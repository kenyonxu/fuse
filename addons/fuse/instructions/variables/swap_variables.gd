@tool
@icon("res://addons/fuse/icons/builtin/Swap.svg")
extends BaseInstruction
class_name SwapVariables

## Swap Variables 指令 - 交换两个变量的值
##
## 支持三层变量作用域（Local/Scope/Global）。
## 涉及 variable_scope 的组件必须遵循 Scope 动态属性开发模式。

## 变量 A
var variable_a: String = "":
	set(value):
		variable_a = value
		_update_resource_name()

## 变量 B
var variable_b: String = "":
	set(value):
		variable_b = value
		_update_resource_name()

## 变量作用域
var variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		variable_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 作用域来源（仅当 variable_scope == SCOPE 时使用）
var scope_source: VariableScopeUtils.ScopeSource = VariableScopeUtils.ScopeSource.NEAREST:
	set(value):
		scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 自定义作用域 ID（scope_source == CUSTOM_ID 时使用）
var custom_scope_id: String = "":
	set(value):
		custom_scope_id = value
		_update_resource_name()

## 目标节点路径（scope_source == TARGET_NODE 时使用）
var target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_path = value
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SWAP_VARIABLES_NAME"
	metadata.category_key = "FUSE_CATEGORY_VARIABLES"
	metadata.description_key = "FUSE_INSTRUCTION_SWAP_VARIABLES_DESC"
	metadata.keywords = ["交换", "swap", "变量", "variable", "值", "value", "替换", "switch"]
	metadata.builtin_icon = "Swap"
	return metadata

func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	properties.append({
		name = "Variables",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "variable_a",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "variable_b",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "Scope",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "variable_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if variable_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.append_scope_source_properties(properties, scope_source)

	return properties

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.validate_scope_source_property(property, scope_source)

## 更新资源名称
func _update_resource_name():
	var a = variable_a if not variable_a.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	var b = variable_b if not variable_b.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	var scope_str = _get_scope_display_name()
	resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_SWAP_VARIABLES_RESOURCE_NAME", {
		"scope": scope_str,
		"a": a,
		"b": b
	})

func _get_scope_display_name() -> String:
	match variable_scope:
		BaseVariable.VariableScope.LOCAL: return FuseLocalization.translate("FUSE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.SCOPE: return FuseLocalization.translate("FUSE_SCOPE_SCOPE_STR")
		BaseVariable.VariableScope.GLOBAL: return FuseLocalization.translate("FUSE_SCOPE_GLOBAL_STR")
		_: return "?"

## 获取指令描述
func get_description() -> String:
	var a = variable_a if not variable_a.is_empty() else "?"
	var b = variable_b if not variable_b.is_empty() else "?"
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SWAP_VARIABLES_DESC_FORMAT", {
		"a": a,
		"b": b
	})

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	if variable_a.is_empty() or variable_b.is_empty():
		_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取变量 A 的值
	var value_a = _get_variable_value(context, variable_a)
	# 获取变量 B 的值
	var value_b = _get_variable_value(context, variable_b)

	# 交换：A ← B, B ← A
	_set_variable_value(context, variable_a, value_b)
	_set_variable_value(context, variable_b, value_a)

	_log_info_localized("FUSE_LOG_VARIABLES_SWAPPED", {
		"a": variable_a,
		"b": variable_b
	})

	_on_execution_completed()

## 从上下文获取变量值
func _get_variable_value(context: ExecutionContext, var_name: String) -> Variant:
	return VariableOperations.get_variable(context, var_name, variable_scope, null)

## 设置变量值到上下文
func _set_variable_value(context: ExecutionContext, var_name: String, value: Variant) -> void:
	VariableOperations.set_variable(context, var_name, value, variable_scope)

## 动态属性拦截
func _set(property: StringName, value: Variant) -> bool:
	if property in ["variable_a", "variable_b", "variable_scope", "scope_source", "custom_scope_id", "target_node_path"]:
		set(property, value)
		_update_resource_name()
		if property == "variable_scope" or property == "scope_source":
			notify_property_list_changed()
		return true
	return false

## 验证参数
func validate() -> Array[String]:
	var errors = super.validate()
	if variable_a.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_A_EMPTY"))
	if variable_b.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_B_EMPTY"))
	return errors
