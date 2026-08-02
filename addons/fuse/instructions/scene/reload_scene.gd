@tool
@icon("res://addons/fuse/icons/builtin/Reload.png")
extends BaseInstruction
class_name ReloadScene

## 重新加载当前场景

# 延迟时间（秒）
var delay: float = 0.0

# 定时器
var _timer: SceneTreeTimer = null

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_RELOAD_SCENE_NAME"
	metadata.category_key = "FUSE_CATEGORY_SCENE"
	metadata.description_key = "FUSE_INSTRUCTION_RELOAD_SCENE_DESC"
	metadata.keywords = ["reload", "restart", "reset", "scene", "重载", "重新加载", "重启", "场景"]
	metadata.builtin_icon = "Reload"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Delay 分类
	properties.append({
		name = "Delay",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 延迟时间
	properties.append({
		name = "delay",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,3600,0.1,or_greater",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_RELOAD_SCENE_BASE"))

	if delay > 0:
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_RELOAD_SCENE_DELAY", {"delay": delay}))

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 获取 SceneTree
	var scene_tree = Engine.get_main_loop()
	if not scene_tree:
		_log_error_localized("FUSE_ERROR_CANNOT_RELOAD_SCENE", {})
		set_error_localized("FUSE_ERROR_CANNOT_RELOAD_SCENE", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 验证延迟时间
	if delay < 0:
		_log_error_localized("FUSE_ERROR_INVALID_DURATION", {})
		set_error_localized("FUSE_ERROR_INVALID_DURATION", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	if delay > 0:
		_log_info_localized("FUSE_LOG_RELOAD_SCENE_DELAYED", {"delay": delay})
		_timer = scene_tree.create_timer(delay)
		_timer.timeout.connect(_on_reload_timeout)
		# 不调用 _on_execution_completed()，等待定时器
	else:
		_log_info_localized("FUSE_LOG_RELOAD_SCENE_IMMEDIATE", {})
		_cleanup_resources()  # 清理资源（保持一致性）
		scene_tree.reload_current_scene()
		# 重载场景会销毁所有节点，直接发出完成信号
		finished.emit()

## 延迟重载回调
func _on_reload_timeout():
	_log_info_localized("FUSE_LOG_RELOAD_SCENE_EXECUTING", {})

	var scene_tree = Engine.get_main_loop()
	if scene_tree:
		scene_tree.reload_current_scene()
	# 重载场景会销毁所有节点，直接发出完成信号
	finished.emit()

## 清理资源
func _cleanup_resources() -> void:
	if _timer and is_instance_valid(_timer):
		if _timer.timeout.is_connected(_on_reload_timeout):
			_timer.timeout.disconnect(_on_reload_timeout)
		_timer = null

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if delay < 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_DELAY_NEGATIVE"))

	return errors

## 获取指令描述
func get_description() -> String:
	if delay > 0:
		return FuseLocalization.translate_format("FUSE_INSTRUCTION_RELOAD_SCENE_DESC_DELAYED", {"delay": delay})
	else:
		return FuseLocalization.translate("FUSE_INSTRUCTION_RELOAD_SCENE_DESC_IMMEDIATE")
