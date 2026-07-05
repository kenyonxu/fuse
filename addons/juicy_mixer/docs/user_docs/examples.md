# JuicyMixer 游戏开发示例集

## 概述

本文档提供了完整的游戏开发场景示例，展示如何在实际项目中使用JuicyMixer序列系统。每个示例都包含完整的代码实现和详细说明，可以直接集成到您的游戏中。

## 示例1：动作游戏战斗系统

### 场景描述
一个2D动作游戏的战斗系统，包含不同类型的攻击、受击反馈和技能效果。

### 完整实现

```gdscript
# CombatEffects.gd - 战斗效果管理器
class_name CombatEffects
extends Node

# 预加载的资源
var attack_sequences: Dictionary = {}
var hit_sequences: Dictionary = {}
var skill_sequences: Dictionary = {}

func _ready():
    _load_sequences()

func _load_sequences():
    # 攻击序列
    attack_sequences["light_punch"] = preload("res://sequences/combat/light_punch.tres")
    attack_sequences["heavy_slash"] = preload("res://sequences/combat/heavy_slash.tres")
    attack_sequences["quick_thrust"] = preload("res://sequences/combat/quick_thrust.tres")
    
    # 受击序列
    hit_sequences["light_damage"] = preload("res://sequences/combat/light_damage.tres")
    hit_sequences["heavy_damage"] = preload("res://sequences/combat/heavy_damage.tres")
    hit_sequences["critical_damage"] = preload("res://sequences/combat/critical_damage.tres")
    
    # 技能序列
    skill_sequences["fireball"] = preload("res://sequences/skills/fireball.tres")
    skill_sequences["ice_shard"] = preload("res://sequences/skills/ice_shard.tres")
    skill_sequences["lightning_strike"] = preload("res://sequences/skills/lightning_strike.tres")

# 执行攻击效果
func play_attack(attack_type: String, attacker: Node, target: Node = null):
    var sequence = attack_sequences.get(attack_type)
    if not sequence:
        push_warning("未找到攻击序列: " + attack_type)
        return ""
    
    # 设置目标为攻击者本身（攻击动作）
    var context_id = JuicyMixer.play(sequence, attacker)
    
    # 如果有目标，创建受击效果
    if target:
        _schedule_hit_effect(attack_type, target, 0.3)  # 0.3秒后触发受击
    
    return context_id

# 执行受击效果
func play_hit(damage_type: String, target: Node):
    var sequence = hit_sequences.get(damage_type)
    if not sequence:
        push_warning("未找到受击序列: " + damage_type)
        return ""
    
    return JuicyMixer.play(sequence, target)

# 执行技能效果
func play_skill(skill_name: String, caster: Node, target: Node = null):
    var sequence = skill_sequences.get(skill_name)
    if not sequence:
        push_warning("未找到技能序列: " + skill_name)
        return ""
    
    var context_id = JuicyMixer.play(sequence, caster)
    
    # 技能通常有飞行时间，延迟触发目标效果
    if target:
        var skill_delay = _get_skill_delay(skill_name)
        _schedule_skill_impact(skill_name, target, skill_delay)
    
    return context_id

# 计划受击效果
func _schedule_hit_effect(attack_type: String, target: Node, delay: float):
    await get_tree().create_timer(delay).timeout
    var damage_type = _get_damage_type(attack_type)
    play_hit(damage_type, target)

# 计划技能冲击效果
func _schedule_skill_impact(skill_name: String, target: Node, delay: float):
    await get_tree().create_timer(delay).timeout
    var impact_sequence = _get_impact_sequence(skill_name)
    if impact_sequence:
        JuicyMixer.play(impact_sequence, target)

# 获取伤害类型
func _get_damage_type(attack_type: String) -> String:
    match attack_type:
        "light_punch", "quick_thrust":
            return "light_damage"
        "heavy_slash":
            return "heavy_damage"
        _:
            return "light_damage"

# 获取技能延迟
func _get_skill_delay(skill_name: String) -> float:
    match skill_name:
        "fireball":
            return 0.8
        "ice_shard":
            return 0.5
        "lightning_strike":
            return 0.2
        _:
            return 0.5

# 获取技能冲击序列
func _get_impact_sequence(skill_name: String) -> JuicySequenceResource:
    match skill_name:
        "fireball":
            return preload("res://sequences/skills/fireball_impact.tres")
        "ice_shard":
            return preload("res://sequences/skills/ice_shard_impact.tres")
        "lightning_strike":
            return preload("res://sequences/skills/lightning_impact.tres")
        _:
            return null
```

