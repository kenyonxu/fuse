# 高级中断配置示例

## 概述

本文档提供了JuicyMixer中断策略系统的高级配置示例，展示如何在实际游戏项目中实现复杂的中断逻辑和效果管理。

## 多通道优先级系统

### 游戏状态感知的中断配置

```gdscript
class_name GameInterruptionManager
extends Node

# 游戏状态枚举
enum GameState {
    MENU,
    PLAYING,
    COMBAT,
    DIALOGUE,
    CINEMATIC,
    PAUSED
}

var current_state: GameState = GameState.MENU
var interruption_configs: Dictionary = {}

func _ready():
    _setup_interruption_configs()
    _setup_state_transitions()

func _setup_interruption_configs():
    # 菜单状态配置
    var menu_config = ChannelInterruptionConfig.new()
    menu_config.channel_name = "menu_effects"
    menu_config.set_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
    menu_config.set_channel_priority(5)
    menu_config.set_max_queue_size(3)
    menu_config.set_transition_duration(0.2)
    interruption_configs[GameState.MENU] = menu_config
    
    # 游戏状态配置
    var play_config = ChannelInterruptionConfig.new()
    play_config.channel_name = "game_effects"
    play_config.set_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_STACK)
    play_config.set_channel_priority(10)
    play_config.set_max_queue_size(10)
    play_config.enable_feature("priority_queue", true)
    play_config.enable_feature("interruption_history", true)
    interruption_configs[GameState.PLAYING] = play_config
    
    # 战斗状态配置
    var combat_config = ChannelInterruptionConfig.new()
    combat_config.channel_name = "combat_effects"
    combat_config.set_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
    combat_config.set_channel_priority(20)
    combat_config.set_max_queue_size(15)
    combat_config.set_transition_duration(0.1)
    combat_config.enable_feature("auto_cleanup", true)
    combat_config.auto_cleanup_threshold = 8
    interruption_configs[GameState.COMBAT] = combat_config
    
    # 对话状态配置
    var dialogue_config = ChannelInterruptionConfig.new()
    dialogue_config.channel_name = "dialogue_effects"
    dialogue_config.set_policy(JuicyMixerEnms.InterruptionPolicy.IGNORE)
    dialogue_config.set_channel_priority(15)
    dialogue_config.allow_preemption = false
    interruption_configs[GameState.DIALOGUE] = dialogue_config
    
    # 电影模式配置
    var cinematic_config = ChannelInterruptionConfig.new()
    cinematic_config.channel_name = "cinematic_effects"
    cinematic_config.set_policy(JuicyMixerEnms.InterruptionPolicy.SMOOTH_TRANSITION)
    cinematic_config.set_channel_priority(25)
    cinematic_config.set_transition_duration(0.5)
    interruption_configs[GameState.CINEMATIC] = cinematic_config

func change_game_state(new_state: GameState):
    current_state = new_state
    
    # 应用对应状态的配置
    var config = interruption_configs[new_state]
    if config:
        JuicyMixer.set_channel_interruption_config("active_effects", config)
        print("切换到游戏状态: ", new_state, ", 应用中断配置: ", config.channel_name)
```

### 动态优先级调整

```gdscript
# 根据游戏情境动态调整优先级
func adjust_priorities_based_on_context(context: Dictionary):
    var health_percentage = context.get("health_percentage", 100)
    var is_critical = context.get("is_critical", false)
    var is_boss_fight = context.get("is_boss_fight", false)
    
    # 基础优先级映射
    var base_priorities = {
        "ui_effects": 10,
        "combat_effects": 15,
        "audio_effects": 5,
        "ambient_effects": 3,
        "player_effects": 20
    }
    
    # 根据情境调整优先级
    if health_percentage < 30:
        # 低血量时提高玩家效果优先级
        base_priorities.player_effects = 30
        base_priorities.ui_effects = 15  # 提高UI反馈优先级
    
    if is_critical:
        # 关键时刻提高所有效果优先级
        for key in base_priorities:
            base_priorities[key] += 10
    
    if is_boss_fight:
        # Boss战时提高战斗效果优先级
        base_priorities.combat_effects = 25
        base_priorities.player_effects = 25
        base_priorities.ambient_effects = 1  # 降低环境效果优先级
    
    # 应用调整后的优先级
    for channel in base_priorities:
        var config = JuicyMixer.get_channel_interruption_config(channel)
        if config:
            config.set_channel_priority(base_priorities[channel])
            JuicyMixer.set_channel_interruption_config(channel, config)
```

## 复杂中断策略组合

### 分层中断系统

