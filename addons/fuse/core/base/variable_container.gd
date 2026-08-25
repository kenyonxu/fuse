@tool
## ⚠️ 已废弃 - 2026-02-08
##
## VariableContainer 已被废弃，请使用以下替代方案：
## - 局部变量：使用 ExecutionContext.local_variables (Dictionary)
## - 全局变量：使用 GlobalVariableAssistant
##
## 迁移指南：
## 1. OnVariableChanged 事件已重构为使用 GlobalVariableAssistant
## 2. 所有变量操作指令已使用 ExecutionContext 和 GlobalVariableAssistant
## 3. 新代码不应再依赖此类
##
class_name VariableContainer extends Resource

## 动态属性列表
##
## 显式返回 Array[Dictionary]，避免 Godot 4.x 使用 Resource 基类的 Array 返回类型
## 触发 "_get_property_list() should return Array[Dictionary]" 兼容性警告。
func _get_property_list() -> Array[Dictionary]:
	return []

## 变量容器
##
## 用于存储和管理作用域变量的容器类，支持局部变量和全局变量的管理。
##
## 这个类提供了：
## - 分层的变量作用域（局部、全局）
## - 变量的动态添加、获取和删除
## - 变量作用域的清理和管理
## - 变量的序列化和反序列化支持
## - 统一存储系统，提供高性能的变量访问
## - 持久化和运行时变量的分离管理

## 变量作用域
##
## 定义了变量的不同作用域级别：
## - LOCAL: 局部变量，仅在当前执行上下文中存在
## - GLOBAL: 全局变量，在整个应用生命周期内存在
## 注意：为了保持与 BaseVariable 的一致性，TRIGGER 作用域已被移除
enum VariableScope {
	LOCAL = 0,	  ## 局部变量
	GLOBAL = 1	  ## 全局变量
}

## 变量数据结构
class VariableData:
	var value: Variant = null					## 变量值
	var type: Variant.Type = TYPE_NIL			## 变量类型
	var scope: VariableScope = VariableScope.LOCAL  ## 变量作用域
	var timestamp: int = 0					   ## 创建时间戳
	var persistent: bool = false				 ## 是否持久化
	var access_count: int = 0					## 访问次数
	var modification_count: int = 0			  ## 修改次数
	var last_modified: int = 0				   ## 最后修改时间

## 变量容器属性

var _trigger_id: String = ""			  ## 触发器ID
var _creation_time: int = 0			   ## 创建时间
var _auto_create_variables: bool = false  ## 是否自动创建变量（默认为false）

## 数组优化的变量存储（新增）
var _variable_name_to_index: Dictionary = {}  ## 变量名到索引的映射
var _indexed_variables: Array = []  ## 按索引存储的变量数组
var _use_indexed_storage: bool = false  ## 是否使用索引存储

## 变量访问优化缓存（新增）
var _access_cache: Dictionary = {}  ## 变量访问缓存
var _cache_enabled: bool = true  ## 是否启用缓存
var _cache_max_size: int = 100  ## 缓存最大大小

## 缓存配置
var _enable_cache: bool = false		   ## 是否启用缓存
var _cache_duration: float = 2.0		  ## 缓存持续时间（秒）
var _variable_cache: Dictionary = {}	  ## 变量访问缓存
var _cache_timestamps: Dictionary = {}	## 缓存时间戳

## 依赖关系管理
var _variable_dependencies: Dictionary = {}  ## 变量依赖关系
var _variable_dependents: Dictionary = {}	## 变量被依赖关系

## ============================================
## 新的统一存储系统 (Phase 1 - 非破坏性变更)
## ============================================

## 主存储：所有变量的真实数据源（单一真实数据源）
var _variables_data: Dictionary = {}  ## name -> VariableData

## 辅助索引（用于快速查询和分类）
var _scope_index: Dictionary = {	 ## scope -> Array[String]
	VariableScope.LOCAL: [],
	VariableScope.GLOBAL: []
}
var _persistent_index: Array[String] = []  ## 持久化变量名列表
var _runtime_index: Array[String] = []	 ## 运行时变量名列表

## 统一缓存（性能优化）
var _unified_cache: Dictionary = {}   ## name -> cached_value
var _unified_cache_enabled: bool = true
var _unified_cache_max_size: int = 1000
var _unified_cache_timestamps: Dictionary = {}  ## name -> timestamp

## 初始化变量容器
func _init(trigger_id: String = ""):
	_trigger_id = trigger_id
	_creation_time = Time.get_ticks_msec()

## 设置触发器ID
func set_trigger_id(id: String):
	_trigger_id = id

## 获取触发器ID
func get_trigger_id() -> String:
	return _trigger_id

