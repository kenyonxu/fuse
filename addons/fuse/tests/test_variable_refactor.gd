extends Node

func _ready():
	print("=== 开始测试 BaseVariable 重构 ===")

	# 测试1: 创建不同类型的变量
	test_create_variables()

	# 测试2: 测试变量值设置和获取
	test_variable_operations()

	# 测试3: 测试工厂方法
	test_factory_methods()

	# 测试4: 测试序列化和反序列化
	test_serialization()

	print("=== 所有测试完成 ===")

func test_create_variables():
	print("\n--- 测试1: 创建不同类型的变量 ---")

	# 测试整数
	var int_var = BaseVariable.create("test_int", 42)
	assert(int_var != null, "整数变量创建失败")
	assert(int_var.variable_name == "test_int", "变量名设置失败")
	assert(int_var.value == 42, "整数值设置失败")
	assert(int_var.get_type_name() == "Int", "整数类型识别失败")
	print("✓ 整数变量创建成功")

	# 测试字符串
	var string_var = BaseVariable.create("test_string", "Hello World")
	assert(string_var != null, "字符串变量创建失败")
	assert(string_var.value == "Hello World", "字符串值设置失败")
	assert(string_var.get_type_name() == "String", "字符串类型识别失败")
	print("✓ 字符串变量创建成功")

	# 测试向量
	var vector_var = BaseVariable.create("test_vector", Vector2(1, 2))
	assert(vector_var != null, "向量变量创建失败")
	assert(vector_var.value == Vector2(1, 2), "向量值设置失败")
	assert(vector_var.get_type_name() == "Vector2", "向量类型识别失败")
	print("✓ 向量变量创建成功")

	# 测试数组
	var array_var = BaseVariable.create("test_array", [1, 2, 3])
	assert(array_var != null, "数组变量创建失败")
	assert(array_var.value == [1, 2, 3], "数组值设置失败")
	assert(array_var.get_type_name() == "Array", "数组类型识别失败")
	print("✓ 数组变量创建成功")

	# 测试字典
	var dict_var = BaseVariable.create("test_dict", {"key": "value"})
	assert(dict_var != null, "字典变量创建失败")
	assert(dict_var.value == {"key": "value"}, "字典值设置失败")
	assert(dict_var.get_type_name() == "Dictionary", "字典类型识别失败")
	print("✓ 字典变量创建成功")

	# 测试 null
	var null_var = BaseVariable.create("test_null", null)
	assert(null_var != null, "null变量创建失败")
	assert(null_var.value == null, "null值设置失败")
	assert(null_var.get_type_name() == "Null", "null类型识别失败")
	print("✓ null变量创建成功")

func test_variable_operations():
	print("\n--- 测试2: 测试变量值设置和获取 ---")

	var variable = BaseVariable.create("test_ops", 10)
	assert(variable != null, "变量创建失败")

	# 测试初始值
	assert(variable.get_value() == 10, "初始值获取失败")
	print("✓ 初始值获取成功")

	# 测试设置新值
	var old_value = variable.value
	variable.set_value(20)
	assert(variable.value == 20, "新值设置失败")
	# 注意：set_value 会增加 modification_count，初始创建也会增加
	assert(variable.modification_count >= 1, "修改计数失败")
	print("✓ 新值设置成功")

	# 测试不同类型
	variable.set_value("new_string")
	assert(variable.value == "new_string", "字符串值设置失败")
	assert(variable.get_type_name() == "String", "类型变化识别失败")
	print("✓ 类型变化成功")

	# 测试比较操作
	variable.set_value(50)
	assert(variable.equals(50) == true, "相等比较失败")
	assert(variable.greater_than(30) == true, "大于比较失败")
	assert(variable.less_than(60) == true, "小于比较失败")
	print("✓ 比较操作成功")

func test_factory_methods():
	print("\n--- 测试3: 测试工厂方法 ---")

	# 测试 create_local
	var local_var = BaseVariable.create_local("local_test", "local_value")
	assert(local_var != null, "局部变量创建失败")
	assert(local_var.scope == BaseVariable.VariableScope.LOCAL, "局部作用域设置失败")
	print("✓ create_local 成功")

	# 测试 create_global
	var global_var = BaseVariable.create_global("global_test", 100, true)
	assert(global_var != null, "全局变量创建失败")
	assert(global_var.scope == BaseVariable.VariableScope.GLOBAL, "全局作用域设置失败")
	assert(global_var.persistent == true, "持久化设置失败")
	print("✓ create_global 成功")

	# 测试游戏常用变量
	var health_var = BaseVariable.create_player_health(100)
	assert(health_var != null, "玩家生命值变量创建失败")
	assert(health_var.variable_name == "player_health", "玩家生命值变量名设置失败")
	assert(health_var.value == 100, "玩家生命值设置失败")
	print("✓ create_player_health 成功")

	var score_var = BaseVariable.create_player_score(0)
	assert(score_var != null, "玩家分数变量创建失败")
	assert(score_var.variable_name == "player_score", "玩家分数变量名设置失败")
	assert(score_var.value == 0, "玩家分数设置失败")
	print("✓ create_player_score 成功")

func test_serialization():
	print("\n--- 测试4: 测试序列化和反序列化 ---")

	var original = BaseVariable.create("serialize_test", {"data": "test"})
	assert(original != null, "原始变量创建失败")
	original.modification_count = 5

	# 序列化
	var data = original.serialize()
	assert(data.has("name"), "序列化缺少名称")
	assert(data.has("value"), "序列化缺少值")
	assert(data.has("persistent"), "序列化缺少持久化信息")
	assert(data["name"] == "serialize_test", "序列化名称错误")
	print("✓ 序列化成功")

	# 反序列化
	var restored = BaseVariable.new()
	restored.deserialize(data)
	assert(restored.variable_name == "serialize_test", "反序列化名称错误")
	assert(restored.value == {"data": "test"}, "反序列化值错误")
	assert(restored.modification_count == 5, "反序列化修改计数错误")
	print("✓ 反序列化成功")

	# 测试克隆
	var cloned = original.clone()
	assert(cloned.variable_name == "serialize_test", "克隆名称错误")
	assert(cloned.value == {"data": "test"}, "克隆值错误")
	assert(cloned.modification_count == 5, "克隆修改计数错误")
	print("✓ 克隆成功")

func test_error_handling():
	print("\n--- 测试5: 错误处理 ---")

	# 测试空名称
	var null_var = BaseVariable.create("", "value")
	assert(null_var == null, "空名称应该返回null")
	print("✓ 空名称验证成功")

	# 测试验证
	var variable = BaseVariable.new()
	var errors = variable.validate_configuration()
	assert(errors.size() == 1, "空名称应该有一个错误")
	assert(errors[0].contains("变量名不能为空"), "错误信息不正确")
	print("✓ 验证功能成功")

func test_performance():
	print("\n--- 测试6: 性能测试 ---")

	var start_time = Time.get_ticks_msec()

	# 创建大量变量
	for i in range(1000):
		var var_name = "perf_test_" + str(i)
		var var_value = i * 2
		var variable = BaseVariable.create(var_name, var_value)
		assert(variable != null, "性能测试变量创建失败")

	var end_time = Time.get_ticks_msec()
	var duration = (end_time - start_time) / 1000.0

	print("✓ 创建1000个变量耗时: %.3f秒" % duration)
	assert(duration < 1.0, "性能测试失败：创建1000个变量耗时过长")
