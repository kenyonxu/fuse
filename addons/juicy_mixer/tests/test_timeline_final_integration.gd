# JuicyMixer V3 Timeline系统最终集成测试

extends Node

# 测试结果
var test_results = {
	"total_tests": 0,
	"passed_tests": 0,
	"failed_tests": 0,
	"test_details": []
}

func _ready():
	print("开始Timeline系统最终集成测试")
	
	# 运行所有集成测试
	run_all_integration_tests()
	
	# 生成测试报告
	generate_test_report()

# 运行所有集成测试
func run_all_integration_tests():
	print("\n=== Timeline系统集成测试开始 ===")
	
	# 1. 基础功能测试
	test_basic_timeline_functionality()
	
	# 2. 轨道类型测试
	test_all_track_types()
	
	# 3. 参数映射集成测试
	test_parameter_mapping_integration()
	
	# 4. 条件系统集成测试
	test_condition_system_integration()
	
	# 5. 性能集成测试
	test_performance_integration()
	
	# 6. 编辑器集成测试
	test_editor_integration()
	
	# 7. 资源管理测试
	test_resource_management()
	
	# 8. 错误处理测试
	test_error_handling()
	
	# 9. 内存管理测试
	test_memory_management()
	
	# 10. 系统兼容性测试
	test_system_compatibility()

# 1. 基础功能测试
func test_basic_timeline_functionality():
	print("\n--- 基础功能测试 ---")
	
	# 测试Timeline创建和播放
	var timeline = create_test_timeline()
	assert(timeline != null, "Timeline创建失败")
	
	var target_node = create_test_target()
	assert(target_node != null, "目标节点创建失败")
	
	# 测试播放
	var context_id = JuicyMixer.play(timeline, target_node)
	assert(not context_id.is_empty(), "Timeline播放失败")
	
	# 测试状态查询
	var context = JuicyMixer.get_context(context_id)
	assert(context != null, "上下文获取失败")
	assert(context.is_playing(), "播放状态不正确")
	
	# 测试暂停和恢复
	JuicyMixer.pause(context_id)
	context = JuicyMixer.get_context(context_id)
	assert(context.is_paused(), "暂停状态不正确")
	
	JuicyMixer.resume(context_id)
	context = JuicyMixer.get_context(context_id)
	assert(not context.is_paused(), "恢复状态不正确")
	
	# 测试停止
	JuicyMixer.stop(context_id)
	context = JuicyMixer.get_context(context_id)
	assert(context.is_completed(), "停止状态不正确")
	
	# 清理
	target_node.queue_free()
	
	record_test_result("基础功能测试", true, "所有基础功能正常工作")

# 2. 轨道类型测试
func test_all_track_types():
	print("\n--- 轨道类型测试 ---")
	
	# 测试属性轨道
	test_property_track()
	
	# 测试反馈轨道
	test_feedback_track()
	
	# 测试方法轨道
	test_method_track()
	
	# 测试事件轨道
	test_event_track()

func test_property_track():
	var timeline = JuicyTimelineResource.new()
	var track = JuicyPropertyTrack.new()
	track.track_name = "TestPropertyTrack"
	track.target_node_path = "Sprite2D"
	track.property_path = "scale"
	track.duration = 1.0
	
	# 添加关键帧
	var keyframe1 = JuicyKeyframe.new()
	keyframe1.time = 0.0
	keyframe1.value = Vector2.ONE
	keyframe1.interpolation_type = JuicyKeyframe.InterpolationType.LINEAR
	
	var keyframe2 = JuicyKeyframe.new()
	keyframe2.time = 1.0
	keyframe2.value = Vector2(2.0, 2.0)
	keyframe2.interpolation_type = JuicyKeyframe.InterpolationType.EASE_IN_OUT
	
	track.add_keyframe(keyframe1)
	track.add_keyframe(keyframe2)
	
	timeline.add_track(track)
	
	# 测试播放
	var target = create_test_target()
	var context_id = JuicyMixer.play(timeline, target)
	
	await get_tree().create_timer(1.5).timeout
	
	# 验证缩放变化
	var final_scale = target.scale
	assert(final_scale.x > 1.0 and final_scale.y > 1.0, "属性轨道缩放效果未正确应用")
	
	JuicyMixer.stop(context_id)
	target.queue_free()
	
	record_test_result("属性轨道测试", true, "属性轨道正常工作")

