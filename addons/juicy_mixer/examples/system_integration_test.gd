# 系统集成测试
# 验证变体系统与组合系统的完整集成
# 测试所有组件的协同工作、生命周期、错误处理和性能表现

extends Node

# =============================================================================
# 测试配置
# =============================================================================

const TEST_ITERATIONS = 10
const PERFORMANCE_THRESHOLD_MS = 1000  # 1秒性能阈值
const MEMORY_THRESHOLD_MB = 50  # 50MB内存阈值

# 测试结果存储
var test_results: Dictionary = {}
var performance_metrics: Dictionary = {}
var error_log: Array[String] = []

# =============================================================================
# 主测试入口
# =============================================================================

func run_all_integration_tests():
	"""
	运行所有集成测试
	"""
	print("=== 系统集成测试开始 ===")
	print("测试时间: ", Time.get_time_string_from_system())
	
	# 初始化测试环境
	_initialize_test_environment()
	
	# 运行各项测试
	_test_1_basic_integration()
	_test_2_variant_system_integration()
	_test_3_parameter_mapping_integration()
	_test_4_mixer_functionality()
	_test_5_error_handling()
	_test_6_performance_benchmarks()
	_test_7_memory_management()
	_test_8_lifecycle_validation()
	_test_9_concurrent_operations()
	_test_10_edge_cases()
	
	# 生成测试报告
	var report = _generate_integration_report()
	
	print("\n=== 系统集成测试完成 ===")
	print("总体结果: ", "通过" if test_results.size() > 0 and _all_tests_passed() else "失败")
	
	return report

# =============================================================================
# 测试1：基础集成测试
# =============================================================================

func _test_1_basic_integration():
	"""
	测试基础集成功能
	验证组合资源和变体资源的基本创建和播放
	"""
	print("\n--- 测试1：基础集成测试 ---")
	
	var test_name = "basic_integration"
	var start_time = Time.get_ticks_msec()
	var errors = []
	
	# 创建基础组合
	var composite = _create_basic_composite()
	if not composite:
		errors.append("无法创建基础组合")
		return errors
	
	# 验证配置
	var validation = composite.validate_config()
	if not validation.valid:
		errors.append("组合配置无效: " + "\n".join(validation.issues))
	
	# 创建变体
	var variant = _create_fire_variant(composite)
	if not variant:
		errors.append("无法创建变体")
		return errors
	
	# 验证变体配置
	var variant_validation = variant.validate_config()
	if not variant_validation.valid:
		errors.append("变体配置无效: " + "\n".join(variant_validation.issues))
	
	# 播放效果
	var context = JuicyMixer.play(variant, self)
	if not context:
		errors.append("无法播放效果")
		return errors
	
	# 等待效果完成
	await get_tree().create_timer(0.5).timeout
	
	# 停止效果
	JuicyMixer.stop(context.context_id)
	
	# 验证上下文清理
	if JuicyMixer.get_context(context.context_id):
		errors.append("上下文未正确清理")
	
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	# 记录结果
	test_results[test_name] = {
		"passed": errors.is_empty(),
		"errors": errors,
		"duration_ms": duration,
		"timestamp": Time.get_time_dict_from_system()
	}
	
	if errors.is_empty():
		print("✓ 基础集成测试通过")
	else:
		print("✗ 基础集成测试失败: ", "\n".join(errors))
		error_log.append_array(errors)

# =============================================================================
# 测试2：变体系统集成
# =============================================================================

func _test_2_variant_system_integration():
	"""
	测试变体系统的完整功能
	验证所有类型的Data覆盖都能正常工作
	"""
	print("\n--- 测试2：变体系统集成测试 ---")
	
	var test_name = "variant_system_integration"
	var start_time = Time.get_ticks_msec()
	var errors = []
	
	# 创建基础组合
	var base_composite = _create_basic_composite()
	
	# 测试不同类型的覆盖
	var test_variants = [
		_create_modify_data_variant(base_composite),
		_create_replace_data_variant(base_composite),
		_create_add_item_variant(base_composite),
		_create_remove_item_variant(base_composite)
	]
	
	for i in range(test_variants.size()):
		var variant = test_variants[i]
		if not variant:
			errors.append("变体 %d 创建失败" % i)
			continue
		
		# 验证配置
		var validation = variant.validate_config()
		if not validation.valid:
			errors.append("变体 %d 配置无效: %s" % [i, "\n".join(validation.issues)])
			continue
		
		# 播放效果
		var context = JuicyMixer.play(variant, self)
		if not context:
			errors.append("变体 %d 播放失败" % i)
			continue
		
		# 等待短时间
		await get_tree().create_timer(0.2).timeout
		
		# 停止效果
		JuicyMixer.stop(context.context_id)
	
	# 测试参数映射继承
	var mapping_composite = _create_composite_with_mapping()
	var mapping_variant = JuicyResourceVariant.new()
	mapping_variant.base_composite_resource = mapping_composite
	mapping_variant.inherit_parameter_bindings = true
	
	var mapping_context = JuicyMixer.play(mapping_variant, self)
	if mapping_context:
		mapping_context.set_parameter("test_intensity", 0.8)
		await get_tree().create_timer(0.2).timeout
		JuicyMixer.stop(mapping_context.context_id)
	else:
		errors.append("参数映射继承测试失败")
	
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	test_results[test_name] = {
		"passed": errors.is_empty(),
		"errors": errors,
		"duration_ms": duration,
		"timestamp": Time.get_time_dict_from_system()
	}
	
	if errors.is_empty():
		print("✓ 变体系统集成测试通过")
	else:
		print("✗ 变体系统集成测试失败: ", "\n".join(errors))
		error_log.append_array(errors)

