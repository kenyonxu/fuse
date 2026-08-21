# 文件：addons/fuse/editor/preset_ai/schema_extractor.gd
@tool
class_name SchemaExtractor
extends RefCounted

## 组件参数 Schema 提取器
##
## 为 LLM 预设生成提供组件参数结构信息。
## 提取 Instruction / Event / Condition 的可存储属性，
## 过滤基类属性，并标记嵌套指令数组（用于 LLM 递归生成子指令）。
##
## 与 FusePresetSerializer._serialize_instructions 的过滤规则一致，
## 确保 LLM 生成的 schema 能直接反序列化为运行时组件。

# 基类属性过滤（与 PresetValueCodec._BASE_PROPERTIES 一致）
const _BASE_PROPS := [
	"log_level",
	"completion_timing",
	"execution_mode",
	"script",
	"resource_local_to_scene",
	"resource_name",
	"metadata",
]

# 嵌套指令数组（与 instruction_analyzer._SUB_INSTRUCTIONS 一致）
# 标记为 is_nested_instructions=true 供 LLM 递归填充
const _NESTED_PROPS := [
	"instructions",
	"true_instructions",
	"false_instructions",
	"else_instructions",
	"loop_instructions",
]

# 各类别扫描目录（与 FuseComponentScanner._register_all_* 一致）
const _INSTRUCTION_FOLDERS := [
	"res://addons/fuse/instructions/",
	"res://addons/fuse/integration/",
	"res://fuse_generated/instructions/",
]
const _EVENT_FOLDERS := ["res://addons/fuse/events/"]
const _CONDITION_FOLDERS := ["res://addons/fuse/conditions/"]

# 类别 → 文件夹映射（供 _scan_category 调用）
const _CATEGORY_FOLDERS := {
	"instruction": _INSTRUCTION_FOLDERS,
	"event": _EVENT_FOLDERS,
	"condition": _CONDITION_FOLDERS,
}


# ============================================================
# 公共 API
# ============================================================

# BFS 状态探测上限：门控组合深度 / 状态总数（防组合爆炸）
const _MAX_PROBE_DEPTH := 4
const _MAX_PROBE_STATES := 128

## 获取单个组件的参数 schema
##
## 参数：
## - type_name: 组件类名（class_name，如 "SendEvent"、"ForEach"）
##
## 返回：
## - Array[Dictionary] - 每项包含 name/type/type_name/hint/hint_string/default/is_nested_instructions，
##   条件注册的动态参数额外携带 requires（{门参数名: 枚举int值}，已最小化；
##   静态参数条目不带该键，保持与旧 dump 字节一致）
##   未找到组件时返回空数组
##
## 实现：BFS 状态展开——对每个 int 枚举门的非默认值组合实例化组件再扫描属性列表，
## 使 _get_property_list 条件注册的动态参数（如 MathOperation.operand_a_variable
## 三层嵌套门控）也进入 schema。
##
## 属性分两档（Godot 4.7 实测：STORAGE=2, SCRIPT_VARIABLE=4096, NO_EDITOR=2）：
## - 可存储档（含 STORAGE 位）：收录口径，与旧 dump 一致；
##   含"幽灵条目"（_validate_property 设 NO_EDITOR 的脚本 var，任何状态都在）
## - 注册档（STORAGE ∧ SCRIPT_VARIABLE）：_get_property_list/@export 真正注册的属性，
##   仅此档可作为门控证据（门识别 / 解锁判定 / requires 最小化 / 幽灵覆盖）
static func get_parameter_schema(type_name: String) -> Array[Dictionary]:
	var script = _resolve_script(type_name)
	if script == null:
		push_warning("[SchemaExtractor] 未找到组件: %s" % type_name)
		return []

	var inst = script.new()
	# 默认态快照：每个状态探测前先复位，杜绝上一状态的门值泄漏
	# （后续状态中新出现的属性在发现时补录默认值）
	var defaults := {}
	for pname in _scan_storable_props(inst):
		defaults[pname] = inst.get(pname)

	var result: Array[Dictionary] = []
	var by_name := {}  # pname -> {"index": int, "registered": bool}
	var queue: Array = [{"assigns": {}, "depth": 0}]
	var seen_states := {"": true}
	while not queue.is_empty():
		var state: Dictionary = queue.pop_front()
		_reset_to_defaults(inst, defaults)
		_apply_assignments(inst, state.assigns)
		var props := _scan_storable_props(inst)
		# 收录：可存储档首现即收录；注册档发现可为幽灵首现条目补最小门控
		for pname in props:
			var is_reg: bool = _is_registered_prop(props[pname])
			if not defaults.has(pname):
				defaults[pname] = inst.get(pname)
			if not by_name.has(pname):
				by_name[pname] = {"index": result.size(), "registered": is_reg}
				var requires := {}
				if is_reg:
					requires = _minimize_requires(inst, defaults, pname, state.assigns)
				result.append(_build_param_entry(inst, props[pname], requires, pname in _NESTED_PROPS))
			elif is_reg and not by_name[pname]["registered"]:
				# 幽灵首现的参数在门控状态真正注册——仅追加 requires 键，
				# 其余字段保持幽灵首现条目原样（旧 dump 条目字节不变纪律）
				by_name[pname]["registered"] = true
				var requires := _minimize_requires(inst, defaults, pname, state.assigns)
				if not requires.is_empty():
					result[by_name[pname]["index"]]["requires"] = requires
		# 门扩展：仅注册档枚举门；仅入队能解锁新注册属性的状态
		# （纯变值不解锁任何参数的分支无信息增益，剪掉以把状态预算留给条件分支）
		if state.depth < _MAX_PROBE_DEPTH:
			var registered_names := {}
			for pname in props:
				if _is_registered_prop(props[pname]):
					registered_names[pname] = true
			for pname in props:
				var prop: Dictionary = props[pname]
				if not _is_registered_prop(prop) or not _is_enum_gate(prop):
					continue
				for value in _enum_gate_values(prop.get("hint_string", "")):
					if int(defaults.get(pname, prop.get("default", 0))) == value:
						continue  # 默认值态已由空 assigns 覆盖
					var next_assigns: Dictionary = state.assigns.duplicate()
					next_assigns[pname] = value
					var sig := _state_signature(next_assigns)
					if not seen_states.has(sig):
						if not _unlocks_registered(inst, defaults, next_assigns, registered_names):
							continue
						if seen_states.size() >= _MAX_PROBE_STATES:
							push_warning("[SchemaExtractor] %s 状态数超上限 %d，截断探测" % [type_name, _MAX_PROBE_STATES])
							continue
						seen_states[sig] = true
						queue.append({"assigns": next_assigns, "depth": state.depth + 1})

	# 释放实例（RefCounted 自动释放，Resource/Object 需手动 free）
	if inst is RefCounted == false:
		inst.free()
	return result


