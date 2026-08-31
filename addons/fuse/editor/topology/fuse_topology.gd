# addons/fuse/editor/topology/fuse_topology.gd
@tool
class_name FuseTopology
extends VBoxContainer

## 全场景拓扑面板 — 主屏幕 Tab
##
## 左侧 Trigger 树（嵌套指令 + 图标 + 分支标记）+ 右侧详情面板 + 全局关联扫描。
## 选中 Trigger → 右侧 Trigger 概要；选中指令 → 右侧指令详情。
## 依赖 InstructionAnalyzer 解析引擎。

const TopologyExport := preload("res://addons/fuse/editor/topology/topology_export.gd")

# E6: 问题过滤模式
const FILTER_ALL := 0
const FILTER_ERROR := 1
const FILTER_NONE := 2

var _tree: Tree
var _detail: RichTextLabel
var _graph_edit: FuseGraphEdit  # 保留但降级（不默认显示）
var _cross_ref_label: RichTextLabel
var _refresh_btn: Button
var _last_topology: Dictionary = {}
var _filter_mode: int = FILTER_ALL

const _REFRESH_DEBOUNCE := 0.5
var _refresh_timer: Timer


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# ---- 顶部标题栏 ----
	var banner := HBoxContainer.new()
	add_child(banner)

	var title := Label.new()
	title.text = "Fuse 场景拓扑"
	banner.add_child(title)

	# E6: 问题过滤下拉框
	var filter_label := Label.new()
	filter_label.text = "问题过滤:"
	banner.add_child(filter_label)
	var filter_option := OptionButton.new()
	filter_option.add_item("全部", FILTER_ALL)
	filter_option.add_item("仅错误", FILTER_ERROR)
	filter_option.add_item("无", FILTER_NONE)
	filter_option.select(_filter_mode)
	filter_option.item_selected.connect(_on_filter_changed)
	banner.add_child(filter_option)

	banner.add_spacer(true)

	_refresh_btn = Button.new()
	_refresh_btn.text = "刷新"
	_refresh_btn.pressed.connect(_do_refresh)
	banner.add_child(_refresh_btn)

	_refresh_timer = Timer.new()
	_refresh_timer.one_shot = true
	_refresh_timer.wait_time = _REFRESH_DEBOUNCE
	_refresh_timer.timeout.connect(_do_refresh)
	add_child(_refresh_timer)

	var export_btn := Button.new()
	export_btn.text = "导出问题报告"
	export_btn.pressed.connect(_on_export_problems)
	banner.add_child(export_btn)

	var export_json_btn := Button.new()
	export_json_btn.text = "导出 JSON"
	export_json_btn.pressed.connect(_on_export_json)
	banner.add_child(export_json_btn)

	# ---- 左右分栏 ----
	var hsplit := HSplitContainer.new()
	hsplit.split_offset = 300
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(hsplit)

	# 左侧：Trigger 树
	_tree = Tree.new()
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.hide_root = true
	_tree.columns = 2
	_tree.set_column_title(0, "Trigger")
	_tree.set_column_title(1, "事件")
	_tree.set_column_expand(0, true)
	_tree.set_column_expand(1, false)
	_tree.allow_reselect = true
	_tree.item_selected.connect(_on_item_selected)
	_tree.item_activated.connect(_on_item_activated)
	hsplit.add_child(_tree)

	# 右侧：详情面板
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.add_child(right)

	_detail = RichTextLabel.new()
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.bbcode_enabled = true
	_detail.fit_content = true
	_detail.selection_enabled = true
	_detail.context_menu_enabled = true
	right.add_child(_detail)

	# GraphEdit 保留但降级（不默认显示，代码不删）
	_graph_edit = FuseGraphEdit.new()
	_graph_edit.visible = false
	_graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph_edit.right_disconnects = false
	right.add_child(_graph_edit)

	_cross_ref_label = RichTextLabel.new()
	_cross_ref_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cross_ref_label.bbcode_enabled = true
	_cross_ref_label.fit_content = true
	_cross_ref_label.selection_enabled = true
	right.add_child(_cross_ref_label)

	refresh()


# ============================================================
# 刷新（Tree 构建）
# ============================================================

## E6: 切换过滤模式 → 重建树
func _on_filter_changed(item_index: int) -> void:
	_filter_mode = item_index
	refresh()


## 请求刷新（防抖：0.5s 内多次请求合并为 1 次；未显示时不刷新）
func request_refresh() -> void:
	if not visible:
		return
	_refresh_timer.start()


## 防抖后实际执行刷新（捕获选中 → refresh → 恢复选中）
func _do_refresh() -> void:
	var selected_key := _capture_selection()
	refresh()
	_restore_selection(selected_key)


## 捕获当前选中项的唯一标识（刷新前调用）
func _capture_selection() -> String:
	var selected := _tree.get_selected()
	if selected == null:
		return ""
	var meta: Dictionary = selected.get_metadata(0)
	var type: String = meta.get("type", "")
	match type:
		"trigger":
			var tn: String = meta.get("report", {}).get("trigger_name", "")
			return "trigger:%s" % tn
		"instruction":
			var trigger_name: String = meta.get("report", {}).get("trigger_name", "")
			var path := _get_tree_path(selected)
			return "instruction:%s:%s" % [trigger_name, path]
		_:
			return ""


