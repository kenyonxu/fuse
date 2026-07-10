extends Node

## InstructionAnalyzer.analyze_problems 单测
##
## analyze_problems(instructions, scene_root=null) -> {valid: bool, problems: Array}
## 覆盖：空序列、先写后读（正常）、读未定义（报错）、read_write 先出现（定义）、
##       NodePath 解析失败检测（E1）。
const InstructionAnalyzer = preload("res://addons/fuse/editor/analysis/instruction_analyzer.gd")
const NodePathResolver = preload("res://addons/fuse/editor/serialization/nodepath_resolver.gd")

var _fail := 0
var _scene_root: Node = null


func _ready() -> void:
	_test_empty_sequence_valid()
	_test_no_undefined_local()
	_test_undefined_local_detected()
	_test_read_write_defines_variable()
	_test_condition_read_undefined()
	_test_condition_read_defined()
	_test_condition_read_scope_not_undefined()
	_test_condition_does_not_define()
	# E1: NodePath 解析失败检测
	_setup_nodepath_test_scene()
	_test_resolve_or_null_relative_ok()
	_test_resolve_or_null_nonexistent_returns_null()
	_test_resolve_or_null_absolute_ok()
	_test_resolve_or_null_parent_path_ok()
	_test_resolve_or_null_multi_segment_ok()
	_test_resolve_or_null_empty_string_returns_null()
	_test_resolve_or_null_global_name_fallback()
	_test_resolve_or_null_null_scene_root_returns_null()
	_test_nodepath_relative_resolve_ok()
	_test_nodepath_relative_resolve_fail()
	_test_nodepath_skip_when_no_scene_root()
	_test_nodepath_skip_empty()
	_test_nodepath_global_name_fallback()
	_test_nodepath_multiple_instructions()
	_teardown_nodepath_test_scene()
	# E2: 信号引用检测
	_setup_signal_test_scene()
	_test_extract_signal_refs_basic()
	_test_extract_signal_refs_empty_skip()
	_test_extract_signal_refs_no_signal_prop()
	_test_extract_signal_refs_naming_heuristics()
	_test_signal_target_has_signal_no_error()
	_test_signal_target_missing_signal_error()
	_test_signal_skip_when_no_scene_root()
	_test_signal_target_node_unresolvable_skip()
	_test_signal_empty_target_defaults_to_scene_root()
	_teardown_signal_test_scene()
	# E5: index_problems / collect_insts_from_report / collect_insts_from_tree（公开静态）
	_test_index_problems_structure()
	_test_index_problems_empty_safe()
	_test_index_problems_summary_suggestions()
	_test_collect_insts_from_report_flat_with_inst()
	_test_collect_insts_from_report_tree_fallback()
	_test_collect_insts_from_report_event_bindings()
	_test_collect_insts_from_report_empty()
	_test_collect_insts_from_tree_recursive_children()
	_test_collect_insts_from_tree_empty()
	print("\n=== 结果: %d 处失败 ===" % _fail)
	if _fail > 0:
		push_error("analyze_problems 测试失败: %d 处" % _fail)
	get_tree().quit()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: ", msg)
	else:
		_fail += 1
		push_error("  FAIL: ", msg)


## 最小 mock 指令：用 Resource + @export 让 get_property_list() 暴露属性。
## RefCounted + 动态 set() 不会出现在 get_property_list()，故用 Resource。
class MockInst extends Resource:
	@export var target_variable: String = ""
	@export var target_variable_scope: int = 0
	@export var from_variable: String = ""
	@export var from_variable_scope: int = 0
	@export var value_variable: String = ""        # read_write mode（无 target_/from_ 前缀）
	@export var value_variable_scope: int = 0
	@export var condition: Resource = null          # 条件（MockCondition）
	# E1: NodePath 引用属性（命名命中 _extract_nodepaths 的 *_node 启发式）
	@export var target_node: NodePath = NodePath("")
	# E2: 信号引用属性（命名命中 _is_signal_prop / target_node 复用）
	@export var signal_name: String = ""
	@export var custom_signal: String = ""          # *_signal 启发式覆盖
	@export var emit_signal: String = ""             # 显式 emit_signal 命名


