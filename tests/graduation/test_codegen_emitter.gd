# tests/graduation/test_codegen_emitter.gd
extends Node

## EventMapper + GdscriptEmitter 测试（M2 毕业导出器核心）
##
## 三层覆盖：
##   1. emit_instruction 单元级——直接构造指令对象断言生成的代码行
##      （白名单 9 类原生直译 + 各委托降级分支）
##   2. EventMapper.map_event——四类白名单事件的接线形态 + 非白名单拒绝
##   3. emit_system 系统级——L2/L4 fixture 组装完整脚本断言关键行
##      （头注释/preload/_DELEGATED/gate_allows/teardown/入口函数），
##      并把产物写到 user:// 临时 .gd 后 load() 做解析冒烟（T7 前移）。

var _fail := 0
var _smoke_seq := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("✓ " + msg)
	else:
		_fail += 1
		push_error("✗ " + msg)


func _ready() -> void:
	print("=== test_codegen_emitter ===")
	_test_wait_native()
	_test_wait_variable_delegated()
	_test_print_native()
	_test_tween_delegated()
	_test_set_variable_native_and_copy_delegated()
	_test_math_operation_native()
	_test_math_operation_local_delegated()
	_test_math_operation_modulo_fmod()
	_test_math_operation_divide_by_zero()
	_test_send_event_native_and_ref_delegated()
	_test_show_hide_ui_native()
	_test_set_ui_text_native()
	_test_save_load_global_variables()
	_test_map_ready()
	_test_map_input_modes()
	_test_map_interval()
	_test_map_receive()
	_test_map_unsupported_event()
	_test_emit_system_l2_golden()
	_test_emit_system_l2_runner_child_fallback()
	_test_emit_system_l4_multi_and_disabled()
	_test_emit_system_mixed_native_delegated()
	_test_emit_system_rejections()
	_test_emit_system_conditions_gate_phases()
	_test_emit_system_local_whole_delegated()
	_test_emit_system_segments_merged()
	_test_report_risk_fields()
	_test_parse_smoke_all_event_kinds()
	_test_parse_smoke_modulo_and_conditions()
	_test_parse_smoke_local_busy()
	print("=== test_codegen_emitter 完成（失败 %d）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)


# ============================================================
# emit_instruction 单元级
# ============================================================

func _test_wait_native() -> void:
	var w := Wait.new()
	w.wait_time = 0.5
	var line: String = GdscriptEmitter.emit_instruction(w, "\t")
	_check(line.contains("await get_tree().create_timer(0.5).timeout"), "Wait 原生直译: %s" % line)


func _test_wait_variable_delegated() -> void:
	var w := Wait.new()
	w.value_source = Wait.ValueSource.VARIABLE
	w.wait_time_variable = "delay_secs"
	var line: String = GdscriptEmitter.emit_instruction(w, "\t")
	_check(line.strip_edges().begins_with("await FuseDelegation.run"), "Wait 变量模式走委托: %s" % line)


func _test_print_native() -> void:
	var p := Print.new()
	p.message = "hi"
	var line: String = GdscriptEmitter.emit_instruction(p, "\t")
	_check(line.contains('print("hi")'), "Print 原生直译: %s" % line)


func _test_tween_delegated() -> void:
	var t: BaseInstruction = load("res://addons/fuse/instructions/tween/tween_move_to.gd").new()
	var line: String = GdscriptEmitter.emit_instruction(t, "\t")
	_check(line.strip_edges().begins_with("await FuseDelegation.run"), "非白名单指令走委托: %s" % line)


func _test_set_variable_native_and_copy_delegated() -> void:
	var s := SetVariable.new()
	s.target_variable = "hp"
	s.target_variable_scope = BaseVariable.VariableScope.GLOBAL
	s.new_value = 10
	var line: String = GdscriptEmitter.emit_instruction(s, "\t")
	_check(line.contains('FuseDelegation.set_var(self, "hp", 10, "global")'),
		"SetVariable 字面量模式原生: %s" % line)

	var copy := SetVariable.new()
	copy.target_variable = "hp"
	copy.set_with_another_variable = true
	copy.from_variable = "max_hp"
	var line2: String = GdscriptEmitter.emit_instruction(copy, "\t")
	_check(line2.strip_edges().begins_with("await FuseDelegation.run"),
		"SetVariable 变量复制模式委托（set_with_another_variable）: %s" % line2)

	# 终审 C1：LOCAL 目标委托（原生写进即抛的临时 ctx 必丢失）
	var local_target := SetVariable.new()
	local_target.target_variable = "tmp"
	local_target.target_variable_scope = BaseVariable.VariableScope.LOCAL
	local_target.new_value = 1
	var line3: String = GdscriptEmitter.emit_instruction(local_target, "\t")
	_check(line3.strip_edges().begins_with("await FuseDelegation.run"),
		"SetVariable LOCAL 目标委托（终审 C1）: %s" % line3)


func _test_math_operation_native() -> void:
	var m := MathOperation.new()
	m.operation_type = MathOperation.OperationType.ADD
	m.operand_a_source = MathOperation.OperandASource.VALUE
	m.operand_a_value = 2.0
	m.operand_b_source = MathOperation.OperandBSource.VARIABLE
	m.operand_b_variable = "bonus"
	m.operand_b_scope = BaseVariable.VariableScope.GLOBAL
	m.save_to_variable = "score"
	m.save_to_scope = BaseVariable.VariableScope.GLOBAL
	var block: String = GdscriptEmitter.emit_instruction(m, "\t")
	_check(block.contains('FuseDelegation.get_var(self, "bonus", "global")'),
		"MathOperation 变量操作数经桥读取: %s" % block)
	_check(block.contains('FuseDelegation.set_var(self, "score",'),
		"MathOperation 结果经桥写回: %s" % block)
	_check(block.contains(" + "), "MathOperation ADD 运算符直译: %s" % block)
	_check(not block.contains("await FuseDelegation.run"), "MathOperation 原生非委托")


## 终审 C1：LOCAL 层变量操作的原生发射一律降级委托——原生行写 LOCAL 进即抛的
## 临时 ctx（写=静默丢失）、读恒 miss 后回退 global 同名变量（读到错值）
func _test_math_operation_local_delegated() -> void:
	var save_local := MathOperation.new()
	save_local.operation_type = MathOperation.OperationType.ADD
	save_local.operand_a_source = MathOperation.OperandASource.VALUE
	save_local.operand_a_value = 2.0
	save_local.operand_b_source = MathOperation.OperandBSource.VALUE
	save_local.operand_b_value = 3.0
	save_local.save_to_variable = "score"
	save_local.save_to_scope = BaseVariable.VariableScope.LOCAL
	var block: String = GdscriptEmitter.emit_instruction(save_local, "\t")
	_check(block.strip_edges().begins_with("await FuseDelegation.run"),
		"MathOperation 写回 LOCAL → 委托（原生写进即抛 ctx 必丢失）: %s" % block)

	var read_local := MathOperation.new()
	read_local.operation_type = MathOperation.OperationType.ADD
	read_local.operand_a_source = MathOperation.OperandASource.VARIABLE
	read_local.operand_a_variable = "bonus"
	read_local.operand_a_scope = BaseVariable.VariableScope.LOCAL
	read_local.operand_b_source = MathOperation.OperandBSource.VALUE
	read_local.operand_b_value = 3.0
	read_local.save_to_variable = "score"
	read_local.save_to_scope = BaseVariable.VariableScope.GLOBAL
	var block2: String = GdscriptEmitter.emit_instruction(read_local, "\t")
	_check(block2.strip_edges().begins_with("await FuseDelegation.run"),
		"MathOperation LOCAL 操作数 → 委托（原生读恒 miss 回退 global 同名错值）: %s" % block2)


func _test_math_operation_modulo_fmod() -> void:
	var m := MathOperation.new()
	m.operation_type = MathOperation.OperationType.MODULO
	m.operand_a_source = MathOperation.OperandASource.VALUE
	m.operand_a_value = 7.0
	m.operand_b_source = MathOperation.OperandBSource.VALUE
	m.operand_b_value = 3.0
	m.save_to_variable = "rem"
	m.save_to_scope = BaseVariable.VariableScope.GLOBAL
	var block: String = GdscriptEmitter.emit_instruction(m, "\t")
	_check(block.contains("fmod("), "MathOperation MODULO 用 fmod（%% 仅支持 int）: %s" % block)
	_check(not block.contains(" % "), "MODULO 不生成 %% 运算符: %s" % block)


func _test_math_operation_divide_by_zero() -> void:
	var m := MathOperation.new()
	m.operation_type = MathOperation.OperationType.DIVIDE
	m.operand_a_source = MathOperation.OperandASource.VALUE
	m.operand_a_value = 10.0
	m.operand_b_source = MathOperation.OperandBSource.VALUE
	m.operand_b_value = 0.0
	m.save_to_variable = "ratio"
	m.save_to_scope = BaseVariable.VariableScope.GLOBAL
	var block: String = GdscriptEmitter.emit_instruction(m, "\t")
	_check(block.contains("if is_zero_approx("), "DIVIDE 除零守卫（对齐 Fuse RUNTIME_ERROR）: %s" % block)
	_check(block.contains("push_error(") and block.contains("return"),
		"除零报错并中断后续指令: %s" % block)
	var mod := MathOperation.new()
	mod.operation_type = MathOperation.OperationType.MODULO
	mod.operand_a_source = MathOperation.OperandASource.VALUE
	mod.operand_a_value = 7.0
	mod.operand_b_source = MathOperation.OperandBSource.VALUE
	mod.operand_b_value = 3.0
	mod.save_to_variable = "rem"
	mod.save_to_scope = BaseVariable.VariableScope.GLOBAL
	var mod_block: String = GdscriptEmitter.emit_instruction(mod, "\t")
	_check(mod_block.contains("is_zero_approx("), "MODULO 同享除零守卫")
	var add := MathOperation.new()
	add.operation_type = MathOperation.OperationType.ADD
	add.operand_a_source = MathOperation.OperandASource.VALUE
	add.operand_a_value = 1.0
	add.operand_b_source = MathOperation.OperandBSource.VALUE
	add.operand_b_value = 2.0
	add.save_to_variable = "sum"
	add.save_to_scope = BaseVariable.VariableScope.GLOBAL
	var add_block: String = GdscriptEmitter.emit_instruction(add, "\t")
	_check(not add_block.contains("is_zero_approx("), "ADD 不生成除零守卫")


func _test_send_event_native_and_ref_delegated() -> void:
	var s := SendEvent.new()
	s.event_name = "score_changed"
	s.event_args = {"amount": 5}
	var line: String = GdscriptEmitter.emit_instruction(s, "\t")
	_check(line.contains('FuseDelegation.send_event("score_changed", {"amount":5})'),
		"SendEvent 字面量参数原生: %s" % line)

	var ref := SendEvent.new()
	ref.event_name = "score_changed"
	ref.event_args = {"amount": "$score"}
	var line2: String = GdscriptEmitter.emit_instruction(ref, "\t")
	_check(line2.strip_edges().begins_with("await FuseDelegation.run"),
		"SendEvent $variable 引用参数委托: %s" % line2)


func _test_show_hide_ui_native() -> void:
	var show := ShowHideUI.new()
	show.target_node = NodePath("UI/Panel")
	show.action = ShowHideUI.Action.SHOW
	var line: String = GdscriptEmitter.emit_instruction(show, "\t")
	_check(line.contains('(get_node("UI/Panel") as Control).show()'),
		"ShowHideUI SHOW 原生: %s" % line)

	var toggle := ShowHideUI.new()
	toggle.target_node = NodePath("UI/Panel")
	toggle.action = ShowHideUI.Action.TOGGLE
	var block: String = GdscriptEmitter.emit_instruction(toggle, "\t")
	_check(block.contains("visible = not "), "ShowHideUI TOGGLE 原生: %s" % block)

	var by_var := ShowHideUI.new()
	by_var.use_variable_for_target = true
	by_var.target_variable = "panel_node"
	var line3: String = GdscriptEmitter.emit_instruction(by_var, "\t")
	_check(line3.strip_edges().begins_with("await FuseDelegation.run"),
		"ShowHideUI 变量目标模式委托: %s" % line3)


func _test_set_ui_text_native() -> void:
	var t := SetUIText.new()
	t.target_node = NodePath("UI/Label")
	t.text = "hello"
	var line: String = GdscriptEmitter.emit_instruction(t, "\t")
	_check(line.contains('(get_node("UI/Label") as Control).set("text", "hello")'),
		"SetUIText 字面量模式原生: %s" % line)

	var by_var := SetUIText.new()
	by_var.use_variable = true
	by_var.text_variable = "label_text"
	var line2: String = GdscriptEmitter.emit_instruction(by_var, "\t")
	_check(line2.strip_edges().begins_with("await FuseDelegation.run"),
		"SetUIText 文本变量模式委托: %s" % line2)


func _test_save_load_global_variables() -> void:
	var save := SaveGlobalVariables.new()
	save.save_target = SaveGlobalVariables.SaveTarget.CUSTOM_PATH
	save.custom_path = "res://saves/game.tres"
	save.save_scope = SaveGlobalVariables.SaveScope.PERSISTENT_ONLY
	var line: String = GdscriptEmitter.emit_instruction(save, "\t")
	_check(line.contains('GlobalVariableManager.get_instance().save_persistent_to_resource("res://saves/game.tres")'),
		"SaveGlobalVariables CUSTOM_PATH 原生: %s" % line)

	var load_inst := LoadGlobalVariables.new()
	load_inst.load_source = LoadGlobalVariables.LoadSource.CUSTOM_PATH
	load_inst.custom_path = "res://saves/game.tres"
	var line2: String = GdscriptEmitter.emit_instruction(load_inst, "\t")
	_check(line2.contains('GlobalVariableManager.get_instance().load_from_resource("res://saves/game.tres")'),
		"LoadGlobalVariables CUSTOM_PATH 原生: %s" % line2)

	var assistant := SaveGlobalVariables.new()
	assistant.save_target = SaveGlobalVariables.SaveTarget.ASSISTANT_RESOURCE
	var line3: String = GdscriptEmitter.emit_instruction(assistant, "\t")
	_check(line3.strip_edges().begins_with("await FuseDelegation.run"),
		"SaveGlobalVariables ASSISTANT_RESOURCE 委托（路径运行时检测）: %s" % line3)


# ============================================================
# EventMapper
# ============================================================

func _test_map_ready() -> void:
	var ev0 := OnReady.new()
	var m0: Dictionary = EventMapper.map_event(ev0, "u1")
	_check(m0.get("mode", "") == "ready", "OnReady mode=ready")
	_check(m0.get("setup_code", "").contains("_on_u1.call_deferred()"),
		"OnReady delay=0 生成 call_deferred 一帧延迟（对齐 Fuse）: %s" % m0.get("setup_code", ""))

	var ev5 := OnReady.new()
	ev5.delay_seconds = 1.5
	var m5: Dictionary = EventMapper.map_event(ev5, "u1")
	_check(m5.get("setup_code", "").contains("wait_time = 1.5") and m5.get("setup_code", "").contains("one_shot = true"),
		"OnReady delay>0 one-shot Timer: %s" % m5.get("setup_code", ""))


func _test_map_input_modes() -> void:
	var cases := [
		[OnInputAction.TriggerMode.JUST_PRESSED, "Input.is_action_just_pressed(\"jump\")"],
		[OnInputAction.TriggerMode.JUST_RELEASED, "Input.is_action_just_released(\"jump\")"],
		[OnInputAction.TriggerMode.HOLD, "Input.is_action_pressed(\"jump\")"],
		[OnInputAction.TriggerMode.PRESSED_OR_RELEASED, "Input.is_action_just_pressed(\"jump\") or Input.is_action_just_released(\"jump\")"],
	]
	for case: Array in cases:
		var ev := OnInputAction.new()
		ev.target_input_action = "jump"
		ev.trigger_mode = case[0]
		var m: Dictionary = EventMapper.map_event(ev, "u1")
		_check(m.get("mode", "") == "input", "OnInputAction mode=input")
		_check(m.get("input_branch", "").contains('event.is_action("jump")'),
			"OnInputAction 分支含 is_action 过滤: %s" % m.get("input_branch", ""))
		_check(m.get("input_branch", "").contains(case[1]),
			"OnInputAction trigger_mode=%d 分支: %s" % [case[0], m.get("input_branch", "")])


func _test_map_interval() -> void:
	var ev := OnInterval.new()
	ev.interval_seconds = 2.0
	ev.max_repeats = 3
	var m: Dictionary = EventMapper.map_event(ev, "u1")
	_check(m.get("mode", "") == "interval", "OnInterval mode=interval")
	var wiring: String = m.get("wiring_code", "")
	_check(wiring.contains("_setup_interval_u1") and wiring.contains("_on_interval_u1"),
		"OnInterval 生成 Timer 成员与滴答函数: %s" % wiring.substr(0, 80))
	_check(wiring.contains("wait_time = 2.0"), "OnInterval 间隔直译")
	_check(wiring.contains("_repeats_u1 >= 3"), "OnInterval max_repeats 计数")
	_check(m.get("setup_code", "").contains("_setup_interval_u1()"), "OnInterval auto_start 接进 _ready")

	var stop := OnInterval.new()
	stop.interval_seconds = 1.0
	stop.stop_condition = CheckVariable.new()
	var m2: Dictionary = EventMapper.map_event(stop, "u1")
	var wiring2: String = m2.get("wiring_code", "")
	_check(wiring2.contains("FuseDelegation.check_condition(self, {"),
		"OnInterval stop_condition 仍原生（每滴 check_condition）: %s" % wiring2.substr(0, 120))
	_check(wiring2.contains('"repeat_count": _repeats_u1'),
		"OnInterval 滴答检查注入 repeat_count extras（对齐 on_interval 独立 ctx）: %s" % wiring2.substr(0, 200))

	# T7 ruling：随机模式首拍间隔对齐 on_interval._create_timer 的
	# _get_next_interval()（randf_range），而非 interval_seconds 字段值
	var rnd := OnInterval.new()
	rnd.interval_seconds = 1.0
	rnd.use_random_interval = true
	rnd.min_interval_seconds = 0.3
	rnd.max_interval_seconds = 0.8
	var mr: Dictionary = EventMapper.map_event(rnd, "u1")
	var rw: String = mr.get("wiring_code", "")
	_check(rw.contains("wait_time = randf_range(0.3, 0.8)"),
		"OnInterval 随机模式首拍即 randf_range（对齐 on_interval 首拍随机）: %s" % rw.substr(0, 160))
	_check(not rw.contains("wait_time = 1.0"),
		"OnInterval 随机模式不用 interval_seconds 作首拍")

	# T7 ruling：最后一拍当帧停 Timer（对齐 on_interval 递增后达 max_repeats 即停）
	# + 随机模式最后一拍不重启（对齐 not is_last_trigger 守卫）
	var fin := OnInterval.new()
	fin.interval_seconds = 0.5
	fin.max_repeats = 3
	fin.use_random_interval = true
	fin.min_interval_seconds = 0.2
	fin.max_interval_seconds = 0.4
	var mf: Dictionary = EventMapper.map_event(fin, "u1")
	var fw: String = mf.get("wiring_code", "")
	var tick := fw.get_slice("func _on_interval_u1() -> void:", 1)
	var i_entry := tick.find("_on_u1({})")
	var i_guard := tick.find("if _repeats_u1 < 3:")
	var i_restart := tick.find(".start()")
	var before_entry := tick.substr(0, i_entry).strip_edges()
	_check(i_entry >= 0 and before_entry.ends_with("_stop_interval_u1()"),
		"OnInterval 最后一拍当帧先停 Timer 再触发入口（此前下一拍才兜底停）: %s" % before_entry.substr(before_entry.length() - 60))
	_check(i_guard >= 0 and i_guard > i_entry and i_restart > i_guard,
		"OnInterval 随机重启带 not-last 守卫（最后一拍不重启）: %s" % tick.substr(0, 200))


func _test_map_receive() -> void:
	var ev := OnReceiveEvent.new()
	ev.event_name = "game_over"
	var m: Dictionary = EventMapper.map_event(ev, "u1")
	_check(m.get("mode", "") == "receive", "OnReceiveEvent mode=receive")
	_check(m.get("setup_code", "").contains('FuseDelegation.subscribe("game_over", _on_evt_u1)'),
		"OnReceiveEvent _ready 订阅: %s" % m.get("setup_code", ""))
	_check(m.get("teardown_code", "").contains("FuseDelegation.unsubscribe(_sub_u1)"),
		"OnReceiveEvent _exit_tree 退订: %s" % m.get("teardown_code", ""))


func _test_map_unsupported_event() -> void:
	var ev := OnInputKey.new()
	var m: Dictionary = EventMapper.map_event(ev, "u1")
	_check(m.get("mode", "") == "unsupported", "非白名单事件 mode=unsupported")
	_check(str(m.get("error", "")).length() > 0, "unsupported 带原因说明")


# ============================================================
# emit_system fixture
# ============================================================

## 最小 System JSON（对齐 SystemDeriver._derive_single 产物结构）
func _make_system(system_name: String, node_path: String, level: String) -> Dictionary:
	return {
		"format_version": "1.0",
		"name": system_name,
		"description": "",
		"units": [{
			"id": "u1",
			"kind": "trigger",
			"scene": "res://test_fixture.tscn",
			"node_path": node_path,
			"level": level,
		}],
		"emit": {
			"output_script": "res://fuse_generated/scripts/%s.gd" % system_name,
			"native_instructions": [],
		},
	}


func _test_emit_system_l2_golden() -> void:
	var root := Node.new()
	root.name = "FixtureScene"
	add_child(root)
	var trigger := Trigger.new()
	trigger.name = "TrigPrint"
	root.add_child(trigger)
	trigger.set_owner(root)
	var ar := ActionRunner.new()
	var p := Print.new()
	p.message = "graduated"
	ar.instructions = [p]
	trigger.action_runner = ar
	trigger.event_definition = OnReady.new()
	trigger.trigger_once = false
	trigger.cooldown_mode = BaseTrigger.CooldownMode.GLOBAL_COOLDOWN
	trigger.cooldown_time = 2.5

	var result: Dictionary = GdscriptEmitter.emit_system(
		_make_system("trig_print", "TrigPrint", "L2"), trigger, "res://test_fixture.tscn")
	var text: String = result.get("script_text", "")

	_check(text.contains("毕业导出器生成"), "头注释含毕业导出器生成标记")
	_check(text.contains("System: trig_print"), "头注释含 System 名")
	_check(text.contains("源单元: TrigPrint (L2)"), "头注释含源单元/层级")
	_check(text.contains("采用:") and text.contains("回滚:"), "头注释含采用/回滚说明")
	_check(text.contains('preload("res://addons/fuse/core/graduation/fuse_delegation.gd")'),
		"FuseDelegation preload 行")
	_check(text.contains("const _DELEGATED"), "_DELEGATED 常量存在")
	_check(text.contains("FuseDelegation.build_delegated(_DELEGATED)"), "build_delegated 接线")
	_check(text.contains('FuseDelegation.gate_allows(_gate, "u1", false, 1, 2.5, get_instance_id())'),
		"gate_allows 门控调用（trigger_once/cooldown 三值快照）")
	_check(text.contains("FuseDelegation.teardown(self)"), "_exit_tree teardown")
	_check(text.contains('print("graduated")'), "Print 原生行")
	_check(text.contains("_on_u1.call_deferred()"), "OnReady delay=0 入口 call_deferred")
	_check(text.contains("var _busy_u1 := false"), "busy 卫语句状态变量声明（终审 C2）")
	_check(text.contains("\tif _busy_u1:\n\t\treturn\n"),
		"入口首行 busy 卫语句（复刻 trigger.gd:172-174 SKIP retrigger）")
	_check(text.contains("await _body_u1(event_args)"),
		"入口经独立 body 函数执行（busy 直线序复位）")
	_check(result.get("native_count", -1) == 1, "native_count = 1")
	_check((result.get("delegated_names", []) as Array).is_empty(), "无委托指令")
	var report: Dictionary = result.get("report", {})
	_check(report.get("total_instructions", -1) == 1 and report.get("delegated_count", -1) == 0,
		"report 覆盖率分母/分子")
	root.queue_free()


## L2 Trigger 自身无 action_runner、Runner 子节点承载指令 → emit 取子 runner 的
## 指令（M3 收口：`_get_action_runner` 回退对齐 deriver/validator 归集语义，防漏发射）
func _test_emit_system_l2_runner_child_fallback() -> void:
	var root := Node.new()
	root.name = "FixtureScene"
	add_child(root)
	var trigger := Trigger.new()
	trigger.name = "TrigHosted"
	root.add_child(trigger)
	trigger.set_owner(root)
	trigger.event_definition = OnReady.new()
	var runner := Runner.new()
	runner.name = "HostedRunner"
	trigger.add_child(runner)
	var ar := ActionRunner.new()
	var p := Print.new()
	p.message = "from_child_runner"
	ar.instructions = [p]
	runner.action_runner = ar

	var result: Dictionary = GdscriptEmitter.emit_system(
		_make_system("trig_hosted", "TrigHosted", "L2"), trigger, "res://test_fixture.tscn")
	var text: String = result.get("script_text", "")
	_check(text.contains('print("from_child_runner")'),
		"L2 Runner 子节点承载指令 → emit 拿到（回退对齐 deriver/validator）")
	_check(result.get("native_count", -1) == 1, "子 runner 指令计入 native_count")
	_check(result.get("report", {}).get("total_instructions", -1) == 1,
		"子 runner 指令计入 report.total_instructions")
	root.queue_free()


func _test_emit_system_l4_multi_and_disabled() -> void:
	var root := Node.new()
	root.name = "FixtureScene"
	add_child(root)
	var multi := MultiEventTrigger.new()
	multi.name = "MultiTrig"
	root.add_child(multi)
	multi.set_owner(root)

	var b0 := EventBinding.new()
	b0.event = OnInputAction.new()
	b0.event.target_input_action = "jump"
	var ar0 := ActionRunner.new()
	ar0.instructions = [Print.new()]
	b0.action_runner = ar0

	var b1 := EventBinding.new()
	b1.event = OnInterval.new()
	b1.event.interval_seconds = 1.0
	var ar1 := ActionRunner.new()
	var t: BaseInstruction = load("res://addons/fuse/instructions/tween/tween_move_to.gd").new()
	ar1.instructions = [t]
	b1.action_runner = ar1

	var b2 := EventBinding.new()
	b2.event = OnReady.new()
	b2.enabled = false
	b2.action_runner = ActionRunner.new()
	multi.event_bindings = [b0, b1, b2]

	var result: Dictionary = GdscriptEmitter.emit_system(
		_make_system("multi_trig", "MultiTrig", "L4"), multi, "res://test_fixture.tscn")
	var text: String = result.get("script_text", "")
	_check(text.contains('FuseDelegation.gate_allows(_gate, "b0"'), "L4 binding0 gate key b0")
	_check(text.contains('FuseDelegation.gate_allows(_gate, "b1"'), "L4 binding1 gate key b1")
	_check(text.contains("func _unhandled_input(event: InputEvent) -> void:"), "输入事件合并 _unhandled_input")
	_check(text.contains('event.is_action("jump")'), "b0 输入过滤")
	_check(text.contains("_setup_interval_b1()"), "b1 OnInterval setup")
	_check(not text.contains('_on_b2'), "disabled binding 直接跳过（不生成入口）")
	var report: Dictionary = result.get("report", {})
	var skipped: Array = report.get("skipped_disabled_bindings", [])
	_check(skipped.size() == 1, "report 列出被跳过的 disabled binding: %s" % str(skipped))
	_check((result.get("delegated_names", []) as Array).has("TweenMoveTo"), "TweenMoveTo 进委托清单")
	root.queue_free()


func _test_emit_system_mixed_native_delegated() -> void:
	var root := Node.new()
	root.name = "FixtureScene"
	add_child(root)
	var trigger := Trigger.new()
	trigger.name = "TrigMixed"
	root.add_child(trigger)
	trigger.set_owner(root)
	var ar := ActionRunner.new()
	var p := Print.new()
	p.message = "before"
	var t: BaseInstruction = load("res://addons/fuse/instructions/tween/tween_move_to.gd").new()
	var p2 := Print.new()
	p2.message = "after"
	ar.instructions = [p, t, p2]
	trigger.action_runner = ar
	trigger.event_definition = OnReady.new()

	var result: Dictionary = GdscriptEmitter.emit_system(
		_make_system("trig_mixed", "TrigMixed", "L2"), trigger, "res://test_fixture.tscn")
	var text: String = result.get("script_text", "")
	_check(result.get("native_count", -1) == 2, "混合序列 native_count=2")
	_check(text.contains('print("before")') and text.contains('print("after")'), "原生行保留")
	_check(text.contains('await FuseDelegation.run(self, _delegated["u1_d0"],'),
		"混合序列委托段交错发射: %s" % text.get_slice("await Fuse", 1).substr(0, 60))
	var lines := text.split("\n")
	var i_before := -1
	var i_delegated := -1
	var i_after := -1
	for i: int in lines.size():
		if lines[i].contains('print("before")'):
			i_before = i
		elif lines[i].contains("await FuseDelegation.run"):
			i_delegated = i
		elif lines[i].contains('print("after")'):
			i_after = i
	_check(i_before >= 0 and i_before < i_delegated and i_delegated < i_after,
		"原生/委托/原生按原顺序交错")
	_check(text.contains('"u1_d0":[{'), "_DELEGATED 内嵌委托指令 JSON")
	root.queue_free()


func _test_emit_system_rejections() -> void:
	# L3 Runner 拒生成
	var root := Node.new()
	root.name = "FixtureScene"
	add_child(root)
	var runner := Runner.new()
	runner.name = "SpawnLogic"
	root.add_child(runner)
	runner.set_owner(root)
	runner.action_runner = ActionRunner.new()
	var res_runner: Dictionary = GdscriptEmitter.emit_system(
		_make_system("spawn_logic", "SpawnLogic", "L3"), runner, "res://test_fixture.tscn")
	_check(res_runner.get("script_text", "x") == "", "L3 Runner MVP 拒生成（script_text 空）")
	var errs_runner: Array = res_runner.get("report", {}).get("errors", [])
	_check(errs_runner.any(func(e): return e.get("code", "") == "E_EVENT_UNSUPPORTED"),
		"L3 拒生成归 E_EVENT_UNSUPPORTED: %s" % str(errs_runner))

	# 非白名单事件拒生成
	var trigger := Trigger.new()
	trigger.name = "TrigKey"
	root.add_child(trigger)
	trigger.set_owner(root)
	var ar := ActionRunner.new()
	ar.instructions = [Print.new()]
	trigger.action_runner = ar
	trigger.event_definition = OnInputKey.new()
	var res_ev: Dictionary = GdscriptEmitter.emit_system(
		_make_system("trig_key", "TrigKey", "L2"), trigger, "res://test_fixture.tscn")
	_check(res_ev.get("script_text", "x") == "", "非白名单事件拒生成（script_text 空）")
	var errs_ev: Array = res_ev.get("report", {}).get("errors", [])
	_check(errs_ev.any(func(e): return e.get("code", "") == "E_EVENT_UNSUPPORTED"),
		"事件拒生成归 E_EVENT_UNSUPPORTED: %s" % str(errs_ev))

	# RESTART retrigger_policy：T7 起降级为 SKIP 并备案（金样例 game_flow b0 实需），
	# 不再拒生成
	var multi := MultiEventTrigger.new()
	multi.name = "MultiRestart"
	root.add_child(multi)
	multi.set_owner(root)
	var b := EventBinding.new()
	b.event = OnReady.new()
	b.retrigger_policy = EventBinding.RetriggerPolicy.RESTART
	b.action_runner = ActionRunner.new()
	multi.event_bindings = [b]
	var res_restart: Dictionary = GdscriptEmitter.emit_system(
		_make_system("multi_restart", "MultiRestart", "L4"), multi, "res://test_fixture.tscn")
	_check(res_restart.get("script_text", "") != "", "RESTART 降级 SKIP 后仍生成")
	var report_r: Dictionary = res_restart.get("report", {})
	var downgraded: Array = report_r.get("downgraded_restart_bindings", [])
	_check(downgraded == ["b0"], "RESTART 降级入 report: %s" % str(downgraded))
	_check(str(res_restart.get("script_text", "")).contains("降级备案: b0"),
		"RESTART 降级在生成脚本头注释显著备案")
	var restart_text := str(res_restart.get("script_text", ""))
	_check(restart_text.contains("请人工确认重触发时上一轮执行已完成"),
		"降级备案为中性确认文案（人工确认义务）")
	_check(not restart_text.contains("不可达"),
		"降级备案不含'不可达'式断言（M3 收口中性化）")
	root.queue_free()


## 带条件 binding 的入口：两阶段门控（gate_check → 条件（注入 event_args）→
## gate_commit → 执行）——对齐 Fuse"条件通过才消耗 trigger_once"（trigger.gd:216）
func _test_emit_system_conditions_gate_phases() -> void:
	var root := Node.new()
	root.name = "FixtureScene"
	add_child(root)
	var trigger := Trigger.new()
	trigger.name = "TrigCond"
	root.add_child(trigger)
	trigger.set_owner(root)
	var ar := ActionRunner.new()
	ar.instructions = [Print.new()]
	trigger.action_runner = ar
	var receive := OnReceiveEvent.new()
	receive.event_name = "score_changed"
	trigger.event_definition = receive
	trigger.trigger_once = true
	var cond := CheckVariable.new()
	cond.variable_name = "event_score"
	cond.expected_value = 7
	trigger.conditions = [cond]
	trigger.use_conditions = true

	var result: Dictionary = GdscriptEmitter.emit_system(
		_make_system("trig_cond", "TrigCond", "L2"), trigger, "res://test_fixture.tscn")
	var text: String = result.get("script_text", "")
	var lines := text.split("\n")
	var i_check := -1
	var i_cond := -1
	var i_commit := -1
	for i: int in lines.size():
		if lines[i].contains("FuseDelegation.gate_check(_gate"):
			i_check = i
		elif lines[i].contains("FuseDelegation.check_condition(self, _cond, event_args)"):
			i_cond = i
		elif lines[i].contains("FuseDelegation.gate_commit(_gate"):
			i_commit = i
	_check(i_check >= 0, "条件 binding 生成 gate_check（纯检查）")
	_check(i_cond >= 0, "条件检查调用注入 event_args: %s" % str(i_cond))
	_check(i_commit >= 0, "条件通过后 gate_commit 消耗")
	_check(i_check >= 0 and i_cond >= 0 and i_commit >= 0 and i_check < i_cond and i_cond < i_commit,
		"两阶段顺序：check → 条件 → commit")
	_check(not text.contains("gate_allows"), "条件 binding 不再用合一 gate_allows")
	_check(text.contains("const _CONDITIONS_U1"), "条件常量生成")
	root.queue_free()


## 终审 C1：binding 含 LOCAL 用途（SetVariable LOCAL 目标 + SendEvent $引用）→
## 整条 binding 全委托单段（一个 ctx 贯穿），无任何原生行
func _test_emit_system_local_whole_delegated() -> void:
	var root := Node.new()
	root.name = "FixtureLocal"
	add_child(root)
	var trigger := Trigger.new()
	trigger.name = "TrigLocal"
	root.add_child(trigger)
	trigger.set_owner(root)
	var ar := ActionRunner.new()
	var set_local := SetVariable.new()
	set_local.target_variable = "c_x"
	set_local.target_variable_scope = BaseVariable.VariableScope.LOCAL
	set_local.new_value = 42
	var send_ref := SendEvent.new()
	send_ref.event_name = "score_changed"
	send_ref.event_args = {"score": "$c_x"}
	var nativeable := Print.new()
	nativeable.message = "still_delegated"
	ar.instructions = [set_local, send_ref, nativeable]
	trigger.action_runner = ar
	var receive := OnReceiveEvent.new()
	receive.event_name = "enemy_die"
	trigger.event_definition = receive

	var result: Dictionary = GdscriptEmitter.emit_system(
		_make_system("trig_local", "TrigLocal", "L2"), trigger, "res://test_fixture.tscn")
	var text: String = result.get("script_text", "")
	var report: Dictionary = result.get("report", {})
	_check((report.get("local_delegated_bindings", []) as Array) == ["u1"],
		"LOCAL 用途 binding 入 report.local_delegated_bindings: %s"
		% str(report.get("local_delegated_bindings")))
	_check(text.count("await FuseDelegation.run(") == 1,
		"整条 binding 单段 run（一个 ctx 贯穿，实测 %d 段）" % text.count("await FuseDelegation.run("))
	_check(not text.contains('print("still_delegated")'),
		"LOCAL binding 内白名单可原生指令也全委托")
	var delegated_json := _extract_delegated_json(text)
	_check(delegated_json.size() == 1 and (delegated_json["u1_d0"] as Array).size() == 3,
		"单段委托数据块含全部 3 条顶层指令")
	_check(report.get("native_count", -1) == 0 and report.get("delegated_count", -1) == 3,
		"report 覆盖率：native=0，delegated=3")
	_check(text.contains("LOCAL 连续性: u1"), "头注释 LOCAL 连续性备案行")
	root.queue_free()


## 终审 C1(a/d)：无 LOCAL 用途 binding——连续委托指令合并为单段（原生行切段，
## 背靠背同帧执行缓解逐指令摊帧）
func _test_emit_system_segments_merged() -> void:
	var root := Node.new()
	root.name = "FixtureMerge"
	add_child(root)
	var trigger := Trigger.new()
	trigger.name = "TrigMerge"
	root.add_child(trigger)
	trigger.set_owner(root)
	var ar := ActionRunner.new()
	var tween: BaseInstruction = load("res://addons/fuse/instructions/tween/tween_move_to.gd").new()
	var tween2: BaseInstruction = load("res://addons/fuse/instructions/tween/tween_move_to.gd").new()
	var tween3: BaseInstruction = load("res://addons/fuse/instructions/tween/tween_move_to.gd").new()
	var wait_mid := Wait.new()
	wait_mid.wait_time = 0.1
	var p_start := Print.new()
	p_start.message = "start"
	ar.instructions = [p_start, tween, tween2, wait_mid, tween3]
	trigger.action_runner = ar
	trigger.event_definition = OnReady.new()

	var result: Dictionary = GdscriptEmitter.emit_system(
		_make_system("trig_merge", "TrigMerge", "L2"), trigger, "res://test_fixture.tscn")
	var text: String = result.get("script_text", "")
	var delegated_json := _extract_delegated_json(text)
	_check(delegated_json.size() == 2,
		"委托-委托连续合并单段、原生 Wait 切段后余下单段（实测 %d 段）" % delegated_json.size())
	_check((delegated_json["u1_d0"] as Array).size() == 2,
		"首段合并 2 条连续委托指令（tween+tween2 同 ctx 同帧背靠背）")
	_check((delegated_json["u1_d1"] as Array).size() == 1, "末段 1 条")
	var report: Dictionary = result.get("report", {})
	_check(report.get("native_count", -1) == 2 and report.get("delegated_count", -1) == 3,
		"混合计数：native=2（print/wait），delegated=3（tween×3）")
	root.queue_free()


## 终审 I3：report 风险原料（输入事件 / CheckAnyInput stop_condition / 条件+冷却偏差）
func _test_report_risk_fields() -> void:
	var root := Node.new()
	root.name = "FixtureRisk"
	add_child(root)
	var trigger := Trigger.new()
	trigger.name = "TrigRisk"
	root.add_child(trigger)
	trigger.set_owner(root)
	var ar := ActionRunner.new()
	ar.instructions = [Print.new()]
	trigger.action_runner = ar
	var interval := OnInterval.new()
	interval.interval_seconds = 2.0
	var stop := CheckAnyInput.new()
	interval.stop_condition = stop
	trigger.event_definition = interval
	trigger.cooldown_mode = BaseTrigger.CooldownMode.GLOBAL_COOLDOWN
	trigger.cooldown_time = 1.5
	var cond := CheckVariable.new()
	cond.variable_name = "event_score"
	cond.expected_value = 7
	trigger.conditions = [cond]
	trigger.use_conditions = true

	var result: Dictionary = GdscriptEmitter.emit_system(
		_make_system("trig_risk", "TrigRisk", "L2"), trigger, "res://test_fixture.tscn")
	var report: Dictionary = result.get("report", {})
	_check((report.get("check_any_input_bindings", []) as Array) == ["u1"],
		"CheckAnyInput stop_condition 入 report（即时探测语义风险行原料）")
	_check((report.get("cond_cooldown_deviation_bindings", []) as Array) == ["u1"],
		"条件+冷却并存 binding 入 report（条件失败不进冷却偏差原料）")
	_check(bool(report.get("has_input_events", true)) == false,
		"OnInterval 非 input 事件不置 has_input_events")

	var input_trig := Trigger.new()
	input_trig.name = "TrigInput"
	root.add_child(input_trig)
	input_trig.set_owner(root)
	var ar2 := ActionRunner.new()
	ar2.instructions = [Print.new()]
	input_trig.action_runner = ar2
	var input_ev := OnInputAction.new()
	input_ev.target_input_action = "jump"
	input_trig.event_definition = input_ev
	var result2: Dictionary = GdscriptEmitter.emit_system(
		_make_system("trig_input", "TrigInput", "L2"), input_trig, "res://test_fixture.tscn")
	_check(bool(result2.get("report", {}).get("has_input_events", false)),
		"OnInputAction 事件置 has_input_events（_unhandled_input 时序风险行原料）")
	root.queue_free()


## 产物文本 → _DELEGATED 常量解析（金样例守恒测试同款提取）
func _extract_delegated_json(text: String) -> Dictionary:
	for line: String in text.split("\n"):
		if line.begins_with("const _DELEGATED := "):
			var parsed: Variant = JSON.parse_string(line.trim_prefix("const _DELEGATED := "))
			if parsed is Dictionary:
				return parsed
	return {}


## 冒烟补充：MODULO 原生 + 条件两阶段门控产物 load() 零解析错
func _test_parse_smoke_modulo_and_conditions() -> void:
	var root := Node.new()
	root.name = "SmokeScene2"
	add_child(root)

	# MODULO + DIVIDE 原生（fmod/除零守卫分支的可编译性）
	var t1 := Trigger.new()
	t1.name = "SmokeModulo"
	root.add_child(t1)
	t1.set_owner(root)
	var ar1 := ActionRunner.new()
	var mod := MathOperation.new()
	mod.operation_type = MathOperation.OperationType.MODULO
	mod.operand_a_source = MathOperation.OperandASource.VALUE
	mod.operand_a_value = 7.0
	mod.operand_b_source = MathOperation.OperandBSource.VALUE
	mod.operand_b_value = 3.0
	mod.save_to_variable = "rem"
	var div := MathOperation.new()
	div.operation_type = MathOperation.OperationType.DIVIDE
	div.operand_a_source = MathOperation.OperandASource.VALUE
	div.operand_a_value = 10.0
	div.operand_b_source = MathOperation.OperandBSource.VALUE
	div.operand_b_value = 4.0
	div.save_to_variable = "ratio"
	ar1.instructions = [mod, div]
	t1.action_runner = ar1
	t1.event_definition = OnReady.new()
	_smoke_load(_make_system("smoke_modulo", "SmokeModulo", "L2"), t1)

	# 带条件 binding（两阶段门控 + event_args 条件）+ OnInterval stop_condition（extras 注入）
	var t2 := Trigger.new()
	t2.name = "SmokeCondInterval"
	root.add_child(t2)
	t2.set_owner(root)
	var ar2 := ActionRunner.new()
	ar2.instructions = [Print.new()]
	t2.action_runner = ar2
	var receive := OnReceiveEvent.new()
	receive.event_name = "smoke_evt"
	t2.event_definition = receive
	t2.trigger_once = true
	var cond := CheckVariable.new()
	cond.variable_name = "event_score"
	cond.expected_value = 7
	t2.conditions = [cond]
	t2.use_conditions = true
	_smoke_load(_make_system("smoke_cond", "SmokeCondInterval", "L2"), t2)

	var t3 := Trigger.new()
	t3.name = "SmokeStopCond"
	root.add_child(t3)
	t3.set_owner(root)
	var ar3 := ActionRunner.new()
	ar3.instructions = [Print.new()]
	t3.action_runner = ar3
	var interval := OnInterval.new()
	interval.interval_seconds = 1.0
	interval.max_repeats = 5
	var stop := CheckVariable.new()
	stop.variable_name = "repeat_count"
	stop.comparison_operator = CheckVariable.ComparisonOperator.GREATER_EQUAL
	stop.expected_value = 3
	interval.stop_condition = stop
	t3.event_definition = interval
	_smoke_load(_make_system("smoke_stop_cond", "SmokeStopCond", "L2"), t3)

	root.queue_free()


## 冒烟补充（终审 C1/C2）：LOCAL 整条委托 + busy 卫语句 + 独立 body 函数产物
## load() 零解析错（行为级验证见 test_codegen_behavior.gd）
func _test_parse_smoke_local_busy() -> void:
	var root := Node.new()
	root.name = "SmokeScene3"
	add_child(root)
	var trigger := Trigger.new()
	trigger.name = "SmokeLocalBusy"
	root.add_child(trigger)
	trigger.set_owner(root)
	var ar := ActionRunner.new()
	var set_local := SetVariable.new()
	set_local.target_variable = "c_x"
	set_local.target_variable_scope = BaseVariable.VariableScope.LOCAL
	set_local.new_value = 42
	var send_ref := SendEvent.new()
	send_ref.event_name = "smoke_evt"
	send_ref.event_args = {"v": "$c_x"}
	var wait := Wait.new()
	wait.wait_time = 0.1
	ar.instructions = [set_local, wait, send_ref]
	trigger.action_runner = ar
	var receive := OnReceiveEvent.new()
	receive.event_name = "smoke_evt"
	trigger.event_definition = receive
	_smoke_load(_make_system("smoke_local_busy", "SmokeLocalBusy", "L2"), trigger)
	root.queue_free()


# ============================================================
# 解析冒烟：产物写 user:// 后 load() 验证零解析错（T7 前移）
# ============================================================

func _test_parse_smoke_all_event_kinds() -> void:
	var root := Node.new()
	root.name = "SmokeScene"
	add_child(root)

	# 1) OnReady + 混合指令（含委托）
	var t1 := Trigger.new()
	t1.name = "SmokeReady"
	root.add_child(t1)
	t1.set_owner(root)
	var ar1 := ActionRunner.new()
	var p := Print.new()
	p.message = "smoke"
	var tween: BaseInstruction = load("res://addons/fuse/instructions/tween/tween_move_to.gd").new()
	var setv := SetVariable.new()
	setv.target_variable = "count"
	setv.new_value = 1
	ar1.instructions = [p, tween, setv]
	t1.action_runner = ar1
	t1.event_definition = OnReady.new()
	t1.event_definition.delay_seconds = 0.25
	_smoke_load(_make_system("smoke_ready", "SmokeReady", "L2"), t1)

	# 2) OnInputAction + Wait + SendEvent 原生
	var t2 := Trigger.new()
	t2.name = "SmokeInput"
	root.add_child(t2)
	t2.set_owner(root)
	var ar2 := ActionRunner.new()
	var w := Wait.new()
	w.wait_time = 0.1
	var se := SendEvent.new()
	se.event_name = "smoke_evt"
	ar2.instructions = [w, se]
	t2.action_runner = ar2
	t2.event_definition = OnInputAction.new()
	t2.event_definition.target_input_action = "jump"
	_smoke_load(_make_system("smoke_input", "SmokeInput", "L2"), t2)

	# 3) OnInterval（max_repeats + 随机间隔）
	var t3 := Trigger.new()
	t3.name = "SmokeInterval"
	root.add_child(t3)
	t3.set_owner(root)
	var ar3 := ActionRunner.new()
	ar3.instructions = [Print.new()]
	t3.action_runner = ar3
	var interval := OnInterval.new()
	interval.interval_seconds = 0.5
	interval.max_repeats = 2
	interval.use_random_interval = true
	interval.min_interval_seconds = 0.1
	interval.max_interval_seconds = 0.3
	t3.event_definition = interval
	_smoke_load(_make_system("smoke_interval", "SmokeInterval", "L2"), t3)

	# 4) OnReceiveEvent + MathOperation 原生
	var t4 := Trigger.new()
	t4.name = "SmokeReceive"
	root.add_child(t4)
	t4.set_owner(root)
	var ar4 := ActionRunner.new()
	var m := MathOperation.new()
	m.operation_type = MathOperation.OperationType.MULTIPLY
	m.operand_a_source = MathOperation.OperandASource.VALUE
	m.operand_a_value = 3.0
	m.operand_b_source = MathOperation.OperandBSource.VALUE
	m.operand_b_value = 7.0
	m.save_to_variable = "result"
	ar4.instructions = [m]
	t4.action_runner = ar4
	var receive := OnReceiveEvent.new()
	receive.event_name = "smoke_evt"
	t4.event_definition = receive
	_smoke_load(_make_system("smoke_receive", "SmokeReceive", "L2"), t4)

	# 5) L4 多事件混合（input + interval + receive）
	var multi := MultiEventTrigger.new()
	multi.name = "SmokeMulti"
	root.add_child(multi)
	multi.set_owner(root)
	var bindings: Array[EventBinding] = []
	for i: int in 3:
		var b := EventBinding.new()
		var b_ar := ActionRunner.new()
		b_ar.instructions = [Print.new()]
		b.action_runner = b_ar
		match i:
			0:
				var ia := OnInputAction.new()
				ia.target_input_action = "jump"
				b.event = ia
			1:
				var iv := OnInterval.new()
				iv.interval_seconds = 1.0
				b.event = iv
			2:
				var rc := OnReceiveEvent.new()
				rc.event_name = "smoke_evt"
				b.event = rc
		bindings.append(b)
	multi.event_bindings = bindings
	_smoke_load(_make_system("smoke_multi", "SmokeMulti", "L4"), multi)

	root.queue_free()


func _smoke_load(system: Dictionary, unit_node: Node) -> void:
	_smoke_seq += 1
	var path := "user://graduation_smoke_%d.gd" % _smoke_seq
	var result: Dictionary = GdscriptEmitter.emit_system(system, unit_node, "res://smoke.tscn")
	var text: String = result.get("script_text", "")
	if text.is_empty():
		_check(false, "解析冒烟 %s：script_text 为空（拒生成）" % system.get("name", "?"))
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var script: GDScript = load(path)
	var ok: bool = script != null and script.can_instantiate()
	_check(ok, "解析冒烟 %s：load() 零解析错" % system.get("name", "?"))
	if not ok:
		push_error("---- 冒烟产物 ----\n" + text)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
