@tool
@icon("res://addons/fuse/icons/builtin/Code.svg")
extends BaseCondition
class_name ExpressionCondition

## 表达式条件 - 使用 Expression 评估布尔条件
##
## 支持功能:
## - 变量引用: {local:xxx}, {scope:xxx}, {global:xxx}
## - 比较运算: ==, !=, >, <, >=, <=
## - 逻辑运算: and, or, not
## - 三元运算: a if b else c
## - 辅助函数: distance(), direction(), is_zero(), remap(), inverse_lerp(), snap()

# =============================================
# 作用域来源
# =============================================

## 作用域来源（当表达式中使用 {scope:xxx} 时生效）
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# =============================================
# 参数定义
# =============================================

## 布尔表达式字符串
var expression: String = "":
	set(value):
		expression = value
		_update_resource_name()

## SCOPE 来源（当表达式中使用 {scope:xxx} 时生效）
var scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		scope_source = value
		notify_property_list_changed()
		_update_resource_name()

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

## 缓存的辅助实例
var _expr_helper: ExpressionHelper.GameExprHelper

# =============================================
# 元数据方法
# =============================================

static func _get_condition_metadata() -> ConditionMetadata:
	var metadata := ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_EXPRESSION_NAME"
	metadata.category_key = "FUSE_CATEGORY_MATH"
	metadata.description_key = "FUSE_CONDITION_EXPRESSION_DESC"
	metadata.keywords = ["expression", "表达式", "condition", "条件", "bool", "boolean", "compare", "比较", "logic", "逻辑", "math", "数学"]
	metadata.builtin_icon = "Code"
	return metadata

# =============================================
# 属性列表
# =============================================

func _get_property_list() -> Array[Dictionary]:
	var properties := []

	properties.append({
		name = "Expression",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "expression",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_MULTILINE_TEXT,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "Scope Source Config",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "scope_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

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

func _validate_property(property: Dictionary) -> void:
	_hide_scope_source_properties(property, scope_source)

func _hide_scope_source_properties(property: Dictionary, source: ScopeSource) -> void:
	if source != ScopeSource.CUSTOM_ID:
		if property.name == "custom_scope_id":
			property.usage = PROPERTY_USAGE_NO_EDITOR
	if source != ScopeSource.TARGET_NODE:
		if property.name == "target_node_path":
			property.usage = PROPERTY_USAGE_NO_EDITOR

# =============================================
# 资源名称和描述
# =============================================

func _update_resource_name():
	var display_expr := expression
	if display_expr.is_empty():
		resource_name = FuseLocalization.translate("FUSE_CONDITION_EXPRESSION_FORMAT").format({"expr": "<empty>"})
	else:
		if display_expr.length() > 40:
			display_expr = display_expr.substr(0, 37) + "..."
		resource_name = FuseLocalization.translate("FUSE_CONDITION_EXPRESSION_FORMAT").format({"expr": display_expr})
	_description = resource_name

func get_description() -> String:
	return expression

# =============================================
# 条件评估
# =============================================

func _evaluate_condition(context: ExecutionContext) -> bool:
	if expression.is_empty():
		_log_error("Expression is empty")
		_create_fuse_error(FuseLocalization.translate("FUSE_ERROR_EXPRESSION_EMPTY"), FuseError.ErrorType.VALIDATION_ERROR)
		return false

	if _expr_helper == null:
		_expr_helper = ExpressionHelper.GameExprHelper.new()

	var utils_scope := scope_source as VariableScopeUtils.ScopeSource

	var processed_expr := ExpressionHelper.replace_variables(
		expression, context, utils_scope, custom_scope_id, target_node_path, true
	)
	if processed_expr == null:
		_log_error("Failed to replace variables in expression")
		_create_fuse_error(FuseLocalization.translate("FUSE_ERROR_EXPRESSION_REGEX"), FuseError.ErrorType.RUNTIME_ERROR)
		return false

	var error_text := ""
	var result = ExpressionHelper.evaluate(String(processed_expr), _expr_helper, error_text)

	if result == null:
		_log_error("Expression evaluation failed: %s" % error_text)
		_create_fuse_error(
			FuseLocalization.translate_format("FUSE_ERROR_EXPRESSION_PARSE", {"error": error_text}),
			FuseError.ErrorType.RUNTIME_ERROR
		)
		return false

	if not (result is bool):
		_log_error("Expression result is not boolean: %s (%s)" % [str(result), typeof(result)])
		_create_fuse_error(
			FuseLocalization.translate_format("FUSE_ERROR_EXPRESSION_NOT_BOOLEAN", {"result": str(result)}),
			FuseError.ErrorType.RUNTIME_ERROR
		)
		return false

	_log_debug("Expression condition '%s' = %s" % [expression, result])
	return result

# =============================================
# 依赖计算
# =============================================

func _compute_dependencies() -> Array[String]:
	return ExpressionHelper.extract_variable_names(expression)

# =============================================
# 线程安全
# =============================================

func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	var is_safe := true
	match scope_source:
		ScopeSource.CUSTOM_ID, ScopeSource.TARGET_NODE, ScopeSource.TRIGGER_SCOPE:
			is_safe = false

	_thread_safety_cached = is_safe
	_thread_safety_computed = true
	return _thread_safety_cached

# =============================================
# 验证
# =============================================

func validate() -> Array[String]:
	var errors := super.validate()

	if expression.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_EXPRESSION_EMPTY"))

	errors.append_array(ExpressionHelper.validate_syntax(expression))

	if scope_source == ScopeSource.CUSTOM_ID and custom_scope_id.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_ID_EMPTY"))
	if scope_source == ScopeSource.TARGET_NODE and target_node_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_PATH_EMPTY"))

	return errors

# =============================================
# 信息方法
# =============================================

func get_condition_type() -> String:
	return "expression_condition"

func get_condition_category() -> String:
	return "math"

func get_parameters() -> Dictionary:
	var params := {
		"expression": expression,
		"scope_source": scope_source,
	}
	if scope_source == ScopeSource.CUSTOM_ID:
		params["custom_scope_id"] = custom_scope_id
	if scope_source == ScopeSource.TARGET_NODE:
		params["target_node_path"] = target_node_path
	return params

func get_detailed_info() -> Dictionary:
	var info := super.get_detailed_info()
	info["expression"] = expression
	info["scope_source"] = ScopeSource.keys()[scope_source]
	return info

func reset():
	super.reset()
	_log_debug("ExpressionCondition reset")
