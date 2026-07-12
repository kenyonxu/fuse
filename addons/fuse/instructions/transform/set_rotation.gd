@tool
@icon("res://addons/fuse/icons/builtin/KeyRotation.png")
extends BaseInstruction
class_name SetRotation

## 设置节点的旋转（支持 2D/3D）- 单作用域读取组件
##
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问
## ScopeSource 支持: 2026-02-10 - 始终从变量读取 rotation

# 目标节点路径
var target_node: NodePath = NodePath("")

# 坐标空间（Global/Local）
enum CoordinateSpace {
	GLOBAL,
	LOCAL
}
var space: CoordinateSpace = CoordinateSpace.GLOBAL

# 旋转变量名
var rotation_variable: String = "rotation"

# 旋转变量作用域
@export var rotation_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.SCOPE

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_ROTATION_NAME"
	metadata.category_key = "FUSE_CATEGORY_TRANSFORM"
	metadata.description_key = "FUSE_INSTRUCTION_SET_ROTATION_DESC"
	metadata.keywords = ["rotation", "transform", "rotate", "angle", "旋转", "变换", "角度"]
	metadata.builtin_icon = "KeyRotation"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 声明变量读写模式（rotation=read）
func get_variable_modes() -> Array[Dictionary]:
	return [{"name": "rotation_variable", "mode": "read"}]

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

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

	# 坐标空间
	properties.append({
		name = "space",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Global,Local",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 变量选项分类
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

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_ROTATION_BASE"))

	if not target_node.is_empty():
		parts.append("'%s'" % target_node)
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_ROTATION_NO_NODE"))

	parts.append("[%s]" % _get_space_string())

	var scope_str = VariableScopeUtils.enum_to_string(rotation_scope).to_upper()
	parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_ROTATION_FROM_VARIABLE", {"name": "%s [%s]" % [rotation_variable, scope_str]}))

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

	# 获取目标旋转（始终从变量读取）
	var target_rot: Vector3

	if rotation_variable.is_empty():
		_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	var var_value = VariableOperations.get_variable(context, rotation_variable, rotation_scope, null)
	if var_value == null and not VariableOperations.has_variable(context, rotation_variable, rotation_scope):
		_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": rotation_variable})
		set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"variable": rotation_variable})
		finished.emit()
		return

	# 支持更多向量类型（包括整数向量）
	if var_value is Vector2 or var_value is Vector2i or var_value is Vector3 or var_value is Vector3i:
		target_rot = var_value
	else:
		var type_str = type_string(typeof(var_value))
		_log_error_localized("FUSE_ERROR_VAR_TYPE_INVALID", {"variable": rotation_variable, "actual_type": type_str})
		set_error_localized("FUSE_ERROR_VAR_TYPE_INVALID", FuseError.ErrorType.VALIDATION_ERROR, {"variable": rotation_variable, "actual_type": type_str})
		finished.emit()
		return

	# 应用旋转变换（自动检测 2D/3D）
	if node is Node2D:
		# Node2D 只使用 Z 轴旋转
		var rot_2d = target_rot.z
		if space == CoordinateSpace.GLOBAL:
			node.global_rotation_degrees = rot_2d
		else:
			node.rotation_degrees = rot_2d

		_log_info_localized("FUSE_LOG_NODE2D_SET_ROTATION", {"node": node.name, "space": _get_space_string(), "rotation": rot_2d})

	elif node is Node3D:
		if space == CoordinateSpace.GLOBAL:
			node.global_rotation_degrees = target_rot
		else:
			node.rotation_degrees = target_rot

		_log_info_localized("FUSE_LOG_NODE3D_SET_ROTATION", {"node": node.name, "space": _get_space_string(), "x": target_rot.x, "y": target_rot.y, "z": target_rot.z})

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

	if rotation_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_ROTATION_VARIABLE_EMPTY"))

	# 验证 SCOPE 作用域需要 ScopeVariableManager
	if rotation_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

	return errors

## 验证旋转值是否有效（检查 NaN 和 Infinity）
func _is_valid_rotation(rot: Vector3) -> bool:
	# 检查每个分量是否为有效数字
	return not (is_nan(rot.x) or is_inf(rot.x) or
				is_nan(rot.y) or is_inf(rot.y) or
				is_nan(rot.z) or is_inf(rot.z))

## 获取坐标空间的本地化字符串
func _get_space_string() -> String:
	return "全局" if space == CoordinateSpace.GLOBAL else "局部"

## 动态属性设置（支持属性刷新）
func _set(property: StringName, value: Variant) -> bool:
	return false

## 属性验证
func _validate_property(property: Dictionary) -> void:
	pass

## 获取指令描述
func get_description() -> String:
	var space_str = _get_space_string()
	var source_desc = ""

	var scope_str = VariableScopeUtils.enum_to_string(rotation_scope).to_upper()
	source_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_ROTATION_DESC_VARIABLE", {"name": "%s [%s]" % [rotation_variable, scope_str]})

	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_ROTATION_DESC_FORMAT", {"node": _get_node_display_name(target_node), "source": source_desc, "space": space_str})