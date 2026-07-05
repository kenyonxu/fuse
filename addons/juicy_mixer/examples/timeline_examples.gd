# JuicyMixer V3 Timeline系统使用示例

extends Node

# 基础Timeline示例
func _ready():
	print("Timeline示例初始化")
	
	# 运行各种示例
	example_basic_property_timeline()
	example_feedback_timeline()
	example_method_timeline()
	example_event_timeline()
	example_complex_timeline()
	example_parameter_mapping()
	example_conditional_timeline()
	example_performance_optimization()

# 基础属性轨道示例
func example_basic_property_timeline():
	print("\n=== 基础属性轨道示例 ===")
	
	# 创建Timeline
	var timeline = JuicyTimelineResource.new()
	timeline.timeline_name = "BasicPropertyAnimation"
	timeline.duration = 2.0
	
	# 创建属性轨道 - 缩放动画
	var scale_track = JuicyPropertyTrack.new()
	scale_track.track_name = "ScaleAnimation"
	scale_track.target_node_path = "Sprite2D"
	scale_track.property_path = "scale"
	scale_track.duration = 2.0
	
	# 添加关键帧
	var start_scale = JuicyKeyframe.new()
	start_scale.time = 0.0
	start_scale.value = Vector2.ONE
	start_scale.interpolation_type = JuicyKeyframe.InterpolationType.LINEAR
	
	var mid_scale = JuicyKeyframe.new()
	mid_scale.time = 1.0
	mid_scale.value = Vector2(1.5, 1.5)
	mid_scale.interpolation_type = JuicyKeyframe.InterpolationType.EASE_IN_OUT
	
	var end_scale = JuicyKeyframe.new()
	end_scale.time = 2.0
	end_scale.value = Vector2.ONE
	end_scale.interpolation_type = JuicyKeyframe.InterpolationType.EASE_IN_OUT
	
	scale_track.add_keyframe(start_scale)
	scale_track.add_keyframe(mid_scale)
	scale_track.add_keyframe(end_scale)
	
	# 创建属性轨道 - 透明度动画
	var opacity_track = JuicyPropertyTrack.new()
	opacity_track.track_name = "OpacityAnimation"
	opacity_track.target_node_path = "Sprite2D"
	opacity_track.property_path = "modulate:a"
	opacity_track.duration = 2.0
	
	var fade_in = JuicyKeyframe.new()
	fade_in.time = 0.0
	fade_in.value = 0.5
	fade_in.interpolation_type = JuicyKeyframe.InterpolationType.LINEAR
	
	var fade_out = JuicyKeyframe.new()
	fade_out.time = 2.0
	fade_out.value = 1.0
	fade_out.interpolation_type = JuicyKeyframe.InterpolationType.LINEAR
	
	opacity_track.add_keyframe(fade_in)
	opacity_track.add_keyframe(fade_out)
	
	# 添加轨道到Timeline
	timeline.add_track(scale_track)
	timeline.add_track(opacity_track)
	
	# 播放Timeline
	var target_node = get_node_or_null("Sprite2D")
	if target_node:
		var context_id = JuicyMixer.play(timeline, target_node)
		print("基础属性Timeline已播放，上下文ID: ", context_id)
	else:
		print("警告：找不到Sprite2D节点")

