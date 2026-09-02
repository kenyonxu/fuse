@tool
@icon("res://addons/fuse/icons/builtin/Timer.png")
extends BaseEvent
class_name OnInterval

## 间隔执行事件
##
## 按固定间隔重复触发事件，支持最大重复次数限制
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _is_running: bool - 是否正在运行
## - _is_completed: bool - 是否已完成
## - _current_repeat_count: int - 当前重复次数
## - _last_input_time: float - 最近一次输入的时间戳
##
## 相关文档: addons/fuse/docs/zh_CN/dev_docs/guides/runtime-instance-migration-guide.md

## 间隔时间（秒）- 仅当 use_random_interval = false 时使用
var interval_seconds: float = 1.0:
	set(value):
		interval_seconds = value
		_update_resource_name()

## 最大重复次数（0 = 无限重复）
@export var max_repeats: int = 0:
	set(value):
		max_repeats = value
		_update_resource_name()

## 是否自动开始
@export var auto_start: bool = true:
	set(value):
		auto_start = value
		_update_resource_name()

## 是否在启动时立即触发一次（然后再按间隔触发）
@export var trigger_on_start: bool = false:
	set(value):
		trigger_on_start = value
		_update_resource_name()

## 是否在 context 中传递重复次数
@export var emit_repeat_count: bool = true

## 是否使用随机间隔
@export var use_random_interval: bool = false:
	set(value):
		use_random_interval = value
		_update_resource_name()
		notify_property_list_changed()  # 刷新属性列表显示

## 最小间隔时间（秒）- 仅当 use_random_interval = true 时使用
var min_interval_seconds: float = 0.5:
	set(value):
		min_interval_seconds = value
		_update_resource_name()

## 最大间隔时间（秒）- 仅当 use_random_interval = true 时使用
var max_interval_seconds: float = 2.0:
	set(value):
		max_interval_seconds = value
		_update_resource_name()

## 停止条件（当条件满足时停止触发）
@export var stop_condition: BaseCondition = null:
	set(value):
		stop_condition = value
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
	var repeat_text_key = "FUSE_EVENT_ON_INTERVAL_REPEAT_INFINITE" if max_repeats == 0 else "FUSE_EVENT_ON_INTERVAL_REPEAT_COUNT"
	var auto_text_key = "FUSE_EVENT_ON_INTERVAL_AUTO_START" if auto_start else "FUSE_EVENT_ON_INTERVAL_MANUAL_START"
	var trigger_text_key = "FUSE_EVENT_ON_INTERVAL_TRIGGER_ON_START" if trigger_on_start else "FUSE_EVENT_ON_INTERVAL_TRIGGER_AFTER_INTERVAL"

	var repeat_text = FuseLocalization.translate(repeat_text_key)
	var auto_text = FuseLocalization.translate(auto_text_key)
	var trigger_text = FuseLocalization.translate(trigger_text_key)

	if max_repeats > 0:
		repeat_text = FuseLocalization.translate_format("FUSE_EVENT_ON_INTERVAL_REPEAT_COUNT_FORMAT", {"count": max_repeats})

	# 构建间隔时间文本
	var interval_text = ""
	if use_random_interval:
		interval_text = FuseLocalization.translate_format("FUSE_EVENT_ON_INTERVAL_RANDOM_RANGE", {
			"min": str(min_interval_seconds),
			"max": str(max_interval_seconds)
		})
	else:
		interval_text = str(interval_seconds)

	# 添加停止条件信息
	var stop_condition_text = ""
	if stop_condition:
		stop_condition_text = FuseLocalization.translate_format("FUSE_EVENT_ON_INTERVAL_WITH_STOP_CONDITION", {
			"condition": stop_condition.get_description()
		})

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_INTERVAL_RESOURCE_NAME", {
		"interval": interval_text,
		"auto": auto_text,
		"repeat": repeat_text,
		"trigger": trigger_text,
		"stop_condition": stop_condition_text
	})

