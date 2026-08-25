@tool
extends SceneTree

## 变量查找优化性能测试
##
## 测试 ExecutionContext 的变量查找优化效果，包括：
## - StringName 优化
## - 变量索引预编译
## - 性能对比分析

const ITERATIONS = 10000  # 测试迭代次数
const VARIABLE_COUNT = 50  # 测试变量数量

func _init():
	print("=== ExecutionContext 变量查找优化性能测试 ===")

	# 创建测试上下文
	var context = ExecutionContext.new()

	# 测试 1: 基础变量访问性能
	print("\n1. 基础变量访问性能测试")
	test_basic_variable_access(context)

	# 测试 2: StringName 优化性能
	print("\n2. StringName 优化性能测试")
	test_stringname_optimization(context)

	# 测试 3: 索引预编译优化性能
	print("\n3. 索引预编译优化性能测试")
	test_indexed_optimization(context)

	# 测试 4: 功能正确性验证
	print("\n4. 功能正确性验证")
	test_functional_correctness(context)

	# 测试 5: 内存使用分析
	print("\n5. 内存使用分析")
	test_memory_usage(context)

	print("\n=== 测试完成 ===")
	quit()

func test_basic_variable_access(context: ExecutionContext):
	"""测试基础变量访问性能"""
	print("测试基础变量访问 (set_variable/get_variable)...")

	# 设置测试变量
	var start_time = Time.get_ticks_msec()
	for i in range(VARIABLE_COUNT):
		context.set_variable("var_%d" % i, i * 10)
	var set_time = Time.get_ticks_msec() - start_time

	# 获取测试变量
	start_time = Time.get_ticks_msec()
	for i in range(VARIABLE_COUNT):
		var value = context.get_variable("var_%d" % i)
	var get_time = Time.get_ticks_msec() - start_time

	print("  设置 %d 个变量: %.2f ms (平均 %.4f ms/次)" % [VARIABLE_COUNT, set_time, float(set_time) / VARIABLE_COUNT])
	print("  获取 %d 个变量: %.2f ms (平均 %.4f ms/次)" % [VARIABLE_COUNT, get_time, float(get_time) / VARIABLE_COUNT])

	# 高频访问测试
	print("  高频访问测试 (%d 次)..." % ITERATIONS)
	start_time = Time.get_ticks_msec()
	for i in range(ITERATIONS):
		context.set_variable("test_var", i)
		var value = context.get_variable("test_var")
	var high_freq_time = Time.get_ticks_msec() - start_time
	print("  高频访问耗时: %.2f ms (平均 %.6f ms/次)" % [high_freq_time, float(high_freq_time) / ITERATIONS])

func test_stringname_optimization(context: ExecutionContext):
	"""测试 StringName 优化效果"""
	print("测试 StringName 缓存优化...")

	# 获取缓存统计
	var stats = context.get_indexed_access_stats()
	print("  缓存的变量名数量: %d" % stats.cached_names)

	# 测试重复访问相同变量名的性能
	var test_var_name = "repeated_variable_name"

	# 第一次访问（应该创建缓存）
	var start_time = Time.get_ticks_msec()
	context.set_variable(test_var_name, 100)
	var first_set_time = Time.get_ticks_msec() - start_time

	start_time = Time.get_ticks_msec()
	var value = context.get_variable(test_var_name)
	var first_get_time = Time.get_ticks_msec() - start_time

	# 多次重复访问（应该使用缓存）
	start_time = Time.get_ticks_msec()
	for i in range(ITERATIONS):
		context.set_variable(test_var_name, i)
		var val = context.get_variable(test_var_name)
	var cached_time = Time.get_ticks_msec() - start_time

	print("  首次访问: 设置 %.4f ms, 获取 %.4f ms" % [first_set_time, first_get_time])
	print("  缓存后 %d 次访问: %.2f ms (平均 %.6f ms/次)" % [ITERATIONS, cached_time, float(cached_time) / ITERATIONS])

	# 验证缓存增长
	var new_stats = context.get_indexed_access_stats()
	print("  缓存增长: %d -> %d" % [stats.cached_names, new_stats.cached_names])

func test_indexed_optimization(context: ExecutionContext):
	"""测试索引预编译优化"""
	print("测试索引预编译优化...")

	# 准备变量名列表
	var variable_names: Array[String] = []
	for i in range(VARIABLE_COUNT):
		variable_names.append("indexed_var_%d" % i)

	# 预编译变量访问
	var start_time = Time.get_ticks_msec()
	context.precompile_variable_access(variable_names)
	var compile_time = Time.get_ticks_msec() - start_time

	var stats = context.get_indexed_access_stats()
	print("  预编译 %d 个变量耗时: %.2f ms" % [VARIABLE_COUNT, compile_time])
	print("  索引访问已启用: %s" % stats.indexed_access_enabled)
	print("  总变量数: %d" % stats.total_variables)
	print("  索引映射大小: %d" % stats.index_map_size)

	# 测试索引访问性能
	print("  测试索引访问性能...")

	# 通过索引设置变量
	start_time = Time.get_ticks_msec()
	for i in range(VARIABLE_COUNT):
		context.set_variable_by_index(i, i * 100)
	var indexed_set_time = Time.get_ticks_msec() - start_time

	# 通过索引获取变量
	start_time = Time.get_ticks_msec()
	for i in range(VARIABLE_COUNT):
		var value = context.get_variable_by_index(i)
	var indexed_get_time = Time.get_ticks_msec() - start_time

	print("  索引设置 %d 个变量: %.2f ms (平均 %.4f ms/次)" % [VARIABLE_COUNT, indexed_set_time, float(indexed_set_time) / VARIABLE_COUNT])
	print("  索引获取 %d 个变量: %.2f ms (平均 %.4f ms/次)" % [VARIABLE_COUNT, indexed_get_time, float(indexed_get_time) / VARIABLE_COUNT])

	# 高频索引访问测试
	print("  高频索引访问测试 (%d 次)..." % ITERATIONS)
	start_time = Time.get_ticks_msec()
	for i in range(ITERATIONS):
		var index = i % VARIABLE_COUNT
		context.set_variable_by_index(index, i)
		var value = context.get_variable_by_index(index)
	var high_freq_indexed_time = Time.get_ticks_msec() - start_time
	print("  高频索引访问耗时: %.2f ms (平均 %.6f ms/次)" % [high_freq_indexed_time, float(high_freq_indexed_time) / ITERATIONS])

	# 对比普通访问和索引访问
	print("  性能对比:")
	var normal_time = indexed_set_time + indexed_get_time
	var indexed_time = indexed_set_time + indexed_get_time
	print("    普通访问: %.2f ms" % normal_time)
	print("    索引访问: %.2f ms" % indexed_time)
	if normal_time > 0:
		var improvement = (1.0 - float(indexed_time) / normal_time) * 100
		print("    性能提升: %.1f%%" % improvement)

