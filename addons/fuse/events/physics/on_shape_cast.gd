@tool
@icon("res://addons/fuse/icons/builtin/ShapeCast2D.png")
extends BaseEvent
class_name OnShapeCast

## Event: OnShapeCast
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _is_monitoring: bool - 是否正在监听
## - _last_collider_count: int - 上次碰撞体数量
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

## 形状投射检测碰撞时触发
##
## 使用 ShapeCast2D 节点定期检测形状碰撞，当命中物体时触发事件。

## 形状原点节点路径（空 = 使用 owner_node）
@export var origin_node_path: NodePath = NodePath(""):
	set(value):
		origin_node_path = value
		_update_resource_name()

## 形状类型
enum ShapeType {
	RECTANGLE,
	CIRCLE,
	CAPSULE
}

@export var shape_type: ShapeType = ShapeType.RECTANGLE:
	set(value):
		shape_type = value
		_update_resource_name()

## 形状大小（用于矩形和胶囊）
@export var shape_size: Vector2 = Vector2(20, 20):
	set(value):
		shape_size = value
		_update_resource_name()

## 形状半径（用于圆形和胶囊）
@export var shape_radius: float = 10.0:
	set(value):
		shape_radius = value
		_update_resource_name()

## 投射目标位置（相对原点）
@export var target_position: Vector2 = Vector2(50, 0):
	set(value):
		target_position = value
		_update_resource_name()

## 碰撞掩码
@export_flags_2d_physics var collision_mask: int = 1:
	set(value):
		collision_mask = value
		_update_resource_name()

## 是否传递碰撞点
@export var emit_collision_point: bool = false

## 是否传递碰撞法线
@export var emit_collision_normal: bool = false

var _origin_node: Node2D = null
var _owner_node_ref: Node = null
var _shape_cast: ShapeCast2D = null
var _process_timer: Timer = null

# RuntimeInstance 引用已在 BaseEvent 中定义
# 运行时状态（is_monitoring, last_collider_count）现在存储在 RuntimeEventInstance 中

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["is_monitoring"] = false
	base["last_collider_count"] = 0
	return base

## 更新资源名称（必需）
func _update_resource_name() -> void:
	var origin_text = str(origin_node_path) if not origin_node_path.is_empty() else FuseLocalization.translate("FUSE_EVENT_ON_SHAPE_CAST_ORIGIN_SELF")

	var shape_key = ""
	match shape_type:
		ShapeType.RECTANGLE:
			shape_key = "FUSE_EVENT_ON_SHAPE_CAST_TYPE_RECT"
		ShapeType.CIRCLE:
			shape_key = "FUSE_EVENT_ON_SHAPE_CAST_TYPE_CIRCLE"
		ShapeType.CAPSULE:
			shape_key = "FUSE_EVENT_ON_SHAPE_CAST_TYPE_CAPSULE"

	var shape_text = FuseLocalization.translate(shape_key)

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_SHAPE_CAST_RESOURCE_NAME", {
		"origin": origin_text,
		"shape": shape_text,
		"target": str(target_position)
	})

