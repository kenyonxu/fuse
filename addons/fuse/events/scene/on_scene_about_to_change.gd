@tool
@icon("res://addons/fuse/icons/builtin/PackedScene.png")
extends BaseEvent
class_name OnSceneAboutToChange

## 场景切换前触发
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _owner_node_ref: Node - 场景根节点引用
## - _is_connected: bool - 是否连接了场景信号
## - _is_monitoring: bool - 是否正在监控场景
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

## 是否传递场景路径
@export var _subscription: Variant = null
var _owner_node_ref: Node = null
var emit_scene_path: bool = false:
	set(value):
		emit_scene_path = value
		_update_resource_name()

## 动态属性注册——带 setter 的 script var 无 STORAGE 位，
## 不显式注册则 emit_scene_path 在 .tres/.tscn 序列化时静默丢失
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		"name": "emit_scene_path",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	return properties

## 更新资源名称（必需）
func _update_resource_name() -> void:
	resource_name = FuseLocalization.translate("FUSE_EVENT_ON_SCENE_ABOUT_TO_CHANGE_RESOURCE_NAME")

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["owner_node_ref"] = null
	base["is_connected"] = false
	base["is_monitoring"] = false
	return base

## 初始化事件监听（必需）## 使用 RuntimeInstance 初始化事件（订阅 EventBus 预告）
## ChangeScene 指令切换前会广播 "Fuse_SceneAboutToChange"——SceneTree 无原生
## 切换前信号，原实现挂在幻觉信号 about_to_disconnect_from_scene 上从未触发过
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return
	_runtime_instance_ref = runtime_instance
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return
	_owner_node_ref = owner_node
	_subscribe(owner_node)
	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})


## 旧初始化入口（非 RuntimeInstance 路径）
func initialize(owner_node: Node) -> void:
	if Engine.is_editor_hint():
		return
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return
	_owner_node_ref = owner_node
	_subscribe(owner_node)
	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})


## 订阅 EventBus 的切换预告事件
func _subscribe(owner_node: Node) -> void:
	var bus: Node = Engine.get_main_loop().root.get_node_or_null("FuseEventBus")
	if bus == null:
		_create_fuse_error_localized("FUSE_ERROR_EVENT_BUS_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
		return
	if _subscription != null:
		return
	_subscription = bus.subscribe("Fuse_SceneAboutToChange", _on_scene_about_to_change.bind(owner_node))


## 收到切换预告：发触发信号
func _on_scene_about_to_change(args: Dictionary, owner_node: Node) -> void:
	var scene_path: String = str(args.get("scene_path", ""))
	_log_info_localized("FUSE_LOG_EVENT_SCENE_ABOUT_TO_CHANGE", {"scene_path": scene_path})

	var context_node = Node.new()
	context_node.name = "SceneAboutToChangeContext"
	context_node.set_meta("scene_path", scene_path)
	context_node.set_meta("trigger", owner_node)
	if emit_scene_path:
		context_node.set_meta("old_scene", owner_node.get_tree().current_scene.scene_file_path if owner_node.get_tree().current_scene else "")
	triggered.emit(context_node)
	context_node.queue_free()


## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	if _subscription != null:
		var bus: Node = Engine.get_main_loop().root.get_node_or_null("FuseEventBus")
		if bus != null:
			bus.unsubscribe(_subscription)
		_subscription = null
	_runtime_instance_ref = null
	_owner_node_ref = null
	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})


func get_description() -> String:
	return FuseLocalization.translate("FUSE_EVENT_ON_SCENE_ABOUT_TO_CHANGE_DESC_FORMAT")

## 获取事件类型
func get_event_type() -> String:
	return "scene_about_to_change"

## 获取事件分类
func get_event_category() -> String:
	return "scene"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []
	return errors

## 重置事件状态
func reset() -> void:
	super.reset()

	# 重置 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", true)
		_runtime_instance_ref.set_runtime_state("is_connected", false)
		_runtime_instance_ref.set_runtime_state("owner_node_ref", null)

	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_SCENE_ABOUT_TO_CHANGE_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_SCENE"
	metadata.description_key = "FUSE_EVENT_ON_SCENE_ABOUT_TO_CHANGE_DESC"
	metadata.keywords = ["scene", "场景", "change", "切换", "save", "保存", "load", "加载", "transition", "过渡"]
	metadata.builtin_icon = "PackedScene"
	return metadata
