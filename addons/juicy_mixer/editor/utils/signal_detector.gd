## 信号检测工具类
##
## 提供信号检测、过滤、分组的功能
@tool
class_name SignalDetector

## 排除的内置信号列表
const EXCLUDED_SIGNALS = [
	"tree_entered", "tree_exited", "tree_exiting",
	"renamed", "child_entered_tree",
	"child_exiting_tree", "parent_set",
	"script_changed", "size_changed",
	"child_order_changed", "replacing_by",
	"editor_description_changed", "editor_state_changed",
	"property_list_changed"
]

## 检测节点的所有自定义信号
##
## @param node: 要检测的节点
## @return: 自定义信号信息数组，每个信号包含 name, source_class, arguments
static func detect_custom_signals(node: Node) -> Array:
	if not node:
		push_error("SignalDetector: 节点为空")
		return []

	var all_signals = node.get_signal_list()
	var result = []

	# 获取脚本定义的信号列表（用于识别自定义信号）
	var script_signals = []
	var node_script = node.get_script()
	if node_script:
		script_signals = node_script.get_script_signal_list()

	for signal_info in all_signals:
		var signal_name = signal_info.name

		# 排除以 _ 开头的内部信号
		if signal_name.begins_with("_"):
			continue

		# 排除内置的标准信号
		if signal_name in EXCLUDED_SIGNALS:
			continue

		# 确定信号的来源类
		var source_class = _determine_signal_source_class(node, signal_name, script_signals)

		# 创建增强的信号信息
		var enhanced_info = {
			"name": signal_name,
			"source_class": source_class,
			"arguments": signal_info.get("arguments", []),
			"is_custom": _is_custom_signal(signal_name, script_signals)
		}

		result.append(enhanced_info)

	return result

## 判断信号是否为自定义信号
##
## @param signal_name: 信号名称
## @param script_signals: 脚本定义的信号列表
## @return: 如果是自定义信号返回 true
static func _is_custom_signal(signal_name: String, script_signals: Array) -> bool:
	for sig in script_signals:
		if sig.name == signal_name:
			return true
	return false

## 确定信号的来源类
##
## @param node: 节点
## @param signal_name: 信号名称
## @param script_signals: 脚本定义的信号列表
## @return: 信号的来源类名
static func _determine_signal_source_class(node: Node, signal_name: String, script_signals: Array) -> String:
	# 如果是脚本定义的信号，返回"自定义"
	if _is_custom_signal(signal_name, script_signals):
		return "自定义"

	# 否则遍历类继承链找到信号的定义来源
	var class_chain = []
	var current_class = node.get_class()

	# 构建类继承链（从具体到通用）
	while current_class != "":
		class_chain.append(current_class)
		# 获取父类
		current_class = ClassDB.get_parent_class(current_class)

	# 反转链，使其从通用到具体（Object -> Node -> CanvasItem -> Node2D -> Sprite2D）
	class_chain.reverse()

	# 遍历继承链，找到定义该信号的类（从通用到具体，第一次找到的就是定义来源）
	for cls_name in class_chain:
		if ClassDB.class_has_signal(cls_name, signal_name):
			return cls_name

	# 如果找不到，返回节点的类
	return node.get_class()

## 按 class 分组信号
##
## @param signals: 信号信息数组（可为空）
## @return: 分组字典 { "ClassName": [signal_infos] }，空数组返回空字典
static func group_signals_by_class(signals: Array) -> Dictionary:
	if signals.is_empty():
		return {}

	var grouped = {}

	for signal_info in signals:
		var source_class = signal_info.get("source_class", "Object")

		if not grouped.has(source_class):
			grouped[source_class] = []

		grouped[source_class].append(signal_info)

	return grouped

## 格式化信号显示文本
##
## @param signal_info: 信号信息字典
## @return: 格式化的显示字符串
static func format_signal_text(signal_info: Dictionary) -> String:
	var signal_name = signal_info.get("name", "")
	var params = signal_info.get("args", [])

	if params.is_empty():
		return signal_name

	var param_strings = []
	for param_info in params:
		var param_name = param_info.get("name", "")
		var param_type = param_info.get("type", TYPE_NIL)
		param_strings.append("%s: %s" % [param_name, _type_to_string(param_type)])

	return "%s(%s)" % [signal_name, ", ".join(param_strings)]

## 类型转换为可读字符串
static func _type_to_string(type: int) -> String:
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
		TYPE_CALLABLE: return "Callable"
		TYPE_PACKED_BYTE_ARRAY: return "PackedByteArray"
		TYPE_PACKED_INT32_ARRAY: return "PackedInt32Array"
		TYPE_PACKED_FLOAT32_ARRAY: return "PackedFloat32Array"
		TYPE_PACKED_STRING_ARRAY: return "PackedStringArray"
		_: return "Variant"

## 应用搜索过滤
##
## @param grouped: 分组的信号字典
## @param search_text: 搜索文本
## @return: 过滤后的分组字典
static func apply_search_filter(grouped: Dictionary, search_text: String) -> Dictionary:
	if search_text.is_empty():
		return grouped

	var filtered = {}
	var search_lower = search_text.to_lower()

	for source_class in grouped:
		var filtered_signals = []
		for signal_info in grouped[source_class]:
			var signal_name = signal_info.name.to_lower()
			if search_lower in signal_name:
				filtered_signals.append(signal_info)

		if not filtered_signals.is_empty():
			filtered[source_class] = filtered_signals

	return filtered
