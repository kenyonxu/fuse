@tool
@icon("res://addons/fuse/icons/builtin/CollisionShape2D.png")
extends BaseInstruction
class_name EnableDisableCollision

## 启用或禁用碰撞对象的碰撞检测

# =============================================
# 属性定义
# =============================================

## 目标碰撞对象节点
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## 是否启用碰撞
var enable: bool = true:
	set(value):
		enable = value
		_update_resource_name()

# =============================================
# 元数据（必需）
# =============================================
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_ENABLE_DISABLE_COLLISION_NAME"
	metadata.category_key = "FUSE_CATEGORY_PHYSICS"
	metadata.description_key = "FUSE_INSTRUCTION_ENABLE_DISABLE_COLLISION_DESC"
	metadata.keywords = ["碰撞", "collision", "启用", "enable", "禁用", "disable", "物理", "physics", "碰撞体", "区域"]
	metadata.builtin_icon = "CollisionShape2D"
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
		hint_string = "CollisionShape2D,CollisionShape3D,CollisionPolygon2D,CollisionPolygon3D,Area2D,Area3D",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Action 分类
	properties.append({
		name = "Action",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "enable",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

# =============================================
# 资源名称
# =============================================
func _update_resource_name():
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	var action_str = FuseLocalization.translate("FUSE_INSTRUCTION_ENABLE_DISABLE_COLLISION_ENABLE") if enable else FuseLocalization.translate("FUSE_INSTRUCTION_ENABLE_DISABLE_COLLISION_DISABLE")
	resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_ENABLE_DISABLE_COLLISION_RESOURCE_NAME", {
		"action": action_str,
		"target": target_str
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

	var handled := false

	# CollisionShape2D/3D — 使用 disabled 属性
	if node is CollisionShape2D or node is CollisionShape3D:
		node.set_deferred("disabled", not enable)
		handled = true
	# CollisionPolygon2D/3D — 使用 disabled 属性
	elif node is CollisionPolygon2D or node is CollisionPolygon3D:
		node.set_deferred("disabled", not enable)
		handled = true
	# Area2D — 控制 monitoring 和 monitorable
	elif node is Area2D:
		var area := node as Area2D
		area.set_deferred("monitoring", enable)
		area.set_deferred("monitorable", enable)
		handled = true
	# Area3D — 控制 monitoring 和 monitorable
	elif node is Area3D:
		var area := node as Area3D
		area.set_deferred("monitoring", enable)
		area.set_deferred("monitorable", enable)
		handled = true
	else:
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {
			"node": node.name,
			"actual_type": node.get_class()
		})
		finished.emit()
		return

	if handled:
		var action_key = "FUSE_LOG_COLLISION_ENABLED" if enable else "FUSE_LOG_COLLISION_DISABLED"
		_log_info_localized(action_key, {"node": node.name})

	_on_execution_completed()

# =============================================
# 描述
# =============================================
func get_description() -> String:
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	var action_str = FuseLocalization.translate("FUSE_INSTRUCTION_ENABLE_DISABLE_COLLISION_ENABLE") if enable else FuseLocalization.translate("FUSE_INSTRUCTION_ENABLE_DISABLE_COLLISION_DISABLE")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_ENABLE_DISABLE_COLLISION_DESCRIPTION", {
		"action": action_str,
		"target": target_str
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
	if property == "enable":
		set(property, value)
		_update_resource_name()
		return true
	return false
