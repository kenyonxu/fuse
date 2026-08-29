@tool
@icon("res://addons/fuse/icons/builtin/Control.svg")
extends BaseEvent
class_name OnUIMouseEntered

## Event: OnUIMouseEntered
##
## 监听鼠标进入 Control 节点事件。
## 连接 Control 节点的 mouse_entered 信号。

## 目标 Control 节点路径
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

var _control_ref: Control = null

## 动态属性注册——带 setter 的 script var 无 STORAGE 位，
## 不显式注册则 target_node 在 .tres/.tscn 序列化时静默丢失
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		"name": "target_node",
		"type": TYPE_NODE_PATH,
		"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		"hint_string": "Control",
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	return properties

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	return base

## 更新资源名称
func _update_resource_name():
	var node_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
	resource_name = FuseLocalization.translate_format("FUSE_EVENT_MOUSE_ENTERED_FORMAT", {"node": node_str})

func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return
	_runtime_instance_ref = runtime_instance
	_do_initialize(owner_node)

func initialize(owner_node: Node) -> void:
	if Engine.is_editor_hint():
		return
	_do_initialize(owner_node)

func _do_initialize(owner_node: Node) -> void:
	if not owner_node:
		return

	set_trigger_ref(owner_node)

	if target_node.is_empty():
		return

	_control_ref = owner_node.get_node_or_null(target_node)
	if not _control_ref:
		return

	if not _control_ref is Control:
		return

	if not _control_ref.mouse_entered.is_connected(_on_mouse_entered):
		_control_ref.mouse_entered.connect(_on_mouse_entered)

func terminate(owner_node: Node) -> void:
	if _runtime_instance_ref:
		pass

	if _control_ref and is_instance_valid(_control_ref):
		if _control_ref.mouse_entered.is_connected(_on_mouse_entered):
			_control_ref.mouse_entered.disconnect(_on_mouse_entered)
	_control_ref = null

func reset() -> void:
	super.reset()

func _on_mouse_entered() -> void:
	_emit_triggered(_control_ref)

func get_description() -> String:
	var node_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
	return FuseLocalization.translate_format("FUSE_EVENT_MOUSE_ENTERED_DESCRIPTION", {"node": node_str})

func get_event_type() -> String:
	return "ui_mouse_entered"

func get_event_category() -> String:
	return "ui"

func validate() -> Array[String]:
	var errors: Array[String] = []
	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))
	return errors

static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_MOUSE_ENTERED_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_UI"
	metadata.description_key = "FUSE_EVENT_MOUSE_ENTERED_DESC"
	metadata.keywords = ["鼠标", "mouse", "进入", "enter", "UI", "hover", "悬停", "control"]
	metadata.builtin_icon = "Control"
	return metadata
