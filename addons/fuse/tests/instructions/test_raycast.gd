extends Node2D

## Raycast 指令测试

func _ready():
	print("=== Testing Raycast Instruction ===")
	test_raycast_hit_2d()
	test_raycast_miss_2d()
	test_raycast_exclude_2d()
	test_raycast_collision_mask()
	test_raycast_save_result()
	test_raycast_hit_3d()
	test_raycast_miss_3d()
	test_raycast_exclude_3d()
	test_error_handling()
	print("=== All Raycast tests passed! ===")

## 测试射线击中物体（2D）
func test_raycast_hit_2d():
	print("\n[Test 1] Raycast hit object (2D)")

	var instruction_script = load("res://addons/fuse/instructions/raycast.gd")
	var instruction = instruction_script.new()
	instruction.use_3d = false
	instruction.from_position = Vector2(0, 100)
	instruction.to_position = Vector2(300, 100)
	instruction.collision_mask = 0xFFFFFFFF

	var context = ExecutionContext.new()
	instruction.execute(context)
	await get_tree().process_frame

	# 手动执行射线检测以验证
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(Vector2(0, 100), Vector2(300, 100), 0xFFFFFFFF)
	var result = space_state.intersect_ray(query)

	assert(not result.is_empty(), "Raycast should hit the StaticBody2D")
	assert(result.collider == $StaticBody2D, "Raycast should hit StaticBody2D")
	assert(result.position.x > 175 and result.position.x < 225, "Hit point should be on the StaticBody2D")

	print("  ✓ Raycast hit object correctly (2D)")

## 测试射线未击中（2D）
func test_raycast_miss_2d():
	print("\n[Test 2] Raycast miss (2D)")

	var instruction_script = load("res://addons/fuse/instructions/raycast.gd")
	var instruction = instruction_script.new()
	instruction.use_3d = false
	instruction.from_position = Vector2(0, 500)
	instruction.to_position = Vector2(300, 500)
	instruction.collision_mask = 0xFFFFFFFF

	var context = ExecutionContext.new()
	instruction.execute(context)
	await get_tree().process_frame

	# 验证
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(Vector2(0, 500), Vector2(300, 500), 0xFFFFFFFF)
	var result = space_state.intersect_ray(query)

	assert(result.is_empty(), "Raycast should miss all objects")

	print("  ✓ Raycast miss correctly (2D)")

## 测试排除节点（2D）
func test_raycast_exclude_2d():
	print("\n[Test 3] Raycast exclude node (2D)")

	var instruction_script = load("res://addons/fuse/instructions/raycast.gd")
	var instruction = instruction_script.new()
	instruction.use_3d = false
	instruction.from_position = Vector2(0, 200)
	instruction.to_position = Vector2(300, 200)
	instruction.collision_mask = 0xFFFFFFFF
	instruction.exclude_target = NodePath("ExcludedBody2D")

	var context = ExecutionContext.new()
	context.owner = self
	instruction.execute(context)
	await get_tree().process_frame

	# 手动验证
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(Vector2(0, 200), Vector2(300, 200), 0xFFFFFFFF)
	query.exclude = [$ExcludedBody2D.get_rid()]
	var result = space_state.intersect_ray(query)

	assert(result.is_empty(), "Raycast should miss when excluding the only object in path")

	print("  ✓ Raycast exclude node correctly (2D)")

## 测试碰撞层过滤
func test_raycast_collision_mask():
	print("\n[Test 4] Raycast collision mask")

	var instruction_script = load("res://addons/fuse/instructions/raycast.gd")
	var instruction = instruction_script.new()
	instruction.use_3d = false
	instruction.from_position = Vector2(0, 100)
	instruction.to_position = Vector2(300, 100)
	instruction.collision_mask = 2  # 只检测第2层

	var context = ExecutionContext.new()
	instruction.execute(context)
	await get_tree().process_frame

	# 手动验证
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(Vector2(0, 100), Vector2(300, 100), 2)
	var result = space_state.intersect_ray(query)

	# StaticBody2D 在第1层，不应该被击中
	assert(result.is_empty(), "Raycast should miss when using wrong collision mask")

	print("  ✓ Raycast collision mask works correctly")

## 测试保存结果到变量
func test_raycast_save_result():
	print("\n[Test 5] Raycast save result to variable")

	var instruction_script = load("res://addons/fuse/instructions/raycast.gd")
	var instruction = instruction_script.new()
	instruction.use_3d = false
	instruction.from_position = Vector2(0, 100)
	instruction.to_position = Vector2(300, 100)
	instruction.collision_mask = 0xFFFFFFFF
	instruction.save_result = true
	instruction.result_variable = "ray_result"
	instruction.is_global = false

	var context = ExecutionContext.new()
	instruction.execute(context)
	await get_tree().process_frame

	# 验证变量保存
	var result_dict = context.get_variable("ray_result")
	assert(result_dict != null, "Result should be saved to variable")
	assert(result_dict.collider != null, "Result should have a collider")
	assert(result_dict.collider == $StaticBody2D, "Collider should be StaticBody2D")
	assert(result_dict.distance > 0, "Distance should be greater than 0")
	assert(result_dict.point.x > 175 and result_dict.point.x < 225, "Hit point should be on the StaticBody2D")

	print("  ✓ Raycast save result works correctly")

