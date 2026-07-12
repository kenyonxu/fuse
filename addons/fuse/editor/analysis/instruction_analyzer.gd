# 文件：addons/fuse/editor/analysis/instruction_analyzer.gd
@tool
class_name InstructionAnalyzer
extends RefCounted

## 指令静态分析器
##
## 按属性名模式提取引用信息，不侵入指令基类。
## 支持：NodePath 引用、变量引用、信号、控制流嵌套指令。

# ============================================================
# 属性提取策略（Stage 6.5：反射 + 命名启发式，覆盖动态属性组件）
# ============================================================
# Fuse 组件 95% 用 _get_property_list 动态声明属性，硬编码属性名无法覆盖。
# 改为运行时反射 get_property_list + 命名启发式筛选：
#   - 变量引用: *_variable（配对 *_variable_scope）
#   - 节点引用: *_node / *_node_path（NodePath 类型 + String 类型）

## 子指令数组属性名 — 控制流指令（if/else/loop）的嵌套指令
const _SUB_INSTRUCTIONS := ["instructions", "true_instructions", "false_instructions", "else_instructions", "loop_instructions"]


# ============================================================
# 单 Trigger 分析
# ============================================================

## 解析单个 Trigger，返回结构化数据流报告
static func analyze_trigger(trigger: Node) -> Dictionary:
	var report := {
		"trigger_name": trigger.name,
		"trigger_path": str(trigger.get_path()),
		"trigger_type": _get_node_type_name(trigger),
		"event": {},
		"event_bindings": [],
		"nodes": [],
		"variables": {"local": [], "scope": [], "global": []},
		"signals": [],
		"instructions_flat": [],
		"instructions_tree": [],
		"provided_locals": []  # E7: 事件提供的 LOCAL 变量名（白名单）
	}

	# MultiEventTrigger：遍历 event_bindings
	if trigger.get("event_bindings") != null:
		report["event_bindings"] = _analyze_event_bindings(trigger)
		# 信号提取
		_extract_signals(trigger, report)
		return report

	# 普通 Trigger：单 event + action_runner
	report["event"] = _extract_event(trigger)

	# 提取 event_definition 的节点/变量引用
	var event_def = trigger.get("event_definition")
	if event_def:
		_extract_nodepaths(event_def, report)
		_extract_variables(event_def, report)
		# E7: 提取事件提供的 LOCAL 变量（白名单）
		report["provided_locals"] = _extract_provided_locals(event_def)

	# 获取 ActionRunner：优先从 trigger 自身读取，再查 Runner 子节点
	var action_runner = _get_action_runner(trigger)
	if action_runner == null:
		return report

	_analyze_instructions(action_runner.instructions, report, "", report["instructions_tree"])

	# 提取信号信息：优先 Runner 子节点，再查 trigger 自身信号
	_extract_signals(trigger, report)

	return report


## 分析 MultiEventTrigger 的 event_bindings
static func _analyze_event_bindings(trigger: Node) -> Array:
	var result: Array = []
	var bindings = trigger.get("event_bindings")
	if bindings == null:
		return result
	for i in range(bindings.size()):
		var binding = bindings[i]
		if binding == null:
			continue
		var binding_report := {
			"index": i,
			"event": _extract_event_resource(binding.event),
			"enabled": binding.enabled,
			"instructions_flat": [],
			"instructions_tree": [],
			"nodes": [],
			"variables": {"local": [], "scope": [], "global": []},
			"provided_locals": []  # E7: 事件提供的 LOCAL 变量（白名单）
		}
		# event 节点/变量引用
		var ev = binding.event
		if ev:
			_extract_nodepaths(ev, binding_report)
			_extract_variables(ev, binding_report)
			# E7: 提取事件提供的 LOCAL 变量
			binding_report["provided_locals"] = _extract_provided_locals(ev)
		# action_runner 指令链
		var ar = binding.action_runner
		if ar and ar.instructions.size() > 0:
			_analyze_instructions(ar.instructions, binding_report, "", binding_report["instructions_tree"])
		result.append(binding_report)
	return result


