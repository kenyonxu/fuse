@tool
@icon("res://addons/fuse/icons/builtin/Code.svg")
extends BaseInstruction
class_name MathExpression

## 数学表达式指令 - 执行包含变量引用的数学表达式
##
## 支持功能:
## - 变量引用语法: {local:xxx}, {scope:xxx}, {global:xxx}
## - 基础运算: + - * / %
## - 括号优先级: ()
## - 数学函数: abs, min, max, round, floor, ceil, sqrt, pow, clamp
## - 向量字面量: vec2(x, y), vec3(x, y, z)
## - 输出类型: Float, Int, Vector2, Vector3

## 作用域来源
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 输出类型
enum OutputType {
	FLOAT,     ## 浮点数
	INT,       ## 整数
	VECTOR2,   ## 2D 向量
	VECTOR3    ## 3D 向量
}

## 缓存的辅助实例
var _expr_helper: ExpressionHelper.GameExprHelper

# =============================================
# 参数定义
# =============================================

## 表达式字符串
var expression: String = "":
	set(value):
		expression = value
		_update_resource_name()

## 输出类型
var output_type: OutputType = OutputType.FLOAT:
	set(value):
		output_type = value
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

## 保存到变量名
var save_to_variable: String = "expr_result":
	set(value):
		save_to_variable = value
		_update_resource_name()

## 保存到作用域
var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		save_to_scope = value
		notify_property_list_changed()
		_update_resource_name()

## 保存作用域来源（仅当 save_to_scope == SCOPE 时使用）
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

# =============================================
# 元数据方法
# =============================================

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_MATH_EXPRESSION_NAME"
	metadata.category_key = "FUSE_CATEGORY_MATH"
	metadata.description_key = "FUSE_INSTRUCTION_MATH_EXPRESSION_DESC"
	metadata.keywords = ["math", "expression", "formula", "calculate", "math", "expression", "formula", "vector"]
	metadata.builtin_icon = "Code"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 声明变量读写模式（save_to=write）
func get_variable_modes() -> Array[Dictionary]:
	return [{"name": "save_to_variable", "mode": "write"}]

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# Expression 分组
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
		hint_string = "",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "output_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Float,Int,Vector2,Vector3",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Scope 来源配置（当使用 {scope:xxx} 时生效）
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

	# Output 分组
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

	# 只在 save_to_scope == SCOPE 时显示 ScopeSource 配置
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

