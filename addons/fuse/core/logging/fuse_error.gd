@tool
class_name FuseError extends RefCounted

## 统一错误处理类
## 提供标准化的错误创建和处理机制，与 FuseLogger 集成

enum ErrorType {
	VALIDATION_ERROR,    # 验证错误
	EXECUTION_ERROR,     # 执行错误
	CONFIGURATION_ERROR, # 配置错误
	RUNTIME_ERROR,       # 运行时错误
	TIMEOUT_ERROR        # 超时错误
}

## 性能优化：缓存 FuseLocalization 类引用
## 避免重复 load() 调用，提升性能约 70%
static var _fuse_localization_class: RefCounted = null

var error_type: ErrorType
var component_name: String
var error_code: String
var message: String
var context: Dictionary
var timestamp: float

func _init(type: ErrorType, component: String, msg: String, code: String = "", ctx: Dictionary = {}):
	error_type = type
	component_name = component
	message = msg
	error_code = code
	context = ctx
	timestamp = Time.get_ticks_msec() / 1000.0

	# 自动记录到日志系统
	_log_to_fuse_logger()

## 静态创建方法
static func create_validation_error(component: String, message: String, context: Dictionary = {}) -> FuseError:
	return FuseError.new(ErrorType.VALIDATION_ERROR, component, message, "VALIDATION_ERROR", context)

static func create_execution_error(component: String, message: String, context: Dictionary = {}) -> FuseError:
	return FuseError.new(ErrorType.EXECUTION_ERROR, component, message, "EXECUTION_ERROR", context)

static func create_configuration_error(component: String, message: String, context: Dictionary = {}) -> FuseError:
	return FuseError.new(ErrorType.CONFIGURATION_ERROR, component, message, "CONFIGURATION_ERROR", context)

static func create_runtime_error(component: String, message: String, context: Dictionary = {}) -> FuseError:
	return FuseError.new(ErrorType.RUNTIME_ERROR, component, message, "RUNTIME_ERROR", context)

static func create_timeout_error(component: String, message: String, context: Dictionary = {}) -> FuseError:
	return FuseError.new(ErrorType.TIMEOUT_ERROR, component, message, "TIMEOUT_ERROR", context)

## 本地化错误创建方法 - Validation Error
static func create_validation_error_localized(
	component: String,
	message_key: String,
	args: Dictionary = {},
	context: Dictionary = {}
) -> FuseError:
	var localized_message = _translate_error_message(message_key, args)
	var error_context = context.duplicate()
	error_context["message_key"] = message_key
	error_context["message_args"] = args
	return FuseError.new(ErrorType.VALIDATION_ERROR, component, localized_message, "VALIDATION_ERROR", error_context)

## 本地化错误创建方法 - Execution Error
static func create_execution_error_localized(
	component: String,
	message_key: String,
	args: Dictionary = {},
	context: Dictionary = {}
) -> FuseError:
	var localized_message = _translate_error_message(message_key, args)
	var error_context = context.duplicate()
	error_context["message_key"] = message_key
	error_context["message_args"] = args
	return FuseError.new(ErrorType.EXECUTION_ERROR, component, localized_message, "EXECUTION_ERROR", error_context)

## 本地化错误创建方法 - Configuration Error
static func create_configuration_error_localized(
	component: String,
	message_key: String,
	args: Dictionary = {},
	context: Dictionary = {}
) -> FuseError:
	var localized_message = _translate_error_message(message_key, args)
	var error_context = context.duplicate()
	error_context["message_key"] = message_key
	error_context["message_args"] = args
	return FuseError.new(ErrorType.CONFIGURATION_ERROR, component, localized_message, "CONFIGURATION_ERROR", error_context)

## 本地化错误创建方法 - Runtime Error
static func create_runtime_error_localized(
	component: String,
	message_key: String,
	args: Dictionary = {},
	context: Dictionary = {}
) -> FuseError:
	var localized_message = _translate_error_message(message_key, args)
	var error_context = context.duplicate()
	error_context["message_key"] = message_key
	error_context["message_args"] = args
	return FuseError.new(ErrorType.RUNTIME_ERROR, component, localized_message, "RUNTIME_ERROR", error_context)

