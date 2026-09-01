extends Node

## Condition 类测试脚本

var _fail: int = 0

func _ready():
	print("=== Condition 类测试开始 ===\n")

	test_variable_comparison_condition()
	test_node_property_check_condition()
	test_node_exists_condition()
	test_if_else_with_condition()

	print("=== Condition 类测试完成 ===")
	# 退出码门禁：headless 运行时非 0 即失败
	get_tree().quit(1 if _fail > 0 else 0)

## 断言门禁：失败 push_error 并计数（不中断后续用例）
func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_fail += 1
	push_error("✗ " + message)

## 测试 CompareVariable
func test_variable_comparison_condition():
	print("测试 1: CompareVariable")

	var condition_script = load("res://addons/fuse/conditions/variable/compare_variable.gd")
	var condition = condition_script.new()
	add_child(condition)

	# 设置条件
	condition.variable_name = "test_var"
	condition.comparison_operator = condition.ComparisonOperator.EQUAL
	condition.compare_value = 42

	# 创建执行上下文
	var context = ExecutionContext.new()
	add_child(context)
	context.set_variable("test_var", 42)

	# 测试相等
	var result = condition.check(context)
	print("  测试 42 == 42: %s" % ("✓" if result else "✗"))
	_check(result == true, "42 == 42 应该为 true")

	# 测试不相等
	context.set_variable("test_var", 50)
	result = condition.check(context)
	print("  测试 42 == 50: %s" % ("✓" if not result else "✗"))
	_check(result == false, "42 == 50 应该为 false")

	# 测试大于
	condition.comparison_operator = condition.ComparisonOperator.GREATER_THAN
	context.set_variable("test_var", 50)
	result = condition.check(context)
	print("  测试 50 > 42: %s" % ("✓" if result else "✗"))
	_check(result == true, "50 > 42 应该为 true")

	# 测试小于
	condition.comparison_operator = condition.ComparisonOperator.LESS_THAN
	context.set_variable("test_var", 30)
	result = condition.check(context)
	print("  测试 30 < 42: %s" % ("✓" if result else "✗"))
	_check(result == true, "30 < 42 应该为 true")

	# 测试结果取反
	condition.negate_result = true
	result = condition.check(context)
	print("  测试 !(30 < 42): %s" % ("✓" if not result else "✗"))
	_check(result == false, "!(30 < 42) 应该为 false")

	# 测试描述
	var desc = condition.get_description()
	print("  条件描述: %s" % desc)
	_check("test_var" in desc, "描述应包含变量名")

	# 测试依赖
	var deps = condition.get_dependencies()
	print("  依赖变量: %s" % str(deps))
	_check(deps.size() == 1, "应该有1个依赖")
	_check(deps[0] == "test_var", "依赖应该是 test_var")

	# 测试验证
	var errors = condition.validate()
	print("  验证错误: %s (期望: 0)" % errors.size())
	_check(errors.is_empty(), "验证应该通过")

	print("  ✓ CompareVariable 测试通过\n")


## 测试 CheckNodeProperty
func test_node_property_check_condition():
	print("测试 2: CheckNodeProperty")

	var condition_script = load("res://addons/fuse/conditions/node/check_node_property.gd")
	var condition = condition_script.new()
	add_child(condition)

	# 创建测试节点
	var test_node = Node2D.new()
	test_node.name = "TestNode2D"
	test_node.position = Vector2(100, 200)
	add_child(test_node)

	# 设置条件
	condition.target_node_path = NodePath("../TestNode2D")
	condition.property_name = "position"
	condition.property_value = Vector2(100, 200)

	# 创建执行上下文
	var context = ExecutionContext.new()
	add_child(context)

	# 测试属性匹配
	var result = condition.check(context)
	print("  测试 position == (100, 200): %s" % ("✓" if result else "✗"))
	_check(result == true, "position 应该匹配")

	# 测试属性不匹配
	condition.property_value = Vector2(50, 50)
	result = condition.check(context)
	print("  测试 position == (50, 50): %s" % ("✓" if not result else "✗"))
	_check(result == false, "position 不应该匹配")

	# 测试描述
	var desc = condition.get_description()
	print("  条件描述: %s" % desc)
	_check("position" in desc, "描述应包含属性名")

	# 测试验证（目标节点路径为空）
	condition.target_node_path = NodePath("")
	var errors = condition.validate()
	print("  验证错误（空路径）: %s (期望: 1)" % errors.size())
	_check(errors.size() == 1, "应该有1个验证错误")

	print("  ✓ CheckNodeProperty 测试通过\n")

	test_node.queue_free()

