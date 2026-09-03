@tool
class_name GlobalVariableManager extends RefCounted

## 全局变量管理器 - 核心服务层
##
## Fuse 全局变量的统一存储和持久化服务。
## - RefCounted 纯逻辑层，不依赖场景树，通过静态单例 get_instance() 访问
## - 变量 CRUD + 信号(variable_added/removed/changed)
## - 持久化(save_to_resource/load_from_resource/save_persistent_to_resource)
## - 线程安全(所有操作受 Mutex 保护)
## - 供 GlobalVariableService / GlobalVariableAssistant 委托，也可直接使用

## 单例实例 - 使用静态初始化避免竞态条件
static var _instance: GlobalVariableManager = GlobalVariableManager.new()

## 简化的存储
var _variables: Dictionary = {}  # 直接存储 BaseVariable
var _resource_path: String = ""

## 线程安全配置
var _mutex: Mutex = Mutex.new()

## 信号
signal variable_added(name: String, variable: BaseVariable)
signal variable_removed(name: String)
signal variable_changed(name: String, old_value: Variant, new_value: Variant)

## 获取单例实例
static func get_instance() -> GlobalVariableManager:
	return _instance

## 检查单例是否存在
static func has_instance() -> bool:
	return _instance != null

## 私有构造函数 - 防止直接实例化
func _init():
	# 静态初始化已保证单例，这里仅记录日志
	_log_info_localized("FUSE_LOG_GLOBAL_VAR_MANAGER_INITIALIZED")

## 简化的变量操作
func add_variable(name: String, variable: BaseVariable) -> bool:
	if name.is_empty() or variable == null:
		_log_error_localized("FUSE_LOG_GLOBAL_VAR_NAME_OR_INSTANCE_EMPTY")
		return false

	_mutex.lock()
	# 断开旧变量信号（如果存在）
	if _variables.has(name):
		var old_var = _variables[name]
		if old_var.value_changed.is_connected(_on_variable_changed):
			old_var.value_changed.disconnect(_on_variable_changed)
	_variables[name] = variable
	_mutex.unlock()

	# 锁外连接新信号
	variable.value_changed.connect(_on_variable_changed.bind(name))
	variable_added.emit(name, variable)
	_log_info_localized("FUSE_LOG_VARIABLE_ADDED", {"name": name})
	return true

func get_variable(name: String) -> BaseVariable:
	_mutex.lock()
	var result = _variables.get(name, null)
	_mutex.unlock()
	return result

func has_variable(name: String) -> bool:
	_mutex.lock()
	var result = _variables.has(name)
	_mutex.unlock()
	return result

func remove_variable(name: String) -> bool:
	_mutex.lock()
	if not _variables.has(name):
		_mutex.unlock()
		return false

	var variable = _variables[name]
	_variables.erase(name)
	_mutex.unlock()

	variable_removed.emit(name)
	_log_info_localized("FUSE_LOG_VARIABLE_REMOVED", {"name": name})
	return true

## 简化的资源操作
func save_to_resource(path: String) -> bool:
	if path.is_empty():
		_log_error_localized("FUSE_ERROR_RESOURCE_PATH_EMPTY")
		return false

	# 使用 GlobalVariableResource 来正确持久化变量
	var resource = GlobalVariableResource.new()
	resource.description = "全局变量存储"

	_mutex.lock()
	for name in _variables:
		var variable = _variables[name]
		var var_data = {
			"value": variable.value,
			"scope": variable.scope,
			"persistent": variable.persistent,
			"description": variable.description
		}
		resource.add_variable(name, var_data)
	_mutex.unlock()

	var error = ResourceSaver.save(resource, path)
	if error != OK:
		_log_error_localized("FUSE_LOG_GLOBAL_VAR_RESOURCE_SAVE_FAILED", {"path": path, "error_code": error})
		return false

	_resource_path = path
	_log_info_localized("FUSE_LOG_GLOBAL_VAR_RESOURCE_SAVED", {"path": path})
	return true

## 仅保存持久化变量到资源文件
func save_persistent_to_resource(path: String) -> bool:
	if path.is_empty():
		_log_error_localized("FUSE_ERROR_RESOURCE_PATH_EMPTY")
		return false

	var resource = GlobalVariableResource.new()
	resource.description = "全局变量存储（仅持久化）"

	_mutex.lock()
	var persistent_count = 0
	for name in _variables:
		var variable = _variables[name]
		if variable.persistent:
			var var_data = {
				"value": variable.value,
				"scope": variable.scope,
				"persistent": true,
				"description": variable.description
			}
			resource.add_variable(name, var_data)
			persistent_count += 1
	_mutex.unlock()

	if persistent_count == 0:
		_log_info_localized("FUSE_LOG_GLOBAL_VAR_NO_PERSISTENT_TO_SAVE")

	var error = ResourceSaver.save(resource, path)
	if error != OK:
		_log_error_localized(
			"FUSE_LOG_GLOBAL_VAR_PERSISTENT_SAVE_FAILED",
			{"path": path, "error_code": error}
		)
		return false

	_log_info_localized(
		"FUSE_LOG_GLOBAL_VAR_PERSISTENT_SAVED",
		{"path": path, "count": persistent_count}
	)
	return true

