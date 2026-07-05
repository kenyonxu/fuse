# JuicyTimelineDriver 多播放测试
# 测试 Timeline Driver 在多个播放场景下的状态隔离
# 验证不同 context_id 之间的状态不会互相干扰

extends Node

# =============================================================================
# 断言辅助函数
# =============================================================================

func assert_check(condition: bool, message: String = "") -> void:
	if not condition:
		push_error("❌ 断言失败: " + message)
		return
	print("✓ " + message)

func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		push_error("❌ 断言失败: 期望 %s, 实际 %s - %s" % [str(expected), str(actual), message])
		return
	print("✓ " + message)

func assert_true(condition: bool, message: String = "") -> void:
	assert_check(condition, message)

func assert_false(condition: bool, message: String = "") -> void:
	assert_check(not condition, message)

func assert_near(actual: Variant, expected: Variant, tolerance: float = 0.01, message: String = "") -> void:
	var diff = abs(float(actual) - float(expected))
	if diff > tolerance:
		push_error("❌ 断言失败: 期望 %s ≈ %s (±%s), 实际差值 %s - %s" % [str(expected), str(tolerance), str(diff), str(actual), message])
		return
	print("✓ " + message)

func assert_gt(actual: Variant, expected: Variant, message: String = "") -> void:
	if not (actual > expected):
		push_error("❌ 断言失败: 期望 %s > %s, 实际 %s - %s" % [str(expected), str(expected), str(actual), message])
		return
	print("✓ " + message)

# =============================================================================
# 测试数据和节点
# =============================================================================

var timeline_resource: JuicyTimelineResource
var target_nodes: Array[Node2D] = []
var contexts: Array[JuicyContext] = []

# =============================================================================
# 测试初始化
# =============================================================================

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("开始 JuicyTimelineDriver 多播放状态隔离测试")
	print("=".repeat(60) + "\n")

	# 等待一帧以确保所有系统都已初始化
	await get_tree().process_frame

	# 运行所有测试
	await test_basic_multi_play_isolation()
	await test_different_playback_times()
	await test_simultaneous_playback_with_different_loops()
	await test_state_independence_during_pause()

	print("\n" + "=".repeat(60))
	print("所有测试完成！")
	print("=".repeat(60) + "\n")

	# 测试完成后退出
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()

# =============================================================================
# 测试场景准备
# =============================================================================

func setup_test_timeline() -> JuicyTimelineResource:
	"""
	创建一个简单的测试 Timeline
	"""
	var timeline = JuicyTimelineResource.new()
	timeline.resource_name = "TestTimeline"
	timeline.timeline_duration = 2.0  # 2秒时长
	timeline.loop_mode = JuicyTimelineResource.LoopMode.NO_LOOP

	# 添加一个简单的属性轨道（位置变化）
	var property_track = JuicyPropertyTrack.new()
	property_track.track_name = "PositionTrack"
	property_track.property_path = "position"
	property_track.enabled = true
	property_track.start_time = 0.0
	property_track.end_time = 2.0

	# 添加关键帧
	var keyframe1 = JuicyKeyframe.new()
	keyframe1.time = 0.0
	keyframe1.value = Vector2.ZERO

	var keyframe2 = JuicyKeyframe.new()
	keyframe2.time = 1.0
	keyframe2.value = Vector2(50, 50)

	var keyframe3 = JuicyKeyframe.new()
	keyframe3.time = 2.0
	keyframe3.value = Vector2(100, 100)

	property_track.add_keyframe(keyframe1)
	property_track.add_keyframe(keyframe2)
	property_track.add_keyframe(keyframe3)

	timeline.add_track(property_track)
	return timeline

func create_test_targets(count: int) -> Array[Node2D]:
	"""
	创建测试目标节点
	"""
	var targets: Array[Node2D] = []
	for i in range(count):
		var target = Node2D.new()
		target.name = "TestTarget_" + str(i)
		add_child(target)
		targets.append(target)
	return targets

func cleanup_test() -> void:
	"""
	清理测试数据
	"""
	# 停止所有播放
	for context in contexts:
		if context and not context.is_completed:
			JuicyMixer.stop(context.context_id)

	# 清空数组
	contexts.clear()

	# 删除目标节点
	for target in target_nodes:
		if is_instance_valid(target):
			target.queue_free()

	target_nodes.clear()

	# 等待一帧以确保清理完成
	await get_tree().process_frame

