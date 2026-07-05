# JuicyFeedbackResource 单元测试
# 测试反馈资源基类的配置和验证功能

extends Node

var _resource: Object

# 模拟具体的反馈资源子类
class MockFeedbackResource:
	extends Object
	
	var duration: float = 1.0
	var channel: String = "default"
	var priority: int = 0
	var time_group: String = ""
	var interruption_policy: String = "stack"
	
	func create_drivers() -> Array:
		# 返回模拟的驱动器数组
		return []
	
	func validate_config():
		var result = ValidationResult.new()
		
		# 基础验证
		if duration <= 0:
			result.valid = false
			result.issues.append("Duration must be greater than 0")
		
		if channel.is_empty():
			result.warnings.append("Empty channel name, using 'default'")
			channel = "default"
		
		return result
	
	func get_resource_type() -> String:
		return "MockFeedbackResource"
	
	func get_description() -> String:
		return "MockFeedbackResource: " + get_resource_type()
	
	func _get_property_list() -> Array[Dictionary]:
		var properties = []
		
		properties.append({
			"name": "interruption_policy",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "stack,restart,ignore,smooth_transition",
			"usage": PROPERTY_USAGE_DEFAULT
		})
		
		return properties
	
	func _to_string() -> String:
		return "%s(duration=%.2f, channel='%s')" % [get_resource_type(), duration, channel]

# 验证结果类
class ValidationResult:
	var valid: bool = true
	var issues: Array = []
	var warnings: Array = []

func _ready():
	_resource = MockFeedbackResource.new()
	
	# 运行测试
	_test_basic_properties()
	_test_validation()
	_test_resource_type()
	_test_string_representation()
	
	print("✅ All JuicyFeedbackResource tests passed!")

func _test_basic_properties():
	print("Testing basic resource properties...")
	
	# 测试默认属性
	assert(_resource.duration == 1.0, "Default duration should be 1.0")
	assert(_resource.channel == "default", "Default channel should be 'default'")
	assert(_resource.priority == 0, "Default priority should be 0")
	assert(_resource.time_group == "", "Default time_group should be empty")
	assert(_resource.interruption_policy == "stack", "Default interruption_policy should be 'stack'")
	
	# 测试属性修改
	_resource.duration = 2.5
	_resource.channel = "ui"
	_resource.priority = 5
	_resource.time_group = "effects"
	_resource.interruption_policy = "restart"
	
	assert(_resource.duration == 2.5, "Duration should be modifiable")
	assert(_resource.channel == "ui", "Channel should be modifiable")
	assert(_resource.priority == 5, "Priority should be modifiable")
	assert(_resource.time_group == "effects", "Time group should be modifiable")
	assert(_resource.interruption_policy == "restart", "Interruption policy should be modifiable")
	
	print("✅ Basic properties test passed")

func _test_validation():
	print("Testing resource validation...")
	
	# 测试有效配置
	_resource.duration = 1.0
	_resource.channel = "test"
	var valid_result = _resource.validate_config()
	
	assert(valid_result.valid == true, "Valid configuration should pass validation")
	assert(valid_result.issues.size() == 0, "Valid configuration should have no issues")
	
	# 测试无效配置 - 负持续时间
	_resource.duration = -1.0
	var invalid_result = _resource.validate_config()
	
	assert(invalid_result.valid == false, "Invalid configuration should fail validation")
	assert(invalid_result.issues.size() > 0, "Invalid configuration should have issues")
	assert("Duration must be greater than 0" in invalid_result.issues, "Should have duration error")
	
	# 测试空通道警告
	_resource.duration = 1.0
	_resource.channel = ""
	var warning_result = _resource.validate_config()
	
	assert(warning_result.valid == true, "Configuration with warnings should still be valid")
	assert(warning_result.warnings.size() > 0, "Should have warnings")
	assert(_resource.channel == "default", "Empty channel should be set to default")
	
	print("✅ Validation test passed")

func _test_resource_type():
	print("Testing resource type identification...")
	
	var resource_type = _resource.get_resource_type()
	assert(resource_type == "MockFeedbackResource", "Resource type should be correctly identified")
	
	var description = _resource.get_description()
	assert(description == "MockFeedbackResource: MockFeedbackResource", "Description should be correctly formatted")
	
	print("✅ Resource type test passed")

func _test_string_representation():
	print("Testing string representation...")
	
	_resource.duration = 2.5
	_resource.channel = "test_channel"
	
	var string_repr = _resource._to_string()
	assert(string_repr.find("MockFeedbackResource") != -1, "String representation should contain resource type")
	assert(string_repr.find("2.50") != -1, "String representation should contain duration")
	assert(string_repr.find("test_channel") != -1, "String representation should contain channel")
	
	print("✅ String representation test passed")

func _exit_tree():
	pass