```gdscript
class_name LayeredInterruptionSystem
extends Node

# 效果层级
enum EffectLayer {
    CRITICAL,    # 关键效果（不可中断）
    HIGH,        # 高优先级效果
    MEDIUM,       # 中等优先级效果
    LOW,          # 低优先级效果
    BACKGROUND    # 背景效果
}

var layer_configs: Dictionary = {}

func _ready():
    _setup_layer_system()

func _setup_layer_system():
    # 关键层级配置
    var critical_config = ChannelInterruptionConfig.new()
    critical_config.channel_name = "critical_effects"
    critical_config.set_policy(JuicyMixerEnms.InterruptionPolicy.IGNORE)
    critical_config.set_channel_priority(100)
    critical_config.allow_preemption = false
    layer_configs[EffectLayer.CRITICAL] = critical_config
    
    # 高优先级层级配置
    var high_config = ChannelInterruptionConfig.new()
    high_config.channel_name = "high_priority_effects"
    high_config.set_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
    high_config.set_channel_priority(75)
    high_config.set_max_queue_size(5)
    layer_configs[EffectLayer.HIGH] = high_config
    
    # 中等优先级层级配置
    var medium_config = ChannelInterruptionConfig.new()
    medium_config.channel_name = "medium_priority_effects"
    medium_config.set_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_STACK)
    medium_config.set_channel_priority(50)
    medium_config.set_max_queue_size(8)
    layer_configs[EffectLayer.MEDIUM] = medium_config
    
    # 低优先级层级配置
    var low_config = ChannelInterruptionConfig.new()
    low_config.channel_name = "low_priority_effects"
    low_config.set_policy(JuicyMixerEnms.InterruptionPolicy.STACK)
    low_config.set_channel_priority(25)
    low_config.set_max_queue_size(10)
    layer_configs[EffectLayer.LOW] = low_config
    
    # 背景层级配置
    var background_config = ChannelInterruptionConfig.new()
    background_config.channel_name = "background_effects"
    background_config.set_policy(JuicyMixerEnms.InterruptionPolicy.FADE_OUT_FADE_IN)
    background_config.set_channel_priority(10)
    background_config.set_transition_duration(0.8)
    layer_configs[EffectLayer.BACKGROUND] = background_config
    
    # 应用所有层级配置
    for layer in layer_configs:
        var config = layer_configs[layer]
        JuicyMixer.set_channel_interruption_config(config.channel_name, config)

func play_layered_effect(effect_resource: Resource, target: Node, layer: EffectLayer):
    # 根据层级设置效果属性
    var config = layer_configs[layer]
    effect_resource.channel = config.channel_name
    
    # 设置层级特定的中断属性
    match layer:
        EffectLayer.CRITICAL:
            effect_resource.allow_interruption = false
            effect_resource.can_interrupt_others = true
            effect_resource.set_interruption_priority(100)
        
        EffectLayer.HIGH:
            effect_resource.allow_interruption = true
            effect_resource.can_interrupt_others = true
            effect_resource.set_interruption_priority(75)
        
        EffectLayer.MEDIUM:
            effect_resource.allow_interruption = true
            effect_resource.can_interrupt_others = false
            effect_resource.set_interruption_priority(50)
        
        EffectLayer.LOW:
            effect_resource.allow_interruption = true
            effect_resource.can_interrupt_others = false
            effect_resource.set_interruption_priority(25)
        
        EffectLayer.BACKGROUND:
            effect_resource.allow_interruption = true
            effect_resource.can_interrupt_others = false
            effect_resource.set_interruption_priority(10)
            effect_resource.interruption_fade_duration = 0.5
    
    # 播放效果
    return JuicyMixer.play(effect_resource, target)
```

### 条件中断系统

