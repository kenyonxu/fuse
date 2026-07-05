@tool
class_name JuicyPropertyManager
extends RefCounted

## Juicy属性管理器
## 专门为Property Track提供属性发现、过滤和验证功能

## 缓存系统
static var _property_cache: Dictionary = {}

## 属性过滤器
enum PropertyFilter {
	ALL,                ## 所有属性
	NUMERIC_ONLY,        ## 仅数值属性（int, float）
	WRITABLE_ONLY,       ## 仅可写属性
	EXPORTED_ONLY        ## 仅导出属性
}

## 获取节点的所有属性信息
static func get_all_properties(node: Node) -> Array[Dictionary]:
	if node == null:
		return []
	
	var cache_key = str(node.get_instance_id())
	if _property_cache.has(cache_key):
		return _property_cache[cache_key]
	
	var properties: Array[Dictionary] = []
	var property_list = node.get_property_list()
	
	for prop_dict in property_list:
		var property_info = _create_property_info(prop_dict)
		properties.append(property_info)
	
	# 缓存结果
	_property_cache[cache_key] = properties
	
	return properties

## 创建属性信息字典
static func _create_property_info(prop_dict: Dictionary) -> Dictionary:
	return {
		"name": prop_dict.get("name", ""),
		"type": prop_dict.get("type", TYPE_NIL),
		"hint": prop_dict.get("hint", PROPERTY_HINT_NONE),
		"hint_string": prop_dict.get("hint_string", ""),
		"usage": prop_dict.get("usage", PROPERTY_USAGE_DEFAULT),
		"default_value": prop_dict.get("default", null),
		"is_writable": _is_property_writable(prop_dict),
		"is_numeric": _is_property_numeric(prop_dict),
		"is_exported": _is_property_exported(prop_dict)
	}

## 检查属性是否可写
static func _is_property_writable(prop_dict: Dictionary) -> bool:
	var usage = prop_dict.get("usage", PROPERTY_USAGE_DEFAULT)
	return (usage & PROPERTY_USAGE_STORAGE) != 0 and (usage & PROPERTY_USAGE_READ_ONLY) == 0

## 检查属性是否为数值类型
static func _is_property_numeric(prop_dict: Dictionary) -> bool:
	var type = prop_dict.get("type", TYPE_NIL)
	return type in [TYPE_INT, TYPE_FLOAT]

## 检查属性是否已导出
static func _is_property_exported(prop_dict: Dictionary) -> bool:
	var usage = prop_dict.get("usage", PROPERTY_USAGE_DEFAULT)
	return (usage & PROPERTY_USAGE_EDITOR) != 0

## 获取节点的数值属性
static func get_numeric_properties(node: Node) -> Array[Dictionary]:
	return get_filtered_properties(node, PropertyFilter.NUMERIC_ONLY)

## 获取节点的可写属性
static func get_writable_properties(node: Node) -> Array[Dictionary]:
	return get_filtered_properties(node, PropertyFilter.WRITABLE_ONLY)

## 根据过滤器获取属性
static func get_filtered_properties(node: Node, filter: PropertyFilter) -> Array[Dictionary]:
	var all_properties = get_all_properties(node)
	var filtered_properties: Array[Dictionary] = []
	
	for property_info in all_properties:
		if _passes_filter(property_info, filter):
			filtered_properties.append(property_info)
	
	return filtered_properties

## 检查属性是否通过过滤器
static func _passes_filter(property_info: Dictionary, filter: PropertyFilter) -> bool:
	match filter:
		PropertyFilter.ALL:
			return _is_valid_property(property_info)
		PropertyFilter.NUMERIC_ONLY:
			return property_info.is_numeric and _is_valid_property(property_info)
		PropertyFilter.WRITABLE_ONLY:
			return property_info.is_writable and _is_valid_property(property_info)
		PropertyFilter.EXPORTED_ONLY:
			return property_info.is_exported and _is_valid_property(property_info)
		_:
			return _is_valid_property(property_info)

## 检查属性是否有效
static func _is_valid_property(property_info: Dictionary) -> bool:
	var name = property_info.get("name", "")
	
	# 排除空属性名
	if name.is_empty():
		return false
	
	# 排除内部属性（以下划线开头）
	if name.begins_with("_"):
		return false
	
	# 排除类型名属性（全大写或首字母大写且无小写）
	if _looks_like_type_name(name):
		return false
	
	# 排除常见的非设置table属性
	var non_settable_names = [
		"Transform", "Rect2", "Vector2", "Vector3", "Color",
		"String", "int", "float", "bool", "Array", "Dictionary"
	]
	
	if name in non_settable_names:
		return false
	
	# 检查属性类型是否有效
	var type = property_info.get("type", TYPE_NIL)
	if type == TYPE_NIL:
		return false
	
	return true

## 检查属性名是否像类型名
static func _looks_like_type_name(name: String) -> bool:
	# 如果全是小写，可能是实际属性
	if name == name.to_lower():
		return false
	
	# 如果包含下划线，可能是实际属性
	if name.contains("_"):
		return false
	
	# 如果首字母大写且后面没有小写字母，可能是类型名
	if name.length() > 0 and name[0].to_upper() == name[0] and name.substr(1).to_upper() == name.substr(1):
		return true
	
	return false

