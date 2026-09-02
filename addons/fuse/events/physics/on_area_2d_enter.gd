@icon("res://addons/fuse/icons/builtin/CollisionShape2D.png")
# 文件：addons/fuse/events/on_area_2d_enter.gd
@tool
class_name OnArea2DEnter extends BaseEvent

## 设计师必须指定 Area2D 节点的路径
## (相对于 Trigger 节点)
@export var area_node_path: NodePath:
	set(value):
		area_node_path = value
		_update_resource_name()

## 目标组名，为空时匹配任何物体
@export var target_group: String = ""

## 是否只触发一次（每个物体）
@export var trigger_once_per_body: bool = false

## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _triggered_bodies: Array - 已触发的物体列表
##
## 相关文档: addons/fuse/docs/zh_CN/dev_docs/guides/runtime-instance-migration-guide.md

# 🔧 Area 节点引用
var _area_node: Area2D

## 🔧 信号连接注册表：为每个 Trigger 存储独立的连接信息
## key: owner_node.get_instance_id()
## value: {
##   "area_node": Area2D,           # 🔧 每个 owner 的 Area2D 节点引用
##   "body_entered": Callable,
##   "body_exited": Callable,
##   "area_entered": Callable,
##   "area_exited": Callable
## }
var _signal_connections: Dictionary = {}

# 根据属性设置更新在列表中的名称
func _update_resource_name():
	var area_path = area_node_path if not area_node_path.is_empty() else FuseLocalization.translate("FUSE_EVENT_AREA_2D_NOT_SPECIFIED")
	var body_name = FuseLocalization.translate("FUSE_EVENT_AREA_2D_ANY") if target_group.is_empty() else target_group

	if trigger_once_per_body:
		var timing_key = "FUSE_EVENT_AREA_2D_ONCE"
		resource_name = FuseLocalization.translate_format("FUSE_EVENT_AREA_2D_RESOURCE_NAME_FIRST", {"body": body_name, "area": area_path, "timing": FuseLocalization.translate(timing_key)})
	else:
		var timing_key = "FUSE_EVENT_AREA_2D_EVERY"
		resource_name = FuseLocalization.translate_format("FUSE_EVENT_AREA_2D_RESOURCE_NAME_EVERY", {"body": body_name, "area": area_path, "timing": FuseLocalization.translate(timing_key)})

## 初始化事件监听（必需）- 向后兼容
func initialize(owner_node: Node) -> void:
	var area_node = owner_node.get_node_or_null(area_node_path)

	if not area_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(area_node_path)})
		_log_error("[OnArea2DEnter] 找不到目标节点: %s" % str(area_node_path))
		return

	if not area_node is Area2D:
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(area_node_path)})
		_log_error("[OnArea2DEnter] 目标节点不是 Area2D: %s (类型: %s)" % [area_node.name, area_node.get_class()])
		return

	# 创建并存储 Callable 对象
	var owner_id = owner_node.get_instance_id()

	# 使用 lambda 函数来正确捕获 owner_node 并确保参数顺序
	var body_entered_callable = func(body): _on_body_entered_impl(owner_node, body)
	var body_exited_callable = func(body): _on_body_exited_impl(owner_node, body)
	var area_entered_callable = func(area): _on_area_entered_impl(owner_node, area)
	var area_exited_callable = func(area): _on_area_exited_impl(owner_node, area)

	# 🔧 关键修复：将 area_node 也存储到连接信息中
	_signal_connections[owner_id] = {
		"area_node": area_node,  # 🔧 存储每个 owner 的 Area2D 节点引用
		"body_entered": body_entered_callable,
		"body_exited": body_exited_callable,
		"area_entered": area_entered_callable,
		"area_exited": area_exited_callable
	}

	# 连接信号
	# 连接 PhysicsBody2D 信号
	if not area_node.body_entered.is_connected(body_entered_callable):
		area_node.body_entered.connect(body_entered_callable)

	if not area_node.body_exited.is_connected(body_exited_callable):
		area_node.body_exited.connect(body_exited_callable)

	# 连接 Area2D 信号（用于检测 Area2D 类型的敌人）
	if not area_node.area_entered.is_connected(area_entered_callable):
		area_node.area_entered.connect(area_entered_callable)

	if not area_node.area_exited.is_connected(area_exited_callable):
		area_node.area_exited.connect(area_exited_callable)

