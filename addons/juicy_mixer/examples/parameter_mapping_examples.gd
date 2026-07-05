# 参数映射系统示例
# 演示如何在Timeline系统中使用各种类型的参数映射

extends Node

# 示例1：根据玩家生命值调整视觉效果
func create_health_based_visual_timeline() -> JuicyTimelineResource:
	"""
	创建一个根据玩家生命值动态调整视觉效果的Timeline
	
	@return: 配置好的Timeline资源
	"""
	var timeline = JuicyTimelineResource.new()
	timeline.resource_name = "HealthBasedVisual"
	timeline.timeline_duration = 2.0
	
	# 属性轨道：屏幕颜色效果
	var color_track = JuicyPropertyTrack.new()
	color_track.track_name = "ScreenColorEffect"
	color_track.property_path = "modulate"
	# 注意：value_range应该使用Vector2(float, float)表示最小值和最大值
	# 对于颜色映射，我们使用强度来控制颜色插值
	color_track.value_range = Vector2(0.0, 1.0)
	color_track.use_parameter_mapping = true
	
	# 创建生命值到颜色的映射
	var health_mapping = JuicyParameterMapping.new()
	health_mapping.input_parameter = "player_health"
	health_mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_VALUE
	health_mapping.target_property = "intensity"
	health_mapping.input_range = Vector2(0.0, 100.0)  # 生命值范围
	health_mapping.output_range = Vector2(0.0, 1.0)   # 映射到0-1
	health_mapping.invert_mapping = true  # 生命值越低，效果越强
	
	# 创建S型曲线，使低生命值时效果更明显
	var health_curve = Curve.new()
	health_curve.add_point(Vector2(0, 1))
	health_curve.add_point(Vector2(0.3, 0.8))
	health_curve.add_point(Vector2(0.7, 0.2))
	health_curve.add_point(Vector2(1, 0))
	health_mapping.curve = health_curve
	
	color_track.parameter_mappings = [health_mapping]
	timeline.add_track(color_track)
	
	return timeline

# 示例2：根据移动速度调整震动和音效
func create_speed_based_feedback_timeline() -> JuicyTimelineResource:
	"""
	创建一个根据玩家移动速度调整震动和音效的Timeline
	
	@return: 配置好的Timeline资源
	"""
	var timeline = JuicyTimelineResource.new()
	timeline.resource_name = "SpeedBasedFeedback"
	timeline.timeline_duration = 1.0
	
	# 反馈轨道：震动效果
	var shake_track = JuicyFeedbackTrack.new()
	shake_track.track_name = "CameraShake"
	# 注意：这里使用注释，实际使用时需要替换为真实的资源路径
	# shake_track.resource = preload("res://effects/camera_shake.tres")
	print("注意：请设置实际的震动资源路径")
	shake_track.use_parameter_mapping = true
	
	# 速度到震动强度的映射
	var speed_shake_mapping = JuicyParameterMapping.new()
	speed_shake_mapping.input_parameter = "player_speed"
	speed_shake_mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_PROPERTY
	speed_shake_mapping.target_property = "intensity"
	speed_shake_mapping.input_range = Vector2(0.0, 20.0)  # 速度范围
	speed_shake_mapping.output_range = Vector2(0.0, 1.0)  # 强度范围
	
	# 创建指数曲线，使高速时震动更明显
	var speed_curve = Curve.new()
	speed_curve.add_point(Vector2(0, 0))
	speed_curve.add_point(Vector2(0.5, 0.3))
	speed_curve.add_point(Vector2(0.8, 0.7))
	speed_curve.add_point(Vector2(1, 1))
	speed_shake_mapping.curve = speed_curve
	
	shake_track.parameter_mappings = [speed_shake_mapping]
	timeline.add_track(shake_track)
	
	# 事件轨道：脚步声
	var footstep_track = JuicyEventTrack.new()
	footstep_track.track_name = "FootstepSounds"
	# 注意：这里使用注释，实际使用时需要替换为真实的资源路径
	# footstep_track.juicy_event = preload("res://events/footstep_sound.tres")
	print("注意：请设置实际的事件资源路径")
	footstep_track.use_parameter_mapping = true
	
	# 速度到音高的映射
	var pitch_mapping = JuicyParameterMapping.new()
	pitch_mapping.input_parameter = "player_speed"
	pitch_mapping.mapping_type = JuicyParameterMapping.MappingType.EVENT_PROPERTY
	pitch_mapping.target_property = "pitch"
	pitch_mapping.input_range = Vector2(0.0, 20.0)  # 速度范围
	pitch_mapping.output_range = Vector2(0.8, 1.3)  # 音高范围
	
	footstep_track.parameter_mappings = [pitch_mapping]
	timeline.add_track(footstep_track)
	
	return timeline

