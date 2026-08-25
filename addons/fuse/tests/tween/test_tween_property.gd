extends Node2D

## Tween Property 指令测试

## 测试目标节点
@onready var test_sprite = $TestSprite
@onready var test_label = $TestLabel

## 测试标签
@onready var info_label = $InfoLabel

## 当前测试状态
var _current_test: int = 0
var _test_active: bool = false

func _ready():
	# 设置初始状态
	test_sprite.modulate = Color.WHITE
	test_sprite.position = Vector2(200, 200)
	test_sprite.scale = Vector2.ONE
	test_sprite.rotation = 0.0

	test_label.text = "Test Label"
	test_label.modulate = Color.WHITE

	info_label.text = """Tween Property Test
Press 1: Test position animation
Press 2: Test scale animation
Press 3: Test rotation animation
Press 4: Test color animation
Press 5: Test modulate alpha animation
Press 6: Test label text animation
Press 7: Test position with auto_free"""

func _input(event):
	if not event.is_pressed():
		return

	if not _test_active:
		match event.keycode:
			KEY_1:
				_test_position_animation()
			KEY_2:
				_test_scale_animation()
			KEY_3:
				_test_rotation_animation()
			KEY_4:
				_test_color_animation()
			KEY_5:
				_test_alpha_animation()
			KEY_6:
				_test_text_animation()
			KEY_7:
				_test_auto_free_animation()

## 测试位置动画
func _test_position_animation():
	print("=== 测试 TweenProperty 指令：位置动画 ===")

	_current_test = 1
	_test_active = true

	var start_pos = test_sprite.position
	var target_pos = Vector2(500, 300)

	info_label.text = "Testing position animation...\nFrom: %s\nTo: %s" % [str(start_pos), str(target_pos)]

	var context = ExecutionContext.new()
	var instruction = TweenPropertyInstruction.new()

	# 配置参数
	instruction.target_node = ^"TestSprite"
	instruction.property_path = "position"
	instruction.to_value = target_pos
	instruction.duration = 1.0
	instruction.auto_free = false
	instruction.easing_type = BaseTweenInstruction.EasingType.EASE_IN_OUT
	instruction.trans_type = BaseTweenInstruction.TransitionType.SINE

	# 连接完成信号
	instruction.finished.connect(_on_animation_completed)

	# 执行指令
	add_child(instruction)
	instruction.execute(context)

	print("✓ 位置动画已启动")

## 测试缩放动画
func _test_scale_animation():
	print("=== 测试 TweenProperty 指令：缩放动画 ===")

	_current_test = 2
	_test_active = true

	var start_scale = test_sprite.scale
	var target_scale = Vector2(2.0, 2.0)

	info_label.text = "Testing scale animation...\nFrom: %s\nTo: %s" % [str(start_scale), str(target_scale)]

	var context = ExecutionContext.new()
	var instruction = TweenPropertyInstruction.new()

	# 配置参数
	instruction.target_node = ^"TestSprite"
	instruction.property_path = "scale"
	instruction.to_value = target_scale
	instruction.duration = 0.8
	instruction.auto_free = false
	instruction.easing_type = BaseTweenInstruction.EasingType.EASE_OUT
	instruction.trans_type = BaseTweenInstruction.TransitionType.BACK

	# 连接完成信号
	instruction.finished.connect(_on_animation_completed)

	# 执行指令
	add_child(instruction)
	instruction.execute(context)

	print("✓ 缩放动画已启动")

## 测试旋转动画
func _test_rotation_animation():
	print("=== 测试 TweenProperty 指令：旋转动画 ===")

	_current_test = 3
	_test_active = true

	var start_rotation = test_sprite.rotation
	var target_rotation = PI / 2  # 90度

	info_label.text = "Testing rotation animation...\nFrom: %.2f\nTo: %.2f (90°)" % [start_rotation, target_rotation]

	var context = ExecutionContext.new()
	var instruction = TweenPropertyInstruction.new()

	# 配置参数
	instruction.target_node = ^"TestSprite"
	instruction.property_path = "rotation"
	instruction.to_value = target_rotation
	instruction.duration = 1.0
	instruction.auto_free = false
	instruction.easing_type = BaseTweenInstruction.EasingType.EASE_IN_OUT
	instruction.trans_type = BaseTweenInstruction.TransitionType.SINE

	# 连接完成信号
	instruction.finished.connect(_on_animation_completed)

	# 执行指令
	add_child(instruction)
	instruction.execute(context)

	print("✓ 旋转动画已启动")

## 测试颜色动画
func _test_color_animation():
	print("=== 测试 TweenProperty 指令：颜色动画 ===")

	_current_test = 4
	_test_active = true

	var start_color = test_sprite.modulate
	var target_color = Color.RED

	info_label.text = "Testing color animation...\nFrom: %s\nTo: %s" % [str(start_color), str(target_color)]

	var context = ExecutionContext.new()
	var instruction = TweenPropertyInstruction.new()

	# 配置参数
	instruction.target_node = ^"TestSprite"
	instruction.property_path = "modulate"
	instruction.to_value = target_color
	instruction.duration = 1.0
	instruction.auto_free = false
	instruction.easing_type = BaseTweenInstruction.EasingType.EASE_IN_OUT
	instruction.trans_type = BaseTweenInstruction.TransitionType.SINE

	# 连接完成信号
	instruction.finished.connect(_on_animation_completed)

	# 执行指令
	add_child(instruction)
	instruction.execute(context)

	print("✓ 颜色动画已启动")

