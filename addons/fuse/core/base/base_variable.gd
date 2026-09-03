@tool
@icon("res://addons/fuse/icons/variable.svg")
class_name BaseVariable extends Resource

## 动态属性列表
##
## 显式返回 Array[Dictionary]，避免 Godot 4.x 使用 Resource 基类的 Array 返回类型
## 触发 "_get_property_list() should return Array[Dictionary]" 兼容性警告。
func _get_property_list() -> Array[Dictionary]:
    return []

## 变量配置
@export_group("Variable Configuration")
@export var variable_name: String = "":
    set(value):
        variable_name = value
        _log_debug("Variable name set to: %s" % value)

## 变量值 - 直接使用 Godot Variant
## setter 唯一负责 emit（value_changed + value_modified）+ 计数/时间。
## set_value 与其它赋值路径不再 emit/计数，避免双发与计数翻倍（B1/B2/B3）。
@export var value: Variant = null:
    set(new_value):
        var old_value = value
        value = new_value
        last_modified_time = Time.get_ticks_msec() / 1000.0
        modification_count += 1
        _log_debug("Variable value changed from %s to %s" % [str(old_value), str(new_value)])
        value_changed.emit(old_value, new_value)
        value_modified.emit(new_value)

## 变量描述
@export var description: String = ""

## 日志级别配置
@export var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.INFO  ## 日志输出级别

## 工厂配置
@export_group("Factory Configuration")
@export var scope: int = VariableScope.LOCAL:
    set(value):
        scope = value
        _update_resource_name()

@export var persistent: bool = false
@export var auto_create: bool = false
@export var access_count: int = 0
var creation_time: float = 0.0

## 变量作用域枚举
enum VariableScope {
    LOCAL = 0,      ## 局部变量（ExecutionContext）
    SCOPE = 1,      ## 作用域变量（ScopeVariableContainer）
    GLOBAL = 2      ## 全局变量（GlobalVariableAssistant）
}

## 持久化配置 (已废弃 - 请使用 GlobalVariableManager)
## @deprecated 这些常量用于旧的 ConfigFile 持久化系统，不推荐在新项目中使用
const STORAGE_SECTION = "variables"
const STORAGE_CONFIG_PATH = "user://fuse_variables.cfg"

## 变量状态
var last_modified_time: float = 0.0
var modification_count: int = 0
var is_initialized: bool = false
var _fuse_error: FuseError = null     ## FuseError 实例，用于统一错误处理

## 常量
const DEFAULT_VALUE = null

## 变量值改变信号
signal value_changed(old_value: Variant, new_value: Variant)
signal value_modified(value: Variant)
signal variable_reset()

## 初始化变量
func _init():
    # 注意：不要在这里调用 reset()，因为 value 可能还没有设置
    # 改为直接初始化基本状态
    last_modified_time = Time.get_ticks_msec() / 1000.0
    modification_count = 0
    is_initialized = false  # 初始为 false，等待显式初始化
    _fuse_error = null
    creation_time = Time.get_ticks_msec() / 1000.0

## 记录上次更新 resource_name 时使用的语言
## 用于检测编辑器语言是否发生变化，以便自动刷新资源名称
var _last_locale: String = ""

## 拦截属性设置，处理 resource_name 的语言自动更新
## （机制与 base_instruction/base_event/base_condition 保持一致）
func _set(property: StringName, value: Variant) -> bool:
    if property == "resource_name":
        FuseLocalization.init()
        var current_locale = FuseLocalization.get_locale_code()
        if _last_locale.is_empty() or current_locale != _last_locale:
            _last_locale = current_locale
            _update_resource_name()
            # 返回 true 声明"已处理"：阻止引擎把传入的旧值（如 .tscn 里
            # 烘焙的旧语言快照）写回 resource_name，覆盖刚重译的名称。
            return true
        _last_locale = current_locale
    return false

## 更新资源名称
func _update_resource_name():
    var scope_name = _get_scope_name(scope)
    var value_str = str(value)
    if value_str.length() > 20:
        value_str = value_str.substr(0, 17) + "..."

    resource_name = "%s [%s]: %s" % [variable_name, scope_name, value_str]

## 获取作用域名称
func _get_scope_name(scope_value: int) -> String:
    match scope_value:
        0: return "LOCAL"
        1: return "SCOPE"
        2: return "GLOBAL"
        _: return "UNKNOWN"

## 获取变量值
## returns: Variant - 变量当前值
func get_value() -> Variant:
    access_count += 1
    if not is_initialized:
        _initialize_value()

    return value

