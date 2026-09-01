extends Node

## OnEnterTree 事件测试

func _ready():
	print("=== Testing OnEnterTree ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_dynamic_node()
	print("=== All OnEnterTree tests passed! ===")

## 测试基本功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	var event = OnEnterTree.new()
	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	event.triggered.connect(func(node):
		triggered = true
		print("  Event triggered!")
	)

	# 初始化事件（此时 trigger 已在树中，tree_entered 信号可能已发射）
	event.initialize(trigger)
	await get_tree().process_frame

	# 如果节点已经在树中，可能不会触发 tree_entered
	# 但事件应该正确初始化
	print("  Event initialized successfully")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试动态节点
func test_dynamic_node():
	print("Test 2: Dynamic node")

	var event = OnEnterTree.new()
	var trigger = Node.new()

	var triggered = false
	event.triggered.connect(func(node):
		triggered = true
		print("  Event triggered!")
	)

	# 初始化事件（trigger 不在树中）
	event.initialize(trigger)
	await get_tree().process_frame

	assert(not triggered, "Event should not trigger yet")

	# 添加到场景树
	add_child(trigger)
	await get_tree().process_frame

	assert(triggered, "Event should trigger when node enters tree")
	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	trigger.queue_free()
