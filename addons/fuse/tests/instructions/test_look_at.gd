extends Node3D

## Look At 指令测试

func _ready():
	print("=== Testing Look At Instruction ===")

	test_look_at_position_3d()
	test_look_at_node_3d()
	test_look_at_2d()
	test_look_at_from_variable()
	test_invalid_target()

	print("=== All Look At tests passed! ===")

## 测试 1: 3D 节点朝向位置
func test_look_at_position_3d():
	print("Test 1: 3D node look at position")

	var instruction_script = load("res://addons/fuse/instructions/look_at.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath(".")
	instruction.target_type = 0  # POSITION
	instruction.target_position = Vector3(10, 5, 0)
	instruction.use_variable = false

	var context = ExecutionContext.new()
	add_child(context)

	# 先设置一个不同的朝向
	look_at(Vector3(1, 0, 0))

	instruction.execute(context)
	await get_tree().process_frame

	# 验证节点已朝向目标
	var forward = -global_basis.z  # Node3D 的前方向是 -Z
	var target_dir = (Vector3(10, 5, 0) - global_position).normalized()

	var dot_product = forward.dot(target_dir)
	assert(dot_product > 0.99, "Node should face the target position")
	print("  Forward: (%.2f, %.2f, %.2f)" % [forward.x, forward.y, forward.z])
	print("  Target dir: (%.2f, %.2f, %.2f)" % [target_dir.x, target_dir.y, target_dir.z])
	print("  Dot product: %.3f" % dot_product)
	print("  ✓ Test 1 passed\n")

## 测试 2: 3D 节点朝向另一个节点
func test_look_at_node_3d():
	print("Test 2: 3D node look at another node")

	# 创建目标节点
	var target = Node3D.new()
	target.name = "TargetNode"
	target.position = Vector3(-5, 10, 3)
	add_child(target)

	var instruction_script = load("res://addons/fuse/instructions/look_at.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath(".")
	instruction.target_type = 1  # NODE
	instruction.look_at_node = NodePath("../TargetNode")

	var context = ExecutionContext.new()
	add_child(context)

	instruction.execute(context)
	await get_tree().process_frame

	# 验证节点已朝向目标
	var forward = -global_basis.z
	var target_dir = (target.global_position - global_position).normalized()

	var dot_product = forward.dot(target_dir)
	assert(dot_product > 0.99, "Node should face the target node")
	print("  Target position: (%.2f, %.2f, %.2f)" % [target.position.x, target.position.y, target.position.z])
	print("  Dot product: %.3f" % dot_product)
	print("  ✓ Test 2 passed\n")

	# 清理
	target.queue_free()

## 测试 3: 2D 节点朝向位置
func test_look_at_2d():
	print("Test 3: 2D node look at position")

	# 创建 2D 节点
	var node_2d = Node2D.new()
	node_2d.name = "TestNode2D"
	node_2d.position = Vector2(0, 0)
	add_child(node_2d)

	var instruction_script = load("res://addons/fuse/instructions/look_at.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("../TestNode2D")
	instruction.target_type = 0  # POSITION
	instruction.target_position = Vector3(5, 5, 0)
	instruction.use_variable = false

	var context = ExecutionContext.new()
	add_child(context)

	instruction.execute(context)
	await get_tree().process_frame

	# 验证节点已朝向目标（检查角度）
	var expected_angle = atan2(5, 5)  # 目标方向的角度
	var angle_diff = abs(node_2d.global_rotation - expected_angle)

	# Node2D 的 look_at 会立即旋转，所以角度应该接近
	assert(angle_diff < 0.1, "Node2D should face the target position")
	print("  Expected angle: %.3f rad" % expected_angle)
	print("  Actual angle: %.3f rad" % node_2d.global_rotation)
	print("  Angle diff: %.3f rad" % angle_diff)
	print("  ✓ Test 3 passed\n")

	# 清理
	node_2d.queue_free()

## 测试 4: 从变量读取目标位置
func test_look_at_from_variable():
	print("Test 4: Look at from variable")

	var instruction_script = load("res://addons/fuse/instructions/look_at.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath(".")
	instruction.target_type = 0  # POSITION
	instruction.use_variable = true
	instruction.position_variable = "target_pos"

	var context = ExecutionContext.new()
	add_child(context)
	context.set_variable("target_pos", Vector3(0, 10, 5))

	instruction.execute(context)
	await get_tree().process_frame

	# 验证节点已朝向目标
	var forward = -global_basis.z
	var target_dir = (Vector3(0, 10, 5) - global_position).normalized()

	var dot_product = forward.dot(target_dir)
	assert(dot_product > 0.99, "Node should face the variable position")
	print("  Dot product: %.3f" % dot_product)
	print("  ✓ Test 4 passed\n")

## 测试 5: 无效目标
func test_invalid_target():
	print("Test 5: Invalid target validation")

	var instruction_script = load("res://addons/fuse/instructions/look_at.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath(".")
	instruction.target_type = 1  # NODE
	instruction.look_at_node = NodePath("../NonexistentNode")

	var context = ExecutionContext.new()
	add_child(context)

	print("  Executing with invalid target node...")
	instruction.execute(context)
	await get_tree().process_frame

	# 验证应该记录错误
	assert(context.had_error(), "Should have error for invalid target node")
	print("  ✓ Test 5 passed (should log error)\n")