## 添加变量
##
## 向指定作用域添加变量。
##
## 参数：
## - name: String - 变量名称
## - value: Variant - 变量值
## - scope: VariableScope - 变量作用域（默认为 LOCAL）
## - persistent: bool - 是否持久化（默认为 false，即运行时变量）
##
## 返回：
## - bool - 如果添加成功返回 true，如果变量已存在返回 false
func add_variable(name: String, value: Variant, scope: VariableScope = VariableScope.LOCAL, persistent: bool = false) -> bool:
	if name.is_empty():
		_log_error("变量名称不能为空")
		return false

	# 检查变量是否已存在（使用统一存储）
	if _variables_data.has(name):
		_log_error("变量 '%s' 已存在" % name)
		return false

	# 创建变量数据
	var var_data = VariableData.new()
	var_data.value = value
	var_data.type = typeof(value)
	var_data.scope = scope
	var_data.persistent = persistent
	var_data.timestamp = Time.get_ticks_msec()
	var_data.last_modified = var_data.timestamp

	# 使用统一存储
	_set_variable_data(name, var_data)

	# 检查作用域是否有效
	if scope != VariableScope.LOCAL and scope != VariableScope.GLOBAL:
		_log_error("不支持的作用域: %s" % str(scope))
		return false

	_log_debug("添加变量: %s (作用域: %s, 类型: %s, 持久化: %s)" % [
		name, VariableScope.keys()[scope], type_string(typeof(value)), persistent
	])

	return true

## 获取变量
##
## 从指定作用域获取变量值。
##
## 参数：
## - name: String - 变量名称
## - default_value: Variant - 默认值（可选）
## - scope: VariableScope - 变量作用域（默认为 LOCAL）
## - use_cache: bool - 是否使用缓存（默认为 true）
##
## 返回：
## - Variant - 变量值，如果不存在则返回默认值
func get_variable(name: String, default_value: Variant = null, scope: VariableScope = VariableScope.LOCAL, use_cache: bool = true) -> Variant:
	if name.is_empty():
		print("[ERROR][VariableContainer] 变量名称不能为空")
		return default_value

	# 使用统一缓存
	if use_cache and _unified_cache_enabled:
		if _unified_cache.has(name):
			return _unified_cache[name]

	# 从主存储获取
	var data = _get_variable_data(name)
	if data:
		# 更新缓存
		if use_cache and _unified_cache_enabled:
			_unified_cache[name] = data.value
			_unified_cache_timestamps[name] = Time.get_ticks_msec()

		return data.value

	# 变量不存在，返回默认值
	return default_value

## 设置变量值
##
## 更新指定作用域中已存在的变量值。
##
## 参数：
## - name: String - 变量名称
## - value: Variant - 新的变量值
## - scope: VariableScope - 变量作用域（默认为 LOCAL）
## - auto_create: bool - 是否自动创建变量（默认为 false）
##
## 返回：
## - bool - 如果更新成功返回 true，如果变量不存在返回 false
func set_variable(name: String, value: Variant, scope: VariableScope = VariableScope.LOCAL, auto_create: bool = false) -> bool:
	if name.is_empty():
		_log_error("变量名称不能为空")
		return false

	var data = _get_variable_data(name)

	if not data:
		# 变量不存在
		if auto_create:
			return add_variable(name, value, scope, false)
		else:
			_log_error("变量 '%s' 不存在" % name)
			return false

	# 更新变量值
	data.value = value
	data.type = typeof(value)
	data.modification_count += 1
	data.last_modified = Time.get_ticks_msec()

	# 使缓存失效
	_invalidate_unified_cache(name)

	# 统一存储系统自动处理索引更新，无需手动操作旧存储

	# 变量值发生变化，清除旧缓存
	if _enable_cache:
		_invalidate_cache_for_variable(name, scope)

	_log_debug("更新变量: %s = %s" % [name, str(value)])
	return true

## 删除变量
##
## 从指定作用域删除变量。
##
## 参数：
## - name: String - 变量名称
## - scope: VariableScope - 变量作用域（默认为 LOCAL）
##
## 返回：
## - bool - 如果删除成功返回 true，如果变量不存在返回 false
func remove_variable(name: String, scope: VariableScope = VariableScope.LOCAL) -> bool:
	if name.is_empty():
		print("[ERROR][VariableContainer] 变量名称不能为空")
		return false

	var data = _get_variable_data(name)
	if not data:
		_log_warning("变量 '%s' 不存在" % name)
		return false

	# 从统一存储删除
	_remove_variable_data(name)

	_log_debug("删除变量: %s" % name)
	return true

## 移除变量数据的内部方法
## name: String - 变量名称
func _remove_variable_data(name: String):
	# 从索引中移除
	_remove_from_indices(name)

	# 从主存储删除
	_variables_data.erase(name)

	# 使缓存失效
	_invalidate_unified_cache(name)

## 检查变量是否存在
##
## 检查指定作用域中是否存在指定名称的变量。
##
## 参数：
## - name: String - 变量名称
## - scope: VariableScope - 变量作用域（默认为 LOCAL）
##
## 返回：
## - bool - 如果变量存在返回 true，否则返回 false
func has_variable(name: String, scope: VariableScope = VariableScope.LOCAL) -> bool:
	return _variables_data.has(name)

