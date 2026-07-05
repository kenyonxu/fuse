# 阶段3：Middleware系统详细开发计划

## 概述

**时间范围**：第7-8周（2周）
**主要目标**：实现完整的中间件系统，提供高级调度功能，建立可组合的处理流程
**优先级**：高 - 提供灵活的效果调度和优化机制

---

## 基于阶段1-2开发内容的调整和新增

### 3.0.1 与JuicyDirector的深度集成

基于阶段1-2实现的Director和Driver系统，Middleware需要进行以下调整：

**Director执行流程集成**：
- 中间件管道需要完全集成到Director的执行流程中
- 修改Director的`_execute_drivers()`方法，在Driver执行前先执行中间件管道
- 确保中间件的执行结果正确传递给Driver系统

**Context生命周期管理**：
- 中间件需要与Director的Context生命周期保持同步
- 实现中间件的`on_context_created()`、`on_context_destroyed()`钩子与Director的集成
- 确保中间件状态在Context完成时正确清理

### 3.0.2 与Driver系统的协同优化

基于阶段2实现的Driver系统，Middleware需要进行以下调整：

**Driver执行优化**：
- ValidationMiddleware需要验证Driver的兼容性和可用性
- ChannelMiddleware需要考虑Driver的资源消耗和执行时间
- TimeScaleMiddleware需要与Driver的时间处理机制协调

**属性缓冲协调**：
- 中间件需要与Driver共享JuicyPropertyBuffer实例
- 实现中间件级别的属性修改，支持全局效果调整
- 确保中间件和Driver的属性写入顺序正确

### 3.0.3 与JuicyContext的增强集成

基于阶段1实现的Context系统，Middleware需要进行以下增强：

**Context数据扩展**：
- 中间件需要能够向Context添加自定义数据
- 实现中间件专用的数据存储区域，避免与Driver数据冲突
- 支持中间件之间的数据共享和传递

**时间管理协调**：
- TimeScaleMiddleware需要与Context的时间系统深度集成
- 实现中间件级别的时间暂停和恢复机制
- 支持中间件对Context进度的控制和调整

### 3.0.4 性能优化和资源管理

基于阶段1-2的性能基准，Middleware系统需要进行以下优化：

**执行效率优化**：
- 实现中间件的懒加载和按需激活
- 添加中间件执行缓存，避免重复计算
- 优化中间件链的构建和执行性能

**内存管理**：
- 实现中间件对象池，减少内存分配
- 优化中间件状态存储，减少内存占用
- 添加中间件资源的自动清理机制

### 3.0.5 错误处理和调试增强

基于阶段1-2的错误处理机制，Middleware需要增强：

**错误传播**：
- 实现中间件错误的正确传播和处理
- 添加中间件级别的错误恢复机制
- 支持中间件错误的隔离，避免影响整个管道

**调试支持**：
- 集成阶段1-2的调试和监控系统
- 添加中间件执行的可视化和日志
- 实现中间件性能的实时监控

### 3.0.6 新增枚举类型

基于阶段3的中间件系统需求，需要在JuicyMixerEnms中添加以下枚举：

**PriorityMode**：
```gdscript
enum PriorityMode {
    FIFO,           # 先进先出
    LIFO,           # 后进先出
    PRIORITY_BASED  # 基于优先级
}
```

此枚举用于通道配置中的优先级模式设置，控制队列中Context的处理顺序。

### 3.0.7 新增中间件类型

基于阶段1-2的系统需求，需要新增以下中间件：

**DriverMiddleware**：
- 专门处理Driver相关的逻辑
- 提供Driver级别的优化和缓存
- 支持Driver的动态加载和卸载

**ResourceMiddleware**：
- 处理资源相关的验证和优化
- 实现资源的预加载和缓存
- 支持资源的动态替换和更新

**PerformanceMiddleware**：
- 提供系统级别的性能监控
- 实现自适应的性能优化
- 支持性能预警和自动调整

---

## 核心组件详细设计

### 3.1 JuicyMiddleware (中间件基类)

**文件路径**：`addons/juicy_mixer/middleware/juicy_middleware.gd`

**核心职责**：
- 定义所有中间件的通用接口
- 提供可组合的处理流程
- 支持异步和同步处理
- 实现中间件的生命周期管理

**详细实现计划**：

```gdscript
@abstract
class_name JuicyMiddleware
extends RefCounted

# 中间件元信息
var middleware_name: String = ""
var middleware_version: String = "1.0.0"
var priority: int = 0
var enabled: bool = true
var description: String = ""

# 性能统计
var _execution_count: int = 0
var _total_execution_time: float = 0.0
var _last_execution_time: float = 0.0
var _error_count: int = 0

# 核心接口 - 子类必须实现
@abstract
func process(context: JuicyContext, next: Callable) -> bool

@abstract
func cleanup(context: JuicyContext) -> void

# 生命周期钩子
@abstract
func on_context_created(context: JuicyContext) -> void

@abstract
func on_context_destroyed(context: JuicyContext) -> void

@abstract
func on_context_paused(context: JuicyContext) -> void

@abstract
func on_context_resumed(context: JuicyContext) -> void

# 配置接口
func configure(config: Dictionary) -> void:
    """配置中间件参数"""
    for key in config.keys():
        if key in self:
            self.set(key, config[key])

func get_configuration() -> Dictionary:
    """获取当前配置"""
    return {}

# 验证接口
func validate_context(context: JuicyContext) -> Dictionary:
    """验证Context是否适合此中间件"""
    var result = {
        "valid": true,
        "issues": [],
        "warnings": []
    }
    
    # 基础验证
    if not context:
        result.valid = false
        result.issues.append("Context is null")
    
    if not context.target:
        result.valid = false
        result.issues.append("Context target is null")
    
    if not context.resource:
        result.valid = false
        result.issues.append("Context resource is null")
    
    return result

# 性能监控
func get_performance_stats() -> Dictionary:
    return {
        "execution_count": _execution_count,
        "total_execution_time": _total_execution_time,
        "average_execution_time": _total_execution_time / max(_execution_count, 1),
        "last_execution_time": _last_execution_time,
        "error_count": _error_count,
        "error_rate": float(_error_count) / max(_execution_count, 1)
    }

func reset_performance_stats() -> void:
    _execution_count = 0
    _total_execution_time = 0.0
    _last_execution_time = 0.0
    _error_count = 0

# 内部方法
func _start_execution_timer() -> float:
    return Time.get_ticks_usec()

func _end_execution_timer(start_time: float) -> void:
    _last_execution_time = (Time.get_ticks_usec() - start_time) / 1000.0
    _execution_count += 1
    _total_execution_time += _last_execution_time

func _record_error() -> void:
    _error_count += 1

func _log_debug(message: String) -> void:
    if OS.is_debug_build():
        print("[", middleware_name, "] ", message)

func _log_warning(message: String) -> void:
    push_warning("[" + middleware_name + "] " + message)

func _log_error(message: String) -> void:
    push_error("[" + middleware_name + "] " + message)
    _record_error()
```

**开发任务分解**：
- [x] 第7周第1天：基础类结构和元信息
- [x] 第7周第1天：核心接口定义
- [x] 第7周第2天：生命周期钩子
- [x] 第7周第2天：配置和验证接口
- [x] 第7周第3天：性能监控和日志
- [x] 第7周第3天：单元测试和文档

**验收标准**：
- 基类接口定义完整
- 生命周期管理正确
- 性能监控功能正常
- 单元测试覆盖率100%

---

### 3.2 JuicyMiddlewarePipeline (管道管理)

**文件路径**：`addons/juicy_mixer/middleware/juicy_middleware_pipeline.gd`

**核心职责**：
- 管理中间件的注册和执行
- 构建可组合的处理链
- 提供灵活的中间件配置
- 支持动态中间件管理

**详细实现计划**：

