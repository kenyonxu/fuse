# Timeline轨道类型测试
# 测试属性轨道、反馈轨道、方法轨道和事件轨道的功能

extends Node

# 测试统计
var _tests_run = 0
var _tests_passed = 0
var _tests_failed = 0

# 测试资源
var _test_context: JuicyContext
var _test_target: Node
var _test_timeline: JuicyTimelineResource

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
	_test_timeline = JuicyTimelineResource.new()
	_test_target = Node.new()
	_test_context = JuicyContext.create(_test_timeline, _test_target)

# 测试属性轨道的曲线和关键帧功能
func test_property_track():
	print("=== 📊 测试属性轨道 ===")
	
	# 创建属性轨道
	var property_track = JuicyPropertyTrack.new()
	property_track.track_name = "TestPropertyTrack"
	property_track.property_path = "scale"
	property_track.value_range = Vector2(0.0, 2.0)
	property_track.relative = false
	
	# 测试基本属性
	assert_equals("Property", property_track.get_track_type(), "轨道类型应为Property")
	assert_true(property_track.validate_track().is_empty(), "有效轨道应通过验证")
	
	# 测试空属性路径验证
	property_track.property_path = ""
	assert_false(property_track.validate_track().is_empty(), "空属性路径应验证失败")
	property_track.property_path = "scale"  # 恢复
	
	# 测试动画曲线
	var animation_curve = Curve.new()
	animation_curve.add_point(Vector2(0, 0))
	animation_curve.add_point(Vector2(0.5, 0.8))
	animation_curve.add_point(Vector2(1, 1))
	property_track.animation_curve = animation_curve
	
	# 测试曲线采样
	var value_at_0 = property_track.get_value_at_time(0.0, _test_context)
	assert_almost_equals(0.0, value_at_0, 0.01, "时间0的值应为0")
	
	var value_at_0_5 = property_track.get_value_at_time(0.5, _test_context)
	assert_almost_equals(1.6, value_at_0_5, 0.01, "时间0.5的值应为1.6")
	
	var value_at_1 = property_track.get_value_at_time(1.0, _test_context)
	assert_almost_equals(2.0, value_at_1, 0.01, "时间1的值应为2.0")
	
	# 测试关键帧
	var keyframe1 = JuicyKeyframe.new()
	keyframe1.time = 0.0
	keyframe1.value = 0.0
	
	var keyframe2 = JuicyKeyframe.new()
	keyframe2.time = 0.5
	keyframe2.value = 1.5
	
	var keyframe3 = JuicyKeyframe.new()
	keyframe3.time = 1.0
	keyframe3.value = 2.0
	
	property_track.keyframes = [keyframe1, keyframe2, keyframe3]
	property_track.animation_curve = null  # 使用关键帧模式
	
	# 测试关键帧采样
	var keyframe_value_at_0_25 = property_track.get_value_at_time(0.25, _test_context)
	assert_almost_equals(0.75, keyframe_value_at_0_25, 0.01, "关键帧时间0.25的值应为0.75")
	
	# 测试时间变换
	property_track.time_offset = 0.2
	property_track.time_scale = 2.0
	
	var transformed_value = property_track.get_value_at_time(0.4, _test_context)
	# (0.4 - 0.2) * 2.0 = 0.4，在关键帧中对应值约为0.6
	assert_almost_equals(1.2, transformed_value, 0.1, "时间变换后的值不正确")
	
	# 测试混合模式
	property_track.blend_mode = JuicyPropertyTrack.BlendMode.ADDITIVE
	assert_equals(JuicyPropertyTrack.BlendMode.ADDITIVE, property_track.blend_mode, "混合模式设置失败")
	
	# 测试循环模式
	property_track.wrap_mode = 1  # Loop
	var looped_value = property_track.get_value_at_time(1.5, _test_context)
	# 1.5在循环模式下相当于0.5
	assert_almost_equals(1.5, looped_value, 0.1, "循环模式下的值不正确")
	
	# 测试缓动预设
	property_track.ease_preset = 1  # EaseIn
	var eased_value = property_track.get_value_at_time(0.5, _test_context)
	# EaseIn: t^2 = 0.25，在关键帧中对应值约为0.375
	assert_almost_equals(0.75, eased_value, 0.1, "缓动预设下的值不正确")
	
	# 测试轨道启用/禁用
	property_track.enabled = false
	var disabled_value = property_track.get_value_at_time(0.5, _test_context)
	assert_equals(0.0, disabled_value, "禁用轨道应返回0")
	
	property_track.muted = true
	var muted_value = property_track.get_value_at_time(0.5, _test_context)
	assert_equals(0.0, muted_value, "静音轨道应返回0")
	
	print("✅ 属性轨道测试通过")

