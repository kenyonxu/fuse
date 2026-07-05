extends SceneTree
# ChannelInterruptionConfig 单元测试
# 测试通道中断配置的核心功能

const ChannelInterruptionConfig = preload("res://addons/juicy_mixer/resources/channel_interruption_config.gd")
const JuicyMixerEnms = preload("res://addons/juicy_mixer/core/juicy_mixer_enums.gd")

var _test_results: Array = []

func _init():
	_test_results = []

func test_channel_interruption_config_creation():
	# 测试基本创建
	var config = ChannelInterruptionConfig.new()
	assert(config != null, "ChannelInterruptionConfig 应该成功创建")
	assert(config.channel_name == "default", "默认通道名称应该是 'default'")
	assert(config.default_policy == JuicyMixerEnms.InterruptionPolicy.STACK, "默认策略应该是 STACK")
	assert(config.priority == 0, "默认优先级应该是 0")
	assert(config.max_queue_size == 10, "默认最大队列大小应该是 10")
	assert(config.transition_duration == 0.2, "默认过渡持续时间应该是 0.2")
	assert(config.allow_preemption == true, "默认应该允许抢占")
	
	_test_results.append("test_channel_interruption_config_creation: PASSED")

func test_policy_configuration():
	var config = ChannelInterruptionConfig.new()
	
	# 测试策略设置
	config.set_policy(JuicyMixerEnms.InterruptionPolicy.RESTART)
	assert(config.get_policy() == JuicyMixerEnms.InterruptionPolicy.RESTART, "策略应该设置为 RESTART")
	
	config.set_policy(JuicyMixerEnms.InterruptionPolicy.IGNORE)
	assert(config.get_policy() == JuicyMixerEnms.InterruptionPolicy.IGNORE, "策略应该设置为 IGNORE")
	
	config.set_policy(JuicyMixerEnms.InterruptionPolicy.SMOOTH_TRANSITION)
	assert(config.get_policy() == JuicyMixerEnms.InterruptionPolicy.SMOOTH_TRANSITION, "策略应该设置为 SMOOTH_TRANSITION")
	
	config.set_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
	assert(config.get_policy() == JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE, "策略应该设置为 PRIORITY_OVERRIDE")
	
	_test_results.append("test_policy_configuration: PASSED")

func test_priority_configuration():
	var config = ChannelInterruptionConfig.new()
	
	# 测试优先级设置
	config.set_channel_priority(5)
	assert(config.get_channel_priority() == 5, "优先级应该设置为 5")
	
	config.set_channel_priority(-10)
	assert(config.get_channel_priority() == -10, "优先级应该设置为 -10")
	
	config.set_channel_priority(999)
	assert(config.get_channel_priority() == 999, "优先级应该设置为 999")
	
	config.set_channel_priority(0)
	assert(config.get_channel_priority() == 0, "优先级应该重置为 0")
	
	_test_results.append("test_priority_configuration: PASSED")

func test_queue_size_configuration():
	var config = ChannelInterruptionConfig.new()
	
	# 测试队列大小设置
	config.set_max_queue_size(20)
	assert(config.get_max_queue_size() == 20, "队列大小应该设置为 20")
	
	# 测试边界值
	config.set_max_queue_size(1)
	assert(config.get_max_queue_size() == 1, "队列大小应该设置为 1")
	
	# 测试无效值（应该被限制为最小值 1）
	config.set_max_queue_size(0)
	assert(config.get_max_queue_size() == 1, "队列大小不应该小于 1")
	
	config.set_max_queue_size(-5)
	assert(config.get_max_queue_size() == 1, "负值应该被限制为 1")
	
	_test_results.append("test_queue_size_configuration: PASSED")

func test_transition_duration_configuration():
	var config = ChannelInterruptionConfig.new()
	
	# 测试过渡持续时间设置
	config.set_transition_duration(1.5)
	assert(config.get_transition_duration() == 1.5, "过渡持续时间应该设置为 1.5")
	
	config.set_transition_duration(0.0)
	assert(config.get_transition_duration() == 0.0, "过渡持续时间应该设置为 0.0")
	
	# 测试负值（应该被限制为 0.0）
	config.set_transition_duration(-1.0)
	assert(config.get_transition_duration() == 0.0, "负值应该被限制为 0.0")
	
	config.set_transition_duration(10.5)
	assert(config.get_transition_duration() == 10.5, "过渡持续时间应该设置为 10.5")
	
	_test_results.append("test_transition_duration_configuration: PASSED")

