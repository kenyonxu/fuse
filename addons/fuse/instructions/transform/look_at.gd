@tool
@icon("res://addons/fuse/icons/builtin/EditorControlAnchor.png")
extends BaseInstruction
class_name LookAt

## 让节点朝向目标位置或节点
##
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问

# 目标节点路径（要旋转的节点）
var target_node: NodePath = NodePath("")

# 目标类型（位置/节点）
enum TargetType {
	POSITION,
	NODE
}
var target_type: TargetType = TargetType.POSITION

# 目标节点路径（当 target_type = NODE）
var look_at_node: NodePath = NodePath("")

# 位置变量名
var position_variable: String = ""

# 位置变量作用域
@export var position_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

# Up 向量（仅 3D）
var use_custom_up: bool = false
var up_vector: Vector3 = Vector3.UP

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_LOOK_AT_NAME"
	metadata.category_key = "FUSE_CATEGORY_TRANSFORM"
	metadata.description_key = "FUSE_INSTRUCTION_LOOK_AT_DESC"
	metadata.keywords = ["look at", "rotate", "face", "target", "朝向", "旋转", "面向"]
	metadata.builtin_icon = "EditorControlAnchor"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 声明变量读写模式（position=read）
func get_variable_modes() -> Array[Dictionary]:
	return [{"name": "position_variable", "mode": "read"}]

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

	# 目标类型
	properties.append({
		name = "target_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Position,Node",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Variable 分类
	properties.append({
		name = "Variable",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 位置变量名
	properties.append({
		name = "position_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 位置变量作用域
	properties.append({
		name = "position_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Target 分类
	properties.append({
		name = "Target",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 目标节点路径
	properties.append({
		name = "look_at_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "Node2D,Node3D",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Up 向量选项（仅 3D）
	properties.append({
		name = "3D Options",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "use_custom_up",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "up_vector",
		type = TYPE_VECTOR3,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_LOOK_AT_BASE"))

	if not target_node.is_empty():
		parts.append("'%s'" % target_node)
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_LOOK_AT_NO_NODE"))

	if target_type == TargetType.POSITION:
		if position_variable.is_empty():
			parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_LOOK_AT_NO_VARIABLE"))
		else:
			var scope_str = VariableScopeUtils.enum_to_string(position_scope).to_upper()
			parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_LOOK_AT_VARIABLE", {"name": "%s [%s]" % [position_variable, scope_str]}))
	else:
		if not look_at_node.is_empty():
			parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_LOOK_AT_TARGET_NODE", {"node": look_at_node}))
		else:
			parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_LOOK_AT_NO_TARGET_NODE"))

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

	# 获取要旋转的节点
	var node := context.get_node(target_node)
	if not node:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	# 获取目标位置
	var look_pos: Vector3

	if target_type == TargetType.POSITION:
		# 从变量获取目标位置
		if position_variable.is_empty():
			_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
			set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

		var var_value = VariableOperations.get_variable(context, position_variable, position_scope, null)
		if var_value == null and not VariableOperations.has_variable(context, position_variable, position_scope):
			_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": position_variable})
			set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"variable": position_variable})
			finished.emit()
			return

		if var_value is Vector2 or var_value is Vector2i or var_value is Vector3 or var_value is Vector3i:
			look_pos = var_value
		else:
			var type_str = type_string(typeof(var_value))
			_log_error_localized("FUSE_ERROR_VAR_TYPE_INVALID", {"variable": position_variable, "actual_type": type_str})
			set_error_localized("FUSE_ERROR_VAR_TYPE_INVALID", FuseError.ErrorType.VALIDATION_ERROR, {"variable": position_variable, "actual_type": type_str})
			finished.emit()
			return
	else:
		# 从目标节点获取位置
		if look_at_node.is_empty():
			_log_error_localized("FUSE_ERROR_LOOK_AT_NODE_EMPTY", {})
			set_error_localized("FUSE_ERROR_LOOK_AT_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

		var target := context.get_node(look_at_node)
		if not target:
			_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(look_at_node)})
			set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(look_at_node)})
			finished.emit()
			return

		if target is Node2D:
			look_pos = Vector3(target.global_position.x, target.global_position.y, 0)
		elif target is Node3D:
			look_pos = target.global_position
		else:
			# 节点没有位置，使用原点
			look_pos = Vector3.ZERO

	# 应用朝向变换（自动检测 2D/3D）
	if node is Node2D:
		var target_2d = Vector2(look_pos.x, look_pos.y)
		node.look_at(target_2d)

		_log_info_localized("FUSE_LOG_NODE2D_LOOK_AT", {"node": node.name, "x": target_2d.x, "y": target_2d.y})

	elif node is Node3D:
		if use_custom_up:
			node.look_at(look_pos, up_vector)
		else:
			node.look_at(look_pos)

		_log_info_localized("FUSE_LOG_NODE3D_LOOK_AT", {"node": node.name, "x": look_pos.x, "y": look_pos.y, "z": look_pos.z})

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

	if target_type == TargetType.POSITION and position_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_POSITION_VARIABLE_EMPTY"))

	if target_type == TargetType.NODE and look_at_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_LOOK_AT_NODE_EMPTY"))

	# 验证 SCOPE 作用域需要 ScopeVariableManager
	if target_type == TargetType.POSITION and position_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

	return errors

## 动态属性设置（支持属性刷新）
func _set(property: StringName, value: Variant) -> bool:
	if property == "target_type" or property == "use_custom_up":
		set(property, value)
		notify_property_list_changed()
		return true
	return false

## 属性验证
func _validate_property(property: Dictionary) -> void:
	# 目标类型相关
	if property.name == "look_at_node" and target_type != TargetType.NODE:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	# 变量相关
	if property.name == "position_variable" and target_type != TargetType.POSITION:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	# Up 向量相关
	if property.name == "up_vector" and not use_custom_up:
		property.usage = PROPERTY_USAGE_NO_EDITOR

## 获取指令描述
func get_description() -> String:
	var target_desc = ""

	if target_type == TargetType.POSITION:
		if position_variable.is_empty():
			target_desc = FuseLocalization.translate("FUSE_INSTRUCTION_LOOK_AT_NO_VARIABLE")
		else:
			var scope_str = VariableScopeUtils.enum_to_string(position_scope).to_upper()
			target_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_LOOK_AT_DESC_VARIABLE", {"name": "%s [%s]" % [position_variable, scope_str]})
	else:
		target_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_LOOK_AT_DESC_NODE", {"node": str(look_at_node)})

	var up_desc = ""
	if use_custom_up:
		up_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_LOOK_AT_UP_VECTOR", {"x": up_vector.x, "y": up_vector.y, "z": up_vector.z})

	return FuseLocalization.translate_format("FUSE_INSTRUCTION_LOOK_AT_DESC_FORMAT", {"node": _get_node_display_name(target_node), "target": target_desc, "up": up_desc})