```gdscript
class_name ConditionalInterruptionSystem
extends Node

# 中断条件
enum InterruptionCondition {
    ALWAYS,           # 总是允许
    NEVER,            # 从不允许
    HEALTH_BASED,     # 基于血量
    STAMINA_BASED,    # 基于体力
    COMBAT_STATE,      # 基于战斗状态
    PROXIMITY_BASED,  # 基于距离
    TIME_BASED        # 基于时间
}

var condition_handlers: Dictionary = {}

func _ready():
    _setup_condition_handlers()

func _setup_condition_handlers():
    condition_handlers[InterruptionCondition.ALWAYS] = _always_allow
    condition_handlers[InterruptionCondition.NEVER] = _never_allow
    condition_handlers[InterruptionCondition.HEALTH_BASED] = _health_based_check
    condition_handlers[InterruptionCondition.STAMINA_BASED] = _stamina_based_check
    condition_handlers[InterruptionCondition.COMBAT_STATE] = _combat_state_check
    condition_handlers[InterruptionCondition.PROXIMITY_BASED] = _proximity_based_check
    condition_handlers[InterruptionCondition.TIME_BASED] = _time_based_check

func create_conditional_effect(base_resource: Resource, condition: InterruptionCondition, condition_data: Dictionary = {}) -> Resource:
    # 创建条件效果的副本
    var conditional_resource = base_resource.duplicate()
    
    # 设置条件中断策略
    conditional_resource.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.CUSTOM)
    
    # 存储条件和数据
    conditional_resource.set_meta("interruption_condition", condition)
    conditional_resource.set_meta("condition_data", condition_data)
    
    return conditional_resource

func check_interruption_allowed(effect_resource: Resource, new_effect: Resource) -> bool:
    var condition = effect_resource.get_meta("interruption_condition", InterruptionCondition.ALWAYS)
    var condition_data = effect_resource.get_meta("condition_data", {})
    var handler = condition_handlers.get(condition, _always_allow)
    
    return handler.call(effect_resource, new_effect, condition_data)

# 条件处理函数
func _always_allow(_old_effect: Resource, _new_effect: Resource, _data: Dictionary) -> bool:
    return true

func _never_allow(_old_effect: Resource, _new_effect: Resource, _data: Dictionary) -> bool:
    return false

func _health_based_check(_old_effect: Resource, _new_effect: Resource, data: Dictionary) -> bool:
    var min_health = data.get("min_health", 0)
    var max_health = data.get("max_health", 100)
    var current_health = GameManager.player_health
    
    return current_health >= min_health and current_health <= max_health

func _stamina_based_check(_old_effect: Resource, _new_effect: Resource, data: Dictionary) -> bool:
    var min_stamina = data.get("min_stamina", 0)
    var current_stamina = GameManager.player_stamina
    
    return current_stamina >= min_stamina

func _combat_state_check(_old_effect: Resource, _new_effect: Resource, data: Dictionary) -> bool:
    var required_state = data.get("combat_state", "any")
    var current_state = GameManager.combat_state
    
    if required_state == "any":
        return true
    
    return current_state == required_state

func _proximity_based_check(_old_effect: Resource, _new_effect: Resource, data: Dictionary) -> bool:
    var max_distance = data.get("max_distance", 100)
    var target_position = data.get("target_position", Vector2.ZERO)
    var player_position = GameManager.player.global_position
    
    var distance = player_position.distance_to(target_position)
    return distance <= max_distance

func _time_based_check(_old_effect: Resource, _new_effect: Resource, data: Dictionary) -> bool:
    var start_time = data.get("start_time", 0)
    var end_time = data.get("end_time", 24)
    var current_time = Time.get_datetime_dict_from_system().hour
    
    return current_time >= start_time and current_time <= end_time
```

## 高级效果管理

### 效果组合系统

