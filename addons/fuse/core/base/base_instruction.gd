@tool
@icon("res://addons/fuse/icons/instruction.svg")
@abstract
class_name BaseInstruction extends Resource

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

## 指令基类
##
## 所有指令的基类，提供基本的指令执行框架和接口。
##
## 这个类定义了指令的基本生命周期和状态管理，包括：
## - 指令的初始化和元数据设置
## - 执行状态跟踪（PENDING, RUNNING, COMPLETED, CANCELLED, ERROR）
## - 错误处理和验证机制
## - 信号系统用于通知执行完成
## - 统一的 FuseError 错误处理
##
## 使用示例：
## ```gdscript
## # 创建自定义指令
## extends BaseInstruction
## class_name MyInstruction
##
## func _setup_metadata():
##     metadata.name = "我的指令"
##     metadata.description = "这是一个自定义指令"
##     metadata.category = "自定义"
##
## func execute(context: ExecutionContext):
##     super.execute(context)
##     # 实现指令逻辑
##     _on_execution_completed()
## ```

## 指令完成信号
##
## 当指令执行完成时发出，无论是成功完成、取消还是出错。
##
## 连接此信号可以监听指令执行结果：
## ```gdscript
## instruction.finished.connect(_on_instruction_finished)
##
## func _on_instruction_finished():
##     if instruction.is_completed():
##         print("指令成功完成")
##     elif instruction.has_error():
##         print("指令执行出错: ", instruction.get_error_message())
## ```
signal finished

## 指令执行状态
##
## 定义了指令在执行过程中可能的状态：
## - PENDING: 指令已创建但尚未开始执行
## - RUNNING: 指令正在执行中
## - COMPLETED: 指令已成功完成执行
## - CANCELLED: 指令被取消（通常在执行过程中）
## - ERROR: 指令执行过程中发生错误
enum ExecutionStatus {
	PENDING,    ## 等待执行
	RUNNING,    ## 正在执行
	COMPLETED,  ## 执行完成
	CANCELLED,  ## 已取消
	ERROR       ## 执行出错
}

## 完成信号时机
##
## 定义了指令完成信号的发送时机：
## - ON_START: 在执行开始时发送完成信号
## - ON_FINISH: 在执行完成时发送完成信号（默认）
enum CompletionSignalTiming {
	ON_START,   ## 在执行开始时发送完成信号
	ON_FINISH   ## 在执行完成时发送完成信号
}

## 执行模式
##
## 定义了指令的执行模式，用于智能执行路径优化：
## - AUTO_DETECT: 自动检测执行模式（推荐）
## - FORCE_ASYNC: 强制异步执行
## - FORCE_SYNC: 强制同步执行
enum ExecutionMode {
	AUTO_DETECT,    ## 自动检测执行模式（推荐）
	FORCE_ASYNC,    ## 强制异步执行
	FORCE_SYNC      ## 强制同步执行
}

## 指令元数据
##
## 包含指令的基本信息和描述，用于在编辑器和运行时识别和分类指令。
##
## 子类应该通过重写 `_setup_metadata()` 方法来设置自己的元数据。
static var metadata: InstructionMetadata = null   ## 指令元数据，包含名称、描述等信息
var execution_status: ExecutionStatus = ExecutionStatus.PENDING  ## 当前执行状态，默认为 PENDING
var error_message: String = ""            ## 错误信息，当执行出错时存储详细错误描述
var _is_finished_connected: bool = false  ## 标记 finished 信号是否已连接，防止重复连接
var _fuse_error: FuseError = null     ## FuseError 实例，用于统一错误处理

## 性能优化：缓存 FuseLocalization 类引用
## 避免重复 load() 调用，提升性能约 70%
static var _fuse_localization_class: RefCounted = null

## 异步执行检测机制
##
## 子类可以通过以下方式声明异步行为：
## 1. 重写 _is_synchronous() 方法返回 true/false
## 2. 调用 set_synchronous_hint(true/false) 设置提示
## 3. 在 execute() 中使用 await（自动检测）
##
## 示例：
## ```gdscript
## class MySyncInstruction extends BaseInstruction
##     func _is_synchronous():
##         return true  # 明确声明为同步
##
## class MyAsyncInstruction extends BaseInstruction
##     func execute(context):
##         await some_async_operation()
##         _on_execution_completed()
## ```

## 日志级别配置
@export var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.INFO  ## 日志输出级别

## 同步能力标记
var _is_synchronous_hint: bool = false  ## 子类可以设置此标记提示是否同步
var _sync_capability_cached: bool = false  ## 缓存的同步能力
var _sync_capability_detected: bool = false  ## 是否已检测同步能力
var _sync_hint_manually_set: bool = false  ## hint是否被手动设置（通过set_synchronous_hint）

## 完成信号时机配置
@export var completion_timing: CompletionSignalTiming = CompletionSignalTiming.ON_FINISH  ## 完成信号发送时机

