extends Node

## CheckVector2VariableAxis 条件测试脚本

func _ready():
	print("=== CheckVector2VariableAxis 条件测试开始 ===\n")

	test_basic_evaluation()
	test_x_axis_check()
	test_y_axis_check()
	test_all_operators()
	test_all_scopes()
	test_negation()
	test_dependencies()
	test_edge_cases()
	test_error_handling()

	print("=== CheckVector2VariableAxis 条件测试完成 ===")
	queue_free()

## 测试基本评估功能
func test_basic_evaluation():
	print("测试 1: 基本评估功能")

	var condition_script = load("res://addons/fuse/conditions/variable/check_vector2_variable_axis.gd")
	var condition = condition_script.new()
	add_child(condition)

	# 设置条件
	condition.variable_name = "input_dir"
	condition.axis = condition.VectorAxis.X_AXIS
	condition.comparison_operator = condition.ComparisonOperator.GREATER_THAN
	condition.compare_value = 0.0

	# 创建执行上下文
	var context = ExecutionContext.new()
	add_child(context)
	context.set_variable("input_dir", Vector2(5.0, 0.0))

	# 测试 X 轴大于 0
	var result = condition.check(context)
	print("  测试 Vector2(5, 0).x > 0.0: %s" % ("✓" if result else "✗"))
	assert(result == true, "Vector2(5, 0).x > 0.0 应该为 true")

	print("  ✓ 基本评估功能测试通过\n")

	condition.queue_free()

## 测试 X 轴检查
func test_x_axis_check():
	print("测试 2: X 轴检查")

	var condition_script = load("res://addons/fuse/conditions/variable/check_vector2_variable_axis.gd")
	var condition = condition_script.new()
	add_child(condition)

	condition.variable_name = "position"
	condition.axis = condition.VectorAxis.X_AXIS
	condition.comparison_operator = condition.ComparisonOperator.EQUAL
	condition.compare_value = 10.5

	var context = ExecutionContext.new()
	add_child(context)
	context.set_variable("position", Vector2(10.5, 20.0))

	var result = condition.check(context)
	print("  测试 Vector2(10.5, 20.0).x == 10.5: %s" % ("✓" if result else "✗"))
	assert(result == true, "Vector2(10.5, 20.0).x == 10.5 应该为 true")

	print("  ✓ X 轴检查测试通过\n")

	condition.queue_free()

## 测试 Y 轴检查
func test_y_axis_check():
	print("测试 3: Y 轴检查")

	var condition_script = load("res://addons/fuse/conditions/variable/check_vector2_variable_axis.gd")
	var condition = condition_script.new()
	add_child(condition)

	condition.variable_name = "velocity"
	condition.axis = condition.VectorAxis.Y_AXIS
	condition.comparison_operator = condition.ComparisonOperator.LESS_THAN
	condition.compare_value = 0.0

	var context = ExecutionContext.new()
	add_child(context)
	context.set_variable("velocity", Vector2(0.0, -5.0))

	var result = condition.check(context)
	print("  测试 Vector2(0, -5).y < 0.0: %s" % ("✓" if result else "✗"))
	assert(result == true, "Vector2(0, -5).y < 0.0 应该为 true")

	print("  ✓ Y 轴检查测试通过\n")

	condition.queue_free()

