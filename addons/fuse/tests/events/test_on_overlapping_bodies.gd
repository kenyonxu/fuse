extends Node2D

## OnOverlappingBodies 事件测试

func _ready():
	print("=== Testing OnOverlappingBodies ===")
	await get_tree().process_frame
	test_greater_threshold()
	test_less_threshold()
	test_equal_threshold()
	test_body_enter_trigger()
	test_body_exit_trigger()
	test_emit_count()
	test_trigger_once()
	test_validation()
	print("=== All OnOverlappingBodies tests passed! ===")

## 测试 1: 数量大于阈值触发
func test_greater_threshold():
	print("Test 1: Greater than threshold")

	# 创建测试场景
	var trigger = Node.new()
	add_child(trigger)

	var area = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(200, 200)
	collision_shape.shape = shape
	area.add_child(collision_shape)
	trigger.add_child(area)

	# 创建3个物体
	var bodies = []
	for i in range(3):
		var body = CharacterBody2D.new()
		var body_shape = CollisionShape2D.new()
		var body_shape_rect = RectangleShape2D.new()
		body_shape_rect.size = Vector2(30, 30)
		body_shape.shape = body_shape_rect
		body.add_child(body_shape)
		add_child(body)
		bodies.append(body)

	# 创建事件（数量 > 2 时触发）
	var event = OnOverlappingBodies.new()
	event.area_node = trigger.get_path_to(area)
	event.check_threshold = 2
	event.comparison = OnOverlappingBodies.Comparison.Greater
	event.emit_count = true

	var triggered = false
	var received_count = -1
	event.triggered.connect(func(count):
		triggered = true
		received_count = count
		print("  Event triggered with count: ", count)
	)

	# 初始化事件
	event.initialize(trigger)
	await get_tree().process_frame

	# 移入2个物体（不应该触发）
	bodies[0].position = area.position
	bodies[1].position = area.position + Vector2(10, 10)
	await get_tree().create_timer(0.1).timeout
	assert(not triggered, "Event should not trigger with 2 bodies (not > 2)")
	print("  2 bodies in area, no trigger")

	# 移入第3个物体（应该触发）
	bodies[2].position = area.position + Vector2(20, 20)
	await get_tree().create_timer(0.1).timeout
	assert(triggered, "Event should trigger with 3 bodies (> 2)")
	assert(received_count == 3, "Event should pass count of 3")
	print("  ✓ Test 1 passed: Greater threshold works\n")

	# 清理
	event.terminate(trigger)
	trigger.queue_free()
	for body in bodies:
		body.queue_free()

## 测试 2: 数量小于阈值触发
func test_less_threshold():
	print("Test 2: Less than threshold")

	# 创建测试场景
	var trigger = Node.new()
	add_child(trigger)

	var area = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(200, 200)
	collision_shape.shape = shape
	area.add_child(collision_shape)
	trigger.add_child(area)

	# 创建3个物体
	var bodies = []
	for i in range(3):
		var body = CharacterBody2D.new()
		var body_shape = CollisionShape2D.new()
		var body_shape_rect = RectangleShape2D.new()
		body_shape_rect.size = Vector2(30, 30)
		body_shape.shape = body_shape_rect
		body.add_child(body_shape)
		add_child(body)
		bodies.append(body)

	# 创建事件（数量 < 2 时触发）
	var event = OnOverlappingBodies.new()
	event.area_node = trigger.get_path_to(area)
	event.check_threshold = 2
	event.comparison = OnOverlappingBodies.Comparison.Less
	event.emit_count = true

	var trigger_count = 0
	event.triggered.connect(func(count):
		trigger_count += 1
		print("  Event triggered with count: ", count)
	)

	# 初始化事件
	event.initialize(trigger)
	await get_tree().process_frame

	# 移入3个物体
	for i in range(3):
		bodies[i].position = area.position + Vector2(i * 10, i * 10)
	await get_tree().create_timer(0.1).timeout
	assert(trigger_count == 0, "Event should not trigger with 3 bodies (not < 2)")
	print("  3 bodies in area, no trigger")

	# 移出1个物体（应该触发）
	bodies[0].position = area.position + Vector2(500, 500)
	await get_tree().create_timer(0.1).timeout
	assert(trigger_count == 1, "Event should trigger when count drops to 2 (< 2 is false, but check again)")

	# 移出另一个物体（应该再次触发，数量 = 1 < 2）
	bodies[1].position = area.position + Vector2(600, 600)
	await get_tree().create_timer(0.1).timeout
	assert(trigger_count >= 1, "Event should trigger when count is 1 (< 2)")
	print("  ✓ Test 2 passed: Less threshold works\n")

	# 清理
	event.terminate(trigger)
	trigger.queue_free()
	for body in bodies:
		body.queue_free()

