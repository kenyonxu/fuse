@tool
@icon("res://addons/fuse/icons/builtin/ScopeVariable.png")
class_name CheckScopeVariable extends BaseCondition
## 检查作用域变量条件
##
## 用于检查作用域变量与给定值的比较结果。
## 支持多种比较操作符和类型安全的比较。


## 比较操作符枚举
enum ComparisonOperator {
	EQUALS,           ## 等于 (==)
	NOT_EQUALS,       ## 不等于 (!=)
	GREATER_THAN,     ## 大于 (>)
	LESS_THAN,        ## 小于 (<)
	GREATER_EQUAL,    ## 大于等于 (>=)
	LESS_EQUAL,       ## 小于等于 (<=)
	CONTAINS,         ## 包含（用于字符串、数组）
	NOT_CONTAINS,     ## 不包含
	IS_EMPTY,         ## 为空
	IS_NOT_EMPTY,     ## 不为空
	IS_NULL,          ## 为 null
	IS_NOT_NULL,      ## 不为 null
	IS_TRUE,          ## 为 true
	IS_FALSE          ## 为 false
}

## 作用域来源
enum ScopeSource {
	NEAREST,        # 最近的作用域容器（默认）
	CUSTOM_ID,      # 指定 scope_id
	TRIGGER_SCOPE,  # Trigger 节点上的作用域
	TARGET_NODE     # Target 节点上的作用域
}

# 比较配置
@export var variable_name: String = "":
	set(value):
		variable_name = value
		_update_resource_name()

@export var scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		scope_source = value
		_update_resource_name()
		notify_property_list_changed()

@export var comparison_operator: ComparisonOperator = ComparisonOperator.EQUALS:
	set(value):
		comparison_operator = value
		_update_resource_name()

# 控制属性
@export var check_with_another_variable: bool = false:
	set(value):
		check_with_another_variable = value
		_update_resource_name()
		notify_property_list_changed()

# 条件属性
@export var compare_variable: String = "":
	set(value):
		compare_variable = value
		_update_resource_name()

@export var expected_value: Variant:
	set(value):
		expected_value = value
		_update_resource_name()

@export var custom_scope_id: String = "":
	set(value):
		custom_scope_id = value
		_update_resource_name()

@export var target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_path = value
		_update_resource_name()

@export var case_sensitive: bool = true

## 高级配置
@export_group("Advanced Configuration")
@export var auto_convert_types: bool = true

## 私有属性
var _last_variable_value: Variant = null
var _last_comparison_result: bool = false

func _validate_property(property: Dictionary) -> void:
	# 当 check_with_another_variable = false 时，禁用比较变量属性
	if not check_with_another_variable:
		if property.name == "compare_variable":
			property.usage = PROPERTY_USAGE_READ_ONLY

	# 当 check_with_another_variable = true 时，禁用期望值属性
	if check_with_another_variable and property.name == "expected_value":
		property.usage = PROPERTY_USAGE_READ_ONLY

	# 根据 scope_source 控制属性可见性
	match scope_source:
		ScopeSource.CUSTOM_ID:
			if property.name == "target_node_path":
				property.usage = PROPERTY_USAGE_NO_EDITOR
		ScopeSource.TARGET_NODE:
			if property.name == "custom_scope_id":
				property.usage = PROPERTY_USAGE_NO_EDITOR
		_:
			# NEAREST 和 TRIGGER_SCOPE 不需要这两个参数
			if property.name == "custom_scope_id" or property.name == "target_node_path":
				property.usage = PROPERTY_USAGE_NO_EDITOR

func _setup_metadata():
	pass

func _update_resource_name():
	var operator_name = ComparisonOperator.keys()[comparison_operator]
	var scope_str = _get_scope_source_string()
	var value_str: String

	if check_with_another_variable:
		if compare_variable.is_empty():
			value_str = FuseLocalization.translate("FUSE_CONDITION_NOT_SET")
		else:
			value_str = "'%s'" % compare_variable
	else:
		value_str = _get_value_display_string(expected_value)
		if value_str.length() > 20:
			value_str = value_str.substr(0, 17) + "..."

	resource_name = "%s [%s] '%s' %s %s" % [
		FuseLocalization.translate("FUSE_CONDITION_CHECK_SCOPE_VARIABLE"),
		scope_str,
		variable_name if not variable_name.is_empty() else FuseLocalization.translate("FUSE_CONDITION_UNNAMED"),
		operator_name,
		value_str
	]

	_description = resource_name

