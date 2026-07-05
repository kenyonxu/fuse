extends Node

## StringExpression 指令测试

var test_results: Array[String] = []
var test_passed: int = 0
var test_failed: int = 0

func _ready():
	print("=== StringExpression 指令测试开始 ===")
	_run_all_tests()
	_show_test_results()
	print("=== StringExpression 指令测试完成 ===")

func _run_all_tests():
	_test_basic_concat()
	_test_variable_interpolation()
	_test_type_conversion()
	_test_helper_functions()
	_test_validation()

func _test_basic_concat():
	print("\n--- 基础拼接测试 ---")
	await _test_string_expression('"Hello" + " " + "World"', "Hello World", "字符串拼接")
	await _test_string_expression('str(42)', "42", "str() 转换")
	await _test_string_expression('"Score: " + str(100)', "Score: 100", "字符串+数值")

func _test_variable_interpolation():
	print("\n--- 变量插值测试 ---")
	await _test_string_expression_with_vars(
		'"Player " + str({local:id}) + " HP:" + str({local:hp})',
		{"id": 1, "hp": 80},
		"Player 1 HP:80",
		"多变量插值"
	)

func _test_type_conversion():
	print("\n--- 类型转换测试 ---")
	await _test_string_expression_with_vars(
		'{local:hp} > 0 ? "Alive" : "Dead"',
		{"hp": 50},
		"Alive",
		"三元运算（真）"
	)
	await _test_string_expression_with_vars(
		'{local:hp} > 0 ? "Alive" : "Dead"',
		{"hp": 0},
		"Dead",
		"三元运算（假）"
	)
	await _test_string_expression_with_vars(
		'{local:a} + {local:b}',
		{"a": 10, "b": 20},
		"30",
		"数值表达式自动转字符串"
	)

func _test_helper_functions():
	print("\n--- 辅助函数测试 ---")
	await _test_string_expression('format_num(3.14159, 2)', "3.14", "format_num")
	await _test_string_expression('pad_left("42", 6, "0")', "000042", "pad_left")
	await _test_string_expression('pad_right("hi", 5, "!")', "hi!!!", "pad_right")

func _test_validation():
	print("\n--- 验证测试 ---")

	var instr := StringExpression.new()
	instr.log_level = FuseLogger.LogLevel.DEBUG
	instr.expression = ""
	instr.save_to_variable = "result"
	var errors := instr.validate()
	_record("空表达式", errors.size() > 0)

	instr.expression = '"hello"'
	instr.save_to_variable = ""
	errors = instr.validate()
	_record("空变量名", errors.size() > 0)

	instr.save_to_variable = "result"
	errors = instr.validate()
	_record("有效配置", errors.is_empty())

func _test_string_expression(expr: String, expected: String, name: String):
	await _test_string_expression_with_vars(expr, {}, expected, name)

func _test_string_expression_with_vars(expr: String, variables: Dictionary, expected: String, name: String):
	var instr := StringExpression.new()
	instr.log_level = FuseLogger.LogLevel.DEBUG
	instr.expression = expr
	instr.save_to_variable = "str_result"

	var context := ExecutionContext.new()
	for key in variables:
		context.set_variable(key, variables[key])

	var execution_result := {"executed": false}
	instr.finished.connect(func(): execution_result.executed = true)
	instr.execute(context)

	await get_tree().create_timer(0.1).timeout

	if execution_result.executed and context.has_variable("str_result"):
		var val = context.get_variable("str_result") as String
		_record(name, val == expected, "期望 '%s', 实际 '%s'" % [expected, val])
	else:
		_record(name, false, "执行失败或变量未设置")

func _record(name: String, passed: bool, details: String = ""):
	var status = "PASS" if passed else "FAIL"
	var s = "[%s] %s" % [status, name]
	if not details.is_empty():
		s += " - " + details
	test_results.append(s)
	if passed:
		test_passed += 1
	else:
		test_failed += 1
	print(s)

func _show_test_results():
	print("\n=== 测试结果汇总 ===")
	print("通过: %d" % test_passed)
	print("失败: %d" % test_failed)
	if test_failed > 0:
		print("\n失败:")
		for r in test_results:
			if r.begins_with("[FAIL]"):
				print("  " + r)
