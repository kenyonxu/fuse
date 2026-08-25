@tool
class_name TypeConverter
extends RefCounted

## 类型转换器类
## 提供安全的类型转换和兼容性检查功能

## 类型转换映射
static var _type_converters: Dictionary = {}
static var _compatibility_matrix: Dictionary = {}
static var _type_names: Dictionary = {}
static var _type_descriptions: Dictionary = {}

## 初始化静态数据
static func _static_init():
    if _type_converters.is_empty():
        _setup_converters()
        _setup_compatibility_matrix()
        _setup_type_names()
        _setup_type_descriptions()

## 设置转换器
static func _setup_converters():
    _type_converters = {
        TYPE_BOOL: func(value): return safe_convert_to_bool(value),
        TYPE_INT: func(value): return safe_convert_to_int(value),
        TYPE_FLOAT: func(value): return safe_convert_to_float(value),
        TYPE_STRING: func(value): return safe_convert_to_string(value),
        TYPE_VECTOR2: func(value): return safe_convert_to_vector2(value),
        TYPE_VECTOR3: func(value): return safe_convert_to_vector3(value),
        TYPE_COLOR: func(value): return safe_convert_to_color(value),
        TYPE_NODE_PATH: func(value): return safe_convert_to_node_path(value),
        TYPE_ARRAY: func(value): return safe_convert_to_array(value),
        TYPE_DICTIONARY: func(value): return safe_convert_to_dictionary(value)
    }

## 设置兼容性矩阵
static func _setup_compatibility_matrix():
    _compatibility_matrix = {
        # 数值类型互相兼容
        "INT_FLOAT": true, "FLOAT_INT": true,
        "INT_BOOL": true, "FLOAT_BOOL": true,
        "BOOL_INT": true, "BOOL_FLOAT": true,

        # 字符串与基础类型兼容
        "STRING_INT": true, "STRING_FLOAT": true,
        "STRING_BOOL": true, "STRING_VECTOR2": true,
        "STRING_VECTOR3": true, "STRING_COLOR": true,

        # 向量类型部分兼容
        "VECTOR2_VECTOR3": true, "VECTOR3_VECTOR2": true,
        "VECTOR2I_VECTOR2": true, "VECTOR3I_VECTOR3": true,

        # 数组与容器兼容
        "ARRAY_ARRAY": true, "STRING_ARRAY": true,
        "DICTIONARY_STRING": true, "STRING_DICTIONARY": true,

        # NodePath 与字符串兼容
        "NODE_PATH_STRING": true, "STRING_NODE_PATH": true,

        # 所有类型都可以转换为字符串（避免重复）
        "INT_STRING": true, "FLOAT_STRING": true,
        "BOOL_STRING": true, "VECTOR2_STRING": true,
        "VECTOR3_STRING": true, "COLOR_STRING": true,
        "ARRAY_STRING": true,
        "OBJECT_STRING": true
    }

## 设置类型名称映射
static func _setup_type_names():
    _type_names = {
        TYPE_NIL: "NIL",
        TYPE_BOOL: "BOOL",
        TYPE_INT: "INT",
        TYPE_FLOAT: "FLOAT",
        TYPE_STRING: "STRING",
        TYPE_VECTOR2: "VECTOR2",
        TYPE_VECTOR2I: "VECTOR2I",
        TYPE_VECTOR3: "VECTOR3",
        TYPE_VECTOR3I: "VECTOR3I",
        TYPE_COLOR: "COLOR",
        TYPE_ARRAY: "ARRAY",
        TYPE_DICTIONARY: "DICTIONARY",
        TYPE_OBJECT: "OBJECT",
        TYPE_NODE_PATH: "NODE_PATH",
        TYPE_PACKED_BYTE_ARRAY: "PACKED_BYTE_ARRAY",
        TYPE_PACKED_INT32_ARRAY: "PACKED_INT32_ARRAY",
        TYPE_PACKED_FLOAT32_ARRAY: "PACKED_FLOAT32_ARRAY",
        TYPE_PACKED_STRING_ARRAY: "PACKED_STRING_ARRAY",
        TYPE_PACKED_VECTOR2_ARRAY: "PACKED_VECTOR2_ARRAY",
        TYPE_PACKED_VECTOR3_ARRAY: "PACKED_VECTOR3_ARRAY",
        TYPE_PACKED_COLOR_ARRAY: "PACKED_COLOR_ARRAY"
    }

