@tool
@icon("res://addons/fuse/icons/builtin/Keyboard.svg")
extends BaseCondition
class_name CheckAnyInput

## 任意输入条件
##
## 检测是否有任何键盘、鼠标或手柄的按键输入。适用于检测玩家活动、暂停菜单等功能。

## 检查输入映射动作
@export_group("Input Detection")
@export var check_input_map_actions: bool = true:
	set(value):
		check_input_map_actions = value
		_update_resource_name()

## 检查原始键盘输入（所有常用按键）
@export var check_raw_keyboard: bool = false:
	set(value):
		check_raw_keyboard = value
		_update_resource_name()

## 检查原始鼠标输入（所有按钮）
@export var check_raw_mouse: bool = false:
	set(value):
		check_raw_mouse = value
		_update_resource_name()

## 检查原始手柄输入（所有按钮）
@export var check_raw_gamepad: bool = false:
	set(value):
		check_raw_gamepad = value
		_update_resource_name()

## 手柄设备索引（-1 表示检查所有设备）
@export var gamepad_device: int = -1:
	set(value):
		gamepad_device = value
		_update_resource_name()

## 常用键盘按键列表（用于原始键盘检测）
var _common_keycodes: Array[int] = []

func _init():
	# 初始化常用键盘按键列表
	_setup_common_keycodes()

## 设置常用键盘按键列表
func _setup_common_keycodes():
	# 字母键 A-Z
	for i in range(KEY_A, KEY_Z + 1):
		_common_keycodes.append(i)

	# 数字键 0-9
	for i in range(KEY_0, KEY_9 + 1):
		_common_keycodes.append(i)

	# 功能键 F1-F12
	for i in range(KEY_F1, KEY_F12 + 1):
		_common_keycodes.append(i)

	# 常用控制键
	_common_keycodes.append_array([
		KEY_SPACE,
		KEY_ENTER,
		KEY_ESCAPE,
		KEY_TAB,
		KEY_SHIFT,
		KEY_CTRL,
		KEY_ALT,
		KEY_UP,
		KEY_DOWN,
		KEY_LEFT,
		KEY_RIGHT,
		KEY_HOME,
		KEY_END,
		KEY_PAGEUP,
		KEY_PAGEDOWN
	])

## 更新资源名称（必需）
func _update_resource_name() -> void:
	var checks = []

	if check_input_map_actions:
		checks.append(FuseLocalization.translate("FUSE_CONDITION_ANY_INPUT_INPUT_MAP"))

	if check_raw_keyboard:
		checks.append(FuseLocalization.translate("FUSE_CONDITION_ANY_INPUT_KEYBOARD"))

	if check_raw_mouse:
		checks.append(FuseLocalization.translate("FUSE_CONDITION_ANY_INPUT_MOUSE"))

	if check_raw_gamepad:
		var device_text = FuseLocalization.translate("FUSE_CONDITION_ANY_INPUT_GAMEPAD_ALL")
		if gamepad_device >= 0:
			device_text = FuseLocalization.translate_format("FUSE_CONDITION_ANY_INPUT_GAMEPAD_DEVICE", {"device": gamepad_device})
		checks.append(device_text)

	if checks.is_empty():
		resource_name = FuseLocalization.translate("FUSE_CONDITION_ANY_INPUT_NOT_SET")
	else:
		resource_name = FuseLocalization.translate_format("FUSE_CONDITION_ANY_INPUT", {"checks": ", ".join(checks)})

## 评估条件
func _evaluate_condition(context: ExecutionContext) -> bool:
	# 至少需要启用一种检查方式
	if not check_input_map_actions and not check_raw_keyboard and not check_raw_gamepad:
		_log_warning(FuseLocalization.translate("FUSE_CONDITION_ANY_INPUT_WARNING_NO_CHECKS"))
		return false

	var any_input_detected = false

	# 1. 检查 Input Map 动作
	if check_input_map_actions:
		if _check_any_input_map_action():
			_log_debug(FuseLocalization.translate("FUSE_CONDITION_ANY_INPUT_DETECTED_INPUT_MAP"))
			any_input_detected = true

	# 2. 检查原始键盘输入
	if not any_input_detected and check_raw_keyboard:
		if _check_any_keyboard_key():
			_log_debug(FuseLocalization.translate("FUSE_CONDITION_ANY_INPUT_DETECTED_KEYBOARD"))
			any_input_detected = true

	# 3. 检查原始手柄输入
	if not any_input_detected and check_raw_gamepad:
		if _check_any_gamepad_button():
			_log_debug(FuseLocalization.translate("FUSE_CONDITION_ANY_INPUT_DETECTED_GAMEPAD"))
			any_input_detected = true

	_log_debug(FuseLocalization.translate_format(
		"FUSE_CONDITION_ANY_INPUT_CHECK_RESULT",
		{"result": FuseLocalization.translate("FUSE_CONDITION_DETECTED" if any_input_detected else "FUSE_CONDITION_NOT_DETECTED")}
	))

	return any_input_detected

