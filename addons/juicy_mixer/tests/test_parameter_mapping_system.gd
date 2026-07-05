# 参数映射系统测试
# 测试JuicyParameterMapping的基本功能、验证逻辑、曲线映射、序列化和错误处理

extends Node

# 测试状态
var _tests_completed = 0
var _tests_total = 0
var _test_results = []
var _start_time = 0.0

# 测试资源
var _test_mapping: JuicyParameterMapping
var _test_curve: Curve
var _test_composite: JuicyCompositeResource
var _test_item: JuicyCompositeItem
var _test_feedback_resource: JuicyShakeResource

func _ready():
	print("🧪 开始参数映射系统测试...")
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
	# 创建测试曲线
	_test_curve = Curve.new()
	_test_curve.add_point(Vector2(0, 0))
	_test_curve.add_point(Vector2(0.5, 0.8))
	_test_curve.add_point(Vector2(1, 1))
	
	# 创建测试反馈资源
	_test_feedback_resource = JuicyShakeResource.new()
	
	# 创建测试组合项
	_test_item = JuicyCompositeItem.new()
	_test_item.resource = _test_feedback_resource
	_test_item.weight = 1.0
	_test_item.enabled = true
	
	# 创建测试组合资源
	_test_composite = JuicyCompositeResource.new()
	_test_composite.composite_items = [_test_item]
	
	# 创建测试参数映射
	_test_mapping = JuicyParameterMapping.new()
	_test_mapping.input_parameter = "intensity"
	_test_mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_VALUE
	_test_mapping.target_item_index = 0
	_test_mapping.target_property = "volume"
	_test_mapping.curve = _test_curve
	_test_mapping.enabled = true
	_test_mapping.input_range = Vector2(0.0, 1.0)
	_test_mapping.output_range = Vector2(0.0, 1.0)

func _run_all_tests():
	print("\n📋 运行参数映射系统测试...")
	
	# 基本功能测试
	_test_basic_functionality()
	
	# 验证逻辑测试
	_test_validation_logic()
	
	# 曲线映射测试
	_test_curve_mapping()
	
	# 序列化和反序列化测试
	_test_serialization()
	
	# 错误处理测试
	_test_error_handling()
	
	# 边界条件测试
	_test_boundary_conditions()
	
	# 性能测试
	_test_performance()

func _test_basic_functionality():
	print("\n🔍 测试基本功能...")
	_tests_total += 1
	
	# 测试映射创建
	assert(_test_mapping != null, "参数映射创建失败")
	assert(_test_mapping.input_parameter == "intensity", "输入参数名设置错误")
	assert(_test_mapping.mapping_type == JuicyParameterMapping.MappingType.TRACK_VALUE, "映射类型设置错误")
	assert(_test_mapping.target_item_index == 0, "目标项索引设置错误")
	assert(_test_mapping.target_property == "volume", "目标属性设置错误")
	assert(_test_mapping.enabled == true, "启用状态设置错误")
	
	# 测试描述信息
	var description = _test_mapping.get_description()
	assert(description.contains("intensity"), "描述信息应包含输入参数名")
	assert(description.contains("volume"), "描述信息应包含目标属性")
	assert(description.contains("with curve mapping"), "曲线映射描述错误")
	
	_record_test_result("基本功能", true, "所有基本功能测试通过")

func _test_validation_logic():
	print("\n🔍 测试验证逻辑...")
	_tests_total += 1
	
	# 测试有效配置
	var valid_error = _test_mapping.validate_mapping()
	assert(valid_error.is_empty(), "有效配置验证失败: " + valid_error)
	
	# 测试空输入参数
	_test_mapping.input_parameter = ""
	var empty_input_error = _test_mapping.validate_mapping()
	assert(not empty_input_error.is_empty(), "空输入参数应该验证失败")
	_test_mapping.input_parameter = "intensity"
	
	# 测试空目标属性
	_test_mapping.target_property = ""
	var empty_property_error = _test_mapping.validate_mapping()
	assert(not empty_property_error.is_empty(), "空目标属性应该验证失败")
	_test_mapping.target_property = "volume"
	
	# 测试负目标项索引
	_test_mapping.target_item_index = -1
	var negative_index_error = _test_mapping.validate_mapping()
	assert(not negative_index_error.is_empty(), "负目标项索引应该验证失败")
	_test_mapping.target_item_index = 0
	
	_record_test_result("验证逻辑", true, "所有验证逻辑测试通过")

