@tool
class_name ExecutionTracker extends RefCounted

## 执行跟踪器
##
## 提供运行时执行跟踪功能，记录指令执行的详细历史，
## 用于调试和性能分析。

var execution_history: Array[Dictionary] = []
var current_execution: Dictionary = {}
var is_tracking: bool = false
var max_history_size: int = 100
var track_performance_metrics: bool = true
var track_memory_usage: bool = false
var track_variable_changes: bool = true

# 本地化
var _fuse_localization_class: RefCounted = null  # 缓存本地化类引用

func _init():
	# 加载本地化类
	_fuse_localization_class = load("res://addons/fuse/localization/fuse_localization.gd")

## 开始跟踪
## 开始新的执行跟踪会话
## @param context: ExecutionContext - 执行上下文
func start_tracking(context: ExecutionContext) -> void:
	is_tracking = true
	current_execution = {
		"start_time": Time.get_ticks_msec(),
		"context_id": context.execution_id if context else "unknown",
		"steps": [],
		"performance_metrics": {},
		"memory_snapshots": [],
		"variable_changes": []
	}

	# 记录初始性能指标
	if track_performance_metrics:
		_record_initial_performance_metrics()

	# 记录初始内存快照
	if track_memory_usage:
		_record_memory_snapshot("start")

	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		_log_debug(_fuse_localization_class.translate("FUSE_LOG_TRACKING_STARTED") % current_execution.context_id)
	else:
		_log_debug("开始执行跟踪，上下文ID: %s" % current_execution.context_id)

## 记录指令开始
## 记录指令开始执行的信息
## @param instruction: BaseInstruction - 开始执行的指令
## @param context: ExecutionContext - 执行上下文
func record_instruction_start(instruction: BaseInstruction, context: ExecutionContext) -> void:
	if not is_tracking:
		return

	# 安全检查：确保指令对象不为空
	if not instruction:
		if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
			_log_warning(_fuse_localization_class.translate("FUSE_LOG_WARNING_RECORD_NULL_INSTRUCTION_START"))
		else:
			_log_warning("尝试记录空指令的开始")
		return

	var step = {
		"type": "instruction_start",
		"timestamp": Time.get_ticks_msec(),
		"instruction": instruction.get_description() if instruction else "Unknown",
		"instruction_type": _get_instruction_class_name(instruction),
		"context_id": context.execution_id if context else "unknown",
		"instruction_index": _get_instruction_index(instruction, context),
		"performance_data": {}
	}

	# 记录性能数据
	if track_performance_metrics:
		step.performance_data = _collect_performance_metrics()

	# 记录变量状态
	if track_variable_changes:
		step.variable_state = _capture_variable_state(context)

	current_execution.steps.append(step)
	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		_log_debug(_fuse_localization_class.translate("FUSE_LOG_RECORD_INSTRUCTION_START") % instruction.get_description())
	else:
		_log_debug("记录指令开始: %s" % instruction.get_description())

## 记录指令完成
## 记录指令完成执行的信息
## @param instruction: BaseInstruction - 完成执行的指令
## @param context: ExecutionContext - 执行上下文
func record_instruction_complete(instruction: BaseInstruction, context: ExecutionContext) -> void:
	if not is_tracking:
		return

	# 安全检查：确保指令对象不为空
	if not instruction:
		if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
			_log_warning(_fuse_localization_class.translate("FUSE_LOG_WARNING_RECORD_NULL_INSTRUCTION_COMPLETE"))
		else:
			_log_warning("尝试记录空指令的完成")
		return

	var execution_time = instruction.get_execution_time() if instruction.has_method("get_execution_time") else 0.0
	var step = {
		"type": "instruction_complete",
		"timestamp": Time.get_ticks_msec(),
		"instruction": instruction.get_description() if instruction else "Unknown",
		"instruction_type": _get_instruction_class_name(instruction),
		"execution_time": execution_time,
		"context_id": context.execution_id if context else "unknown",
		"instruction_index": _get_instruction_index(instruction, context),
		"success": instruction.is_completed() if instruction and instruction.has_method("is_completed") else false,
		"has_error": instruction.has_error() if instruction and instruction.has_method("has_error") else false,
		"error_message": instruction.get_error_message() if instruction and instruction.has_method("get_error_message") and instruction.has_error() else "",
		"performance_data": {}
	}

	# 记录性能数据
	if track_performance_metrics:
		step.performance_data = _collect_performance_metrics()

	# 记录变量状态变化
	if track_variable_changes:
		step.variable_changes = _detect_variable_changes(context)

	current_execution.steps.append(step)
	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		_log_debug(_fuse_localization_class.translate("FUSE_LOG_RECORD_INSTRUCTION_COMPLETE") % [instruction.get_description(), execution_time])
	else:
		_log_debug("记录指令完成: %s (耗时: %.3f秒)" % [instruction.get_description(), execution_time])

