extends Node

func test_global_config_creation():
	var config = GlobalAudioLimitConfig.new()

	assert(config.max_total_voices == 64, "Default max_total_voices should be 64")
	assert(config.max_virtual_voices == 128, "Default max_virtual_voices should be 128")
	assert(config.virtual_voice_enabled == true, "Virtual voices should be enabled by default")

	print("test_global_config_creation PASSED")

func test_bus_limits():
	var config = GlobalAudioLimitConfig.new()

	assert(config.get_bus_limit("Master") == 64, "Master bus limit should be 64")
	assert(config.get_bus_limit("Music") == 2, "Music bus limit should be 2")
	assert(config.get_bus_limit("SFX") == 40, "SFX bus limit should be 40")

	# 设置自定义限额
	config.set_bus_limit("Custom", 20)
	assert(config.get_bus_limit("Custom") == 20, "Custom bus limit should be 20")

	print("test_bus_limits PASSED")

func test_validation():
	var config = GlobalAudioLimitConfig.new()

	# 测试1: 无效的 max_total_voices
	config.max_total_voices = -10
	var result = config.validate()
	assert(result.valid == false, "Invalid max_total_voices should fail validation")
	assert("max_total_voices must be positive" in str(result.issues), "Should have error about positive max_total_voices")

	# 测试2: 虚声部必须大于真实声部
	config.max_total_voices = 64
	config.max_virtual_voices = 32  # 小于真实声部
	result = config.validate()
	assert(result.valid == false, "max_virtual_voices <= max_total_voices should fail validation")
	assert("max_virtual_voices must be larger than max_total_voices" in str(result.issues), "Should have error about virtual voices being too small")

	# 修复
	config.max_virtual_voices = 128
	result = config.validate()
	assert(result.valid == true, "Valid config should pass")

	print("test_validation PASSED")

func test_clone():
	var config = GlobalAudioLimitConfig.new()
	config.max_total_voices = 100
	config.set_bus_limit("Custom", 50)

	var cloned = config.clone()

	assert(cloned.max_total_voices == 100, "Cloned config should preserve max_total_voices")
	assert(cloned.get_bus_limit("Custom") == 50, "Cloned config should preserve custom bus limit")
	assert(cloned.get_bus_limit("Music") == 2, "Cloned config should preserve default bus limits")

	print("test_clone PASSED")

func test_virtual_voice_config():
	var config = GlobalAudioLimitConfig.new()

	assert(config.virtual_voice_enabled == true, "Virtual voices should be enabled by default")
	assert(config.virtual_max_distance == 50.0, "Default virtual_max_distance should be 50.0")
	assert(config.virtual_min_importance == 30, "Default virtual_min_importance should be 30")

	# 修改配置
	config.virtual_voice_enabled = false
	config.virtual_max_distance = 100.0
	config.virtual_min_importance = 50

	assert(config.virtual_voice_enabled == false, "Virtual voices should be disabled")
	assert(config.virtual_max_distance == 100.0, "virtual_max_distance should be updated")
	assert(config.virtual_min_importance == 50, "virtual_min_importance should be updated")

	print("test_virtual_voice_config PASSED")

func test_hardware_monitoring_config():
	var config = GlobalAudioLimitConfig.new()

	assert(config.enable_hardware_monitoring == true, "Hardware monitoring should be enabled by default")
	assert(config.cpu_usage_threshold == 80.0, "Default cpu_usage_threshold should be 80.0")
	assert(config.memory_usage_threshold == 512.0, "Default memory_usage_threshold should be 512.0")

	# 修改配置
	config.enable_hardware_monitoring = false
	config.cpu_usage_threshold = 90.0
	config.memory_usage_threshold = 1024.0

	assert(config.enable_hardware_monitoring == false, "Hardware monitoring should be disabled")
	assert(config.cpu_usage_threshold == 90.0, "cpu_usage_threshold should be updated")
	assert(config.memory_usage_threshold == 1024.0, "memory_usage_threshold should be updated")

	print("test_hardware_monitoring_config PASSED")

func test_bus_validation():
	var config = GlobalAudioLimitConfig.new()

	# 测试无效的总线限额（非正数）
	config.set_bus_limit("TestBus", -5)
	var result = config.validate()
	# set_bus_limit 现在会拒绝非正数值，所以这个值不会被设置
	assert(config.get_bus_limit("TestBus") == config.max_total_voices, "Negative limit should not be set")

	# 测试有效的总线限额
	config.set_bus_limit("TestBus", 10)
	assert(config.get_bus_limit("TestBus") == 10, "Valid limit should be set")

	# 测试总线存在性验证（会生成警告，不是错误）
	# 注意：在测试环境中可能没有 AudioServer，所以这个测试会检查警告是否存在
	config.set_bus_limit("NonExistentBus", 20)
	result = config.validate()
	# 不存在的总线应该生成警告
	if AudioServer.get_bus_count() > 0:
		# 只有在有 AudioServer 的情况下才检查
		var has_warning = false
		for warning in result.warnings:
			if "NonExistentBus" in warning:
				has_warning = true
				break
		assert(has_warning, "Non-existent bus should generate warning")

	print("test_bus_validation PASSED")

func _ready():
	print("========== GlobalAudioLimitConfig 测试开始 ==========")

	test_global_config_creation()
	test_bus_limits()
	test_validation()
	test_clone()
	test_virtual_voice_config()
	test_hardware_monitoring_config()
	test_bus_validation()

	print("========== 所有测试通过 ==========")
