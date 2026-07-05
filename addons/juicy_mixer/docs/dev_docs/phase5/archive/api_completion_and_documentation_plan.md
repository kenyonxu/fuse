# API完善和文档开发计划

## 概述

本文档详细描述了JuicyMixer V3中API完善和文档的开发计划。该系统提供了简洁易用的API接口、Builder模式支持、批量操作功能和类型安全接口，同时提供全面的文档和示例，确保开发者能够快速上手和高效使用。

## 系统架构

API完善和文档系统由以下核心组件构成：

- **JuicyMixerAPI** - 统一API接口
- **JuicyMixerBuilder** - Builder模式实现
- **JuicyBatchAPI** - 批量操作API
- **JuicyDocumentation** - 文档系统

## 与现有系统的集成

### 统一API接口
- API需要封装所有系统的功能
- API需要提供简洁的使用方式
- API需要支持所有高级功能

### 向后兼容性
- API设计需要考虑未来扩展
- API接口需要保持稳定性
- API文档需要完整准确

### 性能和易用性
- API需要优化性能开销
- API需要提供类型安全
- API需要支持批量操作

## 开发时间线

**总体时间**：第16周（与性能优化并行开发，共1周）

## JuicyMixerAPI (统一API接口)

**文件路径**：`addons/juicy_mixer/core/juicy_mixer_api.gd`

**核心职责**：
- 提供简洁易用的API
- 封装所有系统功能
- 确保类型安全
- 支持高级功能

**详细实现计划**：

```gdscript
class_name JuicyMixerAPI
extends RefCounted

# 单例实例
static var _instance: JuicyMixerAPI

# 核心系统引用
var _director: JuicyDirector
var _interruption_manager: JuicyInterruptionManager
var _state_manager: JuicyStateManager
var _debugger: JuicyDebugger
var _performance_optimizer: JuicyPerformanceOptimizer

# API配置
var _default_time_scale: float = 1.0
var _default_channel: String = "default"
var _auto_cleanup: bool = true

func _init():
    if _instance == null:
        _instance = self
    
    # 初始化核心系统
    _initialize_core_systems()

static func get_instance() -> JuicyMixerAPI:
    if _instance == null:
        _instance = JuicyMixerAPI.new()
    return _instance

func _initialize_core_systems() -> void:
    _director = JuicyDirector.new()
    _interruption_manager = JuicyInterruptionManager.new()
    _state_manager = JuicyStateManager.new()
    _debugger = JuicyDebugger.new()
    _performance_optimizer = JuicyPerformanceOptimizer.new()

# 基础播放API
static func play(resource: JuicyFeedbackResource, target: Node) -> String:
    return get_instance()._director.play(resource, target)

static func play_with_config(resource: JuicyFeedbackResource, target: Node, config: Dictionary = {}) -> String:
    var instance = get_instance()
    var context_id = instance._director.play(resource, target)
    
    # 应用配置
    if not context_id.is_empty():
        var context = JuicyMixer.get_context(context_id)
        if context:
            if config.has("time_scale"):
                context.time_scale = config["time_scale"]
            if config.has("channel"):
                context.resource.channel = config["channel"]
            if config.has("priority"):
                context.priority = config["priority"]
            if config.has("loop"):
                context.loop = config["loop"]
    
    return context_id

static func stop(context_id: String) -> bool:
    return get_instance()._director.stop(context_id)

static func pause(context_id: String) -> bool:
    return get_instance()._director.pause(context_id)

static func resume(context_id: String) -> bool:
    return get_instance()._director.resume(context_id)

static func seek(context_id: String, progress: float) -> bool:
    return get_instance()._director.seek(context_id, progress)

static func set_time_scale(context_id: String, time_scale: float) -> bool:
    return get_instance()._director.set_time_scale(context_id, time_scale)

static func set_loop(context_id: String, loop: bool) -> bool:
    return get_instance()._director.set_loop(context_id, loop)

# 批量操作API
static func play_batch(resources: Array[JuicyFeedbackResource], targets: Array[Node]) -> Array[String]:
    var context_ids: Array[String] = []
    var instance = get_instance()
    
    for i in range(min(resources.size(), targets.size())):
        var context_id = instance._director.play(resources[i], targets[i])
        if not context_id.is_empty():
            context_ids.append(context_id)
    
    return context_ids

static func stop_batch(context_ids: Array[String]) -> Array[bool]:
    var results: Array[bool] = []
    var instance = get_instance()
    
    for context_id in context_ids:
        results.append(instance._director.stop(context_id))
    
    return results

static func pause_batch(context_ids: Array[String]) -> Array[bool]:
    var results: Array[bool] = []
    var instance = get_instance()
    
    for context_id in context_ids:
        results.append(instance._director.pause(context_id))
    
    return results

static func resume_batch(context_ids: Array[String]) -> Array[bool]:
    var results: Array[bool] = []
    var instance = get_instance()
    
    for context_id in context_ids:
        results.append(instance._director.resume(context_id))
    
    return results

# 查询API
static func get_context(context_id: String) -> JuicyContext:
    return get_instance()._director.get_context(context_id)

static func get_active_contexts() -> Array[String]:
    return get_instance()._director.get_active_contexts()

static func get_contexts_for_target(target: Node) -> Array[String]:
    return get_instance()._director.get_contexts_for_target(target)

static func get_contexts_for_channel(channel: String) -> Array[String]:
    return get_instance()._director.get_contexts_for_channel(channel)

static func is_context_active(context_id: String) -> bool:
    return get_instance()._director.is_context_active(context_id)

static func is_context_paused(context_id: String) -> bool:
    return get_instance()._director.is_context_paused(context_id)

static func is_context_completed(context_id: String) -> bool:
    return get_instance()._director.is_context_completed(context_id)

# 中断策略API
static func set_interruption_policy(context_id: String, policy: JuicyInterruptionManager.InterruptionPolicy) -> void:
    var instance = get_instance()
    instance._interruption_manager.set_context_policy(context_id, policy)

static func set_channel_interruption_policy(channel: String, policy: JuicyInterruptionManager.InterruptionPolicy) -> void:
    var instance = get_instance()
    instance._interruption_manager.set_channel_policy(channel, policy)

static func set_default_interruption_policy(policy: JuicyInterruptionManager.InterruptionPolicy) -> void:
    var instance = get_instance()
    instance._interruption_manager.set_default_policy(policy)

static func get_interruption_state(target: Node) -> JuicyInterruptionManager.InterruptionState:
    var instance = get_instance()
    return instance._interruption_manager.get_interruption_state(target)

# 状态管理API
static func create_state_snapshot(target: Node, context_id: String = "") -> String:
    var instance = get_instance()
    return instance._state_manager.create_snapshot(target, context_id)

static func restore_state_snapshot(target: Node, context_id: String) -> bool:
    var instance = get_instance()
    return instance._state_manager.auto_restore_state(target, context_id)

static func emergency_restore(target: Node) -> bool:
    var instance = get_instance()
    return instance._state_manager.emergency_restore(target)

static func register_emergency_target(target: Node) -> void:
    var instance = get_instance()
    instance._state_manager.register_emergency_target(target)

static func unregister_emergency_target(target: Node) -> void:
    var instance = get_instance()
    instance._state_manager.unregister_emergency_target(target)

# 调试API
static func enable_debug() -> void:
    var instance = get_instance()
    instance._debugger.enable_debug()

static func disable_debug() -> void:
    var instance = get_instance()
    instance._debugger.disable_debug()

static func enable_visualization() -> void:
    var instance = get_instance()
    instance._debugger.visualization_enabled = true

static func disable_visualization() -> void:
    var instance = get_instance()
    instance._debugger.visualization_enabled = false

static func get_debug_statistics() -> Dictionary:
    var instance = get_instance()
    return instance._debugger.get_statistics()

static func export_debug_data() -> Dictionary:
    var instance = get_instance()
    return instance._debugger.export_debug_data()

# 性能优化API
static func enable_optimization() -> void:
    var instance = get_instance()
    instance._performance_optimizer.enable_optimization(true)

static func disable_optimization() -> void:
    var instance = get_instance()
    instance._performance_optimizer.enable_optimization(false)

static func set_batch_size(size: int) -> void:
    var instance = get_instance()
    instance._performance_optimizer.set_batch_size(size)

static func set_cache_size(size: int) -> void:
    var instance = get_instance()
    instance._performance_optimizer.set_cache_size(size)

static func get_performance_metrics() -> Dictionary:
    var instance = get_instance()
    return instance._performance_optimizer.get_performance_metrics()

# 配置API
static func set_default_time_scale(time_scale: float) -> void:
    get_instance()._default_time_scale = time_scale

static func set_default_channel(channel: String) -> void:
    get_instance()._default_channel = channel

static func set_auto_cleanup(enabled: bool) -> void:
    get_instance()._auto_cleanup = enabled

static func get_default_time_scale() -> float:
    return get_instance()._default_time_scale

static func get_default_channel() -> String:
    return get_instance()._default_channel

static func is_auto_cleanup_enabled() -> bool:
    return get_instance()._auto_cleanup

# 工具API
static func cleanup_completed_contexts() -> int:
    return get_instance()._director.cleanup_completed_contexts()

static func stop_all_contexts() -> int:
    return get_instance()._director.stop_all_contexts()

static func pause_all_contexts() -> int:
    return get_instance()._director.pause_all_contexts()

static func resume_all_contexts() -> int:
    return get_instance()._director.resume_all_contexts()

static func get_system_statistics() -> Dictionary:
    var instance = get_instance()
    return {
        "director": instance._director.get_statistics(),
        "interruption": instance._interruption_manager.get_statistics(),
        "state": instance._state_manager.get_statistics(),
        "debug": instance._debugger.get_statistics(),
        "performance": instance._performance_optimizer.get_performance_metrics()
    }

# 事件API
static func connect_context_started(callback: Callable) -> void:
    JuicyEventBus.context_started.connect(callback)

static func connect_context_completed(callback: Callable) -> void:
    JuicyEventBus.context_completed.connect(callback)

static func connect_context_paused(callback: Callable) -> void:
    JuicyEventBus.context_paused.connect(callback)

static func connect_context_resumed(callback: Callable) -> void:
    JuicyEventBus.context_resumed.connect(callback)

static func connect_interruption_occurred(callback: Callable) -> void:
    JuicyEventBus.interruption_occurred.connect(callback)

static func connect_state_event(callback: Callable) -> void:
    JuicyEventBus.state_event.connect(callback)

static func disconnect_context_started(callback: Callable) -> void:
    JuicyEventBus.context_started.disconnect(callback)

static func disconnect_context_completed(callback: Callable) -> void:
    JuicyEventBus.context_completed.disconnect(callback)

static func disconnect_context_paused(callback: Callable) -> void:
    JuicyEventBus.context_paused.disconnect(callback)

static func disconnect_context_resumed(callback: Callable) -> void:
    JuicyEventBus.context_resumed.disconnect(callback)

static func disconnect_interruption_occurred(callback: Callable) -> void:
    JuicyEventBus.interruption_occurred.disconnect(callback)

static func disconnect_state_event(callback: Callable) -> void:
    JuicyEventBus.state_event.disconnect(callback)
```

