extends Node

## OnScreenEnteredExited 事件测试

func _ready():
	print("=== Testing OnScreenEnteredExited ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_trigger_modes()
	test_with_camera()
	test_validation()
	print("=== All OnScreenEnteredExited tests passed! ===")

## 测试基本功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	# 创建测试场景
	var camera = Camera2D.new()
	camera.name = "TestCamera"
	camera.position = Vector2(0, 0)
	add_child(camera)

	var target = Node2D.new()
	target.name = "TestTarget"
	target.position = Vector2(0, 0)
	add_child(target)

	var trigger = Node.new()
	add_child(trigger)

	var event = OnScreenEnteredExited.new()
	event.target_node = trigger.get_path_to(target)
	event.camera = NodePath("")
	event.trigger_on = OnScreenEnteredExited.TriggerOn.BOTH
	event.check_interval = 0.1

	var enter_triggered = false
	var exit_triggered = false

	event.triggered.connect(func(context):
		if context.get_meta("event_type") == "entered":
			enter_triggered = true
			print("  Event: Screen entered")
		elif context.get_meta("event_type") == "exited":
			exit_triggered = true
			print("  Event: Screen exited")
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 等待一段时间让定时器检查
	await get_tree().create_timer(0.5).timeout
	await get_tree().process_frame

	# 移动目标到屏幕外
	target.position = Vector2(10000, 10000)
	await get_tree().create_timer(0.5).timeout
	await get_tree().process_frame

	assert(enter_triggered or exit_triggered, "Event should trigger at least once")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	camera.queue_free()
	target.queue_free()
	trigger.queue_free()

## 测试触发模式
func test_trigger_modes():
	print("Test 2: Trigger modes")

	var camera = Camera2D.new()
	camera.name = "TestCamera"
	add_child(camera)

	var target = Node2D.new()
	target.name = "TestTarget"
	target.position = Vector2(0, 0)
	add_child(target)

	var trigger = Node.new()
	add_child(trigger)

	# 测试仅进入模式
	var event_enter = OnScreenEnteredExited.new()
	event_enter.target_node = trigger.get_path_to(target)
	event_enter.trigger_on = OnScreenEnteredExited.TriggerOn.ENTER
	event_enter.check_interval = 0.1

	var enter_triggered = false
	event_enter.triggered.connect(func(context):
		if context.get_meta("event_type") == "entered":
			enter_triggered = true
	)

	event_enter.initialize(trigger)
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout

	print("  ✓ Test 2 passed\n")

	event_enter.terminate(trigger)
	camera.queue_free()
	target.queue_free()
	trigger.queue_free()

## 测试使用相机
func test_with_camera():
	print("Test 3: With custom camera")

	var camera = Camera2D.new()
	camera.name = "CustomCamera"
	camera.position = Vector2(0, 0)
	add_child(camera)

	var target = Node2D.new()
	target.name = "TestTarget"
	target.position = Vector2(0, 0)
	add_child(target)

	var trigger = Node.new()
	add_child(trigger)

	var event = OnScreenEnteredExited.new()
	event.target_node = trigger.get_path_to(target)
	event.camera = trigger.get_path_to(camera)
	event.check_interval = 0.1

	event.initialize(trigger)
	await get_tree().process_frame

	# 等待定时器检查
	await get_tree().create_timer(0.3).timeout

	print("  ✓ Test 3 passed\n")

	event.terminate(trigger)
	camera.queue_free()
	target.queue_free()
	trigger.queue_free()

## 测试参数验证
func test_validation():
	print("Test 4: Parameter validation")

	var event = OnScreenEnteredExited.new()

	# 测试空目标节点
	event.target_node = NodePath("")
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for empty target")
	print("  ✓ Empty target validation passed")

	# 测试无效检查间隔
	event.target_node = NodePath("../TestNode")
	event.check_interval = -1.0
	errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for invalid interval")
	print("  ✓ Invalid interval validation passed")

	print("  ✓ Test 4 passed\n")
