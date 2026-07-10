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