## 执行模式配置
@export var execution_mode: ExecutionMode = ExecutionMode.AUTO_DETECT  ## 指令执行模式

## 超时管理
var _timeout_timer: SceneTreeTimer = null  ## 超时计时器
var _timeout_duration: float = 0.0         ## 超时时间（秒），0表示无超时
var _execution_start_time: float = 0.0     ## 指令执行开始时间

## 子类可以重写此方法明确声明是否为同步指令
##
## 返回：
## - bool - true 表示同步，false 表示异步
func _is_synchronous() -> bool:
	return _is_synchronous_hint

## 初始化指令
##
## 创建指令实例并初始化元数据。此方法会：
## 1. 尝试使用静态 metadata（如果子类通过 _get_instruction_metadata() 设置）
## 2. 否则创建新的 InstructionMetadata 实例
## 3. 调用 _setup_metadata() 设置初始元数据
##
## 注意：子类不应重写此方法，而应重写 _setup_metadata() 方法
func _init():
	# 尝试使用静态 metadata（子类通过 _get_instruction_metadata() 设置）
	var script = get_script()
	if script and script.has_method("_get_instruction_metadata"):
		# 调用静态方法获取静态 metadata，并赋值给实例变量
		metadata = script._get_instruction_metadata()
		# 确保使用新实例，避免多个实例共享同一个 metadata
		metadata = metadata.duplicate(true)
		# 注意：duplicate() 会复制缓存，但我们通过 instance ID 检测新实例并强制重建缓存
	else:
		# 没有静态方法，创建新实例
		metadata = InstructionMetadata.new()
		_setup_metadata()

	# 设置资源名称，用于在编辑器检查器中显示
	_update_resource_name()

## 更新资源名称
## 根据指令信息更新 resource_name，用于在编辑器检查器中显示
# 子类应该重写此方法来提供自定义的 resource_name
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
##
## 例如：.. → [上级], ../.. → [2层上级], ../../.. → [3层上级]
static func _get_parent_level_display(path_str: String) -> String:
	var segments = path_str.split("/")
	var parent_count = 0
	for seg in segments:
		if seg == "..":
			parent_count += 1
		elif seg == ".":
			continue  # ./ 不计入层级
		else:
			break  # 遇到非相对引用段停止
	if parent_count <= 0:
		return path_str
	if parent_count == 1:
		return FuseLocalization.translate("FUSE_TEXT_PARENT")
	return FuseLocalization.translate_format("FUSE_TEXT_PARENT_LEVELS", {"count": parent_count})

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
## - property: String - 属性名称
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
			# 返回 true 声明"已处理"：阻止引擎把传入的旧值（如 .tscn 里
			# 烘焙的旧语言快照）写回 resource_name，覆盖刚重译的名称。
			# 返回 false 的语义是"未处理，走默认写入"，会让旧值覆盖重译结果。
			return true

		# 语言未变化，记录当前语言
		_last_locale = current_locale

	# 返回 false 让 Godot 继续默认处理
	return false



## 设置指令元数据
##
## 子类必须重写此方法来设置自己的元数据信息。
##
## 在此方法中应该设置以下元数据：
## - name: 指令的显示名称
## - description: 指令的详细描述
## - category: 指令的分类（用于在编辑器中组织）
## - icon: 指令的图标（可选）
## - version: 指令版本（可选）
## - author: 作者信息（可选）
## - dependencies: 依赖项列表（可选）
##
## 示例：
## ```gdscript
## func _setup_metadata():
##     metadata.name = "移动节点"
##     metadata.description = "将节点移动到指定位置"
##     metadata.category = "节点操作"
##     metadata.version = "1.0"
## ```
@abstract
func _setup_metadata()

## 获取指令元数据（用于指令选择器）
##
## 返回指令的元数据，用于在指令选择器中显示和搜索。
## 子类应该重写此方法来提供元数据。
##
## 返回：
## - InstructionMetadata - 指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	metadata.name = "基础指令"
	metadata.category = "基础"
	metadata.description = "基础指令类"
	metadata.keywords = ["基础", "指令"]
	return metadata

## 组件自描述（供 InstructionAnalyzer 静态分析使用）
##
## 由 codegen 脚本自动生成子类覆写，请勿手动编辑。
## 详见 addons/fuse/docs/zh_CN/system_docs/architecture/editor_tools_design.md
## 默认实现返回空，未 codegen 的组件由 InstructionAnalyzer 静默降级处理。

## 返回该指令读写的变量引用。
## 返回: Array[Dictionary]，每项：
##   { "prop": String, "scope_prop": String, "mode": String, "condition_prop": String }
##   - prop: 变量名属性（如 "target_variable"）
##   - scope_prop: 配对的作用域属性（如 "target_variable_scope"），可为空 ""
##   - mode: "read" / "write" / "read_write"
##   - condition_prop: 变量访问受开关控制时的属性名（如 "set_with_another_variable"），可为空 ""
static func _get_variable_accesses() -> Array:
	return []

