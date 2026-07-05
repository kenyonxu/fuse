extends Node2D

## Tween Shake Animation 指令测试

func _ready():
	print("=== Tween Shake Animation 指令测试场景已加载 ===")
	print("按 SPACE 键测试 XY 震动")
	print("按 1 键测试 X 震动")
	print("按 2 键测试 Y 震动")

func _input(event):
	if event.is_action_pressed("ui_accept"):
		_test_shake_animation(TweenShakeAnimation.ShakeAxis.XY, "XY")
	elif event.is_key_pressed(KEY_1):
		_test_shake_animation(TweenShakeAnimation.ShakeAxis.X, "X")
	elif event.is_key_pressed(KEY_2):
		_test_shake_animation(TweenShakeAnimation.ShakeAxis.Y, "Y")

func _test_shake_animation(axis: TweenShakeAnimation.ShakeAxis, axis_name: String):
	print("\n=== 测试 Tween Shake Animation 指令 (%s轴) ===" % axis_name)

	# 创建执行上下文
	var context = ExecutionContext.new()
	add_child(context)

	# 创建指令
	var instruction = TweenShakeAnimation.new()

	# 配置参数
	instruction.target_node = ^"TestSprite"
	instruction.intensity = 15.0
	instruction.duration = 0.4
	instruction.shake_count = 3
	instruction.shake_axis = axis

	# 连接完成信号
	instruction.finished.connect(_on_shake_animation_completed.bind(instruction, axis_name))

	# 执行指令
	print("✓ 指令已配置:")
	print("  - 目标节点: TestSprite")
	print("  - 震动强度: 15.0")
	print("  - 持续时间: 0.4s")
	print("  - 震动次数: 3")
	print("  - 震动轴向: %s" % axis_name)
	print("\n开始执行震动动画...")

	instruction.execute(context)

func _on_shake_animation_completed(instruction: TweenShakeAnimation, axis_name: String):
	print("\n✓ Tween Shake Animation 指令已完成 (%s轴)" % axis_name)
	print("✓ 测试通过！")

	# 清理指令
	if instruction.get_parent():
		instruction.get_parent().remove_child(instruction)
	instruction.queue_free()

	# 提示可以继续测试
	print("\n可以按 SPACE/1/2 继续测试其他轴向")