# =============================================================================
# 测试用例
# =============================================================================

## 测试1: 基本的多播放隔离
func test_basic_multi_play_isolation() -> void:
	print("\n【测试1】基本的多播放状态隔离测试")

	timeline_resource = setup_test_timeline()
	target_nodes = create_test_targets(3)  # 创建3个目标节点

	# 为每个目标播放相同的 Timeline
	for i in range(3):
		var context = JuicyMixer.play(timeline_resource, target_nodes[i])
		contexts.append(context)
		print("  - 播放 %d: context_id=%s, 目标=%s" % [i, context.context_id, target_nodes[i].name])

	# 等待一段时间让它们运行
	await get_tree().create_timer(0.5).timeout

	# 验证每个播放的状态是独立的
	var driver = timeline_resource.get_driver()

	for i in range(3):
		var context = contexts[i]
		var state = driver._get_timeline_state(context)

		assert_true(state != null, "播放 %d 的状态存在" % i)
		assert_eq(context.target, target_nodes[i], "播放 %d 的目标节点正确" % i)
		print("  - 播放 %d: current_time=%.3f, is_playing=%s" % [i, state.current_time, state.is_playing])

	# 验证不同播放的状态不同（即使它们同时启动，由于时间差异也会略有不同）
	var state0 = driver._get_timeline_state(contexts[0])
	var state1 = driver._get_timeline_state(contexts[1])
	var state2 = driver._get_timeline_state(contexts[2])

	# 所有播放应该在运行
	assert_true(state0.is_playing, "播放0 正在运行")
	assert_true(state1.is_playing, "播放1 正在运行")
	assert_true(state2.is_playing, "播放2 正在运行")

	# 所有播放应该有相似的时间（因为同时启动）
	assert_near(state0.current_time, state1.current_time, 0.05, "播放0和1的时间接近")
	assert_near(state1.current_time, state2.current_time, 0.05, "播放1和2的时间接近")

	print("  ✓ 基本多播放隔离测试通过")

	await cleanup_test()

## 测试2: 不同播放时间的独立性
func test_different_playback_times() -> void:
	print("\n【测试2】不同播放时间的独立性测试")

	timeline_resource = setup_test_timeline()
	target_nodes = create_test_targets(3)

	# 依次启动播放，每个间隔0.3秒
	for i in range(3):
		var context = JuicyMixer.play(timeline_resource, target_nodes[i])
		contexts.append(context)
		print("  - %.1fs: 启动播放 %d" % [float(i) * 0.3, i])

		if i < 2:
			await get_tree().create_timer(0.3).timeout

	# 等待所有播放完成
	await get_tree().create_timer(1.0).timeout

	var driver = timeline_resource.get_driver()

	# 验证播放时间有明显差异
	var state0 = driver._get_timeline_state(contexts[0])
	var state1 = driver._get_timeline_state(contexts[1])
	var state2 = driver._get_timeline_state(contexts[2])

	print("  - 播放0: current_time=%.3f" % state0.current_time)
	print("  - 播放1: current_time=%.3f" % state1.current_time)
	print("  - 播放2: current_time=%.3f" % state2.current_time)

	# 播放0应该最早启动，所以时间最长
	assert_gt(state0.current_time, state1.current_time, "播放0 > 播放1")
	assert_gt(state1.current_time, state2.current_time, "播放1 > 播放2")

	# 验证时间差异大致符合启动间隔
	var diff_01 = state0.current_time - state1.current_time
	var diff_12 = state1.current_time - state2.current_time

	assert_near(diff_01, 0.3, 0.1, "播放0和1的时间差约为0.3秒")
	assert_near(diff_12, 0.3, 0.1, "播放1和2的时间差约为0.3秒")

	print("  ✓ 不同播放时间独立性测试通过")

	await cleanup_test()

