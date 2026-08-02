@tool
@icon("res://addons/fuse/icons/builtin/ClassList.png")
extends BaseInstruction
class_name IfElse

## If/Else 指令
##
## 根据条件执行不同的指令序列。
## 使用 Condition 类实现，支持扩展性。
## 支持同步和异步两种执行模式。

## 指令序列执行模式枚举
enum SequenceMode {
	SYNCHRONOUS,  ## 同步执行，不等待指令完成
	ASYNCHRONOUS  ## 异步执行，等待每个指令完成后再继续
}

## 指令序列执行模式（默认异步，确保子指令正确执行）
@export var sequence_mode: SequenceMode = SequenceMode.ASYNCHRONOUS:
	set(value):
		sequence_mode = value
		_update_resource_name()

# 条件配置（使用Condition类实现）
var condition: BaseCondition = null:
	set(value):
		condition = value
		_update_resource_name()
		_log_debug("Condition set to: %s" % (value.get_description() if value else "null"))

# 嵌套指令列表
var true_instructions: Array[BaseInstruction] = []:
	set(value):
		true_instructions = value
		_update_resource_name()

var false_instructions: Array[BaseInstruction] = []:
	set(value):
		false_instructions = value
		_update_resource_name()

# 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_IF_ELSE_NAME"
	metadata.category_key = "FUSE_CATEGORY_FLOW_CONTROL"
	metadata.description_key = "FUSE_INSTRUCTION_IF_ELSE_DESC"
	metadata.keywords = ["如果", "否则", "条件", "判断", "分支", "if", "else", "condition", "branch"]
	# 设置指令选择器图标
	metadata.builtin_icon = "ClassList"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Condition 分类
	properties.append({
		name = "Condition Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 条件（使用 BaseCondition 资源）
	properties.append({
		name = "condition",
		type = TYPE_OBJECT,
		hint = PROPERTY_HINT_RESOURCE_TYPE,
		hint_string = "BaseCondition",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Instructions 分类
	properties.append({
		name = "Branch Instructions",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "true_instructions",
		type = TYPE_ARRAY,
		hint = PROPERTY_HINT_RESOURCE_TYPE,
		hint_string = "BaseInstruction",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "false_instructions",
		type = TYPE_ARRAY,
		hint = PROPERTY_HINT_RESOURCE_TYPE,
		hint_string = "BaseInstruction",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []

	parts.append("If/Else")

	# 使用条件的描述
	if condition:
		parts.append(condition.get_description())
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_IF_ELSE_NO_CONDITION"))

	var true_count = true_instructions.size()
	var false_count = false_instructions.size()

	parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_IF_ELSE_BRANCH_COUNT", {"true": true_count, "false": false_count}))

	# 显示执行模式
	var mode_key = "FUSE_INSTRUCTION_IF_ELSE_MODE_SYNC" if sequence_mode == SequenceMode.SYNCHRONOUS else "FUSE_INSTRUCTION_IF_ELSE_MODE_ASYNC"
	parts.append("[%s]" % FuseLocalization.translate(mode_key))

	resource_name = " ".join(parts)

## 动态属性设置（支持属性刷新）
func _set(property: StringName, value: Variant) -> bool:
	if property == "condition":
		condition = value
		_update_resource_name()
		return true

	if property == "true_instructions" or property == "false_instructions":
		_update_resource_name()
		return false

	return false

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	_log_debug_localized("FUSE_LOG_INSTRUCTION_START", {"instruction": "If/Else"})

	# 验证条件
	if not condition:
		_log_error_localized("FUSE_INSTRUCTION_IF_ELSE_ERROR_NO_CONDITION", {})
		set_error_localized("FUSE_INSTRUCTION_IF_ELSE_ERROR_NO_CONDITION", FuseError.ErrorType.VALIDATION_ERROR, {})
		_on_execution_completed()
		return

	# 评估条件（简化为一行！）
	var condition_result: bool = condition.check(context)

	var result_key = "FUSE_COMMON_TRUE" if condition_result else "FUSE_COMMON_FALSE"
	_log_info_localized("FUSE_INSTRUCTION_IF_ELSE_CONDITION_RESULT", {"result": FuseLocalization.translate(result_key)})

	# 根据条件结果执行对应的指令序列
	var instructions_to_execute = true_instructions if condition_result else false_instructions

	if instructions_to_execute.is_empty():
		_log_info_localized("FUSE_INSTRUCTION_IF_ELSE_EMPTY_SEQUENCE", {})
		_on_execution_completed()
		return

	# 根据执行模式选择执行方式
	if sequence_mode == SequenceMode.SYNCHRONOUS:
		_execute_synchronous(context, instructions_to_execute)
	else:
		_execute_asynchronous(context, instructions_to_execute)

## 同步执行指令序列
func _execute_synchronous(context: ExecutionContext, instructions: Array[BaseInstruction]):
	for instruction in instructions:
		if not instruction:
			_log_warning_localized("FUSE_INSTRUCTION_IF_ELSE_SKIP_NULL", {})
			continue

		_log_debug_localized("FUSE_INSTRUCTION_IF_ELSE_EXECUTE_INSTRUCTION", {"instruction": instruction.get_description()})

		# 检测是否为异步指令，发出警告
		BaseInstruction.log_async_in_sync_mode_warning(instruction)

		# 执行指令（同步执行）
		instruction.execute(context)

		# 检查指令是否完成
		if not instruction.is_completed():
			_log_warning_localized("FUSE_INSTRUCTION_IF_ELSE_INSTRUCTION_NOT_COMPLETED", {"instruction": instruction.get_description()})

	_log_info_localized("FUSE_INSTRUCTION_IF_ELSE_EXECUTION_COMPLETE", {})
	_on_execution_completed()

## 异步执行指令序列
func _execute_asynchronous(context: ExecutionContext, instructions: Array[BaseInstruction]):
	for instruction in instructions:
		if not instruction:
			_log_warning_localized("FUSE_INSTRUCTION_IF_ELSE_SKIP_NULL", {})
			continue

		_log_debug_localized("FUSE_INSTRUCTION_IF_ELSE_EXECUTE_INSTRUCTION", {"instruction": instruction.get_description()})

		# 重置指令状态（确保可以重新执行）
		instruction.reset()

		# 执行指令
		instruction.execute(context)

		# 等待指令完成
		if not instruction.is_completed():
			_log_debug_localized("FUSE_INSTRUCTION_IF_ELSE_WAITING_FOR_INSTRUCTION", {"instruction": instruction.get_description()})
			await instruction.finished

	_log_info_localized("FUSE_INSTRUCTION_IF_ELSE_EXECUTION_COMPLETE", {})
	_on_execution_completed()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if not condition:
		errors.append(FuseLocalization.translate("FUSE_INSTRUCTION_IF_ELSE_ERROR_NO_CONDITION"))

	# 验证同步模式下是否包含异步指令（验证 true 分支）
	BaseInstruction.validate_async_in_sync_mode(
		true_instructions,
		sequence_mode == SequenceMode.SYNCHRONOUS,
		errors
	)

	# 验证同步模式下是否包含异步指令（验证 false 分支）
	BaseInstruction.validate_async_in_sync_mode(
		false_instructions,
		sequence_mode == SequenceMode.SYNCHRONOUS,
		errors
	)

	return errors

## 获取指令描述
func get_description() -> String:
	var desc = FuseLocalization.translate("FUSE_INSTRUCTION_IF_ELSE_DESC_PREFIX")

	if condition:
		desc += condition.get_description()
	else:
		desc += FuseLocalization.translate("FUSE_INSTRUCTION_IF_ELSE_NO_CONDITION")

	desc += FuseLocalization.translate_format("FUSE_INSTRUCTION_IF_ELSE_DESC_SUFFIX", {"true": true_instructions.size(), "false": false_instructions.size()})

	return desc

## 重置指令状态
func reset():
	super.reset()
	_log_debug_localized("FUSE_INSTRUCTION_IF_ELSE_RESET_COMPLETE", {})

## 统一日志方法
func _log_debug(message: String):
	FuseLogger.log_debug("IfElseInstruction", log_level, message)

func _log_info(message: String):
	FuseLogger.log_info("IfElseInstruction", log_level, message)

func _log_warning(message: String):
	FuseLogger.log_warning("IfElseInstruction", log_level, message)

func _log_error(message: String):
	FuseLogger.log_error("IfElseInstruction", log_level, message)
