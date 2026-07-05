# EventOnTargetSignalEmit 事件设计文档

## 概述

`EventOnTargetSignalEmit` 是一个新的事件类，用于监听指定节点的特定信号并在信号发出时触发事件。这个事件类允许用户动态选择目标节点和该节点的任意信号，提供了极大的灵活性。

## 设计目标

1. **动态信号发现**: 能够自动发现目标节点的所有可用信号
2. **类型安全**: 正确处理信号的参数类型
3. **编辑器友好**: 提供直观的编辑器界面
4. **性能优化**: 高效的信号连接和断开机制
5. **错误处理**: 完善的错误检查和报告
6. **可复用性**: 通过独立的 SignalInfo 类实现信号信息的复用

## 核心类设计

### 1. SignalInfo 通用类

首先创建一个独立的 `SignalInfo` 类来处理信号信息，这个类可以在整个项目中复用：

**文件位置**: `addons/bricks/utils/signal_info.gd`

```gdscript
# 文件：addons/bricks/utils/signal_info.gd
@tool
class_name SignalInfo extends Resource

## 信号名称
var name: String = ""

## 信号参数信息数组
var args: Array[Dictionary] = []

## 默认参数值
var default_args: Array[Variant] = []

## 信号标志
var flags: int = 0

## 所属节点类型（用于缓存和过滤）
var owner_class_name: String = ""

## 信号描述（可选）
var description: String = ""

## 从 Godot 信号字典创建 SignalInfo
static func from_godot_signal(signal_dict: Dictionary, class_name: String = "") -> SignalInfo:
    var signal_info = SignalInfo.new()
    signal_info.name = signal_dict.name
    signal_info.args = signal_dict.args if signal_dict.has("args") else []
    signal_info.default_args = signal_dict.get("default_args", [])
    signal_info.flags = signal_dict.get("flags", 0)
    signal_info.owner_class_name = class_name
    return signal_info

## 获取信号的完整签名
func get_signature() -> String:
    var args_str = []
    for i in range(args.size()):
        var arg = args[i]
        var type_str = _get_type_string(arg.type)
        var arg_name = arg.name if arg.has("name") else "arg%d" % i
        
        # 添加默认值信息
        if i < default_args.size():
            args_str.append("%s: %s = %s" % [arg_name, type_str, str(default_args[i])])
        else:
            args_str.append("%s: %s" % [arg_name, type_str])
    
    return "%s(%s)" % [name, ", ".join(args_str)]

## 获取简短的显示名称
func get_display_name() -> String:
    if args.is_empty():
        return name
    return "%s(%d)" % [name, args.size()]

## 获取参数类型字符串数组
func get_arg_type_strings() -> Array[String]:
    var type_strings: Array[String] = []
    for arg in args:
        type_strings.append(_get_type_string(arg.type))
    return type_strings

## 检查参数数量是否匹配
func has_arg_count(count: int) -> bool:
    return args.size() == count

## 检查参数类型是否兼容
func are_args_compatible(arg_types: Array[int]) -> bool:
    if args.size() != arg_types.size():
        return false
    
    for i in range(args.size()):
        if not _are_types_compatible(args[i].type, arg_types[i]):
            return false
    
    return true

## 验证信号参数值
func validate_args(values: Array[Variant]) -> bool:
    if values.size() > args.size():
        return false
    
    for i in range(values.size()):
        if not _is_value_valid_for_type(values[i], args[i].type):
            return false
    
    return true

## 获取参数的属性列表（用于编辑器）
func get_arg_property_list() -> Array[Dictionary]:
    var properties = []
    
    for i in range(args.size()):
        var arg = args[i]
        var property = {
            "name": "arg_%d" % i,
            "type": arg.type,
            "usage": PROPERTY_USAGE_DEFAULT
        }
        
        # 添加提示信息
        if arg.has("hint"):
            property["hint"] = arg.hint
        if arg.has("hint_string"):
            property["hint_string"] = arg.hint_string
        
        properties.append(property)
    
    return properties

## 创建参数上下文字典
func create_arg_context(values: Array[Variant]) -> Dictionary:
    var context = {}
    
    for i in range(min(values.size(), args.size())):
        var arg = args[i]
        var arg_name = arg.name if arg.has("name") else "arg%d" % i
        context[arg_name] = values[i]
    
    return context

## 序列化信号信息
func serialize() -> Dictionary:
    return {
        "name": name,
        "args": args,
        "default_args": default_args,
        "flags": flags,
        "owner_class_name": owner_class_name,
        "description": description
    }

## 从字典反序列化
func deserialize(data: Dictionary):
    name = data.get("name", "")
    args = data.get("args", [])
    default_args = data.get("default_args", [])
    flags = data.get("flags", 0)
    owner_class_name = data.get("owner_class_name", "")
    description = data.get("description", "")

## 私有方法：获取类型字符串
func _get_type_string(type: int) -> String:
    match type:
        TYPE_NIL: return "Variant"
        TYPE_BOOL: return "bool"
        TYPE_INT: return "int"
        TYPE_FLOAT: return "float"
        TYPE_STRING: return "String"
        TYPE_VECTOR2: return "Vector2"
        TYPE_VECTOR2I: return "Vector2i"
        TYPE_VECTOR3: return "Vector3"
        TYPE_VECTOR3I: return "Vector3i"
        TYPE_COLOR: return "Color"
        TYPE_ARRAY: return "Array"
        TYPE_DICTIONARY: return "Dictionary"
        TYPE_OBJECT: return "Object"
        TYPE_NODE_PATH: return "NodePath"
        TYPE_PACKED_BYTE_ARRAY: return "PackedByteArray"
        TYPE_PACKED_INT32_ARRAY: return "PackedInt32Array"
        TYPE_PACKED_FLOAT32_ARRAY: return "PackedFloat32Array"
        TYPE_PACKED_STRING_ARRAY: return "PackedStringArray"
        _: return "Variant"

## 私有方法：检查类型兼容性
func _are_types_compatible(type1: int, type2: int) -> bool:
    # 完全匹配
    if type1 == type2:
        return true
    
    # 数值类型兼容性
    var numeric_types = [TYPE_INT, TYPE_FLOAT]
    if type1 in numeric_types and type2 in numeric_types:
        return true
    
    # 向量类型兼容性
    var vector2_types = [TYPE_VECTOR2, TYPE_VECTOR2I]
    var vector3_types = [TYPE_VECTOR3, TYPE_VECTOR3I]
    
    if type1 in vector2_types and type2 in vector2_types:
        return true
    
    if type1 in vector3_types and type2 in vector3_types:
        return true
    
    # 字符串可以接受任何类型
    if type1 == TYPE_STRING or type2 == TYPE_STRING:
        return true
    
    return false

## 私有方法：检查值是否对类型有效
func _is_value_valid_for_type(value: Variant, type: int) -> bool:
    if value == null:
        return type == TYPE_NIL or type == TYPE_OBJECT
    
    var value_type = typeof(value)
    return _are_types_compatible(value_type, type)
```

