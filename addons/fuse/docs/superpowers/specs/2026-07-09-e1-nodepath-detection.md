# E1. NodePath 解析失败检测 — 设计规格

> 关联 roadmap：[2026-07-09-static-analysis-enhancement-roadmap.md](2026-07-09-static-analysis-enhancement-roadmap.md)
> 关联 spec：[2026-07-09-static-analysis-integration-design.md](2026-07-09-static-analysis-integration-design.md)
> 日期：2026-07-09
> 状态：规划中
> 前置依赖：analyze_problems 已落地（变量检测 + Topology 标注）

---

## 1. 动机

指令引用的节点路径（`TweenMoveTo.target_node`、`SetPosition.target_node` 等）指向不存在的节点，是 **Fuse 用户最高频的配置错误之一**。当前行为：运行时静默失败——Target 节点找不到，指令不执行，无任何反馈。

**用户看到的**：角色不移动、不旋转、不播放动画——体验上像"Fuse 坏了"。
**实际原因**：场景重构后节点路径变了，指令里的 NodePath 还是旧的。

E1 在"刷新拓扑"时扫描指令中的 NodePath 引用，对无法解析的路径报 `warning`，将静默失败提前到编辑器静态分析阶段。

---

## 2. 现状分析

### 2.1 已有提取能力

`InstructionAnalyzer._extract_nodepaths(inst, report)`（`instruction_analyzer.gd:192`）已通过反射 + 命名启发式提取所有 NodePath 属性：

```gdscript
var is_node_ref := ptype == TYPE_NODE_PATH \
    or prop_name.ends_with("_node") \
    or prop_name.ends_with("_node_path")
```

覆盖：NodePath 类型属性 + String 类型但命名约定为 `*_node` / `*_node_path` 的动态属性。

### 2.2 已有解析规则

`NodePathResolver`（`nodepath_resolver.gd`）在预设粘贴场景（8a-2）实现了三级匹配策略：

| 策略 | 方法 | 适用 |
|------|------|------|
| 1. 相对路径结构 | `target_node.get_node_or_null(old_np)` → 父节点回退 | 路径结构保留的场景 |
| 2. 全局同名 | `scene_root.find_children(last_name)` | 节点改名但场景树变化大 |
| 3. 手动候选 | 收集场景所有路径供用户选 | 无自动匹配 |

当前策略 1 和 2 **作为 `resolve_mapping` 内部私有方法存在**，没有公开的"尝试所有策略、返回首个匹配或 null"的单一入口。

### 2.3 当前缺口

- `analyze_problems` 签名只有 `(instructions: Array)`，没有场景上下文
- `analyze_problems` 未调用 `_extract_nodepaths` 检测
- `NodePathResolver` 无公开的单路径解析 API（`resolve_mapping` 传的是批量 old_nodepaths）
- Topology `refresh()` 有 `scene_root` 但传给 `analyze_problems` 时不带

---

## 3. 设计

### 3.1 总览

```
analyze_problems(instructions, scene_root=null)
  └─ _check_nodepath_targets(instructions, scene_root)
       └─ 对每条指令 i:
            └─ 调用 _extract_nodepaths(inst, tmp_report)
            └─ 对每个提取的 np_str:
                 └─ NodePathResolver.resolve_or_null(np_str, scene_root)
                 └─ null → problems.append({severity: "warning", ...})
```

### 3.2 签名变更

```gdscript
## @param instructions: Array - 指令序列（flat 顺序）
## @param scene_root: Node - 场景根节点（可选；为 null 时跳过 NodePath 检测）
## @return: Dictionary - {valid: bool, problems: Array[Dictionary]}
static func analyze_problems(instructions: Array, scene_root: Node = null) -> Dictionary:
```

- `scene_root` 默认 `null` → 兼容现有调用方（Inspector、测试）不传场景时不报 NodePath 问题
- Topology `refresh()` 传入 `scene_root` → 触发 NodePath 检测

### 3.3 `_check_nodepath_targets` 分支

在 `analyze_problems` 主循环**末尾**（变量检测完成后）新增分支，**不与其他检测耦合**：