**开发任务分解**：
- [ ] 第16周第1天：API接口设计
- [ ] 第16周第2天：基础API实现
- [ ] 第16周第3天：批量操作API
- [ ] 第16周第4天：类型安全验证
- [ ] 第16周第5天：API测试和优化

## JuicyMixerBuilder (Builder模式实现)

**文件路径**：`addons/juicy_mixer/core/juicy_mixer_builder.gd`

**核心职责**：
- 实现Builder模式
- 提供流畅的API接口
- 支持链式调用
- 确保类型安全

**详细实现计划**：

```gdscript
class_name JuicyMixerBuilder
extends RefCounted

# 构建状态
var _context: JuicyContext
var _resource: JuicyFeedbackResource
var _target: Node
var _config: Dictionary = {}

# 构建器创建
static func create(resource: JuicyFeedbackResource, target: Node) -> JuicyMixerBuilder:
    var builder = JuicyMixerBuilder.new()
    builder._resource = resource
    builder._target = target
    builder._context = JuicyContext.create(resource, target)
    return builder

# 时间控制
func set_time_scale(scale: float) -> JuicyMixerBuilder:
    _config["time_scale"] = scale
    return self

func set_duration(duration: float) -> JuicyMixerBuilder:
    _config["duration"] = duration
    return self

func set_delay(delay: float) -> JuicyMixerBuilder:
    _config["delay"] = delay
    return self

func set_loop(loop: bool) -> JuicyMixerBuilder:
    _config["loop"] = loop
    return self

func set_loop_count(count: int) -> JuicyMixerBuilder:
    _config["loop_count"] = count
    return self

# 通道和优先级
func set_channel(channel: String) -> JuicyMixerBuilder:
    _config["channel"] = channel
    return self

func set_priority(priority: int) -> JuicyMixerBuilder:
    _config["priority"] = priority
    return self

# 中断策略
func set_interruption_policy(policy: JuicyInterruptionManager.InterruptionPolicy) -> JuicyMixerBuilder:
    _config["interruption_policy"] = policy
    return self

func set_restart_on_interruption(restart: bool) -> JuicyMixerBuilder:
    _config["restart_on_interruption"] = restart
    return self

# 状态管理
func enable_state_snapshot(enabled: bool = true) -> JuicyMixerBuilder:
    _config["state_snapshot_enabled"] = enabled
    return self

func set_state_snapshot_frequency(frequency: float) -> JuicyMixerBuilder:
    _config["state_snapshot_frequency"] = frequency
    return self

func enable_emergency_restoration(enabled: bool = true) -> JuicyMixerBuilder:
    _config["emergency_restoration_enabled"] = enabled
    return self

# 调试和性能
func enable_debug(enabled: bool = true) -> JuicyMixerBuilder:
    _config["debug_enabled"] = enabled
    return self

func enable_visualization(enabled: bool = true) -> JuicyMixerBuilder:
    _config["visualization_enabled"] = enabled
    return self

func enable_performance_optimization(enabled: bool = true) -> JuicyMixerBuilder:
    _config["performance_optimization_enabled"] = enabled
    return self

# 自定义属性
func set_property(name: String, value: Variant) -> JuicyMixerBuilder:
    _config[name] = value
    return self

func set_properties(properties: Dictionary) -> JuicyMixerBuilder:
    for key in properties:
        _config[key] = properties[key]
    return self

# 条件执行
func set_condition(condition: String) -> JuicyMixerBuilder:
    _config["condition"] = condition
    return self

func set_weight(weight: float) -> JuicyMixerBuilder:
    _config["weight"] = weight
    return self

# 标签和元数据
func set_tag(tag: String) -> JuicyMixerBuilder:
    _config["tag"] = tag
    return self

func set_metadata(metadata: Dictionary) -> JuicyMixerBuilder:
    _config["metadata"] = metadata
    return self

# 回调和事件
func on_started(callback: Callable) -> JuicyMixerBuilder:
    _config["on_started"] = callback
    return self

func on_completed(callback: Callable) -> JuicyMixerBuilder:
    _config["on_completed"] = callback
    return self

func on_paused(callback: Callable) -> JuicyMixerBuilder:
    _config["on_paused"] = callback
    return self

func on_resumed(callback: Callable) -> JuicyMixerBuilder:
    _config["on_resumed"] = callback
    return self

func on_interrupted(callback: Callable) -> JuicyMixerBuilder:
    _config["on_interrupted"] = callback
    return self

# 构建和执行
func build() -> JuicyContext:
    # 应用配置到上下文
    _apply_config_to_context()
    return _context

func play() -> String:
    var context_id = _build_and_play()
    _connect_event_callbacks()
    return context_id

func play_and_forget() -> void:
    var context_id = play()
    # 设置自动清理
    if _config.get("auto_cleanup", true):
        JuicyMixerAPI.connect_context_completed(_auto_cleanup_callback)

func _apply_config_to_context() -> void:
    # 时间控制
    if _config.has("time_scale"):
        _context.time_scale = _config["time_scale"]
    if _config.has("duration"):
        _context.duration = _config["duration"]
    if _config.has("loop"):
        _context.loop = _config["loop"]
    if _config.has("loop_count"):
        _context.loop_count = _config["loop_count"]
    
    # 通道和优先级
    if _config.has("channel"):
        _context.resource.channel = _config["channel"]
    if _config.has("priority"):
        _context.priority = _config["priority"]
    
    # 应用其他配置
    for key in _config:
        if key in ["on_started", "on_completed", "on_paused", "on_resumed", "on_interrupted", "auto_cleanup"]:
            continue  # 跳过回调配置
        _context.set_custom_property(key, _config[key])

func _build_and_play() -> String:
    _apply_config_to_context()
    return JuicyMixerAPI.play(_resource, _target)

func _connect_event_callbacks() -> void:
    var context_id = _context.context_id
    
    if _config.has("on_started"):
        JuicyMixerAPI.connect_context_started(_wrap_callback(_config["on_started"], context_id))
    
    if _config.has("on_completed"):
        JuicyMixerAPI.connect_context_completed(_wrap_callback(_config["on_completed"], context_id))
    
    if _config.has("on_paused"):
        JuicyMixerAPI.connect_context_paused(_wrap_callback(_config["on_paused"], context_id))
    
    if _config.has("on_resumed"):
        JuicyMixerAPI.connect_context_resumed(_wrap_callback(_config["on_resumed"], context_id))
    
    if _config.has("on_interrupted"):
        JuicyMixerAPI.connect_interruption_occurred(_wrap_callback(_config["on_interrupted"], context_id))

func _wrap_callback(callback: Callable, context_id: String) -> Callable:
    return func(data):
        if data is JuicyContext and data.context_id == context_id:
            callback.call(data)
        elif data is Dictionary and data.get("context_id", "") == context_id:
            callback.call(data)

func _auto_cleanup_callback(context: JuicyContext) -> void:
    # 自动清理完成的效果
    JuicyMixerAPI.stop(context.context_id)
    JuicyMixerAPI.disconnect_context_completed(_auto_cleanup_callback)

# 静态便捷方法
static func quick_play(resource: JuicyFeedbackResource, target: Node) -> String:
    return create(resource, target).play()

static func quick_play_with_time_scale(resource: JuicyFeedbackResource, target: Node, time_scale: float) -> String:
    return create(resource, target).set_time_scale(time_scale).play()

static func quick_play_with_loop(resource: JuicyFeedbackResource, target: Node, loop: bool) -> String:
    return create(resource, target).set_loop(loop).play()

static func quick_play_with_channel(resource: JuicyFeedbackResource, target: Node, channel: String) -> String:
    return create(resource, target).set_channel(channel).play()

static func quick_play_with_interruption_policy(resource: JuicyFeedbackResource, target: Node, policy: JuicyInterruptionManager.InterruptionPolicy) -> String:
    return create(resource, target).set_interruption_policy(policy).play()

static func quick_play_with_state_snapshot(resource: JuicyFeedbackResource, target: Node) -> String:
    return create(resource, target).enable_state_snapshot().play()

static func quick_play_with_debug(resource: JuicyFeedbackResource, target: Node) -> String:
    return create(resource, target).enable_debug().play()
```

