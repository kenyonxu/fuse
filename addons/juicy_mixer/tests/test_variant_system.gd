# 变体系统测试
# 测试DataOverride的各种覆盖模式、JuicyResourceVariant的变体创建、数据级别的精确覆盖

extends Node

# 测试状态
var _tests_completed = 0
var _tests_total = 0
var _test_results = []
var _start_time = 0.0

# 测试资源
var _test_base_composite: JuicyCompositeResource
var _test_variant: JuicyResourceVariant
var _test_override_replace: DataOverride
var _test_override_modify: DataOverride
var _test_override_add: DataOverride
var _test_override_remove: DataOverride
var _test_shake_resource: JuicyShakeResource
var _test_shake_data: ShakeData

func _ready():
	print("🧪 开始变体系统测试...")
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
	# 创建测试震动数据
	_test_shake_data = ShakeData.new()
	_test_shake_data.property = "position"
	_test_shake_data.amplitude = 10.0
	_test_shake_data.frequency = 5.0
	_test_shake_data.duration = 1.0
	
	# 创建测试震动资源
	_test_shake_resource = JuicyShakeResource.new()
	# 使用add_shake_data方法，传递正确的参数
	_test_shake_resource.add_shake_data(
		_test_shake_data.property,
		_test_shake_data.amplitude,
		_test_shake_data.frequency,
		_test_shake_data.duration,
		_test_shake_data.falloff,
		_test_shake_data.noise_seed,
		_test_shake_data.octaves,
		_test_shake_data.persistence,
		_test_shake_data.lacunarity
	)
	_test_shake_resource.duration = 1.0
	
	# 创建测试组合项
	var composite_item = JuicyCompositeItem.new()
	composite_item.resource = _test_shake_resource
	composite_item.weight = 1.0
	composite_item.enabled = true
	
	# 创建基础组合资源
	_test_base_composite = JuicyCompositeResource.new()
	_test_base_composite.composite_items = [composite_item]
	_test_base_composite.blend_mode = JuicyCompositeResource.CompositeBlendMode.ADDITIVE
	
	# 创建数据覆盖 - 替换模式
	_test_override_replace = DataOverride.new()
	_test_override_replace.override_mode = DataOverride.OverrideMode.REPLACE_DATA
	_test_override_replace.target_item_index = 0
	_test_override_replace.target_data_index = 0
	_test_override_replace.enabled = true
	
	# 创建新的震动数据用于替换
	var new_shake_data = ShakeData.new()
	new_shake_data.property = "rotation"
	new_shake_data.amplitude = 20.0
	new_shake_data.frequency = 8.0
	new_shake_data.duration = 2.0
	_test_override_replace.new_data = new_shake_data
	
	# 创建数据覆盖 - 修改模式
	_test_override_modify = DataOverride.new()
	_test_override_modify.override_mode = DataOverride.OverrideMode.MODIFY_DATA
	_test_override_modify.target_item_index = 0
	_test_override_modify.target_data_index = 0
	_test_override_modify.property_overrides = {
		"amplitude": 15.0,
		"frequency": 7.0
	}
	_test_override_modify.enabled = true
	
	# 创建数据覆盖 - 添加模式
	_test_override_add = DataOverride.new()
	_test_override_add.override_mode = DataOverride.OverrideMode.ADD_TO_COMPOSITE
	_test_override_add.enabled = true
	
	# 创建新的组合项用于添加
	var new_composite_item = JuicyCompositeItem.new()
	var new_shake_resource = JuicyShakeResource.new()
	var new_data = ShakeData.new()
	new_data.property = "scale"
	new_data.amplitude = 5.0
	new_data.frequency = 3.0
	# 使用add_shake_data方法而不是直接赋值
	new_shake_resource.add_shake_data(
		new_data.property,
		new_data.amplitude,
		new_data.frequency,
		new_data.duration,
		new_data.falloff,
		new_data.noise_seed,
		new_data.octaves,
		new_data.persistence,
		new_data.lacunarity
	)
	new_composite_item.resource = new_shake_resource
	new_composite_item.weight = 0.5
	new_composite_item.enabled = true
	_test_override_add.new_composite_item = new_composite_item
	
	# 创建数据覆盖 - 移除模式
	_test_override_remove = DataOverride.new()
	_test_override_remove.override_mode = DataOverride.OverrideMode.REMOVE_FROM_COMPOSITE
	_test_override_remove.target_item_index = 0
	_test_override_remove.enabled = true
	
	# 创建变体资源
	_test_variant = JuicyResourceVariant.new()
	_test_variant.base_composite_resource = _test_base_composite
	_test_variant.data_overrides = []
	_test_variant.inherit_parameter_bindings = true