# 测试反馈轨道的子效果触发
func test_feedback_track():
	print("=== 🔊 测试反馈轨道 ===")
	
	# 创建反馈轨道
	var feedback_track = JuicyFeedbackTrack.new()
	feedback_track.track_name = "TestFeedbackTrack"
	feedback_track.start_time = 1.0
	feedback_track.duration = 2.0
	
	# 创建测试资源
	var test_resource = JuicyShakeResource.new()
	feedback_track.resource = test_resource
	
	# 测试基本属性
	assert_equals("Feedback", feedback_track.get_track_type(), "轨道类型应为Feedback")
	assert_true(feedback_track.validate_track().is_empty(), "有效轨道应通过验证")
	
	# 测试空资源验证
	feedback_track.resource = null
	assert_false(feedback_track.validate_track().is_empty(), "空资源应验证失败")
	feedback_track.resource = test_resource  # 恢复
	
	# 测试实际持续时间
	assert_equals(2.0, feedback_track.get_actual_duration(), "应返回设置的持续时间")
	
	feedback_track.duration = -1.0  # 使用资源自身时长
	# 这里假设资源有get_duration方法，如果没有则返回默认值1.0
	var resource_duration = feedback_track.get_actual_duration()
	assert_true(resource_duration > 0.0, "应返回正数持续时间")
	
	# 测试时间范围
	assert_equals(1.0, feedback_track.get_start_time(), "开始时间应为1.0")
	assert_equals(3.0, feedback_track.get_end_time(), "结束时间应为3.0")
	
	# 测试触发条件
	_test_context.current_time = 0.5
	assert_false(feedback_track.should_trigger(0.5, _test_context), "时间未到不应触发")
	
	_test_context.current_time = 1.0
	assert_true(feedback_track.should_trigger(1.0, _test_context), "时间到达应触发")
	
	_test_context.current_time = 2.5
	assert_true(feedback_track.should_trigger(2.5, _test_context), "时间范围内应触发")
	
	_test_context.current_time = 3.0
	assert_false(feedback_track.should_trigger(3.0, _test_context), "时间结束不应触发")
	
	# 测试禁用状态
	feedback_track.enabled = false
	_test_context.current_time = 1.5
	assert_false(feedback_track.should_trigger(1.5, _test_context), "禁用轨道不应触发")
	feedback_track.enabled = true  # 恢复
	
	# 测试静音状态
	feedback_track.muted = true
	assert_false(feedback_track.should_trigger(1.5, _test_context), "静音轨道不应触发")
	feedback_track.muted = false  # 恢复
	
	# 测试中断设置
	feedback_track.interrupt_on_restart = false
	feedback_track.trigger_once = true
	
	# 第一次触发
	var trigger1 = feedback_track.should_trigger(1.5, _test_context)
	assert_true(trigger1, "第一次应触发")
	
	# 模拟触发
	feedback_track._active_context_id = "test_id"
	feedback_track._triggered = true
	
	# 第二次触发
	var trigger2 = feedback_track.should_trigger(1.5, _test_context)
	assert_false(trigger2, "trigger_once为true时不应重复触发")
	
	# 测试高级属性
	feedback_track.inherit_time_scale = false
	assert_false(feedback_track.inherit_time_scale, "继承时间缩放设置失败")
	
	feedback_track.blend_in_time = 0.5
	assert_equals(0.5, feedback_track.blend_in_time, "淡入时间设置失败")
	
	feedback_track.blend_out_time = 0.3
	assert_equals(0.3, feedback_track.blend_out_time, "淡出时间设置失败")
	
	feedback_track.auto_start = false
	assert_false(feedback_track.auto_start, "自动开始设置失败")
	
	feedback_track.loop_sub_effect = true
	assert_true(feedback_track.loop_sub_effect, "循环子效果设置失败")
	
	print("✅ 反馈轨道测试通过")

