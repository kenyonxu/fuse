## JuicyParameterEditor
## JuicyMixer 参数属性生成器
## 负责生成动态 Inspector 属性和处理参数编辑

class_name JuicyParameterEditor
extends RefCounted

## 生成方法选择属性
## @param method_names: 可用方法名称数组
## @param selected_method: 当前选中的方法名
## @return: 用于 _get_property_list() 的属性字典
static func create_method_selector_property(method_names: Array[String], selected_method: String = "") -> Dictionary:
	var property: Dictionary = {
		"name": "target_function",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(method_names),
		"usage": PROPERTY_USAGE_DEFAULT
	}

	# 如果没有可用方法，显示提示
	if method_names.is_empty():
		property.hint = PROPERTY_HINT_PLACEHOLDER_TEXT
		property.hint_string = "没有可用方法"
		property.usage = PROPERTY_USAGE_READ_ONLY if selected_method.is_empty() else PROPERTY_USAGE_DEFAULT

	return property

## 生成参数属性列表
## @param method_info: 方法信息对象
## @param current_args: 当前参数值数组
## @return: 参数属性字典数组
static func create_parameter_properties(method_info: JuicyMethodInfo, current_args: Array = []) -> Array[Dictionary]:
	if not method_info:
		return []

	var properties: Array[Dictionary] = []
	var param_count = method_info.get_parameter_count()

	# 确保参数数组有足够的大小
	var args = current_args.duplicate()
	while args.size() < param_count:
		args.append(null)

	for i in range(param_count):
		var param_info = method_info.get_parameter_info(i)
		var param_name = method_info.get_parameter_name(i)
		var param_type = method_info.get_parameter_type(i)

		# 创建增强的属性名（格式：param_0___position: Vector2）
		var display_label = _create_enhanced_parameter_label(i, param_name, param_type, method_info)
		var property_name = "param_%d___%s" % [i, display_label]

		# 创建参数属性
		var property: Dictionary = {
			"name": property_name,  # 使用增强的名称
			"type": param_type,
			"hint": param_info.get("hint", PROPERTY_HINT_NONE),
			"hint_string": param_info.get("hint_string", ""),
			"usage": PROPERTY_USAGE_DEFAULT
		}

		# 如果有默认值，添加到属性
		if method_info.parameter_has_default(i):
			property["default"] = method_info.get_parameter_default(i)
		else:
			# 根据类型创建默认值
			property["default"] = _create_default_value_for_type(param_type)

		properties.append(property)

	return properties

## 创建增强的参数标签（显示在 Inspector 中）
## @param index: 参数索引
## @param param_name: 参数名称
## @param param_type: 参数类型
## @param method_info: 方法信息对象
## @return: 格式化的参数标签
static func _create_enhanced_parameter_label(
	index: int,
	param_name: String,
	param_type: int,
	method_info: JuicyMethodInfo
) -> String:
	# 标准类型参数的标签格式（不包含默认值，默认值会在 Inspector 值框中显示）
	var type_name = _get_type_name(param_type)
	var display_name = _sanitize_parameter_name(param_name)
	var label = "%s: %s" % [display_name, type_name]

	return label

## 清理参数名称（处理特殊情况）
## @param param_name: 原始参数名
## @return: 清理后的参数名
static func _sanitize_parameter_name(param_name: String) -> String:
	if param_name.is_empty():
		return "未命名参数"

	# 移除常见的无用前缀
	var sanitized = param_name
	if sanitized.begins_with("p_"):
		sanitized = sanitized.substr(2)
	elif sanitized.begins_with("param_"):
		sanitized = sanitized.substr(6)
	elif sanitized.begins_with("_"):
		sanitized = sanitized.substr(1)

	# 如果清理后为空，使用原名
	if sanitized.is_empty():
		sanitized = param_name

	return sanitized