## 动态属性列表 - 根据 use_random_interval 显示/隐藏相关属性
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	# interval_seconds - 仅当不使用随机间隔时显示
	var interval_usage: int = PROPERTY_USAGE_STORAGE  # 始终存储
	if not use_random_interval:
		interval_usage |= PROPERTY_USAGE_EDITOR  # 仅在非随机模式下显示在编辑器
	properties.append({
		"name": "interval_seconds",
		"type": TYPE_FLOAT,
		"usage": interval_usage,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.001,3600.0,0.001"
	})

	# min_interval_seconds - 仅当使用随机间隔时显示
	var min_usage: int = PROPERTY_USAGE_STORAGE  # 始终存储
	if use_random_interval:
		min_usage |= PROPERTY_USAGE_EDITOR  # 仅在随机模式下显示在编辑器
	properties.append({
		"name": "min_interval_seconds",
		"type": TYPE_FLOAT,
		"usage": min_usage,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.001,3600.0,0.001"
	})

	# max_interval_seconds - 仅当使用随机间隔时显示
	var max_usage: int = PROPERTY_USAGE_STORAGE  # 始终存储
	if use_random_interval:
		max_usage |= PROPERTY_USAGE_EDITOR  # 仅在随机模式下显示在编辑器
	properties.append({
		"name": "max_interval_seconds",
		"type": TYPE_FLOAT,
		"usage": max_usage,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.001,3600.0,0.001"
	})

	return properties

