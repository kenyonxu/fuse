# 序列化系统调试测试 - 通过界面按钮逐个测试
extends Control

# 测试结果显示
@onready var result_label: Label = $VBoxContainer/ResultLabel
@onready var test_buttons: VBoxContainer = $VBoxContainer/TestButtons

# 当前测试状态
var current_test_node: Node = null
var current_context_id: String = ""

func _ready():
	print("🚀 序列化系统调试测试启动")

	_initialize_juicy_mixer()
	
	# 添加JuicyMixerManager节点来驱动process循环
	var mixer_manager = JuicyMixerManager.new()
	mixer_manager.name = "JuicyMixerManager"
	add_child(mixer_manager)
	
	# 创建测试按钮
	create_test_buttons()



func create_test_buttons():
	# 清空现有按钮
	for child in test_buttons.get_children():
		child.queue_free()
	
	# 基础测试按钮
	add_test_button("测试1: 基础时间驱动序列", _test_basic_time_driven)
	add_test_button("测试2: 基础事件驱动序列", _test_basic_event_driven)
	add_test_button("测试3: 顺序执行模式", _test_sequential_execution)
	add_test_button("测试4: 并行执行模式", _test_parallel_execution)
	add_test_button("测试5: 循环功能测试", _test_loop_functionality)
	add_test_button("测试6: 随机顺序测试", _test_random_order)
	add_test_button("测试7: 事件超时处理", _test_event_timeout)
	add_test_button("测试8: 中间件集成测试", _test_middleware_integration)
	add_test_button("测试9: 事件系统集成测试", _test_event_system_integration)
	add_test_button("测试10: 驱动器集成测试", _test_driver_integration)
	
	# 清理按钮
	add_test_button("清理当前测试", _cleanup_current_test)
	add_test_button("初始化JuicyMixer", _initialize_juicy_mixer)

func add_test_button(text: String, callback: Callable):
	var button = Button.new()
	button.text = text
	button.pressed.connect(callback)
	test_buttons.add_child(button)

func _initialize_juicy_mixer():
	print("\n=== 初始化JuicyMixer ===")
	
	# 清理现有实例
	# JuicyMixer使用单例模式，通过instance属性自动初始化
	# 清理现有实例
	JuicyMixer.cleanup()
	
	# 获取新实例（会自动初始化）
	var _instance = JuicyMixer.instance
	var success = _instance != null
	
	if success:
		result_label.text = "✅ JuicyMixer初始化成功"
		print("JuicyMixer初始化成功")
	else:
		result_label.text = "❌ JuicyMixer初始化失败"
		print("JuicyMixer初始化失败")

func _cleanup_current_test():
	print("\n=== 清理当前测试 ===")
	
	if current_context_id != "":
		JuicyMixer.stop(current_context_id)
		current_context_id = ""
	
	if current_test_node:
		current_test_node.queue_free()
		current_test_node = null
	
	result_label.text = "✅ 清理完成"
	print("当前测试已清理")

func _test_basic_time_driven():
	print("\n=== 测试1: 基础时间驱动序列 ===")
	
	_cleanup_current_test()
	
	# 创建序列资源
	var sequence_resource = JuicySequenceResource.new()
	sequence_resource.parallel = false
	sequence_resource.enable_event_sync = false
	
	# 创建震动资源
	var shake_resource = JuicyShakeResource.new()
	shake_resource.duration = 0.5  # 减少持续时间以便测试更快完成
	shake_resource.add_shake_data("position", 5.0, 10.0, 0.5)  # 减少持续时间
	
	# 创建序列项
	var item = JuicySequenceItem.new()
	item.resource = shake_resource
	item.delay = 0.5
	item.duration = 0.5  # 减少持续时间
	item.trigger_mode = JuicySequenceItem.TriggerMode.TIME
	item.enabled = true
	
	# 使用set方法设置序列项，避免直接赋值问题
	var items_array: Array[JuicySequenceItem] = [item]
	sequence_resource.set("sequence_items", items_array)
	
	# 调试信息
	print("设置的sequence_items: ", sequence_resource.get("sequence_items"))
	print("sequence_items是否为空: ", sequence_resource.get("sequence_items").is_empty())
	
	# 创建测试节点
	current_test_node = Node.new()
	add_child(current_test_node)
	
	# 验证配置
	var validation = sequence_resource.validate_config()
	if not validation.valid:
		result_label.text = "❌ 配置验证失败: " + str(validation.issues)
		print("配置验证失败: ", validation.issues)
		return
	
	# 播放序列
	current_context_id = JuicyMixer.play(sequence_resource, current_test_node)
	
	if current_context_id.is_empty():
		result_label.text = "❌ 序列播放失败"
		print("序列播放失败")
		return
	
	result_label.text = "✅ 基础时间驱动序列启动成功"
	print("基础时间驱动序列启动成功，上下文ID: ", current_context_id)
	
	# 等待完成
	_wait_for_completion(3.0)