## 生成参数映射属性
## 为 JuicyMixer 的参数映射系统生成特殊属性
## @param param_count: 参数数量
## @param mapped_indices: 已映射的参数索引数组
## @return: 参数映射属性数组
static func create_parameter_mapping_properties(param_count: int, mapped_indices: Array[int] = []) -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	for i in range(param_count):
		var is_mapped = i in mapped_indices
		var property: Dictionary = {
			"name": "param_%d_mapped" % i,
			"type": TYPE_BOOL,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "启用参数映射",
			"usage": PROPERTY_USAGE_DEFAULT,
			"default": is_mapped
		}

		properties.append(property)

	return properties

## 从属性名中提取参数索引
## @param property: 属性名称（格式：param_0___display_label 或 param_0）
## @return: 参数索引，如果无法提取返回 -1
static func extract_param_index(property: String) -> int:
	if not property.begins_with("param_"):
		return -1

	# 提取参数索引（支持两种格式：param_0 或 param_0___label）
	var index_str = property.substr(6)  # 移除 "param_" 前缀
	if index_str.contains("___"):
		index_str = index_str.split("___")[0]  # 提取 "___" 前的部分

	if not index_str.is_valid_int():
		return -1

	return index_str.to_int()

## 验证参数属性
## 检查属性值是否与方法签名匹配
## @param method_info: 方法信息对象
## @param property_name: 属性名称
## @param value: 属性值
## @return: 包含 valid 和 error 的字典
static func validate_parameter_property(method_info: JuicyMethodInfo, property_name: String, value: Variant) -> Dictionary:
	var result = {
		"valid": true,
		"error": ""
	}

	# 提取参数索引
	var index = extract_param_index(property_name)
	if index < 0:
		return result  # 不是参数属性，返回有效

	# 检查索引范围
	if index < 0 or index >= method_info.get_parameter_count():
		result.valid = false
		result.error = "参数索引超出范围: %d" % index
		return result

	# 验证参数类型
	var expected_type = method_info.get_parameter_type(index)
	var actual_type = typeof(value)

	# 允许 null 值（对于对象类型）
	if value == null and (expected_type == TYPE_OBJECT or expected_type == TYPE_NIL):
		return result

	# 检查类型兼容性
	if not _is_type_compatible(actual_type, expected_type):
		var expected_name = _get_type_name(expected_type)
		var actual_name = _get_type_name(actual_type)
		result.valid = false
		result.error = "参数 %d 类型不匹配: 期望 %s，实际 %s" % [index, expected_name, actual_name]

	return result

## 创建完整的属性列表
## 用于 _get_property_list() 方法
## @param method_info: 方法信息对象
## @param current_args: 当前参数值
## @param include_return_value: 是否包含返回值处理选项
## @return: 完整的属性列表
static func create_full_property_list(method_info: JuicyMethodInfo, current_args: Array = [], include_return_value: bool = false) -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	# 添加参数属性
	if method_info:
		var param_properties = create_parameter_properties(method_info, current_args)
		properties.append_array(param_properties)

	# 添加返回值处理选项
	if include_return_value:
		properties.append({
			"name": "store_return_value",
			"type": TYPE_BOOL,
			"hint": PROPERTY_HINT_NONE,
			"usage": PROPERTY_USAGE_DEFAULT,
			"default": false
		})

	return properties

## 格式化值用于显示
## @param value: 要格式化的值
## @return: 格式化的字符串
static func _format_value(value: Variant) -> String:
	if value == null:
		return "null"

	match typeof(value):
		TYPE_STRING:
			return '"%s"' % value
		TYPE_ARRAY:
			return "[%d]" % value.size()
		TYPE_DICTIONARY:
			return "{%d}" % value.size()
		TYPE_NODE_PATH:
			return str(value)
		_:
			return str(value)

