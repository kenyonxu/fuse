extends Node
## 测试 CheckArrayContains 条件类

var check_array_contains: CheckArrayContains
var assistant: GlobalVariableAssistant

func _ready():
	print("=== 开始测试 CheckArrayContains 条件类 ===")

	# 初始化 GlobalVariableAssistant 单例（用于测试全局变量功能）
	assistant = GlobalVariableAssistant.get_instance()
	if assistant == null:
		assistant = GlobalVariableAssistant.new()

	# 延迟运行测试以确保所有单例都已初始化
	call_deferred("_run_tests")


func _run_tests():
	# 测试 1: 基本包含测试 - 元素存在
	_test_contains_true()

	# 测试 2: 基本包含测试 - 元素不存在
	_test_contains_false()

	# 测试 3: 字符串数组测试
	_test_string_array()

	# 测试 4: 空数组测试
	_test_empty_array()

	# 测试 5: 全局变量作用域测试
	_test_global_scope()

	# 测试 6: 本地变量作用域测试
	_test_local_scope()

	# 测试 7: 不同类型测试
	_test_different_types()

	# 测试 8: PackedArray 测试
	_test_packed_array()

	# 测试 9: 错误处理测试
	_test_error_handling()

	# 测试 10: 验证测试
	_test_validation()

	# 测试 11: 条件取反测试
	_test_negate_result()

	# 测试 12: 重置测试
	_test_reset()

	# 测试 13: 依赖计算测试
	_test_dependencies()

	print("=== 所有 CheckArrayContains 测试完成 ===")


#region 基础测试

func _test_contains_true():
	print("\n--- 测试 1: 基本包含测试 - 元素存在 ---")

	var context = ExecutionContext.new()
	VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3])

	check_array_contains = CheckArrayContains.new()
	check_array_contains.array_variable = "my_array"
	check_array_contains.array_scope = BaseVariable.VariableScope.LOCAL
	check_array_contains.search_value = 2

	var result = check_array_contains.check(context)
	assert(result == true, "应该返回 true 当元素存在于数组中")
	print("✓ 元素 2 存在于数组 [1, 2, 3] 中: %s" % result)


func _test_contains_false():
	print("\n--- 测试 2: 基本包含测试 - 元素不存在 ---")

	var context = ExecutionContext.new()
	VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3])

	check_array_contains = CheckArrayContains.new()
	check_array_contains.array_variable = "my_array"
	check_array_contains.array_scope = BaseVariable.VariableScope.LOCAL
	check_array_contains.search_value = 999

	var result = check_array_contains.check(context)
	assert(result == false, "应该返回 false 当元素不存在于数组中")
	print("✓ 元素 999 不存在于数组 [1, 2, 3] 中: %s" % result)


func _test_string_array():
	print("\n--- 测试 3: 字符串数组测试 ---")

	var context = ExecutionContext.new()
	VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, ["apple", "banana", "cherry"])

	# 测试存在的字符串
	check_array_contains = CheckArrayContains.new()
	check_array_contains.array_variable = "my_array"
	check_array_contains.array_scope = BaseVariable.VariableScope.LOCAL
	check_array_contains.search_value = "banana"

	var result = check_array_contains.check(context)
	assert(result == true, "应该返回 true 当字符串存在")
	print("✓ 字符串 'banana' 存在于数组中: %s" % result)

	# 测试不存在的字符串
	check_array_contains.search_value = "orange"
	result = check_array_contains.check(context)
	assert(result == false, "应该返回 false 当字符串不存在")
	print("✓ 字符串 'orange' 不存在于数组中: %s" % result)

#endregion

#region 空数组测试

func _test_empty_array():
	print("\n--- 测试 4: 空数组测试 ---")

	var context = ExecutionContext.new()
	VariableOperations.set_variable(context, "empty_array", BaseVariable.VariableScope.LOCAL, [])

	check_array_contains = CheckArrayContains.new()
	check_array_contains.array_variable = "empty_array"
	check_array_contains.array_scope = BaseVariable.VariableScope.LOCAL
	check_array_contains.search_value = 1

	var result = check_array_contains.check(context)
	assert(result == false, "空数组应该不包含任何元素")
	print("✓ 空数组不包含元素 1: %s" % result)

#endregion

#region 变量作用域测试

func _test_global_scope():
	print("\n--- 测试 5: 全局变量作用域测试 ---")

	var context = ExecutionContext.new()
	VariableOperations.set_variable(context, "global_array", BaseVariable.VariableScope.GLOBAL, [10, 20, 30])

	check_array_contains = CheckArrayContains.new()
	check_array_contains.array_variable = "global_array"
	check_array_contains.array_scope = BaseVariable.VariableScope.GLOBAL
	check_array_contains.search_value = 20

	var result = check_array_contains.check(context)
	assert(result == true, "全局变量作用域应该正常工作")
	print("✓ 全局变量数组包含 20: %s" % result)


