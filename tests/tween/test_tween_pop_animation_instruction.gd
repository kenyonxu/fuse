extends Node2D

## Tween Pop Animation 指令测试

func _ready():
	print("=== Tween Pop Animation 指令测试场景已加载 ===")
	print("按 SPACE 键开始测试")

func _input(event):
	if event.is_action_pressed("ui_accept"):
		_test_pop_animation()

func _test_pop_animation():
	print("\n=== 测试 Tween Pop Animation 指令 ===")

	# 创建执行上下文
	var context = ExecutionContext.new()
	add_child(context)

	# 创建指令
	var instruction = TweenPopAnimation.new()

	# 配置参数
	instruction.target_node = ^"TestSprite"
	instruction.target_scale = Vector2.ONE
	instruction.duration = 0.6

	# 连接完成信号
	instruction.finished.connect(_on_pop_animation_completed.bind(instruction))

	# 执行指令
	print("✓ 指令已配置:")
	print("  - 目标节点: TestSprite")
	print("  - 目标缩放: (1, 1)")
	print("  - 持续时间: 0.6s")
	print("  - 弹簧效果: TRANS_SPRING + EASE_OUT")
	print("\n开始执行弹出动画（从缩放 0 开始）...")

	instruction.execute(context)

func _on_pop_animation_completed(instruction: TweenPopAnimation):
	print("\n✓ Tween Pop Animation 指令已完成")
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
		test_rect.scale = Vector2.ZERO
		print("\n场景已重置，可以再次按 SPACE 测试")
