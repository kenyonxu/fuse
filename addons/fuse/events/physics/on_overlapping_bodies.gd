@tool
@icon("res://addons/fuse/icons/builtin/CollisionShape2D.png")
extends BaseEvent
class_name OnOverlappingBodies

## Event: OnOverlappingBodies
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _has_triggered: bool - 是否已触发（用于 trigger_once 模式）
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

## 区域内重叠物体数量变化事件
##
## 当 Area2D/3D 内重叠的 PhysicsBody 数量变化并满足阈值条件时触发。

enum Comparison {
	Greater = 0,
	Less = 1,
	Equal = 2
}

## 目标 Area 节点路径
@export var area_node: NodePath = NodePath(""):
	set(value):
		area_node = value
		_update_resource_name()

## 数量阈值
@export var check_threshold: int = 1:
	set(value):
		check_threshold = value
		_update_resource_name()

## 比较方式
@export var comparison: Comparison = Comparison.Greater:
	set(value):
		comparison = value
		_update_resource_name()

## 是否传递当前数量
@export var emit_count: bool = true

## 是否只触发一次
@export var trigger_once: bool = false:
	set(value):
		trigger_once = value
		_update_resource_name()

var _area_ref: Variant = null  # Area2D 或 Area3D

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["has_triggered"] = false
	return base

## 使用 RuntimeInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

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

	# 验证节点类型（支持 Area2D 和 Area3D）
	if not _area_ref is Area2D and not _area_ref is Area3D:
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(area_node)})
		return

	# 连接信号
	if _area_ref is Area2D:
		if not _area_ref.body_entered.is_connected(_on_body_changed):
			_area_ref.body_entered.connect(_on_body_changed)
		if not _area_ref.body_exited.is_connected(_on_body_changed):
			_area_ref.body_exited.connect(_on_body_changed)
	elif _area_ref is Area3D:
		if not _area_ref.body_entered.is_connected(_on_body_changed):
			_area_ref.body_entered.connect(_on_body_changed)
		if not _area_ref.body_exited.is_connected(_on_body_changed):
			_area_ref.body_exited.connect(_on_body_changed)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 更新资源名称（必需）
func _update_resource_name():
	var comparison_key = ""
	match comparison:
		Comparison.Greater:
			comparison_key = "FUSE_EVENT_ON_OVERLAPPING_BODIES_GREATER"
		Comparison.Less:
			comparison_key = "FUSE_EVENT_ON_OVERLAPPING_BODIES_LESS"
		Comparison.Equal:
			comparison_key = "FUSE_EVENT_ON_OVERLAPPING_BODIES_EQUAL"

	var comparison_text = FuseLocalization.translate(comparison_key)
	var once_text = FuseLocalization.translate("FUSE_EVENT_ON_OVERLAPPING_BODIES_ONCE") if trigger_once else ""

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_OVERLAPPING_BODIES_RESOURCE_NAME", {
		"comparison": comparison_text,
		"threshold": str(check_threshold),
		"once": once_text
	})

## 初始化事件监听（必需）
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

	# 验证节点类型（支持 Area2D 和 Area3D）
	if not _area_ref is Area2D and not _area_ref is Area3D:
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(area_node)})
		return

	# 连接信号
	if _area_ref is Area2D:
		if not _area_ref.body_entered.is_connected(_on_body_changed):
			_area_ref.body_entered.connect(_on_body_changed)
		if not _area_ref.body_exited.is_connected(_on_body_changed):
			_area_ref.body_exited.connect(_on_body_changed)
	elif _area_ref is Area3D:
		if not _area_ref.body_entered.is_connected(_on_body_changed):
			_area_ref.body_entered.connect(_on_body_changed)
		if not _area_ref.body_exited.is_connected(_on_body_changed):
			_area_ref.body_exited.connect(_on_body_changed)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 断开信号连接
	if _area_ref and is_instance_valid(_area_ref):
		if _area_ref is Area2D:
			if _area_ref.body_entered.is_connected(_on_body_changed):
				_area_ref.body_entered.disconnect(_on_body_changed)
			if _area_ref.body_exited.is_connected(_on_body_changed):
				_area_ref.body_exited.disconnect(_on_body_changed)
		elif _area_ref is Area3D:
			if _area_ref.body_entered.is_connected(_on_body_changed):
				_area_ref.body_entered.disconnect(_on_body_changed)
			if _area_ref.body_exited.is_connected(_on_body_changed):
				_area_ref.body_exited.disconnect(_on_body_changed)

	# 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", false)

	# 清理引用
	_area_ref = null
	_runtime_instance_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 物体进入/离开区域回调
