@tool
@icon("res://addons/fuse/icons/builtin/CollisionShape2D.png")
extends BaseInstruction
class_name SetCollisionMask

## 设置 CollisionObject2D / CollisionObject3D 的碰撞掩码 (collision_mask)

# =============================================
# 属性定义
# =============================================

## 目标 CollisionObject2D/3D 节点
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## 碰撞掩码位值
var collision_mask: int = 1:
	set(value):
		collision_mask = value
		_update_resource_name()

# =============================================
# 元数据（必需）
# =============================================
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_COLLISION_MASK_ONLY_NAME"
	metadata.category_key = "FUSE_CATEGORY_PHYSICS"
	metadata.description_key = "FUSE_INSTRUCTION_SET_COLLISION_MASK_ONLY_DESC"
	metadata.keywords = ["碰撞", "collision", "掩码", "mask", "物理", "physics", "碰撞对象", "层"]
	metadata.builtin_icon = "CollisionShape2D"
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
		hint_string = "Area2D,Area3D,RigidBody2D,RigidBody3D,CharacterBody2D,CharacterBody3D",
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
		name = "collision_mask",
		type = TYPE_INT,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

# =============================================
# 资源名称
# =============================================
func _update_resource_name():
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_COLLISION_MASK_ONLY_RESOURCE_NAME", {
		"target": target_str,
		"mask": collision_mask
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

	# 运行时自动适配 2D/3D
	if node is CollisionObject2D:
		(node as CollisionObject2D).collision_mask = collision_mask
	elif node is CollisionObject3D:
		(node as CollisionObject3D).collision_mask = collision_mask
	else:
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {
			"node": node.name,
			"actual_type": node.get_class()
		})
		finished.emit()
		return

	_log_info_localized("FUSE_LOG_COLLISION_MASK_SET", {
		"node": node.name,
		"mask": collision_mask
	})
	_on_execution_completed()

# =============================================
# 描述
# =============================================
func get_description() -> String:
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_COLLISION_MASK_ONLY_DESCRIPTION", {
		"target": target_str,
		"mask": collision_mask
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
	if property == "collision_mask":
		set(property, value)
		_update_resource_name()
		return true
	return false
