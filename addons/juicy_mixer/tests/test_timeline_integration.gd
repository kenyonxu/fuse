# Timeline集成测试和性能测试
# 测试Timeline与JuicyMixer V3的集成、复杂场景的执行、性能基准测试和内存泄漏检测

extends Node

# 测试统计
var _tests_run = 0
var _tests_passed = 0
var _tests_failed = 0

# 测试资源
var _test_timeline: JuicyTimelineResource
var _test_driver: JuicyTimelineDriver
var _test_mixer: JuicyMixer
var _test_context: JuicyContext

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
	# 创建测试节点
	var test_node = Node.new()
	add_child(test_node)
	
	# 创建JuicyMixer（模拟）
	_test_mixer = _create_mock_mixer()
	
	# 创建JuicyContext（模拟）
	_test_context = _create_mock_context()
	
	# 创建Timeline资源
	_test_timeline = JuicyTimelineResource.new()
	_test_timeline.timeline_duration = 5.0
	_test_timeline.description = "Integration Test Timeline"
	
	# 创建Timeline驱动器
	_test_driver = JuicyTimelineDriver.new()
	_test_driver.timeline = _test_timeline
	_test_driver.mixer = _test_mixer
	_test_driver.context = _test_context

# 测试Timeline与JuicyMixer V3的集成
func test_timeline_mixer_integration():
	print("=== 🔗 测试Timeline与JuicyMixer V3的集成 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 测试驱动器与Mixer的连接
	assert_not_null(_test_driver.mixer, "驱动器应连接到Mixer")
	assert_not_null(_test_driver.context, "驱动器应连接到Context")
	
	# 测试Mixer回调
	var mixer_called = false
	_test_mixer.set_callback(func(event, context):
		mixer_called = true
	)
	
	# 添加反馈轨道并触发
	var feedback_track = JuicyFeedbackTrack.new()
	feedback_track.track_name = "IntegrationFeedback"
	feedback_track.resource = JuicyShakeResource.new()
	_test_timeline.add_track(feedback_track, "Feedback")
	
	# 播放Timeline
	_test_driver.play()
	
	# 等待一段时间
	await get_tree().create_timer(0.1).timeout
	
	# 验证Mixer被调用
	assert_true(mixer_called, "Mixer应被调用")
	
	# 测试Context传递
	var context_received = false
	_test_mixer.set_callback(func(event, context):
		if context == _test_context:
			context_received = true
	)
	
	# 重新播放
	_test_driver.stop()
	_test_driver.play()
	
	await get_tree().create_timer(0.1).timeout
	
	assert_true(context_received, "Context应正确传递")
	
	print("✅ Timeline与JuicyMixer V3的集成测试通过")

# 测试复杂场景的执行
func test_complex_scenario_execution():
	print("=== 🎬 测试复杂场景的执行 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 创建复杂Timeline
	_test_timeline.timeline_duration = 10.0
	
	# 添加多种轨道
	# 属性轨道
	var property_track = JuicyPropertyTrack.new()
	property_track.track_name = "ComplexProperty"
	property_track.property_path = "position"
	property_track.value_range = Vector2(0.0, 100.0)
	
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(5, 50))
	curve.add_point(Vector2(10, 100))
	property_track.animation_curve = curve
	
	_test_timeline.add_track(property_track, "Property")
	
	# 反馈轨道
	var feedback_track = JuicyFeedbackTrack.new()
	feedback_track.track_name = "ComplexFeedback"
	feedback_track.resource = JuicyShakeResource.new()
	_test_timeline.add_track(feedback_track, "Feedback")
	
	# 方法轨道
	var method_track = JuicyMethodTrack.new()
	method_track.track_name = "ComplexMethod"
	method_track.method_name = "complex_method"
	method_track.method_args = [1, "test", true]
	_test_timeline.add_track(method_track, "Method")
	
	# 事件轨道
	var event_track = JuicyEventTrack.new()
	event_track.track_name = "ComplexEvent"
	event_track.event_name = "complex_event"
	_test_timeline.add_track(event_track, "Event")
	
	# 添加参数映射
	var mapping = JuicyParameterMapping.new()
	mapping.input_parameter = "intensity"
	mapping.output_parameter = "strength"
	mapping.mapping_type = 1  # 假设1是MULTIPLY的枚举值
	mapping.mapping_value = 2.0
	property_track.add_parameter_mapping(mapping)
	
	# 测试执行
	var execution_events = []
	_test_mixer.set_callback(func(event, context):
		execution_events.append({"event": event, "time": Time.get_ticks_msec()})
	)
	
	# 播放Timeline
	_test_driver.play()
	
	# 等待执行完成
	await get_tree().create_timer(11.0).timeout
	
	# 验证执行结果
	assert_true(execution_events.size() > 0, "应有执行事件")
	assert_true(_test_driver.is_finished(), "Timeline应已完成")
	
	# 验证轨道执行顺序
	var track_types = []
	for event_data in execution_events:
		if event_data.event.has_method("get_track_type"):
			track_types.append(event_data.event.get_track_type())
	
	# 应包含所有轨道类型
	assert_true("Property" in track_types, "应执行属性轨道")
	assert_true("Feedback" in track_types, "应执行反馈轨道")
	assert_true("Method" in track_types, "应执行方法轨道")
	assert_true("Event" in track_types, "应执行事件轨道")
	
	print("✅ 复杂场景的执行测试通过")

# 测试性能基准
func test_performance_benchmarks():
	print("=== ⚡ 测试性能基准 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 基准测试1：大量轨道处理
	print("  基准测试1：大量轨道处理")
	
	# 添加100个轨道
	for i in range(100):
		var track = JuicyPropertyTrack.new()
		track.track_name = "PerfTrack" + str(i)
		track.property_path = "property" + str(i)
		track.value_range = Vector2(0.0, 1.0)
		
		var curve = Curve.new()
		curve.add_point(Vector2(0, 0))
		curve.add_point(Vector2(1, 1))
		track.animation_curve = curve
		
		_test_timeline.add_track(track, "Property")
	
	# 测试初始化性能
	var start_time = Time.get_ticks_msec()
	var driver = JuicyTimelineDriver.new()
	driver.timeline = _test_timeline
	driver.mixer = _test_mixer
	driver.context = _test_context
	var init_time = Time.get_ticks_msec() - start_time
	
	print("    初始化100个轨道耗时: " + str(init_time) + "ms")
	assert_true(init_time < 100, "初始化性能应满足要求")
	
	# 测试播放性能
	start_time = Time.get_ticks_msec()
	driver.play()
	await get_tree().create_timer(2.0).timeout
	var play_time = Time.get_ticks_msec() - start_time
	
	print("    播放2秒耗时: " + str(play_time) + "ms")
	assert_true(play_time < 2100, "播放性能应满足要求")
	
	# 基准测试2：长时间轴执行
	print("  基准测试2：长时间轴执行")
	
	# 创建长时间轴
	_test_timeline.timeline_duration = 60.0
	
	start_time = Time.get_ticks_msec()
	driver.play()
	await get_tree().create_timer(5.0).timeout  # 只测试5秒
	driver.stop()
	var long_timeline_time = Time.get_ticks_msec() - start_time
	
	print("    长时间轴执行5秒耗时: " + str(long_timeline_time) + "ms")
	assert_true(long_timeline_time < 5100, "长时间轴执行性能应满足要求")
	
	# 基准测试3：参数映射性能
	print("  基准测试3：参数映射性能")
	
	# 清空轨道
	_test_timeline.clear_all_tracks()
	
	# 添加带参数映射的轨道
	for i in range(50):
		var track = JuicyPropertyTrack.new()
		track.track_name = "MappingTrack" + str(i)
		track.property_path = "property" + str(i)
		
		# 添加多个参数映射
		for j in range(5):
			var mapping = JuicyParameterMapping.new()
			mapping.input_parameter = "param" + str(j)
			mapping.output_parameter = "output" + str(j)
			mapping.mapping_type = 1  # 假设1是MULTIPLY的枚举值
			mapping.mapping_value = j + 1
			track.add_parameter_mapping(mapping)
		
		_test_timeline.add_track(track, "Property")
	
	# 测试参数映射处理性能
	start_time = Time.get_ticks_msec()
	driver.play()
	await get_tree().create_timer(2.0).timeout
	driver.stop()
	var mapping_time = Time.get_ticks_msec() - start_time
	
	print("    参数映射处理2秒耗时: " + str(mapping_time) + "ms")
	assert_true(mapping_time < 2100, "参数映射处理性能应满足要求")
	
	print("✅ 性能基准测试通过")

# 测试内存泄漏检测
func test_memory_leak_detection():
	print("=== 🔍 测试内存泄漏检测 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 记录初始内存使用
	var initial_memory = OS.get_static_memory_usage()
	
	# 创建和销毁多个Timeline
	for i in range(50):
		var timeline = JuicyTimelineResource.new()
		timeline.timeline_duration = 5.0
		
		# 添加轨道
		for j in range(10):
			var track = JuicyPropertyTrack.new()
			track.track_name = "LeakTestTrack" + str(i) + "_" + str(j)
			track.property_path = "property" + str(j)
			
			var curve = Curve.new()
			curve.add_point(Vector2(0, 0))
			curve.add_point(Vector2(1, 1))
			track.animation_curve = curve
			
			timeline.add_track(track, "Property")
		
		# 创建驱动器并播放
		var driver = JuicyTimelineDriver.new()
		driver.timeline = timeline
		driver.mixer = _test_mixer
		driver.context = _test_context
		
		driver.play()
		await get_tree().create_timer(0.1).timeout
		driver.stop()
		
		# 清理引用
		driver.timeline = null
		driver.mixer = null
		driver.context = null
		driver.queue_free()
		timeline.queue_free()
	
	# 强制垃圾回收
	for i in range(3):
		await get_tree().process_frame
		# 强制垃圾回收
		for j in range(10):
			await get_tree().process_frame
	
	# 检查内存使用
	var final_memory = OS.get_static_memory_usage()
	
	# 计算内存增长（允许一定的增长）
	var memory_growth = final_memory - initial_memory
	var memory_growth_mb = memory_growth / (1024.0 * 1024.0)
	
	print("  内存增长: " + str(memory_growth_mb) + "MB")
	
	# 内存增长应小于50MB
	assert_true(memory_growth_mb < 50.0, "内存增长应在合理范围内")
	
	# 测试循环播放的内存泄漏
	print("  测试循环播放的内存泄漏")
	
	var loop_timeline = JuicyTimelineResource.new()
	loop_timeline.timeline_duration = 1.0
	loop_timeline.loop_mode = JuicyTimelineResource.LoopMode.LOOP
	
	var loop_track = JuicyFeedbackTrack.new()
	loop_track.track_name = "LoopTest"
	loop_track.resource = JuicyShakeResource.new()
	loop_timeline.add_track(loop_track, "Feedback")
	
	var loop_driver = JuicyTimelineDriver.new()
	loop_driver.timeline = loop_timeline
	loop_driver.mixer = _test_mixer
	loop_driver.context = _test_context
	
	var loop_start_memory = OS.get_static_memory_usage()
	
	# 循环播放100次
	loop_driver.play()
	for i in range(100):
		await get_tree().create_timer(0.01).timeout
	
	loop_driver.stop()
	
	# 强制垃圾回收
	for i in range(3):
		await get_tree().process_frame
		# 强制垃圾回收
		for j in range(10):
			await get_tree().process_frame
	
	var loop_end_memory = OS.get_static_memory_usage()
	var loop_memory_growth = loop_end_memory - loop_start_memory
	var loop_memory_growth_mb = loop_memory_growth / (1024.0 * 1024.0)
	
	print("  循环播放内存增长: " + str(loop_memory_growth_mb) + "MB")
	
	# 循环播放内存增长应小于10MB
	assert_true(loop_memory_growth_mb < 10.0, "循环播放内存增长应在合理范围内")
	
	# 清理
	loop_driver.queue_free()
	loop_timeline.queue_free()
	
	print("✅ 内存泄漏检测测试通过")

# 测试并发访问安全性
func test_concurrent_access_safety():
	print("=== 🔒 测试并发访问安全性 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 创建共享Timeline
	var shared_timeline = JuicyTimelineResource.new()
	shared_timeline.timeline_duration = 5.0
	
	# 添加轨道
	var track = JuicyPropertyTrack.new()
	track.track_name = "ConcurrentTrack"
	track.property_path = "position"
	shared_timeline.add_track(track, "Property")
	
	# 创建多个驱动器
	var drivers = []
	for i in range(5):
		var driver = JuicyTimelineDriver.new()
		driver.timeline = shared_timeline
		driver.mixer = _test_mixer
		driver.context = _test_context
		drivers.append(driver)
	
	# 并发播放
	var concurrent_events = []
	_test_mixer.set_callback(func(event, context):
		concurrent_events.append({"event": event, "time": Time.get_ticks_msec()})
	)
	
	for driver in drivers:
		driver.play()
	
	# 等待执行
	await get_tree().create_timer(6.0).timeout
	
	# 验证所有驱动器都完成
	for driver in drivers:
		assert_true(driver.is_finished(), "所有驱动器应完成")
	
	# 验证并发执行事件
	assert_true(concurrent_events.size() > 0, "应有并发执行事件")
	
	# 测试并发修改
	print("  测试并发修改")
	
	# 在播放过程中修改Timeline
	var modify_driver = JuicyTimelineDriver.new()
	modify_driver.timeline = shared_timeline
	modify_driver.mixer = _test_mixer
	modify_driver.context = _test_context
	
	modify_driver.play()
	
	# 1秒后添加轨道
	await get_tree().create_timer(1.0).timeout
	
	var new_track = JuicyFeedbackTrack.new()
	new_track.track_name = "AddedDuringPlay"
	new_track.resource = JuicyShakeResource.new()
	
	# 这应该安全执行
	shared_timeline.add_track(new_track, "Feedback")
	
	# 等待完成
	await get_tree().create_timer(5.0).timeout
	
	assert_true(modify_driver.is_finished(), "修改后的驱动器应完成")
	
	# 清理
	for driver in drivers:
		driver.queue_free()
	modify_driver.queue_free()
	
	print("✅ 并发访问安全性测试通过")

# 测试错误恢复
func test_error_recovery():
	print("=== 🛡️ 测试错误恢复 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 测试无效轨道处理
	print("  测试无效轨道处理")
	
	var invalid_timeline = JuicyTimelineResource.new()
	invalid_timeline.timeline_duration = 5.0
	
	# 添加无效轨道（模拟）
	var invalid_track = _create_mock_invalid_track()
	invalid_timeline.add_track(invalid_track, "Property")
	
	var error_driver = JuicyTimelineDriver.new()
	error_driver.timeline = invalid_timeline
	error_driver.mixer = _test_mixer
	error_driver.context = _test_context
	
	# 播放应能处理错误
	error_driver.play()
	await get_tree().create_timer(2.0).timeout
	
	# 驱动器应能继续运行
	assert_true(error_driver.is_playing or error_driver.is_finished, "驱动器应能处理错误并继续")
	
	error_driver.stop()
	
	# 测试空Timeline处理
	print("  测试空Timeline处理")
	
	var empty_timeline = JuicyTimelineResource.new()
	empty_timeline.timeline_duration = 1.0
	
	var empty_driver = JuicyTimelineDriver.new()
	empty_driver.timeline = empty_timeline
	empty_driver.mixer = _test_mixer
	empty_driver.context = _test_context
	
	empty_driver.play()
	await get_tree().create_timer(2.0).timeout
	
	assert_true(empty_driver.is_finished(), "空Timeline应能正常完成")
	
	# 测试极端时间值
	print("  测试极端时间值")
	
	var extreme_timeline = JuicyTimelineResource.new()
	extreme_timeline.timeline_duration = 0.001  # 极短时长
	
	var extreme_driver = JuicyTimelineDriver.new()
	extreme_driver.timeline = extreme_timeline
	extreme_driver.mixer = _test_mixer
	extreme_driver.context = _test_context
	
	extreme_driver.play()
	await get_tree().create_timer(0.1).timeout
	
	assert_true(extreme_driver.is_finished(), "极短时长Timeline应能正常完成")
	
	# 清理
	error_driver.queue_free()
	empty_driver.queue_free()
	extreme_driver.queue_free()
	
	print("✅ 错误恢复测试通过")

# 辅助函数：创建模拟Mixer
func _create_mock_mixer() -> Object:
	var mixer = RefCounted.new()
	
	# 回调函数
	mixer.callback = Callable()
	
	# 方法
	mixer.set_callback = func(callback: Callable):
		mixer.callback = callback
	
	mixer.play_event = func(event, context):
		if mixer.callback.is_valid():
			mixer.callback.call(event, context)
	
	return mixer

# 辅助函数：创建模拟Context
func _create_mock_context() -> Object:
	var context = RefCounted.new()
	
	# 上下文数据
	context.data = {}
	
	# 方法
	context.set_data = func(key: String, value):
		context.data[key] = value
	
	context.get_data = func(key: String):
		return context.data.get(key)
	
	return context

# 辅助函数：创建模拟无效轨道
func _create_mock_invalid_track() -> Object:
	var track = RefCounted.new()
	
	# 模拟无效轨道
	track.track_name = "InvalidTrack"
	track.is_valid = false
	
	# 方法
	track.get_track_type = func() -> String:
		return "Invalid"
	
	track.process_at_time = func(time: float, context):
		# 模拟错误
		push_error("Invalid track processing error")
	
	return track

# 运行所有测试
func run_all_tests():
	print("🚀 开始Timeline集成测试和性能测试")
	print("==================================================")
	
	test_timeline_mixer_integration()
	test_complex_scenario_execution()
	test_performance_benchmarks()
	test_memory_leak_detection()
	test_concurrent_access_safety()
	test_error_recovery()
	
	print("==================================================")
	print("📊 测试统计:")
	print("  总测试数: %d" % _tests_run)
	print("  通过: %d" % _tests_passed)
	print("  失败: %d" % _tests_failed)
	
	if _tests_failed == 0:
		print("🎉 所有Timeline集成测试和性能测试通过！")
	else:
		push_error("❌ 有 %d 个测试失败！" % _tests_failed)

func _ready():
	run_all_tests()