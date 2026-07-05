# Timeline系统核心功能测试
# 测试JuicyTimelineResource的基本功能、轨道管理、时间轴配置和参数预设系统

extends Node

# 测试统计
var _tests_run = 0
var _tests_passed = 0
var _tests_failed = 0

# 测试资源
var _test_timeline: JuicyTimelineResource
var _test_property_track: JuicyPropertyTrack
var _test_feedback_track: JuicyFeedbackTrack
var _test_method_track: JuicyMethodTrack
var _test_event_track: JuicyEventTrack

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

# 测试JuicyTimelineResource的基本功能
func test_timeline_resource_basic():
	print("=== 📋 测试JuicyTimelineResource基本功能 ===")
	
	# 创建Timeline资源
	_test_timeline = JuicyTimelineResource.new()
	assert_not_null(_test_timeline, "Timeline资源创建失败")
	
	# 测试基础属性
	assert_equals(5.0, _test_timeline.timeline_duration, "默认时长应为5.0秒")
	assert_equals(JuicyTimelineResource.LoopMode.NO_LOOP, _test_timeline.loop_mode, "默认循环模式应为NO_LOOP")
	assert_equals(0, _test_timeline.loop_count, "默认循环次数应为0")
	assert_equals(1.0, _test_timeline.time_scale, "默认时间缩放应为1.0")
	
	# 测试轨道数组初始化
	assert_true(_test_timeline.property_tracks.is_empty(), "属性轨道数组应为空")
	assert_true(_test_timeline.feedback_tracks.is_empty(), "反馈轨道数组应为空")
	assert_true(_test_timeline.method_tracks.is_empty(), "方法轨道数组应为空")
	assert_true(_test_timeline.event_tracks.is_empty(), "事件轨道数组应为空")
	
	print("✅ JuicyTimelineResource基本功能测试通过")

# 测试轨道的添加、删除和重排序
func test_track_management():
	print("=== 🔄 测试轨道管理功能 ===")
	
	# 创建测试轨道
	_test_property_track = JuicyPropertyTrack.new()
	_test_property_track.track_name = "TestProperty"
	_test_property_track.property_path = "scale"
	
	_test_feedback_track = JuicyFeedbackTrack.new()
	_test_feedback_track.track_name = "TestFeedback"
	
	_test_method_track = JuicyMethodTrack.new()
	_test_method_track.track_name = "TestMethod"
	_test_method_track.method_name = "test_method"
	
	_test_event_track = JuicyEventTrack.new()
	_test_event_track.track_name = "TestEvent"
	
	# 测试添加轨道
	assert_true(_test_timeline.add_track(_test_property_track, "Property"), "添加属性轨道失败")
	assert_equals(1, _test_timeline.property_tracks.size(), "属性轨道数量应为1")
	
	assert_true(_test_timeline.add_track(_test_feedback_track, "Feedback"), "添加反馈轨道失败")
	assert_equals(1, _test_timeline.feedback_tracks.size(), "反馈轨道数量应为1")
	
	assert_true(_test_timeline.add_track(_test_method_track, "Method"), "添加方法轨道失败")
	assert_equals(1, _test_timeline.method_tracks.size(), "方法轨道数量应为1")
	
	assert_true(_test_timeline.add_track(_test_event_track, "Event"), "添加事件轨道失败")
	assert_equals(1, _test_timeline.event_tracks.size(), "事件轨道数量应为1")
	
	# 测试自动类型检测
	var auto_property_track = JuicyPropertyTrack.new()
	auto_property_track.track_name = "AutoProperty"
	assert_true(_test_timeline.add_track(auto_property_track), "自动类型检测添加属性轨道失败")
	assert_equals(2, _test_timeline.property_tracks.size(), "自动添加后属性轨道数量应为2")
	
	# 测试获取所有轨道
	var all_tracks = _test_timeline.get_all_tracks()
	assert_equals(5, all_tracks.size(), "所有轨道数量应为5")
	
	# 测试按类型获取轨道
	var property_tracks = _test_timeline.get_tracks_by_type("Property")
	assert_equals(2, property_tracks.size(), "属性轨道数量应为2")
	
	var feedback_tracks = _test_timeline.get_tracks_by_type("Feedback")
	assert_equals(1, feedback_tracks.size(), "反馈轨道数量应为1")
	
	# 测试移动轨道
	assert_true(_test_timeline.move_track(_test_property_track, 1, "Property"), "移动属性轨道失败")
	assert_equals(_test_property_track, _test_timeline.property_tracks[1], "属性轨道应在位置1")
	
	# 测试设置轨道状态
	assert_true(_test_timeline.set_track_enabled(_test_feedback_track, false), "设置轨道启用状态失败")
	assert_false(_test_feedback_track.enabled, "反馈轨道应为禁用状态")
	
	assert_true(_test_timeline.set_track_muted(_test_method_track, true), "设置轨道静音状态失败")
	assert_true(_test_method_track.muted, "方法轨道应为静音状态")
	
	# 测试删除轨道
	assert_true(_test_timeline.remove_track(_test_event_track), "删除事件轨道失败")
	assert_true(_test_timeline.event_tracks.is_empty(), "事件轨道数组应为空")
	
	# 测试按索引删除轨道
	assert_true(_test_timeline.remove_track_at(0, "Method"), "按索引删除方法轨道失败")
	assert_true(_test_timeline.method_tracks.is_empty(), "方法轨道数组应为空")
	
	print("✅ 轨道管理功能测试通过")

