@tool
@icon("res://addons/fuse/icons/builtin/Info.png")
extends BaseInstruction
class_name RunConditionCheck

# 关键：实现这个静态方法，用于指令选择器
static func _get_instruction_metadata() -> InstructionMetadata:
	metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_RUN_CONDITION_CHECK_NAME"
	metadata.category_key = "FUSE_CATEGORY_FLOW_CONTROL"
	metadata.description_key = "FUSE_INSTRUCTION_RUN_CONDITION_CHECK_DESC"
	metadata.keywords = ["条件", "检查", "控制流", "分支", "跳过", "停止", "condition", "check", "control flow", "branch", "skip", "stop"]
	# 设置指令选择器图标
	metadata.builtin_icon = "Info"
	return metadata

## 条件配置
@export var condition: BaseCondition = null:
	set(value):
		condition = value
		_update_resource_name()
		_log_debug("Condition set to: %s" % (value.get_description() if value else "null"))

## 行为配置
@export_group("Behavior Configuration")
@export var on_condition_true: ConditionBehavior = ConditionBehavior.CONTINUE:
	set(value):
		on_condition_true = value
		_update_resource_name()
		_log_debug("On condition true behavior set to: %s" % ConditionBehavior.keys()[value])

@export var on_condition_false: ConditionBehavior = ConditionBehavior.STOP_EXECUTION:
	set(value):
		on_condition_false = value
		_update_resource_name()
		_log_debug("On condition false behavior set to: %s" % ConditionBehavior.keys()[value])

@export var skip_count: int = 0:
	set(value):
		skip_count = value
		_update_resource_name()
		_log_debug("Skip count set to: %d" % value)

## 条件行为枚举
enum ConditionBehavior {
	CONTINUE,           ## 继续执行（正常流程）
	SKIP_NEXT,          ## 跳过后面的 N 个指令（N = skip_count）
	SKIP_REMAINING,     ## 跳过所有剩余指令
	STOP_EXECUTION,     ## 停止整个执行序列
	JUMP_TO_LABEL       ## 跳转到指定标签（需要标签系统支持）
}

## 执行结果
var condition_result: bool = false
var _action_runner: ActionRunner = null
var _execution_context: ExecutionContext = null

## 设置指令元数据
func _setup_metadata():
	pass

## 更新资源名称
func _update_resource_name():
	var condition_desc = condition.get_description() if condition else FuseLocalization.translate("FUSE_INSTRUCTION_RUN_CONDITION_CHECK_NO_CONDITION")
	var true_behavior_key = "FUSE_CONDITION_BEHAVIOR_" + ConditionBehavior.keys()[on_condition_true]
	var false_behavior_key = "FUSE_CONDITION_BEHAVIOR_" + ConditionBehavior.keys()[on_condition_false]
	var true_behavior = FuseLocalization.translate(true_behavior_key)
	var false_behavior = FuseLocalization.translate(false_behavior_key)

	resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_RUN_CONDITION_CHECK_RESOURCE_NAME", {
		"condition": condition_desc,
		"true": true_behavior,
		"false": false_behavior
	})

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证条件
	if not condition:
		_log_error_localized("FUSE_ERROR_VALIDATION_FAILED", {"errors": "条件未设置"})
		set_error_localized("FUSE_ERROR_VALIDATION_FAILED", FuseError.ErrorType.VALIDATION_ERROR, {"errors": "条件未设置"})
		finished.emit()
		return

	# 评估条件
	_log_info_localized("FUSE_LOG_EVALUATING_CONDITION", {})
	condition_result = condition.check(context)

	var result_str = "真" if condition_result else "假"
	_log_info_localized("FUSE_LOG_CONDITION_RESULT", {"result": result_str})

	# 根据条件结果选择行为
	var behavior = on_condition_true if condition_result else on_condition_false

	# 执行相应的行为
	match behavior:
		ConditionBehavior.CONTINUE:
			_handle_continue_behavior(context)
		ConditionBehavior.SKIP_NEXT:
			_handle_skip_next_behavior(context)
		ConditionBehavior.SKIP_REMAINING:
			_handle_skip_remaining_behavior(context)
		ConditionBehavior.STOP_EXECUTION:
			_handle_stop_execution_behavior(context)
		ConditionBehavior.JUMP_TO_LABEL:
			_handle_jump_to_label_behavior(context)

	_on_execution_completed()

## 处理继续执行行为
func _handle_continue_behavior(context: ExecutionContext):
	_log_debug_localized("FUSE_LOG_CONDITION_TRUE", {})
	var msg = FuseLocalization.translate("FUSE_LOG_CONDITION_TRUE")
	context.print_message(msg)
	# 不需要特殊处理，正常流程继续

