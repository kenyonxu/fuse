@tool
@icon("res://addons/fuse/icons/builtin/ProgressBar.png")
extends BaseInstruction
class_name SetUIProgress


## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 设置 ProgressBar 的进度值
##
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问

# 目标 UI 节点路径
var target_node: NodePath = NodePath("")

## 是否从变量获取UI 节点
var use_variable_for_target: bool = false:
	set(value):
		use_variable_for_target = value
		_update_resource_name()
		notify_property_list_changed()

## UI 节点变量名
var target_variable: String = "":
	set(value):
		target_variable = value
		_update_resource_name()

## UI 节点变量作用域
var target_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		target_scope = value
		_update_resource_name()
		notify_property_list_changed()

## UI 节点作用域来源（仅当 target_scope == SCOPE 时使用）
var target_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		target_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## UI 节点自定义作用域 ID（CUSTOM_ID 模式使用）
var target_custom_scope_id: String = "":
	set(value):
		target_custom_scope_id = value
		_update_resource_name()

## UI 节点目标节点路径（TARGET_NODE 模式使用）
var target_target_node_path: NodePath = NodePath(""):
	set(value):
		target_target_node_path = value
		_update_resource_name()

# 是否使用变量控制进度值
var use_variable: bool = false

# 直接进度值（0.0 - 1.0）
var value: float = 1.0

# 进度值变量名
var value_variable: String = ""

