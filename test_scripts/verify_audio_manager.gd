extends Node

## AudioManager 验证脚本
##
## 这个脚本验证 AudioManager 的基本功能
## 将此脚本附加到场景的根节点，然后在编辑器中运行场景

func _ready():
	print("\n========== AudioManager Verification ==========\n")

	# 验证 1: AudioManager 类是否注册
	print("[Verify 1] Checking AudioManager class...")
	if ClassDB.class_exists("AudioManager"):
		print("✓ AudioManager class is registered in ClassDB")
	else:
		# 检查是否作为全局类可用
		var manager = AudioManager.new()
		if manager:
			print("✓ AudioManager can be instantiated as global class")
			manager.queue_free()
		else:
			print("✗ FAILED: AudioManager cannot be instantiated")

	# 验证 2: 创建 AudioManager 并测试基本功能
	print("\n[Verify 2] Creating AudioManager instance...")
	var manager = AudioManager.new()
	manager.name = "VerificationManager"
	add_child(manager)
	await get_tree().process_frame

	# 检查组
	if manager.is_in_group("audio_manager"):
		print("✓ Manager is in 'audio_manager' group")
	else:
		print("✗ FAILED: Manager not in 'audio_manager' group")

	# 检查处理器
	if manager._audio_handler != null:
		print("✓ Audio handler created")
	else:
		print("✗ FAILED: Audio handler is null")

	# 检查 get_audio_handler()
	var handler = manager.get_audio_handler()
	if handler != null and handler is JuicyAudioEventHandler:
		print("✓ get_audio_handler() works correctly")
	else:
		print("✗ FAILED: get_audio_handler() returned null or wrong type")

	# 验证 3: 测试全局配置
	print("\n[Verify 3] Testing global config...")
	var global_config = GlobalAudioLimitConfig.new()
	global_config.max_total_voices = 32
	manager.global_limit_config = global_config

	var retrieved_config = manager.get_audio_handler().get_global_config()
	if retrieved_config != null and retrieved_config.max_total_voices == 32:
		print("✓ Global config applied (max_total_voices: ", retrieved_config.max_total_voices, ")")
	else:
		print("✗ FAILED: Global config not applied correctly")

	# 验证 4: 测试 JuicyAudioPlayer 集成
	print("\n[Verify 4] Testing JuicyAudioPlayer integration...")
	var player = JuicyAudioPlayer.new()
	player.name = "TestPlayer"
	add_child(player)
	await get_tree().process_frame

	# JuicyAudioPlayer 应该能找到我们的 AudioManager
	var player_handler = player.get_audio_handler()
	if player_handler == handler:
		print("✓ JuicyAudioPlayer found AudioManager's handler")
	else:
		print("✗ FAILED: JuicyAudioPlayer did not find AudioManager's handler")

	# 清理
	player.queue_free()
	manager.queue_free()
	await get_tree().process_frame

	print("\n========== Verification Complete ==========\n")