## 最小 mock 条件：variable_name 让 _extract_variables 提取（_is_variable_prop 支持）
class MockCondition extends Resource:
	@export var variable_name: String = ""
	@export var variable_scope: int = 0


## 构造伪指令：target_variable（write）+ from_variable（read）+ value_variable（read_write）
func _make_inst(target_var: String, from_var: String, rw_var: String = "") -> Resource:
	var inst := MockInst.new()
	inst.target_variable = target_var
	inst.target_variable_scope = 0
	if not from_var.is_empty():
		inst.from_variable = from_var
		inst.from_variable_scope = 0
	if not rw_var.is_empty():
		inst.value_variable = rw_var
		inst.value_variable_scope = 0
	return inst


func _test_empty_sequence_valid() -> void:
	print("\n--- 空序列 valid=true ---")
	var r := InstructionAnalyzer.analyze_problems([])
	_check(r.valid == true, "空序列 valid=true")
	_check(r.problems.is_empty(), "空序列 0 problems")


func _test_no_undefined_local() -> void:
	print("\n--- 先定义后使用：无未声明 ---")
	var insts := [_make_inst("hp", ""), _make_inst("", "hp")]
	var r := InstructionAnalyzer.analyze_problems(insts)
	_check(r.valid == true, "先写后读 valid=true")
	_check(r.problems.is_empty(), "无 problems（hp 已定义）")


func _test_undefined_local_detected() -> void:
	print("\n--- 读未定义 local 变量：报 error ---")
	var insts := [_make_inst("", "mana")]
	var r := InstructionAnalyzer.analyze_problems(insts)
	_check(r.valid == false, "未声明 valid=false")
	_check(r.problems.size() == 1, "1 problem（实际 %d）" % r.problems.size())
	if r.problems.size() == 1:
		var p = r.problems[0]
		_check(p.severity == "error", "severity=error")
		_check(p.instruction_index == 0, "instruction_index=0")
		_check(p.variable == "mana", "variable=mana")


func _test_read_write_defines_variable() -> void:
	print("\n--- read_write 模式先出现 → 定义，不报未声明 ---")
	var insts := [_make_inst("", "", "score")]  # value_variable=score（read_write）
	var r := InstructionAnalyzer.analyze_problems(insts)
	_check(r.valid == true, "read_write 先出现 valid=true（score 被定义）")
	_check(r.problems.is_empty(), "无 problem")


func _test_condition_read_undefined() -> void:
	print("\n--- 条件读未声明 local 变量 → error ---")
	var cond := MockCondition.new()
	cond.variable_name = "undefined_in_condition"
	var inst := _make_inst("", "", "")
	inst.condition = cond
	var r := InstructionAnalyzer.analyze_problems([inst])
	_check(r.valid == false, "条件读未声明 valid=false")
	_check(r.problems.size() == 1, "1 problem（实际 %d）" % r.problems.size())
	if r.problems.size() == 1:
		_check(r.problems[0].variable == "undefined_in_condition", "variable=undefined_in_condition")


func _test_condition_read_defined() -> void:
	print("\n--- 条件读已声明变量（前序 write）→ valid ---")
	var write_inst := _make_inst("shared", "", "")
	var cond := MockCondition.new()
	cond.variable_name = "shared"
	var cond_inst := _make_inst("", "", "")
	cond_inst.condition = cond
	var r := InstructionAnalyzer.analyze_problems([write_inst, cond_inst])
	_check(r.valid == true, "条件读已声明 valid=true")
	_check(r.problems.is_empty(), "0 problem")


func _test_condition_read_scope_not_undefined() -> void:
	print("\n--- 条件读 scope 变量（variable_scope=1）→ 不报未声明（scope 非 local）---")
	var cond := MockCondition.new()
	cond.variable_name = "scope_var"
	cond.variable_scope = 1  # SCOPE
	var inst := _make_inst("", "", "")
	inst.condition = cond
	var r := InstructionAnalyzer.analyze_problems([inst])
	_check(r.valid == true, "scope 变量不报未声明 valid=true")
	_check(r.problems.is_empty(), "0 problem（scope 不在 local 未声明检测范围）")