## 🔧 使用 RuntimeEventInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	# 保存 RuntimeInstance 引用
	if runtime_instance:
		_runtime_instance_ref = runtime_instance

	var area_node = owner_node.get_node_or_null(area_node_path)

	if not area_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(area_node_path)})
		_log_error("[OnArea2DEnter] 找不到目标节点: %s" % str(area_node_path))
		return

	if not area_node is Area2D:
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(area_node_path)})
		_log_error("[OnArea2DEnter] 目标节点不是 Area2D: %s (类型: %s)" % [area_node.name, area_node.get_class()])
		return

	var owner_id = owner_node.get_instance_id()

	# 🔧 关键修复：先断开所有可能存在的旧信号连接
	# 这解决了 pool_reset() 时 lambda 函数无法正确断开的问题
	_disconnect_all_signals_for_owner(owner_id)

	# 创建并存储 Callable 对象
	# 使用 lambda 函数来正确捕获 owner_node 并确保参数顺序
	var body_entered_callable = func(body): _on_body_entered_impl(owner_node, body)
	var body_exited_callable = func(body): _on_body_exited_impl(owner_node, body)
	var area_entered_callable = func(area): _on_area_entered_impl(owner_node, area)
	var area_exited_callable = func(area): _on_area_exited_impl(owner_node, area)

	# 🔧 关键修复：将 area_node 也存储到连接信息中
	# 这样在断开信号时可以使用正确的 Area2D 节点
	_signal_connections[owner_id] = {
		"area_node": area_node,  # 🔧 存储每个 owner 的 Area2D 节点引用
		"body_entered": body_entered_callable,
		"body_exited": body_exited_callable,
		"area_entered": area_entered_callable,
		"area_exited": area_exited_callable
	}

	# 连接信号（此时已确保没有旧连接）
	area_node.body_entered.connect(body_entered_callable)
	area_node.body_exited.connect(body_exited_callable)
	area_node.area_entered.connect(area_entered_callable)
	area_node.area_exited.connect(area_exited_callable)

## 🔧 断开指定 owner 的所有信号连接
## 使用存储的 area_node 和 callable 来正确断开连接
func _disconnect_all_signals_for_owner(owner_id: int) -> void:
	# 检查是否有该 owner 的记录
	if owner_id not in _signal_connections:
		return

	var connection_info = _signal_connections[owner_id]

	# 🔧 关键修复：使用存储的 area_node，而不是共享的 _area_node
	var area_node = connection_info.get("area_node", null)
	if not area_node or not is_instance_valid(area_node):
		_signal_connections.erase(owner_id)
		return

	var callables = connection_info

	# 使用存储的 callable 来断开连接
	# 注意：lambda 函数的比较是基于引用的，所以只有存储的 callable 才能正确断开
	if area_node.body_entered.is_connected(callables.body_entered):
		area_node.body_entered.disconnect(callables.body_entered)

	if area_node.body_exited.is_connected(callables.body_exited):
		area_node.body_exited.disconnect(callables.body_exited)

	if area_node.area_entered.is_connected(callables.area_entered):
		area_node.area_entered.disconnect(callables.area_entered)

	if area_node.area_exited.is_connected(callables.area_exited):
		area_node.area_exited.disconnect(callables.area_exited)

	# 清理连接注册
	_signal_connections.erase(owner_id)

func terminate(owner_node: Node) -> void:
	var owner_id = owner_node.get_instance_id()

	# 检查是否有该 owner 的记录
	if owner_id not in _signal_connections:
		return

	var connection_info = _signal_connections[owner_id]

	# 🔧 关键修复：使用存储的 area_node，而不是共享的 _area_node
	var area_node = connection_info.get("area_node", null)
	if area_node and is_instance_valid(area_node):
		var callables = connection_info

		if area_node.body_entered.is_connected(callables.body_entered):
			area_node.body_entered.disconnect(callables.body_entered)

		if area_node.body_exited.is_connected(callables.body_exited):
			area_node.body_exited.disconnect(callables.body_exited)

		if area_node.area_entered.is_connected(callables.area_entered):
			area_node.area_entered.disconnect(callables.area_entered)

		if area_node.area_exited.is_connected(callables.area_exited):
			area_node.area_exited.disconnect(callables.area_exited)

		# 清理连接注册
		_signal_connections.erase(owner_id)

	# 🔧 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("triggered_bodies", [])

func _on_body_entered_impl(owner_node: Node, body: Node2D) -> void:
	if not body:
		return

	# 检查目标组
	if not target_group.is_empty() and not body.is_in_group(target_group):
		return

	# 🔧 使用 RuntimeEventInstance 的状态
	var triggered_bodies: Array = []

	if _runtime_instance_ref:
		triggered_bodies = _runtime_instance_ref.runtime_state.get("triggered_bodies", [])

	# 检查是否已经触发过
	if trigger_once_per_body and body in triggered_bodies:
		return

	# 记录已触发的物体
	if trigger_once_per_body:
		triggered_bodies.append(body)

		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("triggered_bodies", triggered_bodies)
			_runtime_instance_ref.update_trigger_stats()

	_log_info("[OnArea2DEnter] 触发事件: body '%s' 进入区域" % body.name)

	var context_node = Node.new()
	context_node.name = "Area2DEnterContext"
	context_node.set_meta("trigger", owner_node)
	context_node.set_meta("body", body)

	triggered.emit(context_node)
	context_node.queue_free()