# 示例3：连击系统的多轨道参数映射
func create_combo_system_timeline() -> JuicyTimelineResource:
	"""
	创建一个连击系统的Timeline，包含多个轨道和复杂的参数映射
	
	@return: 配置好的Timeline资源
	"""
	var timeline = JuicyTimelineResource.new()
	timeline.resource_name = "ComboSystem"
	timeline.timeline_duration = 3.0
	
	# 属性轨道：连击数越大，屏幕效果越强
	var combo_track = JuicyPropertyTrack.new()
	combo_track.track_name = "ComboEffect"
	combo_track.property_path = "scale"
	# 注意：value_range应该使用Vector2(float, float)表示缩放范围
	combo_track.value_range = Vector2(1.0, 1.2)
	combo_track.use_parameter_mapping = true
	
	var combo_mapping = JuicyParameterMapping.new()
	combo_mapping.input_parameter = "combo_count"
	combo_mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_VALUE
	combo_mapping.target_property = "intensity"
	combo_mapping.input_range = Vector2(0, 50)  # 连击数范围
	combo_mapping.output_range = Vector2(0.0, 1.0)  # 效果强度
	
	combo_track.parameter_mappings = [combo_mapping]
	timeline.add_track(combo_track)
	
	# 方法轨道：连击达到阈值时触发特殊效果
	var special_track = JuicyMethodTrack.new()
	special_track.track_name = "SpecialEffect"
	special_track.method_name = "trigger_special_effect"
	special_track.args = ["$special_effect", 1.0]
	special_track.use_parameter_mapping = true
	
	var special_mapping = JuicyParameterMapping.new()
	special_mapping.input_parameter = "combo_count"
	special_mapping.mapping_type = JuicyParameterMapping.MappingType.METHOD_ARGUMENT
	special_mapping.target_argument_index = 1  # 第二个参数（强度）
	special_mapping.input_range = Vector2(0, 50)
	special_mapping.output_range = Vector2(0.0, 2.0)
	
	special_track.parameter_mappings = [special_mapping]
	timeline.add_track(special_track)
	
	# 反馈轨道：连击音效
	var sound_track = JuicyFeedbackTrack.new()
	sound_track.track_name = "ComboSound"
	# 注意：这里使用注释，实际使用时需要替换为真实的资源路径
	# sound_track.resource = preload("res://effects/combo_sound.tres")
	print("注意：请设置实际的音效资源路径")
	sound_track.use_parameter_mapping = true
	
	var sound_mapping = JuicyParameterMapping.new()
	sound_mapping.input_parameter = "combo_count"
	sound_mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_PROPERTY
	sound_mapping.target_property = "volume"
	sound_mapping.input_range = Vector2(0, 50)
	sound_mapping.output_range = Vector2(0.5, 1.5)
	
	sound_track.parameter_mappings = [sound_mapping]
	timeline.add_track(sound_track)
	
	return timeline

# 示例4：自定义参数映射处理
func create_custom_mapping_timeline() -> JuicyTimelineResource:
	"""
	创建一个使用自定义参数映射的Timeline
	
	@return: 配置好的Timeline资源
	"""
	var timeline = JuicyTimelineResource.new()
	timeline.resource_name = "CustomMapping"
	timeline.timeline_duration = 2.0
	
	# 属性轨道：使用自定义映射
	var custom_track = JuicyPropertyTrack.new()
	custom_track.track_name = "CustomEffect"
	custom_track.property_path = "rotation:y"
	custom_track.value_range = Vector2(0, 360)
	custom_track.use_parameter_mapping = true
	
	var custom_mapping = JuicyParameterMapping.new()
	custom_mapping.input_parameter = "input_angle"
	custom_mapping.mapping_type = JuicyParameterMapping.MappingType.CUSTOM
	custom_mapping.custom_handler = "handle_angle_mapping"
	custom_mapping.input_range = Vector2(-180, 180)
	custom_mapping.output_range = Vector2(0, 360)
	
	custom_track.parameter_mappings = [custom_mapping]
	timeline.add_track(custom_track)
	
	return timeline

