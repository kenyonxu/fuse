# 文件：addons/fuse/editor/graduation/system_deriver.gd
@tool
class_name SystemDeriver
extends RefCounted

## System 推导器（M1 毕业导出器）
##
## 拓扑（InstructionAnalyzer.build_topology）→ 每个非 runner 非嵌套单元一份
## 单例 System 草稿 JSON（结构见 spec §4.1）+ 一份推导报告。
##
## - kind 过滤：runner 单元跳过（MVP 不推导，L3 推导是一期扩展直接放开）
## - is_nested 跳过：嵌套单元需到其所属子场景内推导
## - externals 边界声明：events_out/in 与 variables 三层归并
## - 连通分量：run 边 + 变量边并查集（signal 边为既有死代码，spec §4.2 注记，不参与）
## - 草稿仍按单例产出；分量信息仅供报告标注（多单元物化是二期加法）

## 控制流指令的嵌套指令字段（与 InstructionAnalyzer._SUB_INSTRUCTIONS 对齐）
const _SUB_INSTRUCTIONS := ["instructions", "true_instructions", "false_instructions", "else_instructions", "loop_instructions"]

## System JSON 格式版本（spec §4.1）
const FORMAT_VERSION := "1.0"

## 参与连通分量计算的跨引用边类型（signal 边为既有死代码，不参与——spec §4.2）
const _COMPONENT_EDGE_TYPES := ["run", "variable_write_to_read", "variable_write_to_write"]


## 推导一个场景的全部 System 草稿
## @param scene_root: Node - 场景实例根节点
## @param scene_path: String - res:// 场景路径（溯源字段 derived_from）
## @return: Dictionary {
##   "drafts": [SystemJSON...]（spec §4.1 结构，纯 JSON 标量），
##   "report": {
##     "skipped_runner": int, "skipped_nested": Array[String],
##     "components": {unit_name: [同分量其它单元名...]},
##     "warnings_by_unit": {unit_name: [竞态 warning 条目...]}
##   }}
static func derive_systems(scene_root: Node, scene_path: String) -> Dictionary:
	var topology: Dictionary = InstructionAnalyzer.build_topology(scene_root)
	var digest := topology_digest(topology)

	# —— 全拓扑汇总（externals 边界判定原料；含嵌套与 runner 单元——它们仍是
	#    运行中的变量使用者。注：单元名做 key，同名单元会被覆盖——
	#    与 build_topology 的 all_reports 行为一致，MVP 接受）
	var scope_names_by_unit := {}
	var global_names_by_unit := {}
	for report: Dictionary in topology.triggers:
		var unit: String = report.get("trigger_name", "")
		var merged := _merged_variable_names(report)
		scope_names_by_unit[unit] = merged["scope"]
		global_names_by_unit[unit] = merged["global"]

	var components := _components(topology)
	var warnings_by_unit := _collect_warnings_by_unit(topology)

	# —— 逐单元推导草稿 ——
	var drafts: Array = []
	var skipped_runner := 0
	var skipped_nested: Array = []
	var used_names := {}
	for report: Dictionary in topology.triggers:
		var unit: String = report.get("trigger_name", "?")
		if report.get("kind", "trigger") == "runner":
			skipped_runner += 1
			continue
		if report.get("is_nested", false):
			skipped_nested.append(unit)
			continue
		var node := _resolve_unit_node(scene_root, report)
		drafts.append(_derive_single(report, node, scene_path, digest, used_names,
			scope_names_by_unit, global_names_by_unit))
	return {
		"drafts": drafts,
		"report": {
			"skipped_runner": skipped_runner,
			"skipped_nested": skipped_nested,
			"components": components,
			"warnings_by_unit": warnings_by_unit,
		},
	}


# ============================================================
# 单元草稿组装
# ============================================================

