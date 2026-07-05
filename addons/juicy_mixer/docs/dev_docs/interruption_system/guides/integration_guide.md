# 中断系统集成步骤指南

## 概述

本指南详细介绍了如何将JuicyMixer中断策略系统集成到您的Godot项目中，包括基础设置、高级配置、测试验证等完整流程。

## 前置条件

### 系统要求

- Godot 4.0+ 版本
- 支持GDScript的项目
- 基本的Godot开发经验

### 依赖项

- JuicyMixer核心系统
- 中间件系统支持
- 事件系统（可选）

## 集成步骤

### 第一步：项目设置

#### 1.1 添加JuicyMixer插件

1. 将JuicyMixer插件文件夹复制到项目的`addons/`目录
2. 在Godot编辑器中启用插件
3. 验证插件是否正确加载

```gdscript
# 在项目设置中检查插件
func _ready():
    if Engine.has_singleton("JuicyMixer"):
        print("JuicyMixer插件已成功加载")
    else:
        push_error("JuicyMixer插件未找到，请检查插件安装")
```

#### 1.2 创建自动加载

1. 在项目设置中创建新的自动加载
2. 设置名称为`JuicyMixer`
3. 设置路径为`res://addons/juicy_mixer/plugin.gd`
4. 启用自动加载

```gdscript
# 验证自动加载
func _ready():
    if JuicyMixer:
        print("JuicyMixer自动加载已设置")
    else:
        push_error("JuicyMixer自动加载设置失败")
```

### 第二步：基础配置

#### 2.1 初始化中断系统

```gdscript
# 在主场景或游戏管理器中初始化
class_name GameManager
extends Node

func _ready():
    _initialize_interruption_system()

func _initialize_interruption_system():
    """初始化中断系统"""
    print("初始化JuicyMixer中断系统...")
    
    # 验证中断中间件是否可用
    var interruption_middleware = JuicyMixer.get_middleware("InterruptionMiddleware")
    if not interruption_middleware:
        push_error("InterruptionMiddleware未找到")
        return
    
    # 设置默认配置
    _setup_default_interruption_config()
    
    print("中断系统初始化完成")

func _setup_default_interruption_config():
    """设置默认中断配置"""
    # 设置全局默认策略
    JuicyMixer.set_global_interruption_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
    
    # 设置基础通道配置
    _setup_basic_channels()
    
    # 设置资源类型优先级
    _setup_resource_priorities()

func _setup_basic_channels():
    """设置基础通道配置"""
    # UI效果通道
    var ui_config = ChannelInterruptionConfig.new()
    ui_config.channel_name = "ui_effects"
    ui_config.set_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
    ui_config.set_channel_priority(10)
    ui_config.set_max_queue_size(5)
    JuicyMixer.set_channel_interruption_config("ui_effects", ui_config)
    
    # 游戏效果通道
    var game_config = ChannelInterruptionConfig.new()
    game_config.channel_name = "game_effects"
    game_config.set_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_STACK)
    game_config.set_channel_priority(15)
    game_config.set_max_queue_size(10)
    JuicyMixer.set_channel_interruption_config("game_effects", game_config)
    
    # 音频效果通道
    var audio_config = ChannelInterruptionConfig.new()
    audio_config.channel_name = "audio_effects"
    audio_config.set_policy(JuicyMixerEnms.InterruptionPolicy.FADE_OUT_FADE_IN)
    audio_config.set_transition_duration(0.3)
    audio_config.set_channel_priority(5)
    JuicyMixer.set_channel_interruption_config("audio_effects", audio_config)

func _setup_resource_priorities():
    """设置资源类型优先级"""
    JuicyMixer.set_resource_interruption_priority("JuicyShakeResource", 10)
    JuicyMixer.set_resource_interruption_priority("JuicyTweenResource", 5)
    JuicyMixer.set_resource_interruption_priority("JuicySpringResource", 7)
    JuicyMixer.set_resource_interruption_priority("JuicyParticleResource", 8)
```

#### 2.2 创建效果资源