## 从 TreeItem 向上遍历到 Trigger 根，记录路径
func _get_tree_path(item: TreeItem) -> String:
	var parts: PackedStringArray = []
	var current: TreeItem = item
	while current != null:
		parts.insert(0, current.get_text(0))
		var parent := current.get_parent()
		if parent == null or parent == _tree.get_root():
			break
		current = parent
	return "/".join(parts)


## 刷新后恢复选中
func _restore_selection(key: String) -> void:
	if key.is_empty():
		return
	var parts := key.split(":", true, 2)
	if parts.size() < 2:
		return
	var type := parts[0]
	var info := parts[1]
	var root := _tree.get_root()
	if root == null:
		return
	var trigger_item := root.get_first_child()
	while trigger_item != null:
		var meta: Variant = trigger_item.get_metadata(0)
		if meta == null or not meta is Dictionary:
			trigger_item = trigger_item.get_next()
			continue
		var trigger_name: String = meta.get("report", {}).get("trigger_name", "")
		if type == "trigger" and info == trigger_name:
			trigger_item.select(0)
			_on_item_selected()
			return
		if type == "instruction":
			var sub_parts := info.split(":", true, 1)
			if sub_parts.size() == 2 and sub_parts[0] == trigger_name:
				var found := _find_tree_item_by_path(trigger_item, sub_parts[1])
				if found:
					found.select(0)
					_on_item_selected()
					return
		trigger_item = trigger_item.get_next()


## 递归查找 TreeItem 匹配路径
func _find_tree_item_by_path(parent: TreeItem, path: String) -> TreeItem:
	var segments := path.split("/")
	if segments.size() == 0:
		return null
	var current: TreeItem = parent
	for segment in segments:
		if segment.is_empty():
			continue
		var found: TreeItem = null
		var child := current.get_first_child()
		while child != null:
			if child.get_text(0) == segment:
				found = child
				break
			child = child.get_next()
		if found == null:
			return null
		current = found
	return current


## 双击条目 → Inspector 跳转到对应节点/资源
func _on_item_activated() -> void:
	var item := _tree.get_selected()
	if item == null:
		return
	var meta: Dictionary = item.get_metadata(0)
	match meta.get("type", ""):
		"trigger":
			var trigger_name: String = meta.get("report", {}).get("trigger_name", "")
			var scene_root := EditorInterface.get_edited_scene_root()
			if scene_root and not trigger_name.is_empty():
				var node: Node = scene_root.find_child(trigger_name, true, false)
				if node:
					EditorInterface.edit_node(node)
		"instruction":
			var inst = meta.get("inst", null)
			if inst is Resource:
				EditorInterface.edit_resource(inst)
		"binding":
			var binding = meta.get("binding", null)
			if binding is Resource:
				EditorInterface.edit_resource(binding)


## 重新扫描当前场景，刷新树和详情
func refresh() -> void:
	_tree.clear()
	_detail.clear()
	_cross_ref_label.text = ""
	_graph_edit.visible = false
	_detail.visible = true

	if not ClassDB.class_exists("EditorInterface"):
		_detail.append_text("[color=gray](编辑器不可用)[/color]")
		return

	var scene_root: Node = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		_detail.append_text("[color=gray](未打开场景)[/color]")
		return

	var topology: Dictionary = InstructionAnalyzer.build_topology(scene_root)
	var root: TreeItem = _tree.create_item()

	if topology.triggers.is_empty():
		var note := _tree.create_item(root)
		note.set_text(0, "(场景中无 Trigger)")
		_cross_ref_label.text = "跨 Trigger 关联: (无)"
		return

	# 注入静态分析结果到每 trigger report（report.problems: {by_inst, summary}）
	# E1: 传 scene_root 触发 NodePath 解析失败检测（warning）
	# E7: predefined_locals 从 event 提取（事件提供的 LOCAL 变量白名单）
	for report in topology.triggers:
		var insts: Array = _collect_insts_from_report(report)
		var provided_locals: Array = _collect_provided_locals(report)
		var analysis := InstructionAnalyzer.analyze_problems(insts, scene_root, provided_locals)
		report["problems"] = _index_problems(analysis.problems)

	# 填充 Trigger 列表（主场景 + 嵌套场景分组）
	var main_reports: Array = []
	var nested_groups: Dictionary = {}  # scene_source → [reports]
	for report in topology.triggers:
		if report.get("is_nested", false):
			var source: String = report.get("scene_source", "?")
			if not nested_groups.has(source):
				nested_groups[source] = []
			nested_groups[source].append(report)
		else:
			main_reports.append(report)

	# 主场景 Trigger
	for report in main_reports:
		_create_trigger_tree_item(root, report)

	# 嵌套场景分组
	for source in nested_groups:
		var group_item: TreeItem = _tree.create_item(root)
		group_item.set_text(0, "📦 %s (嵌套场景)" % source)
		group_item.set_selectable(0, false)
		group_item.set_custom_color(0, Color(0.5, 0.7, 1.0))
		for report in nested_groups[source]:
			_create_trigger_tree_item(group_item, report)

	# 全局关联
	_refresh_cross_references(topology)
	_last_topology = topology


# ============================================================
# Tree 构建（任务 A — 层级嵌套 + 指令可选）
# ============================================================

