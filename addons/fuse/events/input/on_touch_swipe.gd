@tool
@icon("res://addons/fuse/icons/builtin/InputEventScreenDrag.png")
extends BaseEvent
class_name OnTouchSwipe

## Event: OnTouchSwipe
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _is_monitoring: bool - 是否正在监听输入
## - _start_position: Vector2 - 触摸起点位置
## - _start_time: float - 触摸开始时间（秒）
## - _is_touching: bool - 是否正在触摸
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

## 触摸滑动手势事件
##
## 检测触摸滑动手势。通过监听 InputEventScreenTouch 事件，
## 记录触摸起点和终点，计算滑动向量和距离。

## 滑动方向枚举
enum SwipeDirection {
	UP = 0,
	DOWN = 1,
	LEFT = 2,
	RIGHT = 3,
	ANY = 4
}

## 最小滑动距离（像素）
@export var min_distance: float = 50.0:
	set(value):
		min_distance = value
		_update_resource_name()

## 滑动方向
@export var swipe_direction: SwipeDirection = SwipeDirection.ANY:
	set(value):
		swipe_direction = value
		_update_resource_name()

## 时间窗口（秒）
@export var time_window: float = 0.5:
	set(value):
		time_window = value
		_update_resource_name()

## 是否传递滑动速度
@export var emit_velocity: bool = false

# 节点引用（非状态变量）
var _owner_node_ref: Node = null

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["is_monitoring"] = false
	base["start_position"] = Vector2.ZERO
	base["start_time"] = 0.0
	base["is_touching"] = false
	return base

## 更新资源名称（必需）
func _update_resource_name() -> void:
	var direction_key = _get_direction_key()
	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_TOUCH_SWIPE_RESOURCE_NAME", {
		"direction": FuseLocalization.translate(direction_key),
		"distance": str(int(min_distance))
	})

## 使用 RuntimeInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_runtime_instance_ref = runtime_instance
	_owner_node_ref = owner_node

	# 设置初始状态
	_runtime_instance_ref.set_runtime_state("is_monitoring", true)
	_runtime_instance_ref.set_runtime_state("start_position", Vector2.ZERO)
	_runtime_instance_ref.set_runtime_state("start_time", 0.0)
	_runtime_instance_ref.set_runtime_state("is_touching", false)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 初始化事件监听（必需）- 向后兼容
func initialize(owner_node: Node) -> void:
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_owner_node_ref = owner_node

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)
		_runtime_instance_ref.set_runtime_state("is_touching", false)
		_runtime_instance_ref.set_runtime_state("start_position", Vector2.ZERO)
		_runtime_instance_ref.set_runtime_state("start_time", 0.0)

	_owner_node_ref = null
	_runtime_instance_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 输入处理
func _input(event: InputEvent) -> void:
	if not _runtime_instance_ref:
		return

	var is_monitoring: bool = _runtime_instance_ref.get_runtime_state("is_monitoring")
	if not is_monitoring:
		return

	if event is InputEventScreenTouch:
		_handle_touch_event(event)

## 处理触摸事件
func _handle_touch_event(event: InputEventScreenTouch) -> void:
	if event.pressed:
		# 触摸开始
		_runtime_instance_ref.set_runtime_state("start_position", event.position)
		_runtime_instance_ref.set_runtime_state("start_time", Time.get_ticks_msec() / 1000.0)
		_runtime_instance_ref.set_runtime_state("is_touching", true)
	else:
		# 触摸结束
		var is_touching: bool = _runtime_instance_ref.get_runtime_state("is_touching")
		if not is_touching:
			return

		_runtime_instance_ref.set_runtime_state("is_touching", false)
		var end_position = event.position
		var end_time = Time.get_ticks_msec() / 1000.0

		# 检查时间窗口
		var start_time: float = _runtime_instance_ref.get_runtime_state("start_time")
		var elapsed = end_time - start_time
		if elapsed > time_window:
			return

		# 计算滑动向量
		var start_position: Vector2 = _runtime_instance_ref.get_runtime_state("start_position")
		var swipe_vector = end_position - start_position
		var distance = swipe_vector.length()

		# 检查最小距离
		if distance < min_distance:
			return

		# 检测方向
		var detected_direction = _detect_direction(swipe_vector)
		if not _is_direction_match(detected_direction):
			return

		# 触发事件
		_trigger_event(swipe_vector, distance, elapsed)

