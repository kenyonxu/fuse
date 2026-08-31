# 文件：addons/fuse/editor/graduation/codegen/gdscript_emitter.gd
@tool
class_name GdscriptEmitter
extends RefCounted

## GDScript 发射器（M2 毕业导出器核心）
##
## 两级公开入口：
##   - emit_instruction(inst, indent)：白名单指令原生直译（单行/短块），
##     其余一切（含白名单内的不支持形态）降级为 FuseDelegation.run 委托行；
##   - emit_system(system, unit_node, scene_path)：System JSON + 源单元节点 →
##     完整生成脚本（头注释/委托数据块/门控复刻/事件接线/teardown）+ 覆盖率报告。
##
## LOCAL 连续性（终审 C1）：binding 指令树任一处读写 LOCAL 层变量（含嵌套子指令、
## 内嵌条件对象、SendEvent $var 引用）→ 整条 binding 全委托为单段 run——一个
## ExecutionContext 贯穿整条顶层序列，与源 Fuse 单 Trigger 单 ctx 语义一致；
## 无 LOCAL 用途的 binding 照常发射白名单原生行，连续委托指令合并为单段
## （背靠背同帧执行，缓解逐指令一段的摊帧）。原生发射器对 LOCAL 层变量操作
## 一律返回 "" 降级委托（_scope_literal 仅放行 global——原生行写 LOCAL 进的是
## 即抛的临时 ctx、读恒 miss 后回退 global 同名变量，均为静默错值）。
##
## 门控复刻：入口函数首行 busy 卫语句 + FuseDelegation.gate_*（trigger_once/cooldown
## 三值快照）。运行中重触发忽略（SKIP retrigger，trigger.gd:172-174）由 busy 卫语句
## 复刻——注意此前的"await 协程自然串行承担"论断不成立（终审 C2：协程仅串行化
## 单次调用内的段序列，并发调用各自启动新协程并行）。busy 置位 → await _body_ →
## 复位为直线序；body 收敛为独立函数使中途 return 不泄漏 busy（return 只结束 body
## 协程，await 正常完成）；GDScript 无 finally，body 内运行时异常中断协程的路径
## 接受不复位（终审备案）。RESTART 降级为 SKIP 并备案（T7）——busy 卫语句使
## "降级为 SKIP"在运行中重触发时真正兑现。
## 事件接线形态由 EventMapper 产出（四类白名单事件外整 System 拒生成）。

## 控制流指令的嵌套指令字段（与 SystemDeriver._SUB_INSTRUCTIONS 对齐）
const _SUB_INSTRUCTIONS := ["instructions", "true_instructions", "false_instructions",
	"else_instructions", "loop_instructions"]

const PresetValueCodec := preload("res://addons/fuse/core/serialization/preset_value_codec.gd")
const EventMapper := preload("res://addons/fuse/editor/graduation/codegen/event_mapper.gd")

const TAB := "\t"
const DELEGATION_PATH := "res://addons/fuse/core/graduation/fuse_delegation.gd"

## emit.native_instructions 为空时的默认白名单（controller ruling：
## 空数组 = 无覆盖偏好，用默认白名单；非空 = 覆盖偏好清单）
const DEFAULT_NATIVE_INSTRUCTIONS: Array[String] = [
	"Wait", "Print", "SendEvent", "SetVariable", "MathOperation",
	"ShowHideUI", "SetUIText", "SaveGlobalVariables", "LoadGlobalVariables",
]

## 原生发射器注册表（键 = 指令 class_name）；发射器返回 "" 表示该形态不支持 → 委托
static var _emitters_cache: Dictionary = {}


## 单指令 → 代码行/短块（不含尾换行）。
## @param inst: BaseInstruction - 指令对象
## @param indent: String - 行缩进（生成函数体内通常为 "\t"）
## @param delegated_key: String - 委托降级时 _DELEGATED 数据块键
## @param execution_mode: int - 委托 run 的执行模式（0=SEQUENTIAL/1=PARALLEL）
static func emit_instruction(inst: BaseInstruction, indent: String,
		delegated_key: String = "d", execution_mode: int = 0) -> String:
	if inst == null:
		return ""
	var emitter: Callable = _emitters().get(_class_of(inst), Callable())
	if emitter.is_valid():
		var line: String = emitter.call(inst, indent, delegated_key)
		if not line.is_empty():
			return line
	return _delegation_line(indent, delegated_key, execution_mode)


