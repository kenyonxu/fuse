## JuicyMethodReflection
## JuicyMixer 方法反射工具类
## 提供方法发现、验证和类型检查功能

class_name JuicyMethodReflection
extends RefCounted

## 获取节点的可调用方法
## 过滤掉私有方法和内部方法，只返回用户可调用的公开方法
## @param node: 要反射的节点
## @param included_levels: 包含的继承级别位掩码（默认 0xFFFFFFFF = 所有级别）
## @param exclude_getters: 是否排除 getter 方法（get/is/has 开头，默认 true）
## @return: 可调用方法的信息字典数组
static func get_callable_methods(node: Node, included_levels: int = 0xFFFFFFFF, exclude_getters: bool = true) -> Array[Dictionary]:
	if not node:
		return []

	var callable_methods: Array[Dictionary] = []
	var method_list = node.get_method_list()

	for method_info in method_list:
		var method_name = method_info.get("name", "")

		# 过滤掉私有方法和特殊方法
		if _should_filter_method(method_name):
			continue

		# 过滤 getter 方法（如果启用）
		if exclude_getters and _is_getter_method(method_name):
			continue

		# 检测方法定义位置
		var def_info = detect_method_definition(node, method_name)
		var method_level = def_info.get("level", 0)

		# 检查是否在包含的级别中
		if not _is_level_included(method_level, included_levels):
			continue

		# 检查方法是否可调用
		if is_method_callable(node, method_name):
			# 附加继承级别信息
			method_info["defined_in_class"] = def_info.get("class_name", "")
			method_info["inheritance_level"] = method_level
			callable_methods.append(method_info)

	# 按方法名排序，便于用户选择
	callable_methods.sort_custom(func(a, b): return a.get("name", "") < b.get("name", ""))

	return callable_methods

## 验证方法可调用性
## @param node: 要检查的节点
## @param method_name: 方法名称
## @return: 方法是否可调用
static func is_method_callable(node: Node, method_name: String) -> bool:
	if not node or method_name.is_empty():
		return false

	# 首先过滤掉不应该调用的方法
	if _should_filter_method(method_name):
		return false

	# 检查方法是否存在
	var method_list = node.get_method_list()
	for method_info in method_list:
		if method_info.get("name", "") == method_name:
			# 检查方法标志，确保不是私有或内部方法
			var flags = method_info.get("flags", 0)

			# 排除私有方法和受保护的方法
			if flags & METHOD_FLAG_NORMAL == 0:
				return false

			# 排除虚方法和纯虚方法（通常不应该直接调用）
			if flags & METHOD_FLAG_VIRTUAL != 0:
				return false

			return true

	return false

## 获取特定方法的信息
## @param node: 要查询的节点
## @param method_name: 方法名称
## @return: 方法信息字典，如果方法不存在则返回空字典
static func get_method_info(node: Node, method_name: String) -> Dictionary:
	if not node or method_name.is_empty():
		return {}

	var method_list = node.get_method_list()
	for method_info in method_list:
		if method_info.get("name", "") == method_name:
			return method_info

	return {}

## 创建方法信息的轻量级副本
## 只包含必要信息，用于缓存和序列化
## @param method_info: 完整的方法信息字典
## @return: 轻量级方法信息字典
static func create_lightweight_method_info(method_info: Dictionary) -> Dictionary:
	if method_info.is_empty():
		return {}

	return {
		"name": method_info.get("name", ""),
		"args": method_info.get("args", []),
		"return_val": method_info.get("return", {}).get("type", TYPE_NIL),
		"flags": method_info.get("flags", METHOD_FLAG_NORMAL)
	}

## 批量创建轻量级方法信息
## @param methods: 完整方法信息数组
## @return: 轻量级方法信息数组
static func create_lightweight_method_list(methods: Array[Dictionary]) -> Array[Dictionary]:
	var lightweight_list: Array[Dictionary] = []

	for method in methods:
		var lightweight = create_lightweight_method_info(method)
		if not lightweight.is_empty():
			lightweight_list.append(lightweight)

	return lightweight_list

## 从轻量级信息创建 JuicyMethodInfo 对象
## @param lightweight_info: 轻量级方法信息
## @return: JuicyMethodInfo 对象
static func create_method_info_from_lightweight(lightweight_info: Dictionary) -> JuicyMethodInfo:
	if lightweight_info.is_empty():
		return null

	return JuicyMethodInfo.new(lightweight_info)

## 获取方法名称列表
## @param node: 要查询的节点
## @return: 可调用方法名称数组（已排序）
static func get_callable_method_names(node: Node) -> Array[String]:
	if not node:
		return []

	var methods = get_callable_methods(node)
	var names: Array[String] = []

	for method in methods:
		names.append(method.get("name", ""))

	return names