## 测试所有运算符
func test_all_operators():
	print("测试 4: 所有运算符")

	var condition_script = load("res://addons/fuse/conditions/variable/check_vector2_variable_axis.gd")
	var context = ExecutionContext.new()
	add_child(context)
	context.set_variable("test_vec", Vector2(5.0, 0.0))

	# GREATER_THAN
	var condition = condition_script.new()
	add_child(condition)
	condition.variable_name = "test_vec"
	condition.axis = condition.VectorAxis.X_AXIS
	condition.comparison_operator = condition.ComparisonOperator.GREATER_THAN
	condition.compare_value = 3.0
	var result = condition.check(context)
	print("  测试 > (5.0 > 3.0): %s" % ("✓" if result else "✗"))
	assert(result == true)
	condition.queue_free()

	# GREATER_EQUAL
	condition = condition_script.new()
	add_child(condition)
	condition.variable_name = "test_vec"
	condition.axis = condition.VectorAxis.X_AXIS
	condition.comparison_operator = condition.ComparisonOperator.GREATER_EQUAL
	condition.compare_value = 5.0
	result = condition.check(context)
	print("  测试 >= (5.0 >= 5.0): %s" % ("✓" if result else "✗"))
	assert(result == true)
	condition.queue_free()

	# EQUAL
	condition = condition_script.new()
	add_child(condition)
	condition.variable_name = "test_vec"
	condition.axis = condition.VectorAxis.X_AXIS
	condition.comparison_operator = condition.ComparisonOperator.EQUAL
	condition.compare_value = 5.0
	result = condition.check(context)
	print("  测试 == (5.0 == 5.0): %s" % ("✓" if result else "✗"))
	assert(result == true)
	condition.queue_free()

	# LESS_EQUAL
	condition = condition_script.new()
	add_child(condition)
	condition.variable_name = "test_vec"
	condition.axis = condition.VectorAxis.X_AXIS
	condition.comparison_operator = condition.ComparisonOperator.LESS_EQUAL
	condition.compare_value = 10.0
	result = condition.check(context)
	print("  测试 <= (5.0 <= 10.0): %s" % ("✓" if result else "✗"))
	assert(result == true)
	condition.queue_free()

	# LESS_THAN
	condition = condition_script.new()
	add_child(condition)
	condition.variable_name = "test_vec"
	condition.axis = condition.VectorAxis.X_AXIS
	condition.comparison_operator = condition.ComparisonOperator.LESS_THAN
	condition.compare_value = 10.0
	result = condition.check(context)
	print("  测试 < (5.0 < 10.0): %s" % ("✓" if result else "✗"))
	assert(result == true)
	condition.queue_free()

	print("  ✓ 所有运算符测试通过\n")

## 测试所有作用域
func test_all_scopes():
	print("测试 5: 所有作用域")

	# LOCAL 作用域
	var condition_script = load("res://addons/fuse/conditions/variable/check_vector2_variable_axis.gd")
	var condition = condition_script.new()
	add_child(condition)
	condition.variable_name = "local_vec"
	condition.axis = condition.VectorAxis.X_AXIS
	condition.comparison_operator = condition.ComparisonOperator.GREATER_THAN
	condition.compare_value = 0.0
	condition.variable_scope = BaseVariable.VariableScope.LOCAL

	var context = ExecutionContext.new()
	add_child(context)
	context.set_variable("local_vec", Vector2(5.0, 0.0))

	var result = condition.check(context)
	print("  测试 LOCAL 作用域: %s" % ("✓" if result else "✗"))
	assert(result == true)
	condition.queue_free()

	# SCOPE 作用域
	condition = condition_script.new()
	add_child(condition)
	condition.variable_name = "scope_vec"
	condition.axis = condition.VectorAxis.X_AXIS
	condition.comparison_operator = condition.ComparisonOperator.GREATER_THAN
	condition.compare_value = 0.0
	condition.variable_scope = BaseVariable.VariableScope.SCOPE

	# 创建 ScopeVariableContainer
	var scope_container = ScopeVariableContainer.new()
	add_child(scope_container)
	scope_container.set_variable("scope_vec", Vector2(5.0, 0.0))

	result = condition.check(context)
	print("  测试 SCOPE 作用域: %s" % ("✓" if result else "✗"))
	assert(result == true)
	condition.queue_free()
	scope_container.queue_free()

	print("  ✓ 所有作用域测试通过\n")

## 测试取反功能
func test_negation():
	print("测试 6: 取反功能")

	var condition_script = load("res://addons/fuse/conditions/variable/check_vector2_variable_axis.gd")
	var condition = condition_script.new()
	add_child(condition)

	condition.variable_name = "test_vec"
	condition.axis = condition.VectorAxis.X_AXIS
	condition.comparison_operator = condition.ComparisonOperator.GREATER_THAN
	condition.compare_value = 10.0
	condition.negate_result = true

	var context = ExecutionContext.new()
	add_child(context)
	context.set_variable("test_vec", Vector2(5.0, 0.0))

	var result = condition.check(context)
	print("  测试 !(5.0 > 10.0): %s" % ("✓" if result else "✗"))
	assert(result == true, "!(5.0 > 10.0) 应该为 true")

	print("  ✓ 取反功能测试通过\n")

	condition.queue_free()