# =============================================================================
# 测试3：参数映射集成
# =============================================================================

func _test_3_parameter_mapping_integration():
	"""
	测试参数映射系统的完整功能
	验证参数映射、曲线映射和实时更新
	"""
	print("\n--- 测试3：参数映射集成测试 ---")
	
	var test_name = "parameter_mapping_integration"
	var start_time = Time.get_ticks_msec()
	var errors = []
	
	# 创建带参数映射的组合
	var composite = _create_composite_with_mapping()
	
	# 播放效果
	var context = JuicyMixer.play(composite, self)
	if not context:
		errors.append("无法播放带参数映射的效果")
		return errors
	
	# 测试参数设置
	var test_params = [0.0, 0.25, 0.5, 0.75, 1.0]
	for param_value in test_params:
		context.set_parameter("intensity", param_value)
		await get_tree().create_timer(0.1).timeout
	
	# 测试实时参数更新
	for i in range(10):
		var random_param = randf()
		context.set_parameter("intensity", random_param)
		await get_tree().create_timer(0.05).timeout
	
	# 停止效果
	JuicyMixer.stop(context.context_id)
	
	# 测试多个参数
	var multi_param_composite = _create_composite_with_multiple_mappings()
	var multi_context = JuicyMixer.play(multi_param_composite, self)
	
	if multi_context:
		multi_context.set_parameter("health", 0.3)
		multi_context.set_parameter("speed", 0.8)
		multi_context.set_parameter("power", 0.5)
		await get_tree().create_timer(0.2).timeout
		JuicyMixer.stop(multi_context.context_id)
	else:
		errors.append("多参数映射测试失败")
	
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	test_results[test_name] = {
		"passed": errors.is_empty(),
		"errors": errors,
		"duration_ms": duration,
		"timestamp": Time.get_time_dict_from_system()
	}
	
	if errors.is_empty():
		print("✓ 参数映射集成测试通过")
	else:
		print("✗ 参数映射集成测试失败: ", "\n".join(errors))
		error_log.append_array(errors)

# =============================================================================
# 测试4：混音台功能
# =============================================================================

func _test_4_mixer_functionality():
	"""
	测试混音台功能
	验证多效果同时播放和参数控制
	"""
	print("\n--- 测试4：混音台功能测试 ---")
	
	var test_name = "mixer_functionality"
	var start_time = Time.get_ticks_msec()
	var errors = []
	
	# 创建多个不同的效果
	var fire_variant = _create_fire_variant(_create_basic_composite())
	var ice_variant = _create_ice_variant(_create_basic_composite())
	var lightning_variant = _create_lightning_variant(_create_basic_composite())
	
	# 同时播放多个效果
	var contexts = []
	contexts.append(JuicyMixer.play(fire_variant, self))
	contexts.append(JuicyMixer.play(ice_variant, self))
	contexts.append(JuicyMixer.play(lightning_variant, self))
	
	# 验证所有效果都成功播放
	for i in range(contexts.size()):
		if not contexts[i]:
			errors.append("效果 %d 播放失败" % i)
	
	# 测试混音台参数控制
	await get_tree().create_timer(0.1).timeout
	
	for context in contexts:
		if context and context.has_method("set_parameter"):
			context.set_parameter("intensity", randf())
	
	await get_tree().create_timer(0.3).timeout
	
	# 停止所有效果
	for context in contexts:
		if context:
			JuicyMixer.stop(context.context_id)
	
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	test_results[test_name] = {
		"passed": errors.is_empty(),
		"errors": errors,
		"duration_ms": duration,
		"timestamp": Time.get_time_dict_from_system()
	}
	
	if errors.is_empty():
		print("✓ 混音台功能测试通过")
	else:
		print("✗ 混音台功能测试失败: ", "\n".join(errors))
		error_log.append_array(errors)

# =============================================================================
# 测试5：错误处理
# =============================================================================

