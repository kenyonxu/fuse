# Timeline示例和演示测试
# 测试各种使用示例、验证文档中的示例代码、测试边界条件和异常情况

extends Node

# 测试统计
var _tests_run = 0
var _tests_passed = 0
var _tests_failed = 0

# 测试资源
var _test_timeline: JuicyTimelineResource
var _test_driver: JuicyTimelineDriver
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
	# 创建测试目标节点
	_test_target = Node.new()
	_test_target.name = "TestTarget"
	add_child(_test_target)
	
	# 创建Timeline资源
	_test_timeline = JuicyTimelineResource.new()
	_test_timeline.timeline_duration = 5.0
	_test_timeline.description = "Example Test Timeline"
	
	# 创建Timeline驱动器
	_test_driver = JuicyTimelineDriver.new()
	_test_driver.timeline = _test_timeline
	_test_driver.target = _test_target

# 测试基本属性动画示例
func test_basic_property_animation_example():
	print("=== 🎬 测试基本属性动画示例 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 创建属性动画示例（来自文档）
	var property_track = JuicyPropertyTrack.new()
	property_track.track_name = "Position Animation"
	property_track.property_path = "position"
	property_track.value_range = Vector2(0.0, 100.0)
	
	# 创建动画曲线
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0))      # 开始时位置为0
	curve.add_point(Vector2(0.5, 50))   # 中间时位置为50
	curve.add_point(Vector2(1, 100))    # 结束时位置为100
	property_track.animation_curve = curve
	
	# 添加到Timeline
	_test_timeline.add_track(property_track, "Property")
	
	# 验证设置
	assert_equals(1, _test_timeline.property_tracks.size(), "应添加一个属性轨道")
	assert_equals("Position Animation", property_track.track_name, "轨道名称应正确")
	assert_equals("position", property_track.property_path, "属性路径应正确")
	
	# 测试播放
	_test_driver.play()
	
	# 验证初始状态
	assert_equals(0.0, _test_driver.current_time, "开始时间应为0")
	
	# 等待一段时间
	await get_tree().create_timer(2.5).timeout
	
	# 验证中间状态
	assert_almost_equals(2.5, _test_driver.current_time, 0.1, "中间时间应约为2.5秒")
	
	# 等待完成
	await get_tree().create_timer(3.0).timeout
	
	# 验证完成状态
	assert_true(_test_driver.is_finished(), "Timeline应已完成")
	
	print("✅ 基本属性动画示例测试通过")

