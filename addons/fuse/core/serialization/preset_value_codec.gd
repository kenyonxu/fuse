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
		if value.resource_path != "":
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
	if not ClassDB.class_exists(type_name):
		push_warning("PresetValueCodec: 未知类型 '%s'" % type_name)
		return null

	if expected_base != "" and not ClassDB.is_parent_class(type_name, expected_base):
		push_warning("PresetValueCodec: 类型 '%s' 不继承 '%s'" % [type_name, expected_base])
		return null

	var inst := ClassDB.instantiate(type_name) as Resource
	if inst == null:
		push_warning("PresetValueCodec: 无法实例化 '%s'" % type_name)
		return null

	for key in data:
		if key == "type":
			continue
		inst.set(key, deserialize_value(inst, key, data[key]))

	return inst


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
# 属性提示解析
# ============================================================

static func _find_property(obj: Object, property_name: String) -> Dictionary:
	for prop in obj.get_property_list():
		if prop.get("name", "") == property_name:
			return prop
	return {}


static func _property_to_hint(prop: Dictionary) -> Dictionary:
	var prop_type: int = prop.get("type", TYPE_NIL)
	var hint: int = prop.get("hint", PROPERTY_HINT_NONE)
	var hint_string: String = prop.get("hint_string", "")

	if prop_type == TYPE_OBJECT and hint == PROPERTY_HINT_RESOURCE_TYPE:
		return {"kind": "object", "class": hint_string}

	if prop_type == TYPE_ARRAY:
		var element_class := ""
		if hint == PROPERTY_HINT_RESOURCE_TYPE:
			element_class = hint_string
		elif hint == PROPERTY_HINT_ARRAY_TYPE:
			element_class = _parse_array_hint_string(hint_string)
		if element_class != "":
			return {"kind": "array", "class": element_class}

	return {"kind": "", "class": ""}


static func _parse_array_hint_string(hint_string: String) -> String:
	var prefix := "Array["
	if hint_string.begins_with(prefix) and hint_string.ends_with("]"):
		return hint_string.substr(prefix.length(), hint_string.length() - prefix.length() - 1)
	return hint_string


static func _is_nested_resource_class(class_name_str: String) -> bool:
	if class_name_str.is_empty():
		return false
	for base in _NESTED_BASE_CLASSES:
		if class_name_str == base or ClassDB.is_parent_class(class_name_str, base):
			return true
	return false