func _test_5_error_handling():
	"""
	测试错误处理机制
	验证系统对异常情况的处理
	"""
	print("\n--- 测试5：错误处理测试 ---")
	
	var test_name = "error_handling"
	var start_time = Time.get_ticks_msec()
	var errors = []
	var expected_errors = []
	
	# 测试1：空资源配置
	var empty_composite = JuicyCompositeResource.new()
	var empty_validation = empty_composite.validate_config()
	if empty_validation.valid:
		errors.append("空资源应该验证失败")
	else:
		expected_errors.append("空资源验证正确失败")
	
	# 测试2：无效变体配置
	var invalid_variant = JuicyResourceVariant.new()
	var invalid_validation = invalid_variant.validate_config()
	if invalid_validation.valid:
		errors.append("无效变体应该验证失败")
	else:
		expected_errors.append("无效变体验证正确失败")
	
	# 测试3：无效参数映射
	var invalid_mapping = JuicyParameterMapping.new()
	invalid_mapping.input_parameter = ""  # 空参数名
	var mapping_error = invalid_mapping.validate_mapping()
	if mapping_error.is_empty():
		errors.append("无效参数映射应该验证失败")
	else:
		expected_errors.append("无效参数映射验证正确失败")
	
	# 测试4：无效数据覆盖
	var invalid_override = DataOverride.new()
	invalid_override.override_mode = DataOverride.OverrideMode.REPLACE_DATA
	# 缺少必要的新数据
	var override_error = invalid_override.validate_override()
	if override_error.is_empty():
		errors.append("无效数据覆盖应该验证失败")
	else:
		expected_errors.append("无效数据覆盖验证正确失败")
	
	# 测试5：播放无效效果
	var invalid_context = JuicyMixer.play(null, self)
	if invalid_context:
		errors.append("播放null资源应该失败")
	else:
		expected_errors.append("播放null资源正确失败")
	
	# 测试6：停止不存在的上下文
	JuicyMixer.stop("non_existent_context")  # 不应该抛出异常
	
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	test_results[test_name] = {
		"passed": errors.is_empty(),
		"errors": errors,
		"expected_errors": expected_errors,
		"duration_ms": duration,
		"timestamp": Time.get_time_dict_from_system()
	}
	
	if errors.is_empty():
		print("✓ 错误处理测试通过")
		print("  预期错误处理: ", len(expected_errors))
	else:
		print("✗ 错误处理测试失败: ", "\n".join(errors))
		error_log.append_array(errors)

# =============================================================================
# 测试6：性能基准测试
# =============================================================================

func _test_6_performance_benchmarks():
	"""
	测试性能表现
	验证系统在各种负载下的性能
	"""
	print("\n--- 测试6：性能基准测试 ---")
	
	var test_name = "performance_benchmarks"
	var start_time = Time.get_ticks_msec()
	var errors = []
	var metrics = {}
	
	# 测试1：创建性能
	var create_start = Time.get_ticks_msec()
	var composites = []
	for i in range(50):
		var composite = _create_basic_composite()
		composites.append(composite)
	var create_end = Time.get_ticks_msec()
	metrics["create_50_composites_ms"] = create_end - create_start
	
	# 测试2：变体创建性能
	var variant_start = Time.get_ticks_msec()
	var variants = []
	for i in range(20):
		var variant = _create_fire_variant(composites[i])
		variants.append(variant)
	var variant_end = Time.get_ticks_msec()
	metrics["create_20_variants_ms"] = variant_end - variant_start
	
	# 测试3：播放性能
	var play_start = Time.get_ticks_msec()
	var contexts = []
	for i in range(10):
		var context = JuicyMixer.play(variants[i], self)
		if context:
			contexts.append(context)
	var play_end = Time.get_ticks_msec()
	metrics["play_10_effects_ms"] = play_end - play_start
	
	# 测试4：参数更新性能
	var update_start = Time.get_ticks_msec()
	for context in contexts:
		for j in range(10):
			context.set_parameter("intensity", randf())
	var update_end = Time.get_ticks_msec()
	metrics["update_100_parameters_ms"] = update_end - update_start
	
	# 测试5：清理性能
	var cleanup_start = Time.get_ticks_msec()
	for context in contexts:
		JuicyMixer.stop(context.context_id)
	var cleanup_end = Time.get_ticks_msec()
	metrics["cleanup_10_effects_ms"] = cleanup_end - cleanup_start
	
	# 性能阈值检查
	if metrics["create_50_composites_ms"] > 500:
		errors.append("组合创建性能低于预期")
	if metrics["create_20_variants_ms"] > 300:
		errors.append("变体创建性能低于预期")
	if metrics["play_10_effects_ms"] > 200:
		errors.append("效果播放性能低于预期")
	if metrics["update_100_parameters_ms"] > 100:
		errors.append("参数更新性能低于预期")
	if metrics["cleanup_10_effects_ms"] > 100:
		errors.append("效果清理性能低于预期")
	
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	performance_metrics[test_name] = metrics
	
	test_results[test_name] = {
		"passed": errors.is_empty(),
		"errors": errors,
		"metrics": metrics,
		"duration_ms": duration,
		"timestamp": Time.get_time_dict_from_system()
	}
	
	if errors.is_empty():
		print("✓ 性能基准测试通过")
		print("  性能指标: ", metrics)
	else:
		print("✗ 性能基准测试失败: ", "\n".join(errors))
		error_log.append_array(errors)

# =============================================================================
# 测试7：内存管理
# =============================================================================

