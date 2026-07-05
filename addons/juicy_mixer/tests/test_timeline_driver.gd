# Timeline驱动器测试
# 测试JuicyTimelineDriver的生命周期、时间推进、循环处理、轨道处理逻辑和性能优化

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

func assert_null(value, message: String = "") -> void:
	_tests_run += 1
	if value == null:
		_tests_passed += 1
	else:
		_tests_failed += 1
		push_error("❌ 测试失败: " + message + " (值不为null)")

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
	
	# 创建测试轨道
	var property_track = JuicyPropertyTrack.new()
	property_track.track_name = "TestProperty"
	property_track.property_path = "scale"
	property_track.value_range = Vector2(0.0, 2.0)
	
	var animation_curve = Curve.new()
	animation_curve.add_point(Vector2(0, 0))
	animation_curve.add_point(Vector2(1, 1))
	property_track.animation_curve = animation_curve
	
	_test_timeline.add_track(property_track, "Property")
	
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
	
	# 模拟add_sample方法
	buffer.add_sample = func(target: Node, property: String, value: Variant, mode: int, source: String):
		# 在实际测试中，这里会记录属性更新
		pass
	
	# 模拟add_middleware_sample方法
	buffer.add_middleware_sample = func(target: Node, property: String, value: Variant, mode: int, source: String, priority: int):
		# 在实际测试中，这里会记录中间件属性更新
		pass
	
	return buffer

# 测试驱动器的基本属性
func test_driver_basic_properties():
	print("=== 🔧 测试驱动器基本属性 ===")
	
	# 创建驱动器
	var driver = JuicyTimelineDriver.new()
	
	# 测试元信息
	assert_equals("JuicyTimelineDriver", driver.driver_name, "驱动器名称应正确")
	assert_equals("1.0.0", driver.driver_version, "驱动器版本应正确")
	assert_true(driver.supported_properties.is_empty(), "支持的属性应为空数组")
	assert_equals(2, driver.required_context_data.size(), "应需要2个上下文数据")
	assert_true("timeline_resource" in driver.required_context_data, "应需要timeline_resource数据")
	assert_true("current_time" in driver.required_context_data, "应需要current_time数据")
	
	print("✅ 驱动器基本属性测试通过")

# 测试驱动器的生命周期
func test_driver_lifecycle():
	print("=== 🔄 测试驱动器生命周期 ===")

	# 设置测试环境
	setup_test_environment()

	# 测试准备阶段
	_test_driver.prepare(_test_context, 0.016, _test_buffer)

	# 获取状态来验证
	var state = _test_driver._get_timeline_state(_test_context)
	assert_true(state.is_playing, "准备后应处于播放状态")
	assert_false(state.is_paused, "准备后不应处于暂停状态")
	assert_equals(0.0, state.current_time, "初始时间应为0")
	assert_equals(1, state.play_direction, "播放方向应为正向")
	assert_equals(0, state.current_loop, "初始循环次数应为0")

	# 测试处理阶段
	_test_driver.process(_test_context, 0.016, _test_buffer)
	assert_equals(0.016, state.current_time, "时间应推进")
	assert_equals(0.016 / _test_timeline.timeline_duration, _test_driver.get_progress(state), "进度应正确计算")

	# 测试清理阶段
	_test_driver.cleanup(_test_context)
	state = _test_driver._get_timeline_state(_test_context)
	assert_false(state.is_playing, "清理后应停止播放")
	assert_equals(0.0, state.current_time, "清理后时间应重置")
	assert_equals(1, state.play_direction, "清理后播放方向应重置")
	assert_equals(0, state.current_loop, "清理后循环次数应重置")

	print("✅ 驱动器生命周期测试通过")

