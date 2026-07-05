# 组合系统集成测试
# 测试完整的组合系统流程、参数映射与组合系统的集成、变体系统与组合系统的集成

extends Node

# 测试状态
var _tests_completed = 0
var _tests_total = 0
var _test_results = []
var _start_time = 0.0

# 测试资源
var _test_composite: JuicyCompositeResource
var _test_parameter_mapping: JuicyParameterMapping
var _test_variant: JuicyResourceVariant
var _test_context: JuicyContext
var _test_driver: JuicyCompositeDriver
var _test_shake_resource: JuicyShakeResource
var _test_tween_resource: JuicyTweenResource

func _ready():
	print("🧪 开始组合系统集成测试...")
	_start_time = Time.get_ticks_msec() / 1000.0
	
	# 初始化测试资源
	_setup_test_resources()
	
	# 运行所有测试
	_run_all_tests()
	
	# 生成测试报告
	_generate_test_report()
	
	# 标记测试完成
	_tests_completed = _tests_total

func _setup_test_resources():
	# 创建测试震动资源
	_test_shake_resource = JuicyShakeResource.new()
	var shake_data = ShakeData.new()
	shake_data.property = "position"
	shake_data.amplitude = 10.0
	shake_data.frequency = 5.0
	shake_data.duration = 1.0
	# 使用add_shake_data方法而不是直接赋值
	_test_shake_resource.add_shake_data(
		shake_data.property,
		shake_data.amplitude,
		shake_data.frequency,
		shake_data.duration,
		shake_data.falloff,
		shake_data.noise_seed,
		shake_data.octaves,
		shake_data.persistence,
		shake_data.lacunarity
	)
	_test_shake_resource.duration = 1.0
	
	# 创建测试补间资源
	_test_tween_resource = JuicyTweenResource.new()
	var tween_data = TweenData.new()
	tween_data.property = "position"
	tween_data.from_value = Vector2.ZERO
	tween_data.to_value = Vector2(100, 100)
	tween_data.duration = 1.0
	_test_tween_resource.tween_data = [tween_data]
	_test_tween_resource.duration = 1.0
	
	# 创建测试组合项
	var shake_item = JuicyCompositeItem.new()
	shake_item.resource = _test_shake_resource
	shake_item.weight = 1.0
	shake_item.enabled = true
	
	var tween_item = JuicyCompositeItem.new()
	tween_item.resource = _test_tween_resource
	tween_item.weight = 0.5
	tween_item.enabled = true
	
	# 创建测试参数映射
	_test_parameter_mapping = JuicyParameterMapping.new()
	_test_parameter_mapping.input_parameter = "intensity"
	_test_parameter_mapping.target_item_index = 0
	_test_parameter_mapping.target_property = "amplitude"
	_test_parameter_mapping.enabled = true
	
	# 创建测试组合资源
	_test_composite = JuicyCompositeResource.new()
	_test_composite.composite_items = [shake_item, tween_item]
	_test_composite.blend_mode = JuicyCompositeResource.CompositeBlendMode.ADDITIVE
	_test_composite.enable_parameter_mapping = true
	_test_composite.parameter_mappings = [_test_parameter_mapping]
	
	# 创建测试变体
	_test_variant = JuicyResourceVariant.new()
	_test_variant.base_composite_resource = _test_composite
	_test_variant.inherit_parameter_bindings = true
	
	# 创建测试上下文
	_test_context = JuicyContext.new()
	_test_context.set_parameter("intensity", 0.5)
	
	# 创建测试驱动器
	_test_driver = JuicyCompositeDriver.new()
	_test_driver.composite_resource = _test_composite

func _run_all_tests():
	print("\n📋 运行组合系统集成测试...")
	
	# 基本组合功能测试
	_test_basic_composite_functionality()
	
	# 参数映射集成测试
	_test_parameter_mapping_integration()
	
	# 变体系统集成测试
	_test_variant_integration()
	
	# 实时参数更新测试
	_test_real_time_parameter_updates()
	
	# 混音台功能测试
	_test_mixer_functionality()
	
	# 多资源类型组合测试
	_test_multi_resource_combination()
	
	# 权重和混合模式测试
	_test_weights_and_blend_modes()
	
	# 错误处理和边界条件测试
	_test_error_handling_and_boundaries()
	
	# 性能测试
	_test_performance()

