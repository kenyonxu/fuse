extends Node
## 测试 CheckVariable 条件类

var check_variable: CheckVariable
var assistant: GlobalVariableAssistant

func _ready():
	print("=== 开始测试 CheckVariable 条件类 ===")
	
	# 初始化 GlobalVariableAssistant 单例（用于测试全局变量功能）
	assistant = GlobalVariableAssistant.get_instance()
	if assistant == null:
		assistant = GlobalVariableAssistant.new()
	
	# 创建测试条件
	check_variable = CheckVariable.new()
	
	#运行测试
	call_deferred("_run_tests")


func _run_tests():
	# 测试 1: 基本等于比较
	_test_equals_comparison()
	
	# 测试 2: 数字比较
	_test_numeric_comparison()
	
	# 测试 3: 字符串比较
	_test_string_comparison()
	
	# 测试 4: 包含操作
	_test_contains_operation()
	
	# 测试 5: 空值检查
	_test_null_check()
	
	# 测试 6: 布尔值检查
	_test_boolean_check()
	
	# 测试 7: 作用域测试
	_test_scope_functionality()
	
	# 测试 8: 类型转换
	_test_type_conversion()
	
	# 测试 9: 验证功能
	_test_validation()
	
	print("=== 所有测试完成 ===")

func _test_equals_comparison():
	print("\n--- 测试 1: 基本等于比较 ---")
	
	var context = ExecutionContext.new()
	
	# 测试字符串相等
	context.set_variable("player_name", "Alice")
	check_variable.variable_name = "player_name"
	check_variable.comparison_operator = CheckVariable.ComparisonOperator.EQUALS
	check_variable.expected_value = "Alice"
	
	var result = check_variable.check(context)
	print("字符串相等测试: %s (期望: true)" % result)
	assert(result == true, "字符串相等测试失败")
	
	# 测试数字相等
	context.set_variable("score", 100)
	check_variable.variable_name = "score"  # 修复：更新变量名
	check_variable.expected_value = 100
	
	result = check_variable.check(context)
	print("数字相等测试: %s (期望: true)" % result)
	assert(result == true, "数字相等测试失败")
	
	# 测试不相等
	check_variable.expected_value = 200
	
	result = check_variable.check(context)
	print("数字不相等测试: %s (期望: false)" % result)
	assert(result == false, "数字不相等测试失败")

func _test_numeric_comparison():
	print("\n--- 测试 2: 数字比较 ---")
	
	var context = ExecutionContext.new()
	context.set_variable("health", 75)
	check_variable.variable_name = "health"
	check_variable.expected_value = 50
	
	# 测试大于
	check_variable.comparison_operator = CheckVariable.ComparisonOperator.GREATER_THAN
	var result = check_variable.check(context)
	print("大于测试 (75 > 50): %s (期望: true)" % result)
	assert(result == true, "大于测试失败")
	
	# 测试小于
	check_variable.comparison_operator = CheckVariable.ComparisonOperator.LESS_THAN
	result = check_variable.check(context)
	print("小于测试 (75 < 50): %s (期望: false)" % result)
	assert(result == false, "小于测试失败")
	
	# 测试大于等于
	check_variable.comparison_operator = CheckVariable.ComparisonOperator.GREATER_EQUAL
	result = check_variable.check(context)
	print("大于等于测试 (75 >= 50): %s (期望: true)" % result)
	assert(result == true, "大于等于测试失败")
	
	# 测试等于
	check_variable.expected_value = 75
	check_variable.comparison_operator = CheckVariable.ComparisonOperator.EQUALS
	result = check_variable.check(context)
	print("等于测试 (75 == 75): %s (期望: true)" % result)
	assert(result == true, "等于测试失败")

