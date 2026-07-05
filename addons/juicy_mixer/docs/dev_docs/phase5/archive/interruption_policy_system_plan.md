# 中断策略系统开发计划

## 概述

本文档详细描述了JuicyMixer V3中中断策略系统的开发计划。该系统提供了多种智能中断策略，允许开发者精确控制效果之间的交互，实现平滑过渡、优先级管理和智能队列等功能。

## 系统架构

中断策略系统由以下核心组件构成：

- **JuicyInterruptionManager** - 中断管理器
- **InterruptionPolicy** - 中断策略枚举
- **InterruptionState** - 中断状态数据结构
- **InterruptionMiddleware** - 中断处理中间件

## 与现有系统的集成

### Director系统集成
- 中断管理器需要与Director的Context管理深度集成
- 中断策略需要考虑Director的执行顺序和优先级
- 中断过程需要维护Director的状态一致性

### Middleware系统协调
- 中断策略需要实现为专门的Middleware
- 中断决策需要通过Middleware管道执行
- 中断过程需要考虑其他Middleware的影响

### 序列化系统协同
- 序列化执行需要支持中断和恢复
- 中断过程需要正确处理序列化状态
- 序列化恢复需要考虑中断历史

### Context系统增强
- 中断策略需要Context级别的配置
- 中断过程需要维护Context的一致性

### 事件系统协同
- 中断过程需要生成中断、恢复事件
- 中断状态需要通过事件系统广播

## 开发时间线

**总体时间**：第13周（共1周）

## JuicyMixerEnums中添加中断策略枚举

**文件路径**：`addons/juicy_mixer/core/juicy_mixer_enums.gd`

**核心职责**：
- 定义中断策略相关的枚举
- 提供统一的枚举访问接口
- 确保枚举值的一致性

**详细实现计划**：

```gdscript
@tool
class_name JuicyMixerEnums
extends RefCounted

# 中断策略枚举
enum InterruptionPolicy {
    STACK,              # 堆叠：新效果加入队列
    RESTART,            # 重启：立即重启效果
    IGNORE,             # 忽略：忽略新效果
    SMOOTH_TRANSITION,   # 平滑过渡：平滑过渡到新效果
    PRIORITY_OVERRIDE,   # 优先级覆盖：高优先级覆盖低优先级
    FADE_OUT_FADE_IN,   # 淡出淡入：当前效果淡出，新效果淡入
    PRIORITY_STACK      # 优先级堆叠：按优先级插入队列
}
```

## InterruptionState (中断状态)

**文件路径**：`addons/juicy_mixer/core/interruption_state.gd`

**核心职责**：
- 存储中断状态数据
- 管理活跃和队列中的上下文
- 跟踪中断历史
- 处理优先级队列

**详细实现计划**：

