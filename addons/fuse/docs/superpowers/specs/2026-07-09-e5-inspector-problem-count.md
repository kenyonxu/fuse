# E5. Inspector 问题计数集成 — 设计规格

> 关联 roadmap：[2026-07-09-static-analysis-enhancement-roadmap.md](2026-07-09-static-analysis-enhancement-roadmap.md)
> 关联 spec：[2026-07-09-static-analysis-integration-design.md](2026-07-09-static-analysis-integration-design.md)
> 日期：2026-07-10
> 状态：规划中
> 前置依赖：`InstructionAnalyzer.analyze_problems` 已落地（变量检测 + NodePath 检测）
> 前置依赖：`FuseInspectorPlugin._add_dataflow_ui` 已落地（Trigger 选中时显示数据流卡片）

---

## 1. 动机

Topology 面板是问题查看主入口，但用户在 **Inspector 中直接编辑 Trigger** 时（修改事件、变量、指令），无法立刻看到 Trigger 是否存在问题——必须切换到 Topology 面板重新刷新。

**当前用户路径**：
```
在场景树中选中 Trigger → Inspector 编辑属性
  → 编辑完成后切换到 Topology 面板
  → 按 🔄 刷新 → 查看问题列表
  → 发现问题 → 切回 Inspector 修复
  → 再切回 Topology 确认修复
  ⚠ 来回切换，效率低
```

**目标路径**：
```
在场景树中选中 Trigger → Inspector 编辑属性并立即看到问题摘要
  → 展开数据流卡片查看问题详情
  → 在 Inspector 内就地修复
  → 数据流卡片自动反映问题状态
```

E5 在 Fuse Inspector 的数据流卡片中集成问题摘要和详情展示，消除面板切换。

---

## 2. 现状分析

### 2.1 当前数据流卡片实现

`FuseInspectorPlugin._add_dataflow_ui(report)`（`:233-271`）在 Inspector 底部生成一个可折叠的数据流卡片，展示：

- **按钮文本**：`"📊 数据流: <事件名> (N指令, N节点, N变量, N信号)"`
- **展开卡片内容**（`_create_dataflow_card`，`:277-316`）：
  - 事件名称
  - 操作节点列表
  - 变量列表（local / scope / global 分组）
  - 信号列表
  - 指令链列表

**缺少的**：问题摘要——卡片没有任何与 `analyze_problems` 结果相关的信息。

### 2.2 `analyze_trigger` 的当前输出

`InstructionAnalyzer.analyze_trigger(trigger)`（`:28-68`）返回的 `report` 字典不含 `problems` 字段：

```gdscript
{
    "trigger_name": "TweenTrigger",
    "trigger_path": "...",
    "trigger_type": "Trigger",
    "event": {"type": "OnStart", "resource_name": "On Start"},
    "event_bindings": [...],
    "nodes": ["Player", "Enemy"],
    "variables": {"local": [...], "scope": [...], "global": [...]},
    "signals": [{"signal": "pressed", "target": "Button", ...}],
    "instructions_flat": [...],
    "instructions_tree": [...]
    # ❌ 无 "problems" 字段
}
```

### 2.3 当前 `analyze_problems` 调用路径

在 Topology `refresh`（`:123-126`）中调用：

```gdscript
for report in topology.triggers:
    var insts: Array = _collect_insts_from_report(report)
    var analysis := InstructionAnalyzer.analyze_problems(insts)
    report["problems"] = _index_problems(analysis.problems)
```

而在 Inspector 中，`_add_dataflow_ui` 直接使用 `_report_cache`（`analyze_trigger` 的原始输出），**未调用 `analyze_problems`**。

✅ **源码验证**（`fuse_inspector_plugin.gd:132-138`）：`_parse_end` 当前流程为 `analyze_trigger` → `_report_cache = report` → `_add_action_buttons` → `_add_dataflow_ui`，确无 `analyze_problems` 调用。现状描述准确。

### 2.4 当前缺口

- `analyze_trigger` 内部不调用 `analyze_problems`——其输出不含问题数据
- `_add_dataflow_ui` / `_create_dataflow_card` 不读取 `problems`
- `_parse_end` 中获取 `_report_cache` 后，没有触发 `analyze_problems` 的更新机制
- 数据流卡片展开（`_toggle_dataflow` → `_dataflow_card.visible`）后内容不变——即使编辑了 Trigger，卡片数据不会刷新

---

## 3. 设计

### 3.1 总览

