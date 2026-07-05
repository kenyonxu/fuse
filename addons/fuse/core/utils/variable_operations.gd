## addons/fuse/core/utils/variable_operations.gd
@tool
class_name VariableOperations extends RefCounted

## 变量操作统一工具类
##
## 提供三层变量体系（LOCAL/SCOPE/GLOBAL）的统一操作接口。
##
## 功能：
## - 变量读取：从不同作用域获取变量值
## - 变量设置：向不同作用域设置变量值
## - 变量检查：检查变量是否存在
## - 作用域容器查找：查找 ScopeVariableContainer
## - 日志级别控制：可配置的日志输出级别
##
## 设计原则：
## - 所有方法为静态方法，无状态
## - 返回值明确，使用 Variant 或 bool 表示成功/失败
## - 错误处理：使用 FuseLogger 记录日志
## - 性能优化：尽量减少重复查找

## ==================== 日志级别控制 ====================

## 日志级别配置（默认不输出日志）
static var _log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.NONE

## 设置日志输出级别
##
## 参数：
## - level: FuseLogger.LogLevel - 目标日志级别
##
## 使用示例：
## ```gdscript
## VariableOperations.set_log_level(FuseLogger.LogLevel.DEBUG)  # 输出所有日志
## VariableOperations.set_log_level(FuseLogger.LogLevel.ERROR)  # 只输出错误
## VariableOperations.set_log_level(FuseLogger.LogLevel.NONE)   # 禁用日志
## ```
static func set_log_level(level: FuseLogger.LogLevel) -> void:
	_log_level = level

## 获取当前日志输出级别
##
## 返回：
## - FuseLogger.LogLevel - 当前日志级别
static func get_log_level() -> FuseLogger.LogLevel:
	return _log_level

## 从指定作用域获取变量值
##
## 参数：
## - context: ExecutionContext - 执行上下文
## - variable_name: String - 变量名
## - scope: BaseVariable.VariableScope - 变量作用域
## - default_value: Variant = null - 默认值（变量不存在时返回）
##
## 返回：
## - Variant - 变量值，如果找不到则返回默认值
##
## 示例：
## ```gdscript
## var value = VariableOperations.get_variable(context, "score", BaseVariable.VariableScope.SCOPE, 0)
## ```
static func get_variable(
	context: ExecutionContext,
	variable_name: String,
	scope: BaseVariable.VariableScope,
	default_value: Variant = null
) -> Variant:
	if context == null:
		_log_error("ExecutionContext 为空")
		return default_value

	if variable_name.is_empty():
		_log_error("变量名为空")
		return default_value

	match scope:
		BaseVariable.VariableScope.LOCAL:
			return _get_local_variable(context, variable_name, default_value)

		BaseVariable.VariableScope.SCOPE:
			return _get_scope_variable(context, variable_name, default_value)

		BaseVariable.VariableScope.GLOBAL:
			return _get_global_variable(context, variable_name, default_value)

		_:
			_log_error("未知的作用域类型: %s" % BaseVariable.VariableScope.keys()[scope])
			return default_value

## 向指定作用域设置变量值
##
## 参数：
## - context: ExecutionContext - 执行上下文
## - variable_name: String - 变量名
## - scope: BaseVariable.VariableScope - 变量作用域
## - value: Variant - 要设置的值
##
## 返回：
## - bool - 是否成功设置
##
## 示例：
## ```gdscript
## var success = VariableOperations.set_variable(context, "score", BaseVariable.VariableScope.SCOPE, 100)
## ```
static func set_variable(
	context: ExecutionContext,
	variable_name: String,
	scope: BaseVariable.VariableScope,
	value: Variant
) -> bool:
	if context == null:
		_log_error("ExecutionContext 为空")
		return false

	if variable_name.is_empty():
		_log_error("变量名为空")
		return false

	match scope:
		BaseVariable.VariableScope.LOCAL:
			return _set_local_variable(context, variable_name, value)

		BaseVariable.VariableScope.SCOPE:
			return _set_scope_variable(context, variable_name, value)

		BaseVariable.VariableScope.GLOBAL:
			return _set_global_variable(context, variable_name, value)

		_:
			_log_error("未知的作用域类型: %s" % BaseVariable.VariableScope.keys()[scope])
			return false

## 检查变量是否存在
##
## 参数：
## - context: ExecutionContext - 执行上下文
## - variable_name: String - 变量名
## - scope: BaseVariable.VariableScope - 变量作用域
##
## 返回：
## - bool - 变量是否存在
static func has_variable(
	context: ExecutionContext,
	variable_name: String,
	scope: BaseVariable.VariableScope
) -> bool:
	if context == null or variable_name.is_empty():
		return false

	match scope:
		BaseVariable.VariableScope.LOCAL:
			return context.has_variable(variable_name)

		BaseVariable.VariableScope.SCOPE:
			var container = get_scope_container(context)
			return container != null and container.has_variable(variable_name)

		BaseVariable.VariableScope.GLOBAL:
			var assistant = GlobalVariableAssistant.get_instance()
			return assistant != null and assistant.has_global_variable(variable_name)

		_:
			return false

