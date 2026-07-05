# 测试修复后的JuicyEvent和JuicyContext事件API

extends Node

func _ready():
	print("=== 修复后的JuicyEvent测试开始 ===")
	
	# 首先注册事件处理中间件以启用事件系统
	_register_event_middleware()
	
	# 等待一帧确保中间件注册完成
	await get_tree().process_frame
	
	# 运行测试
	test_juicy_event_creation()
	test_context_event_binding()
	test_event_lifecycle_with_context()
	
	print("=== 修复后的JuicyEvent测试完成 ===")

func _register_event_middleware():
	print("注册事件处理中间件...")
	var middleware = EventHandlingMiddleware.new()
	var result = JuicyMixer.add_middleware(middleware)
	print("事件处理中间件注册结果: ", result)

func test_juicy_event_creation():
	print("\n--- 测试：JuicyEvent创建 ---")
	
	# 创建JuicyEvent
	var event = JuicyEvent.create_audio_play_event("Test", self, null, Vector2(100, 100), 0.8)
	print("事件创建: ", event != null)
	print("事件类型: ", event.get_class() if event.has_method("get_class") else "无get_class方法")
	print("事件字符串表示: ", str(event))
	
	# 测试Context创建
	var context = JuicyContext.create(null, self)
	print("Context创建: ", context != null)
	
	# 检查事件系统可用性
	var is_available = context._is_event_system_available()
	print("事件系统可用性: ", is_available)
	
	# 尝试添加事件
	var add_result = context.add_event(event)
	print("添加事件结果: ", add_result)
	
	if add_result:
		var events = context.get_events()
		print("Context中的事件数量: ", events.size())
		if events.size() > 0:
			var retrieved_event = events[0]
			print("检索到的事件类型: ", retrieved_event.event_type)
			print("事件目标: ", retrieved_event.target)
			print("事件数据: ", retrieved_event.event_data)

func test_context_event_binding():
	print("\n--- 测试：事件与Context绑定 ---")
	
	var context = JuicyContext.create(null, self)
	var context_id = context.get_context_id()
	
	# 创建多个事件
	for i in range(3):
		var event = JuicyEvent.create_particle_spawn_event("Test", self, null, i + 1, Vector2(i * 50, i * 50))
		var add_result = context.add_event(event)
		print("事件 ", i, " 添加结果: ", add_result)
	
	# 验证所有事件都绑定了正确的Context ID
	var events = context.get_events()
	print("总事件数量: ", events.size())
	
	for i in range(events.size()):
		var event = events[i]
		if event.has_method("get_context_id"):
			var event_context_id = event.get_context_id()
			print("事件 ", i, " 的Context ID: ", event_context_id)
			print("Context ID匹配: ", event_context_id == context_id)

func test_event_lifecycle_with_context():
	print("\n--- 测试：事件与Context生命周期 ---")
	
	var context = JuicyContext.create(null, self)
	
	# 添加事件
	for i in range(2):
		var event = JuicyEvent.create_ui_update_event("Test", self, "test_property", i)
		context.add_event(event)
	
	print("重置前事件数量: ", context.get_events().size())
	
	# 重置Context
	context.reset()
	
	print("重置后事件数量: ", context.get_events().size())
	
	# 验证事件被清理
	var events_after_reset = context.get_events()
	assert(events_after_reset.size() == 0, "重置后事件应该被清理")
	
	# 重置后尝试添加新事件
	var new_event = JuicyEvent.create_screen_shake_event("Test", self, 2.0, 1.0)
	var add_after_reset = context.add_event(new_event)
	print("重置后添加事件结果: ", add_after_reset)
	print("重置后新事件数量: ", context.get_events().size())

func _exit_tree():
	print("修复后测试脚本清理完成")