```gdscript
@tool
class_name InterruptionState
extends RefCounted

# 状态数据
var target_id: int
var active_contexts: Array[String] = []
var queued_contexts: Array[String] = []
var current_policy: JuicyMixerEnums.InterruptionPolicy
var transition_context: String = ""
var transition_progress: float = 0.0
var interruption_history: Array[Dictionary] = []
var priority_queue: Array[Dictionary] = []  # 优先级队列：[{"context_id": String, "priority": int}]

func _init(target: Node = null):
    if target:
        target_id = target.get_instance_id()

func add_active_context(context_id: String) -> void:
    if context_id not in active_contexts:
        active_contexts.append(context_id)

func remove_active_context(context_id: String) -> void:
    active_contexts.erase(context_id)

func has_active_context(context_id: String) -> bool:
    return context_id in active_contexts

func get_active_context_count() -> int:
    return active_contexts.size()

func clear_active_contexts() -> void:
    active_contexts.clear()

func add_queued_context(context_id: String) -> void:
    if context_id not in queued_contexts:
        queued_contexts.append(context_id)

func remove_queued_context(context_id: String) -> void:
    queued_contexts.erase(context_id)

func has_queued_context(context_id: String) -> bool:
    return context_id in queued_contexts

func get_next_queued_context() -> String:
    if queued_contexts.size() > 0:
        return queued_contexts.front()
    return ""

func pop_next_queued_context() -> String:
    if queued_contexts.size() > 0:
        return queued_contexts.pop_front()
    return ""

func get_queued_context_count() -> int:
    return queued_contexts.size()

func clear_queued_contexts() -> void:
    queued_contexts.clear()

func add_priority_queue_item(context_id: String, priority: int) -> void:
    var queue_item = {
        "context_id": context_id,
        "priority": priority,
        "timestamp": Time.get_ticks_msec() / 1000.0
    }
    
    # 按优先级插入到正确位置
    var inserted = false
    for i in range(priority_queue.size()):
        if priority_queue[i].priority < priority:
            priority_queue.insert(i, queue_item)
            inserted = true
            break
    
    if not inserted:
        priority_queue.append(queue_item)

func get_next_priority_item() -> Dictionary:
    if priority_queue.size() > 0:
        return priority_queue.front()
    return {}

func pop_next_priority_item() -> Dictionary:
    if priority_queue.size() > 0:
        return priority_queue.pop_front()
    return {}

func get_priority_queue_count() -> int:
    return priority_queue.size()

func clear_priority_queue() -> void:
    priority_queue.clear()

func add_interruption_record(record: Dictionary) -> void:
    interruption_history.append(record)
    
    # 限制历史记录数量
    if interruption_history.size() > 100:
        interruption_history.pop_front()

func get_interruption_history() -> Array[Dictionary]:
    return interruption_history.duplicate()

func clear_interruption_history() -> void:
    interruption_history.clear()

func is_transitioning() -> bool:
    return not transition_context.is_empty()

func set_transition(context_id: String) -> void:
    transition_context = context_id
    transition_progress = 0.0

func clear_transition() -> void:
    transition_context = ""
    transition_progress = 0.0

func update_transition_progress(delta: float) -> void:
    if is_transitioning():
        transition_progress = min(transition_progress + delta, 1.0)

func is_transition_complete() -> bool:
    return transition_progress >= 1.0

func to_string() -> String:
    return "InterruptionState[target_id=%d, active=%d, queued=%d, policy=%d]" % [
        target_id, active_contexts.size(), queued_contexts.size(), current_policy
    ]
```

## ChannelInterruptionConfig (通道中断配置)

**文件路径**：`addons/juicy_mixer/resources/channel_interruption_config.gd`

**核心职责**：
- 配置通道级中断行为
- 管理中断策略参数
- 提供可编辑的配置选项
- 支持通道特定的优先级

**详细实现计划**：

