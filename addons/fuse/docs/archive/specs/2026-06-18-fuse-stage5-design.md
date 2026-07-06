# Fuse Stage 5+6+7: 数据流可视化 + 多层级 Preset + 变量监视器 V2 — 设计文档

**日期:** 2026-06-18
**基线:** Stage 1-4 完成(183 组件), 架构整改全链闭环, 预设系统/变量监视器 V1 可用
**目标:** Stage 5(数据流可视化) | Stage 6(多层级 Preset) | Stage 7(变量监视器 V2) — 三个独立并行任务

---

## 1. 子任务总览

| # | 子任务 | 复杂度 | 工时 | 依赖 |
|---|--------|:---:|:--:|------|
| 5a | 逻辑流引擎 + Inspector 单 Trigger 卡片 | 高 | 3-4天 | — |
| 5b | 全场景拓扑(主屏幕 Tab) | 高 | 2-3天 | 5a 解析引擎 |
| 5c | 多层级 Preset 导出 | 中 | 2-3天 | Stage 2 Preset V1 |
| 5d | 变量监视器 V2 | 中 | 1-2天 | Stage 2c V1 |

> **已移除:** Snippet(多选指令片段) — 在 Fuse 语境下用处不大,被多层级 Preset 替代。

---

## 2. Stage 5: 逻辑流引擎 + Inspector 卡片

### 2.1 目标

选中场景 Trigger 节点时,在 Inspector 底部自动显示该 Trigger 的数据流卡片:监听信号、操作节点、变量读写、控制流嵌套、输出信号。

### 2.2 解析引擎 — `InstructionAnalyzer`

**新工具类:** `addons/fuse/editor/analysis/instruction_analyzer.gd`

静态规则匹配(方案 A):按属性名模式提取引用,不侵入指令基类。

```gdscript
class_name InstructionAnalyzer
extends RefCounted

# 属性名模式映射
const _NODE_PATH_PATTERNS := [
    "target_node", "agent_node", "camera_node", "area_node",
    "parent_node", "source_node"
]
const _VARIABLE_PATTERNS := ["variable_name", "target_variable", "from_variable"]
const _SUB_INSTRUCTIONS := ["instructions", "else_instructions", "then_instructions"]
const _SIGNAL_NAME_PROP := "signal_name"


## 解析单个 Trigger,返回结构化数据流报告
static func analyze_trigger(trigger: Node) -> Dictionary:
    var report := {
        "trigger_name": trigger.name,
        "trigger_path": str(trigger.get_path()),
        "event": _extract_event(trigger),
        "nodes": [],
        "variables": {"local": [], "scope": [], "global": []},
        "signals": [],
        "instructions_flat": []
    }
    var runner = _find_runner(trigger)
    if runner == null: return report
    var ar = runner.get("action_runner")
    if ar == null: return report

    _analyze_instructions(ar.instructions, report, "")
    _extract_signals(trigger, runner, report)
    return report


## 递归分析指令树
static func _analyze_instructions(instructions: Array, report: Dictionary, prefix: String) -> void:
    for inst in instructions:
        if inst == null: continue
        report.instructions_flat.append({"name": inst.resource_name, "prefix": prefix})

        # 提取 NodePath 引用
        for prop in inst.get_property_list():
            if prop.type == TYPE_NODE_PATH or prop.name in _NODE_PATH_PATTERNS:
                var np: NodePath = inst.get(prop.name)
                if not np.is_empty() and str(np) not in report.nodes:
                    report.nodes.append(str(np))

        # 提取变量引用
        if "variable_name" in inst and "variable_scope" in inst:
            var scope: int = inst.variable_scope
            var entry := {"name": inst.variable_name}
            if scope == 1 and "scope_source" in inst:
                var source = inst.scope_source  # ScopeSource enum
                if "custom_scope_id" in inst: entry["scope_id"] = inst.custom_scope_id
                if "target_node_path" in inst: entry["target"] = str(inst.target_node_path)
            match scope:
                0: report.variables.local.append(entry)
                1: report.variables.scope.append(entry)
                2: report.variables.global.append(entry)

        # 递归嵌套指令
        for sub_key in _SUB_INSTRUCTIONS:
            if sub_key in inst:
                var sub_insts: Array = inst.get(sub_key)
                _analyze_instructions(sub_insts, report, prefix + "  ")


## 提取事件定义
static func _extract_event(trigger: Node) -> Dictionary:
    var ed = trigger.get("event_definition")
    if ed == null: return {}
    return {
        "type": ed.get_script().get_global_name() if ed.get_script() else "",
        "resource_name": ed.get("resource_name", "")
    }


## 提取 Runner 信号
static func _extract_signals(trigger: Node, runner: Node, report: Dictionary) -> void:
    var signal_name = runner.get("signal_name")
    var target_path = runner.get("target_node")
    if signal_name != null and not str(signal_name).is_empty():
        report.signals.append({
            "signal": str(signal_name),
            "target": str(target_path) if target_path != null else ""
        })
```

### 2.3 Inspector 内嵌卡片

