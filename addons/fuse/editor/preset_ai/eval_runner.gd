# addons/fuse/editor/preset_ai/eval_runner.gd
@tool
class_name PresetEvalRunner
extends RefCounted

## Eval runner：回放评分 + baseline 门禁（spec §5）

const PresetValidator := preload("res://addons/fuse/editor/preset_ai/preset_validator.gd")
const _NESTED_FIELDS := ["instructions", "true_instructions", "false_instructions", "else_instructions", "loop_instructions"]

static func load_cases(workspace: String) -> Array[Dictionary]:
	var dir_path := workspace.path_join("evals/cases")
	var cases: Array[Dictionary] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("eval cases 目录不存在: %s" % dir_path)
		return cases
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".json"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(name)))
			if parsed is Dictionary:
				cases.append(parsed)
		name = dir.get_next()
	dir.list_dir_end()
	cases.sort_custom(func(a, b): return str(a.get("name", "")) < str(b.get("name", "")))
	return cases

static func check_assertions(case_data: Dictionary, preset_data: Dictionary) -> Dictionary:
	var details: Array[String] = []
	var passed := 0
	var total := 0
	for a in case_data.get("must_include", []):
		total += 1
		if _assertion_holds(a, preset_data):
			passed += 1
		else:
			details.append("未满足 must_include: %s" % JSON.stringify(a))
	for a in case_data.get("must_not_include", []):
		total += 1
		if not _assertion_holds(a, preset_data):
			passed += 1
		else:
			details.append("违反 must_not_include: %s" % JSON.stringify(a))
	for v in case_data.get("variables_required", []):
		total += 1
		var scope: String = v.get("scope", "")
		var bucket: Array = preset_data.get("variables", {}).get(scope, [])
		var hit := bucket.any(func(e): return (e if e is String else e.get("name", "")) == v.get("name", ""))
		if hit: passed += 1
		else: details.append("缺少变量声明: %s" % JSON.stringify(v))
	return {"passed": passed, "total": total, "details": details}

static func _assertion_holds(a: Dictionary, preset_data: Dictionary) -> bool:
	match String(a.get("kind", "")):
		"component":
			# _root_arrays 返回数组的数组，需逐个收集（直接整传会让 Array 条目被跳过）
			var found: Array = []
			for arr in _root_arrays(preset_data):
				_collect_types(arr, found)
			return found.has(a.get("type", ""))
		"event":
			if preset_data.get("event", {}) is Dictionary:
				if preset_data["event"].get("type", "") == a.get("type", ""): return true
			for b in preset_data.get("event_bindings", []):
				if b.get("event", {}).get("type", "") == a.get("type", ""): return true
			return false
		"param":
			for arr in _root_arrays(preset_data):
				if _has_param(arr, a.get("component", ""), a.get("key", "")): return true
			return false
	return false

static func _root_arrays(preset_data: Dictionary) -> Array:
	var arrays: Array = []
	var ar: Dictionary = preset_data.get("action_runner", {})
	if ar.get("instructions", null) is Array: arrays.append(ar["instructions"])
	for b in preset_data.get("event_bindings", []):
		var bar: Dictionary = b.get("action_runner", {})
		if bar.get("instructions", null) is Array: arrays.append(bar["instructions"])
	return arrays

static func _collect_types(arr: Array, out: Array) -> Array:
	for item in arr:
		if item is Dictionary and item.has("type"):
			out.append(item["type"])
			for field in _NESTED_FIELDS:
				if item.get(field, null) is Array:
					_collect_types(item[field], out)
	return out

static func _has_param(arr: Array, component: String, key: String) -> bool:
	for item in arr:
		if item is Dictionary and item.get("type", "") == component and item.has(key):
			return true
		if item is Dictionary:
			for field in _NESTED_FIELDS:
				if item.get(field, null) is Array and _has_param(item[field], component, key):
					return true
	return false
