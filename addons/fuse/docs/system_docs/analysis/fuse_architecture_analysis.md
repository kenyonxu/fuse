# Fuse 可视化编程系统架构分析报告

## 概述

Fuse 是一个为 Godot 4.x 设计的可视化编程系统插件，它提供了一个基于事件驱动的可视化编程框架，允许开发者通过拖拽和配置指令来创建游戏逻辑，而无需编写传统代码。本报告将深入分析 Fuse 系统的架构设计、核心组件、设计模式以及实现细节。

## 1. 系统整体架构

### 1.1 架构概览

Fuse 系统采用分层架构设计，主要包含以下层次：

```
┌─────────────────────────────────────────────────────────────┐
│                    编辑器工具层                              │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ │
│  │  指令选择器      │ │  静态分析工具    │ │  调试可视化工具   │ │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│                    业务逻辑层                                │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ │
│  │   指令系统       │ │   事件系统       │ │   条件系统       │ │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│                    核心服务层                                │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ │
│  │  执行上下文      │ │  动作执行器      │ │  变量管理器      │ │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│                    基础设施层                                │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ │
│  │   日志系统       │ │   错误处理       │ │   序列化系统     │ │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 核心设计原则

Fuse 系统遵循以下核心设计原则：

1. **事件驱动架构**：基于事件-触发器-动作的编程范式
2. **组件化设计**：高度模块化的组件，便于扩展和维护
3. **资源导向**：充分利用 Godot 的资源系统进行数据管理
4. **类型安全**：强类型检查和运行时验证
5. **性能优化**：智能缓存和内存管理机制
6. **可扩展性**：插件化架构支持自定义指令和事件

## 2. 核心组件分析

### 2.1 BaseInstruction - 指令基类

[`BaseInstruction`](addons/fuse/core/base/base_instruction.gd:1) 是所有指令的抽象基类，提供了指令执行的核心框架：

#### 2.1.1 生命周期管理

```gdscript
enum ExecutionStatus {
    PENDING,    # 等待执行
    RUNNING,    # 正在执行
    COMPLETED,  # 执行完成
    CANCELLED,  # 已取消
    ERROR       # 执行出错
}
```

指令具有完整的生命周期状态管理，从创建到完成的每个阶段都有明确的状态标识。

#### 2.1.2 智能执行模式

系统支持三种执行模式：

```gdscript
enum ExecutionMode {
    AUTO_DETECT,    # 自动检测执行模式（推荐）
    FORCE_ASYNC,    # 强制异步执行
    FORCE_SYNC      # 强制同步执行
}
```

特别值得注意的是 `AUTO_DETECT` 模式，系统能够通过静态代码分析自动判断指令是否可以同步执行：

```gdscript
func _detect_sync_capability() -> bool:
    var has_async = _has_async_operations()
    if has_async:
        return false
    
    var immediate = _has_immediate_completion()
    if immediate:
        return true
    
    return true
```

#### 2.1.3 超时管理

每个指令都支持超时机制，防止长时间运行的指令阻塞系统：

```gdscript
func set_timeout(timeout_seconds: float):
    _timeout_duration = max(0.0, timeout_seconds)

func _setup_timeout_timer():
    if not has_timeout():
        return
    
    _cleanup_timeout_timer()
    var scene_tree = Engine.get_main_loop()
    if scene_tree:
        _timeout_timer = scene_tree.create_timer(_timeout_duration)
        _timeout_timer.timeout.connect(_on_timeout)
```

### 2.2 ExecutionContext - 执行上下文

[`ExecutionContext`](addons/fuse/core/base/execution_context.gd:1) 是指令执行的环境容器，提供了丰富的上下文管理功能：

#### 2.2.1 变量管理系统

支持多层次的变量存储：

```gdscript
# 局部变量（指令执行期间有效）
var local_variables: Dictionary = {}

# 全局变量（整个应用程序生命周期中有效）
var global_variables = null

# 自定义数据存储
var custom_data: Dictionary = {}
```

#### 2.2.2 性能优化机制

系统实现了多种性能优化策略：

**StringName 缓存**：
```gdscript
var _variable_name_cache: Dictionary = {}

func _get_cached_name_key(name: String) -> StringName:
    if not _variable_name_cache.has(name):
        _variable_name_cache[name] = StringName(name)
    return _variable_name_cache[name]
```

**索引访问优化**：
```gdscript
var _variable_index_map: Dictionary = {}
var _variable_array: Array = []

func precompile_variable_access(variable_names: Array[String]):
    _variable_index_map.clear()
    _variable_array.clear()
    _variable_array.resize(variable_names.size())
    
    for i in range(variable_names.size()):
        var name_key = StringName(variable_names[i])
        _variable_index_map[name_key] = i
```

#### 2.2.3 WeakRef 内存管理

使用弱引用避免内存泄漏：

```gdscript
var _target_weakref: WeakRef = null
var _trigger_weakref: WeakRef = null

func set_target_node(node: Node):
    target = node
    _target_weakref = weakref(node) if node else null
```

### 2.3 ActionRunner - 动作执行器

[`ActionRunner`](addons/fuse/core/base/action_runner.gd:1) 负责管理和执行指令序列：

#### 2.3.1 执行模式

支持两种执行模式：

```gdscript
enum ExecutionMode {
    SEQUENTIAL,  # 顺序执行
    PARALLEL     # 并行执行
}
```

#### 2.3.2 智能同步优化

系统会自动检测指令是否可以同步执行，对于同步指令采用优化路径：

```gdscript
func _run_sequential(context: ExecutionContext):
    for i in range(instructions.size()):
        var instruction = instructions[i]
        var can_sync = instruction.can_execute_sync()
        
        if can_sync:
            var sync_result = instruction.execute_sync(context)
            if sync_result:
                # 同步执行成功，继续下一个指令
                continue