func load_from_resource(path: String) -> bool:
	if path.is_empty():
		_log_error_localized("FUSE_ERROR_RESOURCE_PATH_EMPTY")
		return false

	var resource = ResourceLoader.load(path)
	if resource == null:
		_log_error_localized("FUSE_LOG_GLOBAL_VAR_RESOURCE_LOAD_FAILED", {"path": path})
		return false

	# 检查是否是 GlobalVariableResource 类型
	var gvr: GlobalVariableResource = null
	if resource is GlobalVariableResource:
		gvr = resource
	else:
		# 向后兼容：尝试从旧的 meta 数据加载
		var data = resource.get_meta("variables", {})
		if data.is_empty():
			_log_warning_localized("FUSE_LOG_GLOBAL_VAR_NO_VARIABLE_DATA", {"path": path})
			return true

		# 将旧格式转换为新格式
		gvr = GlobalVariableResource.new()
		for name in data:
			gvr.add_variable(name, data[name])

	# 清空现有变量（断开旧信号连接）
	_mutex.lock()
	for name in _variables:
		var old_var = _variables[name]
		if old_var.value_changed.is_connected(_on_variable_changed):
			old_var.value_changed.disconnect(_on_variable_changed)
	_variables.clear()

	# 从 GlobalVariableResource 加载变量
	for name in gvr.get_variable_names():
		var var_data = gvr.get_variable(name)
		var variable = BaseVariable.new()
		variable.variable_name = name

		# 处理两种格式：新格式（字典）和旧格式（原始值）
		if var_data is Dictionary and var_data.has("value"):
			# 新格式：{"value": ..., "scope": ..., "persistent": ..., "description": ...}
			variable.value = var_data.get("value", null)
			variable.scope = var_data.get("scope", BaseVariable.VariableScope.LOCAL)
			variable.persistent = var_data.get("persistent", false)
			variable.description = var_data.get("description", "")
		else:
			# 旧格式：直接存储原始值
			variable.value = var_data
			variable.scope = BaseVariable.VariableScope.LOCAL
			variable.persistent = false
			variable.description = ""

		# 连接信号
		variable.value_changed.connect(_on_variable_changed.bind(name))
		_variables[name] = variable

	var var_count = _variables.size()
	_mutex.unlock()

	_resource_path = path
	_log_info_localized("FUSE_LOG_GLOBAL_VAR_RESOURCE_LOADED", {"path": path, "count": var_count})
	return true

## 获取所有变量名称
func get_all_variable_names() -> Array[String]:
	var result: Array[String] = []
	_mutex.lock()
	for key in _variables.keys():
		result.append(key)
	_mutex.unlock()
	return result

## 获取变量数量
func get_variable_count() -> int:
	_mutex.lock()
	var count = _variables.size()
	_mutex.unlock()
	return count

## 清空所有变量
func clear_all_variables():
	_mutex.lock()
	# 断开所有变量信号
	for name in _variables:
		var old_var = _variables[name]
		if old_var.value_changed.is_connected(_on_variable_changed):
			old_var.value_changed.disconnect(_on_variable_changed)
	_variables.clear()
	_mutex.unlock()
	_log_info_localized("FUSE_LOG_ALL_VARIABLES_CLEARED")

## 事件处理
func _on_variable_changed(old_value: Variant, new_value: Variant, variable_name: String):
	_log_debug_localized("FUSE_LOG_VARIABLE_VALUE_CHANGED", {
		"name": variable_name,
		"old_value": str(old_value),
		"new_value": str(new_value)
	})
	variable_changed.emit(variable_name, old_value, new_value)

## 手动通知变量已变化（用于引用类型如 Array/Dictionary 的内容修改）
## 当修改数组/字典的内容而非替换引用时，value_changed 信号不会自动触发
## 调用此方法可以手动触发变化通知，让 GlobalVariableAssistant 知道持久化变量已变化
func notify_variable_content_changed(variable_name: String) -> void:
	_mutex.lock()
	if not _variables.has(variable_name):
		_mutex.unlock()
		_log_warning_localized("FUSE_LOG_GLOBAL_VAR_NOTIFY_NOT_FOUND", {"name": variable_name})
		return

	var variable = _variables[variable_name]
	var current_value = variable.value
	var is_persistent = variable.persistent
	_mutex.unlock()

	_log_debug_localized(
		"FUSE_LOG_GLOBAL_VAR_CONTENT_CHANGED",
		{"name": variable_name, "persistent": is_persistent}
	)
	variable_changed.emit(variable_name, current_value, current_value)

## ============================================
## 线程安全的迭代器方法
## ============================================

