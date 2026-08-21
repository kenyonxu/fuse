# addons/fuse/editor/preset_ai/preset_validator.gd
@tool
class_name PresetValidator
extends RefCounted

## Preset 离线校验器（spec §4）
## 四层：结构 → schema 比对 → codec 实测 → 语义
## 只读 JSON 与真实 codec，不修改任何文件。

const SCHEMAS_PATH := "res://addons/fuse/preset_ai_context/fuse_component_schemas.json"

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

static func _validate_schema(data: Dictionary, findings: Array) -> void:
	pass


static func _validate_codec(data: Dictionary, findings: Array) -> void:
	pass


static func _validate_semantics(data: Dictionary, findings: Array) -> void:
	pass
