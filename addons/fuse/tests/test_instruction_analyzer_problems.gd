extends Node

## InstructionAnalyzer.analyze_problems 单测（TDD RED 阶段）
##
## analyze_problems(instructions) -> {valid: bool, problems: Array}
## 方法尚未实现，本测试预期失败（RED）。
const InstructionAnalyzer = preload("res://addons/fuse/editor/analysis/instruction_analyzer.gd")

var _fail := 0


func _ready() -> void:
	_test_empty_sequence_valid()
	_test_no_undefined_local()
	_test_undefined_local_detected()
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


## 构造伪指令：含 target_variable（write）+ from_variable（read）属性
func _make_inst(target_var: String, from_var: String) -> Resource:
	var inst := MockInst.new()
	inst.target_variable = target_var
	inst.target_variable_scope = 0
	if not from_var.is_empty():
		inst.from_variable = from_var
		inst.from_variable_scope = 0
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
