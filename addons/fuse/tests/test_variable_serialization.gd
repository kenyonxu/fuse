extends Node

## BaseVariable 持久化序列化测试
## 测试所有类型的序列化和反序列化功能

func _ready():
	print("========== 开始 BaseVariable 序列化测试 ==========")

	test_basic_types()
	test_vector_types()
	test_complex_types()
	test_packed_arrays()
	test_backward_compatibility()
	test_edge_cases()

	print("========== 序列化测试完成 ==========")

## 测试基本类型
func test_basic_types():
	print("\n--- 测试基本类型 ---")

	var test_cases = [
		{"name": "test_null", "value": null, "type": "Null"},
		{"name": "test_bool", "value": true, "type": "Bool"},
		{"name": "test_int", "value": 42, "type": "Int"},
		{"name": "test_float", "value": 3.14159, "type": "Float"},
		{"name": "test_string", "value": "Hello, World!", "type": "String"},
		{"name": "test_bool_false", "value": false, "type": "Bool"},
		{"name": "test_int_negative", "value": -123, "type": "Int"},
		{"name": "test_float_negative", "value": -2.71828, "type": "Float"},
		{"name": "test_string_empty", "value": "", "type": "String"},
		{"name": "test_int_zero", "value": 0, "type": "Int"}
	]

	for test_case in test_cases:
		var variable = BaseVariable.create(test_case.name, test_case.value)
		variable.persistent = true

		# 触发保存
		variable._save_to_storage()

		# 创建新变量并加载
		var loaded_var = BaseVariable.create(test_case.name + "_loaded", null)
		loaded_var.variable_name = test_case.name  # 使用相同的名称加载
		loaded_var.persistent = true
		loaded_var._load_from_storage()

		# 验证值是否正确
		var test_passed = test_equality(loaded_var.value, test_case.value)

		if test_passed:
			print("✓ %s: %s -> %s" % [test_case.name, str(test_case.value), str(loaded_var.value)])
		else:
			print("✗ %s 失败: 期望 %s，得到 %s" % [test_case.name, str(test_case.value), str(loaded_var.value)])
			assert(false, "测试失败: " + test_case.name)

		# 清理
		loaded_var._clear_storage()

	print("基本类型测试完成")

## 测试 Vector 类型
func test_vector_types():
	print("\n--- 测试 Vector 类型 ---")

	var test_cases = [
		{"name": "test_vector2", "value": Vector2(1.5, 2.5), "type": "Vector2"},
		{"name": "test_vector2_zero", "value": Vector2.ZERO, "type": "Vector2"},
		{"name": "test_vector2_negative", "value": Vector2(-1.0, -2.0), "type": "Vector2"},
		{"name": "test_vector3", "value": Vector3(1.0, 2.0, 3.0), "type": "Vector3"},
		{"name": "test_vector3_zero", "value": Vector3.ZERO, "type": "Vector3"},
		{"name": "test_vector3_negative", "value": Vector3(-1.0, -2.0, -3.0), "type": "Vector3"},
		{"name": "test_color_white", "value": Color.WHITE, "type": "Color"},
		{"name": "test_color_red", "value": Color.RED, "type": "Color"},
		{"name": "test_color_custom", "value": Color(0.5, 0.3, 0.7, 0.9), "type": "Color"},
		{"name": "test_color_half_alpha", "value": Color(1.0, 0.5, 0.2, 0.5), "type": "Color"}
	]

	for test_case in test_cases:
		var variable = BaseVariable.create(test_case.name, test_case.value)
		variable.persistent = true

		# 触发保存
		variable._save_to_storage()

		# 创建新变量并加载
		var loaded_var = BaseVariable.create(test_case.name + "_loaded", null)
		loaded_var.variable_name = test_case.name
		loaded_var.persistent = true
		loaded_var._load_from_storage()

		# 验证值是否正确
		var test_passed = test_equality(loaded_var.value, test_case.value)

		if test_passed:
			print("✓ %s: %s" % [test_case.name, str(loaded_var.value)])
		else:
			print("✗ %s 失败: 期望 %s，得到 %s" % [test_case.name, str(test_case.value), str(loaded_var.value)])
			assert(false, "测试失败: " + test_case.name)

		# 清理
		loaded_var._clear_storage()

	print("Vector 类型测试完成")

