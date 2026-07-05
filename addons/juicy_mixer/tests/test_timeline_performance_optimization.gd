# JuicyMixer V3 Timeline系统性能优化验证测试

extends Node

# 性能测试配置
var performance_configs = {
	"lightweight": {
		"track_count": 2,
		"keyframe_count": 10,
		"instance_count": 10,
		"duration": 1.0
	},
	"standard": {
		"track_count": 5,
		"keyframe_count": 25,
		"instance_count": 25,
		"duration": 2.0
	},
	"heavy": {
		"track_count": 10,
		"keyframe_count": 50,
		"instance_count": 50,
		"duration": 3.0
	}
}

# 性能基准
var performance_benchmarks = {
	"creation_time_per_instance": 5.0,  # ms per instance
	"playback_time_per_second": 16.0,  # ms per second of playback
	"memory_per_instance": 50.0,  # KB per instance
	"frame_time_60fps": 16.67,  # ms for 60 FPS
	"frame_time_30fps": 33.33,  # ms for 30 FPS
}

# 测试结果
var optimization_results = {}

func _ready():
	print("开始Timeline性能优化验证测试")
	
	# 运行所有性能测试
	run_all_performance_tests()
	
	# 生成优化报告
	generate_optimization_report()

# 运行所有性能测试
func run_all_performance_tests():
	print("\n=== Timeline性能优化验证测试开始 ===")
	
	# 轻量级测试
	run_performance_test("lightweight")
	
	await get_tree().create_timer(2.0).timeout
	
	# 标准级测试
	run_performance_test("standard")
	
	await get_tree().create_timer(3.0).timeout
	
	# 重负载测试
	run_performance_test("heavy")
	
	await get_tree().create_timer(5.0).timeout
	
	# 缓存效果测试
	test_caching_performance()
	
	await get_tree().create_timer(2.0).timeout
	
	# 插值类型性能测试
	test_interpolation_performance()

# 运行单个性能测试
func run_performance_test(config_name: String):
	print("\n--- ", config_name, " 性能测试 ---")
	
	var config = performance_configs[config_name]
	var timeline = create_performance_timeline(config)
	
	# 预热系统
	warmup_timeline_system()
	
	# 测量创建性能
	var creation_metrics = measure_creation_performance(timeline, config)
	
	# 测量播放性能
	var playback_metrics = await measure_playback_performance(timeline, config, creation_metrics.targets)
	
	# 测量内存使用
	var memory_metrics = await measure_memory_usage(creation_metrics.targets)
	
	# 分析结果
	var analysis = analyze_performance_metrics(config_name, creation_metrics, playback_metrics, memory_metrics)
	
	# 存储结果
	optimization_results[config_name] = {
		"config": config,
		"creation": creation_metrics,
		"playback": playback_metrics,
		"memory": memory_metrics,
		"analysis": analysis
	}
	
	print("  创建时间: ", creation_metrics.total_time, "ms (平均: ", creation_metrics.average_time, "ms/实例)")
	print("  播放时间: ", playback_metrics.total_time, "ms")
	print("  内存使用: ", memory_metrics.peak_memory, "KB (平均: ", memory_metrics.average_memory, "KB/实例)")
	print("  平均帧时间: ", playback_metrics.average_frame_time, "ms")
	print("  性能评级: ", analysis.rating)

# 创建性能测试Timeline
func create_performance_timeline(config: Dictionary) -> JuicyTimelineResource:
	var timeline = JuicyTimelineResource.new()
	timeline.timeline_name = "PerformanceTestTimeline"
	timeline.duration = config.duration
	
	# 创建轨道
	for i in range(config.track_count):
		var track_type = i % 4
		var track: JuicyTrack
		
		match track_type:
			0:
				track = create_performance_property_track(i, config)
			1:
				track = create_performance_feedback_track(i, config)
			2:
				track = create_performance_method_track(i, config)
			3:
				track = create_performance_event_track(i, config)
			_:
				track = create_performance_property_track(i, config)
		
		timeline.add_track(track)
	
	return timeline

