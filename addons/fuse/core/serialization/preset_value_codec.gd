# addons/fuse/core/serialization/preset_value_codec.gd
@tool
class_name PresetValueCodec
extends RefCounted

## Preset 嵌套资源通用编解码器
##
## 负责把 BaseCondition / BaseInstruction / BaseEvent 及其数组递归地
## 序列化为可 JSON 化的字典/数组，并按目标属性类型反序列化回对象。

const _BASE_PROPERTIES := [
	"log_level",
	"completion_timing",
	"execution_mode",
	"script",
	"resource_local_to_scene",
	"resource_name",
	"metadata"
]

const _NESTED_BASE_CLASSES := ["BaseInstruction", "BaseCondition", "BaseEvent"]

const _COMPONENT_FOLDERS: Array[String] = [
	"res://addons/fuse/instructions/",
	"res://addons/fuse/events/",
	"res://addons/fuse/conditions/",
	"res://addons/fuse/integration/"
]

# 类型名 -> GDScript 缓存（null 表示已扫描但未找到）
static var _script_cache: Dictionary = {}


# ============================================================
# 公共序列化入口
# ============================================================

static func serialize_instructions(instructions: Array[BaseInstruction]) -> Array:
	var result: Array = []
	for instruction in instructions:
		if instruction == null:
			continue
		result.append(serialize_instruction(instruction))
	return result


static func serialize_instruction(instruction: BaseInstruction) -> Dictionary:
	return _serialize_resource(instruction)


static func serialize_condition(condition: BaseCondition) -> Dictionary:
	return _serialize_resource(condition)


static func serialize_event(event: BaseEvent) -> Dictionary:
	return _serialize_resource(event)


# ============================================================
# 公共反序列化入口
# ============================================================

static func deserialize_instructions(raw: Array) -> Array[BaseInstruction]:
	var result: Array[BaseInstruction] = []
	for item in raw:
		if item is Dictionary:
			var instruction := deserialize_instruction(item)
			if instruction != null:
				result.append(instruction)
		else:
			push_warning("PresetValueCodec: instruction 数组中出现非字典项 %s" % item)
	return result


static func deserialize_instruction(data: Dictionary) -> BaseInstruction:
	var resource := _deserialize_resource(data, "BaseInstruction")
	return resource as BaseInstruction


static func deserialize_condition(data: Dictionary) -> BaseCondition:
	var resource := _deserialize_resource(data, "BaseCondition")
	return resource as BaseCondition


static func deserialize_event(data: Dictionary) -> BaseEvent:
	var resource := _deserialize_resource(data, "BaseEvent")
	return resource as BaseEvent


# ============================================================
# 按目标属性上下文反序列化单个值
# ============================================================

static func deserialize_value(obj: Object, key: String, raw_value: Variant) -> Variant:
	var prop := _find_property(obj, key)

	# 仅当目标属性是 Object（资源）或嵌套资源数组时，才把 res:// / uid:// 字符串加载为 Resource
	var should_load_resource_path := false
	if not prop.is_empty():
		var prop_type: int = prop.get("type", TYPE_NIL)
		if prop_type == TYPE_OBJECT:
			should_load_resource_path = true
		elif prop_type == TYPE_ARRAY:
			var hint := _property_to_hint(prop)
			if hint.class != "" and _is_nested_resource_class(hint.class):
				should_load_resource_path = true

	if should_load_resource_path and raw_value is String and (raw_value.begins_with("uid://") or raw_value.begins_with("res://")):
		var res := load(raw_value)
		if res != null:
			return res

	if prop.is_empty():
		return raw_value

	# NodePath 字符串转为 NodePath 对象
	if prop.get("type", TYPE_NIL) == TYPE_NODE_PATH and raw_value is String:
		return NodePath(raw_value)

	# 引擎值类型（Vector2/Color 等）：Variant 隐式转换矩阵不含 String→这些类型，
	# 显式解析（序列化产物是裸 "(x, y)" 形式，str_to_var 需要类型前缀）
	var engine_value_types: Array = [
		TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4,
		TYPE_COLOR, TYPE_RECT2, TYPE_RECT2I, TYPE_QUATERNION, TYPE_PLANE, TYPE_AABB,
		TYPE_TRANSFORM2D, TYPE_TRANSFORM3D, TYPE_BASIS, TYPE_PROJECTION,
	]
	if prop.get("type", TYPE_NIL) in engine_value_types and raw_value is String:
		var parsed: Variant = str_to_var(type_string(prop.get("type", TYPE_NIL)) + raw_value)
		if parsed != null:
			return parsed

	var hint := _property_to_hint(prop)
	if hint.kind == "object" and raw_value is Dictionary:
		return _deserialize_resource(raw_value, hint.class)
	if hint.kind == "array" and raw_value is Array:
		return _deserialize_array(raw_value, hint.class)

	return raw_value


