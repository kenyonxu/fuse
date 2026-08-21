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

# 嵌套指令字段名（codec 实测层 / 语义层递归使用；schema 层走参数驱动递归，不依赖此表）
const _NESTED_FIELDS := ["instructions", "true_instructions", "false_instructions", "else_instructions", "loop_instructions"]

const PresetValueCodecScript := preload("res://addons/fuse/core/serialization/preset_value_codec.gd")
const FusePresetScript := preload("res://addons/fuse/core/resources/fuse_preset.gd")

# 写入变量的指令字段（以真实组件 schema 为准）：
# SetVariable.target_variable / getter 类指令 save_to_variable / ForEach 的 item_variable + index_variable
const _WRITE_VARIABLE_KEYS := ["target_variable", "save_to_variable", "item_variable", "index_variable"]

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
		_validate_schema(data, findings)
		_validate_codec(data, findings)
	_validate_semantics(data, findings)
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


# ---- 第 2 层：schema 比对 ----

static func _load_schemas() -> Dictionary:
	if _schemas_cache.is_empty():
		var text := FileAccess.get_file_as_string(SCHEMAS_PATH)
		var parsed: Variant = JSON.parse_string(text)
		_schemas_cache = parsed if parsed is Dictionary else {}
	return _schemas_cache


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
			var implicit_index := 0
			for pair in String(p.get("hint_string", "")).split(","):
				var kv := pair.split(":")
				if kv.size() == 2:
					# 带值对格式 "Name:Value" → 用显式值
					allowed[kv[1].strip_edges()] = true
				else:
					# 仅名称格式 "Name" → Godot 按出现顺序隐式索引（0 起）
					allowed[str(implicit_index)] = true
				implicit_index += 1
			# JSON.parse_string 把数字解析为 float（0 → 0.0，str() 为 "0.0"），比对前归一化整值 float 为 int 字符串
			var val_str := str(comp[key])
			if comp[key] is float and comp[key] == floor(comp[key]):
				val_str = str(int(comp[key]))
			if not allowed.has(val_str):
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
		"int": ok = (value is float or value is int) and float(value) == floor(float(value))
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


# ---- 第 3 层：codec 实测 ----

# 用真实 codec 反序列化并比对指令数量，捕获「源 JSON 里有、对象里没有」的静默丢弃
static func _validate_codec(data: Dictionary, findings: Array) -> void:
	var level := _infer_level(data)
	if level in ["L1", "L2", "L3"]:
		var src: Array = data.get("action_runner", {}).get("instructions", [])
		var preset := FusePresetScript.from_json(data.duplicate(true))
		var src_n := _count_instruction_dicts(src)
		var dst_n := _count_instruction_objects(preset.instructions)
		if src_n > dst_n:
			findings.append(_finding("E_ROUNDTRIP_LOSS", "error", "$.action_runner.instructions",
				"源 JSON 含 %d 条指令，反序列化仅剩 %d 条（静默丢弃）" % [src_n, dst_n]))
		_check_conditions_restore(src, "$.action_runner.instructions", findings)
		if level == "L2" and data.get("event", {}) is Dictionary and not (data["event"] as Dictionary).is_empty():
			if PresetValueCodecScript.deserialize_event(data["event"]) == null:
				findings.append(_finding("E_EVENT_NULL", "error", "$.event", "event 无法反序列化"))
	elif level == "L4":
		var bindings: Array = data.get("event_bindings", [])
		for b in bindings.size():
			var binding: Dictionary = bindings[b] if bindings[b] is Dictionary else {}
			var ar_v: Variant = binding.get("action_runner", null)
			# action_runner / event 类型异常（幻觉 JSON）时跳过，避免反序列化调用被类型检查中断
			if ar_v != null and not (ar_v is Dictionary):
				continue
			var ar: Dictionary = ar_v if ar_v is Dictionary else {}
			var src: Array = ar.get("instructions", [])
			var insts := PresetValueCodecScript.deserialize_instructions(src)
			if _count_instruction_dicts(src) > _count_instruction_objects(insts):
				findings.append(_finding("E_ROUNDTRIP_LOSS", "error",
					"$.event_bindings[%d].action_runner.instructions" % b, "L4 binding 指令静默丢弃"))
			_check_conditions_restore(src, "$.event_bindings[%d].action_runner.instructions" % b, findings)
			if binding.get("event", null) is Dictionary \
					and PresetValueCodecScript.deserialize_event(binding["event"]) == null:
				findings.append(_finding("E_EVENT_NULL", "error", "$.event_bindings[%d].event" % b,
					"L4 binding event 无法反序列化"))


# 统计源 JSON 指令数组中的条目数：dict 条目计数并递归嵌套字段；
# 非 dict 条目（字符串化的指令、null 等）反序列化必然被丢弃，同样计入以捕获丢失
static func _count_instruction_dicts(arr: Array) -> int:
	var n := 0
	for item in arr:
		n += 1
		if item is Dictionary:
			for field in _NESTED_FIELDS:
				if item.get(field, null) is Array:
					n += _count_instruction_dicts(item[field])
	return n