## 获取值的显示字符串
func _get_value_display_string(value: Variant) -> String:
	if value == null:
		return "null"
	elif value is String and value.is_empty():
		return '""'
	else:
		return str(value)

## 评估条件
func _evaluate_condition(context: ExecutionContext) -> bool:
	if variable_name.is_empty():
		_log_error("Variable name is empty")
		var error_msg = FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY")
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return false

	# 获取作用域容器
	var scope_container = _get_scope_container(context)
	if scope_container == null:
		var localized_msg = FuseLocalization.translate_format("FUSE_LOG_SCOPE_VAR_NOT_FOUND", {"scope": "container"})
		_log_warning(localized_msg)
		_create_fuse_error(localized_msg, FuseError.ErrorType.CONFIGURATION_ERROR)
		return false

	# 使用 VariableOperations 获取变量值
	var variable_value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.SCOPE, null)
	_last_variable_value = variable_value

	# 获取比较值
	var compare_value: Variant
	if check_with_another_variable:
		if compare_variable.is_empty():
			var localized_msg = FuseLocalization.translate("FUSE_ERROR_COMPARE_VAR_NAME_UNSET")
			_log_error(localized_msg)
			_create_fuse_error(localized_msg, FuseError.ErrorType.VALIDATION_ERROR)
			return false
		compare_value = VariableOperations.get_variable(context, compare_variable, BaseVariable.VariableScope.SCOPE, null)
	else:
		compare_value = expected_value

	# 执行比较
	var result = _perform_comparison(variable_value, compare_value)
	_last_comparison_result = result

	# 记录结果
	_log_debug("变量值: %s, 比较值: %s, 操作符: %s, 结果: %s" % [
		str(variable_value),
		str(compare_value),
		ComparisonOperator.keys()[comparison_operator],
		str(result)
	])

	return result

## 执行比较
func _perform_comparison(variable_value: Variant, compare_value: Variant) -> bool:
	match comparison_operator:
		ComparisonOperator.EQUALS:
			return _compare_equals(variable_value, compare_value)
		ComparisonOperator.NOT_EQUALS:
			return not _compare_equals(variable_value, compare_value)
		ComparisonOperator.GREATER_THAN:
			if auto_convert_types:
				return _to_number(variable_value) > _to_number(compare_value)
			return variable_value > compare_value if variable_value != null and compare_value != null else false
		ComparisonOperator.LESS_THAN:
			if auto_convert_types:
				return _to_number(variable_value) < _to_number(compare_value)
			return variable_value < compare_value if variable_value != null and compare_value != null else false
		ComparisonOperator.GREATER_EQUAL:
			if auto_convert_types:
				return _to_number(variable_value) >= _to_number(compare_value)
			return variable_value >= compare_value if variable_value != null and compare_value != null else false
		ComparisonOperator.LESS_EQUAL:
			if auto_convert_types:
				return _to_number(variable_value) <= _to_number(compare_value)
			return variable_value <= compare_value if variable_value != null and compare_value != null else false
		ComparisonOperator.CONTAINS:
			return _check_contains(variable_value, compare_value, true)
		ComparisonOperator.NOT_CONTAINS:
			return not _check_contains(variable_value, compare_value, true)
		ComparisonOperator.IS_EMPTY:
			return _is_empty(variable_value)
		ComparisonOperator.IS_NOT_EMPTY:
			return not _is_empty(variable_value)
		ComparisonOperator.IS_NULL:
			return variable_value == null
		ComparisonOperator.IS_NOT_NULL:
			return variable_value != null
		ComparisonOperator.IS_TRUE:
			return variable_value == true
		ComparisonOperator.IS_FALSE:
			return variable_value == false
		_:
			return false

## 比较等于（支持类型转换）
func _compare_equals(a: Variant, b: Variant) -> bool:
	if auto_convert_types:
		# 尝试类型转换
		if a is float or a is int:
			return _to_number(a) == _to_number(b)
		if b is float or b is int:
			return _to_number(a) == _to_number(b)
		if a is String and b is String:
			if case_sensitive:
				return a == b
			else:
				return a.to_lower() == b.to_lower()
	# 默认严格比较
	return a == b