## 设置变量值
## new_value: Variant - 要设置的值
## returns: bool - 设置是否成功
## 注：setter 已统一负责 emit（value_changed + value_modified）与计数/时间，
## 这里只需赋值，避免重复 emit / 重复计数（修复 B2/B3）。
func set_value(new_value: Variant) -> bool:
    value = new_value
    # 注意：持久化已移至 GlobalVariableManager.save_to_resource()
    # 请使用 GlobalVariableAssistant 进行统一的持久化管理
    return true

## 重置变量为默认值
func reset():
    value = null
    last_modified_time = Time.get_ticks_msec() / 1000.0
    modification_count = 0
    is_initialized = true
    _fuse_error = null

    variable_reset.emit()

## 检查变量是否存在值
## returns: bool - 变量是否有值
func has_value() -> bool:
    return is_initialized and value != null

## 检查变量是否为空
## returns: bool - 变量是否为空
func is_empty() -> bool:
    return not has_value()

## 获取类型信息（使用 Godot 内置）
func get_type_name() -> String:
    return _type_to_string(typeof(value))

func get_godot_type() -> int:
    return typeof(value)

## 简化的类型转换
static func _type_to_string(type: int) -> String:
    match type:
        TYPE_NIL: return "Null"
        TYPE_BOOL: return "Bool"
        TYPE_INT: return "Int"
        TYPE_FLOAT: return "Float"
        TYPE_STRING: return "String"
        TYPE_VECTOR2: return "Vector2"
        TYPE_VECTOR3: return "Vector3"
        TYPE_COLOR: return "Color"
        TYPE_ARRAY: return "Array"
        TYPE_DICTIONARY: return "Dictionary"
        TYPE_OBJECT: return "Object"
        TYPE_NODE_PATH: return "NodePath"
        TYPE_PACKED_BYTE_ARRAY: return "PackedByteArray"
        TYPE_PACKED_INT32_ARRAY: return "PackedInt32Array"
        TYPE_PACKED_FLOAT32_ARRAY: return "PackedFloat32Array"
        TYPE_PACKED_STRING_ARRAY: return "PackedStringArray"
        TYPE_PACKED_VECTOR2_ARRAY: return "PackedVector2Array"
        TYPE_PACKED_VECTOR3_ARRAY: return "PackedVector3Array"
        TYPE_PACKED_COLOR_ARRAY: return "PackedColorArray"
        _: return "Unknown"

## 获取变量信息
## returns: Dictionary - 包含变量详细信息的字典
func get_info() -> Dictionary:
    var info = {
        "name": variable_name,
        "type": get_type_name(),
        "value": value,
        "persistent": persistent,
        "modification_count": modification_count,
        "last_modified_time": last_modified_time,
        "is_initialized": is_initialized
    }

    # 如果有 FuseError，添加错误信息
    if _fuse_error:
        info["fuse_error"] = _fuse_error.get_error_details()

    return info

## 初始化变量值
func _initialize_value():
    if not is_initialized:
        is_initialized = true

## 保存到持久化存储
## @deprecated 请使用 GlobalVariableManager.save_to_resource() 进行持久化
## 此方法保留用于向后兼容，但不推荐在新项目中使用
func _save_to_storage():
    if not persistent:
        _log_debug("变量未启用持久化，跳过保存")
        return

    var config = ConfigFile.new()

    # 加载现有配置
    if FileAccess.file_exists(STORAGE_CONFIG_PATH):
        var error = config.load(STORAGE_CONFIG_PATH)
        if error != OK:
            _log_warning("加载现有配置失败: %d，将覆盖" % error)

    # 使用改进的序列化方法
    var serialized = _serialize_value(value)
    config.set_value(STORAGE_SECTION, variable_name, serialized.data)
    config.set_value(STORAGE_SECTION, "%s_type" % variable_name, get_type_name())
    config.set_value(STORAGE_SECTION, "%s_format" % variable_name, serialized.format)
    config.set_value(STORAGE_SECTION, "%s_modified" % variable_name, last_modified_time)
    config.set_value(STORAGE_SECTION, "%s_count" % variable_name, modification_count)

    # 保存到文件
    var error = config.save(STORAGE_CONFIG_PATH)
    if error == OK:
        _log_debug("变量 '%s' 已保存到持久化存储 (格式: %s)" % [variable_name, serialized.format])
    else:
        _log_error("保存变量 '%s' 失败: %d" % [variable_name, error])

