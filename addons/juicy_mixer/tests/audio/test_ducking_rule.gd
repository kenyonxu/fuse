extends Node

func _ready():
    test_rule_creation()
    test_pattern_matching()
    test_validation()
    test_recovery_delay()
    test_apply_remove_ducking()
    print("✓ DuckingRule tests passed")

func test_rule_creation():
    var rule = DuckingRule.new()
    assert(rule != null, "Rule should be created")
    assert(rule.enabled == true, "Should be enabled by default")
    assert(rule.target_bus == "Music", "Default target should be Music")
    print("  ✓ Rule creation test passed")

func test_pattern_matching():
    var rule = DuckingRule.new()
    rule.event_name_pattern = "dialogue_*"

    assert(rule.matches("dialogue_hello"), "Should match pattern")
    assert(rule.matches("dialogue_goodbye"), "Should match pattern")
    assert(not rule.matches("sfx_jump"), "Should not match different pattern")
    assert(rule.matches("dialogue_*"), "Should match exact pattern")

    # 测试通配符
    rule.event_name_pattern = "*"
    assert(rule.matches("anything"), "Wildcard should match everything")

    print("  ✓ Pattern matching test passed")

func test_validation():
    # 测试有效的配置
    var rule = DuckingRule.new()
    rule.target_bus = "Master"
    rule.duck_amount = -10.0

    var result = rule.validate()
    assert(result.valid == true, "Valid configuration should be valid")
    assert(result.issues.size() == 0, "Should have no issues")

    # 测试空总线名
    rule.target_bus = ""
    result = rule.validate()
    assert(result.valid == false, "Empty target bus should be invalid")
    assert(result.issues.has("target_bus cannot be empty"), "Should mention empty target bus")

    # 测试正数duck_amount警告
    rule.target_bus = "Master"
    rule.duck_amount = 5.0
    result = rule.validate()
    assert(result.warnings.has("duck_amount is usually negative (lowering volume)"),
           "Should warn about positive duck_amount")

    print("  ✓ Validation test passed")

func test_recovery_delay():
    var rule = DuckingRule.new()

    # 测试默认值
    assert(rule.recovery_delay == 0.5, "Default recovery delay should be 0.5")

    # 测试设置值
    rule.recovery_delay = 2.0
    assert(rule.recovery_delay == 2.0, "Should set recovery delay correctly")

    # 测试边界值
    rule.recovery_delay = 0.0
    assert(rule.recovery_delay == 0.0, "Should allow zero delay")

    rule.recovery_delay = 5.0
    assert(rule.recovery_delay == 5.0, "Should allow max delay")

    print("  ✓ Recovery delay test passed")

func test_apply_remove_ducking():
    # 注意：这些测试主要验证总线索引验证逻辑
    # 在实际游戏中需要正确配置AudioServer总线
    var rule = DuckingRule.new()
    rule.enabled = true

    # 测试无效的总线索引
    # 由于AudioServer.get_bus_count()可能为0，我们需要小心处理
    var bus_count = AudioServer.get_bus_count()
    if bus_count > 0:
        # 测试有效的总线索引
        rule.apply_ducking(0)
        assert(rule._is_ducking == true, "Should be ducking after apply")

        rule.remove_ducking(0)
        assert(rule._is_ducking == false, "Should not be ducking after remove")

    # 测试无效的负索引
    rule.apply_ducking(-1)
    # 应该不会抛出错误，但会打印错误消息

    # 测试无效的大索引
    if bus_count > 0:
        rule.apply_ducking(bus_count)  # 等于总线数量，应该是无效的
        # 应该不会抛出错误，但会打印错误消息

    print("  ✓ Apply/remove ducking test passed")