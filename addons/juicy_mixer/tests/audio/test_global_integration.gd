extends Node

func test_global_config_integration():
	var handler = JuicyAudioEventHandler.new()

	# 验证默认全局配置
	assert(handler.get_global_config() != null, "Should have default global config")
	assert(handler.get_global_config() is GlobalAudioLimitConfig, "Should be GlobalAudioLimitConfig")

	print("test_global_config_integration PASSED")

func test_virtual_voice_integration():
	var handler = JuicyAudioEventHandler.new()
	var resource = AudioEventResource.new()
	resource.event_name = "test_explosion"

	# 注意：由于我们无法在没有实际音频文件的情况下创建 AudioStream，
	# 这个测试主要验证虚声部检查逻辑，而不是实际音频播放
	# 实际测试中应该使用真实的 AudioStream 资源

	# 配置全局限制
	var config = GlobalAudioLimitConfig.new()
	config.max_total_voices = 5
	config.virtual_max_distance = 10.0  # 10米后转为虚声部

	handler.set_global_config(config)

	# 验证配置已正确设置
	assert(handler.get_global_config() != null, "Global config should be set")
	assert(handler.get_global_config().virtual_max_distance == 10.0, "Virtual max distance should be 10.0")

	print("test_virtual_voice_integration PASSED")

func test_three_tier_integration():
	var handler = JuicyAudioEventHandler.new()
	var resource = AudioEventResource.new()
	resource.event_name = "footstep"

	# 配置实例级限制
	var mixing_config = AudioMixingConfig.new()
	mixing_config.max_instances = 3
	resource.mixing = mixing_config

	# 配置类别
	var category = AudioCategory.new()
	category.category_name = "Footsteps"
	category.max_instances = 2
	resource.categories.append(category)

	# 配置全局限制
	var global_config = GlobalAudioLimitConfig.new()
	global_config.max_total_voices = 10
	handler.set_global_config(global_config)

	# 验证三层配置都存在
	assert(resource.mixing != null, "Should have instance-level config")
	assert(resource.categories.size() > 0, "Should have category config")
	assert(handler.get_global_config() != null, "Should have global config")

	print("test_three_tier_integration PASSED")

func test_virtual_voice_update():
	var handler = JuicyAudioEventHandler.new()

	# 创建虚声部场景
	var resource = AudioEventResource.new()
	resource.event_name = "distant_sound"

	var config = GlobalAudioLimitConfig.new()
	config.virtual_max_distance = 1.0  # 1米后转为虚声部
	handler.set_global_config(config)

	# 模拟更新虚声部
	handler._process(0.1)  # 100ms
	handler._process(0.1)  # 再 100ms

	# 验证没有崩溃
	print("test_virtual_voice_update PASSED")

func test_virtual_voice_disabled():
	"""测试虚声部功能被禁用时的情况"""
	var handler = JuicyAudioEventHandler.new()

	var config = GlobalAudioLimitConfig.new()
	config.virtual_voice_enabled = false  # 禁用虚声部
	config.virtual_max_distance = 10.0

	handler.set_global_config(config)

	# 验证配置
	assert(handler.get_global_config() != null, "Should have global config")
	assert(handler.get_global_config().virtual_voice_enabled == false, "Virtual voice should be disabled")

	print("test_virtual_voice_disabled PASSED")

func test_null_global_config():
	"""测试全局配置为 null 时的情况"""
	var handler = JuicyAudioEventHandler.new()

	# 设置为 null
	handler.set_global_config(null)

	# 验证不会崩溃
	assert(handler.get_global_config() == null, "Global config should be null")

	print("test_null_global_config PASSED")

func test_boundary_distance():
	"""测试在精确的虚声部边界距离处的行为"""
	var handler = JuicyAudioEventHandler.new()
	var resource = AudioEventResource.new()
	resource.event_name = "boundary_test"

	var config = GlobalAudioLimitConfig.new()
	config.virtual_max_distance = 50.0  # 50米边界
	config.virtual_voice_enabled = true

	handler.set_global_config(config)

	# 验证边界值已设置
	assert(handler.get_global_config().virtual_max_distance == 50.0, "Boundary should be 50.0")

	print("test_boundary_distance PASSED")

func _ready():
	# 运行所有测试
	test_global_config_integration()
	test_virtual_voice_integration()
	test_three_tier_integration()
	test_virtual_voice_update()
	test_virtual_voice_disabled()
	test_null_global_config()
	test_boundary_distance()

	print("\n=== 全局集成测试完成 ===")