# 进度值变量作用域
var value_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
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
	var modes: Array[Dictionary] = [{"name": "value_variable", "mode": "read"}]
	if use_variable_for_target:
		modes.append({"name": "target_variable", "mode": "read"})
	return modes

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		name = "UI",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})


	# 是否从变量获取UI 节点
	properties.append({
		name = "use_variable_for_target",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if not use_variable_for_target:
		# 直接指定节点路径
		properties.append({
			name = "target_node",
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			hint_string = "Control",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		# 从变量获取节点
		properties.append({
			name = "target_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "target_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if target_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "target_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			if target_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "target_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif target_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "target_target_node_path",
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

	var target_str := ""
	if use_variable_for_target:
		if target_variable.is_empty():
			target_str = FuseLocalization.translate("FUSE_UI_NODE_NOT_SELECTED")
		else:
			var target_scope_str := VariableScopeUtils.enum_to_string(target_scope).to_upper()
			if target_scope == BaseVariable.VariableScope.SCOPE:
				var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
				target_scope_str = VariableScopeUtils.get_scope_source_string(target_utils_scope_source, target_custom_scope_id, target_target_node_path)
			target_str = "%s [%s]" % [target_variable, target_scope_str]
	else:
		target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_UI_NODE_NOT_SELECTED")
	parts.append("→ %s" % target_str)

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
	var node := _resolve_node(
		context,
		use_variable_for_target,
		target_node,
		target_variable,
		target_scope,
		target_scope_source,
		target_custom_scope_id,
		target_target_node_path,
		"FUSE_ERROR_TARGET_VARIABLE_EMPTY",
		"FUSE_ERROR_TARGET_NODE_EMPTY",
		"FUSE_ERROR_TARGET_NODE_NOT_FOUND"
	)
	if not node:
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

	# 设置进度值——value 是 0.0~1.0 归一化比例，须经 Range.ratio 换算到目标区间
	# （直接写 value 会让 0-100 的条把 0.8 显示为 0.8%）
	progress_bar.ratio = progress_value
	_log_info_localized("FUSE_LOG_SET_UI_PROGRESS", {"node": progress_bar.name, "value": "%.0f%%" % (progress_value * 100)})
	_on_execution_completed()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()
	# 验证 UI 节点
	if use_variable_for_target:
		if target_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_VARIABLE_EMPTY"))
		if target_scope == BaseVariable.VariableScope.SCOPE:
			var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				target_utils_scope_source,
				target_custom_scope_id,
				target_target_node_path
			))
	else:
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

## 属性验证
func _validate_property(property: Dictionary) -> void:
	# 控制UI 节点相关属性可见性
	if not use_variable_for_target:
		if property.name in ["target_variable", "target_scope", "target_scope_source", "target_custom_scope_id", "target_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "target_node":
			property.usage = PROPERTY_USAGE_NO_EDITOR

		if target_scope != BaseVariable.VariableScope.SCOPE:
			if property.name in ["target_scope_source", "target_custom_scope_id", "target_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
			VariableScopeUtils.validate_scope_source_property(property, target_utils_scope_source)
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
	var node_str := ""
	if use_variable_for_target:
		if target_variable.is_empty():
			node_str = "(%s)" % FuseLocalization.translate("FUSE_UI_NODE_NOT_SELECTED")
		else:
			var target_scope_str := VariableScopeUtils.enum_to_string(target_scope).to_upper()
			if target_scope == BaseVariable.VariableScope.SCOPE:
				var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
				target_scope_str = VariableScopeUtils.get_scope_source_string(target_utils_scope_source, target_custom_scope_id, target_target_node_path)
			node_str = "%s [%s]" % [target_variable, target_scope_str]
	else:
		node_str = _get_node_display_name(target_node) if not target_node.is_empty() else "(%s)" % FuseLocalization.translate("FUSE_UI_NODE_NOT_SELECTED")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_UI_PROGRESS_DESC_FORMAT", {"node": node_str, "value": source_str})

## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property in ["use_variable_for_target", "target_scope", "target_scope_source"]:
		set(property, value)
		notify_property_list_changed()
		return true
	if property == "use_variable":
		set(property, value)
		notify_property_list_changed()
		_update_resource_name()
		return true
	return false

## 从变量或节点路径解析节点
func _resolve_node(
	context: ExecutionContext,
	use_variable: bool,
	node_path: NodePath,
	variable_name: String,
	variable_scope: BaseVariable.VariableScope,
	scope_source: ScopeSource,
	custom_scope_id: String,
	target_node_path: NodePath,
	empty_variable_error_key: String,
	empty_node_error_key: String,
	not_found_error_key: String
) -> Node:
	if use_variable:
		if variable_name.is_empty():
			_log_error_localized(empty_variable_error_key, {})
			set_error_localized(empty_variable_error_key, FuseError.ErrorType.VALIDATION_ERROR, {})
			return null

		var node_value = VariableOperations.get_variable(
			context,
			variable_name,
			variable_scope,
			null
		)

		if node_value == null and not VariableOperations.has_variable(context, variable_name, variable_scope):
			_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"name": variable_name})
			set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"name": variable_name})
			return null

		# 支持多种类型：Node、String（节点路径）、NodePath
		if node_value is Node:
			return node_value
		elif node_value is String or node_value is NodePath:
			var resolved_path = NodePath(node_value)
			var resolved_node = context.get_node(resolved_path)
			if not resolved_node:
				_log_error_localized(not_found_error_key, {"node": str(node_value)})
				set_error_localized(not_found_error_key, FuseError.ErrorType.RUNTIME_ERROR, {"node": str(node_value)})
				return null
			return resolved_node
		else:
			_log_error_localized("FUSE_ERROR_VAR_TYPE_NOT_NODE_OR_PATH", {"variable": variable_name, "actual_type": type_string(typeof(node_value))})
			set_error_localized("FUSE_ERROR_VAR_TYPE_NOT_NODE_OR_PATH", FuseError.ErrorType.VALIDATION_ERROR, {"variable": variable_name, "actual_type": type_string(typeof(node_value))})
			return null
	else:
		if node_path.is_empty():
			_log_error_localized(empty_node_error_key, {})
			set_error_localized(empty_node_error_key, FuseError.ErrorType.VALIDATION_ERROR, {})
			return null

		var resolved_node = context.get_node(node_path)
		if not resolved_node:
			_log_error_localized(not_found_error_key, {"node": str(node_path)})
			set_error_localized(not_found_error_key, FuseError.ErrorType.RUNTIME_ERROR, {"node": str(node_path)})
			return null
		return resolved_node

