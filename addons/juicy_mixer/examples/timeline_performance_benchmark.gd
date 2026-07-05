# JuicyMixer V3 Timeline系统性能基准测试

extends Node

# 基准测试配置
var benchmark_config = {
	"simple_timeline": {
		"track_count": 1,
		"keyframe_count": 5,
		"instance_count": 10,
		"duration": 1.0
	},
	"medium_timeline": {
		"track_count": 5,
		"keyframe_count": 25,
		"instance_count": 20,
		"duration": 2.0
	},
	"complex_timeline": {
		"track_count": 10,
		"keyframe_count": 50,
		"instance_count": 50,
		"duration": 3.0
	}
}

# 性能统计
var performance_stats = {}

func _ready():
	print("开始Timeline性能基准测试")
	
	# 运行所有基准测试
	run_all_benchmarks()
	
	# 生成报告
	generate_performance_report()

# 运行所有基准测试
func run_all_benchmarks():
	print("\n=== 开始性能基准测试 ===")
	
	# 简单Timeline测试
	run_benchmark("simple_timeline")
	
	await get_tree().create_timer(1.0).timeout
	
	# 中等复杂度Timeline测试
	run_benchmark("medium_timeline")
	
	await get_tree().create_timer(1.0).timeout
	
	# 复杂Timeline测试
	run_benchmark("complex_timeline")

# 运行单个基准测试
func run_benchmark(benchmark_name: String):
	print("\n--- ", benchmark_name, " ---")
	
	var config = benchmark_config[benchmark_name]
	var timeline = create_benchmark_timeline(config)
	
	# 预热
	warmup_system()
	
	# 创建性能测试
	var test_results = await create_performance_test(timeline, config)
	
	# 存储结果
	performance_stats[benchmark_name] = test_results
	
	print("完成: ", benchmark_name)
	print("  创建时间: ", test_results.creation_time, "ms")
	print("  播放时间: ", test_results.playback_time, "ms")
	print("  平均帧时间: ", test_results.average_frame_time, "ms")
	print("  成功率: ", test_results.success_rate, "%")

# 创建基准测试Timeline
func create_benchmark_timeline(config: Dictionary) -> JuicyTimelineResource:
	var timeline = JuicyTimelineResource.new()
	timeline.timeline_name = "BenchmarkTimeline"
	timeline.duration = config.duration
	
	# 创建指定数量的轨道
	for i in range(config.track_count):
		var track = create_benchmark_track(i, config)
		timeline.add_track(track)
	
	return timeline

# 创建基准测试轨道
func create_benchmark_track(track_index: int, config: Dictionary) -> JuicyTrack:
	var track_type = track_index % 4
	var track: JuicyTrack
	
	match track_type:
		0: # 属性轨道
			track = create_property_track(track_index, config)
		1: # 反馈轨道
			track = create_feedback_track(track_index, config)
		2: # 方法轨道
			track = create_method_track(track_index, config)
		3: # 事件轨道
			track = create_event_track(track_index, config)
		_:
			track = create_property_track(track_index, config)
	
	return track

# 创建属性轨道
func create_property_track(track_index: int, config: Dictionary) -> JuicyPropertyTrack:
	var track = JuicyPropertyTrack.new()
	track.track_name = "PropertyTrack_" + str(track_index)
	track.target_node_path = "Sprite2D"
	track.property_path = "scale"
	track.duration = config.duration
	
	# 添加关键帧
	var keyframe_interval = config.duration / config.keyframe_count
	for i in range(config.keyframe_count):
		var keyframe = JuicyKeyframe.new()
		keyframe.time = i * keyframe_interval
		keyframe.value = Vector2.ONE * (1.0 + 0.1 * sin(i * PI * 2.0 / config.keyframe_count))
		keyframe.interpolation_type = JuicyKeyframe.InterpolationType.LINEAR
		track.add_keyframe(keyframe)
	
	return track

# 创建反馈轨道
func create_feedback_track(track_index: int, config: Dictionary) -> JuicyFeedbackTrack:
	var track = JuicyFeedbackTrack.new()
	track.track_name = "FeedbackTrack_" + str(track_index)
	track.duration = config.duration
	
	# 创建震动资源
	var shake_resource = JuicyShakeResource.new()
	shake_resource.resource_name = "BenchmarkShake"
	shake_resource.add_shake_data("offset", 10.0, 10.0, 0.5)
	
	track.resource = shake_resource
	
	# 添加触发关键帧
	var trigger = JuicyKeyframe.new()
	trigger.time = 0.1
	trigger.value = true
	trigger.interpolation_type = JuicyKeyframe.InterpolationType.STEP
	track.add_keyframe(trigger)
	
	return track