```gdscript
@tool
class_name ChannelInterruptionConfig
extends Resource

# 通道配置
@export var channel_name: String = ""
@export var default_policy: JuicyMixerEnums.InterruptionPolicy = JuicyMixerEnums.InterruptionPolicy.STACK
@export var priority: int = 0
@export var max_queue_size: int = 10
@export var transition_duration: float = 0.2
@export var allow_preemption: bool = true  # 是否允许抢占

# 高级配置
@export var enable_priority_queue: bool = true
@export var enable_interruption_history: bool = true
@export var max_history_size: int = 100
@export var auto_cleanup_threshold: int = 50  # 队列大小超过此值时自动清理

func _init():
    # 设置默认值
    if channel_name.is_empty():
        channel_name = "default"

func set_policy(policy: JuicyMixerEnums.InterruptionPolicy) -> void:
    default_policy = policy

func get_policy() -> JuicyMixerEnums.InterruptionPolicy:
    return default_policy

func set_channel_priority(prio: int) -> void:
    priority = prio

func get_channel_priority() -> int:
    return priority

func set_max_queue_size(size: int) -> void:
    max_queue_size = max(size, 1)

func get_max_queue_size() -> int:
    return max_queue_size

func set_transition_duration(duration: float) -> void:
    transition_duration = max(duration, 0.0)

func get_transition_duration() -> float:
    return transition_duration

func set_preemption_allowed(allowed: bool) -> void:
    allow_preemption = allowed

func is_preemption_allowed() -> bool:
    return allow_preemption

func enable_feature(feature: String, enabled: bool) -> void:
    match feature:
        "priority_queue":
            enable_priority_queue = enabled
        "interruption_history":
            enable_interruption_history = enabled
        "auto_cleanup":
            auto_cleanup_threshold = 50 if enabled else 0

func is_feature_enabled(feature: String) -> bool:
    match feature:
        "priority_queue":
            return enable_priority_queue
        "interruption_history":
            return enable_interruption_history
        "auto_cleanup":
            return auto_cleanup_threshold > 0
    return false

func validate_config() -> Dictionary:
    var issues = []
    
    if channel_name.is_empty():
        issues.append("Channel name cannot be empty")
    
    if max_queue_size < 1:
        issues.append("Max queue size must be at least 1")
    
    if transition_duration < 0.0:
        issues.append("Transition duration cannot be negative")
    
    if max_history_size < 10:
        issues.append("Max history size should be at least 10")
    
    return {
        "valid": issues.is_empty(),
        "issues": issues
    }

func duplicate() -> ChannelInterruptionConfig:
    var new_config = ChannelInterruptionConfig.new()
    new_config.channel_name = channel_name
    new_config.default_policy = default_policy
    new_config.priority = priority
    new_config.max_queue_size = max_queue_size
    new_config.transition_duration = transition_duration
    new_config.allow_preemption = allow_preemption
    new_config.enable_priority_queue = enable_priority_queue
    new_config.enable_interruption_history = enable_interruption_history
    new_config.max_history_size = max_history_size
    new_config.auto_cleanup_threshold = auto_cleanup_threshold
    
    return new_config

func _to_string() -> String:
    return "ChannelInterruptionConfig[channel=%s, policy=%d, priority=%d]" % [
        channel_name, default_policy, priority
    ]
```

## JuicyInterruptionManager (中断管理器)

**文件路径**：`addons/juicy_mixer/core/juicy_interruption_manager.gd`

**核心职责**：
- 管理效果中断策略
- 处理多种中断模式
- 实现平滑过渡机制
- 提供中断状态监控

**详细实现计划**：

