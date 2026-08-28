@tool
@icon("res://addons/fuse/icons/builtin/AudioStreamPlayer.png")
extends BaseEvent
class_name OnMusicBeat

## Event: OnMusicBeat
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _beat_timer: float - 节拍计时器
## - _beat_count: int - 节拍计数
## - _elapsed_time: float - 经过时间
## - _is_monitoring: bool - 是否正在监听
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

## 检测音乐节拍（BPM）
##
## 按照 BPM（每分钟节拍数）定期触发，用于节奏游戏和音乐同步。

## BPM（每分钟节拍数）
@export_range(1.0, 300.0, 1.0) var bpm: float = 120.0:
	set(value):
		bpm = value
		_update_resource_name()

## 节拍间隔（1 = 每拍，2 = 每两拍，4 = 每小节）
@export_range(1, 16, 1) var beat_interval: int = 1:
	set(value):
		beat_interval = value
		_update_resource_name()

## 是否传递节拍数
@export var emit_beat_count: bool = true

## 是否传递 BPM
@export var emit_bpm: bool = true

## 是否传递经过时间
@export var emit_elapsed_time: bool = true

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["beat_timer"] = 0.0
	base["beat_count"] = 0
	base["elapsed_time"] = 0.0
	base["is_monitoring"] = false
	return base

## 更新资源名称（必需）
func _update_resource_name() -> void:
	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_MUSIC_BEAT_RESOURCE_NAME", {
		"bpm": str(int(bpm)),
		"interval": str(beat_interval)
	})

## 使用 RuntimeInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	if bpm <= 0:
		_create_fuse_error_localized("FUSE_ERROR_BPM_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 设置初始状态
	get_runtime_instance().set_runtime_state("is_monitoring", true)
	get_runtime_instance().set_runtime_state("beat_count", 0)
	get_runtime_instance().set_runtime_state("beat_timer", 0.0)
	get_runtime_instance().set_runtime_state("elapsed_time", 0.0)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 每帧处理（由 Trigger 驱动）——原实现写在 _process(delta)，事件是 Resource
## 引擎从不调用资源的 _process，节拍永不触发；改为事件标准的 on_process 入口
func on_process(delta: float, _event_instance: RuntimeEventInstance = null) -> void:
	var is_monitoring = get_runtime_instance().get_runtime_state("is_monitoring")
	if not is_monitoring:
		return

	var beat_duration = 60.0 / bpm
	var beat_timer = get_runtime_instance().get_runtime_state("beat_timer")
	var elapsed_time = get_runtime_instance().get_runtime_state("elapsed_time")

	beat_timer += delta
	elapsed_time += delta

	get_runtime_instance().set_runtime_state("beat_timer", beat_timer)
	get_runtime_instance().set_runtime_state("elapsed_time", elapsed_time)

	if beat_timer >= beat_duration * beat_interval:
		var beat_count = get_runtime_instance().get_runtime_state("beat_count")
		beat_count += 1
		get_runtime_instance().set_runtime_state("beat_count", beat_count)
		get_runtime_instance().set_runtime_state("beat_timer", 0.0)
		_trigger_event()

## 触发事件
func _trigger_event() -> void:
	var beat_count = get_runtime_instance().get_runtime_state("beat_count")
	_log_info_localized("FUSE_LOG_EVENT_MUSIC_BEAT_TRIGGERED", {
		"count": str(beat_count)
	})

	# 创建上下文节点传递参数
	var context_node = Node.new()
	context_node.name = "MusicBeatContext"

	if emit_beat_count:
		context_node.set_meta("beat_count", beat_count)

	if emit_bpm:
		context_node.set_meta("bpm", bpm)

	if emit_elapsed_time:
		var elapsed_time = get_runtime_instance().get_runtime_state("elapsed_time")
		context_node.set_meta("elapsed_time", elapsed_time)

	context_node.set_meta("beat_interval", beat_interval)

	triggered.emit(context_node)

	# 清理上下文节点
	context_node.queue_free()

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)
		_runtime_instance_ref.set_runtime_state("beat_timer", 0.0)
		_runtime_instance_ref.set_runtime_state("elapsed_time", 0.0)
		_runtime_instance_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 获取事件描述
func get_description() -> String:
	return FuseLocalization.translate_format("FUSE_EVENT_ON_MUSIC_BEAT_DESC", {
		"bpm": str(int(bpm)),
		"interval": str(beat_interval)
	})

## 获取事件类型
func get_event_type() -> String:
	return "music_beat"

## 获取事件分类
func get_event_category() -> String:
	return "audio"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if bpm <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_BPM_INVALID"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()

	# 重置 RuntimeInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("beat_count", 0)
		_runtime_instance_ref.set_runtime_state("beat_timer", 0.0)
		_runtime_instance_ref.set_runtime_state("elapsed_time", 0.0)
		# 如果 owner_node 仍然有效，重新开始监听
		if _runtime_instance_ref.get_owner() and is_instance_valid(_runtime_instance_ref.get_owner()):
			_runtime_instance_ref.set_runtime_state("is_monitoring", true)

	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_MUSIC_BEAT_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_AUDIO"
	metadata.description_key = "FUSE_EVENT_ON_MUSIC_BEAT_DESC"
	metadata.keywords = ["music", "音乐", "beat", "节拍", "bpm", "rhythm", "节奏", "timing", "时机", "tempo", "拍子"]
	metadata.builtin_icon = "AudioStreamPlayer"
	return metadata