## 获取节点的脚本类名（Trigger/Runner/MultiEventTrigger），回退 get_class()
static func _get_node_type_name(node: Node) -> String:
	var script = node.get_script()
	if script:
		var global_name: String = script.get_global_name()
		if not global_name.is_empty():
			return global_name
	return node.get_class()


## 从 trigger 获取 ActionRunner
## 优先从 trigger 自身属性读取（Trigger.action_runner），
## 再查找 Runner 子节点（Runner.action_runner）
static func _get_action_runner(trigger: Node):
	# 方式 1：Trigger 自身有 action_runner 属性
	if "action_runner" in trigger:
		var ar = trigger.action_runner
		if ar != null:
			return ar

	# 方式 2：查找 Runner 子节点
	var runner = _find_child_of_type(trigger, "Runner")
	if runner != null and "action_runner" in runner:
		return runner.action_runner

	return null


# ============================================================
# 递归分析
# ============================================================

## 递归分析指令树
## tree_out 参数维护嵌套层次：每层插入 {name, children: {then/else/loop: [...]}}
static func _analyze_instructions(instructions: Array, report: Dictionary, prefix: String, tree_out: Array = []) -> void:
	if instructions == null:
		return
	for inst in instructions:
		if inst == null:
			continue

		var display_name: String = inst.resource_name
		if display_name.is_empty():
			display_name = inst.get_class()

		# Flat 兼容（现有逻辑不变）
		report.instructions_flat.append({"name": display_name, "prefix": prefix})

		# Tree 新增（明确 parent + branch label）
		var tree_node := {
			"name": display_name,
			"inst": inst,
			"children": {}
		}
		tree_out.append(tree_node)

		# NodePath 引用
		_extract_nodepaths(inst, report)

		# 变量引用
		_extract_variables(inst, report)

		# 条件（BaseCondition）节点/变量引用
		if "condition" in inst:
			var cond = inst.get("condition")
			if cond != null:
				_extract_nodepaths(cond, report)
				_extract_variables(cond, report)

		# 递归嵌套指令（子树写入 children，branch label 明确）
		for sub_key in _SUB_INSTRUCTIONS:
			if sub_key in inst:
				var sub: Array = inst.get(sub_key)
				var branch_label := _sub_key_to_branch(sub_key)
				tree_node.children[branch_label] = []
				_analyze_instructions(sub, report, prefix + "  ", tree_node.children[branch_label])


## 子指令 key → branch label 映射
static func _sub_key_to_branch(p_key: String) -> String:
	match p_key:
		"instructions", "true_instructions": return "then"
		"false_instructions", "else_instructions": return "else"
		"loop_instructions": return "loop"
		_: return p_key



## 提取指令中的 NodePath 引用（反射 + 命名启发式）
static func _extract_nodepaths(inst, report: Dictionary) -> void:
	for prop in inst.get_property_list():
		var prop_name: String = prop.get("name", "")
		var ptype: int = prop.get("type", 0)
		# NodePath 类型，或命名启发式 *_node / *_node_path（含 String 型动态属性）
		var is_node_ref := ptype == TYPE_NODE_PATH \
			or prop_name.ends_with("_node") \
			or prop_name.ends_with("_node_path")
		if not is_node_ref:
			continue
		var np = inst.get(prop_name)
		if np == null:
			continue
		var s := str(np)
		if not s.is_empty() and s not in report.nodes:
			report.nodes.append(s)


