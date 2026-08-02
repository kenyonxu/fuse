@tool
@icon("res://addons/fuse/icons/builtin/LocalVariable.png")
extends BaseCondition
class_name CheckVector2VariableAxis

## Vector2 轴检查条件
##
## 检查 Vector2 类型变量的指定轴（x 或 y）是否满足条件。
##
## 重构变量系统: 2026-02-11 - 使用三层变量系统和 ScopeSource

## 作用域来源（仅在 variable_scope == SCOPE 时使用）
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 轴选择枚举
enum VectorAxis {
	X_AXIS = 0,  ## X 轴
	Y_AXIS = 1   ## Y 轴
}

## 比较运算符枚举
enum ComparisonOperator {
	GREATER_THAN = 0,    ## 大于 (>)
	GREATER_EQUAL = 1,   ## 大于等于 (>=)
	EQUAL = 2,           ## 等于 (==)
	LESS_EQUAL = 3,      ## 小于等于 (<=)
	LESS_THAN = 4        ## 小于 (<)
}

# ========== 变量配置 ==========

## 变量名
var variable_name: String = "":
	set(value):
		variable_name = value
		clear_dependencies_cache()
		_update_resource_name()

## 变量作用域（三层变量系统）
var variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		variable_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 作用域来源（仅当 variable_scope == SCOPE 时使用）
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

# ========== 轴配置 ==========

var axis: VectorAxis = VectorAxis.X_AXIS:
	set(value):
		axis = value
		_update_resource_name()

# ========== 比较配置 ==========

## 比较运算符
var comparison_operator: ComparisonOperator = ComparisonOperator.GREATER_THAN:
	set(value):
		comparison_operator = value
		_update_resource_name()

## 比较值
var compare_value: float = 0.0:
	set(new_value):
		compare_value = new_value
		_update_resource_name()