func _test_condition_does_not_define() -> void:
	print("\n--- 条件变量不进 defined_locals（条件只读）---")
	var cond := MockCondition.new()
	cond.variable_name = "cond_only"
	var cond_inst := _make_inst("", "", "")
	cond_inst.condition = cond
	var read_inst := _make_inst("", "cond_only", "")
	var r := InstructionAnalyzer.analyze_problems([cond_inst, read_inst])
	_check(r.problems.size() >= 1, "cond_only 未被条件定义，read 仍报（实际 %d）" % r.problems.size())


# ============================================================
# E1: NodePath 解析失败检测
# ============================================================

## 构造临时测试场景树供 resolve_or_null 解析：
##   TestRoot (Node, name=TestScene)
##   ├── Player (Node2D)
##   ├── UI (Node)
##   │   └── HealthBar (ProgressBar)
##   └── Enemy (CharacterBody2D)
func _setup_nodepath_test_scene() -> void:
	print("\n[setup] 构造 NodePath 测试场景树")
	var root := Node.new()
	root.name = "TestScene"
	var player := Node2D.new()
	player.name = "Player"
	root.add_child(player)
	var ui := Node.new()
	ui.name = "UI"
	root.add_child(ui)
	var health_bar := ProgressBar.new()
	health_bar.name = "HealthBar"
	ui.add_child(health_bar)
	var enemy := CharacterBody2D.new()
	enemy.name = "Enemy"
	root.add_child(enemy)
	# 入树（find_children 需要 tree 非空）
	add_child(root)
	_scene_root = root


func _teardown_nodepath_test_scene() -> void:
	if _scene_root != null and is_instance_valid(_scene_root):
		_scene_root.queue_free()
	_scene_root = null


# ----- NodePathResolver.resolve_or_null 单测 -----

func _test_resolve_or_null_relative_ok() -> void:
	print("\n--- resolve_or_null 相对路径解析成功 ---")
	var node := NodePathResolver.resolve_or_null("Player", _scene_root)
	_check(node != null, "Player 解析非空")
	if node != null:
		_check(node.name == "Player", "解析到 Player")


func _test_resolve_or_null_nonexistent_returns_null() -> void:
	print("\n--- resolve_or_null 不存在节点 → null ---")
	var node := NodePathResolver.resolve_or_null("NonexistentNode", _scene_root)
	_check(node == null, "NonexistentNode → null")


func _test_resolve_or_null_absolute_ok() -> void:
	print("\n--- resolve_or_null 绝对路径解析 ---")
	var node := NodePathResolver.resolve_or_null("/root/TestScene/Player", _scene_root)
	_check(node != null, "/root/TestScene/Player 解析非空")
	if node != null:
		_check(node.name == "Player", "绝对路径解析到 Player")


func _test_resolve_or_null_parent_path_ok() -> void:
	print("\n--- resolve_or_null 父级回退（跨兄弟）---")
	# scene_root 的子节点 Player 解析 "../Enemy"——
	# 实际 E1 以 scene_root 为锚点，"../" 从 scene_root 父级（场景树 root）查
	# 测试以 scene_root 视角：get_node_or_null("../TestScene/Enemy") 命中
	var node := NodePathResolver.resolve_or_null("../TestScene/Enemy", _scene_root)
	_check(node != null, "../TestScene/Enemy 解析非空")
	if node != null:
		_check(node.name == "Enemy", "父级回退解析到 Enemy")


func _test_resolve_or_null_multi_segment_ok() -> void:
	print("\n--- resolve_or_null 多段路径 UI/HealthBar ---")
	var node := NodePathResolver.resolve_or_null("UI/HealthBar", _scene_root)
	_check(node != null, "UI/HealthBar 解析非空")
	if node != null:
		_check(node.name == "HealthBar", "解析到 HealthBar")


func _test_resolve_or_null_empty_string_returns_null() -> void:
	print("\n--- resolve_or_null 空字符串 → null（自守卫）---")
	var node := NodePathResolver.resolve_or_null("", _scene_root)
	_check(node == null, "空字符串 → null")


func _test_resolve_or_null_global_name_fallback() -> void:
	print("\n--- resolve_or_null 策略 2 兜底（最后段同名）---")
	# 构造一个不存在相对路径但节点名在场景中的：路径错但 HealthBar 存在
	var node := NodePathResolver.resolve_or_null("SomeWrongPath/HealthBar", _scene_root)
	_check(node != null, "策略 2 兜底匹配 HealthBar")