func _run_all_tests():
	print("\n📋 运行变体系统测试...")
	
	# DataOverride验证测试
	_test_data_override_validation()
	
	# 替换数据测试
	_test_replace_data()
	
	# 修改数据测试
	_test_modify_data()
	
	# 添加数据测试
	_test_add_data()
	
	# 移除数据测试
	_test_remove_data()
	
	# 变体创建测试
	_test_variant_creation()
	
	# 变体验证测试
	_test_variant_validation()
	
	# 序列化测试
	_test_serialization()
	
	# 错误处理测试
	_test_error_handling()
	
	# 性能测试
	_test_performance()

func _test_data_override_validation():
	print("\n🔍 测试DataOverride验证逻辑...")
	_tests_total += 1
	
	# 测试有效的替换覆盖
	var replace_error = _test_override_replace.validate_override()
	assert(replace_error.is_empty(), "有效的替换覆盖验证失败: " + replace_error)
	
	# 测试有效的修改覆盖
	var modify_error = _test_override_modify.validate_override()
	assert(modify_error.is_empty(), "有效的修改覆盖验证失败: " + modify_error)
	
	# 测试有效的添加覆盖
	var add_error = _test_override_add.validate_override()
	assert(add_error.is_empty(), "有效的添加覆盖验证失败: " + add_error)
	
	# 测试有效的移除覆盖
	var remove_error = _test_override_remove.validate_override()
	assert(remove_error.is_empty(), "有效的移除覆盖验证失败: " + remove_error)
	
	# 测试禁用的覆盖（应该通过验证）
	_test_override_replace.enabled = false
	var disabled_error = _test_override_replace.validate_override()
	assert(disabled_error.is_empty(), "禁用的覆盖应该通过验证")
	_test_override_replace.enabled = true
	
	# 测试无效的替换覆盖（缺少新数据）
	var temp_new_data = _test_override_replace.new_data
	_test_override_replace.new_data = null
	var invalid_replace_error = _test_override_replace.validate_override()
	assert(not invalid_replace_error.is_empty(), "无效的替换覆盖应该验证失败")
	_test_override_replace.new_data = temp_new_data
	
	# 测试无效的修改覆盖（空属性覆盖）
	var temp_overrides = _test_override_modify.property_overrides
	_test_override_modify.property_overrides = {}
	var invalid_modify_error = _test_override_modify.validate_override()
	assert(not invalid_modify_error.is_empty(), "无效的修改覆盖应该验证失败")
	_test_override_modify.property_overrides = temp_overrides
	
	_record_test_result("DataOverride验证", true, "所有DataOverride验证测试通过")

func _test_replace_data():
	print("\n🔍 测试数据替换功能...")
	_tests_total += 1
	
	# 创建变体并应用替换覆盖
	_test_variant.data_overrides = []
	_test_variant.data_overrides.append(_test_override_replace)
	var variant_composite = _test_variant._create_variant_composite()
	
	assert(variant_composite != null, "变体组合资源创建失败")
	assert(variant_composite.get_composite_items().size() == 1, "变体组合项数量错误")
	
	# 验证数据替换
	var item = variant_composite.get_composite_items()[0]
	var resource = item.resource
	assert(resource is JuicyShakeResource, "资源类型错误")
	
	var shake_resource = resource as JuicyShakeResource
	assert(shake_resource.shake_data.size() == 1, "震动数据数量错误")
	
	var replaced_data = shake_resource.shake_data[0]
	print("Debug: amplitude =", replaced_data.amplitude, ", expected 20.0")
	print("Debug: frequency =", replaced_data.frequency, ", expected 8.0")
	print("Debug: duration =", replaced_data.duration, ", expected 2.0")
	assert(replaced_data.property == "rotation", "属性替换失败: got " + replaced_data.property + ", expected rotation")
	assert(abs(replaced_data.amplitude - 20.0) < 0.001, "振幅替换失败: got " + str(replaced_data.amplitude) + ", expected 20.0")
	assert(abs(replaced_data.frequency - 8.0) < 0.001, "频率替换失败: got " + str(replaced_data.frequency) + ", expected 8.0")
	assert(abs(replaced_data.duration - 2.0) < 0.001, "持续时间替换失败: got " + str(replaced_data.duration) + ", expected 2.0")
	
	_record_test_result("数据替换", true, "数据替换功能测试通过")

