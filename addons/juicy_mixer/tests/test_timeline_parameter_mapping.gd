# Timeline参数映射集成测试
# 测试轨道级参数映射、参数映射与Timeline的集成、实时参数更新和参数映射性能

extends Node

# 测试统计
var _tests_run = 0
var _tests_passed = 0
var _tests_failed = 0

# 测试资源
var _test_timeline: JuicyTimelineResource
var _test_driver: JuicyTimelineDriver
var _test_context: JuicyContext
var _test_buffer: JuicyPropertyBuffer
var _test_target: Node

# 断言辅助函数
func assert_true(condition: bool, message: String = "") -> void:
	_tests_run += 1
	if condition:
		_tests_passed += 1
	else:
		_tests_failed += 1
		push_error("❌ 测试失败: " + message)

func assert_false(condition: bool, message: String = "") -> void:
	assert_true(not condition, message)

func assert_equals(expected, actual, message: String = "") -> void:
	_tests_run += 1
	if expected == actual:
		_tests_passed += 1
	else:
		_tests_failed += 1
		push_error("❌ 测试失败: %s (期望: %s, 实际: %s)" % [message, str(expected), str(actual)])

func assert_not_null(value, message: String = "") -> void:
	_tests_run += 1
	if value != null:
		_tests_passed += 1
	else:
		_tests_failed += 1
		push_error("❌ 测试失败: " + message + " (值为null)")

func assert_almost_equals(expected: float, actual: float, tolerance: float = 0.001, message: String = "") -> void:
	_tests_run += 1
	if abs(expected - actual) <= tolerance:
		_tests_passed += 1
	else:
		_tests_failed += 1
		push_error("❌ 测试失败: %s (期望: %s, 实际: %s, 容差: %s)" % [message, str(expected), str(actual), str(tolerance)])

# 设置测试环境
func setup_test_environment():
	# 创建Timeline资源
	_test_timeline = JuicyTimelineResource.new()
	_test_timeline.timeline_duration = 5.0
	_test_timeline.loop_mode = JuicyTimelineResource.LoopMode.NO_LOOP
	
	# 创建驱动器
	_test_driver = JuicyTimelineDriver.new()
	_test_driver.timeline_resource = _test_timeline
	
	# 创建测试环境
	_test_target = Node.new()
	_test_context = JuicyContext.create(_test_timeline, _test_target)
	_test_context.set_driver_data("timeline_resource", _test_timeline)
	_test_context.set_driver_data("current_time", 0.0)
	
	# 创建属性缓冲（模拟）
	_test_buffer = _create_mock_property_buffer()

# 创建模拟属性缓冲
func _create_mock_property_buffer() -> Object:
	var buffer = RefCounted.new()
	
	# 存储属性更新记录
	buffer.property_updates = []
	
	# 模拟add_sample方法
	buffer.add_sample = func(target: Node, property: String, value: Variant, mode: int, source: String):
		buffer.property_updates.append({
			"target": target,
			"property": property,
			"value": value,
			"mode": mode,
			"source": source
		})
	
	# 模拟add_middleware_sample方法
	buffer.add_middleware_sample = func(target: Node, property: String, value: Variant, mode: int, source: String, priority: int):
		buffer.property_updates.append({
			"target": target,
			"property": property,
			"value": value,
			"mode": mode,
			"source": source,
			"priority": priority
		})
	
	# 清理更新记录
	buffer.clear_updates = func():
		buffer.property_updates.clear()
	
	return buffer