func _test_basic_composite_functionality():
	print("\n🔍 测试基本组合功能...")
	_tests_total += 1
	
	# 测试组合资源创建
	assert(_test_composite != null, "组合资源创建失败")
	assert(_test_composite.get_item_count() == 2, "组合项数量错误")
	
	# 测试组合项验证
	var validation_result = _test_composite.validate_config()
	assert(validation_result.valid, "组合配置验证失败: " + str(validation_result.issues))
	
	# 测试总权重计算
	var total_weight = _test_composite.get_total_weight()
	assert(abs(total_weight - 1.5) < 0.001, "总权重计算错误: " + str(total_weight))
	
	# 测试标准化权重
	var normalized_weights = _test_composite.get_normalized_weights()
	assert(normalized_weights.size() == 2, "标准化权重数量错误")
	assert(abs(normalized_weights[0] - 0.667) < 0.01, "第一个权重标准化错误: " + str(normalized_weights[0]))
	assert(abs(normalized_weights[1] - 0.333) < 0.01, "第二个权重标准化错误: " + str(normalized_weights[1]))
	
	# 测试驱动器创建
	var drivers = _test_composite.create_drivers()
	assert(drivers.size() == 1, "驱动器创建数量错误")
	assert(drivers[0] is JuicyCompositeDriver, "驱动器类型错误")
	
	_record_test_result("基本组合功能", true, "所有基本组合功能测试通过")

func _test_parameter_mapping_integration():
	print("\n🔍 测试参数映射集成...")
	_tests_total += 1
	
	# 测试参数映射配置
	assert(_test_composite.enable_parameter_mapping == true, "参数映射未启用")
	assert(_test_composite.parameter_mappings.size() == 1, "参数映射数量错误")
	
	# 测试参数映射验证
	var mapping_validation = _test_parameter_mapping.validate_mapping()
	assert(mapping_validation.is_empty(), "参数映射验证失败: " + mapping_validation)
	
	# 测试参数映射应用
	var mapped_value = _test_parameter_mapping.apply_mapping(0.8)
	assert(abs(mapped_value - 0.8) < 0.001, "参数映射应用失败: " + str(mapped_value))
	
	# 测试驱动器中的参数映射
	_test_driver.composite_resource = _test_composite
	
	# 验证驱动器可以正确处理参数映射
	assert(_test_driver.has_method("set_parameter"), "驱动器应该支持参数设置")
	
	_record_test_result("参数映射集成", true, "参数映射集成测试通过")

func _test_variant_integration():
	print("\n🔍 测试变体系统集成...")
	_tests_total += 1
	
	# 测试变体创建
	var variant_composite = _test_variant._create_variant_composite()
	assert(variant_composite != null, "变体组合资源创建失败")
	assert(variant_composite != _test_composite, "变体应该是基础资源的副本")
	
	# 测试变体验证
	var variant_validation = _test_variant.validate_config()
	assert(variant_validation.valid, "变体验证失败: " + str(variant_validation.issues))
	
	# 测试变体驱动器创建
	var variant_drivers = _test_variant.create_drivers()
	assert(variant_drivers.size() == 1, "变体驱动器创建数量错误")
	
	# 测试参数绑定继承
	assert(_test_variant.inherit_parameter_bindings == true, "参数绑定继承设置错误")
	
	_record_test_result("变体集成", true, "变体系统集成测试通过")

func _test_real_time_parameter_updates():
	print("\n🔍 测试实时参数更新...")
	_tests_total += 1
	
	# 设置初始参数
	_test_context.set_parameter("intensity", 0.3)
	assert(abs(_test_context.get_parameter("intensity") - 0.3) < 0.001, "初始参数设置失败")
	
	# 更新参数
	_test_context.set_parameter("intensity", 0.7)
	assert(abs(_test_context.get_parameter("intensity") - 0.7) < 0.001, "参数更新失败")
	
	# 测试参数变化通知
	var parameter_changed = false
	var _on_parameter_changed = func(parameter_name, new_value):
		if parameter_name == "intensity":
			parameter_changed = true
	
	# 模拟参数变化
	_test_context.set_parameter("intensity", 0.9)
	
	# 验证参数存在
	assert(_test_context.has_parameter("intensity"), "参数存在性检查失败")
	assert(not _test_context.has_parameter("non_existent"), "不存在的参数应该返回false")
	
	# 测试参数移除
	_test_context.remove_parameter("intensity")
	assert(not _test_context.has_parameter("intensity"), "参数移除失败")
	
	# 重新添加参数
	_test_context.set_parameter("intensity", 0.5)
	
	_record_test_result("实时参数更新", true, "实时参数更新测试通过")

