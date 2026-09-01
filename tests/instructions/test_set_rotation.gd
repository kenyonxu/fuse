extends Node3D

## Set Rotation 指令测试

func _ready():
	print("=== Testing Set Rotation Instruction ===")

	test_set_rotation_3d()
	test_set_rotation_2d()
	test_rotation_from_variable()
	test_invalid_rotation()

	print("=== All Set Rotation tests passed! ===")

## 测试 1: 设置 3D 节点旋转
func test_set_rotation_3d():
	print("Test 1: Set 3D node rotation")

	var instruction_script = load("res://addons/fuse/instructions/set_rotation.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath(".")
	instruction.rotation_degrees = Vector3(45, 90, 135)
	instruction.space = 0  # Global
	instruction.use_variable = false

	var context = ExecutionContext.new()
	add_child(context)

	instruction.execute(context)
	await get_tree().process_frame

	# 验证旋转已设置
	assert(abs(global_rotation_degrees.x - 45) < 0.1, "X rotation should be 45")
	assert(abs(global_rotation_degrees.y - 90) < 0.1, "Y rotation should be 90")
	assert(abs(global_rotation_degrees.z - 135) < 0.1, "Z rotation should be 135")
	print("  Global rotation: (%.1f, %.1f, %.1f)" % [global_rotation_degrees.x, global_rotation_degrees.y, global_rotation_degrees.z])
	print("  ✓ Test 1 passed\n")

	# 重置旋转
	global_rotation_degrees = Vector3.ZERO

## 测试 2: 设置 2D 节点旋转
func test_set_rotation_2d():
	print("Test 2: Set 2D node rotation")

	# 创建一个 2D 节点
	var node_2d = Node2D.new()
	node_2d.name = "TestNode2D"
	add_child(node_2d)

	var instruction_script = load("res://addons/fuse/instructions/set_rotation.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("../TestNode2D")
	instruction.rotation_degrees = Vector3(0, 0, 90)  # 2D 只使用 Z 轴
	instruction.space = 1  # Local
	instruction.use_variable = false

	var context = ExecutionContext.new()
	add_child(context)

	instruction.execute(context)
	await get_tree().process_frame

	# 验证旋转已设置（2D 节点只使用 Z 轴）
	assert(abs(node_2d.rotation_degrees - 90) < 0.1, "Rotation should be 90 degrees")
	print("  2D rotation: %.1f°" % node_2d.rotation_degrees)
	print("  ✓ Test 2 passed\n")

	# 清理
	node_2d.queue_free()

## 测试 3: 从变量读取旋转
func test_rotation_from_variable():
	print("Test 3: Set rotation from variable")

	var instruction_script = load("res://addons/fuse/instructions/set_rotation.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath(".")
	instruction.use_variable = true
	instruction.rotation_variable = "test_rotation"

	var context = ExecutionContext.new()
	add_child(context)
	context.set_variable("test_rotation", Vector3(30, 60, 90))

	instruction.execute(context)
	await get_tree().process_frame

	# 验证旋转已设置
	assert(abs(global_rotation_degrees.x - 30) < 0.1, "X rotation should be 30")
	assert(abs(global_rotation_degrees.y - 60) < 0.1, "Y rotation should be 60")
	assert(abs(global_rotation_degrees.z - 90) < 0.1, "Z rotation should be 90")
	print("  Rotation from variable: (%.1f, %.1f, %.1f)" % [global_rotation_degrees.x, global_rotation_degrees.y, global_rotation_degrees.z])
	print("  ✓ Test 3 passed\n")

	# 重置旋转
	global_rotation_degrees = Vector3.ZERO

## 测试 4: 无效旋转值
func test_invalid_rotation():
	print("Test 4: Invalid rotation validation")

	var instruction_script = load("res://addons/fuse/instructions/set_rotation.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath(".")
	instruction.rotation_degrees = Vector3(NAN, 90, 135)  # 无效的 X 值
	instruction.use_variable = false

	var context = ExecutionContext.new()
	add_child(context)

	print("  Executing with invalid rotation...")
	instruction.execute(context)
	await get_tree().process_frame

	# 验证应该记录错误
	assert(context.had_error(), "Should have error for invalid rotation")
	print("  ✓ Test 4 passed (should log error)\n")
