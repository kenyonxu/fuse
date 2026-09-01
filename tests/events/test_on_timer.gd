extends Node

## OnTimer 事件测试

func _ready():
	print("=== Testing OnTimer ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_repeat_triggering()
	test_manual_control()
	test_validation()
	test_edge_cases()
	print("=== All OnTimer tests passed! ===")

## 测试基本功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	var event = OnTimer.new()
	event.wait_time = 0.1
	event.repeat_count = 1
	event.autostart = true

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	var trigger_count = 0
	event.triggered.connect(func():
		triggered = true
		trigger_count += 1
		print("  Event triggered! (count: %d)" % trigger_count)
	)

	event.initialize(trigger)
	await get_tree().create_timer(0.3).timeout

	assert(triggered, "Event should trigger")
	assert(trigger_count == 1, "Event should trigger exactly once")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试重复触发
func test_repeat_triggering():
	print("Test 2: Repeat triggering")

	var event = OnTimer.new()
	event.wait_time = 0.05
	event.repeat_count = 3
	event.autostart = true

	var trigger = Node.new()
	add_child(trigger)

	var trigger_count = 0
	event.triggered.connect(func():
		trigger_count += 1
		print("  Event triggered! (count: %d)" % trigger_count)
	)

	event.initialize(trigger)
	await get_tree().create_timer(0.3).timeout

	assert(trigger_count == 3, "Event should trigger 3 times (actual: %d)" % trigger_count)
	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试手动控制
func test_manual_control():
	print("Test 3: Manual control")

	var event = OnTimer.new()
	event.wait_time = 0.1
	event.autostart = false  # 不自动开始

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	event.triggered.connect(func():
		triggered = true
		print("  Event triggered!")
	)

	event.initialize(trigger)

	# 手动启动定时器
	assert(not triggered, "Event should not trigger yet")
	event.start_timer()
	print("  Timer started manually")

	await get_tree().create_timer(0.2).timeout

	assert(triggered, "Event should trigger after manual start")
	print("  ✓ Test 3 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试参数验证
func test_validation():
	print("Test 4: Parameter validation")

	var event = OnTimer.new()

	# 测试无效的 wait_time
	event.wait_time = -1.0
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for negative wait_time")
	print("  ✓ Negative wait_time validation passed")

	# 测试无效的 repeat_count
	event.wait_time = 1.0
	event.repeat_count = -1
	errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for negative repeat_count")
	print("  ✓ Negative repeat_count validation passed")

	# 测试有效配置
	event.wait_time = 1.0
	event.repeat_count = 5
	errors = event.validate()
	assert(errors.is_empty(), "Valid configuration should pass validation")
	print("  ✓ Valid configuration passed")

	print("  ✓ Test 4 passed\n")

## 测试边界条件
func test_edge_cases():
	print("Test 5: Edge cases")

	# 测试零值 wait_time
	var event = OnTimer.new()
	event.wait_time = 0.0
	event.repeat_count = 1

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	event.triggered.connect(func():
		triggered = true
		print("  Event triggered immediately!")
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 注意：零值应该被 validate() 拦截，所以这里应该不会触发
	assert(not triggered, "Event with zero wait_time should not trigger (validation error)")
	print("  ✓ Zero wait_time edge case passed\n")

	event.terminate(trigger)
	trigger.queue_free()
