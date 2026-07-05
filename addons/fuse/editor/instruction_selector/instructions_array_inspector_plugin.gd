# addons/fuse/editor/instruction_selector/instructions_array_inspector_plugin.gd
@tool
extends EditorInspectorPlugin

## Inspector 插件:在 Array[BaseInstruction] 属性上方添加操作按钮
## 添加指令 / 导出为预设 / 导入预设
## 保留 Godot 原生数组编辑器处理内联展开

func _can_handle(object: Object) -> bool:
	return true

static var _last_import_dir: String = ""


func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	var is_instruction_array = (
		type == TYPE_ARRAY and
		(
			("BaseInstruction" in hint_string) or
			(name == "instructions") or
			(name.ends_with("_instructions"))
		)
	)
	if not is_instruction_array:
		return false

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var add_btn := Button.new()
	add_btn.text = "添加指令"
	add_btn.icon = FuseIconManager.get_builtin_icon("Add")
	add_btn.pressed.connect(_on_add_pressed.bind(object, name))
	hbox.add_child(add_btn)

	var export_btn := Button.new()
	export_btn.text = "导出为预设"
	export_btn.pressed.connect(_on_export_pressed.bind(object, name))
	hbox.add_child(export_btn)

	var import_btn := Button.new()
	import_btn.text = "导入预设"
	import_btn.pressed.connect(_on_import_pressed.bind(object, name))
	hbox.add_child(import_btn)

	add_custom_control(hbox)
	return false


func _ensure_dir(path: String) -> void:
	var parts = path.trim_prefix("res://").split("/")
	var current := "res://"
	for part in parts:
		current = current.path_join(part)
		if not DirAccess.dir_exists_absolute(current):
			DirAccess.make_dir_absolute(current)


func _on_add_pressed(object: Object, property_name: String) -> void:
	var selector = InstructionSelector.new(object, property_name)
	EditorInterface.get_base_control().add_child(selector)
	selector.popup()


func _on_export_pressed(object: Object, property_name: String) -> void:
	var instructions: Array = object.get(property_name)
	if instructions.is_empty():
		return
	var dialog := PresetExportDialog.new(instructions)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.confirmed.connect(_on_export_confirmed.bind(dialog))
	dialog.popup_centered(Vector2i(800, 500))


func _on_export_confirmed(dialog: PresetExportDialog) -> void:
	var preset := dialog.get_preset()
	var default_dir := dialog.get_folder_path()
	_ensure_dir(default_dir)

	var file_dialog := FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.current_dir = default_dir
	file_dialog.current_file = preset.display_name.to_snake_case() + ".tres"
	file_dialog.add_filter("*.tres", "Fuse Preset (.tres)")
	file_dialog.file_selected.connect(_on_preset_save_path_selected.bind(preset, dialog))
	EditorInterface.get_base_control().add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(800, 500))


func _on_preset_save_path_selected(tres_path: String, preset: FusePreset, dialog: PresetExportDialog) -> void:
	# 保存 .tres
	ResourceSaver.save(preset, tres_path)

	# 保存同名 .json
	var json_path := tres_path.get_basename() + ".json"
	var file := FileAccess.open(json_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(preset.to_json(), "	"))
		file.close()

	PresetRegistry.scan_presets()

	var notify := AcceptDialog.new()
	notify.title = "预设已导出"
	notify.dialog_text = "已保存到:
%s
%s" % [tres_path, json_path]
	notify.confirmed.connect(notify.queue_free)
	notify.close_requested.connect(notify.queue_free)
	EditorInterface.get_base_control().add_child(notify)
	notify.popup_centered(Vector2i(600, 180))
	dialog.queue_free()


func _on_import_pressed(object: Object, property_name: String) -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.current_dir = _last_import_dir if not _last_import_dir.is_empty() else "res://addons/fuse/presets/"
	dialog.add_filter("*.json", "Fuse 预设 JSON")
	dialog.file_selected.connect(_on_preset_json_selected.bind(object, property_name))
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(800, 500))


func _on_preset_json_selected(path: String, object: Object, property_name: String) -> void:
	_last_import_dir = path.get_base_dir()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open file: " + path)
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		push_error("JSON parse failed: " + path)
		return

	var preset := FusePreset.from_json(data)
	if preset.level != "L1":
		push_error("ActionRunner only accepts L1 presets, got: " + preset.level)
		return
	_on_preset_mapped(preset, object, property_name)


func _on_preset_mapped(preset: FusePreset, object: Object, property_name: String) -> void:
	var nodepaths := preset.collect_unique_nodepaths()
	var mapping: Dictionary = {}

	if not nodepaths.is_empty():
		var scene_tree = Engine.get_main_loop() as SceneTree
		if scene_tree and scene_tree.current_scene:
			for np in nodepaths:
				var np_str := str(np)
				var target_name := str(np.get_name(0))
				var found: Array[Node] = scene_tree.current_scene.find_children(target_name, "", true, false)
				if not found.is_empty():
					mapping[np_str] = found[0].get_path()

	if not mapping.is_empty():
		preset.apply_nodepath_mapping(mapping)

	var instructions: Array = object.get(property_name)
	instructions.append_array(preset.instructions)
	object.set(property_name, instructions)
	if object is Resource:
		object.emit_changed()
		object.notify_property_list_changed()

	var dir_path := "res://addons/fuse/presets/%s" % preset.category
	_ensure_dir(dir_path)
	var base_name := preset.display_name.to_snake_case()
	var tres_path := "%s/%s.tres" % [dir_path, base_name]
	ResourceSaver.save(preset, tres_path)
	PresetRegistry.scan_presets()

	print("预设已导入: %s → %s" % [preset.display_name, property_name])
