# 条件系统单元测试
# 测试所有条件类的基本功能、验证和性能优化

extends Node

# 测试统计
var _tests_run = 0
var _tests_passed = 0
var _tests_failed = 0

# 断言辅助函数
func assert_true(condition: bool, message: String = "") -> void:
	_tests_run += 1
	if condition:
		_tests_passed += 1
	else:
		_tests_failed += 1
		push_error("❌ 测试失败: " + message)

func assert_false(condition: bool, message: String = "") -> void:
	assert_true(not condition, message)

func assert_equals(expected, actual, message: String = "") -> void:
	_tests_run += 1
	if expected == actual:
		_tests_passed += 1
	else:
		_tests_failed += 1
		push_error("❌ 测试失败: %s (期望: %s, 实际: %s)" % [message, str(expected), str(actual)])

# 测试时间条件
func test_time_condition_basic():
	print("=== ⏰ 测试时间条件基本功能 ===")
	
	# 创建上下文
	var context = JuicyContext.new()
	context.duration = 5.0
	
	# 测试1: AFTER_START 操作符
	var after_condition = JuicyTimeCondition.new()
	after_condition.time_operator = JuicyTimeCondition.TimeOperator.AFTER_START
	after_condition.target_time = 1.0
	after_condition.enabled = true
	
	context.current_time = 0.5
	assert_false(after_condition.evaluate(context), "时间0.5s应该不满足AFTER_START 1.0s")
	
	context.current_time = 1.5
	assert_true(after_condition.evaluate(context), "时间1.5s应该满足AFTER_START 1.0s")
	
	# 测试2: BEFORE_END 操作符
	var before_condition = JuicyTimeCondition.new()
	before_condition.time_operator = JuicyTimeCondition.TimeOperator.BEFORE_END
	before_condition.target_time = 1.0  # 结束前1秒
	before_condition.enabled = true
	
	context.current_time = 3.5  # 总时长5.0，结束前1.5秒
	assert_true(before_condition.evaluate(context), "时间3.5s应该满足BEFORE_END 1.0s")
	
	context.current_time = 4.5  # 总时长5.0，结束前0.5秒
	assert_false(before_condition.evaluate(context), "时间4.5s应该不满足BEFORE_END 1.0s")
	
	# 测试3: DURATION_GREATER/LESS 操作符
	var duration_greater = JuicyTimeCondition.new()
	duration_greater.time_operator = JuicyTimeCondition.TimeOperator.DURATION_GREATER
	duration_greater.target_time = 3.0
	duration_greater.enabled = true
	
	context.duration = 4.0
	assert_true(duration_greater.evaluate(context), "时长4.0s应该满足DURATION_GREATER 3.0s")
	
	context.duration = 2.0
	assert_false(duration_greater.evaluate(context), "时长2.0s应该不满足DURATION_GREATER 3.0s")
	
	# 测试4: PROGRESS 操作符
	var progress_condition = JuicyTimeCondition.new()
	progress_condition.time_operator = JuicyTimeCondition.TimeOperator.PROGRESS_GREATER
	progress_condition.target_time = 0.5  # 50%进度
	progress_condition.use_progress = true
	progress_condition.enabled = true
	
	context.progress = 0.3
	assert_false(progress_condition.evaluate(context), "进度30%应该不满足PROGRESS_GREATER 50%")
	
	context.progress = 0.7
	assert_true(progress_condition.evaluate(context), "进度70%应该满足PROGRESS_GREATER 50%")
	
	print("✅ 时间条件基本功能测试通过")

# 测试时间条件验证
func test_time_condition_validation():
	print("=== ✅ 测试时间条件验证 ===")
	
	# 有效条件
	var valid_condition = JuicyTimeCondition.new()
	valid_condition.target_time = 1.0
	valid_condition.enabled = true
	
	var valid_errors = valid_condition.validate_condition()
	assert_true(valid_errors.is_empty(), "有效时间条件应该通过验证: " + valid_errors)
	
	# 无效条件：负时间
	var invalid_condition = JuicyTimeCondition.new()
	invalid_condition.target_time = -1.0
	invalid_condition.enabled = true
	
	var invalid_errors = invalid_condition.validate_condition()
	assert_false(invalid_errors.is_empty(), "负时间应该验证失败")
	assert_true(invalid_errors.find("negative") != -1, "错误信息应该包含negative")
	
	# 禁用条件（应该通过验证）
	var disabled_condition = JuicyTimeCondition.new()
	disabled_condition.target_time = -1.0
	disabled_condition.enabled = false
	
	var disabled_errors = disabled_condition.validate_condition()
	assert_true(disabled_errors.is_empty(), "禁用条件应该通过验证")
	
	print("✅ 时间条件验证测试通过")

