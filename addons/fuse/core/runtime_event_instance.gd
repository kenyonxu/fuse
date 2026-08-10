# 文件：addons/fuse/core/runtime_event_instance.gd
@tool
class_name RuntimeEventInstance extends RefCounted

## 运行时事件实例类
##
## 提供轻量级的运行时事件实例，避免不必要的资源复制。
## 这个类包装了事件定义，并为每个触发器提供独立的运行时状态。

## 信号
signal triggered(context: Node)  ## 事件触发信号，每个实例独立发出

## 属性
var event_definition: BaseEvent                    ## 事件定义资源
var runtime_state: Dictionary = {}                 ## 运行时状态字典
var owner_trigger: Node                           ## 拥有此实例的触发器节点
var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.INFO  ## 日志输出级别

## 构造函数
func _init(definition: BaseEvent, trigger: Node):
	event_definition = definition
	owner_trigger = trigger

	# 初始化运行时状态
	_initialize_runtime_state()

	# 🔧 连接到 Event 资源的 triggered 信号，然后转发给自己的信号
	# 这样每个 RuntimeEventInstance 都有独立的信号，不会相互干扰
	if event_definition and event_definition.has_signal("triggered"):
		event_definition.triggered.connect(_on_event_triggered)

	_log_debug("RuntimeEventInstance 创建完成: %s" % get_description())

## 初始化运行时状态
##
## 优先使用 Event 的自声明状态模式，回退到遗留的 match 分支模式
func _initialize_runtime_state():
	if not event_definition:
		_log_warning("没有事件定义，无法初始化运行时状态")
		return

	# 🔧 新架构：检查 Event 是否实现了自声明状态模式
	if event_definition.has_method("get_default_runtime_state"):
		var declared_state = event_definition.get_default_runtime_state()
		# 深度复制状态以避免共享引用
		runtime_state = declared_state.duplicate(true)
		_log_debug("使用 Event 自声明状态模式初始化: %s, 状态数: %d" % [event_definition.get_event_type(), runtime_state.size()])
		_ensure_base_states()
		return

	# 遗留架构：使用 match 分支初始化（向后兼容）
	_initialize_runtime_state_legacy()
	_log_debug("使用遗留 match 分支模式初始化: %s" % event_definition.get_event_type())

## 遗留的运行时状态初始化方法（向后兼容）
##
## 使用 match 分支为不同事件类型初始化运行时状态
## 这是旧架构的保留实现，仅用于未迁移的 Events
##
## 已迁移的 Events（使用自声明状态模式）：
## - OnInterval, OnInputKey, OnTimer, OnArea2DEnter, OnArea3DEntered
## - OnSignalFromGroup, OnPropertyChanged, OnVariableChanged
## - OnMouseButton, OnCooldownFinished, OnMouseEnter, OnMouseExit
func _initialize_runtime_state_legacy():
	# 根据事件类型初始化特定的运行时状态
	match event_definition.get_event_type():
		"timer":
			runtime_state["timer"] = null
			runtime_state["elapsed_time"] = 0.0
			runtime_state["is_running"] = false
			runtime_state["duration"] = 1.0  # 默认持续时间
		"input":
			runtime_state["input_state"] = {}
			runtime_state["last_input_time"] = 0.0
			runtime_state["input_buffer"] = []
		"collision":
			runtime_state["collision_count"] = 0
			runtime_state["last_collision_time"] = 0.0
			runtime_state["colliding_bodies"] = []
		"area":
			runtime_state["entered_bodies"] = []
			runtime_state["exited_bodies"] = []
			runtime_state["current_bodies"] = []
		"signal":
			runtime_state["signal_count"] = 0
			runtime_state["last_signal_time"] = 0.0
			runtime_state["signal_args"] = []
		"variable":
			runtime_state["variable_name"] = ""
			runtime_state["last_value"] = null
			runtime_state["change_count"] = 0
		_:
			# 默认状态（用于未声明的 Events）
			runtime_state["initialized"] = true
			runtime_state["trigger_count"] = 0
			runtime_state["last_trigger_time"] = 0.0

	_log_debug("运行时状态已初始化（遗留模式），事件类型: %s" % event_definition.get_event_type())

## Event 资源的 triggered 信号回调
##
## 当 Event 资源发出 triggered 信号时，转发给 RuntimeEventInstance 自己的信号
## 这样每个 RuntimeEventInstance 都有独立的信号，不会相互干扰
func _on_event_triggered(context: Node):
	# 🔧 检查 Trigger 是否匹配
	# 只有当事件来自对应的 Trigger 时才转发
	# 这解决了多个 Trigger 共享同一个 Event 资源时的信号干扰问题
	# 修复：owner_trigger 可能已被释放（例如切换场景），先校验有效性。
	if owner_trigger == null or not is_instance_valid(owner_trigger):
		return

	if context and is_instance_valid(context) and context.has_meta("trigger"):
		var event_trigger = context.get_meta("trigger")
		if event_trigger != owner_trigger:
			# 不是我们触发器的事件，忽略
			return

	# 发出 RuntimeEventInstance 自己的 triggered 信号
	triggered.emit(context)

## 获取运行时状态
##
## 参数：
## - key: String - 状态键
##
## 返回：
## - Variant - 状态值，如果不存在则返回 null
func get_runtime_state(key: String):
	return runtime_state.get(key, null)

## 设置运行时状态
##
## 参数：
## - key: String - 状态键
## - value: Variant - 状态值
func set_runtime_state(key: String, value):
	runtime_state[key] = value
	_log_debug("运行时状态已更新: %s = %s" % [key, str(value)])

