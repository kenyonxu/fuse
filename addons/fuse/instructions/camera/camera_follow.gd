@tool
@icon("res://addons/fuse/icons/builtin/PathFollow3D.png")
extends BaseInstruction
class_name CameraFollow

## 设置相机跟随目标节点移动

# 目标节点路径
var target_node: NodePath = NodePath("")

# 相机节点路径
var camera_node: NodePath = NodePath("")

# 跟随模式
enum FollowMode {
	LOCK,
	SMOOTH,
	DAMPED
}
var follow_mode: FollowMode = FollowMode.SMOOTH:
	set(value_):
		follow_mode = value_
		_update_resource_name()
		notify_property_list_changed()

# 平滑速度（仅 SMOOTH 模式）
var smooth_speed: float = 5.0:
	set(value_):
		smooth_speed = value_
		_update_resource_name()

# 阻尼（仅 DAMPED 模式）
var damping: bool = true:
	set(value_):
		damping = value_
		_update_resource_name()

# 是否启用跟随
var enabled: bool = true:
	set(value_):
		enabled = value_
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_CAMERA_FOLLOW_NAME"
	metadata.category_key = "FUSE_CATEGORY_CAMERA"
	metadata.description_key = "FUSE_INSTRUCTION_CAMERA_FOLLOW_DESC"
	metadata.keywords = ["camera", "follow", "target", "smooth", "track", "相机", "跟随", "追踪"]
	metadata.builtin_icon = "PathFollow3D"
	return metadata

func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	properties.append({
		name = "Camera Follow",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "camera_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "follow_mode",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Lock,Smooth,Damped",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 根据模式显示不同属性
	if follow_mode == FollowMode.SMOOTH:
		properties.append({
			name = "smooth_speed",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.1,100,0.1",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	elif follow_mode == FollowMode.DAMPED:
		properties.append({
			name = "damping",
			type = TYPE_BOOL,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	properties.append({
		name = "enabled",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts := []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_CAMERA_FOLLOW_BASE_NAME"))

	if enabled:
		var mode_key = ""
		match follow_mode:
			FollowMode.LOCK: mode_key = "FUSE_CAMERA_FOLLOW_MODE_LOCK"
			FollowMode.SMOOTH: mode_key = "FUSE_CAMERA_FOLLOW_MODE_SMOOTH"
			FollowMode.DAMPED: mode_key = "FUSE_CAMERA_FOLLOW_MODE_DAMPED"

		parts.append(FuseLocalization.translate(mode_key))

		if follow_mode == FollowMode.SMOOTH:
			parts.append(FuseLocalization.translate_format("FUSE_CAMERA_FOLLOW_SPEED", {"speed": "%.1f" % smooth_speed}))
		elif follow_mode == FollowMode.DAMPED:
			var damping_state_key = "FUSE_CAMERA_FOLLOW_DAMPING_ON" if damping else "FUSE_CAMERA_FOLLOW_DAMPING_OFF"
			parts.append(FuseLocalization.translate_format("FUSE_CAMERA_FOLLOW_DAMPING", {"state": FuseLocalization.translate(damping_state_key)}))
	else:
		parts.append(FuseLocalization.translate("FUSE_CAMERA_FOLLOW_DISABLED"))

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 获取相机节点
	var camera := context.get_node(camera_node)
	if not camera:
		_log_error_localized("FUSE_ERROR_CAMERA_NODE_NOT_FOUND", {})
		set_error_localized("FUSE_ERROR_CAMERA_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 验证相机类型
	if not camera is Camera2D:
		_log_error_localized("FUSE_ERROR_CAMERA_NOT_CAMERA2D", {})
		set_error_localized("FUSE_ERROR_CAMERA_NOT_CAMERA2D", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	var camera_2d := camera as Camera2D

	# 获取目标节点
	var target := context.get_node(target_node)
	if not target:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 验证目标类型
	if not target is Node2D:
		_log_error_localized("FUSE_ERROR_TARGET_NOT_NODE2D", {})
		set_error_localized("FUSE_ERROR_TARGET_NOT_NODE2D", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	var target_2d := target as Node2D

	# 验证平滑速度
	if follow_mode == FollowMode.SMOOTH and smooth_speed <= 0.0:
		_log_error_localized("FUSE_ERROR_INVALID_SMOOTH_SPEED", {})
		set_error_localized("FUSE_ERROR_INVALID_SMOOTH_SPEED", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 配置跟随
	if enabled:
		camera_2d.enabled = true

		match follow_mode:
			FollowMode.LOCK:
				# 锁定模式：直接设置位置
				camera_2d.position_smoothing_enabled = false
				camera_2d.global_position = target_2d.global_position
			FollowMode.SMOOTH:
				# 平滑模式：设置平滑速度
				camera_2d.position_smoothing_enabled = true
				camera_2d.position_smoothing_speed = smooth_speed
			FollowMode.DAMPED:
				# 阻尼模式：使用阻尼
				camera_2d.position_smoothing_enabled = damping
	else:
		# 禁用跟随
		camera_2d.enabled = false

	_log_info("设置相机跟随: %s → %s (模式: %s)" % [target_2d.name, camera_2d.name, FollowMode.keys()[follow_mode]])
	_on_execution_completed()

## 验证指令参数
func validate() -> Array[String]:
	var errors := super.validate()

	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	if camera_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_CAMERA_NODE_EMPTY"))

	return errors

## 获取指令描述
func get_description() -> String:
	var mode_name: String = FollowMode.keys()[follow_mode]
	var state_key = "FUSE_CAMERA_FOLLOW_ENABLED" if enabled else "FUSE_CAMERA_FOLLOW_DISABLED"
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_CAMERA_FOLLOW_DESC_FORMAT", {
		"target": _get_node_display_name(target_node),
		"state": FuseLocalization.translate(state_key),
		"mode": mode_name
	})
