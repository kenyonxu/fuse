extends Node

const PrintVariableValue = preload("res://addons/fuse/instructions/debug/print_variable_value.gd")
const ForEach = preload("res://addons/fuse/instructions/flow_control/for_each.gd")
const CheckVariable = preload("res://addons/fuse/conditions/variable/check_variable.gd")
const MathOperation = preload("res://addons/fuse/instructions/math/math_operation.gd")
const RandomNumber = preload("res://addons/fuse/instructions/math/random_number.gd")
const DictGetValue = preload("res://addons/fuse/instructions/dictionaries/dict_get_value.gd")
const CheckNodeActive = preload("res://addons/fuse/conditions/node/check_node_active.gd")
const CheckDistance = preload("res://addons/fuse/conditions/distance/check_distance.gd")
const CheckOverlapArea = preload("res://addons/fuse/conditions/physics/check_overlap_area.gd")

var _fail := 0

func _ready() -> void:
	_test_print_variable_read_mode()
	_test_foreach_array_read_mode()
	_test_check_variable_read_mode()
	_test_math_operation_multi_mode()
	_test_random_number_save_to_write()
	_test_dict_get_value_modes()
	_test_check_node_active_read_mode()
	_test_check_distance_dual_read_mode()
	_test_check_overlap_area_write_mode()
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

func _test_foreach_array_read_mode() -> void:
	print("\n--- ForEach array_variable = read ---")
	var inst := ForEach.new()
	var modes := inst.get_variable_modes()
	var array_mode := ""
	for m in modes:
		if m.name == "array_variable":
			array_mode = m.mode
	_check(array_mode == "read", "array_variable mode=read（实际 %s）" % array_mode)

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

## Phase 2: MathOperation 多属性（save_to=write + operand_a/b=read）
func _test_math_operation_multi_mode() -> void:
	print("\n--- MathOperation save_to=write, operand_a/b=read ---")
	var inst := MathOperation.new()
	var modes := inst.get_variable_modes()
	var save_mode := ""
	var opa_mode := ""
	var opb_mode := ""
	for m in modes:
		if m.name == "save_to_variable":
			save_mode = m.mode
		if m.name == "operand_a_variable":
			opa_mode = m.mode
		if m.name == "operand_b_variable":
			opb_mode = m.mode
	_check(save_mode == "write", "save_to_variable write（实际 %s）" % save_mode)
	_check(opa_mode == "read", "operand_a_variable read（实际 %s）" % opa_mode)
	_check(opb_mode == "read", "operand_b_variable read（实际 %s）" % opb_mode)

## Phase 2: RandomNumber save_to-only（write）
func _test_random_number_save_to_write() -> void:
	print("\n--- RandomNumber save_to_variable = write ---")
	var inst := RandomNumber.new()
	var modes := inst.get_variable_modes()
	var save_mode := ""
	for m in modes:
		if m.name == "save_to_variable":
			save_mode = m.mode
	_check(save_mode == "write", "save_to_variable write（实际 %s）" % save_mode)

## Phase 2: DictGetValue（dict/key=read + target=write）
func _test_dict_get_value_modes() -> void:
	print("\n--- DictGetValue dict/key=read, target=write ---")
	var inst := DictGetValue.new()
	var modes := inst.get_variable_modes()
	var dict_mode := ""
	var key_mode := ""
	var tgt_mode := ""
	for m in modes:
		if m.name == "dict_variable":
			dict_mode = m.mode
		if m.name == "key_variable":
			key_mode = m.mode
		if m.name == "target_variable":
			tgt_mode = m.mode
	_check(dict_mode == "read", "dict_variable read（实际 %s）" % dict_mode)
	_check(key_mode == "read", "key_variable read（实际 %s）" % key_mode)
	_check(tgt_mode == "write", "target_variable write（实际 %s）" % tgt_mode)

## Phase 3: CheckNodeActive（node_variable_name read）— 代表节点类 condition 抽验
func _test_check_node_active_read_mode() -> void:
	print("\n--- CheckNodeActive node_variable_name = read ---")
	var inst := CheckNodeActive.new()
	var modes := inst.get_variable_modes()
	var vn_mode := ""
	for m in modes:
		if m.name == "node_variable_name":
			vn_mode = m.mode
	_check(vn_mode == "read", "node_variable_name read（实际 %s）" % vn_mode)

## Phase 3: CheckDistance（source/target 双 read）— 代表双节点类 condition 抽验
func _test_check_distance_dual_read_mode() -> void:
	print("\n--- CheckDistance source/target_variable_name = read ---")
	var inst := CheckDistance.new()
	var modes := inst.get_variable_modes()
	var src_mode := ""
	var tgt_mode := ""
	for m in modes:
		if m.name == "source_variable_name":
			src_mode = m.mode
		if m.name == "target_variable_name":
			tgt_mode = m.mode
	_check(src_mode == "read", "source_variable_name read（实际 %s）" % src_mode)
	_check(tgt_mode == "read", "target_variable_name read（实际 %s）" % tgt_mode)

## Phase 3: CheckOverlapArea（save_to_variable write）— condition 写变量场景抽验
func _test_check_overlap_area_write_mode() -> void:
	print("\n--- CheckOverlapArea save_to_variable = write ---")
	var inst := CheckOverlapArea.new()
	var modes := inst.get_variable_modes()
	var save_mode := ""
	for m in modes:
		if m.name == "save_to_variable":
			save_mode = m.mode
	_check(save_mode == "write", "save_to_variable write（实际 %s）" % save_mode)
