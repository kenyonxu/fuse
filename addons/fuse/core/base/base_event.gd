# 文件：addons/fuse/core/base_event.gd
@tool
@abstract
class_name BaseEvent extends Resource

## 动态属性列表
##
## 显式返回 Array[Dictionary]，避免 Godot 4.x 使用 Resource 基类的 Array 返回类型
## 触发 "_get_property_list() should return Array[Dictionary]" 兼容性警告。
func _get_property_list() -> Array[Dictionary]:
	return []

# 预加载本地化工具类
const FuseLocalization = preload("res://addons/fuse/localization/fuse_localization.gd")

# 预加载变量工具类（统一变量访问 API）
const VariableOperations = preload("res://addons/fuse/core/utils/variable_operations.gd")
const VariableScopeUtils = preload("res://addons/fuse/core/utils/variable_scope_utils.gd")
const FuseNodeUtils = preload("res://addons/fuse/utils/fuse_node_utils.gd")

## 日志级别配置
@export var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.INFO  ## 日志输出级别

## 当此事件的触发条件满足时发出
## 'context' 参数可以传递相关的节点（例如进入区域的 body）
signal triggered(context: Node)

## 当事件停止时发出（例如 OnInterval 因条件满足而停止）
## reason: 停止原因（使用 STOP_REASON_* 常量）
## context: 停止上下文信息
signal stopped(reason: String, context: Dictionary)

## 停止原因常量
const STOP_REASON_CONDITION_MET = "condition_met"  ## 条件满足而停止
const STOP_REASON_MAX_REPEATS = "max_repeats"      ## 达到最大重复次数
const STOP_REASON_MANUAL = "manual"                ## 手动停止
const STOP_REASON_ERROR = "error"                  ## 因错误而停止

## 事件状态
var _fuse_error: FuseError = null     ## FuseError 实例，用于统一错误处理
var _trigger_ref: Node = null             ## Trigger 节点引用，用于发出停止通知
## 🔧 运行时实例引用（可选），用于访问运行时状态
var _runtime_instance_ref: RuntimeEventInstance = null

## 性能优化：缓存 FuseLocalization 类引用
## 避免重复 load() 调用，提升性能约 70%
static var _fuse_localization_class: RefCounted = null

# 更逊事件在列表中的名称
# 需要子类重写此方法
@abstract
func _update_resource_name()

## 获取 target_node 的可读显示名称
##
## 将相对路径（如 "..", "../NodeName"）转换为可读的节点名称。
## 用于 _update_resource_name() 和 get_description() 中显示目标节点。
##
## 解析策略：
## - 路径末尾有明确节点名（非纯相对引用）→ 直接提取
## - 编辑器模式通过 FuseNodeUtils 解析纯相对引用（.. / .）
## - 多层 .. 无法解析时 → 智能回退（如 ../../.. → [3层上级]）
## - 重启后的刷新由 EditorPlugin.scene_changed 信号处理
##
## 参数：
## - path: NodePath - 要解析的节点路径
##
## 返回：
## - String - 可读的节点名称
func _get_node_display_name(path: NodePath) -> String:
	if path.is_empty():
		return ""
	var path_str = str(path)
	# 快速路径：路径末尾有明确节点名（非纯相对引用）
	var file_name = path_str.get_file()
	if not file_name.is_empty() and file_name != ".." and file_name != ".":
		return file_name
	# 编辑器模式下通过 FuseNodeUtils 解析纯相对引用（.. / .）
	if Engine.is_editor_hint():
		var resolved = FuseNodeUtils.resolve_node_name_for_display(self, path)
		if resolved != path_str:
			return resolved
		# 解析失败，使用智能回退显示
		return _get_parent_level_display(path_str)
	return path_str

## 将纯 .. 路径转换为可读的层级描述
static func _get_parent_level_display(path_str: String) -> String:
	var segments = path_str.split("/")
	var parent_count = 0
	for seg in segments:
		if seg == "..":
			parent_count += 1
		elif seg == ".":
			continue
		else:
			break
	if parent_count <= 0:
		return path_str
	if parent_count == 1:
		return "[上级]"
	return "[%d层上级]" % parent_count

## 记录上次更新 resource_name 时使用的语言
## 用于检测编辑器语言是否发生变化，以便自动刷新资源名称
var _last_locale: String = ""

