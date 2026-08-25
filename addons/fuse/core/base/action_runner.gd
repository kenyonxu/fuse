@tool
@icon("res://addons/fuse/icons/action_runner.svg")
class_name ActionRunner extends Resource

## 导入指令序列化器
# const InstructionSerializer = preload("res://addons/fuse/core/serialization/instruction_serializer.gd")

## Phase 3: 预加载编译缓存类
const CompiledInstructionSequenceClass = preload("res://addons/fuse/core/execution/compiled_instruction_sequence.gd")

## 动作执行器配置
@export var instructions: Array[BaseInstruction] = []:
	set(value):
		instructions = value
		_validation_cache.clear()  # 清除验证缓存
		_log_debug("Instructions updated (%d instructions)" % value.size())

@export var execution_mode: ExecutionMode = ExecutionMode.SEQUENTIAL:
	set(value):
		execution_mode = value
		_log_debug("Execution mode set to: %s" % ExecutionMode.keys()[value])

@export var stop_on_error: bool = true:
	set(value):
		stop_on_error = value
		_log_debug("Stop on error %s" % ("enabled" if value else "disabled"))

@export var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.INFO  ## 日志输出级别

@export_group("Timeout Configuration")
@export var enable_instruction_timeout: bool = false:  ## 是否启用自定义指令超时检查
	set(value):
		enable_instruction_timeout = value
		_log_debug("Instruction timeout %s" % ("enabled" if value else "disabled"))

@export var instruction_timeout: float = 5.0:  ## 单个指令超时时间（秒），最小值0.1秒
	set(value):
		instruction_timeout = max(0.1, value)
		_log_debug("Instruction timeout set to: %.2f seconds" % value)

## 执行状态
var is_running: bool = false
var is_canceling: bool = false  ## 是否正在取消执行
var cancellation_reason: String = ""  ## 取消原因
var current_context: ExecutionContext = null
var current_instruction_index: int = 0
var execution_start_time: float = 0.0
var execution_end_time: float = 0.0
var _fuse_error: FuseError = null	 ## FuseError 实例，用于统一错误处理
var _validation_cache: Dictionary = {}  ## 验证缓存，避免重复验证相同指令
var _execution_tracker = null  ## 执行跟踪器，用于调试
var _debug_enabled: bool = true  ## 是否启用调试模式

## 信号跟踪（用于防止内存泄漏）
var _instruction_callback_cache: Dictionary = {}  ## instruction -> cached callback

## 顺序执行中当前正被 await 的指令（取消传播目标）
var _awaiting_instruction: BaseInstruction = null

## 终态信号已发出标志（run 完成时据此跳过 _complete_execution 的重复 emit，
## 保证 canceled/failed/completed 各恰好一次）
var _terminal_emitted: bool = false

## 条件检查支持
var _skip_instruction_count: int = 0  ## 需要跳过的指令数量
var _stop_execution: bool = false  ## 是否停止执行
var _stop_reason: String = ""  ## 停止原因

## Phase 3: 编译缓存（所有 RuntimeActionRunnerInstance 共享）
## 预缓存描述字符串和方法绑定，减少高频触发时的重复计算
var _compiled_cache: RefCounted = null  # CompiledInstructionSequence 类型

## 执行模式枚举
enum ExecutionMode {
	SEQUENTIAL,	# 顺序执行
	PARALLEL	   # 并行执行
}

## 信号
signal execution_started
signal instruction_started(instruction: BaseInstruction)
signal instruction_completed(instruction: BaseInstruction)
signal execution_completed
signal execution_failed(error_message: String)
signal execution_canceled(reason: String)  ## 执行被取消信号

## 常量
const MAX_INSTRUCTIONS: int = 1000
const DEFAULT_TIMEOUT: float = 30.0

## 初始化
func _init():
	_log_debug_localized("FUSE_LOG_ACTION_RUNNER_INITIALIZED")

## 动态属性列表
##
## 显式返回 Array[Dictionary]，避免 Godot 4.x 使用 Resource 基类的 Array 返回类型
## 触发 "_get_property_list() should return Array[Dictionary]" 兼容性警告。
func _get_property_list() -> Array[Dictionary]:
	return []

