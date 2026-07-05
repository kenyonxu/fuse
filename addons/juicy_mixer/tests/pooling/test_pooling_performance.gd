# 池化系统性能测试
# 测试池化系统的性能表现，验证是否达到设计目标

class_name TestPoolingPerformance
extends RefCounted

# 测试配置
const TEST_ITERATIONS: int = 1000
const WARMUP_ITERATIONS: int = 100
const PERFORMANCE_TARGET_REUSE_RATIO: float = 0.9  # 90%重用率
const PERFORMANCE_TARGET_MEMORY_REDUCTION: float = 0.8  # 80%内存分配减少
const PERFORMANCE_TARGET_GC_PRESSURE_REDUCTION: float = 0.7  # 70%GC压力减少

# 池配置优化
const CONTEXT_POOL_SIZE: int = 200  # 增加Context池大小
const OBJECT_POOL_SIZE: int = 300   # 增加对象池大小
const MAX_POOL_SIZE: int = 500      # 增加最大池大小

# 测试结果
var _test_results: Dictionary = {}
var _performance_metrics: Dictionary = {}

# 运行所有性能测试
func run_all_performance_tests() -> Dictionary:
	print("=== Running Pooling System Performance Tests ===")
	_test_results.clear()
	_performance_metrics.clear()
	
	# 测试Context池性能
	_test_results["context_pool"] = test_context_pool_performance()
	
	# 测试对象池性能
	_test_results["object_pool"] = test_object_pool_performance()
	
	# 测试池管理器性能
	_test_results["pool_manager"] = test_pool_manager_performance()
	
	# 测试集成性能
	_test_results["integration"] = test_integration_performance()
	
	# 计算总体性能评估
	_calculate_overall_performance()
	
	# 打印结果
	_print_performance_summary()
	
	return _test_results

# 测试Context池性能
func test_context_pool_performance() -> Dictionary:
	print("\n--- Testing Context Pool Performance ---")
	var result = {}
	
	# 获取Context池
	var pool_manager = JuicyPoolManager.instance
	var context_pool = pool_manager.get_context_pool()
	
	# 配置池大小以适应测试
	context_pool.set_pool_size(CONTEXT_POOL_SIZE)
	context_pool.set_max_pool_size(MAX_POOL_SIZE)
	
	# 预热池
	context_pool.warm_up(WARMUP_ITERATIONS)
	
	# 测试获取和返回Context的性能（改进的测试逻辑）
	var start_time = Time.get_ticks_msec()
	var successful_acquires = 0
	var failed_acquires = 0
	
	# 使用更真实的测试模式：获取少量Context，使用后立即返回
	for i in range(TEST_ITERATIONS):
		# 获取Context
		var context = context_pool.get_context()
		if context and not context.context_id.is_empty():
			successful_acquires += 1
			# 模拟短暂使用（使用实际存在的方法）
			context.set_property_override("test_data", "test_" + str(i))  # 模拟使用
			context.set_driver_data("test_driver", {"iteration": i})  # 模拟驱动器数据
			# 立即返回Context，避免池耗尽
			context_pool.return_context(context)
		else:
			failed_acquires += 1
			print("Warning: Failed to get context at iteration ", i)
	
	var operation_time = Time.get_ticks_msec() - start_time
	
	# 获取统计信息
	var stats = context_pool.get_statistics()
	
	print("Context Pool - Operation: ", operation_time, "ms")
	print("Context Pool - Successful Acquires: ", successful_acquires, ", Failed: ", failed_acquires)
	print("Context Pool - Reuse Ratio: ", stats.reuse_ratio, ", Target: ", PERFORMANCE_TARGET_REUSE_RATIO)
	print("Context Pool - Pool Size: ", CONTEXT_POOL_SIZE, ", Max Pool Size: ", MAX_POOL_SIZE)
	
	result = {
		"operation_time_ms": operation_time,
		"successful_acquires": successful_acquires,
		"failed_acquires": failed_acquires,
		"total_allocated": stats.total_allocated,
		"total_reused": stats.total_reused,
		"reuse_ratio": stats.reuse_ratio,
		"efficiency_score": stats.efficiency_score,
		"target_met": stats.reuse_ratio >= PERFORMANCE_TARGET_REUSE_RATIO
	}
	
	return result