# 反馈轨道示例
func example_feedback_timeline():
	print("\n=== 反馈轨道示例 ===")
	
	# 创建Timeline
	var timeline = JuicyTimelineResource.new()
	timeline.timeline_name = "FeedbackEffects"
	timeline.duration = 1.5
	
	# 创建屏幕震动反馈轨道
	var shake_track = JuicyFeedbackTrack.new()
	shake_track.track_name = "ScreenShake"
	shake_track.duration = 0.5
	
	# 创建震动资源（假设已存在）
	var shake_resource = create_test_shake_resource()
	shake_track.resource = shake_resource
	
	# 添加触发关键帧
	var shake_trigger = JuicyKeyframe.new()
	shake_trigger.time = 0.1
	shake_trigger.value = true
	shake_trigger.interpolation_type = JuicyKeyframe.InterpolationType.STEP
	
	shake_track.add_keyframe(shake_trigger)
	
	# 创建粒子效果反馈轨道
	var particle_track = JuicyFeedbackTrack.new()
	particle_track.track_name = "ParticleEffect"
	particle_track.duration = 1.0
	
	var particle_resource = create_test_particle_resource()
	particle_track.resource = particle_resource
	
	var particle_trigger = JuicyKeyframe.new()
	particle_trigger.time = 0.0
	particle_trigger.value = true
	particle_trigger.interpolation_type = JuicyKeyframe.InterpolationType.STEP
	
	particle_track.add_keyframe(particle_trigger)
	
	# 添加轨道到Timeline
	timeline.add_track(shake_track)
	timeline.add_track(particle_track)
	
	# 播放Timeline
	var target_node = get_tree().current_scene
	var context_id = JuicyMixer.play(timeline, target_node)
	print("反馈Timeline已播放，上下文ID: ", context_id)

# 方法轨道示例
func example_method_timeline():
	print("\n=== 方法轨道示例 ===")
	
	# 创建Timeline
	var timeline = JuicyTimelineResource.new()
	timeline.timeline_name = "MethodCalls"
	timeline.duration = 2.0
	
	# 创建音效播放轨道
	var sound_track = JuicyMethodTrack.new()
	sound_track.track_name = "SoundEffects"
	sound_track.target_node_path = "AudioStreamPlayer2D"
	sound_track.method_name = "play"
	sound_track.duration = 2.0
	
	# 添加多个音效触发
	var hit_sound = JuicyKeyframe.new()
	hit_sound.time = 0.0
	hit_sound.value = ["hit_sound.wav", 1.0]
	hit_sound.interpolation_type = JuicyKeyframe.InterpolationType.STEP
	
	var impact_sound = JuicyKeyframe.new()
	impact_sound.time = 0.5
	impact_sound.value = ["impact_sound.wav", 0.8]
	impact_sound.interpolation_type = JuicyKeyframe.InterpolationType.STEP
	
	var finish_sound = JuicyKeyframe.new()
	finish_sound.time = 1.8
	finish_sound.value = ["finish_sound.wav", 1.0]
	finish_sound.interpolation_type = JuicyKeyframe.InterpolationType.STEP
	
	sound_track.add_keyframe(hit_sound)
	sound_track.add_keyframe(impact_sound)
	sound_track.add_keyframe(finish_sound)
	
	# 创建自定义方法调用轨道
	var custom_track = JuicyMethodTrack.new()
	custom_track.track_name = "CustomCalls"
	custom_track.target_node_path = "."
	custom_track.method_name = "on_timeline_event"
	custom_track.duration = 2.0
	
	var event_start = JuicyKeyframe.new()
	event_start.time = 0.0
	event_start.value = ["animation_started", 0]
	event_start.interpolation_type = JuicyKeyframe.InterpolationType.STEP
	
	var event_mid = JuicyKeyframe.new()
	event_mid.time = 1.0
	event_mid.value = ["animation_midpoint", 1]
	event_mid.interpolation_type = JuicyKeyframe.InterpolationType.STEP
	
	var event_end = JuicyKeyframe.new()
	event_end.time = 2.0
	event_end.value = ["animation_completed", 2]
	event_end.interpolation_type = JuicyKeyframe.InterpolationType.STEP
	
	custom_track.add_keyframe(event_start)
	custom_track.add_keyframe(event_mid)
	custom_track.add_keyframe(event_end)
	
	# 添加轨道到Timeline
	timeline.add_track(sound_track)
	timeline.add_track(custom_track)
	
	# 播放Timeline
	var target_node = self
	var context_id = JuicyMixer.play(timeline, target_node)
	print("方法Timeline已播放，上下文ID: ", context_id)

