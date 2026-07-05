# 综合性能测试 - 多Driver并行运行和大量属性处理
# =============================================================================

extends Node

var context: JuicyContext
var property_buffer: JuicyPropertyBuffer
var tween_driver: JuicyTweenDriver
var shake_driver: JuicyShakeDriver
var spring_driver: JuicySpringDriver

# 测试结果
var test_results = {}
var overall_passed = false

# 测试配置
const TEST_COUNT = 1000  # 大量测试数量
const SPRING_COUNT = 500  # 弹簧数量
const TWEEN_COUNT = 300  # 补间数量
const SHAKE_COUNT = 200  # 震动数量

# 性能目标
const TARGET_MULTI_DRIVER_TIME = 16.0  # 多Driver并行运行 < 16ms
const TARGET_LARGE_SCALE_TIME = 25.0   # 大量属性处理 < 25ms
const TARGET_MEMORY_USAGE = 50.0      # 内存使用 < 50MB

func _ready():
	# 初始化测试环境
	_setup_test_environment()
	
	# 运行所有性能测试
	_run_performance_tests()
	print("✅ 综合性能测试完成！")
	
	# 设置测试结果
	overall_passed = _calculate_overall_result()

func _setup_test_environment():
	# 初始化JuicyContext
	context = JuicyContext.new()
	context.target = Node2D.new()  # 创建一个简单的测试目标
	
	# 初始化属性缓冲区
	property_buffer = JuicyPropertyBuffer.new()
	
	# 初始化Driver实例
	tween_driver = JuicyTweenDriver.new()
	shake_driver = JuicyShakeDriver.new()
	spring_driver = JuicySpringDriver.new()

func get_test_results():
	return {
		"overall_passed": overall_passed,
		"test_results": test_results
	}

func _calculate_overall_result():
	var passed_count = 0
	var total_count = test_results.size()
	
	for test_name in test_results.keys():
		if test_results[test_name].passed:
			passed_count += 1
	
	if total_count == 0:
		return false
	
	return (passed_count / total_count) >= 0.8  # 80%通过率

func _run_performance_tests():
	print("=== 开始综合性能测试 ===")
	
	# 运行各个测试
	_test_multi_driver_parallel_performance()
	_test_mixed_driver_types_performance()
	_test_large_property_processing_performance()
	_test_property_buffer_large_scale()
	_test_comprehensive_scene_performance()
	_test_memory_usage_gc_pressure()
	
	# 生成总结报告
	_generate_performance_summary()

func _cleanup():
	# 清理测试环境
	if tween_driver:
		tween_driver.queue_free()
	if shake_driver:
		shake_driver.queue_free()
	if spring_driver:
		spring_driver.queue_free()
	if property_buffer:
		property_buffer.queue_free()
	if context:
		context.queue_free()

# =============================================================================
# 测试1: 多Driver并行运行性能测试
# =============================================================================

func _test_multi_driver_parallel_performance():
	print("=== 多Driver并行运行性能测试 ===")
	
	# 创建多个Driver实例
	var drivers = []
	var start_time = Time.get_ticks_msec()
	
	# 创建多个Driver实例
	for i in range(10):
		var driver = JuicySpringDriver.new()
		drivers.append(driver)
	
	var creation_time = Time.get_ticks_msec() - start_time
	
	# 测试并行运行性能
	start_time = Time.get_ticks_msec()
	
	# 同时运行多个Driver
	for driver in drivers:
		driver.process(context, 0.016, property_buffer)  # 模拟16ms帧时间
	
	var parallel_time = Time.get_ticks_msec() - start_time
	
	
	# 验证性能目标
	var passed = parallel_time < TARGET_MULTI_DRIVER_TIME
	print("✓ Driver创建时间: %dms" % creation_time)
	print("✓ 并行运行时间: %dms (目标: <%dms)" % [parallel_time, TARGET_MULTI_DRIVER_TIME])
	print("✓ 性能通过: %s" % ["是" if passed else "否"])
	
	# 记录测试结果
	test_results["multi_driver_parallel"] = {
		"passed": passed,
		"creation_time": creation_time,
		"parallel_time": parallel_time,
		"target": TARGET_MULTI_DRIVER_TIME
	}
	
	return passed

# =============================================================================
# 测试2: 混合Driver类型性能测试
# =============================================================================

