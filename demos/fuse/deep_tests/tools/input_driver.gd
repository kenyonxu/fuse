extends Node

## deep_tests 输入注入器——headless/F5 无真设备时按时间轴注入动作与原始输入事件。
## 两条时间轴：
##   timeline: [{delay, action, press}] —— Input.action_press/release（action 状态层，
##             供 OnInputActionComposite/CheckInput* 等读 action 状态的组件消费）
##   events:   [{delay, event, ...}] —— Input.parse_input_event（原始事件层，走完整
##             输入管线，供 OnInputKey/OnMouseButton/OnGamepad* 等走 handle_input/
##             Input 单例轮询的组件消费）。事件类型：
##             key {keycode, pressed, unicode?} / text {unicode, pressed}
##             mouse_motion {pos, relative?} / mouse_button {button, pressed}
##             joypad_motion {axis, value} / joypad_button {button, pressed}
## 测试工具脚本（计划中约定的 C 层唯一手写代码）。

@export var timeline: Array[Dictionary] = [
	{"delay": 1.0, "action": "Right", "press": true},
	{"delay": 2.5, "action": "Right", "press": false},
]

@export var events: Array[Dictionary] = []

## 自动注入总开关——F5 手动测试想关自动注入时在 Inspector 取消勾选即可，
## 不必改节点的 process_mode（那会随场景保存污染 .tscn）
@export var enabled := true

var _t := 0.0


func _process(delta: float) -> void:
	if not enabled:
		return
	_t += delta
	for entry in timeline:
		if not entry.get("done", false) and _t >= float(entry.get("delay", 0.0)):
			entry["done"] = true
			if entry.get("press", true):
				Input.action_press(String(entry.get("action", "")))
			else:
				Input.action_release(String(entry.get("action", "")))
	for entry in events:
		if not entry.get("done", false) and _t >= float(entry.get("delay", 0.0)):
			entry["done"] = true
			_dispatch(String(entry.get("event", "")), entry)


func _dispatch(kind: String, entry: Dictionary) -> void:
	match kind:
		"key":
			var ev := InputEventKey.new()
			ev.keycode = int(entry.get("keycode", 0)) as Key
			# 工程 InputMap 以 physical_keycode 绑定——不设则 InputMap.event_is_action 永不匹配
			ev.physical_keycode = int(entry.get("keycode", 0)) as Key
			ev.pressed = bool(entry.get("pressed", true))
			if entry.has("unicode"):
				ev.unicode = int(entry["unicode"])
			_send(ev)
		"text":
			var ev := InputEventKey.new()
			ev.keycode = int(entry.get("keycode", 0)) as Key
			ev.physical_keycode = int(entry.get("keycode", 0)) as Key
			ev.unicode = int(entry.get("unicode", 0))
			ev.pressed = bool(entry.get("pressed", true))
			_send(ev)
		"mouse_motion":
			var ev := InputEventMouseMotion.new()
			var pos: Array = entry.get("pos", [0, 0])
			ev.position = Vector2(float(pos[0]), float(pos[1]))
			if entry.has("relative"):
				var rel: Array = entry["relative"]
				ev.relative = Vector2(float(rel[0]), float(rel[1]))
			_send(ev)
		"mouse_button":
			var ev := InputEventMouseButton.new()
			ev.button_index = int(entry.get("button", 1)) as MouseButton
			ev.pressed = bool(entry.get("pressed", true))
			var pos: Array = entry.get("pos", [0, 0])
			ev.position = Vector2(float(pos[0]), float(pos[1]))
			_send(ev)
		"joypad_motion":
			var ev := InputEventJoypadMotion.new()
			ev.axis = int(entry.get("axis", 0)) as JoyAxis
			ev.axis_value = float(entry.get("value", 0.0))
			_send(ev)
		"joypad_button":
			var ev := InputEventJoypadButton.new()
			ev.button_index = int(entry.get("button", 0)) as JoyButton
			ev.pressed = bool(entry.get("pressed", true))
			_send(ev)


func _send(ev: InputEvent) -> void:
	Input.parse_input_event(ev)