**开发任务分解**：
- [ ] 第16周第2天：Builder模式基础实现
- [ ] 第16周第3天：链式调用支持
- [ ] 第16周第4天：事件回调处理
- [ ] 第16周第5天：便捷方法和优化

## JuicyBatchAPI (批量操作API)

**文件路径**：`addons/juicy_mixer/core/juicy_batch_api.gd`

**核心职责**：
- 提供批量操作功能
- 优化批量处理性能
- 支持异步批量操作
- 提供批量操作结果

**详细实现计划**：

```gdscript
class_name JuicyBatchAPI
extends RefCounted

# 批量操作配置
class BatchConfig:
    var batch_size: int = 100
    var timeout: float = 0.1
    var parallel: bool = true
    var continue_on_error: bool = false

# 批量操作结果
class BatchResult:
    var success_count: int = 0
    var error_count: int = 0
    var results: Array = []
    var errors: Array = []
    var execution_time: float = 0.0

# 批量播放
static func batch_play(resources: Array[JuicyFeedbackResource], targets: Array[Node], config: BatchConfig = null) -> BatchResult:
    if config == null:
        config = BatchConfig.new()
    
    var result = BatchResult.new()
    var start_time = Time.get_ticks_msec() / 1000.0
    
    # 确保资源数量和目标数量一致
    var count = min(resources.size(), targets.size())
    
    if config.parallel:
        result = _parallel_batch_play(resources.slice(0, count), targets.slice(0, count), config)
    else:
        result = _sequential_batch_play(resources.slice(0, count), targets.slice(0, count), config)
    
    result.execution_time = Time.get_ticks_msec() / 1000.0 - start_time
    return result

static func _parallel_batch_play(resources: Array[JuicyFeedbackResource], targets: Array[Node], config: BatchConfig) -> BatchResult:
    var result = BatchResult.new()
    var batches = []
    
    # 分批处理
    for i in range(0, resources.size(), config.batch_size):
        var end_index = min(i + config.batch_size, resources.size())
        var batch_resources = resources.slice(i, end_index)
        var batch_targets = targets.slice(i, end_index)
        batches.append([batch_resources, batch_targets])
    
    # 并行执行批次
    for batch in batches:
        var batch_resources = batch[0]
        var batch_targets = batch[1]
        
        for j in range(batch_resources.size()):
            var resource = batch_resources[j]
            var target = batch_targets[j]
            
            try:
                var context_id = JuicyMixerAPI.play(resource, target)
                result.results.append(context_id)
                result.success_count += 1
            except:
                result.errors.append({"index": i + j, "error": "Failed to play effect"})
                result.error_count += 1
                
                if not config.continue_on_error:
                    break
        
        if result.error_count > 0 and not config.continue_on_error:
            break
    
    return result

static func _sequential_batch_play(resources: Array[JuicyFeedbackResource], targets: Array[Node], config: BatchConfig) -> BatchResult:
    var result = BatchResult.new()
    
    for i in range(resources.size()):
        var resource = resources[i]
        var target = targets[i]
        
        try:
            var context_id = JuicyMixerAPI.play(resource, target)
            result.results.append(context_id)
            result.success_count += 1
        except:
            result.errors.append({"index": i, "error": "Failed to play effect"})
            result.error_count += 1
            
            if not config.continue_on_error:
                break
    
    return result

# 批量停止
static func batch_stop(context_ids: Array[String], config: BatchConfig = null) -> BatchResult:
    if config == null:
        config = BatchConfig.new()
    
    var result = BatchResult.new()
    var start_time = Time.get_ticks_msec() / 1000.0
    
    if config.parallel:
        result = _parallel_batch_stop(context_ids, config)
    else:
        result = _sequential_batch_stop(context_ids, config)
    
    result.execution_time = Time.get_ticks_msec() / 1000.0 - start_time
    return result

static func _parallel_batch_stop(context_ids: Array[String], config: BatchConfig) -> BatchResult:
    var result = BatchResult.new()
    var batches = []
    
    # 分批处理
    for i in range(0, context_ids.size(), config.batch_size):
        var end_index = min(i + config.batch_size, context_ids.size())
        var batch_context_ids = context_ids.slice(i, end_index)
        batches.append(batch_context_ids)
    
    # 并行执行批次
    for batch in batches:
        for j in range(batch.size()):
            var context_id = batch[j]
            
            try:
                var success = JuicyMixerAPI.stop(context_id)
                result.results.append(success)
                if success:
                    result.success_count += 1
                else:
                    result.error_count += 1
            except:
                result.errors.append({"index": i + j, "error": "Failed to stop effect"})
                result.error_count += 1
                
                if not config.continue_on_error:
                    break
        
        if result.error_count > 0 and not config.continue_on_error:
            break
    
    return result

static func _sequential_batch_stop(context_ids: Array[String], config: BatchConfig) -> BatchResult:
    var result = BatchResult.new()
    
    for i in range(context_ids.size()):
        var context_id = context_ids[i]
        
        try:
            var success = JuicyMixerAPI.stop(context_id)
            result.results.append(success)
            if success:
                result.success_count += 1
            else:
                result.error_count += 1
        except:
            result.errors.append({"index": i, "error": "Failed to stop effect"})
            result.error_count += 1
            
            if not config.continue_on_error:
                break
    
    return result

# 批量暂停
static func batch_pause(context_ids: Array[String], config: BatchConfig = null) -> BatchResult:
    if config == null:
        config = BatchConfig.new()
    
    var result = BatchResult.new()
    var start_time = Time.get_ticks_msec() / 1000.0
    
    if config.parallel:
        result = _parallel_batch_pause(context_ids, config)
    else:
        result = _sequential_batch_pause(context_ids, config)
    
    result.execution_time = Time.get_ticks_msec() / 1000.0 - start_time
    return result

static func _parallel_batch_pause(context_ids: Array[String], config: BatchConfig) -> BatchResult:
    var result = BatchResult.new()
    var batches = []
    
    # 分批处理
    for i in range(0, context_ids.size(), config.batch_size):
        var end_index = min(i + config.batch_size, context_ids.size())
        var batch_context_ids = context_ids.slice(i, end_index)
        batches.append(batch_context_ids)
    
    # 并行执行批次
    for batch in batches:
        for j in range(batch.size()):
            var context_id = batch[j]
            
            try:
                var success = JuicyMixerAPI.pause(context_id)
                result.results.append(success)
                if success:
                    result.success_count += 1
                else:
                    result.error_count += 1
            except:
                result.errors.append({"index": i + j, "error": "Failed to pause effect"})
                result.error_count += 1
                
                if not config.continue_on_error:
                    break
        
        if result.error_count > 0 and not config.continue_on_error:
            break
    
    return result

static func _sequential_batch_pause(context_ids: Array[String], config: BatchConfig) -> BatchResult:
    var result = BatchResult.new()
    
    for i in range(context_ids.size()):
        var context_id = context_ids[i]
        
        try:
            var success = JuicyMixerAPI.pause(context_id)
            result.results.append(success)
            if success:
                result.success_count += 1
            else:
                result.error_count += 1
        except:
            result.errors.append({"index": i, "error": "Failed to pause effect"})
            result.error_count += 1
            
            if not config.continue_on_error:
                break
    
    return result

# 批量恢复
static func batch_resume(context_ids: Array[String], config: BatchConfig = null) -> BatchResult:
    if config == null:
        config = BatchConfig.new()
    
    var result = BatchResult.new()
    var start_time = Time.get_ticks_msec() / 1000.0
    
    if config.parallel:
        result = _parallel_batch_resume(context_ids, config)
    else:
        result = _sequential_batch_resume(context_ids, config)
    
    result.execution_time = Time.get_ticks_msec() / 1000.0 - start_time
    return result

static func _parallel_batch_resume(context_ids: Array[String], config: BatchConfig) -> BatchResult:
    var result = BatchResult.new()
    var batches = []
    
    # 分批处理
    for i in range(0, context_ids.size(), config.batch_size):
        var end_index = min(i + config.batch_size, context_ids.size())
        var batch_context_ids = context_ids.slice(i, end_index)
        batches.append(batch_context_ids)
    
    # 并行执行批次
    for batch in batches:
        for j in range(batch.size()):
            var context_id = batch[j]
            
            try:
                var success = JuicyMixerAPI.resume(context_id)
                result.results.append(success)
                if success:
                    result.success_count += 1
                else:
                    result.error_count += 1
            except:
                result.errors.append({"index": i + j, "error": "Failed to resume effect"})
                result.error_count += 1
                
                if not config.continue_on_error:
                    break
        
        if result.error_count > 0 and not config.continue_on_error:
            break
    
    return result

static func _sequential_batch_resume(context_ids: Array[String], config: BatchConfig) -> BatchResult:
    var result = BatchResult.new()
    
    for i in range(context_ids.size()):
        var context_id = context_ids[i]
        
        try:
            var success = JuicyMixerAPI.resume(context_id)
            result.results.append(success)
            if success:
                result.success_count += 1
            else:
                result.error_count += 1
        except:
            result.errors.append({"index": i, "error": "Failed to resume effect"})
            result.error_count += 1
            
            if not config.continue_on_error:
                break
    
    return result

# 异步批量操作
static func async_batch_play(resources: Array[JuicyFeedbackResource], targets: Array[Node], config: BatchConfig = null, callback: Callable = Callable()) -> void:
    var thread = Thread.new()
    thread.start(_async_batch_worker, {
        "operation": "play",
        "resources": resources,
        "targets": targets,
        "config": config,
        "callback": callback
    })

static func async_batch_stop(context_ids: Array[String], config: BatchConfig = null, callback: Callable = Callable()) -> void:
    var thread = Thread.new()
    thread.start(_async_batch_worker, {
        "operation": "stop",
        "context_ids": context_ids,
        "config": config,
        "callback": callback
    })

static func _async_batch_worker(data: Dictionary) -> void:
    var result
    
    match data.operation:
        "play":
            result = batch_play(data.resources, data.targets, data.config)
        "stop":
            result = batch_stop(data.context_ids, data.config)
        _:
            result = null
    
    # 调用回调
    if data.callback.is_valid():
        data.callback.call(result)
```

