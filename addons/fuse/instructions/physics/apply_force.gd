@tool
@icon("res://addons/fuse/icons/builtin/ToolPan.png")
extends BaseInstruction
class_name ApplyForce

## 对 RigidBody 施加持续力（如风力、推进器等）

# 目标物理体节点路径
var target_node: NodePath = NodePath("")

# 是否使用 3D 物理体
var use_3d: bool = false

# 2D 力向量
var force: Vector2 = Vector2.ZERO

# 3D 力向量
var force_3d: Vector3 = Vector3.ZERO

# 施力位置（相对于物体中心）
var force_position: Vector2 = Vector2.ZERO
var force_position_3d: Vector3 = Vector3.ZERO

# 是否在物体中心施加力
var use_center: bool = true

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_APPLY_FORCE_NAME"
	metadata.category_key = "FUSE_CATEGORY_PHYSICS"
	metadata.description_key = "FUSE_INSTRUCTION_APPLY_FORCE_DESC"
	metadata.keywords = ["force", "physics", "push", "wind", "thruster", "力", "物理", "推力", "风力", "推进器"]
	metadata.builtin_icon = "ToolPan"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Target Body 分类
	properties.append({
		name = "Target Body",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 目标物理体节点
	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "RigidBody2D,RigidBody3D",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 是否使用 3D
	properties.append({
		name = "use_3d",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Force 分类
	properties.append({
		name = "Force",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 2D 力
	if not use_3d:
		properties.append({
			name = "force",
			type = TYPE_VECTOR2,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# 3D 力
	if use_3d:
		properties.append({
			name = "force_3d",
			type = TYPE_VECTOR3,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# Options 分类
	properties.append({
		name = "Options",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 是否在中心施加力
	properties.append({
		name = "use_center",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 施力位置（仅在不使用中心时显示）
	if not use_center:
		if not use_3d:
			properties.append({
				name = "force_position",
				type = TYPE_VECTOR2,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		else:
			properties.append({
				name = "force_position_3d",
				type = TYPE_VECTOR3,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	return properties

## 更新资源名称
func _update_resource_name():
	if target_node.is_empty():
		if use_center:
			resource_name = FuseLocalization.translate("FUSE_INSTRUCTION_APPLY_FORCE_NO_TARGET_CENTER")
		else:
			var pos_str = str(force_position_3d) if use_3d else str(force_position)
			var force_str = str(force_3d) if use_3d else str(force)
			resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_APPLY_FORCE_NO_TARGET_OFFSET", {
				"force": force_str,
				"position": pos_str
			})
	else:
		if use_center:
			var force_str = str(force_3d) if use_3d else str(force)
			resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_APPLY_FORCE_TARGET_CENTER", {
				"target": _get_node_display_name(target_node),
				"force": force_str
			})
		else:
			var pos_str = str(force_position_3d) if use_3d else str(force_position)
			var force_str = str(force_3d) if use_3d else str(force)
			resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_APPLY_FORCE_TARGET_OFFSET", {
				"target": _get_node_display_name(target_node),
				"force": force_str,
				"position": pos_str
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

	# 获取物理体节点
	var node := context.get_node(target_node)
	if not node:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	# 根据节点类型施加力
	var success := false
	var body_type := ""

	if node is RigidBody2D:
		var body := node as RigidBody2D

		if use_center:
			# 中心力（不产生旋转）
			body.apply_central_force(force)
			_log_info_localized("FUSE_LOG_APPLY_CENTRAL_FORCE", {})
		else:
			# 偏心力（产生旋转）
			body.apply_force(force, force_position)
			_log_info_localized("FUSE_LOG_APPLY_FORCE_2D", {
				"node": body.name,
				"force": str(force)
			})

		body_type = "RigidBody2D"
		success = true

	elif node is RigidBody3D:
		var body := node as RigidBody3D

		if use_center:
			# 中心力（不产生旋转）
			body.apply_central_force(force_3d)
			_log_info_localized("FUSE_LOG_APPLY_CENTRAL_FORCE", {})
		else:
			# 偏心力（产生旋转）
			body.apply_force(force_3d, force_position_3d)
			_log_info_localized("FUSE_LOG_APPLY_FORCE_3D", {
				"node": body.name,
				"force": str(force_3d)
			})

		body_type = "RigidBody3D"
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
		if use_center:
			_log_info_localized("FUSE_LOG_APPLY_SUCCESS_CENTRAL", {"body": body_type})
		else:
			var force_str = str(force_3d) if use_3d else str(force)
			_log_info_localized("FUSE_LOG_APPLY_SUCCESS_OFFSET", {"body": body_type, "force": force_str})

	_on_execution_completed()

## 验证参数
func validate() -> Array[String]:
	var errors = super.validate()

	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_PHYSICS_NODE_EMPTY"))

	return errors

## 获取描述
func get_description() -> String:
	var force_str = str(force_3d) if use_3d else str(force)
	if use_center:
		return FuseLocalization.translate_format("FUSE_INSTRUCTION_APPLY_FORCE_DESC_CENTER", {
			"target": _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED"),
			"force": force_str
		})
	else:
		return FuseLocalization.translate_format("FUSE_INSTRUCTION_APPLY_FORCE_DESC_OFFSET", {
			"target": _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED"),
			"force": force_str
		})

## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property == "use_3d" or property == "use_center":
		set(property, value)
		notify_property_list_changed()
		_update_resource_name()
		return true
	return false