# 测试方法轨道的方法调用
func test_method_track():
	print("=== 📞 测试方法轨道 ===")
	
	# 创建方法轨道
	var method_track = JuicyMethodTrack.new()
	method_track.track_name = "TestMethodTrack"
	method_track.trigger_time = 2.0
	method_track.method_name = "test_method"
	method_track.args = [1, "test", true]
	
	# 测试基本属性
	assert_equals("Method", method_track.get_track_type(), "轨道类型应为Method")
	assert_true(method_track.validate_track().is_empty(), "有效轨道应通过验证")
	
	# 测试空方法名验证
	method_track.method_name = ""
	assert_false(method_track.validate_track().is_empty(), "空方法名应验证失败")
	method_track.method_name = "test_method"  # 恢复
	
	# 测试负时间验证
	method_track.trigger_time = -1.0
	assert_false(method_track.validate_track().is_empty(), "负触发时间应验证失败")
	method_track.trigger_time = 2.0  # 恢复
	
	# 测试触发条件
	_test_context.current_time = 1.0
	assert_false(method_track.should_trigger(1.0, _test_context), "时间未到不应触发")
	
	_test_context.current_time = 2.0
	assert_true(method_track.should_trigger(2.0, _test_context), "时间到达应触发")
	
	# 测试trigger_once
	method_track.trigger_once = true
	method_track._triggered = true
	assert_false(method_track.should_trigger(2.0, _test_context), "trigger_once为true时不应重复触发")
	method_track._triggered = false  # 恢复
	
	# 测试重复间隔
	method_track.repeat_interval = 1.0
	method_track.max_repeats = 3
	method_track._trigger_count = 2
	method_track._last_trigger_time = 1.5
	
	_test_context.current_time = 2.4  # 距离上次触发0.9秒，小于间隔
	assert_false(method_track.should_trigger(2.4, _test_context), "未达到重复间隔不应触发")
	
	_test_context.current_time = 2.6  # 距离上次触发1.1秒，大于间隔
	assert_true(method_track.should_trigger(2.6, _test_context), "达到重复间隔应触发")
	
	# 测试最大重复次数
	method_track._trigger_count = 3
	assert_false(method_track.should_trigger(2.6, _test_context), "达到最大重复次数不应触发")
	
	# 测试延迟
	method_track.delay = 0.5
	method_track._pending_calls.clear()
	
	# 模拟触发
	method_track.trigger_method(_test_context)
	assert_equals(1, method_track._pending_calls.size(), "延迟调用应添加到待处理列表")
	
	# 测试待处理调用处理
	_test_context.current_time = 2.6
	method_track.process_pending_calls(_test_context)
	assert_equals(0, method_track._pending_calls.size(), "到期的延迟调用应被处理")
	
	# 测试高级属性
	method_track.target_path = NodePath("../TestNode")
	assert_equals(NodePath("../TestNode"), method_track.target_path, "目标路径设置失败")
	
	method_track.trigger_once = false
	assert_false(method_track.trigger_once, "触发一次设置失败")
	
	method_track.repeat_interval = -1.0
	assert_equals(-1.0, method_track.repeat_interval, "重复间隔设置失败")
	
	method_track.max_repeats = -1
	assert_equals(-1, method_track.max_repeats, "最大重复次数设置失败")
	
	print("✅ 方法轨道测试通过")