```

#### 2.3.3 条件检查支持

支持条件检查指令控制执行流程：

```gdscript
var _skip_instruction_count: int = 0  # 需要跳过的指令数量
var _stop_execution: bool = false     # 是否停止执行

# 在执行循环中
if _skip_instruction_count > 0:
    _skip_instruction_count -= 1
    continue

if _stop_execution:
    return
```

### 2.4 Trigger - 触发器系统

[`Trigger`](addons/fuse/core/trigger.gd:1) 是事件和动作之间的桥梁：

#### 2.4.1 内存优化

使用运行时事件实例避免不必要的资源复制：

```gdscript
var _runtime_event_instance: RuntimeEventInstance = null

func _ready():
    # 🚀 内存优化：使用 RuntimeEventInstance 替代资源复制
    _runtime_event_instance = RuntimeEventInstance.new(event_definition, self)
    event_definition.initialize_with_runtime_instance(self, _runtime_event_instance)
```

#### 2.4.2 事件处理

触发器负责连接事件和动作执行：

```gdscript
func _on_event_fired(context: Node) -> void:
    if trigger_once and has_triggered:
        return
        
    has_triggered = true
    
    if action_runner:
        var execution_context = _create_execution_context(context)
        action_runner.run(execution_context)
```

## 3. 条件系统

### 3.1 BaseCondition - 条件基类

[`BaseCondition`](addons/fuse/core/base/base_condition.gd:1) 是 Fuse 系统中条件逻辑的核心抽象基类，提供了强大的条件评估和管理功能：

#### 3.1.1 条件状态管理

每个条件都有完整的状态跟踪：

```gdscript
## 条件状态
var last_check_time: float = 0.0
var check_count: int = 0
var last_result: bool = false
var _fuse_error: FuseError = null     ## FuseError 实例，用于统一错误处理
```

#### 3.1.2 智能缓存机制

条件系统实现了高效的缓存机制来避免重复计算：

```gdscript
## 缓存配置
@export var enable_cache: bool = false
@export var cache_duration: float = 1.0

## 缓存状态
var _cached_result: bool = false
var _cache_timestamp: float = 0.0
var _cache_context_hash: int = 0
var _cached_dependencies: Array[String] = []
```

缓存验证机制非常智能，不仅检查时间过期，还会检查上下文变化：

```gdscript
func _is_cache_valid(context: ExecutionContext) -> bool:
    if _cache_timestamp == 0.0:
        return false
    
    var current_time = Time.get_ticks_msec() / 1000.0
    var cache_age = current_time - _cache_timestamp
    
    # 检查缓存是否过期
    if cache_age > cache_duration:
        _log_debug("Cache expired (age: %.2f > duration: %.2f)" % [cache_age, cache_duration])
        return false
    
    # 检查上下文是否发生变化
    var current_context_hash = _generate_context_hash(context)
    if current_context_hash != _cache_context_hash:
        _log_debug("Context changed, cache invalidated")
        return false
    
    return true
```

#### 3.1.3 条件评估流程

条件检查采用了完整的防御性编程和错误处理：

```gdscript
func check(context: ExecutionContext) -> bool:
    # 防御性编程：检查 context 是否为空
    if context == null:
        _log_error("ExecutionContext is null, cannot check condition")
        _create_fuse_error("执行上下文为空，无法检查条件", FuseError.ErrorType.VALIDATION_ERROR)
        return false
    
    if not enabled:
        _log_debug("Condition is disabled, returning false")
        return false
    
    # 检查缓存是否有效
    if enable_cache and _is_cache_valid(context):
        _log_debug("Using cached result: %s" % ("true" if _cached_result else "false"))
        last_result = _cached_result
        return _cached_result
    
    check_count += 1
    last_check_time = Time.get_ticks_msec() / 1000.0
    
    # 执行实际的条件检查
    var result = _evaluate_condition(context)
    
    # 应用结果取反
    if negate_result:
        result = not result
    
    last_result = result
    
    # 更新缓存
    if enable_cache:
        _update_cache(result, context)
    
    _log_debug("Condition check #%d: %s" % [check_count, "true" if result else "false"])
    return result
```

#### 3.1.4 依赖关系管理

条件系统支持复杂的依赖关系管理，可以跟踪条件依赖的变量和影响的变量：

```gdscript
## 获取条件依赖的变量
func get_dependencies() -> Array[String]:
    # 使用缓存避免重复计算
    if _cached_dependencies.is_empty():
        _cached_dependencies = _compute_dependencies()
    return _cached_dependencies

## 计算条件依赖的变量（子类实现）
@abstract
func _compute_dependencies() -> Array[String]

## 获取条件影响的变量
func get_affected_variables() -> Array[String]:
    # 子类可以重写此方法来声明影响的变量
    return []
```

#### 3.1.5 依赖关系图

系统提供了完整的依赖关系图生成功能，用于可视化分析：

```gdscript
func get_dependency_graph() -> Dictionary:
    var dependencies = get_dependencies()
    var affected_variables = get_affected_variables()
    
    var graph = {
        "nodes": [],
        "edges": [],
        "condition_info": {
            "type": get_condition_type(),
            "description": get_description(),
            "enabled": enabled,
            "priority": get_priority()
        }
    }
    
    # 添加条件节点
    graph["nodes"].append({
        "id": "condition_" + str(get_instance_id()),
        "label": get_description(),
        "type": "condition"
    })
    
    # 添加依赖变量节点和边
    for dep_var in dependencies:
        graph["nodes"].append({
            "id": dep_var,
            "label": dep_var,
            "type": "dependency"
        })
        graph["edges"].append({
            "from": dep_var,
            "to": "condition_" + str(get_instance_id()),
            "type": "dependency"
        })
    
    # 添加影响变量节点和边
    for affected_var in affected_variables:
        graph["nodes"].append({
            "id": affected_var,
            "label": affected_var,
            "type": "affected"
        })
        graph["edges"].append({
            "from": "condition_" + str(get_instance_id()),
            "to": affected_var,
            "type": "affects"
        })
    
    return graph
