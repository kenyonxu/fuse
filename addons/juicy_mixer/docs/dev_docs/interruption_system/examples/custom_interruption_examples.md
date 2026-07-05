# 自定义中断策略示例

## 概述

本文档展示了如何创建和使用自定义中断策略，扩展JuicyMixer中断系统的功能，满足特定游戏需求。

## 自定义中断策略基础

### 创建自定义策略处理器

```gdscript
class_name CustomInterruptionHandler
extends RefCounted

# 自定义策略处理器基类
class_name InterruptionHandler
extends RefCounted

# 策略名称
var strategy_name: String = ""

# 处理中断请求
func handle_interruption(new_context: Object, existing_context: Object, config: Dictionary) -> bool:
    push_error("handle_interruption must be implemented by subclass")
    return false

# 验证配置
func validate_config(config: Dictionary) -> Dictionary:
    return {"valid": true, "issues": []}

# 获取策略描述
func get_description() -> String:
    return "自定义中断策略"
```

### 实现具体策略处理器

```gdscript
# 渐进式中断策略
class_name ProgressiveInterruptionHandler
extends InterruptionHandler

func _init():
    strategy_name = "progressive"

func handle_interruption(new_context: Object, existing_context: Object, config: Dictionary) -> bool:
    # 获取配置参数
    var intensity_threshold = config.get("intensity_threshold", 5)
    var fade_duration = config.get("fade_duration", 0.3)
    
    # 计算新效果和现有效果的强度
    var new_intensity = _calculate_effect_intensity(new_context)
    var existing_intensity = _calculate_effect_intensity(existing_context)
    
    # 如果新效果强度超过阈值，则中断
    if new_intensity >= intensity_threshold:
        # 创建渐进过渡
        _create_progressive_transition(existing_context, new_context, fade_duration)
        return true
    
    # 否则加入队列
    var state = _get_interruption_state(existing_context.target)
    state.add_queued_context(new_context.context_id)
    return false

func _calculate_effect_intensity(context: Object) -> float:
    # 根据效果的优先级、持续时间等计算强度
    var base_intensity = context.resource.priority if context.resource else 0
    var duration_factor = min(context.resource.duration / 2.0, 1.0)
    var channel_factor = _get_channel_intensity_factor(context.resource.channel)
    
    return base_intensity * duration_factor * channel_factor

func _get_channel_intensity_factor(channel: String) -> float:
    # 不同通道的强度系数
    match channel:
        "critical_effects": return 2.0
        "combat_effects": return 1.5
        "ui_effects": return 1.0
        "ambient_effects": return 0.5
        _: return 1.0

func _create_progressive_transition(from_context: Object, to_context: Object, duration: float):
    # 创建渐进过渡效果
    var transition_resource = JuicyTweenResource.new()
    transition_resource.duration = duration
    transition_resource.property = JuicyMixerEnms.tween_properties.modulate
    
    # 设置过渡参数
    var from_modulate = from_context.target.modulate
    var to_modulate = to_context.target.modulate
    
    # 创建过渡上下文
    var transition_context = JuicyContext.create(transition_resource, from_context.target)
    transition_context.set_meta("from_modulate", from_modulate)
    transition_context.set_meta("to_modulate", to_modulate)
    
    JuicyMixer.play(transition_resource, from_context.target)

func validate_config(config: Dictionary) -> Dictionary:
    var issues = []
    
    if not config.has("intensity_threshold"):
        issues.append("缺少 intensity_threshold 配置")
    elif config.intensity_threshold < 0 or config.intensity_threshold > 20:
        issues.append("intensity_threshold 必须在 0-20 之间")
    
    if not config.has("fade_duration"):
        issues.append("缺少 fade_duration 配置")
    elif config.fade_duration < 0 or config.fade_duration > 5.0:
        issues.append("fade_duration 必须在 0-5.0 之间")
    
    return {
        "valid": issues.is_empty(),
        "issues": issues
    }

func get_description() -> String:
    return "渐进式中断：根据效果强度决定是否中断，支持渐进过渡"
```

### 注册自定义策略