## 设置类型描述
static func _setup_type_descriptions():
    _type_descriptions = {
        TYPE_NIL: "空值",
        TYPE_BOOL: "布尔值",
        TYPE_INT: "整数",
        TYPE_FLOAT: "浮点数",
        TYPE_STRING: "字符串",
        TYPE_VECTOR2: "二维向量",
        TYPE_VECTOR2I: "整数二维向量",
        TYPE_VECTOR3: "三维向量",
        TYPE_VECTOR3I: "整数三维向量",
        TYPE_COLOR: "颜色",
        TYPE_ARRAY: "数组",
        TYPE_DICTIONARY: "字典",
        TYPE_OBJECT: "对象",
        TYPE_NODE_PATH: "节点路径",
        TYPE_PACKED_BYTE_ARRAY: "字节数组",
        TYPE_PACKED_INT32_ARRAY: "整数数组",
        TYPE_PACKED_FLOAT32_ARRAY: "浮点数数组",
        TYPE_PACKED_STRING_ARRAY: "字符串数组",
        TYPE_PACKED_VECTOR2_ARRAY: "二维向量数组",
        TYPE_PACKED_VECTOR3_ARRAY: "三维向量数组",
        TYPE_PACKED_COLOR_ARRAY: "颜色数组"
    }

## 安全转换为指定类型
static func safe_convert(value: Variant, target_type: int) -> Variant:
    _static_init()

    if typeof(value) == target_type:
        return value

    match target_type:
        TYPE_BOOL:
            return safe_convert_to_bool(value)
        TYPE_INT:
            return safe_convert_to_int(value)
        TYPE_FLOAT:
            return safe_convert_to_float(value)
        TYPE_STRING:
            return safe_convert_to_string(value)
        TYPE_VECTOR2:
            return safe_convert_to_vector2(value)
        TYPE_VECTOR3:
            return safe_convert_to_vector3(value)
        TYPE_COLOR:
            return safe_convert_to_color(value)
        TYPE_NODE_PATH:
            return safe_convert_to_node_path(value)
        TYPE_ARRAY:
            return safe_convert_to_array(value)
        TYPE_DICTIONARY:
            return safe_convert_to_dictionary(value)
        _:
            push_warning("不支持的转换类型: " + get_type_name(target_type))
            return value

## 安全转换为布尔值
static func safe_convert_to_bool(value: Variant) -> bool:
    match typeof(value):
        TYPE_BOOL:
            return value
        TYPE_INT:
            return value != 0
        TYPE_FLOAT:
            return value != 0.0
        TYPE_STRING:
            var str_val = (value as String).to_lower().strip_edges()
            if str_val in ["true", "1", "yes", "on", "是", "真"]:
                return true
            elif str_val in ["false", "0", "no", "off", "否", "假"]:
                return false
            else:
                return str_val.is_empty() == false
        TYPE_NIL:
            return false
        _:
            return value != null

## 安全转换为整数
static func safe_convert_to_int(value: Variant) -> int:
    match typeof(value):
        TYPE_INT:
            return value
        TYPE_FLOAT:
            return int(value)
        TYPE_BOOL:
            return 1 if value else 0
        TYPE_STRING:
            var str_val = (value as String).strip_edges()
            if str_val.is_valid_int():
                return str_val.to_int()
            elif str_val.is_valid_float():
                return int(str_val.to_float())
            else:
                return 0
        TYPE_NIL:
            return 0
        _:
            return 0

## 安全转换为浮点数
static func safe_convert_to_float(value: Variant) -> float:
    match typeof(value):
        TYPE_FLOAT:
            return value
        TYPE_INT:
            return float(value)
        TYPE_BOOL:
            return 1.0 if value else 0.0
        TYPE_STRING:
            var str_val = (value as String).strip_edges()
            if str_val.is_valid_float():
                return str_val.to_float()
            else:
                return 0.0
        TYPE_NIL:
            return 0.0
        _:
            return 0.0

