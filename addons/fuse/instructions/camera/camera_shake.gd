@tool
@icon("res://addons/fuse/icons/builtin/CameraAttributesPractical.png")
extends BaseInstruction
class_name CameraShake


## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 触发相机抖动效果

# 抖动动画帧率（性能优化：30 FPS 足够产生流畅的抖动效果）
const SHAKE_FPS: int = 30

# Tween 引用（用于异步指令管理）
var _tween: Tween = null

func _init():
	# 🔧 关键修复：明确声明此指令是异步的
	# CameraShake 指令使用 Tween 回调机制而非 await，所以源码检测无法正确识别
	_is_synchronous_hint = false
	_sync_hint_manually_set = true

# 目标相机节点路径
var target_node: NodePath = NodePath("")

## 是否从变量获取相机节点
var use_variable_for_target: bool = false:
	set(value):
		use_variable_for_target = value
		_update_resource_name()
		notify_property_list_changed()

## 相机节点变量名
var target_variable: String = "":
	set(value):
		target_variable = value
		_update_resource_name()

## 相机节点变量作用域
var target_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		target_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 相机节点作用域来源（仅当 target_scope == SCOPE 时使用）
var target_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		target_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 相机节点自定义作用域 ID（CUSTOM_ID 模式使用）
var target_custom_scope_id: String = "":
	set(value):
		target_custom_scope_id = value
		_update_resource_name()

## 相机节点目标节点路径（TARGET_NODE 模式使用）
var target_target_node_path: NodePath = NodePath(""):
	set(value):
		target_target_node_path = value
		_update_resource_name()

# 抖动强度（0.0-1.0）
var intensity: float = 0.5:
	set(value_):
		intensity = clamp(value_, 0.0, 1.0)
		_update_resource_name()

# 抖动持续时间（秒）
var duration: float = 0.5:
	set(value_):
		duration = max(0.0, value_)
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_CAMERA_SHAKE_NAME"
	metadata.category_key = "FUSE_CATEGORY_CAMERA"
	metadata.description_key = "FUSE_INSTRUCTION_CAMERA_SHAKE_DESC"
	metadata.keywords = ["camera", "shake", "impact", "effect", "screen", "相机", "抖动", "震动", "效果"]
	metadata.builtin_icon = "CameraAttributesPractical"
	return metadata

func _setup_metadata():
	pass

## 声明变量读写模式
func get_variable_modes() -> Array[Dictionary]:
	var modes: Array[Dictionary] = []
	if use_variable_for_target:
		modes.append({"name": "target_variable", "mode": "read"})
	return modes


## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		name = "Camera Shake",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})


	# 是否从变量获取相机节点
	properties.append({
		name = "use_variable_for_target",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if not use_variable_for_target:
		# 直接指定节点路径
		properties.append({
			name = "target_node",
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			hint_string = "Camera2D",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		# 从变量获取节点
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

	properties.append({
		name = "intensity",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.0,1.0,0.1",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "duration",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.0,5.0,0.1",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts := []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_CAMERA_SHAKE_BASE_NAME"))
	parts.append(FuseLocalization.translate_format("FUSE_CAMERA_SHAKE_PARAMS", {
		"intensity": "%.1f" % intensity,
		"duration": "%.1f" % duration
	}))

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 获取目标节点
	var camera := _resolve_node(
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
	if not camera:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	# 验证节点类型
	if not camera is Camera2D:
		_log_error_localized("FUSE_ERROR_CAMERA_NOT_CAMERA2D", {})
		set_error_localized("FUSE_ERROR_CAMERA_NOT_CAMERA2D", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	var camera_2d := camera as Camera2D

	# 验证持续时间
	if duration <= 0.0:
		_log_error_localized("FUSE_ERROR_SHAKE_DURATION_INVALID", {})
		set_error_localized("FUSE_ERROR_SHAKE_DURATION_INVALID", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 执行抖动
	_execute_shake(camera_2d)

## 执行相机抖动
func _execute_shake(camera: Camera2D):
	# 获取 SceneTree
	var scene_tree := Engine.get_main_loop()
	if not scene_tree:
		_log_error_localized("FUSE_ERROR_CANNOT_GET_SCENETREE", {})
		set_error_localized("FUSE_ERROR_CANNOT_GET_SCENETREE", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 保存原始偏移
	var original_offset := camera.offset

	# 创建 Tween 并保存引用
	_tween = scene_tree.create_tween()
	if not _tween:
		_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", {})
		set_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 创建抖动动画（随机偏移）
	var shake_count := int(duration * SHAKE_FPS)  # 30 FPS，性能优化
	for i in shake_count:
		var random_offset := Vector2(
			randf_range(-intensity * 20, intensity * 20),
			randf_range(-intensity * 20, intensity * 20)
		)

		var frame_time := 1.0 / SHAKE_FPS
		_tween.tween_property(camera, "offset", random_offset, frame_time)
		_tween.tween_property(camera, "offset", original_offset, frame_time)

	# 在 Tween 完成时发出 finished 信号
	_tween.finished.connect(_on_shake_completed.bind(camera, original_offset), CONNECT_ONE_SHOT)

	_log_info("相机抖动开始 (强度: %.1f, 时间: %.1f秒)" % [intensity, duration])

## 抖动完成回调
func _on_shake_completed(camera: Camera2D, original_offset: Vector2):
	# 使用 is_instance_valid 检查对象是否仍然有效
	if not is_instance_valid(camera):
		_log_warning("相机对象已在抖动过程中被销毁，跳过恢复偏移")
		finished.emit()
		return

	# 检查相机是否在场景树中
	if not camera.is_inside_tree():
		_log_warning("相机已从场景树中移除")
		finished.emit()
		return

	camera.offset = original_offset
	_log_info("相机抖动完成")
	finished.emit()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()
	# 验证 相机节点
	if use_variable_for_target:
		if target_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_VARIABLE_EMPTY"))
		if target_scope == BaseVariable.VariableScope.SCOPE:
			var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				target_utils_scope_source,
				target_custom_scope_id,
				target_target_node_path
			))
	else:
		if target_node.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))


	if duration <= 0.0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_DURATION_MUST_BE_POSITIVE"))

	return errors

## 取消指令执行
func cancel():
	if _tween and is_instance_valid(_tween):
		_tween.kill()
		_tween = null
	super.cancel()

## 清理资源
func _cleanup_resources():
	super._cleanup_resources()
	if _tween and is_instance_valid(_tween):
		_tween.kill()
		_tween = null

## 属性验证
func _validate_property(property: Dictionary) -> void:
	# 控制相机节点相关属性可见性
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
## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property in ["use_variable_for_target", "target_scope", "target_scope_source"]:
		set(property, value)
		notify_property_list_changed()
		return true
	return false
## 获取指令描述
func get_description() -> String:
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_CAMERA_SHAKE_DESC_FORMAT", {
		"intensity": "%.1f" % intensity,
		"duration": "%.1f" % duration
	})

## ============================================================
## 运行时实例模式支持（RuntimeInstructionInstance 架构）
## ============================================================

## 获取默认运行时状态
##
## 声明 CameraShake 指令需要的运行时状态。
## 这些状态会在 RuntimeInstructionInstance 初始化时被复制。
func get_default_runtime_state() -> Dictionary:
	var state = super.get_default_runtime_state()
	state["tween"] = null  # Tween 引用（每个 RuntimeInstance 有自己的 tween）
	state["camera"] = null  # Camera2D 引用
	state["original_offset"] = Vector2.ZERO  # 原始偏移
	state["is_running"] = false  # 运行状态
	state["tween_callback"] = null  # 完成回调引用（用于断开连接）
	return state

## 使用运行时实例执行（推荐模式）
##
## 这种模式下，所有状态存储在 runtime_instance.runtime_state 中，
## 确保多个执行实例互不干扰。
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
	_start_execution(runtime_instance.execution_context)

	# 获取目标节点
	var camera := _resolve_node(
		runtime_instance.execution_context,
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
	if not camera:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		runtime_instance._complete_execution()
		return true

	# 验证节点类型
	if not camera is Camera2D:
		_log_error_localized("FUSE_ERROR_CAMERA_NOT_CAMERA2D", {})
		set_error_localized("FUSE_ERROR_CAMERA_NOT_CAMERA2D", FuseError.ErrorType.RUNTIME_ERROR, {})
		runtime_instance._complete_execution()
		return true

	var camera_2d := camera as Camera2D

	# 验证持续时间
	if duration <= 0.0:
		_log_error_localized("FUSE_ERROR_SHAKE_DURATION_INVALID", {})
		set_error_localized("FUSE_ERROR_SHAKE_DURATION_INVALID", FuseError.ErrorType.VALIDATION_ERROR, {})
		runtime_instance._complete_execution()
		return true

	# 执行抖动
	_execute_shake_runtime(runtime_instance, camera_2d)
	return false  # 异步执行

## 执行相机抖动（运行时实例版本）
func _execute_shake_runtime(runtime_instance: RuntimeInstructionInstance, camera: Camera2D) -> void:
	var state = runtime_instance.runtime_state

	# 获取 SceneTree
	var scene_tree := Engine.get_main_loop()
	if not scene_tree:
		_log_error_localized("FUSE_ERROR_CANNOT_GET_SCENETREE", {})
		set_error_localized("FUSE_ERROR_CANNOT_GET_SCENETREE", FuseError.ErrorType.RUNTIME_ERROR, {})
		runtime_instance._complete_execution()
		return

	# 保存原始偏移和相机引用到运行时状态
	state["original_offset"] = camera.offset
	state["camera"] = camera

	# 创建 Tween 并保存引用
	var tween = scene_tree.create_tween()
	if not tween:
		_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", {})
		set_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", FuseError.ErrorType.RUNTIME_ERROR, {})
		runtime_instance._complete_execution()
		return

	state["tween"] = tween
	state["is_running"] = true

	# 创建抖动动画（随机偏移）
	var shake_count := int(duration * SHAKE_FPS)  # 30 FPS，性能优化
	for i in shake_count:
		var random_offset := Vector2(
			randf_range(-intensity * 20, intensity * 20),
			randf_range(-intensity * 20, intensity * 20)
		)

		var frame_time := 1.0 / SHAKE_FPS
		tween.tween_property(camera, "offset", random_offset, frame_time)
		tween.tween_property(camera, "offset", state["original_offset"], frame_time)

	# 创建完成回调并存储引用
	var callback = _create_tween_callback(runtime_instance)
	tween.finished.connect(callback, CONNECT_ONE_SHOT)
	state["tween_callback"] = callback
	runtime_instance.register_timer_callback(callback)

	_log_info("相机抖动开始 (强度: %.1f, 时间: %.1f秒)" % [intensity, duration])

## 创建 Tween 完成回调（避免 bind）
func _create_tween_callback(runtime_instance: RuntimeInstructionInstance) -> Callable:
	var callback = func():
		_on_shake_completed_runtime(runtime_instance)
	return callback

## 抖动完成回调（运行时实例版本）
func _on_shake_completed_runtime(runtime_instance: RuntimeInstructionInstance) -> void:
	# 检查实例是否仍然有效
	if not runtime_instance or runtime_instance.is_completed():
		return

	var state = runtime_instance.runtime_state
	var camera = state.get("camera")
	var original_offset = state.get("original_offset", Vector2.ZERO)

	# 使用 is_instance_valid 检查对象是否仍然有效
	if not is_instance_valid(camera):
		_log_warning("相机对象已在抖动过程中被销毁，跳过恢复偏移")
		runtime_instance._complete_execution()
		return

	# 检查相机是否在场景树中
	if not camera.is_inside_tree():
		_log_warning("相机已从场景树中移除")
		runtime_instance._complete_execution()
		return

	camera.offset = original_offset
	_log_info("相机抖动完成")

	# 清理运行时状态
	state["tween"] = null
	state["camera"] = null
	state["is_running"] = false
	state["tween_callback"] = null

	# 标记完成
	runtime_instance._complete_execution()

## 暂停处理
##
## 当运行时实例被暂停时，暂停 Tween 动画
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var tween = state.get("tween")

	if tween and is_instance_valid(tween):
		tween.pause()
		state["is_running"] = false
		_log_debug("相机抖动已暂停")

## 恢复处理
##
## 当运行时实例被恢复时，恢复 Tween 动画
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var tween = state.get("tween")

	if tween and is_instance_valid(tween):
		tween.play()
		state["is_running"] = true
		_log_debug("相机抖动已恢复")

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
			_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"name": variable_name})
			set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"name": variable_name})
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