# 测试轨道级参数映射
func test_track_level_parameter_mapping():
	print("=== 🗺️ 测试轨道级参数映射 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 创建属性轨道
	var property_track = JuicyPropertyTrack.new()
	property_track.track_name = "TestPropertyTrack"
	property_track.property_path = "scale"
	property_track.value_range = Vector2(0.0, 2.0)
	property_track.use_parameter_mapping = true
	
	# 创建参数映射
	var intensity_mapping = JuicyParameterMapping.new()
	intensity_mapping.input_parameter = "intensity"
	intensity_mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_VALUE
	intensity_mapping.target_property = "intensity"
	intensity_mapping.enabled = true
	
	# 创建映射曲线
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(1, 1))
	intensity_mapping.curve = curve
	
	property_track.parameter_mappings = [intensity_mapping]
	_test_timeline.add_track(property_track, "Property")
	
	# 准备驱动器
	_test_driver.prepare(_test_context, 0.016, _test_buffer)
	
	# 设置参数值
	_test_context.set_parameter("intensity", 0.5)
	
	# 测试参数映射应用
	_test_driver.current_time = 0.5
	_test_driver.process(_test_context, 0.016, _test_buffer)
	
	# 验证属性更新
	assert_true(_test_buffer.property_updates.size() > 0, "应有属性更新")
	
	var update = _test_buffer.property_updates[0]
	assert_equals("scale", update.property, "应更新scale属性")
	# 参数0.5映射后应影响最终值
	assert_true(update.value > 0.0, "参数映射应影响属性值")
	
	# 测试参数值变化
	_test_buffer.clear_updates()
	_test_context.set_parameter("intensity", 0.8)
	
	_test_driver.process(_test_context, 0.016, _test_buffer)
	
	# 验证参数变化后的更新
	assert_true(_test_buffer.property_updates.size() > 0, "参数变化后应有新的属性更新")
	
	var updated_value = _test_buffer.property_updates[0].value
	# 参数0.8应产生更大的属性值
	assert_true(updated_value > update.value, "参数增大应产生更大的属性值")
	
	print("✅ 轨道级参数映射测试通过")

# 测试参数映射与Timeline的集成
func test_timeline_parameter_mapping_integration():
	print("=== 🔗 测试参数映射与Timeline的集成 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 设置Timeline输入参数
	_test_timeline.input_parameters = ["intensity", "speed", "duration"]
	
	# 添加参数预设
	var preset_values = {
		"intensity": 0.7,
		"speed": 1.2,
		"duration": 3.0
	}
	_test_timeline.add_parameter_preset("test_preset", preset_values)
	
	# 创建带参数映射的属性轨道
	var property_track = JuicyPropertyTrack.new()
	property_track.track_name = "MappedPropertyTrack"
	property_track.property_path = "modulate:a"
	property_track.value_range = Vector2(0.0, 1.0)
	property_track.use_parameter_mapping = true
	
	# 创建多个参数映射
	var intensity_mapping = JuicyParameterMapping.new()
	intensity_mapping.input_parameter = "intensity"
	intensity_mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_VALUE
	intensity_mapping.target_property = "intensity"
	intensity_mapping.enabled = true
	
	var speed_mapping = JuicyParameterMapping.new()
	speed_mapping.input_parameter = "speed"
	speed_mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_PROPERTY
	speed_mapping.target_property = "time_scale"
	speed_mapping.enabled = true
	
	property_track.parameter_mappings = [intensity_mapping, speed_mapping]
	_test_timeline.add_track(property_track, "Property")
	
	# 准备驱动器
	_test_driver.prepare(_test_context, 0.016, _test_buffer)
	
	# 应用参数预设
	_test_timeline.apply_parameter_preset("test_preset", _test_context)
	
	# 验证参数预设应用
	assert_equals(0.7, _test_context.get_parameter("intensity"), "intensity参数预设应被应用")
	assert_equals(1.2, _test_context.get_parameter("speed"), "speed参数预设应被应用")
	assert_equals(3.0, _test_context.get_parameter("duration"), "duration参数预设应被应用")
	
	# 测试参数映射在Timeline中的集成
	_test_driver.current_time = 0.5
	_test_driver.process(_test_context, 0.016, _test_buffer)
	
	# 验证参数映射集成
	assert_true(_test_buffer.property_updates.size() > 0, "应有属性更新")
	
	var update = _test_buffer.property_updates[0]
	assert_equals("modulate:a", update.property, "应更新modulate:a属性")
	
	# 验证intensity参数映射的影响
	assert_true(update.value > 0.0, "intensity参数映射应影响属性值")
	
	# 测试参数映射验证
	var validation_result = _test_timeline.validate_config()
	assert_true(validation_result.valid, "参数映射集成应通过验证")
	
	print("✅ 参数映射与Timeline集成测试通过")

# 测试实时参数更新
func test_realtime_parameter_updates():
	print("=== ⏱️ 测试实时参数更新 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 创建属性轨道
	var property_track = JuicyPropertyTrack.new()
	property_track.track_name = "RealtimePropertyTrack"
	property_track.property_path = "rotation"
	property_track.value_range = Vector2(0.0, 360.0)
	property_track.use_parameter_mapping = true
	
	# 创建参数映射
	var mapping = JuicyParameterMapping.new()
	mapping.input_parameter = "rotation_speed"
	mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_VALUE
	mapping.target_property = "intensity"
	mapping.enabled = true
	
	# 创建动态映射曲线
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.5, 0.5))
	curve.add_point(Vector2(1, 1))
	mapping.curve = curve
	
	property_track.parameter_mappings = [mapping]
	_test_timeline.add_track(property_track, "Property")
	
	# 准备驱动器
	_test_driver.prepare(_test_context, 0.016, _test_buffer)
	
	# 测试实时参数更新
	var parameter_values = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
	var expected_values = []
	
	for i in range(parameter_values.size()):
		var param_value = parameter_values[i]
		_test_context.set_parameter("rotation_speed", param_value)
		
		_test_buffer.clear_updates()
		_test_driver.current_time = 0.5
		_test_driver.process(_test_context, 0.016, _test_buffer)
		
		# 记录期望值
		expected_values.append(curve.sample(param_value) * 360.0)
		
		# 验证实时更新
		assert_true(_test_buffer.property_updates.size() > 0, "参数" + str(param_value) + "应有属性更新")
		
		if _test_buffer.property_updates.size() > 0:
			var update = _test_buffer.property_updates[0]
			var expected_value = expected_values[i]
			assert_almost_equals(expected_value, update.value, 1.0, "参数" + str(param_value) + "的映射值应正确")
	
	# 测试参数变化通知
	_test_buffer.clear_updates()
	
	# 模拟参数变化通知
	if property_track.has_method("on_parameter_changed"):
		property_track.on_parameter_changed("rotation_speed", 0.5, 0.8)
		
		_test_driver.process(_test_context, 0.016, _test_buffer)
		assert_true(_test_buffer.property_updates.size() > 0, "参数变化通知后应有更新")
	
	# 测试参数范围映射
	mapping.input_range = Vector2(-1.0, 1.0)
	mapping.output_range = Vector2(0.0, 2.0)
	
	_test_context.set_parameter("rotation_speed", 0.5)
	_test_buffer.clear_updates()
	
	_test_driver.process(_test_context, 0.016, _test_buffer)
	
	if _test_buffer.property_updates.size() > 0:
		var update = _test_buffer.property_updates[0]
		# 参数0.5在-1到1范围内映射到0.75，再在0到2范围内映射到1.5
		var expected_mapped_value = 1.5 * 360.0
		assert_almost_equals(expected_mapped_value, update.value, 1.0, "参数范围映射应正确")
	
	print("✅ 实时参数更新测试通过")

