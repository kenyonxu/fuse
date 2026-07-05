extends Node2D

## Tween Scale To 指令测试

func _ready():
	print("=== Tween Scale To 指令测试场景已加载 ===")
	print("按 SPACE 键开始放大测试")
	print("按 1 键开始缩小测试")

func _input(event):
	if event.is_action_pressed("ui_accept"):
		_test_scale_up()
	elif event.is_action_pressed("ui_text_backspace"):
		_test_scale_down()

func _test_scale_up():
	print("\n=== 测试 Tween Scale To 指令（放大） ===")

	# 创建执行上下文
	var context = ExecutionContext.new()
	add_child(context)

	# 创建指令
	var instruction = TweenScaleTo.new()

	# 配置参数
	instruction.target_node = ^"TestSprite"
	instruction.target_scale = Vector2(2.0, 2.0)
	instruction.duration = 0.8
	instruction.easing_type = BaseTweenInstruction.EasingType.EASE_OUT
	instruction.trans_type = BaseTweenInstruction.TransitionType.BACK

	# 连接完成信号
	instruction.finished.connect(_on_scale_to_completed.bind(instruction))

	# 执行指令
	print("✓ 指令已配置:")
	print("  - 目标节点: TestSprite")
	print("  - 目标缩放: (2.0, 2.0)")
	print("  - 持续时间: 0.8s")
	print("  - 缓动类型: EASE_OUT")
	print("  - 过渡类型: TRANS_BACK")
	print("\n开始执行缩放动画...")

	instruction.execute(context)

func _test_scale_down():
	print("\n=== 测试 Tween Scale To 指令（缩小） ===")

	# 创建执行上下文
	var context = ExecutionContext.new()
	add_child(context)

	# 创建指令
	var instruction = TweenScaleTo.new()

	# 配置参数
	instruction.target_node = ^"TestSprite"
	instruction.target_scale = Vector2(0.5, 0.5)
	instruction.duration = 0.8
	instruction.easing_type = BaseTweenInstruction.EasingType.EASE_IN
	instruction.trans_type = BaseTweenInstruction.TransitionType.BACK

	# 连接完成信号
	instruction.finished.connect(_on_scale_to_completed.bind(instruction))

	# 执行指令
	print("✓ 指令已配置:")
	print("  - 目标节点: TestSprite")
	print("  - 目标缩放: (0.5, 0.5)")
	print("  - 持续时间: 0.8s")
	print("  - 缓动类型: EASE_IN")
	print("  - 过渡类型: TRANS_BACK")
	print("\n开始执行缩放动画...")

	instruction.execute(context)

func _on_scale_to_completed(instruction: TweenScaleTo):
	print("\n✓ Tween Scale To 指令已完成")
	print("✓ 测试通过！")

	# 清理指令
	if instruction.get_parent():
		instruction.get_parent().remove_child(instruction)
	instruction.queue_free()

	# 延迟后重置场景
	await get_tree().create_timer(2.0).timeout
	_reset_sprite()

func _reset_sprite():
	var test_rect = $TestSprite
	if test_rect:
		test_rect.scale = Vector2.ONE
		print("\n场景已重置，可以再次按键测试")