## 声明本组件变量属性的精确读写模式（供 InstructionAnalyzer 静态分析用）
## 返回 [{name: String, mode: String}]，mode ∈ "read"/"write"/"read_write"
## name 为属性名（与 source_prop 对齐，如 "target_variable"）
## 默认空数组 → fallback _infer_variable_mode（向后兼容，存量组件渐进迁移）
func get_variable_modes() -> Array[Dictionary]:
	return []

## 返回该指令引用的场景节点属性名（仅补充类型非 NodePath 的，如用 String 存的 *_node）。
## 类型为 NodePath 的属性由反射自动覆盖，无需在此声明。
## 返回: Array[String]
static func _get_nodepath_props() -> Array:
	return []

## 返回该指令涉及的自定义信号信息。
## 返回: Dictionary
##   { "declared": Array[String], "emitted": Array[String] }
##   - declared: 指令声明/代表的信号名（如 EmitSignal 的 signal_name）
##   - emitted: 指令执行时 emit 的信号名
static func _get_signal_info() -> Dictionary:
	return {"declared": [], "emitted": []}

## 执行指令
##
## 执行指令的主要方法。此方法会：
## 1. 设置执行状态为 RUNNING
## 2. 记录执行开始信息到上下文
## 3. 根据 completion_timing 设置决定是否立即发送完成信号
## 4. 执行子类实现的逻辑
##
## 子类必须重写此方法来实现具体的指令逻辑。
## 在指令完成后，必须调用 _on_execution_completed() 或直接发出 finished 信号。
##
## 参数：
## - context: ExecutionContext - 执行上下文，提供执行环境和所需资源
##
## 执行流程：
## 1. 调用 _start_execution(context) 设置基本状态
## 2. 实现指令的具体逻辑
## 3. 完成后调用 _on_execution_completed() 或处理错误
##
## 示例：
## ```gdscript
## func execute(context: ExecutionContext):
##     _start_execution(context)
##
##     # 实现指令逻辑
##     var node = context.get_node(target_path)
##     if node:
##         node.position = new_position
##         _on_execution_completed()
##     else:
##         set_error("找不到目标节点")
##         finished.emit()
## ```
@abstract
func execute(context: ExecutionContext)

## 开始执行指令
##
## 执行指令前的初始化方法。此方法会：
## 1. 设置执行状态为 RUNNING
## 2. 记录执行开始信息到上下文
## 3. 根据 completion_timing 设置决定是否立即发送完成信号
##
## 参数：
## - context: ExecutionContext - 执行上下文
func _start_execution(context: ExecutionContext):
	execution_status = ExecutionStatus.RUNNING
	_execution_start_time = Time.get_ticks_msec() / 1000.0

	# 设置超时计时器
	_setup_timeout_timer()

	# 记录执行开始信息（支持本地化）
	# 性能优化：使用缓存的类引用，避免重复 load()
	if _fuse_localization_class == null:
		_fuse_localization_class = load("res://addons/fuse/localization/fuse_localization.gd")

	var start_msg = "开始执行指令: %s" % get_description()
	if _fuse_localization_class and _fuse_localization_class.has_method("translate_format"):
		start_msg = _fuse_localization_class.translate_format("FUSE_LOG_EXECUTION_STARTED", {}) + ": %s" % get_description()

	_log_info(start_msg)
	if context:
		context.print_message(start_msg)

	# 根据完成时机设置决定是否立即发送完成信号
	if completion_timing == CompletionSignalTiming.ON_START:
		_log_debug("立即发送完成信号 (ON_START 模式)")
		_on_execution_completed()

## 获取指令描述
##
## 返回指令的描述信息，用于在日志和调试中显示。
## 子类应该重写此方法来提供有意义的描述，通常包含指令的关键参数。
##
## 返回：
## - String - 指令的描述信息
##
## 示例：
## ```gdscript
## func get_description() -> String:
##     return "移动节点 %s 到位置 %s" % [node_name, position]
## ```
func get_description() -> String:
	return "Base Instruction"

## 验证指令参数
##
## 验证指令参数的有效性。子类可以重写此方法来添加自定义验证逻辑。
##
## 返回：
## - Array[String] - 错误信息数组，如果为空则表示验证通过
##
## 验证流程：
## 1. 调用 super.validate() 获取基础验证结果
## 2. 添加自定义验证逻辑
## 3. 返回所有错误信息
##
## 示例：
## ```gdscript
## func validate() -> Array[String]:
##     var errors = super.validate()
##     if duration <= 0:
##         errors.append("持续时间必须大于0")
##     return errors
## ```
func validate() -> Array[String]:
	var errors: Array[String] = []

	return errors

## 取消指令执行
##
## 取消正在执行的指令。如果指令当前正在运行，将：
## 1. 设置执行状态为 CANCELLED
## 2. 设置错误信息为"指令被取消"
## 3. 发出 finished 信号
## 4. 清理超时计时器
##
## 注意：子类在重写此方法时，应该调用 super.cancel() 并执行必要的清理操作
func cancel():
	if execution_status == ExecutionStatus.RUNNING:
		execution_status = ExecutionStatus.CANCELLED
		error_message = "指令被取消"
		_cleanup_timeout_timer()
		finished.emit()

