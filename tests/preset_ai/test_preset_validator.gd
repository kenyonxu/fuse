# tests/preset_ai/test_preset_validator.gd
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
	print("=== test_preset_validator: L3/L4 顶层字段（spec §6.4，终审 I1）===")
	_test_l3_signal_name_empty()
	_test_l3_signal_name_type_error()
	_test_l3_valid_no_false_positive()
	_test_l4_binding_config_enum_range()
	_test_l4_binding_config_type_mismatch()
	_test_l4_valid_no_false_positive()
	print("=== test_preset_validator: 畸形输入判型防护 ===")
	_test_malformed_action_runner()
	_test_malformed_event_bindings()
	print("=== test_preset_validator: schema 层 ===")
	_test_unknown_component()
	_test_unknown_param()
	_test_base_property_hallucination()
	_test_enum_range()
	_test_enum_implicit_index_ok()
	_test_enum_json_roundtrip()
	_test_type_mismatch()
	_test_missing_param_warning()
	_test_missing_param_requires_aware()
	_test_missing_param_aggregated()
	_test_unknown_param_message_distinction()
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
	print("=== test_preset_validator: 真实语料首跑裁定 ===")
	_test_string_enum_hint_not_range_checked()
	_test_object_param_null_ok()
	print("=== test_preset_validator: validate_path ===")
	_test_validate_path_single_file()
	_test_validate_path_dir_recursion()
	print("=== test_preset_validator: 真实样本断言（M1 收尾） ===")
	_test_real_samples()
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

# ---- L3/L4 顶层字段（spec §6.4 承诺、终审 I1 补齐）----

func _valid_l3() -> Dictionary:
	return {
		"format_version": "2.0", "level": "L3", "display_name": "t3",
		"variables": {"local": [], "scope": [], "global": []},
		"action_runner": {"execution_mode": 0, "instructions": []},
		"signal_binding": {"signal_name": "player_died"},
	}

func _valid_l4() -> Dictionary:
	return {
		"format_version": "2.0", "level": "L4", "display_name": "t4",
		"variables": {"local": [], "scope": [], "global": []},
		"event_bindings": [{
			"event": {"type": "OnReady", "delay_seconds": 0.0},
			"binding_config": {"enabled": true, "trigger_once": false,
				"cooldown_mode": 0, "cooldown_time": 1.0},
			"action_runner": {"execution_mode": 0, "instructions": []},
		}],
	}

func _test_l3_signal_name_empty() -> void:
	var d := _valid_l3()
	d["signal_binding"]["signal_name"] = ""
	var findings: Array = PresetValidator.validate_data(d).findings
	var hit: bool = findings.any(func(f):
		return f.code == "E_SIGNAL_NAME_EMPTY" and f.json_path == "$.signal_binding.signal_name")
	_check(hit, "L3 signal_name 空字符串 → E_SIGNAL_NAME_EMPTY（$.signal_binding.signal_name）")
	# 缺失同样视为空（spec：非空字符串）
	var d2 := _valid_l3()
	d2["signal_binding"].erase("signal_name")
	var codes: Array = PresetValidator.validate_data(d2).findings.map(func(f): return f.code)
	_check("E_SIGNAL_NAME_EMPTY" in codes, "L3 signal_name 缺失 → E_SIGNAL_NAME_EMPTY")

func _test_l3_signal_name_type_error() -> void:
	var d := _valid_l3()
	d["signal_binding"]["signal_name"] = 42
	var findings: Array = PresetValidator.validate_data(d).findings
	var hit: bool = findings.any(func(f):
		return f.code == "E_TYPE_MISMATCH" and f.json_path == "$.signal_binding.signal_name")
	_check(hit, "L3 signal_name 为数字 → E_TYPE_MISMATCH（$.signal_binding.signal_name）")

func _test_l3_valid_no_false_positive() -> void:
	var r := PresetValidator.validate_data(_valid_l3())
	_check(r.errors == 0, "合法 L3 无 error（实际 findings: %s）" % JSON.stringify(r.findings))

func _test_l4_binding_config_enum_range() -> void:
	var d := _valid_l4()
	d["event_bindings"][0]["binding_config"]["cooldown_mode"] = 99
	var findings: Array = PresetValidator.validate_data(d).findings
	var hit: bool = findings.any(func(f):
		return (f.code == "E_ENUM_RANGE"
			and f.json_path == "$.event_bindings[0].binding_config.cooldown_mode"))
	_check(hit, "L4 binding_config.cooldown_mode=99 越界 → E_ENUM_RANGE（$.event_bindings[0].binding_config.cooldown_mode）")
	# 0-2 全部合法（NONE/GLOBAL_COOLDOWN/PER_OBJECT_COOLDOWN）
	for v in [0, 1, 2]:
		var ok_d := _valid_l4()
		ok_d["event_bindings"][0]["binding_config"]["cooldown_mode"] = v
		var codes: Array = PresetValidator.validate_data(ok_d).findings.map(func(f): return f.code)
		_check("E_ENUM_RANGE" not in codes, "L4 cooldown_mode=%d（合法枚举）无 E_ENUM_RANGE" % v)

