@tool
@icon("res://addons/fuse/icons/builtin/Timer.png")
extends BaseEvent
class_name OnTimer

## 定时器事件
##
## 按指定时间间隔触发事件，支持单次和重复触发。
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _current_repeat_count: int - 当前重复次数
##
## 相关文档: addons/fuse/docs/zh_CN/dev_docs/guides/runtime-instance-migration-guide.md

## 等待时间（秒）
@export var wait_time: float = 1.0:
	set(value):
		wait_time = value
		_update_resource_name()

## 是否自动开始
@export var autostart: bool = true:
	set(value):
		autostart = value
		_update_resource_name()

## 重复次数（0 = 无限重复）
@export var repeat_count: int = 0:
	set(value):
		repeat_count = value
		_update_resource_name()

## 🔧 Timer 对象仍在 Event 类中管理（不存储在 RuntimeEventInstance）
var _timer: Timer = null

## 🔧 信号连接注册表：为每个 Trigger 存储独立的连接信息
## key: owner_node.get_instance_id()
## value: { "timer": Timer, "owner": Node }
var _signal_connections: Dictionary = {}

## 🔧 缓存 owner_node 引用，用于访问节点
var _owner_node_ref: Node = null

## 更新资源名称（必需）
func _update_resource_name():
	var repeat_text = ""
	if repeat_count > 0:
		repeat_text = FuseLocalization.translate_format("FUSE_DESC_REPEAT_COUNT", {"count": repeat_count})
	else:
		repeat_text = FuseLocalization.translate("FUSE_DESC_REPEAT_INFINITE")

	var auto_key = "FUSE_DESC_AUTO_START" if autostart else "FUSE_DESC_MANUAL_START"
	var auto_text = FuseLocalization.translate(auto_key)

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_TIMER_RESOURCE_NAME", {
		"wait_time": "%.2fs" % wait_time,
		"auto": auto_text,
		"repeat": repeat_text
	})