# 自定义映射处理函数
func handle_angle_mapping(input_value: float, mapping: JuicyParameterMapping) -> float:
	"""
	自定义角度映射处理函数
	
	@param input_value: 输入角度值
	@param mapping: 参数映射实例
	@return: 处理后的角度值
	"""
	# 将-180到180的角度映射到0到360
	var normalized = (input_value + 180) / 360.0
	
	# 应用曲线映射（如果有）
	if mapping.curve:
		normalized = mapping.curve.sample(clampf(normalized, 0.0, 1.0))
	
	# 转换回角度范围
	return normalized * 360.0

# 示例5：复杂的多参数映射
func create_complex_mapping_timeline() -> JuicyTimelineResource:
	"""
	创建一个使用多个参数映射的复杂Timeline
	
	@return: 配置好的Timeline资源
	"""
	var timeline = JuicyTimelineResource.new()
	timeline.resource_name = "ComplexMapping"
	timeline.timeline_duration = 4.0
	
	# 属性轨道：位置效果
	var position_track = JuicyPropertyTrack.new()
	position_track.track_name = "PositionEffect"
	position_track.property_path = "position"
	position_track.use_parameter_mapping = true
	
	# X轴位置映射
	var x_mapping = JuicyParameterMapping.new()
	x_mapping.input_parameter = "input_x"
	x_mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_VALUE
	x_mapping.target_property = "offset"
	x_mapping.input_range = Vector2(-100, 100)
	x_mapping.output_range = Vector2(-50, 50)
	
	# 时间缩放映射
	var time_mapping = JuicyParameterMapping.new()
	time_mapping.input_parameter = "time_scale_factor"
	time_mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_TIME
	time_mapping.target_property = "time_scale"
	time_mapping.input_range = Vector2(0.1, 3.0)
	time_mapping.output_range = Vector2(0.1, 3.0)
	
	position_track.parameter_mappings = [x_mapping, time_mapping]
	timeline.add_track(position_track)
	
	# 反馈轨道：粒子效果
	var particle_track = JuicyFeedbackTrack.new()
	particle_track.track_name = "ParticleEffect"
	# 注意：这里使用注释，实际使用时需要替换为真实的资源路径
	# particle_track.resource = preload("res://effects/particle_burst.tres")
	print("注意：请设置实际的粒子效果资源路径")
	particle_track.use_parameter_mapping = true
	
	# 粒子强度映射
	var particle_intensity_mapping = JuicyParameterMapping.new()
	particle_intensity_mapping.input_parameter = "intensity_factor"
	particle_intensity_mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_PROPERTY
	particle_intensity_mapping.target_property = "intensity"
	particle_intensity_mapping.input_range = Vector2(0.0, 1.0)
	particle_intensity_mapping.output_range = Vector2(0.0, 2.0)
	
	# 粒子颜色映射
	var particle_color_mapping = JuicyParameterMapping.new()
	particle_color_mapping.input_parameter = "color_factor"
	particle_color_mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_PROPERTY
	particle_color_mapping.target_property = "value_range_min"
	particle_color_mapping.input_range = Vector2(0.0, 1.0)
	particle_color_mapping.output_range = Vector2(0.0, 1.0)
	
	particle_track.parameter_mappings = [particle_intensity_mapping, particle_color_mapping]
	timeline.add_track(particle_track)
	
	return timeline