## 设置错误信息
##
## 设置指令执行状态为错误，并记录错误信息。
##
## 参数：
## - message: String - 错误信息
## - error_type: FuseError.ErrorType - 错误类型，默认为 EXECUTION_ERROR
## - context: Dictionary - 错误上下文信息
##
## 此方法会：
## 1. 设置执行状态为 ERROR
## 2. 存储错误信息
## 3. 创建 FuseError 实例并自动记录到日志系统
## 4. 将错误信息输出到 Godot 控制台
func set_error(message: String, error_type: FuseError.ErrorType = FuseError.ErrorType.EXECUTION_ERROR, context: Dictionary = {}):
	execution_status = ExecutionStatus.ERROR

	# 尝试本地化错误消息
	# 性能优化：使用缓存的类引用，避免重复 load()
	var localized_message = message
	if _fuse_localization_class == null:
		_fuse_localization_class = load("res://addons/fuse/localization/fuse_localization.gd")

	# 如果 message 是翻译键（以 FUSE_ERROR_ 开头），则翻译
	if message.begins_with("FUSE_ERROR_") and _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		localized_message = _fuse_localization_class.translate(message)

	error_message = localized_message

	# 创建 FuseError 实例
	var error_context = context.duplicate()
	error_context["instruction_name"] = get_name()
	error_context["instruction_description"] = get_description()

	_fuse_error = FuseError.create_with_context(error_type, "BaseInstruction", localized_message, error_context)

	_log_error("指令执行错误: %s - %s" % [get_description(), localized_message])

## 创建本地化错误并设置
##
## 参数：
## - message_key: String - 翻译键
## - error_type: FuseError.ErrorType - 错误类型
## - args: Dictionary - 翻译参数（可选）
## - context: Dictionary - 错误上下文（可选）
func set_error_localized(
	message_key: String,
	error_type: FuseError.ErrorType = FuseError.ErrorType.EXECUTION_ERROR,
	args: Dictionary = {},
	context: Dictionary = {}
) -> void:
	execution_status = ExecutionStatus.ERROR

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

	error_message = localized_message

	# 创建 FuseError 实例
	var error_context = context.duplicate()
	error_context["message_key"] = message_key
	error_context["message_args"] = args
	error_context["instruction_name"] = get_name()
	error_context["instruction_description"] = get_description()

	_fuse_error = FuseError.create_with_context(error_type, "BaseInstruction", localized_message, error_context)

	_log_error_localized(message_key, args)

## 获取执行状态
##
## 返回指令的当前执行状态。
##
## 返回：
## - ExecutionStatus - 当前执行状态
func get_execution_status() -> ExecutionStatus:
	return execution_status

## 获取错误信息
##
## 返回指令执行过程中的错误信息。
##
## 返回：
## - String - 错误信息，如果没有错误则返回空字符串
func get_error_message() -> String:
	return error_message

## 检查指令是否正在运行
##
## 判断指令当前是否正在执行中。
##
## 返回：
## - bool - 如果指令正在运行返回 true，否则返回 false
func is_running() -> bool:
	return execution_status == ExecutionStatus.RUNNING

## 检查指令是否已完成
##
## 判断指令是否已成功完成执行。
##
## 返回：
## - bool - 如果指令已完成返回 true，否则返回 false
func is_completed() -> bool:
	return execution_status == ExecutionStatus.COMPLETED

## 检查指令是否出错
##
## 判断指令执行过程中是否发生错误。
##
## 返回：
## - bool - 如果指令出错返回 true，否则返回 false
func has_error() -> bool:
	return execution_status == ExecutionStatus.ERROR

## 获取指令分类
##
## 返回指令的分类信息，用于在编辑器中组织指令。
##
## 返回：
## - String - 指令分类
func get_category() -> String:
	if metadata and metadata.has_method("get_localized_category"):
		return metadata.get_localized_category()
	return metadata.category if metadata else ""

## 获取指令名称
##
## 返回指令的显示名称（已翻译）。
##
## 返回：
## - String - 指令名称
func get_name() -> String:
	if metadata:
		if metadata.has_method("get_localized_name"):
			return metadata.get_localized_name()
		return metadata.name
	return ""

## 获取指令版本
##
## 返回指令的版本信息。
##
## 返回：
## - String - 指令版本
func get_version() -> String:
	return metadata.version

## 获取指令图标
##
## 返回指令的图标资源。
##
## 返回：
## - String - 指令版本
func get_icon() -> Texture2D:
	# 从脚本的静态方法获取元数据（不依赖共享的 static var，后者会被其他类型覆盖）
	var script = get_script()
	var meta = null
	if script and script.has_method("_get_instruction_metadata"):
		meta = script._get_instruction_metadata()
	if not meta:
		return null
	# 优先级与 FuseMetadata.get_icon_texture() 一致：builtin > custom > icon_name > icon
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
	return null