## System JSON + 源单元节点 → 完整生成脚本与报告。
## @param system: Dictionary - SystemDeriver 产物（spec §4.1 结构）
## @param unit_node: Node - 源单元场景节点（Trigger / MultiEventTrigger；Runner 拒）
## @param scene_path: String - 源场景 res:// 路径（头注释溯源）
## @return: Dictionary {
##   "script_text": String（拒生成时为空串），
##   "native_count": int, "delegated_names": Array[String],
##   "report": {system_name/unit/total_instructions/native_count/delegated_count/
##             delegated_names/skipped_disabled_bindings/errors}}
static func emit_system(system: Dictionary, unit_node: Node, scene_path: String) -> Dictionary:
	var report := {
		"system_name": str(system.get("name", "system")),
		"unit": _unit_info(system),
		"total_instructions": 0,
		"native_count": 0,
		"delegated_count": 0,
		"delegated_names": [] as Array[String],
		"skipped_disabled_bindings": [] as Array[String],
		"downgraded_restart_bindings": [] as Array[String],
		"local_delegated_bindings": [] as Array[String],
		"has_input_events": false,
		"check_any_input_bindings": [] as Array[String],
		"cond_cooldown_deviation_bindings": [] as Array[String],
		"errors": [] as Array[Dictionary],
	}
	var errors: Array = report["errors"]
	var bindings := _collect_bindings(unit_node, report)
	if errors.is_empty() and bindings.is_empty():
		errors.append({"code": "E_EVENT_UNSUPPORTED", "detail": "源单元无可导出的事件绑定"})
	if not errors.is_empty():
		return _rejected(report)

	var whitelist := _effective_whitelist(system)
	var delegated_json := {}
	var entry_funcs: Array[String] = []
	var busy_keys: Array[String] = []
	var const_lines: Array[String] = []
	var setup_lines: Array[String] = []
	var teardown_lines: Array[String] = []
	var wiring_blocks: Array[String] = []
	var input_branches: Array[String] = []

	for b: Dictionary in bindings:
		var mapped: Dictionary = EventMapper.map_event(b["event"], b["key"])
		if str(mapped.get("mode", "")) == "unsupported":
			errors.append({
				"code": "E_EVENT_UNSUPPORTED",
				"detail": "事件 %s：%s" % [str(b["key"]), str(mapped.get("error", ""))],
			})
			continue
		if not str(mapped.get("setup_code", "")).is_empty():
			setup_lines.append(str(mapped["setup_code"]))
		if not str(mapped.get("teardown_code", "")).is_empty():
			teardown_lines.append(str(mapped["teardown_code"]))
		if not str(mapped.get("wiring_code", "")).is_empty():
			wiring_blocks.append(str(mapped["wiring_code"]))
		if not str(mapped.get("input_branch", "")).is_empty():
			input_branches.append(str(mapped["input_branch"]))
		_collect_report_risks(b, mapped, report)
		entry_funcs.append(_emit_entry_function(b, whitelist, delegated_json, report))
		busy_keys.append(str(b["key"]))
		var cond_const := _emit_conditions_const(b)
		if not cond_const.is_empty():
			const_lines.append(cond_const)

	if not errors.is_empty():
		return _rejected(report)

	return {
		"script_text": _assemble(report, scene_path, delegated_json, const_lines,
			setup_lines, teardown_lines, entry_funcs, input_branches, wiring_blocks, busy_keys),
		"native_count": report["native_count"],
		"delegated_names": report["delegated_names"],
		"report": report,
	}


## report.md 风险行原料（终审 I3，由 export CLI 渲染）：
## - 输入事件（_unhandled_input 时序）；
## - OnInterval stop_condition 为 CheckAnyInput（即时探测语义未复刻）；
## - 条件 + 冷却并存的 binding（两阶段门控"条件失败不进冷却"与源 Fuse
##   _check_cooldown 检查即消耗的偏差，base_trigger.gd:138/153）。
static func _collect_report_risks(b: Dictionary, mapped: Dictionary, report: Dictionary) -> void:
	var key := str(b["key"])
	if str(mapped.get("mode", "")) == "input":
		report["has_input_events"] = true
	var params: Dictionary = mapped.get("params", {})
	if str(params.get("stop_condition_type", "")) == "CheckAnyInput":
		(report["check_any_input_bindings"] as Array).append(key)
	if _has_conditions(b) and int(b["cooldown_mode"]) != 0 and float(b["cooldown_time"]) > 0.0:
		(report["cond_cooldown_deviation_bindings"] as Array).append(key)


# ============================================================
# 绑定归集（L2 单绑定 u1 / L4 每 binding b<i> / L3 Runner 拒）
# ============================================================

## 节点形态 → 规范化绑定列表（key/event/action_runner/门控三值/conditions）
static func _collect_bindings(unit_node: Node, report: Dictionary) -> Array:
	if unit_node == null:
		(report["errors"] as Array).append({
			"code": "E_EVENT_UNSUPPORTED",
			"detail": "源单元节点为 null",
		})
		return []
	if unit_node is Runner:
		(report["errors"] as Array).append({
			"code": "E_EVENT_UNSUPPORTED",
			"detail": "L3 Runner 的 signal_binding 非四类白名单事件（MVP 拒生成）",
		})
		return []
	if "event_bindings" in unit_node:
		return _collect_l4_bindings(unit_node, report)
	if "event_definition" in unit_node:
		return [{
			"key": "u1",
			"event": unit_node.get("event_definition"),
			"action_runner": _get_action_runner(unit_node),
			"trigger_once": bool(unit_node.get("trigger_once")),
			"cooldown_mode": int(unit_node.get("cooldown_mode")),
			"cooldown_time": float(unit_node.get("cooldown_time")),
			"conditions": unit_node.get("conditions"),
		}]
	(report["errors"] as Array).append({
		"code": "E_EVENT_UNSUPPORTED",
		"detail": "未知单元形态（既非 Trigger 也非 MultiEventTrigger）：%s" % unit_node.get_class(),
	})
	return []


