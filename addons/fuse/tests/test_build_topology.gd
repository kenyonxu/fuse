extends Node

## InstructionAnalyzer.build_topology 跨 Trigger 关联单测（E3）
##
## build_topology(scene_root) -> {scene_name, triggers, cross_references, variable_analysis}
## 覆盖：
##   - 写-读关联（variable_write_to_read）
##   - 竞态预警（variable_write_to_write）+ mutex 抑制
##   - 孤写/孤读标注（variable_analysis.anomaly）
##   - 单 Trigger 自身写读 → cross_references 关联类为空，variable_analysis normal
const InstructionAnalyzer = preload("res://addons/fuse/editor/analysis/instruction_analyzer.gd")

var _fail := 0
var _scene_root: Node = null


func _ready() -> void:
	_test_cross_ref_variable_write_to_read()
	_test_cross_ref_variable_race_condition()
	_test_cross_ref_variable_race_suppressed_by_mutex()
	_test_variable_write_only_anomaly()
	_test_variable_read_only_anomaly()
	_test_no_cross_ref_when_single_trigger_write_read()
	_test_cross_ref_when_two_triggers_write_read_same_var()
	_teardown_scene()
	print("\n=== 结果: %d 处失败 ===" % _fail)
	if _fail > 0:
		push_error("build_topology 测试失败: %d 处" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: ", msg)
	else:
		_fail += 1
		push_error("  FAIL: ", msg)


## Mock 指令：继承 BaseInstruction 以满足 ActionRunner.instructions 类型约束。
## 暴露变量属性以触发 _extract_variables（target_=write, from_=read, value_=read_write）。
class MockInst extends BaseInstruction:
	@export var target_variable: String = ""
	@export var target_variable_scope: int = 0
	@export var from_variable: String = ""
	@export var from_variable_scope: int = 0
	@export var value_variable: String = ""        # read_write mode
	@export var value_variable_scope: int = 0

	func _setup_metadata() -> void:
		pass

	func _update_resource_name() -> void:
		pass

	func execute(_context) -> void:
		pass


## 含 LockVariable 关键词的 Mock 指令（用于 mutex 抑制测试）
class MockLockInst extends BaseInstruction:
	@export var target_variable: String = ""
	@export var target_variable_scope: int = 0

	func _setup_metadata() -> void:
		pass

	func _update_resource_name() -> void:
		# resource_name 含 "LockVariable" 关键词 → _has_mutex_protection 命中
		resource_name = "LockVariable"

	func execute(_context) -> void:
		pass


## 构造写者指令（target_global_variable = vname, scope=2 global）
func _make_writer_inst(vname: String) -> MockInst:
	var inst := MockInst.new()
	inst.target_variable = vname
	inst.target_variable_scope = 2  # global
	inst.resource_name = "SetVariable"
	return inst


## 构造读者指令（from_global_variable = vname, scope=2 global）
func _make_reader_inst(vname: String) -> MockInst:
	var inst := MockInst.new()
	inst.from_variable = vname
	inst.from_variable_scope = 2  # global
	inst.resource_name = "ReadVariable"
	return inst


## 构造含 LockVariable 的写者指令（mutex 标记）
func _make_lock_writer_inst(vname: String) -> MockLockInst:
	var inst := MockLockInst.new()
	inst.target_variable = vname
	inst.target_variable_scope = 2  # global
	# resource_name 在 _update_resource_name() 中被设为 "LockVariable"
	return inst


## 构造 Trigger 节点 + ActionRunner + 指令列表
func _make_trigger(tname: String, insts: Array) -> Trigger:
	var trigger := Trigger.new()
	trigger.name = tname
	var ar := ActionRunner.new()
	for inst in insts:
		ar.instructions.append(inst)
	trigger.action_runner = ar
	return trigger


## 构造临时场景树：根 + 多个 Trigger 子节点
## 注：find_children 默认 owned=true（仅 owner==self 的子节点），
## 测试手动构造的场景需显式 set_owner(root) 才能被扫描到。
func _setup_scene(triggers: Array) -> Node:
	var root := Node.new()
	root.name = "TestScene"
	add_child(root)
	for t in triggers:
		root.add_child(t)
		t.set_owner(root)  # 关键：让 find_children(owned=true) 命中
	_scene_root = root
	return root


func _teardown_scene() -> void:
	if _scene_root != null and is_instance_valid(_scene_root):
		_scene_root.queue_free()
	_scene_root = null


# ============================================================
# E3 测试用例
# ============================================================

## T1 写 global_hp, T2 读 global_hp → cross_ref 含 variable_write_to_read
func _test_cross_ref_variable_write_to_read() -> void:
	print("\n--- 跨 Trigger 写-读关联：variable_write_to_read ---")
	var t1 := _make_trigger("T1", [_make_writer_inst("global_hp")])
	var t2 := _make_trigger("T2", [_make_reader_inst("global_hp")])
	_setup_scene([t1, t2])

	var topology := InstructionAnalyzer.build_topology(_scene_root)
	var cross_refs: Array = topology.get("cross_references", [])
	var write_to_read := cross_refs.filter(func(r): return r.get("type", "") == "variable_write_to_read")

	_check(not write_to_read.is_empty(), "含 variable_write_to_read 条目（实际 %d）" % write_to_read.size())
	if not write_to_read.is_empty():
		var r = write_to_read[0]
		_check(r.get("from", "") == "T1", "from=T1（实际 %s）" % r.get("from", ""))
		_check(r.get("to", "") == "T2", "to=T2（实际 %s）" % r.get("to", ""))
		_check(r.get("detail", "") == "global_hp", "detail=global_hp")
		_check(r.get("from_mode", "") == "write", "from_mode=write")
		_check(r.get("to_mode", "") == "read", "to_mode=read")


## T1 写 global_score, T2 写 global_score → cross_ref 含 variable_write_to_write（warning=true）
func _test_cross_ref_variable_race_condition() -> void:
	print("\n--- 竞态预警：variable_write_to_write（warning=true）---")
	var t1 := _make_trigger("T1", [_make_writer_inst("global_score")])
	var t2 := _make_trigger("T2", [_make_writer_inst("global_score")])
	_setup_scene([t1, t2])

	var topology := InstructionAnalyzer.build_topology(_scene_root)
	var cross_refs: Array = topology.get("cross_references", [])
	var races := cross_refs.filter(func(r): return r.get("type", "") == "variable_write_to_write")

	_check(not races.is_empty(), "含 variable_write_to_write 条目（实际 %d）" % races.size())
	if not races.is_empty():
		var r = races[0]
		_check(r.get("detail", "") == "global_score", "detail=global_score")
		_check(r.get("warning", false) == true, "warning=true")


## T1 用 LockVariable 写, T2 写 → 竞态被 mutex 抑制（无 variable_write_to_write）
func _test_cross_ref_variable_race_suppressed_by_mutex() -> void:
	print("\n--- mutex 抑制竞态：LockVariable 关键词 → 无预警 ---")
	# T1 用 MockLockInst（resource_name = "LockVariable"）
	var t1 := _make_trigger("T1", [_make_lock_writer_inst("global_mutex_var")])
	var t2 := _make_trigger("T2", [_make_writer_inst("global_mutex_var")])
	_setup_scene([t1, t2])

	var topology := InstructionAnalyzer.build_topology(_scene_root)
	var cross_refs: Array = topology.get("cross_references", [])
	var races := cross_refs.filter(func(r): return r.get("type", "") == "variable_write_to_write")

	_check(races.is_empty(), "mutex 抑制 → 0 variable_write_to_write（实际 %d）" % races.size())


## global_orphan 被 T1 写入，无 Trigger 读取 → variable_analysis.anomaly=write_only
func _test_variable_write_only_anomaly() -> void:
	print("\n--- 孤写：variable_analysis write_only ---")
	var t1 := _make_trigger("T1", [_make_writer_inst("global_orphan")])
	_setup_scene([t1])

	var topology := InstructionAnalyzer.build_topology(_scene_root)
	var analysis: Array = topology.get("variable_analysis", [])
	var orphan := analysis.filter(func(a): return a.get("name", "") == "global_orphan")

	_check(not orphan.is_empty(), "global_orphan 在 variable_analysis 中")
	if not orphan.is_empty():
		_check(orphan[0].get("anomaly", "") == "write_only", "anomaly=write_only（实际 %s）" % orphan[0].get("anomaly", ""))


## global_uninit 被 T1 读取，无 Trigger 写入 → variable_analysis.anomaly=read_only
func _test_variable_read_only_anomaly() -> void:
	print("\n--- 孤读：variable_analysis read_only ---")
	var t1 := _make_trigger("T1", [_make_reader_inst("global_uninit")])
	_setup_scene([t1])

	var topology := InstructionAnalyzer.build_topology(_scene_root)
	var analysis: Array = topology.get("variable_analysis", [])
	var uninit := analysis.filter(func(a): return a.get("name", "") == "global_uninit")

	_check(not uninit.is_empty(), "global_uninit 在 variable_analysis 中")
	if not uninit.is_empty():
		_check(uninit[0].get("anomaly", "") == "read_only", "anomaly=read_only（实际 %s）" % uninit[0].get("anomaly", ""))


## 单 Trigger T1 既写又读 global_x → cross_references 关联类为空，variable_analysis normal
func _test_no_cross_ref_when_single_trigger_write_read() -> void:
	print("\n--- 单 Trigger 写+读：cross_ref 关联类为空，variable_analysis normal ---")
	# 单指令同时写+读（target_=write, from_=read 同一变量）
	var inst := MockInst.new()
	inst.target_variable = "global_x"
	inst.target_variable_scope = 2
	inst.from_variable = "global_x"
	inst.from_variable_scope = 2
	inst.resource_name = "ReadWriteX"
	var t1 := _make_trigger("T1", [inst])
	_setup_scene([t1])

	var topology := InstructionAnalyzer.build_topology(_scene_root)
	var cross_refs: Array = topology.get("cross_references", [])
	var write_to_read := cross_refs.filter(func(r): return r.get("type", "") == "variable_write_to_read")
	var write_to_write := cross_refs.filter(func(r): return r.get("type", "") == "variable_write_to_write")

	_check(write_to_read.is_empty(), "单 Trigger → 0 variable_write_to_read（实际 %d）" % write_to_read.size())
	_check(write_to_write.is_empty(), "单 Trigger → 0 variable_write_to_write（实际 %d）" % write_to_write.size())

	var analysis: Array = topology.get("variable_analysis", [])
	var x_entry := analysis.filter(func(a): return a.get("name", "") == "global_x")
	_check(not x_entry.is_empty(), "global_x 在 variable_analysis 中")
	if not x_entry.is_empty():
		_check(x_entry[0].get("anomaly", "") == "normal", "anomaly=normal（既有写者又有读者，实际 %s）" % x_entry[0].get("anomaly", ""))


## T1/T2 各自同指令写+读 global_rw → 模式合并为 read_write 后双方均进 writers 与 readers，
## 跨 trigger 检测不得被合并削弱：write_to_read 边与 write_to_write 竞态预警都应产出
func _test_cross_ref_when_two_triggers_write_read_same_var() -> void:
	print("\n--- 双 Trigger 各自写+读：write_to_read 边 + write_to_write 预警并存 ---")
	var inst1 := MockInst.new()
	inst1.target_variable = "global_rw"
	inst1.target_variable_scope = 2
	inst1.from_variable = "global_rw"
	inst1.from_variable_scope = 2
	inst1.resource_name = "ReadWriteRW1"
	var inst2 := MockInst.new()
	inst2.target_variable = "global_rw"
	inst2.target_variable_scope = 2
	inst2.from_variable = "global_rw"
	inst2.from_variable_scope = 2
	inst2.resource_name = "ReadWriteRW2"
	var t1 := _make_trigger("T1", [inst1])
	var t2 := _make_trigger("T2", [inst2])
	_setup_scene([t1, t2])

	var topology := InstructionAnalyzer.build_topology(_scene_root)
	var cross_refs: Array = topology.get("cross_references", [])
	var write_to_read := cross_refs.filter(
		func(r): return r.get("type", "") == "variable_write_to_read" and r.get("detail", "") == "global_rw")
	var write_to_write := cross_refs.filter(
		func(r): return r.get("type", "") == "variable_write_to_write" and r.get("detail", "") == "global_rw")

	_check(not write_to_read.is_empty(), "含 variable_write_to_read 条目（实际 %d）" % write_to_read.size())
	if not write_to_read.is_empty():
		var r = write_to_read[0]
		_check(r.get("from", "") == "T1" and r.get("to", "") == "T2", "from=T1 → to=T2（实际 %s → %s）" % [r.get("from", ""), r.get("to", "")])
		_check(r.get("from_mode", "") == "read_write", "from_mode=read_write（合并后，实际 %s）" % r.get("from_mode", ""))
		_check(r.get("to_mode", "") == "read_write", "to_mode=read_write（合并后，实际 %s）" % r.get("to_mode", ""))
	_check(not write_to_write.is_empty(), "含 variable_write_to_write 竞态预警（实际 %d）" % write_to_write.size())
	if not write_to_write.is_empty():
		var rw = write_to_write[0]
		_check(rw.get("warning", false) == true, "warning=true")
		_check(rw.get("from", "") == "T1" and rw.get("to", "") == "T2", "from=T1 → to=T2（实际 %s → %s）" % [rw.get("from", ""), rw.get("to", "")])

	var analysis: Array = topology.get("variable_analysis", [])
	var rw_entry := analysis.filter(func(a): return a.get("name", "") == "global_rw")
	if not rw_entry.is_empty():
		_check(rw_entry[0].get("anomaly", "") == "normal", "anomaly=normal（实际 %s）" % rw_entry[0].get("anomaly", ""))
