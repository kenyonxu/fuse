# 文件：addons/fuse/editor/fuse_inspector_plugin.gd
@tool
extends EditorInspectorPlugin

## Fuse 统一 Inspector 插件
##
## 处理以下组件类型的 Inspector 增强：
## - Array[BaseInstruction]：指令数组，添加按钮打开多选选择器
## - BaseEvent：事件资源，添加按钮打开单选选择器
## - BaseCondition：条件资源，添加按钮打开单选选择器

# 本地化类缓存
var _fuse_localization_class: RefCounted = null

# Stage 5: InstructionAnalyzer 预加载
const InstructionAnalyzerClass = preload("res://addons/fuse/editor/analysis/instruction_analyzer.gd")

func _can_handle(object: Object) -> bool:
	if object == null:
		return false
	if object is BaseInstruction or object is BaseEvent or object is BaseCondition \
			or object is BaseVariable or object is ActionRunner \
			or object is BaseTrigger:
		return true
	var prop_list = object.get_property_list()
	for p in prop_list:
		var pname: String = p.get("name", "")
		if pname == "instructions" or pname.ends_with("_instructions") \
				or pname == "event" or pname.ends_with("_event") \
				or pname == "condition" or pname.ends_with("_condition") \
				or pname == "event_definition":
			return true
	return false

func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	# 1. 指令数组已委托给 instructions_array_inspector_plugin.gd 处理

	# 2. Event
	var is_event_resource = (
		type == TYPE_OBJECT and
		hint_type == PROPERTY_HINT_RESOURCE_TYPE and
		(("BaseEvent" in hint_string) or (name == "event") or (name.ends_with("_event")))
	)
	if is_event_resource:
		_add_component_selector_button(object, name, ComponentRegistry.ComponentType.EVENT)
		return false

	# 3. Condition
	var is_condition_resource = (
		type == TYPE_OBJECT and
		hint_type == PROPERTY_HINT_RESOURCE_TYPE and
		(("BaseCondition" in hint_string) or (name == "condition") or (name.ends_with("_condition")))
	)
	if is_condition_resource:
		_add_component_selector_button(object, name, ComponentRegistry.ComponentType.CONDITION)
		return false

	return false

func _add_component_selector_button(object: Object, property_name: String, component_type: ComponentRegistry.ComponentType) -> void:
	_ensure_localization_loaded()
	var container = VBoxContainer.new()
	var enhance_hbox = HBoxContainer.new()
	enhance_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var select_button = Button.new()
	var icon = FuseIconManager.get_builtin_icon("Edit")
	select_button.icon = icon

	var button_text_key := ""
	var button_tooltip_key := ""
	match component_type:
		ComponentRegistry.ComponentType.EVENT:
			button_text_key = "FUSE_UI_BTN_CLICK_TO_SELECT_EVENT"
			button_tooltip_key = "FUSE_UI_BTN_CLICK_TO_SELECT_EVENT_TOOLTIP"
		ComponentRegistry.ComponentType.CONDITION:
			button_text_key = "FUSE_UI_BTN_CLICK_TO_SELECT_CONDITION"
			button_tooltip_key = "FUSE_UI_BTN_CLICK_TO_SELECT_CONDITION_TOOLTIP"
		_:
			button_text_key = "FUSE_UI_BTN_CLICK_TO_SELECT_COMPONENT"
			button_tooltip_key = "FUSE_UI_BTN_CLICK_TO_SELECT_COMPONENT_TOOLTIP"

	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		select_button.text = _fuse_localization_class.translate(button_text_key)
		select_button.tooltip_text = _fuse_localization_class.translate(button_tooltip_key)
	else:
		match component_type:
			ComponentRegistry.ComponentType.EVENT:
				select_button.text = " 点击以选择事件..."
				select_button.tooltip_text = "点击以选择事件..."
			ComponentRegistry.ComponentType.CONDITION:
				select_button.text = " 点击以选择条件..."
				select_button.tooltip_text = "点击以选择条件..."
			_:
				select_button.text = " 点击以选择组件..."
				select_button.tooltip_text = "点击以选择组件..."

	select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	select_button.custom_minimum_size.x = 200

	select_button.pressed.connect(_open_component_selector.bind(object, property_name, component_type))
	enhance_hbox.add_child(select_button)
	container.add_child(enhance_hbox)
	add_custom_control(container)