```gdscript
class_name CustomInterruptionRegistry
extends RefCounted

var custom_handlers: Dictionary = {}

static var instance: CustomInterruptionRegistry

static func get_instance() -> CustomInterruptionRegistry:
    if not instance:
        instance = CustomInterruptionRegistry.new()
    return instance

func register_handler(strategy_name: String, handler: InterruptionHandler):
    custom_handlers[strategy_name] = handler
    print("注册自定义中断策略: ", strategy_name)

func get_handler(strategy_name: String) -> InterruptionHandler:
    return custom_handlers.get(strategy_name, null)

func get_all_strategies() -> Array[String]:
    return custom_handlers.keys()

func unregister_handler(strategy_name: String):
    if custom_handlers.has(strategy_name):
        custom_handlers.erase(strategy_name)
        print("注销自定义中断策略: ", strategy_name)
```

## 高级自定义策略示例

### 基于游戏状态的中断策略

```gdscript
# 游戏状态感知中断策略
class_name GameStateAwareInterruptionHandler
extends InterruptionHandler

var game_state_manager: Node
var state_policies: Dictionary = {}

func _init(manager: Node):
    strategy_name = "game_state_aware"
    game_state_manager = manager
    _setup_state_policies()

func _setup_state_policies():
    # 不同游戏状态的中断策略
    state_policies = {
        "exploration": {
            "max_concurrent_effects": 5,
            "priority_threshold": 10,
            "allow_combat_interruption": false
        },
        "combat": {
            "max_concurrent_effects": 10,
            "priority_threshold": 15,
            "allow_combat_interruption": true
        },
        "dialogue": {
            "max_concurrent_effects": 3,
            "priority_threshold": 8,
            "allow_combat_interruption": false
        },
        "menu": {
            "max_concurrent_effects": 8,
            "priority_threshold": 5,
            "allow_combat_interruption": false
        }
    }

func handle_interruption(new_context: Object, existing_context: Object, config: Dictionary) -> bool:
    var current_state = game_state_manager.get_current_state()
    var state_policy = state_policies.get(current_state, state_policies["exploration"])
    
    # 检查当前效果数量
    var active_count = _get_active_effects_count(existing_context.target)
    if active_count >= state_policy.max_concurrent_effects:
        # 检查是否可以替换低优先级效果
        return _try_replace_low_priority_effect(new_context, existing_context, state_policy)
    
    # 检查优先级阈值
    var new_priority = new_context.resource.priority if new_context.resource else 0
    if new_priority >= state_policy.priority_threshold:
        return true
    
    # 检查战斗中断规则
    if not state_policy.allow_combat_interruption and _is_combat_effect(new_context):
        return false
    
    return false

func _get_active_effects_count(target: Node) -> int:
    var state = JuicyMixer.get_interruption_state(target)
    return state.get_active_context_count() if state else 0

func _try_replace_low_priority_effect(new_context: Object, existing_context: Object, state_policy: Dictionary) -> bool:
    var new_priority = new_context.resource.priority if new_context.resource else 0
    var existing_priority = existing_context.resource.priority if existing_context.resource else 0
    
    if new_priority > existing_priority:
        # 替换低优先级效果
        JuicyMixer.stop(existing_context.context_id)
        return true
    
    return false

func _is_combat_effect(context: Object) -> bool:
    return context.resource.channel == "combat_effects" if context.resource else false

func get_description() -> String:
    return "游戏状态感知中断：根据当前游戏状态调整中断行为"
```

### 基于玩家状态的中断策略

