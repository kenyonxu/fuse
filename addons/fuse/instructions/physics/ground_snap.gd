@tool
@icon("res://addons/fuse/icons/builtin/PlaneMesh.png")
extends BaseInstruction
class_name GroundSnap

## Ground Snap 指令 - 对 CharacterBody2D/3D 执行贴地操作
##
## 设置 up_direction 并检查 is_on_floor() 状态。
## V1 简化版：不实现完整 snap 物理，仅验证贴地状态。

## 目标节点路径（CharacterBody2D 或 CharacterBody3D）
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()
		notify_property_list_changed()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_GROUND_SNAP_NAME"
	metadata.category_key = "FUSE_CATEGORY_PHYSICS"
	metadata.description_key = "FUSE_INSTRUCTION_GROUND_SNAP_DESC"
	metadata.keywords = ["地面", "ground", "snap", "贴地", "physics", "物理", "character", "body", "floor"]
	metadata.builtin_icon = "PlaneMesh"
	return metadata

func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		name = "Ground Snap",
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

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_GROUND_SNAP_NAME"))

	if not target_node.is_empty():
		parts.append("[%s]" % _get_node_display_name(target_node))
	else:
		parts.append("[%s]" % FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED"))

	resource_name = " ".join(parts)

## 获取指令描述
func get_description() -> String:
	var target_desc = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_GROUND_SNAP_DESC_FORMAT", {"target": target_desc})

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	# 验证目标节点
	if target_node.is_empty():
		_log_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", {})
		set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	var node = context.get_node(target_node)
	if node == null:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	# V1 简化版：设置 up_direction 并检查贴地状态
	if node is CharacterBody2D:
		var body_2d := node as CharacterBody2D
		body_2d.up_direction = Vector2.UP
		var on_floor = body_2d.is_on_floor()
		_log_info_localized("FUSE_LOG_GROUND_SNAP_2D", {
			"node": node.name,
			"on_floor": str(on_floor)
		})
	elif node is CharacterBody3D:
		var body_3d := node as CharacterBody3D
		body_3d.up_direction = Vector3.UP
		var on_floor = body_3d.is_on_floor()
		_log_info_localized("FUSE_LOG_GROUND_SNAP_3D", {
			"node": node.name,
			"on_floor": str(on_floor)
		})
	else:
		_log_error_localized("FUSE_ERROR_CHARACTER_BODY_REQUIRED", {})
		set_error_localized("FUSE_ERROR_CHARACTER_BODY_REQUIRED", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	_on_execution_completed()

## 验证参数
func validate() -> Array[String]:
	var errors = super.validate()
	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))
	return errors
