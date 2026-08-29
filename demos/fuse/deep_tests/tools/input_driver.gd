extends Node

## deep_tests 输入注入器——headless/F5 无真键盘时按时间轴注入动作。
## timeline: [{delay, action, press}]，delay 秒后按下/释放动作。
## 测试工具脚本（计划中约定的 C 层唯一手写代码）。

@export var timeline: Array[Dictionary] = [
	{"delay": 1.0, "action": "Right", "press": true},
	{"delay": 2.5, "action": "Right", "press": false},
]

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	for entry in timeline:
		if not entry.get("done", false) and _t >= float(entry.get("delay", 0.0)):
			entry["done"] = true
			if entry.get("press", true):
				Input.action_press(String(entry.get("action", "")))
			else:
				Input.action_release(String(entry.get("action", "")))