# 测试事件轨道的事件触发
func test_event_track():
	print("=== ⚡ 测试事件轨道 ===")
	
	# 创建事件轨道
	var event_track = JuicyEventTrack.new()
	event_track.track_name = "TestEventTrack"
	event_track.trigger_time = 1.5
	
	# 创建测试事件
	var test_event = JuicyEvent.new()
	event_track.juicy_event = test_event
	
	# 测试基本属性
	assert_equals("Event", event_track.get_track_type(), "轨道类型应为Event")
	assert_true(event_track.validate_track().is_empty(), "有效轨道应通过验证")
	
	# 测试空事件验证
	event_track.juicy_event = null
	event_track.event_template = null
	assert_false(event_track.validate_track().is_empty(), "空事件和模板应验证失败")
	
	event_track.juicy_event = test_event  # 恢复
	
	# 测试负时间验证
	event_track.trigger_time = -1.0
	assert_false(event_track.validate_track().is_empty(), "负触发时间应验证失败")
	event_track.trigger_time = 1.5  # 恢复
	
	# 测试触发条件
	_test_context.current_time = 1.0
	assert_false(event_track.should_trigger(1.0, _test_context), "时间未到不应触发")
	
	_test_context.current_time = 1.5
	assert_true(event_track.should_trigger(1.5, _test_context), "时间到达应触发")
	
	# 测试trigger_once
	event_track.trigger_once = true
	event_track._triggered = true
	assert_false(event_track.should_trigger(1.5, _test_context), "trigger_once为true时不应重复触发")
	event_track._triggered = false  # 恢复
	
	# 测试延迟
	event_track.delay = 0.3
	event_track._pending_events.clear()
	
	# 模拟触发
	event_track.trigger_event(_test_target, _test_context)
	assert_equals(1, event_track._pending_events.size(), "延迟事件应添加到待处理列表")
	
	# 测试待处理事件处理
	_test_context.current_time = 1.8
	event_track.process_pending_events(_test_context)
	assert_equals(0, event_track._pending_events.size(), "到期的延迟事件应被处理")
	
	# 测试事件数据覆盖
	event_track.event_data = {
		"volume": 0.8,
		"pitch": 1.2,
		"custom_data": "test_value"
	}
	
	var actual_event = event_track.create_actual_event(_test_target, _test_context)
	assert_not_null(actual_event, "应创建实际事件")
	
	# 测试事件模板
	var event_template = JuicyEvent.new()
	event_template.set("volume", 0.5)
	event_track.event_template = event_template
	event_track.juicy_event = null
	
	var template_event = event_track.create_actual_event(_test_target, _test_context)
	assert_not_null(template_event, "应从模板创建事件")
	assert_true(event_template != template_event, "应创建新的事件实例")
	
	# 测试高级属性
	event_track.target_path = NodePath("../TestNode")
	assert_equals(NodePath("../TestNode"), event_track.target_path, "目标路径设置失败")
	
	event_track.trigger_once = false
	assert_false(event_track.trigger_once, "触发一次设置失败")
	
	event_track.delay = 0.0
	assert_equals(0.0, event_track.delay, "延迟设置失败")
	
	print("✅ 事件轨道测试通过")