```gdscript
class_name JuicyInterruptionManager
extends RefCounted

# 中断配置
var _interruption_states: Dictionary = {}  # target_id -> InterruptionState
var _policy_configs: Dictionary = {}      # channel_name -> ChannelInterruptionConfig
var _default_policy: JuicyMixerEnums.InterruptionPolicy = JuicyMixerEnums.InterruptionPolicy.STACK
var _transition_resources: Dictionary = {} # transition_type -> Resource
var _global_priority_map: Dictionary = {}  # resource_type -> priority

func handle_interruption(new_context_id: String, existing_context_id: String,
                    policy: JuicyMixerEnums.InterruptionPolicy) -> bool:
    var new_context = JuicyMixer.get_context(new_context_id)
    var existing_context = JuicyMixer.get_context(existing_context_id)
    
    if not new_context or not existing_context:
        return false
    
    # 记录中断历史
    _record_interruption(new_context, existing_context, policy)
    
    match policy:
        JuicyMixerEnums.InterruptionPolicy.STACK:
            return _handle_stack_interruption(new_context, existing_context)
        JuicyMixerEnums.InterruptionPolicy.RESTART:
            return _handle_restart_interruption(new_context, existing_context)
        JuicyMixerEnums.InterruptionPolicy.IGNORE:
            return _handle_ignore_interruption(new_context, existing_context)
        JuicyMixerEnums.InterruptionPolicy.SMOOTH_TRANSITION:
            return _handle_smooth_transition(new_context, existing_context)
        JuicyMixerEnums.InterruptionPolicy.PRIORITY_OVERRIDE:
            return _handle_priority_override(new_context, existing_context)
        JuicyMixerEnums.InterruptionPolicy.FADE_OUT_FADE_IN:
            return _handle_fade_transition(new_context, existing_context)
    
    return false

func _handle_stack_interruption(new_context: JuicyContext,
                                existing_context: JuicyContext) -> bool:
    var target_id = existing_context.target.get_instance_id()
    var state = _get_or_create_state(target_id)
    
    # 暂停当前效果
    JuicyMixer.pause(existing_context.context_id)
    
    # 添加到队列
    state.queued_contexts.append(existing_context.context_id)
    state.active_contexts.append(new_context.context_id)
    state.current_policy = JuicyMixerEnums.InterruptionPolicy.STACK
    
    # 触发中断事件
    _emit_interruption_event("stack_interruption", new_context, existing_context)
    
    return true

func _handle_restart_interruption(new_context: JuicyContext,
                                  existing_context: JuicyContext) -> bool:
    var target_id = existing_context.target.get_instance_id()
    var state = _get_or_create_state(target_id)
    
    # 停止当前效果
    JuicyMixer.stop(existing_context.context_id)
    
    # 清除队列中的所有上下文
    state.queued_contexts.clear()
    state.active_contexts.clear()
    state.active_contexts.append(new_context.context_id)
    state.current_policy = JuicyMixerEnums.InterruptionPolicy.RESTART
    
    # 触发中断事件
    _emit_interruption_event("restart_interruption", new_context, existing_context)
    
    return true

func _handle_ignore_interruption(new_context: JuicyContext,
                                existing_context: JuicyContext) -> bool:
    # 停止新效果
    JuicyMixer.stop(new_context.context_id)
    
    # 触发中断事件
    _emit_interruption_event("ignore_interruption", new_context, existing_context)
    
    return true

func _handle_smooth_transition(new_context: JuicyContext,
                              existing_context: JuicyContext) -> bool:
    var target_id = existing_context.target.get_instance_id()
    var state = _get_or_create_state(target_id)
    
    # 创建过渡上下文
    var transition_context = _create_transition_context(
        existing_context, new_context, 0.2
    )
    
    state.transition_context = transition_context.context_id
    state.current_policy = JuicyMixerEnums.InterruptionPolicy.SMOOTH_TRANSITION
    
    # 开始过渡
    JuicyMixer.play(transition_context.resource, transition_context.target)
    
    # 触发中断事件
    _emit_interruption_event("smooth_transition", new_context, existing_context)
    
    return true

func _handle_priority_override(new_context: JuicyContext,
                               existing_context: JuicyContext) -> bool:
    # 比较优先级
    var new_priority = _get_context_priority(new_context)
    var existing_priority = _get_context_priority(existing_context)
    
    if new_priority <= existing_priority:
        # 新效果优先级不高，忽略
        return _handle_ignore_interruption(new_context, existing_context)
    
    # 高优先级覆盖低优先级
    return _handle_restart_interruption(new_context, existing_context)

func _handle_priority_stack(new_context: JuicyContext,
                          existing_context: JuicyContext) -> bool:
    var target_id = existing_context.target.get_instance_id()
    var state = _get_or_create_state(target_id)
    
    # 获取新上下文的优先级
    var new_priority = _get_context_priority(new_context)
    
    # 按优先级插入到队列中
    var queue_item = {
        "context_id": new_context.context_id,
        "priority": new_priority,
        "timestamp": Time.get_ticks_msec() / 1000.0
    }
    
    # 插入到优先级队列的正确位置
    var inserted = false
    for i in range(state.priority_queue.size()):
        if state.priority_queue[i].priority < new_priority:
            state.priority_queue.insert(i, queue_item)
            inserted = true
            break
    
    if not inserted:
        state.priority_queue.append(queue_item)
    
    # 限制队列大小
    var channel_config = _get_channel_config(new_context.resource.channel)
    var max_queue_size = channel_config.max_queue_size if channel_config else 10
    while state.priority_queue.size() > max_queue_size:
        state.priority_queue.pop_back()
    
    state.current_policy = JuicyMixerEnums.InterruptionPolicy.PRIORITY_STACK
    
    # 触发中断事件
    _emit_interruption_event("priority_stack_interruption", new_context, existing_context)
    
    return true

func _handle_fade_transition(new_context: JuicyContext,
                            existing_context: JuicyContext) -> bool:
    var target_id = existing_context.target.get_instance_id()
    var state = _get_or_create_state(target_id)
    
    # 创建淡出效果
    var fade_out_context = _create_fade_context(existing_context, 0.2, false)
    
    # 创建淡入效果
    var fade_in_context = _create_fade_context(new_context, 0.2, true)
    
    # 设置过渡状态
    state.transition_context = fade_out_context.context_id
    state.queued_contexts.append(fade_in_context.context_id)
    state.current_policy = JuicyMixerEnums.InterruptionPolicy.FADE_OUT_FADE_IN
    
    # 开始淡出
    JuicyMixer.play(fade_out_context.resource, fade_out_context.target)
    
    # 触发中断事件
    _emit_interruption_event("fade_transition", new_context, existing_context)
    
    return true

func _get_or_create_state(target_id: int) -> InterruptionState:
    if not _interruption_states.has(target_id):
        _interruption_states[target_id] = InterruptionState.new()
        _interruption_states[target_id].target_id = target_id
    return _interruption_states[target_id]

func _create_transition_context(existing_context: JuicyContext, 
                               new_context: JuicyContext, 
                               duration: float) -> JuicyContext:
    # 创建过渡资源
    var transition_resource = _create_blend_transition_resource(
        existing_context.resource, new_context.resource, duration
    )
    
    # 创建过渡上下文
    var transition_context = JuicyContext.create(
        transition_resource, existing_context.target, existing_context.owner
    )
    
    return transition_context

func _create_fade_context(context: JuicyContext, duration: float, fade_in: bool) -> JuicyContext:
    # 创建淡入淡出资源
    var fade_resource = _create_fade_resource(context.resource, duration, fade_in)
    
    # 创建淡入淡出上下文
    var fade_context = JuicyContext.create(
        fade_resource, context.target, context.owner
    )
    
    return fade_context

func _create_blend_transition_resource(from_resource: JuicyFeedbackResource, 
                                     to_resource: JuicyFeedbackResource, 
                                     duration: float) -> JuicyFeedbackResource:
    # 实现混合过渡资源创建逻辑
    # 这里应该创建一个特殊的过渡资源，能够平滑地从from_resource过渡到to_resource
    pass

func _create_fade_resource(resource: JuicyFeedbackResource, duration: float, fade_in: bool) -> JuicyFeedbackResource:
    # 实现淡入淡出资源创建逻辑
    # 这里应该创建一个特殊的淡入淡出资源
    pass

func _get_context_priority(context: JuicyContext) -> int:
    # 从上下文或资源中获取优先级
    if context.resource.has_method("get_priority"):
        return context.resource.get_priority()
    
    # 从全局优先级映射中获取
    var resource_type = context.resource.get_script().get_global_name()
    if _global_priority_map.has(resource_type):
        return _global_priority_map[resource_type]
    
    # 从通道配置中获取
    var channel_config = _get_channel_config(context.resource.channel)
    if channel_config:
        return channel_config.priority
    
    return 0

func _get_channel_config(channel: String) -> ChannelInterruptionConfig:
    return _policy_configs.get(channel, null)

func set_channel_config(channel: String, config: ChannelInterruptionConfig) -> void:
    _policy_configs[channel] = config

func set_global_priority(resource_type: String, priority: int) -> void:
    _global_priority_map[resource_type] = priority

func replay_interruption_history(target_id: int, from_timestamp: float = 0.0) -> void:
    # 回放中断历史，用于调试和恢复
    var state = _interruption_states.get(target_id)
    if not state:
        return
    
    for record in state.interruption_history:
        if record.timestamp >= from_timestamp:
            # 重新执行中断记录
            var new_context = JuicyMixer.get_context(record.new_context)
            var existing_context = JuicyMixer.get_context(record.existing_context)
            
            if new_context and existing_context:
                handle_interruption(record.new_context, record.existing_context, record.policy)

func _record_interruption(new_context: JuicyContext, existing_context: JuicyContext, policy: InterruptionPolicy) -> void:
    var record = {
        "timestamp": Time.get_ticks_msec() / 1000.0,
        "new_context": new_context.context_id,
        "existing_context": existing_context.context_id,
        "policy": policy,
        "target_id": existing_context.target.get_instance_id()
    }
    
    var target_id = existing_context.target.get_instance_id()
    var state = _get_or_create_state(target_id)
    state.interruption_history.append(record)
    
    # 限制历史记录数量
    if state.interruption_history.size() > 100:
        state.interruption_history.pop_front()

func _emit_interruption_event(event_type: String, new_context: JuicyContext, existing_context: JuicyContext) -> void:
    var event_data = {
        "type": event_type,
        "new_context": new_context.context_id,
        "existing_context": existing_context.context_id,
        "target": existing_context.target,
        "timestamp": Time.get_ticks_msec() / 1000.0
    }
    
    # 通过事件系统发送中断事件
    JuicyEventBus.emit_signal("interruption_occurred", event_data)

func process_transition(delta: float) -> void:
    for target_id in _interruption_states.keys():
        var state = _interruption_states[target_id]
        if not state.transition_context.is_empty():
            state.transition_progress = min(state.transition_progress + delta, 1.0)
            
            # 检查过渡是否完成
            if state.transition_progress >= 1.0:
                _complete_transition(target_id, state)

func _complete_transition(target_id: int, state: InterruptionState) -> void:
    # 处理过渡完成逻辑
    match state.current_policy:
        JuicyMixerEnums.InterruptionPolicy.SMOOTH_TRANSITION:
            # 平滑过渡完成，激活新效果
            _activate_next_in_queue(target_id, state)
        JuicyMixerEnums.InterruptionPolicy.FADE_OUT_FADE_IN:
            # 淡出完成，开始淡入
            if state.queued_contexts.size() > 0:
                var fade_in_context_id = state.queued_contexts.pop_front()
                JuicyMixer.play(JuicyMixer.get_context(fade_in_context_id).resource, 
                               JuicyMixer.get_context(fade_in_context_id).target)
    
    state.transition_context = ""
    state.transition_progress = 0.0

func _activate_next_in_queue(target_id: int, state: InterruptionState) -> void:
    if state.queued_contexts.size() > 0:
        var next_context_id = state.queued_contexts.pop_front()
        JuicyMixer.resume(next_context_id)

func get_interruption_state(target: Node) -> InterruptionState:
    var target_id = target.get_instance_id()
    return _interruption_states.get(target_id, null)

func clear_interruption_state(target: Node) -> void:
    var target_id = target.get_instance_id()
    _interruption_states.erase(target_id)

func set_default_policy(policy: JuicyMixerEnums.InterruptionPolicy) -> void:
    _default_policy = policy

func get_default_policy() -> JuicyMixerEnums.InterruptionPolicy:
    return _default_policy
```