func _open_component_selector(object: Object, property_name: String, component_type: ComponentRegistry.ComponentType) -> void:
	var selector = ComponentSelector.new(object, property_name, component_type)
	EditorInterface.get_base_control().add_child(selector)
	selector.popup()

func _ensure_localization_loaded() -> void:
	if _fuse_localization_class == null:
		_fuse_localization_class = load("res://addons/fuse/localization/fuse_localization.gd")


# ============================================================
# Stage 5: BaseTrigger 数据流卡片（可折叠）
# ============================================================

var _dataflow_button: Button = null
var _dataflow_card: VBoxContainer = null
var _dataflow_expanded: bool = false
var _report_cache: Dictionary = {}

# Stage 6: 导出预设按钮
var _action_hbox: HBoxContainer = null
var _import_btn: Button = null
var _current_node: Node = null


func _parse_end(object: Object) -> void:
	if object is BaseTrigger:
		var report = InstructionAnalyzerClass.analyze_trigger(object)
		_report_cache = report
		_current_node = object as Node
		_add_action_buttons(object as Node)
		_add_dataflow_ui(report)

	if object is Runner:
		_current_node = object as Runner
		_add_action_buttons(object as Runner)


func _add_action_buttons(node: Node) -> void:
	var level := FusePresetSerializer.detect_level(node)
	if level.is_empty() or level == "L1":
		return

	if _action_hbox:
		return

	_action_hbox = HBoxContainer.new()
	_action_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 导出按钮
	var errors := _validate_before_export(node, level)
	if errors.is_empty():
		var export_btn := Button.new()
		export_btn.text = "📦 导出 (%s)" % _level_label(level)
		export_btn.pressed.connect(_on_export_preset_pressed)
		_action_hbox.add_child(export_btn)

	# 导入按钮
	_import_btn = Button.new()
	_import_btn.text = "📥 导入预设"
	_import_btn.pressed.connect(_on_import_preset_pressed)
	_action_hbox.add_child(_import_btn)

	add_custom_control(_action_hbox)

func _level_label(level: String) -> String:
	match level:
		"L2": return "Trigger/触发器"
		"L3": return "Runner/信号适配器"
		"L4": return "MultiEventTrigger/多重事件触发器"
	return level


func _validate_before_export(node: Node, level: String) -> Array[String]:
	var errors: Array[String] = []
	match level:
		"L2":
			var trigger := node as Trigger
			if not trigger or not trigger.event_definition:
				errors.append("事件定义未配置，无法导出")
		"L3":
			var runner := node as Runner
			if not runner or not runner.action_runner:
				errors.append("ActionRunner 未配置，无法导出")
		"L4":
			var multi := node as MultiEventTrigger
			if not multi:
				errors.append("节点无效")
			else:
				var has_enabled := false
				for binding in multi.event_bindings:
					if binding.enabled:
						has_enabled = true
						break
				if not has_enabled:
					errors.append("没有启用的事件绑定，无法导出")
	return errors


func _on_export_preset_pressed() -> void:
	if _current_node == null:
		return
	var dialog := PresetExportDialog.new(_current_node)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.confirmed.connect(_on_export_confirmed.bind(dialog))
	dialog.popup_centered()


func _on_export_confirmed(dialog: PresetExportDialog) -> void:
	var preset := dialog.get_preset()
	if preset == null:
		push_error("export failed: preset is null")
		return
	var dir_path := dialog.get_folder_path()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var base_name := preset.display_name.to_snake_case()
	var tres_path := "%s/%s.tres" % [dir_path, base_name]
	ResourceSaver.save(preset, tres_path)
	var json_path := "%s/%s.json" % [dir_path, base_name]
	var file := FileAccess.open(json_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(preset.to_json(), "	"))
		file.close()
	PresetRegistry.scan_presets()


