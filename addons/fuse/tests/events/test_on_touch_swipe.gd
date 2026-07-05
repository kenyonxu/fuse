extends Node

## OnTouchSwipe 事件测试

func _ready():
	print("=== Testing OnTouchSwipe ===")
	await get_tree().process_frame
	test_horizontal_swipe()
	test_vertical_swipe()
	test_direction_filter()
	print("=== All OnTouchSwipe tests passed! ===")

## 测试水平滑动
func test_horizontal_swipe():
	print("Test 1: Horizontal swipe")

	var event = OnTouchSwipe.new()
	event.swipe_direction = OnTouchSwipe.SwipeDirection.ANY
	event.min_distance = 50.0
	event.time_window = 0.5

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	var received_velocity = Vector2.ZERO
	event.triggered.connect(func(context):
		triggered = true
		if context:
			received_velocity = context.get_meta("velocity", Vector2.ZERO)
			print("  Swipe detected! Velocity: %s" % received_velocity)
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 模拟滑动事件
	var touch_event = InputEventScreenTouch.new()
	touch_event.index = 0
	touch_event.pressed = true
	touch_event.position = Vector2(100, 300)

	# 触摸开始
	trigger._input(touch_event)
	await get_tree().process_frame

	# 触摸结束（模拟向右滑动）
	touch_event.pressed = false
	touch_event.position = Vector2(200, 300)
	trigger._input(touch_event)
	await get_tree().process_frame

	assert(triggered, "Event should trigger on horizontal swipe")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试垂直滑动
func test_vertical_swipe():
	print("Test 2: Vertical swipe")

	var event = OnTouchSwipe.new()
	event.swipe_direction = OnTouchSwipe.SwipeDirection.ANY
	event.min_distance = 50.0

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	event.triggered.connect(func(context):
		triggered = true
		print("  Vertical swipe detected!")
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 模拟向上滑动
	var touch_event = InputEventScreenTouch.new()
	touch_event.index = 0
	touch_event.pressed = true
	touch_event.position = Vector2(200, 400)

	trigger._input(touch_event)
	await get_tree().process_frame

	touch_event.pressed = false
	touch_event.position = Vector2(200, 300)
	trigger._input(touch_event)
	await get_tree().process_frame

	assert(triggered, "Event should trigger on vertical swipe")
	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试方向过滤
func test_direction_filter():
	print("Test 3: Direction filter")

	var event = OnTouchSwipe.new()
	event.swipe_direction = OnTouchSwipe.SwipeDirection.UP
	event.min_distance = 50.0

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	event.triggered.connect(func(context):
		triggered = true
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 模拟向下滑动（不应触发）
	var touch_event = InputEventScreenTouch.new()
	touch_event.index = 0
	touch_event.pressed = true
	touch_event.position = Vector2(200, 300)

	trigger._input(touch_event)
	await get_tree().process_frame

	touch_event.pressed = false
	touch_event.position = Vector2(200, 400)
	trigger._input(touch_event)
	await get_tree().process_frame

	assert(not triggered, "Event should not trigger on wrong direction")

	# 模拟向上滑动（应触发）
	touch_event.pressed = true
	touch_event.position = Vector2(200, 400)
	trigger._input(touch_event)
	await get_tree().process_frame

	touch_event.pressed = false
	touch_event.position = Vector2(200, 300)
	trigger._input(touch_event)
	await get_tree().process_frame

	assert(triggered, "Event should trigger on correct direction")
	print("  ✓ Test 3 passed\n")

	event.terminate(trigger)
	trigger.queue_free()