## 使用 RuntimeInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

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
		_create_fuse_error_localized("FUSE_ERROR_SHAPE_TARGET_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 创建 ShapeCast2D
	_shape_cast = ShapeCast2D.new()
	_shape_cast.target_position = target_position
	_shape_cast.collision_mask = collision_mask
	_shape_cast.enabled = true

	# 设置形状
	_set_shape()

	_origin_node.add_child(_shape_cast)

	# 创建检测定时器（约 60 FPS）
	_process_timer = Timer.new()
	_process_timer.wait_time = 0.016
	_process_timer.timeout.connect(_on_process_timeout)
	_process_timer.autostart = false
	owner_node.add_child(_process_timer)
	_process_timer.start()

	# 设置 RuntimeEventInstance 状态
	_runtime_instance_ref.set_runtime_state("is_monitoring", true)
	_runtime_instance_ref.set_runtime_state("last_collider_count", 0)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 初始化事件监听（必需）- 向后兼容
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
		_create_fuse_error_localized("FUSE_ERROR_SHAPE_TARGET_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 创建 ShapeCast2D
	_shape_cast = ShapeCast2D.new()
	_shape_cast.target_position = target_position
	_shape_cast.collision_mask = collision_mask
	_shape_cast.enabled = true

	# 设置形状
	_set_shape()

	_origin_node.add_child(_shape_cast)

	# 创建检测定时器（约 60 FPS）
	_process_timer = Timer.new()
	_process_timer.wait_time = 0.016
	_process_timer.timeout.connect(_on_process_timeout)
	_process_timer.autostart = false
	owner_node.add_child(_process_timer)
	_process_timer.start()

	# 设置初始状态（通过 RuntimeInstance）
	get_runtime_instance().set_runtime_state("is_monitoring", true)
	get_runtime_instance().set_runtime_state("last_collider_count", 0)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 设置形状
func _set_shape() -> void:
	var shape = null

	match shape_type:
		ShapeType.RECTANGLE:
			shape = RectangleShape2D.new()
			shape.size = shape_size
		ShapeType.CIRCLE:
			shape = CircleShape2D.new()
			shape.radius = shape_radius
		ShapeType.CAPSULE:
			shape = CapsuleShape2D.new()
			shape.radius = shape_radius
			shape.height = shape_size.y

	if shape:
		_shape_cast.shape = shape

## 定时检测形状碰撞
func _on_process_timeout() -> void:
	if not _shape_cast or not is_instance_valid(_shape_cast):
		return

	var is_monitoring: bool = false
	if get_runtime_instance().has_runtime_state("is_monitoring"):
		is_monitoring = get_runtime_instance().get_runtime_state("is_monitoring")

	if not is_monitoring:
		return

	if _shape_cast.is_colliding():
		var collider_count = _shape_cast.get_collision_count()
		var last_collider_count: int = 0
		if get_runtime_instance().has_runtime_state("last_collider_count"):
			last_collider_count = get_runtime_instance().get_runtime_state("last_collider_count")

		# 检查是否是新的碰撞
		if collider_count != last_collider_count:
			for i in range(collider_count):
				var collider = _shape_cast.get_collider(i)
				_trigger_event(collider, i)

			get_runtime_instance().set_runtime_state("last_collider_count", collider_count)
	else:
		# 没有碰撞时重置
		get_runtime_instance().set_runtime_state("last_collider_count", 0)

## 触发事件
func _trigger_event(collider: Object, index: int) -> void:
	_log_info_localized("FUSE_LOG_EVENT_SHAPE_CAST_TRIGGERED", {
		"collider": collider.name if collider else "null"
	})

	# 创建上下文节点传递参数
	var context_node = Node.new()
	context_node.name = "ShapeCastContext"

	context_node.set_meta("collider", collider)
	context_node.set_meta("collision_index", index)

	if emit_collision_point:
		context_node.set_meta("collision_point", _shape_cast.get_collision_point(index))

	if emit_collision_normal:
		context_node.set_meta("collision_normal", _shape_cast.get_collision_normal(index))

	context_node.set_meta("shape_cast", _shape_cast)

	triggered.emit(context_node)

	# 清理上下文节点
	context_node.queue_free()

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)
		_runtime_instance_ref.set_runtime_state("last_collider_count", 0)
		_runtime_instance_ref = null

	if _process_timer:
		_process_timer.stop()
		if _process_timer.timeout.is_connected(_on_process_timeout):
			_process_timer.timeout.disconnect(_on_process_timeout)
		if owner_node and is_instance_valid(owner_node):
			owner_node.remove_child(_process_timer)
		_process_timer.queue_free()
		_process_timer = null

	if _shape_cast and is_instance_valid(_shape_cast):
		_shape_cast.queue_free()
		_shape_cast = null

	_origin_node = null
	_owner_node_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 获取事件描述
func get_description() -> String:
	var origin_text = str(origin_node_path) if not origin_node_path.is_empty() else FuseLocalization.translate("FUSE_EVENT_ON_SHAPE_CAST_ORIGIN_SELF")

	return FuseLocalization.translate_format("FUSE_EVENT_ON_SHAPE_CAST_DESC", {
		"origin": origin_text,
		"target": str(target_position)
	})

## 获取事件类型
func get_event_type() -> String:
	return "shape_cast"

## 获取事件分类
func get_event_category() -> String:
	return "physics"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if target_position == Vector2.ZERO:
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_POSITION_INVALID"))

	if shape_size.x < 0 or shape_size.y < 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_SHAPE_SIZE_INVALID"))

	if shape_radius < 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_SHAPE_RADIUS_INVALID"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()

	# 重置 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("last_collider_count", 0)
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)

	if _owner_node_ref and is_instance_valid(_owner_node_ref):
		initialize(_owner_node_ref)

	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_SHAPE_CAST_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_PHYSICS"
	metadata.description_key = "FUSE_EVENT_ON_SHAPE_CAST_DESC"
	metadata.keywords = ["shapecast", "形状投射", "collision", "碰撞", "shape", "形状", "cast", "投射", "detection", "检测"]
	metadata.builtin_icon = "ShapeCast2D"
	return metadata