```gdscript
# 创建自定义反馈资源
class_name GameEffectResource
extends JuicyFeedbackResource

@export var effect_type: String = "generic"
@export var effect_strength: float = 1.0

func _init():
    # 设置默认中断策略
    set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
    set_interruption_priority(5)
    allow_interruption = true
    can_interrupt_others = true

func create_drivers() -> Array:
    """创建效果驱动器"""
    var drivers = []
    
    match effect_type:
        "shake":
            drivers.append(_create_shake_driver())
        "tween":
            drivers.append(_create_tween_driver())
        "particle":
            drivers.append(_create_particle_driver())
        _:
            drivers.append(_create_generic_driver())
    
    return drivers

func _create_shake_driver() -> Object:
    """创建震动驱动器"""
    var driver = JuicyShakeDriver.new()
    driver.strength = effect_strength
    return driver

func _create_tween_driver() -> Object:
    """创建补间驱动器"""
    var driver = JuicyTweenDriver.new()
    driver.duration = duration
    return driver

func _create_particle_driver() -> Object:
    """创建粒子驱动器"""
    var driver = JuicyParticleDriver.new()
    driver.emission_rate = effect_strength * 10
    return driver

func _create_generic_driver() -> Object:
    """创建通用驱动器"""
    var driver = JuicyGenericDriver.new()
    driver.intensity = effect_strength
    return driver
```

### 第三步：集成到游戏逻辑

#### 3.1 基础效果播放

```gdscript
# 在游戏对象中集成中断系统
class_name PlayerController
extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var effect_manager: Node = $EffectManager

func _ready():
    _setup_effect_manager()

func _setup_effect_manager():
    """设置效果管理器"""
    # 创建效果资源
    var jump_effect = GameEffectResource.new()
    jump_effect.effect_type = "tween"
    jump_effect.effect_strength = 1.5
    jump_effect.duration = 0.5
    jump_effect.channel = "game_effects"
    
    var hurt_effect = GameEffectResource.new()
    hurt_effect.effect_type = "shake"
    hurt_effect.effect_strength = 2.0
    hurt_effect.duration = 0.8
    hurt_effect.channel = "game_effects"
    hurt_effect.set_interruption_priority(15)  # 高优先级
    
    var heal_effect = GameEffectResource.new()
    heal_effect.effect_type = "particle"
    heal_effect.effect_strength = 1.0
    heal_effect.duration = 1.0
    heal_effect.channel = "game_effects"
    
    # 存储效果引用
    effect_manager.set_meta("jump_effect", jump_effect)
    effect_manager.set_meta("hurt_effect", hurt_effect)
    effect_manager.set_meta("heal_effect", heal_effect)

func play_jump_effect():
    """播放跳跃效果"""
    var jump_effect = effect_manager.get_meta("jump_effect")
    JuicyMixer.play(jump_effect, sprite)

func take_damage(amount: int):
    """处理受伤"""
    var hurt_effect = effect_manager.get_meta("hurt_effect")
    JuicyMixer.play(hurt_effect, sprite)
    
    # 如果伤害严重，添加屏幕震动
    if amount > 50:
        var screen_shake = GameEffectResource.new()
        screen_shake.effect_type = "shake"
        screen_shake.effect_strength = 3.0
        screen_shake.duration = 0.6
        screen_shake.channel = "ui_effects"
        screen_shake.set_interruption_priority(20)
        
        JuicyMixer.play(screen_shake, get_viewport())

func heal(amount: int):
    """处理治疗"""
    var heal_effect = effect_manager.get_meta("heal_effect")
    JuicyMixer.play(heal_effect, sprite)
```

#### 3.2 UI集成