## 获取变量信息
##
## 获取指定变量的详细信息。
##
## 参数：
## - name: String - 变量名称
## - scope: VariableScope - 变量作用域（默认为 LOCAL）
##
## 返回：
## - Dictionary - 包含变量信息的字典，如果变量不存在则返回空字典
func get_variable_info(name: String, scope: VariableScope = VariableScope.LOCAL) -> Dictionary:
	if name.is_empty():
		return {}

	var var_data = _get_variable_data(name)

	if var_data:
		return {
			"name": name,
			"value": var_data.value,
			"type": var_data.type,
			"scope": var_data.scope,
			"scope_name": VariableScope.keys()[var_data.scope],
			"timestamp": var_data.timestamp,
			"age": Time.get_ticks_msec() - var_data.timestamp,
			"persistent": var_data.persistent,
			"access_count": var_data.access_count,
			"modification_count": var_data.modification_count,
			"last_modified": var_data.last_modified
		}

	return {}

## 获取所有变量名称
##
## 获取指定作用域中所有变量的名称列表。
##
## 参数：
## - scope: VariableScope - 变量作用域（默认为 LOCAL）
##
## 返回：
## - Array[String] - 变量名称列表
func get_variable_names(scope: VariableScope = VariableScope.LOCAL) -> Array[String]:
	return _get_variable_names_unified(scope)

## 获取所有变量
##
## 获取指定作用域中所有变量的值字典。
##
## 参数：
## - scope: VariableScope - 变量作用域（默认为 LOCAL）
##
## 返回：
## - Dictionary - 变量名称到值的映射字典
func get_all_variables(scope: VariableScope = VariableScope.LOCAL) -> Dictionary:
	var result: Dictionary = {}

	# 使用统一存储的索引
	var scope_keys = _scope_index.get(scope, [])
	for var_name in scope_keys:
		var variable = _variables_data.get(var_name)
		if variable:
			result[var_name] = variable.value

	return result

## 批量操作方法

## 批量设置变量
## variables: Dictionary - 变量名称到值的映射字典
## scope: VariableScope - 变量作用域（默认为 LOCAL）
## auto_create: bool - 是否自动创建变量（默认为 false）
## returns: Dictionary - 包含成功和失败结果的字典
func set_variables_batch(variables: Dictionary, scope: VariableScope = VariableScope.LOCAL, auto_create: bool = false) -> Dictionary:
	var results = {
		"success": [],
		"failed": [],
		"total": variables.size(),
		"success_count": 0,
		"failed_count": 0
	}

	for name in variables:
		var value = variables[name]
		var success = set_variable(name, value, scope, auto_create)

		if success:
			results["success"].append(name)
			results["success_count"] += 1
		else:
			results["failed"].append(name)
			results["failed_count"] += 1

	_log_debug("批量设置变量完成: 成功 %d/%d, 失败 %d/%d" % [
		results["success_count"], results["total"],
		results["failed_count"], results["total"]
	])

	return results

## 批量获取变量
## names: Array[String] - 变量名称数组
## scope: VariableScope - 变量作用域（默认为 LOCAL）
## returns: Dictionary - 变量名称到值的映射字典
func get_variables_batch(names: Array[String], scope: VariableScope = VariableScope.LOCAL) -> Dictionary:
	var results: Dictionary = {}

	for name in names:
		var value = get_variable(name, null, scope)
		results[name] = value

	_log_debug("批量获取变量完成: 获取了 %d 个变量" % results.size())
	return results

## 批量删除变量
## names: Array[String] - 变量名称数组
## scope: VariableScope - 变量作用域（默认为 LOCAL）
## returns: Dictionary - 包含成功和失败结果的字典
func remove_variables_batch(names: Array[String], scope: VariableScope = VariableScope.LOCAL) -> Dictionary:
	var results = {
		"success": [],
		"failed": [],
		"total": names.size(),
		"success_count": 0,
		"failed_count": 0
	}

	for name in names:
		var success = remove_variable(name, scope)

		if success:
			results["success"].append(name)
			results["success_count"] += 1
		else:
			results["failed"].append(name)
			results["failed_count"] += 1

	_log_debug("批量删除变量完成: 成功 %d/%d, 失败 %d/%d" % [
		results["success_count"], results["total"],
		results["failed_count"], results["total"]
	])

	return results

## 批量检查变量是否存在
## names: Array[String] - 变量名称数组
## scope: VariableScope - 变量作用域（默认为 LOCAL）
## returns: Dictionary - 变量名称到存在状态的映射字典
func has_variables_batch(names: Array[String], scope: VariableScope = VariableScope.LOCAL) -> Dictionary:
	var results: Dictionary = {}

	for name in names:
		var exists = has_variable(name, scope)
		results[name] = exists

	_log_debug("批量检查变量存在性完成: 检查了 %d 个变量" % results.size())
	return results

## 清理局部变量
##
## 清理所有局部变量。通常在触发器执行完成后调用。
func clear_local_variables():
	var local_vars = _get_variable_names_unified(VariableScope.LOCAL)
	for var_name in local_vars:
		_remove_variable_data(var_name)
	_log_debug("局部变量已清理 (清理了 %d 个变量)" % local_vars.size())

