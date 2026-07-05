@tool
@icon("res://addons/fuse/icons/builtin/JoyButton.png")
extends BaseEvent
class_name OnGamepadButton

## Event: OnGamepadButton
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _has_triggered: bool - 是否已触发（虽然当前未使用，但保留用于未来扩展）
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

## 游戏手柄按键事件
##
## 监听游戏手柄按键事件，支持按下和释放触发模式。

## 触发模式
enum TriggerMode {
	PRESSED,   # 按下
	RELEASED   # 释放
}

## 设备索引（-1 表示任意手柄，0 表示第一个手柄）
@export var device: int = 0:
	set(value):
		device = value
		_update_resource_name()

## 按键索引
@export var button_index: JoyButton = JOY_BUTTON_A:
	set(value):
		button_index = value
		_update_resource_name()

## 触发模式
@export var trigger_mode: TriggerMode = TriggerMode.PRESSED:
	set(value):
		trigger_mode = value
		_update_resource_name()

# RuntimeInstance 引用已在 BaseEvent 中定义
var _owner_node_ref: Node = null  # 保留用于信号连接管理

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["has_triggered"] = false
	return base

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

	_owner_node_ref = owner_node

	# 设置输入处理
	if not owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.connect(_on_tree_entered)

	if owner_node.is_inside_tree():
		_setup_input_processing()

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 更新资源名称（必需）
func _update_resource_name():
	var device_key = "FUSE_TEXT_GAMEPAD_ANY" if device == -1 else "FUSE_TEXT_GAMEPAD_N"
	var device_text = FuseLocalization.translate_format(device_key, {"device": str(device)})
	var button_name = _get_button_name()
	var mode_key = "FUSE_TEXT_GAMEPAD_PRESSED" if trigger_mode == TriggerMode.PRESSED else "FUSE_TEXT_GAMEPAD_RELEASED"
	var mode_name = FuseLocalization.translate(mode_key)

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_GAMEPAD_BUTTON_RESOURCE_NAME", {
		"device": device_text,
		"button": button_name,
		"mode": mode_name
	})

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_owner_node_ref = owner_node

	# 设置输入处理
	if not owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.connect(_on_tree_entered)

	if owner_node.is_inside_tree():
		_setup_input_processing()

	# 设置初始状态（通过 RuntimeInstance）
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", false)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 设置输入处理
func _setup_input_processing():
	if not _owner_node_ref:
		return
	_owner_node_ref.set_process_input(true)

## 节点进入场景树回调
func _on_tree_entered():
	_setup_input_processing()

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 断开 tree_entered 信号
	if owner_node and owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.disconnect(_on_tree_entered)

	# 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("has_triggered", false)

	# 清理引用
	_owner_node_ref = null
	_runtime_instance_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 处理输入事件
func _input(event: InputEvent):
	# 只处理手柄按钮事件
	if not event is InputEventJoypadButton:
		return

	var button_event = event as InputEventJoypadButton

	# 检查设备索引
	if device != -1 and button_event.device != device:
		return

	# 检查按键索引
	if button_event.button_index != button_index:
		return

	# 检查触发模式
	var should_trigger = false
	match trigger_mode:
		TriggerMode.PRESSED:
			should_trigger = button_event.pressed
		TriggerMode.RELEASED:
			should_trigger = not button_event.pressed

	if not should_trigger:
		return

	# 触发事件
	_on_gamepad_button_triggered(button_event)

## 手柄按钮触发回调
func _on_gamepad_button_triggered(event: InputEventJoypadButton):
	var button_name = _get_button_name()
	var mode_key = "FUSE_TEXT_GAMEPAD_PRESSED" if trigger_mode == TriggerMode.PRESSED else "FUSE_TEXT_GAMEPAD_RELEASED"
	var mode_name = FuseLocalization.translate(mode_key)
	var device_key = "FUSE_TEXT_DEVICE_N"
	var device_text = FuseLocalization.translate_format(device_key, {"device": str(event.device)})

	_log_info_localized("FUSE_LOG_EVENT_GAMEPAD_BUTTON_TRIGGERED", {
		"button": button_name,
		"mode": mode_name,
		"device": device_text
	})

	# 创建上下文节点传递事件信息
	var context_node = Node.new()
	context_node.name = "GamepadButtonContext"
	context_node.set_meta("device", event.device)
	context_node.set_meta("button_index", event.button_index)
	context_node.set_meta("button_name", button_name)
	context_node.set_meta("pressed", event.pressed)
	context_node.set_meta("pressure", event.pressure)

	triggered.emit(context_node)
	context_node.queue_free()

