extends Node2D
## Property Track Phase 2 测试脚本
## 测试双向 Bake 系统（Curve ↔ Keyframe）

# 测试节点引用
@onready var test_sprite = $TestSprite
@onready var main_label = $Label

# Property Track 资源
var test_track: JuicyPropertyTrack

# 测试状态
var test_time: float = 0.0
var test_duration: float = 2.0
var is_testing: bool = false

# 测试配置
enum TestType {
	BAKE_CURVE_TO_KEYFRAMES,  # 测试 Curve → Keyframes
	BAKE_KEYFRAMES_TO_CURVE,  # 测试 Keyframes → Curve
	ROUND_TRIP_TEST           # 测试双向转换的精度
}

var current_test_type: int = TestType.BAKE_CURVE_TO_KEYFRAMES

func _ready():
	print("=== Property Track Phase 2 Test Started ===")
	_update_label()

func _input(event):
	if event.is_action_pressed("ui_accept"):
		_restart_test()
	elif event.is_action_pressed("ui_cancel"):
		_stop_test()
	elif event is InputEventKey:
		match event.keycode:
			KEY_1: _start_test(TestType.BAKE_CURVE_TO_KEYFRAMES)
			KEY_2: _start_test(TestType.BAKE_KEYFRAMES_TO_CURVE)
			KEY_3: _start_test(TestType.ROUND_TRIP_TEST)

func _process(delta):
	if is_testing:
		test_time += delta
		var progress = test_time / test_duration

		if progress >= 1.0:
			# 测试完成
			_print_test_results()
			_stop_test()
		else:
			# 更新测试值显示
			_update_test_display(progress)

func _create_test_track():
	"""创建测试用的 Property Track"""
	test_track = JuicyPropertyTrack.new()
	test_track.target = NodePath("TestSprite")

	# 设置基础属性
	test_track.property_path = "position"
	test_track.edit_mode = JuicyPropertyTrack.EditMode.CURVE_BASED
	test_track.time_start = 0.0
	test_track.time_end = test_duration

	# 设置 Vector2 值域
	test_track.value_min = Vector2(100, 100)
	test_track.value_max = Vector2(500, 100)

	print("✅ Test track created successfully")

func _setup_test_curve():
	"""创建测试用的 Animation Curve"""
	var curve = Curve.new()

	# 创建一个抛物线形状的曲线
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.5, 1.0))  # 顶点
	curve.add_point(Vector2(1.0, 0.0))

	test_track.animation_curve = curve

	print("📊 Test curve created: Parabolic shape (0 → 1 → 0)")

func _start_test(type: int):
	"""开始指定类型的测试"""
	current_test_type = type
	is_testing = false
	test_time = 0.0

	# 重置节点状态
	_reset_test_nodes()

	# 创建测试 track
	_create_test_track()

	# 设置测试曲线
	_setup_test_curve()

	# 根据测试类型执行不同的操作
	match current_test_type:
		TestType.BAKE_CURVE_TO_KEYFRAMES:
			_test_bake_curve_to_keyframes()

		TestType.BAKE_KEYFRAMES_TO_CURVE:
			_test_bake_keyframes_to_curve()

		TestType.ROUND_TRIP_TEST:
			_test_round_trip()

	is_testing = true
	print("\n🚀 Starting test type: ", TestType.keys()[type])
	_update_label()

func _test_bake_curve_to_keyframes():
	"""测试 Curve → Keyframes 转换"""
	print("\n=== 测试 Curve → Keyframes ===")

	var original_curve = test_track.animation_curve
	var original_point_count = original_curve.get_point_count()

	print("原始曲线点数: ", original_point_count)
	print("  - 点 0: ", original_curve.get_point_position(0))
	print("  - 点 1: ", original_curve.get_point_position(1))
	print("  - 点 2: ", original_curve.get_point_position(2))

	# 执行 bake
	test_track.bake_curve_to_keyframes()  # 使用 curve 的实际控制点

	# 验证结果
	print("\nBake 结果:")
	print("  - 编辑模式: ", JuicyPropertyTrack.EditMode.keys()[test_track.edit_mode])
	print("  - 关键帧数量: ", test_track.keyframes.size())
	print("  - Bake 元数据: ", test_track.keyframes_baked_from_curve)

	# 打印前几个关键帧
	for i in range(min(5, test_track.keyframes.size())):
		var kf = test_track.keyframes[i]
		print("  - 关键帧 %d: time=%.2f, value=%s" % [i, kf.time, kf.value])

	# 验证
	assert(test_track.edit_mode == JuicyPropertyTrack.EditMode.KEYFRAME_BASED, "编辑模式应为 KEYFRAME_BASED")
	assert(test_track.keyframes.size() == 11, "应生成 11 个关键帧")
	assert(test_track.keyframes_baked_from_curve == true, "应标记为从 curve bake 而来")

	print("\n✅ Curve → Keyframes 转换测试 PASSED")

