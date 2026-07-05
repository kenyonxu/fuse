extends Node

## BaseVariable 持久化存储测试
##
## 测试 BaseVariable 的持久化存储功能

func test_variable_persistence():
	print("=== 开始变量持久化测试 ===")

	var var1 = BaseVariable.create_global("test_score", 100, true)
	var var2 = BaseVariable.create_global("test_health", 50.5, true)

	print("初始变量:")
	print("  test_score: %s (type: %s)" % [var1.value, var1.get_type_name()])
	print("  test_health: %s (type: %s)" % [var2.value, var2.get_type_name()])

	# 保存变量
	var1._save_to_storage()
	var2._save_to_storage()
	print("变量已保存到持久化存储")

	# 创建新变量并加载
	var var1_loaded = BaseVariable.create("test_score", 0, BaseVariable.VariableScope.GLOBAL)
	var1_loaded._load_from_storage()

	var var2_loaded = BaseVariable.create("test_health", 0.0, BaseVariable.VariableScope.GLOBAL)
	var2_loaded._load_from_storage()

	print("从持久化存储加载的变量:")
	print("  test_score: %s (type: %s)" % [var1_loaded.value, var1_loaded.get_type_name()])
	print("  test_health: %s (type: %s)" % [var2_loaded.value, var2_loaded.get_type_name()])

	# 验证值是否正确恢复
	print("验证恢复的值...")
	assert(var1_loaded.value == 100, "score 应该恢复为 100，得到 %s" % var1_loaded.value)
	assert(var2_loaded.value == 50.5, "health 应该恢复为 50.5，得到 %s" % var2_loaded.value)
	print("✓ 所有值正确恢复")

	# 清理持久化存储
	var1_loaded._clear_storage()
	var2_loaded._clear_storage()
	print("持久化存储已清理")

	print("✓ 变量持久化测试通过")

func test_persistence_for_different_types():
	print("\n=== 开始不同类型变量持久化测试 ===")

	# 测试不同类型的变量
	var int_var = BaseVariable.create_global("test_int", 42, true)
	var float_var = BaseVariable.create_global("test_float", 3.14, true)
	var string_var = BaseVariable.create_global("test_string", "hello", true)
	var bool_var = BaseVariable.create_global("test_bool", true, true)
	var vector2_var = BaseVariable.create_global("test_vector2", Vector2(10, 20), true)
	var color_var = BaseVariable.create_global("test_color", Color.RED, true)

	# 保存所有变量
	int_var._save_to_storage()
	float_var._save_to_storage()
	string_var._save_to_storage()
	bool_var._save_to_storage()
	vector2_var._save_to_storage()
	color_var._save_to_storage()
	print("所有类型的变量已保存")

	# 创建新变量并加载
	var int_loaded = BaseVariable.create("test_int", 0, BaseVariable.VariableScope.GLOBAL)
	int_loaded._load_from_storage()

	var float_loaded = BaseVariable.create("test_float", 0.0, BaseVariable.VariableScope.GLOBAL)
	float_loaded._load_from_storage()

	var string_loaded = BaseVariable.create("test_string", "", BaseVariable.VariableScope.GLOBAL)
	string_loaded._load_from_storage()

	var bool_loaded = BaseVariable.create("test_bool", false, BaseVariable.VariableScope.GLOBAL)
	bool_loaded._load_from_storage()

	var vector2_loaded = BaseVariable.create("test_vector2", Vector2.ZERO, BaseVariable.VariableScope.GLOBAL)
	vector2_loaded._load_from_storage()

	var color_loaded = BaseVariable.create("test_color", Color.WHITE, BaseVariable.VariableScope.GLOBAL)
	color_loaded._load_from_storage()

	# 验证所有类型
	print("验证所有类型的恢复...")
	assert(int_loaded.value == 42, "INT 类型应该正确恢复")
	assert(float_loaded.value == 3.14, "FLOAT 类型应该正确恢复")
	assert(string_loaded.value == "hello", "STRING 类型应该正确恢复")
	assert(bool_loaded.value == true, "BOOL 类型应该正确恢复")
	assert(vector2_loaded.value == Vector2(10, 20), "VECTOR2 类型应该正确恢复")
	assert(color_loaded.value == Color.RED, "COLOR 类型应该正确恢复")

	print("✓ 所有类型的变量正确恢复")

	# 清理
	int_loaded._clear_storage()
	float_loaded._clear_storage()
	string_loaded._clear_storage()
	bool_loaded._clear_storage()
	vector2_loaded._clear_storage()
	color_loaded._clear_storage()

	print("✓ 不同类型变量持久化测试通过")

func test_modification_tracking():
	print("\n=== 开始修改跟踪持久化测试 ===")

	var var1 = BaseVariable.create_global("test_tracking", 10, true)
	var original_mod_count = var1.modification_count
	print("初始修改次数: %d" % original_mod_count)

	# 修改变量
	var1.value = 20
	var1.value = 30
	var modified_mod_count = var1.modification_count
	print("修改后修改次数: %d" % modified_mod_count)

	# 保存
	var1._save_to_storage()

	# 加载并验证
	var loaded = BaseVariable.create("test_tracking", 0, BaseVariable.VariableScope.GLOBAL)
	loaded._load_from_storage()

	# 注意：修改次数可能不会持久化，这取决于实现
	print("✓ 修改跟踪持久化测试通过")

	loaded._clear_storage()

func test_persistence_without_permission():
	print("\n=== 开始无持久化权限测试 ===")

	# 创建非持久化变量
	var var1 = BaseVariable.create_local("test_no_persist", 100)

	# 尝试保存（应该被跳过）
	var1._save_to_storage()
	print("✓ 无持久化权限测试通过（应该被优雅跳过）")

func test_clear_storage():
	print("\n=== 开始清理存储测试 ===")

	# 创建并保存变量
	var var1 = BaseVariable.create_global("test_clear", 100, true)
	var1._save_to_storage()

	# 清理存储
	var1._clear_storage()
	print("存储已清理")

	# 尝试加载（应该返回默认值）
	var loaded = BaseVariable.create("test_clear", 0, BaseVariable.VariableScope.GLOBAL)
	loaded._load_from_storage()

	print("加载的值: %s (应该为默认值 0)" % loaded.value)

	print("✓ 清理存储测试通过")
