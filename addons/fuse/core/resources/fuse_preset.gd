# addons/fuse/core/resources/fuse_preset.gd
@tool
class_name FusePreset
extends Resource

## 动态属性列表
##
## 显式返回 Array[Dictionary]，避免 Godot 4.x 使用 Resource 基类的 Array 返回类型
## 触发 "_get_property_list() should return Array[Dictionary]" 兼容性警告。
func _get_property_list() -> Array[Dictionary]:
	return []

## 预设名称(显示在面板中)
@export var display_name: String = ""

## 分类标识
@export var category: String = ""

## 描述
@export var description: String = ""

## 图标(FuseIconManager builtin_icon 名称)
@export var icon_name: String = ""

## 版本号
@export var version: String = "1.0"

## 变量声明: {"local":["n1"],"scope":[{"name":"hp","container":"../Player"}],"global":["level"]}
@export var variables: Dictionary = {}

## 预设层级: "L1"|"L2"|"L3"|"L4"
@export var level: String = "L1"

## L2/L4: BaseEvent 的序列化数据
@export var event_json: Dictionary = {}

## L2/L4: trigger_once, cooldown_mode, cooldown_time
@export var trigger_config: Dictionary = {}

## L3: signal_name
@export var signal_binding: Dictionary = {}

## L4: EventBinding 数组的序列化数据
@export var event_bindings_json: Array = []

## 指令序列
@export var instructions: Array[BaseInstruction] = []


# ---- 序列化 ----

func to_json() -> Dictionary:
	var data: Dictionary = {
		"format_version": version,
		"level": level,
		"display_name": display_name,
		"category": category,
		"description": description,
		"icon_name": icon_name,
		"variables": variables,
	}

	match level:
		"L1":
			data["action_runner"] = {
				"instructions": _serialize_instructions()
			}
		"L2":
			data["action_runner"] = {
				"instructions": _serialize_instructions()
			}
			data["event"] = event_json
			data["trigger_config"] = trigger_config
		"L3":
			data["action_runner"] = {
				"instructions": _serialize_instructions()
			}
			data["signal_binding"] = signal_binding
		"L4":
			data["trigger_config"] = trigger_config
			data["event_bindings"] = event_bindings_json
		_:
			push_warning("FusePreset.to_json: 未知 level '%s'" % level)

	return data


const _BASE_PROPERTIES := ["log_level", "completion_timing", "execution_mode", "script", "resource_local_to_scene", "resource_name", "metadata"]

func _serialize_instructions() -> Array:
	var result: Array = []
	for inst in instructions:
		var script = inst.get_script()
		var entry := {"type": script.get_global_name() if script else inst.get_class()}
		for prop in inst.get_property_list():
			var pname: String = prop.name
			if pname.begins_with("_") or (prop.usage & PROPERTY_USAGE_STORAGE) == 0:
				continue
			if pname in _BASE_PROPERTIES:
				continue
			var val = inst.get(pname)
			if val is NodePath:
				entry[pname] = str(val)
			elif val is Resource and val.resource_path != "":
				entry[pname] = val.resource_path
			elif not (val is Resource):
				entry[pname] = val
		result.append(entry)
	return result


# ---- 反序列化 ----

static func from_json(data: Dictionary) -> FusePreset:
	var preset := FusePreset.new()
	preset.version = data.get("format_version", "1.0")
	preset.level = data.get("level", "L1")
	preset.display_name = data.get("display_name", "")
	preset.category = data.get("category", "")
	preset.description = data.get("description", "")
	preset.icon_name = data.get("icon_name", "")
	preset.variables = data.get("variables", {})

	# 按 level 解析
	var ar_data: Dictionary = data.get("action_runner", {})
	match preset.level:
		"L1", "L2", "L3":
			preset.instructions = _deserialize_instructions(ar_data.get("instructions", []))
		"L4":
			# L4 不存顶层 instructions，event_bindings 内各自包含
			pass

	if preset.level == "L2":
		preset.event_json = data.get("event", {})
		preset.trigger_config = data.get("trigger_config", {})
	elif preset.level == "L3":
		preset.signal_binding = data.get("signal_binding", {})
	elif preset.level == "L4":
		preset.trigger_config = data.get("trigger_config", {})
		preset.event_bindings_json = data.get("event_bindings", [])

	return preset


static func _cache_type_script(type_name: String) -> GDScript:
	var instructions = InstructionRegistry.get_all_instructions()
	for info in instructions:
		var cls: GDScript = info.get("class")
		if cls and cls.get_global_name() == type_name:
			return cls
	return null


static func _deserialize_instructions(raw: Array) -> Array[BaseInstruction]:
	var result: Array[BaseInstruction] = []
	for entry in raw:
		var type_name: String = entry.get("type", "")
		var script: GDScript = _cache_type_script(type_name)
		if script == null:
			push_warning("FusePreset: 无法找到指令类型 '%s'" % type_name)
			continue
		var inst: BaseInstruction = script.new()
		for key in entry:
			if key == "type":
				continue
			var val = entry[key]
			if val is String and (val.begins_with("uid://") or val.begins_with("res://")):
				var res = load(val)
				if res != null:
					inst.set(key, res)
				else:
					inst.set(key, val)  # 可能是 NodePath 字符串,保留
			else:
				inst.set(key, val)
		result.append(inst)
	return result


# ---- NodePath 映射 ----

func collect_unique_nodepaths() -> Array[NodePath]:
	var result: Array[NodePath] = []
	for inst in instructions:
		for prop in inst.get_property_list():
			if prop.type == TYPE_NODE_PATH:
				var np: NodePath = inst.get(prop.name)
				if not np.is_empty() and np not in result:
					result.append(np)
	return result


func apply_nodepath_mapping(mapping: Dictionary) -> void:
	for inst in instructions:
		for prop in inst.get_property_list():
			if prop.type == TYPE_NODE_PATH:
				var np: NodePath = inst.get(prop.name)
				if mapping.has(str(np)):
					inst.set(prop.name, mapping[str(np)])


# ---- 变量收集 ----

func collect_variables() -> Dictionary:
	var result := {"local": [], "scope": [], "global": []}
	for inst in instructions:
		if "variable_name" in inst and "variable_scope" in inst:
			var name: String = inst.variable_name
			var scope: int = inst.variable_scope
			match scope:
				0:
					if name not in result["local"]:
						result["local"].append(name)
				1:
					var entry := {"name": name, "container": ""}
					if "target_node" in inst:
						entry["container"] = str(inst.target_node)
					result["scope"].append(entry)
				2:
					if name not in result["global"]:
						result["global"].append(name)
	return result
