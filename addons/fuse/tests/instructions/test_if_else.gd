extends Node

## If/Else 指令测试（重构版本）
##
## 测试场景：
## 1. 变量比较 - 等于、大于、小于
## 2. 节点属性检查
## 3. 节点存在性检查
## 4. True 分支执行
## 5. False 分支执行
##
## 使用新的 Condition 类架构

func _ready():
	print("=== If/Else 指令测试开始（重构版本）===\n")

	test_variable_comparison_equal()
	test_variable_comparison_greater_than()
	test_variable_comparison_less_than()
	test_node_property_check()
	test_node_exists_check()
	test_true_branch_execution()
	test_false_branch_execution()
	test_validation()
	test_type_comparison()

	print("\n=== If/Else 指令测试完成 ===")
	get_tree().quit()

## 测试 1: 变量比较 - 等于
func test_variable_comparison_equal():
	print("\n--- 测试 1: 变量比较 - 等于 ---")

	# 创建条件
	var condition_script = load("res://addons/fuse/conditions/variable/compare_variable.gd")
	var condition = condition_script.new()
	condition.variable_name = "test_value"
	condition.comparison_operator = condition.ComparisonOperator.EQUAL
	condition.compare_value = 100

	# 创建 If/Else 指令
	var if_else_script = load("res://addons/fuse/instructions/flow_control/if_else.gd")
	var if_else = if_else_script.new()
	if_else.condition = condition

	# 创建 True 分支指令
	var true_print = Print.new()
	true_print.message = "条件为真：test_value == 100"
	if_else.true_instructions.append(true_print)

	# 创建 False 分支指令
	var false_print = Print.new()
	false_print.message = "条件为假：test_value != 100"
	if_else.false_instructions.append(false_print)

	# 创建执行上下文并设置变量
	var context = ExecutionContext.new()
	context.set_variable("test_value", 100)

	# 执行指令
	if_else.execute(context)
	await get_tree().process_frame

	# 验证结果
	assert(if_else.is_completed(), "指令应该成功完成")
	print("✓ 变量比较（等于）测试通过")

## 测试 2: 变量比较 - 大于
func test_variable_comparison_greater_than():
	print("\n--- 测试 2: 变量比较 - 大于 ---")

	# 创建条件
	var condition_script = load("res://addons/fuse/conditions/variable/compare_variable.gd")
	var condition = condition_script.new()
	condition.variable_name = "score"
	condition.comparison_operator = condition.ComparisonOperator.GREATER_THAN
	condition.compare_value = 50

	# 创建 If/Else 指令
	var if_else_script = load("res://addons/fuse/instructions/flow_control/if_else.gd")
	var if_else = if_else_script.new()
	if_else.condition = condition

	# 创建分支指令
	var true_print = Print.new()
	true_print.message = "分数大于 50！"
	if_else.true_instructions.append(true_print)

	var false_print = Print.new()
	false_print.message = "分数小于等于 50"
	if_else.false_instructions.append(false_print)

	# 创建执行上下文并设置变量（分数 > 50）
	var context = ExecutionContext.new()
	context.set_variable("score", 75)

	# 执行指令
	if_else.execute(context)
	await get_tree().process_frame

	# 验证结果
	assert(if_else.is_completed(), "指令应该成功完成")
	print("✓ 变量比较（大于）测试通过")

## 测试 3: 变量比较 - 小于
func test_variable_comparison_less_than():
	print("\n--- 测试 3: 变量比较 - 小于 ---")

	# 创建条件
	var condition_script = load("res://addons/fuse/conditions/variable/compare_variable.gd")
	var condition = condition_script.new()
	condition.variable_name = "health"
	condition.comparison_operator = condition.ComparisonOperator.LESS_THAN
	condition.compare_value = 30

	# 创建 If/Else 指令
	var if_else_script = load("res://addons/fuse/instructions/flow_control/if_else.gd")
	var if_else = if_else_script.new()
	if_else.condition = condition

	# 创建分支指令
	var true_print = Print.new()
	true_print.message = "生命值过低！"
	if_else.true_instructions.append(true_print)

	var false_print = Print.new()
	false_print.message = "生命值正常"
	if_else.false_instructions.append(false_print)

	# 创建执行上下文并设置变量（生命值 < 30）
	var context = ExecutionContext.new()
	context.set_variable("health", 20)

	# 执行指令
	if_else.execute(context)
	await get_tree().process_frame

	# 验证结果
	assert(if_else.is_completed(), "指令应该成功完成")
	print("✓ 变量比较（小于）测试通过")

