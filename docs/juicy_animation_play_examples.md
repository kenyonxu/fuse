# JuicyAnimationPlay 代码示例与集成指南

## 1. 快速开始

### 1.1 基本使用示例

```gdscript
# 创建动画播放资源
var animation_resource = JuicyAnimationPlayResource.new()

# 添加单个动画
animation_resource.add_animation_data(
    NodePath("../Character"),           # 目标节点路径
    "walk",                            # 动画名称
    AnimationPlayData.PlayMode.NORMAL,   # 播放模式
    1.0,                               # 播放到100%
    0.2,                               # 混入时间
    0.1                                # 混出时间
)

# 播放动画
var context_id = JuicyMixer.play(animation_resource, get_node("."))
print("Animation playing with context ID: ", context_id)
```

### 1.2 多动画序列示例

```gdscript
# 创建复杂的动画序列
var combo_animation = JuicyAnimationPlayResource.new()

# 第一个动画：起手动作
combo_animation.add_animation_data(
    NodePath("../Player"),
    "attack_start",
    AnimationPlayData.PlayMode.NORMAL,
    1.0,    # 完整播放
    0.0,     # 无混入
    0.3      # 混出到下一个动画
)

# 第二个动画：连击动作
combo_animation.add_animation_data(
    NodePath("../Player"),
    "attack_combo",
    AnimationPlayData.PlayMode.SYNC,
    0.8,     # 只播放80%
    0.3,     # 与前一个动画混入
    0.2      # 混出到下一个动画
)

# 第三个动画：收尾动作
combo_animation.add_animation_data(
    NodePath("../Player"),
    "attack_end",
    AnimationPlayData.PlayMode.NORMAL,
    1.0,     # 完整播放
    0.2,     # 混入
    0.0      # 无混出
)

# 设置为不循环
combo_animation.loop = false

# 播放连击动画序列
var context_id = JuicyMixer.play(combo_animation, get_node("."))
```

## 2. 高级用法

### 2.1 循环动画序列

```gdscript
# 创建循环的待机动画序列
var idle_loop = JuicyAnimationPlayResource.new()

# 呼吸动画
idle_loop.add_animation_data(
    NodePath("../Character"),
    "breathe",
    AnimationPlayData.PlayMode.NORMAL,
    1.0,
    0.5,    # 缓慢混入
    0.5     # 缓慢混出
)

# 微调动画
idle_loop.add_animation_data(
    NodePath("../Character"),
    "fidget",
    AnimationPlayData.PlayMode.SYNC,
    0.6,    # 只播放60%
    0.5,    # 混入
    0.5     # 混出
)

# 设置循环和延迟
idle_loop.loop = true
idle_loop.loop_delay = 2.0  # 每次循环后等待2秒

# 播放循环待机动画
var context_id = JuicyMixer.play(idle_loop, get_node("."))
```

### 2.2 时间缩放控制

```gdscript
# 创建受时间缩放影响的动画
var time_controlled = JuicyAnimationPlayResource.new()

# 使用SYNC模式，受时间缩放影响
time_controlled.add_animation_data(
    NodePath("../Character"),
    "run",
    AnimationPlayData.PlayMode.SYNC,  # 关键：使用SYNC模式
    1.0,
    0.1,
    0.1
)

# 播放并应用时间缩放
var context_id = JuicyMixer.play(time_controlled, get_node("."))
var context = JuicyMixer.get_context(context_id)

# 设置时间缩放为0.5（慢动作）
context.time_scale = 0.5

# 稍后恢复正常速度
await get_tree().create_timer(2.0).timeout
context.time_scale = 1.0

# 快进播放
await get_tree().create_timer(2.0).timeout
context.time_scale = 2.0
```

### 2.3 动态目标节点

```gdscript
# 创建支持动态目标的动画资源
func play_animation_on_target(target_node: Node, animation_name: String):
    var resource = JuicyAnimationPlayResource.new()
    
    # 动态创建目标路径
    var target_path = get_path_to(target_node)
    
    resource.add_animation_data(
        NodePath(target_path),
        animation_name,
        AnimationPlayData.PlayMode.NORMAL,
        1.0,
        0.1,
        0.1
    )
    
    return JuicyMixer.play(resource, self)

# 使用示例
var enemy = get_node("../Enemies/Enemy1")
var context_id = play_animation_on_target(enemy, "hurt")
```

## 3. 实际游戏场景示例

### 3.1 角色攻击系统

