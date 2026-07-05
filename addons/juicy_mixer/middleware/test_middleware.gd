# TestMiddleware - 中间件基类测试脚本
# 用于验证JuicyMiddleware基类的核心功能

class_name TestMiddleware
extends Node

# 测试计数器
var _test_count = 0
var _passed_count = 0
var _failed_count = 0

# 测试结果
var _test_results = []

func _ready():
	print("开始 JuicyMiddleware 基类测试...")
	run_all_tests()

func run_all_tests():
	print("\n" + "=".repeat(50))
	print("运行所有测试")
	print("=".repeat(50))
	
	# 测试1: 基本初始化
	test_basic_initialization()
	
	# 测试2: 配置管理
	test_configuration_management()
	
	# 测试3: 性能监控
	test_performance_monitoring()
	
	# 测试4: 生命周期管理
	test_lifecycle_management()
	
	# 测试5: 验证接口
	test_validation_interface()
	
	# 测试6: 日志记录
	test_logging()
	
	# 打印测试总结
	print_test_summary()

# 测试1: 基本初始化
func test_basic_initialization():
	print("\n测试1: 基本初始化")
	
	var middleware = _create_test_middleware()
	
	# 测试元信息
	assert_equal(middleware.middleware_name, "TestMiddleware", "中间件名称应该正确")
	assert_equal(middleware.middleware_version, "1.0.0", "中间件版本应该正确")
	assert_equal(middleware.priority, 100, "中间件优先级应该正确")
	
	# 测试初始化状态
	assert_false(middleware._is_initialized, "中间件应该未初始化")
	
	# 测试初始化
	var config = {"test_param": "test_value"}
	var init_result = middleware.initialize(config)
	assert_true(init_result, "中间件初始化应该成功")
	assert_true(middleware._is_initialized, "中间件应该已初始化")
	assert_true(middleware._is_configured, "中间件应该已配置")
	
	# 测试激活状态
	assert_true(middleware.is_active, "中间件应该默认激活")
	assert_true(middleware.is_ready(), "中间件应该准备好执行")
	
	_test_count += 1
	_passed_count += 1
	print("✓ 基本初始化测试通过")

# 测试2: 配置管理
func test_configuration_management():
	print("\n测试2: 配置管理")
	
	var middleware = _create_test_middleware()
	middleware.initialize()
	
	# 测试获取配置
	var config = middleware.get_configuration()
	assert_true(config.has("enable_performance_monitoring"), "配置应该包含性能监控设置")
	
	# 测试默认配置
	var default_config = middleware.get_default_configuration()
	assert_true(default_config.has("enable_performance_monitoring"), "默认配置应该包含性能监控设置")
	
	# 测试配置更新
	var new_config = {
		"enable_performance_monitoring": false,
		"priority": 200,
		"custom_param": "custom_value"
	}
	
	var update_result = middleware.configure(new_config)
	assert_true(update_result, "配置更新应该成功")
	
	var updated_config = middleware.get_configuration()
	assert_equal(updated_config["enable_performance_monitoring"], false, "性能监控设置应该更新")
	assert_equal(updated_config["priority"], 200, "优先级应该更新")
	assert_equal(updated_config["custom_param"], "custom_value", "自定义参数应该添加")
	
	_test_count += 1
	_passed_count += 1
	print("✓ 配置管理测试通过")

# 测试3: 性能监控
func test_performance_monitoring():
	print("\n测试3: 性能监控")
	
	var middleware = _create_test_middleware()
	middleware.initialize()
	
	# 测试初始性能统计
	var initial_stats = middleware.get_performance_stats()
	assert_equal(initial_stats.execution_count, 0, "初始执行次数应该为0")
	assert_equal(initial_stats.total_execution_time, 0.0, "初始总执行时间应该为0")
	
	# 模拟执行
	middleware._execution_count = 5
	middleware._total_execution_time = 10.5
	middleware._last_execution_time = 2.1
	
	var updated_stats = middleware.get_performance_stats()
	assert_equal(updated_stats.execution_count, 5, "执行次数应该正确")
	assert_equal(updated_stats.total_execution_time, 10.5, "总执行时间应该正确")
	assert_equal(updated_stats.average_execution_time, 2.1, "平均执行时间应该正确")
	
	# 测试重置统计
	middleware.reset_performance_stats()
	var reset_stats = middleware.get_performance_stats()
	assert_equal(reset_stats.execution_count, 0, "重置后执行次数应该为0")
	assert_equal(reset_stats.total_execution_time, 0.0, "重置后总执行时间应该为0")
	
	_test_count += 1
	_passed_count += 1
	print("✓ 性能监控测试通过")

# 测试4: 生命周期管理
func test_lifecycle_management():
	print("\n测试4: 生命周期管理")
	
	var middleware = _create_test_middleware()
	middleware.initialize()
	
	# 创建测试Context
	var context = _create_test_context()
	
	# 测试Context创建事件
	middleware.handle_context_event(context, "created")
	assert_equal(middleware._context_count, 1, "Context计数应该增加")
	assert_equal(middleware._current_context, context, "当前Context应该设置")
	
	# 测试Context暂停事件
	middleware.handle_context_event(context, "paused")
	
	# 测试Context恢复事件
	middleware.handle_context_event(context, "resumed")
	
	# 测试Context销毁事件
	middleware.handle_context_event(context, "destroyed")
	
	# 测试当前Context
	assert_equal(middleware._current_context, context, "当前Context应该保持")
	
	_test_count += 1
	_passed_count += 1
	print("✓ 生命周期管理测试通过")

