# addons/fuse/tests/graduation/test_system_validator.gd
extends Node

## SystemValidator 校验器测试（M1 毕业导出器，spec §5）
##
## 正例走真实 fixture（Task 4 冒烟产出的 game_flow 草稿拷贝，acknowledged_warnings
## 已按 game_scene 实测竞态 0 条填空——"人工确认"动作的 fixture 化）；
## 负例内联构造：版本错 / 幽灵节点 / level 不符 / 竞态未确认 / emit 冲突，
## 另补 externals 解析（E_EXTERNAL_UNRESOLVED 正反 + I_CROSS_SCENE_EXTERNAL）
## 与 W_NESTED_UNIT 组。合成场景经 inject_scene_context 注入（无 .tscn 文件）。

var _fail := 0

const FIXTURE_PATH := "res://addons/fuse/tests/graduation/fixtures/game_flow_draft.json"


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("✓ " + msg)
	else:
		_fail += 1
		push_error("✗ " + msg)


func _codes(report: Dictionary) -> Array:
	return (report["findings"] as Array).map(func(f): return f["code"])


func _has_code(report: Dictionary, code: String) -> bool:
	return _codes(report).has(code)


func _ready() -> void:
	print("=== test_system_validator ===")
	_test_positive_game_flow()
	_test_negative_format_version()
	_test_negative_ghost_node()
	_test_negative_level_mismatch()
	_test_negative_race_unacknowledged()
	_test_negative_emit_conflict()
	_test_external_resolution()
	_test_nested_unit_warning()
	print("=== test_system_validator 完成（失败 %d）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)


# ============================================================
# 正例：真实 game_flow 草稿 fixture
# ============================================================

## game_scene 实测：GameFlow 与 SpawnEnemy 经 run 边同分量（Task 4 报告），
## 故正例必有 W_SINGLETON_IN_COMPONENT；竞态边 0 条 → acknowledged 空即通过
func _test_positive_game_flow() -> void:
	var report: Dictionary = SystemValidator.validate_system(FIXTURE_PATH)
	_check(report["errors"] == 0, "正例 fixture 零 error（实际 %d：%s）" % [report["errors"], str(_codes(report))])
	_check(_has_code(report, "W_SINGLETON_IN_COMPONENT"),
		"game_flow 与 SpawnEnemy 同分量 → W_SINGLETON_IN_COMPONENT")
	for f: Dictionary in report["findings"]:
		if f["code"] == "I_CROSS_SCENE_EXTERNAL":
			_check(f["severity"] == "info", "跨场景外联条目恒 info 级（%s）" % f["message"])


# ============================================================
# 负例 1：版本错
# ============================================================

func _test_negative_format_version() -> void:
	var draft := _draft("res://demos/fuse/brickian/game_scene.tscn", "GameManager/GameFlow", "L4")
	draft["format_version"] = "0.9"
	var report: Dictionary = SystemValidator.validate_data(draft)
	_check(_has_code(report, "E_FORMAT_VERSION"), "format_version 0.9 → E_FORMAT_VERSION")


# ============================================================
# 负例 2：幽灵节点
# ============================================================

func _test_negative_ghost_node() -> void:
	var root := _inject_scene("res://test/ut_race.tscn", "RaceScene")
	_make_race_fixture(root)
	var draft := _draft("res://test/ut_race.tscn", "Ghost", "L2")
	var report: Dictionary = SystemValidator.validate_data(draft)
	_check(_has_code(report, "E_UNIT_NOT_FOUND"), "node_path=Ghost 解析不到 → E_UNIT_NOT_FOUND")
	_check(not _has_code(report, "E_UNIT_LEVEL_MISMATCH"), "幽灵节点不级联 level 错（先 continue）")
	SystemValidator.clear_scene_cache()
	root.queue_free()


# ============================================================
# 负例 3：level 不符
# ============================================================

func _test_negative_level_mismatch() -> void:
	var root := _inject_scene("res://test/ut_race.tscn", "RaceScene")
	_make_race_fixture(root)
	var draft := _draft("res://test/ut_race.tscn", "TrigA", "L4")
	var report: Dictionary = SystemValidator.validate_data(draft)
	_check(_has_code(report, "E_UNIT_LEVEL_MISMATCH"), "Trigger 声明 L4 → E_UNIT_LEVEL_MISMATCH")
	SystemValidator.clear_scene_cache()
	root.queue_free()


# ============================================================
# 负例 4：竞态未确认（+ 确认后消除的对照）
# ============================================================

func _test_negative_race_unacknowledged() -> void:
	var root := _inject_scene("res://test/ut_race.tscn", "RaceScene")
	_make_race_fixture(root)
	var draft := _draft("res://test/ut_race.tscn", "TrigA", "L2")
	var report: Dictionary = SystemValidator.validate_data(draft)
	_check(_has_code(report, "E_WARNING_NOT_ACKNOWLEDGED"),
		"双写 global score 竞态未确认 → E_WARNING_NOT_ACKNOWLEDGED")
	# 人工确认动作：填入 deriver 推导报告同构的 warning 条目（from/to/type/detail）
	draft["acknowledged_warnings"] = [{
		"from": "TrigA", "to": "TrigB",
		"type": "variable_write_to_write", "detail": "score", "warning": true,
	}]
	var confirmed: Dictionary = SystemValidator.validate_data(draft)
	_check(not _has_code(confirmed, "E_WARNING_NOT_ACKNOWLEDGED"),
		"acknowledged_warnings 填对应条目后该 error 消除")
	SystemValidator.clear_scene_cache()
	root.queue_free()


# ============================================================
# 负例 5：emit 冲突（+ 旧生成物允许覆盖的对照）
# ============================================================

func _test_negative_emit_conflict() -> void:
	var root := _inject_scene("res://test/ut_race.tscn", "RaceScene")
	_make_race_fixture(root)
	var probe := "user://ut_graduation_emit_probe.gd"
	var draft := _draft("res://test/ut_race.tscn", "TrigA", "L2")
	draft["emit"]["output_script"] = probe

	_write_file(probe, "# 手写的业务脚本\nextends Node\n")
	var report: Dictionary = SystemValidator.validate_data(draft)
	_check(_has_code(report, "E_EMIT_TARGET_CONFLICT"),
		"目标已存在且头注释无生成器标记 → E_EMIT_TARGET_CONFLICT")

	_write_file(probe, "# ====\n# 由 Fuse 场景毕业导出器生成 — 请勿手工编辑委托数据块\n")
	var regen: Dictionary = SystemValidator.validate_data(draft)
	_check(not _has_code(regen, "E_EMIT_TARGET_CONFLICT") and _has_code(regen, "I_OVERWRITE_GENERATED"),
		"头注释含「毕业导出器生成」标记 → 允许覆盖（info I_OVERWRITE_GENERATED）")
	_check(regen["errors"] == report["errors"] - 1, "覆盖场景不计 error")

	DirAccess.remove_absolute(probe)
	SystemValidator.clear_scene_cache()
	root.queue_free()


# ============================================================
# externals 解析（E_EXTERNAL_UNRESOLVED 正反 + I_CROSS_SCENE_EXTERNAL）
# ============================================================

func _test_external_resolution() -> void:
	var root := _inject_scene("res://test/ut_ext.tscn", "ExtScene")
	var trig_x := _make_trigger(root, "TrigX")
	var arx := ActionRunner.new()
	var sv := SetVariable.new()
	sv.target_variable = "hp"
	sv.target_variable_scope = BaseVariable.VariableScope.SCOPE
	arx.instructions = [sv]
	trig_x.action_runner = arx
	var trig_y := _make_trigger(root, "TrigY")
	var ary := ActionRunner.new()
	ary.instructions = [_make_send_event("RealEvent")]
	trig_y.action_runner = ary

	# scope 变量名不在拓扑 → error
	var draft := _draft("res://test/ut_ext.tscn", "TrigX", "L2")
	draft["externals"]["variables"] = [{"name": "ghost_var", "scope": "scope"}]
	var report: Dictionary = SystemValidator.validate_data(draft)
	_check(_has_code(report, "E_EXTERNAL_UNRESOLVED"), "scope 变量 ghost_var 拓扑无此名 → E_EXTERNAL_UNRESOLVED")

	# 声明场景内有生产者（outside_producers=false）但拓扑无产出 → error
	draft["externals"]["variables"] = []
	draft["externals"]["events_in"] = [{"name": "GhostEvent", "outside_producers": false}]
	report = SystemValidator.validate_data(draft)
	_check(_has_code(report, "E_EXTERNAL_UNRESOLVED"),
		"outside_producers=false 且同场景无生产者 → E_EXTERNAL_UNRESOLVED")

	# 同场景确有生产者 → 无 finding
	draft["externals"]["events_in"] = [{"name": "RealEvent", "outside_producers": false}]
	report = SystemValidator.validate_data(draft)
	_check(not _has_code(report, "E_EXTERNAL_UNRESOLVED"), "同场景生产者存在 → 无 error")

	# outside_producers=true 且场景内无生产者 → 跨场景 info（从宽，不计 error）
	draft["externals"]["events_in"] = [{"name": "CrossEvent", "outside_producers": true}]
	report = SystemValidator.validate_data(draft)
	_check(_has_code(report, "I_CROSS_SCENE_EXTERNAL") and report["errors"] == 0,
		"跨场景依赖 → I_CROSS_SCENE_EXTERNAL info 级不计 error")
	SystemValidator.clear_scene_cache()
	root.queue_free()


# ============================================================
# W_NESTED_UNIT
# ============================================================

func _test_nested_unit_warning() -> void:
	var root := _inject_scene("res://test/ut_nest.tscn", "NestScene")
	var sub_root := Node.new()
	sub_root.name = "SubRoot"
	root.add_child(sub_root)
	sub_root.set_owner(root)
	var nested := _make_trigger(sub_root, "NestedTrig")
	nested.set_owner(sub_root)

	var draft := _draft("res://test/ut_nest.tscn", "SubRoot/NestedTrig", "L2")
	var report: Dictionary = SystemValidator.validate_data(draft)
	_check(_has_code(report, "W_NESTED_UNIT"), "单元位于实例化子场景内 → W_NESTED_UNIT")
	_check(report["errors"] == 0, "嵌套单元仅 warning 不阻断")
	SystemValidator.clear_scene_cache()
	root.queue_free()


# ============================================================
# fixture 辅助
# ============================================================

## 构造合成场景根并注入校验器场景缓存（挂测试节点下——find_children 需 in-tree）
func _inject_scene(scene_path: String, rname: String) -> Node:
	var root := Node.new()
	root.name = rname
	add_child(root)
	SystemValidator.inject_scene_context(scene_path, root)
	return root


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


## 双 Trigger 共写 global "score" 且无互斥 → variable_write_to_write 竞态边
func _make_race_fixture(root: Node) -> void:
	var ta := _make_trigger(root, "TrigA")
	var ara := ActionRunner.new()
	var sva := SetVariable.new()
	sva.target_variable = "score"
	sva.target_variable_scope = BaseVariable.VariableScope.GLOBAL
	ara.instructions = [sva]
	ta.action_runner = ara
	var tb := _make_trigger(root, "TrigB")
	var arb := ActionRunner.new()
	var svb := SetVariable.new()
	svb.target_variable = "score"
	svb.target_variable_scope = BaseVariable.VariableScope.GLOBAL
	arb.instructions = [svb]
	tb.action_runner = arb


## 最小合法草稿骨架（externals 空、emit 目标不存在）
func _draft(scene_path: String, node_path: String, level: String) -> Dictionary:
	return {
		"format_version": "1.0",
		"name": "ut_draft",
		"description": "",
		"source": {"derived_from": scene_path, "derived_at": "", "topology_digest": ""},
		"units": [{
			"id": "u1", "kind": "trigger", "scene": scene_path,
			"node_path": node_path, "level": level,
		}],
		"externals": {"events_out": [], "events_in": [], "variables": []},
		"acknowledged_warnings": [],
		"emit": {"output_script": "user://ut_graduation_no_such.gd", "native_instructions": []},
	}


func _write_file(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(content)
		f.close()