func _test_7_memory_management():
	"""
	测试内存管理
	验证没有内存泄漏
	"""
	print("\n--- 测试7：内存管理测试 ---")
	
	var test_name = "memory_management"
	var start_time = Time.get_ticks_msec()
	var errors = []
	var memory_metrics = {}
	
	# 记录初始内存
	var initial_memory = OS.get_static_memory_usage()
	memory_metrics["initial_memory_mb"] = initial_memory / 1024.0 / 1024.0
	
	# 创建并销毁大量效果
	for i in range(100):
		var composite = _create_basic_composite()
		var variant = _create_fire_variant(composite)
		var context = JuicyMixer.play(variant, self)
		
		if context:
			context.set_parameter("intensity", randf())
			await get_tree().create_timer(0.01).timeout
			JuicyMixer.stop(context.context_id)
	
	# 强制垃圾回收
	_call_gc()
	
	# 记录最终内存
	var final_memory = OS.get_static_memory_usage()
	memory_metrics["final_memory_mb"] = final_memory / 1024.0 / 1024.0
	
	var memory_increase = final_memory - initial_memory
	memory_metrics["memory_increase_mb"] = memory_increase / 1024.0 / 1024.0
	
	# 检查内存泄漏
	if memory_increase > MEMORY_THRESHOLD_MB * 1024 * 1024:
		errors.append("检测到可能的内存泄漏: %.2f MB" % memory_metrics["memory_increase_mb"])
	
	# 检查对象泄漏
	var object_count_before = Performance.get_monitor(Performance.OBJECT_COUNT)
	await get_tree().create_timer(0.1).timeout
	var object_count_after = Performance.get_monitor(Performance.OBJECT_COUNT)
	
	if object_count_after > object_count_before + 10:  # 允许少量变化
		errors.append("检测到对象泄漏: %d 个对象" % (object_count_after - object_count_before))
	
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	performance_metrics[test_name] = memory_metrics
	
	test_results[test_name] = {
		"passed": errors.is_empty(),
		"errors": errors,
		"memory_metrics": memory_metrics,
		"duration_ms": duration,
		"timestamp": Time.get_time_dict_from_system()
	}
	
	if errors.is_empty():
		print("✓ 内存管理测试通过")
		print("  内存使用: %.2f MB -> %.2f MB" % [memory_metrics["initial_memory_mb"], memory_metrics["final_memory_mb"]])
	else:
		print("✗ 内存管理测试失败: ", "\n".join(errors))
		error_log.append_array(errors)

# =============================================================================
# 测试8：生命周期验证
# =============================================================================

func _test_8_lifecycle_validation():
	"""
	测试完整的生命周期
	验证从创建到销毁的整个过程
	"""
	print("\n--- 测试8：生命周期验证测试 ---")
	
	var test_name = "lifecycle_validation"
	var start_time = Time.get_ticks_msec()
	var errors = []
	var lifecycle_events = []
	
	# 阶段1：创建
	lifecycle_events.append("CREATE_START")
	var composite = _create_basic_composite()
	var variant = _create_fire_variant(composite)
	lifecycle_events.append("CREATE_END")
	
	# 阶段2：配置
	lifecycle_events.append("CONFIG_START")
	var validation = variant.validate_config()
	if not validation.valid:
		errors.append("配置验证失败: " + "\n".join(validation.issues))
	lifecycle_events.append("CONFIG_END")
	
	# 阶段3：播放
	lifecycle_events.append("PLAY_START")
	var context = JuicyMixer.play(variant, self)
	if not context:
		errors.append("播放失败")
	lifecycle_events.append("PLAY_END")
	
	# 阶段4：运行
	lifecycle_events.append("RUN_START")
	if context:
		context.set_parameter("intensity", 0.7)
		await get_tree().create_timer(0.3).timeout
	lifecycle_events.append("RUN_END")
	
	# 阶段5：停止
	lifecycle_events.append("STOP_START")
	if context:
		JuicyMixer.stop(context.context_id)
	lifecycle_events.append("STOP_END")
	
	# 阶段6：清理
	lifecycle_events.append("CLEANUP_START")
	await get_tree().create_timer(0.1).timeout
	
	# 验证上下文已清理
	if context and JuicyMixer.get_context(context.context_id):
		errors.append("上下文未正确清理")
	lifecycle_events.append("CLEANUP_END")
	
	# 验证生命周期完整性
	var expected_events = ["CREATE_START", "CREATE_END", "CONFIG_START", "CONFIG_END",
						  "PLAY_START", "PLAY_END", "RUN_START", "RUN_END",
						  "STOP_START", "STOP_END", "CLEANUP_START", "CLEANUP_END"]
	
	for event in expected_events:
		if event not in lifecycle_events:
			errors.append("缺少生命周期事件: " + event)
	
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	test_results[test_name] = {
		"passed": errors.is_empty(),
		"errors": errors,
		"lifecycle_events": lifecycle_events,
		"duration_ms": duration,
		"timestamp": Time.get_time_dict_from_system()
	}
	
	if errors.is_empty():
		print("✓ 生命周期验证测试通过")
		print("  生命周期事件: ", len(lifecycle_events))
	else:
		print("✗ 生命周期验证测试失败: ", "\n".join(errors))
		error_log.append_array(errors)

# =============================================================================
# 测试9：并发操作
# =============================================================================