# 测试5: 验证接口
func test_validation_interface():
	print("\n测试5: 验证接口")
	
	var middleware = _create_test_middleware()
	middleware.initialize()
	
	# 测试Context验证
	var context = _create_test_context()
	var validation = middleware.validate_context(context)
	
	assert_true(validation.valid, "Context验证应该通过")
	assert_true(validation.issues.is_empty(), "不应该有错误信息")
	
	# 测试无效Context
	var invalid_context = null
	var invalid_validation = middleware.validate_context(invalid_context)
	assert_false(invalid_validation.valid, "无效Context应该验证失败")
	assert_false(invalid_validation.issues.is_empty(), "应该有错误信息")
	
	# 测试目标节点验证
	var targetless_context = JuicyContext.new()
	targetless_context.resource = null
	targetless_context.target = null
	
	var targetless_validation = middleware.validate_context(targetless_context)
	assert_false(targetless_validation.valid, "无目标节点的Context应该验证失败")
	
	_test_count += 1
	_passed_count += 1
	print("✓ 验证接口测试通过")

# 测试6: 日志记录
func test_logging():
	print("\n测试6: 日志记录")
	
	var middleware = _create_test_middleware()
	middleware.initialize()
	
	# 启用调试日志
	middleware.set_debug_logging(true)
	
	# 测试错误日志
	middleware._log_error("测试错误消息", {"test": "data"})
	assert_equal(middleware._error_count, 1, "错误计数应该增加")
	assert_equal(middleware._error_log.size(), 1, "错误日志应该有一条记录")
	
	# 测试警告日志
	middleware._log_warning("测试警告消息", {"test": "data"})
	assert_equal(middleware._warning_count, 1, "警告计数应该增加")
	assert_equal(middleware._debug_log.size(), 2, "调试日志应该有两条记录")
	
	# 测试调试日志
	middleware._log_debug("测试调试消息", {"test": "data"})
	assert_equal(middleware._debug_log.size(), 3, "调试日志应该有三条记录")
	
	# 测试获取日志
	var error_log = middleware.get_error_log()
	assert_equal(error_log.size(), 1, "错误日志应该有一条记录")
	
	var debug_log = middleware.get_debug_log()
	assert_equal(debug_log.size(), 3, "调试日志应该有三条记录")
	
	# 测试清除日志
	middleware.clear_logs()
	assert_equal(middleware._error_log.size(), 0, "错误日志应该被清除")
	assert_equal(middleware._debug_log.size(), 0, "调试日志应该被清除")
	
	_test_count += 1
	_passed_count += 1
	print("✓ 日志记录测试通过")

# 辅助函数
func _create_test_middleware() -> JuicyMiddleware:
	var middleware = preload("example_middleware.gd").new()
	middleware.middleware_name = "TestMiddleware"
	middleware.priority = 100
	return middleware

func _create_test_context() -> JuicyContext:
	# 这里需要实际的JuicyContext类，我们创建一个简化的版本
	var context = JuicyContext.new()
	context.context_id = "test_context_" + str(Time.get_ticks_msec())
	context.resource = JuicyTweenResource.new()
	context.target = Node2D.new()
	return context

# 断言函数
func assert_equal(expected, actual, message = ""):
	if expected != actual:
		_failed_count += 1
		print("✗ 断言失败: " + message)
		print("  期望: ", expected)
		print("  实际: ", actual)
		_test_results.append({
			"test": get_stack()[1].function,
			"message": message,
			"expected": expected,
			"actual": actual,
			"status": "FAILED"
		})
	else:
		print("  ✓ ", message)

func assert_true(condition, message = ""):
	if !condition:
		_failed_count += 1
		print("✗ 断言失败: " + message)
		print("  期望: true")
		print("  实际: ", condition)
		_test_results.append({
			"test": get_stack()[1].function,
			"message": message,
			"expected": true,
			"actual": condition,
			"status": "FAILED"
		})
	else:
		print("  ✓ ", message)

func assert_false(condition, message = ""):
	if condition:
		_failed_count += 1
		print("✗ 断言失败: " + message)
		print("  期望: false")
		print("  实际: ", condition)
		_test_results.append({
			"test": get_stack()[1].function,
			"message": message,
			"expected": false,
			"actual": condition,
			"status": "FAILED"
		})
	else:
		print("  ✓ ", message)

# 打印测试总结
func print_test_summary():
	print("\n" + "=".repeat(50))
	print("测试总结")
	print("=".repeat(50))
	print("总测试数: ", _test_count)
	print("通过测试: ", _passed_count)
	print("失败测试: ", _failed_count)
	print("成功率: ", float(_passed_count) / float(_test_count) * 100, "%")
	
	if _failed_count > 0:
		print("\n失败的测试:")
		for result in _test_results:
			if result.status == "FAILED":
				print("  - ", result.test, ": ", result.message)
	
	print("\n测试完成!")