## 记录自定义事件
## 记录执行过程中的自定义事件
## @param event_type: String - 事件类型
## @param event_data: Dictionary - 事件数据
func record_custom_event(event_type: String, event_data: Dictionary) -> void:
	if not is_tracking:
		return

	var event = {
		"type": "custom_event",
		"timestamp": Time.get_ticks_msec(),
		"event_type": event_type,
		"data": event_data.duplicate()
	}

	current_execution.steps.append(event)
	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		_log_debug(_fuse_localization_class.translate("FUSE_LOG_RECORD_CUSTOM_EVENT") % event_type)
	else:
		_log_debug("记录自定义事件: %s" % event_type)

## 记录错误
## 记录执行过程中发生的错误
## @param error_message: String - 错误信息
## @param error_type: String - 错误类型
## @param context: Dictionary - 错误上下文
func record_error(error_message: String, error_type: String = "runtime_error", context: Dictionary = {}) -> void:
	if not is_tracking:
		return

	var error_event = {
		"type": "error",
		"timestamp": Time.get_ticks_msec(),
		"error_message": error_message,
		"error_type": error_type,
		"context": context.duplicate()
	}

	current_execution.steps.append(error_event)
	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		_log_error(_fuse_localization_class.translate("FUSE_LOG_RECORD_EXECUTION_ERROR") % error_message)
	else:
		_log_error("记录执行错误: %s" % error_message)

## 记录性能瓶颈
## 记录检测到的性能瓶颈
## @param bottleneck_type: String - 瓶颈类型
## @param severity: String - 严重程度
## @param details: Dictionary - 详细信息
func record_performance_bottleneck(bottleneck_type: String, severity: String = "medium", details: Dictionary = {}) -> void:
	if not is_tracking:
		return

	var bottleneck = {
		"type": "performance_bottleneck",
		"timestamp": Time.get_ticks_msec(),
		"bottleneck_type": bottleneck_type,
		"severity": severity,
		"details": details.duplicate()
	}

	current_execution.steps.append(bottleneck)
	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		_log_warning(_fuse_localization_class.translate("FUSE_LOG_RECORD_PERFORMANCE_BOTTLENECK") % [bottleneck_type, severity])
	else:
		_log_warning("记录性能瓶颈: %s (严重程度: %s)" % [bottleneck_type, severity])

## 停止跟踪
## 停止当前执行跟踪会话
func stop_tracking() -> void:
	if not is_tracking:
		return

	var end_time = Time.get_ticks_msec()
	var total_time = end_time - current_execution.get("start_time", 0)

	current_execution["end_time"] = end_time
	current_execution["total_time"] = total_time

	# 记录最终性能指标
	if track_performance_metrics:
		_record_final_performance_metrics()

	# 记录最终内存快照
	if track_memory_usage:
		_record_memory_snapshot("end")

	# 计算执行统计
	_calculate_execution_stats()

	execution_history.append(current_execution.duplicate())

	# 限制历史记录大小
	if execution_history.size() > max_history_size:
		execution_history.pop_front()

	is_tracking = false
	current_execution.clear()

	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		_log_info(_fuse_localization_class.translate("FUSE_LOG_TRACKING_COMPLETED") % (total_time / 1000.0))
	else:
		_log_info("执行跟踪完成，总耗时: %.3f秒" % (total_time / 1000.0))

## 获取执行历史
## 获取所有执行历史记录
## @return: Array[Dictionary] - 执行历史记录数组
func get_execution_history() -> Array[Dictionary]:
	return execution_history.duplicate()

## 获取最近的执行记录
## @param count: int - 要获取的记录数量
## @return: Array[Dictionary] - 最近的执行记录
func get_recent_executions(count: int = 10) -> Array[Dictionary]:
	if execution_history.is_empty():
		return []

	var start_index = max(0, execution_history.size() - count)
	return execution_history.slice(start_index, execution_history.size()).duplicate()