func _test_modify_data():
	print("\n🔍 测试数据修改功能...")
	_tests_total += 1
	
	# 创建变体并应用修改覆盖
	_test_variant.data_overrides = []
	_test_variant.data_overrides.append(_test_override_modify)
	var variant_composite = _test_variant._create_variant_composite()
	
	assert(variant_composite != null, "变体组合资源创建失败")
	
	# 验证数据修改
	var item = variant_composite.get_composite_items()[0]
	var resource = item.resource
	var shake_resource = resource as JuicyShakeResource
	var modified_data = shake_resource.shake_data[0]
	
	assert(modified_data.property == "position", "基础属性应该保持不变")
	assert(abs(modified_data.amplitude - 15.0) < 0.001, "振幅修改失败")
	assert(abs(modified_data.frequency - 7.0) < 0.001, "频率修改失败")
	assert(abs(modified_data.duration - 1.0) < 0.001, "未修改的属性应该保持不变")
	
	_record_test_result("数据修改", true, "数据修改功能测试通过")

func _test_add_data():
	print("\n🔍 测试数据添加功能...")
	_tests_total += 1
	
	# 创建变体并应用添加覆盖
	_test_variant.data_overrides = []
	_test_variant.data_overrides.append(_test_override_add)
	var variant_composite = _test_variant._create_variant_composite()
	
	assert(variant_composite != null, "变体组合资源创建失败")
	assert(variant_composite.get_composite_items().size() == 2, "添加后组合项数量应该为2")
	
	# 验证新添加的项
	var new_item = variant_composite.get_composite_items()[1]
	assert(new_item.resource is JuicyShakeResource, "新添加的资源类型错误")
	
	var new_shake_resource = new_item.resource as JuicyShakeResource
	assert(new_shake_resource.shake_data.size() == 1, "新添加的震动数据数量错误")
	
	var new_data = new_shake_resource.shake_data[0]
	assert(new_data.property == "scale", "新数据属性错误")
	assert(abs(new_data.amplitude - 5.0) < 0.001, "新数据振幅错误")
	assert(abs(new_data.frequency - 3.0) < 0.001, "新数据频率错误")
	
	_record_test_result("数据添加", true, "数据添加功能测试通过")

func _test_remove_data():
	print("\n🔍 测试数据移除功能...")
	_tests_total += 1
	
	# 创建变体并应用移除覆盖
	_test_variant.data_overrides = []
	_test_variant.data_overrides.append(_test_override_remove)
	var variant_composite = _test_variant._create_variant_composite()
	
	assert(variant_composite != null, "变体组合资源创建失败")
	assert(variant_composite.get_composite_items().size() == 0, "移除后组合项数量应该为0")
	
	_record_test_result("数据移除", true, "数据移除功能测试通过")

func _test_variant_creation():
	print("\n🔍 测试变体创建功能...")
	_tests_total += 1
	
	# 测试创建驱动器
	_test_variant.data_overrides = []
	var drivers = _test_variant.create_drivers()
	assert(drivers.size() > 0, "变体驱动器创建失败")
	
	# 测试变体组合资源创建
	var variant_composite = _test_variant._create_variant_composite()
	assert(variant_composite != null, "变体组合资源创建失败")
	assert(variant_composite != _test_base_composite, "变体应该是基础资源的副本")
	
	# 验证变体属性
	assert(variant_composite.get_composite_items().size() == 1, "变体组合项数量错误")
	
	_record_test_result("变体创建", true, "变体创建功能测试通过")

func _test_variant_validation():
	print("\n🔍 测试变体验证逻辑...")
	_tests_total += 1
	
	# 测试有效配置
	var valid_result = _test_variant.validate_config()
	assert(valid_result.valid, "有效配置验证失败: " + str(valid_result.issues))
	
	# 测试null基础资源
	var temp_base = _test_variant.base_composite_resource
	_test_variant.base_composite_resource = null
	var null_base_result = _test_variant.validate_config()
	assert(not null_base_result.valid, "null基础资源应该验证失败")
	_test_variant.base_composite_resource = temp_base
	
	# 测试null数据覆盖
	_test_variant.data_overrides = [null]
	var null_override_result = _test_variant.validate_config()
	assert(not null_override_result.valid, "null数据覆盖应该验证失败")
	_test_variant.data_overrides = []
	
	_record_test_result("变体验证", true, "所有变体验证测试通过")

