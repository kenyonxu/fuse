# 文件：addons/fuse/editor/graduation/system_validator.gd
@tool
class_name SystemValidator
extends RefCounted

## System 工件离线校验器（M1 毕业导出器，spec §5）
##
## 校验 System JSON（deriver 草稿整理后的定稿）能否进入生成阶段：
## 结构（版本）→ 单元落点（节点存在 / level 相符）→ 拓扑核对
## （externals 边界 / 竞态确认 / 嵌套与分量标注）→ emit 目标覆盖保护。
## 只读 JSON 与场景资源，不修改任何文件；结构对齐 preset_validator 四件套
## （_finding / validate_data / validate_system / validate_path）。
##
## codes（spec §5）：
##   E_FORMAT_VERSION / E_UNIT_NOT_FOUND / E_UNIT_LEVEL_MISMATCH /
##   E_EXTERNAL_UNRESOLVED / E_WARNING_NOT_ACKNOWLEDGED / E_EMIT_TARGET_CONFLICT /
##   W_SINGLETON_IN_COMPONENT / W_NESTED_UNIT
## 另有 info 级：I_CROSS_SCENE_EXTERNAL（跨场景依赖从宽提示）、
##   I_OVERWRITE_GENERATED（覆盖本导出器旧生成物）、I_NOT_SYSTEM（目录递归时跳过非 System JSON）
##
## 拓扑核对需实例化场景（同场景多 System 只 load 一次，缓存实例常驻到进程结束）；
## MVP 从宽：events_in 生产者仅在同场景拓扑内核对，跨场景依赖降为 info 不计 error。

## System JSON 格式版本（spec §4.1，与 SystemDeriver.FORMAT_VERSION 同步维护）
const FORMAT_VERSION := "1.0"

## 生成脚本头注释的溯源标记（与 M2 生成器骨架首部注释同步维护，spec §6.2）
const GENERATED_MARKER := "毕业导出器生成"

## 检查 output_script 头注释标记的行数窗口（spec §6.2 骨架标记在首部注释块内）
const _EMIT_HEAD_LINES := 5

## 参与连通分量计算的跨引用边类型（与 SystemDeriver._COMPONENT_EDGE_TYPES 同步维护）
const _COMPONENT_EDGE_TYPES := ["run", "variable_write_to_read", "variable_write_to_write"]

## 控制流指令的嵌套指令字段（与 SystemDeriver._SUB_INSTRUCTIONS 对齐）
const _SUB_INSTRUCTIONS := ["instructions", "true_instructions", "false_instructions", "else_instructions", "loop_instructions"]

## scene_path → 场景上下文（Dictionary）或 null（load 失败亦缓存，避免重复 IO）
static var _scene_contexts: Dictionary = {}


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

