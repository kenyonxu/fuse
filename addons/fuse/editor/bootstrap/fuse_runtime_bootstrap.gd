@tool
class_name FuseRuntimeBootstrap extends RefCounted

## Fuse 运行时基础设施引导
##
## 负责：FuseEventBus / FuseRuntimeBridge Autoload 注册/注销、
## 反射缓存自动清理（节点删除时清理 PropertyManager/SignalManager/FunctionManager 缓存）。

const BRIDGE_PATH := "res://addons/fuse/core/fuse_runtime_bridge.gd"

var _plugin: EditorPlugin

func _init(plugin: EditorPlugin) -> void:
	_plugin = plugin

func setup() -> void:
	_register_event_bus()
	_register_reflection_cache_cleanup()
	_register_runtime_bridge()

func teardown() -> void:
	_unregister_runtime_bridge()
	_unregister_reflection_cache_cleanup()
	_unregister_event_bus()

## 注册 Event Bus 为 Autoload
func _register_event_bus() -> void:
	var bus_path = "res://addons/fuse/core/fuse_event_bus.gd"
	var autoloads = ProjectSettings.get_setting("autoload", {})
	if not autoloads.has("FuseEventBus"):
		_plugin.add_autoload_singleton("FuseEventBus", bus_path)
		print("[FusePlugin] FuseEventBus 已注册为 Autoload")
	else:
		print("[FusePlugin] FuseEventBus Autoload 已存在")

## 清理 Event Bus
func _unregister_event_bus() -> void:
	var autoloads = ProjectSettings.get_setting("autoload", {})
	if autoloads.has("FuseEventBus"):
		_plugin.remove_autoload_singleton("FuseEventBus")
		print("[FusePlugin] FuseEventBus Autoload 已移除")

## 注册节点删除信号，自动清理反射缓存
func _register_reflection_cache_cleanup() -> void:
	var tree = _plugin.get_tree()
	if tree:
		tree.node_removed.connect(_on_node_removed_for_cache)
	# 脚本保存触发热重载但不重建节点实例，以 instance_id 为键的反射缓存会变陈旧
	if not _plugin.resource_saved.is_connected(_on_resource_saved_for_cache):
		_plugin.resource_saved.connect(_on_resource_saved_for_cache)
	print("[FusePlugin] 反射缓存自动清理已注册")

## 清理节点删除信号
func _unregister_reflection_cache_cleanup() -> void:
	var tree = _plugin.get_tree()
	if tree:
		if tree.node_removed.is_connected(_on_node_removed_for_cache):
			tree.node_removed.disconnect(_on_node_removed_for_cache)
	if _plugin.resource_saved.is_connected(_on_resource_saved_for_cache):
		_plugin.resource_saved.disconnect(_on_resource_saved_for_cache)
	# 同时清理所有静态缓存
	PropertyManager.clear_all_cache()
	SignalManager.clear_all_cache()
	FunctionManager.clear_all_callable_cache()
	print("[FusePlugin] 反射缓存自动清理已注销")

## 节点删除时清理缓存
func _on_node_removed_for_cache(node: Node) -> void:
	ReflectionCache.get_instance().clear_node(node)
	FunctionManager.clear_callable_cache(node)

## 脚本保存时清理反射缓存（热重载后属性/信号/方法表可能已变化）
func _on_resource_saved_for_cache(resource: Resource) -> void:
	if resource is Script:
		PropertyManager.clear_all_cache()
		SignalManager.clear_all_cache()
		FunctionManager.clear_all_callable_cache()

## 注册 FuseRuntimeBridge 为 Autoload
func _register_runtime_bridge() -> void:
	var autoloads = ProjectSettings.get_setting("autoload", {})
	if not autoloads.has("FuseRuntimeBridge"):
		_plugin.add_autoload_singleton("FuseRuntimeBridge", BRIDGE_PATH)
		print("[FusePlugin] FuseRuntimeBridge 已注册为 Autoload")
	else:
		print("[FusePlugin] FuseRuntimeBridge Autoload 已存在")

## 清理 FuseRuntimeBridge
func _unregister_runtime_bridge() -> void:
	var autoloads = ProjectSettings.get_setting("autoload", {})
	if autoloads.has("FuseRuntimeBridge"):
		_plugin.remove_autoload_singleton("FuseRuntimeBridge")
		print("[FusePlugin] FuseRuntimeBridge Autoload 已移除")