# 创建方法轨道
func create_method_track(track_index: int, config: Dictionary) -> JuicyMethodTrack:
	var track = JuicyMethodTrack.new()
	track.track_name = "MethodTrack_" + str(track_index)
	track.target_node_path = "AudioStreamPlayer2D"
	track.method_name = "play"
	track.duration = config.duration
	
	# 添加方法调用关键帧
	var call_interval = config.duration / config.keyframe_count
	for i in range(config.keyframe_count):
		var keyframe = JuicyKeyframe.new()
		keyframe.time = i * call_interval
		keyframe.value = ["test_sound.wav", 0.5 + 0.5 * randf()]
		keyframe.interpolation_type = JuicyKeyframe.InterpolationType.STEP
		track.add_keyframe(keyframe)
	
	return track

# 创建事件轨道
func create_event_track(track_index: int, config: Dictionary) -> JuicyEventTrack:
	var track = JuicyEventTrack.new()
	track.track_name = "EventTrack_" + str(track_index)
	track.duration = config.duration
	
	# 创建事件
	var event = JuicyEvent.create_particle_spawn_event("benchmark_event", null, null, 10)
	track.juicy_event = event
	
	# 添加事件触发关键帧
	var trigger_interval = config.duration / config.keyframe_count
	for i in range(config.keyframe_count):
		var keyframe = JuicyKeyframe.new()
		keyframe.time = i * trigger_interval
		keyframe.value = {"count": int(5 + 10 * randf())}
		keyframe.interpolation_type = JuicyKeyframe.InterpolationType.STEP
		track.add_keyframe(keyframe)
	
	return track

