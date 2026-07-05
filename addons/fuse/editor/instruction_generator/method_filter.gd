# 文件：addons/fuse/editor/instruction_generator/method_filter.gd
@tool
class_name MethodFilter extends RefCounted

## 方法过滤器
## 薄层封装 FunctionManager 的过滤逻辑，添加按类分组功能
## 纯新增功能：
##   - filter_methods(): 按定义类分组
##   - get_class_methods_with_inheritance(): 基于 ClassDB 的方法列表（含继承信息）
## 复用 FunctionManager 的：
##   - _should_filter_method(): 过滤私有/虚方法
##   - _is_getter_method(): 过滤 getter
##   - get_inheritance_chain(): 继承链
##   - is_virtual_method_from_info() / is_static_method_from_info(): 方法标志

## 过滤方法列表并按定义类分组
## @param methods: 原始方法列表（来自 ClassDB.class_get_method_list）
## @return: 按类分组的方法字典 {class_name: [method_info, ...]}
static func filter_methods(methods: Array[Dictionary]) -> Dictionary:
	var result := {}

	for method_info in methods:
		var method_name = method_info.get("name", "")

		# 复用 FunctionManager 的过滤逻辑
		if _should_skip_method(method_name, method_info):
			continue

		var defined_in = method_info.get("defined_in_class", "")
		if defined_in.is_empty():
			defined_in = "Unknown"

		if not result.has(defined_in):
			result[defined_in] = []

		result[defined_in].append({
			"name": method_name,
			"args": method_info.get("args", []),
			"return": method_info.get("return", {}),
			"flags": method_info.get("flags", 0),
			"defined_in_class": defined_in,
			"has_default_values": _has_default_values(method_info)
		})

	return result

## 判断方法是否应该跳过
## 组合复用 FunctionManager 的多个静态方法，并添加指令生成器特有的过滤
static func _should_skip_method(method_name: String, method_info: Dictionary) -> bool:
	# 复用: FunctionManager._should_filter_method()
	if FunctionManager._should_filter_method(method_name):
		return true

	# 复用: FunctionManager.is_virtual_method_from_info()
	if FunctionManager.is_virtual_method_from_info(method_info):
		return true

	# 复用: FunctionManager.is_static_method_from_info()
	if FunctionManager.is_static_method_from_info(method_info):
		return true

	# 跳过 Object 基类方法（free, get_class, set, get 等对指令生成无意义）
	var defined_in = method_info.get("defined_in_class", "")
	if defined_in == "Object":
		return true

	# 跳过不适合生成指令的 Node 内部方法
	if defined_in == "Node" and method_name in _NODE_INTERNAL_METHODS:
		return true

	# 跳过 CanvasItem draw 方法（Canvas 绘制 API，不适合生成指令）
	if defined_in == "CanvasItem" and method_name.begins_with("draw_"):
		return true

	return false

## Node 内部方法黑名单（不适合生成指令的方法）
const _NODE_INTERNAL_METHODS: PackedStringArray = [
	"add_sibling", "reparent", "get_child_count", "get_children", "get_child",
	"has_node", "find_child", "find_children", "find_parent",
	"has_node_and_resource", "get_node_and_resource",
	"is_inside_tree", "is_part_of_edited_scene", "is_ancestor_of", "is_greater_than",
	"get_path", "get_path_to", "add_to_group", "remove_from_group", "is_in_group",
	"move_child", "get_groups", "set_owner", "get_owner", "get_index",
	"print_tree", "print_tree_pretty", "get_tree_string", "get_tree_string_pretty",
	"set_scene_file_path", "get_scene_file_path",
	"propagate_notification", "propagate_call",
	"can_process", "get_process_mode", "set_process_mode",
	"get_process_priority", "set_process_priority",
	"get_process_delta_time", "get_physics_process_delta_time",
	"is_physics_processing", "is_processing", "is_processing_input",
	"get_process_thread_group", "set_process_thread_group",
	"get_multiplayer_authority", "is_multiplayer_authority",
	"rpc", "rpc_id", "rpc_config", "get_node_rpc_config",
	"set_multiplayer", "get_multiplayer",
	"set_editor_description", "get_editor_description",
	"set_unique_name_in_owner", "is_unique_name_in_owner",
	"duplicate", "replace_by", "get_viewport", "get_window",
	"get_last_exclusive_window", "get_tree",
	"queue_free", "request_ready", "is_node_ready",
	"update_configuration_warnings",
]

## 检查方法是否有默认参数值
static func _has_default_values(method_info: Dictionary) -> bool:
	var args = method_info.get("args", [])
	for arg in args:
		if arg.has("default_value"):
			return true
	return false

## 获取类的继承链
## 复用 ClassDB API（FunctionManager 的版本需要 Node 实例，这里直接用类名字符串）
## @param class_name: 类名
## @return: 继承链数组 [class_name, parent_class, ...]
static func get_inheritance_chain(cls_name: String) -> Array[String]:
	var chain: Array[String] = []
	var current = cls_name

	while not current.is_empty():
		chain.append(current)
		current = ClassDB.get_parent_class(current)
		if chain.size() > 50:
			break

	return chain

## 获取类的方法列表（带继承信息）
## 注意：这个方法基于 ClassDB（不需要 Node 实例），与 FunctionManager 的版本互补
## @param class_name: 类名
## @return: 方法列表，每个方法包含 defined_in_class 字段
static func get_class_methods_with_inheritance(cls_name: String) -> Array[Dictionary]:
	var all_methods: Array[Dictionary] = []
	var chain = get_inheritance_chain(cls_name)

	chain.reverse()
	for cls in chain:
		var class_methods = ClassDB.class_get_method_list(cls, true)
		for method in class_methods:
			method["defined_in_class"] = cls

			var existing_index = -1
			for i in range(all_methods.size()):
				if all_methods[i].get("name") == method.get("name"):
					existing_index = i
					break

			if existing_index >= 0:
				all_methods[existing_index] = method
			else:
				all_methods.append(method)

	return all_methods
