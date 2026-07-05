# JuicyInterruptionManager API文档

## 概述

[`JuicyInterruptionManager`](../../core/juicy_interruption_manager.gd:5) 是中断管理器，负责管理效果中断策略，处理多种中断模式，实现平滑过渡机制，提供中断状态监控。

## 类定义

```gdscript
class_name JuicyInterruptionManager
extends RefCounted
```

## 内部属性

| 属性名 | 类型 | 描述 |
|--------|------|------|
| `_interruption_states` | `Dictionary` | target_id -> InterruptionState 映射 |
| `_policy_configs` | `Dictionary` | channel_name -> ChannelInterruptionConfig 映射 |
| `_default_policy` | `JuicyMixerEnms.InterruptionPolicy` | 默认中断策略 |
| `_transition_resources` | `Dictionary` | transition_type -> Resource 映射 |
| `_global_priority_map` | `Dictionary` | resource_type -> priority 映射 |
| `_interruption_count` | `int` | 中断计数 |
| `_total_interruption_time` | `float` | 总中断时间 |
| `_last_interruption_time` | `float` | 最后中断时间 |

## 核心中断处理接口

### `handle_interruption(new_context_id: String, existing_context_id: String, policy: JuicyMixerEnms.InterruptionPolicy) -> bool`

处理中断请求，这是中断系统的核心方法。

**参数:**
- `new_context_id` (String): 新上下文ID
- `existing_context_id` (String): 现有上下文ID
- `policy` (JuicyMixerEnms.InterruptionPolicy): 中断策略

**返回值:**
- `bool`: 中断处理是否成功

**示例:**
```gdscript
var manager = JuicyInterruptionManager.new()
var success = manager.handle_interruption(
    "new_effect_001", 
    "existing_effect_001", 
    JuicyMixerEnms.InterruptionPolicy.STACK
)
if success:
    print("中断处理成功")
else:
    print("中断处理失败")
```

## 具体中断策略实现

### 堆叠中断策略

系统内部使用 `_handle_stack_interruption` 方法处理堆叠中断：

- 暂停当前效果
- 将当前效果添加到队列
- 激活新效果
- 记录中断事件

### 重启中断策略

系统内部使用 `_handle_restart_interruption` 方法处理重启中断：

- 停止当前效果
- 清除队列中的所有上下文
- 激活新效果
- 记录中断事件

### 忽略中断策略

系统内部使用 `_handle_ignore_interruption` 方法处理忽略中断：

- 停止新效果
- 保持当前效果继续执行
- 记录中断事件

### 平滑过渡策略

系统内部使用 `_handle_smooth_transition` 方法处理平滑过渡：

- 创建过渡上下文
- 设置过渡状态
- 开始过渡效果
- 记录中断事件

### 优先级覆盖策略

系统内部使用 `_handle_priority_override` 方法处理优先级覆盖：

- 比较新效果和现有效果的优先级
- 如果新效果优先级更高，则执行重启策略
- 否则执行忽略策略

### 淡出淡入策略

系统内部使用 `_handle_fade_transition` 方法处理淡出淡入：

- 创建淡出效果
- 创建淡入效果
- 设置过渡状态
- 开始淡出效果
- 记录中断事件

### 优先级堆叠策略

系统内部使用 `_handle_priority_stack` 方法处理优先级堆叠：

