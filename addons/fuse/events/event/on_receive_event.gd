# 文件：addons/fuse/events/event/on_receive_event.gd
@tool
@icon("res://addons/fuse/icons/builtin/Signal.svg")
extends BaseEvent
class_name OnReceiveEvent

## OnReceiveEvent 事件
##
## 监听并响应自定义事件。
## 当 FuseEventBus 发出指定事件时触发，支持接收事件参数。

# =============================================
# 参数定义
# =============================================

## 监听的事件名称
@export var event_name: String = "":
	set(value):
		event_name = value
		_update_resource_name()

## 是否只触发一次
@export var trigger_once: bool = false

## 是否将参数存储到局部变量
@export var store_args_to_local: bool = true

## 局部变量前缀
@export var local_var_prefix: String = "event_"

# =============================================
# 运行时状态
# =============================================

## 订阅引用
var _subscription: RefCounted = null

## 缓存 owner_node 引用
var _owner_node_ref: Node = null

## 是否已触发（用于 trigger_once）
var _has_triggered: bool = false

# =============================================
# 元数据方法
# =============================================

## 获取事件元数据（必需）
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_RECEIVE_EVENT_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_EVENT"
	metadata.description_key = "FUSE_EVENT_ON_RECEIVE_EVENT_DESC"
	metadata.keywords = ["event", "receive", "listen", "subscribe", "事件", "接收", "监听", "订阅", "bus", "总线"]
	metadata.builtin_icon = "Signal"
	return metadata

# =============================================
# 资源名称和描述
# =============================================

## 更新资源名称（必需）
func _update_resource_name() -> void:
	if event_name.is_empty():
		resource_name = FuseLocalization.translate("FUSE_EVENT_ON_RECEIVE_EVENT_NAME")
	else:
		var once_text = " [%s]" % FuseLocalization.translate("FUSE_EVENT_TRIGGER_ONCE") if trigger_once else ""
		resource_name = "%s: %s%s" % [
			FuseLocalization.translate("FUSE_EVENT_ON_RECEIVE_EVENT_NAME"),
			event_name,
			once_text
		]


## 获取事件描述
func get_description() -> String:
	return FuseLocalization.translate_format("FUSE_EVENT_ON_RECEIVE_EVENT_DESCRIPTION", {
		"event_name": event_name if not event_name.is_empty() else FuseLocalization.translate("FUSE_EVENT_ON_RECEIVE_EVENT_NO_EVENT")
	})


## 获取事件类型
func get_event_type() -> String:
	return "receive_event"


## 获取事件分类
func get_event_category() -> String:
	return "event"

# =============================================
# 生命周期方法
# =============================================

## 初始化事件监听（向后兼容）
func initialize(owner_node: Node) -> void:
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_owner_node_ref = owner_node

	if event_name.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_EVENT_NAME_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 订阅事件
	_subscribe_to_event(owner_node)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})


## 使用 RuntimeEventInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		_log_debug("编辑器模式下，跳过事件初始化")
		return

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 保存运行时实例引用
	_runtime_instance_ref = runtime_instance
	_owner_node_ref = owner_node

	if event_name.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_EVENT_NAME_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 重置触发状态
	_has_triggered = false
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", false)

	# 订阅事件
	_subscribe_to_event(owner_node)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})