```

#### 3.1.6 批量操作支持

条件系统提供了丰富的批量操作方法，提高处理效率：

```gdscript
## 批量检查条件
func check_batch(contexts: Array[ExecutionContext]) -> Array[bool]:
    var results: Array[bool] = []
    var start_time = Time.get_ticks_msec() / 1000.0
    
    for context in contexts:
        var result = check(context)
        results.append(result)
    
    var end_time = Time.get_ticks_msec() / 1000.0
    var total_time = end_time - start_time
    var avg_time = total_time / contexts.size() if contexts.size() > 0 else 0.0
    
    _log_debug("批量条件检查完成: 检查了 %d 个上下文, 平均时间: %.4f 秒" % [contexts.size(), avg_time])
    return results

## 批量优化检查条件
func optimized_check_batch(contexts: Array[ExecutionContext]) -> Array[bool]:
    var results: Array[bool] = []
    var start_time = Time.get_ticks_msec() / 1000.0
    
    for context in contexts:
        var result = optimized_check(context)
        results.append(result)
    
    var end_time = Time.get_ticks_msec() / 1000.0
    var total_time = end_time - start_time
    var avg_time = total_time / contexts.size() if contexts.size() > 0 else 0.0
    
    _log_debug("批量优化条件检查完成: 检查了 %d 个上下文, 平均时间: %.4f 秒" % [contexts.size(), avg_time])
    return results
```

#### 3.1.7 性能监控

条件系统内置了性能监控功能：

```gdscript
## 获取条件的性能指标
func get_performance_metrics() -> Dictionary:
    return {
        "check_count": check_count,
        "last_check_time": last_check_time,
        "average_check_time": 0.0  # 需要在子类中实现
    }

## 获取缓存信息
func get_cache_info() -> Dictionary:
    var current_time = Time.get_ticks_msec() / 1000.0
    var cache_age = current_time - _cache_timestamp if _cache_timestamp > 0 else 0.0
    var is_valid = _cache_timestamp > 0 and cache_age <= cache_duration
    
    return {
        "enabled": enable_cache,
        "duration": cache_duration,
        "cached_result": _cached_result,
        "cache_timestamp": _cache_timestamp,
        "cache_age": cache_age,
        "context_hash": _cache_context_hash,
        "is_valid": is_valid
    }
```

## 4. 事件驱动架构

### 3.1 BaseEvent - 事件基类

[`BaseEvent`](addons/fuse/core/base/base_event.gd:1) 定义了事件的基本接口：

```gdscript
signal triggered(context: Node)

func initialize(owner_node: Node) -> void:
    # 子类实现具体的事件监听逻辑
    
func terminate(owner_node: Node) -> void:
    # 子类实现事件清理逻辑
```

### 3.2 具体事件实现

以 [`OnInputKey`](addons/fuse/events/on_input_key.gd:1) 为例，展示了具体事件的实现：

#### 3.2.1 事件类型支持

支持多种按键事件类型：

```gdscript
@export_enum("按下:0", "释放:1", "持续按下:2") var key_event_type: int = 0
```

#### 3.2.2 条件化属性显示

使用 `_validate_property` 方法实现条件化属性显示：

```gdscript
func _validate_property(property: Dictionary) -> void:
    # 当按键事件类型不是持续按下时，禁用持续按下相关属性
    if key_event_type != 2:
        if property.name == "held_initial_delay" or property.name == "held_repeat_interval":
            property.usage = PROPERTY_USAGE_READ_ONLY
```

#### 3.2.3 输入处理

通过虚函数重写实现输入处理：

```gdscript
func handle_input(event: InputEvent) -> void:
    if not event is InputEventKey:
        return
    
    if event.keycode != key_code:
        return
    
    match key_event_type:
        0:  # 按下
            if event.pressed and not event.is_echo():
                _handle_key_pressed()
        1:  # 释放
            if not event.pressed:
                _handle_key_released()
        2:  # 持续按下
            if event.pressed:
                if not event.is_echo():
                    _handle_key_held_start()
            else:
                _handle_key_held_end()
```

## 4. 变量系统

### 4.1 BaseVariable - 变量基类

[`BaseVariable`](addons/fuse/core/base/base_variable.gd:1) 提供了统一的变量管理接口：

#### 4.1.1 变量作用域

支持两种变量作用域：

```gdscript
enum VariableScope {
    LOCAL = 0,      # 局部变量
    GLOBAL = 1      # 全局变量
}
```

#### 4.1.2 类型安全

提供强类型检查和转换：

```gdscript
func _check_type_compatibility(variable: BaseVariable, new_value: Variant) -> bool:
    var current_type = typeof(variable.value)
    var new_type = typeof(new_value)
    
    # 如果当前值为 null，允许任何类型
    if variable.value == null:
        return true
    
    # 类型必须完全匹配
    if current_type != new_type:
        _log_error("类型不匹配: 变量当前类型为 %s，但尝试设置为 %s 类型" % [
            variable.get_type_name(), 
            _type_to_string(new_type)
        ])
        return false
    
    return true
```

#### 4.1.3 工厂模式

提供便捷的变量创建方法：

```gdscript
static func create(name: String, val: Variant, scope: VariableScope = VariableScope.LOCAL) -> BaseVariable:
    if name.is_empty():
        push_error("变量名称不能为空")
        return null
    
    var variable = BaseVariable.new()
    variable.variable_name = name
    variable.value = val
    variable.scope = scope
    variable.creation_time = Time.get_ticks_msec() / 1000.0
    
    variable._configure_by_scope(scope)
    variable.is_initialized = true
    
    return variable