# 测试对象池性能
func test_object_pool_performance() -> Dictionary:
	print("\n--- Testing Object Pool Performance ---")
	var result = {}
	
	# 获取对象池
	var pool_manager = JuicyPoolManager.instance
	var object_pool = pool_manager.get_driver_pool(JuicyPoolItem)
	
	# 配置全局对象池大小以适应测试
	object_pool.set_pool_size(OBJECT_POOL_SIZE)
	object_pool.set_max_pool_size(MAX_POOL_SIZE)
	object_pool.warm_up(WARMUP_ITERATIONS)
	
	# 测试获取和返回对象的性能（改进的测试逻辑）
	var start_time = Time.get_ticks_msec()
	var successful_acquires = 0
	var failed_acquires = 0
	
	# 使用更真实的测试模式：获取少量对象，使用后立即返回
	for i in range(TEST_ITERATIONS):
		# 获取对象
		var obj = object_pool.get_object()
		if obj:
			successful_acquires += 1
			# 模拟短暂使用
			obj.usage_count = i  # 模拟使用
			# 立即返回对象，避免池耗尽
			object_pool.return_object(obj)
		else:
			failed_acquires += 1
			print("Warning: Failed to get object at iteration ", i)
	
	var operation_time = Time.get_ticks_msec() - start_time
	
	# 获取统计信息
	var stats = object_pool.get_statistics()
	
	print("Object Pool - Operation: ", operation_time, "ms")
	print("Object Pool - Successful Acquires: ", successful_acquires, ", Failed: ", failed_acquires)
	print("Object Pool - Reuse Ratio: ", stats.reuse_ratio, ", Target: ", PERFORMANCE_TARGET_REUSE_RATIO)
	print("Object Pool - Pool Size: ", OBJECT_POOL_SIZE, ", Objects Created: ", stats.total_created)
	
	result = {
		"test_name": "object_pool_performance",
		"operation_time_ms": operation_time,
		"successful_acquires": successful_acquires,
		"failed_acquires": failed_acquires,
		"total_created": stats.total_created,
		"total_reused": stats.total_reused,
		"reuse_ratio": stats.reuse_ratio,
		"efficiency_score": stats.efficiency_score,
		"target_met": stats.reuse_ratio >= PERFORMANCE_TARGET_REUSE_RATIO
	}
	
	return result

# 测试池管理器性能
func test_pool_manager_performance() -> Dictionary:
	print("\n--- Testing Pool Manager Performance ---")
	var result = {}
	
	# 获取池管理器
	var pool_manager = JuicyPoolManager.instance
	
	# 预热所有池
	pool_manager.warm_up_system()
	
	# 测试并发操作性能
	var start_time = Time.get_ticks_msec()
	
	# 并发获取和返回操作
	for i in range(TEST_ITERATIONS / 10):  # 较少的迭代，因为每个操作更复杂
		var context = pool_manager.get_context_pool().get_context()
		var obj = pool_manager.get_driver(JuicyPoolItem)
		var resource = pool_manager.get_resource(JuicyPoolItem)
		
		# 模拟一些处理时间
		for j in range(10):
			pass
		
		# 返回对象
		pool_manager.get_context_pool().return_context(context)
		pool_manager.return_driver(obj)
		pool_manager.return_resource(resource)
	
	var operation_time = Time.get_ticks_msec() - start_time
	
	# 获取全局统计信息
	var global_stats = pool_manager.get_all_pool_statistics()
	var efficiency_score = pool_manager.get_global_efficiency_score()
	
	result = {
		"operation_time_ms": operation_time,
		"global_efficiency_score": efficiency_score,
		"total_pools": global_stats.global.total_pools,
		"driver_pool_count": global_stats.global.driver_pool_count,
		"resource_pool_count": global_stats.global.resource_pool_count,
		"target_met": efficiency_score >= PERFORMANCE_TARGET_REUSE_RATIO
	}
	
	print("Pool Manager - Operation: ", operation_time, "ms")
	print("Pool Manager - Global Efficiency: ", efficiency_score, ", Target: ", PERFORMANCE_TARGET_REUSE_RATIO)
	
	return result