## 执行指令序列
## context: ExecutionContext - 执行上下文
func run(context: ExecutionContext):
	if is_running:
		context.print_warning("ActionRunner is already running")
		_create_fuse_error_localized("FUSE_ERROR_ACTION_RUNNER_ALREADY_RUNNING", FuseError.ErrorType.EXECUTION_ERROR)
		return

	if not validate_instructions():
		context.print_error("Instruction validation failed")
		execution_failed.emit("Instruction validation failed")
		return

	# 设置 ActionRunner 引用到上下文，供条件检查指令使用
	context.set_action_runner(self)

	is_running = true
	current_context = context
	current_instruction_index = 0
	execution_start_time = Time.get_ticks_msec() / 1000.0
	_fuse_error = null  # 重置错误状态

	_log_debug_localized("FUSE_LOG_STARTING_EXECUTION", {"count": instructions.size()})
	context.print_message(FuseLocalization.translate_format("FUSE_LOG_STARTING_EXECUTION", {"count": instructions.size()}))

	execution_started.emit()

	# 启动调试跟踪（如果启用）
	if _debug_enabled and _execution_tracker:
		_execution_tracker.start_tracking(context)

	match execution_mode:
		ExecutionMode.SEQUENTIAL:
			await _run_sequential(context)
		ExecutionMode.PARALLEL:
			await _run_parallel(context)

	# 停止调试跟踪
	if _debug_enabled and _execution_tracker:
		_execution_tracker.stop_tracking()

	_complete_execution()
	# 复位终态标志，保证下次 run 干净（取消/失败 emit 点在循环内已置位）
	_terminal_emitted = false

## 停止执行
func stop():
	if is_running:
		_log_debug_localized("FUSE_LOG_EXECUTION_STOPPED_BY_REQUEST")
		# 设置运行状态为 false，让执行循环自然退出
		is_running = false

## 取消执行序列
## reason: String - 取消原因
func cancel_execution(reason: String = ""):
	if not is_running:
		_log_debug_localized("FUSE_LOG_CANNOT_CANCEL_NOT_RUNNING")
		return

	if is_canceling:
		_log_debug_localized("FUSE_LOG_ALREADY_CANCELLING")
		return

	is_canceling = true
	cancellation_reason = reason
	_log_debug_localized("FUSE_LOG_CANCELLING_EXECUTION", {"reason": reason})

	# 设置运行状态为 false，让执行循环自然退出
	is_running = false

	# 唤醒正卡在 await instruction.finished 的顺序协程
	# （BaseInstruction.cancel 自带 finished.emit()）
	if _awaiting_instruction != null and is_instance_valid(_awaiting_instruction) \
			and not _awaiting_instruction.is_completed():
		_awaiting_instruction.cancel()
	_awaiting_instruction = null

## 检查是否正在取消
## returns: bool - 是否正在取消执行
func get_is_canceling() -> bool:
	return is_canceling

## 获取执行状态
## returns: Dictionary - 执行状态信息
func get_execution_status() -> Dictionary:
	var current_time = Time.get_ticks_msec() / 1000.0
	return {
		"is_running": is_running,
		"current_instruction_index": current_instruction_index,
		"total_instructions": instructions.size(),
		"execution_time": current_time - execution_start_time if is_running else execution_end_time - execution_start_time,
		"progress": float(current_instruction_index) / float(instructions.size()) if instructions.size() > 0 else 0.0,
		"execution_mode": ExecutionMode.keys()[execution_mode]
	}

## 验证指令
## returns: bool - 指令是否有效
func validate_instructions() -> bool:
	if instructions.size() > MAX_INSTRUCTIONS:
		_log_error_localized("FUSE_ERROR_TOO_MANY_INSTRUCTIONS", {"count": instructions.size(), "max": MAX_INSTRUCTIONS})
		_create_fuse_error_localized("FUSE_ERROR_TOO_MANY_INSTRUCTIONS", FuseError.ErrorType.VALIDATION_ERROR, {}, {"count": instructions.size(), "max": MAX_INSTRUCTIONS})
		return false

	for i in range(instructions.size()):
		var instruction = instructions[i]
		if not instruction:
			_log_error_localized("FUSE_ERROR_INSTRUCTION_AT_INDEX_NULL", {"index": i})
			_create_fuse_error_localized("FUSE_ERROR_INSTRUCTION_AT_INDEX_NULL", FuseError.ErrorType.VALIDATION_ERROR, {}, {"index": i})
			return false

		# 使用缓存避免重复验证
		var instruction_id = instruction.get_instance_id()
		if not _validation_cache.has(instruction_id):
			var errors = instruction.validate()
			_validation_cache[instruction_id] = errors

		var errors = _validation_cache[instruction_id]
		if not errors.is_empty():
			_log_error_localized("FUSE_ERROR_INSTRUCTION_VALIDATION_FAILED", {"index": i, "errors": ", ".join(errors)})
			_create_fuse_error_localized("FUSE_ERROR_INSTRUCTION_VALIDATION_FAILED", FuseError.ErrorType.VALIDATION_ERROR, {}, {"index": i, "errors": ", ".join(errors)})
			return false

	return true