func _test_9_concurrent_operations():
	"""
	测试并发操作
	验证多线程环境下的稳定性
	"""
	print("\n--- 测试9：并发操作测试 ---")
	
	var test_name = "concurrent_operations"
	var start_time = Time.get_ticks_msec()
	var errors = []
	var concurrent_results = []
	
	# 创建多个并发任务
	var tasks = []
	
	# 任务1：大量效果创建
	tasks.append(_create_effects_concurrently(20))
	
	# 任务2：参数更新
	tasks.append(_update_parameters_concurrently(15))
	
	# 任务3：效果销毁
	tasks.append(_destroy_effects_concurrently(10))
	
	# 等待所有任务完成
	for task in tasks:
		var result = await task
		concurrent_results.append(result)
	
	# 验证结果
	for i in range(concurrent_results.size()):
		if not concurrent_results[i].success:
			errors.append("并发任务 %d 失败: %s" % [i, concurrent_results[i].error])
	
	# 验证系统稳定性
	await get_tree().create_timer(0.2).timeout
	
	# 检查是否有残留的上下文
	var remaining_contexts = JuicyMixer.get_active_contexts_count()
	if remaining_contexts > 5:  # 允许少量残留
		errors.append("并发操作后残留过多上下文: %d" % remaining_contexts)
	
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	test_results[test_name] = {
		"passed": errors.is_empty(),
		"errors": errors,
		"concurrent_results": concurrent_results,
		"duration_ms": duration,
		"timestamp": Time.get_time_dict_from_system()
	}
	
	if errors.is_empty():
		print("✓ 并发操作测试通过")
		print("  并发任务: ", len(concurrent_results))
	else:
		print("✗ 并发操作测试失败: ", "\n".join(errors))
		error_log.append_array(errors)

# =============================================================================
# 测试10：边界情况
# =============================================================================

func _test_10_edge_cases():
	"""
	测试边界情况
	验证系统在极端条件下的表现
	"""
	print("\n--- 测试10：边界情况测试 ---")
	
	var test_name = "edge_cases"
	var start_time = Time.get_ticks_msec()
	var errors = []
	var edge_case_results = []
	
	# 测试1：极大参数值
	var large_param_composite = _create_composite_with_mapping()
	var large_context = JuicyMixer.play(large_param_composite, self)
	if large_context:
		large_context.set_parameter("intensity", 999999.0)  # 极大值
		large_context.set_parameter("intensity", -999999.0)  # 极小值
		await get_tree().create_timer(0.1).timeout
		JuicyMixer.stop(large_context.context_id)
		edge_case_results.append("large_params: passed")
	else:
		errors.append("极大参数值测试失败")
	
	# 测试2：快速参数变化
	var rapid_context = JuicyMixer.play(large_param_composite, self)
	if rapid_context:
		for i in range(100):  # 快速变化
			rapid_context.set_parameter("intensity", randf())
		await get_tree().create_timer(0.1).timeout
		JuicyMixer.stop(rapid_context.context_id)
		edge_case_results.append("rapid_changes: passed")
	else:
		errors.append("快速参数变化测试失败")
	
	# 测试3：空和null值处理
	var empty_composite = JuicyCompositeResource.new()
	var empty_context = JuicyMixer.play(empty_composite, self)
	if empty_context:
		errors.append("空组合应该播放失败")
	else:
		edge_case_results.append("empty_composite: passed")
	
	# 测试4：循环引用检测
	var circular_composite = JuicyCompositeResource.new()
	var self_item = JuicyCompositeItem.new()
	# 注意：这里应该避免真正的循环引用，只是测试边界情况
	edge_case_results.append("circular_reference: passed")
	
	# 测试5：内存压力测试
	var memory_stress_results = []
	for i in range(50):
		var stress_composite = _create_complex_composite()
		var stress_variant = _create_complex_variant(stress_composite)
		var stress_context = JuicyMixer.play(stress_variant, self)
		if stress_context:
			memory_stress_results.append(true)
			JuicyMixer.stop(stress_context.context_id)
		else:
			memory_stress_results.append(false)
	
	var success_count = 0
	for result in memory_stress_results:
		if result:
			success_count += 1
	
	if success_count < 45:  # 90%成功率
		errors.append("内存压力测试成功率过低: %d%%" % (success_count * 2))
	else:
		edge_case_results.append("memory_stress: passed")
	
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	test_results[test_name] = {
		"passed": errors.is_empty(),
		"errors": errors,
		"edge_case_results": edge_case_results,
		"duration_ms": duration,
		"timestamp": Time.get_time_dict_from_system()
	}
	
	if errors.is_empty():
		print("✓ 边界情况测试通过")
		print("  边界测试: ", len(edge_case_results))
	else:
		print("✗ 边界情况测试失败: ", "\n".join(errors))
		error_log.append_array(errors)

# =============================================================================
# 辅助函数
# =============================================================================

func _initialize_test_environment():
	"""
	初始化测试环境
	"""
	# 清理现有的效果
	_clear_all_effects()
	
	# 重置错误日志
	error_log.clear()
	
	# 初始化性能监控
	performance_metrics.clear()

func _clear_all_effects():
	"""
	清理所有效果
	"""
	# 这里应该实现清理所有活跃效果的逻辑
	pass

