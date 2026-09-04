# 文件：addons/fuse/core/runner.gd
@tool
@icon("res://addons/fuse/icons/builtin/ViewportSpeed.png")
class_name Runner extends Node

## ============================================
## 属性
## ============================================

## 要执行的 ActionRunner 资源
@export_storage var action_runner: ActionRunner:
	set(value):
		action_runner = value
		_clear_runtime_instance()

## 自动绑定信号的目标节点路径
@export_storage var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_disconnect_signal_binding()
		# 编辑器中刷新可用信号列表
		if Engine.is_editor_hint() and not target_node.is_empty():
			_editor_is_refreshing = false
			call_deferred("_editor_refresh_signals")

## 要绑定的信号名称
@export_storage var signal_name: String = "":
	set(value):
		signal_name = value
		_disconnect_signal_binding()

## 日志级别
@export_storage var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.NONE

## 当前执行上下文(运行时设置,变量监视器读取)
var current_execution_context: ExecutionContext = null
var current_execution_context_at_ms: int = 0

## ============================================
## 信号
## ============================================

## 执行完成信号
signal execution_completed(total_time: float)

## 执行失败信号
signal execution_failed(error_message: String)

## 执行取消信号
signal execution_canceled(reason: String)

## 内部完成信号（用于 wait_completed）
signal _internal_completed()

## ============================================
## 内部状态
## ============================================

## RuntimeActionRunnerInstance 实例
var _runtime_instance: RuntimeActionRunnerInstance = null

## 信号绑定的目标节点引用
var _bound_node: Node = null

## 外部信号是否已连接
var _signal_connected: bool = false

## RuntimeActionRunnerInstance 信号是否已连接
var _runtime_signals_connected: bool = false

## 编辑器信号缓存
var _editor_available_signals: Array = []
var _editor_signals_loaded: bool = false
var _editor_is_refreshing: bool = false

## ============================================
## 生命周期方法
## ============================================

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# 创建 RuntimeActionRunnerInstance
	if action_runner:
		_runtime_instance = RuntimeActionRunnerInstance.new(action_runner, self)
		_connect_runtime_signals()

	# 自动绑定信号
	_setup_signal_binding()

