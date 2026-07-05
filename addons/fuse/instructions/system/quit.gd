@icon("res://addons/fuse/icons/builtin/Stop.png")
# 文件：addons/fuse/instructions/quit_instruction.gd
@tool
extends BaseInstruction
class_name Quit

# 关键：实现这个静态方法，用于指令选择器
static func _get_instruction_metadata() -> InstructionMetadata:
	metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_QUIT_NAME"
	metadata.category_key = "FUSE_CATEGORY_SYSTEM"
	metadata.description_key = "FUSE_INSTRUCTION_QUIT_DESC"
	# 正确初始化 Array[String] 类型
	metadata.keywords = ["退出", "应用", "程序", "终止", "关闭", "quit", "application", "program", "terminate", "close"]
	# 设置指令选择器图标
	metadata.builtin_icon = "Stop"
	return metadata

## 退出指令
##
## 一个简单的指令，用于退出当前运行的应用程序。
## 此指令会调用 get_tree().quit() 来终止应用程序。

## 更新资源名称
## 重写基类方法，提供 QuitInstruction 的自定义资源名称
func _update_resource_name():
	resource_name = FuseLocalization.translate("FUSE_INSTRUCTION_QUIT_RESOURCE")

## 设置指令元数据
func _setup_metadata():
	pass

## 执行指令
## context: ExecutionContext - 执行上下文
func execute(context: ExecutionContext):
	# 调用基类的执行初始化方法
	_start_execution(context)

	_log_debug_localized("FUSE_LOG_INSTRUCTION_START", {"instruction": "Quit"})

	# 获取场景树
	var scene_tree = Engine.get_main_loop()
	if not scene_tree:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": "SceneTree"})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": "SceneTree"})
		finished.emit()
		return

	# 记录退出信息
	_log_info_localized("FUSE_LOG_QUITTING")
	if context:
		var exit_message = FuseLocalization.translate("FUSE_LOG_QUITTING")
		context.print_message(exit_message)

	# 执行退出操作
	scene_tree.quit()

	_log_debug_localized("FUSE_LOG_INSTRUCTION_COMPLETE", {"instruction": "Quit"})

	# 标记指令完成
	_on_execution_completed()

## 获取指令描述
## returns: String - 指令描述
func get_description() -> String:
	return FuseLocalization.translate("FUSE_INSTRUCTION_QUIT_DESC_FULL")

## 验证指令参数
## returns: Array[String] - 错误信息数组
func validate() -> Array[String]:
	var errors = super.validate()
	# 无需额外验证，此指令没有参数
	return errors

## 统一日志方法
func _log_debug(message: String):
	FuseLogger.log_debug("QuitInstruction", log_level, message)

func _log_info(message: String):
	FuseLogger.log_info("QuitInstruction", log_level, message)

func _log_warning(message: String):
	FuseLogger.log_warning("QuitInstruction", log_level, message)

func _log_error(message: String):
	FuseLogger.log_error("QuitInstruction", log_level, message)