## 检查运行时状态是否存在
##
## 参数：
## - key: String - 状态键
##
## 返回：
## - bool - 状态是否存在
func has_runtime_state(key: String) -> bool:
	return runtime_state.has(key)

## 移除运行时状态
##
## 参数：
## - key: String - 状态键
func remove_runtime_state(key: String):
	if runtime_state.has(key):
		runtime_state.erase(key)
		_log_debug("运行时状态已移除: %s" % key)

## 获取所有运行时状态
##
## 返回：
## - Dictionary - 所有运行时状态的副本
func get_all_runtime_states() -> Dictionary:
	return runtime_state.duplicate()

## 重置运行时状态
##
## 重新初始化运行时状态，清除所有现有状态
func reset_runtime_state():
	runtime_state.clear()
	_initialize_runtime_state()
	_log_debug("运行时状态已重置")

## 更新触发统计
##
## 更新触发相关的统计信息
func update_trigger_stats():
	runtime_state["trigger_count"] = runtime_state.get("trigger_count", 0) + 1
	runtime_state["last_trigger_time"] = Time.get_ticks_msec() / 1000.0
	_log_debug("触发统计已更新")

## 清理运行时实例
##
## 清理所有引用和状态，准备销毁
func cleanup():
	_log_debug("开始清理 RuntimeEventInstance")

	# 断开 Event 资源的信号连接
	if event_definition and event_definition.has_signal("triggered"):
		if event_definition.triggered.is_connected(_on_event_triggered):
			event_definition.triggered.disconnect(_on_event_triggered)

	# 清理运行时状态
	runtime_state.clear()

	# 清理引用
	event_definition = null
	owner_trigger = null

	_log_debug("RuntimeEventInstance 清理完成")

## 获取运行时实例描述
##
## 返回：
## - String - 运行时实例的描述文本
func get_description() -> String:
	if event_definition:
		return "RuntimeEventInstance: %s" % event_definition.get_description()
	return "RuntimeEventInstance (无事件定义)"

## 获取运行时实例信息
##
## 返回：
## - Dictionary - 包含运行时实例信息的字典
func get_info() -> Dictionary:
	return {
		"event_type": event_definition.get_event_type() if event_definition else "none",
		"event_description": event_definition.get_description() if event_definition else "无事件定义",
		"owner_trigger": owner_trigger.get_name() if owner_trigger and is_instance_valid(owner_trigger) else "无触发器",
		"runtime_state_count": runtime_state.size(),
		"has_event_definition": event_definition != null,
		"has_owner_trigger": owner_trigger != null and is_instance_valid(owner_trigger)
	}

## 验证运行时实例
##
## 返回：
## - Array[String] - 验证错误列表，空数组表示验证通过
func validate() -> Array[String]:
	var errors: Array[String] = []
	
	if not event_definition:
		errors.append(FuseLocalization.translate("FUSE_ERROR_NO_EVENT_DEFINITION"))
	
	if not owner_trigger:
		errors.append(FuseLocalization.translate("FUSE_ERROR_NO_TRIGGER_NODE"))
	elif not is_instance_valid(owner_trigger):
		errors.append(FuseLocalization.translate("FUSE_ERROR_TRIGGER_NODE_INVALID"))
	
	return errors

## 创建 FuseError 实例
func _create_fuse_error(message: String, error_type: FuseError.ErrorType = FuseError.ErrorType.RUNTIME_ERROR, context: Dictionary = {}):
	var error_context = context.duplicate()
	error_context["event_type"] = event_definition.get_event_type() if event_definition else "unknown"
	error_context["event_description"] = event_definition.get_description() if event_definition else "无事件定义"
	error_context["owner_trigger"] = owner_trigger.get_name() if owner_trigger else "无触发器"
	
	return FuseError.create_with_context(error_type, "RuntimeEventInstance", message, error_context)

## 统一日志方法
func _log_debug(message: String) -> void:
	FuseLogger.log_debug("RuntimeEventInstance", log_level, message)

func _log_info(message: String) -> void:
	FuseLogger.log_info("RuntimeEventInstance", log_level, message)

func _log_warning(message: String) -> void:
	FuseLogger.log_warning("RuntimeEventInstance", log_level, message)

func _log_error(message: String) -> void:
	FuseLogger.log_error("RuntimeEventInstance", log_level, message)

## 确保基础状态存在
##
## 确保 Event 的基础状态（initialized, trigger_count, last_trigger_time）存在
## 这是为了向后兼容和保证所有 Events 都有基础状态
func _ensure_base_states():
	if not runtime_state.has("initialized"):
		runtime_state["initialized"] = true
	if not runtime_state.has("trigger_count"):
		runtime_state["trigger_count"] = 0
	if not runtime_state.has("last_trigger_time"):
		runtime_state["last_trigger_time"] = 0.0

## 启动事件监听
##
## 代理方法，调用 event_definition 的 initialize_with_runtime_instance
## 这是 MultiEventTrigger 调用的接口
func start_listening() -> void:
	if event_definition and owner_trigger:
		event_definition.initialize_with_runtime_instance(owner_trigger, self)
		_log_debug("事件监听已启动: %s" % get_description())

## 停止事件监听
##
## 代理方法，调用 event_definition 的 terminate
## 这是 MultiEventTrigger 调用的接口
func stop_listening() -> void:
	if event_definition and owner_trigger:
		event_definition.terminate(owner_trigger)
		_log_debug("事件监听已停止: %s" % get_description())