### 序列资源示例

```gdscript
# light_punch.tres - 轻拳攻击序列
[gd_script class="JuicySequenceResource" resource_path="res://sequences/combat/light_punch.tres"]

resource_name = "Light Punch Attack"
sequence_items = [{
    "resource": preload("res://effects/character/forward_lunge.tres"),
    "delay": 0.0,
    "duration": 0.2,
    "enabled": true,
    "trigger_mode": 0
}, {
    "resource": preload("res://effects/character/fist_trail.tres"),
    "delay": 0.1,
    "duration": 0.3,
    "enabled": true,
    "trigger_mode": 0
}, {
    "resource": preload("res://effects/audio/punch_swing.tres"),
    "delay": 0.05,
    "duration": 0.2,
    "enabled": true,
    "trigger_mode": 0
}]

parallel = false
random_order = false
loop_sequence = false
loop_count = -1
shuffle_items = false
enable_event_sync = false
global_event_listeners = []
event_timeout = 10.0
```

### 使用示例

```gdscript
# Player.gd - 玩家控制器
extends CharacterBody2D

@onready var combat_effects = $CombatEffects

func _input(event):
    if event.is_action_pressed("light_attack"):
        combat_effects.play_attack("light_punch", self)
    elif event.is_action_pressed("heavy_attack"):
        combat_effects.play_attack("heavy_slash", self)
    elif event.is_action_pressed("fireball"):
        combat_effects.play_skill("fireball", self, get_nearest_enemy())

func take_damage(damage: int, damage_type: String = "light"):
    combat_effects.play_hit(damage_type, self)
    health -= damage
    if health <= 0:
        _on_death()
```

## 示例2：RPG游戏UI反馈系统

### 场景描述
一个RPG游戏的UI系统，包含按钮交互、菜单动画、状态更新等反馈效果。

### 完整实现