# 运行示例的函数
func run_examples():
	"""
	运行所有示例，演示参数映射系统的功能
	"""
	print("=== 参数映射系统示例 ===")
	
	# 创建并测试健康值映射
	var health_timeline = create_health_based_visual_timeline()
	print("健康值映射Timeline创建完成: ", health_timeline.get_description())
	
	# 创建并测试速度映射
	var speed_timeline = create_speed_based_feedback_timeline()
	print("速度映射Timeline创建完成: ", speed_timeline.get_description())
	
	# 创建并测试连击系统
	var combo_timeline = create_combo_system_timeline()
	print("连击系统Timeline创建完成: ", combo_timeline.get_description())
	
	# 创建并测试自定义映射
	var custom_timeline = create_custom_mapping_timeline()
	print("自定义映射Timeline创建完成: ", custom_timeline.get_description())
	
	# 创建并测试复杂映射
	var complex_timeline = create_complex_mapping_timeline()
	print("复杂映射Timeline创建完成: ", complex_timeline.get_description())
	
	# 演示参数映射的应用
	demonstrate_parameter_application()

# 演示参数应用
func demonstrate_parameter_application():
	"""
	演示如何在运行时应用参数映射
	"""
	print("\n=== 参数应用演示 ===")
	
	# 创建上下文并设置参数
	var context = JuicyContext.create(null, null, self)
	context.set_parameter("player_health", 30.0)
	context.set_parameter("player_speed", 15.0)
	context.set_parameter("combo_count", 25)
	context.set_parameter("input_angle", 45.0)
	
	# 创建测试映射
	var test_mapping = JuicyParameterMapping.new()
	test_mapping.input_parameter = "player_health"
	test_mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_VALUE
	test_mapping.target_property = "intensity"
	test_mapping.input_range = Vector2(0.0, 100.0)
	test_mapping.output_range = Vector2(0.0, 1.0)
	test_mapping.invert_mapping = true
	
	# 应用映射
	var mapped_value = test_mapping.apply_mapping(30.0)
	print("健康值30映射后的强度: ", mapped_value)
	
	# 测试自定义映射
	var custom_mapping = JuicyParameterMapping.new()
	custom_mapping.input_parameter = "input_angle"
	custom_mapping.mapping_type = JuicyParameterMapping.MappingType.CUSTOM
	custom_mapping.custom_handler = "handle_angle_mapping"
	
	var custom_value = custom_mapping.apply_custom_mapping(45.0, self)
	print("角度45自定义映射后的值: ", custom_value)
	
	print("参数应用演示完成")

# 验证映射配置
func validate_mapping_examples():
	"""
	验证示例中的映射配置
	"""
	print("\n=== 映射验证 ===")
	
	var mappings = [
		create_health_based_visual_timeline().get_all_tracks()[0].parameter_mappings[0],
		create_speed_based_feedback_timeline().get_all_tracks()[0].parameter_mappings[0],
		create_combo_system_timeline().get_all_tracks()[0].parameter_mappings[0]
	]
	
	for i in range(mappings.size()):
		var mapping = mappings[i]
		var error = mapping.validate_mapping()
		if error.is_empty():
			print("映射 ", i + 1, " 验证通过")
		else:
			print("映射 ", i + 1, " 验证失败: ", error)
	
	print("映射验证完成")

# 性能测试
func performance_test():
	"""
	测试参数映射系统的性能
	"""
	print("\n=== 性能测试 ===")
	
	var mapping = JuicyParameterMapping.new()
	mapping.input_parameter = "test_param"
	mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_VALUE
	mapping.target_property = "intensity"
	
	# 创建测试曲线
	var curve = Curve.new()
	for i in range(10):
		curve.add_point(Vector2(i / 9.0, randf()))
	mapping.curve = curve
	
	var iterations = 10000
	var start_time = Time.get_ticks_usec()
	
	for i in range(iterations):
		var input = randf() * 100.0
		mapping.apply_mapping(input)
	
	var end_time = Time.get_ticks_usec()
	var total_time = (end_time - start_time) / 1000.0  # 转换为毫秒
	var avg_time = total_time / iterations
	
	print("性能测试结果:")
	print("  迭代次数: ", iterations)
	print("  总耗时: ", total_time, "ms")
	print("  平均耗时: ", avg_time, "ms")
	print("  每秒可处理: ", 1000.0 / avg_time, "次映射")
	
	print("性能测试完成")

# 完整的示例运行
func _ready():
	"""
	节点准备就绪时运行所有示例
	"""
	run_examples()
	validate_mapping_examples()
	performance_test()
	
	print("\n=== 所有示例运行完成 ===")