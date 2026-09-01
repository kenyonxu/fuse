extends Node

## OnSceneLoaded 事件测试

func _ready():
	print("=== Testing OnSceneLoaded ===")
	await get_tree().process_frame
	test_current_scene()
	test_validation()
	print("=== All OnSceneLoaded tests passed! ===")

## 测试当前场景
func test_current_scene():
	print("Test 1: Current scene")

	var event = OnSceneLoaded.new()
	event.scene_path = ""  # 空字符串表示当前场景

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	event.triggered.connect(func(node):
		triggered = true
		print("  Event triggered! Scene: %s" % node.name if node else "null")
	)

	event.initialize(trigger)
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout

	assert(triggered, "Event should trigger for current scene")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试参数验证
func test_validation():
	print("Test 2: Parameter validation")

	var event = OnSceneLoaded.new()

	# 测试无效的场景扩展名
	event.scene_path = "invalid_scene.txt"
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for invalid extension")
	print("  ✓ Invalid extension validation passed")

	# 测试有效的扩展名
	event.scene_path = "test_scene.tscn"
	errors = event.validate()
	assert(errors.is_empty(), "Valid extension should pass validation")
	print("  ✓ Valid extension passed")

	print("  ✓ Test 2 passed\n")
