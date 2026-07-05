extends Node

## AudioManager 快速测试脚本
##
## 在编辑器中运行此脚本以测试 AudioManager 功能

func _ready():
	print("=== AudioManager Quick Test ===")

	# 测试 1: 创建 AudioManager 并验证初始化
	print("\n[Test 1] Creating AudioManager...")
	var manager = AudioManager.new()
	manager.name = "TestManager"
	add_child(manager)
	await get_tree().process_frame

	if manager.is_in_group("audio_manager"):
		print("✓ Manager is in 'audio_manager' group")
	else:
		print("✗ FAILED: Manager not in 'audio_manager' group")

	if manager._audio_handler != null:
		print("✓ Audio handler created")
	else:
		print("✗ FAILED: Audio handler is null")

	# 测试 2: 测试全局配置
	print("\n[Test 2] Testing global config...")
	var global_config = GlobalAudioLimitConfig.new()
	global_config.max_total_voices = 32
	manager.global_limit_config = global_config

	var handler_config = manager.get_audio_handler().get_global_config()
	if handler_config != null and handler_config.max_total_voices == 32:
		print("✓ Global config applied correctly")
	else:
		print("✗ FAILED: Global config not applied")

	# 测试 3: 测试 get_audio_handler()
	print("\n[Test 3] Testing get_audio_handler()...")
	var handler = manager.get_audio_handler()
	if handler != null and handler is JuicyAudioEventHandler:
		print("✓ get_audio_handler() returns correct type")
	else:
		print("✗ FAILED: get_audio_handler() returned null or wrong type")

	# 清理
	print("\nCleaning up...")
	manager.queue_free()
	await get_tree().process_frame

	print("\n=== AudioManager Quick Test Completed ===")
