extends Node

## ArrayRemove 指令测试脚本

# 测试节点
var test_trigger: Node

# 执行上下文
var context: ExecutionContext

# 测试结果
var tests_passed := 0
var tests_failed := 0
var test_results := []

func _ready():
	print("=== ArrayRemove 指令测试开始 ===\n")

	# 初始化测试环境
	_setup_test_environment()

	# 运行测试
	_test_remove_by_index()
	_test_remove_by_negative_index()
	_test_remove_by_value()
	_test_remove_value_not_found()
	_test_remove_from_empty_array()
	_test_remove_index_out_of_range()
	_test_remove_from_variable()
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

## 测试 1: 按索引移除元素
func _test_remove_by_index():
	print("测试 1: 按索引移除元素")

	# 设置数组变量
	VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3, 4, 5])

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/arrays/array_remove.gd")
	var instruction = instruction_script.new()
	instruction.source_type = 0  # VARIABLE
	instruction.array_variable = "my_array"
	instruction.array_scope = BaseVariable.VariableScope.LOCAL
	instruction.remove_mode = 0  # INDEX
	instruction.index_value = 2

	# 执行指令
	instruction.execute(context)
	await instruction.finished

	# 验证结果
	var result = VariableOperations.get_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, null)
	var expected = [1, 2, 4, 5]

	if _arrays_equal(result, expected):
		_test_pass("按索引移除元素成功")
		print("  期望: %s" % str(expected))
		print("  实际: %s" % str(result))
	else:
		_test_fail("按索引移除元素失败")
		print("  期望: %s" % str(expected))
		print("  实际: %s" % str(result))

	print()

## 测试 2: 按负索引移除元素
func _test_remove_by_negative_index():
	print("测试 2: 按负索引移除元素（-1 移除最后一个）")

	# 设置数组变量
	VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3, 4, 5])

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/arrays/array_remove.gd")
	var instruction = instruction_script.new()
	instruction.source_type = 0  # VARIABLE
	instruction.array_variable = "my_array"
	instruction.array_scope = BaseVariable.VariableScope.LOCAL
	instruction.remove_mode = 0  # INDEX
	instruction.index_value = -1

	# 执行指令
	instruction.execute(context)
	await instruction.finished

	# 验证结果
	var result = VariableOperations.get_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, null)
	var expected = [1, 2, 3, 4]

	if _arrays_equal(result, expected):
		_test_pass("按负索引移除元素成功")
		print("  期望: %s" % str(expected))
		print("  实际: %s" % str(result))
	else:
		_test_fail("按负索引移除元素失败")
		print("  期望: %s" % str(expected))
		print("  实际: %s" % str(result))

	print()

## 测试 3: 按值移除元素
func _test_remove_by_value():
	print("测试 3: 按值移除元素")

	# 设置数组变量
	VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3, 2, 5])

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/arrays/array_remove.gd")
	var instruction = instruction_script.new()
	instruction.source_type = 0  # VARIABLE
	instruction.array_variable = "my_array"
	instruction.array_scope = BaseVariable.VariableScope.LOCAL
	instruction.remove_mode = 1  # VALUE
	instruction.element_value = 2

	# 执行指令
	instruction.execute(context)
	await instruction.finished

	# 验证结果 - 只移除第一个匹配项
	var result = VariableOperations.get_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, null)
	var expected = [1, 3, 2, 5]

	if _arrays_equal(result, expected):
		_test_pass("按值移除元素成功（移除第一个匹配项）")
		print("  期望: %s" % str(expected))
		print("  实际: %s" % str(result))
	else:
		_test_fail("按值移除元素失败")
		print("  期望: %s" % str(expected))
		print("  实际: %s" % str(result))

	print()

## 测试 4: 按值移除但值不存在
func _test_remove_value_not_found():
	print("测试 4: 按值移除但值不存在")

	# 设置数组变量
	VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3])

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/arrays/array_remove.gd")
	var instruction = instruction_script.new()
	instruction.source_type = 0  # VARIABLE
	instruction.array_variable = "my_array"
	instruction.array_scope = BaseVariable.VariableScope.LOCAL
	instruction.remove_mode = 1  # VALUE
	instruction.element_value = 999

	# 执行指令
	instruction.execute(context)
	await instruction.finished

	# 验证结果 - 数组应保持不变
	var result = VariableOperations.get_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, null)
	var expected = [1, 2, 3]

	if _arrays_equal(result, expected):
		_test_pass("值不存在时数组保持不变")
		print("  期望: %s" % str(expected))
		print("  实际: %s" % str(result))
	else:
		_test_fail("值不存在时数组被错误修改")
		print("  期望: %s" % str(expected))
		print("  实际: %s" % str(result))

	print()