## 顺序执行模式
## context: ExecutionContext - 执行上下文
func _run_sequential(context: ExecutionContext):
	_log_debug_localized("FUSE_LOG_STARTING_SEQUENTIAL_EXECUTION")

	for i in range(instructions.size()):
		# 检查是否需要跳过当前指令
		if _skip_instruction_count > 0:
			_skip_instruction_count -= 1
			_log_debug_localized("FUSE_LOG_SKIPPING_INSTRUCTION", {"index": str(i), "remaining": str(_skip_instruction_count)})
			continue

		# 检查是否需要停止执行
		if _stop_execution:
			_log_debug_localized("FUSE_LOG_STOP_EXECUTION", {"reason": _stop_reason})
			if current_context:
				current_context.print_message("执行被条件检查停止: %s" % _stop_reason)
			return

		if not is_running:
			if is_canceling:
				_log_debug_localized("FUSE_LOG_EXECUTION_CANCELLED", {"reason": cancellation_reason})
				execution_canceled.emit(cancellation_reason)
				_terminal_emitted = true

			else:
				_log_debug_localized("FUSE_LOG_EXECUTION_STOP")
			# 断开当前指令的信号（如果已连接）
			_disconnect_instruction_signal(instructions[i] if i < instructions.size() else null)
			return

		current_instruction_index = i
		var instruction = instructions[i]

		var desc = instruction.get_description()
		_log_debug_localized("FUSE_LOG_EXECUTING_INSTRUCTION", {"current": str(i + 1), "total": str(instructions.size()), "description": desc})
		context.print_message(FuseLocalization.translate_format("FUSE_LOG_EXECUTING_INSTRUCTION", {"current": str(i + 1), "total": str(instructions.size()), "description": desc}))

		instruction_started.emit(instruction)

		# 记录指令开始（调试模式）
		if _debug_enabled and _execution_tracker:
			_execution_tracker.record_instruction_start(instruction, context)

		# 记录指令开始时间（用于异步执行的时间计算）
		var instruction_start_time = Time.get_ticks_msec() / 1000.0

		# 统一执行指令
		var sync_completed = _execute_instruction(instruction, context)

		if sync_completed:
			# 同步完成，继续下一个指令
			# 检查错误
			if stop_on_error and instruction.has_error():
				_create_fuse_error_localized("FUSE_ERROR_INSTRUCTION_EXECUTION_FAILED", FuseError.ErrorType.EXECUTION_ERROR, {
					"instruction_index": i,
					"instruction_description": instruction.get_description()
				}, {"error": instruction.get_error_message()})
				execution_failed.emit(FuseLocalization.translate_format("FUSE_ERROR_INSTRUCTION_EXECUTION_FAILED", {"error": instruction.get_error_message()}))
				_terminal_emitted = true
				_disconnect_instruction_signal(instruction)
				return

			# 检查超时
			if _check_timeout(context):
				_disconnect_instruction_signal(instruction)
				return

			continue  # 继续下一个指令
		else:
			# 异步执行，等待完成
			if not instruction.is_completed() and not instruction.has_error():
				_awaiting_instruction = instruction
				await instruction.finished
				_awaiting_instruction = null

			var instruction_end_time = Time.get_ticks_msec() / 1000.0
			var instruction_time = instruction_end_time - instruction_start_time
			_log_debug_localized("FUSE_LOG_ASYNC_INSTRUCTION_COMPLETED", {"time": str(instruction_time)})

			# 记录指令完成（调试模式）
			if _debug_enabled and _execution_tracker:
				_execution_tracker.record_instruction_complete(instruction, context)

			# 断开信号连接
			_disconnect_instruction_signal(instruction)

			# 终态互斥：被取消唤醒的指令（status=CANCELLED，非真完成）不发完成信号
			if not (is_canceling and not instruction.is_completed()):
				instruction_completed.emit(instruction)

			# 检查错误
			if stop_on_error and instruction.has_error():
				_log_debug_localized("FUSE_LOG_STOPPING_DUE_TO_ERROR", {"error": instruction.get_error_message()})
				_create_fuse_error_localized("FUSE_ERROR_INSTRUCTION_EXECUTION_FAILED", FuseError.ErrorType.EXECUTION_ERROR, {
					"instruction_index": i,
					"instruction_description": instruction.get_description()
				}, {"error": instruction.get_error_message()})
				execution_failed.emit(FuseLocalization.translate_format("FUSE_ERROR_INSTRUCTION_EXECUTION_FAILED", {"error": instruction.get_error_message()}))
				_terminal_emitted = true
				return

			# 检查超时
			if _check_timeout(context):
				return

	_log_debug_localized("FUSE_LOG_SEQUENTIAL_EXECUTION_COMPLETED")


## 执行指令（统一接口）
##
## 统一执行指令的包装方法，处理同步和异步执行的逻辑。
##
## 参数：
## - instruction: BaseInstruction - 要执行的指令
## - context: ExecutionContext - 执行上下文
##
## 返回：
## - bool - 是否同步完成（true 表示同步完成，false 表示需要异步等待）
func _execute_instruction(instruction: BaseInstruction, context: ExecutionContext) -> bool:
	# 记录指令开始时间（用于超时检查）
	var instruction_start_time = Time.get_ticks_msec() / 1000.0

	# 设置指令超时（如果启用）
	if enable_instruction_timeout:
		instruction.set_timeout(instruction_timeout)

	# 使用指令的同步执行包装器
	var sync_completed = instruction.execute_sync(context)

	return sync_completed

