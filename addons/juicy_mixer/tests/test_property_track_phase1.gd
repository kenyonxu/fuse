extends Node2D
## Property Track Phase 1 测试脚本
## 测试 Curve 模式的采样逻辑和值域系统

# 测试节点引用
@onready var test_sprite = $TestSprite
@onready var test_color_rect = $TestColorRect
@onready var test_label = $TestLabel
@onready var main_label = $Label

# Property Track 资源
var test_track: JuicyPropertyTrack

# 当前测试类型
var current_test_type: int = 0

# 测试时间
var test_time: float = 0.0
var test_duration: float = 2.0
var is_testing: bool = false

# 测试配置
enum TestType {
	FLOAT_ALPHA,      # 测试 Float 类型 (modulate.a)
	VECTOR2_POSITION, # 测试 Vector2 类型 (position)
	VECTOR2_SCALE,    # 测试 Vector2 类型 (scale) - Sprite2D 的 scale 是 Vector2
	COLOR_MODULATE,   # 测试 Color 类型 (modulate)
	INT_ROTATION      # 测试 Int 类型 (rotation_degrees)
}

func _ready():
	print("=== Property Track Phase 1 Test Started ===")
	_update_label()

func _input(event):
	if event.is_action_pressed("ui_accept"):
		_restart_test()
	elif event.is_action_pressed("ui_cancel"):
		_stop_test()
	elif event is InputEventKey:
		match event.keycode:
			KEY_1: _start_test(TestType.FLOAT_ALPHA)
			KEY_2: _start_test(TestType.VECTOR2_POSITION)
			KEY_3: _start_test(TestType.VECTOR2_SCALE)
			KEY_4: _start_test(TestType.COLOR_MODULATE)
			KEY_5: _start_test(TestType.INT_ROTATION)

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
	match current_test_type:
		TestType.FLOAT_ALPHA:
			_test_setup_float_alpha(test_track)
		TestType.VECTOR2_POSITION:
			_test_setup_vector2_position(test_track)
		TestType.VECTOR2_SCALE:
			_test_setup_vector2_scale(test_track)
		TestType.COLOR_MODULATE:
			_test_setup_color_modulate(test_track)
		TestType.INT_ROTATION:
			_test_setup_int_rotation(test_track)

	print("✅ Test track created successfully")

func _test_setup_float_alpha(track: JuicyPropertyTrack):
	"""测试 Float 类型：modulate.a"""
	track.property_path = "modulate.a"
	track.target = NodePath("TestSprite")
	track.edit_mode = JuicyPropertyTrack.EditMode.CURVE_BASED
	track.time_start = 0.0
	track.time_end = test_duration

	# 创建一个简单的渐变曲线
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.0))  # 透明度从 0 开始
	curve.add_point(Vector2(1.0, 1.0))  # 透明度到 1 结束
	track.animation_curve = curve

	print("📊 Test configured: Float (alpha) 0.0 → 1.0 over ", test_duration, "s")

func _test_setup_vector2_position(track: JuicyPropertyTrack):
	"""测试 Vector2 类型：position"""
	current_test_type = TestType.VECTOR2_POSITION
	track.property_path = "position"
	track.edit_mode = JuicyPropertyTrack.EditMode.CURVE_BASED
	track.time_start = 0.0
	track.time_end = test_duration

	# 创建简单的位置变化曲线
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.0))   # 从起点开始
	curve.add_point(Vector2(0.5, 1.0))   # 中间达到最大
	curve.add_point(Vector2(1.0, 0.0))   # 回到起点
	track.animation_curve = curve

	# 设置 Vector2 值域
	track.value_min = Vector2(100, 100)  # 原始位置
	track.value_max = Vector2(400, 100)  # 向右移动 300 像素

	print("📊 Test configured: Vector2 (position) ", track.value_min, " → ", track.value_max)

