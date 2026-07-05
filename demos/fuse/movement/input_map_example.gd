extends Node

## InputMap 配置示例
## 在项目的 _ready() 或 autoload 中调用此脚本

func _ready():
	_setup_movement_input_map()

## 配置移动相关的 InputMap
func _setup_movement_input_map():
	# 清除已存在的动作（避免重复）
	_clear_input_actions(["move_up", "move_down", "move_left", "move_right"])

	# 创建四个方向的输入动作
	_create_input_action("move_up", KEY_W, KEY_UP)
	_create_input_action("move_down", KEY_S, KEY_DOWN)
	_create_input_action("move_left", KEY_A, KEY_LEFT)
	_create_input_action("move_right", KEY_D, KEY_RIGHT)

	print("Movement InputMap configured successfully!")

## 创建单个输入动作
func _create_input_action(action_name: String, key1: Key, key2: Key = KEY_NONE) -> void:
	InputMap.add_action(action_name)

	# 添加键盘事件
	var event1 = InputEventKey.new()
	event1.keycode = key1
	InputMap.action_add_event(action_name, event1)

	if key2 != KEY_NONE:
		var event2 = InputEventKey.new()
		event2.keycode = key2
		InputMap.action_add_event(action_name, event2)

## 清除输入动作
func _clear_input_actions(action_names: Array[String]) -> void:
	for action_name in action_names:
		if InputMap.has_action(action_name):
			InputMap.erase_action(action_name)
