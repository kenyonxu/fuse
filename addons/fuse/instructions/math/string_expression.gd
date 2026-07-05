@tool
@icon("res://addons/fuse/icons/builtin/Code.svg")
extends BaseInstruction
class_name StringExpression

## 字符串表达式指令 - 使用表达式拼接和格式化字符串
##
## 支持功能:
## - 变量引用: {local:xxx}, {scope:xxx}, {global:xxx}
## - 字符串拼接: "Hello" + " " + "World"
## - 条件文本: {local:hp} > 0 ? "Alive" : "Dead"
## - 类型转换: str(), int(), float()
## - 字符串工具: format_num(), pad_left(), pad_right()

# =============================================
# 作用域来源
# =============================================

enum ScopeSource {
	NEAREST,
	CUSTOM_ID,
	TRIGGER_SCOPE,
	TARGET_NODE
}

# =============================================
# 参数定义
# =============================================

## 表达式字符串
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

## 自定义作用域 ID
var custom_scope_id: String = "":
	set(value):
		custom_scope_id = value
		_update_resource_name()

## 目标节点路径
var target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_path = value
		_update_resource_name()

## 保存到变量名
var save_to_variable: String = "str_result":
	set(value):
		save_to_variable = value
		_update_resource_name()

## 保存到作用域
var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		save_to_scope = value
		notify_property_list_changed()
		_update_resource_name()

## 保存作用域来源
var save_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		save_scope_source = value
		notify_property_list_changed()
		_update_resource_name()

## 保存自定义作用域 ID
var save_custom_scope_id: String = "":
	set(value):
		save_custom_scope_id = value
		_update_resource_name()

## 保存目标节点路径
var save_target_node_path: NodePath = NodePath(""):
	set(value):
		save_target_node_path = value
		_update_resource_name()

## 缓存的辅助实例
var _expr_helper: ExpressionHelper.GameExprHelper

# =============================================
# 元数据方法
# =============================================

static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata := InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_STRING_EXPRESSION_NAME"
	metadata.category_key = "FUSE_CATEGORY_MATH"
	metadata.description_key = "FUSE_INSTRUCTION_STRING_EXPRESSION_DESC"
	metadata.keywords = ["string", "字符串", "expression", "表达式", "format", "格式化", "concat", "拼接", "text", "文本"]
	metadata.builtin_icon = "Code"
	metadata.execution_hint = InstructionMetadata.ExecutionHint.LIKELY_SYNC
	return metadata

