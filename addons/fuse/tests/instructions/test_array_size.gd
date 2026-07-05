extends Node

## ArraySize 指令测试脚本

# 测试节点
var test_trigger: Node

# 执行上下文
var context: ExecutionContext

# 测试结果
var tests_passed := 0
var tests_failed := 0
var test_results := []

func _ready():
	print("=== ArraySize 指令测试开始 ===\n")

	# 初始化测试环境
	_setup_test_environment()

	# 运行测试
	_test_get_size()
	_test_get_size_empty_array()
	_test_get_size_from_variable_not_found()
	_test_get_size_from_node_children()
	_test_get_size_from_node_group()
	_test_validation()

	# 输出测试结果
	_print_test_results()

	# 清理
	_cleanup()

	# 退出测试
	print("\n=== 测试完成 ===")
	get_tree().quit()

## 初始化测试环境
func _setup_test_environment():
	# 创建测试触发器节点
	test_trigger = Node.new()
	test_trigger.name = "TestTrigger"
	add_child(test_trigger)

	# 创建执行上下文
	var scene_tree = get_tree()
	context = ExecutionContext.new(test_trigger, null, null, scene_tree)

	print("测试环境初始化完成")
	print("  - 创建 Trigger: %s" % test_trigger.name)
	print("  - 创建执行上下文\n")

## 测试 1: 获取数组大小
func _test_get_size():
	print("测试 1: 获取数组大小")

	# 设置数组变量
	VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3, 4, 5])

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/arrays/array_size.gd")
	var instruction = instruction_script.new()
	instruction.source_type = 0  # VARIABLE
	instruction.array_variable = "my_array"
	instruction.array_scope = BaseVariable.VariableScope.LOCAL
	instruction.target_variable = "size"
	instruction.target_scope = BaseVariable.VariableScope.LOCAL

	# 执行指令
	instruction.execute(context)
	await instruction.finished

	# 验证结果
	var result = VariableOperations.get_variable(context, "size", BaseVariable.VariableScope.LOCAL, null)
	var expected = 5

	if result == expected:
		_test_pass("获取数组大小成功")
		print("  期望: %d" % expected)
		print("  实际: %d" % result)
	else:
		_test_fail("获取数组大小失败")
		print("  期望: %d" % expected)
		print("  实际: %s" % str(result))

	print()

## 测试 2: 获取空数组大小
func _test_get_size_empty_array():
	print("测试 2: 获取空数组大小")

	# 设置空数组变量
	VariableOperations.set_variable(context, "empty_array", BaseVariable.VariableScope.LOCAL, [])

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/arrays/array_size.gd")
	var instruction = instruction_script.new()
	instruction.source_type = 0  # VARIABLE
	instruction.array_variable = "empty_array"
	instruction.array_scope = BaseVariable.VariableScope.LOCAL
	instruction.target_variable = "size"
	instruction.target_scope = BaseVariable.VariableScope.LOCAL

	# 执行指令
	instruction.execute(context)
	await instruction.finished

	# 验证结果
	var result = VariableOperations.get_variable(context, "size", BaseVariable.VariableScope.LOCAL, null)
	var expected = 0

	if result == expected:
		_test_pass("获取空数组大小成功")
		print("  期望: %d" % expected)
		print("  实际: %d" % result)
	else:
		_test_fail("获取空数组大小失败")
		print("  期望: %d" % expected)
		print("  实际: %s" % str(result))

	print()

## 测试 3: 数组不存在
func _test_get_size_from_variable_not_found():
	print("测试 3: 数组不存在")

	# 不设置任何数组变量

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/arrays/array_size.gd")
	var instruction = instruction_script.new()
	instruction.source_type = 0  # VARIABLE
	instruction.array_variable = "nonexistent_array"
	instruction.array_scope = BaseVariable.VariableScope.LOCAL
	instruction.target_variable = "size"
	instruction.target_scope = BaseVariable.VariableScope.LOCAL

	# 执行指令
	instruction.execute(context)
	await instruction.finished

	# 验证结果 - 应该产生错误
	if instruction.has_error():
		_test_pass("数组不存在时产生错误")
		print("  错误信息: %s" % instruction.get_error_message())
	else:
		_test_fail("数组不存在时未产生错误")

	print()