## 订阅事件
func _subscribe_to_event(owner_node: Node) -> void:
	# 通过 Autoload 访问 FuseEventBus
	var bus: Node = Engine.get_main_loop().root.get_node_or_null("FuseEventBus")
	if bus == null:
		_create_fuse_error_localized("FUSE_ERROR_EVENT_BUS_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
		return

	# 订阅事件，绑定 owner_node
	_subscription = bus.subscribe(event_name, _on_event_received.bind(owner_node))

	_log_debug_localized("FUSE_LOG_EVENT_SUBSCRIBED", {"event_name": event_name})


## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 取消订阅
	if _subscription != null:
		var bus: Node = Engine.get_main_loop().root.get_node_or_null("FuseEventBus")
		if bus != null:
			bus.unsubscribe(_subscription)
		_subscription = null
		_log_debug_localized("FUSE_LOG_EVENT_UNSUBSCRIBED", {"event_name": event_name})

	# 清理引用
	_owner_node_ref = null
	_has_triggered = false

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

# =============================================
# 事件处理
# =============================================

## 事件接收回调
func _on_event_received(args: Dictionary, owner_node: Node) -> void:
	# 检查是否只触发一次
	if trigger_once:
		# 使用 RuntimeEventInstance 的状态（如果可用）
		if _runtime_instance_ref:
			var has_triggered_state = _runtime_instance_ref.get_runtime_state("has_triggered")
			if has_triggered_state == true:
				_log_debug_localized("FUSE_LOG_EVENT_ALREADY_TRIGGERED", {})
				return
		elif _has_triggered:
			_log_debug_localized("FUSE_LOG_EVENT_ALREADY_TRIGGERED", {})
			return

	# 标记已触发
	_has_triggered = true
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", true)

	_log_info_localized("FUSE_LOG_EVENT_RECEIVED", {
		"event_name": event_name,
		"args_count": args.size()
	})

	# 调试：输出接收到的事件参数详情
	_log_debug("[OnReceiveEvent] ========== 事件参数接收 ==========")
	_log_debug("[OnReceiveEvent] 事件名称: %s" % event_name)
	_log_debug("[OnReceiveEvent] 参数数量: %d" % args.size())
	_log_debug("[OnReceiveEvent] store_args_to_local: %s" % store_args_to_local)
	_log_debug("[OnReceiveEvent] local_var_prefix: %s" % local_var_prefix)
	_log_debug("[OnReceiveEvent] _runtime_instance_ref 有效: %s" % (_runtime_instance_ref != null))
	for key in args:
		_log_debug("[OnReceiveEvent]   接收参数[%s] = %s (类型: %s)" % [key, args[key], typeof(args[key])])

	# 将参数存储到运行时状态
	if store_args_to_local and _runtime_instance_ref:
		_log_debug("[OnReceiveEvent] 开始存储参数到运行时状态...")
		for key in args:
			var var_name = local_var_prefix + key
			_runtime_instance_ref.set_runtime_state(var_name, args[key])
			# 调试：验证存储结果
			var stored_value = _runtime_instance_ref.get_runtime_state(var_name)
			_log_debug("[OnReceiveEvent]   存储变量: %s = %s (验证: %s)" % [var_name, args[key], stored_value])
		# 也存储完整参数字典
		_runtime_instance_ref.set_runtime_state("last_event_args", args.duplicate())
		var stored_args = _runtime_instance_ref.get_runtime_state("last_event_args")
		_log_debug("[OnReceiveEvent]   last_event_args 已存储，数量: %d" % stored_args.size())

		# 调试：输出所有运行时状态
		_log_debug("[OnReceiveEvent] 当前运行时状态:")
		var all_state = _runtime_instance_ref.get_all_runtime_states()
		for state_key in all_state:
			_log_debug("[OnReceiveEvent]   runtime_state[%s] = %s" % [state_key, all_state[state_key]])
	else:
		_log_debug("[OnReceiveEvent] 跳过存储参数 (store_args_to_local=%s, _runtime_instance_ref=%s)" % [store_args_to_local, _runtime_instance_ref != null])

	_log_debug("[OnReceiveEvent] ========== 参数处理完成 ==========")

	# 更新触发统计
	if _runtime_instance_ref:
		_runtime_instance_ref.update_trigger_stats()

	# 创建上下文节点传递事件信息
	var context_node = Node.new()
	context_node.name = "ReceiveEventContext"
	context_node.set_meta("event_name", event_name)
	context_node.set_meta("event_args", args.duplicate())
	context_node.set_meta("trigger", owner_node)

	# 发出触发信号
	triggered.emit(context_node)

	# 清理上下文节点
	context_node.queue_free()

	# 如果只触发一次，取消订阅
	if trigger_once and _subscription != null:
		var bus: Node = Engine.get_main_loop().root.get_node_or_null("FuseEventBus")
		if bus != null:
			bus.unsubscribe(_subscription)
		_subscription = null

# =============================================
# 验证和重置
# =============================================

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if event_name.is_empty():
		var error_msg := FuseLocalization.translate("FUSE_ERROR_EVENT_NAME_EMPTY")
		errors.append(error_msg)

	return errors


## 重置事件状态
func reset() -> void:
	super.reset()

	_has_triggered = false

	# 重置 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", false)
		_runtime_instance_ref.set_runtime_state("last_event_args", {})

	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})


## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base := super.get_default_runtime_state()
	base["has_triggered"] = false
	base["last_event_args"] = {}
	return base
