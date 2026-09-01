extends Node
class_name TestVariableContainerPerformance

## VariableContainer 性能测试套件
##
## 全面测试 VariableContainer 的性能特性：
## - 单次操作性能（添加、读取、更新、删除）
## - 批量操作性能（1000个变量）
## - 缓存效率测试（热数据vs冷数据）
## - 内存占用估算
## - 作用域过滤性能

const WARMUP_ITERATIONS = 100  ## 预热迭代次数
const TEST_ITERATIONS = 1000   ## 测试迭代次数
const VARIABLE_COUNT = 1000    ## 批量测试的变量数量

var _container: VariableContainer
var _results: Dictionary = {}  ## 存储测试结果

func _ready():
	print("=== VariableContainer 性能测试套件 ===")
	print("\n注意: 这些测试会创建和操作大量变量，可能需要几秒钟...")

	# 预热
	_warmup()

	# 运行测试
	run_all_tests()

	# 输出结果
	print_results()

	print("\n=== 性能测试完成 ===")

## 预热JIT编译
func _warmup():
	print("\n正在预热...")
	var temp_container = VariableContainer.new()
	for i in range(WARMUP_ITERATIONS):
		temp_container.add_variable("temp_%d" % i, i)
		temp_container.get_variable("temp_%d" % i)
	print("✓ 预热完成")

## 运行所有测试
func run_all_tests():
	test_single_operations()
	test_bulk_operations()
	test_cache_efficiency()
	test_memory_usage()
	test_scope_filtering()

## 测试单次操作性能
func test_single_operations():
	print("\n=== 测试1: 单次操作性能 ===")
	_container = VariableContainer.new()

	# 测试添加
	var start_time = Time.get_ticks_usec()
	for i in range(TEST_ITERATIONS):
		_container.add_variable("test_var_%d" % i, i)
	var add_time = (Time.get_ticks_usec() - start_time) / float(TEST_ITERATIONS)
	_results["add_single"] = add_time
	print("  add_variable() 平均: %.3f 微秒" % add_time)

	# 测试读取
	start_time = Time.get_ticks_usec()
	for i in range(TEST_ITERATIONS):
		_container.get_variable("test_var_%d" % i)
	var get_time = (Time.get_ticks_usec() - start_time) / float(TEST_ITERATIONS)
	_results["get_single"] = get_time
	print("  get_variable() 平均: %.3f 微秒" % get_time)

	# 测试更新
	start_time = Time.get_ticks_usec()
	for i in range(TEST_ITERATIONS):
		_container.set_variable("test_var_%d" % i, i * 2)
	var set_time = (Time.get_ticks_usec() - start_time) / float(TEST_ITERATIONS)
	_results["set_single"] = set_time
	print("  set_variable() 平均: %.3f 微秒" % set_time)

	# 测试删除（只测试100个以避免影响其他测试）
	start_time = Time.get_ticks_usec()
	for i in range(100):
		_container.remove_variable("test_var_%d" % i)
	var remove_time = (Time.get_ticks_usec() - start_time) / float(100)
	_results["remove_single"] = remove_time
	print("  remove_variable() 平均: %.3f 微秒" % remove_time)

	print("✓ 单次操作测试完成")

## 测试批量操作性能
func test_bulk_operations():
	print("\n=== 测试2: 批量操作性能 ===")
	_container = VariableContainer.new()

	# 批量添加
	var start_time = Time.get_ticks_usec()
	for i in range(VARIABLE_COUNT):
		_container.add_variable("bulk_var_%d" % i, i)
	var bulk_add_time = (Time.get_ticks_usec() - start_time)
	_results["bulk_add"] = bulk_add_time
	print("  添加 %d 个变量: %.2f 毫秒" % [VARIABLE_COUNT, bulk_add_time / 1000.0])
	print("  平均每变量: %.3f 微秒" % (bulk_add_time / float(VARIABLE_COUNT)))

	# 批量读取
	start_time = Time.get_ticks_usec()
	for i in range(VARIABLE_COUNT):
		_container.get_variable("bulk_var_%d" % i)
	var bulk_get_time = (Time.get_ticks_usec() - start_time)
	_results["bulk_get"] = bulk_get_time
	print("  读取 %d 个变量: %.2f 毫秒" % [VARIABLE_COUNT, bulk_get_time / 1000.0])
	print("  平均每变量: %.3f 微秒" % (bulk_get_time / float(VARIABLE_COUNT)))

	# 批量更新
	start_time = Time.get_ticks_usec()
	for i in range(VARIABLE_COUNT):
		_container.set_variable("bulk_var_%d" % i, i * 2)
	var bulk_set_time = (Time.get_ticks_usec() - start_time)
	_results["bulk_set"] = bulk_set_time
	print("  更新 %d 个变量: %.2f 毫秒" % [VARIABLE_COUNT, bulk_set_time / 1000.0])
	print("  平均每变量: %.3f 微秒" % (bulk_set_time / float(VARIABLE_COUNT)))

	print("✓ 批量操作测试完成")

