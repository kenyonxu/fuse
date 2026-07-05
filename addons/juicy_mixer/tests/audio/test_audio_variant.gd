extends Node

func _ready():
    test_audio_variant_creation()
    test_audio_variant_serialization()
    test_audio_variant_validation()
    test_audio_variant_randomization()
    print("✓ AudioVariant tests passed")

func test_audio_variant_creation():
    var variant = AudioVariant.new()
    assert(variant != null, "Variant should be created")
    assert(variant.audio_stream == null, "Default stream should be null")
    assert(variant.weight == 1.0, "Default weight should be 1.0")
    print("  ✓ AudioVariant creation test passed")

func test_audio_variant_serialization():
    var variant = AudioVariant.new()
    variant.variant_name = "test_variant"
    variant.weight = 2.0
    variant.pitch_enabled = true
    variant.pitch_min = -0.5
    variant.pitch_max = 0.5

    # 测试序列化（通过Resource.duplicate）
    var duplicated = variant.duplicate(true)
    assert(duplicated.variant_name == "test_variant", "Name should be preserved")
    assert(duplicated.weight == 2.0, "Weight should be preserved")
    assert(duplicated.pitch_enabled == true, "Pitch enabled should be preserved")
    print("  ✓ AudioVariant serialization test passed")

func test_audio_variant_validation():
    var variant = AudioVariant.new()

    # 有效配置
    variant.weight = 1.0
    var result = variant.validate()
    assert(result.valid, "Valid config should pass")

    # 无效权重
    variant.weight = -1.0
    result = variant.validate()
    assert(not result.valid, "Negative weight should fail")
    assert(result.issues.size() > 0, "Should have issues")

    # 音高范围错误
    variant.weight = 1.0
    variant.pitch_enabled = true
    variant.pitch_min = 0.5
    variant.pitch_max = -0.5
    result = variant.validate()
    assert(not result.valid, "Invalid pitch range should fail")

    print("  ✓ AudioVariant validation test passed")

func test_audio_variant_randomization():
    var variant = AudioVariant.new()

    # 音高随机化
    variant.pitch_enabled = true
    variant.pitch_min = -0.3
    variant.pitch_max = 0.3

    var pitch_values = []
    for i in range(10):
        pitch_values.append(variant.get_randomized_pitch())

    # 验证范围（粗略检查）
    for pitch in pitch_values:
        assert(pitch > 0.7 and pitch < 1.3, "Pitch should be within randomized range")

    # 音量随机化
    variant.volume_enabled = true
    variant.volume_min = 0.8
    variant.volume_max = 1.2

    var volume_values = []
    for i in range(10):
        volume_values.append(variant.get_randomized_volume())

    for volume in volume_values:
        assert(volume >= 0.8 and volume <= 1.2, "Volume should be within randomized range")

    print("  ✓ AudioVariant randomization test passed")