## L2 主 ActionRunner：先节点自身，无则回退 Runner 子节点（宿主实现细节：
## Trigger 的 Runner 子节点也是动作源——与 deriver/validator `_unit_action_runners`
## 的归集语义对齐，M3 收口：三处取动作源的口径一致，防 L2 漏发射）
static func _get_action_runner(node: Node) -> ActionRunner:
	var ar = node.get("action_runner")
	if ar == null:
		for child in node.get_children():
			if child is Runner and "action_runner" in child:
				ar = child.action_runner
				break
	return ar as ActionRunner


static func _collect_l4_bindings(unit_node: Node, report: Dictionary) -> Array:
	var out: Array = []
	var raw: Array = unit_node.get("event_bindings")
	for i: int in raw.size():
		var binding = raw[i]
		if binding == null:
			continue
		if not bool(binding.get("enabled")):
			(report["skipped_disabled_bindings"] as Array).append("b%d" % i)
			continue
		if int(binding.get("retrigger_policy")) == EventBinding.RetriggerPolicy.RESTART:
			# RESTART 降级为 SKIP（T7 ruling；M3 收口改中性备案）：生成器不重启
			# 进行中的执行协程（取消重启需桥暴露 runner 句柄，超出 MVP）。
			# 显著备案三处：report + 生成脚本头注释 + validator W_RESTART_DEGRADED。
			(report["downgraded_restart_bindings"] as Array).append("b%d" % i)
		var gate_once := bool(binding.get("trigger_once"))
		var event_obj = binding.get("event")
		if event_obj != null and event_obj is OnReceiveEvent:
			gate_once = gate_once or (event_obj as OnReceiveEvent).trigger_once
		out.append({
			"key": "b%d" % i,
			"event": event_obj,
			"action_runner": binding.get("action_runner"),
			"trigger_once": gate_once,
			"cooldown_mode": int(binding.get("cooldown_mode")),
			"cooldown_time": float(binding.get("cooldown_time")),
			"conditions": binding.get("conditions"),
		})
	return out


static func _effective_whitelist(system: Dictionary) -> Array:
	var override = system.get("emit", {}).get("native_instructions", [])
	if override == null or (override is Array and (override as Array).is_empty()):
		return DEFAULT_NATIVE_INSTRUCTIONS
	return override as Array


# ============================================================
# 入口函数（busy 卫语句 + 门控复刻 + 条件检查 + 独立 body 函数）
# ============================================================

## 入口 = busy 卫语句（复刻 trigger.gd:172-174 的 SKIP retrigger）+ 门控（两阶段
## 或合一）+ busy 置位 → await 独立 body 函数 → 复位。body 独立成函数使中途
## return（如 MathOperation 原生除零守卫）只结束 body 协程、await 照常完成，
## busy 必复位；body 内运行时异常中断协程的路径接受不复位（GDScript 无 finally）。
static func _emit_entry_function(b: Dictionary, whitelist: Array,
		delegated_json: Dictionary, report: Dictionary) -> String:
	var key := str(b["key"])
	var body := _emit_instruction_body(b, whitelist, delegated_json, report)
	var gate_args := '"%s", %s, %d, %s, get_instance_id()' \
		% [key, str(bool(b["trigger_once"])).to_lower(), int(b["cooldown_mode"]),
			_fmt_float(float(b["cooldown_time"]))]
	var lines: Array[String] = []
	lines.append("func _on_%s(event_args: Dictionary = {}) -> void:" % key)
	lines.append(TAB + "if _busy_%s:" % key)
	lines.append(TAB + TAB + "return")
	if _has_conditions(b):
		# 两阶段门控（对齐 Fuse"条件通过才消耗 trigger_once"，trigger.gd:216）：
		# gate_check 纯检查 → 条件（注入 event_args）→ gate_commit 写状态 → 执行
		lines.append(TAB + "if not FuseDelegation.gate_check(_gate, %s):" % gate_args)
		lines.append(TAB + TAB + "return")
		lines.append(TAB + "for _cond: Dictionary in _CONDITIONS_%s:" % key.to_upper())
		lines.append(TAB + TAB + "if not FuseDelegation.check_condition(self, _cond, event_args):")
		lines.append(TAB + TAB + TAB + "return")
		lines.append(TAB + "FuseDelegation.gate_commit(_gate, \"%s\", %d, %s, get_instance_id())" \
			% [key, int(b["cooldown_mode"]), _fmt_float(float(b["cooldown_time"]))])
	else:
		lines.append(TAB + "if not FuseDelegation.gate_allows(_gate, %s):" % gate_args)
		lines.append(TAB + TAB + "return")
	lines.append(TAB + "_busy_%s = true" % key)
	lines.append(TAB + "await _body_%s(event_args)" % key)
	lines.append(TAB + "_busy_%s = false" % key)
	lines.append("")
	lines.append("")
	lines.append("func _body_%s(event_args: Dictionary) -> void:" % key)
	lines.append(body)
	return "\n".join(lines)