在 `fuse_inspector_plugin.gd` 的 `_parse_property` 末尾,检测对象为 `BaseTrigger` 类型时,在底部追加数据流卡片:

```gdscript
# 在 fuse_inspector_plugin._parse_property() 末尾:
if object is BaseTrigger:
    var report = InstructionAnalyzer.analyze_trigger(object)
    _add_dataflow_card(report)
```

卡片用 `VBoxContainer` + `Label` 构建,显示:
- 事件信息(类型+resource_name)
- 节点引用列表(去重后的 NodePath)
- 变量列表(按作用域分组:local/scope/global)
- 信号连接(如果有)

### 2.4 验收标准

- [ ] 选中 Trigger 节点后,Inspector 底部出现数据流卡片
- [ ] 显示:事件类型、节点引用、变量引用(含作用域)、信号连接
- [ ] 嵌套 if/else/for 指令的引用被递归收集
- [ ] 无指令的 Trigger 显示"(空)"
- [ ] 选中非 Trigger 节点时卡片消失

---

## 3. Stage 5b: 全场景拓扑(主屏幕 Tab)

### 3.1 目标

主屏幕插件 Tab "Fuse",显示当前场景所有 Trigger 的拓扑关系图。左侧 Trigger 列表(树形) + 右侧全局关系面板(跨 Trigger 连线)。

### 3.2 主屏幕插件

**新文件:** `addons/fuse/editor/topology/fuse_topology.gd`

```gdscript
@tool
class_name FuseTopology
extends VBoxContainer

var _trigger_tree: Tree
var _detail_panel: VBoxContainer


func _init() -> void:
    var hsplit := HSplitContainer.new()
    add_child(hsplit)

    _trigger_tree = Tree.new()
    _trigger_tree.hide_root = true
    _trigger_tree.item_selected.connect(_on_trigger_selected)
    hsplit.add_child(_trigger_tree)

    _detail_panel = VBoxContainer.new()
    hsplit.add_child(_detail_panel)


func refresh() -> void:
    _trigger_tree.clear()
    var root := _trigger_tree.create_item()
    var editor = EditorInterface.get_singleton()
    if editor == null: return
    var scene_root = editor.get_edited_scene_root()
    if scene_root == null: return

    var triggers: Array[Node] = scene_root.find_children("*", "BaseTrigger")
    if triggers.is_empty():
        var note := _trigger_tree.create_item(root)
        note.set_text(0, "(场景中无 Trigger)")

    for trigger in triggers:
        var t_item := _trigger_tree.create_item(root)
        t_item.set_text(0, trigger.name)
        t_item.set_metadata(0, {"trigger": trigger})

        var report = InstructionAnalyzer.analyze_trigger(trigger)
        t_item.set_text(1, report.get("event", {}).get("resource_name", "?"))

        # 子项:指令列表
        for inst_info in report.instructions_flat:
            var i_item := _trigger_tree.create_item(t_item)
            i_item.set_text(0, inst_info.prefix + inst_info.name)


func _on_trigger_selected() -> void:
    var item := _trigger_tree.get_selected()
    var meta = item.get_metadata(0)
    if meta == null: return
    var trigger = meta.get("trigger")
    if trigger == null: return
    var report = InstructionAnalyzer.analyze_trigger(trigger)
    _show_detail(report)


func _show_detail(report: Dictionary) -> void:
    _detail_panel.clear()
    # 复用 5a 的卡片渲染逻辑
```

### 3.3 注册为主屏幕插件

在 `plugin.gd` 的 `_enter_tree()` 中:

```gdscript
var _topology: FuseTopology = null
# ...
_topology = preload("res://addons/fuse/editor/topology/fuse_topology.gd").new()
add_control_to_bottom_panel(_topology, "Fuse")  # 先放底部,后续改主屏幕
```

> **V1 放底部 Dock,快速验证。V2 升级为 `EditorPlugin._has_main_screen()` + `_get_plugin_name()` 主屏幕 Tab。**

### 3.4 全局关联扫描

在 `InstructionAnalyzer` 中新增静态方法:

```gdscript
## 扫描场景所有 Trigger,构建全局关系图
static func build_topology(scene_root: Node) -> Dictionary:
    var topology := {
        "triggers": [],
        "cross_references": []
    }
    var all_reports := {}
    var triggers: Array[Node] = scene_root.find_children("*", "BaseTrigger")

    for trigger in triggers:
        var report = analyze_trigger(trigger)
        all_reports[trigger.name] = report
        topology.triggers.append(report)

    # 跨 Trigger 关联
    for t1_name in all_reports:
        var r1 = all_reports[t1_name]
        for signal_info in r1.signals:
            var target = signal_info.get("target", "")
            for t2_name in all_reports:
                if t2_name == t1_name: continue
                if target.contains(t2_name):
                    topology.cross_references.append({
                        "from": t1_name, "to": t2_name,
                        "type": "signal", "detail": signal_info.signal
                    })

    return topology
```

### 3.5 验收标准

- [ ] 底部 Dock 新增"Fuse 拓扑"Tab,显示场景所有 Trigger 的树形列表
- [ ] 点击 Trigger → 右侧显示完整数据流(节点/变量/信号)
- [ ] 全局关系面板:列出跨 Trigger 的连线(signal/共享变量)
- [ ] 树中每条指令以名称+图标显示,嵌套带缩进
- [ ] 场景变更时面板自动刷新

