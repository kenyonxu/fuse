@tool
@icon("res://addons/fuse/icons/builtin/LocalVariable.png")
extends BaseCondition
class_name CompareVariableTemplate

## 变量比较条件描述（简短说明条件的功能）
##
## 变量比较条件说明：
## - 检查变量值与期望值的比较
## - 支持多种比较操作符
## - 支持局部和全局变量

# =============================================
# 比较操作符枚举
# =============================================

enum ComparisonOperator {
	EQUALS,           ## 等于 (==)
	NOT_EQUALS,       ## 不等于 (!=)
	GREATER_THAN,     ## 大于 (>)
	LESS_THAN,        ## 小于 (<)
	GREATER_EQUAL,    ## 大于等于 (>=)
	LESS_EQUAL,       ## 小于等于 (<=)
	IS_TRUE,          ## 为 true
	IS_FALSE          ## 为 false
}

# =============================================
# 参数定义
# =============================================

## 变量名称
@export_group("Variable Comparison")
@export var variable_name: String = "":
	set(value):
		variable_name = value
		_update_resource_name()

## 变量作用域
@export var variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		variable_scope = value
		_update_resource_name()

## 比较操作符
@export var comparison_operator: ComparisonOperator = ComparisonOperator.EQUALS:
	set(value):
		comparison_operator = value
		_update_resource_name()

## 期望值
@export var expected_value: Variant:
	set(value):
		expected_value = value
		_update_resource_name()

# =============================================
# 元数据方法
# =============================================

## 获取条件元数据（必需）
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_XXX_NAME"
	metadata.category_key = "FUSE_CATEGORY_VARIABLES"
	metadata.description_key = "FUSE_CONDITION_XXX_DESC"
	metadata.keywords = ["variable", "变量", "compare", "比较", "check", "检查"]
	metadata.builtin_icon = "LocalVariable"
	return metadata

# =============================================
# 资源名称和描述
# =============================================

## 更新资源名称（必需）
func _update_resource_name():
	var operator_name = ComparisonOperator.keys()[comparison_operator]
	var scope_name = BaseVariable.VariableScope.keys()[variable_scope]

	var value_str = str(expected_value)
	if value_str.length() > 20:
		value_str = value_str.substr(0, 17) + "..."

	resource_name = "变量 [%s:%s] %s %s" % [
		scope_name,
		variable_name if not variable_name.is_empty() else "未命名",
		operator_name,
		value_str
	]

## 获取条件类型
func get_condition_type() -> String:
	return "variable_comparison"

## 获取条件分类
func get_condition_category() -> String:
	return "variable"

## 获取条件描述
func get_description() -> String:
	if variable_name.is_empty():
		return "变量比较 (未设置变量名)"

	var operator_name = ComparisonOperator.keys()[comparison_operator]
	var scope_name = BaseVariable.VariableScope.keys()[variable_scope]

	return "变量 '%s' (%s) %s %s" % [
		variable_name,
		scope_name,
		operator_name,
		str(expected_value)
	]

# =============================================
# 条件评估
# =============================================

## 评估条件（必需）
func _evaluate_condition(context: ExecutionContext) -> bool:
	# ============================================
	# 1. 验证变量名
	# ============================================

	if variable_name.is_empty():
		_log_error("变量名称不能为空")
		_create_fuse_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		return false

	# ============================================
	# 2. 获取变量值
	# ============================================

	var actual_value = _get_variable_value(context)

	if actual_value == null and not VariableOperations.has_variable(context, variable_name, variable_scope):
		_log_error("变量不存在: %s" % variable_name)
		_create_fuse_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"variable": variable_name})
		return false

	# ============================================
	# 3. 执行比较
	# ============================================

	var result = _perform_comparison(actual_value, expected_value)

	# ============================================
	# 4. 记录日志
	# ============================================

	_log_debug("变量比较: %s %s %s => %s" % [
		str(actual_value),
		ComparisonOperator.keys()[comparison_operator],
		str(expected_value),
		"true" if result else "false"
	])

	# ============================================
	# 5. 返回布尔值
	# ============================================

	return result

# =============================================
# 变量获取
# =============================================

## 获取变量值（使用 VariableOperations 统一访问三层作用域）
func _get_variable_value(context: ExecutionContext) -> Variant:
	if context == null:
		_log_error("ExecutionContext is null")
		return null

	# 使用 VariableOperations 统一获取变量（支持 LOCAL/SCOPE/GLOBAL）
	return VariableOperations.get_variable(context, variable_name, variable_scope, null)

# =============================================
# 比较逻辑
# =============================================

## 执行比较
func _perform_comparison(actual: Variant, expected: Variant) -> bool:
	match comparison_operator:
		ComparisonOperator.EQUALS:
			return actual == expected

		ComparisonOperator.NOT_EQUALS:
			return actual != expected

		ComparisonOperator.GREATER_THAN:
			return _compare_greater_than(actual, expected)

		ComparisonOperator.LESS_THAN:
			return _compare_less_than(actual, expected)

		ComparisonOperator.GREATER_EQUAL:
			return _compare_greater_than(actual, expected) or actual == expected

		ComparisonOperator.LESS_EQUAL:
			return _compare_less_than(actual, expected) or actual == expected

		ComparisonOperator.IS_TRUE:
			return bool(actual) == true

		ComparisonOperator.IS_FALSE:
			return bool(actual) == false

		_:
			_log_error("未知的比较操作符: %s" % ComparisonOperator.keys()[comparison_operator])
			return false

## 大于比较
func _compare_greater_than(actual: Variant, expected: Variant) -> bool:
	var actual_num = _convert_to_number(actual)
	var expected_num = _convert_to_number(expected)

	return actual_num > expected_num

## 小于比较
func _compare_less_than(actual: Variant, expected: Variant) -> bool:
	var actual_num = _convert_to_number(actual)
	var expected_num = _convert_to_number(expected)

	return actual_num < expected_num

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

# =============================================
# 依赖计算
# =============================================

## 计算依赖
func _compute_dependencies() -> Array[String]:
	var dependencies = []

	if not variable_name.is_empty():
		dependencies.append(variable_name)

	return dependencies

# =============================================
# 参数方法
# =============================================

## 获取参数
func get_parameters() -> Dictionary:
	return {
		"variable_name": variable_name,
		"variable_scope": BaseVariable.VariableScope.keys()[variable_scope],
		"comparison_operator": comparison_operator,
		"expected_value": expected_value
	}

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("variable_name"):
		variable_name = parameters["variable_name"]
	if parameters.has("variable_scope"):
		variable_scope = parameters["variable_scope"]
	if parameters.has("comparison_operator"):
		comparison_operator = parameters["comparison_operator"]
	if parameters.has("expected_value"):
		expected_value = parameters["expected_value"]

# =============================================
# 验证
# =============================================

## 验证条件配置（必需）
func validate() -> Array[String]:
	var errors: Array[String] = super.validate()

	if variable_name.is_empty():
		errors.append("变量名称不能为空")

	return errors