## 序列化变量值为可存储的字符串
## returns: Dictionary - 包含 data 和 format 的字典
func _serialize_value(val: Variant) -> Dictionary:
    var type = typeof(val)
    var result = {"data": "", "format": "string"}

    match type:
        TYPE_NIL:
            result.data = "null"
            result.format = "nil"

        TYPE_BOOL:
            result.data = str(val).to_lower()
            result.format = "bool"

        TYPE_INT:
            result.data = str(val)
            result.format = "int"

        TYPE_FLOAT:
            result.data = str(val)
            result.format = "float"

        TYPE_STRING:
            result.data = val
            result.format = "string"

        TYPE_VECTOR2:
            var v: Vector2 = val
            result.data = "%s,%s" % [v.x, v.y]
            result.format = "vector2"

        TYPE_VECTOR3:
            var v: Vector3 = val
            result.data = "%s,%s,%s" % [v.x, v.y, v.z]
            result.format = "vector3"

        TYPE_VECTOR4:
            # Godot 中没有 Vector4，但为了未来兼容性预留
            # Plane 类型会被识别为 TYPE_QUAT，这里预留接口
            result.data = str(val)
            result.format = "vector4"

        TYPE_COLOR:
            var c: Color = val
            result.data = "%s,%s,%s,%s" % [c.r, c.g, c.b, c.a]
            result.format = "color"

        TYPE_ARRAY:
            var json_string = JSON.stringify(val)
            if json_string != "":
                result.data = json_string
                result.format = "json_array"
            else:
                _log_error("序列化数组失败: %s" % str(val))
                result.data = "[]"
                result.format = "json_array"

        TYPE_DICTIONARY:
            var json_string = JSON.stringify(val)
            if json_string != "":
                result.data = json_string
                result.format = "json_dict"
            else:
                _log_error("序列化字典失败: %s" % str(val))
                result.data = "{}"
                result.format = "json_dict"

        TYPE_PACKED_BYTE_ARRAY:
            # 转换为十六进制字符串
            var packed: PackedByteArray = val
            result.data = Marshalls.raw_to_base64(packed)
            result.format = "base64_bytearray"

        TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_STRING_ARRAY:
            # 转换为 JSON 数组
            var json_string = JSON.stringify(Array(val))
            if json_string != "":
                result.data = json_string
                result.format = "json_packed_array"
            else:
                _log_error("序列化 PackedArray 失败: %s" % str(val))
                result.data = "[]"
                result.format = "json_packed_array"

        TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY:
            # 转换为 JSON 数组，每个元素单独序列化
            var array_data = []
            for element in val:
                var element_serialized = _serialize_value(element)
                array_data.append(element_serialized.data)

            var json_string = JSON.stringify(array_data)
            if json_string != "":
                result.data = json_string
                result.format = "json_vector_array"
            else:
                _log_error("序列化 Vector Array 失败: %s" % str(val))
                result.data = "[]"
                result.format = "json_vector_array"

        TYPE_NODE_PATH:
            result.data = str(val)
            result.format = "nodepath"

        _:
            # 其他类型使用 var_to_str
            result.data = var_to_str(val)
            result.format = "var_to_str"

    return result

## 从持久化存储加载
## @deprecated 请使用 GlobalVariableManager.load_from_resource() 进行加载
## 此方法保留用于向后兼容，但不推荐在新项目中使用
func _load_from_storage():
    if not FileAccess.file_exists(STORAGE_CONFIG_PATH):
        _log_debug("持久化存储文件不存在，跳过加载")
        return

    var config = ConfigFile.new()
    var error = config.load(STORAGE_CONFIG_PATH)

    if error != OK:
        _log_error("加载持久化存储失败: %d" % error)
        return

    # 检查变量是否存在
    if config.has_section_key(STORAGE_SECTION, variable_name):
        var value_str = config.get_value(STORAGE_SECTION, variable_name, "")
        var type_str = config.get_value(STORAGE_SECTION, "%s_type" % variable_name, "")

        # 优先使用新的格式标记，如果没有则回退到类型推断
        var format_str = config.get_value(STORAGE_SECTION, "%s_format" % variable_name, "")
        if format_str.is_empty():
            # 向后兼容：根据类型推断格式
            format_str = _infer_format_from_type(type_str)

        # 根据格式和类型解析值
        value = _parse_value_from_string(value_str, type_str, format_str)

        var modified = config.get_value(STORAGE_SECTION, "%s_modified" % variable_name, 0.0)
        last_modified_time = modified

        var count = config.get_value(STORAGE_SECTION, "%s_count" % variable_name, 0)
        modification_count = count

        is_initialized = true
        _log_debug("变量 '%s' 已从持久化存储加载: %s (格式: %s)" % [variable_name, str(value), format_str])
    else:
        _log_debug("变量 '%s' 不在持久化存储中" % variable_name)