# 测试时间轴配置和循环模式
func test_timeline_configuration():
	print("=== ⏱️ 测试时间轴配置和循环模式 ===")
	
	# 测试时长配置
	_test_timeline.timeline_duration = 10.0
	assert_equals(10.0, _test_timeline.timeline_duration, "设置时长失败")
	assert_equals(10.0, _test_timeline.get_duration(), "获取时长失败")
	
	# 测试循环模式设置
	_test_timeline.set_loop_mode(JuicyTimelineResource.LoopMode.LOOP, 3)
	assert_equals(JuicyTimelineResource.LoopMode.LOOP, _test_timeline.loop_mode, "设置循环模式失败")
	assert_equals(3, _test_timeline.loop_count, "设置循环次数失败")
	assert_true(_test_timeline.is_looping(), "循环状态应为true")
	
	# 测试总时长计算
	assert_equals(30.0, _test_timeline.get_total_duration(), "循环总时长计算错误")
	
	# 测试无限循环
	_test_timeline.set_loop_mode(JuicyTimelineResource.LoopMode.LOOP, 0)
	assert_equals(0, _test_timeline.loop_count, "无限循环次数应为0")
	assert_equals(10.0, _test_timeline.get_total_duration(), "无限循环总时长应为单次时长")
	
	# 测试往返循环
	_test_timeline.set_loop_mode(JuicyTimelineResource.LoopMode.PING_PONG, 2)
	assert_equals(JuicyTimelineResource.LoopMode.PING_PONG, _test_timeline.loop_mode, "设置往返循环失败")
	assert_equals(2, _test_timeline.loop_count, "往返循环次数应为2")
	
	# 测试时间缩放
	_test_timeline.time_scale = 2.0
	assert_equals(2.0, _test_timeline.time_scale, "设置时间缩放失败")
	
	# 测试编辑器设置
	_test_timeline.timeline_zoom = 1.5
	assert_equals(1.5, _test_timeline.timeline_zoom, "设置时间轴缩放失败")
	
	_test_timeline.snap_enabled = false
	assert_false(_test_timeline.snap_enabled, "设置吸附启用失败")
	
	_test_timeline.snap_step = 0.05
	assert_equals(0.05, _test_timeline.snap_step, "设置吸附步长失败")
	
	print("✅ 时间轴配置和循环模式测试通过")

