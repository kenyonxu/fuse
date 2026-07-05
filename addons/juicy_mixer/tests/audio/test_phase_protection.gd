extends Node

## 相位保护测试
##
## 测试高频重复音效的相位保护机制

func test_phase_cooldown_blocks_fast_repeats():
    print("\n=== 测试相位冷却阻止快速重复 ===")

    var resource = AudioEventResource.new()
    resource.event_name = "test_phase"
    resource.anti_phase_cancellation = true
    resource.phase_cooldown = 0.1  # 100ms

    var config = AudioMixingConfig.new()
    config.max_instances = 10
    resource.mixing = config

    var controller = AudioMixingController.new()

    # 第一次播放应该通过
    var result1 = controller.can_play(resource, "test_phase")
    assert(result1 == true, "First play should pass")
    print("✓ 第一次播放通过")

    # 立即第二次播放应该被阻止
    var result2 = controller.can_play(resource, "test_phase")
    assert(result2 == false, "Immediate second play should be blocked")
    print("✓ 立即第二次播放被阻止")

    # 等待冷却时间后应该可以通过
    await get_tree().create_timer(0.15).timeout  # 等待 150ms
    var result3 = controller.can_play(resource, "test_phase")
    assert(result3 == true, "Play after cooldown should pass")
    print("✓ 冷却后播放通过")

    print("✅ test_phase_cooldown_blocks_fast_repeats PASSED\n")

func test_phase_protection_disabled():
    print("\n=== 测试禁用相位保护 ===")

    var resource = AudioEventResource.new()
    resource.event_name = "test_no_phase"
    resource.anti_phase_cancellation = false  # 禁用相位保护

    var config = AudioMixingConfig.new()
    config.max_instances = 10
    resource.mixing = config

    var controller = AudioMixingController.new()

    # 连续播放都应该通过
    var result1 = controller.can_play(resource, "test_no_phase")
    assert(result1 == true, "First play should pass")
    print("✓ 第一次播放通过")

    var result2 = controller.can_play(resource, "test_no_phase")
    assert(result2 == true, "Second play should also pass")
    print("✓ 第二次播放通过")

    var result3 = controller.can_play(resource, "test_no_phase")
    assert(result3 == true, "Third play should also pass")
    print("✓ 第三次播放通过")

    print("✅ test_phase_protection_disabled PASSED\n")

func test_phase_cooldown_precision():
    print("\n=== 测试相位冷却时间精度 ===")

    var resource = AudioEventResource.new()
    resource.event_name = "test_precision"
    resource.anti_phase_cancellation = true
    resource.phase_cooldown = 0.05  # 50ms

    var config = AudioMixingConfig.new()
    config.max_instances = 10
    resource.mixing = config

    var controller = AudioMixingController.new()

    # 第一次播放
    assert(controller.can_play(resource, "test_precision") == true)
    print("✓ 第一次播放通过")

    # 等待 30ms（应该仍被阻止）
    await get_tree().create_timer(0.03).timeout
    assert(controller.can_play(resource, "test_precision") == false)
    print("✓ 30ms 后仍被阻止")

    # 再等待 30ms（总共 60ms，应该可以通过）
    await get_tree().create_timer(0.03).timeout
    assert(controller.can_play(resource, "test_precision") == true)
    print("✓ 60ms 后可以通过")

    print("✅ test_phase_cooldown_precision PASSED\n")

func _ready():
    print("\n" + "=".repeat(50))
    print("相位保护测试套件")
    print("=".repeat(50))

    await test_phase_cooldown_blocks_fast_repeats()
    await test_phase_protection_disabled()
    await test_phase_cooldown_precision()

    print("\n" + "=".repeat(50))
    print("所有测试通过！")
    print("=".repeat(50) + "\n")