## 从字符串解析值（改进版，支持格式标记）
func _parse_value_from_string(value_str: String, type_str: String, format_str: String) -> Variant:
    # 首先尝试根据格式解析
    match format_str:
        "nil":
            return null

        "bool":
            return _parse_bool(value_str)

        "int":
            return int(value_str)

        "float":
            return float(value_str)

        "string":
            return value_str

        "vector2":
            return _parse_vector2(value_str)

        "vector3":
            return _parse_vector3(value_str)

        "vector4":
            return _parse_vector4(value_str)

        "color":
            return _parse_color(value_str)

        "json_array":
            return _parse_json_array(value_str)

        "json_dict":
            return _parse_json_dict(value_str)

        "json_packed_array":
            return _parse_json_packed_array(value_str)

        "json_vector_array":
            return _parse_json_vector_array(value_str, type_str)

        "base64_bytearray":
            return _parse_base64_bytearray(value_str)

        "nodepath":
            return NodePath(value_str)

        "var_to_str":
            return str_to_var(value_str)

        _:
            # 回退到旧的类型推断方法（向后兼容）
            return _parse_value_legacy(value_str, type_str)

## 从类型推断格式（向后兼容）
func _infer_format_from_type(type_str: String) -> String:
    match type_str:
        "Null": return "nil"
        "Bool": return "bool"
        "Int": return "int"
        "Float": return "float"
        "String": return "string"
        "Vector2": return "vector2"
        "Vector3": return "vector3"
        "Color": return "color"
        "Array": return "json_array"
        "Dictionary": return "json_dict"
        "NodePath": return "nodepath"
        _: return "var_to_str"

## 旧版解析方法（向后兼容）
func _parse_value_legacy(value_str: String, type_str: String) -> Variant:
    match type_str:
        "Bool":
            return _parse_bool(value_str)
        "Int":
            return int(value_str)
        "Float":
            return float(value_str)
        "String":
            return value_str
        "Vector2":
            # 尝试旧格式 "(x, y)" 或新格式 "x,y"
            if value_str.begins_with("("):
                var parts = value_str.substr(1, value_str.length() - 2).split(", ")
                return Vector2(float(parts[0]), float(parts[1]))
            else:
                return _parse_vector2(value_str)
        "Vector3":
            # 尝试旧格式 "(x, y, z)" 或新格式 "x,y,z"
            if value_str.begins_with("("):
                var parts = value_str.substr(1, value_str.length() - 2).split(", ")
                return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
            else:
                return _parse_vector3(value_str)
        "Color":
            # 尝试旧格式 "(r, g, b, a)" 或新格式 "r,g,b,a"
            if value_str.begins_with("("):
                var parts = value_str.substr(1, value_str.length() - 2).split(", ")
                return Color(float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3]))
            else:
                return _parse_color(value_str)
        _:
            # 默认：尝试 str_to_var
            var result = str_to_var(value_str)
            if result == null and value_str != "null":
                _log_warning("无法解析值 '%s' (类型: %s)，使用默认值" % [value_str, type_str])
            return result

## 解析布尔值
func _parse_bool(value_str: String) -> bool:
    var lower_str = value_str.to_lower()
    if lower_str == "true" or lower_str == "1":
        return true
    elif lower_str == "false" or lower_str == "0":
        return false
    else:
        _log_warning("无法解析布尔值: '%s'，使用 false" % value_str)
        return false

## 解析 Vector2
func _parse_vector2(value_str: String) -> Vector2:
    var parts = value_str.split(",")
    if parts.size() >= 2:
        return Vector2(float(parts[0]), float(parts[1]))
    _log_warning("无法解析 Vector2: '%s'，使用 Vector2.ZERO" % value_str)
    return Vector2.ZERO

## 解析 Vector3
func _parse_vector3(value_str: String) -> Vector3:
    var parts = value_str.split(",")
    if parts.size() >= 3:
        return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
    _log_warning("无法解析 Vector3: '%s'，使用 Vector3.ZERO" % value_str)
    return Vector3.ZERO

## 解析 Vector4（用于 Plane 或未来类型）
func _parse_vector4(value_str: String) -> Variant:
    var parts = value_str.split(",")
    if parts.size() >= 4:
        # Godot 没有 Vector4，返回 Plane
        return Plane(float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3]))
    _log_warning("无法解析 Vector4: '%s'，使用 null" % value_str)
    return null

