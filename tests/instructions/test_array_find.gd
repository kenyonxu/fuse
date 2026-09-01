extends Node

## ArrayFind 指令测试脚本

# 测试节点
var test_trigger: Node

# 执行上下文
var context: ExecutionContext

# 测试结果
var tests_passed := 0
var tests_failed := 0
var test_results := []

func _ready():
	print("=== ArrayFind 指令测试开始 ===\n")

	# 初始化测试环境
	_setup_test_environment()

	# 运行测试
	_test_find_found()
	_test_find_not_found()
	_test_find_string()
	_test_find_from_node_children()
	_test_find_from_node_group()
	_test_find_empty_array()
	_test_find_nonexistent_array()
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

## 测试 1: 查找存在的元素
func _test_find_found():
	print("测试 1: 查找存在的元素")

	# 设置数组变量
	VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [10, 20, 30, 40, 50])

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/arrays/array_find.gd")
	var instruction = instruction_script.new()
	instruction.source_type = 0  # VARIABLE
	instruction.array_variable = "my_array"
	instruction.array_scope = BaseVariable.VariableScope.LOCAL
	instruction.search_value = 30
	instruction.target_variable = "index"
	instruction.target_scope = BaseVariable.VariableScope.LOCAL

	# 执行指令
	instruction.execute(context)
	await instruction.finished

	# 验证结果
	var result = VariableOperations.get_variable(context, "index", BaseVariable.VariableScope.LOCAL, null)
	var expected = 2

	if result == expected:
		_test_pass("查找存在的元素成功")
		print("  期望: %d" % expected)
		print("  实际: %d" % result)
	else:
		_test_fail("查找存在的元素失败")
		print("  期望: %d" % expected)
		print("  实际: %s" % str(result))

	print()

## 测试 2: 查找不存在的元素
func _test_find_not_found():
	print("测试 2: 查找不存在的元素")

	# 设置数组变量
	VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [10, 20, 30])

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/arrays/array_find.gd")
	var instruction = instruction_script.new()
	instruction.source_type = 0  # VARIABLE
	instruction.array_variable = "my_array"
	instruction.array_scope = BaseVariable.VariableScope.LOCAL
	instruction.search_value = 999
	instruction.target_variable = "index"
	instruction.target_scope = BaseVariable.VariableScope.LOCAL

	# 执行指令
	instruction.execute(context)
	await instruction.finished

	# 验证结果
	var result = VariableOperations.get_variable(context, "index", BaseVariable.VariableScope.LOCAL, null)
	var expected = -1

	if result == expected:
		_test_pass("查找不存在的元素返回 -1")
		print("  期望: %d" % expected)
		print("  实际: %d" % result)
	else:
		_test_fail("查找不存在的元素未返回 -1")
		print("  期望: %d" % expected)
		print("  实际: %s" % str(result))

	print()

## 测试 3: 查找字符串元素
func _test_find_string():
	print("测试 3: 查找字符串元素")

	# 设置数组变量
	VariableOperations.set_variable(context, "string_array", BaseVariable.VariableScope.LOCAL, ["apple", "banana", "cherry", "date"])

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/arrays/array_find.gd")
	var instruction = instruction_script.new()
	instruction.source_type = 0  # VARIABLE
	instruction.array_variable = "string_array"
	instruction.array_scope = BaseVariable.VariableScope.LOCAL
	instruction.search_value = "cherry"
	instruction.target_variable = "fruit_index"
	instruction.target_scope = BaseVariable.VariableScope.LOCAL

	# 执行指令
	instruction.execute(context)
	await instruction.finished

	# 验证结果
	var result = VariableOperations.get_variable(context, "fruit_index", BaseVariable.VariableScope.LOCAL, null)
	var expected = 2

	if result == expected:
		_test_pass("查找字符串元素成功")
		print("  期望: %d" % expected)
		print("  实际: %d" % result)
	else:
		_test_fail("查找字符串元素失败")
		print("  期望: %d" % expected)
		print("  实际: %s" % str(result))

	print()