# 测试参数条件
func test_parameter_condition_basic():
	print("=== 📊 测试参数条件基本功能 ===")
	
	var context = JuicyContext.new()
	context.set_parameter("test_param", 50.0)
	context.set_parameter("health", 75.0)
	
	# 测试所有比较操作符
	var operators = [
		JuicyParameterCondition.ComparisonOperator.GREATER_THAN,
		JuicyParameterCondition.ComparisonOperator.LESS_THAN,
		JuicyParameterCondition.ComparisonOperator.GREATER_EQUAL,
		JuicyParameterCondition.ComparisonOperator.LESS_EQUAL,
		JuicyParameterCondition.ComparisonOperator.EQUAL,
		JuicyParameterCondition.ComparisonOperator.NOT_EQUAL
	]
	
	var test_values = [40.0, 60.0, 50.0, 50.0, 50.0, 60.0]
	var expected_results = [true, true, true, true, true, true]
	
	for i in range(operators.size()):
		var condition = JuicyParameterCondition.new()
		condition.parameter_name = "test_param"
		condition.operator = operators[i]
		condition.target_value = test_values[i]
		condition.enabled = true
		
		var result = condition.evaluate(context)
		assert_equals(expected_results[i], result, "操作符 %d 测试结果" % i)
	
	print("✅ 参数条件基本功能测试通过")

# 测试参数条件缓存
func test_parameter_condition_caching():
	print("=== 💾 测试参数条件缓存 ===")
	
	var context = JuicyContext.new()
	context.set_parameter("cached_param", 25.0)
	
	var condition = JuicyParameterCondition.new()
	condition.parameter_name = "cached_param"
	condition.operator = JuicyParameterCondition.ComparisonOperator.GREATER_THAN
	condition.target_value = 20.0
	condition.enabled = true
	
	# 第一次评估（应该缓存）
	var result1 = condition.evaluate(context)
	assert_true(result1, "第一次评估应该为true")
	
	# 第二次评估（应该使用缓存）
	var result2 = condition.evaluate(context)
	assert_true(result2, "第二次评估应该为true（缓存）")
	
	# 修改参数值
	context.set_parameter("cached_param", 15.0)
	condition.on_parameter_changed("cached_param", 25.0, 15.0)
	
	# 第三次评估（应该重新计算）
	var result3 = condition.evaluate(context)
	assert_false(result3, "第三次评估应该为false（参数已改变）")
	
	print("✅ 参数条件缓存测试通过")

# 测试参数条件验证
func test_parameter_condition_validation():
	print("=== ✅ 测试参数条件验证 ===")
	
	# 有效条件
	var valid_condition = JuicyParameterCondition.new()
	valid_condition.parameter_name = "health"
	valid_condition.target_value = 50.0
	valid_condition.enabled = true
	
	var valid_errors = valid_condition.validate_condition()
	assert_true(valid_errors.is_empty(), "有效参数条件应该通过验证")
	
	# 无效条件：空参数名
	var invalid_condition = JuicyParameterCondition.new()
	invalid_condition.parameter_name = ""
	invalid_condition.enabled = true
	
	var invalid_errors = invalid_condition.validate_condition()
	assert_false(invalid_errors.is_empty(), "空参数名应该验证失败")
	assert_true(invalid_errors.find("empty") != -1, "错误信息应该包含empty")
	
	print("✅ 参数条件验证测试通过")