### 2. SignalManager 通用类

为了更好地管理信号信息，创建一个 SignalManager 类：

**文件位置**: `addons/bricks/utils/signal_manager.gd`

```gdscript
# 文件：addons/bricks/utils/signal_manager.gd
@tool
class_name SignalManager extends RefCounted

## 信号信息缓存
static var _signal_cache: Dictionary = {}

## 获取节点的所有信号信息
static func get_node_signals(node: Node) -> Array[SignalInfo]:
    if not node:
        return []
    
    var cache_key = _get_cache_key(node)
    if _signal_cache.has(cache_key):
        return _signal_cache[cache_key]
    
    var signals: Array[SignalInfo] = []
    var signal_list = node.get_signal_list()
    var class_name = node.get_class()
    
    for signal_dict in signal_list:
        var signal_info = SignalInfo.from_godot_signal(signal_dict, class_name)
        signals.append(signal_info)
    
    # 缓存结果
    _signal_cache[cache_key] = signals
    
    return signals

## 根据名称查找信号信息
static func find_signal_by_name(node: Node, signal_name: String) -> SignalInfo:
    var signals = get_node_signals(node)
    
    for signal_info in signals:
        if signal_info.name == signal_name:
            return signal_info
    
    return null

## 检查节点是否有指定信号
static func has_signal(node: Node, signal_name: String) -> bool:
    return find_signal_by_name(node, signal_name) != null

## 获取信号名称列表
static func get_signal_names(node: Node) -> Array[String]:
    var signals = get_node_signals(node)
    var names: Array[String] = []
    
    for signal_info in signals:
        names.append(signal_info.name)
    
    return names

## 获取信号显示名称列表
static func get_signal_display_names(node: Node) -> Array[String]:
    var signals = get_node_signals(node)
    var display_names: Array[String] = []
    
    for signal_info in signals:
        display_names.append(signal_info.get_display_name())
    
    return display_names

## 清理指定节点的缓存
static func clear_cache_for_node(node: Node):
    if not node:
        return
    
    var cache_key = _get_cache_key(node)
    if _signal_cache.has(cache_key):
        _signal_cache.erase(cache_key)

## 清理所有缓存
static func clear_all_cache():
    _signal_cache.clear()

## 获取缓存统计信息
static func get_cache_stats() -> Dictionary:
    return {
        "cached_nodes": _signal_cache.size(),
        "total_signals": _get_total_signal_count()
    }

## 私有方法：生成缓存键
static func _get_cache_key(node: Node) -> String:
    if not node:
        return ""
    
    # 使用节点路径和类名作为缓存键
    var node_path = node.get_path()
    var class_name = node.get_class()
    return "%s:%s" % [node_path, class_name]

## 私有方法：获取总信号数量
static func _get_total_signal_count() -> int:
    var total = 0
    for signals in _signal_cache.values():
        total += signals.size()
    return total
```

