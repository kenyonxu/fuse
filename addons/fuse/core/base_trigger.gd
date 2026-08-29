# 文件：addons/fuse/core/base_trigger.gd
@tool
@abstract
class_name BaseTrigger extends Node
## BaseTrigger - 触发器抽象基类
##
## 提供触发器的公共功能：
## - 冷却检查逻辑
## - 执行上下文创建
## - 事件参数同步
## - 引擎回调转发
## - 日志和错误处理
##
## 子类需要实现抽象方法来提供具体的事件/动作管理。

## ==================== 枚举 ====================

## 冷却模式：控制事件触发的频率
enum CooldownMode {
	NONE,               ## 无冷却，每次都触发
	GLOBAL_COOLDOWN,    ## 全局冷却：触发后所有物体都需要等待
	PER_OBJECT_COOLDOWN ## 每物体独立冷却：每个物体有自己的冷却计时器
}

## ==================== 信号 ====================

## 事件执行完成的信号（子类可定义自己的完成信号）
signal event_completed(context: Dictionary)

## 事件停止的信号（当事件停止时发出）
signal event_stopped(reason: String, context: Dictionary)

## ==================== 导出属性 ====================

@export_group("Configuration")

## 池化模式：首次创建时不初始化，等待 pool_reset
@export var pool_mode: bool = false

## 日志级别
@export var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.NONE

## ==================== 内部状态 ====================

var _fuse_error: FuseError = null

## ==================== 抽象方法 ====================
## 子类必须实现这些方法

## 获取事件数量
@abstract func get_event_count() -> int

## 获取指定索引的事件定义
@abstract func get_event_at(index: int) -> BaseEvent

## 获取指定索引的运行时事件实例
@abstract func get_runtime_event_instance_at(index: int) -> RuntimeEventInstance

## 获取指定索引的运行时 ActionRunner 实例
@abstract func get_action_runner_instance_at(index: int) -> RuntimeActionRunnerInstance

## 池化重置的子类实现
@abstract func _on_pool_reset() -> void

## ==================== 可选覆盖方法 ====================

## 获取触发器描述（子类可覆盖）
func get_description() -> String:
	return "BaseTrigger"

## ==================== 生命周期 ====================

func _ready() -> void:
	if Engine.is_editor_hint():
		_log_debug_localized("FUSE_LOG_TRIGGER_EDITOR_MODE_SKIPPED")
		return

	if pool_mode:
		_log_debug("池化模式，跳过首次初始化")
		return

	_on_trigger_ready()

func _exit_tree() -> void:
	_on_trigger_exit_tree()

## 子类可覆盖的初始化钩子
func _on_trigger_ready() -> void:
	pass

## 子类可覆盖的退出钩子
func _on_trigger_exit_tree() -> void:
	pass

## 重置触发器状态（子类可覆盖）
func reset() -> void:
	_fuse_error = null

## 验证触发器配置（子类可覆盖）
func validate() -> Array[String]:
	var errors: Array[String] = []
	return errors

## 手动触发触发器（子类可覆盖）
## 默认实现无效果；若子类未覆盖则发出 warning 提示。
func trigger_manually(context: Node = null) -> void:
	push_warning("BaseTrigger.trigger_manually 未在子类覆盖，调用无效果")

## ==================== 冷却检查 ====================

## object_cooldowns 过期阈值倍数：
## 当 (current_time - last_time) > cooldown_time * 此倍数 时，条目视为过期可清理。
## 4.0 = cooldown 期 + 3 倍宽限（足够长的保留窗口避免抖动）。
const _OBJECT_COOLDOWN_TTL_MULTIPLIER: float = 4.0

## object_cooldowns 清理触发阈值（摊销策略）：
## 仅在字典大小 >= 此值时才执行 O(n) 扫描清理；小字典跳过避免每次调用都扫描。
const _OBJECT_COOLDOWN_CLEANUP_THRESHOLD: int = 8

## 检查冷却状态
## 返回 true 表示可以触发，false 表示冷却中
func _check_cooldown(index: int, context: Node, cooldown_mode: CooldownMode, cooldown_time: float) -> bool:
	if cooldown_mode == CooldownMode.NONE or cooldown_time <= 0.0:
		return true

	var event_instance := get_runtime_event_instance_at(index)
	if event_instance == null:
		return true

	var current_time := Time.get_ticks_msec() / 1000.0

	match cooldown_mode:
		CooldownMode.GLOBAL_COOLDOWN:
			var last_time: float = event_instance.runtime_state.get("last_trigger_time", 0.0)
			if current_time - last_time < cooldown_time:
				_log_debug("全局冷却中：已过 %.2f 秒，需要 %.2f 秒" % [current_time - last_time, cooldown_time])
				return false
			event_instance.runtime_state["last_trigger_time"] = current_time

		CooldownMode.PER_OBJECT_COOLDOWN:
			var object_cooldowns: Dictionary = event_instance.runtime_state.get("object_cooldowns", {})
			# B12: 清理过期 object_cooldowns 条目，防止长时间运行（物体频繁进出）下字典无限增长。
			# 阈值 = cooldown_time * _OBJECT_COOLDOWN_TTL_MULTIPLIER。
			# 在字典较小时跳过扫描以避免开销；达到阈值后才执行清理。
			_cleanup_expired_object_cooldowns(object_cooldowns, current_time, cooldown_time)
			var object_id: int = context.get_instance_id() if context != null else 0
			if object_id != 0 and object_cooldowns.has(object_id):
				var last_time: float = object_cooldowns[object_id]
				if current_time - last_time < cooldown_time:
					var object_name: String = context.name if context != null else "unknown"
					_log_debug("物体 '%s' (ID:%d) 冷却中" % [object_name, object_id])
					return false
			object_cooldowns[object_id] = current_time
			event_instance.runtime_state["object_cooldowns"] = object_cooldowns

	return true

