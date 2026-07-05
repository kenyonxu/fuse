extends Node

## AudioManager 节点测试脚本
##
## 测试 AudioManager 的场景级配置功能

func _ready():
	print("=== AudioManager Node Tests ===")
	run_all_tests()

func run_all_tests():
	"""运行所有测试"""
	test_basic_initialization()
	test_apply_global_config()
	test_get_audio_handler()

	print("\n=== All AudioManager Tests Completed ===")

# =============================================================================
# 测试 1: 基本初始化
# =============================================================================

func test_basic_initialization():
	"""测试 AudioManager 的基本初始化"""
	print("\n[Test 1] Basic Initialization")

	# 创建 AudioManager
	var manager = AudioManager.new()
	manager.name = "TestAudioManager"

	# 添加为子节点（触发 _ready）
	add_child(manager)
	await get_tree().process_frame

	# 验证节点在 "audio_manager" 组中
	assert(manager.is_in_group("audio_manager"), "Manager should be in 'audio_manager' group")
	print("✓ Manager is in 'audio_manager' group")

	# 验证 _audio_handler 已创建
	assert(manager._audio_handler != null, "Audio handler should be created")
	print("✓ Audio handler created")

	# 验证 handler 是 JuicyAudioEventHandler 实例
	assert(manager._audio_handler is JuicyAudioEventHandler, "Handler should be JuicyAudioEventHandler")
	print("✓ Handler is JuicyAudioEventHandler instance")

	# 清理
	manager.queue_free()
	await get_tree().process_frame

	print("[Test 1] PASSED\n")

# =============================================================================
# 测试 2: 应用全局配置
# =============================================================================

func test_apply_global_config():
	"""测试应用全局配置"""
	print("\n[Test 2] Apply Global Config")

	# 创建 GlobalAudioLimitConfig
	var global_config = GlobalAudioLimitConfig.new()
	global_config.max_total_voices = 32
	global_config.max_virtual_voices = 64

	print("Created global config with max_total_voices: ", global_config.max_total_voices)

	# 创建 AudioManager 并设置配置
	var manager = AudioManager.new()
	manager.name = "TestAudioManager_GlobalConfig"
	manager.global_limit_config = global_config

	# 添加为子节点（触发 _ready）
	add_child(manager)
	await get_tree().process_frame

	# 验证 handler 的全局配置已设置
	var handler_config = manager.get_audio_handler().get_global_config()
	assert(handler_config != null, "Handler should have global config")
	assert(handler_config.max_total_voices == 32, "Max total voices should be 32")
	print("✓ Handler global config applied (max_total_voices: ", handler_config.max_total_voices, ")")

	# 清理
	manager.queue_free()
	await get_tree().process_frame

	print("[Test 2] PASSED\n")

# =============================================================================
# 测试 3: 获取音频处理器
# =============================================================================

func test_get_audio_handler():
	"""测试获取音频处理器"""
	print("\n[Test 3] Get Audio Handler")

	# 创建 AudioManager
	var manager = AudioManager.new()
	manager.name = "TestAudioManager_GetHandler"

	# 添加为子节点
	add_child(manager)
	await get_tree().process_frame

	# 调用 get_audio_handler()
	var handler = manager.get_audio_handler()

	# 验证 handler 不为 null
	assert(handler != null, "Handler should not be null")
	print("✓ Handler is not null")

	# 验证 handler 类型
	assert(handler is JuicyAudioEventHandler, "Handler should be JuicyAudioEventHandler")
	print("✓ Handler is JuicyAudioEventHandler")

	# 清理
	manager.queue_free()
	await get_tree().process_frame

	print("[Test 3] PASSED\n")