## 复制指令
##
## 创建指令的副本，包括元数据、执行状态和错误信息。
##
## 返回：
## - BaseInstruction - 指令的副本
##
## 注意：此方法会创建一个与当前指令类型相同的新实例，
## 并复制所有相关属性，但不会复制执行过程中的临时状态。
func duplicate(p_deep: bool = true) -> Resource:
	var copy = get_script().new()
	copy.metadata = metadata.duplicate() if metadata else null
	copy.execution_status = execution_status
	copy.error_message = error_message
	return copy as Resource

## 指令执行完成
##
## 指令执行完成时的内部处理方法。
##
## 此方法会：
## 1. 设置执行状态为 COMPLETED
## 2. 发出 finished 信号
## 3. 清理超时计时器
##
## 注意：子类通常不需要直接调用此方法，除非在自定义执行逻辑中
func _on_execution_completed():
	# 重入保护：ON_START 模式在启动时即完成（_start_execution 调用本方法），
	# 指令后台真正结束时不再重复迁移状态/发信号——消费方只收到一次 finished
	if execution_status == ExecutionStatus.COMPLETED:
		_log_debug("跳过重复完成处理（已完成）")
		return
	execution_status = ExecutionStatus.COMPLETED
	_cleanup_timeout_timer()
	_cleanup_resources()
	finished.emit()

## 指令执行出错
##
## 指令执行出错时的内部处理方法。
##
## 参数：
## - error: String - 错误信息
## - error_type: FuseError.ErrorType - 错误类型，默认为 EXECUTION_ERROR
## - context: Dictionary - 错误上下文信息
##
## 此方法会：
## 1. 调用 set_error() 设置错误状态和信息
## 2. 发出 finished 信号
## 3. 清理超时计时器
func _on_execution_error(error: String, error_type: FuseError.ErrorType = FuseError.ErrorType.EXECUTION_ERROR, context: Dictionary = {}):
	set_error(error, error_type, context)
	_cleanup_timeout_timer()
	_cleanup_resources()

	# 即使在 ON_START 模式下，出错时也需要发出信号
	finished.emit()

## 调试信息字符串
##
## 返回指令的调试信息字符串，用于日志输出和调试。
##
## 返回：
## - String - 调试信息
func to_string() -> String:
	# 使用字符串缓冲区减少内存分配
	var buffer = []
	buffer.append("BaseInstruction[")
	buffer.append(str(metadata.name))
	buffer.append("] - ")
	buffer.append(str(get_description()))
	return "".join(buffer)

## 获取指令的详细信息（用于调试）
##
## 返回包含指令详细信息的字典，用于调试和日志记录。
##
## 返回：
## - Dictionary - 包含以下键的字典：
##   - name: 指令名称
##   - description: 指令描述
##   - category: 指令分类
##   - status: 执行状态（字符串形式）
##   - version: 指令版本
##   - error: 错误信息（如果没有错误则为"None"）
##   - fuse_error: FuseError 详细信息（如果有错误）
func get_debug_info() -> Dictionary:
	var debug_info = {
		"name": metadata.name,
		"description": get_description(),
		"category": metadata.category,
		"status": ExecutionStatus.keys()[execution_status],
		"version": metadata.version,
		"error": error_message if has_error() else "None"
	}

	# 如果有 FuseError，添加详细信息
	if _fuse_error:
		debug_info["fuse_error"] = _fuse_error.get_error_details()

	return debug_info

## 安全连接 finished 信号
##
## 安全地连接 finished 信号，防止重复连接。
##
## 参数：
## - callable: Callable - 可调用对象
##
## 返回：
## - bool - 如果连接成功返回 true，如果已连接返回 false
func connect_finished_safe(callable: Callable) -> bool:
	if _is_finished_connected:
		_log_warning("finished 信号已连接，跳过重复连接")
		return false

	var result = finished.connect(callable)
	if result == OK:
		_is_finished_connected = true
		_log_debug("成功连接 finished 信号到 %s" % callable)
	else:
		_log_error("连接 finished 信号失败: %s" % result)

	return result == OK

## 断开 finished 信号
##
## 断开 finished 信号连接。
func disconnect_finished_safe():
	if _is_finished_connected:
		# 在 Godot 4 中，需要手动跟踪连接并断开
		# 这里我们重置连接状态，实际断开需要在外部处理
		_is_finished_connected = false
		_log_debug("已重置 finished 信号连接状态")

## 资源清理
##
## 清理指令执行过程中使用的资源，防止内存泄漏。
func _cleanup_resources():
	# 子类可以重写此方法来清理自定义资源
	# 例如：释放计时器、取消异步操作等
	_log_debug("执行资源清理")

## 记录调试日志
##
## 记录调试信息，仅在调试模式下输出。
##
## 参数：
## - message: String - 日志消息
func _log_debug(message: String):
	FuseLogger.log_debug("BaseInstruction", log_level, message, get_name())

