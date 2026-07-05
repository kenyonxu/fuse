# addons/fuse/editor/preset_export_dialog.gd
@tool
class_name PresetExportDialog
extends AcceptDialog

## 导出预设对话框 — 支持 L1（传指令数组）和 L2-L4（传节点）

var _display_name_input: LineEdit
var _folder_input: LineEdit
var _folder_browse_btn: Button
var _description_input: TextEdit
var _icon_input: LineEdit
var _info_label: Label
var _level_label: Label
var _instructions: Array[BaseInstruction] = []
var _serialized_data: Dictionary = {}
var _level: String = "L1"
var _source_node: Node = null
var _folder_path: String = "res://addons/fuse/presets/"


func _init(source: Variant) -> void:
	title = "导出为预设"
	ok_button_text = "导出"
	min_size = Vector2i(800, 0)
	if source is Node:
		_source_node = source
		_level = FusePresetSerializer.detect_level(source)
		_serialized_data = FusePresetSerializer.serialize(source)
		if _level == "L1":
			var ar := source as ActionRunner
			_instructions = ar.instructions if ar else []
		else:
			_instructions = _extract_instructions_from_data()
	elif source is Array:
		_level = "L1"
		_instructions = source
		var dummy := ActionRunner.new()
		dummy.instructions = _instructions
		_serialized_data = FusePresetSerializer.serialize_l1(dummy)

	_build_ui()
	_update_info()


func get_folder_path() -> String:
	return _folder_path


func _extract_instructions_from_data() -> Array[BaseInstruction]:
	var result: Array[BaseInstruction] = []
	match _level:
		"L2", "L3":
			if _source_node is Trigger:
				var trigger := _source_node as Trigger
				if trigger.action_runner:
					result = trigger.action_runner.instructions
			elif _source_node is Runner:
				var runner := _source_node as Runner
				if runner.action_runner:
					result = runner.action_runner.instructions
		"L4":
			if _source_node is MultiEventTrigger:
				var multi := _source_node as MultiEventTrigger
				for binding in multi.event_bindings:
					if binding.action_runner:
						result.append_array(binding.action_runner.instructions)
	return result


func _build_ui() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(grid)

	# Level 标签
	grid.add_child(_make_label("层级:"))
	_level_label = Label.new()
	_level_label.text = _level_display_name()
	_level_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	grid.add_child(_level_label)

	# display_name
	grid.add_child(_make_label("名称:"))
	_display_name_input = LineEdit.new()
	_display_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_display_name_input.text = _default_display_name()
	grid.add_child(_display_name_input)

	# 目标文件夹（替代旧 category 文本框）
	grid.add_child(_make_label("目标文件夹:"))
	var folder_hbox := HBoxContainer.new()
	folder_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_folder_input = LineEdit.new()
	_folder_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_folder_input.text = _folder_path
	_folder_input.text_changed.connect(_on_folder_text_changed)
	folder_hbox.add_child(_folder_input)
	_folder_browse_btn = Button.new()
	_folder_browse_btn.text = "浏览..."
	_folder_browse_btn.pressed.connect(_on_browse_folder)
	folder_hbox.add_child(_folder_browse_btn)
	grid.add_child(folder_hbox)

	# description
	grid.add_child(_make_label("描述:"))
	_description_input = TextEdit.new()
	_description_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_description_input.custom_minimum_size.y = 60
	grid.add_child(_description_input)

	# icon
	grid.add_child(_make_label("图标:"))
	_icon_input = LineEdit.new()
	_icon_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_icon_input.placeholder_text = "Bullet / Sprite2D / Node"
	grid.add_child(_icon_input)

	# info label
	var spacer := Control.new()
	grid.add_child(spacer)
	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	grid.add_child(_info_label)

	register_text_enter(_display_name_input)


func _on_folder_text_changed(new_text: String) -> void:
	_folder_path = new_text


func _on_browse_folder() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.exclusive = false
	if _folder_path.begins_with("res://"):
		dialog.current_dir = _folder_path
	else:
		dialog.current_dir = "res://addons/fuse/presets/"
	dialog.dir_selected.connect(_on_dir_selected.bind(dialog))
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()


func _on_dir_selected(dir: String, dialog: FileDialog) -> void:
	_folder_path = dir
	_folder_input.text = dir
	dialog.queue_free()


func _make_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	return lbl


func _level_display_name() -> String:
	match _level:
		"L1": return "L1 · ActionRunner（指令序列）"
		"L2": return "L2 · Trigger（事件 + 指令）"
		"L3": return "L3 · Runner（信号 + 指令）"
		"L4": return "L4 · MultiEventTrigger（多事件绑定）"
	return _level


func _default_display_name() -> String:
	if _source_node:
		return _source_node.name
	return "Preset_%s" % _level


func _update_info() -> void:
	var temp := FusePreset.new()
	temp.instructions = _instructions
	var nodepaths := temp.collect_unique_nodepaths()
	var vars := temp.collect_variables()
	_info_label.text = "检测到: %d 个 NodePath, %d 个变量(local:%d scope:%d global:%d)" % [
		nodepaths.size(),
		vars.local.size() + vars.scope.size() + vars.global.size(),
		vars.local.size(), vars.scope.size(), vars.global.size()
	]


func _get_source_instructions() -> Array[BaseInstruction]:
	if _source_node is Trigger:
		var trigger := _source_node as Trigger
		if trigger.action_runner:
			return trigger.action_runner.instructions
	elif _source_node is Runner:
		var runner := _source_node as Runner
		if runner.action_runner:
			return runner.action_runner.instructions
	return _instructions


func get_preset() -> FusePreset:
	var preset := FusePreset.new()
	preset.level = _level
	preset.display_name = _display_name_input.text
	preset.category = _folder_path.get_file() if not _folder_path.get_file().is_empty() else "uncategorized"
	preset.description = _description_input.text
	preset.icon_name = _icon_input.text
	preset.version = "2.0"

	match _level:
		"L1":
			preset.instructions = _instructions
			preset.variables = preset.collect_variables()
		"L2":
			preset.instructions = _get_source_instructions()
			preset.event_json = _serialized_data.get("event", {})
			preset.trigger_config = _serialized_data.get("trigger_config", {})
		"L3":
			preset.instructions = _get_source_instructions()
			preset.signal_binding = _serialized_data.get("signal_binding", {})
		"L4":
			preset.event_bindings_json = _serialized_data.get("event_bindings", [])
			preset.trigger_config = _serialized_data.get("trigger_config", {})

	preset.variables = preset.collect_variables()
	return preset
