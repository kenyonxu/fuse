# addons/fuse/editor/preset_import_dialog.gd
@tool
class_name PresetImportDialog
extends AcceptDialog

## 导入映射对话框 — 按 level 创建对应节点，含 NodePath 映射 + 变量依赖检查

var _preset: FusePreset
var _created_node: Node = null


func _init(preset: FusePreset) -> void:
	_preset = preset
	title = "应用预设: %s [%s]" % [preset.display_name, preset.level]
	ok_button_text = "创建节点"
	confirmed.connect(_on_create_node)
	_build_ui()

func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	add_child(vbox)

	# Level 信息
	var level_label := Label.new()
	level_label.text = _level_display()
	level_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	vbox.add_child(level_label)

	# 描述
	var desc_label := Label.new()
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.text = "%s · %s\n%s" % [_preset.category, _preset.display_name, _preset.description]
	vbox.add_child(desc_label)

	# L3 特殊：信号源节点
	if _preset.level == "L3":
		vbox.add_child(_make_section("信号源节点"))
		var hbox := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "信号源:"
		hbox.add_child(lbl)
		var option := OptionButton.new()
		option.add_item("选择节点...")
		option.custom_minimum_size.x = 200
		hbox.add_child(option)
		vbox.add_child(hbox)

	# 变量检查
	_build_variable_section(vbox)

func _level_display() -> String:
	match _preset.level:
		"L1": return "L1 · ActionRunner（将创建 Resource，不创建节点）"
		"L2": return "L2 · Trigger（将创建 Trigger 节点）"
		"L3": return "L3 · Runner（将创建 Runner 节点）"
		"L4": return "L4 · MultiEventTrigger（将创建 MultiEventTrigger 节点）"
	return _preset.level

func _build_variable_section(vbox: VBoxContainer) -> void:
	var vars := _preset.collect_variables()
	if vars.local.is_empty() and vars.scope.is_empty() and vars.global.is_empty():
		return
	vbox.add_child(_make_section("变量依赖"))
	if not vars.local.is_empty():
		vbox.add_child(_make_var_line("[local] %s — 运行时自动创建" % ", ".join(vars.local)))
	if not vars.global.is_empty():
		vbox.add_child(_make_var_line("[global] %s — 项目级存在" % ", ".join(vars.global)))

func _make_section(title: String) -> Label:
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 13)
	return lbl

func _make_var_line(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = "  " + text
	lbl.add_theme_color_override("font_color", Color.GRAY)
	return lbl

func _on_create_node() -> void:
	var parent := _get_target_parent()
	if parent == null:
		push_warning("无法确定挂载点，取消导入")
		return

	# NodePath 映射：提取 → 自动匹配 → 用户确认 → 导入
	var nodepaths := NodePathResolver.extract_nodepaths(_preset.instructions)
	if nodepaths.is_empty():
		# 无 NodePath，直接导入
		_do_import(parent, {})
		return

	var mapping_suggestions := NodePathResolver.resolve_mapping(nodepaths, parent)
	var dialog := NodePathMappingDialog.new(mapping_suggestions, parent)
	dialog.canceled.connect(func():
		push_warning("导入已取消（NodePath 映射未确认）")
	)
	dialog.confirmed.connect(func():
		var final_mapping := dialog.get_final_mapping()
		_do_import(parent, final_mapping)
	)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()


func _do_import(parent: Node, mapping: Dictionary) -> void:
	# 反序列化
	_created_node = FusePresetDeserializer.deserialize(_preset, mapping)

	if _created_node == null:
		push_error("节点创建失败")
		return

	# L1 不需要挂到场景
	if _preset.level == "L1":
		print("ActionRunner Resource 已创建: %s" % _created_node.resource_name)
		return

	# 挂到场景
	parent.add_child(_created_node)
	_created_node.owner = parent.owner if parent.owner else parent

	# 导入后校验（§9.1）
	var warnings := FusePresetDeserializer.validate_imported_node(_created_node, _preset.level)
	if not warnings.is_empty():
		_show_import_warnings(warnings)

	print("节点已创建: %s (%s)" % [_created_node.name, _preset.level])


func _get_target_parent() -> Node:
	var selection := EditorInterface.get_selection()
	if selection:
		var selected_nodes := selection.get_selected_nodes()
		if not selected_nodes.is_empty():
			return selected_nodes[0]
	var scene_root := EditorInterface.get_edited_scene_root()
	return scene_root

func _show_import_warnings(warnings: Array[String]) -> void:
	var msg := "导入完成，但有以下警告:\n\n" + "\n".join(warnings)
	var dialog := AcceptDialog.new()
	dialog.title = "导入警告"
	dialog.dialog_text = msg
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()
