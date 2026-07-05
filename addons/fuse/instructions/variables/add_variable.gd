@tool
@icon("res://addons/fuse/icons/builtin/Add.svg")
extends BaseInstruction
class_name AddVariable

## 对数值变量执行加法运算，使用 VariableOperations 统一 API

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

## 加数值
var add_value: float = 1.0:
	set(value):
		add_value = value
		_update_resource_name()

## 是否从另一个变量读取加数
var use_variable: bool = false:
	set(value):
		use_variable = value
		_update_resource_name()
		notify_property_list_changed()

## 加数变量名
var add_variable: String = "":
	set(value):
		add_variable = value
		_update_resource_name()

# =============================================
# 元数据（必需）
# =============================================
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_ADD_VARIABLE_NAME"
	metadata.category_key = "FUSE_CATEGORY_VARIABLES"
	metadata.description_key = "FUSE_INSTRUCTION_ADD_VARIABLE_DESC"
	metadata.keywords = ["增加", "add", "加法", "变量", "variable", "数值", "数学", "math", "increment", "递增"]
	metadata.builtin_icon = "Add"
	return metadata

func _setup_metadata():
	pass

# =============================================
# 动态属性列表
# =============================================
func _get_property_list() -> Array[Dictionary]:
	var properties := []

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

	# Value 分类
	properties.append({
		name = "Value",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "use_variable",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if use_variable:
		properties.append({
			name = "add_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "add_value",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	return properties

# =============================================
# 条件属性可见性
# =============================================
func _validate_property(property: Dictionary) -> void:

	if variable_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.validate_scope_source_property(property, scope_source)
		return
	if use_variable:
		if property.name == "add_value":
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "add_variable":
			property.usage = PROPERTY_USAGE_NO_EDITOR

# =============================================
# 资源名称
# =============================================
func _update_resource_name():
	var name_str = variable_name if not variable_name.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	var scope_str = _get_scope_display_name()
	var amount_str = add_variable if use_variable and not add_variable.is_empty() else str(add_value)
	resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_ADD_VARIABLE_RESOURCE_NAME", {
		"scope": scope_str,
		"name": name_str,
		"amount": amount_str
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

	# 获取当前变量值
	var current = VariableOperations.get_variable(context, variable_name, variable_scope, null)
	if current == null:
		# 如果不存在，初始化为 0
		current = 0

	# 获取增量值
	var increment: Variant = add_value
	if use_variable and not add_variable.is_empty():
		increment = VariableOperations.get_variable(context, add_variable, BaseVariable.VariableScope.LOCAL, 0)

	# 执行加法运算
	var new_value: Variant
	if current is int and increment is int:
		new_value = current + increment
	elif current is float or increment is float:
		new_value = float(current) + float(increment)
	elif current is Vector2:
		if increment is Vector2:
			new_value = current + increment
		else:
			new_value = current + Vector2(float(increment), float(increment))
	elif current is Vector3:
		if increment is Vector3:
			new_value = current + increment
		else:
			new_value = current + Vector3(float(increment), float(increment), float(increment))
	else:
		new_value = float(current) + float(increment)

	# 使用 VariableOperations 设置新值
	VariableOperations.set_variable(context, variable_name, new_value, variable_scope)

	_log_info_localized("FUSE_LOG_VARIABLE_ADDED", {
		"name": variable_name,
		"amount": str(increment),
		"result": str(new_value)
	})
	_on_execution_completed()

# =============================================
# 描述
# =============================================
func get_description() -> String:
	var name_str = variable_name if not variable_name.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	var scope_str = _get_scope_display_name()
	var amount_str = add_variable if use_variable and not add_variable.is_empty() else str(add_value)
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_ADD_VARIABLE_DESCRIPTION", {
		"scope": scope_str,
		"name": name_str,
		"amount": amount_str,
		"result": "?"
	})

# =============================================
# 验证
# =============================================
func validate() -> Array[String]:
	var errors = super.validate()
	if variable_name.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))
	if use_variable and add_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))
	return errors

# =============================================
# 动态属性拦截
# =============================================
func _set(property: StringName, value: Variant) -> bool:
	if property in ["variable_name", "variable_scope", "add_value", "use_variable", "add_variable", "scope_source", "custom_scope_id", "target_node_path"]:
		set(property, value)
		_update_resource_name()
		if property in ["variable_scope", "use_variable", "scope_source"]:
			notify_property_list_changed()
		return true
	return false