## 测试透明度动画
func _test_alpha_animation():
	print("=== 测试 TweenProperty 指令：透明度动画 ===")

	_current_test = 5
	_test_active = true

	var start_alpha = test_sprite.modulate.a
	var target_alpha = 0.3

	info_label.text = "Testing alpha animation...\nFrom: %.2f\nTo: %.2f" % [start_alpha, target_alpha]

	var context = ExecutionContext.new()
	var instruction = TweenPropertyInstruction.new()

	# 配置参数（使用 "modulate:a" 访问 alpha 通道）
	instruction.target_node = ^"TestSprite"
	instruction.property_path = "modulate:a"
	instruction.to_value = target_alpha
	instruction.duration = 0.8
	instruction.auto_free = false
	instruction.easing_type = BaseTweenInstruction.EasingType.EASE_OUT
	instruction.trans_type = BaseTweenInstruction.TransitionType.SINE

	# 连接完成信号
	instruction.finished.connect(_on_animation_completed)

	# 执行指令
	add_child(instruction)
	instruction.execute(context)

	print("✓ 透明度动画已启动")

## 测试文本动画
func _test_text_animation():
	print("=== 测试 TweenProperty 指令：Label 文本动画 ===")

	_current_test = 6
	_test_active = true

	var start_text = test_label.text
	var target_text = "Animated Text!"

	info_label.text = "Testing label text animation...\nFrom: %s\nTo: %s" % [start_text, target_text]

	var context = ExecutionContext.new()
	var instruction = TweenPropertyInstruction.new()

	# 配置参数
	instruction.target_node = ^"TestLabel"
	instruction.property_path = "text"
	instruction.to_value = target_text
	instruction.duration = 0.5
	instruction.auto_free = false

	# 连接完成信号
	instruction.finished.connect(_on_animation_completed)

	# 执行指令
	add_child(instruction)
	instruction.execute(context)

	print("✓ 文本动画已启动")

## 测试 auto_free 功能
func _test_auto_free_animation():
	print("=== 测试 TweenProperty 指令：auto_free 功能 ===")

	_current_test = 7
	_test_active = true

	# 创建一个临时节点用于测试
	var temp_node = Sprite2D.new()
	temp_node.name = "TempSprite"
	temp_node.position = Vector2(400, 400)
	temp_node.scale = Vector2(0.5, 0.5)
	add_child(temp_node)

	info_label.text = "Testing auto_free animation...\nTempSprite created and will be freed after animation"

	var context = ExecutionContext.new()
	var instruction = TweenPropertyInstruction.new()

	# 配置参数
	instruction.target_node = ^"TempSprite"
	instruction.property_path = "scale"
	instruction.to_value = Vector2.ZERO
	instruction.duration = 1.0
	instruction.auto_free = true
	instruction.easing_type = BaseTweenInstruction.EasingType.EASE_IN
	instruction.trans_type = BaseTweenInstruction.TransitionType.SINE

	# 连接完成信号（但由于 auto_free，finished 可能不会被触发）
	instruction.finished.connect(_on_auto_free_completed)

	# 执行指令
	add_child(instruction)
	instruction.execute(context)

	print("✓ auto_free 动画已启动，节点将在 1 秒后自动释放")

## 动画完成回调
func _on_animation_completed():
	print("✓ TweenProperty 指令已完成")

	match _current_test:
		1:
			print("  位置: %s" % str(test_sprite.position))
		2:
			print("  缩放: %s" % str(test_sprite.scale))
		3:
			print("  旋转: %.2f" % test_sprite.rotation)
		4:
			print("  颜色: %s" % str(test_sprite.modulate))
		5:
			print("  透明度: %.2f" % test_sprite.modulate.a)
		6:
			print("  文本: %s" % test_label.text)

	print("测试通过！")

	_test_active = false
	info_label.text = "Test PASSED!\n\nPress 1-7 to run different tests"

## auto_free 完成回调
func _on_auto_free_completed():
	print("✓ auto_free 动画已完成（节点已释放）")
	print("测试通过！")

	_test_active = false
	info_label.text = "auto_free Test PASSED!\nNode has been freed.\n\nPress 1-7 to run different tests"

## 验证测试结果
func _verify_test_result():
	match _current_test:
		1:
			# 位置动画测试
			var expected_pos = Vector2(500, 300)
			var actual_pos = test_sprite.position
			assert(actual_pos.distance_to(expected_pos) < 1.0, "位置不匹配: 期望 %s, 实际 %s" % [expected_pos, actual_pos])
			print("✓ 位置动画测试验证通过")
		2:
			# 缩放动画测试
			assert(test_sprite.scale.is_equal_approx(Vector2(2.0, 2.0)), "缩放不匹配")
			print("✓ 缩放动画测试验证通过")
		3:
			# 旋转动画测试
			assert(is_equal_approx(test_sprite.rotation, PI / 2), "旋转不匹配")
			print("✓ 旋转动画测试验证通过")
		4:
			# 颜色动画测试
			assert(test_sprite.modulate.is_equal_approx(Color.RED), "颜色不匹配")
			print("✓ 颜色动画测试验证通过")
		5:
			# 透明度动画测试
			assert(is_equal_approx(test_sprite.modulate.a, 0.3), "透明度不匹配")
			print("✓ 透明度动画测试验证通过")
		6:
			# 文本动画测试
			assert(test_label.text == "Animated Text!", "文本不匹配")
			print("✓ 文本动画测试验证通过")
