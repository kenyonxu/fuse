@tool
@icon("res://addons/fuse/icons/builtin/ScriptCreate.png")
extends BaseEvent
class_name OnNodeInstance

## 节点实例化事件
##
## 当指定场景被实例化时触发。
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _is_monitoring: bool - 监控状态
## - _parent_node_ref: Node - 父节点引用
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

## 场景路径
@export var scene_path: String = "":
	set(value):
		scene_path = value
		_update_resource_name()

## 父节点路径（可选，用于过滤）
@export var parent_node: NodePath = NodePath(""):
	set(value):
		parent_node = value
		_update_resource_name()

## 是否传递实例节点
@export var emit_instance: bool = true

## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _is_monitoring: bool - 监控状态
## - _parent_node_ref: Node - 父节点引用
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

## 更新资源名称（必需）
func _update_resource_name():
	var scene_text = FuseNodeUtils.get_path_display_name(scene_path).get_basename() if not scene_path.is_empty() else FuseLocalization.translate("FUSE_EVENT_ON_NODE_INSTANCE_NOT_SPECIFIED")
	var parent_text = ""
	if not parent_node.is_empty():
		parent_text = FuseLocalization.translate_format("FUSE_EVENT_ON_NODE_INSTANCE_WITH_PARENT", {"parent": _get_node_display_name(parent_node)})

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_NODE_INSTANCE_RESOURCE_NAME", {
		"scene": scene_text,
		"parent": parent_text
	})

## 使用运行时实例初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证场景路径
	if scene_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_SCENE_PATH_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证场景文件是否存在
	if not FileAccess.file_exists(scene_path):
		_create_fuse_error_localized("FUSE_ERROR_SCENE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"scene_path": scene_path})
		return

	# 🔧 获取父节点引用（如果指定）
	var parent_ref = null
	if not parent_node.is_empty():
		parent_ref = owner_node.get_node_or_null(parent_node)
		if not parent_ref:
			_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(parent_node)})
			return

		# 🔧 存储父节点引用到运行时状态
		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("parent_node_ref", parent_ref)

	# 🔧 设置监控状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", true)

	# 监听场景树变化
	owner_node.get_tree().node_added.connect(_on_node_added)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 初始化事件监听（必需）- 保持向后兼容
func initialize(owner_node: Node) -> void:
	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证场景路径
	if scene_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_SCENE_PATH_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证场景文件是否存在
	if not FileAccess.file_exists(scene_path):
		_create_fuse_error_localized("FUSE_ERROR_SCENE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"scene_path": scene_path})
		return

	# 获取父节点引用（如果指定）
	var parent_ref = null
	if not parent_node.is_empty():
		parent_ref = owner_node.get_node_or_null(parent_node)
		if not parent_ref:
			_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(parent_node)})
			return

	# 🔧 初始化 RuntimeEventInstance 状态
	if get_runtime_instance():
		get_runtime_instance().set_runtime_state("parent_node_ref", parent_ref)
		get_runtime_instance().set_runtime_state("is_monitoring", true)

	# 监听场景树变化
	owner_node.get_tree().node_added.connect(_on_node_added)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 🔧 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)
		_runtime_instance_ref.set_runtime_state("parent_node_ref", null)

	# 断开信号连接
	if owner_node and owner_node.get_tree():
		if owner_node.get_tree().node_added.is_connected(_on_node_added):
			owner_node.get_tree().node_added.disconnect(_on_node_added)

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 当节点添加到场景树时
func _on_node_added(node: Node):
	var is_monitoring = false
	var parent_node_ref = null

	# 🔧 从 RuntimeEventInstance 获取状态
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("is_monitoring"):
		is_monitoring = _runtime_instance_ref.get_runtime_state("is_monitoring")
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("parent_node_ref"):
		parent_node_ref = _runtime_instance_ref.get_runtime_state("parent_node_ref")

	if not is_monitoring:
		return

	# 检查场景路径是否匹配
	var node_scene_path = node.scene_file_path
	if node_scene_path != scene_path:
		return

	# 检查父节点（如果指定）
	if parent_node_ref:
		if node.get_parent() != parent_node_ref:
			var node_name = node.name if node else "Unknown"
			var parent_name = parent_node_ref.name if parent_node_ref else "Unknown"
			var actual_parent = node.get_parent().name if node.get_parent() else "null"
			_log_debug_localized("FUSE_LOG_EVENT_NODE_INSTANCE_PARENT_MISMATCH", {
				"node": node_name,
				"expected_parent": parent_name,
				"actual_parent": actual_parent
			})
			return

	# 触发事件
	_trigger_with_instance(node)

## 触发事件并传递实例节点
func _trigger_with_instance(instance_node: Node):
	var is_monitoring = false

	# 🔧 从 RuntimeEventInstance 获取状态
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("is_monitoring"):
		is_monitoring = _runtime_instance_ref.get_runtime_state("is_monitoring")

	if not is_monitoring:
		return

	var instance_name = instance_node.name if instance_node else "Unknown"
	_log_info_localized("FUSE_LOG_EVENT_NODE_INSTANCE_TRIGGERED", {
		"instance": instance_name,
		"scene": scene_path
	})

	# 传递实例节点（如果需要）
	if emit_instance:
		triggered.emit(instance_node)
	else:
		triggered.emit(null)

## 获取事件描述
func get_description() -> String:
	var scene_name = FuseNodeUtils.get_path_display_name(scene_path).get_basename() if not scene_path.is_empty() else FuseLocalization.translate("FUSE_EVENT_ON_NODE_INSTANCE_NOT_SPECIFIED")

	if not parent_node.is_empty():
		return FuseLocalization.translate_format("FUSE_EVENT_ON_NODE_INSTANCE_DESC_WITH_PARENT", {
			"scene": scene_name,
			"parent": _get_node_display_name(parent_node)
		})
	else:
		return FuseLocalization.translate_format("FUSE_EVENT_ON_NODE_INSTANCE_DESC", {"scene": scene_name})

## 获取事件类型
func get_event_type() -> String:
	return "node_instance"

## 获取事件分类
func get_event_category() -> String:
	return "scene"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if scene_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_SCENE_PATH_EMPTY"))
	else:
		# 验证文件扩展名
		if not scene_path.ends_with(".tscn") and not scene_path.ends_with(".scn"):
			errors.append(FuseLocalization.translate("FUSE_ERROR_INVALID_SCENE_EXTENSION"))

	return errors

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["is_monitoring"] = false
	base["parent_node_ref"] = null
	return base

## 重置事件状态
func reset() -> void:
	super.reset()
	# 🔧 重置 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)
		_runtime_instance_ref.set_runtime_state("parent_node_ref", null)

	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_NODE_INSTANCE_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_NODE"
	metadata.description_key = "FUSE_EVENT_ON_NODE_INSTANCE_DESC"
	metadata.keywords = ["node", "节点", "instance", "实例化", "instantiate", "scene", "场景", "spawn", "生成"]
	metadata.builtin_icon = "ScriptCreate"
	return metadata
