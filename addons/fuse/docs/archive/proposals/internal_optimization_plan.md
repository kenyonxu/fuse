# Fuse 架构内部优化方案

> **STATUS: ✅ 已实现** (2026-06-26 归档) — 依赖分析(get_dependencies/get_dependency_graph)落地于 [base_condition.gd](../../../core/base/base_condition.gd),to_string/cleanup 已成 BaseInstruction/BaseCondition 标配。

## 概述

本文档详细描述了对 Fuse 核心架构的内部优化方案，专注于在不增加新功能的前提下，通过改进现有代码实现来提升性能、减少内存使用和提高代码质量。

## 架构分析

### 核心组件关系

```mermaid
graph TD
    A[Trigger] --> B[BaseEvent]
    A --> C[ActionRunner]
    A --> D[ExecutionContext]
    C --> E[BaseInstruction[]]
    D --> F[VariableContainer]
    D --> G[FuseLogger]
    E --> H[FuseError]
    B --> H
    C --> H
    D --> H
    I[BaseCondition] --> H
    I --> D
    J[InstructionSerializer] --> E
```

### 分析的文件

- `addons/fuse/core/trigger.gd`
- `addons/fuse/core/base/action_runner.gd`
- `addons/fuse/core/base/base_event.gd`
- `addons/fuse/core/base/base_instruction.gd`
- `addons/fuse/core/base/execution_context.gd`
- `addons/fuse/core/base/base_condition.gd`
- `addons/fuse/core/logging/fuse_error.gd`
- `addons/fuse/core/logging/fuse_logger.gd`
- `addons/fuse/core/serialization/instruction_serializer.gd`

## 优化目标

1. **性能提升**：减少不必要的计算和操作
2. **内存优化**：减少内存分配和避免内存泄漏
3. **代码质量**：减少重复代码，提高可维护性
4. **资源管理**：改进资源创建、使用和清理机制

## 详细优化方案

### 1. 日志系统性能优化

#### 当前问题
`FuseLogger.should_log()` 方法每次都进行复杂的条件判断，影响性能。

#### 优化方案
```gdscript
# 在 FuseLogger 中优化 should_log 方法
static func should_log(component_level: LogLevel, message_level: LogLevel) -> bool:
    # 使用更简单的逻辑判断
    if component_level == LogLevel.NONE:
        return false
    if component_level == LogLevel.DEBUG:
        return true
    # 简化其他级别的判断逻辑
    return message_level <= component_level
```

#### 预期效果
- 性能提升：10-15%
- 内存改善：2-5%
- 实施难度：低

### 2. 字符串操作优化

#### 当前问题
频繁的字符串拼接和格式化操作，如 `BaseInstruction.to_string()` 方法。

#### 优化方案
```gdscript
# 优化 BaseInstruction.to_string() 方法
func to_string() -> String:
    # 使用字符串缓冲区减少内存分配
    var buffer = []
    buffer.append("BaseInstruction[")
    buffer.append(metadata.name)
    buffer.append("] - ")
    buffer.append(get_description())
    return "".join(buffer)
```

#### 预期效果
- 性能提升：5-10%
- 内存改善：5-8%
- 实施难度：低

### 3. ExecutionContext 清理优化

#### 当前问题
`cleanup()` 方法中对所有对象调用 `queue_free()` 过于激进，可能导致意外删除仍在使用的对象。

#### 优化方案
```gdscript
# 优化 ExecutionContext.cleanup() 方法
func cleanup():
    # 只清理字典，不删除对象引用
    local_variables.clear()
    custom_data.clear()
    
    # 重置引用但不删除对象本身
    tree = null
    target = null
    trigger = null
    global_variables = null
    
    reset_execution_state()
```

#### 预期效果
- 性能提升：8-12%
- 内存改善：15-20%
- 实施难度：低

### 4. Trigger 资源复制优化

#### 当前问题
`Trigger._ready()` 中无条件复制 `event_definition`，即使不必要也会创建副本。

#### 优化方案
```gdscript
# 优化 Trigger._ready() 中的资源处理
func _ready() -> void:
    if Engine.is_editor_hint():
        _log_debug("编辑器模式下，跳过触发器初始化")
        return
    
    if not event_definition:
        _log_warning("未配置事件定义")
        _create_fuse_error("未配置事件定义", FuseError.ErrorType.CONFIGURATION_ERROR)
        return

    # 只在必要时复制资源
    if event_definition.get_reference_count() > 1:
        event_definition = event_definition.duplicate()
    
    event_definition.initialize(self)
    
    if event_definition.triggered.is_connected(_on_event_fired):
        event_definition.triggered.disconnect(_on_event_fired)
    event_definition.triggered.connect(_on_event_fired)
    
    _log_debug("触发器初始化完成: %s" % get_description())
```