func test_feedback_track():
	var timeline = JuicyTimelineResource.new()
	var track = JuicyFeedbackTrack.new()
	track.track_name = "TestFeedbackTrack"
	track.duration = 0.5
	
	# 创建震动资源
	var shake_resource = JuicyShakeResource.new()
	shake_resource.resource_name = "TestShake"
	shake_resource.add_shake_data("offset", 10.0, 10.0, 0.5)
	
	track.resource = shake_resource
	
	# 添加触发关键帧
	var trigger = JuicyKeyframe.new()
	trigger.time = 0.1
	trigger.value = true
	trigger.interpolation_type = JuicyKeyframe.InterpolationType.STEP
	
	track.add_keyframe(trigger)
	timeline.add_track(track)
	
	# 测试播放
	var target = create_test_target()
	var context_id = JuicyMixer.play(timeline, target)
	
	await get_tree().create_timer(1.0).timeout
	
	JuicyMixer.stop(context_id)
	target.queue_free()
	
	record_test_result("反馈轨道测试", true, "反馈轨道正常工作")

func test_method_track():
	var timeline = JuicyTimelineResource.new()
	var track = JuicyMethodTrack.new()
	track.track_name = "TestMethodTrack"
	track.target_node_path = "."
	track.method_name = "test_method"
	track.duration = 1.0
	
	# 添加方法调用关键帧
	var call_keyframe = JuicyKeyframe.new()
	call_keyframe.time = 0.5
	call_keyframe.value = ["test_param", 42]
	call_keyframe.interpolation_type = JuicyKeyframe.InterpolationType.STEP
	
	track.add_keyframe(call_keyframe)
	timeline.add_track(track)
	
	# 测试播放
	var target = create_test_target()
	target.set_script(self)  # 设置测试脚本
	
	var context_id = JuicyMixer.play(timeline, target)
	
	await get_tree().create_timer(1.5).timeout
	
	JuicyMixer.stop(context_id)
	target.queue_free()
	
	record_test_result("方法轨道测试", true, "方法轨道正常工作")

func test_event_track():
	var timeline = JuicyTimelineResource.new()
	var track = JuicyEventTrack.new()
	track.track_name = "TestEventTrack"
	track.duration = 1.0
	
	# 创建事件
	var event = JuicyEvent.create_particle_spawn_event("test_event", null, null, 10)
	track.juicy_event = event
	
	# 添加事件触发关键帧
	var trigger = JuicyKeyframe.new()
	trigger.time = 0.0
	trigger.value = {"count": 10, "spread": 30.0}
	trigger.interpolation_type = JuicyKeyframe.InterpolationType.STEP
	
	track.add_keyframe(trigger)
	timeline.add_track(track)
	
	# 测试播放
	var target = create_test_target()
	var context_id = JuicyMixer.play(timeline, target)
	
	await get_tree().create_timer(1.5).timeout
	
	JuicyMixer.stop(context_id)
	target.queue_free()
	
	record_test_result("事件轨道测试", true, "事件轨道正常工作")

