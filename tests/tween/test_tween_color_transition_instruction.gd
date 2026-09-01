extends Node2D

## Tween Color Transition 指令测试

func _ready():
	print("=== Tween Color Transition 指令测试场景已加载 ===")
	print("按 SPACE 键开始测试")

func _input(event):
	if event.is_action_pressed("ui_accept"):
		_test_color_transition()

func _test_color_transition():
	print("\n=== 测试 Tween Color Transition 指令 ===")

	# 创建执行上下文
	var context = ExecutionContext.new()
	add_child(context)

	# 创建指令
	var instruction = TweenColorTransition.new()

	# 配置参数
	instruction.target_node = ^"TestSprite"
	instruction.target_color = Color.RED
	instruction.duration = 1.5
	instruction.easing_type = BaseTweenInstruction.EasingType.EASE_IN_OUT
	instruction.trans_type = BaseTweenInstruction.TransitionType.SINE

	# 连接完成信号
	instruction.finished.connect(_on_color_transition_completed.bind(instruction))

	# 执行指令
	print("✓ 指令已配置:")
	print("  - 目标节点: TestSprite")
	print("  - 目标颜色: RED (1, 0, 0)")
	print("  - 持续时间: 1.5s")
	print("  - 缓动类型: EASE_IN_OUT")
	print("  - 过渡类型: TRANS_SINE")
	print("\n开始执行颜色过渡动画...")

	instruction.execute(context)

func _on_color_transition_completed(instruction: TweenColorTransition):
	print("\n✓ Tween Color Transition 指令已完成")
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
		test_rect.modulate = Color.WHITE
		print("\n场景已重置，可以再次按 SPACE 测试")