## 组装单个单元的单例 System 草稿（spec §4.1）
static func _derive_single(report: Dictionary, node: Node, scene_path: String,
		digest: String, used_names: Dictionary, scope_names_by_unit: Dictionary,
		global_names_by_unit: Dictionary) -> Dictionary:
	var unit_name: String = report.get("trigger_name", "system")
	var system_name := _unique_system_name(unit_name, used_names)
	# events_in 对本单元节点现算——不经按名汇总字典，规避同名单元覆盖
	var events_in_names: Array = _collect_events_in(node)
	var events_in: Array = []
	for ev_name: String in events_in_names:
		events_in.append({"name": ev_name, "outside_producers": true})
	return {
		"format_version": FORMAT_VERSION,
		"name": system_name,
		"description": "",  # 推导时留空，人填或 AI 生成（spec §4.1）
		"source": {
			"derived_from": scene_path,
			"derived_at": Time.get_datetime_string_from_system(),
			"topology_digest": digest,
		},
		"units": [{
			"id": "u1",  # MVP 恒 1 个元素，id 稳定供后续物化模式交叉引用
			"kind": report.get("kind", "trigger"),
			"scene": scene_path,
			"node_path": _relative_node_path(report),
			"level": _detect_level(report, node),
		}],
		"externals": {
			"events_out": _collect_events_out(node),
			"events_in": events_in,
			"variables": _collect_variables(report, node, unit_name,
				scope_names_by_unit, global_names_by_unit),
		},
		# 竞态等预警不自动确认：校验器要求 warning 存在时人工补对应条目（spec §5）
		"acknowledged_warnings": [],
		"emit": {
			"output_script": "res://fuse_generated/scripts/%s.gd" % system_name,
			"native_instructions": [],  # 缺省用导出器默认白名单
		},
	}


## report.trigger_path 形如 "<场景根名>/A/B"——去场景根前缀得挂载相对路径
static func _relative_node_path(report: Dictionary) -> String:
	var trigger_path: String = report.get("trigger_path", "")
	var idx := trigger_path.find("/")
	if idx < 0:
		return ""
	return trigger_path.substr(idx + 1)


## 从场景根解析单元节点（level 检测与 events/指令对象实取用）
static func _resolve_unit_node(scene_root: Node, report: Dictionary) -> Node:
	var rel := _relative_node_path(report)
	if rel.is_empty():
		return null
	return scene_root.get_node_or_null(NodePath(rel))


## level 与 node 由节点实取（FusePresetSerializer.detect_level）；
## 节点不可得时按 kind 回退推断
static func _detect_level(report: Dictionary, node: Node) -> String:
	if node != null:
		var level := FusePresetSerializer.detect_level(node)
		if not level.is_empty():
			return level
	match report.get("kind", "trigger"):
		"multi": return "L4"
		_: return "L2"


## snake_case 化单元名并全局唯一化（spec §4.1：name 全局唯一，文件名 = name）
static func _unique_system_name(trigger_name: String, used_names: Dictionary) -> String:
	var base := trigger_name.to_snake_case()
	if base.is_empty():
		base = "system"
	if not used_names.has(base):
		used_names[base] = true
		return base
	var i := 2
	while used_names.has("%s_%d" % [base, i]):
		i += 1
	var unique := "%s_%d" % [base, i]
	used_names[unique] = true
	return unique


## topology 摘要指纹（十六进制；变更检测用途，非加密）。
## 先 sanitize 再 str：裸 topology 的 instructions_tree 持对象引用，
## 直接转字符串会带入 instance id，同场景两次推导指纹会漂移。
## 归一化项：
## - 场景根名（trigger_path 首段 / scene_name）：同一场景二次实例化会被 Godot
##   自动改名（如 GameScene2），属实例化噪音而非拓扑变更；
## - signal 边（triggers[].signals + cross_references 的 type=="signal" 条目）：
##   signal 连接在运行时按 _ready 时序出现（实测 title_scene 的
##   OnHintBreathStopped 订阅 HintBreath.event_stopped——attach 后立即构建与
##   隔帧构建拓扑在该字段上漂移），且 signal 边为既有死代码（spec §4.2，
##   不参与分量）——摘要口径剔除，保证 deriver/validator 实测环境差异下
##   指纹确定（终审 I2 实测发现）。
## 公开 static（终审 I2）：SystemValidator 校验 source.topology_digest 时直接
## 调本函数——同一实现，杜绝 deriver/validator 两处同构漂移。
static func topology_digest(topology: Dictionary) -> String:
	var normalized: Dictionary = TopologyExport.sanitize_for_json(topology)
	normalized["scene_name"] = ""
	for report: Dictionary in normalized.get("triggers", []):
		var tp := str(report.get("trigger_path", ""))
		var idx := tp.find("/")
		if idx >= 0:
			report["trigger_path"] = tp.substr(idx + 1)
		report["signals"] = []
	var stable_refs: Array = []
	for ref: Dictionary in normalized.get("cross_references", []):
		if str(ref.get("type", "")) != "signal":
			stable_refs.append(ref)
	normalized["cross_references"] = stable_refs
	return "%x" % str(normalized).hash()