## 并行执行模式
## context: ExecutionContext - 执行上下文
func _run_parallel(context: ExecutionContext):
	_log_debug_localized("FUSE_LOG_STARTING_PARALLEL_EXECUTION")

	if instructions.size() == 0:
		return

	# 创建并行任务
	var tasks: Array[BaseInstruction] = []
	var errors: Array[String] = []

	# 启动所有指令
	for i in range(instructions.size()):
		var instruction = instructions[i]
		if not is_running:
			if is_canceling:
				_log_debug("并行执行被取消: %s" % cancellation_reason)
				execution_canceled.emit(cancellation_reason)
				_terminal_emitted = true
			else:
				_log_debug("并行执行停止")
			return

		_log_debug("并行启动指令 %d/%d: %s" % [i + 1, instructions.size(), instruction.get_description()])

		# 发出指令开始信号
		instruction_started.emit(instruction)

		# 设置指令超时（如果启用）
		if enable_instruction_timeout:
			instruction.set_timeout(instruction_timeout)

		# 重置指令状态，确保可以重新执行
		instruction.reset()

		# 执行指令（不使用 await，让指令在后台运行）
		instruction.execute(context)

		# 添加到任务列表
		tasks.append(instruction)

	# 等待所有任务完成（使用并行等待机制）
	if tasks.size() > 0:
		await _wait_for_all_tasks(tasks)

	# 检查错误
	for i in range(tasks.size()):
		var instruction = tasks[i]
		if instruction.has_error():
			errors.append("Instruction %d failed: %s" % [i, instruction.get_error_message()])
			_log_error("Parallel instruction %d failed: %s" % [i, instruction.get_error_message()])

	# 如果有错误，发出失败信号
	if not errors.is_empty():
		var error_message = FuseLocalization.translate_format("Parallel execution failed with {count} errors: {errors}", {"count": errors.size(), "errors": ", ".join(errors)})
		_create_fuse_error_localized("FUSE_ERROR_PARALLEL_EXECUTION_FAILED", FuseError.ErrorType.EXECUTION_ERROR, {
			"error_count": errors.size(),
			"errors": errors
		}, {"count": errors.size()})
		execution_failed.emit(error_message)
		_terminal_emitted = true
		_log_error(error_message)

	_log_debug_localized("FUSE_LOG_PARALLEL_EXECUTION_COMPLETED")

## 检查超时
## context: ExecutionContext - 执行上下文
## returns: bool - 是否超时
func _check_timeout(context: ExecutionContext) -> bool:
	# 计算有效超时时间
	var effective_timeout: float
	if enable_instruction_timeout and instruction_timeout > 0:
		# 使用单个指令超时 * 指令数作为总超时
		effective_timeout = instruction_timeout * max(1, instructions.size())
	else:
		# 默认超时：基础时间 + 每个指令额外时间
		effective_timeout = DEFAULT_TIMEOUT + (instructions.size() * 5.0)

	var elapsed = Time.get_ticks_msec() / 1000.0 - execution_start_time
	if elapsed > effective_timeout:
		_log_error_localized("FUSE_ERROR_EXECUTION_TIMEOUT", {"elapsed": str(elapsed), "timeout": str(effective_timeout), "count": instructions.size()})
		_create_fuse_error_localized("FUSE_ERROR_EXECUTION_TIMEOUT_FORMAT", FuseError.ErrorType.TIMEOUT_ERROR, {
			"elapsed_time": elapsed,
			"timeout_duration": effective_timeout,
			"instruction_count": instructions.size()
		}, {"timeout": str(effective_timeout)})
		execution_failed.emit(FuseLocalization.translate_format("FUSE_ERROR_EXECUTION_TIMEOUT_AFTER", {"timeout": str(effective_timeout)}))
		_terminal_emitted = true
		return true
	return false

## 安全连接信号
## instruction: BaseInstruction - 要连接信号的指令
## handler: Callable - 信号处理器（已弃用，保留用于兼容性）
## returns: bool - 连接是否成功
func _connect_instruction_signal(instruction: BaseInstruction, handler: Callable) -> bool:
	if not instruction:
		_log_warning_localized("FUSE_WARNING_CANNOT_CONNECT_SIGNAL_INSTRUCTION_NULL")
		return false

	# 创建并缓存回调函数
	var callback = _on_instruction_finished_wrapper.bind(instruction)
	_instruction_callback_cache[instruction] = callback

	var result = instruction.finished.connect(callback)

	_log_debug("已连接指令 '%s' 的 finished 信号" % instruction.get_name())
	return result == OK

