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


# ---- 回放编排 + 报告（Task 9）----

# 回放一个 iteration 的全部产物：逐产物 validate + check_assertions，再对比 baseline。
# 返回 {"results": [...], "summary": {...}, "regressions": [...]}
# results 元素字段：{case, variant, path, errors, warnings, passed, total, pass, details, findings}
static func run_replay(workspace: String, iteration: String, report_dir := "") -> Dictionary:
	var results: Array = []
	for case_data in load_cases(workspace):
		for rel in case_data.get("outputs", {}).get(iteration, []):
			var full := workspace.path_join(iteration).path_join(rel)
			var entry := _evaluate_output(case_data, full, rel)
			results.append(entry)
	var regressions := _check_baseline(workspace, results)
	var summary := {
		"total": results.size(),
		"pass": results.filter(func(x): return x["pass"]).size(),
		"fail": results.filter(func(x): return not x["pass"]).size(),
		"regressions": regressions.size(),
	}
	if report_dir != "":
		_write_reports(report_dir, iteration, results, summary, regressions)
	return {"results": results, "summary": summary, "regressions": regressions}

# 单产物评分：validate 0 error 且断言全过才算过（产物本来就败但基线没要求过 → 只飘红不算回归）
static func _evaluate_output(case_data: Dictionary, full_path: String, rel_path: String) -> Dictionary:
	var variant := "unknown"
	var parts := rel_path.split("/")
	if parts.size() >= 3:
		variant = parts[parts.size() - 3]  # <case>/<variant>/outputs/x.json → 倒数第三段
	var validation: Dictionary = PresetValidator.validate_preset(full_path)
	var assertions := {"passed": 0, "total": 0, "details": []}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(full_path))
	if parsed is Dictionary:
		assertions = check_assertions(case_data, parsed)
	# pass 是 GDScript 保留字，变量用 is_pass（结果字典键仍为 "pass"，Task 10 依赖）
	var is_pass: bool = validation.errors == 0 and assertions.passed == assertions.total
	return {
		"case": case_data.get("name", ""), "variant": variant, "path": rel_path,
		"errors": validation.errors, "warnings": validation.warnings,
		"passed": assertions.passed, "total": assertions.total,
		"pass": is_pass, "details": assertions.details,
		"findings": validation.findings,
	}

# baseline 不存在 → 空数组（无回归可言；baseline 文件由 Task 10 生成）
static func _check_baseline(workspace: String, results: Array) -> Array:
	var path := workspace.path_join("eval_baseline.json")
	if not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return []
	var regressions: Array = []
	for r in results:
		var expected: Variant = parsed.get(r["case"], {}).get(r["path"], null)
		if expected is Dictionary and expected.get("pass", false) and not r["pass"]:
			regressions.append(r)
	return regressions

static func _write_reports(dir: String, iteration: String, results: Array, summary: Dictionary, regressions: Array) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("report.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"iteration": iteration, "results": results,
			"summary": summary, "regressions": regressions}, "\t"))
		f.close()
	var lines: Array[String] = []
	lines.append("# Eval report — %s" % iteration)
	lines.append("")
	lines.append("| case | variant | errors | warnings | assertions | pass |")
	lines.append("|------|---------|--------|----------|------------|------|")
	for r in results:
		lines.append("| %s | %s | %d | %d | %d/%d | %s |" % [r["case"], r["variant"],
			r["errors"], r["warnings"], r["passed"], r["total"], "✅" if r["pass"] else "❌"])
	lines.append("")
	lines.append("regressions: %d" % regressions.size())
	var m := FileAccess.open(dir.path_join("report.md"), FileAccess.WRITE)
	if m:
		m.store_string("\n".join(lines))
		m.close()

# ---- live 模式（Task 12，experimental）----

# system prompt 素材：skill 文档 + 上下文清单（与 fuse-preset-generator skill 一致）
const _PROMPT_FILES := [
	"res://.claude/skills/fuse-preset-generator/SKILL.md",
	"res://addons/fuse/preset_ai_context/preset_structure_cheatsheet.md",
	"res://addons/fuse/preset_ai_context/skill_workflow_brief.md",
	"res://addons/fuse/preset_ai_context/fuse_components.json",
	"res://addons/fuse/preset_ai_context/fuse_component_schemas.json",
	"res://addons/fuse/preset_ai_context/fuse_enums.json",
]

