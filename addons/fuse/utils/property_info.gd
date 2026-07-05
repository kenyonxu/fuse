@tool
class_name PropertyInfo
extends RefCounted

## 属性信息结构类
## 用于封装和管理节点属性的元数据信息

## 属性基本信息
var name: String                           ## 属性名称
var type: int = TYPE_NIL                 ## 属性类型 (Godot TYPE_*)
var hint: PropertyHint = PROPERTY_HINT_NONE  ## 属性提示
var hint_string: String = ""                 ## 提示字符串
var usage: PropertyUsageFlags = 0           ## 使用标志
var default_value: Variant = null             ## 默认值
var class_type: String = ""                 ## 类名（用于对象类型）

## 扩展信息
var category: String = ""                    ## 属性分类
var description: String = ""                 ## 属性描述
var is_read_only: bool = false              ## 是否只读
var is_internal: bool = false               ## 是否内部属性（以下划线开头）
var is_exported: bool = false               ## 是否导出属性
var is_script_variable: bool = false         ## 是否脚本变量

## 验证信息
var min_value: Variant = null                 ## 最小值（数值类型）
var max_value: Variant = null                 ## 最大值（数值类型）
var step: float = 0.0                        ## 步长（数值类型）
var is_array_fixed_size: bool = false        ## 数组是否固定大小
var array_size: int = 0                     ## 数组大小（固定时）

## 构造函数
func _init():
    pass

## 从属性字典创建 PropertyInfo
static func create(property_dict: Dictionary) -> PropertyInfo:
    var info = PropertyInfo.new()
    info.name = property_dict.get("name", "")
    info.type = property_dict.get("type", TYPE_NIL)
    info.hint = property_dict.get("hint", PROPERTY_HINT_NONE)
    info.hint_string = property_dict.get("hint_string", "")
    info.usage = property_dict.get("usage", 0)
    info.default_value = property_dict.get("default_value", null)
    info.class_type = property_dict.get("class_name", "")
    
    # 解析扩展信息
    info._parse_extended_info(property_dict)
    
    return info

## 从节点属性创建 PropertyInfo
static func from_node_property(node: Node, property_name: String) -> PropertyInfo:
    var property_list = node.get_property_list()
    for prop_dict in property_list:
        if prop_dict.name == property_name:
            return create(prop_dict)
    
    # 如果找不到属性，返回空信息
    var empty_info = PropertyInfo.new()
    empty_info.name = property_name
    empty_info.is_read_only = true
    return empty_info

## 解析扩展信息
func _parse_extended_info(property_dict: Dictionary):
    # 分析使用标志
    _parse_usage_flags(property_dict.usage)
    
    # 分析类型特定信息
    _parse_type_specific_info(property_dict)
    
    # 分析提示信息
    _parse_hint_info(property_dict)

## 解析使用标志
func _parse_usage_flags(usage: int):
    is_exported = usage & PROPERTY_USAGE_EDITOR != 0
    is_read_only = usage & PROPERTY_USAGE_READ_ONLY != 0
    is_script_variable = usage & PROPERTY_USAGE_SCRIPT_VARIABLE != 0
    is_internal = name.begins_with("_")

## 解析类型特定信息
func _parse_type_specific_info(property_dict: Dictionary):
    match type:
        TYPE_INT, TYPE_FLOAT:
            _parse_numeric_info(property_dict)
        TYPE_STRING:
            _parse_string_info(property_dict)
        TYPE_ARRAY:
            _parse_array_info(property_dict)
        TYPE_OBJECT:
            _parse_object_info(property_dict)

## 解析数值信息
func _parse_numeric_info(property_dict: Dictionary):
    if property_dict.has("min_value"):
        min_value = property_dict.min_value
    if property_dict.has("max_value"):
        max_value = property_dict.max_value
    if property_dict.has("step"):
        step = property_dict.step

## 解析字符串信息
func _parse_string_info(property_dict: Dictionary):
    if property_dict.has("length"):
        max_value = property_dict.length

## 解析数组信息
func _parse_array_info(property_dict: Dictionary):
    if property_dict.has("array_size"):
        is_array_fixed_size = true
        array_size = property_dict.array_size

## 解析对象信息
func _parse_object_info(property_dict: Dictionary):
    # 对象类型可能有额外的类名信息
    if property_dict.has("class_name"):
        class_type = property_dict.class_name

## 解析提示信息
func _parse_hint_info(property_dict: Dictionary):
    # 根据提示类型解析额外的验证信息
    match hint:
        PROPERTY_HINT_RANGE:
            _parse_range_hint(hint_string)
        PROPERTY_HINT_ENUM:
            _parse_enum_hint(hint_string)
        PROPERTY_HINT_FLAGS:
            _parse_flags_hint(hint_string)

## 解析范围提示
func _parse_range_hint(hint_str: String):
    var parts = hint_str.split(",")
    if parts.size() >= 2:
        min_value = parts[0].to_float()
        max_value = parts[1].to_float()
        if parts.size() >= 3:
            step = parts[2].to_float()

## 解析枚举提示
func _parse_enum_hint(hint_str: String):
    # 枚举提示字符串格式: "选项1:值1,选项2:值2"
    # 这里可以解析为可用的枚举值
    pass

## 解析标志提示
func _parse_flags_hint(hint_str: String):
    # 标志提示字符串格式: "标志1:值1,标志2:值2"
    # 这里可以解析为可用的标志值
    pass

## 检查属性是否可写
func is_writable() -> bool:
    return not is_read_only and not is_internal