func _test_string_comparison():
	print("\n--- 测试 3: 字符串比较 ---")
	
	var context = ExecutionContext.new()
	context.set_variable("message", "Hello World")
	check_variable.variable_name = "message"
	
	# 测试字符串相等（区分大小写）
	check_variable.comparison_operator = CheckVariable.ComparisonOperator.EQUALS
	check_variable.expected_value = "Hello World"
	check_variable.case_sensitive = true
	
	var result = check_variable.check(context)
	print("字符串相等测试: %s (期望: true)" % result)
	assert(result == true, "字符串相等测试失败")
	
	# 测试字符串不相等
	check_variable.expected_value = "hello world"
	result = check_variable.check(context)
	print("字符串不相等测试: %s (期望: false)" % result)
	assert(result == false, "字符串不相等测试失败")
	
	# 测试不区分大小写
	check_variable.case_sensitive = false
	result = check_variable.check(context)
	print("不区分大小写测试: %s (期望: true)" % result)
	assert(result == true, "不区分大小写测试失败")

func _test_contains_operation():
	print("\n--- 测试 4: 包含操作 ---")
	
	var context = ExecutionContext.new()
	context.set_variable("message", "Hello World")
	check_variable.variable_name = "message"
	
	# 测试字符串包含
	check_variable.comparison_operator = CheckVariable.ComparisonOperator.CONTAINS
	check_variable.expected_value = "World"
	
	var result = check_variable.check(context)
	print("字符串包含测试: %s (期望: true)" % result)
	assert(result == true, "字符串包含测试失败")
	
	# 测试不包含
	check_variable.expected_value = "Foo"
	result = check_variable.check(context)
	print("字符串不包含测试: %s (期望: false)" % result)
	assert(result == false, "字符串不包含测试失败")
	
	# 测试数组包含
	context.set_variable("items", ["apple", "banana", "orange"])
	check_variable.variable_name = "items"  # 修复：更新变量名
	check_variable.expected_value = "banana"
	
	result = check_variable.check(context)
	print("数组包含测试: %s (期望: true)" % result)
	assert(result == true, "数组包含测试失败")

func _test_null_check():
	print("\n--- 测试 5: 空值检查 ---")
	
	var context = ExecutionContext.new()
	
	# 测试 IS_NULL
	context.set_variable("optional_value", null)
	check_variable.variable_name = "optional_value"
	check_variable.comparison_operator = CheckVariable.ComparisonOperator.IS_NULL
	
	var result = check_variable.check(context)
	print("IS_NULL 测试: %s (期望: true)" % result)
	assert(result == true, "IS_NULL 测试失败")
	
	# 测试 IS_NOT_NULL
	context.set_variable("optional_value", "some_value")
	check_variable.variable_name = "optional_value"  # 修复：更新变量名
	check_variable.comparison_operator = CheckVariable.ComparisonOperator.IS_NOT_NULL
	
	# 添加调试信息
	var actual_value = context.get_variable("optional_value")
	print("调试: IS_NOT_NULL 测试 - 实际值 = %s (类型: %s)" % [actual_value, typeof(actual_value)])
	
	result = check_variable.check(context)
	print("IS_NOT_NULL 测试: %s (期望: true)" % result)
	assert(result == true, "IS_NOT_NULL 测试失败")
	
	# 测试 IS_EMPTY
	context.set_variable("empty_string", "")
	check_variable.variable_name = "empty_string"  # 修复：更新变量名
	check_variable.comparison_operator = CheckVariable.ComparisonOperator.IS_EMPTY
	
	result = check_variable.check(context)
	print("IS_EMPTY 测试: %s (期望: true)" % result)
	assert(result == true, "IS_EMPTY 测试失败")
	
	# 测试数组为空
	context.set_variable("empty_array", [])
	check_variable.variable_name = "empty_array"  # 修复：更新变量名
	result = check_variable.check(context)
	print("空数组测试: %s (期望: true)" % result)
	assert(result == true, "空数组测试失败")

