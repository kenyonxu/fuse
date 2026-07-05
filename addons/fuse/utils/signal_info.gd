# 文件：addons/fuse/utils/signal_info.gd
@tool
class_name SignalInfo extends Resource

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

## 获取参数的属性列表（用于编辑器）
func get_arg_property_list():
	var properties = []
	
	for i in range(args.size()):
		var arg = args[i]
		var property = {
			"name": "arg_%d" % i,
			"type": arg.type,
			"usage": PROPERTY_USAGE_DEFAULT
		}
		
		# 添加提示信息
		if arg.has("hint"):
			property["hint"] = arg.hint
		if arg.has("hint_string"):
			property["hint_string"] = arg.hint_string
		
		# 添加显示名称
		var arg_name = arg.name if arg.has("name") else "参数 %d" % i
		property["name"] = "arg_filter_values/%d_%s" % [i, arg_name]
		
		properties.append(property)
	
	return properties

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