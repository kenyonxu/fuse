@tool
@icon("res://addons/fuse/icons/builtin/AudioStreamPlayer.png")
extends BaseEvent
class_name OnAudioStarted

## Event: OnAudioStarted
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _was_playing: bool - 上一次的播放状态
## - _has_triggered_once: bool - 是否已触发过一次
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

## 当音频开始播放时触发
##
## 监听 AudioStreamPlayer 的 playing 属性变化
## 检测从 false → true 的状态转换

## 目标音频播放器路径
@export var audio_player_path: NodePath = NodePath(""):
	set(value):
		audio_player_path = value
		_update_resource_name()

## 是否传递音频名称
@export var emit_audio_name: bool = false:
	set(value):
		emit_audio_name = value
		_update_resource_name()

## 循环播放时是否每次触发
@export var trigger_on_loop: bool = true:
	set(value):
		trigger_on_loop = value
		_update_resource_name()

## 检测间隔（秒）
@export_range(0.01, 1.0, 0.01) var check_interval: float = 0.1:
	set(value):
		check_interval = value
		_update_resource_name()

# RuntimeInstance 引用已在 BaseEvent 中定义
var _audio_player_ref: AudioStreamPlayer = null
var _check_timer: Timer = null

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["was_playing"] = false
	base["has_triggered_once"] = false
	return base

## 更新资源名称（必需）
func _update_resource_name():
	var path_text = str(audio_player_path) if not audio_player_path.is_empty() else FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED")
	var loop_text = "" if trigger_on_loop else " " + FuseLocalization.translate("FUSE_TEXT_TRIGGER_ONCE_PER_PLAY")

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_AUDIO_STARTED_RESOURCE_NAME", {
		"path": path_text,
		"timing": loop_text
	})

## 使用 RuntimeInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证目标节点路径
	if audio_player_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 获取音频播放器
	_audio_player_ref = owner_node.get_node_or_null(audio_player_path)
	if not _audio_player_ref:
		_create_fuse_error_localized("FUSE_ERROR_AUDIO_PLAYER_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	if not _audio_player_ref is AudioStreamPlayer:
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {
			"node_path": str(audio_player_path),
			"expected_types": "AudioStreamPlayer"
		})
		return

	# 初始化状态
	get_runtime_instance().set_runtime_state("was_playing", _audio_player_ref.playing)

	# 创建检测定时器
	_check_timer = Timer.new()
	_check_timer.wait_time = check_interval
	if not _check_timer.timeout.is_connected(_on_check_timeout):
		_check_timer.timeout.connect(_on_check_timeout)
	_check_timer.autostart = false
	owner_node.add_child(_check_timer)
	_check_timer.start()

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证目标节点路径
	if audio_player_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 获取音频播放器
	_audio_player_ref = owner_node.get_node_or_null(audio_player_path)
	if not _audio_player_ref:
		_create_fuse_error_localized("FUSE_ERROR_AUDIO_PLAYER_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	if not _audio_player_ref is AudioStreamPlayer:
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {
			"node_path": str(audio_player_path),
			"expected_types": "AudioStreamPlayer"
		})
		return

	# 初始化状态（通过 RuntimeInstance）
	get_runtime_instance().set_runtime_state("was_playing", _audio_player_ref.playing)

	# 创建检测定时器
	_check_timer = Timer.new()
	_check_timer.wait_time = check_interval
	if not _check_timer.timeout.is_connected(_on_check_timeout):
		_check_timer.timeout.connect(_on_check_timeout)
	_check_timer.autostart = false
	owner_node.add_child(_check_timer)
	_check_timer.start()

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 停止并清理定时器
	if _check_timer:
		_check_timer.stop()
		if _check_timer.timeout.is_connected(_on_check_timeout):
			_check_timer.timeout.disconnect(_on_check_timeout)
		if owner_node and is_instance_valid(owner_node):
			owner_node.remove_child(_check_timer)
		_check_timer.queue_free()
		_check_timer = null

	# 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("was_playing", false)
		_runtime_instance_ref.set_runtime_state("has_triggered_once", false)
	_runtime_instance_ref = null
	_audio_player_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 重置事件状态
func reset() -> void:
	super.reset()
	# 重置 RuntimeInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("was_playing", false)
		_runtime_instance_ref.set_runtime_state("has_triggered_once", false)
	if _check_timer:
		_check_timer.stop()
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 定时检查
func _on_check_timeout():
	if not _audio_player_ref or not is_instance_valid(_audio_player_ref):
		return

	var is_playing = _audio_player_ref.playing
	var was_playing = false
	if get_runtime_instance().has_runtime_state("was_playing"):
		was_playing = get_runtime_instance().get_runtime_state("was_playing")

	# 检测从 false → true 的变化
	if is_playing and not was_playing:
		_log_debug_localized("FUSE_LOG_EVENT_AUDIO_START_CHECK", {
			"playing": is_playing,
			"was_playing": was_playing
		})
		_trigger_event()

	get_runtime_instance().set_runtime_state("was_playing", is_playing)

## 触发事件
func _trigger_event():
	# 检查是否需要触发
	var has_triggered_once = false
	if get_runtime_instance().has_runtime_state("has_triggered_once"):
		has_triggered_once = get_runtime_instance().get_runtime_state("has_triggered_once")

	if not trigger_on_loop and has_triggered_once:
		_log_debug_localized("FUSE_LOG_EVENT_AUDIO_ALREADY_STARTED", {})
		return

	get_runtime_instance().set_runtime_state("has_triggered_once", true)

	if not _audio_player_ref or not is_instance_valid(_audio_player_ref):
		return

	var audio_name = ""
	if emit_audio_name and _audio_player_ref.has_method("get"):
		if _audio_player_ref.has_property("stream"):
			var stream = _audio_player_ref.get("stream")
			audio_name = stream.resource_path if stream else ""

	_log_debug_localized("FUSE_LOG_EVENT_AUDIO_STARTED", {
		"player": str(audio_player_path),
		"audio_name": audio_name
	})

	var context = _audio_player_ref
	triggered.emit(context)

## 获取事件描述
func get_description() -> String:
	var interval_text = "%.2fs" % check_interval
	var loop_text = "" if trigger_on_loop else FuseLocalization.translate("FUSE_EVENT_AUDIO_TRIGGER_FIRST")

	return FuseLocalization.translate_format("FUSE_EVENT_ON_AUDIO_STARTED_DESC", {
		"interval": interval_text,
		"timing": loop_text
	})

## 获取事件类型
func get_event_type() -> String:
	return "audio_started"

## 获取事件分类
func get_event_category() -> String:
	return "audio"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if audio_player_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	if check_interval <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_CHECK_INTERVAL_NON_POSITIVE"))

	if check_interval > 1.0:
		errors.append(FuseLocalization.translate("FUSE_WARNING_CHECK_INTERVAL_TOO_LARGE"))

	return errors

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_AUDIO_STARTED_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_AUDIO"
	metadata.description_key = "FUSE_EVENT_ON_AUDIO_STARTED_DESC"
	metadata.keywords = ["audio", "音频", "start", "开始", "play", "播放", "playing", "播放中", "monitor", "监听"]
	metadata.builtin_icon = "AudioStreamPlayer"
	return metadata