## 获取执行统计
## 获取执行历史的统计信息
## @return: Dictionary - 统计信息
func get_execution_stats() -> Dictionary:
	if execution_history.is_empty():
		return {"error": "没有执行历史"}

	var total_executions = execution_history.size()
	var total_time = 0.0
	var instruction_counts = []
	var error_counts = []
	var performance_issues = []

	for execution in execution_history:
		total_time += execution.get("total_time", 0.0)

		# 统计指令数量
		var instruction_count = 0
		var error_count = 0
		for step in execution.steps:
			if step.type == "instruction_start":
				instruction_count += 1
			elif step.type == "error":
				error_count += 1
			elif step.type == "performance_bottleneck":
				performance_issues.append(step)

		instruction_counts.append(instruction_count)
		error_counts.append(error_count)

	var avg_time = total_time / total_executions if total_executions > 0 else 0.0
	var avg_instructions = instruction_counts.reduce(func(a, b): return a + b, 0) / instruction_counts.size() if instruction_counts.size() > 0 else 0.0
	var total_errors = error_counts.reduce(func(a, b): return a + b, 0)

	return {
		"total_executions": total_executions,
		"total_time": total_time,
		"average_time": avg_time,
		"average_instructions": avg_instructions,
		"total_errors": total_errors,
		"performance_issues": performance_issues.size(),
		"instruction_counts": instruction_counts,
		"error_counts": error_counts
	}

## 清除执行历史
## 清除所有执行历史记录
func clear_execution_history() -> void:
	execution_history.clear()
	current_execution.clear()
	is_tracking = false
	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		_log_info(_fuse_localization_class.translate("FUSE_LOG_EXECUTION_HISTORY_CLEARED"))
	else:
		_log_info("执行历史已清除")

## 设置跟踪配置
## @param config: Dictionary - 跟踪配置
func set_tracking_config(config: Dictionary) -> void:
	if config.has("max_history_size"):
		max_history_size = max(10, config["max_history_size"])

	if config.has("track_performance_metrics"):
		track_performance_metrics = config["track_performance_metrics"]

	if config.has("track_memory_usage"):
		track_memory_usage = config["track_memory_usage"]

	if config.has("track_variable_changes"):
		track_variable_changes = config["track_variable_changes"]

	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		_log_debug(_fuse_localization_class.translate("FUSE_LOG_TRACKING_CONFIG_UPDATED"))
	else:
		_log_debug("跟踪配置已更新")

## 获取跟踪配置
## @return: Dictionary - 当前跟踪配置
func get_tracking_config() -> Dictionary:
	return {
		"max_history_size": max_history_size,
		"track_performance_metrics": track_performance_metrics,
		"track_memory_usage": track_memory_usage,
		"track_variable_changes": track_variable_changes,
		"is_tracking": is_tracking,
		"history_count": execution_history.size()
	}

## 导出执行历史
## 将执行历史导出为JSON格式
## @param file_path: String - 导出文件路径
## @return: bool - 导出是否成功
func export_execution_history(file_path: String) -> bool:
	if execution_history.is_empty():
		if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
			_log_warning(_fuse_localization_class.translate("FUSE_LOG_WARNING_NO_EXECUTION_HISTORY_TO_EXPORT"))
		else:
			_log_warning("没有可导出的执行历史")
		return false

	var export_data = {
		"export_time": Time.get_time_string_from_system(),
		"execution_history": execution_history.duplicate(),
		"stats": get_execution_stats()
	}

	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(export_data, "\t")
		file.store_string(json_string)
		file.close()
		if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
			_log_info(_fuse_localization_class.translate("FUSE_LOG_EXECUTION_HISTORY_EXPORTED") % file_path)
		else:
			_log_info("执行历史已导出到: %s" % file_path)
		return true
	else:
		if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
			_log_error(_fuse_localization_class.translate("FUSE_LOG_ERROR_FAILED_TO_OPEN_EXPORT_FILE") % file_path)
		else:
			_log_error("无法打开文件进行导出: %s" % file_path)
		return false

## 获取当前跟踪状态
## @return: Dictionary - 当前跟踪状态
func get_current_tracking_state() -> Dictionary:
	return {
		"is_tracking": is_tracking,
		"current_execution": current_execution.duplicate() if not current_execution.is_empty() else {},
		"steps_count": current_execution.get("steps", []).size() if not current_execution.is_empty() else 0
	}

## 内部辅助方法

## 获取指令索引
## @param instruction: BaseInstruction - 指令对象
## @param context: ExecutionContext - 执行上下文
## @return: int - 指令索引
func _get_instruction_index(instruction: BaseInstruction, context: ExecutionContext) -> int:
	# 尝试从上下文中获取指令索引
	if context and context.has_method("get_instruction_index"):
		return context.get_instruction_index(instruction)

	# 回退：返回-1表示未知
	return -1

