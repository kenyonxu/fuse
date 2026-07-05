extends Control

## 音频管理器演示场景控制器

@onready var label_status = $VBoxContainer/LabelStatus
@onready var button_footstep = $VBoxContainer/ButtonFootstep
@onready var button_explosion = $VBoxContainer/ButtonExplosion
@onready var button_dialogue = $VBoxContainer/ButtonDialogue
@onready var button_clear = $VBoxContainer/ButtonClear

var footstep_resource: AudioEventResource = null
var explosion_resource: AudioEventResource = null
var dialogue_resource: AudioEventResource = null

func _ready():
    _setup_audio_resources()
    _connect_buttons()
    _update_status()

func _setup_audio_resources():
    # 脚步声资源（多变体 + 随机化）
    footstep_resource = AudioEventResource.new()
    footstep_resource.event_name = "footstep"
    footstep_resource.audio_bus = "SFX"
    footstep_resource.no_repeat_enabled = true
    footstep_resource.no_repeat_memory = 2

    # 添加变体（需要实际音频文件）
    for i in range(3):
        var variant = AudioVariant.new()
        # variant.audio_stream = load("res://sounds/footstep_%d.ogg" % (i + 1))
        variant.weight = 1.0
        variant.pitch_enabled = true
        variant.pitch_min = -0.2
        variant.pitch_max = 0.2
        variant.volume_enabled = true
        variant.volume_min = 0.9
        variant.volume_max = 1.1
        footstep_resource.audio_variants.append(variant)

    # 爆炸资源（类别限额）
    explosion_resource = AudioEventResource.new()
    explosion_resource.event_name = "explosion"
    explosion_resource.audio_bus = "SFX"
    explosion_resource.mixing = AudioMixingConfig.new()
    explosion_resource.mixing.max_instances = 3

    # 对白资源（鸭霸音乐）
    dialogue_resource = AudioEventResource.new()
    dialogue_resource.event_name = "dialogue"
    dialogue_resource.audio_bus = "Voice"
    dialogue_resource.mixing = AudioMixingConfig.new()

    var ducking_rule = DuckingRule.new()
    ducking_rule.event_name_pattern = "dialogue_*"
    ducking_rule.target_bus = "Music"
    ducking_rule.duck_amount = -10.0
    ducking_rule.recovery_delay = 0.5
    dialogue_resource.mixing.ducking_rules.append(ducking_rule)

func _connect_buttons():
    button_footstep.pressed.connect(_on_footstep_pressed)
    button_explosion.pressed.connect(_on_explosion_pressed)
    button_dialogue.pressed.connect(_on_dialogue_pressed)
    button_clear.pressed.connect(_on_clear_pressed)

func _on_footstep_pressed():
    if footstep_resource and not footstep_resource.audio_variants.is_empty():
        var event = JuicyEvent.new()
        event.event_type = JuicyEvent.EventType.AUDIO_PLAY
        event.event_data = {"audio_event_resource": footstep_resource}
        JuicyMixer.add_event(event)
        _update_status()

func _on_explosion_pressed():
    if explosion_resource:
        var event = JuicyEvent.new()
        event.event_type = JuicyEvent.EventType.AUDIO_PLAY
        event.event_data = {"audio_event_resource": explosion_resource}
        JuicyMixer.add_event(event)
        _update_status()

func _on_dialogue_pressed():
    if dialogue_resource:
        var event = JuicyEvent.new()
        event.event_type = JuicyEvent.EventType.AUDIO_PLAY
        event.event_data = {"audio_event_resource": dialogue_resource}
        JuicyMixer.add_event(event)
        _update_status()

func _on_clear_pressed():
    # 清理所有音频
    _update_status()

func _update_status():
    # 获取统计信息
    label_status.text = "Audio Manager Demo\n\nStatus: Running\n\nClick buttons to test different audio features."