# 创建性能测试属性轨道
func create_performance_property_track(track_index: int, config: Dictionary) -> JuicyPropertyTrack:
	var track = JuicyPropertyTrack.new()
	track.track_name = "PerfPropertyTrack_" + str(track_index)
	track.target_node_path = "Sprite2D"
	track.property_path = "scale"
	track.duration = config.duration
	
	# 添加关键帧
	var keyframe_interval = config.duration / config.keyframe_count
	for i in range(config.keyframe_count):
		var keyframe = JuicyKeyframe.new()
		keyframe.time = i * keyframe_interval
		keyframe.value = Vector2.ONE * (1.0 + 0.5 * sin(i * PI * 2.0 / config.keyframe_count))
		keyframe.interpolation_type = JuicyKeyframe.InterpolationType.LINEAR
		track.add_keyframe(keyframe)
	
	return track

# 创建性能测试反馈轨道
func create_performance_feedback_track(track_index: int, config: Dictionary) -> JuicyFeedbackTrack:
	var track = JuicyFeedbackTrack.new()
	track.track_name = "PerfFeedbackTrack_" + str(track_index)
	track.duration = config.duration * 0.5
	
	# 创建震动资源
	var shake_resource = JuicyShakeResource.new()
	shake_resource.resource_name = "PerfShake_" + str(track_index)
	shake_resource.add_shake_data("offset", 10.0 + track_index * 2.0, 15.0 + track_index * 5.0, 0.3)
	
	track.resource = shake_resource
	
	# 添加触发关键帧
	var trigger = JuicyKeyframe.new()
	trigger.time = 0.1
	trigger.value = true
	trigger.interpolation_type = JuicyKeyframe.InterpolationType.STEP
	track.add_keyframe(trigger)
	
	return track

# 创建性能测试方法轨道
func create_performance_method_track(track_index: int, config: Dictionary) -> JuicyMethodTrack:
	var track = JuicyMethodTrack.new()
	track.track_name = "PerfMethodTrack_" + str(track_index)
	track.target_node_path = "."
	track.method_name = "performance_test_method"
	track.duration = config.duration
	
	# 添加方法调用关键帧
	var call_interval = config.duration / max(1, config.keyframe_count / 5)
	for i in range(min(5, config.keyframe_count)):
		var keyframe = JuicyKeyframe.new()
		keyframe.time = i * call_interval
		keyframe.value = [track_index, randf()]
		keyframe.interpolation_type = JuicyKeyframe.InterpolationType.STEP
		track.add_keyframe(keyframe)
	
	return track

# 创建性能测试事件轨道
func create_performance_event_track(track_index: int, config: Dictionary) -> JuicyEventTrack:
	var track = JuicyEventTrack.new()
	track.track_name = "PerfEventTrack_" + str(track_index)
	track.duration = config.duration
	
	# 创建事件
	var event = JuicyEvent.create_particle_spawn_event("perf_event", null, null, 5 + track_index * 2)
	track.juicy_event = event
	
	# 添加事件触发关键帧
	var trigger_interval = config.duration / max(1, config.keyframe_count / 3)
	for i in range(min(3, config.keyframe_count)):
		var keyframe = JuicyKeyframe.new()
		keyframe.time = i * trigger_interval
		keyframe.value = {"count": 5 + track_index, "spread": 30.0 + track_index * 10.0}
		keyframe.interpolation_type = JuicyKeyframe.InterpolationType.STEP
		track.add_keyframe(keyframe)
	
	return track

