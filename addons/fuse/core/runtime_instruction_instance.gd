# addons/fuse/core/runtime_instruction_instance.gd
@tool
class_name RuntimeInstructionInstance extends RefCounted

## 运行时指令实例类
##
## 提供轻量级的运行时指令实例，避免不必要的资源复制。
## 这个类包装了指令定义，并为每个执行提供独立的运行时状态。
##
## 架构设计：
## - 与 RuntimeEventInstance/RuntimeActionRunnerInstance 保持一致
## - 使用 runtime_state 字典存储运行时状态
## - 通过信号转发机制确保独立回调
##
## 修订说明：
## - 添加信号多次触发保护
## - 添加 SceneTreeTimer 信号断开机制
## - 添加错误处理（使用条件检查，GDScript 不支持 try-catch）
## - 添加执行超时机制
## - 添加暂停/恢复功能

## 信号
signal finished()                           ## 执行完成信号
signal error_occurred(message: String)      ## 执行出错信号
signal paused()                             ## 暂停信号
signal resumed()                            ## 恢复信号
signal timeout()                            ## 超时信号

## 属性
var instruction: BaseInstruction            ## 指令定义资源
var runtime_state: Dictionary = {}          ## 运行时状态字典
var execution_context: ExecutionContext     ## 执行上下文
var owner_runner: RuntimeActionRunnerInstance  ## 拥有此实例的 ActionRunner
var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.INFO  ## 日志级别

## 超时配置
var execution_timeout: float = 0.0          ## 执行超时时间（0 表示无超时）

## 内部状态
var _is_executing: bool = false
var _is_completed: bool = false
var _is_paused: bool = false
var _has_error: bool = false
var _error_message: String = ""

## 超时相关
var _timeout_timer: SceneTreeTimer = null
var _paused_time: float = 0.0
var _pause_start_time: float = 0.0

## 信号连接追踪（用于清理）
var _connected_timer_callbacks: Array[Callable] = []

## 构造函数
func _init(inst: BaseInstruction, context: ExecutionContext, runner: RuntimeActionRunnerInstance = null):
	instruction = inst
	execution_context = context
	owner_runner = runner

	# 同步日志级别
	if instruction:
		log_level = instruction.log_level

	# 初始化运行时状态
	_initialize_runtime_state()

	_log_debug("RuntimeInstructionInstance 创建完成: %s" % get_description())

## 初始化运行时状态
##
## 优先使用指令的自声明状态模式，回退到遗留模式
func _initialize_runtime_state():
	if not instruction:
		_log_warning("没有指令定义，无法初始化运行时状态")
		return

	# 新架构：检查指令是否实现了自声明状态模式
	if instruction.has_method("get_default_runtime_state"):
		var declared_state = instruction.get_default_runtime_state()
		runtime_state = declared_state.duplicate(true)
		_log_debug("使用指令自声明状态模式初始化: %s" % instruction.get_name())
	else:
		# 遗留架构：使用默认状态
		runtime_state["timer"] = null
		runtime_state["elapsed_time"] = 0.0
		runtime_state["is_running"] = false

	# 确保基础状态存在
	_ensure_base_states()

## 确保基础状态存在
func _ensure_base_states():
	if not runtime_state.has("initialized"):
		runtime_state["initialized"] = true
	if not runtime_state.has("execution_status"):
		runtime_state["execution_status"] = BaseInstruction.ExecutionStatus.PENDING