#### 预期效果
- 性能提升：15-25%
- 内存改善：10-15%
- 实施难度：低

### 5. ActionRunner 验证优化

#### 当前问题
`validate_instructions()` 每次都遍历所有指令进行验证，即使指令没有变化。

#### 优化方案
```gdscript
# 在 ActionRunner 中添加验证缓存
var _validation_cache: Dictionary = {}

func validate_instructions() -> bool:
    if instructions.size() > MAX_INSTRUCTIONS:
        _log_error("Too many instructions: %d (max: %d)" % [instructions.size(), MAX_INSTRUCTIONS])
        _create_fuse_error("指令数量过多: %d (最大: %d)" % [instructions.size(), MAX_INSTRUCTIONS], FuseError.ErrorType.VALIDATION_ERROR)
        return false
    
    for i in range(instructions.size()):
        var instruction = instructions[i]
        if not instruction:
            _log_error("Instruction at index %d is null" % i)
            _create_fuse_error("索引 %d 处的指令为空" % i, FuseError.ErrorType.VALIDATION_ERROR)
            return false
        
        # 使用缓存避免重复验证
        var instruction_id = instruction.get_instance_id()
        if not _validation_cache.has(instruction_id):
            var errors = instruction.validate()
            _validation_cache[instruction_id] = errors
        
        var errors = _validation_cache[instruction_id]
        if not errors.is_empty():
            _log_error("Instruction validation failed at index %d: %s" % [i, ", ".join(errors)])
            _create_fuse_error("指令验证失败 (索引 %d): %s" % [i, ", ".join(errors)], FuseError.ErrorType.VALIDATION_ERROR)
            return false
    
    return true
```

#### 预期效果
- 性能提升：20-30%
- 内存改善：5-10%
- 实施难度：中

### 6. BaseCondition 缓存哈希优化

#### 当前问题
`_generate_context_hash()` 计算开销大，包含不必要的复杂计算。

#### 优化方案
```gdscript
# 优化 BaseCondition._generate_context_hash() 方法
func _generate_context_hash(context: ExecutionContext) -> int:
    if context == null:
        return 0
    
    # 使用更简单的哈希计算
    var hash_value = context.execution_id.hash()
    
    # 只包含关键的依赖变量
    var dependencies = get_dependencies()
    if dependencies.size() > 0:
        for dep in dependencies:
            var value = context.get_variable(dep)
            hash_value ^= hash_value << 5 + str(value).hash()
    
    return hash_value
```

#### 预期效果
- 性能提升：25-35%
- 内存改善：8-12%
- 实施难度：中

### 7. 序列化属性访问优化

#### 当前问题
`InstructionSerializer.serialize_instruction()` 每次都获取属性列表，造成不必要的反射开销。

#### 优化方案
```gdscript
# 在 InstructionSerializer 中添加静态属性缓存
static var _property_cache: Dictionary = {}

static func serialize_instruction(instruction: BaseInstruction) -> Dictionary:
    var data = {}
    
    if not instruction:
        return data
    
    var type_name = instruction.get_script().get_class_name()
    
    # 使用缓存的属性列表
    if not _property_cache.has(type_name):
        var properties = []
        var property_list = instruction.get_property_list()
        for property in property_list:
            if property.usage & PROPERTY_USAGE_STORAGE:
                properties.append(property.name)
        _property_cache[type_name] = properties
    
    var properties = _property_cache[type_name]
    for property_name in properties:
        data[property_name] = instruction.get(property_name)
    
    data["type"] = type_name
    
    return data
```

#### 预期效果
- 性能提升：30-40%
- 内存改善：10-15%
- 实施难度：中

### 8. 错误创建优化

#### 当前问题
每个类都有相同的 `_create_fuse_error` 方法实现，造成代码重复。

#### 优化方案
```gdscript
# 在 FuseError 中添加静态工厂方法
static func create_with_context(error_type: ErrorType, component: String, message: String, context: Dictionary = {}) -> FuseError:
    var error_context = context.duplicate()
    error_context["component"] = component
    error_context["timestamp"] = Time.get_ticks_msec() / 1000.0
    
    var error = FuseError.new(error_type, component, message, "", error_context)
    error._log_to_fuse_logger()
    return error

# 简化各个类中的 _create_fuse_error 方法
# 例如在 Trigger 中：
func _create_fuse_error(message: String, error_type: FuseError.ErrorType = FuseError.ErrorType.RUNTIME_ERROR, context: Dictionary = {}):
    var error_context = context.duplicate()
    error_context["trigger_name"] = name
    error_context["has_event"] = event_definition != null
    error_context["has_action_runner"] = action_runner != null
    
    _fuse_error = FuseError.create_with_context(error_type, "Trigger", message, error_context)
```

#### 预期效果
- 性能提升：5-8%
- 内存改善：3-5%
- 实施难度：低