### 3. EventOnTargetSignalEmit 事件类

**文件位置**: `addons/bricks/events/event_on_target_signal_emit.gd`

```gdscript
# 文件：addons/bricks/events/event_on_target_signal_emit.gd
@tool
@icon("res://addons/bricks/icons/event.svg")
class_name EventOnTargetSignalEmit extends BaseEvent

## 目标节点路径（相对于 Trigger 节点）
@export var target_node_path: NodePath:
    set(value):
        target_node_path = value
        _update_resource_name()
        _clear_signal_cache()
        notify_property_list_changed()

## 目标信号名称
@export var target_signal: String = "":
    set(value):
        target_signal = value
        _update_resource_name()
        _update_signal_info()
        notify_property_list_changed()

## 是否只触发一次
@export var trigger_once: bool = false:
    set(value):
        trigger_once = value
        _update_resource_name()
        notify_property_list_changed()

## 信号参数过滤（可选）
@export var filter_signal_args: bool = false:
    set(value):
        filter_signal_args = value
        _update_resource_name()
        notify_property_list_changed()

## 参数过滤值（当 filter_signal_args 为 true 时使用）
@export var arg_filter_values: Array[Variant] = []:
    set(value):
        arg_filter_values = value
        _update_resource_name()

# 运行时状态
var _target_node: Node = null
var _signal_info: SignalInfo = null
var _has_triggered: bool = false
var _available_signals: Array[SignalInfo] = []

## 更新资源名称
func _update_resource_name():
    var parts = []
    
    parts.append("信号监听")
    
    if not target_node_path.is_empty():
        parts.append("→ %s" % target_node_path.get_name(target_node_path.get_name_count() - 1))
    else:
        parts.append("→ 未选择节点")
    
    if not target_signal.is_empty():
        if _signal_info:
            parts.append(":: %s" % _signal_info.get_display_name())
        else:
            parts.append(":: %s" % target_signal)
    else:
        parts.append(":: 未选择信号")
    
    if trigger_once:
        parts.append("[仅一次]")
    
    resource_name = " ".join(parts)

## 获取动态属性列表
func _get_property_list() -> Array[Dictionary]:
    var properties = []
    
    # 目标节点选择
    properties.append({
        "name": "target_node_path",
        "type": TYPE_NODE_PATH,
        "hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
        "hint_string": "Node",
        "usage": PROPERTY_USAGE_DEFAULT
    })
    
    # 信号选择
    if _has_valid_target_node():
        var signal_names = _get_signal_names()
        if not signal_names.is_empty():
            properties.append({
                "name": "target_signal",
                "type": TYPE_STRING,
                "hint": PROPERTY_HINT_ENUM,
                "hint_string": ",".join(signal_names),
                "usage": PROPERTY_USAGE_DEFAULT
            })
        else:
            properties.append({
                "name": "target_signal",
                "type": TYPE_STRING,
                "hint": PROPERTY_HINT_PLACEHOLDER_TEXT,
                "hint_string": "目标节点没有可用信号",
                "usage": PROPERTY_USAGE_READ_ONLY
            })
    else:
        properties.append({
            "name": "target_signal",
            "type": TYPE_STRING,
            "hint": PROPERTY_HINT_PLACEHOLDER_TEXT,
            "hint_string": "请先选择目标节点",
            "usage": PROPERTY_USAGE_READ_ONLY
        })
    
    # 基础选项
    properties.append({
        "name": "trigger_once",
        "type": TYPE_BOOL,
        "usage": PROPERTY_USAGE_DEFAULT
    })
    
    properties.append({
        "name": "filter_signal_args",
        "type": TYPE_BOOL,
        "usage": PROPERTY_USAGE_DEFAULT
    })
    
    # 参数过滤配置
    if filter_signal_args and _signal_info:
        var arg_properties = _get_arg_filter_properties()
        properties.append_array(arg_properties)
    
    return properties

## 初始化事件
func initialize(owner_node: Node) -> void:
    _log_debug("初始化 EventOnTargetSignalEmit")
    
    if not owner_node:
        _create_bricks_error("Owner 节点为空", BricksError.ErrorType.CONFIGURATION_ERROR)
        return
    
    # 获取目标节点
    _target_node = _get_target_node_from_path(owner_node)
    if not _target_node:
        _create_bricks_error("无法找到目标节点: %s" % target_node_path, BricksError.ErrorType.CONFIGURATION_ERROR)
        return
    
    # 验证信号
    if target_signal.is_empty():
        _create_bricks_error("未指定目标信号", BricksError.ErrorType.CONFIGURATION_ERROR)
        return
    
    # 检查信号是否存在
    if not SignalManager.has_signal(_target_node, target_signal):
        _create_bricks_error("目标节点没有信号: %s" % target_signal, BricksError.ErrorType.CONFIGURATION_ERROR)
        return
    
    # 连接信号
    if not _target_node.is_connected(target_signal, _on_target_signal_emitted):
        var connect_result = _target_node.connect(target_signal, _on_target_signal_emitted)
        if connect_result != OK:
            _create_bricks_error("连接信号失败: %s (错误码: %d)" % [target_signal, connect_result], BricksError.ErrorType.RUNTIME_ERROR)
            return
    
    _log_debug("成功连接到信号: %s.%s" % [_target_node.name, target_signal])

## 终止事件
func terminate(owner_node: Node) -> void:
    _log_debug("清理 EventOnTargetSignalEmit")
    
    # 断开信号连接
    if _target_node and is_instance_valid(_target_node):
        if _target_node.is_connected(target_signal, _on_target_signal_emitted):
            _target_node.disconnect(target_signal, _on_target_signal_emitted)
            _log_debug("已断开信号连接: %s.%s" % [_target_node.name, target_signal])
    
    # 重置状态
    _target_node = null
    _signal_info = null
    _has_triggered = false
    _clear_signal_cache()

## 信号处理函数
func _on_target_signal_emitted(...args) -> void:
    _log_debug("接收到信号: %s，参数: %s" % [target_signal, args])
    
    # 检查是否只触发一次
    if trigger_once and _has_triggered:
        _log_debug("已触发过，跳过")
        return
    
    # 参数过滤检查
    if filter_signal_args and not _check_signal_args(args):
        _log_debug("参数过滤检查失败，跳过")
        return
    
    _has_triggered = true
    _log_info("触发信号事件: %s.%s" % [_target_node.name, target_signal])
    
    # 将信号参数作为上下文传递
    var context = _create_signal_context(args)
    triggered.emit(context)

## 获取事件描述
func get_description() -> String:
    var node_name = target_node_path.get_name(target_node_path.get_name_count() - 1) if not target_node_path.is_empty() else "未选择节点"
    var signal_name = target_signal if not target_signal.is_empty() else "未选择信号"
    var once_text = " (仅一次)" if trigger_once else ""
    
    return "当 %s 节点发出 %s 信号时触发%s" % [node_name, signal_name, once_text]

## 获取事件类型
func get_event_type() -> String:
    return "target_signal_emit"

## 获取事件分类
func get_event_category() -> String:
    return "signal"

## 验证配置
func validate() -> Array[String]:
    var errors: Array[String] = []
    
    if target_node_path.is_empty():
        errors.append("必须指定目标节点")
    
    if target_signal.is_empty():
        errors.append("必须指定目标信号")
    
    return errors

## 重置状态
func reset() -> void:
    super.reset()
    _has_triggered = false
    _log_debug("EventOnTargetSignalEmit 状态已重置")

# 私有方法实现

## 检查是否有有效的目标节点
func _has_valid_target_node() -> bool:
    return not target_node_path.is_empty()

## 获取信号名称列表
func _get_signal_names() -> Array[String]:
    if _available_signals.is_empty():
        _refresh_signal_cache()
    
    var names: Array[String] = []
    for signal_info in _available_signals:
        names.append(signal_info.name)
    
    return names

## 刷新信号缓存
func _refresh_signal_cache():
    if not _has_valid_target_node():
        _available_signals.clear()
        return
    
    # 这里需要一个临时的目标节点来获取信号信息
    # 在实际实现中，可能需要在运行时获取
    _available_signals = []
    _update_signal_info()

## 更新信号信息
func _update_signal_info():
    if not target_signal.is_empty() and not _available_signals.is_empty():
        for signal_info in _available_signals:
            if signal_info.name == target_signal:
                _signal_info = signal_info
                return
    
    _signal_info = null

## 获取目标节点
func _get_target_node_from_path(owner_node: Node) -> Node:
    if target_node_path.is_empty():
        return null
    
    return owner_node.get_node_or_null(target_node_path)

## 检查信号参数
func _check_signal_args(args: Array) -> bool:
    if not _signal_info or args.size() != arg_filter_values.size():
        return false
    
    for i in range(args.size()):
        if args[i] != arg_filter_values[i]:
            return false
    
    return true

## 创建信号上下文
func _create_signal_context(args: Array) -> Dictionary:
    var context = {
        "source_node": _target_node,
        "signal_name": target_signal,
        "signal_args": args
    }
    
    # 如果有信号信息，添加参数名称
    if _signal_info:
        context["named_args"] = _signal_info.create_arg_context(args)
    
    return context

## 获取参数过滤属性
func _get_arg_filter_properties() -> Array[Dictionary]:
    if not _signal_info:
        return []
    
    return _signal_info.get_arg_property_list()

## 清理信号缓存
func _clear_signal_cache():
    _available_signals.clear()
    _signal_info = null
```