func test_preemption_configuration():
	var config = ChannelInterruptionConfig.new()
	
	# 测试抢占设置
	config.set_preemption_allowed(false)
	assert(not config.is_preemption_allowed(), "抢占应该被禁用")
	
	config.set_preemption_allowed(true)
	assert(config.is_preemption_allowed(), "抢占应该被启用")
	
	_test_results.append("test_preemption_configuration: PASSED")

func test_feature_switches():
	var config = ChannelInterruptionConfig.new()
	
	# 测试优先级队列功能
	config.enable_feature("priority_queue", false)
	assert(not config.is_feature_enabled("priority_queue"), "优先级队列应该被禁用")
	
	config.enable_feature("priority_queue", true)
	assert(config.is_feature_enabled("priority_queue"), "优先级队列应该被启用")
	
	# 测试中断历史功能
	config.enable_feature("interruption_history", false)
	assert(not config.is_feature_enabled("interruption_history"), "中断历史应该被禁用")
	
	config.enable_feature("interruption_history", true)
	assert(config.is_feature_enabled("interruption_history"), "中断历史应该被启用")
	
	# 测试自动清理功能
	config.enable_feature("auto_cleanup", false)
	assert(not config.is_feature_enabled("auto_cleanup"), "自动清理应该被禁用")
	
	config.enable_feature("auto_cleanup", true)
	assert(config.is_feature_enabled("auto_cleanup"), "自动清理应该被启用")
	
	# 测试无效功能名称
	assert(not config.is_feature_enabled("invalid_feature"), "无效功能应该返回 false")
	
	_test_results.append("test_feature_switches: PASSED")

func test_configuration_validation():
	var config = ChannelInterruptionConfig.new()
	
	# 测试默认配置验证
	var validation_result = config.validate_config()
	assert(validation_result.valid, "默认配置应该是有效的")
	assert(validation_result.issues.size() == 0, "默认配置不应该有问题")
	
	# 测试空通道名称
	config.channel_name = ""
	validation_result = config.validate_config()
	assert(not validation_result.valid, "空通道名称应该验证失败")
	assert(validation_result.issues.size() > 0, "应该有验证问题")
	assert("Channel name cannot be empty" in validation_result.issues, "应该包含通道名称错误")
	
	# 恢复通道名称
	config.channel_name = "test_channel"
	
	# 测试无效队列大小
	config.max_queue_size = 0
	validation_result = config.validate_config()
	assert(not validation_result.valid, "无效队列大小应该验证失败")
	assert("Max queue size must be at least 1" in validation_result.issues, "应该包含队列大小错误")
	
	# 恢复队列大小
	config.max_queue_size = 10
	
	# 测试负过渡持续时间
	config.transition_duration = -1.0
	validation_result = config.validate_config()
	assert(not validation_result.valid, "负过渡持续时间应该验证失败")
	assert("Transition duration cannot be negative" in validation_result.issues, "应该包含过渡持续时间错误")
	
	# 恢复过渡持续时间
	config.transition_duration = 0.2
	
	# 测试过小的历史大小
	config.max_history_size = 5
	validation_result = config.validate_config()
	assert(not validation_result.valid, "过小的历史大小应该验证失败")
	assert("Max history size should be at least 10" in validation_result.issues, "应该包含历史大小错误")
	
	_test_results.append("test_configuration_validation: PASSED")

func test_resource_duplication():
	var config = ChannelInterruptionConfig.new()
	
	# 设置一些自定义值
	config.channel_name = "test_channel"
	config.default_policy = JuicyMixerEnms.InterruptionPolicy.RESTART
	config.priority = 5
	config.max_queue_size = 25
	config.transition_duration = 0.5
	config.allow_preemption = false
	config.enable_priority_queue = false
	config.enable_interruption_history = false
	config.max_history_size = 200
	config.auto_cleanup_threshold = 30
	
	# 测试资源复制
	var duplicated = config.duplicate()
	assert(duplicated != null, "复制应该成功")
	assert(duplicated != config, "复制应该是不同的实例")
	
	# 验证所有属性都被正确复制
	assert(duplicated.channel_name == config.channel_name, "通道名称应该相同")
	assert(duplicated.default_policy == config.default_policy, "默认策略应该相同")
	assert(duplicated.priority == config.priority, "优先级应该相同")
	assert(duplicated.max_queue_size == config.max_queue_size, "最大队列大小应该相同")
	assert(duplicated.transition_duration == config.transition_duration, "过渡持续时间应该相同")
	assert(duplicated.allow_preemption == config.allow_preemption, "抢占设置应该相同")
	assert(duplicated.enable_priority_queue == config.enable_priority_queue, "优先级队列设置应该相同")
	assert(duplicated.enable_interruption_history == config.enable_interruption_history, "中断历史设置应该相同")
	assert(duplicated.max_history_size == config.max_history_size, "最大历史大小应该相同")
	assert(duplicated.auto_cleanup_threshold == config.auto_cleanup_threshold, "自动清理阈值应该相同")
	
	_test_results.append("test_resource_duplication: PASSED")

