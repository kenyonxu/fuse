@tool
@icon("res://addons/fuse/icons/builtin/DebugSkipBreakpointsOff.png")
extends BaseCondition
class_name CheckInputHeld

## 按键持续按住条件
##
## 检查指定的输入动作是否持续按住。用于检测按键、鼠标按钮等保持按下的状态。
## 适用于检测持续操作，如蓄力、长按、连续移动等。

## 输入动作名称（必须在 Project Settings -> Input Map 中定义）
@export_group("Input Held Check")
@export var action_name: String = "":
	set(value):
		action_name = value
		_update_resource_name()

## 最小按住时间（秒），0 表示不需要最小时间
@export var minimum_hold_time: float = 0.0:
	set(value):
		minimum_hold_time = max(0.0, value)
		_update_resource_name()
		_log_debug("Minimum hold time set to: %s seconds" % minimum_hold_time)

## 私有属性
var _press_start_time: float = 0.0
var _is_holding: bool = false

## 更新资源名称（必需）
func _update_resource_name() -> void:
	if action_name.is_empty():
		resource_name = FuseLocalization.translate("FUSE_CONDITION_INPUT_HELD_NOT_SET")
	else:
		if minimum_hold_time > 0.0:
			resource_name = FuseLocalization.translate_format("FUSE_CONDITION_INPUT_HELD_WITH_TIME", {"name": action_name, "time": minimum_hold_time})
		else:
			resource_name = FuseLocalization.translate_format("FUSE_CONDITION_INPUT_HELD", {"name": action_name})

## 评估条件
func _evaluate_condition(context: ExecutionContext) -> bool:
	# 验证动作名称
	if action_name.is_empty():
		var error_msg = FuseLocalization.translate("FUSE_CONDITION_ERROR_ACTION_NAME_EMPTY")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return false

	# 检查输入动作是否存在
	if not InputMap.has_action(action_name):
		var error_msg = FuseLocalization.translate_format("FUSE_CONDITION_WARNING_ACTION_NOT_DEFINED", {"action": action_name})
		_log_warning(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return false

	# 检查按键是否按下
	var is_pressed = Input.is_action_pressed(action_name)

	# 处理按住状态
	if is_pressed:
		# 按键正在被按下
		if not _is_holding:
			# 刚开始按下，记录开始时间
			_press_start_time = Time.get_ticks_msec() / 1000.0
			_is_holding = true
			_log_debug(FuseLocalization.translate_format("FUSE_CONDITION_LOG_INPUT_HELD_START", {"action": action_name}))

		# 计算按住时长
		var hold_duration = (Time.get_ticks_msec() / 1000.0) - _press_start_time

		# 检查是否满足最小按住时间
		var meets_minimum = (minimum_hold_time == 0.0) or (hold_duration >= minimum_hold_time)

		_log_debug(FuseLocalization.translate_format(
			"FUSE_CONDITION_LOG_INPUT_HELD_CHECK",
			{"action": action_name, "duration": hold_duration, "status": FuseLocalization.translate("FUSE_CONDITION_HELD_MET") if meets_minimum else FuseLocalization.translate_format("FUSE_CONDITION_HELD_WAITING", {"time": minimum_hold_time})}
		))

		return meets_minimum
	else:
		# 按键未被按下或已释放
		if _is_holding:
			_is_holding = false
			_press_start_time = 0.0
			_log_debug(FuseLocalization.translate_format("FUSE_CONDITION_LOG_INPUT_RELEASED", {"action": action_name}))

		_log_debug(FuseLocalization.translate_format("FUSE_CONDITION_LOG_INPUT_HELD_NOT_PRESSED", {"action": action_name}))
		return false

## 重置条件状态
func reset():
	super.reset()
	_press_start_time = 0.0
	_is_holding = false
	_log_debug("InputHeld condition reset")

## 计算依赖
func _compute_dependencies() -> Array[String]:
	# 输入检查不依赖变量
	return []

## 获取条件类型
func get_condition_type() -> String:
	return "input_held"

## 获取条件分类
func get_condition_category() -> String:
	return "input"

## 获取条件描述
func get_description() -> String:
	if action_name.is_empty():
		return FuseLocalization.translate("FUSE_CONDITION_INPUT_HELD_DESC_NOT_SET")

	var desc = FuseLocalization.translate_format("FUSE_CONDITION_INPUT_HELD", {"name": action_name})
	if minimum_hold_time > 0.0:
		desc += FuseLocalization.translate_format("FUSE_CONDITION_INPUT_HELD_TIME_APPEND", {"time": minimum_hold_time})

	return desc

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()

	if action_name.is_empty():
		errors.append(FuseLocalization.translate("FUSE_CONDITION_ERROR_ACTION_NAME_EMPTY"))
	elif not InputMap.has_action(action_name):
		errors.append(FuseLocalization.translate_format("FUSE_CONDITION_ERROR_ACTION_NOT_DEFINED_INPUTMAP", {"action": action_name}))

	if minimum_hold_time < 0.0:
		errors.append(FuseLocalization.translate("FUSE_CONDITION_ERROR_MINIMUM_HOLD_NEGATIVE"))

	return errors

## 获取参数
func get_parameters() -> Dictionary:
	return {
		"action_name": action_name,
		"minimum_hold_time": minimum_hold_time
	}

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("action_name"):
		action_name = parameters["action_name"]
	if parameters.has("minimum_hold_time"):
		minimum_hold_time = parameters["minimum_hold_time"]

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_INPUT_HELD_NAME"
	metadata.category_key = "FUSE_CATEGORY_INPUT"
	metadata.description_key = "FUSE_CONDITION_INPUT_HELD_DESC"
	metadata.keywords = ["输入", "input", "按键", "key", "button", "hold", "按住", "长按", "long", "press", "continuous", "持续", "charge", "蓄力"]
	metadata.builtin_icon = "DebugSkipBreakpointsOff"
	return metadata

## 计算线程安全性
## CheckInputHeld 只调用 Input.is_action_pressed()
## Input API 是线程安全的，不访问节点或 ExecutionContext
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	_thread_safety_cached = true  # Input API 线程安全
	_thread_safety_computed = true
	return _thread_safety_cached