# 测试集成性能
func test_integration_performance() -> Dictionary:
	print("\n--- Testing Integration Performance ---")
	var result = {}
	
	# 初始化中间件管道，确保有必要的中间件
	_setup_middleware_for_integration_test()
	
	# 创建测试资源（使用具体的子类）
	var test_resource = JuicyShakeResource.new()
	test_resource.duration = 1.0
	# 添加震动数据以通过ValidationMiddleware的验证
	test_resource.add_shake_data("position", 10.0, 10.0, 1.0)
	
	# 创建测试目标
	var test_target = Node.new()
	
	# 测试Director与池系统的集成性能
	var start_time = Time.get_ticks_msec()
	var context_ids: Array = []
	
	# 播放大量效果
	for i in range(TEST_ITERATIONS / 10):  # 较少的迭代，因为每个操作更复杂
		var context_id = JuicyMixer.play(test_resource, test_target)
		if not context_id.is_empty():
			context_ids.append(context_id)
		
		# 立即停止以测试完整生命周期
		if not context_id.is_empty():
			JuicyMixer.stop(context_id)
	
	var integration_time = Time.get_ticks_msec() - start_time
	
	# 获取池统计信息
	var pool_stats = JuicyMixer.get_pool_statistics()
	var efficiency_score = JuicyMixer.get_pool_efficiency_score()
	
	result = {
		"integration_time_ms": integration_time,
		"pool_efficiency_score": efficiency_score,
		"context_pool_stats": pool_stats.context_pool,
		"target_met": efficiency_score >= PERFORMANCE_TARGET_REUSE_RATIO
	}
	
	print("Integration - Operation: ", integration_time, "ms")
	print("Integration - Pool Efficiency: ", efficiency_score, ", Target: ", PERFORMANCE_TARGET_REUSE_RATIO)
	
	# 清理
	test_target.free()
	
	return result

# 为集成测试设置中间件
func _setup_middleware_for_integration_test() -> void:
	"""为集成测试设置必要的中间件"""
	var juicy_mixer = JuicyMixer.instance
	var pipeline = juicy_mixer.get_middleware_pipeline()
	
	if not pipeline:
		print("Warning: Cannot get middleware pipeline")
		return
	
	# 检查是否已有中间件
	var middleware_list = pipeline.get_all_middleware()
	if middleware_list.size() > 0:
		print("Middleware pipeline already has ", middleware_list.size(), " middleware(s)")
		return
	
	# 创建并注册ValidationMiddleware
	var validation_middleware = ValidationMiddleware.new()
	var success = juicy_mixer.add_middleware(validation_middleware)
	
	if success:
		print("ValidationMiddleware registered successfully")
	else:
		print("Failed to register ValidationMiddleware")

# 计算总体性能评估
func _calculate_overall_performance() -> void:
	var overall_efficiency = 0.0
	var targets_met = 0
	var total_tests = 0
	
	for test_name in _test_results.keys():
		var test_result = _test_results[test_name]
		total_tests += 1
		
		if test_result.has("efficiency_score"):
			overall_efficiency += test_result.efficiency_score
		
		if test_result.has("target_met") and test_result.target_met:
			targets_met += 1
	
	overall_efficiency /= total_tests
	
	_performance_metrics = {
		"overall_efficiency_score": overall_efficiency,
		"targets_met_ratio": float(targets_met) / float(total_tests),
		"total_tests": total_tests,
		"targets_met": targets_met,
		"performance_target_met": overall_efficiency >= PERFORMANCE_TARGET_REUSE_RATIO
	}

# 打印性能摘要
func _print_performance_summary() -> void:
	print("\n=== Pooling System Performance Summary ===")
	print("Overall Efficiency Score: ", _performance_metrics.overall_efficiency_score)
	print("Targets Met: ", _performance_metrics.targets_met, "/", _performance_metrics.total_tests)
	print("Targets Met Ratio: ", _performance_metrics.targets_met_ratio * 100, "%")
	print("Performance Target Met: ", _performance_metrics.performance_target_met)
	
	print("\n--- Detailed Results ---")
	for test_name in _test_results.keys():
		var result = _test_results[test_name]
		print("\n", test_name, ":")
		
		for key in result.keys():
			print("  ", key, ": ", result[key])
	
	print("\n--- Performance Targets ---")
	print("Target Reuse Ratio: ", PERFORMANCE_TARGET_REUSE_RATIO * 100, "%")
	print("Target Memory Reduction: ", PERFORMANCE_TARGET_MEMORY_REDUCTION * 100, "%")
	print("Target GC Pressure Reduction: ", PERFORMANCE_TARGET_GC_PRESSURE_REDUCTION * 100, "%")

