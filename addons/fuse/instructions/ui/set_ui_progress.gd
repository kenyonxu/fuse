@tool
@icon("res://addons/fuse/icons/builtin/ProgressBar.png")
extends BaseInstruction
class_name SetUIProgress

## 设置 ProgressBar 的进度值
##
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问

# 目标 UI 节点路径
var target_node: NodePath = NodePath("")

# 是否使用变量控制进度值
var use_variable: bool = false

# 直接进度值（0.0 - 1.0）
var value: float = 1.0

# 进度值变量名
var value_variable: String = ""

# 进度值变量作用域
@export var value_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		value_scope = value
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_UI_PROGRESS_NAME"
	metadata.category_key = "FUSE_CATEGORY_UI"
	metadata.description_key = "FUSE_INSTRUCTION_SET_UI_PROGRESS_DESC"
	metadata.keywords = ["ui", "progress", "bar", "value", "UI", "进度", "进度条", "值"]
	metadata.builtin_icon = "ProgressBar"
	return metadata

func _setup_metadata():
	pass

## 声明变量读写模式（value=read）
func get_variable_modes() -> Array[Dictionary]:
	return [{"name": "value_variable", "mode": "read"}]

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	properties.append({
		name = "UI",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "Value",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "use_variable",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 直接进度值
	if not use_variable:
		properties.append({
			name = "value",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0,1,0.01",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# 进度值变量
	if use_variable:
		properties.append({
			name = "value_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 进度值变量作用域
		properties.append({
			name = "value_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts := []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_UI_PROGRESS_RESOURCE"))

	if not target_node.is_empty():
		parts.append("→ %s" % _get_node_display_name(target_node))
	else:
		parts.append("→ %s" % FuseLocalization.translate("FUSE_UI_NODE_NOT_SELECTED"))

	var source_str = ""
	if use_variable:
		if not value_variable.is_empty():
			var scope_str = VariableScopeUtils.enum_to_string(value_scope).to_upper()
			source_str = "%s [%s]" % [value_variable, scope_str]
		else:
			source_str = FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY")
	else:
		source_str = "%.0f%%" % (value * 100)
	parts.append("(%s)" % source_str)

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 获取目标节点
	var node := context.get_node(target_node)
	if not node:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	# 验证节点类型
	if not node is ProgressBar:
		_log_error_localized("FUSE_ERROR_UI_NODE_NOT_PROGRESSBAR", {})
		set_error_localized("FUSE_ERROR_UI_NODE_NOT_PROGRESSBAR", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	var progress_bar := node as ProgressBar

	# 获取进度值
	var progress_value: float
	if use_variable:
		if value_variable.is_empty():
			_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
			set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

		var var_value = VariableOperations.get_variable(context, value_variable, value_scope, null)
		if var_value == null and not VariableOperations.has_variable(context, value_variable, value_scope):
			_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"name": value_variable})
			set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"name": value_variable})
			finished.emit()
			return

		# 类型转换
		if var_value is float or var_value is int:
			progress_value = float(var_value)
		else:
			_log_error_localized("FUSE_ERROR_VAR_TYPE_MISMATCH", {
				"variable": value_variable,
				"expected": "float",
				"actual": typeof(var_value)
			})
			set_error_localized("FUSE_ERROR_VAR_TYPE_MISMATCH", FuseError.ErrorType.RUNTIME_ERROR, {
				"variable": value_variable,
				"expected": "float",
				"actual": typeof(var_value)
			})
			finished.emit()
			return
	else:
		progress_value = value

	# 验证进度值
	if progress_value < 0.0 or progress_value > 1.0:
		_log_error_localized("FUSE_ERROR_INVALID_PROGRESS_VALUE", {})
		set_error_localized("FUSE_ERROR_INVALID_PROGRESS_VALUE", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 设置进度值
	progress_bar.value = progress_value
	_log_info_localized("FUSE_LOG_SET_UI_PROGRESS", {"node": progress_bar.name, "value": "%.0f%%" % (progress_value * 100)})
	_on_execution_completed()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	if not use_variable:
		if value < 0.0 or value > 1.0:
			errors.append(FuseLocalization.translate("FUSE_ERROR_PROGRESS_VALUE_RANGE"))
	else:
		if value_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_PROGRESS_VAR_NAME_EMPTY"))

	# 验证作用域 (SCOPE)
	if use_variable and not value_variable.is_empty():
		if not VariableScopeUtils.is_valid_scope_string(VariableScopeUtils.enum_to_string(value_scope)):
			errors.append(FuseLocalization.translate_format("FUSE_ERROR_INVALID_SCOPE", {"scope": value_scope}))

		# 验证 SCOPE 作用域需要 ScopeVariableManager
		if value_scope == BaseVariable.VariableScope.SCOPE:
			var manager = ScopeVariableManager.get_instance()
			if manager == null:
				errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

	return errors

## 获取指令描述
func get_description() -> String:
	var source_str = ""
	if use_variable:
		if not value_variable.is_empty():
			var scope_str = VariableScopeUtils.enum_to_string(value_scope).to_upper()
			source_str = "%s [%s]" % [value_variable, scope_str]
		else:
			source_str = FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY")
	else:
		source_str = "%.0f%%" % (value * 100)
	var node_str = _get_node_display_name(target_node) if not target_node.is_empty() else "(%s)" % FuseLocalization.translate("FUSE_UI_NODE_NOT_SELECTED")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_UI_PROGRESS_DESC_FORMAT", {"node": node_str, "value": source_str})

## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property == "use_variable":
		set(property, value)
		notify_property_list_changed()
		_update_resource_name()
		return true
	return false