- 获取新效果的优先级
- 按优先级插入到队列中
- 限制队列大小
- 记录中断事件

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
manager.set_channel_config("ui_effects", config)
```

### `set_global_priority(resource_type: String, priority: int) -> void`

设置全局优先级。

**参数:**
- `resource_type` (String): 资源类型
- `priority` (int): 优先级

**示例:**
```gdscript
manager.set_global_priority("JuicyTweenResource", 10)
manager.set_global_priority("JuicyShakeResource", 5)
```

### `set_default_policy(policy: JuicyMixerEnms.InterruptionPolicy) -> void`

设置默认中断策略。

**参数:**
- `policy` (JuicyMixerEnms.InterruptionPolicy): 中断策略

**示例:**
```gdscript
manager.set_default_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
```

### `get_default_policy() -> JuicyMixerEnms.InterruptionPolicy`

获取默认中断策略。

**返回值:**
- `JuicyMixerEnms.InterruptionPolicy`: 中断策略

**示例:**
```gdscript
var policy = manager.get_default_policy()
print("默认策略: ", JuicyMixerEnms.get_interruption_policy_name(policy))
```

## 中断历史管理

### `replay_interruption_history(target_id: int, from_timestamp: float = 0.0) -> void`

回放中断历史，用于调试和恢复。

**参数:**
- `target_id` (int): 目标ID
- `from_timestamp` (float, 可选): 起始时间戳

**示例:**
```gdscript
# 回放所有历史
manager.replay_interruption_history(target_node.get_instance_id())

# 回放指定时间后的历史
manager.replay_interruption_history(target_node.get_instance_id(), Time.get_ticks_msec() / 1000.0 - 60.0)
```

## 过渡处理

### `process_transition(delta: float) -> void`

处理过渡进度，应在每帧调用。

**参数:**
- `delta` (float): 时间增量

**示例:**
```gdscript
func _process(delta):
    manager.process_transition(delta)
```

## 状态查询

### `get_interruption_state(target: Node) -> InterruptionState`

获取目标的中断状态。

**参数:**
- `target` (Node): 目标节点

**返回值:**
- `InterruptionState`: 中断状态，如果不存在则返回null

**示例:**
```gdscript
var state = manager.get_interruption_state(target_node)
if state:
    print("活跃上下文: ", state.get_active_context_count())
    print("队列上下文: ", state.get_queued_context_count())
```

### `clear_interruption_state(target: Node) -> void`

清除目标的中断状态。

**参数:**
- `target` (Node): 目标节点

**示例:**
```gdscript
manager.clear_interruption_state(target_node)
```

## 性能统计

### `get_performance_stats() -> Dictionary`

获取性能统计信息。

**返回值:**
- `Dictionary`: 性能统计字典，包含：
  - `interruption_count` (int): 中断次数
  - `total_interruption_time` (float): 总中断时间
  - `average_interruption_time` (float): 平均中断时间
  - `last_interruption_time` (float): 最后中断时间
  - `active_states` (int): 活跃状态数

**示例:**
```gdscript
var stats = manager.get_performance_stats()
print("中断次数: ", stats.interruption_count)
print("平均中断时间: ", stats.average_interruption_time, "ms")
print("活跃状态数: ", stats.active_states)
```

### `reset_performance_stats() -> void`

重置性能统计。

**示例:**
```gdscript
manager.reset_performance_stats()
```

## 使用示例

### 基本使用

```gdscript
# 创建中断管理器
var manager = JuicyInterruptionManager.new()

# 设置默认策略
manager.set_default_policy(JuicyMixerEnms.InterruptionPolicy.STACK)

# 设置通道配置
var ui_config = ChannelInterruptionConfig.new()
ui_config.channel_name = "ui_effects"
ui_config.set_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
ui_config.set_channel_priority(10)
manager.set_channel_config("ui_effects", ui_config)

# 设置全局优先级
manager.set_global_priority("JuicyTweenResource", 5)
manager.set_global_priority("JuicyShakeResource", 8)

# 处理中断
var success = manager.handle_interruption(
    "new_ui_effect",
    "existing_ui_effect", 
    JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE
)
```

### 高级配置

```gdscript
# 创建管理器
var manager = JuicyInterruptionManager.new()

# 配置多个通道
var combat_config = ChannelInterruptionConfig.new()
combat_config.channel_name = "combat_effects"
combat_config.set_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_STACK)
combat_config.set_channel_priority(15)
combat_config.set_max_queue_size(20)
combat_config.enable_feature("priority_queue", true)
manager.set_channel_config("combat_effects", combat_config)

