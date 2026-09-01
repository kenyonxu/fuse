# tests/topology/test_topology_filter.gd
extends Node

## 拓扑搜索过滤单测（FuseTopology.report_matches_filter static 匹配函数）
##
## 匹配面：单元名 / 三层变量名（local/scope/global）/ binding 变量名
##        / 指令类型名（instructions_flat + instructions_tree 递归 + event_bindings 链）
##        / signal_binding.signal_name / signals[].signal
## 字段名实测（instruction_analyzer.gd _analyze_instructions）：
##   instructions_flat 条目 = {"name", "prefix"}；instructions_tree 节点 = {"name", "inst", "children"}

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("✓ " + msg)
	else:
		_fail += 1
		push_error("✗ " + msg)


## 指令条目字段名与生产侧一致（"name"，非 "type"）
func _report_fixture() -> Dictionary:
	return {
		"trigger_name": "TrigA",
		"kind": "trigger",
		"variables": {"local": [], "scope": [], "global": [{"name": "score", "mode": "write"}]},
		"instructions_flat": [{"name": "RunRunner", "prefix": ""}, {"name": "SetVariable", "prefix": ""}],
		"instructions_tree": [{"name": "IfThen", "inst": null, "children": {
			"then": [{"name": "DeepNested", "inst": null, "children": {}}],
		}}],
		"signals": [{"signal": "pressed", "target": "../Btn"}],
		"signal_binding": {"signal_name": "spawn_requested", "target_node": ""},
		"event_bindings": [],
	}


## MultiEventTrigger fixture：指令链与变量只存在于 event_bindings（顶层列表为空）
func _binding_fixture() -> Dictionary:
	return {
		"trigger_name": "MultiA",
		"kind": "multi",
		"variables": {"local": [], "scope": [], "global": []},
		"instructions_flat": [],
		"instructions_tree": [],
		"signals": [],
		"signal_binding": {},
		"event_bindings": [{
			"index": 0,
			"event": {"resource_name": "OnKeyDown", "type": "OnKeyDown"},
			"enabled": true,
			"variables": {"local": [], "scope": [], "global": [{"name": "hp", "mode": "read"}]},
			"instructions_flat": [{"name": "PlaySound", "prefix": ""}],
			"instructions_tree": [],
		}],
	}


func _ready() -> void:
	print("=== test_topology_filter ===")
	_test_match()
	_test_bindings()
	print("=== 结果: %d 失败 ===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)


func _test_match() -> void:
	var r: Dictionary = _report_fixture()
	_check(FuseTopology.report_matches_filter(r, ""), "空文本恒过")
	_check(FuseTopology.report_matches_filter(r, "triga"), "单元名大小写不敏感")
	_check(FuseTopology.report_matches_filter(r, "score"), "变量名命中")
	_check(FuseTopology.report_matches_filter(r, "runrunner"), "flat 指令类型命中")
	_check(FuseTopology.report_matches_filter(r, "ifthen"), "树指令类型命中")
	_check(FuseTopology.report_matches_filter(r, "deepnested"), "树子分支递归命中")
	_check(FuseTopology.report_matches_filter(r, "spawn_requested"), "signal_binding 命中")
	_check(FuseTopology.report_matches_filter(r, "pressed"), "signals 命中")
	_check(not FuseTopology.report_matches_filter(r, "nosuchthing"), "无命中不过")


func _test_bindings() -> void:
	var r: Dictionary = _binding_fixture()
	_check(FuseTopology.report_matches_filter(r, "multia"), "multi 单元名命中")
	_check(FuseTopology.report_matches_filter(r, "hp"), "binding 变量名命中")
	_check(FuseTopology.report_matches_filter(r, "playsound"), "binding 指令链命中")
	_check(not FuseTopology.report_matches_filter(r, "score"), "他单元变量不串扰")
