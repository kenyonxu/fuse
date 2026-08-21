# addons/fuse/tests/preset_ai/test_eval_runner.gd
extends Node

const EvalRunner := preload("res://addons/fuse/editor/preset_ai/eval_runner.gd")

var _fail := 0

func _check(cond: bool, msg: String) -> void:
	if cond: print("✓ " + msg)
	else:
		_fail += 1
		push_error("✗ " + msg)

func _ready():
	print("=== test_eval_runner: 断言引擎 ===")
	_test_component_assertion()
	_test_param_assertion()
	_test_event_assertion()
	_test_variable_assertion()
	_test_must_not()
	print("=== 结果: %d 失败 ===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _preset(insts: Array) -> Dictionary:
	return {"level": "L2", "variables": {"local": [], "scope": [{"name": "hp", "container": "../Target"}], "global": []},
		"action_runner": {"instructions": insts},
		"event": {"type": "OnInputAction", "target_input_action": "attack"}}

func _test_component_assertion() -> void:
	var case := {"must_include": [{"kind": "component", "type": "SendEvent"}], "must_not_include": [], "variables_required": []}
	var r := EvalRunner.check_assertions(case, _preset([{"type": "SendEvent", "event_name": "Hit"}]))
	_check(r.passed == 1 and r.total == 1, "component 断言命中")

func _test_param_assertion() -> void:
	var case := {"must_include": [{"kind": "param", "component": "Wait", "key": "wait_time"}], "must_not_include": [], "variables_required": []}
	var r := EvalRunner.check_assertions(case, _preset([{"type": "Wait", "wait_time": 2.0}]))
	_check(r.passed == 1 and r.total == 1, "param 断言命中")

func _test_event_assertion() -> void:
	var case := {"must_include": [{"kind": "event", "type": "OnReady"}], "must_not_include": [], "variables_required": []}
	var r := EvalRunner.check_assertions(case, _preset([]))
	_check(r.passed == 0 and r.total == 1, "event 断言未命中（实际是 OnInputAction）")

func _test_variable_assertion() -> void:
	var case := {"must_include": [], "must_not_include": [], "variables_required": [{"name": "hp", "scope": "scope"}]}
	var r := EvalRunner.check_assertions(case, _preset([]))
	_check(r.passed == 1 and r.total == 1, "variables_required 断言命中")

func _test_must_not() -> void:
	var case := {"must_include": [], "must_not_include": [{"kind": "component", "type": "SendEvent"}], "variables_required": []}
	var r := EvalRunner.check_assertions(case, _preset([{"type": "SendEvent"}]))
	_check(r.passed == 0 and r.total == 1, "must_not_include 违规被抓住")
