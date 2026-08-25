# 文件：addons/fuse/utils/signal_info.gd
@tool
class_name SignalInfo extends Resource

## 动态属性列表
##
## 显式返回 Array[Dictionary]，避免 Godot 4.x 使用 Resource 基类的 Array 返回类型
## 触发 "_get_property_list() should return Array[Dictionary]" 兼容性警告。
func _get_property_list() -> Array[Dictionary]:
	return []

## 信号名称
var name: String = ""

## 信号参数信息数组
var args: Array = []

## 默认参数值
var default_args: Array = []

## 信号标志
var flags: int = 0

## 所属节点类型（用于缓存和过滤）
var owner_node_class: String = ""

## 信号描述（可选）
var description: String = ""

## 从 Godot 信号字典创建 SignalInfo
static func from_godot_signal(signal_dict: Dictionary, node_class: String = ""):
	var signal_info = SignalInfo.new()
	signal_info.name = signal_dict.name
	signal_info.args = signal_dict.args if signal_dict.has("args") else []
	signal_info.default_args = signal_dict.get("default_args", [])
	signal_info.flags = signal_dict.get("flags", 0)
	signal_info.owner_node_class = node_class
	return signal_info

## 获取信号的完整签名
func get_signature():
	var args_str = []
	for i in range(args.size()):
		var arg = args[i]
		var type_str = _get_type_string(arg.type)
		var arg_name = arg.name if arg.has("name") else "arg%d" % i

		# 添加默认值信息
		if i < default_args.size():
			args_str.append("%s: %s = %s" % [arg_name, type_str, str(default_args[i])])
		else:
			args_str.append("%s: %s" % [arg_name, type_str])

	return "%s(%s)" % [name, ", ".join(args_str)]

## 获取简短的显示名称
func get_display_name():
	if args.is_empty():
		return name
	return "%s(%d)" % [name, args.size()]

## 获取参数类型字符串数组
func get_arg_type_strings():
	var type_strings = []
	for arg in args:
		type_strings.append(_get_type_string(arg.type))
	return type_strings

## 检查参数数量是否匹配
func has_arg_count(count: int):
	return args.size() == count

## 检查参数类型是否兼容
func are_args_compatible(arg_types):
	if args.size() != arg_types.size():
		return false

	for i in range(args.size()):
		if not _are_types_compatible(args[i].type, arg_types[i]):
			return false

	return true

## 验证信号参数值
func validate_args(values):
	if values.size() > args.size():
		return false

	for i in range(values.size()):
		if not _is_value_valid_for_type(values[i], args[i].type):
			return false

	return true

## 获取参数过滤属性（用于编辑器；按参数名生成，Object 类型参数不生成——期望值无从表达）
##
## usage 取 EDITOR（显示可编辑、不参与存储）：子字段经组件 _set/_get 桥接写入
## arg_filter_values dict，顶层 dict 是唯一数据源——带 STORAGE 会让 serialize
## 产出无法还原的冗余 "arg_filter_values/<名>" 子键
func get_arg_property_list():
	var properties = []
	for i in range(args.size()):
		var arg = args[i]
		if arg.type == TYPE_OBJECT:
			continue
		var arg_name = arg.name if arg.has("name") else "arg%d" % i
		var property = {
			"name": "arg_filter_values/%s" % arg_name,
			"type": arg.type,
			"usage": PROPERTY_USAGE_EDITOR
		}
		if arg.has("hint"):
			property["hint"] = arg.hint
		if arg.has("hint_string"):
			property["hint_string"] = arg.hint_string
		properties.append(property)
	return properties

## 类型安全的参数匹配（过滤比较共用）
##
## Object 与非 Object 混合、跨类型族一律视为不匹配（不执行原生比较，
## 避免运行时硬错误——CompareVariable 同款教训）；数值互转与
## String/StringName 兼容对齐 _are_types_compatible 的既有分派。
static func matches_arg(expected: Variant, actual: Variant) -> bool:
	# Object 只与 Object（引用比较）或 null 比较
	if (expected is Object) or (actual is Object):
		if (expected is Object) and (actual is Object):
			return expected == actual
		return expected == null and actual == null
	if expected == null or actual == null:
		return expected == null and actual == null
	var et := typeof(expected)
	var at := typeof(actual)
	if et == at:
		return expected == actual
	# 数值互转
	if (et == TYPE_INT or et == TYPE_FLOAT) and (at == TYPE_INT or at == TYPE_FLOAT):
		return float(expected) == float(actual)
	# 字符串族
	if (et == TYPE_STRING and at == TYPE_STRING_NAME) or (et == TYPE_STRING_NAME and at == TYPE_STRING):
		return String(expected) == String(actual)
	# 向量族（对齐 _are_types_compatible）
	if et == TYPE_VECTOR2 and at == TYPE_VECTOR2I:
		return Vector2(expected) == Vector2(actual)
	if et == TYPE_VECTOR2I and at == TYPE_VECTOR2:
		return Vector2(expected) == Vector2(actual)
	if et == TYPE_VECTOR3 and at == TYPE_VECTOR3I:
		return Vector3(expected) == Vector3(actual)
	if et == TYPE_VECTOR3I and at == TYPE_VECTOR3:
		return Vector3(expected) == Vector3(actual)
	return false

## 创建参数上下文字典
func create_arg_context(values):
	var context = {}

	for i in range(min(values.size(), args.size())):
		var arg = args[i]
		var arg_name = arg.name if arg.has("name") else "arg%d" % i
		context[arg_name] = values[i]

	return context

## 序列化信号信息
func serialize():
	return {
		"name": name,
		"args": args,
		"default_args": default_args,
		"flags": flags,
		"owner_node_class": owner_node_class,
		"description": description
	}

## 从字典反序列化
func deserialize(data):
	name = data.get("name", "")
	args = data.get("args", [])
	default_args = data.get("default_args", [])
	flags = data.get("flags", 0)
	owner_node_class = data.get("owner_node_class", "")
	description = data.get("description", "")

## 获取调试信息
func get_debug_info():
	var info = "SignalInfo: %s" % name
	if not args.is_empty():
		info += " (%d args)" % args.size()
	if not owner_node_class.is_empty():
		info += " [%s]" % owner_node_class
	return info

## 私有方法：获取类型字符串
func _get_type_string(type: int):
	match type:
		TYPE_NIL: return "Variant"
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
		_: return "Variant"

## 私有方法：检查类型兼容性
func _are_types_compatible(type1: int, type2: int):
	# 完全匹配
	if type1 == type2:
		return true

	# 数值类型兼容性
	var numeric_types = [TYPE_INT, TYPE_FLOAT]
	if type1 in numeric_types and type2 in numeric_types:
		return true

	# 向量类型兼容性
	var vector2_types = [TYPE_VECTOR2, TYPE_VECTOR2I]
	var vector3_types = [TYPE_VECTOR3, TYPE_VECTOR3I]

	if type1 in vector2_types and type2 in vector2_types:
		return true

	if type1 in vector3_types and type2 in vector3_types:
		return true

	# 字符串可以接受任何类型
	if type1 == TYPE_STRING or type2 == TYPE_STRING:
		return true

	return false

## 私有方法：检查值是否对类型有效
func _is_value_valid_for_type(value: Variant, type: int):
	if value == null:
		return type == TYPE_NIL or type == TYPE_OBJECT

	var value_type = typeof(value)
	return _are_types_compatible(value_type, type)