# 快速性能测试（用于开发时快速验证）
func quick_performance_test() -> bool:
	print("\n=== Quick Performance Test ===")
	
	# 简单测试池管理器性能
	var pool_manager = JuicyPoolManager.instance
	if not pool_manager:
		print("Quick performance test failed: Cannot get pool manager")
		return false
	
	# 预热池
	pool_manager.warm_up_system()
	
	# 测试Context池性能（改进的测试逻辑）
	var context_pool = pool_manager.get_context_pool()
	var start_time = Time.get_ticks_msec()
	var successful_operations = 0
	
	# 使用边获取边返回的测试模式
	for i in range(100):
		var context = context_pool.get_context()
		if context:
			successful_operations += 1
			# 模拟使用（使用实际存在的方法）
			context.set_property_override("quick_test", "quick_test_" + str(i))
			context.set_driver_data("quick_driver", {"iteration": i})
			# 立即返回
			context_pool.return_context(context)
	
	var operation_time = Time.get_ticks_msec() - start_time
	
	var stats = context_pool.get_statistics()
	
	print("Quick Test - 100 operations: ", operation_time, "ms")
	print("Quick Test - Successful operations: ", successful_operations)
	print("Quick Test - Reuse Ratio: ", stats.reuse_ratio)
	
	# 检查基本性能目标
	if stats.reuse_ratio < 0.5:  # 至少50%重用率
		print("Quick performance test failed: Reuse ratio too low")
		return false
	
	print("Quick performance test passed!")
	return true

# 内存使用测试（简化版本，因为Godot 4的内存API有限）
func test_memory_usage() -> Dictionary:
	print("\n=== Memory Usage Test ===")
	
	# 执行大量池操作
	var pool_manager = JuicyPoolManager.instance
	pool_manager.warm_up_system()
	
	var successful_context_ops = 0
	var successful_object_ops = 0
	
	# 使用边获取边返回的测试模式，避免池耗尽
	for i in range(TEST_ITERATIONS):
		# 获取并立即返回Context
		var context = pool_manager.get_context_pool().get_context()
		if context:
			successful_context_ops += 1
			# 模拟使用（使用实际存在的方法）
			context.set_property_override("memory_test", "memory_test_" + str(i))
			context.set_driver_data("memory_driver", {"iteration": i})
			pool_manager.get_context_pool().return_context(context)
			
			# 获取并立即返回对象
			var obj = pool_manager.get_driver(JuicyPoolItem)
			if obj:
				successful_object_ops += 1
				obj.usage_count = i
				pool_manager.return_driver(obj)
	
	# 获取池统计信息作为内存使用指标
	var pool_stats = pool_manager.get_all_pool_statistics()
	
	var memory_diff = {
		"total_contexts_allocated": pool_stats.context_pool.total_allocated,
		"total_contexts_reused": pool_stats.context_pool.total_reused,
		"total_objects_created": 0,  # 累计所有对象池的创建数
		"total_objects_reused": 0,   # 累计所有对象池的重用数
		"pool_efficiency": pool_manager.get_global_efficiency_score(),
		"successful_context_ops": successful_context_ops,
		"successful_object_ops": successful_object_ops
	}
	
	# 计算对象池的总计
	for pool_name in pool_stats.driver_pools.keys():
		var driver_stats = pool_stats.driver_pools[pool_name]
		memory_diff.total_objects_created += driver_stats.total_created
		memory_diff.total_objects_reused += driver_stats.total_reused
	
	for pool_name in pool_stats.resource_pools.keys():
		var resource_stats = pool_stats.resource_pools[pool_name]
		memory_diff.total_objects_created += resource_stats.total_created
		memory_diff.total_objects_reused += resource_stats.total_reused
	
	print("Memory Usage Test:")
	print("  Total Contexts Allocated: ", memory_diff.total_contexts_allocated)
	print("  Total Contexts Reused: ", memory_diff.total_contexts_reused)
	print("  Total Objects Created: ", memory_diff.total_objects_created)
	print("  Total Objects Reused: ", memory_diff.total_objects_reused)
	print("  Pool Efficiency Score: ", memory_diff.pool_efficiency)
	print("  Successful Context Operations: ", memory_diff.successful_context_ops)
	print("  Successful Object Operations: ", memory_diff.successful_object_ops)
	
	return memory_diff
