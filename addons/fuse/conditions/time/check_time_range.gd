@tool
@icon("res://addons/fuse/icons/builtin/Time.png")
extends BaseCondition
class_name CheckTimeRange

## 时间段内条件
##
## 检查当前时间是否在指定范围内。

## 开始时间（秒）
@export_group("Time Range Check")
@export var start_time: float = 0.0:
	set(value):
		start_time = value
		_update_resource_name()

## 结束时间（秒）
@export var end_time: float = 1.0:
	set(value):
		end_time = value
		_update_resource_name()

## 更新资源名称（必需）
func _update_resource_name() -> void:
	resource_name = FuseLocalization.translate_format(
		"FUSE_CONDITION_TIME_RANGE_FORMAT",
		{"start": start_time, "end": end_time}
	)

## 评估条件
func _evaluate_condition(context: ExecutionContext) -> bool:
	# 验证时间范围
	if start_time < 0 or end_time < 0:
		var error_msg = FuseLocalization.translate("FUSE_ERROR_TIME_NEGATIVE")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return false

	if start_time >= end_time:
		var error_msg = FuseLocalization.translate("FUSE_ERROR_START_MUST_BE_LESS_THAN_END")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return false

	# 获取当前时间（秒）
	var current_time = Engine.get_frames_drawn() / 60.0

	# 检查是否在时间范围内
	var in_range = current_time >= start_time and current_time <= end_time

	_log_debug(FuseLocalization.translate_format(
		"FUSE_CONDITION_LOG_TIME_RANGE_CHECK",
		{"current": current_time, "start": start_time, "end": end_time, "result": "是" if in_range else "否"}
	))

	return in_range

## 计算依赖
func _compute_dependencies() -> Array[String]:
	return []

## 获取条件类型
func get_condition_type() -> String:
	return "time_range"

## 获取条件分类
func get_condition_category() -> String:
	return "time"

## 获取条件描述
func get_description() -> String:
	var desc = FuseLocalization.translate_format(
		"FUSE_CONDITION_TIME_RANGE_DESC_FORMAT",
		{"start": start_time, "end": end_time}
	)

	# 限制描述长度
	if desc.length() > 50:
		desc = desc.substr(0, 47) + "..."

	return desc

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()

	if start_time < 0 or end_time < 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_TIME_NEGATIVE"))

	if start_time >= end_time:
		errors.append(FuseLocalization.translate("FUSE_ERROR_START_MUST_BE_LESS_THAN_END"))

	return errors

## 获取参数
func get_parameters() -> Dictionary:
	return {
		"start_time": start_time,
		"end_time": end_time
	}

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("start_time"):
		start_time = parameters["start_time"]
	if parameters.has("end_time"):
		end_time = parameters["end_time"]

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_TIME_RANGE_NAME"
	metadata.category_key = "FUSE_CATEGORY_TIME"
	metadata.description_key = "FUSE_CONDITION_TIME_RANGE_DESC"
	metadata.keywords = ["时间段", "time range", "范围", "range", "时间窗口"]
	metadata.builtin_icon = "Time"
	return metadata
