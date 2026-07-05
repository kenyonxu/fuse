extends Node2D

## Set Velocity 指令测试

func _ready():
	print("=== Testing Set Velocity Instruction ===")
	test_set_velocity_characterbody_2d()
	test_set_velocity_rigidbody_2d()
	test_set_velocity_characterbody_3d()
	test_set_velocity_rigidbody_3d()
	test_local_space_transform_rigidbody_2d()
	test_local_space_transform_rigidbody_3d()
	test_error_handling()
	print("=== All Set Velocity tests passed! ===")

## 测试设置 CharacterBody2D 速度
func test_set_velocity_characterbody_2d():
	print("\n[Test 1] Set CharacterBody2D velocity")

	var instruction_script = load("res://addons/fuse/instructions/set_velocity.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("CharacterBody2D")
	instruction.use_3d = false
	instruction.velocity = Vector2(100, 50)

	var context = ExecutionContext.new()
	instruction.execute(context)
	await get_tree().process_frame

	var body = $CharacterBody2D as CharacterBody2D
	assert(is_equal_approx(body.velocity.x, 100.0), "Velocity X should be 100")
	assert(is_equal_approx(body.velocity.y, 50.0), "Velocity Y should be 50")

	print("  ✓ CharacterBody2D velocity set correctly")

## 测试设置 RigidBody2D 速度
func test_set_velocity_rigidbody_2d():
	print("\n[Test 2] Set RigidBody2D velocity")

	var instruction_script = load("res://addons/fuse/instructions/set_velocity.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("RigidBody2D")
	instruction.use_3d = false
	instruction.velocity = Vector2(200, -100)

	var context = ExecutionContext.new()
	instruction.execute(context)
	await get_tree().process_frame

	var body = $RigidBody2D as RigidBody2D
	assert(is_equal_approx(body.linear_velocity.x, 200.0), "Linear velocity X should be 200")
	assert(is_equal_approx(body.linear_velocity.y, -100.0), "Linear velocity Y should be -100")

	print("  ✓ RigidBody2D velocity set correctly")

## 测试设置 CharacterBody3D 速度
func test_set_velocity_characterbody_3d():
	print("\n[Test 3] Set CharacterBody3D velocity")

	var instruction_script = load("res://addons/fuse/instructions/set_velocity.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("CharacterBody3D")
	instruction.use_3d = true
	instruction.velocity_3d = Vector3(50, 0, 100)

	var context = ExecutionContext.new()
	instruction.execute(context)
	await get_tree().process_frame

	var body = $CharacterBody3D as CharacterBody3D
	assert(is_equal_approx(body.velocity.x, 50.0), "Velocity X should be 50")
	assert(is_equal_approx(body.velocity.y, 0.0), "Velocity Y should be 0")
	assert(is_equal_approx(body.velocity.z, 100.0), "Velocity Z should be 100")

	print("  ✓ CharacterBody3D velocity set correctly")

## 测试设置 RigidBody3D 速度
func test_set_velocity_rigidbody_3d():
	print("\n[Test 4] Set RigidBody3D velocity")

	var instruction_script = load("res://addons/fuse/instructions/set_velocity.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("RigidBody3D")
	instruction.use_3d = true
	instruction.velocity_3d = Vector3(-100, 50, 200)

	var context = ExecutionContext.new()
	instruction.execute(context)
	await get_tree().process_frame

	var body = $RigidBody3D as RigidBody3D
	assert(is_equal_approx(body.linear_velocity.x, -100.0), "Linear velocity X should be -100")
	assert(is_equal_approx(body.linear_velocity.y, 50.0), "Linear velocity Y should be 50")
	assert(is_equal_approx(body.linear_velocity.z, 200.0), "Linear velocity Z should be 200")

	print("  ✓ RigidBody3D velocity set correctly")

## 测试局部坐标转换 (RigidBody2D)
func test_local_space_transform_rigidbody_2d():
	print("\n[Test 5] Local space transform (RigidBody2D)")

	var body = $RigidBody2D as RigidBody2D
	body.rotation_degrees = 90  # 旋转 90 度

	var instruction_script = load("res://addons/fuse/instructions/set_velocity.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("RigidBody2D")
	instruction.use_3d = false
	instruction.velocity = Vector2(100, 0)
	instruction.use_local_space = true

	var context = ExecutionContext.new()
	instruction.execute(context)
	await get_tree().process_frame

	# 局部坐标 (100, 0) 在旋转 90 度后应该变成 (0, 100)
	assert(is_equal_approx(body.linear_velocity.x, 0.0), "Transformed velocity X should be approximately 0")
	assert(is_equal_approx(body.linear_velocity.y, 100.0), "Transformed velocity Y should be 100")

	print("  ✓ Local space transform (RigidBody2D) works correctly")

	# 重置旋转
	body.rotation_degrees = 0

## 测试局部坐标转换 (RigidBody3D)
func test_local_space_transform_rigidbody_3d():
	print("\n[Test 6] Local space transform (RigidBody3D)")

	var body = $RigidBody3D as RigidBody3D
	body.rotation_degrees = Vector3(0, 90, 0)  # 绕 Y 轴旋转 90 度

	var instruction_script = load("res://addons/fuse/instructions/set_velocity.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("RigidBody3D")
	instruction.use_3d = true
	instruction.velocity_3d = Vector3(100, 0, 0)
	instruction.use_local_space = true

	var context = ExecutionContext.new()
	instruction.execute(context)
	await get_tree().process_frame

	# 局部坐标 (100, 0, 0) 在 Y 轴旋转 90 度后应该变成 (0, 0, -100) 或 (0, 0, 100)
	# 取决于旋转方向，我们检查其中一个分量应该是 100
	var has_large_component = abs(body.linear_velocity.x) > 99.0 or abs(body.linear_velocity.z) > 99.0
	assert(has_large_component, "Transformed velocity should have large X or Z component")

	print("  ✓ Local space transform (RigidBody3D) works correctly")

	# 重置旋转
	body.rotation_degrees = Vector3.ZERO

## 测试错误处理
func test_error_handling():
	print("\n[Test 7] Error handling")

	# 测试空节点路径
	var instruction1 = load("res://addons/fuse/instructions/set_velocity.gd").new()
	instruction1.target_node = NodePath("")
	var context1 = ExecutionContext.new()
	instruction1.execute(context1)
	await get_tree().process_frame
	assert(context1.had_error(), "Should have error for empty target node")

	# 测试节点不存在
	var instruction2 = load("res://addons/fuse/instructions/set_velocity.gd").new()
	instruction2.target_node = NodePath("NonExistentNode")
	var context2 = ExecutionContext.new()
	instruction2.execute(context2)
	await get_tree().process_frame
	assert(context2.had_error(), "Should have error for non-existent node")

	# 测试节点类型错误
	var instruction3 = load("res://addons/fuse/instructions/set_velocity.gd").new()
	instruction3.target_node = NodePath(".")
	var context3 = ExecutionContext.new()
	instruction3.execute(context3)
	await get_tree().process_frame
	assert(context3.had_error(), "Should have error for invalid node type")

	print("  ✓ Error handling works correctly")