func _test_l4_binding_config_type_mismatch() -> void:
	var cases := {"enabled": "yes", "trigger_once": 1, "cooldown_time": "1.0"}
	for key in cases:
		var d := _valid_l4()
		d["event_bindings"][0]["binding_config"][key] = cases[key]
		var findings: Array = PresetValidator.validate_data(d).findings
		var hit: bool = findings.any(func(f):
			return (f.code == "E_TYPE_MISMATCH"
				and f.json_path == "$.event_bindings[0].binding_config." + key))
		_check(hit, "L4 binding_config.%s 类型错（%s）→ E_TYPE_MISMATCH" % [key, str(cases[key])])

func _test_l4_valid_no_false_positive() -> void:
	var r := PresetValidator.validate_data(_valid_l4())
	_check(r.errors == 0, "合法 L4 无 error（实际 findings: %s）" % JSON.stringify(r.findings))

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

func _test_base_property_hallucination() -> void:
	# _collect_dynamic_params 的豁免集必须与序列化器输出集一致：_ 前缀属性与
	# 基类属性（codec _BASE_PROPERTIES：log_level/metadata/script/resource_name 等）
	# 永不出现在合法 preset JSON 中，幻觉即报错（2026-08-21 动态复核豁免集审查修复）
	_check("E_UNKNOWN_PARAM" in _codes({"type": "Wait", "wait_time": 1.0, "log_level": 2}),
		"基类属性 log_level 幻觉键 → E_UNKNOWN_PARAM（动态复核不豁免）")
	_check("E_UNKNOWN_PARAM" in _codes({"type": "Wait", "wait_time": 1.0, "metadata": {"x": 1}}),
		"基类属性 metadata 幻觉键 → E_UNKNOWN_PARAM")
	_check("E_UNKNOWN_PARAM" in _codes({"type": "Wait", "wait_time": 1.0, "resource_name": "hack"}),
		"基类属性 resource_name 幻觉键 → E_UNKNOWN_PARAM")
	_check("E_UNKNOWN_PARAM" in _codes({"type": "Wait", "wait_time": 1.0,
			"script": "res://addons/fuse/core/base/base_instruction.gd"}),
		"基类属性 script 幻觉键 → E_UNKNOWN_PARAM（且不得触发脚本加载/替换）")

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

# requires 感知的缺参（Task 2：schemas 重 dump 后条件参数带 requires 门控）
func _test_missing_param_requires_aware() -> void:
	# operand_a_source=1（VARIABLE）时：operand_a_scope_source（门控满足）应报缺；
	# operand_b_variable（需 operand_b_source=1，本 JSON 缺省回退默认 0）门控未满足 → 不应报缺。
	# 注：operand_a_value 不带 requires——提取器纪律是仅正向门控标注
	# （默认状态注册的参数保持旧 dump 字节不变），反向门控（VARIABLE 态消失）不标注
	var inst := {"type": "MathOperation", "operation_type": 1, "operand_a_source": 1,
		"operand_a_variable": "hp", "operand_a_scope": 1}
	var findings: Array = PresetValidator.validate_data(_l1_with(inst)).findings
	var missing: Array = findings.filter(func(f): return f.code == "W_MISSING_PARAM")
	var names := []
	for f in missing:
		names.append(str(f.message))
	_check(missing.size() >= 1, "仍报缺参（operand_a_scope_source 等）")
	_check(not names.any(func(m): return m.contains("operand_b_variable")),
		"门控未满足的 operand_b_variable 不报缺")

# W_MISSING_PARAM 按组件聚合（Task 3：每组件单条，message 固定格式供 CLI/报告消费）
func _test_missing_param_aggregated() -> void:
	var findings: Array = PresetValidator.validate_data(_l1_with({"type": "Wait"})).findings
	var w: Array = findings.filter(func(f): return f.code == "W_MISSING_PARAM")
	_check(w.size() == 1, "缺参聚合为单条 finding（实际 %d）" % w.size())
	if w.size() == 1:
		_check(str(w[0].message).contains("、") and str(w[0].message).begins_with("缺少"),
			"聚合 message 列出参数名")

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

