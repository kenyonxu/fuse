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
	_test_replay()
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


# ---- 回放编排（Task 9）----

const _FIXTURE_CASE := {
	"name": "mini", "level": "L1",
	"must_include": [{"kind": "component", "type": "Print"}],
	"must_not_include": [], "variables_required": [],
	"outputs": {"iter-x": ["mini/good/outputs/a.json", "mini/bad/outputs/b.json"]},
}

# 迷你 fixture workspace：1 case + 2 产物（good 过 / bad 败，Nope 不在 schemas → E_UNKNOWN_COMPONENT）
# 开头清掉上轮残留保证幂等（前批 _remove_dir_recursive 先例）
func _make_fixture_workspace(root: String) -> void:
	if DirAccess.dir_exists_absolute(root):
		_remove_dir_recursive(root)
	DirAccess.make_dir_recursive_absolute(root + "/evals/cases")
	DirAccess.make_dir_recursive_absolute(root + "/iter-x/mini/good/outputs")
	DirAccess.make_dir_recursive_absolute(root + "/iter-x/mini/bad/outputs")
	var f := FileAccess.open(root + "/evals/cases/mini.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_FIXTURE_CASE))
	f.close()
	f = FileAccess.open(root + "/iter-x/mini/good/outputs/a.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"format_version": "2.0", "level": "L1",
		"action_runner": {"instructions": [{"type": "Print", "message": "hi"}]}}))
	f.close()
	f = FileAccess.open(root + "/iter-x/mini/bad/outputs/b.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"format_version": "2.0", "level": "L1",
		"action_runner": {"instructions": [{"type": "Nope"}]}}))
	f.close()

func _test_replay() -> void:
	var root := "res://addons/fuse/tests/preset_ai/fixtures/mini_ws"
	_make_fixture_workspace(root)
	var r: Dictionary = EvalRunner.run_replay(root, "iter-x")
	_check(r.results.size() == 2, "回放产出 2 条结果")
	var good: Array = r.results.filter(func(x): return x.path.contains("good"))
	var bad: Array = r.results.filter(func(x): return x.path.contains("bad"))
	_check(good.size() == 1 and bad.size() == 1, "good/bad 各命中 1 条")
	_check(good[0].get("pass") == true and bad[0].get("pass") == false, "good 过 bad 败")
	_check(r.summary.get("total", -1) == 2 and r.summary.get("pass", -1) == 1 and r.summary.get("fail", -1) == 1,
		"summary total/pass/fail = 2/1/1（实际: %s）" % JSON.stringify(r.summary))
	_check(r.regressions.is_empty(), "无 baseline → 无回归")

# Godot 4.7 的 DirAccess.remove_recursive 非静态，测试内自实现（前批先例）
func _remove_dir_recursive(dir_path: String) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	var names: Array[String] = []
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		names.append(n)
		n = d.get_next()
	d.list_dir_end()
	for name in names:
		var full := dir_path.path_join(name)
		if DirAccess.dir_exists_absolute(full):
			_remove_dir_recursive(full)
		else:
			DirAccess.remove_absolute(full)
	DirAccess.remove_absolute(dir_path)