## 获取按钮名称
func _get_button_name() -> String:
	match button_index:
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_LEFT_SHOULDER: return FuseLocalization.translate("FUSE_TEXT_GAMEPAD_LEFT_SHOULDER")
		JOY_BUTTON_RIGHT_SHOULDER: return FuseLocalization.translate("FUSE_TEXT_GAMEPAD_RIGHT_SHOULDER")
		JOY_BUTTON_LEFT_STICK: return FuseLocalization.translate("FUSE_TEXT_GAMEPAD_LEFT_STICK")
		JOY_BUTTON_RIGHT_STICK: return FuseLocalization.translate("FUSE_TEXT_GAMEPAD_RIGHT_STICK")
		JOY_BUTTON_BACK: return FuseLocalization.translate("FUSE_TEXT_GAMEPAD_BACK")
		JOY_BUTTON_START: return FuseLocalization.translate("FUSE_TEXT_GAMEPAD_START")
		JOY_BUTTON_DPAD_UP: return FuseLocalization.translate("FUSE_TEXT_GAMEPAD_DPAD_UP")
		JOY_BUTTON_DPAD_DOWN: return FuseLocalization.translate("FUSE_TEXT_GAMEPAD_DPAD_DOWN")
		JOY_BUTTON_DPAD_LEFT: return FuseLocalization.translate("FUSE_TEXT_GAMEPAD_DPAD_LEFT")
		JOY_BUTTON_DPAD_RIGHT: return FuseLocalization.translate("FUSE_TEXT_GAMEPAD_DPAD_RIGHT")
		_: return FuseLocalization.translate_format("FUSE_TEXT_GAMEPAD_BUTTON_N", {"button": str(button_index)})

## 获取事件描述
func get_description() -> String:
	var device_key = "FUSE_TEXT_GAMEPAD_ANY" if device == -1 else "FUSE_TEXT_GAMEPAD_N"
	var device_text = FuseLocalization.translate_format(device_key, {"device": str(device)})
	var button_name = _get_button_name()
	var mode_key = "FUSE_TEXT_GAMEPAD_PRESSED" if trigger_mode == TriggerMode.PRESSED else "FUSE_TEXT_GAMEPAD_RELEASED"
	var mode_text = FuseLocalization.translate(mode_key)

	return FuseLocalization.translate_format("FUSE_EVENT_ON_GAMEPAD_BUTTON_DESC", {
		"device": device_text,
		"button": button_name,
		"mode": mode_text
	})

## 获取事件类型
func get_event_type() -> String:
	return "gamepad_button"

## 获取事件分类
func get_event_category() -> String:
	return "input"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	# 验证设备索引
	if device < -1:
		errors.append(FuseLocalization.translate("FUSE_ERROR_EVENT_DEVICE_INDEX_TOO_SMALL"))

	# 验证 trigger_mode 值
	if trigger_mode < 0 or trigger_mode >= TriggerMode.size():
		errors.append(FuseLocalization.translate("FUSE_ERROR_EVENT_INVALID_TRIGGER_MODE"))

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
	metadata.name_key = "FUSE_EVENT_ON_GAMEPAD_BUTTON_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_INPUT"
	metadata.description_key = "FUSE_EVENT_ON_GAMEPAD_BUTTON_DESC"
	metadata.keywords = ["gamepad", "手柄", "controller", "控制器", "button", "按键", "joystick", "摇杆", "input", "输入", "xbox", "ps5", "switch"]
	metadata.builtin_icon = "JoyButton"
	return metadata
