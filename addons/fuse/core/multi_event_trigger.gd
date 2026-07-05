# 文件：addons/fuse/core/multi_event_trigger.gd
@tool
@icon("res://addons/fuse/icons/builtin/Signal.svg")
class_name MultiEventTrigger extends BaseTrigger

## MultiEventTrigger - 多事件触发器
##
## 将多个 Trigger 的功能合并到一个节点中，
## 减少节点数量，提升性能。
##
## 使用 EventBinding 数组配置多个事件-动作绑定。
## 继承自 BaseTrigger，复用公共功能。

## ==================== 信号 ====================

## 重写基类信号，添加 binding_index 参数
signal event_completed_with_index(binding_index: int, context: Dictionary)
signal event_stopped_with_index(binding_index: int, reason: String, context: Dictionary)

## ==================== 导出属性 ====================

@export_group("Components")

## 事件绑定列表
@export var event_bindings: Array[EventBinding] = []:
	set(value):
		event_bindings = value
		notify_property_list_changed()

## ==================== 内部状态 ====================

## 运行时事件实例（一一对应 event_bindings）
var _runtime_event_instances: Array[RuntimeEventInstance] = []

## 运行时 ActionRunner 实例（一一对应 event_bindings）
var _runtime_action_instances: Array[RuntimeActionRunnerInstance] = []

## 触发状态（一一对应 event_bindings）
var _has_triggered: Array[bool] = []

## 信号连接状态（一一对应 event_bindings）
var _signal_connected: Array[bool] = []

## ActionRunner 信号连接状态
var _action_signals_connected: Array[bool] = []
var _initialized: Array[bool] = []

## ==================== 并行条件评估 ====================

## 是否启用并行条件评估
## 启用后，条件检查将使用 WorkerThreadPool 并行执行
@export var use_parallel_condition_evaluation: bool = true

## 并行条件评估器实例
var _condition_evaluator: ParallelConditionEvaluator = null

## ==================== 抽象方法实现 ====================

func get_event_count() -> int:
	return event_bindings.size()

func get_event_at(index: int) -> BaseEvent:
	if index < 0 or index >= event_bindings.size():
		return null
	var binding: EventBinding = event_bindings[index]
	return binding.event if binding != null else null

func get_runtime_event_instance_at(index: int) -> RuntimeEventInstance:
	if index < 0 or index >= _runtime_event_instances.size():
		return null
	return _runtime_event_instances[index]

func get_action_runner_instance_at(index: int) -> RuntimeActionRunnerInstance:
	if index < 0 or index >= _runtime_action_instances.size():
		return null
	return _runtime_action_instances[index]

func _on_pool_reset() -> void:
	_disable_processing()

	# 终止并清理（_initialize_runtime_instances 内部也会调用 _cleanup_runtime_instances）
	_stop_all_events()
	_initialize_runtime_instances()
	_start_all_events()

	_enable_processing()
	_log_debug("pool_reset 完成")

## ==================== 生命周期钩子 ====================

func _on_trigger_ready() -> void:
	_initialize_parallel_evaluator()
	_initialize_runtime_instances()
	_start_all_events()
	_log_debug("MultiEventTrigger 初始化完成，共 %d 个绑定" % event_bindings.size())

func _on_trigger_exit_tree() -> void:
	_stop_all_events()
	_cleanup_runtime_instances()
	_condition_evaluator = null  # CRITICAL FIX: 清理并行条件评估器

## ==================== 初始化 ====================

## 初始化并行条件评估器
func _initialize_parallel_evaluator() -> void:
	if use_parallel_condition_evaluation:
		_condition_evaluator = ParallelConditionEvaluator.new()
		_condition_evaluator.evaluation_mode = ParallelConditionEvaluator.EvaluationMode.PARALLEL_SAFE
		_log_debug("并行条件评估器已初始化")