## 提取指令中的变量引用
static func _extract_variables(inst, report: Dictionary) -> void:
	# 优先用组件声明的精确 mode（get_variable_modes）
	# 默认空数组 → fallback _infer_variable_mode（向后兼容，存量组件渐进迁移）
	var declared_modes := {}
	if inst.has_method("get_variable_modes"):
		for entry in inst.get_variable_modes():
			var entry_name: String = entry.get("name", "")
			if not entry_name.is_empty():
				declared_modes[entry_name] = entry.get("mode", "read_write")
	# 反射扫所有属性，命名启发式找变量引用（*_variable）
	for prop in inst.get_property_list():
		var pname: String = prop.get("name", "")
		# _variable_scope 结尾是 _scope，不会被 ends_with("_variable") 选中，自动排除
		if not _is_variable_prop(pname):
			continue
		if prop.get("type", 0) != TYPE_STRING:
			continue
		var name_val = inst.get(pname)
		if name_val == null:
			continue
		var name: String = name_val
		if name.is_empty():
			continue
		# 配对 scope 属性（默认 *_variable_scope；variable_name → variable_scope；array_variable → array_scope）
		var scope_val = inst.get(pname + "_scope")
		if scope_val == null and pname.ends_with("_name"):
			scope_val = inst.get(pname.substr(0, pname.length() - 5) + "_scope")
		if scope_val == null and pname.ends_with("_variable"):
			scope_val = inst.get(pname.substr(0, pname.length() - 9) + "_scope")
		var scope: int = 0
		if scope_val != null:
			scope = int(scope_val)
		# mode：组件声明优先，fallback 命名启发式
		var mode: String = declared_modes.get(pname, _infer_variable_mode(pname))
		var entry := {"name": name, "source_prop": pname, "mode": mode}
		if scope == 1:  # SCOPE
			if "scope_source" in inst:
				entry["source"] = inst.scope_source
			if "custom_scope_id" in inst:
				entry["scope_id"] = inst.custom_scope_id
		match scope:
			0: report.variables.local.append(entry)
			1: report.variables.scope.append(entry)
			2: report.variables.global.append(entry)


## 变量访问 mode 启发式（target_=write, from_=read, 其他=read_write）
static func _infer_variable_mode(pname: String) -> String:
	if pname.begins_with("target_"):
		return "write"
	if pname.begins_with("from_"):
		return "read"
	return "read_write"



## 判断属性名是否为变量引用（命名启发式扩展版）
static func _is_variable_prop(pname: String) -> bool:
	# Stage 6.5 原有：*_variable（排除 *_variable_scope，因 _scope 结尾）
	if pname.ends_with("_variable"):
		return true
	# 扩展：Condition 常见的变量属性名
	if pname.ends_with("_variable_name"):
		return true
	if pname == "variable_name":
		return true
	if pname == "compare_variable":
		return true
	if pname == "source_variable":
		return true
	return false


# ============================================================
# E2: 信号引用提取
# ============================================================

## 判断属性名是否为信号引用（命名启发式）
## 覆盖：signal_name（EmitSignal 标准）/ *_signal（自定义扩展）/ emit_signal（显式）
## spec §3.2 + §6 Phase 1：与 _is_variable_prop 同级，单点扩展
static func _is_signal_prop(pname: String) -> bool:
	return pname == "signal_name" \
		or pname.ends_with("_signal") \
		or pname == "emit_signal"


## 提取指令中的信号引用（信号名 + 目标节点路径字符串）
## 反射 + 命名启发式，覆盖动态属性组件（与 _extract_nodepaths 同构）
## @param inst: 指令（Resource）
## @param report: Dictionary - 写入 report["signal_refs"] 数组
## 每条 entry: {signal_name: String, target_str: String, source_prop: String}
static func _extract_signal_refs(inst, report: Dictionary) -> void:
	if not report.has("signal_refs"):
		report["signal_refs"] = []
	if inst == null:
		return
	for prop in inst.get_property_list():
		var pname: String = prop.get("name", "")
		if not _is_signal_prop(pname):
			continue
		var val = inst.get(pname)
		if val == null:
			continue
		var sig_name: String = str(val)
		if sig_name.is_empty():
			continue
		# 取配对 target_node（NodePath 字符串形式）
		var target_str := ""
		if "target_node" in inst:
			var tn = inst.get("target_node")
			if tn != null:
				target_str = str(tn)
		report["signal_refs"].append({
			"signal_name": sig_name,
			"target_str": target_str,
			"source_prop": pname
		})


# ============================================================
# 事件与信号提取
# ============================================================

## 提取 Trigger 的事件定义
static func _extract_event(trigger: Node) -> Dictionary:
	var ed = trigger.get("event_definition")
	return _extract_event_resource(ed)


## 从 BaseEvent Resource 提取事件信息（Trigger + EventBinding 共用）
static func _extract_event_resource(event_def) -> Dictionary:
	if event_def == null:
		return {}
	var script = event_def.get_script()
	return {
		"type": script.get_global_name() if script else "?",
		"resource_name": event_def.resource_name
	}