```

### 4.2 GlobalVariableManager - 全局变量管理器

[`GlobalVariableManager`](addons/fuse/core/global_variable_manager.gd:1) 采用单例模式管理全局变量：

```gdscript
static var _instance: GlobalVariableManager = null

static func get_instance() -> GlobalVariableManager:
    if _instance == null:
        _instance = GlobalVariableManager.new()
    return _instance
```

#### 4.2.1 资源持久化

支持将全局变量保存到资源文件：

```gdscript
func save_to_resource(path: String) -> bool:
    var resource = Resource.new()
    var data = {}
    
    for name in _variables:
        var variable = _variables[name]
        data[name] = {
            "value": variable.value,
            "scope": variable.scope,
            "persistent": variable.persistent,
            "description": variable.description
        }
    
    resource.set_meta("variables", data)
    resource.set_meta("version", "2.0")
    resource.set_meta("created_time", Time.get_ticks_msec() / 1000.0)
    
    var error = ResourceSaver.save(resource, path)
    return error == OK
```

## 5. 编辑器工具系统

### 5.1 InstructionRegistry - 指令注册表

[`InstructionRegistry`](addons/fuse/editor/instruction_selector/instruction_registry.gd:1) 负责管理所有可用的指令：

```gdscript
static var _instructions: Array[Dictionary] = []
static var _instruction_map: Dictionary = {}

static func register_instruction(instruction_class: GDScript):
    if not instruction_class.has_method("_get_instruction_metadata"):
        print("警告：指令类没有实现 _get_instruction_metadata 方法")
        return
    
    var metadata = instruction_class._get_instruction_metadata()
    if metadata == null or metadata.name == null or metadata.name.is_empty():
        return
    
    var instruction_info = {
        "class": instruction_class,
        "metadata": metadata
    }
    _instructions.append(instruction_info)
    _instruction_map[metadata.name] = instruction_info
```

### 5.2 指令元数据系统

每个指令通过静态方法提供元数据：

```gdscript
static func _get_instruction_metadata() -> InstructionMetadata:
    metadata = InstructionMetadata.new()
    metadata.name = "设置变量"
    metadata.category = "变量操作"
    metadata.description = "设置变量的值，支持从另一个变量复制值或直接设置新值，运行时检查类型兼容性。"
    metadata.keywords = ["变量", "设置", "赋值", "复制", "类型检查", "Variant"]
    return metadata
```

### 5.3 条件化属性显示

系统支持根据配置动态显示/隐藏属性：

```gdscript
func _validate_property(property: Dictionary) -> void:
    # 当 set_with_another_variable = false 时，禁用源变量属性
    if not set_with_another_variable:
        if property.name == "from_variable" or property.name == "from_variable_scope":
            property.usage = PROPERTY_USAGE_READ_ONLY
    
    # 当 set_with_another_variable = true 时，禁用新值属性
    if set_with_another_variable and property.name == "new_value":
        property.usage = PROPERTY_USAGE_READ_ONLY
```

## 6. 序列化和持久化

### 6.1 InstructionSerializer - 指令序列化器

[`InstructionSerializer`](addons/fuse/core/serialization/instruction_serializer.gd:1) 提供指令的序列化和反序列化功能：

#### 6.1.1 属性缓存机制

使用静态缓存优化序列化性能：

```gdscript
static var _property_cache: Dictionary = {}

static func serialize_instruction(instruction: BaseInstruction) -> Dictionary:
    var type_name = instruction.get_script().get_class_name()
    
    # 使用缓存的属性列表，如果缓存中没有则获取并缓存
    if not _property_cache.has(type_name):
        var properties = []
        var property_list = instruction.get_property_list()
        for property in property_list:
            if property.usage & PROPERTY_USAGE_STORAGE:
                properties.append(property.name)
        _property_cache[type_name] = properties
    
    # 从缓存中获取属性列表并序列化
    var properties = _property_cache[type_name]
    for property_name in properties:
        data[property_name] = instruction.get(property_name)
```

#### 6.1.2 类型安全的反序列化

```gdscript
static func deserialize_instruction(data: Dictionary) -> BaseInstruction:
    if not data or not data.has("type"):
        return null
    
    var type = data["type"]
    var instruction = _create_instruction(type)
    
    if not instruction:
        return null
    
    # 设置属性
    for property in data:
        if property != "type":
            instruction.set(property, data[property])
    
    return instruction
```

## 7. 日志系统和错误处理

### 7.1 FuseLogger - 统一日志系统

[`FuseLogger`](addons/fuse/core/logging/fuse_logger.gd:1) 提供统一的日志管理：

#### 7.1.1 分级日志

支持多级日志输出：

```gdscript
enum LogLevel {
    NONE,    # 不输出任何日志
    INFO,    # 只输出 info 级别
    WARNING, # 只输出 warning 级别
    ERROR,   # 只输出 error 级别
    DEBUG    # 输出所有级别（debug, info, warning, error）
}
```

#### 7.1.2 格式化输出

提供丰富的日志格式化：

```gdscript
static func format_message(level: LogLevel, component_name: String, message: String, context: String = "") -> String:
    var level_str = LogLevel.keys()[level]
    var context_str = context if not context.is_empty() else ""
    
    # 添加颜色代码和图标
    var level_color = ""
    var icon = ""
    var reset_code = "[/color]"
    
    match level:
        LogLevel.ERROR:
            level_color = "[color=red]"
            icon = "❌"
        LogLevel.WARNING:
            level_color = "[color=yellow]"
            icon = "⚠️"
        LogLevel.INFO:
            level_color = "[color=green]"
            icon = "ℹ️"
        LogLevel.DEBUG:
            level_color = "[color=cyan]"
            icon = "🔍"
    
    return "%s%s%s[%s][%s]%s%s%s%s" % [
        icon, level_color, level_str, reset_code, component_name, context_str, level_color, message, reset_code
    ]