```gdscript
# CharacterAttack.gd
extends Node

class_name CharacterAttack

# 预定义的攻击动画序列
var attack_sequences = {
    "light_attack": preload("res://animations/light_attack_sequence.tres"),
    "heavy_attack": preload("res://animations/heavy_attack_sequence.tres"),
    "special_attack": preload("res://animations/special_attack_sequence.tres")
}

func perform_attack(attack_type: String, target: Node):
    var sequence_resource = attack_sequences.get(attack_type)
    if not sequence_resource:
        push_error("Attack sequence not found: " + attack_type)
        return
    
    # 播放攻击动画
    var context_id = JuicyMixer.play(sequence_resource, target)
    
    # 连接攻击完成事件
    var context = JuicyMixer.get_context(context_id)
    context.connect("completed", _on_attack_completed.bind(attack_type))
    
    return context_id

func _on_attack_completed(attack_type: String):
    print("Attack completed: ", attack_type)
    # 这里可以添加攻击完成后的逻辑
    match attack_type:
        "light_attack":
            _enable_next_attack()
        "heavy_attack":
            _apply_cooldown(1.0)
        "special_attack":
            _apply_cooldown(3.0)

func _enable_next_attack():
    # 启用下一次攻击
    pass

func _apply_cooldown(duration: float):
    # 应用攻击冷却
    pass
```

### 3.2 环境动画系统

```gdscript
# EnvironmentAnimator.gd
extends Node

class_name EnvironmentAnimator

# 环境动画配置
var environment_animations = {
    "day_cycle": {
        "resource": preload("res://animations/day_cycle.tres"),
        "loop": true,
        "duration": 300.0  # 5分钟
    },
    "weather_change": {
        "resource": preload("res://animations/weather_change.tres"),
        "loop": false,
        "duration": 10.0
    }
}

func start_environment_animation(animation_name: String):
    var config = environment_animations.get(animation_name)
    if not config:
        push_error("Environment animation not found: " + animation_name)
        return
    
    var resource = config.resource.duplicate()  # 复制资源以避免修改原资源
    
    # 应用配置
    if config.has("loop"):
        resource.loop = config.loop
    
    # 播放环境动画
    var context_id = JuicyMixer.play(resource, get_tree().current_scene)
    
    print("Started environment animation: ", animation_name)
    return context_id

func start_day_night_cycle():
    # 启动日夜循环
    var context_id = start_environment_animation("day_cycle")
    
    # 设置时间缩放以加速循环（用于测试）
    var context = JuicyMixer.get_context(context_id)
    context.time_scale = 60.0  # 60倍速，5分钟变成5秒

func change_weather(new_weather: String):
    # 改变天气
    var weather_animations = {
        "sunny": "weather_to_sunny",
        "rainy": "weather_to_rainy",
        "cloudy": "weather_to_cloudy",
        "stormy": "weather_to_stormy"
    }
    
    var animation_name = weather_animations.get(new_weather)
    if animation_name:
        start_environment_animation(animation_name)
```

### 3.3 UI动画系统

```gdscript
# UIAnimator.gd
extends Node

class_name UIAnimator

# UI动画预设
var ui_animations = {
    "button_hover": {
        "target": "button",
        "animation": "hover",
        "mode": AnimationPlayData.PlayMode.SYNC,
        "duration": 0.3
    },
    "button_press": {
        "target": "button",
        "animation": "press",
        "mode": AnimationPlayData.PlayMode.NORMAL,
        "duration": 0.2
    },
    "panel_slide_in": {
        "target": "panel",
        "animation": "slide_in",
        "mode": AnimationPlayData.PlayMode.SYNC,
        "duration": 0.5
    },
    "panel_slide_out": {
        "target": "panel",
        "animation": "slide_out",
        "mode": AnimationPlayData.PlayMode.SYNC,
        "duration": 0.5
    }
}

func play_ui_animation(animation_name: String, ui_node: Node):
    var config = ui_animations.get(animation_name)
    if not config:
        push_error("UI animation not found: " + animation_name)
        return null
    
    var resource = JuicyAnimationPlayResource.new()
    
    # 添加动画数据
    resource.add_animation_data(
        ui_node.get_path(),
        config.animation,
        config.mode,
        1.0,
        0.1,
        0.1
    )
    
    # 播放UI动画
    var context_id = JuicyMixer.play(resource, ui_node)
    return context_id

func animate_button_hover(button: Button):
    play_ui_animation("button_hover", button)

func animate_button_press(button: Button):
    var context_id = play_ui_animation("button_press", button)
    
    # 等待动画完成后恢复悬停状态
    if context_id:
        var context = JuicyMixer.get_context(context_id)
        await context.completed
        animate_button_hover(button)

func show_panel_with_animation(panel: Control):
    # 先显示面板
    panel.visible = true
    
    # 播放滑入动画
    var context_id = play_ui_animation("panel_slide_in", panel)
    return context_id

func hide_panel_with_animation(panel: Control):
    var context_id = play_ui_animation("panel_slide_out", panel)
    
    # 等待动画完成后隐藏面板
    if context_id:
        var context = JuicyMixer.get_context(context_id)
        await context.completed
        panel.visible = false
```