## 动态属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	# === Action Runner ===
	properties.append({
		"name": "action_runner",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_GROUP | PROPERTY_USAGE_INTERNAL
	})
	properties.append({
		"name": "action_runner",
		"type": TYPE_OBJECT,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": "ActionRunner",
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# === Signal Binding ===
	properties.append({
		"name": "signal_binding",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_GROUP | PROPERTY_USAGE_INTERNAL
	})
	properties.append({
		"name": "target_node",
		"type": TYPE_NODE_PATH,
		"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		"hint_string": "Node",
		"usage": PROPERTY_USAGE_DEFAULT
	})

	# signal_name — 动态 hint：有信号时下拉选择，无信号时文本输入
	var signal_names = _get_signal_names()
	if not signal_names.is_empty():
		properties.append({
			"name": "signal_name",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": ",".join(signal_names),
			"usage": PROPERTY_USAGE_DEFAULT
		})
	else:
		properties.append({
			"name": "signal_name",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_DEFAULT
		})

	# === Configuration ===
	properties.append({
		"name": "configuration",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_GROUP | PROPERTY_USAGE_INTERNAL
	})
	properties.append({
		"name": "log_level",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "NONE,DEBUG,INFO,WARNING,ERROR",
		"usage": PROPERTY_USAGE_DEFAULT
	})

	return properties

func _exit_tree() -> void:
	_disconnect_signal_binding()
	_disconnect_runtime_signals()

	if _runtime_instance:
		_runtime_instance.cleanup()
		_runtime_instance = null

## ============================================
## 编辑器信号发现
## ============================================

## 获取信号名称列表（编辑器用）
func _get_signal_names() -> Array[String]:
	if Engine.is_editor_hint():
		if _editor_is_refreshing:
			return []
		var names: Array[String] = []
		for sig_info in _editor_available_signals:
			names.append(sig_info.name)
		return names
	return []

## 编辑器中刷新可用信号列表
func _editor_refresh_signals() -> void:
	if target_node.is_empty():
		_editor_is_refreshing = false
		return

	_editor_available_signals.clear()
	_editor_signals_loaded = false

	var target = _get_target_node_in_editor()
	if not target:
		_editor_is_refreshing = false
		return

	_editor_available_signals = SignalManager.get_node_signals(target)
	_editor_signals_loaded = true

	notify_property_list_changed()
	_editor_is_refreshing = false

## 编辑器中获取目标节点
func _get_target_node_in_editor() -> Node:
	if target_node.is_empty():
		return null
	# Runner 是场景中的 Node，直接解析相对路径
	return get_node_or_null(target_node)

## ============================================
## 运行时实例管理
## ============================================

## 清理运行时实例
func _clear_runtime_instance() -> void:
	if _runtime_instance:
		_disconnect_runtime_signals()
		_runtime_instance.cleanup()
		_runtime_instance = null

## 连接 RuntimeActionRunnerInstance 信号
func _connect_runtime_signals() -> void:
	if not _runtime_instance or _runtime_signals_connected:
		return

	# 连接执行完成信号
	if _runtime_instance.has_signal("execution_completed"):
		if not _runtime_instance.execution_completed.is_connected(_on_runtime_execution_completed):
			_runtime_instance.execution_completed.connect(_on_runtime_execution_completed)

	# 连接执行失败信号
	if _runtime_instance.has_signal("execution_failed"):
		if not _runtime_instance.execution_failed.is_connected(_on_runtime_execution_failed):
			_runtime_instance.execution_failed.connect(_on_runtime_execution_failed)

	# 连接执行取消信号
	if _runtime_instance.has_signal("execution_canceled"):
		if not _runtime_instance.execution_canceled.is_connected(_on_runtime_execution_canceled):
			_runtime_instance.execution_canceled.connect(_on_runtime_execution_canceled)

	_runtime_signals_connected = true

## 断开 RuntimeActionRunnerInstance 信号
func _disconnect_runtime_signals() -> void:
	if not _runtime_instance or not _runtime_signals_connected:
		return

	if _runtime_instance.has_signal("execution_completed"):
		if _runtime_instance.execution_completed.is_connected(_on_runtime_execution_completed):
			_runtime_instance.execution_completed.disconnect(_on_runtime_execution_completed)

	if _runtime_instance.has_signal("execution_failed"):
		if _runtime_instance.execution_failed.is_connected(_on_runtime_execution_failed):
			_runtime_instance.execution_failed.disconnect(_on_runtime_execution_failed)

	if _runtime_instance.has_signal("execution_canceled"):
		if _runtime_instance.execution_canceled.is_connected(_on_runtime_execution_canceled):
			_runtime_instance.execution_canceled.disconnect(_on_runtime_execution_canceled)

	_runtime_signals_connected = false

## ============================================
## 信号绑定
## ============================================

## 设置信号绑定
func _setup_signal_binding() -> void:
	if target_node.is_empty() or signal_name.is_empty():
		return

	# 获取目标节点
	_bound_node = get_node_or_null(target_node)
	if not _bound_node:
		_log_warning("无法找到目标节点: %s" % target_node)
		return

	# 检查信号是否存在
	if not SignalManager.has_signal_named(_bound_node, signal_name):
		_log_warning("节点 %s 没有信号 %s" % [_bound_node.name, signal_name])
		return

	# 连接信号
	if not _signal_connected:
		_bound_node.connect(signal_name, _on_bound_signal_triggered)
		_signal_connected = true
		_log_debug("信号绑定成功: %s.%s" % [_bound_node.name, signal_name])

## 断开信号绑定
func _disconnect_signal_binding() -> void:
	if _signal_connected and _bound_node and is_instance_valid(_bound_node):
		if _bound_node.is_connected(signal_name, _on_bound_signal_triggered):
			_bound_node.disconnect(signal_name, _on_bound_signal_triggered)
	_signal_connected = false
	_bound_node = null

## ============================================
## 公共 API
## ============================================

## 执行 ActionRunner
##
## 参数：
## - context_node: Node - 上下文节点（可选，默认为 Runner 自身）
func run(context_node: Node = null) -> void:
	if not action_runner or not _runtime_instance:
		_log_warning("ActionRunner 未配置或运行时实例未初始化")
		return

	# 检查是否正在执行
	if is_running():
		_log_warning("Runner is already running")
		return

	var target = context_node if context_node else self
	var execution_context = _create_execution_context(target)
	current_execution_context = execution_context
	current_execution_context_at_ms = Time.get_ticks_msec()

	_log_debug("开始执行 ActionRunner")
	_runtime_instance.run(execution_context)

## 取消执行
##
## 参数：
## - reason: String - 取消原因
func cancel(reason: String = "") -> void:
	if _runtime_instance:
		_runtime_instance.cancel_execution(reason)

## 停止当前执行（不带原因）
func stop() -> void:
	cancel("")

## 检查是否正在运行
##
## 返回：
## - bool - 是否正在运行
func is_running() -> bool:
	return _runtime_instance != null and _runtime_instance.is_running()

## 是否正在取消
func is_canceling() -> bool:
	if not _runtime_instance:
		return false
	return _runtime_instance.get_runtime_state("is_canceling") == true

## 等待执行完成（awaitable）
func wait_completed() -> void:
	if not is_running():
		return
	await _internal_completed

## 获取执行状态详情
func get_execution_status() -> Dictionary:
	if not _runtime_instance:
		return {
			"is_running": false,
			"is_canceling": false,
			"has_action_runner": action_runner != null,
			"signal_bound": _signal_connected
		}
	return {
		"is_running": _runtime_instance.is_running(),
		"is_canceling": _runtime_instance.get_runtime_state("is_canceling") == true,
		"has_action_runner": action_runner != null,
		"signal_bound": _signal_connected
	}

## 重置状态
func reset() -> void:
	# 取消正在执行的任务
	if _runtime_instance and _runtime_instance.is_running():
		_runtime_instance.cancel_execution("Reset called")

	# 断开信号绑定
	_disconnect_signal_binding()

	# 断开运行时信号
	_disconnect_runtime_signals()

	# 清理运行时实例
	if _runtime_instance:
		_runtime_instance.cleanup()
		_runtime_instance = null

	_log_debug("Runner reset")

## ============================================
## 内部方法
## ============================================

## 创建执行上下文
func _create_execution_context(target: Node) -> RefCounted:
	var context = ExecutionContext.new(target, self)
	context.log_level = log_level
	return context

## 绑定信号触发回调
func _on_bound_signal_triggered(_reason: String = "", _context: Dictionary = {}) -> void:
	run()

## RuntimeActionRunnerInstance 完成回调
func _on_runtime_execution_completed(total_time: float) -> void:
	_internal_completed.emit()
	_log_debug("执行完成: %.3f 秒" % total_time)
	execution_completed.emit(total_time)

## RuntimeActionRunnerInstance 失败回调
func _on_runtime_execution_failed(error_message: String) -> void:
	_log_error("执行失败: %s" % error_message)
	execution_failed.emit(error_message)

## RuntimeActionRunnerInstance 取消回调
func _on_runtime_execution_canceled(reason: String) -> void:
	_log_debug("执行取消: %s" % reason)
	execution_canceled.emit(reason)

## ============================================
## 日志方法
## ============================================

func _log_debug(message: String) -> void:
	FuseLogger.log_debug("Runner", log_level, message, name)

func _log_info(message: String) -> void:
	FuseLogger.log_info("Runner", log_level, message, name)

func _log_warning(message: String) -> void:
	FuseLogger.log_warning("Runner", log_level, message, name)

func _log_error(message: String) -> void:
	FuseLogger.log_error("Runner", log_level, message, name)