func _test_resolve_or_null_null_scene_root_returns_null() -> void:
	print("\n--- resolve_or_null scene_root=null → null（自守卫）---")
	var node := NodePathResolver.resolve_or_null("Player", null)
	_check(node == null, "scene_root=null → null")


# ----- analyze_problems NodePath 检测单测 -----

func _test_nodepath_relative_resolve_ok() -> void:
	print("\n--- NodePath 有效相对路径 → 0 warning ---")
	var inst := _make_inst("", "", "")
	inst.target_node = NodePath("Player")
	var r := InstructionAnalyzer.analyze_problems([inst], _scene_root)
	var warnings := _count_warnings(r.problems)
	_check(warnings == 0, "有效 NodePath 0 warning（实际 %d）" % warnings)


func _test_nodepath_relative_resolve_fail() -> void:
	print("\n--- NodePath 无效路径 → 1 warning（含 nodepath 字段）---")
	var inst := _make_inst("", "", "")
	inst.target_node = NodePath("GhostNode")
	var r := InstructionAnalyzer.analyze_problems([inst], _scene_root)
	_check(r.valid == false, "含 warning → valid=false")
	var warnings := _count_warnings(r.problems)
	_check(warnings == 1, "1 warning（实际 %d）" % warnings)
	if warnings >= 1:
		var p = _first_warning(r.problems)
		_check(p.severity == "warning", "severity=warning")
		_check(p.nodepath == "GhostNode", "nodepath=GhostNode")
		_check(p.instruction_index == 0, "instruction_index=0")
		_check(p.inst == inst, "inst 字段指向触发指令")


func _test_nodepath_skip_when_no_scene_root() -> void:
	print("\n--- scene_root=null 跳过 NodePath 检测 ---")
	var inst := _make_inst("", "", "")
	inst.target_node = NodePath("GhostNode")
	# 不传 scene_root（默认 null）
	var r := InstructionAnalyzer.analyze_problems([inst])
	var warnings := _count_warnings(r.problems)
	_check(warnings == 0, "scene_root=null → 0 warning（跳过检测）")
	_check(r.valid == true, "scene_root=null 且无变量错误 → valid=true")


func _test_nodepath_skip_empty() -> void:
	print("\n--- 空 NodePath → 不报 warning ---")
	var inst := _make_inst("", "", "")
	inst.target_node = NodePath("")
	var r := InstructionAnalyzer.analyze_problems([inst], _scene_root)
	var warnings := _count_warnings(r.problems)
	_check(warnings == 0, "空 NodePath 0 warning")


func _test_nodepath_global_name_fallback() -> void:
	print("\n--- NodePath 策略 2 兜底成功 → 0 warning ---")
	var inst := _make_inst("", "", "")
	# 路径前段错但末段 HealthBar 存在
	inst.target_node = NodePath("WrongPrefix/HealthBar")
	var r := InstructionAnalyzer.analyze_problems([inst], _scene_root)
	var warnings := _count_warnings(r.problems)
	_check(warnings == 0, "策略 2 兜底成功 → 0 warning（实际 %d）" % warnings)


func _test_nodepath_multiple_instructions() -> void:
	print("\n--- 多指令混合（有效+无效）→ instruction_index 正确 ---")
	var good := _make_inst("", "", "")
	good.target_node = NodePath("Player")
	var bad := _make_inst("", "", "")
	bad.target_node = NodePath("MissingOne")
	var r := InstructionAnalyzer.analyze_problems([good, bad], _scene_root)
	var warnings := _count_warnings(r.problems)
	_check(warnings == 1, "仅 1 warning（实际 %d）" % warnings)
	if warnings >= 1:
		var p = _first_warning(r.problems)
		_check(p.instruction_index == 1, "instruction_index=1（bad 是第二条）")
		_check(p.nodepath == "MissingOne", "nodepath=MissingOne")


# ----- 辅助 -----

func _count_warnings(problems: Array) -> int:
	var n := 0
	for p in problems:
		if p.get("severity", "") == "warning":
			n += 1
	return n


