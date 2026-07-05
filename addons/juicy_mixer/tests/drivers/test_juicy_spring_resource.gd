# 测试 JuicySpringResource 功能
extends Node

var spring_resource: JuicySpringResource
var test_target: Node2D

func _ready():
	# 运行所有测试
	_test_create_instance()
	_test_add_spring_data()
	_test_validate_config_empty()
	_test_validate_config_valid()
	_test_validate_config_invalid_data()
	_test_validate_config_duplicate_properties()
	_test_remove_spring_data()
	_test_remove_spring_data_invalid_index()
	_test_clear_spring_data()
	_test_get_spring_data_invalid_index()
	_test_loop_properties()
	_test_create_drivers()
	_test_string_representation()
	_test_configuration_warning()
	_test_spring_data_validation()
	
	print("✅ All JuicySpringResource tests passed!")

func _test_create_instance():
	spring_resource = JuicySpringResource.new()
	assert(spring_resource != null, "应该能创建 JuicySpringResource 实例")
	assert(spring_resource.get_resource_type() == "JuicySpringResource", "资源类型应该正确")
	print("✅ test_create_instance passed")

func _test_add_spring_data():
	spring_resource = JuicySpringResource.new()
	var data = spring_resource.add_spring_data("position", Vector2(100, 0), 50.0, 5.0, 1.0, Vector2.ZERO, 0.1)
	
	assert(data != null, "应该返回有效的 SpringData 实例")
	assert(spring_resource.get_spring_data_count() == 1, "应该有一个弹簧数据")
	assert(data.property == "position", "属性名称应该正确")
	assert(data.target_value == Vector2(100, 0), "目标值应该正确")
	assert(data.stiffness == 50.0, "刚度应该正确")
	assert(data.damping == 5.0, "阻尼应该正确")
	assert(data.mass == 1.0, "质量应该正确")
	assert(data.initial_velocity == Vector2.ZERO, "初始速度应该正确")
	assert(data.threshold == 0.1, "阈值应该正确")
	print("✅ test_add_spring_data passed")

func _test_validate_config_empty():
	spring_resource = JuicySpringResource.new()
	var result = spring_resource.validate_config()
	
	assert(not result.valid, "空配置应该无效")
	assert(result.issues.size() > 0, "应该有错误信息")
	assert("Spring data cannot be empty" in result.issues, "应该提示弹簧数据为空")
	print("✅ test_validate_config_empty passed")

func _test_validate_config_valid():
	spring_resource = JuicySpringResource.new()
	# 添加有效的弹簧数据
	spring_resource.add_spring_data("position", Vector2(100, 0), 50.0, 5.0, 1.0)
	spring_resource.add_spring_data("scale", Vector2(2, 2), 30.0, 3.0, 0.5)
	
	var result = spring_resource.validate_config()
	
	assert(result.valid, "有效配置应该通过验证")
	assert(result.issues.is_empty(), "不应该有错误")
	print("✅ test_validate_config_valid passed")

func _test_validate_config_invalid_data():
	spring_resource = JuicySpringResource.new()
	# 添加无效的弹簧数据
	var data = SpringData.new()
	data.property = ""  # 空属性名
	data.stiffness = 0.0  # 无效刚度
	data.damping = -1.0  # 无效阻尼
	data.mass = 0.0  # 无效质量
	spring_resource.spring_data.append(data)
	
	var result = spring_resource.validate_config()
	
	assert(not result.valid, "无效数据应该导致验证失败")
	assert(result.issues.size() > 0, "应该有错误信息")
	print("✅ test_validate_config_invalid_data passed")

func _test_validate_config_duplicate_properties():
	spring_resource = JuicySpringResource.new()
	# 添加重复的属性
	spring_resource.add_spring_data("position", Vector2(100, 0), 50.0, 5.0, 1.0)
	spring_resource.add_spring_data("position", Vector2(150, 0), 30.0, 3.0, 0.5)
	
	var result = spring_resource.validate_config()
	
	assert(result.valid, "重复属性不应该导致验证失败")
	assert(result.warnings.size() > 0, "应该有警告信息")
	assert("Duplicate property name: position" in result.warnings, "应该警告重复属性")
	print("✅ test_validate_config_duplicate_properties passed")

func _test_remove_spring_data():
	spring_resource = JuicySpringResource.new()
	spring_resource.add_spring_data("position", Vector2(100, 0), 50.0, 5.0, 1.0)
	spring_resource.add_spring_data("scale", Vector2(2, 2), 30.0, 3.0, 0.5)
	
	assert(spring_resource.get_spring_data_count() == 2, "应该有两个弹簧数据")
	
	var removed = spring_resource.remove_spring_data(0)
	assert(removed, "应该成功移除第一个数据")
	assert(spring_resource.get_spring_data_count() == 1, "应该只剩下一个数据")
	
	# 验证剩余的数据
	var remaining_data = spring_resource.get_spring_data(0)
	assert(remaining_data != null, "应该还有剩余数据")
	assert(remaining_data.property == "scale", "剩余数据应该是scale")
	print("✅ test_remove_spring_data passed")