# 测试参数预设系统
func test_parameter_presets():
	print("=== 📊 测试参数预设系统 ===")
	
	# 测试输入参数定义
	_test_timeline.input_parameters = ["intensity", "speed", "duration"]
	assert_equals(3, _test_timeline.input_parameters.size(), "设置输入参数失败")
	
	# 测试添加参数预设
	var preset_values = {
		"intensity": 0.8,
		"speed": 1.2,
		"duration": 2.5
	}
	assert_true(_test_timeline.add_parameter_preset("high_intensity", preset_values), "添加参数预设失败")
	
	# 测试获取参数预设名称
	var preset_names = _test_timeline.get_parameter_preset_names()
	assert_equals(1, preset_names.size(), "获取预设名称数量失败")
	assert_equals("high_intensity", preset_names[0], "预设名称不匹配")
	
	# 测试应用参数预设
	var context = JuicyContext.new()
	assert_true(_test_timeline.apply_parameter_preset("high_intensity", context), "应用参数预设失败")
	assert_equals(0.8, context.get_parameter("intensity"), "应用intensity参数失败")
	assert_equals(1.2, context.get_parameter("speed"), "应用speed参数失败")
	assert_equals(2.5, context.get_parameter("duration"), "应用duration参数失败")
	
	# 测试移除参数预设
	assert_true(_test_timeline.remove_parameter_preset("high_intensity"), "移除参数预设失败")
	assert_true(_test_timeline.parameter_presets.is_empty(), "参数预设字典应为空")
	
	print("✅ 参数预设系统测试通过")

# 测试验证机制
func test_validation():
	print("=== ✅ 测试验证机制 ===")
	
	# 测试有效配置
	var valid_result = _test_timeline.validate_config()
	assert_true(valid_result.valid, "有效配置应该通过验证")
	assert_true(valid_result.issues.is_empty(), "有效配置不应有错误信息")
	
	# 测试无效时长
	_test_timeline.timeline_duration = -1.0
	var invalid_duration_result = _test_timeline.validate_config()
	assert_false(invalid_duration_result.valid, "负时长应该验证失败")
	assert_true(invalid_duration_result.issues.size() > 0, "负时长应该有错误信息")
	_test_timeline.timeline_duration = 5.0  # 恢复
	
	# 测试无效时间缩放
	_test_timeline.time_scale = 0.0
	var invalid_scale_result = _test_timeline.validate_config()
	assert_false(invalid_scale_result.valid, "零时间缩放应该验证失败")
	_test_timeline.time_scale = 1.0  # 恢复
	
	# 测试无效循环次数
	_test_timeline.loop_count = -1
	var invalid_loop_result = _test_timeline.validate_config()
	assert_false(invalid_loop_result.valid, "负循环次数应该验证失败")
	_test_timeline.loop_count = 0  # 恢复
	
	# 测试无效吸附步长
	_test_timeline.snap_step = -0.1
	var invalid_snap_result = _test_timeline.validate_config()
	assert_false(invalid_snap_result.valid, "负吸附步长应该验证失败")
	_test_timeline.snap_step = 0.1  # 恢复
	
	print("✅ 验证机制测试通过")

# 测试序列化和反序列化
func test_serialization():
	print("=== 💾 测试序列化和反序列化 ===")
	
	# 设置测试数据
	_test_timeline.timeline_duration = 8.0
	_test_timeline.loop_mode = JuicyTimelineResource.LoopMode.PING_PONG
	_test_timeline.loop_count = 2
	_test_timeline.time_scale = 1.5
	_test_timeline.description = "Test Timeline"
	
	# 测试获取配置字典
	var config_dict = _test_timeline.get_config_dict()
	assert_not_null(config_dict, "配置字典不应为null")
	assert_true(config_dict.has("timeline_duration"), "配置字典应包含timeline_duration")
	assert_true(config_dict.has("loop_mode"), "配置字典应包含loop_mode")
	assert_true(config_dict.has("loop_count"), "配置字典应包含loop_count")
	assert_true(config_dict.has("time_scale"), "配置字典应包含time_scale")
	assert_true(config_dict.has("description"), "配置字典应包含description")
	
	# 验证配置值
	assert_equals(8.0, config_dict["timeline_duration"], "配置字典中的时长值错误")
	assert_equals("PING_PONG", config_dict["loop_mode"], "配置字典中的循环模式错误")
	assert_equals(2, config_dict["loop_count"], "配置字典中的循环次数错误")
	assert_equals(1.5, config_dict["time_scale"], "配置字典中的时间缩放错误")
	assert_equals("Test Timeline", config_dict["description"], "配置字典中的描述错误")
	
	# 测试从字典加载
	var new_timeline = JuicyTimelineResource.new()
	assert_true(new_timeline.load_from_dict(config_dict), "从字典加载失败")
	assert_equals(8.0, new_timeline.timeline_duration, "加载后的时长值错误")
	assert_equals(JuicyTimelineResource.LoopMode.PING_PONG, new_timeline.loop_mode, "加载后的循环模式错误")
	assert_equals(2, new_timeline.loop_count, "加载后的循环次数错误")
	assert_equals(1.5, new_timeline.time_scale, "加载后的时间缩放错误")
	assert_equals("Test Timeline", new_timeline.description, "加载后的描述错误")
	
	print("✅ 序列化和反序列化测试通过")