## 获取所有变量的快照（深拷贝）
## 用于并行条件检测等需要遍历变量的场景
func get_all_variables_snapshot() -> Dictionary:
	var snapshot = {}

	_mutex.lock()
	for name in _variables:
		var variable = _variables[name]
		snapshot[name] = {
			"value": variable.value,
			"scope": variable.scope,
			"persistent": variable.persistent,
			"description": variable.description
		}
	_mutex.unlock()

	return snapshot

## 获取线程安全的变量迭代器
## 返回变量名称数组和变量的深拷贝，用于安全迭代
func get_variables_safe() -> Dictionary:
	var result = {}

	_mutex.lock()
	for name in _variables:
		var variable = _variables[name]
		result[name] = {
			"value": variable.value,
			"scope": variable.scope,
			"persistent": variable.persistent,
			"description": variable.description,
			"variable_name": variable.variable_name
		}
	_mutex.unlock()

	return result

## 线程安全的变量获取（带默认值）
func get_variable_thread_safe(name: String) -> BaseVariable:
	_mutex.lock()
	var result = _variables.get(name, null)
	_mutex.unlock()
	return result

## 线程安全的变量检查
func has_variable_thread_safe(name: String) -> bool:
	_mutex.lock()
	var result = _variables.has(name)
	_mutex.unlock()
	return result

## 批量获取变量（减少锁开销）
func get_variables_batch_thread_safe(names: Array[String]) -> Dictionary:
	var results = {}

	_mutex.lock()
	for name in names:
		results[name] = _variables.get(name, null)
	_mutex.unlock()

	return results

## 线程安全的变量设置
func set_variable_thread_safe(name: String, variable: BaseVariable) -> bool:
	if name.is_empty() or variable == null:
		return false

	_mutex.lock()
	# 断开旧变量信号（如果存在）
	if _variables.has(name):
		var old_var = _variables[name]
		if old_var.value_changed.is_connected(_on_variable_changed):
			old_var.value_changed.disconnect(_on_variable_changed)
	_variables[name] = variable
	_mutex.unlock()

	# 锁外连接新信号
	variable.value_changed.connect(_on_variable_changed.bind(name))
	return true

## 线程安全的变量值设置
func set_variable_value_thread_safe(name: String, value: Variant) -> bool:
	_mutex.lock()
	var has_var = _variables.has(name)
	if has_var:
		_variables[name].value = value
	_mutex.unlock()

	return has_var

## 统一日志方法
func _log_debug(message: String):
	FuseLogger.log_debug("GlobalVariableManager", FuseLogger.LogLevel.INFO, message)

func _log_info(message: String):
	FuseLogger.log_info("GlobalVariableManager", FuseLogger.LogLevel.INFO, message)

func _log_warning(message: String):
	FuseLogger.log_warning("GlobalVariableManager", FuseLogger.LogLevel.INFO, message)

func _log_error(message: String):
	FuseLogger.log_error("GlobalVariableManager", FuseLogger.LogLevel.INFO, message)

## 本地化日志方法
func _log_debug_localized(message_key: String, args: Dictionary = {}) -> void:
	FuseLogger.log_debug_localized("GlobalVariableManager", FuseLogger.LogLevel.INFO, message_key, args)

func _log_info_localized(message_key: String, args: Dictionary = {}) -> void:
	FuseLogger.log_info_localized("GlobalVariableManager", FuseLogger.LogLevel.INFO, message_key, args)

func _log_warning_localized(message_key: String, args: Dictionary = {}) -> void:
	FuseLogger.log_warning_localized("GlobalVariableManager", FuseLogger.LogLevel.INFO, message_key, args)

func _log_error_localized(message_key: String, args: Dictionary = {}) -> void:
	FuseLogger.log_error_localized("GlobalVariableManager", FuseLogger.LogLevel.INFO, message_key, args)

## 获取调试信息
func get_debug_info() -> String:
	var info = "=== 全局变量管理器调试信息 ===\n"
	info += "资源路径: %s\n" % _resource_path
	info += "变量列表:\n"

	_mutex.lock()
	info += "变量总数: %d\n" % _variables.size()
	for name in _variables:
		var variable = _variables[name]
		info += "  - %s: %s = %s\n" % [name, variable.get_type_name(), str(variable.value)]
	_mutex.unlock()

	return info

## 获取统计信息
func get_statistics() -> Dictionary:
	_mutex.lock()
	var total = _variables.size()
	var persistent_count = 0
	for name in _variables:
		if _variables[name].persistent:
			persistent_count += 1
	_mutex.unlock()

	return {
		"total_variables": total,
		"resource_path": _resource_path,
		"persistent_variables": persistent_count
	}

## 统计持久化变量数量
func _count_persistent_variables() -> int:
	var count = 0
	_mutex.lock()
	for name in _variables:
		if _variables[name].persistent:
			count += 1
	_mutex.unlock()
	return count

## 析构函数
func _notification(what: int):
	if what == NOTIFICATION_PREDELETE:
		_variables.clear()