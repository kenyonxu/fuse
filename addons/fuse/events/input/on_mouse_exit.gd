@tool
@icon("res://addons/fuse/icons/builtin/InputEventMouseMotion.png")
extends BaseEvent
class_name OnMouseExit

## 鼠标离开节点事件
##
## 监听鼠标离开 Control 或 CollisionObject2D/3D 节点。

## 目标节点路径
@export var target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_path = value
		_update_resource_name()

## 每次离开只触发一次
@export var trigger_once_per_exit: bool = true:
	set(value):
		trigger_once_per_exit = value
		_update_resource_name()

# 🔧 运行时状态现在存储在 RuntimeEventInstance 中


# 🔧 信号连接注册表：为每个 Trigger 存储独立的连接信息
# key: owner_node.get_instance_id()
# value: { "target": Node, "callback": Callable, "owner": Node }
var _signal_connections: Dictionary = {}

## 更新资源名称（必需）
func _update_resource_name():
	var node_name = _get_node_display_name(target_node_path) if not target_node_path.is_empty() else FuseLocalization.translate("FUSE_EVENT_MOUSE_EXIT_CURRENT_NODE")
	var once_key = "FUSE_EVENT_MOUSE_EXIT_ONCE" if trigger_once_per_exit else "FUSE_EVENT_MOUSE_EXIT_REPEAT"
	var once_text = " [%s]" % FuseLocalization.translate(once_key)

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_MOUSE_EXIT_RESOURCE_NAME", {
		"target": node_name,
		"timing": once_text
	})

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证目标节点路径
	if target_node_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 🔧 动态解析目标节点（使用传入的 owner_node 参数）
	var target_node = owner_node.get_node_or_null(target_node_path)
	if not target_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
		return

	# 验证节点类型
	if not _is_valid_target_type(target_node):
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {
			"node_path": str(target_node_path),
			"expected_types": "Control, CollisionObject2D, 或 CollisionObject3D"
		})
		return

	# 根据节点类型连接相应的信号
	_connect_hover_signals(target_node, owner_node)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 🔧 使用 RuntimeEventInstance 初始化事件
##
## 这是推荐的方法，通过 RuntimeEventInstance 管理运行时状态
##
## 参数：
## - owner_node: Node - 拥有此事件的 Trigger 节点
## - runtime_instance: RuntimeEventInstance - 运行时事件实例
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		_log_debug("编辑器模式下，跳过事件初始化")
		return

	# 保存 RuntimeEventInstance 引用
	_runtime_instance_ref = runtime_instance

	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证目标节点路径
	if target_node_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 🔧 动态解析目标节点
	var target_node = owner_node.get_node_or_null(target_node_path)
	if not target_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
		return

	# 验证节点类型
	if not _is_valid_target_type(target_node):
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {
			"node_path": str(target_node_path),
			"expected_types": "Control, CollisionObject2D, 或 CollisionObject3D"
		})
		return

	# 根据节点类型连接相应的信号
	_connect_hover_signals(target_node, owner_node)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 🔧 根据 owner_node 找到并断开对应的信号连接
	var owner_id = owner_node.get_instance_id()

	if _signal_connections.has(owner_id):
		var conn_info = _signal_connections[owner_id]
		var target_node = conn_info["target"]
		var callback = conn_info["callback"]

		if target_node and is_instance_valid(target_node):
			# 断开信号（注意：OnMouseExit 使用 mouse_exited 信号）
			if target_node is Control:
				var control = target_node as Control
				if control.mouse_exited.is_connected(callback):
					control.mouse_exited.disconnect(callback)
			elif target_node is CollisionObject2D:
				if target_node.mouse_exited.is_connected(callback):
					target_node.mouse_exited.disconnect(callback)
			elif target_node is CollisionObject3D:
				var collision = target_node as CollisionObject3D
				if collision.mouse_exited.is_connected(callback):
					collision.mouse_exited.disconnect(callback)

		# 清理注册表
		_signal_connections.erase(owner_id)

	# 🔧 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_exited", false)

	# 清理引用
	_runtime_instance_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 连接悬停信号
func _connect_hover_signals(target_node: Node, owner_node: Node):
	if not target_node or not is_instance_valid(target_node):
		return

	# 🔧 为每个 Trigger 创建独立的回调包装器
	var wrapped_callback = _create_mouse_exit_callback(owner_node)

	# 保存连接信息
	var owner_id = owner_node.get_instance_id()
	_signal_connections[owner_id] = {
		"target": target_node,
		"callback": wrapped_callback,
		"owner": owner_node
	}

	# 检查是否是 Control 节点
	if target_node is Control:
		var control = target_node as Control
		control.mouse_exited.connect(wrapped_callback)

	# 检查是否是 CollisionObject2D
	elif target_node is CollisionObject2D:
		var collision = target_node as CollisionObject2D
		target_node.mouse_exited.connect(wrapped_callback)

	# 检查是否是 CollisionObject3D
	elif target_node is CollisionObject3D:
		var collision = target_node as CollisionObject3D
		collision.mouse_exited.connect(wrapped_callback)

