# MiddlewarePerformanceBenchmark - 中间件性能基准测试
# 测试优化前后的性能对比，验证优化效果

extends Node
class_name MiddlewarePerformanceBenchmark

# 测试结果存储
var _test_results: Dictionary = {}
var _baseline_results: Dictionary = {}
var _optimization_results: Dictionary = {}

# 性能指标
var _performance_metrics: Dictionary = {
	"validation_overhead": {},
	"execution_time": {},
	"memory_usage": {},
	"throughput": {}
}

# 测试配置
var _test_config: Dictionary = {
	"iterations": 1000,
	"warmup_iterations": 100,
	"test_contexts_count": 100,
	"enable_memory_profiling": true,
	"enable_detailed_logging": false
}

# 中间件实例
var _validation_middleware: ValidationMiddleware
var _event_middleware: EventHandlingMiddleware
var _lod_middleware: JuicyLODMiddleware

# 测试节点
var _test_nodes: Array = []
var _test_camera: Camera2D

# 常量
const TEST_NODE_COUNT = 50
const MAX_TEST_DISTANCE = 1000.0

func _ready():
	# 初始化测试环境
	_setup_test_environment()
	
	# 运行基准测试
	run_performance_benchmark()

func _setup_test_environment():
	"""设置测试环境"""
	# 创建测试节点
	_create_test_nodes()
	
	# 创建测试摄像机
	_create_test_camera()
	
	# 初始化中间件
	_initialize_middleware()
	
	print("测试环境设置完成")

func _create_test_nodes():
	"""创建测试节点"""
	for i in range(TEST_NODE_COUNT):
		var node = Node2D.new()
		node.name = "TestNode_" + str(i)
		node.position = Vector2(randf_range(-500, 500), randf_range(-500, 500))
		add_child(node)
		_test_nodes.append(node)

func _create_test_camera():
	"""创建测试摄像机"""
	_test_camera = Camera2D.new()
	_test_camera.name = "TestCamera"
	_test_camera.position = Vector2(0, 0)
	add_child(_test_camera)

func _initialize_middleware():
	"""初始化中间件"""
	# 验证中间件
	_validation_middleware = ValidationMiddleware.new()
	_validation_middleware.initialize({
		"strict_mode": false,
		"validate_target_properties": true,
		"validate_resource_config": true,
		"validate_time_parameters": true
	})
	
	# 事件处理中间件
	_event_middleware = EventHandlingMiddleware.new()
	_event_middleware.initialize()
	
	# LOD中间件
	_lod_middleware = JuicyLODMiddleware.new()
	_lod_middleware.initialize()
	_lod_middleware.set_camera(_test_camera)

func run_performance_benchmark():
	"""运行性能基准测试"""
	print("=== 开始中间件性能基准测试 ===")
	
	# 运行各个性能测试
	_run_validation_overhead_test()
	_run_execution_time_test()
	_run_memory_usage_test()
	_run_throughput_test()
	
	# 生成测试报告
	_generate_performance_report()
	
	print("=== 性能基准测试完成 ===")

func _run_validation_overhead_test():
	"""验证开销测试 - 测量重复验证的消除效果"""
	print("\n--- 验证开销测试 ---")
	
	var start_time = Time.get_ticks_usec()
	var validation_eliminated_count = 0
	
	# 测试优化前（模拟重复验证）
	for i in range(_test_config.iterations):
		var context = _create_test_context(i)
		
		# 模拟重复验证（优化前）
		for j in range(5):  # 每个context验证5次
			_validation_middleware.execute(context, func(): return true)
	
	var baseline_time = Time.get_ticks_usec() - start_time
	
	# 测试优化后（使用验证信任机制）
	start_time = Time.get_ticks_usec()
	_validation_middleware.set_validation_passed(true)  # 模拟前置验证通过
	
	for i in range(_test_config.iterations):
		var context = _create_test_context(i)
		
		# 使用验证信任机制（优化后）
		_validation_middleware.execute(context, func(): return true)
	
	var optimized_time = Time.get_ticks_usec() - start_time
	
	# 计算改进百分比
	var improvement_percent = 0.0
	if baseline_time > 0:
		improvement_percent = ((baseline_time - optimized_time) / baseline_time) * 100
	
	# 存储结果
	_performance_metrics.validation_overhead = {
		"baseline_time_ms": baseline_time / 1000.0,
		"optimized_time_ms": optimized_time / 1000.0,
		"improvement_percent": improvement_percent,
		"iterations": _test_config.iterations
	}
	
	print("验证开销优化结果:")
	print("  基线时间: %.2f ms" % _performance_metrics.validation_overhead.baseline_time_ms)
	print("  优化时间: %.2f ms" % _performance_metrics.validation_overhead.optimized_time_ms)
	print("  性能提升: %.1f%%" % _performance_metrics.validation_overhead.improvement_percent)