## 初始化运行时实例
func _initialize_runtime_instances() -> void:
	_cleanup_runtime_instances()

	for i: int in range(event_bindings.size()):
		var binding: EventBinding = event_bindings[i]

		# 初始化状态数组
		_has_triggered.append(false)
		_signal_connected.append(false)
		_action_signals_connected.append(false)
		_initialized.append(false)

		if not binding.enabled or binding.event == null:
			_runtime_event_instances.append(null)
			_runtime_action_instances.append(null)
			continue

		# 创建 RuntimeEventInstance
		var event_instance := RuntimeEventInstance.new(binding.event, self)
		binding.event.initialize_with_runtime_instance(self, event_instance)
		_runtime_event_instances.append(event_instance)

		# 创建 RuntimeActionRunnerInstance
		var action_instance: RuntimeActionRunnerInstance = null
		if binding.action_runner != null:
			action_instance = RuntimeActionRunnerInstance.new(binding.action_runner, self)
			# Phase 2.5 优化：启用批量信号模式以减少高频触发的信号开销
			action_instance.set_batch_signal_mode(true)
		_runtime_action_instances.append(action_instance)

		# 连接事件信号
		_connect_event_signals(i)
		_connect_action_signals(i)

		# 标记已初始化，防止 _start_all_events() 重复调用 initialize_with_runtime_instance
		_initialized[i] = true

	_log_debug("运行时实例初始化完成")

## 连接事件信号
func _connect_event_signals(index: int) -> void:
	if index < 0 or index >= _runtime_event_instances.size():
		return

	var event_instance: RuntimeEventInstance = _runtime_event_instances[index]
	if event_instance == null or _signal_connected[index]:
		return

	if event_instance.triggered.is_connected(_on_event_fired):
		event_instance.triggered.disconnect(_on_event_fired)

	event_instance.triggered.connect(_on_event_fired.bind(index))
	_signal_connected[index] = true
	_log_debug("Binding[%d] 事件信号已连接" % index)

## 连接 ActionRunner 信号
func _connect_action_signals(index: int) -> void:
	if index < 0 or index >= _runtime_action_instances.size():
		return

	var action_instance: RuntimeActionRunnerInstance = _runtime_action_instances[index]
	if action_instance == null or _action_signals_connected[index]:
		return

	if action_instance.has_signal("execution_completed"):
		if action_instance.execution_completed.is_connected(_on_action_completed):
			action_instance.execution_completed.disconnect(_on_action_completed)
		action_instance.execution_completed.connect(_on_action_completed.bind(index))

	if action_instance.has_signal("execution_failed"):
		if action_instance.execution_failed.is_connected(_on_action_failed):
			action_instance.execution_failed.disconnect(_on_action_failed)
		action_instance.execution_failed.connect(_on_action_failed.bind(index))

	if action_instance.has_signal("execution_canceled"):
		if action_instance.execution_canceled.is_connected(_on_action_canceled):
			action_instance.execution_canceled.disconnect(_on_action_canceled)
		action_instance.execution_canceled.connect(_on_action_canceled.bind(index))

	_action_signals_connected[index] = true
	_log_debug("Binding[%d] ActionRunner 信号已连接" % index)

## 启动所有事件监听
func _start_all_events() -> void:
	for i: int in range(_runtime_event_instances.size()):
		var event_instance: RuntimeEventInstance = _runtime_event_instances[i]
		if event_instance != null and not _initialized[i]:
			event_instance.start_listening()
			_initialized[i] = true

## 停止所有事件监听
func _stop_all_events() -> void:
	for i: int in range(_runtime_event_instances.size()):
		var event_instance: RuntimeEventInstance = _runtime_event_instances[i]
		if event_instance == null:
			continue

		# 🔧 修复：在调用 terminate() 之前设置正确的 _runtime_instance_ref
		# 这解决了多个池化对象共享同一个 Event 资源时的状态覆盖问题
		# 所有 Event 子类的 terminate() 方法内部都通过 get_runtime_state() 访问状态
		# 而 get_runtime_state() 会使用 _runtime_instance_ref 作为回退
		var binding: EventBinding = event_bindings[i]
		if binding != null and binding.event != null:
			binding.event._runtime_instance_ref = event_instance
			binding.event.terminate(self)

## 清理运行时实例
func _cleanup_runtime_instances() -> void:
	# 断开信号
	for i: int in range(_runtime_event_instances.size()):
		var event_instance: RuntimeEventInstance = _runtime_event_instances[i]
		if event_instance != null and _signal_connected[i]:
			if event_instance.triggered.is_connected(_on_event_fired):
				event_instance.triggered.disconnect(_on_event_fired)
			event_instance.cleanup()

		var action_instance: RuntimeActionRunnerInstance = _runtime_action_instances[i]
		if action_instance != null:
			action_instance.cleanup()

	_runtime_event_instances.clear()
	_runtime_action_instances.clear()
	_has_triggered.clear()
	_signal_connected.clear()
	_action_signals_connected.clear()
	_initialized.clear()