func _test_boolean_check():
	print("\n--- 测试 6: 布尔值检查 ---")
	
	var context = ExecutionContext.new()
	
	# 测试 IS_TRUE
	context.set_variable("is_active", true)
	check_variable.variable_name = "is_active"
	check_variable.comparison_operator = CheckVariable.ComparisonOperator.IS_TRUE
	
	var result = check_variable.check(context)
	print("IS_TRUE 测试: %s (期望: true)" % result)
	assert(result == true, "IS_TRUE 测试失败")
	
	# 测试 IS_FALSE
	context.set_variable("is_active", false)
	check_variable.variable_name = "is_active"  # 修复：更新变量名
	check_variable.comparison_operator = CheckVariable.ComparisonOperator.IS_FALSE
	
	result = check_variable.check(context)
	print("IS_FALSE 测试: %s (期望: true)" % result)
	assert(result == true, "IS_FALSE 测试失败")
	
	# 测试整数转换为布尔值
	context.set_variable("count", 5)
	check_variable.variable_name = "count"  # 修复：更新变量名
	check_variable.comparison_operator = CheckVariable.ComparisonOperator.IS_TRUE
	
	result = check_variable.check(context)
	print("整数转布尔测试: %s (期望: true)" % result)
	assert(result == true, "整数转布尔测试失败")

func _test_scope_functionality():
	print("\n--- 测试 7: 作用域功能 ---")
	
	var context = ExecutionContext.new()
	
	# 设置局部变量
	context.set_variable("local_var", "local_value", "local")
	
	# 设置全局变量（使用 GlobalVariableAssistant）
	# 注意：这里需要使用 GlobalVariableAssistant 来添加全局变量
	if assistant != null:
		var global_var = BaseVariable.create("global_var", "global_value", BaseVariable.VariableScope.GLOBAL)
		assistant.add_global_variable("global_var", global_var)
	else:
		# 如果没有 assistant，则回退到局部变量模拟
		context.set_variable("global_var", "global_value", "global")
	
	# 测试局部变量
	check_variable.variable_name = "local_var"
	check_variable.variable_scope = BaseVariable.VariableScope.LOCAL
	check_variable.comparison_operator = CheckVariable.ComparisonOperator.EQUALS
	check_variable.expected_value = "local_value"
	
	var result = check_variable.check(context)
	print("局部变量测试: %s (期望: true)" % result)
	assert(result == true, "局部变量测试失败")
	
	# 测试全局变量（现在使用真正的全局变量）
	check_variable.variable_name = "global_var"
	check_variable.variable_scope = BaseVariable.VariableScope.GLOBAL  # 使用全局作用域进行测试
	check_variable.expected_value = "global_value"
	
	result = check_variable.check(context)
	print("全局变量测试: %s (期望: true)" % result)
	assert(result == true, "全局变量测试失败")

func _test_type_conversion():
	print("\n--- 测试 8: 类型转换 ---")
	
	var context = ExecutionContext.new()
	
	# 测试字符串转数字
	context.set_variable("number_str", "42")
	check_variable.variable_name = "number_str"
	check_variable.variable_scope = BaseVariable.VariableScope.LOCAL  # 明确设置为局部作用域
	check_variable.comparison_operator = CheckVariable.ComparisonOperator.EQUALS
	check_variable.expected_value = 42
	check_variable.auto_convert_types = true
	check_variable.log_level = FuseLogger.LogLevel.DEBUG  # 确保显示调试信息
	
	# 添加调试信息
	var actual_value = context.get_variable("number_str")
	print("调试: 字符串转数字测试 - 实际值 = %s (类型: %s), 期望值 = %s (类型: %s)" % [
		str(actual_value), typeof(actual_value),
		str(check_variable.expected_value), typeof(check_variable.expected_value)
	])
	
	var result = check_variable.check(context)
	print("字符串转数字测试: %s (期望: true)" % result)
	assert(result == true, "字符串转数字测试失败")
	
	# 测试数字转字符串
	context.set_variable("actual_number", 42)
	check_variable.variable_name = "actual_number"  # 修复：更新变量名
	check_variable.expected_value = "42"
	
	result = check_variable.check(context)
	print("数字转字符串测试: %s (期望: true)" % result)
	assert(result == true, "数字转字符串测试失败")
	
	# 测试布尔值转换
	context.set_variable("bool_str", "true")
	check_variable.variable_name = "bool_str"  # 修复：更新变量名
	check_variable.expected_value = true
	
	result = check_variable.check(context)
	print("字符串转布尔测试: %s (期望: true)" % result)
	assert(result == true, "字符串转布尔测试失败")

