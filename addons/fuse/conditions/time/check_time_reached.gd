@tool
@icon("res://addons/fuse/icons/builtin/Timer.png")
extends BaseCondition
class_name CheckTimeReached

## 时间到达条件
##
## 检查是否到达指定时间。用于定时器、倒计时等场景。

## 时间模式枚举
enum TimeMode {
	RELATIVE,   ## 相对时间（从场景开始）
	ABSOLUTE    ## 绝对时间（从 Unix 纪元）
}

## 时间阈值（秒）
@export_group("Time Check")
@export_range(0.0, 36000.0, 0.1)
var target_time: float = 1.0:
	set(value):
		target_time = value
		_update_resource_name()

## 时间模式
@export var time_mode: TimeMode = TimeMode.RELATIVE:
	set(value):
		time_mode = value
		_update_resource_name()

## 私有属性
var _start_time: float = 0.0
var _initialized: bool = false

## 更新资源名称（必需）
func _update_resource_name() -> void:
	var mode_key = "FUSE_CONDITION_TIME_REACHED_RELATIVE" if time_mode == TimeMode.RELATIVE else "FUSE_CONDITION_TIME_REACHED_ABSOLUTE"
	var mode_str = FuseLocalization.translate(mode_key)
	resource_name = FuseLocalization.translate_format(
		"FUSE_CONDITION_TIME_REACHED_FORMAT",
		{"mode": mode_str, "time": target_time}
	)

## 评估条件
func _evaluate_condition(context: ExecutionContext) -> bool:
	# 初始化开始时间（仅第一次）
	if not _initialized:
		_start_time = Time.get_ticks_msec() / 1000.0
		_initialized = true
		_log_debug("时间检查初始化，开始时间: %.2f" % _start_time)

	# 获取当前时间
	var current_time = Time.get_ticks_msec() / 1000.0

	# 根据时间模式计算
	var elapsed: float
	var target: float

	match time_mode:
		TimeMode.RELATIVE:
			# 相对时间：从初始化开始计算
			elapsed = current_time - _start_time
			target = target_time
		TimeMode.ABSOLUTE:
			# 绝对时间：从 Unix 纪元开始计算
			elapsed = current_time
			target = target_time
		_:
			_log_error("未知的时间模式: %d" % time_mode)
			return false

	# 检查是否到达目标时间
	var result = elapsed >= target

	_log_debug(FuseLocalization.translate_format(
		"FUSE_CONDITION_LOG_TIME_REACHED_CHECK",
		{"elapsed": elapsed, "target": target, "status": "已到达" if result else "未到达"}
	))

	return result

## 计算依赖
func _compute_dependencies() -> Array[String]:
	# 时间检查不依赖变量
	return []

## 获取条件类型
func get_condition_type() -> String:
	return "time_reached"

## 获取条件分类
func get_condition_category() -> String:
	return "time"

## 获取条件描述
func get_description() -> String:
	var mode_key = "FUSE_CONDITION_TIME_REACHED_RELATIVE" if time_mode == TimeMode.RELATIVE else "FUSE_CONDITION_TIME_REACHED_ABSOLUTE"
	var mode_str = FuseLocalization.translate(mode_key)
	var desc = FuseLocalization.translate_format(
		"FUSE_CONDITION_TIME_REACHED_FORMAT",
		{"mode": mode_str, "time": target_time}
	)

	# 限制描述长度
	if desc.length() > 50:
		desc = desc.substr(0, 47) + "..."

	return desc

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()

	if target_time < 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_TIME_THRESHOLD_NEGATIVE"))

	return errors

## 获取参数
func get_parameters() -> Dictionary:
	return {
		"target_time": target_time,
		"time_mode": time_mode
	}

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("target_time"):
		target_time = parameters["target_time"]
	if parameters.has("time_mode"):
		time_mode = parameters["time_mode"]

## 获取详细条件信息
func get_detailed_info() -> Dictionary:
	var info = super.get_detailed_info()
	info["target_time"] = target_time
	info["time_mode"] = "RELATIVE" if time_mode == TimeMode.RELATIVE else "ABSOLUTE"
	info["start_time"] = _start_time
	info["initialized"] = _initialized

	# 计算已过时间
	if _initialized:
		var current_time = Time.get_ticks_msec() / 1000.0
		if time_mode == TimeMode.RELATIVE:
			info["elapsed_time"] = current_time - _start_time
		else:
			info["elapsed_time"] = current_time

	return info

## 重置条件状态
func reset():
	super.reset()
	_start_time = 0.0
	_initialized = false
	_log_debug("ConditionTimeReached reset")

## 获取剩余时间
## returns: float - 距离目标时间还剩多少秒（如果已到达返回 0）
func get_remaining_time() -> float:
	if not _initialized:
		return target_time

	var current_time = Time.get_ticks_msec() / 1000.0
	var elapsed: float

	match time_mode:
		TimeMode.RELATIVE:
			elapsed = current_time - _start_time
		TimeMode.ABSOLUTE:
			elapsed = current_time
		_:
			return target_time

	var remaining = target_time - elapsed
	return max(0.0, remaining)

## 获取已过时间
## returns: float - 已经过了多少秒
func get_elapsed_time() -> float:
	if not _initialized:
		return 0.0

	var current_time = Time.get_ticks_msec() / 1000.0
	var elapsed: float

	match time_mode:
		TimeMode.RELATIVE:
			elapsed = current_time - _start_time
		TimeMode.ABSOLUTE:
			elapsed = current_time
		_:
			return 0.0

	return elapsed

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_TIME_REACHED_NAME"
	metadata.category_key = "FUSE_CATEGORY_TIME"
	metadata.description_key = "FUSE_CONDITION_TIME_REACHED_DESC"
	metadata.keywords = ["时间", "time", "timer", "定时", "timeout", "倒计时", "elapsed", "经过", "schedule", "计划"]
	metadata.builtin_icon = "Timer"
	return metadata
