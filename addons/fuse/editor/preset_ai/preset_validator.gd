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


# 安全取值：类型不符时给空值（入口判型层已产出 finding，这里保证直接调用也不崩溃）
static func _as_array(v: Variant) -> Array:
	return v if v is Array else []


static func _as_dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


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
	_validate_l3_l4_toplevel(data, findings)
	# 顶层判型防护：幻觉 JSON（action_runner 为字符串等）会让下游取值链/codec 崩溃，
	# 此层产出 finding 并决定 schema/codec 层是否可安全运行
	var types_ok := _validate_top_level_types(data, findings)
	if not findings.any(func(f): return f.code in ["E_PARSE"]):
		if types_ok:
			_validate_schema(data, findings)
			_validate_codec(data, findings)
	_validate_semantics(data, findings)
	return _report_for(src, findings)


# 顶层字段判型（spec §7：畸形输入不 crash）。
# 返回 false 表示存在类型异常，schema/codec 层跳过（语义层纯递归扫描可安全处理任意 JSON）。
static func _validate_top_level_types(data: Dictionary, findings: Array) -> bool:
	var level := _infer_level(data)
	if level in ["L1", "L2", "L3"]:
		var ar_v: Variant = data.get("action_runner", null)
		if ar_v != null and not (ar_v is Dictionary):
			findings.append(_finding("E_TYPE_MISMATCH", "error", "$.action_runner",
				"action_runner 应为对象，实际 %s" % type_string(typeof(ar_v))))
			return false
		if ar_v is Dictionary:
			var insts_v: Variant = ar_v.get("instructions", null)
			if insts_v != null and not (insts_v is Array):
				findings.append(_finding("E_TYPE_MISMATCH", "error", "$.action_runner.instructions",
					"instructions 应为数组，实际 %s" % type_string(typeof(insts_v))))
				return false
	elif level == "L4":
		var eb_v: Variant = data.get("event_bindings", null)
		if eb_v != null and not (eb_v is Array):
			findings.append(_finding("E_TYPE_MISMATCH", "error", "$.event_bindings",
				"event_bindings 应为数组，实际 %s" % type_string(typeof(eb_v))))
			return false
		if not (eb_v is Array):
			return false
		var ok := true
		for b in (eb_v as Array).size():
			var binding_v: Variant = (eb_v as Array)[b]
			if not (binding_v is Dictionary):
				findings.append(_finding("E_TYPE_MISMATCH", "error", "$.event_bindings[%d]" % b,
					"binding 应为对象，实际 %s" % type_string(typeof(binding_v))))
				ok = false
				continue
			var ar_v: Variant = (binding_v as Dictionary).get("action_runner", null)
			if ar_v == null:
				continue
			if not (ar_v is Dictionary):
				findings.append(_finding("E_TYPE_MISMATCH", "error",
					"$.event_bindings[%d].action_runner" % b,
					"action_runner 应为对象，实际 %s" % type_string(typeof(ar_v))))
				ok = false
				continue
			var insts_v: Variant = (ar_v as Dictionary).get("instructions", null)
			if insts_v != null and not (insts_v is Array):
				findings.append(_finding("E_TYPE_MISMATCH", "error",
					"$.event_bindings[%d].action_runner.instructions" % b,
					"instructions 应为数组，实际 %s" % type_string(typeof(insts_v))))
				ok = false
		return ok
	return true


static func validate_path(target: String, report_path := "") -> Dictionary:
	var files: Array[String] = []
	if DirAccess.dir_exists_absolute(target):
		_collect_json_files(target, files)
	elif FileAccess.file_exists(target):
		files.append(target)
	else:
		push_error("目标不存在: %s" % target)
		return {"files": [], "summary": {"total": 0, "passed": 0, "failed": 0}}
	files.sort()  # 目录递归时保证输出顺序稳定（跨平台 list_dir 顺序不保证）
	var reports: Array = []
	for f in files:
		reports.append(validate_preset(f))
	var failed := reports.filter(func(r): return r.errors > 0).size()
	var summary := {"total": reports.size(), "passed": reports.size() - failed, "failed": failed}
	if report_path != "":
		var out := FileAccess.open(report_path, FileAccess.WRITE)
		if out:
			out.store_string(JSON.stringify({"files": reports, "summary": summary}, "\t"))
			out.close()
		else:
			push_error("报告文件无法写入: %s" % report_path)
	return {"files": reports, "summary": summary}


