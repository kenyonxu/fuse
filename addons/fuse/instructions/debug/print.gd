@icon("res://addons/fuse/icons/builtin/Debug.png")
# 文件：addons/fuse/tests/print_instruction.gd
@tool
extends BaseInstruction
class_name Print

# 关键：实现这个静态方法，用于指令选择器
static func _get_instruction_metadata() -> InstructionMetadata:
	metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_PRINT_NAME"
	metadata.category_key = "FUSE_CATEGORY_DEBUG"
	metadata.description_key = "FUSE_INSTRUCTION_PRINT_DESC"
	# 正确初始化 Array[String] 类型
	metadata.keywords = ["打印", "调试", "输出", "消息", "日志", "print", "debug", "output", "message", "log"]
	metadata.builtin_icon = "Debug"
	return metadata

## 打印指令
##
## 一个简单的指令，用于在控制台打印消息。
## 主要用于测试和调试指令执行流程。

## 要打印的消息
@export var message: String = "Hello, World!":
	set(value):
		message = value
		_update_resource_name()

## 更新资源名称
## 重写基类方法，提供 PrintInstruction 的自定义资源名称
func _update_resource_name():
	resource_name = FuseLocalization.translate_format(
		"FUSE_INSTRUCTION_PRINT_RESOURCE_NAME",
		{"message": message}
	)

## 设置指令元数据
func _setup_metadata():
	pass
## 执行指令
## context: ExecutionContext - 执行上下文
func execute(context: ExecutionContext):
	# 调用基类的执行初始化方法
	_start_execution(context)

	_log_debug_localized("FUSE_LOG_INSTRUCTION_START", {"instruction": "Print"})

	# 检查消息是否为空
	if message.is_empty():
		_log_error_localized("FUSE_ERROR_MESSAGE_EMPTY", {})
		set_error_localized("FUSE_ERROR_MESSAGE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 打印消息到控制台
	print("[PrintInstruction] %s" % message)

	# 如果提供了执行上下文，也输出到上下文
	if context:
		var print_message = FuseLocalization.translate_format("FUSE_LOG_PRINT_MESSAGE", {"message": message})
		context.print_message(print_message)

	_log_debug_localized("FUSE_LOG_INSTRUCTION_COMPLETE", {"instruction": "Print"})

	# 标记指令完成
	_on_execution_completed()

## 获取指令描述
## returns: String - 指令描述
func get_description() -> String:
	return FuseLocalization.translate_format(
		"FUSE_INSTRUCTION_PRINT_DESCRIPTION",
		{"message": message}
	)

## 验证指令参数
## returns: Array[String] - 错误信息数组
func validate() -> Array[String]:
	var errors = super.validate()

	if message.is_empty():
		# 使用本地化的验证错误消息
		var error_msg = FuseLocalization.translate("FUSE_ERROR_MESSAGE_EMPTY")
		errors.append(error_msg)

	return errors

## 统一日志方法
func _log_debug(message: String):
	FuseLogger.log_debug("PrintInstruction", log_level, message)

func _log_info(message: String):
	FuseLogger.log_info("PrintInstruction", log_level, message)

func _log_warning(message: String):
	FuseLogger.log_warning("PrintInstruction", log_level, message)

func _log_error(message: String):
	FuseLogger.log_error("PrintInstruction", log_level, message)