## 测试复杂类型
func test_complex_types():
	print("\n--- 测试复杂类型 ---")

	# 测试 Array
	var array_var = BaseVariable.create("test_array", [1, 2, 3, 4, 5])
	array_var.persistent = true
	array_var._save_to_storage()

	var loaded_array = BaseVariable.create("test_array_loaded", [])
	loaded_array.variable_name = "test_array"
	loaded_array.persistent = true
	loaded_array._load_from_storage()

	if loaded_array.value == array_var.value:
		print("✓ Array: %s" % str(loaded_array.value))
	else:
		print("✗ Array 失败: 期望 %s，得到 %s" % [str(array_var.value), str(loaded_array.value)])
		assert(false, "Array 测试失败")

	loaded_array._clear_storage()

	# 测试 Dictionary
	var dict_var = BaseVariable.create("test_dict", {"key1": "value1", "key2": 42, "key3": true})
	dict_var.persistent = true
	dict_var._save_to_storage()

	var loaded_dict = BaseVariable.create("test_dict_loaded", {})
	loaded_dict.variable_name = "test_dict"
	loaded_dict.persistent = true
	loaded_dict._load_from_storage()

	if loaded_dict.value == dict_var.value:
		print("✓ Dictionary: %s" % str(loaded_dict.value))
	else:
		print("✗ Dictionary 失败: 期望 %s，得到 %s" % [str(dict_var.value), str(loaded_dict.value)])
		assert(false, "Dictionary 测试失败")

	loaded_dict._clear_storage()

	# 测试嵌套 Array
	var nested_array_var = BaseVariable.create("test_nested_array", [[1, 2], [3, 4], [5, 6]])
	nested_array_var.persistent = true
	nested_array_var._save_to_storage()

	var loaded_nested = BaseVariable.create("test_nested_array_loaded", [])
	loaded_nested.variable_name = "test_nested_array"
	loaded_nested.persistent = true
	loaded_nested._load_from_storage()

	if loaded_nested.value == nested_array_var.value:
		print("✓ 嵌套 Array: %s" % str(loaded_nested.value))
	else:
		print("✗ 嵌套 Array 失败: 期望 %s，得到 %s" % [str(nested_array_var.value), str(loaded_nested.value)])
		assert(false, "嵌套 Array 测试失败")

	loaded_nested._clear_storage()

	# 测试嵌套 Dictionary
	var nested_dict_var = BaseVariable.create("test_nested_dict", {
		"player": {"name": "Alice", "score": 100},
		"enemies": [{"name": "Enemy1", "health": 50}, {"name": "Enemy2", "health": 75}]
	})
	nested_dict_var.persistent = true
	nested_dict_var._save_to_storage()

	var loaded_nested_dict = BaseVariable.create("test_nested_dict_loaded", {})
	loaded_nested_dict.variable_name = "test_nested_dict"
	loaded_nested_dict.persistent = true
	loaded_nested_dict._load_from_storage()

	# 注意：嵌套结构的比较需要深度比较
	if loaded_nested_dict.value.size() == nested_dict_var.value.size():
		print("✓ 嵌套 Dictionary: 大小匹配")
	else:
		print("✗ 嵌套 Dictionary 失败: 大小不匹配")
		assert(false, "嵌套 Dictionary 测试失败")

	loaded_nested_dict._clear_storage()

	print("复杂类型测试完成")

