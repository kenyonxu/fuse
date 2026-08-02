@tool
@icon("res://addons/fuse/icons/builtin/MoveRight.png")
extends BaseTweenInstruction
class_name TweenMoveTo

## Tween Move To 指令 - 平滑移动节点（相对移动，支持全局/局部坐标空间）

# 坐标空间枚举
enum SpaceMode {
	GLOBAL,
	LOCAL
}

# 参数配置
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()
		notify_property_list_changed()

var target_position: Vector2 = Vector2.ZERO:
	set(value):
		target_position = value
		_update_resource_name()

var duration: float = 0.5:
	set(value):
		duration = value
		_update_resource_name()

var space_mode: SpaceMode = SpaceMode.GLOBAL:
	set(value):
		space_mode = value
		_update_resource_name()
		notify_property_list_changed()

var easing_type: EasingType = EasingType.EASE_IN_OUT:
	set(value):
		easing_type = value
		_update_resource_name()

var trans_type: TransitionType = TransitionType.SINE:
	set(value):
		trans_type = value
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_TWEEN_MOVE_TO_NAME"
	metadata.category_key = "FUSE_CATEGORY_TWEEN"
	metadata.description_key = "FUSE_INSTRUCTION_TWEEN_MOVE_TO_DESC"
	metadata.keywords = ["tween", "move", "position", "移动", "位置", "动画"]
	metadata.builtin_icon = "MoveRight"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# 基础参数分类
	properties.append({
		name = "Tween Move To",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 目标节点
	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 目标位置
	properties.append({
		name = "target_position",
		type = TYPE_VECTOR2,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 持续时间
	properties.append({
		name = "duration",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,10,0.1,or_greater",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 坐标空间
	properties.append({
		name = "space_mode",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Global,Local",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 缓动类型
	properties.append({
		name = "easing_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "In,Out,InOut,OutIn",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 过渡类型
	properties.append({
		name = "trans_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Linear,Sine,Quad,Cubic,Quart,Quint,Expo,Circ,Back,Spring,Bounce,Elastic",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称（必需）
func _update_resource_name():
	var parts = []
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_TWEEN_MOVE_TO_NAME"))

	if not target_node.is_empty():
		parts.append("[%s]" % _get_node_display_name(target_node))
	else:
		parts.append("[%s]" % FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED"))

	parts.append(str(target_position))
	var space_key = "FUSE_SPACE_GLOBAL" if space_mode == SpaceMode.GLOBAL else "FUSE_SPACE_LOCAL"
	parts.append("(%s)" % FuseLocalization.translate(space_key))
	parts.append("(%.2fs)" % duration)

	resource_name = " ".join(parts)

## 获取指令描述（必需）
func get_description() -> String:
	var target_desc = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
	var space_key = "FUSE_SPACE_GLOBAL" if space_mode == SpaceMode.GLOBAL else "FUSE_SPACE_LOCAL"
	var space_desc = FuseLocalization.translate(space_key)
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_TWEEN_MOVE_TO_DESC_FORMAT", {
		"target": target_desc,
		"position": str(target_position),
		"space": space_desc
	})

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	# 验证目标节点
	if target_node.is_empty():
		_log_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", {})
		set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取目标节点
	var target = _get_target_node(context, target_node)
	if target == null:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	# 验证节点有 position 属性
	if not "position" in target:
		_log_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", {"node": target.name, "expected": "Node2D or Node3D"})
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.VALIDATION_ERROR, {"node": target.name, "expected": "Node2D or Node3D"})
		finished.emit()
		return

	# 创建 Tween
	var tween = _create_tween(target)
	if tween == null:
		_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", {})
		set_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 应用缓动设置
	_apply_easing_settings(tween, easing_type, trans_type)

	# 获取当前位置并计算相对移动的目标位置
	var current_position: Vector2
	var final_position: Vector2

	if space_mode == SpaceMode.GLOBAL:
		# 获取当前世界坐标
		if target is Node2D:
			current_position = target.global_position
		elif target.has_method("get_global_position"):
			current_position = target.get_global_position()
		else:
			current_position = target.position
		# 计算相对偏移后的目标位置
		final_position = current_position + target_position
	else:
		# 获取当前本地坐标
		current_position = target.position
		# 计算相对偏移后的目标位置
		final_position = current_position + target_position

	# 根据坐标空间选择属性
	var property_name = "global_position" if space_mode == SpaceMode.GLOBAL else "position"

	# 播放移动动画到相对偏移后的位置
	tween.tween_property(target, property_name, final_position, duration)

	_log_info_localized("FUSE_LOG_TWEEN_MOVE_TO", {
		"node": target.name,
		"position": str(final_position),
		"from": str(current_position),
		"offset": str(target_position),
		"space": "global" if space_mode == SpaceMode.GLOBAL else "local",
		"duration": str(duration)
	})

	# 等待动画完成
	await tween.finished
	_on_execution_completed()

## 验证参数（必需）
func validate() -> Array[String]:
	var errors = super.validate()

	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	if duration <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_DURATION_MUST_BE_POSITIVE"))

	return errors

## ============================================================
## 运行时实例模式支持（RuntimeInstructionInstance 架构）
## ============================================================

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var state = super.get_default_runtime_state()
	state["tween"] = null
	state["target_instance"] = null
	state["tween_callback"] = null
	state["is_running"] = false
	return state

## 使用运行时实例执行
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
	_start_execution(runtime_instance.execution_context)

	var state = runtime_instance.runtime_state

	# 验证目标节点
	if target_node.is_empty():
		_log_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", {})
		set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		runtime_instance._complete_execution()
		return true

	# 获取目标节点
	var target = _get_target_node(runtime_instance.execution_context, target_node)
	if target == null:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		runtime_instance._complete_execution()
		return true

	# 验证节点有 position 属性
	if not "position" in target:
		_log_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", {"node": target.name, "expected": "Node2D or Node3D"})
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.VALIDATION_ERROR, {"node": target.name, "expected": "Node2D or Node3D"})
		runtime_instance._complete_execution()
		return true

	state["target_instance"] = target

	# 创建 Tween
	var tween = _create_tween(target)
	if tween == null:
		_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", {})
		set_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", FuseError.ErrorType.RUNTIME_ERROR, {})
		runtime_instance._complete_execution()
		return true

	state["tween"] = tween
	state["is_running"] = true

	# 应用缓动设置
	_apply_easing_settings(tween, easing_type, trans_type)

	# 获取当前位置并计算相对移动的目标位置
	var current_position: Vector2
	var final_position: Vector2

	if space_mode == SpaceMode.GLOBAL:
		if target is Node2D:
			current_position = target.global_position
		elif target.has_method("get_global_position"):
			current_position = target.get_global_position()
		else:
			current_position = target.position
		final_position = current_position + target_position
	else:
		current_position = target.position
		final_position = current_position + target_position

	# 根据坐标空间选择属性
	var property_name = "global_position" if space_mode == SpaceMode.GLOBAL else "position"

	# 播放移动动画
	tween.tween_property(target, property_name, final_position, duration)

	_log_info_localized("FUSE_LOG_TWEEN_MOVE_TO", {
		"node": target.name,
		"position": str(final_position),
		"from": str(current_position),
		"offset": str(target_position),
		"space": "global" if space_mode == SpaceMode.GLOBAL else "local",
		"duration": str(duration)
	})

	# 使用回调注册机制
	var callback = _create_tween_callback(runtime_instance)
	tween.finished.connect(callback, CONNECT_ONE_SHOT)
	runtime_instance.register_timer_callback(callback)
	state["tween_callback"] = callback

	return false

## 创建 Tween 完成回调
func _create_tween_callback(runtime_instance: RuntimeInstructionInstance) -> Callable:
	var callback = func():
		_on_runtime_tween_finished(runtime_instance)
	return callback

## Tween 完成回调
func _on_runtime_tween_finished(runtime_instance: RuntimeInstructionInstance) -> void:
	if not runtime_instance or runtime_instance.is_completed():
		return

	var state = runtime_instance.runtime_state
	state["tween"] = null
	state["target_instance"] = null
	state["is_running"] = false
	state["tween_callback"] = null

	runtime_instance._complete_execution()

## 暂停处理
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var tween = state.get("tween")

	if tween and is_instance_valid(tween):
		tween.pause()
		state["is_running"] = false

## 恢复处理
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var tween = state.get("tween")

	if tween and is_instance_valid(tween):
		tween.play()
		state["is_running"] = true
