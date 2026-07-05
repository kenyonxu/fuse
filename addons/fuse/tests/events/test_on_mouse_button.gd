extends Node

## OnMouseButton 事件测试

func _ready():
	print("=== Testing OnMouseButton ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_trigger_modes()
	test_validation()
	print("=== All OnMouseButton tests passed! ===")

## 测试基本功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	var event = OnMouseButton.new()
	event.mouse_button = OnMouseButton.CustomMouseButton.LEFT
	event.trigger_mode = OnMouseButton.TriggerMode.PRESSED
	event.require_hovered = false

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	event.triggered.connect(func(node):
		triggered = true
		print("  Event triggered!")
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 模拟鼠标按钮事件
	var mouse_event = InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	mouse_event.pressed = true
	mouse_event.position = Vector2(100, 100)

	# 手动调用 _input
	event._input(mouse_event)
	await get_tree().process_frame

	assert(triggered, "Event should trigger on left mouse button press")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试触发模式
func test_trigger_modes():
	print("Test 2: Trigger modes")

	var trigger = Node.new()
	add_child(trigger)

	# 测试释放模式
	var event_released = OnMouseButton.new()
	event_released.mouse_button = OnMouseButton.CustomMouseButton.LEFT
	event_released.trigger_mode = OnMouseButton.TriggerMode.RELEASED

	var released_triggered = false
	event_released.triggered.connect(func(node):
		released_triggered = true
	)

	event_released.initialize(trigger)
	await get_tree().process_frame

	var mouse_event_release = InputEventMouseButton.new()
	mouse_event_release.button_index = MOUSE_BUTTON_LEFT
	mouse_event_release.pressed = false
	event_released._input(mouse_event_release)
	await get_tree().process_frame

	assert(released_triggered, "Event should trigger on release")
	event_released.terminate(trigger)

	print("  ✓ Test 2 passed\n")
	trigger.queue_free()

## 测试参数验证
func test_validation():
	print("Test 3: Parameter validation")

	var event = OnMouseButton.new()

	# 测试无效的触发模式
	event.mouse_button = -1
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for invalid mouse button")
	print("  ✓ Invalid mouse button validation passed")

	# 测试无效的触发模式
	event.mouse_button = OnMouseButton.CustomMouseButton.LEFT
	event.trigger_mode = -1
	errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for invalid trigger mode")
	print("  ✓ Invalid trigger mode validation passed")

	print("  ✓ Test 3 passed\n")
