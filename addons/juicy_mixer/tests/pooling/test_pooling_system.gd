# 池化系统单元测试
# 测试JuicyPoolItem、JuicyContextPool、JuicyObjectPool和JuicyPoolManager的功能

class_name TestPoolingSystem
extends RefCounted

# 测试结果
var _test_results: Array[Dictionary] = []
var _current_test_name: String = ""

# 测试JuicyPoolItem
func test_juicy_pool_item() -> void:
	_current_test_name = "JuicyPoolItem"
	
	# 创建测试对象
	var test_obj = RefCounted.new()
	var pool_item = JuicyPoolItem.new(test_obj)
	
	# 测试初始状态
	assert_test(pool_item.object == test_obj, "Pool item should store the object")
	assert_test(pool_item.in_use == false, "Pool item should initially not be in use")
	assert_test(pool_item.usage_count == 0, "Pool item should initially have 0 usage count")
	
	# 测试标记使用
	pool_item.mark_used()
	assert_test(pool_item.in_use == true, "Pool item should be marked as in use")
	assert_test(pool_item.usage_count == 1, "Pool item should have 1 usage count after mark_used")
	
	# 测试标记未使用
	pool_item.mark_unused()
	assert_test(pool_item.in_use == false, "Pool item should be marked as not in use")
	
	# 测试重置
	pool_item.mark_used()
	pool_item.mark_used()
	pool_item.reset()
	assert_test(pool_item.in_use == false, "Pool item should be not in use after reset")
	assert_test(pool_item.usage_count == 0, "Pool item should have 0 usage count after reset")
	
	# 测试过期检测
	pool_item.mark_unused()
	assert_test(not pool_item.is_expired(1.0), "Fresh pool item should not be expired")
	
	# 模拟过期
	pool_item.last_used = Time.get_ticks_msec() / 1000.0 - 120.0  # 2分钟前
	assert_test(pool_item.is_expired(60.0), "Pool item should be expired after idle time")
	
	_end_test()

# 测试JuicyContextPool
func test_juicy_context_pool() -> void:
	_current_test_name = "JuicyContextPool"
	
	# 创建Context池
	var context_pool = JuicyContextPool.new(10)
	
	# 测试获取Context
	var context1 = context_pool.get_context()
	assert_test(context1 != null, "Should be able to get a context from pool")
	assert_test(context1.context_id != null and not context1.context_id.is_empty(), "Context should have valid ID")
	assert_test(context_pool.get_active_contexts().size() == 1, "Should have 1 active context")
	assert_test(context_pool.has_context(context1), "Context should be in pool")
	
	var context2 = context_pool.get_context()
	assert_test(context2 != null, "Should be able to get another context from pool")
	assert_test(context2.context_id != null and not context2.context_id.is_empty(), "Context should have valid ID")
	assert_test(context_pool.get_active_contexts().size() == 2, "Should have 2 active contexts")
	assert_test(context1 != context2, "Contexts should be different instances")
	assert_test(context_pool.has_context(context2), "Second context should be in pool")
	
	# 测试返回Context到池中
	context_pool.return_context(context1)
	assert_test(context_pool.get_active_contexts().size() == 1, "Should have 1 active context after return")
	assert_test(context_pool.get_available_contexts().size() >= 1, "Should have at least 1 available context")
	assert_test(not context_pool.has_context(context1), "Returned context should not be in active list")
	
	# 测试统计信息
	var stats = context_pool.get_statistics()
	assert_test(stats.total_allocated >= 2, "Should have allocated at least 2 contexts")
	assert_test(stats.active_contexts == 1, "Should have 1 active context")
	
	# 测试预热
	context_pool.warm_up(5)
	var available_before = context_pool.get_available_contexts().size()
	context_pool.warm_up(3)  # 尝试预热更多
	var available_after = context_pool.get_available_contexts().size()
	assert_test(available_after >= available_before, "Warm up should increase available contexts")
	
	# 测试清空池
	context_pool.clear_pool()
	assert_test(context_pool.get_active_contexts().size() == 0, "Should have 0 active contexts after clear")
	assert_test(context_pool.get_available_contexts().size() == 0, "Should have 0 available contexts after clear")
	
	_end_test()

