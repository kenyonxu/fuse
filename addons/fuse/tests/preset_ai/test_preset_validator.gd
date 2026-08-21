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
	print("=== test_preset_validator: codec 实测层 ===")
	_test_roundtrip_loss()
	_test_event_null()
	_test_condition_null()
	print("=== test_preset_validator: 语义层 ===")
	_test_scene_private_ref()
	_test_variable_undeclared()
	print("=== test_preset_validator: 裁定实验 ===")
	_test_vector2_adjudication()
	_test_engine_value_color_roundtrip()
	_test_repr_noncanonical()
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

# ---- codec 实测层（Task 3）----

func _test_roundtrip_loss() -> void:
	var inst := {"type": "ForEach", "loop_instructions": ["等待 2.0 秒 (res://x.tscn::Resource_a):<Resource#1>"]}
	var codes := _codes(inst)
	_check("E_ROUNDTRIP_LOSS" in codes, "字符串化嵌套指令 → E_ROUNDTRIP_LOSS")

func _test_event_null() -> void:
	var d := _valid_l1()
	d["level"] = "L2"
	d["event"] = {"type": "NoSuchEvent"}
	d["trigger_config"] = {"trigger_once": false, "cooldown_mode": 0, "cooldown_time": 1.0}
	var codes: Array = PresetValidator.validate_data(d).findings.map(func(f): return f.code)
	_check("E_EVENT_NULL" in codes and "E_UNKNOWN_COMPONENT" in codes,
		"L2 event 未知类型 → E_EVENT_NULL + E_UNKNOWN_COMPONENT")

func _test_condition_null() -> void:
	var inst := {"type": "IfThen", "sequence_mode": 0,
		"condition": {"type": "NoSuchCondition"},
		"instructions": []}
	var codes := _codes(inst)
	_check("E_CONDITION_NULL" in codes and "E_UNKNOWN_COMPONENT" in codes,
		"condition inline dict 未知类型 → E_CONDITION_NULL + E_UNKNOWN_COMPONENT")

# ---- 语义层（Task 4）----

func _test_scene_private_ref() -> void:
	var inst := {"type": "OnInterval", "interval_seconds": 1.0,
		"stop_condition": "res://demos/x.tscn::Resource_fknqa"}
	var d := _valid_l1()
	d["level"] = "L2"
	d["event"] = inst
	d["trigger_config"] = {"trigger_once": false, "cooldown_mode": 0, "cooldown_time": 1.0}
	var findings: Array = PresetValidator.validate_data(d).findings
	_check(findings.any(func(f): return f.code == "E_SCENE_PRIVATE_REF"),
		"场景私有引用 → E_SCENE_PRIVATE_REF")

func _test_variable_undeclared() -> void:
	# SetVariable 真实参数名为 target_variable / new_value（brief 中的 variable_name/value 为幻觉名）
	var inst := {"type": "SetVariable", "target_variable": "score", "new_value": 1}
	var d := _valid_l1()
	d["action_runner"]["instructions"] = [inst]
	var findings: Array = PresetValidator.validate_data(d).findings
	_check(findings.any(func(f): return f.code == "W_VARIABLE_UNDECLARED"),
		"写未声明变量 → W_VARIABLE_UNDECLARED")

# ---- 裁定实验（Task 5）----

func _test_vector2_adjudication() -> void:
	var forms := {
		"string": "(100.0, 0.0)",
		"array": [100.0, 0.0],
		"dict": {"x": 100.0, "y": 0.0},
	}
	var results := {}
	for form in forms:
		var d := _valid_l1()
		d["action_runner"]["instructions"] = [
			{"type": "TweenMoveTo", "target_node": "..", "target_position": forms[form], "duration": 1.0}]
		var preset := PresetValidator.FusePresetScript.from_json(d)
		var tween: Variant = preset.instructions[0]
		results[form] = str(tween.get("target_position"))
	print("Vector2 裁定结果: ", JSON.stringify(results))
	# 断言（方案 A 修订后，controller b94ba41）：codec 显式解析字符串 → Vector2（唯一规范形式）；
	# Variant 隐式转换矩阵不含 String→Vector2 / Array→Vector2，数组/字典形式 set 静默失败、停留默认值
	# （Godot 4.7 实测，str 格式为 "(x.0, y.0)"）
	_check(results["string"] == "(100.0, 0.0)", "字符串形式可转（唯一规范形式，codec 方案 A）")
	_check(results["array"] == "(0.0, 0.0)", "数组形式不可转，属性停留默认值")
	_check(results["dict"] == "(0.0, 0.0)", "字典形式不可转，属性停留默认值")

func _test_engine_value_color_roundtrip() -> void:
	# 引擎值类型分支泛化证明：CameraFadeIn.color（Color 类型）字符串 → 显式解析导入
	var d := _valid_l1()
	d["action_runner"]["instructions"] = [
		{"type": "CameraFadeIn", "color": "(1.0, 0.5, 0.0, 1.0)"}]
	var preset := PresetValidator.FusePresetScript.from_json(d)
	var inst: Variant = preset.instructions[0]
	var got: Variant = inst.get("color")
	print("Color 泛化用例: ", str(got))
	_check(got is Color and got == Color(1, 0.5, 0, 1),
		"CameraFadeIn.color 字符串形式 → Color(1, 0.5, 0, 1)")

func _test_repr_noncanonical() -> void:
	var codes := _codes({"type": "TweenMoveTo", "target_node": "..",
		"target_position": [100.0, 0.0], "duration": 1.0})
	_check("E_REPR_NONCANONICAL" in codes, "Vector2 数组形式 → E_REPR_NONCANONICAL")