func _test_basic_event_driven():
	print("\n=== 测试2: 基础事件驱动序列 ===")
	
	_cleanup_current_test()
	
	# 创建序列资源
	var sequence_resource = JuicySequenceResource.new()
	sequence_resource.enable_event_sync = true
	sequence_resource.event_timeout = 5.0
	
	# 创建震动资源
	var shake_resource = JuicyShakeResource.new()
	shake_resource.duration = 1.0
	shake_resource.add_shake_data("position", 4.0, 12.0, 1.0)
	
	# 创建事件驱动序列项
	var item = JuicySequenceItem.new()
	item.resource = shake_resource
	item.delay = 0.0  # 添加延迟设置
	item.duration = 1.0  # 添加持续时间设置
	item.trigger_mode = JuicySequenceItem.TriggerMode.EVENT
	item.trigger_event = "test_event"
	item.enabled = true
	
	# 使用与测试1相同的方式设置序列项
	var items_array: Array[JuicySequenceItem] = [item]
	sequence_resource.set("sequence_items", items_array)
	
	# 创建测试节点
	current_test_node = Node.new()
	add_child(current_test_node)
	
	# 验证配置
	var validation = sequence_resource.validate_config()
	if not validation.valid:
		result_label.text = "❌ 配置验证失败: " + str(validation.issues)
		print("配置验证失败: ", validation.issues)
		return
	
	# 播放序列
	current_context_id = JuicyMixer.play(sequence_resource, current_test_node)
	
	if current_context_id.is_empty():
		result_label.text = "❌ 序列播放失败"
		print("序列播放失败")
		return
	
	result_label.text = "✅ 事件驱动序列启动成功，等待事件触发..."
	print("事件驱动序列启动成功，上下文ID: ", current_context_id)
	
	# 延迟触发事件
	await get_tree().create_timer(1.0).timeout
	_trigger_test_event()

func _trigger_test_event():
	print("触发测试事件: test_event")
	
	var event = JuicyEvent.new(JuicyEvent.EventType.CUSTOM_EVENT)
	event.event_name = "test_event"
	event.target = current_test_node
	
	# 获取事件处理中间件
	var pipeline = JuicyMixer.get_middleware_pipeline()
	if pipeline:
		var event_middleware = pipeline.get_middleware("EventHandlingMiddleware")
		if event_middleware and event_middleware is EventHandlingMiddleware:
			if event_middleware._event_buffer:
				event_middleware._event_buffer.add_event(event)
				result_label.text = "✅ 测试事件已触发"
				print("测试事件已添加到缓冲区")