## E7: 从 event_definition 提取其提供的 LOCAL 变量名（白名单）
## 调用 event_def.get_provided_local_variables()；失败/无方法返回空数组。
static func _extract_provided_locals(event_def) -> Array:
	if event_def == null:
		return []
	if not event_def.has_method("get_provided_local_variables"):
		return []
	var result: Array = []
	var raw = event_def.get_provided_local_variables()
	if raw == null:
		return result
	for v in raw:
		if v is String and not v.is_empty():
			result.append(v)
	return result


## 提取信号信息
## 优先从 Runner 子节点提取，再检查 trigger 自身的信号
static func _extract_signals(trigger: Node, report: Dictionary) -> void:
		# 向上找到场景根,搜索整棵树中的 Runner 节点
		var root := trigger
		while root.get_parent() != null:
			root = root.get_parent()

		var runners: Array[Node] = root.find_children("*", "Runner")
		for runner in runners:
			if not runner is Runner:
				continue
			var sig = runner.get("signal_name")
			if sig == null or str(sig).is_empty():
				continue
			var target = runner.get("target_node")
			var target_str := str(target) if target != null else ""
			var trigger_path := str(trigger.get_path())
			# 检查 target_node 是否指向本 Trigger
			if target_str == trigger_path or target_str.contains(trigger.name):
				report.signals.append({
					"signal": str(sig),
					"target": target_str,
					"runner_name": runner.name
				})

## 在节点的子节点中查找特定类型的节点
static func _find_child_of_type(parent: Node, type_name: String) -> Node:
		for child in parent.get_children():
			# Runner 的 class_name 是 GDScript 层面,get_class() 只返回 C++ 类名
			if type_name == "Runner" and child is Runner:
				return child
			if child.get_class() == type_name:
				return child
		return null


# ============================================================
# 全场景拓扑
# ============================================================

## 扫描场景所有 Trigger，构建全局关系图
static func build_topology(scene_root: Node) -> Dictionary:
	var topology := {
		"scene_name": scene_root.name,
		"triggers": [],
		"cross_references": [],
		"variable_analysis": []
	}
	var all_reports := {}
	var triggers: Array[Node] = scene_root.find_children("*", "Trigger")
	triggers.append_array(scene_root.find_children("*", "MultiEventTrigger"))

	for trigger in triggers:
		var report := analyze_trigger(trigger)
		report["trigger_path"] = scene_root.name + "/" + str(scene_root.get_path_to(trigger))
		# 嵌套场景检测（owner != scene_root → 来自 instance 场景）
		var is_nested: bool = trigger.owner != null and trigger.owner != scene_root
		report["is_nested"] = is_nested
		if is_nested:
			report["scene_source"] = trigger.owner.name
		else:
			report["scene_source"] = "main"
		all_reports[trigger.name] = report
		topology.triggers.append(report)

	# 跨 Trigger 关联：信号连接
	for t1_name in all_reports:
		var r1 = all_reports[t1_name]
		for signal_info in r1.signals:
			var target: String = signal_info.get("target", "")
			for t2_name in all_reports:
				if t2_name == t1_name:
					continue
				if target.find(t2_name) != -1:
					topology.cross_references.append({
						"from": t1_name, "to": t2_name,
						"type": "signal", "detail": signal_info.signal
					})

	# E3: 全局变量读写方向收集
	# global_vars_usage: { vname: [{trigger_name, mode}, ...] }
	# mode 来自 _infer_variable_mode: write（target_）/ read（from_）/ read_write（其他）
	var global_vars_usage := {}
	for report in all_reports.values():
		var seen := {}  # 同 trigger 内同 vname 去重（_extract_variables 可能重复提取）
		# 收集 trigger 级 + event_bindings 级（MultiEventTrigger）的全局变量
		var all_global_vars: Array = report.variables.global.duplicate()
		for binding in report.get("event_bindings", []):
			all_global_vars.append_array(binding.get("variables", {}).get("global", []))
		for var_entry in all_global_vars:
			var vname: String = var_entry.name
			if seen.has(vname):
				continue
			seen[vname] = true
			var mode: String = var_entry.get("mode", "read_write")
			if not global_vars_usage.has(vname):
				global_vars_usage[vname] = []
			global_vars_usage[vname].append({
				"trigger_name": report.trigger_name,
				"mode": mode
			})

	# E3 §3.3: 跨 Trigger 变量关联生成
	_build_variable_cross_references(global_vars_usage, all_reports, topology)

	# E3 §3.3: 孤写/孤读标注（variable_analysis 顶层）
	_build_variable_analysis(global_vars_usage, topology)

	return topology


