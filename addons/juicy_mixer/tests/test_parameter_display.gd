## Test Parameter Display
## 测试参数显示优化功能
##
## 此测试验证：
## 1. 普通参数的增强显示
## 2. 带默认值的参数显示
## 3. 空参数名的处理
## 4. 中文参数名的支持
## 5. 超长参数名的处理
## 6. 参数名清理功能

extends Node

## 测试结果统计
var tests_passed: int = 0
var tests_failed: int = 0

func _ready():
	print("========================================")
	print("开始测试：参数显示优化")
	print("========================================\n")

	test_normal_parameters()
	test_parameters_with_defaults()
	test_empty_parameter_names()
	test_chinese_parameter_names()
	test_long_parameter_names()
	test_parameter_name_sanitization()
	test_special_hint_preservation()

	# 输出总结
	print("\n========================================")
	print("测试总结")
	print("========================================")
	print("通过: %d" % tests_passed)
	print("失败: %d" % tests_failed)
	if tests_failed == 0:
		print("✅ 所有测试通过!")
	else:
		print("❌ 有 %d 个测试失败" % tests_failed)
	print("========================================")

## 测试 1: 普通参数的增强显示
func test_normal_parameters():
	print("\n--- 测试 1: 普通参数 ---")

	# 创建测试方法信息
	var params = []
	params.append({"name": "position", "type": TYPE_VECTOR2})
	params.append({"name": "speed", "type": TYPE_FLOAT})
	var method_info = create_test_method_info(params)

	var label0 = JuicyParameterEditor._create_enhanced_parameter_label(0, "position", TYPE_VECTOR2, method_info)
	var label1 = JuicyParameterEditor._create_enhanced_parameter_label(1, "speed", TYPE_FLOAT, method_info)

	print("标签 0: %s" % label0)
	print("标签 1: %s" % label1)

	test_assert(label0.contains("position"), "标签应包含参数名 'position'")
	test_assert(label0.contains("Vector2"), "标签应包含类型 'Vector2'")
	tests_passed += 2

	test_assert(label1.contains("speed"), "标签应包含参数名 'speed'")
	test_assert(label1.contains("float"), "标签应包含类型 'float'")
	tests_passed += 2

	print("✓ 普通参数测试通过")

## 测试 2: 带默认值的参数
func test_parameters_with_defaults():
	print("\n--- 测试 2: 带默认值的参数 ---")

	var params = []
	params.append({"name": "count", "type": TYPE_INT, "default": 1})
	params.append({"name": "delay", "type": TYPE_FLOAT, "default": 0.5})
	var method_info = create_test_method_info(params)

	var label0 = JuicyParameterEditor._create_enhanced_parameter_label(0, "count", TYPE_INT, method_info)
	var label1 = JuicyParameterEditor._create_enhanced_parameter_label(1, "delay", TYPE_FLOAT, method_info)

	print("标签 0: %s" % label0)
	print("标签 1: %s" % label1)

	# 验证标签不包含默认值文本（默认值在 Inspector 值框中显示，不在属性名中）
	test_assert(not label0.contains("(默认:"), "标签不应包含默认值文本")
	test_assert(not label1.contains("(默认:"), "标签不应包含默认值文本")
	tests_passed += 2

	# 验证标签包含参数名和类型
	test_assert(label0.contains("count"), "标签应包含参数名 'count'")
	test_assert(label0.contains("int"), "标签应包含类型 'int'")
	test_assert(label1.contains("delay"), "标签应包含参数名 'delay'")
	test_assert(label1.contains("float"), "标签应包含类型 'float'")
	tests_passed += 4

	print("✓ 带默认值参数测试通过")

## 测试 3: 空参数名的处理
func test_empty_parameter_names():
	print("\n--- 测试 3: 空参数名 ---")

	var params = []
	params.append({"name": "", "type": TYPE_INT})
	params.append({"name": "", "type": TYPE_FLOAT})
	var method_info = create_test_method_info(params)

	var label0 = JuicyParameterEditor._create_enhanced_parameter_label(0, "", TYPE_INT, method_info)
	var label1 = JuicyParameterEditor._create_enhanced_parameter_label(1, "", TYPE_FLOAT, method_info)

	print("标签 0: %s" % label0)
	print("标签 1: %s" % label1)

	test_assert(label0.contains("未命名参数"), "空参数名应显示为 '未命名参数'")
	test_assert(label1.contains("未命名参数"), "空参数名应显示为 '未命名参数'")
	tests_passed += 2

	print("✓ 空参数名测试通过")