```gdscript
if scene_root != null:
    _check_nodepath_targets(instructions, scene_root, problems)
```

原型：

```gdscript
static func _check_nodepath_targets(
    instructions: Array,
    scene_root: Node,
    problems: Array
) -> void:
    for i in range(instructions.size()):
        var inst = instructions[i]
        if inst == null:
            continue
        var tmp := {"nodes": []}
        _extract_nodepaths(inst, tmp)
        # 条件节点中的 NodePath 引用（与 analyze_problems 变量检测对齐）
        var cond = inst.get("condition") if inst != null else null
        if cond != null:
            _extract_nodepaths(cond, tmp)
        for np_str in tmp.nodes:
            if NodePathResolver.resolve_or_null(np_str, scene_root) == null:
                problems.append({
                    "severity": "warning",
                    "message": "节点路径无法解析: %s（指令 %d）" % [np_str, i],
                    "instruction_index": i,
                    "nodepath": np_str,
                    "inst": inst
                })
```

### 3.4 解析规则：`NodePathResolver.resolve_or_null`

在 `NodePathResolver` 新增公开静态方法，**封装现有三级匹配策略的核心逻辑**：

```gdscript
## 尝试用所有策略解析 NodePath，返回找到的 Node 或 null
## @param np_str: String - 原始 NodePath 字符串
## @param scene_root: Node - 当前场景根节点
static func resolve_or_null(np_str: String, scene_root: Node) -> Node:
    var np := NodePath(np_str)
    var found: Node

    # —— 策略 1: 相对路径结构 ——
    # 从 scene_root 直接解析（覆盖绝对路径 /root/... 和相对路径 Player）
    found = scene_root.get_node_or_null(np)
    if found:
        return found

    # 从 scene_root 父节点解析（覆盖 ../... 跨兄弟路径）
    var parent := scene_root.get_parent()
    if parent:
        found = parent.get_node_or_null(np)
        if found:
            return found

    # —— 策略 2: 全局同名 ——
    # 取最后一段节点名，全场景广度优先搜索
    if np.get_name_count() > 0:
        var last_name := _get_last_name(np_str)
        if last_name != "" and last_name != ".." and last_name != ".":
            # 守卫：节点未入树时 get_tree() 为 null，find_children 会崩溃
            if scene_root.get_tree() != null:
                var children := scene_root.find_children(last_name, "", true, false)
                if not children.is_empty():
                    return children[0]

    # —— 策略 3: 空 ——
    return null
```

**与现有 NodePathResolver 的关系**：
- `_match_relative(old_np, target_node)` 与策略 1 逻辑重叠——但现有方法以 `target_node`（Trigger 所在节点）为锚点，而 E1 以 `scene_root` 为锚点
- `_find_node_by_name` 与策略 2 逻辑相似但锚点不同——前者以 `from_node.get_tree().current_scene` 为搜索根，E1 以 `scene_root` 为搜索根
- `resolve_or_null` 调整为以 `scene_root` 为锚点（与 E1 场景匹配），同时保留 `_match_relative` 的 `target_node` 版本不变（供预设粘贴使用）

**为什么复用 NodePathResolver 而非在 Analyzer 内重写**：
- 解析规则（相对→绝对→名搜索）是**有上下文的知识**，两处用同一定义避免 divergence
- 未来如果策略增加（如 UID 匹配），只改一处

### 3.5 Topology 修改

`fuse_topology.gd` `refresh()` 中已有 `scene_root`（`EditorInterface.get_edited_scene_root()`），在调用 `analyze_problems` 时传入：

```gdscript
# 当前（行 125）：
var analysis := InstructionAnalyzer.analyze_problems(insts)

# 改为：
var analysis := InstructionAnalyzer.analyze_problems(insts, scene_root)
```

**无其他 Topology 改动**——问题标注机制（`_index_problems` → `by_inst` → 树节点红/黄标）已在集成 spec 中实现，E1 新增的 `warning` 级 problem 自动被现有标注流程处理：

