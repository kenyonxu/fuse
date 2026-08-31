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
## 门控复刻：入口函数首行 FuseDelegation.gate_allows（trigger_once/cooldown 三值快照），
## 运行中忽略（SKIP retrigger）由 await 协程自然串行承担；RESTART 首版拒生成。
## 事件接线形态由 EventMapper 产出（四类白名单事件外整 System 拒生成）。

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
		entry_funcs.append(_emit_entry_function(b, whitelist, delegated_json, report))
		var cond_const := _emit_conditions_const(b)
		if not cond_const.is_empty():
			const_lines.append(cond_const)

	if not errors.is_empty():
		return _rejected(report)

	return {
		"script_text": _assemble(report, scene_path, delegated_json, const_lines,
			setup_lines, teardown_lines, entry_funcs, input_branches, wiring_blocks),
		"native_count": report["native_count"],
		"delegated_names": report["delegated_names"],
		"report": report,
	}


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
			"action_runner": unit_node.get("action_runner"),
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
			(report["errors"] as Array).append({
				"code": "E_EVENT_UNSUPPORTED",
				"detail": "binding b%d：RESTART retrigger_policy 未支持（首版拒生成）" % i,
			})
			continue
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
# 入口函数（统一触发入口 + 门控复刻 + 条件检查 + 指令体）
# ============================================================

static func _emit_entry_function(b: Dictionary, whitelist: Array,
		delegated_json: Dictionary, report: Dictionary) -> String:
	var key := str(b["key"])
	var body := _emit_instruction_body(b, whitelist, delegated_json, report)
	var gate_args := '"%s", %s, %d, %s, get_instance_id()' \
		% [key, str(bool(b["trigger_once"])).to_lower(), int(b["cooldown_mode"]),
			_fmt_float(float(b["cooldown_time"]))]
	var lines: Array[String] = []
	lines.append("func _on_%s(event_args: Dictionary = {}) -> void:" % key)
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
	lines.append(body)
	return "\n".join(lines)


## 指令序列 → 入口体：白名单原生行与委托段按原顺序交错
static func _emit_instruction_body(b: Dictionary, whitelist: Array,
		delegated_json: Dictionary, report: Dictionary) -> String:
	var runner = b.get("action_runner")
	var instructions: Array = runner.get("instructions") if runner != null else []
	var mode := int(runner.get("execution_mode")) if runner != null else 0
	var body_lines: Array[String] = []
	var seq := 0
	for inst in instructions:
		if inst == null:
			continue
		report["total_instructions"] = int(report["total_instructions"]) + 1
		var cls := _class_of(inst)
		var delegated_key := "%s_d%d" % [str(b["key"]), seq]
		var line := ""
		if whitelist.has(cls):
			var emitter: Callable = _emitters().get(cls, Callable())
			if emitter.is_valid():
				line = str(emitter.call(inst, TAB, delegated_key))
		if line.is_empty():
			delegated_json[delegated_key] = [PresetValueCodec.serialize_instruction(inst)]
			line = _delegation_line(TAB, delegated_key, mode)
			report["delegated_count"] = int(report["delegated_count"]) + 1
			(report["delegated_names"] as Array).append(cls)
		else:
			report["native_count"] = int(report["native_count"]) + 1
		body_lines.append(line)
		seq += 1
	if body_lines.is_empty():
		return TAB + "pass"
	return "\n".join(body_lines)


static func _has_conditions(b: Dictionary) -> bool:
	var raw_conditions: Array = b.get("conditions") if b.get("conditions") != null else []
	for cond in raw_conditions:
		if cond != null:
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
		entry_funcs: Array, input_branches: Array, wiring_blocks: Array) -> String:
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
	out += "# ============================================================\n"
	out += "extends Node\n\n"
	out += 'const FuseDelegation := preload("%s")\n\n' % DELEGATION_PATH
	out += "# ---- 委托数据块（PresetValueCodec 重建为 BaseInstruction）----\n"
	out += "const _DELEGATED := %s\n" % JSON.stringify(delegated_json)
	for const_line: String in const_lines:
		out += "\n%s\n" % const_line
	out += "\nvar _delegated := {}\nvar _gate := {}\n\n"
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
## new_value 可直译且目标作用域为 LOCAL/GLOBAL 时原生；其余委托
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


## MathOperation：操作数与写回的作用域均为 LOCAL/GLOBAL 时原生（SCOPE 语义委托）
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


## 操作数表达式：VALUE → 字面量；VARIABLE → 桥读取（仅 LOCAL/GLOBAL）
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


## VariableScope 枚举 → 桥 scope 字符串；SCOPE 返回 ""（变量语义走 Fuse 完整路径更稳）
static func _scope_literal(scope: int) -> String:
	match scope:
		BaseVariable.VariableScope.LOCAL:
			return "local"
		BaseVariable.VariableScope.GLOBAL:
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