## 安全断开指令的所有信号
## instruction: BaseInstruction - 要断开信号的指令
func _disconnect_instruction_signal(instruction: BaseInstruction):
	if not instruction:
		return

	# 使用缓存的 callback 断开连接
	if _instruction_callback_cache.has(instruction):
		var callback = _instruction_callback_cache[instruction]
		if instruction.finished.is_connected(callback):
			instruction.finished.disconnect(callback)
			_log_debug_localized("FUSE_LOG_SIGNAL_DISCONNECTED", {"instruction": instruction.get_name()})
		_instruction_callback_cache.erase(instruction)

## 断开所有指令的信号
func _disconnect_all_signals():
	_log_debug_localized("FUSE_LOG_DISCONNECTING_ALL_SIGNALS")
	var disconnect_count = 0

	for instruction in _instruction_callback_cache.keys():
		_disconnect_instruction_signal(instruction)
		disconnect_count += 1

	_instruction_callback_cache.clear()

	_log_debug_localized("FUSE_LOG_SIGNALS_DISCONNECTED", {"count": disconnect_count})

## 完成执行
func _complete_execution():
	is_running = false
	execution_end_time = Time.get_ticks_msec() / 1000.0

	var total_time = execution_end_time - execution_start_time

	# 清理所有信号连接（防止内存泄漏）
	_disconnect_all_signals()

	# 强制清理所有上下文引用
	if current_context:
		current_context.cleanup()
		# 确保上下文被垃圾回收
		current_context = null

	# 清理指令引用
	for instruction in instructions:
		if instruction.has_method("cleanup"):
			instruction.cleanup()

	if is_canceling:
		_log_debug_localized("FUSE_LOG_EXECUTION_CANCELLED_TIME", {"time": str(total_time), "reason": cancellation_reason})
		if current_context:
			current_context.print_message(FuseLocalization.translate_format("FUSE_LOG_EXECUTION_CANCELLED", {"reason": cancellation_reason}))
	else:
		_log_debug_localized("FUSE_LOG_EXECUTION_COMPLETED_TIME", {"time": str(total_time)})
		if current_context:
			var note = ""
			if total_time > 0.5:  # 只对较长的执行时间显示说明
				note = FuseLocalization.translate("FUSE_LOG_EXECUTION_TIME_NOTE")
			current_context.print_message(FuseLocalization.translate_format("FUSE_LOG_EXECUTION_COMPLETED_TIME", {"time": str(total_time)}) + note)

	# 终态互斥：循环内已 emit 过 canceled/failed 时不重复发终态信号
	# （清理逻辑照常执行——is_running 复位、信号断开、上下文与指令清理）
	if not _terminal_emitted:
		if is_canceling:
			execution_canceled.emit(cancellation_reason)
		else:
			execution_completed.emit()

	# 重置取消状态
	is_canceling = false
	cancellation_reason = ""

	_log_debug_localized("FUSE_LOG_ACTION_RUNNER_COMPLETED")

## 添加指令
## instruction: BaseInstruction - 要添加的指令
## position: int - 插入位置，-1 表示末尾
func add_instruction(instruction: BaseInstruction, position: int = -1):
	if not instruction:
		_log_error("Cannot add null instruction")
		return

	if instructions.size() >= MAX_INSTRUCTIONS:
		_log_error("Cannot add instruction: maximum limit reached")
		return

	if position < 0 or position >= instructions.size():
		instructions.append(instruction)
	else:
		instructions.insert(position, instruction)

	# 清除验证缓存（新指令可能影响验证结果）
	_validation_cache.clear()

	_log_debug_localized("FUSE_LOG_INSTRUCTION_ADDED", {"position": str(position), "description": instruction.get_description()})

## 移除指令
## position: int - 要移除的指令位置
func remove_instruction(position: int):
	if position < 0 or position >= instructions.size():
		_log_error("Invalid instruction position: %d" % position)
		return

	var removed = instructions.pop_at(position)

	# 清除验证缓存（移除指令可能影响验证结果）
	_validation_cache.clear()

	_log_debug_localized("FUSE_LOG_INSTRUCTION_REMOVED", {"position": str(position), "description": removed.get_description()})

## 清空所有指令
func clear_instructions():
	instructions.clear()
	_validation_cache.clear()  # 清除验证缓存
	_log_debug_localized("FUSE_LOG_CLEARED_ALL_INSTRUCTIONS")

## 获取指令
## position: int - 指令位置
## returns: BaseInstruction - 指令对象
func get_instruction(position: int) -> BaseInstruction:
	if position < 0 or position >= instructions.size():
		_log_error("Invalid instruction position: %d" % position)
		return null

	var instruction = instructions[position]
	if instruction is BaseInstruction:
		return instruction
	else:
		_log_error("Instruction at position %d is not a BaseInstruction" % position)
		return null

