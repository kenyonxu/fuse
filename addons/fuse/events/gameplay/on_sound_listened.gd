@tool
@icon("res://addons/fuse/icons/builtin/AudioListener3D.png")
extends BaseEvent
class_name OnSoundListened

## 声音被"听到"事件
##
## 检测声音是否被监听器"听到"（基于距离和方向）
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _check_timer: float - 检查计时器
## - _was_heard: bool - 上次是否听到
## - _has_triggered_once: bool - 是否已触发一次
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

## 声源节点路径（AudioStreamPlayer2D/3D）
@export var sound_source_path: NodePath = NodePath(""):
	set(value):
		sound_source_path = value
		_update_resource_name()

## 监听器节点路径（如玩家 Camera 或 CharacterBody3D）
@export var listener_path: NodePath = NodePath(""):
	set(value):
		listener_path = value
		_update_resource_name()

## 最大听到距离，默认 100.0
@export var max_distance: float = 100.0:
	set(value):
		max_distance = value
		_update_resource_name()

## 检查间隔（秒），默认 0.1 秒
@export var check_interval: float = 0.1:
	set(value):
		check_interval = value
		_update_resource_name()

## 是否需要视线检测，默认 false
@export var require_line_of_sight: bool = false

## 射线检测层（用于视线检测）
@export_flags_3d_physics var raycast_layers: int = 1

## 触发模式
enum TriggerMode {
	ON_HEARD,         ## 第一次听到时触发
	ON_NOT_HEARD,     ## 第一次听不到时触发
	ON_CHANGE         ## 状态改变时触发（听到/听不到）
}

@export var trigger_mode: TriggerMode = TriggerMode.ON_CHANGE:
	set(value):
		trigger_mode = value
		_update_resource_name()

var _is_monitoring: bool = false
var _owner_node_ref: Node = null
var _sound_source_ref: Node = null
var _listener_ref: Node = null

## 更新资源名称（必需）
func _update_resource_name():
	var mode_key = ""
	match trigger_mode:
		TriggerMode.ON_HEARD:
			mode_key = "FUSE_EVENT_SOUND_MODE_HEARD"
		TriggerMode.ON_NOT_HEARD:
			mode_key = "FUSE_EVENT_SOUND_MODE_NOT_HEARD"
		TriggerMode.ON_CHANGE:
			mode_key = "FUSE_EVENT_SOUND_MODE_CHANGE"

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_SOUND_LISTENED_RESOURCE_NAME", {
		"distance": "%.1f" % max_distance,
		"mode": FuseLocalization.translate(mode_key)
	})

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["check_timer"] = 0.0
	base["was_heard"] = false
	base["has_triggered_once"] = false
	return base

