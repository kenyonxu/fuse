# 文件：addons/fuse/core/runtime_action_runner_instance.gd
@tool
class_name RuntimeActionRunnerInstance extends RefCounted

## Phase 2 优化：预加载对象池类（避免循环依赖）
# const InstructionInstancePoolClass = preload("res://addons/fuse/core/pooling/instruction_instance_pool.gd")

## Phase 3 优化：预加载编译缓存类
# const CompiledInstructionSequenceClass = preload("res://addons/fuse/core/execution/compiled_instruction_sequence.gd")

## 运行时 ActionRunner 实例类
##
## 提供轻量级的运行时 ActionRunner 实例，避免不必要的资源复制。
## 这个类包装了 ActionRunner 定义，并为每个触发器提供独立的运行时状态。

## 信号
signal execution_completed(total_time: float)      ## 执行完成信号
signal execution_failed(error_message: String)     ## 执行失败信号
signal execution_canceled(reason: String)          ## 执行取消信号
signal instruction_started(instruction: BaseInstruction)  ## 指令开始执行信号
signal instruction_completed(instruction: BaseInstruction)  ## 指令完成信号
signal all_instructions_completed()                ## 所有指令完成信号

## 属性
var action_runner: ActionRunner                    ## ActionRunner 定义资源
var runtime_state: Dictionary = {}                 ## 运行时状态字典
var owner_trigger: Node                           ## 拥有此实例的触发器节点
var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.INFO  ## 日志输出级别

## 运行时指令实例数组（用于状态隔离）
var _instruction_instances: Array[RuntimeInstructionInstance] = []

## 性能优化：验证缓存（Phase 2.5 优化）
## 避免每帧重复验证相同的指令数组
var _instructions_validated: bool = false
var _validated_instruction_count: int = -1

## 性能优化：信号批量模式（Phase 2.5 优化）
## 减少 per-instruction 信号发射开销
var _batch_signals: bool = false
var _pending_started_instructions: Array[BaseInstruction] = []
var _pending_completed_instructions: Array[BaseInstruction] = []

## 性能优化：状态缓存变量（Phase 1 优化）
## 避免频繁的字典访问，直接使用缓存变量
var _is_running_cached: bool = false              ## 运行状态缓存
var _is_canceling_cached: bool = false            ## 取消状态缓存
var _context_cached: ExecutionContext = null      ## 执行上下文缓存

## Phase 2 优化：对象池配置
## 是否启用对象池（可通过属性禁用以回滚）
var use_instruction_pool: bool = true

## 静态对象池实例（所有 RuntimeActionRunnerInstance 共享）
static var _shared_instruction_pool: RefCounted = null

## 获取共享的对象池实例
static func get_shared_pool() -> RefCounted:
	if not _shared_instruction_pool:
		_shared_instruction_pool = InstructionInstancePool.new(32, 128)
	return _shared_instruction_pool

## 构造函数
func _init(definition: ActionRunner, trigger: Node):
	action_runner = definition
	owner_trigger = trigger

	# 同步 ActionRunner 的 log_level
	if action_runner:
		log_level = action_runner.log_level

	# 初始化运行时状态
	_initialize_runtime_state()

	_log_debug("RuntimeActionRunnerInstance 创建完成: %s" % get_description())

## 初始化运行时状态
##
## 初始化 ActionRunner 的运行时状态
func _initialize_runtime_state():
	if not action_runner:
		_log_warning("没有 ActionRunner 定义，无法初始化运行时状态")
		return

	# 初始化运行时状态
	runtime_state["is_running"] = false
	runtime_state["is_canceling"] = false
	runtime_state["cancellation_reason"] = ""
	runtime_state["current_context"] = null
	runtime_state["current_instruction_index"] = 0
	runtime_state["execution_start_time"] = 0.0
	runtime_state["execution_end_time"] = 0.0
	runtime_state["has_triggered"] = false
	runtime_state["fuse_error"] = null

	_log_debug("运行时状态已初始化")

