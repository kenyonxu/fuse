extends Node

## OnTouch 事件测试

# 预加载 OnTouch 类
const OnTouch = preload("res://addons/fuse/events/input/on_touch.gd")

func _ready():
	print("=== Testing OnTouch ===")
	await get_tree().process_frame
	test_touch_detection()
	await get_tree().process_frame
	test_action_filtering()
	await get_tree().process_frame
	test_index_filtering()
	await get_tree().process_frame
	test_termination()
	await get_tree().process_frame
	cleanup()
	print("=== All OnTouch tests passed! ===")

func test_touch_detection():
	print("Test 1: Basic touch detection")

	var event_script = load("res://addons/fuse/events/input/on_touch.gd")
	var event = event_script.new()
	event.touch_index = -1  # 所有索引
	event.touch_action = OnTouch.TouchAction.ON_BOTH

	var trigger = Node.new()
	add_child(trigger)

	var received_context = null
	event.triggered.connect(func(context):
		received_context = context
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 模拟触摸事件
	var touch_event = InputEventScreenTouch.new()
	touch_event.index = 0
	touch_event.pressed = true
	touch_event.position = Vector2(100, 200)

	Input.parse_input_event(touch_event)
	await get_tree().process_frame

	assert(received_context != null, "Event should trigger on touch")
	assert(received_context.has_meta("index"), "Context should have index")
	assert(received_context.get_meta("index") == 0, "Should capture touch index")
	assert(received_context.get_meta("pressed") == true, "Should capture pressed state")
	print("  ✓ Test 1 passed: Touch detection works\n")

	event.terminate(trigger)
	trigger.queue_free()

func test_action_filtering():
	print("Test 2: Action filtering")

	var event_script = load("res://addons/fuse/events/input/on_touch.gd")
	var event = event_script.new()
	event.touch_index = -1
	event.touch_action = OnTouch.TouchAction.ON_PRESSED  # 只监听按下

	var trigger = Node.new()
	add_child(trigger)

	var trigger_count = 0
	event.triggered.connect(func(_context):
		trigger_count += 1
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 模拟按下事件
	var press_event = InputEventScreenTouch.new()
	press_event.index = 0
	press_event.pressed = true
	Input.parse_input_event(press_event)
	await get_tree().process_frame

	assert(trigger_count == 1, "Should trigger on press")

	# 模拟释放事件
	var release_event = InputEventScreenTouch.new()
	release_event.index = 0
	release_event.pressed = false
	Input.parse_input_event(release_event)
	await get_tree().process_frame

	assert(trigger_count == 1, "Should not trigger on release with ON_PRESSED mode")
	print("  ✓ Test 2 passed: Action filtering works\n")

	event.terminate(trigger)
	trigger.queue_free()

func test_index_filtering():
	print("Test 3: Touch index filtering")

	var event_script = load("res://addons/fuse/events/input/on_touch.gd")
	var event = event_script.new()
	event.touch_index = 2  # 只监听索引 2
	event.touch_action = OnTouch.TouchAction.ON_BOTH

	var trigger = Node.new()
	add_child(trigger)

	var trigger_count = 0
	event.triggered.connect(func(_context):
		trigger_count += 1
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 模拟索引 0 的触摸（不应触发）
	var touch_event_0 = InputEventScreenTouch.new()
	touch_event_0.index = 0
	touch_event_0.pressed = true
	Input.parse_input_event(touch_event_0)
	await get_tree().process_frame

	assert(trigger_count == 0, "Should not trigger for different index")

	# 模拟索引 2 的触摸（应触发）
	var touch_event_2 = InputEventScreenTouch.new()
	touch_event_2.index = 2
	touch_event_2.pressed = true
	Input.parse_input_event(touch_event_2)
	await get_tree().process_frame

	assert(trigger_count == 1, "Should trigger for matching index")
	print("  ✓ Test 3 passed: Index filtering works\n")

	event.terminate(trigger)
	trigger.queue_free()

func test_termination():
	print("Test 4: Termination and cleanup")

	var event_script = load("res://addons/fuse/events/input/on_touch.gd")
	var event = event_script.new()
	event.touch_index = -1

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
	print("  ✓ Test 4 passed: Termination works\n")

	trigger.queue_free()

func cleanup():
	# 清理测试资源
	pass