```gdscript
# UI元素中断集成
class_name UIButton
extends Button

@export var button_effect_type: String = "tween"
@export var effect_strength: float = 1.0

func _ready():
    _setup_button_effect()

func _setup_button_effect():
    """设置按钮效果"""
    # 创建按钮点击效果
    var click_effect = GameEffectResource.new()
    click_effect.effect_type = button_effect_type
    click_effect.effect_strength = effect_strength
    click_effect.duration = 0.3
    click_effect.channel = "ui_effects"
    click_effect.set_interruption_priority(8)
    
    # 连接按钮信号
    pressed.connect(_on_button_pressed)
    
    # 存储效果引用
    set_meta("click_effect", click_effect)

func _on_button_pressed():
    """按钮按下处理"""
    var click_effect = get_meta("click_effect")
    JuicyMixer.play(click_effect, self)
    
    # 播放音效（如果存在）
    if has_node("AudioStreamPlayer"):
        var audio_player = $AudioStreamPlayer as AudioStreamPlayer
        if audio_player.stream:
            audio_player.play()
```

### 第四步：高级配置

#### 4.1 游戏状态感知配置

```gdscript
# 游戏状态感知的中断配置
class_name GameStateInterruptionManager
extends Node

enum GameState {
    MENU,
    PLAYING,
    COMBAT,
    DIALOGUE,
    PAUSED
}

var current_state: GameState = GameState.MENU
var state_configs: Dictionary = {}

func _ready():
    _setup_state_configs()
    _connect_game_state_signals()

func _setup_state_configs():
    """设置不同游戏状态的中断配置"""
    # 菜单状态配置
    var menu_config = ChannelInterruptionConfig.new()
    menu_config.channel_name = "menu_effects"
    menu_config.set_policy(JuicyMixerEnms.InterruptionPolicy.SMOOTH_TRANSITION)
    menu_config.set_channel_priority(5)
    menu_config.set_max_queue_size(3)
    state_configs[GameState.MENU] = menu_config
    
    # 游戏状态配置
    var play_config = ChannelInterruptionConfig.new()
    play_config.channel_name = "play_effects"
    play_config.set_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_STACK)
    play_config.set_channel_priority(10)
    play_config.set_max_queue_size(8)
    state_configs[GameState.PLAYING] = play_config
    
    # 战斗状态配置
    var combat_config = ChannelInterruptionConfig.new()
    combat_config.channel_name = "combat_effects"
    combat_config.set_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
    combat_config.set_channel_priority(20)
    combat_config.set_max_queue_size(15)
    combat_config.set_transition_duration(0.1)
    state_configs[GameState.COMBAT] = combat_config
    
    # 对话状态配置
    var dialogue_config = ChannelInterruptionConfig.new()
    dialogue_config.channel_name = "dialogue_effects"
    dialogue_config.set_policy(JuicyMixerEnms.InterruptionPolicy.IGNORE)
    dialogue_config.set_channel_priority(15)
    dialogue_config.allow_preemption = false
    state_configs[GameState.DIALOGUE] = dialogue_config

func _connect_game_state_signals():
    """连接游戏状态信号"""
    # 这里应该连接到实际的游戏状态管理器
    # 示例代码，需要根据实际项目调整
    pass

func change_game_state(new_state: GameState):
    """改变游戏状态"""
    current_state = new_state
    
    # 应用状态对应的配置
    var config = state_configs[new_state]
    if config:
        # 更新所有相关通道的配置
        _apply_state_config(config)
        
        print("游戏状态切换到: ", new_state, ", 应用中断配置: ", config.channel_name)

func _apply_state_config(config: ChannelInterruptionConfig):
    """应用状态配置"""
    var channels = ["ui_effects", "game_effects", "audio_effects", "ambient_effects"]
    
    for channel in channels:
        var channel_config = JuicyMixer.get_channel_interruption_config(channel)
        if channel_config:
            # 复制状态配置的关键参数
            channel_config.set_policy(config.get_policy())
            channel_config.set_channel_priority(config.get_channel_priority())
            channel_config.set_max_queue_size(config.get_max_queue_size())
            
            if config.has_method("get_transition_duration"):
                channel_config.set_transition_duration(config.get_transition_duration())
            
            JuicyMixer.set_channel_interruption_config(channel, channel_config)
```

#### 4.2 性能优化配置

