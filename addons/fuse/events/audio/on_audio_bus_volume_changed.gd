@tool
@icon("res://addons/fuse/icons/builtin/AudioBusLayout.png")
extends BaseEvent
class_name OnAudioBusVolumeChanged

## Event: OnAudioBusVolumeChanged
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _check_timer: float - 检查计时器
## - _last_volume_db: float - 上次音量记录
## - _is_monitoring: bool - 是否正在监听
## - _bus_index: int - 总线索引
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/zh_CN/dev_docs/guides/runtime-instance-migration-guide.md

## 音频总线音量变化事件
##
## 监听音频总线音量的变化，使用轮询检查模式

## 音频总线名称（如 "Master", "SFX", "Music"）
@export var bus_name: String = "Master":
	set(value):
		bus_name = value
		_update_resource_name()

## 检查间隔（秒），默认 0.1 秒
@export var check_interval: float = 0.1:
	set(value):
		check_interval = value
		_update_resource_name()

## 是否在任意变化时触发
@export var trigger_on_any_change: bool = true

## 音量变化阈值（dB），默认 1.0
@export_range(0.0, 80.0, 0.1) var volume_threshold: float = 1.0:
	set(value):
		volume_threshold = value
		_update_resource_name()

## 是否发出旧音量
@export var emit_old_volume: bool = true

## 是否发出新音量
@export var emit_new_volume: bool = true

## 是否发出变化量
@export var emit_volume_change: bool = true

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["check_timer"] = 0.0
	base["last_volume_db"] = 0.0
	base["is_monitoring"] = false
	base["bus_index"] = -1
	return base

## 更新资源名称（必需）
func _update_resource_name():
	var threshold_text = "%.1f dB" % volume_threshold if trigger_on_any_change else FuseLocalization.translate("FUSE_TEXT_ANY")

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_AUDIO_BUS_VOLUME_CHANGED_RESOURCE_NAME", {
		"bus": bus_name,
		"threshold": threshold_text
	})