```

### 7.2 FuseError - 统一错误处理

系统提供了统一的错误处理机制，每个核心组件都集成了错误处理：

```gdscript
func _create_fuse_error(message: String, error_type: FuseError.ErrorType = FuseError.ErrorType.RUNTIME_ERROR, context: Dictionary = {}):
    var error_context = context.duplicate()
    error_context["instruction_name"] = metadata.name
    error_context["instruction_description"] = get_description()
    
    _fuse_error = FuseError.create_with_context(error_type, "BaseInstruction", message, error_context)
```

## 8. 性能优化和内存管理

### 8.1 智能缓存系统

系统实现了多层次的缓存机制：

#### 8.1.1 属性缓存

```gdscript
# PropertyManager 中的属性缓存
static var _property_cache: Dictionary = {}

static func get_all_properties(node: Node) -> Array[PropertyInfo]:
    var cache_key = str(node.get_instance_id())
    if _property_cache.has(cache_key):
        return _property_cache[cache_key]
    
    # 计算并缓存结果
    var properties: Array[PropertyInfo] = []
    var property_list = node.get_property_list()
    
    for prop_dict in property_list:
        var property_info = PropertyInfo.create(prop_dict)
        properties.append(property_info)
    
    _property_cache[cache_key] = properties
    return properties
```

#### 8.1.2 条件缓存

```gdscript
# BaseCondition 中的结果缓存
var _cached_result: bool = false
var _cache_timestamp: float = 0.0
var _cache_context_hash: int = 0

func _is_cache_valid(context: ExecutionContext) -> bool:
    if _cache_timestamp == 0.0:
        return false
    
    var current_time = Time.get_ticks_msec() / 1000.0
    var cache_age = current_time - _cache_timestamp
    
    # 检查缓存是否过期
    if cache_age > cache_duration:
        return false
    
    # 检查上下文是否发生变化
    var current_context_hash = _generate_context_hash(context)
    if current_context_hash != _cache_context_hash:
        return false
    
    return true
```

### 8.2 内存优化策略

#### 8.2.1 WeakRef 使用

```gdscript
# 避免循环引用和内存泄漏
var _target_weakref: WeakRef = null

func get_target_node() -> Node:
    # 首先检查弱引用
    if _target_weakref:
        var node = _target_weakref.get_ref()
        if node:
            return node
        else:
            target = null
            _target_weakref = null
    
    return target
```

#### 8.2.2 运行时事件实例

```gdscript
# 避免大型资源的不必要复制
var _runtime_event_instance: RuntimeEventInstance = null

func _ready():
    _runtime_event_instance = RuntimeEventInstance.new(event_definition, self)
    event_definition.initialize_with_runtime_instance(self, _runtime_event_instance)
```

### 8.3 执行优化

#### 8.3.1 同步执行检测

```gdscript
func can_execute_sync() -> bool:
    match execution_mode:
        ExecutionMode.FORCE_SYNC:
            return true
        ExecutionMode.FORCE_ASYNC:
            return false
        ExecutionMode.AUTO_DETECT:
            return _detect_sync_capability()
    
    return _detect_sync_capability()
```

#### 8.3.2 批量操作

```gdscript
# 批量设置属性
func set_properties_batch(node: Node, property_values: Dictionary) -> Dictionary:
    var results = {"success_count": 0, "failed_count": 0, "errors": []}
    
    for property_name in property_values:
        var value = property_values[property_name]
        var result = set_property_safe(node, property_name, value)
        
        if result.success:
            results.success_count += 1
        else:
            results.failed_count += 1
            results.errors.append({
                "property": property_name,
                "error": result.error
            })
    
    return results
```

## 9. 设计模式分析

### 9.1 使用的设计模式

#### 9.1.1 模板方法模式

[`BaseInstruction`](addons/fuse/core/base/base_instruction.gd:1) 使用模板方法模式定义指令执行流程：

```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)
    # 子类实现具体逻辑
    # 完成后调用 _on_execution_completed()
```

#### 9.1.2 策略模式

执行模式采用策略模式：

```gdscript
enum ExecutionMode {
    SEQUENTIAL,  # 顺序执行策略
    PARALLEL     # 并行执行策略
}

match execution_mode:
    ExecutionMode.SEQUENTIAL:
        await _run_sequential(context)
    ExecutionMode.PARALLEL:
        await _run_parallel(context)
```

#### 9.1.3 观察者模式

事件系统使用观察者模式：

```gdscript
signal triggered(context: Node)

# 事件发出
triggered.emit(context)

# 触发器监听
event_definition.triggered.connect(_on_event_fired)
```

#### 9.1.4 策略模式

条件系统使用策略模式进行条件评估：

```gdscript
# BaseCondition 中的条件检查策略
func check(context: ExecutionContext) -> bool:
    if not enabled:
        return false
    
    # 缓存策略
    if enable_cache and _is_cache_valid(context):
        return _cached_result
    
    # 执行策略
    var result = _evaluate_condition(context)
    
    # 结果处理策略
    if negate_result:
        result = not result
    
    return result
```

#### 9.1.5 工厂模式

变量创建使用工厂模式：

```gdscript
static func create(name: String, val: Variant, scope: VariableScope = VariableScope.LOCAL) -> BaseVariable:
    # 创建并配置变量实例
```

#### 9.1.5 单例模式

全局变量管理器使用单例模式：

```gdscript
static func get_instance() -> GlobalVariableManager:
    if _instance == null:
        _instance = GlobalVariableManager.new()
    return _instance
```

#### 9.1.6 注册表模式

指令注册表使用注册表模式：

```gdscript
static func register_instruction(instruction_class: GDScript):
    # 注册指令类到全局注册表