## 清理触发器变量
##
## 清理所有触发器变量。通常在触发器销毁时调用。
## 注意：TRIGGER 作用域已被移除，此方法保留以保持向后兼容
func clear_trigger_variables():
	_log_warning("TRIGGER 作用域已被移除，此方法不再执行任何操作")
	# 不执行任何操作，因为 TRIGGER 作用域已被移除

## 清理全局变量
##
## 清理所有全局变量。谨慎使用！
func clear_global_variables():
	var global_vars = _get_variable_names_unified(VariableScope.GLOBAL)
	for var_name in global_vars:
		_remove_variable_data(var_name)
	_log_debug("全局变量已清理 (清理了 %d 个变量)" % global_vars.size())

## 清理所有变量
##
## 清理所有作用域的变量。
func clear_all_variables():
	var all_vars = _variables_data.keys()
	for var_name in all_vars:
		_remove_variable_data(var_name)
	_log_debug("所有变量已清理 (清理了 %d 个变量)" % all_vars.size())

## 序列化变量容器
##
## 将变量容器序列化为字典格式，用于保存和加载。
##
## 返回：
## - Dictionary - 序列化后的字典
func serialize() -> Dictionary:
	var serialized_data = {}

	# 序列化所有变量
	for var_name in _variables_data:
		var var_data = _variables_data[var_name]
		serialized_data[var_name] = {
			"value": var_data.value,
			"type": var_data.type,
			"scope": var_data.scope,
			"timestamp": var_data.timestamp,
			"persistent": var_data.persistent,
			"last_modified": var_data.last_modified
		}

	return {
		"trigger_id": _trigger_id,
		"creation_time": _creation_time,
		"variables": serialized_data,
		"version": "2.0"  # 标记新版本格式
	}

## 反序列化变量容器
##
## 从字典数据反序列化变量容器。
## 支持新旧两种格式：
## - 新格式 (version 2.0): 使用统一的 "variables" 字段
## - 旧格式 (无 version): 使用 "local_variables", "global_variables" 字段
##
## 参数：
## - data: Dictionary - 序列化的数据字典
func deserialize(data: Dictionary):
	_trigger_id = data.get("trigger_id", "")
	_creation_time = data.get("creation_time", 0)

	var version = data.get("version", "")

	# 检查版本号以确定格式
	if version == "2.0":
		# 新格式：使用统一存储
		_deserialize_unified_format(data.get("variables", {}))
	else:
		# 旧格式：向后兼容
		_deserialize_legacy_format(data)

func _deserialize_unified_format(variables: Dictionary):
	# 清空现有数据
	_variables_data.clear()
	_scope_index = {
		VariableScope.LOCAL: [],
		VariableScope.GLOBAL: []
	}
	_persistent_index.clear()
	_runtime_index.clear()

	# 反序列化变量
	for var_name in variables:
		var data = variables[var_name]
		var var_data = VariableData.new()
		var_data.value = data.get("value", null)
		var_data.type = data.get("type", TYPE_NIL)
		var_data.scope = data.get("scope", VariableScope.LOCAL)
		var_data.timestamp = data.get("timestamp", 0)
		var_data.persistent = data.get("persistent", false)
		var_data.last_modified = data.get("last_modified", var_data.timestamp)

		# 直接添加到统一存储（不使用 _set_variable_data 以避免修改统计）
		_variables_data[var_name] = var_data
		_add_to_indices(var_name, var_data)

	_log_debug("使用新格式反序列化了 %d 个变量" % _variables_data.size())

func _deserialize_legacy_format(data: Dictionary):
	# 旧格式：local_variables, global_variables
	var local_vars = data.get("local_variables", {})
	var global_vars = data.get("global_variables", {})

	# 清空现有数据
	_variables_data.clear()
	_scope_index = {
		VariableScope.LOCAL: [],
		VariableScope.GLOBAL: []
	}
	_persistent_index.clear()
	_runtime_index.clear()

	# 转换旧格式到新格式
	for var_name in local_vars:
		var var_data = _deserialize_single_variable(local_vars[var_name])
		var_data.scope = VariableScope.LOCAL
		_variables_data[var_name] = var_data
		_add_to_indices(var_name, var_data)

	for var_name in global_vars:
		var var_data = _deserialize_single_variable(global_vars[var_name])
		var_data.scope = VariableScope.GLOBAL
		_variables_data[var_name] = var_data
		_add_to_indices(var_name, var_data)

	_log_debug("使用旧格式反序列化了 %d 个变量" % _variables_data.size())

func _deserialize_single_variable(data: Dictionary) -> VariableData:
	var var_data = VariableData.new()
	var_data.value = data.get("value", null)
	var_data.type = data.get("type", TYPE_NIL)
	var_data.timestamp = data.get("timestamp", 0)
	var_data.persistent = false  # 旧格式默认为运行时变量
	var_data.last_modified = var_data.timestamp
	return var_data

