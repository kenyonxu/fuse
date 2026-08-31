# addons/fuse/tests/graduation/test_codegen_behavior.gd
extends Node

## 生成脚本行为级测试（终审 C1/C2 硬要求）
##
## 超越"产物文本断言"：真实发射 → 写盘 → load → 实例化挂树 → 经事件总线驱动 →
## 断言运行时行为：
##   1. C1：L2 binding（SetVariable local x → SendEvent $x）收到的总线事件 args
##      携带正确值——LOCAL 变量跨指令经整条委托单段的 ctx 贯穿（修复前 score=null）。
##   2. C2：运行中重触发被 busy 卫语句忽略（修复前并行重入）；执行完成后放行。
##   3. C1(d)：连续委托合并段背靠背同帧执行（帧数摊销验证）。

const FuseDelegation := preload("res://addons/fuse/core/graduation/fuse_delegation.gd")

var _fail := 0
var _seq := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("✓ " + msg)
	else:
		_fail += 1
		push_error("✗ " + msg)


func _ready() -> void:
	print("=== test_codegen_behavior ===")
	await _test_local_variable_continuity()
	await _test_busy_skip_retrigger()
	await _test_merged_segment_frame_amortization()
	print("=== test_codegen_behavior 完成（失败 %d）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)


# ============================================================
# C1：LOCAL 变量跨指令连续性（行为级）
# ============================================================

## L2 binding：OnReceiveEvent("grad_local_in") → SetVariable local c_x=42 →
## SendEvent("grad_local_out", {"v": "$c_x"})。金样例 game_flow b2 链的最小复刻
## （修复前：每指令一段 ctx，$c_score 恒 null）。
func _test_local_variable_continuity() -> void:
	print("--- C1 LOCAL 连续性 ---")
	var trigger := _make_local_trigger("grad_local_in", "grad_local_out")
	var holder := _instantiate_generated(trigger, "behavior_local")

	var received: Array = []
	var sub: Variant = FuseDelegation.subscribe("grad_local_out",
		func(args: Dictionary): received.append(args))
	FuseDelegation.send_event("grad_local_in", {"score": 1})
	await _wait_frames(10)
	FuseDelegation.unsubscribe(sub)
	_check(received.size() == 1, "输出事件恰收到 1 次（实测 %d）" % received.size())
	if received.is_empty():
		holder.queue_free()
		return
	_check(int(received[0].get("v", -1)) == 42,
		"LOCAL 变量 c_x=42 经 $引用随事件携带（实测 %s，修复前为 null）"
		% str(received[0].get("v", null)))
	holder.queue_free()


func _make_local_trigger(in_evt: String, out_evt: String) -> Trigger:
	# 不挂树：源 Trigger 挂树会在 _ready 订阅同名总线事件，与生成脚本并行
	# 双发干扰行为断言（emit_system 只消费其资源对象，无需在树）
	var trigger := Trigger.new()
	trigger.name = "BehaviorLocalTrig"
	var ar := ActionRunner.new()
	var set_local := SetVariable.new()
	set_local.target_variable = "c_x"
	set_local.target_variable_scope = BaseVariable.VariableScope.LOCAL
	set_local.new_value = 42
	var send_ref := SendEvent.new()
	send_ref.event_name = out_evt
	send_ref.event_args = {"v": "$c_x"}
	ar.instructions = [set_local, send_ref]
	trigger.action_runner = ar
	var receive := OnReceiveEvent.new()
	receive.event_name = in_evt
	trigger.event_definition = receive
	return trigger


# ============================================================
# C2：busy 卫语句复刻 SKIP retrigger（行为级）
# ============================================================

## binding：OnReceiveEvent → [SendEvent($x 触发 LOCAL 整条委托), Wait 0.25,
## SendEvent(probe)]。第一轮执行中（0.25s Wait 未完）再触发 → busy 忽略；
## 完成后再触发 → 放行。修复前：并发调用各自启动协程，probe 翻倍。
func _test_busy_skip_retrigger() -> void:
	print("--- C2 busy 卫语句 ---")
	# 不挂树（同上：防源 Trigger 与生成脚本双发）
	var trigger := Trigger.new()
	trigger.name = "BehaviorBusyTrig"
	var ar := ActionRunner.new()
	var marker := SendEvent.new()
	marker.event_name = "grad_busy_probe"
	marker.event_args = {"m": "$c_m"}
	var set_local := SetVariable.new()
	set_local.target_variable = "c_m"
	set_local.target_variable_scope = BaseVariable.VariableScope.LOCAL
	set_local.new_value = 7
	var wait := Wait.new()
	wait.wait_time = 0.25
	var tail := SendEvent.new()
	tail.event_name = "grad_busy_probe"
	tail.event_args = {"m": "tail"}
	ar.instructions = [set_local, marker, wait, tail]
	trigger.action_runner = ar
	var receive := OnReceiveEvent.new()
	receive.event_name = "grad_busy_in"
	trigger.event_definition = receive
	var holder := _instantiate_generated(trigger, "behavior_busy")

	var received: Array = []
	var sub: Variant = FuseDelegation.subscribe("grad_busy_probe",
		func(args: Dictionary): received.append(args))

	# 第一轮：启动后立刻在运行中重触发两次（Wait 0.25s 未完 → busy 忽略）
	holder._on_u1({"n": 1})
	_check(bool(holder.get("_busy_u1")) == true, "运行中 _busy_u1 已置位")
	holder._on_u1({"n": 2})
	holder._on_u1({"n": 3})
	await _wait_seconds(0.8)
	_check(received.size() == 2,
		"运行中重触发 2 次均被 busy 忽略（probe 恰 2 次：marker+tail，实测 %d）" % received.size())
	if received.size() >= 2:
		_check(int(received[0].get("m", -1)) == 7 and str(received[1].get("m")) == "tail",
			"probe 序列 = [marker m=7, tail]（顺序与 args 保真）: %s" % str(received))
	_check(bool(holder.get("_busy_u1")) == false, "执行完成后 busy 复位")

	# 第二轮：完成后重触发 → 放行（再收 2 次）
	holder._on_u1({"n": 4})
	await _wait_seconds(0.8)
	_check(received.size() == 4, "完成后重触发放行（probe 共 4 次，实测 %d）" % received.size())
	FuseDelegation.unsubscribe(sub)
	holder.queue_free()


# ============================================================
# C1(d)：连续委托合并段的帧行为（摊帧验证）
# ============================================================

## 5 条连续委托 Print（无 LOCAL）合并为一段 vs 逐指令一段（人为切段）：
## 实测两者均在 1 帧 deferred flush 内背靠背完成（Godot MessageQueue flush 内
## call_deferred 级联、await 信号在 flush 中同步恢复）——终审"每指令一帧"的
## 摊帧担忧对同步委托链**实证不成立**；合并段的实质收益是 ctx 连续性（C1）
## 与单 runner 实例，帧数不劣化。此断言钉住"合并段背靠背 ≤2 帧"下界事实，
## 防回归为逐段跨帧。
func _test_merged_segment_frame_amortization() -> void:
	print("--- C1(d) 合并段帧行为 ---")
	var instructions: Array = []
	for i: int in 5:
		var p := Print.new()
		p.message = "merged_%d" % i
		instructions.append(p)
	var holder := Node.new()
	holder.name = "AmortHolder"
	add_child(holder)

	# 合并段（等价生成形态：单段 5 指令）
	var f0 := Engine.get_process_frames()
	await FuseDelegation.run(holder, instructions, 0)
	var merged_frames := Engine.get_process_frames() - f0
	_check(merged_frames <= 2,
		"合并段 5 指令背靠背 ≤2 帧（实测 %d 帧）" % merged_frames)

	# 对照：逐指令一段（修复前的逐段形态）——同步链同帧级联，帧数不劣化
	var singles: Array = []
	for single in instructions:
		singles.append([single])
	var f1 := Engine.get_process_frames()
	for seg: Array in singles:
		await FuseDelegation.run(holder, seg, 0)
	var split_frames := Engine.get_process_frames() - f1
	_check(split_frames <= 2,
		"对照逐段形态同步链亦同帧级联（实测 %d 帧）——摊帧担忧实证不成立，合并收益在 ctx 连续性" % split_frames)
	holder.queue_free()


# ============================================================
# 生成 → 写盘 → load → 实例化挂树
# ============================================================

func _instantiate_generated(trigger: Trigger, system_name: String) -> Node:
	_seq += 1
	var system := {
		"format_version": "1.0",
		"name": system_name,
		"description": "",
		"units": [{
			"id": "u1", "kind": "trigger", "scene": "res://test_behavior.tscn",
			"node_path": trigger.name, "level": "L2",
		}],
		"emit": {"output_script": "user://%s_%d.gd" % [system_name, _seq],
			"native_instructions": []},
	}
	var result: Dictionary = GdscriptEmitter.emit_system(
		system, trigger, "res://test_behavior.tscn")
	var text: String = result.get("script_text", "")
	_check(not text.is_empty(), "%s 生成成功" % system_name)
	var path := "user://%s_%d.gd" % [system_name, _seq]
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var script: GDScript = load(path)
	_check(script != null and script.can_instantiate(), "%s 产物 load() 零解析错" % system_name)
	var holder: Node = script.new()
	holder.name = "%sHolder" % system_name
	add_child(holder)  # _ready 订阅总线（OnReceiveEvent 接线）
	trigger.free()
	return holder


func _wait_frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _wait_seconds(t: float) -> void:
	await get_tree().create_timer(t).timeout
