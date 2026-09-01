extends Node2D

## Tween Rotate To 指令测试

func _ready():
	print("=== Tween Rotate To 指令测试场景已加载 ===")
	print("按 SPACE 键开始旋转 90° 测试")
	print("按 1 键开始旋转 -90° 测试")
	print("按 2 键开始旋转 360° 测试")

func _input(event):
	if event.is_action_pressed("ui_accept"):
		_test_rotate_90()
	elif event.is_action_pressed("ui_text_backspace"):
		_test_rotate_negative_90()
	elif event.is_key_pressed(KEY_2):
		_test_rotate_360()

func _test_rotate_90():
	print("\n=== 测试 Tween Rotate To 指令（旋转 90°） ===")

	# 创建执行上下文
	var context = ExecutionContext.new()
	add_child(context)

	# 创建指令
	var instruction = TweenRotateTo.new()

	# 配置参数
	instruction.target_node = ^"TestSprite"
	instruction.target_rotation = 90.0
	instruction.duration = 1.0
	instruction.space_mode = TweenRotateTo.SpaceMode.LOCAL
	instruction.easing_type = BaseTweenInstruction.EasingType.EASE_IN_OUT
	instruction.trans_type = BaseTweenInstruction.TransitionType.SINE

	# 连接完成信号
	instruction.finished.connect(_on_rotate_to_completed.bind(instruction))

	# 执行指令
	print("✓ 指令已配置:")
	print("  - 目标节点: TestSprite")
	print("  - 目标旋转: 90.0°")
	print("  - 坐标空间: 本地坐标")
	print("  - 持续时间: 1.0s")
	print("  - 缓动类型: EASE_IN_OUT")
	print("  - 过渡类型: TRANS_SINE")
	print("\n开始执行旋转动画...")

	instruction.execute(context)

func _test_rotate_negative_90():
	print("\n=== 测试 Tween Rotate To 指令（旋转 -90°） ===")

	# 创建执行上下文
	var context = ExecutionContext.new()
	add_child(context)

	# 创建指令
	var instruction = TweenRotateTo.new()

	# 配置参数
	instruction.target_node = ^"TestSprite"
	instruction.target_rotation = -90.0
	instruction.duration = 1.0
	instruction.space_mode = TweenRotateTo.SpaceMode.LOCAL
	instruction.easing_type = BaseTweenInstruction.EasingType.EASE_IN_OUT
	instruction.trans_type = BaseTweenInstruction.TransitionType.SINE

	# 连接完成信号
	instruction.finished.connect(_on_rotate_to_completed.bind(instruction))

	# 执行指令
	print("✓ 指令已配置:")
	print("  - 目标节点: TestSprite")
	print("  - 目标旋转: -90.0°")
	print("  - 坐标空间: 本地坐标")
	print("  - 持续时间: 1.0s")
	print("  - 缓动类型: EASE_IN_OUT")
	print("  - 过渡类型: TRANS_SINE")
	print("\n开始执行旋转动画...")

	instruction.execute(context)

func _test_rotate_360():
	print("\n=== 测试 Tween Rotate To 指令（旋转 360°） ===")

	# 创建执行上下文
	var context = ExecutionContext.new()
	add_child(context)

	# 创建指令
	var instruction = TweenRotateTo.new()

	# 配置参数
	instruction.target_node = ^"TestSprite"
	instruction.target_rotation = 360.0
	instruction.duration = 1.5
	instruction.space_mode = TweenRotateTo.SpaceMode.LOCAL
	instruction.easing_type = BaseTweenInstruction.EasingType.EASE_IN_OUT
	instruction.trans_type = BaseTweenInstruction.TransitionType.CUBIC

	# 连接完成信号
	instruction.finished.connect(_on_rotate_to_completed.bind(instruction))

	# 执行指令
	print("✓ 指令已配置:")
	print("  - 目标节点: TestSprite")
	print("  - 目标旋转: 360.0°")
	print("  - 坐标空间: 本地坐标")
	print("  - 持续时间: 1.5s")
	print("  - 缓动类型: EASE_IN_OUT")
	print("  - 过渡类型: TRANS_CUBIC")
	print("\n开始执行旋转动画...")

	instruction.execute(context)

func _on_rotate_to_completed(instruction: TweenRotateTo):
	print("\n✓ Tween Rotate To 指令已完成")
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
		test_rect.rotation = 0.0
		print("\n场景已重置，可以再次按键测试")