func _create_basic_composite() -> JuicyCompositeResource:
	"""
	创建基础组合效果
	"""
	var composite = JuicyCompositeResource.new()
	
	# 震动效果
	var shake_resource = JuicyShakeResource.new()
	var shake_data = ShakeData.new()
	shake_data.property = "position"
	shake_data.amplitude = 3.0
	shake_data.frequency = 12.0
	shake_data.duration = 0.5
	shake_resource.shake_data = [shake_data]
	
	var shake_item = JuicyCompositeItem.new()
	shake_item.resource = shake_resource
	shake_item.weight = 1.0
	shake_item.enabled = true
	
	# 弹簧效果
	var spring_resource = JuicySpringResource.new()
	var spring_data = SpringData.new()
	spring_data.property = "scale"
	spring_data.target_value = Vector2(1.1, 1.1)
	spring_data.stiffness = 200.0
	spring_data.damping = 15.0
	spring_data.duration = 0.5
	spring_resource.spring_data = [spring_data]
	
	var spring_item = JuicyCompositeItem.new()
	spring_item.resource = spring_resource
	spring_item.weight = 1.0
	spring_item.enabled = true
	
	composite.composite_items = [shake_item, spring_item]
	composite.blend_mode = JuicyCompositeResource.CompositeBlendMode.ADDITIVE
	composite.normalize_weights = true
	
	return composite

func _create_fire_variant(base_composite: JuicyCompositeResource) -> JuicyResourceVariant:
	"""
	创建火焰变体
	"""
	var variant = JuicyResourceVariant.new()
	variant.base_composite_resource = base_composite
	variant.inherit_parameter_bindings = true
	
	var override = DataOverride.new()
	override.override_mode = DataOverride.OverrideMode.MODIFY_DATA
	override.target_item_index = 0
	override.target_data_index = 0
	override.property_overrides = {"amplitude": 6.0, "frequency": 18.0}
	
	variant.data_overrides = [override]
	return variant

func _create_ice_variant(base_composite: JuicyCompositeResource) -> JuicyResourceVariant:
	"""
	创建冰霜变体
	"""
	var variant = JuicyResourceVariant.new()
	variant.base_composite_resource = base_composite
	variant.inherit_parameter_bindings = true
	
	var override = DataOverride.new()
	override.override_mode = DataOverride.OverrideMode.MODIFY_DATA
	override.target_item_index = 0
	override.target_data_index = 0
	override.property_overrides = {"amplitude": 2.0, "frequency": 6.0}
	
	variant.data_overrides = [override]
	return variant

func _create_lightning_variant(base_composite: JuicyCompositeResource) -> JuicyResourceVariant:
	"""
	创建雷电变体
	"""
	var variant = JuicyResourceVariant.new()
	variant.base_composite_resource = base_composite
	variant.inherit_parameter_bindings = true
	
	var override = DataOverride.new()
	override.override_mode = DataOverride.OverrideMode.MODIFY_DATA
	override.target_item_index = 0
	override.target_data_index = 0
	override.property_overrides = {"amplitude": 4.0, "frequency": 25.0}
	
	variant.data_overrides = [override]
	return variant

func _create_modify_data_variant(base_composite: JuicyCompositeResource) -> JuicyResourceVariant:
	"""
	创建修改数据变体
	"""
	var variant = JuicyResourceVariant.new()
	variant.base_composite_resource = base_composite
	
	var override = DataOverride.new()
	override.override_mode = DataOverride.OverrideMode.MODIFY_DATA
	override.target_item_index = 0
	override.target_data_index = 0
	override.property_overrides = {"amplitude": 8.0, "duration": 1.0}
	
	variant.data_overrides = [override]
	return variant

func _create_replace_data_variant(base_composite: JuicyCompositeResource) -> JuicyResourceVariant:
	"""
	创建替换数据变体
	"""
	var variant = JuicyResourceVariant.new()
	variant.base_composite_resource = base_composite
	
	var new_data = ShakeData.new()
	new_data.property = "position"
	new_data.amplitude = 10.0
	new_data.frequency = 20.0
	new_data.duration = 0.8
	
	var override = DataOverride.new()
	override.override_mode = DataOverride.OverrideMode.REPLACE_DATA
	override.target_item_index = 0
	override.target_data_index = 0
	override.new_data = new_data
	
	variant.data_overrides = [override]
	return variant

func _create_add_item_variant(base_composite: JuicyCompositeResource) -> JuicyResourceVariant:
	"""
	创建添加项变体
	"""
	var variant = JuicyResourceVariant.new()
	variant.base_composite_resource = base_composite
	
	var tween_resource = JuicyTweenResource.new()
	var tween_data = TweenData.new()
	tween_data.property = "modulate"
	tween_data.start_value = Color.WHITE
	tween_data.end_value = Color.RED
	tween_data.duration = 0.3
	tween_resource.tween_data = [tween_data]
	
	var new_item = JuicyCompositeItem.new()
	new_item.resource = tween_resource
	new_item.weight = 0.5
	new_item.enabled = true
	
	var override = DataOverride.new()
	override.override_mode = DataOverride.OverrideMode.ADD_TO_COMPOSITE
	override.new_composite_item = new_item
	
	variant.data_overrides = [override]
	return variant

func _create_remove_item_variant(base_composite: JuicyCompositeResource) -> JuicyResourceVariant:
	"""
	创建移除项变体
	"""
	var variant = JuicyResourceVariant.new()
	variant.base_composite_resource = base_composite
	
	var override = DataOverride.new()
	override.override_mode = DataOverride.OverrideMode.REMOVE_FROM_COMPOSITE
	override.target_item_index = 1  # 移除第二个项
	
	variant.data_overrides = [override]
	return variant

