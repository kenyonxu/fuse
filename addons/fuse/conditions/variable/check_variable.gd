@tool
@icon("res://addons/fuse/icons/builtin/LocalVariable.png")
class_name CheckVariable extends BaseCondition
## 检查变量条件类
##
## 用于检查局部或全局变量与给定值的比较结果。
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
	IS_FALSE,         ## 为 false
	MATCHES_PATTERN   ## 匹配模式（正则表达式）
}

## 作用域来源（仅在 variable_scope == SCOPE 时使用）
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# 比较配置
@export var variable_name: String = "":
	set(value):
		variable_name = value
		_update_resource_name()
		_log_debug("Variable name set to: %s" % value)

## 主变量作用域（三层变量系统）
var variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		variable_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 主变量作用域来源（仅当 variable_scope == SCOPE 时使用）
var scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 主变量自定义作用域 ID（仅当 scope_source == CUSTOM_ID 时使用）
var custom_scope_id: String = "":
	set(value):
		custom_scope_id = value
		_update_resource_name()

## 主变量目标节点路径（仅当 scope_source == TARGET_NODE 时使用）
var target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_path = value
		_update_resource_name()

var comparison_operator: ComparisonOperator = ComparisonOperator.EQUALS:
	set(value):
		comparison_operator = value
		_update_resource_name()
		_log_debug("Comparison operator set to: %s" % ComparisonOperator.keys()[value])

# 控制属性（带 setter）
var check_with_another_variable: bool = false:
	set(value):
		check_with_another_variable = value
		_update_resource_name()
		notify_property_list_changed()  # 触发检视器更新

# 条件属性
var compare_variable: String = "":
	set(value):
		compare_variable = value
		_update_resource_name()
		# 触发检视器更新

## 比较变量作用域（三层变量系统）
var compare_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		compare_variable_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 比较变量作用域来源（仅当 compare_variable_scope == SCOPE 时使用）
var compare_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		compare_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 比较变量自定义作用域 ID（仅当 compare_scope_source == CUSTOM_ID 时使用）
var compare_custom_scope_id: String = "":
	set(value):
		compare_custom_scope_id = value
		_update_resource_name()

## 比较变量目标节点路径（仅当 compare_scope_source == TARGET_NODE 时使用）
var compare_target_node_path: NodePath = NodePath(""):
	set(value):
		compare_target_node_path = value
		_update_resource_name()

@export var expected_value: Variant:
	set(value):
		expected_value = value
		_update_resource_name()
		_log_debug("Expected value set to: %s" % str(value))

var case_sensitive: bool = true:
	set(value):
		case_sensitive = value
		_log_debug("Case sensitivity %s" % ("enabled" if value else "disabled"))

## 高级配置
var auto_convert_types: bool = true:
	set(value):
		auto_convert_types = value
		_log_debug("Auto type conversion %s" % ("enabled" if value else "disabled"))

var treat_empty_as_null: bool = false:
	set(value):
		treat_empty_as_null = value
		_log_debug("Treat empty as null %s" % ("enabled" if value else "disabled"))