func _run_execution_time_test():
	"""中间件执行时间测试"""
	print("\n--- 中间件执行时间测试 ---")
	
	var middlewares = [
		{"name": "ValidationMiddleware", "instance": _validation_middleware},
		{"name": "EventHandlingMiddleware", "instance": _event_middleware},
		{"name": "LODMiddleware", "instance": _lod_middleware}
	]
	
	for middleware_data in middlewares:
		var middleware = middleware_data.instance
		var name = middleware_data.name
		
		# 预热
		for i in range(_test_config.warmup_iterations):
			var context = _create_test_context(i)
			middleware.execute(context, func(): return true)
		
		# 正式测试
		var start_time = Time.get_ticks_usec()
		var total_time = 0.0
		
		for i in range(_test_config.iterations):
			var context = _create_test_context(i)
			var iter_start = Time.get_ticks_usec()
			middleware.execute(context, func(): return true)
			var iter_time = Time.get_ticks_usec() - iter_start
			total_time += iter_time
		
		var avg_time = total_time / _test_config.iterations
		
		_performance_metrics.execution_time[name] = {
			"average_time_ms": avg_time / 1000.0,
			"total_time_ms": total_time / 1000.0,
			"iterations": _test_config.iterations
		}
		
		print("  %s: 平均 %.3f ms/次" % [name, _performance_metrics.execution_time[name].average_time_ms])

func _run_memory_usage_test():
	"""内存使用测试"""
	print("\n--- 内存使用测试 ---")
	
	if not _test_config.enable_memory_profiling:
		print("  内存分析已禁用")
		return
	
	# 获取初始内存使用
	var initial_memory = OS.get_static_memory_usage()
	
	# 创建大量context进行测试
	var contexts = []
	for i in range(_test_config.test_contexts_count):
		var context = _create_test_context(i)
		contexts.append(context)
	
	# 执行中间件处理
	for context in contexts:
		_validation_middleware.execute(context, func(): return true)
		_event_middleware.execute(context, func(): return true)
		_lod_middleware.execute(context, func(): return true)
	
	# 获取最终内存使用
	var final_memory = OS.get_static_memory_usage()
	var memory_increase = final_memory - initial_memory
	
	# 计算每个context的平均内存使用
	var avg_memory_per_context = memory_increase / _test_config.test_contexts_count
	
	_performance_metrics.memory_usage = {
		"initial_memory_kb": initial_memory / 1024.0,
		"final_memory_kb": final_memory / 1024.0,
		"memory_increase_kb": memory_increase / 1024.0,
		"avg_memory_per_context_kb": avg_memory_per_context / 1024.0,
		"context_count": _test_config.test_contexts_count
	}
	
	print("  初始内存: %.2f KB" % _performance_metrics.memory_usage.initial_memory_kb)
	print("  最终内存: %.2f KB" % _performance_metrics.memory_usage.final_memory_kb)
	print("  内存增长: %.2f KB" % _performance_metrics.memory_usage.memory_increase_kb)
	print("  平均每Context: %.2f KB" % _performance_metrics.memory_usage.avg_memory_per_context_kb)

func _run_throughput_test():
	"""吞吐量测试 - 每秒处理的context数量"""
	print("\n--- 吞吐量测试 ---")
	
	var test_duration = 5.0  # 测试5秒
	var processed_count = 0
	var start_time = Time.get_ticks_msec()
	
	while (Time.get_ticks_msec() - start_time) / 1000.0 < test_duration:
		var context = _create_test_context(processed_count)
		
		# 执行完整的中间件链
		_validation_middleware.execute(context, func():
			return _event_middleware.execute(context, func():
				return _lod_middleware.execute(context, func():
					return true
				)
			)
		)
		
		processed_count += 1
	
	var actual_duration = (Time.get_ticks_msec() - start_time) / 1000.0
	var throughput = processed_count / actual_duration
	
	_performance_metrics.throughput = {
		"processed_count": processed_count,
		"duration_seconds": actual_duration,
		"throughput_per_second": throughput
	}
	
	print("  处理数量: %d" % _performance_metrics.throughput.processed_count)
	print("  测试时长: %.2f 秒" % _performance_metrics.throughput.duration_seconds)
	print("  吞吐量: %.1f context/秒" % _performance_metrics.throughput.throughput_per_second)