## 使用 RuntimeInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证 bus_name
	if bus_name.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_AUDIO_BUS_NAME_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证总线是否存在
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		_create_fuse_error_localized("FUSE_ERROR_AUDIO_BUS_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"bus_name": bus_name})
		return

	# 验证 check_interval
	if check_interval <= 0:
		_create_fuse_error_localized("FUSE_ERROR_CHECK_INTERVAL_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {"interval": check_interval})
		return

	# 验证 volume_threshold
	if volume_threshold < 0:
		_create_fuse_error_localized("FUSE_ERROR_VOLUME_THRESHOLD_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {"threshold": volume_threshold})
		return

	# 设置初始状态
	get_runtime_instance().set_runtime_state("bus_index", bus_index)
	get_runtime_instance().set_runtime_state("is_monitoring", true)
	get_runtime_instance().set_runtime_state("check_timer", 0.0)

	# 获取初始音量
	var last_volume_db = AudioServer.get_bus_volume_db(bus_index)
	get_runtime_instance().set_runtime_state("last_volume_db", last_volume_db)

	_log_debug_localized("FUSE_LOG_EVENT_AUDIO_BUS_MONITORING_STARTED", {
		"bus_name": bus_name,
		"bus_index": bus_index,
		"interval": check_interval,
		"threshold": volume_threshold
	})

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证 bus_name
	if bus_name.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_AUDIO_BUS_NAME_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证总线是否存在
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		_create_fuse_error_localized("FUSE_ERROR_AUDIO_BUS_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"bus_name": bus_name})
		return

	# 验证 check_interval
	if check_interval <= 0:
		_create_fuse_error_localized("FUSE_ERROR_CHECK_INTERVAL_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {"interval": check_interval})
		return

	# 验证 volume_threshold
	if volume_threshold < 0:
		_create_fuse_error_localized("FUSE_ERROR_VOLUME_THRESHOLD_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {"threshold": volume_threshold})
		return

	# 设置初始状态
	get_runtime_instance().set_runtime_state("bus_index", bus_index)
	get_runtime_instance().set_runtime_state("is_monitoring", true)
	get_runtime_instance().set_runtime_state("check_timer", 0.0)

	# 获取初始音量
	var last_volume_db = AudioServer.get_bus_volume_db(bus_index)
	get_runtime_instance().set_runtime_state("last_volume_db", last_volume_db)

	_log_debug_localized("FUSE_LOG_EVENT_AUDIO_BUS_MONITORING_STARTED", {
		"bus_name": bus_name,
		"bus_index": bus_index,
		"interval": check_interval,
		"threshold": volume_threshold
	})

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)
		_runtime_instance_ref.set_runtime_state("check_timer", 0.0)
		_runtime_instance_ref.set_runtime_state("last_volume_db", 0.0)
		_runtime_instance_ref.set_runtime_state("bus_index", -1)
		_runtime_instance_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 每帧处理（由 Trigger 调用）
func on_process(delta: float, event_instance: RuntimeEventInstance = null) -> void:
	var is_monitoring = get_runtime_instance().get_runtime_state("is_monitoring")
	if not is_monitoring:
		return

	var check_timer = get_runtime_instance().get_runtime_state("check_timer")
	check_timer += delta
	get_runtime_instance().set_runtime_state("check_timer", check_timer)

	if check_timer >= check_interval:
		check_timer -= check_interval
		get_runtime_instance().set_runtime_state("check_timer", check_timer)
		_check_volume_change()

## 检查音量变化
func _check_volume_change():
	var bus_index = get_runtime_instance().get_runtime_state("bus_index")
	var current_volume_db = AudioServer.get_bus_volume_db(bus_index)
	var last_volume_db = get_runtime_instance().get_runtime_state("last_volume_db")
	var volume_change = abs(current_volume_db - last_volume_db)

	var should_trigger = false

	if trigger_on_any_change:
		# 任意变化时触发（受阈值限制）
		if volume_change >= volume_threshold:
			should_trigger = true
	else:
		# 仅在超过阈值时触发
		if volume_change >= volume_threshold:
			should_trigger = true

	if should_trigger:
		var old_volume = last_volume_db
		var new_volume = current_volume_db
		var change_amount = new_volume - old_volume

		get_runtime_instance().set_runtime_state("last_volume_db", current_volume_db)

		_log_info_localized("FUSE_LOG_EVENT_AUDIO_BUS_VOLUME_CHANGED", {
			"bus_name": bus_name,
			"old_volume": "%.2f" % old_volume,
			"new_volume": "%.2f" % new_volume,
			"change": "%.2f" % change_amount
		})

		# 创建上下文节点传递值
		var context_node = Node.new()
		context_node.name = "AudioBusVolumeChangedContext"

		context_node.set_meta("bus_name", bus_name)
		context_node.set_meta("bus_index", bus_index)

		if emit_old_volume:
			context_node.set_meta("old_volume_db", old_volume)

		if emit_new_volume:
			context_node.set_meta("new_volume_db", new_volume)

		if emit_volume_change:
			context_node.set_meta("volume_change_db", change_amount)

		triggered.emit(context_node)

		# 清理上下文节点
		context_node.queue_free()

## 获取事件描述
func get_description() -> String:
	var mode_key = "FUSE_EVENT_AUDIO_VOLUME_CHANGE_ANY" if trigger_on_any_change else "FUSE_EVENT_AUDIO_VOLUME_CHANGE_THRESHOLD"
	var mode_text = FuseLocalization.translate_format(mode_key, {"threshold": "%.1f dB" % volume_threshold})

	var options = []
	if emit_old_volume:
		options.append(FuseLocalization.translate("FUSE_EVENT_AUDIO_VOLUME_OLD"))
	if emit_new_volume:
		options.append(FuseLocalization.translate("FUSE_EVENT_AUDIO_VOLUME_NEW"))
	if emit_volume_change:
		options.append(FuseLocalization.translate("FUSE_EVENT_AUDIO_VOLUME_CHANGE"))

	var options_text = ""
	if not options.is_empty():
		options_text = FuseLocalization.translate_format("FUSE_EVENT_AUDIO_EMIT_OPTIONS", {
			"options": "、".join(options)
		})

	return FuseLocalization.translate_format("FUSE_EVENT_ON_AUDIO_BUS_VOLUME_CHANGED_DESC", {
		"bus": bus_name,
		"mode": mode_text,
		"interval": "%.2f" % check_interval,
		"options": options_text
	})

## 获取事件类型
func get_event_type() -> String:
	return "audio_bus_volume_changed"

## 获取事件分类
func get_event_category() -> String:
	return "state"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if bus_name.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_AUDIO_BUS_NAME_EMPTY"))

	if check_interval <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_CHECK_INTERVAL_INVALID"))

	if volume_threshold < 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_VOLUME_THRESHOLD_INVALID"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()

	# 重置 RuntimeInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("check_timer", 0.0)
		var bus_index = _runtime_instance_ref.get_runtime_state("bus_index")
		if bus_index >= 0:
			var last_volume_db = AudioServer.get_bus_volume_db(bus_index)
			_runtime_instance_ref.set_runtime_state("last_volume_db", last_volume_db)

	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取当前总线音量（dB）
func get_current_volume_db() -> float:
	if not _runtime_instance_ref:
		return -INF

	var bus_index = _runtime_instance_ref.get_runtime_state("bus_index")
	if bus_index < 0:
		return -INF
	return AudioServer.get_bus_volume_db(bus_index)

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_AUDIO_BUS_VOLUME_CHANGED_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_AUDIO"
	metadata.description_key = "FUSE_EVENT_ON_AUDIO_BUS_VOLUME_CHANGED_DESC"
	metadata.keywords = ["audio", "音频", "bus", "总线", "volume", "音量", "change", "变化", "monitor", "监听"]
	metadata.builtin_icon = "AudioBusLayout"
	return metadata
