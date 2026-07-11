extends Node

const PrintVariableValue = preload("res://addons/fuse/instructions/debug/print_variable_value.gd")
const ForEach = preload("res://addons/fuse/instructions/flow_control/for_each.gd")
const CheckVariable = preload("res://addons/fuse/conditions/variable/check_variable.gd")

var _fail := 0

func _ready() -> void:
	_test_print_variable_read_mode()
	_test_foreach_array_read_mode()
	_test_check_variable_read_mode()
	print("\n=== 结果: %d 处失败 ===" % _fail)
	if _fail > 0:
		push_error("variable_modes 测试失败: %d 处" % _fail)
	get_tree().quit()

func _check(c: bool, msg: String) -> void:
	if c:
		print("  PASS: ", msg)
	else:
		_fail += 1
		push_error("  FAIL: ", msg)

func _test_print_variable_read_mode() -> void:
	print("\n--- PrintVariableValue variable_name = read ---")
	var inst := PrintVariableValue.new()
	var modes := inst.get_variable_modes()
	var found := false
	for m in modes:
		if m.name == "variable_name":
			_check(m.mode == "read", "mode=read（实际 %s）" % m.mode)
			found = true
	_check(found, "含 variable_name 声明")
	inst.free()

func _test_foreach_array_read_mode() -> void:
	print("\n--- ForEach array_variable = read ---")
	var inst := ForEach.new()
	var modes := inst.get_variable_modes()
	var array_mode := ""
	for m in modes:
		if m.name == "array_variable":
			array_mode = m.mode
	_check(array_mode == "read", "array_variable mode=read（实际 %s）" % array_mode)
	inst.free()

func _test_check_variable_read_mode() -> void:
	print("\n--- CheckVariable variable_name = read ---")
	var inst := CheckVariable.new()
	var modes := inst.get_variable_modes()
	var vn_mode := ""
	var cv_mode := ""
	for m in modes:
		if m.name == "variable_name":
			vn_mode = m.mode
		if m.name == "compare_variable":
			cv_mode = m.mode
	_check(vn_mode == "read", "variable_name read（实际 %s）" % vn_mode)
	_check(cv_mode == "read", "compare_variable read（实际 %s）" % cv_mode)
	inst.free()
