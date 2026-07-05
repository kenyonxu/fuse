extends Node

## MathExpression 指令测试脚本

var test_results: Array[String] = []
var test_passed: int = 0
var test_failed: int = 0

func _ready():
	print("=== MathExpression 指令测试开始 ===")

	# 运行测试
	_run_all_tests()

	# 显示测试结果
	_show_test_results()

	print("=== MathExpression 指令测试完成 ===")

## 运行所有测试
func _run_all_tests():
	# 基础功能测试
	_test_basic_functionality()

	# 验证测试
	_test_validation()

	# 简单数值表达式测试
	_test_simple_numeric_expressions()

	# 变量引用测试
	_test_variable_references()

	# 数学函数测试
	_test_math_functions()

	# 向量测试
	_test_vector_operations()

	# 输出类型测试
	_test_output_types()

	# 错误处理测试
	_test_error_handling()

## 测试基础功能
func _test_basic_functionality():
	print("\n--- 测试基础功能 ---")

	# 测试1: 创建指令实例
	var instruction = MathExpression.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	if instruction:
		_record_test_result("创建指令实例", true)
	else:
		_record_test_result("创建指令实例", false)
		return

	# 测试2: 设置参数
	instruction.expression = "1 + 2"
	instruction.output_type = MathExpression.OutputType.FLOAT
	instruction.save_to_variable = "test_result"

	if instruction.expression == "1 + 2":
		_record_test_result("设置参数", true)
	else:
		_record_test_result("设置参数", false)

## 测试验证
func _test_validation():
	print("\n--- 测试验证 ---")

	# 测试1: 空表达式
	var instruction = MathExpression.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.expression = ""
	instruction.save_to_variable = "test_result"

	var errors = instruction.validate()
	if errors.size() > 0:
		_record_test_result("验证（空表达式）", true)
	else:
		_record_test_result("验证（空表达式）", false)

	# 测试2: 空变量名
	instruction.expression = "1 + 2"
	instruction.save_to_variable = ""

	errors = instruction.validate()
	if errors.size() > 0:
		_record_test_result("验证（空变量名）", true)
	else:
		_record_test_result("验证（空变量名）", false)

	# 测试3: 有效配置
	instruction.save_to_variable = "result"

	errors = instruction.validate()
	if errors.size() == 0:
		_record_test_result("验证（有效配置）", true)
	else:
		_record_test_result("验证（有效配置）", false)

## 测试简单数值表达式
func _test_simple_numeric_expressions():
	print("\n--- 测试简单数值表达式 ---")

	# 测试1: 加法
	await _test_expression("10 + 5", 15.0, "加法")

	# 测试2: 减法
	await _test_expression("10 - 3", 7.0, "减法")

	# 测试3: 乘法
	await _test_expression("6 * 7", 42.0, "乘法")

	# 测试4: 除法
	await _test_expression("20 / 4", 5.0, "除法")

	# 测试5: 取模
	await _test_expression("17 % 5", 2.0, "取模")

	# 测试6: 括号优先级
	await _test_expression("(2 + 3) * 4", 20.0, "括号优先级")

	# 测试7: 复杂表达式
	await _test_expression("2 + 3 * 4 - 1", 13.0, "复杂表达式")