## 拦截属性设置，处理 resource_name 的语言自动更新
##
## 当 resource_name 被设置时（包括从文件反序列化时），
## 检查当前语言是否与上次更新时的语言不同。
## 如果不同，则重新调用 _update_resource_name() 来使用新语言翻译。
##
## 参数：
## - property: StringName - 属性名称
## - value: Variant - 属性值
##
## 返回：
## - bool - 如果属性被处理返回 true，否则返回 false
func _set(property: StringName, value: Variant) -> bool:
	if property == "resource_name":
		# 确保本地化系统已初始化，并检查语言是否变化
		FuseLocalization.init()

		# 检查当前语言是否与上次更新时不同
		var current_locale = FuseLocalization.get_locale_code()
		if _last_locale.is_empty() or current_locale != _last_locale:
			# 语言已变化或首次设置，重新生成翻译
			_last_locale = current_locale
			_update_resource_name()
			# 返回 false 让 Godot 使用我们更新的 resource_name
			return false

		# 语言未变化，记录当前语言
		_last_locale = current_locale

	# 返回 false 让 Godot 继续默认处理
	return false


## 由 Trigger 在 _ready() 时调用，用来 "启动" 事件监听
## 'owner_node' 通常就是 Trigger 节点
## 子类将在这里连接信号
func initialize(owner_node: Node) -> void:
	# 检查是否在编辑器模式下，如果是则跳过初始化
	if Engine.is_editor_hint():
		_log_debug("编辑器模式下，跳过事件初始化")
		return
	
	_create_fuse_error_localized("FUSE_ERROR_BASE_EVENT_INITIALIZE_NOT_OVERRIDDEN", FuseError.ErrorType.RUNTIME_ERROR)
	push_error("BaseEvent.initialize() must be overridden in subclass")

## 使用运行时实例初始化事件
##
## 由 Trigger 在 _ready() 时调用，使用 RuntimeEventInstance 初始化事件
## 这是内存优化的一部分，避免不必要的资源复制
##
## 参数：
## - owner_node: Node - 拥有此事件的触发器节点
## - runtime_instance: RuntimeEventInstance - 运行时事件实例
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	# 检查是否在编辑器模式下，如果是则跳过初始化
	if Engine.is_editor_hint():
		_log_debug("编辑器模式下，跳过事件初始化")
		return

	# 🔧 保存 RuntimeEventInstance 引用，子类可以通过它访问运行时状态
	_runtime_instance_ref = runtime_instance

	# 先设置 Trigger 引用，这样子类的 initialize() 就能使用它
	set_trigger_ref(owner_node)

	# 默认实现调用原有的 initialize 方法，保持向后兼容
	initialize(owner_node)

	# 子类可以重写此方法来处理特定的运行时状态
	_initialize_runtime_state(runtime_instance)

## 由 Trigger 在 _exit_tree() 时调用，用来 "清理" 事件监听
## 这是必要的，以防止内存泄漏
## 子类将在这里断开信号
##
## 🔧 修复说明：
## 在对象池场景中，Trigger._on_pool_reset() 会在调用此方法之前设置正确的 _runtime_instance_ref
## 因此子类的 terminate() 实现可以直接使用 get_runtime_state() 获取正确的运行时状态
##
## 参数：
## - owner_node: Node - 触发器节点
func terminate(owner_node: Node) -> void:
	# 默认实现：子类应该重写此方法
	_log_debug("terminate() called on BaseEvent - subclass should override")

## 初始化运行时状态
##
## 子类可以重写此方法来初始化特定的运行时状态
## 默认实现为空，子类可以根据需要添加特定的运行时状态初始化逻辑
##
## 参数：
## - runtime_instance: RuntimeEventInstance - 运行时事件实例
func _initialize_runtime_state(runtime_instance: RuntimeEventInstance):
	# 默认实现为空，子类可以重写此方法来处理特定的运行时状态
	_log_debug("运行时状态初始化 (默认实现): %s" % runtime_instance.get_description())

