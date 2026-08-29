@tool
class_name VariableContext extends RefCounted

## ExecutionContext 变量子系统
##
## 管理 local / scope / global 三层变量作用域,提供:
## - 变量 CRUD(set/get/has/add)
## - 变量名缓存(LRU)和索引访问优化
## - 作用域容器查找(ScopeVariableManager)
## - 全局变量访问(GlobalVariableAssistant)
## - 变量快照(断点调试)
## - 循环控制标志(break/continue/nested stack)
##
## 通过 _owner 引用获取节点信息(target/trigger/owner)用于作用域查找。

var _owner: ExecutionContext

# 变量存储
var local_variables: Dictionary = {}
var global_variables = null
var _global_variable_assistant: GlobalVariableAssistant = null

# 变量名缓存(LRU)
var _variable_name_cache: Dictionary = {}
var _cache_max_size: int = 1000
var _cache_access_order: Array = []

# 索引访问优化
var _variable_index_map: Dictionary = {}
var _variable_array: Array = []
var _use_indexed_access: bool = false

# 循环控制标志
var _break_loop_flag: bool = false
var _continue_loop_flag: bool = false
var _loop_flag_stack: Array[Dictionary] = []


func _init(owner: ExecutionContext) -> void:
	_owner = owner


# ============================================================
# 变量 CRUD(从 EC 迁入,逻辑完全不变)
# ============================================================

## 添加变量(接受 BaseVariable)
func add_variable(name: String, variable: BaseVariable) -> bool:
	if not variable or not variable.is_initialized:
		_owner._log_error_localized("FUSE_ERROR_INVALID_VARIABLE_OBJECT")
		return false
	var scope_name := "local"
	if variable.scope == BaseVariable.VariableScope.GLOBAL:
		scope_name = "global"
	return set_variable(name, variable.value, scope_name)


## 设置变量(三层作用域分发)
func set_variable(name: String, value: Variant, scope: String = "local") -> bool:
	if name.is_empty():
		_owner._log_error_localized("FUSE_ERROR_VARIABLE_NAME_CANNOT_BE_EMPTY")
		return false
	match scope:
		"scope":  return _set_scope_variable(name, value)
		"global": return _set_global_variable(name, value)
		"local":  return _set_local_variable(name, value)
		_:
			_owner._log_error_localized("FUSE_ERROR_UNKNOWN_VARIABLE_SCOPE", {"scope": scope})
			return false


## 获取变量值(三层作用域分发)
func get_variable(name: String, default: Variant = null, scope: String = "local") -> Variant:
	if OS.is_debug_build() and _owner.log_level >= FuseLogger.LogLevel.DEBUG:
		_owner._log_debug("ExecutionContext.get_variable called: name='%s', default=%s" % [name, str(default)])
		_owner._log_debug("ExecutionContext ID: %s" % _owner.execution_id)
		_owner._log_debug("Local variables count: %d" % local_variables.size())
	if name.is_empty():
		_owner._log_error_localized("FUSE_ERROR_VARIABLE_NAME_CANNOT_BE_EMPTY")
		return default
	match scope:
		"scope":  return _get_scope_variable(name, default)
		"global": return _get_global_variable(name, default)
		"local":  pass  # continue below
		_:
			_owner._log_error_localized("FUSE_ERROR_UNKNOWN_VARIABLE_SCOPE", {"scope": scope})
			return default

	# local scope lookup
	var name_key = _get_cached_name_key(name)
	if local_variables.has(name_key):
		var value = local_variables[name_key]
		if OS.is_debug_build() and _owner.log_level >= FuseLogger.LogLevel.DEBUG:
			_owner._log_debug("Retrieved local variable '%s': %s (type: %s)" % [name, str(value), typeof(value)])
		return value

	# fallback: check global
	if _global_variable_assistant != null:
		var global_var = _global_variable_assistant.get_global_variable(name)
		if global_var != null and global_var is BaseVariable:
			var value = global_var.get_value()
			if OS.is_debug_build() and _owner.log_level >= FuseLogger.LogLevel.DEBUG:
				_owner._log_debug("Retrieved global variable '%s': %s (type: %s)" % [name, str(value), typeof(value)])
			return value
	elif global_variables != null and global_variables.has_method("get"):
		var global_var = global_variables.get(name, null)
		if global_var != null:
			if global_var is BaseVariable:
				return global_var.get_value()
			else:
				return global_var

	if OS.is_debug_build() and _owner.log_level >= FuseLogger.LogLevel.DEBUG:
		_owner._log_debug("All local variables:")
		for var_name in local_variables:
			_owner._log_debug("  %s = %s (type: %s)" % [var_name, str(local_variables[var_name]), typeof(local_variables[var_name])])
	if OS.is_debug_build() and _owner.log_level >= FuseLogger.LogLevel.DEBUG:
		_owner._log_debug("Variable '%s' not found, returning default: %s" % [name, str(default)])
	return default