## 获取变量统计信息
##
## 获取变量的统计信息。
##
## 返回：
## - Dictionary - 包含统计信息的字典
func get_statistics() -> Dictionary:
	var local_count = _scope_index[VariableScope.LOCAL].size()
	var global_count = _scope_index[VariableScope.GLOBAL].size()
	var persistent_count = _persistent_index.size()
	var runtime_count = _runtime_index.size()

	return {
		"local_count": local_count,
		"global_count": global_count,
		"total_count": _variables_data.size(),
		"persistent_count": persistent_count,
		"runtime_count": runtime_count,
		"trigger_id": _trigger_id,
		"creation_time": _creation_time,
		"age_ms": Time.get_ticks_msec() - _creation_time,
		"cache_hit_rate": _get_cache_hit_rate()
	}

func _get_cache_hit_rate() -> float:
	if _unified_cache_enabled:
		var current_time = Time.get_ticks_msec()
		var valid_count = 0
		for timestamp in _unified_cache_timestamps.values():
			if current_time - timestamp < 5000:  # 5秒内有效
				valid_count += 1
		return float(valid_count) / float(_unified_cache.size()) if _unified_cache.size() > 0 else 0.0
	return 0.0

## 调试信息字符串
func to_string() -> String:
	var local_count = _scope_index[VariableScope.LOCAL].size()
	var global_count = _scope_index[VariableScope.GLOBAL].size()
	var persistent_count = _persistent_index.size()
	var runtime_count = _runtime_index.size()

	return "VariableContainer[%s] - Local: %d, Global: %d, Total: %d (Persistent: %d, Runtime: %d)" % [
		_trigger_id,
		local_count,
		global_count,
		_variables_data.size(),
		persistent_count,
		runtime_count
	]

## 私有方法：检查变量是否存在
func _variable_exists(name: String, scope: VariableScope) -> bool:
	var data = _get_variable_data(name)
	if not data:
		return false
	return data.scope == scope

## 私有方法：验证变量类型
func _validate_variable_type(value: Variant) -> bool:
	# 验证变量类型是否有效
	var value_type = typeof(value)

	# 检查是否为 Godot 支持的类型
	match value_type:
		TYPE_NIL:
			return true
		TYPE_BOOL:
			return true
		TYPE_INT:
			return true
		TYPE_FLOAT:
			return true
		TYPE_STRING:
			return true
		TYPE_VECTOR2:
			return true
		TYPE_VECTOR2I:
			return true
		TYPE_VECTOR3:
			return true
		TYPE_VECTOR3I:
			return true
		TYPE_COLOR:
			return true
		TYPE_ARRAY:
			return true
		TYPE_DICTIONARY:
			return true
		TYPE_OBJECT:
			return true
		TYPE_NODE_PATH:
			return true
		TYPE_PACKED_BYTE_ARRAY:
			return true
		TYPE_PACKED_STRING_ARRAY:
			return true
		TYPE_PACKED_VECTOR2_ARRAY:
			return true
		TYPE_PACKED_VECTOR3_ARRAY:
			return true
		TYPE_PACKED_COLOR_ARRAY:
			return true
		_:
			return false

## 私有方法：获取类型名称
func _get_type_name(type: Variant.Type) -> String:
	match type:
		TYPE_NIL: return "Nil"
		TYPE_BOOL: return "Bool"
		TYPE_INT: return "Int"
		TYPE_FLOAT: return "Float"
		TYPE_STRING: return "String"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR2I: return "Vector2I"
		TYPE_VECTOR3: return "Vector3"
		TYPE_VECTOR3I: return "Vector3I"
		TYPE_COLOR: return "Color"
		TYPE_ARRAY: return "Array"
		TYPE_DICTIONARY: return "Dictionary"
		TYPE_OBJECT: return "Object"
		TYPE_NODE_PATH: return "NodePath"
		TYPE_PACKED_BYTE_ARRAY: return "PackedByteArray"
		TYPE_PACKED_STRING_ARRAY: return "PackedStringArray"
		TYPE_PACKED_VECTOR2_ARRAY: return "PackedVector2Array"
		TYPE_PACKED_VECTOR3_ARRAY: return "PackedVector3Array"
		TYPE_PACKED_COLOR_ARRAY: return "PackedColorArray"
		_: return "Unknown"

## 私有方法：调试日志
func _log_debug(message: String):
	var timestamp = Time.get_datetime_string_from_system().replace("T", " ")
	print("[DEBUG][VariableContainer][%s] %s" % [timestamp, message])

## 私有方法：错误日志
func _log_error(message: String):
	var timestamp = Time.get_datetime_string_from_system().replace("T", " ")
	print("[ERROR][VariableContainer][%s] %s" % [timestamp, message])

## 私有方法：警告日志
func _log_warning(message: String):
	var timestamp = Time.get_datetime_string_from_system().replace("T", " ")
	print("[WARNING][VariableContainer][%s] %s" % [timestamp, message])