## E3: 基于全局变量读写方向生成跨 Trigger 关联条目
## - variable_write_to_read: 写者 → 变量 → 读者（跨 Trigger）
## - variable_write_to_write: 多 Trigger 共写 + 无互斥 → 竞态预警
static func _build_variable_cross_references(
		global_vars_usage: Dictionary,
		all_reports: Dictionary,
		topology: Dictionary) -> void:
	for vname in global_vars_usage:
		var usages: Array = global_vars_usage[vname]
		# writers: mode in [write, read_write]; readers: mode in [read, read_write]
		# 注：read_write 同时进入 writers 和 readers（修订 MEDIUM#7 双向性）
		var writers := usages.filter(func(u): return u.mode in ["write", "read_write"])
		var readers := usages.filter(func(u): return u.mode in ["read", "read_write"])

		# variable_write_to_read: 写者 → 读者（跳过自环）
		for writer in writers:
			for reader in readers:
				if writer.trigger_name == reader.trigger_name:
					continue
				topology.cross_references.append({
					"from": writer.trigger_name,
					"from_mode": writer.mode,
					"to": reader.trigger_name,
					"to_mode": reader.mode,
					"type": "variable_write_to_read",
					"detail": vname
				})

		# variable_write_to_write: 竞态预警（2+ writers，无互斥）
		if writers.size() >= 2:
			var has_mutex := false
			for writer in writers:
				var wreport: Dictionary = all_reports.get(writer.trigger_name, {})
				if _has_mutex_protection(wreport):
					has_mutex = true
					break
			if not has_mutex:
				for i in range(writers.size()):
					for j in range(i + 1, writers.size()):
						if writers[i].trigger_name == writers[j].trigger_name:
							continue  # 同 Trigger 不算竞态（顺序执行，非并发）
						topology.cross_references.append({
							"from": writers[i].trigger_name,
							"from_mode": writers[i].mode,
							"to": writers[j].trigger_name,
							"to_mode": writers[j].mode,
							"type": "variable_write_to_write",
							"detail": vname,
							"warning": true
						})


## E3: 全局变量孤写/孤读标注（单 Trigger 维度统计）
## anomaly: "write_only"（无读者）/ "read_only"（无写者）/ "normal"
static func _build_variable_analysis(global_vars_usage: Dictionary, topology: Dictionary) -> void:
	for vname in global_vars_usage:
		var usages: Array = global_vars_usage[vname]
		var writers := usages.filter(func(u): return u.mode in ["write", "read_write"])
		var readers := usages.filter(func(u): return u.mode in ["read", "read_write"])
		var entry := {"name": vname, "writers": writers, "readers": readers}
		if writers.is_empty() and not readers.is_empty():
			entry["anomaly"] = "read_only"
		elif not writers.is_empty() and readers.is_empty():
			entry["anomaly"] = "write_only"
		else:
			entry["anomaly"] = "normal"
		topology.variable_analysis.append(entry)


## E3: 检测 Trigger 是否对全局变量有互斥保护
## Phase 1 简化策略：扫描指令链中是否含 lock/mutex/sync 关键词
## （修订 MEDIUM#2: inst 是 Resource 对象，用 inst.resource_name 取脚本资源名）
static func _has_mutex_protection(report: Dictionary) -> bool:
	# 复用 fuse_topology 的收集策略：优先 flat（含 inst），回退 tree 递归 + event_bindings
	var insts: Array = _collect_insts_for_mutex(report)
	for inst in insts:
		if inst == null:
			continue
		var name: String = inst.resource_name
		if name.is_empty():
			continue
		var name_lower := name.to_lower()
		if name_lower.contains("lock") or name_lower.contains("mutex") or name_lower.contains("sync"):
			return true
	return false