```

### 9.2 架构优势

1. **高度模块化**：每个组件职责单一，便于维护和扩展
2. **类型安全**：强类型检查和运行时验证
3. **性能优化**：多层次的缓存和优化策略
4. **内存安全**：WeakRef 和自动清理机制
5. **可扩展性**：插件化架构支持自定义组件
6. **调试友好**：丰富的日志和错误信息
7. **智能条件系统**：高效的条件评估、缓存机制和依赖关系管理
8. **事件驱动设计**：清晰的事件-触发器-动作编程范式

### 9.3 潜在改进点

1. **异步优化**：可以进一步优化异步指令的执行效率
2. **可视化调试**：可以增加更直观的可视化调试工具
3. **性能监控**：可以添加更详细的性能监控和分析工具
4. **文档生成**：可以自动生成指令和事件的文档
5. **单元测试**：可以增加更全面的单元测试覆盖

## 10. 总结

Fuse 可视化编程系统是一个设计精良、架构清晰的 Godot 插件，它成功地将复杂的编程概念抽象为直观的可视化组件。系统采用了多种设计模式和优化策略，在保证功能丰富的同时，也注重性能和内存管理。

### 10.1 核心优势

1. **完整的生命周期管理**：从创建到销毁的完整状态管理
2. **智能执行优化**：自动检测同步/异步执行模式
3. **多层次缓存系统**：属性缓存、结果缓存、索引缓存等
4. **内存安全保障**：WeakRef、自动清理、运行时实例等机制
5. **丰富的编辑器工具**：指令选择器、静态分析、调试可视化等
6. **强大的扩展能力**：插件化架构支持自定义指令和事件

### 10.2 技术亮点

1. **事件驱动架构**：基于事件-触发器-动作的清晰编程范式
2. **类型安全设计**：强类型检查和运行时验证机制
3. **性能优化策略**：智能缓存、批量操作、同步优化等
4. **资源管理**：充分利用 Godot 资源系统进行数据管理
5. **错误处理**：统一的错误处理和日志系统

Fuse 系统为 Godot 开发者提供了一个强大而易用的可视化编程解决方案，它不仅降低了编程门槛，还为高级用户提供了足够的扩展能力。该系统的架构设计和实现细节都体现了工程化的思维，是一个值得学习和借鉴的优秀项目。

## 架构演进：2026 年新增系统（2026-03 更新）

本章节记录 Fuse 系统在 2026 年初引入的重大架构扩展。这些新增系统在原有事件驱动、指令执行和条件评估的核心架构之上，引入了运行时实例化、统一变量体系、多线程支持、表达式系统和增强的编辑器工具链，进一步完善了系统的工程化水平。

### 11.1 运行时实例架构（Runtime Instance Pattern）

运行时实例架构是 2026 年最重要的架构演进之一，其核心思想是将**定义资源**（Resource）与**运行时状态**（Runtime State）彻底分离，避免多个触发器共享同一资源时的状态污染问题。

#### 11.1.1 三层运行时实例体系

系统为事件、指令和动作执行器分别提供了对应的运行时实例类，均继承自 `RefCounted` 以实现轻量级生命周期管理：

| 定义资源 | 运行时实例 | 核心职责 |
|---------|-----------|---------|
| `BaseEvent` | [`RuntimeEventInstance`](addons/fuse/core/runtime_event_instance.gd) | 事件运行时状态存储，独立信号转发 |
| `BaseInstruction` | [`RuntimeInstructionInstance`](addons/fuse/core/runtime_instruction_instance.gd) | 指令运行时实例，超时/暂停/取消支持 |
| `ActionRunner` | [`RuntimeActionRunnerInstance`](addons/fuse/core/runtime_action_runner_instance.gd) | ActionRunner 运行时实例，指令序列编排 |

#### 11.1.2 自声明状态模式（Self-Declared State Pattern）

新架构引入了 `get_default_runtime_state()` 方法，允许事件和指令通过自声明的方式定义其运行时状态，替代了旧的硬编码 match 分支模式：

```gdscript
# 新架构：Event 自声明状态（推荐）
func get_default_runtime_state() -> Dictionary:
    return {
        "timer": null,
        "elapsed_time": 0.0,
        "is_running": false,
        "duration": 1.0
    }
