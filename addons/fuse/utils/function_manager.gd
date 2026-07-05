@tool
class_name FunctionManager
extends RefCounted

## FunctionManager 通用类
## 提供方法发现、验证和安全调用的功能

## Callable 缓存
## 缓存已验证的 Callable 对象，跳过运行时字符串查找
static var _callable_cache: Dictionary = {}
static var _callable_cache_max: int = 500  # 缓存上限
static var _callable_cache_order: Array = []  # LRU 访问顺序

## 获取缓存的 Callable
## 如果缓存命中且目标节点仍然有效，直接返回 Callable
## 否则验证方法可调用性后创建并缓存
static func get_cached_callable(node: Node, method_name: String) -> Callable:
	if not node or method_name.is_empty():
		return Callable()

	var instance_id = node.get_instance_id()
	var cache_key = "%d:%s" % [instance_id, method_name]

	if _callable_cache.has(cache_key):
		var cached: Callable = _callable_cache[cache_key]
		# 验证目标节点是否仍然有效
		if is_instance_valid(node) and node.has_method(method_name):
			_update_callable_cache_order(cache_key)
			return cached
		# 缓存失效，移除
		_callable_cache.erase(cache_key)
		_remove_callable_cache_order(cache_key)

	if not is_method_callable(node, method_name):
		return Callable()

	_evict_callable_cache_if_needed()

	var callable = Callable(node, method_name)
	_callable_cache[cache_key] = callable
	_callable_cache_order.append(cache_key)
	return callable

