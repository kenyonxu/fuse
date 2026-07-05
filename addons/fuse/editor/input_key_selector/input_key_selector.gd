# 文件：addons/fuse/editor/input_key_selector/input_key_selector.gd
@tool
class_name InputKeySelector extends EditorProperty

var dialog: InputKeyDialog
var property_control: Button
var current_key_code: int = KEY_NONE
var _fuse_localization_class: RefCounted = null  # 缓存本地化类引用

func _init():
	property_control = Button.new()
	# 本地化按钮文本
	_update_button_text()
	property_control.pressed.connect(_on_button_pressed)
	add_child(property_control)
	add_focusable(property_control)

func _on_button_pressed() -> void:
	# 确保对话框在场景树中
	if not is_inside_tree():
		return

	# 如果已有对话框，先清理
	if dialog and is_instance_valid(dialog):
		dialog.queue_free()

	dialog = InputKeyDialog.new()
	dialog.key_selected.connect(_on_key_selected)

	# 添加到场景树中
	var root = get_tree().get_root()
	root.add_child(dialog)

	# 延迟一帧再显示对话框，确保它已正确添加到场景树
	await get_tree().process_frame
	if dialog and is_instance_valid(dialog) and dialog.is_inside_tree():
		dialog.popup_centered()

func _on_key_selected(key_code: int) -> void:
	current_key_code = key_code
	var key_name = OS.get_keycode_string(key_code)
	# 本地化按键显示格式
	_update_button_text_with_key(key_name)
	emit_changed(get_edited_property(), key_code)
	print("DEBUG: 按键已选择 - key_code:", key_code, "key_name:", key_name)

func _update_property() -> void:
	var object = get_edited_object()
	if object and object.has_method("get"):
		current_key_code = object.get(get_edited_property())
		var key_name = OS.get_keycode_string(current_key_code)
		# 本地化按键显示格式
		_update_button_text_with_key(key_name)

## 更新按钮文本（本地化）
func _update_button_text() -> void:
	# 加载本地化类
	if _fuse_localization_class == null:
		_fuse_localization_class = load("res://addons/fuse/localization/fuse_localization.gd")

	# 使用翻译或回退文本
	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		property_control.text = _fuse_localization_class.translate("FUSE_UI_BTN_SELECT_KEY")
	else:
		property_control.text = "选择按键"  # 回退文本

## 更新按钮文本并显示按键（本地化）
func _update_button_text_with_key(key_name: String) -> void:
	# 加载本地化类
	if _fuse_localization_class == null:
		_fuse_localization_class = load("res://addons/fuse/localization/fuse_localization.gd")

	# 使用翻译或回退文本
	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		var key_label = _fuse_localization_class.translate("FUSE_UI_KEY_LABEL")
		property_control.text = key_label + ": " + key_name
	else:
		property_control.text = "按键: " + key_name  # 回退文本