## 4. 资源创建指南

### 4.1 在编辑器中创建资源

```gdscript
# 创建动画资源的工具脚本
@tool
extends EditorScript

func _run():
    # 创建新的动画播放资源
    var resource = JuicyAnimationPlayResource.new()
    resource.resource_name = "PlayerAttackSequence"
    resource.loop = false
    
    # 添加攻击动画序列
    var attack_start = AnimationPlayData.new()
    attack_start.target = NodePath("../Player")
    attack_start.target_animation = "attack_start"
    attack_start.play_mode = AnimationPlayData.PlayMode.NORMAL
    attack_start.end_at = 1.0
    attack_start.blend_in_time = 0.0
    attack_start.blend_out_time = 0.2
    
    var attack_loop = AnimationPlayData.new()
    attack_loop.target = NodePath("../Player")
    attack_loop.target_animation = "attack_loop"
    attack_loop.play_mode = AnimationPlayData.PlayMode.SYNC
    attack_loop.end_at = 0.8
    attack_loop.blend_in_time = 0.2
    attack_loop.blend_out_time = 0.2
    
    var attack_end = AnimationPlayData.new()
    attack_end.target = NodePath("../Player")
    attack_end.target_animation = "attack_end"
    attack_end.play_mode = AnimationPlayData.PlayMode.NORMAL
    attack_end.end_at = 1.0
    attack_end.blend_in_time = 0.2
    attack_end.blend_out_time = 0.0
    
    # 添加到资源
    resource.animation_data = [attack_start, attack_loop, attack_end]
    
    # 保存资源
    ResourceSaver.save(resource, "res://animations/player_attack_sequence.tres")
    print("Animation resource saved!")
```

### 4.2 批量创建动画资源

```gdscript
# BatchAnimationCreator.gd
@tool
extends EditorScript

func _run():
    var animations_config = [
        {
            "name": "walk_cycle",
            "target": "../Character",
            "animations": [
                {"name": "walk_start", "mode": "NORMAL", "end_at": 1.0, "blend_in": 0.0, "blend_out": 0.2},
                {"name": "walk_loop", "mode": "SYNC", "end_at": 1.0, "blend_in": 0.2, "blend_out": 0.2},
                {"name": "walk_end", "mode": "NORMAL", "end_at": 1.0, "blend_in": 0.2, "blend_out": 0.0}
            ],
            "loop": false
        },
        {
            "name": "idle_sequence",
            "target": "../Character",
            "animations": [
                {"name": "idle", "mode": "NORMAL", "end_at": 1.0, "blend_in": 0.5, "blend_out": 0.5},
                {"name": "breathe", "mode": "SYNC", "end_at": 0.8, "blend_in": 0.5, "blend_out": 0.5}
            ],
            "loop": true,
            "loop_delay": 2.0
        }
    ]
    
    for config in animations_config:
        create_animation_resource(config)

func create_animation_resource(config: Dictionary):
    var resource = JuicyAnimationPlayResource.new()
    resource.resource_name = config.name
    resource.loop = config.get("loop", false)
    resource.loop_delay = config.get("loop_delay", 0.0)
    
    for anim_config in config.animations:
        var data = AnimationPlayData.new()
        data.target = NodePath(config.target)
        data.target_animation = anim_config.name
        data.play_mode = AnimationPlayData.PlayMode.NORMAL if anim_config.mode == "NORMAL" else AnimationPlayData.PlayMode.SYNC
        data.end_at = anim_config.end_at
        data.blend_in_time = anim_config.blend_in
        data.blend_out_time = anim_config.blend_out
        
        resource.animation_data.append(data)
    
    # 保存资源
    var file_path = "res://animations/" + config.name + ".tres"
    ResourceSaver.save(resource, file_path)
    print("Created animation resource: ", file_path)
```

