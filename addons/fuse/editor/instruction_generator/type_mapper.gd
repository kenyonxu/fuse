# 文件：addons/fuse/editor/instruction_generator/type_mapper.gd
@tool
class_name TypeMapper extends RefCounted

## 类型映射器
## 复用 TypeConverter.get_type_name() 处理基础类型名
## 仅新增代码生成特有的功能：
##   - get_type_declaration(): Godot 类型 → GDScript @export 类型声明
##   - get_default_value(): 类型 → 默认值字符串
##   - get_export_annotation(): 类型/hint → @export 注解
##   - param_to_property(): 参数字典 → 完整属性声明行

## GDScript 类型声明（TypeConverter.get_type_name 返回的是大写标识符如 "VECTOR2"）
## 这里需要 GDScript 的 PascalCase 类型名
const GDSCRIPT_TYPE_NAMES := {
	TYPE_NIL: "Variant",
	TYPE_BOOL: "bool",
	TYPE_INT: "int",
	TYPE_FLOAT: "float",
	TYPE_STRING: "String",
	TYPE_VECTOR2: "Vector2",
	TYPE_VECTOR2I: "Vector2i",
	TYPE_VECTOR3: "Vector3",
	TYPE_VECTOR3I: "Vector3i",
	TYPE_VECTOR4: "Vector4",
	TYPE_VECTOR4I: "Vector4i",
	TYPE_COLOR: "Color",
	TYPE_RECT2: "Rect2",
	TYPE_RECT2I: "Rect2i",
	TYPE_TRANSFORM2D: "Transform2D",
	TYPE_TRANSFORM3D: "Transform3D",
	TYPE_BASIS: "Basis",
	TYPE_QUATERNION: "Quaternion",
	TYPE_ARRAY: "Array",
	TYPE_DICTIONARY: "Dictionary",
	TYPE_NODE_PATH: "NodePath",
	TYPE_STRING_NAME: "StringName",
	TYPE_RID: "RID",
	TYPE_OBJECT: "Object",
	TYPE_CALLABLE: "Callable",
	TYPE_SIGNAL: "Signal",
	TYPE_PACKED_BYTE_ARRAY: "PackedByteArray",
	TYPE_PACKED_INT32_ARRAY: "PackedInt32Array",
	TYPE_PACKED_INT64_ARRAY: "PackedInt64Array",
	TYPE_PACKED_FLOAT32_ARRAY: "PackedFloat32Array",
	TYPE_PACKED_FLOAT64_ARRAY: "PackedFloat64Array",
	TYPE_PACKED_STRING_ARRAY: "PackedStringArray",
	TYPE_PACKED_VECTOR2_ARRAY: "PackedVector2Array",
	TYPE_PACKED_VECTOR3_ARRAY: "PackedVector3Array",
	TYPE_PACKED_COLOR_ARRAY: "PackedColorArray",
}

## 获取类型的 GDScript 声明
## @param type: Variant 类型 ID
## @param hint: 属性提示
## @param hint_string: 提示字符串（可能包含类名）
## @return: 类型声明字符串（如 "int", "Texture2D", "Variant"）
static func get_type_declaration(type: int, hint: int = PROPERTY_HINT_NONE, hint_string: String = "") -> String:
	if type == TYPE_OBJECT and not hint_string.is_empty():
		return hint_string

	if hint == PROPERTY_HINT_ENUM and not hint_string.is_empty():
		return "int"

	if hint == PROPERTY_HINT_FLAGS and not hint_string.is_empty():
		return "int"

	if hint == PROPERTY_HINT_RESOURCE_TYPE and not hint_string.is_empty():
		return hint_string

	if GDSCRIPT_TYPE_NAMES.has(type):
		return GDSCRIPT_TYPE_NAMES[type]

	return "Variant"

## 获取类型的默认值字符串
static func get_default_value(type: int) -> String:
	if type == TYPE_OBJECT:
		return "null"

	match type:
		TYPE_NIL: return "null"
		TYPE_BOOL: return "false"
		TYPE_INT: return "0"
		TYPE_FLOAT: return "0.0"
		TYPE_STRING: return "\"\""
		TYPE_VECTOR2: return "Vector2.ZERO"
		TYPE_VECTOR2I: return "Vector2i.ZERO"
		TYPE_VECTOR3: return "Vector3.ZERO"
		TYPE_VECTOR3I: return "Vector3i.ZERO"
		TYPE_VECTOR4: return "Vector4.ZERO"
		TYPE_VECTOR4I: return "Vector4i.ZERO"
		TYPE_COLOR: return "Color.WHITE"
		TYPE_RECT2: return "Rect2()"
		TYPE_RECT2I: return "Rect2i()"
		TYPE_ARRAY: return "[]"
		TYPE_DICTIONARY: return "{}"
		TYPE_NODE_PATH: return "NodePath(\"\")"
		TYPE_STRING_NAME: return "&\"\""
		_: return "null"

