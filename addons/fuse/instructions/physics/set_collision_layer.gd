@tool
@icon("res://addons/fuse/icons/builtin/GuiMiniCheckerboard.png")
extends BaseInstruction
class_name SetCollisionLayer

## 设置 CollisionObject 的碰撞层和/或掩码

# 目标碰撞对象节点路径
var target_node: NodePath = NodePath("")

# 是否使用 3D 节点
var use_3d: bool = false

# 设置类型枚举
enum SetType {
	LAYER = 0,  # 仅设置层
	MASK = 1,   # 仅设置掩码
	BOTH = 2    # 同时设置层和掩码
}

# 设置类型
var set_type: SetType = SetType.BOTH

# 碰撞层值（位掩码）
var layer_value: int = 1

# 碰撞掩码值（位掩码）
var mask_value: int = 1

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_COLLISION_LAYER_NAME"
	metadata.category_key = "FUSE_CATEGORY_PHYSICS"
	metadata.description_key = "FUSE_INSTRUCTION_SET_COLLISION_LAYER_DESC"
	metadata.keywords = ["collision", "layer", "mask", "physics", "碰撞", "层", "掩码", "物理"]
	metadata.builtin_icon = "GuiMiniCheckerboard"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Target 分类
	properties.append({
		name = "Target",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 目标碰撞对象节点
	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "Area2D,Area3D,RigidBody2D,RigidBody3D,CharacterBody2D,CharacterBody3D",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 是否使用 3D
	properties.append({
		name = "use_3d",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Settings 分类
	properties.append({
		name = "Settings",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 设置类型
	properties.append({
		name = "set_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Layer,Mask,Both",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Layer Value 分类（根据设置类型显示）
	if set_type == SetType.LAYER or set_type == SetType.BOTH:
		properties.append({
			name = "Layer Value",
			type = TYPE_NIL,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_CATEGORY
		})

		properties.append({
			name = "layer_value",
			type = TYPE_INT,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# Mask Value 分类（根据设置类型显示）
	if set_type == SetType.MASK or set_type == SetType.BOTH:
		properties.append({
			name = "Mask Value",
			type = TYPE_NIL,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_CATEGORY
		})

		properties.append({
			name = "mask_value",
			type = TYPE_INT,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	return properties

## 更新资源名称
func _update_resource_name():
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")

	if set_type == SetType.LAYER:
		resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_COLLISION_LAYER_RESOURCE", {
			"target": target_str,
			"value": layer_value
		})
	elif set_type == SetType.MASK:
		resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_COLLISION_MASK_RESOURCE", {
			"target": target_str,
			"value": mask_value
		})
	else:  # BOTH
		resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_COLLISION_BOTH_RESOURCE", {
			"target": target_str,
			"layer": layer_value,
			"mask": mask_value
		})

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证目标节点
	if target_node.is_empty():
		_log_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", {})
		set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取碰撞对象节点
	var node := context.get_node(target_node)
	if not node:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	# 根据节点类型设置碰撞层/掩码
	var success := false
	var obj_type := ""

	if node is CollisionObject2D:
		var obj := node as CollisionObject2D

		if set_type == SetType.LAYER:
			obj.collision_layer = layer_value
			_log_info_localized("FUSE_LOG_SET_COLLISION_LAYER", {"value": layer_value})
		elif set_type == SetType.MASK:
			obj.collision_mask = mask_value
			_log_info_localized("FUSE_LOG_SET_COLLISION_MASK", {"value": mask_value})
		else:  # BOTH
			obj.collision_layer = layer_value
			obj.collision_mask = mask_value
			_log_info_localized("FUSE_LOG_SET_COLLISION_BOTH", {
				"layer": layer_value,
				"mask": mask_value
			})

		obj_type = "CollisionObject2D"
		success = true

	elif node is CollisionObject3D:
		var obj := node as CollisionObject3D

		if set_type == SetType.LAYER:
			obj.collision_layer = layer_value
			_log_info_localized("FUSE_LOG_SET_COLLISION_LAYER", {"value": layer_value})
		elif set_type == SetType.MASK:
			obj.collision_mask = mask_value
			_log_info_localized("FUSE_LOG_SET_COLLISION_MASK", {"value": mask_value})
		else:  # BOTH
			obj.collision_layer = layer_value
			obj.collision_mask = mask_value
			_log_info_localized("FUSE_LOG_SET_COLLISION_BOTH", {
				"layer": layer_value,
				"mask": mask_value
			})

		obj_type = "CollisionObject3D"
		success = true

	else:
		# 节点类型无效
		var type_str = node.get_class()
		_log_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", {
			"node": node.name,
			"actual_type": type_str
		})
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {
			"node": node.name,
			"actual_type": type_str
		})
		finished.emit()
		return

	# 记录成功日志
	if success:
		_log_info_localized("FUSE_LOG_SET_COLLISION_SUCCESS", {
			"type": obj_type,
			"node": node.name
		})

	_on_execution_completed()

## 验证参数
func validate() -> Array[String]:
	var errors = super.validate()

	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_COLLISION_NODE_EMPTY"))

	# 验证位掩码值在有效范围内（1-32位）
	if set_type == SetType.LAYER or set_type == SetType.BOTH:
		if layer_value < 0 or layer_value > 0xFFFFFFFF:
			errors.append(FuseLocalization.translate("FUSE_ERROR_COLLISION_LAYER_VALUE_OUT_OF_RANGE"))

	if set_type == SetType.MASK or set_type == SetType.BOTH:
		if mask_value < 0 or mask_value > 0xFFFFFFFF:
			errors.append(FuseLocalization.translate("FUSE_ERROR_COLLISION_MASK_VALUE_OUT_OF_RANGE"))

	return errors

## 获取描述
func get_description() -> String:
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")

	if set_type == SetType.LAYER:
		return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_COLLISION_LAYER_DESC", {
			"target": target_str,
			"value": layer_value
		})
	elif set_type == SetType.MASK:
		return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_COLLISION_MASK_DESC", {
			"target": target_str,
			"value": mask_value
		})
	else:  # BOTH
		return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_COLLISION_BOTH_DESC", {
			"target": target_str,
			"layer": layer_value,
			"mask": mask_value
		})

## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property == "use_3d" or property == "set_type":
		set(property, value)
		notify_property_list_changed()
		_update_resource_name()
		return true
	if property == "layer_value" or property == "mask_value":
		set(property, value)
		_update_resource_name()
		return true
	return false
