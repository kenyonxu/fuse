@tool
@icon("res://addons/fuse/icons/builtin/JoyAxis.png")
extends BaseEvent
class_name OnGamepadAxis

## Event: OnGamepadAxis
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _last_value: float - 最后的轴值，用于判断触发条件
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/zh_CN/dev_docs/guides/runtime-instance-migration-guide.md

## 监听游戏手柄轴输入变化

## 手柄设备索引（-1 = 所有设备）
@export_range(-1, 7) var device_index: int = -1:
	set(value):
		device_index = value
		_update_resource_name()

## 轴索引（0-5）
## 0: 左摇杆 X, 1: 左摇杆 Y, 2: 右摇杆 X, 3: 右摇杆 Y, 4-5: 扳机
@export_range(0, 5) var axis_index: int = 0:
	set(value):
		axis_index = value
		_update_resource_name()

## 触发模式
enum TriggerMode {
	ON_ANY_CHANGE,      ## 任何变化
	ON_THRESHOLD,       ## 超过阈值
	ON_CROSS_ZERO,      ## 穿过零点
}

@export var trigger_mode: TriggerMode = TriggerMode.ON_ANY_CHANGE:
	set(value):
		trigger_mode = value
		_update_resource_name()

## 阈值（用于 ON_THRESHOLD 模式）
@export_range(0.0, 1.0, 0.01) var threshold: float = 0.5:
	set(value):
		threshold = value
		_update_resource_name()

## 死区（0.0-1.0）
@export_range(0.0, 1.0, 0.01) var deadzone: float = 0.1:
	set(value):
		deadzone = value
		_update_resource_name()

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["last_value"] = 0.0
	return base

## 更新资源名称（必需）
func _update_resource_name() -> void:
	var mode_text = ""
	match trigger_mode:
		TriggerMode.ON_ANY_CHANGE:
			mode_text = FuseLocalization.translate("FUSE_EVENT_GAMEPAD_AXIS_MODE_ANY_CHANGE")
		TriggerMode.ON_THRESHOLD:
			mode_text = FuseLocalization.translate_format("FUSE_EVENT_GAMEPAD_AXIS_MODE_THRESHOLD", {"threshold": str(threshold)})
		TriggerMode.ON_CROSS_ZERO:
			mode_text = FuseLocalization.translate("FUSE_EVENT_GAMEPAD_AXIS_MODE_CROSS_ZERO")

	var device_text = ""
	if device_index >= 0:
		device_text = FuseLocalization.translate_format("FUSE_EVENT_GAMEPAD_AXIS_DEVICE_N", {"device": str(device_index)})
	else:
		device_text = FuseLocalization.translate("FUSE_EVENT_GAMEPAD_AXIS_ALL_DEVICES")

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_GAMEPAD_AXIS_RESOURCE_NAME", {
		"axis": str(axis_index),
		"mode": mode_text,
		"device": device_text
	})

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	if not owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.connect(_on_tree_entered)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 使用 RuntimeInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	if not owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.connect(_on_tree_entered)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 当节点进入场景树
func _on_tree_entered() -> void:
	pass

## 输入处理（使用 BaseEvent 定义的接口）
func handle_input(event: InputEvent) -> void:
	if not event is InputEventJoypadMotion:
		return

	var axis_event = event as InputEventJoypadMotion

	# 检查设备索引
	if device_index >= 0 and axis_event.device != device_index:
		return

	# 检查轴索引
	if axis_event.axis != axis_index:
		return

	var axis_value = axis_event.axis_value

	# 应用死区
	if abs(axis_value) < deadzone:
		axis_value = 0.0

	# 检查是否应该触发
	if _should_trigger(axis_value):
		_trigger_event(axis_value)

	# 更新 RuntimeInstance 状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("last_value", axis_value)

## 判断是否应该触发
func _should_trigger(current_value: float) -> bool:
	var last_value: float = 0.0
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("last_value"):
		last_value = _runtime_instance_ref.get_runtime_state("last_value")

	match trigger_mode:
		TriggerMode.ON_ANY_CHANGE:
			return current_value != last_value

		TriggerMode.ON_THRESHOLD:
			# 超过阈值时触发
			return abs(current_value) >= threshold and abs(last_value) < threshold

		TriggerMode.ON_CROSS_ZERO:
			# 穿过零点（正负切换）
			return (current_value >= 0 and last_value < 0) or (current_value <= 0 and last_value > 0)

	return false

## 触发事件
func _trigger_event(axis_value: float) -> void:
	var device_text = ""
	if device_index >= 0:
		device_text = FuseLocalization.translate_format("FUSE_TEXT_DEVICE_N", {"device": str(device_index)})
	else:
		device_text = FuseLocalization.translate("FUSE_TEXT_ALL_DEVICES")

	_log_debug_localized("FUSE_LOG_EVENT_GAMEPAD_AXIS_TRIGGERED", {
		"axis": str(axis_index),
		"value": str(axis_value),
		"device": device_text
	})

	var context_node = Node.new()
	context_node.name = "GamepadAxisContext"
	context_node.set_meta("axis", axis_index)
	context_node.set_meta("axis_value", axis_value)
	context_node.set_meta("device", device_index)

	triggered.emit(context_node)
	context_node.queue_free()

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	if owner_node and is_instance_valid(owner_node):
		if owner_node.tree_entered.is_connected(_on_tree_entered):
			owner_node.tree_entered.disconnect(_on_tree_entered)

	# 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("last_value", 0.0)
	_runtime_instance_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 重置事件状态
func reset() -> void:
	super.reset()

	# 重置 RuntimeInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("last_value", 0.0)

	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件描述
func get_description() -> String:
	var mode_text = ""
	match trigger_mode:
		TriggerMode.ON_ANY_CHANGE:
			mode_text = FuseLocalization.translate("FUSE_EVENT_GAMEPAD_AXIS_DESC_ANY_CHANGE")
		TriggerMode.ON_THRESHOLD:
			mode_text = FuseLocalization.translate_format("FUSE_EVENT_GAMEPAD_AXIS_DESC_THRESHOLD", {"threshold": str(threshold)})
		TriggerMode.ON_CROSS_ZERO:
			mode_text = FuseLocalization.translate("FUSE_EVENT_GAMEPAD_AXIS_DESC_CROSS_ZERO")

	var deadzone_text = ""
	if deadzone > 0:
		deadzone_text = FuseLocalization.translate_format("FUSE_EVENT_GAMEPAD_AXIS_DESC_WITH_DEADZONE", {"deadzone": str(deadzone)})

	return FuseLocalization.translate_format("FUSE_EVENT_GAMEPAD_AXIS_DESC_MONITOR", {"axis": str(axis_index)}) + mode_text + deadzone_text

## 获取事件类型
func get_event_type() -> String:
	return "gamepad_axis"

## 获取事件分类
func get_event_category() -> String:
	return "input"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if axis_index < 0 or axis_index > 5:
		errors.append(FuseLocalization.translate("FUSE_ERROR_AXIS_INDEX_INVALID"))

	if deadzone < 0.0 or deadzone > 1.0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_AXIS_DEADZONE_INVALID"))

	return errors

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_GAMEPAD_AXIS_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_INPUT"
	metadata.description_key = "FUSE_EVENT_ON_GAMEPAD_AXIS_DESC"
	metadata.keywords = ["gamepad", "手柄", "joystick", "摇杆", "axis", "轴", "stick", "模拟", "analog", "controller", "控制器"]
	metadata.builtin_icon = "JoyAxis"
	return metadata