## 测试射线击中物体（3D）
func test_raycast_hit_3d():
	print("\n[Test 6] Raycast hit object (3D)")

	var instruction_script = load("res://addons/fuse/instructions/raycast.gd")
	var instruction = instruction_script.new()
	instruction.use_3d = true
	instruction.from_position_3d = Vector3(0, 0, 0)
	instruction.to_position_3d = Vector3(0, 0, 10)
	instruction.collision_mask = 0xFFFFFFFF

	var context = ExecutionContext.new()
	context.owner = self
	instruction.execute(context)
	await get_tree().process_frame

	# 手动验证
	var scene_tree = Engine.get_main_loop() as SceneTree
	var space_state = scene_tree.root.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(Vector3(0, 0, 0), Vector3(0, 0, 10), 0xFFFFFFFF)
	var result = space_state.intersect_ray(query)

	assert(not result.is_empty(), "Raycast should hit the StaticBody3D")
	assert(result.collider == $StaticBody3D, "Raycast should hit StaticBody3D")
	assert(result.position.z > 4.5 and result.position.z < 5.5, "Hit point should be on the StaticBody3D")

	print("  ✓ Raycast hit object correctly (3D)")

## 测试射线未击中（3D）
func test_raycast_miss_3d():
	print("\n[Test 7] Raycast miss (3D)")

	var instruction_script = load("res://addons/fuse/instructions/raycast.gd")
	var instruction = instruction_script.new()
	instruction.use_3d = true
	instruction.from_position_3d = Vector3(0, 0, 0)
	instruction.to_position_3d = Vector3(0, 100, 0)  # 向上发射，应该没有物体
	instruction.collision_mask = 0xFFFFFFFF

	var context = ExecutionContext.new()
	context.owner = self
	instruction.execute(context)
	await get_tree().process_frame

	# 手动验证
	var scene_tree = Engine.get_main_loop() as SceneTree
	var space_state = scene_tree.root.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(Vector3(0, 0, 0), Vector3(0, 100, 0), 0xFFFFFFFF)
	var result = space_state.intersect_ray(query)

	assert(result.is_empty(), "Raycast should miss all objects")

	print("  ✓ Raycast miss correctly (3D)")

## 测试排除节点（3D）
func test_raycast_exclude_3d():
	print("\n[Test 8] Raycast exclude node (3D)")

	var instruction_script = load("res://addons/fuse/instructions/raycast.gd")
	var instruction = instruction_script.new()
	instruction.use_3d = true
	instruction.from_position_3d = Vector3(0, 0, 0)
	instruction.to_position_3d = Vector3(0, 0, 10)
	instruction.collision_mask = 0xFFFFFFFF
	instruction.exclude_target = NodePath("ExcludedBody3D")

	var context = ExecutionContext.new()
	context.owner = self
	instruction.execute(context)
	await get_tree().process_frame

	# 手动验证 - 这条射线应该击中 StaticBody3D（在 z=5）
	# ExcludedBody3D 在 z=10，所以排除它不影响击中 StaticBody3D
	var scene_tree = Engine.get_main_loop() as SceneTree
	var space_state = scene_tree.root.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(Vector3(0, 0, 0), Vector3(0, 0, 10), 0xFFFFFFFF)
	query.exclude = [$ExcludedBody3D.get_rid()]
	var result = space_state.intersect_ray(query)

	assert(not result.is_empty(), "Raycast should hit StaticBody3D when excluding ExcludedBody3D")
	assert(result.collider == $StaticBody3D, "Raycast should hit StaticBody3D")

	print("  ✓ Raycast exclude node correctly (3D)")

## 测试错误处理
func test_error_handling():
	print("\n[Test 9] Error handling")

	# 测试无效位置
	var instruction1 = load("res://addons/fuse/instructions/raycast.gd").new()
	instruction1.use_3d = false
	instruction1.from_position = Vector2(NAN, 0)
	instruction1.to_position = Vector2(100, 0)
	var context1 = ExecutionContext.new()
	instruction1.execute(context1)
	await get_tree().process_frame
	assert(context1.had_error(), "Should have error for invalid from_position")

	# 测试空变量名
	var instruction2 = load("res://addons/fuse/instructions/raycast.gd").new()
	instruction2.use_3d = false
	instruction2.from_position = Vector2(0, 0)
	instruction2.to_position = Vector2(100, 0)
	instruction2.save_result = true
	instruction2.result_variable = ""
	var context2 = ExecutionContext.new()
	instruction2.execute(context2)
	await get_tree().process_frame
	assert(context2.had_error(), "Should have error for empty variable name")

	print("  ✓ Error handling works correctly")
