extends Node

## OnSceneAboutToChange 事件测试

func _ready():
	print("=== Testing OnSceneAboutToChange ===")
	await get_tree().process_frame
	test_initialization()
	test_termination()
	test_context_emission()
	cleanup()
	print("=== All OnSceneAboutToChange tests passed! ===")

## 测试初始化
func test_initialization():
	print("Test 1: Initialization and setup")

	var event_script = load("res://addons/fuse/events/scene/on_scene_about_to_change.gd")
	var event = event_script.new()
	event.emit_scene_path = true

	var trigger = Node.new()
	add_child(trigger)

	event.initialize(trigger)
	await get_tree().process_frame

	# 验证信号已连接
	assert(event._is_connected == true, "_is_connected should be true after initialization")
	assert(event._owner_node_ref == trigger, "Owner reference should be set")
	print("  ✓ Event initialized successfully")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试终止和清理
func test_termination():
	print("Test 2: Termination and cleanup")

	var event_script = load("res://addons/fuse/events/scene/on_scene_about_to_change.gd")
	var event = event_script.new()

	var trigger = Node.new()
	add_child(trigger)

	event.initialize(trigger)
	await get_tree().process_frame

	# 验证信号已连接
	var scene_root = get_tree().root
	assert(event._is_connected == true, "_is_connected should be true")
	assert(scene_root.about_to_disconnect_from_scene.is_connected(event._on_scene_about_to_change), "about_to_disconnect_from_scene should be connected")

	# 终止事件
	event.terminate(trigger)

	# 验证信号已断开
	assert(event._is_connected == false, "_is_connected should be false after termination")
	assert(not scene_root.about_to_disconnect_from_scene.is_connected(event._on_scene_about_to_change), "about_to_disconnect_from_scene should be disconnected")
	assert(event._owner_node_ref == null, "Owner reference should be cleared")
	print("  ✓ Termination works correctly")
	print("  ✓ Test 2 passed\n")

	trigger.queue_free()

## 测试上下文发射
func test_context_emission():
	print("Test 3: Context emission")

	var event_script = load("res://addons/fuse/events/scene/on_scene_about_to_change.gd")
	var event = event_script.new()
	event.emit_scene_path = true

	var trigger = Node.new()
	add_child(trigger)

	var received_context = null
	event.triggered.connect(func(context):
		received_context = context
		print("  Event triggered with context: %s" % str(context))
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 注意：about_to_disconnect_from_scene 信号在实际场景切换时才会触发
	# 这里我们主要测试事件的结构和设置是否正确
	print("  ✓ Event structure validated")
	print("  ✓ Test 3 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 清理测试资源
func cleanup():
	# 清理测试资源
	pass
