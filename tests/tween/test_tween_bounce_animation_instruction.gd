extends Node2D

## Tween Bounce Animation 指令测试

func _ready():
	print("=== Tween Bounce Animation 指令测试场景已加载 ===")
	print("按 SPACE 键开始测试")

func _input(event):
	if event.is_action_pressed("ui_accept"):
		_test_bounce_animation()

func _test_bounce_animation():
	print("\n=== 测试 Tween Bounce Animation 指令 ===")

	# 创建执行上下文
	var context = ExecutionContext.new()
	add_child(context)

	# 创建指令
	var instruction = TweenBounceAnimation.new()

	# 配置参数
	instruction.target_node = ^"TestSprite"
	instruction.bounce_height = 100.0
	instruction.bounce_count = 3
	instruction.duration = 0.8

	# 连接完成信号
	instruction.finished.connect(_on_bounce_animation_completed.bind(instruction))

	# 执行指令
	print("✓ 指令已配置:")
	print("  - 目标节点: TestSprite")
	print("  - 弹跳高度: 100.0")
	print("  - 弹跳次数: 3")
	print("  - 持续时间: 0.8s")
	print("  - 弹跳效果: TRANS_BOUNCE + EASE_OUT")
	print("\n开始执行弹跳动画...")

	instruction.execute(context)

func _on_bounce_animation_completed(instruction: TweenBounceAnimation):
	print("\n✓ Tween Bounce Animation 指令已完成")
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
		test_rect.position = Vector2(300, 300)
		print("\n场景已重置，可以再次按 SPACE 测试")
