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
		"instructions_tree": []
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
			"variables": {"local": [], "scope": [], "global": []}
		}
		# event 节点/变量引用
		var ev = binding.event
		if ev:
			_extract_nodepaths(ev, binding_report)
			_extract_variables(ev, binding_report)
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
		# 配对 scope 属性（*_variable_scope）
		var scope_prop := pname + "_scope"
		var scope: int = 0
		var scope_val = inst.get(scope_prop)
		if scope_val != null:
			scope = int(scope_val)
		var entry := {"name": name, "source_prop": pname, "mode": _infer_variable_mode(pname)}
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
		"cross_references": []
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

	# 跨 Trigger 关联：共享全局变量
	var global_vars_used := {}
	for t_name in all_reports:
		for var_entry in all_reports[t_name].variables.global:
			var vname: String = var_entry.name
			if not global_vars_used.has(vname):
				global_vars_used[vname] = []
			global_vars_used[vname].append(t_name)

	for vname in global_vars_used:
		var users = global_vars_used[vname]
		if users.size() > 1:
			for i in range(users.size()):
				for j in range(i + 1, users.size()):
					topology.cross_references.append({
						"from": users[i], "to": users[j],
						"type": "shared_global_variable", "detail": vname
					})

	return topology