## 创建 Trigger Tree 项（含指令子树 / EventBinding 子项）
func _create_trigger_tree_item(parent_item: TreeItem, report: Dictionary) -> void:
	var tname: String = report.get("trigger_name", "?")
	var ttype: String = report.get("trigger_type", "?")
	var event_info: Dictionary = report.get("event", {})

	var t_item: TreeItem = _tree.create_item(parent_item)
	t_item.set_text(0, "%s (%s)" % [tname, ttype])
	t_item.set_text(1, event_info.get("resource_name", ""))
	t_item.set_metadata(0, {"type": "trigger", "report": report})

	# 问题汇总标注（按 report.problems.summary + E6 过滤模式）
	var probs: Dictionary = report.get("problems", {"summary": {"errors": 0, "warnings": 0}})
	var n_err: int = probs.get("summary", {}).get("errors", 0)
	var n_warn: int = probs.get("summary", {}).get("warnings", 0)
	# E6: 按过滤模式调整显示计数
	var display_err := 0
	var display_warn := 0
	match _filter_mode:
		FILTER_ALL:
			display_err = n_err
			display_warn = n_warn
		FILTER_ERROR:
			display_err = n_err
			display_warn = 0
		FILTER_NONE:
			display_err = 0
			display_warn = 0
	if display_err > 0:
		var suffix_parts := PackedStringArray()
		suffix_parts.append("%d %s" % [display_err, _severity_label("error")])
		if display_warn > 0:
			suffix_parts.append("%d %s" % [display_warn, _severity_label("warning")])
		t_item.set_custom_color(0, Color(1.0, 0.3, 0.3))
		t_item.set_text(0, t_item.get_text(0) + "  (%s)" % ", ".join(suffix_parts))
		t_item.set_icon(0, _get_theme_icon("StatusError"))
	elif display_warn > 0:
		t_item.set_custom_color(0, Color(1.0, 0.8, 0.3))
		t_item.set_text(0, t_item.get_text(0) + "  (%d %s)" % [display_warn, _severity_label("warning")])
		t_item.set_icon(0, _get_theme_icon("StatusWarning"))

	# MultiEventTrigger：展开 event_bindings
	var bindings: Array = report.get("event_bindings", [])
	if not bindings.is_empty():
		for binding in bindings:
			var b_index: int = binding.get("index", 0)
			var b_event: Dictionary = binding.get("event", {})
			var b_enabled: bool = binding.get("enabled", true)

			var b_item: TreeItem = _tree.create_item(t_item)
			var b_label: String = "[%d] %s" % [b_index, b_event.get("resource_name", "?")]
			if not b_enabled:
				b_label += " (禁用)"
			b_item.set_text(0, b_label)
			b_item.set_metadata(0, {"type": "binding", "binding": binding, "report": report})
			if not b_enabled:
				b_item.set_custom_color(0, Color.GRAY)
			else:
				b_item.set_custom_color(0, Color(0.7, 0.85, 1.0))

			# binding 的指令树
			var b_tree: Array = binding.get("instructions_tree", [])
			if not b_tree.is_empty():
				_build_tree_items(b_item, b_tree, report)
			else:
				for inst_info in binding.get("instructions_flat", []):
					_create_flat_item(b_item, inst_info, report)
		return

	# 普通 Trigger：指令树（优先 tree 嵌套，回退 flat 线性）
	var tree_data: Array = report.get("instructions_tree", [])
	if not tree_data.is_empty():
		_build_tree_items(t_item, tree_data, report)
	else:
		for inst_info in report.get("instructions_flat", []):
			_create_flat_item(t_item, inst_info, report)


## 递归构建指令树（明确 parent + branch label）
func _build_tree_items(parent_item: TreeItem, tree_data: Array, report: Dictionary) -> void:
	for node_info in tree_data:
		var inst = node_info.get("inst")
		var children: Dictionary = node_info.get("children", {})
		var is_branch: bool = not children.is_empty()

		var item: TreeItem = _tree.create_item(parent_item)
		var display_name: String = node_info.get("name", "?")

		# 优先 get_description（实时，避免 resource_name 陈旧），回退 name
		if inst != null and inst.has_method("get_description"):
			var desc: String = inst.get_description()
			if not desc.is_empty():
				display_name = desc

		item.set_text(0, display_name)

		# 图标（任务 B）
		_set_item_icon(item, inst)

		# 可选 + metadata（任务 D 基础）
		item.set_selectable(0, true)
		item.set_metadata(0, {"type": "instruction", "inst": inst, "report": report})

		# 按问题标注指令节点（StatusError/StatusWarning 主题图标 + 着色，E4 + E6 过滤）
		# 问题严重度图标优先于分类图标（_set_item_icon 之后覆盖），错误/警告更需用户注意
		# E6: 按 _filter_mode 决定是否标注——FILTER_NONE 全不标；FILTER_ERROR 仅 error；
		# FILTER_ALL 全标（与 E4 落地后行为一致）
		var inst_problems := _find_problems_for_inst(inst, report)
		var has_problem_color := false
		if _filter_mode != FILTER_NONE and not inst_problems.is_empty():
			var has_error := false
			var has_warning := false
			for p in inst_problems:
				if p.get("severity") == "error":
					has_error = true
				elif p.get("severity") == "warning":
					has_warning = true
			# has_error 分支独立——FILTER_ALL/FILTER_ERROR 两模式下只要有 error 都标
			if has_error:
				item.set_custom_color(0, Color(1.0, 0.3, 0.3))
				item.set_icon(0, _get_theme_icon("StatusError"))
				has_problem_color = true
			# warning 仅 FILTER_ALL 且无 error 时才标
			elif has_warning and _filter_mode == FILTER_ALL:
				item.set_custom_color(0, Color(1.0, 0.8, 0.3))
				item.set_icon(0, _get_theme_icon("StatusWarning"))
				has_problem_color = true

		# 分支颜色（仅当未因问题着色时）
		if is_branch and not has_problem_color:
			item.set_custom_color(0, Color(1.0, 0.65, 0.1))

		# 递归子分支（then ✓ / else ✗ / loop ↻）
		for branch_label in children:
			var subtree: Array = children[branch_label]
			if subtree.is_empty():
				continue
			var branch_item: TreeItem = _tree.create_item(item)
			branch_item.set_text(0, _branch_label_display(branch_label))
			branch_item.set_selectable(0, false)
			branch_item.set_custom_color(0, _branch_color(branch_label))
			_build_tree_items(branch_item, subtree, report)


