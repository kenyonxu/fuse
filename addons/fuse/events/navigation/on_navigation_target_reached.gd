@tool
@icon("res://addons/fuse/icons/builtin/NavigationAgent2D.svg")
extends BaseEvent
class_name OnNavigationTargetReached

## Event: OnNavigationTargetReached
##
## 监听 NavigationAgent2D/3D 到达目的地事件。
## 连接 navigation_finished 信号。

## NavigationAgent 节点路径
var agent_node: NodePath = NodePath(""):
	set(value):
		agent_node = value
		_update_resource_name()

var _agent_ref: Node = null

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	return base

## 更新资源名称
func _update_resource_name():
	var agent_str = _get_node_display_name(agent_node) if not agent_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
	resource_name = FuseLocalization.translate_format("FUSE_EVENT_NAV_TARGET_REACHED_FORMAT", {"agent": agent_str})

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

	if agent_node.is_empty():
		return

	_agent_ref = owner_node.get_node_or_null(agent_node)
	if not _agent_ref:
		return

	if _agent_ref is NavigationAgent2D:
		if not (_agent_ref as NavigationAgent2D).navigation_finished.is_connected(_on_navigation_finished):
			(_agent_ref as NavigationAgent2D).navigation_finished.connect(_on_navigation_finished)
	elif _agent_ref is NavigationAgent3D:
		if not (_agent_ref as NavigationAgent3D).navigation_finished.is_connected(_on_navigation_finished):
			(_agent_ref as NavigationAgent3D).navigation_finished.connect(_on_navigation_finished)

func terminate(owner_node: Node) -> void:
	if _runtime_instance_ref:
		pass

	if _agent_ref and is_instance_valid(_agent_ref):
		if _agent_ref is NavigationAgent2D:
			if (_agent_ref as NavigationAgent2D).navigation_finished.is_connected(_on_navigation_finished):
				(_agent_ref as NavigationAgent2D).navigation_finished.disconnect(_on_navigation_finished)
		elif _agent_ref is NavigationAgent3D:
			if (_agent_ref as NavigationAgent3D).navigation_finished.is_connected(_on_navigation_finished):
				(_agent_ref as NavigationAgent3D).navigation_finished.disconnect(_on_navigation_finished)
	_agent_ref = null

func reset() -> void:
	super.reset()

func _on_navigation_finished() -> void:
	_emit_triggered(_agent_ref)

func get_description() -> String:
	var agent_str = _get_node_display_name(agent_node) if not agent_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
	return FuseLocalization.translate_format("FUSE_EVENT_NAV_TARGET_REACHED_DESCRIPTION", {"agent": agent_str})

func get_event_type() -> String:
	return "navigation_target_reached"

func get_event_category() -> String:
	return "navigation"

func validate() -> Array[String]:
	var errors: Array[String] = []
	if agent_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))
	return errors

static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_NAV_TARGET_REACHED_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_NAVIGATION"
	metadata.description_key = "FUSE_EVENT_NAV_TARGET_REACHED_DESC"
	metadata.keywords = ["导航", "navigation", "到达", "arrive", "目标", "target", "agent", "路径", "path", "寻路"]
	metadata.builtin_icon = "NavigationAgent2D"
	return metadata

# 补齐参数的属性注册——带自定义 setter 的脚本变量只有 SCRIPT_VARIABLE 位、无 STORAGE 位，
# 不注册则 Inspector 不可编辑、.tres/.tscn 序列化静默丢值、preset schema 提取器漏收录
# （同 9a90828 与 10 条件批量修复的修法）
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		name = "agent_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	return properties