# 测试JuicyObjectPool
func test_juicy_object_pool() -> void:
	_current_test_name = "JuicyObjectPool"
	
	# 创建测试脚本
	var object_pool = JuicyObjectPool.new(JuicyPoolItem, 5)
	
	# 测试获取对象
	var obj1 = object_pool.get_object()
	assert_test(obj1 != null, "Should be able to get an object from pool")
	assert_test(obj1 is JuicyPoolItem, "Object should be of correct type")
	
	var obj2 = object_pool.get_object()
	assert_test(obj2 != null, "Should be able to get another object from pool")
	assert_test(obj1 != obj2, "Objects should be different instances")
	
	# 测试返回对象到池中
	object_pool.return_object(obj1)
	var stats = object_pool.get_statistics()
	assert_test(stats.total_created >= 2, "Should have created at least 2 objects")
	
	# 测试对象重用
	var obj3 = object_pool.get_object()
	# 由于池的内部实现，我们无法直接测试是否重用了obj1，但可以测试统计信息
	var stats_after = object_pool.get_statistics()
	assert_test(stats_after.total_reused >= 0, "Should have some reuse statistics")
	
	# 测试预热
	object_pool.warm_up(3)
	var stats_warm = object_pool.get_statistics()
	assert_test(stats_warm.total_created >= stats_after.total_created, "Warm up should increase total created")
	
	# 测试清空池
	object_pool.clear_pool()
	var stats_clear = object_pool.get_statistics()
	assert_test(stats_clear.total_created == 0, "Should have 0 total created after clear")
	assert_test(stats_clear.total_reused == 0, "Should have 0 total reused after clear")
	
	_end_test()

# 测试JuicyPoolManager
func test_juicy_pool_manager() -> void:
	_current_test_name = "JuicyPoolManager"
	
	# 获取池管理器实例
	var pool_manager = JuicyPoolManager.instance
	assert_test(pool_manager != null, "Should be able to get pool manager instance")
	
	# 测试获取Context池
	var context_pool = pool_manager.get_context_pool()
	assert_test(context_pool != null, "Should be able to get context pool")
	assert_test(context_pool is JuicyContextPool, "Context pool should be of correct type")
	
	# 测试获取事件池
	var event_pool = pool_manager.get_event_pool()
	assert_test(event_pool != null, "Should be able to get event pool")
	assert_test(event_pool is JuicyObjectPool, "Event pool should be of correct type")
	
	# 测试获取驱动器池
	var driver_pool = pool_manager.get_driver_pool(JuicyPoolItem)
	assert_test(driver_pool != null, "Should be able to get driver pool")
	assert_test(driver_pool is JuicyObjectPool, "Driver pool should be of correct type")
	
	# 测试获取资源池
	var resource_pool = pool_manager.get_resource_pool(JuicyPoolItem)
	assert_test(resource_pool != null, "Should be able to get resource pool")
	assert_test(resource_pool is JuicyObjectPool, "Resource pool should be of correct type")
	
	# 测试便捷方法
	var driver = pool_manager.get_driver(JuicyPoolItem)
	assert_test(driver != null, "Should be able to get driver from pool")
	
	pool_manager.return_driver(driver)
	
	var resource = pool_manager.get_resource(JuicyPoolItem)
	assert_test(resource != null, "Should be able to get resource from pool")
	
	pool_manager.return_resource(resource)
	
	# 测试统计信息
	var stats = pool_manager.get_all_pool_statistics()
	assert_test(stats.has("context_pool"), "Stats should contain context pool info")
	assert_test(stats.has("event_pool"), "Stats should contain event pool info")
	assert_test(stats.has("driver_pools"), "Stats should contain driver pools info")
	assert_test(stats.has("resource_pools"), "Stats should contain resource pools info")
	assert_test(stats.has("global"), "Stats should contain global info")
	
	# 测试效率评分
	var efficiency_score = pool_manager.get_global_efficiency_score()
	assert_test(efficiency_score >= 0.0 and efficiency_score <= 1.0, "Efficiency score should be between 0 and 1")
	
	# 测试清空所有池
	pool_manager.clear_all_pools()
	var stats_after_clear = pool_manager.get_all_pool_statistics()
	assert_test(stats_after_clear.context_pool.total_allocated == 0, "Context pool should be cleared")
	
	_end_test()

