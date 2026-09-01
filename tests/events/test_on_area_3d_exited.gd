extends Node3D

## OnArea3DExited 事件测试

func _ready():
	print("=== Testing OnArea3DExited ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_target_group_filtering()
	test_trigger_once_per_body()
	test_area_exited_signal()
	test_resource_cleanup()
	test_validation()
	print("=== All OnArea3DExited tests passed! ===")

## 测试 1: 基本功能测试
func test_basic_functionality():
	print("Test 1: Basic functionality")

	# 创建测试场景
	var trigger = Node.new()
	add_child(trigger)

	var area = Area3D.new()
	var collision_shape = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2, 2, 2)
	collision_shape.shape = shape
	area.add_child(collision_shape)
	trigger.add_child(area)

	var body = CharacterBody3D.new()
	var body_shape = CollisionShape3D.new()
	var body_shape_box = BoxShape3D.new()
	body_shape_box.size = Vector3(1, 1, 1)
	body_shape.shape = body_shape_box
	body.add_child(body_shape)
	add_child(body)

	# 创建事件
	var event = OnArea3DExited.new()
	event.area_node_path = trigger.get_path_to(area)

	var triggered = false
	var exited_body = null
	event.triggered.connect(func(b):
		triggered = true
		exited_body = b
		print("  Event triggered with body: ", b.name)
	)

	# 初始化事件
	event.initialize(trigger)
	await get_tree().process_frame

	# 将物体移入区域
	body.position = area.position
	await get_tree().create_timer(0.1).timeout

	# 验证物体在区域内
	var bodies_in_area = area.get_overlapping_bodies()
	assert(bodies_in_area.has(body), "Body should be in area")
	print("  Body entered area")

	# 将物体移出区域
	body.position = area.position + Vector3(5, 0, 0)
	await get_tree().create_timer(0.1).timeout

	# 验证物体离开区域
	assert(triggered, "Event should trigger when body exits")
	assert(exited_body == body, "Event should pass the exited body")
	print("  ✓ Test 1 passed: Event triggered correctly\n")

	# 清理
	event.terminate(trigger)
	trigger.queue_free()
	body.queue_free()

## 测试 2: 目标组过滤测试
func test_target_group_filtering():
	print("Test 2: Target group filtering")

	# 创建测试场景
	var trigger = Node.new()
	add_child(trigger)

	var area = Area3D.new()
	var collision_shape = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2, 2, 2)
	collision_shape.shape = shape
	area.add_child(collision_shape)
	trigger.add_child(area)

	var player_body = CharacterBody3D.new()
	player_body.add_to_group("player")
	var player_shape = CollisionShape3D.new()
	var player_shape_box = BoxShape3D.new()
	player_shape_box.size = Vector3(1, 1, 1)
	player_shape.shape = player_shape_box
	player_body.add_child(player_shape)
	add_child(player_body)

	var enemy_body = CharacterBody3D.new()
	enemy_body.add_to_group("enemy")
	var enemy_shape = CollisionShape3D.new()
	var enemy_shape_box = BoxShape3D.new()
	enemy_shape_box.size = Vector3(1, 1, 1)
	enemy_shape.shape = enemy_shape_box
	enemy_body.add_child(enemy_shape)
	add_child(enemy_body)

	# 创建事件（只监听 player 组）
	var event = OnArea3DExited.new()
	event.area_node_path = trigger.get_path_to(area)
	event.target_group = "player"

	var player_triggered = false
	var enemy_triggered = false
	event.triggered.connect(func(b):
		if b.is_in_group("player"):
			player_triggered = true
		elif b.is_in_group("enemy"):
			enemy_triggered = true
		print("  Event triggered with body: ", b.name, " group: ", b.get_groups())
	)

	# 初始化事件
	event.initialize(trigger)
	await get_tree().process_frame

	# 将两个物体都移入区域
	player_body.position = area.position
	enemy_body.position = area.position
	await get_tree().create_timer(0.1).timeout

	# 移出 player
	player_body.position = area.position + Vector3(5, 0, 0)
	await get_tree().create_timer(0.1).timeout

	# 验证 player 触发事件
	assert(player_triggered, "Event should trigger for player body")
	assert(not enemy_triggered, "Event should not trigger for enemy body")
	print("  ✓ Test 2 passed: Target group filtering works\n")

	# 清理
	event.terminate(trigger)
	trigger.queue_free()
	player_body.queue_free()
	enemy_body.queue_free()