func _first_warning(problems: Array) -> Dictionary:
	for p in problems:
		if p.get("severity", "") == "warning":
			return p
	return {}


# ============================================================
# E2: 信号引用检测
# ============================================================

## E2 信号测试场景：
##   SignalScene (Node)
##   ├── SignalButton (Button)        ← 有内置信号 pressed / button_up / button_down
##   └── PlainNode (Node)             ← 无自定义信号，仅 Object 基础信号
var _signal_scene_root: Node = null


func _setup_signal_test_scene() -> void:
	print("\n[setup] 构造信号引用测试场景树")
	var root := Node.new()
	root.name = "SignalScene"
	var btn := Button.new()
	btn.name = "SignalButton"
	root.add_child(btn)
	var plain := Node.new()
	plain.name = "PlainNode"
	root.add_child(plain)
	add_child(root)
	_signal_scene_root = root


func _teardown_signal_test_scene() -> void:
	if _signal_scene_root != null and is_instance_valid(_signal_scene_root):
		_signal_scene_root.queue_free()
	_signal_scene_root = null


## 构造含信号引用的 mock 指令
## signal_name / custom_signal / emit_signal 三选一；target_node 可选 NodePath
func _make_signal_inst(p_signal_name: String, p_target: NodePath = NodePath("")) -> Resource:
	var inst := MockInst.new()
	if not p_signal_name.is_empty():
		inst.signal_name = p_signal_name
	if p_target != NodePath(""):
		inst.target_node = p_target
	return inst


# ----- _extract_signal_refs 直接测试（单元级） -----

func _test_extract_signal_refs_basic() -> void:
	print("\n--- _extract_signal_refs 提取 signal_name + target_node ---")
	var inst := MockInst.new()
	inst.signal_name = "pressed"
	inst.target_node = NodePath("SignalButton")
	var tmp := {}
	InstructionAnalyzer._extract_signal_refs(inst, tmp)
	var refs: Array = tmp.get("signal_refs", [])
	_check(refs.size() == 1, "提取 1 条 signal_ref（实际 %d）" % refs.size())
	if refs.size() >= 1:
		_check(refs[0].signal_name == "pressed", "signal_name=pressed")
		_check(refs[0].target_str == "SignalButton", "target_str=SignalButton")


func _test_extract_signal_refs_empty_skip() -> void:
	print("\n--- _extract_signal_refs 空 signal_name 跳过 ---")
	var inst := MockInst.new()
	inst.signal_name = ""  # 空字符串
	var tmp := {}
	InstructionAnalyzer._extract_signal_refs(inst, tmp)
	var refs: Array = tmp.get("signal_refs", [])
	_check(refs.is_empty(), "空 signal_name → 0 ref（实际 %d）" % refs.size())


func _test_extract_signal_refs_no_signal_prop() -> void:
	print("\n--- _extract_signal_refs 无信号属性的指令 → 0 ref ---")
	# 仅设变量属性，无 signal_name 等
	var inst := _make_inst("hp", "", "")
	var tmp := {}
	InstructionAnalyzer._extract_signal_refs(inst, tmp)
	var refs: Array = tmp.get("signal_refs", [])
	_check(refs.is_empty(), "无信号属性 → 0 ref（实际 %d）" % refs.size())


func _test_extract_signal_refs_naming_heuristics() -> void:
	print("\n--- _extract_signal_refs 命名启发式：signal_name / custom_signal / emit_signal ---")
	var inst := MockInst.new()
	inst.signal_name = "sig_a"
	inst.custom_signal = "sig_b"
	inst.emit_signal = "sig_c"
	var tmp := {}
	InstructionAnalyzer._extract_signal_refs(inst, tmp)
	var refs: Array = tmp.get("signal_refs", [])
	_check(refs.size() == 3, "命名启发式覆盖 3 个属性（实际 %d）" % refs.size())
	if refs.size() >= 3:
		var names: Array = []
		for r in refs:
			names.append(r.signal_name)
		_check("sig_a" in names, "signal_name 命中")
		_check("sig_b" in names, "custom_signal 命中（*_signal）")
		_check("sig_c" in names, "emit_signal 命中")


# ----- analyze_problems 信号检测（集成级） -----