func _on_body_exited_impl(owner_node: Node, body: Node2D) -> void:
	if not body:
		return

	# 🔧 使用 RuntimeEventInstance 的状态
	var triggered_bodies: Array = []

	if _runtime_instance_ref:
		triggered_bodies = _runtime_instance_ref.runtime_state.get("triggered_bodies", [])

	# 如果物体离开区域，从已触发列表中移除
	if trigger_once_per_body and body in triggered_bodies:
		triggered_bodies.erase(body)

		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("triggered_bodies", triggered_bodies)

## 🔧 Area2D 进入回调（用于检测 Area2D 类型的敌人）
func _on_area_entered_impl(owner_node: Node, area: Area2D) -> void:
	if not area:
		return

	# 检查目标组
	if not target_group.is_empty() and not area.is_in_group(target_group):
		return

	# 🔧 使用 RuntimeEventInstance 的状态
	var triggered_bodies: Array = []

	if _runtime_instance_ref:
		triggered_bodies = _runtime_instance_ref.runtime_state.get("triggered_bodies", [])

	# 检查是否已经触发过
	if trigger_once_per_body and area in triggered_bodies:
		return

	# 记录已触发的物体
	if trigger_once_per_body:
		triggered_bodies.append(area)

		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("triggered_bodies", triggered_bodies)
			_runtime_instance_ref.update_trigger_stats()

	_log_info("[OnArea2DEnter] 触发事件: Area2D '%s' 进入区域" % area.name)

	var context_node = Node.new()
	context_node.name = "Area2DEnterContext"
	context_node.set_meta("trigger", owner_node)
	context_node.set_meta("area", area)  # Area2D 使用 area 元数据

	triggered.emit(context_node)
	context_node.queue_free()

## 🔧 Area2D 离开回调
func _on_area_exited_impl(owner_node: Node, area: Area2D) -> void:
	if not area:
		return

	# 🔧 使用 RuntimeEventInstance 的状态
	var triggered_bodies: Array = []

	if _runtime_instance_ref:
		triggered_bodies = _runtime_instance_ref.runtime_state.get("triggered_bodies", [])

	# 如果物体离开区域，从已触发列表中移除
	if trigger_once_per_body and area in triggered_bodies:
		triggered_bodies.erase(area)

		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("triggered_bodies", triggered_bodies)

func get_description() -> String:
	var area_name = area_node_path if not area_node_path.is_empty() else FuseLocalization.translate("FUSE_EVENT_AREA_2D_NOT_SPECIFIED")
	var body_name = FuseLocalization.translate("FUSE_EVENT_AREA_2D_ANY") if target_group.is_empty() else target_group

	if trigger_once_per_body:
		return FuseLocalization.translate_format("FUSE_EVENT_AREA_2D_RESOURCE_NAME_FIRST", {"body": body_name, "area": area_name})
	else:
		return FuseLocalization.translate_format("FUSE_EVENT_AREA_2D_RESOURCE_NAME_EVERY", {"body": body_name, "area": area_name})

func get_event_type() -> String:
	return "area_2d_enter"

func get_event_category() -> String:
	return "area"

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["triggered_bodies"] = []
	return base

func reset() -> void:
	super.reset()

	# 🔧 重置 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("triggered_bodies", [])

func validate() -> Array[String]:
	var errors: Array[String] = []

	if area_node_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_AREA_2D_NOT_SPECIFIED"))

	# 检查路径是否有效
	# 注意：在 Resource 中无法直接验证节点路径，需要在运行时验证
	if not area_node_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_WARNING_AREA_2D_RUNTIME_VALIDATION"))

	return errors

## 手动触发区域进入事件
func trigger_manually(body: Node2D) -> void:
	_log_debug_localized("FUSE_LOG_EVENT_TRIGGERED", {"event_type": get_event_type()})
	triggered.emit(body)

## 获取当前在区域内的物体列表
func get_bodies_in_area() -> Array[Node2D]:
	if not _area_node:
		return []

	var bodies: Array[Node2D] = []
	var overlapping_bodies = _area_node.get_overlapping_bodies()

	for body in overlapping_bodies:
		if body is Node2D:
			# 检查目标组
			if target_group.is_empty() or body.is_in_group(target_group):
				bodies.append(body)

	return bodies

## 检查指定物体是否在区域内
func is_body_in_area(body: Node2D) -> bool:
	if not _area_node or not body:
		return false

	var overlapping_bodies = _area_node.get_overlapping_bodies()
	return overlapping_bodies.has(body)

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_AREA_2D_ENTER_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_PHYSICS"
	metadata.description_key = "FUSE_EVENT_ON_AREA_2D_ENTER_DESC"
	metadata.keywords = ["area", "区域", "enter", "进入", "collision", "碰撞", "physics", "物理", "2d", "body", "物体"]
	metadata.builtin_icon = "CollisionShape2D"
	return metadata
