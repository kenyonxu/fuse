# 测试启用了事件系统的JuicyContext事件API功能
# 用于验证事件系统在启用状态下的完整功能

extends Node

func _ready():
	print("=== JuicyContext事件API（启用状态）测试开始 ===")
	
	# 首先注册事件处理中间件以启用事件系统
	_register_event_middleware()
	
	# 等待一帧确保中间件注册完成
	await get_tree().process_frame
	
	# 运行测试
	test_event_system_enabled()
	test_event_context_binding()
	test_event_lifecycle_with_context()
	
	print("=== JuicyContext事件API（启用状态）测试完成 ===")

func _register_event_middleware():
	print("注册事件处理中间件...")
	var middleware = EventHandlingMiddleware.new()
	var result = JuicyMixer.add_middleware(middleware)
	print("事件处理中间件注册结果: ", result)

func test_event_system_enabled():
	print("\n--- 测试：事件系统启用状态 ---")
	
	var context = JuicyContext.create(null, self)
	
	# 检查事件系统可用性
	var is_available = context._is_event_system_available()
	print("事件系统可用性: ", is_available)
	
	# 创建事件
	var event = JuicyEvent.new()
	event.event_type = JuicyEvent.EventType.AUDIO_PLAY
	event.target = self
	event.event_data = {"sound_name": "test_sound", "volume": 0.8}
	
	# 添加事件
	var add_result = context.add_event(event)
	print("添加事件结果: ", add_result)
	
	# 获取事件
	var events = context.get_events()
	print("获取事件数量: ", events.size())
	
	# 验证事件内容
	if events.size() > 0:
		var retrieved_event = events[0]
		print("检索到的事件类型: ", retrieved_event.event_type)
		print("事件目标: ", retrieved_event.target)
		print("事件数据: ", retrieved_event.event_data)

func test_event_context_binding():
	print("\n--- 测试：事件与Context绑定 ---")
	
	var context = JuicyContext.create(null, self)
	var context_id = context.get_context_id()
	
	# 创建多个事件
	for i in range(3):
		var event = JuicyEvent.new()
		event.event_type = JuicyEvent.EventType.PARTICLE_SPAWN
		event.target = self
		event.event_data = {"particle_count": i + 1, "color": Color(randf(), randf(), randf())}
		
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
		var event = JuicyEvent.new()
		event.event_type = JuicyEvent.EventType.UI_UPDATE
		event.target = self
		context.add_event(event)
	
	print("重置前事件数量: ", context.get_events().size())
	
	# 重置Context
	context.reset()
	
	print("重置后事件数量: ", context.get_events().size())
	
	# 验证事件被清理
	var events_after_reset = context.get_events()
	assert(events_after_reset.size() == 0, "重置后事件应该被清理")
	
	# 重置后尝试添加新事件
	var new_event = JuicyEvent.new()
	new_event.event_type = JuicyEvent.EventType.SCREEN_SHAKE
	var add_after_reset = context.add_event(new_event)
	print("重置后添加事件结果: ", add_after_reset)
	print("重置后新事件数量: ", context.get_events().size())

func _exit_tree():
	print("启用状态测试脚本清理完成")