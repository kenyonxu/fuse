# Fuse Stage 5: 数据流可视化 — 实施规格

**版本:** 1.0
**日期:** 2026-06-18
**基线:** Stage 1-4 完成(183 组件), 架构整改全链闭环
**目标:** 实现逻辑流可视化 — 单 Trigger 数据流卡片 + 全场景拓扑面板

> **📋 完成状态（2026-06-18）** — Task 5.1+5.2 完成。InstructionAnalyzer 解析引擎 + Inspector 数据流卡片。Task 5.3(拓扑面板)已完成。

> **For agentic workers:** REQUIRED SUB-SKILL: 用 superpowers:subagent-driven-development(推荐)或 superpowers:executing-plans 逐任务实现本计划。步骤使用复选框(`- [ ]`)语法跟踪。

---

## 子任务总览

| # | 子任务 | 复杂度 | 工时 | 产出 |
|---|--------|:---:|:--:|------|
| 5.1 | InstructionAnalyzer 解析引擎 | 中 | 1天 | `instruction_analyzer.gd` |
| 5.2 | Inspector 数据流卡片 | 中 | 1-2天 | 修改 `fuse_inspector_plugin.gd` |
| 5.3 | 全场景拓扑面板 | 中 | 1-2天 | `fuse_topology.gd` + plugin 注册 |
| 5.4 | 回归验证 | 低 | 0.5天 | — |

**依赖:** 5.1 → 5.2 ⋮ 5.3(5.2 和 5.3 都依赖 5.1 的引擎,两者可并行)

---

## Task 5.1: InstructionAnalyzer 解析引擎

**Files:**
- Create: `addons/fuse/editor/analysis/instruction_analyzer.gd`
- Create: `addons/fuse/editor/analysis/instruction_analyzer.gd.uid`

- [x] **Step 1:创建 InstructionAnalyzer** ✅ 已完成（commit 2620b36）

创建 `addons/fuse/editor/analysis/instruction_analyzer.gd`:

```gdscript
@tool
class_name InstructionAnalyzer
extends RefCounted

## 指令静态分析器
##
## 按属性名模式提取引用信息,不侵入指令基类。
## 支持:NodePath 引用、变量引用、信号、控制流嵌套指令。

# 属性名模式映射
const _NODE_PATH_PATTERNS := [
	"target_node", "agent_node", "camera_node", "area_node",
	"parent_node", "source_node"
]
const _VARIABLE_PROP := "variable_name"
const _SCOPE_PROP := "variable_scope"
const _SUB_INSTRUCTIONS := ["instructions", "else_instructions", "loop_instructions"]


## 解析单个 Trigger,返回结构化数据流报告
static func analyze_trigger(trigger: Node) -> Dictionary:
	var report := {
		"trigger_name": trigger.name,
		"trigger_path": str(trigger.get_path()),
		"trigger_type": trigger.get_class(),
		"event": _extract_event(trigger),
		"nodes": [],
		"variables": {"local": [], "scope": [], "global": []},
		"signals": [],
		"instructions_flat": []
	}

	# 查找 Runner 子节点
	var runner = _find_child_of_type(trigger, "Runner")
	if runner == null:
		return report

	var action_runner = runner.get("action_runner")
	if action_runner == null:
		return report

	_analyze_instructions(action_runner.instructions, report, "")
	_extract_runner_signals(runner, report)
	return report


## 递归分析指令树
static func _analyze_instructions(instructions: Array, report: Dictionary, prefix: String) -> void:
	if instructions == null:
		return
	for inst in instructions:
		if inst == null:
			continue

		var display_name := inst.resource_name
		if display_name.is_empty():
			display_name = inst.get_class()
		report.instructions_flat.append({"name": display_name, "prefix": prefix})

		# NodePath 引用
		_extract_nodepaths(inst, report)

		# 变量引用
		_extract_variables(inst, report)

		# 递归嵌套
		for sub_key in _SUB_INSTRUCTIONS:
			if sub_key in inst:
				var sub: Array = inst.get(sub_key)
				_analyze_instructions(sub, report, prefix + "  ")


## 提取指令中的 NodePath 引用
static func _extract_nodepaths(inst, report: Dictionary) -> void:
	for prop in inst.get_property_list():
		if prop.type == TYPE_NODE_PATH or prop.name in _NODE_PATH_PATTERNS:
			var np: NodePath = inst.get(prop.name)
			var s := str(np)
			if not s.is_empty() and s not in report.nodes:
				report.nodes.append(s)


## 提取指令中的变量引用
static func _extract_variables(inst, report: Dictionary) -> void:
	if not (_VARIABLE_PROP in inst):
		return
	var scope: int = inst.get(_SCOPE_PROP) if _SCOPE_PROP in inst else 0
	var name: String = inst.get(_VARIABLE_PROP)
	if name.is_empty():
		return

	var entry := {"name": name}
	if scope == 1:  # SCOPE
		if "scope_source" in inst:
			entry["source"] = inst.scope_source
		if "custom_scope_id" in inst:
			entry["scope_id"] = inst.custom_scope_id
		if "target_node_path" in inst:
			entry["target"] = str(inst.target_node_path)

	match scope:
		0: report.variables.local.append(entry)
		1: report.variables.scope.append(entry)
		2: report.variables.global.append(entry)


## 提取 Trigger 的事件定义
static func _extract_event(trigger: Node) -> Dictionary:
	var ed = trigger.get("event_definition")
	if ed == null:
		return {}
	var script = ed.get_script()
	return {
		"type": script.get_global_name() if script else "?",
		"resource_name": ed.get("resource_name", "")
	}


## 提取 Runner 的信号信息
static func _extract_runner_signals(runner: Node, report: Dictionary) -> void:
	var sig = runner.get("signal_name")
	var target = runner.get("target_node")
	if sig != null:
		var s := str(sig)
		if not s.is_empty():
			report.signals.append({
				"signal": s,
				"target": str(target) if target != null else ""
			})


## 在节点的子节点中查找特定类型的节点
static func _find_child_of_type(parent: Node, type_name: String) -> Node:
	for child in parent.get_children():
		if child.get_class() == type_name:
			return child
	return null


# ---- 全场景拓扑 ----

## 扫描场景所有 Trigger,构建全局关系图
static func build_topology(scene_root: Node) -> Dictionary:
	var topology := {
		"scene_name": scene_root.name,
		"triggers": [],
		"cross_references": []
	}
	var all_reports := {}
	var triggers: Array[Node] = scene_root.find_children("*", "Trigger")
	triggers.append_array(scene_root.find_children("*", "MultiEventTrigger"))

	for trigger in triggers:
		var report := analyze_trigger(trigger)
		all_reports[trigger.name] = report
		topology.triggers.append(report)

	# 跨 Trigger 关联:信号连接
	for t1_name in all_reports:
		var r1 = all_reports[t1_name]
		for signal_info in r1.signals:
			var target := signal_info.get("target", "")
			for t2_name in all_reports:
				if t2_name == t1_name:
					continue
				if target.find(t2_name) != -1:
					topology.cross_references.append({
						"from": t1_name, "to": t2_name,
						"type": "signal", "detail": signal_info.signal
					})

	# 跨 Trigger 关联:共享全局变量
	var global_vars_used := {}
	for t_name in all_reports:
		for var_entry in all_reports[t_name].variables.global:
			var vname := var_entry.name
			if not global_vars_used.has(vname):
				global_vars_used[vname] = []
			global_vars_used[vname].append(t_name)

	for vname in global_vars_used:
		var users = global_vars_used[vname]
		if users.size() > 1:
			for i in range(users.size()):
				for j in range(i + 1, users.size()):
					topology.cross_references.append({
						"from": users[i], "to": users[j],
						"type": "shared_global_variable", "detail": vname
					})

	return topology
```