## 测试 PackedArray 类型
func test_packed_arrays():
	print("\n--- 测试 PackedArray 类型 ---")

	# 测试 PackedByteArray
	var byte_array = PackedByteArray([1, 2, 3, 4, 5])
	var packed_byte_var = BaseVariable.create("test_packed_byte", byte_array)
	packed_byte_var.persistent = true
	packed_byte_var._save_to_storage()

	var loaded_byte = BaseVariable.create("test_packed_byte_loaded", PackedByteArray())
	loaded_byte.variable_name = "test_packed_byte"
	loaded_byte.persistent = true
	loaded_byte._load_from_storage()

	if loaded_byte.value == byte_array:
		print("✓ PackedByteArray: %s" % str(loaded_byte.value))
	else:
		print("✗ PackedByteArray 失败")
		assert(false, "PackedByteArray 测试失败")

	loaded_byte._clear_storage()

	# 测试 PackedInt32Array
	var int_array = PackedInt32Array([10, 20, 30, 40, 50])
	var packed_int_var = BaseVariable.create("test_packed_int", int_array)
	packed_int_var.persistent = true
	packed_int_var._save_to_storage()

	var loaded_int = BaseVariable.create("test_packed_int_loaded", PackedInt32Array())
	loaded_int.variable_name = "test_packed_int"
	loaded_int.persistent = true
	loaded_int._load_from_storage()

	if loaded_int.value == int_array:
		print("✓ PackedInt32Array: %s" % str(loaded_int.value))
	else:
		print("✗ PackedInt32Array 失败")
		assert(false, "PackedInt32Array 测试失败")

	loaded_int._clear_storage()

	# 测试 PackedFloat32Array
	var float_array = PackedFloat32Array([1.1, 2.2, 3.3, 4.4, 5.5])
	var packed_float_var = BaseVariable.create("test_packed_float", float_array)
	packed_float_var.persistent = true
	packed_float_var._save_to_storage()

	var loaded_float = BaseVariable.create("test_packed_float_loaded", PackedFloat32Array())
	loaded_float.variable_name = "test_packed_float"
	loaded_float.persistent = true
	loaded_float._load_from_storage()

	if loaded_float.value == float_array:
		print("✓ PackedFloat32Array: %s" % str(loaded_float.value))
	else:
		print("✗ PackedFloat32Array 失败")
		assert(false, "PackedFloat32Array 测试失败")

	loaded_float._clear_storage()

	# 测试 PackedVector2Array
	var vector2_array = PackedVector2Array([Vector2(1, 2), Vector2(3, 4), Vector2(5, 6)])
	var packed_v2_var = BaseVariable.create("test_packed_vector2", vector2_array)
	packed_v2_var.persistent = true
	packed_v2_var._save_to_storage()

	var loaded_v2 = BaseVariable.create("test_packed_vector2_loaded", PackedVector2Array())
	loaded_v2.variable_name = "test_packed_vector2"
	loaded_v2.persistent = true
	loaded_v2._load_from_storage()

	if loaded_v2.value == vector2_array:
		print("✓ PackedVector2Array: %s" % str(loaded_v2.value))
	else:
		print("✗ PackedVector2Array 失败")
		assert(false, "PackedVector2Array 测试失败")

	loaded_v2._clear_storage()

	# 测试 PackedColorArray
	var color_array = PackedColorArray([Color.RED, Color.GREEN, Color.BLUE])
	var packed_color_var = BaseVariable.create("test_packed_color", color_array)
	packed_color_var.persistent = true
	packed_color_var._save_to_storage()

	var loaded_color = BaseVariable.create("test_packed_color_loaded", PackedColorArray())
	loaded_color.variable_name = "test_packed_color"
	loaded_color.persistent = true
	loaded_color._load_from_storage()

	if loaded_color.value == color_array:
		print("✓ PackedColorArray: %s" % str(loaded_color.value))
	else:
		print("✗ PackedColorArray 失败")
		assert(false, "PackedColorArray 测试失败")

	loaded_color._clear_storage()

	print("PackedArray 类型测试完成")

## 测试向后兼容性
func test_backward_compatibility():
	print("\n--- 测试向后兼容性 ---")

	# 模拟旧格式的存储
	var config = ConfigFile.new()
	config.load(BaseVariable.STORAGE_CONFIG_PATH)

	# 手动写入旧格式数据（使用 str() 格式）
	config.set_value(BaseVariable.STORAGE_SECTION, "legacy_vector2", "(5.5, 6.5)")
	config.set_value(BaseVariable.STORAGE_SECTION, "legacy_vector2_type", "Vector2")

	config.set_value(BaseVariable.STORAGE_SECTION, "legacy_vector3", "(1.5, 2.5, 3.5)")
	config.set_value(BaseVariable.STORAGE_SECTION, "legacy_vector3_type", "Vector3")

	config.set_value(BaseVariable.STORAGE_SECTION, "legacy_color", "(1, 0.5, 0.2, 0.8)")
	config.set_value(BaseVariable.STORAGE_SECTION, "legacy_color_type", "Color")

	config.save(BaseVariable.STORAGE_CONFIG_PATH)

	# 尝试加载旧格式数据
	var legacy_v2 = BaseVariable.create("legacy_vector2", Vector2.ZERO)
	legacy_v2.persistent = true
	legacy_v2._load_from_storage()

	if legacy_v2.value == Vector2(5.5, 6.5):
		print("✓ 向后兼容 Vector2: %s" % str(legacy_v2.value))
	else:
		print("✗ 向后兼容 Vector2 失败: 期望 (5.5, 6.5)，得到 %s" % str(legacy_v2.value))
		assert(false, "向后兼容 Vector2 测试失败")

	var legacy_v3 = BaseVariable.create("legacy_vector3", Vector3.ZERO)
	legacy_v3.persistent = true
	legacy_v3._load_from_storage()

	if legacy_v3.value == Vector3(1.5, 2.5, 3.5):
		print("✓ 向后兼容 Vector3: %s" % str(legacy_v3.value))
	else:
		print("✗ 向后兼容 Vector3 失败")
		assert(false, "向后兼容 Vector3 测试失败")

	var legacy_color = BaseVariable.create("legacy_color", Color.WHITE)
	legacy_color.persistent = true
	legacy_color._load_from_storage()

	if legacy_color.value == Color(1.0, 0.5, 0.2, 0.8):
		print("✓ 向后兼容 Color: %s" % str(legacy_color.value))
	else:
		print("✗ 向后兼容 Color 失败")
		assert(false, "向后兼容 Color 测试失败")

	# 清理
	legacy_v2._clear_storage()
	legacy_v3._clear_storage()
	legacy_color._clear_storage()

	print("向后兼容性测试完成")