func _test_validation():
	print("\n--- 测试 9: 验证功能 ---")
	
	# 测试空变量名验证
	check_variable.variable_name = ""
	var errors = check_variable.validate()
	print("空变量名验证: %d 个错误 (期望: >0)" % errors.size())
	assert(errors.size() > 0, "空变量名验证失败")
	
	# 测试有效配置
	check_variable.variable_name = "test_var"
	check_variable.variable_scope = BaseVariable.VariableScope.LOCAL
	check_variable.comparison_operator = CheckVariable.ComparisonOperator.EQUALS
	check_variable.expected_value = "test"
	
	errors = check_variable.validate()
	print("有效配置验证: %d 个错误 (期望: 0)" % errors.size())
	assert(errors.size() == 0, "有效配置验证失败")


func _test_edge_cases():
	print("\n--- 测试 10: 边界情况 ---")
	
	var context = ExecutionContext.new()
	
	# 测试不存在的变量
	check_variable.variable_name = "non_existent"
	check_variable.variable_scope = BaseVariable.VariableScope.LOCAL
	check_variable.comparison_operator = CheckVariable.ComparisonOperator.IS_NULL
	
	var result = check_variable.check(context)
	print("不存在的变量 IS_NULL 测试: %s (期望: true)" % result)
	assert(result == true, "不存在的变量 IS_NULL 测试失败")
	
	# 测试模式匹配
	context.set_variable("email", "user@example.com")
	check_variable.variable_name = "email"  # 修复：更新变量名
	check_variable.comparison_operator = CheckVariable.ComparisonOperator.MATCHES_PATTERN
	check_variable.expected_value = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
	
	result = check_variable.check(context)
	print("模式匹配测试: %s (期望: true)" % result)
	assert(result == true, "模式匹配测试失败")
	
	# 测试 NOT_EQUALS
	context.set_variable("status", "active")
	check_variable.variable_name = "status"  # 修复：更新变量名
	check_variable.comparison_operator = CheckVariable.ComparisonOperator.NOT_EQUALS
	check_variable.expected_value = "inactive"
	
	result = check_variable.check(context)
	print("NOT_EQUALS 测试: %s (期望: true)" % result)
	assert(result == true, "NOT_EQUALS 测试失败")

func _test_performance():
	print("\n--- 测试 11: 性能测试 ---")
	
	var context = ExecutionContext.new()
	context.set_variable("counter", 1000)
	
	check_variable.variable_name = "counter"  # 修复：更新变量名
	check_variable.comparison_operator = CheckVariable.ComparisonOperator.EQUALS
	check_variable.expected_value = 1000
	
	var start_time = Time.get_ticks_msec()
	
	# 执行 1000 次检查
	for i in range(1000):
		var result = check_variable.check(context)
		assert(result == true, "性能测试失败")
	
	var end_time = Time.get_ticks_msec()
	var total_time = end_time - start_time
	var avg_time = total_time / 1000.0
	
	print("性能测试: 1000 次检查耗时 %d ms, 平均 %.4f ms/次" % [total_time, avg_time])
	print("性能测试: %s (期望: 平均时间 < 1ms)" % ("通过" if avg_time < 1.0 else "失败"))