## 获取所有组件的参数 schema（Instruction + Event + Condition）
##
## 返回：
## - Dictionary - { type_name: Array[Dictionary] }，覆盖所有已注册组件
static func get_all_parameter_schemas() -> Dictionary:
	var result := {}
	for type in _get_all_types("instruction"):
		result[type] = get_parameter_schema(type)
	for type in _get_all_types("event"):
		result[type] = get_parameter_schema(type)
	for type in _get_all_types("condition"):
		result[type] = get_parameter_schema(type)
	return result


# ============================================================
# 内部辅助 — type_name → GDScript
# ============================================================

## type_name → GDScript 反查
##
## 策略（两步回退）：
## 1. ComponentRegistry 已注册：按 global_name 匹配（覆盖编辑器运行场景）
## 2. 文件夹扫描：扫描 instructions/events/conditions 目录，按 global_name 匹配
##    （覆盖 headless 测试 / plugin 未激活场景）
## 3. 都失败：返回 null
static func _resolve_script(type_name: String) -> GDScript:
	# 1. ComponentRegistry 反查（按 script.global_name 匹配）
	for ct in [
		ComponentRegistry.ComponentType.INSTRUCTION,
		ComponentRegistry.ComponentType.EVENT,
		ComponentRegistry.ComponentType.CONDITION,
	]:
		for info in ComponentRegistry.get_all(ct):
			var cls = info.get("class", null)
			if cls is GDScript and cls.get_global_name() == type_name:
				return cls

	# 2. 文件夹扫描回退（按 global_name 匹配）
	for category in _CATEGORY_FOLDERS.keys():
		var script = _scan_find_script_by_global_name(category, type_name)
		if script != null:
			return script

	# 3. 失败
	return null