## 获取默认运行时状态
##
## 提供事件的默认运行时状态声明。子类可以重写此方法来添加特定状态。
## RuntimeEventInstance 会调用此方法来初始化运行时状态。
##
## 返回：
## - Dictionary: 默认运行时状态字典
##
## 使用示例：
## ```gdscript
## func get_default_runtime_state() -> Dictionary:
##     var base = super.get_default_runtime_state()
##     base["my_custom_state"] = false
##     return base
## ```
func get_default_runtime_state() -> Dictionary:
	return {
		"initialized": true,
		"trigger_count": 0,
		"last_trigger_time": 0.0
	}

## 验证事件配置
## returns: Array[String] - 验证错误列表，空数组表示验证通过
func validate() -> Array[String]:
	var errors: Array[String] = []
	return errors

## 获取事件描述
## returns: String - 事件的描述文本
func get_description() -> String:
	return "Base Event"

## 获取事件类型
## returns: String - 事件类型名称
func get_event_type() -> String:
	return "base"

## 获取事件分类
## returns: String - 事件分类名称
func get_event_category() -> String:
	return "general"

## 图标名称（推荐使用）
var icon_name: String = ""

## 图标资源（向后兼容）
var icon: Texture2D = null

## 获取事件图标
##
## 优先级与 BaseInstruction.get_icon() 一致：
##   1. metadata.builtin_icon → FuseIconManager.get_builtin_icon()
##   2. metadata.custom_icon → FuseIconManager.get_custom_icon()
##   3. metadata.icon_name → FuseIconManager
##   4. metadata.icon → 直接返回 Texture2D
##   5. 回退到实例变量 icon_name / icon（向后兼容）
##
## returns: Texture2D - 事件图标
func get_event_icon() -> Texture2D:
	# 优先从静态 metadata 获取图标（与 BaseInstruction 对齐）
	var script = get_script()
	if script and script.has_method("_get_event_metadata"):
		var meta = script._get_event_metadata()
		if meta:
			var builtin = meta.get("builtin_icon")
			if builtin is String and not builtin.is_empty():
				return FuseIconManager.get_builtin_icon(builtin)
			var custom = meta.get("custom_icon")
			if custom is String and not custom.is_empty():
				return FuseIconManager.get_custom_icon(custom)
			var icon_name_val = meta.get("icon_name")
			if icon_name_val is String and not icon_name_val.is_empty():
				if FuseIconManager.has_custom_icon(icon_name_val):
					return FuseIconManager.get_custom_icon(icon_name_val)
				return FuseIconManager.get_builtin_icon(icon_name_val)
			var icon_val = meta.get("icon")
			if icon_val is Texture2D:
				return icon_val

	# 回退到实例变量（向后兼容旧事件）
	if not icon_name.is_empty():
		return FuseIconManager.get_builtin_icon(icon_name)
	if icon != null:
		return icon
	return null

## 事件触发时自动提供的 LOCAL 变量名（供静态分析白名单）
## 默认空数组；子类按需覆盖。
## 例如 OnInputActionComposite 提供 ["input_vector", "last_input_vector"]。
## 静态分析器（analyze_problems）将这些变量视为已定义，避免误报"未声明"。
func get_provided_local_variables() -> Array[String]:
	return []


## 重置事件状态
## 子类可以重写此方法来重置特定状态
func reset() -> void:
	_fuse_error = null
	_runtime_instance_ref = null  # 🔧 清理运行时实例引用

## 设置 Trigger 引用
##
## 用于在事件停止时通知 Trigger 发出 event_stopped 信号
##
## 参数：
## - trigger: Node - Trigger 节点引用
func set_trigger_ref(trigger: Node) -> void:
	_trigger_ref = trigger

## 🔧 获取 RuntimeEventInstance 引用
##
## 返回：
## - RuntimeEventInstance - 运行时实例，如果未设置则返回 null
func get_runtime_instance() -> RuntimeEventInstance:
	return _runtime_instance_ref

