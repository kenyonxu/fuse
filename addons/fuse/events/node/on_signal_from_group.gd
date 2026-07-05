@tool
@icon("res://addons/fuse/icons/builtin/Node.png")
extends BaseEvent
class_name OnSignalFromGroup

## 监听指定组中任意节点的信号
##
## 当指定组中任意节点发射指定信号时触发事件。

## 信号名称
@export var signal_name: String = "":
	set(value):
		signal_name = value
		_update_resource_name()

## 节点组名
@export var group_name: String = "":
	set(value):
		group_name = value
		_update_resource_name()

## 是否传递节点引用
@export var emit_node: bool = true

## 是否传递信号名称
@export var emit_signal_name: bool = true

## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _connected_nodes: Array - 已连接信号的节点列表
## - _is_monitoring: bool - 是否正在监听
##
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

## 缓存 owner_node 引用，用于访问节点
var _owner_node_ref: Node = null

## 更新资源名称（必需）
func _update_resource_name() -> void:
	var group_text = group_name if not group_name.is_empty() else FuseLocalization.translate("FUSE_EVENT_ON_SIGNAL_FROM_GROUP_NO_GROUP")
	var signal_text = signal_name if not signal_name.is_empty() else FuseLocalization.translate("FUSE_EVENT_ON_SIGNAL_FROM_GROUP_NO_SIGNAL")

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_SIGNAL_FROM_GROUP_RESOURCE_NAME", {
		"group": group_text,
		"signal": signal_text
	})

## 初始化事件监听（必需）- 向后兼容
func initialize(owner_node: Node) -> void:
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_owner_node_ref = owner_node

	if signal_name.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_SIGNAL_NAME_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	if group_name.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_GROUP_NAME_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 连接组内所有节点的信号
	_connect_group_signals(owner_node)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 使用 RuntimeEventInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		_log_debug("编辑器模式下，跳过事件初始化")
		return

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 保存运行时实例引用
	_runtime_instance_ref = runtime_instance

	_owner_node_ref = owner_node

	if signal_name.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_SIGNAL_NAME_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	if group_name.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_GROUP_NAME_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 连接组内所有节点的信号
	_connect_group_signals(owner_node)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 连接组内节点的信号
func _connect_group_signals(owner_node: Node) -> void:
	if not owner_node or not owner_node.is_inside_tree():
		return

	# 使用 RuntimeEventInstance 的状态
	var connected_nodes: Array[Node] = []
	if _runtime_instance_ref:
		connected_nodes = _runtime_instance_ref.get_runtime_state("connected_nodes")

	var nodes = owner_node.get_tree().get_nodes_in_group(group_name)

	for node in nodes:
		if not is_instance_valid(node):
			continue

		if not node.has_signal(signal_name):
			continue

		# 动态连接信号
		if not node.is_connected(signal_name, _on_signal_emitted.bind(owner_node, node)):
			node.connect(signal_name, _on_signal_emitted.bind(owner_node, node))
			if not node in connected_nodes:
				connected_nodes.append(node)

	# 更新 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("connected_nodes", connected_nodes)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {
		"event_type": get_event_type(),
		"connected_count": connected_nodes.size()
	})

## 信号发射回调
func _on_signal_emitted(owner_node: Node, emitting_node: Node) -> void:
	# 使用 RuntimeEventInstance 的状态
	var is_monitoring = true
	if _runtime_instance_ref:
		is_monitoring = _runtime_instance_ref.get_runtime_state("is_monitoring")

	if not is_monitoring:
		return

	if not emitting_node or not is_instance_valid(emitting_node):
		return

	var node_name = emitting_node.name if emitting_node.name else "Unknown"
	_log_info_localized("FUSE_LOG_EVENT_SIGNAL_FROM_GROUP_TRIGGERED", {
		"node": node_name,
		"signal": signal_name
	})

	# 创建上下文节点传递参数
	var context_node = Node.new()
	context_node.name = "SignalFromGroupContext"

	if emit_node:
		context_node.set_meta("node", emitting_node)

	if emit_signal_name:
		context_node.set_meta("signal_name", signal_name)

	context_node.set_meta("group_name", group_name)
	context_node.set_meta("trigger", owner_node)

	if _runtime_instance_ref:
		_runtime_instance_ref.update_trigger_stats()

	triggered.emit(context_node)

	# 清理上下文节点
	context_node.queue_free()

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 使用 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)

		var connected_nodes: Array[Node] = []
		if _runtime_instance_ref:
			connected_nodes = _runtime_instance_ref.get_runtime_state("connected_nodes")

		# 断开所有已连接的信号
		for node in connected_nodes:
			if is_instance_valid(node) and node.is_connected(signal_name, _on_signal_emitted):
				node.disconnect(signal_name, _on_signal_emitted)

		# 清理状态
		_runtime_instance_ref.set_runtime_state("connected_nodes", [])

	_owner_node_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 获取事件描述
func get_description() -> String:
	return FuseLocalization.translate_format("FUSE_EVENT_ON_SIGNAL_FROM_GROUP_DESC", {
		"group": group_name,
		"signal": signal_name
	})

## 获取事件类型
func get_event_type() -> String:
	return "signal_from_group"

## 获取事件分类
func get_event_category() -> String:
	return "node"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if signal_name.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_SIGNAL_NAME_INVALID"))

	if group_name.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_GROUP_NAME_INVALID"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()

	# 重置 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("connected_nodes", [])
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)

	# 清理节点引用
	_owner_node_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["connected_nodes"] = []
	base["is_monitoring"] = false
	return base

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_SIGNAL_FROM_GROUP_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_NODE"
	metadata.description_key = "FUSE_EVENT_ON_SIGNAL_FROM_GROUP_DESC"
	metadata.keywords = ["signal", "信号", "group", "组", "monitor", "监听", "multiple", "多个", "nodes", "节点"]
	metadata.builtin_icon = "Node"
	return metadata
