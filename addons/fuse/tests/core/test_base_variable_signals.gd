extends Node

## 验证 BaseVariable 信号一致性（B1/B2/B3）+ clone 完整性（B9）

const BaseVariable = preload("res://addons/fuse/core/base/base_variable.gd")

var _fail_count: int = 0

func _ready() -> void:
	_test_setter_emits_both_signals()
	_test_set_value_emits_each_once()
	_test_setter_increments_count_by_one()
	_test_set_value_increments_count_by_one()
	_test_clone_completeness()
	print("\n=== 结果: %d 处失败 ===" % _fail_count)
	if _fail_count > 0:
		push_error("BaseVariable 信号/clone 测试失败: %d 处" % _fail_count)
	get_tree().quit()

func _check(condition: bool, msg: String) -> void:
	if condition:
		print("  PASS: ", msg)
	else:
		_fail_count += 1
		push_error("  FAIL: ", msg)

func _test_setter_emits_both_signals() -> void:
	print("\n--- 直接赋值应同时 emit value_changed 与 value_modified ---")
	var v := BaseVariable.new()
	var counts := {"changed": 0, "modified": 0}
	v.value_changed.connect(func(_a, _b): counts["changed"] += 1)
	v.value_modified.connect(func(_nv): counts["modified"] += 1)
	v.value = 42
	_check(counts["changed"] == 1, "value_changed emit %d 次（预期 1）" % counts["changed"])
	_check(counts["modified"] == 1, "value_modified emit %d 次（预期 1）" % counts["modified"])

func _test_set_value_emits_each_once() -> void:
	print("\n--- set_value 应恰好 emit value_changed 与 value_modified 各 1 次 ---")
	var v := BaseVariable.new()
	var counts := {"changed": 0, "modified": 0}
	v.value_changed.connect(func(_a, _b): counts["changed"] += 1)
	v.value_modified.connect(func(_nv): counts["modified"] += 1)
	v.set_value(99)
	_check(counts["changed"] == 1, "value_changed emit %d 次（预期 1）" % counts["changed"])
	_check(counts["modified"] == 1, "value_modified emit %d 次（预期 1）" % counts["modified"])

func _test_setter_increments_count_by_one() -> void:
	print("\n--- 直接赋值 modification_count +1 ---")
	var v := BaseVariable.new()
	var before := v.modification_count
	v.value = 1
	_check(v.modification_count == before + 1, "modification_count %d（预期 %d）" % [v.modification_count, before + 1])

func _test_set_value_increments_count_by_one() -> void:
	print("\n--- set_value modification_count +1（B3 当前 +2）---")
	var v := BaseVariable.new()
	var before := v.modification_count
	v.set_value(1)
	_check(v.modification_count == before + 1, "modification_count %d（预期 %d）" % [v.modification_count, before + 1])

func _test_clone_completeness() -> void:
	print("\n--- clone 应拷贝 scope/auto_create/creation_time（B9）---")
	var v := BaseVariable.new()
	v.scope = 1  # SCOPE
	v.auto_create = true
	var cloned: BaseVariable = v.clone()
	_check(cloned.scope == 1, "clone scope == 1（实际 %d）" % cloned.scope)
	_check(cloned.auto_create == true, "clone auto_create == true（实际 %s）" % cloned.auto_create)