# ============================================================
# externals：events_out / events_in
# ============================================================

## 收集单元全部 ActionRunner：普通 Trigger 主 runner（含 Runner 子节点回退）
## + MultiEventTrigger 的 event_bindings[].action_runner（对齐 analyzer 覆盖面）
static func _unit_action_runners(node: Node) -> Array:
	var runners: Array = []
	if node == null:
		return runners
	var ar = node.get("action_runner")
	if ar == null:
		# 宿主实现细节：Trigger 的 Runner 子节点也是动作源
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


## events_out：遍历单元指令树（含嵌套字段）中的 SendEvent 实例取 event_name。
## outside_consumers 从宽恒 true（controller ruling）：单例分量内无订阅者，
## 事件总线全局广播无法证伪外部消费者；场景内其它单元订阅时可精确成立。
static func _collect_events_out(node: Node) -> Array:
	var names: Array = []
	for ar in _unit_action_runners(node):
		_collect_send_event_names(ar.instructions, names)
	var out: Array = []
	for ev_name: String in names:
		out.append({"name": ev_name, "outside_consumers": true})
	return out


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


## events_in：普通 Trigger 的 event_definition + MultiEventTrigger 的
## event_bindings[].event 中，OnReceiveEvent 实例的 event_name。
## outside_producers 同 events_out 从宽恒 true（MVP 桥接模式全部外联，spec §6.3）
static func _collect_events_in(node: Node) -> Array:
	var names: Array = []
	if node == null:
		return names
	_append_receive_event_name(node.get("event_definition"), names)
	var bindings = node.get("event_bindings")
	if bindings != null:
		for binding in bindings:
			if binding != null:
				_append_receive_event_name(binding.get("event"), names)
	return names


static func _append_receive_event_name(event_def, names: Array) -> void:
	if event_def == null or not event_def is OnReceiveEvent:
		return
	var ev_name := str(event_def.get("event_name"))
	if not ev_name.is_empty() and not (ev_name in names):
		names.append(ev_name)


# ============================================================
# externals：variables（三层 + event_bindings 级归并）
# ============================================================

## 变量边界声明：trigger 级三层 + event_bindings 级归并去重。
## - scope 层带 container（NodePath 字符串）：TARGET_NODE → target_node_path、
##   CUSTOM_ID → "id:<custom_scope_id>"；NEAREST/TRIGGER_SCOPE 运行时决定，缺省
## - shared_outside 按分量边界（单例 = 拓扑中其它单元是否也用同层同名变量）；
##   local 层物理上不跨单元，恒 false
static func _collect_variables(report: Dictionary, node: Node, unit_name: String,
		scope_names_by_unit: Dictionary, global_names_by_unit: Dictionary) -> Array:
	var containers := {}
	if node != null:
		for ar in _unit_action_runners(node):
			_scan_scope_containers(ar.instructions, containers)
	var merged := _merged_variable_names(report)
	var out: Array = []
	for layer in ["local", "scope", "global"]:
		for vname: String in merged[layer]:
			var item := {"name": vname, "scope": layer}
			if layer == "scope" and containers.has(vname):
				var container: String = containers[vname]
				if not container.is_empty():
					item["container"] = container
			item["shared_outside"] = _is_shared_outside(
				layer, vname, unit_name, scope_names_by_unit, global_names_by_unit)
			out.append(item)
	return out


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
		for entry: Dictionary in variables.get(layer, []):
			var vname: String = entry.get("name", "")
			if not vname.is_empty():
				layers[layer][vname] = true


static func _is_shared_outside(layer: String, vname: String, unit_name: String,
		scope_names_by_unit: Dictionary, global_names_by_unit: Dictionary) -> bool:
	var names_by_unit: Dictionary
	match layer:
		"local":
			return false  # 局部变量物理上不跨单元（同名巧合不构成共享）
		"scope":
			names_by_unit = scope_names_by_unit
		"global":
			names_by_unit = global_names_by_unit
		_:
			return false
	for other in names_by_unit:
		if other == unit_name:
			continue
		if (names_by_unit[other] as Array).has(vname):
			return true
	return false