## 指令序列 → body 体。
## LOCAL 用途 → 整条 binding 全委托单段（一个 ctx 贯穿，终审 C1）；
## 否则白名单原生行 + 连续委托指令合并段按原顺序交错（原生行切段，
## 段内多指令单 ctx 且背靠背同帧执行）。
static func _emit_instruction_body(b: Dictionary, whitelist: Array,
		delegated_json: Dictionary, report: Dictionary) -> String:
	var runner = b.get("action_runner")
	var instructions: Array = runner.get("instructions") if runner != null else []
	var mode := int(runner.get("execution_mode")) if runner != null else 0
	if instructions == null or instructions.is_empty():
		return TAB + "pass"
	if _uses_local_variables(instructions):
		return _emit_whole_delegated(b, instructions, mode, delegated_json, report)
	return _emit_mixed(b, whitelist, instructions, mode, delegated_json, report)


## 整条 binding 单段全委托：全部顶层指令序列化进一个数组、一段 run 执行——
## LOCAL 变量存于该段唯一 ctx，跨指令读写与源 Fuse 单 Trigger 单 ctx 语义一致。
## 嵌套指令随顶层指令的委托 JSON 整体重建（白名单原生指令无嵌套）。
static func _emit_whole_delegated(b: Dictionary, instructions: Array, mode: int,
		delegated_json: Dictionary, report: Dictionary) -> String:
	(report["local_delegated_bindings"] as Array).append(str(b["key"]))
	var all: Array = []
	for inst in instructions:
		if inst == null:
			continue
		report["total_instructions"] = int(report["total_instructions"]) + 1
		report["delegated_count"] = int(report["delegated_count"]) + 1
		(report["delegated_names"] as Array).append(_class_of(inst))
		all.append(PresetValueCodec.serialize_instruction(inst))
	if all.is_empty():
		return TAB + "pass"
	var key := "%s_d0" % str(b["key"])
	delegated_json[key] = all
	return _delegation_line(TAB, key, mode)


## 混合发射：先逐指令定原生/委托（两遍渲染避免 lambda 捕获语义），再把
## 连续委托指令合并为一段（中间夹原生行时切段——原生行经桥读写 global/scope
## 服务，跨段连续性仅 LOCAL 需要，而 LOCAL 用途已被整条委托路径接管）。
static func _emit_mixed(b: Dictionary, whitelist: Array, instructions: Array,
		mode: int, delegated_json: Dictionary, report: Dictionary) -> String:
	var bkey := str(b["key"])
	var items: Array = []  # [{native: String} | {delegated: Dictionary, cls: String}]
	var naming := 0  # 原生临时变量命名用槽位号（段键独立编号，互不冲突）
	for inst in instructions:
		if inst == null:
			continue
		report["total_instructions"] = int(report["total_instructions"]) + 1
		var cls := _class_of(inst)
		var line := ""
		if whitelist.has(cls):
			var emitter: Callable = _emitters().get(cls, Callable())
			if emitter.is_valid():
				line = str(emitter.call(inst, TAB, "%s_d%d" % [bkey, naming]))
		if line.is_empty():
			items.append({"delegated": PresetValueCodec.serialize_instruction(inst), "cls": cls})
		else:
			report["native_count"] = int(report["native_count"]) + 1
			items.append({"native": line})
		naming += 1

	var body_lines: Array[String] = []
	var seg := 0
	var idx := 0
	while idx < items.size():
		if (items[idx] as Dictionary).has("native"):
			body_lines.append(str((items[idx] as Dictionary)["native"]))
			idx += 1
			continue
		var seg_json: Array = []
		while idx < items.size() and not (items[idx] as Dictionary).has("native"):
			var item: Dictionary = items[idx]
			seg_json.append(item["delegated"])
			report["delegated_count"] = int(report["delegated_count"]) + 1
			(report["delegated_names"] as Array).append(str(item["cls"]))
			idx += 1
		var key := "%s_d%d" % [bkey, seg]
		seg += 1
		delegated_json[key] = seg_json
		body_lines.append(_delegation_line(TAB, key, mode))
	if body_lines.is_empty():
		return TAB + "pass"
	return "\n".join(body_lines)


static func _has_conditions(b: Dictionary) -> bool:
	var raw_conditions: Array = b.get("conditions") if b.get("conditions") != null else []
	for cond in raw_conditions:
		if cond != null:
			return true
	return false


# ============================================================
# LOCAL 用途探测（终审 C1 整条委托的判据）
# ============================================================