var audio_config = ChannelInterruptionConfig.new()
audio_config.channel_name = "audio_effects"
audio_config.set_policy(JuicyMixerEnms.InterruptionPolicy.FADE_OUT_FADE_IN)
audio_config.set_transition_duration(0.3)
manager.set_channel_config("audio_effects", audio_config)

# 设置资源类型优先级
manager.set_global_priority("JuicyShakeResource", 10)
manager.set_global_priority("JuicyTweenResource", 5)
manager.set_global_priority("JuicySpringResource", 7)

# 在游戏循环中处理过渡
func _process(delta):
    manager.process_transition(delta)
```

### 状态监控

```gdscript
# 监控特定目标的中断状态
func monitor_target_interruptions(target: Node):
    var state = manager.get_interruption_state(target)
    if not state:
        print("目标没有中断状态")
        return
    
    print("=== 目标中断状态 ===")
    print("活跃上下文数量: ", state.get_active_context_count())
    print("队列上下文数量: ", state.get_queued_context_count())
    print("优先级队列数量: ", state.get_priority_queue_count())
    print("当前策略: ", JuicyMixerEnms.get_interruption_policy_name(state.current_policy))
    
    if state.is_transitioning():
        print("正在过渡，进度: ", state.transition_progress)
    
    # 显示历史记录
    var history = state.get_interruption_history()
    print("历史记录数量: ", history.size())

# 性能监控
func monitor_performance():
    var stats = manager.get_performance_stats()
    print("=== 性能统计 ===")
    print("总中断次数: ", stats.interruption_count)
    print("总中断时间: ", stats.total_interruption_time, "ms")
    print("平均中断时间: ", stats.average_interruption_time, "ms")
    print("最后中断时间: ", stats.last_interruption_time, "ms")
    print("活跃状态数: ", stats.active_states)
```

### 调试和故障排除

```gdscript
# 回放中断历史
func debug_interruption_history(target: Node):
    var state = manager.get_interruption_state(target)
    if not state:
        return
    
    print("=== 中断历史 ===")
    var history = state.get_interruption_history()
    for i in range(history.size()):
        var record = history[i]
        print("[%d] 时间: %.2f, 新上下文: %s, 现有上下文: %s, 策略: %s" % [
            i,
            record.timestamp,
            record.new_context,
            record.existing_context,
            JuicyMixerEnms.get_interruption_policy_name(record.policy)
        ])

# 重置状态和统计
func reset_all_states():
    # 清除所有目标的状态
    for target in get_tree().get_nodes_in_group("interruption_targets"):
        manager.clear_interruption_state(target)
    
    # 重置性能统计
    manager.reset_performance_stats()
    
    print("所有中断状态和统计已重置")
```

## 最佳实践

1. **策略选择**: 根据游戏类型选择合适的中断策略
   - UI效果: 使用PRIORITY_OVERRIDE确保重要反馈
   - 战斗效果: 使用PRIORITY_STACK按重要性排队
   - 音频效果: 使用FADE_OUT_FADE_IN避免突然中断

2. **性能优化**: 定期检查性能统计，优化中断处理时间

3. **状态管理**: 在适当时机清理中断状态，避免内存泄漏

4. **配置验证**: 应用配置前验证其有效性

## 注意事项

1. **上下文有效性**: 确保传入的上下文ID对应有效的上下文
2. **性能监控**: 定期检查性能统计，及时发现性能问题
3. **内存管理**: 长时间运行时注意清理历史记录和状态
4. **线程安全**: 此类不是线程安全的，应在主线程中使用

## 相关类

- [`InterruptionState`](InterruptionState.md) - 中断状态
- [`ChannelInterruptionConfig`](ChannelInterruptionConfig.md) - 通道中断配置
- [`InterruptionMiddleware`](InterruptionMiddleware.md) - 中断中间件
- [`JuicyMixerEnms.InterruptionPolicy`](JuicyMixerEnums.md) - 中断策略枚举