```gdscript
# UIEffects.gd - UI效果管理器
class_name UIEffects
extends Node

# UI序列缓存
var button_sequences: Dictionary = {}
var menu_sequences: Dictionary = {}
var status_sequences: Dictionary = {}

func _ready():
    _load_ui_sequences()

func _load_ui_sequences():
    # 按钮效果
    button_sequences["hover"] = preload("res://sequences/ui/button_hover.tres")
    button_sequences["press"] = preload("res://sequences/ui/button_press.tres")
    button_sequences["disable"] = preload("res://sequences/ui/button_disable.tres")
    
    # 菜单效果
    menu_sequences["open"] = preload("res://sequences/ui/menu_open.tres")
    menu_sequences["close"] = preload("res://sequences/ui/menu_close.tres")
    menu_sequences["switch_tab"] = preload("res://sequences/ui/switch_tab.tres")
    
    # 状态效果
    status_sequences["level_up"] = preload("res://sequences/ui/level_up.tres")
    status_sequences["achievement"] = preload("res://sequences/ui/achievement.tres")
    status_sequences["quest_complete"] = preload("res://sequences/ui/quest_complete.tres")

# 按钮悬停效果
func play_button_hover(button: Button):
    var sequence = button_sequences["hover"]
    if sequence:
        JuicyMixer.play(sequence, button)

# 按钮按下效果
func play_button_press(button: Button):
    var sequence = button_sequences["press"]
    if sequence:
        JuicyMixer.play(sequence, button)

# 菜单打开效果
func play_menu_open(menu: Control):
    var sequence = menu_sequences["open"]
    if sequence:
        # 先设置菜单为不可见，然后播放动画
        menu.modulate.a = 0.0
        menu.visible = true
        JuicyMixer.play(sequence, menu)

# 菜单关闭效果
func play_menu_close(menu: Control, callback: Callable = Callable()):
    var sequence = menu_sequences["close"]
    if sequence:
        var context_id = JuicyMixer.play(sequence, menu)
        # 等待动画完成后隐藏菜单
        if not callback.is_null():
            _wait_for_sequence_complete(context_id, callback)

# 升级效果
func play_level_up(player_panel: Control):
    var sequence = status_sequences["level_up"]
    if sequence:
        JuicyMixer.play(sequence, player_panel)

# 成就解锁效果
func play_achievement(achievement_panel: Control):
    var sequence = status_sequences["achievement"]
    if sequence:
        JuicyMixer.play(sequence, achievement_panel)

# 等待序列完成
func _wait_for_sequence_complete(context_id: String, callback: Callable):
    if context_id.is_empty():
        callback.call()
        return
    
    var timer = Timer.new()
    timer.wait_time = 0.1
    timer.timeout.connect(_check_sequence_complete.bind(context_id, callback, timer))
    add_child(timer)
    timer.start()

func _check_sequence_complete(context_id: String, callback: Callable, timer: Timer):
    timer.queue_free()
    
    var context = JuicyMixer.get_context(context_id)
    if not context or context.is_completed:
        callback.call()
    else:
        _wait_for_sequence_complete(context_id, callback)
```

### 增强按钮组件

```gdscript
# EnhancedButton.gd - 增强按钮
class_name EnhancedButton
extends Button

@export var hover_enabled: bool = true
@export var press_enabled: bool = true
@export var sound_enabled: bool = true

var ui_effects: UIEffects

func _ready():
    ui_effects = UIEffects.new()
    add_child(ui_effects)
    
    if hover_enabled:
        mouse_entered.connect(_on_mouse_entered)
        mouse_exited.connect(_on_mouse_exited)
    
    if press_enabled:
        button_down.connect(_on_button_down)
        button_up.connect(_on_button_up)

func _on_mouse_entered():
    if hover_enabled and disabled == false:
        ui_effects.play_button_hover(self)

func _on_mouse_exited():
    # 可以添加离开效果
    pass

func _on_button_down():
    if press_enabled and disabled == false:
        ui_effects.play_button_press(self)

func _on_button_up():
    # 可以添加释放效果
    pass

func set_disabled_no_effect(disabled: bool):
    # 禁用按钮但不播放效果
    self.disabled = disabled
```

### 使用示例

```gdscript
# MainMenu.gd - 主菜单
extends Control

@onready var ui_effects = $UIEffects
@onready var start_button = $VBoxContainer/StartButton
@onready var options_button = $VBoxContainer/OptionsButton
@onready var exit_button = $VBoxContainer/ExitButton
@onready var options_menu = $OptionsMenu

func _ready():
    # 连接按钮信号
    start_button.pressed.connect(_on_start_pressed)
    options_button.pressed.connect(_on_options_pressed)
    exit_button.pressed.connect(_on_exit_pressed)

func _on_start_pressed():
    ui_effects.play_button_press(start_button)
    # 延迟加载游戏场景
    await get_tree().create_timer(0.3).timeout
    get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_options_pressed():
    ui_effects.play_button_press(options_button)
    ui_effects.play_menu_open(options_menu)

func _on_exit_pressed():
    ui_effects.play_button_press(exit_button)
    get_tree().quit()

func _on_options_back_pressed():
    ui_effects.play_menu_close(options_menu, _on_options_menu_closed)

func _on_options_menu_closed():
    options_menu.visible = false
```

## 示例3：平台游戏环境互动系统

### 场景描述
一个2D平台游戏，包含环境破坏、道具收集、机关触发等互动效果。

### 完整实现