## E3 辅助：从 report 收集所有指令 inst（mutex 检测用，三路径覆盖）
## 与 fuse_topology._collect_insts_from_report 同构（analysis 端独立实现，避免循环依赖）
static func _collect_insts_for_mutex(report: Dictionary) -> Array:
	var insts: Array = []
	for info in report.get("instructions_flat", []):
		var inst = info.get("inst", null)
		if inst != null:
			insts.append(inst)
	if not insts.is_empty():
		return insts
	insts.append_array(_collect_insts_for_mutex_tree(report.get("instructions_tree", [])))
	for binding in report.get("event_bindings", []):
		insts.append_array(_collect_insts_for_mutex_tree(binding.get("instructions_tree", [])))
		for info in binding.get("instructions_flat", []):
			var inst = info.get("inst", null)
			if inst != null and inst not in insts:
				insts.append(inst)
	return insts


static func _collect_insts_for_mutex_tree(tree: Array) -> Array:
	var out: Array = []
	for node_info in tree:
		var inst = node_info.get("inst", null)
		if inst != null:
			out.append(inst)
		var children: Dictionary = node_info.get("children", {})
		for branch in children:
			out.append_array(_collect_insts_for_mutex_tree(children[branch]))
	return out


# ============================================================
# E5: 共用工具方法（公开静态） — Topology + Inspector 共用
# ============================================================

## 从 trigger report 收集所有指令 inst（flat 优先，回退 tree 递归 + event_bindings）
## @param report: analyze_trigger 返回的 report
## @return: Array[BaseInstruction]（flat 列表，已去重 binding.flat 路径）
## 覆盖：
##   1. instructions_flat（若含 inst 字段）
##   2. instructions_tree 递归（含 children 分支）
##   3. event_bindings[].instructions_tree + instructions_flat（MultiEventTrigger）
static func collect_insts_from_report(report: Dictionary) -> Array:
	var insts: Array = []
	# 优先 instructions_flat（若含 inst 字段）
	for info in report.get("instructions_flat", []):
		var inst = info.get("inst", null)
		if inst != null:
			insts.append(inst)
	if not insts.is_empty():
		return insts
	# 回退：instructions_tree 递归 + event_bindings
	insts.append_array(collect_insts_from_tree(report.get("instructions_tree", [])))
	for binding in report.get("event_bindings", []):
		insts.append_array(collect_insts_from_tree(binding.get("instructions_tree", [])))
		for info in binding.get("instructions_flat", []):
			var inst = info.get("inst", null)
			if inst != null and inst not in insts:
				insts.append(inst)
	return insts


## 从 instructions_tree（嵌套）递归收集所有 inst（含 children 分支：then/else/loop）
## @param tree: analyze_trigger 生成的 instructions_tree
## @return: Array[BaseInstruction]
static func collect_insts_from_tree(tree: Array) -> Array:
	var out: Array = []
	for node_info in tree:
		var inst = node_info.get("inst", null)
		if inst != null:
			out.append(inst)
		var children: Dictionary = node_info.get("children", {})
		for branch in children:
			out.append_array(collect_insts_from_tree(children[branch]))
	return out


## 把 problems 按 inst 引用重组 + 汇总（by_inst 供 Inspector / Topology 共用）
## @param problems: analyze_problems 返回的 problems 数组
## @return: Dictionary {by_inst: {int → [problem]}, summary: {errors, warnings, suggestions}}
##   by_inst key = inst.get_instance_id()（int），value = problems[]
##   summary 含 suggestions（与 Topology 原结构一致）
static func index_problems(problems: Array) -> Dictionary:
	var by_inst: Dictionary = {}
	var summary := {"errors": 0, "warnings": 0, "suggestions": 0}
	for p in problems:
		var inst = p.get("inst", null)
		var key: int = inst.get_instance_id() if inst != null else -1
		if not by_inst.has(key):
			by_inst[key] = []
		by_inst[key].append(p)
		match p.get("severity", ""):
			"error": summary.errors += 1
			"warning": summary.warnings += 1
			"suggestion": summary.suggestions += 1
	return {"by_inst": by_inst, "summary": summary}


# ============================================================
# 静态分析：问题检测
# ============================================================

