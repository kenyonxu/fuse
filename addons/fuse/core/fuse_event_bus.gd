# 文件：addons/fuse/core/fuse_event_bus.gd
extends Node

## Fuse 事件总线
##
## 提供全局事件通信机制，允许不同 Trigger 之间通过自定义事件进行通信。
## 支持 SendEvent 指令发送事件和 OnReceiveEvent 事件接收事件。
##
## 注意：此类通过 Autoload 注册为全局单例，可通过 FuseEventBus 直接访问。

## 信号

## 事件发送信号 (用于编辑器调试)
signal event_sent(event_name: String, args: Dictionary)

## 订阅信息类
class Subscription extends RefCounted:
	var event_name: String
	var callback: Callable
	var id: int


## 常量
const MAX_HISTORY_SIZE: int = 100  ## 最大历史记录数量

## 私有变量
var _listeners: Dictionary = {}  ## {event_name: [Subscription, ...]}
var _subscription_counter: int = 0
var _event_history: Array = []


## 生命周期

func _ready() -> void:
	# 注册运行时反射缓存自动清理（导出游戏中也生效）
	if get_tree():
		get_tree().node_removed.connect(_on_node_removed_for_reflection_cache)

func _on_node_removed_for_reflection_cache(node: Node) -> void:
	ReflectionCache.get_instance().clear_node(node)
	FunctionManager.clear_callable_cache(node)


## 发送事件
##
## 向所有监听该事件的订阅者发送事件
##
## 参数：
## - event_name: String - 事件名称
## - args: Dictionary - 事件参数（可选）
func send_event(event_name: String, args: Dictionary = {}) -> void:
	if event_name.is_empty():
		push_warning("FuseEventBus: " + FuseLocalization.translate("FUSE_ERROR_EVENT_NAME_EMPTY"))
		return

	# 记录历史
	_record_event(event_name, args)

	# 发出调试信号
	event_sent.emit(event_name, args)

	# 通知所有监听器
	if _listeners.has(event_name):
		var listeners = _listeners[event_name].duplicate()  # 避免迭代时修改
		for subscription in listeners:
			if subscription.callback.is_valid():
				subscription.callback.call(args)


## 延迟发送事件
##
## 在当前帧末尾发送事件，避免同一帧内过多事件处理
##
## 参数：
## - event_name: String - 事件名称
## - args: Dictionary - 事件参数（可选）
func send_event_deferred(event_name: String, args: Dictionary = {}) -> void:
	call_deferred("send_event", event_name, args)


## 订阅事件
##
## 注册一个回调函数来监听指定事件
##
## 参数：
## - event_name: String - 要监听的事件名称
## - callback: Callable - 事件触发时的回调函数，接收 Dictionary 参数
##
## 返回：
## - Subscription - 订阅对象，用于取消订阅
func subscribe(event_name: String, callback: Callable) -> Subscription:
	if event_name.is_empty():
		push_warning("FuseEventBus: " + FuseLocalization.translate("FUSE_LOG_EVENT_BUS_SUBSCRIBE_EMPTY_NAME"))
		return null

	if not _listeners.has(event_name):
		_listeners[event_name] = []

	var subscription = Subscription.new()
	subscription.event_name = event_name
	subscription.callback = callback
	subscription.id = _subscription_counter
	_subscription_counter += 1

	_listeners[event_name].append(subscription)

	print("[FuseEventBus] " + FuseLocalization.translate_format(
		"FUSE_LOG_EVENT_BUS_SUBSCRIBED",
		{"event": event_name, "count": _listeners[event_name].size()}
	))

	return subscription


## 取消订阅
##
## 移除之前注册的事件订阅
##
## 参数：
## - subscription: Subscription - 要取消的订阅对象
func unsubscribe(subscription: Subscription) -> void:
	if subscription == null:
		return

	if _listeners.has(subscription.event_name):
		var listeners = _listeners[subscription.event_name]
		var idx = listeners.find(subscription)
		if idx >= 0:
			listeners.remove_at(idx)
			print("[FuseEventBus] " + FuseLocalization.translate_format(
				"FUSE_LOG_EVENT_BUS_UNSUBSCRIBED",
				{"event": subscription.event_name, "count": listeners.size()}
			))

		# 清理空列表
		if listeners.is_empty():
			_listeners.erase(subscription.event_name)


## 检查事件是否有监听器
##
## 参数：
## - event_name: String - 事件名称
##
## 返回：
## - bool - 是否有监听器
func has_listeners(event_name: String) -> bool:
	return _listeners.has(event_name) and _listeners[event_name].size() > 0


## 获取事件监听器数量
##
## 参数：
## - event_name: String - 事件名称（空字符串表示获取总数）
##
## 返回：
## - int - 监听器数量
func get_listener_count(event_name: String = "") -> int:
	if event_name.is_empty():
		var total = 0
		for key in _listeners:
			total += _listeners[key].size()
		return total
	elif _listeners.has(event_name):
		return _listeners[event_name].size()
	return 0


## 获取所有已注册的事件名称
##
## 返回：
## - Array[String] - 事件名称列表
func get_registered_events() -> Array[String]:
	var events: Array[String] = []
	for key in _listeners:
		events.append(key)
	return events


## 获取事件历史
##
## 返回最近发送的事件历史记录
##
## 返回：
## - Array - 事件历史列表，每项包含 name, args, timestamp
func get_event_history() -> Array:
	return _event_history.duplicate()


## 清除事件历史
func clear_history() -> void:
	_event_history.clear()


## 清理所有监听器
##
## 移除所有事件订阅，通常在场景切换时调用
func clear_all_listeners() -> void:
	_listeners.clear()
	print("[FuseEventBus] " + FuseLocalization.translate("FUSE_LOG_EVENT_BUS_ALL_LISTENERS_CLEARED"))


## 私有方法

## 记录事件到历史
func _record_event(event_name: String, args: Dictionary) -> void:
	_event_history.append({
		"name": event_name,
		"args": args.duplicate(),
		"timestamp": Time.get_ticks_msec()
	})

	# 限制历史大小
	if _event_history.size() > MAX_HISTORY_SIZE:
		_event_history.pop_front()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# 清理所有监听器
		_listeners.clear()