## binding 指令树是否读写 LOCAL 层变量：递归含嵌套子指令（控制流分支）与
## 内嵌条件对象（随 runner ctx 检查），另计 SendEvent $var 引用（$x 从 ctx
## local 层解析，send_event.gd _resolve_args）。
## 属性判定与 InstructionAnalyzer._extract_variables 的命名启发式**逐条对齐**
## （变量属性名模式、配对 scope 回退链、scope 属性缺失默认 LOCAL 的口径）——
## 修改 analyzer 对应逻辑时必须同步本三函数（同步义务同 validator 对 deriver）。
## 差异点（保守加严）：analyzer 对配对缺失且带 scope_source 的属性归 SCOPE，
## 本探测在此形态下若指令另有悬挂 LOCAL *_scope 属性（如 InstantiateScene 的
## target_variable ↔ save_to_scope 非链式配对）仍保守归 LOCAL——漏判 LOCAL 会
## 静默错值（终审 C1 的根因），过判仅多委托（controller ruling：覆盖率可降）。
static func _uses_local_variables(instructions: Array) -> bool:
	if instructions == null:
		return false
	for inst in instructions:
		if inst == null:
			continue
		if _obj_uses_local(inst):
			return true
		for sub_key in _SUB_INSTRUCTIONS:
			if sub_key in inst and _uses_local_variables(inst.get(sub_key)):
				return true
	return false


## 单个指令/条件对象是否有 LOCAL 层变量用途
static func _obj_uses_local(obj: Resource) -> bool:
	var has_unresolved := false
	for prop in obj.get_property_list():
		var pname: String = prop.get("name", "")
		if prop.get("type", 0) != TYPE_STRING or not _is_variable_prop(pname):
			continue
		var name_val: Variant = obj.get(pname)
		if name_val == null or str(name_val).is_empty():
			continue
		var raw_scope: Variant = _find_scope_prop(obj, pname)
		if raw_scope == null:
			if "scope_source" in obj:
				# analyzer 口径：scope_source 组件的变量归 SCOPE——先记下，
				# 由下方悬挂 LOCAL 保守网裁定（防链式配对覆盖不到的组件）
				has_unresolved = true
			else:
				return true  # 配对彻底缺失且无 scope_source：analyzer 口径默认 LOCAL
		elif int(raw_scope) == BaseVariable.VariableScope.LOCAL:
			return true
	if obj is SendEvent and _send_event_refs_local(obj as SendEvent):
		return true
	# 保守网：配对未解析的非空变量属性 + 指令上存在悬挂 LOCAL *_scope 属性
	# （链式配对覆盖不到的组件内配对，如实名 InstantiateScene save_to_scope）
	if has_unresolved and _has_dangling_local_scope(obj):
		return true
	# 控制流指令内嵌条件对象（IfThen.condition 等）：随 runner ctx 检查
	for prop in obj.get_property_list():
		var sub: Variant = obj.get(String(prop.get("name", "")))
		if sub is BaseCondition and _obj_uses_local(sub as Resource):
			return true
	return false


## 指令上是否存在值为 LOCAL 的 *_scope 后缀属性（悬挂网判据，不限配对）
static func _has_dangling_local_scope(obj: Resource) -> bool:
	for prop in obj.get_property_list():
		var pname: String = prop.get("name", "")
		if not pname.ends_with("_scope") or prop.get("type", 0) != TYPE_INT:
			continue
		var scope_val: Variant = obj.get(pname)
		if scope_val != null and int(scope_val) == BaseVariable.VariableScope.LOCAL:
			return true
	return false


## SendEvent 的 event_args 是否含 $var 引用（$x → ctx local 层）
static func _send_event_refs_local(s: SendEvent) -> bool:
	for key: Variant in s.event_args:
		var value: Variant = s.event_args[key]
		if value is String and (value as String).begins_with("$"):
			return true
	return false


## 变量属性 → 实际存在的配对 scope 属性值；回退链与 analyzer 一致
## （*_variable_scope → 去 _name 后缀 → 去 _variable 后缀）。**不含** analyzer 的
## scope_source 回退与 LOCAL 默认（那两层语义由调用方处置）；返回 null = 配对缺失
static func _find_scope_prop(obj: Resource, pname: String) -> Variant:
	var scope_val: Variant = obj.get(pname + "_scope")
	if scope_val == null and pname.ends_with("_name"):
		scope_val = obj.get(pname.substr(0, pname.length() - 5) + "_scope")
	if scope_val == null and pname.ends_with("_variable"):
		scope_val = obj.get(pname.substr(0, pname.length() - 9) + "_scope")
	return scope_val


## 变量属性名判定（与 InstructionAnalyzer._is_variable_prop 对齐）
static func _is_variable_prop(pname: String) -> bool:
	if pname.ends_with("_variable"):
		return true
	if pname.ends_with("_variable_name"):
		return true
	if pname == "variable_name":
		return true
	if pname == "compare_variable":
		return true
	if pname == "source_variable":
		return true
	return false


## binding 条件 → 常量声明（JSON 内嵌；与入口检查块配套）
static func _emit_conditions_const(b: Dictionary) -> String:
	if not _has_conditions(b):
		return ""
	var raw_conditions: Array = b.get("conditions")
	var json_items: Array = []
	for cond in raw_conditions:
		if cond != null:
			json_items.append(PresetValueCodec.serialize_condition(cond))
	if json_items.is_empty():
		return ""
	return "const _CONDITIONS_%s := %s" % [str(b["key"]).to_upper(), JSON.stringify(json_items)]