```gdscript
# EnvironmentEffects.gd - 环境效果管理器
class_name EnvironmentEffects
extends Node

# 环境序列
var destruction_sequences: Dictionary = {}
var collect_sequences: Dictionary = {}
var mechanism_sequences: Dictionary = {}

func _ready():
    _load_environment_sequences()

func _load_environment_sequences():
    # 破坏效果
    destruction_sequences["crate_break"] = preload("res://sequences/environment/crate_break.tres")
    destruction_sequences["wall_collapse"] = preload("res://sequences/environment/wall_collapse.tres")
    destruction_sequences["glass_shatter"] = preload("res://sequences/environment/glass_shatter.tres")
    
    # 收集效果
    collect_sequences["coin"] = preload("res://sequences/environment/coin_collect.tres")
    collect_sequences["gem"] = preload("res://sequences/environment/gem_collect.tres")
    collect_sequences["powerup"] = preload("res://sequences/environment/powerup_collect.tres")
    
    # 机关效果
    mechanism_sequences["switch_activate"] = preload("res://sequences/environment/switch_activate.tres")
    mechanism_sequences["door_open"] = preload("res://sequences/environment/door_open.tres")
    mechanism_sequences["platform_rise"] = preload("res://sequences/environment/platform_rise.tres")

# 破坏物体
func destroy_object(object_type: String, object_node: Node):
    var sequence = destruction_sequences.get(object_type)
    if sequence:
        var context_id = JuicyMixer.play(sequence, object_node)
        
        # 等待破坏动画完成后隐藏或删除物体
        _wait_and_destroy(object_node, context_id)
        
        return context_id
    return ""

# 收集道具
func collect_item(item_type: String, item_node: Node, player: Node):
    var sequence = collect_sequences.get(item_type)
    if sequence:
        # 播放收集效果
        var context_id = JuicyMixer.play(sequence, item_node)
        
        # 给玩家添加收集反馈
        _give_player_feedback(item_type, player)
        
        # 等待收集动画完成后移除道具
        _wait_and_collect(item_node, context_id)
        
        return context_id
    return ""

# 激活机关
func activate_mechanism(mechanism_type: String, mechanism_node: Node, affected_objects: Array = []):
    var sequence = mechanism_sequences.get(mechanism_type)
    if sequence:
        var context_id = JuicyMixer.play(sequence, mechanism_node)
        
        # 处理受影响的物体
        for obj in affected_objects:
            _handle_affected_object(mechanism_type, obj)
        
        return context_id
    return ""

# 等待并销毁物体
func _wait_and_destroy(object_node: Node, context_id: String):
    if context_id.is_empty():
        object_node.queue_free()
        return
    
    var timer = Timer.new()
    timer.wait_time = 0.1
    timer.timeout.connect(_check_destruction_complete.bind(object_node, context_id, timer))
    add_child(timer)
    timer.start()

func _check_destruction_complete(object_node: Node, context_id: String, timer: Timer):
    timer.queue_free()
    
    var context = JuicyMixer.get_context(context_id)
    if not context or context.is_completed:
        object_node.queue_free()
    else:
        _wait_and_destroy(object_node, context_id)

# 等待并收集道具
func _wait_and_collect(item_node: Node, context_id: String):
    if context_id.is_empty():
        item_node.queue_free()
        return
    
    var timer = Timer.new()
    timer.wait_time = 0.1
    timer.timeout.connect(_check_collection_complete.bind(item_node, context_id, timer))
    add_child(timer)
    timer.start()

func _check_collection_complete(item_node: Node, context_id: String, timer: Timer):
    timer.queue_free()
    
    var context = JuicyMixer.get_context(context_id)
    if not context or context.is_completed:
        item_node.queue_free()
    else:
        _wait_and_collect(item_node, context_id)

# 给玩家反馈
func _give_player_feedback(item_type: String, player: Node):
    match item_type:
        "coin":
            # 播放金币收集音效
            var sound_effect = preload("res://effects/audio/coin_sound.tres")
            JuicyMixer.play(sound_effect, player)
        "gem":
            # 播放宝石收集特效
            var gem_effect = preload("res://effects/player/gem_glow.tres")
            JuicyMixer.play(gem_effect, player)
        "powerup":
            # 播放能力提升效果
            var powerup_effect = preload("res://effects/player/powerup_aura.tres")
            JuicyMixer.play(powerup_effect, player)

# 处理受影响的物体
func _handle_affected_object(mechanism_type: String, obj: Node):
    match mechanism_type:
        "switch_activate":
            if obj.has_method("activate"):
                obj.activate()
        "door_open":
            if obj.has_method("open"):
                obj.open()
        "platform_rise":
            if obj.has_method("rise"):
                obj.rise()
```

