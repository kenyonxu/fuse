extends Node

## OnRealtime 事件测试

func _ready():
	print("=== Testing OnRealtime ===")
	await test_basic_triggering()
	await test_max_triggers_limit()
	await test_timestamp_emission()
	await test_unaffected_by_timescale()
	await test_reset_functionality()
	await test_termination()
	cleanup()
	print("=== All OnRealtime tests passed! ===")

func test_basic_triggering():
	print("Test 1: Basic triggering")

	var event_script = load("res://addons/fuse/events/timing/on_realtime.gd")
	var event = event_script.new()
	event.interval_seconds = 0.1
	event.max_triggers = 0  # 无限触发

	var trigger = Node.new()
	add_child(trigger)

	var trigger_count = 0
	event.triggered.connect(func(_context):
		trigger_count += 1
	)

	# 初始化事件
	event.initialize(trigger)
	await get_tree().process_frame
	await get_tree().process_frame

	# 等待第一次触发
	await get_tree().create_timer(0.15).timeout
	assert(trigger_count >= 1, "Event should trigger at least once")
	print("  ✓ Test 1 passed: Basic triggering works\n")

	# 清理
	event.terminate(trigger)
	trigger.queue_free()

func test_max_triggers_limit():
	print("Test 2: Max triggers limit")

	var event_script = load("res://addons/fuse/events/timing/on_realtime.gd")
	var event = event_script.new()
	event.interval_seconds = 0.05
	event.max_triggers = 3  # 最多触发 3 次

	var trigger = Node.new()
	add_child(trigger)

	var trigger_count = 0
	event.triggered.connect(func(_context):
		trigger_count += 1
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 等待所有触发完成
	await get_tree().create_timer(0.3).timeout
	assert(trigger_count == 3, "Event should trigger exactly 3 times, got %d" % trigger_count)
	print("  ✓ Test 2 passed: Max triggers limit works\n")

	event.terminate(trigger)
	trigger.queue_free()

func test_timestamp_emission():
	print("Test 3: Timestamp emission")

	var event_script = load("res://addons/fuse/events/timing/on_realtime.gd")
	var event = event_script.new()
	event.interval_seconds = 0.1
	event.emit_timestamp = true

	var trigger = Node.new()
	add_child(trigger)

	var received_context = null
	event.triggered.connect(func(context):
		received_context = context
	)

	event.initialize(trigger)
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout

	assert(received_context != null, "Context should be emitted")
	assert(typeof(received_context) == TYPE_DICTIONARY, "Context should be a dictionary")
	assert(received_context.has("timestamp"), "Context should contain timestamp")
	assert(received_context.has("node"), "Context should contain node")
	print("  ✓ Test 3 passed: Timestamp emission works\n")

	event.terminate(trigger)
	trigger.queue_free()

func test_unaffected_by_timescale():
	print("Test 4: Unaffected by time_scale")

	var event_script = load("res://addons/fuse/events/timing/on_realtime.gd")
	var event = event_script.new()
	event.interval_seconds = 0.1

	var trigger = Node.new()
	add_child(trigger)

	var trigger_count = 0
	event.triggered.connect(func(_context):
		trigger_count += 1
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 设置 time_scale = 0（暂停游戏时间）
	Engine.time_scale = 0.0

	# 等待超过触发间隔的时间
	await get_tree().create_timer(0.15).timeout

	# 恢复 time_scale
	Engine.time_scale = 1.0

	# 由于使用 process_always，即使 time_scale=0 也应该触发
	assert(trigger_count >= 1, "Event should trigger even with time_scale=0")
	print("  ✓ Test 4 passed: Unaffected by time_scale\n")

	event.terminate(trigger)
	trigger.queue_free()

func test_reset_functionality():
	print("Test 5: Reset functionality")

	var event_script = load("res://addons/fuse/events/timing/on_realtime.gd")
	var event = event_script.new()
	event.interval_seconds = 0.1
	event.max_triggers = 2

	var trigger = Node.new()
	add_child(trigger)

	var trigger_count = 0
	event.triggered.connect(func(_context):
		trigger_count += 1
	)

	event.initialize(trigger)
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout

	var first_count = trigger_count
	assert(first_count == 2, "Should trigger 2 times before reset")

	# 重置事件
	event.reset()
	await get_tree().create_timer(0.05).timeout  # 等待重置生效
	await get_tree().create_timer(0.2).timeout

	var second_count = trigger_count
	assert(second_count == 4, "Should trigger another 2 times after reset, got %d" % second_count)
	print("  ✓ Test 5 passed: Reset functionality works\n")

	event.terminate(trigger)
	trigger.queue_free()

func test_termination():
	print("Test 6: Termination and cleanup")

	var event_script = load("res://addons/fuse/events/timing/on_realtime.gd")
	var event = event_script.new()
	event.interval_seconds = 0.1

	var trigger = Node.new()
	add_child(trigger)

	event.initialize(trigger)
	await get_tree().process_frame

	var timer = event._timer

	# 验证 Timer 已创建
	assert(timer != null, "Timer should be created")
	assert(timer.get_parent() == trigger, "Timer should be child of trigger")

	# 终止事件
	event.terminate(trigger)
	await get_tree().process_frame

	# 验证 Timer 已清理
	assert(event._timer == null, "Timer reference should be null")
	assert(not is_instance_valid(timer), "Timer should be queued for deletion")
	print("  ✓ Test 6 passed: Termination works\n")

	trigger.queue_free()

func cleanup():
	# 确保 time_scale 恢复正常
	Engine.time_scale = 1.0