```gdscript
# 性能优化配置
class_name PerformanceInterruptionOptimizer
extends Node

var performance_profile: String = "balanced"  # "performance", "balanced", "quality"
var adaptive_quality: bool = true

func _ready():
    _detect_platform()
    _apply_performance_profile()

func _detect_platform():
    """检测平台并调整配置"""
    var platform = OS.get_name()
    
    match platform:
        "Android", "iOS":
            performance_profile = "performance"
            adaptive_quality = true
        "Windows", "macOS", "Linux":
            # 检查硬件性能
            var cpu_count = OS.get_processor_count()
            var memory_mb = OS.get_static_memory_usage_by_type()[OS.MEMORY_TYPE_VIDEO] / 1024 / 1024
            
            if cpu_count >= 8 and memory_mb >= 4096:
                performance_profile = "quality"
            elif cpu_count >= 4 and memory_mb >= 2048:
                performance_profile = "balanced"
            else:
                performance_profile = "performance"
                adaptive_quality = true

func _apply_performance_profile():
    """应用性能配置文件"""
    match performance_profile:
        "performance":
            _apply_performance_settings()
        "balanced":
            _apply_balanced_settings()
        "quality":
            _apply_quality_settings()

func _apply_performance_settings():
    """应用性能设置"""
    print("应用性能优化设置")
    
    # 减少队列大小
    _set_all_channel_queue_size(5)
    
    # 使用快速中断策略
    JuicyMixer.set_global_interruption_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
    
    # 减少过渡时间
    _set_all_transition_duration(0.1)
    
    # 禁用高级功能
    _disable_advanced_features()

func _apply_balanced_settings():
    """应用平衡设置"""
    print("应用平衡设置")
    
    # 中等队列大小
    _set_all_channel_queue_size(10)
    
    # 使用平衡的中断策略
    JuicyMixer.set_global_interruption_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_STACK)
    
    # 中等过渡时间
    _set_all_transition_duration(0.2)
    
    # 启用部分高级功能
    _enable_partial_advanced_features()

func _apply_quality_settings():
    """应用质量设置"""
    print("应用质量设置")
    
    # 较大队列大小
    _set_all_channel_queue_size(20)
    
    # 使用平滑过渡策略
    JuicyMixer.set_global_interruption_policy(JuicyMixerEnms.InterruptionPolicy.SMOOTH_TRANSITION)
    
    # 较长过渡时间
    _set_all_transition_duration(0.3)
    
    # 启用所有高级功能
    _enable_all_advanced_features()

func _set_all_channel_queue_size(size: int):
    """设置所有通道的队列大小"""
    var channels = ["ui_effects", "game_effects", "audio_effects", "ambient_effects"]
    for channel in channels:
        var config = JuicyMixer.get_channel_interruption_config(channel)
        if config:
            config.set_max_queue_size(size)
            JuicyMixer.set_channel_interruption_config(channel, config)

func _set_all_transition_duration(duration: float):
    """设置所有通道的过渡时间"""
    var channels = ["ui_effects", "game_effects", "audio_effects", "ambient_effects"]
    for channel in channels:
        var config = JuicyMixer.get_channel_interruption_config(channel)
        if config:
            config.set_transition_duration(duration)
            JuicyMixer.set_channel_interruption_config(channel, config)

func _disable_advanced_features():
    """禁用高级功能"""
    var channels = ["ui_effects", "game_effects", "audio_effects", "ambient_effects"]
    for channel in channels:
        var config = JuicyMixer.get_channel_interruption_config(channel)
        if config:
            config.enable_feature("priority_queue", false)
            config.enable_feature("interruption_history", false)
            config.enable_feature("auto_cleanup", false)
            JuicyMixer.set_channel_interruption_config(channel, config)

func _enable_partial_advanced_features():
    """启用部分高级功能"""
    var channels = ["ui_effects", "game_effects"]
    for channel in channels:
        var config = JuicyMixer.get_channel_interruption_config(channel)
        if config:
            config.enable_feature("priority_queue", true)
            config.enable_feature("interruption_history", false)
            config.enable_feature("auto_cleanup", true)
            JuicyMixer.set_channel_interruption_config(channel, config)

func _enable_all_advanced_features():
    """启用所有高级功能"""
    var channels = ["ui_effects", "game_effects", "audio_effects", "ambient_effects"]
    for channel in channels:
        var config = JuicyMixer.get_channel_interruption_config(channel)
        if config:
            config.enable_feature("priority_queue", true)
            config.enable_feature("interruption_history", true)
            config.enable_feature("auto_cleanup", true)
            JuicyMixer.set_channel_interruption_config(channel, config)
```

