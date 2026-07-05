# 测试 JuicyShakeResource 功能
extends Node

var shake_resource: JuicyShakeResource
var test_target: Node2D

func _ready():
	# 运行所有测试
	_test_create_instance()
	_test_add_shake_data()
	_test_validate_config_empty()
	_test_validate_config_valid()
	_test_validate_config_invalid_data()
	_test_validate_config_duplicate_properties()
	_test_remove_shake_data()
	_test_remove_shake_data_invalid_index()
	_test_clear_shake_data()
	_test_get_shake_data_invalid_index()
	_test_loop_properties()
	_test_create_drivers()
	_test_string_representation()
	_test_configuration_warning()
	_test_shake_data_validation()
	
	print("✅ All JuicyShakeResource tests passed!")

func _test_create_instance():
	shake_resource = JuicyShakeResource.new()
	assert(shake_resource != null, "应该能创建 JuicyShakeResource 实例")
	assert(shake_resource.get_resource_type() == "JuicyShakeResource", "资源类型应该正确")
	print("✅ test_create_instance passed")

func _test_add_shake_data():
	shake_resource = JuicyShakeResource.new()
	var data = shake_resource.add_shake_data("position", 10.0, 5.0, 1.0, 0, 42, 2, 0.5, 2.0)
	
	assert(data != null, "应该返回有效的 ShakeData 实例")
	assert(shake_resource.get_shake_data_count() == 1, "应该有一个震动数据")
	assert(data.property == "position", "属性名称应该正确")
	assert(data.amplitude == 10.0, "振幅应该正确")
	assert(data.frequency == 5.0, "频率应该正确")
	assert(data.duration == 1.0, "持续时间应该正确")
	assert(data.noise_seed == 42, "噪声种子应该正确")
	print("✅ test_add_shake_data passed")

func _test_validate_config_empty():
	shake_resource = JuicyShakeResource.new()
	var result = shake_resource.validate_config()
	
	assert(not result.valid, "空配置应该无效")
	assert(result.issues.size() > 0, "应该有错误信息")
	assert("Shake data cannot be empty" in result.issues, "应该提示震动数据为空")
	print("✅ test_validate_config_empty passed")

func _test_validate_config_valid():
	shake_resource = JuicyShakeResource.new()
	# 添加有效的震动数据
	shake_resource.add_shake_data("position", 10.0, 5.0, 1.0)
	shake_resource.add_shake_data("scale", 0.5, 10.0, 0.5)
	
	var result = shake_resource.validate_config()
	
	assert(result.valid, "有效配置应该通过验证")
	assert(result.issues.is_empty(), "不应该有错误")
	print("✅ test_validate_config_valid passed")

func _test_validate_config_invalid_data():
	shake_resource = JuicyShakeResource.new()
	# 添加无效的震动数据
	var data = ShakeData.new()
	data.property = ""  # 空属性名
	data.amplitude = 0.0  # 无效振幅
	data.frequency = -1.0  # 无效频率
	shake_resource.shake_data.append(data)
	
	var result = shake_resource.validate_config()
	
	assert(not result.valid, "无效数据应该导致验证失败")
	assert(result.issues.size() > 0, "应该有错误信息")
	print("✅ test_validate_config_invalid_data passed")

func _test_validate_config_duplicate_properties():
	shake_resource = JuicyShakeResource.new()
	# 添加重复的属性
	shake_resource.add_shake_data("position", 10.0, 5.0, 1.0)
	shake_resource.add_shake_data("position", 5.0, 10.0, 0.5)
	
	var result = shake_resource.validate_config()
	
	assert(result.valid, "重复属性不应该导致验证失败")
	assert(result.warnings.size() > 0, "应该有警告信息")
	assert("Duplicate property name: position" in result.warnings, "应该警告重复属性")
	print("✅ test_validate_config_duplicate_properties passed")

func _test_remove_shake_data():
	shake_resource = JuicyShakeResource.new()
	shake_resource.add_shake_data("position", 10.0, 5.0, 1.0)
	shake_resource.add_shake_data("scale", 0.5, 10.0, 0.5)
	
	assert(shake_resource.get_shake_data_count() == 2, "应该有两个震动数据")
	
	var removed = shake_resource.remove_shake_data(0)
	assert(removed, "应该成功移除第一个数据")
	assert(shake_resource.get_shake_data_count() == 1, "应该只剩下一个数据")
	
	# 验证剩余的数据
	var remaining_data = shake_resource.get_shake_data(0)
	assert(remaining_data != null, "应该还有剩余数据")
	assert(remaining_data.property == "scale", "剩余数据应该是scale")
	print("✅ test_remove_shake_data passed")