```
Inspector 选中 Trigger
  → _parse_end(object as BaseTrigger)
  → analyze_trigger(trigger) → _report_cache
  → 新增：analyze_problems 调用 + 注入 problem summary
  → _add_dataflow_ui(report)：按钮文本加问题计数角标
  → 展开卡片：新增问题段（汇总 + 列表）
```

### 3.2 `analyze_trigger` 联动 `analyze_problems`

在 `_parse_end` 中，在调用 `analyze_trigger` 之后立即调用 `analyze_problems` 并将结果注入 `_report_cache`：

```gdscript
func _parse_end(object: Object) -> void:
    if object is BaseTrigger:
        var report = InstructionAnalyzerClass.analyze_trigger(object)
        # 新增：注入问题分析
        var insts := _collect_insts_from_trigger_report(report)
        if not insts.is_empty():
            var analysis := InstructionAnalyzerClass.analyze_problems(insts)
            report["problems"] = _index_problems(analysis.problems)
        else:
            report["problems"] = {"by_inst": {}, "summary": {"errors": 0, "warnings": 0}}
        _report_cache = report
        _current_node = object as Node
        _add_action_buttons(object as Node)
        _add_dataflow_ui(report)
```

**`_collect_insts_from_trigger_report`** — 从 `analyze_trigger` 的 report 中收集所有指令 inst（复用 Topology 的 `_collect_insts_from_tree` 逻辑的简化版）：

```gdscript
## 从 Trigger report 收集所有指令 inst
func _collect_insts_from_trigger_report(report: Dictionary) -> Array:
    var insts: Array = []
    # EventBinding 分支
    for binding in report.get("event_bindings", []):
        insts.append_array(_collect_insts_from_tree(binding.get("instructions_tree", [])))
    # 普通 Trigger 分支
    insts.append_array(_collect_insts_from_tree(report.get("instructions_tree", [])))
    return insts


## 递归收集 instructions_tree 中的 inst
func _collect_insts_from_tree(tree: Array) -> Array:
    var out: Array = []
    for node_info in tree:
        var inst = node_info.get("inst")
        if inst != null:
            out.append(inst)
        for branch in node_info.get("children", {}).values():
            out.append_array(_collect_insts_from_tree(branch))
    return out
```

### 3.3 数据流卡片按钮加问题角标

`_add_dataflow_ui` 在按钮文本末尾添加问题计数：

```gdscript
func _add_dataflow_ui(report: Dictionary) -> void:
    # ... 现有统计 ...
    var node_count: int = report.nodes.size()
    var signal_count: int = report.signals.size()
    var var_count := 0
    for scope in report.variables:
        var_count += report.variables[scope].size()

    # 新增：问题摘要
    var summary: Dictionary = report.get("problems", {}).get("summary", {"errors": 0, "warnings": 0})
    var err_count: int = summary.get("errors", 0)
    var warn_count: int = summary.get("warnings", 0)
    var problem_suffix: String = ""
    if err_count > 0 and warn_count > 0:
        problem_suffix = " 🔴%d 🟡%d" % [err_count, warn_count]
    elif err_count > 0:
        problem_suffix = " 🔴%d" % err_count
    elif warn_count > 0:
        problem_suffix = " 🟡%d" % warn_count

    var base_text := "📊 数据流: %s (%d指令, %d节点, %d变量, %d信号)" % [
        report.event.get("resource_name", "?"),
        report.instructions_flat.size(), node_count, var_count, signal_count
    ]

    if _dataflow_button:
        _dataflow_button.text = base_text + problem_suffix
        return

    # 首次创建
    _dataflow_button = Button.new()
    _dataflow_button.text = base_text + problem_suffix
    # ...
```

### 3.4 展开卡片中的问题详情段

在 `_create_dataflow_card` 的内容末尾追加问题区：