# 系统预热
func warmup_timeline_system():
	print("系统预热中...")
	
	# 创建简单Timeline进行预热
	var warmup_timeline = JuicyTimelineResource.new()
	warmup_timeline.timeline_name = "WarmupTimeline"
	warmup_timeline.duration = 0.1
	
	var warmup_track = create_performance_property_track(0, {
		"track_count": 1,
		"keyframe_count": 2,
		"duration": 0.1
	})
	
	warmup_timeline.add_track(warmup_track)
	
	# 播放并立即停止
	var warmup_target = create_test_target()
	var warmup_context = JuicyMixer.play(warmup_timeline, warmup_target)
	JuicyMixer.stop(warmup_context)
	
	# 清理
	warmup_target.queue_free()
	
	print("预热完成")

# 测量创建性能
func measure_creation_performance(timeline: JuicyTimelineResource, config: Dictionary) -> Dictionary:
	var targets = []
	
	# 创建目标节点
	var start_time = Time.get_ticks_msec()
	
	for i in range(config.instance_count):
		targets.append(create_test_target())
	
	# 创建Timeline实例
	var context_ids = []
	for i in range(config.instance_count):
		var context_id = JuicyMixer.play(timeline, targets[i])
		context_ids.append(context_id)
	
	var end_time = Time.get_ticks_msec()
	var total_time = end_time - start_time
	
	return {
		"total_time": total_time,
		"average_time": float(total_time) / config.instance_count,
		"targets": targets,
		"context_ids": context_ids
	}

# 测量播放性能
func measure_playback_performance(timeline: JuicyTimelineResource, config: Dictionary, targets: Array) -> Dictionary:
	var start_time = Time.get_ticks_msec()
	
	# 等待播放完成
	await get_tree().create_timer(config.duration + 0.5).timeout
	
	var end_time = Time.get_ticks_msec()
	var total_time = end_time - start_time
	
	# 测量帧时间
	var frame_times = []
	var frame_timer = Timer.new()
	frame_timer.wait_time = 0.016  # ~60 FPS
	frame_timer.timeout.connect(_on_frame_tick.bind(frame_times))
	frame_timer.autostart = true
	add_child(frame_timer)
	
	await get_tree().create_timer(1.0).timeout  # 测量1秒的帧时间
	
	frame_timer.queue_free()
	
	var average_frame_time = 0.0
	if frame_times.size() > 0:
		var total = 0.0
		for frame_time in frame_times:
			total += frame_time
		average_frame_time = total / frame_times.size()
	
	return {
		"total_time": total_time,
		"average_frame_time": average_frame_time
	}

# 测量内存使用
func measure_memory_usage(targets: Array) -> Dictionary:
	var peak_memory = 0
	var total_memory = 0
	
	# 测量多个时间点的内存使用
	for i in range(5):
		var current_memory = OS.get_static_memory_usage() / 1024  # KB
		peak_memory = max(peak_memory, current_memory)
		total_memory += current_memory
		await get_tree().process_frame
	
	var average_memory = float(total_memory) / targets.size()
	
	return {
		"peak_memory": peak_memory,
		"average_memory": average_memory
	}

# 分析性能指标
func analyze_performance_metrics(config_name: String, creation: Dictionary, playback: Dictionary, memory: Dictionary) -> Dictionary:
	var config = performance_configs[config_name]
	
	# 计算评级
	var rating = "优秀"
	var issues = []
	
	# 分析创建性能
	if creation.average_time > performance_benchmarks.creation_time_per_instance * 2.0:
		rating = "需要优化"
		issues.append("创建时间过长")
	elif creation.average_time > performance_benchmarks.creation_time_per_instance * 1.5:
		rating = "良好"
	
	# 分析播放性能
	if playback.average_frame_time > performance_benchmarks.frame_time_30fps:
		rating = "需要优化"
		issues.append("帧时间过长，可能影响流畅度")
	elif playback.average_frame_time > performance_benchmarks.frame_time_60fps:
		rating = "良好"
	
	# 分析内存使用
	if memory.average_memory > performance_benchmarks.memory_per_instance * 2.0:
		rating = "需要优化"
		issues.append("内存使用过高")
	elif memory.average_memory > performance_benchmarks.memory_per_instance * 1.5:
		rating = "良好"
	
	# 计算效率分数
	var creation_efficiency = performance_benchmarks.creation_time_per_instance / creation.average_time
	var playback_efficiency = performance_benchmarks.frame_time_60fps / playback.average_frame_time
	var memory_efficiency = performance_benchmarks.memory_per_instance / memory.average_memory
	
	var overall_efficiency = (creation_efficiency + playback_efficiency + memory_efficiency) / 3.0
	
	return {
		"rating": rating,
		"issues": issues,
		"creation_efficiency": creation_efficiency,
		"playback_efficiency": playback_efficiency,
		"memory_efficiency": memory_efficiency,
		"overall_efficiency": overall_efficiency
	}