**开发任务分解**：
- [ ] 第16周第3天：批量操作基础实现
- [ ] 第16周第4天：并行和串行处理
- [ ] 第16周第4天：异步批量操作
- [ ] 第16周第5天：批量操作优化

## JuicyDocumentation (文档系统)

**文件路径**：`addons/juicy_mixer/docs/juicy_documentation.gd`

**核心职责**：
- 生成API文档
- 提供使用示例
- 管理文档版本
- 支持多格式导出

**详细实现计划**：

```gdscript
@tool
class_name JuicyDocumentation
extends RefCounted

# 文档配置
var _output_directory: String = "res://addons/juicy_mixer/docs/generated/"
var _template_directory: String = "res://addons/juicy_mixer/docs/templates/"
var _examples_directory: String = "res://addons/juicy_mixer/docs/examples/"

# 文档数据
var _api_documentation: Dictionary = {}
var _examples: Dictionary = {}
var _tutorials: Array[Dictionary] = []

# 文档生成器
var _markdown_generator: JuicyMarkdownGenerator
var _html_generator: JuicyHTMLGenerator
var _pdf_generator: JuicyPDFGenerator

func _init():
    _markdown_generator = JuicyMarkdownGenerator.new()
    _html_generator = JuicyHTMLGenerator.new()
    _pdf_generator = JuicyPDFGenerator.new()

# 生成API文档
func generate_api_documentation() -> void:
    _collect_api_data()
    _generate_api_markdown()
    _generate_api_html()
    _generate_api_examples()

func _collect_api_data() -> void:
    # 收集JuicyMixerAPI的文档
    _api_documentation["JuicyMixerAPI"] = _collect_class_documentation(JuicyMixerAPI)
    
    # 收集JuicyMixerBuilder的文档
    _api_documentation["JuicyMixerBuilder"] = _collect_class_documentation(JuicyMixerBuilder)
    
    # 收集JuicyBatchAPI的文档
    _api_documentation["JuicyBatchAPI"] = _collect_class_documentation(JuicyBatchAPI)
    
    # 收集其他核心类的文档
    var core_classes = [
        JuicyFeedbackResource,
        JuicyContext,
        JuicyDriver,
        JuicyDirector,
        JuicyInterruptionManager,
        JuicyStateManager
    ]
    
    for cls in core_classes:
        _api_documentation[cls.get_script().get_global_name()] = _collect_class_documentation(cls)

func _collect_class_documentation(cls: Object) -> Dictionary:
    var class_doc = {}
    
    # 获取类信息
    class_doc["name"] = cls.get_script().get_global_name()
    class_doc["description"] = _get_class_description(cls)
    class_doc["inherits"] = cls.get_base_script().get_global_name() if cls.get_base_script() else ""
    
    # 获取方法信息
    class_doc["methods"] = _get_class_methods(cls)
    
    # 获取属性信息
    class_doc["properties"] = _get_class_properties(cls)
    
    # 获取信号信息
    class_doc["signals"] = _get_class_signals(cls)
    
    # 获取常量信息
    class_doc["constants"] = _get_class_constants(cls)
    
    return class_doc

func _get_class_description(cls: Object) -> String:
    # 获取类的描述，这里简化实现
    return "Class description for " + cls.get_script().get_global_name()

func _get_class_methods(cls: Object) -> Array[Dictionary]:
    var methods = []
    
    # 获取类的方法列表
    var method_list = cls.get_method_list()
    
    for method in method_list:
        if method.name.begins_with("_"):
            continue  # 跳过私有方法
        
        var method_doc = {
            "name": method.name,
            "description": _get_method_description(cls, method.name),
            "parameters": _get_method_parameters(method),
            "return_type": method.return_val.type,
            "is_static": method.flags & METHOD_FLAG_STATIC != 0,
            "is_virtual": method.flags & METHOD_FLAG_VIRTUAL != 0
        }
        
        methods.append(method_doc)
    
    return methods

func _get_method_description(cls: Object, method_name: String) -> String:
    # 获取方法的描述，这里简化实现
    return "Method description for " + method_name

func _get_method_parameters(method: Dictionary) -> Array[Dictionary]:
    var parameters = []
    
    for arg in method.args:
        var param = {
            "name": arg.name,
            "type": arg.type,
            "default_value": arg.default_value if arg.has("default_value") else null,
            "description": _get_parameter_description(arg.name)
        }
        
        parameters.append(param)
    
    return parameters

func _get_parameter_description(param_name: String) -> String:
    # 获取参数的描述，这里简化实现
    return "Parameter description for " + param_name

func _get_class_properties(cls: Object) -> Array[Dictionary]:
    var properties = []
    
    # 获取类的属性列表
    var property_list = cls.get_property_list()
    
    for property in property_list:
        if property.name.begins_with("_"):
            continue  # 跳过私有属性
        
        var prop_doc = {
            "name": property.name,
            "type": property.type,
            "default_value": property.default_value if property.has("default_value") else null,
            "description": _get_property_description(property.name),
            "is_readonly": property.usage & PROPERTY_USAGE_READ_ONLY != 0,
            "is_export": property.usage & PROPERTY_USAGE_STORAGE != 0
        }
        
        properties.append(prop_doc)
    
    return properties

func _get_property_description(prop_name: String) -> String:
    # 获取属性的描述，这里简化实现
    return "Property description for " + prop_name

func _get_class_signals(cls: Object) -> Array[Dictionary]:
    var signals = []
    
    # 获取类的信号列表
    var signal_list = cls.get_signal_list()
    
    for signal in signal_list:
        var signal_doc = {
            "name": signal.name,
            "description": _get_signal_description(signal.name),
            "parameters": _get_signal_parameters(signal)
        }
        
        signals.append(signal_doc)
    
    return signals

func _get_signal_description(signal_name: String) -> String:
    # 获取信号的描述，这里简化实现
    return "Signal description for " + signal_name

func _get_signal_parameters(signal: Dictionary) -> Array[Dictionary]:
    var parameters = []
    
    for arg in signal.args:
        var param = {
            "name": arg.name,
            "type": arg.type,
            "description": _get_parameter_description(arg.name)
        }
        
        parameters.append(param)
    
    return parameters

func _get_class_constants(cls: Object) -> Array[Dictionary]:
    var constants = []
    
    # 获取类的常量列表
    var constant_list = cls.get_constant_list()
    
    for constant in constant_list:
        var const_doc = {
            "name": constant.name,
            "value": constant.value,
            "type": typeof(constant.value),
            "description": _get_constant_description(constant.name)
        }
        
        constants.append(const_doc)
    
    return constants

func _get_constant_description(const_name: String) -> String:
    # 获取常量的描述，这里简化实现
    return "Constant description for " + const_name

func _generate_api_markdown() -> void:
    var markdown_content = ""
    
    # 生成目录
    markdown_content += "# JuicyMixer V3 API 文档\n\n"
    markdown_content += "## 目录\n\n"
    
    for class_name in _api_documentation:
        markdown_content += "- [%s](#%s)\n" % [class_name, class_name.to_lower()]
    
    markdown_content += "\n"
    
    # 生成每个类的文档
    for class_name in _api_documentation:
        var class_doc = _api_documentation[class_name]
        markdown_content += _generate_class_markdown(class_doc)
    
    # 保存Markdown文件
    var file = FileAccess.open(_output_directory + "api_reference.md", FileAccess.WRITE)
    if file:
        file.store_string(markdown_content)
        file.close()

func _generate_class_markdown(class_doc: Dictionary) -> String:
    var markdown = ""
    
    # 类标题和描述
    markdown += "## %s\n\n" % class_doc["name"]
    markdown += "%s\n\n" % class_doc["description"]
    
    if not class_doc["inherits"].is_empty():
        markdown += "**继承自:** %s\n\n" % class_doc["inherits"]
    
    # 方法文档
    if not class_doc["methods"].is_empty():
        markdown += "### 方法\n\n"
        
        for method in class_doc["methods"]:
            markdown += _generate_method_markdown(method)
    
    # 属性文档
    if not class_doc["properties"].is_empty():
        markdown += "### 属性\n\n"
        
        for prop in class_doc["properties"]:
            markdown += _generate_property_markdown(prop)
    
    # 信号文档
    if not class_doc["signals"].is_empty():
        markdown += "### 信号\n\n"
        
        for signal in class_doc["signals"]:
            markdown += _generate_signal_markdown(signal)
    
    # 常量文档
    if not class_doc["constants"].is_empty():
        markdown += "### 常量\n\n"
        
        for constant in class_doc["constants"]:
            markdown += _generate_constant_markdown(constant)
    
    markdown += "\n"
    
    return markdown

func _generate_method_markdown(method: Dictionary) -> String:
    var markdown = ""
    
    # 方法签名
    var signature = "#### %s(" % method["name"]
    
    for i in range(method["parameters"].size()):
        var param = method["parameters"][i]
        signature += param["name"] + ": " + _type_to_string(param["type"])
        
        if param["default_value"] != null:
            signature += " = " + str(param["default_value"])
        
        if i < method["parameters"].size() - 1:
            signature += ", "
    
    signature += ") -> " + _type_to_string(method["return_type"])
    
    if method["is_static"]:
        signature = "static " + signature
    
    markdown += signature + "\n\n"
    
    # 方法描述
    markdown += "%s\n\n" % method["description"]
    
    # 参数描述
    if not method["parameters"].is_empty():
        markdown += "**参数:**\n\n"
        
        for param in method["parameters"]:
            markdown += "- `%s: %s` - %s\n" % [
                param["name"],
                _type_to_string(param["type"]),
                param["description"]
            ]
        
        markdown += "\n"
    
    # 返回值描述
    markdown += "**返回值:** `%s`\n\n" % _type_to_string(method["return_type"])
    
    return markdown

func _generate_property_markdown(prop: Dictionary) -> String:
    var markdown = ""
    
    # 属性签名
    var signature = "#### %s: %s" % [prop["name"], _type_to_string(prop["type"])]
    
    if prop["is_readonly"]:
        signature += " (只读)"
    
    if prop["is_export"]:
        signature += " (可导出)"
    
    markdown += signature + "\n\n"
    
    # 属性描述
    markdown += "%s\n\n" % prop["description"]
    
    # 默认值
    if prop["default_value"] != null:
        markdown += "**默认值:** `%s`\n\n" % str(prop["default_value"])
    
    return markdown

func _generate_signal_markdown(signal: Dictionary) -> String:
    var markdown = ""
    
    # 信号签名
    var signature = "#### %s(" % signal["name"]
    
    for i in range(signal["parameters"].size()):
        var param = signal["parameters"][i]
        signature += param["name"] + ": " + _type_to_string(param["type"])
        
        if i < signal["parameters"].size() - 1:
            signature += ", "
    
    signature += ")"
    
    markdown += signature + "\n\n"
    
    # 信号描述
    markdown += "%s\n\n" % signal["description"]
    
    # 参数描述
    if not signal["parameters"].is_empty():
        markdown += "**参数:**\n\n"
        
        for param in signal["parameters"]:
            markdown += "- `%s: %s` - %s\n" % [
                param["name"],
                _type_to_string(param["type"]),
                param["description"]
            ]
        
        markdown += "\n"
    
    return markdown

func _generate_constant_markdown(constant: Dictionary) -> String:
    var markdown = ""
    
    # 常量签名
    var signature = "#### %s: %s" % [constant["name"], _type_to_string(constant["type"])]
    
    markdown += signature + "\n\n"
    
    # 常量描述
    markdown += "%s\n\n" % constant["description"]
    
    # 常量值
    markdown += "**值:** `%s`\n\n" % str(constant["value"])
    
    return markdown

func _type_to_string(type: int) -> String:
    match type:
        TYPE_NIL:
            return "null"
        TYPE_BOOL:
            return "bool"
        TYPE_INT:
            return "int"
        TYPE_FLOAT:
            return "float"
        TYPE_STRING:
            return "String"
        TYPE_ARRAY:
            return "Array"
        TYPE_DICTIONARY:
            return "Dictionary"
        TYPE_OBJECT:
            return "Object"
        TYPE_CALLABLE:
            return "Callable"
        _:
            return "Variant"

func _generate_api_html() -> void:
    var html_content = _html_generator.generate_api_html(_api_documentation)
    
    # 保存HTML文件
    var file = FileAccess.open(_output_directory + "api_reference.html", FileAccess.WRITE)
    if file:
        file.store_string(html_content)
        file.close()

func _generate_api_examples() -> void:
    var examples_content = "# JuicyMixer V3 API 示例\n\n"
    
    # 基础使用示例
    examples_content += "## 基础使用\n\n"
    examples_content += _generate_basic_examples()
    
    # 高级功能示例
    examples_content += "## 高级功能\n\n"
    examples_content += _generate_advanced_examples()
    
    # 最佳实践示例
    examples_content += "## 最佳实践\n\n"
    examples_content += _generate_best_practice_examples()
    
    # 保存示例文件
    var file = FileAccess.open(_output_directory + "api_examples.md", FileAccess.WRITE)
    if file:
        file.store_string(examples_content)
        file.close()

func _generate_basic_examples() -> String:
    var examples = ""
    
    examples += "### 播放效果\n\n"
    examples += "```gdscript\n"
    examples += "# 基础播放\n"
    examples += "var context_id = JuicyMixerAPI.play(effect_resource, target_node)\n\n"
    examples += "# 使用Builder模式\n"
    examples += "var context_id = JuicyMixerBuilder.create(effect_resource, target_node)\n"
    examples += "    .set_time_scale(2.0)\n"
    examples += "    .set_loop(true)\n"
    examples += "    .play()\n"
    examples += "```\n\n"
    
    examples += "### 停止效果\n\n"
    examples += "```gdscript\n"
    examples += "JuicyMixerAPI.stop(context_id)\n"
    examples += "```\n\n"
    
    return examples

