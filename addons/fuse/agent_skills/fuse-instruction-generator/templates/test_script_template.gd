extends Node3D
# extends Node2D  # 根据指令类型选择

## InstructionName 指令测试
##
## 测试 InstructionName 指令的各种功能

## 指令名称（根据实际指令修改）
const INSTRUCTION_NAME = "InstructionName"

func _ready():
	print("=== Testing %s ===" % INSTRUCTION_NAME)

	# 运行所有测试
	test_basic_functionality()
	test_edge_cases()
	test_error_handling()

	print("=== All %s tests passed! ===" % INSTRUCTION_NAME)

## 测试 1: 基本功能
func test_basic_functionality():
	print("\n[Test 1] Basic Functionality")

	# 1. 加载指令脚本
	var instruction_script = load("res://addons/fuse/instructions/instruction_name.gd")
	if not instruction_script:
		push_error("无法加载指令脚本")
		return

	var instruction = instruction_script.new()

	# 2. 设置参数
	instruction.target_node = NodePath("TestNode")
	# instruction.parameter_name = 42  # 根据实际参数设置测试值

	# 3. 创建执行上下文
	var context = ExecutionContext.new()
	add_child(context)

	# 4. 执行前记录状态
	var initial_state = _get_test_node_state()

	# 5. 执行指令
	instruction.execute(context)
	await get_tree().process_frame

	# 6. 验证结果
	var final_state = _get_test_node_state()
	assert(final_state != initial_state, "状态应该发生变化")

	print("  ✓ Test 1 passed\n")

## 测试 2: 边界情况
func test_edge_cases():
	print("\n[Test 2] Edge Cases")

	var instruction_script = load("res://addons/fuse/instructions/instruction_name.gd")
	var instruction = instruction_script.new()

	# 测试 1: 极限值
	# instruction.parameter_name = 999  # 根据实际参数设置极限值
	var context = ExecutionContext.new()
	add_child(context)
	instruction.execute(context)
	await get_tree().process_frame
	# 验证极限值处理正确

	# 测试 2: NaN 和 Infinity
	instruction.parameter_name = NAN
	instruction.execute(context)
	await get_tree().process_frame
	# 验证正确处理 NaN

	print("  ✓ Test 2 passed\n")

## 测试 3: 错误处理
func test_error_handling():
	print("\n[Test 3] Error Handling")

	var instruction_script = load("res://addons/fuse/instructions/instruction_name.gd")
	var instruction = instruction_script.new()

	# 测试 1: 空节点路径
	instruction.target_node = NodePath("")
	var context = ExecutionContext.new()
	add_child(context)

	instruction.execute(context)
	await get_tree().process_frame

	assert(instruction.has_error(), "应该产生错误")
	print("  - 正确处理空节点路径")

	# 测试 2: 无效节点路径
	instruction.reset()
	instruction.target_node = NodePath("/Invalid/Node")
	instruction.execute(context)
	await get_tree().process_frame

	assert(instruction.has_error(), "应该产生错误")
	print("  - 正确处理无效节点路径")

	# 测试 3: 错误的节点类型
	instruction.reset()
	instruction.target_node = NodePath(".")
	instruction.execute(context)
	await get_tree().process_frame

	# 如果指令需要特定节点类型，验证类型检查

	print("  ✓ Test 3 passed\n")

## 辅助方法：获取测试节点状态
func _get_test_node_state() -> Dictionary:
	var test_node = get_node_or_null("TestNode")
	if not test_node:
		return {}

	return {
		"position": test_node.position,
		"rotation": test_node.rotation,
		"scale": test_node.scale,
		# 根据需要添加更多属性
	}

## 辅助方法：验证数值近似相等
func _is_approximately_equal(a: float, b: float, epsilon: float = 0.001) -> bool:
	return abs(a - b) < epsilon

## 辅助方法：验证向量近似相等
func _is_vector_approximately_equal(a: Vector3, b: Vector3, epsilon: float = 0.001) -> bool:
	return _is_approximately_equal(a.x, b.x, epsilon) and \
		   _is_approximately_equal(a.y, b.y, epsilon) and \
		   _is_approximately_equal(a.z, b.z, epsilon)
