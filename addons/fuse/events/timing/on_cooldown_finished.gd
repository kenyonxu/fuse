@tool
@icon("res://addons/fuse/icons/builtin/Timer.png")
extends BaseEvent
class_name OnCooldownFinished

## 冷却完成事件
##
## 监听技能/动作冷却时间结束，支持进度显示
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _remaining_time: float - 剩余冷却时间
## - _is_completed: bool - 是否已完成冷却
## - _is_running: bool - 是否正在冷却中
##
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

## 冷却时间（秒）
@export var cooldown_seconds: float = 1.0:
	set(value):
		cooldown_seconds = value
		_update_resource_name()

## 是否需要手动触发开始冷却
@export var manual_trigger: bool = false:
	set(value):
		manual_trigger = value
		_update_resource_name()

## 是否在 context 中传递冷却进度
@export var show_progress: bool = true:
	set(value):
		show_progress = value
		_update_resource_name()

## 进度更新间隔（秒）
@export var progress_update_interval: float = 0.1:
	set(value):
		progress_update_interval = value
		_update_resource_name()

var _main_timer: Timer = null
var _progress_timer: Timer = null
var _owner_node_ref: Node = null

## 更新资源名称（必需）
func _update_resource_name():
	var manual_key = "FUSE_DESC_MANUAL_TRIGGER" if manual_trigger else "FUSE_DESC_AUTO_START"
	var manual_text = FuseLocalization.translate(manual_key)
	var show_text = ""
	if show_progress:
		show_text = FuseLocalization.translate_format("FUSE_DESC_SHOW_PROGRESS", {
			"interval": "%.3fs" % progress_update_interval
		})

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_COOLDOWN_FINISHED_RESOURCE_NAME", {
		"cooldown": "%.1fs" % cooldown_seconds,
		"manual": manual_text,
		"show_progress": show_text
	})

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证冷却时间
	if cooldown_seconds <= 0:
		_create_fuse_error_localized("FUSE_ERROR_COOLDOWN_SECONDS_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {"cooldown_seconds": cooldown_seconds})
		return

	# 验证更新间隔
	if show_progress and progress_update_interval <= 0:
		_create_fuse_error_localized("FUSE_ERROR_UPDATE_INTERVAL_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {"update_interval": progress_update_interval})
		return

	_owner_node_ref = owner_node

	# 检查是否在场景树中
	if owner_node.is_inside_tree():
		if not manual_trigger:
			_start_cooldown()
		else:
			_create_timers()
	else:
		# 等待进入场景树后再启动
		owner_node.tree_entered.connect(_on_tree_entered)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 断开 tree_entered 连接
	if owner_node and owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.disconnect(_on_tree_entered)

	# 清理所有定时器
	_cleanup_all_timers()

	# 🔧 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("remaining_time", 0.0)
		_runtime_instance_ref.set_runtime_state("is_completed", false)
		_runtime_instance_ref.set_runtime_state("is_running", false)

	_owner_node_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 当节点进入场景树时
func _on_tree_entered():
	if not manual_trigger:
		_start_cooldown()
	else:
		_create_timers()

## 创建定时器（不自动启动）
func _create_timers():
	if not _owner_node_ref:
		return

	_cleanup_all_timers()

	# 创建主冷却定时器
	_main_timer = Timer.new()
	_main_timer.wait_time = cooldown_seconds
	_main_timer.one_shot = true
	_main_timer.timeout.connect(_on_main_timer_timeout)
	_owner_node_ref.add_child(_main_timer)

	# 创建进度更新定时器
	if show_progress:
		_progress_timer = Timer.new()
		_progress_timer.wait_time = progress_update_interval
		_progress_timer.one_shot = false
		_progress_timer.timeout.connect(_on_progress_timer_timeout)
		_owner_node_ref.add_child(_progress_timer)

	# 🔧 使用 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("remaining_time", cooldown_seconds)
		_runtime_instance_ref.set_runtime_state("is_completed", false)

## 开始冷却
func _start_cooldown():
	if not _owner_node_ref:
		return

	_create_timers()

	if _main_timer:
		_main_timer.start()
		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("is_running", true)

		if _progress_timer:
			_progress_timer.start()

		_log_debug_localized("FUSE_LOG_EVENT_COOLDOWN_STARTED", {"cooldown_seconds": cooldown_seconds})

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

	# 清理进度定时器
	if _progress_timer:
		_progress_timer.stop()

		if _progress_timer.timeout.is_connected(_on_progress_timer_timeout):
			_progress_timer.timeout.disconnect(_on_progress_timer_timeout)

		if _owner_node_ref and is_instance_valid(_owner_node_ref):
			_owner_node_ref.remove_child(_progress_timer)

		_progress_timer.queue_free()
		_progress_timer = null

## 主冷却定时器超时回调
func _on_main_timer_timeout():
	# 🔧 使用 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_running", false)
		_runtime_instance_ref.set_runtime_state("is_completed", true)
		_runtime_instance_ref.set_runtime_state("remaining_time", 0.0)
		_runtime_instance_ref.update_trigger_stats()

	_log_info_localized("FUSE_LOG_EVENT_COOLDOWN_COMPLETED", {"cooldown_seconds": cooldown_seconds})

	# 创建上下文节点传递事件信息
	var context_node = Node.new()
	context_node.name = "CooldownFinishedContext"

	if show_progress:
		var progress = 1.0
		context_node.set_meta("cooldown_progress", progress)
		context_node.set_meta("remaining_time", 0.0)
		context_node.set_meta("total_duration", cooldown_seconds)
		context_node.set_meta("is_completed", true)
	else:
		context_node.set_meta("total_duration", cooldown_seconds)
		context_node.set_meta("is_completed", true)

	triggered.emit(context_node)

	# 清理上下文节点
	context_node.queue_free()

## 进度定时器超时回调
func _on_progress_timer_timeout():
	if _main_timer and _main_timer.time_left > 0:
		var remaining_time = _main_timer.time_left
		# 🔧 使用 RuntimeEventInstance 的状态
		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("remaining_time", remaining_time)

		var progress = 1.0 - (remaining_time / cooldown_seconds)

		_log_debug_localized("FUSE_LOG_EVENT_COOLDOWN_PROGRESS", {
			"progress": progress,
			"remaining_time": remaining_time
		})

		# 创建上下文节点传递进度信息
		var context_node = Node.new()
		context_node.name = "CooldownProgressContext"

		context_node.set_meta("cooldown_progress", progress)
		context_node.set_meta("remaining_time", remaining_time)
		context_node.set_meta("total_duration", cooldown_seconds)
		context_node.set_meta("is_completed", false)

		triggered.emit(context_node)

		# 清理上下文节点
		context_node.queue_free()

## 开始冷却（供外部调用）
func start_cooldown():
	var is_running = false
	if _runtime_instance_ref:
		is_running = _runtime_instance_ref.runtime_state.get("is_running", false)

	if _main_timer and not is_running:
		_start_cooldown()

## 暂停冷却
func pause_cooldown():
	var is_running = false
	var remaining_time = 0.0
	if _runtime_instance_ref:
		is_running = _runtime_instance_ref.runtime_state.get("is_running", false)
		remaining_time = _runtime_instance_ref.runtime_state.get("remaining_time", 0.0)

	if _main_timer and is_running:
		_main_timer.stop()
		if _progress_timer:
			_progress_timer.stop()
		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("is_running", false)
		_log_debug_localized("FUSE_LOG_EVENT_COOLDOWN_PAUSED", {"remaining_time": remaining_time})

## 恢复冷却
func resume_cooldown():
	var is_running = false
	var is_completed = false
	var remaining_time = 0.0
	if _runtime_instance_ref:
		is_running = _runtime_instance_ref.runtime_state.get("is_running", false)
		is_completed = _runtime_instance_ref.runtime_state.get("is_completed", false)
		remaining_time = _runtime_instance_ref.runtime_state.get("remaining_time", 0.0)

	if _main_timer and not is_running and not is_completed:
		_main_timer.start()
		if _progress_timer:
			_progress_timer.start()
		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("is_running", true)
		_log_debug_localized("FUSE_LOG_EVENT_COOLDOWN_RESUMED", {"remaining_time": remaining_time})

## 重置冷却
func reset_cooldown():
	_cleanup_all_timers()

	if not manual_trigger:
		_start_cooldown()
	else:
		_create_timers()

	_log_debug_localized("FUSE_LOG_EVENT_COOLDOWN_RESET", {"cooldown_seconds": cooldown_seconds})

## 获取剩余时间
func get_remaining_time() -> float:
	var is_running = false
	var remaining_time = 0.0
	if _runtime_instance_ref:
		is_running = _runtime_instance_ref.runtime_state.get("is_running", false)
		remaining_time = _runtime_instance_ref.runtime_state.get("remaining_time", 0.0)

	if _main_timer and is_running:
		return _main_timer.time_left
	return remaining_time

## 获取冷却进度（0.0-1.0）
func get_progress() -> float:
	var is_completed = false
	var is_running = false
	if _runtime_instance_ref:
		is_completed = _runtime_instance_ref.runtime_state.get("is_completed", false)
		is_running = _runtime_instance_ref.runtime_state.get("is_running", false)

	if is_completed:
		return 1.0
	if _main_timer and is_running:
		return 1.0 - (_main_timer.time_left / cooldown_seconds)
	return 0.0

## 是否正在冷却
func is_running() -> bool:
	if _runtime_instance_ref:
		return _runtime_instance_ref.runtime_state.get("is_running", false)
	return false

## 是否已完成
func is_completed() -> bool:
	if _runtime_instance_ref:
		return _runtime_instance_ref.runtime_state.get("is_completed", false)
	return false

## 获取事件描述
func get_description() -> String:
	var manual_key = "FUSE_DESC_MANUAL_START_NEEDED" if manual_trigger else "FUSE_DESC_AUTO_START"
	var manual_text = FuseLocalization.translate(manual_key)
	var show_text = ""
	if show_progress:
		show_text = FuseLocalization.translate_format("FUSE_DESC_SHOW_COOLDOWN_PROGRESS", {
			"interval": "%.3fs" % progress_update_interval
		})

	return FuseLocalization.translate_format("FUSE_EVENT_ON_COOLDOWN_FINISHED_DESC", {
		"cooldown": "%.1f" % cooldown_seconds,
		"manual": manual_text,
		"show_progress": show_text
	})

## 获取事件类型
func get_event_type() -> String:
	return "cooldown_finished"

## 获取事件分类
func get_event_category() -> String:
	return "timer"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if cooldown_seconds <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_COOLDOWN_SECONDS_INVALID"))

	if show_progress and progress_update_interval <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_UPDATE_INTERVAL_INVALID"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	reset_cooldown()
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["remaining_time"] = 0.0
	base["is_completed"] = false
	base["is_running"] = false
	return base

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_COOLDOWN_FINISHED_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_TIMER"
	metadata.description_key = "FUSE_EVENT_ON_COOLDOWN_FINISHED_DESC"
	metadata.keywords = ["cooldown", "冷却", "timer", "定时器", "skill", "技能", "ability", "能力", "progress", "进度", "remaining", "剩余", "duration", "持续时间"]
	metadata.builtin_icon = "Timer"
	return metadata