# live 真实生成（OpenAI 兼容 /chat/completions，experimental）：
# 逐 case 调 API 生成 preset → 落盘 <workspace>/<iteration>/<case>/live/outputs/<case>.json → 评分。
# 配置来自 FUSE_EVAL_API_BASE / FUSE_EVAL_API_KEY / FUSE_EVAL_MODEL 三个环境变量，缺一即优雅失败。
# live 结果不参与 baseline 门禁（regressions 恒空）。
static func run_live(workspace: String, iteration: String, report_dir := "") -> Dictionary:
	var base := OS.get_environment("FUSE_EVAL_API_BASE")
	var key := OS.get_environment("FUSE_EVAL_API_KEY")
	var model := OS.get_environment("FUSE_EVAL_MODEL")
	if base == "" or key == "" or model == "":
		push_error("live 模式需要 FUSE_EVAL_API_BASE / FUSE_EVAL_API_KEY / FUSE_EVAL_MODEL 环境变量")
		return {"results": [], "summary": {"total": 0, "pass": 0, "fail": 0, "regressions": 0}, "regressions": []}
	var system_prompt := ""
	for p in _PROMPT_FILES:
		var chunk := FileAccess.get_file_as_string(p)
		if chunk == "":
			push_warning("live system prompt 素材读取为空: %s" % p)
		system_prompt += chunk + "\n\n"
	var results: Array = []
	for case_data in load_cases(workspace):
		var case_name := str(case_data.get("name", ""))
		var http := HTTPRequest.new()
		http.timeout = 120
		Engine.get_main_loop().root.add_child(http)
		var body := JSON.stringify({
			"model": model,
			"messages": [
				{"role": "system", "content": system_prompt},
				{"role": "user", "content": str(case_data.get("prompt", ""))},
			],
			"temperature": 0.2,
		})
		var headers := PackedStringArray(["Content-Type: application/json",
			"Authorization: Bearer " + key])
		# request() 立即失败（如 URL 非法）时不会发 request_completed，直接走失败分支避免永久挂起
		var response: Array = []
		if http.request(base.trim_suffix("/") + "/chat/completions", headers, HTTPClient.METHOD_POST, body) == OK:
			response = await http.request_completed
		http.queue_free()
		var variant_dir := workspace.path_join(iteration).path_join(case_name).path_join("live/outputs")
		DirAccess.make_dir_recursive_absolute(variant_dir)
		var out_path := variant_dir.path_join(case_name + ".json")
		var parsed_preset: Variant = null
		if response.size() == 4 and response[1] == 200:
			var resp: Variant = JSON.parse_string(response[3].get_string_from_utf8())
			if resp is Dictionary:
				var choices: Array = resp.get("choices", [])
				if choices.size() > 0 and choices[0] is Dictionary:
					var content := str(choices[0].get("message", {}).get("content", ""))
					var start := content.find("{")
					var end := content.rfind("}")
					if start >= 0 and end > start:
						parsed_preset = JSON.parse_string(content.substr(start, end - start + 1))
		if parsed_preset is Dictionary:
			var f := FileAccess.open(out_path, FileAccess.WRITE)
			if f:
				f.store_string(JSON.stringify(parsed_preset, "\t"))
				f.close()
			results.append(_evaluate_output(case_data, out_path,
				case_name + "/live/outputs/" + out_path.get_file()))
		else:
			results.append({"case": case_data.get("name", ""), "variant": "live",
				"path": out_path, "errors": -1, "warnings": 0, "passed": 0, "total": 0,
				"pass": false, "details": ["live 生成/解析失败"], "findings": []})
	var summary := {"total": results.size(),
		"pass": results.filter(func(x): return x["pass"]).size(),
		"fail": results.filter(func(x): return not x["pass"]).size(),
		"regressions": 0}
	if report_dir != "":
		_write_reports(report_dir, iteration, results, summary, [])
	return {"results": results, "summary": summary, "regressions": []}