## 获取指令数量
## returns: int - 指令数量
func get_instruction_count() -> int:
	return instructions.size()

## 检查是否包含指定指令
## instruction: BaseInstruction - 要检查的指令
## returns: bool - 是否包含
func has_instruction(instruction: BaseInstruction) -> bool:
	return instructions.has(instruction)

## 获取指令索引
## instruction: BaseInstruction - 要查找的指令
## returns: int - 指令索引，-1 表示未找到
func get_instruction_index(instruction: BaseInstruction) -> int:
	return instructions.find(instruction)

## 统一日志方法
func _log_debug(message: String):
	FuseLogger.log_debug("ActionRunner", log_level, message)

func _log_info(message: String):
	FuseLogger.log_info("ActionRunner", log_level, message)

func _log_warning(message: String):
	FuseLogger.log_warning("ActionRunner", log_level, message)

func _log_error(message: String):
	FuseLogger.log_error("ActionRunner", log_level, message)

## 本地化日志方法
func _log_debug_localized(message_key: String, args: Dictionary = {}) -> void:
	FuseLogger.log_debug_localized("ActionRunner", log_level, message_key, args)

func _log_info_localized(message_key: String, args: Dictionary = {}) -> void:
	FuseLogger.log_info_localized("ActionRunner", log_level, message_key, args)

func _log_warning_localized(message_key: String, args: Dictionary = {}) -> void:
	FuseLogger.log_warning_localized("ActionRunner", log_level, message_key, args)

func _log_error_localized(message_key: String, args: Dictionary = {}) -> void:
	FuseLogger.log_error_localized("ActionRunner", log_level, message_key, args)

## 序列化执行器
## returns: Dictionary - 序列化后的数据
func serialize() -> Dictionary:
	return {
		"execution_mode": execution_mode,
		"stop_on_error": stop_on_error,
		"instructions": _serialize_instructions()
	}

## 序列化指令
## returns: Array[Dictionary] - 序列化后的指令数据
func _serialize_instructions() -> Array[Dictionary]:
	var serialized = []
	for instruction in instructions:
		if instruction is BaseInstruction:
			# 使用 InstructionSerializer 来序列化指令，确保与反序列化方法兼容
			var instruction_data = InstructionSerializer.serialize_instruction(instruction)
			serialized.append(instruction_data)
	return serialized

## 反序列化执行器
## data: Dictionary - 序列化的数据
func deserialize(data: Dictionary):
	if data.has("execution_mode"):
		execution_mode = data["execution_mode"]

	if data.has("stop_on_error"):
		stop_on_error = data["stop_on_error"]

	if data.has("instructions"):
		instructions.clear()
		for instruction_data in data["instructions"]:
			# 使用 InstructionSerializer 来反序列化指令
			var instruction = InstructionSerializer.deserialize_instruction(instruction_data)
			if instruction:
				instructions.append(instruction)
			else:
				_log_error("无法反序列化指令: %s" % instruction_data)

## 克隆执行器
## returns: ActionRunner - 克隆的执行器
func clone() -> ActionRunner:
	var runner = ActionRunner.new()
	runner.execution_mode = execution_mode
	runner.stop_on_error = stop_on_error
	runner.log_level = log_level

	# 克隆指令
	for instruction in instructions:
		if instruction is BaseInstruction:
			runner.instructions.append(instruction.duplicate())

	return runner

## 获取执行器信息
## returns: Dictionary - 执行器信息
func get_info() -> Dictionary:
	return {
		"is_running": is_running,
		"instruction_count": instructions.size(),
		"execution_mode": ExecutionMode.keys()[execution_mode],
		"stop_on_error": stop_on_error,
		"execution_time": get_execution_status()["execution_time"],
		"progress": get_execution_status()["progress"]
	}

## 设置跳过指令数量
## count: int - 需要跳过的指令数量
func set_skip_instruction_count(count: int):
	_skip_instruction_count = max(0, count)
	_log_debug_localized("FUSE_LOG_INSTRUCTION_COUNT_SET", {"count": str(_skip_instruction_count)})

## 设置停止执行
## stop: bool - 是否停止执行
## reason: String - 停止原因
func set_stop_execution(stop: bool, reason: String = ""):
	_stop_execution = stop
	_stop_reason = reason
	_log_debug_localized("FUSE_LOG_STOP_EXECUTION_SET", {"stop": str(stop), "reason": reason})

## 重置执行器状态
func reset():
	is_running = false
	is_canceling = false
	cancellation_reason = ""
	_fuse_error = null
	_validation_cache.clear()  # 清除验证缓存

	# 重置条件检查相关状态
	_skip_instruction_count = 0
	_stop_execution = false
	_stop_reason = ""

	# 强制清理所有上下文引用
	if current_context:
		current_context.cleanup()
		# 确保上下文被垃圾回收
		current_context = null

	# 清理指令引用
	for instruction in instructions:
		if instruction.has_method("cleanup"):
			instruction.cleanup()

	current_instruction_index = 0
	execution_start_time = 0.0
	execution_end_time = 0.0
	_log_debug_localized("FUSE_LOG_ACTION_RUNNER_RESET")