## 收集某类别全部 type_name（基于 script.global_name）
##
## 参数：
## - category: "instruction" / "event" / "condition"
##
## 返回：
## - Array[String] - 该类别所有组件的 class_name
static func _get_all_types(category: String) -> Array:
	var types: Array = []
	var seen: Dictionary = {}  # 去重

	# 1. ComponentRegistry
	var ct := _category_to_enum(category)
	if ct != -1:
		for info in ComponentRegistry.get_all(ct):
			var cls = info.get("class", null)
			if cls is GDScript:
				var gname: String = cls.get_global_name()
				if not gname.is_empty() and not seen.has(gname):
					seen[gname] = true
					types.append(gname)

	# 2. 文件夹扫描补充（registry 为空时，headless 测试场景）
	if types.is_empty():
		var scanned := _scan_collect_global_names(category)
		for gname in scanned:
			if not seen.has(gname):
				seen[gname] = true
				types.append(gname)

	return types


# ============================================================
# 内部辅助 — 文件夹扫描（headless 回退路径）
# ============================================================

## 扫描某类别文件夹，找到 global_name 匹配的脚本
static func _scan_find_script_by_global_name(category: String, type_name: String) -> GDScript:
	var folders: Array = _CATEGORY_FOLDERS.get(category, [])
	for folder in folders:
		for path in _scan_scripts_recursive(folder):
			var script = load(path) as GDScript
			if script and script.get_global_name() == type_name:
				return script
	return null


## 扫描某类别文件夹，收集所有 class_name
static func _scan_collect_global_names(category: String) -> Array:
	var names: Array = []
	var folders: Array = _CATEGORY_FOLDERS.get(category, [])
	for folder in folders:
		for path in _scan_scripts_recursive(folder):
			var script = load(path) as GDScript
			if script:
				var gname: String = script.get_global_name()
				if not gname.is_empty():
					names.append(gname)
	return names


## 递归扫描文件夹中的 GDScript 文件（与 FuseComponentScanner._scan_scripts_recursive 一致）
static func _scan_scripts_recursive(folder: String) -> Array[String]:
	var files: Array[String] = []
	var dir = DirAccess.open(folder)
	if not dir:
		return files

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = folder.path_join(file_name)
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				var sub_files = _scan_scripts_recursive(full_path)
				files.append_array(sub_files)
		elif file_name.ends_with(".gd"):
			files.append(full_path)
		file_name = dir.get_next()
	return files


# ============================================================
# 内部辅助 — BFS 状态探测
# ============================================================

## 扫描当前实例的可存储属性（过滤私有/基类），返回 {name: prop_dict}
## 收录口径：与旧实现一致（含 STORAGE 位即可）
## 同名多条目（脚本 var 自动条目 + _get_property_list 条目）取首个，
## 与旧 dump 保留的字段口径一致
static func _scan_storable_props(inst: Object) -> Dictionary:
	var props := {}
	for prop in inst.get_property_list():
		var pname: String = prop.get("name", "")
		if pname.begins_with("_"):
			continue
		if not (prop.get("usage", 0) & PROPERTY_USAGE_STORAGE):
			continue
		if pname in _BASE_PROPS:
			continue
		if not props.has(pname):
			props[pname] = prop
	return props


## 扫描注册档属性（STORAGE ∧ SCRIPT_VARIABLE）
## 幽灵条目（仅 STORAGE，NO_EDITOR 残留）任何状态都在，不可作为门控证据
## 复用 _scan_storable_props（含同名取首个口径），仅追加注册档过滤
static func _scan_registered_props(inst: Object) -> Dictionary:
	var props: Dictionary = _scan_storable_props(inst)
	for pname in props.keys():
		if not _is_registered_prop(props[pname]):
			props.erase(pname)
	return props