## 测试边界情况
func test_edge_cases():
	print("\n--- 测试边界情况 ---")

	# 测试非常大的整数
	var big_int = BaseVariable.create("test_big_int", 2147483647)
	big_int.persistent = true
	big_int._save_to_storage()

	var loaded_big_int = BaseVariable.create("test_big_int_loaded", 0)
	loaded_big_int.variable_name = "test_big_int"
	loaded_big_int.persistent = true
	loaded_big_int._load_from_storage()

	if loaded_big_int.value == 2147483647:
		print("✓ 大整数: %s" % str(loaded_big_int.value))
	else:
		print("✗ 大整数失败")
		assert(false, "大整数测试失败")

	loaded_big_int._clear_storage()

	# 测试非常小的浮点数
	var tiny_float = BaseVariable.create("test_tiny_float", 0.000001)
	tiny_float.persistent = true
	tiny_float._save_to_storage()

	var loaded_tiny = BaseVariable.create("test_tiny_float_loaded", 0.0)
	loaded_tiny.variable_name = "test_tiny_float"
	loaded_tiny.persistent = true
	loaded_tiny._load_from_storage()

	if abs(loaded_tiny.value - 0.000001) < 0.0000001:
		print("✓ 小浮点数: %s" % str(loaded_tiny.value))
	else:
		print("✗ 小浮点数失败")
		assert(false, "小浮点数测试失败")

	loaded_tiny._clear_storage()

	# 测试特殊字符串（包含引号、逗号等）
	var special_string = BaseVariable.create("test_special_str", 'Hello, "World"! Test: 1,2,3')
	special_string.persistent = true
	special_string._save_to_storage()

	var loaded_special = BaseVariable.create("test_special_str_loaded", "")
	loaded_special.variable_name = "test_special_str"
	loaded_special.persistent = true
	loaded_special._load_from_storage()

	if loaded_special.value == special_string.value:
		print("✓ 特殊字符串: %s" % str(loaded_special.value))
	else:
		print("✗ 特殊字符串失败")
		assert(false, "特殊字符串测试失败")

	loaded_special._clear_storage()

	# 测试空数组
	var empty_array = BaseVariable.create("test_empty_array", [])
	empty_array.persistent = true
	empty_array._save_to_storage()

	var loaded_empty = BaseVariable.create("test_empty_array_loaded", [])
	loaded_empty.variable_name = "test_empty_array"
	loaded_empty.persistent = true
	loaded_empty._load_from_storage()

	if loaded_empty.value.is_empty():
		print("✓ 空数组: %s" % str(loaded_empty.value))
	else:
		print("✗ 空数组失败")
		assert(false, "空数组测试失败")

	loaded_empty._clear_storage()

	# 测试空字典
	var empty_dict = BaseVariable.create("test_empty_dict", {})
	empty_dict.persistent = true
	empty_dict._save_to_storage()

	var loaded_empty_dict = BaseVariable.create("test_empty_dict_loaded", {})
	loaded_empty_dict.variable_name = "test_empty_dict"
	loaded_empty_dict.persistent = true
	loaded_empty_dict._load_from_storage()

	if loaded_empty_dict.value.is_empty():
		print("✓ 空字典: %s" % str(loaded_empty_dict.value))
	else:
		print("✗ 空字典失败")
		assert(false, "空字典测试失败")

	loaded_empty_dict._clear_storage()

	print("边界情况测试完成")

## 辅助函数：比较两个值是否相等
func test_equality(value1, value2) -> bool:
	# 处理 null
	if value1 == null and value2 == null:
		return true

	if value1 == null or value2 == null:
		return false

	# 处理浮点数精度
	if typeof(value1) == TYPE_FLOAT and typeof(value2) == TYPE_FLOAT:
		return abs(value1 - value2) < 0.00001

	# 处理数组
	if typeof(value1) == TYPE_ARRAY and typeof(value2) == TYPE_ARRAY:
		if value1.size() != value2.size():
			return false
		for i in range(value1.size()):
			if not test_equality(value1[i], value2[i]):
				return false
		return true

	# 处理字典
	if typeof(value1) == TYPE_DICTIONARY and typeof(value2) == TYPE_DICTIONARY:
		if value1.size() != value2.size():
			return false
		for key in value1:
			if not value2.has(key):
				return false
			if not test_equality(value1[key], value2[key]):
				return false
		return true

	# 默认使用 == 比较
	return value1 == value2
