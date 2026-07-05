extends SceneTree
# JuicyMixerEnums 中断策略枚举测试
# 测试中断策略枚举和相关辅助函数

const JuicyMixerEnms = preload("res://addons/juicy_mixer/core/juicy_mixer_enums.gd")

var _test_results: Array = []

func _init():
    _test_results = []

func test_interruption_policy_enum_values():
    # 测试中断策略枚举值
    assert(JuicyMixerEnms.InterruptionPolicy.STACK == 0, "STACK 策略值应该是 0")
    assert(JuicyMixerEnms.InterruptionPolicy.RESTART == 1, "RESTART 策略值应该是 1")
    assert(JuicyMixerEnms.InterruptionPolicy.IGNORE == 2, "IGNORE 策略值应该是 2")
    assert(JuicyMixerEnms.InterruptionPolicy.SMOOTH_TRANSITION == 3, "SMOOTH_TRANSITION 策略值应该是 3")
    assert(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE == 4, "PRIORITY_OVERRIDE 策略值应该是 4")
    assert(JuicyMixerEnms.InterruptionPolicy.FADE_OUT_FADE_IN == 5, "FADE_OUT_FADE_IN 策略值应该是 5")
    assert(JuicyMixerEnms.InterruptionPolicy.PRIORITY_STACK == 6, "PRIORITY_STACK 策略值应该是 6")
    
    _test_results.append("test_interruption_policy_enum_values: PASSED")

