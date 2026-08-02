@tool
@icon("res://addons/fuse/icons/builtin/LocalVariable.png")
extends BaseCondition
class_name CompareVariable

## 变量比较条件
##
## 比较变量值与给定值的关系。
##
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问

## 作用域来源
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 变量名
@export_group("Variable Comparison")
var variable_name: String = "":
	set(value):
		variable_name = value
		clear_dependencies_cache()
		_update_resource_name()

## 作用域来源
var scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 自定义作用域 ID（CUSTOM_ID 模式使用）
var custom_scope_id: String = "":
	set(value):
		custom_scope_id = value
		_update_resource_name()

## 目标节点路径（TARGET_NODE 模式使用）
var target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_path = value
		_update_resource_name()

## 比较运算符
enum ComparisonOperator {
	EQUAL,              ## 等于
	NOT_EQUAL,          ## 不等于
	GREATER_THAN,       ## 大于
	LESS_THAN,          ## 小于
	GREATER_EQUAL,      ## 大于等于
	LESS_EQUAL          ## 小于等于
}

@export var comparison_operator: ComparisonOperator = ComparisonOperator.EQUAL

## 比较值
@export var compare_value: Variant:
	set(new_value):
		compare_value = new_value
		_update_resource_name()

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		name = "variable_name",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "scope_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 根据作用域来源添加额外属性
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

	return properties


## 更新资源名称（必需）
func _update_resource_name():
	if variable_name.is_empty():
		resource_name = FuseLocalization.translate("FUSE_CONDITION_VAR_COMPARISON_NOT_SET")
		return

	var op_symbol = _get_operator_symbol()
	var value_str = str(compare_value)

	# 限制值长度
	if value_str.length() > 20:
		value_str = value_str.substr(0, 17) + "..."

	# 添加作用域信息
	var scope_str = _get_scope_source_string()

	resource_name = "%s [%s] %s %s" % [
		variable_name,
		scope_str,
		op_symbol,
		value_str
	]

## 评估条件
func _evaluate_condition(context: ExecutionContext) -> bool:
	# 验证变量名
	if variable_name.is_empty():
		var error_msg = FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return false

	# 获取变量值
	var var_value: Variant
	if scope_source == ScopeSource.NEAREST:
		# NEAREST 模式：从最近的作用域容器读取
		var_value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.SCOPE, null)
	else:
		# 其他模式：从指定作用域容器读取
		var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
		var scope_container = VariableScopeUtils.get_scope_container_by_source(
			context,
			utils_scope_source,
			custom_scope_id,
			target_node_path
		)

		if scope_container == null:
			var error_msg = FuseLocalization.translate("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND")
			_log_error(error_msg)
			_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
			return false

		# 从作用域容器获取变量
		if not scope_container.has_variable(variable_name):
			var error_msg = FuseLocalization.translate_format("FUSE_ERROR_VAR_NOT_FOUND", {"name": variable_name})
			_log_error(error_msg)
			_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
			return false

		var_value = scope_container.get_variable(variable_name)

	# 执行比较
	match comparison_operator:
		ComparisonOperator.EQUAL:
			return var_value == compare_value
		ComparisonOperator.NOT_EQUAL:
			return var_value != compare_value
		ComparisonOperator.GREATER_THAN:
			return var_value > compare_value if var_value is float or var_value is int else false
		ComparisonOperator.LESS_THAN:
			return var_value < compare_value if var_value is float or var_value is int else false
		ComparisonOperator.GREATER_EQUAL:
			return var_value >= compare_value if var_value is float or var_value is int else false
		ComparisonOperator.LESS_EQUAL:
			return var_value <= compare_value if var_value is float or var_value is int else false
		_:
			return false

	# 执行比较
	var result := false

	match comparison_operator:
		ComparisonOperator.EQUAL:
			result = _compare_equal(var_value, compare_value)
		ComparisonOperator.NOT_EQUAL:
			result = _compare_not_equal(var_value, compare_value)
		ComparisonOperator.GREATER_THAN:
			result = _compare_greater_than(var_value, compare_value)
		ComparisonOperator.LESS_THAN:
			result = _compare_less_than(var_value, compare_value)
		ComparisonOperator.GREATER_EQUAL:
			result = _compare_greater_equal(var_value, compare_value)
		ComparisonOperator.LESS_EQUAL:
			result = _compare_less_equal(var_value, compare_value)
		_:
			var error_msg = FuseLocalization.translate_format("FUSE_ERROR_UNKNOWN_COMPARISON_OPERATOR", {"op": comparison_operator})
			_log_error(error_msg)
			return false

	_log_debug(FuseLocalization.translate_format(
		"FUSE_CONDITION_LOG_VAR_COMPARISON",
		{"var": variable_name, "value": str(var_value), "op": _get_operator_symbol(), "compare": str(compare_value), "result": result}
	))

	return result

