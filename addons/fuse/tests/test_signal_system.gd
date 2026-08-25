# 测试脚本：SignalInfo 和 SignalManager 系统测试
extends Node

func _ready():
	print("=== Signal 系统测试开始 ===")

	# 测试 SignalInfo
	_test_signal_info()

	# 测试 SignalManager
	_test_signal_manager()

	# 测试 OnTargetSignalEmit
	_test_event_on_target_signal_emit()

	print("=== Signal 系统测试完成 ===")

func _test_signal_info():
	print("\n--- 测试 SignalInfo ---")

	# 创建模拟的信号字典
	var signal_dict = {
		"name": "pressed",
		"args": [
			{"name": "button", "type": TYPE_OBJECT},
			{"name": "position", "type": TYPE_VECTOR2}
		],
		"default_args": [null, Vector2(0, 0)],
		"flags": 0
	}

	# 从字典创建 SignalInfo
	var signal_info = SignalInfo.from_godot_signal(signal_dict, "Button")

	# 测试基本功能
	print("信号名称: ", signal_info.name)
	print("信号签名: ", signal_info.get_signature())
	print("显示名称: ", signal_info.get_display_name())
	print("参数数量: ", signal_info.has_arg_count(2))
	print("参数类型: ", signal_info.get_arg_type_strings())

	# 测试参数验证
	var valid_args = [self, Vector2(100, 200)]
	var invalid_args = ["string", 123]

	print("有效参数验证: ", signal_info.validate_args(valid_args))
	print("无效参数验证: ", signal_info.validate_args(invalid_args))

	# 测试序列化
	var serialized = signal_info.serialize()
	print("序列化数据: ", serialized)

	# 测试反序列化
	var new_signal_info = SignalInfo.new()
	new_signal_info.deserialize(serialized)
	print("反序列化后名称: ", new_signal_info.name)

	print("✓ SignalInfo 测试完成")

func _test_signal_manager():
	print("\n--- 测试 SignalManager ---")

	# 创建测试节点
	var test_button = Button.new()
	test_button.name = "TestButton"
	add_child(test_button)

	# 测试获取节点信号
	var signals = SignalManager.get_node_signals(test_button)
	print("按钮信号数量: ", signals.size())

	# 测试获取信号名称
	var signal_names = SignalManager.get_signal_names(test_button)
	print("信号名称列表: ", signal_names)

	# 测试查找特定信号
	var pressed_signal = SignalManager.find_signal_by_name(test_button, "pressed")
	if pressed_signal:
		print("找到 pressed 信号: ", pressed_signal.get_signature())

	# 测试检查信号存在
	var has_pressed = SignalManager.has_signal_named(test_button, "pressed")
	print("是否有 pressed 信号: ", has_pressed)

	# 测试缓存统计
	var stats = SignalManager.get_cache_stats()
	print("缓存统计: ", stats)

	# 清理测试节点
	test_button.queue_free()

	print("✓ SignalManager 测试完成")

func _test_event_on_target_signal_emit():
	print("\n--- 测试 OnTargetSignalEmit ---")

	# 创建测试按钮
	var test_button = Button.new()
	test_button.name = "TestButton"
	add_child(test_button)

	# 创建信号事件
	var signal_event = OnTargetSignalEmit.new()
	signal_event.target_node_path = "TestButton"
	signal_event.target_signal = "pressed"
	signal_event.trigger_once = false

	# 连接事件
	signal_event.triggered.connect(_on_test_signal_triggered)

	# 初始化事件
	signal_event.initialize(self)

	# 模拟按钮按下
	print("模拟按钮按下...")
	test_button.emit_signal("pressed")

	# 等待事件处理
	await get_tree().create_timer(0.1).timeout

	# 清理
	signal_event.terminate(self)
	test_button.queue_free()

	print("✓ OnTargetSignalEmit 测试完成")

# 事件处理函数
func _on_test_signal_triggered(context):
	print("✓ 信号事件触发！上下文: ", context)
	print("  源节点: ", context.get("source_node", "未知"))
	print("  信号名称: ", context.get("signal_name", "未知"))
	print("  信号参数: ", context.get("signal_args", []))
	if context.has("named_args"):
		print("  命名参数: ", context.named_args)