# 事件轨道示例
func example_event_timeline():
	print("\n=== 事件轨道示例 ===")
	
	# 创建Timeline
	var timeline = JuicyTimelineResource.new()
	timeline.timeline_name = "EventEffects"
	timeline.duration = 3.0
	
	# 创建音频事件轨道
	var audio_event_track = JuicyEventTrack.new()
	audio_event_track.track_name = "AudioEvents"
	audio_event_track.duration = 3.0
	
	var audio_event = create_test_audio_event()
	audio_event_track.juicy_event = audio_event
	
	# 添加音频事件关键帧
	var audio_trigger = JuicyKeyframe.new()
	audio_trigger.time = 0.5
	audio_trigger.value = {"volume": 0.8, "pitch": 1.0}
	audio_trigger.interpolation_type = JuicyKeyframe.InterpolationType.STEP
	
	audio_event_track.add_keyframe(audio_trigger)
	
	# 创建粒子事件轨道
	var particle_event_track = JuicyEventTrack.new()
	particle_event_track.track_name = "ParticleEvents"
	particle_event_track.duration = 3.0
	
	var particle_event = create_test_particle_event()
	particle_event_track.juicy_event = particle_event
	
	var particle_trigger = JuicyKeyframe.new()
	particle_trigger.time = 0.0
	particle_trigger.value = {"count": 20, "spread": 45.0, "color": Color.RED}
	particle_trigger.interpolation_type = JuicyKeyframe.InterpolationType.STEP
	
	particle_event_track.add_keyframe(particle_trigger)
	
	# 添加轨道到Timeline
	timeline.add_track(audio_event_track)
	timeline.add_track(particle_event_track)
	
	# 播放Timeline
	var target_node = get_tree().current_scene
	var context_id = JuicyMixer.play(timeline, target_node)
	print("事件Timeline已播放，上下文ID: ", context_id)

# 复杂Timeline示例
func example_complex_timeline():
	print("\n=== 复杂Timeline示例 ===")
	
	# 创建主Timeline
	var timeline = JuicyTimelineResource.new()
	timeline.timeline_name = "ComplexBattleReaction"
	timeline.duration = 2.5
	
	# 1. 视觉效果组
	var visual_group = {
		"name": "VisualEffects",
		"tracks": [],
		"enabled": true
	}
	
	# 屏幕闪烁轨道
	var flash_track = JuicyPropertyTrack.new()
	flash_track.track_name = "ScreenFlash"
	flash_track.target_node_path = "CanvasModulate"
	flash_track.property_path = "color"
	flash_track.duration = 0.3
	
	var flash_in = JuicyKeyframe.new()
	flash_in.time = 0.0
	flash_in.value = Color.WHITE
	flash_in.interpolation_type = JuicyKeyframe.InterpolationType.STEP
	
	var flash_out = JuicyKeyframe.new()
	flash_out.time = 0.3
	flash_out.value = Color.WHITE
	flash_out.interpolation_type = JuicyKeyframe.InterpolationType.LINEAR
	
	flash_track.add_keyframe(flash_in)
	flash_track.add_keyframe(flash_out)
	visual_group.tracks.append(flash_track)
	
	# 角色受击动画轨道
	var hit_anim_track = JuicyPropertyTrack.new()
	hit_anim_track.track_name = "CharacterHitAnimation"
	hit_anim_track.target_node_path = "Character"
	hit_anim_track.property_path = "position"
	hit_anim_track.duration = 0.8
	
	var hit_start = JuicyKeyframe.new()
	hit_start.time = 0.0
	hit_start.value = Vector2.ZERO
	hit_start.interpolation_type = JuicyKeyframe.InterpolationType.LINEAR
	
	var hit_back = JuicyKeyframe.new()
	hit_back.time = 0.2
	hit_back.value = Vector2(-20, 0)
	hit_back.interpolation_type = JuicyKeyframe.InterpolationType.EASE_OUT
	
	var hit_return = JuicyKeyframe.new()
	hit_return.time = 0.8
	hit_return.value = Vector2.ZERO
	hit_return.interpolation_type = JuicyKeyframe.InterpolationType.EASE_IN_OUT
	
	hit_anim_track.add_keyframe(hit_start)
	hit_anim_track.add_keyframe(hit_back)
	hit_anim_track.add_keyframe(hit_return)
	visual_group.tracks.append(hit_anim_track)
	
	# 2. 音频效果组
	var audio_group = {
		"name": "AudioEffects",
		"tracks": [],
		"enabled": true
	}
	
	# 受击音效轨道
	var hit_sound_track = JuicyMethodTrack.new()
	hit_sound_track.track_name = "HitSound"
	hit_sound_track.target_node_path = "AudioStreamPlayer2D"
	hit_sound_track.method_name = "play"
	hit_sound_track.duration = 0.1
	
	var hit_sound = JuicyKeyframe.new()
	hit_sound.time = 0.0
	hit_sound.value = ["hit_sound.wav", 1.0]
	hit_sound.interpolation_type = JuicyKeyframe.InterpolationType.STEP
	
	hit_sound_track.add_keyframe(hit_sound)
	audio_group.tracks.append(hit_sound_track)
	
	# 3. 粒子效果组
	var particle_group = {
		"name": "ParticleEffects",
		"tracks": [],
		"enabled": true
	}
	
	# 血液粒子轨道
	var blood_particle_track = JuicyEventTrack.new()
	blood_particle_track.track_name = "BloodParticles"
	blood_particle_track.duration = 1.0
	
	var blood_event = create_test_particle_event()
	blood_particle_track.juicy_event = blood_event
	
	var blood_trigger = JuicyKeyframe.new()
	blood_trigger.time = 0.1
	blood_trigger.value = {"count": 15, "color": Color.RED, "direction": Vector2.UP}
	blood_trigger.interpolation_type = JuicyKeyframe.InterpolationType.STEP
	
	blood_particle_track.add_keyframe(blood_trigger)
	particle_group.tracks.append(blood_particle_track)
	
	# 添加所有轨道到Timeline
	for track in visual_group.tracks:
		timeline.add_track(track)
	
	for track in audio_group.tracks:
		timeline.add_track(track)
	
	for track in particle_group.tracks:
		timeline.add_track(track)
	
	# 设置轨道分组
	timeline.track_groups = [visual_group, audio_group, particle_group]
	
	# 播放Timeline
	var target_node = get_tree().current_scene
	var context_id = JuicyMixer.play(timeline, target_node)
	print("复杂Timeline已播放，上下文ID: ", context_id)