# ---- 真实语料首跑裁定（Task 6 Step 3，attack with_skill / red_planet 误报修复）----

func _test_string_enum_hint_not_range_checked() -> void:
	# OnInputAction.target_input_action 为 String 存储 + ENUM hint（InputMap 动态建议下拉，
	# hint_string 是 dump 时项目输入表快照），运行时任意字符串合法 → 不做 E_ENUM_RANGE
	var d := _valid_l1()
	d["level"] = "L2"
	d["event"] = {"type": "OnInputAction", "target_input_action": "attack", "trigger_mode": 0}
	d["trigger_config"] = {"trigger_once": false, "cooldown_mode": 0, "cooldown_time": 1.0}
	var codes: Array = PresetValidator.validate_data(d).findings.map(func(f): return f.code)
	_check("E_ENUM_RANGE" not in codes, "String 枚举建议列表不触发 E_ENUM_RANGE（attack 首跑裁定）")

func _test_object_param_null_ok() -> void:
	# OnInterval.stop_condition 的 schema default 即 null，导出器规范输出显式 null，
	# codec 反序列化无损 → 不算 E_TYPE_MISMATCH
	var d := _valid_l1()
	d["level"] = "L2"
	d["event"] = {"type": "OnInterval", "interval_seconds": 50.0, "stop_condition": null}
	d["trigger_config"] = {"trigger_once": false, "cooldown_mode": 0, "cooldown_time": 1.0}
	var codes: Array = PresetValidator.validate_data(d).findings.map(func(f): return f.code)
	_check("E_TYPE_MISMATCH" not in codes, "Object 参数显式 null → 无 E_TYPE_MISMATCH（red_planet 首跑裁定）")

# ---- 畸形输入判型防护（Task 6，spec §7 不 crash 要求）----

func _test_malformed_action_runner() -> void:
	var d := _valid_l1()
	d["action_runner"] = "跑起来"
	var r := PresetValidator.validate_data(d)
	var hit: bool = r.findings.any(func(f):
		return f.code == "E_TYPE_MISMATCH" and f.json_path == "$.action_runner")
	_check(hit and r.errors > 0, "action_runner 为字符串 → E_TYPE_MISMATCH（json_path $.action_runner，不崩溃）")

func _test_malformed_event_bindings() -> void:
	var d := _valid_l1()
	d["level"] = "L4"
	d["event_bindings"] = 42
	var r := PresetValidator.validate_data(d)
	var hit: bool = r.findings.any(func(f):
		return f.code == "E_TYPE_MISMATCH" and f.json_path == "$.event_bindings")
	_check(hit, "event_bindings 为数字 → E_TYPE_MISMATCH（json_path $.event_bindings，不崩溃）")

# ---- validate_path（Task 6：单文件 + 目录递归 + 报告）----

func _test_validate_path_single_file() -> void:
	var dir := _make_path_fixture()
	var r: Dictionary = PresetValidator.validate_path(dir + "/a.json")
	_check(r.summary.get("total", -1) == 1 and r.summary.get("passed", -1) == 1,
		"validate_path 单文件 → summary total=1 passed=1（实际: %s）" % JSON.stringify(r.summary))

func _test_validate_path_dir_recursion() -> void:
	var dir := _make_path_fixture()
	var report_path := dir + "/report.json"
	var r: Dictionary = PresetValidator.validate_path(dir, report_path)
	var paths: Array = r.files.map(func(f): return f.path)
	var no_noise: bool = not paths.any(func(p): return p.contains(".hidden") or not p.ends_with(".json") or p.ends_with("report.json"))
	_check(r.summary.get("total", -1) == 2 and r.summary.get("passed", -1) == 1 and r.summary.get("failed", -1) == 1,
		"目录递归 → total=2 passed=1 failed=1（实际: %s）" % JSON.stringify(r.summary))
	_check(no_noise, "隐藏目录与非 json 文件被跳过，报告文件不参与本轮校验")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(report_path))
	_check(saved is Dictionary and (saved as Dictionary).get("summary", {}).get("total", -1) == 2,
		"--report 落盘的 JSON 含 files + summary")