## 属性验证
func _validate_property(property: Dictionary) -> void:
	# 处理 scope_source 相关属性
	_hide_scope_source_properties(property, scope_source, "custom_scope_id", "target_node_path")

	# 处理 save_scope_source 相关属性
	if save_to_scope != BaseVariable.VariableScope.SCOPE:
		if property.name in ["save_scope_source", "save_custom_scope_id", "save_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		_hide_scope_source_properties(property, save_scope_source, "save_custom_scope_id", "save_target_node_path")

## 隐藏 ScopeSource 相关属性
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

## 更新资源名称
func _update_resource_name():
	var parts := []

	if expression.is_empty():
		parts.append(FuseLocalization.translate("FUSE_VALUE_EXPRESSION_EMPTY"))
	else:
		# 截断表达式显示
		var display_expr := expression
		if display_expr.length() > 30:
			display_expr = display_expr.substr(0, 27) + "..."
		parts.append("'%s'" % display_expr)

	var type_str := ""
	match output_type:
		OutputType.FLOAT: type_str = "Float"
		OutputType.INT: type_str = "Int"
		OutputType.VECTOR2: type_str = "Vector2"
		OutputType.VECTOR3: type_str = "Vector3"

	parts.append("→ %s [%s]" % [save_to_variable, type_str])

	resource_name = " ".join(parts)

## 获取指令描述
func get_description() -> String:
	var scope_str := _get_scope_source_string()
	return "%s → %s [%s]" % [expression, save_to_variable, scope_str]

## 获取作用域来源字符串
func _get_scope_source_string() -> String:
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

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# ============================================
	# 1. 验证参数
	# ============================================

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

	# ============================================
	# 2. 替换表达式中的变量引用
	# ============================================

	var processed_expr := _replace_variables(expression, context)
	if processed_expr == null:
		# 错误已在内部设置
		finished.emit()
		return

	# ============================================
	# 3. 执行表达式
	# ============================================

	var result := _evaluate_expression(processed_expr)
	if result == null:
		# 错误已在内部设置
		finished.emit()
		return

	# ============================================
	# 4. 类型转换
	# ============================================

	var converted_result := _convert_result(result, output_type)

	# ============================================
	# 5. 保存结果
	# ============================================

	var save_success := _save_result(converted_result, context)
	if not save_success:
		finished.emit()
		return

	_log_info_localized("FUSE_LOG_MATH_EXPRESSION_RESULT", {
		"expr": expression,
		"result": str(converted_result)
	})

	_on_execution_completed()

# =============================================
# 变量替换
# =============================================

## 替换表达式中的变量引用
func _replace_variables(expr: String, context: ExecutionContext) -> Variant:
	return ExpressionHelper.replace_variables(
		expr, context,
		scope_source as VariableScopeUtils.ScopeSource,
		custom_scope_id,
		target_node_path,
		true
	)

## 将值转换为表达式安全的字符串
func _escape_value_for_expression(value: Variant) -> String:
	return ExpressionHelper.escape_value(value)

# =============================================
# 表达式执行
# =============================================

## 执行表达式
func _evaluate_expression(expr: String) -> Variant:
	if _expr_helper == null:
		_expr_helper = ExpressionHelper.GameExprHelper.new()

	var error_text := ""
	var result = ExpressionHelper.evaluate(expr, _expr_helper, error_text)

	if result == null:
		_log_error_localized("FUSE_ERROR_EXPRESSION_PARSE", {"error": error_text})
		set_error_localized("FUSE_ERROR_EXPRESSION_PARSE", FuseError.ErrorType.RUNTIME_ERROR, {"error": error_text})

	return result

# =============================================
# 类型转换
# =============================================

## 转换结果类型
func _convert_result(raw: Variant, type: OutputType) -> Variant:
	match type:
		OutputType.FLOAT:
			return float(raw)
		OutputType.INT:
			return int(raw)
		OutputType.VECTOR2:
			if raw is Vector3:
				return Vector2(raw.x, raw.y)
			elif raw is Vector2:
				return raw
			else:
				return Vector2(float(raw), 0)
		OutputType.VECTOR3:
			if raw is Vector2:
				return Vector3(raw.x, raw.y, 0)
			elif raw is Vector3:
				return raw
			else:
				return Vector3(float(raw), 0, 0)
		_:
			return raw

# =============================================
# 结果保存
# =============================================

## 保存结果到变量
func _save_result(value: Variant, context: ExecutionContext) -> bool:
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

## 保存到 SCOPE 变量
func _save_to_scope_variable(value: Variant, context: ExecutionContext) -> bool:
	if save_scope_source == ScopeSource.NEAREST:
		var success := VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.SCOPE, value)
		if not success:
			_log_error_localized("FUSE_ERROR_SET_SCOPE_VARIABLE_FAILED", {"name": save_to_variable})
			set_error_localized("FUSE_ERROR_SET_SCOPE_VARIABLE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"name": save_to_variable})
		return success
	else:
		var utils_scope_source := save_scope_source as VariableScopeUtils.ScopeSource
		var scope_container := VariableScopeUtils.get_scope_container_by_source(
			context,
			utils_scope_source,
			save_custom_scope_id,
			save_target_node_path
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

## 验证指令参数
func validate() -> Array[String]:
	var errors := super.validate()

	if expression.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_EXPRESSION_EMPTY"))

	if save_to_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))

	# 验证表达式语法
	var syntax_errors := _validate_expression_syntax()
	errors.append_array(syntax_errors)

	# 验证 SCOPE 作用域相关参数
	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		var utils_scope_source := save_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source,
			save_custom_scope_id,
			save_target_node_path
		))

	return errors

## 验证表达式语法
func _validate_expression_syntax() -> Array[String]:
	return ExpressionHelper.validate_syntax(expression)