## 扫描指令树，为 SCOPE 层变量配对容器描述。
## 指令上 scope_source/target_node_path/custom_scope_id 是该指令全部 scope
## 变量共用的容器选择（变量属性判定与 InstructionAnalyzer._extract_variables
## 的命名启发式对齐）。
static func _scan_scope_containers(instructions: Array, containers: Dictionary) -> void:
	if instructions == null:
		return
	for inst in instructions:
		if inst == null:
			continue
		if "scope_source" in inst:
			var var_names := _instruction_scope_var_names(inst)
			if not var_names.is_empty():
				var container := _scope_container_of(inst)
				if not container.is_empty():
					for vname: String in var_names:
						if not containers.has(vname):
							containers[vname] = container
		for sub_key in _SUB_INSTRUCTIONS:
			if sub_key in inst:
				_scan_scope_containers(inst.get(sub_key), containers)


## 指令上 SCOPE 层变量名提取（属性名判定对齐 InstructionAnalyzer._is_variable_prop）
static func _instruction_scope_var_names(inst) -> Array:
	var names: Array = []
	for prop in inst.get_property_list():
		var pname: String = prop.get("name", "")
		if prop.get("type", 0) != TYPE_STRING:
			continue
		if not (pname.ends_with("_variable") or pname.ends_with("_variable_name")
				or pname == "variable_name" or pname == "compare_variable"
				or pname == "source_variable"):
			continue
		var val = inst.get(pname)
		if val == null or str(val).is_empty():
			continue
		# 配对 scope 属性的回退链（对齐 InstructionAnalyzer._extract_variables）
		var scope_val = inst.get(pname + "_scope")
		if scope_val == null and pname.ends_with("_name"):
			scope_val = inst.get(pname.substr(0, pname.length() - 5) + "_scope")
		if scope_val == null and pname.ends_with("_variable"):
			scope_val = inst.get(pname.substr(0, pname.length() - 9) + "_scope")
		if scope_val == null and "scope_source" in inst:
			scope_val = BaseVariable.VariableScope.SCOPE  # scope_source 枚举组件统一视为 SCOPE
		if scope_val != null and int(scope_val) == BaseVariable.VariableScope.SCOPE:
			var vname := str(val)
			if not (vname in names):
				names.append(vname)
	return names


## 指令的 scope 容器描述：TARGET_NODE → target_node_path（NodePath 字符串）、
## CUSTOM_ID → "id:<custom_scope_id>"；NEAREST/TRIGGER_SCOPE 运行时决定返回 ""
static func _scope_container_of(inst) -> String:
	match int(inst.get("scope_source")):
		VariableScopeUtils.ScopeSource.TARGET_NODE:
			return str(inst.get("target_node_path")) if "target_node_path" in inst else ""
		VariableScopeUtils.ScopeSource.CUSTOM_ID:
			var scope_id := str(inst.get("custom_scope_id")) if "custom_scope_id" in inst else ""
			return "id:" + scope_id if not scope_id.is_empty() else ""
	return ""


# ============================================================
# 报告：竞态预警汇总 + 连通分量
# ============================================================

## topology.cross_references 中 warning == true 的条目按涉及单元（from/to）汇总。
## 草稿的 acknowledged_warnings 不自动填——留给人工确认（spec §5 校验门禁）
static func _collect_warnings_by_unit(topology: Dictionary) -> Dictionary:
	var by_unit := {}
	for ref: Dictionary in topology.cross_references:
		if not ref.get("warning", false):
			continue
		for side in ["from", "to"]:
			var unit: String = ref.get(side, "")
			if unit.is_empty():
				continue
			if not by_unit.has(unit):
				by_unit[unit] = []
			by_unit[unit].append(ref.duplicate())
	return by_unit


## 连通分量（并查集）：run 边 + variable_write_to_read/write_to_write 变量边。
## signal 边不参与（既有死代码：_extract_signals 把 Runner 绑定记到接收方且
## target 指向自身，只在子串撞名时偶然命中——spec §4.2 注记）。
## @return: {unit_name: [同分量其它单元名...]}（单元返回空数组）
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
	# 路径压缩
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
