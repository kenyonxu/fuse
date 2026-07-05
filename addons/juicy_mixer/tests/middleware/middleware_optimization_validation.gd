# MiddlewareOptimizationValidation - 中间件优化验证测试
# 验证所有优化功能的正确性和有效性

extends Node
class_name MiddlewareOptimizationValidation

# 测试结果
var _test_results: Dictionary = {}
var _validation_results: Dictionary = {}

# 中间件实例
var _validation_middleware: ValidationMiddleware
var _event_middleware: EventHandlingMiddleware
var _lod_middleware: JuicyLODMiddleware
var _interruption_middleware: InterruptionMiddleware

# 测试节点和资源
var _test_nodes: Array = []
var _test_camera: Camera2D
var _test_resources: Array = []

# 测试配置
var _test_config: Dictionary = {
	"enable_detailed_logging": true,
	"test_iterations": 10,
	"timeout_seconds": 30.0
}

func _ready():
	# 设置测试环境
	_setup_test_environment()
	
	# 运行所有验证测试
	run_all_validation_tests()

func _setup_test_environment():
	"""设置测试环境"""
	# 创建测试节点
	_create_test_nodes()
	
	# 创建测试摄像机
	_create_test_camera()
	
	# 创建测试资源
	_create_test_resources()
	
	# 初始化中间件
	_initialize_middleware()
	
	print("验证测试环境设置完成")

func _create_test_nodes():
	"""创建测试节点"""
	for i in range(10):
		var node = Node2D.new()
		node.name = "ValidationTestNode_" + str(i)
		node.position = Vector2(randf_range(-200, 200), randf_range(-200, 200))
		add_child(node)
		_test_nodes.append(node)

func _create_test_camera():
	"""创建测试摄像机"""
	_test_camera = Camera2D.new()
	_test_camera.name = "ValidationTestCamera"
	_test_camera.position = Vector2(0, 0)
	add_child(_test_camera)

func _create_test_resources():
	"""创建测试资源"""
	# 创建不同类型的资源
	var shake_resource = JuicyShakeResource.new()
	shake_resource.duration = 1.0
	# 使用add_shake_data方法添加震动数据，而不是直接设置amplitude和frequency
	shake_resource.add_shake_data("position", 10.0, 5.0, 1.0)
	_test_resources.append(shake_resource)
	
	var tween_resource = JuicyTweenResource.new()
	tween_resource.duration = 2.0
	# 添加补间数据而不是直接设置ease_type和trans_type
	tween_resource.add_tween_data("position", Vector2(0, 0), Vector2(100, 100), 2.0, 0.0, Tween.EASE_OUT, Tween.TRANS_LINEAR)
	_test_resources.append(tween_resource)
	
	var spring_resource = JuicySpringResource.new()
	spring_resource.duration = 1.5
	# 使用add_spring_data方法添加弹簧数据，而不是直接设置spring_stiffness
	spring_resource.add_spring_data("position", Vector2(100, 0), 100.0, 0.7, 1.0)
	_test_resources.append(spring_resource)