```gdscript
func _create_dataflow_card() -> void:
    var report := _report_cache
    _dataflow_card = VBoxContainer.new()
    var panel := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.08, 0.12, 0.25, 0.8)
    style.set_content_margin_all(4)
    panel.add_theme_stylebox_override("panel", style)
    _dataflow_card.add_child(panel)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 2)
    panel.add_child(content)

    # === 现有内容 ===
    content.add_child(_make_section_label("数据流"))
    # ... event, nodes, variables, signals, instructions ...

    # === 新增：问题段 ===
    _add_problems_section(content, report)

    add_custom_control(_dataflow_card)


func _add_problems_section(content: VBoxContainer, report: Dictionary) -> void:
    var summary: Dictionary = report.get("problems", {}).get("summary", {"errors": 0, "warnings": 0})
    var err_count: int = summary.get("errors", 0)
    var warn_count: int = summary.get("warnings", 0)

    if err_count == 0 and warn_count == 0:
        content.add_child(_make_info_line("问题: (无)"))
        return

    var label_text := "问题: "
    if err_count > 0:
        label_text += "🔴%d 错误 " % err_count
    if warn_count > 0:
        label_text += "🟡%d 警告 " % warn_count
    content.add_child(_make_section_label(label_text))

> **注意**：`_make_info_line` 必须创建 `RichTextLabel`（`bbcode_enabled = true`）而非 `Label`，因为消息文本含 `[color=red]` / `[color=yellow]` BBCode 标签。Label 不解析 BBCode。

    # 列出具体问题
    var by_inst: Dictionary = report.get("problems", {}).get("by_inst", {})
    var seen_messages: Array = []  # 去重（同条指令的类似问题）
    for inst_id in by_inst:
        for p in by_inst[inst_id]:
            var msg: String = p.get("message", "")
            if msg not in seen_messages:
                seen_messages.append(msg)
                var color := "red" if p.get("severity") == "error" else "yellow"
                content.add_child(_make_info_line("[color=%s]• %s[/color]" % [color, msg]))
```

**去重说明**：`by_inst` 是按 `inst instance_id` 索引的。如果同一变量被同一指令多处引用（如 condition + body 都引用了同一个未声明变量），`analyze_problems` 时会生成多条 `instruction_index` 相同的 problem。去重确保卡片中每条错误消息只显示一次。

### 3.5 按钮颜色警示

当 Trigger 有问题时，数据流按钮可通过颜色提示用户注意：

```gdscript
if _dataflow_button:
    _dataflow_button.text = base_text + problem_suffix
    if err_count > 0:
        _dataflow_button.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
    elif warn_count > 0:
        _dataflow_button.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
    else:
        _dataflow_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
    return
```

### 3.6 刷新触发时机

当前数据流卡片在以下时机初始化/更新：
1. **Inspector 选中 Trigger 时**：`_parse_end` 被调用 → 触发 `analyze_trigger` + `analyze_problems`
2. **编辑属性时**：当前 `_parse_end` 重调需要用户切换触发节点（切换选中→切回）才能触发

**不做实时刷新**（与 Roadmap 设计原则一致）：
- Trigger 属性编辑 → `analyze_problems` 结果不变 → 直到用户重选 Trigger 或手动切到 Topology 刷新
- 如果未来需要实时，可在修改 `_parse_end` 或 `notify_property_list_changed` 后重算

### 3.7 边界情况处理

| 场景 | 行为 |
|------|------|
| Trigger 无指令（空 Trigger） | `_collect_insts_from_trigger_report` 返回空数组 → `analyze_problems` 返回 `{valid: true, problems: []}` → `summary` 全零 → 显示"问题: (无)" |
| Trigger 已无问题（修复后） | `analyze_problems` 的 `problems` 数组为空 → `summary{errors: 0, warnings: 0}` → 按钮无角标，卡片显示"问题: (无)" |
| 嵌套场景 Trigger | `analyze_problems` 的 `scene_root` 默认为 `null`（Inspector 中无 `scene_root` 上下文）→ NodePath 检测和信号跳过——不影响变量检测 |
| 展开问题卡片时问题为空 | `err_count == 0 && warn_count == 0` → 不显示问题段，不影响卡片展示 |
| 问题列表超长 | `VBoxContainer` + `_make_info_line` 每种问题一行，随卡片滚动可见 |
| EventBinding（MultiEventTrigger） | `_collect_insts_from_trigger_report` 同时收集 `event_bindings[].instructions_tree` 中的指令——覆盖多 binding 形态 |
| `analyze_problems` 返回 null 或异常 | `report.get("problems", {})` 确保安全访问，不影响卡片其他内容 |

---

## 4. 接口契约

### `FuseInspectorPlugin._collect_insts_from_trigger_report` 新增

```
FuseInspectorPlugin._collect_insts_from_trigger_report(report: Dictionary) -> Array
```

- 私有方法
- 从 `analyze_trigger` 的 report 结构中收集所有指令 inst
- 返回 `Array[BaseInstruction]`（flat 列表）
- 优先收集 `instructions_tree` 中的 inst（含 event_bindings 嵌套）

### `FuseInspectorPlugin._collect_insts_from_tree` 新增

```
FuseInspectorPlugin._collect_insts_from_tree(tree: Array) -> Array
```

- 递归收集嵌套 `instructions_tree` 中的 inst

### `FuseInspectorPlugin._add_problems_section` 新增