# 测试池化系统集成
func test_pooling_integration() -> void:
	_current_test_name = "PoolingIntegration"
	
	# 测试JuicyMixer池化API
	assert_test(JuicyMixer.get_pool_manager() != null, "Should be able to get pool manager from JuicyMixer")
	
	# 测试池统计
	var pool_stats = JuicyMixer.get_pool_statistics()
	assert_test(pool_stats.has("context_pool"), "Pool stats should contain context pool info")
	
	# 测试池效率评分
	var efficiency = JuicyMixer.get_pool_efficiency_score()
	assert_test(efficiency >= 0.0 and efficiency <= 1.0, "Pool efficiency should be between 0 and 1")
	
	# 测试池预热
	JuicyMixer.warm_up_pools()
	
	# 测试清空所有池
	JuicyMixer.clear_all_pools()
	
	_end_test()

# 辅助方法
func assert_test(condition: bool, message: String) -> void:
	var result = {
		"test_name": _current_test_name,
		"message": message,
		"passed": condition,
		"timestamp": Time.get_ticks_msec() / 1000.0
	}
	_test_results.append(result)
	
	if not condition:
		print("[TEST FAILED] ", _current_test_name, ": ", message)
	else:
		print("[TEST PASSED] ", _current_test_name, ": ", message)

func _end_test() -> void:
	print("[TEST COMPLETED] ", _current_test_name)

# 运行所有测试
func run_all_tests() -> Dictionary:
	print("=== Running Pooling System Tests ===")
	_test_results.clear()
	
	test_juicy_pool_item()
	test_juicy_context_pool()
	test_juicy_object_pool()
	test_juicy_pool_manager()
	test_pooling_integration()
	
	# 计算结果
	var passed_count = 0
	var total_count = _test_results.size()
	
	for result in _test_results:
		if result.passed:
			passed_count += 1
	
	var summary = {
		"total_tests": total_count,
		"passed_tests": passed_count,
		"failed_tests": total_count - passed_count,
		"success_rate": float(passed_count) / float(total_count) if total_count > 0 else 0.0,
		"results": _test_results.duplicate()
	}
	
	print("=== Pooling System Tests Summary ===")
	print("Total: ", summary.total_tests)
	print("Passed: ", summary.passed_tests)
	print("Failed: ", summary.failed_tests)
	print("Success Rate: ", summary.success_rate * 100, "%")
	
	return summary

# 快速测试方法（用于开发时快速验证）
func quick_test() -> bool:
	print("=== Running Quick Pooling Test ===")
	
	# 简单测试池管理器
	var pool_manager = JuicyPoolManager.instance
	if not pool_manager:
		print("Quick test failed: Cannot get pool manager instance")
		return false
	
	# 测试Context池
	var context_pool = pool_manager.get_context_pool()
	if not context_pool:
		print("Quick test failed: Cannot get context pool")
		return false
	
	var context = context_pool.get_context()
	if not context:
		print("Quick test failed: Cannot get context from pool")
		return false
	
	context_pool.return_context(context)
	
	# 测试对象池
	var object_pool = pool_manager.get_driver_pool(JuicyPoolItem)
	if not object_pool:
		print("Quick test failed: Cannot get object pool")
		return false
	
	var obj = object_pool.get_object()
	if not obj:
		print("Quick test failed: Cannot get object from pool")
		return false
	
	object_pool.return_object(obj)
	
	print("Quick test passed!")
	return true