func _test_remove_spring_data_invalid_index():
	spring_resource = JuicySpringResource.new()
	spring_resource.add_spring_data("position", Vector2(100, 0), 50.0, 5.0, 1.0)
	
	var removed = spring_resource.remove_spring_data(-1)
	assert(not removed, "无效索引应该返回false")
	
	removed = spring_resource.remove_spring_data(10)
	assert(not removed, "超出范围的索引应该返回false")
	
	assert(spring_resource.get_spring_data_count() == 1, "数据数量应该不变")
	print("✅ test_remove_spring_data_invalid_index passed")

func _test_clear_spring_data():
	spring_resource = JuicySpringResource.new()
	spring_resource.add_spring_data("position", Vector2(100, 0), 50.0, 5.0, 1.0)
	spring_resource.add_spring_data("scale", Vector2(2, 2), 30.0, 3.0, 0.5)
	spring_resource.add_spring_data("rotation", 90.0, 40.0, 2.0, 2.0)
	
	assert(spring_resource.get_spring_data_count() == 3, "应该有三个弹簧数据")
	
	spring_resource.clear_spring_data()
	assert(spring_resource.get_spring_data_count() == 0, "清除后应该没有数据")
	print("✅ test_clear_spring_data passed")

func _test_get_spring_data_invalid_index():
	spring_resource = JuicySpringResource.new()
	spring_resource.add_spring_data("position", Vector2(100, 0), 50.0, 5.0, 1.0)
	
	var data = spring_resource.get_spring_data(-1)
	assert(data == null, "无效索引应该返回null")
	
	data = spring_resource.get_spring_data(10)
	assert(data == null, "超出范围的索引应该返回null")
	print("✅ test_get_spring_data_invalid_index passed")

func _test_loop_properties():
	spring_resource = JuicySpringResource.new()
	assert(not spring_resource.loop, "默认不应该循环")
	assert(spring_resource.loop_delay == 0.0, "默认循环延迟应该为0")
	
	spring_resource.loop = true
	spring_resource.loop_delay = 2.0
	
	assert(spring_resource.loop, "应该能设置循环")
	assert(spring_resource.loop_delay == 2.0, "应该能设置循环延迟")
	print("✅ test_loop_properties passed")

func _test_create_drivers():
	spring_resource = JuicySpringResource.new()
	var drivers = spring_resource.create_drivers()
	
	assert(drivers.size() == 1, "应该创建一个驱动器")
	assert(drivers[0] != null, "驱动器不应该为null")
	assert(drivers[0] is JuicySpringDriver, "应该创建 JuicySpringDriver 实例")
	print("✅ test_create_drivers passed")

func _test_string_representation():
	spring_resource = JuicySpringResource.new()
	spring_resource.add_spring_data("position", Vector2(100, 0), 50.0, 5.0, 1.0)
	spring_resource.add_spring_data("scale", Vector2(2, 2), 30.0, 3.0, 0.5)
	spring_resource.duration = 2.0
	spring_resource.loop = true
	
	var str_repr = spring_resource._to_string()
	
	assert(str_repr.find("JuicySpringResource") >= 0, "字符串表示应该包含资源类型")
	assert(str_repr.find("spring_count=2") >= 0, "字符串表示应该包含数据数量")
	assert(str_repr.find("duration=2.00") >= 0, "字符串表示应该包含持续时间")
	assert(str_repr.find("loop=true") >= 0, "字符串表示应该包含循环信息")
	print("✅ test_string_representation passed")

func _test_configuration_warning():
	spring_resource = JuicySpringResource.new()
	# 测试有效配置
	spring_resource.add_spring_data("position", Vector2(100, 0), 50.0, 5.0, 1.0)
	var warning = spring_resource._get_configuration_warning()
	assert(warning == "", "有效配置不应该有警告")
	
	# 测试无效配置
	spring_resource.clear_spring_data()
	warning = spring_resource._get_configuration_warning()
	assert(warning.find("Configuration errors") >= 0, "无效配置应该有错误警告")
	print("✅ test_configuration_warning passed")

func _test_spring_data_validation():
	spring_resource = JuicySpringResource.new()
	var data = spring_resource.add_spring_data("position", Vector2(100, 0), 50.0, 5.0, 1.0)
	var result = data.validate()
	
	assert(result.valid, "有效弹簧数据应该通过验证")
	
	# 测试无效数据
	data.property = ""
	data.stiffness = 0.0
	data.damping = -1.0
	data.mass = 0.0
	data.threshold = 0.0
	
	result = data.validate()
	assert(not result.valid, "无效数据应该验证失败")
	assert(result.issues.size() > 0, "应该有错误信息")
	print("✅ test_spring_data_validation passed")