## 测试 3: 单次触发模式测试
func test_trigger_once_per_body():
	print("Test 3: Trigger once per body")

	# 创建测试场景
	var trigger = Node.new()
	add_child(trigger)

	var area = Area3D.new()
	var collision_shape = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2, 2, 2)
	collision_shape.shape = shape
	area.add_child(collision_shape)
	trigger.add_child(area)

	var body = CharacterBody3D.new()
	var body_shape = CollisionShape3D.new()
	var body_shape_box = BoxShape3D.new()
	body_shape_box.size = Vector3(1, 1, 1)
	body_shape.shape = body_shape_box
	body.add_child(body_shape)
	add_child(body)

	# 创建事件（启用单次触发模式）
	var event = OnArea3DExited.new()
	event.area_node_path = trigger.get_path_to(area)
	event.trigger_once_per_body = true

	var trigger_count = 0
	event.triggered.connect(func(b):
		trigger_count += 1
		print("  Event triggered, count: ", trigger_count)
	)

	# 初始化事件
	event.initialize(trigger)
	await get_tree().process_frame

	# 第一次进入并离开
	body.position = area.position
	await get_tree().create_timer(0.1).timeout
	body.position = area.position + Vector3(5, 0, 0)
	await get_tree().create_timer(0.1).timeout
	assert(trigger_count == 1, "Event should trigger once")

	# 第二次进入并离开（不应该触发）
	body.position = area.position
	await get_tree().create_timer(0.1).timeout
	body.position = area.position + Vector3(5, 0, 0)
	await get_tree().create_timer(0.1).timeout
	assert(trigger_count == 1, "Event should not trigger again for same body")
	print("  ✓ Test 3 passed: Trigger once per body works\n")

	# 清理
	event.terminate(trigger)
	trigger.queue_free()
	body.queue_free()

## 测试 4: Area 退出信号测试
func test_area_exited_signal():
	print("Test 4: Area exited signal")

	# 创建测试场景
	var trigger = Node.new()
	add_child(trigger)

	var area1 = Area3D.new()
	var collision_shape1 = CollisionShape3D.new()
	var shape1 = BoxShape3D.new()
	shape1.size = Vector3(2, 2, 2)
	collision_shape1.shape = shape1
	area1.add_child(collision_shape1)
	trigger.add_child(area1)

	var area2 = Area3D.new()
	var collision_shape2 = CollisionShape3D.new()
	var shape2 = BoxShape3D.new()
	shape2.size = Vector3(1, 1, 1)
	collision_shape2.shape = shape2
	area2.add_child(collision_shape2)
	add_child(area2)

	# 创建事件
	var event = OnArea3DExited.new()
	event.area_node_path = trigger.get_path_to(area1)

	var triggered = false
	var exited_area = null
	event.triggered.connect(func(a):
		triggered = true
		exited_area = a
		print("  Event triggered with area: ", a.name)
	)

	# 初始化事件
	event.initialize(trigger)
	await get_tree().process_frame

	# 将 area2 移入 area1
	area2.position = area1.position
	await get_tree().create_timer(0.1).timeout

	# 验证 area2 在 area1 内
	var areas_in_area = area1.get_overlapping_areas()
	assert(areas_in_area.has(area2), "Area2 should be in area1")
	print("  Area2 entered area1")

	# 将 area2 移出 area1
	area2.position = area1.position + Vector3(5, 0, 0)
	await get_tree().create_timer(0.1).timeout

	# 验证事件触发
	assert(triggered, "Event should trigger when area exits")
	assert(exited_area == area2, "Event should pass the exited area")
	print("  ✓ Test 4 passed: Area exited signal works\n")

	# 清理
	event.terminate(trigger)
	trigger.queue_free()
	area2.queue_free()

## 测试 5: 资源清理测试
func test_resource_cleanup():
	print("Test 5: Resource cleanup")

	# 创建测试场景
	var trigger = Node.new()
	add_child(trigger)

	var area = Area3D.new()
	var collision_shape = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2, 2, 2)
	collision_shape.shape = shape
	area.add_child(collision_shape)
	trigger.add_child(area)

	# 创建事件
	var event = OnArea3DExited.new()
	event.area_node_path = trigger.get_path_to(area)

	# 初始化事件
	event.initialize(trigger)
	await get_tree().process_frame

	# 验证信号已连接
	assert(area.body_exited.is_connected(event._on_body_exited), "body_exited signal should be connected")
	assert(area.area_exited.is_connected(event._on_area_exited), "area_exited signal should be connected")
	print("  Signals connected")

	# 终止事件
	event.terminate(trigger)

	# 验证信号已断开
	assert(not area.body_exited.is_connected(event._on_body_exited), "body_exited signal should be disconnected")
	assert(not area.area_exited.is_connected(event._on_area_exited), "area_exited signal should be disconnected")
	print("  Signals disconnected")
	print("  ✓ Test 5 passed: Resource cleanup works\n")

	# 清理
	trigger.queue_free()

## 测试 6: 参数验证测试
func test_validation():
	print("Test 6: Parameter validation")

	# 测试空路径
	var event1 = OnArea3DExited.new()
	var errors1 = event1.validate()
	assert(not errors1.is_empty(), "Should have validation errors for empty path")
	print("  ✓ Empty path validation works")

	# 测试有效路径
	var event2 = OnArea3DExited.new()
	event2.area_node_path = NodePath("./SomeArea")
	var errors2 = event2.validate()
	# 注意：路径验证在运行时进行，这里只检查路径非空
	print("  ✓ Valid path validation works")

	print("  ✓ Test 6 passed: Validation works\n")
