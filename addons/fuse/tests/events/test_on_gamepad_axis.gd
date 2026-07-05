extends Node

## OnGamepadAxis 事件测试

# 预加载事件类
const OnGamepadAxis = preload("res://addons/fuse/events/input/on_gamepad_axis.gd")

var _test_trigger_count = 0
var _test_context_node = null
var _test_last_value = null

func _ready():
	print("=== Testing OnGamepadAxis ===")
	await get_tree().process_frame
	test_axis_detection()
	test_trigger_modes()
	test_deadzone()
	test_device_filtering()
	test_validation()
	test_termination()
	print("=== All OnGamepadAxis tests passed! ===")

## 测试基本轴值检测
func test_axis_detection():
	print("Test 1: Basic axis detection")

	_test_trigger_count = 0
	_test_context_node = null

	var event = OnGamepadAxis.new()
	event.device_index = 0
	event.axis_index = 0
	event.trigger_mode = OnGamepadAxis.TriggerMode.ON_ANY_CHANGE

	var trigger = Node.new()
	add_child(trigger)

	event.triggered.connect(_on_test_triggered.bind("axis_detection"))
	event.initialize(trigger)
	await get_tree().process_frame

	# 模拟手柄轴输入事件
	var axis_event = InputEventJoypadMotion.new()
	axis_event.device = 0
	axis_event.axis = 0
	axis_event.axis_value = 0.5

	# 手动调用 _input
	event._input(axis_event)
	await get_tree().process_frame

	assert(_test_trigger_count == 1, "Event should trigger on axis motion")
	assert(_test_context_node != null, "Context node should be provided")
	assert(_test_context_node.has_meta("axis"), "Context should have axis")
	assert(_test_context_node.has_meta("axis_value"), "Context should have axis_value")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试触发模式
func test_trigger_modes():
	print("Test 2: Trigger modes")

	var trigger = Node.new()
	add_child(trigger)

	# 测试 ON_THRESHOLD 模式
	_test_trigger_count = 0
	var event_threshold = OnGamepadAxis.new()
	event_threshold.device_index = 0
	event_threshold.axis_index = 0
	event_threshold.trigger_mode = OnGamepadAxis.TriggerMode.ON_THRESHOLD
	event_threshold.threshold = 0.5

	event_threshold.triggered.connect(_on_test_triggered.bind("threshold"))
	event_threshold.initialize(trigger)
	await get_tree().process_frame

	# 测试低于阈值的输入
	var axis_event_low = InputEventJoypadMotion.new()
	axis_event_low.device = 0
	axis_event_low.axis = 0
	axis_event_low.axis_value = 0.3
	event_threshold._input(axis_event_low)
	await get_tree().process_frame

	assert(_test_trigger_count == 0, "Should not trigger below threshold")

	# 测试超过阈值的输入
	var axis_event_high = InputEventJoypadMotion.new()
	axis_event_high.device = 0
	axis_event_high.axis = 0
	axis_event_high.axis_value = 0.6
	event_threshold._input(axis_event_high)
	await get_tree().process_frame

	assert(_test_trigger_count == 1, "Should trigger above threshold")
	print("  ✓ Threshold mode passed")

	event_threshold.terminate(trigger)

	# 测试 ON_CROSS_ZERO 模式
	_test_trigger_count = 0
	var event_cross = OnGamepadAxis.new()
	event_cross.device_index = 0
	event_cross.axis_index = 0
	event_cross.trigger_mode = OnGamepadAxis.TriggerMode.ON_CROSS_ZERO

	event_cross.triggered.connect(_on_test_triggered.bind("cross_zero"))
	event_cross.initialize(trigger)
	await get_tree().process_frame

	# 测试正负切换
	var axis_event_positive = InputEventJoypadMotion.new()
	axis_event_positive.device = 0
	axis_event_positive.axis = 0
	axis_event_positive.axis_value = 0.5
	event_cross._input(axis_event_positive)
	await get_tree().process_frame

	assert(_test_trigger_count == 0, "Should not trigger on first positive value")

	var axis_event_negative = InputEventJoypadMotion.new()
	axis_event_negative.device = 0
	axis_event_negative.axis = 0
	axis_event_negative.axis_value = -0.5
	event_cross._input(axis_event_negative)
	await get_tree().process_frame

	assert(_test_trigger_count == 1, "Should trigger when crossing zero")
	print("  ✓ Cross zero mode passed")

	event_cross.terminate(trigger)

	print("  ✓ Test 2 passed\n")
	trigger.queue_free()

