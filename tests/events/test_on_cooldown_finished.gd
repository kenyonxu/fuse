extends Node

## OnCooldownFinished 事件测试

func _ready():
	print("=== Testing OnCooldownFinished ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_progress_updates()
	test_manual_trigger()
	test_pause_resume()
	test_validation()
	test_edge_cases()
	print("=== All OnCooldownFinished tests passed! ===")

## 测试基本功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	var event = OnCooldownFinished.new()
	event.cooldown_seconds = 0.2
	event.manual_trigger = false
	event.show_progress = false

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

	var event = OnCooldownFinished.new()
	event.cooldown_seconds = 0.3
	event.manual_trigger = false
	event.show_progress = true
	event.progress_update_interval = 0.1

	var trigger = Node.new()
	add_child(trigger)

	var progress_count = 0
	var final_progress = 0.0
	var completed_triggered = false

	event.triggered.connect(func(context):
		var is_completed = context.get_meta("is_completed")
		if is_completed:
			completed_triggered = true
			final_progress = context.get_meta("cooldown_progress")
			print("  Final event: completed=True, progress=%.2f" % final_progress)
		else:
			progress_count += 1
			var progress = context.get_meta("cooldown_progress")
			var remaining = context.get_meta("remaining_time")
			print("  Progress event #%d: progress=%.2f, remaining=%.2f" % [progress_count, progress, remaining])

		assert(context.has_meta("cooldown_progress"), "Should have cooldown_progress")
		assert(context.has_meta("remaining_time"), "Should have remaining_time")
		assert(context.has_meta("total_duration"), "Should have total_duration")
		assert(context.has_meta("is_completed"), "Should have is_completed")
	)

	event.initialize(trigger)
	await get_tree().create_timer(0.5).timeout

	assert(progress_count > 0, "Should receive progress updates")
	assert(completed_triggered, "Should receive final completion event")
	assert(is_equal_approx(final_progress, 1.0), "Final progress should be 1.0")
	print("  Received %d progress updates" % progress_count)
	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试手动触发
func test_manual_trigger():
	print("Test 3: Manual trigger")

	var event = OnCooldownFinished.new()
	event.cooldown_seconds = 0.2
	event.manual_trigger = true

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

	# 手动启动冷却
	event.start_cooldown()
	print("  Started cooldown manually")

	await get_tree().create_timer(0.3).timeout
	assert(triggered, "Event should trigger after manual start")
	assert(event.is_completed(), "Event should be completed")
	print("  ✓ Test 3 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试暂停/恢复
func test_pause_resume():
	print("Test 4: Pause/Resume")

	var event = OnCooldownFinished.new()
	event.cooldown_seconds = 0.3
	event.manual_trigger = false
	event.show_progress = true

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
	event.pause_cooldown()
	print("  Paused at %.2f seconds" % event.get_remaining_time())

	var remaining_at_pause = event.get_remaining_time()
	var progress_at_pause = event.get_progress()

	assert(remaining_at_pause > 0, "Should have remaining time")
	assert(progress_at_pause > 0 and progress_at_pause < 1.0, "Progress should be between 0 and 1")
	assert(not event.is_running(), "Should not be running")
	assert(not event.is_completed(), "Should not be completed")

	# 恢复并等待完成
	event.resume_cooldown()
	print("  Resumed cooldown")

	await get_tree().create_timer(0.3).timeout
	assert(event.is_completed(), "Event should be completed after resume")
	assert(is_equal_approx(event.get_progress(), 1.0), "Final progress should be 1.0")
	print("  ✓ Test 4 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试参数验证
func test_validation():
	print("Test 5: Parameter validation")

	var event = OnCooldownFinished.new()

	# 测试无效的 cooldown_seconds
	event.cooldown_seconds = -1.0
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for negative cooldown_seconds")
	print("  ✓ Negative cooldown_seconds validation passed")

	# 测试无效的 progress_update_interval
	event.cooldown_seconds = 1.0
	event.show_progress = true
	event.progress_update_interval = 0.0
	errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for zero progress_update_interval")
	print("  ✓ Zero progress_update_interval validation passed")

	# 测试有效配置
	event.cooldown_seconds = 5.0
	event.progress_update_interval = 0.1
	errors = event.validate()
	assert(errors.is_empty(), "Valid configuration should pass validation")
	print("  ✓ Valid configuration passed")

	print("  ✓ Test 5 passed\n")

## 测试边界条件
func test_edge_cases():
	print("Test 6: Edge cases")

	# 测试快速重置
	var event = OnCooldownFinished.new()
	event.cooldown_seconds = 0.2
	event.manual_trigger = false

	var trigger = Node.new()
	add_child(trigger)

	var trigger_count = 0
	event.triggered.connect(func(context):
		trigger_count += 1
	)

	event.initialize(trigger)

	# 在完成前重置
	await get_tree().create_timer(0.1).timeout
	event.reset_cooldown()
	print("  Reset cooldown before completion")

	await get_tree().create_timer(0.3).timeout
	# 应该只触发一次（重置后）
	assert(trigger_count == 1, "Should trigger only once after reset")
	print("  ✓ Reset functionality works")

	# 测试重置方法
	event.reset_cooldown()
	assert(not event.is_completed(), "Should not be completed after reset")
	assert(event.get_remaining_time() > 0, "Should have remaining time after reset")
	assert(is_equal_approx(event.get_progress(), 0.0), "Progress should be 0 after reset")
	print("  ✓ Reset state is correct")

	print("  ✓ Test 6 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试进度计算
func test_progress_calculation():
	print("Test 7: Progress calculation")

	var event = OnCooldownFinished.new()
	event.cooldown_seconds = 1.0
	event.manual_trigger = false
	event.show_progress = true

	var trigger = Node.new()
	add_child(trigger)

	var progress_samples = []

	event.triggered.connect(func(context):
		if not context.get_meta("is_completed"):
			var progress = context.get_meta("cooldown_progress")
			progress_samples.append(progress)

	)

	event.initialize(trigger)

	# 收集多个进度样本
	await get_tree().create_timer(0.6).timeout

	# 验证进度是递增的
	for i in range(1, progress_samples.size()):
		assert(progress_samples[i] > progress_samples[i-1], "Progress should be increasing")
		assert(progress_samples[i] >= 0.0 and progress_samples[i] <= 1.0, "Progress should be between 0 and 1")

	print("  Collected %d progress samples" % progress_samples.size())
	assert(progress_samples.size() > 0, "Should have progress samples")
	print("  ✓ Test 7 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 辅助函数：比较浮点数
func is_equal_approx(a: float, b: float, epsilon: float = 0.001) -> bool:
	return abs(a - b) < epsilon