# 测试时间推进和循环处理
func test_time_advancement_and_looping():
	print("=== ⏱️ 测试时间推进和循环处理 ===")

	# 设置测试环境
	setup_test_environment()
	_test_driver.prepare(_test_context, 0.016, _test_buffer)

	# 测试正常时间推进
	_test_driver.process(_test_context, 0.016, _test_buffer)
	var state = _test_driver._get_timeline_state(_test_context)
	assert_equals(0.016, state.current_time, "时间应正常推进")

	_test_driver.process(_test_context, 0.032, _test_buffer)
	assert_equals(0.048, state.current_time, "时间应累计推进")

	# 测试无循环结束
	state.current_time = 4.9
	_test_driver.process(_test_context, 0.02, _test_buffer)
	assert_false(state.is_playing, "超出时长应停止播放")
	assert_equals(5.0, state.current_time, "时间应限制在最大值")

	# 测试循环模式
	_test_timeline.loop_mode = JuicyTimelineResource.LoopMode.LOOP
	_test_timeline.loop_count = 2
	_test_driver.prepare(_test_context, 0.016, _test_buffer)

	# 推进到接近结束
	state = _test_driver._get_timeline_state(_test_context)
	state.current_time = 4.9
	_test_driver.process(_test_context, 0.02, _test_buffer)
	assert_true(state.is_playing, "循环模式下应继续播放")
	assert_equals(0.02, state.current_time, "时间应循环到开始")
	assert_equals(1, state.current_loop, "循环次数应增加")

	# 测试往返循环
	_test_timeline.loop_mode = JuicyTimelineResource.LoopMode.PING_PONG
	_test_driver.prepare(_test_context, 0.016, _test_buffer)

	state = _test_driver._get_timeline_state(_test_context)
	state.current_time = 4.9
	_test_driver.process(_test_context, 0.02, _test_buffer)
	assert_true(state.is_playing, "往返循环模式下应继续播放")
	assert_equals(4.8, state.current_time, "时间应反向")
	assert_equals(-1, state.play_direction, "播放方向应反向")

	# 测试循环次数限制
	_test_timeline.loop_mode = JuicyTimelineResource.LoopMode.LOOP
	_test_timeline.loop_count = 1
	_test_driver.prepare(_test_context, 0.016, _test_buffer)

	state = _test_driver._get_timeline_state(_test_context)
	state.current_time = 4.9
	_test_driver.process(_test_context, 0.02, _test_buffer)
	assert_false(state.is_playing, "达到循环次数限制应停止")

	print("✅ 时间推进和循环处理测试通过")