## 测试死区处理
func test_deadzone():
	print("Test 3: Deadzone handling")

	_test_last_value = null
	var event = OnGamepadAxis.new()
	event.device_index = 0
	event.axis_index = 0
	event.deadzone = 0.2
	event.trigger_mode = OnGamepadAxis.TriggerMode.ON_ANY_CHANGE

	var trigger = Node.new()
	add_child(trigger)

	event.triggered.connect(_on_test_axis_value)
	event.initialize(trigger)
	await get_tree().process_frame

	# 测试死区内的输入
	var axis_event_inside = InputEventJoypadMotion.new()
	axis_event_inside.device = 0
	axis_event_inside.axis = 0
	axis_event_inside.axis_value = 0.1
	event._input(axis_event_inside)
	await get_tree().process_frame

	assert(_test_last_value == 0.0, "Value inside deadzone should be zero")

	# 测试超过死区的输入
	var axis_event_outside = InputEventJoypadMotion.new()
	axis_event_outside.device = 0
	axis_event_outside.axis = 0
	axis_event_outside.axis_value = 0.5
	event._input(axis_event_outside)
	await get_tree().process_frame

	assert(_test_last_value == 0.5, "Value outside deadzone should be preserved")
	print("  ✓ Test 3 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试设备过滤
func test_device_filtering():
	print("Test 4: Device filtering")

	var trigger = Node.new()
	add_child(trigger)

	# 测试特定设备
	_test_trigger_count = 0
	var event_specific = OnGamepadAxis.new()
	event_specific.device_index = 0
	event_specific.axis_index = 0

	event_specific.triggered.connect(_on_test_triggered.bind("specific"))
	event_specific.initialize(trigger)
	await get_tree().process_frame

	# 来自其他设备的输入（不应该触发）
	var axis_event_other = InputEventJoypadMotion.new()
	axis_event_other.device = 1
	axis_event_other.axis = 0
	axis_event_other.axis_value = 0.5
	event_specific._input(axis_event_other)
	await get_tree().process_frame

	assert(_test_trigger_count == 0, "Event should not trigger for different device")
	event_specific.terminate(trigger)

	# 测试任意设备 (-1)
	_test_trigger_count = 0
	var device_0_triggered = false
	var device_1_triggered = false
	var event_any = OnGamepadAxis.new()
	event_any.device_index = -1
	event_any.axis_index = 0

	event_any.triggered.connect(_on_test_device_check.bind(func(dev):
		if dev == 0:
			device_0_triggered = true
		elif dev == 1:
			device_1_triggered = true
	))

	event_any.initialize(trigger)
	await get_tree().process_frame

	# 来自设备 0 的事件
	var axis_event_0 = InputEventJoypadMotion.new()
	axis_event_0.device = 0
	axis_event_0.axis = 0
	axis_event_0.axis_value = 0.5
	event_any._input(axis_event_0)
	await get_tree().process_frame

	# 来自设备 1 的事件
	var axis_event_1 = InputEventJoypadMotion.new()
	axis_event_1.device = 1
	axis_event_1.axis = 0
	axis_event_1.axis_value = 0.5
	event_any._input(axis_event_1)
	await get_tree().process_frame

	assert(device_0_triggered, "Event should trigger for device 0")
	assert(device_1_triggered, "Event should trigger for device 1")
	event_any.terminate(trigger)

	print("  ✓ Test 4 passed\n")
	trigger.queue_free()

## 测试参数验证
func test_validation():
	print("Test 5: Parameter validation")

	var event = OnGamepadAxis.new()

	# 测试无效的轴索引
	event.axis_index = 6
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for axis > 5")
	print("  ✓ Invalid axis index validation passed")

	# 测试无效的死区值
	event.axis_index = 0
	event.deadzone = 1.5
	errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for deadzone > 1.0")
	print("  ✓ Invalid deadzone validation passed")

	# 测试有效配置
	event.axis_index = 0
	event.deadzone = 0.2
	errors = event.validate()
	assert(errors.is_empty(), "Valid configuration should have no errors")
	print("  ✓ Valid configuration validation passed")

	print("  ✓ Test 5 passed\n")

## 测试终止和清理
func test_termination():
	print("Test 6: Termination and cleanup")

	var event = OnGamepadAxis.new()
	event.device_index = 0
	event.axis_index = 0

	var trigger = Node.new()
	add_child(trigger)

	event.initialize(trigger)
	await get_tree().process_frame

	# 验证 tree_entered 信号已连接
	assert(trigger.tree_entered.is_connected(event._on_tree_entered), "tree_entered should be connected")

	# 终止事件
	event.terminate(trigger)

	# 验证信号已断开
	assert(not trigger.tree_entered.is_connected(event._on_tree_entered), "tree_entered should be disconnected")
	assert(event._owner_node_ref == null, "Owner reference should be cleared")
	print("  ✓ Test 6 passed\n")

	trigger.queue_free()

## 测试回调：记录触发和上下文
func _on_test_triggered(test_name: String, context: Node):
	_test_trigger_count += 1
	_test_context_node = context

## 测试回调：记录轴值
func _on_test_axis_value(context: Node):
	_test_last_value = context.get_meta("axis_value")

## 测试回调：设备检查
func _on_test_device_check(callback: Callable, context: Node):
	var dev = context.get_meta("device")
	callback.call(dev)
