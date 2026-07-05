@tool
@icon("res://addons/fuse/icons/builtin/KeyInvalid.png")
extends BaseCondition
class_name CheckNot

## 非 (NOT) 条件
##
## 对另一个条件的结果取反。这是最简单的逻辑运算，所有复杂逻辑判断的基础。

## 要取反的条件
@export_group("NOT Condition")
@export var inner_condition: BaseCondition = null:
	set(value):
		inner_condition = value
		clear_dependencies_cache()
		_update_resource_name()

## 更新资源名称（必需）
func _update_resource_name() -> void:
	if inner_condition == null:
		resource_name = FuseLocalization.translate("FUSE_CONDITION_NOT_NOT_SET")
	else:
		var inner_desc = inner_condition.get_description()
		# 限制长度
		if inner_desc.length() > 35:
			inner_desc = inner_desc.substr(0, 32) + "..."
		resource_name = FuseLocalization.translate_format("FUSE_CONDITION_NOT_WITH_DESC", {"desc": inner_desc})

## 评估条件
func _evaluate_condition(context: ExecutionContext) -> bool:
	# 验证内部条件
	if inner_condition == null:
		var error_msg = FuseLocalization.translate("FUSE_CONDITION_ERROR_NOT_INNER_NULL")
		_log_error(error_msg)
		_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
		return false

	# 检查内部条件
	var inner_result = inner_condition.check(context)
	var result = not inner_result

	_log_debug(FuseLocalization.translate_format(
		"FUSE_CONDITION_LOG_NOT_RESULT",
		{"input": "true" if inner_result else "false", "result": "true" if result else "false"}
	))

	return result

## 计算依赖
func _compute_dependencies() -> Array[String]:
	if inner_condition != null:
		return inner_condition.get_dependencies()
	return []

## 获取条件类型
func get_condition_type() -> String:
	return "composite_not"

## 获取条件分类
func get_condition_category() -> String:
	return "composite"

## 获取条件描述
func get_description() -> String:
	if inner_condition == null:
		return FuseLocalization.translate("FUSE_CONDITION_NOT_NOT_SET")

	var desc = FuseLocalization.translate_format("FUSE_CONDITION_NOT_WITH_DESC", {"desc": inner_condition.get_description()})

	# 限制描述长度
	if desc.length() > 50:
		desc = desc.substr(0, 47) + "..."

	return desc

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()

	if inner_condition == null:
		errors.append(FuseLocalization.translate("FUSE_CONDITION_ERROR_NOT_INNER_NULL"))
	else:
		# 同时验证内部条件
		var inner_errors = inner_condition.validate()
		errors.append_array(inner_errors)

	return errors

## 获取参数
func get_parameters() -> Dictionary:
	return {
		"inner_condition": inner_condition
	}

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("inner_condition"):
		inner_condition = parameters["inner_condition"]
		clear_dependencies_cache()

## 重置条件状态
func reset():
	super.reset()
	if inner_condition != null and inner_condition.has_method("reset"):
		inner_condition.reset()

## 计算线程安全性
## CheckNot 只有在子条件线程安全时才安全
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	var is_safe := true
	if inner_condition != null and not inner_condition.is_thread_safe:
		is_safe = false

	_thread_safety_cached = is_safe
	_thread_safety_computed = true
	return _thread_safety_cached

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_NOT_NAME"
	metadata.category_key = "FUSE_CATEGORY_COMPOSITE"
	metadata.description_key = "FUSE_CONDITION_NOT_DESC"
	metadata.keywords = ["非", "NOT", "取反", "逻辑", "否定", "inverse", "negate"]
	metadata.builtin_icon = "KeyInvalid"
	return metadata
