@tool
@icon("res://addons/fuse/icons/builtin/TouchScreenButton.png")
extends BaseInstruction
class_name ApplyImpulse

## 对 RigidBody 施加瞬间冲量（如爆炸、跳跃等）

# 目标物理体节点路径
var target_node: NodePath = NodePath("")

# 是否使用 3D 物理体
var use_3d: bool = false

# 2D 冲量向量
var impulse: Vector2 = Vector2.ZERO

# 3D 冲量向量
var impulse_3d: Vector3 = Vector3.ZERO

# 施力位置（相对于物体中心）
var impulse_position: Vector2 = Vector2.ZERO
var impulse_position_3d: Vector3 = Vector3.ZERO

# 是否在物体中心施加冲量
var use_center: bool = true

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_APPLY_IMPULSE_NAME"
	metadata.category_key = "FUSE_CATEGORY_PHYSICS"
	metadata.description_key = "FUSE_INSTRUCTION_APPLY_IMPULSE_DESC"
	metadata.keywords = ["impulse", "physics", "force", "explosion", "jump", "冲量", "物理", "力", "爆炸", "跳跃"]
	metadata.builtin_icon = "TouchScreenButton"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

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

	# Impulse 分类
	properties.append({
		name = "Impulse",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 2D 冲量
	if not use_3d:
		properties.append({
			name = "impulse",
			type = TYPE_VECTOR2,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# 3D 冲量
	if use_3d:
		properties.append({
			name = "impulse_3d",
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

	# 是否在中心施加冲量
	properties.append({
		name = "use_center",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 施力位置（仅在不使用中心时显示）
	if not use_center:
		if not use_3d:
			properties.append({
				name = "impulse_position",
				type = TYPE_VECTOR2,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		else:
			properties.append({
				name = "impulse_position_3d",
				type = TYPE_VECTOR3,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	return properties

## 更新资源名称
func _update_resource_name():
	if target_node.is_empty():
		if use_center:
			resource_name = FuseLocalization.translate("FUSE_INSTRUCTION_APPLY_IMPULSE_NO_TARGET_CENTER")
		else:
			var pos_str = str(impulse_position_3d) if use_3d else str(impulse_position)
			var impulse_str = str(impulse_3d) if use_3d else str(impulse)
			resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_APPLY_IMPULSE_NO_TARGET_OFFSET", {
				"impulse": impulse_str,
				"position": pos_str
			})
	else:
		if use_center:
			var impulse_str = str(impulse_3d) if use_3d else str(impulse)
			resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_APPLY_IMPULSE_TARGET_CENTER", {
				"target": _get_node_display_name(target_node),
				"impulse": impulse_str
			})
		else:
			var pos_str = str(impulse_position_3d) if use_3d else str(impulse_position)
			var impulse_str = str(impulse_3d) if use_3d else str(impulse)
			resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_APPLY_IMPULSE_TARGET_OFFSET", {
				"target": _get_node_display_name(target_node),
				"impulse": impulse_str,
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

	# 根据节点类型施加冲量
	var success := false
	var body_type := ""

	if node is RigidBody2D:
		var body := node as RigidBody2D

		if use_center:
			# 中心冲量（不产生旋转）
			body.apply_central_impulse(impulse)
			_log_info_localized("FUSE_LOG_APPLY_CENTRAL_IMPULSE", {})
		else:
			# 偏心冲量（产生旋转）
			body.apply_impulse(impulse, impulse_position)
			_log_info_localized("FUSE_LOG_APPLY_IMPULSE_2D", {
				"node": body.name,
				"impulse": str(impulse)
			})

		body_type = "RigidBody2D"
		success = true

	elif node is RigidBody3D:
		var body := node as RigidBody3D

		if use_center:
			# 中心冲量（不产生旋转）
			body.apply_central_impulse(impulse_3d)
			_log_info_localized("FUSE_LOG_APPLY_CENTRAL_IMPULSE", {})
		else:
			# 偏心冲量（产生旋转）
			body.apply_impulse(impulse_3d, impulse_position_3d)
			_log_info_localized("FUSE_LOG_APPLY_IMPULSE_3D", {
				"node": body.name,
				"impulse": str(impulse_3d)
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
			var imp_str = str(impulse_3d) if use_3d else str(impulse)
			_log_info_localized("FUSE_LOG_APPLY_SUCCESS_OFFSET", {"body": body_type, "impulse": imp_str})

	_on_execution_completed()

## 验证参数
func validate() -> Array[String]:
	var errors = super.validate()

	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_PHYSICS_NODE_EMPTY"))

	return errors

## 获取描述
func get_description() -> String:
	var imp_str = str(impulse_3d) if use_3d else str(impulse)
	if use_center:
		return FuseLocalization.translate_format("FUSE_INSTRUCTION_APPLY_IMPULSE_DESC_CENTER", {
			"target": _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED"),
			"impulse": imp_str
		})
	else:
		return FuseLocalization.translate_format("FUSE_INSTRUCTION_APPLY_IMPULSE_DESC_OFFSET", {
			"target": _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED"),
			"impulse": imp_str
		})

## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property == "use_3d" or property == "use_center":
		set(property, value)
		notify_property_list_changed()
		_update_resource_name()
		return true
	return false
