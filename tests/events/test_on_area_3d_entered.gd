extends Node

## OnArea3DEntered 事件测试

func _ready():
	print("=== Testing OnArea3DEntered ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_target_group()
	test_trigger_once()
	test_validation()
	print("=== All OnArea3DEntered tests passed! ===")

## 测试基本功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	var event = OnArea3DEntered.new()
	var area = Area3D.new()
	area.name = "TestArea"
	add_child(area)

	# 添加碰撞形状
	var collision_shape = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2, 2, 2)
	collision_shape.shape = shape
	area.add_child(collision_shape)

	# 创建物理体
	var body = StaticBody3D.new()
	body.name = "TestBody"
	body.position = Vector3(0, 0, 0)
	add_child(body)

	# 添加碰撞形状到物理体
	var body_collision = CollisionShape3D.new()
	var body_shape = BoxShape3D.new()
	body_shape.size = Vector3(1, 1, 1)
	body_collision.shape = body_shape
	body.add_child(body_collision)

	var trigger = Node.new()
	add_child(trigger)

	event.area_node_path = trigger.get_path_to(area)
	event.target_group = ""

	var triggered = false
	var entered_body = null
	event.triggered.connect(func(node):
		triggered = true
		entered_body = node
		print("  Event triggered! Body: %s" % node.name)
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 移动物体进入区域
	body.position = Vector3(0, 0, 0)
	await get_tree().create_timer(0.1).timeout

	assert(triggered, "Event should trigger when body enters area")
	assert(entered_body == body, "Should pass correct body")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	area.queue_free()
	body.queue_free()
	trigger.queue_free()

## 测试目标组过滤
func test_target_group():
	print("Test 2: Target group filtering")

	var event = OnArea3DEntered.new()
	var area = Area3D.new()
	area.name = "TestArea"
	add_child(area)

	var collision_shape = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2, 2, 2)
	collision_shape.shape = shape
	area.add_child(collision_shape)

	# 创建带组的物体
	var body1 = StaticBody3D.new()
	body1.name = "TargetBody"
	body1.add_to_group("target")
	body1.position = Vector3(0, 0, 0)
	add_child(body1)

	var body_collision1 = CollisionShape3D.new()
	var body_shape1 = BoxShape3D.new()
	body_shape1.size = Vector3(1, 1, 1)
	body_collision1.shape = body_shape1
	body1.add_child(body_collision1)

	# 创建不带组的物体
	var body2 = StaticBody3D.new()
	body2.name = "NonTargetBody"
	body2.position = Vector3(0, 0, 0)
	add_child(body2)

	var body_collision2 = CollisionShape3D.new()
	var body_shape2 = BoxShape3D.new()
	body_shape2.size = Vector3(1, 1, 1)
	body_collision2.shape = body_shape2
	body2.add_child(body_collision2)

	var trigger = Node.new()
	add_child(trigger)

	event.area_node_path = trigger.get_path_to(area)
	event.target_group = "target"

	var triggered = false
	var entered_body = null
	event.triggered.connect(func(node):
		triggered = true
		entered_body = node
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 等待一段时间
	await get_tree().create_timer(0.1).timeout

	assert(triggered, "Event should trigger for body in target group")
	assert(entered_body == body1, "Should trigger for correct body")
	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	area.queue_free()
	body1.queue_free()
	body2.queue_free()
	trigger.queue_free()

## 测试只触发一次
func test_trigger_once():
	print("Test 3: Trigger once per body")

	var event = OnArea3DEntered.new()
	var area = Area3D.new()
	area.name = "TestArea"
	add_child(area)

	var collision_shape = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2, 2, 2)
	collision_shape.shape = shape
	area.add_child(collision_shape)

	var body = StaticBody3D.new()
	body.name = "TestBody"
	body.position = Vector3(0, 0, 0)
	add_child(body)

	var body_collision = CollisionShape3D.new()
	var body_shape = BoxShape3D.new()
	body_shape.size = Vector3(1, 1, 1)
	body_collision.shape = body_shape
	body.add_child(body_collision)

	var trigger = Node.new()
	add_child(trigger)

	event.area_node_path = trigger.get_path_to(area)
	event.trigger_once_per_body = true

	var trigger_count = 0
	event.triggered.connect(func(node):
		trigger_count += 1
		print("  Event triggered! Count: %d" % trigger_count)
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 等待一段时间，检查是否只触发一次
	await get_tree().create_timer(0.3).timeout

	assert(trigger_count == 1, "Event should trigger only once per body")
	print("  ✓ Test 3 passed\n")

	event.terminate(trigger)
	area.queue_free()
	body.queue_free()
	trigger.queue_free()

## 测试参数验证
func test_validation():
	print("Test 4: Parameter validation")

	var event = OnArea3DEntered.new()

	# 测试空节点路径
	event.area_node_path = NodePath("")
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for empty node path")
	print("  ✓ Empty node path validation passed")

	print("  ✓ Test 4 passed\n")
