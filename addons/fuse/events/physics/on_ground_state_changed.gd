@tool
@icon("res://addons/fuse/icons/builtin/PlaneMesh.png")
extends BaseEvent
class_name OnGroundStateChanged

## Event: OnGroundStateChanged
##
## 监听 CharacterBody 的着地/离地状态变化。
## 通过 Timer 轮询 is_on_floor() 检测状态变化。
##
## 迁移到 RuntimeInstance: 2026-06-18
## 状态变量:
## - check_timer: Timer - 轮询计时器
## - was_on_ground: bool - 上一帧的着地状态

## 触发条件枚举
enum TriggerOn {
	LAND,   ## 着地时触发
	LEAVE,  ## 离地时触发
	BOTH    ## 两者都触发
}

## 目标 CharacterBody 节点路径
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## 触发条件
var trigger_on: TriggerOn = TriggerOn.BOTH:
	set(value):
		trigger_on = value
		_update_resource_name()

## 检查间隔（秒）
var check_interval: float = 0.1:
	set(value):
		check_interval = value
		_update_resource_name()

var _check_timer: Timer = null
var _was_on_ground: bool = false
var _initialized: bool = false

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	return base

## 更新资源名称
func _update_resource_name():
	var node_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
	var trigger_str = ""
	match trigger_on:
		TriggerOn.LAND: trigger_str = FuseLocalization.translate("FUSE_EVENT_GROUND_STATE_LAND")
		TriggerOn.LEAVE: trigger_str = FuseLocalization.translate("FUSE_EVENT_GROUND_STATE_LEAVE")
		TriggerOn.BOTH: trigger_str = FuseLocalization.translate("FUSE_EVENT_GROUND_STATE_BOTH")

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_GROUND_STATE_FORMAT", {
		"node": node_str,
		"trigger": trigger_str
	})

## 使用 RuntimeInstance 初始化
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		return

	set_trigger_ref(owner_node)

	var node: Node
	if target_node.is_empty():
		node = owner_node
	else:
		node = owner_node.get_node_or_null(target_node)

	if node == null:
		return

	# 初始化着地状态
	if node is CharacterBody2D:
		_was_on_ground = (node as CharacterBody2D).is_on_floor()
	elif node is CharacterBody3D:
		_was_on_ground = (node as CharacterBody3D).is_on_floor()
	else:
		return

	_initialized = true

	# 创建定时器轮询
	_check_timer = Timer.new()
	_check_timer.name = "FuseGroundStateTimer"
	_check_timer.wait_time = max(check_interval, 0.05)
	_check_timer.timeout.connect(_check_ground_state.bind(owner_node))
	owner_node.add_child(_check_timer)
	_check_timer.start()

func initialize(owner_node: Node) -> void:
	if Engine.is_editor_hint():
		return

	set_trigger_ref(owner_node)

	var node: Node
	if target_node.is_empty():
		node = owner_node
	else:
		node = owner_node.get_node_or_null(target_node)

	if node == null:
		return

	if node is CharacterBody2D:
		_was_on_ground = (node as CharacterBody2D).is_on_floor()
	elif node is CharacterBody3D:
		_was_on_ground = (node as CharacterBody3D).is_on_floor()
	else:
		return

	_initialized = true

	_check_timer = Timer.new()
	_check_timer.name = "FuseGroundStateTimer"
	_check_timer.wait_time = max(check_interval, 0.05)
	_check_timer.timeout.connect(_check_ground_state.bind(owner_node))
	owner_node.add_child(_check_timer)
	_check_timer.start()

func terminate(owner_node: Node) -> void:
	if _runtime_instance_ref:
		pass

	if _check_timer and is_instance_valid(_check_timer):
		_check_timer.stop()
		_check_timer.queue_free()
	_check_timer = null
	_initialized = false

func reset() -> void:
	super.reset()
	_was_on_ground = false

func _check_ground_state(owner_node: Node) -> void:
	if not _initialized:
		return

	var node: Node
	if target_node.is_empty():
		node = owner_node
	else:
		node = owner_node.get_node_or_null(target_node)

	if node == null:
		return

	var is_on_ground := false
	if node is CharacterBody2D:
		is_on_ground = (node as CharacterBody2D).is_on_floor()
	elif node is CharacterBody3D:
		is_on_ground = (node as CharacterBody3D).is_on_floor()
	else:
		return

	if is_on_ground == _was_on_ground:
		return

	# 状态发生变化
	var should_trigger := false
	match trigger_on:
		TriggerOn.LAND:
			should_trigger = is_on_ground and not _was_on_ground
		TriggerOn.LEAVE:
			should_trigger = not is_on_ground and _was_on_ground
		TriggerOn.BOTH:
			should_trigger = true

	_was_on_ground = is_on_ground

	if should_trigger:
		_emit_triggered(node)

func get_description() -> String:
	var node_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_CURRENT_NODE")
	return FuseLocalization.translate_format("FUSE_EVENT_GROUND_STATE_DESCRIPTION", {"node": node_str})

func get_event_type() -> String:
	return "ground_state_changed"

func get_event_category() -> String:
	return "physics"

func validate() -> Array[String]:
	var errors: Array[String] = []
	if check_interval <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_INTERVAL_MUST_BE_POSITIVE"))
	return errors

static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_GROUND_STATE_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_PHYSICS"
	metadata.description_key = "FUSE_EVENT_GROUND_STATE_DESC"
	metadata.keywords = ["地面", "ground", "着地", "land", "离地", "leave", "floor", "物理", "physics", "character"]
	metadata.builtin_icon = "PlaneMesh"
	return metadata
