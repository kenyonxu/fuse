extends Node2D

## Tween Move To 指令测试

func _ready():
	print("=== Tween Move To 指令测试场景已加载 ===")
	print("按 SPACE 键开始全局坐标测试")
	print("按 1 键开始本地坐标测试")

func _input(event):
	if event.is_action_pressed("ui_accept"):
		_test_move_to_global()
	elif event.is_action_pressed("ui_text_backspace"):
		_test_move_to_local()

func _test_move_to_global():
	print("\n=== 测试 Tween Move To 指令（全局坐标） ===")

	# 创建执行上下文
	var context = ExecutionContext.new()
	add_child(context)

	# 创建指令
	var instruction = TweenMoveTo.new()

	# 配置参数
	instruction.target_node = ^"TestSprite"
	instruction.target_position = Vector2(400, 300)
	instruction.duration = 1.0
	instruction.space_mode = TweenMoveTo.SpaceMode.GLOBAL
	instruction.easing_type = BaseTweenInstruction.EasingType.EASE_IN_OUT
	instruction.trans_type = BaseTweenInstruction.TransitionType.SINE

	# 连接完成信号
	instruction.finished.connect(_on_move_to_completed.bind(instruction))

	# 执行指令
	print("✓ 指令已配置:")
	print("  - 目标节点: TestSprite")
	print("  - 目标位置: (400, 300)")
	print("  - 坐标空间: 全局坐标")
	print("  - 持续时间: 1.0s")
	print("  - 缓动类型: EASE_IN_OUT")
	print("  - 过渡类型: TRANS_SINE")
	print("\n开始执行移动动画...")

	instruction.execute(context)

func _test_move_to_local():
	print("\n=== 测试 Tween Move To 指令（本地坐标） ===")

	# 创建执行上下文
	var context = ExecutionContext.new()
	add_child(context)

	# 创建指令
	var instruction = TweenMoveTo.new()

	# 配置参数
	instruction.target_node = ^"TestSprite"
	instruction.target_position = Vector2(100, 100)
	instruction.duration = 1.0
	instruction.space_mode = TweenMoveTo.SpaceMode.LOCAL
	instruction.easing_type = BaseTweenInstruction.EasingType.EASE_OUT
	instruction.trans_type = BaseTweenInstruction.TransitionType.BACK

	# 连接完成信号
	instruction.finished.connect(_on_move_to_completed.bind(instruction))

	# 执行指令
	print("✓ 指令已配置:")
	print("  - 目标节点: TestSprite")
	print("  - 目标位置: (100, 100)")
	print("  - 坐标空间: 本地坐标")
	print("  - 持续时间: 1.0s")
	print("  - 缓动类型: EASE_OUT")
	print("  - 过渡类型: TRANS_BACK")
	print("\n开始执行移动动画...")

	instruction.execute(context)

func _on_move_to_completed(instruction: TweenMoveTo):
	print("\n✓ Tween Move To 指令已完成")
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
		test_rect.position = Vector2(50, 50)
		print("\n场景已重置，可以再次按键测试")