func _test_signal_target_has_signal_no_error() -> void:
	print("\n--- 目标节点有该信号 → 0 signal error ---")
	# Button.pressed 是内置信号，必然存在
	var inst := _make_signal_inst("pressed", NodePath("SignalButton"))
	var r := InstructionAnalyzer.analyze_problems([inst], _signal_scene_root)
	var errs := _count_signal_errors(r.problems)
	_check(errs == 0, "pressed 信号存在 → 0 error（实际 %d）" % errs)


func _test_signal_target_missing_signal_error() -> void:
	print("\n--- 目标节点无该信号 → 1 signal error ---")
	# SignalButton 不存在 nonexistent_signal
	var inst := _make_signal_inst("nonexistent_signal", NodePath("SignalButton"))
	var r := InstructionAnalyzer.analyze_problems([inst], _signal_scene_root)
	var errs := _count_signal_errors(r.problems)
	_check(errs == 1, "nonexistent_signal 不存在 → 1 error（实际 %d）" % errs)
	if errs >= 1:
		var p = _first_signal_error(r.problems)
		_check(p.severity == "error", "severity=error")
		_check(p.signal_name == "nonexistent_signal", "signal_name=nonexistent_signal")
		_check(p.target_node_str == "SignalButton", "target_node_str=SignalButton")
		_check(p.instruction_index == 0, "instruction_index=0")
		_check(p.inst == inst, "inst 指向触发指令")


func _test_signal_skip_when_no_scene_root() -> void:
	print("\n--- scene_root=null 跳过信号检测 ---")
	var inst := _make_signal_inst("nonexistent_signal", NodePath("SignalButton"))
	var r := InstructionAnalyzer.analyze_problems([inst])
	var errs := _count_signal_errors(r.problems)
	_check(errs == 0, "scene_root=null → 0 signal error（跳过检测）")


func _test_signal_target_node_unresolvable_skip() -> void:
	print("\n--- target_node 解析失败 → 跳过（由 E1 报 NodePath 问题） ---")
	# GhostNode 不存在 → resolve_or_null 返 null → E2 跳过，不报信号错误
	var inst := _make_signal_inst("nonexistent_signal", NodePath("GhostNode"))
	var r := InstructionAnalyzer.analyze_problems([inst], _signal_scene_root)
	var errs := _count_signal_errors(r.problems)
	_check(errs == 0, "target 不可解析 → 0 signal error（实际 %d）" % errs)


func _test_signal_empty_target_defaults_to_scene_root() -> void:
	print("\n--- 空 target_str → 默认 scene_root（绕过 resolve_or_null，MEDIUM #5） ---")
	# 不设 target_node（空 NodePath），信号为 SignalScene 自身没有的信号
	# scene_root 是普通 Node，不存在 "some_signal"
	var inst := _make_signal_inst("some_signal", NodePath(""))
	var r := InstructionAnalyzer.analyze_problems([inst], _signal_scene_root)
	var errs := _count_signal_errors(r.problems)
	_check(errs == 1, "空 target → 默认 scene_root，无该信号 → 1 error（实际 %d）" % errs)
	if errs >= 1:
		var p = _first_signal_error(r.problems)
		_check(p.signal_name == "some_signal", "signal_name=some_signal")
		_check(p.target_node_str == "", "target_node_str 为空（默认 scene_root）")


# ----- E2 辅助 -----

func _count_signal_errors(problems: Array) -> int:
	# 信号检测 problem 含 signal_name 字段，与变量检测区分
	var n := 0
	for p in problems:
		if p.get("severity", "") == "error" and p.has("signal_name"):
			n += 1
	return n


func _first_signal_error(problems: Array) -> Dictionary:
	for p in problems:
		if p.get("severity", "") == "error" and p.has("signal_name"):
			return p
	return {}


# ============================================================
# E5: InstructionAnalyzer.index_problems / collect_insts_from_report / collect_insts_from_tree（公开静态）
# ============================================================