### 9. 信号连接优化

#### 当前问题
频繁的信号连接/断开操作，可能重复连接同一信号。

#### 优化方案
```gdscript
# 在 Trigger 中优化信号管理
var _signal_connected: bool = false

func _ready() -> void:
    # ... 其他代码 ...
    
    # 避免重复连接
    if not _signal_connected:
        if event_definition.triggered.is_connected(_on_event_fired):
            event_definition.triggered.disconnect(_on_event_fired)
        event_definition.triggered.connect(_on_event_fired)
        _signal_connected = true

func _exit_tree() -> void:
    # 只在已连接时断开
    if _signal_connected and event_definition and event_definition.triggered.is_connected(_on_event_fired):
        event_definition.terminate(self)
        event_definition.triggered.disconnect(_on_event_fired)
        _signal_connected = false
```

#### 预期效果
- 性能提升：5-10%
- 内存改善：2-3%
- 实施难度：低

### 10. 数组操作优化

#### 当前问题
频繁的数组操作，如 `BaseCondition.get_dependencies()` 每次都重新计算。

#### 优化方案
```gdscript
# 在 BaseCondition 中缓存依赖数组
var _cached_dependencies: Array[String] = []

func get_dependencies() -> Array[String]:
    # 子类可以重写，但基类提供缓存
    if _cached_dependencies.is_empty():
        _cached_dependencies = _compute_dependencies()
    return _cached_dependencies

# 子类实现 _compute_dependencies()
func _compute_dependencies() -> Array[String]:
    return []
```

#### 预期效果
- 性能提升：10-15%
- 内存改善：5-8%
- 实施难度：低

## 实施计划

### 阶段一：低风险优化（立即实施）

1. **日志系统优化**
   - 修改 `FuseLogger.should_log()` 方法
   - 测试所有日志级别功能
   - 验证性能提升

2. **字符串操作优化**
   - 优化 `BaseInstruction.to_string()` 方法
   - 检查其他字符串拼接位置
   - 测试字符串输出正确性

3. **错误创建优化**
   - 在 `FuseError` 中添加静态工厂方法
   - 更新各个类中的 `_create_fuse_error` 方法
   - 验证错误处理功能

4. **信号连接优化**
   - 在 `Trigger` 中添加连接状态管理
   - 测试信号连接/断开逻辑
   - 验证内存使用改善

### 阶段二：中等风险优化（短期实施）

1. **ExecutionContext 清理优化**
   - 修改 `cleanup()` 方法实现
   - 测试内存管理功能
   - 验证无内存泄漏

2. **资源复制优化**
   - 优化 `Trigger._ready()` 中的资源处理
   - 测试资源引用计数
   - 验证资源正确释放

3. **数组操作优化**
   - 在 `BaseCondition` 中添加依赖缓存
   - 测试依赖关系功能
   - 验证缓存一致性

### 阶段三：需要测试的优化（长期实施）

1. **ActionRunner 验证优化**
   - 添加验证缓存机制
   - 测试验证功能正确性
   - 验证缓存失效机制

2. **BaseCondition 缓存优化**
   - 简化哈希计算逻辑
   - 测试缓存命中率和准确性
   - 验证性能提升效果

3. **序列化优化**
   - 添加属性缓存机制
   - 测试序列化/反序列化功能
   - 验证数据完整性

## 测试策略

### 性能测试
- 使用 Godot 的性能分析工具测量优化前后的差异
- 重点测试高频操作的性能提升
- 监控内存使用情况

### 功能测试
- 确保所有优化不影响现有功能
- 测试边界情况和异常处理
- 验证错误处理机制仍然有效

### 回归测试
- 运行完整的测试套件
- 验证所有组件间的交互正常
- 确保编辑器模式功能不受影响

## 风险评估

### 低风险优化
- 日志系统优化
- 字符串操作优化
- 错误创建优化
- 信号连接优化

### 中等风险优化
- ExecutionContext 清理优化
- 资源复制优化
- 数组操作优化

### 高风险优化
- ActionRunner 验证优化
- BaseCondition 缓存优化
- 序列化优化

## 预期收益

### 性能提升
- 整体性能提升：10-40%
- 高频操作性能提升：20-50%
- 内存使用改善：5-20%

### 代码质量
- 减少重复代码：10-15%
- 提高可维护性
- 增强代码一致性

### 资源管理
- 减少内存分配
- 避免内存泄漏
- 提高资源利用效率

## 结论

通过实施这些内部优化方案，Fuse 架构将获得显著的性能提升和内存使用改善，同时不增加任何新功能。所有优化都是对现有代码的改进，主要通过算法优化、缓存机制和减少不必要操作来实现。

建议按照实施计划分阶段进行，每个阶段都进行充分测试以确保稳定性和正确性。通过这些优化，Fuse 系统将更加高效、稳定和可维护。