## ==================== 事件处理 ====================

## 事件触发回调
func _on_event_fired(context: Node, index: int) -> void:
	if index < 0 or index >= event_bindings.size():
		return

	var binding: EventBinding = event_bindings[index]

	# trigger_once 检查
	if binding.trigger_once and _has_triggered[index]:
		_log_debug("Binding[%d] 已触发，跳过" % index)
		return

	# ActionRunner 运行检查
	var action_instance: RuntimeActionRunnerInstance = _runtime_action_instances[index]
	if action_instance != null and action_instance.is_running():
		_log_debug("Binding[%d] ActionRunner 正在运行，跳过" % index)
		return

	# 冷却检查
	if not _check_binding_cooldown(index, context):
		_log_debug("Binding[%d] 冷却中，跳过" % index)
		return

	# 创建执行上下文（条件检查和 ActionRunner 共用）
	var execution_context := _create_execution_context(context, index)
	# MultiEventTrigger 特有：添加 binding_index 到上下文
	execution_context.set_variable("binding_index", index)

	# 条件检查（使用并行评估）
	if not binding.conditions.is_empty():
		var conditions_passed: bool = false
		if use_parallel_condition_evaluation and _condition_evaluator != null:
			conditions_passed = check_conditions_parallel(index, execution_context)
		else:
			conditions_passed = check_conditions_serial(binding, execution_context)

		if not conditions_passed:
			_log_debug("Binding[%d] 条件检查未通过，跳过" % index)
			return

	_has_triggered[index] = true

	# 执行 ActionRunner
	if action_instance != null:
		_log_debug("Binding[%d] 执行 ActionRunner" % index)
		action_instance.run(execution_context)
	else:
		_log_warning("Binding[%d] 无 ActionRunner" % index)

## 冷却检查（MultiEventTrigger 专用）
func _check_binding_cooldown(index: int, context: Node) -> bool:
	var binding: EventBinding = event_bindings[index]
	if binding.cooldown_mode == CooldownMode.NONE or binding.cooldown_time <= 0.0:
		return true

	var event_instance: RuntimeEventInstance = _runtime_event_instances[index]
	if event_instance == null:
		return true

	var current_time := Time.get_ticks_msec() / 1000.0

	match binding.cooldown_mode:
		CooldownMode.GLOBAL_COOLDOWN:
			var last_time: float = event_instance.runtime_state.get("last_trigger_time", 0.0)
			if current_time - last_time < binding.cooldown_time:
				_log_info("Binding[%d] 全局冷却中：已过 %.2f 秒，需要 %.2f 秒" % [index, current_time - last_time, binding.cooldown_time])
				return false
			event_instance.runtime_state["last_trigger_time"] = current_time

		CooldownMode.PER_OBJECT_COOLDOWN:
			var object_cooldowns: Dictionary = event_instance.runtime_state.get("object_cooldowns", {})
			var object_id: int = context.get_instance_id() if context != null else 0
			if object_id != 0 and object_cooldowns.has(object_id):
				var last_time: float = object_cooldowns[object_id]
				if current_time - last_time < binding.cooldown_time:
					var object_name: String = context.name if context != null else "unknown"
					_log_info("物体 '%s' (ID:%d) 冷却中" % [object_name, object_id])
					return false
			object_cooldowns[object_id] = current_time
			event_instance.runtime_state["object_cooldowns"] = object_cooldowns

	return true

## ==================== 条件检查 ====================

## 批量检查条件（使用并行评估）
## binding_index: int - 绑定索引
## context: ExecutionContext - 执行上下文
## 返回: bool - 所有条件是否满足
func check_conditions_parallel(binding_index: int, context: ExecutionContext) -> bool:
	if binding_index < 0 or binding_index >= event_bindings.size():
		return false

	var binding: EventBinding = event_bindings[binding_index]
	if binding == null:
		return false

	# 收集该绑定的所有条件（HIGH FIX: 过滤禁用的条件）
	var conditions: Array[BaseCondition] = []
	for condition: BaseCondition in binding.conditions:
		if condition != null and condition.enabled:
			conditions.append(condition)

	if conditions.is_empty():
		return true  # 没有条件视为满足

	# 如果没有评估器，使用串行评估
	if _condition_evaluator == null:
		return check_conditions_serial(binding, context)

	var results: Array[bool] = _condition_evaluator.evaluate_parallel(context, conditions)

	# 检查所有条件是否满足
	for result: bool in results:
		if not result:
			return false
	return true

