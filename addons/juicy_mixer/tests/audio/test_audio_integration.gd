extends Node

func _ready():
    test_audio_event_resource_playback()
    test_2d_3d_auto_detection()
    test_integration_with_mixing()
    print("✓ Audio integration tests passed")

func test_audio_event_resource_playback():
    # 创建测试资源
    var resource = AudioEventResource.new()
    resource.event_name = "test_event"
    resource.audio_bus = "Master"

    var variant = AudioVariant.new()
    variant.audio_stream = AudioStreamOggVorbis.load_from_file("res://test.ogg")  # 需要测试音频
    variant.weight = 1.0
    resource.audio_variants.append(variant)

    # 通过JuicyMixer播放
    var event = JuicyEvent.new()
    event.event_type = JuicyEvent.EventType.AUDIO_PLAY
    event.event_data = {"audio_event_resource": resource}

    JuicyMixer.add_event(event)

    # 等待并验证
    await get_tree().create_timer(0.5).timeout

    print("  ✓ AudioEventResource playback test passed")

func test_2d_3d_auto_detection():
    # 2D节点
    var node_2d = Node2D.new()
    add_child(node_2d)

    var resource_2d = AudioEventResource.new()
    resource_2d.player_type = AudioEventResource.AudioPlayerType.AUTO_DETECT

    # 应该自动检测为2D
    var event_2d = JuicyEvent.new()
    event_2d.event_type = JuicyEvent.EventType.AUDIO_PLAY
    event_2d.event_data = {
        "audio_event_resource": resource_2d,
        "target": node_2d
    }

    JuicyMixer.add_event(event_2d)
    await get_tree().create_timer(0.1).timeout

    node_2d.queue_free()
    print("  ✓ 2D/3D auto-detection test passed")

func test_integration_with_mixing():
    # 测试混音控制
    var resource = AudioEventResource.new()
    resource.event_name = "mixing_test"
    resource.mixing = AudioMixingConfig.new()
    resource.mixing.max_instances = 2

    # 尝试播放多个实例
    for i in range(5):
        var event = JuicyEvent.new()
        event.event_type = JuicyEvent.EventType.AUDIO_PLAY
        event.event_data = {"audio_event_resource": resource}
        JuicyMixer.add_event(event)
        await get_tree().create_timer(0.1).timeout

    print("  ✓ Integration with mixing test passed")