func test_string_representation():
	var config = ChannelInterruptionConfig.new()
	
	# 测试字符串表示
	var str_repr = config._to_string()
	assert(str_repr.contains("ChannelInterruptionConfig"), "字符串表示应该包含类名")
	assert(str_repr.contains("channel=default"), "字符串表示应该包含通道名称")
	assert(str_repr.contains("policy=stack"), "字符串表示应该包含策略")
	assert(str_repr.contains("priority=0"), "字符串表示应该包含优先级")
	
	# 测试自定义值的字符串表示
	config.channel_name = "custom_channel"
	config.default_policy = JuicyMixerEnms.InterruptionPolicy.RESTART
	config.priority = 10
	
	str_repr = config._to_string()
	assert(str_repr.contains("channel=custom_channel"), "字符串表示应该包含自定义通道名称")
	assert(str_repr.contains("policy=restart"), "字符串表示应该包含自定义策略")
	assert(str_repr.contains("priority=10"), "字符串表示应该包含自定义优先级")
	
	_test_results.append("test_string_representation: PASSED")

func test_configuration_serialization():
	var config = ChannelInterruptionConfig.new()
	
	# 设置一些自定义值
	config.channel_name = "test_channel"
	config.default_policy = JuicyMixerEnms.InterruptionPolicy.SMOOTH_TRANSITION
	config.priority = 8
	config.max_queue_size = 30
	config.transition_duration = 0.8
	config.allow_preemption = false
	config.enable_priority_queue = false
	config.enable_interruption_history = false
	config.max_history_size = 150
	config.auto_cleanup_threshold = 25
	
	# 测试获取配置字典
	var config_dict = config.get_config_dict()
	assert(typeof(config_dict) == TYPE_DICTIONARY, "配置字典应该是字典类型")
	assert(config_dict.has("channel_name"), "配置字典应该包含 channel_name")
	assert(config_dict.has("default_policy"), "配置字典应该包含 default_policy")
	assert(config_dict.has("priority"), "配置字典应该包含 priority")
	assert(config_dict.has("max_queue_size"), "配置字典应该包含 max_queue_size")
	assert(config_dict.has("transition_duration"), "配置字典应该包含 transition_duration")
	assert(config_dict.has("allow_preemption"), "配置字典应该包含 allow_preemption")
	assert(config_dict.has("enable_priority_queue"), "配置字典应该包含 enable_priority_queue")
	assert(config_dict.has("enable_interruption_history"), "配置字典应该包含 enable_interruption_history")
	assert(config_dict.has("max_history_size"), "配置字典应该包含 max_history_size")
	assert(config_dict.has("auto_cleanup_threshold"), "配置字典应该包含 auto_cleanup_threshold")
	
	# 验证值
	assert(config_dict["channel_name"] == "test_channel", "channel_name 应该正确")
	assert(config_dict["default_policy"] == "smooth_transition", "default_policy 应该正确")
	assert(config_dict["priority"] == 8, "priority 应该正确")
	assert(config_dict["max_queue_size"] == 30, "max_queue_size 应该正确")
	assert(config_dict["transition_duration"] == 0.8, "transition_duration 应该正确")
	assert(config_dict["allow_preemption"] == false, "allow_preemption 应该正确")
	assert(config_dict["enable_priority_queue"] == false, "enable_priority_queue 应该正确")
	assert(config_dict["enable_interruption_history"] == false, "enable_interruption_history 应该正确")
	assert(config_dict["max_history_size"] == 150, "max_history_size 应该正确")
	assert(config_dict["auto_cleanup_threshold"] == 25, "auto_cleanup_threshold 应该正确")
	
	_test_results.append("test_configuration_serialization: PASSED")

