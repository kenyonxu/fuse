# InterruptionMiddleware API文档

## 概述

[`InterruptionMiddleware`](../../middleware/interruption_middleware.gd:5) 是中断中间件，在Director执行流程中处理中断，协调不同中断策略的执行，提供中断决策的钩子函数。

## 类定义

```gdscript
class_name InterruptionMiddleware
extends JuicyMiddleware
```

## 属性

| 属性名 | 类型 | 默认值 | 描述 |
|--------|------|--------|------|
| `_interruption_manager` | `JuicyInterruptionManager` | `null` | 内部中断管理器实例 |

## 构造函数

### `_init()`

创建新的中断中间件实例，设置中间件基本信息。

**示例:**
```gdscript
var middleware = InterruptionMiddleware.new()
print("中间件名称: ", middleware.middleware_name)  # 输出: InterruptionMiddleware
print("中间件优先级: ", middleware.priority)      # 输出: 100
```

## 中间件接口实现

### `initialize(config: Dictionary = {}) -> bool`

初始化中间件，创建中断管理器实例并设置默认配置。

**参数:**
- `config` (Dictionary, 可选): 配置字典

**返回值:**
- `bool`: 初始化是否成功

**示例:**
```gdscript
var middleware = InterruptionMiddleware.new()
var success = middleware.initialize({
    "enable_performance_monitoring": true,
    "enable_debug_logging": false
})
if success:
    print("中间件初始化成功")
```

### `before_play(context: Object) -> bool`

在播放前处理中断逻辑，检查是否需要中断现有效果。

**参数:**
- `context` (Object): 上下文对象

**返回值:**
- `bool`: 是否允许播放

**示例:**
```gdscript
# 此方法通常由系统内部调用
# 当播放新效果时，中间件会自动检查是否需要中断现有效果
var can_play = middleware.before_play(new_context)
if not can_play:
    print("新效果被中断策略阻止")
```

### `process(context: JuicyContext, next: Callable) -> bool`

处理阶段，每帧调用，处理过渡进度。

**参数:**
- `context` (JuicyContext): 上下文
- `next` (Callable): 下一个中间件的回调函数

**返回值:**
- `bool`: 执行是否成功

**示例:**
```gdscript
# 此方法通常由系统内部调用
# 在每帧更新中处理过渡进度
middleware.process(context, next_middleware_callback)
```

### `cleanup(context: JuicyContext) -> void`

清理阶段，在效果结束时调用，清理中断状态。

**参数:**
- `context` (JuicyContext): 上下文

**示例:**
```gdscript
# 此方法通常由系统内部调用
# 当效果结束时自动清理相关的中断状态
middleware.cleanup(context)
```

### `destroy() -> void`

销毁中间件，清理资源。

**示例:**
```gdscript
middleware.destroy()
```

## 配置管理

### `set_channel_config(channel: String, config: ChannelInterruptionConfig) -> void`

设置通道配置。

**参数:**
- `channel` (String): 通道名称
- `config` (ChannelInterruptionConfig): 通道配置

**示例:**
```gdscript
var config = ChannelInterruptionConfig.new()
config.channel_name = "ui_effects"
config.set_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
middleware.set_channel_config("ui_effects", config)
```

### `set_global_priority(resource_type: String, priority: int) -> void`

设置全局优先级。

**参数:**
- `resource_type` (String): 资源类型
- `priority` (int): 优先级

**示例:**
```gdscript
middleware.set_global_priority("JuicyTweenResource", 10)
middleware.set_global_priority("JuicyShakeResource", 5)
```

### `set_default_policy(policy: JuicyMixerEnms.InterruptionPolicy) -> void`

设置默认中断策略。

**参数:**
- `policy` (JuicyMixerEnms.InterruptionPolicy): 中断策略

**示例:**
```gdscript
middleware.set_default_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
```

## 状态查询

### `get_interruption_state(target: Node) -> Object`

获取目标的中断状态。

**参数:**
- `target` (Node): 目标节点

**返回值:**
- `Object`: 中断状态，如果不存在则返回null