# ============================================================
# 脚本组装
# ============================================================

static func _assemble(report: Dictionary, scene_path: String, delegated_json: Dictionary,
		const_lines: Array, setup_lines: Array, teardown_lines: Array,
		entry_funcs: Array, input_branches: Array, wiring_blocks: Array,
		busy_keys: Array) -> String:
	var unit: Dictionary = report.get("unit", {})
	var total := int(report["total_instructions"])
	var native := int(report["native_count"])
	var pct := 100 if total == 0 else int(round(native * 100.0 / total))
	var delegated_names: Array = report["delegated_names"]
	var delegated_desc := "无" if delegated_names.is_empty() else ", ".join(delegated_names)

	var out := "# ============================================================\n"
	out += "# 由 Fuse 场景毕业导出器生成 — 委托数据块勿手工编辑\n"
	out += "# System: %s | 源单元: %s (%s) @ %s\n" % [
		report["system_name"], unit.get("node_path", "?"), unit.get("level", "?"), scene_path]
	out += "# 原生覆盖率: %d/%d (%d%%) | 委托: %s\n" % [native, total, pct, delegated_desc]
	out += "# 采用: 禁用源 Trigger 节点 → 本脚本挂到同路径节点 → 运行验证\n"
	out += "# 回滚: 恢复源 Trigger → 移除本脚本\n"
	var downgraded: Array = report.get("downgraded_restart_bindings", [])
	if not downgraded.is_empty():
		# 中性表述（M3 收口）：不断言"语义差异不可达"，只陈述降级事实 + 人工确认义务
		out += "# 降级备案: %s 该绑定生成时由 RESTART 降级为 SKIP（运行中重触发忽略\n" \
			% "、".join(PackedStringArray(downgraded))
		out += "#   而非重启；请人工确认重触发时上一轮执行已完成）\n"
	var local_all: Array = report.get("local_delegated_bindings", [])
	if not local_all.is_empty():
		# LOCAL 连续性（终审 C1）：这些 binding 因 LOCAL 变量用途整条委托单段
		out += "# LOCAL 连续性: %s 因 LOCAL 变量用途整条委托单段 run（一个 ctx 贯穿\n" \
			% "、".join(PackedStringArray(local_all))
		out += "#   整条顶层序列，LOCAL 变量跨指令读写与源 Fuse 一致）\n"
	out += "# ============================================================\n"
	out += "extends Node\n\n"
	out += 'const FuseDelegation := preload("%s")\n\n' % DELEGATION_PATH
	out += "# ---- 委托数据块（PresetValueCodec 重建为 BaseInstruction）----\n"
	out += "const _DELEGATED := %s\n" % JSON.stringify(delegated_json)
	for const_line: String in const_lines:
		out += "\n%s\n" % const_line
	out += "\nvar _delegated := {}\nvar _gate := {}\n"
	# busy 卫语句状态（每入口一个；SKIP retrigger 复刻，终审 C2）
	for busy_key: String in busy_keys:
		out += "var _busy_%s := false\n" % busy_key
	out += "\n"
	out += "func _ready() -> void:\n"
	out += TAB + "_delegated = FuseDelegation.build_delegated(_DELEGATED)\n"
	for setup: String in setup_lines:
		out += _indent_lines(setup)
	out += "\nfunc _exit_tree() -> void:\n"
	out += TAB + "FuseDelegation.teardown(self)\n"
	for teardown: String in teardown_lines:
		out += _indent_lines(teardown)
	for entry: String in entry_funcs:
		out += "\n\n%s\n" % entry
	if not input_branches.is_empty():
		out += "\n\nfunc _unhandled_input(event: InputEvent) -> void:\n"
		for branch: String in input_branches:
			out += "%s\n" % branch
	for wiring: String in wiring_blocks:
		out += "%s\n" % wiring
	return out


static func _rejected(report: Dictionary) -> Dictionary:
	return {
		"script_text": "",
		"native_count": 0,
		"delegated_names": [] as Array[String],
		"report": report,
	}


static func _unit_info(system: Dictionary) -> Dictionary:
	var units: Array = system.get("units", [])
	if units.is_empty():
		return {"node_path": "?", "level": "?"}
	var unit: Dictionary = units[0]
	return {"node_path": str(unit.get("node_path", "?")), "level": str(unit.get("level", "?"))}


## 多行片段逐行加 1 tab（mapper 产出的 setup/teardown 不带基础缩进）
static func _indent_lines(block: String) -> String:
	var lines := block.split("\n")
	var out := ""
	for i: int in lines.size():
		if i > 0:
			out += "\n"
		out += TAB + lines[i]
	return out + "\n"


# ============================================================
# 白名单原生发射器（返回 "" = 该形态不支持 → 委托）
# ============================================================