**开发任务分解**：
- [ ] 第13周第1天：中断策略定义和状态管理（增加优先级队列）
- [ ] 第13周第2天：堆叠和重启策略实现（增加优先级堆叠）
- [ ] 第13周第3天：平滑过渡和优先级覆盖（优化过渡算法）
- [ ] 第13周第4天：淡出淡入策略和通道级配置
- [ ] 第13周第5天：中断历史记录和回放功能
- [ ] 第13周第5天：中断监控、调试和单元测试

## InterruptionMiddleware (中断中间件)

**文件路径**：`addons/juicy_mixer/middleware/interruption_middleware.gd`

**核心职责**：
- 在Director执行流程中处理中断
- 协调不同中断策略的执行
- 提供中断决策的钩子函数

**详细实现计划**：

```gdscript
class_name InterruptionMiddleware
extends JuicyMiddleware

var _interruption_manager: JuicyInterruptionManager

func _init():
    middleware_name = "InterruptionMiddleware"
    priority = 100  # 高优先级，确保中断处理优先执行

func setup(director: JuicyDirector) -> void:
    super.setup(director)
    _interruption_manager = JuicyInterruptionManager.new()

func before_play(context: JuicyContext) -> bool:
    # 检查是否需要中断现有效果
    var existing_contexts = _get_active_contexts_for_target(context.target)
    
    for existing_context_id in existing_contexts:
        var existing_context = JuicyMixer.get_context(existing_context_id)
        if not existing_context:
            continue
        
        # 确定中断策略
        var policy = _determine_interruption_policy(context, existing_context)
        
        # 处理中断
        if not _interruption_manager.handle_interruption(
            context.context_id, existing_context_id, policy
        ):
            # 中断处理失败，拒绝播放
            return false
    
    return true

func _get_active_contexts_for_target(target: Node) -> Array[String]:
    var active_contexts: Array[String] = []
    
    # 从Director获取目标的所有活跃上下文
    for context_id in _director.active_contexts:
        var context = JuicyMixer.get_context(context_id)
        if context and context.target == target:
            active_contexts.append(context_id)
    
    return active_contexts

func _determine_interruption_policy(new_context: JuicyContext,
                                   existing_context: JuicyContext) -> JuicyMixerEnums.InterruptionPolicy:
    # 从资源获取中断策略
    if new_context.resource.has_method("get_interruption_policy"):
        return new_context.resource.get_interruption_policy()
    
    # 从通道获取中断策略
    var channel_policy = _get_channel_policy(new_context.resource.channel)
    if channel_policy != null:
        return channel_policy
    
    # 使用默认策略
    return _interruption_manager.get_default_policy()

func _get_channel_policy(channel: String) -> JuicyMixerEnums.InterruptionPolicy:
    # 实现通道策略获取逻辑
    return _interruption_manager._policy_configs.get(channel, null)

func process(delta: float) -> void:
    # 处理过渡进度
    _interruption_manager.process_transition(delta)

func cleanup() -> void:
    # 清理中断状态
    _interruption_manager = null
```