**示例:**
```gdscript
var state = middleware.get_interruption_state(target_node)
if state:
    print("活跃上下文数量: ", state.get_active_context_count())
    print("队列上下文数量: ", state.get_queued_context_count())
```

### `get_interruption_stats() -> Dictionary`

获取中断统计信息。

**返回值:**
- `Dictionary`: 统计信息字典

**示例:**
```gdscript
var stats = middleware.get_interruption_stats()
print("中断统计: ", stats)
```

## 上下文生命周期事件处理

### `on_context_created(context: Object) -> void`

上下文创建时调用，检查中断机会。

**参数:**
- `context` (Object): 新创建的上下文

**示例:**
```gdscript
# 此方法通常由系统内部调用
# 当新上下文创建时自动触发
middleware.on_context_created(new_context)
```

### `on_context_destroyed(context: Object) -> void`

上下文销毁时调用，清理相关的中断状态。

**参数:**
- `context` (Object): 即将被销毁的上下文

**示例:**
```gdscript
# 此方法通常由系统内部调用
# 当上下文销毁时自动清理状态
middleware.on_context_destroyed(context)
```

### `on_context_paused(context: Object) -> void`

上下文暂停时调用。

**参数:**
- `context` (Object): 被暂停的上下文

**示例:**
```gdscript
# 此方法通常由系统内部调用
middleware.on_context_paused(context)
```

### `on_context_resumed(context: Object) -> void`

上下文恢复时调用。

**参数:**
- `context` (Object): 被恢复的上下文

**示例:**
```gdscript
# 此方法通常由系统内部调用
middleware.on_context_resumed(context)
```

## 性能监控

### `get_performance_stats() -> Dictionary`

获取性能统计信息。

**返回值:**
- `Dictionary`: 性能统计字典，包含基础统计和中断统计

**示例:**
```gdscript
var stats = middleware.get_performance_stats()
print("性能统计: ", stats)
```

## 使用示例

### 基本使用

```gdscript
# 创建中断中间件
var interruption_middleware = InterruptionMiddleware.new()

# 初始化中间件
interruption_middleware.initialize({
    "enable_performance_monitoring": true,
    "enable_debug_logging": false
})

# 设置通道配置
var ui_config = ChannelInterruptionConfig.new()
ui_config.channel_name = "ui_effects"
ui_config.set_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
ui_config.set_channel_priority(10)
interruption_middleware.set_channel_config("ui_effects", ui_config)

# 设置全局优先级
interruption_middleware.set_global_priority("JuicyTweenResource", 5)
interruption_middleware.set_global_priority("JuicyShakeResource", 8)

# 设置默认策略
interruption_middleware.set_default_policy(JuicyMixerEnms.InterruptionPolicy.STACK)

# 添加到中间件管道
JuicyMixer.add_middleware(interruption_middleware)
```

### 高级配置

```gdscript
# 创建并配置中断中间件
var middleware = InterruptionMiddleware.new()

# 初始化配置
var config = {
    "enable_performance_monitoring": true,
    "enable_debug_logging": true,
    "priority": 100,
    "max_log_entries": 100,
    "enable_auto_cleanup": true,
    "cleanup_threshold": 50
}
middleware.initialize(config)

# 配置多个通道
var channels = ["ui_effects", "combat_effects", "audio_effects", "environment_effects"]
for channel in channels:
    var channel_config = ChannelInterruptionConfig.new()
    channel_config.channel_name = channel
    
    # 根据通道类型设置不同策略
    match channel:
        "ui_effects":
            channel_config.set_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
            channel_config.set_channel_priority(10)
        "combat_effects":
            channel_config.set_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_STACK)
            channel_config.set_channel_priority(15)
        "audio_effects":
            channel_config.set_policy(JuicyMixerEnms.InterruptionPolicy.FADE_OUT_FADE_IN)
            channel_config.set_transition_duration(0.3)
        "environment_effects":
            channel_config.set_policy(JuicyMixerEnms.InterruptionPolicy.SMOOTH_TRANSITION)
            channel_config.set_transition_duration(0.5)
    
    middleware.set_channel_config(channel, channel_config)

# 设置资源类型优先级
var resource_priorities = {
    "JuicyShakeResource": 10,
    "JuicyTweenResource": 5,
    "JuicySpringResource": 7,
    "JuicyParticleResource": 8
}

for resource_type in resource_priorities:
    middleware.set_global_priority(resource_type, resource_priorities[resource_type])
```