## 测试 CheckNodeExists
func test_node_exists_condition():
	print("测试 3: CheckNodeExists")

	var condition_script = load("res://addons/fuse/conditions/node/check_node_exists.gd")
	var condition = condition_script.new()
	add_child(condition)

	# 创建测试节点
	var test_node = Node2D.new()
	test_node.name = "ExistsNode"
	add_child(test_node)

	# 设置条件
	condition.check_node_path = NodePath("../ExistsNode")

	# 创建执行上下文
	var context = ExecutionContext.new()
	add_child(context)

	# 测试节点存在
	var result = condition.check(context)
	print("  测试节点存在: %s" % ("✓" if result else "✗"))
	_check(result == true, "节点应该存在")

	# 测试节点不存在
	condition.check_node_path = NodePath("../NonexistentNode")
	result = condition.check(context)
	print("  测试节点不存在: %s" % ("✓" if not result else "✗"))
	_check(result == false, "节点不应该存在")

	# 测试结果取反
	condition.negate_result = true
	result = condition.check(context)
	print("  测试 !(节点不存在): %s" % ("✓" if result else "✗"))
	_check(result == true, "!(节点不存在) 应该为 true")

	# 测试描述
	var desc = condition.get_description()
	print("  条件描述: %s" % desc)

	# 测试依赖（节点检查不依赖变量）
	var deps = condition.get_dependencies()
	print("  依赖变量: %s (期望: 0)" % str(deps))
	_check(deps.is_empty(), "节点检查不应该有变量依赖")

	print("  ✓ CheckNodeExists 测试通过\n")

	test_node.queue_free()

## 测试重构后的 If/Else 指令
func test_if_else_with_condition():
	print("测试 4: If/Else with Condition")

	# 加载 If/Else 指令
	var if_else_script = load("res://addons/fuse/instructions/flow_control/if_else.gd")
	var if_else = if_else_script.new()
	add_child(if_else)

	# 创建条件
	var condition_script = load("res://addons/fuse/conditions/variable/compare_variable.gd")
	var condition = condition_script.new()
	add_child(condition)

	condition.variable_name = "score"
	condition.comparison_operator = condition.ComparisonOperator.GREATER_EQUAL
	condition.compare_value = 100

	# 创建测试指令
	var print_script = load("res://addons/fuse/instructions/debug/print.gd")
	var print_pass = print_script.new()
	print_pass.message = "通过！"
	var print_fail = print_script.new()
	print_fail.message = "失败！"

	# 设置 If/Else
	if_else.condition = condition
	if_else.true_instructions.append(print_pass)
	if_else.false_instructions.append(print_fail)

	# 创建执行上下文
	var context = ExecutionContext.new()
	add_child(context)

	# 测试条件为真时执行 true_instructions
	context.set_variable("score", 150)
	if_else.execute(context)
	print("  测试 score=150 (应该执行 true 分支): ✓")

	# 测试条件为假时执行 false_instructions
	context.set_variable("score", 50)
	if_else.execute(context)
	print("  测试 score=50 (应该执行 false 分支): ✓")

	# 测试描述
	var desc = if_else.get_description()
	print("  If/Else 描述: %s" % desc)
	_check("If/Else" in desc, "描述应包含 If/Else")

	# 测试验证（条件为空）
	if_else.condition = null
	var errors = if_else.validate()
	print("  验证错误（无条件）: %s (期望: 1)" % errors.size())
	_check(errors.size() == 1, "应该有1个验证错误")

	print("  ✓ If/Else with Condition 测试通过\n")


## 测试条件缓存功能
func test_condition_cache():
	print("测试 5: Condition 缓存功能")

	var condition_script = load("res://addons/fuse/conditions/variable/compare_variable.gd")
	var condition = condition_script.new()
	add_child(condition)

	# 启用缓存
	condition.enable_cache = true
	condition.cache_duration = 1.0

	condition.variable_name = "test_var"
	condition.comparison_operator = condition.ComparisonOperator.EQUAL
	condition.compare_value = 42

	# 创建执行上下文
	var context = ExecutionContext.new()
	add_child(context)
	context.set_variable("test_var", 42)

	# 第一次检查（应该计算）
	var check_count_before = condition.check_count
	var result1 = condition.check(context)
	var check_count_after = condition.check_count
	print("  第一次检查: 计数增加 = %s" % (check_count_after > check_count_before))
	_check(check_count_after > check_count_before, "第一次检查应该增加计数")

	# 第二次检查（应该使用缓存）
	check_count_before = condition.check_count
	result1 = condition.check(context)
	check_count_after = condition.check_count
	print("  第二次检查（缓存）: 计数增加 = %s (期望: false)" % (check_count_after > check_count_before))
	_check(check_count_after == check_count_before, "第二次检查应该使用缓存")

	# 测试缓存信息
	var cache_info = condition.get_cache_info()
	print("  缓存信息: enabled=%s, valid=%s" % [cache_info["enabled"], cache_info["is_valid"]])
	_check(cache_info["enabled"] == true, "缓存应该启用")

	print("  ✓ Condition 缓存测试通过\n")

