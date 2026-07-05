@tool
@icon("res://addons/fuse/icons/builtin/CombineLines.png")
extends BaseEvent
class_name OnTreeChanged

## Event: OnTreeChanged
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _is_monitoring: bool - 监控状态
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md
##
## 场景树变化事件
##
## 监听场景树结构变化，包括节点添加和移除。

## 变化类型
enum ChangeType {
	NodeAdded = 0,
	NodeRemoved = 1,
	Any = 2
}

## 变化类型
@export var change_type: ChangeType = ChangeType.Any:
	set(value):
		change_type = value
		_update_resource_name()

## 组过滤（可选）
@export var filter_by_group: String = "":
	set(value):
		filter_by_group = value
		_update_resource_name()

## 是否传递变化节点
@export var emit_changed_node: bool = true

## 运行时实例引用
var _scene_tree: SceneTree = null

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["is_monitoring"] = false
	return base

## 更新资源名称（必需）
func _update_resource_name():
	var type_key = ""
	match change_type:
		ChangeType.NodeAdded:
			type_key = "FUSE_DESC_CHANGE_TYPE_NODE_ADDED"
		ChangeType.NodeRemoved:
			type_key = "FUSE_DESC_CHANGE_TYPE_NODE_REMOVED"
		ChangeType.Any:
			type_key = "FUSE_DESC_CHANGE_TYPE_ANY"

	var type_text = FuseLocalization.translate(type_key)

	var group_text = ""
	if not filter_by_group.is_empty():
		group_text = FuseLocalization.translate_format("FUSE_DESC_GROUP_FILTER", {
			"group": filter_by_group
		})

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_TREE_CHANGED_RESOURCE_NAME", {
		"type": type_text,
		"group": group_text
	})

## 使用 RuntimeInstance 初始化（必需）
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	if not owner_node.is_inside_tree():
		_create_fuse_error_localized("FUSE_ERROR_NODE_NOT_IN_TREE", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 获取场景树
	_scene_tree = owner_node.get_tree()

	if not _scene_tree:
		_create_fuse_error_localized("FUSE_ERROR_SCENE_TREE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 连接场景树信号
	if change_type == ChangeType.NodeAdded or change_type == ChangeType.Any:
		if not _scene_tree.node_added.is_connected(_on_node_added):
			_scene_tree.node_added.connect(_on_node_added)

	if change_type == ChangeType.NodeRemoved or change_type == ChangeType.Any:
		if not _scene_tree.node_removed.is_connected(_on_node_removed):
			_scene_tree.node_removed.connect(_on_node_removed)

	# 设置监控状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", true)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {
		"event_type": get_event_type(),
		"change_type": ChangeType.keys()[change_type],
		"group_filter": filter_by_group if not filter_by_group.is_empty() else "none"
	})

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	if not owner_node.is_inside_tree():
		_create_fuse_error_localized("FUSE_ERROR_NODE_NOT_IN_TREE", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 获取场景树
	_scene_tree = owner_node.get_tree()

	if not _scene_tree:
		_create_fuse_error_localized("FUSE_ERROR_SCENE_TREE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 连接场景树信号
	if change_type == ChangeType.NodeAdded or change_type == ChangeType.Any:
		if not _scene_tree.node_added.is_connected(_on_node_added):
			_scene_tree.node_added.connect(_on_node_added)

	if change_type == ChangeType.NodeRemoved or change_type == ChangeType.Any:
		if not _scene_tree.node_removed.is_connected(_on_node_removed):
			_scene_tree.node_removed.connect(_on_node_removed)

	# 设置监控状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", true)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {
		"event_type": get_event_type(),
		"change_type": ChangeType.keys()[change_type],
		"group_filter": filter_by_group if not filter_by_group.is_empty() else "none"
	})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 清理 RuntimeEventInstance 状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)

	if _scene_tree:
		# 断开信号连接
		if _scene_tree.node_added.is_connected(_on_node_added):
			_scene_tree.node_added.disconnect(_on_node_added)

		if _scene_tree.node_removed.is_connected(_on_node_removed):
			_scene_tree.node_removed.disconnect(_on_node_removed)

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 节点添加回调
func _on_node_added(node: Node):
	var is_monitoring = false
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("is_monitoring"):
		is_monitoring = _runtime_instance_ref.get_runtime_state("is_monitoring")

	if not is_monitoring:
		return

	# 检查变化类型过滤
	if change_type == ChangeType.NodeRemoved:
		return

	# 检查组过滤
	if not filter_by_group.is_empty():
		if not node.is_in_group(filter_by_group):
			return

	_log_info_localized("FUSE_LOG_EVENT_TREE_NODE_ADDED", {
		"node": node.name,
		"path": node.get_path()
	})

	# 触发事件
	if emit_changed_node:
		triggered.emit(node)
	else:
		triggered.emit(null)

## 节点移除回调
func _on_node_removed(node: Node):
	var is_monitoring = false
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("is_monitoring"):
		is_monitoring = _runtime_instance_ref.get_runtime_state("is_monitoring")

	if not is_monitoring:
		return

	# 检查变化类型过滤
	if change_type == ChangeType.NodeAdded:
		return

	# 检查组过滤
	if not filter_by_group.is_empty():
		if not node.is_in_group(filter_by_group):
			return

	_log_info_localized("FUSE_LOG_EVENT_TREE_NODE_REMOVED", {
		"node": node.name,
		"path": node.get_path()
	})

	# 触发事件
	if emit_changed_node:
		triggered.emit(node)
	else:
		triggered.emit(null)

## 获取事件描述
func get_description() -> String:
	var type_key = ""
	match change_type:
		ChangeType.NodeAdded:
			type_key = "FUSE_DESC_CHANGE_TYPE_NODE_ADDED_TRIGGER"
		ChangeType.NodeRemoved:
			type_key = "FUSE_DESC_CHANGE_TYPE_NODE_REMOVED_TRIGGER"
		ChangeType.Any:
			type_key = "FUSE_DESC_CHANGE_TYPE_ANY_TRIGGER"

	var type_desc = FuseLocalization.translate(type_key)

	var group_desc = ""
	if not filter_by_group.is_empty():
		group_desc = FuseLocalization.translate_format("FUSE_DESC_GROUP_FILTER_ONLY", {
			"group": filter_by_group
		})

	return FuseLocalization.translate_format("FUSE_EVENT_ON_TREE_CHANGED_DESC", {
		"type": type_desc,
		"group": group_desc
	})

## 获取事件类型
func get_event_type() -> String:
	return "tree_changed"

## 获取事件分类
func get_event_category() -> String:
	return "scene"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	# SceneTree 事件通常不需要额外验证
	# 变化类型是枚举，总是有效的
	# 组过滤是可选的

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", true)
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_TREE_CHANGED_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_SCENE"
	metadata.description_key = "FUSE_EVENT_ON_TREE_CHANGED_DESC"
	metadata.keywords = ["tree", "树", "scene", "场景", "changed", "变化", "node", "节点", "added", "添加", "removed", "移除", "structure", "结构"]
	metadata.builtin_icon = "CombineLines"
	return metadata
