extends Node2D

## Tween Fade Out 指令测试

var _test_count: int = 0

func _ready():
	print("=== Testing Tween Fade Out Instruction ===")
	print("Press SPACE to test fade out without auto_free")
	print("Press ENTER to test fade out with auto_free")

func _input(event):
	if event.is_action_pressed("ui_accept"):
		_test_fade_out_without_auto_free()
	elif event.is_action_pressed("ui_text_newline"):
		_test_fade_out_with_auto_free()

func _test_fade_out_without_auto_free():
	print("\n--- Test 1: Fade Out Without Auto Free ---")

	# 确保测试节点存在
	var test_sprite = $TestSprite
	if not test_sprite:
		print("❌ Test sprite not found!")
		return

	# 重置透明度
	test_sprite.modulate.a = 1.0
	print("✓ Test sprite alpha reset to 1.0")

	# 创建指令
	var instruction = TweenFadeOut.new()
	instruction.target_node = NodePath("../TestSprite")
	instruction.duration = 1.0
	instruction.auto_free = false
	instruction.easing_type = BaseTweenInstruction.EasingType.EASE_IN

	# 创建执行上下文
	var context = ExecutionContext.new()
	add_child(context)

	# 连接完成信号
	instruction.finished.connect(_on_fade_out_without_auto_free_completed.bind(instruction, test_sprite))

	# 执行指令
	add_child(instruction)
	instruction.execute(context)

	print("✓ Tween Fade Out instruction started (auto_free=false)")
	print("  Expected: Sprite fades to alpha 0.0 and remains in scene")

func _on_fade_out_without_auto_free_completed(instruction: TweenFadeOut, sprite: Sprite2D):
	print("\n✓ Fade Out completed")

	# 验证透明度
	var alpha = sprite.modulate.a
	print("  Final alpha: %.3f" % alpha)

	if abs(alpha - 0.0) < 0.01:
		print("  ✓ Alpha correctly faded to 0.0")
	else:
		print("  ❌ Alpha not correct (expected 0.0, got %.3f)" % alpha)

	# 验证节点仍然存在
	if is_instance_valid(sprite):
		print("  ✓ Sprite still exists in scene (auto_free=false)")
	else:
		print("  ❌ Sprite was freed (should not be freed)")

	# 清理
	instruction.queue_free()

	_test_count += 1
	print("\nTest 1 passed!")

func _test_fade_out_with_auto_free():
	print("\n--- Test 2: Fade Out With Auto Free ---")

	# 确保测试节点存在
	var test_sprite = $TestSpriteAutoFree
	if not test_sprite:
		print("❌ Test sprite (auto_free) not found!")
		return

	# 重置透明度
	test_sprite.modulate.a = 1.0
	print("✓ Test sprite (auto_free) alpha reset to 1.0")

	# 创建指令
	var instruction = TweenFadeOut.new()
	instruction.target_node = NodePath("../TestSpriteAutoFree")
	instruction.duration = 1.0
	instruction.auto_free = true
	instruction.easing_type = BaseTweenInstruction.EasingType.EASE_IN

	# 创建执行上下文
	var context = ExecutionContext.new()
	add_child(context)

	# 保存节点引用用于验证
	_auto_free_test_sprite = test_sprite

	# 连接完成信号
	instruction.finished.connect(_on_fade_out_with_auto_free_completed.bind(instruction))

	# 执行指令
	add_child(instruction)
	instruction.execute(context)

	print("✓ Tween Fade Out instruction started (auto_free=true)")
	print("  Expected: Sprite fades to alpha 0.0 and is freed from scene")

var _auto_free_test_sprite: Sprite2D = null

func _on_fade_out_with_auto_free_completed(instruction: TweenFadeOut):
	print("\n✓ Fade Out completed")

	# 等待一帧后验证节点已被释放
	await get_tree().process_frame

	if not is_instance_valid(_auto_free_test_sprite):
		print("  ✓ Sprite was successfully freed (auto_free=true)")
	else:
		print("  ❌ Sprite still exists (should have been freed)")

	# 清理
	instruction.queue_free()

	_test_count += 1
	print("\nTest 2 passed!")

	# 总结
	print("\n=== All Tween Fade Out Tests Passed! ===")
	print("Total tests: %d" % _test_count)

func _process(delta):
	# 如果 auto_free 测试节点不存在，重新创建
	if not is_instance_valid($TestSpriteAutoFree):
		var new_sprite = Sprite2D.new()
		new_sprite.name = "TestSpriteAutoFree"
		new_sprite.modulate = Color(1, 1, 1, 1)
		new_sprite.position = Vector2(300, 100)
		add_child(new_sprite)
		print("  [AUTO_FREE] Test sprite recreated for next test")
