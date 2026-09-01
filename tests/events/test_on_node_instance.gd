extends Node

## OnNodeInstance 事件测试

func _ready():
	print("=== Testing OnNodeInstance ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_parent_filtering()
	test_validation()
	print("=== All OnNodeInstance tests passed! ===")

## 测试基本功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	# 创建临时场景文件
	var scene = PackedScene.new()
	var node = Node2D.new()
	node.name = "TestInstance"
	scene.pack(node)

	var scene_path = "user://test_instance_scene.tscn"
	ResourceSaver.save(scene, scene_path)

	var event = OnNodeInstance.new()
	event.scene_path = scene_path

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	event.triggered.connect(func(instance_node):
		triggered = true
		print("  Event triggered! Instance: %s" % instance_node.name if instance_node else "null")
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 实例化场景
	var instance = scene.instantiate()
	instance.name = "TestInstance"
	add_child(instance)
	await get_tree().process_frame

	assert(triggered, "Event should trigger when scene is instantiated")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	instance.queue_free()
	trigger.queue_free()

	# 清理临时文件
	DirAccess.remove_absolute(scene_path)

## 测试父节点过滤
func test_parent_filtering():
	print("Test 2: Parent filtering")

	# 创建临时场景
	var scene = PackedScene.new()
	var node = Node2D.new()
	node.name = "TestInstance"
	scene.pack(node)

	var scene_path = "user://test_instance_parent_scene.tscn"
	ResourceSaver.save(scene, scene_path)

	var parent = Node2D.new()
	parent.name = "TestParent"
	add_child(parent)

	var event = OnNodeInstance.new()
	event.scene_path = scene_path
	event.parent_node = "^/TestParent"

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	event.triggered.connect(func(instance_node):
		triggered = true
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 实例化场景到指定父节点
	var instance = scene.instantiate()
	instance.name = "TestInstance"
	parent.add_child(instance)
	await get_tree().process_frame

	assert(triggered, "Event should trigger for correct parent")
	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	instance.queue_free()
	parent.queue_free()
	trigger.queue_free()

	# 清理临时文件
	DirAccess.remove_absolute(scene_path)

## 测试参数验证
func test_validation():
	print("Test 3: Parameter validation")

	var event = OnNodeInstance.new()

	# 测试空场景路径
	event.scene_path = ""
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for empty scene path")
	print("  ✓ Empty scene path validation passed")

	# 测试无效的扩展名
	event.scene_path = "invalid.txt"
	errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for invalid extension")
	print("  ✓ Invalid extension validation passed")

	print("  ✓ Test 3 passed\n")
