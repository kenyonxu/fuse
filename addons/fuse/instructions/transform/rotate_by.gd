@tool
@icon("res://addons/fuse/icons/builtin/RotateRight.png")
extends BaseInstruction
class_name RotateBy


## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 相对旋转节点
##
## 相对于当前旋转旋转节点（支持 2D/3D）。
##
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问

# 目标节点路径
var target_node: NodePath = NodePath("")

## 是否从变量获取目标节点
var use_variable_for_target: bool = false:
	set(value):
		use_variable_for_target = value
		_update_resource_name()
		notify_property_list_changed()

## 目标节点变量名
var target_variable: String = "":
	set(value):
		target_variable = value
		_update_resource_name()

## 目标节点变量作用域
var target_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		target_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 目标节点作用域来源（仅当 target_scope == SCOPE 时使用）
var target_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		target_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 目标节点自定义作用域 ID（CUSTOM_ID 模式使用）
var target_custom_scope_id: String = "":
	set(value):
		target_custom_scope_id = value
		_update_resource_name()

## 目标节点目标节点路径（TARGET_NODE 模式使用）
var target_target_node_path: NodePath = NodePath(""):
	set(value):
		target_target_node_path = value
		_update_resource_name()

# 旋转偏移量（度数）
var rotation_offset: Vector3 = Vector3.ZERO

# 坐标空间（Global/Local）
enum CoordinateSpace {
	GLOBAL,
	LOCAL
}
var space: CoordinateSpace = CoordinateSpace.LOCAL

# 旋转变量名
var rotation_variable: String = "amount"

# 旋转变量作用域
var rotation_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.SCOPE

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_ROTATE_BY_NAME"
	metadata.category_key = "FUSE_CATEGORY_TRANSFORM"
	metadata.description_key = "FUSE_INSTRUCTION_ROTATE_BY_DESC"
	metadata.keywords = ["rotate", "offset", "angle", "relative", "旋转", "角度"]
	metadata.builtin_icon = "RotateRight"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 声明变量读写模式（rotation=read）