func _setup_metadata():
	pass

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

	properties.append({
		name = "Output",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "save_to_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "save_to_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "save_scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if save_scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "save_custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		elif save_scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "save_target_node_path",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	return properties

func _validate_property(property: Dictionary) -> void:
	_hide_scope_source_properties(property, scope_source, "custom_scope_id", "target_node_path")

	if save_to_scope != BaseVariable.VariableScope.SCOPE:
		if property.name in ["save_scope_source", "save_custom_scope_id", "save_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		_hide_scope_source_properties(property, save_scope_source, "save_custom_scope_id", "save_target_node_path")

func _hide_scope_source_properties(property: Dictionary, source: ScopeSource, custom_id_prop: String, target_node_prop: String) -> void:
	if source != ScopeSource.CUSTOM_ID:
		if property.name == custom_id_prop:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	if source != ScopeSource.TARGET_NODE:
		if property.name == target_node_prop:
			property.usage = PROPERTY_USAGE_NO_EDITOR

# =============================================
# 资源名称和描述
# =============================================

func _update_resource_name():
	var parts := []

	if expression.is_empty():
		parts.append(FuseLocalization.translate("FUSE_VALUE_EXPRESSION_EMPTY"))
	else:
		var display_expr := expression
		if display_expr.length() > 30:
			display_expr = display_expr.substr(0, 27) + "..."
		parts.append("'%s'" % display_expr)

	var scope_str := _get_save_scope_string()
	parts.append("→ %s [%s]" % [save_to_variable, scope_str])

	resource_name = " ".join(parts)

func get_description() -> String:
	return "%s → %s" % [expression, save_to_variable]

func _get_save_scope_string() -> String:
	match save_to_scope:
		BaseVariable.VariableScope.LOCAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.GLOBAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_GLOBAL_STR")
		BaseVariable.VariableScope.SCOPE:
			return VariableScopeUtils.get_scope_source_string(
				save_scope_source as VariableScopeUtils.ScopeSource,
				save_custom_scope_id,
				save_target_node_path
			)
		_:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_UNKNOWN")

# =============================================
# 执行逻辑
# =============================================

func execute(context: ExecutionContext):
	_start_execution(context)

	if expression.is_empty():
		_log_error_localized("FUSE_ERROR_EXPRESSION_EMPTY", {})
		set_error_localized("FUSE_ERROR_EXPRESSION_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	if save_to_variable.is_empty():
		_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	if _expr_helper == null:
		_expr_helper = ExpressionHelper.GameExprHelper.new()

	var utils_scope := scope_source as VariableScopeUtils.ScopeSource

	var processed_expr := ExpressionHelper.replace_variables(
		expression, context, utils_scope, custom_scope_id, target_node_path, true,
		true  # for_string = true, 使用 escape_value_for_string
	)
	if processed_expr == null:
		_log_error_localized("FUSE_ERROR_EXPRESSION_REGEX", {})
		set_error_localized("FUSE_ERROR_EXPRESSION_REGEX", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	var error_text := ""
	var result = ExpressionHelper.evaluate(String(processed_expr), _expr_helper, error_text)
	if result == null:
		_log_error_localized("FUSE_ERROR_EXPRESSION_PARSE", {"error": error_text})
		set_error_localized("FUSE_ERROR_EXPRESSION_PARSE", FuseError.ErrorType.RUNTIME_ERROR, {"error": error_text})
		finished.emit()
		return

	var str_result: String
	if result is String:
		str_result = result
	else:
		str_result = str(result)

	var save_success := _save_result(str_result, context)
	if not save_success:
		finished.emit()
		return

	_log_info_localized("FUSE_LOG_STRING_EXPRESSION_RESULT", {
		"expr": expression,
		"result": str_result
	})

	_on_execution_completed()

# =============================================
# 结果保存
# =============================================

func _save_result(value: String, context: ExecutionContext) -> bool:
	match save_to_scope:
		BaseVariable.VariableScope.LOCAL:
			var success := VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.LOCAL, value)
			if not success:
				_log_error_localized("FUSE_ERROR_SET_LOCAL_VARIABLE_FAILED", {"name": save_to_variable})
				set_error_localized("FUSE_ERROR_SET_LOCAL_VARIABLE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"name": save_to_variable})
			return success

		BaseVariable.VariableScope.SCOPE:
			return _save_to_scope_variable(value, context)

		BaseVariable.VariableScope.GLOBAL:
			var success := VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.GLOBAL, value)
			if not success:
				_log_error_localized("FUSE_ERROR_SET_GLOBAL_VARIABLE_FAILED", {"name": save_to_variable})
				set_error_localized("FUSE_ERROR_SET_GLOBAL_VARIABLE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"name": save_to_variable})
			return success

		_:
			_log_error_localized("FUSE_ERROR_UNKNOWN_SCOPE", {})
			set_error_localized("FUSE_ERROR_UNKNOWN_SCOPE", FuseError.ErrorType.RUNTIME_ERROR, {})
			return false

func _save_to_scope_variable(value: String, context: ExecutionContext) -> bool:
	if save_scope_source == ScopeSource.NEAREST:
		var success := VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.SCOPE, value)
		if not success:
			_log_error_localized("FUSE_ERROR_SET_SCOPE_VARIABLE_FAILED", {"name": save_to_variable})
			set_error_localized("FUSE_ERROR_SET_SCOPE_VARIABLE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"name": save_to_variable})
		return success
	else:
		var utils_scope := save_scope_source as VariableScopeUtils.ScopeSource
		var scope_container := VariableScopeUtils.get_scope_container_by_source(
			context, utils_scope, save_custom_scope_id, save_target_node_path
		)
		if scope_container == null:
			_log_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
			set_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
			return false
		var success := scope_container.set_variable(save_to_variable, value)
		if not success:
			_log_error_localized("FUSE_ERROR_SET_SCOPE_VARIABLE_FAILED", {"name": save_to_variable})
			set_error_localized("FUSE_ERROR_SET_SCOPE_VARIABLE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"name": save_to_variable})
		return success

# =============================================
# 验证
# =============================================

func validate() -> Array[String]:
	var errors := super.validate()

	if expression.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_EXPRESSION_EMPTY"))

	if save_to_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))

	errors.append_array(ExpressionHelper.validate_syntax(expression))

	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		var utils_scope := save_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope, save_custom_scope_id, save_target_node_path
		))

	return errors
