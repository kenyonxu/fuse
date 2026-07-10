# E2. 信号引用检测 — 设计规格

> 关联 roadmap：[2026-07-09-static-analysis-enhancement-roadmap.md](2026-07-09-static-analysis-enhancement-roadmap.md)
> 关联 spec：[2026-07-09-static-analysis-integration-design.md](2026-07-09-static-analysis-integration-design.md)
> 关联 spec：[2026-07-09-e1-nodepath-detection.md](2026-07-09-e1-nodepath-detection.md)
> 日期：2026-07-10
> 状态：规划中
> 前置依赖：analyze_problems 已落地（变量检测 + NodePath 检测）

---

## 1. 动机

`EmitSignal` 指令在运行时 emit 一个信号，如果目标节点不存在该信号（拼写错误、节点类型变更、信号未定义），emit 操作**静默失败**——Godot 的 `Node.emit_signal(name)` 在信号不存在时仅打印一个 `editor` 级警告，用户很容易忽略。

**用户看到的**：预期触发的行为（如播放动画、打开对话框）未发生。
**实际原因**：`EmitSignal.signal_name` 与目标节点的信号列表不匹配——可能是信号名拼错，也可能是目标节点类型不对。

E2 补齐 **变量 → 节点路径 → 信号** 的引用检测闭环，在静态分析阶段捕获目标节点信号不存在的问题。

---

## 2. 现状分析

### 2.1 当前 `_extract_signals` 的作用域

`InstructionAnalyzer._extract_signals(trigger, report)`（`:294-316`）当前用于**全场景信号提取**——它在场景树中搜索 `Runner` 子节点，提取每个 Runner 的 `signal_name` + `target_node`，然后与 trigger 路径匹配。

这个方法**不是**指令级别的信号引用提取——它不处理 `EmitSignal` 等指令自身的 `signal_name` 属性。

```
当前 _extract_signals 用途：
Trigger 级别 → 查找该 Trigger 连接了哪些外部信号（由 Runner 定义）
              → 用于 _show_trigger_detail 显示信号列表
              → 用于 build_topology 的 cross_references 关联

不覆盖：EmitSignal 指令中 emit 的信号（指令级别）
```

### 2.2 `EmitSignal` 指令的典型属性布局

Fuse 的 `EmitSignal` 指令（和类似指令）通常包含以下属性：

| 属性名 | 类型 | 语义 |
|--------|------|------|
| `signal_name` | String | 要 emit 的信号名 |
| `target_node` | NodePath | 信号目标节点（可选，缺省为 self） |
| `emit_value` / `arg1` / `arg2` | Variant | 可选参数（非检测目标） |

**命名模式**：`signal_name`（信号名）、`*_signal`（可选扩展）、`target_node`（节点路径）。

### 2.3 引用检测三件套现状

| 引用类型 | 提取方法 | 检测方法 | 状态 |
|---------|---------|---------|------|
| 变量引用 | `_extract_variables` | `analyze_problems` 内 | ✅ 已落地 |
| NodePath 引用 | `_extract_nodepaths` | `_check_nodepath_targets`（E1） | ✅ spec 完成 |
| 信号引用 | ❌ 缺 | ❌ 缺 | 🟡 本 spec |

### 2.4 当前缺口

- `analyze_problems` 无信号引用检测分支
- `analyze_problems` 无 `scene_root` 参数传递（E1 已加 `scene_root = null`，但信号检测还需额外节点上下文）
- 指令中提取信号引用的反射模式未定义（signal_name 命名模式需确认覆盖度）

---

## 3. 设计

### 3.1 总览

```
analyze_problems(instructions, scene_root = null)
  └─ _check_nodepath_targets(instructions, scene_root, problems)   ← E1 已有
  └─ _check_signal_references(instructions, scene_root, problems)  ← E2 新增
       └─ 对每条指令 i:
            └─ 调用 _extract_signal_refs(inst, tmp_report)
            └─ 对每个提取的信号引用:
                 └─ 解析 target_node → target:
                      └─ 无 target_node → 用 scene_root（默认目标）
                      └─ 有 target_node → NodePathResolver.resolve_or_null
                 └─ target.has_signal(signal_name) == false → problems.append
```

### 3.2 `_extract_signal_refs` — 指令级信号引用提取

