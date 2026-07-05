# 测试 JuicyTweenResource 功能
extends Node

var tween_resource: JuicyTweenResource
var test_target: Node2D

func _ready():
	# 运行所有测试
	_test_create_instance()
	_test_add_tween_data()
	_test_validate_config_empty()
	_test_validate_config_valid()
	_test_validate_config_invalid_data()
	_test_validate_config_duplicate_properties()
	_test_remove_tween_data()
	_test_remove_tween_data_invalid_index()
	_test_clear_tween_data()
	_test_get_tween_data_invalid_index()
	_test_loop_properties()
	_test_create_drivers()
	_test_string_representation()
	_test_configuration_warning()
	
	print("✅ All JuicyTweenResource tests passed!")

func _test_create_instance():
	tween_resource = JuicyTweenResource.new()
	assert(tween_resource != null, "应该能创建 JuicyTweenResource 实例")
	assert(tween_resource.get_resource_type() == "JuicyTweenResource", "资源类型应该正确")
	print("✅ test_create_instance passed")

func _test_add_tween_data():
	tween_resource = JuicyTweenResource.new()
	var data = tween_resource.add_tween_data("position", Vector2.ZERO, Vector2(100, 100), 1.0)
	
	assert(data != null, "应该返回有效的 TweenData 实例")
	assert(tween_resource.get_tween_data_count() == 1, "应该有一个补间数据")
	assert(data.property == "position", "属性名称应该正确")
	assert(data.from_value == Vector2.ZERO, "起始值应该正确")
	assert(data.to_value == Vector2(100, 100), "目标值应该正确")
	assert(data.duration == 1.0, "持续时间应该正确")
	print("✅ test_add_tween_data passed")

func _test_validate_config_empty():
	tween_resource = JuicyTweenResource.new()
	var result = tween_resource.validate_config()
	
	assert(not result.valid, "空配置应该无效")
	assert(result.issues.size() > 0, "应该有错误信息")
	assert("Tween data cannot be empty" in result.issues, "应该提示补间数据为空")
	print("✅ test_validate_config_empty passed")

func _test_validate_config_valid():
	tween_resource = JuicyTweenResource.new()
	# 添加有效的补间数据
	tween_resource.add_tween_data("position", Vector2.ZERO, Vector2(100, 100), 1.0)
	tween_resource.add_tween_data("scale", Vector2.ONE, Vector2(2, 2), 0.5)
	
	var result = tween_resource.validate_config()
	
	assert(result.valid, "有效配置应该通过验证")
	assert(result.issues.is_empty(), "不应该有错误")
	print("✅ test_validate_config_valid passed")

func _test_validate_config_invalid_data():
	tween_resource = JuicyTweenResource.new()
	# 添加无效的补间数据
	var data = TweenData.new()
	data.property = ""  # 空属性名
	data.duration = 0.0  # 无效持续时间
	tween_resource.tween_data.append(data)
	
	var result = tween_resource.validate_config()
	
	assert(not result.valid, "无效数据应该导致验证失败")
	assert(result.issues.size() > 0, "应该有错误信息")
	print("✅ test_validate_config_invalid_data passed")

func _test_validate_config_duplicate_properties():
	tween_resource = JuicyTweenResource.new()
	# 添加重复的属性
	tween_resource.add_tween_data("position", Vector2.ZERO, Vector2(100, 100), 1.0)
	tween_resource.add_tween_data("position", Vector2(50, 50), Vector2(150, 150), 0.5)
	
	var result = tween_resource.validate_config()
	
	assert(result.valid, "重复属性不应该导致验证失败")
	assert(result.warnings.size() > 0, "应该有警告信息")
	assert("Duplicate property name: position" in result.warnings, "应该警告重复属性")
	print("✅ test_validate_config_duplicate_properties passed")

func _test_remove_tween_data():
	tween_resource = JuicyTweenResource.new()
	tween_resource.add_tween_data("position", Vector2.ZERO, Vector2(100, 100), 1.0)
	tween_resource.add_tween_data("scale", Vector2.ONE, Vector2(2, 2), 0.5)
	
	assert(tween_resource.get_tween_data_count() == 2, "应该有两个补间数据")
	
	var removed = tween_resource.remove_tween_data(0)
	assert(removed, "应该成功移除第一个数据")
	assert(tween_resource.get_tween_data_count() == 1, "应该只剩下一个数据")
	
	# 验证剩余的数据
	var remaining_data = tween_resource.get_tween_data(0)
	assert(remaining_data != null, "应该还有剩余数据")
	assert(remaining_data.property == "scale", "剩余数据应该是scale")
	print("✅ test_remove_tween_data passed")