# 递归收集目录下全部 .json（跳过 . 开头的隐藏目录/文件）
static func _collect_json_files(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with("."):
				_collect_json_files(full, out)
		elif name.ends_with(".json"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()


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


# L3/L4 顶层字段校验（spec §6.4「校验器规则同步」，2026-08-21 终审 I1 补齐）：
# L3 signal_binding.signal_name 非空字符串；L4 每个 binding 的 binding_config 四键类型。
# 基于推断 level（与其余各层一致）；畸形输入（signal_binding/binding 非 dict）由 _as_dict 归空跳过，
# 判型层（_validate_top_level_types）负责报顶层结构类型错，此处不重复。
static func _validate_l3_l4_toplevel(data: Dictionary, findings: Array) -> void:
	var level := _infer_level(data)
	if level == "L3":
		var sb: Variant = data.get("signal_binding", null)
		if not (sb is Dictionary):
			return  # 判型职责；缺失/类型错不在本函数范围
		var sn: Variant = (sb as Dictionary).get("signal_name", null)
		if sn == null or (sn is String and (sn as String).is_empty()):
			findings.append(_finding("E_SIGNAL_NAME_EMPTY", "error", "$.signal_binding.signal_name",
				"signal_binding.signal_name 必须为非空字符串（缺失或为空）"))
		elif not (sn is String):
			findings.append(_finding("E_TYPE_MISMATCH", "error", "$.signal_binding.signal_name",
				"signal_name 应为非空字符串，实际 %s" % type_string(typeof(sn))))
	elif level == "L4":
		var bindings := _as_array(data.get("event_bindings", []))
		for b in bindings.size():
			var binding := _as_dict(bindings[b])
			var bc: Variant = binding.get("binding_config", null)
			if bc == null:
				continue  # 可选字段：缺省用运行时默认
			if not (bc is Dictionary):
				findings.append(_finding("E_TYPE_MISMATCH", "error",
					"$.event_bindings[%d].binding_config" % b,
					"binding_config 应为对象，实际 %s" % type_string(typeof(bc))))
				continue
			var cfg: Dictionary = bc
			var path := "$.event_bindings[%d].binding_config" % b
			for bool_key in ["enabled", "trigger_once"]:
				if cfg.has(bool_key) and not (cfg[bool_key] is bool):
					findings.append(_finding("E_TYPE_MISMATCH", "error", path + "." + bool_key,
						"binding_config.%s 应为 bool，实际 %s" % [bool_key, type_string(typeof(cfg[bool_key]))]))
			if cfg.has("cooldown_mode"):
				var cm: Variant = cfg["cooldown_mode"]
				# CooldownMode { NONE=0, GLOBAL_COOLDOWN=1, PER_OBJECT_COOLDOWN=2 }；
				# JSON.parse_string 数字为 float，先归一化整值再判值域（与枚举层处理一致）
				if not ((cm is float or cm is int) and float(cm) == floor(float(cm)) and int(cm) in [0, 1, 2]):
					findings.append(_finding("E_ENUM_RANGE", "error", path + ".cooldown_mode",
						"cooldown_mode 应为 0-2（NONE/GLOBAL_COOLDOWN/PER_OBJECT_COOLDOWN），实际 %s" % str(cm)))
			if cfg.has("cooldown_time"):
				var ct: Variant = cfg["cooldown_time"]
				if not (ct is float or ct is int):
					findings.append(_finding("E_TYPE_MISMATCH", "error", path + ".cooldown_time",
						"cooldown_time 应为 float，实际 %s" % type_string(typeof(ct))))


# ---- 第 2 层：schema 比对 ----

static func _load_schemas() -> Dictionary:
	if _schemas_cache.is_empty():
		var text := FileAccess.get_file_as_string(SCHEMAS_PATH)
		var parsed: Variant = JSON.parse_string(text)
		_schemas_cache = parsed if parsed is Dictionary else {}
	return _schemas_cache


# 基类属性排除表（与 PresetValueCodec._BASE_PROPERTIES / SchemaExtractor._BASE_PROPS 同步维护）：
# 这些属性属于组件基类而非 preset 参数，序列化器与 schema dump 均不输出，
# 出现在 preset JSON 中即为幻觉键；_collect_dynamic_params 的豁免集同样必须排除，
# 否则 AI 产物的 "script"/"metadata"/"log_level" 等幻觉键会被静默放行
const _BASE_PARAM_EXCLUDES := [
	"log_level",
	"completion_timing",
	"execution_mode",
	"script",
	"resource_local_to_scene",
	"resource_name",
	"metadata",
]

# 组件动态参数收集（E_UNKNOWN_PARAM 的动态属性豁免）。
# schemas dump 基于默认状态实例；条件暴露的动态属性（如 MathOperation.operand_a_variable
# 仅 operand_a_source==VARIABLE 时经 _get_property_list 注册，InstantiateScene.pool_* 仅
# use_object_pool=true 时注册）不在其中，但组件真实拥有且序列化器会输出。
# 探测方式：先按本 JSON 的键值恢复组件状态（与源场景实例状态等价），
# 再收集带 STORAGE 的属性名——与 PresetValueCodec 的序列化输出条件完全一致
# （同样排除 _ 前缀属性与基类属性）。
# 注意同名属性会出现两批（引擎静态视图 + 脚本动态注册），任一批带 STORAGE 即可序列化。
static func _collect_dynamic_params(type_name: String, comp: Dictionary) -> Dictionary:
	var names := {}
	var script: GDScript = PresetValueCodecScript._resolve_script(type_name)
	if script == null:
		return names
	var inst: Variant = script.new()
	if not (inst is Object):
		return names
	for k in comp:
		if k == "type" or k.begins_with("_") or k in _BASE_PARAM_EXCLUDES:
			continue
		(inst as Object).set(k, PresetValueCodecScript.deserialize_value(inst, k, comp[k]))
	for prop in (inst as Object).get_property_list():
		var pname := String(prop.get("name", ""))
		if pname.begins_with("_") or pname in _BASE_PARAM_EXCLUDES:
			continue
		if (int(prop.get("usage", 0)) & PROPERTY_USAGE_STORAGE) != 0:
			names[pname] = true
	return names


static func _validate_schema(data: Dictionary, findings: Array) -> void:
	var level := _infer_level(data)
	if level in ["L1", "L2", "L3"]:
		var insts := _as_array(_as_dict(data.get("action_runner", {})).get("instructions", []))
		for i in insts.size():
			_validate_component(insts[i], "instruction", "$.action_runner.instructions[%d]" % i, findings)
	elif level == "L4":
		var bindings := _as_array(data.get("event_bindings", []))
		for b in bindings.size():
			var binding := _as_dict(bindings[b])
			var ar := _as_dict(binding.get("action_runner", {}))
			var b_insts := _as_array(ar.get("instructions", []))
			for i in b_insts.size():
				_validate_component(b_insts[i], "instruction",
					"$.event_bindings[%d].action_runner.instructions[%d]" % [b, i], findings)
			if binding.has("event"):
				_validate_component(binding["event"], "event", "$.event_bindings[%d].event" % b, findings)
			var conds := _as_array(binding.get("conditions", []))
			for c in conds.size():
				_validate_component(conds[c], "condition",
					"$.event_bindings[%d].conditions[%d]" % [b, c], findings)
	if level == "L2" and data.has("event"):
		_validate_component(data["event"], "event", "$.event", findings)
	if level == "L2" and data.has("conditions"):
		var l2_conds := _as_array(data["conditions"])
		for c in l2_conds.size():
			_validate_component(l2_conds[c], "condition", "$.conditions[%d]" % c, findings)


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
	# 懒探测：本组件按 JSON 状态恢复后可序列化、但 schema（默认状态快照）未收录的动态属性
	var dynamic_params: Variant = null
	for key in comp:
		if key == "type": continue
		var p: Variant = known.get(key, null)
		# 条件参数（带 requires）门控未满足 → 该状态下未注册，schema 静态收录无法反映，
		# 与"不在 schema"同样交动态复核实测裁决（schemas 收录条件参数后维持原状态感知检测）
		if p == null or (p.has("requires") and not _requirements_met(p["requires"], comp, known)):
			if dynamic_params == null:
				dynamic_params = _collect_dynamic_params(type_name, comp)
			if dynamic_params.has(key):
				if p == null:
					continue  # 不在 schema 但该状态下真实注册的动态属性，放行
			else:
				if p != null:
					# schema 收录的条件参数，但 requires 门控未满足且该状态下未注册
					findings.append(_finding("E_UNKNOWN_PARAM", "error", path + "." + key,
						"参数 '%s' 存在但 requires 门控未满足（当前状态下不注册）——调整门控参数或删除该键" % key))
				else:
					findings.append(_finding("E_UNKNOWN_PARAM", "error", path + "." + key,
						"组件 %s 无参数 '%s'（幻觉参数名）" % [type_name, key]))
				continue
		var pd: Dictionary = known[key]
		var hint: int = int(pd.get("hint", 0))
		# 仅 int 存储的枚举是封闭值域；String + ENUM（如 OnInputAction.target_input_action 的
		# InputMap 动态下拉、AudioServer bus 名单）是编辑器建议列表，随项目配置变化，
		# 运行时任意字符串合法 → 不做 E_ENUM_RANGE（2026-08-21 真实语料首跑裁定）
		if hint == 2 and String(pd.get("type_name", "")) == "int":  # PROPERTY_HINT_ENUM
			var allowed := {}
			var implicit_index := 0
			for pair in String(pd.get("hint_string", "")).split(","):
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
					"枚举参数 %s.%s 值 %s 不在 %s 中" % [type_name, key, str(comp[key]), pd.get("hint_string")]))
		else:
			_check_json_type(comp[key], pd, path + "." + key, type_name, findings)
		# 递归：嵌套指令
		if pd.get("is_nested_instructions", false) and comp[key] is Array:
			for i in comp[key].size():
				_validate_component(comp[key][i], "instruction", path + "." + key + "[%d]" % i, findings)
		# 递归：condition 字段（hint_string 为 BaseCondition 的 Object 参数）
		if String(pd.get("type_name", "")) == "Object" and String(pd.get("hint_string", "")) == "BaseCondition" and comp[key] is Dictionary:
			_validate_component(comp[key], "condition", path + "." + key, findings)
	# 缺参数提示（requires 感知：门控未满足的条件参数该状态下本就不注册，缺是正常的）
	var missing: Array[String] = []
	for p in params:
		var pname: String = p["name"]
		if comp.has(pname):
			continue
		if p.has("requires") and not _requirements_met(p["requires"], comp, known):
			continue  # 该状态下本就不注册，缺是正常的
		missing.append(pname)
	# 按组件聚合为单条（Task 3 降噪：一条指令缺 N 参数只出一条 finding；
	# message 格式为 CLI/报告消费方契约，勿改）
	if not missing.is_empty():
		findings.append(_finding("W_MISSING_PARAM", "warning", path,
			"缺少 %d 个参数（将用默认值）：%s" % [missing.size(), "、".join(missing)]))