func _test_setup_vector2_scale(track: JuicyPropertyTrack):
	"""测试 Vector2 类型：scale (Sprite2D 的 scale 是 Vector2)"""
	current_test_type = TestType.VECTOR2_SCALE
	track.property_path = "scale"
	track.edit_mode = JuicyPropertyTrack.EditMode.CURVE_BASED
	track.time_start = 0.0
	track.time_end = test_duration

	# 创建缩放曲线
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.0))   # 从最小开始
	curve.add_point(Vector2(0.5, 1.0))   # 中间达到最大
	curve.add_point(Vector2(1.0, 0.0))   # 回到最小
	track.animation_curve = curve

	# 设置 Vector2 值域
	track.value_min = Vector2(1.0, 1.0)  # 原始大小
	track.value_max = Vector2(2.0, 2.0)  # 放大 2 倍

	print("📊 Test configured: Vector2 (scale) ", track.value_min, " → ", track.value_max)

func _test_setup_color_modulate(track: JuicyPropertyTrack):
	"""测试 Color 类型：modulate"""
	current_test_type = TestType.COLOR_MODULATE
	track.property_path = "modulate"
	track.edit_mode = JuicyPropertyTrack.EditMode.CURVE_BASED
	track.time_start = 0.0
	track.time_end = test_duration

	# 创建颜色变化曲线
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.5, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	track.animation_curve = curve

	# 设置 Color 值域（从黑色到白色）
	track.value_min = Color(0, 0, 0, 1)  # 黑色
	track.value_max = Color(1, 1, 1, 1)  # 白色

	print("📊 Test configured: Color (modulate) ", track.value_min, " → ", track.value_max)

func _test_setup_int_rotation(track: JuicyPropertyTrack):
	"""测试 Int 类型：rotation_degrees"""
	current_test_type = TestType.INT_ROTATION
	track.property_path = "rotation_degrees"
	track.edit_mode = JuicyPropertyTrack.EditMode.CURVE_BASED
	track.time_start = 0.0
	track.time_end = test_duration

	# 创建旋转曲线
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(1.0, 1.0))
	track.animation_curve = curve

	# 设置 Int 值域
	track.value_min = 0    # 0 度
	track.value_max = 360  # 360 度

	print("📊 Test configured: Int (rotation) ", track.value_min, " → ", track.value_max, " degrees")

func _start_test(type: int):
	"""开始指定类型的测试"""
	current_test_type = type
	is_testing = false
	test_time = 0.0

	# 重置节点状态
	_reset_test_nodes()

	# 创建测试 track
	_create_test_track()

	is_testing = true
	print("\n🚀 Starting test type: ", TestType.keys()[type])
	_update_label()

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
	test_sprite.modulate = Color(1, 1, 1, 1)
	test_sprite.position = Vector2(100, 100)
	test_sprite.scale = Vector2(1, 1)
	test_sprite.rotation_degrees = 0

	test_color_rect.color = Color(1, 1, 1, 1)
	test_label.text = "Value: 0.0"

func _update_test_display(progress: float):
	"""更新测试显示"""
	var context = JuicyContext.new()
	var value = test_track.get_value_at_time(test_time, context)

	# 🔥 应用采样值到目标节点
	_apply_sampled_value(value)

	match current_test_type:
		TestType.FLOAT_ALPHA:
			var alpha = float(value)
			test_label.text = "Alpha: %.3f" % alpha
			print("⏱ Time: %.2f/%.2f | Alpha: %.3f" % [test_time, test_duration, alpha])

		TestType.VECTOR2_POSITION:
			var pos = value as Vector2
			test_label.text = "Pos: (%.1f, %.1f)" % [pos.x, pos.y]
			print("⏱ Time: %.2f/%.2f | Position: %s" % [test_time, test_duration, pos])

		TestType.VECTOR2_SCALE:
			var scale_val = value as Vector2
			test_label.text = "Scale: (%.2f, %.2f)" % [scale_val.x, scale_val.y]
			print("⏱ Time: %.2f/%.2f | Scale: %s" % [test_time, test_duration, scale_val])

		TestType.COLOR_MODULATE:
			var color = value as Color
			test_label.text = "Color: (%.2f, %.2f, %.2f)" % [color.r, color.g, color.b]
			print("⏱ Time: %.2f/%.2f | Color: %s" % [test_time, test_duration, color])

		TestType.INT_ROTATION:
			var rotation = int(round(float(value)))
			test_label.text = "Rotation: %d°" % rotation
			print("⏱ Time: %.2f/%.2f | Rotation: %d°" % [test_time, test_duration, rotation])

