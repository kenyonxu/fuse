extends Node
## 测试 CheckArraySize 条件类

var check_array_size: CheckArraySize
var assistant: GlobalVariableAssistant

func _ready():
	print("=== 开始测试 CheckArraySize 条件类 ===")

	# 初始化 GlobalVariableAssistant 单例（用于测试全局变量功能）
	assistant = GlobalVariableAssistant.get_instance()
	if assistant == null:
		assistant = GlobalVariableAssistant.new()

	# 创建测试条件
	check_array_size = CheckArraySize.new()

	# 延迟运行测试以确保所有单例都已初始化
	call_deferred("_run_tests")


func _run_tests():
	# 测试 1: 基本等于比较
	_test_equals_comparison()

	# 测试 2: 数字比较
	_test_numeric_comparison()

	# 测试 3: 变量源类型测试
	_test_variable_source()

	# 测试 4: 全局变量测试
	_test_global_variable()

	# 测试 5: 作用域测试
	_test_scope_functionality()

	# 测试 6: 验证功能
	_test_validation()

	# 测试 7: 边界情况
	_test_edge_cases()

	print("=== 所有测试完成 ===")


func test_check_array_size_greater():
	print("\n--- 测试: 大于比较 ---")

	var context = ExecutionContext.new()
	VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3, 4, 5])

	check_array_size.source_type = CheckArraySize.SourceType.VARIABLE
	check_array_size.array_variable = "my_array"
	check_array_size.array_scope = BaseVariable.VariableScope.LOCAL
	check_array_size.comparison = CheckArraySize.Comparison.GREATER_THAN
	check_array_size.compare_value = 3

	var result = check_array_size.check(context)
	print("大于测试 (5 > 3): %s (期望: true)" % result)
	assert(result == true, "大于测试失败")


func test_check_array_size_equals():
	print("\n--- 测试: 等于比较 ---")

	var context = ExecutionContext.new()
	VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3])

	check_array_size.source_type = CheckArraySize.SourceType.VARIABLE
	check_array_size.array_variable = "my_array"
	check_array_size.array_scope = BaseVariable.VariableScope.LOCAL
	check_array_size.comparison = CheckArraySize.Comparison.EQUALS
	check_array_size.compare_value = 3

	var result = check_array_size.check(context)
	print("等于测试 (3 == 3): %s (期望: true)" % result)
	assert(result == true, "等于测试失败")


func test_check_array_size_less():
	print("\n--- 测试: 小于比较 ---")

	var context = ExecutionContext.new()
	VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2])

	check_array_size.source_type = CheckArraySize.SourceType.VARIABLE
	check_array_size.array_variable = "my_array"
	check_array_size.array_scope = BaseVariable.VariableScope.LOCAL
	check_array_size.comparison = CheckArraySize.Comparison.LESS_THAN
	check_array_size.compare_value = 5

	var result = check_array_size.check(context)
	print("小于测试 (2 < 5): %s (期望: true)" % result)
	assert(result == true, "小于测试失败")


func _test_equals_comparison():
	print("\n--- 测试 1: 基本等于比较 ---")

	var context = ExecutionContext.new()
	VariableOperations.set_variable(context, "items", BaseVariable.VariableScope.LOCAL, ["apple", "banana", "orange"])

	check_array_size.source_type = CheckArraySize.SourceType.VARIABLE
	check_array_size.array_variable = "items"
	check_array_size.array_scope = BaseVariable.VariableScope.LOCAL
	check_array_size.comparison = CheckArraySize.Comparison.EQUALS
	check_array_size.compare_value = 3

	var result = check_array_size.check(context)
	print("等于测试 (3 == 3): %s (期望: true)" % result)
	assert(result == true, "等于测试失败")

	# 测试不等于
	check_array_size.compare_value = 5
	result = check_array_size.check(context)
	print("不等于测试 (3 != 5, 使用 EQUALS): %s (期望: false)" % result)
	assert(result == false, "不等于测试失败")


