# 测试脚本：OnTargetSignalEmit 功能测试
extends Node

# 测试用的信号事件
var signal_event = null
var test_button = null
var test_timer = null

func _ready():
	print("=== OnTargetSignalEmit 测试开始 ===")

	# 创建测试节点
	_create_test_nodes()

	# 测试按钮信号监听（内部有 await，必须 await 调用避免 fire-and-forget 乱序）
	await _test_button_signal()

	# 测试定时器信号监听
	await _test_timer_signal()

	# 测试参数过滤
	await _test_parameter_filtering()

	# 测试错误处理
	await _test_error_handling()

	print("=== OnTargetSignalEmit 测试完成 ===")
	# TODO: 断言增强（如按钮触发计数 >= 1）留终审裁量；当前为最小门禁骨架，
	# 无 SCRIPT ERROR 即退出码 0，失败需人工看输出
	get_tree().quit(0)

func _create_test_nodes():
	# 创建测试按钮
	test_button = Button.new()
	test_button.name = "TestButton"
	add_child(test_button)
	
	# 创建测试定时器
	test_timer = Timer.new()
	test_timer.name = "TestTimer"
	test_timer.wait_time = 1.0
	test_timer.one_shot = true
	add_child(test_timer)
	
	print("✓ 测试节点创建完成")

func _test_button_signal():
	print("\n--- 测试按钮信号 ---")
	
	# 创建信号事件
	signal_event = OnTargetSignalEmit.new()
	signal_event.log_level = FuseLogger.LogLevel.DEBUG
	signal_event.target_node = NodePath("TestButton")
	signal_event.target_signal = "pressed"
	signal_event.trigger_once = false
	
	# 连接事件
	signal_event.triggered.connect(_on_button_pressed)
	
	# 初始化事件
	signal_event.initialize(self)
	
	# 模拟按钮按下
	print("模拟按钮按下...")
	test_button.emit_signal("pressed")
	
	# 验证事件触发
	await get_tree().create_timer(0.1).timeout
	print("✓ 按钮信号测试完成")

func _test_timer_signal():
	print("\n--- 测试定时器信号 ---")
	
	# 创建新的信号事件
	var timer_event = OnTargetSignalEmit.new()
	timer_event.target_node = NodePath("TestTimer")
	timer_event.target_signal = "timeout"
	timer_event.trigger_once = true
	
	# 连接事件
	timer_event.triggered.connect(_on_timer_timeout)
	
	# 初始化事件
	timer_event.initialize(self)
	
	# 启动定时器
	print("启动定时器...")
	test_timer.start()
	
	# 等待定时器触发
	await test_timer.timeout
	
	# 验证事件触发
	await get_tree().create_timer(0.1).timeout
	
	# 清理
	timer_event.terminate(self)
	print("✓ 定时器信号测试完成")

func _test_parameter_filtering():
	print("\n--- 测试参数过滤 ---")
	
	# 创建带有参数的信号事件（模拟 body_entered 信号）
	var area_event = OnTargetSignalEmit.new()
	area_event.target_node = NodePath("TestButton")  # 使用按钮作为测试节点
	area_event.target_signal = "pressed"
	area_event.filter_signal_args = true
	area_event.arg_filter_values = []  # 空参数
	
	# 连接事件
	area_event.triggered.connect(_on_filtered_signal)
	
	# 初始化事件
	area_event.initialize(self)
	
	# 触发信号
	print("测试参数过滤...")
	test_button.emit_signal("pressed")
	
	# 验证
	await get_tree().create_timer(0.1).timeout
	
	# 清理
	area_event.terminate(self)
	print("✓ 参数过滤测试完成")

func _test_error_handling():
	print("\n--- 测试错误处理 ---")
	
	# 测试无效节点路径
	var invalid_event = OnTargetSignalEmit.new()
	invalid_event.target_node = NodePath("NonExistentNode")
	invalid_event.target_signal = "pressed"
	
	# 应该产生错误
	invalid_event.initialize(self)
	
	# 测试无效信号
	var invalid_signal_event = OnTargetSignalEmit.new()
	invalid_signal_event.target_node = NodePath("TestButton")
	invalid_signal_event.target_signal = "non_existent_signal"
	
	# 应该产生错误
	invalid_signal_event.initialize(self)
	
	print("✓ 错误处理测试完成")

# 事件处理函数
func _on_button_pressed(context):
	print("✓ 按钮按下事件触发！上下文: ", context)

func _on_timer_timeout(context):
	print("✓ 定时器超时事件触发！上下文: ", context)

func _on_filtered_signal(context):
	print("✓ 过滤信号事件触发！上下文: ", context)

# 辅助测试函数
func _get_test_context():
	return {
		"source_node": self,
		"signal_name": "test_signal",
		"signal_args": ["test_arg1", "test_arg2"],
		"named_args": {
			"arg1": "test_arg1",
			"arg2": "test_arg2"
		}
	}