### 可破坏物体组件

```gdscript
# DestructibleObject.gd - 可破坏物体
class_name DestructibleObject
extends Node2D

@export var object_type: String = "crate_break"
@export var health: int = 1
@export var destroy_on_touch: bool = false

var environment_effects: EnvironmentEffects

func _ready():
    environment_effects = EnvironmentEffects.new()
    add_child(environment_effects)

func take_damage(damage: int):
    health -= damage
    if health <= 0:
        destroy()

func destroy():
    environment_effects.destroy_object(object_type, self)

func _on_body_entered(body):
    if destroy_on_touch and body.is_in_group("player"):
        destroy()
```

### 收集道具组件

```gdscript
# CollectibleItem.gd - 可收集道具
class_name CollectibleItem
extends Node2D

@export var item_type: String = "coin"
@export var value: int = 1
@export var auto_collect: bool = false

var environment_effects: EnvironmentEffects
var collected: bool = false

func _ready():
    environment_effects = EnvironmentEffects.new()
    add_child(environment_effects)

func collect(collector: Node):
    if collected:
        return
    
    collected = true
    
    # 通知收集者
    if collector.has_method("collect_item"):
        collector.collect_item(item_type, value)
    
    # 播放收集效果
    environment_effects.collect_item(item_type, self, collector)

func _on_body_entered(body):
    if body.is_in_group("player") and not collected:
        collect(body)

func _on_area_entered(area):
    if auto_collect and area.get_parent().is_in_group("player") and not collected:
        collect(area.get_parent())
```

## 示例4：音乐节奏游戏系统

### 场景描述
一个音乐节奏游戏，需要精确的时序控制和音乐同步。

### 完整实现