## 5. 性能优化技巧

### 5.1 资源复用

```gdscript
# AnimationPool.gd
extends Node

class_name AnimationPool

# 动画资源池
var resource_pool: Dictionary = {}

func get_animation_resource(name: String) -> JuicyAnimationPlayResource:
    if resource_pool.has(name):
        return resource_pool[name]
    
    # 加载资源
    var resource = load("res://animations/" + name + ".tres")
    if resource:
        resource_pool[name] = resource
        return resource
    
    return null

func play_pooled_animation(name: String, target: Node):
    var resource = get_animation_resource(name)
    if resource:
        return JuicyMixer.play(resource, target)
    return null
```

### 5.2 批量动画控制

```gdscript
# BatchAnimationController.gd
extends Node

class_name BatchAnimationController

var active_contexts: Array[String] = []

func play_batch_animation(animation_name: String, targets: Array[Node]):
    active_contexts.clear()
    
    for target in targets:
        var context_id = JuicyMixer.play_animation(animation_name, target)
        if context_id:
            active_contexts.append(context_id)
    
    return active_contexts

func pause_all_batch():
    for context_id in active_contexts:
        JuicyMixer.pause(context_id)

func resume_all_batch():
    for context_id in active_contexts:
        JuicyMixer.resume(context_id)

func stop_all_batch():
    for context_id in active_contexts:
        JuicyMixer.stop(context_id)
    active_contexts.clear()

func set_batch_time_scale(scale: float):
    for context_id in active_contexts:
        var context = JuicyMixer.get_context(context_id)
        if context:
            context.time_scale = scale
```

### 5.3 内存管理

```gdscript
# MemoryOptimizedAnimator.gd
extends Node

class_name MemoryOptimizedAnimator

# 限制同时播放的动画数量
var max_concurrent_animations: int = 10
var active_contexts: Array[String] = []

func play_with_memory_limit(resource: JuicyAnimationPlayResource, target: Node):
    # 检查是否超过限制
    if active_contexts.size() >= max_concurrent_animations:
        _cleanup_oldest_animations()
    
    var context_id = JuicyMixer.play(resource, target)
    if context_id:
        active_contexts.append(context_id)
        _connect_completion_signal(context_id)
    
    return context_id

func _cleanup_oldest_animations():
    # 清理最老的动画
    var cleanup_count = max_concurrent_animations // 2
    for i in range(cleanup_count):
        if active_contexts.size() > 0:
            var oldest_context = active_contexts.pop_front()
            JuicyMixer.stop(oldest_context)

func _connect_completion_signal(context_id: String):
    var context = JuicyMixer.get_context(context_id)
    if context:
        context.connect("completed", _on_animation_completed.bind(context_id))

func _on_animation_completed(context_id: String):
    active_contexts.erase(context_id)
```

## 6. 调试和测试

### 6.1 动画调试工具

```gdscript
# AnimationDebugger.gd
extends Node

class_name AnimationDebugger

func debug_animation_play(resource: JuicyAnimationPlayResource, target: Node):
    print("=== Animation Debug Info ===")
    print("Resource: ", resource.resource_name)
    print("Target: ", target.name)
    print("Animation Count: ", resource.animation_data.size())
    print("Loop: ", resource.loop)
    print("Loop Delay: ", resource.loop_delay)
    
    for i in range(resource.animation_data.size()):
        var data = resource.animation_data[i]
        print("Animation %d: %s (Mode: %s, End: %.2f)" % [
            i, data.target_animation, 
            "NORMAL" if data.play_mode == AnimationPlayData.PlayMode.NORMAL else "SYNC",
            data.end_at
        ])
    
    var context_id = JuicyMixer.play(resource, target)
    _monitor_animation(context_id)
    
    return context_id

func _monitor_animation(context_id: String):
    var context = JuicyMixer.get_context(context_id)
    if not context:
        return
    
    var timer = Timer.new()
    timer.wait_time = 0.1
    timer.timeout.connect(_print_animation_status.bind(context_id))
    timer.autostart = true
    add_child(timer)
    
    # 连接完成信号
    context.connect("completed", _on_debug_animation_completed.bind(context_id, timer))

func _print_animation_status(context_id: String):
    var context = JuicyMixer.get_context(context_id)
    if context:
        print("Animation Status - Progress: %.2f, Time Scale: %.2f" % [
            context.progress, context.time_scale
        ])

func _on_debug_animation_completed(context_id: String, timer: Timer):
    print("Animation completed: ", context_id)
    timer.queue_free()
```

