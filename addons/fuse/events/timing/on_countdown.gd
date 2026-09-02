@tool
@icon("res://addons/fuse/icons/builtin/Timer.png")
extends BaseEvent
class_name OnCountdown

## 倒计时事件
##
## 倒计时指定秒数后触发事件，支持进度更新和暂停/恢复
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _remaining_time: float - 剩余时间
## - _is_completed: bool - 是否已完成
## - _is_running: bool - 是否正在运行
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/zh_CN/dev_docs/guides/runtime-instance-migration-guide.md

## 倒计时时长（秒）
@export var countdown_seconds: float = 5.0:
	set(value):
		countdown_seconds = value
		_update_resource_name()

## 是否自动开始倒计时
@export var auto_start: bool = true:
	set(value):
		auto_start = value
		_update_resource_name()

## 是否在 context 中传递剩余时间
@export var show_remaining_time: bool = true:
	set(value):
		show_remaining_time = value
		_update_resource_name()

## 更新剩余时间的间隔（秒）
@export var update_interval: float = 0.1:
	set(value):
		update_interval = value
		_update_resource_name()

var _main_timer: Timer = null
var _update_timer: Timer = null
var _owner_node_ref: Node = null

## 更新资源名称（必需）
func _update_resource_name():
	var auto_key = "FUSE_DESC_AUTO_START" if auto_start else "FUSE_DESC_MANUAL_START"
	var auto_text = FuseLocalization.translate(auto_key)
	var show_text = ""
	if show_remaining_time:
		show_text = FuseLocalization.translate_format("FUSE_DESC_SHOW_PROGRESS", {
			"interval": "%.3fs" % update_interval
		})

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_COUNTDOWN_RESOURCE_NAME", {
		"countdown": "%.1fs" % countdown_seconds,
		"auto": auto_text,
		"show_progress": show_text
	})

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["remaining_time"] = 0.0
	base["is_completed"] = false
	base["is_running"] = false
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

	# 验证倒计时时长
	if countdown_seconds <= 0:
		_create_fuse_error_localized("FUSE_ERROR_COUNTDOWN_SECONDS_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {"countdown_seconds": countdown_seconds})
		return

	# 验证更新间隔
	if show_remaining_time and update_interval <= 0:
		_create_fuse_error_localized("FUSE_ERROR_UPDATE_INTERVAL_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {"update_interval": update_interval})
		return

	_owner_node_ref = owner_node

	# 检查是否在场景树中
	if owner_node.is_inside_tree():
		if auto_start:
			_start_countdown()
		else:
			_create_timers()
	else:
		# 等待进入场景树后再启动
		owner_node.tree_entered.connect(_on_tree_entered)

	# 初始化运行时状态
	_runtime_instance_ref.set_runtime_state("remaining_time", 0.0)
	_runtime_instance_ref.set_runtime_state("is_completed", false)
	_runtime_instance_ref.set_runtime_state("is_running", false)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 断开 tree_entered 连接
	if owner_node and owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.disconnect(_on_tree_entered)

	# 清理所有定时器
	_cleanup_all_timers()

	# 重置状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("remaining_time", 0.0)
		_runtime_instance_ref.set_runtime_state("is_completed", false)
		_runtime_instance_ref.set_runtime_state("is_running", false)

	_owner_node_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 当节点进入场景树时
func _on_tree_entered():
	if auto_start:
		_start_countdown()
	else:
		_create_timers()

## 创建定时器（不自动启动）
func _create_timers():
	if not _owner_node_ref:
		return

	_cleanup_all_timers()

	# 创建主倒计时定时器
	_main_timer = Timer.new()
	_main_timer.wait_time = countdown_seconds
	_main_timer.one_shot = true
	_main_timer.timeout.connect(_on_main_timer_timeout)
	_owner_node_ref.add_child(_main_timer)

	# 创建进度更新定时器
	if show_remaining_time:
		_update_timer = Timer.new()
		_update_timer.wait_time = update_interval
		_update_timer.one_shot = false
		_update_timer.timeout.connect(_on_update_timer_timeout)
		_owner_node_ref.add_child(_update_timer)

	_runtime_instance_ref.set_runtime_state("remaining_time", countdown_seconds)
	_runtime_instance_ref.set_runtime_state("is_completed", false)

## 开始倒计时
func _start_countdown():
	if not _owner_node_ref:
		return

	_create_timers()

	if _main_timer:
		_main_timer.start()
		_runtime_instance_ref.set_runtime_state("is_running", true)

		if _update_timer:
			_update_timer.start()

	_log_debug_localized("FUSE_LOG_EVENT_COUNTDOWN_STARTED", {"countdown_seconds": countdown_seconds})

## 清理所有定时器
func _cleanup_all_timers():
	# 清理主定时器
	if _main_timer:
		_main_timer.stop()

		if _main_timer.timeout.is_connected(_on_main_timer_timeout):
			_main_timer.timeout.disconnect(_on_main_timer_timeout)

		if _owner_node_ref and is_instance_valid(_owner_node_ref):
			_owner_node_ref.remove_child(_main_timer)

		_main_timer.queue_free()
		_main_timer = null

	# 清理更新定时器
	if _update_timer:
		_update_timer.stop()

		if _update_timer.timeout.is_connected(_on_update_timer_timeout):
			_update_timer.timeout.disconnect(_on_update_timer_timeout)

		if _owner_node_ref and is_instance_valid(_owner_node_ref):
			_owner_node_ref.remove_child(_update_timer)

		_update_timer.queue_free()
		_update_timer = null

## 主倒计时定时器超时回调
func _on_main_timer_timeout():
	_runtime_instance_ref.set_runtime_state("is_running", false)
	_runtime_instance_ref.set_runtime_state("is_completed", true)
	_runtime_instance_ref.set_runtime_state("remaining_time", 0.0)

	_log_info_localized("FUSE_LOG_EVENT_COUNTDOWN_COMPLETED", {"countdown_seconds": countdown_seconds})

	# 创建上下文节点传递事件信息
	var context_node = Node.new()
	context_node.name = "CountdownContext"

	if show_remaining_time:
		context_node.set_meta("remaining_time", 0.0)
		context_node.set_meta("total_duration", countdown_seconds)
		context_node.set_meta("is_completed", true)
	else:
		context_node.set_meta("total_duration", countdown_seconds)
		context_node.set_meta("is_completed", true)

	triggered.emit(context_node)

	# 清理上下文节点
	context_node.queue_free()

## 更新定时器超时回调
func _on_update_timer_timeout():
	if _main_timer and _main_timer.time_left > 0:
		var remaining_time = _main_timer.time_left
		_runtime_instance_ref.set_runtime_state("remaining_time", remaining_time)

		_log_debug_localized("FUSE_LOG_EVENT_COUNTDOWN_PROGRESS", {"remaining_time": remaining_time})

		# 创建上下文节点传递进度信息
		var context_node = Node.new()
		context_node.name = "CountdownProgressContext"

		context_node.set_meta("remaining_time", remaining_time)
		context_node.set_meta("total_duration", countdown_seconds)
		context_node.set_meta("is_completed", false)

		triggered.emit(context_node)

		# 清理上下文节点
		context_node.queue_free()

## 开始倒计时（供外部调用）
func start_countdown():
	var is_running: bool = false
	if _runtime_instance_ref.has_runtime_state("is_running"):
		is_running = _runtime_instance_ref.get_runtime_state("is_running")

	if _main_timer and not is_running:
		_start_countdown()

## 暂停倒计时
func pause_countdown():
	var is_running: bool = false
	if _runtime_instance_ref.has_runtime_state("is_running"):
		is_running = _runtime_instance_ref.get_runtime_state("is_running")

	if _main_timer and is_running:
		_main_timer.stop()
		if _update_timer:
			_update_timer.stop()
		_runtime_instance_ref.set_runtime_state("is_running", false)

		var remaining_time: float = 0.0
		if _runtime_instance_ref.has_runtime_state("remaining_time"):
			remaining_time = _runtime_instance_ref.get_runtime_state("remaining_time")

		_log_debug_localized("FUSE_LOG_EVENT_COUNTDOWN_PAUSED", {"remaining_time": remaining_time})

## 恢复倒计时
func resume_countdown():
	var is_running: bool = false
	var is_completed: bool = false

	if _runtime_instance_ref.has_runtime_state("is_running"):
		is_running = _runtime_instance_ref.get_runtime_state("is_running")
	if _runtime_instance_ref.has_runtime_state("is_completed"):
		is_completed = _runtime_instance_ref.get_runtime_state("is_completed")

	if _main_timer and not is_running and not is_completed:
		_main_timer.start()
		if _update_timer:
			_update_timer.start()
		_runtime_instance_ref.set_runtime_state("is_running", true)

		var remaining_time: float = 0.0
		if _runtime_instance_ref.has_runtime_state("remaining_time"):
			remaining_time = _runtime_instance_ref.get_runtime_state("remaining_time")

		_log_debug_localized("FUSE_LOG_EVENT_COUNTDOWN_RESUMED", {"remaining_time": remaining_time})

## 重置倒计时
func reset_countdown():
	_cleanup_all_timers()
	_create_timers()

	if auto_start:
		_start_countdown()

	_log_debug_localized("FUSE_LOG_EVENT_COUNTDOWN_RESET", {"countdown_seconds": countdown_seconds})

## 获取剩余时间
func get_remaining_time() -> float:
	var is_running: bool = false
	if _runtime_instance_ref.has_runtime_state("is_running"):
		is_running = _runtime_instance_ref.get_runtime_state("is_running")

	if _main_timer and is_running:
		return _main_timer.time_left

	var remaining_time: float = 0.0
	if _runtime_instance_ref.has_runtime_state("remaining_time"):
		remaining_time = _runtime_instance_ref.get_runtime_state("remaining_time")

	return remaining_time

## 是否正在运行
func is_running() -> bool:
	if _runtime_instance_ref.has_runtime_state("is_running"):
		return _runtime_instance_ref.get_runtime_state("is_running")
	return false

## 是否已完成
func is_completed() -> bool:
	if _runtime_instance_ref.has_runtime_state("is_completed"):
		return _runtime_instance_ref.get_runtime_state("is_completed")
	return false

## 获取事件描述
func get_description() -> String:
	var auto_key = "FUSE_DESC_AUTO_START" if auto_start else "FUSE_DESC_MANUAL_START_NEEDED"
	var auto_text = FuseLocalization.translate(auto_key)
	var show_text = ""
	if show_remaining_time:
		show_text = FuseLocalization.translate_format("FUSE_DESC_SHOW_REMAINING_TIME", {
			"interval": "%.3fs" % update_interval
		})

	return FuseLocalization.translate_format("FUSE_EVENT_ON_COUNTDOWN_DESC", {
		"countdown": "%.1f" % countdown_seconds,
		"auto": auto_text,
		"show_remaining": show_text
	})

## 获取事件类型
func get_event_type() -> String:
	return "countdown"

## 获取事件分类
func get_event_category() -> String:
	return "timer"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if countdown_seconds <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_COUNTDOWN_SECONDS_INVALID"))

	if show_remaining_time and update_interval <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_UPDATE_INTERVAL_INVALID"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	_cleanup_all_timers()

	if auto_start:
		_start_countdown()
	else:
		_create_timers()

	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_COUNTDOWN_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_TIMER"
	metadata.description_key = "FUSE_EVENT_ON_COUNTDOWN_DESC"
	metadata.keywords = ["countdown", "倒计时", "timer", "定时器", "time", "时间", "count", "计数", "remaining", "剩余", "progress", "进度"]
	metadata.builtin_icon = "Timer"
	return metadata