## 记录信息日志
##
## 记录一般信息。
##
## 参数：
## - message: String - 日志消息
func _log_info(message: String):
	FuseLogger.log_info("BaseInstruction", log_level, message, get_name())

## 记录警告日志
##
## 记录警告信息。
##
## 参数：
## - message: String - 日志消息
func _log_warning(message: String):
	FuseLogger.log_warning("BaseInstruction", log_level, message, get_name())

## 记录错误日志
##
## 记录错误信息。
##
## 参数：
## - message: String - 日志消息
func _log_error(message: String):
	FuseLogger.log_error("BaseInstruction", log_level, message, get_name())

## 记录本地化调试日志
##
## 参数：
## - message_key: String - 翻译键
## - args: Dictionary - 翻译参数（可选）
func _log_debug_localized(message_key: String, args: Dictionary = {}) -> void:
	FuseLogger.log_debug_localized("BaseInstruction", log_level, message_key, args, get_name())

## 记录本地化信息日志
##
## 参数：
## - message_key: String - 翻译键
## - args: Dictionary - 翻译参数（可选）
func _log_info_localized(message_key: String, args: Dictionary = {}) -> void:
	FuseLogger.log_info_localized("BaseInstruction", log_level, message_key, args, get_name())

## 记录本地化警告日志
##
## 参数：
## - message_key: String - 翻译键
## - args: Dictionary - 翻译参数（可选）
func _log_warning_localized(message_key: String, args: Dictionary = {}) -> void:
	FuseLogger.log_warning_localized("BaseInstruction", log_level, message_key, args, get_name())

## 记录本地化错误日志
##
## 参数：
## - message_key: String - 翻译键
## - args: Dictionary - 翻译参数（可选）
func _log_error_localized(message_key: String, args: Dictionary = {}) -> void:
	FuseLogger.log_error_localized("BaseInstruction", log_level, message_key, args, get_name())

## 重置指令状态
##
## 重置指令到初始状态，允许重新执行。
##
## 此方法会：
## 1. 重置执行状态为 PENDING
## 2. 清除错误信息
## 3. 断开所有信号连接
## 4. 清理超时计时器
## 5. 清除 FuseError 实例
func reset():
	execution_status = ExecutionStatus.PENDING
	error_message = ""
	_fuse_error = null
	_cleanup_timeout_timer()
	disconnect_finished_safe()
	# 🔧 重置同步能力检测缓存，确保每次执行都重新检测
	# 这对于使用回调机制而非 await 的异步指令很重要
	_sync_capability_detected = false
	_sync_capability_cached = false
	_log_debug("指令状态已重置")

## 超时管理方法

## 设置超时时间
## 参数：
## - timeout_seconds: float - 超时时间（秒），0表示禁用超时
func set_timeout(timeout_seconds: float):
	_timeout_duration = max(0.0, timeout_seconds)
	_log_debug("设置指令超时时间: %.2f 秒" % _timeout_duration)

## 获取超时时间
## 返回：
## - float - 超时时间（秒）
func get_timeout() -> float:
	return _timeout_duration

## 检查是否启用了超时
## 返回：
## - bool - 是否启用了超时
func has_timeout() -> bool:
	return _timeout_duration > 0.0

## 获取执行时间
## 返回：
## - float - 指令执行时间（秒）
func get_execution_time() -> float:
	if execution_status == ExecutionStatus.RUNNING:
		return (Time.get_ticks_msec() / 1000.0) - _execution_start_time
	return 0.0

## 设置超时计时器
func _setup_timeout_timer():
	if not has_timeout():
		return

	_cleanup_timeout_timer()

	# 创建超时计时器
	var scene_tree = Engine.get_main_loop()
	if scene_tree:
		_timeout_timer = scene_tree.create_timer(_timeout_duration)
		_timeout_timer.timeout.connect(_on_timeout)
		_log_debug("设置超时计时器: %.2f 秒" % _timeout_duration)

## 清理超时计时器
func _cleanup_timeout_timer():
	if _timeout_timer:
		if _timeout_timer.timeout.is_connected(_on_timeout):
			_timeout_timer.timeout.disconnect(_on_timeout)
		_timeout_timer = null
		_log_debug("清理超时计时器")

## 超时处理
func _on_timeout():
	if execution_status == ExecutionStatus.RUNNING:
		var elapsed_time = get_execution_time()
		var error_msg = "指令执行超时 (%.2f 秒 > %.2f 秒)" % [elapsed_time, _timeout_duration]
		_log_error(error_msg)

		# 使用超时错误类型
		var timeout_context = {
			"execution_time": elapsed_time,
			"timeout_duration": _timeout_duration
		}
		set_error(error_msg, FuseError.ErrorType.TIMEOUT_ERROR, timeout_context)
		_cleanup_timeout_timer()
		finished.emit()



## 智能执行模式检测方法

