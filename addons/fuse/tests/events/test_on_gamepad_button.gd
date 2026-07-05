extends Node

## OnGamepadButton 事件测试

func _ready():
	print("=== Testing OnGamepadButton ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_trigger_modes()
	test_device_filtering()
	test_validation()
	print("=== All OnGamepadButton tests passed! ===")

## 测试基本功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	var event = OnGamepadButton.new()
	event.device = 0
	event.button_index = JOY_BUTTON_A
	event.trigger_mode = OnGamepadButton.TriggerMode.PRESSED

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	var context_node = null
	event.triggered.connect(func(node):
		triggered = true
		context_node = node
		print("  Event triggered!")
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 模拟手柄按钮事件
	var button_event = InputEventJoypadButton.new()
	button_event.device = 0
	button_event.button_index = JOY_BUTTON_A
	button_event.pressed = true

	# 手动调用 _input
	event._input(button_event)
	await get_tree().process_frame

	assert(triggered, "Event should trigger on button press")
	assert(context_node != null, "Context node should be provided")
	assert(context_node.has_meta("device"), "Context should have device")
	assert(context_node.has_meta("button_index"), "Context should have button_index")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试触发模式
func test_trigger_modes():
	print("Test 2: Trigger modes")

	var trigger = Node.new()
	add_child(trigger)

	# 测试释放模式
	var event_released = OnGamepadButton.new()
	event_released.device = 0
	event_released.button_index = JOY_BUTTON_A
	event_released.trigger_mode = OnGamepadButton.TriggerMode.RELEASED

	var released_triggered = false
	event_released.triggered.connect(func(node):
		released_triggered = true
	)

	event_released.initialize(trigger)
	await get_tree().process_frame

	var button_event_release = InputEventJoypadButton.new()
	button_event_release.device = 0
	button_event_release.button_index = JOY_BUTTON_A
	button_event_release.pressed = false
	event_released._input(button_event_release)
	await get_tree().process_frame

	assert(released_triggered, "Event should trigger on release")
	event_released.terminate(trigger)

	# 测试按下模式不触发释放事件
	var event_pressed = OnGamepadButton.new()
	event_pressed.device = 0
	event_pressed.button_index = JOY_BUTTON_B
	event_pressed.trigger_mode = OnGamepadButton.TriggerMode.PRESSED

	var pressed_triggered = false
	event_pressed.triggered.connect(func(node):
		pressed_triggered = true
	)

	event_pressed.initialize(trigger)
	await get_tree().process_frame

	var button_event_release2 = InputEventJoypadButton.new()
	button_event_release2.device = 0
	button_event_release2.button_index = JOY_BUTTON_B
	button_event_release2.pressed = false
	event_pressed._input(button_event_release2)
	await get_tree().process_frame

	assert(not pressed_triggered, "Pressed mode should not trigger on release")
	event_pressed.terminate(trigger)

	print("  ✓ Test 2 passed\n")
	trigger.queue_free()

## 测试设备过滤
func test_device_filtering():
	print("Test 3: Device filtering")

	var trigger = Node.new()
	add_child(trigger)

	# 测试特定设备
	var event_specific = OnGamepadButton.new()
	event_specific.device = 0
	event_specific.button_index = JOY_BUTTON_A
	event_specific.trigger_mode = OnGamepadButton.TriggerMode.PRESSED

	var specific_triggered = false
	event_specific.triggered.connect(func(node):
		specific_triggered = true
	)

	event_specific.initialize(trigger)
	await get_tree().process_frame

	# 来自其他设备的按钮事件（不应该触发）
	var button_event_other = InputEventJoypadButton.new()
	button_event_other.device = 1
	button_event_other.button_index = JOY_BUTTON_A
	button_event_other.pressed = true
	event_specific._input(button_event_other)
	await get_tree().process_frame

	assert(not specific_triggered, "Event should not trigger for different device")
	event_specific.terminate(trigger)

	# 测试任意设备 (-1)
	var event_any = OnGamepadButton.new()
	event_any.device = -1
	event_any.button_index = JOY_BUTTON_B
	event_any.trigger_mode = OnGamepadButton.TriggerMode.PRESSED

	var any_triggered_0 = false
	var any_triggered_1 = false
	event_any.triggered.connect(func(node):
		var context = node
		var dev = context.get_meta("device")
		if dev == 0:
			any_triggered_0 = true
		elif dev == 1:
			any_triggered_1 = true
	)

	event_any.initialize(trigger)
	await get_tree().process_frame

	# 来自设备 0 的事件
	var button_event_0 = InputEventJoypadButton.new()
	button_event_0.device = 0
	button_event_0.button_index = JOY_BUTTON_B
	button_event_0.pressed = true
	event_any._input(button_event_0)
	await get_tree().process_frame

	# 来自设备 1 的事件
	var button_event_1 = InputEventJoypadButton.new()
	button_event_1.device = 1
	button_event_1.button_index = JOY_BUTTON_B
	button_event_1.pressed = true
	event_any._input(button_event_1)
	await get_tree().process_frame

	assert(any_triggered_0, "Event should trigger for device 0")
	assert(any_triggered_1, "Event should trigger for device 1")
	event_any.terminate(trigger)

	print("  ✓ Test 3 passed\n")
	trigger.queue_free()

## 测试参数验证
func test_validation():
	print("Test 4: Parameter validation")

	var event = OnGamepadButton.new()

	# 测试无效的设备索引
	event.device = -2
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for device < -1")
	print("  ✓ Invalid device index validation passed")

	# 测试无效的触发模式
	event.device = 0
	event.trigger_mode = -1
	errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for invalid trigger mode")
	print("  ✓ Invalid trigger mode validation passed")

	# 测试有效配置
	event.device = 0
	event.trigger_mode = OnGamepadButton.TriggerMode.PRESSED
	errors = event.validate()
	assert(errors.is_empty(), "Valid configuration should have no errors")
	print("  ✓ Valid configuration validation passed")

	print("  ✓ Test 4 passed\n")