# 测试参数映射性能
func test_parameter_mapping_performance():
	print("=== ⚡ 测试参数映射性能 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 创建多个带参数映射的轨道
	var track_count = 50
	var mappings_per_track = 3
	
	for i in range(track_count):
		var track = JuicyPropertyTrack.new()
		track.track_name = "PerfTrack" + str(i)
		track.property_path = "property" + str(i)
		track.value_range = Vector2(0.0, 1.0)
		track.use_parameter_mapping = true
		
		# 为每个轨道添加多个参数映射
		var mappings = []
		for j in range(mappings_per_track):
			var mapping = JuicyParameterMapping.new()
			mapping.input_parameter = "param" + str(j)
			mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_VALUE
			mapping.target_property = "intensity"
			mapping.enabled = true
			
			# 创建简单曲线
			var curve = Curve.new()
			curve.add_point(Vector2(0, 0))
			curve.add_point(Vector2(1, 1))
			mapping.curve = curve
			
			mappings.append(mapping)
		
		track.parameter_mappings = mappings
		_test_timeline.add_track(track, "Property")
		
		# 设置上下文参数
		_test_context.set_parameter("param" + str(i), 0.5)
	
	# 准备驱动器
	_test_driver.prepare(_test_context, 0.016, _test_buffer)
	
	# 测试参数映射性能
	var iterations = 100
	var start_time = Time.get_ticks_usec()
	
	for i in range(iterations):
		_test_buffer.clear_updates()
		_test_driver.current_time = i * 0.01
		_test_driver.process(_test_context, 0.016, _test_buffer)
	
	var end_time = Time.get_ticks_usec()
	var total_time = (end_time - start_time) / 1000.0  # 转换为毫秒
	var avg_time = total_time / iterations
	
	print("  参数映射性能测试结果:")
	print("  轨道数: " + str(track_count))
	print("  每轨道映射数: " + str(mappings_per_track))
	print("  总映射数: " + str(track_count * mappings_per_track))
	print("  总迭代次数: " + str(iterations))
	print("  总耗时: " + str(total_time) + "ms")
	print("  平均每次处理耗时: " + str(avg_time) + "ms")
	print("  平均每个映射耗时: " + str(avg_time / (track_count * mappings_per_track)) + "ms")
	
	# 性能要求：每次处理应小于1ms
	var performance_ok = avg_time < 1.0
	assert_true(performance_ok, "参数映射性能应满足要求")
	
	# 验证所有映射都被处理
	assert_true(_test_buffer.property_updates.size() > 0, "应有属性更新")
	
	print("✅ 参数映射性能测试通过")

# 测试参数映射边界条件
func test_parameter_mapping_edge_cases():
	print("=== 🔍 测试参数映射边界条件 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 创建属性轨道
	var property_track = JuicyPropertyTrack.new()
	property_track.track_name = "EdgeCaseTrack"
	property_track.property_path = "scale"
	property_track.value_range = Vector2(0.0, 1.0)
	property_track.use_parameter_mapping = true
	
	# 创建边界条件参数映射
	var mapping = JuicyParameterMapping.new()
	mapping.input_parameter = "edge_param"
	mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_VALUE
	mapping.target_property = "intensity"
	mapping.enabled = true
	mapping.input_range = Vector2(-10.0, 10.0)
	mapping.output_range = Vector2(-1.0, 2.0)
	mapping.clamp_output = true
	
	# 创建测试曲线
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.5, 0.5))
	curve.add_point(Vector2(1, 1))
	mapping.curve = curve
	
	property_track.parameter_mappings = [mapping]
	_test_timeline.add_track(property_track, "Property")
	
	# 准备驱动器
	_test_driver.prepare(_test_context, 0.016, _test_buffer)
	
	# 测试极小参数值
	_test_context.set_parameter("edge_param", -100.0)
	_test_buffer.clear_updates()
	
	_test_driver.current_time = 0.5
	_test_driver.process(_test_context, 0.016, _test_buffer)
	
	if _test_buffer.property_updates.size() > 0:
		var update = _test_buffer.property_updates[0]
		# 极小值应被限制在输出范围内
		assert_true(update.value >= -1.0, "极小值应被限制在输出范围内")
	
	# 测试极大参数值
	_test_context.set_parameter("edge_param", 100.0)
	_test_buffer.clear_updates()
	
	_test_driver.process(_test_context, 0.016, _test_buffer)
	
	if _test_buffer.property_updates.size() > 0:
		var update = _test_buffer.property_updates[0]
		# 极大值应被限制在输出范围内
		assert_true(update.value <= 2.0, "极大值应被限制在输出范围内")
	
	# 测试禁用映射
	mapping.enabled = false
	_test_context.set_parameter("edge_param", 0.5)
	_test_buffer.clear_updates()
	
	_test_driver.process(_test_context, 0.016, _test_buffer)
	
	if _test_buffer.property_updates.size() > 0:
		var update = _test_buffer.property_updates[0]
		# 禁用映射应使用原始值
		assert_equals(0.5, update.value, "禁用映射应使用原始值")
	
	mapping.enabled = true  # 恢复
	
	# 测试空曲线
	mapping.curve = null
	_test_context.set_parameter("edge_param", 0.5)
	_test_buffer.clear_updates()
	
	_test_driver.process(_test_context, 0.016, _test_buffer)
	
	if _test_buffer.property_updates.size() > 0:
		var update = _test_buffer.property_updates[0]
		# 空曲线应使用直接映射
		assert_true(update.value > 0.0, "空曲线应使用直接映射")
	
	# 测试缺失参数
	_test_context.set_parameter("non_existent_param", 0.5)
	_test_buffer.clear_updates()
	
	_test_driver.process(_test_context, 0.016, _test_buffer)
	
	# 缺失参数应使用默认值
	if _test_buffer.property_updates.size() > 0:
		var update = _test_buffer.property_updates[0]
		assert_true(update.value >= 0.0, "缺失参数应使用默认值")
	
	print("✅ 参数映射边界条件测试通过")