## 注册表：键 = 指令 class_name。发射器签名 (inst, indent, delegated_key) -> String
static func _emitters() -> Dictionary:
	if _emitters_cache.is_empty():
		_emitters_cache = {
			"Wait": _emit_wait,
			"Print": _emit_print,
			"SendEvent": _emit_send_event,
			"SetVariable": _emit_set_variable,
			"MathOperation": _emit_math_operation,
			"ShowHideUI": _emit_show_hide_ui,
			"SetUIText": _emit_set_ui_text,
			"SaveGlobalVariables": _emit_save_global_variables,
			"LoadGlobalVariables": _emit_load_global_variables,
		}
	return _emitters_cache


## Wait：仅 DIRECT 直设秒数原生；变量模式委托
static func _emit_wait(inst: BaseInstruction, indent: String, _key: String) -> String:
	var w := inst as Wait
	if w.value_source != Wait.ValueSource.DIRECT:
		return ""
	return "%sawait get_tree().create_timer(%s).timeout" % [indent, _fmt_float(w.wait_time)]


static func _emit_print(inst: BaseInstruction, indent: String, _key: String) -> String:
	return "%sprint(%s)" % [indent, _literal((inst as Print).message)]


## SendEvent：字面量参数原生；含 $variable 引用或 deferred 时委托（引用解析依赖 ctx）
static func _emit_send_event(inst: BaseInstruction, indent: String, _key: String) -> String:
	var s := inst as SendEvent
	if s.event_name.is_empty() or s.deferred:
		return ""
	for key: Variant in s.event_args:
		var value: Variant = s.event_args[key]
		if value is String and (value as String).begins_with("$"):
			return ""
	var args_literal := _literal(s.event_args)
	if args_literal.is_empty():
		return ""
	return '%sFuseDelegation.send_event("%s", %s)' % [indent, s.event_name, args_literal]


## SetVariable：仅字面量模式（set_with_another_variable == false）且
## new_value 可直译且目标作用域为 GLOBAL 时原生；其余委托（LOCAL 目标委托，
## 终审 C1——原生行写 LOCAL 进即抛的临时 ctx 必丢失）
static func _emit_set_variable(inst: BaseInstruction, indent: String, _key: String) -> String:
	var s := inst as SetVariable
	if s.set_with_another_variable or s.target_variable.is_empty():
		return ""
	var scope := _scope_literal(int(s.target_variable_scope))
	if scope.is_empty():
		return ""
	var value_literal := _literal(s.new_value)
	if value_literal.is_empty():
		return ""
	return '%sFuseDelegation.set_var(self, "%s", %s, "%s")' \
		% [indent, s.target_variable, value_literal, scope]


## MathOperation：操作数与写回的作用域均为 GLOBAL 时原生（LOCAL 委托——终审 C1，
## 原生读写 LOCAL 均错值；SCOPE 语义委托）
static func _emit_math_operation(inst: BaseInstruction, indent: String, key: String) -> String:
	var m := inst as MathOperation
	if m.save_to_variable.is_empty():
		return ""
	var save_scope := _scope_literal(int(m.save_to_scope))
	if save_scope.is_empty():
		return ""
	var a_expr := _operand_expr(m, true)
	var b_expr := _operand_expr(m, false)
	if a_expr.is_empty() or b_expr.is_empty():
		return ""
	var op := ""
	match m.operation_type:
		MathOperation.OperationType.ADD:
			op = "+"
		MathOperation.OperationType.SUBTRACT:
			op = "-"
		MathOperation.OperationType.MULTIPLY:
			op = "*"
		MathOperation.OperationType.DIVIDE:
			op = "/"
		MathOperation.OperationType.MODULO:
			op = "%"
		_:
			return ""
	var a_var := "_m_%s_a" % key
	var b_var := "_m_%s_b" % key
	var needs_zero_guard := op == "/" or op == "%"
	# MODULO 用 fmod（GDScript 4 的 % 仅支持 int，对齐 Fuse 原实现 fmod）
	var expr := "%s %s %s" % [a_var, op, b_var] if op != "%" else "fmod(%s, %s)" % [a_var, b_var]
	var lines := "%svar %s: float = %s\n" % [indent, a_var, a_expr]
	lines += "%svar %s: float = %s\n" % [indent, b_var, b_expr]
	if needs_zero_guard:
		# 除零对齐 Fuse RUNTIME_ERROR 中断语义：报错并 return（后续指令不再执行）
		lines += "%sif is_zero_approx(%s):\n" % [indent, b_var]
		lines += "%s%spush_error(\"[Graduation] MathOperation 除零：save_to=%s\")\n" \
			% [indent, TAB, m.save_to_variable]
		lines += "%s%sreturn\n" % [indent, TAB]
	lines += '%sFuseDelegation.set_var(self, "%s", %s, "%s")' \
		% [indent, m.save_to_variable, expr, save_scope]
	return lines


## 操作数表达式：VALUE → 字面量；VARIABLE → 桥读取（仅 GLOBAL，LOCAL/SCOPE 返回
## "" 使整条指令降级委托——终审 C1）
static func _operand_expr(m: MathOperation, is_a: bool) -> String:
	var source: int = int(m.operand_a_source if is_a else m.operand_b_source)
	var value_source_enum: int = MathOperation.OperandASource.VALUE if is_a \
		else MathOperation.OperandBSource.VALUE
	if source == value_source_enum:
		return _fmt_float(m.operand_a_value if is_a else m.operand_b_value)
	var variable: String = m.operand_a_variable if is_a else m.operand_b_variable
	if variable.is_empty():
		return ""
	var scope_str := _scope_literal(int(m.operand_a_scope if is_a else m.operand_b_scope))
	if scope_str.is_empty():
		return ""
	return 'FuseDelegation.get_var(self, "%s", "%s")' % [variable, scope_str]