func _generate_advanced_examples() -> String:
    var examples = ""
    
    examples += "### 批量操作\n\n"
    examples += "```gdscript\n"
    examples += "# 批量播放\n"
    examples += "var resources = [effect1, effect2, effect3]\n"
    examples += "var targets = [node1, node2, node3]\n"
    examples += "var context_ids = JuicyMixerAPI.play_batch(resources, targets)\n\n"
    examples += "# 使用批量API\n"
    examples += "var config = JuicyBatchAPI.BatchConfig.new()\n"
    examples += "config.batch_size = 10\n"
    examples += "config.parallel = true\n"
    examples += "var result = JuicyBatchAPI.batch_play(resources, targets, config)\n"
    examples += "print(\"成功播放: %d, 失败: %d\" % [result.success_count, result.error_count])\n"
    examples += "```\n\n"
    
    examples += "### 中断策略\n\n"
    examples += "```gdscript\n"
    examples += "# 设置中断策略\n"
    examples += "JuicyMixerAPI.set_default_interruption_policy(JuicyInterruptionManager.InterruptionPolicy.SMOOTH_TRANSITION)\n\n"
    examples += "# 为特定上下文设置策略\n"
    examples += "JuicyMixerAPI.set_interruption_policy(context_id, JuicyInterruptionManager.InterruptionPolicy.STACK)\n"
    examples += "```\n\n"
    
    return examples

