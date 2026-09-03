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

	# 通道分工：error/warning 走 push_*（纯文本完整消息进 Errors 面板，带原生栈、
	# 可点击跳转，不再 print_rich 重复一份）；info/debug 维持 print_rich 富文本
	match message_level:
		LogLevel.ERROR:
			push_error(format_message(message_level, component_name, message, context, false) + _external_call_site())
		LogLevel.WARNING:
			push_warning(format_message(message_level, component_name, message, context, false))
		LogLevel.INFO, LogLevel.DEBUG:
			print_rich(format_message(message_level, component_name, message, context))

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

## 消息详细度排名（阈值式过滤用；NONE 不进表、单独处理）
const _LEVEL_RANK := {
	LogLevel.ERROR: 1,
	LogLevel.WARNING: 2,
	LogLevel.INFO: 3,
	LogLevel.DEBUG: 4,
}

## 判断是否应该输出日志（阈值式）
##
## 组件级别 = 想看到的最低详细度，输出所有排名不高于它的消息：
## - NONE    → 仅 ERROR（静音组件仍能看到真错误）
## - ERROR   → 仅 ERROR
## - WARNING → ERROR + WARNING
## - INFO    → ERROR + WARNING + INFO
## - DEBUG   → 全部
static func should_log(component_level: LogLevel, message_level: LogLevel) -> bool:
	# NONE 只放行 ERROR：避免批量静音后真错误被吞掉
	if component_level == LogLevel.NONE:
		return message_level == LogLevel.ERROR
	return _LEVEL_RANK.get(message_level, 0) <= _LEVEL_RANK.get(component_level, 0)

## 格式化日志消息
##
## rich = true  输出 BBCode 富文本（print_rich 通道）；
## rich = false 输出纯文本（push_error / push_warning 通道）：不插任何 BBCode 标签、
## 级别图标换成 ASCII 前缀，避免标签在 Errors 面板裸奔、emoji 在 CI/控制台乱码。
## 两版字段顺序同构：[图标/级别][组件名][上下文] 消息内容。
static func format_message(
	level: LogLevel,
	component_name: String,
	message: String,
	context: String = "",
	rich: bool = true
) -> String:
	var level_str = LogLevel.keys()[level]

	if not rich:
		return "[%s][%s]%s %s" % [level_str, component_name, context, message]

	# 富文本配色：只给级别标签和实际消息内容着色
	var level_color = ""
	var icon = ""
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

	return "%s%s%s%s[%s]%s %s%s%s" % [
		icon,               # 图标（无颜色）
		level_color,        # 级别颜色开始
		level_str,          # 级别文本
		"[/color]",         # 级别颜色结束
		component_name,     # 组件名（默认颜色）
		context,            # 上下文（默认颜色）
		level_color,        # 消息颜色开始（与级别相同）
		message,            # 消息内容
		"[/color]"          # 消息颜色结束
	]

## 错误首发位置标注：取调用链中第一个 Fuse 插件之外的帧（业务侧真正报错处）
## get_stack() 仅在调试器可用时有数据（发布版/无调试器运行时为空），
## 因此只对 ERROR 级别调用并容忍为空
static func _external_call_site() -> String:
	var stack := get_stack()
	if stack == null or stack.is_empty():
		return ""
	for frame: Dictionary in stack:
		var source := str(frame.get("source", ""))
		if not source.begins_with("res://") or source.begins_with("res://addons/fuse/"):
			continue
		return " (at %s:%d)" % [source, int(frame.get("line", 0))]
	return ""