- [x] **Step 2:验证解析引擎** ✅ 已完成

在 `demos/fuse/brickian/title_scene.tscn` 上测试(该场景有 5 个 Trigger):

1. Godot 编辑器打开场景
2. 在 Script 编辑器中运行临时测试脚本:

```gdscript
# 在 Script Editor 中临时执行:
var scene = EditorInterface.get_edited_scene_root()
var report = InstructionAnalyzer.analyze_trigger(scene.find_child("HintBreath", true, false))
print(report)
```

预期:`report.nodes` 包含 `".."`,`report.signals` 包含 `"event_stopped"`,`report.variables` 为空(无变量操作)。

3. 运行 `build_topology(scene)` 预期:5 个 Trigger,至少 1 条跨 Trigger 关联。

- [x] **Step 3:commit** ✅ 已完成

```bash
git add addons/fuse/editor/analysis/
git commit -m "feat(fuse): add InstructionAnalyzer — static instruction parser (stage5 task5.1)"
```

---

## Task 5.2: Inspector 数据流卡片

**Files:**
- Modify: `addons/fuse/editor/fuse_inspector_plugin.gd`(加 BaseTrigger 检测 + 卡片渲染)

- [x] **Step 1:在 fuse_inspector_plugin.gd 末尾加卡片渲染方法** ✅ 已完成（commit 63a3c17）

在 `fuse_inspector_plugin.gd` 的 `_parse_property()` 末尾(已有 Event/Condition 处理之后)追加:

```gdscript
	# Stage 5: BaseTrigger 数据流卡片
	if object is BaseTrigger:
		var report = InstructionAnalyzer.analyze_trigger(object)
		_add_dataflow_card(report)
		return true  # 已处理,不继续

	return false  # 原有的最终 return
```

新增方法:

```gdscript
func _add_dataflow_card(report: Dictionary) -> void:
	var card := VBoxContainer.new()
	card.add_child(_make_section_label("数据流"))

	if report.instructions_flat.is_empty():
		card.add_child(_make_info_line("(该 Trigger 无指令)"))
		add_custom_control(card)
		return

	# 事件
	if not report.event.is_empty():
		card.add_child(_make_info_line("事件: %s" % report.event.get("resource_name", "?")))

	# 节点引用
	if not report.nodes.is_empty():
		var nodes_str = ", ".join(report.nodes)
		card.add_child(_make_info_line("操作节点: %s" % nodes_str))

	# 变量
	var var_lines := []
	if not report.variables.local.is_empty():
		var local_strs: Array[String] = []
		for v in report.variables.local:
			local_strs.append(v.name)
		var_lines.append("[local] " + ", ".join(local_strs))
	if not report.variables.scope.is_empty():
		var scope_strs: Array[String] = []
		for v in report.variables.scope:
			scope_strs.append(v.name)
		var_lines.append("[scope] " + ", ".join(scope_strs))
	if not report.variables.global.is_empty():
		var global_strs: Array[String] = []
		for v in report.variables.global:
			global_strs.append(v.name)
		var_lines.append("[global] " + ", ".join(global_strs))
	if not var_lines.is_empty():
		card.add_child(_make_info_line("变量: %s" % " | ".join(var_lines)))
	else:
		card.add_child(_make_info_line("变量: (无)"))

	# 信号
	if not report.signals.is_empty():
		for sig in report.signals:
			var target := sig.get("target", "")
			card.add_child(_make_info_line("信号: %s → %s" % [sig.signal, target]))
	else:
		card.add_child(_make_info_line("信号: (无)"))

	# 指令列表
	card.add_child(_make_section_label("指令链 (%d 条)" % report.instructions_flat.size()))
	for inst_info in report.instructions_flat:
		card.add_child(_make_info_line("%s📦 %s" % [inst_info.prefix, inst_info.name]))

	add_custom_control(card)


func _make_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	return lbl


func _make_info_line(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = "  " + text
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	return lbl
```

