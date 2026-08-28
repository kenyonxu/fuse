@tool
class_name ExecutionContext extends RefCounted

## 执行上下文类
##
## 提供指令执行时的环境和上下文信息，是指令与游戏世界交互的桥梁。
##
## 执行上下文包含以下主要功能：
## - 场景访问：获取场景树和节点
## - 变量管理：局部变量、全局变量和触发器变量的访问
## - 日志记录：统一的日志输出接口
## - 自定义数据存储：指令执行过程中的临时数据
## - 执行跟踪：执行时间和唯一标识符
##
## 使用示例：
## ```gdscript
## # 在指令中使用执行上下文
## func execute(context: ExecutionContext):
##     super.execute(context)
##
##     # 获取节点
##     var player = context.get_node("Player")
##
##     # 设置和获取变量
##     context.set_variable("score", 100)
##     var current_score = context.get_variable("score", 0)
##
##     # 记录日志
##     context.print_message("指令执行完成")
##
##     _on_execution_completed()
## ```

## 信号
signal cancel_requested                                ## 取消执行请求信号
signal execution_state_changed(new_state: int)         ## 执行状态改变信号

## 执行状态枚举
enum ExecutionState {
	IDLE,          # 空闲状态
	RUNNING,       # 运行中
	PAUSED,        # 暂停
	COMPLETED,     # 完成
	CANCELLED,     # 取消
	ERROR          # 错误
}

## 属性

var target: Node = null                                ## 目标节点，指令操作的主要对象
var trigger = null                                    ## 触发器节点，通常是触发指令执行的对象
var owner: Node = null                                ## 拥有者节点，创建此上下文的节点
var tree: SceneTree = null                             ## 场景树引用，用于访问场景中的节点
var local_variables: Dictionary = {}                   ## 局部变量字典(兼容引用,指向 _variable_context.local_variables)
var global_variables = null                           ## 全局变量容器引用(兼容引用,用于跨指令共享数据)
var _global_variable_assistant: GlobalVariableAssistant = null  ## 全局变量助手的类型化引用(兼容引用)
## 变量子系统(委托)
var _variable_context: VariableContext = null
## 诊断子系统(委托)
var _diagnostics: ExecutionDiagnostics = null
var custom_data: Dictionary = {}                      ## 自定义数据字典，存储特定于指令执行的数据
var execution_start_time: float = 0.0                 ## 执行开始时间（毫秒），用于计算执行时长
var execution_id: String = ""                         ## 唯一的执行标识符，用于跟踪和调试
var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.NONE       ## 日志输出级别
var action_runner = null                              ## ActionRunner 引用，用于控制执行流程
var delta_time: float = 0.0                           ## Delta 时间（秒），来自物理/帧回调

## WeakRef 支持的节点引用（内存优化）
var _target_weakref: WeakRef = null                    ## 目标节点的弱引用，避免内存泄漏
var _trigger_weakref: WeakRef = null                   ## 触发器节点的弱引用，避免内存泄漏

var _fuse_error: FuseError = null                  ## FuseError 实例，用于统一错误处理



## 初始化执行上下文
##
## 创建新的执行上下文实例，初始化执行时间和生成唯一执行ID。
##
## 此方法会：
## 1. 记录当前时间作为执行开始时间
## 2. 生成唯一的执行ID，格式为 "exec_[时间戳]_[随机数]"
## 3. 初始化执行状态
func _init(target_node: Node = null, trigger_node: Node = null, global_vars: Variant = null, scene_tree: SceneTree = null, owner_node: Node = null):
	execution_start_time = Time.get_ticks_msec()
	execution_id = _generate_execution_id()

	# 初始化属性
	target = target_node
	trigger = trigger_node
	global_variables = global_vars
	owner = owner_node

	# 初始化全局变量助手引用
	if global_vars != null:
		if global_vars is GlobalVariableAssistant:
			_global_variable_assistant = global_vars
		elif global_vars is GlobalVariableManager:
			# 如果传入的是 Manager，仍然通过 Assistant 访问
			_global_variable_assistant = GlobalVariableAssistant.get_instance()
		else:
			# 尝试获取单例
			_global_variable_assistant = GlobalVariableAssistant.get_instance()
	else:
		# 即使没有传入 global_vars，也尝试获取单例
		_global_variable_assistant = GlobalVariableAssistant.get_instance()

	tree = scene_tree

	# 设置弱引用
	if target_node:
		_target_weakref = weakref(target_node)
	if trigger_node:
		_trigger_weakref = weakref(trigger_node)

	# 创建诊断子系统（无条件：诊断/状态机为 EC 核心能力，不依赖 trigger 存在）
	_diagnostics = ExecutionDiagnostics.new(self)

	# 创建变量子系统（无条件：变量访问为 EC 核心能力，仅 target 存在即可。
	# 历史 bug B19：此块曾误嵌在 `if trigger_node:` 下，导致仅传 target 时
	# _variable_context/_diagnostics 为 nil → set_variable/get_variable 报 Nil。）
	_variable_context = VariableContext.new(self)
	_variable_context.global_variables = global_variables
	_variable_context.set_global_variable_assistant(_global_variable_assistant)
	# 兼容引用: EC 的 local_variables/global_variables 指向 VariableContext 的同一字典
	local_variables = _variable_context.local_variables
	global_variables = _variable_context.global_variables

	# 初始化执行状态
	reset_execution_state()