- `severity: "warning"` → `summary.warnings += 1`（`_index_problems:711`）
- `has_warning` → 树节点 **🟡 黄色**（`_build_tree_items:256,262`）
- Trigger 汇总行显示 `🟡` 计数

### 3.6 边界情况处理

| 场景 | 行为 |
|------|------|
| `scene_root == null` | 跳过整个 `_check_nodepath_targets` 分支，零影响 |
| 空 NodePath 字符串 `""` | `_extract_nodepaths` 时已跳过（`s.is_empty()` 检查，行 206），不报 |
| NodePath 类型属性值为 `NodePath("")` | `str(NodePath(""))` = `""` → 被 `is_empty() ` 跳过 |
| 绝对路径 `/root/Main/Player` | 策略 1 `scene_root.get_node_or_null` 从根起解析，可直接匹配 |
| 相对路径 `Player` | 策略 1 在 `scene_root` 子节点中匹配 |
| 跨层路径 `../Enemy` | 策略 1 父节点回退匹配 |
| 多层路径 `UI/HealthBar/Bar` | 策略 1 逐层匹配；策略 2 只取最后一段 `Bar` |
| 场景树中存在同名节点（策略 2 匹配到第一个） | 返回第一个 `find_children` 结果——这是 NodePathResolver 现有行为，与预设粘贴一致 |
| 指令在嵌套场景（instanced scene）中 | `scene_root` 仍为主场景根节点，`find_children` 递归搜索可跨越嵌套边界 |
| NodePath 是 `"."`（自引用） | `"."` 的 `get_node_or_null` 在 scene_root 上返回 scene_root 自身 → 解析成功 |
| 属性值非 NodePath/String（null / Variant 其他类型） | `_extract_nodepaths` 中 `str(np)` 转换，非字符串型可能返回 `"<null>"` 等——但 `is_empty` 仍能正确排除空值 |
| 指令被删除后残留引用（Null inst） | `inst == null` 时 `continue`，跳过 |

---

## 4. 接口契约

### `InstructionAnalyzer.analyze_problems` 签名变更

```
旧: InstructionAnalyzer.analyze_problems(instructions: Array) -> Dictionary
新: InstructionAnalyzer.analyze_problems(instructions: Array, scene_root: Node = null) -> Dictionary
```

- 返回结构不变：`{valid: bool, problems: Array[{severity, message, instruction_index, ...}]}`
- 新增字段 `nodepath: String`（仅在 NodePath 检测产生的 problem 中存在）
- `scene_root` 默认 `null` → 完全向后兼容

### `NodePathResolver.resolve_or_null` 新增

```
NodePathResolver.resolve_or_null(np_str: String, scene_root: Node) -> Node
返回：找到的 Node 实例，或 null（所有策略均失败）
```

- **静态方法**，无副作用，不修改场景树
- 依赖：`scene_root` 必须为有效节点（`is_inside_tree()` 或至少 `get_tree()` 可访问）
- 当 `scene_root.get_tree()` 为 `null`（节点未入树）时：策略 1 仍可工作（`get_node_or_null` 不依赖 tree），策略 2（`find_children` 依赖 tree）回退为 null

### Problem 条目新增字段

```gdscript
{
    "severity": "warning",            # NodePath 检测用 warning，区别于变量检测的 error
    "message": "节点路径无法解析: Player（指令 3）",
    "instruction_index": 3,
    "nodepath": "Player",             # 新增：无法解析的 NodePath 原始字符串
    "inst": <BaseInstruction>         # 已有：供 Topology by_inst 索引
}
```

使用 `warning` 而非 `error` 的依据：
- NodePath 可能是运行时动态填充的（占位符），静态不确定
- 场景可能通过脚本运行时添加节点，静态分析无法覆盖
- 变量未声明 → 确定错误（`error`）；NodePath 未解析 → 可能错误（`warning`）

---

## 5. 测试策略

### 5.1 单元测试（`test_instruction_analyzer_problems.gd` 新增用例）