## 获取变量对象(高级 API)
func get_variable_object(name: String) -> BaseVariable:
	if name.is_empty():
		_owner._log_error_localized("FUSE_ERROR_VARIABLE_NAME_CANNOT_BE_EMPTY")
		return null
	var name_key = _get_cached_name_key(name)
	if local_variables.has(name_key):
		return _create_temporary_variable(name, local_variables[name_key])
	if global_variables:
		if global_variables.has_method("get"):
			var global_var = global_variables.get(name, null)
			if global_var is BaseVariable:
				return global_var
	_owner._log_debug("Variable object '%s' not found" % name)
	return null


func _create_temporary_variable(name: String, value: Variant) -> BaseVariable:
	return BaseVariable.create(name, value, BaseVariable.VariableScope.LOCAL)


## 检查变量是否存在
func has_variable(name: String) -> bool:
	if name.is_empty():
		return false
	var name_key = _get_cached_name_key(name)
	if _use_indexed_access:
		var index = _variable_index_map.get(name_key, -1)
		if index >= 0:
			return true
	if local_variables.has(name_key):
		return true
	if _global_variable_assistant != null:
		return _global_variable_assistant.has_global_variable(name)
	elif global_variables != null:
		if global_variables.has_method("has"):
			return global_variables.has(name)
		elif global_variables is Dictionary:
			return global_variables.has(name)
	return false


# ============================================================
# 作用域变量(scoped)
# ============================================================

func _find_scope_container() -> ScopeVariableContainer:
	var manager = ScopeVariableManager.get_instance()
	if manager == null:
		return null
	if _owner.trigger != null:
		var scope = manager.find_nearest_scope(_owner.trigger)
		if scope != null: return scope
	if _owner.target != null:
		var scope = manager.find_nearest_scope(_owner.target)
		if scope != null: return scope
	if _owner.owner != null:
		var scope = manager.find_nearest_scope(_owner.owner)
		if scope != null: return scope
	return null


func _set_scope_variable(name: String, value: Variant) -> bool:
	var scope_container = _find_scope_container()
	if scope_container != null:
		return scope_container.set_variable(name, value)
	# B7：未找到 scope 容器属于配置错误（trigger/target/owner 不在 ScopeVariableContainer 树下），
	# 升级为 error 以避免静默错位；同时保留 fallback 到 LOCAL 不破坏既有契约
	push_error("未找到作用域容器，回退到本地变量: %s" % name)
	return _set_local_variable(name, value)


func _get_scope_variable(name: String, default: Variant) -> Variant:
	var scope_container = _find_scope_container()
	if scope_container != null:
		return scope_container.get_variable(name, default)
	# B7：见 _set_scope_variable
	push_error("未找到作用域容器，回退到本地变量: %s" % name)
	return _get_local_variable(name, default)


# ============================================================
# 全局变量
# ============================================================

func _set_global_variable(name: String, value: Variant) -> bool:
	if _global_variable_assistant != null:
		if _global_variable_assistant.has_global_variable(name):
			var existing_var = _global_variable_assistant.get_global_variable(name)
			if existing_var != null:
				existing_var.set_value(value)
				_owner._log_debug_localized("FUSE_LOG_GLOBAL_VARIABLE_UPDATED", {"name": name, "value": str(value)})
				return true
			else:
				_owner._log_error_localized("FUSE_ERROR_GLOBAL_VARIABLE_RETRIEVAL_FAILED", {"name": name})
				return false
		else:
			var new_variable = BaseVariable.create(name, value, BaseVariable.VariableScope.GLOBAL)
			if new_variable == null:
				_owner._log_error_localized("FUSE_ERROR_CREATE_GLOBAL_VARIABLE_FAILED", {"name": name})
				return false
			var success = _global_variable_assistant.add_global_variable(name, new_variable)
			if not success:
				_owner._log_error_localized("FUSE_ERROR_ADD_GLOBAL_VARIABLE_FAILED", {"name": name})
				return false
			_owner._log_debug_localized("FUSE_LOG_GLOBAL_VARIABLE_ADDED", {"name": name, "value": str(value)})
			return true
	elif global_variables != null and global_variables.has_method("set"):
		global_variables.set(name, value)
		_owner._log_debug_localized("FUSE_LOG_GLOBAL_VARIABLE_ADDED", {"name": name, "value": str(value)})
		return true
	else:
		_owner._log_error_localized("FUSE_ERROR_GLOBAL_VARIABLE_ASSISTANT_NOT_FOUND")
		return false