```gdscript
# 玩家状态感知中断策略
class_name PlayerStateAwareInterruptionHandler
extends InterruptionHandler

var player: Node
var health_thresholds: Dictionary = {}
var stamina_thresholds: Dictionary = {}

func _init(player_node: Node):
    strategy_name = "player_state_aware"
    player = player_node
    _setup_thresholds()

func _setup_thresholds():
    # 健康状态阈值
    health_thresholds = {
        "critical": 0.2,    # 20%以下
        "low": 0.4,         # 20-40%
        "medium": 0.7,      # 40-70%
        "high": 1.0          # 70%以上
    }
    
    # 体力状态阈值
    stamina_thresholds = {
        "exhausted": 0.1,   # 10%以下
        "tired": 0.3,       # 10-30%
        "normal": 0.6,      # 30-60%
        "fresh": 1.0         # 60%以上
    }

func handle_interruption(new_context: Object, existing_context: Object, config: Dictionary) -> bool:
    var health_state = _get_health_state()
    var stamina_state = _get_stamina_state()
    
    # 根据玩家状态调整中断行为
    match health_state:
        "critical":
            # 危急状态：只允许关键效果
            return _handle_critical_state(new_context, existing_context)
        "low":
            # 低血量状态：优先防御和治疗效果
            return _handle_low_health_state(new_context, existing_context)
        "medium":
            # 中等血量状态：正常中断逻辑
            return _handle_medium_health_state(new_context, existing_context)
        "high":
            # 高血量状态：允许所有效果
            return _handle_high_health_state(new_context, existing_context)
    
    return false

func _get_health_state() -> String:
    var health_percentage = player.health / player.max_health
    
    for state in health_thresholds:
        if health_percentage <= health_thresholds[state]:
            return state
    
    return "high"

func _get_stamina_state() -> String:
    var stamina_percentage = player.stamina / player.max_stamina
    
    for state in stamina_thresholds:
        if stamina_percentage <= stamina_thresholds[state]:
            return state
    
    return "fresh"

func _handle_critical_state(new_context: Object, existing_context: Object) -> bool:
    # 危急状态：只允许防御和治疗效果
    var effect_type = _get_effect_type(new_context)
    
    match effect_type:
        "defense", "heal", "escape":
            return true
        _:
            return false

func _handle_low_health_state(new_context: Object, existing_context: Object) -> bool:
    # 低血量状态：优先防御和治疗效果
    var new_type = _get_effect_type(new_context)
    var existing_type = _get_effect_type(existing_context)
    
    # 治疗和防御效果可以中断其他效果
    if new_type in ["heal", "defense"]:
        return true
    
    # 其他效果不能中断治疗和防御效果
    if existing_type in ["heal", "defense"]:
        return false
    
    return true

func _handle_medium_health_state(new_context: Object, existing_context: Object) -> bool:
    # 中等血量状态：正常中断逻辑
    return new_context.resource.priority >= existing_context.resource.priority

func _handle_high_health_state(new_context: Object, existing_context: Object) -> bool:
    # 高血量状态：允许所有效果
    return true

func _get_effect_type(context: Object) -> String:
    # 根据效果通道和资源类型判断效果类型
    if not context.resource:
        return "unknown"
    
    var channel = context.resource.channel
    match channel:
        "healing_effects": return "heal"
        "defense_effects": return "defense"
        "combat_effects": return "attack"
        "movement_effects": return "movement"
        "ui_effects": return "ui"
        _: return "unknown"

func get_description() -> String:
    return "玩家状态感知中断：根据玩家健康和体力状态调整中断行为"
```

### 基于环境的中断策略