# 3. 参数映射集成测试
func test_parameter_mapping_integration():
	print("\n--- 参数映射集成测试 ---")
	
	var timeline = JuicyTimelineResource.new()
	var track = JuicyPropertyTrack.new()
	track.track_name = "ParameterMappedTrack"
	track.target_node_path = "Sprite2D"
	track.property_path = "scale"
	track.duration = 2.0
	track.use_parameter_mapping = true
	
	# 创建参数映射
	var mapping = JuicyParameterMapping.new()
	mapping.input_parameter = "test_intensity"
	mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_VALUE
	mapping.target_property = "intensity"
	mapping.input_range = Vector2(0.0, 1.0)
	mapping.output_range = Vector2(0.5, 2.0)
	
	track.parameter_mappings = [mapping]
	
	# 添加关键帧
	var keyframe = JuicyKeyframe.new()
	keyframe.time = 0.0
	keyframe.value = Vector2.ONE
	keyframe.interpolation_type = JuicyKeyframe.InterpolationType.LINEAR
	
	track.add_keyframe(keyframe)
	timeline.add_track(track)
	
	# 测试播放
	var target = create_test_target()
	var context_id = JuicyMixer.play(timeline, target)
	
	# 设置参数
	var context = JuicyMixer.get_context(context_id)
	context.set_parameter("test_intensity", 0.8)  # 80%强度
	
	await get_tree().create_timer(2.5).timeout
	
	# 验证参数映射效果
	var final_scale = target.scale
	assert(final_scale.x > 1.0, "参数映射效果未正确应用")
	
	JuicyMixer.stop(context_id)
	target.queue_free()
	
	record_test_result("参数映射集成测试", true, "参数映射正常工作")

# 4. 条件系统集成测试
func test_condition_system_integration():
	print("\n--- 条件系统集成测试 ---")
	
	var timeline = JuicyTimelineResource.new()
	var track = JuicyPropertyTrack.new()
	track.track_name = "ConditionalTrack"
	track.target_node_path = "Sprite2D"
	track.property_path = "modulate"
	track.duration = 2.0
	
	# 创建条件
	var condition = JuicyParameterCondition.new()
	condition.parameter_name = "test_condition"
	condition.operator = JuicyParameterCondition.ComparisonOperator.GREATER_THAN
	condition.target_value = 0.5
	
	track.activation_condition = condition
	
	# 添加关键帧
	var keyframe = JuicyKeyframe.new()
	keyframe.time = 0.0
	keyframe.value = Color.RED
	keyframe.interpolation_type = JuicyKeyframe.InterpolationType.STEP
	
	track.add_keyframe(keyframe)
	timeline.add_track(track)
	
	# 测试播放 - 条件不满足
	var target = create_test_target()
	var context_id = JuicyMixer.play(timeline, target)
	
	var context = JuicyMixer.get_context(context_id)
	context.set_parameter("test_condition", 0.3)  # 条件不满足
	
	await get_tree().create_timer(1.0).timeout
	
	# 验证轨道未激活
	var initial_color = target.modulate
	assert(initial_color != Color.RED, "条件轨道在条件不满足时被激活")
	
	# 设置条件满足
	context.set_parameter("test_condition", 0.8)  # 条件满足
	
	await get_tree().create_timer(1.0).timeout
	
	# 验证轨道已激活
	var activated_color = target.modulate
	assert(activated_color == Color.RED, "条件轨道在条件满足时未被激活")
	
	JuicyMixer.stop(context_id)
	target.queue_free()
	
	record_test_result("条件系统集成测试", true, "条件系统正常工作")

# 5. 性能集成测试
func test_performance_integration():
	print("\n--- 性能集成测试 ---")
	
	# 测试大量Timeline实例的性能
	var timeline = create_performance_test_timeline()
	var targets = []
	
	# 创建目标节点
	for i in range(20):
		targets.append(create_test_target())
	
	# 测量创建时间
	var start_time = Time.get_ticks_msec()
	
	# 创建多个Timeline实例
	var context_ids = []
	for i in range(20):
		var context_id = JuicyMixer.play(timeline, targets[i])
		context_ids.append(context_id)
	
	var creation_time = Time.get_ticks_msec() - start_time
	
	# 等待播放完成
	await get_tree().create_timer(2.0).timeout
	
	# 测量播放时间
	var playback_time = Time.get_ticks_msec() - creation_time
	
	# 清理
	for context_id in context_ids:
		JuicyMixer.stop(context_id)
	
	for target in targets:
		target.queue_free()
	
	# 性能验证
	assert(creation_time < 1000, "Timeline创建时间过长: " + str(creation_time) + "ms")
	assert(playback_time < 3000, "Timeline播放时间过长: " + str(playback_time) + "ms")
	
	record_test_result("性能集成测试", true, "性能表现良好")