# 系统预热
func warmup_system():
	print("系统预热中...")
	
	# 创建简单的Timeline进行预热
	var warmup_timeline = JuicyTimelineResource.new()
	warmup_timeline.timeline_name = "WarmupTimeline"
	warmup_timeline.duration = 0.1
	
	var warmup_track = create_property_track(0, {
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

# 创建性能测试
func create_performance_test(timeline: JuicyTimelineResource, config: Dictionary) -> Dictionary:
	var results = {}
	
	# 1. 测量创建时间
	var creation_start = Time.get_ticks_msec()
	
	# 创建目标节点
	var targets = []
	for i in range(config.instance_count):
		targets.append(create_test_target())
	
	var creation_end = Time.get_ticks_msec()
	results.creation_time = creation_end - creation_start
	
	# 2. 测量播放时间
	var playback_start = Time.get_ticks_msec()
	
	# 播放所有Timeline实例
	var context_ids = []
	for i in range(config.instance_count):
		var context_id = JuicyMixer.play(timeline, targets[i])
		context_ids.append(context_id)
	
	# 等待播放完成
	await get_tree().create_timer(config.duration + 0.5).timeout
	
	# 3. 测量帧时间
	var frame_times = []
	var frame_count = 0
	var frame_timer = Timer.new()
	frame_timer.wait_time = 0.016  # ~60 FPS
	frame_timer.timeout.connect(_on_frame_tick.bind(frame_times))
	frame_timer.autostart = true
	add_child(frame_timer)
	
	await get_tree().create_timer(1.0).timeout  # 测量1秒的帧时间
	
	frame_timer.queue_free()
	
	var playback_end = Time.get_ticks_msec()
	
	# 4. 计算统计
	results.playback_time = playback_end - playback_start
	results.instance_count = config.instance_count
	
	if frame_times.size() > 0:
		var total_frame_time = 0.0
		for frame_time in frame_times:
			total_frame_time += frame_time
		results.average_frame_time = total_frame_time / frame_times.size()
		results.max_frame_time = frame_times.max()
		results.min_frame_time = frame_times.min()
	else:
		results.average_frame_time = 0.0
		results.max_frame_time = 0.0
		results.min_frame_time = 0.0
	
	# 5. 计算成功率
	var success_count = 0
	for context_id in context_ids:
		var context = JuicyMixer.get_context(context_id)
		if context and not context.is_completed():
			success_count += 1
	
	results.success_rate = float(success_count) / context_ids.size() * 100.0
	
	# 6. 清理
	for context_id in context_ids:
		JuicyMixer.stop(context_id)
	
	for target in targets:
		target.queue_free()
	
	return results

# 帧时间测量
func _on_frame_tick(frame_times: Array):
	frame_times.append(Time.get_ticks_msec() % 1000)  # 简化的帧时间测量

# 创建测试目标
func create_test_target() -> Node:
	var container = Node2D.new()
	var sprite = Sprite2D.new()
	sprite.texture = load("res://icon.svg")
	container.add_child(sprite)
	get_tree().current_scene.add_child(container)
	return container

# 生成性能报告
func generate_performance_report():
	print("\n=== Timeline性能基准测试报告 ===")
	print("测试时间: ", Time.get_datetime_string_from_system())
	print("系统信息: ", OS.get_name(), " ", OS.get_version())
	print("Godot版本: ", Engine.get_version_info())
	print("")
	
	# 详细结果
	for benchmark_name in performance_stats.keys():
		var stats = performance_stats[benchmark_name]
		var config = benchmark_config[benchmark_name]
		
		print("## ", benchmark_name.to_upper())
		print("- 实例数量: ", stats.instance_count)
		print("- 轨道数量: ", config.track_count)
		print("- 关键帧数量: ", config.keyframe_count)
		print("- 持续时间: ", config.duration, "秒")
		print("- 创建时间: ", stats.creation_time, "ms")
		print("- 播放时间: ", stats.playback_time, "ms")
		print("- 平均帧时间: ", stats.average_frame_time, "ms")
		print("- 最大帧时间: ", stats.max_frame_time, "ms")
		print("- 最小帧时间: ", stats.min_frame_time, "ms")
		print("- 成功率: ", stats.success_rate, "%")
		print("")
	
	# 性能评级
	performance_rating()
	
	# 保存报告到文件
	save_report_to_file()

# 性能评级
func performance_rating():
	print("## 性能评级")
	
	for benchmark_name in performance_stats.keys():
		var stats = performance_stats[benchmark_name]
		var rating = "优秀"
		
		# 根据平均帧时间评级
		if stats.average_frame_time > 20.0:
			rating = "需要优化"
		elif stats.average_frame_time > 16.0:
			rating = "良好"
		elif stats.average_frame_time > 12.0:
			rating = "良好"
		else:
			rating = "优秀"
		
		print("- ", benchmark_name, ": ", rating)
		
		# 性能建议
		if rating == "需要优化":
			print("  建议: 减少轨道数量、优化关键帧、启用缓存")
		elif rating == "良好":
			print("  建议: 考虑使用更高效的插值类型")
		else:
			print("  建议: 性能表现良好")

# 保存报告到文件
func save_report_to_file():
	var report_content = "# Timeline性能基准测试报告\n\n"
	report_content += "测试时间: " + Time.get_datetime_string_from_system() + "\n"
	report_content += "系统信息: " + OS.get_name() + " " + OS.get_version() + "\n"
	report_content += "Godot版本: " + str(Engine.get_version_info()) + "\n\n"
	
	for benchmark_name in performance_stats.keys():
		var stats = performance_stats[benchmark_name]
		var config = benchmark_config[benchmark_name]
		
		report_content += "## " + benchmark_name.to_upper() + "\n"
		report_content += "- 实例数量: " + str(stats.instance_count) + "\n"
		report_content += "- 轨道数量: " + str(config.track_count) + "\n"
		report_content += "- 关键帧数量: " + str(config.keyframe_count) + "\n"
		report_content += "- 持续时间: " + str(config.duration) + "秒\n"
		report_content += "- 创建时间: " + str(stats.creation_time) + "ms\n"
		report_content += "- 播放时间: " + str(stats.playback_time) + "ms\n"
		report_content += "- 平均帧时间: " + str(stats.average_frame_time) + "ms\n"
		report_content += "- 最大帧时间: " + str(stats.max_frame_time) + "ms\n"
		report_content += "- 最小帧时间: " + str(stats.min_frame_time) + "ms\n"
		report_content += "- 成功率: " + str(stats.success_rate) + "%\n\n"
	
	# 保存文件
	var file = FileAccess.open("user://timeline_performance_benchmark.md", FileAccess.WRITE)
	if file:
		file.store_string(report_content)
		file.close()
		print("报告已保存到: user://timeline_performance_benchmark.md")
	else:
		print("无法保存报告文件")