**`test_nodepath_relative_resolve_ok`**
- 构造含有效 NodePath（指向测试场景中存在的节点）的指令
- 传入 `scene_root`
- 预期：0 warning，problems 为空

**`test_nodepath_relative_resolve_fail`**
- 构造含无效 NodePath（指向不存在的 "NonexistentNode"）的指令
- 传入 `scene_root`
- 预期：1 warning，severity="warning"，nodepath 字段正确

**`test_nodepath_absolute_resolve_ok`**
- 构造含绝对路径 `/root/TestScene/ExistingNode` 的指令
- 预期：0 warning

**`test_nodepath_skip_when_no_scene_root`**
- `scene_root = null`（或不传）
- 预期：即使指令含无效 NodePath，也不产生 warning

**`test_nodepath_skip_empty`**
- NodePath 属性值为空 `""`
- 预期：0 warning

**`test_nodepath_global_name_fallback`**
- 节点路径结构已变，但最后一段节点名在场景中唯一
- 预期：warning = 0（策略 2 兜底成功）

**`test_nodepath_multiple_instructions`**
- 多条指令各有 NodePath 引用，部分有效部分无效
- 预期：仅无效路径产生 warning，instruction_index 正确

### 5.2 Test Scene 需求

现有 `test_instruction_analyzer_problems.tscn` 需扩展——添加以下节点供分辨率测试：

```
TestScene (root)
├── Player (Node2D)
├── UI
│   └── HealthBar (ProgressBar)
└── Enemy (CharacterBody2D)
```

测试指令通过 `inst.set("target_node", NodePath("Player"))` 等方式注入 NodePath。

### 5.3 回归

- 现有 `test_stage65_extract.gd`（`_extract_nodepaths` 提取）+ 变量检测用例在 `scene_root` 默认值下零影响
- Topology 现有标注行为不变（新增 warning 自动走现有 `has_warning` → 🟡 路径）
- `NodePathResolver._match_relative` 和 `_find_node_by_name` 不受影响（现有私有方法不动，仅新增 `resolve_or_null` 公开方法）

---

## 6. 实现步骤

### Phase 1：`NodePathResolver.resolve_or_null`

**文件**: `addons/fuse/editor/serialization/nodepath_resolver.gd`

1. 新增公开静态方法 `resolve_or_null(np_str, scene_root) → Node`
2. 实现策略 1（`get_node_or_null` + 父级回退）和策略 2（`find_children` 按名搜索）
3. 可考虑从 `_match_relative` 和 `_find_node_by_name` 抽取公共部分，但最小变更优先——直接在新方法中实现，后续再重构私有方法的共享逻辑

**验收**：
- [ ] `resolve_or_null("Player", scene_root)` → 返回 Player 节点
- [ ] `resolve_or_null("Nonexistent", scene_root)` → 返回 null
- [ ] `resolve_or_null("../Enemy", scene_root)` → 返回 Enemy 节点
- [ ] `resolve_or_null("/root/TestScene/Player", scene_root)` → 返回 Player 节点
- [ ] `resolve_or_null("UI/HealthBar", scene_root)` → 返回 HealthBar 节点

### Phase 2：`InstructionAnalyzer._check_nodepath_targets`

**文件**: `addons/fuse/editor/analysis/instruction_analyzer.gd`

1. 新增 `_check_nodepath_targets(instructions, scene_root, problems) → void`
2. 在 `analyze_problems` 主循环末尾插入调用点
3. 修改 `analyze_problems` 签名增加 `scene_root = null`

**验收**：
- [ ] `analyze_problems([inst_with_bad_np], scene_root)` → 返回含 1 warning 的 problems
- [ ] `analyze_problems([inst_with_bad_np])`（不传 scene_root） → 0 warning
- [ ] 问题条目的 `nodepath` 字段为正确字符串
- [ ] 问题条目的 `inst` 字段指向触发指令

### Phase 3：Topology 传 scene_root

**文件**: `addons/fuse/editor/topology/fuse_topology.gd`

1. `refresh()` 中调用 `analyze_problems` 的行增加 `scene_root` 参数