## 获取作用域容器（用于 SCOPE 级别）
##
## 参数：
## - context: ExecutionContext - 执行上下文
## - search_node: Node = null - 搜索起点节点（null 时使用 context.trigger）
##
## 返回：
## - ScopeVariableContainer - 找到的容器，未找到返回 null
static func get_scope_container(
	context: ExecutionContext,
	search_node: Node = null
) -> ScopeVariableContainer:
	if context == null:
		return null

	# 确定搜索起点
	var node = search_node
	if node == null:
		node = context.trigger

	if node == null:
		_log_debug("没有可用的搜索节点")
		return null

	# 使用 ScopeVariableManager 查找
	var manager = ScopeVariableManager.get_instance()
	if manager == null:
		_log_debug("ScopeVariableManager 实例为空")
		return null

	return manager.find_nearest_scope(node)

## ==================== 私有辅助方法 ====================

## 获取局部变量
static func _get_local_variable(
	context: ExecutionContext,
	variable_name: String,
	default_value: Variant
) -> Variant:
	if context.has_variable(variable_name):
		return context.get_variable(variable_name, default_value)

	_log_debug("局部变量未找到: %s" % variable_name)
	return default_value

## 获取作用域变量
static func _get_scope_variable(
	context: ExecutionContext,
	variable_name: String,
	default_value: Variant
) -> Variant:
	var container = get_scope_container(context)

	if container == null:
		_log_debug("未找到作用域容器，回退到默认值: %s" % variable_name)
		return default_value

	if container.has_variable(variable_name):
		var value = container.get_variable(variable_name, default_value)
		_log_debug("从作用域 '%s' 获取变量 %s = %s" % [
			container.scope_id, variable_name, str(value)
		])
		return value

	_log_debug("作用域变量未找到: %s" % variable_name)
	return default_value

## 获取全局变量
static func _get_global_variable(
	context: ExecutionContext,
	variable_name: String,
	default_value: Variant
) -> Variant:
	var assistant = GlobalVariableAssistant.get_instance()

	if assistant == null:
		_log_debug("GlobalVariableAssistant 实例为空")
		return default_value

	var variable = assistant.get_global_variable(variable_name)
	if variable != null:
		return variable.get_value()

	_log_debug("全局变量未找到: %s" % variable_name)
	return default_value

## 设置局部变量
## 同时写入 ExecutionContext.local_variables 和 Trigger 节点的 meta 数据
## 这样 Event（如 OnIntervalWithVariable）也能访问 LOCAL 变量
static func _set_local_variable(
	context: ExecutionContext,
	variable_name: String,
	value: Variant
) -> bool:
	# 1. 写入 ExecutionContext.local_variables（供后续指令使用）
	var success = context.set_variable(variable_name, value, "local")

	# 2. 同时写入 Trigger 节点的 meta 数据（供 Event 使用）
	# 这是 Event 和 ExecutionContext 之间共享 LOCAL 变量的变通方案
	if success and context.trigger != null:
		var meta_key = "local_variable_%s" % variable_name
		context.trigger.set_meta(meta_key, value)
		_log_debug("LOCAL 变量已写入 Trigger meta: %s = %s" % [variable_name, str(value)])

	return success

## 设置作用域变量
static func _set_scope_variable(
	context: ExecutionContext,
	variable_name: String,
	value: Variant
) -> bool:
	var container = get_scope_container(context)

	if container == null:
		_log_debug("未找到作用域容器，回退到局部变量: %s" % variable_name)
		return _set_local_variable(context, variable_name, value)

	var success = container.set_variable(variable_name, value)
	if success:
		_log_debug("在作用域 '%s' 设置变量 %s = %s" % [
			container.scope_id, variable_name, str(value)
		])

	return success

## 设置全局变量
static func _set_global_variable(
	context: ExecutionContext,
	variable_name: String,
	value: Variant
) -> bool:
	var assistant = GlobalVariableAssistant.get_instance()

	if assistant == null:
		_log_error("GlobalVariableAssistant 实例为空")
		return false

	# 检查变量是否存在
	if assistant.has_global_variable(variable_name):
		var variable = assistant.get_global_variable(variable_name)
		if variable != null:
			return variable.set_value(value)
	else:
		# 创建新变量
		var new_variable = BaseVariable.create(
			variable_name,
			value,
			BaseVariable.VariableScope.GLOBAL
		)
		if new_variable == null:
			_log_error("创建全局变量失败: %s" % variable_name)
			return false

		return assistant.add_global_variable(variable_name, new_variable)

	return false

## ==================== 日志方法 ====================

static func _log_debug(message: String):
	FuseLogger.log_debug("VariableOperations", _log_level, message)

static func _log_info(message: String):
	FuseLogger.log_info("VariableOperations", _log_level, message)

static func _log_warning(message: String):
	FuseLogger.log_warning("VariableOperations", _log_level, message)

static func _log_error(message: String):
	FuseLogger.log_error("VariableOperations", _log_level, message)
