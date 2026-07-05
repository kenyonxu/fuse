extends Node

func _ready():
    test_variant_selection()
    test_weighted_selection()
    test_no_repeat()
    test_randomization()
    print("✓ AudioVariationManager tests passed")

func test_variant_selection():
    var manager = AudioVariationManager.new()
    var resource = AudioEventResource.new()

    # 添加3个变体
    for i in range(3):
        var variant = AudioVariant.new()
        variant.audio_stream = AudioStreamOggVorbis.new()
        variant.weight = 1.0
        resource.audio_variants.append(variant)

    var selected = manager.select_variant(resource)
    assert(selected != null, "Should select a variant")
    assert(selected in resource.audio_variants, "Selected should be in variants")

    print("  ✓ Variant selection test passed")

func test_weighted_selection():
    var manager = AudioVariationManager.new()
    var resource = AudioEventResource.new()

    # 添加3个变体，权重分别为1, 2, 3
    var weights = [1.0, 2.0, 3.0]
    for i in range(3):
        var variant = AudioVariant.new()
        variant.audio_stream = AudioStreamOggVorbis.new()
        variant.weight = weights[i]
        resource.audio_variants.append(variant)

    # 测试100次选择，验证权重分布
    var counts = [0, 0, 0]
    for i in range(100):
        var selected = manager.select_variant(resource)
        var index = resource.audio_variants.find(selected)
        counts[index] += 1

    # 变体3应该被选择最多（权重最大）
    assert(counts[2] > counts[1], "Variant 3 (weight 3) should be selected more than variant 2")
    assert(counts[1] > counts[0], "Variant 2 (weight 2) should be selected more than variant 1")

    print("  ✓ Weighted selection test passed")

func test_no_repeat():
    var manager = AudioVariationManager.new()
    var resource = AudioEventResource.new()
    resource.no_repeat_enabled = true
    resource.no_repeat_memory = 2

    # 添加3个变体
    for i in range(3):
        var variant = AudioVariant.new()
        variant.audio_stream = AudioStreamOggVorbis.new()
        variant.variant_name = "variant_%d" % i
        resource.audio_variants.append(variant)

    var last_selected = null
    for i in range(10):
        var selected = manager.select_variant(resource)
        if last_selected != null:
            assert(selected != last_selected, "No repeat should prevent consecutive same variant")
        last_selected = selected

    print("  ✓ No repeat test passed")

func test_randomization():
    var manager = AudioVariationManager.new()
    var config = AudioRandomizationConfig.new()
    config.global_pitch_min = -0.5
    config.global_pitch_max = 0.5
    config.global_volume_min = 0.9
    config.global_volume_max = 1.1
    config.enabled = true

    var resource = AudioEventResource.new()
    resource.randomization = config

    var variant = AudioVariant.new()
    variant.audio_stream = AudioStreamOggVorbis.new()
    variant.pitch_enabled = true
    variant.pitch_min = -0.3
    variant.pitch_max = 0.3
    variant.volume_enabled = true
    variant.volume_min = 0.8
    variant.volume_max = 1.2
    resource.audio_variants.append(variant)

    # 测试100次随机化
    var pitch_values = []
    var volume_values = []
    for i in range(100):
        var rand = manager.apply_randomization(variant, 1.0, 1.0, resource)
        pitch_values.append(rand.pitch)
        volume_values.append(rand.volume)

    # 验证范围
    for pitch in pitch_values:
        assert(pitch > 0.5 and pitch < 1.5, "Pitch should be within randomized range")

    for volume in volume_values:
        assert(volume >= 0.72 and volume <= 1.32, "Volume should be within randomized range")

    print("  ✓ Randomization test passed")