## 执行指令序列
##
## 参数：
## - context: ExecutionContext - 执行上下文
func run(context: ExecutionContext):
	# 检查是否正在运行（使用缓存变量，性能优化）
	if _is_running_cached:
		context.print_warning("RuntimeActionRunnerInstance is already running")
		_create_fuse_error_localized("FUSE_ERROR_ACTION_RUNNER_ALREADY_RUNNING", FuseError.ErrorType.EXECUTION_ERROR)
		return

	# 检查指令是否有效
	if not validate_instructions():
		context.print_error("Instruction validation failed")
		if action_runner:
			action_runner.execution_failed.emit("Instruction validation failed")
		return

	# 设置缓存变量（性能优化：先设置缓存）
	_is_running_cached = true
	_is_canceling_cached = false
	_context_cached = context

	# 同步到运行时状态（用于持久化）
	runtime_state["is_running"] = true
	runtime_state["current_context"] = context
	runtime_state["current_instruction_index"] = 0
	runtime_state["execution_start_time"] = Time.get_ticks_msec() / 1000.0
	runtime_state["fuse_error"] = null

	# 设置 ActionRunner 引用到上下文，供条件检查指令使用
	context.set_action_runner(self)

	_log_debug_localized("FUSE_LOG_STARTING_EXECUTION")

	# 执行指令序列
	_execute_instructions(context)

## 取消执行序列
##
## 参数：
## - reason: String - 取消原因
func cancel_execution(reason: String = ""):
	# 使用缓存变量检查（性能优化）
	if not _is_running_cached:
		_log_debug("没有正在执行的序列可以取消")
		return

	# 更新缓存变量（性能优化）
	_is_canceling_cached = true
	_is_running_cached = false

	# 同步到运行时状态
	runtime_state["is_canceling"] = true
	runtime_state["cancellation_reason"] = reason

	_log_debug_localized("FUSE_LOG_CANCELLING_EXECUTION", {"reason": reason})

	# 设置运行状态为 false，让执行循环自然退出
	runtime_state["is_running"] = false

## 设置停止执行标志（API 兼容性方法）
##
## 此方法为 ActionRunner API 兼容性而提供，内部调用 cancel_execution
##
## 参数：
## - stop: bool - 是否停止执行
## - reason: String - 停止原因
func set_stop_execution(stop: bool, reason: String = ""):
	if stop:
		cancel_execution(reason)

## 验证指令
##
## 返回：
## - bool - 指令是否有效
func validate_instructions() -> bool:
	# Phase 2.5 优化：使用验证缓存
	# 如果指令数组未变化，跳过重复验证
	var current_count = action_runner.instructions.size() if action_runner and action_runner.instructions else 0

	if _instructions_validated and _validated_instruction_count == current_count:
		return current_count > 0

	# 首次验证或指令数量变化时执行完整验证
	if not action_runner or not action_runner.instructions:
		_instructions_validated = false
		_validated_instruction_count = 0
		return false

	for instruction in action_runner.instructions:
		if not instruction:
			_instructions_validated = false
			return false

	# 验证通过，更新缓存
	_instructions_validated = true
	_validated_instruction_count = current_count
	return true

## 执行指令序列（内部实现）
func _execute_instructions(context: ExecutionContext):
	var instructions = action_runner.instructions if action_runner else []

	# 根据执行模式选择执行方法
	if action_runner and action_runner.execution_mode == ActionRunner.ExecutionMode.PARALLEL:
		await _execute_instructions_parallel(context, instructions)
	else:
		await _execute_instructions_sequential(context, instructions)

## 设置信号批量模式（Phase 2.5 优化）
##
## 启用后，instruction_started/completed 信号会缓存到执行结束后批量发射
## 适用于需要减少信号开销的高频触发场景
func set_batch_signal_mode(enabled: bool) -> void:
	if not enabled and _batch_signals:
		# 禁用时刷新待发射的信号
		_flush_pending_signals()
	_batch_signals = enabled

## 发射指令开始信号（带批量模式支持）
func _emit_instruction_started(instruction: BaseInstruction) -> void:
	if _batch_signals:
		_pending_started_instructions.append(instruction)
	else:
		instruction_started.emit(instruction)

## 发射指令完成信号（带批量模式支持）
func _emit_instruction_completed(instruction: BaseInstruction) -> void:
	if _batch_signals:
		_pending_completed_instructions.append(instruction)
	else:
		instruction_completed.emit(instruction)