## 应用采样值到目标节点
func _apply_sampled_value(value: Variant):
	"""将采样值应用到 TestSprite"""
	match current_test_type:
		TestType.FLOAT_ALPHA:
			# 嵌套属性：需要更新 modulate 的 alpha 通道
			var current_modulate = test_sprite.modulate
			current_modulate.a = float(value)
			test_sprite.modulate = current_modulate

		TestType.VECTOR2_POSITION:
			# 直接设置 position
			test_sprite.position = value as Vector2

		TestType.VECTOR2_SCALE:
			# 直接设置 scale (Sprite2D 的 scale 就是 Vector2)
			test_sprite.scale = value as Vector2

		TestType.COLOR_MODULATE:
			# 直接设置 modulate
			test_sprite.modulate = value as Color

		TestType.INT_ROTATION:
			# 设置旋转角度
			test_sprite.rotation_degrees = float(value)

func _print_test_results():
	"""打印测试结果"""
	print("\n✅ Test completed: ", TestType.keys()[current_test_type])
	print("   Duration: ", test_duration, "s")
	print("   Sample count: ~", int(test_duration * 60), " frames")

	# 验证结果
	_verify_test_results()

func _verify_test_results():
	"""验证测试结果是否符合预期"""
	print("\n🔍 Verification:")

	match current_test_type:
		TestType.FLOAT_ALPHA:
			# 最终应该是完全不透明
			var final_alpha = test_sprite.modulate.a
			print("   Final alpha: ", final_alpha)
			assert(abs(final_alpha - 1.0) < 0.01, "Final alpha should be 1.0")
			print("   ✅ Float interpolation test PASSED")

		TestType.VECTOR2_POSITION:
			# 最终应该回到起点
			var final_pos = test_sprite.position
			print("   Final position: ", final_pos)
			assert(final_pos.distance_to(Vector2(100, 100)) < 1.0, "Should return to start")
			print("   ✅ Vector2 interpolation test PASSED")

		TestType.VECTOR2_SCALE:
			# 最终应该回到原始大小
			var final_scale = test_sprite.scale
			print("   Final scale: ", final_scale)
			assert(abs(final_scale.x - 1.0) < 0.01, "Should return to scale 1.0")
			print("   ✅ Vector2 scale interpolation test PASSED")

		TestType.COLOR_MODULATE:
			# 最终应该回到黑色（曲线是往返的：黑→白→黑）
			var final_color = test_sprite.modulate
			print("   Final color: ", final_color)
			# Color 没有 distance_to 方法，需要检查每个通道
			var color_diff = abs(final_color.r - 0.0) + abs(final_color.g - 0.0) + abs(final_color.b - 0.0)
			assert(color_diff < 0.03, "Should return to black (round-trip curve)")
			print("   ✅ Color interpolation test PASSED")

		TestType.INT_ROTATION:
			# 最终应该是 360 度（或接近 0/360 度）
			var final_rotation = int(test_sprite.rotation_degrees)
			var rotation_mod = final_rotation % 360
			print("   Final rotation: ", final_rotation, "° (mod 360 = ", rotation_mod, "°)")
			# 允许 0 或 359（浮点数精度问题）
			assert(rotation_mod == 0 or rotation_mod == 359 or rotation_mod == 360, "Should complete full rotation")
			print("   ✅ Int interpolation test PASSED")

func _update_label():
	var test_name = TestType.keys()[current_test_type] if current_test_type >= 0 else "None"
	var status = "RUNNING" if is_testing else "READY"

	main_label.text = "Property Track Phase 1 Test\n\n" + \
		"Current Test: %s\n" % test_name + \
		"Status: %s\n\n" % status + \
		"Press 1-5 to test different property types:\n" + \
		"  1: Float (alpha)\n" + \
		"  2: Vector2 (position)\n" + \
		"  3: Vector2 (scale)\n" + \
		"  4: Color (modulate)\n" + \
		"  5: Int (rotation)\n\n" + \
		"Press ENTER to restart test\n" + \
		"Press ESC to stop"