## 测试变量引用
func _test_variable_references():
	print("\n--- 测试变量引用 ---")

	# 测试1: LOCAL 变量
	var instruction = MathExpression.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.expression = "{local:a} + {local:b}"
	instruction.output_type = MathExpression.OutputType.FLOAT
	instruction.save_to_variable = "result"
	instruction.save_to_scope = BaseVariable.VariableScope.LOCAL

	var context = ExecutionContext.new()
	context.set_variable("a", 10.0)
	context.set_variable("b", 5.0)

	var execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("result"):
		var val = context.get_variable("result")
		if val == 15.0:
			_record_test_result("LOCAL 变量引用", true, "10 + 5 = 15")
		else:
			_record_test_result("LOCAL 变量引用", false, "期望: 15.0, 实际: %s" % str(val))
	else:
		_record_test_result("LOCAL 变量引用", false)

	# 测试2: 变量不存在（使用默认值 0）
	instruction.expression = "{local:missing} + 5"
	instruction.save_to_variable = "result2"

	context = ExecutionContext.new()
	execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("result2"):
		var val = context.get_variable("result2")
		if val == 5.0:
			_record_test_result("变量不存在（默认值）", true, "0 + 5 = 5")
		else:
			_record_test_result("变量不存在（默认值）", false, "期望: 5.0, 实际: %s" % str(val))
	else:
		_record_test_result("变量不存在（默认值）", false)

## 测试数学函数
func _test_math_functions():
	print("\n--- 测试数学函数 ---")

	# 测试1: abs
	await _test_expression("abs(-5)", 5.0, "abs 函数")

	# 测试2: min
	await _test_expression("min(3, 7)", 3.0, "min 函数")

	# 测试3: max
	await _test_expression("max(3, 7)", 7.0, "max 函数")

	# 测试4: round
	await _test_expression("round(3.7)", 4.0, "round 函数")

	# 测试5: floor
	await _test_expression("floor(3.7)", 3.0, "floor 函数")

	# 测试6: ceil
	await _test_expression("ceil(3.2)", 4.0, "ceil 函数")

	# 测试7: sqrt
	await _test_expression("sqrt(16)", 4.0, "sqrt 函数")

	# 测试8: pow
	await _test_expression("pow(2, 3)", 8.0, "pow 函数")

	# 测试9: clamp
	await _test_expression("clamp(150, 0, 100)", 100.0, "clamp 函数")

## 测试向量操作
func _test_vector_operations():
	print("\n--- 测试向量操作 ---")

	# 测试1: vec2 创建
	var instruction = MathExpression.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.expression = "vec2(10, 20)"
	instruction.output_type = MathExpression.OutputType.VECTOR2
	instruction.save_to_variable = "vec_result"

	var context = ExecutionContext.new()
	var execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("vec_result"):
		var val = context.get_variable("vec_result")
		if val is Vector2 and val.x == 10.0 and val.y == 20.0:
			_record_test_result("vec2 创建", true, "vec2(10, 20)")
		else:
			_record_test_result("vec2 创建", false, "实际: %s" % str(val))
	else:
		_record_test_result("vec2 创建", false)

	# 测试2: vec3 创建
	instruction.expression = "vec3(1, 2, 3)"
	instruction.output_type = MathExpression.OutputType.VECTOR3
	instruction.save_to_variable = "vec3_result"

	context = ExecutionContext.new()
	execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("vec3_result"):
		var val = context.get_variable("vec3_result")
		if val is Vector3 and val.x == 1.0 and val.y == 2.0 and val.z == 3.0:
			_record_test_result("vec3 创建", true, "vec3(1, 2, 3)")
		else:
			_record_test_result("vec3 创建", false, "实际: %s" % str(val))
	else:
		_record_test_result("vec3 创建", false)

	# 测试3: 向量加法
	instruction.expression = "{local:pos} + vec2(5, 5)"
	instruction.output_type = MathExpression.OutputType.VECTOR2
	instruction.save_to_variable = "vec_add_result"

	context = ExecutionContext.new()
	context.set_variable("pos", Vector2(10, 10))
	execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("vec_add_result"):
		var val = context.get_variable("vec_add_result")
		if val is Vector2 and val.x == 15.0 and val.y == 15.0:
			_record_test_result("向量加法", true, "vec2(10,10) + vec2(5,5)")
		else:
			_record_test_result("向量加法", false, "实际: %s" % str(val))
	else:
		_record_test_result("向量加法", false)