## 静态分析：检测指令序列中的问题（local 未声明变量使用 + NodePath 解析失败）
## @param instructions: Array - 指令序列（flat 顺序）
## @param scene_root: Node - 场景根节点（可选；为 null 时跳过 NodePath 检测）
## @param predefined_locals: Array[String] - 事件提供的 LOCAL 变量名白名单（视为已定义，不报未声明）
## @return: Dictionary - {valid: bool, problems: Array[Dictionary]}
##   problem: {severity, message, instruction_index, variable, inst}
##   NodePath 检测产生的 problem 额外含字段 nodepath: String
static func analyze_problems(instructions: Array, scene_root: Node = null, predefined_locals: Array = []) -> Dictionary:
	var problems: Array = []
	var defined_locals: Dictionary = {}  # var_name → true（已被 write 定义）

	# E7: predefined_locals 视为已定义（事件提供的 LOCAL 变量，如 input_vector）
	for v in predefined_locals:
		if v is String and not v.is_empty():
			defined_locals[v] = true

	for i in range(instructions.size()):
		var inst = instructions[i]
		if inst == null:
			continue
		# 复用 _extract_variables：每指令单独提取
		var tmp := {"variables": {"local": [], "scope": [], "global": []},
					"nodes": [], "signals": []}
		_extract_variables(inst, tmp)
		var entries: Array = tmp.variables.local  # scope==0 的变量
		for entry in entries:
			var vname: String = entry.get("name", "")
			var mode: String = entry.get("mode", "read_write")
			if vname.is_empty():
				continue
			# write / read_write → 视为定义（累积）
			if mode == "write" or mode == "read_write":
				defined_locals[vname] = true
			# read → 检查是否已定义
			if mode == "read" and not defined_locals.has(vname) and not vname.begins_with("event_"):
				problems.append({
					"severity": "error",
					"message": "未声明的局部变量被使用: %s（指令 %d）" % [vname, i],
					"instruction_index": i,
					"variable": vname,
					"inst": inst  # 供 Topology by_inst 索引（instance_id）
				})

		# 递归 condition（条件变量全部 read，不进 defined_locals）
		# 注意：条件只读不写，故只检测未声明，忽略 cond_entry.mode
		# 用 cond != null + "condition" in inst 判断（与 _analyze_instructions 一致），
		# 避免硬绑 BaseCondition（测试 mock 用 Resource 子类即可注入）。
		var cond = inst.get("condition") if inst != null else null
		if cond != null:
			var cond_tmp := {"variables": {"local": [], "scope": [], "global": []}, "nodes": [], "signals": []}
			_extract_variables(cond, cond_tmp)
			for cond_entry in cond_tmp.variables.local:
				var cvname: String = cond_entry.get("name", "")
				if cvname.is_empty():
					continue
				if not defined_locals.has(cvname) and not cvname.begins_with("event_"):
					problems.append({
						"severity": "error",
						"message": "未声明的局部变量被使用（条件）: %s（指令 %d）" % [cvname, i],
						"instruction_index": i,
						"variable": cvname,
						"inst": inst
					})

	# —— E1: NodePath 解析失败检测（仅在 scene_root 提供时启用）——
	# 与变量检测解耦：独立分支，scene_root=null 时完全跳过（零误报）
	if scene_root != null:
		_check_nodepath_targets(instructions, scene_root, problems)

	# —— E2: 信号引用检测（仅在 scene_root 提供时启用）——
	# 检测 EmitSignal 等指令引用的信号是否在目标节点存在（has_signal）
	if scene_root != null:
		_check_signal_references(instructions, scene_root, problems)

	return {"valid": problems.is_empty(), "problems": problems}


## E1: 扫描指令序列的 NodePath 引用，对无法解析的路径报 warning
## 对每条指令：
##   1. 调用 _extract_nodepaths 提取 NodePath 字符串（反射 + 命名启发式）
##   2. 也提取 condition 节点中的 NodePath 引用（与变量检测对齐）
##   3. 对每个 np_str 调 NodePathResolver.resolve_or_null 解析，失败 → warning problem
## warning 而非 error：NodePath 可能运行时动态填充（占位符），静态不确定
static func _check_nodepath_targets(
	instructions: Array,
	scene_root: Node,
	problems: Array
) -> void:
	for i in range(instructions.size()):
		var inst = instructions[i]
		if inst == null:
			continue
		_check_nodepath_in_object(inst, inst, i, scene_root, problems)
		# 条件节点中的 NodePath 引用（与 analyze_problems 变量检测对齐）
		var cond = inst.get("condition") if inst != null else null
		if cond != null:
			_check_nodepath_in_object(cond, inst, i, scene_root, problems)


