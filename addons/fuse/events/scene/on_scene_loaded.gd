@tool
@icon("res://addons/fuse/icons/builtin/StatusSuccess.png")
extends BaseEvent
class_name OnSceneLoaded

## Event: OnSceneLoaded
##
## 场景加载完成事件
##
## 当指定场景加载完成时触发。
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _is_monitoring: bool - 监听状态，跟踪是否正在监听场景树变化
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/zh_CN/dev_docs/guides/runtime-instance-migration-guide.md

## 场景路径（空字符串表示当前场景）
@export var scene_path: String = "":
	set(value):
		scene_path = value
		_update_resource_name()

## 是否传递场景根节点
@export var emit_scene_node: bool = true



## 更新资源名称（必需）
func _update_resource_name():
	var scene_text = scene_path if not scene_path.is_empty() else FuseLocalization.translate("FUSE_TEXT_CURRENT_SCENE")
	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_SCENE_LOADED_RESOURCE_NAME", {
		"scene": scene_text
	})

## 使用运行时实例初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 如果指定了场景路径，验证场景是否存在
	if not scene_path.is_empty():
		if not FileAccess.file_exists(scene_path):
			_create_fuse_error_localized("FUSE_ERROR_SCENE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"scene_path": scene_path})
			return

	# 监听场景树变化
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", true)

	# 如果没有指定场景路径，立即触发（当前场景）
	if scene_path.is_empty():
		call_deferred("_trigger_on_current_scene", owner_node)
	else:
		# 监听场景树变化，检测目标场景加载
		owner_node.get_tree().node_added.connect(_on_node_added)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	# 验证是否已经有 runtime_instance_ref
	if _runtime_instance_ref:
		# 如果已有运行时实例，直接执行初始化逻辑
		initialize_with_runtime_instance(owner_node, _runtime_instance_ref)
		return

	# 否则执行旧版初始化逻辑
	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 如果指定了场景路径，验证场景是否存在
	if not scene_path.is_empty():
		if not FileAccess.file_exists(scene_path):
			_create_fuse_error_localized("FUSE_ERROR_SCENE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"scene_path": scene_path})
			return

	# 监听场景树变化
	# (如果没有运行时实例，直接使用变量)
	var is_monitoring = true

	# 如果没有指定场景路径，立即触发（当前场景）
	if scene_path.is_empty():
		call_deferred("_trigger_on_current_scene", owner_node)
	else:
		# 监听场景树变化，检测目标场景加载
		owner_node.get_tree().node_added.connect(_on_node_added)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 🔧 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)

	# 断开信号连接
	if owner_node and owner_node.get_tree():
		if owner_node.get_tree().node_added.is_connected(_on_node_added):
			owner_node.get_tree().node_added.disconnect(_on_node_added)

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 当节点添加到场景树时
func _on_node_added(node: Node):
	# 🔧 获取监听状态
	var is_monitoring = false
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("is_monitoring"):
		is_monitoring = _runtime_instance_ref.get_runtime_state("is_monitoring")

	if not is_monitoring:
		return

	# 检查是否是根节点
	if not node.get_parent() or node.get_parent() == node.get_tree().root:
		# 检查场景路径是否匹配
		var node_scene_path = node.scene_file_path
		if node_scene_path == scene_path:
			_trigger_with_scene(node)

## 触发当前场景
func _trigger_on_current_scene(owner_node: Node):
	# 等待一帧，确保场景完全加载
	await owner_node.get_tree().process_frame

	# 🔧 获取监听状态
	var is_monitoring = false
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("is_monitoring"):
		is_monitoring = _runtime_instance_ref.get_runtime_state("is_monitoring")

	if not is_monitoring:
		return

	var current_scene = owner_node.get_tree().current_scene
	if current_scene:
		_trigger_with_scene(current_scene)

## 触发事件并传递场景节点
func _trigger_with_scene(scene_node: Node):
	# 🔧 获取监听状态
	var is_monitoring = false
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("is_monitoring"):
		is_monitoring = _runtime_instance_ref.get_runtime_state("is_monitoring")

	if not is_monitoring:
		return

	_log_info_localized("FUSE_LOG_EVENT_SCENE_LOADED_TRIGGERED", {
		"scene": scene_node.name,
		"path": scene_node.scene_file_path
	})

	# 停止监听
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)

	# 传递场景根节点（如果需要）
	if emit_scene_node:
		triggered.emit(scene_node)
	else:
		triggered.emit(null)

## 获取事件描述
func get_description() -> String:
	if scene_path.is_empty():
		return FuseLocalization.translate("FUSE_EVENT_ON_SCENE_LOADED_DESC_CURRENT")
	else:
		var scene_name = FuseNodeUtils.get_path_display_name(scene_path).get_basename()
		return FuseLocalization.translate_format("FUSE_EVENT_ON_SCENE_LOADED_DESC_SPECIFIC", {
			"scene": scene_name
		})

## 获取事件类型
func get_event_type() -> String:
	return "scene_loaded"

## 获取事件分类
func get_event_category() -> String:
	return "scene"

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["is_monitoring"] = true
	return base

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	# 如果指定了场景路径，验证文件扩展名
	if not scene_path.is_empty():
		if not scene_path.ends_with(".tscn") and not scene_path.ends_with(".scn"):
			errors.append(FuseLocalization.translate("FUSE_ERROR_INVALID_SCENE_EXTENSION"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()

	# 🔧 重置 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", true)

	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_SCENE_LOADED_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_SCENE"
	metadata.description_key = "FUSE_EVENT_ON_SCENE_LOADED_DESC"
	metadata.keywords = ["scene", "场景", "loaded", "加载", "load", "完成", "complete", "change", "切换"]
	metadata.builtin_icon = "StatusSuccess"
	return metadata