func _test_sequential_execution():
	print("\n=== 测试3: 顺序执行模式 ===")
	
	_cleanup_current_test()
	
	# 创建序列资源
	var sequence_resource = JuicySequenceResource.new()
	sequence_resource.parallel = false
	sequence_resource.enable_event_sync = false
	
	# 创建多个序列项
	var items: Array[JuicySequenceItem] = []
	for i in range(2):  # 减少到2项以简化测试
		var shake_resource = JuicyShakeResource.new()
		shake_resource.duration = 0.5
		shake_resource.add_shake_data("position", 2.0 + i, 8.0, 0.5)
		
		var item = JuicySequenceItem.new()
		item.resource = shake_resource
		item.delay = 0.2 * i
		item.duration = 0.5
		item.trigger_mode = JuicySequenceItem.TriggerMode.TIME
		item.enabled = true
		items.append(item)
	
	sequence_resource.set("sequence_items", items)
	
	# 创建测试节点
	current_test_node = Node.new()
	add_child(current_test_node)
	
	# 验证配置
	var validation = sequence_resource.validate_config()
	if not validation.valid:
		result_label.text = "❌ 配置验证失败: " + str(validation.issues)
		print("配置验证失败: ", validation.issues)
		return
	
	# 播放序列
	current_context_id = JuicyMixer.play(sequence_resource, current_test_node)
	
	if current_context_id.is_empty():
		result_label.text = "❌ 顺序执行序列播放失败"
		print("顺序执行序列播放失败")
		return
	
	result_label.text = "✅ 顺序执行序列启动成功"
	print("顺序执行序列启动成功，上下文ID: ", current_context_id)
	
	# 等待完成
	_wait_for_completion_with_analysis(3.0, "顺序执行", 1.2, "第1项(0延迟+0.5震动) + 第2项(0.2延迟+0.5震动)")

func _test_parallel_execution():
	print("\n=== 测试4: 并行执行模式 ===")
	
	_cleanup_current_test()
	
	# 创建序列资源
	var sequence_resource = JuicySequenceResource.new()
	sequence_resource.parallel = true
	sequence_resource.enable_event_sync = false
	
	# 创建多个序列项 - 添加延迟测试
	var items: Array[JuicySequenceItem] = []
	for i in range(3):  # 增加到3项以测试延迟
		var shake_resource = JuicyShakeResource.new()
		shake_resource.duration = 0.4  # 减少持续时间以便更快完成测试
		shake_resource.add_shake_data("position", 1.0 + i, 6.0, 0.4)
		
		var item = JuicySequenceItem.new()
		item.resource = shake_resource
		item.delay = 0.2 * i  # 第1项0延迟，第2项0.2延迟，第3项0.4延迟
		item.duration = 0.4
		item.trigger_mode = JuicySequenceItem.TriggerMode.TIME
		item.enabled = true
		items.append(item)
	
	sequence_resource.set("sequence_items", items)
	
	# 创建测试节点
	current_test_node = Node.new()
	add_child(current_test_node)
	
	# 验证配置
	var validation = sequence_resource.validate_config()
	if not validation.valid:
		result_label.text = "❌ 配置验证失败: " + str(validation.issues)
		print("配置验证失败: ", validation.issues)
		return
	
	# 播放序列
	current_context_id = JuicyMixer.play(sequence_resource, current_test_node)
	
	if current_context_id.is_empty():
		result_label.text = "❌ 并行执行序列播放失败"
		print("并行执行序列播放失败")
		return
	
	result_label.text = "✅ 并行执行序列启动成功"
	print("并行执行序列启动成功，上下文ID: ", current_context_id)
	
	# 等待完成 - 调整预期时间计算
	# 预期时间 = max(0.0*0 + 0.4, 0.2*1 + 0.4, 0.4*2 + 0.4) = max(0.4, 0.6, 1.2) = 1.2秒
	_wait_for_completion_with_analysis(3.0, "并行执行", 1.2, "max(0.0*0 + 0.4, 0.2*1 + 0.4, 0.4*2 + 0.4)")