- [x] **Step 2:验证卡片显示** ✅ 已完成

1. Godot 编辑器打开 `title_scene.tscn`
2. 选中 `HintBreath` 节点(Trigger)
3. Inspector 底部应显示数据流卡片:事件、节点、信号、指令链

预期:`事件: 间隔执行: 1.3s...`,`操作节点: ..`,`信号: event_stopped → ...`,`指令链:TweenFadeIn → TweenFadeOut`

4. 选中非 Trigger 节点 → 卡片消失

- [x] **Step 3:commit** ✅ 已完成

```bash
git add addons/fuse/editor/fuse_inspector_plugin.gd
git commit -m "feat(fuse): add data flow card in Inspector for Trigger nodes (stage5 task5.2)"
```

---

## Task 5.3: 全场景拓扑面板

**Files:**
- Create: `addons/fuse/editor/topology/fuse_topology.gd`
- Create: `addons/fuse/editor/topology/fuse_topology.gd.uid`
- Modify: `addons/fuse/plugin.gd`(注册拓扑面板)

- [x] **Step 1:创建 FuseTopology 面板** ✅ 已完成

创建 `addons/fuse/editor/topology/fuse_topology.gd`:

```gdscript
@tool
class_name FuseTopology
extends VBoxContainer

## 全场景拓扑面板 — 底部 Dock Tab
## 左侧 Trigger 树 + 右侧详情 + 全局关联

var _tree: Tree
var _detail: RichTextLabel
var _cross_ref_label: Label
var _refresh_btn: Button


func _init() -> void:
	var banner := HBoxContainer.new()
	add_child(banner)
	var title := Label.new()
	title.text = "Fuse 场景拓扑"
	banner.add_child(title)
	banner.add_spacer(true)
	_refresh_btn = Button.new()
	_refresh_btn.text = "刷新"
	_refresh_btn.pressed.connect(refresh)
	banner.add_child(_refresh_btn)

	var hsplit := HSplitContainer.new()
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(hsplit)

	_tree = Tree.new()
	_tree.hide_root = true
	_tree.columns = 2
	_tree.set_column_title(0, "Trigger")
	_tree.set_column_title(1, "事件")
	_tree.item_selected.connect(_on_item_selected)
	hsplit.add_child(_tree)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.add_child(right)

	_detail = RichTextLabel.new()
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.bbcode_enabled = true
	_detail.fit_content = true
	right.add_child(_detail)

	_cross_ref_label = Label.new()
	_cross_ref_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	right.add_child(_cross_ref_label)

	refresh()


func refresh() -> void:
	_tree.clear()
	_detail.clear()
	_cross_ref_label.text = ""

	var editor = EditorInterface.get_singleton()
	if editor == null:
		return
	var scene_root = editor.get_edited_scene_root()
	if scene_root == null:
		return

	var topology = InstructionAnalyzer.build_topology(scene_root)

	var root := _tree.create_item()
	if topology.triggers.is_empty():
		var note := _tree.create_item(root)
		note.set_text(0, "(场景中无 Trigger)")
		return

	for report in topology.triggers:
		var item := _tree.create_item(root)
		item.set_text(0, report.get("trigger_name", "?"))
		item.set_text(1, report.get("event", {}).get("resource_name", "?"))
		item.set_metadata(0, report)

	# 全局关联
	var ref_lines := PackedStringArray()
	for ref in topology.cross_references:
		var line := "[%s] %s → %s (%s)" % [
			"signal" if ref.type == "signal" else "全局变量",
			ref["from"], ref["to"], ref["detail"]
		]
		ref_lines.append(line)
	if not ref_lines.is_empty():
		_cross_ref_label.text = "跨 Trigger 关联:\n" + "\n".join(ref_lines)
	else:
		_cross_ref_label.text = "跨 Trigger 关联: (无)"


func _on_item_selected() -> void:
	var item := _tree.get_selected()
	if item == null:
		return
	var report = item.get_metadata(0)
	if report == null:
		return

	_detail.clear()
	_detail.append_text("[b]%s[/b] (%s)\n\n" % [report.trigger_name, report.trigger_path])

	if not report.event.is_empty():
		_detail.append_text("事件: %s\n" % report.event.resource_name)

	if not report.nodes.is_empty():
		_detail.append_text("操作节点: %s\n" % ", ".join(report.nodes))

	var var_parts := []
	if not report.variables.local.is_empty():
		var_parts.append("[local] " + ", ".join(report.variables.local))
	if not report.variables.scope.is_empty():
		var_parts.append("[scope] " + ", ".join(report.variables.scope))
	if not report.variables.global.is_empty():
		var_parts.append("[global] " + ", ".join(report.variables.global))
	_detail.append_text("变量: %s\n" % (" | ".join(var_parts) if not var_parts.is_empty() else "(无)"))

	if not report.signals.is_empty():
		_detail.append_text("信号:\n")
		for sig in report.signals:
			_detail.append_text("  %s → %s\n" % [sig.signal, sig.target])

	_detail.append_text("\n指令链:\n")
	for inst_info in report.instructions_flat:
		_detail.append_text("  %s📦 %s\n" % [inst_info.prefix, inst_info.name])
```