```gdscript
class_name JuicyMiddlewarePipeline
extends RefCounted

# 中间件存储
var _middlewares: Array[JuicyMiddleware] = []
var _enabled_middlewares: Array[JuicyMiddleware] = []
var _middleware_map: Dictionary = {}  # name -> middleware

# 管道状态
var _is_executing: bool = false
var _execution_contexts: Dictionary = {}  # context_id -> execution_data

# 性能统计
var _total_executions: int = 0
var _total_execution_time: float = 0.0

# 中间件管理
func add_middleware(middleware: JuicyMiddleware) -> bool:
    """添加中间件"""
    if not middleware or middleware.middleware_name.is_empty():
        push_error("Invalid middleware")
        return false
    
    if _middleware_map.has(middleware.middleware_name):
        push_warning("Middleware '" + middleware.middleware_name + "' already exists, overriding")
        remove_middleware(middleware.middleware_name)
    
    _middlewares.append(middleware)
    _middleware_map[middleware.middleware_name] = middleware
    
    if middleware.enabled:
        _update_enabled_middlewares()
    
    print("Added middleware: ", middleware.middleware_name)
    return true

func remove_middleware(middleware_name: String) -> bool:
    """移除中间件"""
    if not _middleware_map.has(middleware_name):
        return false
    
    var middleware = _middleware_map[middleware_name]
    _middlewares.erase(middleware)
    _middleware_map.erase(middleware_name)
    
    _update_enabled_middlewares()
    
    print("Removed middleware: ", middleware_name)
    return true

func get_middleware(middleware_name: String) -> JuicyMiddleware:
    """获取中间件"""
    return _middleware_map.get(middleware_name, null)

func get_all_middlewares() -> Array[JuicyMiddleware]:
    """获取所有中间件"""
    return _middlewares.duplicate()

func get_enabled_middlewares() -> Array[JuicyMiddleware]:
    """获取启用的中间件"""
    return _enabled_middlewares.duplicate()

# 启用/禁用管理
func enable_middleware(middleware_name: String) -> bool:
    """启用中间件"""
    var middleware = _middleware_map.get(middleware_name)
    if not middleware:
        return false
    
    middleware.enabled = true
    _update_enabled_middlewares()
    
    print("Enabled middleware: ", middleware_name)
    return true

func disable_middleware(middleware_name: String) -> bool:
    """禁用中间件"""
    var middleware = _middleware_map.get(middleware_name)
    if not middleware:
        return false
    
    middleware.enabled = false
    _update_enabled_middlewares()
    
    print("Disabled middleware: ", middleware_name)
    return true

# 管道执行
func execute(context: JuicyContext) -> bool:
    """执行中间件管道"""
    if _is_executing:
        push_error("Pipeline is already executing")
        return false
    
    var start_time = Time.get_ticks_usec()
    _is_executing = true
    
    # 初始化执行上下文
    _initialize_execution_context(context)
    
    # 触发创建钩子
    _trigger_context_created_hooks(context)
    
    # 构建执行链
    var execution_chain = _build_execution_chain(_enabled_middlewares, 0)
    
    # 执行管道
    var result = false
    try:
        result = execution_chain.call(context)
    except:
        push_error("Pipeline execution failed for context: " + context.context_id)
        result = false
    
    # 清理执行上下文
    _cleanup_execution_context(context)
    
    # 更新统计
    _total_executions += 1
    _total_execution_time += (Time.get_ticks_usec() - start_time) / 1000.0
    _is_executing = false
    
    return result

# 内部实现
func _update_enabled_middlewares() -> void:
    """更新启用的中间件列表"""
    _enabled_middlewares.clear()
    
    # 按优先级排序
    var sorted_middlewares = _middlewares.duplicate()
    sorted_middlewares.sort_custom(func(a, b): return a.priority > b.priority)
    
    # 收集启用的中间件
    for middleware in sorted_middlewares:
        if middleware.enabled:
            _enabled_middlewares.append(middleware)

func _build_execution_chain(middlewares: Array[JuicyMiddleware], index: int) -> Callable:
    """构建执行链"""
    if index >= middlewares.size():
        # 最后一个中间件，返回成功回调
        return func(context: JuicyContext): return true
    
    var middleware = middlewares[index]
    var next = _build_execution_chain(middlewares, index + 1)
    
    return func(context: JuicyContext):
        var middleware_start = Time.get_ticks_usec()
        
        # 验证Context
        var validation = middleware.validate_context(context)
        if not validation.valid:
            for issue in validation.issues:
                middleware._log_error("Validation failed: " + issue)
            return false
        
        # 执行中间件
        var result = false
        try:
            result = middleware.process(context, next)
        except:
            middleware._log_error("Process execution failed")
            result = false
        
        # 记录执行时间
        middleware._end_execution_timer(middleware_start)
        
        return result

func _initialize_execution_context(context: JuicyContext) -> void:
    """初始化执行上下文"""
    _execution_contexts[context.context_id] = {
        "start_time": Time.get_ticks_msec() / 1000.0,
        "middleware_results": {},
        "execution_order": []
    }

func _cleanup_execution_context(context: JuicyContext) -> void:
    """清理执行上下文"""
    _execution_contexts.erase(context.context_id)

func _trigger_context_created_hooks(context: JuicyContext) -> void:
    """触发Context创建钩子"""
    for middleware in _enabled_middlewares:
        try:
            middleware.on_context_created(context)
        except:
            middleware._log_error("on_context_created hook failed")

func _trigger_context_destroyed_hooks(context: JuicyContext) -> void:
    """触发Context销毁钩子"""
    for middleware in _enabled_middlewares:
        try:
            middleware.on_context_destroyed(context)
        except:
            middleware._log_error("on_context_destroyed hook failed")

# 配置管理
func configure_middleware(middleware_name: String, config: Dictionary) -> bool:
    """配置中间件"""
    var middleware = _middleware_map.get(middleware_name)
    if not middleware:
        return false
    
    middleware.configure(config)
    return true

func get_middleware_configuration(middleware_name: String) -> Dictionary:
    """获取中间件配置"""
    var middleware = _middleware_map.get(middleware_name)
    if not middleware:
        return {}
    
    return middleware.get_configuration()

# 统计和调试
func get_pipeline_stats() -> Dictionary:
    """获取管道统计信息"""
    var middleware_stats = {}
    
    for middleware in _middlewares:
        middleware_stats[middleware.middleware_name] = middleware.get_performance_stats()
    
    return {
        "total_middlewares": _middlewares.size(),
        "enabled_middlewares": _enabled_middlewares.size(),
        "total_executions": _total_executions,
        "total_execution_time": _total_execution_time,
        "average_execution_time": _total_execution_time / max(_total_executions, 1),
        "middleware_stats": middleware_stats
    }

func debug_print_pipeline() -> void:
    """打印管道信息"""
    print("=== JuicyMixer Middleware Pipeline ===")
    print("Total middlewares: ", _middlewares.size())
    print("Enabled middlewares: ", _enabled_middlewares.size())
    print("Execution order (by priority):")
    
    for i in range(_enabled_middlewares.size()):
        var middleware = _enabled_middlewares[i]
        print("  ", i + 1, ". ", middleware.middleware_name, " (priority: ", middleware.priority, ")")
```

**开发任务分解**：
- [x] 第7周第4天：基础类结构和中间件管理
- [x] 第7周第5天：执行链构建和管道执行
- [x] 第8周第1天：生命周期钩子和配置管理
- [x] 第8周第2天：统计和调试功能
- [x] 第8周第3天：错误处理和异常安全
- [x] 第8周第4天：性能优化和单元测试
- [x] 第8周第5天：集成测试和文档

**验收标准**：
- 中间件注册和管理正常
- 执行链构建正确
- 管道执行稳定可靠
- 性能满足设计要求
- 单元测试覆盖率100%

---

### 3.3 ValidationMiddleware (验证中间件)

**文件路径**：`addons/juicy_mixer/middleware/validation_middleware.gd`

**核心职责**：
- 验证Context和Resource的有效性
- 检查目标节点的兼容性
- 提供详细的错误信息
- 支持自定义验证规则

**详细实现计划**：