## 解析 Color
func _parse_color(value_str: String) -> Color:
    var parts = value_str.split(",")
    if parts.size() >= 4:
        return Color(float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3]))
    elif parts.size() == 3:
        # 如果只有 3 个值，alpha 默认为 1.0
        return Color(float(parts[0]), float(parts[1]), float(parts[2]), 1.0)
    _log_warning("无法解析 Color: '%s'，使用 Color.WHITE" % value_str)
    return Color.WHITE

## 解析 JSON 数组
func _parse_json_array(value_str: String) -> Array:
    var json = JSON.new()
    var error = json.parse(value_str)
    if error == OK:
        var data = json.get_data()
        if data is Array:
            return data
        else:
            _log_warning("JSON 不是数组类型: %s" % value_str)
            return []
    else:
        _log_error("解析 JSON 数组失败: %s (错误: %s)" % [value_str, json.get_error_message()])
        return []

## 解析 JSON 字典
func _parse_json_dict(value_str: String) -> Dictionary:
    var json = JSON.new()
    var error = json.parse(value_str)
    if error == OK:
        var data = json.get_data()
        if data is Dictionary:
            return data
        else:
            _log_warning("JSON 不是字典类型: %s" % value_str)
            return {}
    else:
        _log_error("解析 JSON 字典失败: %s (错误: %s)" % [value_str, json.get_error_message()])
        return {}

## 解析 JSON PackedArray
func _parse_json_packed_array(value_str: String) -> Variant:
    var array = _parse_json_array(value_str)
    # 根据内容返回合适的类型
    return array

## 解析 JSON Vector 数组
func _parse_json_vector_array(value_str: String, type_str: String) -> Variant:
    var array_data = _parse_json_array(value_str)

    match type_str:
        "PackedVector2Array":
            var packed_array = PackedVector2Array()
            for element in array_data:
                if element is String:
                    packed_array.append(_parse_vector2(element))
                elif element is Array:
                    packed_array.append(Vector2(float(element[0]), float(element[1])))
            return packed_array

        "PackedVector3Array":
            var packed_array = PackedVector3Array()
            for element in array_data:
                if element is String:
                    packed_array.append(_parse_vector3(element))
                elif element is Array:
                    packed_array.append(Vector3(float(element[0]), float(element[1]), float(element[2])))
            return packed_array

        "PackedColorArray":
            var packed_array = PackedColorArray()
            for element in array_data:
                if element is String:
                    packed_array.append(_parse_color(element))
                elif element is Array:
                    if element.size() >= 4:
                        packed_array.append(Color(float(element[0]), float(element[1]), float(element[2]), float(element[3])))
                    elif element.size() == 3:
                        packed_array.append(Color(float(element[0]), float(element[1]), float(element[2]), 1.0))
            return packed_array

        _:
            _log_warning("未知的 Vector 数组类型: %s" % type_str)
            return array_data

## 解析 Base64 编码的 ByteArray
func _parse_base64_bytearray(value_str: String) -> PackedByteArray:
    return Marshalls.base64_to_raw(value_str)

## 清理持久化存储中的变量
## @deprecated 请使用 GlobalVariableManager.remove_variable() 或 clear_all_variables()
## 此方法保留用于向后兼容，但不推荐在新项目中使用
func _clear_storage():
    if not FileAccess.file_exists(STORAGE_CONFIG_PATH):
        return

    var config = ConfigFile.new()
    var error = config.load(STORAGE_CONFIG_PATH)

    if error == OK:
        config.erase_section_key(STORAGE_SECTION, variable_name)
        config.erase_section_key(STORAGE_SECTION, "%s_type" % variable_name)
        config.erase_section_key(STORAGE_SECTION, "%s_format" % variable_name)
        config.erase_section_key(STORAGE_SECTION, "%s_modified" % variable_name)
        config.erase_section_key(STORAGE_SECTION, "%s_count" % variable_name)

        var save_error = config.save(STORAGE_CONFIG_PATH)
        if save_error == OK:
            _log_debug("已从持久化存储清理变量 '%s'" % variable_name)
        else:
            _log_error("清理持久化存储失败: %d" % save_error)

## 获取变量的调试信息
## returns: String - 调试信息字符串
func get_debug_info() -> String:
    var debug_info = "Variable: %s | Type: %s | Value: %s | Modified: %d times" % [
        variable_name,
        get_type_name(),
        str(value),
        modification_count
    ]

    # 如果有 FuseError，添加错误信息
    if _fuse_error:
        debug_info += " | Error: %s" % _fuse_error.get_formatted_message()

    return debug_info