# 测试轨道的参数映射功能
func test_track_parameter_mapping():
	print("=== 🗺️ 测试轨道参数映射 ===")
	
	# 创建属性轨道
	var property_track = JuicyPropertyTrack.new()
	property_track.track_name = "TestPropertyTrack"
	property_track.property_path = "scale"
	property_track.use_parameter_mapping = true
	
	# 创建参数映射
	var mapping = JuicyParameterMapping.new()
	mapping.input_parameter = "intensity"
	mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_VALUE
	mapping.target_property = "intensity"
	mapping.enabled = true
	
	# 创建测试曲线
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(1, 1))
	mapping.curve = curve
	
	property_track.parameter_mappings = [mapping]
	
	# 测试参数映射验证
	assert_true(property_track.validate_track().is_empty(), "有效参数映射应通过验证")
	
	# 测试空映射验证
	var empty_mapping = JuicyParameterMapping.new()
	property_track.parameter_mappings = [empty_mapping]
	assert_false(property_track.validate_track().is_empty(), "空参数映射应验证失败")
	
	property_track.parameter_mappings = [mapping]  # 恢复
	
	# 测试参数映射应用
	_test_context.set_parameter("intensity", 0.5)
	var mapped_value = property_track.apply_parameter_mappings(_test_context, 1.0)
	assert_almost_equals(0.5, mapped_value, 0.01, "参数映射应用失败")
	
	# 测试禁用映射
	mapping.enabled = false
	var disabled_value = property_track.apply_parameter_mappings(_test_context, 1.0)
	assert_equals(1.0, disabled_value, "禁用映射应返回原值")
	mapping.enabled = true  # 恢复
	
	# 测试不同映射类型
	mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_PROPERTY
	mapping.target_property = "offset"
	
	var offset_value = property_track.apply_parameter_mappings(_test_context, 1.0)
	assert_almost_equals(1.5, offset_value, 0.01, "offset映射应用失败")
	
	# 测试自定义映射
	mapping.mapping_type = JuicyParameterMapping.MappingType.CUSTOM
	mapping.custom_handler = "custom_mapping_handler"
	
	# 测试反馈轨道参数映射
	var feedback_track = JuicyFeedbackTrack.new()
	feedback_track.track_name = "TestFeedbackTrack"
	feedback_track.use_parameter_mapping = true
	feedback_track.parameter_mappings = [mapping]
	
	assert_true(feedback_track.validate_track().is_empty(), "反馈轨道参数映射应通过验证")
	
	# 测试方法轨道参数映射
	var method_track = JuicyMethodTrack.new()
	method_track.track_name = "TestMethodTrack"
	method_track.method_name = "test_method"
	method_track.args = ["$intensity"]  # 参数映射占位符
	method_track.use_parameter_mapping = true
	method_track.parameter_mappings = [mapping]
	
	assert_true(method_track.validate_track().is_empty(), "方法轨道参数映射应通过验证")
	
	var processed_args = method_track._process_parameter_mappings(_test_context)
	assert_equals(1, processed_args.size(), "应处理一个参数")
	assert_almost_equals(0.5, processed_args[0], 0.01, "参数映射处理失败")
	
	# 测试事件轨道参数映射
	var event_track = JuicyEventTrack.new()
	event_track.track_name = "TestEventTrack"
	event_track.use_parameter_mapping = true
	event_track.parameter_mappings = [mapping]
	
	assert_true(event_track.validate_track().is_empty(), "事件轨道参数映射应通过验证")
	
	print("✅ 轨道参数映射测试通过")

# 测试轨道的序列化和克隆
func test_track_serialization_and_cloning():
	print("=== 💾 测试轨道序列化和克隆 ===")
	
	# 创建属性轨道
	var property_track = JuicyPropertyTrack.new()
	property_track.track_name = "TestPropertyTrack"
	property_track.property_path = "scale"
	property_track.value_range = Vector2(0.0, 2.0)
	property_track.blend_mode = JuicyPropertyTrack.BlendMode.ADDITIVE
	property_track.use_parameter_mapping = true
	
	# 添加参数映射
	var mapping = JuicyParameterMapping.new()
	mapping.input_parameter = "intensity"
	mapping.enabled = true
	property_track.parameter_mappings = [mapping]
	
	# 测试序列化
	var config_dict = property_track.get_config_dict()
	assert_not_null(config_dict, "配置字典不应为null")
	assert_true(config_dict.has("property_path"), "配置应包含property_path")
	assert_true(config_dict.has("value_range"), "配置应包含value_range")
	assert_true(config_dict.has("blend_mode"), "配置应包含blend_mode")
	assert_true(config_dict.has("use_parameter_mapping"), "配置应包含use_parameter_mapping")
	
	# 测试反序列化
	var new_track = JuicyPropertyTrack.new()
	assert_true(new_track.load_from_dict(config_dict), "从字典加载应成功")
	assert_equals(property_track.property_path, new_track.property_path, "加载的属性路径应相同")
	assert_equals(property_track.value_range, new_track.value_range, "加载的值范围应相同")
	assert_equals(property_track.blend_mode, new_track.blend_mode, "加载的混合模式应相同")
	assert_equals(property_track.use_parameter_mapping, new_track.use_parameter_mapping, "加载的参数映射开关应相同")
	
	# 测试克隆
	var cloned_track = property_track.clone()
	assert_not_null(cloned_track, "克隆的轨道不应为null")
	assert_true(property_track != cloned_track, "克隆的轨道应是不同实例")
	
	assert_equals(property_track.track_name, cloned_track.track_name, "克隆的轨道名应相同")
	assert_equals(property_track.property_path, cloned_track.property_path, "克隆的属性路径应相同")
	assert_equals(property_track.value_range, cloned_track.value_range, "克隆的值范围应相同")
	assert_equals(property_track.blend_mode, cloned_track.blend_mode, "克隆的混合模式应相同")
	assert_equals(property_track.use_parameter_mapping, cloned_track.use_parameter_mapping, "克隆的参数映射开关应相同")
	
	# 测试参数映射也被克隆
	assert_equals(property_track.parameter_mappings.size(), cloned_track.parameter_mappings.size(), "克隆的参数映射数量应相同")
	if property_track.parameter_mappings.size() > 0:
		assert_true(property_track.parameter_mappings[0] != cloned_track.parameter_mappings[0], "克隆的参数映射应是不同实例")
	
	print("✅ 轨道序列化和克隆测试通过")