func _get_global_variable(name: String, default: Variant) -> Variant:
	if _global_variable_assistant != null:
		var global_var = _global_variable_assistant.get_global_variable(name)
		if global_var != null and global_var is BaseVariable:
			return global_var.get_value()
	elif global_variables != null and global_variables.has_method("get"):
		var global_var = global_variables.get(name, null)
		if global_var != null:
			return global_var.get_value() if global_var is BaseVariable else global_var
	return default


func get_global_variable_assistant() -> GlobalVariableAssistant:
	if _global_variable_assistant == null:
		_global_variable_assistant = GlobalVariableAssistant.get_instance()
	return _global_variable_assistant


func set_global_variable_assistant(assistant: GlobalVariableAssistant):
	_global_variable_assistant = assistant
	global_variables = assistant
	_owner._log_debug("GlobalVariableAssistant 已设置")


# ============================================================
# 本地变量
# ============================================================

func _set_local_variable(name: String, value: Variant) -> bool:
	var name_key = _get_cached_name_key(name)
	if OS.is_debug_build() and _owner.log_level >= FuseLogger.LogLevel.DEBUG:
		_owner._log_debug("Setting local variable '%s': %s (type: %s)" % [name, str(value), typeof(value)])
	if local_variables.has(name_key):
		_owner._log_warning_localized("FUSE_LOG_VARIABLE_ALREADY_EXISTS_OVERWRITING", {"name": name})
	local_variables[name_key] = value
	# B6 同步：若已 precompile，索引数组镜像 LOCAL 字典，避免双轨不一致
	if _use_indexed_access and _variable_index_map.has(name_key):
		_variable_array[_variable_index_map[name_key]] = value
	return true


func _get_local_variable(name: String, default: Variant) -> Variant:
	var name_key = _get_cached_name_key(name)
	if local_variables.has(name_key):
		var value = local_variables[name_key]
		if OS.is_debug_build() and _owner.log_level >= FuseLogger.LogLevel.DEBUG:
			_owner._log_debug("Retrieved local variable '%s': %s (type: %s)" % [name, str(value), typeof(value)])
		return value
	# LOCAL 变量桥：VariableOperations 写入时镜像到 Trigger meta（供 Event 轮询），
	# 临时上下文（如 OnVariableChanged._create_temp_context）经此读到共享值——
	# 只读镜像不回填字典，避免与执行上下文的本地副本产生双写竞争
	if _owner.trigger != null:
		var meta_key := "local_variable_%s" % name
		if _owner.trigger.has_meta(meta_key):
			return _owner.trigger.get_meta(meta_key)
	return default


# ============================================================
# 变量名缓存(LRU)
# ============================================================

func _get_cached_name_key(name: String) -> StringName:
	if _variable_name_cache.size() >= _cache_max_size:
		var remove_count = _cache_max_size / 5
		for i in range(remove_count):
			if _cache_access_order.size() > 0:
				var old_name = _cache_access_order[0]
				_variable_name_cache.erase(old_name)
				_cache_access_order.pop_front()
	if name in _cache_access_order:
		_cache_access_order.erase(name)
	_cache_access_order.append(name)
	if not _variable_name_cache.has(name):
		_variable_name_cache[name] = StringName(name)
	return _variable_name_cache[name]


# ============================================================
# 索引访问优化
# ============================================================

func precompile_variable_access(variable_names: Array[String]):
	_variable_index_map.clear()
	_variable_array.clear()
	_variable_array.resize(variable_names.size())
	for i in range(variable_names.size()):
		var name_key = StringName(variable_names[i])
		_variable_index_map[name_key] = i
	_use_indexed_access = true
	_owner._log_debug("预编译了 %d 个变量索引" % variable_names.size())


func set_variable_by_index(index: int, value: Variant):
	if not _use_indexed_access:
		_owner._log_warning_localized("FUSE_WARNING_INDEXED_ACCESS_NOT_ENABLED")
		return
	if index >= 0 and index < _variable_array.size():
		_variable_array[index] = value
		# B6 同步：反向镜像到 LOCAL 字典，保证 get_variable(name) 与索引读一致
		# 通过 _variable_index_map 反查 name_key
		for name_key in _variable_index_map:
			if _variable_index_map[name_key] == index:
				local_variables[name_key] = value
				break
	else:
		_owner._log_error("索引 %d 超出范围，有效范围: 0-%d" % [index, _variable_array.size() - 1])