## 串行条件检查（回退方案）
## binding: EventBinding - 事件绑定
## context: ExecutionContext - 执行上下文
## 返回: bool - 所有条件是否满足
func check_conditions_serial(binding: EventBinding, context: ExecutionContext) -> bool:
	for condition: BaseCondition in binding.conditions:
		if condition != null and condition.enabled:
			if not condition.check(context):
				return false
	return true

## ==================== ActionRunner 回调 ====================

func _on_action_completed(total_time: float, index: int) -> void:
	_log_debug("Binding[%d] ActionRunner 完成 (耗时: %.3fs)" % [index, total_time])
	var context := {
		"type": "action_runner_completed",
		"trigger": self,
		"binding_index": index
	}
	# 同时发射两个信号以保持兼容
	event_completed.emit(context)
	event_completed_with_index.emit(index, context)

func _on_action_failed(error_message: String, index: int) -> void:
	_log_debug("Binding[%d] ActionRunner 失败: %s" % [index, error_message])
	var context := {
		"type": "action_runner_failed",
		"error": error_message,
		"trigger": self,
		"binding_index": index
	}
	event_stopped.emit("execution_failed", context)
	event_stopped_with_index.emit(index, "execution_failed", context)

func _on_action_canceled(reason: String, index: int) -> void:
	_log_debug("Binding[%d] ActionRunner 取消: %s" % [index, reason])
	var context := {
		"type": "action_runner_canceled",
		"reason": reason,
		"trigger": self,
		"binding_index": index
	}
	event_stopped.emit("execution_canceled", context)
	event_stopped_with_index.emit(index, "execution_canceled", context)

## ==================== 公共方法 ====================

## 获取触发器描述
func get_description() -> String:
	var enabled_count := 0
	for binding: EventBinding in event_bindings:
		if binding.enabled:
			enabled_count += 1

	return "MultiEventTrigger: %d 绑定 (%d 启用)" % [event_bindings.size(), enabled_count]

## 重置触发器状态
func reset() -> void:
	for i: int in range(_has_triggered.size()):
		_has_triggered[i] = false

	for i: int in range(event_bindings.size()):
		var binding: EventBinding = event_bindings[i]
		if binding.event != null:
			binding.event.reset()

	# 清理冷却状态
	for event_instance: RuntimeEventInstance in _runtime_event_instances:
		if event_instance != null:
			event_instance.runtime_state.erase("last_trigger_time")
			event_instance.runtime_state.erase("object_cooldowns")

	_fuse_error = null
	_log_debug("状态已重置")

## 验证配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	for i: int in range(event_bindings.size()):
		var binding: EventBinding = event_bindings[i]

		if binding.event == null:
			var error_msg := "EventBinding[%d]: event 未配置" % i
			errors.append(error_msg)

		if binding.action_runner == null:
			var error_msg := "EventBinding[%d]: action_runner 未配置" % i
			errors.append(error_msg)

		if binding.event != null:
			var binding_errors: Array[String] = binding.event.validate()
			for error: String in binding_errors:
				errors.append("EventBinding[%d]: %s" % [i, error])

	return errors

## 手动触发指定绑定（MultiEventTrigger 专用）
func trigger_binding(index: int, context: Node = null) -> void:
	if index < 0 or index >= event_bindings.size():
		_log_warning("无效的绑定索引: %d" % index)
		return
	_log_debug("手动触发 Binding[%d]" % index)
	_on_event_fired(context, index)

## 动态启用/禁用指定绑定
func set_binding_enabled(index: int, enabled: bool) -> void:
	if index < 0 or index >= event_bindings.size():
		_log_warning("无效的绑定索引: %d" % index)
		return

	event_bindings[index].enabled = enabled

	if index < _runtime_event_instances.size():
		var event_instance: RuntimeEventInstance = _runtime_event_instances[index]
		if event_instance != null:
			if enabled:
				event_instance.start_listening()
			else:
				event_instance.stop_listening()

	_log_debug("Binding[%d] %s" % [index, "启用" if enabled else "禁用"])