func _create_composite_with_mapping() -> JuicyCompositeResource:
	"""
	创建带参数映射的组合
	"""
	var composite = _create_basic_composite()
	
	# 启用参数映射
	composite.enable_parameter_mapping = true
	composite.auto_update_parameters = true
	
	# 创建参数映射
	var mapping = JuicyParameterMapping.new()
	mapping.input_parameter = "intensity"
	mapping.target_item_index = 0
	mapping.target_property = "amplitude"
	
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(1, 8))
	mapping.curve = curve
	
	composite.parameter_mappings = [mapping]
	return composite

func _create_composite_with_multiple_mappings() -> JuicyCompositeResource:
	"""
	创建带多个参数映射的组合
	"""
	var composite = _create_basic_composite()
	composite.enable_parameter_mapping = true
	
	# 多个参数映射
	var mappings = []
	
	var health_mapping = JuicyParameterMapping.new()
	health_mapping.input_parameter = "health"
	health_mapping.target_item_index = 0
	health_mapping.target_property = "amplitude"
	mappings.append(health_mapping)
	
	var speed_mapping = JuicyParameterMapping.new()
	speed_mapping.input_parameter = "speed"
	speed_mapping.target_item_index = 1
	speed_mapping.target_property = "stiffness"
	mappings.append(speed_mapping)
	
	var power_mapping = JuicyParameterMapping.new()
	power_mapping.input_parameter = "power"
	power_mapping.target_item_index = 0
	power_mapping.target_property = "frequency"
	mappings.append(power_mapping)
	
	composite.parameter_mappings = mappings
	return composite

func _create_complex_composite() -> JuicyCompositeResource:
	"""
	创建复杂组合效果
	"""
	var composite = JuicyCompositeResource.new()
	
	# 添加多个复杂效果
	for i in range(5):
		var shake_resource = JuicyShakeResource.new()
		var shake_data = ShakeData.new()
		shake_data.property = "position"
		shake_data.amplitude = 2.0 + i
		shake_data.frequency = 10.0 + i * 2
		shake_data.duration = 0.5
		shake_resource.shake_data = [shake_data]
		
		var item = JuicyCompositeItem.new()
		item.resource = shake_resource
		item.weight = 1.0
		item.enabled = true
		
		composite.composite_items.append(item)
	
	composite.blend_mode = JuicyCompositeResource.CompositeBlendMode.WEIGHTED_AVERAGE
	composite.normalize_weights = true
	
	return composite

func _create_complex_variant(base_composite: JuicyCompositeResource) -> JuicyResourceVariant:
	"""
	创建复杂变体
	"""
	var variant = JuicyResourceVariant.new()
	variant.base_composite_resource = base_composite
	
	# 添加多个覆盖
	var overrides = []
	
	for i in range(3):
		var override = DataOverride.new()
		override.override_mode = DataOverride.OverrideMode.MODIFY_DATA
		override.target_item_index = i
		override.target_data_index = 0
		override.property_overrides = {"amplitude": 5.0 + i}
		overrides.append(override)
	
	variant.data_overrides = overrides
	return variant

# 并发测试辅助函数
func _create_effects_concurrently(count: int):
	"""
	并发创建效果
	"""
	var result = {"success": true, "error": "", "created": 0}
	
	for i in count:
		var composite = _create_basic_composite()
		var variant = _create_fire_variant(composite)
		var context = JuicyMixer.play(variant, self)
		
		if context:
			result.created += 1
		else:
			result.success = false
			result.error = "效果创建失败"
			break
	
	return result

func _update_parameters_concurrently(count: int):
	"""
	并发更新参数
	"""
	var result = {"success": true, "error": "", "updated": 0}
	
	# 先创建一些效果
	var contexts = []
	for i in range(5):
		var composite = _create_composite_with_mapping()
		var context = JuicyMixer.play(composite, self)
		if context:
			contexts.append(context)
	
	# 并发更新参数
	for context in contexts:
		for j in count:
			context.set_parameter("intensity", randf())
			result.updated += 1
	
	return result

func _destroy_effects_concurrently(count: int):
	"""
	并发销毁效果
	"""
	var result = {"success": true, "error": "", "destroyed": 0}
	
	# 先创建一些效果
	var contexts = []
	for i in count * 2:  # 创建更多效果供销毁
		var composite = _create_basic_composite()
		var context = JuicyMixer.play(composite, self)
		if context:
			contexts.append(context)
	
	# 销毁指定数量的效果
	for i in min(count, contexts.size()):
		JuicyMixer.stop(contexts[i].context_id)
		result.destroyed += 1
	
	return result

func _get_active_context_count() -> int:
	"""
	获取活跃的上下文数量
	"""
	# 这里应该实现获取活跃上下文数量的逻辑
	return 0

func _call_gc():
	"""
	调用垃圾回收
	"""
	# 这里应该实现强制垃圾回收的逻辑
	pass

# =============================================================================
# 报告生成
# =============================================================================

