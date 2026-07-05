# 核心中间件系统开发计划

## 概述

本模块负责实现中间件系统的核心基础架构，包括中间件基类和管道管理系统。

## 系统集成与优化要求

### 1. 与JuicyDirector的深度集成
**Director执行流程集成**：
- 中间件管道需要完全集成到Director的执行流程中
- 修改Director的`_execute_drivers()`方法，在Driver执行前先执行中间件管道
- 确保中间件的执行结果正确传递给Driver系统

**Context生命周期管理**：
- 中间件需要与Director的Context生命周期保持同步
- 实现中间件的`on_context_created()`、`on_context_destroyed()`钩子与Director的集成
- 确保中间件状态在Context完成时正确清理

### 2. 与Driver系统的协同优化
**属性缓冲协调**：
- 中间件需要与Driver共享JuicyPropertyBuffer实例
- 实现中间件级别的属性修改，支持全局效果调整
- 确保中间件和Driver的属性写入顺序正确

### 3. 与JuicyContext的增强集成
**Context数据扩展**：
- 中间件需要能够向Context添加自定义数据
- 实现中间件专用的数据存储区域，避免与Driver数据冲突
- 支持中间件之间的数据共享和传递

### 4. 性能优化和资源管理
**执行效率优化**：
- 实现中间件的懒加载和按需激活
- 添加中间件执行缓存，避免重复计算
- 优化中间件链的构建和执行性能

**内存管理**：
- 实现中间件对象池，减少内存分配
- 优化中间件状态存储，减少内存占用
- 添加中间件资源的自动清理机制

### 5. 错误处理和调试增强
**错误传播**：
- 实现中间件错误的正确传播和处理
- 添加中间件级别的错误恢复机制
- 支持中间件错误的隔离，避免影响整个管道

**调试支持**：
- 集成阶段1-2的调试和监控系统
- 添加中间件执行的可视化和日志
- 实现中间件性能的实时监控

## 核心组件详细设计

### 1. JuicyMiddleware (中间件基类)

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
- [ ] 第7周第1天：基础类结构和元信息
- [ ] 第7周第1天：核心接口定义
- [ ] 第7周第2天：生命周期钩子
- [ ] 第7周第2天：配置和验证接口
- [ ] 第7周第3天：性能监控和日志
- [ ] 第7周第3天：单元测试和文档

**验收标准**：
- 基类接口定义完整
- 生命周期管理正确
- 性能监控功能正常
- 单元测试覆盖率100%

---

### 2. JuicyMiddlewarePipeline (管道管理)

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
- [ ] 第7周第4天：基础类结构和中间件管理
- [ ] 第7周第5天：执行链构建和管道执行
- [ ] 第8周第1天：生命周期钩子和配置管理
- [ ] 第8周第2天：统计和调试功能
- [ ] 第8周第3天：错误处理和异常安全
- [ ] 第8周第4天：性能优化和单元测试
- [ ] 第8周第5天：集成测试和文档

**验收标准**：
- 中间件注册和管理正常
- 执行链构建正确
- 管道执行稳定可靠
- 性能满足设计要求
- 单元测试覆盖率100%
---

## 测试计划

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