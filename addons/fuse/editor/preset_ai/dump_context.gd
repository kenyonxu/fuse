# 文件：addons/fuse/editor/preset_ai/dump_context.gd
@tool
class_name DumpContext
extends Node

## 预设 AI 上下文 dump 工具
##
## 收集组件参数 schema、关键枚举、组件清单，
## 产 3 JSON 到 res://addons/fuse/preset_ai_context/，
## 作为 skill-creator 输入素材。
##
## 触发方式：
##   1. Headless（推荐）：建 dump_context.tscn（root 为本脚本），跑
##      `Godot --headless --path <project> res://addons/fuse/editor/preset_ai/dump_context.tscn`
##   2. 编辑器内：把 dump_context.tscn 当场景打开运行
##
## Headless 场景下 ComponentRegistry 为空（扫描器依赖 EditorPlugin），
## 故 _dump_components 自行扫描文件夹收集 metadata（与 SchemaExtractor 一致）。

const SchemaExtractor := preload("res://addons/fuse/editor/preset_ai/schema_extractor.gd")

const OUT_DIR := "res://addons/fuse/preset_ai_context/"

# 各类别扫描目录（与 SchemaExtractor / FuseComponentScanner 一致）
const _INSTRUCTION_FOLDERS := [
	"res://addons/fuse/instructions/",
	"res://addons/fuse/integration/",
	"res://fuse_generated/instructions/",
]
const _EVENT_FOLDERS := ["res://addons/fuse/events/"]
const _CONDITION_FOLDERS := ["res://addons/fuse/conditions/"]

# 各类别 metadata 静态方法名 + 文件前缀过滤（与 FuseComponentScanner 一致）
const _CATEGORY_CONFIG := {
	"instruction": {
		"folders": _INSTRUCTION_FOLDERS,
		"metadata_method": "_get_instruction_metadata",
		"skip_prefix": "instructions_",
	},
	"event": {
		"folders": _EVENT_FOLDERS,
		"metadata_method": "_get_event_metadata",
		"skip_prefix": "base_",
	},
	"condition": {
		"folders": _CONDITION_FOLDERS,
		"metadata_method": "_get_condition_metadata",
		"skip_prefix": "base_",
	},
}


func _ready() -> void:
	_ensure_out_dir()
	_dump_schemas()
	_dump_enums()
	_dump_components()
	print("[DumpContext] dump 完成 → %s" % OUT_DIR)
	get_tree().quit()


# ============================================================
# 1. 组件参数 schema
# ============================================================

func _dump_schemas() -> void:
	var schemas: Dictionary = SchemaExtractor.get_all_parameter_schemas()
	_save_json(OUT_DIR + "fuse_component_schemas.json", schemas)
	print("[DumpContext] schemas: %d 组件" % schemas.size())


# ============================================================
# 2. 关键枚举
# ============================================================

func _dump_enums() -> void:
	var enums := {}
	# BaseVariable.VariableScope（core/base/base_variable.gd）
	enums["VariableScope"] = _enum_to_dict(BaseVariable, "VariableScope")
	# ActionRunner.ExecutionMode（core/base/action_runner.gd）
	enums["ExecutionMode"] = _enum_to_dict(ActionRunner, "ExecutionMode")
	# BaseTrigger.CooldownMode（core/base_trigger.gd）
	enums["CooldownMode"] = _enum_to_dict(BaseTrigger, "CooldownMode")
	# SequenceMode（if_else 等控制流本地枚举，定义相同；通过 if_else 取）
	var if_else_script := load("res://addons/fuse/instructions/flow_control/if_else.gd") as GDScript
	enums["SequenceMode"] = _script_enum_to_dict(if_else_script, "SequenceMode")
	# ScopeSource（core/utils/variable_scope_utils.gd）
	var scope_utils_script := load("res://addons/fuse/core/utils/variable_scope_utils.gd") as GDScript
	enums["ScopeSource"] = _script_enum_to_dict(scope_utils_script, "ScopeSource")
	_save_json(OUT_DIR + "fuse_enums.json", enums)
	print("[DumpContext] enums: %d 项" % enums.size())


