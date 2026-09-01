@icon("res://addons/fuse/icons/builtin/ZoomReset.png")
# 文件：tests/count_instruction.gd
@tool
extends BaseInstruction
class_name Count

## 计数指令
##
## 一个计数指令，用于演示如何维护状态和多次执行。
## 可以用于测试指令的状态管理和重复执行。

# 关键：实现这个静态方法，用于指令选择器
static func _get_instruction_metadata() -> InstructionMetadata:
	metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_COUNT_NAME"
	metadata.category_key = "FUSE_CATEGORY_FLOW_CONTROL"
	metadata.description_key = "FUSE_INSTRUCTION_COUNT_DESC"
	# 正确初始化 Array[String] 类型
	metadata.keywords = ["计数", "循环", "状态", "累加", "count", "loop", "state", "accumulate"]
	# 设置指令选择器图标
	metadata.builtin_icon = "ZoomReset"
	return metadata

## 计数器的初始值
@export var initial_count: int = 0:
	set(value):
		initial_count = value
		current_count = value  # 同时重置当前计数
		_update_resource_name()

## 每次执行增加的值
@export var increment: int = 1:
	set(value):
		increment = value
		_update_resource_name()


## 当前计数值
var current_count: int = 0



## 更新资源名称
## 重写基类方法，提供 CountInstruction 的自定义资源名称
func _update_resource_name():
	resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_COUNT_RESOURCE_NAME", {
		"initial": initial_count,
		"current": current_count,
		"increment": increment
	})

## 设置指令元数据
func _setup_metadata():
	pass

## 执行指令
## context: ExecutionContext - 执行上下文
func execute(context: ExecutionContext):
	_start_execution(context)

	_log_debug_localized("FUSE_LOG_INSTRUCTION_START", {"instruction": "Count"})

	# 更新计数值
	current_count += increment

	# 打印计数结果
	var count_message = FuseLocalization.translate_format("FUSE_LOG_COUNT_INCREMENT", {
		"count": current_count,
		"initial": initial_count,
		"increment": increment
	})
	print("[CountInstruction] %s" % count_message)

	# 如果提供了执行上下文，也输出到上下文
	if context:
		context.print_message(count_message)

	_log_debug_localized("FUSE_LOG_INSTRUCTION_COMPLETE", {"instruction": "Count", "detail": "新计数: %d" % current_count})

	# 标记指令完成
	_on_execution_completed()

## 获取指令描述
## returns: String - 指令描述
func get_description() -> String:
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_COUNT_DESCRIPTION", {
		"initial": initial_count,
		"increment": increment,
		"current": current_count
	})

## 验证指令参数
## returns: Array[String] - 错误信息数组
func validate() -> Array[String]:
	var errors = super.validate()

	# 检查增量是否为0
	if increment == 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_INCREMENT_CANNOT_BE_ZERO"))

	return errors

## 重置指令状态
func reset():
	super.reset()
	current_count = initial_count
	_log_debug_localized("FUSE_LOG_COUNT_RESET", {"count": current_count})

## 获取当前计数值
## returns: int - 当前计数值
func get_current_count() -> int:
	return current_count

## 设置计数值
## new_count: int - 新的计数值
func set_count(new_count: int):
	current_count = new_count
	_log_debug_localized("FUSE_LOG_COUNT_RESET", {"count": current_count})
