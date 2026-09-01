extends Node

# 测试 RunTargetNodeFunction 性能优化的脚本
class_name TestRunTargetNodeFunctionPerformance

var test_instruction: RunTargetNodeFunction
var test_context: ExecutionContext

func _ready():
	print("=== RunTargetNodeFunction 性能测试开始 ===")
	setup_test_environment()
	run_performance_tests()
	print("=== 性能测试完成 ===")

func setup_test_environment():
	# 创建测试指令实例
	test_instruction = RunTargetNodeFunction.new()

	# 创建测试上下文（使用真实的 ExecutionContext）
	test_context = ExecutionContext.new(self, self)

	# 设置测试目标节点（指向自身）
	test_instruction.target_node = get_path()
	test_instruction.target_function = "test_method"

	# 添加一些测试参数
	test_instruction.function_args = ["test_param", 42, Vector2(1, 2)]

	# 性能优化：减少日志输出，设置为 WARNING 级别
	test_instruction.log_level = FuseLogger.LogLevel.WARNING

	print("测试环境设置完成")

func test_method(param1: String, param2: int, param3: Vector2) -> String:
	# 模拟一个简单的方法调用
	return "执行成功: %s, %d, %s" % [param1, param2, param3]

func run_performance_tests():
	print("\n--- 测试1: 重复执行性能 ---")
	test_repeated_execution()

	print("\n--- 测试2: 属性更新性能 ---")
	test_property_updates()

	print("\n--- 测试3: 节点查找性能 ---")
	test_node_lookup_performance()

	print("\n--- 测试4: 方法缓存性能 ---")
	test_method_cache_performance()

func test_repeated_execution():
	var iterations = 100
	var start_time = Time.get_ticks_msec()

	for i in range(iterations):
		test_instruction.execute(test_context)

	var end_time = Time.get_ticks_msec()
	var total_time = end_time - start_time
	var avg_time = float(total_time) / iterations

	print("重复执行 %d 次总耗时: %d ms" % [iterations, total_time])
	print("平均每次执行耗时: %.2f ms" % avg_time)

	# 输出性能统计
	print_performance_stats()

	# 重置统计以进行下一个测试
	test_instruction.reset_performance_stats()

func test_property_updates():
	var iterations = 50
	var start_time = Time.get_ticks_msec()

	for i in range(iterations):
		test_instruction.target_function = "test_method_%d" % i
		test_instruction.function_args = ["param_%d" % i, i, Vector2(i, i)]
		test_instruction.store_result = (i % 2 == 0)

	var end_time = Time.get_ticks_msec()
	var total_time = end_time - start_time
	var avg_time = float(total_time) / iterations

	print("属性更新 %d 次总耗时: %d ms" % [iterations, total_time])
	print("平均每次属性更新耗时: %.2f ms" % avg_time)

	# 重置统计以进行下一个测试
	test_instruction.reset_performance_stats()

func test_node_lookup_performance():
	var iterations = 30
	var start_time = Time.get_ticks_msec()

	for i in range(iterations):
		# 重置节点实例，强制重新查找
		test_instruction._target_node_instance = null
		var node = test_instruction._get_target_node()

	var end_time = Time.get_ticks_msec()
	var total_time = end_time - start_time
	var avg_time = float(total_time) / iterations

	print("节点查找 %d 次总耗时: %d ms" % [iterations, total_time])
	print("平均每次节点查找耗时: %.2f ms" % avg_time)

	# 重置统计以进行下一个测试
	test_instruction.reset_performance_stats()

func test_method_cache_performance():
	var iterations = 20
	var start_time = Time.get_ticks_msec()

	for i in range(iterations):
		# 重置缓存，强制重新刷新
		test_instruction._cache_valid = false
		test_instruction._refresh_method_cache()

	var end_time = Time.get_ticks_msec()
	var total_time = end_time - start_time
	var avg_time = float(total_time) / iterations

	print("方法缓存刷新 %d 次总耗时: %d ms" % [iterations, total_time])
	print("平均每次方法缓存刷新耗时: %.2f ms" % avg_time)

	# 重置统计以进行下一个测试
	test_instruction.reset_performance_stats()

func print_performance_stats():
	if test_instruction and test_instruction.has_method("_log_performance_stats"):
		test_instruction._log_performance_stats()
	else:
		print("无法获取性能统计信息")

# 测试用的简单方法，不需要模拟类
