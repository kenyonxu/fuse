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
