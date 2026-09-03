# addons/fuse/editor/instruction_selector/instructions_array_property.gd
@tool
extends VBoxContainer

const FuseLocalizationClass = preload("res://addons/fuse/localization/fuse_localization.gd")

## 指令列表编辑器(add_custom_control 模式)
## ItemList 在上方 + 原生编辑器在下方(内联展开) + 选中时内联 EditorInspector

var property_list: ItemList = ItemList.new()
var add_button: Button = Button.new()
var remove_button: Button = Button.new()
var edit_button: Button = Button.new()
var copy_button: Button = Button.new()
var export_btn: Button = Button.new()
var _edited_object: Object = null
var _property_name: String = ""
var _inline_inspector: EditorInspector = EditorInspector.new()


func _init():
	# ItemList + 按钮行
	var hbox = HBoxContainer.new()
	add_child(hbox)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 80
	hbox.add_child(scroll)

	scroll.add_child(property_list)
	property_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	property_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	property_list.select_mode = ItemList.SELECT_MULTI
	property_list.item_selected.connect(_on_item_selected)
	property_list.item_activated.connect(_on_item_activated)

	var vbox_btns = VBoxContainer.new()
	hbox.add_child(vbox_btns)

	add_button.text = FuseLocalizationClass.translate("FUSE_UI_BTN_ADD")
	add_button.custom_minimum_size.x = 70
	add_button.pressed.connect(_on_add_pressed)
	vbox_btns.add_child(add_button)

	edit_button.text = FuseLocalizationClass.translate("FUSE_UI_BTN_EDIT")
	edit_button.custom_minimum_size.x = 70
	edit_button.pressed.connect(_on_edit_pressed)
	edit_button.disabled = true
	vbox_btns.add_child(edit_button)

	remove_button.text = FuseLocalizationClass.translate("FUSE_UI_BTN_DELETE")
	remove_button.custom_minimum_size.x = 70
	remove_button.pressed.connect(_on_remove_pressed)
	remove_button.disabled = true
	vbox_btns.add_child(remove_button)

	copy_button.text = FuseLocalizationClass.translate("FUSE_UI_INSTRUCTIONS_ARRAY_BTN_COPY")
	copy_button.custom_minimum_size.x = 70
	copy_button.pressed.connect(_on_copy_pressed)
	copy_button.disabled = true
	vbox_btns.add_child(copy_button)

	export_btn.text = FuseLocalizationClass.translate("FUSE_UI_INSTRUCTIONS_ARRAY_BTN_EXPORT_PRESET")
	export_btn.custom_minimum_size.x = 70
	export_btn.pressed.connect(_on_export_pressed)
	vbox_btns.add_child(export_btn)

	# 内联属性面板(选中指令时在下方展开)
	_inline_inspector.custom_minimum_size.y = 200
	_inline_inspector.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_child(_inline_inspector)
	_inline_inspector.hide()


func setup(edited_object: Object, prop_name: String):
	_edited_object = edited_object
	_property_name = prop_name
	refresh()


func refresh():
	property_list.clear()
	_inline_inspector.edit(null)
	_inline_inspector.hide()

	var raw = _edited_object.get(_property_name)
	var instructions: Array[BaseInstruction] = []
	if raw is Array:
		for item in raw:
			if item is BaseInstruction:
				instructions.append(item)

	if instructions:
		for i in range(instructions.size()):
			var instruction: BaseInstruction = instructions[i]
			var instruction_name := instruction.resource_name
			if instruction_name.is_empty():
				instruction_name = instruction.get_class()
			var icon: Texture2D = null
			# 使用 get_icon() 方法（内部从脚本静态方法获取元数据，避免共享 static var 被覆盖问题）
			icon = instruction.get_icon()
			property_list.add_item(instruction_name, icon if icon != null else null)
		_update_buttons()
	else:
		property_list.add_item(FuseLocalizationClass.translate("FUSE_UI_INSTRUCTIONS_ARRAY_EMPTY_LIST"))


func _update_buttons():
	var has_selection = not property_list.get_selected_items().is_empty()
	edit_button.disabled = not has_selection
	remove_button.disabled = not has_selection
	copy_button.disabled = not has_selection


func _on_item_selected(index: int) -> void:
	_update_buttons()
	# 在 ItemList 下方内联展开该指令的属性
	var instructions: Array = _edited_object.get(_property_name)
	if index >= 0 and index < instructions.size():
		_inline_inspector.edit(instructions[index])
		_inline_inspector.show()
	else:
		_inline_inspector.edit(null)
		_inline_inspector.hide()


func _on_item_activated(index: int) -> void:
	_on_item_selected(index)


func _on_add_pressed() -> void:
	var selector = InstructionSelector.new(_edited_object, _property_name)
	EditorInterface.get_base_control().add_child(selector)
	selector.popup()
	selector.popup_hide.connect(_on_selector_closed)


func _on_edit_pressed() -> void:
	var selected = property_list.get_selected_items()
	if selected.is_empty():
		return
	var instructions: Array = _edited_object.get(_property_name)
	var index = selected[0]
	if index >= 0 and index < instructions.size():
		EditorInterface.edit_resource(instructions[index])


func _on_remove_pressed() -> void:
	var selected = property_list.get_selected_items()
	if selected.is_empty():
		return
	var instructions: Array[BaseInstruction] = _edited_object.get(_property_name)
	for i in range(selected.size() - 1, -1, -1):
		instructions.remove_at(selected[i])
	_edited_object.set(_property_name, instructions)
	refresh()


func _on_copy_pressed() -> void:
	var selected = property_list.get_selected_items()
	if selected.is_empty():
		return
	var instructions: Array[BaseInstruction] = _edited_object.get(_property_name)
	var to_copy: Array[BaseInstruction] = []
	for idx in selected:
		if idx < instructions.size():
			to_copy.append(instructions[idx].duplicate(true))
	instructions.append_array(to_copy)
	_edited_object.set(_property_name, instructions)
	refresh()


func _on_selector_closed() -> void:
	refresh()


# ---- 导出为预设 (Stage 2.3) ----

func _on_export_pressed() -> void:
	var instructions: Array[BaseInstruction] = _edited_object.get(_property_name)
	if instructions.is_empty():
		return
	var dialog := PresetExportDialog.new(instructions)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.confirmed.connect(_on_export_confirmed.bind(dialog))
	dialog.popup_centered()


func _on_export_confirmed(dialog: PresetExportDialog) -> void:
	var preset := dialog.get_preset()
	var dir_path := dialog.get_folder_path()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var base_name := preset.display_name.to_snake_case()
	var tres_path := "%s/%s.tres" % [dir_path, base_name]
	ResourceSaver.save(preset, tres_path)
	var json_path := "%s/%s.json" % [dir_path, base_name]
	var file := FileAccess.open(json_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(preset.to_json(), "\t"))
		file.close()
	PresetRegistry.scan_presets()
	var fs := EditorInterface.get_resource_filesystem()
	fs.filesystem_changed.connect(_on_fs_ready_for_navigate.bind(tres_path), CONNECT_ONE_SHOT)
	fs.scan()
func _on_fs_ready_for_navigate(tres_path: String) -> void:
	EditorInterface.get_file_system_dock().navigate_to_path(tres_path)