## 检查是否有任何 Input Map 动作被按下
func _check_any_input_map_action() -> bool:
	# 获取所有 Input Map 动作
	var actions = InputMap.get_actions()

	for action in actions:
		# 检查动作是否刚被按下
		if Input.is_action_just_pressed(action):
			_log_debug(FuseLocalization.translate_format("FUSE_CONDITION_ANY_INPUT_ACTION_PRESSED", {"action": action}))
			return true

	return false

## 检查是否有任何键盘按键被按下
func _check_any_keyboard_key() -> bool:
	for keycode in _common_keycodes:
		if Input.is_key_pressed(keycode):
			_log_debug(FuseLocalization.translate_format("FUSE_CONDITION_ANY_INPUT_KEY_PRESSED", {"keycode": keycode}))
			return true

	return false

## 检查是否有任何手柄按钮被按下
func _check_any_gamepad_button() -> bool:
	# 检查所有连接的手柄设备
	var joystick_count = Input.get_connected_joypads().size()

	if joystick_count == 0:
		_log_debug(FuseLocalization.translate("FUSE_CONDITION_ANY_INPUT_NO_GAMEPAD"))
		return false

	# 如果指定了设备索引，只检查该设备
	var devices_to_check = []
	if gamepad_device >= 0:
		devices_to_check.append(gamepad_device)
	else:
		# 检查所有设备（0 到 joystick_count - 1）
		for i in range(joystick_count):
			devices_to_check.append(i)

	# 检查每个设备的按钮
	for device in devices_to_check:
		# 检查所有常见的游戏手柄按钮
		for button_index in range(21):  # Xbox/PS 手柄通常有 0-20 的按钮索引
			if Input.is_joy_button_pressed(device, button_index):
				_log_debug(FuseLocalization.translate_format("FUSE_CONDITION_ANY_INPUT_BUTTON_PRESSED", {
					"device": device,
					"button": button_index
				}))
				return true

	return false

## 计算依赖
func _compute_dependencies() -> Array[String]:
	# 输入检查不依赖变量
	return []

## 获取条件类型
func get_condition_type() -> String:
	return "any_input"

## 获取条件分类
func get_condition_category() -> String:
	return "input"

## 获取条件描述
func get_description() -> String:
	var checks = []

	if check_input_map_actions:
		checks.append(FuseLocalization.translate("FUSE_CONDITION_ANY_INPUT_INPUT_MAP"))

	if check_raw_keyboard:
		checks.append(FuseLocalization.translate("FUSE_CONDITION_ANY_INPUT_KEYBOARD"))

	if check_raw_mouse:
		checks.append(FuseLocalization.translate("FUSE_CONDITION_ANY_INPUT_MOUSE"))

	if check_raw_gamepad:
		var device_text = FuseLocalization.translate("FUSE_CONDITION_ANY_INPUT_GAMEPAD_ALL")
		if gamepad_device >= 0:
			device_text = FuseLocalization.translate_format("FUSE_CONDITION_ANY_INPUT_GAMEPAD_DEVICE", {"device": gamepad_device})
		checks.append(device_text)

	if checks.is_empty():
		return FuseLocalization.translate("FUSE_CONDITION_ANY_INPUT_DESC_NOT_SET")

	return FuseLocalization.translate_format("FUSE_CONDITION_ANY_INPUT_DESC", {"checks": ", ".join(checks)})

## 验证条件
func validate() -> Array[String]:
	var errors = super.validate()

	# 至少需要启用一种检查方式
	if not check_input_map_actions and not check_raw_keyboard and not check_raw_mouse and not check_raw_gamepad:
		errors.append(FuseLocalization.translate("FUSE_CONDITION_ANY_INPUT_ERROR_NO_CHECKS"))

	# 如果启用了手柄检查，验证设备索引
	if check_raw_gamepad and gamepad_device < -1:
		errors.append(FuseLocalization.translate("FUSE_CONDITION_ANY_INPUT_ERROR_INVALID_DEVICE"))

	return errors

## 获取参数
func get_parameters() -> Dictionary:
	return {
		"check_input_map_actions": check_input_map_actions,
		"check_raw_keyboard": check_raw_keyboard,
		"check_raw_mouse": check_raw_mouse,
		"check_raw_gamepad": check_raw_gamepad,
		"gamepad_device": gamepad_device
	}

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("check_input_map_actions"):
		check_input_map_actions = parameters["check_input_map_actions"]

	if parameters.has("check_raw_keyboard"):
		check_raw_keyboard = parameters["check_raw_keyboard"]

	if parameters.has("check_raw_mouse"):
		check_raw_mouse = parameters["check_raw_mouse"]

	if parameters.has("check_raw_gamepad"):
		check_raw_gamepad = parameters["check_raw_gamepad"]

	if parameters.has("gamepad_device"):
		gamepad_device = parameters["gamepad_device"]

## 获取条件元数据
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_ANY_INPUT_NAME"
	metadata.category_key = "FUSE_CATEGORY_INPUT"
	metadata.description_key = "FUSE_CONDITION_ANY_INPUT_DESC"
	metadata.keywords = ["输入", "input", "任意", "any", "按键", "key", "按钮", "button", "检测", "detect", "活动", "activity"]
	metadata.builtin_icon = "Keyboard"
	return metadata