## 回退：flat 线性构建（无 instructions_tree 时）
func _create_flat_item(parent_item: TreeItem, inst_info: Dictionary, report: Dictionary) -> void:
	var item: TreeItem = _tree.create_item(parent_item)
	var prefix: String = inst_info.get("prefix", "")
	var inst_name: String = inst_info.get("name", "?")

	# 优先 get_description（实时，避免 resource_name 陈旧），回退 name
	var inst = inst_info.get("inst", null)
	if inst != null and inst.has_method("get_description"):
		var desc: String = _strip_bbcode(inst.get_description())
		if not desc.is_empty():
			inst_name = desc

	item.set_text(0, "%s📦 %s" % [prefix, inst_name])
	item.set_selectable(0, true)
	item.set_metadata(0, {"type": "instruction", "inst": inst, "report": report})


func _branch_label_display(p_label: String) -> String:
	match p_label:
		"then": return "✓ then"
		"else": return "✗ else"
		"loop": return "↻ loop"
		_: return p_label


func _branch_color(p_label: String) -> Color:
	match p_label:
		"then": return Color(0.4, 0.9, 0.4)
		"else": return Color(0.9, 0.5, 0.4)
		"loop": return Color(0.4, 0.6, 1.0)
		_: return Color.GRAY


# ============================================================
# 图标（任务 B — builtin icon 优先 + emoji 回退）
# ============================================================

func _set_item_icon(item: TreeItem, inst) -> void:
	if inst == null:
		return

	# 优先 builtin_icon（metadata）
	var icon_name := ""
	var script = inst.get_script()
	if script and script.has_method("_get_instruction_metadata"):
		var metadata = script._get_instruction_metadata()
		icon_name = metadata.builtin_icon

	if not icon_name.is_empty():
		var theme := EditorInterface.get_editor_theme()
		if theme and theme.has_icon(icon_name, "EditorIcons"):
			item.set_icon(0, theme.get_icon(icon_name, "EditorIcons"))
			return

	# 回退：分类 emoji 前缀
	var emoji: String = _category_emoji(inst)
	if not emoji.is_empty():
		var current_text: String = item.get_text(0)
		item.set_text(0, emoji + " " + current_text)


func _category_emoji(inst) -> String:
	var script = inst.get_script()
	if script and script.has_method("_get_instruction_metadata"):
		var category: String = script._get_instruction_metadata().category_key
		if category.find("VARIABLE") >= 0: return "📊"
		if category.find("NODE") >= 0: return "🔧"
		if category.find("AUDIO") >= 0: return "🎵"
		if category.find("UI") >= 0: return "🖼"
		if category.find("ANIMATION") >= 0: return "🎬"
		if category.find("PHYSICS") >= 0: return "⚙"
		if category.find("TWEEN") >= 0: return "✨"
		if category.find("CAMERA") >= 0: return "📷"
	# 流控（指令名判断）
	var name: String = inst.resource_name
	if name.begins_with("If") or name.begins_with("While") or name.begins_with("For"):
		return "🔀"
	return "▶"


# ============================================================
# 参数摘要（任务 C）
# ============================================================

func _get_param_summary(inst) -> String:
	if inst == null:
		return ""
	if inst.has_method("get_description"):
		var desc: String = _strip_bbcode(inst.get_description())
		if not desc.is_empty():
			if desc.length() > 50:
				desc = desc.substr(0, 47) + "..."
			return " — " + desc
	return ""