func _test_curve_mapping():
	print("\n🔍 测试曲线映射...")
	_tests_total += 1
	
	# 测试直接映射（无曲线）
	_test_mapping.curve = null
	var direct_value = _test_mapping.apply_mapping(0.5)
	assert(abs(direct_value - 0.5) < 0.001, "直接映射失败: " + str(direct_value))
	
	# 测试曲线映射
	_test_mapping.curve = _test_curve
	var curve_value = _test_mapping.apply_mapping(0.5)
	var expected_value = _test_curve.sample(0.5)
	assert(abs(curve_value - expected_value) < 0.001, "曲线映射失败: " + str(curve_value))
	
	# 测试边界值
	var zero_value = _test_mapping.apply_mapping(0.0)
	var one_value = _test_mapping.apply_mapping(1.0)
	assert(abs(zero_value - 0.0) < 0.001, "0值映射失败: " + str(zero_value))
	assert(abs(one_value - 1.0) < 0.001, "1值映射失败: " + str(one_value))
	
	# 测试超出范围的输入值
	var clamped_value = _test_mapping.apply_mapping(1.5)
	assert(clamped_value <= 1.0, "超出范围的值应该被限制: " + str(clamped_value))
	
	# 测试禁用状态
	_test_mapping.enabled = false
	var disabled_value = _test_mapping.apply_mapping(0.5)
	assert(disabled_value == 0.0, "禁用状态应该返回0: " + str(disabled_value))
	_test_mapping.enabled = true
	
	_record_test_result("曲线映射", true, "所有曲线映射测试通过")

func _test_serialization():
	print("\n🔍 测试序列化和反序列化...")
	_tests_total += 1
	
	# 测试配置字典生成
	var config_dict = _test_mapping.get_config_dict()
	assert(config_dict.has("input_parameter"), "配置字典缺少input_parameter")
	assert(config_dict.has("target_item_index"), "配置字典缺少target_item_index")
	assert(config_dict.has("target_property"), "配置字典缺少target_property")
	assert(config_dict.has("enabled"), "配置字典缺少enabled")
	assert(config_dict["input_parameter"] == "intensity", "配置字典input_parameter值错误")
	assert(config_dict["target_item_index"] == 0, "配置字典target_item_index值错误")
	assert(config_dict["target_property"] == "volume", "配置字典target_property值错误")
	assert(config_dict["enabled"] == true, "配置字典enabled值错误")
	
	# 测试从字典加载
	var new_mapping = JuicyParameterMapping.new()
	var load_success = new_mapping.load_from_dict(config_dict)
	assert(load_success, "从字典加载失败")
	assert(new_mapping.input_parameter == "intensity", "加载后input_parameter错误")
	assert(new_mapping.target_item_index == 0, "加载后target_item_index错误")
	assert(new_mapping.target_property == "volume", "加载后target_property错误")
	assert(new_mapping.enabled == true, "加载后enabled错误")
	
	# 测试空字典加载（空字典应该加载成功，返回默认值）
	var empty_load_success = new_mapping.load_from_dict({})
	assert(empty_load_success, "空字典加载应该成功")
	
	# 验证空字典加载后，映射保持默认值
	assert(new_mapping.input_parameter == "intensity", "空字典加载后应保持原值")
	assert(new_mapping.target_item_index == 0, "空字典加载后应保持原值")
	assert(new_mapping.target_property == "volume", "空字典加载后应保持原值")
	
	# 测试无效字典加载（使用不包含必要字段的字典）
	var invalid_dict = {"invalid_field": "value"}
	var invalid_load_success = new_mapping.load_from_dict(invalid_dict)
	assert(invalid_load_success, "包含无效字段的字典加载应该成功（忽略无效字段）")
	
	_record_test_result("序列化", true, "所有序列化测试通过")