func _create_test_context(index: int) -> JuicyContext:
	"""创建测试用的Context"""
	# 创建测试资源 - 使用具体的资源类而不是抽象类
	var resource = JuicyShakeResource.new()
	resource.duration = 1.0
	# 使用add_shake_data方法添加震动数据，而不是直接设置amplitude和frequency
	resource.add_shake_data("position", 10.0, 5.0, 1.0)
	
	# 选择测试节点
	var node_index = index % _test_nodes.size()
	var target_node = _test_nodes[node_index]
	
	# 创建Context
	var context = JuicyContext.create(resource, target_node)
	context.time_scale = randf_range(0.5, 2.0)
	
	return context

func _generate_performance_report():
	"""生成性能测试报告"""
	print("\n=== 性能测试报告 ===")
	
	# 验证开销报告
	if _performance_metrics.validation_overhead:
		print("\n验证开销优化:")
		print("  基线时间: %.2f ms" % _performance_metrics.validation_overhead.baseline_time_ms)
		print("  优化时间: %.2f ms" % _performance_metrics.validation_overhead.optimized_time_ms)
		print("  性能提升: %.1f%%" % _performance_metrics.validation_overhead.improvement_percent)
	
	# 执行时间报告
	print("\n中间件执行时间:")
	for middleware_name in _performance_metrics.execution_time.keys():
		var data = _performance_metrics.execution_time[middleware_name]
		print("  %s: %.3f ms/次" % [middleware_name, data.average_time_ms])
	
	# 内存使用报告
	if _performance_metrics.memory_usage:
		print("\n内存使用情况:")
		print("  内存增长: %.2f KB" % _performance_metrics.memory_usage.memory_increase_kb)
		print("  平均每Context: %.2f KB" % _performance_metrics.memory_usage.avg_memory_per_context_kb)
	
	# 吞吐量报告
	if _performance_metrics.throughput:
		print("\n吞吐量:")
		print("  %.1f context/秒" % _performance_metrics.throughput.throughput_per_second)
	
	# 保存详细报告到文件
	_save_detailed_report()

func _save_detailed_report():
	"""保存详细报告到文件"""
	var report_data = {
		"test_timestamp": Time.get_datetime_string_from_system(),
		"test_config": _test_config,
		"performance_metrics": _performance_metrics,
		"summary": _generate_summary()
	}
	
	var file_path = "user://middleware_performance_report.json"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report_data, "\t"))
		file.close()
		print("\n详细报告已保存到: " + file_path)

func _generate_summary() -> Dictionary:
	"""生成测试摘要"""
	return {
		"total_tests": 4,
		"validation_optimization_improved": _performance_metrics.validation_overhead.improvement_percent > 0,
		"validation_improvement_percent": _performance_metrics.validation_overhead.improvement_percent,
		"average_execution_time_ms": _calculate_average_execution_time(),
		"memory_efficiency": _performance_metrics.memory_usage.avg_memory_per_context_kb if _performance_metrics.memory_usage else 0,
		"throughput_contexts_per_second": _performance_metrics.throughput.throughput_per_second
	}

func _calculate_average_execution_time() -> float:
	"""计算平均执行时间"""
	var total_time = 0.0
	var count = 0
	
	for middleware_name in _performance_metrics.execution_time.keys():
		total_time += _performance_metrics.execution_time[middleware_name].average_time_ms
		count += 1
	
	return total_time / max(count, 1)

func get_performance_metrics() -> Dictionary:
	"""获取性能指标"""
	return _performance_metrics.duplicate()

func get_test_results() -> Dictionary:
	"""获取测试结果"""
	return _test_results.duplicate()

func cleanup():
	"""清理测试环境"""
	# 清理测试节点
	for node in _test_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_test_nodes.clear()
	
	# 清理摄像机
	if is_instance_valid(_test_camera):
		_test_camera.queue_free()
	
	# 清理中间件
	if _validation_middleware:
		_validation_middleware.destroy()
	if _event_middleware:
		_event_middleware.destroy()
	if _lod_middleware:
		_lod_middleware.destroy()
	
	print("测试环境已清理")
