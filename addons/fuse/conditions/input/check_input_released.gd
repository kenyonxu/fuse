@tool
@icon("res://addons/fuse/icons/builtin/GuiRadioCheckedDisabled.png")
extends BaseCondition
class_name CheckInputReleased

## 按键释放条件
##
## 检查指定的输入动作是否在当前帧被释放。用于检测按键、鼠标按钮等释放事件。
## 适用于执行按键释放后的操作，如结束蓄力、释放技能等。

## 输入动作名称（必须在 Project Settings -> Input Map 中定义）
@export_group("Input Released Check")
@export var action_name: String = "":
	set(value):
		action_name = value
		_update_resource_name()

## 更新资源名称（必需）
func _update_resource_name() -> void:
	if action_name.is_empty():
		resource_name = FuseLocalization.translate("FUSE_CONDITION_INPUT_RELEASED_NOT_SET")
	else:
		resource_name = FuseLocalization.translate_format("FUSE_CONDITION_INPUT_RELEASED", {"name": action_name})

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

	# 检查按键是否刚被释放
	var is_released = Input.is_action_just_released(action_name)

	_log_debug(FuseLocalization.translate_format(
		"FUSE_CONDITION_LOG_INPUT_RELEASED_CHECK",
		{"action": action_name, "result": FuseLocalization.translate("FUSE_CONDITION_RELEASED" if is_released else "FUSE_CONDITION_NOT_RELEASED")}
	))

	return is_released

## 计算依赖
func _compute_dependencies() -> Array[String]:
	# 输入检查不依赖变量
	return []

## 获取条件类型
func get_condition_type() -> String:
	return "input_released"

## 获取条件分类
func get_condition_category() -> String:
	return "input"

## 获取条件描述
func get_description() -> String:
	if action_name.is_empty():
		return FuseLocalization.translate("FUSE_CONDITION_INPUT_RELEASED_DESC_NOT_SET")

	return FuseLocalization.translate_format("FUSE_CONDITION_INPUT_RELEASED", {"name": action_name})

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()

	if action_name.is_empty():
		errors.append(FuseLocalization.translate("FUSE_CONDITION_ERROR_ACTION_NAME_EMPTY"))
	elif not InputMap.has_action(action_name):
		errors.append(FuseLocalization.translate_format("FUSE_CONDITION_ERROR_ACTION_NOT_DEFINED_INPUTMAP", {"action": action_name}))

	return errors

## 获取参数
func get_parameters() -> Dictionary:
	return {
		"action_name": action_name
	}

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("action_name"):
		action_name = parameters["action_name"]

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_INPUT_RELEASED_NAME"
	metadata.category_key = "FUSE_CATEGORY_INPUT"
	metadata.description_key = "FUSE_CONDITION_INPUT_RELEASED_DESC"
	metadata.keywords = ["输入", "input", "按键", "key", "button", "release", "释放", "松开", "keyup", "mouseup"]
	metadata.builtin_icon = "GuiRadioCheckedDisabled"
	return metadata

## 计算线程安全性
## CheckInputReleased 只调用 Input.is_action_just_released()
## Input API 是线程安全的，不访问节点或 ExecutionContext
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	_thread_safety_cached = true  # Input API 线程安全
	_thread_safety_computed = true
	return _thread_safety_cached
