@tool
@icon("res://addons/fuse/icons/builtin/RigidBody2D.svg")
extends BaseInstruction
class_name SetGravityDirection

## 设置 CharacterBody2D/3D 的 up_direction（改变重力方向）

# =============================================
# 属性定义
# =============================================

## 目标 CharacterBody 节点
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## 使用 2D 模式（false = 3D）
var use_2d: bool = true:
	set(value):
		use_2d = value
		_update_resource_name()
		notify_property_list_changed()

## 方向 X 分量
var direction_x: float = 0.0:
	set(value):
		direction_x = value
		_update_resource_name()

## 方向 Y 分量
var direction_y: float = -1.0:
	set(value):
		direction_y = value
		_update_resource_name()

## 方向 Z 分量（仅 3D）
var direction_z: float = 0.0:
	set(value):
		direction_z = value
		_update_resource_name()

# =============================================
# 元数据
# =============================================
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_GRAVITY_DIRECTION_NAME"
	metadata.category_key = "FUSE_CATEGORY_PHYSICS"
	metadata.description_key = "FUSE_INSTRUCTION_SET_GRAVITY_DIRECTION_DESC"
	metadata.keywords = ["重力", "gravity", "方向", "direction", "up_direction", "物理", "physics", "body", "角色"]
	metadata.builtin_icon = "RigidBody2D"
	return metadata

func _setup_metadata():
	pass

# =============================================
# 动态属性列表
# =============================================
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Target 分类
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
		hint_string = "CharacterBody2D,CharacterBody3D",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Mode 分类
	properties.append({
		name = "Mode",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "use_2d",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Direction 分类
	properties.append({
		name = "Direction",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "direction_x",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "direction_y",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if not use_2d:
		properties.append({
			name = "direction_z",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	return properties

# =============================================
# 条件属性可见性
# =============================================
func _validate_property(property: Dictionary) -> void:
	if use_2d and property.name == "direction_z":
		property.usage = PROPERTY_USAGE_NO_EDITOR

# =============================================
# 资源名称
# =============================================
func _update_resource_name():
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	var dir_str = "(%s, %s)" % [direction_x, direction_y]
	if not use_2d:
		dir_str = "(%s, %s, %s)" % [direction_x, direction_y, direction_z]
	resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_GRAVITY_DIRECTION_RESOURCE_NAME", {
		"target": target_str,
		"direction": dir_str
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

	if use_2d:
		if node is CharacterBody2D:
			(node as CharacterBody2D).up_direction = Vector2(direction_x, direction_y)
		else:
			set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {
				"node": node.name,
				"actual_type": node.get_class()
			})
			finished.emit()
			return
	else:
		if node is CharacterBody3D:
			(node as CharacterBody3D).up_direction = Vector3(direction_x, direction_y, direction_z)
		else:
			set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {
				"node": node.name,
				"actual_type": node.get_class()
			})
			finished.emit()
			return

	_log_info_localized("FUSE_LOG_GRAVITY_DIRECTION_SET", {
		"node": node.name,
		"direction": str(use_2d and Vector2(direction_x, direction_y) or Vector3(direction_x, direction_y, direction_z))
	})
	_on_execution_completed()

# =============================================
# 描述
# =============================================
func get_description() -> String:
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_GRAVITY_DIRECTION_DESCRIPTION", {
		"target": target_str,
		"x": direction_x,
		"y": direction_y
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
	if property in ["target_node", "use_2d", "direction_x", "direction_y", "direction_z"]:
		set(property, value)
		_update_resource_name()
		if property == "use_2d":
			notify_property_list_changed()
		return true
	return false