## 刷新待发射的信号
func _flush_pending_signals() -> void:
	for instruction in _pending_started_instructions:
		instruction_started.emit(instruction)
	for instruction in _pending_completed_instructions:
		instruction_completed.emit(instruction)
	_pending_started_instructions.clear()
	_pending_completed_instructions.clear()

## 使验证缓存失效（Phase 2.5 优化）
##
## 当 ActionRunner 的指令数组发生变化时应调用此方法
func invalidate_validation_cache() -> void:
	_instructions_validated = false
	_validated_instruction_count = -1

## ============================================================
## Phase 3: 编译缓存集成
## ============================================================

## 获取或创建编译缓存
##
## 从 ActionRunner 资源获取共享的编译缓存。
## 如果缓存无效或不存在，则重新编译。
##
## 返回：
## - CompiledInstructionSequence - 编译缓存实例
func _get_or_create_compiled_cache() -> RefCounted:
	if not action_runner:
		return null

	# 从 ActionRunner 获取共享缓存
	var cache = action_runner._compiled_cache
	if cache == null:
		cache = CompiledInstructionSequence.new()
		action_runner._compiled_cache = cache

	# 检查缓存有效性
	if not cache.is_valid_for(action_runner):
		cache.compile(action_runner)

	return cache

## 获取缓存的指令描述
##
## 使用编译缓存获取指令描述，避免重复调用 get_description()
##
## 参数：
## - index: int - 指令索引
##
## 返回：
## - String - 缓存的描述字符串，如果无效则返回空字符串
func _get_cached_description(index: int) -> String:
	var cache = _get_or_create_compiled_cache()
	if cache:
		return cache.get_cached_description(index)
	return ""

## 顺序执行指令
func _execute_instructions_sequential(context: ExecutionContext, instructions: Array):
	_log_debug_localized("FUSE_LOG_STARTING_SEQUENTIAL_EXECUTION")

	# 性能优化：日志级别前置检查
	# 避免在热路径中重复调用日志方法
	var should_log_debug = log_level >= FuseLogger.LogLevel.DEBUG

	# 清理之前的指令实例
	_cleanup_instruction_instances()

	for i in range(instructions.size()):
		# 检查是否需要停止执行（使用缓存变量，性能优化）
		if not _is_running_cached:
			if _is_canceling_cached:
				_log_debug_localized("FUSE_LOG_EXECUTION_CANCELLED", {"reason": runtime_state["cancellation_reason"]})
				execution_canceled.emit(runtime_state["cancellation_reason"])
			else:
				_log_debug_localized("FUSE_LOG_EXECUTION_STOP")
			return

		runtime_state["current_instruction_index"] = i
		var instruction = instructions[i]

		# Phase 2 优化：使用对象池获取运行时指令实例
		var runtime_instruction = _acquire_instruction_instance(instruction, context)
		_instruction_instances.append(runtime_instruction)

		# 性能优化：仅当日志级别允许时才获取描述并记录日志
		# Phase 3 优化：使用编译缓存获取描述
		if should_log_debug:
			var desc = _get_cached_description(i)
			_log_debug_localized("FUSE_LOG_EXECUTING_INSTRUCTION", {"current": str(i + 1), "total": str(instructions.size()), "description": desc})
			context.print_message(FuseLocalization.translate_format("FUSE_LOG_EXECUTING_INSTRUCTION", {"current": str(i + 1), "total": str(instructions.size()), "description": desc}))

		# 发出运行时实例的信号（Phase 2.5 优化：使用批量模式）
		_emit_instruction_started(instruction)

		# 记录指令开始时间（用于异步执行的时间计算）
		var instruction_start_time = Time.get_ticks_msec() / 1000.0

		# 使用运行时实例执行
		var sync_completed = runtime_instruction.execute_sync()

		if sync_completed:
			# 同步完成，继续下一个指令
			# 检查错误
			if action_runner and action_runner.stop_on_error and runtime_instruction.has_error():
				_create_fuse_error_localized("FUSE_ERROR_INSTRUCTION_EXECUTION_FAILED", FuseError.ErrorType.EXECUTION_ERROR, {
					"instruction_index": i,
					"instruction_description": instruction.get_description()
				}, {"error": runtime_instruction.get_error_message()})
				execution_failed.emit(FuseLocalization.translate_format("FUSE_ERROR_INSTRUCTION_EXECUTION_FAILED", {"error": runtime_instruction.get_error_message()}))
				return

			# Phase 2.5 优化：使用批量信号发射方法
			_emit_instruction_completed(instruction)
			continue  # 继续下一个指令
		else:
			# 异步执行，等待完成
			# 修复：如果指令已完成，不需要 await（兼容 RuntimeInstructionInstance 架构）
			# 这修复了引入 RuntimeInstructionInstance 后的 "ActionRunner 已经在运行" 错误
			if not runtime_instruction.is_completed() and not runtime_instruction.has_error():
				await runtime_instruction.finished

			var instruction_end_time = Time.get_ticks_msec() / 1000.0
			var instruction_time = instruction_end_time - instruction_start_time
			if should_log_debug:
				_log_debug_localized("FUSE_LOG_ASYNC_INSTRUCTION_COMPLETED", {"time": str(instruction_time)})

			# 发出运行时实例的信号
			instruction_completed.emit(instruction)

			# 检查错误
			if action_runner and action_runner.stop_on_error and runtime_instruction.has_error():
				_log_debug_localized("FUSE_LOG_STOPPING_DUE_TO_ERROR", {"error": runtime_instruction.get_error_message()})
				_create_fuse_error_localized("FUSE_ERROR_INSTRUCTION_EXECUTION_FAILED", FuseError.ErrorType.EXECUTION_ERROR, {
					"instruction_index": i,
					"instruction_description": instruction.get_description()
				}, {"error": runtime_instruction.get_error_message()})
				execution_failed.emit(FuseLocalization.translate_format("FUSE_ERROR_INSTRUCTION_EXECUTION_FAILED", {"error": runtime_instruction.get_error_message()}))
				return

	_complete_execution()