func _test_remove_tween_data_invalid_index():
	tween_resource = JuicyTweenResource.new()
	tween_resource.add_tween_data("position", Vector2.ZERO, Vector2(100, 100), 1.0)
	
	var removed = tween_resource.remove_tween_data(-1)
	assert(not removed, "无效索引应该返回false")
	
	removed = tween_resource.remove_tween_data(10)
	assert(not removed, "超出范围的索引应该返回false")
	
	assert(tween_resource.get_tween_data_count() == 1, "数据数量应该不变")
	print("✅ test_remove_tween_data_invalid_index passed")

func _test_clear_tween_data():
	tween_resource = JuicyTweenResource.new()
	tween_resource.add_tween_data("position", Vector2.ZERO, Vector2(100, 100), 1.0)
	tween_resource.add_tween_data("scale", Vector2.ONE, Vector2(2, 2), 0.5)
	tween_resource.add_tween_data("rotation", 0.0, 90.0, 2.0)
	
	assert(tween_resource.get_tween_data_count() == 3, "应该有三个补间数据")
	
	tween_resource.clear_tween_data()
	assert(tween_resource.get_tween_data_count() == 0, "清除后应该没有数据")
	print("✅ test_clear_tween_data passed")

func _test_get_tween_data_invalid_index():
	tween_resource = JuicyTweenResource.new()
	tween_resource.add_tween_data("position", Vector2.ZERO, Vector2(100, 100), 1.0)
	
	var data = tween_resource.get_tween_data(-1)
	assert(data == null, "无效索引应该返回null")
	
	data = tween_resource.get_tween_data(10)
	assert(data == null, "超出范围的索引应该返回null")
	print("✅ test_get_tween_data_invalid_index passed")

func _test_loop_properties():
	tween_resource = JuicyTweenResource.new()
	assert(not tween_resource.loop, "默认不应该循环")
	assert(tween_resource.loop_delay == 0.0, "默认循环延迟应该为0")
	
	tween_resource.loop = true
	tween_resource.loop_delay = 2.0
	
	assert(tween_resource.loop, "应该能设置循环")
	assert(tween_resource.loop_delay == 2.0, "应该能设置循环延迟")
	print("✅ test_loop_properties passed")

func _test_create_drivers():
	tween_resource = JuicyTweenResource.new()
	var drivers = tween_resource.create_drivers()
	
	assert(drivers.size() == 1, "应该创建一个驱动器")
	assert(drivers[0] != null, "驱动器不应该为null")
	assert(drivers[0] is JuicyTweenDriver, "应该创建 JuicyTweenDriver 实例")
	print("✅ test_create_drivers passed")

func _test_string_representation():
	tween_resource = JuicyTweenResource.new()
	tween_resource.add_tween_data("position", Vector2.ZERO, Vector2(100, 100), 1.0)
	tween_resource.add_tween_data("scale", Vector2.ONE, Vector2(2, 2), 0.5)
	tween_resource.duration = 2.0
	tween_resource.loop = true
	
	var str_repr = tween_resource._to_string()
	
	assert(str_repr.find("JuicyTweenResource") >= 0, "字符串表示应该包含资源类型")
	assert(str_repr.find("tween_count=2") >= 0, "字符串表示应该包含数据数量")
	assert(str_repr.find("duration=2.00") >= 0, "字符串表示应该包含持续时间")
	assert(str_repr.find("loop=true") >= 0, "字符串表示应该包含循环信息")
	print("✅ test_string_representation passed")

func _test_configuration_warning():
	tween_resource = JuicyTweenResource.new()
	# 测试有效配置
	tween_resource.add_tween_data("position", Vector2.ZERO, Vector2(100, 100), 1.0)
	var warning = tween_resource._get_configuration_warning()
	assert(warning == "", "有效配置不应该有警告")
	
	# 测试无效配置
	tween_resource.clear_tween_data()
	warning = tween_resource._get_configuration_warning()
	assert(warning.find("Configuration errors") >= 0, "无效配置应该有错误警告")
	print("✅ test_configuration_warning passed")