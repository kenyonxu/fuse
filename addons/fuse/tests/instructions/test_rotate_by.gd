extends Node3D

## Rotate By 指令测试

func _ready():
	print("=== Testing Rotate By Instruction ===")

	test_rotate_by_3d_global()
	test_rotate_by_3d_local()
	test_rotate_by_2d()
	test_rotate_by_from_variable()
	test_invalid_rotation()
	test_infinity_rotation()
	test_large_rotation()
	test_mixed_invalid_rotation_values()

	print("=== All Rotate By tests passed! ===")

## 测试 1: 3D 节点全局旋转
func test_rotate_by_3d_global():
	print("Test 1: Rotate 3D node by global offset")

	var instruction_script = load("res://addons/fuse/instructions/rotate_by.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath(".")
	instruction.rotation_offset = Vector3(45, 90, 135)
	instruction.space = 0  # GLOBAL
	instruction.use_variable = false

	var context = ExecutionContext.new()
	add_child(context)

	# 记录初始旋转
	var initial_rot = global_rotation_degrees

	instruction.execute(context)
	await get_tree().process_frame

	# 验证旋转已相对旋转
	var expected_rot = initial_rot + Vector3(45, 90, 135)
	assert(abs(global_rotation_degrees.x - expected_rot.x) < 0.1, "X rotation should be rotated")
	assert(abs(global_rotation_degrees.y - expected_rot.y) < 0.1, "Y rotation should be rotated")
	assert(abs(global_rotation_degrees.z - expected_rot.z) < 0.1, "Z rotation should be rotated")
	print("  Global rotation: (%.1f, %.1f, %.1f)" % [global_rotation_degrees.x, global_rotation_degrees.y, global_rotation_degrees.z])
	print("  ✓ Test 1 passed\n")

	# 重置旋转
	global_rotation_degrees = initial_rot

## 测试 2: 3D 节点局部旋转
func test_rotate_by_3d_local():
	print("Test 2: Rotate 3D node by local offset")

	var instruction_script = load("res://addons/fuse/instructions/rotate_by.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath(".")
	instruction.rotation_offset = Vector3(30, 60, 90)
	instruction.space = 1  # LOCAL
	instruction.use_variable = false

	var context = ExecutionContext.new()
	add_child(context)

	# 记录初始旋转
	var initial_rot = rotation_degrees

	instruction.execute(context)
	await get_tree().process_frame

	# 验证旋转已相对旋转
	var expected_rot = initial_rot + Vector3(30, 60, 90)
	assert(abs(rotation_degrees.x - expected_rot.x) < 0.1, "X rotation should be rotated")
	assert(abs(rotation_degrees.y - expected_rot.y) < 0.1, "Y rotation should be rotated")
	assert(abs(rotation_degrees.z - expected_rot.z) < 0.1, "Z rotation should be rotated")
	print("  Local rotation: (%.1f, %.1f, %.1f)" % [rotation_degrees.x, rotation_degrees.y, rotation_degrees.z])
	print("  ✓ Test 2 passed\n")

	# 重置旋转
	rotation_degrees = initial_rot

## 测试 3: 2D 节点相对旋转
func test_rotate_by_2d():
	print("Test 3: Rotate 2D node by offset")

	# 创建一个 2D 节点
	var node_2d = Node2D.new()
	node_2d.name = "TestNode2D"
	node_2d.rotation_degrees = 45
	add_child(node_2d)

	var instruction_script = load("res://addons/fuse/instructions/rotate_by.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("../TestNode2D")
	instruction.rotation_offset = Vector3(0, 0, 90)  # 2D 只使用 Z 轴
	instruction.space = 1  # LOCAL
	instruction.use_variable = false

	var context = ExecutionContext.new()
	add_child(context)

	instruction.execute(context)
	await get_tree().process_frame

	# 验证旋转已相对旋转
	assert(abs(node_2d.rotation_degrees - 135) < 0.1, "Rotation should be 135 degrees")
	print("  2D rotation: %.1f°" % node_2d.rotation_degrees)
	print("  ✓ Test 3 passed\n")

	# 清理
	node_2d.queue_free()

## 测试 4: 从变量读取旋转偏移
func test_rotate_by_from_variable():
	print("Test 4: Rotate by from variable")

	var instruction_script = load("res://addons/fuse/instructions/rotate_by.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath(".")
	instruction.use_variable = true
	instruction.rotation_variable = "rot_offset"
	instruction.space = 0  # GLOBAL

	var context = ExecutionContext.new()
	add_child(context)
	context.set_variable("rot_offset", Vector3(15, 30, 45))

	# 记录初始旋转
	var initial_rot = global_rotation_degrees

	instruction.execute(context)
	await get_tree().process_frame

	# 验证旋转已相对旋转
	var expected_rot = initial_rot + Vector3(15, 30, 45)
	assert(abs(global_rotation_degrees.x - expected_rot.x) < 0.1, "X rotation should be rotated")
	assert(abs(global_rotation_degrees.y - expected_rot.y) < 0.1, "Y rotation should be rotated")
	assert(abs(global_rotation_degrees.z - expected_rot.z) < 0.1, "Z rotation should be rotated")
	print("  Rotated from variable: ✓")
	print("  ✓ Test 4 passed\n")

	# 重置旋转
	global_rotation_degrees = initial_rot

## 测试 5: 无效旋转偏移值
func test_invalid_rotation():
	print("Test 5: Invalid rotation validation")

	var instruction_script = load("res://addons/fuse/instructions/rotate_by.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath(".")
	instruction.rotation_offset = Vector3(NAN, 0, 0)  # 无效的 X 值
	instruction.use_variable = false

	var context = ExecutionContext.new()
	add_child(context)

	print("  Executing with invalid rotation...")
	instruction.execute(context)
	await get_tree().process_frame

	# 验证应该记录错误
	assert(context.had_error(), "Should have error for invalid rotation")
	print("  ✓ Test 5 passed (should log error)\n")

## 测试 6: Infinity 旋转偏移值
func test_infinity_rotation():
	print("Test 6: Infinity rotation validation")

	var instruction_script = load("res://addons/fuse/instructions/rotate_by.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath(".")
	instruction.rotation_offset = Vector3(INF, 0, 0)  # 无限的 X 值
	instruction.use_variable = false

	var context = ExecutionContext.new()
	add_child(context)

	print("  Executing with infinity rotation...")
	instruction.execute(context)
	await get_tree().process_frame

	# 验证应该记录错误
	assert(context.had_error(), "Should have error for infinity rotation")
	print("  ✓ Test 6 passed (should log error)\n")

## 测试 7: 大数值旋转
func test_large_rotation():
	print("Test 7: Large rotation values")

	var instruction_script = load("res://addons/fuse/instructions/rotate_by.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath(".")
	instruction.rotation_offset = Vector3(7200, 10800, 14400)  # 大数值（多圈旋转）
	instruction.space = 0  # GLOBAL
	instruction.use_variable = false

	var context = ExecutionContext.new()
	add_child(context)

	var initial_rot = global_rotation_degrees

	instruction.execute(context)
	await get_tree().process_frame

	# 验证旋转已相对旋转（大数值应该也能正常工作）
	var expected_rot = initial_rot + Vector3(7200, 10800, 14400)
	assert(abs(global_rotation_degrees.x - expected_rot.x) < 0.1, "X rotation should handle large values")
	assert(abs(global_rotation_degrees.y - expected_rot.y) < 0.1, "Y rotation should handle large values")
	assert(abs(global_rotation_degrees.z - expected_rot.z) < 0.1, "Z rotation should handle large values")
	print("  Large rotation: (%.1f°, %.1f°, %.1f°)" % [global_rotation_degrees.x, global_rotation_degrees.y, global_rotation_degrees.z])
	print("  ✓ Test 7 passed\n")

	# 重置旋转
	global_rotation_degrees = initial_rot

## 测试 8: 混合无效旋转值
func test_mixed_invalid_rotation_values():
	print("Test 8: Mixed invalid rotation values (NaN + valid + Infinity)")

	var instruction_script = load("res://addons/fuse/instructions/rotate_by.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath(".")
	instruction.rotation_offset = Vector3(NAN, 45.0, INF)  # 混合无效值
	instruction.use_variable = false

	var context = ExecutionContext.new()
	add_child(context)

	print("  Executing with mixed invalid rotation values...")
	instruction.execute(context)
	await get_tree().process_frame

	# 验证应该记录错误
	assert(context.had_error(), "Should have error for mixed invalid rotation values")
	print("  ✓ Test 8 passed (should log error)\n")