# 通过 class_name（全局类）取枚举 KEY→int
# GDScript 内置类直接访问 <Class>.<Enum>.keys() 与 [<Enum>.KEY1, <Enum>.KEY2, ...]
static func _enum_to_dict(cls: Object, enum_name: String) -> Dictionary:
	var result := {}
	# Object.get_class_enum_list() 不可用；改用 keys + value list
	# GDScript 枚举值绑定在脚本/类上：cls.<enum_name>.keys() / cls.<enum_name>[key]
	# 通过 get(str) 反射访问 enum 字典
	var enum_dict: Dictionary = cls.get(enum_name)
	for key in enum_dict.keys():
		result[key] = enum_dict[key]
	return result


# 通过 GDScript（class_name 但调用方持有 script）取枚举
static func _script_enum_to_dict(script: GDScript, enum_name: String) -> Dictionary:
	var result := {}
	var enum_dict: Dictionary = script.get(enum_name)
	for key in enum_dict.keys():
		result[key] = enum_dict[key]
	return result


# ============================================================
# 3. 组件清单
# ============================================================

func _dump_components() -> void:
	var comps: Array = []
	for category in ["instruction", "event", "condition"]:
		var list := _collect_category_components(category)
		comps.append_array(list)
	_save_json(OUT_DIR + "fuse_components.json", comps)
	print("[DumpContext] components: %d 项" % comps.size())


# 扫描某类别文件夹，收集 {type, category, name_key, description_key, category_key, keywords, icon/builtin_icon}
func _collect_category_components(category: String) -> Array:
	var config: Dictionary = _CATEGORY_CONFIG[category]
	var folders: Array = config.folders
	var metadata_method: String = config.metadata_method
	var skip_prefix: String = config.skip_prefix

	var out: Array = []
	var seen: Dictionary = {}  # type 去重

	for folder in folders:
		for path in _scan_scripts_recursive(folder, skip_prefix):
			var script = load(path) as GDScript
			if script == null:
				continue
			if not script.has_method(metadata_method):
				continue
			var type_name: String = script.get_global_name()
			if type_name.is_empty() or seen.has(type_name):
				continue

			var metadata: Variant = null
			metadata = script.call(metadata_method)
			if metadata == null:
				continue

			seen[type_name] = true
			out.append(_build_component_entry(category, type_name, metadata))
	return out


# 从 metadata Resource 提取字段（兼容 FuseMetadata 的 name_key/category_key/description_key/keywords/builtin_icon/icon_name）
func _build_component_entry(category: String, type_name: String, metadata) -> Dictionary:
	var entry := {
		"type": type_name,
		"category": category,
	}
	# 安全字段访问（metadata 是 Resource）
	for field in ["name_key", "category_key", "description_key", "keywords", "builtin_icon", "icon_name"]:
		var value: Variant = metadata.get(field)
		if value != null:
			entry[field] = value
	return entry


# ============================================================
# 工具方法
# ============================================================

static func _ensure_out_dir() -> void:
	if not DirAccess.dir_exists_absolute(OUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUT_DIR)


static func _save_json(path: String, data) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[DumpContext] 无法写入 %s (err=%d)" % [path, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()


# 递归扫描 GDScript（与 FuseComponentScanner._scan_scripts_recursive 一致）
static func _scan_scripts_recursive(folder: String, skip_prefix: String = "") -> Array[String]:
	var files: Array[String] = []
	var dir = DirAccess.open(folder)
	if dir == null:
		return files

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = folder.path_join(file_name)
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				var sub := _scan_scripts_recursive(full_path, skip_prefix)
				files.append_array(sub)
		elif file_name.ends_with(".gd"):
			if skip_prefix.is_empty() or not file_name.begins_with(skip_prefix):
				files.append(full_path)
		file_name = dir.get_next()
	return files
