extends Node

## ExpressionHelper 工具类测试

var test_results: Array[String] = []
var test_passed: int = 0
var test_failed: int = 0

func _ready():
	print("=== ExpressionHelper 测试开始 ===")
	_run_all_tests()
	_show_test_results()
	print("=== ExpressionHelper 测试完成 ===")

func _run_all_tests():
	_test_escape_value()
	_test_escape_value_for_string()
	_test_validate_syntax()
	_test_extract_variable_names()
	_test_evaluate()
	_test_game_expr_helper_math()
	_test_game_expr_helper_vector()
	_test_game_expr_helper_string()

func _test_escape_value():
	print("\n--- escape_value 测试 ---")
	_record("数值 int", ExpressionHelper.escape_value(42) == "42")
	_record("数值 float", ExpressionHelper.escape_value(3.14) == "3.14")
	_record("bool true", ExpressionHelper.escape_value(true) == "1")
	_record("bool false", ExpressionHelper.escape_value(false) == "0")
	_record("Vector2", ExpressionHelper.escape_value(Vector2(1, 2)) == "vec2(1, 2)")
	_record("Vector3", ExpressionHelper.escape_value(Vector3(1, 2, 3)) == "vec3(1, 2, 3)")
	_record("字符串→float", ExpressionHelper.escape_value("hello") == "0")

func _test_escape_value_for_string():
	print("\n--- escape_value_for_string 测试 ---")
	_record("字符串", ExpressionHelper.escape_value_for_string("hello") == '"hello"')
	_record("字符串含引号", ExpressionHelper.escape_value_for_string('say "hi"') == '"say \\"hi\\""')
	_record("bool true", ExpressionHelper.escape_value_for_string(true) == "true")
	_record("数值", ExpressionHelper.escape_value_for_string(42) == "42")
	_record("Vector2", ExpressionHelper.escape_value_for_string(Vector2(1, 2)) == "vec2(1, 2)")

func _test_validate_syntax():
	print("\n--- validate_syntax 测试 ---")
	var errors: Array[String]

	errors = ExpressionHelper.validate_syntax("{local:hp}")
	_record("有效 local 引用", errors.is_empty())

	errors = ExpressionHelper.validate_syntax("{scope:x} + {global:y}")
	_record("有效多引用", errors.is_empty())

	errors = ExpressionHelper.validate_syntax("{invalid:hp}")
	_record("无效作用域类型", errors.size() > 0)

	errors = ExpressionHelper.validate_syntax("{local:123bad}")
	_record("无效变量名", errors.size() > 0)

	errors = ExpressionHelper.validate_syntax("1 + 2")
	_record("无变量引用", errors.is_empty())

func _test_extract_variable_names():
	print("\n--- extract_variable_names 测试 ---")
	var names: Array[String]

	names = ExpressionHelper.extract_variable_names("{local:hp} + {local:max_hp}")
	_record("提取两个变量", names.size() == 2 and "hp" in names and "max_hp" in names)

	names = ExpressionHelper.extract_variable_names("{local:x}")
	_record("去重", names.size() == 1)

	names = ExpressionHelper.extract_variable_names("{local:x} + {scope:x}")
	_record("不同作用域同名", names.size() == 1)

func _test_evaluate():
	print("\n--- evaluate 测试 ---")
	var helper := ExpressionHelper.GameExprHelper.new()
	var error := ""
	var result: Variant

	result = ExpressionHelper.evaluate("1 + 2", helper, error)
	_record("简单加法", result == 3)

	result = ExpressionHelper.evaluate("abs(-5)", helper, error)
	_record("内置函数 abs", result == 5.0)

	result = ExpressionHelper.evaluate("1 + + 2", helper, error)
	_record("无效语法返回 null", result == null and not error.is_empty())

func _test_game_expr_helper_math():
	print("\n--- GameExprHelper 数学函数测试 ---")
	var helper := ExpressionHelper.GameExprHelper.new()
	var error := ""

	var result = ExpressionHelper.evaluate("remap(5, 0, 10, 0, 100)", helper, error)
	_record("remap", result == 50.0)

	result = ExpressionHelper.evaluate("inverse_lerp(0, 10, 5)", helper, error)
	_record("inverse_lerp", result == 0.5)

	result = ExpressionHelper.evaluate("snap(7, 5)", helper, error)
	_record("snap", result == 5.0)

	result = ExpressionHelper.evaluate("is_zero(0)", helper, error)
	_record("is_zero(0)", result == true)
	result = ExpressionHelper.evaluate("is_zero(1)", helper, error)
	_record("is_zero(1)", result == false)

	result = ExpressionHelper.evaluate("move_toward_val(0, 100, 30)", helper, error)
	_record("move_toward_val", result == 30.0)

func _test_game_expr_helper_vector():
	print("\n--- GameExprHelper 向量函数测试 ---")
	var helper := ExpressionHelper.GameExprHelper.new()
	var error := ""
	var result: Variant

	result = ExpressionHelper.evaluate("distance(0, 10)", helper, error)
	_record("distance(数值)", result == 10.0)

	result = ExpressionHelper.evaluate("distance(vec2(0, 0), vec2(3, 4))", helper, error)
	_record("distance(Vector2)", absf(float(result) - 5.0) < 0.001)

	result = ExpressionHelper.evaluate("direction(vec2(0, 0), vec2(10, 0))", helper, error)
	_record("direction(Vector2)", result is Vector2 and result.x == 1.0 and result.y == 0.0)

func _test_game_expr_helper_string():
	print("\n--- GameExprHelper 字符串函数测试 ---")
	var helper := ExpressionHelper.GameExprHelper.new()
	var error := ""
	var result: Variant

	result = ExpressionHelper.evaluate('format_num(3.14159, 2)', helper, error)
	_record("format_num", result == "3.14")

	result = ExpressionHelper.evaluate('pad_left("42", 6, "0")', helper, error)
	_record("pad_left", result == "000042")

	result = ExpressionHelper.evaluate('pad_right("hi", 5, "!")', helper, error)
	_record("pad_right", result == "hi!!!")

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