## 测试缓存效率
func test_cache_efficiency():
	print("\n=== 测试3: 缓存效率 ===")
	_container = VariableContainer.new()

	# 添加变量
	for i in range(100):
		_container.add_variable("cache_test_%d" % i, i)

	# 测试热数据（重复读取同一变量）
	var start_time = Time.get_ticks_usec()
	for i in range(10000):
		_container.get_variable("cache_test_0")
	var hot_data_time = Time.get_ticks_usec() - start_time
	print("  热数据读取（10000次同一变量）: %.2f 毫秒" % (hot_data_time / 1000.0))

	# 测试冷数据（读取不同变量）
	start_time = Time.get_ticks_usec()
	for i in range(10000):
		var var_name = "cache_test_%d" % (i % 100)
		_container.get_variable(var_name)
	var cold_data_time = Time.get_ticks_usec() - start_time
	print("  冷数据读取（10000次不同变量）: %.2f 毫秒" % (cold_data_time / 1000.0))

	var speedup = float(cold_data_time) / float(hot_data_time)
	print("  缓存加速比: %.2fx" % speedup)

	_results["cache_speedup"] = speedup

	print("✓ 缓存效率测试完成")

## 测试内存占用（估算）
func test_memory_usage():
	print("\n=== 测试4: 内存占用（估算）===")
	_container = VariableContainer.new()

	# 记录初始内存
	var initial_memory = OS.get_static_memory_usage()

	# 添加大量变量
	for i in range(VARIABLE_COUNT):
		_container.add_variable("mem_test_%d" % i, i)

	# 记录最终内存
	var final_memory = OS.get_static_memory_usage()

	# 计算差异（注意：这个方法不精确，但可以提供参考）
	print("  初始内存: %d 字节" % initial_memory)
	print("  最终内存: %d 字节" % final_memory)
	print("  增长: %d 字节（约 %.2f KB）" % [final_memory - initial_memory, (final_memory - initial_memory) / 1024.0])
	print("  平均每变量: %.2f 字节" % ((final_memory - initial_memory) / float(VARIABLE_COUNT)))

	print("✓ 内存占用测试完成")
	print("  注意: 由于Godot的垃圾回收机制，实际内存占用可能更高")

## 测试作用域过滤性能
func test_scope_filtering():
	print("\n=== 测试5: 作用域过滤性能 ===")
	_container = VariableContainer.new()

	# 添加混合作用域变量
	for i in range(500):
		_container.add_variable("local_%d" % i, i, VariableContainer.VariableScope.LOCAL)
		_container.add_variable("global_%d" % i, i, VariableContainer.VariableScope.GLOBAL)

	# 测试本地变量查询
	var start_time = Time.get_ticks_usec()
	var local_vars = _container.get_variable_names(VariableContainer.VariableScope.LOCAL)
	var local_filter_time = Time.get_ticks_usec() - start_time
	print("  获取本地变量（500个）: %.3f 毫秒" % (local_filter_time / 1000.0))
	assert(local_vars.size() == 500, "应该返回500个本地变量")

	# 测试全局变量查询
	start_time = Time.get_ticks_usec()
	var global_vars = _container.get_variable_names(VariableContainer.VariableScope.GLOBAL)
	var global_filter_time = Time.get_ticks_usec() - start_time
	print("  获取全局变量（500个）: %.3f 毫秒" % (global_filter_time / 1000.0))
	assert(global_vars.size() == 500, "应该返回500个全局变量")

	# 测试持久化变量查询
	_container = VariableContainer.new()
	for i in range(500):
		_container.add_variable("persistent_%d" % i, i, VariableContainer.VariableScope.LOCAL, true)
		_container.add_variable("runtime_%d" % i, i, VariableContainer.VariableScope.LOCAL, false)

	# 获取所有变量信息
	var all_vars = _container.get_all_variables(VariableContainer.VariableScope.LOCAL)
	print("  获取所有变量（1000个）: %d 个变量" % all_vars.size())
	assert(all_vars.size() == 1000, "应该返回1000个变量")

	print("✓ 作用域过滤测试完成")

## 打印结果摘要
func print_results():
	print("\n" + "=".repeat(50))
	print("性能测试结果摘要")
	print("=".repeat(50))

	print("\n单次操作性能（微秒/操作）:")
	print("  添加: %.3f µs" % _results.get("add_single", 0))
	print("  读取: %.3f µs" % _results.get("get_single", 0))
	print("  更新: %.3f µs" % _results.get("set_single", 0))
	print("  删除: %.3f µs" % _results.get("remove_single", 0))

	print("\n批量操作性能（毫秒）:")
	print("  添加 %d 个变量: %.2f ms" % [VARIABLE_COUNT, _results.get("bulk_add", 0) / 1000.0])
	print("  读取 %d 个变量: %.2f ms" % [VARIABLE_COUNT, _results.get("bulk_get", 0) / 1000.0])
	print("  更新 %d 个变量: %.2f ms" % [VARIABLE_COUNT, _results.get("bulk_set", 0) / 1000.0])

	print("\n缓存效率:")
	var speedup = _results.get("cache_speedup", 1.0)
	print("  加速比: %.2fx" % speedup)
	if speedup > 1.5:
		print("  ✓ 缓存工作良好")
	elif speedup > 1.1:
		print("  ⚠ 缓存效果一般")
	else:
		print("  ✗ 缓存可能未生效")

	print("\n" + "=".repeat(50))