## 生成执行ID
##
## 生成唯一的执行标识符，用于跟踪和调试指令执行。
##
## 返回：
## - String - 格式为 "exec_[时间戳]_[随机数]" 的唯一标识符
func _generate_execution_id() -> String:
	return "exec_%d_%d" % [Time.get_ticks_msec(), randi()]

## 获取场景树
##
## 获取场景树的引用。如果未设置，尝试从当前场景获取。
##
## 返回：
## - SceneTree - 场景树引用，如果无法获取则返回 null
func get_tree() -> SceneTree:
	if not tree:
		# 尝试从当前场景获取树
		var current_scene = Engine.get_main_loop().current_scene
		if current_scene:
			tree = current_scene.get_tree()
	return tree

## 获取节点
##
## 根据路径获取场景中的节点。
##
## 参数：
## - path: NodePath - 节点路径，可以是相对路径或绝对路径
##
## 返回：
## - Node - 节点对象，如果找不到则返回 null
##
## 示例：
## ```gdscript
## # 获取玩家节点
## var player = context.get_node("Player")
##
## # 获取子节点
## var child = context.get_node("../OtherNode/Child")
## ```
func get_node(path: NodePath) -> Node:
	if path.is_empty():
		_log_error_localized("FUSE_ERROR_INVALID_NODE_PATH_EMPTY")
		return null

	# 优先从 trigger 节点查找（使用 FuseNodeUtils 多策略）
	if trigger:
		var found = FuseNodeUtils.find_node_at_runtime(trigger, path)
		if found:
			return found

	# 其次从 target 节点查找（使用 FuseNodeUtils 多策略）
	if target:
		var found = FuseNodeUtils.find_node_at_runtime(target, path)
		if found:
			return found

	# 尝试从当前场景获取
	var scene_tree = get_tree()
	if not scene_tree:
		_log_error_localized("FUSE_ERROR_SCENE_TREE_NOT_AVAILABLE")
		return null

	var current_scene = scene_tree.current_scene
	if current_scene:
		var found = FuseNodeUtils.find_node_at_runtime(current_scene, path)
		if found:
			return found

	# 如果路径是绝对路径，尝试从根节点获取
	if path.is_absolute():
		var root = scene_tree.root
		if root:
			var found = FuseNodeUtils.find_node_at_runtime(root, path)
			if found:
				return found

	# 查找未命中降为 debug：get_node 是查询型 API，调用方决定缺失是否为错误——
	# CheckNodeExists 反例（QueueFreeNode 后验证已删除）等合法模式不该被 push_error 染红
	_log_debug_localized("FUSE_ERROR_NODE_NOT_FOUND_AT_PATH", {"path": str(path)})
	return null

## 添加变量（接受 BaseVariable 对象）
##
## 将 BaseVariable 对象添加到执行上下文中
##
## 参数：
## - name: String - 变量名
## - variable: BaseVariable - 变量对象
##
## 返回：
## - bool - 是否成功添加
# ---- 变量门面(委托 VariableContext) ----

func add_variable(name: String, variable: BaseVariable) -> bool:
	return _variable_context.add_variable(name, variable)


func set_variable(name: String, value: Variant, scope: String = "local") -> bool:
	return _variable_context.set_variable(name, value, scope)