## 测试 4: 中文参数名的支持
func test_chinese_parameter_names():
	print("\n--- 测试 4: 中文参数名 ---")

	var params = []
	params.append({"name": "目标位置", "type": TYPE_VECTOR2})
	params.append({"name": "速度", "type": TYPE_FLOAT})
	var method_info = create_test_method_info(params)

	var label0 = JuicyParameterEditor._create_enhanced_parameter_label(0, "目标位置", TYPE_VECTOR2, method_info)
	var label1 = JuicyParameterEditor._create_enhanced_parameter_label(1, "速度", TYPE_FLOAT, method_info)

	print("标签 0: %s" % label0)
	print("标签 1: %s" % label1)

	test_assert(label0.contains("目标位置"), "标签应包含中文参数名 '目标位置'")
	test_assert(label1.contains("速度"), "标签应包含中文参数名 '速度'")
	tests_passed += 2

	print("✓ 中文参数名测试通过")

## 测试 5: 超长参数名的处理
func test_long_parameter_names():
	print("\n--- 测试 5: 超长参数名 ---")

	var long_name = "very_long_parameter_name_that_exceeds_normal_length"
	var params = []
	params.append({"name": long_name, "type": TYPE_INT})
	var method_info = create_test_method_info(params)

	var label = JuicyParameterEditor._create_enhanced_parameter_label(0, long_name, TYPE_INT, method_info)

	print("标签: %s" % label)

	test_assert(label.contains(long_name), "标签应包含完整的超长参数名")
	tests_passed += 1

	print("✓ 超长参数名测试通过")

## 测试 6: 参数名清理功能
func test_parameter_name_sanitization():
	print("\n--- 测试 6: 参数名清理 ---")

	var test_cases = []
	test_cases.append({"input": "p_position", "expected": "position"})
	test_cases.append({"input": "param_speed", "expected": "speed"})
	test_cases.append({"input": "_hidden", "expected": "hidden"})
	test_cases.append({"input": "normal", "expected": "normal"})
	test_cases.append({"input": "", "expected": "未命名参数"})

	for test_case in test_cases:
		var sanitized = JuicyParameterEditor._sanitize_parameter_name(test_case.input)
		var passed = sanitized == test_case.expected
		test_assert(passed, "参数名 '%s' 应清理为 '%s'，实际为 '%s'" % [test_case.input, test_case.expected, sanitized])
		if passed:
			tests_passed += 1
		print("  - '%s' -> '%s' %s" % [test_case.input, sanitized, "✓" if passed else "✗"])

	print("✓ 参数名清理测试通过")

## 测试 7: 特殊 hint_string 的保留
func test_special_hint_preservation():
	print("\n--- 测试 7: 特殊 hint_string 保留 ---")

	var params = []
	params.append({"name": "target", "type": TYPE_NODE_PATH})
	var method_info = create_test_method_info(params)

	var special_hint = "Node"
	var label = JuicyParameterEditor._create_enhanced_parameter_label(0, "target", TYPE_NODE_PATH, method_info)

	print("标签: %s" % label)

	test_assert(label.contains("target"), "标签应包含参数名 'target'")
	test_assert(label.contains("NodePath"), "标签应包含类型 'NodePath'")
	tests_passed += 2

	print("✓ 特殊 hint_string 保留测试通过")

## 创建测试方法信息
func create_test_method_info(params: Array) -> JuicyMethodInfo:
	var args = []
	for param in params:
		var arg_info = {
			"name": param.get("name", ""),
			"type": param.get("type", TYPE_NIL),
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "",
			"usage": PROPERTY_USAGE_DEFAULT
		}
		if param.has("default"):
			arg_info["default_value"] = param.get("default")
		args.append(arg_info)

	var method_dict = {
		"name": "test_method",
		"args": args,
		"return": {"type": TYPE_NIL, "hint": PROPERTY_HINT_NONE, "hint_string": "", "usage": PROPERTY_USAGE_DEFAULT},
		"flags": METHOD_FLAG_NORMAL
	}
	return JuicyMethodInfo.new(method_dict)

## 自定义断言函数
func test_assert(condition: bool, message: String):
	if not condition:
		print("❌ 断言失败: %s" % message)
		tests_failed += 1
		# 在编辑器中暂停以便调试
		if OS.is_debug_build():
			push_error(message)
	else:
		print("✓ 断言通过: %s" % message)
