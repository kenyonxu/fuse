# 文件：addons/fuse/editor/input_key_selector/input_key_dialog.gd
@tool
class_name InputKeyDialog extends AcceptDialog

signal key_selected(key_code: int)

var instruction_label: Label
var waiting_for_key: bool = false
var _fuse_localization_class: RefCounted = null  # 缓存本地化类引用

func _init():
	# 加载本地化类
	_fuse_localization_class = load("res://addons/fuse/localization/fuse_localization.gd")

	# 本地化对话框标题
	_update_dialog_title()
	min_size = Vector2(300, 150)

	instruction_label = Label.new()
	# 本地化指示文本
	_update_instruction_text()
	add_child(instruction_label)

	var start_button = Button.new()
	# 本地化按钮文本
	_update_start_button_text(start_button)
	start_button.pressed.connect(_start_capture)
	add_child(start_button)

	# 移除错误的 gui_input 信号连接
	# connect("gui_input", _on_gui_input)

func _start_capture() -> void:
	waiting_for_key = true
	# 本地化等待按键提示
	_update_waiting_text()
	print("DEBUG: === 使用 window_input 信号 === 开始捕获按键，waiting_for_key =", waiting_for_key)
	
	# 关键修复：直接使用对话框自身的 window_input 信号
	# 因为 AcceptDialog 继承自 Window，它应该有自己的 window_input 信号
	print("DEBUG: 使用对话框自身的 window_input 信号")
	print("DEBUG: 对话框类型 =", typeof(self))
	print("DEBUG: 对话框类名 =", self.get_class())
	
	# 检查对话框自身是否有 window_input 信号
	if self.has_signal("window_input"):
		print("DEBUG: 对话框有 window_input 信号")
		var error = self.connect("window_input", _on_window_input)
		print("DEBUG: 连接结果:", error)
		if error == OK:
			print("DEBUG: window_input 信号连接成功")
		else:
			print("DEBUG: 连接失败，错误码:", error)
	else:
		print("DEBUG: 对话框没有 window_input 信号")
		# 列出所有可用的信号
		print("DEBUG: 对话框的信号:", self.get_signal_list())
		
		# 备用方案：尝试使用 SceneTree 的全局输入处理
		print("DEBUG: 尝试使用 SceneTree 输入处理")
		var tree = get_tree()
		if tree:
			print("DEBUG: 连接到 SceneTree 的 input 信号")
			var error = tree.connect("input", _on_tree_input)
			if error == OK:
				print("DEBUG: SceneTree input 信号连接成功")
			else:
				print("DEBUG: SceneTree input 连接失败，错误码:", error)

func _on_window_input(event: InputEvent):
	print("DEBUG: === _on_window_input 被调用 ===")
	print("DEBUG: waiting_for_key =", waiting_for_key)
	print("DEBUG: event 类型 =", typeof(event))
	print("DEBUG: event 类名 =", event.get_class() if event else "null")
	
	if not waiting_for_key:
		print("DEBUG: 不在等待按键状态，返回")
		return
	
	# 详细记录所有事件信息
	print("DEBUG: 收到事件:", event)
	if event is InputEventKey:
		print("DEBUG: 是 InputEventKey 事件")
		print("DEBUG: keycode =", event.keycode)
		print("DEBUG: pressed =", event.pressed)
		print("DEBUG: is_echo =", event.is_echo())
		print("DEBUG: as_text =", event.as_text())
	else:
		print("DEBUG: 不是 InputEventKey 事件，类型 =", typeof(event))
	
	# 过滤按键事件 - 只处理按键按下事件
	if event is InputEventKey and event.pressed and not event.is_echo():
		print("DEBUG: ✅ 检测到有效按键按下:", event.keycode, "文本:", event.as_text())
		key_selected.emit(event.keycode)
		print("DEBUG: ✅ 已发送 key_selected 信号")
		
		# 断开 window_input 信号连接
		if self.has_signal("window_input"):
			if self.window_input.is_connected(_on_window_input):
				self.window_input.disconnect(_on_window_input)
				print("DEBUG: ✅ window_input 信号已断开")
		
		print("DEBUG: ✅ 准备隐藏对话框")
		hide()
	else:
		print("DEBUG: ❌ 不是有效按键按下事件")

func _on_tree_input(event: InputEvent):
	print("DEBUG: === _on_tree_input 被调用 ===")
	print("DEBUG: waiting_for_key =", waiting_for_key)
	print("DEBUG: event 类型 =", typeof(event))
	
	if not waiting_for_key:
		return
	
	# 过滤按键事件 - 只处理按键按下事件
	if event is InputEventKey and event.pressed and not event.is_echo():
		print("DEBUG: ✅ 通过 SceneTree 检测到有效按键按下:", event.keycode, "文本:", event.as_text())
		key_selected.emit(event.keycode)
		
		# 断开 SceneTree input 信号连接
		var tree = get_tree()
		if tree:
			if tree.has_signal("input"):
				if tree.input.is_connected(_on_tree_input):
					tree.input.disconnect(_on_tree_input)
		
		hide()

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if not visible:
			waiting_for_key = false
			print("DEBUG: 对话框隐藏，清理信号连接")
			# 确保在对话框关闭时断开所有信号连接
			if self.has_signal("window_input"):
				if self.window_input.is_connected(_on_window_input):
					self.window_input.disconnect(_on_window_input)
					print("DEBUG: 隐藏时 window_input 信号已断开")
			
			# 断开 SceneTree input 信号连接
			var tree = get_tree()
			if tree:
				if tree.has_signal("input"):
					if tree.input.is_connected(_on_tree_input):
						tree.input.disconnect(_on_tree_input)
						print("DEBUG: 隐藏时 SceneTree input 信号已断开")

func _exit_tree():
	print("DEBUG: _exit_tree called")
	# 确保在节点退出时清理所有信号连接
	if self.has_signal("window_input"):
		if self.window_input.is_connected(_on_window_input):
			self.window_input.disconnect(_on_window_input)
			print("DEBUG: 退出时 window_input 信号已断开")

	# 断开 SceneTree input 信号连接
	var tree = get_tree()
	if tree:
		if tree.has_signal("input"):
			if tree.input.is_connected(_on_tree_input):
				tree.input.disconnect(_on_tree_input)
				print("DEBUG: 退出时 SceneTree input 信号已断开")


## ==================== 本地化辅助方法 ====================

## 更新对话框标题（本地化）
func _update_dialog_title() -> void:
	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		self.title = _fuse_localization_class.translate("FUSE_UI_INPUT_KEY_SELECTOR_TITLE")
	else:
		self.title = "选择按键"  # 回退文本

## 更新指示文本（本地化）
func _update_instruction_text() -> void:
	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		instruction_label.text = _fuse_localization_class.translate("FUSE_UI_INSTRUCTION_CLICK_TO_START")
	else:
		instruction_label.text = "点击下方按钮，然后按下任意键"  # 回退文本

## 更新开始按钮文本（本地化）
func _update_start_button_text(button: Button) -> void:
	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		button.text = _fuse_localization_class.translate("FUSE_UI_BTN_START_CAPTURE")
	else:
		button.text = "开始捕获按键"  # 回退文本

## 更新等待按键提示（本地化）
func _update_waiting_text() -> void:
	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		instruction_label.text = _fuse_localization_class.translate("FUSE_UI_WAITING_FOR_KEY")
	else:
		instruction_label.text = "请按下任意键..."  # 回退文本