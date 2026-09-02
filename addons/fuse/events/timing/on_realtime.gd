@tool
@icon("res://addons/fuse/icons/builtin/Time.png")
extends BaseEvent
class_name OnRealtime

## 按实际时间触发事件（不受 Engine.time_scale 影响）
##
## 与 OnTimer 不同，此事件使用 Timer 并设置 ignore_time_scale = true
## 即使游戏暂停或 time_scale = 0，此事件仍会触发
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _trigger_count: int - 触发次数计数器
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/zh_CN/dev_docs/guides/runtime-instance-migration-guide.md

## 触发间隔（秒）
@export_range(0.1, 3600.0, 0.1) var interval_seconds: float = 1.0:
	set(value):
		interval_seconds = value
		_update_resource_name()

## 最大触发次数（0 = 无限）
@export var max_triggers: int = 0:
	set(value):
		max_triggers = value
		_update_resource_name()

## 是否传递当前时间戳
@export var emit_timestamp: bool = false:
	set(value):
		emit_timestamp = value
		_update_resource_name()

var _timer: Timer = null
var _owner_node_ref: Node = null
var _tree_entered_connected: bool = false

## 更新资源名称（必需）
func _update_resource_name() -> void:
	var max_text = ""
	if max_triggers > 0:
		max_text = FuseLocalization.translate_format("FUSE_DESC_MAX_TRIGGERS_LIMITED", {"count": max_triggers})
	else:
		max_text = FuseLocalization.translate("FUSE_DESC_UNLIMITED")

	var time_text = "%.1fs" % interval_seconds
	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_REALTIME_RESOURCE_NAME", {
		"time": time_text,
		"max": max_text
	})

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["trigger_count"] = 0
	return base

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

	# 检查是否在场景树中
	if owner_node.is_inside_tree():
		_start_timer()
	else:
		# 等待进入场景树后再启动
		if not owner_node.tree_entered.is_connected(_on_tree_entered):
			owner_node.tree_entered.connect(_on_tree_entered)
			_tree_entered_connected = true

	# 初始化运行时状态
	_runtime_instance_ref.set_runtime_state("trigger_count", 0)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 断开 tree_entered 连接（如果存在）
	if _tree_entered_connected and owner_node and owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.disconnect(_on_tree_entered)
		_tree_entered_connected = false

	if _timer:
		_timer.stop()
		if _timer.timeout.is_connected(_on_timer_timeout):
			_timer.timeout.disconnect(_on_timer_timeout)
		if owner_node and is_instance_valid(owner_node):
			owner_node.remove_child(_timer)
		_timer.queue_free()
		_timer = null

	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("trigger_count", 0)

	_owner_node_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 定时器超时
func _on_timer_timeout() -> void:
	var trigger_count: int = 0
	if _runtime_instance_ref.has_runtime_state("trigger_count"):
		trigger_count = _runtime_instance_ref.get_runtime_state("trigger_count")

	# 检查触发次数限制
	if max_triggers > 0 and trigger_count >= max_triggers:
		_log_debug_localized("FUSE_LOG_EVENT_TIMER_REPEAT_LIMIT_REACHED", {"repeat_count": max_triggers})
		_timer.stop()
		return

	trigger_count += 1
	_runtime_instance_ref.set_runtime_state("trigger_count", trigger_count)

	var timestamp = Time.get_datetime_dict_from_system()
	var timestamp_str = "{year}-{month}-{day} {hour}:{minute}:{second}".format(timestamp)
	_log_debug_localized("FUSE_LOG_EVENT_REALTIME_TRIGGERED", {"timestamp": timestamp_str})

	var context: Variant = _owner_node_ref
	if emit_timestamp:
		context = {"timestamp": timestamp, "node": _owner_node_ref}

	triggered.emit(context)

## 当节点进入场景树时
func _on_tree_entered() -> void:
	_start_timer()

## 创建并启动定时器
func _start_timer() -> void:
	_timer = Timer.new()
	_timer.wait_time = interval_seconds
	_timer.autostart = false
	_timer.one_shot = false
	_timer.ignore_time_scale = true  # 关键：即使 time_scale=0 也继续计时

	if not _timer.timeout.is_connected(_on_timer_timeout):
		_timer.timeout.connect(_on_timer_timeout)

	_owner_node_ref.add_child(_timer)
	_timer.start()

	# 构建重复次数文本
	var repeat_count_text = str(max_triggers) if max_triggers > 0 else FuseLocalization.translate("FUSE_TEXT_UNLIMITED")
	_log_debug_localized("FUSE_LOG_EVENT_TIMER_STARTED", {
		"wait_time": interval_seconds,
		"repeat_count": repeat_count_text
	})

## 获取事件描述
func get_description() -> String:
	var max_text = ""
	if max_triggers > 0:
		max_text = FuseLocalization.translate_format("FUSE_DESC_MAX_TRIGGERS_LIMITED_SHORT", {"count": max_triggers})
	else:
		max_text = FuseLocalization.translate("FUSE_DESC_UNLIMITED_SHORT")

	return FuseLocalization.translate_format("FUSE_EVENT_ON_REALTIME_DESC", {
		"interval": "%.1f" % interval_seconds,
		"max": max_text
	})

## 获取事件类型
func get_event_type() -> String:
	return "realtime"

## 获取事件分类
func get_event_category() -> String:
	return "timing"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if interval_seconds <= 0:
		errors.append(FuseLocalization.translate_format("FUSE_ERROR_REALTIME_INTERVAL_INVALID", {"interval": str(interval_seconds)}))

	if max_triggers < 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_MAX_TRIGGERS_NEGATIVE"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()

	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("trigger_count", 0)

	if _timer:
		_timer.stop()
		if _owner_node_ref and is_instance_valid(_owner_node_ref):
			_timer.start()

	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_REALTIME_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_TIMER"
	metadata.description_key = "FUSE_EVENT_ON_REALTIME_DESC"
	metadata.keywords = ["time", "时间", "realtime", "实时", "clock", "时钟", "unscaled", "不受缩放", "interval", "间隔"]
	metadata.builtin_icon = "Time"
	return metadata
