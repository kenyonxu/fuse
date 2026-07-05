# 文件：addons/fuse/core/trigger.gd
@tool
@icon("res://addons/fuse/icons/builtin/Signal.svg")
class_name Trigger extends BaseTrigger

## Trigger - 单事件触发器
##
## 监听单个事件并在触发时执行动作。
## 继承自 BaseTrigger，复用公共功能。

## ==================== 导出属性 ====================


## 1. 在这里选择要监听的 "事件" 资源
@export var event_definition: BaseEvent

## 2. 在这里选择事件触发时要执行的 "动作" 资源
@export var action_runner: ActionRunner

@export_group("Configuration")
## 3. (关键) 是否只触发一次？
@export var trigger_once: bool = false

## 冷却模式
@export var cooldown_mode: CooldownMode = CooldownMode.NONE

## 冷却时间（秒）- 在 cooldown_mode 不为 NONE 时生效
@export_range(0.0, 60.0, 0.1) var cooldown_time: float = 1.0

## ==================== 内部状态 ====================

var has_triggered: bool = false
var _signal_connected: bool = false
var _runtime_event_instance: RuntimeEventInstance = null
var _runtime_action_runner_instance: RuntimeActionRunnerInstance = null
var _action_runner_signals_connected: bool = false

## ==================== 抽象方法实现 ====================

func get_event_count() -> int:
	return 1 if event_definition != null else 0

func get_event_at(index: int) -> BaseEvent:
	return event_definition if index == 0 else null

func get_runtime_event_instance_at(index: int) -> RuntimeEventInstance:
	return _runtime_event_instance if index == 0 else null

func get_action_runner_instance_at(index: int) -> RuntimeActionRunnerInstance:
	return _runtime_action_runner_instance if index == 0 else null

func _on_pool_reset() -> void:
	# Trigger 特定的池化重置逻辑
	reset()
	_disable_processing()

	if event_definition:
		# 🔧 修复：在调用 terminate() 之前设置正确的 _runtime_instance_ref
		# 这解决了多个池化对象共享同一个 Event 资源时的状态覆盖问题
		# 所有 Event 子类的 terminate() 方法内部都通过 get_runtime_state() 访问状态
		# 而 get_runtime_state() 会优先使用传入参数，回退到 _runtime_instance_ref
		# 通过预先设置正确的引用，确保 terminate() 操作正确的运行时实例
		event_definition._runtime_instance_ref = _runtime_event_instance
		event_definition.terminate(self)

		if _runtime_event_instance:
			_runtime_event_instance.cleanup()

		if _runtime_action_runner_instance:
			_runtime_action_runner_instance.cleanup()

		_runtime_event_instance = RuntimeEventInstance.new(event_definition, self)
		event_definition.initialize_with_runtime_instance(self, _runtime_event_instance)

		if action_runner:
			_runtime_action_runner_instance = RuntimeActionRunnerInstance.new(action_runner, self)

		# 重新连接 triggered 信号
		if _runtime_event_instance.has_signal("triggered"):
			if _runtime_event_instance.triggered.is_connected(_on_event_fired):
				_runtime_event_instance.triggered.disconnect(_on_event_fired)
			_runtime_event_instance.triggered.connect(_on_event_fired)
			_signal_connected = true

	_enable_processing()
	_log_debug_localized("FUSE_LOG_TRIGGER_POOL_RESET")

## ==================== 生命周期钩子 ====================

func _on_trigger_ready() -> void:
	if not event_definition:
		_log_warning_localized("FUSE_ERROR_EVENT_DEFINITION_NOT_CONFIGURED")
		_create_fuse_error_localized("FUSE_ERROR_EVENT_DEFINITION_NOT_CONFIGURED", FuseError.ErrorType.CONFIGURATION_ERROR)
		return

	# 创建运行时事件实例
	_runtime_event_instance = RuntimeEventInstance.new(event_definition, self)
	event_definition.initialize_with_runtime_instance(self, _runtime_event_instance)

	# 创建 ActionRunner 运行时实例
	if action_runner:
		_runtime_action_runner_instance = RuntimeActionRunnerInstance.new(action_runner, self)
		# Phase 2.5 优化：启用批量信号模式以减少高频触发的信号开销
		_runtime_action_runner_instance.set_batch_signal_mode(true)
		_log_debug("RuntimeActionRunnerInstance 创建完成")

	# 连接 triggered 信号
	if not _signal_connected and _runtime_event_instance:
		if _runtime_event_instance.triggered.is_connected(_on_event_fired):
			_runtime_event_instance.triggered.disconnect(_on_event_fired)
		_runtime_event_instance.triggered.connect(_on_event_fired)
		_signal_connected = true

	# 连接 ActionRunner 信号
	_connect_action_runner_signals()

	_log_debug_localized("FUSE_LOG_TRIGGER_INITIALIZED", {"description": get_description()})

