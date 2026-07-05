@tool
@icon("res://addons/fuse/icons/builtin/RigidBody2D.svg")
extends BaseInstruction
class_name SetGravityScale

## 设置物理体的重力缩放值（支持 CharacterBody2D/3D 和 RigidBody2D/3D）

# =============================================
# 属性定义
# =============================================

## 目标物理体节点
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## 重力缩放值（0 = 无重力）
var gravity_scale: float = 1.0:
	set(value):
		gravity_scale = value
		_update_resource_name()

# =============================================
# 元数据（必需）
# =============================================
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_GRAVITY_SCALE_NAME"
	metadata.category_key = "FUSE_CATEGORY_PHYSICS"
	metadata.description_key = "FUSE_INSTRUCTION_SET_GRAVITY_SCALE_DESC"
	metadata.keywords = ["重力", "gravity", "缩放", "scale", "物理", "physics", "body", "刚体", "角色"]
	metadata.builtin_icon = "RigidBody2D"
	return metadata

func _setup_metadata():
	pass

# =============================================
# 动态属性列表
# =============================================
func _get_property_list() -> Array[Dictionary]:
	var properties := []

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
		hint_string = "CharacterBody2D,CharacterBody3D,RigidBody2D,RigidBody3D",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Value 分类
	properties.append({
		name = "Value",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "gravity_scale",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

# =============================================
# 资源名称
# =============================================
func _update_resource_name():
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_GRAVITY_SCALE_RESOURCE_NAME", {
		"target": target_str,
		"scale": gravity_scale
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

	# 支持多种物理体类型
	if node is CharacterBody2D:
		(node as CharacterBody2D).gravity_scale = gravity_scale
	elif node is CharacterBody3D:
		(node as CharacterBody3D).gravity_scale = gravity_scale
	elif node is RigidBody2D:
		(node as RigidBody2D).gravity_scale = gravity_scale
	elif node is RigidBody3D:
		(node as RigidBody3D).gravity_scale = gravity_scale
	else:
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {
			"node": node.name,
			"actual_type": node.get_class()
		})
		finished.emit()
		return

	_log_info_localized("FUSE_LOG_GRAVITY_SCALE_SET", {
		"node": node.name,
		"scale": gravity_scale
	})
	_on_execution_completed()

# =============================================
# 描述
# =============================================
func get_description() -> String:
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_GRAVITY_SCALE_DESCRIPTION", {
		"target": target_str,
		"scale": gravity_scale
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
	if property == "gravity_scale":
		set(property, value)
		_update_resource_name()
		return true
	return false
