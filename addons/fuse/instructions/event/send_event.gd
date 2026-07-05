# 文件：addons/fuse/instructions/event/send_event.gd
@icon("res://addons/fuse/icons/builtin/Signal.svg")
@tool
extends BaseInstruction
class_name SendEvent

## SendEvent 指令
##
## 发送自定义事件到事件总线，允许跨 Trigger 通信。
## 可以携带参数，支持变量引用（$variable_name 语法）。

# =============================================
# 参数定义
# =============================================

## 事件名称
@export var event_name: String = "":
	set(value):
		event_name = value
		_update_resource_name()

## 事件参数（支持变量引用：$variable_name）
@export var event_args: Dictionary = {}

## 是否延迟发送（帧末尾）
@export var deferred: bool = false

# =============================================
# 元数据方法
# =============================================

## 获取指令元数据（必需）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SEND_EVENT_NAME"
	metadata.category_key = "FUSE_CATEGORY_EVENT"
	metadata.description_key = "FUSE_INSTRUCTION_SEND_EVENT_DESC"
	metadata.keywords = ["event", "send", "broadcast", "signal", "trigger", "事件", "发送", "广播", "信号"]
	metadata.builtin_icon = "Signal"
	return metadata


## 设置指令元数据
func _setup_metadata() -> void:
	pass


# =============================================
# 资源名称和描述
# =============================================

## 更新资源名称（必需）
func _update_resource_name() -> void:
	if event_name.is_empty():
		resource_name = FuseLocalization.translate("FUSE_INSTRUCTION_SEND_EVENT_NAME")
	else:
		resource_name = "%s: %s" % [
			FuseLocalization.translate("FUSE_INSTRUCTION_SEND_EVENT_NAME"),
			event_name
		]


## 获取指令描述（必需）
func get_description() -> String:
	return FuseLocalization.translate_format(
		"FUSE_INSTRUCTION_SEND_EVENT_DESCRIPTION",
		{"event_name": event_name}
	)


# =============================================
# 执行逻辑
# =============================================

## 执行指令（必需）
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	_log_debug_localized("FUSE_LOG_INSTRUCTION_START", {"instruction": "SendEvent"})

	# ============================================
	# 1. 验证参数
	# ============================================

	if event_name.is_empty():
		_log_error_localized("FUSE_ERROR_EVENT_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_EVENT_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# ============================================
	# 2. 解析参数中的变量引用
	# ============================================

	var resolved_args := _resolve_args(context, event_args)

	# ============================================
	# 3. 发送事件（通过 Autoload 全局访问）
	# ============================================
	# FuseEventBus 是 Autoload 单例，可通过 /root/FuseEventBus 访问

	var bus: Node = Engine.get_main_loop().root.get_node_or_null("FuseEventBus")
	if bus == null:
		_log_error_localized("FUSE_ERROR_EVENT_BUS_NOT_FOUND", {})
		set_error_localized("FUSE_ERROR_EVENT_BUS_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	if deferred:
		bus.send_event_deferred(event_name, resolved_args)
		_log_debug_localized("FUSE_LOG_EVENT_SENT_DEFERRED", {"event_name": event_name})
	else:
		bus.send_event(event_name, resolved_args)
		_log_debug_localized("FUSE_LOG_EVENT_SENT", {"event_name": event_name})

	_log_debug_localized("FUSE_LOG_INSTRUCTION_COMPLETE", {"instruction": "SendEvent"})

	# ============================================
	# 5. 同步完成
	# ============================================

	_on_execution_completed()


# =============================================
# 辅助方法
# =============================================

## 解析参数中的变量引用
##
## 将 $variable_name 格式的值从 ExecutionContext 中解析
func _resolve_args(context: ExecutionContext, args: Dictionary) -> Dictionary:
	var resolved := {}

	# 调试：输出原始参数
	_log_debug("[SendEvent] 开始解析参数，原始参数数量: %d" % args.size())
	for key in args:
		_log_debug("[SendEvent]   原始参数[%s] = %s (类型: %s)" % [key, args[key], typeof(args[key])])

	for key in args:
		var value = args[key]
		# 检查是否是变量引用格式
		if value is String and value.begins_with("$"):
			# 提取变量名（去掉 $ 前缀）
			var var_name: String = value.substr(1)
			# 从 ExecutionContext 获取变量值
			var resolved_value = context.get_variable(var_name)
			resolved[key] = resolved_value
			# 调试：输出变量引用解析结果
			_log_debug("[SendEvent]   解析变量引用: $%s -> %s (类型: %s)" % [var_name, resolved_value, typeof(resolved_value)])
		else:
			# 不是变量引用，直接使用原值
			resolved[key] = value
			_log_debug("[SendEvent]   直接使用值: %s" % value)

	# 调试：输出最终解析结果
	_log_debug("[SendEvent] 参数解析完成，解析后参数:")
	for key in resolved:
		_log_debug("[SendEvent]   resolved[%s] = %s (类型: %s)" % [key, resolved[key], typeof(resolved[key])])

	return resolved


# =============================================
# 验证
# =============================================

## 验证指令参数（必需）
func validate() -> Array[String]:
	var errors := super.validate()

	if event_name.is_empty():
		var error_msg := FuseLocalization.translate("FUSE_ERROR_EVENT_NAME_EMPTY")
		errors.append(error_msg)

	return errors
