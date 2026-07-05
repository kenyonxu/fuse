@tool
@icon("res://addons/fuse/icons/builtin/AnimationPlayer.png")
extends BaseEvent
class_name OnAnimationFrameReached

## Event: OnAnimationFrameReached
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _is_monitoring: bool → "is_monitoring" - 是否正在监听动画帧
## - _has_triggered: bool → "has_triggered" - 是否已触发过事件
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

## 动画播放到指定帧时触发
##
## 当 AnimationPlayer 播放到达指定帧时触发。

## 目标 AnimationPlayer 节点路径
@export var animation_player_path: NodePath = NodePath(""):
	set(value):
		animation_player_path = value
		_update_resource_name()

## 目标帧索引
@export_range(0, 10000, 1) var target_frame: int = 0:
	set(value):
		target_frame = value
		_update_resource_name()

## 动画名称（空字符串 = 当前动画）
@export var animation_name: String = "":
	set(value):
		animation_name = value
		_update_resource_name()

## 是否传递动画名称
@export var emit_animation_name: bool = true

## 是否传递当前帧
@export var emit_current_frame: bool = true

## 是否传递播放位置（秒）
@export var emit_position: bool = true

# RuntimeInstance 引用已在 BaseEvent 中定义
var _animation_player: AnimationPlayer = null
var _process_timer: Timer = null

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["is_monitoring"] = false
	base["has_triggered"] = false
	return base

## 使用 RuntimeInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	if animation_player_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_animation_player = owner_node.get_node_or_null(animation_player_path) as AnimationPlayer

	if not _animation_player:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(animation_player_path)})
		return

	# 验证节点类型
	if not _animation_player is AnimationPlayer:
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(animation_player_path)})
		return

	# 创建帧检测定时器（约 60 FPS）
	_process_timer = Timer.new()
	_process_timer.wait_time = 0.016
	_process_timer.timeout.connect(_on_process_timeout)
	_process_timer.autostart = false
	owner_node.add_child(_process_timer)
	_process_timer.start()

	# 设置初始状态
	get_runtime_instance().set_runtime_state("is_monitoring", true)
	get_runtime_instance().set_runtime_state("has_triggered", false)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 更新资源名称（必需）
func _update_resource_name() -> void:
	var player_text = str(animation_player_path) if not animation_player_path.is_empty() else FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED")
	var anim_text = animation_name if not animation_name.is_empty() else FuseLocalization.translate("FUSE_EVENT_ANIMATION_CURRENT")

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_ANIMATION_FRAME_REACHED_RESOURCE_NAME", {
		"frame": str(target_frame),
		"player": player_text,
		"animation": anim_text
	})

## 初始化事件监听（必需）- 保留以向后兼容
func initialize(owner_node: Node) -> void:
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	if animation_player_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_animation_player = owner_node.get_node_or_null(animation_player_path) as AnimationPlayer

	if not _animation_player:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(animation_player_path)})
		return

	# 验证节点类型
	if not _animation_player is AnimationPlayer:
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(animation_player_path)})
		return

	# 创建帧检测定时器（约 60 FPS）
	_process_timer = Timer.new()
	_process_timer.wait_time = 0.016
	_process_timer.timeout.connect(_on_process_timeout)
	_process_timer.autostart = false
	owner_node.add_child(_process_timer)
	_process_timer.start()

	# 设置初始状态（通过 RuntimeInstance）
	get_runtime_instance().set_runtime_state("is_monitoring", true)
	get_runtime_instance().set_runtime_state("has_triggered", false)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 定时检查帧位置
func _on_process_timeout() -> void:
	if not _animation_player or not is_instance_valid(_animation_player):
		return

	var is_monitoring = get_runtime_instance().get_runtime_state("is_monitoring")
	if not is_monitoring:
		return

	if not _animation_player.is_playing():
		return

	# 获取当前动画
	var current_anim = _animation_player.current_animation
	if current_anim.is_empty():
		return

	# 检查是否匹配指定动画
	if not animation_name.is_empty() and current_anim != animation_name:
		return

	# 获取动画资源
	var animation = _animation_player.get_animation(current_anim)
	if not animation:
		return

	# 获取当前播放位置（秒）
	var current_position = _animation_player.current_animation_position

	# 计算当前帧（使用动画的帧率，默认 60 FPS）
	var fps = animation.frame_rate
	if fps <= 0:
		fps = 60.0

	var current_frame = int(current_position * fps)

	# 检查是否到达或超过目标帧
	if current_frame >= target_frame:
		_trigger_event(current_anim, current_frame, current_position)

## 触发事件
func _trigger_event(anim_name: String, frame: int, position: float) -> void:
	var has_triggered = get_runtime_instance().get_runtime_state("has_triggered")
	if has_triggered:
		return

	get_runtime_instance().set_runtime_state("has_triggered", true)

	_log_info_localized("FUSE_LOG_EVENT_ANIMATION_FRAME_REACHED", {
		"animation": anim_name,
		"frame": str(frame)
	})

	# 创建上下文节点传递参数
	var context_node = Node.new()
	context_node.name = "AnimationFrameContext"

	if emit_animation_name:
		context_node.set_meta("animation_name", anim_name)

	if emit_current_frame:
		context_node.set_meta("current_frame", frame)

	if emit_position:
		context_node.set_meta("position", position)

	context_node.set_meta("target_frame", target_frame)
	context_node.set_meta("animation_player", _animation_player)

	triggered.emit(context_node)

	# 清理上下文节点
	context_node.queue_free()

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)
		_runtime_instance_ref.set_runtime_state("has_triggered", false)

	if _process_timer:
		_process_timer.stop()
		if _process_timer.timeout.is_connected(_on_process_timeout):
			_process_timer.timeout.disconnect(_on_process_timeout)
		if owner_node and is_instance_valid(owner_node):
			owner_node.remove_child(_process_timer)
		_process_timer.queue_free()
		_process_timer = null

	_animation_player = null
	_runtime_instance_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 获取事件描述
func get_description() -> String:
	var player_name = animation_player_path if not animation_player_path.is_empty() else FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED")
	var anim_text = animation_name if not animation_name.is_empty() else FuseLocalization.translate("FUSE_EVENT_ANIMATION_CURRENT")

	return FuseLocalization.translate_format("FUSE_EVENT_ON_ANIMATION_FRAME_REACHED_DESC", {
		"player": player_name,
		"animation": anim_text,
		"frame": str(target_frame)
	})

## 获取事件类型
func get_event_type() -> String:
	return "animation_frame_reached"

## 获取事件分类
func get_event_category() -> String:
	return "animation"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if animation_player_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	if target_frame < 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_FRAME_INDEX_INVALID"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	# 重置 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", false)
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_ANIMATION_FRAME_REACHED_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_ANIMATION"
	metadata.description_key = "FUSE_EVENT_ON_ANIMATION_FRAME_REACHED_DESC"
	metadata.keywords = ["animation", "动画", "frame", "帧", "position", "位置", "sync", "同步", "player", "播放器"]
	metadata.builtin_icon = "AnimationPlayer"
	return metadata