func _on_trigger_exit_tree() -> void:
	# 断开事件信号
	if _signal_connected and _runtime_event_instance and _runtime_event_instance.triggered.is_connected(_on_event_fired):
		if event_definition:
			event_definition.terminate(self)
		_runtime_event_instance.triggered.disconnect(_on_event_fired)
		_signal_connected = false
		_log_debug_localized("FUSE_LOG_TRIGGER_CLEANUP_COMPLETE", {"name": name})

	# 断开 ActionRunner 信号
	_disconnect_action_runner_signals()

	# 清理运行时实例
	if _runtime_event_instance:
		_runtime_event_instance.cleanup()
		_runtime_event_instance = null
		_log_debug_localized("FUSE_LOG_RUNTIME_EVENT_CLEANUP")

	if _runtime_action_runner_instance:
		_runtime_action_runner_instance.cleanup()
		_runtime_action_runner_instance = null
		_log_debug_localized("FUSE_LOG_RUNTIME_ACTION_RUNNER_CLEANUP")

## ==================== 事件处理 ====================

func _on_event_fired(context: Node) -> void:
	if trigger_once and has_triggered:
		_log_debug_localized("FUSE_LOG_TRIGGER_ALREADY_FIRED")
		return

	# 检查 ActionRunner 是否正在运行
	if _runtime_action_runner_instance and _runtime_action_runner_instance.is_running():
		_log_debug("ActionRunner 正在运行，跳过重复触发")
		return

	# 冷却检查 - 使用基类方法，参数顺序：index, context, cooldown_mode, cooldown_time
	if not _check_cooldown(0, context, cooldown_mode, cooldown_time):
		return

	has_triggered = true

	if action_runner:
		_log_debug_localized("FUSE_LOG_TRIGGER_FIRED", {"description": get_description()})

		# 添加执行模式调试信息
		if action_runner.has_method("get_execution_status"):
			var status = action_runner.get_execution_status()
			if status.has("execution_mode"):
				_log_debug_localized("FUSE_LOG_ACTION_RUNNER_EXECUTION_MODE", {"mode": status["execution_mode"]})
		else:
			_log_debug_localized("FUSE_LOG_ACTION_RUNNER_EXECUTION_MODE", {"mode": ActionRunner.ExecutionMode.keys()[action_runner.execution_mode]})

		# 创建执行上下文 - 使用基类方法，参数顺序：target, index
		var execution_context = _create_execution_context(context, 0)

		# 从 RuntimeEventInstance 中读取事件数据
		if _runtime_event_instance and _runtime_event_instance.runtime_state.has("input_vector"):
			var input_vector = _runtime_event_instance.runtime_state["input_vector"]
			execution_context.set_variable("input_vector", input_vector)
			_log_debug("Trigger: 从 RuntimeEventInstance 读取 input_vector: " + str(input_vector))

		# 同步额外事件参数
		_sync_additional_event_args(execution_context)

		# 执行 ActionRunner
		if _runtime_action_runner_instance:
			_runtime_action_runner_instance.run(execution_context)
		else:
			_log_error_localized("FUSE_ERROR_TRIGGER_NO_ACTION_RUNNER_INSTANCE")
	else:
		_log_warning_localized("FUSE_ERROR_TRIGGER_NO_ACTION_RUNNER")
		_create_fuse_error_localized("FUSE_ERROR_TRIGGER_NO_ACTION_RUNNER", FuseError.ErrorType.CONFIGURATION_ERROR)

## 同步额外的事件参数
func _sync_additional_event_args(execution_context: RefCounted) -> void:
	if not _runtime_event_instance:
		return

	var event_state = _runtime_event_instance.runtime_state

	# 同步 last_event_args 中的参数
	if event_state.has("last_event_args"):
		var event_args = event_state["last_event_args"]
		if event_args is Dictionary:
			for key in event_args:
				var var_name = "event_" + key
				execution_context.set_variable(var_name, event_args[key])
				_log_debug("Trigger: 同步事件参数到 ExecutionContext: %s = %s" % [var_name, event_args[key]])

	# 同步其他以 event_ 开头的运行时状态
	for key in event_state:
		if key.begins_with("event_") and key != "event_source":
			execution_context.set_variable(key, event_state[key])
			_log_debug("Trigger: 同步事件状态到 ExecutionContext: %s = %s" % [key, event_state[key]])