## 清除验证缓存
## 用于强制重新验证所有指令
func clear_validation_cache():
	_validation_cache.clear()
	_log_debug_localized("FUSE_LOG_VALIDATION_CACHE_CLEARED")

## 批量操作方法

## 批量执行指令
## contexts: Array[ExecutionContext] - 执行上下文数组
## returns: Dictionary - 批量执行结果
func run_batch(contexts: Array[ExecutionContext]) -> Dictionary:
	var results = {
		"success": [],
		"failed": [],
		"total": contexts.size(),
		"success_count": 0,
		"failed_count": 0,
		"execution_times": []
	}

	var start_time = Time.get_ticks_msec() / 1000.0

	for i in range(contexts.size()):
		var context = contexts[i]
		var context_start_time = Time.get_ticks_msec() / 1000.0

		# 使用条件检查代替 try/except
		if not is_running:
			run(context)
			await execution_completed

			var context_end_time = Time.get_ticks_msec() / 1000.0
			var execution_time = context_end_time - context_start_time

			results["success"].append({
				"context_index": i,
				"execution_time": execution_time,
				"context_id": context.execution_id
			})
			results["success_count"] += 1
			results["execution_times"].append(execution_time)
		else:
			results["failed"].append({
				"context_index": i,
				"error": "执行失败 - ActionRunner 正在运行",
				"context_id": context.execution_id
			})
			results["failed_count"] += 1

	var end_time = Time.get_ticks_msec() / 1000.0
	var total_time = end_time - start_time
	var avg_time = total_time / contexts.size() if contexts.size() > 0 else 0.0

	results["total_time"] = total_time
	results["average_time"] = avg_time

	_log_debug_localized("FUSE_LOG_BATCH_EXECUTION_COMPLETE", {
		"success": str(results["success_count"]),
		"total": str(results["total"]),
		"time": str(total_time),
		"avg": str(avg_time)
	})

	return results

## 批量验证指令
## returns: Dictionary - 验证结果
func validate_instructions_batch() -> Dictionary:
	var results = {
		"valid": [],
		"invalid": [],
		"total": instructions.size(),
		"valid_count": 0,
		"invalid_count": 0
	}

	for i in range(instructions.size()):
		var instruction = instructions[i]
		var errors = instruction.validate()

		if errors.is_empty():
			results["valid"].append({
				"index": i,
				"instruction": instruction.get_description()
			})
			results["valid_count"] += 1
		else:
			results["invalid"].append({
				"index": i,
				"instruction": instruction.get_description(),
				"errors": errors
			})
			results["invalid_count"] += 1

	_log_debug_localized("FUSE_LOG_BATCH_INSTRUCTION_VALIDATION_COMPLETE", {
		"valid": str(results["valid_count"]),
		"total": str(results["total"]),
		"invalid": str(results["invalid_count"]),
		"total2": str(results["total"])
	})

	return results

## 批量获取指令信息
## returns: Array[Dictionary] - 指令信息数组
func get_instructions_info_batch() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	for i in range(instructions.size()):
		var instruction = instructions[i]
		var info = instruction.get_debug_info()
		info["index"] = i
		results.append(info)

	_log_debug_localized("FUSE_LOG_BATCH_GET_INSTRUCTION_INFO_COMPLETE", {"count": str(results.size())})
	return results

## 批量添加指令
## new_instructions: Array[BaseInstruction] - 新指令数组
## position: int - 插入位置，-1 表示末尾
## returns: Dictionary - 添加结果
func add_instructions_batch(new_instructions: Array[BaseInstruction], position: int = -1) -> Dictionary:
	var results = {
		"added": [],
		"failed": [],
		"total": new_instructions.size(),
		"added_count": 0,
		"failed_count": 0
	}

	for i in range(new_instructions.size()):
		var instruction = new_instructions[i]

		if instructions.size() >= MAX_INSTRUCTIONS:
			results["failed"].append({
				"index": i,
				"instruction": instruction.get_description(),
				"reason": "达到最大指令限制"
			})
			results["failed_count"] += 1
			continue

		if not instruction:
			results["failed"].append({
				"index": i,
				"instruction": "null",
				"reason": "指令为空"
			})
			results["failed_count"] += 1
			continue

		var actual_position = position
		if position < 0 or position >= instructions.size():
			instructions.append(instruction)
			actual_position = instructions.size() - 1
		else:
			instructions.insert(position + i, instruction)
			actual_position = position + i

		results["added"].append({
			"index": i,
			"instruction": instruction.get_description(),
			"position": actual_position
		})
		results["added_count"] += 1

	_log_debug_localized("FUSE_LOG_BATCH_ADD_INSTRUCTION_COMPLETE", {
		"added": str(results["added_count"]),
		"total": str(results["total"]),
		"failed": str(results["failed_count"]),
		"total2": str(results["total"])
	})

	return results