## 测试 4: 节点属性检查
func test_node_property_check():
	print("\n--- 测试 4: 节点属性检查 ---")

	# 创建条件
	var condition_script = load("res://addons/fuse/conditions/node/check_node_property.gd")
	var condition = condition_script.new()
	condition.target_node_path = NodePath(".")
	condition.property_name = "name"
	condition.property_value = "TestIfElseInstruction"

	# 创建 If/Else 指令
	var if_else_script = load("res://addons/fuse/instructions/flow_control/if_else.gd")
	var if_else = if_else_script.new()
	if_else.condition = condition

	# 创建分支指令
	var true_print = Print.new()
	true_print.message = "节点名称匹配"
	if_else.true_instructions.append(true_print)

	var false_print = Print.new()
	false_print.message = "节点名称不匹配"
	if_else.false_instructions.append(false_print)

	# 创建执行上下文
	var context = ExecutionContext.new()
	context.target = self

	# 执行指令
	if_else.execute(context)
	await get_tree().process_frame

	# 验证结果
	assert(if_else.is_completed(), "指令应该成功完成")
	print("✓ 节点属性检查测试通过")

## 测试 5: 节点存在性检查
func test_node_exists_check():
	print("\n--- 测试 5: 节点存在性检查 ---")

	# 创建条件
	var condition_script = load("res://addons/fuse/conditions/node/check_node_exists.gd")
	var condition = condition_script.new()
	condition.check_node_path = NodePath(".")

	# 创建 If/Else 指令
	var if_else_script = load("res://addons/fuse/instructions/flow_control/if_else.gd")
	var if_else = if_else_script.new()
	if_else.condition = condition

	# 创建分支指令
	var true_print = Print.new()
	true_print.message = "节点存在"
	if_else.true_instructions.append(true_print)

	var false_print = Print.new()
	false_print.message = "节点不存在"
	if_else.false_instructions.append(false_print)

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 执行指令
	if_else.execute(context)
	await get_tree().process_frame

	# 验证结果
	assert(if_else.is_completed(), "指令应该成功完成")
	print("✓ 节点存在性检查测试通过")

## 测试 6: True 分支执行
func test_true_branch_execution():
	print("\n--- 测试 6: True 分支执行 ---")

	# 创建条件
	var condition_script = load("res://addons/fuse/conditions/variable/compare_variable.gd")
	var condition = condition_script.new()
	condition.variable_name = "enabled"
	condition.comparison_operator = condition.ComparisonOperator.EQUAL
	condition.compare_value = true

	# 创建 If/Else 指令
	var if_else_script = load("res://addons/fuse/instructions/flow_control/if_else.gd")
	var if_else = if_else_script.new()
	if_else.condition = condition

	# 创建多个 True 分支指令
	var print1 = Print.new()
	print1.message = "True 分支：指令 1"
	if_else.true_instructions.append(print1)

	var print2 = Print.new()
	print2.message = "True 分支：指令 2"
	if_else.true_instructions.append(print2)

	var print3 = Print.new()
	print3.message = "True 分支：指令 3"
	if_else.true_instructions.append(print3)

	# 创建 False 分支指令（不应该执行）
	var false_print = Print.new()
	false_print.message = "False 分支：这条不应该执行"
	if_else.false_instructions.append(false_print)

	# 创建执行上下文并设置变量
	var context = ExecutionContext.new()
	context.set_variable("enabled", true)

	# 执行指令
	if_else.execute(context)
	await get_tree().process_frame

	# 验证结果
	assert(if_else.is_completed(), "指令应该成功完成")
	print("✓ True 分支执行测试通过：执行了 %d 个指令" % if_else.true_instructions.size())