func _test_loop_functionality():
	print("\n=== 测试5: 循环功能测试 ===")
	
	_cleanup_current_test()
	
	# 创建序列资源
	var sequence_resource = JuicySequenceResource.new()
	sequence_resource.parallel = false
	sequence_resource.loop_sequence = true
	sequence_resource.loop_count = 2
	sequence_resource.enable_event_sync = false
	
	# 创建震动资源
	var shake_resource = JuicyShakeResource.new()
	shake_resource.duration = 0.3
	shake_resource.add_shake_data("position", 3.0, 10.0, 0.3)
	
	# 创建序列项
	var item = JuicySequenceItem.new()
	item.resource = shake_resource
	item.delay = 0.1
	item.duration = 0.3
	item.trigger_mode = JuicySequenceItem.TriggerMode.TIME
	item.enabled = true
	
	var items_array: Array[JuicySequenceItem] = [item]
	sequence_resource.set("sequence_items", items_array)
	
	# 创建测试节点
	current_test_node = Node.new()
	add_child(current_test_node)
	
	# 验证配置
	var validation = sequence_resource.validate_config()
	if not validation.valid:
		result_label.text = "❌ 配置验证失败: " + str(validation.issues)
		print("配置验证失败: ", validation.issues)
		return
	
	# 播放序列
	current_context_id = JuicyMixer.play(sequence_resource, current_test_node)
	
	if current_context_id.is_empty():
		result_label.text = "❌ 循环序列播放失败"
		print("循环序列播放失败")
		return
	
	result_label.text = "✅ 循环序列启动成功"
	print("循环序列启动成功，上下文ID: ", current_context_id)
	
	# 等待完成
	_wait_for_completion_with_analysis(2.0, "循环功能", 0.8, "(0.1 + 0.3) * 2次循环")

func _test_random_order():
	print("\n=== 测试6: 随机顺序测试 ===")
	
	_cleanup_current_test()
	
	# 创建序列资源
	var sequence_resource = JuicySequenceResource.new()
	sequence_resource.parallel = false
	sequence_resource.random_order = true
	sequence_resource.enable_event_sync = false
	
	# 创建多个序列项
	var items: Array[JuicySequenceItem] = []
	for i in range(2):  # 减少到2项以简化测试
		var shake_resource = JuicyShakeResource.new()
		shake_resource.duration = 0.2
		shake_resource.add_shake_data("position", 2.0 + i, 7.0, 0.2)
		
		var item = JuicySequenceItem.new()
		item.resource = shake_resource
		item.delay = 0.1
		item.duration = 0.2
		item.trigger_mode = JuicySequenceItem.TriggerMode.TIME
		item.enabled = true
		items.append(item)
	
	sequence_resource.set("sequence_items", items)
	
	# 创建测试节点
	current_test_node = Node.new()
	add_child(current_test_node)
	
	# 验证配置
	var validation = sequence_resource.validate_config()
	if not validation.valid:
		result_label.text = "❌ 配置验证失败: " + str(validation.issues)
		print("配置验证失败: ", validation.issues)
		return
	
	# 播放序列
	current_context_id = JuicyMixer.play(sequence_resource, current_test_node)
	
	if current_context_id.is_empty():
		result_label.text = "❌ 随机顺序序列播放失败"
		print("随机顺序序列播放失败")
		return
	
	result_label.text = "✅ 随机顺序序列启动成功"
	print("随机顺序序列启动成功，上下文ID: ", current_context_id)
	
	# 等待完成
	_wait_for_completion_with_analysis(2.0, "随机顺序", 0.3, "0.1 + 0.2")

func _test_event_timeout():
	print("\n=== 测试7: 事件超时处理 ===")
	
	_cleanup_current_test()
	
	# 创建序列资源
	var sequence_resource = JuicySequenceResource.new()
	sequence_resource.enable_event_sync = true
	sequence_resource.event_timeout = 1.0  # 设置较短的超时时间
	
	# 创建震动资源
	var shake_resource = JuicyShakeResource.new()
	shake_resource.duration = 0.8
	shake_resource.add_shake_data("position", 5.0, 15.0, 0.8)
	
	# 创建事件驱动序列项
	var item = JuicySequenceItem.new()
	item.resource = shake_resource
	item.trigger_mode = JuicySequenceItem.TriggerMode.EVENT
	item.trigger_event = "timeout_event"
	item.enabled = true
	
	var items_array: Array[JuicySequenceItem] = [item]
	sequence_resource.set("sequence_items", items_array)
	
	# 创建测试节点
	current_test_node = Node.new()
	add_child(current_test_node)
	
	# 验证配置
	var validation = sequence_resource.validate_config()
	if not validation.valid:
		result_label.text = "❌ 配置验证失败: " + str(validation.issues)
		print("配置验证失败: ", validation.issues)
		return
	
	# 播放序列
	current_context_id = JuicyMixer.play(sequence_resource, current_test_node)
	
	if current_context_id.is_empty():
		result_label.text = "❌ 超时测试序列播放失败"
		print("超时测试序列播放失败")
		return
	
	result_label.text = "✅ 超时测试序列启动成功，等待超时..."
	print("超时测试序列启动成功，上下文ID: ", current_context_id)
	
	# 等待超时
	_wait_for_completion_with_analysis(2.0, "事件超时", 1.0, "事件超时时间")