```gdscript
# RhythmGameManager.gd - 节奏游戏管理器
class_name RhythmGameManager
extends Node

@export var bpm: float = 120.0
@export var beat_offset: float = 0.0

var beat_interval: float
var current_beat: int = 0
var song_position: float = 0.0
var is_playing: bool = false

var rhythm_sequences: Dictionary = {}
var effect_queue: Array = []

func _ready():
    beat_interval = 60.0 / bpm
    _load_rhythm_sequences()

func _load_rhythm_sequences():
    rhythm_sequences["perfect_hit"] = preload("res://sequences/rhythm/perfect_hit.tres")
    rhythm_sequences["good_hit"] = preload("res://sequences/rhythm/good_hit.tres")
    rhythm_sequences["miss_hit"] = preload("res://sequences/rhythm/miss_hit.tres")
    rhythm_sequences["combo_effect"] = preload("res://sequences/rhythm/combo_effect.tres")
    rhythm_sequences["beat_indicator"] = preload("res://sequences/rhythm/beat_indicator.tres")

func start_music():
    is_playing = true
    current_beat = 0
    song_position = -beat_offset
    
    # 开始节拍指示器
    _start_beat_indicators()

func stop_music():
    is_playing = false

func _process(delta):
    if not is_playing:
        return
    
    song_position += delta
    
    # 检查新节拍
    var expected_beat = int(song_position / beat_interval)
    if expected_beat > current_beat:
        current_beat = expected_beat
        _on_beat(current_beat)

func _on_beat(beat_number: int):
    # 发送节拍事件
    var beat_event = JuicyEvent.create_custom_event("beat_" + str(beat_number % 4 + 1), self, {
        "beat_number": beat_number,
        "song_position": song_position,
        "bpm": bpm
    })
    JuicyMixer.add_event(beat_event)
    
    # 处理效果队列
    _process_effect_queue()

# 处理节奏输入
func handle_rhythm_input(timing_accuracy: float):
    var hit_quality = _evaluate_hit_quality(timing_accuracy)
    
    match hit_quality:
        "perfect":
            _play_hit_effect("perfect_hit")
            _increase_combo()
        "good":
            _play_hit_effect("good_hit")
            _increase_combo()
        "miss":
            _play_hit_effect("miss_hit")
            _reset_combo()

# 评估打击质量
func _evaluate_hit_quality(timing_accuracy: float) -> String:
    var accuracy_threshold = beat_interval * 0.1  # 10%容差
    
    if abs(timing_accuracy) < accuracy_threshold:
        return "perfect"
    elif abs(timing_accuracy) < accuracy_threshold * 2:
        return "good"
    else:
        return "miss"

# 播放打击效果
func _play_hit_effect(effect_type: String):
    var sequence = rhythm_sequences.get(effect_type)
    if sequence:
        JuicyMixer.play(sequence, self)

# 增加连击
func _increase_combo():
    # 播放连击效果
    var combo_sequence = rhythm_sequences["combo_effect"]
    if combo_sequence:
        JuicyMixer.play(combo_sequence, self)

# 重置连击
func _reset_combo():
    # 可以添加连击中断效果
    pass

# 开始节拍指示器
func _start_beat_indicators():
    var indicator_sequence = rhythm_sequences["beat_indicator"]
    if indicator_sequence:
        # 创建循环的节拍指示器
        indicator_sequence.loop_sequence = true
        indicator_sequence.loop_count = -1
        JuicyMixer.play(indicator_sequence, self)

# 处理效果队列
func _process_effect_queue():
    for effect_data in effect_queue:
        if effect_data.beat == current_beat:
            _execute_queued_effect(effect_data)
    
    # 清理已执行的效果
    effect_queue = effect_queue.filter(func(data): return data.beat > current_beat)

# 执行队列中的效果
func _execute_queued_effect(effect_data: Dictionary):
    var sequence = rhythm_sequences.get(effect_data.effect_type)
    if sequence and effect_data.target:
        JuicyMixer.play(sequence, effect_data.target)

# 添加效果到队列
func queue_effect_at_beat(effect_type: String, target: Node, beat: int):
    effect_queue.append({
        "effect_type": effect_type,
        "target": target,
        "beat": beat
    })
```

### 节奏音符组件

```gdscript
# RhythmNote.gd - 节奏音符
class_name RhythmNote
extends Node2D

@export var note_type: String = "normal"
@export var target_beat: int = 0
@export var approach_time: float = 2.0

var hit_zone: Area2D
var sprite: Sprite2D
var rhythm_manager: RhythmGameManager
var hit: bool = false

func _ready():
    rhythm_manager = RhythmGameManager.instance
    _setup_note()

func _setup_note():
    # 创建音符精灵
    sprite = Sprite2D.new()
    add_child(sprite)
    
    # 根据音符类型设置纹理
    match note_type:
        "normal":
            sprite.texture = preload("res://assets/rhythm/note_normal.png")
        "special":
            sprite.texture = preload("res://assets/rhythm/note_special.png")
        "hold":
            sprite.texture = preload("res://assets/rhythm/note_hold.png")
    
    # 创建碰撞区域
    hit_zone = Area2D.new()
    var collision_shape = CollisionShape2D.new()
    var shape = CircleShape2D.new()
    shape.radius = 20.0
    collision_shape.shape = shape
    hit_zone.add_child(collision_shape)
    add_child(hit_zone)
    
    # 连接信号
    hit_zone.body_entered.connect(_on_hit_zone_entered)

func _on_hit_zone_entered(body):
    if body.is_in_group("hit_detector") and not hit:
        _register_hit()

func _register_hit():
    hit = true
    
    # 计算打击时机
    var current_beat = rhythm_manager.current_beat
    var timing_diff = abs(current_beat - target_beat)
    
    # 通知节奏管理器
    rhythm_manager.handle_rhythm_input(timing_diff)
    
    # 播放命中效果
    _play_hit_effect()
    
    # 隐藏音符
    visible = false

func _play_hit_effect():
    var hit_effect = preload("res://effects/rhythm/note_hit.tres")
    JuicyMixer.play(hit_effect, self)
```