func _test_mixed_driver_types_performance():
	print("=== 混合Driver类型性能测试 ===")
	
	var start_time = Time.get_ticks_msec()
	var drivers = []
	
	# 创建混合类型的Driver
	for i in range(20):
		if i % 3 == 0:
			var driver = JuicyTweenDriver.new()
			drivers.append(driver)
		elif i % 3 == 1:
			var driver = JuicyShakeDriver.new()
			drivers.append(driver)
		else:
			var driver = JuicySpringDriver.new()
			drivers.append(driver)
	
	# 测试混合类型并行运行
	start_time = Time.get_ticks_msec()
	for i in range(100):  # 运行100帧
		for driver in drivers:
			driver.process(context, 0.016, property_buffer)
	
	var mixed_time = Time.get_ticks_msec() - start_time
	
	
	# 计算平均每帧时间
	var avg_frame_time = mixed_time / 100.0
	var passed = avg_frame_time < 1.0
	
	print("✓ 混合类型Driver数量: %d" % drivers.size())
	print("✓ 总运行时间: %dms (100帧)" % mixed_time)
	print("✓ 平均每帧时间: %.3fms" % avg_frame_time)
	print("✓ 性能通过: %s" % ["是" if passed else "否"])
	
	# 记录测试结果
	test_results["mixed_driver_types"] = {
		"passed": passed,
		"avg_frame_time": avg_frame_time,
		"total_time": mixed_time,
		"target": 1.0
	}
	
	return passed

# =============================================================================
# 测试3: 大量属性同时处理性能测试
# =============================================================================

func _test_large_property_processing_performance():
	print("=== 大量属性处理性能测试 ===")
	
	var start_time = Time.get_ticks_msec()
	var property_count = 1000
	
	# 创建大量属性
	var properties = []
	for i in range(property_count):
		var prop = {
			"name": "property_%d" % i,
			"value": 0.0,
			"target": 100.0,
			"speed": 1.0 + (i % 10) * 0.1
		}
		properties.append(prop)
	
	var creation_time = Time.get_ticks_msec() - start_time
	
	# 测试属性更新性能
	start_time = Time.get_ticks_msec()
	for frame in range(60):  # 模拟60帧
		for prop in properties:
			prop.value += (prop.target - prop.value) * prop.speed * 0.016
	
	var processing_time = Time.get_ticks_msec() - start_time
	
	# 计算性能指标
	var avg_frame_time = processing_time / 60.0
	var passed = avg_frame_time < TARGET_LARGE_SCALE_TIME / 60.0
	
	print("✓ 属性数量: %d" % property_count)
	print("✓ 属性创建时间: %dms" % creation_time)
	print("✓ 60帧处理时间: %dms" % processing_time)
	print("✓ 平均每帧时间: %.3fms" % avg_frame_time)
	print("✓ 性能通过: %s" % ["是" if passed else "否"])
	
	# 记录测试结果
	test_results["large_property_processing"] = {
		"passed": passed,
		"avg_frame_time": avg_frame_time,
		"processing_time": processing_time,
		"target": TARGET_LARGE_SCALE_TIME / 60.0
	}
	
	return passed

# =============================================================================
# 测试4: 属性缓冲区大规模处理测试
# =============================================================================

func _test_property_buffer_large_scale():
	print("=== 属性缓冲区大规模处理测试 ===")
	
	var start_time = Time.get_ticks_msec()
	
	# 在属性缓冲区中添加大量属性
	for i in range(SPRING_COUNT + TWEEN_COUNT + SHAKE_COUNT):
		var prop_name = "prop_%d" % i
		property_buffer.add_sample(context.target, prop_name, 0.0, JuicyPropertyBuffer.BlendMode.ADDITIVE)
	
	var buffer_setup_time = Time.get_ticks_msec() - start_time
	
	# 测试大规模属性采样
	start_time = Time.get_ticks_msec()
	for frame in range(60):
		for i in range(SPRING_COUNT + TWEEN_COUNT + SHAKE_COUNT):
			var prop_name = "prop_%d" % i
			property_buffer.add_sample(context.target, prop_name, 0.1, JuicyPropertyBuffer.BlendMode.ADDITIVE)
	
	var sampling_time = Time.get_ticks_msec() - start_time
	
	# 计算性能指标
	var avg_frame_time = sampling_time / 60.0
	var passed = avg_frame_time < TARGET_LARGE_SCALE_TIME / 60.0
	
	print("✓ 属性缓冲区设置时间: %dms" % buffer_setup_time)
	print("✓ 属性数量: %d" % (SPRING_COUNT + TWEEN_COUNT + SHAKE_COUNT))
	print("✓ 60帧采样时间: %dms" % sampling_time)
	print("✓ 平均每帧时间: %.3fms" % avg_frame_time)
	print("✓ 性能通过: %s" % ["是" if passed else "否"])
	
	# 记录测试结果
	test_results["property_buffer_sampling"] = {
		"passed": passed,
		"avg_frame_time": avg_frame_time,
		"sampling_time": sampling_time,
		"target": TARGET_LARGE_SCALE_TIME / 60.0
	}
	
	return passed