## 检查属性是否可读
func is_readable() -> bool:
    return not is_internal

## 检查属性是否为数值类型
func is_numeric() -> bool:
    return type in [TYPE_INT, TYPE_FLOAT]

## 检查属性是否为容器类型
func is_container() -> bool:
    return type in [TYPE_ARRAY, TYPE_DICTIONARY]

## 检查属性是否为向量类型
func is_vector() -> bool:
    return type in [TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I]

## 检查属性是否为颜色类型
func is_color() -> bool:
    return type == TYPE_COLOR

## 检查属性是否为字符串类型
func is_string() -> bool:
    return type == TYPE_STRING

## 检查属性是否为布尔类型
func is_bool() -> bool:
    return type == TYPE_BOOL

## 检查属性是否为对象类型
func is_object() -> bool:
    return type == TYPE_OBJECT

## 检查属性是否为节点路径类型
func is_node_path() -> bool:
    return type == TYPE_NODE_PATH

## 获取类型名称
func get_type_name() -> String:
    # OBJECT 类型优先显示具体类名（如 SpriteFrames, Material）
    if type == TYPE_OBJECT and not class_type.is_empty():
        return class_type
    var tc_name = TypeConverter.get_type_name(type)
    if tc_name == "UNKNOWN":
        # 使用 GDScript 内置函数兜底（覆盖 Transform2D, Rect2 等）
        return type_string(type)
    return tc_name

## 获取显示名称
func get_display_name() -> String:
    if not description.is_empty():
        return description
    return name.capitalize()

## 验证值是否适合此属性
func validate_value(value: Variant) -> Dictionary:
    var result = {"valid": true, "error": "", "converted_value": value}
    
    # 类型检查
    if not TypeConverter.is_compatible(typeof(value), type):
        result.valid = false
        result.error = "类型不兼容：期望 %s，实际 %s" % [
            get_type_name(), TypeConverter.get_type_name(typeof(value))
        ]
        return result
    
    # 数值范围检查
    if is_numeric():
        result = _validate_numeric_range(value)
    
    # 字符串长度检查
    if type == TYPE_STRING and max_value != null:
        var str_value = str(value)
        if str_value.length() > max_value:
            result.valid = false
            result.error = "字符串长度超过限制：%d/%d" % [str_value.length(), max_value]
    
    # 数组大小检查
    if type == TYPE_ARRAY and is_array_fixed_size and array_size > 0:
        if value is Array and value.size() != array_size:
            result.valid = false
            result.error = "数组大小不匹配：期望 %d，实际 %d" % [array_size, value.size()]
    
    return result

## 验证数值范围
func _validate_numeric_range(value: Variant) -> Dictionary:
    var result = {"valid": true, "error": "", "converted_value": value}
    
    var num_value: float
    if typeof(value) == TYPE_INT:
        num_value = float(value)
    elif typeof(value) == TYPE_FLOAT:
        num_value = value
    else:
        # 尝试转换
        num_value = TypeConverter.safe_convert_to_float(value)
        if num_value == null:
            result.valid = false
            result.error = "无法转换为数值"
            return result
    
    if min_value != null and num_value < min_value:
        result.valid = false
        result.error = "值小于最小值：%f < %f" % [num_value, min_value]
    elif max_value != null and num_value > max_value:
        result.valid = false
        result.error = "值大于最大值：%f > %f" % [num_value, max_value]
    
    return result

## 获取属性摘要信息
func get_summary() -> String:
    var parts = []
    parts.append("名称: " + name)
    parts.append("类型: " + get_type_name())
    
    if is_writable():
        parts.append("可写")
    if is_read_only:
        parts.append("只读")
    if is_internal:
        parts.append("内部")
    if is_exported:
        parts.append("导出")
    
    if is_numeric() and (min_value != null or max_value != null):
        var range_str = "范围: "
        if min_value != null:
            range_str += str(min_value)
        range_str += " - "
        if max_value != null:
            range_str += str(max_value)
        parts.append(range_str)
    
    return " | ".join(parts)

## 转换为字典
func to_dict() -> Dictionary:
    return {
        "name": name,
        "type": type,
        "hint": hint,
        "hint_string": hint_string,
        "usage": usage,
        "default_value": default_value,
        "class_type": class_type,
        "category": category,
        "description": description,
        "is_read_only": is_read_only,
        "is_internal": is_internal,
        "is_exported": is_exported,
        "is_script_variable": is_script_variable,
        "min_value": min_value,
        "max_value": max_value,
        "step": step,
        "is_array_fixed_size": is_array_fixed_size,
        "array_size": array_size
    }

## 从字典恢复
func from_dict(data: Dictionary):
    name = data.get("name", "")
    type = data.get("type", TYPE_NIL)
    hint = data.get("hint", PROPERTY_HINT_NONE)
    hint_string = data.get("hint_string", "")
    usage = data.get("usage", 0)
    default_value = data.get("default_value", null)
    class_type = data.get("class_name", "")
    category = data.get("category", "")
    description = data.get("description", "")
    is_read_only = data.get("is_read_only", false)
    is_internal = data.get("is_internal", false)
    is_exported = data.get("is_exported", false)
    is_script_variable = data.get("is_script_variable", false)
    min_value = data.get("min_value", null)
    max_value = data.get("max_value", null)
    step = data.get("step", 0.0)
    is_array_fixed_size = data.get("is_array_fixed_size", false)
    array_size = data.get("array_size", 0)