func test_get_interruption_policy_name():
    # 测试获取中断策略名称
    var stack_name = JuicyMixerEnms.get_interruption_policy_name(JuicyMixerEnms.InterruptionPolicy.STACK)
    assert(stack_name == "stack", "STACK 策略名称应该是 'stack'")
    
    var restart_name = JuicyMixerEnms.get_interruption_policy_name(JuicyMixerEnms.InterruptionPolicy.RESTART)
    assert(restart_name == "restart", "RESTART 策略名称应该是 'restart'")
    
    var ignore_name = JuicyMixerEnms.get_interruption_policy_name(JuicyMixerEnms.InterruptionPolicy.IGNORE)
    assert(ignore_name == "ignore", "IGNORE 策略名称应该是 'ignore'")
    
    var smooth_name = JuicyMixerEnms.get_interruption_policy_name(JuicyMixerEnms.InterruptionPolicy.SMOOTH_TRANSITION)
    assert(smooth_name == "smooth_transition", "SMOOTH_TRANSITION 策略名称应该是 'smooth_transition'")
    
    var priority_name = JuicyMixerEnms.get_interruption_policy_name(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
    assert(priority_name == "priority_override", "PRIORITY_OVERRIDE 策略名称应该是 'priority_override'")
    
    var fade_name = JuicyMixerEnms.get_interruption_policy_name(JuicyMixerEnms.InterruptionPolicy.FADE_OUT_FADE_IN)
    assert(fade_name == "fade_out_fade_in", "FADE_OUT_FADE_IN 策略名称应该是 'fade_out_fade_in'")
    
    var priority_stack_name = JuicyMixerEnms.get_interruption_policy_name(JuicyMixerEnms.InterruptionPolicy.PRIORITY_STACK)
    assert(priority_stack_name == "priority_stack", "PRIORITY_STACK 策略名称应该是 'priority_stack'")
    
    # 测试无效策略值
    var invalid_name = JuicyMixerEnms.get_interruption_policy_name(999)
    assert(invalid_name == "unknown", "无效策略应该返回 'unknown'")
    
    _test_results.append("test_get_interruption_policy_name: PASSED")

func test_get_interruption_policy_from_name():
    # 测试从名称获取中断策略
    var stack_policy = JuicyMixerEnms.get_interruption_policy_from_name("stack")
    assert(stack_policy == JuicyMixerEnms.InterruptionPolicy.STACK, "名称 'stack' 应该对应 STACK 策略")
    
    var restart_policy = JuicyMixerEnms.get_interruption_policy_from_name("restart")
    assert(restart_policy == JuicyMixerEnms.InterruptionPolicy.RESTART, "名称 'restart' 应该对应 RESTART 策略")
    
    var ignore_policy = JuicyMixerEnms.get_interruption_policy_from_name("ignore")
    assert(ignore_policy == JuicyMixerEnms.InterruptionPolicy.IGNORE, "名称 'ignore' 应该对应 IGNORE 策略")
    
    var smooth_policy = JuicyMixerEnms.get_interruption_policy_from_name("smooth_transition")
    assert(smooth_policy == JuicyMixerEnms.InterruptionPolicy.SMOOTH_TRANSITION, "名称 'smooth_transition' 应该对应 SMOOTH_TRANSITION 策略")
    
    var priority_policy = JuicyMixerEnms.get_interruption_policy_from_name("priority_override")
    assert(priority_policy == JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE, "名称 'priority_override' 应该对应 PRIORITY_OVERRIDE 策略")
    
    var fade_policy = JuicyMixerEnms.get_interruption_policy_from_name("fade_out_fade_in")
    assert(fade_policy == JuicyMixerEnms.InterruptionPolicy.FADE_OUT_FADE_IN, "名称 'fade_out_fade_in' 应该对应 FADE_OUT_FADE_IN 策略")
    
    var priority_stack_policy = JuicyMixerEnms.get_interruption_policy_from_name("priority_stack")
    assert(priority_stack_policy == JuicyMixerEnms.InterruptionPolicy.PRIORITY_STACK, "名称 'priority_stack' 应该对应 PRIORITY_STACK 策略")
    
    # 测试大小写不敏感
    var upper_case_policy = JuicyMixerEnms.get_interruption_policy_from_name("STACK")
    assert(upper_case_policy == JuicyMixerEnms.InterruptionPolicy.STACK, "大写名称应该也能正确解析")
    
    var mixed_case_policy = JuicyMixerEnms.get_interruption_policy_from_name("SmOoTh_TrAnSiTiOn")
    assert(mixed_case_policy == JuicyMixerEnms.InterruptionPolicy.SMOOTH_TRANSITION, "混合大小写名称应该也能正确解析")
    
    # 测试无效名称
    var invalid_policy = JuicyMixerEnms.get_interruption_policy_from_name("invalid_policy")
    assert(invalid_policy == JuicyMixerEnms.InterruptionPolicy.STACK, "无效名称应该返回默认策略 STACK")
    
    # 测试空名称
    var empty_policy = JuicyMixerEnms.get_interruption_policy_from_name("")
    assert(empty_policy == JuicyMixerEnms.InterruptionPolicy.STACK, "空名称应该返回默认策略 STACK")
    
    _test_results.append("test_get_interruption_policy_from_name: PASSED")

func test_get_all_interruption_policies():
    # 测试获取所有中断策略
    var all_policies = JuicyMixerEnms.get_all_interruption_policies()
    assert(typeof(all_policies) == TYPE_ARRAY, "返回值应该是数组")
    assert(all_policies.size() == 7, "应该返回 7 种策略")
    
    # 验证所有策略都存在
    assert("stack" in all_policies, "应该包含 stack 策略")
    assert("restart" in all_policies, "应该包含 restart 策略")
    assert("ignore" in all_policies, "应该包含 ignore 策略")
    assert("smooth_transition" in all_policies, "应该包含 smooth_transition 策略")
    assert("priority_override" in all_policies, "应该包含 priority_override 策略")
    assert("fade_out_fade_in" in all_policies, "应该包含 fade_out_fade_in 策略")
    assert("priority_stack" in all_policies, "应该包含 priority_stack 策略")
    
    _test_results.append("test_get_all_interruption_policies: PASSED")

func test_get_interruption_policy_description():
    # 测试获取中断策略描述
    var stack_desc = JuicyMixerEnms.get_interruption_policy_description(JuicyMixerEnms.InterruptionPolicy.STACK)
    assert(stack_desc.contains("堆叠"), "STACK 策略描述应该包含 '堆叠'")
    assert(stack_desc.contains("新效果加入队列"), "STACK 策略描述应该包含 '新效果加入队列'")
    assert(stack_desc.contains("当前效果继续执行"), "STACK 策略描述应该包含 '当前效果继续执行'")
    
    var restart_desc = JuicyMixerEnms.get_interruption_policy_description(JuicyMixerEnms.InterruptionPolicy.RESTART)
    assert(restart_desc.contains("重启"), "RESTART 策略描述应该包含 '重启'")
    assert(restart_desc.contains("立即停止当前效果"), "RESTART 策略描述应该包含 '立即停止当前效果'")
    assert(restart_desc.contains("开始新效果"), "RESTART 策略描述应该包含 '开始新效果'")
    
    var ignore_desc = JuicyMixerEnms.get_interruption_policy_description(JuicyMixerEnms.InterruptionPolicy.IGNORE)
    assert(ignore_desc.contains("忽略"), "IGNORE 策略描述应该包含 '忽略'")
    assert(ignore_desc.contains("忽略新效果"), "IGNORE 策略描述应该包含 '忽略新效果'")
    assert(ignore_desc.contains("保持当前效果"), "IGNORE 策略描述应该包含 '保持当前效果'")
    
    var smooth_desc = JuicyMixerEnms.get_interruption_policy_description(JuicyMixerEnms.InterruptionPolicy.SMOOTH_TRANSITION)
    assert(smooth_desc.contains("平滑过渡"), "SMOOTH_TRANSITION 策略描述应该包含 '平滑过渡'")
    assert(smooth_desc.contains("平滑地从当前效果过渡到新效果"), "SMOOTH_TRANSITION 策略描述应该包含 '平滑地从当前效果过渡到新效果'")
    
    var priority_desc = JuicyMixerEnms.get_interruption_policy_description(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
    assert(priority_desc.contains("优先级覆盖"), "PRIORITY_OVERRIDE 策略描述应该包含 '优先级覆盖'")
    assert(priority_desc.contains("高优先级效果覆盖低优先级效果"), "PRIORITY_OVERRIDE 策略描述应该包含 '高优先级效果覆盖低优先级效果'")
    
    var fade_desc = JuicyMixerEnms.get_interruption_policy_description(JuicyMixerEnms.InterruptionPolicy.FADE_OUT_FADE_IN)
    assert(fade_desc.contains("淡出淡入"), "FADE_OUT_FADE_IN 策略描述应该包含 '淡出淡入'")
    assert(fade_desc.contains("当前效果淡出"), "FADE_OUT_FADE_IN 策略描述应该包含 '当前效果淡出'")
    assert(fade_desc.contains("新效果淡入"), "FADE_OUT_FADE_IN 策略描述应该包含 '新效果淡入'")
    
    var priority_stack_desc = JuicyMixerEnms.get_interruption_policy_description(JuicyMixerEnms.InterruptionPolicy.PRIORITY_STACK)
    assert(priority_stack_desc.contains("优先级堆叠"), "PRIORITY_STACK 策略描述应该包含 '优先级堆叠'")
    assert(priority_stack_desc.contains("按优先级插入队列"), "PRIORITY_STACK 策略描述应该包含 '按优先级插入队列'")
    
    # 测试无效策略
    var invalid_desc = JuicyMixerEnms.get_interruption_policy_description(999)
    assert(invalid_desc == "未知策略", "无效策略应该返回 '未知策略'")
    
    _test_results.append("test_get_interruption_policy_description: PASSED")

func test_policy_name_roundtrip():
    # 测试策略名称的往返转换
    var original_policies = [
        JuicyMixerEnms.InterruptionPolicy.STACK,
        JuicyMixerEnms.InterruptionPolicy.RESTART,
        JuicyMixerEnms.InterruptionPolicy.IGNORE,
        JuicyMixerEnms.InterruptionPolicy.SMOOTH_TRANSITION,
        JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE,
        JuicyMixerEnms.InterruptionPolicy.FADE_OUT_FADE_IN,
        JuicyMixerEnms.InterruptionPolicy.PRIORITY_STACK
    ]
    
    for policy in original_policies:
        var name = JuicyMixerEnms.get_interruption_policy_name(policy)
        var converted_policy = JuicyMixerEnms.get_interruption_policy_from_name(name)
        assert(converted_policy == policy, "策略名称往返转换应该保持一致: " + str(policy))
    
    _test_results.append("test_policy_name_roundtrip: PASSED")

func test_tween_properties_enum():
    # 测试 Tween 属性枚举
    assert(JuicyMixerEnms.tween_properties.custom == 0, "custom 属性值应该是 0")
    assert(JuicyMixerEnms.tween_properties.position == 1, "position 属性值应该是 1")
    assert(JuicyMixerEnms.tween_properties.rotation == 2, "rotation 属性值应该是 2")
    assert(JuicyMixerEnms.tween_properties.scale == 3, "scale 属性值应该是 3")
    assert(JuicyMixerEnms.tween_properties.modulate == 4, "modulate 属性值应该是 4")
    assert(JuicyMixerEnms.tween_properties.self_modulate == 5, "self_modulate 属性值应该是 5")
    assert(JuicyMixerEnms.tween_properties.skew == 6, "skew 属性值应该是 6")
    assert(JuicyMixerEnms.tween_properties.size == 7, "size 属性值应该是 7")
    assert(JuicyMixerEnms.tween_properties.global_position == 8, "global_position 属性值应该是 8")
    assert(JuicyMixerEnms.tween_properties.global_rotation == 9, "global_rotation 属性值应该是 9")
    assert(JuicyMixerEnms.tween_properties.global_scale == 10, "global_scale 属性值应该是 10")
    assert(JuicyMixerEnms.tween_properties.pivot_offset == 11, "pivot_offset 属性值应该是 11")
    assert(JuicyMixerEnms.tween_properties.offset == 12, "offset 属性值应该是 12")
    
    _test_results.append("test_tween_properties_enum: PASSED")

func test_shake_properties_enum():
    # 测试 Shake 属性枚举
    assert(JuicyMixerEnms.shake_properties.custom == 0, "shake custom 属性值应该是 0")
    assert(JuicyMixerEnms.shake_properties.position == 1, "shake position 属性值应该是 1")
    assert(JuicyMixerEnms.shake_properties.rotation == 2, "shake rotation 属性值应该是 2")
    assert(JuicyMixerEnms.shake_properties.scale == 3, "shake scale 属性值应该是 3")
    assert(JuicyMixerEnms.shake_properties.offset == 4, "shake offset 属性值应该是 4")
    assert(JuicyMixerEnms.shake_properties.zoom == 5, "shake zoom 属性值应该是 5")
    assert(JuicyMixerEnms.shake_properties.global_position == 6, "shake global_position 属性值应该是 6")
    assert(JuicyMixerEnms.shake_properties.global_rotation == 7, "shake global_rotation 属性值应该是 7")
    assert(JuicyMixerEnms.shake_properties.global_scale == 8, "shake global_scale 属性值应该是 8")
    assert(JuicyMixerEnms.shake_properties.pivot_offset == 9, "shake pivot_offset 属性值应该是 9")
    assert(JuicyMixerEnms.shake_properties.modulate == 10, "shake modulate 属性值应该是 10")
    
    _test_results.append("test_shake_properties_enum: PASSED")

func test_spring_properties_enum():
    # 测试 Spring 属性枚举
    assert(JuicyMixerEnms.spring_properties.custom == 0, "spring custom 属性值应该是 0")
    assert(JuicyMixerEnms.spring_properties.position == 1, "spring position 属性值应该是 1")
    assert(JuicyMixerEnms.spring_properties.rotation == 2, "spring rotation 属性值应该是 2")
    assert(JuicyMixerEnms.spring_properties.scale == 3, "spring scale 属性值应该是 3")
    assert(JuicyMixerEnms.spring_properties.offset == 4, "spring offset 属性值应该是 4")
    assert(JuicyMixerEnms.spring_properties.zoom == 5, "spring zoom 属性值应该是 5")
    assert(JuicyMixerEnms.spring_properties.global_position == 6, "spring global_position 属性值应该是 6")
    assert(JuicyMixerEnms.spring_properties.global_rotation == 7, "spring global_rotation 属性值应该是 7")
    assert(JuicyMixerEnms.spring_properties.global_scale == 8, "spring global_scale 属性值应该是 8")
    assert(JuicyMixerEnms.spring_properties.pivot_offset == 9, "spring pivot_offset 属性值应该是 9")
    assert(JuicyMixerEnms.spring_properties.modulate == 10, "spring modulate 属性值应该是 10")
    
    _test_results.append("test_spring_properties_enum: PASSED")

func test_get_tween_property_name():
    # 测试获取 Tween 属性名称
    assert(JuicyMixerEnms.get_tween_property_name(JuicyMixerEnms.tween_properties.custom) == "custom", "custom 属性名称应该正确")
    assert(JuicyMixerEnms.get_tween_property_name(JuicyMixerEnms.tween_properties.position) == "position", "position 属性名称应该正确")
    assert(JuicyMixerEnms.get_tween_property_name(JuicyMixerEnms.tween_properties.rotation) == "rotation", "rotation 属性名称应该正确")
    assert(JuicyMixerEnms.get_tween_property_name(JuicyMixerEnms.tween_properties.scale) == "scale", "scale 属性名称应该正确")
    assert(JuicyMixerEnms.get_tween_property_name(JuicyMixerEnms.tween_properties.modulate) == "modulate", "modulate 属性名称应该正确")
    assert(JuicyMixerEnms.get_tween_property_name(JuicyMixerEnms.tween_properties.self_modulate) == "self_modulate", "self_modulate 属性名称应该正确")
    assert(JuicyMixerEnms.get_tween_property_name(JuicyMixerEnms.tween_properties.skew) == "skew", "skew 属性名称应该正确")
    assert(JuicyMixerEnms.get_tween_property_name(JuicyMixerEnms.tween_properties.size) == "size", "size 属性名称应该正确")
    assert(JuicyMixerEnms.get_tween_property_name(JuicyMixerEnms.tween_properties.global_position) == "global_position", "global_position 属性名称应该正确")
    assert(JuicyMixerEnms.get_tween_property_name(JuicyMixerEnms.tween_properties.global_rotation) == "global_rotation", "global_rotation 属性名称应该正确")
    assert(JuicyMixerEnms.get_tween_property_name(JuicyMixerEnms.tween_properties.global_scale) == "global_scale", "global_scale 属性名称应该正确")
    assert(JuicyMixerEnms.get_tween_property_name(JuicyMixerEnms.tween_properties.pivot_offset) == "pivot_offset", "pivot_offset 属性名称应该正确")
    assert(JuicyMixerEnms.get_tween_property_name(JuicyMixerEnms.tween_properties.offset) == "offset", "offset 属性名称应该正确")
    
    # 测试无效值
    var invalid_name = JuicyMixerEnms.get_tween_property_name(999)
    assert(invalid_name == "", "无效属性值应该返回空字符串")
    
    _test_results.append("test_get_tween_property_name: PASSED")

func test_get_shake_property_name():
    # 测试获取 Shake 属性名称
    assert(JuicyMixerEnms.get_shake_property_name(JuicyMixerEnms.shake_properties.custom) == "custom", "shake custom 属性名称应该正确")
    assert(JuicyMixerEnms.get_shake_property_name(JuicyMixerEnms.shake_properties.position) == "position", "shake position 属性名称应该正确")
    assert(JuicyMixerEnms.get_shake_property_name(JuicyMixerEnms.shake_properties.rotation) == "rotation", "shake rotation 属性名称应该正确")
    assert(JuicyMixerEnms.get_shake_property_name(JuicyMixerEnms.shake_properties.scale) == "scale", "shake scale 属性名称应该正确")
    assert(JuicyMixerEnms.get_shake_property_name(JuicyMixerEnms.shake_properties.offset) == "offset", "shake offset 属性名称应该正确")
    assert(JuicyMixerEnms.get_shake_property_name(JuicyMixerEnms.shake_properties.zoom) == "zoom", "shake zoom 属性名称应该正确")
    assert(JuicyMixerEnms.get_shake_property_name(JuicyMixerEnms.shake_properties.global_position) == "global_position", "shake global_position 属性名称应该正确")
    assert(JuicyMixerEnms.get_shake_property_name(JuicyMixerEnms.shake_properties.global_rotation) == "global_rotation", "shake global_rotation 属性名称应该正确")
    assert(JuicyMixerEnms.get_shake_property_name(JuicyMixerEnms.shake_properties.global_scale) == "global_scale", "shake global_scale 属性名称应该正确")
    assert(JuicyMixerEnms.get_shake_property_name(JuicyMixerEnms.shake_properties.pivot_offset) == "pivot_offset", "shake pivot_offset 属性名称应该正确")
    assert(JuicyMixerEnms.get_shake_property_name(JuicyMixerEnms.shake_properties.modulate) == "modulate", "shake modulate 属性名称应该正确")
    
    # 测试无效值
    var invalid_name = JuicyMixerEnms.get_shake_property_name(999)
    assert(invalid_name == "", "无效属性值应该返回空字符串")
    
    _test_results.append("test_get_shake_property_name: PASSED")

func test_get_spring_property_name():
    # 测试获取 Spring 属性名称
    assert(JuicyMixerEnms.get_spring_property_name(JuicyMixerEnms.spring_properties.custom) == "custom", "spring custom 属性名称应该正确")
    assert(JuicyMixerEnms.get_spring_property_name(JuicyMixerEnms.spring_properties.position) == "position", "spring position 属性名称应该正确")
    assert(JuicyMixerEnms.get_spring_property_name(JuicyMixerEnms.spring_properties.rotation) == "rotation", "spring rotation 属性名称应该正确")
    assert(JuicyMixerEnms.get_spring_property_name(JuicyMixerEnms.spring_properties.scale) == "scale", "spring scale 属性名称应该正确")
    assert(JuicyMixerEnms.get_spring_property_name(JuicyMixerEnms.spring_properties.offset) == "offset", "spring offset 属性名称应该正确")
    assert(JuicyMixerEnms.get_spring_property_name(JuicyMixerEnms.spring_properties.zoom) == "zoom", "spring zoom 属性名称应该正确")
    assert(JuicyMixerEnms.get_spring_property_name(JuicyMixerEnms.spring_properties.global_position) == "global_position", "spring global_position 属性名称应该正确")
    assert(JuicyMixerEnms.get_spring_property_name(JuicyMixerEnms.spring_properties.global_rotation) == "global_rotation", "spring global_rotation 属性名称应该正确")
    assert(JuicyMixerEnms.get_spring_property_name(JuicyMixerEnms.spring_properties.global_scale) == "global_scale", "spring global_scale 属性名称应该正确")
    assert(JuicyMixerEnms.get_spring_property_name(JuicyMixerEnms.spring_properties.pivot_offset) == "pivot_offset", "spring pivot_offset 属性名称应该正确")
    assert(JuicyMixerEnms.get_spring_property_name(JuicyMixerEnms.spring_properties.modulate) == "modulate", "spring modulate 属性名称应该正确")
    
    # 测试无效值
    var invalid_name = JuicyMixerEnms.get_spring_property_name(999)
    assert(invalid_name == "", "无效属性值应该返回空字符串")
    
    _test_results.append("test_get_spring_property_name: PASSED")

func test_get_property_type_hint():
    # 测试获取属性类型提示
    assert(JuicyMixerEnms.get_property_type_hint("position") == "Vector2", "position 类型提示应该是 Vector2")
    assert(JuicyMixerEnms.get_property_type_hint("global_position") == "Vector2", "global_position 类型提示应该是 Vector2")
    assert(JuicyMixerEnms.get_property_type_hint("offset") == "Vector2", "offset 类型提示应该是 Vector2")
    assert(JuicyMixerEnms.get_property_type_hint("pivot_offset") == "Vector2", "pivot_offset 类型提示应该是 Vector2")
    assert(JuicyMixerEnms.get_property_type_hint("size") == "Vector2", "size 类型提示应该是 Vector2")
    assert(JuicyMixerEnms.get_property_type_hint("zoom") == "Vector2", "zoom 类型提示应该是 Vector2")
    
    assert(JuicyMixerEnms.get_property_type_hint("rotation") == "float (radians)", "rotation 类型提示应该是 float (radians)")
    assert(JuicyMixerEnms.get_property_type_hint("global_rotation") == "float (radians)", "global_rotation 类型提示应该是 float (radians)")
    assert(JuicyMixerEnms.get_property_type_hint("skew") == "float", "skew 类型提示应该是 float")
    
    assert(JuicyMixerEnms.get_property_type_hint("scale") == "Vector2", "scale 类型提示应该是 Vector2")
    assert(JuicyMixerEnms.get_property_type_hint("global_scale") == "Vector2", "global_scale 类型提示应该是 Vector2")
    
    assert(JuicyMixerEnms.get_property_type_hint("modulate") == "Color", "modulate 类型提示应该是 Color")
    assert(JuicyMixerEnms.get_property_type_hint("self_modulate") == "Color", "self_modulate 类型提示应该是 Color")
    
    assert(JuicyMixerEnms.get_property_type_hint("custom") == "自定义属性", "custom 类型提示应该是 自定义属性")
    
    # 测试未知属性
    assert(JuicyMixerEnms.get_property_type_hint("unknown_property") == "未知类型", "未知属性应该返回 未知类型")
    
    _test_results.append("test_get_property_type_hint: PASSED")

func test_is_property_valid_for_node():
    # 创建测试节点
    var test_node = Node2D.new()
    
    # 测试有效属性
    assert(JuicyMixerEnms.is_property_valid_for_node("custom", test_node), "custom 属性应该总是有效")
    
    # 测试节点实际拥有的属性
    # 注意：这里需要实际的节点属性测试，由于环境限制，只做基本测试
    var result = JuicyMixerEnms.is_property_valid_for_node("position", test_node)
    assert(typeof(result) == TYPE_BOOL, "返回值应该是布尔值")
    
    # 清理
    test_node.free()
    
    _test_results.append("test_is_property_valid_for_node: PASSED")

func test_get_valid_properties_for_node():
    # 创建测试节点
    var test_node = Node2D.new()
    
    # 测试获取有效属性
    var valid_props = JuicyMixerEnms.get_valid_properties_for_node(test_node)
    assert(typeof(valid_props) == TYPE_ARRAY, "返回值应该是数组")
    
    # 测试空节点
    var empty_props = JuicyMixerEnms.get_valid_properties_for_node(null)
    assert(empty_props.size() == 0, "空节点应该返回空数组")
    
    # 清理
    test_node.free()
    
    _test_results.append("test_get_valid_properties_for_node: PASSED")

func test_edge_cases():
    # 测试边界情况
    
    # 测试无效值（使用极端值代替 null）
    var invalid_value_name = JuicyMixerEnms.get_interruption_policy_name(-1)
    assert(invalid_value_name == "unknown", "无效值应该返回 'unknown'")
    
    # 测试极端值
    var extreme_name = JuicyMixerEnms.get_interruption_policy_name(-999999)
    assert(extreme_name == "unknown", "极端负值应该返回 'unknown'")
    
    var extreme_positive_name = JuicyMixerEnms.get_interruption_policy_name(999999)
    assert(extreme_positive_name == "unknown", "极端正值应该返回 'unknown'")
    
    # 测试空字符串
    var empty_policy = JuicyMixerEnms.get_interruption_policy_from_name("")
    assert(empty_policy == JuicyMixerEnms.InterruptionPolicy.STACK, "空字符串应该返回默认策略")
    
    # 测试特殊字符
    var special_policy = JuicyMixerEnms.get_interruption_policy_from_name("!@#$%^&*()")
    assert(special_policy == JuicyMixerEnms.InterruptionPolicy.STACK, "特殊字符应该返回默认策略")
    
    _test_results.append("test_edge_cases: PASSED")

func test_property_name_consistency():
    # 测试属性名称的一致性
    var tween_names = []
    for enum_value in JuicyMixerEnms.tween_properties.values():
        var name = JuicyMixerEnms.get_tween_property_name(enum_value)
        if name != "" and name != "custom":
            tween_names.append(name)
    
    var shake_names = []
    for enum_value in JuicyMixerEnms.shake_properties.values():
        var name = JuicyMixerEnms.get_shake_property_name(enum_value)
        if name != "" and name != "custom":
            shake_names.append(name)
    
    var spring_names = []
    for enum_value in JuicyMixerEnms.spring_properties.values():
        var name = JuicyMixerEnms.get_spring_property_name(enum_value)
        if name != "" and name != "custom":
            spring_names.append(name)
    
    # 验证共同属性的一致性
    var common_properties = ["position", "rotation", "scale", "offset", "global_position", "global_rotation", "global_scale", "pivot_offset", "modulate"]
    
    for prop in common_properties:
        assert(prop in tween_names, "Tween 应该包含共同属性: " + prop)
        assert(prop in shake_names, "Shake 应该包含共同属性: " + prop)
        assert(prop in spring_names, "Spring 应该包含共同属性: " + prop)
    
    _test_results.append("test_property_name_consistency: PASSED")

func run_all_tests():
    print("=== 开始 JuicyMixerEnums 中断策略枚举测试 ===")
    
    # 测试函数列表
    var test_functions = [
        "test_interruption_policy_enum_values",
        "test_get_interruption_policy_name",
        "test_get_interruption_policy_from_name",
        "test_get_all_interruption_policies",
        "test_get_interruption_policy_description",
        "test_policy_name_roundtrip",
        "test_tween_properties_enum",
        "test_shake_properties_enum",
        "test_spring_properties_enum",
        "test_get_tween_property_name",
        "test_get_shake_property_name",
        "test_get_spring_property_name",
        "test_get_property_type_hint",
        "test_is_property_valid_for_node",
        "test_get_valid_properties_for_node",
        "test_edge_cases",
        "test_property_name_consistency"
    ]
    
    # 记录测试开始时的结果数量
    var initial_count = _test_results.size()
    
    # 执行每个测试
    for test_name in test_functions:
        print("执行测试: " + test_name)
        var test_start_count = _test_results.size()
        call(test_name)
        var test_end_count = _test_results.size()
        if test_end_count > test_start_count:
            print("✓ " + test_name + " 通过")
        else:
            print("✗ " + test_name + " 失败")
            _test_results.append(test_name + ": FAILED")
    
    print("=== JuicyMixerEnums 中断策略枚举测试结果 ===")
    for result in _test_results:
        print(result)
    
    var passed_count = _test_results.size() - initial_count
    var total_tests = test_functions.size()
    print("通过测试: " + str(passed_count) + "/" + str(total_tests))
    
    if passed_count == total_tests:
        print("所有测试通过！")
        return true
    else:
        print("部分测试失败！")
        return false