func _test_error_handling():
	print("\n🔍 测试错误处理...")
	_tests_total += 1
	
	# 测试null组合资源验证
	var null_composite_error = _test_mapping._validate_target_item_index(null)
	assert(not null_composite_error.is_empty(), "null组合资源应该验证失败")
	
	# 测试超出范围的项索引
	_test_mapping.target_item_index = 10
	var out_of_bounds_error = _test_mapping._validate_target_item_index(_test_composite)
	assert(not out_of_bounds_error.is_empty(), "超出范围的项索引应该验证失败")
	_test_mapping.target_item_index = 0
	
	# 测试null项资源
	var null_item_composite = JuicyCompositeResource.new()
	var null_item = JuicyCompositeItem.new()
	null_item.resource = null  # 设置resource为null，但item本身不为null
	null_item_composite.add_composite_item(null_item)
	_test_mapping.target_item_index = 0
	var null_item_error = _test_mapping._validate_target_item_index(null_item_composite)
	assert(not null_item_error.is_empty(), "null项应该验证失败")
	_test_mapping.target_item_index = 0
	
	# 测试null目标资源
	var null_resource_error = _test_mapping._validate_target_property(null)
	assert(not null_resource_error.is_empty(), "null目标资源应该验证失败")
	
	_record_test_result("错误处理", true, "所有错误处理测试通过")

func _test_boundary_conditions():
	print("\n🔍 测试边界条件...")
	_tests_total += 1
	
	# 测试极端输入值
	var extreme_values = [-1000.0, -1.0, 0.0, 1.0, 1000.0, 999999.0]
	for value in extreme_values:
		var result = _test_mapping.apply_mapping(value)
		assert(result >= 0.0 and result <= 1.0, "极端值映射超出范围: " + str(value) + " -> " + str(result))
	
	# 测试空曲线
	_test_mapping.curve = Curve.new()
	var empty_curve_result = _test_mapping.apply_mapping(0.5)
	assert(abs(empty_curve_result - 0.5) < 0.001, "空曲线映射失败: " + str(empty_curve_result))
	
	# 测试单点曲线
	_test_mapping.curve.add_point(Vector2(0.5, 0.8))
	var single_point_result = _test_mapping.apply_mapping(0.5)
	assert(abs(single_point_result - 0.8) < 0.001, "单点曲线映射失败: " + str(single_point_result))
	
	_record_test_result("边界条件", true, "所有边界条件测试通过")

func _test_performance():
	print("\n🔍 测试性能...")
	_tests_total += 1
	
	var iterations = 10000
	var start_time = Time.get_ticks_usec()
	
	# 测试映射应用性能
	for i in range(iterations):
		var input_value = randf()
		_test_mapping.apply_mapping(input_value)
	
	var end_time = Time.get_ticks_usec()
	var total_time = (end_time - start_time) / 1000.0  # 转换为毫秒
	var avg_time = total_time / iterations
	
	print("  性能测试结果:")
	print("  总迭代次数: " + str(iterations))
	print("  总耗时: " + str(total_time) + "ms")
	print("  平均每次映射耗时: " + str(avg_time) + "ms")
	
	# 性能基准：每次映射应该小于0.01ms
	var performance_ok = avg_time < 0.01
	assert(performance_ok, "性能测试失败: 平均耗时 " + str(avg_time) + "ms 超过基准 0.01ms")
	
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
	print("📊 参数映射系统测试报告")
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
		print("🎉 所有参数映射系统测试通过！")
	else:
		print("⚠️  部分测试失败，请检查上面的详细信息")
	print("==================================================")
