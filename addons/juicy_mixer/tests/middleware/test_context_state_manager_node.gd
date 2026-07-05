# ContextStateManager测试节点
# 基于Node的测试，用于验证统一Context状态管理器的功能

extends Node

# 测试状态
var _test_passed: int = 0
var _test_failed: int = 0
var _test_results: Array[String] = []

# 测试组件
var _state_manager: ContextStateManager
var _channel_middleware: ChannelMiddleware
var _interruption_middleware: InterruptionMiddleware
var _test_target: Node

# 初始化测试
func _ready():
	print("=== ContextStateManager Node测试开始 ===")
	_run_all_tests()
	_print_test_results()

# 运行所有测试
func _run_all_tests():
	_setup_test_environment()
	
	# 运行各个测试
	_test_singleton_pattern()
	_test_basic_state_sync()
	_test_target_context_tracking()
	_test_channel_overview()
	_test_state_consistency()
	_test_context_lifecycle()
	_test_statistics()
	_test_compatibility_interfaces()
	_test_cleanup()
	
	_cleanup_test_environment()

# 设置测试环境
func _setup_test_environment():
	# 重置状态管理器单例
	ContextStateManager.reset_instance()
	_state_manager = ContextStateManager.get_instance()
	
	# 创建测试中间件
	_channel_middleware = ChannelMiddleware.new()
	_interruption_middleware = InterruptionMiddleware.new()
	_channel_middleware.initialize()
	_interruption_middleware.initialize()
	
	# 创建测试目标节点
	_test_target = Node.new()
	add_child(_test_target)

# 清理测试环境
func _cleanup_test_environment():
	if _test_target:
		_test_target.queue_free()
	if _channel_middleware:
		_channel_middleware.destroy()
	if _interruption_middleware:
		_interruption_middleware.destroy()
	ContextStateManager.reset_instance()

# 创建测试Context
func _create_test_context(target: Node = null) -> JuicyContext:
	if not target:
		target = _test_target
	
	var test_resource = JuicyTweenResource.new()
	test_resource.duration = 1.0
	test_resource.channel = "test_channel"
	return JuicyContext.create(test_resource, target, self)

# 记录测试结果
func _record_test_result(test_name: String, passed: bool, message: String = ""):
	var result = "["
	result += "PASS" if passed else "FAIL"
	result += "] " + test_name
	if message:
		result += " - " + message
	_test_results.append(result)
	
	if passed:
		_test_passed += 1
	else:
		_test_failed += 1
		print("测试失败: " + test_name + " - " + message)

# 打印测试结果
func _print_test_results():
	print("\n=== 测试结果 ===")
	for result in _test_results:
		print(result)
	
	print("\n总计: %d 通过, %d 失败" % [_test_passed, _test_failed])
	if _test_failed == 0:
		print("✅ 所有测试通过!")
	else:
		print("❌ 有测试失败!")

# 测试单例模式
func _test_singleton_pattern():
	var instance1 = ContextStateManager.get_instance()
	var instance2 = ContextStateManager.get_instance()
	
	_record_test_result("单例模式", instance1 == instance2, 
		"应该返回同一个单例实例")

# 测试基本状态同步
func _test_basic_state_sync():
	var context = _create_test_context()
	
	# 同步Context状态
	_state_manager.sync_context_state(context, _channel_middleware, _interruption_middleware)
	
	# 验证状态信息
	var info = _state_manager.get_unified_context_info(context.context_id)
	var passed = info != null and info.context_id == context.context_id
	
	_record_test_result("基本状态同步", passed,
		"应该能获取到统一状态信息且Context ID匹配")
	
	

# 测试目标Context跟踪
func _test_target_context_tracking():
	var context = _create_test_context()
	context.is_active = true  # 设置为活跃状态
	
	# 同步Context状态
	_state_manager.sync_context_state(context, _channel_middleware, _interruption_middleware)
	
	# 获取活跃Context
	var active_contexts = _state_manager.get_active_contexts_for_target(_test_target)
	var passed = active_contexts.size() == 1 and active_contexts[0] == context.context_id
	
	_record_test_result("目标Context跟踪", passed,
		"应该有一个活跃Context且ID匹配")
	
	

# 测试通道概览
func _test_channel_overview():
	# 确保干净的环境
	_state_manager.cleanup_all()
	
	var context = _create_test_context()
	
	# 同步Context状态
	_state_manager.sync_context_state(context, _channel_middleware, _interruption_middleware)
	
	# 获取通道概览
	var overview = _state_manager.get_channel_overview("test_channel")
	var passed = overview != null and overview.total == 1
	
	_record_test_result("通道概览", passed,
		"应该能获取通道概览且有一个Context")
	
	

