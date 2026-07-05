extends Node

## FunctionManager 类型兼容性测试
##
## 测试 FunctionManager 的类型兼容性检查是否完善

func test_vector_type_compatibility():
	print("=== 开始 Vector 类型兼容性测试 ===")

	var manager = FunctionManager.new()
	var node = Node2D.new()

	# 应该允许 Vector2 ↔ Vector2I 的转换
	var vector2 = Vector2(10, 20)
	var vector2i = Vector2i(10, 20)

	print("测试 Vector2 到 Vector2I 兼容性...")
	var result1 = manager._is_type_compatible(TYPE_VECTOR2, TYPE_VECTOR2I)
	print("  Vector2 -> Vector2I: %s" % result1)
	assert(result1, "Vector2 应该兼容 Vector2I")

	print("测试 Vector2I 到 Vector2 兼容性...")
	var result2 = manager._is_type_compatible(TYPE_VECTOR2I, TYPE_VECTOR2)
	print("  Vector2I -> Vector2: %s" % result2)
	assert(result2, "Vector2I 应该兼容 Vector2")

	print("测试 Vector3 到 Vector3I 兼容性...")
	var result3 = manager._is_type_compatible(TYPE_VECTOR3, TYPE_VECTOR3I)
	print("  Vector3 -> Vector3I: %s" % result3)
	assert(result3, "Vector3 应该兼容 Vector3I")

	print("测试 Vector3I 到 Vector3 兼容性...")
	var result4 = manager._is_type_compatible(TYPE_VECTOR3I, TYPE_VECTOR3)
	print("  Vector3I -> Vector3: %s" % result4)
	assert(result4, "Vector3I 应该兼容 Vector3")

	print("✓ Vector 类型兼容性测试通过")

	node.queue_free()

func test_numeric_type_compatibility():
	print("\n=== 开始数值类型兼容性测试 ===")

	var manager = FunctionManager.new()

	# 数值类型之间的转换
	print("测试数值类型之间的转换...")
	assert(manager._is_type_compatible(TYPE_INT, TYPE_INT), "INT 应该兼容 INT")
	assert(manager._is_type_compatible(TYPE_INT, TYPE_FLOAT), "INT 应该兼容 FLOAT")
	assert(manager._is_type_compatible(TYPE_FLOAT, TYPE_INT), "FLOAT 应该兼容 INT")
	assert(manager._is_type_compatible(TYPE_FLOAT, TYPE_FLOAT), "FLOAT 应该兼容 FLOAT")

	print("✓ 数值类型兼容性测试通过")

func test_string_to_numeric_compatibility():
	print("\n=== 开始字符串到数值转换兼容性测试 ===")

	var manager = FunctionManager.new()

	# 字符串到数值的转换
	print("测试字符串到数值的转换...")
	assert(manager._is_type_compatible(TYPE_STRING, TYPE_INT), "STRING 应该兼容 INT")
	assert(manager._is_type_compatible(TYPE_STRING, TYPE_FLOAT), "STRING 应该兼容 FLOAT")

	print("✓ 字符串到数值转换兼容性测试通过")

func test_numeric_to_string_compatibility():
	print("\n=== 开始数值到字符串转换兼容性测试 ===")

	var manager = FunctionManager.new()

	# 数值到字符串的转换
	print("测试数值到字符串的转换...")
	assert(manager._is_type_compatible(TYPE_INT, TYPE_STRING), "INT 应该兼容 STRING")
	assert(manager._is_type_compatible(TYPE_FLOAT, TYPE_STRING), "FLOAT 应该兼容 STRING")

	print("✓ 数值到字符串转换兼容性测试通过")

func test_boolean_type_compatibility():
	print("\n=== 开始布尔类型兼容性测试 ===")

	var manager = FunctionManager.new()

	# 布尔值到数值的转换
	print("测试布尔值到数值的转换...")
	assert(manager._is_type_compatible(TYPE_BOOL, TYPE_INT), "BOOL 应该兼容 INT")
	assert(manager._is_type_compatible(TYPE_BOOL, TYPE_FLOAT), "BOOL 应该兼容 FLOAT")

	# 数值到布尔值的转换
	print("测试数值到布尔值的转换...")
	assert(manager._is_type_compatible(TYPE_INT, TYPE_BOOL), "INT 应该兼容 BOOL")
	assert(manager._is_type_compatible(TYPE_FLOAT, TYPE_BOOL), "FLOAT 应该兼容 BOOL")

	# 字符串到布尔值的转换
	print("测试字符串到布尔值的转换...")
	assert(manager._is_type_compatible(TYPE_STRING, TYPE_BOOL), "STRING 应该兼容 BOOL")

	print("✓ 布尔类型兼容性测试通过")

func test_object_type_compatibility():
	print("\n=== 开始对象类型兼容性测试 ===")

	var manager = FunctionManager.new()

	# nil 到对象的转换
	print("测试 nil 到对象的转换...")
	assert(manager._is_type_compatible(TYPE_NIL, TYPE_OBJECT), "NIL 应该兼容 OBJECT")

	print("✓ 对象类型兼容性测试通过")

func test_type_incompatibility():
	print("\n=== 开始类型不兼容测试 ===")

	var manager = FunctionManager.new()

	# 不兼容的类型组合
	print("测试不兼容的类型组合...")

	# 布尔值不应该直接兼容字符串（单向转换）
	var result1 = manager._is_type_compatible(TYPE_BOOL, TYPE_STRING)
	print("  BOOL -> STRING: %s (应该为 false)" % result1)
	assert(not result1, "BOOL 不应该兼容 STRING")

	# Vector2 不应该兼容 Vector3
	var result2 = manager._is_type_compatible(TYPE_VECTOR2, TYPE_VECTOR3)
	print("  VECTOR2 -> VECTOR3: %s (应该为 false)" % result2)
	assert(not result2, "VECTOR2 不应该兼容 VECTOR3")

	print("✓ 类型不兼容测试通过")