## 测试 4: 从节点子节点数组查找
func _test_find_from_node_children():
	print("测试 4: 从节点子节点数组查找")

	# 创建测试节点
	var parent_node = Node.new()
	parent_node.name = "ParentNode"
	test_trigger.add_child(parent_node)

	# 添加子节点
	var child1 = Node.new()
	child1.name = "Child1"
	parent_node.add_child(child1)

	var child2 = Node.new()
	child2.name = "Child2"
	parent_node.add_child(child2)

	var child3 = Node.new()
	child3.name = "Child3"
	parent_node.add_child(child3)

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/arrays/array_find.gd")
	var instruction = instruction_script.new()
	instruction.source_type = 1  # NODE_CHILDREN
	instruction.target_node_path = NodePath("../ParentNode")
	instruction.search_value = child2
	instruction.target_variable = "child_index"
	instruction.target_scope = BaseVariable.VariableScope.LOCAL

	# 执行指令
	instruction.execute(context)
	await instruction.finished

	# 验证结果
	var result = VariableOperations.get_variable(context, "child_index", BaseVariable.VariableScope.LOCAL, null)
	var expected = 1  # child2 是第二个子节点（索引 1）

	if result == expected:
		_test_pass("从节点子节点数组查找成功")
		print("  期望: %d" % expected)
		print("  实际: %d" % result)
	else:
		_test_fail("从节点子节点数组查找失败")
		print("  期望: %d" % expected)
		print("  实际: %s" % str(result))

	# 清理
	parent_node.queue_free()
	print()

## 测试 5: 从节点组查找
func _test_find_from_node_group():
	print("测试 5: 从节点组查找")

	# 创建测试节点组
	var node1 = Node.new()
	node1.name = "GroupNode1"
	node1.add_to_group("test_find_group")
	test_trigger.add_child(node1)

	var node2 = Node.new()
	node2.name = "GroupNode2"
	node2.add_to_group("test_find_group")
	test_trigger.add_child(node2)

	var node3 = Node.new()
	node3.name = "GroupNode3"
	node3.add_to_group("test_find_group")
	test_trigger.add_child(node3)

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/arrays/array_find.gd")
	var instruction = instruction_script.new()
	instruction.source_type = 2  # NODE_GROUP
	instruction.group_name = "test_find_group"
	instruction.search_value = node2
	instruction.target_variable = "group_index"
	instruction.target_scope = BaseVariable.VariableScope.LOCAL

	# 执行指令
	instruction.execute(context)
	await instruction.finished

	# 验证结果
	var result = VariableOperations.get_variable(context, "group_index", BaseVariable.VariableScope.LOCAL, null)

	if result >= 0 and result < 3:
		_test_pass("从节点组查找成功")
		print("  找到节点在索引: %d" % result)
	else:
		_test_fail("从节点组查找失败")
		print("  期望索引在 0-2 之间")
		print("  实际: %s" % str(result))

	# 清理
	node1.queue_free()
	node2.queue_free()
	node3.queue_free()
	print()

## 测试 6: 从空数组查找
func _test_find_empty_array():
	print("测试 6: 从空数组查找")

	# 设置空数组
	VariableOperations.set_variable(context, "empty_array", BaseVariable.VariableScope.LOCAL, [])

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/arrays/array_find.gd")
	var instruction = instruction_script.new()
	instruction.source_type = 0  # VARIABLE
	instruction.array_variable = "empty_array"
	instruction.array_scope = BaseVariable.VariableScope.LOCAL
	instruction.search_value = 1
	instruction.target_variable = "result"
	instruction.target_scope = BaseVariable.VariableScope.LOCAL

	# 执行指令
	instruction.execute(context)
	await instruction.finished

	# 验证结果 - 应该产生错误
	if instruction.has_error():
		_test_pass("从空数组查找时产生错误")
		print("  错误信息: %s" % instruction.get_error_message())
	else:
		_test_fail("从空数组查找时未产生错误")

	print()

## 测试 7: 数组不存在
func _test_find_nonexistent_array():
	print("测试 7: 数组不存在")

	# 不设置任何数组变量

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/arrays/array_find.gd")
	var instruction = instruction_script.new()
	instruction.source_type = 0  # VARIABLE
	instruction.array_variable = "nonexistent_array"
	instruction.array_scope = BaseVariable.VariableScope.LOCAL
	instruction.search_value = 1
	instruction.target_variable = "result"
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

## 测试 8: 参数验证
func _test_validation():
	print("测试 8: 参数验证")

	# 测试空数组变量名
	var instruction_script = load("res://addons/fuse/instructions/arrays/array_find.gd")
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

	print()

## 测试通过
func _test_pass(description: String):
	tests_passed += 1
	test_results.append({"status": "PASS", "description": description})
	print("  [OK] %s" % description)

## 测试失败
func _test_fail(description: String):
	tests_failed += 1
	test_results.append({"status": "FAIL", "description": description})
	print("  [FAIL] %s" % description)

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
		var status_symbol = "[OK]" if result.status == "PASS" else "[FAIL]"
		print("%d. %s %s" % [i + 1, status_symbol, result.description])

	print("=".repeat(50))

## 清理资源
func _cleanup():
	if test_trigger:
		test_trigger.queue_free()
	context = null

	print("测试环境已清理")