## 过滤不应该调用的方法
## @param method_name: 方法名称
## @return: 是否应该过滤此方法
static func _should_filter_method(method_name: String) -> bool:
	# 过滤空方法名
	if method_name.is_empty():
		return true

	# 过滤私有方法（以下划线开头）
	if method_name.begins_with("_"):
		return true

	# 过滤特殊方法
	var special_methods = [
		"_init", "_ready", "_enter_tree", "_exit_tree", "_process", "_physics_process",
		"_input", "_unhandled_input", "_unhandled_key_input", "_draw", "_notification",
		"_get", "_set", "_get_property_list", "_property_can_revert", "_property_get_revert",
		"_validate_property", "_get_configuration_warning", "_make_custom_tooltip",
		"_edit_use_anchors", "_edit_get_rect", "_edit_set_rect", "_edit_get_pivot",
		"_edit_set_pivot", "_edit_get_rotation", "_edit_set_rotation", "_edit_get_scale",
		"_edit_set_scale", "_edit_get_transform", "_edit_set_transform", "_edit_get_rect",
		"_edit_use_rect", "_edit_get_rotation", "_edit_set_rotation"
	]

	return method_name in special_methods

## 检查是否为 getter 方法（get/is/has 开头）
## 这类方法通常用于查询状态，在 Timeline 场景中意义不大
## @param method_name: 方法名称
## @return: 是否为 getter 方法
static func _is_getter_method(method_name: String) -> bool:
	if method_name.is_empty():
		return false

	# 过滤 get/is/has 开头的方法
	if method_name.begins_with("get_") or method_name.begins_with("is_") or method_name.begins_with("has_"):
		return true

	return false

## 安全调用方法
## @param node: 目标节点
## @param method_name: 方法名称
## @param args: 参数数组
## @return: 包含 success, result, error 的字典
static func call_method_safe(node: Node, method_name: String, args: Array) -> Dictionary:
	var result = {
		"success": false,
		"result": null,
		"error": ""
	}

	# 验证输入
	if not node:
		result.error = "目标节点为空"
		return result

	if method_name.is_empty():
		result.error = "方法名为空"
		return result

	# 验证方法可调用性
	if not is_method_callable(node, method_name):
		result.error = "方法不存在或不可调用: %s" % method_name
		return result

	# 获取方法信息以验证参数
	var method_info = get_method_info(node, method_name)
	if method_info.is_empty():
		result.error = "无法获取方法信息: %s" % method_name
		return result

	# 验证参数
	var validation_result = _validate_arguments(method_info, args)
	if not validation_result.success:
		result.error = validation_result.error
		return result

	# 安全调用方法
	var call_result = node.callv(method_name, args)
	result.success = true
	result.result = call_result

	return result

## 验证参数
## @param method_info: 方法信息字典
## @param args: 参数数组
## @return: 包含 success 和 error 的字典
static func _validate_arguments(method_info: Dictionary, args: Array) -> Dictionary:
	var result = {
		"success": false,
		"error": ""
	}

	var expected_args = method_info.get("args", [])

	# 检查参数数量
	if args.size() != expected_args.size():
		result.error = "参数数量不匹配: 期望 %d，实际 %d" % [expected_args.size(), args.size()]
		return result

	# 检查每个参数类型
	for i in range(expected_args.size()):
		var expected_type = expected_args[i].get("type", TYPE_NIL)
		var actual_value = args[i]
		var actual_type = typeof(actual_value)

		# 允许 null 值（对于对象类型）
		if actual_value == null and (expected_type == TYPE_OBJECT or expected_type == TYPE_NIL):
			continue

		# 检查类型兼容性
		if not _is_type_compatible(actual_type, expected_type):
			var type_name = _get_type_name(expected_type)
			var actual_type_name = _get_type_name(actual_type)
			result.error = "参数 %d 类型不匹配: 期望 %s，实际 %s" % [
				i,
				type_name,
				actual_type_name
			]
			return result

	result.success = true
	return result

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

## 检查方法是否为虚方法
## @param method_info: 方法信息字典
## @return: 是否为虚方法
static func is_virtual_method(method_info: Dictionary) -> bool:
	if not method_info:
		return false

	var flags = method_info.get("flags", 0)
	return (flags & METHOD_FLAG_VIRTUAL) != 0

## 检查方法是否为静态方法
## @param method_info: 方法信息字典
## @return: 是否为静态方法
static func is_static_method(method_info: Dictionary) -> bool:
	if not method_info:
		return false

	var flags = method_info.get("flags", 0)
	return (flags & METHOD_FLAG_STATIC) != 0

## 检查方法是否为常量方法
## @param method_info: 方法信息字典
## @return: 是否为常量方法
static func is_const_method(method_info: Dictionary) -> bool:
	if not method_info:
		return false

	var flags = method_info.get("flags", 0)
	return (flags & METHOD_FLAG_CONST) != 0