```gdscript
# 环境感知中断策略
class_name EnvironmentAwareInterruptionHandler
extends InterruptionHandler

var environment_manager: Node
var environment_factors: Dictionary = {}

func _init(env_manager: Node):
    strategy_name = "environment_aware"
    environment_manager = env_manager
    _setup_environment_factors()

func _setup_environment_factors():
    # 环境因素对效果的影响
    environment_factors = {
        "indoor": {
            "audio_dampening": 0.7,
            "visual_clarity": 1.0,
            "effect_duration_modifier": 1.0
        },
        "outdoor": {
            "audio_dampening": 1.0,
            "visual_clarity": 0.8,
            "effect_duration_modifier": 0.9
        },
        "underwater": {
            "audio_dampening": 0.3,
            "visual_clarity": 0.6,
            "effect_duration_modifier": 1.2
        },
        "darkness": {
            "audio_dampening": 1.2,
            "visual_clarity": 0.4,
            "effect_duration_modifier": 1.1
        }
    }

func handle_interruption(new_context: Object, existing_context: Object, config: Dictionary) -> bool:
    var current_environment = environment_manager.get_current_environment()
    var env_factors = environment_factors.get(current_environment, environment_factors["indoor"])
    
    # 根据环境调整效果属性
    _adjust_effect_for_environment(new_context, env_factors)
    _adjust_effect_for_environment(existing_context, env_factors)
    
    # 环境特定的中断逻辑
    match current_environment:
        "underwater":
            return _handle_underwater_interruption(new_context, existing_context)
        "darkness":
            return _handle_darkness_interruption(new_context, existing_context)
        "outdoor":
            return _handle_outdoor_interruption(new_context, existing_context)
        _:
            return _handle_standard_interruption(new_context, existing_context)

func _adjust_effect_for_environment(context: Object, factors: Dictionary):
    if not context.resource:
        return
    
    # 调整音频效果
    if context.resource.channel == "audio_effects":
        var volume_modifier = factors.get("audio_dampening", 1.0)
        context.resource.set_meta("volume_modifier", volume_modifier)
    
    # 调整视觉效果
    if context.resource.channel == "visual_effects":
        var clarity_modifier = factors.get("visual_clarity", 1.0)
        context.resource.set_meta("clarity_modifier", clarity_modifier)
    
    # 调整效果持续时间
    var duration_modifier = factors.get("effect_duration_modifier", 1.0)
    context.resource.set_meta("duration_modifier", duration_modifier)

func _handle_underwater_interruption(new_context: Object, existing_context: Object) -> bool:
    # 水下环境：优先处理气泡和水流效果
    var new_type = _get_environmental_effect_type(new_context)
    var existing_type = _get_environmental_effect_type(existing_context)
    
    # 水下相关效果优先级更高
    if new_type == "underwater" and existing_type != "underwater":
        return true
    
    if existing_type == "underwater" and new_type != "underwater":
        return false
    
    return new_context.resource.priority >= existing_context.resource.priority

func _handle_darkness_interruption(new_context: Object, existing_context: Object) -> bool:
    # 黑暗环境：优先处理光源效果
    var new_type = _get_environmental_effect_type(new_context)
    var existing_type = _get_environmental_effect_type(existing_context)
    
    # 光源效果优先级更高
    if new_type == "light" and existing_type != "light":
        return true
    
    if existing_type == "light" and new_type != "light":
        return false
    
    return new_context.resource.priority >= existing_context.resource.priority

func _handle_outdoor_interruption(new_context: Object, existing_context: Object) -> bool:
    # 户外环境：考虑天气因素
    var weather = environment_manager.get_current_weather()
    
    match weather:
        "rain":
            # 雨天：降低视觉效果优先级
            if new_context.resource.channel == "visual_effects":
                return false
        "wind":
            # 大风：降低粒子效果优先级
            if new_context.resource.channel == "particle_effects":
                return false
        _:
            pass
    
    return new_context.resource.priority >= existing_context.resource.priority

func _handle_standard_interruption(new_context: Object, existing_context: Object) -> bool:
    # 标准中断逻辑
    return new_context.resource.priority >= existing_context.resource.priority

func _get_environmental_effect_type(context: Object) -> String:
    if not context.resource:
        return "unknown"
    
    # 根据效果属性判断环境类型
    if context.resource.has_meta("environmental_type"):
        return context.resource.get_meta("environmental_type")
    
    # 根据通道和资源类型推断
    match context.resource.channel:
        "light_effects": return "light"
        "water_effects": return "underwater"
        "particle_effects": return "particle"
        _: return "standard"

func get_description() -> String:
    return "环境感知中断：根据当前环境调整中断行为和效果属性"
```

## 集成自定义策略

### 扩展JuicyInterruptionManager