## 计算依赖
func _compute_dependencies() -> Array[String]:
	if not variable_name.is_empty():
		return [variable_name]
	return []

## 获取条件类型
func get_condition_type() -> String:
	return "variable_comparison"

## 获取条件分类
func get_condition_category() -> String:
	return "variable"

## 声明变量读写模式（精确化静态分析）
## variable_name 仅 read（_evaluate 中读取比较）
func get_variable_modes() -> Array[Dictionary]:
	return [
		{"name": "variable_name", "mode": "read"},
	]

## 获取条件描述
func get_description() -> String:
	if variable_name.is_empty():
		return FuseLocalization.translate("FUSE_CONDITION_VAR_COMPARISON_DESC_NOT_SET")

	var op_symbol = _get_operator_symbol()
	var value_str = str(compare_value)

	# 限制值长度
	if value_str.length() > 20:
		value_str = value_str.substr(0, 17) + "..."

	# 添加作用域信息
	var scope_str = _get_scope_source_string()

	var desc = "%s [%s] %s %s" % [
		variable_name,
		scope_str,
		op_symbol,
		value_str
	]

	# 限制描述长度
	if desc.length() > 50:
		desc = desc.substr(0, 47) + "..."

	return desc

## 获取运算符符号
func _get_operator_symbol() -> String:
	match comparison_operator:
		ComparisonOperator.EQUAL: return "=="
		ComparisonOperator.NOT_EQUAL: return "!="
		ComparisonOperator.GREATER_THAN: return ">"
		ComparisonOperator.LESS_THAN: return "<"
		ComparisonOperator.GREATER_EQUAL: return ">="
		ComparisonOperator.LESS_EQUAL: return "<="
		_: return "?"

## 比较函数：等于
func _compare_equal(a: Variant, b: Variant) -> bool:
	# 类型相同时直接比较
	if typeof(a) == typeof(b):
		return a == b

	# 数值类型之间的比较
	if _is_numeric(a) and _is_numeric(b):
		return _to_number(a) == _to_number(b)

	# 字符串与数值之间的比较
	if a is String and _is_numeric(b):
		return _to_number(a) == _to_number(b)
	if _is_numeric(a) and b is String:
		return _to_number(a) == _to_number(b)

	return a == b

## 比较函数：不等于
func _compare_not_equal(a: Variant, b: Variant) -> bool:
	return not _compare_equal(a, b)

## 比较函数：大于
func _compare_greater_than(a: Variant, b: Variant) -> bool:
	if not (_is_numeric(a) and _is_numeric(b)):
		_log_warning("无法比较非数值类型: %s 和 %s" % [type_string(typeof(a)), type_string(typeof(b))])
		return false

	return _to_number(a) > _to_number(b)

## 比较函数：小于
func _compare_less_than(a: Variant, b: Variant) -> bool:
	if not (_is_numeric(a) and _is_numeric(b)):
		_log_warning("无法比较非数值类型: %s 和 %s" % [type_string(typeof(a)), type_string(typeof(b))])
		return false

	return _to_number(a) < _to_number(b)

## 比较函数：大于等于
func _compare_greater_equal(a: Variant, b: Variant) -> bool:
	return _compare_greater_than(a, b) or _compare_equal(a, b)

## 比较函数：小于等于
func _compare_less_equal(a: Variant, b: Variant) -> bool:
	return _compare_less_than(a, b) or _compare_equal(a, b)

## 检查是否为数值类型
func _is_numeric(value: Variant) -> bool:
	return value is int or value is float

## 转换为数值
func _to_number(value: Variant) -> float:
	if value is int:
		return float(value)
	elif value is float:
		return value
	elif value is String:
		var num = float(value)
		if not num.is_nan():
			return num
	return 0.0

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()

	if variable_name.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))

	return errors

## 获取参数
func get_parameters() -> Dictionary:
	return {
		"variable_name": variable_name,
		"comparison_operator": comparison_operator,
		"compare_value": compare_value
	}

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("variable_name"):
		variable_name = parameters["variable_name"]
	if parameters.has("comparison_operator"):
		comparison_operator = parameters["comparison_operator"]
	if parameters.has("compare_value"):
		compare_value = parameters["compare_value"]

	clear_dependencies_cache()

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_VARIABLE_COMPARISON_NAME"
	metadata.category_key = "FUSE_CATEGORY_VARIABLES"
	metadata.description_key = "FUSE_CONDITION_VARIABLE_COMPARISON_DESC"
	metadata.keywords = ["变量", "比较", "variable", "comparison", "等于", "大于", "小于", "equal", "greater", "less", "check"]
	metadata.builtin_icon = "LocalVariable"
	return metadata

## 获取作用域来源字符串
func _get_scope_source_string() -> String:
	return VariableScopeUtils.get_scope_source_string(
		scope_source as VariableScopeUtils.ScopeSource,
		custom_scope_id,
		target_node_path
	)

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
