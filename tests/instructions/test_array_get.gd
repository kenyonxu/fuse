extends Node

## ArrayGet 指令测试脚本

# 测试节点
var test_trigger: Node

# 执行上下文
var context: ExecutionContext

# 测试结果
var tests_passed := 0
var tests_failed := 0
var test_results := []

func _ready():
	print("=== ArrayGet 指令测试开始 ===\n")

	# 初始化测试环境
	_setup_test_environment()

	# 运行测试
	_test_get_by_index()
	_test_get_by_negative_index()
	_test_get_out_of_range()
	_test_get_from_empty_array()
	_test_get_from_variable()
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

## 测试 1: 按索引获取元素
func _test_get_by_index():
	print("测试 1: 按索引获取元素")

	# 设置数组变量
	VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [10, 20, 30, 40, 50])

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/arrays/array_get.gd")
	var instruction = instruction_script.new()
	instruction.source_type = 0  # VARIABLE
	instruction.array_variable = "my_array"
	instruction.array_scope = BaseVariable.VariableScope.LOCAL
	instruction.index_value = 2
	instruction.target_variable = "result"
	instruction.target_scope = BaseVariable.VariableScope.LOCAL

	# 执行指令
	instruction.execute(context)
	await instruction.finished

	# 验证结果
	var result = VariableOperations.get_variable(context, "result", BaseVariable.VariableScope.LOCAL, null)
	var expected = 30

	if result == expected:
		_test_pass("按索引获取元素成功")
		print("  期望: %d" % expected)
		print("  实际: %d" % result)
	else:
		_test_fail("按索引获取元素失败")
		print("  期望: %d" % expected)
		print("  实际: %s" % str(result))

	print()

## 测试 2: 按负索引获取元素
func _test_get_by_negative_index():
	print("测试 2: 按负索引获取元素（-1 获取最后一个）")

	# 设置数组变量
	VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [10, 20, 30])

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/arrays/array_get.gd")
	var instruction = instruction_script.new()
	instruction.source_type = 0  # VARIABLE
	instruction.array_variable = "my_array"
	instruction.array_scope = BaseVariable.VariableScope.LOCAL
	instruction.index_value = -1
	instruction.target_variable = "result"
	instruction.target_scope = BaseVariable.VariableScope.LOCAL

	# 执行指令
	instruction.execute(context)
	await instruction.finished

	# 验证结果
	var result = VariableOperations.get_variable(context, "result", BaseVariable.VariableScope.LOCAL, null)
	var expected = 30

	if result == expected:
		_test_pass("按负索引获取元素成功")
		print("  期望: %d" % expected)
		print("  实际: %d" % result)
	else:
		_test_fail("按负索引获取元素失败")
		print("  期望: %d" % expected)
		print("  实际: %s" % str(result))

	print()

## 测试 3: 索引越界
func _test_get_out_of_range():
	print("测试 3: 索引越界")

	# 设置数组变量
	VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3])

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/arrays/array_get.gd")
	var instruction = instruction_script.new()
	instruction.source_type = 0  # VARIABLE
	instruction.array_variable = "my_array"
	instruction.array_scope = BaseVariable.VariableScope.LOCAL
	instruction.index_value = 100
	instruction.target_variable = "result"
	instruction.target_scope = BaseVariable.VariableScope.LOCAL

	# 执行指令
	instruction.execute(context)
	await instruction.finished

	# 验证结果 - 应该产生错误
	if instruction.has_error():
		_test_pass("索引越界时产生错误")
		print("  错误信息: %s" % instruction.get_error_message())
	else:
		_test_fail("索引越界时未产生错误")

	print()

## 测试 4: 从空数组获取
func _test_get_from_empty_array():
	print("测试 4: 从空数组获取")

	# 设置空数组
	VariableOperations.set_variable(context, "empty_array", BaseVariable.VariableScope.LOCAL, [])

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/arrays/array_get.gd")
	var instruction = instruction_script.new()
	instruction.source_type = 0  # VARIABLE
	instruction.array_variable = "empty_array"
	instruction.array_scope = BaseVariable.VariableScope.LOCAL
	instruction.index_value = 0
	instruction.target_variable = "result"
	instruction.target_scope = BaseVariable.VariableScope.LOCAL

	# 执行指令
	instruction.execute(context)
	await instruction.finished

	# 验证结果 - 应该产生错误
	if instruction.has_error():
		_test_pass("从空数组获取时产生错误")
		print("  错误信息: %s" % instruction.get_error_message())
	else:
		_test_fail("从空数组获取时未产生错误")

	print()

## 测试 5: 数组不存在
func _test_get_from_variable():
	print("测试 5: 数组不存在")

	# 不设置任何数组变量

	# 创建指令
	var instruction_script = load("res://addons/fuse/instructions/arrays/array_get.gd")
	var instruction = instruction_script.new()
	instruction.source_type = 0  # VARIABLE
	instruction.array_variable = "nonexistent_array"
	instruction.array_scope = BaseVariable.VariableScope.LOCAL
	instruction.index_value = 0
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

## 测试 6: 参数验证
func _test_validation():
	print("测试 6: 参数验证")

	# 测试空数组变量名
	var instruction_script = load("res://addons/fuse/instructions/arrays/array_get.gd")
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
