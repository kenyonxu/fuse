@tool
@icon("res://addons/fuse/icons/builtin/KeyScale.png")
extends BaseInstruction
class_name SetScale

## 设置节点的缩放（支持 2D/3D）
##
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问

# 目标节点路径
var target_node: NodePath = NodePath("")

# 目标缩放
var scale: Vector3 = Vector3.ONE

# 是否使用变量
var use_variable: bool = false

# 缩放变量名
var scale_variable: String = ""

# 缩放变量作用域
@export var scale_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_SCALE_NAME"
	metadata.category_key = "FUSE_CATEGORY_TRANSFORM"
	metadata.description_key = "FUSE_INSTRUCTION_SET_SCALE_DESC"
	metadata.keywords = ["scale", "transform", "size", "缩放", "变换", "大小"]
	metadata.builtin_icon = "KeyScale"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 声明变量读写模式（scale=read）
func get_variable_modes() -> Array[Dictionary]:
	return [{"name": "scale_variable", "mode": "read"}]

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Transform 分类
	properties.append({
		name = "Transform",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 目标节点
	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "Node2D,Node3D",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 变量选项分类
	properties.append({
		name = "Variable",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 是否使用变量
	properties.append({
		name = "use_variable",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 缩放值（当不使用变量时显示）
	properties.append({
		name = "scale",
		type = TYPE_VECTOR3,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 缩放变量名（当使用变量时显示）
	properties.append({
		name = "scale_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 缩放变量作用域（当使用变量时显示）
	properties.append({
		name = "scale_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_SCALE_BASE"))

	if not target_node.is_empty():
		parts.append("'%s'" % target_node)
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_SCALE_NO_NODE"))

	if use_variable:
		if scale_variable.is_empty():
			parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_SCALE_NO_VARIABLE"))
		else:
			var scope_str = VariableScopeUtils.enum_to_string(scale_scope).to_upper()
			parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_SCALE_FROM_VARIABLE", {"name": "%s [%s]" % [scale_variable, scope_str]}))
	else:
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_SCALE_VALUE", {"x": scale.x, "y": scale.y, "z": scale.z}))

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证目标节点
	if target_node.is_empty():
		_log_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", {})
		set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取目标节点
	var node := context.get_node(target_node)
	if not node:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	# 获取目标缩放
	var target_scale: Vector3

	if use_variable:
		if scale_variable.is_empty():
			_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
			set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

		var var_value = VariableOperations.get_variable(context, scale_variable, scale_scope, null)
		if var_value == null and not VariableOperations.has_variable(context, scale_variable, scale_scope):
			_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": scale_variable})
			set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"variable": scale_variable})
			finished.emit()
			return

		# 支持更多向量类型（包括整数向量和浮点数）
		if var_value is Vector2 or var_value is Vector2i or var_value is Vector3 or var_value is Vector3i:
			target_scale = var_value
		elif var_value is float or var_value is int:
			# 如果是单个数值，则统一缩放
			var scalar = float(var_value)
			target_scale = Vector3(scalar, scalar, scalar)
		else:
			var type_str = type_string(typeof(var_value))
			_log_error_localized("FUSE_ERROR_VAR_TYPE_INVALID", {"variable": scale_variable, "actual_type": type_str})
			set_error_localized("FUSE_ERROR_VAR_TYPE_INVALID", FuseError.ErrorType.VALIDATION_ERROR, {"variable": scale_variable, "actual_type": type_str})
			finished.emit()
			return
	else:
		target_scale = scale
		# 验证缩放值有效性
		if not _is_valid_scale(target_scale):
			_log_error_localized("FUSE_ERROR_INVALID_SCALE", {})
			set_error_localized("FUSE_ERROR_INVALID_SCALE", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

	# 应用缩放变换（自动检测 2D/3D）
	if node is Node2D:
		var scale_2d = Vector2(target_scale.x, target_scale.y)
		node.scale = scale_2d

		_log_info_localized("FUSE_LOG_NODE2D_SET_SCALE", {"node": node.name, "x": scale_2d.x, "y": scale_2d.y})

	elif node is Node3D:
		node.scale = target_scale

		_log_info_localized("FUSE_LOG_NODE3D_SET_SCALE", {"node": node.name, "x": target_scale.x, "y": target_scale.y, "z": target_scale.z})

	else:
		var type_str = node.get_class()
		_log_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", {"node": node.name, "actual_type": type_str})
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {"node": node.name, "actual_type": type_str})
		finished.emit()
		return

	_on_execution_completed()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	if use_variable and scale_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_SCALE_VARIABLE_EMPTY"))

	# 验证 SCOPE 作用域需要 ScopeVariableManager
	if use_variable and scale_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

	return errors

## 验证缩放值是否有效（检查 NaN 和 Infinity）
func _is_valid_scale(s: Vector3) -> bool:
	# 检查每个分量是否为有效数字
	return not (is_nan(s.x) or is_inf(s.x) or
				is_nan(s.y) or is_inf(s.y) or
				is_nan(s.z) or is_inf(s.z))

## 动态属性设置（支持属性刷新）
func _set(property: StringName, value: Variant) -> bool:
	if property == "use_variable":
		use_variable = value
		notify_property_list_changed()
		return true
	return false

## 属性验证
func _validate_property(property: Dictionary) -> void:
	if property.name == "scale" and use_variable:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	if property.name == "scale_variable" and not use_variable:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	if property.name == "scale_scope" and not use_variable:
		property.usage = PROPERTY_USAGE_NO_EDITOR

## 获取指令描述
func get_description() -> String:
	var source_desc = ""

	if use_variable:
		if scale_variable.is_empty():
			source_desc = FuseLocalization.translate("FUSE_INSTRUCTION_SET_SCALE_DESC_NO_VARIABLE")
		else:
			var scope_str = VariableScopeUtils.enum_to_string(scale_scope).to_upper()
			source_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_SCALE_DESC_VARIABLE", {"name": "%s [%s]" % [scale_variable, scope_str]})
	else:
		source_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_SCALE_DESC_VALUE", {"x": scale.x, "y": scale.y, "z": scale.z})

	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_SCALE_DESC_FORMAT", {"node": _get_node_display_name(target_node), "source": source_desc})