---

## 4. Stage 6: 多层级 Preset 导出

### 4.1 目标

将 Preset 从"仅 ActionRunner 级别"(Stage 2 L1)提升到四个层次,用户可导出/分享不同粒度的逻辑。

### 4.2 四个层次

| 层次 | 导出内容 | 示例 | JSON 结构 |
|------|---------|------|-----------|
| **L1** ActionRunner | instructions 数组 | "这套淡入淡出动画" | 当前 FusePreset(已有) |
| **L2** Trigger | 事件定义 + ActionRunner | "弹幕生成器:OnInterval→Spawn→Tween" | `{event, action_runner: {instructions}}` |
| **L3** Runner | 信号绑定 + Trigger | "按钮交互:pressed→Trigger" | `{signal_name, target_node, trigger: {event, action_runner}}` |
| **L4** MultiEventTrigger | 多事件 + 多条 ActionRunner | "Boss 战斗:多阶段" | `{events: [...], triggers: [...]}` |

### 4.3 实现

**扩展 `FusePreset` 加一个 `level` 字段:**

```gdscript
@export var level: int = 1  # 1-4
@export var event_definition: Resource = null      # L2+
@export var trigger_data: Dictionary = {}          # L2+: 组合 event+action_runner
@export var runner_data: Dictionary = {}           # L3+: signal_name + target_node
@export var multi_events: Array[Dictionary] = []   # L4: 多事件/Trigger 组合
```

**导出入口:** 在 Inspector 中,根据选中的节点类型自动检测层级:

- 选中的是 ActionRunner Resource → L1 导出
- 选中的是 Trigger 节点 → L2 导出
- 选中的是 Runner 节点 → L3 导出
- 选中的是 MultiEventTrigger → L4 导出

**JSON 格式(L2 示例):**
```json
{
  "format_version": "1.0",
  "level": 2,
  "display_name": "弹幕生成器",
  "category": "combat",
  "event": {
    "type": "OnInterval",
    "interval_seconds": 1.5,
    "trigger_on_start": true
  },
  "action_runner": {
    "instructions": [...]
  }
}
```

**导入:** 根据 `level` 字段创建对应节点:
- L1: 导入到当前 ActionRunner.instructions(现有行为)
- L2: 创建 Trigger 节点 + 设置 event_definition + action_runner
- L3: 创建 Runner 节点 + 设置 signal_name + target_node + Trigger
- L4: 创建 MultiEventTrigger 节点

### 4.4 验收标准

- [ ] L1 导出/导入:当前 Preset 行为不变
- [ ] L2 导出:选中 Trigger 节点 →"导出为预设"→ JSON 含 event + action_runner
- [ ] L2 导入:选择 L2 JSON → 自动创建 Trigger 节点(含事件定义+指令)
- [ ] L3 导出:选中 Runner 节点 → JSON 含 signal + target + trigger
- [ ] L4 导出:选中 MultiEventTrigger → JSON 含多事件/Trigger 组合
- [ ] NodePath 映射:跨场景导入时,自动匹配同名节点(复用 Stage 2 逻辑)
- [ ] 预设面板显示 level 标签(L1/L2/L3/L4)

---

## 5. Stage 7: 变量监视器 V2

### 5.1 目标

在 V1 基础上增加:运行时修改变量值(双击编辑)、类型安全赋值、历史值折线图。

### 5.2 实现

- **编辑:** 双击 Tree 中的变量值 → `LineEdit` 覆盖 → Enter 确认 → `VariableOperations.set_variable()`
- **折线图:** 维护最近 60 次快照(1s 间隔),用 `Control.draw_line()` 在底部绘制迷你折线图

### 5.3 验收标准

- [ ] 双击变量值可编辑,Enter 确认后值更新
- [ ] 数值变量(Int/Float)显示最近 60s 折线图
- [ ] 非数值变量忽略折线图

---

## 6. 文件清单

**新增:**
```
addons/fuse/editor/analysis/instruction_analyzer.gd       # 5a 解析引擎
addons/fuse/editor/topology/fuse_topology.gd               # 5b 拓扑面板
```

**修改:**
```
addons/fuse/core/resources/fuse_preset.gd                  # 5c 加 level + 多层级字段
addons/fuse/editor/fuse_inspector_plugin.gd                # 5a 卡片 + 5c 多层级导出入口
addons/fuse/editor/instruction_selector/instructions_array_inspector_plugin.gd  # 5c L1 已有
addons/fuse/editor/debugging/variable_watcher.gd           # 5d V2 升级
addons/fuse/plugin.gd                                      # 注册拓扑面板
```

---

## 7. 不做什么

- ❌ GraphEdit 连线图(5b V2)
- ❌ 逻辑流编辑/拖拽/右键菜单
- ❌ Snippet 参数映射
- ❌ 变量监视器离线模式

---

**文档版本:** 1.0
**最后更新:** 2026-06-18
**审核状态:** 待审核