```gdscript
class_name ExtendedJuicyInterruptionManager
extends JuicyInterruptionManager

var custom_registry: CustomInterruptionRegistry

func _init():
    super._init()
    custom_registry = CustomInterruptionRegistry.get_instance()

func register_custom_strategy(strategy_name: String, handler: InterruptionHandler):
    custom_registry.register_handler(strategy_name, handler)

func handle_custom_interruption(new_context_id: String, existing_context_id: String, 
                               strategy_name: String, config: Dictionary = {}) -> bool:
    var handler = custom_registry.get_handler(strategy_name)
    if not handler:
        push_error("未找到自定义中断策略: " + strategy_name)
        return false
    
    var new_context = JuicyMixer.get_context(new_context_id)
    var existing_context = JuicyMixer.get_context(existing_context_id)
    
    if not new_context or not existing_context:
        return false
    
    # 验证配置
    var validation = handler.validate_config(config)
    if not validation.valid:
        push_error("自定义策略配置无效: " + str(validation.issues))
        return false
    
    # 处理中断
    return handler.handle_interruption(new_context, existing_context, config)
```

### 在游戏中使用自定义策略

```gdscript
class_name CustomInterruptionDemo
extends Node

var extended_manager: ExtendedJuicyInterruptionManager

func _ready():
    # 创建扩展管理器
    extended_manager = ExtendedJuicyInterruptionManager.new()
    
    # 注册自定义策略
    _register_custom_strategies()
    
    # 设置测试场景
    _setup_test_scenario()

func _register_custom_strategies():
    # 注册渐进式策略
    var progressive_handler = ProgressiveInterruptionHandler.new()
    extended_manager.register_custom_strategy("progressive", progressive_handler)
    
    # 注册游戏状态感知策略
    var game_state_handler = GameStateAwareInterruptionHandler.new(GameManager)
    extended_manager.register_custom_strategy("game_state_aware", game_state_handler)
    
    # 注册玩家状态感知策略
    var player_state_handler = PlayerStateAwareInterruptionHandler.new(player)
    extended_manager.register_custom_strategy("player_state_aware", player_state_handler)
    
    # 注册环境感知策略
    var env_handler = EnvironmentAwareInterruptionHandler.new(EnvironmentManager)
    extended_manager.register_custom_strategy("environment_aware", env_handler)

func _setup_test_scenario():
    # 创建测试效果
    var effect1 = JuicyFeedbackResource.new()
    effect1.duration = 2.0
    effect1.channel = "test_effects"
    effect1.priority = 5
    
    var effect2 = JuicyFeedbackResource.new()
    effect2.duration = 1.5
    effect2.channel = "test_effects"
    effect2.priority = 8
    
    # 使用自定义策略处理中断
    var config = {
        "intensity_threshold": 6,
        "fade_duration": 0.3
    }
    
    # 播放第一个效果
    var context_id1 = JuicyMixer.play(effect1, test_target)
    
    # 等待一段时间
    await get_tree().create_timer(0.5).timeout
    
    # 使用自定义策略播放第二个效果
    var success = extended_manager.handle_custom_interruption(
        "effect_2", context_id1, "progressive", config
    )
    
    print("自定义中断处理结果: ", success)
```

## 最佳实践

1. **策略设计**: 保持策略的单一职责，每个策略解决特定的问题
2. **配置验证**: 始终验证自定义策略的配置参数
3. **性能考虑**: 避免在自定义策略中进行耗时操作
4. **错误处理**: 提供适当的错误处理和回退机制
5. **文档记录**: 为自定义策略提供清晰的文档和示例

## 常见问题

### Q: 如何在现有系统中集成自定义策略？
A: 扩展JuicyInterruptionManager或创建包装器来处理自定义策略。

### Q: 自定义策略的性能如何优化？
A: 缓存计算结果，避免重复操作，使用高效的数据结构。

### Q: 如何测试自定义策略？
A: 创建单元测试，模拟各种中断场景，验证策略行为。

### Q: 自定义策略能否与内置策略组合使用？
A: 可以，通过配置参数或策略链的方式实现组合。

## 相关文档

- [基础中断策略使用示例](basic_interruption_examples.md)
- [高级中断配置示例](advanced_interruption_examples.md)
- [中断事件处理示例](interruption_event_examples.md)
- [性能优化示例](performance_optimization_examples.md)
- [API文档](../api/)