## 测试依赖追踪
func test_dependencies():
	print("测试 7: 依赖追踪")

	var condition_script = load("res://addons/fuse/conditions/variable/check_vector2_variable_axis.gd")
	var condition = condition_script.new()
	add_child(condition)

	condition.variable_name = "input_dir"

	var deps = condition.get_dependencies()
	print("  依赖变量: %s" % str(deps))
	assert(deps.size() == 1, "应该有1个依赖")
	assert(deps[0] == "input_dir", "依赖应该是 input_dir")

	print("  ✓ 依赖追踪测试通过\n")

	condition.queue_free()

## 测试边界情况
func test_edge_cases():
	print("测试 8: 边界情况")

	var condition_script = load("res://addons/fuse/conditions/variable/check_vector2_variable_axis.gd")
	var context = ExecutionContext.new()
	add_child(context)

	# 测试零向量
	context.set_variable("zero_vec", Vector2.ZERO)
	var condition = condition_script.new()
	add_child(condition)
	condition.variable_name = "zero_vec"
	condition.axis = condition.VectorAxis.X_AXIS
	condition.comparison_operator = condition.ComparisonOperator.EQUAL
	condition.compare_value = 0.0
	var result = condition.check(context)
	print("  测试零向量 (0.0 == 0.0): %s" % ("✓" if result else "✗"))
	assert(result == true)
	condition.queue_free()

	# 测试负值
	context.set_variable("negative_vec", Vector2(-5.0, -10.0))
	condition = condition_script.new()
	add_child(condition)
	condition.variable_name = "negative_vec"
	condition.axis = condition.VectorAxis.Y_AXIS
	condition.comparison_operator = condition.ComparisonOperator.LESS_THAN
	condition.compare_value = -5.0
	result = condition.check(context)
	print("  测试负值 (-10.0 < -5.0): %s" % ("✓" if result else "✗"))
	assert(result == true)
	condition.queue_free()

	# 测试浮点数精度
	context.set_variable("float_vec", Vector2(0.1 + 0.2, 0.0))
	condition = condition_script.new()
	add_child(condition)
	condition.variable_name = "float_vec"
	condition.axis = condition.VectorAxis.X_AXIS
	condition.comparison_operator = condition.ComparisonOperator.EQUAL
	condition.compare_value = 0.3
	result = condition.check(context)
	print("  测试浮点数精度 (0.3 == 0.3, 使用 is_equal_approx): %s" % ("✓" if result else "✗"))
	assert(result == true, "is_equal_approx 应该处理浮点数精度问题")
	condition.queue_free()

	print("  ✓ 边界情况测试通过\n")

## 测试错误处理
func test_error_handling():
	print("测试 9: 错误处理")

	var condition_script = load("res://addons/fuse/conditions/variable/check_vector2_variable_axis.gd")
	var context = ExecutionContext.new()
	add_child(context)

	# 测试空变量名
	var condition = condition_script.new()
	add_child(condition)
	condition.variable_name = ""
	var errors = condition.validate()
	print("  测试空变量名验证: %s" % ("✓" if not errors.is_empty() else "✗"))
	assert(not errors.is_empty(), "空变量名应该产生验证错误")
	condition.queue_free()

	# 测试不存在的变量
	condition = condition_script.new()
	add_child(condition)
	condition.variable_name = "nonexistent_var"
	condition.axis = condition.VectorAxis.X_AXIS
	condition.comparison_operator = condition.ComparisonOperator.GREATER_THAN
	condition.compare_value = 0.0
	var result = condition.check(context)
	print("  测试不存在的变量: %s" % ("✓" if not result else "✗"))
	assert(result == false, "不存在的变量应该返回 false")
	condition.queue_free()

	# 测试非 Vector2 类型
	context.set_variable("int_var", 42)
	condition = condition_script.new()
	add_child(condition)
	condition.variable_name = "int_var"
	condition.axis = condition.VectorAxis.X_AXIS
	condition.comparison_operator = condition.ComparisonOperator.GREATER_THAN
	condition.compare_value = 0.0
	result = condition.check(context)
	print("  测试非 Vector2 类型: %s" % ("✓" if not result else "✗"))
	assert(result == false, "非 Vector2 类型应该返回 false")
	condition.queue_free()

	print("  ✓ 错误处理测试通过\n")