### 第五步：测试验证

#### 5.1 单元测试

```gdscript
# 中断系统单元测试
class_name InterruptionSystemTests
extends Node

func _ready():
    run_all_tests()

func run_all_tests():
    """运行所有测试"""
    print("开始中断系统测试...")
    
    var test_results = []
    
    # 测试基础功能
    test_results.append(test_basic_interruption())
    test_results.append(test_channel_configuration())
    test_results.append(test_priority_system())
    
    # 测试高级功能
    test_results.append(test_state_management())
    test_results.append(test_transition_handling())
    test_results.append(test_performance())
    
    # 输出测试结果
    _print_test_results(test_results)

func test_basic_interruption() -> Dictionary:
    """测试基础中断功能"""
    print("测试基础中断功能...")
    
    var test_effect = GameEffectResource.new()
    test_effect.effect_type = "tween"
    test_effect.duration = 1.0
    
    # 测试播放效果
    var context_id = JuicyMixer.play(test_effect, self)
    var success = not context_id.is_empty()
    
    return {
        "name": "基础中断功能",
        "passed": success,
        "details": "效果播放" + ("成功" if success else "失败")
    }

func test_channel_configuration() -> Dictionary:
    """测试通道配置"""
    print("测试通道配置...")
    
    var config = ChannelInterruptionConfig.new()
    config.channel_name = "test_channel"
    config.set_policy(JuicyMixerEnms.InterruptionPolicy.STACK)
    
    var validation = config.validate_config()
    
    return {
        "name": "通道配置",
        "passed": validation.valid,
        "details": "配置验证" + ("通过" if validation.valid else "失败")
    }

func test_priority_system() -> Dictionary:
    """测试优先级系统"""
    print("测试优先级系统...")
    
    # 设置不同优先级的效果
    var low_effect = GameEffectResource.new()
    low_effect.set_interruption_priority(1)
    
    var high_effect = GameEffectResource.new()
    high_effect.set_interruption_priority(10)
    
    # 测试优先级比较
    var low_priority = low_effect.get_interruption_priority()
    var high_priority = high_effect.get_interruption_priority()
    
    var success = high_priority > low_priority
    
    return {
        "name": "优先级系统",
        "passed": success,
        "details": "优先级比较" + ("正确" if success else "错误")
    }

func test_state_management() -> Dictionary:
    """测试状态管理"""
    print("测试状态管理...")
    
    var state = JuicyMixer.get_interruption_state(self)
    var success = state != null
    
    return {
        "name": "状态管理",
        "passed": success,
        "details": "状态获取" + ("成功" if success else "失败")
    }

func test_transition_handling() -> Dictionary:
    """测试过渡处理"""
    print("测试过渡处理...")
    
    # 创建过渡效果
    var transition_effect = GameEffectResource.new()
    transition_effect.set_interruption_policy(JuicyMixerEnms.InterruptionPolicy.SMOOTH_TRANSITION)
    transition_effect.interruption_fade_duration = 0.3
    
    var success = transition_effect.interruption_fade_duration > 0
    
    return {
        "name": "过渡处理",
        "passed": success,
        "details": "过渡配置" + ("正确" if success else "错误")
    }

func test_performance() -> Dictionary:
    """测试性能"""
    print("测试性能...")
    
    var stats = JuicyMixer.get_interruption_stats()
    var success = stats.has("interruption_count")
    
    return {
        "name": "性能统计",
        "passed": success,
        "details": "性能统计" + ("可用" if success else "不可用")
    }

func _print_test_results(results: Array[Dictionary]):
    """打印测试结果"""
    print("\n=== 中断系统测试结果 ===")
    
    var passed_count = 0
    var total_count = results.size()
    
    for result in results:
        var status = "✓ 通过" if result.passed else "✗ 失败"
        print(result.name, ": ", status, " - ", result.details)
        
        if result.passed:
            passed_count += 1
    
    print("\n总计: ", passed_count, "/", total_count, " 测试通过")
    
    if passed_count == total_count:
        print("🎉 所有测试通过！中断系统已正确集成。")
    else:
        print("⚠️ 部分测试失败，请检查配置。")
```