## 测试3: 不同循环模式的独立性
func test_simultaneous_playback_with_different_loops() -> void:
	print("\n【测试3】不同循环模式的独立性测试")

	# 创建两个不同循环设置的 Timeline
	var timeline_no_loop = setup_test_timeline()
	timeline_no_loop.loop_mode = JuicyTimelineResource.LoopMode.NO_LOOP
	timeline_no_loop.loop_count = 0

	var timeline_loop = setup_test_timeline()
	timeline_loop.loop_mode = JuicyTimelineResource.LoopMode.LOOP
	timeline_loop.loop_count = 3  # 循环3次

	target_nodes = create_test_targets(2)

	# 同时启动两个不同循环的播放
	var context0 = JuicyMixer.play(timeline_no_loop, target_nodes[0])
	var context1 = JuicyMixer.play(timeline_loop, target_nodes[1])

	contexts.append(context0)
	contexts.append(context1)

	print("  - 播放0: NO_LOOP, 时长2秒")
	print("  - 播放1: LOOP(3次), 时长6秒")

	# 等待3秒
	await get_tree().create_timer(3.0).timeout

	var driver0 = timeline_no_loop.get_driver()
	var driver1 = timeline_loop.get_driver()
	var state0 = driver0._get_timeline_state(context0)
	var state1 = driver1._get_timeline_state(context1)

	print("  - 播放0: is_playing=%s, current_time=%.3f, current_loop=%d" % [state0.is_playing, state0.current_time, state0.current_loop])
	print("  - 播放1: is_playing=%s, current_time=%.3f, current_loop=%d" % [state1.is_playing, state1.current_time, state1.current_loop])

	# 播放0应该已经完成（NO_LOOP，2秒时长）
	assert_false(state0.is_playing, "播放0（NO_LOOP）已完成")
	assert_eq(state0.current_time, 2.0, "播放0的时间在终点")

	# 播放1应该还在运行（LOOP，6秒总时长）
	assert_true(state1.is_playing, "播放1（LOOP）还在运行")
	assert_gt(state1.current_loop, 0, "播放1已经完成至少1次循环")

	print("  ✓ 不同循环模式独立性测试通过")

	await cleanup_test()

## 测试4: 暂停和恢复的独立性
func test_state_independence_during_pause() -> void:
	print("\n【测试4】暂停和恢复的独立性测试")

	timeline_resource = setup_test_timeline()
	target_nodes = create_test_targets(2)

	var context0 = JuicyMixer.play(timeline_resource, target_nodes[0])
	var context1 = JuicyMixer.play(timeline_resource, target_nodes[1])

	contexts.append(context0)
	contexts.append(context1)

	# 等待0.5秒
	await get_tree().create_timer(0.5).timeout

	# 暂停播放0，播放1继续运行
	print("  - 暂停播放0")
	JuicyMixer.pause(context0.context_id)

	# 再等待0.5秒
	await get_tree().create_timer(0.5).timeout

	var driver = timeline_resource.get_driver()
	var state0 = driver._get_timeline_state(context0)
	var state1 = driver._get_timeline_state(context1)

	print("  - 播放0: current_time=%.3f, is_paused=%s" % [state0.current_time, state0.is_paused])
	print("  - 播放1: current_time=%.3f, is_paused=%s" % [state1.current_time, state1.is_paused])

	# 播放0应该被暂停
	assert_true(state0.is_paused, "播放0已暂停")
	assert_true(state0.is_playing, "播放0仍在播放状态")

	# 播放1应该继续运行
	assert_false(state1.is_paused, "播放1未暂停")
	assert_true(state1.is_playing, "播放1正在播放")

	# 播放1的时间应该比播放0多（因为播放0被暂停了）
	var time_diff = state1.current_time - state0.current_time
	assert_gt(time_diff, 0.4, "播放1的时间明显领先播放0")

	# 恢复播放0
	print("  - 恢复播放0")
	JuicyMixer.resume(context0.context_id)

	# 等待0.3秒
	await get_tree().create_timer(0.3).timeout

	state0 = driver._get_timeline_state(context0)
	state1 = driver._get_timeline_state(context1)

	print("  - 恢复后播放0: current_time=%.3f, is_paused=%s" % [state0.current_time, state0.is_paused])
	print("  - 恢复后播放1: current_time=%.3f" % [state1.current_time])

	# 播放0应该恢复运行
	assert_false(state0.is_paused, "播放0已恢复")

	print("  ✓ 暂停和恢复独立性测试通过")

	await cleanup_test()
