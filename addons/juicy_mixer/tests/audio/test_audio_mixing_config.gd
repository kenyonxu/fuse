@tool
extends Node

func _ready():
    test_config_creation()
    test_instance_limiting()
    test_ducking_rules()
    test_apply_to_player()
    test_get_ducking_rule_for_event()
    test_validation()
    print("✓ AudioMixingConfig tests passed")

func test_config_creation():
    var config = AudioMixingConfig.new()
    assert(config != null, "Config should be created")
    assert(config.max_instances == 10, "Should have default max instances")
    assert(config.limit_policy == AudioMixingConfig.LimitPolicy.PRIORITY, "Should use priority policy by default")
    assert(config.priority == 1, "Should have default priority")
    assert(config.ducking_rules.size() == 0, "Should have empty ducking rules by default")
    assert(config.ducking_fade_in == 0.1, "Should have default fade in time")
    assert(config.ducking_fade_out == 0.5, "Should have default fade out time")
    assert(config.ducking_bus == "Master", "Should use Master bus by default")
    print("  ✓ Config creation test passed")

func test_instance_limiting():
    var config = AudioMixingConfig.new()

    # 测试最大实例数限制
    config.max_instances = 5
    assert(config.max_instances == 5, "Max instances should be 5")

    # 测试优先级限制
    config.priority = 5
    assert(config.priority == 5, "Priority should be 5")

    # 测试不同限制策略
    config.limit_policy = AudioMixingConfig.LimitPolicy.FIFO
    assert(config.limit_policy == AudioMixingConfig.LimitPolicy.FIFO, "Should use FIFO policy")

    config.limit_policy = AudioMixingConfig.LimitPolicy.LIFO
    assert(config.limit_policy == AudioMixingConfig.LimitPolicy.LIFO, "Should use LIFO policy")

    config.limit_policy = AudioMixingConfig.LimitPolicy.PRIORITY
    assert(config.limit_policy == AudioMixingConfig.LimitPolicy.PRIORITY, "Should use PRIORITY policy")

    print("  ✓ Instance limiting test passed")

func test_ducking_rules():
    var config = AudioMixingConfig.new()

    # 创建一个鸭霸规则
    var ducking_rule = DuckingRule.new()
    ducking_rule.event_name_pattern = "explosion*"
    ducking_rule.target_bus = "Music"
    ducking_rule.duck_amount = -20.0
    ducking_rule.recovery_delay = 1.0
    ducking_rule.enabled = true

    # 添加规则
    config.ducking_rules.append(ducking_rule)
    assert(config.ducking_rules.size() == 1, "Should have 1 ducking rule")

    # 测试淡入淡出时间
    config.ducking_fade_in = 0.2
    config.ducking_fade_out = 0.3
    assert(config.ducking_fade_in == 0.2, "Fade in should be 0.2")
    assert(config.ducking_fade_out == 0.3, "Fade out should be 0.3")

    # 测试鸭霸总线
    config.ducking_bus = "Effects"
    assert(config.ducking_bus == "Effects", "Ducking bus should be Effects")

    print("  ✓ Ducking rules test passed")

func test_apply_to_player():
    var config = AudioMixingConfig.new()

    # 创建一个模拟的音频播放器
    var mock_player = Node.new()
    mock_player.set("max_instances", 10)
    mock_player.set("limit_policy", "priority")
    mock_player.set("priority", 1)

    # 应用配置
    config.apply_to_player(mock_player)

    # 验证应用结果
    assert(mock_player.get("max_instances") == config.max_instances, "Max instances should be applied")
    assert(mock_player.get("limit_policy") == str(config.limit_policy), "Limit policy should be applied")
    assert(mock_player.get("priority") == config.priority, "Priority should be applied")

    mock_player.queue_free()
    print("  ✓ Apply to player test passed")

func test_get_ducking_rule_for_event():
    var config = AudioMixingConfig.new()

    # 添加多个鸭霸规则
    var rule1 = DuckingRule.new()
    rule1.event_name_pattern = "explosion*"
    rule1.target_bus = "Music"
    rule1.enabled = true

    var rule2 = DuckingRule.new()
    rule2.event_name_pattern = "music*"
    rule2.target_bus = "Ambient"
    rule2.enabled = true

    var rule3 = DuckingRule.new()
    rule3.event_name_pattern = "ui*"
    rule3.target_bus = "Master"
    rule3.enabled = false  # 禁用的规则不应该匹配

    config.ducking_rules = [rule1, rule2, rule3]

    # 测试精确匹配
    var result1 = config.get_ducking_rule_for_event("explosion_big")
    assert(result1 == rule1, "Should match explosion rule")

    # 测试通配符匹配
    var result2 = config.get_ducking_rule_for_event("music_theme")
    assert(result2 == rule2, "Should match music rule")

    # 测试不匹配
    var result3 = config.get_ducking_rule_for_event("ui_click")
    assert(result3 == null, "Should not match disabled ui rule")

    # 测试完全不匹配
    var result4 = config.get_ducking_rule_for_event("ambient_wind")
    assert(result4 == null, "Should not match any rule")

    print("  ✓ Get ducking rule for event test passed")

func test_validation():
    var config = AudioMixingConfig.new()

    # 测试正常配置
    var result = config.validate()
    assert(result.valid == true, "Normal config should be valid")
    assert(result.issues.size() == 0, "Normal config should have no issues")

    # 测试无效的最大实例数
    config.max_instances = 0
    result = config.validate()
    assert(result.valid == false, "Max instances of 0 should be invalid")
    assert(result.issues.size() > 0, "Invalid max instances should have issues")

    # 修复配置
    config.max_instances = 1
    result = config.validate()
    assert(result.valid == true, "Fixed config should be valid")
    assert(result.issues.size() == 0, "Fixed config should have no issues")

    # 测试淡入淡出时间无效
    config.ducking_fade_in = -0.1
    result = config.validate()
    assert(result.valid == false, "Negative fade in should be invalid")
    assert(result.issues.size() > 0, "Negative fade in should have issues")

    # 测试鸭霸总线为空
    config.ducking_bus = ""
    result = config.validate()
    assert(result.valid == false, "Empty ducking bus should be invalid")
    assert(result.issues.size() > 0, "Empty ducking bus should have issues")

    print("  ✓ Validation test passed")