```gdscript
class_name EffectCombinationSystem
extends Node

# 效果组合类型
enum CombinationType {
    SEQUENTIAL,       # 顺序执行
    PARALLEL,         # 并行执行
    OVERLAY,          # 叠加执行
    TRANSITIONAL      # 过渡执行
}

class EffectCombination:
    var name: String
    var type: CombinationType
    var effects: Array[Resource] = []
    var delays: Array[float] = []
    var conditions: Array[Callable] = []
    var on_complete: Callable
    
    func _init(n: String, t: CombinationType):
        name = n
        type = t

var active_combinations: Dictionary = {}

func create_combination(name: String, type: CombinationType) -> EffectCombination:
    var combination = EffectCombination.new(name, type)
    active_combinations[name] = combination
    return combination

func add_effect_to_combination(combination_name: String, effect: Resource, delay: float = 0.0):
    var combination = active_combinations.get(combination_name)
    if combination:
        combination.effects.append(effect)
        combination.delays.append(delay)

func add_condition_to_combination(combination_name: String, condition: Callable):
    var combination = active_combinations.get(combination_name)
    if combination:
        combination.conditions.append(condition)

func set_combination_complete_callback(combination_name: String, callback: Callable):
    var combination = active_combinations.get(combination_name)
    if combination:
        combination.on_complete = callback

func play_combination(combination_name: String, target: Node) -> String:
    var combination = active_combinations.get(combination_name)
    if not combination or combination.effects.is_empty():
        return ""
    
    # 检查所有条件
    for condition in combination.conditions:
        if not condition.call():
            print("组合效果条件不满足: ", combination_name)
            return ""
    
    # 根据类型播放组合
    match combination.type:
        CombinationType.SEQUENTIAL:
            return _play_sequential_combination(combination, target)
        CombinationType.PARALLEL:
            return _play_parallel_combination(combination, target)
        CombinationType.OVERLAY:
            return _play_overlay_combination(combination, target)
        CombinationType.TRANSITIONAL:
            return _play_transitional_combination(combination, target)
    
    return ""

func _play_sequential_combination(combination: EffectCombination, target: Node) -> String:
    var context_ids = []
    
    for i in range(combination.effects.size()):
        var effect = combination.effects[i]
        var delay = combination.delays[i]
        
        if delay > 0:
            await get_tree().create_timer(delay).timeout
        
        var context_id = JuicyMixer.play(effect, target)
        context_ids.append(context_id)
    
    # 设置完成回调
    if combination.on_complete.is_valid():
        _wait_for_combination_complete(context_ids, combination.on_complete)
    
    return context_ids[0] if context_ids.size() > 0 else ""

func _play_parallel_combination(combination: EffectCombination, target: Node) -> String:
    var context_ids = []
    
    for i in range(combination.effects.size()):
        var effect = combination.effects[i]
        var delay = combination.delays[i]
        
        if delay > 0:
            await get_tree().create_timer(delay).timeout
        
        var context_id = JuicyMixer.play(effect, target)
        context_ids.append(context_id)
    
    # 设置完成回调
    if combination.on_complete.is_valid():
        _wait_for_combination_complete(context_ids, combination.on_complete)
    
    return context_ids[0] if context_ids.size() > 0 else ""

func _play_overlay_combination(combination: EffectCombination, target: Node) -> String:
    var main_context_id = ""
    
    for i in range(combination.effects.size()):
        var effect = combination.effects[i]
        var delay = combination.delays[i]
        
        if delay > 0:
            await get_tree().create_timer(delay).timeout
        
        # 设置叠加策略
        effect.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.STACK)
        
        var context_id = JuicyMixer.play(effect, target)
        if i == 0:
            main_context_id = context_id
    
    return main_context_id

func _play_transitional_combination(combination: EffectCombination, target: Node) -> String:
    var main_context_id = ""
    
    for i in range(combination.effects.size()):
        var effect = combination.effects[i]
        var delay = combination.delays[i]
        
        if delay > 0:
            await get_tree().create_timer(delay).timeout
        
        # 设置过渡策略
        effect.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.SMOOTH_TRANSITION)
        effect.interruption_fade_duration = 0.3
        
        var context_id = JuicyMixer.play(effect, target)
        if i == 0:
            main_context_id = context_id
        
        # 等待效果完成再播放下一个
        if i < combination.effects.size() - 1:
            await get_tree().create_timer(effect.duration).timeout
    
    return main_context_id

func _wait_for_combination_complete(context_ids: Array[String], callback: Callable):
    var completed_count = 0
    
    for context_id in context_ids:
        # 这里需要监听效果完成事件
        # 实际实现中需要连接到JuicyMixer的完成信号
        pass
    
    # 当所有效果完成时调用回调
    if completed_count == context_ids.size():
        callback.call()
```

### 自适应中断系统

