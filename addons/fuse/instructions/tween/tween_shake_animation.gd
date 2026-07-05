@tool
@icon("res://addons/fuse/icons/builtin/GuiTreeUpdown.png")
extends BaseTweenInstruction
class_name TweenShakeAnimation

## Tween Shake Animation 指令 - 震动效果

## 震动轴向枚举
enum ShakeAxis {
	X,
	Y,
	XY
}

# 参数配置
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()
		notify_property_list_changed()

var intensity: float = 10.0:
	set(value):
		intensity = value
		_update_resource_name()

var duration: float = 0.3:
	set(value):
		duration = value
		_update_resource_name()

var shake_count: int = 3:
	set(value):
		shake_count = value
		_update_resource_name()
		notify_property_list_changed()

var shake_axis: ShakeAxis = ShakeAxis.XY:
	set(value):
		shake_axis = value
		_update_resource_name()
		notify_property_list_changed()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_TWEEN_SHAKE_ANIMATION_NAME"
	metadata.category_key = "FUSE_CATEGORY_TWEEN"
	metadata.description_key = "FUSE_INSTRUCTION_TWEEN_SHAKE_ANIMATION_DESC"
	metadata.keywords = ["tween", "shake", "震动", "抖动"]
	metadata.builtin_icon = "GuiTreeUpdown"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# 基础参数分类
	properties.append({
		name = "Tween Shake Animation",
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

	# 震动强度
	properties.append({
		name = "intensity",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,100,1,or_greater",
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

	# 震动次数
	properties.append({
		name = "shake_count",
		type = TYPE_INT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "1,20,1",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 震动轴向
	properties.append({
		name = "shake_axis",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "X,Y,XY",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称（必需）
func _update_resource_name():
	var parts = []
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_TWEEN_SHAKE_ANIMATION_NAME"))

	if not target_node.is_empty():
		parts.append("[%s]" % _get_node_display_name(target_node))
	else:
		parts.append("[%s]" % FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED"))

	parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_TWEEN_SHAKE_ANIMATION_INTENSITY", {"intensity": intensity}))
	parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_TWEEN_SHAKE_ANIMATION_COUNT", {"count": shake_count}))
	var axis_key = "FUSE_AXIS_X" if shake_axis == ShakeAxis.X else "FUSE_AXIS_Y" if shake_axis == ShakeAxis.Y else "FUSE_AXIS_XY"
	parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_TWEEN_SHAKE_ANIMATION_AXIS", {"axis": FuseLocalization.translate(axis_key)}))
	parts.append("(%.2fs)" % duration)

	resource_name = " ".join(parts)

## 获取指令描述（必需）
func get_description() -> String:
	var target_desc = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
	var axis_key = "FUSE_AXIS_X" if shake_axis == ShakeAxis.X else "FUSE_AXIS_Y" if shake_axis == ShakeAxis.Y else "FUSE_AXIS_XY"
	var axis_desc = FuseLocalization.translate(axis_key)
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_TWEEN_SHAKE_ANIMATION_DESC_FORMAT", {
		"target": target_desc,
		"intensity": intensity,
		"count": shake_count,
		"axis": axis_desc
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

	# 创建 Tween
	var tween = _create_tween(target)
	if tween == null:
		_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", {})
		set_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 设置震动参数
	tween.set_loops(shake_count)
	tween.set_parallel(true)

	# 根据轴向选择震动方向
	match shake_axis:
		ShakeAxis.X:
			tween.tween_property(target, "position:x", intensity, duration * 0.25).as_relative()
			tween.tween_property(target, "position:x", -intensity, duration * 0.25).as_relative()
			tween.tween_property(target, "position:x", 0, duration * 0.25).as_relative()
		ShakeAxis.Y:
			tween.tween_property(target, "position:y", intensity, duration * 0.25).as_relative()
			tween.tween_property(target, "position:y", -intensity, duration * 0.25).as_relative()
			tween.tween_property(target, "position:y", 0, duration * 0.25).as_relative()
		ShakeAxis.XY:
			tween.tween_property(target, "position", Vector2(intensity, intensity), duration * 0.25).as_relative()
			tween.tween_property(target, "position", Vector2(-intensity, -intensity), duration * 0.25).as_relative()
			tween.tween_property(target, "position", Vector2.ZERO, duration * 0.25).as_relative()

	_log_info_localized("FUSE_LOG_TWEEN_SHAKE_ANIMATION", {
		"node": target.name,
		"intensity": str(intensity),
		"count": str(shake_count),
		"axis": "X" if shake_axis == ShakeAxis.X else "Y" if shake_axis == ShakeAxis.Y else "XY"
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

	if shake_count < 1:
		errors.append(FuseLocalization.translate("FUSE_ERROR_SHAKE_COUNT_AT_LEAST_ONE"))

	if intensity <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_SHAKE_INTENSITY_POSITIVE"))

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
		_log_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", {"node": target.name, "expected": "Node2D or Node3D or Control"})
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.VALIDATION_ERROR, {"node": target.name, "expected": "Node2D or Node3D or Control"})
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

	# 设置震动参数
	tween.set_loops(shake_count)
	tween.set_parallel(true)

	# 根据轴向选择震动方向
	match shake_axis:
		ShakeAxis.X:
			tween.tween_property(target, "position:x", intensity, duration * 0.25).as_relative()
			tween.tween_property(target, "position:x", -intensity, duration * 0.25).as_relative()
			tween.tween_property(target, "position:x", 0, duration * 0.25).as_relative()
		ShakeAxis.Y:
			tween.tween_property(target, "position:y", intensity, duration * 0.25).as_relative()
			tween.tween_property(target, "position:y", -intensity, duration * 0.25).as_relative()
			tween.tween_property(target, "position:y", 0, duration * 0.25).as_relative()
		ShakeAxis.XY:
			tween.tween_property(target, "position", Vector2(intensity, intensity), duration * 0.25).as_relative()
			tween.tween_property(target, "position", Vector2(-intensity, -intensity), duration * 0.25).as_relative()
			tween.tween_property(target, "position", Vector2.ZERO, duration * 0.25).as_relative()

	_log_info_localized("FUSE_LOG_TWEEN_SHAKE_ANIMATION", {
		"node": target.name,
		"intensity": str(intensity),
		"count": str(shake_count),
		"axis": "X" if shake_axis == ShakeAxis.X else "Y" if shake_axis == ShakeAxis.Y else "XY"
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