## 执行指令（同步包装器）
##
## 返回：
## - bool - 是否同步完成（true=同步，false=需要异步等待）
func execute_sync() -> bool:
	# 性能优化：日志级别前置检查
	var should_log_debug = log_level >= FuseLogger.LogLevel.DEBUG
	var should_log_warning = log_level >= FuseLogger.LogLevel.WARNING

	if _is_executing:
		if should_log_warning:
			_log_warning("指令已在执行中")
		return true

	# 修复：如果已完成，不允许重新执行
	if _is_completed:
		if should_log_warning:
			_log_warning("指令已完成，无法重新执行")
		return true

	_is_executing = true
	_is_completed = false
	_is_paused = false
	_has_error = false
	_error_message = ""
	_paused_time = 0.0
	_pause_start_time = 0.0

	runtime_state["execution_status"] = BaseInstruction.ExecutionStatus.RUNNING

	# 新增：启动超时计时器
	_start_timeout_timer()

	var result = true

	# 修复：GDScript 不支持 try-catch，使用条件检查代替
	# 检查指令是否需要运行时实例模式
	if instruction == null:
		_handle_execution_error("指令为空")
		return true

	if not is_instance_valid(instruction):
		_handle_execution_error("指令无效")
		return true

	if instruction.has_method("execute_with_runtime_instance"):
		# 新模式：传递运行时实例给指令
		# 修复：需要连接信号以处理异步完成的情况
		if instruction.finished.is_connected(_on_instruction_finished):
			instruction.finished.disconnect(_on_instruction_finished)
		instruction.finished.connect(_on_instruction_finished)

		result = instruction.execute_with_runtime_instance(self)

		# 修复：如果指令同步完成了（execute_sync 返回 true），直接完成
		# 注意：如果信号已经触发，_is_completed 可能已经被设置为 true
		if result and instruction.is_completed() and not _is_completed:
			# 断开信号（因为指令已完成但信号回调可能还没执行）
			if instruction.finished.is_connected(_on_instruction_finished):
				instruction.finished.disconnect(_on_instruction_finished)
			_complete_execution()
	else:
		# 兼容模式：直接执行指令，但需要包装回调
		result = _execute_legacy_mode()

	return result

## 遗留模式执行
##
## 为不支持运行时实例的指令提供兼容执行
func _execute_legacy_mode() -> bool:
	if not instruction:
		_handle_execution_error("指令为空")
		return true

	# 连接指令的 finished 信号
	if instruction.finished.is_connected(_on_instruction_finished):
		instruction.finished.disconnect(_on_instruction_finished)
	instruction.finished.connect(_on_instruction_finished)

	# 执行指令
	var sync_completed = instruction.execute_sync(execution_context)

	return sync_completed

## 指令完成回调（遗留模式）
func _on_instruction_finished():
	# 断开信号
	if instruction and instruction.finished.is_connected(_on_instruction_finished):
		instruction.finished.disconnect(_on_instruction_finished)

	_complete_execution()

## 完成执行
func _complete_execution():
	# 修复：防止多次触发
	if _is_completed:
		return

	# 停止超时计时器
	_stop_timeout_timer()

	_is_executing = false
	_is_completed = true
	_is_paused = false
	runtime_state["execution_status"] = BaseInstruction.ExecutionStatus.COMPLETED

	finished.emit()

## 处理执行错误
func _handle_execution_error(message: String):
	_has_error = true
	_error_message = message
	runtime_state["execution_status"] = BaseInstruction.ExecutionStatus.ERROR

	_stop_timeout_timer()
	_is_executing = false
	_is_completed = true

	_log_error(message)
	error_occurred.emit(message)
	finished.emit()

## 新增：暂停执行
func pause() -> bool:
	# 性能优化：日志级别前置检查
	var should_log_debug = log_level >= FuseLogger.LogLevel.DEBUG
	var should_log_warning = log_level >= FuseLogger.LogLevel.WARNING

	if not _is_executing or _is_paused:
		if should_log_warning:
			_log_warning("无法暂停：指令未在执行或已暂停")
		return false

	_is_paused = true
	_pause_start_time = Time.get_ticks_msec() / 1000.0
	runtime_state["is_paused"] = true

	# 通知指令暂停（如果支持）
	if instruction and instruction.has_method("on_runtime_pause"):
		instruction.on_runtime_pause(self)

	if should_log_debug:
		_log_debug("指令执行已暂停: %s" % get_description())
	paused.emit()
	return true

## 新增：恢复执行
func resume() -> bool:
	# 性能优化：日志级别前置检查
	var should_log_debug = log_level >= FuseLogger.LogLevel.DEBUG
	var should_log_warning = log_level >= FuseLogger.LogLevel.WARNING

	if not _is_paused:
		if should_log_warning:
			_log_warning("无法恢复：指令未暂停")
		return false

	# 计算暂停时长
	var pause_duration = Time.get_ticks_msec() / 1000.0 - _pause_start_time
	_paused_time += pause_duration

	_is_paused = false
	runtime_state["is_paused"] = false

	# 通知指令恢复（如果支持）
	if instruction and instruction.has_method("on_runtime_resume"):
		instruction.on_runtime_resume(self)

	if should_log_debug:
		_log_debug("指令执行已恢复: %s" % get_description())
	resumed.emit()
	return true

