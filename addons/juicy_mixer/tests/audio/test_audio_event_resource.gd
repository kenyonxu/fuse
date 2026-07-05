extends Node

func test_virtual_voice_properties():
	var event = AudioEventResource.new()

	# 验证默认值
	assert(event.virtual_voice_enabled == true, "Default virtual_voice_enabled should be true")
	assert(event.virtual_max_distance == 50.0, "Default virtual_max_distance should be 50.0")
	assert(event.virtual_min_importance == 30, "Default virtual_min_importance should be 30")

	# 验证可以设置
	event.virtual_voice_enabled = false
	event.virtual_max_distance = 100.0
	event.virtual_min_importance = 50

	assert(event.virtual_voice_enabled == false, "virtual_voice_enabled should be false")
	assert(event.virtual_max_distance == 100.0, "virtual_max_distance should be 100.0")
	assert(event.virtual_min_importance == 50, "virtual_min_importance should be 50")

	print("test_virtual_voice_properties PASSED")

func test_virtual_voice_validation():
	var event = AudioEventResource.new()
	event.audio_variants = [AudioVariant.new()]

	# 有效配置
	var result = event.validate()
	assert(result.valid == true, "Valid configuration should pass")
	assert(result.warnings.is_empty(), "Valid config should have no warnings")

	# 无效配置
	event.virtual_max_distance = -10.0
	result = event.validate()
	assert(result.warnings.size() > 0, "Invalid max_distance should generate warning")

	print("test_virtual_voice_validation PASSED")