func _test_remove_shake_data_invalid_index():
	shake_resource = JuicyShakeResource.new()
	shake_resource.add_shake_data("position", 10.0, 5.0, 1.0)
	
	var removed = shake_resource.remove_shake_data(-1)
	assert(not removed, "无效索引应该返回false")
	
	removed = shake_resource.remove_shake_data(10)
	assert(not removed, "超出范围的索引应该返回false")
	
	assert(shake_resource.get_shake_data_count() == 1, "数据数量应该不变")
	print("✅ test_remove_shake_data_invalid_index passed")

func _test_clear_shake_data():
	shake_resource = JuicyShakeResource.new()
	shake_resource.add_shake_data("position", 10.0, 5.0, 1.0)
	shake_resource.add_shake_data("scale", 0.5, 10.0, 0.5)
	shake_resource.add_shake_data("rotation", 1.0, 15.0, 2.0)
	
	assert(shake_resource.get_shake_data_count() == 3, "应该有三个震动数据")
	
	shake_resource.clear_shake_data()
	assert(shake_resource.get_shake_data_count() == 0, "清除后应该没有数据")
	print("✅ test_clear_shake_data passed")

func _test_get_shake_data_invalid_index():
	shake_resource = JuicyShakeResource.new()
	shake_resource.add_shake_data("position", 10.0, 5.0, 1.0)
	
	var data = shake_resource.get_shake_data(-1)
	assert(data == null, "无效索引应该返回null")
	
	data = shake_resource.get_shake_data(10)
	assert(data == null, "超出范围的索引应该返回null")
	print("✅ test_get_shake_data_invalid_index passed")

func _test_loop_properties():
	shake_resource = JuicyShakeResource.new()
	assert(not shake_resource.loop, "默认不应该循环")
	assert(shake_resource.loop_delay == 0.0, "默认循环延迟应该为0")
	
	shake_resource.loop = true
	shake_resource.loop_delay = 2.0
	
	assert(shake_resource.loop, "应该能设置循环")
	assert(shake_resource.loop_delay == 2.0, "应该能设置循环延迟")
	print("✅ test_loop_properties passed")

func _test_create_drivers():
	shake_resource = JuicyShakeResource.new()
	var drivers = shake_resource.create_drivers()
	
	assert(drivers.size() == 1, "应该创建一个驱动器")
	assert(drivers[0] != null, "驱动器不应该为null")
	assert(drivers[0] is JuicyShakeDriver, "应该创建 JuicyShakeDriver 实例")
	print("✅ test_create_drivers passed")

func _test_string_representation():
	shake_resource = JuicyShakeResource.new()
	shake_resource.add_shake_data("position", 10.0, 5.0, 1.0)
	shake_resource.add_shake_data("scale", 0.5, 10.0, 0.5)
	shake_resource.duration = 2.0
	shake_resource.loop = true
	
	var str_repr = shake_resource._to_string()
	
	assert(str_repr.find("JuicyShakeResource") >= 0, "字符串表示应该包含资源类型")
	assert(str_repr.find("shake_count=2") >= 0, "字符串表示应该包含数据数量")
	assert(str_repr.find("duration=2.00") >= 0, "字符串表示应该包含持续时间")
	assert(str_repr.find("loop=true") >= 0, "字符串表示应该包含循环信息")
	print("✅ test_string_representation passed")

func _test_configuration_warning():
	shake_resource = JuicyShakeResource.new()
	# 测试有效配置
	shake_resource.add_shake_data("position", 10.0, 5.0, 1.0)
	var warning = shake_resource._get_configuration_warning()
	assert(warning == "", "有效配置不应该有警告")
	
	# 测试无效配置
	shake_resource.clear_shake_data()
	warning = shake_resource._get_configuration_warning()
	assert(warning.find("Configuration errors") >= 0, "无效配置应该有错误警告")
	print("✅ test_configuration_warning passed")

func _test_shake_data_validation():
	shake_resource = JuicyShakeResource.new()
	var data = shake_resource.add_shake_data("position", 10.0, 5.0, 1.0)
	var result = data.validate()
	
	assert(result.valid, "有效震动数据应该通过验证")
	
	# 测试无效数据
	data.property = ""
	data.amplitude = 0.0
	data.frequency = -1.0
	data.duration = 0.0
	
	result = data.validate()
	assert(not result.valid, "无效数据应该验证失败")
	assert(result.issues.size() > 0, "应该有错误信息")
	print("✅ test_shake_data_validation passed")