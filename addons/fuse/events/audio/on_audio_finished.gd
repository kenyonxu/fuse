@tool
@icon("res://addons/fuse/icons/builtin/AudioStreamPlayer.png")
extends BaseEvent
class_name OnAudioFinished

## Event: OnAudioFinished
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - (此 Event 无额外状态变量，仅有节点引用)
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/zh_CN/dev_docs/guides/runtime-instance-migration-guide.md

## 音频播放完成事件
##
## 当 AudioStreamPlayer 播放完成时触发

## 目标 AudioStreamPlayer 节点路径
@export var audio_player_path: NodePath = NodePath(""):
	set(value):
		audio_player_path = value
		_update_resource_name()

## 是否传递音频名称
@export var emit_audio_name: bool = true

## 是否传递音频长度
@export var emit_stream_length: bool = false

var _audio_player_ref: AudioStreamPlayer = null

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	# 此 Event 无额外状态变量
	return base

## 使用 RuntimeInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证目标节点路径
	if audio_player_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 获取目标节点
	_audio_player_ref = owner_node.get_node_or_null(audio_player_path)
	if not _audio_player_ref:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(audio_player_path)})
		return

	# 验证节点类型
	if not _audio_player_ref is AudioStreamPlayer:
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(audio_player_path)})
		return

	# 连接信号
	if not _audio_player_ref.finished.is_connected(_on_audio_finished):
		_audio_player_ref.finished.connect(_on_audio_finished)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 更新资源名称（必需）
func _update_resource_name():
	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_AUDIO_FINISHED_RESOURCE_NAME", {
		"player": str(audio_player_path)
	})

## 初始化事件监听（必需）- 向后兼容
func initialize(owner_node: Node) -> void:
	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证目标节点路径
	if audio_player_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 获取目标节点
	_audio_player_ref = owner_node.get_node_or_null(audio_player_path)
	if not _audio_player_ref:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(audio_player_path)})
		return

	# 验证节点类型
	if not _audio_player_ref is AudioStreamPlayer:
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(audio_player_path)})
		return

	# 连接信号
	if not _audio_player_ref.finished.is_connected(_on_audio_finished):
		_audio_player_ref.finished.connect(_on_audio_finished)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 断开信号连接
	if _audio_player_ref and is_instance_valid(_audio_player_ref):
		if _audio_player_ref.finished.is_connected(_on_audio_finished):
			_audio_player_ref.finished.disconnect(_on_audio_finished)

	# 清理引用
	_audio_player_ref = null
	_runtime_instance_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 音频完成回调
func _on_audio_finished():
	if not _audio_player_ref or not is_instance_valid(_audio_player_ref):
		return
	_log_info_localized("FUSE_LOG_EVENT_AUDIO_FINISHED", {"player": _audio_player_ref.name if _audio_player_ref else "Unknown"})

	# 创建上下文节点传递参数
	var context_node = Node.new()
	context_node.name = "AudioFinishedContext"

	context_node.set_meta("audio_player", _audio_player_ref)

	if emit_audio_name and _audio_player_ref:
		var stream = _audio_player_ref.stream
		var audio_name = ""
		if stream:
			if stream.resource_path != "":
				audio_name = stream.resource_path.get_file()
			else:
				audio_name = FuseLocalization.translate("FUSE_EVENT_AUDIO_INLINE")
		context_node.set_meta("audio_name", audio_name)

	if emit_stream_length and _audio_player_ref and _audio_player_ref.stream:
		var stream_length = _audio_player_ref.stream.get_length()
		context_node.set_meta("stream_length", stream_length)

	triggered.emit(context_node)
	# 注意：context_node 会在指令执行完后被 Trigger 清理

## 获取事件描述
func get_description() -> String:
	var player_name = audio_player_path if not audio_player_path.is_empty() else FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED")
	var options = []

	if emit_audio_name:
		options.append(FuseLocalization.translate("FUSE_EVENT_AUDIO_NAME"))
	if emit_stream_length:
		options.append(FuseLocalization.translate("FUSE_EVENT_AUDIO_LENGTH"))

	var options_text = ""
	if not options.is_empty():
		options_text = FuseLocalization.translate_format("FUSE_EVENT_AUDIO_EMIT_OPTIONS", {
			"options": "、".join(options)
		})

	return FuseLocalization.translate_format("FUSE_EVENT_ON_AUDIO_FINISHED_DESC", {
		"player": player_name,
		"options": options_text
	})

## 获取事件类型
func get_event_type() -> String:
	return "audio_finished"

## 获取事件分类
func get_event_category() -> String:
	return "signal"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if audio_player_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_AUDIO_FINISHED_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_AUDIO"
	metadata.description_key = "FUSE_EVENT_ON_AUDIO_FINISHED_DESC"
	metadata.keywords = ["audio", "音频", "sound", "声音", "finished", "完成", "player", "播放器", "complete", "结束"]
	metadata.builtin_icon = "AudioStreamPlayer"
	return metadata
