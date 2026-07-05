@tool
@icon("res://addons/fuse/icons/builtin/Variant.png")
extends BaseCondition
class_name CheckAny

## 任意条件满足 (OR) 条件
##
## 当任意一个子条件满足时返回 true。这是核心逻辑运算符。

## 子条件列表
@export_group("ANY Conditions (OR)")
@export var conditions: Array[BaseCondition] = []:
	set(value):
		conditions = value
		clear_dependencies_cache()
		_update_resource_name()

## 是否使用短路求值(遇到 true 立即返回)
@export var short_circuit: bool = true

## 更新资源名称(必需)
func _update_resource_name() -> void:
	if conditions.is_empty():
		resource_name = FuseLocalization.translate("FUSE_CONDITION_ANY_NO_CONDITIONS")
	else:
		var count = conditions.size()
		resource_name = FuseLocalization.translate_format("FUSE_CONDITION_ANY_WITH_COUNT", {"count": count})

## 评估条件
func _evaluate_condition(context: ExecutionContext) -> bool:
	# 验证条件列表
	if conditions.is_empty():
		_log_warning(FuseLocalization.translate("FUSE_CONDITION_WARNING_ANY_EMPTY"))
		return false

	# 检查所有条件
	for i in range(conditions.size()):
		var condition = conditions[i]

		if condition == null:
			var error_msg = FuseLocalization.translate_format("FUSE_CONDITION_ERROR_SUBCONDITION_NULL", {"index": i})
			_log_error(error_msg)
			_create_fuse_error(error_msg, FuseError.ErrorType.VALIDATION_ERROR)
			return false

		var result = condition.check(context)

		# 短路求值:遇到 true 立即返回
		if result:
			_log_debug(FuseLocalization.translate_format("FUSE_CONDITION_LOG_ANY_SUCCESS", {"index": i}))
			return true

	_log_debug(FuseLocalization.translate_format("FUSE_CONDITION_LOG_ANY_FAILED", {"count": conditions.size()}))
	return false

## 计算依赖
func _compute_dependencies() -> Array[String]:
	var all_deps: Array[String] = []
	for condition in conditions:
		if condition != null:
			var deps = condition.get_dependencies()
			for dep in deps:
				if not dep in all_deps:
					all_deps.append(dep)
	return all_deps

## 获取条件类型
func get_condition_type() -> String:
	return "composite_any"

## 获取条件分类
func get_condition_category() -> String:
	return "composite"

## 获取条件描述
func get_description() -> String:
	if conditions.is_empty():
		return FuseLocalization.translate("FUSE_CONDITION_ANY_NO_CONDITIONS")

	var desc = FuseLocalization.translate_format("FUSE_CONDITION_ANY_WITH_COUNT", {"count": conditions.size()})

	# 限制描述长度
	if desc.length() > 50:
		desc = desc.substr(0, 47) + "..."

	return desc

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()

	if conditions.is_empty():
		errors.append(FuseLocalization.translate("FUSE_CONDITION_ERROR_ANY_NEEDS_ONE"))
	else:
		# 验证所有子条件
		for i in range(conditions.size()):
			var condition = conditions[i]
			if condition == null:
				errors.append(FuseLocalization.translate_format("FUSE_CONDITION_ERROR_SUBCONDITION_NULL_VALIDATION", {"index": i}))
			else:
				var inner_errors = condition.validate()
				for err in inner_errors:
					errors.append(FuseLocalization.translate_format("FUSE_CONDITION_ERROR_SUBCONDITION", {"index": i, "error": err}))

	return errors

## 获取参数
func get_parameters() -> Dictionary:
	return {
		"conditions": conditions,
		"short_circuit": short_circuit
	}

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("conditions"):
		conditions = parameters["conditions"]
		clear_dependencies_cache()
	if parameters.has("short_circuit"):
		short_circuit = parameters["short_circuit"]

## 重置条件状态
func reset():
	super.reset()
	for condition in conditions:
		if condition != null and condition.has_method("reset"):
			condition.reset()

## 计算线程安全性
## CheckAny 只有在所有子条件都线程安全时才安全
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	var is_safe := true
	for condition in conditions:
		if condition != null and not condition.is_thread_safe:
			is_safe = false
			break

	_thread_safety_cached = is_safe
	_thread_safety_computed = true
	return _thread_safety_cached

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_ANY_NAME"
	metadata.category_key = "FUSE_CATEGORY_COMPOSITE"
	metadata.description_key = "FUSE_CONDITION_ANY_DESC"
	metadata.keywords = ["任意", "OR", "或", "其中一个", "any", "some", "either"]
	metadata.builtin_icon = "Variant"
	return metadata
