@tool
@icon("res://addons/fuse/icons/builtin/Time.png")
extends BaseCondition
class_name CheckGameTime

## 游戏时间条件
##
## 检查游戏运行时间是否达到指定值。

## 目标游戏时间（秒）
@export_group("Game Time Check")
@export var target_game_time: float = 0.0:
	set(value):
		target_game_time = value
		_update_resource_name()

## 更新资源名称（必需）
func _update_resource_name() -> void:
	resource_name = FuseLocalization.translate_format(
		"FUSE_CONDITION_GAME_TIME_FORMAT",
		{"time": target_game_time}
	)

## 评估条件
func _evaluate_condition(context: ExecutionContext) -> bool:
	# 验证目标时间
	if target_game_time < 0:
		var error_msg = FuseLocalization.translate("FUSE_ERROR_GAME_TIME_NEGATIVE")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return false

	# 获取当前游戏时间（秒）
	var current_time = Engine.get_frames_drawn() / 60.0

	# 检查是否达到目标时间
	var reached = current_time >= target_game_time

	_log_debug(FuseLocalization.translate_format(
		"FUSE_CONDITION_LOG_GAME_TIME_CHECK",
		{"current": current_time, "target": target_game_time, "status": "已达到" if reached else "未达到"}
	))

	return reached

## 计算依赖
func _compute_dependencies() -> Array[String]:
	return []

## 获取条件类型
func get_condition_type() -> String:
	return "game_time"

## 获取条件分类
func get_condition_category() -> String:
	return "time"

## 获取条件描述
func get_description() -> String:
	var desc = FuseLocalization.translate_format(
		"FUSE_CONDITION_GAME_TIME_DESC_FORMAT",
		{"time": target_game_time}
	)

	# 限制描述长度
	if desc.length() > 50:
		desc = desc.substr(0, 47) + "..."

	return desc

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()

	if target_game_time < 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_GAME_TIME_NEGATIVE"))

	return errors

## 获取参数
func get_parameters() -> Dictionary:
	return {
		"target_game_time": target_game_time
	}

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("target_game_time"):
		target_game_time = parameters["target_game_time"]

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_GAME_TIME_NAME"
	metadata.category_key = "FUSE_CATEGORY_TIME"
	metadata.description_key = "FUSE_CONDITION_GAME_TIME_DESC"
	metadata.keywords = ["游戏时间", "game time", "运行时间", "runtime", "Engine"]
	metadata.builtin_icon = "Time"
	return metadata