# 统计反序列化后对象树中实际保留的指令数（null 项 = 已被丢弃，不计）
static func _count_instruction_objects(insts: Array) -> int:
	var n := 0
	for inst in insts:
		if inst == null:
			continue
		n += 1
		for field in _NESTED_FIELDS:
			if field in inst:
				var sub: Variant = inst.get(field)
				if sub is Array:
					n += _count_instruction_objects(sub)
	return n


# 与 schema 层 condition 递归对齐：dict 形式的 condition 若反序列化为 null → E_CONDITION_NULL
static func _check_conditions_restore(arr: Array, base_path: String, findings: Array) -> void:
	for i in arr.size():
		var item: Variant = arr[i]
		if not (item is Dictionary) or not item.has("type"):
			continue
		for field in ["condition"]:
			var cond: Variant = item.get(field, null)
			if cond is Dictionary and cond.has("type"):
				if PresetValueCodecScript.deserialize_condition(cond) == null:
					findings.append(_finding("E_CONDITION_NULL", "error",
						"%s[%d].%s" % [base_path, i, field], "condition 无法反序列化"))
		for field in _NESTED_FIELDS:
			if item.get(field, null) is Array:
				_check_conditions_restore(item[field], "%s[%d].%s" % [base_path, i, field], findings)


# ---- 第 4 层：语义 ----
# W_NODEPATH_UNRESOLVED：离线无法验证目标节点存在性，格式层面任何字符串都是合法 NodePath；
# 该 code 保留给未来的节点感知模式，本层不实现。

static func _validate_semantics(data: Dictionary, findings: Array) -> void:
	_scan_private_refs(data, "$", findings)
	_scan_variable_declarations(data, findings)


# 递归扫描全部字符串值：场景私有资源引用 / 资源存在性
static func _scan_private_refs(value: Variant, path: String, findings: Array) -> void:
	if value is String:
		var s: String = value
		if s.contains("::Resource_"):
			findings.append(_finding("E_SCENE_PRIVATE_REF", "error", path,
				"场景私有资源引用离开源场景无意义: %s" % s.substr(0, 80)))
		elif (s.begins_with("res://") or s.begins_with("uid://")) and not s.contains("::"):
			if not ResourceLoader.exists(s):
				findings.append(_finding("E_RESOURCE_NOT_FOUND", "error", path, "资源不存在: %s" % s))
	elif value is Dictionary:
		for k in value:
			_scan_private_refs(value[k], path + "." + str(k), findings)
	elif value is Array:
		for i in value.size():
			_scan_private_refs(value[i], path + "[%d]" % i, findings)


# 收集 variables 中声明的变量名，再扫描所有指令的写变量字段
static func _scan_variable_declarations(data: Dictionary, findings: Array) -> void:
	var declared := {}
	var vars_v: Variant = data.get("variables", {})
	var vars: Dictionary = vars_v if vars_v is Dictionary else {}
	var local_arr: Array = vars.get("local", []) if vars.get("local", []) is Array else []
	var global_arr: Array = vars.get("global", []) if vars.get("global", []) is Array else []
	var scope_arr: Array = vars.get("scope", []) if vars.get("scope", []) is Array else []
	for n in local_arr:
		declared[n] = true
	for n in global_arr:
		declared[n] = true
	for e in scope_arr:
		if e is Dictionary:
			declared[e.get("name", "")] = true
	var level := _infer_level(data)
	var inst_arrays: Array = []
	if level in ["L1", "L2", "L3"]:
		inst_arrays.append(data.get("action_runner", {}).get("instructions", []))
	elif level == "L4":
		var bindings: Array = data.get("event_bindings", [])
		for b in bindings.size():
			var binding: Dictionary = bindings[b] if bindings[b] is Dictionary else {}
			var ar_v: Variant = binding.get("action_runner", null)
			if ar_v is Dictionary:
				var src: Array = (ar_v as Dictionary).get("instructions", [])
				inst_arrays.append(src)
	for arr in inst_arrays:
		_scan_writes(arr, declared, findings)


# 指令树中写变量但未声明 → W_VARIABLE_UNDECLARED（warning：运行时可能动态创建，不阻断）
static func _scan_writes(arr: Array, declared: Dictionary, findings: Array) -> void:
	for i in arr.size():
		var item: Variant = arr[i]
		if not (item is Dictionary) or not item.has("type"):
			continue
		for key in _WRITE_VARIABLE_KEYS:
			var n: Variant = item.get(key, null)
			if n is String and n != "" and not declared.has(n):
				findings.append(_finding("W_VARIABLE_UNDECLARED", "warning",
					"", "变量 '%s' 被写入但未在 variables 中声明" % n))
		for field in _NESTED_FIELDS:
			if item.get(field, null) is Array:
				_scan_writes(item[field], declared, findings)