## 🔧 获取运行时实例（支持传入参数优先）
##
## 当 Event 被多个 Trigger 共享时，传入的 runtime_instance 参数优先使用
## 这解决了多个实例共享 Event 资源时的状态覆盖问题
##
## 参数：
## - runtime_instance: RuntimeEventInstance - 可选的运行时实例，如果传入则优先使用
##
## 返回：
## - RuntimeEventInstance - 运行时实例，优先使用传入的参数，否则使用 _runtime_instance_ref
func get_runtime_instance_with_fallback(runtime_instance: RuntimeEventInstance = null) -> RuntimeEventInstance:
	if runtime_instance:
		return runtime_instance

	# 🔍 调试日志：仅在运行时模式下输出警告（编辑器模式下为 null 是正常的）
	if not _runtime_instance_ref and not Engine.is_editor_hint():
		push_warning("[BaseEvent.get_runtime_instance_with_fallback] 🔴 _runtime_instance_ref is NULL! Event: %s" % get_event_type())

	return _runtime_instance_ref

## 发出 triggered 信号（自动设置 trigger meta）
##
## 此方法会自动设置 context 的 "trigger" meta，防止信号被广播到其他 RuntimeEventInstance
## 适用于池化对象和共享 Event 资源的场景
##
## 参数：
## - context: Node - 事件上下文节点，传递给 triggered 信号
## - owner_node: Node - 触发器节点，用于设置 "trigger" meta
##   ⚠️ 必须传入此参数，除非子类确保 _trigger_ref 已被正确设置
##
## 使用示例：
## ```gdscript
## # context 和 trigger_node 是同一个节点时（最常见）
## _emit_triggered(owner_node, owner_node)
##
## # context 是其他节点，需要指定 trigger_node
## _emit_triggered(context_node, owner_node)
##
## # 如果 _trigger_ref 已设置（通过 set_trigger_ref），可以省略第二个参数
## _emit_triggered(context_node)
## ```
func _emit_triggered(context: Node, owner_node: Node = null) -> void:
	var trigger_node = owner_node if owner_node else _trigger_ref
	if context and trigger_node:
		context.set_meta("trigger", trigger_node)
	triggered.emit(context)

## 通知事件停止
##
## 当事件停止时调用此方法，会发出 stopped 信号并通知 Trigger
##
## 参数：
## - reason: String - 停止原因（使用 STOP_REASON_* 常量）
## - context: Dictionary - 停止上下文信息（可选）
func notify_stopped(reason: String, context: Dictionary = {}) -> void:
	# 发出 stopped 信号
	stopped.emit(reason, context)

	# 通知 Trigger 发出 event_stopped 信号
	if _trigger_ref:
		var stop_context = context.duplicate()
		stop_context["event"] = self
		stop_context["event_type"] = get_event_type()
		stop_context["event_description"] = get_description()

		# 如果 Trigger 有 event_stopped 信号，发出它
		if _trigger_ref.has_signal("event_stopped"):
			_trigger_ref.emit_signal("event_stopped", reason, stop_context)
			_log_debug_localized("FUSE_LOG_EVENT_STOPPED_NOTIFIED", {
				"reason": reason,
				"trigger": _trigger_ref.name if _trigger_ref else "null"
			})

## 获取事件详细信息
## returns: Dictionary - 包含事件详细信息的字典
func get_detailed_info() -> Dictionary:
	var detailed_info = {
		"type": get_event_type(),
		"description": get_description(),
		"category": get_event_category()
	}
	
	# 如果有 FuseError，添加错误信息
	if _fuse_error:
		detailed_info["fuse_error"] = _fuse_error.get_error_details()
	
	return detailed_info

## 创建 FuseError 实例
## message: String - 错误消息
## error_type: FuseError.ErrorType - 错误类型
## context: Dictionary - 错误上下文
func _create_fuse_error(message: String, error_type: FuseError.ErrorType = FuseError.ErrorType.RUNTIME_ERROR, context: Dictionary = {}):
	var error_context = context.duplicate()
	error_context["event_type"] = get_event_type()
	error_context["event_description"] = get_description()

	_fuse_error = FuseError.create_with_context(error_type, "BaseEvent", message, error_context)