**开发任务分解**：
- [ ] 第13周第3天：中间件基础实现
- [ ] 第13周第4天：中断决策逻辑
- [ ] 第13周第5天：与Director集成
- [ ] 第13周第5天：单元测试

## 性能优化

### 执行效率
- 中断策略需要快速响应
- 中断过程需要最小化性能影响

### 内存管理
- 中断状态需要高效的存储机制
- 历史记录需要限制大小

## 测试计划

### 单元测试
- JuicyInterruptionManager状态管理测试
- 各种中断策略实现测试（包括PRIORITY_STACK）
- 优先级队列功能测试
- 通道级配置测试
- 中断历史记录和回放测试
- InterruptionMiddleware集成测试

### 集成测试
- 与Director系统集成测试
- 与序列化系统集成测试
- 与事件系统集成测试

### 性能测试
- 1000次中断处理性能测试
- 中断策略响应时间测试（按策略分类）
- 优先级队列操作性能测试
- 中断历史回放性能测试
- 内存使用优化验证

## 交付检查清单

### 代码交付
- [ ] JuicyInterruptionManager中断管理系统
- [ ] InterruptionMiddleware中断中间件
- [ ] 单元测试和集成测试
- [ ] 性能基准测试

### 文档交付
- [ ] 中断策略系统使用文档
- [ ] API参考文档
- [ ] 性能优化指南

### 验收标准
- [ ] 所有单元测试通过（覆盖率100%）
- [ ] 所有集成测试通过
- [ ] 性能基准测试达标
- [ ] 代码审查通过
- [ ] 文档完整准确

## 风险管控

### 技术风险
1. **中断复杂性**：复杂的中断逻辑可能导致状态不一致
   - 缓解措施：实现全面的状态验证和恢复机制

2. **过渡效果性能**：平滑过渡可能影响性能
   - 缓解措施：实现过渡效果的优化和缓存

### 进度风险
1. **策略实现复杂性**：多种中断策略实现可能比预期复杂
   - 缓解措施：优先实现核心策略，后续扩展

## 总结

中断策略系统是JuicyMixer V3的关键特性之一，它提供了智能的效果管理能力。通过多种中断策略，开发者可以精确控制效果之间的交互，实现平滑过渡和优先级管理。

**关键成就**：
- 实现了灵活的中断策略系统
- 提供了平滑过渡机制
- 确保了高效的中断处理
- 提供了完善的状态管理

中断策略系统将为JuicyMixer V3用户提供前所未有的效果控制能力，使复杂效果的管理变得简单直观。