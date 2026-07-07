@tool
class_name ExecutionDiagnostics extends RefCounted

## ExecutionContext 诊断子系统
##
## 管理执行状态机、执行历史、状态变化监听器、
## 进度跟踪、状态统计、依赖关系图与可视化数据。

var _owner: ExecutionContext

# 执行状态管理
var _execution_state: int = 0  # ExecutionState
var _execution_progress: float = 0.0
var _error_message: String = ""
var _is_cancelled: bool = false
var _last_state_change_time: float = 0.0

# 历史记录
var _execution_history: Array[Dictionary] = []
var _max_history_size: int = 100

# 状态变化监听器
var _state_change_listeners: Array[Callable] = []


func _init(owner: ExecutionContext) -> void:
	_owner = owner
	_execution_state = ExecutionContext.ExecutionState.IDLE


# ============================================================
# 执行状态管理
# ============================================================

func get_execution_state() -> int:
	return _execution_state


func set_execution_state(state: int):
	var old_state = _execution_state
	if old_state != state:
		_execution_state = state
		_owner.execution_state_changed.emit(state)
		_record_execution_history(state, "状态变化: %s -> %s" % [
			ExecutionContext.ExecutionState.keys()[old_state],
			ExecutionContext.ExecutionState.keys()[state]
		])
		_notify_state_change(old_state, state)
		_owner._log_debug("Execution state changed to: %s" % ExecutionContext.ExecutionState.keys()[state])


func reset_execution_state():
	var old_state = _execution_state
	_execution_state = ExecutionContext.ExecutionState.IDLE
	_execution_progress = 0.0
	_error_message = ""
	_is_cancelled = false
	_record_execution_history(ExecutionContext.ExecutionState.IDLE, "状态重置")
	if old_state != ExecutionContext.ExecutionState.IDLE:
		_notify_state_change(old_state, ExecutionContext.ExecutionState.IDLE)


func is_running() -> bool:
	return _execution_state == ExecutionContext.ExecutionState.RUNNING


func is_completed() -> bool:
	return _execution_state == ExecutionContext.ExecutionState.COMPLETED


func has_error() -> bool:
	return _execution_state == ExecutionContext.ExecutionState.ERROR


func is_cancelled() -> bool:
	return _is_cancelled or _execution_state == ExecutionContext.ExecutionState.CANCELLED


func request_cancel():
	if _execution_state == ExecutionContext.ExecutionState.RUNNING:
		_is_cancelled = true
		set_execution_state(ExecutionContext.ExecutionState.CANCELLED)
		_owner.cancel_requested.emit()


# ---- 进度 ----

func get_execution_progress() -> float:
	return _execution_progress


func set_execution_progress(progress: float):
	var old_progress = _execution_progress
	_execution_progress = clamp(progress, 0.0, 1.0)
	if abs(old_progress - _execution_progress) > 0.01:
		_record_execution_history(_execution_state, "进度更新", {
			"old_progress": old_progress, "new_progress": _execution_progress,
			"progress_delta": _execution_progress - old_progress
		})


# ---- 错误 ----

func get_error_message() -> String:
	return _error_message


func set_error_message(message: String, error_type: int = 0, context: Dictionary = {}):
	_error_message = message
	set_execution_state(ExecutionContext.ExecutionState.ERROR)


# ============================================================
# 历史记录
# ============================================================

func _record_execution_history(state: int, message: String = "", data: Dictionary = {}):
	var history_entry = {
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"state": state,
		"state_name": ExecutionContext.ExecutionState.keys()[state],
		"message": message,
		"progress": _execution_progress,
		"execution_time": _owner.get_execution_time(),
		"data": data.duplicate()
	}
	_execution_history.append(history_entry)
	if _execution_history.size() > _max_history_size:
		_execution_history.pop_front()
	_last_state_change_time = Time.get_ticks_msec() / 1000.0


func get_execution_history(limit: int = 0) -> Array[Dictionary]:
	if limit <= 0 or limit >= _execution_history.size():
		return _execution_history.duplicate()
	else:
		return _execution_history.slice(-limit).duplicate()


func clear_execution_history():
	_execution_history.clear()


# ============================================================
# 状态变化监听器
# ============================================================

func add_state_change_listener(listener: Callable):
	if not _state_change_listeners.has(listener):
		_state_change_listeners.append(listener)


func remove_state_change_listener(listener: Callable):
	if _state_change_listeners.has(listener):
		_state_change_listeners.erase(listener)


func _notify_state_change(old_state: int, new_state: int):
	for listener in _state_change_listeners:
		if listener.is_valid():
			listener.call(old_state, new_state, _owner)


# ============================================================
# 状态统计
# ============================================================