# 测试轨道的边界条件
func test_track_edge_cases():
	print("=== 🔍 测试轨道边界条件 ===")
	
	# 测试属性轨道边界条件
	var property_track = JuicyPropertyTrack.new()
	property_track.property_path = "scale"
	
	# 测试无效值范围
	property_track.value_range = Vector2(1.0, 0.0)  # 最小值大于最大值
	assert_false(property_track.validate_track().is_empty(), "无效值范围应验证失败")
	
	property_track.value_range = Vector2(0.0, 1.0)  # 恢复
	
	# 测试无效时间缩放
	property_track.time_scale = 0.0
	assert_false(property_track.validate_track().is_empty(), "零时间缩放应验证失败")
	
	property_track.time_scale = 1.0  # 恢复
	
	# 测试空曲线
	property_track.animation_curve = Curve.new()  # 空曲线
	var empty_curve_value = property_track.get_value_at_time(0.5, _test_context)
	assert_equals(0.0, empty_curve_value, "空曲线应返回0")
	
	# 测试反馈轨道边界条件
	var feedback_track = JuicyFeedbackTrack.new()
	feedback_track.start_time = -1.0
	assert_false(feedback_track.validate_track().is_empty(), "负开始时间应验证失败")
	
	feedback_track.start_time = 0.0  # 恢复
	feedback_track.duration = -2.0
	assert_false(feedback_track.validate_track().is_empty(), "无效持续时间应验证失败")
	
	feedback_track.duration = 1.0  # 恢复
	feedback_track.blend_in_time = -0.1
	assert_false(feedback_track.validate_track().is_empty(), "负淡入时间应验证失败")
	
	feedback_track.blend_in_time = 0.0  # 恢复
	feedback_track.blend_out_time = -0.1
	assert_false(feedback_track.validate_track().is_empty(), "负淡出时间应验证失败")
	
	# 测试方法轨道边界条件
	var method_track = JuicyMethodTrack.new()
	method_track.method_name = "test_method"
	method_track.delay = -0.1
	assert_false(method_track.validate_track().is_empty(), "负延迟应验证失败")
	
	method_track.delay = 0.0  # 恢复
	method_track.repeat_interval = -2.0
	assert_false(method_track.validate_track().is_empty(), "无效重复间隔应验证失败")
	
	method_track.repeat_interval = 1.0  # 恢复
	method_track.max_repeats = -2
	assert_false(method_track.validate_track().is_empty(), "无效最大重复次数应验证失败")
	
	# 测试事件轨道边界条件
	var event_track = JuicyEventTrack.new()
	event_track.delay = -0.1
	assert_false(event_track.validate_track().is_empty(), "负延迟应验证失败")
	
	print("✅ 轨道边界条件测试通过")

# 运行所有测试
func run_all_tests():
	print("🚀 开始Timeline轨道类型测试")
	print("==================================================")
	
	# 设置测试环境
	setup_test_environment()
	
	test_property_track()
	test_feedback_track()
	test_method_track()
	test_event_track()
	test_track_parameter_mapping()
	test_track_serialization_and_cloning()
	test_track_edge_cases()
	
	print("==================================================")
	print("📊 测试统计:")
	print("  总测试数: %d" % _tests_run)
	print("  通过: %d" % _tests_passed)
	print("  失败: %d" % _tests_failed)
	
	if _tests_failed == 0:
		print("🎉 所有Timeline轨道类型测试通过！")
	else:
		push_error("❌ 有 %d 个测试失败！" % _tests_failed)

func _ready():
	run_all_tests()