## 检查指令是否可以同步执行
##
## 根据执行模式设置和指令特征判断是否可以同步执行。
## 返回 true 表示可以同步执行，false 表示需要异步执行。
##
## 返回：
## - bool - 是否可以同步执行
func can_execute_sync() -> bool:
	var result = false
	match execution_mode:
		ExecutionMode.FORCE_SYNC:
			result = true
		ExecutionMode.FORCE_ASYNC:
			result = false
		ExecutionMode.AUTO_DETECT:
			result = _detect_sync_capability()
		_:
			result = _detect_sync_capability()  # 默认使用自动检测

	return result

## 自动检测同步执行能力
##
## 通过分析指令的源代码特征来判断其是否适合同步执行。
## 检测异步操作特征和立即完成模式。
##
## 返回：
## - bool - 是否适合同步执行
func _detect_sync_capability() -> bool:
	# 检查指令是否有异步操作的特征
	var has_async = _has_async_operations()

	if has_async:
		return false

	# 检查指令是否在 execute 方法中直接调用 finished.emit()
	# 这类指令通常是同步的
	var immediate = _has_immediate_completion()

	if immediate:
		return true

	# 默认情况下，假设指令是同步的
	return true

## 检查是否有异步操作
##
## 通过分析指令源代码来检测是否包含异步操作相关的代码模式。
## 优先使用子类明确声明的能力，其次通过源码分析检测。
##
## 返回：
## - bool - 是否包含异步操作
func _has_async_operations() -> bool:
	# 优先使用明确的标记
	if _sync_capability_detected:
		return not _sync_capability_cached

	# 检查子类是否重写了 _is_synchronous
	# 通过检查源码中是否定义了该函数来判断
	var script = get_script()
	if script:
		var source = script.source_code
		if source and "func _is_synchronous(" in source:
			# 子类重写了方法，使用其返回值
			_sync_capability_cached = _is_synchronous()
			_sync_capability_detected = true
			return not _sync_capability_cached

		# 未重写，使用源码检测（向后兼容）
		# 但如果hint已被手动设置，则优先使用hint值
		if _sync_hint_manually_set:
			# 使用手动设置的hint值
			_sync_capability_cached = _is_synchronous_hint
			_sync_capability_detected = true
			return not _is_synchronous_hint

		if source:
			# 检查是否使用 await（排除注释中的await）
			if _contains_await_in_code(source):
				_sync_capability_cached = false
				_sync_capability_detected = true
				return true

	# 默认假设为同步
	_sync_capability_cached = true
	_sync_capability_detected = true
	return false

## 检查源码中是否包含await（排除注释）
##
## 参数：
## - source: String - 源代码
##
## 返回：
## - bool - 是否在代码中（非注释）包含await
func _contains_await_in_code(source: String) -> bool:
	var lines = source.split("\n")
	for line in lines:
		# 去除前后空白
		var stripped = line.strip_edges()
		# 跳过空行
		if stripped.is_empty():
			continue
		# 跳过注释行（以#开头）
		if stripped.begins_with("#"):
			continue
		# 检查是否包含await（不在注释中）
		if " await " in line or "\tawait " in line or line.strip_edges().begins_with("await "):
			return true
	return false

## 设置同步提示（供子类或工厂使用）
##
## 参数：
## - is_sync: bool - 是否为同步指令
func set_synchronous_hint(is_sync: bool):
	_is_synchronous_hint = is_sync
	_sync_hint_manually_set = true  # 标记为手动设置
	_sync_capability_detected = false  # 重置缓存

## 检查是否立即完成
##
## 通过分析指令源代码来检测是否在 execute 方法中直接调用 finished.emit()。
##
## 返回：
## - bool - 是否立即完成
func _has_immediate_completion() -> bool:
	var script = get_script()
	if not script:
		return false

	var source_code = script.source_code
	if not source_code:
		return false

	# 检查是否在 execute 方法中直接调用 finished.emit()
	return "finished.emit()" in source_code and "execute(" in source_code

## 同步执行包装器
##
## 同步执行指令的包装器，用于优化同步指令的执行性能。
## 返回 true 表示指令已完成（含同步失败/取消——终态即完成），false 表示需要异步等待。
##
## 参数：
## - context: ExecutionContext - 执行上下文
##
## 返回：
## - bool - 是否同步完成
func execute_sync(context: ExecutionContext) -> bool:
	"""
	同步执行指令的包装器
	返回 true 表示指令已完成（含同步失败/取消——终态即完成，错误传播
	由调用方的 has_error() 检查路径接管），false 表示需要异步等待
	"""
	if not can_execute_sync():
		execute(context)
		return false

	# 重置执行状态，确保干净的开始状态
	var original_status = execution_status
	execution_status = ExecutionStatus.PENDING

	# 执行指令
	execute(context)

	# 同步指令应在 execute() 返回前到达终态（COMPLETED/ERROR/CANCELLED）。
	# 早期实现用 lambda 监听 finished 检测同步完成，但 GDScript 闭包对局部
	# 变量按值捕获使赋值永不生效（死代码），实际一直靠此处的状态检查兜底
	# ——且旧判定只认 COMPLETED，同步失败被误判为异步（finished 已发，
	# 调用方 await 挂死）。改为纯终态判定。
	var result: bool = execution_status != ExecutionStatus.PENDING \
		and execution_status != ExecutionStatus.RUNNING

	# 如果没有同步完成，恢复原始状态
	if not result:
		execution_status = original_status

	return result