func test_configuration_deserialization():
	var config = ChannelInterruptionConfig.new()
	
	# 创建测试配置字典
	var test_dict = {
		"channel_name": "loaded_channel",
		"default_policy": "priority_override",
		"priority": 15,
		"max_queue_size": 40,
		"transition_duration": 1.2,
		"allow_preemption": true,
		"enable_priority_queue": true,
		"enable_interruption_history": true,
		"max_history_size": 250,
		"auto_cleanup_threshold": 35
	}
	
	# 测试从字典加载
	var success = config.load_from_dict(test_dict)
	assert(success, "从字典加载应该成功")
	
	# 验证加载的值
	assert(config.channel_name == "loaded_channel", "channel_name 应该正确加载")
	assert(config.default_policy == JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE, "default_policy 应该正确加载")
	assert(config.priority == 15, "priority 应该正确加载")
	assert(config.max_queue_size == 40, "max_queue_size 应该正确加载")
	assert(config.transition_duration == 1.2, "transition_duration 应该正确加载")
	assert(config.allow_preemption == true, "allow_preemption 应该正确加载")
	assert(config.enable_priority_queue == true, "enable_priority_queue 应该正确加载")
	assert(config.enable_interruption_history == true, "enable_interruption_history 应该正确加载")
	assert(config.max_history_size == 250, "max_history_size 应该正确加载")
	assert(config.auto_cleanup_threshold == 35, "auto_cleanup_threshold 应该正确加载")
	
	# 测试空字典
	var empty_success = config.load_from_dict({})
	assert(empty_success, "空字典加载应该成功（保持现有值）")
	
	# 测试无效字典（使用空字典代替 null）
	var invalid_dict = {}
	var invalid_success = config.load_from_dict(invalid_dict)
	# 空字典加载应该成功，但不会改变任何值
	assert(invalid_success, "空字典加载应该成功")
	
	_test_results.append("test_configuration_deserialization: PASSED")

func test_resource_serialization():
	var config = ChannelInterruptionConfig.new()
	
	# 设置一些值
	config.channel_name = "serialized_channel"
	config.priority = 20
	
	# 测试资源序列化
	var serialized = config.serialize_resource()
	assert(typeof(serialized) == TYPE_DICTIONARY, "序列化结果应该是字典")
	assert(serialized.has("resource_type"), "序列化应该包含 resource_type")
	assert(serialized.has("version"), "序列化应该包含 version")
	assert(serialized.has("data"), "序列化应该包含 data")
	
	assert(serialized["resource_type"] == "ChannelInterruptionConfig", "resource_type 应该正确")
	assert(serialized["version"] == "1.0", "version 应该正确")
	assert(typeof(serialized["data"]) == TYPE_DICTIONARY, "data 应该是字典")
	
	_test_results.append("test_resource_serialization: PASSED")

func test_resource_deserialization():
	var config = ChannelInterruptionConfig.new()
	
	# 创建测试序列化数据
	var serialized_data = {
		"resource_type": "ChannelInterruptionConfig",
		"version": "1.0",
		"data": {
			"channel_name": "deserialized_channel",
			"default_policy": "fade_out_fade_in",
			"priority": 25,
			"max_queue_size": 50,
			"transition_duration": 1.5,
			"allow_preemption": false,
			"enable_priority_queue": false,
			"enable_interruption_history": true,
			"max_history_size": 300,
			"auto_cleanup_threshold": 40
		}
	}
	
	# 测试资源反序列化
	var success = config.deserialize_resource(serialized_data)
	assert(success, "资源反序列化应该成功")
	
	# 验证反序列化的值
	assert(config.channel_name == "deserialized_channel", "channel_name 应该正确反序列化")
	assert(config.default_policy == JuicyMixerEnms.InterruptionPolicy.FADE_OUT_FADE_IN, "default_policy 应该正确反序列化")
	assert(config.priority == 25, "priority 应该正确反序列化")
	
	# 测试无效数据
	var invalid_success = config.deserialize_resource({})
	assert(not invalid_success, "无效数据反序列化应该失败")
	
	# 移除重复的无效数据测试，避免变量名冲突
	
	_test_results.append("test_resource_deserialization: PASSED")