## 创建本地化 FuseError 实例
##
## 参数：
## - message_key: String - 翻译键
## - error_type: FuseError.ErrorType - 错误类型
## - args: Dictionary - 翻译参数（可选）
## - context: Dictionary - 错误上下文（可选）
func _create_fuse_error_localized(
	message_key: String,
	error_type: FuseError.ErrorType = FuseError.ErrorType.RUNTIME_ERROR,
	args: Dictionary = {},
	context: Dictionary = {}
) -> void:
	# 尝试本地化错误消息
	# 性能优化：使用缓存的类引用，避免重复 load()
	var localized_message = message_key
	if _fuse_localization_class == null:
		_fuse_localization_class = load("res://addons/fuse/localization/fuse_localization.gd")

	# 确保翻译系统已初始化
	if _fuse_localization_class and _fuse_localization_class.has_method("init"):
		_fuse_localization_class.init()

	if _fuse_localization_class and _fuse_localization_class.has_method("translate_format"):
		if args.is_empty():
			localized_message = _fuse_localization_class.translate(message_key)
		else:
			localized_message = _fuse_localization_class.translate_format(message_key, args)
	else:
		# 回退：手动替换参数
		for key in args:
			localized_message = localized_message.replace("{%s}" % key, str(args[key]))

	# 创建 FuseError 实例
	var error_context = context.duplicate()
	error_context["message_key"] = message_key
	error_context["message_args"] = args
	error_context["event_type"] = get_event_type()
	error_context["event_description"] = get_description()

	_fuse_error = FuseError.create_with_context(error_type, "BaseEvent", localized_message, error_context)
	_log_error_localized(message_key, args)

## 获取 FuseError 实例
## returns: FuseError - FuseError 实例，如果没有错误则返回 null
func get_fuse_error() -> FuseError:
	return _fuse_error

## 检查是否有 FuseError
## returns: bool - 是否有 FuseError
func has_fuse_error() -> bool:
	return _fuse_error != null

## 统一日志方法
func _log_debug(message: String) -> void:
	FuseLogger.log_debug("BaseEvent", log_level, message)

func _log_info(message: String) -> void:
	FuseLogger.log_info("BaseEvent", log_level, message)

func _log_warning(message: String) -> void:
	FuseLogger.log_warning("BaseEvent", log_level, message)

func _log_error(message: String) -> void:
	FuseLogger.log_error("BaseEvent", log_level, message)

## 便捷本地化日志方法
## 记录本地化调试日志
##
## 参数：
## - message_key: String - 翻译键
## - args: Dictionary - 翻译参数（可选）
func _log_debug_localized(message_key: String, args: Dictionary = {}) -> void:
	FuseLogger.log_debug_localized("BaseEvent", log_level, message_key, args, get_event_type())

## 记录本地化信息日志
##
## 参数：
## - message_key: String - 翻译键
## - args: Dictionary - 翻译参数（可选）
func _log_info_localized(message_key: String, args: Dictionary = {}) -> void:
	FuseLogger.log_info_localized("BaseEvent", log_level, message_key, args, get_event_type())

## 记录本地化警告日志
##
## 参数：
## - message_key: String - 翻译键
## - args: Dictionary - 翻译参数（可选）
func _log_warning_localized(message_key: String, args: Dictionary = {}) -> void:
	FuseLogger.log_warning_localized("BaseEvent", log_level, message_key, args, get_event_type())

## 记录本地化错误日志
##
## 参数：
## - message_key: String - 翻译键
## - args: Dictionary - 翻译参数（可选）
func _log_error_localized(message_key: String, args: Dictionary = {}) -> void:
	FuseLogger.log_error_localized("BaseEvent", log_level, message_key, args, get_event_type())

## 获取事件元数据
##
## 子类应实现此方法以提供事件的元数据信息
## returns: EventMetadata - 事件元数据对象
static func _get_event_metadata() -> EventMetadata:
	return null

## ============================================================
## 🔍 性能追踪方法
## ============================================================

## 开始性能追踪
##
## 使用事件类型作为追踪名称，自动追踪所有事件的执行时间
## 示例追踪名称：OnProcess.on_process, OnPhysicsProcess.on_physics_process
##
## 参数：
## - method_name: String - 方法名称（默认为 "execute"）
func _start_performance_track(method_name: String = "execute") -> void:
	var track_name = "%s.%s" % [get_event_type(), method_name]
	FusePerformanceTracker.get_instance().start_track(track_name)

## 停止性能追踪
##
## 与 _start_performance_track 配对使用
##
## 参数：
## - method_name: String - 方法名称（必须与 _start_performance_track 一致）
func _stop_performance_track(method_name: String = "execute") -> void:
	var track_name = "%s.%s" % [get_event_type(), method_name]
	FusePerformanceTracker.get_instance().stop_track(track_name)
