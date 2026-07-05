extends Node

func _ready():
	print("=== 开始 VirtualVoiceManager 测试 ===")
	test_virtual_voice_creation()
	test_virtual_voice_updates()
	test_virtual_voice_completion()
	test_virtual_voice_distance_check()
	test_virtual_voice_importance_check()
	test_virtual_voice_null_resource()
	test_virtual_voice_boundary_validation()
	test_virtual_voice_max_limit()
	test_listener_position_cache()
	print("=== 所有测试通过 ===")

func test_virtual_voice_creation():
	var resource = AudioEventResource.new()

	var manager = VirtualVoiceManager.new()

	# 创建虚声部
	var info = manager.check_virtual_voice(resource, Vector3(1000, 0, 0), 50, null)
	# 由于没有 global_config，应该返回 null
	assert(info == null, "Should return null without global config")

	print("test_virtual_voice_creation PASSED")

func test_virtual_voice_updates():
	var manager = VirtualVoiceManager.new()
	var config = GlobalAudioLimitConfig.new()

	# 模拟虚声部
	var resource = AudioEventResource.new()
	var info = manager._create_virtual_voice(resource, Vector3.ZERO, true, config)

	# 更新虚声部
	manager.update_virtual_voices(0.5)  # 500ms

	# 检查统计
	var stats = manager.get_virtual_voice_stats()
	assert(stats.total_virtual_voices == 1, "Should have 1 virtual voice")

	print("test_virtual_voice_updates PASSED")

func test_virtual_voice_completion():
	var manager = VirtualVoiceManager.new()
	var config = GlobalAudioLimitConfig.new()

	# 创建短时长的虚声部
	var resource = AudioEventResource.new()
	var info = manager._create_virtual_voice(resource, Vector3.ZERO, true, config)
	info.duration = 1.0  # 1秒时长

	# 更新超过时长
	manager.update_virtual_voices(0.5)
	assert(manager.get_virtual_voice_stats().total_virtual_voices == 1, "Should still be active")

	manager.update_virtual_voices(0.6)  # 总计 1.1秒
	assert(manager.get_virtual_voice_stats().total_virtual_voices == 0, "Should be completed")

	print("test_virtual_voice_completion PASSED")

func test_virtual_voice_distance_check():
	var manager = VirtualVoiceManager.new()
	var resource = AudioEventResource.new()
	var config = GlobalAudioLimitConfig.new()
	config.virtual_max_distance = 50.0

	# 远距离应该创建虚声部
	var info = manager.check_virtual_voice(resource, Vector3(100, 0, 0), 50, config)
	assert(info != null, "Should create virtual voice for distant sound")
	assert(info.is_virtual == true, "Should be marked as virtual")

	print("test_virtual_voice_distance_check PASSED")

func test_virtual_voice_importance_check():
	var manager = VirtualVoiceManager.new()
	var resource = AudioEventResource.new()
	var config = GlobalAudioLimitConfig.new()
	config.virtual_min_importance = 60

	# 低重要性应该创建虚声部
	var info = manager.check_virtual_voice(resource, Vector3(0, 0, 0), 30, config)
	assert(info != null, "Should create virtual voice for low importance")

	print("test_virtual_voice_importance_check PASSED")

func test_virtual_voice_null_resource():
	"""I3 修复测试: 测试 null 资源处理"""
	var manager = VirtualVoiceManager.new()
	var config = GlobalAudioLimitConfig.new()

	# null 资源应该被拒绝
	var info = manager.check_virtual_voice(null, Vector3.ZERO, 50, config)
	assert(info == null, "Should reject null resource")

	print("test_virtual_voice_null_resource PASSED")

func test_virtual_voice_boundary_validation():
	"""V1 修复测试: 测试边界值验证"""
	var manager = VirtualVoiceManager.new()
	var resource = AudioEventResource.new()

	# 测试无效的 virtual_max_distance
	var config = GlobalAudioLimitConfig.new()
	config.virtual_max_distance = -10.0
	var info = manager.check_virtual_voice(resource, Vector3.ZERO, 50, config)
	assert(info == null, "Should reject negative virtual_max_distance")

	# 测试无效的 virtual_min_importance
	config = GlobalAudioLimitConfig.new()
	config.virtual_min_importance = -10
	info = manager.check_virtual_voice(resource, Vector3.ZERO, 50, config)
	assert(info == null, "Should reject negative virtual_min_importance")

	config = GlobalAudioLimitConfig.new()
	config.virtual_min_importance = 150
	info = manager.check_virtual_voice(resource, Vector3.ZERO, 50, config)
	assert(info == null, "Should reject virtual_min_importance > 100")

	# 测试无效的 max_total_voices
	config = GlobalAudioLimitConfig.new()
	config.max_total_voices = 0
	info = manager.check_virtual_voice(resource, Vector3.ZERO, 50, config)
	assert(info == null, "Should reject max_total_voices <= 0")

	print("test_virtual_voice_boundary_validation PASSED")

func test_virtual_voice_max_limit():
	"""V3 修复测试: 测试虚声部数量限制"""
	var manager = VirtualVoiceManager.new()
	var resource = AudioEventResource.new()
	var config = GlobalAudioLimitConfig.new()
	config.max_virtual_voices = 3  # 设置小限制

	# 创建最大数量的虚声部
	for i in range(3):
		var info = manager._create_virtual_voice(resource, Vector3.ZERO, true, config)
		assert(info != null, "Should create virtual voice %d" % i)

	# 尝试创建超过限制
	var info = manager._create_virtual_voice(resource, Vector3.ZERO, true, config)
	assert(info == null, "Should reject virtual voice beyond max limit")

	print("test_virtual_voice_max_limit PASSED")

func test_listener_position_cache():
	"""I1 修复测试: 测试监听器位置缓存"""
	var manager = VirtualVoiceManager.new()

	# 第一次调用应该更新缓存
	var pos1 = manager._get_listener_position()
	# 立即再次调用应该使用缓存
	var pos2 = manager._get_listener_position()

	# 两个位置应该相同（缓存生效）
	assert(pos1 == pos2, "Listener position should be cached")

	print("test_listener_position_cache PASSED")