## 设置是否自动创建变量
func set_auto_create_variables(enabled: bool):
	_auto_create_variables = enabled
	_log_debug("自动创建变量功能已%s" % ["启用" if enabled else "禁用"])

## 获取是否自动创建变量
func get_auto_create_variables() -> bool:
	return _auto_create_variables

## 缓存管理方法

## 启用或禁用缓存
## enabled: bool - 是否启用缓存
## duration: float - 缓存持续时间（秒）
func set_cache_enabled(enabled: bool, duration: float = 2.0):
	_enable_cache = enabled
	_cache_duration = max(0.1, duration)
	if not enabled:
		clear_cache()
	_log_debug("变量缓存已%s (持续时间: %.2f 秒)" % ["启用" if enabled else "禁用", _cache_duration])

## 获取缓存状态
## returns: bool - 是否启用缓存
func is_cache_enabled() -> bool:
	return _enable_cache

## 检查缓存是否有效
## name: String - 变量名称
## scope: VariableScope - 变量作用域
## returns: bool - 缓存是否有效
func _is_cache_valid(name: String, scope: VariableScope) -> bool:
	var cache_key = _get_cache_key(name, scope)
	if not _cache_timestamps.has(cache_key):
		return false

	var cache_time = _cache_timestamps[cache_key]
	var current_time = Time.get_ticks_msec() / 1000.0
	var cache_age = current_time - cache_time

	return cache_age <= _cache_duration

## 获取缓存键
## name: String - 变量名称
## scope: VariableScope - 变量作用域
## returns: String - 缓存键
func _get_cache_key(name: String, scope: VariableScope) -> String:
	return "%s_%s" % [name, VariableScope.keys()[scope]]

## 更新缓存
## name: String - 变量名称
## scope: VariableScope - 变量作用域
## value: Variant - 变量值
func _update_cache(name: String, scope: VariableScope, value: Variant):
	var cache_key = _get_cache_key(name, scope)
	_variable_cache[cache_key] = value
	_cache_timestamps[cache_key] = Time.get_ticks_msec() / 1000.0
	_log_debug("更新变量缓存: %s (作用域: %s)" % [name, VariableScope.keys()[scope]])

## 清除缓存
func clear_cache():
	_variable_cache.clear()
	_cache_timestamps.clear()
	_log_debug("变量缓存已清除")

## 获取缓存信息
## returns: Dictionary - 缓存信息字典
func get_cache_info() -> Dictionary:
	var current_time = Time.get_ticks_msec() / 1000.0
	var valid_cache_count = 0
	var total_cache_count = _variable_cache.size()

	for cache_key in _cache_timestamps:
		var cache_time = _cache_timestamps[cache_key]
		var cache_age = current_time - cache_time
		if cache_age <= _cache_duration:
			valid_cache_count += 1

	return {
		"enabled": _enable_cache,
		"duration": _cache_duration,
		"total_cache_count": total_cache_count,
		"valid_cache_count": valid_cache_count,
		"cache_hit_rate": float(valid_cache_count) / float(total_cache_count) if total_cache_count > 0 else 0.0
	}

## 带缓存的变量获取方法
func get_variable_cached(name: String, default_value: Variant = null, scope: VariableScope = VariableScope.LOCAL) -> Variant:
	if not _cache_enabled:
		return get_variable(name, default_value, scope, false)

	# 检查缓存
	if _access_cache.has(name):
		var cached_data = _access_cache[name]
		if Time.get_ticks_msec() - cached_data.timestamp < 5000:  # 5秒缓存
			return cached_data.value

	# 获取变量值并缓存
	var value = get_variable(name, default_value, scope, false)
	_access_cache[name] = {
		"value": value,
		"timestamp": Time.get_ticks_msec()
	}

	# 限制缓存大小
	if _access_cache.size() > _cache_max_size:
		_cleanup_cache()

	return value

## 清理过期缓存
func _cleanup_cache():
	var current_time = Time.get_ticks_msec()
	var keys_to_remove = []

	for key in _access_cache:
		if current_time - _access_cache[key].timestamp > 5000:
			keys_to_remove.append(key)

	for key in keys_to_remove:
		_access_cache.erase(key)

## 预编译变量索引
func precompile_variable_indices(variable_names: Array[String]):
	_variable_name_to_index.clear()
	_indexed_variables.clear()
	_indexed_variables.resize(variable_names.size())

	for i in range(variable_names.size()):
		_variable_name_to_index[variable_names[i]] = i

	_use_indexed_storage = true
	_log_debug("预编译了 %d 个变量索引" % variable_names.size())

## 快速变量访问（索引方式）
func set_variable_indexed(index: int, value: Variant):
	if _use_indexed_storage and index >= 0 and index < _indexed_variables.size():
		_indexed_variables[index] = value

func get_variable_indexed(index: int) -> Variant:
	if _use_indexed_storage and index >= 0 and index < _indexed_variables.size():
		return _indexed_variables[index]
	return null