## 统一日志方法
func _log_debug(message: String):
    FuseLogger.log_debug("BaseVariable", log_level, message, variable_name)

func _log_info(message: String):
    FuseLogger.log_info("BaseVariable", log_level, message, variable_name)

func _log_warning(message: String):
    FuseLogger.log_warning("BaseVariable", log_level, message, variable_name)

func _log_error(message: String):
    FuseLogger.log_error("BaseVariable", log_level, message, variable_name)

## 序列化变量
## returns: Dictionary - 序列化后的变量数据
func serialize() -> Dictionary:
    return {
        "name": variable_name,
        "value": value,
        "persistent": persistent,
        "modification_count": modification_count,
        "last_modified_time": last_modified_time
    }

## 反序列化变量
## data: Dictionary - 序列化的变量数据
func deserialize(data: Dictionary):
    if data.has("name"):
        variable_name = data["name"]

    if data.has("value"):
        value = data["value"]

    if data.has("persistent"):
        persistent = data["persistent"]

    if data.has("modification_count"):
        modification_count = data["modification_count"]

    if data.has("last_modified_time"):
        last_modified_time = data["last_modified_time"]

    is_initialized = true
    _log_debug("Variable deserialized: %s" % variable_name)

## 克隆变量
## returns: BaseVariable - 克隆的新变量
## 字段集与静态 clone_variable() 保持一致（B9：补齐 scope/auto_create/creation_time）
func clone() -> BaseVariable:
    var new_variable = BaseVariable.new()

    # 深拷贝所有属性
    new_variable.variable_name = variable_name
    new_variable.value = value
    new_variable.persistent = persistent
    new_variable.log_level = log_level
    new_variable.scope = scope
    new_variable.auto_create = auto_create
    new_variable.creation_time = Time.get_ticks_msec() / 1000.0
    new_variable.last_modified_time = last_modified_time
    new_variable.modification_count = modification_count
    new_variable.is_initialized = is_initialized

    _log_debug("Variable cloned: %s" % variable_name)
    return new_variable

## 检查变量是否等于指定值
## other_value: Variant - 要比较的值
## returns: bool - 是否相等
func equals(other_value: Variant) -> bool:
    return value == other_value

## 检查变量是否不等于指定值
## other_value: Variant - 要比较的值
## returns: bool - 是否不相等
func not_equals(other_value: Variant) -> bool:
    return value != other_value

## 检查变量是否大于指定值
## other_value: Variant - 要比较的值
## returns: bool - 是否大于
func greater_than(other_value: Variant) -> bool:
    var current_num = to_number()
    var compare_num = _convert_to_number(other_value)

    if current_num != 0.0 or compare_num != 0.0:  # 至少有一个不是0
        var result = current_num > compare_num
        _log_debug("Numeric comparison: %s > %s = %s" % [current_num, compare_num, result])
        return result

    _log_warning("Cannot compare %s with %s for greater_than operation" % [
        str(typeof(value)), str(typeof(other_value))
    ])
    return false

## 检查变量是否小于指定值
## other_value: Variant - 要比较的值
## returns: bool - 是否小于
func less_than(other_value: Variant) -> bool:
    var current_num = to_number()
    var compare_num = _convert_to_number(other_value)

    if current_num != 0.0 or compare_num != 0.0:  # 至少有一个不是0
        var result = current_num < compare_num
        _log_debug("Numeric comparison: %s < %s = %s" % [current_num, compare_num, result])
        return result

    _log_warning("Cannot compare %s with %s for less_than operation" % [
        str(typeof(value)), str(typeof(other_value))
    ])
    return false

## 将任意值转换为数字
## val: Variant - 要转换的值
## returns: float - 转换后的数字，如果无法转换则返回0
func _convert_to_number(val: Variant) -> float:
    match typeof(val):
        TYPE_INT:
            return float(val)
        TYPE_FLOAT:
            return val
        TYPE_STRING:
            var num = float(val)
            if not num.is_nan():
                return num
        TYPE_BOOL:
            return 1.0 if val else 0.0
        _:
            return 0.0
    return 0.0

## 检查变量是否大于等于指定值
## other_value: Variant - 要比较的值
## returns: bool - 是否大于等于
func greater_equal(other_value: Variant) -> bool:
    return greater_than(other_value) or equals(other_value)

## 检查变量是否小于等于指定值
## other_value: Variant - 要比较的值
## returns: bool - 是否小于等于
func less_equal(other_value: Variant) -> bool:
    return less_than(other_value) or equals(other_value)