新增私有方法，从单条指令反射提取 emit 的信号引用：

```gdscript
## 提取指令中的信号引用（信号名 + 目标节点）
## 反射 + 命名启发式，覆盖 dynamic 属性
## @param inst: BaseInstruction - 目标指令
## @param report: Dictionary - 写入 report["signal_refs"] 数组
static func _extract_signal_refs(inst, report: Dictionary) -> void:
    if not report.has("signal_refs"):
        report["signal_refs"] = []

    for prop in inst.get_property_list():
        var pname: String = prop.get("name", "")
        # 信号名：signal_name / *_signal / emit_signal
        var is_signal_name := pname == "signal_name" \
            or pname.ends_with("_signal") \
            or pname == "emit_signal"
        if is_signal_name:
            var val = inst.get(pname)
            if val == null:
                continue
            var sig_name: String = str(val)
            if sig_name.is_empty():
                continue

            # 取 target_node（配对属性）
            var target_str := ""
            if "target_node" in inst:
                var tn = inst.get("target_node")
                if tn != null:
                    target_str = str(tn)

            report.signal_refs.append({
                "signal_name": sig_name,
                "target_str": target_str,
                "source_prop": pname
            })
```

**命名启发式覆盖范围**：

| 属性模式 | 示例 | 覆盖 |
|---------|------|------|
| `signal_name` | `EmitSignal.signal_name` | ✅ |
| `*_signal` | `emit_signal`、`custom_signal` | ✅ |
| `emit_signal` | 显式匹配 | ✅（包含在 `*_signal` 中） |
| `target_node` | 配对属性 | ✅（独立提取，非命名匹配） |

**注意**：`target_node` 使用 NodePath 字符串形式，后续检测时通过 `NodePathResolver.resolve_or_null` 解析——复用 E1 的解析能力。

### 3.3 `_check_signal_references` — 信号存在性检测

```gdscript
static func _check_signal_references(
    instructions: Array,
    scene_root: Node,
    problems: Array
) -> void:
    if scene_root == null:
        return

    for i in range(instructions.size()):
        var inst = instructions[i]
        if inst == null:
            continue
        var tmp := {"signal_refs": [], "nodes": [], "variables": {"local": [], "scope": [], "global": []}}
        _extract_signal_refs(inst, tmp)
        for ref in tmp.get("signal_refs", []):
            var sig_name: String = ref.get("signal_name", "")
            var target_str: String = ref.get("target_str", "")

            # 解析目标节点
            var target_node: Node
            if target_str.is_empty():
                target_node = scene_root  # 默认：触发场景根节点
            else:
                target_node = NodePathResolver.resolve_or_null(target_str, scene_root)

            if target_node == null:
                # target_node 本身无法解析 → 这是一个 NodePath 问题
                # 由 _check_nodepath_targets 报告，此处跳过
                continue

            # 检测信号是否存在
            if not target_node.has_signal(sig_name):
                problems.append({
                    "severity": "error",
                    "message": "目标节点不存在信号: %s（指令 %d）" % [sig_name, i],
                    "instruction_index": i,
                    "signal_name": sig_name,
                    "target_node_str": target_str,
                    "inst": inst
                })
```

**检测流程**：

```
对于每条指令的每个 signal_ref:
  1. 取 signal_name（字符串）
  2. 取 target_str（可能是空/NodePath）
  3. 空 target → 默认以 scene_root 为目标
  4. 非空 target → 用 NodePathResolver 解析
  5. 解析失败 → 跳过（由 E1 报告 NodePath 问题）
  6. 解析成功 → target_node.has_signal(signal_name) 检测
  7. false → 追加 error 到 problems
```

### 3.4 与 `analyze_problems` 集成

在 `analyze_problems` 方法中，在 `_check_nodepath_targets` 之后新增调用点：

```gdscript
static func analyze_problems(instructions: Array, scene_root: Node = null) -> Dictionary:
    var problems: Array = []
    var defined_locals: Dictionary = {}

    # ... 已有：变量检测（未声明变量使用）...

    # E1: NodePath 检测
    if scene_root != null:
        _check_nodepath_targets(instructions, scene_root, problems)

    # E2: 信号引用检测
    if scene_root != null:
        _check_signal_references(instructions, scene_root, problems)

    return {"valid": problems.is_empty(), "problems": problems}
```