## 使用示例

### 基本用法

```gdscript
# 监听 Button 的 pressed 信号
var event = EventOnTargetSignalEmit.new()
event.target_node_path = "../Button"
event.target_signal = "pressed"
event.trigger_once = true

# 监听 Timer 的 timeout 信号
var timer_event = EventOnTargetSignalEmit.new()
timer_event.target_node_path = "../Timer"
timer_event.target_signal = "timeout"
timer_event.trigger_once = false

# 监听 Area2D 的 body_entered 信号并过滤参数
var area_event = EventOnTargetSignalEmit.new()
area_event.target_node_path = "../Area2D"
area_event.target_signal = "body_entered"
area_event.filter_signal_args = true
area_event.arg_filter_values = [player_node]  # 只响应玩家进入
```

### 高级用法

```gdscript
# 在脚本中使用
extends Node

@export var signal_event: EventOnTargetSignalEmit

func _ready():
    if signal_event:
        signal_event.triggered.connect(_on_signal_triggered)
        signal_event.initialize(self)

func _on_signal_triggered(context: Dictionary):
    print("信号触发: ", context.signal_name)
    print("参数: ", context.signal_args)
    
    if context.has("named_args"):
        print("命名参数: ", context.named_args)
```

## 性能优化

1. **信号缓存**: SignalManager 提供信号信息缓存
2. **延迟连接**: 只在需要时连接信号
3. **及时断开**: 在 terminate 时及时断开信号连接
4. **内存管理**: 正确清理内部状态和引用