## 使用 RuntimeInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	# 保存 RuntimeEventInstance 引用
	_runtime_instance_ref = runtime_instance

	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证节点路径
	if sound_source_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_SOUND_SOURCE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	if listener_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_LISTENER_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 获取声源节点
	_sound_source_ref = owner_node.get_node_or_null(sound_source_path)
	if not _sound_source_ref:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(sound_source_path)})
		return

	# 验证声源类型
	if not (_sound_source_ref is AudioStreamPlayer2D or _sound_source_ref is AudioStreamPlayer3D):
		_create_fuse_error_localized("FUSE_ERROR_INVALID_SOUND_SOURCE", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(sound_source_path)})
		return

	# 获取监听器节点
	_listener_ref = owner_node.get_node_or_null(listener_path)
	if not _listener_ref:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(listener_path)})
		return

	# 验证 check_interval
	if check_interval <= 0:
		_create_fuse_error_localized("FUSE_ERROR_CHECK_INTERVAL_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {"interval": check_interval})
		return

	# 验证 max_distance
	if max_distance < 0:
		_create_fuse_error_localized("FUSE_ERROR_DISTANCE_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {"distance": max_distance})
		return

	_owner_node_ref = owner_node
	_is_monitoring = true

	# 初始化运行时状态
	_runtime_instance_ref.set_runtime_state("check_timer", 0.0)
	_runtime_instance_ref.set_runtime_state("was_heard", false)
	_runtime_instance_ref.set_runtime_state("has_triggered_once", false)

	_log_debug_localized("FUSE_LOG_EVENT_SOUND_LISTENING_STARTED", {
		"source": _sound_source_ref.name,
		"listener": _listener_ref.name,
		"max_distance": max_distance,
		"interval": check_interval,
		"line_of_sight": require_line_of_sight
	})

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	_is_monitoring = false

	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("check_timer", 0.0)
		_runtime_instance_ref.set_runtime_state("was_heard", false)
		_runtime_instance_ref.set_runtime_state("has_triggered_once", false)

	_owner_node_ref = null
	_sound_source_ref = null
	_listener_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 每帧处理（由 Trigger 调用）
func on_process(delta: float) -> void:
	if not _is_monitoring:
		return

	var check_timer: float = 0.0
	if _runtime_instance_ref.has_runtime_state("check_timer"):
		check_timer = _runtime_instance_ref.get_runtime_state("check_timer")

	check_timer += delta
	_runtime_instance_ref.set_runtime_state("check_timer", check_timer)

	if check_timer >= check_interval:
		_runtime_instance_ref.set_runtime_state("check_timer", check_timer - check_interval)
		_check_sound_listened()

## 检查声音是否被听到
func _check_sound_listened():
	# 检查节点有效性
	if not is_instance_valid(_sound_source_ref) or not is_instance_valid(_listener_ref):
		_is_monitoring = false
		_log_warning_localized("FUSE_LOG_EVENT_SOUND_NODE_INVALID", {})
		return

	var is_heard = _is_sound_heard()

	var should_trigger = false
	var was_heard: bool = false
	var has_triggered_once: bool = false

	if _runtime_instance_ref.has_runtime_state("was_heard"):
		was_heard = _runtime_instance_ref.get_runtime_state("was_heard")
	if _runtime_instance_ref.has_runtime_state("has_triggered_once"):
		has_triggered_once = _runtime_instance_ref.get_runtime_state("has_triggered_once")

	match trigger_mode:
		TriggerMode.ON_HEARD:
			# 第一次听到时触发
			if is_heard and not has_triggered_once:
				should_trigger = true
				_runtime_instance_ref.set_runtime_state("has_triggered_once", true)

		TriggerMode.ON_NOT_HEARD:
			# 第一次听不到时触发
			if not is_heard and not has_triggered_once:
				should_trigger = true
				_runtime_instance_ref.set_runtime_state("has_triggered_once", true)

		TriggerMode.ON_CHANGE:
			# 状态改变时触发
			if is_heard != was_heard:
				should_trigger = true

	if should_trigger:
		_runtime_instance_ref.set_runtime_state("was_heard", is_heard)

		var distance = _get_distance()
		_log_info_localized("FUSE_LOG_EVENT_SOUND_LISTENED", {
			"heard": is_heard,
			"distance": "%.2f" % distance,
			"source": _sound_source_ref.name,
			"listener": _listener_ref.name
		})

		# 创建上下文节点传递值
		var context_node = Node.new()
		context_node.name = "SoundListenedContext"

		context_node.set_meta("sound_source", _sound_source_ref)
		context_node.set_meta("listener", _listener_ref)
		context_node.set_meta("is_heard", is_heard)
		context_node.set_meta("distance", distance)
		context_node.set_meta("max_distance", max_distance)

		triggered.emit(context_node)

		# 清理上下文节点
		context_node.queue_free()

## 判断声音是否被听到
func _is_sound_heard() -> bool:
	var distance = _get_distance()

	# 检查距离
	if distance > max_distance:
		return false

	# 检查视线（如果需要）
	if require_line_of_sight:
		return _check_line_of_sight()

	return true

## 获取声源和监听器之间的距离
func _get_distance() -> float:
	if not is_instance_valid(_sound_source_ref) or not is_instance_valid(_listener_ref):
		return INF

	var source_pos: Vector3
	var listener_pos: Vector3

	# 获取声源位置
	if _sound_source_ref is AudioStreamPlayer3D:
		source_pos = _sound_source_ref.global_position
	elif _sound_source_ref is AudioStreamPlayer2D:
		source_pos = Vector3(_sound_source_ref.global_position.x, _sound_source_ref.global_position.y, 0.0)
	else:
		source_pos = _sound_source_ref.global_position

	# 获取监听器位置
	if _listener_ref is Node3D:
		listener_pos = _listener_ref.global_position
	elif _listener_ref is Node2D:
		listener_pos = Vector3(_listener_ref.global_position.x, _listener_ref.global_position.y, 0.0)
	else:
		listener_pos = _listener_ref.global_position

	return source_pos.distance_to(listener_pos)

## 检查视线
func _check_line_of_sight() -> bool:
	if not is_instance_valid(_sound_source_ref) or not is_instance_valid(_listener_ref):
		return false

	var source_pos: Vector3
	var listener_pos: Vector3

	# 获取声源位置
	if _sound_source_ref is AudioStreamPlayer3D:
		source_pos = _sound_source_ref.global_position
	elif _sound_source_ref is AudioStreamPlayer2D:
		source_pos = Vector3(_sound_source_ref.global_position.x, _sound_source_ref.global_position.y, 0.0)
	else:
		source_pos = _sound_source_ref.global_position

	# 获取监听器位置
	if _listener_ref is Node3D:
		listener_pos = _listener_ref.global_position
	elif _listener_ref is Node2D:
		listener_pos = Vector3(_listener_ref.global_position.x, _listener_ref.global_position.y, 0.0)
	else:
		listener_pos = _listener_ref.global_position

	var space_state = _listener_ref.get_world_3d().direct_space_state
	if not space_state:
		return true

	# 执行射线检测
	var query = PhysicsRayQueryParameters3D.create(listener_pos, source_pos, raycast_layers)
	var result = space_state.intersect_ray(query)

	# 如果没有碰撞物，视线通畅
	if result.is_empty():
		return true

	# 检查碰撞物是否是声源本身
	var collider = result.get("collider")
	if collider == _sound_source_ref:
		return true

	return false

## 获取事件描述
func get_description() -> String:
	var source_name = sound_source_path if not sound_source_path.is_empty() else FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED")
	var listener_name = listener_path if not listener_path.is_empty() else FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED")

	var mode_key = ""
	match trigger_mode:
		TriggerMode.ON_HEARD:
			mode_key = "FUSE_EVENT_SOUND_DESC_HEARD"
		TriggerMode.ON_NOT_HEARD:
			mode_key = "FUSE_EVENT_SOUND_DESC_NOT_HEARD"
		TriggerMode.ON_CHANGE:
			mode_key = "FUSE_EVENT_SOUND_DESC_CHANGE"

	var mode_text = FuseLocalization.translate(mode_key)
	var line_of_sight_text = "" if not require_line_of_sight else FuseLocalization.translate("FUSE_EVENT_SOUND_LINE_OF_SIGHT")

	return FuseLocalization.translate_format("FUSE_EVENT_ON_SOUND_LISTENED_DESC", {
		"source": source_name,
		"listener": listener_name,
		"distance": "%.1f" % max_distance,
		"line_of_sight": line_of_sight_text,
		"mode": mode_text,
		"interval": "%.2f" % check_interval
	})

## 获取事件类型
func get_event_type() -> String:
	return "sound_listened"

## 获取事件分类
func get_event_category() -> String:
	return "state"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if sound_source_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_SOUND_SOURCE_EMPTY"))

	if listener_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_LISTENER_EMPTY"))

	if check_interval <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_CHECK_INTERVAL_INVALID"))

	if max_distance < 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_DISTANCE_INVALID"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()

	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("check_timer", 0.0)
		_runtime_instance_ref.set_runtime_state("was_heard", false)
		_runtime_instance_ref.set_runtime_state("has_triggered_once", false)

	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 手动检查声音是否被听到
func check_is_heard() -> bool:
	return _is_sound_heard()

## 获取当前距离
func get_current_distance() -> float:
	return _get_distance()

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_SOUND_LISTENED_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_STATE"
	metadata.description_key = "FUSE_EVENT_ON_SOUND_LISTENED_DESC"
	metadata.keywords = ["sound", "声音", "listen", "听到", "hear", "听觉", "distance", "距离", "detect", "检测", "3d", "audio"]
	metadata.builtin_icon = "AudioListener3D"
	return metadata