func _test_bake_keyframes_to_curve():
	"""测试 Keyframes → Curve 转换"""
	print("\n=== 测试 Keyframes → Curve ===")

	# 先创建一些关键帧
	test_track.edit_mode = JuicyPropertyTrack.EditMode.KEYFRAME_BASED
	test_track.keyframes.clear()

	# 创建 3 个关键帧
	var kf1 = test_track.create_keyframe(0.0, Vector2(100, 100))
	var kf2 = test_track.create_keyframe(1.0, Vector2(300, 100))
	var kf3 = test_track.create_keyframe(2.0, Vector2(100, 100))

	test_track.keyframes.append(kf1)
	test_track.keyframes.append(kf2)
	test_track.keyframes.append(kf3)

	print("原始关键帧数量: ", test_track.keyframes.size())
	print("  - 关键帧 0: time=%.2f, value=%s" % [kf1.time, kf1.value])
	print("  - 关键帧 1: time=%.2f, value=%s" % [kf2.time, kf2.value])
	print("  - 关键帧 2: time=%.2f, value=%s" % [kf3.time, kf3.value])

	# 执行 bake back
	test_track.bake_keyframes_to_curve()

	# 验证结果
	print("\nBake Back 结果:")
	print("  - 编辑模式: ", JuicyPropertyTrack.EditMode.keys()[test_track.edit_mode])
	print("  - 曲线点数: ", test_track.animation_curve.get_point_count())

	# 打印曲线点
	for i in range(test_track.animation_curve.get_point_count()):
		var point = test_track.animation_curve.get_point_position(i)
		print("  - 曲线点 %d: %s" % [i, point])

	# 验证
	assert(test_track.edit_mode == JuicyPropertyTrack.EditMode.CURVE_BASED, "编辑模式应为 CURVE_BASED")
	assert(test_track.animation_curve != null, "应创建曲线")
	assert(test_track.keyframes_baked_from_curve == false, "应标记为非从 curve bake 而来")

	print("\n✅ Keyframes → Curve 转换测试 PASSED")

func _test_round_trip():
	"""测试双向转换的精度"""
	print("\n=== 测试双向转换精度 ===")

	# 保存原始曲线
	var original_curve = test_track.animation_curve.duplicate()

	print("步骤 1: Curve → Keyframes")
	test_track.bake_curve_to_keyframes()
	var keyframe_count = test_track.keyframes.size()
	print("  生成关键帧数: ", keyframe_count)

	print("\n步骤 2: Keyframes → Curve")
	test_track.bake_keyframes_to_curve()
	var curve_point_count = test_track.animation_curve.get_point_count()
	print("  生成曲线点数: ", curve_point_count)

	print("\n步骤 3: 验证精度")
	# 在多个时间点采样，比较原始曲线和最终曲线的值
	var max_error = 0.0
	var sample_count = 100

	for i in range(sample_count + 1):
		var t = float(i) / float(sample_count)
		var actual_time = test_track.time_start + t * (test_track.time_end - test_track.time_start)

		# 从原始曲线采样
		var original_val = _sample_curve(original_curve, t, test_track)

		# 从最终曲线采样
		var final_val = _sample_curve(test_track.animation_curve, t, test_track)

		# 计算误差
		var error = (final_val as Vector2).distance_to(original_val as Vector2)
		max_error = max(max_error, error)

	print("  最大误差: %.4f 像素" % max_error)
	print("  验收标准: 误差 < 10.0 像素")

	# 验证
	assert(max_error < 10.0, "最大误差应小于 10 像素，实际为 %.2f" % max_error)

	print("\n✅ 双向转换精度测试 PASSED")

func _sample_curve(curve: Curve, t: float, track: JuicyPropertyTrack) -> Variant:
	"""辅助函数：从曲线采样（模拟 track 的采样逻辑）"""
	var curve_val = curve.sample(t)
	var value_min = track.value_min as Vector2
	var value_max = track.value_max as Vector2
	return value_min.lerp(value_max, curve_val)

func _update_test_display(progress: float):
	"""更新测试显示"""
	var context = JuicyContext.new()
	var value = test_track.get_value_at_time(test_time, context)

	# 应用采样值到目标节点
	test_sprite.position = value as Vector2

	main_label.text = "Property Track Phase 2 Test\n\n" + \
		"Test: %s\n" % TestType.keys()[current_test_type] + \
		"Time: %.2f/%.2f\n" % [test_time, test_duration] + \
		"Position: (%.1f, %.1f)\n" % [(value as Vector2).x, (value as Vector2).y] + \
		"\nPress 1-3 to test different bake functions:\n" + \
		"  1: Curve → Keyframes\n" + \
		"  2: Keyframes → Curve\n" + \
		"  3: Round Trip Test\n\n" + \
		"Press ENTER to restart test\n" + \
		"Press ESC to stop"

func _print_test_results():
	"""打印测试结果"""
	print("\n✅ Test completed: ", TestType.keys()[current_test_type])
	print("   Duration: ", test_duration, "s")
	print("   Sample count: ~", int(test_duration * 60), " frames")

func _stop_test():
	"""停止测试"""
	is_testing = false
	test_time = 0.0
	_reset_test_nodes()
	_update_label()

func _restart_test():
	"""重新开始当前测试"""
	if current_test_type >= 0:
		_start_test(current_test_type)

func _reset_test_nodes():
	"""重置测试节点到初始状态"""
	test_sprite.position = Vector2(100, 100)

func _update_label():
	var test_name = TestType.keys()[current_test_type] if current_test_type >= 0 else "None"
	var status = "RUNNING" if is_testing else "READY"

	main_label.text = "Property Track Phase 2 Test\n\n" + \
		"Current Test: %s\n" % test_name + \
		"Status: %s\n\n" % status + \
		"Press 1-3 to test different bake functions:\n" + \
		"  1: Curve → Keyframes\n" + \
		"  2: Keyframes → Curve\n" + \
		"  3: Round Trip Test\n\n" + \
		"Press ENTER to restart test\n" + \
		"Press ESC to stop"