## 剥离 BBCode 标签（防止用户指令 text 的 BBCode 污染 _detail 渲染状态）
## 如 SetUIText 的 text 含 [font_size=30] 会导致 _detail 后续字体变大
static func _strip_bbcode(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("\\[[^\\]]+\\]")
	return regex.sub(text, "", true)


# ============================================================
# 选中处理（任务 D + E）
# ============================================================

func _on_item_selected() -> void:
	var item: TreeItem = _tree.get_selected()
	if item == null:
		return

	var meta = item.get_metadata(0)
	if meta == null:
		return

	# 统一 RichTextLabel（GraphEdit 不默认显示，任务 E）
	_detail.visible = true
	_graph_edit.visible = false
	_detail.clear()

	var meta_type: String = meta.get("type", "trigger")

	if meta_type == "instruction":
		_show_instruction_detail(meta)
	elif meta_type == "binding":
		_show_binding_detail(meta)
	else:
		_show_trigger_detail(meta.get("report", {}))

	# 追加问题段（任务 5）
	var report: Dictionary = meta.get("report", {})
	if meta_type == "trigger":
		var s: Dictionary = report.get("problems", {}).get("summary", {"errors": 0, "warnings": 0})
		var err_count: int = s.get("errors", 0)
		var warn_count: int = s.get("warnings", 0)
		if err_count > 0 or warn_count > 0:
			var parts := PackedStringArray()
			if err_count > 0:
				parts.append("[color=red]%d %s[/color]" % [err_count, _severity_label("error")])
			if warn_count > 0:
				parts.append("[color=yellow]%d %s[/color]" % [warn_count, _severity_label("warning")])
			_detail.append_text("\n[b]问题（%s）:[/b]\n" % ", ".join(parts))
	elif meta_type == "instruction":
		var inst_problems: Array = _find_problems_for_inst(meta.get("inst", null), report)
		if not inst_problems.is_empty():
			_detail.append_text("\n[b]本指令问题:[/b]\n")
			for p in inst_problems:
				var color := "red" if p.get("severity") == "error" else "yellow"
				_detail.append_text("[color=%s]• %s[/color]\n" % [color, p.get("message", "")])


## 选中 EventBinding → 右侧详情
func _show_binding_detail(meta: Dictionary) -> void:
	var binding: Dictionary = meta.get("binding", {})
	var report: Dictionary = meta.get("report", {})

	var b_event: Dictionary = binding.get("event", {})
	var b_index: int = binding.get("index", 0)
	var b_enabled: bool = binding.get("enabled", true)

	_detail.append_text("[b]EventBinding [%d][/b]\n" % b_index)
	_detail.append_text("[color=gray]所属: %s[/color]\n" % report.get("trigger_name", "?"))
	if b_enabled:
		_detail.append_text("[color=green]启用[/color]\n\n")
	else:
		_detail.append_text("[color=gray]禁用[/color]\n\n")

	# 事件
	if not b_event.is_empty():
		_detail.append_text("[b]事件:[/b] %s [color=gray](%s)[/color]\n" % [b_event.get("resource_name", "?"), b_event.get("type", "?")])

	# 节点引用
	var b_nodes: Array = binding.get("nodes", [])
	if not b_nodes.is_empty():
		var node_displays := PackedStringArray()
		for np in b_nodes:
			node_displays.append(_display_node_path(np))
		_detail.append_text("[b]操作节点:[/b] %s\n" % ", ".join(node_displays))

	# 变量
	var b_vars: Dictionary = binding.get("variables", {})
	var var_parts := PackedStringArray()
	var local_names: Array[String] = []
	for v in b_vars.get("local", []):
		local_names.append(v.get("name", "?"))
	if not local_names.is_empty():
		var_parts.append("[local] " + ", ".join(local_names))
	var scope_names: Array[String] = []
	for v in b_vars.get("scope", []):
		scope_names.append(v.get("name", "?"))
	if not scope_names.is_empty():
		var_parts.append("[scope] " + ", ".join(scope_names))
	var global_names: Array[String] = []
	for v in b_vars.get("global", []):
		global_names.append(v.get("name", "?"))
	if not global_names.is_empty():
		var_parts.append("[global] " + ", ".join(global_names))
	if not var_parts.is_empty():
		_detail.append_text("[b]变量:[/b] %s\n" % " | ".join(var_parts))

	# 指令链
	var flat: Array = binding.get("instructions_flat", [])
	_detail.append_text("\n[b]指令链 (%d 条):[/b]\n" % flat.size())
	if flat.is_empty():
		_detail.append_text("  [color=gray](空)[/color]\n")
	else:
		for inst_info in flat:
			var prefix: String = inst_info.get("prefix", "")
			var inst_name: String = inst_info.get("name", "?")
			_detail.append_text("  %s📦 %s\n" % [prefix, _strip_bbcode(inst_name)])


## 选中指令 → 右侧详情
func _show_instruction_detail(meta: Dictionary) -> void:
	var inst = meta.get("inst")
	var report: Dictionary = meta.get("report", {})

	if inst == null:
		# flat 回退（无 inst 引用）
		_detail.append_text("[color=gray](指令详情需要 instructions_tree 支持)[/color]")
		return

	var iname: String = _strip_bbcode(inst.resource_name)
	if iname.is_empty():
		iname = inst.get_class()

	_detail.append_text("[b]%s[/b]\n" % iname)

	# 分类
	var script = inst.get_script()
	if script and script.has_method("_get_instruction_metadata"):
		var metadata = script._get_instruction_metadata()
		_detail.append_text("[color=gray]分类: %s[/color]\n\n" % metadata.category_key)

	# 参数表（反射 @export 属性）
	_detail.append_text("[b]参数:[/b]\n")
	for prop in inst.get_property_list():
		var pname: String = prop.get("name", "")
		if pname.begins_with("_") or pname in ["script", "resource_name", "metadata"]:
			continue
		var usage: int = prop.get("usage", 0)
		if not (usage & PROPERTY_USAGE_EDITOR):
			continue
		var value = inst.get(pname)
		_detail.append_text("  %s: %s\n" % [pname, str(value)])

	# 引用（单指令提取）
	var inst_report := {"nodes": [], "variables": {"local": [], "scope": [], "global": []}}
	InstructionAnalyzer._extract_nodepaths(inst, inst_report)
	InstructionAnalyzer._extract_variables(inst, inst_report)

	if not inst_report["nodes"].is_empty():
		_detail.append_text("\n[b]节点引用:[/b] %s\n" % ", ".join(inst_report["nodes"]))

	var var_names: Array = []
	for v in inst_report["variables"]["local"]:
		var_names.append(v.get("name", "?"))
	for v in inst_report["variables"]["scope"]:
		var_names.append(v.get("name", "?"))
	for v in inst_report["variables"]["global"]:
		var_names.append(v.get("name", "?"))
	if not var_names.is_empty():
		_detail.append_text("[b]变量引用:[/b] %s\n" % ", ".join(var_names))

	# 上下文
	_detail.append_text("\n[color=gray]所属 Trigger: %s[/color]\n" % report.get("trigger_name", "?"))


## 选中 Trigger → 右侧概要（现有逻辑封装）
func _show_trigger_detail(report: Dictionary) -> void:
	if report.is_empty():
		return

	_detail.append_text("[b]%s[/b]\n" % report.get("trigger_name", "?"))
	_detail.append_text("[color=gray]%s[/color]\n\n" % report.get("trigger_path", ""))

	# 事件
	var event_info: Dictionary = report.get("event", {})
	if not event_info.is_empty():
		_detail.append_text("[b]事件:[/b] %s [color=gray](%s)[/color]\n" % [event_info.get("resource_name", "?"), event_info.get("type", "?")])

	# 节点引用
	var report_nodes: Array = report.get("nodes", [])
	if not report_nodes.is_empty():
		var node_displays := PackedStringArray()
		for np in report_nodes:
			node_displays.append(_display_node_path(np))
		_detail.append_text("[b]操作节点:[/b] %s\n" % ", ".join(node_displays))
	else:
		_detail.append_text("[b]操作节点:[/b] (无)\n")

	# 变量
	var var_parts := _build_variable_parts(report)
	if not var_parts.is_empty():
		_detail.append_text("[b]变量:[/b] %s\n" % " | ".join(var_parts))
	else:
		_detail.append_text("[b]变量:[/b] (无)\n")

	# 信号
	var report_signals: Array = report.get("signals", [])
	if not report_signals.is_empty():
		_detail.append_text("[b]信号:[/b]\n")
		for sig in report_signals:
			_detail.append_text("  • %s → %s\n" % [sig.get("signal", "?"), sig.get("target", "")])
	else:
		_detail.append_text("[b]信号:[/b] (无)\n")

	# 指令链
	var flat: Array = report.get("instructions_flat", [])
	_detail.append_text("\n[b]指令链 (%d 条):[/b]\n" % flat.size())
	if flat.is_empty():
		_detail.append_text("  [color=gray](空)[/color]\n")
	else:
		for inst_info in flat:
			var prefix: String = inst_info.get("prefix", "")
			var inst_name: String = inst_info.get("name", "?")
			_detail.append_text("  %s📦 %s\n" % [prefix, _strip_bbcode(inst_name)])

	# E3: 跨 Trigger 变量关联（追加段）
	_append_cross_trigger_relations(report)


# ============================================================
# GraphEdit（保留，不默认显示）
# ============================================================

func _show_graph(report: Dictionary) -> void:
	_detail.visible = false
	_graph_edit.visible = true
	var graph_data: Dictionary = FuseGraphBuilder.build(report)
	_graph_edit.set_graph(graph_data["nodes"], graph_data["edges"])


# ============================================================
# 辅助方法
# ============================================================

## 节点路径可读化显示
func _display_node_path(path_str: String) -> String:
	if path_str.is_empty():
		return ""
	var file_name := path_str.get_file()
	if not file_name.is_empty() and file_name != ".." and file_name != ".":
		return file_name
	return BaseInstruction._get_parent_level_display(path_str)


## 从 report 构建变量标签列表（按作用域分组）
static func _build_variable_parts(report: Dictionary) -> PackedStringArray:
	var parts := PackedStringArray()
	var local_names: Array[String] = []
	for v in report.get("variables", {}).get("local", []):
		local_names.append(v.get("name", "?"))
	if not local_names.is_empty():
		parts.append("[local] " + ", ".join(local_names))
	var scope_names: Array[String] = []
	for v in report.get("variables", {}).get("scope", []):
		scope_names.append(v.get("name", "?"))
	if not scope_names.is_empty():
		parts.append("[scope] " + ", ".join(scope_names))
	var global_names: Array[String] = []
	for v in report.get("variables", {}).get("global", []):
		global_names.append(v.get("name", "?"))
	if not global_names.is_empty():
		parts.append("[global] " + ", ".join(global_names))
	return parts


# ============================================================
# 全局关联渲染
# ============================================================

func _refresh_cross_references(topology: Dictionary) -> void:
	var ref_lines := PackedStringArray()
	var warning_lines := PackedStringArray()

	for ref in topology.get("cross_references", []):
		var ref_type: String = ref.get("type", "?")
		var from_name: String = ref.get("from", "?")
		var to_name: String = ref.get("to", "?")
		var detail: String = ref.get("detail", "")

		match ref_type:
			"signal":
				ref_lines.append("🔗  %s → %s  信号: %s" % [from_name, to_name, detail])
			"variable_write_to_read":
				ref_lines.append("📝  %s (%s) → [%s] → %s (%s)" % [
					from_name, _mode_label(ref.get("from_mode", "")),
					detail,
					to_name, _mode_label(ref.get("to_mode", ""))])
			"variable_write_to_write":
				# 竞态预警 → warning 区（BBCode 黄色）
				warning_lines.append("[color=yellow]🔥  %s ↔ %s  共享变量: %s (竞态)[/color]" % [
					from_name, to_name, detail])
			_:
				# 兼容旧 shared_global_variable（理论不再产出，保险）
				ref_lines.append("🌐  %s → %s  (%s)" % [from_name, to_name, detail])

	# E3: 孤写/孤读标注（variable_analysis 顶层）
	for entry in topology.get("variable_analysis", []):
		match entry.get("anomaly", "normal"):
			"write_only":
				warning_lines.append("[color=yellow]📤  孤写: %s → (无读者)[/color]" % entry.get("name", "?"))
			"read_only":
				warning_lines.append("[color=yellow]📥  孤读: %s ← (无写者)[/color]" % entry.get("name", "?"))

	# 组装显示（BBCode，_cross_ref_label 已是 RichTextLabel + bbcode_enabled）
	var all_lines := PackedStringArray()
	if not ref_lines.is_empty():
		all_lines.append("跨 Trigger 关联 (%d 条):" % ref_lines.size())
		all_lines.append_array(ref_lines)
	if not warning_lines.is_empty():
		if not all_lines.is_empty():
			all_lines.append("")
		all_lines.append("⚠ 预警 (%d 条):" % warning_lines.size())
		all_lines.append_array(warning_lines)
	if all_lines.is_empty():
		_cross_ref_label.text = "跨 Trigger 关联: (无)"
	else:
		_cross_ref_label.text = "\n".join(all_lines)


## E3: 变量访问 mode → 中文标签（渲染辅助）
static func _mode_label(mode: String) -> String:
	match mode:
		"write": return "写"
		"read": return "读"
		"read_write": return "读写"
		_: return mode


## E3: 在 _show_trigger_detail 末尾追加当前 Trigger 的跨 Trigger 关联信息
## 从 _last_topology.cross_references 中过滤出与当前 trigger 相关的条目
func _append_cross_trigger_relations(report: Dictionary) -> void:
	if _last_topology.is_empty():
		return
	var cross_refs: Array = _last_topology.get("cross_references", [])
	var this_name: String = report.get("trigger_name", "")
	if this_name.is_empty():
		return
	var related_refs := cross_refs.filter(func(r):
		return r.get("from", "") == this_name or r.get("to", "") == this_name)
	if related_refs.is_empty():
		return

	_detail.append_text("\n[b]跨 Trigger 关联 (%d 条):[/b]\n" % related_refs.size())
	for r in related_refs:
		var r_type: String = r.get("type", "")
		var from_name: String = r.get("from", "?")
		var to_name: String = r.get("to", "?")
		var detail: String = r.get("detail", "")
		match r_type:
			"variable_write_to_read":
				var direction := "→" if from_name == this_name else "←"
				var target := to_name if from_name == this_name else from_name
				_detail.append_text("  📝 %s %s [color=gray]变量: %s (%s→%s)[/color]\n" % [
					direction, target, detail,
					_mode_label(r.get("from_mode", "")),
					_mode_label(r.get("to_mode", ""))])
			"variable_write_to_write":
				_detail.append_text("  [color=yellow]🔥 竞态 ↔ %s [color=gray]变量: %s[/color][/color]\n" % [
					to_name if from_name == this_name else from_name, detail])
			"signal":
				var direction := "→" if from_name == this_name else "←"
				var target := to_name if from_name == this_name else from_name
				_detail.append_text("  🔗 %s %s [color=gray]信号: %s[/color]\n" % [
					direction, target, detail])
			_:
				_detail.append_text("  • %s ↔ %s [color=gray]%s[/color]\n" % [
					from_name, to_name, detail])


# ============================================================
# 静态分析注入辅助（任务 3 — 注入 problems 到 report）
# ============================================================

## 从 trigger report 收集所有指令 inst（E5：委托 InstructionAnalyzer 公开静态方法，行为零变化）
func _collect_insts_from_report(report: Dictionary) -> Array:
	return InstructionAnalyzer.collect_insts_from_report(report)


## E7: 收集 trigger 自身 + 所有 event_binding 的 provided_locals 并集
## MultiEventTrigger 多 binding 时保守合并（任一 binding 提供的都视为已定义）
func _collect_provided_locals(report: Dictionary) -> Array:
	var merged: Array = []
	var seen: Dictionary = {}
	for v in report.get("provided_locals", []):
		if v is String and not v.is_empty() and not seen.has(v):
			merged.append(v)
			seen[v] = true
	for binding in report.get("event_bindings", []):
		for v in binding.get("provided_locals", []):
			if v is String and not v.is_empty() and not seen.has(v):
				merged.append(v)
				seen[v] = true
	return merged


## 从 instructions_tree（嵌套）递归收集所有 inst（E5：委托，行为零变化）
func _collect_insts_from_tree(tree: Array) -> Array:
	return InstructionAnalyzer.collect_insts_from_tree(tree)


## 把 problems 按 inst 引用重组 + 汇总（E5：委托 InstructionAnalyzer 公开静态方法，行为零变化）
## by_inst key = inst.get_instance_id()（int），value = problems[]
## summary = {errors, warnings, suggestions}
func _index_problems(problems: Array) -> Dictionary:
	return InstructionAnalyzer.index_problems(problems)


## 按 inst 引用查该指令的问题（by_inst 索引，O(1)）
## inst 为 null（flat 回退路径）时返回空数组 — 自动跳过标注。
func _find_problems_for_inst(inst, report: Dictionary) -> Array:
	if inst == null:
		return []
	var by_inst: Dictionary = report.get("problems", {}).get("by_inst", {})
	return by_inst.get(inst.get_instance_id(), [])


## 导出全场景问题报告到 res://fuse_reports/fuse_problems_report_*.txt
func _on_export_problems() -> void:
	if _last_topology.is_empty():
		_detail.append_text("\n[color=yellow]无分析数据，先刷新[/color]")
		return

	var report_dir := "res://fuse_reports"
	if not DirAccess.dir_exists_absolute(report_dir):
		var err := DirAccess.make_dir_recursive_absolute(report_dir)
		if err != OK:
			_detail.append_text("\n[color=red]无法创建目录 '%s' (错误码 %d)[/color]" % [report_dir, err])
			return

	var lines := ["Fuse 问题报告 %s" % Time.get_time_string_from_system(), "=".repeat(50)]

	var scene_path := ""
	if ClassDB.class_exists("EditorInterface"):
		var scene_root := EditorInterface.get_edited_scene_root()
		if scene_root != null:
			scene_path = scene_root.scene_file_path
	if not scene_path.is_empty():
		lines.append("场景: %s" % scene_path)
	lines.append("")

	var total_err := 0
	var total_warn := 0
	var total_suggest := 0

	for t in _last_topology.get("triggers", []):
		var problems_data: Dictionary = t.get("problems", {})
		var summary: Dictionary = problems_data.get("summary", {"errors": 0, "warnings": 0, "suggestions": 0})
		var by_inst: Dictionary = problems_data.get("by_inst", {})
		if by_inst.is_empty():
			continue

		var trigger_name: String = t.get("trigger_name", "?")
		var trigger_type: String = t.get("trigger_type", "?")
		lines.append("[%s] %s" % [trigger_type, trigger_name])
		lines.append("-".repeat(40))

		for key in by_inst:
			var inst_problems: Array = by_inst[key]
			for p in inst_problems:
				var severity: String = p.get("severity", "info")
				var message: String = p.get("message", "")
				var idx: int = p.get("instruction_index", -1)
				var inst = p.get("inst", null)
				var inst_name := "?"
				if inst != null:
					var script := inst.get_script() as GDScript
					inst_name = script.get_global_name() if script and not script.get_global_name().is_empty() else inst.get_class()

				match severity:
					"error": total_err += 1
					"warning": total_warn += 1
					"suggestion": total_suggest += 1

				var label := "建议"
				match severity:
					"error": label = "错误"
					"warning": label = "警告"
					"suggestion": label = "建议"
				lines.append("  [%s] 指令#%d (%s): %s" % [label, idx, inst_name, message])
		lines.append("")

	lines.append("=".repeat(50))
	lines.append("合计: %d 错误, %d 警告, %d 建议" % [total_err, total_warn, total_suggest])

	var path := "%s/fuse_problems_report_%s.txt" % [report_dir, Time.get_time_string_from_system().replace(":", "-")]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines))
		f.close()
		_detail.append_text("\n[color=green]报告已导出: %s[/color]" % path)
	else:
		_detail.append_text("\n[color=red]导出失败: %s[/color]" % path)