func get_variable(name: String, default: Variant = null, scope: String = "local") -> Variant:
	return _variable_context.get_variable(name, default, scope)


func get_variable_object(name: String) -> BaseVariable:
	return _variable_context.get_variable_object(name)


func has_variable(name: String) -> bool:
	return _variable_context.has_variable(name)


func get_global_variable_assistant() -> GlobalVariableAssistant:
	return _variable_context.get_global_variable_assistant()


func set_global_variable_assistant(assistant: GlobalVariableAssistant):
	_variable_context.set_global_variable_assistant(assistant)
	global_variables = assistant   # 保持兼容
	_global_variable_assistant = assistant


# ---- 循环控制门面(委托 VariableContext) ----

func set_break_loop():
	_variable_context.set_break_loop()


func set_continue_loop():
	_variable_context.set_continue_loop()


func should_break_loop() -> bool:
	return _variable_context.should_break_loop()


func should_continue_loop() -> bool:
	return _variable_context.should_continue_loop()


func clear_loop_flags():
	_variable_context.clear_loop_flags()


func push_loop_flags():
	_variable_context.push_loop_flags()


func pop_loop_flags():
	_variable_context.pop_loop_flags()


# ---- 索引访问门面(委托 VariableContext) ----

func precompile_variable_access(variable_names: Array[String]):
	_variable_context.precompile_variable_access(variable_names)


func set_variable_by_index(index: int, value: Variant):
	_variable_context.set_variable_by_index(index, value)


func get_variable_by_index(index: int) -> Variant:
	return _variable_context.get_variable_by_index(index)


func get_variable_index(name: String) -> int:
	return _variable_context.get_variable_index(name)


func is_indexed_access_enabled() -> bool:
	return _variable_context.is_indexed_access_enabled()


func get_indexed_access_stats() -> Dictionary:
	return _variable_context.get_indexed_access_stats()


# ---- 变量快照门面(委托 VariableContext) ----

func get_all_local_variables_snapshot() -> Dictionary:
	return _variable_context.get_all_local_variables_snapshot()


func get_all_scope_variables_snapshot() -> Dictionary:
	return _variable_context.get_all_scope_variables_snapshot()


func get_all_global_variables_snapshot() -> Dictionary:
	return _variable_context.get_all_global_variables_snapshot()
## 设置日志输出级别

func set_log_level(level: FuseLogger.LogLevel) -> void:
	var old_level = log_level
	log_level = level
	_log_info("日志级别已从 %s 更改为 %s" % [FuseLogger.LogLevel.keys()[old_level], FuseLogger.LogLevel.keys()[log_level]])

## 获取当前日志输出级别
##
## 返回：
## - FuseLogger.LogLevel - 当前日志级别
func get_log_level() -> FuseLogger.LogLevel:
	return log_level

## 打印消息
##
## 输出普通消息到控制台，使用统一的日志系统。
##
## 参数：
## - message: String - 消息内容
func print_message(message: String):
	FuseLogger.log_info("ExecutionContext", log_level, message, execution_id)

## 打印警告
##
## 输出警告消息到控制台，使用统一的日志系统。
##
## 参数：
## - message: String - 警告内容
func print_warning(message: String):
	FuseLogger.log_warning("ExecutionContext", log_level, message, execution_id)

## 打印错误
##
## 输出错误消息到控制台，使用统一的日志系统。
##
## 参数：
## - message: String - 错误内容
func print_error(message: String):
	FuseLogger.log_error("ExecutionContext", log_level, message, execution_id)

## 获取执行时间
##
## 获取自执行开始以来的时间（毫秒）。
##
## 返回：
## - float - 执行时间（毫秒）
##
## 示例：
## ```gdscript
## # 记录指令执行时间
## var elapsed = context.get_execution_time()
## context.print_message("指令执行耗时: %.2f 毫秒" % elapsed)
## ```
func get_execution_time() -> float:
	return Time.get_ticks_msec() - execution_start_time

## 添加自定义数据
##
## 存储自定义数据，用于指令执行过程中的临时信息交换。
##
## 参数：
## - key: String - 键
## - value: Variant - 值
##
## 示例：
## ```gdscript
## # 存储中间计算结果
## context.set_custom_data("intermediate_result", calculation_result)
##
## # 存储状态信息
## context.set_custom_data("current_state", "processing")
## ```
func set_custom_data(key: String, value: Variant):
	custom_data[key] = value