func _add_dataflow_ui(report: Dictionary) -> void:
	# 按钮已存在则只更新文本,避免 add_custom_control 重复调用
	if _dataflow_button:
		var node_count: int = report.nodes.size()
		var var_count := 0
		for scope in report.variables:
			var_count += report.variables[scope].size()
		_dataflow_button.text = "📊 数据流: %s (%d指令, %d节点, %d变量, %d信号)" % [
			report.event.get("resource_name", "?"),
			report.instructions_flat.size(), node_count, var_count, report.signals.size()
		]
		return

	if report.instructions_flat.is_empty():
		_dataflow_button = Button.new()
		_dataflow_button.text = "📊 数据流: (无指令)"
		add_custom_control(_dataflow_button)
		return

	# 首次创建按钮
	var node_count: int = report.nodes.size()
	var signal_count: int = report.signals.size()
	var var_count := 0
	for scope in report.variables:
		var_count += report.variables[scope].size()
	_dataflow_button = Button.new()
	_dataflow_button.text = "📊 数据流: %s (%d指令, %d节点, %d变量, %d信号)" % [
		report.event.get("resource_name", "?"),
		report.instructions_flat.size(), node_count, var_count, signal_count
	]
	_dataflow_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_dataflow_button.pressed.connect(_toggle_dataflow)
	add_custom_control(_dataflow_button)


	# 在 _parse_end 中创建卡片
	_create_dataflow_card()
	_dataflow_card.visible = false
	_dataflow_expanded = false

func _toggle_dataflow() -> void:
	_dataflow_expanded = not _dataflow_expanded
	if _dataflow_card:
		_dataflow_card.visible = _dataflow_expanded
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
	content.add_child(_make_section_label("数据流"))
	if not report.event.is_empty():
		content.add_child(_make_info_line("事件: %s" % report.event.resource_name))
	if not report.nodes.is_empty():
		content.add_child(_make_info_line("操作节点: %s" % ", ".join(report.nodes)))
	var var_lines: Array[String] = []
	if not report.variables.local.is_empty():
		var strs: Array[String] = []
		for v in report.variables.local: strs.append(v.name)
		var_lines.append("[local] " + ", ".join(strs))
	if not report.variables.scope.is_empty():
		var strs: Array[String] = []
		for v in report.variables.scope: strs.append(v.name)
		var_lines.append("[scope] " + ", ".join(strs))
	if not report.variables.global.is_empty():
		var strs: Array[String] = []
		for v in report.variables.global: strs.append(v.name)
		var_lines.append("[global] " + ", ".join(strs))
	content.add_child(_make_info_line("变量: %s" % (" | ".join(var_lines) if not var_lines.is_empty() else "(无)")))
	if not report.signals.is_empty():
		for sig in report.signals:
			content.add_child(_make_info_line("信号: %s (%s)" % [sig.signal, sig.runner_name]))
	else:
		content.add_child(_make_info_line("信号: (无)"))
	content.add_child(_make_section_label("指令链 (%d 条)" % report.instructions_flat.size()))
	for inst_info in report.instructions_flat:
		content.add_child(_make_info_line("%s %s" % [inst_info.prefix, inst_info.name]))
	add_custom_control(_dataflow_card)


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

func _on_import_preset_pressed() -> void:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_RESOURCES
	fd.current_dir = "res://addons/fuse/presets/"
	fd.add_filter("*.tres", "Fuse Preset (.tres)")
	fd.add_filter("*.json", "Fuse Preset JSON (.json)")
	fd.file_selected.connect(_on_import_file_selected.bind(fd))
	EditorInterface.get_base_control().add_child(fd)
	fd.popup_centered()