# 参数映射示例
func example_parameter_mapping():
	print("\n=== 参数映射示例 ===")
	
	# 创建Timeline
	var timeline = JuicyTimelineResource.new()
	timeline.timeline_name = "ParameterMappedEffects"
	timeline.duration = 2.0
	
	# 创建属性轨道 - 使用参数映射控制强度
	var intensity_track = JuicyPropertyTrack.new()
	intensity_track.track_name = "IntensityEffect"
	intensity_track.target_node_path = "Sprite2D"
	intensity_track.property_path = "scale"
	intensity_track.duration = 2.0
	intensity_track.use_parameter_mapping = true
	
	# 创建参数映射
	var intensity_mapping = JuicyParameterMapping.new()
	intensity_mapping.input_parameter = "player_health"
	intensity_mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_VALUE
	intensity_mapping.target_property = "intensity"
	intensity_mapping.input_range = Vector2(0, 100)
	intensity_mapping.output_range = Vector2(0.5, 2.0)
	
	# 创建映射曲线
	var health_curve = Curve.new()
	health_curve.add_point(Vector2(0, 2.0))  # 低生命值时效果更强
	health_curve.add_point(Vector2(50, 1.0))  # 中等生命值时正常
	health_curve.add_point(Vector2(100, 0.5))  # 高生命值时效果较弱
	intensity_mapping.curve = health_curve
	
	intensity_track.parameter_mappings = [intensity_mapping]
	
	# 添加基础关键帧
	var start_frame = JuicyKeyframe.new()
	start_frame.time = 0.0
	start_frame.value = Vector2.ONE
	start_frame.interpolation_type = JuicyKeyframe.InterpolationType.LINEAR
	
	var end_frame = JuicyKeyframe.new()
	end_frame.time = 2.0
	end_frame.value = Vector2.ONE
	end_frame.interpolation_type = JuicyKeyframe.InterpolationType.LINEAR
	
	intensity_track.add_keyframe(start_frame)
	intensity_track.add_keyframe(end_frame)
	
	# 创建反馈轨道 - 使用参数映射控制震动强度
	var shake_track = JuicyFeedbackTrack.new()
	shake_track.track_name = "MappedScreenShake"
	shake_track.duration = 0.5
	shake_track.use_parameter_mapping = true
	
	var shake_resource = create_test_shake_resource()
	shake_track.resource = shake_resource
	
	# 创建震动强度映射
	var shake_mapping = JuicyParameterMapping.new()
	shake_mapping.input_parameter = "damage_amount"
	shake_mapping.mapping_type = JuicyParameterMapping.MappingType.TRACK_PROPERTY
	shake_mapping.target_property = "intensity"
	shake_mapping.input_range = Vector2(0, 50)
	shake_mapping.output_range = Vector2(0.0, 1.0)
	
	shake_track.parameter_mappings = [shake_mapping]
	
	var shake_trigger = JuicyKeyframe.new()
	shake_trigger.time = 0.2
	shake_trigger.value = true
	shake_trigger.interpolation_type = JuicyKeyframe.InterpolationType.STEP
	
	shake_track.add_keyframe(shake_trigger)
	
	# 添加轨道到Timeline
	timeline.add_track(intensity_track)
	timeline.add_track(shake_track)
	
	# 播放Timeline并设置参数
	var target_node = get_tree().current_scene
	var context_id = JuicyMixer.play(timeline, target_node)
	
	# 获取上下文并设置参数
	var context = JuicyMixer.get_context(context_id)
	if context:
		context.set_parameter("player_health", 30.0)  # 30%生命值
		context.set_parameter("damage_amount", 25.0)  # 25点伤害
	
	print("参数映射Timeline已播放，上下文ID: ", context_id)