func get_variable_modes() -> Array[Dictionary]:
	var modes: Array[Dictionary] = [{"name": "rotation_variable", "mode": "read"}]
	if use_variable_for_target:
		modes.append({"name": "target_variable", "mode": "read"})
	return modes

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

	# 是否从变量获取目标节点
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
			hint_string = "Node2D,Node3D",
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

	# 坐标空间
	properties.append({
		name = "space",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Global,Local",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Variable 分类
	properties.append({
		name = "Variable",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 旋转变量名
	properties.append({
		name = "rotation_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 旋转变量作用域
	properties.append({
		name = "rotation_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_ROTATE_BY_BASE"))

	var target_str := ""
	if use_variable_for_target:
		if target_variable.is_empty():
			target_str = FuseLocalization.translate("FUSE_INSTRUCTION_ROTATE_BY_NO_NODE")
		else:
			var target_scope_str := VariableScopeUtils.enum_to_string(target_scope).to_upper()
			if target_scope == BaseVariable.VariableScope.SCOPE:
				var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
				target_scope_str = VariableScopeUtils.get_scope_source_string(target_utils_scope_source, target_custom_scope_id, target_target_node_path)
			target_str = "%s [%s]" % [target_variable, target_scope_str]
	else:
		target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_ROTATE_BY_NO_NODE")
	parts.append("'%s'" % target_str)

	parts.append("[%s]" % _get_space_string())

	var scope_str = VariableScopeUtils.enum_to_string(rotation_scope).to_upper()
	parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_ROTATE_BY_FROM_VARIABLE", {"name": "%s [%s]" % [rotation_variable, scope_str]}))

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证目标节点

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

	# 获取目标旋转偏移
	var target_rot_offset: Vector3

	# 始终从变量获取值
	if rotation_variable.is_empty():
		_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	var var_value = VariableOperations.get_variable(context, rotation_variable, rotation_scope, null)
	if var_value == null and not VariableOperations.has_variable(context, rotation_variable, rotation_scope):
		_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"name": rotation_variable})
		set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"name": rotation_variable})
		finished.emit()
		return

	# 支持更多向量类型
	if var_value is Vector2 or var_value is Vector2i or var_value is Vector3 or var_value is Vector3i:
		target_rot_offset = var_value
	else:
		var type_str = type_string(typeof(var_value))
		_log_error_localized("FUSE_ERROR_VAR_TYPE_INVALID", {"variable": rotation_variable, "actual_type": type_str})
		set_error_localized("FUSE_ERROR_VAR_TYPE_INVALID", FuseError.ErrorType.VALIDATION_ERROR, {"variable": rotation_variable, "actual_type": type_str})
		finished.emit()
		return

	# 验证旋转偏移值有效性
	if not _is_valid_rotation_offset(target_rot_offset):
		_log_error_localized("FUSE_ERROR_INVALID_ROTATION_OFFSET", {})
		set_error_localized("FUSE_ERROR_INVALID_ROTATION_OFFSET", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 应用旋转变换（自动检测 2D/3D）
	if node is Node2D:
		# Node2D 只使用 Z 轴旋转
		var rot_offset_2d = target_rot_offset.z
		var current_rot: float

		if space == CoordinateSpace.GLOBAL:
			current_rot = node.global_rotation_degrees
			node.global_rotation_degrees = current_rot + rot_offset_2d
			_log_info_localized("FUSE_LOG_NODE2D_ROTATE_GLOBAL", {
				"node": node.name, "offset": rot_offset_2d,
				"from": current_rot, "to": node.global_rotation_degrees
			})
		else:
			current_rot = node.rotation_degrees
			node.rotation_degrees = current_rot + rot_offset_2d
			_log_info_localized("FUSE_LOG_NODE2D_ROTATE_LOCAL", {
				"node": node.name, "offset": rot_offset_2d,
				"from": current_rot, "to": node.rotation_degrees
			})

	elif node is Node3D:
		var current_rot: Vector3

		if space == CoordinateSpace.GLOBAL:
			current_rot = node.global_rotation_degrees
			node.global_rotation_degrees = current_rot + target_rot_offset
			_log_info_localized("FUSE_LOG_NODE3D_ROTATE_GLOBAL", {
				"node": node.name,
				"ox": target_rot_offset.x, "oy": target_rot_offset.y, "oz": target_rot_offset.z,
				"fx": current_rot.x, "fy": current_rot.y, "fz": current_rot.z,
				"tx": node.global_rotation_degrees.x, "ty": node.global_rotation_degrees.y, "tz": node.global_rotation_degrees.z
			})
		else:
			current_rot = node.rotation_degrees
			node.rotation_degrees = current_rot + target_rot_offset
			_log_info_localized("FUSE_LOG_NODE3D_ROTATE_LOCAL", {
				"node": node.name,
				"ox": target_rot_offset.x, "oy": target_rot_offset.y, "oz": target_rot_offset.z,
				"fx": current_rot.x, "fy": current_rot.y, "fz": current_rot.z,
				"tx": node.rotation_degrees.x, "ty": node.rotation_degrees.y, "tz": node.rotation_degrees.z
			})

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
	# 验证 目标节点
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


	if rotation_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_ROTATION_VARIABLE_EMPTY"))

	# 验证 SCOPE 作用域需要 ScopeVariableManager
	if rotation_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

	return errors

## 验证旋转偏移值是否有效（检查 NaN 和 Infinity）
func _is_valid_rotation_offset(rot: Vector3) -> bool:
	return not (is_nan(rot.x) or is_inf(rot.x) or
				is_nan(rot.y) or is_inf(rot.y) or
				is_nan(rot.z) or is_inf(rot.z))

## 获取坐标空间的本地化字符串
func _get_space_string() -> String:
	return "全局" if space == CoordinateSpace.GLOBAL else "局部"

## 动态属性设置（支持属性刷新）
func _set(property: StringName, value: Variant) -> bool:
	if property in ["use_variable_for_target", "target_scope", "target_scope_source"]:
		set(property, value)
		notify_property_list_changed()
		return true
	return false

## 属性验证
func _validate_property(property: Dictionary) -> void:
	# 隐藏 rotation_offset 属性，因为我们始终使用变量
	if property.name == "rotation_offset":
		property.usage = PROPERTY_USAGE_NO_EDITOR
	# 控制目标节点相关属性可见性
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
	var space_str = _get_space_string()
	var scope_str = VariableScopeUtils.enum_to_string(rotation_scope).to_upper()
	var offset_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_ROTATE_BY_DESC_VARIABLE", {"name": "%s [%s]" % [rotation_variable, scope_str]})

	var node_str := ""
	if use_variable_for_target:
		if target_variable.is_empty():
			node_str = FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
		else:
			var target_scope_str := VariableScopeUtils.enum_to_string(target_scope).to_upper()
			if target_scope == BaseVariable.VariableScope.SCOPE:
				var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
				target_scope_str = VariableScopeUtils.get_scope_source_string(target_utils_scope_source, target_custom_scope_id, target_target_node_path)
			node_str = "%s [%s]" % [target_variable, target_scope_str]
	else:
		node_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_ROTATE_BY_DESC_FORMAT", {"node": node_str, "offset": offset_desc, "space": space_str})

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

