extends Node

# 测试事件调度器功能
class TestEventHandler:
	extends JuicyEventHandler
	
	var processed_events: Array = []
	
	func _init():
		handler_name = "TestHandler"
		supported_events = [JuicyEvent.EventType.AUDIO_PLAY, JuicyEvent.EventType.UI_UPDATE]
		enabled = true
	
	func handle_event(event) -> bool:
		print("TestHandler processing event: ", event.event_type)
		processed_events.append(event)
		_record_success()
		return true

# 测试不同的处理器优先级
class HighPriorityHandler:
	extends JuicyEventHandler
	
	func _init():
		handler_name = "HighPriorityHandler"
		supported_events = [JuicyEvent.EventType.AUDIO_PLAY]
		enabled = true
	
	func handle_event(event) -> bool:
		print("HighPriorityHandler processing event: ", event.event_type)
		_record_success()
		return true

class LowPriorityHandler:
	extends JuicyEventHandler
	
	func _init():
		handler_name = "LowPriorityHandler"
		supported_events = [JuicyEvent.EventType.AUDIO_PLAY]
		enabled = true
	
	func handle_event(event) -> bool:
		print("LowPriorityHandler processing event: ", event.event_type)
		_record_success()
		return true

# 测试事件调度器
func _ready():
	print("=== JuicyEventScheduler Test Runner ===")
	run_basic_test()
	run_priority_test()
	run_batch_test()
	run_performance_test()
	print("=== All tests completed ===")

func run_basic_test():
	print("\n--- Basic Test ---")
	
	# 创建事件调度器和缓冲区
	var scheduler = JuicyEventScheduler.new()
	var buffer = JuicyEventBuffer.new()
	
	# 注册测试处理器
	var handler = TestEventHandler.new()
	var registered = scheduler.register_handler(handler, 100)
	print("✓ Handler registered: ", registered)
	
	# 创建测试事件
	var event = JuicyEvent.new()
	event.event_type = JuicyEvent.EventType.AUDIO_PLAY
	event.context_id = "test_context"
	event.target = self
	event.priority = 10
	
	# 添加事件到缓冲区
	var added = buffer.add_event(event)
	print("✓ Event added to buffer: ", added)
	
	# 处理事件
	var processed = scheduler.process_events(buffer, 0.016)
	print("✓ Events processed: ", processed)
	
	# 验证处理器收到了事件
	print("✓ Handler processed events: ", handler.processed_events.size())
	
	# 获取统计信息
	var stats = scheduler.get_scheduler_stats()
	print("✓ Scheduler stats: ", stats)
	
	# 注销处理器
	var unregistered = scheduler.unregister_handler("TestHandler")
	print("✓ Handler unregistered: ", unregistered)

func run_priority_test():
	print("\n--- Priority Test ---")
	
	var scheduler = JuicyEventScheduler.new()
	var buffer = JuicyEventBuffer.new()
	
	# 注册不同优先级的处理器
	var high_priority = HighPriorityHandler.new()
	var low_priority = LowPriorityHandler.new()
	
	scheduler.register_handler(low_priority, 50)   # 低优先级
	scheduler.register_handler(high_priority, 100) # 高优先级
	
	# 创建测试事件
	var event = JuicyEvent.new()
	event.event_type = JuicyEvent.EventType.AUDIO_PLAY
	event.context_id = "priority_test"
	event.target = self
	event.priority = 10
	
	buffer.add_event(event)
	
	# 处理事件 - 应该按优先级顺序处理
	print("Processing event with multiple handlers...")
	var processed = scheduler.process_events(buffer, 0.016)
	print("✓ Events processed: ", processed)
	
	# 调试打印处理器信息
	scheduler.debug_print_handlers()

func run_batch_test():
	print("\n--- Batch Test ---")
	
	var scheduler = JuicyEventScheduler.new()
	var buffer = JuicyEventBuffer.new()
	
	# 注册处理器
	var handler = TestEventHandler.new()
	scheduler.register_handler(handler, 100)
	
	# 创建多个事件
	for i in range(10):
		var event = JuicyEvent.new()
		event.event_type = JuicyEvent.EventType.AUDIO_PLAY
		event.context_id = "batch_test_" + str(i)
		event.target = self
		event.priority = randi() % 100
		buffer.add_event(event)
	
	# 设置小批处理大小来测试批处理
	scheduler.set_batch_size(3)
	
	print("Processing multiple events in batches...")
	var total_processed = 0
	var iterations = 0
	
	# 模拟多帧处理
	while iterations < 5:
		var processed = scheduler.process_events(buffer, 0.016)
		total_processed += processed
		iterations += 1
		if processed == 0:
			break
	
	print("✓ Total events processed: ", total_processed)
	print("✓ Handler processed events: ", handler.processed_events.size())

func run_performance_test():
	print("\n--- Performance Test ---")
	
	var scheduler = JuicyEventScheduler.new()
	var buffer = JuicyEventBuffer.new()
	
	# 注册处理器
	var handler = TestEventHandler.new()
	scheduler.register_handler(handler, 100)
	
	# 创建大量事件
	var event_count = 100
	for i in range(event_count):
		var event = JuicyEvent.new()
		event.event_type = JuicyEvent.EventType.AUDIO_PLAY
		event.context_id = "perf_test_" + str(i)
		event.target = self
		event.priority = randi() % 100
		buffer.add_event(event)
	
	# 记录开始时间
	var start_time = Time.get_ticks_usec()
	
	# 处理所有事件
	var total_processed = 0
	while true:
		var processed = scheduler.process_events(buffer, 0.016)
		total_processed += processed
		if processed == 0:
			break
	
	var end_time = Time.get_ticks_usec()
	var total_time = (end_time - start_time) / 1000.0  # 转换为毫秒
	
	print("✓ Total events processed: ", total_processed)
	print("✓ Total processing time: ", total_time, " ms")
	print("✓ Average time per event: ", total_time / event_count, " ms")
	
	# 获取性能统计
	var stats = scheduler.get_scheduler_stats()
	print("✓ Final scheduler stats: ", stats)