# 测试克隆功能
func test_cloning():
	print("=== 📋 测试克隆功能 ===")
	
	# 添加一些轨道和配置
	_test_timeline.description = "Original Timeline"
	_test_timeline.timeline_duration = 6.0
	_test_timeline.loop_mode = JuicyTimelineResource.LoopMode.LOOP
	_test_timeline.loop_count = 3
	
	# 测试克隆
	var cloned_timeline = _test_timeline.clone()
	assert_not_null(cloned_timeline, "克隆的Timeline不应为null")
	assert_true(_test_timeline != cloned_timeline, "克隆的Timeline应是不同实例")
	
	# 验证克隆的属性
	assert_equals(_test_timeline.description, cloned_timeline.description, "克隆的描述应相同")
	assert_equals(_test_timeline.timeline_duration, cloned_timeline.timeline_duration, "克隆的时长应相同")
	assert_equals(_test_timeline.loop_mode, cloned_timeline.loop_mode, "克隆的循环模式应相同")
	assert_equals(_test_timeline.loop_count, cloned_timeline.loop_count, "克隆的循环次数应相同")
	assert_equals(_test_timeline.time_scale, cloned_timeline.time_scale, "克隆的时间缩放应相同")
	
	# 验证轨道也被克隆
	assert_equals(_test_timeline.property_tracks.size(), cloned_timeline.property_tracks.size(), "克隆的属性轨道数量应相同")
	assert_equals(_test_timeline.feedback_tracks.size(), cloned_timeline.feedback_tracks.size(), "克隆的反馈轨道数量应相同")
	
	# 验证轨道是不同的实例
	if _test_timeline.property_tracks.size() > 0 and cloned_timeline.property_tracks.size() > 0:
		assert_true(_test_timeline.property_tracks[0] != cloned_timeline.property_tracks[0], "克隆的轨道应是不同实例")
	
	print("✅ 克隆功能测试通过")

# 测试描述信息
func test_description():
	print("=== 📝 测试描述信息 ===")
	
	# 设置测试数据
	_test_timeline.timeline_duration = 12.0
	_test_timeline.loop_mode = JuicyTimelineResource.LoopMode.LOOP
	_test_timeline.loop_count = 5
	_test_timeline.time_scale = 2.0
	_test_timeline.description = "Test Description"
	
	# 获取描述信息
	var description = _test_timeline.get_description()
	assert_not_null(description, "描述信息不应为null")
	assert_true(description.find("JuicyTimelineResource") != -1, "描述应包含类型名")
	assert_true(description.find("duration=12.00") != -1, "描述应包含时长")
	assert_true(description.find("tracks=") != -1, "描述应包含轨道数量")
	assert_true(description.find("loop_mode=LOOP") != -1, "描述应包含循环模式")
	assert_true(description.find("loop_count=5") != -1, "描述应包含循环次数")
	assert_true(description.find("time_scale=2.00") != -1, "描述应包含时间缩放")
	assert_true(description.find("Test Description") != -1, "描述应包含自定义描述")
	
	print("✅ 描述信息测试通过")

# 测试驱动器创建
func test_driver_creation():
	print("=== 🚗 测试驱动器创建 ===")
	
	# 测试创建驱动器
	var drivers = _test_timeline.create_drivers()
	assert_not_null(drivers, "驱动器数组不应为null")
	assert_equals(1, drivers.size(), "应创建1个驱动器")
	
	var driver = drivers[0]
	assert_not_null(driver, "驱动器不应为null")
	assert_true(driver is JuicyTimelineDriver, "驱动器应为JuicyTimelineDriver类型")
	assert_equals(_test_timeline, driver.timeline_resource, "驱动器应引用Timeline资源")
	
	print("✅ 驱动器创建测试通过")