func _generate_best_practice_examples() -> String:
    var examples = ""
    
    examples += "### 性能优化\n\n"
    examples += "```gdscript\n"
    examples += "# 启用性能优化\n"
    examples += "JuicyMixerAPI.enable_optimization()\n\n"
    examples += "# 设置合适的批处理大小\n"
    examples += "JuicyMixerAPI.set_batch_size(50)\n\n"
    examples += "# 启用对象池\n"
    examples += "JuicyMixerAPI.enable_object_pooling()\n"
    examples += "```\n\n"
    
    examples += "### 内存管理\n\n"
    examples += "```gdscript\n"
    examples += "# 启用状态快照\n"
    examples += "JuicyMixerAPI.create_state_snapshot(target_node)\n\n"
    examples += "# 注册紧急恢复目标\n"
    examples += "JuicyMixerAPI.register_emergency_target(target_node)\n\n"
    examples += "# 启用自动清理\n"
    examples += "JuicyMixerAPI.set_auto_cleanup(true)\n"
    examples += "```\n\n"
    
    return examples

# 生成教程文档
func generate_tutorials() -> void:
    _collect_tutorial_data()
    _generate_tutorial_markdown()

func _collect_tutorial_data() -> void:
    # 收集教程数据
    _tutorials = [
        {
            "title": "快速入门",
            "description": "学习如何快速开始使用JuicyMixer V3",
            "content": _get_quick_start_content(),
            "difficulty": "beginner"
        },
        {
            "title": "序列化系统",
            "description": "学习如何使用序列化系统创建复杂效果序列",
            "content": _get_sequence_system_content(),
            "difficulty": "intermediate"
        },
        {
            "title": "中断策略",
            "description": "学习如何使用中断策略管理效果交互",
            "content": _get_interruption_policy_content(),
            "difficulty": "intermediate"
        },
        {
            "title": "性能优化",
            "description": "学习如何优化JuicyMixer的性能",
            "content": _get_performance_optimization_content(),
            "difficulty": "advanced"
        }
    ]