# 缓存效果测试
func test_caching_performance():
	print("\n--- 缓存效果测试 ---")
	
	var config = performance_configs["standard"]
	var timeline = create_performance_timeline(config)
	
	# 测试无缓存
	var no_cache_metrics = await run_caching_test(timeline, config, false)
	
	# 测试有缓存
	timeline.set_meta("enable_caching", true)
	var with_cache_metrics = await run_caching_test(timeline, config, true)
	
	# 分析缓存效果
	var cache_improvement = float(no_cache_metrics.creation_time) / with_cache_metrics.creation_time
	
	print("  缓存改进: ", cache_improvement, "x")
	print("  无缓存创建时间: ", no_cache_metrics.creation_time, "ms")
	print("  有缓存创建时间: ", with_cache_metrics.creation_time, "ms")

# 运行缓存测试
func run_caching_test(timeline: JuicyTimelineResource, config: Dictionary, enable_cache: bool) -> Dictionary:
	var targets = []
	
	# 创建目标节点
	for i in range(config.instance_count):
		targets.append(create_test_target())
	
	# 测量创建时间
	var start_time = Time.get_ticks_msec()
	
	var context_ids = []
	for i in range(config.instance_count):
		var context_id = JuicyMixer.play(timeline, targets[i])
		context_ids.append(context_id)
	
	var end_time = Time.get_ticks_msec()
	
	# 清理
	for context_id in context_ids:
		JuicyMixer.stop(context_id)
	
	for target in targets:
		target.queue_free()
	
	return {
		"creation_time": end_time - start_time
	}

# 插值类型性能测试
func test_interpolation_performance():
	print("\n--- 插值类型性能测试 ---")
	
	var interpolation_types = [
		JuicyKeyframe.InterpolationType.LINEAR,
		JuicyKeyframe.InterpolationType.EASE_IN,
		JuicyKeyframe.InterpolationType.EASE_OUT,
		JuicyKeyframe.InterpolationType.EASE_IN_OUT,
		JuicyKeyframe.InterpolationType.STEP
	]
	
	var interpolation_names = ["LINEAR", "EASE_IN", "EASE_OUT", "EASE_IN_OUT", "STEP"]
	
	for i in range(interpolation_types.size()):
		var interp_type = interpolation_types[i]
		var interp_name = interpolation_names[i]
		
		var metrics = await test_interpolation_type_performance(interp_type, interp_name)
		
		print("  ", interp_name, ": ", metrics.average_time, "ms")