# =============================================================================
# 测试5: 综合场景性能测试
# =============================================================================

func _test_comprehensive_scene_performance():
	print("=== 综合场景性能测试 ===")
	
	var start_time = Time.get_ticks_msec()
	var drivers = []
	
	# 创建大规模的混合场景
	# 添加弹簧效果
	for i in range(SPRING_COUNT):
		var spring_data = SpringData.new()
		spring_data.property = "spring_%d" % i
		spring_data.target_value = Vector3.ZERO
		spring_data.stiffness = 100.0 + (i % 50) * 2.0
		spring_data.damping = 10.0 + (i % 20) * 0.5
		spring_data.mass = 1.0 + (i % 10) * 0.1
		
		var driver = JuicySpringDriver.new()
		# 创建Context并设置资源
		var test_context = JuicyContext.new()
		test_context.target = context.target
		test_context.context_id = "spring_%d" % i
		var resource = JuicySpringResource.new()
		resource.add_spring_data(spring_data.property, spring_data.target_value, spring_data.stiffness, spring_data.damping, spring_data.mass, spring_data.initial_velocity, spring_data.threshold)
		test_context.resource = resource
		
		driver.prepare(test_context, 0.016, property_buffer)
		drivers.append({"driver": driver, "context": test_context})
	
	# 添加补间效果
	for i in range(TWEEN_COUNT):
		var tween_data = TweenData.new()
		tween_data.property = "tween_%d" % i
		tween_data.from_value = 0.0
		tween_data.to_value = 100.0
		tween_data.duration = 1.0 + (i % 5) * 0.2
		tween_data.ease_type = Tween.EASE_IN_OUT
		
		var driver = JuicyTweenDriver.new()
		# 创建Context并设置资源
		var test_context = JuicyContext.new()
		test_context.target = context.target
		test_context.context_id = "tween_%d" % i
		var resource = JuicyTweenResource.new()
		resource.add_tween_data(tween_data.property, tween_data.from_value, tween_data.to_value, tween_data.duration, tween_data.delay, tween_data.ease_type, tween_data.trans_type, tween_data.relative)
		test_context.resource = resource
		
		driver.prepare(test_context, 0.016, property_buffer)
		drivers.append({"driver": driver, "context": test_context})
	
	# 添加震动效果
	for i in range(SHAKE_COUNT):
		var shake_data = ShakeData.new()
		shake_data.property = "shake_%d" % i
		shake_data.amplitude = 10.0 + (i % 30) * 0.5
		shake_data.duration = 0.5 + (i % 10) * 0.1
		shake_data.frequency = 10.0 + (i % 20) * 2.0
		
		var driver = JuicyShakeDriver.new()
		# 创建Context并设置资源
		var test_context = JuicyContext.new()
		test_context.target = context.target
		test_context.context_id = "shake_%d" % i
		var resource = JuicyShakeResource.new()
		resource.add_shake_data(shake_data.property, shake_data.amplitude, shake_data.frequency, shake_data.duration, shake_data.falloff, shake_data.noise_seed, shake_data.octaves, shake_data.persistence, shake_data.lacunarity)
		test_context.resource = resource
		
		driver.prepare(test_context, 0.016, property_buffer)
		drivers.append({"driver": driver, "context": test_context})
	
	var setup_time = Time.get_ticks_msec() - start_time
	
	# 测试综合场景运行性能
	start_time = Time.get_ticks_msec()
	for frame in range(60):  # 运行60帧
		for driver_data in drivers:
			driver_data.driver.process(driver_data.context, 0.016, property_buffer)
		
		# 每隔10帧更新属性缓冲区
		if frame % 10 == 0:
			property_buffer.flush_all_samples()
	
	var total_time = Time.get_ticks_msec() - start_time
	
	# 计算性能指标
	var avg_frame_time = total_time / 60.0
	var driver_count = drivers.size()
	var passed = avg_frame_time < TARGET_LARGE_SCALE_TIME / 60.0
	
	# 清理
	for driver_data in drivers:
		driver_data.driver.cleanup(driver_data.context)
	
	print("✓ 场景设置时间: %dms" % setup_time)
	print("✓ Driver总数: %d" % drivers.size())
	print("✓ 弹簧Driver: %d" % SPRING_COUNT)
	print("✓ 补间Driver: %d" % TWEEN_COUNT)
	print("✓ 震动Driver: %d" % SHAKE_COUNT)
	print("✓ 60帧总时间: %dms" % total_time)
	print("✓ 平均每帧时间: %.3fms" % avg_frame_time)
	print("✓ 性能通过: %s" % ["是" if passed else "否"])
	
	# 记录测试结果
	test_results["comprehensive_scene"] = {
		"passed": passed,
		"avg_frame_time": avg_frame_time,
		"total_time": total_time,
		"setup_time": setup_time,
		"driver_count": driver_count,
		"target": TARGET_LARGE_SCALE_TIME / 60.0
	}
	
	return passed

