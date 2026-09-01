extends Node2D

## Apply Impulse 指令测试

func _ready():
	print("=== Testing Apply Impulse Instruction ===")
	test_central_impulse_2d()
	test_central_impulse_3d()
	test_offset_impulse_2d()
	test_offset_impulse_3d()
	test_error_handling()
	print("=== All Apply Impulse tests passed! ===")

## 测试 2D 中心冲量
func test_central_impulse_2d():
	print("\n[Test 1] 2D Central Impulse")

	var instruction_script = load("res://addons/fuse/instructions/apply_impulse.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("RigidBody2D")
	instruction.use_3d = false
	instruction.use_center = true
	instruction.impulse = Vector2(100, 0)

	var context = ExecutionContext.new()

	# 获取 RigidBody2D 节点
	var body = $RigidBody2D as RigidBody2D

	# 执行前记录状态
	var initial_velocity = body.linear_velocity

	# 执行指令
	instruction.execute(context)
	await get_tree().process_frame

	# 验证：速度应该改变（因为冲量会改变速度）
	assert(context.had_error() == false, "Should not have error")
	assert(is_equal_approx(body.linear_velocity.x, initial_velocity.x + 100), "Velocity should increase by impulse")
	assert(is_equal_approx(body.linear_velocity.y, 0), "Y velocity should remain 0")

	print("  ✓ 2D central impulse applied correctly")

## 测试 3D 中心冲量
func test_central_impulse_3d():
	print("\n[Test 2] 3D Central Impulse")

	var instruction_script = load("res://addons/fuse/instructions/apply_impulse.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("RigidBody3D")
	instruction.use_3d = true
	instruction.use_center = true
	instruction.impulse_3d = Vector3(0, 0, 100)

	var context = ExecutionContext.new()

	# 获取 RigidBody3D 节点
	var body = $RigidBody3D as RigidBody3D

	# 执行前记录状态
	var initial_velocity = body.linear_velocity

	# 执行指令
	instruction.execute(context)
	await get_tree().process_frame

	# 验证：速度应该改变
	assert(context.had_error() == false, "Should not have error")
	assert(is_equal_approx(body.linear_velocity.z, initial_velocity.z + 100), "Z velocity should increase by impulse")

	print("  ✓ 3D central impulse applied correctly")

## 测试 2D 偏心冲量（产生旋转）
func test_offset_impulse_2d():
	print("\n[Test 3] 2D Offset Impulse (produces rotation)")

	var instruction_script = load("res://addons/fuse/instructions/apply_impulse.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("RigidBody2D")
	instruction.use_3d = false
	instruction.use_center = false
	instruction.impulse = Vector2(0, 100)
	instruction.impulse_position = Vector2(25, 0)  # 偏心施力

	var context = ExecutionContext.new()

	# 获取 RigidBody2D 节点
	var body = $RigidBody2D as RigidBody2D

	# 重置物理状态
	body.linear_velocity = Vector2.ZERO
	body.angular_velocity = 0

	# 执行指令
	instruction.execute(context)
	await get_tree().process_frame

	# 验证：偏心冲量应该产生旋转
	assert(context.had_error() == false, "Should not have error")
	assert(body.angular_velocity != 0, "Angular velocity should be non-zero due to offset impulse")

	print("  ✓ 2D offset impulse produces rotation")

## 测试 3D 偏心冲量（产生旋转）
func test_offset_impulse_3d():
	print("\n[Test 4] 3D Offset Impulse (produces rotation)")

	var instruction_script = load("res://addons/fuse/instructions/apply_impulse.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("RigidBody3D_Capsule")
	instruction.use_3d = true
	instruction.use_center = false
	instruction.impulse_3d = Vector3(100, 0, 0)
	instruction.impulse_position_3d = Vector3(0, 0.5, 0)  # 偏心施力

	var context = ExecutionContext.new()

	# 获取 RigidBody3D 节点
	var body = $RigidBody3D_Capsule as RigidBody3D

	# 重置物理状态
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO

	# 执行指令
	instruction.execute(context)
	await get_tree().process_frame

	# 验证：偏心冲量应该产生旋转
	assert(context.had_error() == false, "Should not have error")
	# 3D 旋转是向量，检查是否不为零
	assert(body.angular_velocity.length() > 0, "Angular velocity should be non-zero due to offset impulse")

	print("  ✓ 3D offset impulse produces rotation")

## 测试错误处理
func test_error_handling():
	print("\n[Test 5] Error Handling")

	# 测试 1: 空目标节点
	print("  5.1: Empty target node")
	var instruction1 = load("res://addons/fuse/instructions/apply_impulse.gd").new()
	instruction1.target_node = NodePath("")
	var context1 = ExecutionContext.new()
	instruction1.execute(context1)
	await get_tree().process_frame
	assert(context1.had_error(), "Should have error for empty target node")

	# 测试 2: 节点不存在
	print("  5.2: Node not found")
	var instruction2 = load("res://addons/fuse/instructions/apply_impulse.gd").new()
	instruction2.target_node = NodePath("NonExistentNode")
	var context2 = ExecutionContext.new()
	instruction2.execute(context2)
	await get_tree().process_frame
	assert(context2.had_error(), "Should have error for non-existent node")

	# 测试 3: 节点类型错误（CharacterBody2D 不是 RigidBody）
	print("  5.3: Invalid node type (CharacterBody2D)")
	var instruction3 = load("res://addons/fuse/instructions/apply_impulse.gd").new()
	instruction3.target_node = NodePath("CharacterBody2D")
	var context3 = ExecutionContext.new()
	instruction3.execute(context3)
	await get_tree().process_frame
	assert(context3.had_error(), "Should have error for invalid node type")

	print("  ✓ Error handling works correctly")
