extends RefCounted

# 测试事件调度器功能
class TestEventHandler:
	extends JuicyEventHandler
	
	func _init():
		handler_name = "TestHandler"
		supported_events = [JuicyEvent.EventType.AUDIO_PLAY, JuicyEvent.EventType.UI_UPDATE]
		enabled = true
	
	func handle_event(event) -> bool:
		print("TestHandler processing event: ", event.event_type)
		_record_success()
		return true

func test_event_scheduler():
	print("=== Testing JuicyEventScheduler ===")
	
	# 创建事件调度器
	var scheduler = JuicyEventScheduler.new()
	var buffer = JuicyEventBuffer.new()
	
	# 注册测试处理器
	var handler = TestEventHandler.new()
	var registered = scheduler.register_handler(handler, 100)
	print("Handler registered: ", registered)
	
	# 创建测试事件
	var event = JuicyEvent.new()
	event.event_type = JuicyEvent.EventType.AUDIO_PLAY
	event.context_id = "test_context"
	event.target = null
	event.priority = 10
	
	# 添加事件到缓冲区
	var added = buffer.add_event(event)
	print("Event added to buffer: ", added)
	
	# 处理事件
	var processed = scheduler.process_events(buffer, 0.016)
	print("Events processed: ", processed)
	
	# 获取统计信息
	var stats = scheduler.get_scheduler_stats()
	print("Scheduler stats: ", stats)
	
	# 调试打印处理器
	scheduler.debug_print_handlers()
	
	print("=== Test completed ===")

# 运行测试
func _ready():
	test_event_scheduler()