@tool
@icon("res://addons/fuse/icons/builtin/Boolean.svg")
extends BaseInstruction
class_name ToggleVariable

## 切换布尔变量的值 (true ↔ false)，使用 VariableOperations 统一 API

# =============================================
# 属性定义
# =============================================

## 变量名
var variable_name: String = "":
	set(value):
		variable_name = value
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

# =============================================
# 元数据（必需）
# =============================================
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_TOGGLE_VARIABLE_NAME"
	metadata.category_key = "FUSE_CATEGORY_VARIABLES"
	metadata.description_key = "FUSE_INSTRUCTION_TOGGLE_VARIABLE_DESC"
	metadata.keywords = ["切换", "toggle", "布尔", "boolean", "变量", "variable", "开关", "true", "false", "翻转"]
	metadata.builtin_icon = "Boolean"
	return metadata

func _setup_metadata():
	pass

# =============================================
# 动态属性列表
# =============================================
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Variable 分类
	properties.append({
		name = "Variable",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "variable_name",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
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

# =============================================
# 资源名称
# =============================================
func _update_resource_name():
	var name_str = variable_name if not variable_name.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	var scope_str = _get_scope_display_name()
	resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_TOGGLE_VARIABLE_RESOURCE_NAME", {
		"scope": scope_str,
		"name": name_str
	})

func _get_scope_display_name() -> String:
	match variable_scope:
		BaseVariable.VariableScope.LOCAL: return FuseLocalization.translate("FUSE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.SCOPE: return FuseLocalization.translate("FUSE_SCOPE_SCOPE_STR")
		BaseVariable.VariableScope.GLOBAL: return FuseLocalization.translate("FUSE_SCOPE_GLOBAL_STR")
		_: return "?"

# =============================================
# 执行
# =============================================
func execute(context: ExecutionContext):
	_start_execution(context)

	if variable_name.is_empty():
		set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 使用 VariableOperations 获取当前值
	var current = VariableOperations.get_variable(context, variable_name, variable_scope, null)
	if current == null:
		set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"variable": variable_name})
		finished.emit()
		return

	# 切换布尔值
	var new_value: bool
	if current is bool:
		new_value = not current
	else:
		# 尝试类型转换为布尔值
		new_value = not (current != null and current != false and current != 0 and current != 0.0 and current != "")

	# 使用 VariableOperations 设置新值
	VariableOperations.set_variable(context, variable_name, variable_scope, new_value)

	_log_info_localized("FUSE_LOG_VARIABLE_TOGGLED", {
		"name": variable_name,
		"value": str(new_value)
	})
	_on_execution_completed()

# =============================================
# 描述
# =============================================
func get_description() -> String:
	var name_str = variable_name if not variable_name.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	var scope_str = _get_scope_display_name()
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_TOGGLE_VARIABLE_DESCRIPTION", {
		"scope": scope_str,
		"name": name_str
	})

# =============================================
# 验证
# =============================================
func validate() -> Array[String]:
	var errors = super.validate()
	if variable_name.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))
	return errors

# =============================================
# 动态属性拦截
# =============================================
func _set(property: StringName, value: Variant) -> bool:
	if property in ["variable_name", "variable_scope", "scope_source", "custom_scope_id", "target_node_path"]:
		set(property, value)
		_update_resource_name()
		if property == "variable_scope" or property == "scope_source":
			notify_property_list_changed()
		return true
	return false
