# addons/fuse/tests/threading/test_parallel_condition_evaluator.gd
## ParallelConditionEvaluator 测试脚本
## 测试串行模式、并行安全模式、并行所有模式
extends Node

## 测试目标
var evaluator: ParallelConditionEvaluator

func _ready():
	print("=== ParallelConditionEvaluator 测试开始 ===\n")

	test_sequential_evaluation()
	test_parallel_safe_evaluation()
	test_empty_conditions()
	test_statistics()
	test_reset_statistics()
	test_single_condition()

	print("\n=== ParallelConditionEvaluator 测试完成 ===")

## 测试串行评估模式
func test_sequential_evaluation():
	print("测试 1: 串行评估模式")

	evaluator = ParallelConditionEvaluator.new()
	evaluator.evaluation_mode = ParallelConditionEvaluator.EvaluationMode.SEQUENTIAL

	var context = ExecutionContext.new(null, null)

	# 创建测试条件
	var conditions: Array[BaseCondition] = []
	for i in range(5):
		var cond = CheckVariable.new()
		cond.variable_name = "test_%d" % i
		cond.variable_scope = BaseVariable.VariableScope.LOCAL
		conditions.append(cond)

	var results = evaluator.evaluate_parallel(context, conditions)

	assert(results.size() == 5, "应该返回 5 个结果")
	print("  评估了 %d 个条件" % results.size())
	print("  ✓ 串行评估模式测试通过\n")

## 测试并行安全评估模式
func test_parallel_safe_evaluation():
	print("测试 2: 并行安全评估模式")

	evaluator = ParallelConditionEvaluator.new()
	evaluator.evaluation_mode = ParallelConditionEvaluator.EvaluationMode.PARALLEL_SAFE

	var context = ExecutionContext.new(null, null)

	# 创建线程安全的测试条件（LOCAL 作用域）
	var conditions: Array[BaseCondition] = []
	for i in range(10):
		var cond = CheckVariable.new()
		cond.variable_name = "parallel_test_%d" % i
		cond.variable_scope = BaseVariable.VariableScope.LOCAL
		conditions.append(cond)

	var start_time = Time.get_ticks_usec()
	var results = evaluator.evaluate_parallel(context, conditions)
	var elapsed = Time.get_ticks_usec() - start_time

	assert(results.size() == 10, "应该返回 10 个结果")
	print("  评估了 %d 个条件，耗时 %d 微秒" % [results.size(), elapsed])
	print("  ✓ 并行安全评估模式测试通过\n")

## 测试空条件数组
func test_empty_conditions():
	print("测试 3: 空条件数组")

	evaluator = ParallelConditionEvaluator.new()
	var context = ExecutionContext.new(null, null)
	var conditions: Array[BaseCondition] = []

	var results = evaluator.evaluate_parallel(context, conditions)

	assert(results.size() == 0, "空条件数组应返回空结果")
	print("  空条件返回 %d 个结果" % results.size())
	print("  ✓ 空条件数组测试通过\n")

## 测试统计信息
func test_statistics():
	print("测试 4: 统计信息")

	evaluator = ParallelConditionEvaluator.new()
	evaluator.evaluation_mode = ParallelConditionEvaluator.EvaluationMode.SEQUENTIAL

	var context = ExecutionContext.new(null, null)
	var conditions: Array[BaseCondition] = []
	for i in range(10):
		var cond = CheckVariable.new()
		cond.variable_name = "stats_test_%d" % i
		cond.variable_scope = BaseVariable.VariableScope.LOCAL
		conditions.append(cond)

	evaluator.evaluate_parallel(context, conditions)

	var stats = evaluator.get_statistics()
	print("  评估条件数: %d" % stats["total_conditions_evaluated"])
	print("  评估模式: %s" % stats["evaluation_mode"])

	assert(stats["total_conditions_evaluated"] >= 10, "应该记录评估的条件数")
	print("  ✓ 统计信息测试通过\n")

## 测试重置统计信息
func test_reset_statistics():
	print("测试 5: 重置统计信息")

	evaluator = ParallelConditionEvaluator.new()

	# 先执行一些评估
	var context = ExecutionContext.new(null, null)
	var conditions: Array[BaseCondition] = []
	for i in range(5):
		var cond = CheckVariable.new()
		cond.variable_name = "reset_test_%d" % i
		cond.variable_scope = BaseVariable.VariableScope.LOCAL
		conditions.append(cond)

	evaluator.evaluation_mode = ParallelConditionEvaluator.EvaluationMode.SEQUENTIAL
	evaluator.evaluate_parallel(context, conditions)

	# 重置
	evaluator.reset_statistics()

	var stats = evaluator.get_statistics()
	assert(stats["last_evaluation_time"] == 0.0, "重置后时间应为 0")
	assert(stats["total_conditions_evaluated"] == 0, "重置后计数应为 0")
	print("  重置后 last_evaluation_time: %f" % stats["last_evaluation_time"])
	print("  重置后 total_conditions_evaluated: %d" % stats["total_conditions_evaluated"])
	print("  ✓ 重置统计信息测试通过\n")

## 测试单个条件
func test_single_condition():
	print("测试 6: 单个条件评估")

	evaluator = ParallelConditionEvaluator.new()
	evaluator.evaluation_mode = ParallelConditionEvaluator.EvaluationMode.SEQUENTIAL

	var context = ExecutionContext.new(null, null)
	context.set_variable("single_test", 42)

	var cond = CheckVariable.new()
	cond.variable_name = "single_test"
	cond.variable_scope = BaseVariable.VariableScope.LOCAL
	cond.comparison_operator = CheckVariable.ComparisonOperator.EQUALS
	cond.expected_value = 42

	var conditions: Array[BaseCondition] = [cond]
	var results = evaluator.evaluate_parallel(context, conditions)

	assert(results.size() == 1, "应该返回 1 个结果")
	assert(results[0] == true, "条件应该满足")
	print("  单个条件评估结果: %s" % str(results[0]))
	print("  ✓ 单个条件评估测试通过\n")