func _test_serialization():
	print("\n🔍 测试序列化和反序列化...")
	_tests_total += 1
	
	# 测试配置字典生成
	var config_dict = _test_override_replace.get_config_dict()
	assert(config_dict.has("override_mode"), "配置字典缺少override_mode")
	assert(config_dict.has("target_item_index"), "配置字典缺少target_item_index")
	assert(config_dict.has("target_data_index"), "配置字典缺少target_data_index")
	assert(config_dict.has("property_overrides"), "配置字典缺少property_overrides")
	assert(config_dict.has("enabled"), "配置字典缺少enabled")
	
	# 测试从字典加载
	var new_override = DataOverride.new()
	var load_success = new_override.load_from_dict(config_dict)
	assert(load_success, "从字典加载失败")
	assert(new_override.override_mode == _test_override_replace.override_mode, "加载后override_mode错误")
	assert(new_override.target_item_index == _test_override_replace.target_item_index, "加载后target_item_index错误")
	assert(new_override.target_data_index == _test_override_replace.target_data_index, "加载后target_data_index错误")
	assert(new_override.enabled == _test_override_replace.enabled, "加载后enabled错误")
	
	# 测试变体配置序列化
	var variant_config = _test_variant.get_config_dict()
	assert(variant_config.has("inherit_parameter_bindings"), "变体配置字典缺少inherit_parameter_bindings")
	assert(variant_config["inherit_parameter_bindings"] == true, "变体配置inherit_parameter_bindings值错误")
	
	_record_test_result("序列化", true, "所有序列化测试通过")

func _test_error_handling():
	print("\n🔍 测试错误处理...")
	_tests_total += 1
	
	# 测试null基础资源
	var temp_base = _test_variant.base_composite_resource
	_test_variant.base_composite_resource = null
	var null_base_variant = _test_variant._create_variant_composite()
	assert(null_base_variant == null, "null基础资源应该返回null")
	_test_variant.base_composite_resource = temp_base
	
	# 测试无效的基础资源类型 - 跳过这个测试，因为类型系统不允许
	# JuicyResourceVariant的base_composite_resource属性类型为JuicyCompositeResource
	# 无法在运行时赋值其他类型的资源
	print("  跳过无效基础资源类型测试（类型系统保护）")
	
	# 测试应用无效的覆盖模式
	var invalid_override = DataOverride.new()
	invalid_override.override_mode = 999  # 无效的模式
	invalid_override.enabled = true
	_test_variant.data_overrides = [invalid_override]
	
	# 这应该不会产生错误，但会记录错误信息
	var variant_with_invalid_override = _test_variant._create_variant_composite()
	assert(variant_with_invalid_override != null, "即使有不无效的覆盖，变体创建也应该成功")
	
	_test_variant.data_overrides = []
	
	_record_test_result("错误处理", true, "所有错误处理测试通过")

func _test_performance():
	print("\n🔍 测试性能...")
	_tests_total += 1
	
	var iterations = 100  # 减少迭代次数以避免输出过多
	var start_time = Time.get_ticks_usec()
	
	# 测试变体创建性能
	for i in range(iterations):
		_test_variant.data_overrides = []
		_test_variant.data_overrides.append(_test_override_modify)
		var variant_composite = _test_variant._create_variant_composite()
		assert(variant_composite != null, "性能测试中的变体创建失败")
	
	var end_time = Time.get_ticks_usec()
	var total_time = (end_time - start_time) / 1000.0  # 转换为毫秒
	var avg_time = total_time / iterations
	
	print("  性能测试结果:")
	print("  总迭代次数: " + str(iterations))
	print("  总耗时: " + str(total_time) + "ms")
	print("  平均每次变体创建耗时: " + str(avg_time) + "ms")
	
	# 性能基准：每次变体创建应该小于0.1ms
	var performance_ok = avg_time < 0.1
	assert(performance_ok, "性能测试失败: 平均耗时 " + str(avg_time) + "ms 超过基准 0.1ms")
	
	_record_test_result("性能", performance_ok, "性能测试" + ("通过" if performance_ok else "失败"))

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
	print("📊 变体系统测试报告")
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
		print("🎉 所有变体系统测试通过！")
	else:
		print("⚠️  部分测试失败，请检查上面的详细信息")
	print("==================================================")