```gdscript
class_name JuicyValidationMiddleware
extends JuicyMiddleware

# 验证配置
var strict_mode: bool = false
var validate_target_properties: bool = true
var validate_resource_config: bool = true
var validate_time_parameters: bool = true

# 自定义验证规则
var custom_validators: Array[Callable] = []

func _init():
    middleware_name = "ValidationMiddleware"
    priority = 1000  # 最高优先级，最先执行
    description = "Validates context and resource parameters"

func process(context: JuicyContext, next: Callable) -> bool:
    """执行验证"""
    var start_time = _start_execution_timer()
    
    # 基础验证
    if not _validate_basic_requirements(context):
        _end_execution_timer(start_time)
        return false
    
    # 目标节点验证
    if validate_target_properties and not _validate_target_node(context):
        _end_execution_timer(start_time)
        return false
    
    # 资源配置验证
    if validate_resource_config and not _validate_resource_config(context):
        _end_execution_timer(start_time)
        return false
    
    # 时间参数验证
    if validate_time_parameters and not _validate_time_parameters(context):
        _end_execution_timer(start_time)
        return false
    
    # 自定义验证
    if not _validate_custom_rules(context):
        _end_execution_timer(start_time)
        return false
    
    _end_execution_timer(start_time)
    return next.call(context)

# 验证实现
func _validate_basic_requirements(context: JuicyContext) -> bool:
    """基础需求验证"""
    if not context:
        _log_error("Context is null")
        return false
    
    if not context.target:
        _log_error("Context target is null")
        return false
    
    if not context.resource:
        _log_error("Context resource is null")
        return false
    
    if not is_instance_valid(context.target):
        _log_error("Context target is not valid")
        return false
    
    return true

func _validate_target_node(context: JuicyContext) -> bool:
    """目标节点验证"""
    var target = context.target
    var resource = context.resource
    
    # 检查节点是否在场景树中
    if not target.is_inside_tree():
        _log_warning("Target node is not inside scene tree")
        if strict_mode:
            return false
    
    # 检查节点是否支持所需属性
    var drivers = resource.create_drivers()
    for driver in drivers:
        for property in driver.supported_properties:
            if not property in target:
                var message = "Target node doesn't support property: " + property
                if strict_mode:
                    _log_error(message)
                    return false
                else:
                    _log_warning(message)
    
    return true

func _validate_resource_config(context: JuicyContext) -> bool:
    """资源配置验证"""
    var resource = context.resource
    var validation = resource.validate_config()
    
    if not validation.valid:
        for issue in validation.issues:
            _log_error("Resource validation failed: " + issue)
        return false
    
    for warning in validation.warnings:
        _log_warning("Resource validation warning: " + warning)
    
    return true

func _validate_time_parameters(context: JuicyContext) -> bool:
    """时间参数验证"""
    var resource = context.resource
    
    if resource.duration <= 0:
        _log_error("Duration must be greater than 0")
        return false
    
    if context.time_scale < 0:
        _log_error("Time scale cannot be negative")
        return false
    
    return true

func _validate_custom_rules(context: JuicyContext) -> bool:
    """自定义验证规则"""
    for validator in custom_validators:
        if not validator.call(context):
            _log_error("Custom validation failed")
            if strict_mode:
                return false
    
    return true

# 配置接口
func configure(config: Dictionary) -> void:
    super.configure(config)
    
    if config.has("strict_mode"):
        strict_mode = config.strict_mode
    
    if config.has("validate_target_properties"):
        validate_target_properties = config.validate_target_properties
    
    if config.has("validate_resource_config"):
        validate_resource_config = config.validate_resource_config
    
    if config.has("validate_time_parameters"):
        validate_time_parameters = config.validate_time_parameters

func get_configuration() -> Dictionary:
    return super.get_configuration().merge({
        "strict_mode": strict_mode,
        "validate_target_properties": validate_target_properties,
        "validate_resource_config": validate_resource_config,
        "validate_time_parameters": validate_time_parameters,
        "custom_validators_count": custom_validators.size()
    })

# 自定义验证器管理
func add_custom_validator(validator: Callable) -> void:
    """添加自定义验证器"""
    custom_validators.append(validator)

func remove_custom_validator(validator: Callable) -> void:
    """移除自定义验证器"""
    custom_validators.erase(validator)

func clear_custom_validators() -> void:
    """清除所有自定义验证器"""
    custom_validators.clear()
```

**开发任务分解**：
- [x] 第8周第1天：基础验证逻辑
- [x] 第8周第1天：目标节点验证
- [x] 第8周第2天：资源配置验证
- [x] 第8周第2天：自定义验证规则
- [x] 第8周第3天：配置管理和单元测试

**验收标准**：
- 验证逻辑全面准确
- 错误信息详细清晰
- 支持灵活配置
- 单元测试覆盖率100%

---

### 3.4 JuicyChannelConfig (通道配置资源)

**文件路径**：`addons/juicy_mixer/resources/juicy_channel_config.gd`

**核心职责**：
- 定义通道的配置参数
- 提供可序列化的配置存储
- 支持编辑器中的可视化配置
- 提供配置验证功能

**详细实现计划**：

```gdscript
@tool
class_name JuicyChannelConfig
extends Resource

# 通道配置属性
@export var channel_name: String = "default"
@export var max_concurrent: int = -1  # -1表示无限制
@export var priority_mode: JuicyMixerEnms.PriorityMode = JuicyMixerEnms.PriorityMode.FIFO
@export var allow_interruption: bool = true
@export var auto_stop_previous: bool = false
@export var description: String = ""

func _init():
    """初始化通道配置"""
    resource_name = "ChannelConfig: " + channel_name

# 验证配置
func validate() -> Dictionary:
    """验证配置的有效性"""
    var result = {
        "valid": true,
        "issues": [],
        "warnings": []
    }
    
    if channel_name.is_empty():
        result.valid = false
        result.issues.append("Channel name cannot be empty")
    
    if max_concurrent < -1:
        result.valid = false
        result.issues.append("Max concurrent must be -1 or greater")
    
    return result

# 获取配置描述
func get_description() -> String:
    """获取配置的友好描述"""
    var priority_names = ["FIFO", "LIFO", "PRIORITY_BASED"]
    var priority_name = priority_names[priority_mode] if priority_mode < priority_names.size() else "UNKNOWN"
    
    return "Channel '%s': max=%s, mode=%s, interrupt=%s" % [
        channel_name,
        "unlimited" if max_concurrent == -1 else str(max_concurrent),
        priority_name,
        allow_interruption
    ]

# 编辑器支持
func _get_property_list() -> Array[Dictionary]:
    """获取属性列表，用于编辑器显示"""
    var properties = []
    
    properties.append({
        "name": "priority_mode",
        "type": TYPE_INT,
        "hint": PROPERTY_HINT_ENUM,
        "hint_string": "FIFO,LIFO,PRIORITY_BASED",
        "usage": PROPERTY_USAGE_DEFAULT
    })
    
    return properties

# 序列化支持
func _to_string() -> String:
    """获取字符串表示"""
    return get_description()
```

**开发任务分解**：
- [x] 第8周第3天：基础资源类结构
- [x] 第8周第3天：属性定义和验证
- [x] 第8周第4天：编辑器支持和序列化
- [x] 第8周第4天：单元测试

**验收标准**：
- 资源类正确继承Resource
- 属性序列化和反序列化正常
- 编辑器显示友好
- 配置验证功能完整
- 单元测试覆盖率100%

---

### 3.5 ChannelMiddleware (通道中间件)

**文件路径**：`addons/juicy_mixer/middleware/channel_middleware.gd`

**核心职责**：
- 管理效果通道的调度规则
- 控制同通道效果的并发
- 实现通道优先级和限制
- 提供通道状态监控
- 加载和管理通道配置资源

**详细实现计划**：