# 测试复合条件
func test_composite_condition_basic():
	print("=== 🔗 测试复合条件基本功能 ===")
	
	var context = JuicyContext.new()
	context.set_parameter("param1", 10.0)
	context.set_parameter("param2", 20.0)
	
	# 创建两个参数条件
	var condition1 = JuicyParameterCondition.new()
	condition1.parameter_name = "param1"
	condition1.operator = JuicyParameterCondition.ComparisonOperator.GREATER_THAN
	condition1.target_value = 5.0
	condition1.enabled = true
	
	var condition2 = JuicyParameterCondition.new()
	condition2.parameter_name = "param2"
	condition2.operator = JuicyParameterCondition.ComparisonOperator.LESS_THAN
	condition2.target_value = 25.0
	condition2.enabled = true
	
	# 测试AND操作符
	var and_composite = JuicyCompositeCondition.new()
	and_composite.operator = JuicyCompositeCondition.LogicalOperator.AND
	and_composite.conditions.append(condition1)
	and_composite.conditions.append(condition2)
	and_composite.enabled = true
	
	assert_true(and_composite.evaluate(context), "AND复合条件应该为true")
	
	# 测试OR操作符
	var or_composite = JuicyCompositeCondition.new()
	or_composite.operator = JuicyCompositeCondition.LogicalOperator.OR
	or_composite.conditions.append(condition1)
	or_composite.conditions.append(condition2)
	or_composite.enabled = true
	
	assert_true(or_composite.evaluate(context), "OR复合条件应该为true")
	
	# 测试AND失败情况
	context.set_parameter("param1", 3.0)  # 使condition1失败
	assert_false(and_composite.evaluate(context), "AND复合条件应该为false")
	assert_true(or_composite.evaluate(context), "OR复合条件应该仍为true")
	
	print("✅ 复合条件基本功能测试通过")

# 测试复合条件短路评估
func test_composite_condition_short_circuit():
	print("=== ⚡ 测试复合条件短路评估 ===")
	
	var context = JuicyContext.new()
	context.set_parameter("param", 10.0)
	
	# 创建评估计数器
	var eval_count = 0
	
	# 创建自定义条件（带评估计数）
	var condition1 = JuicyParameterCondition.new()
	condition1.parameter_name = "param"
	condition1.operator = JuicyParameterCondition.ComparisonOperator.GREATER_THAN
	condition1.target_value = 5.0
	condition1.enabled = true
	
	var condition2 = JuicyParameterCondition.new()
	condition2.parameter_name = "param"
	condition2.operator = JuicyParameterCondition.ComparisonOperator.LESS_THAN
	condition2.target_value = 15.0
	condition2.enabled = true
	
	# 测试AND短路（第一个条件失败时）
	context.set_parameter("param", 3.0)
	var and_composite = JuicyCompositeCondition.new()
	and_composite.operator = JuicyCompositeCondition.LogicalOperator.AND
	and_composite.conditions.append(condition1)
	and_composite.conditions.append(condition2)
	and_composite.enabled = true
	
	var result = and_composite.evaluate(context)
	assert_false(result, "AND复合条件应该为false")
	
	# 测试OR短路（第一个条件成功时）
	context.set_parameter("param", 10.0)
	var or_composite = JuicyCompositeCondition.new()
	or_composite.operator = JuicyCompositeCondition.LogicalOperator.OR
	or_composite.conditions.append(condition1)
	or_composite.conditions.append(condition2)
	or_composite.enabled = true
	
	result = or_composite.evaluate(context)
	assert_true(result, "OR复合条件应该为true")
	
	print("✅ 复合条件短路评估测试通过")

# 测试复合条件缓存
func test_composite_condition_caching():
	print("=== 💾 测试复合条件缓存 ===")
	
	var context = JuicyContext.new()
	context.set_parameter("param1", 10.0)
	context.set_parameter("param2", 20.0)
	context.context_id = "test_context"
	
	var condition1 = JuicyParameterCondition.new()
	condition1.parameter_name = "param1"
	condition1.operator = JuicyParameterCondition.ComparisonOperator.GREATER_THAN
	condition1.target_value = 5.0
	condition1.enabled = true
	
	var condition2 = JuicyParameterCondition.new()
	condition2.parameter_name = "param2"
	condition2.operator = JuicyParameterCondition.ComparisonOperator.LESS_THAN
	condition2.target_value = 25.0
	condition2.enabled = true
	
	var composite = JuicyCompositeCondition.new()
	composite.operator = JuicyCompositeCondition.LogicalOperator.AND
	composite.conditions.append(condition1)
	composite.conditions.append(condition2)
	composite.enabled = true
	
	# 第一次评估
	var result1 = composite.evaluate(context)
	assert_true(result1, "第一次评估应该为true")
	
	# 第二次评估（应该使用缓存）
	var result2 = composite.evaluate(context)
	assert_true(result2, "第二次评估应该为true（缓存）")
	
	# 修改参数并通知
	context.set_parameter("param1", 3.0)
	composite.on_parameter_changed("param1", 10.0, 3.0)
	
	# 第三次评估（缓存应该被清除）
	var result3 = composite.evaluate(context)
	assert_false(result3, "第三次评估应该为false")
	
	print("✅ 复合条件缓存测试通过")