## 清理 object_cooldowns 中过期的条目。
## 过期条件：current_time - last_time > cooldown_time * _OBJECT_COOLDOWN_TTL_MULTIPLIER
func _cleanup_expired_object_cooldowns(object_cooldowns: Dictionary, current_time: float, cooldown_time: float) -> void:
	if object_cooldowns.size() < _OBJECT_COOLDOWN_CLEANUP_THRESHOLD:
		return
	var ttl: float = cooldown_time * _OBJECT_COOLDOWN_TTL_MULTIPLIER
	var expired_keys: Array = []
	for key: int in object_cooldowns:
		var last_time: float = object_cooldowns[key]
		if current_time - last_time > ttl:
			expired_keys.append(key)
	for key: int in expired_keys:
		object_cooldowns.erase(key)
	if not expired_keys.is_empty():
		_log_debug("清理过期 object_cooldowns：删除 %d 条，剩余 %d 条" % [expired_keys.size(), object_cooldowns.size()])

## 清理冷却状态
func _clear_cooldown_state(index: int) -> void:
	var event_instance := get_runtime_event_instance_at(index)
	if event_instance != null:
		event_instance.runtime_state.erase("last_trigger_time")
		event_instance.runtime_state.erase("object_cooldowns")

## ==================== 执行上下文 ====================

## 创建执行上下文
func _create_execution_context(target: Node, index: int = 0) -> ExecutionContext:
	var context := ExecutionContext.new(target, self)
	context.set_variable("event_source", self)
	context.set_variable("triggered_node", target)
	context.log_level = log_level

	# 从 target meta 读取 delta_time
	if target != null and target.has_meta("delta_time"):
		context.delta_time = target.get_meta("delta_time")
		_log_debug("从 target meta 读取 delta_time: " + str(context.delta_time))

	# 同步 RuntimeEventInstance 中的事件参数
	_sync_event_args_to_context(context, index)

	return context

## 同步事件参数到 ExecutionContext
func _sync_event_args_to_context(context: ExecutionContext, index: int) -> void:
	var event_instance := get_runtime_event_instance_at(index)
	if event_instance == null:
		return

	var event_state: Dictionary = event_instance.runtime_state

	# 同步 last_event_args
	if event_state.has("last_event_args"):
		var event_args: Variant = event_state["last_event_args"]
		if event_args is Dictionary:
			for key: String in event_args:
				var var_name := "event_" + key
				context.set_variable(var_name, event_args[key])
				_log_debug("同步事件参数: %s = %s" % [var_name, str(event_args[key])])

	# 同步其他 event_ 开头的状态
	for key: String in event_state:
		if key.begins_with("event_") and key != "event_source":
			context.set_variable(key, event_state[key])
			_log_debug("同步事件状态: %s = %s" % [key, str(event_state[key])])

	# 同步事件显式提供的 LOCAL 变量——兑现 BaseEvent.get_provided_local_variables() 声明
	# （如 OnInputActionComposite 的 input_vector/last_input_vector，指令按声明名直接读取）
	var event_def: BaseEvent = event_instance.event_definition
	if event_def != null:
		for var_name: String in event_def.get_provided_local_variables():
			if event_state.has(var_name):
				context.set_variable(var_name, event_state[var_name])
				_log_debug("同步事件提供变量: %s = %s" % [var_name, str(event_state[var_name])])

## ==================== ActionRunner 信号管理 ====================

## 连接 ActionRunner 信号
## callbacks: { "completed": callable, "failed": callable, "canceled": callable }
func _connect_action_runner_signals_at(index: int, callbacks: Dictionary) -> bool:
	var action_instance := get_action_runner_instance_at(index)
	if action_instance == null:
		return false

	var connected := false

	if action_instance.has_signal("execution_completed") and callbacks.has("completed"):
		var cb: Callable = callbacks["completed"]
		if not action_instance.execution_completed.is_connected(cb):
			action_instance.execution_completed.connect(cb)
			connected = true

	if action_instance.has_signal("execution_failed") and callbacks.has("failed"):
		var cb: Callable = callbacks["failed"]
		if not action_instance.execution_failed.is_connected(cb):
			action_instance.execution_failed.connect(cb)
			connected = true

	if action_instance.has_signal("execution_canceled") and callbacks.has("canceled"):
		var cb: Callable = callbacks["canceled"]
		if not action_instance.execution_canceled.is_connected(cb):
			action_instance.execution_canceled.connect(cb)
			connected = true

	return connected

