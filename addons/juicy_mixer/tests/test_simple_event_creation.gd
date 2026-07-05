# 简单的事件创建和验证测试

extends Node

func _ready():
	print("=== 简单事件创建测试 ===")
	
	# 创建事件
	var event = JuicyEvent.new()
	print("事件对象创建: ", event != null)
	print("事件类型: ", event.get_class() if event.has_method("get_class") else "无get_class方法")
	print("事件字符串表示: ", str(event))
	
	# 检查事件属性
	event.event_type = JuicyEvent.EventType.AUDIO_PLAY
	event.target = self
	event.event_data = {"test": "data"}
	
	print("事件类型设置: ", event.event_type)
	print("事件目标设置: ", event.target)
	print("事件数据设置: ", event.event_data)
	
	# 测试Context创建
	var context = JuicyContext.create(null, self)
	print("Context创建: ", context != null)
	
	# 注册事件处理中间件
	var middleware = EventHandlingMiddleware.new()
	var result = JuicyMixer.add_middleware(middleware)
	print("中间件注册结果: ", result)
	
	# 检查事件系统可用性
	var is_available = context._is_event_system_available()
	print("事件系统可用性: ", is_available)
	
	# 尝试添加事件
	var add_result = context.add_event(event)
	print("添加事件结果: ", add_result)
	
	if add_result:
		var events = context.get_events()
		print("Context中的事件数量: ", events.size())
	
	print("=== 测试完成 ===")