# 条件Timeline示例
func example_conditional_timeline():
	print("\n=== 条件Timeline示例 ===")
	
	# 创建Timeline
	var timeline = JuicyTimelineResource.new()
	timeline.timeline_name = "ConditionalEffects"
	timeline.duration = 2.0
	
	# 创建条件轨道 - 只在低生命值时播放
	var low_health_track = JuicyPropertyTrack.new()
	low_health_track.track_name = "LowHealthEffect"
	low_health_track.target_node_path = "Sprite2D"
	low_health_track.property_path = "modulate"
	low_health_track.duration = 1.5
	
	# 创建生命值条件
	var health_condition = JuicyParameterCondition.new()
	health_condition.parameter_name = "player_health"
	health_condition.operator = JuicyParameterCondition.ComparisonOperator.LESS_THAN
	health_condition.target_value = 0.3
	
	low_health_track.activation_condition = health_condition
	
	# 添加红色闪烁关键帧
	var red_flash = JuicyKeyframe.new()
	red_flash.time = 0.0
	red_flash.value = Color.RED
	red_flash.interpolation_type = JuicyKeyframe.InterpolationType.STEP
	
	var normal_color = JuicyKeyframe.new()
	normal_color.time = 1.5
	normal_color.value = Color.WHITE
	normal_color.interpolation_type = JuicyKeyframe.InterpolationType.LINEAR
	
	low_health_track.add_keyframe(red_flash)
	low_health_track.add_keyframe(normal_color)
	
	# 创建无条件轨道 - 始终播放
	var normal_track = JuicyPropertyTrack.new()
	normal_track.track_name = "NormalEffect"
	normal_track.target_node_path = "Sprite2D"
	normal_track.property_path = "scale"
	normal_track.duration = 2.0
	
	var scale_up = JuicyKeyframe.new()
	scale_up.time = 0.0
	scale_up.value = Vector2.ONE
	scale_up.interpolation_type = JuicyKeyframe.InterpolationType.LINEAR
	
	var scale_down = JuicyKeyframe.new()
	scale_down.time = 1.0
	scale_down.value = Vector2(1.2, 1.2)
	scale_down.interpolation_type = JuicyKeyframe.InterpolationType.EASE_IN_OUT
	
	var scale_return = JuicyKeyframe.new()
	scale_return.time = 2.0
	scale_return.value = Vector2.ONE
	scale_return.interpolation_type = JuicyKeyframe.InterpolationType.EASE_IN_OUT
	
	normal_track.add_keyframe(scale_up)
	normal_track.add_keyframe(scale_down)
	normal_track.add_keyframe(scale_return)
	
	# 添加轨道到Timeline
	timeline.add_track(low_health_track)
	timeline.add_track(normal_track)
	
	# 测试不同条件
	print("测试高生命值（条件轨道不应激活）:")
	test_conditional_timeline(timeline, 0.8)
	
	await get_tree().create_timer(3.0).timeout
	
	print("测试低生命值（条件轨道应激活）:")
	test_conditional_timeline(timeline, 0.2)