## 获取自定义数据
##
## 获取之前存储的自定义数据。
##
## 参数：
## - key: String - 键
## - default: Variant - 默认值，如果键不存在则返回此值
##
## 返回：
## - Variant - 值，如果找不到则返回默认值
##
## 示例：
## ```gdscript
## # 获取中间计算结果
## var result = context.get_custom_data("intermediate_result", 0)
##
## # 获取状态信息
## var state = context.get_custom_data("current_state", "unknown")
## ```
func get_custom_data(key: String, default: Variant = null) -> Variant:
	return custom_data.get(key, default)

## 设置 ActionRunner
## @param runner: ActionRunner 或 RuntimeActionRunnerInstance - ActionRunner 实例或运行时实例
func set_action_runner(runner):
	action_runner = runner
	_log_debug("ActionRunner 已设置: %s" % (str(runner) if runner else "null"))

## 获取 ActionRunner
## @return: ActionRunner 或 RuntimeActionRunnerInstance - ActionRunner 实例或运行时实例，如果未设置则返回 null
func get_action_runner():
	return action_runner

## 检查是否有 ActionRunner
## @return: bool - 是否有 ActionRunner
func has_action_runner() -> bool:
	return action_runner != null

## 清理执行上下文
##
## 清理执行上下文中的所有数据，释放引用。
##
## 此方法会：
## 1. 逐个清理局部变量，显式释放 RefCounted 对象
## 2. 逐个清理自定义数据，释放资源引用
## 3. 释放对场景树、目标节点和触发器的引用
## 4. 重置执行状态
## 5. 清理执行历史和弱引用
## 6. 清理优化缓存
func cleanup():
	# 清理变量子系统
	if _variable_context:
		_variable_context.cleanup()

	# 清理自定义数据字典（释放资源引用）
	for key in custom_data.keys():
		var value = custom_data[key]
		if is_instance_valid(value) and (value is Resource or value is RefCounted):
			custom_data[key] = null
	custom_data.clear()

	# 使用 WeakRef 清理节点引用
	if target and not target.is_queued_for_deletion():
		_log_debug("清理目标节点引用: %s" % target.name)
		target = null

	if trigger and not trigger.is_queued_for_deletion():
		_log_debug("清理触发器节点引用: %s" % trigger.name)
		trigger = null

	# 清理弱引用
	_target_weakref = null
	_trigger_weakref = null

	# 清理其他引用
	global_variables = null
	tree = null
	action_runner = null

	if _diagnostics:
		_diagnostics.cleanup()


	# 清理 FuseError 实例
	if _fuse_error:
		_fuse_error = null

	# 重置执行状态
	reset_execution_state()

	_log_debug_localized("FUSE_LOG_EXECUTION_CONTEXT_CLEANED")

## 复制执行上下文
##
## 创建执行上下文的副本，包括所有属性和数据。
##
## 返回：
## - ExecutionContext - 复制的上下文
##
## 注意：
## - 局部变量和自定义数据会进行深拷贝
## - 全局变量容器是引用拷贝（共享同一个容器）
## - 节点引用是浅拷贝（指向同一个节点对象）
func duplicate(p_deep: bool = true) -> ExecutionContext:
	var copy = ExecutionContext.new()
	copy.target = target
	copy.trigger = trigger
	copy.tree = tree
	# 弱引用同步（target/trigger 引用一致性）
	copy._target_weakref = _target_weakref
	copy._trigger_weakref = _trigger_weakref
	# 变量子系统深拷贝
	copy._variable_context = _variable_context.duplicate()
	copy._variable_context._owner = copy  # 更新 owner 引用
	# 兼容引用指向新 VariableContext 的字典
	copy.local_variables = copy._variable_context.local_variables
	copy.global_variables = global_variables
	copy._global_variable_assistant = _global_variable_assistant
	# 诊断子系统深拷贝（执行状态/历史/进度/监听器）
	# 历史 bug B11：duplicate 曾漏拷贝 _diagnostics，导致复制后执行历史/状态丢失。
	copy._diagnostics = _diagnostics.duplicate()
	copy._diagnostics._owner = copy  # 更新 owner 引用
	copy.custom_data = custom_data.duplicate(true)
	copy.execution_start_time = execution_start_time
	copy.execution_id = execution_id
	copy.log_level = log_level
	copy.owner = owner
	copy.action_runner = action_runner  # 共享 ActionRunner 引用
	# FuseError 深拷贝（独立错误实例）
	if _fuse_error:
		copy._fuse_error = _fuse_error.duplicate() if _fuse_error.has_method("duplicate") else _fuse_error
	return copy