## 检测滑动方向
func _detect_direction(swipe_vector: Vector2) -> SwipeDirection:
	var abs_x = abs(swipe_vector.x)
	var abs_y = abs(swipe_vector.y)

	if abs_x > abs_y:
		# 水平滑动
		return SwipeDirection.RIGHT if swipe_vector.x > 0 else SwipeDirection.LEFT
	else:
		# 垂直滑动
		return SwipeDirection.DOWN if swipe_vector.y > 0 else SwipeDirection.UP

## 检查方向是否匹配
func _is_direction_match(detected: SwipeDirection) -> bool:
	if swipe_direction == SwipeDirection.ANY:
		return true
	return detected == swipe_direction

## 触发事件
func _trigger_event(swipe_vector: Vector2, distance: float, elapsed: float) -> void:
	var direction_text = _get_direction_name(_detect_direction(swipe_vector))

	_log_info_localized("FUSE_LOG_EVENT_TOUCH_SWIPE_TRIGGERED", {
		"direction": direction_text,
		"distance": int(distance)
	})

	# 创建上下文节点
	var context_node = Node.new()
	context_node.name = "TouchSwipeContext"

	# 传递方向
	context_node.set_meta("direction", _detect_direction(swipe_vector))
	context_node.set_meta("direction_name", direction_text)

	# 传递距离
	context_node.set_meta("distance", distance)

	# 传递速度（如果启用）
	if emit_velocity:
		var velocity = swipe_vector / elapsed if elapsed > 0 else Vector2.ZERO
		context_node.set_meta("velocity", velocity)

	# 传递起点和终点
	var start_position: Vector2 = _runtime_instance_ref.get_runtime_state("start_position")
	context_node.set_meta("start_position", start_position)
	context_node.set_meta("end_position", start_position + swipe_vector)

	triggered.emit(context_node)

	# 清理上下文节点
	context_node.queue_free()

## 获取方向键（用于显示）
func _get_direction_key() -> String:
	match swipe_direction:
		SwipeDirection.UP:
			return "FUSE_TEXT_SWIPE_DIRECTION_UP"
		SwipeDirection.DOWN:
			return "FUSE_TEXT_SWIPE_DIRECTION_DOWN"
		SwipeDirection.LEFT:
			return "FUSE_TEXT_SWIPE_DIRECTION_LEFT"
		SwipeDirection.RIGHT:
			return "FUSE_TEXT_SWIPE_DIRECTION_RIGHT"
		SwipeDirection.ANY:
			return "FUSE_TEXT_SWIPE_DIRECTION_ANY"
		_:
			return "FUSE_TEXT_SWIPE_DIRECTION_UNKNOWN"

## 获取方向名称
func _get_direction_name(direction: SwipeDirection) -> String:
	match direction:
		SwipeDirection.UP:
			return FuseLocalization.translate("FUSE_TEXT_SWIPE_DIRECTION_UP")
		SwipeDirection.DOWN:
			return FuseLocalization.translate("FUSE_TEXT_SWIPE_DIRECTION_DOWN")
		SwipeDirection.LEFT:
			return FuseLocalization.translate("FUSE_TEXT_SWIPE_DIRECTION_LEFT")
		SwipeDirection.RIGHT:
			return FuseLocalization.translate("FUSE_TEXT_SWIPE_DIRECTION_RIGHT")
		_:
			return FuseLocalization.translate("FUSE_TEXT_SWIPE_DIRECTION_UNKNOWN")

## 获取事件描述
func get_description() -> String:
	var direction_key = _get_direction_key()
	return FuseLocalization.translate_format("FUSE_EVENT_ON_TOUCH_SWIPE_DESC", {
		"direction": FuseLocalization.translate(direction_key),
		"distance": str(int(min_distance))
	})

## 获取事件类型
func get_event_type() -> String:
	return "touch_swipe"

## 获取事件分类
func get_event_category() -> String:
	return "input"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if min_distance <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_MIN_DISTANCE_INVALID"))

	if time_window <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_TIME_WINDOW_INVALID"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	# 重置 RuntimeInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", true)
		_runtime_instance_ref.set_runtime_state("start_position", Vector2.ZERO)
		_runtime_instance_ref.set_runtime_state("start_time", 0.0)
		_runtime_instance_ref.set_runtime_state("is_touching", false)
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_TOUCH_SWIPE_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_INPUT"
	metadata.description_key = "FUSE_EVENT_ON_TOUCH_SWIPE_DESC"
	metadata.keywords = ["touch", "触摸", "swipe", "滑动", "gesture", "手势", "input", "输入"]
	metadata.builtin_icon = "InputEventScreenDrag"
	return metadata
