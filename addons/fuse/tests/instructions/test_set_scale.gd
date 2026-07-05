extends Node3D

## Set Scale 指令测试

func _ready():
	print("=== Testing Set Scale Instruction ===")

	test_set_scale_3d()
	test_set_scale_2d()
	test_scale_from_variable()
	test_scale_from_scalar()
	test_invalid_scale()

	print("=== All Set Scale tests passed! ===")

## 测试 1: 设置 3D 节点缩放
func test_set_scale_3d():
	print("Test 1: Set 3D node scale")

	var instruction_script = load("res://addons/fuse/instructions/set_scale.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath(".")
	instruction.scale = Vector3(2, 3, 4)
	instruction.use_variable = false

	var context = ExecutionContext.new()
	add_child(context)

	instruction.execute(context)
	await get_tree().process_frame

	# 验证缩放已设置
	assert(abs(scale.x - 2) < 0.01, "X scale should be 2")
	assert(abs(scale.y - 3) < 0.01, "Y scale should be 3")
	assert(abs(scale.z - 4) < 0.01, "Z scale should be 4")
	print("  Scale: (%.2f, %.2f, %.2f)" % [scale.x, scale.y, scale.z])
	print("  ✓ Test 1 passed\n")

	# 重置缩放
	scale = Vector3.ONE

## 测试 2: 设置 2D 节点缩放
func test_set_scale_2d():
	print("Test 2: Set 2D node scale")

	# 创建一个 2D 节点
	var node_2d = Node2D.new()
	node_2d.name = "TestNode2D"
	add_child(node_2d)

	var instruction_script = load("res://addons/fuse/instructions/set_scale.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("../TestNode2D")
	instruction.scale = Vector3(1.5, 2.5, 1)  # 2D 只使用 X 和 Y
	instruction.use_variable = false

	var context = ExecutionContext.new()
	add_child(context)

	instruction.execute(context)
	await get_tree().process_frame

	# 验证缩放已设置
	assert(abs(node_2d.scale.x - 1.5) < 0.01, "X scale should be 1.5")
	assert(abs(node_2d.scale.y - 2.5) < 0.01, "Y scale should be 2.5")
	print("  2D scale: (%.2f, %.2f)" % [node_2d.scale.x, node_2d.scale.y])
	print("  ✓ Test 2 passed\n")

	# 清理
	node_2d.queue_free()

## 测试 3: 从变量读取缩放
func test_scale_from_variable():
	print("Test 3: Set scale from variable")

	var instruction_script = load("res://addons/fuse/instructions/set_scale.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath(".")
	instruction.use_variable = true
	instruction.scale_variable = "test_scale"

	var context = ExecutionContext.new()
	add_child(context)
	context.set_variable("test_scale", Vector3(0.5, 1.5, 2.0))

	instruction.execute(context)
	await get_tree().process_frame

	# 验证缩放已设置
	assert(abs(scale.x - 0.5) < 0.01, "X scale should be 0.5")
	assert(abs(scale.y - 1.5) < 0.01, "Y scale should be 1.5")
	assert(abs(scale.z - 2.0) < 0.01, "Z scale should be 2.0")
	print("  Scale from variable: (%.2f, %.2f, %.2f)" % [scale.x, scale.y, scale.z])
	print("  ✓ Test 3 passed\n")

	# 重置缩放
	scale = Vector3.ONE

## 测试 4: 从标量值设置统一缩放
func test_scale_from_scalar():
	print("Test 4: Set uniform scale from scalar")

	var instruction_script = load("res://addons/fuse/instructions/set_scale.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath(".")
	instruction.use_variable = true
	instruction.scale_variable = "test_scalar"

	var context = ExecutionContext.new()
	add_child(context)
	context.set_variable("test_scalar", 2.5)

	instruction.execute(context)
	await get_tree().process_frame

	# 验证缩放已设置为统一值
	assert(abs(scale.x - 2.5) < 0.01, "X scale should be 2.5")
	assert(abs(scale.y - 2.5) < 0.01, "Y scale should be 2.5")
	assert(abs(scale.z - 2.5) < 0.01, "Z scale should be 2.5")
	print("  Uniform scale from scalar: (%.2f, %.2f, %.2f)" % [scale.x, scale.y, scale.z])
	print("  ✓ Test 4 passed\n")

	# 重置缩放
	scale = Vector3.ONE

## 测试 5: 无效缩放值
func test_invalid_scale():
	print("Test 5: Invalid scale validation")

	var instruction_script = load("res://addons/fuse/instructions/set_scale.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath(".")
	instruction.scale = Vector3(NAN, 3, 4)  # 无效的 X 值
	instruction.use_variable = false

	var context = ExecutionContext.new()
	add_child(context)

	print("  Executing with invalid scale...")
	instruction.execute(context)
	await get_tree().process_frame

	# 验证应该记录错误
	assert(context.had_error(), "Should have error for invalid scale")
	print("  ✓ Test 5 passed (should log error)\n")