- [x] **Step 2:在 plugin.gd 注册拓扑面板** ✅ 已完成

在 `plugin.gd` 的 `_enter_tree()` 中(变量声明区 + 注册):

```gdscript
var _topology: FuseTopology = null
# 在 _enter_tree() 末尾:
_topology = preload("res://addons/fuse/editor/topology/fuse_topology.gd").new()
add_control_to_bottom_panel(_topology, "Fuse 拓扑")
print("Fuse 拓扑面板已注册")
```

在 `_exit_tree()` 中移除:

```gdscript
if _topology:
    _topology.queue_free()
    _topology = null
```

- [x] **Step 3:验证拓扑面板** ✅ 已完成

1. 打开 `title_scene.tscn`
2. 底部 Dock 出现"Fuse 拓扑"Tab
3. 左侧树显示 5 个 Trigger,右侧选中 Trigger 时显示详情
4. 全局关联面板显示跨 Trigger 连线(如有)
5. "刷新"按钮:修改场景后点刷新更新

- [x] **Step 4:commit** ✅ 已完成

```bash
git add addons/fuse/editor/topology/ addons/fuse/plugin.gd
git commit -m "feat(fuse): add topology panel — full scene trigger analysis (stage5 task5.3)"
```

---

## Task 5.4: 验证 + 回归

- [ ] 打开含 Trigger 的场景 → Inspector 卡片正常
- [ ] 底部 Dock "Fuse 拓扑" Tab 正常
- [ ] 嵌套 if/else/for 指令的递归收集正确
- [ ] 空场景或空 Trigger 不报错
- [ ] 插件启用/停用无报错(拓扑面板正确注册/注销)
- [ ] 现有组件功能不受影响

```bash
git add addons/fuse/editor/analysis/ addons/fuse/editor/fuse_inspector_plugin.gd addons/fuse/editor/topology/ addons/fuse/plugin.gd
git commit -m "feat(fuse): stage5 complete — data flow visualization"
```

---

## 文件清单

**新增:**
```
addons/fuse/editor/analysis/instruction_analyzer.gd      # 解析引擎
addons/fuse/editor/topology/fuse_topology.gd              # 拓扑面板
```

**修改:**
```
addons/fuse/editor/fuse_inspector_plugin.gd               # 加 5a 卡片
addons/fuse/plugin.gd                                     # 注册拓扑面板
```

---

**文档版本:** 1.0
**最后更新:** 2026-06-18
**审核状态:** 待审核
