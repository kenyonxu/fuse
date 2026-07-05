extends Node

## ExpressionCondition 条件测试

var test_results: Array[String] = []
var test_passed: int = 0
var test_failed: int = 0

func _ready():
	print("=== ExpressionCondition 测试开始 ===")
	_run_all_tests()
	_show_test_results()
	print("=== ExpressionCondition 测试完成 ===")

func _run_all_tests():
	_test_basic_comparison()
	_test_logical_operators()
	_test_variable_references()
	_test_helper_functions()
	_test_validation()
	_test_error_handling()

func _test_basic_comparison():
	print("\n--- 基础比较测试 ---")
	await _test_condition("10 > 5", {}, true, "大于")
	await _test_condition("3 >= 3", {}, true, "大于等于")
	await _test_condition("1 < 2", {}, true, "小于")
	await _test_condition("5 <= 4", {}, false, "小于等于（假）")
	await _test_condition("5 == 5", {}, true, "等于")
	await _test_condition("5 != 5", {}, false, "不等于（假）")

func _test_logical_operators():
	print("\n--- 逻辑运算测试 ---")
	await _test_condition("true and true", {}, true, "AND 真")
	await _test_condition("true and false", {}, false, "AND 假")
	await _test_condition("false or true", {}, true, "OR 真")
	await _test_condition("false or false", {}, false, "OR 假")
	await _test_condition("not false", {}, true, "NOT")
	await _test_condition("1 > 0 and 2 > 1", {}, true, "复合 AND")
	await _test_condition("1 > 0 or 0 > 1", {}, true, "复合 OR")

func _test_variable_references():
	print("\n--- 变量引用测试 ---")
	await _test_condition("{local:hp} > 0", {"hp": 50.0}, true, "LOCAL 变量（真）")
	await _test_condition("{local:hp} > 0", {"hp": 0.0}, false, "LOCAL 变量（假）")
	await _test_condition("{local:a} > {local:b}", {"a": 10, "b": 5}, true, "双变量比较")
	await _test_condition("{local:x} >= 5 and {local:x} <= 10", {"x": 7}, true, "范围检查")

func _test_helper_functions():
	print("\n--- 辅助函数测试 ---")
	await _test_condition("is_zero(0)", {}, true, "is_zero(0)")
	await _test_condition("is_zero(1)", {}, false, "is_zero(1)")
	await _test_condition("distance(vec2(0,0), vec2(3,4)) < 6", {}, true, "distance")

func _test_validation():
	print("\n--- 验证测试 ---")

	var cond := ExpressionCondition.new()
	cond.log_level = FuseLogger.LogLevel.DEBUG
	cond.expression = ""
	var errors := cond.validate()
	_record("空表达式验证", errors.size() > 0)

	cond.expression = "{local:hp} > 0"
	errors = cond.validate()
	_record("有效表达式验证", errors.is_empty())

	cond.expression = "{invalid:hp}"
	errors = cond.validate()
	_record("无效变量语法验证", errors.size() > 0)

func _test_error_handling():
	print("\n--- 错误处理测试 ---")

	var cond := ExpressionCondition.new()
	cond.log_level = FuseLogger.LogLevel.DEBUG
	cond.expression = "1 + 2"

	var context := ExecutionContext.new()
	var result := cond.check(context)
	_record("非布尔结果返回 false", result == false)

	cond.expression = "1 + +"
	cond.clear_error()
	result = cond.check(context)
	_record("无效语法返回 false", result == false)

func _test_condition(expr: String, variables: Dictionary, expected: bool, name: String):
	var cond := ExpressionCondition.new()
	cond.log_level = FuseLogger.LogLevel.DEBUG
	cond.expression = expr

	var context := ExecutionContext.new()
	for key in variables:
		context.set_variable(key, variables[key])

	var result := cond.check(context)
	_record(name, result == expected)

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