## 清理指令实例
func _cleanup_instruction_instances():
	# Phase 2 优化：使用对象池时，将实例归还到池中
	if use_instruction_pool:
		var pool = get_shared_pool()
		for runtime_instruction in _instruction_instances:
			pool.release(runtime_instruction)
	else:
		# 非池化模式：直接清理
		for runtime_instruction in _instruction_instances:
			runtime_instruction.cleanup()
	_instruction_instances.clear()

## 获取或创建运行时指令实例（Phase 2 优化）
##
## 如果启用了对象池，从池中获取实例；否则创建新实例
func _acquire_instruction_instance(
	instruction: BaseInstruction,
	context: ExecutionContext
) -> RuntimeInstructionInstance:
	if use_instruction_pool:
		var pool = get_shared_pool()
		return pool.acquire(instruction, context, self)
	else:
		return RuntimeInstructionInstance.new(instruction, context, self)

## 并行执行指令
func _execute_instructions_parallel(context: ExecutionContext, instructions: Array):
	_log_debug_localized("FUSE_LOG_STARTING_PARALLEL_EXECUTION")

	if instructions.size() == 0:
		_complete_execution()
		return

	# 性能优化：日志级别前置检查
	var should_log_debug = log_level >= FuseLogger.LogLevel.DEBUG

	# 清理之前的指令实例
	_cleanup_instruction_instances()

	var tasks: Array[RuntimeInstructionInstance] = []
	var errors: Array[String] = []

	# 启动所有指令
	for i in range(instructions.size()):
		var instruction = instructions[i]
		# 使用缓存变量检查（性能优化）
		if not _is_running_cached:
			if _is_canceling_cached:
				_log_debug_localized("FUSE_LOG_EXECUTION_CANCELLED", {"reason": runtime_state["cancellation_reason"]})
				execution_canceled.emit(runtime_state["cancellation_reason"])
			else:
				_log_debug("并行执行停止")
			return

		# 性能优化：仅当日志级别允许时才记录
		if should_log_debug:
			_log_debug("并行启动指令 %d/%d: %s" % [i + 1, instructions.size(), instruction.get_description()])
			context.print_message(FuseLocalization.translate_format("FUSE_LOG_EXECUTING_INSTRUCTION", {
				"current": str(i + 1),
				"total": str(instructions.size()),
				"description": instruction.get_description()
			}))

		# Phase 2.5 优化：使用批量信号发射方法
		_emit_instruction_started(instruction)

		# Phase 2 优化：使用对象池获取运行时指令实例
		var runtime_instruction = _acquire_instruction_instance(instruction, context)
		_instruction_instances.append(runtime_instruction)

		# 执行（不等待）
		runtime_instruction.execute_sync()

		tasks.append(runtime_instruction)

	# 等待所有任务完成
	await _wait_for_all_parallel_tasks(tasks)

	# 检查错误
	for i in range(tasks.size()):
		var runtime_instruction = tasks[i]
		if runtime_instruction.has_error():
			errors.append("Instruction %d failed: %s" % [i, runtime_instruction.get_error_message()])

	if not errors.is_empty():
		execution_failed.emit("并行执行失败: " + ", ".join(errors))

	_complete_execution()

