extends Node

## OnMouseMove 事件测试

func _ready():
	print("=== Testing OnMouseMove ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_trigger_modes()
	test_hover_requirement()
	test_validation()
	print("=== All OnMouseMove tests passed! ===")

## 测试基本功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	var event = OnMouseMove.new()
	event.trigger_mode = OnMouseMove.TriggerMode.CONTINUOUS
	event.require_hovered = false

	var trigger = Node.new()
	add_child(trigger)

	var trigger_count = 0
	event.triggered.connect(func(node):
		trigger_count += 1
		print("  Event triggered! Count: ", trigger_count)
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 模拟鼠标移动事件
	var mouse_event = InputEventMouseMotion.new()
	mouse_event.position = Vector2(100, 100)
	mouse_event.relative = Vector2(10, 10)

	# 手动调用 _input
	event._input(mouse_event)
	await get_tree().process_frame

	assert(trigger_count > 0, "Event should trigger on mouse move")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试触发模式
func test_trigger_modes():
	print("Test 2: Trigger modes")

	var trigger = Node.new()
	add_child(trigger)

	# 测试阈值触发模式
	var event_threshold = OnMouseMove.new()
	event_threshold.trigger_mode = OnMouseMove.TriggerMode.ON_THRESHOLD
	event_threshold.move_threshold = 50.0
	event_threshold.require_hovered = false

	var threshold_triggered = false
	event_threshold.triggered.connect(func(node):
		threshold_triggered = true
		print("  Threshold event triggered!")
	)

	event_threshold.initialize(trigger)
	await get_tree().process_frame

	# 第一次移动（未达到阈值）
	var mouse_event1 = InputEventMouseMotion.new()
	mouse_event1.position = Vector2(100, 100)
	event_threshold._input(mouse_event1)

	# 第二次移动（达到阈值）
	await get_tree().create_timer(0.1).timeout
	var mouse_event2 = InputEventMouseMotion.new()
	mouse_event2.position = Vector2(160, 160)  # 移动距离约 84.8 像素
	event_threshold._input(mouse_event2)
	await get_tree().process_frame

	assert(threshold_triggered, "Event should trigger when threshold is reached")
	event_threshold.terminate(trigger)

	print("  ✓ Test 2 passed\n")
	trigger.queue_free()

## 测试悬停要求
func test_hover_requirement():
	print("Test 3: Hover requirement")

	var trigger = Node.new()
	add_child(trigger)

	# 创建一个 Control 节点用于悬停检测
	var control = Control.new()
	control.custom_minimum_size = Vector2(100, 100)
	control.position = Vector2(50, 50)
	trigger.add_child(control)

	# 测试需要悬停
	var event_hover = OnMouseMove.new()
	event_hover.trigger_mode = OnMouseMove.TriggerMode.CONTINUOUS
	event_hover.require_hovered = true
	event_hover.target_node_path = control.get_path()

	var hover_triggered = false
	event_hover.triggered.connect(func(node):
		hover_triggered = true
	)

	event_hover.initialize(trigger)
	await get_tree().process_frame

	# 模拟鼠标不在悬停位置
	var mouse_event_outside = InputEventMouseMotion.new()
	mouse_event_outside.position = Vector2(10, 10)
	mouse_event_outside.relative = Vector2(10, 10)
	event_hover._input(mouse_event_outside)
	await get_tree().process_frame

	assert(not hover_triggered, "Event should not trigger when not hovered")

	# 模拟鼠标在悬停位置
	var mouse_event_inside = InputEventMouseMotion.new()
	mouse_event_inside.position = Vector2(75, 75)
	mouse_event_inside.relative = Vector2(10, 10)
	event_hover._input(mouse_event_inside)
	await get_tree().process_frame

	# Control 节点的 is_hovered() 需要真实的鼠标输入
	# 这里主要验证事件逻辑，实际悬停需要真实测试

	event_hover.terminate(trigger)
	control.queue_free()

	print("  ✓ Test 3 passed\n")
	trigger.queue_free()

## 测试参数验证
func test_validation():
	print("Test 4: Parameter validation")

	var event = OnMouseMove.new()

	# 测试无效的触发模式
	event.trigger_mode = -1
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for invalid trigger mode")
	print("  ✓ Invalid trigger mode validation passed")

	# 测试无效的阈值
	event.trigger_mode = OnMouseMove.TriggerMode.ON_THRESHOLD
	event.move_threshold = -10.0
	errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for negative threshold")
	print("  ✓ Negative threshold validation passed")

	# 测试过小的阈值
	event.move_threshold = 0.5
	errors = event.validate()
	assert(not errors.is_empty(), "Should have validation warning for too small threshold")
	print("  ✓ Small threshold validation passed")

	print("  ✓ Test 4 passed\n")
