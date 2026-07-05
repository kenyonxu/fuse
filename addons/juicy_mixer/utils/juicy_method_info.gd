## JuicyMethodInfo
## JuicyMixer 方法信息封装类
## 用于存储和访问节点方法的签名信息

class_name JuicyMethodInfo
extends RefCounted

## 类型名称常量（用于高效的类型名称查找）
const TYPE_NAMES = {
	TYPE_NIL: "null",
	TYPE_BOOL: "bool",
	TYPE_INT: "int",
	TYPE_FLOAT: "float",
	TYPE_STRING: "String",
	TYPE_VECTOR2: "Vector2",
	TYPE_VECTOR2I: "Vector2i",
	TYPE_VECTOR3: "Vector3",
	TYPE_VECTOR3I: "Vector3i",
	TYPE_COLOR: "Color",
	TYPE_ARRAY: "Array",
	TYPE_DICTIONARY: "Dictionary",
	TYPE_NODE_PATH: "NodePath",
	TYPE_OBJECT: "Object",
	TYPE_PACKED_BYTE_ARRAY: "PackedByteArray",
	TYPE_PACKED_INT32_ARRAY: "PackedInt32Array",
	TYPE_PACKED_FLOAT32_ARRAY: "PackedFloat32Array",
	TYPE_PACKED_STRING_ARRAY: "PackedStringArray",
	TYPE_PACKED_VECTOR2_ARRAY: "PackedVector2Array",
	TYPE_PACKED_VECTOR3_ARRAY: "PackedVector3Array",
	TYPE_PACKED_COLOR_ARRAY: "PackedColorArray"
}

## 方法信息
var method_name: String
var method_info: Dictionary
var parameter_infos: Array[Dictionary]
var return_type: int
var is_callable: bool

## 继承级别信息
var defined_in_class: String = ""  # 方法定义所在的类名
var inheritance_level: int = 0     # 方法定义所在的继承级别

## 构造函数
func _init(p_method_info: Dictionary = {}):
	if p_method_info.is_empty():
		return

	method_info = p_method_info
	method_name = p_method_info.get("name", "")
	return_type = _get_method_return_type(p_method_info)
	parameter_infos = _get_method_parameters(p_method_info)
	is_callable = true

	# 初始化继承级别信息
	defined_in_class = p_method_info.get("defined_in_class", "")
	inheritance_level = p_method_info.get("inheritance_level", 0)

## 获取方法的返回类型
static func _get_method_return_type(method_info: Dictionary) -> int:
	if not method_info or not method_info.has("return"):
		return TYPE_NIL

	var return_info = method_info.get("return", {})
	return return_info.get("type", TYPE_NIL)

## 获取方法的参数信息
static func _get_method_parameters(method_info: Dictionary) -> Array[Dictionary]:
	if not method_info or not method_info.has("args"):
		return []

	var parameters: Array[Dictionary] = []
	var args = method_info.get("args", [])

	for i in range(args.size()):
		var arg_info = args[i]
		var param_info = {
			"name": arg_info.get("name", "param_%d" % i),
			"type": arg_info.get("type", TYPE_NIL),
			"hint": arg_info.get("hint", PROPERTY_HINT_NONE),
			"hint_string": arg_info.get("hint_string", ""),
			"default_value": arg_info.get("default_value", null),
			"usage": arg_info.get("usage", PROPERTY_USAGE_DEFAULT)
		}
		parameters.append(param_info)

	return parameters

## 获取方法显示名称
## 返回格式: "method_name(param_count) -> return_type"
func get_display_name() -> String:
	if method_name.is_empty():
		return "未知方法"

	# 构建显示名称，包含参数信息
	var param_count = get_parameter_count()
	var display_name = "%s(%d)" % [method_name, param_count]

	# 如果有返回类型，添加到显示名称
	if has_return_value():
		var return_type_name = _get_type_name(return_type)
		display_name += " -> " + return_type_name

	return display_name

## 获取方法签名
## 返回格式: "method_name(param1: type1, param2: type2) -> return_type"
func get_method_signature() -> String:
	if method_name.is_empty():
		return "unknown()"

	var signature = method_name + "("

	# 添加参数信息
	for i in range(parameter_infos.size()):
		if i > 0:
			signature += ", "

		var param_info = parameter_infos[i]
		var param_name = param_info.get("name", "param_%d" % i)
		var param_type = param_info.get("type", TYPE_NIL)
		var type_name = _get_type_name(param_type)

		signature += "%s: %s" % [param_name, type_name]

	signature += ")"

	# 添加返回类型
	if has_return_value():
		var return_type_name = _get_type_name(return_type)
		signature += " -> " + return_type_name

	return signature

## 获取参数属性列表（用于动态属性生成）
## 返回可用于 _get_property_list() 的属性字典数组
func get_parameter_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	for i in range(parameter_infos.size()):
		var param_info = parameter_infos[i]

		var property = {
			"name": "param_%d" % i,
			"type": param_info.get("type", TYPE_NIL),
			"hint": param_info.get("hint", PROPERTY_HINT_NONE),
			"hint_string": param_info.get("hint_string", ""),
			"default": param_info.get("default_value", null),
			"usage": param_info.get("usage", PROPERTY_USAGE_DEFAULT)
		}

		properties.append(property)

	return properties

## 验证参数兼容性
## 检查给定的参数数组是否与方法签名匹配
func validate_arguments(args: Array) -> bool:
	if args.size() != parameter_infos.size():
		return false

	for i in range(parameter_infos.size()):
		var param_info = parameter_infos[i]
		var expected_type = param_info.get("type", TYPE_NIL)
		var actual_value = args[i]
		var actual_type = typeof(actual_value)

		# 允许 null 值（对于对象类型）
		if actual_value == null and (expected_type == TYPE_OBJECT or expected_type == TYPE_NIL):
			continue

		# 检查类型兼容性
		if not _is_type_compatible(actual_type, expected_type):
			return false

	return true

