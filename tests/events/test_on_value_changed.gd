extends Node

## OnValueChanged 事件测试

func _ready():
	print("=== Testing OnValueChanged ===")
	await get_tree().process_frame
	test_slider_on_change()
	test_slider_on_threshold()
	test_spinbox_on_change()
	test_progressbar_on_change()
	test_validation()
	print("=== All OnValueChanged tests passed! ===")

## 测试 Slider 值变化触发
func test_slider_on_change():
	print("Test 1: Slider value changed")

	var event = OnValueChanged.new()
	var slider = HSlider.new()
	slider.name = "TestSlider"
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.value = 50.0
	add_child(slider)

	var trigger = Node.new()
	add_child(trigger)

	event.target_node_path = trigger.get_path_to(slider)
	event.trigger_mode = OnValueChanged.TriggerMode.ON_ANY_CHANGE

	var triggered = false
	var current_value = -1.0
	var old_value = -1.0
	var delta = 0.0

	event.triggered.connect(func(context):
		triggered = true
		if context:
			current_value = context.get_meta("current_value", -1.0)
			old_value = context.get_meta("old_value", -1.0)
			delta = context.get_meta("delta", 0.0)
		print("  Event triggered! Current: %.2f, Old: %.2f, Delta: %.2f" % [current_value, old_value, delta])
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 改变滑块值
	slider.value = 75.0
	slider.emit_signal("drag_ended")
	await get_tree().process_frame

	assert(triggered, "Event should trigger when slider value changes")
	assert(current_value == 75.0, "Current value should be 75.0")
	assert(old_value == 50.0, "Old value should be 50.0")
	assert(delta == 25.0, "Delta should be 25.0")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	slider.queue_free()
	trigger.queue_free()

## 测试 Slider 阈值触发
func test_slider_on_threshold():
	print("Test 2: Slider threshold trigger")

	var event = OnValueChanged.new()
	var slider = HSlider.new()
	slider.name = "ThresholdSlider"
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.value = 30.0
	add_child(slider)

	var trigger = Node.new()
	add_child(trigger)

	event.target_node_path = trigger.get_path_to(slider)
	event.trigger_mode = OnValueChanged.TriggerMode.ON_THRESHOLD
	event.threshold_value = 50.0

	var triggered = false
	var threshold_reached = false

	event.triggered.connect(func(context):
		triggered = true
		if context:
			threshold_reached = context.get_meta("threshold_reached", false)
		print("  Event triggered! Threshold reached: ", threshold_reached)
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 跨越阈值
	slider.value = 60.0
	slider.emit_signal("drag_ended")
	await get_tree().process_frame

	assert(triggered, "Event should trigger when crossing threshold")
	assert(threshold_reached, "Threshold should be reached")
	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	slider.queue_free()
	trigger.queue_free()

## 测试 SpinBox 值变化
func test_spinbox_on_change():
	print("Test 3: SpinBox value changed")

	var event = OnValueChanged.new()
	var spinbox = SpinBox.new()
	spinbox.name = "TestSpinBox"
	spinbox.min_value = 0.0
	spinbox.max_value = 10.0
	spinbox.value = 5.0
	add_child(spinbox)

	var trigger = Node.new()
	add_child(trigger)

	event.target_node_path = trigger.get_path_to(spinbox)
	event.trigger_mode = OnValueChanged.TriggerMode.ON_ANY_CHANGE

	var triggered = false
	var current_value = -1.0

	event.triggered.connect(func(context):
		triggered = true
		if context:
			current_value = context.get_meta("current_value", -1.0)
		print("  Event triggered! SpinBox value: %.2f" % current_value)
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 改变 SpinBox 值
	spinbox.value = 7.5
	await get_tree().process_frame

	assert(triggered, "Event should trigger when SpinBox value changes")
	assert(current_value == 7.5, "Current value should be 7.5")
	print("  ✓ Test 3 passed\n")

	event.terminate(trigger)
	spinbox.queue_free()
	trigger.queue_free()

## 测试 ProgressBar 值变化
func test_progressbar_on_change():
	print("Test 4: ProgressBar value changed")

	var event = OnValueChanged.new()
	var progressbar = ProgressBar.new()
	progressbar.name = "TestProgressBar"
	progressbar.min_value = 0.0
	progressbar.max_value = 100.0
	progressbar.value = 20.0
	add_child(progressbar)

	var trigger = Node.new()
	add_child(trigger)

	event.target_node_path = trigger.get_path_to(progressbar)
	event.trigger_mode = OnValueChanged.TriggerMode.ON_MAX_REACHED
	event.max_threshold = 100.0

	var triggered = false
	var current_value = -1.0

	event.triggered.connect(func(context):
		triggered = true
		if context:
			current_value = context.get_meta("current_value", -1.0)
		print("  Event triggered! ProgressBar value: %.2f" % current_value)
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 设置为最大值
	progressbar.value = 100.0
	await get_tree().process_frame

	assert(triggered, "Event should trigger when ProgressBar reaches max")
	assert(current_value == 100.0, "Current value should be 100.0")
	print("  ✓ Test 4 passed\n")

	event.terminate(trigger)
	progressbar.queue_free()
	trigger.queue_free()

## 测试参数验证
func test_validation():
	print("Test 5: Parameter validation")

	var event = OnValueChanged.new()

	# 测试空目标节点
	event.target_node_path = NodePath("")
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for empty target")
	print("  ✓ Empty target validation passed")

	print("  ✓ Test 5 passed\n")