## 查找指定属性
static func find_property(node: Node, property_name: String) -> Dictionary:
	# 检查是否为嵌套属性（如 modulate.a, position.x）
	if "." in property_name:
		return _find_nested_property(node, property_name)

	# 查找顶层属性
	var properties = get_all_properties(node)

	for property_info in properties:
		if property_info.name == property_name:
			return property_info

	return {}

## 查找嵌套属性（如 modulate.a, position.x）
static func _find_nested_property(node: Node, property_path: String) -> Dictionary:
	var parts = property_path.split(".", false, 1)
	if parts.size() != 2:
		return {}

	var base_property_name = parts[0]
	var channel = parts[1]

	# 先查找基础属性
	var base_property = find_property(node, base_property_name)
	if base_property.is_empty():
		return {}

	# 根据基础属性类型，确定通道类型
	var base_type = base_property.type
	var channel_type = _get_channel_type(base_type, channel)

	if channel_type == TYPE_NIL:
		# 不支持的通道
		return {}

	# 返回合成的嵌套属性信息
	return {
		"name": property_path,
		"type": channel_type,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"usage": base_property.usage,
		"default_value": 0.0,
		"is_writable": base_property.is_writable,
		"is_numeric": channel_type in [TYPE_INT, TYPE_FLOAT],
		"is_exported": false,  # 嵌套属性不是导出的
		"base_property": base_property_name,  # 记录基础属性
		"channel": channel  # 记录通道名
	}

## 获取通道的类型
static func _get_channel_type(base_type: int, channel: String) -> int:
	match base_type:
		TYPE_COLOR:
			# Color.r, .g, .b, .a 都是 float
			if channel in ["r", "g", "b", "a"]:
				return TYPE_FLOAT
		TYPE_VECTOR2:
			# Vector2.x, .y 都是 float
			if channel in ["x", "y"]:
				return TYPE_FLOAT
		TYPE_VECTOR3:
			# Vector3.x, .y, .z 都是 float
			if channel in ["x", "y", "z"]:
				return TYPE_FLOAT
		TYPE_VECTOR4:
			# Vector4.x, .y, .z, .w 都是 float
			if channel in ["x", "y", "z", "w"]:
				return TYPE_FLOAT
		TYPE_TRANSFORM2D:
			# Transform2D 暂不支持通道访问
			pass
		TYPE_TRANSFORM3D:
			# Transform3D 暂不支持通道访问
			pass
		_:
			pass

	return TYPE_NIL  # 不支持的类型

## 检查属性是否存在
static func has_property(node: Node, property_name: String) -> bool:
	return not find_property(node, property_name).is_empty()

## 检查属性是否可写
static func is_property_writable(node: Node, property_name: String) -> bool:
	var property_info = find_property(node, property_name)
	return not property_info.is_empty() and property_info.is_writable

## 验证属性值
static func validate_property_value(node: Node, property_name: String, value: Variant) -> Dictionary:
	var property_info = find_property(node, property_name)
	if property_info.is_empty():
		return {"valid": false, "error": "属性不存在: " + property_name}
	
	if not property_info.is_writable:
		return {"valid": false, "error": "属性不可写: " + property_name}
	
	# 检查类型兼容性
	var expected_type = property_info.type
	var actual_type = typeof(value)
	
	if expected_type != actual_type:
		# 尝试类型转换
		var converted_value = _convert_value(value, expected_type)
		if converted_value == null:
			return {"valid": false, "error": "类型不兼容: 期望 %s, 实际 %s" % [type_string(expected_type), type_string(actual_type)]}
		
		return {"valid": true, "converted_value": converted_value}
	
	return {"valid": true, "converted_value": value}

## 转换值类型
static func _convert_value(value: Variant, target_type: int) -> Variant:
	match target_type:
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			return float(value)
		TYPE_STRING:
			return str(value)
		TYPE_BOOL:
			return bool(value)
		_:
			return null

## 安全设置属性值
static func set_property_safe(node: Node, property_name: String, value: Variant) -> Dictionary:
	var validation = validate_property_value(node, property_name, value)
	if not validation.valid:
		return {"success": false, "error": validation.error}
	
	var converted_value = validation.get("converted_value", value)
	node.set(property_name, converted_value)
	
	return {"success": true, "value": converted_value}

## 获取属性默认值范围
static func get_default_value_range(property_type: int) -> Vector2:
	match property_type:
		TYPE_INT:
			return Vector2(0, 100)
		TYPE_FLOAT:
			return Vector2(0.0, 1.0)
		_:
			return Vector2(0.0, 1.0)

## 获取属性值范围提示字符串
static func get_value_range_hint_string(property_type: int) -> String:
	match property_type:
		TYPE_INT:
			return "-1000,1000,1"  # 最小值,最大值,步长
		TYPE_FLOAT:
			return "-1000,1000,0.01"
		_:
			return ""

## 清除指定节点的缓存
static func clear_cache(node: Node):
	if node == null:
		return
	
	var cache_key = str(node.get_instance_id())
	_property_cache.erase(cache_key)

## 清除所有缓存
static func clear_all_cache():
	_property_cache.clear()
