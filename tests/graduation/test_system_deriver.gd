# tests/graduation/test_system_deriver.gd
extends Node

## SystemDeriver 推导器测试（M1 毕业导出器）
##
## 真实场景（brickian game_scene，断言按 2026-08-31 实测收紧）+ 合成 fixture 双轨：
##   - kind 过滤（runner 跳过）/ 嵌套跳过 / 草稿数
##   - name snake_case + 重名唯一化
##   - events_out（含嵌套指令字段与 MultiEventTrigger event_bindings）/ events_in 提取
##   - variables 三层归并 / scope container 配对 / shared_outside 分量边界判定
##   - 连通分量：run 边 + 变量边（signal 死边不参与，spec §4.2）
##   - topology_digest 稳定性
##   - 竞态 warning 进报告、草稿 acknowledged_warnings 初始空

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("✓ " + msg)
	else:
		_fail += 1
		push_error("✗ " + msg)


func _ready() -> void:
	print("=== test_system_deriver ===")
	_test_derive_game_scene()
	_test_kind_filter_and_nested_skip()
	_test_name_dedup()
	_test_events_out_nested_and_multi()
	_test_scope_container_and_variables()
	_test_shared_outside_and_race_warning()
	_test_components_run_and_variable_edges()
	_test_components_signal_edge_excluded()
	_test_digest_stability()
	_test_cli_report_file()
	print("=== test_system_deriver 完成（失败 %d）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)


# ============================================================
# 真实场景（brickian game_scene）
# ============================================================

## 实测基线（2026-08-31，拓扑导出核实）：game_scene 共 19 单元
## = 7 顶层（6 Trigger + 1 MultiEventTrigger "GameFlow"）+ 11 嵌套 + 1 runner（SpawnEnemy）
func _test_derive_game_scene() -> void:
	var scene: PackedScene = load("res://demos/fuse/brickian/game_scene.tscn")
	var inst := scene.instantiate()
	add_child(inst)
	var result: Dictionary = SystemDeriver.derive_systems(inst, "res://demos/fuse/brickian/game_scene.tscn")
	var drafts: Array = result["drafts"]
	var report: Dictionary = result["report"]

	_check(drafts.size() == 7, "非 runner 非嵌套单元各一份草稿（实际 %d）" % drafts.size())
	var names: Array = drafts.map(func(d): return d["name"])
	_check(names.has("game_flow"), "GameFlow 有草稿")
	_check(not names.has("spawn_enemy"), "runner 单元被 kind 过滤（MVP 不推导）")
	_check(not names.has("movement"), "嵌套单元被跳过（需到子场景内推导）")
	_check(report["skipped_runner"] == 1, "报告记 runner 跳过数 = 1（实际 %d）" % report["skipped_runner"])
	_check(report["skipped_nested"].size() == 11, "报告记嵌套跳过数 = 11（实际 %d）" % report["skipped_nested"].size())
	# game_flow 与 SpawnEnemy 经 run 边同分量（RunRunner ../SpawnEnemy）
	var components: Dictionary = report["components"]
	_check("SpawnEnemy" in components.get("GameFlow", []), "run 边并入分量：game_flow ↔ SpawnEnemy")

	var gf: Dictionary = drafts.filter(func(d): return d["name"] == "game_flow")[0]
	_check(gf["format_version"] == "1.0", "format_version = 1.0")
	_check(gf["description"] == "", "description 推导时留空")
	_check(gf["units"].size() == 1, "MVP 恒单单元")
	var u: Dictionary = gf["units"][0]
	_check(u["id"] == "u1", "units id 稳定为 u1")
	_check(u["kind"] == "multi", "units kind = multi")
	_check(u["level"] == "L4", "GameFlow 草稿 L4（节点实取 detect_level）")
	_check(u["node_path"] == "GameManager/GameFlow", "node_path 去场景根前缀（实际 %s）" % u["node_path"])
	_check(u["scene"] == "res://demos/fuse/brickian/game_scene.tscn", "units scene")
	_check(gf["source"]["derived_from"] == "res://demos/fuse/brickian/game_scene.tscn", "溯源字段")
	_check(not str(gf["source"]["topology_digest"]).is_empty(), "topology_digest 非空")
	_check(gf["source"].has("derived_at") and not str(gf["source"]["derived_at"]).is_empty(), "derived_at 非空")

	# events_out 实测钉死：binding2 → ScoreUpdate/AllEnemyDied，binding3 → GameEnd/StartCountDown，binding4 → GameEnd（重复去重）
	var ev_out: Array = gf["externals"]["events_out"].map(func(e): return e["name"])
	_check(ev_out.size() == 4 and ev_out.has("ScoreUpdate") and ev_out.has("AllEnemyDied")
		and ev_out.has("GameEnd") and ev_out.has("StartCountDown"),
		"game_flow events_out 名单钉死 4 项（实际 %s）" % str(ev_out))
	for e: Dictionary in gf["externals"]["events_out"]:
		_check(e["outside_consumers"] == true, "events_out[%s].outside_consumers 恒 true（MVP 从宽）" % e["name"])

	# events_in 实测钉死：binding2/3/4 的 OnReceiveEvent
	var ev_in: Array = gf["externals"]["events_in"].map(func(e): return e["name"])
	_check(ev_in.size() == 3 and ev_in.has("EnemyDie") and ev_in.has("PlayerDie") and ev_in.has("AllEnemyDied"),
		"game_flow events_in 名单钉死 3 项（实际 %s）" % str(ev_in))
	for e: Dictionary in gf["externals"]["events_in"]:
		_check(e["outside_producers"] == true, "events_in[%s].outside_producers 恒 true（MVP 从宽）" % e["name"])

	# variables 归并（trigger 级 + 4 个 binding 级）后按 scope:name 索引
	var shared := {}
	for v: Dictionary in gf["externals"]["variables"]:
		shared["%s:%s" % [v["scope"], v["name"]]] = v["shared_outside"]
	_check(shared.get("local:event_score", null) == false, "local event_score 不跨单元")
	_check(shared.get("local:c_score", null) == false, "local c_score 不跨单元")
	_check(shared.get("global:score_list", null) == true, "global score_list 被 OnGameEnd 共用 → shared_outside")
	_check(shared.get("scope:current_wave", null) == true, "scope current_wave 被 RandomFireOnInterval 共用 → shared_outside")
	_check(shared.get("scope:instance_id", null) == true, "scope instance_id 多单元共用 → shared_outside")
	_check(shared.get("scope:player_life", null) == true, "scope player_life 被 OnPlayerDie 共用 → shared_outside")
	_check(shared.get("scope:start_pos", null) == false, "scope start_pos 无外部共享")
	_check(shared.get("scope:current_score", null) == false, "scope current_score 无外部共享")
	var score_list_entry: Array = gf["externals"]["variables"].filter(
		func(v): return v["name"] == "score_list" and v["scope"] == "global")
	_check(score_list_entry.size() == 1, "同名同层变量归并为一条")

	_check(gf["acknowledged_warnings"] == [], "草稿 acknowledged_warnings 初始空（待人工确认）")
	_check(gf["emit"]["output_script"] == "res://fuse_generated/scripts/game_flow.gd", "emit.output_script")
	_check(gf["emit"]["native_instructions"] == [], "emit.native_instructions 缺省空")
	inst.queue_free()


# ============================================================
# fixture 辅助
# ============================================================

## 构造 fixture 场景根（挂到测试节点下）
func _make_fixture_root(name: String) -> Node:
	var root := Node.new()
	root.name = name
	add_child(root)
	return root


## 构造顶层 Trigger（owner = root，避免 is_nested）
func _make_trigger(root: Node, tname: String) -> Trigger:
	var trigger := Trigger.new()
	trigger.name = tname
	root.add_child(trigger)
	trigger.set_owner(root)
	return trigger


func _make_send_event(ev_name: String) -> SendEvent:
	var send := SendEvent.new()
	send.event_name = ev_name
	return send


func _make_set_global(vname: String) -> SetVariable:
	var inst := SetVariable.new()
	inst.target_variable = vname
	inst.target_variable_scope = BaseVariable.VariableScope.GLOBAL
	return inst


# ============================================================
# fixture 用例
# ============================================================

func _test_kind_filter_and_nested_skip() -> void:
	var root := _make_fixture_root("FixtureKind")
	var trigger := _make_trigger(root, "TrigMain")
	var ar := ActionRunner.new()
	ar.instructions = [_make_send_event("Ping")]
	trigger.action_runner = ar

	# runner 单元（独立 Runner，父非 Trigger/MultiEventTrigger）
	var runner := Runner.new()
	runner.name = "SpawnLogic"
	root.add_child(runner)
	runner.set_owner(root)

	# 嵌套单元（owner 为子场景根而非 scene_root；容器需 set_owner(root)
	# 让 owner 链可达根——find_children 的 owned 过滤按 owner 链判定）
	var sub_root := Node.new()
	sub_root.name = "SubSceneRoot"
	root.add_child(sub_root)
	sub_root.set_owner(root)
	var nested := Trigger.new()
	nested.name = "NestedTrig"
	sub_root.add_child(nested)
	nested.set_owner(sub_root)

	var result: Dictionary = SystemDeriver.derive_systems(root, "res://test/fixture_kind.tscn")
	_check(result["drafts"].size() == 1, "runner 与嵌套均不出草稿（实际 %d）" % result["drafts"].size())
	_check(result["report"]["skipped_runner"] == 1, "skipped_runner = 1")
	_check(result["report"]["skipped_nested"] == ["NestedTrig"],
		"skipped_nested 名单（实际 %s）" % str(result["report"]["skipped_nested"]))
	var draft: Dictionary = result["drafts"][0]
	_check(draft["name"] == "trig_main", "name = snake_case(trigger_name)")
	_check(draft["units"][0]["level"] == "L2", "Trigger 层级 L2")
	var ev_out: Array = draft["externals"]["events_out"].map(func(e): return e["name"])
	_check(ev_out == ["Ping"], "普通 Trigger 主 action_runner 的 SendEvent 提取")
	root.queue_free()


func _test_name_dedup() -> void:
	var root := _make_fixture_root("FixtureDedup")
	_make_trigger(root, "Dup")
	var t2 := _make_trigger(root, "Dup")
	t2.name = "Dup"  # add_child 会自动改名 @node@N，显式恢复同名（.tscn 中同名兄弟合法）
	var result: Dictionary = SystemDeriver.derive_systems(root, "res://test/fixture_dedup.tscn")
	var names: Array = result["drafts"].map(func(d): return d["name"])
	_check(names.size() == 2 and "dup" in names and "dup_2" in names,
		"重名单元 snake_case 后唯一化（实际 %s）" % str(names))
	var scripts: Array = result["drafts"].map(func(d): return d["emit"]["output_script"])
	_check(scripts[0] != scripts[1], "唯一化后 output_script 不冲突")
	root.queue_free()


func _test_events_out_nested_and_multi() -> void:
	var root := _make_fixture_root("FixtureMulti")
	var multi := MultiEventTrigger.new()
	multi.name = "GameFlowX"
	root.add_child(multi)
	multi.set_owner(root)

	# binding 0：OnReceiveEvent + 直发 SendEvent
	var b0 := EventBinding.new()
	var recv := OnReceiveEvent.new()
	recv.event_name = "PlayerDie"
	b0.event = recv
	var ar0 := ActionRunner.new()
	ar0.instructions = [_make_send_event("Go")]
	b0.action_runner = ar0

	# binding 1：OnReady + IfElse.true_instructions 嵌套 SendEvent
	var b1 := EventBinding.new()
	b1.event = OnReady.new()
	var ar1 := ActionRunner.new()
	var ifelse := IfElse.new()
	ifelse.true_instructions = [_make_send_event("Nested")]
	ar1.instructions = [ifelse]
	b1.action_runner = ar1

	multi.event_bindings = [b0, b1]

	var result: Dictionary = SystemDeriver.derive_systems(root, "res://test/fixture_multi.tscn")
	var draft: Dictionary = result["drafts"][0]
	var ev_out: Array = draft["externals"]["events_out"].map(func(e): return e["name"])
	_check(ev_out == ["Go", "Nested"], "events_out 覆盖 bindings 与嵌套指令字段（实际 %s）" % str(ev_out))
	var ev_in: Array = draft["externals"]["events_in"].map(func(e): return e["name"])
	_check(ev_in == ["PlayerDie"], "events_in 从 event_bindings 的 OnReceiveEvent 提取")
	_check(draft["units"][0]["level"] == "L4", "MultiEventTrigger 层级 L4")
	root.queue_free()


func _test_scope_container_and_variables() -> void:
	var root := _make_fixture_root("FixtureScope")
	var trigger := _make_trigger(root, "TrigScope")
	var ar := ActionRunner.new()
	var sv_nearest := SetVariable.new()
	sv_nearest.target_variable = "hp_near"
	sv_nearest.target_variable_scope = BaseVariable.VariableScope.SCOPE
	var sv_target := SetVariable.new()
	sv_target.target_variable = "hp_target"
	sv_target.target_variable_scope = BaseVariable.VariableScope.SCOPE
	sv_target.scope_source = SetVariable.ScopeSource.TARGET_NODE
	sv_target.target_node_path = NodePath("../Target")
	var sv_global := _make_set_global("score")
	var sv_local := SetVariable.new()
	sv_local.target_variable = "tmp"
	ar.instructions = [sv_nearest, sv_target, sv_global, sv_local]
	trigger.action_runner = ar

	var result: Dictionary = SystemDeriver.derive_systems(root, "res://test/fixture_scope.tscn")
	var draft: Dictionary = result["drafts"][0]
	var vars: Array = draft["externals"]["variables"]
	var by_key := {}
	for v: Dictionary in vars:
		by_key["%s:%s" % [v["scope"], v["name"]]] = v
	_check(by_key.has("scope:hp_target") and by_key["scope:hp_target"].get("container", "") == "../Target",
		"TARGET_NODE 的 scope 变量带 container（NodePath 字符串）")
	_check(by_key.has("scope:hp_near") and not by_key["scope:hp_near"].has("container"),
		"NEAREST 的 scope 变量 container 缺省（运行时最近容器）")
	_check(by_key.has("global:score") and not by_key["global:score"].has("container"),
		"global 层无 container 字段")
	_check(by_key.has("local:tmp"), "local 层变量归并")
	root.queue_free()


func _test_shared_outside_and_race_warning() -> void:
	var root := _make_fixture_root("FixtureShare")
	var ta := _make_trigger(root, "TrigA")
	var ara := ActionRunner.new()
	ara.instructions = [_make_set_global("score")]
	ta.action_runner = ara
	var tb := _make_trigger(root, "TrigB")
	var arb := ActionRunner.new()
	arb.instructions = [_make_set_global("score")]
	tb.action_runner = arb

	var result: Dictionary = SystemDeriver.derive_systems(root, "res://test/fixture_share.tscn")
	var drafts: Array = result["drafts"]
	var da: Dictionary = drafts.filter(func(d): return d["name"] == "trig_a")[0]
	var score_entry: Array = da["externals"]["variables"].filter(func(v): return v["name"] == "score")
	_check(score_entry.size() == 1 and score_entry[0]["shared_outside"] == true,
		"其它单元共用同名 global 变量 → shared_outside = true")
	# 双写同名 global 无互斥 → 竞态预警进报告；草稿 acknowledged_warnings 仍空（待确认）
	var warn_by_unit: Dictionary = result["report"]["warnings_by_unit"]
	_check(warn_by_unit.has("TrigA") and warn_by_unit.has("TrigB"), "竞态 warning 按单元进推导报告")
	_check(da["acknowledged_warnings"] == [], "草稿 acknowledged_warnings 不自动填（人工确认）")
	root.queue_free()


func _test_components_run_and_variable_edges() -> void:
	var root := _make_fixture_root("FixtureComp")
	# run 边：TrigC 指令 RunRunner ../RunnerBind
	var tc := _make_trigger(root, "TrigC")
	var arc := ActionRunner.new()
	var run_inst := RunRunner.new()
	run_inst.target_runner = NodePath("../RunnerBind")
	arc.instructions = [run_inst]
	tc.action_runner = arc
	var runner := Runner.new()
	runner.name = "RunnerBind"
	root.add_child(runner)
	runner.set_owner(root)
	# 孤立单元（无边）
	_make_trigger(root, "TrigLone")

	var result: Dictionary = SystemDeriver.derive_systems(root, "res://test/fixture_comp.tscn")
	var components: Dictionary = result["report"]["components"]
	_check("RunnerBind" in components.get("TrigC", []), "run 边并入分量：TrigC ↔ RunnerBind")
	_check(components.get("TrigLone", ["x"]).is_empty(), "孤立单元分量为空")
	root.queue_free()


## signal 边为既有死代码（spec §4.2 注记），不参与分量计算。
## 构造子串撞名的 signal 边（"Spawn" ⊂ "SpawnLogic"）验证其被排除。
func _test_components_signal_edge_excluded() -> void:
	var root := _make_fixture_root("FixtureSignal")
	var spawn := _make_trigger(root, "Spawn")
	var logic := _make_trigger(root, "SpawnLogic")
	spawn.set_owner(root)
	logic.set_owner(root)
	# Runner 信号绑定 target 指向 SpawnLogic——_extract_signals 会因 target 含 "Spawn"
	# 同时记入 Spawn 的 signals，从而产生 signal 边 Spawn ↔ SpawnLogic（子串撞名）
	var runner := Runner.new()
	runner.name = "RunnerSig"
	root.add_child(runner)
	runner.set_owner(root)
	runner.set("signal_name", "notify")
	runner.set("target_node", str(root.get_path_to(logic)))

	var result: Dictionary = SystemDeriver.derive_systems(root, "res://test/fixture_signal.tscn")
	var components: Dictionary = result["report"]["components"]
	_check(components.get("Spawn", ["x"]).is_empty(), "signal 边不进分量：Spawn 独立")
	_check(components.get("SpawnLogic", ["x"]).is_empty(), "signal 边不进分量：SpawnLogic 独立")
	root.queue_free()


func _test_digest_stability() -> void:
	var scene: PackedScene = load("res://demos/fuse/brickian/game_scene.tscn")
	var inst_a := scene.instantiate()
	add_child(inst_a)
	var digest_a: String = SystemDeriver.derive_systems(inst_a, "res://demos/fuse/brickian/game_scene.tscn")["drafts"][0]["source"]["topology_digest"]
	inst_a.queue_free()
	var inst_b := scene.instantiate()
	add_child(inst_b)
	var digest_b: String = SystemDeriver.derive_systems(inst_b, "res://demos/fuse/brickian/game_scene.tscn")["drafts"][0]["source"]["topology_digest"]
	inst_b.queue_free()
	_check(digest_a == digest_b and not digest_a.is_empty(), "同拓扑两次推导 digest 一致（%s vs %s）" % [digest_a, digest_b])

	var root := _make_fixture_root("FixtureDigest")
	_make_trigger(root, "OnlyOne")
	var digest_c: String = SystemDeriver.derive_systems(root, "res://test/fixture_digest.tscn")["drafts"][0]["source"]["topology_digest"]
	_check(digest_c != digest_a, "不同拓扑 digest 不同")
	root.queue_free()


# ============================================================
# derive CLI 报告落盘（终审 I1：_derive_report.json + warnings_by_unit 四元组）
# ============================================================

## 双 Trigger 共写 global "score" 的竞态 fixture → 推导报告含可构造
## acknowledged_warnings 的完整四元组条目；CLI 的 write_report_file 为
## 独立 static（场景 _ready 会 quit 进程，测试直接断言其落盘行为）
func _test_cli_report_file() -> void:
	const DeriveCli := preload("res://addons/fuse/editor/graduation/derive_systems_cli.gd")
	var root := _make_fixture_root("FixtureCliReport")
	var ta := _make_trigger(root, "TrigA")
	var ara := ActionRunner.new()
	ara.instructions = [_make_set_global("score")]
	ta.action_runner = ara
	var tb := _make_trigger(root, "TrigB")
	var arb := ActionRunner.new()
	arb.instructions = [_make_set_global("score")]
	tb.action_runner = arb

	var result: Dictionary = SystemDeriver.derive_systems(root, "res://test/fixture_cli.tscn")
	root.queue_free()
	var out_dir := "user://grad_derive_report_ut"
	var err: int = DeriveCli.write_report_file(out_dir, result["report"])
	_check(err == OK, "write_report_file 落盘成功（err=%d）" % err)
	var path := out_dir + "/_derive_report.json"
	_check(FileAccess.file_exists(path), "_derive_report.json 写入 out_dir")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(parsed is Dictionary, "_derive_report.json 可解析")
	if not (parsed is Dictionary):
		return
	var payload: Dictionary = parsed
	for key: String in ["skipped_runner", "skipped_nested", "components", "warnings_by_unit"]:
		_check(payload.has(key), "报告含 %s（用户可据此构造 acknowledged_warnings）" % key)
	var warnings: Dictionary = payload.get("warnings_by_unit", {})
	_check(not warnings.is_empty(), "双写竞态 fixture 产出 warnings_by_unit 条目")
	var tuple_ok := true
	var saw_entry := false
	for unit: String in warnings:
		for entry_v: Variant in warnings[unit]:
			saw_entry = true
			var entry: Dictionary = entry_v if entry_v is Dictionary else {}
			if not entry.has_all(["type", "from", "to", "detail"]):
				tuple_ok = false
	_check(saw_entry and tuple_ok,
		"warnings_by_unit 条目为 type/from/to/detail 四元组（可整条拷入 acknowledged_warnings）")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
