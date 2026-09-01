# tests/threading/test_performance_benchmark.gd
## 性能基准测试脚本
## 测试 FuseTaskManager 和 ParallelConditionEvaluator 的性能
extends Node

## 测试目标
var evaluator: ParallelConditionEvaluator

func _ready():
	print("=== 性能基准测试开始 ===\n")

	test_sequential_vs_parallel()
	test_scalability()

	print("\n=== 性能基准测试完成 ===")

## 测试串行 vs 并行性能
func test_sequential_vs_parallel():
	print("测试 1: 串行 vs 并行性能")

	evaluator = ParallelConditionEvaluator.new()
	evaluator.evaluation_mode = ParallelConditionEvaluator.EvaluationMode.SEQUENTIAL

	var context = ExecutionContext.new(null, null)

	# 创建测试条件（线程安全）
	var conditions: Array[BaseCondition] = []
	for i in range(100):
		var cond = CheckVariable.new()
		cond.variable_name = "thread_test_%d" % i
		cond.variable_scope = BaseVariable.VariableScope.LOCAL
		cond._thread_safety_cached = true
		cond._thread_safety_computed = true
		conditions.append(cond)

	# 性能测试：串行 vs 并行
	var serial_start = Time.get_ticks_usec()
	var serial_results = evaluator.evaluate_parallel(context, conditions)
	var serial_time = Time.get_ticks_usec() - serial_start

	print("  串行评估了 %d 个条件，耗时: %d 微秒" % [conditions.size(), serial_time])

	# 并行评估
	evaluator.evaluation_mode = ParallelConditionEvaluator.EvaluationMode.PARALLEL_SAFE
	evaluator.reset_statistics()
	var parallel_start = Time.get_ticks_usec()
	var parallel_results = evaluator.evaluate_parallel(context, conditions)
	var parallel_time = Time.get_ticks_usec() - parallel_start

	print("  并行评估了 %d 个条件，耗时: %d 微秒" % [conditions.size(), parallel_time])

	# 验证结果一致性
	assert(serial_results.size() == parallel_results.size(), "串行和并行结果数量应一致")

	print("\n=== 性能基准测试结果 ===")
	print("条件数量: %d" % conditions.size())
	print("串行时间: %d 微秒" % serial_time)
	print("并行时间: %d 微秒" % parallel_time)

	if parallel_time > 0:
		var speedup = float(serial_time) / float(parallel_time)
		print("加速比: %.2fx" % speedup)

	# 注意：并行不一定总是更快，取决于条件和硬件
	# 这个测试主要用于记录性能数据，不做严格断言
	print("  ✓ 性能基准测试通过\n")

## 测试扩展性
func test_scalability():
	print("测试 2: 扩展性测试")

	evaluator = ParallelConditionEvaluator.new()
	evaluator.evaluation_mode = ParallelConditionEvaluator.EvaluationMode.SEQUENTIAL

	var context = ExecutionContext.new(null, null)
	var conditions: Array[BaseCondition] = []

	for i in range(200):
		var cond = CheckVariable.new()
		cond.variable_name = "scalability_test_%d" % i
		cond.variable_scope = BaseVariable.VariableScope.LOCAL
		cond._thread_safety_cached = true
		cond._thread_safety_computed = true
		conditions.append(cond)

	# 性能测试：串行 vs 并行
	var serial_start = Time.get_ticks_usec()
	var serial_results = evaluator.evaluate_parallel(context, conditions)
	var serial_time = Time.get_ticks_usec() - serial_start

	print("  串行评估了 %d 个条件，耗时: %d 微秒" % [conditions.size(), serial_time])

	# 并行评估
	evaluator.evaluation_mode = ParallelConditionEvaluator.EvaluationMode.PARALLEL_SAFE
	evaluator.reset_statistics()
	var parallel_start = Time.get_ticks_usec()
	var parallel_results = evaluator.evaluate_parallel(context, conditions)
	var parallel_time = Time.get_ticks_usec() - parallel_start

	print("  并行评估了 %d 个条件，耗时: %d 微秒" % [conditions.size(), parallel_time])

	# 验证结果一致性
	assert(serial_results.size() == parallel_results.size(), "串行和并行结果数量应一致")

	print("\n=== 扩展性测试结果 ===")
	print("条件数量: %d" % conditions.size())
	print("串行时间: %d 微秒" % serial_time)
	print("并行时间: %d 微秒" % parallel_time)

	if parallel_time > 0:
		var speedup = float(serial_time) / float(parallel_time)
		print("加速比: %.2fx" % speedup)

	# 注意：并行不一定总是更快，取决于条件和硬件
	# 这个测试主要用于记录性能数据，不做严格断言
	print("  ✓ 扩展性测试通过\n")