## 初始化事件监听（必需）- 向后兼容
func initialize(owner_node: Node) -> void:
	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证间隔时间
	if not use_random_interval and interval_seconds <= 0:
		_create_fuse_error_localized("FUSE_ERROR_INTERVAL_SECONDS_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {"interval_seconds": interval_seconds})
		return

	# 验证随机区间
	if use_random_interval:
		if min_interval_seconds <= 0:
			_create_fuse_error_localized("FUSE_ERROR_MIN_INTERVAL_SECONDS_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {"min_interval_seconds": min_interval_seconds})
			return
		if max_interval_seconds <= 0:
			_create_fuse_error_localized("FUSE_ERROR_MAX_INTERVAL_SECONDS_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {"max_interval_seconds": max_interval_seconds})
			return
		if min_interval_seconds > max_interval_seconds:
			_create_fuse_error_localized("FUSE_ERROR_INTERVAL_RANGE_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {
				"min_interval_seconds": min_interval_seconds,
				"max_interval_seconds": max_interval_seconds
			})
			return

	# 验证重复次数
	if max_repeats < 0:
		_create_fuse_error_localized("FUSE_ERROR_MAX_REPEATS_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {"max_repeats": max_repeats})
		return

	_owner_node_ref = owner_node
	_trigger_ref = owner_node  # 保存 Trigger 引用用于检查停止条件

	# 检查是否在场景树中
	if owner_node.is_inside_tree():
		if auto_start:
			_start_interval(owner_node)
		else:
			_create_timer(owner_node)
	else:
		# 等待进入场景树后再启动
		owner_node.tree_entered.connect(_on_tree_entered.bind(owner_node))

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 🔧 使用 RuntimeEventInstance 初始化事件
##
## 这是推荐的方法，通过 RuntimeEventInstance 管理运行时状态
##
## 参数：
## - owner_node: Node - 拥有此事件的 Trigger 节点
## - runtime_instance: RuntimeEventInstance - 运行时事件实例
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		_log_debug("编辑器模式下，跳过事件初始化")
		return

	# 保存 RuntimeEventInstance 引用
	_runtime_instance_ref = runtime_instance

	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证间隔时间
	if not use_random_interval and interval_seconds <= 0:
		_create_fuse_error_localized("FUSE_ERROR_INTERVAL_SECONDS_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {"interval_seconds": interval_seconds})
		return

	# 验证随机区间
	if use_random_interval:
		if min_interval_seconds <= 0:
			_create_fuse_error_localized("FUSE_ERROR_MIN_INTERVAL_SECONDS_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {"min_interval_seconds": min_interval_seconds})
			return
		if max_interval_seconds <= 0:
			_create_fuse_error_localized("FUSE_ERROR_MAX_INTERVAL_SECONDS_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {"max_interval_seconds": max_interval_seconds})
			return
		if min_interval_seconds > max_interval_seconds:
			_create_fuse_error_localized("FUSE_ERROR_INTERVAL_RANGE_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {
				"min_interval_seconds": min_interval_seconds,
				"max_interval_seconds": max_interval_seconds
			})
			return

	# 验证重复次数
	if max_repeats < 0:
		_create_fuse_error_localized("FUSE_ERROR_MAX_REPEATS_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {"max_repeats": max_repeats})
		return

	_owner_node_ref = owner_node
	_trigger_ref = owner_node  # 保存 Trigger 引用用于检查停止条件

	# 检查是否在场景树中
	if owner_node.is_inside_tree():
		if auto_start:
			_start_interval(owner_node)
		else:
			_create_timer(owner_node)
	else:
		# 等待进入场景树后再启动
		owner_node.tree_entered.connect(_on_tree_entered.bind(owner_node))

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 断开 tree_entered 连接
	if owner_node and owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.disconnect(_on_tree_entered)

	var owner_id = owner_node.get_instance_id()

	# 🔧 根据 owner_id 清理定时器和连接
	if _signal_connections.has(owner_id):
		var conn_info = _signal_connections[owner_id]
		var timer = conn_info.get("timer")

		if timer and is_instance_valid(timer):
			timer.stop()
			if timer.timeout.is_connected(_on_timer_timeout.bind(owner_node)):
				timer.timeout.disconnect(_on_timer_timeout.bind(owner_node))
			if owner_node and is_instance_valid(owner_node):
				owner_node.remove_child(timer)
			timer.queue_free()

		_signal_connections.erase(owner_id)

	# 🔧 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("current_repeat_count", 0)
		_runtime_instance_ref.set_runtime_state("is_running", false)
		_runtime_instance_ref.set_runtime_state("is_completed", false)
		_runtime_instance_ref.set_runtime_state("last_input_time", 0.0)

	_owner_node_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 当节点进入场景树时
func _on_tree_entered(owner_node: Node):
	if auto_start:
		_start_interval(owner_node)
	else:
		_create_timer(owner_node)

## 创建定时器（不自动启动）
func _create_timer(owner_node: Node):
	if not owner_node:
		return

	var owner_id = owner_node.get_instance_id()

	# 清理旧的 timer
	_cleanup_timer(owner_node)

	# 创建新的 timer
	var timer = Timer.new()
	timer.wait_time = _get_next_interval()
	timer.one_shot = use_random_interval  # 随机间隔模式下使用 one_shot，每次手动设置新间隔
	timer.timeout.connect(_on_timer_timeout.bind(owner_node))
	owner_node.add_child(timer)

	# 保存连接信息
	_signal_connections[owner_id] = {
		"timer": timer,
		"owner": owner_node
	}

	# 🔧 初始化 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("current_repeat_count", 0)
		_runtime_instance_ref.set_runtime_state("is_completed", false)

## 开始间隔执行
func _start_interval(owner_node: Node):
	if not owner_node:
		return

	_create_timer(owner_node)

	var owner_id = owner_node.get_instance_id()
	if _signal_connections.has(owner_id):
		var conn_info = _signal_connections[owner_id]
		var timer = conn_info.get("timer")

		if timer:
			timer.start()

			# 🔧 使用 RuntimeEventInstance 的状态
			if _runtime_instance_ref:
				_runtime_instance_ref.set_runtime_state("is_running", true)

			_log_debug_localized("FUSE_LOG_EVENT_INTERVAL_STARTED", {"interval_seconds": interval_seconds, "max_repeats": max_repeats})

			# 如果启用 trigger_on_start，使用 call_deferred 延迟触发
			# 这样可以确保 ActionRunner 已经准备好处理指令
			if trigger_on_start:
				_log_debug("trigger_on_start 已启用，将在下一帧触发一次")
				_on_timer_timeout.call_deferred(owner_node)
			else:
				_log_debug("trigger_on_start 未启用，将等待 %s 秒后首次触发" % interval_seconds)

## 获取下一次间隔时间
## 如果使用随机间隔，返回 min_interval_seconds 和 max_interval_seconds 之间的随机值
## 否则返回固定的 interval_seconds
func _get_next_interval() -> float:
	if use_random_interval:
		return randf_range(min_interval_seconds, max_interval_seconds)
	return interval_seconds

## 清理定时器
func _cleanup_timer(owner_node: Node):
	if not owner_node:
		return

	var owner_id = owner_node.get_instance_id()

	if _signal_connections.has(owner_id):
		var conn_info = _signal_connections[owner_id]
		var timer = conn_info.get("timer")

		if timer and is_instance_valid(timer):
			timer.stop()

			if timer.timeout.is_connected(_on_timer_timeout.bind(owner_node)):
				timer.timeout.disconnect(_on_timer_timeout.bind(owner_node))

			if owner_node and is_instance_valid(owner_node):
				owner_node.remove_child(timer)

			timer.queue_free()

		_signal_connections.erase(owner_id)

## 定时器超时回调
func _on_timer_timeout(owner_node: Node):
	# 🔧 使用 RuntimeEventInstance 的状态
	var current_repeat_count = 0
	var is_running = false
	var is_completed = false

	if _runtime_instance_ref:
		current_repeat_count = _runtime_instance_ref.runtime_state.get("current_repeat_count", 0)
		is_running = _runtime_instance_ref.runtime_state.get("is_running", false)
		is_completed = _runtime_instance_ref.runtime_state.get("is_completed", false)

	# 检查是否达到最大重复次数
	if max_repeats > 0 and current_repeat_count >= max_repeats:
		# 停止定时器
		_cleanup_timer(owner_node)

		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("is_running", false)
			_runtime_instance_ref.set_runtime_state("is_completed", true)

		_log_debug_localized("FUSE_LOG_EVENT_INTERVAL_MAX_REACHED", {"max_repeats": max_repeats})

		# 通知事件停止
		notify_stopped(STOP_REASON_MAX_REPEATS, {
			"repeat_count": current_repeat_count,
			"max_repeats": max_repeats
		})
		return

	# 递增计数
	current_repeat_count += 1
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("current_repeat_count", current_repeat_count)

	# 检查停止条件
	if stop_condition and _check_stop_condition(owner_node):
		# 停止定时器
		_cleanup_timer(owner_node)

		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("is_running", false)
			_runtime_instance_ref.set_runtime_state("is_completed", true)

		_log_info_localized("FUSE_LOG_EVENT_INTERVAL_STOP_CONDITION_MET", {
			"repeat_count": current_repeat_count,
			"condition": stop_condition.get_description() if stop_condition else "unknown"
		})

		# 通知事件停止
		notify_stopped(STOP_REASON_CONDITION_MET, {
			"repeat_count": current_repeat_count,
			"condition": stop_condition.get_description() if stop_condition else "unknown"
		})
		return

	# 检查是否是最后一次触发
	var is_last_trigger = false
	if max_repeats > 0 and current_repeat_count >= max_repeats:
		is_last_trigger = true

		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("is_running", false)
			_runtime_instance_ref.set_runtime_state("is_completed", true)

		var owner_id = owner_node.get_instance_id()
		if _signal_connections.has(owner_id):
			var conn_info = _signal_connections[owner_id]
			var timer = conn_info.get("timer")
			if timer:
				timer.stop()

	_log_info_localized("FUSE_LOG_EVENT_INTERVAL_TRIGGERED", {
		"count": current_repeat_count,
		"interval_seconds": interval_seconds
	})

	# 更新触发统计
	if _runtime_instance_ref:
		_runtime_instance_ref.update_trigger_stats()

	# 创建上下文节点传递事件信息
	var context_node = Node.new()
	context_node.name = "IntervalContext"

	if emit_repeat_count:
		context_node.set_meta("repeat_count", current_repeat_count)

	context_node.set_meta("max_repeats", max_repeats)
	context_node.set_meta("is_completed", is_last_trigger)
	context_node.set_meta("is_last_trigger", is_last_trigger)
	context_node.set_meta("trigger", owner_node)  # 🔧 设置正确的 trigger

	triggered.emit(context_node)

	# 清理上下文节点
	context_node.queue_free()

	# 🔧 如果使用随机间隔且不是最后一次触发，更新下一次间隔时间
	if use_random_interval and not is_last_trigger:
		var owner_id = owner_node.get_instance_id()
		if _signal_connections.has(owner_id):
			var conn_info = _signal_connections[owner_id]
			var timer = conn_info.get("timer")
			if timer and is_instance_valid(timer):
				var next_interval = _get_next_interval()
				timer.wait_time = next_interval
				timer.start()
				_log_debug_localized("FUSE_LOG_EVENT_INTERVAL_RANDOM_NEXT", {
					"next_interval": next_interval
				})

## 开始间隔执行（供外部调用）
func start_interval():
	if _owner_node_ref:
		_start_interval(_owner_node_ref)

## 停止间隔执行
func stop_interval():
	if _owner_node_ref:
		var owner_id = _owner_node_ref.get_instance_id()
		if _signal_connections.has(owner_id):
			var conn_info = _signal_connections[owner_id]
			var timer = conn_info.get("timer")

			if timer:
				timer.stop()

				if _runtime_instance_ref:
					_runtime_instance_ref.set_runtime_state("is_running", false)

				var current_repeat_count = 0
				if _runtime_instance_ref:
					current_repeat_count = _runtime_instance_ref.runtime_state.get("current_repeat_count", 0)

				_log_debug_localized("FUSE_LOG_EVENT_INTERVAL_STOPPED", {"repeat_count": current_repeat_count})

## 暂停间隔执行
func pause_interval():
	stop_interval()

## 恢复间隔执行
func resume_interval():
	if _owner_node_ref:
		var owner_id = _owner_node_ref.get_instance_id()
		if _signal_connections.has(owner_id):
			var conn_info = _signal_connections[owner_id]
			var timer = conn_info.get("timer")

			if timer:
				var is_completed = false
				if _runtime_instance_ref:
					is_completed = _runtime_instance_ref.runtime_state.get("is_completed", false)

				if not is_completed:
					timer.start()

					if _runtime_instance_ref:
						_runtime_instance_ref.set_runtime_state("is_running", true)

					var current_repeat_count = 0
					if _runtime_instance_ref:
						current_repeat_count = _runtime_instance_ref.runtime_state.get("current_repeat_count", 0)

					_log_debug_localized("FUSE_LOG_EVENT_INTERVAL_RESUMED", {"repeat_count": current_repeat_count})

## 处理输入事件（由 Trigger 调用）
func handle_input(event: InputEvent) -> void:
	# 只在有停止条件时才处理输入
	if not stop_condition:
		return

	# 检查是否是相关的输入事件
	var is_relevant_input = false

	# 检查键盘输入
	if event is InputEventKey:
		var key_event = event as InputEventKey
		if key_event.pressed:
			is_relevant_input = true
			if _runtime_instance_ref:
				_runtime_instance_ref.set_runtime_state("last_input_time", Time.get_ticks_msec() / 1000.0)
			_log_debug_localized("FUSE_LOG_EVENT_INTERVAL_INPUT_KEY_DETECTED", {"keycode": key_event.keycode})

	# 检查鼠标输入
	elif event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.pressed:
			is_relevant_input = true
			if _runtime_instance_ref:
				_runtime_instance_ref.set_runtime_state("last_input_time", Time.get_ticks_msec() / 1000.0)
			_log_debug_localized("FUSE_LOG_EVENT_INTERVAL_INPUT_MOUSE_DETECTED", {"button_index": mouse_event.button_index})

	# 检查手柄输入
	elif event is InputEventJoypadButton:
		var joy_event = event as InputEventJoypadButton
		if joy_event.pressed:
			is_relevant_input = true
			if _runtime_instance_ref:
				_runtime_instance_ref.set_runtime_state("last_input_time", Time.get_ticks_msec() / 1000.0)
			_log_debug_localized("FUSE_LOG_EVENT_INTERVAL_INPUT_JOY_DETECTED", {
				"device": joy_event.device,
				"button": joy_event.button_index
			})

## 重置间隔执行
func reset_interval():
	if _owner_node_ref:
		_cleanup_timer(_owner_node_ref)

		if auto_start:
			_start_interval(_owner_node_ref)
		else:
			_create_timer(_owner_node_ref)

	_log_debug_localized("FUSE_LOG_EVENT_INTERVAL_RESET", {"interval_seconds": interval_seconds})

## 获取当前重复次数
func get_repeat_count() -> int:
	if _runtime_instance_ref:
		return _runtime_instance_ref.runtime_state.get("current_repeat_count", 0)
	return 0

## 是否正在运行
func is_running() -> bool:
	if _runtime_instance_ref:
		return _runtime_instance_ref.runtime_state.get("is_running", false)
	return false

## 是否已完成
func is_completed() -> bool:
	if _runtime_instance_ref:
		return _runtime_instance_ref.runtime_state.get("is_completed", false)
	return false

## 检查停止条件是否满足
## returns: bool - 条件是否满足
func _check_stop_condition(owner_node: Node) -> bool:
	if not stop_condition:
		return false

	# 🔧 使用 RuntimeEventInstance 的状态
	var current_repeat_count = 0
	var last_input_time = 0.0

	if _runtime_instance_ref:
		current_repeat_count = _runtime_instance_ref.runtime_state.get("current_repeat_count", 0)
		last_input_time = _runtime_instance_ref.runtime_state.get("last_input_time", 0.0)

	# 特殊处理 CheckAnyInput 条件：检查最近是否有输入
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_last_input = current_time - last_input_time

	# 如果是 CheckAnyInput 条件，使用输入时间戳判断
	if stop_condition is CheckAnyInput:
		var threshold = interval_seconds * 2
		var has_recent_input = last_input_time > 0 and time_since_last_input < threshold

		if has_recent_input:
			_log_debug_localized("FUSE_LOG_EVENT_INTERVAL_STOP_CONDITION_MET", {
				"repeat_count": current_repeat_count,
				"condition": stop_condition.get_description()
			})
			# 重置输入时间戳，避免重复触发
			if _runtime_instance_ref:
				_runtime_instance_ref.set_runtime_state("last_input_time", 0)
			return true
		else:
			_log_debug_localized("FUSE_LOG_EVENT_INTERVAL_STOP_CONDITION_CHECK", {
				"met": false,
				"condition": stop_condition.get_description()
			})
			return false

	# 创建执行上下文用于条件检查
	var execution_context = ExecutionContext.new(owner_node, _trigger_ref)
	if execution_context.has_method("set_variable"):
		execution_context.set_variable("event_source", self)
		execution_context.set_variable("repeat_count", current_repeat_count)
		execution_context.set_variable("max_repeats", max_repeats)
		execution_context.set_variable("last_input_time", last_input_time)
		execution_context.set_variable("time_since_last_input", time_since_last_input)
		execution_context.log_level = log_level

	# 检查条件
	var condition_met = stop_condition.check(execution_context)

	if condition_met:
		_log_debug_localized("FUSE_LOG_EVENT_INTERVAL_STOP_CONDITION_MET", {
			"repeat_count": current_repeat_count,
			"condition": stop_condition.get_description()
		})
	else:
		_log_debug_localized("FUSE_LOG_EVENT_INTERVAL_STOP_CONDITION_CHECK", {
			"met": false,
			"condition": stop_condition.get_description()
		})

	return condition_met

## 获取事件描述
func get_description() -> String:
	var repeat_text_key = ""
	if max_repeats == 0:
		repeat_text_key = "FUSE_EVENT_ON_INTERVAL_REPEAT_INFINITE"
	elif max_repeats == 1:
		repeat_text_key = "FUSE_EVENT_ON_INTERVAL_ONCE"
	else:
		repeat_text_key = "FUSE_EVENT_ON_INTERVAL_REPEAT_COUNT_FORMAT"

	var repeat_text = FuseLocalization.translate(repeat_text_key)
	if max_repeats > 1:
		repeat_text = FuseLocalization.translate_format("FUSE_EVENT_ON_INTERVAL_REPEAT_COUNT_FORMAT", {"count": max_repeats})

	var auto_text_key = "FUSE_EVENT_ON_INTERVAL_AUTO_START" if auto_start else "FUSE_EVENT_ON_INTERVAL_MANUAL_START"
	var auto_text = FuseLocalization.translate(auto_text_key)

	# 构建间隔时间文本
	var interval_text = ""
	if use_random_interval:
		interval_text = FuseLocalization.translate_format("FUSE_EVENT_ON_INTERVAL_RANDOM_RANGE", {
			"min": str(min_interval_seconds),
			"max": str(max_interval_seconds)
		})
	else:
		interval_text = str(interval_seconds)

	var desc = FuseLocalization.translate_format("FUSE_EVENT_ON_INTERVAL_DESC", {
		"interval": interval_text,
		"repeat": repeat_text,
		"auto": auto_text
	})

	# 添加停止条件信息
	if stop_condition:
		desc += "\n" + FuseLocalization.translate_format("FUSE_EVENT_ON_INTERVAL_STOP_CONDITION_DESC", {
			"condition": stop_condition.get_description()
		})

	return desc

## 获取事件类型
func get_event_type() -> String:
	return "interval"

## 获取事件分类
func get_event_category() -> String:
	return "timer"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	# 验证固定间隔
	if not use_random_interval and interval_seconds <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_INTERVAL_SECONDS_INVALID"))

	# 验证随机区间
	if use_random_interval:
		if min_interval_seconds <= 0:
			errors.append(FuseLocalization.translate("FUSE_ERROR_MIN_INTERVAL_SECONDS_INVALID"))
		if max_interval_seconds <= 0:
			errors.append(FuseLocalization.translate("FUSE_ERROR_MAX_INTERVAL_SECONDS_INVALID"))
		if min_interval_seconds > max_interval_seconds:
			errors.append(FuseLocalization.translate("FUSE_ERROR_INTERVAL_RANGE_INVALID"))

	if max_repeats < 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_MAX_REPEATS_INVALID"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()

	# 🔧 重置 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("current_repeat_count", 0)
		_runtime_instance_ref.set_runtime_state("is_running", false)
		_runtime_instance_ref.set_runtime_state("is_completed", false)
		_runtime_instance_ref.set_runtime_state("last_input_time", 0.0)

	reset_interval()
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["current_repeat_count"] = 0
	base["is_running"] = false
	base["is_completed"] = false
	base["last_input_time"] = 0.0
	return base

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_INTERVAL_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_LIFECYCLE"
	metadata.description_key = "FUSE_EVENT_ON_INTERVAL_DESC"
	metadata.keywords = ["interval", "间隔", "timer", "定时器", "repeat", "重复", "schedule", "调度", "periodic", "周期", "frequency", "频率"]
	metadata.builtin_icon = "Timer"
	return metadata