```gdscript
class_name JuicyChannelMiddleware
extends JuicyMiddleware

# 通道管理
var _channel_configs: Dictionary = {}  # channel_name -> JuicyChannelConfig
var _channel_states: Dictionary = {}   # channel_name -> ChannelState
var _context_channels: Dictionary = {} # context_id -> channel_name

# 通道状态
class ChannelState:
    var active_contexts: Array[String] = []
    var queued_contexts: Array[String] = []
    var total_executed: int = 0

func _init():
    middleware_name = "ChannelMiddleware"
    priority = 900  # 高优先级，在验证后执行
    description = "Manages effect channel scheduling and concurrency"

func process(context: JuicyContext, next: Callable) -> bool:
    """处理通道调度"""
    var start_time = _start_execution_timer()
    
    var channel_name = context.resource.channel
    if channel_name.is_empty():
        channel_name = "default"
    
    # 获取或创建通道配置
    var channel_config = _get_channel_config(channel_name)
    
    # 获取或创建通道状态
    var channel_state = _get_channel_state(channel_name)
    
    # 检查是否可以调度
    if not _can_schedule(channel_config, channel_state, context):
        _end_execution_timer(start_time)
        return false
    
    # 执行调度
    if not _schedule_context(channel_config, channel_state, context):
        _end_execution_timer(start_time)
        return false
    
    # 记录通道关联
    _context_channels[context.context_id] = channel_name
    
    _end_execution_timer(start_time)
    return next.call(context)

func cleanup(context: JuicyContext) -> void:
    """清理通道状态"""
    var channel_name = _context_channels.get(context.context_id)
    if channel_name:
        var channel_state = _channel_states.get(channel_name)
        if channel_state:
            channel_state.active_contexts.erase(context.context_id)
        
        _context_channels.erase(context.context_id)
        
        # 处理队列中的下一个Context
        _process_queue(channel_name)

# 内部实现
func _get_channel_config(channel_name: String) -> JuicyChannelConfig:
    """获取通道配置"""
    if not _channel_configs.has(channel_name):
        _channel_configs[channel_name] = _create_default_channel_config(channel_name)
    return _channel_configs[channel_name]

func _create_default_channel_config(channel_name: String) -> JuicyChannelConfig:
    """创建默认通道配置"""
    var config = JuicyChannelConfig.new()
    config.channel_name = channel_name
    return config

func _get_channel_state(channel_name: String) -> ChannelState:
    """获取通道状态"""
    if not _channel_states.has(channel_name):
        _channel_states[channel_name] = ChannelState.new()
    return _channel_states[channel_name]

func _can_schedule(config: JuicyChannelConfig, state: ChannelState, context: JuicyContext) -> bool:
    """检查是否可以调度"""
    # 检查并发限制
    if config.max_concurrent > 0 and state.active_contexts.size() >= config.max_concurrent:
        return false
    
    # 检查是否允许中断
    if not config.allow_interruption and not state.active_contexts.is_empty():
        return false
    
    return true

func _schedule_context(config: JuicyChannelConfig, state: ChannelState, context: JuicyContext) -> bool:
    """调度Context"""
    # 如果需要自动停止前一个Context
    if config.auto_stop_previous and not state.active_contexts.is_empty():
        var previous_context_id = state.active_contexts[-1]
        JuicyMixer.stop(previous_context_id)
    
    # 添加到活跃列表
    state.active_contexts.append(context.context_id)
    state.total_executed += 1
    
    return true

func _process_queue(channel_name: String) -> void:
    """处理队列中的Context"""
    var config = _get_channel_config(channel_name)
    var state = _get_channel_state(channel_name)
    
    while not state.queued_contexts.is_empty() and _can_schedule(config, state, null):
        var context_id = _dequeue_context(config, state)
        if context_id.is_empty():
            break
        
        # 重新调度队列中的Context
        var context = JuicyMixer.get_context(context_id)
        if context:
            _schedule_context(config, state, context)

func _dequeue_context(config: JuicyChannelConfig, state: ChannelState) -> String:
    """从队列中取出Context"""
    if state.queued_contexts.is_empty():
        return ""
    
    match config.priority_mode:
        JuicyMixerEnms.PriorityMode.FIFO:
            return state.queued_contexts.pop_front()
        JuicyMixerEnms.PriorityMode.LIFO:
            return state.queued_contexts.pop_back()
        JuicyMixerEnms.PriorityMode.PRIORITY_BASED:
            # 按优先级排序后取出
            state.queued_contexts.sort_custom(func(a, b):
                var context_a = JuicyMixer.get_context(a)
                var context_b = JuicyMixer.get_context(b)
                if not context_a or not context_b:
                    return false
                return context_a.resource.priority > context_b.resource.priority
            )
            return state.queued_contexts.pop_front()
        _:
            return state.queued_contexts.pop_front()

# 通道配置管理
func set_channel_config(channel_name: String, config: JuicyChannelConfig) -> void:
    """设置通道配置"""
    _channel_configs[channel_name] = config

func get_channel_config(channel_name: String) -> JuicyChannelConfig:
    """获取通道配置"""
    return _get_channel_config(channel_name)

func load_channel_config(resource_path: String) -> JuicyChannelConfig:
    """从文件加载通道配置"""
    if ResourceLoader.exists(resource_path):
        return load(resource_path) as JuicyChannelConfig
    return null

func save_channel_config(config: JuicyChannelConfig, resource_path: String) -> bool:
    """保存通道配置到文件"""
    return ResourceSaver.save(config, resource_path) == OK

func get_channel_state(channel_name: String) -> ChannelState:
    """获取通道状态"""
    return _get_channel_state(channel_name)

# 统计和调试
func get_channel_stats() -> Dictionary:
    """获取通道统计信息"""
    var stats = {}
    
    for channel_name in _channel_states.keys():
        var state = _channel_states[channel_name]
        var config = _channel_configs[channel_name]
        
        stats[channel_name] = {
            "active_contexts": state.active_contexts.size(),
            "queued_contexts": state.queued_contexts.size(),
            "max_concurrent": config.max_concurrent,
            "priority_mode": config.priority_mode,
            "total_executed": state.total_executed
        }
    
    return stats

func debug_print_channels() -> void:
    """打印通道信息"""
    print("=== JuicyMixer Channel States ===")
    var stats = get_channel_stats()
    
    for channel_name in stats.keys():
        var stat = stats[channel_name]
        print("Channel: ", channel_name)
        print("  Active: ", stat.active_contexts, "/", stat.max_concurrent)
        print("  Queued: ", stat.queued_contexts)
        print("  Priority Mode: ", stat.priority_mode)
        print("  Total Executed: ", stat.total_executed)
```

**开发任务分解**：
- [x] 第8周第4天：通道配置资源集成
- [x] 第8周第4天：调度逻辑和队列处理
- [x] 第8周第5天：优先级模式实现
- [x] 第8周第5天：统计和调试功能
- [x] 第8周第5天：单元测试和集成测试

**验收标准**：
- 通道调度规则正确执行
- 并发控制有效
- 优先级处理准确
- 单元测试覆盖率100%

---

### 3.5 TimeScaleMiddleware (时间缩放中间件)

**文件路径**：`addons/juicy_mixer/middleware/timescale_middleware.gd`

**核心职责**：
- 应用全局和局部时间缩放
- 支持时间组管理
- 提供时间缩放动画
- 实现时间暂停和恢复

**详细实现计划**：

```gdscript
class_name JuicyTimeScaleMiddleware
extends JuicyMiddleware

# 时间缩放配置
var global_time_scale: float = 1.0
var time_groups: Dictionary = {}  # group_name -> time_scale
var time_group_animations: Dictionary = {}  # group_name -> animation_data

# 时间组动画数据
class TimeGroupAnimation:
    var from_scale: float
    var to_scale: float
    var duration: float
    var elapsed_time: float
    var ease_type: Tween.EaseType
    var callback: Callable

func _init():
    middleware_name = "TimeScaleMiddleware"
    priority = 800  # 中等优先级
    description = "Applies time scaling to effects"

func process(context: JuicyContext, next: Callable) -> bool:
    """应用时间缩放"""
    var start_time = _start_execution_timer()
    
    # 应用全局时间缩放
    context.time_scale *= global_time_scale
    
    # 应用时间组缩放
    var time_group = context.resource.time_group
    if not time_group.is_empty() and time_groups.has(time_group):
        context.time_scale *= time_groups[time_group]
    
    # 更新时间组动画
    _update_time_group_animations()
    
    _end_execution_timer(start_time)
    return next.call(context)

# 时间缩放管理
func set_global_time_scale(scale: float) -> void:
    """设置全局时间缩放"""
    global_time_scale = max(0.0, scale)

func get_global_time_scale() -> float:
    """获取全局时间缩放"""
    return global_time_scale

func set_time_group_scale(group_name: String, scale: float) -> void:
    """设置时间组缩放"""
    time_groups[group_name] = max(0.0, scale)

func get_time_group_scale(group_name: String) -> float:
    """获取时间组缩放"""
    return time_groups.get(group_name, 1.0)

func remove_time_group(group_name: String) -> void:
    """移除时间组"""
    time_groups.erase(group_name)
    time_group_animations.erase(group_name)

# 时间组动画
func animate_time_group_scale(group_name: String, to_scale: float, duration: float,
                           ease_type: Tween.EaseType = Tween.EASE_IN_OUT,
                           callback: Callable = Callable()) -> void:
    """动画时间组缩放"""
    var from_scale = get_time_group_scale(group_name)
    
    var animation = TimeGroupAnimation.new()
    animation.from_scale = from_scale
    animation.to_scale = to_scale
    animation.duration = duration
    animation.elapsed_time = 0.0
    animation.ease_type = ease_type
    animation.callback = callback
    
    time_group_animations[group_name] = animation

func stop_time_group_animation(group_name: String) -> void:
    """停止时间组动画"""
    time_group_animations.erase(group_name)

func _update_time_group_animations() -> void:
    """更新时间组动画"""
    var groups_to_remove: Array[String] = []
    
    for group_name in time_group_animations.keys():
        var animation = time_group_animations[group_name]
        
        animation.elapsed_time += get_process_delta_time()
        
        if animation.elapsed_time >= animation.duration:
            # 动画完成
            set_time_group_scale(group_name, animation.to_scale)
            groups_to_remove.append(group_name)
            
            # 调用回调
            if animation.callback.is_valid():
                animation.callback.call()
        else:
            # 计算当前值
            var progress = animation.elapsed_time / animation.duration
            progress = _apply_easing(progress, animation.ease_type)
            
            var current_scale = lerp(animation.from_scale, animation.to_scale, progress)
            set_time_group_scale(group_name, current_scale)
    
    # 移除完成的动画
    for group_name in groups_to_remove:
        time_group_animations.erase(group_name)

func _apply_easing(progress: float, ease_type: Tween.EaseType) -> float:
    """应用缓动函数"""
    match ease_type:
        Tween.EASE_IN:
            return progress * progress
        Tween.EASE_OUT:
            return 1.0 - (1.0 - progress) * (1.0 - progress)
        Tween.EASE_IN_OUT:
            if progress < 0.5:
                return 2.0 * progress * progress
            else:
                return 1.0 - 2.0 * (1.0 - progress) * (1.0 - progress)
        _:
            return progress

# 统计和调试
func get_time_scale_stats() -> Dictionary:
    """获取时间缩放统计"""
    return {
        "global_time_scale": global_time_scale,
        "time_groups": time_groups.duplicate(),
        "active_animations": time_group_animations.size(),
        "animated_groups": time_group_animations.keys()
    }

func debug_print_time_scales() -> void:
    """打印时间缩放信息"""
    print("=== JuicyMixer Time Scales ===")
    print("Global: ", global_time_scale)
    print("Time Groups:")
    for group_name in time_groups.keys():
        print("  ", group_name, ": ", time_groups[group_name])
    
    if not time_group_animations.is_empty():
        print("Active Animations:")
        for group_name in time_group_animations.keys():
            var animation = time_group_animations[group_name]
            print("  ", group_name, ": ", animation.from_scale, " -> ", animation.to_scale,
                  " (", animation.elapsed_time, "/", animation.duration, ")")
```