# 测试状态一致性
func _test_state_consistency():
	# 确保干净的环境
	_state_manager.cleanup_all()
	
	var context = _create_test_context()
	
	# 同步Context状态
	_state_manager.sync_context_state(context, _channel_middleware, _interruption_middleware)
	
	# 验证状态一致性
	var result = _state_manager.validate_state_consistency(_channel_middleware, _interruption_middleware)
	var passed = result.consistent and result.stats.total_contexts == 1
	
	_record_test_result("状态一致性", passed,
		"状态应该是一致的且有一个Context")
	
	

# 测试Context生命周期
func _test_context_lifecycle():
	var context = _create_test_context()
	
	# 创建Context
	_state_manager.sync_context_state(context, _channel_middleware, _interruption_middleware)
	
	var info = _state_manager.get_unified_context_info(context.context_id)
	var created_passed = info != null
	
	# 移除Context
	_state_manager.remove_context_sync(context.context_id)
	
	info = _state_manager.get_unified_context_info(context.context_id)
	var removed_passed = info == null
	
	_record_test_result("Context生命周期", created_passed and removed_passed,
		"应该能创建和移除Context")
	
	

# 测试统计功能
func _test_statistics():
	# 确保干净的环境
	_state_manager.cleanup_all()
	
	var context = _create_test_context()
	
	# 同步Context状态
	_state_manager.sync_context_state(context, _channel_middleware, _interruption_middleware)
	
	# 获取统计信息
	var stats = _state_manager.get_statistics()
	var passed = stats.has("total_contexts") and stats.total_contexts == 1
	
	# 获取摘要信息
	var summary = _state_manager.get_contexts_summary()
	var summary_passed = summary.total == 1 and summary.targets == 1
	
	_record_test_result("统计功能", passed and summary_passed,
		"统计和摘要信息应该正确")
	
	

# 测试兼容性接口
func _test_compatibility_interfaces():
	# 确保干净的环境
	_state_manager.cleanup_all()
	
	var context = _create_test_context()
	context.is_active = true  # 设置为活跃状态
	
	# 同步Context状态
	_state_manager.sync_context_state(context, _channel_middleware, _interruption_middleware)
	
	# 测试兼容性接口
	var active_count = _state_manager.get_active_contexts_count()
	var queued_count = _state_manager.get_queued_contexts_count()
	var has_active = _state_manager.has_active_contexts()
	
	var passed = active_count == 1 and queued_count == 0 and has_active
	
	# 测试摘要接口
	var summary = _state_manager.get_contexts_summary()
	var summary_passed = summary.active == 1 and summary.total == 1
	
	_record_test_result("兼容性接口", passed and summary_passed,
		"兼容性接口应该正确工作")
	
	

# 测试清理功能
func _test_cleanup():
	# 确保干净的环境
	_state_manager.cleanup_all()
	
	var context = _create_test_context()
	
	# 同步Context状态
	_state_manager.sync_context_state(context, _channel_middleware, _interruption_middleware)
	
	# 验证有数据
	var before_cleanup = _state_manager.get_statistics().total_contexts
	
	# 清理所有数据
	_state_manager.cleanup_all()
	
	# 验证数据被清理
	var after_cleanup = _state_manager.get_statistics().total_contexts
	
	_record_test_result("清理功能", before_cleanup == 1 and after_cleanup == 0,
		"应该能正确清理所有数据")
	
	

# 测试多个Context
func _test_multiple_contexts():
	var contexts = []
	for i in range(3):
		var context = _create_test_context()
		context.is_active = true  # 设置为活跃状态
		contexts.append(context)
		_state_manager.sync_context_state(context, _channel_middleware, _interruption_middleware)
	
	# 验证多个Context
	var active_count = _state_manager.get_active_contexts_count()
	var summary = _state_manager.get_contexts_summary()
	
	var passed = active_count == 3 and summary.total == 3 and summary.active == 3
	
	_record_test_result("多个Context管理", passed,
		"应该能正确管理多个Context")
	

		

# 测试状态转换
func _test_state_transitions():
	var context = _create_test_context()
	
	# 初始状态
	_state_manager.sync_context_state(context, _channel_middleware, _interruption_middleware)
	var info = _state_manager.get_unified_context_info(context.context_id)
	var initial_status = info.status if info else "unknown"
	
	# 模拟状态转换
	context.is_paused = true  # 模拟暂停状态
	_state_manager.sync_context_state(context, _channel_middleware, _interruption_middleware)
	info = _state_manager.get_unified_context_info(context.context_id)
	var queued_status = info.status if info else "unknown"
	
	var passed = initial_status != "unknown" and queued_status != "unknown"
	
	_record_test_result("状态转换", passed,
		"应该能正确处理状态转换")
	
	