## 根据类型创建默认值
## @param type: Godot 类型常量
## @return: 类型的默认值
static func _create_default_value_for_type(type: int) -> Variant:
	match type:
		TYPE_BOOL: return false
		TYPE_INT: return 0
		TYPE_FLOAT: return 0.0
		TYPE_STRING: return ""
		TYPE_VECTOR2: return Vector2.ZERO
		TYPE_VECTOR2I: return Vector2i.ZERO
		TYPE_VECTOR3: return Vector3.ZERO
		TYPE_VECTOR3I: return Vector3i.ZERO
		TYPE_COLOR: return Color.WHITE
		TYPE_ARRAY: return []
		TYPE_DICTIONARY: return {}
		TYPE_NODE_PATH: return NodePath("")
		TYPE_OBJECT: return null
		TYPE_PACKED_BYTE_ARRAY: return PackedByteArray()
		TYPE_PACKED_INT32_ARRAY: return PackedInt32Array()
		TYPE_PACKED_FLOAT32_ARRAY: return PackedFloat32Array()
		TYPE_PACKED_STRING_ARRAY: return PackedStringArray()
		TYPE_PACKED_VECTOR2_ARRAY: return PackedVector2Array()
		TYPE_PACKED_VECTOR3_ARRAY: return PackedVector3Array()
		TYPE_PACKED_COLOR_ARRAY: return PackedColorArray()
		_: return null

## 获取类型名称
## @param type: Godot 类型常量
## @return: 类型名称字符串
static func _get_type_name(type: int) -> String:
	match type:
		TYPE_NIL: return "null"
		TYPE_BOOL: return "bool"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_STRING: return "String"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR2I: return "Vector2i"
		TYPE_VECTOR3: return "Vector3"
		TYPE_VECTOR3I: return "Vector3i"
		TYPE_COLOR: return "Color"
		TYPE_ARRAY: return "Array"
		TYPE_DICTIONARY: return "Dictionary"
		TYPE_OBJECT: return "Object"
		TYPE_NODE_PATH: return "NodePath"
		TYPE_PACKED_BYTE_ARRAY: return "PackedByteArray"
		TYPE_PACKED_INT32_ARRAY: return "PackedInt32Array"
		TYPE_PACKED_FLOAT32_ARRAY: return "PackedFloat32Array"
		TYPE_PACKED_STRING_ARRAY: return "PackedStringArray"
		TYPE_PACKED_VECTOR2_ARRAY: return "PackedVector2Array"
		TYPE_PACKED_VECTOR3_ARRAY: return "PackedVector3Array"
		TYPE_PACKED_COLOR_ARRAY: return "PackedColorArray"
		_: return "Unknown"

## 检查类型兼容性
## @param actual_type: 实际类型
## @param expected_type: 期望类型
## @return: 类型是否兼容
static func _is_type_compatible(actual_type: int, expected_type: int) -> bool:
	# 完全匹配
	if actual_type == expected_type:
		return true

	# 允许 nil 到对象的转换
	if actual_type == TYPE_NIL and expected_type == TYPE_OBJECT:
		return true

	# 数值类型之间的转换
	if actual_type in [TYPE_INT, TYPE_FLOAT] and expected_type in [TYPE_INT, TYPE_FLOAT]:
		return true

	# 字符串到数值的转换
	if actual_type == TYPE_STRING and expected_type in [TYPE_INT, TYPE_FLOAT]:
		return true

	# 数值到字符串的转换
	if actual_type in [TYPE_INT, TYPE_FLOAT] and expected_type == TYPE_STRING:
		return true

	# 布尔值到数值的转换
	if actual_type == TYPE_BOOL and expected_type in [TYPE_INT, TYPE_FLOAT]:
		return true

	# 数值到布尔值的转换
	if actual_type in [TYPE_INT, TYPE_FLOAT] and expected_type == TYPE_BOOL:
		return true

	# 字符串到布尔值的转换
	if actual_type == TYPE_STRING and expected_type == TYPE_BOOL:
		return true

	return false

