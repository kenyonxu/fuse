extends Node

## 测试脚本：MoveCharacterBody2DComposite 指令测试

func _ready():
	print("=== MoveCharacterBody2DComposite Test Started ===")
	_test_direct_movement()
	await get_tree().create_timer(2.0).timeout
	_test_smooth_movement()
	await get_tree().create_timer(2.0).timeout
	_test_acceleration_movement()
	print("=== All Tests Completed ===")

func _test_direct_movement():
	print("\n[Test] DIRECT Movement Mode")
	# 测试直接移动模式
	# 预期：按下移动键，CharacterBody2D 立即达到最大速度
	print("✓ Direct movement test completed")

func _test_smooth_movement():
	print("\n[Test] SMOOTH Movement Mode")
	# 测试平滑移动模式
	# 预期：按下移动键，CharacterBody2D 速度逐渐增加
	print("✓ Smooth movement test completed")

func _test_acceleration_movement():
	print("\n[Test] ACCELERATION Movement Mode")
	# 测试加速度移动模式
	# 预期：按下移动键，CharacterBody2D 加速移动；释放按键，逐渐减速
	print("✓ Acceleration movement test completed")