## 导出当前场景拓扑 JSON（TopologyExport 共享序列化，Task 2 毕业 deriver 的地基）
func _on_export_json() -> void:
	var scene_root: Node = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		_detail.append_text("[color=red](未打开场景，无法导出)[/color]")
		return
	var topology: Dictionary = InstructionAnalyzer.build_topology(scene_root)
	var path: String = TopologyExport.export_to_json(topology, "res://fuse_reports/topology")
	if path.is_empty():
		_detail.append_text("[color=red](导出失败，见输出面板)[/color]")
	else:
		_detail.append_text("[color=gray]拓扑已导出: %s[/color]\n" % path)


# ============================================================
# E4：主题图标 + 严重度标签辅助
# ============================================================

## 获取编辑器主题图标，不存在时返回 null（E4）
func _get_theme_icon(icon_name: String) -> Texture2D:
	var theme := EditorInterface.get_editor_theme()
	if theme and theme.has_icon(icon_name, "EditorIcons"):
		return theme.get_icon(icon_name, "EditorIcons")
	return null


## 严重度 → 中文标签（E4，替代 emoji 文本）
static func _severity_label(p_severity: String) -> String:
	match p_severity:
		"error": return "错误"
		"warning": return "警告"
		"suggestion": return "建议"
		_: return p_severity