## 检查包含
func _check_contains(haystack: Variant, needle: Variant, is_contains: bool) -> bool:
	if haystack == null:
		return false
	if haystack is Array:
		return needle in haystack
	if haystack is String:
		if needle is String:
			if case_sensitive:
				return needle in haystack
			else:
				return needle.to_lower() in haystack.to_lower()
		return str(needle) in haystack
	if haystack is Dictionary:
		return needle in haystack
	return false

## 检查是否为空
func _is_empty(value: Variant) -> bool:
	if value == null:
		return true
	if value is String:
		return value.is_empty()
	if value is Array:
		return value.is_empty()
	if value is Dictionary:
		return value.is_empty()
	return false

## 转换为数字
func _to_number(value: Variant) -> float:
	if value == null:
		return 0.0
	if value is float:
		return value
	if value is int:
		return float(value)
	if value is String:
		if value.is_valid_float():
			return value.to_float()
		if value.is_valid_int():
			return float(value.to_int())
	return 0.0

## 获取作用域容器（使用 VariableOperations 工具类）
func _get_scope_container(context: ExecutionContext) -> ScopeVariableContainer:
	var manager = ScopeVariableManager.get_instance()
	if manager == null:
		var localized_msg = FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND")
		_log_error(localized_msg)
		return null

	match scope_source:
		ScopeSource.NEAREST:
			return VariableOperations.get_scope_container(context)
		ScopeSource.CUSTOM_ID:
			if custom_scope_id.is_empty():
				var localized_msg = FuseLocalization.translate("FUSE_WARNING_SCOPE_ID_EMPTY")
				_log_warning(localized_msg)
				return null
			return manager.get_scope_by_id(custom_scope_id)
		ScopeSource.TRIGGER_SCOPE:
			if context.trigger != null:
				return VariableOperations.get_scope_container(context, context.trigger)
			return null
		ScopeSource.TARGET_NODE:
			if target_node_path.is_empty():
				var localized_msg = FuseLocalization.translate("FUSE_WARNING_TARGET_NODE_PATH_EMPTY")
				_log_warning(localized_msg)
				return null
			var node = context.get_node(target_node_path)
			if node == null:
				var localized_msg = FuseLocalization.translate_format("FUSE_WARNING_NODE_NOT_FOUND", {"path": str(target_node_path)})
				_log_warning(localized_msg)
				return null
			return VariableOperations.get_scope_container(context, node)

	return null

## 获取作用域来源字符串
func _get_scope_source_string() -> String:
	match scope_source:
		ScopeSource.NEAREST:
			return FuseLocalization.translate("FUSE_SCOPE_SOURCE_NEAREST_STR")
		ScopeSource.CUSTOM_ID:
			if custom_scope_id.is_empty():
				return FuseLocalization.translate("FUSE_SCOPE_SOURCE_CUSTOM_ID_UNSET")
			return "ID:%s" % custom_scope_id
		ScopeSource.TRIGGER_SCOPE:
			return FuseLocalization.translate("FUSE_SCOPE_SOURCE_TRIGGER_SCOPE_STR")
		ScopeSource.TARGET_NODE:
			if target_node_path.is_empty():
				return FuseLocalization.translate("FUSE_SCOPE_SOURCE_TARGET_NODE_UNSET")
			return "节点:%s" % target_node_path
		_:
			return FuseLocalization.translate("FUSE_SCOPE_SOURCE_UNKNOWN")

func _compute_dependencies() -> Array[String]:
	var dependencies = []

	if not variable_name.is_empty():
		dependencies.append(variable_name)

	if check_with_another_variable and not compare_variable.is_empty():
		dependencies.append(compare_variable)

	return dependencies

func validate() -> Array[String]:
	var errors = super.validate()

	if variable_name.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_VAR_NAME_EMPTY"))

	if scope_source == ScopeSource.CUSTOM_ID and custom_scope_id.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_ID_EMPTY"))

	if scope_source == ScopeSource.TARGET_NODE and target_node_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_PATH_EMPTY"))

	if check_with_another_variable and compare_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_COMPARE_VAR_NAME_EMPTY"))

	return errors

func get_description() -> String:
	return _description

## 统一日志方法
func _log_debug(message: String):
	FuseLogger.log_debug("CheckScopeVariable", log_level, message, variable_name)

func _log_info(message: String):
	FuseLogger.log_info("CheckScopeVariable", log_level, message, variable_name)

func _log_warning(message: String):
	FuseLogger.log_warning("CheckScopeVariable", log_level, message, variable_name)

func _log_error(message: String):
	FuseLogger.log_error("CheckScopeVariable", log_level, message, variable_name)