## 断开悬停信号
func _disconnect_hover_signals(target_node: Node):
	if not target_node or not is_instance_valid(target_node):
		return

	# 断开所有连接到这个 target 的信号
	var keys_to_remove = []
	for owner_id in _signal_connections.keys():
		var conn_info = _signal_connections[owner_id]
		if conn_info["target"] == target_node and is_instance_valid(target_node):
			var callback = conn_info["callback"]
			if target_node is Control:
				var control = target_node as Control
				if control.mouse_exited.is_connected(callback):
					control.mouse_exited.disconnect(callback)
			elif target_node is CollisionObject2D:
				if target_node.mouse_exited.is_connected(callback):
					target_node.mouse_exited.disconnect(callback)
			elif target_node is CollisionObject3D:
				var collision = target_node as CollisionObject3D
				if collision.mouse_exited.is_connected(callback):
					collision.mouse_exited.disconnect(callback)
			keys_to_remove.append(owner_id)

	# 清理注册表
	for key in keys_to_remove:
		_signal_connections.erase(key)

## 创建带上下文的鼠标离开回调
##
## 🔧 为每个 Trigger 创建独立的回调函数，捕获正确的 owner 引用
func _create_mouse_exit_callback(owner: Node) -> Callable:
	return _on_mouse_exited_with_context.bind(owner)

## 鼠标离开回调（带上下文）
##
## 🔧 这个方法接收正确的 owner 参数，使用 RuntimeEventInstance 管理状态
func _on_mouse_exited_with_context(owner: Node):
	# 验证 owner 是否有效
	if not owner or not is_instance_valid(owner):
		return

	# 使用传入的 owner 参数获取目标节点
	var target_node = owner.get_node_or_null(target_node_path)
	if not target_node:
		_log_error("无法获取目标节点")
		return

	# 🔧 使用 RuntimeEventInstance 的状态（如果可用）
	var has_exited: bool = false
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("has_exited"):
		has_exited = _runtime_instance_ref.get_runtime_state("has_exited")
	else:
		# 回退：使用默认值（_has_exited 已被删除）
		has_exited = false

	# 检查是否只触发一次
	if trigger_once_per_exit and has_exited:
		_log_debug_localized("FUSE_LOG_EVENT_ALREADY_EXITED", {})
		return

	# 🔧 更新 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_exited", true)
		# 更新触发统计
		_runtime_instance_ref.update_trigger_stats()

	var node_name = target_node.name if target_node else "Unknown"
	_log_info_localized("FUSE_LOG_EVENT_MOUSE_EXIT_TRIGGERED", {"node": node_name})

	# 创建上下文节点传递事件信息
	var context_node = Node.new()
	context_node.name = "MouseExitContext"
	context_node.set_meta("trigger", owner)  # 🔧 使用传入的正确 owner
	context_node.set_meta("target_node", target_node)
	context_node.set_meta("node_path", str(target_node_path))

	triggered.emit(context_node)
	context_node.queue_free()

## 检查是否是有效的目标类型
func _is_valid_target_type(node: Node) -> bool:
	return node is Control or node is CollisionObject2D or node is CollisionObject3D

## 获取事件描述
func get_description() -> String:
	var timing_key = "FUSE_EVENT_ON_MOUSE_EXIT_TIMING_ONCE" if trigger_once_per_exit else "FUSE_EVENT_ON_MOUSE_EXIT_TIMING_REPEAT"
	var timing_text = FuseLocalization.translate(timing_key)
	var node_name = _get_node_display_name(target_node_path) if not target_node_path.is_empty() else FuseLocalization.translate("FUSE_EVENT_MOUSE_EXIT_CURRENT_NODE")

	return FuseLocalization.translate_format("FUSE_EVENT_ON_MOUSE_EXIT_DESC", {
		"target": node_name,
		"timing": timing_text
	})

## 获取事件类型
func get_event_type() -> String:
	return "mouse_exit"

## 获取事件分类
func get_event_category() -> String:
	return "input"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	# 验证目标节点路径
	if target_node_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	# 🔧 重置 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_exited", false)
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["has_exited"] = false
	return base

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_MOUSE_EXIT_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_INPUT"
	metadata.description_key = "FUSE_EVENT_ON_MOUSE_EXIT_DESC"
	metadata.keywords = ["mouse", "鼠标", "exit", "离开", "hover", "悬停", "input", "输入", "control", "控制节点"]
	metadata.builtin_icon = "InputEventMouseMotion"
	return metadata