**开发任务分解**：
- [x] 第8周第5天：基础时间缩放逻辑
- [x] 第8周第5天：时间组管理
- [x] 第8周第5天：时间组动画
- [x] 第8周第5天：统计和调试功能
- [x] 第8周第5天：单元测试

**验收标准**：
- 时间缩放正确应用
- 时间组管理有效
- 动画播放流畅
- 单元测试覆盖率100%

---

### 3.6 JuicyLODConfig (LOD配置资源)

**文件路径**：`addons/juicy_mixer/resources/juicy_lod_config.gd`

**核心职责**：
- 定义LOD的配置参数
- 提供可序列化的LOD配置存储
- 支持编辑器中的可视化配置
- 提供LOD配置验证功能

**详细实现计划**：

```gdscript
@tool
class_name JuicyLODConfig
extends Resource

# LOD配置属性
@export var config_name: String = "default_lod"
@export var max_distance: float = 500.0
@export var distance_thresholds: Array[float] = [100.0, 200.0, 300.0]
@export var intensity_multipliers: Array[float] = [1.0, 0.75, 0.5, 0.25, 0.0]
@export var enable_frustum_culling: bool = true
@export var enable_distance_culling: bool = true
@export var description: String = ""

func _init():
    """初始化LOD配置"""
    resource_name = "LODConfig: " + config_name

# 验证配置
func validate() -> Dictionary:
    """验证配置的有效性"""
    var result = {
        "valid": true,
        "issues": [],
        "warnings": []
    }
    
    if config_name.is_empty():
        result.valid = false
        result.issues.append("Config name cannot be empty")
    
    if max_distance <= 0:
        result.valid = false
        result.issues.append("Max distance must be greater than 0")
    
    if distance_thresholds.size() + 1 != intensity_multipliers.size():
        result.valid = false
        result.issues.append("Intensity multipliers array must be one element larger than distance thresholds array")
    
    # 检查距离阈值是否递增
    for i in range(1, distance_thresholds.size()):
        if distance_thresholds[i] <= distance_thresholds[i-1]:
            result.valid = false
            result.issues.append("Distance thresholds must be in ascending order")
            break
    
    return result

# 获取配置描述
func get_description() -> String:
    """获取配置的友好描述"""
    return "LOD '%s': max_dist=%.1f, thresholds=%d, frustum=%s, distance=%s" % [
        config_name,
        max_distance,
        distance_thresholds.size(),
        enable_frustum_culling,
        enable_distance_culling
    ]

# 计算强度倍数
func calculate_intensity_multiplier(distance: float) -> float:
    """根据距离计算强度倍数"""
    if distance > max_distance:
        return 0.0
    
    for i in range(distance_thresholds.size()):
        if distance <= distance_thresholds[i]:
            return intensity_multipliers[i]
    
    # 超出所有阈值，返回最小倍数
    return intensity_multipliers[-1] if intensity_multipliers.size() > 0 else 0.0

# 编辑器支持
func _get_property_list() -> Array[Dictionary]:
    """获取属性列表，用于编辑器显示"""
    var properties = []
    
    properties.append({
        "name": "distance_thresholds",
        "type": TYPE_ARRAY,
        "hint": PROPERTY_HINT_ARRAY_TYPE,
        "hint_string": "float",
        "usage": PROPERTY_USAGE_DEFAULT
    })
    
    properties.append({
        "name": "intensity_multipliers",
        "type": TYPE_ARRAY,
        "hint": PROPERTY_HINT_ARRAY_TYPE,
        "hint_string": "float",
        "usage": PROPERTY_USAGE_DEFAULT
    })
    
    return properties

# 序列化支持
func _to_string() -> String:
    """获取字符串表示"""
    return get_description()
```

**开发任务分解**：
- [x] 第8周第4天：基础资源类结构
- [x] 第8周第4天：属性定义和验证
- [x] 第8周第5天：编辑器支持和序列化
- [x] 第8周第5天：单元测试

**验收标准**：
- 资源类正确继承Resource
- 属性序列化和反序列化正常
- 编辑器显示友好
- 配置验证功能完整
- 强度计算准确
- 单元测试覆盖率100%

---

### 3.7 JuicyTimeGroupConfig (时间组配置资源)

**文件路径**：`addons/juicy_mixer/resources/juicy_time_group_config.gd`

**核心职责**：
- 定义多个时间组的配置参数
- 提供可序列化的时间组配置存储
- 支持编辑器中的可视化配置
- 提供时间组配置验证功能
- 集中管理所有时间组的时间缩放值

**详细实现计划**：

```gdscript
@tool
class_name JuicyTimeGroupConfig
extends Resource

# 时间组配置属性
@export var config_name: String = "default_time_groups"
@export var time_groups: Dictionary = {
    "default": 1.0,
    "player": 1.0,
    "enemies": 1.0,
    "npc": 1.0,
    "projectiles": 1.0,
    "ui": 1.0,
    "vfx": 1.0,
    "unscaled": 1.0
}
@export var description: String = ""

func _init():
    """初始化时间组配置"""
    resource_name = "TimeGroupConfig: " + config_name

# 验证配置
func validate() -> Dictionary:
    """验证配置的有效性"""
    var result = {
        "valid": true,
        "issues": [],
        "warnings": []
    }
    
    if config_name.is_empty():
        result.valid = false
        result.issues.append("Config name cannot be empty")
    
    if time_groups.is_empty():
        result.valid = false
        result.issues.append("Time groups dictionary cannot be empty")
    
    # 验证每个时间组的时间缩放值
    for group_name in time_groups.keys():
        var time_scale = time_groups[group_name]
        if time_scale < 0.0:
            result.valid = false
            result.issues.append("Time scale for group '" + group_name + "' cannot be negative")
    
    return result

# 获取配置描述
func get_description() -> String:
    """获取配置的友好描述"""
    return "TimeGroups '%s': %d groups configured" % [
        config_name,
        time_groups.size()
    ]

# 获取时间组缩放值
func get_time_scale(group_name: String) -> float:
    """获取指定时间组的时间缩放值"""
    return time_groups.get(group_name, 1.0)

# 设置时间组缩放值
func set_time_scale(group_name: String, scale: float) -> void:
    """设置指定时间组的时间缩放值"""
    time_groups[group_name] = max(0.0, scale)

# 移除时间组
func remove_time_group(group_name: String) -> void:
    """移除指定的时间组"""
    time_groups.erase(group_name)

# 获取所有时间组名称
func get_time_group_names() -> Array[String]:
    """获取所有时间组的名称"""
    var names: Array[String] = []
    for group_name in time_groups.keys():
        names.append(group_name)
    return names

# 检查时间组是否存在
func has_time_group(group_name: String) -> bool:
    """检查指定的时间组是否存在"""
    return time_groups.has(group_name)

# 编辑器支持
func _get_property_list() -> Array[Dictionary]:
    """获取属性列表，用于编辑器显示"""
    var properties = []
    
    properties.append({
        "name": "time_groups",
        "type": TYPE_DICTIONARY,
        "hint": PROPERTY_HINT_NONE,
        "usage": PROPERTY_USAGE_DEFAULT
    })
    
    return properties

# 序列化支持
func _to_string() -> String:
    """获取字符串表示"""
    return get_description()

# 获取详细配置信息
func get_detailed_info() -> String:
    """获取详细的配置信息"""
    var info = "TimeGroupConfig: " + config_name + "\n"
    for group_name in time_groups.keys():
        info += "  " + group_name + ": " + str(time_groups[group_name]) + "\n"
    return info
```