# =============================================================================
# 测试6: 内存使用和GC压力测试
# =============================================================================

func _test_memory_usage_gc_pressure():
	print("=== 内存使用和GC压力测试 ===")
	
	var start_memory = Performance.get_monitor(Performance.MEMORY_STATIC)
	var start_time = Time.get_ticks_msec()
	
	# 创建大量对象来模拟内存压力
	var objects = []
	for i in range(1000):
		var driver = JuicySpringDriver.new()
		
		var spring_data = SpringData.new()
		spring_data.property = "memory_test_%d" % i
		spring_data.target_value = Vector3.ZERO
		spring_data.stiffness = 100.0 + (i % 100) * 1.0
		spring_data.damping = 10.0 + (i % 50) * 0.2
		spring_data.mass = 1.0 + (i % 20) * 0.05
		
		var test_context = JuicyContext.new()
		test_context.target = context.target
		test_context.context_id = "memory_test_%d" % i
		var resource = JuicySpringResource.new()
		resource.add_spring_data(spring_data.property, spring_data.target_value, spring_data.stiffness, spring_data.damping, spring_data.mass, spring_data.initial_velocity, spring_data.threshold)
		test_context.resource = resource
		
		driver.prepare(test_context, 0.016, property_buffer)
		objects.append({"driver": driver, "context": test_context, "data": spring_data})
		
		# 定期清理部分对象
		if i % 100 == 0:
			objects.clear()
		# 等待一帧让垃圾回收有机会运行
			await Engine.get_main_loop().process_frame
	
	var end_time = Time.get_ticks_msec()
	var end_memory = Performance.get_monitor(Performance.MEMORY_STATIC)
	
	# 清理剩余对象
	for obj in objects:
		obj.driver.cleanup(obj.context)
	
	# 计算内存使用
	var memory_usage_mb = (end_memory - start_memory) / (1024.0 * 1024.0)
	var test_duration = end_time - start_time
	var passed = memory_usage_mb < TARGET_MEMORY_USAGE
	
	print("✓ 测试持续时间: %dms" % test_duration)
	print("✓ 内存增长: %.2fMB" % memory_usage_mb)
	print("✓ 内存目标: <%.2fMB" % TARGET_MEMORY_USAGE)
	print("✓ 内存测试通过: %s" % ["是" if passed else "否"])
	
	# 等待垃圾回收完成
	await Engine.get_main_loop().process_frame
	
	# 记录测试结果
	test_results["memory_usage"] = {
		"passed": passed,
		"memory_usage_mb": memory_usage_mb,
		"test_duration": test_duration,
		"target": TARGET_MEMORY_USAGE
	}
	
	return passed

# =============================================================================
# 测试7: 性能基准测试总结
# =============================================================================

func _generate_performance_summary():
	print("\n=== 性能基准测试总结 ===")
	
	# 生成性能报告
	print("\n=== 性能基准测试报告 ===")
	for test_name in test_results.keys():
		var result_data = test_results[test_name]
		print("✓ %s: %s (目标: <%.3f)" % [
			test_name,
			"通过" if result_data.passed else "失败",
			result_data.target
		])
	
	var passed_count = 0
	for test_name in test_results.keys():
		if test_results[test_name].passed:
			passed_count += 1
	
	var pass_rate = (passed_count / test_results.size()) * 100.0
	print("\n总体通过率: %.1f%% (%d/%d)" % [pass_rate, passed_count, test_results.size()])
	
	# 验证整体性能目标
	if pass_rate >= 80.0:
		print("✅ 性能基准测试通过，整体通过率: %.1f%%" % pass_rate)
	else:
		print("❌ 性能基准测试失败，整体通过率: %.1f%% (需要 >= 80%%)" % pass_rate)