## 获取增强缓存信息（避免与原有get_cache_info冲突）
func get_enhanced_cache_info() -> Dictionary:
	var current_time = Time.get_ticks_msec()
	var valid_cache_count = 0
	var total_cache_count = _access_cache.size()

	for cache_key in _access_cache:
		var cached_data = _access_cache[cache_key]
		if current_time - cached_data.timestamp < 5000:
			valid_cache_count += 1

	return {
		"enabled": _cache_enabled,
		"max_size": _cache_max_size,
		"total_count": total_cache_count,
		"valid_count": valid_cache_count,
		"hit_rate": float(valid_cache_count) / float(total_cache_count) if total_cache_count > 0 else 0.0
	}

## 设置增强缓存状态（避免与原有set_cache_enabled冲突）
func set_enhanced_cache_enabled(enabled: bool, max_size: int = 100):
	_cache_enabled = enabled
	_cache_max_size = max(10, max_size)  # 最小缓存大小为10
	if not enabled:
		_access_cache.clear()
	_log_debug("变量缓存已%s (最大大小: %d)" % ["启用" if enabled else "禁用", _cache_max_size])

## 清除所有缓存
func clear_all_cache():
	_access_cache.clear()
	_variable_cache.clear()
	_cache_timestamps.clear()
	_log_debug("所有缓存已清除")

## 获取索引存储状态
func get_indexed_storage_info() -> Dictionary:
	return {
		"enabled": _use_indexed_storage,
		"index_count": _variable_name_to_index.size(),
		"array_size": _indexed_variables.size()
	}

## 获取运行时和持久化变量统计
func get_runtime_persistent_stats() -> Dictionary:
	return {
		"runtime_variables": _runtime_index.size(),
		"persistent_variables": _persistent_index.size(),
		"total_variables": _variables_data.size()
	}


## 使特定变量的缓存失效
## name: String - 变量名称
## scope: VariableScope - 变量作用域
func _invalidate_cache_for_variable(name: String, scope: VariableScope):
	var cache_key = _get_cache_key(name, scope)
	if _variable_cache.has(cache_key):
		_variable_cache.erase(cache_key)
		_cache_timestamps.erase(cache_key)
		_log_debug("变量缓存失效: %s (作用域: %s)" % [name, VariableScope.keys()[scope]])

## 依赖关系管理方法

## 添加变量依赖关系
## @param variable_name: 变量名
## @param depends_on: 依赖的变量名数组
func add_variable_dependencies(variable_name: String, depends_on: Array[String]) -> void:
	if not _variable_dependencies.has(variable_name):
		_variable_dependencies[variable_name] = []

	for dep_var in depends_on:
		if not dep_var in _variable_dependencies[variable_name]:
			_variable_dependencies[variable_name].append(dep_var)

  # 更新被依赖关系
		if not _variable_dependents.has(dep_var):
			_variable_dependents[dep_var] = []
		if not variable_name in _variable_dependents[dep_var]:
			_variable_dependents[dep_var].append(variable_name)

## 移除变量依赖关系
## @param variable_name: 变量名
## @param depends_on: 要移除的依赖变量名数组
func remove_variable_dependencies(variable_name: String, depends_on: Array[String]) -> void:
	if not _variable_dependencies.has(variable_name):
		return

	for dep_var in depends_on:
		if dep_var in _variable_dependencies[variable_name]:
			_variable_dependencies[variable_name].erase(dep_var)

  # 更新被依赖关系
		if _variable_dependents.has(dep_var) and variable_name in _variable_dependents[dep_var]:
			_variable_dependents[dep_var].erase(variable_name)
			if _variable_dependents[dep_var].is_empty():
				_variable_dependents.erase(dep_var)

 # 如果变量没有依赖关系了，移除条目
	if _variable_dependencies[variable_name].is_empty():
		_variable_dependencies.erase(variable_name)

## 获取变量的依赖关系
## @param variable_name: 变量名
## @return: 依赖的变量名数组
func get_variable_dependencies(variable_name: String) -> Array[String]:
	return _variable_dependencies.get(variable_name, [])

## 获取变量的被依赖关系
## @param variable_name: 变量名
## @return: 依赖此变量的变量名数组
func get_variable_dependents(variable_name: String) -> Array[String]:
	return _variable_dependents.get(variable_name, [])

## 检查变量是否有依赖关系
## @param variable_name: 变量名
## @return: 是否有依赖关系
func has_variable_dependencies(variable_name: String) -> bool:
	return _variable_dependencies.has(variable_name)

## 获取所有依赖关系
## @return: 依赖关系字典
func get_all_dependencies() -> Dictionary:
	return _variable_dependencies.duplicate(true)

## 获取所有被依赖关系
## @return: 被依赖关系字典
func get_all_dependents() -> Dictionary:
	return _variable_dependents.duplicate(true)