## 取消执行
func cancel():
	if not _is_executing:
		return

	_is_executing = false
	_is_completed = true
	_is_paused = false
	runtime_state["execution_status"] = BaseInstruction.ExecutionStatus.CANCELLED

	# 停止超时计时器
	_stop_timeout_timer()

	# 清理运行时状态中的资源
	_cleanup_runtime_resources()

	_log_debug("指令执行已取消: %s" % get_description())

## 新增：启动超时计时器
func _start_timeout_timer():
	if execution_timeout <= 0:
		return

	var scene_tree = Engine.get_main_loop()
	if not scene_tree:
		return

	_timeout_timer = scene_tree.create_timer(execution_timeout)
	_timeout_timer.timeout.connect(_on_execution_timeout)

	_log_debug("启动超时计时器: %.2fs" % execution_timeout)

## 新增：停止超时计时器
func _stop_timeout_timer():
	if _timeout_timer:
		# SceneTreeTimer 无法取消，但可以断开连接
		if _timeout_timer.timeout.is_connected(_on_execution_timeout):
			_timeout_timer.timeout.disconnect(_on_execution_timeout)
		_timeout_timer = null

## 新增：执行超时回调
func _on_execution_timeout():
	if _is_executing and not _is_completed:
		_log_warning("指令执行超时: %s" % get_description())

		_has_error = true
		_error_message = "Execution timeout (%.2fs)" % execution_timeout
		runtime_state["execution_status"] = BaseInstruction.ExecutionStatus.ERROR

		# 清理资源
		_cleanup_runtime_resources()

		_is_executing = false
		_is_completed = true

		timeout.emit()
		error_occurred.emit(_error_message)
		finished.emit()

## 修复：清理运行时资源（包含信号断开）
func _cleanup_runtime_resources():
	# 清理计时器
	if runtime_state.has("timer") and runtime_state["timer"]:
		var timer = runtime_state["timer"]
		if timer is SceneTreeTimer:
			# 修复：断开所有连接的信号
			for callback in _connected_timer_callbacks:
				if timer.timeout.is_connected(callback):
					timer.timeout.disconnect(callback)
			_connected_timer_callbacks.clear()
		runtime_state["timer"] = null

	# 清理其他资源
	runtime_state["is_running"] = false

## 新增：注册计时器回调（用于追踪信号连接）
func register_timer_callback(callback: Callable):
	if callback not in _connected_timer_callbacks:
		_connected_timer_callbacks.append(callback)

## 新增：取消注册计时器回调
func unregister_timer_callback(callback: Callable):
	_connected_timer_callbacks.erase(callback)

## 清理实例
func cleanup():
	_log_debug("开始清理 RuntimeInstructionInstance")

	# 取消正在执行的操作
	if _is_executing:
		cancel()

	# 断开指令的 finished 信号
	if instruction and instruction.finished.is_connected(_on_instruction_finished):
		instruction.finished.disconnect(_on_instruction_finished)

	# 停止超时计时器
	_stop_timeout_timer()

	# 清理运行时状态
	_cleanup_runtime_resources()
	runtime_state.clear()

	# 清除回调追踪
	_connected_timer_callbacks.clear()

	# 清理引用
	instruction = null
	execution_context = null
	owner_runner = null

	_log_debug("RuntimeInstructionInstance 清理完成")

## ============================================
## Phase 2: 对象池化支持
## ============================================