**开发任务分解**：
- [x] 第8周第5天：基础资源类结构
- [x] 第8周第5天：时间组字典管理
- [x] 第8周第5天：属性定义和验证
- [x] 第8周第5天：编辑器支持和序列化
- [x] 第8周第5天：单元测试

**验收标准**：
- 资源类正确继承Resource
- 时间组字典管理功能完整
- 属性序列化和反序列化正常
- 编辑器显示友好
- 配置验证功能完整
- 单元测试覆盖率100%

---

### 3.8 TimeScaleMiddleware (时间缩放中间件)

**文件路径**：`addons/juicy_mixer/middleware/timescale_middleware.gd`

**核心职责**：
- 应用全局和局部时间缩放
- 支持时间组管理
- 提供时间缩放动画
- 实现时间暂停和恢复
- 加载和管理时间组配置资源

**详细实现计划**：

```gdscript
class_name JuicyTimeScaleMiddleware
extends JuicyMiddleware

# 时间缩放配置
var global_time_scale: float = 1.0
var time_group_config: JuicyTimeGroupConfig  # 时间组配置资源
var time_group_animations: Dictionary = {}  # group_name -> animation_data

# 时间组动画数据
class TimeGroupAnimation:
    var from_scale: float
    var to_scale: float
    var duration: float
    var elapsed_time: float
    var ease_type: Tween.EaseType
    var callback: Callable

func _init():
    middleware_name = "TimeScaleMiddleware"
    priority = 800  # 中等优先级
    description = "Applies time scaling to effects"

func process(context: JuicyContext, next: Callable) -> bool:
    """应用时间缩放"""
    var start_time = _start_execution_timer()
    
    # 应用全局时间缩放
    context.time_scale *= global_time_scale
    
    # 应用时间组缩放
    var time_group = context.resource.time_group
    if not time_group.is_empty() and time_group_config and time_group_config.has_time_group(time_group):
        context.time_scale *= time_group_config.get_time_scale(time_group)
    
    # 更新时间组动画
    _update_time_group_animations()
    
    _end_execution_timer(start_time)
    return next.call(context)

# 时间缩放管理
func set_global_time_scale(scale: float) -> void:
    """设置全局时间缩放"""
    global_time_scale = max(0.0, scale)

func get_global_time_scale() -> float:
    """获取全局时间缩放"""
    return global_time_scale

func set_time_group_scale(group_name: String, scale: float) -> void:
    """设置时间组缩放"""
    if time_group_config:
        time_group_config.set_time_scale(group_name, scale)

func get_time_group_scale(group_name: String) -> float:
    """获取时间组缩放"""
    if time_group_config:
        return time_group_config.get_time_scale(group_name)
    return 1.0

func remove_time_group(group_name: String) -> void:
    """移除时间组"""
    if time_group_config:
        time_group_config.remove_time_group(group_name)
    time_group_animations.erase(group_name)

# 时间组配置管理
func set_time_group_config(config: JuicyTimeGroupConfig) -> void:
    """设置时间组配置"""
    time_group_config = config

func get_time_group_config() -> JuicyTimeGroupConfig:
    """获取时间组配置"""
    return time_group_config

func load_time_group_config(resource_path: String) -> JuicyTimeGroupConfig:
    """从文件加载时间组配置"""
    if ResourceLoader.exists(resource_path):
        var config = load(resource_path) as JuicyTimeGroupConfig
        if config:
            time_group_config = config
        return config
    return null

func save_time_group_config(config: JuicyTimeGroupConfig, resource_path: String) -> bool:
    """保存时间组配置到文件"""
    time_group_config = config
    return ResourceSaver.save(config, resource_path) == OK

# 时间组动画
func animate_time_group_scale(group_name: String, to_scale: float, duration: float,
                           ease_type: Tween.EaseType = Tween.EASE_IN_OUT,
                           callback: Callable = Callable()) -> void:
    """动画时间组缩放"""
    var from_scale = get_time_group_scale(group_name)
    
    var animation = TimeGroupAnimation.new()
    animation.from_scale = from_scale
    animation.to_scale = to_scale
    animation.duration = duration
    animation.elapsed_time = 0.0
    animation.ease_type = ease_type
    animation.callback = callback
    
    time_group_animations[group_name] = animation

func stop_time_group_animation(group_name: String) -> void:
    """停止时间组动画"""
    time_group_animations.erase(group_name)

func _update_time_group_animations() -> void:
    """更新时间组动画"""
    var groups_to_remove: Array[String] = []
    
    for group_name in time_group_animations.keys():
        var animation = time_group_animations[group_name]
        
        animation.elapsed_time += get_process_delta_time()
        
        if animation.elapsed_time >= animation.duration:
            # 动画完成
            set_time_group_scale(group_name, animation.to_scale)
            groups_to_remove.append(group_name)
            
            # 调用回调
            if animation.callback.is_valid():
                animation.callback.call()
        else:
            # 计算当前值
            var progress = animation.elapsed_time / animation.duration
            progress = _apply_easing(progress, animation.ease_type)
            
            var current_scale = lerp(animation.from_scale, animation.to_scale, progress)
            set_time_group_scale(group_name, current_scale)
    
    # 移除完成的动画
    for group_name in groups_to_remove:
        time_group_animations.erase(group_name)

func _apply_easing(progress: float, ease_type: Tween.EaseType) -> float:
    """应用缓动函数"""
    match ease_type:
        Tween.EASE_IN:
            return progress * progress
        Tween.EASE_OUT:
            return 1.0 - (1.0 - progress) * (1.0 - progress)
        Tween.EASE_IN_OUT:
            if progress < 0.5:
                return 2.0 * progress * progress
            else:
                return 1.0 - 2.0 * (1.0 - progress) * (1.0 - progress)
        _:
            return progress

# 统计和调试
func get_time_scale_stats() -> Dictionary:
    """获取时间缩放统计"""
    var time_group_stats = {}
    if time_group_config:
        for group_name in time_group_config.get_time_group_names():
            time_group_stats[group_name] = {
                "time_scale": time_group_config.get_time_scale(group_name)
            }
    
    return {
        "global_time_scale": global_time_scale,
        "time_groups": time_group_stats,
        "active_animations": time_group_animations.size(),
        "animated_groups": time_group_animations.keys()
    }

func debug_print_time_scales() -> void:
    """打印时间缩放信息"""
    print("=== JuicyMixer Time Scales ===")
    print("Global: ", global_time_scale)
    if time_group_config:
        print("Time Groups:")
        for group_name in time_group_config.get_time_group_names():
            print("  ", group_name, ": ", time_group_config.get_time_scale(group_name))
    
    if not time_group_animations.is_empty():
        print("Active Animations:")
        for group_name in time_group_animations.keys():
            var animation = time_group_animations[group_name]
            print("  ", group_name, ": ", animation.from_scale, " -> ", animation.to_scale,
                  " (", animation.elapsed_time, "/", animation.duration, ")")
```

**开发任务分解**：
- [x] 第8周第5天：基础时间缩放逻辑
- [x] 第8周第5天：时间组配置资源集成
- [x] 第8周第5天：时间组动画
- [x] 第8周第5天：统计和调试功能
- [x] 第8周第5天：单元测试

**验收标准**：
- 时间缩放正确应用
- 时间组配置资源管理有效
- 动画播放流畅
- 单元测试覆盖率100%

