@tool
@icon("res://addons/fuse/icons/builtin/Performance.png")
extends BaseInstruction
class_name SetTimeScale

## 设置游戏时间缩放（慢动作/快进）

# 时间缩放值（1.0 = 正常，0.5 = 慢动作，2.0 = 快进）
var time_scale: float = 1.0

# 持续时间（秒，0 = 永久）
var duration: float = 0.0

# 定时器
var _timer: SceneTreeTimer = null

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_TIME_SCALE_NAME"
	metadata.category_key = "FUSE_CATEGORY_TIME"
	metadata.description_key = "FUSE_INSTRUCTION_SET_TIME_SCALE_DESC"
	metadata.keywords = ["time", "scale", "slow", "fast", "时间", "缩放", "慢动作", "快进"]
	metadata.builtin_icon = "Performance"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Time Scale 分类
	properties.append({
		name = "Time Scale",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 时间缩放值
	properties.append({
		name = "time_scale",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.01,10,0.01,or_greater",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Duration 分类
	properties.append({
		name = "Duration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 持续时间
	properties.append({
		name = "duration",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,3600,0.1,or_greater",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_TIME_SCALE_RESOURCE"))

	parts.append("%.2fx" % time_scale)

	if duration > 0:
		parts.append("(%s)" % FuseLocalization.translate_format("FUSE_TIME_SCALE_RECOVER_AFTER", {"duration": "%.1f" % duration}))
	else:
		parts.append("(%s)" % FuseLocalization.translate("FUSE_TIME_SCALE_PERMANENT"))

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证时间缩放值
	if time_scale <= 0:
		_log_error_localized("FUSE_ERROR_INVALID_TIME_SCALE", {})
		set_error_localized("FUSE_ERROR_INVALID_TIME_SCALE", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 验证持续时间
	if duration < 0:
		_log_error_localized("FUSE_ERROR_INVALID_DURATION", {})
		set_error_localized("FUSE_ERROR_INVALID_DURATION", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 捕获原始时间缩放值（使用局部变量，避免多实例冲突）
	var original_scale = Engine.time_scale

	# 设置时间缩放
	Engine.time_scale = time_scale

	if duration > 0:
		_log_info_localized("FUSE_LOG_TIME_SCALE_SET_TEMPORARY", {"scale": "%.2f" % time_scale, "duration": "%.1f" % duration, "original": "%.2f" % original_scale})
	else:
		_log_info_localized("FUSE_LOG_TIME_SCALE_SET_PERMANENT", {"scale": "%.2f" % time_scale})

	# 如果有持续时间，创建定时器
	if duration > 0:
		var scene_tree = Engine.get_main_loop()
		if not scene_tree:
			_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TIMER", {})
			finished.emit()
			return

		_timer = scene_tree.create_timer(duration)
		# 使用闭包捕获 original_scale，避免多实例冲突
		_timer.timeout.connect(_on_timer_timeout.bind(original_scale))
		# 不调用 _on_execution_completed()，等待定时器
	else:
		_on_execution_completed()

## 定时器超时回调（接收捕获的原始缩放值）
func _on_timer_timeout(original_scale: float):
	# 恢复原始时间缩放
	Engine.time_scale = original_scale
	_log_info_localized("FUSE_LOG_TIME_SCALE_RESTORED", {"scale": "%.2f" % original_scale})

	_cleanup_resources()
	finished.emit()

## 清理资源
func _cleanup_resources() -> void:
	if _timer and is_instance_valid(_timer):
		if _timer.timeout.is_connected(_on_timer_timeout):
			_timer.timeout.disconnect(_on_timer_timeout)
		_timer = null

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if time_scale <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_TIME_SCALE_MUST_BE_POSITIVE"))

	if duration < 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_DURATION_MUST_BE_POSITIVE"))

	return errors

## 获取指令描述
func get_description() -> String:
	var duration_str = ""
	if duration > 0:
		duration_str = " (%s)" % FuseLocalization.translate_format("FUSE_TIME_SCALE_RECOVER_AFTER", {"duration": "%.1f" % duration})

	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_TIME_SCALE_DESC_FORMAT", {"scale": "%.2f" % time_scale, "duration": duration_str})