# 测试反馈效果示例
func test_feedback_effect_example():
	print("=== ✨ 测试反馈效果示例 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 创建反馈效果示例（来自文档）
	var feedback_track = JuicyFeedbackTrack.new()
	feedback_track.track_name = "Camera Shake"
	feedback_track.resource = JuicyShakeResource.new()
	feedback_track.resource.intensity = 0.5
	feedback_track.resource.duration = 1.0
	
	# 添加到Timeline
	_test_timeline.add_track(feedback_track, "Feedback")
	
	# 验证设置
	assert_equals(1, _test_timeline.feedback_tracks.size(), "应添加一个反馈轨道")
	assert_equals("Camera Shake", feedback_track.track_name, "轨道名称应正确")
	assert_not_null(feedback_track.resource, "反馈资源不应为null")
	
	# 测试播放
	var feedback_triggered = false
	_test_driver.feedback_triggered.connect(func(track, resource):
		feedback_triggered = true
		assert_equals(feedback_track, track, "触发的轨道应正确")
		assert_equals(feedback_track.resource, resource, "触发的资源应正确")
	)
	
	_test_driver.play()
	
	# 等待触发
	await get_tree().create_timer(0.1).timeout
	
	# 验证触发
	assert_true(feedback_triggered, "反馈效果应被触发")
	
	# 等待完成
	await get_tree().create_timer(5.0).timeout
	assert_true(_test_driver.is_finished(), "Timeline应已完成")
	
	print("✅ 反馈效果示例测试通过")

# 测试方法调用示例
func test_method_call_example():
	print("=== 🔧 测试方法调用示例 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 为测试目标添加方法
	_test_target.set_script(load("res://addons/juicy_mixer/tests/test_target_methods.gd").new())
	
	# 创建方法调用示例（来自文档）
	var method_track = JuicyMethodTrack.new()
	method_track.track_name = "Game Actions"
	method_track.method_name = "activate_power_up"
	method_track.method_args = ["speed_boost", 5.0]
	
	# 添加到Timeline
	_test_timeline.add_track(method_track, "Method")
	
	# 验证设置
	assert_equals(1, _test_timeline.method_tracks.size(), "应添加一个方法轨道")
	assert_equals("Game Actions", method_track.track_name, "轨道名称应正确")
	assert_equals("activate_power_up", method_track.method_name, "方法名应正确")
	assert_equals(2, method_track.method_args.size(), "应有2个参数")
	
	# 测试播放
	var method_called = false
	var method_args = []
	
	_test_target.method_called.connect(func(name, args):
		method_called = true
		method_args = args
	)
	
	_test_driver.play()
	
	# 等待调用
	await get_tree().create_timer(0.1).timeout
	
	# 验证调用
	assert_true(method_called, "方法应被调用")
	assert_equals("activate_power_up", method_args[0], "方法名应正确")
	assert_equals("speed_boost", method_args[1], "第一个参数应正确")
	assert_equals(5.0, method_args[2], "第二个参数应正确")
	
	# 等待完成
	await get_tree().create_timer(5.0).timeout
	assert_true(_test_driver.is_finished(), "Timeline应已完成")
	
	print("✅ 方法调用示例测试通过")

# 测试事件触发示例
func test_event_trigger_example():
	print("=== 📢 测试事件触发示例 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 创建事件触发示例（来自文档）
	var event_track = JuicyEventTrack.new()
	event_track.track_name = "Game Events"
	event_track.event_name = "level_complete"
	event_track.event_data = {"level": 1, "score": 1000}
	
	# 添加到Timeline
	_test_timeline.add_track(event_track, "Event")
	
	# 验证设置
	assert_equals(1, _test_timeline.event_tracks.size(), "应添加一个事件轨道")
	assert_equals("Game Events", event_track.track_name, "轨道名称应正确")
	assert_equals("level_complete", event_track.event_name, "事件名应正确")
	assert_not_null(event_track.event_data, "事件数据不应为null")
	
	# 测试播放
	var event_triggered = false
	var event_data = {}
	
	_test_driver.event_triggered.connect(func(track, name, data):
		event_triggered = true
		event_data = data
		assert_equals(event_track, track, "触发的轨道应正确")
		assert_equals("level_complete", name, "事件名应正确")
	)
	
	_test_driver.play()
	
	# 等待触发
	await get_tree().create_timer(0.1).timeout
	
	# 验证触发
	assert_true(event_triggered, "事件应被触发")
	assert_equals(1, event_data.get("level"), "事件数据应正确")
	assert_equals(1000, event_data.get("score"), "事件数据应正确")
	
	# 等待完成
	await get_tree().create_timer(5.0).timeout
	assert_true(_test_driver.is_finished(), "Timeline应已完成")
	
	print("✅ 事件触发示例测试通过")

# 测试参数映射示例
func test_parameter_mapping_example():
	print("=== 🎛️ 测试参数映射示例 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 创建参数映射示例（来自文档）
	var property_track = JuicyPropertyTrack.new()
	property_track.track_name = "Intensity Controlled Animation"
	property_track.property_path = "scale"
	property_track.value_range = Vector2(1.0, 2.0)
	
	# 创建参数映射
	var mapping = JuicyParameterMapping.new()
	mapping.input_parameter = "intensity"
	mapping.output_parameter = "scale_factor"
	mapping.mapping_type = 1  # MULTIPLY
	mapping.mapping_value = 1.5
	
	property_track.add_parameter_mapping(mapping)
	
	# 添加到Timeline
	_test_timeline.add_track(property_track, "Property")
	
	# 验证设置
	assert_equals(1, _test_timeline.property_tracks.size(), "应添加一个属性轨道")
	assert_equals(1, property_track.parameter_mappings.size(), "应添加一个参数映射")
	
	# 测试播放
	_test_driver.set_parameter("intensity", 0.8)
	_test_driver.play()
	
	# 验证参数映射
	var mapped_value = _test_driver.get_mapped_parameter("scale_factor")
	assert_almost_equals(1.2, mapped_value, 0.01, "参数映射应正确")
	
	# 等待完成
	await get_tree().create_timer(5.0).timeout
	assert_true(_test_driver.is_finished(), "Timeline应已完成")
	
	print("✅ 参数映射示例测试通过")

# 测试循环播放示例
func test_loop_playback_example():
	print("=== 🔁 测试循环播放示例 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 配置循环播放（来自文档）
	_test_timeline.loop_mode = JuicyTimelineResource.LoopMode.LOOP
	_test_timeline.loop_count = 3
	
	# 添加简单轨道
	var property_track = JuicyPropertyTrack.new()
	property_track.track_name = "Loop Animation"
	property_track.property_path = "rotation"
	property_track.value_range = Vector2(0.0, 360.0)
	
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(1, 360))
	property_track.animation_curve = curve
	
	_test_timeline.add_track(property_track, "Property")
	
	# 验证设置
	assert_equals(JuicyTimelineResource.LoopMode.LOOP, _test_timeline.loop_mode, "循环模式应正确")
	assert_equals(3, _test_timeline.loop_count, "循环次数应正确")
	
	# 测试播放
	var loop_count = 0
	_test_driver.loop_completed.connect(func(count):
		loop_count = count
	)
	
	_test_driver.play()
	
	# 等待第一次循环完成
	await get_tree().create_timer(5.5).timeout
	assert_equals(1, loop_count, "应完成1次循环")
	
	# 等待所有循环完成
	await get_tree().create_timer(11.0).timeout
	assert_equals(3, loop_count, "应完成3次循环")
	assert_true(_test_driver.is_finished(), "Timeline应已完成")
	
	print("✅ 循环播放示例测试通过")

# 测试时间缩放示例
func test_time_scale_example():
	print("=== ⏱️ 测试时间缩放示例 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 配置时间缩放（来自文档）
	_test_timeline.time_scale = 2.0  # 2倍速
	
	# 添加轨道
	var property_track = JuicyPropertyTrack.new()
	property_track.track_name = "Fast Animation"
	property_track.property_path = "position"
	property_track.value_range = Vector2(0.0, 100.0)
	
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(1, 100))
	property_track.animation_curve = curve
	
	_test_timeline.add_track(property_track, "Property")
	
	# 验证设置
	assert_equals(2.0, _test_timeline.time_scale, "时间缩放应正确")
	
	# 测试播放
	_test_driver.play()
	
	# 等待2.5秒（应该是正常速度的5秒）
	await get_tree().create_timer(2.5).timeout
	
	# 验证时间缩放效果
	assert_almost_equals(5.0, _test_driver.current_time, 0.1, "时间缩放应生效")
	assert_true(_test_driver.is_finished(), "Timeline应已完成")
	
	print("✅ 时间缩放示例测试通过")

# 测试边界条件
func test_edge_cases():
	print("=== 🚨 测试边界条件 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 测试空Timeline
	print("  测试空Timeline")
	var empty_timeline = JuicyTimelineResource.new()
	empty_timeline.timeline_duration = 1.0
	
	var empty_driver = JuicyTimelineDriver.new()
	empty_driver.timeline = empty_timeline
	empty_driver.target = _test_target
	
	empty_driver.play()
	await get_tree().create_timer(1.5).timeout
	assert_true(empty_driver.is_finished(), "空Timeline应能正常完成")
	
	# 测试极短时长
	print("  测试极短时长")
	var short_timeline = JuicyTimelineResource.new()
	short_timeline.timeline_duration = 0.001
	
	var short_driver = JuicyTimelineDriver.new()
	short_driver.timeline = short_timeline
	short_driver.target = _test_target
	
	short_driver.play()
	await get_tree().create_timer(0.1).timeout
	assert_true(short_driver.is_finished(), "极短时长Timeline应能正常完成")
	
	# 测试极大时长
	print("  测试极大时长")
	var long_timeline = JuicyTimelineResource.new()
	long_timeline.timeline_duration = 3600.0  # 1小时
	
	var long_driver = JuicyTimelineDriver.new()
	long_driver.timeline = long_timeline
	long_driver.target = _test_target
	
	long_driver.play()
	await get_tree().create_timer(0.1).timeout
	long_driver.stop()
	assert_false(long_driver.is_finished(), "长时长Timeline应能正常停止")
	
	# 测试零时长
	print("  测试零时长")
	var zero_timeline = JuicyTimelineResource.new()
	zero_timeline.timeline_duration = 0.0
	
	var zero_driver = JuicyTimelineDriver.new()
	zero_driver.timeline = zero_timeline
	zero_driver.target = _test_target
	
	zero_driver.play()
	await get_tree().create_timer(0.1).timeout
	assert_true(zero_driver.is_finished(), "零时长Timeline应立即完成")
	
	# 测试负时长
	print("  测试负时长")
	var negative_timeline = JuicyTimelineResource.new()
	negative_timeline.timeline_duration = -1.0
	
	var negative_driver = JuicyTimelineDriver.new()
	negative_driver.timeline = negative_timeline
	negative_driver.target = _test_target
	
	negative_driver.play()
	await get_tree().create_timer(0.1).timeout
	assert_true(negative_driver.is_finished(), "负时长Timeline应立即完成")
	
	print("✅ 边界条件测试通过")

# 测试异常情况
func test_exception_cases():
	print("=== ⚠️ 测试异常情况 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 测试无效属性路径
	print("  测试无效属性路径")
	var invalid_property_track = JuicyPropertyTrack.new()
	invalid_property_track.track_name = "Invalid Property"
	invalid_property_track.property_path = "non_existent_property"
	invalid_property_track.value_range = Vector2(0.0, 1.0)
	
	_test_timeline.add_track(invalid_property_track, "Property")
	
	# 播放应能处理错误
	_test_driver.play()
	await get_tree().create_timer(1.0).timeout
	
	# 测试无效方法名
	print("  测试无效方法名")
	var invalid_method_track = JuicyMethodTrack.new()
	invalid_method_track.track_name = "Invalid Method"
	invalid_method_track.method_name = "non_existent_method"
	invalid_method_track.method_args = []
	
	_test_timeline.add_track(invalid_method_track, "Method")
	
	# 播放应能处理错误
	_test_driver.stop()
	_test_driver.play()
	await get_tree().create_timer(1.0).timeout
	
	# 测试空反馈资源
	print("  测试空反馈资源")
	var empty_feedback_track = JuicyFeedbackTrack.new()
	empty_feedback_track.track_name = "Empty Feedback"
	empty_feedback_track.resource = null
	
	_test_timeline.add_track(empty_feedback_track, "Feedback")
	
	# 播放应能处理错误
	_test_driver.stop()
	_test_driver.play()
	await get_tree().create_timer(1.0).timeout
	
	# 测试空事件名
	print("  测试空事件名")
	var empty_event_track = JuicyEventTrack.new()
	empty_event_track.track_name = "Empty Event"
	empty_event_track.event_name = ""
	empty_event_track.event_data = {}
	
	_test_timeline.add_track(empty_event_track, "Event")
	
	# 播放应能处理错误
	_test_driver.stop()
	_test_driver.play()
	await get_tree().create_timer(1.0).timeout
	
	# 验证驱动器仍能正常工作
	assert_false(_test_driver.is_finished(), "驱动器应仍能运行")
	
	_test_driver.stop()
	
	print("✅ 异常情况测试通过")

# 测试文档示例代码
func test_documentation_examples():
	print("=== 📚 测试文档示例代码 ===")
	
	# 设置测试环境
	setup_test_environment()
	
	# 示例1：创建简单动画Timeline
	print("  示例1：创建简单动画Timeline")
	var simple_timeline = JuicyTimelineResource.new()
	simple_timeline.timeline_duration = 3.0
	simple_timeline.description = "Simple Animation"
	
	var position_track = JuicyPropertyTrack.new()
	position_track.track_name = "Position"
	position_track.property_path = "position"
	position_track.value_range = Vector2(0.0, 200.0)
	
	var position_curve = Curve.new()
	position_curve.add_point(Vector2(0, 0))
	position_curve.add_point(Vector2(1, 200))
	position_track.animation_curve = position_curve
	
	simple_timeline.add_track(position_track, "Property")
	
	# 验证创建成功
	assert_equals(1, simple_timeline.property_tracks.size(), "应创建一个属性轨道")
	assert_equals(3.0, simple_timeline.timeline_duration, "时长应正确")
	
	# 示例2：创建带反馈的Timeline
	print("  示例2：创建带反馈的Timeline")
	var feedback_timeline = JuicyTimelineResource.new()
	feedback_timeline.timeline_duration = 2.0
	
	var shake_track = JuicyFeedbackTrack.new()
	shake_track.track_name = "Camera Shake"
	shake_track.resource = JuicyShakeResource.new()
	shake_track.resource.intensity = 0.3
	shake_track.resource.duration = 0.5
	
	feedback_timeline.add_track(shake_track, "Feedback")
	
	# 验证创建成功
	assert_equals(1, feedback_timeline.feedback_tracks.size(), "应创建一个反馈轨道")
	assert_not_null(shake_track.resource, "反馈资源不应为null")
	
	# 示例3：创建带参数映射的Timeline
	print("  示例3：创建带参数映射的Timeline")
	var mapped_timeline = JuicyTimelineResource.new()
	mapped_timeline.timeline_duration = 4.0
	
	var scale_track = JuicyPropertyTrack.new()
	scale_track.track_name = "Scale"
	scale_track.property_path = "scale"
	scale_track.value_range = Vector2(1.0, 2.0)
	
	var intensity_mapping = JuicyParameterMapping.new()
	intensity_mapping.input_parameter = "intensity"
	intensity_mapping.output_parameter = "scale_multiplier"
	intensity_mapping.mapping_type = 1  # MULTIPLY
	intensity_mapping.mapping_value = 1.5
	
	scale_track.add_parameter_mapping(intensity_mapping)
	mapped_timeline.add_track(scale_track, "Property")
	
	# 验证创建成功
	assert_equals(1, mapped_timeline.property_tracks.size(), "应创建一个属性轨道")
	assert_equals(1, scale_track.parameter_mappings.size(), "应创建一个参数映射")
	
	print("✅ 文档示例代码测试通过")

# 运行所有测试
func run_all_tests():
	print("🚀 开始Timeline示例和演示测试")
	print("==================================================")
	
	test_basic_property_animation_example()
	test_feedback_effect_example()
	test_method_call_example()
	test_event_trigger_example()
	test_parameter_mapping_example()
	test_loop_playback_example()
	test_time_scale_example()
	test_edge_cases()
	test_exception_cases()
	test_documentation_examples()
	
	print("==================================================")
	print("📊 测试统计:")
	print("  总测试数: %d" % _tests_run)
	print("  通过: %d" % _tests_passed)
	print("  失败: %d" % _tests_failed)
	
	if _tests_failed == 0:
		print("🎉 所有Timeline示例和演示测试通过！")
	else:
		push_error("❌ 有 %d 个测试失败！" % _tests_failed)

func _ready():
	run_all_tests()