func _test_local_scope():
	print("\n--- 测试 6: 本地变量作用域测试 ---")

	var context = ExecutionContext.new()
	VariableOperations.set_variable(context, "local_array", BaseVariable.VariableScope.LOCAL, [5, 6, 7])

	check_array_contains = CheckArrayContains.new()
	check_array_contains.array_variable = "local_array"
	check_array_contains.array_scope = BaseVariable.VariableScope.LOCAL
	check_array_contains.search_value = 6

	var result = check_array_contains.check(context)
	assert(result == true, "本地变量作用域应该正常工作")
	print("✓ 本地变量数组包含 6: %s" % result)

#endregion

#region 类型测试

func _test_different_types():
	print("\n--- 测试 7: 不同类型测试 ---")

	var context = ExecutionContext.new()

	# 浮点数数组
	VariableOperations.set_variable(context, "float_array", BaseVariable.VariableScope.LOCAL, [1.5, 2.5, 3.5])
	check_array_contains = CheckArrayContains.new()
	check_array_contains.array_variable = "float_array"
	check_array_contains.array_scope = BaseVariable.VariableScope.LOCAL
	check_array_contains.search_value = 2.5

	var result = check_array_contains.check(context)
	assert(result == true, "浮点数数组应该正常工作")
	print("✓ 浮点数数组包含 2.5: %s" % result)

	# 布尔值数组
	VariableOperations.set_variable(context, "bool_array", BaseVariable.VariableScope.LOCAL, [true, false, true])
	check_array_contains.array_variable = "bool_array"
	check_array_contains.search_value = false

	result = check_array_contains.check(context)
	assert(result == true, "布尔值数组应该正常工作")
	print("✓ 布尔值数组包含 false: %s" % result)

	# 包含 null 的数组
	var array_with_null: Array = [1, null, 3]
	VariableOperations.set_variable(context, "null_array", BaseVariable.VariableScope.LOCAL, array_with_null)
	check_array_contains.array_variable = "null_array"
	check_array_contains.search_value = null

	result = check_array_contains.check(context)
	assert(result == true, "包含 null 的数组应该能找到 null")
	print("✓ 数组包含 null: %s" % result)

#endregion

#region PackedArray 测试

func _test_packed_array():
	print("\n--- 测试 8: PackedArray 测试 ---")

	var context = ExecutionContext.new()

	# PackedInt32Array
	var packed := PackedInt32Array([1, 2, 3, 4, 5])
	VariableOperations.set_variable(context, "packed_array", BaseVariable.VariableScope.LOCAL, packed)

	check_array_contains = CheckArrayContains.new()
	check_array_contains.array_variable = "packed_array"
	check_array_contains.array_scope = BaseVariable.VariableScope.LOCAL
	check_array_contains.search_value = 3

	var result = check_array_contains.check(context)
	assert(result == true, "PackedInt32Array 应该正常工作")
	print("✓ PackedInt32Array 包含 3: %s" % result)

	# PackedStringArray
	var packed_str := PackedStringArray(["hello", "world"])
	VariableOperations.set_variable(context, "packed_str_array", BaseVariable.VariableScope.LOCAL, packed_str)
	check_array_contains.array_variable = "packed_str_array"
	check_array_contains.search_value = "world"

	result = check_array_contains.check(context)
	assert(result == true, "PackedStringArray 应该正常工作")
	print("✓ PackedStringArray 包含 'world': %s" % result)

#endregion

#region 错误处理测试

func _test_error_handling():
	print("\n--- 测试 9: 错误处理测试 ---")

	var context = ExecutionContext.new()

	# 变量不存在
	check_array_contains = CheckArrayContains.new()
	check_array_contains.array_variable = "non_existent_array"
	check_array_contains.array_scope = BaseVariable.VariableScope.LOCAL
	check_array_contains.search_value = 1

	var result = check_array_contains.check(context)
	assert(result == false, "变量不存在时应该返回 false")
	print("✓ 变量不存在时返回 false: %s" % result)

	# 变量名为空
	check_array_contains.array_variable = ""
	result = check_array_contains.check(context)
	assert(result == false, "变量名为空时应该返回 false")
	print("✓ 变量名为空时返回 false: %s" % result)

	# 非数组类型变量
	VariableOperations.set_variable(context, "not_an_array", BaseVariable.VariableScope.LOCAL, "hello")
	check_array_contains.array_variable = "not_an_array"
	check_array_contains.search_value = "e"

	result = check_array_contains.check(context)
	assert(result == false, "非数组类型变量应该返回 false")
	print("✓ 非数组类型变量返回 false: %s" % result)

