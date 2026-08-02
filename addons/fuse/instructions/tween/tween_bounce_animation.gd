@tool
@icon("res://addons/fuse/icons/builtin/AudioStreamGenerator.png")
extends BaseTweenInstruction
class_name TweenBounceAnimation

## Tween Bounce Animation 指令 - 弹跳效果（掉落后反弹）

# 参数配置
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()
		notify_property_list_changed()

var bounce_height: float = 50.0:
	set(value):
		bounce_height = value
		_update_resource_name()

var bounce_count: int = 3:
	set(value):
		bounce_count = value
		_update_resource_name()
		notify_property_list_changed()

var duration: float = 0.5:
	set(value):
		duration = value
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_TWEEN_BOUNCE_ANIMATION_NAME"
	metadata.category_key = "FUSE_CATEGORY_TWEEN"
	metadata.description_key = "FUSE_INSTRUCTION_TWEEN_BOUNCE_ANIMATION_DESC"
	metadata.keywords = ["tween", "bounce", "弹跳", "掉落"]
	metadata.builtin_icon = "AudioStreamGenerator"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# 基础参数分类
	properties.append({
		name = "Tween Bounce Animation",
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

	# 弹跳高度
	properties.append({
		name = "bounce_height",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,500,10,or_greater",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 弹跳次数
	properties.append({
		name = "bounce_count",
		type = TYPE_INT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "1,10,1",
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

	return properties

## 更新资源名称（必需）
func _update_resource_name():
	var parts = []
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_TWEEN_BOUNCE_ANIMATION_NAME"))

	if not target_node.is_empty():
		parts.append("[%s]" % _get_node_display_name(target_node))
	else:
		parts.append("[%s]" % FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED"))

	parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_TWEEN_BOUNCE_ANIMATION_HEIGHT", {"height": bounce_height}))
	parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_TWEEN_BOUNCE_ANIMATION_COUNT", {"count": bounce_count}))
	parts.append("(%.2fs)" % duration)

	resource_name = " ".join(parts)

## 获取指令描述（必需）
func get_description() -> String:
	var target_desc = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_TWEEN_BOUNCE_ANIMATION_DESC_FORMAT", {
		"target": target_desc,
		"height": bounce_height,
		"count": bounce_count
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
		_log_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", {"node": target.name, "expected": "Node2D or Node3D or Control"})
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.VALIDATION_ERROR, {"node": target.name, "expected": "Node2D or Node3D or Control"})
		finished.emit()
		return

	# 保存原始位置
	var original_position: Vector2 = target.position if target is Node2D or target is Control else Vector2(target.position.x, target.position.y)

	# 创建 Tween
	var tween = _create_tween(target)
	if tween == null:
		_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", {})
		set_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 设置弹跳效果
	tween.set_trans(Tween.TransitionType.TRANS_BOUNCE)
	tween.set_ease(Tween.EaseType.EASE_OUT)

	# 播放弹跳动画（向上弹起）
	if target is Node2D or target is Control:
		tween.tween_property(target, "position:y", original_position.y - bounce_height, duration)
	else:
		# Node3D 使用 position.y（3D 坐标系）
		tween.tween_property(target, "position:y", original_position.y - bounce_height, duration)

	_log_info_localized("FUSE_LOG_TWEEN_BOUNCE_ANIMATION", {
		"node": target.name,
		"height": str(bounce_height),
		"count": str(bounce_count)
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

	if bounce_height <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_BOUNCE_HEIGHT_MUST_BE_POSITIVE"))

	if bounce_count < 1:
		errors.append(FuseLocalization.translate("FUSE_ERROR_BOUNCE_COUNT_AT_LEAST_ONE"))

	return errors

## ============================================================
## 运行时实例模式支持（RuntimeInstructionInstance 架构）
## ============================================================

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var state = super.get_default_runtime_state()
	state["tween"] = null
	state["target_instance"] = null
	state["original_position"] = Vector2.ZERO
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
		_log_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", {"node": target.name, "expected": "Node2D or Node3D or Control"})
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.VALIDATION_ERROR, {"node": target.name, "expected": "Node2D or Node3D or Control"})
		runtime_instance._complete_execution()
		return true

	state["target_instance"] = target

	# 保存原始位置
	var original_position: Vector2
	if target is Node2D or target is Control:
		original_position = target.position
	else:
		original_position = Vector2(target.position.x, target.position.y)
	state["original_position"] = original_position

	# 创建 Tween
	var tween = _create_tween(target)
	if tween == null:
		_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", {})
		set_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", FuseError.ErrorType.RUNTIME_ERROR, {})
		runtime_instance._complete_execution()
		return true

	state["tween"] = tween
	state["is_running"] = true

	# 设置弹跳效果
	tween.set_trans(Tween.TransitionType.TRANS_BOUNCE)
	tween.set_ease(Tween.EaseType.EASE_OUT)

	# 播放弹跳动画（向上弹起）
	if target is Node2D or target is Control:
		tween.tween_property(target, "position:y", original_position.y - bounce_height, duration)
	else:
		tween.tween_property(target, "position:y", original_position.y - bounce_height, duration)

	_log_info_localized("FUSE_LOG_TWEEN_BOUNCE_ANIMATION", {
		"node": target.name,
		"height": str(bounce_height),
		"count": str(bounce_count)
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
