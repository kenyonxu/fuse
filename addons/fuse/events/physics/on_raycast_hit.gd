@tool
@icon("res://addons/fuse/icons/builtin/RayCast2D.png")
extends BaseEvent
class_name OnRaycastHit

## Event: OnRaycastHit
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _is_monitoring: bool - 是否正在监控
## - _last_collider: Object - 最后检测到的碰撞体
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/zh_CN/dev_docs/guides/runtime-instance-migration-guide.md

## 射线检测到碰撞体时触发
##
## 使用 RayCast2D 节点定期检测射线碰撞，当命中物体时触发事件。

## 射线原点节点路径（空 = 使用 owner_node）
@export var origin_node_path: NodePath = NodePath(""):
	set(value):
		origin_node_path = value
		_update_resource_name()

## 射线目标位置（相对原点）
@export var target_position: Vector2 = Vector2(100, 0):
	set(value):
		target_position = value
		_update_resource_name()

## 碰撞掩码
@export_flags_2d_physics var collision_mask: int = 1:
	set(value):
		collision_mask = value
		_update_resource_name()

## 是否传递碰撞点
@export var emit_collision_point: bool = true

## 是否传递碰撞法线
@export var emit_collision_normal: bool = false

## 是否传递射线原点
@export var emit_raycast_origin: bool = false

var _origin_node: Node2D = null
var _owner_node_ref: Node = null
var _raycast: RayCast2D = null
var _process_timer: Timer = null

# RuntimeInstance 引用已在 BaseEvent 中定义

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["is_monitoring"] = false
	base["last_collider"] = null
	return base

## 更新资源名称（必需）
func _update_resource_name() -> void:
	var origin_text = str(origin_node_path) if not origin_node_path.is_empty() else FuseLocalization.translate("FUSE_EVENT_ON_RAYCAST_HIT_ORIGIN_SELF")

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_RAYCAST_HIT_RESOURCE_NAME", {
		"origin": origin_text,
		"target": str(target_position)
	})

## 使用 RuntimeInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	# 保存 RuntimeEventInstance 引用
	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_owner_node_ref = owner_node

	# 获取原点节点
	if not origin_node_path.is_empty():
		_origin_node = owner_node.get_node_or_null(origin_node_path) as Node2D
	else:
		_origin_node = owner_node as Node2D

	if not _origin_node:
		_create_fuse_error_localized("FUSE_ERROR_RAYCAST_TARGET_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 创建 RayCast2D
	_raycast = RayCast2D.new()
	_raycast.target_position = target_position
	_raycast.collision_mask = collision_mask
	_raycast.enabled = true
	_origin_node.add_child(_raycast)

	# 创建检测定时器（约 60 FPS）
	_process_timer = Timer.new()
	_process_timer.wait_time = 0.016
	_process_timer.timeout.connect(_on_process_timeout)
	_process_timer.autostart = false
	owner_node.add_child(_process_timer)
	_process_timer.start()

	# 设置初始状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", true)
		_runtime_instance_ref.set_runtime_state("last_collider", null)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_owner_node_ref = owner_node

	# 获取原点节点
	if not origin_node_path.is_empty():
		_origin_node = owner_node.get_node_or_null(origin_node_path) as Node2D
	else:
		_origin_node = owner_node as Node2D

	if not _origin_node:
		_create_fuse_error_localized("FUSE_ERROR_RAYCAST_TARGET_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 创建 RayCast2D
	_raycast = RayCast2D.new()
	_raycast.target_position = target_position
	_raycast.collision_mask = collision_mask
	_raycast.enabled = true
	_origin_node.add_child(_raycast)

	# 创建检测定时器（约 60 FPS）
	_process_timer = Timer.new()
	_process_timer.wait_time = 0.016
	_process_timer.timeout.connect(_on_process_timeout)
	_process_timer.autostart = false
	owner_node.add_child(_process_timer)
	_process_timer.start()

	# 设置初始状态（通过 RuntimeInstance）
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", true)
		_runtime_instance_ref.set_runtime_state("last_collider", null)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 定时检测射线
func _on_process_timeout() -> void:
	if not _raycast or not is_instance_valid(_raycast):
		return

	var is_monitoring: bool = false
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("is_monitoring"):
		is_monitoring = _runtime_instance_ref.get_runtime_state("is_monitoring")

	if not is_monitoring:
		return

	if _raycast.is_colliding():
		var collider = _raycast.get_collider()
		var last_collider = null

		if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("last_collider"):
			last_collider = _runtime_instance_ref.get_runtime_state("last_collider")

		# 检查是否是新的碰撞体（避免重复触发）
		if collider != last_collider:
			_trigger_event(collider)
			if _runtime_instance_ref:
				_runtime_instance_ref.set_runtime_state("last_collider", collider)
	else:
		# 没有碰撞时重置
		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("last_collider", null)

## 触发事件
func _trigger_event(collider: Object) -> void:
	_log_info_localized("FUSE_LOG_EVENT_RAYCAST_HIT", {
		"collider": collider.name if collider else "null"
	})

	# 创建上下文节点传递参数
	var context_node = Node.new()
	context_node.name = "RaycastHitContext"

	context_node.set_meta("collider", collider)

	if emit_collision_point:
		context_node.set_meta("collision_point", _raycast.get_collision_point())

	if emit_collision_normal:
		context_node.set_meta("collision_normal", _raycast.get_collision_normal())

	if emit_raycast_origin:
		context_node.set_meta("raycast_origin", _origin_node.global_position)

	context_node.set_meta("raycast", _raycast)

	triggered.emit(context_node)

	# 清理上下文节点
	context_node.queue_free()

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)
		_runtime_instance_ref.set_runtime_state("last_collider", null)
		_runtime_instance_ref = null

	if _process_timer:
		_process_timer.stop()
		if _process_timer.timeout.is_connected(_on_process_timeout):
			_process_timer.timeout.disconnect(_on_process_timeout)
		if owner_node and is_instance_valid(owner_node):
			owner_node.remove_child(_process_timer)
		_process_timer.queue_free()
		_process_timer = null

	if _raycast and is_instance_valid(_raycast):
		_raycast.queue_free()
		_raycast = null

	_origin_node = null
	_owner_node_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 获取事件描述
func get_description() -> String:
	var origin_text = str(origin_node_path) if not origin_node_path.is_empty() else FuseLocalization.translate("FUSE_EVENT_ON_RAYCAST_HIT_ORIGIN_SELF")

	return FuseLocalization.translate_format("FUSE_EVENT_ON_RAYCAST_HIT_DESC", {
		"origin": origin_text,
		"target": str(target_position)
	})

## 获取事件类型
func get_event_type() -> String:
	return "raycast_hit"

## 获取事件分类
func get_event_category() -> String:
	return "physics"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if target_position == Vector2.ZERO:
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_POSITION_INVALID"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()

	# 重置 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("last_collider", null)
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)

		if _owner_node_ref and is_instance_valid(_owner_node_ref):
			initialize(_owner_node_ref)

	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_RAYCAST_HIT_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_PHYSICS"
	metadata.description_key = "FUSE_EVENT_ON_RAYCAST_HIT_DESC"
	metadata.keywords = ["raycast", "射线", "hit", "命中", "detection", "检测", "line", "线", "collision", "碰撞"]
	metadata.builtin_icon = "RayCast2D"
	return metadata
