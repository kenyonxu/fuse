extends Node

func _ready():
    test_instance_limiting()
    test_ducking()
    test_stats()
    print("✓ AudioMixingController tests passed")

func test_instance_limiting():
    var controller = AudioMixingController.new()
    var resource = AudioEventResource.new()
    resource.event_name = "test_sound"
    resource.mixing = AudioMixingConfig.new()
    resource.mixing.max_instances = 3
    resource.mixing.limit_policy = AudioMixingConfig.LimitPolicy.FIFO

    # 测试限额
    for i in range(5):
        var can_play = controller.can_play(resource, "test_sound")
        if i < 3:
            assert(can_play, "Should be able to play within limit (iteration %d)" % i)
        else:
            assert(can_play, "Should stop oldest and allow new (iteration %d)" % i)

        var player = AudioStreamPlayer2D.new()
        controller.record_instance("test_sound", player, 50)

    print("  ✓ Instance limiting test passed")

func test_ducking():
    var controller = AudioMixingController.new()
    var resource = AudioEventResource.new()
    resource.event_name = "test_sound"
    resource.mixing = AudioMixingConfig.new()

    var ducking_rule = DuckingRule.new()
    ducking_rule.event_name_pattern = "test_*"
    ducking_rule.target_bus = "Master"
    ducking_rule.duck_amount = -10.0
    ducking_rule.enabled = true

    resource.mixing.ducking_rules.append(ducking_rule)

    # 测试鸭霸
    controller.apply_ducking("test_sound", resource.mixing)
    var stats = controller.get_stats()
    assert(stats.ducking_active == 1, "Ducking should be active")

    # 测试恢复
    controller.remove_ducking("test_sound", resource.mixing)
    for i in range(100):
        controller.update_ducking(0.016)

    stats = controller.get_stats()
    assert(stats.ducking_active == 0, "Ducking should be recovered")

    print("  ✓ Ducking test passed")

func test_stats():
    var controller = AudioMixingController.new()
    var stats = controller.get_stats()

    assert(stats.has("active_instances"), "Should have active_instances stat")
    assert(stats.has("ducking_active"), "Should have ducking_active stat")

    print("  ✓ Stats test passed")