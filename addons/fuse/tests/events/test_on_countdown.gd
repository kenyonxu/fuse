extends Node

## OnCountdown 事件测试

func _ready():
	print("=== Testing OnCountdown ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_progress_updates()
	test_manual_control()
	test_pause_resume()
	test_validation()
	test_edge_cases()
	print("=== All OnCountdown tests passed! ===")

## 测试基本功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	var event = OnCountdown.new()
	event.countdown_seconds = 0.2
	event.auto_start = true
	event.show_remaining_time = false

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	var is_completed = false
	event.triggered.connect(func(context):
		triggered = true
		is_completed = context.get_meta("is_completed")
		print("  Event triggered! (completed: %s)" % is_completed)
	)

	event.initialize(trigger)
	await get_tree().create_timer(0.4).timeout

	assert(triggered, "Event should trigger")
	assert(is_completed, "Event should be completed")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试进度更新
func test_progress_updates():
	print("Test 2: Progress updates")

	var event = OnCountdown.new()
	event.countdown_seconds = 0.3
	event.auto_start = true
	event.show_remaining_time = true
	event.update_interval = 0.1

	var trigger = Node.new()
	add_child(trigger)

	var progress_count = 0
	var last_remaining = 0.0
	var completed_triggered = false

	event.triggered.connect(func(context):
		var is_completed = context.get_meta("is_completed")
		if is_completed:
			completed_triggered = true
			print("  Final event: completed=True")
		else:
			progress_count += 1
			last_remaining = context.get_meta("remaining_time")
			print("  Progress event #%d: remaining=%.2f" % [progress_count, last_remaining])

		assert(context.has_meta("remaining_time"), "Should have remaining_time")
		assert(context.has_meta("total_duration"), "Should have total_duration")
		assert(context.has_meta("is_completed"), "Should have is_completed")
	)

	event.initialize(trigger)
	await get_tree().create_timer(0.5).timeout

	assert(progress_count > 0, "Should receive progress updates")
	assert(completed_triggered, "Should receive final completion event")
	print("  Received %d progress updates" % progress_count)
	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试手动控制
func test_manual_control():
	print("Test 3: Manual control")

	var event = OnCountdown.new()
	event.countdown_seconds = 0.2
	event.auto_start = false

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	event.triggered.connect(func(context):
		triggered = true
		print("  Event triggered!")
	)

	event.initialize(trigger)

	# 不应该自动触发
	await get_tree().create_timer(0.1).timeout
	assert(not triggered, "Event should not trigger automatically")

	# 手动启动
	event.start_countdown()
	print("  Started countdown manually")

	await get_tree().create_timer(0.3).timeout
	assert(triggered, "Event should trigger after manual start")
	assert(event.is_completed(), "Event should be completed")
	print("  ✓ Test 3 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试暂停/恢复
func test_pause_resume():
	print("Test 4: Pause/Resume")

	var event = OnCountdown.new()
	event.countdown_seconds = 0.3
	event.auto_start = true
	event.show_remaining_time = true

	var trigger = Node.new()
	add_child(trigger)

	var progress_count = 0
	event.triggered.connect(func(context):
		if not context.get_meta("is_completed"):
			progress_count += 1
	)

	event.initialize(trigger)

	# 等待一段时间后暂停
	await get_tree().create_timer(0.15).timeout
	event.pause_countdown()
	print("  Paused at %.2f seconds" % event.get_remaining_time())

	var remaining_at_pause = event.get_remaining_time()
	assert(remaining_at_pause > 0, "Should have remaining time")
	assert(not event.is_running(), "Should not be running")
	assert(not event.is_completed(), "Should not be completed")

	# 恢复并等待完成
	event.resume_countdown()
	print("  Resumed countdown")

	await get_tree().create_timer(0.3).timeout
	assert(event.is_completed(), "Event should be completed after resume")
	print("  ✓ Test 4 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试参数验证
func test_validation():
	print("Test 5: Parameter validation")

	var event = OnCountdown.new()

	# 测试无效的 countdown_seconds
	event.countdown_seconds = -1.0
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for negative countdown_seconds")
	print("  ✓ Negative countdown_seconds validation passed")

	# 测试无效的 update_interval
	event.countdown_seconds = 1.0
	event.show_remaining_time = true
	event.update_interval = 0.0
	errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for zero update_interval")
	print("  ✓ Zero update_interval validation passed")

	# 测试有效配置
	event.countdown_seconds = 5.0
	event.update_interval = 0.1
	errors = event.validate()
	assert(errors.is_empty(), "Valid configuration should pass validation")
	print("  ✓ Valid configuration passed")

	print("  ✓ Test 5 passed\n")

## 测试边界条件
func test_edge_cases():
	print("Test 6: Edge cases")

	# 测试快速重置
	var event = OnCountdown.new()
	event.countdown_seconds = 0.2
	event.auto_start = true

	var trigger = Node.new()
	add_child(trigger)

	var trigger_count = 0
	event.triggered.connect(func(context):
		trigger_count += 1
	)

	event.initialize(trigger)

	# 在完成前重置
	await get_tree().create_timer(0.1).timeout
	event.reset_countdown()
	print("  Reset countdown before completion")

	await get_tree().create_timer(0.3).timeout
	# 应该只触发一次（重置后）
	assert(trigger_count == 1, "Should trigger only once after reset")
	print("  ✓ Reset functionality works")

	# 测试重置方法
	event.reset_countdown()
	assert(not event.is_completed(), "Should not be completed after reset")
	assert(event.get_remaining_time() > 0, "Should have remaining time after reset")
	print("  ✓ Reset state is correct")

	print("  ✓ Test 6 passed\n")

	event.terminate(trigger)
	trigger.queue_free()