### 3.5 与 Topology 的集成

**无额外 Topology 修改**——E2 新增的 `error` 级 problem 自动走现有标注流程：

- `severity: "error"` → `summary.errors += 1`（`_index_problems:718`）
- `has_error` → 树节点 **🔴 红色**（`_build_tree_items:258`）
- Trigger 汇总行显示 `🔴` 计数（`_create_trigger_tree_item:179`）
- 问题消息在详情面板 `_on_item_selected:418` 自动显示

### 3.6 边界情况处理

| 场景 | 行为 |
|------|------|
| `scene_root == null` | 跳过 `_check_signal_references`，零影响 |
| `signal_name` 为空字符串 | `is_empty()` 过滤，不报 |
| `signal_name` 属性值为 `null` | `inst.get(pname)` 返回 null，跳过 |
| `target_node` 未设置（空字符串） | 默认以 `scene_root` 为目标——检测 scene_root 是否有该信号 |
| `target_node` 指向不存在节点 | `resolve_or_null` 返回 null → 跳过报错（由 E1 处理） |
| 目标节点存在但未定义该信号 | `has_signal` 返回 false → 报 `error` |
| 信号名正确但大小写不匹配 | Godot 信号名是**大小写敏感**的——`has_signal("health_changed")` 与 `"Health_Changed"` 不匹配，报 error |
| 目标节点是 `scene_root` 自身 | `resolve_or_null("", scene_root)` → 空字符串 → 默认 `scene_root`，`scene_root.has_signal(...)` |
| 指令类型本身不包含信号属性 | `_extract_signal_refs` 反射不到，`signal_refs[]` 为空 → 跳过 |
| 自定义指令用非标准属性名保存信号 | 命名启发式可能漏掉——需在 `_is_signal_prop` 扩展列表中补充 |
| 目标节点是编辑器脚本生成的虚拟节点 | 静态分析只能检测已入树的节点——`has_signal` 在未 `_ready` 的节点上可正常调用（信号定义在 script 中编译时存在） |

### 3.7 关于 `has_signal` 的可靠性

Godot 4.x 的 `Node.has_signal(name)`：
- 对已 `_ready` 的节点：检查该节点的脚本中 `signal <name>` 定义 + 继承链信号
- 对未入树的 `Node`：同样有效（信号定义在类层级，与 `is_inside_tree` 无关）
- 对 `@tool` 脚本：编译时信号定义已加载，`has_signal` 正常工作
- 自定义信号通过 `add_user_signal("custom_signal")` 动态注册后 `has_signal` 返回 true——此场景在静态分析时如果尚未注册（`_ready` 时注册），会**误报**。但 Fuse `EmitSignal` 的典型用例是 emit 目标节点**静态定义**的信号（如 `Button.pressed`），误报概率低。

---

## 4. 接口契约

### `InstructionAnalyzer._extract_signal_refs` 新增

```
InstructionAnalyzer._extract_signal_refs(inst, report: Dictionary) -> void
```

- 私有静态方法
- 写入 `report["signal_refs"]` 数组
- 每条 entry 格式：`{signal_name: String, target_str: String, source_prop: String}`
- 无副作用，纯反射提取

### `InstructionAnalyzer._check_signal_references` 新增

```
InstructionAnalyzer._check_signal_references(instructions: Array, scene_root: Node, problems: Array) -> void
```

- 私有静态方法
- 在 `scene_root == null` 时直接返回
- 追加 problem 到 `problems` 数组

### Problem 条目新增字段

```gdscript
{
    "severity": "error",              # 信号缺失是确定性问题（与变量未声明同级）
    "message": "目标节点不存在信号: my_signal（指令 5）",
    "instruction_index": 5,
    "signal_name": "my_signal",       # 新增：缺失的信号名
    "target_node_str": "Player",       # 新增：目标节点路径字符串（可能为空）
    "inst": <BaseInstruction>          # 已有：供 Topology by_inst 索引
}
```

**为什么用 `error` 而非 `warning`**：
- `has_signal` 是确定性的静态检测——信号**不存在**是确定的，不依赖运行时条件
- 与变量未声明检测同级（`severity: "error"`）
- 如果目标节点是通过 `add_user_signal` 动态注册信号的，用 `error` 会有误报——但此场景在 Roadmap 中标记为 YAGNI

