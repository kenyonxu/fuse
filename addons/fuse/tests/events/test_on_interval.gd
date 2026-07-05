extends Node

## OnInterval 事件测试

func _ready():
	print("=== Testing OnInterval ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_repeat_limit()
	test_manual_control()
	test_pause_resume()
	test_validation()
	test_edge_cases()
	print("=== All OnInterval tests passed! ===")

## 测试基本功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	var event = OnInterval.new()
	event.interval_seconds = 0.1
	event.max_repeats = 3
	event.auto_start = true

	var trigger = Node.new()
	add_child(trigger)

	var trigger_count = 0
	event.triggered.connect(func(context):
		trigger_count += 1
		var count = context.get_meta("repeat_count")
		print("  Event triggered! (count: %d)" % count)
	)

	event.initialize(trigger)
	await get_tree().create_timer(0.5).timeout

	assert(trigger_count == 3, "Event should trigger 3 times (actual: %d)" % trigger_count)
	assert(event.is_completed(), "Event should be completed")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试重复次数限制
func test_repeat_limit():
	print("Test 2: Repeat limit")

	var event = OnInterval.new()
	event.interval_seconds = 0.05
	event.max_repeats = 5
	event.auto_start = true

	var trigger = Node.new()
	add_child(trigger)

	var trigger_count = 0
	event.triggered.connect(func(context):
		trigger_count += 1
		var count = context.get_meta("repeat_count")
		var is_completed = context.get_meta("is_completed")
		var is_last = context.get_meta("is_last_trigger")
		print("  Trigger #%d: completed=%s, last=%s" % [count, is_completed, is_last])
	)

	event.initialize(trigger)
	await get_tree().create_timer(0.5).timeout

	assert(trigger_count == 5, "Event should trigger exactly 5 times (actual: %d)" % trigger_count)
	assert(event.is_completed(), "Event should be completed")
	assert(not event.is_running(), "Event should not be running after completion")
	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试手动控制
func test_manual_control():
	print("Test 3: Manual control")

	var event = OnInterval.new()
	event.interval_seconds = 0.1
	event.max_repeats = 2
	event.auto_start = false

	var trigger = Node.new()
	add_child(trigger)

	var trigger_count = 0
	event.triggered.connect(func(context):
		trigger_count += 1
		print("  Event triggered! (count: %d)" % trigger_count)
	)

	event.initialize(trigger)

	# 不应该自动触发
	await get_tree().create_timer(0.15).timeout
	assert(trigger_count == 0, "Event should not trigger automatically")

	# 手动启动
	event.start_interval()
	print("  Started interval manually")

	await get_tree().create_timer(0.3).timeout
	assert(trigger_count == 2, "Event should trigger 2 times after manual start")
	assert(event.is_completed(), "Event should be completed")
	print("  ✓ Test 3 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试暂停/恢复
func test_pause_resume():
	print("Test 4: Pause/Resume")

	var event = OnInterval.new()
	event.interval_seconds = 0.1
	event.max_repeats = 10  # 设置足够高的重复次数
	event.auto_start = true

	var trigger = Node.new()
	add_child(trigger)

	var trigger_count = 0
	event.triggered.connect(func(context):
		trigger_count += 1
	)

	event.initialize(trigger)

	# 等待几次触发后暂停
	await get_tree().create_timer(0.25).timeout
	event.pause_interval()
	var count_at_pause = trigger_count
	print("  Paused after %d triggers" % count_at_pause)

	assert(count_at_pause > 0, "Should have triggered at least once")
	assert(not event.is_running(), "Should not be running")
	assert(not event.is_completed(), "Should not be completed")

	# 等待确认暂停有效
	await get_tree().create_timer(0.2).timeout
	assert(trigger_count == count_at_pause, "Count should not increase while paused")

	# 恢复并继续
	event.resume_interval()
	print("  Resumed interval")

	await get_tree().create_timer(0.3).timeout
	assert(trigger_count > count_at_pause, "Should trigger more after resume")
	print("  ✓ Test 4 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试参数验证
func test_validation():
	print("Test 5: Parameter validation")

	var event = OnInterval.new()

	# 测试无效的 interval_seconds
	event.interval_seconds = -1.0
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for negative interval_seconds")
	print("  ✓ Negative interval_seconds validation passed")

	# 测试无效的 max_repeats
	event.interval_seconds = 1.0
	event.max_repeats = -1
	errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for negative max_repeats")
	print("  ✓ Negative max_repeats validation passed")

	# 测试有效配置
	event.interval_seconds = 0.5
	event.max_repeats = 5
	errors = event.validate()
	assert(errors.is_empty(), "Valid configuration should pass validation")
	print("  ✓ Valid configuration passed")

	print("  ✓ Test 5 passed\n")

## 测试边界条件
func test_edge_cases():
	print("Test 6: Edge cases")

	# 测试无限重复模式（max_repeats = 0）
	var event = OnInterval.new()
	event.interval_seconds = 0.1
	event.max_repeats = 0  # 无限重复
	event.auto_start = true

	var trigger = Node.new()
	add_child(trigger)

	var trigger_count = 0
	event.triggered.connect(func(context):
		trigger_count += 1
	)

	event.initialize(trigger)

	# 等待几次触发
	await get_tree().create_timer(0.35).timeout
	assert(trigger_count >= 3, "Should trigger at least 3 times in 0.35s")
	assert(not event.is_completed(), "Should not be completed (infinite repeat)")
	assert(event.is_running(), "Should still be running")

	# 手动停止
	event.stop_interval()
	print("  Stopped after %d triggers" % trigger_count)

	assert(not event.is_running(), "Should not be running after stop")
	var count_after_stop = trigger_count

	# 等待确认停止有效
	await get_tree().create_timer(0.2).timeout
	assert(trigger_count == count_after_stop, "Count should not increase after stop")
	print("  ✓ Infinite repeat and stop works")

	print("  ✓ Test 6 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试重置功能
func test_reset():
	print("Test 7: Reset functionality")

	var event = OnInterval.new()
	event.interval_seconds = 0.1
	event.max_repeats = 3
	event.auto_start = true

	var trigger = Node.new()
	add_child(trigger)

	var trigger_count = 0
	event.triggered.connect(func(context):
		trigger_count += 1
	)

	event.initialize(trigger)

	# 等待一次触发
	await get_tree().create_timer(0.15).timeout
	assert(trigger_count > 0, "Should have triggered at least once")

	# 重置
	event.reset_interval()
	print("  Reset interval after %d triggers" % trigger_count)
	assert(not event.is_completed(), "Should not be completed after reset")
	assert(event.get_repeat_count() == 0, "Repeat count should be 0 after reset")

	# 等待完成
	await get_tree().create_timer(0.4).timeout
	assert(event.is_completed(), "Should be completed after reset")
	print("  ✓ Test 7 passed\n")

	event.terminate(trigger)
	trigger.queue_free()