func _test_numeric_comparison():
	print("\n--- 测试 2: 数字比较 ---")

	var context = ExecutionContext.new()
	VariableOperations.set_variable(context, "numbers", BaseVariable.VariableScope.LOCAL, [1, 2, 3, 4, 5, 6, 7])

	check_array_size.source_type = CheckArraySize.SourceType.VARIABLE
	check_array_size.array_variable = "numbers"
	check_array_size.array_scope = BaseVariable.VariableScope.LOCAL
	check_array_size.compare_value = 5

	# 测试大于
	check_array_size.comparison = CheckArraySize.Comparison.GREATER_THAN
	var result = check_array_size.check(context)
	print("大于测试 (7 > 5): %s (期望: true)" % result)
	assert(result == true, "大于测试失败")

	# 测试小于
	check_array_size.comparison = CheckArraySize.Comparison.LESS_THAN
	result = check_array_size.check(context)
	print("小于测试 (7 < 5): %s (期望: false)" % result)
	assert(result == false, "小于测试失败")

	# 测试大于等于
	check_array_size.comparison = CheckArraySize.Comparison.GREATER_OR_EQUAL
	result = check_array_size.check(context)
	print("大于等于测试 (7 >= 5): %s (期望: true)" % result)
	assert(result == true, "大于等于测试失败")

	# 测试小于等于
	check_array_size.comparison = CheckArraySize.Comparison.LESS_OR_EQUAL
	result = check_array_size.check(context)
	print("小于等于测试 (7 <= 5): %s (期望: false)" % result)
	assert(result == false, "小于等于测试失败")

	# 测试边界情况：等于
	check_array_size.comparison = CheckArraySize.Comparison.EQUALS
	check_array_size.compare_value = 7
	result = check_array_size.check(context)
	print("等于边界测试 (7 == 7): %s (期望: true)" % result)
	assert(result == true, "等于边界测试失败")

	# 测试 NOT_EQUALS
	check_array_size.comparison = CheckArraySize.Comparison.NOT_EQUALS
	check_array_size.compare_value = 5
	result = check_array_size.check(context)
	print("不等于测试 (7 != 5): %s (期望: true)" % result)
	assert(result == true, "不等于测试失败")


func _test_variable_source():
	print("\n--- 测试 3: 变量源类型测试 ---")

	var context = ExecutionContext.new()

	# 测试空数组
	VariableOperations.set_variable(context, "empty_array", BaseVariable.VariableScope.LOCAL, [])

	check_array_size.source_type = CheckArraySize.SourceType.VARIABLE
	check_array_size.array_variable = "empty_array"
	check_array_size.array_scope = BaseVariable.VariableScope.LOCAL
	check_array_size.comparison = CheckArraySize.Comparison.EQUALS
	check_array_size.compare_value = 0

	var result = check_array_size.check(context)
	print("空数组测试 (0 == 0): %s (期望: true)" % result)
	assert(result == true, "空数组测试失败")

	# 测试大数组
	var large_array: Array = []
	for i in range(100):
		large_array.append(i)
	VariableOperations.set_variable(context, "large_array", BaseVariable.VariableScope.LOCAL, large_array)

	check_array_size.array_variable = "large_array"
	check_array_size.compare_value = 100
	result = check_array_size.check(context)
	print("大数组测试 (100 == 100): %s (期望: true)" % result)
	assert(result == true, "大数组测试失败")

	# 测试 PackedArray
	var packed_array: PackedInt32Array = [1, 2, 3, 4]
	VariableOperations.set_variable(context, "packed", BaseVariable.VariableScope.LOCAL, packed_array)

	check_array_size.array_variable = "packed"
	check_array_size.compare_value = 4
	result = check_array_size.check(context)
	print("PackedArray 测试 (4 == 4): %s (期望: true)" % result)
	assert(result == true, "PackedArray 测试失败")


func _test_global_variable():
	print("\n--- 测试 4: 全局变量测试 ---")

	var context = ExecutionContext.new()

	# 设置全局变量
	VariableOperations.set_variable(context, "global_items", BaseVariable.VariableScope.GLOBAL, ["a", "b", "c"])

	check_array_size.source_type = CheckArraySize.SourceType.VARIABLE
	check_array_size.array_variable = "global_items"
	check_array_size.array_scope = BaseVariable.VariableScope.GLOBAL
	check_array_size.comparison = CheckArraySize.Comparison.EQUALS
	check_array_size.compare_value = 3

	var result = check_array_size.check(context)
	print("全局变量测试 (3 == 3): %s (期望: true)" % result)
	assert(result == true, "全局变量测试失败")


func _test_scope_functionality():
	print("\n--- 测试 5: 作用域功能测试 ---")

	var context = ExecutionContext.new()

	# 测试局部变量
	VariableOperations.set_variable(context, "local_array", BaseVariable.VariableScope.LOCAL, [1, 2])

	check_array_size.source_type = CheckArraySize.SourceType.VARIABLE
	check_array_size.array_variable = "local_array"
	check_array_size.array_scope = BaseVariable.VariableScope.LOCAL
	check_array_size.comparison = CheckArraySize.Comparison.EQUALS
	check_array_size.compare_value = 2

	var result = check_array_size.check(context)
	print("局部变量测试 (2 == 2): %s (期望: true)" % result)
	assert(result == true, "局部变量测试失败")

	# 测试全局变量与局部变量隔离
	VariableOperations.set_variable(context, "scope_test", BaseVariable.VariableScope.LOCAL, [1])
	VariableOperations.set_variable(context, "scope_test", BaseVariable.VariableScope.GLOBAL, [1, 2, 3])

	# 检查局部变量
	check_array_size.array_variable = "scope_test"
	check_array_size.array_scope = BaseVariable.VariableScope.LOCAL
	check_array_size.compare_value = 1
	result = check_array_size.check(context)
	print("局部作用域隔离测试 (1 == 1): %s (期望: true)" % result)
	assert(result == true, "局部作用域隔离测试失败")

	# 检查全局变量
	check_array_size.array_scope = BaseVariable.VariableScope.GLOBAL
	check_array_size.compare_value = 3
	result = check_array_size.check(context)
	print("全局作用域隔离测试 (3 == 3): %s (期望: true)" % result)
	assert(result == true, "全局作用域隔离测试失败")


