# addons/fuse/tests/topology/test_runner_topology.gd
extends Node

## Runner（L3 信号绑定单元）拓扑扫描单测
##
## build_topology 覆盖 Runner 单元：
##   - kind 判别字段（trigger / runner）
##   - runner report 携带 signal_binding（signal_name + target_node）
##   - RunRunner 调用边（cross_references type: "run"）
##   - 竞态预警覆盖 runner 单元（variable_write_to_write）

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("✓ " + msg)
	else:
		_fail += 1
		push_error("✗ " + msg)


## 构造写 GLOBAL 变量的 SetVariable
## 注：target_variable_scope 默认 LOCAL，必须显式设 GLOBAL 才进 global 桶（竞态分析数据源）
func _make_set_global(vname: String, value: int) -> SetVariable:
	var inst := SetVariable.new()
	inst.target_variable = vname
	inst.target_variable_scope = BaseVariable.VariableScope.GLOBAL
	inst.new_value = value
	return inst


func _ready() -> void:
	print("=== test_runner_topology ===")
	# fixture：root + 触发器（写 score + RunRunner 调 SpawnLogic）+ 独立 runner（也写 score）
	var root := Node.new()
	root.name = "FixtureScene"
	add_child(root)

	var trigger := Trigger.new()
	trigger.name = "TrigA"
	root.add_child(trigger)
	trigger.set_owner(root)  # find_children(owned=true) 需要显式 owner
	var ar_trig := ActionRunner.new()
	var run_inst := RunRunner.new()
	run_inst.target_runner = NodePath("../SpawnLogic")
	ar_trig.instructions = [_make_set_global("score", 1), run_inst]
	trigger.action_runner = ar_trig

	var runner := Runner.new()
	runner.name = "SpawnLogic"
	root.add_child(runner)
	runner.set_owner(root)
	var ar_run := ActionRunner.new()
	ar_run.instructions = [_make_set_global("score", 2)]
	runner.action_runner = ar_run
	runner.signal_name = "spawn_requested"
	runner.target_node = NodePath("../TrigA")

	var topology: Dictionary = InstructionAnalyzer.build_topology(root)
	var names := {}
	for report in topology.triggers:
		names[report.get("trigger_name", "")] = report
	_check(names.has("TrigA") and names["TrigA"].get("kind") == "trigger", "TrigA 在拓扑且 kind=trigger")
	_check(names.has("SpawnLogic") and names["SpawnLogic"].get("kind") == "runner", "SpawnLogic 在拓扑且 kind=runner")
	var sb: Dictionary = names.get("SpawnLogic", {}).get("signal_binding", {})
	_check(sb.get("signal_name", "") == "spawn_requested", "runner report 带 signal_binding")
	var run_edges: Array = topology.cross_references.filter(func(e): return e.get("type") == "run")
	_check(run_edges.any(func(e): return e.get("from") == "TrigA" and e.get("to") == "SpawnLogic"),
		"RunRunner 调用边 TrigA → SpawnLogic 存在")
	var races: Array = topology.cross_references.filter(func(e): return e.get("type") == "variable_write_to_write")
	_check(races.any(func(e): return str(e.get("detail")) == "score"), "score 双写竞态预警覆盖 runner 单元")
	root.queue_free()
	print("=== 结果: %d 失败 ===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)
