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

## 获取单个组件的参数 schema
##
## 参数：
## - type_name: 组件类名（class_name，如 "SendEvent"、"ForEach"）
##
## 返回：
## - Array[Dictionary] - 每项包含 name/type/type_name/hint/hint_string/default/is_nested_instructions
##   未找到组件时返回空数组
static func get_parameter_schema(type_name: String) -> Array[Dictionary]:
	var script = _resolve_script(type_name)
	if script == null:
		push_warning("[SchemaExtractor] 未找到组件: %s" % type_name)
		return []

	var inst = script.new()
	var schemas: Array[Dictionary] = []
	for prop in inst.get_property_list():
		var pname: String = prop.get("name", "")
		# 过滤私有属性
		if pname.begins_with("_"):
			continue
		# 仅保留可存储属性
		if not (prop.get("usage", 0) & PROPERTY_USAGE_STORAGE):
			continue
		# 过滤基类属性
		if pname in _BASE_PROPS:
			continue

		var ptype: int = prop.get("type", 0)
		schemas.append({
			"name": pname,
			"type": ptype,
			"type_name": _type_to_string(ptype),
			"hint": prop.get("hint", 0),
			"hint_string": prop.get("hint_string", ""),
			"default": inst.get(pname),
			"is_nested_instructions": pname in _NESTED_PROPS,
		})

	# 释放实例（RefCounted 自动释放，Resource/Object 需手动 free）
	if inst is RefCounted == false:
		inst.free()
	return schemas


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