func test_functional_correctness(context: ExecutionContext):
	"""验证功能正确性"""
	print("验证功能正确性...")

	# 测试 1: 基本变量操作
	context.set_variable("test_var", 42)
	var value = context.get_variable("test_var")
	assert(value == 42, "基本变量设置/获取失败")
	print("  ✓ 基本变量操作正确")

	# 测试 2: 默认值处理
	var default_value = context.get_variable("non_existent_var", "default")
	assert(default_value == "default", "默认值处理失败")
	print("  ✓ 默认值处理正确")

	# 测试 3: 变量存在检查
	context.set_variable("existing_var", 100)
	assert(context.has_variable("existing_var"), "变量存在检查失败")
	assert(not context.has_variable("non_existing_var"), "变量不存在检查失败")
	print("  ✓ 变量存在检查正确")

	# 测试 4: 索引预编译功能
	var var_names: Array[String] = ["var1", "var2", "var3"]
	context.precompile_variable_access(var_names)

	# 通过索引设置和获取
	context.set_variable_by_index(0, "index_value_1")
	context.set_variable_by_index(1, "index_value_2")
	context.set_variable_by_index(2, "index_value_3")

	var val1 = context.get_variable_by_index(0)
	var val2 = context.get_variable_by_index(1)
	var val3 = context.get_variable_by_index(2)

	assert(val1 == "index_value_1", "索引访问失败 - 索引 0")
	assert(val2 == "index_value_2", "索引访问失败 - 索引 1")
	assert(val3 == "index_value_3", "索引访问失败 - 索引 2")
	print("  ✓ 索引访问功能正确")

	# 测试 5: 变量名到索引映射
	var index = context.get_variable_index("var2")
	assert(index == 1, "变量名到索引映射失败")
	print("  ✓ 变量名到索引映射正确")

	# 测试 6: 混合访问模式
	# 通过普通方式访问应该也能工作（回退机制）
	var normal_access = context.get_variable("var1")
	assert(normal_access == "index_value_1", "混合访问模式失败")
	print("  ✓ 混合访问模式正确")

	# 测试 7: 错误处理
	var invalid_index_result = context.get_variable_by_index(999)
	assert(invalid_index_result == null, "无效索引处理失败")
	print("  ✓ 错误处理正确")

func test_memory_usage(context: ExecutionContext):
	"""分析内存使用情况"""
	print("分析内存使用情况...")

	# 获取初始统计
	var initial_stats = context.get_indexed_access_stats()
	print("  初始状态:")
	print("    缓存变量名: %d" % initial_stats.cached_names)
	print("    索引映射大小: %d" % initial_stats.index_map_size)

	# 添加大量变量
	var large_var_names: Array[String] = []
	for i in range(1000):
		large_var_names.append("memory_test_var_%d" % i)

	context.precompile_variable_access(large_var_names)

	# 获取后续统计
	var final_stats = context.get_indexed_access_stats()
	print("  添加 1000 个变量后:")
	print("    缓存变量名: %d" % final_stats.cached_names)
	print("    索引映射大小: %d" % final_stats.index_map_size)
	print("    内存使用增长: 缓存 %d, 映射 %d" % [
		final_stats.cached_names - initial_stats.cached_names,
		final_stats.index_map_size - initial_stats.index_map_size
	])

	# 测试缓存清理
	context.cleanup()
	var cleaned_stats = context.get_indexed_access_stats()
	print("  清理后:")
	print("    缓存变量名: %d" % cleaned_stats.cached_names)
	print("    索引映射大小: %d" % cleaned_stats.index_map_size)
	print("    索引访问启用: %s" % cleaned_stats.indexed_access_enabled)

func run_tests():
	# 确保在编辑器中也能运行
	if Engine.is_editor_hint():
		return

	# 运行测试
	print("=== ExecutionContext 变量查找优化性能测试 ===")

	# 创建测试上下文
	var context = ExecutionContext.new()

	# 测试 1: 基础变量访问性能
	print("\n1. 基础变量访问性能测试")
	test_basic_variable_access(context)

	# 测试 2: StringName 优化性能
	print("\n2. StringName 优化性能测试")
	test_stringname_optimization(context)

	# 测试 3: 索引预编译优化性能
	print("\n3. 索引预编译优化性能测试")
	test_indexed_optimization(context)

	# 测试 4: 功能正确性验证
	print("\n4. 功能正确性验证")
	test_functional_correctness(context)

	# 测试 5: 内存使用分析
	print("\n5. 内存使用分析")
	test_memory_usage(context)

	print("\n=== 测试完成 ===")