func _on_body_changed(_body: Node):
	# 检查是否只触发一次
	var has_triggered: bool = false
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("has_triggered"):
		has_triggered = _runtime_instance_ref.get_runtime_state("has_triggered")

	if trigger_once and has_triggered:
		_log_debug_localized("FUSE_LOG_EVENT_ALREADY_TRIGGERED", {})
		return

	# 获取当前重叠数量
	var count: int = 0
	if _area_ref is Area2D:
		count = _area_ref.get_overlapping_bodies().size()
	elif _area_ref is Area3D:
		count = _area_ref.get_overlapping_bodies().size()

	# 检查是否满足阈值条件
	var should_trigger: bool = false
	match comparison:
		Comparison.Greater:
			should_trigger = count > check_threshold
		Comparison.Less:
			should_trigger = count < check_threshold
		Comparison.Equal:
			should_trigger = count == check_threshold

	if not should_trigger:
		return

	# 标记已触发
	if trigger_once and _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", true)

	_log_info_localized("FUSE_LOG_EVENT_OVERLAPPING_BODIES_TRIGGERED", {
		"count": count,
		"threshold": check_threshold
	})

	# triggered 信号签名是 (context: Node)——int 直传会触发 int→Object 转换错误；
	# 按惯例用上下文节点携带元数据（同 OnReceiveEvent/OnSoundListened），emit_count 控制是否附带
	var context_node = Node.new()
	context_node.name = "OverlappingBodiesContext"
	if emit_count:
		context_node.set_meta("body_count", count)
	context_node.set_meta("threshold", check_threshold)
	triggered.emit(context_node)
	context_node.queue_free()

## 获取事件描述
func get_description() -> String:
	var area_name = area_node if not area_node.is_empty() else FuseLocalization.translate("FUSE_EVENT_ON_OVERLAPPING_BODIES_NOT_SPECIFIED")

	var comparison_key = ""
	match comparison:
		Comparison.Greater:
			comparison_key = "FUSE_EVENT_ON_OVERLAPPING_BODIES_COMPARISON_GREATER"
		Comparison.Less:
			comparison_key = "FUSE_EVENT_ON_OVERLAPPING_BODIES_COMPARISON_LESS"
		Comparison.Equal:
			comparison_key = "FUSE_EVENT_ON_OVERLAPPING_BODIES_COMPARISON_EQUAL"

	var comparison_text = FuseLocalization.translate(comparison_key)
	var once_text = FuseLocalization.translate("FUSE_EVENT_ON_OVERLAPPING_BODIES_ONCE_SUFFIX") if trigger_once else ""

	return FuseLocalization.translate_format("FUSE_EVENT_ON_OVERLAPPING_BODIES_DESC", {
		"area": area_name,
		"comparison": comparison_text,
		"threshold": str(check_threshold),
		"once": once_text
	})

## 获取事件类型
func get_event_type() -> String:
	return "overlapping_bodies"

## 获取事件分类
func get_event_category() -> String:
	return "physics"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if area_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	if check_threshold < 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_OVERLAPPING_BODIES_THRESHOLD_NEGATIVE"))

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
	metadata.name_key = "FUSE_EVENT_ON_OVERLAPPING_BODIES_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_PHYSICS"
	metadata.description_key = "FUSE_EVENT_ON_OVERLAPPING_BODIES_DESC"
	metadata.keywords = ["overlapping", "重叠", "bodies", "物体", "area", "区域", "physics", "物理", "count", "数量", "threshold", "阈值"]
	metadata.builtin_icon = "CollisionShape2D"
	return metadata