func test_conditional_timeline(timeline: JuicyTimelineResource, health_percentage: float):
	var target_node = get_tree().current_scene
	var context_id = JuicyMixer.play(timeline, target_node)
	
	var context = JuicyMixer.get_context(context_id)
	if context:
		context.set_parameter("player_health", health_percentage)
		print("设置生命值为: ", health_percentage * 100, "%")

# 性能优化示例
func example_performance_optimization():
	print("\n=== 性能优化示例 ===")
	
	# 创建优化的Timeline
	var timeline = JuicyTimelineResource.new()
	timeline.timeline_name = "OptimizedTimeline"
	timeline.duration = 1.0
	
	# 使用线性插值（最快）
	var fast_track = JuicyPropertyTrack.new()
	fast_track.track_name = "FastTrack"
	fast_track.target_node_path = "Sprite2D"
	fast_track.property_path = "position:x"
	fast_track.duration = 1.0
	
	var start_pos = JuicyKeyframe.new()
	start_pos.time = 0.0
	start_pos.value = 0.0
	start_pos.interpolation_type = JuicyKeyframe.InterpolationType.LINEAR  # 最快的插值类型
	
	var end_pos = JuicyKeyframe.new()
	end_pos.time = 1.0
	end_pos.value = 100.0
	end_pos.interpolation_type = JuicyKeyframe.InterpolationType.LINEAR
	
	fast_track.add_keyframe(start_pos)
	fast_track.add_keyframe(end_pos)
	
	# 启用缓存
	timeline.set_meta("enable_caching", true)
	
	# 添加轨道到Timeline
	timeline.add_track(fast_track)
	
	# 性能测试
	print("开始性能测试...")
	var start_time = Time.get_ticks_msec()
	
	# 创建多个实例
	var context_ids = []
	for i in range(10):
		var target_node = create_test_sprite(i * 20)
		var context_id = JuicyMixer.play(timeline, target_node)
		context_ids.append(context_id)
	
	# 等待播放完成
	await get_tree().create_timer(1.5).timeout
	
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	print("10个优化Timeline实例创建和播放时间: ", duration, "ms")
	
	# 清理
	for context_id in context_ids:
		JuicyMixer.stop(context_id)

# 自定义事件处理
func on_timeline_event(event_name: String, data: Variant):
	print("Timeline事件: ", event_name, " 数据: ", data)

# 辅助函数
func create_test_shake_resource() -> JuicyShakeResource:
	# 创建测试震动资源
	var shake = JuicyShakeResource.new()
	shake.resource_name = "TestShake"
	shake.add_shake_data("offset", 10.0, 10.0, 0.5)
	return shake

func create_test_particle_resource() -> JuicyAnimationPlayResource:
	# 创建测试粒子资源
	var particle = JuicyAnimationPlayResource.new()
	particle.resource_name = "TestParticle"
	particle.add_animation_data("Sprite2D", "default")
	return particle

func create_test_audio_event() -> JuicyEvent:
	# 创建测试音频事件
	var event = JuicyEvent.create_audio_play_event("test_audio", null, null)
	return event

func create_test_particle_event() -> JuicyEvent:
	# 创建测试粒子事件
	var event = JuicyEvent.new()
	event.event_type = JuicyEvent.EventType.PARTICLE_SPAWN
	return event

func create_test_sprite(x_offset: float) -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite.texture = load("res://icon.svg")
	sprite.position = Vector2(x_offset, 0)
	get_tree().current_scene.add_child(sprite)
	return sprite