### `analyze_problems` 签名不变

沿用 E1 修改后的签名，E2 不新增参数：

```
InstructionAnalyzer.analyze_problems(instructions: Array, scene_root: Node = null) -> Dictionary
```

---

## 5. 测试策略

### 5.1 单元测试（`test_instruction_analyzer_problems.gd` 新增用例）

**`test_signal_ref_extract_basic`**
- 构造含 `signal_name = "pressed"` + `target_node = NodePath("Button")` 的指令
- 调用 `_extract_signal_refs(inst, tmp)`
- 预期：`tmp.signal_refs` 含 1 条 entry，`signal_name == "pressed"`，`target_str == "Button"`

**`test_signal_ref_extract_empty_skip`**
- signal_name 为空字符串
- 预期：0 条 signal_ref

**`test_signal_ref_no_signal_prop`**
- 无信号属性的普通指令（如 `SetPosition`）
- 预期：0 条 signal_ref

**`test_signal_exists`**
- signal_name = "pressed"，target_node 指向 TestScene 中的 Button 节点
- 预期：0 signal error

**`test_signal_not_exists`**
- signal_name = "nonexistent_signal"，target_node 指向 TestScene 中的 Button 节点
- 预期：1 error，`severity = "error"`，`signal_name = "nonexistent_signal"`

**`test_signal_target_node_not_found`**
- target_node 指向不存在的节点
- 预期：0 signal error（由 E1 处理 NodePath 问题，E2 跳过）

**`test_signal_default_target`**
- 不设 target_node（空字符串），signal_name 不存在的信号
- 预期：1 error（检测 scene_root 自身没有该信号）

**`test_signal_multiple_refs`**
- 指令同时有 `signal_name` + `emit_signal` 两个属性
- 预期：2 条 signal_ref

**`test_signal_no_scene_root`**
- `scene_root = null`
- 预期：0 signal error（跳过检测）

### 5.2 测试场景扩展

E1 的测试场景已包含 `Player`、`UI/HealthBar`、`Enemy` 节点。E2 需在场景中加一个**带信号的节点**：

```
TestScene (root)
├── Player (Node2D)
├── UI
│   └── HealthBar (ProgressBar)
├── Enemy (CharacterBody2D)
└── SignalButton (Button)     ← 新增：Button 有 pressed / toggled / button_up 等内置信号
```

**测试信号用例**：
- `SignalButton` 的 `pressed` → 存在
- `SignalButton` 的无 `custom_signal` → 不存在
- `Player` 节点无 `pressed` → 不存在（验证对不同节点类型检测）

### 5.3 回归

- 现有 `_extract_signals`（Trigger 级信号提取）不受影响——E2 新增的是指令级 `_extract_signal_refs`，两者在命名和作用域上正交
- 变量检测、NodePath 检测用例不受影响
- Topology cross_references 和 Trigger 详情中的信号列表不变

---

## 6. 实现步骤

### Phase 1：`_extract_signal_refs` 实现

**文件**: `addons/fuse/editor/analysis/instruction_analyzer.gd`

1. 新增 `_is_signal_prop(pname: String) -> bool` 方法（模式匹配 `signal_name` / `*_signal` / `emit_signal`）
2. 新增 `_extract_signal_refs(inst, report) -> void`：
   - 反射遍历 `get_property_list()`
   - 匹配信号属性名
   - 读取 `target_node` 配对
   - 写入 `report.signal_refs`

**验收**：
- [ ] `_extract_signal_refs(mock_emit_signal, {})` → `signal_refs` 数组含信号引用
- [ ] 无信号属性的指令返回 `signal_refs` 为空
- [ ] 空字符串 `signal_name` 自动跳过

### Phase 2：`_check_signal_references` 实现

**文件**: `addons/fuse/editor/analysis/instruction_analyzer.gd`

1. 新增 `_check_signal_references(instructions, scene_root, problems) -> void`
2. 对每条指令：提取 signal_refs → 解析 target_node → `has_signal` 检测
3. 在 `analyze_problems` 主循环末尾、`_check_nodepath_targets` 之后插入调用点