# user:// 下搭夹具：a.json（合法）/ sub/b.json（E_FORMAT_VERSION）/ .hidden/c.json（应跳过）/ readme.txt（应跳过）
# 先清场重建（上一轮落盘的 report.json 不能计入本轮递归收集）
func _make_path_fixture() -> String:
	var base := "user://test_validate_path"
	if DirAccess.dir_exists_absolute(base):
		_remove_dir_recursive(base)
	DirAccess.make_dir_recursive_absolute(base + "/sub")
	DirAccess.make_dir_recursive_absolute(base + "/.hidden")
	var bad := _valid_l1()
	bad["format_version"] = "1.0"
	var f := FileAccess.open(base + "/a.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_valid_l1()))
	f.close()
	f = FileAccess.open(base + "/sub/b.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(bad))
	f.close()
	f = FileAccess.open(base + "/.hidden/c.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_valid_l1()))
	f.close()
	f = FileAccess.open(base + "/readme.txt", FileAccess.WRITE)
	f.store_string("not json")
	f.close()
	return base


# Godot 4.7 的 DirAccess.remove_recursive 非静态，测试内自实现
func _remove_dir_recursive(dir_path: String) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	var names: Array[String] = []
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		names.append(n)
		n = d.get_next()
	d.list_dir_end()
	for name in names:
		var full := dir_path.path_join(name)
		if DirAccess.dir_exists_absolute(full):
			_remove_dir_recursive(full)
		else:
			DirAccess.remove_absolute(full)
	DirAccess.remove_absolute(dir_path)


# ---- 真实样本断言（Task 7，M1 收尾；M3 重导后翻转项见 Task 14）----

func _codes_of_file(path: String) -> Array:
	return PresetValidator.validate_preset(path).findings.map(func(f): return f.code)

func _test_real_samples() -> void:
	_check(PresetValidator.validate_preset("res://addons/fuse/presets/gameplay/red_planet.json").errors == 0,
		"red_planet.json 0 error")
	_check(PresetValidator.validate_preset("res://addons/fuse/presets/ui/hint_breath.json").errors == 0,
		"hint_breath.json 重导后 0 error（Task 14 翻转：E_SCENE_PRIVATE_REF 已消除）")
	_check(PresetValidator.validate_preset("res://addons/fuse/presets/gameplay/game_flow.json").errors == 0,
		"game_flow.json 重导后 0 error（Task 14 翻转：E_ROUNDTRIP_LOSS 已消除）")
	_check(PresetValidator.validate_preset("res://addons/fuse/presets/gameplay/spawn_enemy.json").errors == 0,
		"spawn_enemy.json 重导后 0 error（Task 14 翻转：E_ROUNDTRIP_LOSS 已消除）")
	_check(PresetValidator.validate_preset("res://fuse-preset-generator-workspace/iteration-1/attack-l2/without_skill/outputs/attack.json").errors == 0,
		"attack without_skill 0 error（Task 14 裁决 A 翻转：当年报的 E_UNKNOWN_PARAM 是 schema dump 缺条件注册属性的历史误报——MathOperation.operand_a_variable/operand_a_scope 真实存在，2026-08-21 动态复核修复；产物 JSON 未动。真幻觉覆盖见 patrol without 的 Wait.time_scope）")
	_check("E_UNKNOWN_PARAM" in _codes_of_file("res://fuse-preset-generator-workspace/iteration-1/patrol-l1/without_skill/outputs/patrol.json"),
		"patrol without_skill 报真幻觉参数 Wait.time_scope（产物 value_source=DIRECT，该状态下 time_scope 未注册；VARIABLE 状态下它是合法序列化参数）")
	_check("E_REPR_NONCANONICAL" in _codes_of_file("res://fuse-preset-generator-workspace/iteration-1/patrol-l1/with_skill/outputs/patrol_a_wait_b_wait.json"),
		"patrol with_skill 报 Vector2 数组形式")

func _test_unknown_param_message_distinction() -> void:
	# 门控未满足：time_scope 在 schema（requires value_source:1）但产物 value_source=0
	var gated: Array = PresetValidator.validate_data(_l1_with(
		{"type": "Wait", "wait_time": 1.0, "value_source": 0, "time_scope": 0})).findings
	var gated_msg := ""
	for f in gated:
		if f.code == "E_UNKNOWN_PARAM" and str(f.json_path).contains("time_scope"):
			gated_msg = str(f.message)
	_check(gated_msg.contains("门控未满足"), "门控未满足场景消息指向门控而非拼写")
	# 纯幻觉：不存在的参数名
	var halluc: Array = PresetValidator.validate_data(_l1_with(
		{"type": "Wait", "wait_time": 1.0, "totally_made_up": 1})).findings
	var halluc_msg := ""
	for f in halluc:
		if f.code == "E_UNKNOWN_PARAM" and str(f.json_path).contains("totally_made_up"):
			halluc_msg = str(f.message)
	_check(halluc_msg.contains("幻觉参数名"), "纯幻觉场景消息保持幻觉措辞")