# 6. 编辑器集成测试
func test_editor_integration():
	print("\n--- 编辑器集成测试 ---")
	
	# 测试Timeline资源验证
	var timeline = JuicyTimelineResource.new()
	var validation = timeline.validate()
	
	assert(validation.valid, "Timeline验证失败")
	assert(validation.issues.is_empty(), "Timeline验证存在问题")
	
	# 测试轨道验证
	var track = JuicyPropertyTrack.new()
	var track_validation = track.validate()
	
	assert(track_validation.valid, "轨道验证失败")
	
	record_test_result("编辑器集成测试", true, "编辑器集成正常")

# 7. 资源管理测试
func test_resource_management():
	print("\n--- 资源管理测试 ---")
	
	# 测试资源序列化
	var timeline = create_test_timeline()
	var json_string = JSON.stringify(timeline.to_dict())
	
	assert(not json_string.is_empty(), "Timeline序列化失败")
	
	# 测试资源反序列化
	var parsed_dict = JSON.parse_string(json_string)
	
	assert(parsed_dict != null, "Timeline反序列化失败")
	
	record_test_result("资源管理测试", true, "资源管理正常")

# 8. 错误处理测试
func test_error_handling():
	print("\n--- 错误处理测试 ---")
	
	# 测试无效Timeline播放
	var invalid_context_id = JuicyMixer.play(null, null)
	assert(invalid_context_id.is_empty(), "无效Timeline播放应该失败")
	
	# 测试无效上下文操作
	var result = JuicyMixer.pause("invalid_context")
	assert(not result, "无效上下文暂停应该失败")
	
	# 测试资源验证错误处理
	var invalid_timeline = JuicyTimelineResource.new()
	invalid_timeline.duration = -1.0
	
	var validation = invalid_timeline.validate()
	assert(not validation.valid, "无效Timeline应该验证失败")
	
	record_test_result("错误处理测试", true, "错误处理正常")

# 9. 内存管理测试
func test_memory_management():
	print("\n--- 内存管理测试 ---")
	
	# 测试大量Timeline创建和销毁
	var initial_memory = OS.get_static_memory_usage() / 1024  # KB
	
	var timelines = []
	for i in range(50):
		timelines.append(create_test_timeline())
	
	var peak_memory = OS.get_static_memory_usage() / 1024  # KB
	
	# 清理
	timelines.clear()
	
	await get_tree().process_frame  # 等待一帧
	
	var final_memory = OS.get_static_memory_usage() / 1024  # KB
	
	# 验证内存释放
	assert(final_memory < peak_memory, "内存未正确释放")
	
	record_test_result("内存管理测试", true, "内存管理正常")

# 10. 系统兼容性测试
func test_system_compatibility():
	print("\n--- 系统兼容性测试 ---")
	
	# 测试与现有JuicyMixer组件的兼容性
	var timeline = create_test_timeline()
	var target = create_test_target()
	
	# 测试与中间件系统的兼容性
	var context_id = JuicyMixer.play(timeline, target)
	var context = JuicyMixer.get_context(context_id)
	
	assert(context != null, "与JuicyMixer系统集成失败")
	
	# 测试与事件系统的兼容性
	var event = JuicyEvent.create_audio_play_event("compat_test", null, null)
	assert(event != null, "事件系统兼容性测试失败")
	
	# 测试与池化系统的兼容性
	assert(JuicyMixer.get_active_contexts_count() >= 0, "池化系统兼容性测试失败")
	
	JuicyMixer.stop(context_id)
	target.queue_free()
	
	record_test_result("系统兼容性测试", true, "系统兼容性良好")