## index_problems 基础结构：按 inst.instance_id 分组 + summary 计数
func _test_index_problems_structure() -> void:
	print("\n--- index_problems 按 inst 分组 + summary ---")
	var inst1 := _make_inst("", "missing", "")  # 读未声明 → 1 error
	var inst2 := _make_inst("", "another_missing", "")  # 另一读未声明 → 1 error
	var analysis := InstructionAnalyzer.analyze_problems([inst1, inst2])
	var indexed: Dictionary = InstructionAnalyzer.index_problems(analysis.problems)
	_check(indexed.has("by_inst"), "返回含 by_inst")
	_check(indexed.has("summary"), "返回含 summary")
	var summary: Dictionary = indexed.get("summary", {})
	_check(summary.has("errors"), "summary 含 errors")
	_check(summary.has("warnings"), "summary 含 warnings")
	_check(summary.has("suggestions"), "summary 含 suggestions（与 Topology 结构一致）")
	_check(summary.get("errors", 0) == 2, "errors=2（实际 %d）" % summary.get("errors", 0))
	_check(summary.get("warnings", 0) == 0, "warnings=0")
	# by_inst 应按 inst.instance_id 索引
	var by_inst: Dictionary = indexed.get("by_inst", {})
	_check(by_inst.has(inst1.get_instance_id()), "by_inst 含 inst1 key")
	_check(by_inst.has(inst2.get_instance_id()), "by_inst 含 inst2 key")
	_check(by_inst[inst1.get_instance_id()].size() == 1, "inst1 1 problem")


## index_problems 空 problems 安全返回零 summary
func _test_index_problems_empty_safe() -> void:
	print("\n--- index_problems 空 problems 安全返回 ---")
	var indexed: Dictionary = InstructionAnalyzer.index_problems([])
	_check(indexed.has("by_inst"), "空 → 含 by_inst（空 dict）")
	_check(indexed.by_inst.is_empty(), "空 → by_inst 为空")
	var summary: Dictionary = indexed.get("summary", {})
	_check(summary.get("errors", -1) == 0, "空 → errors=0")
	_check(summary.get("warnings", -1) == 0, "空 → warnings=0")
	_check(summary.get("suggestions", -1) == 0, "空 → suggestions=0")


## index_problems summary 含 warnings + suggestions 计数
func _test_index_problems_summary_suggestions() -> void:
	print("\n--- index_problems summary warnings/suggestions 计数 ---")
	# 构造含 warning + suggestion severity 的 problems（analyze_problems 不产 suggestion，
	# 此处直接构造 problems 数组验证 _index_problems 的 severity 分类逻辑）
	var inst := _make_inst("", "", "")
	var problems := [
		{"severity": "warning", "inst": inst, "message": "w1"},
		{"severity": "suggestion", "inst": inst, "message": "s1"},
		{"severity": "suggestion", "inst": inst, "message": "s2"},
	]
	var indexed: Dictionary = InstructionAnalyzer.index_problems(problems)
	var summary: Dictionary = indexed.get("summary", {})
	_check(summary.get("warnings", 0) == 1, "warnings=1（实际 %d）" % summary.get("warnings", 0))
	_check(summary.get("suggestions", 0) == 2, "suggestions=2（实际 %d）" % summary.get("suggestions", 0))
	_check(summary.get("errors", 0) == 0, "errors=0")


## collect_insts_from_report 优先 instructions_flat（含 inst 字段）
func _test_collect_insts_from_report_flat_with_inst() -> void:
	print("\n--- collect_insts_from_report flat 含 inst 字段 ---")
	var inst1 := _make_inst("a", "", "")
	var inst2 := _make_inst("", "", "b")
	var report := {
		"instructions_flat": [{"name": "A", "prefix": "", "inst": inst1}, {"name": "B", "prefix": "", "inst": inst2}],
		"instructions_tree": [],
		"event_bindings": [],
	}
	var insts: Array = InstructionAnalyzer.collect_insts_from_report(report)
	_check(insts.size() == 2, "flat 含 inst → 收集 2（实际 %d）" % insts.size())
	if insts.size() >= 2:
		_check(inst1 in insts, "inst1 在结果中")
		_check(inst2 in insts, "inst2 在结果中")