#endregion

#region 验证测试

func _test_validation():
	print("\n--- 测试 10: 验证测试 ---")

	# 空变量名验证
	check_array_contains = CheckArrayContains.new()
	check_array_contains.source_type = CheckArrayContains.SourceType.VARIABLE
	check_array_contains.array_variable = ""

	var errors = check_array_contains.validate()
	assert(errors.size() > 0, "空变量名应该有验证错误")
	print("✓ 空变量名验证错误数: %d" % errors.size())

	# 有效配置验证
	check_array_contains.array_variable = "my_array"
	check_array_contains.array_scope = BaseVariable.VariableScope.LOCAL

	errors = check_array_contains.validate()
	assert(errors.size() == 0, "有效配置应该没有验证错误")
	print("✓ 有效配置验证通过")

	# 空组名验证
	check_array_contains.source_type = CheckArrayContains.SourceType.NODE_GROUP
	check_array_contains.group_name = ""

	errors = check_array_contains.validate()
	assert(errors.size() > 0, "空组名应该有验证错误")
	print("✓ 空组名验证错误数: %d" % errors.size())

	# 空节点路径验证
	check_array_contains.source_type = CheckArrayContains.SourceType.NODE_CHILDREN
	check_array_contains.target_node_path = NodePath("")

	errors = check_array_contains.validate()
	assert(errors.size() > 0, "空节点路径应该有验证错误")
	print("✓ 空节点路径验证错误数: %d" % errors.size())

#endregion

#region 条件取反测试

func _test_negate_result():
	print("\n--- 测试 11: 条件取反测试 ---")

	var context = ExecutionContext.new()
	VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3])

	# 测试结果为 true 时取反
	check_array_contains = CheckArrayContains.new()
	check_array_contains.array_variable = "my_array"
	check_array_contains.array_scope = BaseVariable.VariableScope.LOCAL
	check_array_contains.search_value = 2
	check_array_contains.negate_result = true

	var result = check_array_contains.check(context)
	assert(result == false, "取反后 true 应该变成 false")
	print("✓ 结果 true 取反后: %s" % result)

	# 测试结果为 false 时取反
	check_array_contains.search_value = 999
	result = check_array_contains.check(context)
	assert(result == true, "取反后 false 应该变成 true")
	print("✓ 结果 false 取反后: %s" % result)

#endregion

#region 重置测试

func _test_reset():
	print("\n--- 测试 12: 重置测试 ---")

	var context = ExecutionContext.new()
	VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3])

	check_array_contains = CheckArrayContains.new()
	check_array_contains.array_variable = "my_array"
	check_array_contains.array_scope = BaseVariable.VariableScope.LOCAL
	check_array_contains.search_value = 2

	# 执行检查
	check_array_contains.check(context)

	# 验证内部状态已设置
	assert(check_array_contains._last_array != null, "检查后 _last_array 应该被设置")
	assert(check_array_contains._last_contains_result == true, "检查后 _last_contains_result 应该为 true")
	print("✓ 检查后内部状态已设置")

	# 重置
	check_array_contains.reset()

	# 验证内部状态已清除
	assert(check_array_contains._last_array == null, "重置后 _last_array 应该为 null")
	assert(check_array_contains._last_contains_result == false, "重置后 _last_contains_result 应该为 false")
	print("✓ 重置后内部状态已清除")

#endregion

#region 依赖计算测试

func _test_dependencies():
	print("\n--- 测试 13: 依赖计算测试 ---")

	# 测试有效变量名
	check_array_contains = CheckArrayContains.new()
	check_array_contains.source_type = CheckArrayContains.SourceType.VARIABLE
	check_array_contains.array_variable = "my_array"

	var deps = check_array_contains._compute_dependencies()
	assert(deps.size() == 1, "应该有一个依赖")
	assert(deps[0] == "my_array", "依赖应该是数组变量名")
	print("✓ 有效变量名依赖: %s" % str(deps))

	# 测试空变量名
	check_array_contains.array_variable = ""
	deps = check_array_contains._compute_dependencies()
	assert(deps.size() == 0, "空变量名应该没有依赖")
	print("✓ 空变量名依赖数: %d" % deps.size())

	# 测试节点子节点源类型
	check_array_contains.source_type = CheckArrayContains.SourceType.NODE_CHILDREN
	check_array_contains.target_node_path = NodePath("TargetNode")

	deps = check_array_contains._compute_dependencies()
	assert(deps.size() == 0, "节点子节点源类型应该没有依赖")
	print("✓ 节点子节点源类型依赖数: %d" % deps.size())

#endregion