func _get_quick_start_content() -> String:
    return """
# 快速入门

## 安装

1. 将JuicyMixer插件添加到您的Godot项目中
2. 在项目设置中启用插件
3. 重新启动编辑器

## 基础使用

```gdscript
# 创建效果资源
var effect = JuicyShakeResource.new()
effect.intensity = 10.0
effect.duration = 1.0

# 播放效果
var context_id = JuicyMixerAPI.play(effect, $Sprite2D)
```

## 下一步

- 阅读API文档了解更多功能
- 查看示例代码
- 学习高级功能
"""

func _get_sequence_system_content() -> String:
    return """
# 序列化系统

序列化系统允许您创建复杂的效果序列，支持顺序执行、并行执行和循环。

## 创建序列

```gdscript
var sequence = JuicySequenceResource.new()

# 添加序列项
var item1 = JuicySequenceResource.JuicySequenceItem.new()
item1.resource = shake_effect
item1.delay = 0.5

var item2 = JuicySequenceResource.JuicySequenceItem.new()
item2.resource = fade_effect

sequence.sequence_items = [item1, item2]
```

## 配置序列

```gdscript
# 设置为并行执行
sequence.parallel = true

# 设置循环
sequence.loop_sequence = true
sequence.loop_count = 3

# 设置随机顺序
sequence.random_order = true
```

## 播放序列

```gdscript
var context_id = JuicyMixerAPI.play(sequence, $Sprite2D)
```
"""

func _get_interruption_policy_content() -> String:
    return """
# 中断策略

中断策略允许您控制效果之间的交互方式。

## 可用策略

- **STACK**: 堆叠新效果到队列
- **RESTART**: 重启效果
- **IGNORE**: 忽略新效果
- **SMOOTH_TRANSITION**: 平滑过渡到新效果
- **PRIORITY_OVERRIDE**: 优先级覆盖
- **FADE_OUT_FADE_IN**: 淡出淡入

## 设置策略

```gdscript
# 全局默认策略
JuicyMixerAPI.set_default_interruption_policy(JuicyInterruptionManager.InterruptionPolicy.SMOOTH_TRANSITION)

# 特定通道策略
JuicyMixerAPI.set_channel_interruption_policy("ui", JuicyInterruptionManager.InterruptionPolicy.STACK)

# 特定上下文策略
JuicyMixerAPI.set_interruption_policy(context_id, JuicyInterruptionManager.InterruptionPolicy.RESTART)
```
"""