## 等待所有并行任务完成
func _wait_for_all_parallel_tasks(tasks: Array[RuntimeInstructionInstance]):
	# 收集所有未完成的运行时实例
	var pending_tasks: Array[RuntimeInstructionInstance] = []

	for task in tasks:
		if not task.is_completed() and not task.has_error():
			pending_tasks.append(task)

	if pending_tasks.is_empty():
		return

	_log_debug("等待 %d 个异步指令完成" % pending_tasks.size())

	# 使用 RefCounted 包装计数器，避免 GDScript 闭包在 await 后无法修改捕获的基本类型变量
	var _counter = RefCounted.new()
	_counter.set_meta("remaining", pending_tasks.size())

	for task in pending_tasks:
		task.finished.connect(func():
			var remaining = _counter.get_meta("remaining")
			_counter.set_meta("remaining", remaining - 1)
		)

	while _counter.get_meta("remaining") > 0:
		await Engine.get_main_loop().process_frame
		# 检查是否需要取消（使用缓存变量，性能优化）
		if not _is_running_cached:
			break

## 等待任意并行信号
func _wait_for_any_parallel_signal(signals: Array) -> int:
	if signals.is_empty():
		return -1

	var aggregator = _ParallelSignalAggregator.new()
	aggregator.setup(signals)

	var result = await aggregator.any_completed
	return result

## 并行信号聚合器
class _ParallelSignalAggregator extends RefCounted:
	signal any_completed(index: int)
	var _signals: Array = []
	var _connections: Array = []
	var _completed: bool = false

	func setup(signals: Array) -> void:
		_signals = signals
		for i in range(_signals.size()):
			var sig = _signals[i]
			var idx = i
			var callback = func(): _on_signal_received(idx)
			_connections.append({"signal": sig, "callback": callback, "index": idx})
			sig.connect(callback)

	func _on_signal_received(index: int) -> void:
		if _completed:
			return
		_completed = true

		# 先发出信号，再断开连接（确保信号能被接收）
		any_completed.emit(index)

		# 断开所有连接
		_disconnect_all()

	func _disconnect_all() -> void:
		for conn in _connections:
			# 安全检查：确保信号和回调仍然有效
			if conn.signal and is_instance_valid(conn.signal) and conn.callback:
				if conn.signal.is_connected(conn.callback):
					conn.signal.disconnect(conn.callback)
		_connections.clear()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			# 安全检查：确保对象仍然有效
			if is_instance_valid(self):
				_disconnect_all()

## 执行指令（统一接口）
func _execute_instruction(instruction: BaseInstruction, context: ExecutionContext) -> bool:
	if not instruction:
		_log_error("指令为空")
		return true  # 同步完成（失败）

	# 使用指令的同步执行包装器
	var sync_completed = instruction.execute_sync(context)

	return sync_completed

## 完成执行
func _complete_execution():
	if not _is_running_cached:
		return
	# Phase 2.5 优化：刷新待发射的信号
	_flush_pending_signals()

	# 更新缓存变量（性能优化）
	_is_running_cached = false
	_is_canceling_cached = false

	# 同步到运行时状态
	runtime_state["is_running"] = false
	runtime_state["execution_end_time"] = Time.get_ticks_msec() / 1000.0

	var total_time = runtime_state["execution_end_time"] - runtime_state["execution_start_time"]

	_log_debug_localized("FUSE_LOG_EXECUTION_COMPLETED", {"time": str(total_time)})

	# 发出运行时实例的完成信号（让 Trigger 能够独立接收）
	execution_completed.emit(total_time)
	all_instructions_completed.emit()

