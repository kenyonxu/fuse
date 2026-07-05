@tool
@icon("res://addons/fuse/icons/builtin/PhysicsBody2D.png")
extends BaseEvent
class_name OnBodyEntered

## Event: OnBodyEntered
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _has_triggered: bool - 是否已触发
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

## 物体进入区域事件
##
## 当 PhysicsBody2D 进入 Area2D 区域时触发。

## 目标 Area 节点路径
@export var area_node: NodePath = NodePath(""):
	set(value):
		area_node = value
		_update_resource_name()

## 目标组名（为空时匹配任何物体）
@export var target_group: String = "":
	set(value):
		target_group = value
		_update_resource_name()

## 是否只触发一次
@export var trigger_once: bool = false:
	set(value):
		trigger_once = value
		_update_resource_name()

## 是否传递碰撞物体
@export var emit_body: bool = true

var _area_ref: Area2D = null
# RuntimeInstance 引用已在 BaseEvent 中定义

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["has_triggered"] = false
	return base

## 更新资源名称（必需）
func _update_resource_name():
	var group_display = FuseLocalization.translate_format("FUSE_EVENT_BODY_ENTERED_GROUP", {"group": target_group if not target_group.is_empty() else "any"})
	var once_display = FuseLocalization.translate("FUSE_EVENT_BODY_ENTERED_ONCE") if trigger_once else FuseLocalization.translate("FUSE_EVENT_BODY_ENTERED_REPEAT")

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_BODY_ENTERED_RESOURCE_NAME", {
		"body": str(area_node),
		"group": group_display,
		"once": once_display
	})

## 初始化事件监听（必需）- 向后兼容
func initialize(owner_node: Node) -> void:
	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证目标节点路径
	if area_node.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 获取目标节点
	_area_ref = owner_node.get_node_or_null(area_node)
	if not _area_ref:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(area_node)})
		return

	# 验证节点类型
	if not _area_ref is Area2D:
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(area_node)})
		return

	# 连接信号
	if not _area_ref.body_entered.is_connected(_on_body_entered):
		_area_ref.body_entered.connect(_on_body_entered)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 使用 RuntimeInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	# 保存 RuntimeEventInstance 引用
	_runtime_instance_ref = runtime_instance

	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证目标节点路径
	if area_node.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 获取目标节点
	_area_ref = owner_node.get_node_or_null(area_node)
	if not _area_ref:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(area_node)})
		return

	# 验证节点类型
	if not _area_ref is Area2D:
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(area_node)})
		return

	# 连接信号
	if not _area_ref.body_entered.is_connected(_on_body_entered):
		_area_ref.body_entered.connect(_on_body_entered)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 断开信号连接
	if _area_ref and is_instance_valid(_area_ref):
		if _area_ref.body_entered.is_connected(_on_body_entered):
			_area_ref.body_entered.disconnect(_on_body_entered)

	# 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", false)
		_runtime_instance_ref = null

	# 清理引用
	_area_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 物体进入区域回调
func _on_body_entered(body: Node2D):
	# 验证 body
	if not body:
		return

	# 检查是否只触发一次
	var has_triggered: bool = false
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("has_triggered"):
		has_triggered = _runtime_instance_ref.get_runtime_state("has_triggered")

	if trigger_once and has_triggered:
		_log_debug_localized("FUSE_LOG_EVENT_ALREADY_TRIGGERED", {})
		return

	# 检查目标组
	if not target_group.is_empty() and not body.is_in_group(target_group):
		var body_name = body.name if body else "Unknown"
		_log_debug_localized("FUSE_LOG_EVENT_BODY_ENTERED_GROUP", {
			"body": body_name,
			"group": target_group,
			"status": "skipped"
		})
		return

	# 标记已触发
	if trigger_once and _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", true)

	var body_name = body.name if body else "Unknown"
	_log_info_localized("FUSE_LOG_EVENT_BODY_ENTERED_TRIGGERED", {"body": body_name})

	# 传递碰撞物体（如果需要）
	if emit_body:
		triggered.emit(body)
	else:
		triggered.emit(null)

## 获取事件描述
func get_description() -> String:
	var area_name = str(area_node) if not area_node.is_empty() else FuseLocalization.translate("FUSE_EVENT_ON_BODY_ENTERED_NOT_SPECIFIED")
	var group_name = target_group if not target_group.is_empty() else FuseLocalization.translate("FUSE_EVENT_ON_BODY_ENTERED_ANY_GROUP")
	var once_str = FuseLocalization.translate("FUSE_EVENT_BODY_ENTERED_ONCE") if trigger_once else FuseLocalization.translate("FUSE_EVENT_BODY_ENTERED_REPEAT")

	return FuseLocalization.translate_format("FUSE_EVENT_ON_BODY_ENTERED_DESC", {
		"group": group_name,
		"area": area_name,
		"once": once_str
	})

## 获取事件类型
func get_event_type() -> String:
	return "body_entered"

## 获取事件分类
func get_event_category() -> String:
	return "physics"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if area_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	# 重置 RuntimeInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", false)
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_BODY_ENTERED_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_PHYSICS"
	metadata.description_key = "FUSE_EVENT_ON_BODY_ENTERED_DESC"
	metadata.keywords = ["body", "物体", "entered", "进入", "area", "区域", "physics", "物理", "collision", "碰撞"]
	metadata.builtin_icon = "PhysicsBody2D"
	return metadata