func _get_performance_optimization_content() -> String:
    return """
# 性能优化

性能优化确保JuicyMixer能够高效处理大量效果实例。

## 启用优化

```gdscript
# 启用性能优化
JuicyMixerAPI.enable_optimization()

# 设置批处理大小
JuicyMixerAPI.set_batch_size(100)

# 设置缓存大小
JuicyMixerAPI.set_cache_size(1000)
```

## 使用批量操作

```gdscript
# 批量播放
var config = JuicyBatchAPI.BatchConfig.new()
config.parallel = true
config.batch_size = 50

var result = JuicyBatchAPI.batch_play(resources, targets, config)
```

## 内存管理

```gdscript
# 启用对象池
JuicyMixerAPI.enable_object_pooling()

# 设置自动清理
JuicyMixerAPI.set_auto_cleanup(true)

# 注册紧急恢复目标
JuicyMixerAPI.register_emergency_target(critical_node)
```
"""

func _generate_tutorial_markdown() -> void:
    var markdown_content = "# JuicyMixer V3 教程\n\n"
    
    # 生成目录
    markdown_content += "## 目录\n\n"
    
    for tutorial in _tutorials:
        markdown_content += "- [%s](#%s)\n" % [tutorial["title"], tutorial["title"].to_lower().replace(" ", "-")]
    
    markdown_content += "\n"
    
    # 生成每个教程的内容
    for tutorial in _tutorials:
        markdown_content += "## %s\n\n" % tutorial["title"]
        markdown_content += "**难度:** %s\n\n" % tutorial["difficulty"]
        markdown_content += "%s\n\n" % tutorial["description"]
        markdown_content += tutorial["content"]
        markdown_content += "\n"
    
    # 保存教程文件
    var file = FileAccess.open(_output_directory + "tutorials.md", FileAccess.WRITE)
    if file:
        file.store_string(markdown_content)
        file.close()

# 生成完整文档
func generate_full_documentation() -> void:
    generate_api_documentation()
    generate_tutorials()
    _generate_index_page()
    _generate_search_index()

func _generate_index_page() -> void:
    var index_content = """
# JuicyMixer V3 文档

欢迎来到JuicyMixer V3文档！这里包含了完整的API参考、教程和示例。

## 快速链接

- [API参考](api_reference.md)
- [教程](tutorials.md)
- [示例](api_examples.md)

## 主要功能

- 序列化与组合系统
- 中断策略系统
- 状态还原机制
- 编辑器预览功能
- 调试与可视化系统
- 性能优化与池化系统

## 开始使用

如果您是第一次使用JuicyMixer，建议从[快速入门教程](tutorials.md#快速入门)开始。

## 获取帮助

如果您在使用过程中遇到问题，可以：

1. 查看[API参考](api_reference.md)
2. 阅读[教程](tutorials.md)
3. 查看[示例代码](api_examples.md)
4. 启用调试功能获取更多信息
"""
    
    # 保存索引文件
    var file = FileAccess.open(_output_directory + "README.md", FileAccess.WRITE)
    if file:
        file.store_string(index_content)
        file.close()

func _generate_search_index() -> void:
    var search_index = {
        "version": "3.0",
        "timestamp": Time.get_ticks_msec() / 1000.0,
        "classes": [],
        "methods": [],
        "properties": [],
        "examples": []
    }
    
    # 构建搜索索引
    for class_name in _api_documentation:
        var class_doc = _api_documentation[class_name]
        
        # 添加类到索引
        search_index["classes"].append({
            "name": class_name,
            "description": class_doc["description"],
            "url": "api_reference.md#" + class_name.to_lower()
        })
        
        # 添加方法到索引
        for method in class_doc["methods"]:
            search_index["methods"].append({
                "name": method["name"],
                "class": class_name,
                "description": method["description"],
                "url": "api_reference.md#" + class_name.to_lower() + "-" + method["name"].to_lower()
            })
        
        # 添加属性到索引
        for prop in class_doc["properties"]:
            search_index["properties"].append({
                "name": prop["name"],
                "class": class_name,
                "description": prop["description"],
                "url": "api_reference.md#" + class_name.to_lower() + "-" + prop["name"].to_lower()
            })
    
    # 保存搜索索引
    var file = FileAccess.open(_output_directory + "search_index.json", FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(search_index))
        file.close()

# 导出文档
func export_documentation(format: String = "markdown") -> void:
    match format:
        "markdown":
            generate_full_documentation()
        "html":
            _export_html_documentation()
        "pdf":
            _export_pdf_documentation()

func _export_html_documentation() -> void:
    # 导出HTML格式文档
    generate_api_documentation()
    generate_tutorials()
    
    # 这里应该使用HTML生成器生成完整的HTML文档
    print("HTML文档导出完成")

func _export_pdf_documentation() -> void:
    # 导出PDF格式文档
    generate_api_documentation()
    generate_tutorials()
    
    # 这里应该使用PDF生成器生成完整的PDF文档
    print("PDF文档导出完成")
```

**开发任务分解**：
- [ ] 第16周第3天：API参考文档
- [ ] 第16周第4天：使用指南和教程
- [ ] 第16周第5天：示例项目和最佳实践
- [ ] 第16周第5天：文档生成工具

## 测试计划

### 单元测试
- JuicyMixerAPI接口测试
- JuicyMixerBuilder构建器测试
- JuicyBatchAPI批量操作测试
- JuicyDocumentation文档生成测试

### 集成测试
- API与所有系统集成测试
- 文档生成完整性测试

### 文档测试
- API文档准确性验证
- 示例代码可执行性验证
- 教程完整性验证

## 交付检查清单

### 代码交付
- [ ] JuicyMixerAPI统一API
- [ ] JuicyMixerBuilder构建器模式
- [ ] JuicyBatchAPI批量操作API
- [ ] JuicyDocumentation文档系统
- [ ] 单元测试和集成测试

### 文档交付
- [ ] API参考文档
- [ ] 使用指南和教程
- [ ] 示例项目和最佳实践
- [ ] 文档生成工具

### 验收标准
- [ ] 所有单元测试通过（覆盖率100%）
- [ ] 所有集成测试通过
- [ ] API文档完整准确
- [ ] 示例代码可执行
- [ ] 代码审查通过

## 风险管控

### 技术风险
1. **API复杂性**：复杂的API设计可能影响易用性
   - 缓解措施：提供多层次的API接口，从简单到高级

2. **文档维护**：文档可能与代码不同步
   - 缓解措施：实现自动化文档生成和验证

### 进度风险
1. **文档工作量**：完整的文档编写可能比预期耗时
   - 缓解措施：优先编写核心API文档，后续补充

## 总结

API完善和文档系统是JuicyMixer V3的重要组成部分，它提供了简洁易用的API接口和全面的文档支持。通过Builder模式、批量操作和类型安全接口，开发者可以高效地使用系统功能。

**关键成就**：
- 实现了简洁易用的统一API
- 提供了强大的Builder模式支持
- 确保了高效的批量操作功能
- 提供了全面的文档和示例

API完善和文档系统将为JuicyMixer V3用户提供优秀的开发体验，使系统的学习和使用变得更加便捷。