## 批量缓存 Callable（在方法列表发现时调用）
## 避免后续逐个方法调用 get_cached_callable 的开销
static func cache_callables_for_node(node: Node, method_names: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	if not node:
		return result

	var instance_id = node.get_instance_id()

	for method_name in method_names:
		var cache_key = "%d:%s" % [instance_id, method_name]
		if _callable_cache.has(cache_key):
			var cached: Callable = _callable_cache[cache_key]
			if is_instance_valid(node) and node.has_method(method_name):
				result[method_name] = cached
				continue

		if node.has_method(method_name):
			_evict_callable_cache_if_needed()
			var callable = Callable(node, method_name)
			_callable_cache[cache_key] = callable
			_callable_cache_order.append(cache_key)
			result[method_name] = callable

	return result

## 清除指定节点的 Callable 缓存
static func clear_callable_cache(node: Node):
	if not node:
		return
	var instance_key = "%d:" % node.get_instance_id()
	var keys_to_remove: Array = []
	for key in _callable_cache:
		if key.begins_with(instance_key):
			keys_to_remove.append(key)
	for key in keys_to_remove:
		_callable_cache.erase(key)
		_remove_callable_cache_order(key)

## 清除所有 Callable 缓存
static func clear_all_callable_cache():
	_callable_cache.clear()
	_callable_cache_order.clear()

## 更新 LRU 访问顺序
static func _update_callable_cache_order(cache_key: String):
	var idx = _callable_cache_order.find(cache_key)
	if idx >= 0:
		_callable_cache_order.remove_at(idx)
	_callable_cache_order.append(cache_key)

## 从访问顺序中移除
static func _remove_callable_cache_order(cache_key: String):
	var idx = _callable_cache_order.find(cache_key)
	if idx >= 0:
		_callable_cache_order.remove_at(idx)

## LRU 淘汰
static func _evict_callable_cache_if_needed():
	while _callable_cache.size() >= _callable_cache_max and _callable_cache_order.size() > 0:
		var oldest = _callable_cache_order[0]
		_callable_cache_order.pop_front()
		_callable_cache.erase(oldest)

## 获取缓存统计
static func get_callable_cache_stats() -> Dictionary:
	return {
		"cached_entries": _callable_cache.size(),
		"cache_keys": _callable_cache.keys()
	}

## 获取节点的可调用方法
## 过滤掉私有方法和内部方法，只返回用户可调用的公开方法
## @param node: 目标节点
## @param included_levels: 包含的继承级别位掩码（0xFFFFFFFF = 所有级别）
## @param exclude_getters: 是否排除 getter 方法（get_/is_/has_ 开头）
## @param debug: 是否输出调试信息
## @return: 可调用方法列表
static func get_callable_methods(node: Node, included_levels: int = 0xFFFFFFFF, exclude_getters: bool = true, debug: bool = false) -> Array[Dictionary]:
	if not node:
		return []

	var callable_methods: Array[Dictionary] = []
	var method_list = node.get_method_list()

	if debug:
		print("FunctionManager.get_callable_methods() 调试信息:")
		print("  目标类型: %s" % node.get_class())
		print("  included_levels 位掩码: 0x%X" % included_levels)
		print("  exclude_getters: %s" % exclude_getters)
		print("  原始方法数量: %d" % method_list.size())

		# 显示继承链
		var chain = get_inheritance_chain(node)
		print("  继承链:")
		for level_info in chain:
			print("    级别 %d: %s (位掩码: 0x%X)" % [level_info.level, level_info.class_name, 1 << level_info.level])

	var filtered_getter_count = 0
	var filtered_level_count = 0
	var filtered_private_count = 0
	var filtered_uncallable_count = 0

	for method_info in method_list:
		var method_name = method_info.get("name", "")

		# 过滤掉私有方法和特殊方法
		if _should_filter_method(method_name):
			filtered_private_count += 1
			if debug and method_name.begins_with("_"):
				print("  [过滤] %s (私有/内部方法)" % method_name)
			continue

		# 过滤 getter 方法（如果启用）
		if exclude_getters and _is_getter_method(method_name):
			filtered_getter_count += 1
			if debug:
				print("  [过滤] %s (getter 方法)" % method_name)
			continue

		# 检测方法定义位置
		var def_info = detect_method_definition(node, method_name)
		var method_level = def_info.get("level", 0)

		# 检查是否在包含的级别中
		if not _is_level_included(method_level, included_levels):
			filtered_level_count += 1
			if debug:
				print("  [过滤] %s (级别 %d 不在位掩码 0x%X 中，定义于 %s)" % [method_name, method_level, included_levels, def_info.get("class_name", "")])
			continue

		# 检查方法是否可调用
		if is_method_callable(node, method_name):
			# 附加继承级别信息
			method_info["defined_in_class"] = def_info.get("class_name", "")
			method_info["inheritance_level"] = method_level
			callable_methods.append(method_info)
			if debug:
				print("  [通过] %s (级别 %d, 定义于 %s)" % [method_name, method_level, def_info.get("class_name", "")])
		else:
			filtered_uncallable_count += 1
			if debug:
				print("  [过滤] %s (不可调用)" % method_name)

	if debug:
		print("  过滤统计:")
		print("    私有/内部方法: %d" % filtered_private_count)
		print("    Getter 方法: %d" % filtered_getter_count)
		print("    级别不符: %d" % filtered_level_count)
		print("    不可调用: %d" % filtered_uncallable_count)
		print("  最终结果: %d 个方法" % callable_methods.size())
		print("")

	# 按方法名排序，便于用户选择
	callable_methods.sort_custom(func(a, b): return a.get("name", "") < b.get("name", ""))

	return callable_methods

## 获取方法的参数信息
static func get_method_parameters(method_info: Dictionary) -> Array[Dictionary]:
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

## 验证方法可调用性
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

## 安全调用方法
## 返回字典包含: {"success": bool, "result": Variant, "error": String}
## 优先使用缓存的 Callable，跳过字符串查找
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

	# 优先使用缓存的 Callable
	var cached = get_cached_callable(node, method_name)
	if cached.is_valid():
		var call_result = cached.callv(args)
		result.success = true
		result.result = call_result
		return result

	# Fallback：无缓存时走原有验证路径
	if not is_method_callable(node, method_name):
		result.error = "方法不存在或不可调用: %s" % method_name
		return result

	# 获取方法信息以验证参数
	var method_info = _get_method_info(node, method_name)
	if not method_info:
		result.error = "无法获取方法信息: %s" % method_name
		return result

	# 验证参数
	var validation_result = _validate_arguments(node, method_name, args, method_info)
	if not validation_result.success:
		result.error = validation_result.error
		return result

	# 安全调用方法
	var call_result = node.callv(method_name, args)
	result.success = true
	result.result = call_result

	return result

## 获取方法信息
static func _get_method_info(node: Node, method_name: String) -> Dictionary:
	if not node or method_name.is_empty():
		return {}
	
	var method_list = node.get_method_list()
	for method_info in method_list:
		if method_info.get("name", "") == method_name:
			return method_info
	
	return {}

## 验证参数
static func _validate_arguments(node: Node, method_name: String, args: Array, method_info: Dictionary) -> Dictionary:
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
			result.error = "参数 %d 类型不匹配: 期望 %s，实际 %s" % [
				i, 
				_get_type_name(expected_type), 
				_get_type_name(actual_type)
			]
			return result
	
	result.success = true
	return result

## 检查类型兼容性
static func _is_type_compatible(actual_type: int, expected_type: int) -> bool:
	# 完全匹配
	if actual_type == expected_type:
		return true
	
	# 允许 nil 到对象的转换
	if actual_type == TYPE_NIL and expected_type == TYPE_OBJECT:
		return true
	
	# Vector 类型兼容性（Vector2 ↔ Vector2I）
	if actual_type == TYPE_VECTOR2 and expected_type == TYPE_VECTOR2I:
		return true
	if actual_type == TYPE_VECTOR2I and expected_type == TYPE_VECTOR2:
		return true
	
	# Vector 类型兼容性（Vector3 ↔ Vector3I）
	if actual_type == TYPE_VECTOR3 and expected_type == TYPE_VECTOR3I:
		return true
	if actual_type == TYPE_VECTOR3I and expected_type == TYPE_VECTOR3:
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

## 过滤不应该调用的方法
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
## 这类方法通常用于查询状态，在 Fuse 场景中意义不大
## @param method_name: 方法名称
## @return: 是否为 getter 方法
static func _is_getter_method(method_name: String) -> bool:
	if method_name.is_empty():
		return false

	# 过滤 get/is/has 开头的方法
	if method_name.begins_with("get_") or method_name.begins_with("is_") or method_name.begins_with("has_"):
		return true

	return false

## 获取节点的完整继承链
## @param node: 目标节点
## @return: 继承链信息数组，每个元素包含 class_name, level, bit_position
static func get_inheritance_chain(node: Node) -> Array[Dictionary]:
	if not node:
		return []

	var chain: Array[Dictionary] = []
	var script_class_name = ""

	# 首先检查节点是否有脚本，并尝试获取脚本类名
	if node.has_method("get_script"):
		var script = node.get_script()
		if script and script.has_method("get_global_name"):
			var global_name = script.get_global_name()
			if not global_name.is_empty():
				script_class_name = str(global_name)

	# 如果脚本没有全局名称，尝试从脚本路径获取
	if script_class_name.is_empty() and node.has_method("get_script"):
		var script = node.get_script()
		if script and script.has_method("get_path"):
			var script_path = script.get_path()
			if not script_path.is_empty():
				# 从脚本路径提取类名（例如：res://addons/xxx/juicy_timeline_player.gd -> JuicyTimelinePlayer）
				var file_name = script_path.get_file().get_basename()
				# 转换为 PascalCase (simple version)
				script_class_name = _to_pascal_case(file_name)

	# 如果成功获取了脚本类名，将其作为第 0 级
	var start_level = 0
	if not script_class_name.is_empty():
		chain.append({
			"class_name": script_class_name,
			"level": 0,
			"bit_position": 0
		})
		start_level = 1  # 原生类从级别 1 开始

	# 获取原生类名
	var cls_name = node.get_class()

	# 递归构建原生类的继承链
	var current_cls = cls_name
	var level = start_level

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

## 将字符串转换为 PascalCase
## 例如：juicy_timeline_player -> JuicyTimelinePlayer
static func _to_pascal_case(s: String) -> String:
	if s.is_empty():
		return s

	var parts = s.split("_")
	var result = ""

	for part in parts:
		if not part.is_empty():
			# 首字母大写，其余小写
			result += part.substr(0, 1).to_upper() + part.substr(1).to_lower()

	return result

## 检测方法定义位置
## @param node: 目标节点
## @param method_name: 方法名
## @return: 方法定义所在的类名和级别
static func detect_method_definition(node: Node, method_name: String) -> Dictionary:
	if not node or method_name.is_empty():
		return {"class_name": "", "level": -1}

	var inheritance_chain = get_inheritance_chain(node)

	# 遍历继承链，从脚本类开始向上查找
	for i in range(inheritance_chain.size()):
		var current_class = inheritance_chain[i].class_name

		# 检查是否是脚本类（不是 ClassDB 中的原生类）
		var is_script_class = not ClassDB.class_exists(current_class)

		if is_script_class:
			# 对于脚本类，我们需要检查脚本源代码来确定方法是否在那里定义
			# 但由于在运行时无法直接读取脚本源代码，我们使用排除法：
			# 检查该方法是否在继承链的任何原生类中定义
			var found_in_native_chain = false
			var found_at_level = -1

			# 检查所有原生类
			for j in range(i, inheritance_chain.size()):
				var native_class = inheritance_chain[j].class_name
				if ClassDB.class_exists(native_class):
					var class_methods = ClassDB.class_get_method_list(native_class, true)
					for method_dict in class_methods:
						if method_dict.get("name", "") == method_name:
							found_in_native_chain = true
							found_at_level = j
							break
					if found_in_native_chain:
						break

			# 如果不在任何原生类中，才认为是在脚本类中定义的
			if not found_in_native_chain:
				# 额外验证：检查节点是否真的有这个方法
				if node.has_method(method_name):
					return {
						"class_name": current_class,
						"level": i
					}
		else:
			# 对于原生类，使用 ClassDB
			if ClassDB.class_exists(current_class):
				var class_methods = ClassDB.class_get_method_list(current_class, true)
				for method_dict in class_methods:
					if method_dict.get("name", "") == method_name:
						return {
							"class_name": current_class,
							"level": i
						}

	# 如果没找到（可能是虚方法或动态方法），返回当前原生类
	var cls_name = node.get_class()
	return {
		"class_name": cls_name,
		"level": inheritance_chain.size() - 1  # 返回原生类的级别
	}

## 检查级别是否包含在位掩码中
## @param level: 继承级别
## @param bitmask: 位掩码
## @return: 是否包含
static func _is_level_included(level: int, bitmask: int) -> bool:
	return (bitmask & (1 << level)) != 0

## 获取类型名称
static func _get_type_name(type: int) -> String:
	match type:
		TYPE_NIL: return "NIL"
		TYPE_BOOL: return "BOOL"
		TYPE_INT: return "INT"
		TYPE_FLOAT: return "FLOAT"
		TYPE_STRING: return "STRING"
		TYPE_VECTOR2: return "VECTOR2"
		TYPE_VECTOR2I: return "VECTOR2I"
		TYPE_VECTOR3: return "VECTOR3"
		TYPE_VECTOR3I: return "VECTOR3I"
		TYPE_COLOR: return "COLOR"
		TYPE_ARRAY: return "ARRAY"
		TYPE_DICTIONARY: return "DICTIONARY"
		TYPE_OBJECT: return "OBJECT"
		TYPE_NODE_PATH: return "NODE_PATH"
		TYPE_PACKED_BYTE_ARRAY: return "PACKED_BYTE_ARRAY"
		TYPE_PACKED_INT32_ARRAY: return "PACKED_INT32_ARRAY"
		TYPE_PACKED_FLOAT32_ARRAY: return "PACKED_FLOAT32_ARRAY"
		TYPE_PACKED_STRING_ARRAY: return "PACKED_STRING_ARRAY"
		TYPE_PACKED_VECTOR2_ARRAY: return "PACKED_VECTOR2_ARRAY"
		TYPE_PACKED_VECTOR3_ARRAY: return "PACKED_VECTOR3_ARRAY"
		TYPE_PACKED_COLOR_ARRAY: return "PACKED_COLOR_ARRAY"
		_: return "UNKNOWN"

## 获取最后的错误信息
static func _get_last_error() -> String:
	# 获取 Godot 引擎的最后错误信息
	var error = Engine.get_main_loop().get_meta("last_error", "")
	if error:
		return error
	
	# 如果没有具体的错误信息，返回通用错误
	return "未知错误"

## 获取方法的返回类型
static func get_method_return_type(method_info: Dictionary) -> int:
	if not method_info or not method_info.has("return"):
		return TYPE_NIL
	
	var return_info = method_info.get("return", {})
	return return_info.get("type", TYPE_NIL)

## 检查方法是否有返回值
static func method_has_return_value(method_info: Dictionary) -> bool:
	var return_type = get_method_return_type(method_info)
	return return_type != TYPE_NIL

## 获取方法的参数数量
static func get_method_argument_count_from_info(method_info: Dictionary) -> int:
	if not method_info or not method_info.has("args"):
		return 0
	
	var args = method_info.get("args", [])
	return args.size()

## 获取方法的参数类型列表
static func get_method_argument_types_from_info(method_info: Dictionary) -> Array[int]:
	if not method_info or not method_info.has("args"):
		return []
	
	var types: Array[int] = []
	var args = method_info.get("args", [])
	
	for arg in args:
		types.append(arg.get("type", TYPE_NIL))
	
	return types

## 检查方法是否为虚方法
static func is_virtual_method_from_info(method_info: Dictionary) -> bool:
	if not method_info:
		return false
	
	var flags = method_info.get("flags", 0)
	return (flags & METHOD_FLAG_VIRTUAL) != 0

## 检查方法是否为静态方法
static func is_static_method_from_info(method_info: Dictionary) -> bool:
	if not method_info:
		return false
	
	var flags = method_info.get("flags", 0)
	return (flags & METHOD_FLAG_STATIC) != 0

## 检查方法是否为常量方法
static func is_const_method_from_info(method_info: Dictionary) -> bool:
	if not method_info:
		return false
	
	var flags = method_info.get("flags", 0)
	return (flags & METHOD_FLAG_CONST) != 0