## 清理运行时实例
func cleanup():
	_log_debug("开始清理 RuntimeActionRunnerInstance")

	# 取消正在执行的序列（使用缓存变量检查）
	if _is_running_cached:
		cancel_execution("清理运行时实例")

	# 修复：清理所有指令实例
	_cleanup_instruction_instances()

	# Phase 2.5 优化：清理待发射的信号
	_pending_started_instructions.clear()
	_pending_completed_instructions.clear()

	# 重置验证缓存
	_instructions_validated = false
	_validated_instruction_count = -1

	# 清理运行时状态
	runtime_state.clear()

	# 重置缓存变量（性能优化）
	_is_running_cached = false
	_is_canceling_cached = false
	_context_cached = null

	# 清理引用
	action_runner = null
	owner_trigger = null

	_log_debug("RuntimeActionRunnerInstance 清理完成")

## 获取运行时状态
##
## 参数：
## - key: String - 状态键
##
## 返回：
## - Variant - 状态值，如果不存在则返回 null
func get_runtime_state(key: String):
	return runtime_state.get(key, null)

## 设置运行时状态
##
## 参数：
## - key: String - 状态键
## - value: Variant - 状态值
func set_runtime_state(key: String, value):
	runtime_state[key] = value

## 检查是否正在运行
##
## 返回：
## - bool - 是否正在运行
func is_running() -> bool:
	# 性能优化：直接返回缓存值，避免字典访问
	return _is_running_cached

## 获取运行时实例描述
##
## 返回：
## - String - 运行时实例的描述文本
func get_description() -> String:
	if action_runner:
		var desc = "RuntimeActionRunnerInstance"
		if action_runner.instructions and action_runner.instructions.size() > 0:
			desc += " (%d 条指令)" % action_runner.instructions.size()
		return desc
	return "RuntimeActionRunnerInstance (无 ActionRunner 定义)"

## 创建 FuseError 实例
func _create_fuse_error(message: String, error_type: FuseError.ErrorType = FuseError.ErrorType.RUNTIME_ERROR, context: Dictionary = {}):
	var error_context = context.duplicate()
	error_context["owner_trigger"] = owner_trigger.get_name() if owner_trigger else "无触发器"

	var error = FuseError.create_with_context(error_type, "RuntimeActionRunnerInstance", message, error_context)
	runtime_state["fuse_error"] = error
	return error

## 创建本地化 FuseError 实例
func _create_fuse_error_localized(message_key: String, error_type: FuseError.ErrorType = FuseError.ErrorType.RUNTIME_ERROR, args: Dictionary = {}, context: Dictionary = {}) -> void:
	var localized_message = FuseLocalization.translate_format(message_key, args)
	_create_fuse_error(localized_message, error_type, context)
	# 注意：不需要额外调用 _log_error_localized()，因为 FuseError._init() 已经自动记录日志

## 统一日志方法
func _log_debug(message: String) -> void:
	FuseLogger.log_debug("RuntimeActionRunnerInstance", log_level, message)

func _log_info(message: String) -> void:
	FuseLogger.log_info("RuntimeActionRunnerInstance", log_level, message)

func _log_warning(message: String) -> void:
	FuseLogger.log_warning("RuntimeActionRunnerInstance", log_level, message)

func _log_error(message: String) -> void:
	FuseLogger.log_error("RuntimeActionRunnerInstance", log_level, message)

## 本地化日志方法
func _log_debug_localized(message_key: String, args: Dictionary = {}) -> void:
	FuseLogger.log_debug_localized("RuntimeActionRunnerInstance", log_level, message_key, args)

func _log_info_localized(message_key: String, args: Dictionary = {}) -> void:
	FuseLogger.log_info_localized("RuntimeActionRunnerInstance", log_level, message_key, args)

func _log_warning_localized(message_key: String, args: Dictionary = {}) -> void:
	FuseLogger.log_warning_localized("RuntimeActionRunnerInstance", log_level, message_key, args)

func _log_error_localized(message_key: String, args: Dictionary = {}) -> void:
	FuseLogger.log_error_localized("RuntimeActionRunnerInstance", log_level, message_key, args)