## 测试 4: 从节点子节点获取大小
func _test_get_size_from_node_children():
	print("测试 4: 从节点子节点获取大小")

	# 创建一个带有子节点的测试节点
	var parent_node = Node.new()
	parent_node.name = "ParentNode"
	test_trigger.add_child(parent_node)

	# 添加子节点
	for i in range(3):
		var child = Node.new()
		child.name = "Child%d" % i
		parent_node.add_child(child)

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/arrays/array_size.gd")
	var instruction = instruction_script.new()
	instruction.source_type = 1  # NODE_CHILDREN
	instruction.target_node_path = NodePath("../ParentNode")
	instruction.target_variable = "children_count"
	instruction.target_scope = BaseVariable.VariableScope.LOCAL

	# 执行指令
	instruction.execute(context)
	await instruction.finished

	# 验证结果
	var result = VariableOperations.get_variable(context, "children_count", BaseVariable.VariableScope.LOCAL, null)
	var expected = 3

	if result == expected:
		_test_pass("从节点子节点获取大小成功")
		print("  期望: %d" % expected)
		print("  实际: %d" % result)
	else:
		_test_fail("从节点子节点获取大小失败")
		print("  期望: %d" % expected)
		print("  实际: %s" % str(result))

	# 清理
	parent_node.queue_free()
	print()

## 测试 5: 从节点组获取大小
func _test_get_size_from_node_group():
	print("测试 5: 从节点组获取大小")

	# 创建节点并添加到组
	var group_nodes: Array[Node] = []
	for i in range(4):
		var node = Node.new()
		node.name = "GroupNode%d" % i
		add_child(node)
		node.add_to_group("test_group")
		group_nodes.append(node)

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/arrays/array_size.gd")
	var instruction = instruction_script.new()
	instruction.source_type = 2  # NODE_GROUP
	instruction.group_name = "test_group"
	instruction.target_variable = "group_count"
	instruction.target_scope = BaseVariable.VariableScope.LOCAL

	# 执行指令
	instruction.execute(context)
	await instruction.finished

	# 验证结果
	var result = VariableOperations.get_variable(context, "group_count", BaseVariable.VariableScope.LOCAL, null)
	var expected = 4

	if result == expected:
		_test_pass("从节点组获取大小成功")
		print("  期望: %d" % expected)
		print("  实际: %d" % result)
	else:
		_test_fail("从节点组获取大小失败")
		print("  期望: %d" % expected)
		print("  实际: %s" % str(result))

	# 清理
	for node in group_nodes:
		node.queue_free()
	print()

## 测试 6: 参数验证
func _test_validation():
	print("测试 6: 参数验证")

	# 测试空数组变量名
	var instruction_script = load("res://addons/fuse/instructions/arrays/array_size.gd")
	var instruction1 = instruction_script.new()
	instruction1.source_type = 0  # VARIABLE
	instruction1.array_variable = ""
	var errors1 = instruction1.validate()

	if errors1.size() > 0:
		_test_pass("空数组变量名验证成功")
		print("  错误信息: %s" % errors1[0])
	else:
		_test_fail("空数组变量名验证失败")

	# 测试空目标变量名
	var instruction2 = instruction_script.new()
	instruction2.source_type = 0  # VARIABLE
	instruction2.array_variable = "my_array"
	instruction2.target_variable = ""
	var errors2 = instruction2.validate()

	if errors2.size() > 0:
		_test_pass("空目标变量名验证成功")
		print("  错误信息: %s" % errors2[0])
	else:
		_test_fail("空目标变量名验证失败")

	# 测试空组名
	var instruction3 = instruction_script.new()
	instruction3.source_type = 2  # NODE_GROUP
	instruction3.group_name = ""
	var errors3 = instruction3.validate()

	if errors3.size() > 0:
		_test_pass("空组名验证成功")
		print("  错误信息: %s" % errors3[0])
	else:
		_test_fail("空组名验证失败")

	# 测试空节点路径
	var instruction4 = instruction_script.new()
	instruction4.source_type = 1  # NODE_CHILDREN
	instruction4.target_node_path = NodePath("")
	var errors4 = instruction4.validate()

	if errors4.size() > 0:
		_test_pass("空节点路径验证成功")
		print("  错误信息: %s" % errors4[0])
	else:
		_test_fail("空节点路径验证失败")

	print()

## 测试通过
func _test_pass(description: String):
	tests_passed += 1
	test_results.append({"status": "PASS", "description": description})
	print("  + %s" % description)

## 测试失败
func _test_fail(description: String):
	tests_failed += 1
	test_results.append({"status": "FAIL", "description": description})
	print("  - %s" % description)

## 打印测试结果
func _print_test_results():
	print("\n" + "=".repeat(50))
	print("测试结果汇总")
	print("=".repeat(50))

	var total = tests_passed + tests_failed
	print("总测试数: %d" % total)
	print("通过: %d" % tests_passed)
	print("失败: %d" % tests_failed)
	print("成功率: %.1f%%" % (float(tests_passed) / float(total) * 100.0 if total > 0 else 0.0))

	print("\n详细结果:")
	for i in range(test_results.size()):
		var result = test_results[i]
		var status_symbol = "+" if result.status == "PASS" else "-"
		print("%d. %s %s" % [i + 1, status_symbol, result.description])

	print("=".repeat(50))

## 清理资源
func _cleanup():
	if test_trigger:
		test_trigger.queue_free()
	context = null

	print("测试环境已清理")