# 测试单个插值类型性能
func test_interpolation_type_performance(interp_type: int, name: String) -> Dictionary:
	var timeline = JuicyTimelineResource.new()
	timeline.timeline_name = "InterpolationTest"
	timeline.duration = 1.0
	
	var track = JuicyPropertyTrack.new()
	track.track_name = "InterpolationTestTrack"
	track.target_node_path = "Sprite2D"
	track.property_path = "scale"
	track.duration = 1.0
	
	# 添加关键帧
	var keyframe1 = JuicyKeyframe.new()
	keyframe1.time = 0.0
	keyframe1.value = Vector2.ONE
	keyframe1.interpolation_type = interp_type
	
	var keyframe2 = JuicyKeyframe.new()
	keyframe2.time = 1.0
	keyframe2.value = Vector2(2.0, 2.0)
	keyframe2.interpolation_type = interp_type
	
	track.add_keyframe(keyframe1)
	track.add_keyframe(keyframe2)
	timeline.add_track(track)
	
	# 测量性能
	var start_time = Time.get_ticks_msec()
	
	var target = create_test_target()
	var context_id = JuicyMixer.play(timeline, target)
	
	await get_tree().create_timer(2.0).timeout
	
	var end_time = Time.get_ticks_msec()
	
	JuicyMixer.stop(context_id)
	target.queue_free()
	
	return {
		"average_time": (end_time - start_time) / 100.0  # 转换为平均时间
	}

# 帧时间测量
func _on_frame_tick(frame_times: Array):
	frame_times.append(Time.get_ticks_msec() % 1000)

# 创建测试目标
func create_test_target() -> Node2D:
	var target = Node2D.new()
	var sprite = Sprite2D.new()
	sprite.texture = load("res://icon.svg")
	target.add_child(sprite)
	get_tree().current_scene.add_child(target)
	return target

# 性能测试方法
func performance_test_method(track_index: int, value: float):
	# 空实现，仅用于性能测试
	pass

# 生成优化报告
func generate_optimization_report():
	print("\n=== Timeline性能优化验证报告 ===")
	print("测试时间: ", Time.get_datetime_string_from_system())
	print("")
	
	# 总体分析
	var overall_rating = "优秀"
	var optimization_suggestions = []
	
	for config_name in optimization_results.keys():
		var results = optimization_results[config_name]
		var analysis = results.analysis
		
		print("## ", config_name.to_upper(), " 测试结果")
		print("- 性能评级: ", analysis.rating)
		print("- 创建效率: ", "%.2f%%" % (analysis.creation_efficiency * 100))
		print("- 播放效率: ", "%.2f%%" % (analysis.playback_efficiency * 100))
		print("- 内存效率: ", "%.2f%%" % (analysis.memory_efficiency * 100))
		print("- 总体效率: ", "%.2f%%" % (analysis.overall_efficiency * 100))
		
		if not analysis.issues.is_empty():
			print("- 问题: ", ", ".join(analysis.issues))
		
		print("")
		
		# 更新总体评级
		if analysis.rating == "需要优化":
			overall_rating = "需要优化"
		elif analysis.rating == "良好" and overall_rating == "优秀":
			overall_rating = "良好"
	
	# 生成优化建议
	if overall_rating == "需要优化":
		optimization_suggestions.append("减少轨道数量和关键帧数量")
		optimization_suggestions.append("启用Timeline缓存系统")
		optimization_suggestions.append("使用更高效的插值类型")
		optimization_suggestions.append("考虑使用对象池化")
	elif overall_rating == "良好":
		optimization_suggestions.append("优化关键帧分布")
		optimization_suggestions.append("启用批处理优化")
	
	print("## 总体性能评级: ", overall_rating)
	print("## 优化建议:")
	for suggestion in optimization_suggestions:
		print("- ", suggestion)
	
	# 保存报告
	save_optimization_report(overall_rating, optimization_suggestions)

# 保存优化报告
func save_optimization_report(rating: String, suggestions: Array):
	var report_content = "# Timeline性能优化验证报告\n\n"
	report_content += "测试时间: " + Time.get_datetime_string_from_system() + "\n"
	report_content += "总体性能评级: " + rating + "\n\n"
	report_content += "## 优化建议\n"
	
	for suggestion in suggestions:
		report_content += "- " + suggestion + "\n"
	
	# 保存文件
	var file = FileAccess.open("user://timeline_performance_optimization_report.md", FileAccess.WRITE)
	if file:
		file.store_string(report_content)
		file.close()
		print("优化报告已保存到: user://timeline_performance_optimization_report.md")
	else:
		print("无法保存优化报告文件")