## 获取变量字符串表示
## returns: String - 变量的字符串表示
func to_string() -> String:
    return str(value)

## 获取变量数值表示
## returns: float - 变量的数值表示，如果无法转换则返回0
func to_number() -> float:
    match typeof(value):
        TYPE_INT:
            return float(value)
        TYPE_FLOAT:
            return value
        TYPE_STRING:
            var num = float(value)
            if not num.is_nan():
                return num
        _:
            return 0.0
    return 0.0

## 获取变量布尔表示
## returns: bool - 变量的布尔表示
func to_bool() -> bool:
    match typeof(value):
        TYPE_BOOL:
            return value
        TYPE_INT:
            return value != 0
        TYPE_FLOAT:
            return value != 0.0
        TYPE_STRING:
            return not value.is_empty()
        _:
            return false

## 获取变量数组表示
## returns: Array - 变量的数组表示，如果无法转换则返回空数组
func to_array() -> Array:
    if typeof(value) == TYPE_ARRAY:
        return value
    return [value]

## 获取变量字典表示
## returns: Dictionary - 变量的字典表示，如果无法转换则返回空字典
func to_dict() -> Dictionary:
    if typeof(value) == TYPE_DICTIONARY:
        return value
    return {}

## 创建 FuseError 实例
## message: String - 错误消息
## error_type: FuseError.ErrorType - 错误类型
## context: Dictionary - 错误上下文
func _create_fuse_error(message: String, error_type: FuseError.ErrorType = FuseError.ErrorType.RUNTIME_ERROR, context: Dictionary = {}):
    var error_context = context.duplicate()
    error_context["variable_name"] = variable_name
    error_context["variable_type"] = get_type_name()

    _fuse_error = FuseError.new(error_type, "BaseVariable", message, "", error_context)

## 获取 FuseError 实例
## returns: FuseError - FuseError 实例，如果没有错误则返回 null
func get_fuse_error() -> FuseError:
    return _fuse_error

## 检查是否有 FuseError
## returns: bool - 是否有 FuseError
func has_fuse_error() -> bool:
    return _fuse_error != null

## ==================== 内置工厂模式 ====================

## 静态工厂方法 - 核心创建接口
## name: String - 变量名称
## val: Variant - 变量值
## scope: VariableScope - 变量作用域（默认为 LOCAL）
## returns: BaseVariable - 创建的变量实例
static func create(name: String, val: Variant, scope: VariableScope = VariableScope.LOCAL) -> BaseVariable:
    if name.is_empty():
        push_error("变量名称不能为空")
        return null

    var variable = BaseVariable.new()
    variable.variable_name = name
    variable.value = val
    variable.scope = scope
    variable.creation_time = Time.get_ticks_msec() / 1000.0

    # 根据作用域设置默认属性
    variable._configure_by_scope(scope)

    # 标记为已初始化
    variable.is_initialized = true

    return variable

## 静态工厂方法 - 便捷创建
## name: String - 变量名称
## val: Variant - 变量值
## returns: BaseVariable - 创建的局部变量实例
static func create_local(name: String, val: Variant) -> BaseVariable:
    return create(name, val, VariableScope.LOCAL)

## 静态工厂方法 - 便捷创建
## name: String - 变量名称
## val: Variant - 变量值
## persist: bool - 是否持久化（默认为 true）
## returns: BaseVariable - 创建的全局变量实例
static func create_global(name: String, val: Variant, persist: bool = true) -> BaseVariable:
    var variable = create(name, val, VariableScope.GLOBAL)
    variable.persistent = persist
    return variable

## 静态工厂方法 - 游戏常用变量
## health: float - 生命值（默认为 100.0）
## returns: BaseVariable - 创建的玩家生命值变量
static func create_player_health(health: float = 100.0) -> BaseVariable:
    return create_global("player_health", health, true)

## 静态工厂方法 - 游戏常用变量
## score: int - 分数（默认为 0）
## returns: BaseVariable - 创建的玩家分数变量
static func create_player_score(score: int = 0) -> BaseVariable:
    return create_global("player_score", score, true)

## 静态工厂方法 - 游戏常用变量
## level: int - 等级（默认为 1）
## returns: BaseVariable - 创建的玩家等级变量
static func create_player_level(level: int = 1) -> BaseVariable:
    return create_global("player_level", level, true)