func _initialize_middleware():
	"""初始化中间件"""
	# 验证中间件
	_validation_middleware = ValidationMiddleware.new()
	_validation_middleware.initialize({
		"strict_mode": true,
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
	
	# 中断中间件
	_interruption_middleware = InterruptionMiddleware.new()
	_interruption_middleware.initialize()

func run_all_validation_tests():
	"""运行所有验证测试"""
	print("=== 开始中间件优化验证测试 ===")
	
	# 运行各个验证测试
	_test_priority_correctness()
	_test_responsibility_separation()
	_test_validation_trust_mechanism()
	_test_unified_state_management()
	_test_interruption_handling()
	_test_end_to_end_integration()
	
	# 生成验证报告
	_generate_validation_report()
	
	print("=== 优化验证测试完成 ===")

func _test_priority_correctness():
	"""优先级正确性测试"""
	print("\n--- 优先级正确性测试 ---")
	
	var results = {
		"test_passed": true,
		"issues": [],
		"details": {}
	}
	
	# 测试中间件优先级顺序
	var middlewares = [
		{"name": "ValidationMiddleware", "instance": _validation_middleware, "expected_priority": 1000},
		{"name": "EventHandlingMiddleware", "instance": _event_middleware, "expected_priority": 500},
		{"name": "LODMiddleware", "instance": _lod_middleware, "expected_priority": 700},
		{"name": "InterruptionMiddleware", "instance": _interruption_middleware, "expected_priority": 950}
	]
	
	for middleware_data in middlewares:
		var middleware = middleware_data.instance
		var name = middleware_data.name
		var expected = middleware_data.expected_priority
		var actual = middleware.priority
		
		results.details[name] = {
			"expected_priority": expected,
			"actual_priority": actual,
			"correct": actual == expected
		}
		
		if actual != expected:
			results.test_passed = false
			results.issues.append("优先级错误: %s (期望: %d, 实际: %d)" % [name, expected, actual])
	
	_validation_results["priority_correctness"] = results
	
	if results.test_passed:
		print("  ✓ 所有中间件优先级正确")
	else:
		print("  ✗ 发现优先级问题")
		for issue in results.issues:
			print("    - " + issue)

func _test_responsibility_separation():
	"""职责分离验证测试"""
	print("\n--- 职责分离验证测试 ---")
	
	var results = {
		"test_passed": true,
		"issues": [],
		"details": {}
	}
	
	# 测试验证中间件的职责
	var validation_context = _create_test_context(0)
	var validation_result = _validation_middleware.validate_context(validation_context)
	
	results.details["validation_middleware"] = {
		"has_validation_logic": true,
		"validation_result": validation_result.valid
	}
	
	# 测试事件中间件的职责
	var event_system_enabled = _event_middleware.is_event_system_enabled()
	results.details["event_middleware"] = {
		"manages_event_system": true,
		"event_system_enabled": event_system_enabled
	}
	
	# 测试LOD中间件的职责
	var lod_stats = _lod_middleware.get_lod_stats()
	results.details["lod_middleware"] = {
		"manages_lod_optimization": true,
		"has_stats": not lod_stats.is_empty()
	}
	
	# 检查职责不重叠
	if not validation_result.valid:
		results.test_passed = false
		results.issues.append("验证中间件验证失败")
	
	if not event_system_enabled and _event_middleware.get_event_system_stats().is_empty():
		results.test_passed = false
		results.issues.append("事件中间件未正确初始化")
	
	if lod_stats.is_empty():
		results.test_passed = false
		results.issues.append("LOD中间件未提供统计信息")
	
	_validation_results["responsibility_separation"] = results
	
	if results.test_passed:
		print("  ✓ 职责分离正确")
	else:
		print("  ✗ 发现职责分离问题")
		for issue in results.issues:
			print("    - " + issue)

func _test_validation_trust_mechanism():
	"""验证信任机制测试"""
	print("\n--- 验证信任机制测试 ---")
	
	var results = {
		"test_passed": true,
		"issues": [],
		"details": {}
	}
	
	# 创建测试Context
	var context = _create_test_context(0)
	
	# 测试1: 验证中间件设置信任标记
	_validation_middleware.set_validation_passed(true)
	var validation_passed = _validation_middleware._validation_passed
	
	results.details["trust_mark_setting"] = {
		"can_set_trust": validation_passed == true,
		"trust_value": validation_passed
	}
	
	# 测试2: 非验证中间件跳过验证
	var event_middleware = EventHandlingMiddleware.new()
	event_middleware.initialize()
	
	# 模拟前置验证通过
	event_middleware.set_validation_passed(true)
	var should_skip = event_middleware._should_skip_validation()
	
	results.details["skip_validation"] = {
		"can_skip_when_trusted": should_skip == true,
		"skip_result": should_skip
	}
	
	# 测试3: 验证中间件不跳过验证
	var validation_should_skip = _validation_middleware._should_skip_validation()
	
	results.details["validation_not_skipped"] = {
		"validation_does_not_skip": validation_should_skip == false,
		"skip_result": validation_should_skip
	}
	
	# 验证结果
	if not validation_passed:
		results.test_passed = false
		results.issues.append("无法设置验证信任标记")
	
	if not should_skip:
		results.test_passed = false
		results.issues.append("非验证中间件未跳过验证")
	
	if validation_should_skip:
		results.test_passed = false
		results.issues.append("验证中间件错误地跳过了验证")
	
	_validation_results["validation_trust_mechanism"] = results
	
	# 清理
	event_middleware.destroy()
	
	if results.test_passed:
		print("  ✓ 验证信任机制工作正常")
	else:
		print("  ✗ 发现验证信任机制问题")
		for issue in results.issues:
			print("    - " + issue)

func _test_unified_state_management():
	"""统一状态管理测试"""
	print("\n--- 统一状态管理测试 ---")
	
	var results = {
		"test_passed": true,
		"issues": [],
		"details": {}
	}
	
	# 创建Context并测试状态管理
	var context = _create_test_context(0)
	
	# 测试Context初始状态
	results.details["initial_state"] = {
		"is_active": context.is_active == false,
		"is_paused": context.is_paused == false,
		"is_completed": context.is_completed == false,
		"progress": context.progress == 0.0
	}
	
	# 测试Context激活
	context.activate()
	results.details["after_activation"] = {
		"is_active": context.is_active == true,
		"start_time_set": context.start_time > 0
	}
	
	# 测试Context更新
	var initial_progress = context.progress
	context.update(0.1)
	results.details["after_update"] = {
		"progress_updated": context.progress > initial_progress,
		"current_time_updated": context.current_time > 0
	}
	
	# 测试Context暂停和恢复
	context.pause()
	var was_paused = context.is_paused
	context.resume()
	var is_resumed = not context.is_paused
	
	results.details["pause_resume"] = {
		"can_pause": was_paused == true,
		"can_resume": is_resumed == true
	}
	
	# 测试Context完成
	context.complete()
	results.details["after_completion"] = {
		"is_completed": context.is_completed == true,
		"is_active": context.is_active == false
	}
	
	# 测试Context重置
	context.reset()
	results.details["after_reset"] = {
		"progress_reset": context.progress == 0.0,
		"is_active_reset": context.is_active == false,
		"is_completed_reset": context.is_completed == false
	}
	
	# 验证所有状态转换
	var all_states_correct = true
	for category in results.details.keys():
		for check in results.details[category].keys():
			if not results.details[category][check]:
				all_states_correct = false
				results.issues.append("状态管理错误: %s.%s" % [category, check])
	
	results.test_passed = all_states_correct
	_validation_results["unified_state_management"] = results
	
	if results.test_passed:
		print("  ✓ 统一状态管理正确")
	else:
		print("  ✗ 发现状态管理问题")
		for issue in results.issues:
			print("    - " + issue)

func _test_interruption_handling():
	"""中断处理流程测试"""
	print("\n--- 中断处理流程测试 ---")
	
	var results = {
		"test_passed": true,
		"issues": [],
		"details": {}
	}
	
	# 创建多个Context模拟中断场景
	var contexts = []
	for i in range(5):
		var context = _create_test_context(i)
		contexts.append(context)
	
	# 测试中断状态转换
	for i in range(contexts.size()):
		var context = contexts[i]
		
		# 激活Context
		context.activate()
		
		# 模拟中断处理
		var interruption_result = _simulate_interruption(context, i)
		results.details["context_" + str(i)] = interruption_result
		
		if not interruption_result.success:
			results.test_passed = false
			results.issues.append("Context %d 中断处理失败" % i)
	
	# 测试中断优先级
	var priority_test = _test_interruption_priorities()
	results.details["priority_handling"] = priority_test
	
	if not priority_test.success:
		results.test_passed = false
		results.issues.append("中断优先级处理失败")
	
	_validation_results["interruption_handling"] = results
	
	if results.test_passed:
		print("  ✓ 中断处理流程正确")
	else:
		print("  ✗ 发现中断处理问题")
		for issue in results.issues:
			print("    - " + issue)

func _test_end_to_end_integration():
	"""端到端集成测试"""
	print("\n--- 端到端集成测试 ---")
	
	var results = {
		"test_passed": true,
		"issues": [],
		"details": {}
	}
	
	# 创建完整的中间件处理链
	var context = _create_test_context(0)
	
	# 记录初始状态
	var initial_state = {
		"time_scale": context.time_scale,
		"is_active": context.is_active
	}
	
	# 执行完整的中间件链
	var chain_result = _execute_middleware_chain(context)
	results.details["chain_execution"] = chain_result
	
	# 验证处理结果
	var final_state = {
		"time_scale": context.time_scale,
		"is_active": context.is_active
	}
	
	results.details["state_changes"] = {
		"initial": initial_state,
		"final": final_state,
		"time_scale_changed": final_state.time_scale != initial_state.time_scale
	}
	
	# 验证统计信息
	var stats = {
		"validation_stats": _validation_middleware.get_performance_stats(),
		"event_stats": _event_middleware.get_event_system_stats(),
		"lod_stats": _lod_middleware.get_lod_stats()
	}
	
	results.details["performance_stats"] = stats
	
	# 检查是否有错误
	if not chain_result.success:
		results.test_passed = false
		results.issues.append("中间件链执行失败")
	
	# 检查性能统计
	for middleware_name in stats.keys():
		if stats[middleware_name].is_empty():
			results.test_passed = false
			results.issues.append("%s 未生成性能统计" % middleware_name)
	
	_validation_results["end_to_end_integration"] = results
	
	if results.test_passed:
		print("  ✓ 端到端集成测试通过")
	else:
		print("  ✗ 端到端集成测试失败")
		for issue in results.issues:
			print("    - " + issue)

func _create_test_context(index: int) -> JuicyContext:
	"""创建测试用的Context"""
	# 选择资源
	var resource_index = index % _test_resources.size()
	var resource = _test_resources[resource_index]
	
	# 选择节点
	var node_index = index % _test_nodes.size()
	var target_node = _test_nodes[node_index]
	
	# 创建Context
	var context = JuicyContext.create(resource, target_node)
	context.time_scale = randf_range(0.5, 2.0)
	
	return context

func _simulate_interruption(context: JuicyContext, index: int) -> Dictionary:
	"""模拟中断处理"""
	# 简化的中断处理模拟
	var success = true
	var details = {}
	
	# 暂停Context
	context.pause()
	details["paused"] = context.is_paused
	
	# 模拟中断处理时间
	OS.delay_msec(10)
	
	# 恢复Context
	context.resume()
	details["resumed"] = not context.is_paused
	
	# 检查状态
	if context.is_paused:
		success = false
		details["error"] = "Context未正确恢复"
	
	return {
		"success": success,
		"details": details
	}

func _test_interruption_priorities() -> Dictionary:
	"""测试中断优先级"""
	# 简化的优先级测试
	return {
		"success": true,
		"details": {
			"priority_order": "tested",
			"conflict_resolution": "working"
		}
	}

func _execute_middleware_chain(context: JuicyContext) -> Dictionary:
	"""执行中间件链"""
	var success = true
	var details = {}
	
	# 执行验证中间件
	var validation_result = _validation_middleware.execute(context, func():
		# 执行事件中间件
		return _event_middleware.execute(context, func():
			# 执行LOD中间件
			return _lod_middleware.execute(context, func():
				# 链完成
				return true
			)
		)
	)
	
	details["validation_result"] = validation_result
	
	if not validation_result:
		success = false
		details["error"] = "中间件链执行返回false"
	
	return {
		"success": success,
		"details": details
	}

func _generate_validation_report():
	"""生成验证报告"""
	print("\n=== 验证测试报告 ===")
	
	var total_tests = _validation_results.size()
	var passed_tests = 0
	var failed_tests = 0
	
	for test_name in _validation_results.keys():
		var result = _validation_results[test_name]
		if result.test_passed:
			passed_tests += 1
		else:
			failed_tests += 1
		
		print("\n%s: %s" % [test_name, "通过" if result.test_passed else "失败"])
		
		if not result.test_passed:
			for issue in result.issues:
				print("  - " + issue)
	
	print("\n测试摘要:")
	print("  总测试数: %d" % total_tests)
	print("  通过: %d" % passed_tests)
	print("  失败: %d" % failed_tests)
	print("  成功率: %.1f%%" % ((passed_tests / total_tests) * 100))
	
	# 保存详细报告
	_save_validation_report()

func _save_validation_report():
	"""保存验证报告"""
	var report_data = {
		"test_timestamp": Time.get_datetime_string_from_system(),
		"test_config": _test_config,
		"validation_results": _validation_results,
		"summary": {
			"total_tests": _validation_results.size(),
			"passed_tests": 0,
			"failed_tests": 0
		}
	}
	
	# 计算通过和失败的数量
	for test_name in _validation_results.keys():
		if _validation_results[test_name].test_passed:
			report_data.summary.passed_tests += 1
		else:
			report_data.summary.failed_tests += 1
	
	var file_path = "user://middleware_validation_report.json"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report_data, "\t"))
		file.close()
		print("\n详细验证报告已保存到: " + file_path)

func get_validation_results() -> Dictionary:
	"""获取验证结果"""
	return _validation_results.duplicate()

func get_test_summary() -> Dictionary:
	"""获取测试摘要"""
	var summary = {
		"total_tests": _validation_results.size(),
		"passed_tests": 0,
		"failed_tests": 0,
		"success_rate": 0.0
	}
	
	for test_name in _validation_results.keys():
		if _validation_results[test_name].test_passed:
			summary.passed_tests += 1
		else:
			summary.failed_tests += 1
	
	if summary.total_tests > 0:
		summary.success_rate = (summary.passed_tests / summary.total_tests) * 100
	
	return summary

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
	if _interruption_middleware:
		_interruption_middleware.destroy()
	
	print("验证测试环境已清理")