```
FuseInspectorPlugin._add_problems_section(content: VBoxContainer, report: Dictionary) -> void
```

- 在数据流卡片中新增问题段
- 根据 `report.problems.summary` 决定显示"无"还是列具体问题

### 无外部签名变更

所有新增方法均为 `fuse_inspector_plugin.gd` 的私有方法。`analyze_problems` 和 `_index_problems` 复用已有公开/私有 API。

---

## 5. 测试策略

### 5.1 手动验证（Inspector 交互）

**`test_inspector_button_error_badge`**
- 在场景中放置一个 Trigger，其指令使用未声明的局部变量
- 选中 Trigger → Inspector 底部数据流卡片按钮
- 预期：按钮文本末尾显示 `🔴N`（err_count > 0）

**`test_inspector_button_warning_badge`**
- Trigger 指令含无效 NodePath（需要在场景中注入）
- 预期：按钮文本末尾显示 `🟡N`（warn_count > 0）

**`test_inspector_button_clean`**
- Trigger 无问题
- 预期：按钮文本无角标后缀

**`test_inspector_card_problems_section`**
- 展开数据流卡片
- Trigger 有问题 → 卡片底部显示"问题: 🔴N 错误 🟡M 警告" + 具体 message 列表
- Trigger 无问题 → 卡片显示"问题: (无)"

**`test_inspector_card_empty_trigger`**
- Trigger 无指令
- 预期：问题段显示"问题: (无)"

### 5.2 单元测试（`test_fuse_inspector_plugin.gd` 或 `test_instruction_analyzer_problems.gd`）

**`test_collect_insts_from_trigger_report`**
- 构造含 `instructions_tree` 的 report
- 调用 `_collect_insts_from_trigger_report`
- 预期：返回数组长度 > 0，每个元素是 `BaseInstruction` 实例

**`test_collect_insts_from_tree_recursive`**
- 含嵌套分支（`then` / `else`）的 instructions_tree
- 预期：返回数组包含所有嵌套层的 inst

**`test_problems_empty_when_no_instructions`**
- report 的 `instructions_flat` 和 `instructions_tree` 均为空
- `analyze_problems([])` → `problems` 空 → summary 全 0

### 5.3 回归

- Topology 的 `_collect_insts_from_report` / `_collect_insts_from_tree` 不变，不受影响
- Inspector 现有数据流卡片内容（事件、节点、变量、信号、指令链）不变
- 按钮展开/折叠行为不变

---

## 6. 实现步骤

### Phase 1：收集指令 inst 的方法

**文件**: `addons/fuse/editor/fuse_inspector_plugin.gd`

1. 新增 `_collect_insts_from_trigger_report(report: Dictionary) -> Array`
2. 新增 `_collect_insts_from_tree(tree: Array) -> Array`

**验收**：
- [ ] 从含 instructions_tree 的 report 中收集到所有 inst
- [ ] 从含 event_bindings 的 report 中收集到所有 binding 内的 inst
- [ ] 空 report → 返回空数组

### Phase 2：`_parse_end` 注入问题分析

**文件**: `addons/fuse/editor/fuse_inspector_plugin.gd`

1. `_parse_end` 中 `analyze_trigger` 后新增：
   - 收集 inst
   - 调用 `analyze_problems(insts)`
   - 调用 `_index_problems(analysis.problems)` 注入 `report["problems"]`

**验收**：
- [ ] 含未声明变量 Trigger → `report.problems.summary.errors > 0`
- [ ] 无问题 Trigger → `report.problems.summary.errors == 0`
- [ ] 收集体已在 EventBinding 场景覆盖

### Phase 3：按钮角标 + 颜色警示

**文件**: `addons/fuse/editor/fuse_inspector_plugin.gd`

1. `_add_dataflow_ui` 中计算 problem_suffix
2. 按钮文本末尾追加计数（`🔴N 🟡M`）
3. 根据 err_count / warn_count 设置按钮字体颜色

**验收**：
- [ ] 有问题 Trigger → 按钮文本含 `🔴N` / `🟡M`
- [ ] 无问题 Trigger → 按钮文本无后缀
- [ ] 有 error → 按钮文字显示红色

### Phase 4：卡片问题段

**文件**: `addons/fuse/editor/fuse_inspector_plugin.gd`

1. 新增 `_add_problems_section(content, report)`
2. 在 `_create_dataflow_card` 末尾调用
3. 按 severity 分组显示具体问题消息（去重）