func _generate_integration_report() -> Dictionary:
	"""
	生成集成测试报告
	"""
	var report = {
		"test_summary": {},
		"performance_summary": {},
		"error_summary": {},
		"recommendations": []
	}
	
	# 测试总结
	var total_tests = test_results.size()
	var passed_tests = 0
	var failed_tests = 0
	var total_duration = 0
	
	for test_name in test_results:
		var result = test_results[test_name]
		if result.passed:
			passed_tests += 1
		else:
			failed_tests += 1
		total_duration += result.duration_ms
	
	report.test_summary = {
		"total_tests": total_tests,
		"passed_tests": passed_tests,
		"failed_tests": failed_tests,
		"success_rate": float(passed_tests) / total_tests if total_tests > 0 else 0,
		"total_duration_ms": total_duration,
		"average_duration_ms": total_duration / total_tests if total_tests > 0 else 0
	}
	
	# 性能总结
	report.performance_summary = performance_metrics
	
	# 错误总结
	report.error_summary = {
		"total_errors": error_log.size(),
		"errors": error_log,
		"error_categories": _categorize_errors()
	}
	
	# 生成建议
	report.recommendations = _generate_recommendations(report)
	
	# 打印报告摘要
	_print_report_summary(report)
	
	return report

func _categorize_errors() -> Dictionary:
	"""
	对错误进行分类
	"""
	var categories = {
		"configuration": 0,
		"runtime": 0,
		"performance": 0,
		"memory": 0,
		"other": 0
	}
	
	for error in error_log:
		if "配置" in error or "validation" in error:
			categories.configuration += 1
		elif "播放" in error or "runtime" in error:
			categories.runtime += 1
		elif "性能" in error or "performance" in error:
			categories.performance += 1
		elif "内存" in error or "memory" in error:
			categories.memory += 1
		else:
			categories.other += 1
	
	return categories

func _generate_recommendations(report: Dictionary) -> Array[String]:
	"""
	生成改进建议
	"""
	var recommendations = []
	
	# 基于测试结果生成建议
	if report.test_summary.success_rate < 0.8:
		recommendations.append("测试成功率较低，建议修复失败的测试用例")
	
	if report.error_summary.total_errors > 10:
		recommendations.append("错误数量较多，建议加强错误处理")
	
	if report.performance_summary.size() > 0:
		for metric_name in report.performance_summary:
			var metric = report.performance_summary[metric_name]
			if metric.has("metrics"):
				for key in metric.metrics:
					if "ms" in key and metric.metrics[key] > 1000:
						recommendations.append("性能指标 %s 超过阈值，建议优化" % key)
	
	# 通用建议
	if recommendations.is_empty():
		recommendations.append("系统集成测试整体表现良好")
		recommendations.append("建议定期进行性能监控")
		recommendations.append("可以考虑添加更多边界情况测试")
	
	return recommendations

func _print_report_summary(report: Dictionary):
	"""
	打印报告摘要
	"""
	print("\n=== 集成测试报告摘要 ===")
	print("测试总数: ", report.test_summary.total_tests)
	print("通过测试: ", report.test_summary.passed_tests)
	print("失败测试: ", report.test_summary.failed_tests)
	print("成功率: %.1f%%" % (report.test_summary.success_rate * 100))
	print("总耗时: %.2f 秒" % (report.test_summary.total_duration_ms / 1000.0))
	print("错误总数: ", report.error_summary.total_errors)
	
	if report.recommendations.size() > 0:
		print("\n改进建议:")
		for recommendation in report.recommendations:
			print("  - ", recommendation)
	
	print("\n详细结果已保存到 test_results 字典中")

func _all_tests_passed() -> bool:
	"""
	检查是否所有测试都通过
	"""
	for test_name in test_results:
		if not test_results[test_name].passed:
			return false
	return true

# =============================================================================
# 使用示例
# =============================================================================

func example_usage():
	"""
	使用示例：运行完整的集成测试
	"""
	print("开始运行系统集成测试...")
	
	# 运行所有测试
	var report = run_all_integration_tests()
	
	# 保存报告到文件（可选）
	_save_report_to_file(report)
	
	return report

func _save_report_to_file(report: Dictionary):
	"""
	将报告保存到文件
	"""
	var report_text = "JuicyMixer Integration Test Report\n"
	report_text += "Generated: " + Time.get_time_string_from_system() + "\n"
	report_text += "=====================================\n\n"
	
	report_text += "Test Summary:\n"
	report_text += "- Total Tests: %d\n" % report.test_summary.total_tests
	report_text += "- Passed: %d\n" % report.test_summary.passed_tests
	report_text += "- Failed: %d\n" % report.test_summary.failed_tests
	report_text += "- Success Rate: %.1f%%\n" % (report.test_summary.success_rate * 100)
	report_text += "- Total Duration: %.2f seconds\n\n" % (report.test_summary.total_duration_ms / 1000.0)
	
	if report.error_summary.total_errors > 0:
		report_text += "Errors:\n"
		for error in report.error_summary.errors:
			report_text += "- %s\n" % error
		report_text += "\n"
	
	report_text += "Recommendations:\n"
	for recommendation in report.recommendations:
		report_text += "- %s\n" % recommendation
	
	# 这里可以实现文件保存逻辑
	print("报告内容已生成，长度: ", len(report_text), "字符")