## 扫描对象（指令/条件）的 NodePath 属性，scope_source 感知检测
## obj = 被扫描对象；owner_inst = 所属指令（problem.inst 索引用）
## *_target_node_path 仅当对应 *_scope_source == TARGET_NODE(3) 时才实际使用，
## 非 TARGET_NODE 时的遗留值不检测（避免序列化残留误报）
static func _check_nodepath_in_object(
	obj, owner_inst, inst_index: int, scene_root: Node, problems: Array
) -> void:
	const TARGET_NODE := 3  # ScopeSource.TARGET_NODE
	for prop in obj.get_property_list():
		var pname: String = prop.get("name", "")
		var ptype: int = prop.get("type", 0)
		# NodePath 属性（NodePath 类型，或命名 *_node/*_node_path）
		var is_np := ptype == TYPE_NODE_PATH or pname.ends_with("_node") or pname.ends_with("_node_path")
		if not is_np:
			continue
		var np_val = obj.get(pname)
		if np_val == null:
			continue
		var np_s: String = str(np_val)
		if np_s.is_empty():
			continue
		# scope_source 感知：*_target_node_path 仅 scope_source==TARGET_NODE 时使用
		if pname.ends_with("target_node_path"):
			var prefix := pname.substr(0, pname.length() - "target_node_path".length())
			var scope_source_prop := prefix + "scope_source"
			if scope_source_prop in obj and obj.get(scope_source_prop) != TARGET_NODE:
				continue  # 非 active（scope_source 非 TARGET_NODE），跳过遗留值
		# 检测
		if NodePathResolver.resolve_or_null(np_s, scene_root) == null:
			problems.append({
				"severity": "warning",
				"message": "节点路径无法解析: %s（指令 %d）" % [np_s, inst_index],
				"instruction_index": inst_index,
				"nodepath": np_s,
				"inst": owner_inst
			})


## E2: 扫描指令序列的信号引用，对目标节点不存在该信号的指令报 error
## 对每条指令：
##   1. 调用 _extract_signal_refs 提取 signal_name + target_str
##   2. 解析 target_str：
##        - 空 → 直接用 scene_root（MEDIUM #5：绕过 resolve_or_null，避免空字符串返回 null）
##        - 非空 → NodePathResolver.resolve_or_null
##   3. 解析失败（target=null）→ 跳过（由 E1 _check_nodepath_targets 报 NodePath 问题）
##   4. target.has_signal(signal_name) == false → error problem
## error 而非 warning：has_signal 是确定性的静态检测，信号不存在是确定的
static func _check_signal_references(
	instructions: Array,
	scene_root: Node,
	problems: Array
) -> void:
	if scene_root == null:
		return
	for i in range(instructions.size()):
		var inst = instructions[i]
		if inst == null:
			continue
		var tmp := {"signal_refs": []}
		_extract_signal_refs(inst, tmp)
		for ref in tmp.get("signal_refs", []):
			var sig_name: String = ref.get("signal_name", "")
			var target_str: String = ref.get("target_str", "")
			if sig_name.is_empty():
				continue
			# 解析目标节点（spec §3.3 + MEDIUM #5）
			var target_node: Node
			if target_str.is_empty():
				# 空 target → 默认 scene_root，绕过 resolve_or_null
				target_node = scene_root
			else:
				target_node = NodePathResolver.resolve_or_null(target_str, scene_root)
			if target_node == null:
				# target 本身不可解析 → 由 E1 报 NodePath 问题，此处跳过
				continue
			if not target_node.has_signal(sig_name):
				problems.append({
					"severity": "error",
					"message": "目标节点不存在信号: %s（指令 %d）" % [sig_name, i],
					"instruction_index": i,
					"signal_name": sig_name,
					"target_node_str": target_str,
					"inst": inst
				})
