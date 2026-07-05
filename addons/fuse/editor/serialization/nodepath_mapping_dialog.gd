# addons/fuse/editor/serialization/nodepath_mapping_dialog.gd
@tool
class_name NodePathMappingDialog
extends AcceptDialog

## NodePath 映射确认对话框
##
## 显示预设中所有 NodePath 引用及其自动匹配结果，
## 用户可手动修正无匹配项，确认后通过 get_final_mapping() 返回最终映射表。

## mapping: NodePathResolver.resolve_mapping 的输出
##  {old_str: {"new": NodePath, "matched": bool, "suggestions": Array[String]}}
var _mapping: Dictionary = {}
var _option_buttons: Dictionary = {}  # old_str → OptionButton
var _target_node: Node


func _init(p_mapping: Dictionary, p_target: Node) -> void:
	_mapping = p_mapping
	_target_node = p_target
	title = "NodePath 映射"
	ok_button_text = "确认导入"
	_build_ui()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(520, 0)
	add_child(vbox)

	# 说明
	var header := Label.new()
	header.text = "以下路径需要映射到当前场景的节点："
	header.add_theme_font_size_override("font_size", 13)
	vbox.add_child(header)

	# 每行一个 NodePath 映射
	for old_np_str in _mapping:
		var result: Dictionary = _mapping[old_np_str]
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)

		# 旧路径标签
		var old_label := Label.new()
		old_label.text = old_np_str
		old_label.custom_minimum_size.x = 160
		old_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		hbox.add_child(old_label)

		# 箭头
		var arrow := Label.new()
		arrow.text = "→"
		arrow.custom_minimum_size.x = 20
		hbox.add_child(arrow)

		# 新路径选择
		var option := OptionButton.new()
		option.custom_minimum_size.x = 300
		option.fit_to_longest_item = false

		if result.matched:
			# 自动匹配成功 — 结果作为默认选项，场景节点作为备选
			var auto_text := str(result["new"])
			option.add_item("✓ " + auto_text)
			option.selected = 0
			for sug in result.get("suggestions", []):
				if sug != auto_text and not _option_contains(option, sug):
					option.add_item(sug)
		else:
			# 无匹配 — 场景节点全量列出
			var suggestions: Array = result.get("suggestions", [])
			if suggestions.is_empty():
				option.add_item("⚠ 场景中无可用节点")
			else:
				option.add_item("⚠ 请选择节点...")
				for sug in suggestions:
					option.add_item(sug)

		hbox.add_child(option)
		_option_buttons[old_np_str] = option
		vbox.add_child(hbox)


## 检查 OptionButton 中是否已包含某文本
static func _option_contains(option: OptionButton, text: String) -> bool:
	for i in option.item_count:
		if option.get_item_text(i) == text:
			return true
	return false


## 用户确认后调用，返回 {old_np_str: NodePath(new_path)}
func get_final_mapping() -> Dictionary:
	var final_mapping: Dictionary = {}
	for old_np_str in _option_buttons:
		var option: OptionButton = _option_buttons[old_np_str]
		var selected_text := option.get_item_text(option.selected)
		var clean := selected_text
		# 去掉前缀标识
		if clean.begins_with("✓ "):
			clean = clean.substr(2)
		elif clean.begins_with("⚠ "):
			clean = clean.substr(2)
		if clean != "" and not clean.begins_with("请选择"):
			final_mapping[old_np_str] = NodePath(clean)
	return final_mapping
