# 条件系统集成测试
# 测试条件系统与组合系统的协同工作

extends Node

func test_composite_item_with_time_condition():
	# 创建组合项
	var item = JuicyCompositeItem.new()
	item.resource = load("res://addons/juicy_mixer/resources/juicy_shake_resource.gd").new()
	item.weight = 1.0
	
	# 添加时间条件
	var time_condition = JuicyTimeCondition.new()
	time_condition.time_operator = JuicyTimeCondition.TimeOperator.AFTER_START
	time_condition.target_time = 0.5
	time_condition.enabled = true
	item.condition = time_condition
	
	# 验证项目
	var errors = item.validate_item()
	assert(errors.is_empty(), "验证应该通过: " + errors)
	
	# 测试条件描述
	var desc = item.get_description()
	assert(desc.find("time") != -1, "描述应该包含时间条件信息: " + desc)
	
	print("✓ 组合项时间条件测试通过")

func test_composite_item_with_parameter_condition():
	# 创建组合项
	var item = JuicyCompositeItem.new()
	item.resource = load("res://addons/juicy_mixer/resources/juicy_shake_resource.gd").new()
	item.weight = 1.0
	
	# 添加参数条件
	var param_condition = JuicyParameterCondition.new()
	param_condition.parameter_name = "intensity"
	param_condition.operator = JuicyParameterCondition.ComparisonOperator.GREATER_THAN
	param_condition.target_value = 0.5
	param_condition.enabled = true
	item.condition = param_condition
	
	# 验证项目
	var errors = item.validate_item()
	assert(errors.is_empty(), "验证应该通过: " + errors)
	
	# 测试条件描述
	var desc = item.get_description()
	assert(desc.find("intensity") != -1, "描述应该包含参数条件信息: " + desc)
	
	print("✓ 组合项参数条件测试通过")

func test_composite_item_with_composite_condition():
	# 创建组合项
	var item = JuicyCompositeItem.new()
	item.resource = load("res://addons/juicy_mixer/resources/juicy_shake_resource.gd").new()
	item.weight = 1.0
	
	# 创建复合条件
	var composite_condition = JuicyCompositeCondition.new()
	composite_condition.operator = JuicyCompositeCondition.LogicalOperator.AND
	
	# 添加子条件
	var time_condition = JuicyTimeCondition.new()
	time_condition.time_operator = JuicyTimeCondition.TimeOperator.AFTER_START
	time_condition.target_time = 0.2
	composite_condition.conditions.append(time_condition)
	
	var param_condition = JuicyParameterCondition.new()
	param_condition.parameter_name = "intensity"
	param_condition.operator = JuicyParameterCondition.ComparisonOperator.GREATER_THAN
	param_condition.target_value = 0.3
	composite_condition.conditions.append(param_condition)
	
	composite_condition.enabled = true
	item.condition = composite_condition
	
	# 验证项目
	var errors = item.validate_item()
	assert(errors.is_empty(), "验证应该通过: " + errors)
	
	# 测试条件描述
	var desc = item.get_description()
	assert(desc.find("AND") != -1, "描述应该包含复合条件信息: " + desc)
	
	print("✓ 组合项复合条件测试通过")

func test_composite_resource_validation():
	# 创建组合资源
	var composite = JuicyCompositeItem.new()
	composite.resource = load("res://addons/juicy_mixer/resources/juicy_shake_resource.gd").new()
	composite.weight = 1.0
	
	# 添加有效条件（禁用状态）
	var disabled_condition = JuicyTimeCondition.new()
	disabled_condition.enabled = false
	disabled_condition.target_time = 1.0  # 有效值
	composite.condition = disabled_condition
	
	# 验证应该通过（条件被禁用）
	var errors = composite.validate_item()
	assert(errors.is_empty(), "禁用条件的验证应该通过: " + errors)
	
	print("✓ 组合资源条件验证测试通过")

func test_condition_validation_errors():
	# 创建组合项
	var item = JuicyCompositeItem.new()
	item.resource = load("res://addons/juicy_mixer/resources/juicy_shake_resource.gd").new()
	item.weight = 1.0
	
	# 添加有验证错误的条件
	var invalid_condition = JuicyTimeCondition.new()
	invalid_condition.enabled = true
	invalid_condition.target_time = -1.0  # 负时间是无效的
	item.condition = invalid_condition
	
	# 验证应该失败
	var errors = item.validate_item()
	assert(errors.find("negative") != -1, "验证应该检测到负时间错误: " + errors)
	
	print("✓ 条件验证错误测试通过")

func test_parameter_condition_validation():
	# 创建参数条件
	var param_condition = JuicyParameterCondition.new()
	param_condition.parameter_name = ""  # 空参数名
	param_condition.enabled = true
	
	# 验证应该失败
	var errors = param_condition.validate_condition()
	assert(errors.find("empty") != -1, "验证应该检测到空参数名: " + errors)
	
	# 修复参数名
	param_condition.parameter_name = "test_param"
	errors = param_condition.validate_condition()
	assert(errors.is_empty(), "修复后的验证应该通过: " + errors)
	
	print("✓ 参数条件验证测试通过")

func _ready():
	test_composite_item_with_time_condition()
	test_composite_item_with_parameter_condition()
	test_composite_item_with_composite_condition()
	test_composite_resource_validation()
	test_condition_validation_errors()
	test_parameter_condition_validation()
	
	print("🎉 所有条件系统集成测试通过！")
