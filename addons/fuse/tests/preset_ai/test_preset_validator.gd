# addons/fuse/tests/preset_ai/test_preset_validator.gd
extends Node

const PresetValidator := preload("res://addons/fuse/editor/preset_ai/preset_validator.gd")

var _fail := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("✓ " + msg)
	else:
		_fail += 1
		push_error("✗ " + msg)

func _ready():
	print("=== test_preset_validator: 结构层 ===")
	_test_valid_l1()
	_test_parse_error()
	_test_format_version()
	_test_level_unknown()
	_test_level_mismatch()
	print("=== test_preset_validator: schema 层 ===")
	_test_unknown_component()
	_test_unknown_param()
	_test_enum_range()
	_test_enum_implicit_index_ok()
	_test_enum_json_roundtrip()
	_test_type_mismatch()
	_test_missing_param_warning()
	print("=== 结果: %d 失败 ===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _valid_l1() -> Dictionary:
	return {
		"format_version": "2.0",
		"level": "L1",
		"display_name": "t",
		"variables": {"local": [], "scope": [], "global": []},
		"action_runner": {"execution_mode": 0, "instructions": []},
	}

func _test_valid_l1() -> void:
	var r := PresetValidator.validate_data(_valid_l1())
	_check(r.errors == 0, "最小合法 L1 无 error（实际 findings: %s）" % JSON.stringify(r.findings))

func _test_parse_error() -> void:
	var r := PresetValidator.validate_data({"no_format_version": 1})
	var codes: Array = r.findings.map(func(f): return f.code)
	_check("E_FORMAT_VERSION" in codes, "缺 format_version → E_FORMAT_VERSION")

func _test_format_version() -> void:
	var d := _valid_l1()
	d["format_version"] = "1.0"
	var codes: Array = PresetValidator.validate_data(d).findings.map(func(f): return f.code)
	_check("E_FORMAT_VERSION" in codes, "format_version != 2.0 → E_FORMAT_VERSION")

func _test_level_unknown() -> void:
	var d := _valid_l1()
	d["level"] = "L9"
	var codes: Array = PresetValidator.validate_data(d).findings.map(func(f): return f.code)
	_check("E_LEVEL_UNKNOWN" in codes, "level=L9 → E_LEVEL_UNKNOWN")

func _test_level_mismatch() -> void:
	var d := _valid_l1()
	d["level"] = "L2"  # 声明 L2 但没有 event
	var codes: Array = PresetValidator.validate_data(d).findings.map(func(f): return f.code)
	_check("E_LEVEL_MISMATCH" in codes, "声明 L2 无 event → E_LEVEL_MISMATCH")

# ---- schema 层（Task 2）----

func _l1_with(inst: Dictionary) -> Dictionary:
	var d := _valid_l1()
	d["action_runner"]["instructions"] = [inst]
	return d

func _codes(inst: Dictionary) -> Array:
	return PresetValidator.validate_data(_l1_with(inst)).findings.map(func(f): return f.code)

func _test_unknown_component() -> void:
	_check("E_UNKNOWN_COMPONENT" in _codes({"type": "NotAComponent", "value": 1}),
		"未知组件 → E_UNKNOWN_COMPONENT")

func _test_unknown_param() -> void:
	_check("E_UNKNOWN_PARAM" in _codes({"type": "Wait", "wait_time": 1.0, "time_scope": 0}),
		"幻觉参数 time_scope → E_UNKNOWN_PARAM")

func _test_enum_range() -> void:
	# Wait.value_source 是枚举 Direct:0,Variable:1
	_check("E_ENUM_RANGE" in _codes({"type": "Wait", "wait_time": 1.0, "value_source": 7}),
		"枚举越界 → E_ENUM_RANGE")

func _test_enum_implicit_index_ok() -> void:
	# Wait.value_source 的 hint_string 为 "Direct,Variable"（无冒号 → 隐式索引 Direct=0, Variable=1）
	var codes: Array = _codes({"type": "Wait", "wait_time": 1.0, "value_source": 1})
	_check("E_ENUM_RANGE" not in codes, "无冒号枚举隐式索引：value_source=1（Variable）合法 → 无 E_ENUM_RANGE")

func _test_enum_json_roundtrip() -> void:
	# 真实 preset 文件经 JSON.parse_string 解析后数字均为 float（0 → 0.0，str() 为 "0.0"）
	var d := _l1_with({"type": "Wait", "wait_time": 1.0, "value_source": 1})
	var roundtrip: Variant = JSON.parse_string(JSON.stringify(d))
	var r := PresetValidator.validate_data(roundtrip)
	var codes: Array = r.findings.map(func(f): return f.code)
	_check("E_ENUM_RANGE" not in codes and r.errors == 0,
		"JSON 往返后枚举值 1.0 归一化为 1 → 无 E_ENUM_RANGE、无 error（实际: %s）" % JSON.stringify(r.findings))

func _test_type_mismatch() -> void:
	_check("E_TYPE_MISMATCH" in _codes({"type": "Wait", "wait_time": "1.0"}),
		"字符串赋给 float 参数 → E_TYPE_MISMATCH")

func _test_missing_param_warning() -> void:
	var r := PresetValidator.validate_data(_l1_with({"type": "Wait"}))
	var has_w: bool = r.findings.any(func(f): return f.code == "W_MISSING_PARAM")
	_check(has_w and r.errors == 0, "缺参数但有默认值 → 仅 W_MISSING_PARAM，无 error")