## 获取上下文信息
##
## 获取包含上下文关键信息的字典，用于调试和日志记录。
##
## 返回：
## - Dictionary - 包含以下键的字典：
##   - execution_id: 执行ID
##   - execution_time: 执行时间（毫秒）
##   - target: 目标节点或"null"
##   - trigger: 触发器节点或"null"
##   - local_variables_count: 局部变量数量
##   - has_global_variables: 是否有全局变量容器
##   - custom_data_count: 自定义数据项数量
##
## 示例：
## ```gdscript
## # 输出上下文信息用于调试
## var info = context.get_info()
## context.print_message("上下文信息: %s" % info)
## ```
func get_info() -> Dictionary:
	return {
		"execution_id": execution_id,
		"execution_time": get_execution_time(),
		"target": target if target else "null",
		"trigger": trigger if trigger else "null",
		"local_variables_count": local_variables.size(),
		"has_global_variables": global_variables != null,
		"custom_data_count": custom_data.size(),
		"execution_state": ExecutionState.keys()[_diagnostics.get_execution_state()],
		"execution_progress": _diagnostics.get_execution_progress(),
		"is_cancelled": _diagnostics.is_cancelled(),
		"error_message": _diagnostics.get_error_message(),
		"has_action_runner": action_runner != null
	}

# ---- 状态管理门面(委托 Diagnostics) ----

func get_execution_state() -> ExecutionState:
	return _diagnostics.get_execution_state() as ExecutionState


func set_execution_state(state: ExecutionState):
	_diagnostics.set_execution_state(state)


func reset_execution_state():
	_diagnostics.reset_execution_state()


func is_running() -> bool:
	return _diagnostics.is_running()


func is_completed() -> bool:
	return _diagnostics.is_completed()


func has_error() -> bool:
	return _diagnostics.has_error()


func is_cancelled() -> bool:
	return _diagnostics.is_cancelled()


func request_cancel():
	_diagnostics.request_cancel()


func get_execution_progress() -> float:
	return _diagnostics.get_execution_progress()


func set_execution_progress(progress: float):
	_diagnostics.set_execution_progress(progress)


func get_error_message() -> String:
	return _diagnostics.get_error_message()


func set_error_message(message: String, error_type: FuseError.ErrorType = FuseError.ErrorType.RUNTIME_ERROR, context: Dictionary = {}):
	_diagnostics.set_error_message(message, error_type, context)
	# 创建 FuseError 实例
	var error_context = context.duplicate()
	error_context["execution_id"] = execution_id
	error_context["execution_state"] = ExecutionState.keys()[_diagnostics.get_execution_state()]
	_create_fuse_error(message, error_type, error_context)
	_log_error("Execution error: %s" % message)


func _record_execution_history(state: ExecutionState, message: String = "", data: Dictionary = {}):
	_diagnostics._record_execution_history(state, message, data)


# ---- 历史/监听器/统计门面(委托 Diagnostics) ----

func get_execution_history(limit: int = 0) -> Array[Dictionary]:
	return _diagnostics.get_execution_history(limit)


func clear_execution_history():
	_diagnostics.clear_execution_history()


func add_state_change_listener(listener: Callable):
	_diagnostics.add_state_change_listener(listener)


func remove_state_change_listener(listener: Callable):
	_diagnostics.remove_state_change_listener(listener)


func _notify_state_change(old_state: ExecutionState, new_state: ExecutionState):
	_diagnostics._notify_state_change(old_state, new_state)


func get_state_statistics() -> Dictionary:
	return _diagnostics.get_state_statistics()


func get_recent_state_changes(count: int = 10) -> Array[Dictionary]:
	return _diagnostics.get_recent_state_changes(count)


# ---- 依赖图门面(委托 Diagnostics) ----

func get_dependency_graph() -> Dictionary:
	return _diagnostics.get_dependency_graph()


func _collect_all_variables() -> Dictionary:
	return _diagnostics._collect_all_variables()


func check_dependencies(dependencies: Array[String]) -> Dictionary:
	return _diagnostics.check_dependencies(dependencies)