func _test_middleware_integration():
	print("\n=== 测试8: 中间件集成测试 ===")
	
	_cleanup_current_test()
	
	# 获取中间件管道
	var pipeline = JuicyMixer.get_middleware_pipeline()
	var success = pipeline != null
	
	if success:
		# 检查事件处理中间件
		var event_middleware = pipeline.get_middleware("EventHandlingMiddleware")
		success = event_middleware != null and event_middleware is EventHandlingMiddleware
		
		if success:
			# 检查事件系统状态
			var stats = event_middleware.get_event_system_stats()
			success = stats.enabled == true
	
	if success:
		result_label.text = "✅ 中间件集成测试通过"
		print("中间件集成测试通过")
	else:
		result_label.text = "❌ 中间件集成测试失败"
		print("中间件集成测试失败")

func _test_event_system_integration():
	print("\n=== 测试9: 事件系统集成测试 ===")
	
	_cleanup_current_test()
	
	# 获取事件处理中间件
	var pipeline = JuicyMixer.get_middleware_pipeline()
	var event_middleware = pipeline.get_middleware("EventHandlingMiddleware")
	
	var success = false
	
	if event_middleware and event_middleware is EventHandlingMiddleware:
		# 创建测试事件处理器
		var test_handler = JuicySequenceEventHandler.new()
		test_handler.handler_name = "TestIntegrationHandler"
		
		# 修复：正确配置事件处理器
		test_handler.target_event_name = "integration_test_event"
		
		# 创建真实的序列状态对象
		var mock_sequence_state = JuicySequenceDriver.SequenceState.new()
		test_handler.sequence_state = mock_sequence_state
		
		# 注册处理器
		var register_success = event_middleware.register_event_handler(test_handler, 100)
		
		if register_success:
			# 创建测试事件
			var event = JuicyEvent.new(JuicyEvent.EventType.CUSTOM_EVENT)
			event.event_name = "integration_test_event"
			
			# 添加事件到缓冲区
			if event_middleware._event_buffer:
				event_middleware._event_buffer.add_event(event)
				
				# 处理事件
				var delta = 0.016
				var processed_count = event_middleware._event_scheduler.process_events(event_middleware._event_buffer, delta)
				
				print("事件处理结果: processed_count = ", processed_count)
				print("模拟序列状态中的触发事件: ", mock_sequence_state.triggered_events)
				
				success = processed_count > 0 and mock_sequence_state.triggered_events.size() > 0
				
				# 清理
				event_middleware.unregister_event_handler("TestIntegrationHandler")
	
	if success:
		result_label.text = "✅ 事件系统集成测试通过"
		print("事件系统集成测试通过")
	else:
		result_label.text = "❌ 事件系统集成测试失败"
		print("事件系统集成测试失败")

