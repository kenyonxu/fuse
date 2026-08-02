@tool
@icon("res://addons/fuse/icons/builtin/KeyPosition.png")
extends BaseInstruction
class_name SetPosition

## 设置节点的位置（支持 2D/3D）
##
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问

# 目标节点路径
var target_node: NodePath = NodePath("")

# 目标位置
var position: Vector3 = Vector3.ZERO

# 坐标空间（Global/Local）
enum CoordinateSpace {
	GLOBAL,
	LOCAL
}
var space: CoordinateSpace = CoordinateSpace.GLOBAL

# 是否使用变量
var use_variable: bool = false

# 位置变量名
var position_variable: String = ""

# 位置变量作用域
@export var position_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_POSITION_NAME"
	metadata.category_key = "FUSE_CATEGORY_TRANSFORM"
	metadata.description_key = "FUSE_INSTRUCTION_SET_POSITION_DESC"
	metadata.keywords = ["position", "transform", "move", "location", "位置", "变换", "移动"]
	# 设置指令选择器图标
	metadata.builtin_icon = "KeyPosition"
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

	# 是否使用变量
	properties.append({
		name = "use_variable",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 位置值（当不使用变量时显示）
	properties.append({
		name = "position",
		type = TYPE_VECTOR3,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 位置变量名（当使用变量时显示）
	properties.append({
		name = "position_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 位置变量作用域（当使用变量时显示）
	properties.append({
		name = "position_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_POSITION_BASE"))

	if not target_node.is_empty():
		parts.append("'%s'" % target_node)
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_POSITION_NO_NODE"))

	parts.append("[%s]" % _get_space_string())

	if use_variable:
		if position_variable.is_empty():
			parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_POSITION_NO_VARIABLE"))
		else:
			var scope_str = VariableScopeUtils.enum_to_string(position_scope).to_upper()
			parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_POSITION_FROM_VARIABLE", {"name": "%s [%s]" % [position_variable, scope_str]}))
	else:
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_POSITION_VALUE", {"x": position.x, "y": position.y, "z": position.z}))

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

	# 获取目标位置
	var target_pos: Vector3

	if use_variable:
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

		# 支持更多向量类型（包括整数向量）
		if var_value is Vector2 or var_value is Vector2i or var_value is Vector3 or var_value is Vector3i:
			target_pos = var_value
		else:
			var type_str = type_string(typeof(var_value))
			_log_error_localized("FUSE_ERROR_VAR_TYPE_INVALID", {"variable": position_variable, "actual_type": type_str})
			set_error_localized("FUSE_ERROR_VAR_TYPE_INVALID", FuseError.ErrorType.VALIDATION_ERROR, {"variable": position_variable, "actual_type": type_str})
			finished.emit()
			return
	else:
		target_pos = position
		# 验证位置值有效性
		if not _is_valid_position(target_pos):
			_log_error_localized("FUSE_ERROR_INVALID_POSITION", {})
			set_error_localized("FUSE_ERROR_INVALID_POSITION", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

	# 应用位置变换（自动检测 2D/3D）
	if node is Node2D:
		var pos_2d = Vector2(target_pos.x, target_pos.y)
		if space == CoordinateSpace.GLOBAL:
			node.global_position = pos_2d
		else:
			node.position = pos_2d

		_log_info_localized("FUSE_LOG_NODE2D_SET_POSITION", {"node": node.name, "space": _get_space_string(), "x": pos_2d.x, "y": pos_2d.y})

	elif node is Node3D:
		if space == CoordinateSpace.GLOBAL:
			node.global_position = target_pos
		else:
			node.position = target_pos

		_log_info_localized("FUSE_LOG_NODE3D_SET_POSITION", {"node": node.name, "space": _get_space_string(), "x": target_pos.x, "y": target_pos.y, "z": target_pos.z})

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

	if use_variable and position_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_POSITION_VARIABLE_EMPTY"))

	# 验证 SCOPE 作用域需要 ScopeVariableManager
	if use_variable and position_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

	return errors

## 验证位置值是否有效（检查 NaN 和 Infinity）
func _is_valid_position(pos: Vector3) -> bool:
	# 检查每个分量是否为有效数字
	return not (is_nan(pos.x) or is_inf(pos.x) or
				is_nan(pos.y) or is_inf(pos.y) or
				is_nan(pos.z) or is_inf(pos.z))

## 获取坐标空间的本地化字符串
func _get_space_string() -> String:
	return "全局" if space == CoordinateSpace.GLOBAL else "局部"

## 动态属性设置（支持属性刷新）
func _set(property: StringName, value: Variant) -> bool:
	if property == "use_variable" or property == "space":
		set(property, value)
		notify_property_list_changed()
		return true
	return false

## 属性验证
func _validate_property(property: Dictionary) -> void:
	if property.name == "position" and use_variable:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	if property.name == "position_variable" and not use_variable:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	if property.name == "position_scope" and not use_variable:
		property.usage = PROPERTY_USAGE_NO_EDITOR

## 获取指令描述
func get_description() -> String:
	var space_str = _get_space_string()
	var source_desc = ""

	if use_variable:
		if position_variable.is_empty():
			source_desc = FuseLocalization.translate("FUSE_INSTRUCTION_SET_POSITION_DESC_NO_VARIABLE")
		else:
			var scope_str = VariableScopeUtils.enum_to_string(position_scope).to_upper()
			source_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_POSITION_DESC_VARIABLE", {"name": "%s [%s]" % [position_variable, scope_str]})
	else:
		source_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_POSITION_DESC_VALUE", {"x": position.x, "y": position.y, "z": position.z})

	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_POSITION_DESC_FORMAT", {"node": _get_node_display_name(target_node), "source": source_desc, "space": space_str})