## 断开 ActionRunner 信号
func _disconnect_action_runner_signals_at(index: int, callbacks: Dictionary) -> void:
	var action_instance := get_action_runner_instance_at(index)
	if action_instance == null:
		return

	if action_instance.has_signal("execution_completed") and callbacks.has("completed"):
		var cb: Callable = callbacks["completed"]
		if action_instance.execution_completed.is_connected(cb):
			action_instance.execution_completed.disconnect(cb)

	if action_instance.has_signal("execution_failed") and callbacks.has("failed"):
		var cb: Callable = callbacks["failed"]
		if action_instance.execution_failed.is_connected(cb):
			action_instance.execution_failed.disconnect(cb)

	if action_instance.has_signal("execution_canceled") and callbacks.has("canceled"):
		var cb: Callable = callbacks["canceled"]
		if action_instance.execution_canceled.is_connected(cb):
			action_instance.execution_canceled.disconnect(cb)

## ==================== 引擎回调转发 ====================

## 绑定是否仍应接收引擎回调（输入/帧/物理通知）
## L4 子类按 binding.enabled 与 trigger_once 已触发状态过滤——
## disabled 或一次性触发完毕的事件不再处理输入，触发日志随之静默
func _is_binding_active(index: int) -> bool:
	return true

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	for i: int in range(get_event_count()):
		if not _is_binding_active(i):
			continue
		var event := get_event_at(i)
		if event != null and event.has_method("on_process"):
			var event_instance := get_runtime_event_instance_at(i)
			event.on_process(delta, event_instance)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	for i: int in range(get_event_count()):
		if not _is_binding_active(i):
			continue
		var event := get_event_at(i)
		if event != null and event.has_method("on_physics_process"):
			var event_instance := get_runtime_event_instance_at(i)
			event.on_physics_process(delta, event_instance)

func _notification(what: int) -> void:
	if Engine.is_editor_hint():
		return

	if what == NOTIFICATION_PROCESS or what == NOTIFICATION_PHYSICS_PROCESS:
		for i: int in range(get_event_count()):
			if not _is_binding_active(i):
				continue
			var event := get_event_at(i)
			if event == null:
				continue

			if what == NOTIFICATION_PROCESS:
				if event.has_method("handle_process_notification"):
					event.handle_process_notification()
			elif what == NOTIFICATION_PHYSICS_PROCESS:
				if event.has_method("handle_physics_process_notification"):
					event.handle_physics_process_notification()

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return

	for i: int in range(get_event_count()):
		if not _is_binding_active(i):
			continue
		var evt := get_event_at(i)
		if evt != null and evt.has_method("handle_input"):
			evt.handle_input(event)

## ==================== 池化支持 ====================

## 对象池复用时的完整重置
func pool_reset() -> void:
	_on_pool_reset()

## 禁用处理
func _disable_processing() -> void:
	set_physics_process(false)
	set_process(false)

## 启用处理
func _enable_processing() -> void:
	set_physics_process(true)
	set_process(true)

## ==================== 错误处理 ====================

## 创建 FuseError 实例
func _create_fuse_error(message: String, error_type: FuseError.ErrorType = FuseError.ErrorType.RUNTIME_ERROR, context: Dictionary = {}):
	var error_context = context.duplicate()
	error_context["trigger_name"] = name
	_fuse_error = FuseError.create_with_context(error_type, "Trigger", message, error_context)

## 创建本地化的 FuseError 实例
func _create_fuse_error_localized(message_key: String, error_type: FuseError.ErrorType = FuseError.ErrorType.RUNTIME_ERROR, context: Dictionary = {}, args: Dictionary = {}):
	var message = FuseLocalization.translate_format(message_key, args)
	_create_fuse_error(message, error_type, context)

## 获取 FuseError 实例
func get_fuse_error() -> FuseError:
	return _fuse_error

## 检查是否有 FuseError
func has_fuse_error() -> bool:
	return _fuse_error != null

## ==================== 日志方法 ====================

func _log_debug(message: String) -> void:
	FuseLogger.log_debug("Trigger", log_level, message, name)

func _log_info(message: String) -> void:
	FuseLogger.log_info("Trigger", log_level, message, name)

func _log_warning(message: String) -> void:
	FuseLogger.log_warning("Trigger", log_level, message, name)

func _log_error(message: String) -> void:
	FuseLogger.log_error("Trigger", log_level, message, name)

func _log_debug_localized(message_key: String, args: Dictionary = {}) -> void:
	FuseLogger.log_debug_localized("Trigger", log_level, message_key, args)

func _log_info_localized(message_key: String, args: Dictionary = {}) -> void:
	FuseLogger.log_info_localized("Trigger", log_level, message_key, args)

func _log_warning_localized(message_key: String, args: Dictionary = {}) -> void:
	FuseLogger.log_warning_localized("Trigger", log_level, message_key, args)

func _log_error_localized(message_key: String, args: Dictionary = {}) -> void:
	FuseLogger.log_error_localized("Trigger", log_level, message_key, args)
