@tool
@icon("res://addons/fuse/icons/builtin/PathFollow3D.png")
extends BaseInstruction
class_name CameraFollow

## 设置相机跟随目标节点移动

## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 目标节点配置
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## 是否从变量获取目标节点
var use_variable_for_target: bool = false:
	set(value):
		use_variable_for_target = value
		_update_resource_name()
		notify_property_list_changed()

## 目标节点变量名
var target_variable: String = "":
	set(value):
		target_variable = value
		_update_resource_name()

## 目标节点变量作用域
var target_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		target_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 目标节点作用域来源（仅当 target_scope == SCOPE 时使用）
var target_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		target_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 目标节点自定义作用域 ID（CUSTOM_ID 模式使用）
var target_custom_scope_id: String = "":
	set(value):
		target_custom_scope_id = value
		_update_resource_name()

## 目标节点目标节点路径（TARGET_NODE 模式使用）
var target_target_node_path: NodePath = NodePath(""):
	set(value):
		target_target_node_path = value
		_update_resource_name()

## 相机节点配置
var camera_node: NodePath = NodePath(""):
	set(value):
		camera_node = value
		_update_resource_name()

## 是否从变量获取相机节点
var use_variable_for_camera: bool = false:
	set(value):
		use_variable_for_camera = value
		_update_resource_name()
		notify_property_list_changed()

## 相机节点变量名
var camera_variable: String = "":
	set(value):
		camera_variable = value
		_update_resource_name()

## 相机节点变量作用域
var camera_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		camera_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 相机节点作用域来源（仅当 camera_scope == SCOPE 时使用）
var camera_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		camera_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 相机节点自定义作用域 ID（CUSTOM_ID 模式使用）
var camera_custom_scope_id: String = "":
	set(value):
		camera_custom_scope_id = value
		_update_resource_name()

## 相机节点目标节点路径（TARGET_NODE 模式使用）
var camera_target_node_path: NodePath = NodePath(""):
	set(value):
		camera_target_node_path = value
		_update_resource_name()

## 跟随模式
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

## 平滑速度（仅 SMOOTH 模式）
var smooth_speed: float = 5.0:
	set(value_):
		smooth_speed = value_
		_update_resource_name()

## 阻尼（仅 DAMPED 模式）
var damping: bool = true:
	set(value_):
		damping = value_
		_update_resource_name()

## 是否启用跟随
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


## 声明变量读写模式
func get_variable_modes() -> Array[Dictionary]:
	var modes: Array[Dictionary] = []
	if use_variable_for_target:
		modes.append({"name": "target_variable", "mode": "read"})
	if use_variable_for_camera:
		modes.append({"name": "camera_variable", "mode": "read"})
	return modes


## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		name = "Camera Follow",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# Target 分类
	properties.append({
		name = "Target",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "use_variable_for_target",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if not use_variable_for_target:
		properties.append({
			name = "target_node",
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			hint_string = "Node2D",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "target_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "target_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if target_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "target_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			if target_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "target_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif target_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "target_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	# Camera 分类
	properties.append({
		name = "Camera",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "use_variable_for_camera",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if not use_variable_for_camera:
		properties.append({
			name = "camera_node",
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			hint_string = "Camera2D",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "camera_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "camera_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if camera_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "camera_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			if camera_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "camera_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif camera_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "camera_target_node_path",
					type = TYPE_NODE_PATH,
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


## 属性验证
func _validate_property(property: Dictionary) -> void:
	# 控制目标节点相关属性可见性
	if not use_variable_for_target:
		if property.name in ["target_variable", "target_scope", "target_scope_source", "target_custom_scope_id", "target_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "target_node":
			property.usage = PROPERTY_USAGE_NO_EDITOR

		if target_scope != BaseVariable.VariableScope.SCOPE:
			if property.name in ["target_scope_source", "target_custom_scope_id", "target_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
			VariableScopeUtils.validate_scope_source_property(property, target_utils_scope_source)

	# 控制相机节点相关属性可见性
	if not use_variable_for_camera:
		if property.name in ["camera_variable", "camera_scope", "camera_scope_source", "camera_custom_scope_id", "camera_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "camera_node":
			property.usage = PROPERTY_USAGE_NO_EDITOR

		if camera_scope != BaseVariable.VariableScope.SCOPE:
			if property.name in ["camera_scope_source", "camera_custom_scope_id", "camera_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			var camera_utils_scope_source = camera_scope_source as VariableScopeUtils.ScopeSource
			VariableScopeUtils.validate_scope_source_property(property, camera_utils_scope_source)


## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property in ["use_variable_for_target", "use_variable_for_camera", "target_scope", "camera_scope", "target_scope_source", "camera_scope_source"]:
		set(property, value)
		notify_property_list_changed()
		return true
	return false

## 更新资源名称
func _update_resource_name():
	var parts := []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_CAMERA_FOLLOW_BASE_NAME"))

	# 目标节点描述
	var target_desc := ""
	if use_variable_for_target:
		if target_variable.is_empty():
			target_desc = FuseLocalization.translate("FUSE_INSTRUCTION_CAMERA_FOLLOW_TARGET_VARIABLE_EMPTY")
		else:
			var scope_str = VariableScopeUtils.enum_to_string(target_scope).to_upper()
			target_desc = "%s [%s]" % [target_variable, scope_str]
	else:
		target_desc = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY")

	# 相机节点描述
	var camera_desc := ""
	if use_variable_for_camera:
		if camera_variable.is_empty():
			camera_desc = FuseLocalization.translate("FUSE_INSTRUCTION_CAMERA_FOLLOW_CAMERA_VARIABLE_EMPTY")
		else:
			var scope_str = VariableScopeUtils.enum_to_string(camera_scope).to_upper()
			camera_desc = "%s [%s]" % [camera_variable, scope_str]
	else:
		camera_desc = _get_node_display_name(camera_node) if not camera_node.is_empty() else FuseLocalization.translate("FUSE_ERROR_CAMERA_NODE_EMPTY")

	parts.append("%s → %s" % [target_desc, camera_desc])

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
	var camera := _resolve_node(
		context,
		use_variable_for_camera,
		camera_node,
		camera_variable,
		camera_scope,
		camera_scope_source,
		camera_custom_scope_id,
		camera_target_node_path,
		"FUSE_ERROR_CAMERA_VARIABLE_EMPTY",
		"FUSE_ERROR_CAMERA_NODE_EMPTY",
		"FUSE_ERROR_CAMERA_NODE_NOT_FOUND"
	)
	if not camera:
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
	var target := _resolve_node(
		context,
		use_variable_for_target,
		target_node,
		target_variable,
		target_scope,
		target_scope_source,
		target_custom_scope_id,
		target_target_node_path,
		"FUSE_ERROR_TARGET_VARIABLE_EMPTY",
		"FUSE_ERROR_TARGET_NODE_EMPTY",
		"FUSE_ERROR_TARGET_NODE_NOT_FOUND"
	)
	if not target:
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

		# 通过 RemoteTransform2D 让 Camera2D 每帧跟随 target
		# （Godot 原生每帧同步 transform，解决一次性配置不持续跟随的问题）
		_setup_follow_remote(camera_2d, target_2d)

		match follow_mode:
			FollowMode.LOCK:
				# 锁定模式：关闭平滑，瞬时跟随
				camera_2d.position_smoothing_enabled = false
			FollowMode.SMOOTH:
				# 平滑模式：Camera2D 内置平滑（position 由 RemoteTransform2D 每帧驱动）
				camera_2d.position_smoothing_enabled = true
				camera_2d.position_smoothing_speed = smooth_speed
			FollowMode.DAMPED:
				# 阻尼模式：使用阻尼开关
				camera_2d.position_smoothing_enabled = damping
	else:
		# 禁用跟随
		camera_2d.enabled = false
		_remove_follow_remote(target_2d)

	_log_info("设置相机跟随: %s → %s (模式: %s)" % [target_2d.name, camera_2d.name, FollowMode.keys()[follow_mode]])
	_on_execution_completed()


const _FOLLOW_REMOTE_NAME := "FuseCameraFollowRemote"

## 在 target 下创建 RemoteTransform2D，remote_path 指向 camera。
## Godot 每帧把 target 的 transform 同步给 camera，实现持续跟随。
func _setup_follow_remote(camera: Camera2D, target: Node2D) -> void:
	# 先移除旧的，保证幂等（重复执行不堆积）
	_remove_follow_remote(target)
	var remote := RemoteTransform2D.new()
	remote.name = _FOLLOW_REMOTE_NAME
	remote.update_position = true
	remote.update_rotation = false
	remote.update_scale = false
	target.add_child(remote)
	# add_child 后才能计算相对路径
	remote.remote_path = remote.get_path_to(camera)

## 移除 target 下的跟随用 RemoteTransform2D
func _remove_follow_remote(target: Node2D) -> void:
	if not is_instance_valid(target):
		return
	var existing := target.get_node_or_null(_FOLLOW_REMOTE_NAME)
	if existing is RemoteTransform2D:
		existing.queue_free()


## 从变量或节点路径解析节点
func _resolve_node(
	context: ExecutionContext,
	use_variable: bool,
	node_path: NodePath,
	variable_name: String,
	variable_scope: BaseVariable.VariableScope,
	scope_source: ScopeSource,
	custom_scope_id: String,
	target_node_path: NodePath,
	empty_variable_error_key: String,
	empty_node_error_key: String,
	not_found_error_key: String
) -> Node:
	if use_variable:
		if variable_name.is_empty():
			_log_error_localized(empty_variable_error_key, {})
			set_error_localized(empty_variable_error_key, FuseError.ErrorType.VALIDATION_ERROR, {})
			return null

		var node_value = VariableOperations.get_variable(
			context,
			variable_name,
			variable_scope,
			null
		)

		if node_value == null and not VariableOperations.has_variable(context, variable_name, variable_scope):
			_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": variable_name})
			set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"variable": variable_name})
			return null

		# 支持多种类型：Node、String（节点路径）、NodePath
		if node_value is Node:
			return node_value
		elif node_value is String or node_value is NodePath:
			var resolved_path = NodePath(node_value)
			var resolved_node = context.get_node(resolved_path)
			if not resolved_node:
				_log_error_localized(not_found_error_key, {"node": str(node_value)})
				set_error_localized(not_found_error_key, FuseError.ErrorType.RUNTIME_ERROR, {"node": str(node_value)})
				return null
			return resolved_node
		else:
			_log_error_localized("FUSE_ERROR_VAR_TYPE_NOT_NODE_OR_PATH", {"variable": variable_name, "actual_type": type_string(typeof(node_value))})
			set_error_localized("FUSE_ERROR_VAR_TYPE_NOT_NODE_OR_PATH", FuseError.ErrorType.VALIDATION_ERROR, {"variable": variable_name, "actual_type": type_string(typeof(node_value))})
			return null
	else:
		if node_path.is_empty():
			_log_error_localized(empty_node_error_key, {})
			set_error_localized(empty_node_error_key, FuseError.ErrorType.VALIDATION_ERROR, {})
			return null

		var resolved_node = context.get_node(node_path)
		if not resolved_node:
			_log_error_localized(not_found_error_key, {"node": str(node_path)})
			set_error_localized(not_found_error_key, FuseError.ErrorType.RUNTIME_ERROR, {"node": str(node_path)})
			return null
		return resolved_node

## 验证指令参数
func validate() -> Array[String]:
	var errors := super.validate()

	# 验证目标节点配置
	if use_variable_for_target:
		if target_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_VARIABLE_EMPTY"))

		if target_scope == BaseVariable.VariableScope.SCOPE:
			var utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				utils_scope_source,
				target_custom_scope_id,
				target_target_node_path
			))
	else:
		if target_node.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	# 验证相机节点配置
	if use_variable_for_camera:
		if camera_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_CAMERA_VARIABLE_EMPTY"))

		if camera_scope == BaseVariable.VariableScope.SCOPE:
			var utils_scope_source = camera_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				utils_scope_source,
				camera_custom_scope_id,
				camera_target_node_path
			))
	else:
		if camera_node.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_CAMERA_NODE_EMPTY"))

	# 验证 ScopeVariableManager（如果需要）
	if target_scope == BaseVariable.VariableScope.SCOPE or camera_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

	return errors

## 获取指令描述
func get_description() -> String:
	var mode_name: String = FollowMode.keys()[follow_mode]
	var state_key = "FUSE_CAMERA_FOLLOW_ENABLED" if enabled else "FUSE_CAMERA_FOLLOW_DISABLED"

	var target_desc := ""
	if use_variable_for_target:
		if target_variable.is_empty():
			target_desc = FuseLocalization.translate("FUSE_INSTRUCTION_CAMERA_FOLLOW_TARGET_VARIABLE_EMPTY")
		else:
			var scope_str = VariableScopeUtils.enum_to_string(target_scope).to_upper()
			target_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_CAMERA_FOLLOW_TARGET_VARIABLE", {
				"variable": "%s [%s]" % [target_variable, scope_str]
			})
	else:
		if target_node.is_empty():
			target_desc = FuseLocalization.translate("FUSE_INSTRUCTION_CAMERA_FOLLOW_NO_TARGET")
		else:
			target_desc = _get_node_display_name(target_node)

	var camera_desc := ""
	if use_variable_for_camera:
		if camera_variable.is_empty():
			camera_desc = FuseLocalization.translate("FUSE_INSTRUCTION_CAMERA_FOLLOW_CAMERA_VARIABLE_EMPTY")
		else:
			var scope_str = VariableScopeUtils.enum_to_string(camera_scope).to_upper()
			camera_desc = FuseLocalization.translate_format("FUSE_INSTRUCTION_CAMERA_FOLLOW_CAMERA_VARIABLE", {
				"variable": "%s [%s]" % [camera_variable, scope_str]
			})
	else:
		if camera_node.is_empty():
			camera_desc = FuseLocalization.translate("FUSE_INSTRUCTION_CAMERA_FOLLOW_NO_CAMERA")
		else:
			camera_desc = _get_node_display_name(camera_node)

	return FuseLocalization.translate_format("FUSE_INSTRUCTION_CAMERA_FOLLOW_DESC_FORMAT", {
		"target": target_desc,
		"camera": camera_desc,
		"state": FuseLocalization.translate(state_key),
		"mode": mode_name
	})