```

`RuntimeEventInstance` 初始化时优先检查此方法，回退到遗留的 `_initialize_runtime_state_legacy()` 以保证向后兼容。

#### 11.1.3 RuntimeInstructionInstance 的关键特性

`RuntimeInstructionInstance` 提供了丰富的执行生命周期管理：

- **信号多次触发保护**：通过 `_is_completed` 标志防止 `finished` 信号多次触发
- **执行超时机制**：通过 `execution_timeout` 配置超时时间，内部使用 `SceneTreeTimer`
- **暂停/恢复功能**：支持 `pause()` / `resume()` 方法，并通过 `on_runtime_pause` / `on_runtime_resume` 回调通知指令
- **对象池化支持**：提供 `reinitialize()` 和 `reset_for_pool()` 方法，支持实例复用

#### 11.1.4 RuntimeActionRunnerInstance 的性能优化

`RuntimeActionRunnerInstance` 包含多项性能优化措施：

- **状态缓存变量**：使用 `_is_running_cached` / `_is_canceling_cached` 直接变量替代字典访问，避免热路径中的字典开销
- **信号批量模式**：`set_batch_signal_mode(true)` 可将 `instruction_started` / `instruction_completed` 信号缓存到执行结束后批量发射，减少高频场景的信号开销
- **验证缓存**：`_instructions_validated` 标志避免每帧重复验证相同的指令数组
- **编译缓存集成**：通过 `CompiledInstructionSequence` 缓存指令描述等编译结果
- **共享对象池**：`InstructionInstancePool` 静态池化 `RuntimeInstructionInstance`，所有实例共享同一池

> **参考文档：** [docs/architecture/runtime-instance-pattern.md](docs/architecture/runtime-instance-pattern.md)

### 11.2 统一变量系统

2026 年的变量系统经历了重大重构，从单一的 `VariableContainer` 演进为**三层变量体系**（Local / Scope / Global），并提供了统一的操作接口。

#### 11.2.1 全局变量子系统

全局变量子系统由三个核心类组成：

- **[`GlobalVariableManager`](addons/fuse/core/global_variable_manager.gd)**：单例模式管理器，使用 `Mutex` 保证线程安全，支持变量增删改查、资源持久化（`save_to_resource` / `load_from_resource`）、批量操作和变量快照（`get_all_variables_snapshot`）
- **[`GlobalVariableResource`](addons/fuse/core/global_variable_resource.gd)**：继承 `Resource`，作为全局变量的数据载体。支持变量数据的标准化（`_normalize_variable_data`）、深拷贝序列化（`from_dict` / `_to_dict`）和可序列化值验证
- **[`GlobalVariableAssistant`](addons/fuse/core/global_variable_assistant.gd)**：场景节点，作为管理器的场景代理。支持自动保存（含延迟保存计时器）、持久化变量清理、资源加载/保存的桥接

#### 11.2.2 作用域变量子系统

作用域变量实现了基于场景树的层次化变量管理：

- **[`ScopeVariableContainer`](addons/fuse/core/base/scope_variable_container.gd)**：作用域容器基类，挂载到场景节点上，提供作用域级别的变量存储
- **[`ScopeVariableManager`](addons/fuse/core/scope_variable_manager.gd)**：单例注册表，管理所有作用域容器的注册/注销。支持按 `scope_id` 查找、按节点向上搜索最近容器（`find_nearest_scope`）、获取节点链（`get_scope_node_chain`）

#### 11.2.3 变量操作工具

- **[`VariableOperations`](addons/fuse/core/utils/variable_operations.gd)**：统一的三层变量操作接口，提供静态方法 `get_variable()` / `set_variable()` / `check_variable()`，屏蔽了 LOCAL / SCOPE / GLOBAL 的访问差异
- **[`VariableScopeUtils`](addons/fuse/core/utils/variable_scope_utils.gd)**：作用域工具类，提供枚举与字符串互转、作用域来源（`ScopeSource`）处理、属性可见性验证（`validate_scope_source_property`），用于 `_validate_property()` 回调

#### 11.2.4 变量作用域枚举扩展

`BaseVariable.VariableScope` 新增了 `SCOPE` 类型，形成完整的三级体系：

```gdscript
enum VariableScope {
    LOCAL = 0,   # 局部变量（ExecutionContext 生命周期）
    SCOPE = 1,   # 作用域变量（ScopeVariableContainer 生命周期）
    GLOBAL = 2   # 全局变量（应用程序生命周期）
}
```

### 11.3 统一错误处理

#### 11.3.1 FuseError 类

[`FuseError`](addons/fuse/core/logging/fuse_error.gd) 提供标准化的错误创建和处理机制，与 `FuseLogger` 深度集成：

- **错误类型枚举**：`VALIDATION_ERROR` / `EXECUTION_ERROR` / `CONFIGURATION_ERROR` / `RUNTIME_ERROR` / `TIMEOUT_ERROR`
- **上下文信息**：`context: Dictionary` 存储任意附加上下文数据
- **自动日志记录**：构造函数中自动调用 `_log_to_fuse_logger()` 将错误写入日志
- **本地化支持**：提供 `create_*_localized()` 系列静态方法，支持通过翻译键和参数创建本地化错误消息

#### 11.3.2 统一接口

所有核心组件（`BaseInstruction`、`BaseCondition`、`RuntimeEventInstance`、`RuntimeActionRunnerInstance` 等）均集成了 `FuseError`，通过 `_create_fuse_error()` 和 `_create_fuse_error_localized()` 方法统一创建错误实例，存储在 `_fuse_error` 实例变量中。

### 11.4 统一日志系统

#### 11.4.1 FuseLogger 类

[`FuseLogger`](addons/fuse/core/logging/fuse_logger.gd) 提供统一的分级日志管理：

- **日志级别**：`NONE` / `INFO` / `WARNING` / `ERROR` / `DEBUG`
- **双层级别控制**：`component_level` 控制组件输出级别，`message_level` 控制单条消息级别，仅当 `message_level <= component_level` 时才输出
- **富文本格式化**：使用 `print_rich` 输出带颜色的日志（红色=错误，黄色=警告，绿色=信息，青色=调试）
- **本地化日志**：提供 `log_debug_localized()` / `log_info_localized()` 等方法，支持翻译键和参数格式化
- **性能优化**：缓存 `FuseLocalization` 类引用，避免重复 `load()` 调用

### 11.5 表达式系统

表达式系统为 Fuse 提供了运行时动态求值能力，支持变量引用嵌入和丰富的内置函数。

#### 11.5.1 ExpressionHelper 工具类

[`ExpressionHelper`](addons/fuse/core/utils/expression_helper.gd) 是表达式系统的共享核心：

- **变量引用语法**：使用 `{local:xxx}` / `{scope:xxx}` / `{global:xxx}` 语法在表达式中引用变量，通过正则匹配（`VAR_PATTERN`）进行替换
- **安全求值**：`evaluate()` 方法封装了 Godot `Expression` 类的解析和执行，失败时通过 `error_text` 参数返回错误信息
- **值转义**：`escape_value()` 用于数学上下文（数值优先），`escape_value_for_string()` 用于字符串上下文（保留字符串类型）
- **GameExprHelper 内部类**：作为 `Expression.execute()` 的 `base_instance` 传入，提供游戏常用函数：

| 类别 | 函数 |
|------|------|
| 向量 | `vec2()`, `vec3()`, `normalize()`, `distance()`, `direction()`, `angle()` |
| 数值 | `remap()`, `inverse_lerp()`, `snap()`, `move_toward_val()`, `is_zero()` |
| 字符串 | `format_num()`, `pad_left()`, `pad_right()` |

#### 11.5.2 表达式指令与条件

基于 `ExpressionHelper` 构建的三个业务组件：

- **[`MathExpression`](addons/fuse/instructions/math/math_expression.gd)**：数学表达式指令，支持四则运算、数学函数、向量字面量，输出类型可选 Float / Int / Vector2 / Vector3
- **[`StringExpression`](addons/fuse/instructions/math/string_expression.gd)**：字符串表达式指令，支持字符串拼接、条件文本、类型转换和字符串工具函数
- **[`ExpressionCondition`](addons/fuse/conditions/math/expression_condition.gd)**：表达式条件，支持比较运算、逻辑运算、三元运算，返回布尔值用于条件分支

三者均支持 `ScopeSource` 枚举，允许在表达式中灵活指定作用域来源（最近容器 / 自定义 ID / 触发器节点 / 目标节点）。

### 11.6 编辑器工具扩展

2026 年大幅扩展了编辑器工具链，覆盖调试可视化、静态分析和代码生成三个维度。

#### 11.6.1 调试可视化

- **[`DebugVisualizer`](addons/fuse/editor/debugging/debug_visualizer.gd)**：图形化调试面板，基于 `ExecutionTracker` 提供执行历史的树形展示（颜色编码：绿色=成功，红色=错误，黄色=性能问题）、详情面板、自动刷新和 JSON 导出
- **[`ExecutionTracker`](addons/fuse/editor/debugging/execution_tracker.gd)**：运行时执行跟踪器，记录每条指令的开始/完成/错误事件，支持性能指标收集（内存使用、执行耗时）、变量状态快照、性能瓶颈检测，提供 `export_execution_history()` 用于历史导出

#### 11.6.2 静态分析

- **[`StaticAnalysisPanel`](addons/fuse/editor/static_analysis/static_analysis_panel.gd)**：用户友好的分析界面，提供分析按钮、进度条、结果展示（错误/警告/建议分级）、报告导出
- **[`InstructionValidator`](addons/fuse/editor/static_analysis/instruction_validator.gd)**：核心分析引擎，执行三大类检查：
  - **变量引用验证**：检测未定义的变量使用
  - **死循环检测**：分析跳转指令模式
  - **性能问题分析**：检测高频操作和资源密集型操作

#### 11.6.3 自动生成指令

- **[`InstructionGenerator`](addons/fuse/editor/instruction_generator/instruction_generator.gd)**：方法指令生成器，根据目标类和方法信息自动生成完整的 GDScript 指令文件，支持普通版和变量绑定版（`use_variables`）
- **[`PropertyInstructionGenerator`](addons/fuse/editor/instruction_generator/property_instruction_generator.gd)**：属性指令生成器，生成 GET / SET 属性指令，与 `InstructionGenerator` 配合使用
- 辅助模块：[`TypeMapper`](addons/fuse/editor/instruction_generator/type_mapper.gd)（类型映射）、[`ConflictHandler`](addons/fuse/editor/instruction_generator/conflict_handler.gd)（文件名冲突处理）、[`MethodFilter`](addons/fuse/editor/instruction_generator/method_filter.gd)（方法过滤）、[`MethodSelectorDialog`](addons/fuse/editor/instruction_generator/method_selector_dialog.gd)（方法选择对话框）

### 11.7 多线程支持

多线程系统为 Fuse 提供了安全高效的并行处理能力，主要服务于条件评估等计算密集型场景。

#### 11.7.1 FuseTaskManager 任务管理器

[`FuseTaskManager`](addons/fuse/core/threading/fuse_task_manager.gd) 封装了 Godot 的 `WorkerThreadPool`，提供统一的异步任务接口：

- **任务生命周期**：`PENDING` -> `RUNNING` -> `COMPLETED` / `FAILED` / `CANCELED`
- **提交接口**：`submit_task()` 提交单个任务，`submit_batch()` 批量提交，返回任务 ID 用于跟踪
- **同步等待**：`await_task()` / `await_all()` 支持带超时的阻塞等待（注意：不应在主线程使用）
- **线程安全**：使用 `Mutex` 保护任务状态字典和完成通知队列
- **信号通知**：`task_completed` / `task_failed` 信号线程安全发射，接收方应使用 `CONNECT_DEFERRED`

#### 11.7.2 ParallelConditionEvaluator 并行条件评估器

[`ParallelConditionEvaluator`](addons/fuse/core/threading/parallel_condition_evaluator.gd) 使用 `WorkerThreadPool` 并行评估多个条件：

- **三种评估模式**：
  - `SEQUENTIAL`：串行评估（默认，最安全）
  - `PARALLEL_SAFE`：仅并行评估标记为 `is_thread_safe` 的条件
  - `PARALLEL_ALL`：强制并行所有条件（仅用于测试）
- **上下文快照**：并行评估前创建 `ExecutionContext` 的深拷贝快照（包括局部变量和全局变量），避免竞态条件
- **Semaphore 同步**：使用 `Semaphore.post()` / `try_wait()` 等待所有并行任务完成，配合 `Mutex` 保护结果数组
- **超时保护**：带超时的等待循环，避免工作线程异常导致主线程永久阻塞

#### 11.7.3 线程安全基础设施

- **[`FuseThreadingConfig`](addons/fuse/core/threading/fuse_threading_config.gd)**：多线程配置资源（单例），提供全局开关（`enable_multithreading`）、并行条件评估开关、最大并行数、每条件超时等可配置项
- **[`FuseThreadSafe`](addons/fuse/core/threading/fuse_thread_safe.gd)**：线程安全工具类，封装字典和数组的 `get` / `set` / `has` / `erase` / `duplicate` / `append` 操作，自动处理 `Mutex` 加锁解锁

> **详细文档：** [addons/fuse/docs/multithreading.md](addons/fuse/docs/multithreading.md)