## 获取指令类名
## @param instruction: BaseInstruction - 指令对象
## @return: String - 指令类名
func _get_instruction_class_name(instruction: BaseInstruction) -> String:
	if not instruction:
		return "Unknown"

	var script = instruction.get_script()
	if not script:
		return "Unknown"

	# 使用 get_global_name() 替代 get_class_name()
	return script.get_global_name() if script.has_method("get_global_name") else "Unknown"

## 记录初始性能指标
func _record_initial_performance_metrics():
	if not current_execution.has("performance_metrics"):
		current_execution.performance_metrics = {}

	current_execution.performance_metrics["initial"] = {
		"timestamp": Time.get_ticks_msec(),
		"memory_usage": OS.get_static_memory_usage(),
		"cpu_usage": _get_cpu_usage()
	}

## 记录最终性能指标
func _record_final_performance_metrics():
	if not current_execution.has("performance_metrics"):
		current_execution.performance_metrics = {}

	current_execution.performance_metrics["final"] = {
		"timestamp": Time.get_ticks_msec(),
		"memory_usage": OS.get_static_memory_usage(),
		"cpu_usage": _get_cpu_usage()
	}

## 记录内存快照
## @param phase: String - 快照阶段
func _record_memory_snapshot(phase: String):
	if not current_execution.has("memory_snapshots"):
		current_execution.memory_snapshots = []

	var snapshot = {
		"phase": phase,
		"timestamp": Time.get_ticks_msec(),
		"static_memory": OS.get_static_memory_usage()
	}

	current_execution.memory_snapshots.append(snapshot)

## 收集性能指标
## @return: Dictionary - 性能指标
func _collect_performance_metrics() -> Dictionary:
	return {
		"timestamp": Time.get_ticks_msec(),
		"memory_usage": OS.get_static_memory_usage(),
		"cpu_usage": _get_cpu_usage()
	}

## 获取CPU使用率
## @return: float - CPU使用率百分比
func _get_cpu_usage() -> float:
	# 简化的CPU使用率估算
	# 在实际实现中，可能需要更复杂的逻辑
	return 0.0

## 捕获变量状态
## @param context: ExecutionContext - 执行上下文
## @return: Dictionary - 变量状态快照
func _capture_variable_state(context: ExecutionContext) -> Dictionary:
	if not context:
		return {}

	var state = {
		"timestamp": Time.get_ticks_msec(),
		"local_variables": {},
		"global_variables": {}
	}

	# 捕获局部变量
	# 注意：这里需要访问上下文的内部变量，可能需要添加相应的方法
	if context.has_method("get_all_local_variables"):
		state.local_variables = context.get_all_local_variables()

	# 捕获全局变量
	if context.has_method("get_all_global_variables"):
		state.global_variables = context.get_all_global_variables()

	return state

## 检测变量变化
## @param context: ExecutionContext - 执行上下文
## @return: Array - 变量变化列表
func _detect_variable_changes(context: ExecutionContext) -> Array:
	# 简化的变量变化检测
	# 在实际实现中，需要维护前一个状态并进行比较
	return []

## 计算执行统计
func _calculate_execution_stats():
	if not current_execution.has("steps"):
		return

	var steps = current_execution.steps
	var instruction_count = 0
	var total_execution_time = 0.0
	var error_count = 0
	var performance_issues = 0

	for step in steps:
		match step.type:
			"instruction_start":
				instruction_count += 1
			"instruction_complete":
				total_execution_time += step.get("execution_time", 0.0)
				if step.get("has_error", false):
					error_count += 1
			"performance_bottleneck":
				performance_issues += 1
			"error":
				error_count += 1

	current_execution["stats"] = {
		"instruction_count": instruction_count,
		"total_execution_time": total_execution_time,
		"average_execution_time": total_execution_time / instruction_count if instruction_count > 0 else 0.0,
		"error_count": error_count,
		"performance_issues": performance_issues,
		"success_rate": (instruction_count - error_count) / instruction_count * 100.0 if instruction_count > 0 else 0.0
	}

## 统一日志方法
func _log_debug(message: String):
	FuseLogger.log_debug("ExecutionTracker", FuseLogger.LogLevel.DEBUG, message)

func _log_info(message: String):
	FuseLogger.log_info("ExecutionTracker", FuseLogger.LogLevel.INFO, message)

func _log_warning(message: String):
	FuseLogger.log_warning("ExecutionTracker", FuseLogger.LogLevel.WARNING, message)

func _log_error(message: String):
	FuseLogger.log_error("ExecutionTracker", FuseLogger.LogLevel.ERROR, message)