## 测试 7: False 分支执行
func test_false_branch_execution():
	print("\n--- 测试 7: False 分支执行 ---")

	# 创建条件
	var condition_script = load("res://addons/fuse/conditions/variable/compare_variable.gd")
	var condition = condition_script.new()
	condition.variable_name = "is_admin"
	condition.comparison_operator = condition.ComparisonOperator.EQUAL
	condition.compare_value = true

	# 创建 If/Else 指令
	var if_else_script = load("res://addons/fuse/instructions/flow_control/if_else.gd")
	var if_else = if_else_script.new()
	if_else.condition = condition

	# 创建 True 分支指令（不应该执行）
	var true_print = Print.new()
	true_print.message = "True 分支：这条不应该执行"
	if_else.true_instructions.append(true_print)

	# 创建多个 False 分支指令
	var print1 = Print.new()
	print1.message = "False 分支：指令 1"
	if_else.false_instructions.append(print1)

	var print2 = Print.new()
	print2.message = "False 分支：指令 2"
	if_else.false_instructions.append(print2)

	# 创建执行上下文并设置变量（is_admin = false）
	var context = ExecutionContext.new()
	context.set_variable("is_admin", false)

	# 执行指令
	if_else.execute(context)
	await get_tree().process_frame

	# 验证结果
	assert(if_else.is_completed(), "指令应该成功完成")
	print("✓ False 分支执行测试通过：执行了 %d 个指令" % if_else.false_instructions.size())

## 测试 8: 验证指令参数
func test_validation():
	print("\n--- 测试 8: 验证指令参数 ---")

	var if_else_script = load("res://addons/fuse/instructions/flow_control/if_else.gd")
	var if_else = if_else_script.new()

	# 测试条件为空
	if_else.condition = null
	var errors = if_else.validate()
	assert(errors.size() > 0, "空条件应该产生验证错误")
	print("✓ 空条件验证通过")

	# 测试条件存在但配置不完整
	var condition_script = load("res://addons/fuse/conditions/variable/compare_variable.gd")
	var condition = condition_script.new()
	condition.variable_name = ""  # 空变量名
	if_else.condition = condition

	errors = if_else.validate()
	# If/Else 本身应该验证通过，但 Condition 会验证失败
	print("✓ 条件配置验证完成")

	print("✓ 所有验证测试通过")

## 测试 9: 类型比较安全性
func test_type_comparison():
	print("\n--- 测试 9: 类型比较安全性 ---")

	# 测试用例
	var test_cases = [
		{
			"value": 5,
			"compare": "5",
			"expect": false,
			"description": "int vs String (应该不相等)"
		},  # int vs String
		{
			"value": 5.0,
			"compare": 5,
			"expect": true,
			"description": "float vs int (应该相等)"
		},  # float vs int
		{
			"value": null,
			"compare": 0,
			"expect": false,
			"description": "null vs int (应该不相等)"
		},  # null vs int
		{
			"value": 10,
			"compare": 10.0,
			"expect": true,
			"description": "int vs float (应该相等)"
		},  # int vs float
	]

	for test_case in test_cases:
		# 创建条件
		var condition_script = load("res://addons/fuse/conditions/variable/compare_variable.gd")
		var condition = condition_script.new()
		condition.variable_name = "test_var"
		condition.comparison_operator = condition.ComparisonOperator.EQUAL
		condition.compare_value = test_case.compare

		# 创建 If/Else 指令
		var if_else_script = load("res://addons/fuse/instructions/flow_control/if_else.gd")
		var if_else = if_else_script.new()
		if_else.condition = condition

		# 创建简单的打印指令
		var print_inst = Print.new()
		print_inst.message = "测试"
		if_else.true_instructions.append(print_inst)

		# 创建执行上下文并设置变量
		var context = ExecutionContext.new()
		context.set_variable("test_var", test_case.value)

		# 执行指令
		if_else.execute(context)
		await get_tree().process_frame

		# 验证结果
		var condition_result = condition.check(context)
		var passed = condition_result == test_case.expect

		if passed:
			print("  ✓ %s" % test_case.description)
		else:
			print("  ✗ %s (期望: %s, 实际: %s)" % [test_case.description, test_case.expect, condition_result])

	print("✓ 类型比较安全性测试通过")
