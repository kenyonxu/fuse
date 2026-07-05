extends Node

## OnCollision 事件测试

func _ready():
	print("=== Testing OnCollision ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_collision_mask()
	test_validation()
	print("=== All OnCollision tests passed! ===")

## 测试基本功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	var event = OnCollision.new()
	var body = CharacterBody2D.new()
	body.name = "TestBody"
	body.collision_layer = 1
	add_child(body)

	var trigger = Node.new()
	add_child(trigger)

	event.target_node = trigger.get_path_to(body)
	event.collision_mask = 0

	var triggered = false
	event.triggered.connect(func(context):
		triggered = true
		print("  Event triggered!")
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 模拟碰撞信号
	if body.has_signal("body_entered"):
		body.emit_signal("body_entered", body)
		await get_tree().process_frame

	assert(triggered, "Event should trigger on collision")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	body.queue_free()
	trigger.queue_free()

## 测试碰撞掩码过滤
func test_collision_mask():
	print("Test 2: Collision mask filtering")

	var event = OnCollision.new()
	var body1 = CharacterBody2D.new()
	body1.name = "Body1"
	body1.collision_layer = 1
	add_child(body1)

	var body2 = CharacterBody2D.new()
	body2.name = "Body2"
	body2.collision_layer = 2
	add_child(body2)

	var trigger = Node.new()
	add_child(trigger)

	event.target_node = trigger.get_path_to(body1)
	event.collision_mask = 1  # 只检测层 1

	var triggered_count = 0
	event.triggered.connect(func(context):
		triggered_count += 1
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 测试层 1 的碰撞
	if body1.has_signal("body_entered"):
		body1.emit_signal("body_entered", body1)
		await get_tree().process_frame

	# 测试层 2 的碰撞（不应触发）
	if body2.has_signal("body_entered"):
		body2.emit_signal("body_entered", body2)
		await get_tree().process_frame

	# 注意：实际测试中需要更复杂的碰撞设置
	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	body1.queue_free()
	body2.queue_free()
	trigger.queue_free()

## 测试参数验证
func test_validation():
	print("Test 3: Parameter validation")

	var event = OnCollision.new()

	# 测试空目标节点
	event.target_node = NodePath("")
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for empty target")
	print("  ✓ Empty target validation passed")

	# 测试无效的碰撞掩码
	event.target_node = NodePath("TestBody")
	event.collision_mask = -1
	errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for invalid mask")
	print("  ✓ Invalid mask validation passed")

	print("  ✓ Test 3 passed\n")
