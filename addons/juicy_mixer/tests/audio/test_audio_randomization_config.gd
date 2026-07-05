@tool
extends Node

func _ready():
    test_config_creation()
    test_global_randomization()
    test_fixed_seed()
    test_disabled_state()
    test_validation()
    print("✓ AudioRandomizationConfig tests passed")

func test_config_creation():
    var config = AudioRandomizationConfig.new()
    assert(config != null, "Config should be created")
    assert(config.enabled == true, "Should be enabled by default")
    print("  ✓ Config creation test passed")

func test_global_randomization():
    var config = AudioRandomizationConfig.new()
    config.global_pitch_min = -0.3
    config.global_pitch_max = 0.3
    config.global_volume_min = 0.9
    config.global_volume_max = 1.1

    var pitch_values = []
    var volume_values = []

    for i in range(20):
        pitch_values.append(config.get_global_pitch_offset())
        volume_values.append(config.get_global_volume_offset())

    # 验证随机化范围
    for pitch in pitch_values:
        assert(pitch >= -0.3 and pitch <= 0.3, "Pitch offset should be in range")

    for volume in volume_values:
        assert(volume >= 0.9 and volume <= 1.1, "Volume offset should be in range")

    print("  ✓ Global randomization test passed")

## 测试固定种子功能
func test_fixed_seed():
    var config1 = AudioRandomizationConfig.new()
    var config2 = AudioRandomizationConfig.new()

    # 设置固定种子
    config1.random_seed = 12345
    config1.use_fixed_seed = true
    config2.random_seed = 12345
    config2.use_fixed_seed = true

    # 初始化两个配置
    config1.initialize_random()
    config2.initialize_random()

    # 使用相同种子的结果应该相同
    for i in range(10):
        var pitch1 = config1.get_global_pitch_offset()
        var pitch2 = config2.get_global_pitch_offset()
        var vol1 = config1.get_global_volume_offset()
        var vol2 = config2.get_global_volume_offset()

        # 比较前3位小数（浮点数精度问题）
        assert(abs(pitch1 - pitch2) < 0.001, "Fixed seed should produce same pitch")
        assert(abs(vol1 - vol2) < 0.001, "Fixed seed should produce same volume")

    print("  ✓ Fixed seed test passed")

## 测试禁用状态
func test_disabled_state():
    var config = AudioRandomizationConfig.new()

    # 禁用随机化
    config.enabled = false

    # 所有调用应返回默认值
    for i in range(10):
        var pitch = config.get_global_pitch_offset()
        var volume = config.get_global_volume_offset()

        assert(pitch == 0.0, "Disabled config should return 0 pitch offset")
        assert(volume == 1.0, "Disabled config should return 1 volume offset")

    print("  ✓ Disabled state test passed")

## 测试验证方法
func test_validation():
    var config = AudioRandomizationConfig.new()

    # 测试正常配置
    var result = config.validate()
    assert(result.valid == true, "Normal config should be valid")
    assert(result.issues.size() == 0, "Normal config should have no issues")

    # 测试音高范围错误
    config.global_pitch_min = 0.5
    config.global_pitch_max = 0.3
    result = config.validate()
    assert(result.valid == false, "Invalid pitch range should be invalid")
    assert(result.issues.size() > 0, "Invalid pitch range should have issues")

    # 测试音量范围错误
    config.global_pitch_min = -0.2  # 修复音高
    config.global_pitch_max = 0.2   # 修复音高
    config.global_volume_min = 1.2  # 设置错误的音量范围
    config.global_volume_max = 0.8
    result = config.validate()
    assert(result.valid == false, "Invalid volume range should be invalid")
    assert(result.issues.size() > 0, "Invalid volume range should have issues")

    # 修复配置
    config.global_volume_min = 0.8
    config.global_volume_max = 1.2
    result = config.validate()
    assert(result.valid == true, "Fixed config should be valid")
    assert(result.issues.size() == 0, "Fixed config should have no issues")

    print("  ✓ Validation test passed")