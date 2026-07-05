extends Node

## OnButtonPressed 事件测试

func _ready():
	print("=== Testing OnButtonPressed ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_disabled_button()
	test_validation()
	print("=== All OnButtonPressed tests passed! ===")

## 测试基本功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	var event = OnButtonPressed.new()
	var button = Button.new()
	button.name = "TestButton"
	button.text = "Click Me"
	add_child(button)

	var trigger = Node.new()
	add_child(trigger)

	event.target_button = trigger.get_path_to(button)
	event.require_enabled = true

	var triggered = false
	event.triggered.connect(func():
		triggered = true
		print("  Event triggered!")
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 模拟按钮点击
	button.emit_signal("pressed")
	await get_tree().process_frame

	assert(triggered, "Event should trigger when button is pressed")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	button.queue_free()
	trigger.queue_free()

## 测试禁用按钮
func test_disabled_button():
	print("Test 2: Disabled button")

	var event = OnButtonPressed.new()
	var button = Button.new()
	button.name = "DisabledButton"
	button.text = "Disabled"
	button.disabled = true
	add_child(button)

	var trigger = Node.new()
	add_child(trigger)

	event.target_button = trigger.get_path_to(button)
	event.require_enabled = true

	var triggered = false
	event.triggered.connect(func():
		triggered = true
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 尝试点击禁用的按钮
	button.emit_signal("pressed")
	await get_tree().process_frame

	assert(not triggered, "Event should not trigger when button is disabled")
	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	button.queue_free()
	trigger.queue_free()

## 测试参数验证
func test_validation():
	print("Test 3: Parameter validation")

	var event = OnButtonPressed.new()

	# 测试空目标节点
	event.target_button = NodePath("")
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for empty target")
	print("  ✓ Empty target validation passed")

	print("  ✓ Test 3 passed\n")
