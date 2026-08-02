@tool
@icon("res://addons/fuse/icons/builtin/CharacterBody3D.png")
extends BaseInstruction
class_name SetVelocity

## 设置物理体（CharacterBody2D/3D, RigidBody2D/3D）的速度

# 目标物理体节点路径
var target_node: NodePath = NodePath("")

# 是否使用 3D 物理体
var use_3d: bool = false

# 2D 速度
var velocity: Vector2 = Vector2.ZERO

# 3D 速度
var velocity_3d: Vector3 = Vector3.ZERO

# 是否使用局部坐标系
var use_local_space: bool = false

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_VELOCITY_NAME"
	metadata.category_key = "FUSE_CATEGORY_PHYSICS"
	metadata.description_key = "FUSE_INSTRUCTION_SET_VELOCITY_DESC"
	metadata.keywords = ["velocity", "speed", "physics", "movement", "velocity", "速度", "物理", "移动"]
	metadata.builtin_icon = "CharacterBody3D"
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
		hint_string = "CharacterBody2D,CharacterBody3D,RigidBody2D,RigidBody3D",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 是否使用 3D
	properties.append({
		name = "use_3d",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Velocity 分类
	properties.append({
		name = "Velocity",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 2D 速度
	if not use_3d:
		properties.append({
			name = "velocity",
			type = TYPE_VECTOR2,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# 3D 速度
	if use_3d:
		properties.append({
			name = "velocity_3d",
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

	# 是否使用局部坐标系
	properties.append({
		name = "use_local_space",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	var velocity_str = str(velocity_3d) if use_3d else str(velocity)

	if use_local_space:
		resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_VELOCITY_LOCAL_RESOURCE", {
			"target": target_str,
			"velocity": velocity_str
		})
	else:
		resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_VELOCITY_RESOURCE", {
			"target": target_str,
			"velocity": velocity_str
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

	# 根据节点类型设置速度
	var success := false
	var body_type := ""

	if node is CharacterBody2D:
		var body := node as CharacterBody2D
		body.velocity = velocity
		body_type = "CharacterBody2D"
		success = true

	elif node is RigidBody2D:
		var body := node as RigidBody2D
		var final_velocity: Vector2

		if use_local_space:
			# 转换局部坐标到全局坐标
			final_velocity = body.global_transform.basis_xform(velocity)
		else:
			final_velocity = velocity

		body.linear_velocity = final_velocity
		body_type = "RigidBody2D"
		success = true

	elif node is CharacterBody3D:
		var body := node as CharacterBody3D
		body.velocity = velocity_3d
		body_type = "CharacterBody3D"
		success = true

	elif node is RigidBody3D:
		var body := node as RigidBody3D
		var final_velocity: Vector3

		if use_local_space:
			# 转换局部坐标到全局坐标
			final_velocity = body.global_transform.basis * velocity_3d
		else:
			final_velocity = velocity_3d

		body.linear_velocity = final_velocity
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

	# 记录日志
	if success:
		var vel_str = str(velocity_3d) if use_3d else str(velocity)
		if use_local_space:
			_log_info_localized("FUSE_LOG_SET_VELOCITY_LOCAL", {
				"type": body_type,
				"velocity": vel_str
			})
		else:
			_log_info_localized("FUSE_LOG_SET_VELOCITY", {
				"type": body_type,
				"velocity": vel_str
			})

	_on_execution_completed()

## 验证参数
func validate() -> Array[String]:
	var errors = super.validate()

	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_PHYSICS_NODE_EMPTY"))

	return errors

## 获取描述
func get_description() -> String:
	var vel_str = str(velocity_3d) if use_3d else str(velocity)
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")

	if use_local_space:
		return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_VELOCITY_LOCAL_DESC", {
			"target": target_str,
			"velocity": vel_str
		})
	else:
		return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_VELOCITY_DESC", {
			"target": target_str,
			"velocity": vel_str
		})

## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property == "use_3d":
		set(property, value)
		notify_property_list_changed()
		_update_resource_name()
		return true
	return false