## 获取 @export 注解
static func get_export_annotation(type: int, hint: int = PROPERTY_HINT_NONE, hint_string: String = "") -> String:
	if hint == PROPERTY_HINT_RANGE and not hint_string.is_empty():
		return "@export_range(\"%s\")" % hint_string
	if hint == PROPERTY_HINT_ENUM and not hint_string.is_empty():
		return "@export_enum(\"%s\")" % hint_string
	if hint == PROPERTY_HINT_FILE:
		return "@export_file(\"%s\")" % hint_string
	if hint == PROPERTY_HINT_DIR:
		return "@export_dir()"
	if hint == PROPERTY_HINT_GLOBAL_FILE:
		return "@export_global_file(\"%s\")" % hint_string
	if hint == PROPERTY_HINT_COLOR_NO_ALPHA:
		return "@export_color_no_alpha"
	return "@export"

## 将参数信息转换为完整的 @export 属性声明行
static func param_to_property(param: Dictionary) -> String:
	var param_name = param.get("name", "param")
	var type = param.get("type", TYPE_NIL)
	var hint = param.get("hint", PROPERTY_HINT_NONE)
	var hint_string = param.get("hint_string", "")
	var default_value = param.get("default_value", null)

	var export_annotation = get_export_annotation(type, hint, hint_string)
	var type_decl = get_type_declaration(type, hint, hint_string)

	var result = "%s var %s: %s" % [export_annotation, param_name, type_decl]

	if default_value != null:
		result += " = %s" % _value_to_string(default_value, type)
	else:
		result += " = %s" % get_default_value(type)

	return result

## 将值转换为 GDScript 代码字符串
static func value_to_string(value: Variant, type: int) -> String:
	if value == null:
		return "null"
	match type:
		TYPE_STRING:
			return "\"%s\"" % value
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_VECTOR2:
			return "Vector2(%s, %s)" % [value.x, value.y]
		TYPE_VECTOR3:
			return "Vector3(%s, %s, %s)" % [value.x, value.y, value.z]
		TYPE_COLOR:
			return "Color(%s, %s, %s, %s)" % [value.r, value.g, value.b, value.a]
		_:
			return str(value)

## 内部：将值转换为字符串（供 param_to_property 使用）
static func _value_to_string(value: Variant, type: int) -> String:
	return value_to_string(value, type)

## 将参数信息转换为变量绑定相关的属性声明
## 参考 math_operation.gd 的 operand_a_* 模式
## @param param: 参数字典
## @return: 属性声明行数组
static func param_to_variable_properties(param: Dictionary) -> Array[String]:
	var param_name = param.get("name", "param")
	var type = param.get("type", TYPE_NIL)
	var hint = param.get("hint", PROPERTY_HINT_NONE)
	var hint_string = param.get("hint_string", "")
	var type_decl = get_type_declaration(type, hint, hint_string)
	var default_val = get_default_value(type)

	var enum_name = param_name.to_pascal_case() + "Source"

	var lines: Array[String] = []
	lines.append("## %s 来源（VALUE=直接值 / VARIABLE=从变量读取）" % param_name)
	lines.append("enum %s { VALUE, VARIABLE }" % enum_name)
	lines.append("var %s_source: %s = %s.VALUE:\n\tset(v):\n\t\t%s_source = v\n\t\tnotify_property_list_changed()" % [param_name, enum_name, enum_name, param_name])
	lines.append("")
	lines.append("## %s 直接值" % param_name)
	lines.append("var %s_value: %s = %s" % [param_name, type_decl, default_val])
	lines.append("")
	lines.append("## %s 变量名" % param_name)
	lines.append("var %s_variable: String = \"\"" % param_name)
	lines.append("## %s 变量作用域" % param_name)
	lines.append("var %s_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:\n\tset(v):\n\t\t%s_scope = v\n\t\tnotify_property_list_changed()" % [param_name, param_name])
	lines.append("## %s 作用域来源（仅 SCOPE 时使用）" % param_name)
	lines.append("var %s_scope_source: VariableScopeUtils.ScopeSource = VariableScopeUtils.ScopeSource.NEAREST:\n\tset(v):\n\t\t%s_scope_source = v\n\t\tnotify_property_list_changed()" % [param_name, param_name])
	lines.append("## %s 自定义作用域 ID（CUSTOM_ID 模式使用）" % param_name)
	lines.append("var %s_custom_scope_id: String = \"\"" % param_name)
	lines.append("## %s 目标节点路径（TARGET_NODE 模式使用）" % param_name)
	lines.append("var %s_target_node_path: NodePath = NodePath(\"\")" % param_name)

	return lines
