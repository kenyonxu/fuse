# 文件：addons/fuse/agent_skills/fuse-handoff-packer/assets/templates/event_bus.gd
## 事件总线——Fuse FuseEventBus 的脱离替代参考实现（推荐 autoload 命名 EventBus）
##
## API 形状与 Fuse FuseEventBus 对齐，preset 中 SendEvent / OnReceiveEvent
## 的用法可直译：
##   FuseDelegation 风格           → 本模板
##   FuseEventBus.send_event(...)   → EventBus.send_event(...)
##   subscribe(name, cb) -> Sub     → subscribe(name, cb) -> Dictionary
##   unsubscribe(sub)               → unsubscribe(sub)
## 订阅回调统一收 args: Dictionary。参考实现：同事件同步分发，无跨线程保证。
extends Node

signal event_sent(event_name: String, args: Dictionary)

# event_name -> Array[Dictionary]（条目形如 {"cb": Callable, "id": int}）
var _subscribers := {}
var _next_id := 0


## 发送总线事件：先广播 event_sent 信号，再同步调用全部订阅者
func send_event(event_name: String, args: Dictionary = {}) -> void:
	event_sent.emit(event_name, args)
	var list: Array = _subscribers.get(event_name, [])
	for entry in list:
		if entry.cb.is_valid():
			entry.cb.call(args)


## 延迟到帧末发送（对齐 FuseEventBus.send_event_deferred）
func send_event_deferred(event_name: String, args: Dictionary = {}) -> void:
	send_event.call_deferred(event_name, args)


## 订阅事件；返回订阅句柄（Dictionary），退订时原样传回 unsubscribe
func subscribe(event_name: String, callback: Callable) -> Dictionary:
	if not _subscribers.has(event_name):
		_subscribers[event_name] = []
	var list: Array = _subscribers[event_name]
	list.append({"cb": callback, "id": _next_id})
	var sub := {"event_name": event_name, "id": _next_id}
	_next_id += 1
	return sub


## 退订（句柄由 subscribe 返回；空句柄安全）
func unsubscribe(subscription: Dictionary) -> void:
	if subscription.is_empty():
		return
	var list: Array = _subscribers.get(subscription.get("event_name", ""), [])
	var target_id: int = subscription.get("id", -1)
	for i in range(list.size()):
		if list[i].id == target_id:
			list.remove_at(i)
			return