func get_variable_by_index(index: int) -> Variant:
	if not _use_indexed_access:
		_owner._log_warning_localized("FUSE_WARNING_INDEXED_ACCESS_NOT_ENABLED")
		return null
	if index >= 0 and index < _variable_array.size():
		return _variable_array[index]
	_owner._log_error("索引 %d 超出范围，有效范围: 0-%d" % [index, _variable_array.size() - 1])
	return null


func get_variable_index(name: String) -> int:
	if not _use_indexed_access:
		return -1
	var name_key = _get_cached_name_key(name)
	return _variable_index_map.get(name_key, -1)


func is_indexed_access_enabled() -> bool:
	return _use_indexed_access


func get_indexed_access_stats() -> Dictionary:
	return {
		"indexed_access_enabled": _use_indexed_access,
		"total_variables": _variable_array.size(),
		"cached_names": _variable_name_cache.size(),
		"index_map_size": _variable_index_map.size()
	}


# ============================================================
# 变量快照(断点调试)
# ============================================================

func get_all_local_variables_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for key in local_variables:
		snapshot[str(key)] = local_variables[key]
	return snapshot


func get_all_scope_variables_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	var scope_container = _find_scope_container()
	if scope_container != null:
		for name in scope_container.get_variable_names():
			snapshot[name] = scope_container.get_variable(name)
	return snapshot


func get_all_global_variables_snapshot() -> Dictionary:
	if _global_variable_assistant != null:
		return _global_variable_assistant.get_all_global_variables_info()
	return {}


# ============================================================
# 循环控制
# ============================================================

func set_break_loop():
	_break_loop_flag = true
	_owner._log_debug_localized("FUSE_LOG_SETTING_BREAK_LOOP_FLAG")


func set_continue_loop():
	_continue_loop_flag = true
	_owner._log_debug_localized("FUSE_LOG_SETTING_CONTINUE_LOOP_FLAG")


func should_break_loop() -> bool:
	return _break_loop_flag


func should_continue_loop() -> bool:
	return _continue_loop_flag


func clear_loop_flags():
	_break_loop_flag = false
	_continue_loop_flag = false
	_owner._log_debug_localized("FUSE_LOG_CLEARING_LOOP_FLAGS")


## 仅清 continue 标志、保留 break——循环执行器中止本迭代剩余指令时用
## （break 需存活到循环头以终止整个循环）
func clear_continue_flag():
	_continue_loop_flag = false


func push_loop_flags():
	_loop_flag_stack.append({"break": _break_loop_flag, "continue": _continue_loop_flag})
	_break_loop_flag = false
	_continue_loop_flag = false
	_owner._log_debug("保存循环标志到栈，栈深度: %d" % _loop_flag_stack.size())


func pop_loop_flags():
	if _loop_flag_stack.is_empty():
		_break_loop_flag = false
		_continue_loop_flag = false
		_owner._log_debug_localized("FUSE_LOG_LOOP_FLAG_STACK_EMPTY")
	else:
		var flags = _loop_flag_stack.pop_back()
		_break_loop_flag = flags["break"]
		_continue_loop_flag = flags["continue"]
		_owner._log_debug("从栈恢复循环标志，栈深度: %d" % _loop_flag_stack.size())


# ============================================================
# cleanup + duplicate
# ============================================================

func cleanup():
	for key in local_variables.keys():
		var value = local_variables[key]
		if is_instance_valid(value) and (value is RefCounted or value is Resource):
			local_variables[key] = null
	local_variables.clear()
	global_variables = null
	_global_variable_assistant = null
	_variable_name_cache.clear()
	_cache_access_order.clear()
	_variable_index_map.clear()
	_variable_array.clear()
	_use_indexed_access = false
	clear_loop_flags()
	_loop_flag_stack.clear()


func duplicate(p_deep: bool = true) -> VariableContext:
	var copy = VariableContext.new(_owner)
	copy.local_variables = local_variables.duplicate()
	copy._variable_name_cache = _variable_name_cache.duplicate()
	copy._variable_index_map = _variable_index_map.duplicate()
	copy._variable_array = _variable_array.duplicate()
	copy._use_indexed_access = _use_indexed_access
	copy.global_variables = global_variables
	copy._global_variable_assistant = _global_variable_assistant
	copy._break_loop_flag = _break_loop_flag
	copy._continue_loop_flag = _continue_loop_flag
	return copy