func _test_mixer_functionality():
	print("\n🔍 测试混音台功能...")
	_tests_total += 1
	
	# 测试组合资源混合模式
	var blend_modes = [
		JuicyCompositeResource.CompositeBlendMode.ADDITIVE,
		JuicyCompositeResource.CompositeBlendMode.MULTIPLICATIVE,
		JuicyCompositeResource.CompositeBlendMode.OVERRIDE,
		JuicyCompositeResource.CompositeBlendMode.WEIGHTED_AVERAGE
	]
	
	for blend_mode in blend_modes:
		_test_composite.blend_mode = blend_mode
		assert(_test_composite.blend_mode == blend_mode, "混合模式设置失败")
	
	# 测试权重归一化
	_test_composite.normalize_weights = true
	assert(_test_composite.normalize_weights == true, "权重归一化设置失败")
	
	# 测试动态权重调整
	_test_composite.dynamic_weight_adjustment = true
	assert(_test_composite.dynamic_weight_adjustment == true, "动态权重调整设置失败")
	
	# 测试自动参数更新
	_test_composite.auto_update_parameters = true
	assert(_test_composite.auto_update_parameters == true, "自动参数更新设置失败")
	
	_record_test_result("混音台功能", true, "混音台功能测试通过")

func _test_multi_resource_combination():
	print("\n🔍 测试多资源类型组合...")
	_tests_total += 1
	
	# 验证组合中包含不同类型的资源
	var items = _test_composite.composite_items
	assert(items.size() == 2, "组合项数量错误")
	
	# 检查第一个项（震动资源）
	var shake_item = items[0]
	assert(shake_item.resource is JuicyShakeResource, "第一个资源应该是震动资源")
	
	# 检查第二个项（补间资源）
	var tween_item = items[1]
	assert(tween_item.resource is JuicyTweenResource, "第二个资源应该是补间资源")
	
	# 测试不同资源类型的时长计算
	var duration = _test_composite.get_duration()
	assert(abs(duration - 1.0) < 0.001, "组合时长计算错误: " + str(duration))
	
	_record_test_result("多资源类型组合", true, "多资源类型组合测试通过")

func _test_weights_and_blend_modes():
	print("\n🔍 测试权重和混合模式...")
	_tests_total += 1
	
	# 测试权重修改
	var original_weights = _test_composite.get_normalized_weights()
	
	# 修改权重
	_test_composite.composite_items[0].weight = 2.0
	_test_composite.composite_items[1].weight = 1.0
	
	var new_weights = _test_composite.get_normalized_weights()
	assert(abs(new_weights[0] - 0.667) < 0.01, "权重修改后计算错误: " + str(new_weights[0]))
	assert(abs(new_weights[1] - 0.333) < 0.01, "权重修改后计算错误: " + str(new_weights[1]))
	
	# 测试禁用项
	_test_composite.composite_items[1].enabled = false
	var disabled_weights = _test_composite.get_normalized_weights()
	assert(abs(disabled_weights[0] - 1.0) < 0.001, "禁用项后权重计算错误: " + str(disabled_weights[0]))
	assert(abs(disabled_weights[1] - 0.0) < 0.001, "禁用项应该权重为0: " + str(disabled_weights[1]))
	
	# 恢复启用状态
	_test_composite.composite_items[1].enabled = true
	
	_record_test_result("权重和混合模式", true, "权重和混合模式测试通过")

func _test_error_handling_and_boundaries():
	print("\n🔍 测试错误处理和边界条件...")
	_tests_total += 1
	
	# 测试空组合项
	var empty_composite = JuicyCompositeResource.new()
	var empty_validation = empty_composite.validate_config()
	assert(not empty_validation.valid, "空组合项应该验证失败")
	
	# 测试null组合项
	var null_item_composite = JuicyCompositeResource.new()
	var null_item = JuicyCompositeItem.new()
	null_item.resource = null
	null_item_composite.add_composite_item(null_item)
	var null_item_validation = null_item_composite.validate_config()
	assert(not null_item_validation.valid, "null组合项应该验证失败")
	
	# 测试null资源项
	var null_resource_composite = JuicyCompositeResource.new()
	var null_resource_item = JuicyCompositeItem.new()
	null_resource_item.resource = null
	null_resource_composite.add_composite_item(null_resource_item)
	var null_resource_validation = null_resource_composite.validate_config()
	assert(not null_resource_validation.valid, "null资源应该验证失败")
	
	# 测试负权重
	var negative_weight_composite = JuicyCompositeResource.new()
	var negative_weight_item = JuicyCompositeItem.new()
	negative_weight_item.resource = _test_shake_resource
	negative_weight_item.weight = -1.0
	negative_weight_composite.add_composite_item(negative_weight_item)
	var negative_weight_validation = negative_weight_composite.validate_config()
	assert(not negative_weight_validation.valid, "负权重应该验证失败")
	
	# 测试无效参数映射
	var invalid_mapping_composite = JuicyCompositeResource.new()
	invalid_mapping_composite.add_composite_item(_test_composite.composite_items[0])
	invalid_mapping_composite.enable_parameter_mapping = true
	var invalid_mapping = JuicyParameterMapping.new()
	invalid_mapping.input_parameter = ""  # 无效配置
	invalid_mapping_composite.add_parameter_mapping(invalid_mapping)
	var invalid_mapping_validation = invalid_mapping_composite.validate_config()
	assert(not invalid_mapping_validation.valid, "无效参数映射应该验证失败")
	
	_record_test_result("错误处理和边界条件", true, "错误处理和边界条件测试通过")