#### 5.2 集成测试

```gdscript
# 集成测试场景
class_name InterruptionIntegrationTest
extends Node

func _ready():
    run_integration_tests()

func run_integration_tests():
    """运行集成测试"""
    print("开始集成测试...")
    
    # 测试场景1：UI效果中断
    await test_ui_interruption_scenario()
    
    # 测试场景2：战斗效果中断
    await test_combat_interruption_scenario()
    
    # 测试场景3：大量效果处理
    await test_mass_effects_scenario()
    
    print("集成测试完成")

func test_ui_interruption_scenario():
    """测试UI效果中断场景"""
    print("测试UI效果中断场景...")
    
    # 创建UI按钮
    var button = Button.new()
    button.text = "测试按钮"
    add_child(button)
    
    # 创建按钮效果
    var click_effect = GameEffectResource.new()
    click_effect.effect_type = "tween"
    click_effect.duration = 0.3
    click_effect.channel = "ui_effects"
    
    # 模拟多次快速点击
    for i in range(5):
        JuicyMixer.play(click_effect, button)
        await get_tree().create_timer(0.1).timeout
    
    # 检查中断状态
    var state = JuicyMixer.get_interruption_state(button)
    if state:
        print("UI中断状态 - 活跃: ", state.get_active_context_count())
        print("UI中断状态 - 队列: ", state.get_queued_context_count())
    
    button.queue_free()

func test_combat_interruption_scenario():
    """测试战斗效果中断场景"""
    print("测试战斗效果中断场景...")
    
    # 创建战斗角色
    var character = Node2D.new()
    character.name = "TestCharacter"
    add_child(character)
    
    # 创建不同优先级的战斗效果
    var low_attack = GameEffectResource.new()
    low_attack.effect_type = "shake"
    low_attack.set_interruption_priority(5)
    low_attack.channel = "combat_effects"
    
    var high_attack = GameEffectResource.new()
    high_attack.effect_type = "shake"
    high_attack.set_interruption_priority(15)
    high_attack.channel = "combat_effects"
    
    # 播放低优先级攻击
    var context1 = JuicyMixer.play(low_attack, character)
    await get_tree().create_timer(0.2).timeout
    
    # 播放高优先级攻击（应该中断低优先级）
    var context2 = JuicyMixer.play(high_attack, character)
    await get_tree().create_timer(0.5).timeout
    
    # 检查中断结果
    var state = JuicyMixer.get_interruption_state(character)
    if state:
        print("战斗中断状态 - 活跃: ", state.get_active_context_count())
        print("战斗中断状态 - 队列: ", state.get_queued_context_count())
    
    character.queue_free()

func test_mass_effects_scenario():
    """测试大量效果处理场景"""
    print("测试大量效果处理场景...")
    
    var start_time = Time.get_ticks_msec()
    var start_fps = Engine.get_frames_per_second()
    
    # 创建大量效果
    var effects = []
    for i in range(50):
        var effect = GameEffectResource.new()
        effect.effect_type = "tween"
        effect.duration = 0.1
        effect.channel = "stress_test_effects"
        effects.append(effect)
    
    # 快速播放效果
    var context_ids = []
    for effect in effects:
        var context_id = JuicyMixer.play(effect, self)
        if not context_id.is_empty():
            context_ids.append(context_id)
    
    # 等待所有效果完成
    await get_tree().create_timer(2.0).timeout
    
    var end_time = Time.get_ticks_msec()
    var end_fps = Engine.get_frames_per_second()
    
    print("大量效果测试结果:")
    print("  处理时间: ", (end_time - start_time), "ms")
    print("  FPS变化: ", start_fps - end_fps)
    print("  成功播放: ", context_ids.size(), "/", effects.size())
```

### 第六步：部署和监控