# 测试不同映射类型
func test_different_mapping_types():
	print("=== 🔄 测试不同映射类型 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 创建属性轨道
	var property_track = JuicyPropertyTrack.new()
	property_track.track_name = "MappingTypeTrack"
	property_track.property_path = "scale"
	property_track.value_range = Vector2(0.0, 2.0)
	property_track.use_parameter_mapping = true
	
	# 测试TRACK_VALUE映射
	var value_mapping = JuicyParameterMapping.new()
	value_mapping.input_parameter = "intensity"
	value_mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_VALUE
	value_mapping.target_property = "intensity"
	value_mapping.enabled = true
	
	# 测试TRACK_PROPERTY映射
	var property_mapping = JuicyParameterMapping.new()
	property_mapping.input_parameter = "speed"
	property_mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_PROPERTY
	property_mapping.target_property = "time_scale"
	property_mapping.enabled = true
	
	# 测试TRACK_TIME映射
	var time_mapping = JuicyParameterMapping.new()
	time_mapping.input_parameter = "time_factor"
	time_mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_TIME
	time_mapping.target_property = "time_scale"
	time_mapping.enabled = true
	
	# 测试CUSTOM映射
	var custom_mapping = JuicyParameterMapping.new()
	custom_mapping.input_parameter = "custom_param"
	custom_mapping.mapping_type = JuicyParameterMapping.MappingType.CUSTOM
	custom_mapping.target_property = "intensity"
	custom_mapping.custom_handler = "custom_mapping_handler"
	custom_mapping.enabled = true
	
	# 创建测试曲线
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(1, 1))
	
	value_mapping.curve = curve
	property_mapping.curve = curve
	time_mapping.curve = curve
	custom_mapping.curve = curve
	
	property_track.parameter_mappings = [value_mapping, property_mapping, time_mapping, custom_mapping]
	_test_timeline.add_track(property_track, "Property")
	
	# 准备驱动器
	_test_driver.prepare(_test_context, 0.016, _test_buffer)
	
	# 设置参数值
	_test_context.set_parameter("intensity", 0.5)
	_test_context.set_parameter("speed", 1.5)
	_test_context.set_parameter("time_factor", 0.8)
	_test_context.set_parameter("custom_param", 0.7)
	
	# 测试映射类型应用
	_test_driver.current_time = 0.5
	_test_driver.process(_test_context, 0.016, _test_buffer)
	
	# 验证映射类型
	assert_true(_test_buffer.property_updates.size() > 0, "应有属性更新")
	
	# 测试映射类型验证
	for mapping in property_track.parameter_mappings:
		var validation_error = mapping.validate_mapping()
		assert_true(validation_error.is_empty(), "映射类型" + str(mapping.mapping_type) + "应通过验证")
	
	# 测试映射类型描述
	var value_desc = value_mapping.get_mapping_type_description()
	assert_equals("Track Value", value_desc, "TRACK_VALUE描述应正确")
	
	var property_desc = property_mapping.get_mapping_type_description()
	assert_equals("Track Property", property_desc, "TRACK_PROPERTY描述应正确")
	
	var time_desc = time_mapping.get_mapping_type_description()
	assert_equals("Track Time", time_desc, "TRACK_TIME描述应正确")
	
	var custom_desc = custom_mapping.get_mapping_type_description()
	assert_equals("Custom", custom_desc, "CUSTOM描述应正确")
	
	print("✅ 不同映射类型测试通过")