# 测试复合条件验证
func test_composite_condition_validation():
	print("=== ✅ 测试复合条件验证 ===")
	
	# 无效条件：空条件数组
	var empty_composite = JuicyCompositeCondition.new()
	empty_composite.enabled = true
	
	var empty_errors = empty_composite.validate_condition()
	assert_false(empty_errors.is_empty(), "空条件数组应该验证失败")
	
	# 无效条件：包含null条件
	var null_composite = JuicyCompositeCondition.new()
	null_composite.conditions.append(null)
	null_composite.enabled = true
	
	var null_errors = null_composite.validate_condition()
	assert_false(null_errors.is_empty(), "包含null条件应该验证失败")
	
	# 无效条件：子条件验证失败
	var invalid_sub_condition = JuicyParameterCondition.new()
	invalid_sub_condition.parameter_name = ""  # 空参数名
	invalid_sub_condition.enabled = true
	
	var invalid_composite = JuicyCompositeCondition.new()
	invalid_composite.conditions.append(invalid_sub_condition)
	invalid_composite.enabled = true
	
	var invalid_errors = invalid_composite.validate_condition()
	assert_false(invalid_errors.is_empty(), "子条件验证失败应该导致复合条件验证失败")
	
	# 有效条件
	var valid_sub_condition = JuicyParameterCondition.new()
	valid_sub_condition.parameter_name = "test_param"
	valid_sub_condition.target_value = 10.0
	valid_sub_condition.enabled = true
	
	var valid_composite = JuicyCompositeCondition.new()
	valid_composite.conditions.append(valid_sub_condition)
	valid_composite.enabled = true
	
	var valid_errors = valid_composite.validate_condition()
	assert_true(valid_errors.is_empty(), "有效复合条件应该通过验证")
	
	print("✅ 复合条件验证测试通过")

# 测试条件描述生成
func test_condition_descriptions():
	print("=== 📝 测试条件描述生成 ===")
	
	# 时间条件描述
	var time_condition = JuicyTimeCondition.new()
	time_condition.time_operator = JuicyTimeCondition.TimeOperator.AFTER_START
	time_condition.target_time = 2.5
	time_condition.enabled = true
	
	var time_desc = time_condition.get_description()
	assert_true(time_desc.find("time") != -1, "时间条件描述应该包含time")
	assert_true(time_desc.find("2.5") != -1, "时间条件描述应该包含目标时间")
	
	# 参数条件描述
	var param_condition = JuicyParameterCondition.new()
	param_condition.parameter_name = "health"
	param_condition.operator = JuicyParameterCondition.ComparisonOperator.GREATER_THAN
	param_condition.target_value = 50.0
	param_condition.enabled = true
	
	var param_desc = param_condition.get_description()
	assert_true(param_desc.find("health") != -1, "参数条件描述应该包含参数名")
	assert_true(param_desc.find(">") != -1, "参数条件描述应该包含操作符")
	assert_true(param_desc.find("50") != -1, "参数条件描述应该包含目标值")
	
	# 复合条件描述
	var composite = JuicyCompositeCondition.new()
	composite.operator = JuicyCompositeCondition.LogicalOperator.AND
	composite.conditions.append(time_condition)
	composite.conditions.append(param_condition)
	composite.enabled = true
	
	var composite_desc = composite.get_description()
	assert_true(composite_desc.find("AND") != -1, "复合条件描述应该包含AND")
	assert_true(composite_desc.find("(") != -1, "复合条件描述应该包含括号")
	
	print("✅ 条件描述生成测试通过")