### 6.2 单元测试示例

```gdscript
# TestAnimationPlay.gd
extends "res://addons/gut/test.gd"

class_name TestAnimationPlay

var test_node: Node2D
var animation_player: AnimationPlayer

func before_each():
    # 创建测试节点
    test_node = Node2D.new()
    add_child(test_node)
    
    # 创建AnimationPlayer
    animation_player = AnimationPlayer.new()
    test_node.add_child(animation_player)
    
    # 创建测试动画
    var animation = Animation.new()
    animation.length = 1.0
    animation_player.add_animation("test", animation)

func test_basic_animation_play():
    # 创建动画资源
    var resource = JuicyAnimationPlayResource.new()
    resource.add_animation_data(
        test_node.get_path(),
        "test",
        AnimationPlayData.PlayMode.NORMAL,
        1.0,
        0.1,
        0.1
    )
    
    # 播放动画
    var context_id = JuicyMixer.play(resource, test_node)
    assert_not_null(context_id)
    
    # 验证动画正在播放
    await get_tree().create_timer(0.5).timeout
    assert_true(animation_player.is_playing())

func test_sync_mode_time_scale():
    # 创建SYNC模式动画
    var resource = JuicyAnimationPlayResource.new()
    resource.add_animation_data(
        test_node.get_path(),
        "test",
        AnimationPlayData.PlayMode.SYNC,
        1.0,
        0.1,
        0.1
    )
    
    # 播放动画并设置时间缩放
    var context_id = JuicyMixer.play(resource, test_node)
    var context = JuicyMixer.get_context(context_id)
    context.time_scale = 0.5  # 慢动作
    
    # 等待动画完成（应该需要2秒而不是1秒）
    await get_tree().create_timer(2.5).timeout
    assert_false(animation_player.is_playing())

func test_loop_animation():
    # 创建循环动画
    var resource = JuicyAnimationPlayResource.new()
    resource.loop = true
    resource.loop_delay = 0.5
    resource.add_animation_data(
        test_node.get_path(),
        "test",
        AnimationPlayData.PlayMode.NORMAL,
        1.0,
        0.1,
        0.1
    )
    
    # 播放动画
    var context_id = JuicyMixer.play(resource, test_node)
    
    # 等待多个循环
    await get_tree().create_timer(3.0).timeout
    assert_true(animation_player.is_playing())  # 应该还在播放
    
    # 停止动画
    JuicyMixer.stop(context_id)
    assert_false(animation_player.is_playing())

func after_each():
    # 清理测试节点
    if test_node:
        test_node.queue_free()
```

## 7. 最佳实践

### 7.1 资源组织

```
res://animations/
├── characters/
│   ├── player/
│   │   ├── attack_sequence.tres
│   │   ├── walk_cycle.tres
│   │   └── idle_sequence.tres
│   └── enemies/
│       ├── goblin_attack.tres
│       └── dragon_breath.tres
├── ui/
│   ├── button_hover.tres
│   ├── panel_transitions.tres
│   └── menu_animations.tres
├── environment/
│   ├── day_cycle.tres
│   ├── weather_effects.tres
│   └── ambient_animations.tres
└── effects/
    ├── explosions.tres
    ├── magic_spells.tres
    └── particle_triggers.tres
```

### 7.2 命名约定

```gdscript
# 资源命名
character_attack_light
character_attack_heavy
character_walk_cycle
character_idle_breathe
ui_button_hover
ui_button_press
ui_panel_slide_in
ui_panel_slide_out
env_day_cycle
env_weather_rain
fx_explosion_small
fx_spell_fireball

# 变量命名
var attack_animation_resource: JuicyAnimationPlayResource
var walk_context_id: String
var current_animation_state: AnimationPlayState
```

### 7.3 错误处理

```gdscript
func safe_play_animation(resource: JuicyAnimationPlayResource, target: Node) -> String:
    # 验证资源
    var validation = resource.validate_config()
    if not validation.valid:
        push_error("Animation resource validation failed: " + str(validation.issues))
        return ""
    
    # 验证目标
    if not target:
        push_error("Target node is null")
        return ""
    
    # 播放动画
    var context_id = JuicyMixer.play(resource, target)
    if context_id.is_empty():
        push_error("Failed to play animation")
        return ""
    
    return context_id
```

这些示例和指南提供了使用JuicyAnimationPlay系统的完整参考，从基本用法到高级技巧，涵盖了实际游戏开发中的各种场景。