## 获取参数数量
func get_parameter_count() -> int:
	return parameter_infos.size()

## 检查是否有返回值
func has_return_value() -> bool:
	return return_type != TYPE_NIL

## 获取参数信息
func get_parameter_info(index: int) -> Dictionary:
	if index < 0 or index >= parameter_infos.size():
		return {}

	return parameter_infos[index]

## 获取参数名称
func get_parameter_name(index: int) -> String:
	if index < 0 or index >= parameter_infos.size():
		return ""

	return parameter_infos[index].get("name", "param_%d" % index)

## 获取参数类型
func get_parameter_type(index: int) -> int:
	if index < 0 or index >= parameter_infos.size():
		return TYPE_NIL

	return parameter_infos[index].get("type", TYPE_NIL)

## 获取参数默认值
func get_parameter_default(index: int) -> Variant:
	if index < 0 or index >= parameter_infos.size():
		return null

	return parameter_infos[index].get("default_value", null)

## 检查参数是否有默认值
func parameter_has_default(index: int) -> bool:
	if index < 0 or index >= parameter_infos.size():
		return false

	return parameter_infos[index].has("default_value")

## 获取所有参数名称
func get_parameter_names() -> Array[String]:
	var names: Array[String] = []

	for param_info in parameter_infos:
		names.append(param_info.get("name", ""))

	return names

## 获取所有参数类型
func get_parameter_types() -> Array[int]:
	var types: Array[int] = []

	for param_info in parameter_infos:
		types.append(param_info.get("type", TYPE_NIL))

	return types

## 检查是否为虚方法
func is_virtual_method() -> bool:
	if not method_info or not method_info.has("flags"):
		return false

	var flags = method_info.get("flags", 0)
	return (flags & METHOD_FLAG_VIRTUAL) != 0

## 检查是否为静态方法
func is_static_method() -> bool:
	if not method_info or not method_info.has("flags"):
		return false

	var flags = method_info.get("flags", 0)
	return (flags & METHOD_FLAG_STATIC) != 0

## 检查是否为常量方法
func is_const_method() -> bool:
	if not method_info or not method_info.has("flags"):
		return false

	var flags = method_info.get("flags", 0)
	return (flags & METHOD_FLAG_CONST) != 0

## 获取方法标志
func get_method_flags() -> int:
	if not method_info or not method_info.has("flags"):
		return 0

	return method_info.get("flags", 0)

## 获取方法ID
func get_method_id() -> int:
	if not method_info or not method_info.has("id"):
		return -1

	return method_info.get("id", -1)

## 获取方法定义所在的类名
func get_defined_class() -> String:
	return defined_in_class

## 获取方法定义所在的继承级别
func get_inheritance_level() -> int:
	return inheritance_level

## 获取方法参数类型列表
func get_argument_types() -> Array[int]:
	var types: Array[int] = []

	for param_info in parameter_infos:
		types.append(param_info.get("type", TYPE_NIL))

	return types

## 获取方法参数数量
func get_argument_count() -> int:
	return parameter_infos.size()

## 创建参数的默认值数组
## 为每个参数创建合适的默认值，优先使用方法签名中的默认值
func create_default_arguments() -> Array:
	var defaults: Array = []

	for i in range(parameter_infos.size()):
		var default_value = get_parameter_default(i)
		if parameter_has_default(i):
			defaults.append(default_value)
		else:
			# 根据类型创建合适的默认值
			var param_type = get_parameter_type(i)
			defaults.append(_create_default_value_for_type(param_type))

	return defaults

## 根据类型创建默认值
func _create_default_value_for_type(type: int) -> Variant:
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

## 检查方法是否与给定签名匹配
## 用于方法重载检查
func matches_signature(name: String, param_types: Array[int]) -> bool:
	if method_name != name:
		return false

	var actual_types = get_argument_types()
	if actual_types.size() != param_types.size():
		return false

	for i in range(param_types.size()):
		if not _is_type_compatible(param_types[i], actual_types[i]):
			return false

	return true

## 获取方法的详细信息字典
## 用于调试和日志记录
func get_method_details() -> Dictionary:
	return {
		"name": method_name,
		"signature": get_method_signature(),
		"return_type": return_type,
		"return_type_name": _get_type_name(return_type),
		"parameter_count": get_parameter_count(),
		"parameters": parameter_infos,
		"is_callable": is_callable,
		"is_virtual": is_virtual_method(),
		"is_static": is_static_method(),
		"is_const": is_const_method(),
		"flags": get_method_flags(),
		"id": get_method_id(),
		"defined_in_class": defined_in_class,
		"inheritance_level": inheritance_level
	}

## 获取类型名称
## 将 Godot 类型常量转换为可读字符串
func _get_type_name(type: int) -> String:
	return TYPE_NAMES.get(type, "UNKNOWN")

## 检查类型兼容性
## 用于参数验证，支持隐式类型转换
func _is_type_compatible(actual_type: int, expected_type: int) -> bool:
	# 完全匹配
	if actual_type == expected_type:
		return true

	# 允许 nil 到对象的转换
	if actual_type == TYPE_NIL and expected_type == TYPE_OBJECT:
		return true

	# 数值类型之间的转换
	if actual_type in [TYPE_INT, TYPE_FLOAT] and expected_type in [TYPE_INT, TYPE_FLOAT]:
		return true

	# 字符串到数值的转换（如果字符串可以解析为数值）
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

## 转换为字符串表示
func to_string() -> String:
	return get_method_signature()