#### 6.1 生产环境配置

```gdscript
# 生产环境配置
class_name ProductionInterruptionConfig
extends Node

func _ready():
    if OS.is_debug_build():
        print("调试模式，跳过生产环境配置")
        return
    
    _apply_production_settings()

func _apply_production_settings():
    """应用生产环境设置"""
    print("应用生产环境中断配置...")
    
    # 启用性能监控
    _enable_performance_monitoring()
    
    # 设置错误处理
    _setup_error_handling()
    
    # 配置日志级别
    _configure_logging()

func _enable_performance_monitoring():
    """启用性能监控"""
    var monitor = PerformanceMonitor.new()
    monitor.name = "InterruptionPerformanceMonitor"
    add_child(monitor)
    
    # 设置性能阈值
    monitor.set_thresholds({
        "max_interruption_time": 5.0,
        "max_queue_size": 20,
        "min_fps": 30
    })

func _setup_error_handling():
    """设置错误处理"""
    # 连接错误信号
    if JuicyMixer.instance and JuicyMixer.instance.has_signal("error_occurred"):
        JuicyMixer.instance.error_occurred.connect(_on_interruption_error)

func _configure_logging():
    """配置日志"""
    # 在生产环境中减少详细日志
    var interruption_middleware = JuicyMixer.get_middleware("InterruptionMiddleware")
    if interruption_middleware:
        interruption_middleware.set_config({"enable_debug_logging": false})

func _on_interruption_error(error_data: Dictionary):
    """处理中断错误"""
    print("中断系统错误: ", error_data)
    
    # 记录错误到日志文件
    var log_file = FileAccess.open("user://interruption_errors.log", FileAccess.WRITE)
    if log_file:
        var timestamp = Time.get_datetime_string_from_system()
        log_file.store_line("[%s] %s" % [timestamp, str(error_data)])
        log_file.close()
```

#### 6.2 监控和分析

```gdscript
# 监控和分析系统
class_name InterruptionAnalytics
extends Node

var analytics_data: Dictionary = {}
var report_interval: float = 60.0  # 每分钟报告一次
var report_timer: Timer

func _ready():
    _setup_analytics()

func _setup_analytics():
    """设置分析系统"""
    analytics_data = {
        "interruption_counts": {},
        "strategy_usage": {},
        "performance_metrics": {},
        "error_counts": {},
        "session_start": Time.get_ticks_msec() / 1000.0
    }
    
    # 设置定时报告
    report_timer = Timer.new()
    report_timer.wait_time = report_interval
    report_timer.timeout.connect(_generate_analytics_report)
    add_child(report_timer)
    report_timer.start()

func record_interruption(strategy: String, channel: String, duration: float):
    """记录中断数据"""
    # 记录策略使用
    if not analytics_data.strategy_usage.has(strategy):
        analytics_data.strategy_usage[strategy] = 0
    analytics_data.strategy_usage[strategy] += 1
    
    # 记录通道使用
    if not analytics_data.interruption_counts.has(channel):
        analytics_data.interruption_counts[channel] = 0
    analytics_data.interruption_counts[channel] += 1
    
    # 记录性能指标
    if not analytics_data.performance_metrics.has("avg_duration"):
        analytics_data.performance_metrics.avg_duration = 0.0
        analytics_data.performance_metrics.count = 0
    
    var current_avg = analytics_data.performance_metrics.avg_duration
    var count = analytics_data.performance_metrics.count
    var new_avg = (current_avg * count + duration) / (count + 1)
    analytics_data.performance_metrics.avg_duration = new_avg
    analytics_data.performance_metrics.count += 1

func record_error(error_type: String):
    """记录错误"""
    if not analytics_data.error_counts.has(error_type):
        analytics_data.error_counts[error_type] = 0
    analytics_data.error_counts[error_type] += 1

func _generate_analytics_report():
    """生成分析报告"""
    var current_time = Time.get_ticks_msec() / 1000.0
    var session_duration = current_time - analytics_data.session_start
    
    print("\n=== 中断系统分析报告 ===")
    print("会话时长: %.1f 秒" % session_duration)
    print("中断次数总计: ", _get_total_interruptions())
    
    print("\n策略使用统计:")
    for strategy in analytics_data.strategy_usage:
        print("  %s: %d 次" % [strategy, analytics_data.strategy_usage[strategy]])
    
    print("\n通道使用统计:")
    for channel in analytics_data.interruption_counts:
        print("  %s: %d 次" % [channel, analytics_data.interruption_counts[channel]])
    
    print("\n性能指标:")
    var perf = analytics_data.performance_metrics
    if perf.has("avg_duration"):
        print("  平均中断时间: %.3f ms" % perf.avg_duration)
        print("  总中断次数: %d" % perf.count)
    
    if analytics_data.error_counts.size() > 0:
        print("\n错误统计:")
        for error_type in analytics_data.error_counts:
            print("  %s: %d 次" % [error_type, analytics_data.error_counts[error_type]])

func _get_total_interruptions() -> int:
    """获取总中断次数"""
    var total = 0
    for count in analytics_data.interruption_counts.values():
        total += count
    return total

func get_analytics_data() -> Dictionary:
    """获取分析数据"""
    return analytics_data.duplicate()

func export_analytics_report() -> void:
    """导出分析报告"""
    var report_data = {
        "timestamp": Time.get_datetime_string_from_system(),
        "session_duration": Time.get_ticks_msec() / 1000.0 - analytics_data.session_start,
        "data": analytics_data
    }
    
    var json_string = JSON.stringify(report_data, "\t")
    var file = FileAccess.open("user://interruption_analytics.json", FileAccess.WRITE)
    if file:
        file.store_string(json_string)
        file.close()
        print("分析报告已导出到: user://interruption_analytics.json")
```