func _test_validation():
	print("\n--- 测试 6: 验证功能 ---")

	# 测试空数组变量名验证（VARIABLE 模式）
	check_array_size.source_type = CheckArraySize.SourceType.VARIABLE
	check_array_size.array_variable = ""
	check_array_size.array_scope = BaseVariable.VariableScope.LOCAL

	var errors = check_array_size.validate()
	print("空数组变量名验证: %d 个错误 (期望: >0)" % errors.size())
	assert(errors.size() > 0, "空数组变量名验证失败")

	# 测试有效配置
	check_array_size.array_variable = "valid_array"
	errors = check_array_size.validate()
	print("有效配置验证: %d 个错误 (期望: 0)" % errors.size())
	assert(errors.size() == 0, "有效配置验证失败")

	# 测试 NODE_CHILDREN 模式空路径验证
	check_array_size.source_type = CheckArraySize.SourceType.NODE_CHILDREN
	check_array_size.target_node_path = NodePath("")
	errors = check_array_size.validate()
	print("空节点路径验证: %d 个错误 (期望: >0)" % errors.size())
	assert(errors.size() > 0, "空节点路径验证失败")

	# 测试 NODE_GROUP 模式空组名验证
	check_array_size.source_type = CheckArraySize.SourceType.NODE_GROUP
	check_array_size.group_name = ""
	errors = check_array_size.validate()
	print("空组名验证: %d 个错误 (期望: >0)" % errors.size())
	assert(errors.size() > 0, "空组名验证失败")


func _test_edge_cases():
	print("\n--- 测试 7: 边界情况 ---")

	var context = ExecutionContext.new()

	# 测试不存在的变量
	check_array_size.source_type = CheckArraySize.SourceType.VARIABLE
	check_array_size.array_variable = "non_existent"
	check_array_size.array_scope = BaseVariable.VariableScope.LOCAL
	check_array_size.comparison = CheckArraySize.Comparison.EQUALS
	check_array_size.compare_value = 0

	var result = check_array_size.check(context)
	print("不存在的变量测试: %s (期望: false)" % result)
	assert(result == false, "不存在的变量测试失败")

	# 测试非数组类型变量
	VariableOperations.set_variable(context, "not_array", BaseVariable.VariableScope.LOCAL, "I am a string")
	check_array_size.array_variable = "not_array"
	result = check_array_size.check(context)
	print("非数组类型测试: %s (期望: false)" % result)
	assert(result == false, "非数组类型测试失败")

	# 测试 null 值变量
	VariableOperations.set_variable(context, "null_var", BaseVariable.VariableScope.LOCAL, null)
	check_array_size.array_variable = "null_var"
	result = check_array_size.check(context)
	print("null 值测试: %s (期望: false)" % result)
	assert(result == false, "null 值测试失败")

	# 测试单元素数组
	VariableOperations.set_variable(context, "single", BaseVariable.VariableScope.LOCAL, [42])
	check_array_size.array_variable = "single"
	check_array_size.comparison = CheckArraySize.Comparison.EQUALS
	check_array_size.compare_value = 1
	result = check_array_size.check(context)
	print("单元素数组测试 (1 == 1): %s (期望: true)" % result)
	assert(result == true, "单元素数组测试失败")

	# 测试 disabled 条件
	VariableOperations.set_variable(context, "test_disabled", BaseVariable.VariableScope.LOCAL, [1, 2, 3])
	check_array_size.array_variable = "test_disabled"
	check_array_size.enabled = false
	result = check_array_size.check(context)
	print("禁用条件测试: %s (期望: false)" % result)
	assert(result == false, "禁用条件测试失败")

	# 恢复 enabled
	check_array_size.enabled = true

	# 测试 negate_result
	check_array_size.comparison = CheckArraySize.Comparison.EQUALS
	check_array_size.compare_value = 3
	check_array_size.negate_result = true
	result = check_array_size.check(context)
	print("取反结果测试 (3 == 3, negate): %s (期望: false)" % result)
	assert(result == false, "取反结果测试失败")

	# 恢复 negate_result
	check_array_size.negate_result = false

	print("\n所有边界情况测试通过!")