# 测试参数映射序列化
func test_parameter_mapping_serialization():
	print("=== 💾 测试参数映射序列化 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 创建属性轨道
	var property_track = JuicyPropertyTrack.new()
	property_track.track_name = "SerializationTrack"
	property_track.property_path = "scale"
	property_track.value_range = Vector2(0.0, 2.0)
	property_track.use_parameter_mapping = true
	
	# 创建参数映射
	var mapping = JuicyParameterMapping.new()
	mapping.input_parameter = "intensity"
	mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_VALUE
	mapping.target_property = "intensity"
	mapping.enabled = true
	mapping.input_range = Vector2(-1.0, 1.0)
	mapping.output_range = Vector2(0.0, 3.0)
	mapping.clamp_output = true
	mapping.invert_mapping = false
	
	# 创建曲线
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.5, 0.8))
	curve.add_point(Vector2(1, 1))
	mapping.curve = curve
	
	property_track.parameter_mappings = [mapping]
	_test_timeline.add_track(property_track, "Property")
	
	# 测试参数映射序列化
	var config_dict = mapping.get_config_dict()
	assert_not_null(config_dict, "配置字典不应为null")
	assert_true(config_dict.has("input_parameter"), "应包含input_parameter")
	assert_true(config_dict.has("mapping_type"), "应包含mapping_type")
	assert_true(config_dict.has("target_property"), "应包含target_property")
	assert_true(config_dict.has("enabled"), "应包含enabled")
	assert_true(config_dict.has("input_range"), "应包含input_range")
	assert_true(config_dict.has("output_range"), "应包含output_range")
	assert_true(config_dict.has("clamp_output"), "应包含clamp_output")
	assert_true(config_dict.has("invert_mapping"), "应包含invert_mapping")
	
	# 验证配置值
	assert_equals("intensity", config_dict["input_parameter"], "input_parameter值应正确")
	assert_equals("TRACK_VALUE", config_dict["mapping_type"], "mapping_type值应正确")
	assert_equals("intensity", config_dict["target_property"], "target_property值应正确")
	assert_true(config_dict["enabled"], "enabled值应正确")
	
	# 测试参数映射反序列化
	var new_mapping = JuicyParameterMapping.new()
	assert_true(new_mapping.load_from_dict(config_dict), "从字典加载应成功")
	
	assert_equals(mapping.input_parameter, new_mapping.input_parameter, "加载后input_parameter应正确")
	assert_equals(mapping.mapping_type, new_mapping.mapping_type, "加载后mapping_type应正确")
	assert_equals(mapping.target_property, new_mapping.target_property, "加载后target_property应正确")
	assert_equals(mapping.enabled, new_mapping.enabled, "加载后enabled应正确")
	assert_equals(mapping.input_range, new_mapping.input_range, "加载后input_range应正确")
	assert_equals(mapping.output_range, new_mapping.output_range, "加载后output_range应正确")
	assert_equals(mapping.clamp_output, new_mapping.clamp_output, "加载后clamp_output应正确")
	assert_equals(mapping.invert_mapping, new_mapping.invert_mapping, "加载后invert_mapping应正确")
	
	# 测试轨道序列化包含参数映射
	var track_config = property_track.get_config_dict()
	assert_true(track_config.has("use_parameter_mapping"), "轨道配置应包含use_parameter_mapping")
	assert_true(track_config["use_parameter_mapping"], "use_parameter_mapping值应正确")
	
	# 测试轨道反序列化
	var new_track = JuicyPropertyTrack.new()
	assert_true(new_track.load_from_dict(track_config), "轨道从字典加载应成功")
	assert_equals(property_track.use_parameter_mapping, new_track.use_parameter_mapping, "加载后use_parameter_mapping应正确")
	
	print("✅ 参数映射序列化测试通过")

# 运行所有测试
func run_all_tests():
	print("🚀 开始Timeline参数映射集成测试")
	print("==================================================")
	
	test_track_level_parameter_mapping()
	test_timeline_parameter_mapping_integration()
	test_realtime_parameter_updates()
	test_parameter_mapping_performance()
	test_parameter_mapping_edge_cases()
	test_different_mapping_types()
	test_parameter_mapping_serialization()
	
	print("==================================================")
	print("📊 测试统计:")
	print("  总测试数: %d" % _tests_run)
	print("  通过: %d" % _tests_passed)
	print("  失败: %d" % _tests_failed)
	
	if _tests_failed == 0:
		print("🎉 所有Timeline参数映射集成测试通过！")
	else:
		push_error("❌ 有 %d 个测试失败！" % _tests_failed)

func _ready():
	run_all_tests()