# ============================================================
# 序列化内部实现
# ============================================================

static func _serialize_resource(res: Resource) -> Dictionary:
	var script := res.get_script() as GDScript
	var type_name := script.get_global_name() if script and not script.get_global_name().is_empty() else res.get_class()
	var entry := {"type": type_name}

	for prop in res.get_property_list():
		var pname: String = prop.name
		if pname.begins_with("_") or (prop.usage & PROPERTY_USAGE_STORAGE) == 0:
			continue
		if pname in _BASE_PROPERTIES:
			continue
		entry[pname] = _serialize_value(res.get(pname))

	return entry


static func _serialize_value(value: Variant) -> Variant:
	if value is BaseInstruction:
		return _serialize_resource(value)
	if value is BaseCondition:
		return _serialize_resource(value)
	if value is BaseEvent:
		return _serialize_resource(value)
	if value is Array:
		return _serialize_array(value)
	if value is NodePath:
		return str(value)
	if value is Resource:
		# 场景内嵌 sub-resource（resource_path 含 ::）的引用离开源场景无意义，序列化为 inline dict
		if value.resource_path != "" and not value.resource_path.contains("::"):
			return value.resource_path
		return _serialize_resource(value)
	return value


static func _serialize_array(arr: Array) -> Array:
	var result: Array = []
	for item in arr:
		result.append(_serialize_value(item))
	return result


# ============================================================
# 反序列化内部实现
# ============================================================

static func _deserialize_resource(data: Dictionary, expected_base: String) -> Resource:
	if not data.has("type"):
		push_warning("PresetValueCodec: 嵌套资源数据缺少 type 字段")
		return null

	var type_name: String = data["type"]

	var inst: Resource = null
	if ClassDB.class_exists(type_name):
		# 原生或已注册类：使用 ClassDB 校验并实例化
		if expected_base != "" and not ClassDB.is_parent_class(type_name, expected_base):
			push_warning("PresetValueCodec: 类型 '%s' 不继承 '%s'" % [type_name, expected_base])
			return null
		inst = ClassDB.instantiate(type_name) as Resource
	else:
		# GDScript class_name 在 headless/运行时未必注册到 ClassDB，按路径回退加载
		var script := _resolve_script(type_name)
		if script == null:
			push_warning("PresetValueCodec: 未知类型 '%s'" % type_name)
			return null
		if expected_base != "" and not _script_inherits(script, expected_base):
			push_warning("PresetValueCodec: 类型 '%s' 不继承 '%s'" % [type_name, expected_base])
			return null
		inst = script.new() as Resource

	if inst == null:
		push_warning("PresetValueCodec: 无法实例化 '%s'" % type_name)
		return null

	for key in data:
		if key == "type":
			continue
		var value := deserialize_value(inst, key, data[key])
		_set_property_safely(inst, key, value)

	return inst


static func _set_property_safely(obj: Object, key: String, value: Variant) -> void:
	obj.set(key, value)
	# Godot 对类型化数组属性可能拒绝无类型 Array；用属性自身的类型化副本再试一次
	if value is Array:
		var current: Variant = obj.get(key)
		if current is Array and current.size() != value.size():
			var typed: Array = current.duplicate()
			typed.clear()
			typed.append_array(value)
			obj.set(key, typed)