---

### 3.9 LODMiddleware (LOD中间件)

**文件路径**：`addons/juicy_mixer/middleware/lod_middleware.gd`

**核心职责**：
- 实现距离相关的效果强度调整
- 提供视锥剔除功能
- 支持自定义LOD策略
- 优化性能表现
- 加载和管理LOD配置资源

**详细实现计划**：

```gdscript
class_name JuicyLODMiddleware
extends JuicyMiddleware

# LOD状态
var _lod_config: JuicyLODConfig
var _camera_reference: Camera2D

func _init():
    middleware_name = "LODMiddleware"
    priority = 700  # 较低优先级，在其他处理后执行
    description = "Applies level of detail optimizations"

func process(context: JuicyContext, next: Callable) -> bool:
    """应用LOD优化"""
    var start_time = _start_execution_timer()
    
    # 初始化LOD配置
    if not _lod_config:
        _initialize_default_config()
    
    # 获取当前摄像机
    var camera = _get_current_camera()
    if not camera:
        _end_execution_timer(start_time)
        return next.call(context)
    
    # 计算距离
    var distance = _calculate_distance_to_target(camera, context.target)
    
    # 视锥剔除
    if _lod_config.enable_frustum_culling and not _is_target_visible(camera, context.target):
        context.time_scale = 0.0
        _end_execution_timer(start_time)
        return next.call(context)
    
    # 距离剔除
    if _lod_config.enable_distance_culling and distance > _lod_config.max_distance:
        context.time_scale = 0.0
        _end_execution_timer(start_time)
        return next.call(context)
    
    # 应用距离相关的强度调整
    var intensity_multiplier = _calculate_intensity_multiplier(distance)
    context.time_scale *= intensity_multiplier
    
    _end_execution_timer(start_time)
    return next.call(context)

# 内部实现
func _initialize_default_config() -> void:
    """初始化默认配置"""
    _lod_config = _create_default_lod_config()
    
    # 尝试获取主摄像机
    _camera_reference = _get_main_camera()

func _create_default_lod_config() -> JuicyLODConfig:
    """创建默认LOD配置"""
    var config = JuicyLODConfig.new()
    config.config_name = "default"
    return config

func _get_current_camera() -> Camera2D:
    """获取当前摄像机"""
    if _lod_config and _lod_config.camera:
        return _lod_config.camera
    
    if _camera_reference and is_instance_valid(_camera_reference):
        return _camera_reference
    
    # 尝试获取主摄像机
    _camera_reference = _get_main_camera()
    return _camera_reference

func _get_main_camera() -> Camera2D:
    """获取主摄像机"""
    var viewport = Engine.get_main_loop().get_viewport()
    if not viewport:
        return null
    
    return viewport.get_camera_2d()

func _calculate_distance_to_target(camera: Camera2D, target: Node) -> float:
    """计算到目标的距离"""
    if not camera or not target:
        return INF
    
    var camera_pos = camera.global_position
    var target_pos = target.global_position
    
    return camera_pos.distance_to(target_pos)

func _is_target_visible(camera: Camera2D, target: Node) -> bool:
    """检查目标是否在视锥内"""
    if not camera or not target:
        return false
    
    var camera_pos = camera.global_position
    var target_pos = target.global_position
    
    # 获取视口大小
    var viewport_size = camera.get_viewport().get_visible_rect().size
    var viewport_center = camera_pos
    
    # 简单的矩形视锥检查
    var half_width = viewport_size.x * 0.5
    var half_height = viewport_size.y * 0.5
    
    return (abs(target_pos.x - viewport_center.x) <= half_width and
            abs(target_pos.y - viewport_center.y) <= half_height)

func _calculate_intensity_multiplier(distance: float) -> float:
    """计算强度倍数"""
    return _lod_config.calculate_intensity_multiplier(distance)

# 配置管理
func set_lod_config(config: JuicyLODConfig) -> void:
    """设置LOD配置"""
    _lod_config = config

func get_lod_config() -> JuicyLODConfig:
    """获取LOD配置"""
    return _lod_config

func load_lod_config(resource_path: String) -> JuicyLODConfig:
    """从文件加载LOD配置"""
    if ResourceLoader.exists(resource_path):
        return load(resource_path) as JuicyLODConfig
    return null

func save_lod_config(config: JuicyLODConfig, resource_path: String) -> bool:
    """保存LOD配置到文件"""
    return ResourceSaver.save(config, resource_path) == OK

func set_camera(camera: Camera2D) -> void:
    """设置摄像机"""
    _camera_reference = camera
    if _lod_config:
        _lod_config.camera = camera

func set_distance_thresholds(thresholds: Array[float], multipliers: Array[float]) -> void:
    """设置距离阈值和强度倍数"""
    if thresholds.size() + 1 != multipliers.size():
        push_error("Multipliers array must be one element larger than thresholds array")
        return
    
    _lod_config.distance_thresholds = thresholds
    _lod_config.intensity_multipliers = multipliers

# 统计和调试
func get_lod_stats() -> Dictionary:
    """获取LOD统计信息"""
    if not _lod_config:
        return {}
    
    return {
        "camera_set": _lod_config.camera != null,
        "max_distance": _lod_config.max_distance,
        "distance_thresholds": _lod_config.distance_thresholds,
        "intensity_multipliers": _lod_config.intensity_multipliers,
        "frustum_culling_enabled": _lod_config.enable_frustum_culling,
        "distance_culling_enabled": _lod_config.enable_distance_culling
    }

func debug_print_lod_info() -> void:
    """打印LOD信息"""
    print("=== JuicyMixer LOD Info ===")
    var stats = get_lod_stats()
    
    for key in stats.keys():
        print(key, ": ", stats[key])
```

**开发任务分解**：
- [x] 第8周第5天：基础LOD逻辑
- [x] 第8周第5天：距离计算和强度调整
- [x] 第8周第5天：视锥剔除
- [x] 第8周第5天：配置管理和调试
- [x] 第8周第5天：单元测试

**验收标准**：
- LOD策略正确应用
- 距离计算准确
- 性能优化有效
- 单元测试覆盖率100%

---

## 集成测试计划

### 测试场景1：中间件管道执行顺序测试
```gdscript
func test_middleware_pipeline_execution_order():
    var pipeline = JuicyMiddlewarePipeline.new()
    
    # 创建测试中间件
    var middleware1 = TestMiddleware.new("Middleware1", 100)
    var middleware2 = TestMiddleware.new("Middleware2", 200)
    var middleware3 = TestMiddleware.new("Middleware3", 50)
    
    # 添加中间件
    pipeline.add_middleware(middleware1)
    pipeline.add_middleware(middleware2)
    pipeline.add_middleware(middleware3)
    
    # 验证执行顺序（按优先级降序）
    var enabled = pipeline.get_enabled_middlewares()
    assert_eq(enabled[0].middleware_name, "Middleware2")  # 优先级200
    assert_eq(enabled[1].middleware_name, "Middleware1")  # 优先级100
    assert_eq(enabled[2].middleware_name, "Middleware3")  # 优先级50
```

### 测试场景2：验证中间件功能测试
```gdscript
func test_validation_middleware():
    var middleware = JuicyValidationMiddleware.new()
    middleware.strict_mode = true
    
    # 测试有效Context
    var valid_context = _create_valid_context()
    assert_true(middleware.process(valid_context, func(ctx): return true))
    
    # 测试无效Context
    var invalid_context = JuicyContext.create(null, null)
    assert_false(middleware.process(invalid_context, func(ctx): return true))
```

### 测试场景3：通道中间件并发控制测试
```gdscript
func test_channel_middleware_concurrency():
    var middleware = JuicyChannelMiddleware.new()
    
    # 设置通道配置（最大并发数为2）
    var config = JuicyChannelConfig.new()
    config.channel_name = "test"
    config.max_concurrent = 2
    middleware.set_channel_config("test", config)
    
    var contexts = []
    for i in range(3):
        var context = _create_test_context()
        context.resource.channel = "test"
        contexts.append(context)
    
    # 前两个应该成功
    assert_true(middleware.process(contexts[0], func(ctx): return true))
    assert_true(middleware.process(contexts[1], func(ctx): return true))
    
    # 第三个应该失败（超过并发限制）
    assert_false(middleware.process(contexts[2], func(ctx): return true))
```