## 示例5：竞速游戏特效系统

### 场景描述
一个竞速游戏，包含车辆特效、环境互动、速度反馈等。

### 完整实现

```gdscript
# RacingEffects.gd - 竞速效果管理器
class_name RacingEffects
extends Node

# 车辆效果序列
var vehicle_sequences: Dictionary = {}
var track_sequences: Dictionary = {}
var speed_sequences: Dictionary = {}

func _ready():
    _load_racing_sequences()

func _load_racing_sequences():
    # 车辆效果
    vehicle_sequences["engine_start"] = preload("res://sequences/racing/engine_start.tres")
    vehicle_sequences["turbo_boost"] = preload("res://sequences/racing/turbo_boost.tres")
    vehicle_sequences["drift_start"] = preload("res://sequences/racing/drift_start.tres")
    vehicle_sequences["drift_end"] = preload("res://sequences/racing/drift_end.tres")
    vehicle_sequences["collision"] = preload("res://sequences/racing/collision.tres")
    
    # 赛道效果
    track_sequences["checkpoint"] = preload("res://sequences/racing/checkpoint.tres")
    track_sequences["speed_boost"] = preload("res://sequences/racing/speed_boost.tres")
    track_sequences["oil_spill"] = preload("res://sequences/racing/oil_spill.tres")
    
    # 速度效果
    speed_sequences["speed_lines"] = preload("res://sequences/racing/speed_lines.tres")
    speed_sequences["motion_blur"] = preload("res://sequences/racing/motion_blur.tres")

# 车辆引擎启动
func play_engine_start(vehicle: Node):
    var sequence = vehicle_sequences["engine_start"]
    if sequence:
        return JuicyMixer.play(sequence, vehicle)
    return ""

# 涡轮增压
func play_turbo_boost(vehicle: Node):
    var sequence = vehicle_sequences["turbo_boost"]
    if sequence:
        # 同时播放速度线效果
        play_speed_lines(vehicle)
        return JuicyMixer.play(sequence, vehicle)
    return ""

# 开始漂移
func play_drift_start(vehicle: Node):
    var sequence = vehicle_sequences["drift_start"]
    if sequence:
        return JuicyMixer.play(sequence, vehicle)
    return ""

# 结束漂移
func play_drift_end(vehicle: Node):
    var sequence = vehicle_sequences["drift_end"]
    if sequence:
        return JuicyMixer.play(sequence, vehicle)
    return ""

# 碰撞效果
func play_collision(vehicle: Node, collision_point: Vector2, impact_force: float):
    var sequence = vehicle_sequences["collision"]
    if sequence:
        # 根据冲击力调整效果强度
        _adjust_collision_intensity(sequence, impact_force)
        return JuicyMixer.play(sequence, vehicle)
    return ""

# 通过检查点
func play_checkpoint(vehicle: Node, checkpoint_node: Node):
    var sequence = track_sequences["checkpoint"]
    if sequence:
        # 在检查点播放效果
        JuicyMixer.play(sequence, checkpoint_node)
        
        # 给车辆反馈
        var vehicle_feedback = preload("res://sequences/racing/checkpoint_feedback.tres")
        return JuicyMixer.play(vehicle_feedback, vehicle)
    return ""

# 速度提升
func play_speed_boost(vehicle: Node):
    var sequence = track_sequences["speed_boost"]
    if sequence:
        # 同时播放速度效果
        play_speed_lines(vehicle)
        play_motion_blur(vehicle)
        return JuicyMixer.play(sequence, vehicle)
    return ""

# 速度线效果
func play_speed_lines(vehicle: Node):
    var sequence = speed_sequences["speed_lines"]
    if sequence:
        return JuicyMixer.play(sequence, vehicle)
    return ""

# 动态模糊效果
func play_motion_blur(vehicle: Node):
    var sequence = speed_sequences["motion_blur"]
    if sequence:
        return JuicyMixer.play(sequence, vehicle)
    return ""

# 调整碰撞强度
func _adjust_collision_intensity(sequence: JuicySequenceResource, force: float):
    for item in sequence.sequence_items:
        if item.resource and item.resource.has_method("set_intensity"):
            item.resource.set_intensity(force)
```