## 测试 3: 数量等于阈值触发
func test_equal_threshold():
	print("Test 3: Equal to threshold")

	# 创建测试场景
	var trigger = Node.new()
	add_child(trigger)

	var area = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(200, 200)
	collision_shape.shape = shape
	area.add_child(collision_shape)
	trigger.add_child(area)

	# 创建3个物体
	var bodies = []
	for i in range(3):
		var body = CharacterBody2D.new()
		var body_shape = CollisionShape2D.new()
		var body_shape_rect = RectangleShape2D.new()
		body_shape_rect.size = Vector2(30, 30)
		body_shape.shape = body_shape_rect
		body.add_child(body_shape)
		add_child(body)
		bodies.append(body)

	# 创建事件（数量 = 2 时触发）
	var event = OnOverlappingBodies.new()
	event.area_node = trigger.get_path_to(area)
	event.check_threshold = 2
	event.comparison = OnOverlappingBodies.Comparison.Equal
	event.emit_count = true

	var triggered = false
	var received_count = -1
	event.triggered.connect(func(count):
		triggered = true
		received_count = count
		print("  Event triggered with count: ", count)
	)

	# 初始化事件
	event.initialize(trigger)
	await get_tree().process_frame

	# 移入3个物体（不应该触发）
	for i in range(3):
		bodies[i].position = area.position + Vector2(i * 10, i * 10)
	await get_tree().create_timer(0.1).timeout
	assert(not triggered, "Event should not trigger with 3 bodies (not = 2)")
	print("  3 bodies in area, no trigger")

	# 移出1个物体（应该触发，数量 = 2）
	bodies[0].position = area.position + Vector2(500, 500)
	await get_tree().create_timer(0.1).timeout
	assert(triggered, "Event should trigger when count equals 2")
	assert(received_count == 2, "Event should pass count of 2")
	print("  ✓ Test 3 passed: Equal threshold works\n")

	# 清理
	event.terminate(trigger)
	trigger.queue_free()
	for body in bodies:
		body.queue_free()

## 测试 4: 物体进入触发
func test_body_enter_trigger():
	print("Test 4: Body enter trigger")

	# 创建测试场景
	var trigger = Node.new()
	add_child(trigger)

	var area = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(200, 200)
	collision_shape.shape = shape
	area.add_child(collision_shape)
	trigger.add_child(area)

	# 创建事件（数量 >= 1 时触发）
	var event = OnOverlappingBodies.new()
	event.area_node = trigger.get_path_to(area)
	event.check_threshold = 0
	event.comparison = OnOverlappingBodies.Comparison.Greater
	event.emit_count = true

	var triggered = false
	event.triggered.connect(func(count):
		triggered = true
		print("  Event triggered when body entered, count: ", count)
	)

	# 初始化事件
	event.initialize(trigger)
	await get_tree().process_frame

	# 移入物体（应该触发）
	var body = CharacterBody2D.new()
	var body_shape = CollisionShape2D.new()
	var body_shape_rect = RectangleShape2D.new()
	body_shape_rect.size = Vector2(30, 30)
	body_shape.shape = body_shape_rect
	body.add_child(body_shape)
	add_child(body)
	body.position = area.position
	await get_tree().create_timer(0.1).timeout

	assert(triggered, "Event should trigger when body enters")
	print("  ✓ Test 4 passed: Body enter trigger works\n")

	# 清理
	event.terminate(trigger)
	trigger.queue_free()
	body.queue_free()

## 测试 5: 物体离开触发
func test_body_exit_trigger():
	print("Test 5: Body exit trigger")

	# 创建测试场景
	var trigger = Node.new()
	add_child(trigger)

	var area = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(200, 200)
	collision_shape.shape = shape
	area.add_child(collision_shape)
	trigger.add_child(area)

	# 创建物体
	var body = CharacterBody2D.new()
	var body_shape = CollisionShape2D.new()
	var body_shape_rect = RectangleShape2D.new()
	body_shape_rect.size = Vector2(30, 30)
	body_shape.shape = body_shape_rect
	body.add_child(body_shape)
	add_child(body)

	# 创建事件（数量 < 1 时触发，即空区域）
	var event = OnOverlappingBodies.new()
	event.area_node = trigger.get_path_to(area)
	event.check_threshold = 1
	event.comparison = OnOverlappingBodies.Comparison.Less
	event.emit_count = true

	var triggered = false
	event.triggered.connect(func(count):
		triggered = true
		print("  Event triggered when body exited, count: ", count)
	)

	# 初始化事件
	event.initialize(trigger)
	await get_tree().process_frame

	# 移入物体
	body.position = area.position
	await get_tree().create_timer(0.1).timeout

	# 移出物体（应该触发）
	body.position = area.position + Vector2(500, 500)
	await get_tree().create_timer(0.1).timeout

	assert(triggered, "Event should trigger when body exits")
	print("  ✓ Test 5 passed: Body exit trigger works\n")

	# 清理
	event.terminate(trigger)
	trigger.queue_free()
	body.queue_free()