## 私有属性
var _last_axis_value: float = 0.0
var _last_comparison_result: bool = false

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# 变量作用域
	properties.append({
		name = "variable_name",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 轴选择
	properties.append({
		name = "axis",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "X Axis,Y Axis",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 变量作用域
	properties.append({
		name = "variable_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 只在 variable_scope == SCOPE 时显示 ScopeSource
	if variable_scope == BaseVariable.VariableScope.SCOPE:
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


	# 比较运算符
	properties.append({
		name = "comparison_operator",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Greater Than,Greater Equal,Equal,Less Equal,Less Than",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 比较值
	properties.append({
		name = "compare_value",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称（必需）
func _update_resource_name():
	if variable_name.is_empty():
		resource_name = FuseLocalization.translate("FUSE_CONDITION_VECTOR2_AXIS_CHECK_NOT_SET")
		_description = resource_name
		return

	var axis_str = _get_axis_string()
	var op_symbol = _get_operator_symbol()
	var value_str = str(compare_value)

	# 限制值长度
	if value_str.length() > 20:
		value_str = value_str.substr(0, 17) + "..."

	# 添加作用域信息
	var scope_str = _get_scope_source_string()

	resource_name = "%s.%s [%s] %s %s" % [
		variable_name,
		axis_str,
		scope_str,
		op_symbol,
		value_str
	]

	_description = resource_name

## 评估条件（必需）
func _evaluate_condition(context: ExecutionContext) -> bool:
	# 验证变量名
	if variable_name.is_empty():
		var error_msg = FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return false

	# 获取变量值
	var var_value: Variant = null

	match variable_scope:
		BaseVariable.VariableScope.LOCAL:
			var_value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.LOCAL, null)

		BaseVariable.VariableScope.GLOBAL:
			var_value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.GLOBAL, null)

		BaseVariable.VariableScope.SCOPE:
			if scope_source == ScopeSource.NEAREST:
				var_value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.SCOPE, null)
			else:
				# 其他模式：获取指定作用域容器并读取变量
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

				if not scope_container.has_variable(variable_name):
					var error_msg = FuseLocalization.translate_format("FUSE_ERROR_VAR_NOT_FOUND", {"name": variable_name})
					_log_error(error_msg)
					_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
					return false

				var_value = scope_container.get_variable(variable_name)

	# 检查变量是否存在
	if var_value == null:
		# 检查是否真的不存在
		var has_var = VariableOperations.has_variable(context, variable_name, variable_scope)
		if not has_var:
			var error_msg = FuseLocalization.translate_format("FUSE_ERROR_VAR_NOT_FOUND", {"name": variable_name})
			_log_error(error_msg)
			_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
			return false

	# 验证类型
	if not (var_value is Vector2):
		var error_msg = FuseLocalization.translate_format("FUSE_ERROR_VAR_NOT_VECTOR2", {"name": variable_name})
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.RUNTIME_ERROR)
		return false

	# 获取轴值
	var axis_value = _get_axis_value(var_value)
	_last_axis_value = axis_value

	# 执行比较
	var result = _perform_comparison(axis_value, compare_value)
	_last_comparison_result = result

	# 记录日志
	_log_debug(FuseLocalization.translate_format(
		"FUSE_LOG_VECTOR2_AXIS_CHECK",
		{"var": variable_name, "axis": _get_axis_string(), "actual": str(axis_value), "op": _get_operator_symbol(), "compare": str(compare_value), "result": result}
	))

	return result

## 获取作用域来源字符串
func _get_scope_source_string() -> String:
	match variable_scope:
		BaseVariable.VariableScope.LOCAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.GLOBAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_GLOBAL_STR")
		BaseVariable.VariableScope.SCOPE:
			return VariableScopeUtils.get_scope_source_string(
				scope_source as VariableScopeUtils.ScopeSource,
				custom_scope_id,
				target_node_path
			)
		_:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_UNKNOWN_STR")

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 控制作用域属性可见性（仅在 variable_scope == SCOPE 时显示）
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
	else:
		# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
		if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

## 计算依赖（必需）
func _compute_dependencies() -> Array[String]:
	if not variable_name.is_empty():
		return [variable_name]
	return []

## 获取轴值
func _get_axis_value(vector2_value: Vector2) -> float:
	match axis:
		VectorAxis.X_AXIS: return vector2_value.x
		VectorAxis.Y_AXIS: return vector2_value.y
		_: return 0.0

## 获取轴字符串
func _get_axis_string() -> String:
	match axis:
		VectorAxis.X_AXIS: return "x"
		VectorAxis.Y_AXIS: return "y"
		_: return "?"

## 获取运算符符号
func _get_operator_symbol() -> String:
	match comparison_operator:
		ComparisonOperator.GREATER_THAN: return ">"
		ComparisonOperator.GREATER_EQUAL: return ">="
		ComparisonOperator.EQUAL: return "=="
		ComparisonOperator.LESS_EQUAL: return "<="
		ComparisonOperator.LESS_THAN: return "<"
		_: return "?"

## 执行比较
func _perform_comparison(actual: float, expected: float) -> bool:
	match comparison_operator:
		ComparisonOperator.GREATER_THAN: return actual > expected
		ComparisonOperator.GREATER_EQUAL: return actual >= expected
		ComparisonOperator.EQUAL: return is_equal_approx(actual, expected)
		ComparisonOperator.LESS_EQUAL: return actual <= expected
		ComparisonOperator.LESS_THAN: return actual < expected
		_: return false

## 浮点数近似相等比较
func is_equal_approx(a: float, b: float) -> bool:
	return abs(a - b) < 0.00001

## 获取条件类型
func get_condition_type() -> String:
	return "vector2_axis_check"

## 获取条件分类
func get_condition_category() -> String:
	return "variable"

## 声明变量读写模式（精确化静态分析）
## variable_name 仅 read（_evaluate_condition 中读取 Vector2 取轴比较）
func get_variable_modes() -> Array[Dictionary]:
	return [
		{"name": "variable_name", "mode": "read"},
	]

## 获取条件描述
func get_description() -> String:
	if variable_name.is_empty():
		return FuseLocalization.translate("FUSE_CONDITION_VECTOR2_AXIS_CHECK_DESC_NOT_SET")

	var axis_str = _get_axis_string()
	var op_symbol = _get_operator_symbol()
	var desc = "%s.%s %s %s" % [variable_name, axis_str, op_symbol, str(compare_value)]

	if desc.length() > 50:
		desc = desc.substr(0, 47) + "..."

	return desc

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()

	if variable_name.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))

	# 验证 SCOPE 作用域时才验证 ScopeSource 参数
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source,
			custom_scope_id,
			target_node_path
		))

	return errors

## 获取参数
func get_parameters() -> Dictionary:
	var params = {
		"variable_name": variable_name,
		"variable_scope": variable_scope,
		"axis": axis,
		"comparison_operator": comparison_operator,
		"compare_value": compare_value
	}

	# 只在 SCOPE 作用域时添加 ScopeSource 参数
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		params["scope_source"] = scope_source
		params["custom_scope_id"] = custom_scope_id
		params["target_node_path"] = target_node_path

	return params

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("variable_name"):
		variable_name = parameters["variable_name"]
	if parameters.has("variable_scope"):
		variable_scope = parameters["variable_scope"]
	if parameters.has("scope_source"):
		scope_source = parameters["scope_source"]
	if parameters.has("custom_scope_id"):
		custom_scope_id = parameters["custom_scope_id"]
	if parameters.has("target_node_path"):
		target_node_path = parameters["target_node_path"]
	if parameters.has("axis"):
		axis = parameters["axis"]
	if parameters.has("comparison_operator"):
		comparison_operator = parameters["comparison_operator"]
	if parameters.has("compare_value"):
		compare_value = parameters["compare_value"]

	clear_dependencies_cache()

## 获取详细条件信息
func get_detailed_info() -> Dictionary:
	var info = super.get_detailed_info()
	info["variable_name"] = variable_name
	info["variable_scope"] = BaseVariable.VariableScope.keys()[variable_scope]
	info["axis"] = VectorAxis.keys()[axis]
	info["comparison_operator"] = ComparisonOperator.keys()[comparison_operator]
	info["compare_value"] = compare_value
	info["last_axis_value"] = _last_axis_value
	info["last_comparison_result"] = _last_comparison_result

	# 只在 SCOPE 作用域时添加 ScopeSource 信息
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		info["scope_source"] = ScopeSource.keys()[scope_source]
		info["custom_scope_id"] = custom_scope_id
		info["target_node_path"] = target_node_path

	return info

## 重置条件状态
func reset():
	super.reset()
	_last_axis_value = 0.0
	_last_comparison_result = false
	_log_debug("CheckVector2VariableAxis condition reset")

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_VECTOR2_AXIS_CHECK_NAME"
	metadata.category_key = "FUSE_CATEGORY_VARIABLES"
	metadata.description_key = "FUSE_CONDITION_VECTOR2_AXIS_CHECK_DESC"
	metadata.keywords = ["vector2", "axis", "轴", "check", "检查", "x", "y", "vector", "向量", "condition", "条件"]
	metadata.builtin_icon = "LocalVariable"
	return metadata