**验收**：
- [ ] 刷新含无效 NodePath 的场景 → Topology 树中对应指令 **🟡 黄色标注**
- [ ] 选中指令 → 详情面板显示 "节点路径无法解析: XXX"
- [ ] Trigger 汇总行显示 `🟡` 计数

### Phase 4：测试

**文件**: `addons/fuse/tests/test_instruction_analyzer_problems.gd` + `.tscn`

1. 扩展 test scene 加 Player/UI/HealthBar/Enemy 节点
2. 实现 Phase 5.1 中的所有测试用例
3. 运行全部测试确认零回归

---

## 7. 不做（YAGNI）

| 项 | 原因 |
|----|------|
| **运行时路径动态填充检测** | 静态分析无法知道运行时 `target_node = get_node("../dynamic")` 是否有效——保持 warning 而非 error，留给动态路径 |
| **NodePath 建议/自动修复** | E1 只检测和报告，修复动作（"是否将路径更新为 X"）属于 Quick fix 功能，排期在 roadmap E 系列之外 |
| **跨场景 NodePath** | `scene_root` 为主场景根，嵌套场景的节点如果不在主场景树中不会被 found_children 找到——这在未来多场景分析增强中处理 |
| **信号连接目标检测** | 属于 E2（信号引用检测），不在 E1 范围 |
| **NodePathResolver._match_relative 重构** | 旧私有方法不变，`resolve_or_null` 仅新增。预设粘贴与 E1 共享规则但不共享实现，降低 Phase 1 风险；后续可抽取公共 resolution core |

---

## 8. 风险

| 风险 | 影响 | 缓解 |
|------|------|------|
| `find_children` 在节点未入树时返回空 | 策略 2 在未入树场景中降级，纯相对路径仍可工作 | `resolve_or_null` 内 `tree == null` 时跳过 `find_children` 调用 |
| 同名节点多（策略 2 匹配到错误节点） | warning 误报（路径其实指向另一个同名节点） | 已在 NodePathResolver 现有设计中接受（策略 2 是降级策略），`warning` 级别不会打断用户工作流 |
| 指令子类自定义 `get(prop_name)` 有副租用 | 属性读取触发意外逻辑 | `_extract_nodepaths` 已通过 `inst.get(prop_name)` 调用，现有指令均无副作用问题（与变量提取 same risk） |
| `scene_root.get_node_or_null` 对空属性返回 null（除非 `""` 提前过滤） | `""` 已在 `_extract_nodepaths` 中通过 `is_empty()` 过滤，不会进入分辨率 | 防御：`resolve_or_null` 入口加 `if np_str.is_empty(): return null` |

---

## 9. 验收标准

- [ ] `NodePathResolver.resolve_or_null` 实现 + 单元测试
- [ ] `InstructionAnalyzer.analyze_problems` 签名扩展（`scene_root = null`），`_check_nodepath_targets` 分支
- [ ] 所有 E1 测试用例通过（含有效路径、无效路径、空路径、无 scene_root）
- [ ] Topology 刷新时传入 `scene_root`，无效 NodePath → 🟡 标注
- [ ] 回归：现有变量检测测试 + Topology 行为不变
- [ ] gdscript-validate 通过所有改动文件
- [ ] roadmap 中 E1 标记为 "spec 完成"

---

## 10. 修改文件清单

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `addons/fuse/editor/serialization/nodepath_resolver.gd` | 新增方法 | `resolve_or_null` 公开静态方法 |
| `addons/fuse/editor/analysis/instruction_analyzer.gd` | 修改 | `analyze_problems` 签名 + 新增 `_check_nodepath_targets` |
| `addons/fuse/editor/topology/fuse_topology.gd` | 修改 | `refresh()` 调用处传 `scene_root` |
| `addons/fuse/tests/test_instruction_analyzer_problems.gd` | 新增用例 | Phase 5.1 全部测试 |
| `addons/fuse/tests/test_instruction_analyzer_problems.tscn` | 修改 | 扩展场景节点 |

---

*本 spec 批准后，下一步：invoke writing-plans 生成实现计划。*