## 获取方法的返回类型
## @param method_info: 方法信息字典
## @return: 返回类型常量
static func get_method_return_type(method_info: Dictionary) -> int:
	if not method_info or not method_info.has("return"):
		return TYPE_NIL

	var return_info = method_info.get("return", {})
	return return_info.get("type", TYPE_NIL)

## 检查方法是否有返回值
## @param method_info: 方法信息字典
## @return: 是否有返回值
static func method_has_return_value(method_info: Dictionary) -> bool:
	var return_type = get_method_return_type(method_info)
	return return_type != TYPE_NIL

## 获取方法的参数数量
## @param method_info: 方法信息字典
## @return: 参数数量
static func get_method_argument_count_from_info(method_info: Dictionary) -> int:
	if not method_info or not method_info.has("args"):
		return 0

	var args = method_info.get("args", [])
	return args.size()

## 获取方法的参数类型列表（从方法信息字典）
## @param method_info: 方法信息字典
## @return: 参数类型数组
static func get_method_argument_types_from_info(method_info: Dictionary) -> Array[int]:
	if not method_info or not method_info.has("args"):
		return []

	var types: Array[int] = []
	var args = method_info.get("args", [])

	for arg in args:
		types.append(arg.get("type", TYPE_NIL))

	return types

## 搜索方法
## 根据名称前缀搜索方法
## @param node: 要搜索的节点
## @param prefix: 方法名前缀
## @return: 匹配的方法名称数组
static func search_methods_by_prefix(node: Node, prefix: String) -> Array[String]:
	if not node or prefix.is_empty():
		return []

	var method_names = get_callable_method_names(node)
	var matched_names: Array[String] = []

	for method_name in method_names:
		if method_name.begins_with(prefix):
			matched_names.append(method_name)

	return matched_names

## 获取方法的简短描述
## @param method_info: 方法信息字典
## @return: 方法的简短描述字符串
static func get_method_description(method_info: Dictionary) -> String:
	if method_info.is_empty():
		return "未知方法"

	var method_name = method_info.get("name", "")
	var args = method_info.get("args", [])
	var return_info = method_info.get("return", {})
	var return_type = return_info.get("type", TYPE_NIL)

	# 构建参数列表
	var arg_list: Array[String] = []
	for i in range(args.size()):
		var arg = args[i]
		var arg_name = arg.get("name", "param_%d" % i)
		var arg_type = _get_type_name(arg.get("type", TYPE_NIL))
		arg_list.append("%s: %s" % [arg_name, arg_type])

	# 构建描述
	var description = "%s(%s)" % [method_name, ", ".join(arg_list)]

	if return_type != TYPE_NIL:
		var return_type_name = _get_type_name(return_type)
		description += " -> %s" % return_type_name

	return description

## ============================================
## 继承级别检测
## ============================================

## 获取节点的完整继承链
## @param node: 目标节点
## @return: 继承链信息数组，每个元素包含 class_name, level, bit_position
static func get_inheritance_chain(node: Node) -> Array[Dictionary]:
	if not node:
		return []

	var chain: Array[Dictionary] = []
	var cls_name = node.get_class()

	# 递归构建继承链
	var current_cls = cls_name
	var level = 0

	while current_cls != "":
		chain.append({
			"class_name": current_cls,
			"level": level,
			"bit_position": level
		})

		# 获取父类
		current_cls = ClassDB.get_parent_class(current_cls)
		level += 1

		# 防止无限循环
		if level > 100:
			break

	return chain

## 检测方法定义位置
## @param node: 目标节点
## @param method_name: 方法名
## @return: 方法定义所在的类名和级别
static func detect_method_definition(node: Node, method_name: String) -> Dictionary:
	if not node or method_name.is_empty():
		return {"class_name": "", "level": -1}

	var cls_name = node.get_class()
	var inheritance_chain = get_inheritance_chain(node)

	# 从当前类开始向上查找
	for i in range(inheritance_chain.size()):
		var current_class = inheritance_chain[i].class_name

		# 使用 ClassDB.class_get_method_list 获取该类的方法列表（不包括继承的）
		# 第二个参数 no_inherit = true 表示只获取该类自己定义的方法
		var class_methods = ClassDB.class_get_method_list(current_class, true)
		for method_dict in class_methods:
			if method_dict.get("name", "") == method_name:
				return {
					"class_name": current_class,
					"level": i
				}

	# 如果没找到（可能是虚方法或动态方法），返回当前类
	return {
		"class_name": cls_name,
		"level": 0
	}

## 检查级别是否包含在位掩码中
## @param level: 继承级别
## @param bitmask: 位掩码
## @return: 是否包含
static func _is_level_included(level: int, bitmask: int) -> bool:
	return (bitmask & (1 << level)) != 0