## 私有属性
var _last_variable_value: Variant = null
var _last_comparison_result: bool = false

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# ========== 变量配置 ==========
	properties.append({
		name = "Variable Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 变量作用域
	properties.append({
		name = "variable_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 只在 variable_scope == SCOPE 时显示 ScopeSource 配置
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 根据主变量作用域来源添加额外属性
		if scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		elif scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "target_node_path",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	# ========== 比较配置 ==========
	properties.append({
		name = "Comparison Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 比较操作符
	properties.append({
		name = "comparison_operator",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Equals,Not Equals,Greater Than,Less Than,Greater Equal,Less Equal,Contains,Not Contains,Is Empty,Is Not Empty,Is Null,Is Not Null,Is True,Is False,Matches Pattern",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 是否用另一个变量比较
	properties.append({
		name = "check_with_another_variable",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 比较变量配置
	if check_with_another_variable:
		# 比较变量名
		properties.append({
			name = "compare_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 比较变量作用域
		properties.append({
			name = "compare_variable_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 compare_variable_scope == SCOPE 时显示 ScopeSource
		if compare_variable_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "compare_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			# 根据比较变量作用域来源添加额外属性
			if compare_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "compare_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif compare_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "compare_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	# ========== 高级配置 ==========
	properties.append({
		name = "Advanced Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 大小写敏感
	properties.append({
		name = "case_sensitive",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 自动类型转换
	properties.append({
		name = "auto_convert_types",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 将空值视为空
	properties.append({
		name = "treat_empty_as_null",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 实现条件化检视器显示（使用 _validate_property 方法）
func _validate_property(property: Dictionary) -> void:
	# 当 check_with_another_variable = false 时，禁用比较变量属性
	if not check_with_another_variable:
		if property.name in ["compare_variable", "compare_variable_scope", "compare_scope_source", "compare_custom_scope_id", "compare_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 当 check_with_another_variable = true 时，禁用期望值属性
	if check_with_another_variable and property.name == "expected_value":
		property.usage = PROPERTY_USAGE_NO_EDITOR

	# 控制主变量 ScopeSource 属性可见性（仅在 variable_scope == SCOPE 时显示）
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
	else:
		# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
		if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 控制比较变量 ScopeSource 属性可见性（仅在 compare_variable_scope == SCOPE 时显示）
	if check_with_another_variable:
		if compare_variable_scope == BaseVariable.VariableScope.SCOPE:
			VariableScopeUtils.validate_scope_source_property(property, compare_scope_source as VariableScopeUtils.ScopeSource)
		else:
			# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
			if property.name in ["compare_scope_source", "compare_custom_scope_id", "compare_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR

## 设置指令元数据（重写基类方法）
func _setup_metadata():
	pass

## 更新资源名称
func _update_resource_name():
	var operator_name = ComparisonOperator.keys()[comparison_operator]
	var value_str: String

	if check_with_another_variable:
		# 使用比较变量名称作为显示值
		if compare_variable.is_empty():
			value_str = FuseLocalization.translate("FUSE_CONDITION_NOT_SET")
		else:
			var compare_scope_str = _get_compare_scope_source_string()
			value_str = "[%s] %s" % [compare_scope_str, compare_variable]
	else:
		# 使用期望值作为显示值
		value_str = _get_value_display_string(expected_value)
		if value_str.length() > 20:
			value_str = value_str.substr(0, 17) + "..."

	var scope_str = _get_scope_source_string()
	resource_name = FuseLocalization.translate_format(
		"FUSE_CONDITION_VARIABLE_FORMAT",
		{"scope": scope_str, "name": variable_name if not variable_name.is_empty() else FuseLocalization.translate("FUSE_CONDITION_UNNAMED"), "op": operator_name, "value": value_str}
	)

	_description = resource_name

## 获取值的显示字符串
func _get_value_display_string(value: Variant) -> String:
	if value == null:
		return "null"
	elif value is String and value.is_empty():
		return '""'
	else:
		return str(value)

## 获取主变量作用域来源字符串
func _get_scope_source_string() -> String:
	# 首先获取作用域类型显示字符串
	var scope_type_str: String
	match variable_scope:
		BaseVariable.VariableScope.LOCAL:
			scope_type_str = FuseLocalization.translate("FUSE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.SCOPE:
			scope_type_str = VariableScopeUtils.get_scope_source_string(
				scope_source as VariableScopeUtils.ScopeSource,
				custom_scope_id,
				target_node_path
			)
		BaseVariable.VariableScope.GLOBAL:
			scope_type_str = FuseLocalization.translate("FUSE_SCOPE_GLOBAL_STR")
		_:
			scope_type_str = FuseLocalization.translate("FUSE_SCOPE_UNKNOWN_STR")

	return scope_type_str

## 获取比较变量作用域来源字符串
func _get_compare_scope_source_string() -> String:
	# 首先获取作用域类型显示字符串
	var scope_type_str: String
	match compare_variable_scope:
		BaseVariable.VariableScope.LOCAL:
			scope_type_str = FuseLocalization.translate("FUSE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.SCOPE:
			scope_type_str = VariableScopeUtils.get_scope_source_string(
				compare_scope_source as VariableScopeUtils.ScopeSource,
				compare_custom_scope_id,
				compare_target_node_path
			)
		BaseVariable.VariableScope.GLOBAL:
			scope_type_str = FuseLocalization.translate("FUSE_SCOPE_GLOBAL_STR")
		_:
			scope_type_str = FuseLocalization.translate("FUSE_SCOPE_UNKNOWN_STR")

	return scope_type_str

## 评估条件
func _evaluate_condition(context: ExecutionContext) -> bool:
	if variable_name.is_empty():
		_log_error("Variable name is empty")
		var error_msg = FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY")
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return false

	# 获取目标变量值
	var actual_value = _get_variable_value(context)
	_last_variable_value = actual_value

	# 确定比较值
	var compare_value: Variant
	if check_with_another_variable:
		# 从另一个变量获取比较值
		if compare_variable.is_empty():
			_log_error("Compare variable name is empty")
			var error_msg = FuseLocalization.translate("FUSE_ERROR_COMPARE_VAR_NAME_EMPTY")
			_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
			return false

		compare_value = _get_compare_variable_value(context)
		if compare_value == null:
			_log_error("无法获取比较变量值: %s" % compare_variable)
			var error_msg = FuseLocalization.translate("FUSE_ERROR_GET_COMPARE_VAR_FAILED")
			_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
			return false
	else:
		# 使用期望值
		compare_value = expected_value

	# 记录调试信息
	var scope_str = _get_scope_source_string()
	_log_debug("Checking variable '%s' (scope: %s): actual=%s, compare=%s, operator=%s" % [
		variable_name, scope_str, str(actual_value), str(compare_value),
		ComparisonOperator.keys()[comparison_operator]
	])

	# 执行比较
	var result = _perform_comparison(actual_value, compare_value)
	_last_comparison_result = result

	_log_debug("Comparison result: %s" % ("true" if result else "false"))
	return result

## 获取变量值
func _get_variable_value(context: ExecutionContext) -> Variant:
	var value: Variant = null

	match variable_scope:
		BaseVariable.VariableScope.LOCAL:
			# LOCAL 模式：使用 VariableOperations
			value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.LOCAL, null)

		BaseVariable.VariableScope.GLOBAL:
			# GLOBAL 模式：使用 VariableOperations
			value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.GLOBAL, null)

		BaseVariable.VariableScope.SCOPE:
			# SCOPE 模式：根据 ScopeSource 获取作用域容器
			if scope_source == ScopeSource.NEAREST:
				# NEAREST 模式：使用 VariableOperations
				value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.SCOPE, null)
			else:
				# 其他模式：获取指定作用域容器并读取变量
				var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					custom_scope_id,
					target_node_path
				)

				if scope_container != null and scope_container.has_variable(variable_name):
					value = scope_container.get_variable(variable_name)

	# 处理空值情况
	if treat_empty_as_null and value is String and value.is_empty():
		return null

	return value

## 获取比较变量值
func _get_compare_variable_value(context: ExecutionContext) -> Variant:
	var value: Variant = null

	match compare_variable_scope:
		BaseVariable.VariableScope.LOCAL:
			# LOCAL 模式：使用 VariableOperations
			value = VariableOperations.get_variable(context, compare_variable, BaseVariable.VariableScope.LOCAL, null)

		BaseVariable.VariableScope.GLOBAL:
			# GLOBAL 模式：使用 VariableOperations
			value = VariableOperations.get_variable(context, compare_variable, BaseVariable.VariableScope.GLOBAL, null)

		BaseVariable.VariableScope.SCOPE:
			# SCOPE 模式：根据 ScopeSource 获取作用域容器
			if compare_scope_source == ScopeSource.NEAREST:
				# NEAREST 模式：使用 VariableOperations
				value = VariableOperations.get_variable(context, compare_variable, BaseVariable.VariableScope.SCOPE, null)
			else:
				# 其他模式：获取指定作用域容器并读取变量
				var utils_scope_source = compare_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					compare_custom_scope_id,
					compare_target_node_path
				)

				if scope_container != null and scope_container.has_variable(compare_variable):
					value = scope_container.get_variable(compare_variable)

	return value

## 执行比较
func _perform_comparison(actual_value: Variant, expected_value: Variant) -> bool:
	match comparison_operator:
		ComparisonOperator.EQUALS:
			return _compare_equals(actual_value, expected_value)
		ComparisonOperator.NOT_EQUALS:
			return not _compare_equals(actual_value, expected_value)
		ComparisonOperator.GREATER_THAN:
			return _compare_greater_than(actual_value, expected_value)
		ComparisonOperator.LESS_THAN:
			return _compare_less_than(actual_value, expected_value)
		ComparisonOperator.GREATER_EQUAL:
			return _compare_greater_equal(actual_value, expected_value)
		ComparisonOperator.LESS_EQUAL:
			return _compare_less_equal(actual_value, expected_value)
		ComparisonOperator.CONTAINS:
			return _compare_contains(actual_value, expected_value)
		ComparisonOperator.NOT_CONTAINS:
			return not _compare_contains(actual_value, expected_value)
		ComparisonOperator.IS_EMPTY:
			return _compare_is_empty(actual_value)
		ComparisonOperator.IS_NOT_EMPTY:
			return not _compare_is_empty(actual_value)
		ComparisonOperator.IS_NULL:
			return actual_value == null
		ComparisonOperator.IS_NOT_NULL:
			return actual_value != null
		ComparisonOperator.IS_TRUE:
			return _compare_is_true(actual_value)
		ComparisonOperator.IS_FALSE:
			return not _compare_is_true(actual_value)
		ComparisonOperator.MATCHES_PATTERN:
			return _compare_matches_pattern(actual_value, expected_value)
		_:
			_log_error("Unknown comparison operator: %s" % ComparisonOperator.keys()[comparison_operator])
			return false

## 等于比较
func _compare_equals(actual: Variant, expected: Variant) -> bool:
	# 处理 null 值
	if actual == null and expected == null:
		return true
	if actual == null or expected == null:
		return false

	# 字符串比较需要考虑大小写敏感性
	if actual is String and expected is String:
		if case_sensitive:
			return actual == expected
		else:
			return actual.to_lower() == expected.to_lower()

	# 尝试类型转换
	if auto_convert_types:
		var converted = _convert_value(actual, typeof(expected))
		_log_debug("Type conversion: %s (%s) -> %s (%s) = %s" % [
			str(actual), typeof(actual),
			str(expected), typeof(expected),
			str(converted)
		])
		if converted != null:
			return converted == expected

	# 直接比较
	return actual == expected

## 大于比较
func _compare_greater_than(actual: Variant, expected: Variant) -> bool:
	var actual_num = _convert_to_number(actual)
	var expected_num = _convert_to_number(expected)

	if actual_num == 0.0 and expected_num == 0.0:
		_log_warning("Cannot compare %s with %s for greater_than operation" % [
			_get_type_name(typeof(actual)), _get_type_name(typeof(expected))
		])
		return false

	return actual_num > expected_num

## 小于比较
func _compare_less_than(actual: Variant, expected: Variant) -> bool:
	var actual_num = _convert_to_number(actual)
	var expected_num = _convert_to_number(expected)

	if actual_num == 0.0 and expected_num == 0.0:
		_log_warning("Cannot compare %s with %s for less_than operation" % [
			_get_type_name(typeof(actual)), _get_type_name(typeof(expected))
		])
		return false

	return actual_num < expected_num

## 大于等于比较
func _compare_greater_equal(actual: Variant, expected: Variant) -> bool:
	return _compare_greater_than(actual, expected) or _compare_equals(actual, expected)

## 小于等于比较
func _compare_less_equal(actual: Variant, expected: Variant) -> bool:
	return _compare_less_than(actual, expected) or _compare_equals(actual, expected)

## 包含比较
func _compare_contains(actual: Variant, expected: Variant) -> bool:
	if actual is String and expected is String:
		if case_sensitive:
			return actual.find(expected) >= 0
		else:
			return actual.to_lower().find(expected.to_lower()) >= 0
	elif actual is Array:
		return actual.has(expected)
	elif actual is Dictionary:
		return actual.has(expected)
	else:
		_log_warning("Contains operation not supported for types: %s, %s" % [
			_get_type_name(typeof(actual)), _get_type_name(typeof(expected))
		])
		return false

## 为空比较
func _compare_is_empty(actual: Variant) -> bool:
	if actual is String:
		return actual.is_empty()
	elif actual is Array:
		return actual.is_empty()
	elif actual is Dictionary:
		return actual.is_empty()
	elif actual == null:
		return true
	else:
		return false

## 为真比较
func _compare_is_true(actual: Variant) -> bool:
	if actual is bool:
		return actual
	elif actual is int:
		return actual != 0
	elif actual is float:
		return actual != 0.0
	elif actual is String:
		return not actual.is_empty()
	else:
		return actual != null

## 模式匹配比较
func _compare_matches_pattern(actual: Variant, expected: Variant) -> bool:
	if not (actual is String and expected is String):
		_log_warning("Pattern matching requires both values to be strings")
		return false

	var regex = RegEx.new()
	var compile_result = regex.compile(expected)
	if compile_result != OK:
		_log_error("Invalid regular expression pattern: %s" % expected)
		return false

	var match_result = regex.search(actual)
	return match_result != null

## 值转换
func _convert_value(value: Variant, target_type: int) -> Variant:
	match target_type:
		TYPE_BOOL:
			return _convert_to_bool(value)
		TYPE_INT:
			return _convert_to_int(value)
		TYPE_FLOAT:
			return _convert_to_float(value)
		TYPE_STRING:
			return str(value)
		_:
			return null

## 转换为数字
func _convert_to_number(value: Variant) -> float:
	match typeof(value):
		TYPE_INT:
			return float(value)
		TYPE_FLOAT:
			return value
		TYPE_STRING:
			var num = float(value)
			if not num.is_nan():
				return num
		TYPE_BOOL:
			return 1.0 if value else 0.0
		_:
			return 0.0
	return 0.0

## 转换为布尔值
func _convert_to_bool(value: Variant) -> bool:
	match typeof(value):
		TYPE_BOOL:
			return value
		TYPE_INT:
			return value != 0
		TYPE_FLOAT:
			return value != 0.0
		TYPE_STRING:
			return not value.is_empty()
		_:
			return value != null

## 转换为整数
func _convert_to_int(value: Variant) -> int:
	match typeof(value):
		TYPE_INT:
			return value
		TYPE_FLOAT:
			return int(value)
		TYPE_STRING:
			if value.is_valid_int():
				return int(value)
			else:
				return 0
		TYPE_BOOL:
			return 1 if value else 0
		_:
			return 0

## 转换为浮点数
func _convert_to_float(value: Variant) -> float:
	match typeof(value):
		TYPE_FLOAT:
			return value
		TYPE_INT:
			return float(value)
		TYPE_STRING:
			var num = float(value)
			if not num.is_nan():
				return num
		TYPE_BOOL:
			return 1.0 if value else 0.0
		_:
			return 0.0
	return 0.0

## 获取类型名称
func _get_type_name(type_value: int) -> String:
	match type_value:
		TYPE_NIL: return "NIL"
		TYPE_BOOL: return "BOOL"
		TYPE_INT: return "INT"
		TYPE_FLOAT: return "FLOAT"
		TYPE_STRING: return "STRING"
		TYPE_VECTOR2: return "VECTOR2"
		TYPE_VECTOR2I: return "VECTOR2I"
		TYPE_VECTOR3: return "VECTOR3"
		TYPE_VECTOR3I: return "VECTOR3I"
		TYPE_COLOR: return "COLOR"
		TYPE_ARRAY: return "ARRAY"
		TYPE_DICTIONARY: return "DICTIONARY"
		TYPE_OBJECT: return "OBJECT"
		TYPE_NODE_PATH: return "NODE_PATH"
		_: return "UNKNOWN"

## 获取条件类型
func get_condition_type() -> String:
	return "check_variable"

## 获取条件分类
func get_condition_category() -> String:
	return "variable"

## 声明变量读写模式（精确化静态分析）
## variable_name/compare_variable 均为 read（_evaluate_condition 中 _get_variable_value 仅读）
func get_variable_modes() -> Array[Dictionary]:
	return [
		{"name": "variable_name", "mode": "read"},
		{"name": "compare_variable", "mode": "read"},
	]

## 获取条件描述
func get_description() -> String:
	if variable_name.is_empty():
		return FuseLocalization.translate("FUSE_CONDITION_VARIABLE_NOT_SET")

	var operator_name = ComparisonOperator.keys()[comparison_operator]
	var value_str: String

	if check_with_another_variable:
		if compare_variable.is_empty():
			value_str = FuseLocalization.translate("FUSE_CONDITION_NO_COMPARE_VAR_SPECIFIED")
		else:
			var compare_scope_str = _get_compare_scope_source_string()
			value_str = "%s [%s]" % [compare_variable, compare_scope_str]
	else:
		value_str = _get_value_display_string(expected_value)

	var scope_str = _get_scope_source_string()
	return "%s [%s] %s %s" % [variable_name, scope_str, operator_name, value_str]

## 获取条件参数
func get_parameters() -> Dictionary:
	var params = {
		"variable_name": variable_name,
		"variable_scope": variable_scope,
		"comparison_operator": comparison_operator,
		"case_sensitive": case_sensitive,
		"auto_convert_types": auto_convert_types,
		"treat_empty_as_null": treat_empty_as_null,
		"check_with_another_variable": check_with_another_variable
	}

	# 只在 SCOPE 作用域时添加 ScopeSource 参数
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		params["scope_source"] = scope_source
		params["custom_scope_id"] = custom_scope_id
		params["target_node_path"] = target_node_path

	if check_with_another_variable:
		params["compare_variable"] = compare_variable
		params["compare_variable_scope"] = compare_variable_scope
		# 只在 SCOPE 作用域时添加 ScopeSource 参数
		if compare_variable_scope == BaseVariable.VariableScope.SCOPE:
			params["compare_scope_source"] = compare_scope_source
			params["compare_custom_scope_id"] = compare_custom_scope_id
			params["compare_target_node_path"] = compare_target_node_path
	else:
		params["expected_value"] = expected_value

	return params

## 计算条件依赖
func _compute_dependencies() -> Array[String]:
	var dependencies = []

	if not variable_name.is_empty():
		dependencies.append(variable_name)

	if check_with_another_variable and not compare_variable.is_empty():
		dependencies.append(compare_variable)

	return dependencies

## 计算线程安全性
## 线程安全规则：
## - LOCAL、GLOBAL：安全（纯变量操作，无需 ExecutionContext）
## - SCOPE + TARGET_NODE/TRIGGER_SCOPE：不安全（需要访问 ExecutionContext 解析节点）
## - SCOPE + NEAREST/CUSTOM_ID：不安全（保守处理）
## 如果比较两个变量，两个变量的作用域都要检查
func _compute_thread_safety() -> bool:
	# 调用基类缓存逻辑
	if _thread_safety_computed:
		return _thread_safety_cached

	var is_safe := true

	# 检查主变量作用域
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		# SCOPE 类型需要检查 scope_source
		match scope_source:
			ScopeSource.TARGET_NODE, ScopeSource.TRIGGER_SCOPE:
				is_safe = false  # 需要 ExecutionContext
			ScopeSource.NEAREST, ScopeSource.CUSTOM_ID:
				is_safe = false  # 保守处理
			# LOCAL, GLOBAL 默认 true（但这些不在 SCOPE 类型中）

	# 如果是比较两个变量，还需要检查比较变量的作用域
	if is_safe and check_with_another_variable:
		if compare_variable_scope == BaseVariable.VariableScope.SCOPE:
			match compare_scope_source:
				ScopeSource.TARGET_NODE, ScopeSource.TRIGGER_SCOPE:
					is_safe = false
				ScopeSource.NEAREST, ScopeSource.CUSTOM_ID:
					is_safe = false

	_thread_safety_cached = is_safe
	_thread_safety_computed = true
	return _thread_safety_cached

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()

	if variable_name.is_empty():
		var error_msg = FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY")
		errors.append(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)

	# 验证 SCOPE 作用域时才验证 ScopeSource 参数
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source,
			custom_scope_id,
			target_node_path
		))

	# 验证变量比较模式
	if check_with_another_variable:
		if compare_variable.is_empty():
			var error_msg = FuseLocalization.translate("FUSE_ERROR_COMPARE_VAR_NAME_EMPTY")
			errors.append(error_msg)
			_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)

		# 验证 SCOPE 作用域时才验证 ScopeSource 参数
		if compare_variable_scope == BaseVariable.VariableScope.SCOPE:
			var compare_utils_scope_source = compare_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				compare_utils_scope_source,
				compare_custom_scope_id,
				compare_target_node_path
			))
	else:
		# 验证比较操作符和期望值的兼容性
		if not _validate_operator_compatibility():
			errors.append(FuseLocalization.translate("FUSE_ERROR_OPERATOR_INCOMPATIBLE"))

	return errors

## 验证操作符兼容性
func _validate_operator_compatibility() -> bool:
	match comparison_operator:
		ComparisonOperator.CONTAINS, ComparisonOperator.NOT_CONTAINS:
			# 包含操作需要期望值是字符串或基本类型
			if expected_value != null and not (expected_value is String or expected_value is int or expected_value is float or expected_value is bool):
				_log_warning("Contains operations work best with string or basic types")
				return false
		ComparisonOperator.MATCHES_PATTERN:
			# 模式匹配需要期望值是有效的正则表达式
			if expected_value is String:
				var regex = RegEx.new()
				var result = regex.compile(expected_value)
				if result != OK:
					_log_error("Invalid regular expression pattern: %s" % expected_value)
					return false
		ComparisonOperator.IS_EMPTY, ComparisonOperator.IS_NOT_EMPTY:
			# 这些操作不需要期望值
			if expected_value != null:
				_log_warning("This operator does not require an expected value")
				return true  # 允许但不推荐
		ComparisonOperator.IS_NULL, ComparisonOperator.IS_NOT_NULL:
			# 这些操作不需要期望值
			if expected_value != null:
				_log_warning("This operator does not require an expected value")
				return true  # 允许但不推荐
		ComparisonOperator.IS_TRUE, ComparisonOperator.IS_FALSE:
			# 这些操作不需要期望值
			if expected_value != null:
				_log_warning("This operator does not require an expected value")
				return true  # 允许但不推荐
		_:
			# 其他操作符需要期望值
			if expected_value == null:
				_log_warning("This operator requires an expected value")
				return false

	return true

## 获取详细条件信息
func get_detailed_info() -> Dictionary:
	var info = super.get_detailed_info()
	info["variable_name"] = variable_name
	info["variable_scope"] = BaseVariable.VariableScope.keys()[variable_scope]
	info["comparison_operator"] = ComparisonOperator.keys()[comparison_operator]
	info["last_variable_value"] = _last_variable_value
	info["last_comparison_result"] = _last_comparison_result
	info["case_sensitive"] = case_sensitive
	info["auto_convert_types"] = auto_convert_types
	info["treat_empty_as_null"] = treat_empty_as_null
	info["check_with_another_variable"] = check_with_another_variable

	# 只在 SCOPE 作用域时添加 ScopeSource 信息
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		info["scope_source"] = ScopeSource.keys()[scope_source]
		info["custom_scope_id"] = custom_scope_id
		info["target_node_path"] = target_node_path

	if check_with_another_variable:
		info["compare_variable"] = compare_variable
		info["compare_variable_scope"] = BaseVariable.VariableScope.keys()[compare_variable_scope]
		# 只在 SCOPE 作用域时添加 ScopeSource 信息
		if compare_variable_scope == BaseVariable.VariableScope.SCOPE:
			info["compare_scope_source"] = ScopeSource.keys()[compare_scope_source]
			info["compare_custom_scope_id"] = compare_custom_scope_id
			info["compare_target_node_path"] = compare_target_node_path
	else:
		info["expected_value"] = expected_value

	return info

## 重置条件状态
func reset():
	super.reset()
	_last_variable_value = null
	_last_comparison_result = false
	_log_debug("CheckVariable condition reset")

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_CHECK_VARIABLE_NAME"
	metadata.category_key = "FUSE_CATEGORY_VARIABLE_OPERATIONS"
	metadata.description_key = "FUSE_CONDITION_CHECK_VARIABLE_DESC"
	metadata.keywords = ["variable", "变量", "check", "检查", "compare", "比较", "equals", "等于", "value", "值", "condition", "条件", "scope", "作用域", "local", "本地", "global", "全局"]
	metadata.builtin_icon = "LocalVariable"
	return metadata