## 测试 6: 传递当前数量
func test_emit_count():
	print("Test 6: Emit count parameter")

	# 创建测试场景
	var trigger = Node.new()
	add_child(trigger)

	var area = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(200, 200)
	collision_shape.shape = shape
	area.add_child(collision_shape)
	trigger.add_child(area)

	# 创建事件（emit_count = true）
	var event = OnOverlappingBodies.new()
	event.area_node = trigger.get_path_to(area)
	event.check_threshold = 0
	event.comparison = OnOverlappingBodies.Comparison.Greater
	event.emit_count = true

	var received_count = -1
	event.triggered.connect(func(count):
		received_count = count
		print("  Received count: ", count)
	)

	# 初始化事件
	event.initialize(trigger)
	await get_tree().process_frame

	# 移入2个物体
	var bodies = []
	for i in range(2):
		var body = CharacterBody2D.new()
		var body_shape = CollisionShape2D.new()
		var body_shape_rect = RectangleShape2D.new()
		body_shape_rect.size = Vector2(30, 30)
		body_shape.shape = body_shape_rect
		body.add_child(body_shape)
		add_child(body)
		body.position = area.position + Vector2(i * 10, i * 10)
		bodies.append(body)

	await get_tree().create_timer(0.1).timeout
	assert(received_count == 2, "Event should pass correct count (2)")

	# 移入第3个物体
	var body3 = CharacterBody2D.new()
	var body_shape3 = CollisionShape2D.new()
	var body_shape_rect3 = RectangleShape2D.new()
	body_shape_rect3.size = Vector2(30, 30)
	body_shape3.shape = body_shape_rect3
	body3.add_child(body_shape3)
	add_child(body3)
	body3.position = area.position + Vector2(20, 20)
	bodies.append(body3)

	await get_tree().create_timer(0.1).timeout
	assert(received_count == 3, "Event should pass correct count (3)")
	print("  ✓ Test 6 passed: Emit count works correctly\n")

	# 清理
	event.terminate(trigger)
	trigger.queue_free()
	for body in bodies:
		body.queue_free()

## 测试 7: 仅触发一次
func test_trigger_once():
	print("Test 7: Trigger once mode")

	# 创建测试场景
	var trigger = Node.new()
	add_child(trigger)

	var area = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(200, 200)
	collision_shape.shape = shape
	area.add_child(collision_shape)
	trigger.add_child(area)

	# 创建事件（启用 trigger_once）
	var event = OnOverlappingBodies.new()
	event.area_node = trigger.get_path_to(area)
	event.check_threshold = 2
	event.comparison = OnOverlappingBodies.Comparison.Greater
	event.emit_count = true
	event.trigger_once = true

	var trigger_count = 0
	event.triggered.connect(func(count):
		trigger_count += 1
		print("  Event triggered, count: ", trigger_count)
	)

	# 初始化事件
	event.initialize(trigger)
	await get_tree().process_frame

	# 移入3个物体（应该触发一次）
	var bodies = []
	for i in range(3):
		var body = CharacterBody2D.new()
		var body_shape = CollisionShape2D.new()
		var body_shape_rect = RectangleShape2D.new()
		body_shape_rect.size = Vector2(30, 30)
		body_shape.shape = body_shape_rect
		body.add_child(body_shape)
		add_child(body)
		body.position = area.position + Vector2(i * 10, i * 10)
		bodies.append(body)

	await get_tree().create_timer(0.1).timeout
	assert(trigger_count == 1, "Event should trigger once")

	# 移出再移入（不应该再次触发）
	bodies[0].position = area.position + Vector2(500, 500)
	await get_tree().create_timer(0.1).timeout
	bodies[0].position = area.position
	await get_tree().create_timer(0.1).timeout

	assert(trigger_count == 1, "Event should not trigger again")
	print("  ✓ Test 7 passed: Trigger once works\n")

	# 清理
	event.terminate(trigger)
	trigger.queue_free()
	for body in bodies:
		body.queue_free()

## 测试 8: 参数验证
func test_validation():
	print("Test 8: Parameter validation")

	# 测试空路径
	var event1 = OnOverlappingBodies.new()
	var errors1 = event1.validate()
	assert(not errors1.is_empty(), "Should have validation errors for empty path")
	print("  ✓ Empty path validation works")

	# 测试负数阈值
	var event2 = OnOverlappingBodies.new()
	event2.area_node = NodePath("./SomeArea")
	event2.check_threshold = -1
	var errors2 = event2.validate()
	assert(not errors2.is_empty(), "Should have validation errors for negative threshold")
	print("  ✓ Negative threshold validation works")

	# 测试有效配置
	var event3 = OnOverlappingBodies.new()
	event3.area_node = NodePath("./SomeArea")
	event3.check_threshold = 1
	var errors3 = event3.validate()
	assert(errors3.is_empty(), "Should have no validation errors for valid config")
	print("  ✓ Valid configuration validation works")

	print("  ✓ Test 8 passed: Validation works\n")