## 校验单个 System JSON 文件（对齐 preset_validator.validate_preset 的入口形态）
static func validate_system(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty() and not FileAccess.file_exists(path):
		return _report_for(path, [_finding("E_PARSE", "error", "$", "文件不存在")])
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		if parsed == null:
			return _report_for(path, [_finding("E_PARSE", "error", "$", "JSON 解析失败")])
		return _report_for(path, [_finding("I_NOT_SYSTEM", "info", "$", "合法 JSON 但顶层非对象，跳过")])
	var data: Dictionary = parsed
	if not data.has("format_version"):
		return _report_for(path, [_finding("I_NOT_SYSTEM", "info", "$", "无 format_version 字段，非 System JSON，跳过")])
	return validate_data(data, path)


static func validate_data(data: Dictionary, src := "<inline>") -> Dictionary:
	var findings: Array = []
	_validate_structure(data, findings)
	_validate_units(data, findings)
	_validate_emit(data, findings)
	return _report_for(src, findings)


## 校验文件或目录（递归收集 .json，跳过隐藏项）；report_path 非空时落盘 JSON 报告
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
		reports.append(validate_system(f))
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


# ---- 测试钩子：合成场景注入 ----

## 注入合成场景实例（测试用：无 .tscn 文件的内存构造场景）。
## inst 由调用方负责挂树与生命周期（find_children 需 in-tree）。
## 拓扑在首次消费时惰性定格（注入后仍可继续装配节点）
static func inject_scene_context(scene_path: String, inst: Node) -> void:
	_scene_contexts[scene_path] = inst


## 清空场景缓存（只断引用不 free——真实 load 的实例常驻场景树，注入实例归测试管理）
static func clear_scene_cache() -> void:
	_scene_contexts = {}


# ---- 第 1 层：结构 ----

static func _validate_structure(data: Dictionary, findings: Array) -> void:
	if str(data.get("format_version", "")) != FORMAT_VERSION:
		findings.append(_finding("E_FORMAT_VERSION", "error", "$.format_version",
			"format_version 必须为 \"%s\"，实际 %s" % [FORMAT_VERSION, str(data.get("format_version", "<缺失>"))]))
	var units_v: Variant = data.get("units", null)
	if not (units_v is Array) or (units_v as Array).is_empty():
		var detail := "空数组" if units_v is Array else type_string(typeof(units_v))
		findings.append(_finding("E_UNIT_NOT_FOUND", "error", "$.units",
			"units 缺失、非数组或为空（实际 %s）" % detail))


# ---- 第 2 层：单元落点 + 拓扑核对 ----

static func _validate_units(data: Dictionary, findings: Array) -> void:
	var units := _as_array(data.get("units", []))
	for i in units.size():
		var unit := _as_dict(units[i])
		var upath := "$.units[%d]" % i
		var scene_path: String = str(unit.get("scene", ""))
		var ctx: Variant = _scene_context(scene_path)
		if ctx == null:
			findings.append(_finding("E_UNIT_NOT_FOUND", "error", upath + ".scene",
				"场景无法加载: %s" % scene_path))
			continue
		var inst: Node = ctx["inst"]
		var node_path: String = str(unit.get("node_path", ""))
		# node_path 为空 = 单元即场景根本身（deriver 对根级单元产 ""）
		var node := inst if node_path.is_empty() else inst.get_node_or_null(NodePath(node_path))
		if node == null:
			findings.append(_finding("E_UNIT_NOT_FOUND", "error", upath + ".node_path",
				"node_path '%s' 在场景 %s 中解析不到节点" % [node_path, scene_path]))
			continue  # 级联防护：level/拓扑核对均依赖节点
		# level 与节点实取比对（非四类节点 detect 为空，跳过防误报）
		var declared: String = str(unit.get("level", ""))
		var actual_level: String = FusePresetSerializer.detect_level(node)
		if not actual_level.is_empty() and actual_level != declared:
			findings.append(_finding("E_UNIT_LEVEL_MISMATCH", "error", upath + ".level",
				"声明 %s 但节点实际层级 %s" % [declared, actual_level]))
		var unit_name: String = str(node.name)
		_check_nested(unit_name, ctx, upath, findings)
		_check_component_singleton(unit_name, ctx, upath, findings)
		_check_warnings_acknowledged(data, unit_name, ctx, upath, findings)
		_check_externals(data, unit_name, ctx, upath, findings)


# 嵌套单元（位于实例化子场景内）——生成目标与挂载点需人工确认，不阻断
static func _check_nested(unit_name: String, ctx: Dictionary, upath: String, findings: Array) -> void:
	var report := _as_dict((ctx["report_by_name"] as Dictionary).get(unit_name, {}))
	if report.get("is_nested", false):
		findings.append(_finding("W_NESTED_UNIT", "warning", upath + ".node_path",
			"单元 '%s' 位于实例化子场景内（生成目标与挂载点需人工确认）" % unit_name))


# 单例属多单元分量——当前将全量桥接，二期物化候选（对齐 deriver 的分量逻辑）
static func _check_component_singleton(unit_name: String, ctx: Dictionary, upath: String, findings: Array) -> void:
	var peers: Array = (ctx["components"] as Dictionary).get(unit_name, [])
	if not peers.is_empty():
		findings.append(_finding("W_SINGLETON_IN_COMPONENT", "warning", upath,
			"单元 '%s' 与 %s 同连通分量（二期物化候选，当前单例全量桥接）" % [unit_name, "、".join(peers)]))


# 竞态预警必须显式确认：实跑拓扑的 warning 边（from/to 含本单元）需在
# acknowledged_warnings 有对应条目（type/from/to/detail 四元组语义匹配）
static func _check_warnings_acknowledged(data: Dictionary, unit_name: String,
		ctx: Dictionary, upath: String, findings: Array) -> void:
	var acknowledged := _as_array(data.get("acknowledged_warnings", []))
	for ref: Dictionary in ctx["topology"]["cross_references"]:
		if not ref.get("warning", false):
			continue
		if unit_name != str(ref.get("from", "")) and unit_name != str(ref.get("to", "")):
			continue
		if not _warning_acknowledged(ref, acknowledged):
			findings.append(_finding("E_WARNING_NOT_ACKNOWLEDGED", "error",
				upath + "~acknowledged_warnings",
				"拓扑竞态预警未确认: %s（%s → %s，detail=%s）——补对应条目后方可生成"
				% [ref.get("type", ""), ref.get("from", ""), ref.get("to", ""), str(ref.get("detail", ""))]))


static func _warning_acknowledged(warning_ref: Dictionary, acknowledged: Array) -> bool:
	for ack_v in acknowledged:
		var ack := _as_dict(ack_v)
		if ack.get("type", "") == warning_ref.get("type", "") \
				and ack.get("from", "") == warning_ref.get("from", "") \
				and ack.get("to", "") == warning_ref.get("to", "") \
				and str(ack.get("detail", "")) == str(warning_ref.get("detail", "")):
			return true
	return false


# externals 边界核对（MVP 从宽，controller ruling）：
# - events_in 生产者仅在**同场景拓扑**内核对（其它单元 SendEvent 同名事件）；
#   声明场景内有生产者（outside_producers=false）却核对不到 → error；
#   声明外部生产（true）且场景内也无 → 跨场景依赖，降为 info 不计 error
# - variables 仅核对 scope 层变量名在拓扑 scope 名集中存在（global 天然全局、
#   local 物理单元内，从宽不核）
static func _check_externals(data: Dictionary, unit_name: String,
		ctx: Dictionary, upath: String, findings: Array) -> void:
	var sent_by_unit: Dictionary = ctx["sent_by_unit"]
	for e in _as_array(_as_dict(data.get("externals", {})).get("events_in", [])):
		var entry := _as_dict(e)
		var ev_name: String = str(entry.get("name", ""))
		if ev_name.is_empty():
			continue
		if _has_other_producer(sent_by_unit, unit_name, ev_name):
			continue
		if entry.get("outside_producers", true):
			findings.append(_finding("I_CROSS_SCENE_EXTERNAL", "info",
				upath + "~externals.events_in[%s]" % ev_name,
				"事件 '%s' 生产者在场景外（同场景拓扑无产出，跨场景依赖）" % ev_name))
		else:
			findings.append(_finding("E_EXTERNAL_UNRESOLVED", "error",
				upath + "~externals.events_in[%s]" % ev_name,
				"事件 '%s' 声明 outside_producers=false 但同场景拓扑无生产者" % ev_name))
	var scope_names: Dictionary = ctx["scope_names"]
	for v in _as_array(_as_dict(data.get("externals", {})).get("variables", [])):
		var entry := _as_dict(v)
		if str(entry.get("scope", "")) != "scope":
			continue
		var vname: String = str(entry.get("name", ""))
		if not vname.is_empty() and not scope_names.has(vname):
			findings.append(_finding("E_EXTERNAL_UNRESOLVED", "error",
				upath + "~externals.variables[%s]" % vname,
				"scope 变量 '%s' 在同场景拓扑中不存在" % vname))


## 是否存在**其它单元**（≠ unit_name）SendEvent 同名事件
static func _has_other_producer(sent_by_unit: Dictionary, unit_name: String, ev_name: String) -> bool:
	for other in sent_by_unit:
		if other == unit_name:
			continue
		if (sent_by_unit[other] as Array).has(ev_name):
			return true
	return false


# ---- 第 3 层：emit 目标覆盖保护 ----

static func _validate_emit(data: Dictionary, findings: Array) -> void:
	var emit := _as_dict(data.get("emit", {}))
	var path: String = str(emit.get("output_script", ""))
	if path.is_empty():
		findings.append(_finding("E_EMIT_TARGET_CONFLICT", "error", "$.emit.output_script",
			"emit.output_script 缺失或为空"))
		return
	if not FileAccess.file_exists(path):
		return  # 目标不存在 → 自由写入
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var marked := false
	var n := 0
	while n < _EMIT_HEAD_LINES and not f.eof_reached():
		if f.get_line().contains(GENERATED_MARKER):
			marked = true
			break
		n += 1
	f.close()
	if marked:
		findings.append(_finding("I_OVERWRITE_GENERATED", "info", "$.emit.output_script",
			"目标为本导出器旧生成物（头注释含标记），允许覆盖: %s" % path))
	else:
		findings.append(_finding("E_EMIT_TARGET_CONFLICT", "error", "$.emit.output_script",
			"目标文件已存在且非本导出器产物（覆盖保护）: %s" % path))


# ============================================================
# 场景上下文：load 缓存 + 拓扑汇总
# ============================================================

## 取场景上下文（缓存未命中则 load+实例化+挂树+汇总）。
## 值为 Dictionary 或 null（load 失败亦缓存，避免重复 IO）；
## 注入的合成实例（Node）在首次消费时构建并定格上下文
static func _scene_context(scene_path: String) -> Variant:
	if _scene_contexts.has(scene_path):
		var cached: Variant = _scene_contexts[scene_path]
		if cached is Dictionary:
			return cached
		if cached is Node:
			var built: Dictionary = _build_context(cached)
			_scene_contexts[scene_path] = built
			return built
		return null  # load 失败的缓存标记
	var ctx: Variant = null
	if ResourceLoader.exists(scene_path):
		var packed: Variant = load(scene_path)
		if packed is PackedScene:
			var inst: Node = (packed as PackedScene).instantiate()
			_attach_to_root(inst)
			ctx = _build_context(inst)
	_scene_contexts[scene_path] = ctx
	return ctx


## 实例挂到主场景树根下（find_children 需 in-tree；controller ruling 1）。
## 实例常驻到进程结束（缓存复用），不主动 free
static func _attach_to_root(inst: Node) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		tree.root.add_child(inst)
	# 无树环境（理论路径）不挂——拓扑核对可能失真，MVP 接受


## 汇总一个场景实例的拓扑核对原料（一次构建，多 System 复用）
static func _build_context(inst: Node) -> Dictionary:
	var topology: Dictionary = InstructionAnalyzer.build_topology(inst)
	var scope_names := {}
	var global_names := {}
	var report_by_name := {}
	for report: Dictionary in topology.triggers:
		var uname: String = report.get("trigger_name", "")
		report_by_name[uname] = report
		var merged := _merged_variable_names(report)
		for vname: String in merged["scope"]:
			scope_names[vname] = true
		for vname: String in merged["global"]:
			global_names[vname] = true
	var event_flow := _scene_event_flow(inst)
	return {
		"inst": inst,
		"topology": topology,
		"report_by_name": report_by_name,
		"scope_names": scope_names,
		"global_names": global_names,
		"sent_by_unit": event_flow["sent"],
		"received_by_unit": event_flow["received"],
		"components": _components(topology),
	}


## 全场景各单元（Trigger/MultiEventTrigger，含嵌套——find_children 递归）的
## SendEvent / OnReceiveEvent 名单。Runner 单元不计（MVP 从宽：核对面与
## deriver 的草稿面一致，宁可少报 error）
static func _scene_event_flow(scene_root: Node) -> Dictionary:
	var sent := {}
	var received := {}
	var units: Array[Node] = scene_root.find_children("*", "Trigger")
	units.append_array(scene_root.find_children("*", "MultiEventTrigger"))
	for node in units:
		var names_out: Array = []
		for ar in _unit_action_runners(node):
			_collect_send_event_names(ar.instructions, names_out)
		sent[str(node.name)] = names_out
		var names_in: Array = []
		_append_receive_event_name(node.get("event_definition"), names_in)
		var bindings = node.get("event_bindings")
		if bindings != null:
			for binding in bindings:
				if binding != null:
					_append_receive_event_name(binding.get("event"), names_in)
		received[str(node.name)] = names_in
	return {"sent": sent, "received": received}


# ============================================================
# 以下三段与 SystemDeriver 同构重实现（deriver 均为私有 static，未暴露公共面；
# 修改 deriver 对应逻辑时必须同步本文件——controller rulings 2/3 的同步义务）
# ============================================================

## 收集单元全部 ActionRunner（普通 Trigger 主 runner 含 Runner 子节点回退
## + MultiEventTrigger 的 event_bindings[].action_runner）
static func _unit_action_runners(node: Node) -> Array:
	var runners: Array = []
	if node == null:
		return runners
	var ar = node.get("action_runner")
	if ar == null:
		for child in node.get_children():
			if child is Runner and "action_runner" in child:
				ar = child.action_runner
				break
	if ar != null:
		runners.append(ar)
	var bindings = node.get("event_bindings")
	if bindings != null:
		for binding in bindings:
			if binding == null:
				continue
			var binding_ar = binding.get("action_runner")
			if binding_ar != null:
				runners.append(binding_ar)
	return runners


## 指令树（含嵌套字段）中的 SendEvent 事件名收集
static func _collect_send_event_names(instructions: Array, out_names: Array) -> void:
	if instructions == null:
		return
	for inst in instructions:
		if inst == null:
			continue
		if inst is SendEvent:
			var ev_name := str(inst.get("event_name"))
			if not ev_name.is_empty() and not (ev_name in out_names):
				out_names.append(ev_name)
		for sub_key in _SUB_INSTRUCTIONS:
			if sub_key in inst:
				_collect_send_event_names(inst.get(sub_key), out_names)


## OnReceiveEvent 事件名追加（event_definition / binding.event 通用）
static func _append_receive_event_name(event_def, names: Array) -> void:
	if event_def == null or not event_def is OnReceiveEvent:
		return
	var ev_name := str(event_def.get("event_name"))
	if not ev_name.is_empty() and not (ev_name in names):
		names.append(ev_name)


## trigger 级 + event_bindings 级三层变量名归并（有序去重）
static func _merged_variable_names(report: Dictionary) -> Dictionary:
	var layers := {"local": {}, "scope": {}, "global": {}}
	_merge_variable_layer(report.get("variables", {}), layers)
	for binding: Dictionary in report.get("event_bindings", []):
		_merge_variable_layer(binding.get("variables", {}), layers)
	var out := {}
	for layer in layers:
		out[layer] = layers[layer].keys()
	return out


static func _merge_variable_layer(variables: Dictionary, layers: Dictionary) -> void:
	for layer in layers:
		for entry: Dictionary in _as_array(variables.get(layer, [])):
			var vname: String = entry.get("name", "")
			if not vname.is_empty():
				layers[layer][vname] = true


## 连通分量（并查集）：run 边 + 变量边；signal 边不参与（spec §4.2 注记）。
## @return: {unit_name: [同分量其它单元名...]}
static func _components(topology: Dictionary) -> Dictionary:
	var parent := {}
	for report: Dictionary in topology.triggers:
		var unit: String = report.get("trigger_name", "")
		parent[unit] = unit
	for ref: Dictionary in topology.cross_references:
		var ref_type: String = ref.get("type", "")
		if not (ref_type in _COMPONENT_EDGE_TYPES):
			continue
		_union(parent, str(ref.get("from", "")), str(ref.get("to", "")))
	var result := {}
	for unit in parent:
		var root := _find(parent, unit)
		var peers: Array = []
		for other in parent:
			if other != unit and _find(parent, other) == root:
				peers.append(other)
		result[unit] = peers
	return result


static func _find(parent: Dictionary, x: String) -> String:
	var root := x
	while parent.get(root, root) != root:
		root = parent[root]
	var cur := x
	while parent.get(cur, cur) != root:
		var next: String = parent[cur]
		parent[cur] = root
		cur = next
	return root


static func _union(parent: Dictionary, a: String, b: String) -> void:
	if a.is_empty() or b.is_empty() or not parent.has(a) or not parent.has(b):
		return
	var ra := _find(parent, a)
	var rb := _find(parent, b)
	if ra != rb:
		parent[rb] = ra
