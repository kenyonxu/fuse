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
@export var emit_scene_path: bool = false:
	set(value):
		emit_scene_path = value
		_update_resource_name()

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

## 初始化事件监听（必需）
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 保存节点引用到运行时状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("owner_node_ref", owner_node)

	# 初始化监控状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", true)
		_runtime_instance_ref.set_runtime_state("is_connected", false)

	# 连接场景切换信号
	if not owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.connect(_on_tree_entered)

	_setup_scene_monitoring()

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 初始化事件监听（兼容旧版本）
func initialize(owner_node: Node) -> void:
	initialize_with_runtime_instance(owner_node, null)

## 设置场景监听
func _setup_scene_monitoring() -> void:
	var owner_node_ref = null
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("owner_node_ref"):
		owner_node_ref = _runtime_instance_ref.get_runtime_state("owner_node_ref")

	if not owner_node_ref:
		return

	# 更新运行时状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", true)

	if owner_node_ref.is_inside_tree():
		_connect_scene_signal()
	else:
		# 等待进入场景树后再连接
		if not owner_node_ref.tree_entered.is_connected(_on_tree_entered):
			owner_node_ref.tree_entered.connect(_on_tree_entered)

## 当节点进入场景树
func _on_tree_entered() -> void:
	_setup_scene_monitoring()

## 连接场景信号
func _connect_scene_signal() -> void:
	var owner_node_ref = null
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("owner_node_ref"):
		owner_node_ref = _runtime_instance_ref.get_runtime_state("owner_node_ref")

	if not owner_node_ref:
		return

	var scene_tree = owner_node_ref.get_tree()
	if not scene_tree:
		return

	var scene_root = scene_tree.root
	if scene_root:
		# 先断开之前的连接（如果存在）
		if scene_root.about_to_disconnect_from_scene.is_connected(_on_scene_about_to_change):
			scene_root.about_to_disconnect_from_scene.disconnect(_on_scene_about_to_change)

		# 连接信号
		scene_root.about_to_disconnect_from_scene.connect(_on_scene_about_to_change)

		# 更新运行时状态
		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("is_connected", true)

## 场景切换前回调
func _on_scene_about_to_change() -> void:
	var is_monitoring = false
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("is_monitoring"):
		is_monitoring = _runtime_instance_ref.get_runtime_state("is_monitoring")

	if not is_monitoring:
		return

	var target_scene = FuseLocalization.translate("FUSE_TEXT_UNKNOWN")
	if emit_scene_path:
		var owner_node_ref = null
		if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("owner_node_ref"):
			owner_node_ref = _runtime_instance_ref.get_runtime_state("owner_node_ref")

		if owner_node_ref:
			var scene_tree = owner_node_ref.get_tree()
			if scene_tree and scene_tree.current_scene:
				target_scene = scene_tree.current_scene.scene_file_path
				if target_scene.is_empty():
					target_scene = scene_tree.current_scene.name

	_log_debug_localized("FUSE_LOG_EVENT_SCENE_ABOUT_TO_CHANGE", {
		"scene": target_scene
	})

	var context = {
		"scene_path": target_scene
	}
	triggered.emit(context)

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)
		_runtime_instance_ref.set_runtime_state("is_connected", false)
		_runtime_instance_ref.set_runtime_state("owner_node_ref", null)

	if owner_node and is_instance_valid(owner_node):
		# 只在场景树中存在时才尝试断开连接
		if owner_node.is_inside_tree():
			var scene_tree = owner_node.get_tree()
			if scene_tree and is_instance_valid(scene_tree):
				var scene_root = scene_tree.root
				if scene_root and is_instance_valid(scene_root) and scene_root.about_to_disconnect_from_scene.is_connected(_on_scene_about_to_change):
					scene_root.about_to_disconnect_from_scene.disconnect(_on_scene_about_to_change)

	if owner_node and is_instance_valid(owner_node) and owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.disconnect(_on_tree_entered)

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 获取事件描述
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

	# 恢复节点引用
	var owner_node_ref = null
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("owner_node_ref"):
		owner_node_ref = _runtime_instance_ref.get_runtime_state("owner_node_ref")

	if owner_node_ref and is_instance_valid(owner_node_ref):
		# 重新连接信号
		if owner_node_ref.is_inside_tree():
			_connect_scene_signal()

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
