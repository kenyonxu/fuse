extends Node

## ExecutionContext 变量查找性能测试
##
## 测试 ExecutionContext 变量查找的性能，验证日志优化的效果

func test_variable_lookup_performance():
	print("=== 变量查找性能测试 ===")

	var context = ExecutionContext.new()

	# 设置 100 个变量
	for i in range(100):
		context.set_variable("var_%d" % i, i)

	# 预热（避免首次分配影响）
	print("预热 100 次查找...")
	for i in range(1000):
		var value = context.get_variable("var_%d" % (i % 100))

	# 实际性能测试
	var iterations = 10000
	var start_time = Time.get_ticks_msec()

	for i in range(iterations):
		var value = context.get_variable("var_%d" % (i % 100))

	var elapsed = Time.get_ticks_msec() - start_time
	var ops_per_ms = float(iterations) / float(elapsed)

	print("✓ 变量查找性能: %.2f ops/ms (%.2f ms for %d lookups)" % [ops_per_ms, elapsed, iterations])
	print("  目标: > 1000 ops/ms")

	# 验证结果
	if ops_per_ms > 1000:
		print("✓ 性能目标达成")
	else:
		push_warning("⚠ 性能低于目标 %.2f ops/ms < 1000" % ops_per_ms)

	context.cleanup()

func test_set_variable_performance():
	print("\n=== 变量设置性能测试 ===")

	var context = ExecutionContext.new()

	var iterations = 1000
	var start_time = Time.get_ticks_msec()

	for i in range(iterations):
		context.set_variable("var_%d" % (i % 50), i)

	var elapsed = Time.get_ticks_msec() - start_time
	var ops_per_ms = float(iterations) / float(elapsed)

	print("✓ 变量设置性能: %.2f ops/ms (%.2f ms for %d sets)" % [ops_per_ms, elapsed, iterations])
	print("  目标: > 500 ops/ms")

	if ops_per_ms > 500:
		print("✓ 性能目标达成")
	else:
		push_warning("⚠ 性能低于目标 %.2f ops/ms < 500" % ops_per_ms)

	context.cleanup()

func test_mixed_operations():
	print("\n=== 混合操作性能测试 ===")

	var context = ExecutionContext.new()

	# 设置初始变量
	for i in range(20):
		context.set_variable("var_%d" % i, i)

	var iterations = 5000
	var start_time = Time.get_ticks_msec()

	# 混合查找和设置
	for i in range(iterations):
		if i % 2 == 0:
			# 查找
			var value = context.get_variable("var_%d" % (i % 20))
		else:
			# 设置
			context.set_variable("var_%d" % (i % 20), i)

	var elapsed = Time.get_ticks_msec() - start_time
	var ops_per_ms = float(iterations) / float(elapsed)

	print("✓ 混合操作性能: %.2f ops/ms (%.2f ms for %d operations)" % [ops_per_ms, elapsed, iterations])
	print("  目标: > 300 ops/ms")

	if ops_per_ms > 300:
		print("✓ 性能目标达成")
	else:
		push_warning("⚠ 性能低于目标 %.2f ops/ms < 300" % ops_per_ms)

	context.cleanup()

func test_precompiled_access():
	print("\n=== 预编译变量访问性能测试 ===")

	var context = ExecutionContext.new()

	# 预编译 20 个变量
	var var_names = []
	for i in range(20):
		var_names.append("var_%d" % i)
		context.set_variable("var_%d" % i, i)

	# 启用索引访问
	context.precompile_variable_access(var_names)

	var iterations = 10000
	var start_time = Time.get_ticks_msec()

	# 使用索引访问
	for i in range(iterations):
		var index = i % 20
		var value = context.get_variable_by_index(index)

	var elapsed = Time.get_ticks_msec() - start_time
	var ops_per_ms = float(iterations) / float(elapsed)

	print("✓ 预编译变量访问性能: %.2f ops/ms (%.2f ms for %d lookups)" % [ops_per_ms, elapsed, iterations])
	print("  目标: > 2000 ops/ms (预编译优化）")

	if ops_per_ms > 2000:
		print("✓ 性能目标达成")
	else:
		push_warning("⚠ 预编译性能低于目标 %.2f ops/ms < 2000" % ops_per_ms)

	context.cleanup()