## 安全转换为字符串
static func safe_convert_to_string(value: Variant) -> String:
    if value == null:
        return ""
    return str(value)

## 安全转换为 Vector2
static func safe_convert_to_vector2(value: Variant) -> Vector2:
    match typeof(value):
        TYPE_VECTOR2:
            return value
        TYPE_VECTOR2I:
            return Vector2(value.x, value.y)
        TYPE_VECTOR3:
            return Vector2(value.x, value.y)
        TYPE_VECTOR3I:
            return Vector2(value.x, value.y)
        TYPE_STRING:
            return _parse_vector2_string(value)
        TYPE_ARRAY:
            if value.size() >= 2:
                return Vector2(value[0], value[1])
            else:
                return Vector2.ZERO
        TYPE_COLOR:
            return Vector2(value.r, value.g)
        _:
            return Vector2.ZERO

## 安全转换为 Vector3
static func safe_convert_to_vector3(value: Variant) -> Vector3:
    match typeof(value):
        TYPE_VECTOR3:
            return value
        TYPE_VECTOR3I:
            return Vector3(value.x, value.y, value.z)
        TYPE_VECTOR2:
            return Vector3(value.x, value.y, 0)
        TYPE_VECTOR2I:
            return Vector3(value.x, value.y, 0)
        TYPE_STRING:
            return _parse_vector3_string(value)
        TYPE_ARRAY:
            if value.size() >= 3:
                return Vector3(value[0], value[1], value[2])
            elif value.size() >= 2:
                return Vector3(value[0], value[1], 0)
            else:
                return Vector3.ZERO
        TYPE_COLOR:
            return Vector3(value.r, value.g, value.b)
        _:
            return Vector3.ZERO

## 安全转换为 Color
static func safe_convert_to_color(value: Variant) -> Color:
    match typeof(value):
        TYPE_COLOR:
            return value
        TYPE_STRING:
            return _parse_color_string(value)
        TYPE_INT, TYPE_FLOAT:
            # 数值转换为灰度
            var gray = clamp(float(value) / 255.0, 0.0, 1.0)
            return Color(gray, gray, gray, 1.0)
        TYPE_VECTOR3:
            return Color(value.x, value.y, value.z, 1.0)
        TYPE_VECTOR3I:
            return Color(float(value.x) / 255.0, float(value.y) / 255.0, float(value.z) / 255.0, 1.0)
        _:
            return Color.WHITE

## 安全转换为 NodePath
static func safe_convert_to_node_path(value: Variant) -> NodePath:
    match typeof(value):
        TYPE_NODE_PATH:
            return value
        TYPE_STRING:
            return NodePath(value)
        _:
            return NodePath("")

## 安全转换为 Array
static func safe_convert_to_array(value: Variant) -> Array:
    match typeof(value):
        TYPE_ARRAY:
            return value
        TYPE_STRING:
            # 尝试解析 JSON 数组
            var json = JSON.new()
            var parse_result = json.parse(value)
            if parse_result == OK and json.data is Array:
                return json.data
            else:
                return [value]
        TYPE_DICTIONARY:
            # 将字典转换为键值对数组
            var dict = value as Dictionary
            var result = []
            for key in dict:
                result.append([key, dict[key]])
            return result
        _:
            return [value]

## 安全转换为 Dictionary
static func safe_convert_to_dictionary(value: Variant) -> Dictionary:
    match typeof(value):
        TYPE_DICTIONARY:
            return value
        TYPE_STRING:
            # 尝试解析 JSON 对象
            var json = JSON.new()
            var parse_result = json.parse(value)
            if parse_result == OK and json.data is Dictionary:
                return json.data
            else:
                return {"value": value}
        TYPE_ARRAY:
            # 将数组转换为字典（索引作为键）
            var arr = value as Array
            var result = {}
            for i in range(arr.size()):
                result[i] = arr[i]
            return result
        _:
            return {"value": value}

