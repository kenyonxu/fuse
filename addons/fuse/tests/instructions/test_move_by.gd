extends Node3D

## Move By 指令测试

func _ready():
	print("=== Testing Move By Instruction ===")

	test_move_by_3d_global()
	test_move_by_3d_local()
	test_move_by_2d()
	test_move_by_from_variable()
	test_invalid_offset()
	test_infinity_offset()
	test_large_offset()
	test_mixed_invalid_values()

	print("=== All Move By tests passed! ===")

## 测试 1: 3D 节点全局移动
func test_move_by_3d_global():
	print("Test 1: Move 3D node by global offset")

	var instruction_script = load("res://addons/fuse/instructions/move_by.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath(".")
	instruction.offset = Vector3(5, 10, 15)
	instruction.space = 0  # GLOBAL
	instruction.use_variable = false

	var context = ExecutionContext.new()
	add_child(context)

	# 记录初始位置
	var initial_pos = global_position

	instruction.execute(context)
	await get_tree().process_frame

	# 验证位置已相对移动
	var expected_pos = initial_pos + Vector3(5, 10, 15)
	assert(abs(global_position.x - expected_pos.x) < 0.01, "X position should be moved")
	assert(abs(global_position.y - expected_pos.y) < 0.01, "Y position should be moved")
	assert(abs(global_position.z - expected_pos.z) < 0.01, "Z position should be moved")
	print("  Global position: (%.2f, %.2f, %.2f)" % [global_position.x, global_position.y, global_position.z])
	print("  ✓ Test 1 passed\n")

	# 重置位置
	global_position = initial_pos

## 测试 2: 3D 节点局部移动
func test_move_by_3d_local():
	print("Test 2: Move 3D node by local offset")

	var instruction_script = load("res://addons/fuse/instructions/move_by.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath(".")
	instruction.offset = Vector3(2, 3, 4)
	instruction.space = 1  # LOCAL
	instruction.use_variable = false

	var context = ExecutionContext.new()
	add_child(context)

	# 记录初始位置
	var initial_pos = position

	instruction.execute(context)
	await get_tree().process_frame

	# 验证位置已相对移动
	var expected_pos = initial_pos + Vector3(2, 3, 4)
	assert(abs(position.x - expected_pos.x) < 0.01, "X position should be moved")
	assert(abs(position.y - expected_pos.y) < 0.01, "Y position should be moved")
	assert(abs(position.z - expected_pos.z) < 0.01, "Z position should be moved")
	print("  Local position: (%.2f, %.2f, %.2f)" % [position.x, position.y, position.z])
	print("  ✓ Test 2 passed\n")

	# 重置位置
	position = initial_pos

## 测试 3: 2D 节点相对移动
func test_move_by_2d():
	print("Test 3: Move 2D node by offset")

	# 创建一个 2D 节点
	var node_2d = Node2D.new()
	node_2d.name = "TestNode2D"
	node_2d.position = Vector2(10, 20)
	add_child(node_2d)

	var instruction_script = load("res://addons/fuse/instructions/move_by.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("../TestNode2D")
	instruction.offset = Vector3(5, -10, 0)  # 2D 只使用 X 和 Y
	instruction.space = 0  # GLOBAL
	instruction.use_variable = false

	var context = ExecutionContext.new()
	add_child(context)

	instruction.execute(context)
	await get_tree().process_frame

	# 验证位置已相对移动
	assert(abs(node_2d.global_position.x - 15) < 0.01, "X position should be 15")
	assert(abs(node_2d.global_position.y - 10) < 0.01, "Y position should be 10")
	print("  2D position: (%.2f, %.2f)" % [node_2d.global_position.x, node_2d.global_position.y])
	print("  ✓ Test 3 passed\n")

	# 清理
	node_2d.queue_free()

## 测试 4: 从变量读取偏移
func test_move_by_from_variable():
	print("Test 4: Move by from variable")

	var instruction_script = load("res://addons/fuse/instructions/move_by.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath(".")
	instruction.use_variable = true
	instruction.offset_variable = "move_offset"
	instruction.space = 0  # GLOBAL

	var context = ExecutionContext.new()
	add_child(context)
	context.set_variable("move_offset", Vector3(1, 2, 3))

	# 记录初始位置
	var initial_pos = global_position

	instruction.execute(context)
	await get_tree().process_frame

	# 验证位置已相对移动
	var expected_pos = initial_pos + Vector3(1, 2, 3)
	assert(abs(global_position.x - expected_pos.x) < 0.01, "X position should be moved")
	assert(abs(global_position.y - expected_pos.y) < 0.01, "Y position should be moved")
	assert(abs(global_position.z - expected_pos.z) < 0.01, "Z position should be moved")
	print("  Moved from variable: ✓")
	print("  ✓ Test 4 passed\n")

	# 重置位置
	global_position = initial_pos

## 测试 5: 无效偏移值
func test_invalid_offset():
	print("Test 5: Invalid offset validation")

	var instruction_script = load("res://addons/fuse/instructions/move_by.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath(".")
	instruction.offset = Vector3(NAN, 0, 0)  # 无效的 X 值
	instruction.use_variable = false

	var context = ExecutionContext.new()
	add_child(context)

	print("  Executing with invalid offset...")
	instruction.execute(context)
	await get_tree().process_frame

	# 验证应该记录错误
	assert(context.had_error(), "Should have error for invalid offset")
	print("  ✓ Test 5 passed (should log error)\n")

## 测试 6: Infinity 偏移值
func test_infinity_offset():
	print("Test 6: Infinity offset validation")

	var instruction_script = load("res://addons/fuse/instructions/move_by.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath(".")
	instruction.offset = Vector3(INF, 0, 0)  # 无限的 X 值
	instruction.use_variable = false

	var context = ExecutionContext.new()
	add_child(context)

	print("  Executing with infinity offset...")
	instruction.execute(context)
	await get_tree().process_frame

	# 验证应该记录错误
	assert(context.had_error(), "Should have error for infinity offset")
	print("  ✓ Test 6 passed (should log error)\n")

## 测试 7: 大数值偏移
func test_large_offset():
	print("Test 7: Large offset values")

	var instruction_script = load("res://addons/fuse/instructions/move_by.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath(".")
	instruction.offset = Vector3(1000000, 2000000, 3000000)  # 大数值
	instruction.space = 0  # GLOBAL
	instruction.use_variable = false

	var context = ExecutionContext.new()
	add_child(context)

	var initial_pos = global_position

	instruction.execute(context)
	await get_tree().process_frame

	# 验证位置已相对移动（大数值应该也能正常工作）
	var expected_pos = initial_pos + Vector3(1000000, 2000000, 3000000)
	assert(abs(global_position.x - expected_pos.x) < 1.0, "X position should handle large values")
	assert(abs(global_position.y - expected_pos.y) < 1.0, "Y position should handle large values")
	assert(abs(global_position.z - expected_pos.z) < 1.0, "Z position should handle large values")
	print("  Large offset: (%.1f, %.1f, %.1f)" % [global_position.x, global_position.y, global_position.z])
	print("  ✓ Test 7 passed\n")

	# 重置位置
	global_position = initial_pos

## 测试 8: 混合无效值
func test_mixed_invalid_values():
	print("Test 8: Mixed invalid values (NaN + valid + Infinity)")

	var instruction_script = load("res://addons/fuse/instructions/move_by.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath(".")
	instruction.offset = Vector3(NAN, 1.0, INF)  # 混合无效值
	instruction.use_variable = false

	var context = ExecutionContext.new()
	add_child(context)

	print("  Executing with mixed invalid values...")
	instruction.execute(context)
	await get_tree().process_frame

	# 验证应该记录错误
	assert(context.had_error(), "Should have error for mixed invalid values")
	print("  ✓ Test 8 passed (should log error)\n")

