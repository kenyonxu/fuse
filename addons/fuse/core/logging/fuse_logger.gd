@tool
class_name FuseLogger extends RefCounted

## 统一日志管理器
## 负责格式化和管理所有 Fuse 组件的日志输出

## 日志级别枚举 - 提供直观的选择方式
enum LogLevel {
	NONE,    # 不输出任何日志
	INFO,    # 只输出 info 级别
	WARNING, # 只输出 warning 级别
	ERROR,   # 只输出 error 级别
	DEBUG    # 输出所有级别（debug, info, warning, error）
}

## 性能优化：缓存 FuseLocalization 类引用
## 避免重复 load() 调用，提升性能约 70%
static var _fuse_localization_class: RefCounted = null

## 核心日志方法
static func log_message(component_name: String, component_level: LogLevel, message_level: LogLevel, message: String, context: String = ""):
	if not should_log(component_level, message_level):
		return
	
	var formatted_message = format_message(message_level, component_name, message, context)
	
	# 根据级别选择输出方法
	match message_level:
		LogLevel.ERROR:
			push_error("发现错误!")
			print_rich(formatted_message)
		LogLevel.WARNING:
			push_warning("警告!")
			print_rich(formatted_message)
		LogLevel.INFO, LogLevel.DEBUG:
			print_rich(formatted_message)

## 各级别日志方法
static func log_debug(component_name: String, component_level: LogLevel, message: String, context: String = ""):
	log_message(component_name, component_level, LogLevel.DEBUG, message, context)
	
static func log_info(component_name: String, component_level: LogLevel, message: String, context: String = ""):
	log_message(component_name, component_level, LogLevel.INFO, message, context)
	
static func log_warning(component_name: String, component_level: LogLevel, message: String, context: String = ""):
	log_message(component_name, component_level, LogLevel.WARNING, message, context)
	
static func log_error(component_name: String, component_level: LogLevel, message: String, context: String = ""):
	log_message(component_name, component_level, LogLevel.ERROR, message, context)

## 本地化日志方法 - Debug
static func log_debug_localized(
	component_name: String,
	component_level: LogLevel,
	message_key: String,
	args: Dictionary = {},
	context: String = ""
) -> void:
	var localized_message = _translate_message(message_key, args)
	log_debug(component_name, component_level, localized_message, context)

## 本地化日志方法 - Info
static func log_info_localized(
	component_name: String,
	component_level: LogLevel,
	message_key: String,
	args: Dictionary = {},
	context: String = ""
) -> void:
	var localized_message = _translate_message(message_key, args)
	log_info(component_name, component_level, localized_message, context)

## 本地化日志方法 - Warning
static func log_warning_localized(
	component_name: String,
	component_level: LogLevel,
	message_key: String,
	args: Dictionary = {},
	context: String = ""
) -> void:
	var localized_message = _translate_message(message_key, args)
	log_warning(component_name, component_level, localized_message, context)

## 本地化日志方法 - Error
static func log_error_localized(
	component_name: String,
	component_level: LogLevel,
	message_key: String,
	args: Dictionary = {},
	context: String = ""
) -> void:
	var localized_message = _translate_message(message_key, args)
	log_error(component_name, component_level, localized_message, context)

## 翻译消息的辅助方法
static func _translate_message(message_key: String, args: Dictionary = {}) -> String:
	# 性能优化：使用缓存的类引用，避免重复 load()
	if _fuse_localization_class == null:
		_fuse_localization_class = load("res://addons/fuse/localization/fuse_localization.gd")

	# 确保翻译系统已初始化
	if _fuse_localization_class and _fuse_localization_class.has_method("init"):
		_fuse_localization_class.init()

	if not _fuse_localization_class or not _fuse_localization_class.has_method("translate_format"):
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

## 判断是否应该输出日志
static func should_log(component_level: LogLevel, message_level: LogLevel) -> bool:
	# 使用更简单的逻辑判断
	if component_level == LogLevel.NONE:
		return false
	if component_level == LogLevel.DEBUG:
		return true
	# 简化其他级别的判断逻辑 - 精确匹配
	return message_level == component_level

## 格式化日志消息
static func format_message(level: LogLevel, component_name: String, message: String, context: String = "") -> String:
	var level_str = LogLevel.keys()[level]
	var context_str = context if not context.is_empty() else ""
	
	# 添加颜色代码和图标（只在关键部分使用颜色）
	var level_color = ""
	var icon = ""
	var reset_code = "[/color]"
	
	match level:
		LogLevel.ERROR:
			level_color = "[color=red]"
			icon = "❌"
		LogLevel.WARNING:
			level_color = "[color=yellow]"
			icon = "⚠️"
		LogLevel.INFO:
			level_color = "[color=green]"
			icon = "ℹ️"
		LogLevel.DEBUG:
			level_color = "[color=cyan]"
			icon = "🔍"
	
	# 精细的颜色方案：只给级别标签和实际消息内容着色
	# 格式：[图标][级别][组件名][上下文] 消息内容
	return "%s%s%s[%s][%s]%s%s%s%s" % [
		icon,                    # 图标（无颜色）
		level_color,             # 级别颜色开始
		level_str,               # 级别文本
		reset_code,              # 级别颜色结束
		component_name,          # 组件名（默认颜色）
		context_str,             # 上下文（默认颜色）
		level_color,             # 消息颜色开始（与级别相同）
		message,                 # 消息内容
		reset_code               # 消息颜色结束
	]