# 测试边界条件
func test_edge_cases():
	print("=== 🔍 测试边界条件 ===")
	
	# 测试空Timeline
	var empty_timeline = JuicyTimelineResource.new()
	assert_true(empty_timeline.get_all_tracks().is_empty(), "新Timeline应无轨道")
	assert_equals(0.0, empty_timeline.get_total_duration(), "空Timeline总时长应为0")
	
	# 测试添加null轨道
	assert_false(empty_timeline.add_track(null), "不应添加null轨道")
	
	# 测试添加错误类型轨道
	var wrong_track = Node.new()  # 非轨道类型
	assert_false(empty_timeline.add_track(wrong_track), "不应添加错误类型轨道")
	
	# 测试移除不存在的轨道
	var non_existent_track = JuicyPropertyTrack.new()
	assert_false(empty_timeline.remove_track(non_existent_track), "不应移除不存在的轨道")
	
	# 测试移除超出索引的轨道
	assert_false(empty_timeline.remove_track_at(0, "Property"), "不应移除超出索引的轨道")
	
	# 测试移动不存在的轨道
	assert_false(empty_timeline.move_track(non_existent_track, 0, "Property"), "不应移动不存在的轨道")
	
	# 测试应用不存在的参数预设
	var context = JuicyContext.new()
	assert_false(empty_timeline.apply_parameter_preset("non_existent", context), "不应应用不存在的参数预设")
	
	# 测试移除不存在的参数预设
	assert_false(empty_timeline.remove_parameter_preset("non_existent"), "不应移除不存在的参数预设")
	
	print("✅ 边界条件测试通过")

# 测试性能
func test_performance():
	print("=== ⚡ 测试性能 ===")
	
	# 创建包含大量轨道的Timeline
	var large_timeline = JuicyTimelineResource.new()
	
	# 添加100个属性轨道
	var start_time = Time.get_ticks_msec()
	for i in range(100):
		var track = JuicyPropertyTrack.new()
		track.track_name = "PropertyTrack" + str(i)
		track.property_path = "property" + str(i)
		large_timeline.add_track(track, "Property")
	
	var add_time = Time.get_ticks_msec() - start_time
	print("  添加100个轨道耗时: " + str(add_time) + "ms")
	assert_true(add_time < 1000, "添加轨道性能应小于1秒")
	
	# 测试获取所有轨道的性能
	start_time = Time.get_ticks_msec()
	for i in range(1000):
		var all_tracks = large_timeline.get_all_tracks()
		var track_count = all_tracks.size()
	
	var get_time = Time.get_ticks_msec() - start_time
	print("  获取所有轨道1000次耗时: " + str(get_time) + "ms")
	assert_true(get_time < 500, "获取轨道性能应小于0.5秒")
	
	# 测试验证性能
	start_time = Time.get_ticks_msec()
	for i in range(100):
		var validation_result = large_timeline.validate_config()
		var is_valid = validation_result.valid
	
	var validate_time = Time.get_ticks_msec() - start_time
	print("  验证100次耗时: " + str(validate_time) + "ms")
	assert_true(validate_time < 1000, "验证性能应小于1秒")
	
	print("✅ 性能测试通过")

# 运行所有测试
func run_all_tests():
	print("🚀 开始Timeline系统核心功能测试")
	print("==================================================")
	
	test_timeline_resource_basic()
	test_track_management()
	test_timeline_configuration()
	test_parameter_presets()
	test_validation()
	test_serialization()
	test_cloning()
	test_description()
	test_driver_creation()
	test_edge_cases()
	test_performance()
	
	print("==================================================")
	print("📊 测试统计:")
	print("  总测试数: %d" % _tests_run)
	print("  通过: %d" % _tests_passed)
	print("  失败: %d" % _tests_failed)
	
	if _tests_failed == 0:
		print("🎉 所有Timeline系统核心功能测试通过！")
	else:
		push_error("❌ 有 %d 个测试失败！" % _tests_failed)

func _ready():
	run_all_tests()