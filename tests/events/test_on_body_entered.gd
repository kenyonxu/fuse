extends Node

## OnBodyEntered 事件测试

func _ready():
	print("=== Testing OnBodyEntered ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_group_filtering()
	test_trigger_once()
	test_validation()
	print("=== All OnBodyEntered tests passed! ===")

## 测试基本功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	var event = OnBodyEntered.new()
	var area = Area2D.new()
	area.name = "TestArea"
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(100, 100)
	collision.shape = shape
	area.add_child(collision)
	add_child(area)

	var body = CharacterBody2D.new()
	body.name = "TestBody"
	body.position = Vector2(0, 0)
	add_child(body)

	var trigger = Node.new()
	add_child(trigger)

	event.area_node = trigger.get_path_to(area)
	event.target_group = ""

	var triggered = false
	event.triggered.connect(func(node):
		triggered = true
		print("  Event triggered! Body: %s" % node.name)
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 模拟物体进入区域
	area.emit_signal("body_entered", body)
	await get_tree().process_frame

	assert(triggered, "Event should trigger when body enters area")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	area.queue_free()
	body.queue_free()
	trigger.queue_free()

## 测试组过滤
func test_group_filtering():
	print("Test 2: Group filtering")

	var event = OnBodyEntered.new()
	var area = Area2D.new()
	area.name = "TestArea"
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(100, 100)
	collision.shape = shape
	area.add_child(collision)
	add_child(area)

	var body1 = CharacterBody2D.new()
	body1.name = "Player"
	body1.add_to_group("player")
	add_child(body1)

	var body2 = CharacterBody2D.new()
	body2.name = "Enemy"
	body2.add_to_group("enemy")
	add_child(body2)

	var trigger = Node.new()
	add_child(trigger)

	event.area_node = trigger.get_path_to(area)
	event.target_group = "player"

	var triggered_count = 0
	event.triggered.connect(func(node):
		triggered_count += 1
		print("  Event triggered! Body: %s" % node.name)
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 测试玩家进入
	area.emit_signal("body_entered", body1)
	await get_tree().process_frame
	assert(triggered_count == 1, "Event should trigger for player group")

	# 测试敌人进入（不应触发）
	area.emit_signal("body_entered", body2)
	await get_tree().process_frame
	assert(triggered_count == 1, "Event should not trigger for non-player group")

	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	area.queue_free()
	body1.queue_free()
	body2.queue_free()
	trigger.queue_free()

## 测试单次触发
func test_trigger_once():
	print("Test 3: Trigger once")

	var event = OnBodyEntered.new()
	var area = Area2D.new()
	area.name = "TestArea"
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(100, 100)
	collision.shape = shape
	area.add_child(collision)
	add_child(area)

	var body = CharacterBody2D.new()
	body.name = "TestBody"
	add_child(body)

	var trigger = Node.new()
	add_child(trigger)

	event.area_node = trigger.get_path_to(area)
	event.trigger_once = true

	var triggered_count = 0
	event.triggered.connect(func(node):
		triggered_count += 1
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 第一次触发
	area.emit_signal("body_entered", body)
	await get_tree().process_frame
	assert(triggered_count == 1, "Event should trigger first time")

	# 第二次触发（应被忽略）
	area.emit_signal("body_entered", body)
	await get_tree().process_frame
	assert(triggered_count == 1, "Event should not trigger second time")

	print("  ✓ Test 3 passed\n")

	event.terminate(trigger)
	area.queue_free()
	body.queue_free()
	trigger.queue_free()

## 测试参数验证
func test_validation():
	print("Test 4: Parameter validation")

	var event = OnBodyEntered.new()

	# 测试空目标节点
	event.area_node = NodePath("")
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for empty target")
	print("  ✓ Empty target validation passed")

	print("  ✓ Test 4 passed\n")