### 车辆控制器

```gdscript
# RacingCar.gd - 赛车控制器
class_name RacingCar
extends Node2D

@export var max_speed: float = 500.0
@export var acceleration: float = 200.0
@export var turbo_multiplier: float = 1.5

var current_speed: float = 0.0
var is_drifting: bool = false
var turbo_active: bool = false

var racing_effects: RacingEffects

func _ready():
    racing_effects = RacingEffects.new()
    add_child(racing_effects)

func start_engine():
    racing_effects.play_engine_start(self)

func accelerate(delta: float):
    current_speed = min(current_speed + acceleration * delta, max_speed)
    _update_speed_effects()

func activate_turbo():
    if not turbo_active:
        turbo_active = true
        racing_effects.play_turbo_boost(self)
        current_speed *= turbo_multiplier
        
        # 涡轮持续一段时间
        await get_tree().create_timer(2.0).timeout
        deactivate_turbo()

func deactivate_turbo():
    turbo_active = false
    current_speed /= turbo_multiplier

func start_drift():
    if not is_drifting and current_speed > max_speed * 0.3:
        is_drifting = true
        racing_effects.play_drift_start(self)

func end_drift():
    if is_drifting:
        is_drifting = false
        racing_effects.play_drift_end(self)

func on_collision(other_object: Node, collision_point: Vector2, impact_force: float):
    racing_effects.play_collision(self, collision_point, impact_force)
    
    # 减速
    current_speed *= 0.5

func on_checkpoint_passed(checkpoint_node: Node):
    racing_effects.play_checkpoint(self, checkpoint_node)

func on_speed_boost_pad():
    racing_effects.play_speed_boost(self)
    current_speed = min(current_speed * 1.2, max_speed * 1.1)

func _update_speed_effects():
    # 根据速度调整效果强度
    var speed_ratio = current_speed / max_speed
    
    if speed_ratio > 0.7 and not turbo_active:
        # 高速时显示速度线
        racing_effects.play_speed_lines(self)
    
    if speed_ratio > 0.9:
        # 极速时添加动态模糊
        racing_effects.play_motion_blur(self)
```

## 总结

这些示例展示了JuicyMixer序列系统在不同游戏类型中的实际应用：

### 关键要点

1. **模块化设计**：每个效果管理器负责特定类型的效果
2. **资源预加载**：在游戏启动时预加载所有序列资源
3. **状态管理**：正确处理效果的开始、进行和结束状态
4. **性能优化**：合理使用对象池和批处理
5. **错误处理**：始终验证资源和目标的有效性

### 扩展建议

1. **配置文件**：使用JSON或XML配置文件定义序列参数
2. **可视化编辑器**：创建序列编辑工具，方便设计师调整效果
3. **性能分析**：集成性能监控，实时优化效果表现
4. **平台适配**：根据不同平台性能调整效果质量
5. **本地化**：支持不同地区的音效和视觉偏好

通过这些示例，开发者可以快速理解如何在实际项目中应用JuicyMixer序列系统，创造出丰富而流畅的游戏体验。