func _on_import_file_selected(path: String, fd: FileDialog) -> void:
	fd.queue_free()
	var preset: FusePreset = null
	if path.ends_with(".json"):
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_error("Cannot open file: " + path)
			return
		var data = JSON.parse_string(file.get_as_text())
		file.close()
		if data == null:
			push_error("JSON parse failed: " + path)
			return
		preset = FusePreset.from_json(data)
	else:
		preset = load(path) as FusePreset
	if preset == null:
		push_error("Failed to load preset: " + path)
		return
	_apply_preset_to_node(preset, _current_node)


func _apply_preset_to_node(preset: FusePreset, node: Node) -> void:
	# NodePath 映射：提取 → 自动匹配 → 用户确认
	var nodepaths := NodePathResolver.extract_nodepaths(preset.instructions)
	if nodepaths.is_empty():
		_do_apply_preset(preset, node, {})
		return

	var mapping_suggestions := NodePathResolver.resolve_mapping(nodepaths, node)
	var dialog := NodePathMappingDialog.new(mapping_suggestions, node)
	dialog.canceled.connect(func():
		push_warning("导入已取消（NodePath 映射未确认）")
	)
	dialog.confirmed.connect(func():
		var final_mapping: Dictionary = dialog.get_final_mapping()
		_do_apply_preset(preset, node, final_mapping)
	)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()


func _do_apply_preset(preset: FusePreset, node: Node, mapping: Dictionary) -> void:
	var temp := FusePresetDeserializer.deserialize(preset, mapping)
	if temp == null:
		push_error("Failed to deserialize preset")
		return
	var level := preset.level
	match level:
		"L2":
			if node is Trigger and temp is Trigger:
				var t := node as Trigger
				var src := temp as Trigger
				t.event_definition = src.event_definition
				t.action_runner = src.action_runner
				t.trigger_once = src.trigger_once
				t.cooldown_mode = src.cooldown_mode
				t.cooldown_time = src.cooldown_time
			else:
				push_error("L2 preset requires Trigger node, got " + node.get_class())
		"L3":
			if node is Runner and temp is Runner:
				var r := node as Runner
				var src := temp as Runner
				r.action_runner = src.action_runner
				r.signal_name = src.signal_name
			else:
				push_error("L3 preset requires Runner node, got " + node.get_class())
		"L4":
			if node is MultiEventTrigger and temp is MultiEventTrigger:
				var m := node as MultiEventTrigger
				var src := temp as MultiEventTrigger
				m.event_bindings = src.event_bindings
				m.use_parallel_condition_evaluation = src.use_parallel_condition_evaluation
			else:
				push_error("L4 preset requires MultiEventTrigger node, got " + node.get_class())
		"L1":
			push_error("L1 preset not supported for node import")
		_:
			push_error("Unknown preset level: " + level)
	if is_instance_valid(temp):
		temp.queue_free()

	# 刷新 action_runner 指令的 resource_name（NodePath 映射后显示名需更新）
	_refresh_instruction_names(node)


## 递归刷新节点下所有 action_runner 指令的 resource_name
func _refresh_instruction_names(node: Node) -> void:
	if "action_runner" in node:
		var ar = node.get("action_runner")
		if ar and "instructions" in ar:
			_refresh_instructions_recursive(ar.instructions)
	if "event_bindings" in node:
		var bindings = node.get("event_bindings")
		if bindings:
			for binding in bindings:
				if binding and "action_runner" in binding:
					var bar = binding.action_runner
					if bar and "instructions" in bar:
						_refresh_instructions_recursive(bar.instructions)


func _refresh_instructions_recursive(instructions: Array) -> void:
	for inst in instructions:
		if inst == null:
			continue
		if inst.has_method("_update_resource_name"):
			inst._update_resource_name()
		# 递归嵌套（if/else/loop）
		for sub_key in ["instructions", "true_instructions", "false_instructions", "else_instructions", "loop_instructions"]:
			if sub_key in inst and inst.get(sub_key) is Array:
				_refresh_instructions_recursive(inst.get(sub_key))
	notify_property_list_changed()