# 测试条件性能
func test_condition_performance():
	print("=== ⚡ 测试条件性能 ===")
	
	var context = JuicyContext.new()
	context.set_parameter("test_param", 50.0)
	
	# 创建各种条件
	var time_condition = JuicyTimeCondition.new()
	time_condition.time_operator = JuicyTimeCondition.TimeOperator.AFTER_START
	time_condition.target_time = 1.0
	time_condition.enabled = true
	
	var param_condition = JuicyParameterCondition.new()
	param_condition.parameter_name = "test_param"
	param_condition.operator = JuicyParameterCondition.ComparisonOperator.GREATER_THAN
	param_condition.target_value = 30.0
	param_condition.enabled = true
	
	var composite_condition = JuicyCompositeCondition.new()
	composite_condition.operator = JuicyCompositeCondition.LogicalOperator.AND
	composite_condition.conditions.append(time_condition)
	composite_condition.conditions.append(param_condition)
	composite_condition.enabled = true
	
	# 测试时间条件性能
	var start_time = Time.get_ticks_msec()
	for i in range(10000):
		time_condition.evaluate(context)
	var time_duration = Time.get_ticks_msec() - start_time
	
	print("  时间条件 10000次评估: %d ms (平均 %.3f ms/次)" % [time_duration, time_duration / 10000.0])
	
	# 测试参数条件性能
	start_time = Time.get_ticks_msec()
	for i in range(10000):
		param_condition.evaluate(context)
	var param_duration = Time.get_ticks_msec() - start_time
	
	print("  参数条件 10000次评估: %d ms (平均 %.3f ms/次)" % [param_duration, param_duration / 10000.0])
	
	# 测试复合条件性能
	start_time = Time.get_ticks_msec()
	for i in range(10000):
		composite_condition.evaluate(context)
	var composite_duration = Time.get_ticks_msec() - start_time
	
	print("  复合条件 10000次评估: %d ms (平均 %.3f ms/次)" % [composite_duration, composite_duration / 10000.0])
	
	# 性能要求：单次评估应该小于0.1ms
	assert_true(time_duration < 1000, "时间条件性能应该小于1000ms/10000次")
	assert_true(param_duration < 1000, "参数条件性能应该小于1000ms/10000次")
	assert_true(composite_duration < 2000, "复合条件性能应该小于2000ms/10000次")
	
	print("✅ 条件性能测试通过")

# 测试边界情况
func test_edge_cases():
	print("=== 🔍 测试边界情况 ===")
	
	var context = JuicyContext.new()
	
	# 测试1：禁用条件
	var disabled_condition = JuicyParameterCondition.new()
	disabled_condition.enabled = false
	disabled_condition.parameter_name = "test"
	disabled_condition.target_value = 10.0
	
	context.set_parameter("test", 15.0)
	assert_false(disabled_condition.evaluate(context), "禁用条件应该返回false")
	
	# 测试2：空上下文参数
	var missing_param_condition = JuicyParameterCondition.new()
	missing_param_condition.parameter_name = "missing_param"
	missing_param_condition.operator = JuicyParameterCondition.ComparisonOperator.GREATER_THAN
	missing_param_condition.target_value = 0.0
	missing_param_condition.enabled = true
	
	# 上下文没有这个参数，应该返回0.0
	var result = missing_param_condition.evaluate(context)
	assert_false(result, "缺失参数应该返回false（默认值为0.0）")
	
	# 测试3：浮点数精度
	var precision_condition = JuicyParameterCondition.new()
	precision_condition.parameter_name = "float_param"
	precision_condition.operator = JuicyParameterCondition.ComparisonOperator.EQUAL
	precision_condition.target_value = 0.1 + 0.2  # 应该是0.3，但可能有精度问题
	precision_condition.tolerance = 0.0001
	precision_condition.enabled = true
	
	context.set_parameter("float_param", 0.3)
	result = precision_condition.evaluate(context)
	assert_true(result, "浮点数比较应该考虑容差")
	
	# 测试4：极大/极小值
	var huge_condition = JuicyParameterCondition.new()
	huge_condition.parameter_name = "huge_param"
	huge_condition.operator = JuicyParameterCondition.ComparisonOperator.LESS_THAN
	huge_condition.target_value = 1e10
	huge_condition.enabled = true
	
	context.set_parameter("huge_param", 1e9)
	result = huge_condition.evaluate(context)
	assert_true(result, "极大值比较应该正常工作")
	
	print("✅ 边界情况测试通过")

# 运行所有测试
func run_all_tests():
	print("🚀 开始条件系统单元测试")
	print("==================================================")
	
	test_time_condition_basic()
	test_time_condition_validation()
	test_parameter_condition_basic()
	test_parameter_condition_caching()
	test_parameter_condition_validation()
	test_composite_condition_basic()
	test_composite_condition_short_circuit()
	test_composite_condition_caching()
	test_composite_condition_validation()
	test_condition_descriptions()
	test_condition_performance()
	test_edge_cases()
	
	print("==================================================")
	print("📊 测试统计:")
	print("  总测试数: %d" % _tests_run)
	print("  通过: %d" % _tests_passed)
	print("  失败: %d" % _tests_failed)
	
	if _tests_failed == 0:
		print("🎉 所有条件系统单元测试通过！")
	else:
		push_error("❌ 有 %d 个测试失败！" % _tests_failed)

func _ready():
	run_all_tests()
