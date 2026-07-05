@tool
@icon("res://addons/fuse/icons/builtin/Tween.png")
extends BaseEvent
class_name OnTweenCompleted

## Tween 补间动画完成时触发
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _is_monitoring: bool - 是否正在监听
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

## 目标 Tween 节点路径
@export var tween_node_path: NodePath = NodePath(""):
	set(value):
		tween_node_path = value
		_update_resource_name()

var _tween: Tween = null
var _owner_node_ref: Node = null

## 更新资源名称（必需）
func _update_resource_name() -> void:
	var path_text = str(tween_node_path) if not tween_node_path.is_empty() else FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED")
	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_TWEEN_COMPLETED_RESOURCE_NAME", {
		"path": path_text
	})

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["is_monitoring"] = false
	return base

## 使用 RuntimeInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	# 保存 RuntimeEventInstance 引用
	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_owner_node_ref = owner_node

	if tween_node_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 获取目标节点
	var tween_node = owner_node.get_node_or_null(tween_node_path)
	if not tween_node:
		_create_fuse_error_localized("FUSE_ERROR_TWEEN_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {
			"node_path": str(tween_node_path)
		})
		return

	# 验证节点类型
	if not tween_node is Tween:
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {
			"node_path": str(tween_node_path)
		})
		return

	_tween = tween_node

	# 连接 finished 信号（Godot 4.6 使用 finished 信号）
	if not _tween.finished.is_connected(_on_tween_finished):
		_tween.finished.connect(_on_tween_finished)

	# 初始化运行时状态
	_runtime_instance_ref.set_runtime_state("is_monitoring", true)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## Tween 完成回调
func _on_tween_finished() -> void:
	var is_monitoring: bool = false
	if _runtime_instance_ref.has_runtime_state("is_monitoring"):
		is_monitoring = _runtime_instance_ref.get_runtime_state("is_monitoring")

	if not is_monitoring:
		return

	_log_debug_localized("FUSE_LOG_EVENT_TWEEN_COMPLETED", {
		"node": _tween.name
	})

	# 创建上下文节点传递 Tween 引用
	var context_node = Node.new()
	context_node.name = "TweenContext"
	context_node.set_meta("tween", _tween)
	triggered.emit(context_node)

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)

	if _tween and is_instance_valid(_tween):
		if _tween.finished.is_connected(_on_tween_finished):
			_tween.finished.disconnect(_on_tween_finished)

	_tween = null
	_owner_node_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 获取事件描述
func get_description() -> String:
	var tween_name = str(tween_node_path) if not tween_node_path.is_empty() else FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED")
	return FuseLocalization.translate_format("FUSE_EVENT_ON_TWEEN_COMPLETED_DESC", {
		"tween": tween_name
	})

## 获取事件类型
func get_event_type() -> String:
	return "tween_completed"

## 获取事件分类
func get_event_category() -> String:
	return "tween"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if tween_node_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()

	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)

	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_TWEEN_COMPLETED_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_TWEEN"
	metadata.description_key = "FUSE_EVENT_ON_TWEEN_COMPLETED_DESC"
	metadata.keywords = ["tween", "补间", "animation", "动画", "completed", "完成", "finished", "结束", "interpolate", "插值"]
	metadata.builtin_icon = "Tween"
	return metadata