## 测试输出类型
func _test_output_types():
	print("\n--- 测试输出类型 ---")

	# 测试1: Float 输出
	var instruction = MathExpression.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.expression = "7 / 2"
	instruction.output_type = MathExpression.OutputType.FLOAT
	instruction.save_to_variable = "float_result"

	var context = ExecutionContext.new()
	var execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("float_result"):
		var val = context.get_variable("float_result")
		if val is float and val == 3.5:
			_record_test_result("Float 输出", true, "7 / 2 = 3.5")
		else:
			_record_test_result("Float 输出", false, "期望 float 3.5, 实际: %s (%s)" % [str(val), typeof(val)])
	else:
		_record_test_result("Float 输出", false)

	# 测试2: Int 输出
	instruction.expression = "7 / 2"
	instruction.output_type = MathExpression.OutputType.INT
	instruction.save_to_variable = "int_result"

	context = ExecutionContext.new()
	execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("int_result"):
		var val = context.get_variable("int_result")
		if val is int and val == 3:
			_record_test_result("Int 输出", true, "7 / 2 = 3 (int)")
		else:
			_record_test_result("Int 输出", false, "期望 int 3, 实际: %s (%s)" % [str(val), typeof(val)])
	else:
		_record_test_result("Int 输出", false)

## 测试错误处理
func _test_error_handling():
	print("\n--- 测试错误处理 ---")

	# 测试1: 无效表达式语法
	var instruction = MathExpression.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.expression = "1 + + 2"
	instruction.save_to_variable = "error_result"

	var context = ExecutionContext.new()
	var execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	# 应该完成但有错误
	if execution_result.executed and instruction.has_error():
		_record_test_result("无效表达式语法", true, "正确检测到错误")
	else:
		_record_test_result("无效表达式语法", false)

	# 测试2: 除零
	instruction.expression = "1 / 0"
	instruction.save_to_variable = "div_zero_result"
	instruction.clear_error()

	context = ExecutionContext.new()
	execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	# Godot Expression 不会将除零视为错误，而是返回 inf
	if execution_result.executed:
		var val = context.get_variable("div_zero_result")
		if is_inf(val):
			_record_test_result("除零处理", true, "返回 inf")
		else:
			_record_test_result("除零处理", false, "期望 inf, 实际: %s" % str(val))
	else:
		_record_test_result("除零处理", false)

## 辅助方法：测试表达式
func _test_expression(expr: String, expected: float, test_name: String):
	var instruction = MathExpression.new()
	instruction.log_level = FuseLogger.LogLevel.DEBUG
	instruction.expression = expr
	instruction.output_type = MathExpression.OutputType.FLOAT
	instruction.save_to_variable = "expr_result"

	var context = ExecutionContext.new()
	var execution_result = {"executed": false}
	instruction.finished.connect(func(): execution_result.executed = true)
	instruction.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("expr_result"):
		var val = context.get_variable("expr_result")
		if absf(val - expected) < 0.0001:
			_record_test_result(test_name, true, "%s = %s" % [expr, str(val)])
		else:
			_record_test_result(test_name, false, "%s: 期望 %s, 实际 %s" % [expr, str(expected), str(val)])
	else:
		_record_test_result(test_name, false, "%s: 执行失败" % expr)

## 记录测试结果
func _record_test_result(test_name: String, passed: bool, details: String = ""):
	var status = "PASS" if passed else "FAIL"
	var result = "[%s] %s" % [status, test_name]
	if not details.is_empty():
		result += " - " + details

	test_results.append(result)

	if passed:
		test_passed += 1
	else:
		test_failed += 1

	print(result)

## 显示测试结果
func _show_test_results():
	print("\n=== 测试结果汇总 ===")
	print("通过: %d" % test_passed)
	print("失败: %d" % test_failed)
	print("总计: %d" % (test_passed + test_failed))

	if test_failed > 0:
		print("\n失败的测试:")
		for result in test_results:
			if result.begins_with("[FAIL]"):
				print("  " + result)

	print("\n所有测试详情:")
	for result in test_results:
		print("  " + result)