## 条件参数的门控判定：requires 的每个门在 comp 实际值（缺省回退 schema 默认）下满足
static func _requirements_met(requires: Dictionary, comp: Dictionary, known: Dictionary) -> bool:
	for gate in requires:
		var actual: Variant = comp.get(gate, null)
		if actual == null and known.has(gate):
			actual = known[gate].get("default", null)
		if actual == null:
			return false
		if actual is float and actual == floor(actual):
			actual = int(actual)
		if int(actual) != int(requires[gate]):
			return false
	return true


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
		# Object 参数显式 null = 未设置（schema default 即 null，导出器规范输出 null，
		# codec 反序列化无损），不算类型错误（2026-08-21 真实语料首跑裁定，red_planet.json）
		"Object": ok = value is Dictionary or value is String or value == null
		_:
			if tn in _ENGINE_VALUE_TYPES:
				# 唯一规范形式是字符串（Task 5 实测裁定 + codec 方案 A 显式解析；
				# StringName 虽可隐式转换，统一按字符串放行，无需特判）
				if value is String: return
				findings.append(_finding("E_REPR_NONCANONICAL", "error", path,
					"引擎值类型参数 %s.%s 必须用字符串形式（如 \"(100.0, 0.0)\"），数组/字典形式无法导入"
					% [type_name, p.get("name", "")]))
				return
			return  # 未知类型名：放行，交给 codec 实测层
	if not ok:
		findings.append(_finding("E_TYPE_MISMATCH", "error", path,
			"参数 %s.%s 期望 %s，得到 %s" % [type_name, p.get("name", ""), tn, type_string(typeof(value))]))


# ---- 第 3 层：codec 实测 ----

# 用真实 codec 反序列化并比对指令数量，捕获「源 JSON 里有、对象里没有」的静默丢弃
static func _validate_codec(data: Dictionary, findings: Array) -> void:
	var level := _infer_level(data)
	if level in ["L1", "L2", "L3"]:
		var src := _as_array(_as_dict(data.get("action_runner", {})).get("instructions", []))
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
		var bindings := _as_array(data.get("event_bindings", []))
		for b in bindings.size():
			var binding := _as_dict(bindings[b])
			var ar_v: Variant = binding.get("action_runner", null)
			# action_runner 类型异常（幻觉 JSON）时跳过（判型层已产出 finding），避免反序列化调用被类型检查中断
			if ar_v != null and not (ar_v is Dictionary):
				continue
			var src := _as_array(_as_dict(ar_v).get("instructions", []))
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
		inst_arrays.append(_as_array(_as_dict(data.get("action_runner", {})).get("instructions", [])))
	elif level == "L4":
		for b_v in _as_array(data.get("event_bindings", [])):
			var ar_v: Variant = _as_dict(b_v).get("action_runner", null)
			if ar_v is Dictionary:
				inst_arrays.append(_as_array(ar_v.get("instructions", [])))
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
