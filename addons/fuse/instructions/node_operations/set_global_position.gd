@tool
@icon("res://addons/fuse/icons/builtin/Node2D.svg")
extends BaseInstruction
class_name SetGlobalPosition

## 设置 Node2D/3D 的全局位置

# =============================================
# 属性定义
# =============================================

## 目标节点
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## 是否 3D
var use_3d: bool = false:
	set(value):
		use_3d = value
		_update_resource_name()
		notify_property_list_changed()

## 2D 位置
var position_2d: Vector2 = Vector2.ZERO:
	set(value):
		position_2d = value
		_update_resource_name()

## 3D 位置
var position_3d: Vector3 = Vector3.ZERO:
	set(value):
		position_3d = value
		_update_resource_name()

# =============================================
# 元数据
# =============================================
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_GLOBAL_POSITION_NAME"
	metadata.category_key = "FUSE_CATEGORY_NODE_OPERATIONS"
	metadata.description_key = "FUSE_INSTRUCTION_SET_GLOBAL_POSITION_DESC"
	metadata.keywords = ["全局位置", "global position", "坐标", "coordinate", "位置", "position", "2D", "3D", "移动", "move", "transform"]
	metadata.builtin_icon = "Node2D"
	return metadata

func _setup_metadata():
	pass

# =============================================
# 动态属性列表
# =============================================
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	properties.append({
		name = "Target",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "Node2D,Node3D",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "Mode",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "use_3d",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "Position",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	if use_3d:
		properties.append({
			name = "position_3d",
			type = TYPE_VECTOR3,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "position_2d",
			type = TYPE_VECTOR2,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	return properties

# =============================================
# 条件属性可见性
# =============================================
func _validate_property(property: Dictionary) -> void:
	if use_3d:
		if property.name == "position_2d":
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "position_3d":
			property.usage = PROPERTY_USAGE_NO_EDITOR

# =============================================
# 资源名称
# =============================================
func _update_resource_name():
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	if use_3d:
		resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_GLOBAL_POSITION_3D_RESOURCE_NAME", {
			"target": target_str,
			"x": position_3d.x,
			"y": position_3d.y,
			"z": position_3d.z
		})
	else:
		resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_GLOBAL_POSITION_2D_RESOURCE_NAME", {
			"target": target_str,
			"x": position_2d.x,
			"y": position_2d.y
		})

# =============================================
# 执行
# =============================================
func execute(context: ExecutionContext):
	_start_execution(context)

	if target_node.is_empty():
		set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	var node := context.get_node(target_node)
	if not node:
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	if use_3d:
		if node is Node3D:
			(node as Node3D).global_position = position_3d
		else:
			set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {
				"node": node.name,
				"actual_type": node.get_class()
			})
			finished.emit()
			return
	else:
		if node is Node2D:
			(node as Node2D).global_position = position_2d
		else:
			set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {
				"node": node.name,
				"actual_type": node.get_class()
			})
			finished.emit()
			return

	_log_info_localized("FUSE_LOG_GLOBAL_POSITION_SET", {
		"node": node.name,
		"position": str(use_3d and position_3d or position_2d)
	})
	_on_execution_completed()

# =============================================
# 描述
# =============================================
func get_description() -> String:
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	if use_3d:
		return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_GLOBAL_POSITION_3D_DESCRIPTION", {
			"target": target_str,
			"x": position_3d.x,
			"y": position_3d.y,
			"z": position_3d.z
		})
	else:
		return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_GLOBAL_POSITION_2D_DESCRIPTION", {
			"target": target_str,
			"x": position_2d.x,
			"y": position_2d.y
		})

# =============================================
# 验证
# =============================================
func validate() -> Array[String]:
	var errors = super.validate()
	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))
	return errors

# =============================================
# 动态属性拦截
# =============================================
func _set(property: StringName, value: Variant) -> bool:
	if property in ["target_node", "use_3d", "position_2d", "position_3d"]:
		set(property, value)
		_update_resource_name()
		if property == "use_3d":
			notify_property_list_changed()
		return true
	return false