## collect_insts_from_report flat 无 inst 字段 → 回退 instructions_tree 递归
func _test_collect_insts_from_report_tree_fallback() -> void:
	print("\n--- collect_insts_from_report flat 无 inst → 回退 tree ---")
	var inst1 := _make_inst("a", "", "")
	var inst2 := _make_inst("", "", "b")
	# flat 不含 inst 字段（与 analyze_trigger 实际输出一致），触发回退
	var report := {
		"instructions_flat": [{"name": "A", "prefix": ""}, {"name": "B", "prefix": ""}],
		"instructions_tree": [
			{"name": "A", "inst": inst1, "children": {}},
			{"name": "B", "inst": inst2, "children": {}},
		],
		"event_bindings": [],
	}
	var insts: Array = InstructionAnalyzer.collect_insts_from_report(report)
	_check(insts.size() == 2, "tree 回退 → 收集 2（实际 %d）" % insts.size())
	if insts.size() >= 2:
		_check(inst1 in insts, "inst1 在结果中")
		_check(inst2 in insts, "inst2 在结果中")


## collect_insts_from_report 覆盖 event_bindings（MultiEventTrigger 形态）
func _test_collect_insts_from_report_event_bindings() -> void:
	print("\n--- collect_insts_from_report 覆盖 event_bindings ---")
	var inst1 := _make_inst("a", "", "")
	var inst2 := _make_inst("", "", "b")
	var report := {
		"instructions_flat": [],
		"instructions_tree": [],
		"event_bindings": [
			{"index": 0, "instructions_flat": [], "instructions_tree": [{"name": "A", "inst": inst1, "children": {}}]},
			{"index": 1, "instructions_flat": [{"name": "B", "prefix": "", "inst": inst2}], "instructions_tree": []},
		],
	}
	var insts: Array = InstructionAnalyzer.collect_insts_from_report(report)
	_check(insts.size() == 2, "event_bindings → 收集 2（实际 %d）" % insts.size())
	if insts.size() >= 2:
		_check(inst1 in insts, "binding0 inst1 在结果中")
		_check(inst2 in insts, "binding1 inst2 在结果中")


## collect_insts_from_report 空 report 安全返回空数组
func _test_collect_insts_from_report_empty() -> void:
	print("\n--- collect_insts_from_report 空 report 安全返回 ---")
	var insts: Array = InstructionAnalyzer.collect_insts_from_report({})
	_check(insts.is_empty(), "空 report → 空数组")
	# 完整结构但全空
	var report := {
		"instructions_flat": [],
		"instructions_tree": [],
		"event_bindings": [],
	}
	insts = InstructionAnalyzer.collect_insts_from_report(report)
	_check(insts.is_empty(), "全空结构 → 空数组")


## collect_insts_from_tree 递归处理 children 分支（then/else/loop）
func _test_collect_insts_from_tree_recursive_children() -> void:
	print("\n--- collect_insts_from_tree 递归 children 分支 ---")
	var inst_root := _make_inst("a", "", "")
	var inst_then := _make_inst("", "x", "")
	var inst_else := _make_inst("", "y", "")
	var inst_loop := _make_inst("", "", "z")
	var tree := [
		{
			"name": "Root",
			"inst": inst_root,
			"children": {
				"then": [{"name": "Then", "inst": inst_then, "children": {}}],
				"else": [{"name": "Else", "inst": inst_else, "children": {}}],
				"loop": [{"name": "Loop", "inst": inst_loop, "children": {}}],
			}
		}
	]
	var out: Array = InstructionAnalyzer.collect_insts_from_tree(tree)
	_check(out.size() == 4, "递归 4 inst（root+then+else+loop）（实际 %d）" % out.size())
	if out.size() >= 4:
		_check(inst_root in out, "inst_root 在结果中")
		_check(inst_then in out, "inst_then 在结果中")
		_check(inst_else in out, "inst_else 在结果中")
		_check(inst_loop in out, "inst_loop 在结果中")


## collect_insts_from_tree 空数组安全
func _test_collect_insts_from_tree_empty() -> void:
	print("\n--- collect_insts_from_tree 空数组安全 ---")
	var out: Array = InstructionAnalyzer.collect_insts_from_tree([])
	_check(out.is_empty(), "空 tree → 空数组")
	# 节点无 inst 字段也不应崩
	var out2: Array = InstructionAnalyzer.collect_insts_from_tree([{"name": "X", "children": {}}])
	_check(out2.is_empty(), "无 inst 字段 → 空数组（不崩）")