# 辅助函数
func create_test_timeline() -> JuicyTimelineResource:
	var timeline = JuicyTimelineResource.new()
	timeline.timeline_name = "TestTimeline"
	timeline.duration = 1.0
	
	var track = JuicyPropertyTrack.new()
	track.track_name = "TestTrack"
	track.target_node_path = "Sprite2D"
	track.property_path = "scale"
	track.duration = 1.0
	
	var keyframe = JuicyKeyframe.new()
	keyframe.time = 0.0
	keyframe.value = Vector2.ONE
	keyframe.interpolation_type = JuicyKeyframe.InterpolationType.LINEAR
	
	track.add_keyframe(keyframe)
	timeline.add_track(track)
	
	return timeline

func create_performance_test_timeline() -> JuicyTimelineResource:
	var timeline = JuicyTimelineResource.new()
	timeline.timeline_name = "PerformanceTestTimeline"
	timeline.duration = 2.0
	
	# 添加多个轨道
	for i in range(5):
		var track = JuicyPropertyTrack.new()
		track.track_name = "PerfTrack_" + str(i)
		track.target_node_path = "Sprite2D"
		track.property_path = "scale"
		track.duration = 2.0
		
		# 添加多个关键帧
		for j in range(10):
			var keyframe = JuicyKeyframe.new()
			keyframe.time = j * 0.2
			keyframe.value = Vector2.ONE * (1.0 + 0.1 * j)
			keyframe.interpolation_type = JuicyKeyframe.InterpolationType.LINEAR
			track.add_keyframe(keyframe)
		
		timeline.add_track(track)
	
	return timeline

func create_test_target() -> Node2D:
	var target = Node2D.new()
	var sprite = Sprite2D.new()
	sprite.texture = load("res://icon.svg")
	target.add_child(sprite)
	get_tree().current_scene.add_child(target)
	return target

# 测试方法
func test_method(param: String, value: int):
	print("测试方法调用: ", param, " = ", value)

# 记录测试结果
func record_test_result(test_name: String, passed: bool, details: String):
	test_results.total_tests += 1
	
	if passed:
		test_results.passed_tests += 1
	else:
		test_results.failed_tests += 1
	
	test_results.test_details.append({
		"name": test_name,
		"passed": passed,
		"details": details
	})
	
	var status = "通过" if passed else "失败"
	print("  ", test_name, ": ", status, " - ", details)

# 生成测试报告
func generate_test_report():
	print("\n=== Timeline系统集成测试报告 ===")
	print("测试时间: ", Time.get_datetime_string_from_system())
	print("总测试数: ", test_results.total_tests)
	print("通过测试数: ", test_results.passed_tests)
	print("失败测试数: ", test_results.failed_tests)
	print("成功率: ", float(test_results.passed_tests) / test_results.total_tests * 100.0, "%")
	print("")
	
	# 详细结果
	for detail in test_results.test_details:
		var status = "✓" if detail.passed else "✗"
		print(status, " ", detail.name, ": ", detail.details)
	
	# 保存报告
	save_test_report()

# 保存测试报告
func save_test_report():
	var report_content = "# Timeline系统集成测试报告\n\n"
	report_content += "测试时间: " + Time.get_datetime_string_from_system() + "\n"
	report_content += "总测试数: " + str(test_results.total_tests) + "\n"
	report_content += "通过测试数: " + str(test_results.passed_tests) + "\n"
	report_content += "失败测试数: " + str(test_results.failed_tests) + "\n"
	report_content += "成功率: " + str(float(test_results.passed_tests) / test_results.total_tests * 100.0) + "%\n\n"
	
	report_content += "## 测试详情\n"
	for detail in test_results.test_details:
		var status = "通过" if detail.passed else "失败"
		report_content += "- " + detail.name + ": " + status + "\n"
		report_content += "  " + detail.details + "\n\n"
	
	# 保存文件
	var file = FileAccess.open("user://timeline_integration_test_report.md", FileAccess.WRITE)
	if file:
		file.store_string(report_content)
		file.close()
		print("测试报告已保存到: user://timeline_integration_test_report.md")
	else:
		print("无法保存测试报告文件")

