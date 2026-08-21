# addons/fuse/editor/preset_ai/preset_validator.gd
@tool
class_name PresetValidator
extends RefCounted

## Preset 离线校验器（spec §4）
## 四层：结构 → schema 比对 → codec 实测 → 语义
## 只读 JSON 与真实 codec，不修改任何文件。

const SCHEMAS_PATH := "res://addons/fuse/preset_ai_context/fuse_component_schemas.json"

const _ENGINE_VALUE_TYPES := ["Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4",
	"Color", "Rect2", "Rect2i", "Quaternion", "Transform2D", "Transform3D", "Basis",
	"AABB", "Plane", "Projection", "StringName"]

static var _schemas_cache: Dictionary = {}

static func _finding(code: String, severity: String, json_path: String, message: String) -> Dictionary:
	return {"code": code, "severity": severity, "json_path": json_path, "message": message}


static func _report_for(src: String, findings: Array) -> Dictionary:
	var errors := findings.filter(func(f): return f.severity == "error").size()
	var warnings := findings.filter(func(f): return f.severity == "warning").size()
	return {"path": src, "errors": errors, "warnings": warnings, "findings": findings}


# ---- 公共入口 ----

static func validate_preset(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty() and not FileAccess.file_exists(path):
		return _report_for(path, [_finding("E_PARSE", "error", "$", "文件不存在")])
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		if parsed == null:
			return _report_for(path, [_finding("E_PARSE", "error", "$", "JSON 解析失败")])
		return _report_for(path, [_finding("I_NOT_PRESET", "info", "$", "合法 JSON 但顶层非对象，跳过")])
	var data: Dictionary = parsed
	if not data.has("format_version"):
		return _report_for(path, [_finding("I_NOT_PRESET", "info", "$", "无 format_version 字段，非 preset JSON，跳过")])
	return validate_data(data, path)


static func validate_data(data: Dictionary, src: String = "<inline>") -> Dictionary:
	var findings: Array = []
	_validate_structure(data, findings)
	if not findings.any(func(f): return f.code in ["E_PARSE"]):
		_validate_schema(data, findings)      # Task 2-3 实现
		_validate_codec(data, findings)       # Task 3 实现
	_validate_semantics(data, findings)      # Task 4 实现
	return _report_for(src, findings)


static func validate_path(target: String) -> Dictionary:
	# Task 6 实现（目录递归）；本任务先支持单文件
	return {"files": [validate_preset(target)], "summary": {}}


# ---- 第 1 层：结构 ----

static func _infer_level(data: Dictionary) -> String:
	if data.has("event_bindings"): return "L4"
	if data.has("signal_binding"): return "L3"
	if data.has("event"): return "L2"
	if data.has("action_runner"): return "L1"
	return ""


static func _validate_structure(data: Dictionary, findings: Array) -> void:
	if str(data.get("format_version", "")) != "2.0":
		findings.append(_finding("E_FORMAT_VERSION", "error", "$.format_version",
			"format_version 必须为 \"2.0\"，实际 %s" % str(data.get("format_version", "<缺失>"))))
	var declared: String = str(data.get("level", ""))
	if declared not in ["L1", "L2", "L3", "L4"]:
		findings.append(_finding("E_LEVEL_UNKNOWN", "error", "$.level", "未知 level '%s'" % declared))
		return
	var inferred := _infer_level(data)
	if inferred != declared:
		findings.append(_finding("E_LEVEL_MISMATCH", "error", "$.level",
			"声明 %s 但字段集合推断为 %s" % [declared, inferred if inferred != "" else "<无法推断>"]))


# ---- 第 2/3/4 层占位（后续任务实现）----

static func _load_schemas() -> Dictionary:
	if _schemas_cache.is_empty():
		var text := FileAccess.get_file_as_string(SCHEMAS_PATH)
		var parsed: Variant = JSON.parse_string(text)
		_schemas_cache = parsed if parsed is Dictionary else {}
	return _schemas_cache


# ---- 第 2 层：schema 比对 ----

static func _validate_schema(data: Dictionary, findings: Array) -> void:
	var level := _infer_level(data)
	if level in ["L1", "L2", "L3"]:
		var insts: Array = data.get("action_runner", {}).get("instructions", [])
		for i in insts.size():
			_validate_component(insts[i], "instruction", "$.action_runner.instructions[%d]" % i, findings)
	elif level == "L4":
		var bindings: Array = data.get("event_bindings", [])
		for b in bindings.size():
			var binding: Dictionary = bindings[b] if bindings[b] is Dictionary else {}
			var ar: Dictionary = binding.get("action_runner", {})
			for i in ar.get("instructions", []).size():
				_validate_component(ar["instructions"][i], "instruction",
					"$.event_bindings[%d].action_runner.instructions[%d]" % [b, i], findings)
			if binding.has("event"):
				_validate_component(binding["event"], "event", "$.event_bindings[%d].event" % b, findings)
			for c in binding.get("conditions", []).size():
				_validate_component(binding["conditions"][c], "condition",
					"$.event_bindings[%d].conditions[%d]" % [b, c], findings)
	if level == "L2" and data.has("event"):
		_validate_component(data["event"], "event", "$.event", findings)


static func _validate_component(comp: Variant, kind: String, path: String, findings: Array) -> void:
	if not (comp is Dictionary):
		findings.append(_finding("E_TYPE_MISMATCH", "error", path, "应为对象，实际 %s" % typeof(comp)))
		return
	var type_name: String = str(comp.get("type", ""))
	var schemas := _load_schemas()
	if not schemas.has(type_name):
		findings.append(_finding("E_UNKNOWN_COMPONENT", "error", path + ".type",
			"未知 %s 组件 '%s'（不在 schemas dump 中）" % [kind, type_name]))
		return
	var params: Array = schemas[type_name]
	var known := {}
	for p in params:
		known[p["name"]] = p
	for key in comp:
		if key == "type": continue
		if not known.has(key):
			findings.append(_finding("E_UNKNOWN_PARAM", "error", path + "." + key,
				"组件 %s 无参数 '%s'（幻觉参数名）" % [type_name, key]))
			continue
		var p: Dictionary = known[key]
		var hint: int = int(p.get("hint", 0))
		if hint == 2:  # PROPERTY_HINT_ENUM
			var allowed := {}
			for pair in String(p.get("hint_string", "")).split(","):
				var kv := pair.split(":")
				if kv.size() == 2:
					allowed[kv[1].strip_edges()] = true
			if not allowed.has(str(comp[key])):
				findings.append(_finding("E_ENUM_RANGE", "error", path + "." + key,
					"枚举参数 %s.%s 值 %s 不在 %s 中" % [type_name, key, str(comp[key]), p.get("hint_string")]))
		else:
			_check_json_type(comp[key], p, path + "." + key, type_name, findings)
		# 递归：嵌套指令
		if p.get("is_nested_instructions", false) and comp[key] is Array:
			for i in comp[key].size():
				_validate_component(comp[key][i], "instruction", path + "." + key + "[%d]" % i, findings)
		# 递归：condition 字段（hint_string 为 BaseCondition 的 Object 参数）
		if String(p.get("type_name", "")) == "Object" and String(p.get("hint_string", "")) == "BaseCondition" and comp[key] is Dictionary:
			_validate_component(comp[key], "condition", path + "." + key, findings)
	# 缺参数提示
	for p in params:
		if not comp.has(p["name"]):
			findings.append(_finding("W_MISSING_PARAM", "warning", path,
				"缺少参数 %s.%s，将用默认值 %s" % [type_name, p["name"], str(p.get("default"))]))


static func _check_json_type(value: Variant, p: Dictionary, path: String, type_name: String, findings: Array) -> void:
	var tn: String = p.get("type_name", "")
	var ok := true
	match tn:
		"String": ok = value is String
		"int": ok = value is float and float(value) == floor(float(value))
		"float": ok = value is float
		"bool": ok = value is bool
		"NodePath": ok = value is String
		"Dictionary": ok = value is Dictionary
		"Array": ok = value is Array
		"Object": ok = value is Dictionary or value is String
		_:
			if tn in _ENGINE_VALUE_TYPES:
				if value is String: return  # 规范形式，Task 5 细化
				ok = false
			else:
				return  # 未知类型名：放行，交给 codec 实测层
	if not ok:
		findings.append(_finding("E_TYPE_MISMATCH", "error", path,
			"参数 %s.%s 期望 %s，得到 %s" % [type_name, p.get("name", ""), tn, type_string(typeof(value))]))


static func _validate_codec(data: Dictionary, findings: Array) -> void:
	pass


static func _validate_semantics(data: Dictionary, findings: Array) -> void:
	pass