**验收**：
- [ ] 信号不存在的指令 → problems 含 1 error
- [ ] 信号存在的指令 → 0 signal error
- [ ] `scene_root = null` → 跳过
- [ ] target_node 不存在（NodePath 问题）→ 跳过

### Phase 3：测试

**文件**: `addons/fuse/tests/test_instruction_analyzer_problems.gd` + `.tscn`

1. 扩展 test scene 加 `SignalButton` 节点
2. 实现所有测试用例（Phase 5.1）
3. 运行全部测试，确认零回归

**验收**：
- [ ] 所有 E2 测试通过
- [ ] 变量检测、NodePath 检测回归测试通过

---

## 7. 不做（YAGNI）

| 项 | 原因 |
|----|------|
| **动态注册信号检测**（`add_user_signal`） | 在 `_ready` 期间注册的信号静态分析无法预知——`has_signal` 返回 false 但运行时可能存在。此场景极少用于 Fuse 指令的目标节点，保持 `error` 级别 |
| **信号参数签名检测**（emit 时传递的参数类型/数量与 `signal` 定义不匹配） | Godot 的 `emit_signal` 参数数量不匹配时只是 runtime warning，静态分析难以确定参数类型——类型系统不足 |
| **接收器连接检测**（谁 connect 了这个信号） | 属于跨 Trigger 关联（E3），不在 E2 范围 |
| **`_extract_signals` 重构**（将现有 Trigger 级和新增指令级信号提取合并） | 两者语义不同（Trigger 级：连接了哪些信号；指令级：emit 了哪些信号），合并降低可维护性 |
| **目标节点推荐**（"是否要改为 Button.pressed？"） | 属于 Quick fix，排期在 Roadmap E 系列之外 |

---

## 8. 风险

| 风险 | 影响 | 缓解 |
|------|------|------|
| 自定义指令用非标准属性名存信号（`signal_to_emit` 等） | `_extract_signal_refs` 漏提取，导致漏报 | 命名启发式覆盖主流模式；`_is_signal_prop` 方法可扩展——用户或后续维护者加新匹配规则只需改这一处 |
| 目标节点在 `_ready` 中用 `add_user_signal` 动态注册信号 | 静态 `has_signal` 返回 false，`error` 误报 | Fuse 指令目标节点通常是 Godot 内置节点（Button、Sprite 等），内置节点信号是静态编译的，无动态注册问题。若发现误报，可在后续将 `error` 降级为 `warning` |
| `has_signal` 对 `@tool` 脚本中的信号定义返回 false（脚本未编译） | `@tool` 脚本在编辑器打开时已编译——通常无此问题 | 若发生（极少数），误报为 error。缓解同上：降级 warning |
| `signal_refs` 数组随指令数量增长，`analyze_problems` 耗时增加 | 每次 analyze_problems 多一次全遍历 | 信号提取是纯反射 O(n)，与现有的变量提取 + NodePath 提取复杂度同量级，无额外瓶颈 |

---

## 9. 验收标准

- [ ] `_extract_signal_refs` 实现：从指令反射提取 `signal_name` + `target_node` 配对
- [ ] `_check_signal_references` 实现：检测目标节点 `has_signal` 缺失
- [ ] 信号名匹配覆盖 `signal_name` / `*_signal` / `emit_signal` 三种模式
- [ ] target_node 不设置时以场景根为目标
- [ ] target_node 解析失败时跳过（E1 处理）
- [ ] `scene_root = null` 时跳过检测
- [ ] 所有 E2 测试用例通过
- [ ] 回归：变量检测 + NodePath 检测不受影响
- [ ] Roadmap 中 E2 标记为 "spec 完成"

---

## 10. 修改文件清单

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `addons/fuse/editor/analysis/instruction_analyzer.gd` | 修改 | 新增 `_extract_signal_refs` + `_is_signal_prop` + `_check_signal_references`；`analyze_problems` 新增调用分支 |
| `addons/fuse/tests/test_instruction_analyzer_problems.gd` | 新增用例 | Phase 5.1 全部测试 |
| `addons/fuse/tests/test_instruction_analyzer_problems.tscn` | 修改 | 扩展场景添加 `SignalButton` 节点 |

仅修改 3 个文件——无 Topology、Inspector、Plugin 改动。

---

*本 spec 批准后，下一步：invoke writing-plans 生成实现计划。*