## 静态工厂方法 - 游戏常用变量
## name: String - 变量名称（默认为 "temp_timer"）
## duration: float - 持续时间（默认为 0.0）
## returns: BaseVariable - 创建的临时计时器变量
static func create_temp_timer(name: String = "temp_timer", duration: float = 0.0) -> BaseVariable:
    return create_local(name, duration)

## 静态工厂方法 - 批量创建
## variables_data: Array - 变量数据数组，每个元素是包含 name, value, scope 的字典
## returns: Array[BaseVariable] - 创建的变量数组
static func create_batch(variables_data: Array) -> Array[BaseVariable]:
    var variables: Array[BaseVariable] = []

    for data in variables_data:
        if data is Dictionary:
            var name = data.get("name", "")
            var val = data.get("value", null)
            var scope = data.get("scope", VariableScope.LOCAL)

            if not name.is_empty():
                variables.append(create(name, val, scope))
            else:
                push_warning("批量创建变量时跳过空名称的变量")
        else:
            push_warning("批量创建变量时跳过无效的数据格式")

    return variables

## 静态工厂方法 - 从配置创建
## config: Dictionary - 配置字典，包含 name, value, scope 等属性
## returns: BaseVariable - 根据配置创建的变量
static func from_config(config: Dictionary) -> BaseVariable:
    if not config.has("name"):
        push_error("配置中缺少变量名称")
        return null

    var name = config["name"]
    var val = config.get("value", null)
    var scope_str = config.get("scope", "local").to_lower()

    # 解析作用域
    var scope = VariableScope.LOCAL
    match scope_str:
        "global":
            scope = VariableScope.GLOBAL
        "scope":
            scope = VariableScope.SCOPE
        "local":
            scope = VariableScope.LOCAL
        "trigger":
            push_warning("'trigger' 作用域已弃用，使用 'local' 代替")
            scope = VariableScope.LOCAL
        _:
            push_warning("未知的作用域 '%s'，使用默认值 LOCAL" % scope_str)

    var variable = create(name, val, scope)

    # 应用额外配置
    if config.has("persistent"):
        variable.persistent = config["persistent"]

    if config.has("auto_create"):
        variable.auto_create = config["auto_create"]

    if config.has("log_level"):
        variable.log_level = config["log_level"]

    return variable

## 静态工厂方法 - 克隆变量
## original: BaseVariable - 原始变量
## new_name: String - 新变量名称（可选，默认为空则使用原名称）
## returns: BaseVariable - 克隆的新变量
static func clone_variable(original: BaseVariable, new_name: String = "") -> BaseVariable:
    if not original:
        push_error("原始变量不能为空")
        return null

    var variable = BaseVariable.new()

    # 深拷贝所有属性
    variable.variable_name = new_name if not new_name.is_empty() else original.variable_name
    variable.value = original.value
    variable.persistent = original.persistent
    variable.log_level = original.log_level
    variable.scope = original.scope
    variable.auto_create = original.auto_create
    variable.creation_time = Time.get_ticks_msec() / 1000.0

    # 重置运行时状态
    variable.last_modified_time = original.last_modified_time
    variable.modification_count = original.modification_count
    variable.is_initialized = original.is_initialized

    return variable

## 私有方法 - 根据作用域配置默认属性
## scope: VariableScope - 变量作用域
func _configure_by_scope(scope: VariableScope):
    match scope:
        VariableScope.LOCAL:
            auto_create = true
            persistent = false
        VariableScope.SCOPE:
            auto_create = true
            persistent = false
        VariableScope.GLOBAL:
            auto_create = false
            persistent = true

## 获取创建信息
## returns: Dictionary - 包含创建信息的字典
func get_creation_info() -> Dictionary:
    return {
        "name": variable_name,
        "type": get_type_name(),
        "scope": VariableScope.keys()[scope],
        "creation_time": creation_time,
        "access_count": access_count,
        "persistent": persistent,
        "auto_create": auto_create,
        "modification_count": modification_count,
        "last_modified_time": last_modified_time
    }

## 验证配置
## returns: Array[String] - 配置错误信息数组
func validate_configuration() -> Array[String]:
    var errors: Array[String] = []

    if variable_name.is_empty():
        errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))

    # 全局变量持久化验证（简化方案：不再强制要求持久化，只作为建议）
    if scope == VariableScope.GLOBAL and not persistent:
        # 改为警告级别，不阻止变量创建
        _log_warning("全局变量 '%s' 未启用持久化，将在场景退出时被自动清理" % variable_name)

    return errors

## 析构函数
func _notification(what: int):
    if what == NOTIFICATION_PREDELETE:
        # 清理 FuseError
        _fuse_error = null