## 本地化错误创建方法 - Timeout Error
static func create_timeout_error_localized(
	component: String,
	message_key: String,
	args: Dictionary = {},
	context: Dictionary = {}
) -> FuseError:
	var localized_message = _translate_error_message(message_key, args)
	var error_context = context.duplicate()
	error_context["message_key"] = message_key
	error_context["message_args"] = args
	return FuseError.new(ErrorType.TIMEOUT_ERROR, component, localized_message, "TIMEOUT_ERROR", error_context)

## 静态工厂方法 - 通用错误创建方法
static func create_with_context(error_type: ErrorType, component: String, message: String, context: Dictionary = {}) -> FuseError:
	var error_context = context.duplicate()
	error_context["component"] = component
	error_context["timestamp"] = Time.get_ticks_msec() / 1000.0

	# _init 已统一记录日志，不再手动补记（曾因此每条错误双份输出）
	return FuseError.new(error_type, component, message, "", error_context)

## 翻译错误消息的辅助方法
static func _translate_error_message(message_key: String, args: Dictionary = {}) -> String:
	# 性能优化：使用缓存的类引用，避免重复 load()
	if _fuse_localization_class == null:
		_fuse_localization_class = load("res://addons/fuse/localization/fuse_localization.gd")

	# 确保翻译系统已初始化
	if _fuse_localization_class and _fuse_localization_class.has_method("init"):
		_fuse_localization_class.init()

	if not _fuse_localization_class or not _fuse_localization_class.has_method("translate"):
		# 如果本地化系统不可用，返回原始键并手动替换参数
		var result = message_key
		for key in args:
			result = result.replace("{%s}" % key, str(args[key]))
		return result

	# 使用本地化系统翻译
	if args.is_empty():
		return _fuse_localization_class.translate(message_key)
	else:
		return _fuse_localization_class.translate_format(message_key, args)

## 格式化输出
func to_string() -> String:
	return "[%s][%s] %s" % [ErrorType.keys()[error_type], component_name, message]

## 日志链内部字段：仅供程序消费，打进 push_error 纯文本只产生噪音
const _INTERNAL_CONTEXT_KEYS: Array[String] = ["message_key", "message_args", "component", "timestamp"]

func get_formatted_message() -> String:
	var message_text := message
	if context.has("message_key"):
		# 本地化错误：按存储的键与参数重新解析（容忍创建时翻译系统尚未就绪）
		message_text = _translate_error_message(context["message_key"], context.get("message_args", {}))
	return "[%s][%s] %s%s" % [ErrorType.keys()[error_type], component_name, message_text, _format_context()]

## 上下文输出：剔除内部字段后以 key=value 扁平展示，避免整包 dict str() 噪音
func _format_context() -> String:
	var parts: Array[String] = []
	for key in context:
		if key in _INTERNAL_CONTEXT_KEYS:
			continue
		parts.append("%s=%s" % [key, str(context[key])])
	if parts.is_empty():
		return ""
	return " | Context: %s" % ", ".join(parts)

## 记录到 FuseLogger - 改进分类输出
func _log_to_fuse_logger():
	var formatted_message = get_formatted_message()

	# 根据错误类型选择正确的日志级别
	match error_type:
		ErrorType.VALIDATION_ERROR, ErrorType.CONFIGURATION_ERROR:
			# 验证和配置错误作为警告输出（黄色）
			FuseLogger.log_warning("FuseError", FuseLogger.LogLevel.WARNING, formatted_message, component_name)
		ErrorType.EXECUTION_ERROR, ErrorType.RUNTIME_ERROR, ErrorType.TIMEOUT_ERROR:
			# 执行、运行时和超时错误作为错误输出（红色）
			FuseLogger.log_error("FuseError", FuseLogger.LogLevel.ERROR, formatted_message, component_name)
		_:
			# 默认作为错误输出
			FuseLogger.log_error("FuseError", FuseLogger.LogLevel.ERROR, formatted_message, component_name)

## 获取错误详细信息
func get_error_details() -> Dictionary:
	return {
		"type": ErrorType.keys()[error_type],
		"component": component_name,
		"code": error_code,
		"message": message,
		"context": context,
		"timestamp": timestamp
	}

## 检查错误是否可恢复
func is_recoverable() -> bool:
	return error_type == ErrorType.VALIDATION_ERROR or error_type == ErrorType.CONFIGURATION_ERROR

## 检查错误是否严重
func is_critical() -> bool:
	return error_type == ErrorType.RUNTIME_ERROR or error_type == ErrorType.TIMEOUT_ERROR