static func _deserialize_array(raw: Array, element_class: String) -> Array:
	if element_class.is_empty() or not _is_nested_resource_class(element_class):
		return raw.duplicate()

	var result: Array = []
	for item in raw:
		if item is Dictionary:
			result.append(_deserialize_resource(item, element_class))
		else:
			result.append(item)
	return result


# ============================================================
# 类型名 → GDScript 解析（headless / 运行时 ClassDB 未注册时回退）
# ============================================================

static func _resolve_script(type_name: String) -> GDScript:
	if _script_cache.has(type_name):
		return _script_cache[type_name]
	var script := _scan_for_script(type_name)
	_script_cache[type_name] = script
	return script


static func _scan_for_script(type_name: String) -> GDScript:
	for folder in _COMPONENT_FOLDERS:
		var script := _scan_folder_for_script(folder, type_name)
		if script != null:
			return script
	return null


static func _scan_folder_for_script(folder: String, type_name: String) -> GDScript:
	var dir := DirAccess.open(folder)
	if dir == null:
		return null
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := folder.path_join(file_name)
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				var sub := _scan_folder_for_script(full_path, type_name)
				if sub != null:
					dir.list_dir_end()
					return sub
		elif file_name.ends_with(".gd"):
			var script := load(full_path) as GDScript
			if script != null and script.get_global_name() == type_name:
				dir.list_dir_end()
				return script
		file_name = dir.get_next()
	dir.list_dir_end()
	return null


static func _script_inherits(script: GDScript, base_name: String) -> bool:
	var current := script
	while current != null:
		if current.get_global_name() == base_name:
			return true
		current = current.get_base_script()
	return false


# ============================================================
# 属性提示解析
# ============================================================

static func _find_property(obj: Object, property_name: String) -> Dictionary:
	var best := {}
	for prop in obj.get_property_list():
		if prop.get("name", "") == property_name:
			# 优先返回带类型提示的条目（数组/资源元素类信息通常在这里）
			if prop.get("hint", PROPERTY_HINT_NONE) != PROPERTY_HINT_NONE or prop.get("class_name", "") != "":
				return prop
			if best.is_empty():
				best = prop
	return best


static func _property_to_hint(prop: Dictionary) -> Dictionary:
	var prop_type: int = prop.get("type", TYPE_NIL)
	var hint: int = prop.get("hint", PROPERTY_HINT_NONE)
	var hint_string: String = prop.get("hint_string", "")
	var class_name_str: String = prop.get("class_name", "")

	if prop_type == TYPE_OBJECT:
		var target_class := hint_string if hint == PROPERTY_HINT_RESOURCE_TYPE and hint_string != "" else class_name_str
		if target_class != "":
			return {"kind": "object", "class": target_class}

	if prop_type == TYPE_ARRAY:
		var element_class := ""
		if hint == PROPERTY_HINT_RESOURCE_TYPE:
			element_class = hint_string
		elif hint == PROPERTY_HINT_ARRAY_TYPE:
			element_class = _parse_array_hint_string(hint_string)
		elif hint == PROPERTY_HINT_TYPE_STRING:
			element_class = _parse_type_string_hint(hint_string)
		elif class_name_str != "":
			element_class = class_name_str
		if element_class != "":
			return {"kind": "array", "class": element_class}

	return {"kind": "", "class": ""}


static func _parse_array_hint_string(hint_string: String) -> String:
	var prefix := "Array["
	if hint_string.begins_with(prefix) and hint_string.ends_with("]"):
		return hint_string.substr(prefix.length(), hint_string.length() - prefix.length() - 1)
	return hint_string


static func _parse_type_string_hint(hint_string: String) -> String:
	# Godot 对 Array[SomeResource] 的提示格式为 "24/17:SomeClass"
	var colon_idx := hint_string.rfind(":")
	if colon_idx == -1:
		return ""
	return hint_string.substr(colon_idx + 1)


static func _is_nested_resource_class(class_name_str: String) -> bool:
	if class_name_str.is_empty():
		return false
	for base in _NESTED_BASE_CLASSES:
		if class_name_str == base or ClassDB.is_parent_class(class_name_str, base):
			return true
	return false