## ==================== ActionRunner 信号管理 ====================

func _connect_action_runner_signals() -> void:
	if not _runtime_action_runner_instance or _action_runner_signals_connected:
		return

	var callbacks := {
		"completed": _on_action_runner_completed,
		"failed": _on_action_runner_failed,
		"canceled": _on_action_runner_canceled
	}

	_connect_action_runner_signals_at(0, callbacks)
	_action_runner_signals_connected = true

func _disconnect_action_runner_signals() -> void:
	if not _runtime_action_runner_instance or not _action_runner_signals_connected:
		return

	var callbacks := {
		"completed": _on_action_runner_completed,
		"failed": _on_action_runner_failed,
		"canceled": _on_action_runner_canceled
	}

	_disconnect_action_runner_signals_at(0, callbacks)
	_action_runner_signals_connected = false

## ActionRunner 完成回调
func _on_action_runner_completed(total_time: float) -> void:
	_log_debug_localized("FUSE_LOG_ACTION_RUNNER_COMPLETED")
	var context = {
		"type": "action_runner_completed",
		"trigger": self,
		"total_time": total_time
	}
	event_completed.emit(context)

## ActionRunner 失败回调
func _on_action_runner_failed(error_message: String) -> void:
	_log_debug_localized("FUSE_LOG_ACTION_RUNNER_FAILED", {"error": error_message})
	var context = {
		"type": "action_runner_failed",
		"error": error_message,
		"trigger": self
	}
	event_stopped.emit("execution_failed", context)

## ActionRunner 取消回调
func _on_action_runner_canceled(reason: String) -> void:
	_log_debug_localized("FUSE_LOG_ACTION_RUNNER_CANCELED", {"reason": reason})
	var context = {
		"type": "action_runner_canceled",
		"reason": reason,
		"trigger": self
	}
	event_stopped.emit("execution_canceled", context)

## ==================== 公共方法 ====================

## 获取触发器描述
func get_description() -> String:
	var description = ""

	if event_definition:
		description = "Trigger: %s" % event_definition.get_description()
	else:
		description = FuseLocalization.translate("FUSE_TRIGGER_NO_EVENT")

	# 添加冷却信息
	if cooldown_mode != CooldownMode.NONE:
		var mode_text = ""
		match cooldown_mode:
			CooldownMode.GLOBAL_COOLDOWN:
				mode_text = "全局冷却"
			CooldownMode.PER_OBJECT_COOLDOWN:
				mode_text = "每物体冷却"
		description += " [%s %.1fs]" % [mode_text, cooldown_time]

	return description

## 重置触发器状态
func reset() -> void:
	has_triggered = false
	_fuse_error = null

	# 清理冷却状态
	_clear_cooldown_state(0)

	if event_definition:
		event_definition.reset()
	_log_debug_localized("FUSE_LOG_TRIGGER_STATE_RESET")

## 验证触发器配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if not event_definition:
		var error_msg = FuseLocalization.translate("FUSE_ERROR_EVENT_DEFINITION_NOT_SPECIFIED")
		errors.append(error_msg)
		_create_fuse_error_localized("FUSE_ERROR_EVENT_DEFINITION_NOT_SPECIFIED", FuseError.ErrorType.CONFIGURATION_ERROR)

	if not action_runner:
		var error_msg = FuseLocalization.translate("FUSE_ERROR_ACTION_RUNNER_NOT_SPECIFIED")
		errors.append(error_msg)
		_create_fuse_error_localized("FUSE_ERROR_ACTION_RUNNER_NOT_SPECIFIED", FuseError.ErrorType.CONFIGURATION_ERROR)

	if event_definition:
		errors.append_array(event_definition.validate())

	# 检查 action_runner 是否有 run 方法
	if action_runner and not action_runner.has_method("run"):
		var error_msg = FuseLocalization.translate_format("FUSE_ERROR_ACTION_RUNNER_NO_RUN_METHOD", {"runner": str(action_runner)})
		errors.append(error_msg)
		_create_fuse_error_localized("FUSE_ERROR_ACTION_RUNNER_NO_RUN_METHOD", FuseError.ErrorType.CONFIGURATION_ERROR, {}, {"runner": str(action_runner)})

	return errors

## 手动触发触发器
func trigger_manually(context: Node = null) -> void:
	_log_debug_localized("FUSE_LOG_TRIGGER_MANUAL_TRIGGER")
	_on_event_fired(context)