### 状态监控和调试

```gdscript
# 监控中断状态
func monitor_interruption_state(target: Node):
    var state = middleware.get_interruption_state(target)
    if not state:
        print("目标没有中断状态")
        return
    
    print("=== 中断状态监控 ===")
    print("目标ID: ", state.target_id)
    print("活跃上下文: ", state.active_contexts)
    print("队列上下文: ", state.queued_contexts)
    print("当前策略: ", JuicyMixerEnms.get_interruption_policy_name(state.current_policy))
    
    if state.is_transitioning():
        print("正在过渡: ", state.transition_context)
        print("过渡进度: ", state.transition_progress)
    
    # 显示优先级队列
    var priority_queue = state.priority_queue
    print("优先级队列:")
    for item in priority_queue:
        print("  - ", item.context_id, " (优先级: ", item.priority, ")")

# 性能监控
func monitor_performance():
    var stats = middleware.get_performance_stats()
    print("=== 性能统计 ===")
    
    # 基础统计
    if stats.has("execution_count"):
        print("执行次数: ", stats.execution_count)
    if stats.has("total_execution_time"):
        print("总执行时间: ", stats.total_execution_time, "ms")
    if stats.has("average_execution_time"):
        print("平均执行时间: ", stats.average_execution_time, "ms")
    
    # 中断统计
    if stats.has("interruption_count"):
        print("中断次数: ", stats.interruption_count)
    if stats.has("total_interruption_time"):
        print("总中断时间: ", stats.total_interruption_time, "ms")
    if stats.has("average_interruption_time"):
        print("平均中断时间: ", stats.average_interruption_time, "ms")
    if stats.has("active_states"):
        print("活跃状态数: ", stats.active_states)
```

### 事件处理

```gdscript
# 监听中断事件
func setup_interruption_events():
    # 连接到JuicyMixer的事件系统（如果可用）
    if JuicyMixer.instance and JuicyMixer.instance.has_signal("interruption_occurred"):
        JuicyMixer.instance.interruption_occurred.connect(_on_interruption_occurred)
    
    if JuicyMixer.instance and JuicyMixer.instance.has_signal("interruption_resolved"):
        JuicyMixer.instance.interruption_resolved.connect(_on_interruption_resolved)

func _on_interruption_occurred(event_data: Dictionary):
    print("中断发生:")
    print("  事件类型: ", event_data.type)
    print("  新上下文: ", event_data.new_context)
    print("  现有上下文: ", event_data.existing_context)
    print("  目标: ", event_data.target)
    print("  时间戳: ", event_data.timestamp)

func _on_interruption_resolved(event_data: Dictionary):
    print("中断解决:")
    print("  上下文: ", event_data.context_id)
    print("  解决类型: ", event_data.resolution_type)
```

## 最佳实践

1. **中间件优先级**: 中断中间件应该具有高优先级，确保在其他中间件之前执行
2. **配置管理**: 在游戏启动时统一配置所有通道和优先级
3. **性能监控**: 定期检查性能统计，确保中断处理不会成为性能瓶颈
4. **事件监听**: 监听中断事件，用于调试和游戏逻辑响应

## 注意事项

1. **初始化顺序**: 确保在使用前正确初始化中间件
2. **线程安全**: 中间件不是线程安全的，应在主线程中使用
3. **资源清理**: 在不需要时调用destroy()方法清理资源
4. **配置验证**: 应用配置前验证其有效性

## 相关类

- [`JuicyInterruptionManager`](JuicyInterruptionManager.md) - 中断管理器
- [`InterruptionState`](InterruptionState.md) - 中断状态
- [`ChannelInterruptionConfig`](ChannelInterruptionConfig.md) - 通道中断配置
- [`JuicyMixerEnms.InterruptionPolicy`](JuicyMixerEnums.md) - 中断策略枚举