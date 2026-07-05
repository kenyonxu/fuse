extends Node

## OnExitTree 事件测试

func _ready():
	print("=== Testing OnExitTree ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_cleanup_flag()
	print("=== All OnExitTree tests passed! ===")

## 测试基本功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	var event = OnExitTree.new()
	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	event.triggered.connect(func(node):
		triggered = true
		print("  Event triggered!")
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 从场景树移除
	remove_child(trigger)
	await get_tree().process_frame

	assert(triggered, "Event should trigger when node exits tree")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试清理标志
func test_cleanup_flag():
	print("Test 2: Cleanup flag")

	var event = OnExitTree.new()
	event.cleanup_resources = true

	var trigger = Node.new()
	add_child(trigger)

	var cleanup_flag_received = false
	event.triggered.connect(func(context):
		if context and context.has_meta("cleanup_resources"):
			cleanup_flag_received = context.get_meta("cleanup_resources")
			print("  Event triggered with cleanup flag: %s" % cleanup_flag_received)
	)

	event.initialize(trigger)
	await get_tree().process_frame

	remove_child(trigger)
	await get_tree().process_frame

	assert(cleanup_flag_received == true, "Event should pass cleanup flag in context")
	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	trigger.queue_free()
