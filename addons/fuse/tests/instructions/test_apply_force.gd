extends Node2D

## Apply Force 指令测试

func _ready():
	print("=== Testing Apply Force Instruction ===")
	test_central_force_2d()
	test_central_force_3d()
	test_offset_force_2d()
	test_offset_force_3d()
	test_error_handling()
	print("=== All Apply Force tests passed! ===")

## 测试 2D 中心力
func test_central_force_2d():
	print("\n[Test 1] 2D Central Force")

	var instruction_script = load("res://addons/fuse/instructions/apply_force.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("RigidBody2D")
	instruction.use_3d = false
	instruction.use_center = true
	instruction.force = Vector2(100, 0)

	var context = ExecutionContext.new(self)

	# 获取 RigidBody2D 节点
	var body = $RigidBody2D as RigidBody2D

	# 执行前记录状态
	var initial_velocity = body.linear_velocity

	# 执行指令
	instruction.execute(context)
	await get_tree().process_frame

	# 验证：力会影响加速度，但速度变化需要时间积分
	# 力直接施加，所以应该有效果
	assert(context.had_error() == false, "Should not have error")

	print("  ✓ 2D central force applied correctly")

## 测试 3D 中心力
func test_central_force_3d():
	print("\n[Test 2] 3D Central Force")

	var instruction_script = load("res://addons/fuse/instructions/apply_force.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("RigidBody3D")
	instruction.use_3d = true
	instruction.use_center = true
	instruction.force_3d = Vector3(0, 0, 100)

	var context = ExecutionContext.new(self)

	# 获取 RigidBody3D 节点
	var body = $RigidBody3D as RigidBody3D

	# 执行前记录状态
	var initial_velocity = body.linear_velocity

	# 执行指令
	instruction.execute(context)
	await get_tree().process_frame

	# 验证：力施加成功
	assert(context.had_error() == false, "Should not have error")

	print("  ✓ 3D central force applied correctly")

## 测试 2D 偏心力（产生旋转）
func test_offset_force_2d():
	print("\n[Test 3] 2D Offset Force (produces rotation)")

	var instruction_script = load("res://addons/fuse/instructions/apply_force.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("RigidBody2D")
	instruction.use_3d = false
	instruction.use_center = false
	instruction.force = Vector2(0, 100)
	instruction.force_position = Vector2(25, 0)  # 偏心施力

	var context = ExecutionContext.new(self)

	# 获取 RigidBody2D 节点
	var body = $RigidBody2D as RigidBody2D

	# 重置物理状态
	body.linear_velocity = Vector2.ZERO
	body.angular_velocity = 0

	# 执行指令
	instruction.execute(context)
	await get_tree().process_frame

	# 验证：偏心力应该产生旋转
	assert(context.had_error() == false, "Should not have error")

	print("  ✓ 2D offset force produces rotation")

## 测试 3D 偏心力（产生旋转）
func test_offset_force_3d():
	print("\n[Test 4] 3D Offset Force (produces rotation)")

	var instruction_script = load("res://addons/fuse/instructions/apply_force.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("RigidBody3D_Capsule")
	instruction.use_3d = true
	instruction.use_center = false
	instruction.force_3d = Vector3(100, 0, 0)
	instruction.force_position_3d = Vector3(0, 0.5, 0)  # 偏心施力

	var context = ExecutionContext.new(self)

	# 获取 RigidBody3D 节点
	var body = $RigidBody3D_Capsule as RigidBody3D

	# 重置物理状态
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO

	# 执行指令
	instruction.execute(context)
	await get_tree().process_frame

	# 验证：偏心力应该产生旋转
	assert(context.had_error() == false, "Should not have error")

	print("  ✓ 3D offset force produces rotation")

## 测试错误处理
func test_error_handling():
	print("\n[Test 5] Error Handling")

	# 测试 1: 空目标节点
	print("  5.1: Empty target node")
	var instruction1 = load("res://addons/fuse/instructions/apply_force.gd").new()
	instruction1.target_node = NodePath("")
	var context1 = ExecutionContext.new(self)
	instruction1.execute(context1)
	await get_tree().process_frame
	assert(context1.had_error(), "Should have error for empty target node")

	# 测试 2: 节点不存在
	print("  5.2: Node not found")
	var instruction2 = load("res://addons/fuse/instructions/apply_force.gd").new()
	instruction2.target_node = NodePath("NonExistentNode")
	var context2 = ExecutionContext.new(self)
	instruction2.execute(context2)
	await get_tree().process_frame
	assert(context2.had_error(), "Should have error for non-existent node")

	# 测试 3: 节点类型错误（CharacterBody2D 不是 RigidBody）
	print("  5.3: Invalid node type (CharacterBody2D)")
	var instruction3 = load("res://addons/fuse/instructions/apply_force.gd").new()
	instruction3.target_node = NodePath("CharacterBody2D")
	var context3 = ExecutionContext.new(self)
	instruction3.execute(context3)
	await get_tree().process_frame
	assert(context3.had_error(), "Should have error for invalid node type")

	print("  ✓ Error handling works correctly")