## 处理参数属性设置
## 用于在 _set() 方法中处理动态参数
## @param property: 属性名称（格式：param_0___display_label 或 param_0）
## @param value: 属性值
## @param current_args: 当前参数数组（引用传递）
## @return: 是否成功设置
static func handle_parameter_set(property: String, value: Variant, current_args: Array) -> bool:
	if not property.begins_with("param_"):
		return false

	# 提取参数索引（支持两种格式：param_0 或 param_0___label）
	var index_str = property.substr(6)  # 移除 "param_" 前缀
	if index_str.contains("___"):
		index_str = index_str.split("___")[0]  # 提取 "___" 前的部分

	if not index_str.is_valid_int():
		return false

	var index = index_str.to_int()

	# 确保数组有足够大小
	while current_args.size() <= index:
		current_args.append(null)

	# 设置参数值
	current_args[index] = value
	return true

## 处理参数属性获取
## 用于在 _get() 方法中处理动态参数
## @param property: 属性名称（格式：param_0___display_label 或 param_0）
## @param current_args: 当前参数数组
## @param method_info: 方法信息对象（可选）
## @return: 参数值，如果不存在返回 null
static func handle_parameter_get(property: String, current_args: Array, method_info: JuicyMethodInfo = null) -> Variant:
	if not property.begins_with("param_"):
		return null

	# 提取参数索引（支持两种格式：param_0 或 param_0___label）
	var index_str = property.substr(6)  # 移除 "param_" 前缀
	if index_str.contains("___"):
		index_str = index_str.split("___")[0]  # 提取 "___" 前的部分

	if not index_str.is_valid_int():
		return null

	var index = index_str.to_int()

	# 确保数组有足够大小
	while current_args.size() <= index:
		current_args.append(null)

	# 返回参数值
	var value = current_args[index]

	# 如果值为 null 且有方法信息，提供默认值
	if value == null and method_info and index < method_info.get_parameter_count():
		if method_info.parameter_has_default(index):
			return method_info.get_parameter_default(index)
		else:
			var param_type = method_info.get_parameter_type(index)
			return _create_default_value_for_type(param_type)

	return value

## 生成属性验证提示
## @param method_info: 方法信息对象
## @return: 验证提示字符串
static func generate_validation_hint(method_info: JuicyMethodInfo) -> String:
	if not method_info:
		return ""

	var hints: Array[String] = []

	# 参数数量提示
	var param_count = method_info.get_parameter_count()
	hints.append("需要 %d 个参数" % param_count)

	# 参数类型提示
	for i in range(param_count):
		var param_name = method_info.get_parameter_name(i)
		var param_type = method_info.get_parameter_type(i)
		var type_name = _get_type_name(param_type)

		if method_info.parameter_has_default(i):
			var default_val = method_info.get_parameter_default(i)
			var default_str = _format_value(default_val)
			hints.append("  %s: %s (默认: %s)" % [param_name, type_name, default_str])
		else:
			hints.append("  %s: %s" % [param_name, type_name])

	# 返回类型提示
	if method_info.has_return_value():
		var return_type = method_info.return_type
		var return_type_name = _get_type_name(return_type)
		hints.append("返回值: %s" % return_type_name)

	return "\n".join(hints)

## 创建参数分组
## 将多个参数组织成分组（用于复杂类型）
## @param method_info: 方法信息对象
## @param group_size: 每组的大小
## @return: 分组后的属性列表
static func create_grouped_parameter_properties(method_info: JuicyMethodInfo, group_size: int = 3) -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	var param_count = method_info.get_parameter_count()
	var group_index = 0

	for i in range(param_count):
		# 每 group_size 个参数创建一个分组
		if i % group_size == 0:
			properties.append({
				"name": "parameter_group_%d" % group_index,
				"type": TYPE_NIL,
				"hint": PROPERTY_HINT_NONE,
				"hint_string": "参数 %d-%d" % [i, min(i + group_size - 1, param_count - 1)],
				"usage": PROPERTY_USAGE_CATEGORY
			})
			group_index += 1

		# 添加参数属性
		var param_properties = create_parameter_properties(method_info, [])
		if i < param_properties.size():
			properties.append(param_properties[i])

	return properties