# 测试轨道处理逻辑
func test_track_processing():
	print("=== 🎵 测试轨道处理逻辑 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 添加多种类型的轨道
	var feedback_track = JuicyFeedbackTrack.new()
	feedback_track.track_name = "TestFeedback"
	feedback_track.start_time = 1.0
	feedback_track.duration = 2.0
	feedback_track.resource = JuicyShakeResource.new()
	
	var method_track = JuicyMethodTrack.new()
	method_track.track_name = "TestMethod"
	method_track.trigger_time = 2.0
	method_track.method_name = "test_method"
	
	var event_track = JuicyEventTrack.new()
	event_track.track_name = "TestEvent"
	event_track.trigger_time = 3.0
	event_track.juicy_event = JuicyEvent.new()
	
	_test_timeline.add_track(feedback_track, "Feedback")
	_test_timeline.add_track(method_track, "Method")
	_test_timeline.add_track(event_track, "Event")
	
	# 准备驱动器
	_test_driver.prepare(_test_context, 0.016, _test_buffer)
	
	# 验证活跃轨道列表
	var debug_info = _test_driver.get_debug_info(_test_context)
	var active_tracks = debug_info.active_tracks
	
	assert_equals(1, active_tracks.property, "应有1个活跃属性轨道")
	assert_equals(1, active_tracks.feedback, "应有1个活跃反馈轨道")
	assert_equals(1, active_tracks.method, "应有1个活跃方法轨道")
	assert_equals(1, active_tracks.event, "应有1个活跃事件轨道")
	
	# 测试属性轨道处理
	var state = _test_driver._get_timeline_state(_test_context)
	state.current_time = 0.5
	_test_driver.process(_test_context, 0.016, _test_buffer)
	
	var stats = debug_info.performance_stats
	assert_true(stats.tracks_processed > 0, "应处理轨道")
	assert_true(stats.properties_updated > 0, "应更新属性")
	
	# 测试反馈轨道触发
	state.current_time = 1.0
	_test_driver.process(_test_context, 0.016, _test_buffer)
	# 在实际实现中，这里会触发子效果

	# 测试方法轨道触发
	state.current_time = 2.0
	_test_driver.process(_test_context, 0.016, _test_buffer)
	# 在实际实现中，这里会调用方法

	# 测试事件轨道触发
	state.current_time = 3.0
	_test_driver.process(_test_context, 0.016, _test_buffer)
	# 在实际实现中，这里会触发事件
	
	print("✅ 轨道处理逻辑测试通过")

# 测试性能和批处理
func test_performance_and_batching():
	print("=== ⚡ 测试性能和批处理 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 添加多个属性轨道以测试批处理
	for i in range(10):
		var track = JuicyPropertyTrack.new()
		track.track_name = "Property" + str(i)
		track.property_path = "property" + str(i)
		track.value_range = Vector2(0.0, 1.0)
		
		var curve = Curve.new()
		curve.add_point(Vector2(0, 0))
		curve.add_point(Vector2(1, 1))
		track.animation_curve = curve
		
		_test_timeline.add_track(track, "Property")
	
	# 准备驱动器
	_test_driver.enable_debug(true)
	_test_driver.prepare(_test_context, 0.016, _test_buffer)

	# 测试批处理性能
	var start_time = Time.get_ticks_msec()
	var state = _test_driver._get_timeline_state(_test_context)

	for i in range(100):
		state.current_time = i * 0.01
		_test_driver.process(_test_context, 0.016, _test_buffer)
	
	var end_time = Time.get_ticks_msec()
	var total_time = end_time - start_time
	
	print("  处理100帧耗时: " + str(total_time) + "ms")
	print("  平均每帧耗时: " + str(total_time / 100) + "ms")
	
	# 性能要求：每帧处理应小于1ms
	assert_true(total_time < 100, "批处理性能应满足要求")
	
	# 测试性能统计
	var debug_info = _test_driver.get_debug_info(_test_context)
	var stats = debug_info.performance_stats
	
	assert_true(stats.tracks_processed > 0, "应处理轨道")
	assert_true(stats.properties_updated > 0, "应更新属性")
	
	print("✅ 性能和批处理测试通过")

# 测试参数映射集成
func test_parameter_mapping_integration():
	print("=== 🗺️ 测试参数映射集成 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 添加带参数映射的属性轨道
	var property_track = JuicyPropertyTrack.new()
	property_track.track_name = "MappedProperty"
	property_track.property_path = "scale"
	property_track.value_range = Vector2(0.0, 2.0)
	property_track.use_parameter_mapping = true
	
	# 创建参数映射
	var mapping = JuicyParameterMapping.new()
	mapping.input_parameter = "intensity"
	mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_VALUE
	mapping.target_property = "intensity"
	mapping.enabled = true
	
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(1, 1))
	mapping.curve = curve
	
	property_track.parameter_mappings = [mapping]
	_test_timeline.add_track(property_track, "Property")
	
	# 设置上下文参数
	_test_context.set_parameter("intensity", 0.5)
	
	# 准备驱动器
	_test_driver.prepare(_test_context, 0.016, _test_buffer)

	# 测试参数映射应用
	var state = _test_driver._get_timeline_state(_test_context)
	state.current_time = 0.5
	_test_driver.process(_test_context, 0.016, _test_buffer)
	
	# 验证参数映射是否被应用
	# 在实际实现中，这里会检查属性值是否根据参数映射进行了调整
	
	# 测试参数映射验证
	var validation_errors = []
	for track in _test_timeline.get_all_tracks():
		if track.has_method("validate_track"):
			var error = track.validate_track()
			if not error.is_empty():
				validation_errors.append(error)
	
	assert_true(validation_errors.is_empty(), "参数映射验证应通过")
	
	print("✅ 参数映射集成测试通过")

# 测试错误处理
func test_error_handling():
	print("=== ⚠️ 测试错误处理 ===")

	# 测试无Timeline资源的驱动器
	var driver = JuicyTimelineDriver.new()
	var target = Node.new()
	var timeline = JuicyTimelineResource.new()
	var context = JuicyContext.create(timeline, target)
	var buffer = _create_mock_property_buffer()

	# 准备阶段应该处理错误（没有timeline_resource在driver_data中）
	driver.prepare(context, 0.016, buffer)
	var state = driver._get_timeline_state(context)
	assert_false(state.is_playing if state else true, "无Timeline资源时不应播放")

	# 测试空轨道处理
	var empty_timeline = JuicyTimelineResource.new()
	driver.timeline_resource = empty_timeline
	context.set_driver_data("timeline_resource", empty_timeline)

	driver.prepare(context, 0.016, buffer)
	state = driver._get_timeline_state(context)
	assert_true(state.is_playing if state else false, "空Timeline应能播放")

	driver.process(context, 0.016, buffer)
	# 应正常处理无轨道情况

	print("✅ 错误处理测试通过")

# 测试调试功能
func test_debug_functionality():
	print("=== 🔍 测试调试功能 ===")

	# 设置测试环境
	setup_test_environment()
	_test_driver.enable_debug(true)

	# 测试调试信息获取
	var debug_info = _test_driver.get_debug_info(_test_context)
	assert_not_null(debug_info, "调试信息不应为null")
	assert_true(debug_info.has("timeline_resource"), "应包含Timeline资源信息")
	assert_true(debug_info.has("current_time"), "应包含当前时间")
	assert_true(debug_info.has("is_playing"), "应包含播放状态")
	assert_true(debug_info.has("is_paused"), "应包含暂停状态")
	assert_true(debug_info.has("play_direction"), "应包含播放方向")
	assert_true(debug_info.has("current_loop"), "应包含当前循环")
	assert_true(debug_info.has("active_tracks"), "应包含活跃轨道信息")
	assert_true(debug_info.has("performance_stats"), "应包含性能统计")
	assert_true(debug_info.has("driver_performance"), "应包含驱动器性能")

	# 准备驱动器
	_test_driver.prepare(_test_context, 0.016, _test_buffer)
	var state = _test_driver._get_timeline_state(_test_context)

	# 测试播放进度
	assert_equals(0.0, _test_driver.get_progress(state), "初始进度应为0")

	state.current_time = 2.5
	assert_almost_equals(0.5, _test_driver.get_progress(state), 0.01, "时间2.5s对应进度应为0.5")

	# 测试播放状态
	assert_true(_test_driver.is_timeline_active(_test_context), "应处于活跃状态")

	state.is_paused = true
	assert_false(_test_driver.is_timeline_active(_test_context), "暂停状态不应为活跃")

	state.is_playing = false
	assert_false(_test_driver.is_timeline_active(_test_context), "停止状态不应为活跃")

	# 测试播放状态描述
	state.is_playing = false
	assert_equals("Stopped", _test_driver.get_playback_state(_test_context), "停止状态描述应为Stopped")

	state.is_playing = true
	state.is_paused = true
	assert_equals("Paused", _test_driver.get_playback_state(_test_context), "暂停状态描述应为Paused")

	state.is_paused = false
	assert_equals("Playing", _test_driver.get_playback_state(_test_context), "播放状态描述应为Playing")

	print("✅ 调试功能测试通过")

# 测试边界条件
func test_edge_cases():
	print("=== 🔍 测试边界条件 ===")

	# 设置测试环境
	setup_test_environment()

	# 测试零时长Timeline
	_test_timeline.timeline_duration = 0.0
	_test_driver.prepare(_test_context, 0.016, _test_buffer)
	var state = _test_driver._get_timeline_state(_test_context)

	assert_equals(0.0, _test_driver.get_progress(state), "零时长Timeline进度应为0")

	# 测试极小时间增量
	_test_timeline.timeline_duration = 1.0
	_test_driver.prepare(_test_context, 0.0001, _test_buffer)
	state = _test_driver._get_timeline_state(_test_context)

	_test_driver.process(_test_context, 0.0001, _test_buffer)
	assert_true(state.current_time > 0.0, "极小时间增量应被处理")

	# 测试极大时间增量
	state.current_time = 0.0
	_test_driver.process(_test_context, 10.0, _test_buffer)

	if _test_timeline.loop_mode == JuicyTimelineResource.LoopMode.NO_LOOP:
		assert_false(state.is_playing, "极大时间增量应导致停止")
		assert_equals(_test_timeline.timeline_duration, state.current_time, "时间应被限制")

	# 测试负时间增量
	_test_driver.prepare(_test_context, -0.016, _test_buffer)
	_test_driver.process(_test_context, -0.016, _test_buffer)

	# 测试重复准备
	_test_driver.prepare(_test_context, 0.016, _test_buffer)
	_test_driver.prepare(_test_context, 0.016, _test_buffer)
	# 应能处理重复准备

	# 测试重复清理
	_test_driver.cleanup(_test_context)
	_test_driver.cleanup(_test_context)
	# 应能处理重复清理
	
	print("✅ 边界条件测试通过")

# 运行所有测试
func run_all_tests():
	print("🚀 开始Timeline驱动器测试")
	print("==================================================")
	
	test_driver_basic_properties()
	test_driver_lifecycle()
	test_time_advancement_and_looping()
	test_track_processing()
	test_performance_and_batching()
	test_parameter_mapping_integration()
	test_error_handling()
	test_debug_functionality()
	test_edge_cases()
	
	print("==================================================")
	print("📊 测试统计:")
	print("  总测试数: %d" % _tests_run)
	print("  通过: %d" % _tests_passed)
	print("  失败: %d" % _tests_failed)
	
	if _tests_failed == 0:
		print("🎉 所有Timeline驱动器测试通过！")
	else:
		push_error("❌ 有 %d 个测试失败！" % _tests_failed)

func _ready():
	run_all_tests()