## 清除变量的所有依赖关系
## @param variable_name: 变量名
func clear_variable_dependencies(variable_name: String) -> void:
	if _variable_dependencies.has(variable_name):
		for dep_var in _variable_dependencies[variable_name]:
			if _variable_dependents.has(dep_var) and variable_name in _variable_dependents[dep_var]:
				_variable_dependents[dep_var].erase(variable_name)
				if _variable_dependents[dep_var].is_empty():
					_variable_dependents.erase(dep_var)
		_variable_dependencies.erase(variable_name)

## 清除所有依赖关系
func clear_all_dependencies() -> void:
	_variable_dependencies.clear()
	_variable_dependents.clear()

## 获取依赖关系图（用于可视化）
## @return: 依赖关系图数据结构
func get_dependency_graph() -> Dictionary:
	var graph = {
		"nodes": [],
		"edges": []
	}

 # 收集所有节点
	var all_variables = {}
	for var_name in _variable_dependencies:
		all_variables[var_name] = true
		for dep_var in _variable_dependencies[var_name]:
			all_variables[dep_var] = true

 # 添加节点
	for var_name in all_variables:
		graph["nodes"].append({
			"id": var_name,
			"label": var_name,
			"type": "variable"
		})

 # 添加边
	for var_name in _variable_dependencies:
		for dep_var in _variable_dependencies[var_name]:
			graph["edges"].append({
				"from": dep_var,
				"to": var_name,
				"type": "dependency"
			})

	return graph

## ============================================
## 统一存储访问方法
## ============================================

## 获取变量数据（内部统一访问方法）
## name: String - 变量名称
## returns: VariableData - 变量数据，如果不存在返回 null
func _get_variable_data(name: String) -> VariableData:
	if not _variables_data.has(name):
		return null

	# 更新访问统计
	var data = _variables_data[name]
	data.access_count += 1
	return data

## 设置变量数据（内部统一访问方法）
## name: String - 变量名称
## data: VariableData - 变量数据
func _set_variable_data(name: String, data: VariableData):
	# 先从索引中移除旧数据（如果存在）
	_remove_from_indices(name)

	# 更新修改统计
	data.modification_count += 1
	data.last_modified = Time.get_ticks_msec()

	# 存储到主数据源
	_variables_data[name] = data

	# 更新索引
	_add_to_indices(name, data)

	# 使缓存失效
	_invalidate_unified_cache(name)

## 从索引中移除变量
## name: String - 变量名称
func _remove_from_indices(name: String):
	var old_data = _variables_data.get(name)
	if old_data:
		# 从作用域索引中移除
		if old_data.scope in _scope_index:
			_scope_index[old_data.scope].erase(name)

		# 从持久化索引中移除
		if name in _persistent_index:
			_persistent_index.erase(name)

		# 从运行时索引中移除
		if name in _runtime_index:
			_runtime_index.erase(name)

## 添加变量到索引
## name: String - 变量名称
## data: VariableData - 变量数据
func _add_to_indices(name: String, data: VariableData):
	# 添加到作用域索引
	if not data.scope in _scope_index:
		_scope_index[data.scope] = []
	if not name in _scope_index[data.scope]:
		_scope_index[data.scope].append(name)

	# 添加到持久化或运行时索引
	if data.persistent:
		if not name in _persistent_index:
			_persistent_index.append(name)
	else:
		if not name in _runtime_index:
			_runtime_index.append(name)

## 使统一缓存失效
## name: String - 变量名称
func _invalidate_unified_cache(name: String):
	if _unified_cache_enabled and _unified_cache.has(name):
		_unified_cache.erase(name)
		_unified_cache_timestamps.erase(name)

	# 限制缓存大小
	if _unified_cache.size() > _unified_cache_max_size:
		_cleanup_unified_cache()

## 清理过期的统一缓存
func _cleanup_unified_cache():
	var current_time = Time.get_ticks_msec()
	var keys_to_remove = []
	var cache_timeout = 5000  # 5秒超时

	for key in _unified_cache_timestamps:
		if current_time - _unified_cache_timestamps[key] > cache_timeout:
			keys_to_remove.append(key)

	for key in keys_to_remove:
		_unified_cache.erase(key)
		_unified_cache_timestamps.erase(key)

	_log_debug("清理了 %d 个过期的统一缓存条目" % keys_to_remove.size())

## 检查变量是否存在于统一存储中
## name: String - 变量名称
## returns: bool - 是否存在
func _has_variable_unified(name: String) -> bool:
	return _variables_data.has(name)

## 获取统一存储中的所有变量名
## scope: VariableScope - 变量作用域
## returns: Array[String] - 变量名列表
func _get_variable_names_unified(scope: VariableScope) -> Array[String]:
	if not scope in _scope_index:
		return []
	return _scope_index[scope].duplicate()

## 从统一存储中移除变量
## name: String - 变量名称
## returns: bool - 是否成功移除
func _remove_variable_unified(name: String) -> bool:
	if not _variables_data.has(name):
		return false

	# 从索引中移除
	_remove_from_indices(name)

	# 从主存储中移除
	_variables_data.erase(name)

	# 使缓存失效
	_invalidate_unified_cache(name)

	_log_debug("从统一存储中移除变量: %s" % name)
	return true