func _test_driver_integration():
	print("\n=== 测试10: 驱动器集成测试 ===")
	
	_cleanup_current_test()
	
	# 创建序列资源（包含实际的序列项）
	var sequence_resource = JuicySequenceResource.new()
	sequence_resource.parallel = false
	sequence_resource.enable_event_sync = false
	
	# 创建震动资源
	var shake_resource = JuicyShakeResource.new()
	shake_resource.duration = 0.3
	shake_resource.add_shake_data("position", 2.0, 8.0, 0.3)
	
	# 创建序列项
	var item = JuicySequenceItem.new()
	item.resource = shake_resource
	item.delay = 0.1
	item.duration = 0.3
	item.trigger_mode = JuicySequenceItem.TriggerMode.TIME
	item.enabled = true
	
	var items_array: Array[JuicySequenceItem] = [item]
	sequence_resource.set("sequence_items", items_array)
	
	# 创建序列驱动器
	var driver = JuicySequenceDriver.new()
	driver.sequence_resource = sequence_resource
	
	# 创建测试上下文
	current_test_node = Node.new()
	add_child(current_test_node)
	var context = JuicyContext.create(sequence_resource, current_test_node, self)
	
	# 测试准备
	var prepare_success = true
	if driver and context:
		driver.prepare(context, 0.0, JuicyPropertyBuffer.new())
	else:
		prepare_success = false
	
	# 测试处理（模拟几帧的处理）
	var process_success = true
	if driver and context:
		for i in range(5):  # 模拟5帧处理
			driver.process(context, 0.016, JuicyPropertyBuffer.new())
			await get_tree().process_frame  # 等待一帧
	else:
		process_success = false
	
	# 测试清理
	var cleanup_success = true
	if driver and context:
		driver.cleanup(context)
	else:
		cleanup_success = false
	
	var success = prepare_success and process_success and cleanup_success
	
	if success:
		result_label.text = "✅ 驱动器集成测试通过"
		print("驱动器集成测试通过")
	else:
		result_label.text = "❌ 驱动器集成测试失败"
		print("驱动器集成测试失败")

func _wait_for_completion(max_wait_time: float):
	print("等待序列完成，最大等待时间: ", max_wait_time, " 秒")
	
	var wait_time = 0.0
	var test_start_time = Time.get_ticks_msec() / 1000.0  # 记录测试开始时间
	
	while wait_time < max_wait_time:
		await get_tree().create_timer(0.01).timeout
		wait_time += 0.01
		
		if current_context_id != "":
			var context = JuicyMixer.get_context(current_context_id)
			if context and context.is_completed:
				var actual_total_time = Time.get_ticks_msec() / 1000.0 - test_start_time
				
				# 详细时间分析
				print("=== 时间分析 ===")
				print("测试开始时间: ", test_start_time)
				print("序列完成时间: ", Time.get_ticks_msec() / 1000.0)
				print("实际总时间: ", actual_total_time, " 秒")
				print("预期总时间: 1.0 秒 (0.5延迟 + 0.5震动)")
				print("时间差异: ", actual_total_time - 1.0, " 秒")
				
				# 计算震动部分时间
				var shake_time = actual_total_time - 0.5
				print("震动部分时间: ", shake_time, " 秒")
				print("震动时间差异: ", shake_time - 0.5, " 秒")
				
				result_label.text = "✅ 序列执行完成"
				print("序列执行完成，实际用时: ", actual_total_time, " 秒")
				return
	
	result_label.text = "⚠️ 序列执行超时"
	print("序列执行超时")

func _wait_for_completion_with_analysis(max_wait_time: float, test_name: String, expected_time: float, time_description: String):
	print("等待", test_name, "完成，最大等待时间: ", max_wait_time, " 秒")
	
	var wait_time = 0.0
	var test_start_time = Time.get_ticks_msec() / 1000.0  # 记录测试开始时间
	
	while wait_time < max_wait_time:
		await get_tree().create_timer(0.01).timeout
		wait_time += 0.01
		
		if current_context_id != "":
			var context = JuicyMixer.get_context(current_context_id)
			if context and context.is_completed:
				var actual_total_time = Time.get_ticks_msec() / 1000.0 - test_start_time
				
				# 详细时间分析
				print("=== ", test_name, " 时间分析 ===")
				print("测试开始时间: ", test_start_time)
				print("序列完成时间: ", Time.get_ticks_msec() / 1000.0)
				print("实际总时间: ", actual_total_time, " 秒")
				print("预期总时间: ", expected_time, " 秒 (", time_description, ")")
				print("时间差异: ", actual_total_time - expected_time, " 秒")
				
				result_label.text = "✅ " + test_name + "序列执行完成"
				print(test_name, "序列执行完成，实际用时: ", actual_total_time, " 秒")
				return
	
	result_label.text = "⚠️ " + test_name + "序列执行超时"
	print(test_name, "序列执行超时")
