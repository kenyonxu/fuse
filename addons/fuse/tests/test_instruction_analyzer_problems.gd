extends Node

## InstructionAnalyzer.analyze_problems 单测
##
## analyze_problems(instructions) -> {valid: bool, problems: Array}
## 覆盖：空序列、先写后读（正常）、读未定义（报错）、read_write 先出现（定义）。
const InstructionAnalyzer = preload("res://addons/fuse/editor/analysis/instruction_analyzer.gd")

var _fail := 0


func _ready() -> void:
	_test_empty_sequence_valid()
	_test_no_undefined_local()
	_test_undefined_local_detected()
	_test_read_write_defines_variable()
	_test_condition_read_undefined()
	_test_condition_read_defined()
	_test_condition_does_not_define()
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