## 初始化事件监听（必需）- 向后兼容
func initialize(owner_node: Node) -> void:
	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证 wait_time
	if wait_time <= 0:
		_create_fuse_error_localized("FUSE_ERROR_TIMER_WAIT_TIME_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {"wait_time": wait_time})
		return

	_owner_node_ref = owner_node

	# 检查是否在场景树中
	if owner_node.is_inside_tree():
		_create_and_start_timer(owner_node)
	else:
		# 等待进入场景树后再启动
		owner_node.tree_entered.connect(_on_tree_entered.bind(owner_node))

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 🔧 使用 RuntimeEventInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		_log_debug("编辑器模式下，跳过事件初始化")
		return

	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证 wait_time
	if wait_time <= 0:
		_create_fuse_error_localized("FUSE_ERROR_TIMER_WAIT_TIME_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {"wait_time": wait_time})
		return

	_owner_node_ref = owner_node

	# 检查是否在场景树中
	if owner_node.is_inside_tree():
		_create_and_start_timer(owner_node)
	else:
		# 等待进入场景树后再启动
		owner_node.tree_entered.connect(_on_tree_entered.bind(owner_node))

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 断开 tree_entered 连接
	if owner_node and owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.disconnect(_on_tree_entered)

	# 清理定时器
	_cleanup_timer(owner_node)

	# 🔧 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("current_repeat_count", 0)

	_owner_node_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 创建并启动定时器
func _create_and_start_timer(owner_node: Node):
	if not owner_node:
		return

	_cleanup_timer(owner_node)

	var owner_id = owner_node.get_instance_id()

	var timer = Timer.new()
	timer.wait_time = wait_time
	timer.autostart = autostart
	timer.timeout.connect(_on_timer_timeout.bind(owner_node))

	owner_node.add_child(timer)

	# 保存连接信息
	_signal_connections[owner_id] = {
		"timer": timer,
		"owner": owner_node
	}

	if autostart:
		timer.start()
		_log_debug_localized("FUSE_LOG_EVENT_TIMER_STARTED", {"wait_time": wait_time, "repeat_count": repeat_count})

## 清理定时器
func _cleanup_timer(owner_node: Node):
	if not owner_node:
		return

	var owner_id = owner_node.get_instance_id()

	if _signal_connections.has(owner_id):
		var conn_info = _signal_connections[owner_id]
		var timer = conn_info.get("timer")

		if timer and is_instance_valid(timer):
			# 先停止定时器
			timer.stop()

			# 断开信号
			if timer.timeout.is_connected(_on_timer_timeout.bind(owner_node)):
				timer.timeout.disconnect(_on_timer_timeout.bind(owner_node))

			# 从场景树中移除并释放
			if owner_node and is_instance_valid(owner_node):
				owner_node.remove_child(timer)

			timer.queue_free()

		_signal_connections.erase(owner_id)

## 当节点进入场景树时
func _on_tree_entered(owner_node: Node):
	_create_and_start_timer(owner_node)

## 定时器超时回调
func _on_timer_timeout(owner_node: Node):
	# 🔧 使用 RuntimeEventInstance 的状态
	var current_repeat_count = 0
	if _runtime_instance_ref:
		current_repeat_count = _runtime_instance_ref.runtime_state.get("current_repeat_count", 0)

	# 检查重复次数
	if repeat_count > 0 and current_repeat_count >= repeat_count:
		# 达到重复次数，停止定时器
		_cleanup_timer(owner_node)
		_log_debug_localized("FUSE_LOG_EVENT_TIMER_REPEAT_LIMIT_REACHED", {"repeat_count": repeat_count})
		return

	# 递增计数
	current_repeat_count += 1
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("current_repeat_count", current_repeat_count)
		_runtime_instance_ref.update_trigger_stats()

	_log_info_localized("FUSE_LOG_EVENT_TIMER_TRIGGERED", {"count": current_repeat_count, "wait_time": wait_time})

	var context_node = Node.new()
	context_node.name = "TimerContext"
	context_node.set_meta("trigger", owner_node)
	context_node.set_meta("repeat_count", current_repeat_count)
	triggered.emit(context_node)
	context_node.queue_free()

## 启动定时器（供外部调用）
func start_timer():
	if _owner_node_ref:
		var owner_id = _owner_node_ref.get_instance_id()
		if _signal_connections.has(owner_id):
			var conn_info = _signal_connections[owner_id]
			var timer = conn_info.get("timer")
			if timer:
				timer.start()
				_log_debug_localized("FUSE_LOG_EVENT_TIMER_STARTED", {"wait_time": wait_time, "repeat_count": repeat_count})

## 停止定时器（供外部调用）
func stop_timer():
	if _owner_node_ref:
		var owner_id = _owner_node_ref.get_instance_id()
		if _signal_connections.has(owner_id):
			var conn_info = _signal_connections[owner_id]
			var timer = conn_info.get("timer")
			if timer:
				timer.stop()
				_log_debug_localized("FUSE_LOG_EVENT_TIMER_STOPPED", {})

## 获取事件描述
func get_description() -> String:
	var repeat_text = ""
	if repeat_count == 0:
		repeat_text = FuseLocalization.translate("FUSE_DESC_REPEAT_INFINITE")
	elif repeat_count == 1:
		repeat_text = FuseLocalization.translate("FUSE_DESC_REPEAT_ONCE")
	else:
		repeat_text = FuseLocalization.translate_format("FUSE_DESC_REPEAT_COUNT", {"count": repeat_count})

	var auto_key = "FUSE_DESC_AUTO_START" if autostart else "FUSE_DESC_MANUAL_START_NEEDED"
	var auto_text = FuseLocalization.translate(auto_key)

	return FuseLocalization.translate_format("FUSE_EVENT_ON_TIMER_DESC", {
		"wait_time": "%.2f" % wait_time,
		"repeat": repeat_text,
		"auto": auto_text
	})

## 获取事件类型
func get_event_type() -> String:
	return "timer"

## 获取事件分类
func get_event_category() -> String:
	return "timer"

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["current_repeat_count"] = 0
	return base

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if wait_time <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_TIMER_WAIT_TIME_INVALID"))

	if repeat_count < 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_TIMER_REPEAT_COUNT_INVALID"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()

	# 🔧 重置 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("current_repeat_count", 0)

	if _owner_node_ref:
		var owner_id = _owner_node_ref.get_instance_id()
		if _signal_connections.has(owner_id):
			var conn_info = _signal_connections[owner_id]
			var timer = conn_info.get("timer")
			if timer:
				timer.stop()
				if autostart:
					timer.start()

	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_TIMER_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_TIMER"
	metadata.description_key = "FUSE_EVENT_ON_TIMER_DESC"
	metadata.keywords = ["timer", "定时器", "interval", "间隔", "time", "时间", "repeat", "重复", "schedule", "调度"]
	metadata.builtin_icon = "Timer"
	return metadata