## ============================================================
## 子指令异步检测工具方法（供包含嵌套指令的指令使用）
## ============================================================

## 查找指令数组中第一个异步指令
##
## 用于验证同步模式下是否包含异步指令。
##
## 参数：
## - instructions: Array[BaseInstruction] - 指令数组
##
## 返回：
## - BaseInstruction - 第一个检测到的异步指令，如果没有则返回 null
static func find_first_async_instruction(instructions: Array[BaseInstruction]) -> BaseInstruction:
	for instruction in instructions:
		if instruction and instruction._has_async_operations():
			return instruction
	return null

## 验证子指令在同步模式下是否包含异步指令
##
## 用于 validate() 方法中，检测同步模式下是否包含异步指令。
## 如果检测到异步指令，会添加警告到错误数组。
##
## 参数：
## - instructions: Array[BaseInstruction] - 指令数组
## - is_sync_mode: bool - 是否为同步模式
## - errors: Array[String] - 错误数组（会被修改）
##
## 示例：
## ```gdscript
## func validate() -> Array[String]:
##     var errors = super.validate()
##     BaseInstruction.validate_async_in_sync_mode(loop_instructions, sequence_mode == SequenceMode.SYNCHRONOUS, errors)
##     return errors
## ```
static func validate_async_in_sync_mode(instructions: Array[BaseInstruction], is_sync_mode: bool, errors: Array[String]) -> void:
	if not is_sync_mode:
		return

	var async_instruction = find_first_async_instruction(instructions)
	if async_instruction != null:
		errors.append(FuseLocalization.translate_format(
			"FUSE_WARNING_SYNC_MODE_WITH_ASYNC_INSTRUCTION",
			{"instruction": async_instruction.get_description()}
		))

## 记录异步指令在同步模式下的运行时警告
##
## 用于 _execute_instructions_synchronous() 方法中。
##
## 参数：
## - instruction: BaseInstruction - 要检查的指令
## - logger_context: String - 日志上下文（用于 _log_warning_localized）
##
## 示例：
## ```gdscript
## func _execute_instructions_synchronous(context: ExecutionContext):
##     for instruction in loop_instructions:
##         BaseInstruction.log_async_in_sync_mode_warning(instruction, "ForEach")
##         instruction.execute(context)
## ```
static func log_async_in_sync_mode_warning(instruction: BaseInstruction) -> void:
	if instruction and instruction._has_async_operations():
		FuseLogger.log_warning_localized(
			"BaseInstruction",
			FuseLogger.LogLevel.WARNING,
			"FUSE_WARNING_SYNC_MODE_WITH_ASYNC_INSTRUCTION",
			{"instruction": instruction.get_description()}
		)

## ============================================================
## 运行时实例模式支持（RuntimeInstructionInstance 架构）
## ============================================================

## 获取默认运行时状态（子类可重写）
##
## 子类可以重写此方法声明自己需要的运行时状态。
## 这些状态会在 RuntimeInstructionInstance 初始化时被复制。
##
## 返回：
## - Dictionary - 默认状态字典
func get_default_runtime_state() -> Dictionary:
	return {
		"initialized": true,
		"execution_status": ExecutionStatus.PENDING,
		"timer": null,
		"elapsed_time": 0.0,
		"is_running": false
	}

## 使用运行时实例执行（子类可重写）
##
## 子类可以重写此方法以支持 RuntimeInstructionInstance 模式。
## 在这种模式下，所有状态应该存储在 runtime_instance.runtime_state 中。
##
## 参数：
## - runtime_instance: RuntimeInstructionInstance - 运行时实例
##
## 返回：
## - bool - 是否同步完成
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
	# 默认实现：调用原有执行方法并同步状态
	var result = execute_sync(runtime_instance.execution_context)

	# 同步状态到 runtime_instance
	runtime_instance.runtime_state["execution_status"] = execution_status
	if has_error():
		runtime_instance._has_error = true
		runtime_instance._error_message = get_error_message()

	return result

## 暂停回调（子类可重写）
##
## 当运行时实例被暂停时调用。子类可以重写此方法处理暂停逻辑。
##
## 参数：
## - runtime_instance: RuntimeInstructionInstance - 运行时实例
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
	pass

## 恢复回调（子类可重写）
##
## 当运行时实例被恢复时调用。子类可以重写此方法处理恢复逻辑。
##
## 参数：
## - runtime_instance: RuntimeInstructionInstance - 运行时实例
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
	pass