func get_state_statistics() -> Dictionary:
	var state_counts = {}
	var total_time_in_states = {}
	for state in ExecutionContext.ExecutionState.values():
		state_counts[ExecutionContext.ExecutionState.keys()[state]] = 0
		total_time_in_states[ExecutionContext.ExecutionState.keys()[state]] = 0.0
	for i in range(_execution_history.size()):
		var entry = _execution_history[i]
		state_counts[entry["state_name"]] += 1
		if i < _execution_history.size() - 1:
			total_time_in_states[entry["state_name"]] += _execution_history[i + 1]["timestamp"] - entry["timestamp"]
	return {
		"total_history_entries": _execution_history.size(),
		"state_counts": state_counts,
		"total_time_in_states": total_time_in_states,
		"last_state_change_time": _last_state_change_time,
		"current_state_duration": Time.get_ticks_msec() / 1000.0 - _last_state_change_time
	}


func get_recent_state_changes(count: int = 10) -> Array[Dictionary]:
	var recent_changes = []
	for i in range(_execution_history.size() - 1, -1, -1):
		var entry = _execution_history[i]
		if i > 0 and _execution_history[i - 1]["state"] != entry["state"]:
			recent_changes.append(entry)
			if recent_changes.size() >= count: break
		elif i == 0:
			recent_changes.append(entry)
	recent_changes.reverse()
	return recent_changes


# ============================================================
# 依赖关系图
# ============================================================

func get_dependency_graph() -> Dictionary:
	var graph = {
		"nodes": [], "edges": [],
		"context_info": {
			"execution_id": _owner.execution_id,
			"target": _owner.target.get_name() if _owner.target else "null",
			"trigger": _owner.trigger.get_name() if _owner.trigger else "null",
			"execution_time": _owner.get_execution_time()
		}
	}
	var all_variables = _collect_all_variables()
	for var_name in all_variables:
		graph["nodes"].append({"id": var_name, "label": var_name, "type": "variable",
			"value": str(all_variables[var_name]), "exists": true})
	return graph


func _collect_all_variables() -> Dictionary:
	var all_vars = {}
	for var_name in _owner.local_variables:
		all_vars[var_name] = _owner.local_variables[var_name]
	return all_vars


func check_dependencies(dependencies: Array[String]) -> Dictionary:
	var result = {"satisfied": true, "missing_dependencies": [], "dependency_details": {}}
	for dep_var in dependencies:
		var exists = _owner.has_variable(dep_var)
		var value = _owner.get_variable(dep_var) if exists else null
		result["dependency_details"][dep_var] = {"exists": exists, "value": value,
			"type": typeof(value) if value != null else TYPE_NIL}
		if not exists:
			result["satisfied"] = false
			result["missing_dependencies"].append(dep_var)
	return result


func get_dependency_status() -> Dictionary:
	return {
		"total_variables": _collect_all_variables().size(),
		"total_conditions": 0,
		"variable_dependencies": {},
		"condition_dependencies": {}
	}


func check_dependencies_batch(dependencies_list: Array) -> Array:
	var results: Array = []
	for dependencies in dependencies_list:
		results.append(check_dependencies(dependencies))
	return results


func get_dependency_visualization_data() -> Dictionary:
	return {
		"graph": get_dependency_graph(),
		"status": get_dependency_status(),
		"context_info": {
			"execution_id": _owner.execution_id,
			"execution_time": _owner.get_execution_time(),
			"execution_state": ExecutionContext.ExecutionState.keys()[_execution_state],
			"progress": _execution_progress
		}
	}


# ============================================================
# 复制
# ============================================================

## 深拷贝诊断子系统（用于 ExecutionContext.duplicate）
## 所有可变状态（执行状态/进度/历史/统计）独立拷贝，监听器列表拷贝但 Callable 共享引用。
func duplicate(p_deep: bool = true) -> ExecutionDiagnostics:
	var copy := ExecutionDiagnostics.new(_owner)
	copy._execution_state = _execution_state
	copy._execution_progress = _execution_progress
	copy._error_message = _error_message
	copy._is_cancelled = _is_cancelled
	copy._last_state_change_time = _last_state_change_time
	copy._max_history_size = _max_history_size
	# 历史深拷贝：每个 entry 的 data 子字典也独立
	copy._execution_history = _execution_history.duplicate(true)
	# 监听器：Callable 是引用语义，列表容器独立即可
	copy._state_change_listeners = _state_change_listeners.duplicate()
	return copy


# ============================================================
# cleanup
# ============================================================

func cleanup():
	_execution_history.clear()
	_state_change_listeners.clear()
	_execution_state = ExecutionContext.ExecutionState.IDLE
	_execution_progress = 0.0
	_error_message = ""
	_is_cancelled = false