```gdscript
class_name AdaptiveInterruptionSystem
extends Node

var performance_metrics: Dictionary = {}
var adaptation_rules: Array[Dictionary] = []

func _ready():
    _setup_adaptation_rules()
    _start_performance_monitoring()

func _setup_adaptation_rules():
    # 基于性能的自适应规则
    adaptation_rules.append({
        "name": "high_framerate_optimization",
        "condition": func(): return Engine.get_frames_per_second() > 55,
        "action": _optimize_for_high_framerate
    })
    
    adaptation_rules.append({
        "name": "low_framerate_optimization",
        "condition": func(): return Engine.get_frames_per_second() < 30,
        "action": _optimize_for_low_framerate
    })
    
    adaptation_rules.append({
        "name": "high_intensity_optimization",
        "condition": func(): return _get_active_effects_count() > 10,
        "action": _optimize_for_high_intensity
    })
    
    adaptation_rules.append({
        "name": "memory_pressure_optimization",
        "condition": func(): return OS.get_static_memory_usage_by_type()[OS.MEMORY_TYPE_VIDEO] > 0.8,
        "action": _optimize_for_memory_pressure
    })

func _start_performance_monitoring():
    # 定期检查性能并应用自适应规则
    var timer = Timer.new()
    timer.wait_time = 1.0  # 每秒检查一次
    timer.timeout.connect(_check_and_adapt)
    add_child(timer)
    timer.start()

func _check_and_adapt():
    for rule in adaptation_rules:
        if rule.condition.call():
            rule.action.call()

func _optimize_for_high_framerate():
    # 高帧率优化：减少过渡时间，增加队列大小
    print("应用高帧率优化")
    _adjust_all_channels({
        "transition_duration": 0.1,
        "max_queue_size": 15
    })

func _optimize_for_low_framerate():
    # 低帧率优化：增加过渡时间，减少队列大小
    print("应用低帧率优化")
    _adjust_all_channels({
        "transition_duration": 0.3,
        "max_queue_size": 5
    })

func _optimize_for_high_intensity():
    # 高强度优化：限制效果数量，提高优先级阈值
    print("应用高强度优化")
    _adjust_all_channels({
        "max_queue_size": 3,
        "priority_threshold": 15
    })

func _optimize_for_memory_pressure():
    # 内存压力优化：禁用历史记录，减少队列大小
    print("应用内存压力优化")
    _adjust_all_channels({
        "max_queue_size": 2,
        "enable_interruption_history": false,
        "auto_cleanup_threshold": 1
    })

func _adjust_all_channels(adjustments: Dictionary):
    var stats = JuicyMixer.get_interruption_stats()
    
    # 应用调整到所有通道
    for channel_name in stats.get("channels", {}):
        var config = JuicyMixer.get_channel_interruption_config(channel_name)
        if config:
            for key in adjustments:
                if config.has_method("set_" + key):
                    config.call("set_" + key, adjustments[key])
            
            JuicyMixer.set_channel_interruption_config(channel_name, config)

func _get_active_effects_count() -> int:
    var stats = JuicyMixer.get_interruption_stats()
    return stats.get("active_effects", 0)
```

## 实际应用场景

### RPG战斗系统

```gdscript
class_name CombatInterruptionSystem
extends LayeredInterruptionSystem

func _ready():
    super._ready()
    _setup_combat_effects()

func _setup_combat_effects():
    # 设置战斗相关的效果组合
    
    # 攻击组合
    var attack_combo = create_combination("sword_attack", CombinationType.SEQUENTIAL)
    add_effect_to_combination("sword_attack", create_swing_effect(), 0.0)
    add_effect_to_combination("sword_attack", create_hit_effect(), 0.3)
    add_effect_to_combination("sword_attack", create_impact_effect(), 0.1)
    set_combination_complete_callback("sword_attack", _on_attack_complete)
    
    # 魔法组合
    var magic_combo = create_combination("fire_spell", CombinationType.TRANSITIONAL)
    add_effect_to_combination("fire_spell", create_cast_effect(), 0.0)
    add_effect_to_combination("fire_spell", create_projectile_effect(), 0.2)
    add_effect_to_combination("fire_spell", create_explosion_effect(), 0.5)
    set_combination_complete_callback("fire_spell", _on_spell_complete)

func create_swing_effect() -> Resource:
    var effect = JuicyTweenResource.new()
    effect.duration = 0.3
    effect.channel = "combat_effects"
    return effect

func create_hit_effect() -> Resource:
    var effect = JuicyShakeResource.new()
    effect.duration = 0.2
    effect.channel = "combat_effects"
    return effect

func create_impact_effect() -> Resource:
    var effect = JuicyParticleResource.new()
    effect.duration = 0.5
    effect.channel = "combat_effects"
    return effect

func execute_sword_attack(target: Node):
    play_layered_effect(create_swing_effect(), target, EffectLayer.HIGH)
    play_combination("sword_attack", target)

func execute_fire_spell(target: Node):
    play_layered_effect(create_cast_effect(), target, EffectLayer.CRITICAL)
    play_combination("fire_spell", target)

func _on_attack_complete():
    print("攻击组合完成")
    # 可以在这里触发攻击完成的逻辑

func _on_spell_complete():
    print("法术组合完成")
    # 可以在这里触发法术完成的逻辑
```

## 最佳实践

1. **分层设计**: 使用分层系统管理不同优先级的效果
2. **条件中断**: 基于游戏状态设置中断条件，提高系统灵活性
3. **性能监控**: 实时监控系统性能，动态调整配置
4. **效果组合**: 使用组合系统创建复杂的效果序列
5. **自适应调整**: 根据运行时条件自动优化系统配置

## 相关文档

- [基础中断策略使用示例](basic_interruption_examples.md)
- [自定义中断策略示例](custom_interruption_examples.md)
- [中断事件处理示例](interruption_event_examples.md)
- [性能优化示例](performance_optimization_examples.md)
- [API文档](../api/)