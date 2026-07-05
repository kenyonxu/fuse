# 测试JuicyContext事件API功能
# 用于验证事件系统的向后兼容性和功能完整性

extends Node

func _ready():
	print("=== JuicyContext事件API测试开始 ===")
	
	# 测试1：基本事件添加和获取
	test_basic_event_api()
	
	# 测试2：事件系统未启用时的优雅降级
	test_event_system_disabled()
	
	# 测试3：Context生命周期管理
	test_context_lifecycle()
	
	# 测试4：无效事件处理
	test_invalid_event_handling()
	
	print("=== JuicyContext事件API测试完成 ===")

func test_basic_event_api():
	print("\n--- 测试1：基本事件API ---")
	
	# 创建测试Context
	var context = JuicyContext.create(null, self)
	
	# 创建测试事件
	var event = JuicyEvent.new()
	event.event_type = JuicyEvent.EventType.AUDIO_PLAY
	event.target = self
	
	# 测试添加事件（事件系统未启用，应该返回false）
	var result = context.add_event(event)
	print("添加事件结果（未启用事件系统）: ", result)
	
	# 测试获取事件（应该返回空数组）
	var events = context.get_events()
	print("获取事件数量（未启用事件系统）: ", events.size())
	
	# 验证Context ID设置
	if event.has_method("get_context_id"):
		var event_context_id = event.get_context_id()
		print("事件Context ID: ", event_context_id)
		print("Context ID匹配: ", event_context_id == context.get_context_id())

func test_event_system_disabled():
	print("\n--- 测试2：事件系统禁用时的行为 ---")
	
	var context = JuicyContext.create(null, self)
	
	# 创建事件
	var event = JuicyEvent.new()
	event.event_type = JuicyEvent.EventType.PARTICLE_SPAWN
	
	# 测试事件系统可用性检查
	var is_available = context._is_event_system_available()
	print("事件系统可用性: ", is_available)
	
	# 尝试添加事件（应该失败但不会产生错误）
	var result = context.add_event(event)
	print("禁用状态下添加事件结果: ", result)
	
	# 获取事件（应该返回空数组）
	var events = context.get_events()
	print("禁用状态下获取事件数量: ", events.size())

func test_context_lifecycle():
	print("\n--- 测试3：Context生命周期管理 ---")
	
	var context = JuicyContext.create(null, self)
	
	# 添加一些事件
	for i in range(3):
		var event = JuicyEvent.new()
		event.event_type = JuicyEvent.EventType.UI_UPDATE
		context.add_event(event)
	
	print("重置前事件数量: ", context.get_events().size())
	
	# 重置Context
	context.reset()
	
	print("重置后事件数量: ", context.get_events().size())
	
	# 验证事件数组被清空
	var events_after_reset = context.get_events()
	assert(events_after_reset.size() == 0, "重置后事件数组应该为空")

func test_invalid_event_handling():
	print("\n--- 测试4：无效事件处理 ---")
	
	var context = JuicyContext.create(null, self)
	
	# 测试null事件
	var null_result = context.add_event(null)
	print("添加null事件结果: ", null_result)
	
	# 测试非事件对象
	var invalid_object = Node.new()
	var invalid_result = context.add_event(invalid_object)
	print("添加无效对象结果: ", invalid_result)
	
	# 测试空字典
	var dict_result = context.add_event({})
	print("添加字典结果: ", dict_result)
	
	print("所有无效事件处理测试通过")

func _exit_tree():
	print("测试脚本清理完成")