## 测试 5: 从空数组移除
func _test_remove_from_empty_array():
	print("测试 5: 从空数组移除")

	# 设置空数组
	VariableOperations.set_variable(context, "empty_array", BaseVariable.VariableScope.LOCAL, [])

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/arrays/array_remove.gd")
	var instruction = instruction_script.new()
	instruction.source_type = 0  # VARIABLE
	instruction.array_variable = "empty_array"
	instruction.array_scope = BaseVariable.VariableScope.LOCAL
	instruction.remove_mode = 0  # INDEX
	instruction.index_value = 0

	# 执行指令
	instruction.execute(context)
	await instruction.finished

	# 验证结果 - 数组应保持空
	var result = VariableOperations.get_variable(context, "empty_array", BaseVariable.VariableScope.LOCAL, null)

	if result is Array and result.is_empty():
		_test_pass("从空数组移除时正常处理")
		print("  结果: 空数组")
	else:
		_test_fail("空数组被错误处理")

	print()

## 测试 6: 索引越界
func _test_remove_index_out_of_range():
	print("测试 6: 索引越界")

	# 设置数组
	VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3])

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/arrays/array_remove.gd")
	var instruction = instruction_script.new()
	instruction.source_type = 0  # VARIABLE
	instruction.array_variable = "my_array"
	instruction.array_scope = BaseVariable.VariableScope.LOCAL
	instruction.remove_mode = 0  # INDEX
	instruction.index_value = 100

	# 执行指令
	instruction.execute(context)
	await instruction.finished

	# 验证结果 - 数组应保持不变
	var result = VariableOperations.get_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, null)
	var expected = [1, 2, 3]

	if _arrays_equal(result, expected):
		_test_pass("索引越界时数组保持不变")
		print("  期望: %s" % str(expected))
		print("  实际: %s" % str(result))
	else:
		_test_fail("索引越界时数组被错误修改")
		print("  期望: %s" % str(expected))
		print("  实际: %s" % str(result))

	print()

## 测试 7: 从变量获取元素值
func _test_remove_from_variable():
	print("测试 7: 从变量获取要移除的元素值")

	# 设置数组和元素变量
	VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [10, 20, 30, 40])
	VariableOperations.set_variable(context, "element_to_remove", BaseVariable.VariableScope.LOCAL, 20)

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/arrays/array_remove.gd")
	var instruction = instruction_script.new()
	instruction.source_type = 0  # VARIABLE
	instruction.array_variable = "my_array"
	instruction.array_scope = BaseVariable.VariableScope.LOCAL
	instruction.remove_mode = 1  # VALUE
	instruction.use_element_from_variable = true
	instruction.element_from_variable = "element_to_remove"
	instruction.element_from_variable_scope = BaseVariable.VariableScope.LOCAL

	# 执行指令
	instruction.execute(context)
	await instruction.finished

	# 验证结果
	var result = VariableOperations.get_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, null)
	var expected = [10, 30, 40]

	if _arrays_equal(result, expected):
		_test_pass("从变量获取元素值移除成功")
		print("  期望: %s" % str(expected))
		print("  实际: %s" % str(result))
	else:
		_test_fail("从变量获取元素值移除失败")
		print("  期望: %s" % str(expected))
		print("  实际: %s" % str(result))

	print()

## 测试 8: 参数验证
func _test_validation():
	print("测试 8: 参数验证")

	# 测试空数组变量名
	var instruction_script = load("res://addons/fuse/instructions/arrays/array_remove.gd")
	var instruction1 = instruction_script.new()
	instruction1.source_type = 0  # VARIABLE
	instruction1.array_variable = ""
	var errors1 = instruction1.validate()

	if errors1.size() > 0:
		_test_pass("空数组变量名验证成功")
		print("  错误信息: %s" % errors1[0])
	else:
		_test_fail("空数组变量名验证失败")

	# 测试空组名
	var instruction2 = instruction_script.new()
	instruction2.source_type = 2  # NODE_GROUP
	instruction2.group_name = ""
	var errors2 = instruction2.validate()

	if errors2.size() > 0:
		_test_pass("空组名验证成功")
		print("  错误信息: %s" % errors2[0])
	else:
		_test_fail("空组名验证失败")

	# 测试 VALUE 模式下的空元素变量名
	var instruction3 = instruction_script.new()
	instruction3.source_type = 0  # VARIABLE
	instruction3.array_variable = "my_array"
	instruction3.remove_mode = 1  # VALUE
	instruction3.use_element_from_variable = true
	instruction3.element_from_variable = ""
	var errors3 = instruction3.validate()

	if errors3.size() > 0:
		_test_pass("VALUE 模式下空元素变量名验证成功")
		print("  错误信息: %s" % errors3[0])
	else:
		_test_fail("VALUE 模式下空元素变量名验证失败")

	print()

## 比较两个数组是否相等
func _arrays_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if a[i] != b[i]:
			return false
	return true

## 测试通过
func _test_pass(description: String):
	tests_passed += 1
	test_results.append({"status": "PASS", "description": description})
	print("  ✓ %s" % description)

## 测试失败
func _test_fail(description: String):
	tests_failed += 1
	test_results.append({"status": "FAIL", "description": description})
	print("  ✗ %s" % description)

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
		var status_symbol = "✓" if result.status == "PASS" else "✗"
		print("%d. %s %s" % [i + 1, status_symbol, result.description])

	print("=".repeat(50))

## 清理资源
func _cleanup():
	if test_trigger:
		test_trigger.queue_free()
	context = null

	print("测试环境已清理")