## 重新初始化实例（用于对象池复用）
##
## 当从对象池获取实例时，调用此方法重新初始化状态
##
## 参数：
## - inst: BaseInstruction - 指令定义
## - context: ExecutionContext - 执行上下文
## - runner: RuntimeActionRunnerInstance - 拥有此实例的 ActionRunner
func reinitialize(
	inst: BaseInstruction,
	context: ExecutionContext,
	runner: RuntimeActionRunnerInstance = null
) -> void:
	# 设置新的引用
	instruction = inst
	execution_context = context
	owner_runner = runner

	# 同步日志级别
	if instruction:
		log_level = instruction.log_level

	# 重置执行状态
	_is_executing = false
	_is_completed = false
	_is_paused = false
	_has_error = false
	_error_message = ""
	_paused_time = 0.0
	_pause_start_time = 0.0
	_timeout_timer = null

	# 清空回调追踪
	_connected_timer_callbacks.clear()

	# 重新初始化运行时状态
	runtime_state.clear()
	_initialize_runtime_state()

	_log_debug("实例已重新初始化: %s" % get_description())

## 重置实例状态（用于归还到对象池）
##
## 在归还到对象池前调用，清理所有状态和资源
func reset_for_pool() -> void:
	# 1. 停止超时计时器并断开信号
	_stop_timeout_timer()

	# 2. 断开指令信号连接
	if instruction and instruction.finished.is_connected(_on_instruction_finished):
		instruction.finished.disconnect(_on_instruction_finished)

	# 3. 清理所有计时器回调
	_cleanup_timer_callbacks()

	# 4. 清理运行时资源
	_cleanup_runtime_resources()

	# 5. 重置所有状态变量
	instruction = null
	execution_context = null
	owner_runner = null
	_is_executing = false
	_is_completed = false
	_is_paused = false
	_has_error = false
	_error_message = ""
	_paused_time = 0.0
	_pause_start_time = 0.0
	_timeout_timer = null

	# 6. 清理运行时状态
	runtime_state.clear()

	# 7. 清空回调追踪
	_connected_timer_callbacks.clear()

## 清理计时器回调（内部方法）
func _cleanup_timer_callbacks() -> void:
	for callback in _connected_timer_callbacks:
		if runtime_state.has("timer") and runtime_state["timer"]:
			var timer = runtime_state["timer"]
			if timer is SceneTreeTimer and timer.timeout.is_connected(callback):
				timer.timeout.disconnect(callback)
	_connected_timer_callbacks.clear()

## 获取运行时状态
func get_runtime_state(key: String, default = null):
	return runtime_state.get(key, default)

## 设置运行时状态
func set_runtime_state(key: String, value):
	runtime_state[key] = value
	_log_debug("运行时状态已更新: %s = %s" % [key, str(value)])

## 检查是否已完成
func is_completed() -> bool:
	return _is_completed

## 检查是否有错误
func has_error() -> bool:
	return _has_error

## 获取错误消息
func get_error_message() -> String:
	return _error_message

## 检查是否已暂停
func is_paused() -> bool:
	return _is_paused

## 获取总暂停时间
func get_paused_time() -> float:
	return _paused_time

## 获取描述
func get_description() -> String:
	if instruction:
		return "RuntimeInstructionInstance: %s" % instruction.get_description()
	return "RuntimeInstructionInstance (无指令定义)"

## 获取信息
func get_info() -> Dictionary:
	return {
		"instruction_name": instruction.get_name() if instruction else "none",
		"instruction_description": instruction.get_description() if instruction else "无指令定义",
		"is_executing": _is_executing,
		"is_completed": _is_completed,
		"is_paused": _is_paused,
		"has_error": _has_error,
		"error_message": _error_message,
		"paused_time": _paused_time,
		"execution_timeout": execution_timeout,
		"runtime_state_count": runtime_state.size()
	}

## 验证实例
func validate() -> Array[String]:
	var errors: Array[String] = []

	if not instruction:
		errors.append(FuseLocalization.translate("FUSE_ERROR_NO_INSTRUCTION_DEFINITION"))

	if not execution_context:
		errors.append(FuseLocalization.translate("FUSE_ERROR_NO_EXECUTION_CONTEXT"))

	return errors

## 日志方法
func _log_debug(message: String) -> void:
	FuseLogger.log_debug("RuntimeInstructionInstance", log_level, message)

func _log_info(message: String) -> void:
	FuseLogger.log_info("RuntimeInstructionInstance", log_level, message)

func _log_warning(message: String) -> void:
	FuseLogger.log_warning("RuntimeInstructionInstance", log_level, message)

func _log_error(message: String) -> void:
	FuseLogger.log_error("RuntimeInstructionInstance", log_level, message)