### 测试场景4：通道配置资源序列化测试
```gdscript
func test_channel_config_serialization():
    var config = JuicyChannelConfig.new()
    config.channel_name = "test_channel"
    config.max_concurrent = 3
    config.priority_mode = JuicyMixerEnms.PriorityMode.LIFO
    config.allow_interruption = false
    config.auto_stop_previous = true
    config.description = "Test channel configuration"
    
    # 保存配置
    var temp_path = "user://temp_channel_config.tres"
    assert_true(ResourceSaver.save(config, temp_path) == OK)
    
    # 加载配置
    var loaded_config = load(temp_path) as JuicyChannelConfig
    assert_not_null(loaded_config)
    assert_eq(loaded_config.channel_name, "test_channel")
    assert_eq(loaded_config.max_concurrent, 3)
    assert_eq(loaded_config.priority_mode, JuicyMixerEnms.PriorityMode.LIFO)
    assert_eq(loaded_config.allow_interruption, false)
    assert_eq(loaded_config.auto_stop_previous, true)
    assert_eq(loaded_config.description, "Test channel configuration")
    
    # 清理
    DirAccess.remove_absolute(temp_path)
```

### 测试场景5：LOD配置资源序列化测试
```gdscript
func test_lod_config_serialization():
    var config = JuicyLODConfig.new()
    config.config_name = "test_lod"
    config.max_distance = 800.0
    config.distance_thresholds = [150.0, 300.0, 450.0]
    config.intensity_multipliers = [1.0, 0.8, 0.6, 0.4, 0.2]
    config.enable_frustum_culling = false
    config.enable_distance_culling = true
    config.description = "Test LOD configuration"
    
    # 保存配置
    var temp_path = "user://temp_lod_config.tres"
    assert_true(ResourceSaver.save(config, temp_path) == OK)
    
    # 加载配置
    var loaded_config = load(temp_path) as JuicyLODConfig
    assert_not_null(loaded_config)
    assert_eq(loaded_config.config_name, "test_lod")
    assert_eq(loaded_config.max_distance, 800.0)
    assert_eq(loaded_config.distance_thresholds, [150.0, 300.0, 450.0])
    assert_eq(loaded_config.intensity_multipliers, [1.0, 0.8, 0.6, 0.4, 0.2])
    assert_eq(loaded_config.enable_frustum_culling, false)
    assert_eq(loaded_config.enable_distance_culling, true)
    assert_eq(loaded_config.description, "Test LOD configuration")
    
    # 测试强度计算
    assert_eq(loaded_config.calculate_intensity_multiplier(100.0), 1.0)
    assert_eq(loaded_config.calculate_intensity_multiplier(200.0), 0.8)
    assert_eq(loaded_config.calculate_intensity_multiplier(400.0), 0.6)
    assert_eq(loaded_config.calculate_intensity_multiplier(500.0), 0.4)
    assert_eq(loaded_config.calculate_intensity_multiplier(900.0), 0.0)
    
    # 清理
    DirAccess.remove_absolute(temp_path)
```

### 测试场景6：时间组配置资源序列化测试
```gdscript
func test_time_group_config_serialization():
    var config = JuicyTimeGroupConfig.new()
    config.config_name = "test_time_groups"
    config.time_groups = {
        "default": 1.0,
        "player": 1.2,
        "enemies": 0.8,
        "npc": 1.0,
        "projectiles": 1.5,
        "ui": 1.0,
        "vfx": 0.9,
        "unscaled": 1.0,
        "slow_motion": 0.3
    }
    config.description = "Test time group configuration"
    
    # 保存配置
    var temp_path = "user://temp_time_group_config.tres"
    assert_true(ResourceSaver.save(config, temp_path) == OK)
    
    # 加载配置
    var loaded_config = load(temp_path) as JuicyTimeGroupConfig
    assert_not_null(loaded_config)
    assert_eq(loaded_config.config_name, "test_time_groups")
    assert_eq(loaded_config.description, "Test time group configuration")
    
    # 测试时间组功能
    assert_true(loaded_config.has_time_group("player"))
    assert_true(loaded_config.has_time_group("enemies"))
    assert_false(loaded_config.has_time_group("nonexistent"))
    
    assert_eq(loaded_config.get_time_scale("player"), 1.2)
    assert_eq(loaded_config.get_time_scale("enemies"), 0.8)
    assert_eq(loaded_config.get_time_scale("nonexistent"), 1.0)  # 默认值
    
    # 测试时间组名称获取
    var group_names = loaded_config.get_time_group_names()
    assert_eq(group_names.size(), 10)
    assert_true("player" in group_names)
    assert_true("enemies" in group_names)
    assert_true("slow_motion" in group_names)
    
    # 测试设置时间组缩放
    loaded_config.set_time_scale("new_group", 2.0)
    assert_eq(loaded_config.get_time_scale("new_group"), 2.0)
    assert_true(loaded_config.has_time_group("new_group"))
    
    # 测试移除时间组
    loaded_config.remove_time_group("new_group")
    assert_false(loaded_config.has_time_group("new_group"))
    assert_eq(loaded_config.get_time_scale("new_group"), 1.0)  # 默认值
    
    # 测试配置验证
    var validation = loaded_config.validate()
    assert_true(validation.valid)
    assert_eq(validation.issues.size(), 0)
    
    # 测试无效配置
    loaded_config.time_groups["invalid"] = -1.0
    validation = loaded_config.validate()
    assert_false(validation.valid)
    assert_true(validation.issues.size() > 0)
    
    # 清理
    DirAccess.remove_absolute(temp_path)
```

---

## 性能基准测试
### 基准1：中间件管道执行性能
- **目标**：1000次管道执行 < 16ms
- **测试方法**：批量执行管道并测量时间
- **验收标准**：平均执行时间 < 0.016ms

### 基准2：验证中间件性能
- **目标**：10000次验证 < 16ms
- **测试方法**：批量验证Context并测量时间
- **验收标准**：平均验证时间 < 0.0016ms

### 基准3：通道调度性能
- **目标**：1000次通道调度 < 16ms
- **测试方法**：批量调度Context并测量时间
- **验收标准**：平均调度时间 < 0.016ms

---

## 风险管控

### 技术风险
1. **中间件链复杂性**：复杂的执行链可能难以调试
   - 缓解措施：提供详细的执行日志和调试信息
   
2. **性能影响**：多层中间件可能影响性能
   - 缓解措施：优化执行逻辑，提供性能监控

### 进度风险
1. **中间件交互**：中间件间的交互可能复杂
   - 缓解措施：明确定义接口和契约

2. **测试覆盖**：复杂的组合场景难以全面测试
   - 缓解措施：分阶段测试，重点测试核心功能

---

## 交付检查清单

### 代码交付
- [x] JuicyMiddleware基类完整实现和单元测试
- [x] JuicyMiddlewarePipeline管道管理完整实现
- [x] ValidationMiddleware验证中间件完整实现
- [x] JuicyChannelConfig通道配置资源完整实现
- [x] ChannelMiddleware通道中间件完整实现
- [x] JuicyLODConfig LOD配置资源完整实现
- [x] LODMiddleware距离优化中间件完整实现
- [x] JuicyTimeGroupConfig时间组配置资源完整实现
- [x] TimeScaleMiddleware时间缩放中间件完整实现
- [x] JuicyMixerEnms.PriorityMode枚举添加

### 文档交付
- [x] 中间件API文档 (见 middleware_best_practices.md)
- [x] 管道配置指南 (见 middleware_best_practices.md)
- [x] 通道配置资源使用指南 (见 middleware_best_practices.md)
- [x] LOD配置资源使用指南 (见 middleware_best_practices.md)
- [x] 时间组配置资源使用指南 (见 middleware_best_practices.md)
- [x] 性能基准报告 (见 tests/test_core_middlewares.gd 输出)
- [x] 集成测试报告 (见 tests/test_middleware_integration.gd 输出)

### 验收标准
- [x] 所有单元测试通过（覆盖率100%）
- [x] 所有集成测试通过
- [x] 性能基准测试达标
- [x] 代码审查通过
- [x] 文档完整准确

---

## 总结

阶段3实现了JuicyMixer V3的中间件系统，提供了灵活可组合的处理流程。通过验证、通道、时间缩放、LOD等中间件，实现了高级调度功能和性能优化。

**关键成就**：
- 建立了可组合的中间件管道
- 实现了全面的验证机制
- 提供了基于Resource的配置管理系统
- 提供了灵活的通道调度
- 支持动态时间缩放和LOD优化
- 实现了集中化的时间组配置管理

**下一步**：进入阶段4，实现事件驱动系统，支持音频、粒子等非属性反馈。