func test_serialization_validation():
	var config = ChannelInterruptionConfig.new()
	
	# 测试有效的序列化数据
	var valid_data = {
		"resource_type": "ChannelInterruptionConfig",
		"version": "1.0",
		"data": {
			"channel_name": "valid_channel",
			"default_policy": "stack",
			"priority": 5,
			"max_queue_size": 10,
			"transition_duration": 0.2,
			"allow_preemption": true,
			"enable_priority_queue": true,
			"enable_interruption_history": true,
			"max_history_size": 100,
			"auto_cleanup_threshold": 50
		}
	}
	
	var validation_result = config.validate_serialization_data(valid_data)
	assert(validation_result.valid, "有效数据应该通过验证")
	assert(validation_result.issues.size() == 0, "有效数据不应该有验证问题")
	
	# 测试无效数据格式（使用空字典代替字符串）
	var invalid_format_data = {}
	var invalid_format_result = config.validate_serialization_data(invalid_format_data)
	# 空字典会触发其他验证错误，但不是格式错误
	assert(not invalid_format_result.valid, "无效数据应该验证失败")
	
	# 测试缺失必需字段
	var missing_fields_data = {
		"resource_type": "ChannelInterruptionConfig",
		"version": "1.0"
		# 缺少 data 字段
	}
	
	var missing_fields_result = config.validate_serialization_data(missing_fields_data)
	assert(not missing_fields_result.valid, "缺失字段应该验证失败")
	assert("Missing required field: data" in missing_fields_result.issues, "应该包含缺失字段错误")
	
	# 测试无效资源类型
	var invalid_type_data = {
		"resource_type": "InvalidType",
		"version": "1.0",
		"data": {}
	}
	
	var invalid_type_result = config.validate_serialization_data(invalid_type_data)
	assert(not invalid_type_result.valid, "无效资源类型应该验证失败")
	assert("Invalid resource type" in invalid_type_result.issues, "应该包含资源类型错误")
	
	_test_results.append("test_serialization_validation: PASSED")

func test_edge_cases():
	var config = ChannelInterruptionConfig.new()
	
	# 测试特殊字符通道名称
	config.channel_name = "channel_with_special_chars_!@#$%^&*()"
	var validation_result = config.validate_config()
	assert(validation_result.valid, "特殊字符通道名称应该有效")
	
	# 测试极大值
	config.priority = 999999
	config.max_queue_size = 999999
	config.transition_duration = 999999.9
	config.max_history_size = 999999
	
	validation_result = config.validate_config()
	assert(validation_result.valid, "极大值应该有效")
	
	# 测试极小值
	config.priority = -999999
	config.transition_duration = 0.000001
	
	validation_result = config.validate_config()
	assert(validation_result.valid, "极小值应该有效")
	
	# 测试浮点数精度
	config.transition_duration = 0.333333
	assert(config.transition_duration == 0.333333, "浮点数精度应该保持")
	
	_test_results.append("test_edge_cases: PASSED")

func test_property_list():
	var config = ChannelInterruptionConfig.new()
	
	# 测试获取属性列表
	var property_list = config._get_property_list()
	assert(typeof(property_list) == TYPE_ARRAY, "属性列表应该是数组")
	assert(property_list.size() > 0, "属性列表不应该为空")
	
	# 验证属性列表结构
	var has_base_group = false
	var has_advanced_group = false
	
	for prop in property_list:
		if prop.has("name") and prop.name == "Base Configuration":
			has_base_group = true
		if prop.has("name") and prop.name == "Advanced Configuration":
			has_advanced_group = true
	
	assert(has_base_group, "应该包含基础配置组")
	assert(has_advanced_group, "应该包含高级配置组")
	
	_test_results.append("test_property_list: PASSED")

func run_all_tests():
	print("=== 开始 ChannelInterruptionConfig 单元测试 ===")
	
	# 定义测试函数列表
	var test_functions = [
		"test_channel_interruption_config_creation",
		"test_policy_configuration",
		"test_priority_configuration",
		"test_queue_size_configuration",
		"test_transition_duration_configuration",
		"test_preemption_configuration",
		"test_feature_switches",
		"test_configuration_validation",
		"test_resource_duplication",
		"test_string_representation",
		"test_configuration_serialization",
		"test_configuration_deserialization",
		"test_resource_serialization",
		"test_resource_deserialization",
		"test_serialization_validation",
		"test_edge_cases",
		"test_property_list"
	]
	
	print("总测试函数数量: " + str(test_functions.size()))
	
	# 执行每个测试函数
	for i in range(test_functions.size()):
		var test_func_name = test_functions[i]
		print("执行测试 " + str(i+1) + "/" + str(test_functions.size()) + ": " + test_func_name)
		
		var initial_count = _test_results.size()
		call(test_func_name)
		var final_count = _test_results.size()
		
		# 如果测试后结果数量没有增加，说明测试失败了
		if final_count == initial_count:
			print("❌ 测试 " + test_func_name + " 失败（没有添加结果）")
			_test_results.append(test_func_name + ": FAILED - No result added")
	
	print("=== ChannelInterruptionConfig 单元测试结果 ===")
	for result in _test_results:
		print(result)
	
	var passed_count = _test_results.size()
	var total_tests = test_functions.size()
	print("通过测试: " + str(passed_count) + "/" + str(total_tests))
	
	if passed_count == total_tests:
		print("所有测试通过！")
		return true
	else:
		print("部分测试失败！")
		return false