**验收**：
- [ ] 有问题 Trigger → 展开卡片后显示 "问题: 🔴N 错误 🟡M 警告" + 消息列表
- [ ] 无问题 Trigger → 显示 "问题: (无)"
- [ ] 消息列表按去重显示（同变量不重复）

---

## 7. 不做（YAGNI）

| 项 | 原因 |
|----|------|
| **实时刷新**（属性编辑后自动重算 `analyze_problems`） | 与 Roadmap 设计原则一致——静态分析不做实时。用户需重选 Trigger 或切到 Topology 刷新 |
| **NodePath 解析检测在 Inspector 中** | Inspector 无 `scene_root` 上下文——需要从 `_current_node` 获取 `EditorInterface.get_edited_scene_root()`。若要做，需确保 `_current_node` 在场景树中（`is_inside_tree()`） |
| **信号引用检测在 Inspector 中** | 同 NodePath——需要 `scene_root` 上下文。Phase 1 跳过信号，只在 Topology 中做 |
| **点击问题跳转到 Topology** | Inspector 与 Topology 是同一 EditorPlugin 内的不同 Tab——跳转逻辑需要切换主屏 Tab，复杂度高于当前可行性 |
| **将问题标记在 Inspector 的属性行上**（如某属性对应未声明变量，在属性行旁显示 🔴） | 需要 `_parse_property` 层级集成 + 在编辑器属性控件上加自定义角标——UI 复杂度高，排期外 |

---

## 8. 风险

| 风险 | 影响 | 缓解 |
|------|------|------|
| `analyze_trigger` + `analyze_problems` 双重调用增加 Inspector 响应时间 | 选中 Trigger 时轻微延迟（< 20ms） | 纯反射提取 + 单 Trigger 分析 O(N)，N 为该 Trigger 的指令数（通常 ≤ 50），无性能瓶颈 |
| `_index_problems` 是 Topology 的私有方法，Inspector 不可用 | Inspector 无法索引 problems | 将 `_index_problems` 提取到 `InstructionAnalyzer` 的公开方法，或直接在 Inspector 内复制简化版索引逻辑。推荐前者——`_index_problems` 本身是工具方法，与 Topology 无耦合 |
| `report["problems"]` 字段名与 `_add_dataflow_ui` 的 report 结构约定 | 与 Topology 的 report.problems 结构一致 | 写入前确认结构匹配：`{by_inst: {int → [problem]}, summary: {errors, warnings}}` |
| `analyze_problems` 的 scene_root 在 Inspector 中为 null | NodePath 检测 + 信号检测无法工作 | 这是有意的——Inspector 中仅运行变量检测（不需要 scene_root），NodePath/信号检测在 Topology 刷新时覆盖 |
| 当前测试框架无法实例化 `EditorInspectorPlugin` | Inspector 级别测试只能手动验证 | 将 `_collect_insts_from_trigger_report` 和 `_collect_insts_from_tree` 抽象为 `InstructionAnalyzer` 的公开方法后可在测试框架中直接测试 |

---

## 9. 验收标准

- [ ] `_parse_end` 在 Trigger 选中时自动运行 `analyze_problems` 并将结果注入 report
- [ ] 数据流卡片按钮文本显示问题计数角标（`🔴N 🟡M`）
- [ ] 有 error 时按钮颜色变为红色
- [ ] 展开数据流卡片显示问题详情（汇总 + 具体消息列表，去重）
- [ ] 无问题 Trigger → 按钮无角标，卡片显示"问题: (无)"
- [ ] `_index_problems` 移至 `InstructionAnalyzer` 公开方法（或等价）
- [ ] E3 的 variable_analysis 范围正确渲染
- [ ] Roadmap 中 E5 标记为 "spec 完成"

---

## 10. 修改文件清单

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `addons/fuse/editor/fuse_inspector_plugin.gd` | 修改 | `_parse_end` 注入 analyze_problems；`_add_dataflow_ui` 加角标；`_create_dataflow_card` 追加问题段；新增 `_collect_insts_from_trigger_report` + `_collect_insts_from_tree` + `_add_problems_section` |
| `addons/fuse/editor/topology/fuse_topology.gd` | 修改 | `_index_problems` 提升为公开静态方法，或迁至 `InstructionAnalyzer` |
| `addons/fuse/editor/analysis/instruction_analyzer.gd` | 可选 | 若抽取 `_index_problems`，增加公开方法 `index_problems(problems)` |
| `addons/fuse/tests/test_instruction_analyzer_problems.gd` | 新增用例 | `_collect_insts` 相关测试 |

---

*本 spec 批准后，下一步：invoke writing-plans 生成实现计划。*