## 错误处理

1. **节点不存在**: 提供清晰的错误信息
2. **信号不存在**: 验证信号是否可用
3. **连接失败**: 处理信号连接错误
4. **参数不匹配**: 检查参数过滤配置

## 扩展性

1. **参数过滤**: 支持基于信号参数的过滤
2. **信号转换**: 可以扩展支持信号参数的转换
3. **多信号监听**: 未来可以扩展支持同时监听多个信号
4. **条件触发**: 可以添加额外的触发条件

## 测试计划

1. **基础功能测试**: 测试基本的信号监听功能
2. **SignalInfo 测试**: 测试信号信息类的正确性
3. **SignalManager 测试**: 测试信号管理器的缓存和查询功能
4. **编辑器测试**: 测试编辑器界面的正确性
5. **性能测试**: 测试大量信号监听的性能
6. **错误处理测试**: 测试各种错误情况的处理
7. **内存泄漏测试**: 确保没有内存泄漏

## 总结

`EventOnTargetSignalEmit` 事件类通过使用独立的 `SignalInfo` 和 `SignalManager` 类，实现了一个强大而灵活的信号监听机制。这种设计不仅满足了当前的需求，还为未来的扩展和复用提供了良好的基础。通过动态信号发现、类型安全的参数处理和完善的错误处理，它为开发者提供了一个可靠的事件监听解决方案。