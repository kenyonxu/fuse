@tool
@icon("res://addons/fuse/icons/builtin/InputEventKey.png")
extends BaseEvent
class_name OnDirectionalInputChanged

## Event: OnDirectionalInputChanged
##
## 监听方向输入变化，对比前后帧的 Input.get_vector()。
## 通过 Timer 轮询检测输入方向变化。

## 输入动作名（上下左右四个动作名）
var input_action_left: String = "move_left":
	set(value):
		input_action_left = value
		_update_resource_name()

var input_action_right: String = "move_right":
	set(value):
		input_action_right = value
		_update_resource_name()

var input_action_up: String = "move_up":
	set(value):
		input_action_up = value
		_update_resource_name()

var input_action_down: String = "move_down":
	set(value):
		input_action_down = value
		_update_resource_name()

## 检查间隔（秒）
var check_interval: float = 0.1:
	set(value):
		check_interval = value
		_update_resource_name()

var _check_timer: Timer = null
var _last_direction: Vector2 = Vector2.ZERO
var _initialized: bool = false

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	return base

## 更新资源名称
func _update_resource_name():
	var actions = "%s,%s,%s,%s" % [input_action_left, input_action_right, input_action_up, input_action_down]
	resource_name = FuseLocalization.translate_format("FUSE_EVENT_DIRECTIONAL_INPUT_FORMAT", {"actions": actions})

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

	# 初始化上一帧方向
	_last_direction = Input.get_vector(input_action_left, input_action_right, input_action_up, input_action_down)
	_initialized = true

	# 创建定时器轮询
	_check_timer = Timer.new()
	_check_timer.name = "FuseDirectionalInputTimer"
	_check_timer.wait_time = max(check_interval, 0.05)
	_check_timer.timeout.connect(_check_direction)
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
	_last_direction = Vector2.ZERO

func _check_direction() -> void:
	if not _initialized:
		return

	var current = Input.get_vector(input_action_left, input_action_right, input_action_up, input_action_down)

	# 检查方向是否变化（允许小的浮点差异）
	if not current.is_equal_approx(_last_direction):
		_last_direction = current
		_emit_triggered(null)

func get_description() -> String:
	var actions = "%s,%s,%s,%s" % [input_action_left, input_action_right, input_action_up, input_action_down]
	return FuseLocalization.translate_format("FUSE_EVENT_DIRECTIONAL_INPUT_DESCRIPTION", {
		"actions": actions,
		"interval": str(check_interval)
	})

func get_event_type() -> String:
	return "directional_input_changed"

func get_event_category() -> String:
	return "input"

func validate() -> Array[String]:
	var errors: Array[String] = []
	if check_interval <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_INTERVAL_MUST_BE_POSITIVE"))
	return errors

static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_DIRECTIONAL_INPUT_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_INPUT"
	metadata.description_key = "FUSE_EVENT_DIRECTIONAL_INPUT_DESC"
	metadata.keywords = ["方向", "direction", "输入", "input", "移动", "movement", "wasd", "手柄", "joystick", "vector"]
	metadata.builtin_icon = "InputEventKey"
	return metadata