## 属性是否为注册档（@export 或 _get_property_list 声明）
static func _is_registered_prop(prop: Dictionary) -> bool:
	return (int(prop.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0


static func _reset_to_defaults(inst: Object, defaults: Dictionary) -> void:
	for pname in defaults:
		inst.set(pname, defaults[pname])


static func _apply_assignments(inst: Object, assigns: Dictionary) -> void:
	for pname in assigns:
		inst.set(pname, assigns[pname])


## int 枚举门（hint==2）；String+ENUM（InputMap 建议列表等）不是门
static func _is_enum_gate(prop: Dictionary) -> bool:
	return prop.get("type", 0) == TYPE_INT and prop.get("hint", 0) == PROPERTY_HINT_ENUM \
		and _enum_gate_values(prop.get("hint_string", "")).size() >= 2


## 双格式枚举值解析："Add:0,Subtract:1"（显式）与 "Direct,Variable"（隐式索引）
static func _enum_gate_values(hint_string: String) -> Array:
	var values: Array = []
	var implicit := 0
	for pair in hint_string.split(","):
		var kv := pair.split(":")
		if kv.size() == 2:
			values.append(int(kv[1].strip_edges()))
		else:
			values.append(implicit)
		implicit += 1
	return values


static func _state_signature(assigns: Dictionary) -> String:
	var parts: Array[String] = []
	for k in assigns:
		parts.append("%s=%d" % [k, int(assigns[k])])
	parts.sort()
	return ";".join(parts)


## 判定 next_assigns 相对当前状态是否解锁新的注册档属性
## （剪枝依据：注册集无增量的状态不产生新参数/新门控证据）
##
## ⚠️ 约定依赖：本剪枝假设组件的条件注册遵循"逐级注册的选择器嵌套"约定——
## 每个前缀门组合态会解锁下一级选择器/参数（如 MathOperation 的
## operand_a_source → operand_a_scope → operand_a_scope_source 三级链），
## 因此合取门的每个前缀态相对其父态都有注册增量，不会被剪，深层合取态可达。
##
## 失效形态：若未来组件出现"两个根态常驻门的合取才注册参数"
## （`if a == 1 and b == 1`，且 a==1 单独不解锁任何新注册属性），
## 则跳板态 {a:1} 相对根态无注册增量被剪 → {a:1, b:1} 不可达 → 该参数静默漏收录
## （schema 条目缺失，AI 侧不可见，无报错）。
##
## 观测方法：重新 dump 后对比上一版 JSON——组件参数数突降/该组件新增参数远低于
## 手数 _get_property_list 中条件分支的预期；或对可疑组件跑无剪枝状态计数比对收录数。
##
## 加固方向（暂不实施，终审分诊）：两段式 BFS——第一阶段（当前剪枝队列）排空且
## _MAX_PROBE_STATES 预算有余时，用剩余预算对未达状态跑第二段无剪枝遍历兜底。
static func _unlocks_registered(inst: Object, defaults: Dictionary, next_assigns: Dictionary, current_registered: Dictionary) -> bool:
	_reset_to_defaults(inst, defaults)
	_apply_assignments(inst, next_assigns)
	for pname in _scan_registered_props(inst):
		if not current_registered.has(pname):
			return true
	return false


## requires 最小化：逐门尝试移除，移除后参数仍注册则该门非必要
## （注册判定用注册档：幽灵条目任何状态都在，不构成门控证据）
static func _minimize_requires(inst: Object, defaults: Dictionary, pname: String, assigns: Dictionary) -> Dictionary:
	if assigns.is_empty():
		return {}
	var requires := assigns.duplicate()
	for gate in assigns:
		var trial := requires.duplicate()
		trial.erase(gate)
		_reset_to_defaults(inst, defaults)
		_apply_assignments(inst, trial)
		if _scan_registered_props(inst).has(pname):
			requires = trial
	_reset_to_defaults(inst, defaults)
	_apply_assignments(inst, assigns)
	return requires


## 构建单条参数 entry
## 仅条件参数携带 requires；静态参数条目保持与旧 dump 字节一致
static func _build_param_entry(inst: Object, prop: Dictionary, requires: Dictionary, is_nested: bool) -> Dictionary:
	var ptype: int = prop.get("type", 0)
	var entry := {
		"name": prop.get("name", ""),
		"type": ptype,
		"type_name": _type_to_string(ptype),
		"hint": prop.get("hint", 0),
		"hint_string": prop.get("hint_string", ""),
		"default": inst.get(prop.get("name", "")),
		"is_nested_instructions": is_nested,
	}
	if not requires.is_empty():
		entry["requires"] = requires
	return entry


# ============================================================
# 内部辅助 — 工具方法
# ============================================================

## category 字符串 → ComponentType 枚举
static func _category_to_enum(category: String) -> int:
	match category:
		"instruction": return ComponentRegistry.ComponentType.INSTRUCTION
		"event":       return ComponentRegistry.ComponentType.EVENT
		"condition":   return ComponentRegistry.ComponentType.CONDITION
		_:             return -1


## Variant.Type → 人类可读字符串（供 LLM 理解参数类型）
static func _type_to_string(ptype: int) -> String:
	match ptype:
		TYPE_STRING:    return "String"
		TYPE_INT:       return "int"
		TYPE_FLOAT:     return "float"
		TYPE_BOOL:      return "bool"
		TYPE_NODE_PATH: return "NodePath"
		TYPE_VECTOR2:   return "Vector2"
		TYPE_VECTOR3:   return "Vector3"
		TYPE_COLOR:     return "Color"
		TYPE_ARRAY:     return "Array"
		TYPE_DICTIONARY: return "Dictionary"
		TYPE_OBJECT:    return "Object"
		_:              return "type_%d" % ptype