func get_dependency_status() -> Dictionary:
	return _diagnostics.get_dependency_status()


func check_dependencies_batch(dependencies_list: Array) -> Array:
	return _diagnostics.check_dependencies_batch(dependencies_list)


func get_dependency_visualization_data() -> Dictionary:
	var data = _diagnostics.get_dependency_visualization_data()
	# 如果有 FuseError，添加错误信息
	if _fuse_error:
		data["fuse_error"] = _fuse_error.get_error_details()
	return data

func create_with_params(target_node: Node = null, trigger_node: Node = null, global_vars: Variant = null, scene_tree: SceneTree = null) -> ExecutionContext:
	var context = ExecutionContext.new()
	context.target = target_node
	context.trigger = trigger_node
	context.global_variables = global_vars
	context.tree = scene_tree
	return context

## 统一日志方法
func _log_debug(message: String):
	FuseLogger.log_debug("ExecutionContext", log_level, message, execution_id)

func _log_info(message: String):
	FuseLogger.log_info("ExecutionContext", log_level, message, execution_id)

func _log_warning(message: String):
	FuseLogger.log_warning("ExecutionContext", log_level, message, execution_id)

func _log_error(message: String):
	FuseLogger.log_error("ExecutionContext", log_level, message, execution_id)

## 本地化日志方法
func _log_debug_localized(message_key: String, args: Dictionary = {}) -> void:
	FuseLogger.log_debug_localized("ExecutionContext", log_level, message_key, args, execution_id)

func _log_info_localized(message_key: String, args: Dictionary = {}) -> void:
	FuseLogger.log_info_localized("ExecutionContext", log_level, message_key, args, execution_id)

func _log_warning_localized(message_key: String, args: Dictionary = {}) -> void:
	FuseLogger.log_warning_localized("ExecutionContext", log_level, message_key, args, execution_id)

func _log_error_localized(message_key: String, args: Dictionary = {}) -> void:
		FuseLogger.log_error_localized("ExecutionContext", log_level, message_key, args, execution_id)
## 创建 FuseError 实例
## message: String - 错误消息
## error_type: FuseError.ErrorType - 错误类型
## context: Dictionary - 错误上下文
func _create_fuse_error(message: String, error_type: FuseError.ErrorType = FuseError.ErrorType.RUNTIME_ERROR, context: Dictionary = {}):
	var error_context = context.duplicate()
	error_context["execution_id"] = execution_id

	_fuse_error = FuseError.create_with_context(error_type, "ExecutionContext", message, error_context)

## 获取 FuseError 实例
## returns: FuseError - FuseError 实例，如果没有错误则返回 null
func get_fuse_error() -> FuseError:
	return _fuse_error

## 检查是否有 FuseError
## returns: bool - 是否有 FuseError
func has_fuse_error() -> bool:
	return _fuse_error != null

## 检查是否有错误（别名方法，用于向后兼容）
## returns: bool - 是否有错误
func had_error() -> bool:
	return has_fuse_error()

func set_target_node(node: Node):
	target = node
	_target_weakref = weakref(node) if node else null
	_log_debug("目标节点已设置: %s" % (node.get_name() if node else "null"))

## 获取目标节点（支持 WeakRef）
## @return: Node - 目标节点，如果节点已释放则返回 null
func get_target_node() -> Node:
	# 首先检查弱引用
	if _target_weakref:
		var node = _target_weakref.get_ref()
		if node:
			return node
		else:
			_log_warning_localized("FUSE_WARNING_TARGET_NODE_RELEASED")
			target = null
			_target_weakref = null

	# 回退到直接引用
	return target

## 设置触发器节点（支持 WeakRef）
## @param node: Node - 触发器节点
func set_trigger_node(node: Node):
	trigger = node
	_trigger_weakref = weakref(node) if node else null
	_log_debug("触发器节点已设置: %s" % (node.get_name() if node else "null"))

## 获取触发器节点（支持 WeakRef）
## @return: Node - 触发器节点，如果节点已释放则返回 null
func get_trigger_node() -> Node:
	# 首先检查弱引用
	if _trigger_weakref:
		var node = _trigger_weakref.get_ref()
		if node:
			return node
		else:
			_log_warning_localized("FUSE_WARNING_TRIGGER_NODE_RELEASED")
			trigger = null
			_trigger_weakref = null

	# 回退到直接引用
	return trigger