## 验证清单

### 集成验证清单

- [ ] JuicyMixer插件已正确安装
- [ ] 自动加载已设置
- [ ] 中断中间件已加载
- [ ] 基础通道配置已完成
- [ ] 效果资源已创建并配置
- [ ] 游戏逻辑已集成中断系统
- [ ] 单元测试已通过
- [ ] 集成测试已通过
- [ ] 生产环境配置已完成
- [ ] 监控系统已设置

### 性能验证清单

- [ ] 中断处理时间 < 5ms
- [ ] 队列大小在合理范围内
- [ ] 内存使用稳定
- [ ] 帧率保持在目标范围内
- [ ] 无内存泄漏

## 故障排除

### 常见问题

1. **插件未加载**
   - 检查插件路径是否正确
   - 验证plugin.gd文件是否存在
   - 查看编辑器输出中的错误信息

2. **自动加载失败**
   - 确认自动加载路径正确
   - 检查脚本是否有语法错误
   - 重启编辑器

3. **中断不工作**
   - 验证中间件是否正确注册
   - 检查通道配置
   - 确认效果资源配置正确

4. **性能问题**
   - 减少队列大小
   - 禁用不必要的高级功能
   - 使用性能分析工具

### 调试技巧

1. **启用调试日志**
   ```gdscript
   var middleware = JuicyMixer.get_middleware("InterruptionMiddleware")
   if middleware:
       middleware.set_config({"enable_debug_logging": true})
   ```

2. **检查中断状态**
   ```gdscript
   var state = JuicyMixer.get_interruption_state(target)
   if state:
       print("活跃上下文: ", state.active_contexts)
       print("队列上下文: ", state.queued_contexts)
   ```

3. **监控性能统计**
   ```gdscript
   var stats = JuicyMixer.get_interruption_stats()
   print("性能统计: ", stats)
   ```

## 最佳实践

1. **渐进式集成**: 先实现基础功能，再添加高级特性
2. **充分测试**: 在各种场景下测试中断系统
3. **性能优先**: 始终关注性能影响
4. **文档记录**: 记录配置决策和集成过程
5. **监控部署**: 在生产环境中持续监控系统表现

## 相关文档

- [配置最佳实践指南](configuration_best_practices.md)
- [性能调优建议](performance_tuning.md)
- [故障排除指南](troubleshooting.md)
- [API文档](../api/)
- [使用示例](../examples/)