## ShowHideUI：直接节点路径模式原生；变量目标模式委托
static func _emit_show_hide_ui(inst: BaseInstruction, indent: String, key: String) -> String:
	var s := inst as ShowHideUI
	if s.use_variable_for_target or s.target_node.is_empty():
		return ""
	var node_expr := '(get_node("%s") as Control)' % str(s.target_node)
	match s.action:
		ShowHideUI.Action.SHOW:
			return "%s%s.show()" % [indent, node_expr]
		ShowHideUI.Action.HIDE:
			return "%s%s.hide()" % [indent, node_expr]
		ShowHideUI.Action.TOGGLE:
			var ctrl := "_ui_%s" % key
			return "%svar %s: Control = %s\n%s%s.visible = not %s.visible" \
				% [indent, ctrl, node_expr, indent, ctrl, ctrl]
	return ""


## SetUIText：节点路径 + 字面量文本双直设时原生；任一变量模式委托
static func _emit_set_ui_text(inst: BaseInstruction, indent: String, _key: String) -> String:
	var s := inst as SetUIText
	if s.use_variable_for_target or s.use_variable or s.target_node.is_empty():
		return ""
	return '%s(get_node("%s") as Control).set("text", %s)' \
		% [indent, str(s.target_node), _literal(s.text)]


## SaveGlobalVariables：CUSTOM_PATH 模式原生；ASSISTANT_RESOURCE 路径运行时检测委托
static func _emit_save_global_variables(inst: BaseInstruction, indent: String, _key: String) -> String:
	var s := inst as SaveGlobalVariables
	if s.save_target != SaveGlobalVariables.SaveTarget.CUSTOM_PATH or s.custom_path.is_empty():
		return ""
	var call := "save_to_resource" if s.save_scope == SaveGlobalVariables.SaveScope.ALL \
		else "save_persistent_to_resource"
	return '%sGlobalVariableManager.get_instance().%s("%s")' % [indent, call, s.custom_path]


## LoadGlobalVariables：CUSTOM_PATH 模式原生；ASSISTANT_RESOURCE 委托
static func _emit_load_global_variables(inst: BaseInstruction, indent: String, _key: String) -> String:
	var l := inst as LoadGlobalVariables
	if l.load_source != LoadGlobalVariables.LoadSource.CUSTOM_PATH or l.custom_path.is_empty():
		return ""
	return '%sGlobalVariableManager.get_instance().load_from_resource("%s")' \
		% [indent, l.custom_path]


# ============================================================
# 字面量与工具
# ============================================================

## 委托执行行（生成代码内 await 桥 run）
static func _delegation_line(indent: String, delegated_key: String, execution_mode: int) -> String:
	return "%sawait FuseDelegation.run(self, _delegated[\"%s\"], %d, event_args)" \
		% [indent, delegated_key, execution_mode]


## Variant → GDScript 字面量；非 JSON 可化类型（Vector2 等）返回 ""（调用方降级委托）
static func _literal(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_INT:
			return str(value)
		TYPE_FLOAT:
			return _fmt_float(value)
		TYPE_STRING:
			return JSON.stringify(value)
		TYPE_ARRAY, TYPE_DICTIONARY:
			return JSON.stringify(value) if _is_jsonable(value) else ""
	return ""


## 值树是否全部由 JSON 可化基本类型构成（String/bool/int/float/null/Array/Dictionary）
static func _is_jsonable(value: Variant) -> bool:
	match typeof(value):
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_NIL:
			return true
		TYPE_ARRAY:
			for item: Variant in value:
				if not _is_jsonable(item):
					return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in value:
				if not _is_jsonable(key) or not _is_jsonable(value[key]):
					return false
			return true
	return false


## VariableScope 枚举 → 桥 scope 字面量。仅放行 global——LOCAL 返回 ""（终审 C1：
## 原生行写 LOCAL 进的是即抛的临时 ctx，读恒 miss 后回退 global 同名变量，均为
## 静默错值——LOCAL 变量操作一律委托）；SCOPE 同理返回 ""（完整 Fuse 路径委托）。
static func _scope_literal(scope: int) -> String:
	if scope == BaseVariable.VariableScope.GLOBAL:
		return "global"
	return ""


## float → 字面量（保证带小数点，避免推断为 int）
static func _fmt_float(value: float) -> String:
	var text := str(value)
	if "." not in text and "e" not in text.to_lower() and not text.contains("inf") \
			and not text.contains("nan"):
		text += ".0"
	return text


static func _class_of(inst: BaseInstruction) -> String:
	var script := inst.get_script() as GDScript
	if script != null and not script.get_global_name().is_empty():
		return script.get_global_name()
	return inst.get_class()