## 等待所有任务完成
## instructions: Array - 指令数组
func _wait_for_all_tasks(instructions: Array):
	# 收集所有未完成指令的信号
	var pending_signals: Array = []
	var pending_instructions: Array = []

	for i in range(instructions.size()):
		var instruction = instructions[i]
		if not instruction.is_completed() and not instruction.has_error():
			pending_signals.append(instruction.finished)
			pending_instructions.append(instruction)

	# 如果没有待等待的信号，直接返回
	if pending_signals.is_empty():
		return

	_log_debug("等待 %d 个异步指令完成" % pending_signals.size())

	# 使用信号数组并行等待所有指令完成
	while not pending_signals.is_empty():
		var completed_signal_index = await _wait_for_any_signal(pending_signals)

		if completed_signal_index >= 0:
			pending_signals.remove_at(completed_signal_index)
			pending_instructions.remove_at(completed_signal_index)
		else:
			break

## 等待信号数组中的任意一个信号发出
## 返回发出信号的索引，如果所有信号源都已完成则返回 -1
func _wait_for_any_signal(signals: Array) -> int:
	if signals.is_empty():
		return -1

	# 创建一个一次性信号聚合器
	var signal_aggregator = _SignalAggregator.new()
	signal_aggregator.setup(signals)

	# 等待任意一个信号
	var result = await signal_aggregator.any_completed
	return result

## 内部信号聚合器类，用于并行等待多个信号
class _SignalAggregator extends RefCounted:
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

		# 断开所有连接
		_disconnect_all()

		# 发出完成信号
		any_completed.emit(index)

	func _disconnect_all() -> void:
		for conn in _connections:
			if conn.signal.is_connected(conn.callback):
				conn.signal.disconnect(conn.callback)
		_connections.clear()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			if is_instance_valid(self):
				_disconnect_all()

## 创建 FuseError 实例
## message: String - 错误消息
## error_type: FuseError.ErrorType - 错误类型
## context: Dictionary - 错误上下文
func _create_fuse_error(message: String, error_type: FuseError.ErrorType = FuseError.ErrorType.RUNTIME_ERROR, context: Dictionary = {}):
	var error_context = context.duplicate()
	error_context["execution_mode"] = ExecutionMode.keys()[execution_mode]
	error_context["instruction_count"] = instructions.size()

	_fuse_error = FuseError.create_with_context(error_type, "ActionRunner", message, error_context)

## 创建本地化的 FuseError 实例
## message_key: String - 翻译键
## error_type: FuseError.ErrorType - 错误类型
## context: Dictionary - 错误上下文
## args: Dictionary - 翻译参数
func _create_fuse_error_localized(message_key: String, error_type: FuseError.ErrorType = FuseError.ErrorType.RUNTIME_ERROR, context: Dictionary = {}, args: Dictionary = {}):
	var message = FuseLocalization.translate_format(message_key, args)
	_create_fuse_error(message, error_type, context)

## 获取 FuseError 实例
## returns: FuseError - FuseError 实例，如果没有错误则返回 null
func get_fuse_error() -> FuseError:
	return _fuse_error

## 检查是否有 FuseError
## returns: bool - 是否有 FuseError
func has_fuse_error() -> bool:
	return _fuse_error != null

## 指令完成包装器
##
## 包装指令完成事件，确保使用缓存的 callback 断开连接。
##
## 参数：
## - instruction: BaseInstruction - 完成的指令
func _on_instruction_finished_wrapper(instruction: BaseInstruction):
	_disconnect_instruction_signal(instruction)

## 启用调试模式
## 启用执行跟踪和调试功能
func enable_debug():
	_debug_enabled = true
	if not _execution_tracker:
		_execution_tracker = ExecutionTracker.new()
	_log_info_localized("FUSE_LOG_DEBUG_MODE_ENABLED")

## 禁用调试模式
## 禁用执行跟踪和调试功能
func disable_debug():
	_debug_enabled = false
	if _execution_tracker:
		_execution_tracker.clear_execution_history()
	_log_info_localized("FUSE_LOG_DEBUG_MODE_DISABLED")

## 检查调试模式是否启用
## @return: bool - 是否启用调试模式
func is_debug_enabled() -> bool:
	return _debug_enabled

## 获取执行跟踪器
## @return: ExecutionTracker - 执行跟踪器实例
func get_execution_tracker():
	return _execution_tracker

## 记录调试信息
## @param message: String - 调试信息
func _log_debug_info(message: String):
	if _debug_enabled:
		_log_debug("[DEBUG] %s" % message)