## 处理跳过后续指令行为
func _handle_skip_next_behavior(context: ExecutionContext):
	_log_debug_localized("FUSE_LOG_CONDITION_FALSE_SKIP", {})
	var msg = FuseLocalization.translate_format("FUSE_LOG_CONDITION_FALSE_SKIP_DETAIL", {"count": skip_count})
	context.print_message(msg)

	# 尝试通过上下文获取 ActionRunner 并设置跳过数量
	var runner = _get_action_runner_from_context(context)
	if runner:
		runner.set_skip_instruction_count(skip_count)
		_log_info_localized("FUSE_LOG_SKIP_COUNT_SET", {"count": skip_count})
	else:
		_log_warning_localized("FUSE_WARNING_NO_ACTION_RUNNER", {})

## 处理跳过所有剩余指令行为
func _handle_skip_remaining_behavior(context: ExecutionContext):
	_log_debug_localized("FUSE_LOG_CONDITION_FALSE_SKIP_ALL", {})
	var msg = FuseLocalization.translate("FUSE_LOG_CONDITION_FALSE_SKIP_ALL")
	context.print_message(msg)

	# 尝试通过上下文获取 ActionRunner 并设置停止执行
	var runner = _get_action_runner_from_context(context)
	if runner:
		runner.set_stop_execution(true, FuseLocalization.translate("FUSE_LOG_CONDITION_FAILED_SKIP_ALL"))
		_log_info_localized("FUSE_LOG_STOP_EXECUTION_SET", {})
	else:
		_log_warning_localized("FUSE_WARNING_NO_ACTION_RUNNER", {})

## 处理停止执行行为
func _handle_stop_execution_behavior(context: ExecutionContext):
	_log_debug_localized("FUSE_LOG_CONDITION_FALSE_STOP", {})
	var msg = FuseLocalization.translate("FUSE_LOG_CONDITION_FALSE_STOP")
	context.print_message(msg)

	# 尝试通过上下文获取 ActionRunner 并设置停止执行
	var runner = _get_action_runner_from_context(context)
	if runner:
		runner.set_stop_execution(true, FuseLocalization.translate("FUSE_LOG_CONDITION_TRIGGERED_STOP"))
		_log_info_localized("FUSE_LOG_STOP_EXECUTION_SET", {})
	else:
		_log_warning_localized("FUSE_WARNING_NO_ACTION_RUNNER", {})

## 从执行上下文获取 ActionRunner
## 返回类型可以是 ActionRunner 或 RuntimeActionRunnerInstance
func _get_action_runner_from_context(context: ExecutionContext):
	# 尝试从上下文中获取 ActionRunner
	if context.has_action_runner():
		return context.get_action_runner()

	_log_warning_localized("FUSE_WARNING_NO_ACTION_RUNNER_IN_CONTEXT", {})
	return null

## 处理跳转到标签行为
func _handle_jump_to_label_behavior(context: ExecutionContext):
	_log_debug_localized("FUSE_LOG_JUMP_TO_LABEL_NOT_IMPLEMENTED", {})
	context.print_message(FuseLocalization.translate("FUSE_LOG_JUMP_TO_LABEL_FALLBACK"))

	# 暂时回退到跳过剩余指令行为
	_handle_skip_remaining_behavior(context)

## 获取指令描述
func get_description() -> String:
	if not condition:
		return FuseLocalization.translate("FUSE_INSTRUCTION_RUN_CONDITION_CHECK_DESC_NO_CONDITION")

	var condition_desc = condition.get_description()
	var true_behavior_key = "FUSE_CONDITION_BEHAVIOR_" + ConditionBehavior.keys()[on_condition_true]
	var false_behavior_key = "FUSE_CONDITION_BEHAVIOR_" + ConditionBehavior.keys()[on_condition_false]
	var true_behavior = FuseLocalization.translate(true_behavior_key)
	var false_behavior = FuseLocalization.translate(false_behavior_key)

	return FuseLocalization.translate_format("FUSE_INSTRUCTION_RUN_CONDITION_CHECK_DESCRIPTION", {
		"condition": condition_desc,
		"true": true_behavior,
		"false": false_behavior
	})

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if not condition:
		errors.append(FuseLocalization.translate("FUSE_INSTRUCTION_RUN_CONDITION_CHECK_NO_CONDITION_SET"))

	# 验证跳过数量
	if skip_count < 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_SKIP_COUNT_NEGATIVE"))

	return errors

## 获取详细执行信息
func get_debug_info() -> Dictionary:
	var info = super.get_debug_info()
	info["condition_result"] = condition_result
	info["on_condition_true"] = ConditionBehavior.keys()[on_condition_true]
	info["on_condition_false"] = ConditionBehavior.keys()[on_condition_false]
	info["skip_count"] = skip_count
	return info

## 统一日志方法
func _log_debug(message: String):
	FuseLogger.log_debug("RunConditionCheck", log_level, message)

func _log_info(message: String):
	FuseLogger.log_info("RunConditionCheck", log_level, message)

func _log_warning(message: String):
	FuseLogger.log_warning("RunConditionCheck", log_level, message)

func _log_error(message: String):
	FuseLogger.log_error("RunConditionCheck", log_level, message)
