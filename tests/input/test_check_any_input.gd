extends Node2D

## CheckAnyInput 条件测试脚本

@onready var check_any_input = $CheckAnyInput
@onready var label = $Label

var _test_enabled: bool = false

func _ready():
	print("=== CheckAnyInput 条件测试开始 ===")
	print("\n说明：")
	print("- 此测试场景需要手动按下按键来测试条件")
	print("- 条件会检测：Input Map 动作、原始键盘输入、手柄按钮")
	print("- 按 ESC 退出测试场景\n")

	# 等待用户按任意键开始测试
	_test_enabled = false
	await get_tree().process_frame
	_test_enabled = true

	# 显示初始状态
	_update_label()

	print("测试已启动，按任意键开始检测...")
	print("配置：")
	print("  - Input Map 动作检测: %s" % check_any_input.check_input_map_actions)
	print("  - 原始键盘检测: %s" % check_any_input.check_raw_keyboard)
	print("  - 原始手柄检测: %s" % check_any_input.check_raw_gamepad)
	print("  - 手柄设备索引: %s\n" % check_any_input.gamepad_device)

func _input(event: InputEvent):
	if not _test_enabled:
		return

	# 检查退出
	if event.is_action_pressed("ui_cancel"):
		print("\n=== 测试退出 ===")
		get_tree().quit()
		return

	# 只在按键按下时测试
	if not event.is_pressed():
		return

	# 创建执行上下文
	var context = ExecutionContext.new()
	add_child(context)

	# 测试条件
	var result = check_any_input.check(context)

	# 输出结果
	print("---")
	print("输入事件类型: %s" % event.get_class())
	print("条件检测结果: %s" % ("✓ 检测到输入" if result else "✗ 未检测到输入"))

	# 显示详细信息
	if event is InputEventKey:
		var key_event = event as InputEventKey
		print("  按键代码: %d" % key_event.keycode)
	elif event is InputEventJoypadButton:
		var joy_event = event as InputEventJoypadButton
		print("  手柄设备: %d" % joy_event.device)
		print("  按钮索引: %d" % joy_event.button_index)

	print("---")

	# 更新 UI
	_update_label()

	# 清理上下文
	context.queue_free()

func _update_label():
	var text = "CheckAnyInput 条件测试\n\n"
	text += "按任意按键测试条件检测：\n"
	text += "- A-Z 字母键\n"
	text += "- 0-9 数字键\n"
	text += "- 空格、回车、Esc 等\n"
	text += "- 手柄按钮（如果已连接）\n\n"
	text += "观察控制台输出\n\n"
	text += "配置：\n"
	text += "✓ Input Map 动作: %s\n" % ("启用" if check_any_input.check_input_map_actions else "禁用")
	text += "✓ 原始键盘: %s\n" % ("启用" if check_any_input.check_raw_keyboard else "禁用")
	text += "✓ 原始手柄: %s\n" % ("启用" if check_any_input.check_raw_gamepad else "禁用")
	text += "  手柄设备: %s\n\n" % ("全部" if check_any_input.gamepad_device < 0 else "设备 %d" % check_any_input.gamepad_device)
	text += "按 ESC 退出"

	label.text = text