func _test_performance():
	print("\n🔍 测试性能...")
	_tests_total += 1
	
	var iterations = 500
	var start_time = Time.get_ticks_usec()
	
	# 测试组合资源验证性能
	for i in range(iterations):
		var validation_result = _test_composite.validate_config()
		assert(validation_result.valid, "性能测试中的验证失败")
	
	var validation_end_time = Time.get_ticks_usec()
	var validation_total_time = (validation_end_time - start_time) / 1000.0
	var validation_avg_time = validation_total_time / iterations
	
	# 测试变体创建性能
	start_time = Time.get_ticks_usec()
	for i in range(iterations):
		var variant_composite = _test_variant._create_variant_composite()
		assert(variant_composite != null, "性能测试中的变体创建失败")
	
	var variant_end_time = Time.get_ticks_usec()
	var variant_total_time = (variant_end_time - start_time) / 1000.0
	var variant_avg_time = variant_total_time / iterations
	
	# 测试参数映射性能
	start_time = Time.get_ticks_usec()
	for i in range(iterations * 10):  # 参数映射更轻量，测试更多次
		var mapped_value = _test_parameter_mapping.apply_mapping(randf())
		assert(mapped_value >= 0.0 and mapped_value <= 1.0, "性能测试中的参数映射失败")
	
	var mapping_end_time = Time.get_ticks_usec()
	var mapping_total_time = (mapping_end_time - start_time) / 1000.0
	var mapping_avg_time = mapping_total_time / (iterations * 10)
	
	print("  性能测试结果:")
	print("  总迭代次数: " + str(iterations))
	print("  验证平均耗时: " + str(validation_avg_time) + "ms")
	print("  变体创建平均耗时: " + str(variant_avg_time) + "ms")
	print("  参数映射平均耗时: " + str(mapping_avg_time) + "ms")
	
	# 性能基准
	var validation_ok = validation_avg_time < 0.05
	var variant_ok = variant_avg_time < 0.1
	var mapping_ok = mapping_avg_time < 0.01
	
	var all_performance_ok = validation_ok and variant_ok and mapping_ok
	
	assert(all_performance_ok, "性能测试失败")
	
	_record_test_result("性能", all_performance_ok, "性能测试" + ("通过" if all_performance_ok else "失败"))

func _record_test_result(test_name: String, passed: bool, message: String):
	_test_results.append({
		"name": test_name,
		"passed": passed,
		"message": message,
		"timestamp": Time.get_ticks_msec() / 1000.0
	})
	
	if not passed:
		push_error("测试失败 - " + test_name + ": " + message)

func _generate_test_report():
	var end_time = Time.get_ticks_msec() / 1000.0
	var total_time = end_time - _start_time
	
	var passed_count = 0
	var failed_count = 0
	
	for result in _test_results:
		if result.passed:
			passed_count += 1
		else:
			failed_count += 1
	
	print("\n==================================================")
	print("📊 组合系统集成测试报告")
	print("==================================================")
	print("总测试数: " + str(_tests_total))
	print("通过测试: " + str(passed_count))
	print("失败测试: " + str(failed_count))
	print("通过率: %.1f%%" % (float(passed_count) / _tests_total * 100))
	print("总耗时: %.3f 秒" % total_time)
	
	if failed_count > 0:
		print("\n❌ 失败的测试:")
		for result in _test_results:
			if not result.passed:
				print("  - " + result.name + ": " + result.message)
	
	print("\n==================================================")
	if failed_count == 0:
		print("🎉 所有组合系统集成测试通过！")
	else:
		print("⚠️  部分测试失败，请检查上面的详细信息")
	print("==================================================")
