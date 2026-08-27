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
# 基线未采样标志：初始化时 body 尚未 move_and_slide，is_on_floor() 恒为 false，
# 直接采样会把"出生在地面"误判为落地；首次轮询时再定基线。
var _baseline_pending: bool = false

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

## 动态属性列表 - 让事件参数在 Inspector 中显示并持久化
## （缺失此声明时 target_node/trigger_on/check_interval 不显示且保存场景时被剔除，
## 导致 target_node 回落为空、事件指向 Trigger 自身而非 CharacterBody，静默失效）
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	properties.append({
		"name": "target_node",
		"type": TYPE_NODE_PATH,
		"usage": PROPERTY_USAGE_DEFAULT,
	})

	var trigger_modes := ",".join([
		FuseLocalization.translate("FUSE_EVENT_GROUND_STATE_LAND"),
		FuseLocalization.translate("FUSE_EVENT_GROUND_STATE_LEAVE"),
		FuseLocalization.translate("FUSE_EVENT_GROUND_STATE_BOTH"),
	])
	properties.append({
		"name": "trigger_on",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": trigger_modes,
	})

	properties.append({
		"name": "check_interval",
		"type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.05,10.0,0.01",
	})

	return properties

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

	# 节点类型校验（基线采样推迟到首次轮询）
	if not (node is CharacterBody2D or node is CharacterBody3D):
		return

	_baseline_pending = true
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

	if not (node is CharacterBody2D or node is CharacterBody3D):
		return

	_baseline_pending = true
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
	_baseline_pending = true

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

	# 首次轮询：只采样基线不触发（初始化时 is_on_floor 不可靠）
	if _baseline_pending:
		_was_on_ground = is_on_ground
		_baseline_pending = false
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