## 解析 Vector2 字符串
static func _parse_vector2_string(str_val: String) -> Vector2:
    var parts = str_val.split(",")
    if parts.size() != 2:
        return Vector2.ZERO

    var x = safe_convert_to_float(parts[0].strip_edges())
    var y = safe_convert_to_float(parts[1].strip_edges())
    return Vector2(x, y)

## 解析 Vector3 字符串
static func _parse_vector3_string(str_val: String) -> Vector3:
    var parts = str_val.split(",")
    if parts.size() < 2:
        return Vector3.ZERO

    var x = safe_convert_to_float(parts[0].strip_edges())
    var y = safe_convert_to_float(parts[1].strip_edges())
    var z = 0.0
    if parts.size() >= 3:
        z = safe_convert_to_float(parts[2].strip_edges())

    return Vector3(x, y, z)

## 解析颜色字符串
static func _parse_color_string(str_val: String) -> Color:
    var clean_str = str_val.strip_edges()

    # 处理十六进制颜色
    if clean_str.begins_with("#"):
        return Color.from_string(clean_str, Color.WHITE)

    # 处理 HTML 颜色名
    var named_colors = {
        "white": Color.WHITE, "black": Color.BLACK, "red": Color.RED,
        "green": Color.GREEN, "blue": Color.BLUE, "yellow": Color.YELLOW,
        "cyan": Color.CYAN, "magenta": Color.MAGENTA, "gray": Color.GRAY,
        "grey": Color.GRAY
    }

    var lower_str = clean_str.to_lower()
    if named_colors.has(lower_str):
        return named_colors[lower_str]

    # 处理 RGB 字符串 "r,g,b"
    var parts = clean_str.split(",")
    if parts.size() >= 3:
        var r = clamp(safe_convert_to_float(parts[0]), 0.0, 1.0)
        var g = clamp(safe_convert_to_float(parts[1]), 0.0, 1.0)
        var b = clamp(safe_convert_to_float(parts[2]), 0.0, 1.0)
        var a = 1.0
        if parts.size() >= 4:
            a = clamp(safe_convert_to_float(parts[3]), 0.0, 1.0)
        return Color(r, g, b, a)

    return Color.WHITE

## 检查类型兼容性
static func is_compatible(source_type: int, target_type: int) -> bool:
    _static_init()

    if source_type == target_type:
        return true

    # 检查兼容性矩阵
    var source_name = get_type_name(source_type)
    var target_name = get_type_name(target_type)
    var key = "%s_%s" % [source_name, target_name]
    return _compatibility_matrix.get(key, false)

## 获取类型名称
static func get_type_name(type: int) -> String:
    _static_init()

    if _type_names.has(type):
        return _type_names[type]
    return "UNKNOWN"

## 获取类型描述
static func get_type_description(type: int) -> String:
    _static_init()

    if _type_descriptions.has(type):
        return _type_descriptions[type]
    return "未知类型"

## 获取所有支持的类型
static func get_supported_types() -> Array[int]:
    _static_init()
    return _type_names.keys()

## 检查值是否可以转换为目标类型
static func can_convert(value: Variant, target_type: int) -> bool:
    return is_compatible(typeof(value), target_type)

## 尝试转换，失败时返回默认值
static func try_convert(value: Variant, target_type: int, default_value: Variant = null) -> Variant:
    if can_convert(value, target_type):
        return safe_convert(value, target_type)
    return default_value

## 获取转换建议
static func get_conversion_suggestions(source_type: int, target_type: int) -> String:
    if is_compatible(source_type, target_type):
        return "可以直接转换"

    var source_name = get_type_name(source_type)
    var target_name = get_type_name(target_type)

    match source_name + "_" + target_name:
        "STRING_VECTOR2":
            return "字符串格式应为 'x,y'，例如 '1.0,2.0'"
        "STRING_VECTOR3":
            return "字符串格式应为 'x,y,z'，例如 '1.0,2.0,3.0'"
        "STRING_COLOR":
            return "支持十六进制 (#FF0000) 或 RGB 格式 'r,g,b'"
        _:
            return "不支持此类型转换"

## 调试信息
static func get_debug_info() -> String:
    _static_init()
    return "TypeConverter - 支持 %d 种类型，%d 种转换规则" % [_type_names.size(), _compatibility_matrix.size()]