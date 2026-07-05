# 性能优化测试
# 测试大量组合项的性能、参数映射的实时更新性能、变体系统的创建性能、内存使用情况

extends Node

# 测试状态
var _tests_completed = 0
var _tests_total = 0
var _test_results = []
var _start_time = 0.0

# 性能基准
const BASELINE_COMPOSITE_VALIDATION_MS = 0.05  # 50微秒
const BASELINE_PARAMETER_MAPPING_MS = 0.01     # 10微秒
const BASELINE_VARIANT_CREATION_MS = 0.1       # 100微秒
const BASELINE_MEMORY_USAGE_MB = 10.0          # 10MB

# 测试资源
var _test_composite: JuicyCompositeResource
var _test_parameter_mapping: JuicyParameterMapping
var _test_variant: JuicyResourceVariant
var _test_context: JuicyContext
var _test_shake_resources: Array = []
var _test_mappings: Array = []

func _ready():
	print("🧪 开始性能优化测试...")
	_start_time = Time.get_ticks_msec() / 1000.0
	
	# 初始化测试资源
	_setup_test_resources()
	
	# 运行所有测试
	_run_all_tests()
	
	# 生成测试报告
	_generate_test_report()
	
	# 标记测试完成
	_tests_completed = _tests_total

func _setup_test_resources():
	# 创建测试上下文
	_test_context = JuicyContext.new()
	
	# 创建测试参数映射
	_test_parameter_mapping = JuicyParameterMapping.new()
	_test_parameter_mapping.input_parameter = "intensity"
	_test_parameter_mapping.target_item_index = 0
	_test_parameter_mapping.target_property = "amplitude"
	_test_parameter_mapping.enabled = true
	
	# 创建测试组合资源
	_test_composite = JuicyCompositeResource.new()
	_test_composite.enable_parameter_mapping = true
	_test_composite.blend_mode = JuicyCompositeResource.CompositeBlendMode.ADDITIVE
	
	# 创建测试变体
	_test_variant = JuicyResourceVariant.new()
	_test_variant.inherit_parameter_bindings = true

func _run_all_tests():
	print("\n📋 运行性能优化测试...")
	
	# 大量组合项性能测试
	_test_large_composite_performance()
	
	# 参数映射实时更新性能测试
	_test_parameter_mapping_real_time_performance()
	
	# 变体系统创建性能测试
	_test_variant_creation_performance()
	
	# 内存使用测试
	_test_memory_usage()
	
	# 并发处理性能测试
	_test_concurrent_processing()
	
	# 缓存机制测试
	_test_caching_mechanisms()
	
	# 垃圾回收影响测试
	_test_garbage_collection_impact()
	
	# 长时间运行稳定性测试
	_test_long_running_stability()

func _test_large_composite_performance():
	print("\n🔍 测试大量组合项性能...")
	_tests_total += 1
	
	# 创建大量组合项
	var item_count = 100
	var items = []
	
	var create_start = Time.get_ticks_usec()
	for i in range(item_count):
		var shake_resource = JuicyShakeResource.new()
		var shake_data = ShakeData.new()
		shake_data.property = "position"
		shake_data.amplitude = randf_range(1.0, 20.0)
		shake_data.frequency = randf_range(1.0, 10.0)
		shake_data.duration = randf_range(0.5, 2.0)
		# 使用add_shake_data方法而不是直接赋值
		shake_resource.add_shake_data(
			shake_data.property,
			shake_data.amplitude,
			shake_data.frequency,
			shake_data.duration,
			shake_data.falloff,
			shake_data.noise_seed,
			shake_data.octaves,
			shake_data.persistence,
			shake_data.lacunarity
		)
		shake_resource.duration = shake_data.duration
		
		var item = JuicyCompositeItem.new()
		item.resource = shake_resource
		item.weight = randf_range(0.1, 2.0)
		item.enabled = true
		items.append(item)
	
	var create_end = Time.get_ticks_usec()
	var create_time = (create_end - create_start) / 1000.0
	
	# 设置组合项
	_test_composite.composite_items = items
	
	# 测试验证性能
	var validation_start = Time.get_ticks_usec()
	var validation_result = _test_composite.validate_config()
	var validation_end = Time.get_ticks_usec()
	var validation_time = (validation_end - validation_start) / 1000.0
	
	# 测试权重计算性能
	var weight_start = Time.get_ticks_usec()
	var total_weight = _test_composite.get_total_weight()
	var normalized_weights = _test_composite.get_normalized_weights()
	var weight_end = Time.get_ticks_usec()
	var weight_time = (weight_end - weight_start) / 1000.0
	
	# 测试驱动器创建性能
	var driver_start = Time.get_ticks_usec()
	var drivers = _test_composite.create_drivers()
	var driver_end = Time.get_ticks_usec()
	var driver_time = (driver_end - driver_start) / 1000.0
	
	print("  大量组合项性能测试结果:")
	print("  组合项数量: " + str(item_count))
	print("  创建耗时: " + str(create_time) + "ms")
	print("  验证平均耗时: " + str(validation_time) + "ms")
	print("  权重计算平均耗时: " + str(weight_time) + "ms")
	print("  驱动器创建平均耗时: " + str(driver_time) + "ms")
	
	# 性能基准检查
	var validation_ok = validation_time < BASELINE_COMPOSITE_VALIDATION_MS * 10  # 大量项时放宽标准
	var weight_ok = weight_time < BASELINE_COMPOSITE_VALIDATION_MS * 5
	var driver_ok = driver_time < BASELINE_COMPOSITE_VALIDATION_MS * 2
	
	var performance_ok = validation_ok and weight_ok and driver_ok
	assert(performance_ok, "大量组合项性能测试失败")
	
	_record_test_result("大量组合项性能", performance_ok, "大量组合项性能测试" + ("通过" if performance_ok else "失败"))

func _test_parameter_mapping_real_time_performance():
	print("\n🔍 测试参数映射实时更新性能...")
	_tests_total += 1
	
	# 创建多个参数映射
	var mapping_count = 50
	_test_mappings.clear()
	
	var create_start = Time.get_ticks_usec()
	for i in range(mapping_count):
		var mapping = JuicyParameterMapping.new()
		mapping.input_parameter = "param_" + str(i)
		mapping.target_item_index = i % 10  # 循环使用0-9
		mapping.target_property = "amplitude"
		mapping.enabled = true
		
		# 为部分映射添加曲线
		if i % 3 == 0:
			var curve = Curve.new()
			curve.add_point(Vector2(0, 0))
			curve.add_point(Vector2(1, 1))
			mapping.curve = curve
		
		_test_mappings.append(mapping)
	
	var create_end = Time.get_ticks_usec()
	var create_time = (create_end - create_start) / 1000.0
	
	# 测试参数映射应用性能
	var iterations = 10000
	var apply_start = Time.get_ticks_usec()
	
	for i in range(iterations):
		var mapping_index = i % mapping_count
		var input_value = randf()
		var mapped_value = _test_mappings[mapping_index].apply_mapping(input_value)
		assert(mapped_value >= 0.0 and mapped_value <= 1.0, "参数映射结果超出范围")
	
	var apply_end = Time.get_ticks_usec()
	var apply_time = (apply_end - apply_start) / 1000.0
	var avg_apply_time = apply_time / iterations
	
	# 测试批量参数更新性能
	var batch_iterations = 1000
	var batch_start = Time.get_ticks_usec()
	
	for i in range(batch_iterations):
		# 模拟同时更新多个参数
		for j in range(10):
			var param_name = "param_" + str(j)
			var param_value = randf()
			_test_context.set_parameter(param_name, param_value)
	
	var batch_end = Time.get_ticks_usec()
	var batch_time = (batch_end - batch_start) / 1000.0
	var avg_batch_time = batch_time / batch_iterations
	
	print("  参数映射实时更新性能测试结果:")
	print("  参数映射数量: " + str(mapping_count))
	print("  创建平均耗时: " + str(create_time / mapping_count) + "ms/个")
	print("  应用平均耗时: " + str(avg_apply_time) + "ms/次")
	print("  批量更新平均耗时: " + str(avg_batch_time) + "ms/批次")
	
	# 性能基准检查
	var apply_ok = avg_apply_time < BASELINE_PARAMETER_MAPPING_MS
	var batch_ok = avg_batch_time < BASELINE_PARAMETER_MAPPING_MS * 10
	
	var performance_ok = apply_ok and batch_ok
	assert(performance_ok, "参数映射实时更新性能测试失败")
	
	_record_test_result("参数映射实时更新性能", performance_ok, "参数映射实时更新性能测试" + ("通过" if performance_ok else "失败"))

func _test_variant_creation_performance():
	print("\n🔍 测试变体系统创建性能...")
	_tests_total += 1
	
	# 创建基础组合资源
	var base_composite = JuicyCompositeResource.new()
	var items = []
	
	# 创建多个组合项
	for i in range(20):
		var shake_resource = JuicyShakeResource.new()
		var shake_data = ShakeData.new()
		shake_data.property = "position"
		shake_data.amplitude = 10.0
		shake_data.frequency = 5.0
		shake_data.duration = 1.0
		# 使用add_shake_data方法而不是直接赋值
		shake_resource.add_shake_data(
			shake_data.property,
			shake_data.amplitude,
			shake_data.frequency,
			shake_data.duration,
			shake_data.falloff,
			shake_data.noise_seed,
			shake_data.octaves,
			shake_data.persistence,
			shake_data.lacunarity
		)
		shake_resource.duration = 1.0
		
		var item = JuicyCompositeItem.new()
		item.resource = shake_resource
		item.weight = 1.0
		item.enabled = true
		items.append(item)
	
	base_composite.composite_items = items
	
	# 创建多个数据覆盖
	var overrides = []
	for i in range(10):
		var override = DataOverride.new()
		override.override_mode = DataOverride.OverrideMode.MODIFY_DATA
		override.target_item_index = i % items.size()
		override.target_data_index = 0
		override.property_overrides = {"amplitude": 15.0, "frequency": 7.0}
		override.enabled = true
		overrides.append(override)
	
	# 设置变体
	_test_variant.base_composite_resource = base_composite
	
	# 测试变体创建性能
	var iterations = 500
	var creation_start = Time.get_ticks_usec()
	
	for i in range(iterations):
		_test_variant.data_overrides = overrides
		var variant_composite = _test_variant._create_variant_composite()
		assert(variant_composite != null, "变体创建失败")
	
	var creation_end = Time.get_ticks_usec()
	var creation_time = (creation_end - creation_start) / 1000.0
	var avg_creation_time = creation_time / iterations
	
	# 测试变体验证性能
	var validation_start = Time.get_ticks_usec()
	var validation_result = _test_variant.validate_config()
	var validation_end = Time.get_ticks_usec()
	var validation_time = (validation_end - validation_start) / 1000.0
	
	print("  变体系统创建性能测试结果:")
	print("  基础组合项数量: " + str(items.size()))
	print("  数据覆盖数量: " + str(overrides.size()))
	print("  变体创建平均耗时: " + str(avg_creation_time) + "ms/次")
	print("  变体验证耗时: " + str(validation_time) + "ms")
	
	# 性能基准检查
	var creation_ok = avg_creation_time < BASELINE_VARIANT_CREATION_MS
	var validation_ok = validation_time < BASELINE_VARIANT_CREATION_MS * 2
	
	var performance_ok = creation_ok and validation_ok
	assert(performance_ok, "变体系统创建性能测试失败")
	
	_record_test_result("变体系统创建性能", performance_ok, "变体系统创建性能测试" + ("通过" if performance_ok else "失败"))

func _test_memory_usage():
	print("\n🔍 测试内存使用情况...")
	_tests_total += 1
	
	# 记录初始内存使用
	var initial_memory = OS.get_static_memory_usage() / 1024.0 / 1024.0  # 转换为MB
	
	# 创建大量对象
	var object_count = 1000
	var composites = []
	var variants = []
	var mappings = []
	
	for i in range(object_count):
		# 创建组合资源
		var composite = JuicyCompositeResource.new()
		var item = JuicyCompositeItem.new()
		var shake_resource = JuicyShakeResource.new()
		var shake_data = ShakeData.new()
		shake_data.property = "position"
		shake_data.amplitude = 10.0
		shake_data.frequency = 5.0
		shake_data.duration = 1.0
		shake_resource.add_shake_data(
			shake_data.property,
			shake_data.amplitude,
			shake_data.frequency,
			shake_data.duration,
			shake_data.falloff,
			shake_data.noise_seed,
			shake_data.octaves,
			shake_data.persistence,
			shake_data.lacunarity
		)
		item.resource = shake_resource
		composite.composite_items = [item]
		composites.append(composite)
		
		# 创建变体资源
		var variant = JuicyResourceVariant.new()
		variant.base_composite_resource = composite
		variants.append(variant)
		
		# 创建参数映射
		var mapping = JuicyParameterMapping.new()
		mapping.input_parameter = "param_" + str(i)
		mapping.target_item_index = 0
		mapping.target_property = "amplitude"
		mappings.append(mapping)
	
	# 记录创建后的内存使用
	var after_creation_memory = OS.get_static_memory_usage() / 1024.0 / 1024.0
	var creation_memory_increase = after_creation_memory - initial_memory
	
	# 测试内存释放
	var release_start = Time.get_ticks_usec()
	
	# 清空引用，允许垃圾回收
	composites.clear()
	variants.clear()
	mappings.clear()
	_test_mappings.clear()
	
	# 强制垃圾回收
	ProjectSettings.set_setting("memory/limits/message_queue/max_size_kb", 4096)
	
	var release_end = Time.get_ticks_usec()
	var release_time = (release_end - release_start) / 1000.0
	
	# 记录释放后的内存使用
	var after_release_memory = OS.get_static_memory_usage() / 1024.0 / 1024.0
	var released_memory = after_creation_memory - after_release_memory
	
	print("  内存使用测试结果:")
	print("  初始内存使用: " + str(initial_memory) + "MB")
	print("  创建后内存使用: " + str(after_creation_memory) + "MB")
	print("  内存增加: " + str(creation_memory_increase) + "MB")
	print("  对象数量: " + str(object_count * 3))
	print("  每个对象平均内存: " + str((creation_memory_increase * 1024) / (object_count * 3)) + "KB")
	print("  内存释放: " + str(released_memory) + "MB")
	print("  释放耗时: " + str(release_time) + "ms")
	
	# 内存基准检查
	var memory_ok = creation_memory_increase < BASELINE_MEMORY_USAGE_MB * 10  # 放宽标准
	var release_ok = released_memory > creation_memory_increase * 0.5  # 至少释放50%
	
	var memory_test_ok = memory_ok and release_ok
	assert(memory_test_ok, "内存使用测试失败")
	
	_record_test_result("内存使用", memory_test_ok, "内存使用测试" + ("通过" if memory_test_ok else "失败"))

func _test_concurrent_processing():
	print("\n🔍 测试并发处理性能...")
	_tests_total += 1
	
	# 创建多个独立的组合资源
	var composite_count = 10
	var composites = []
	
	for i in range(composite_count):
		var composite = JuicyCompositeResource.new()
		var item = JuicyCompositeItem.new()
		var shake_resource = JuicyShakeResource.new()
		var shake_data = ShakeData.new()
		shake_data.property = "position"
		shake_data.amplitude = 10.0
		shake_data.frequency = 5.0
		shake_data.duration = 1.0
		shake_resource.add_shake_data(
			shake_data.property,
			shake_data.amplitude,
			shake_data.frequency,
			shake_data.duration,
			shake_data.falloff,
			shake_data.noise_seed,
			shake_data.octaves,
			shake_data.persistence,
			shake_data.lacunarity
		)
		item.resource = shake_resource
		composite.composite_items = [item]
		composites.append(composite)
	
	# 测试并发验证性能
	var iterations = 100
	var concurrent_start = Time.get_ticks_usec()
	
	for i in range(iterations):
		# 模拟并发处理多个组合资源
		for composite in composites:
			var validation_result = composite.validate_config()
			assert(validation_result.valid, "并发验证失败")
			
			var total_weight = composite.get_total_weight()
			var normalized_weights = composite.get_normalized_weights()
	
	var concurrent_end = Time.get_ticks_usec()
	var concurrent_time = (concurrent_end - concurrent_start) / 1000.0
	var avg_concurrent_time = concurrent_time / iterations
	
	# 测试并发参数映射性能
	var mappings = []
	for i in range(composite_count):
		var mapping = JuicyParameterMapping.new()
		mapping.input_parameter = "param_" + str(i)
		mapping.target_item_index = 0
		mapping.target_property = "amplitude"
		mappings.append(mapping)
	
	var mapping_start = Time.get_ticks_usec()
	for i in range(iterations * 10):  # 更多迭代
		for mapping in mappings:
			var input_value = randf()
			var mapped_value = mapping.apply_mapping(input_value)
			assert(mapped_value >= 0.0 and mapped_value <= 1.0, "并发参数映射失败")
	
	var mapping_end = Time.get_ticks_usec()
	var mapping_time = (mapping_end - mapping_start) / 1000.0
	var avg_mapping_time = mapping_time / (iterations * 10)
	
	print("  并发处理性能测试结果:")
	print("  组合资源数量: " + str(composite_count))
	print("  并发验证平均耗时: " + str(avg_concurrent_time) + "ms/批次")
	print("  并发参数映射平均耗时: " + str(avg_mapping_time) + "ms/次")
	
	# 性能基准检查
	var concurrent_ok = avg_concurrent_time < BASELINE_COMPOSITE_VALIDATION_MS * composite_count * 1.5
	var mapping_ok = avg_mapping_time < BASELINE_PARAMETER_MAPPING_MS * 1.2
	
	var performance_ok = concurrent_ok and mapping_ok
	assert(performance_ok, "并发处理性能测试失败")
	
	_record_test_result("并发处理性能", performance_ok, "并发处理性能测试" + ("通过" if performance_ok else "失败"))

func _test_caching_mechanisms():
	print("\n🔍 测试缓存机制...")
	_tests_total += 1
	
	# 创建测试组合资源
	var composite = JuicyCompositeResource.new()
	var items = []
	
	for i in range(5):
		var shake_resource = JuicyShakeResource.new()
		var shake_data = ShakeData.new()
		shake_data.property = "position"
		shake_data.amplitude = 10.0
		shake_data.frequency = 5.0
		shake_data.duration = 1.0
		shake_resource.add_shake_data(
			shake_data.property,
			shake_data.amplitude,
			shake_data.frequency,
			shake_data.duration,
			shake_data.falloff,
			shake_data.noise_seed,
			shake_data.octaves,
			shake_data.persistence,
			shake_data.lacunarity
		)
		
		var item = JuicyCompositeItem.new()
		item.resource = shake_resource
		item.weight = 1.0
		items.append(item)
	
	composite.composite_items = items
	
	# 测试权重计算缓存效果
	var iterations = 1000
	
	# 第一次计算（无缓存）
	var first_start = Time.get_ticks_usec()
	for i in range(iterations):
		var total_weight = composite.get_total_weight()
		var normalized_weights = composite.get_normalized_weights()
	var first_end = Time.get_ticks_usec()
	var first_time = (first_end - first_start) / 1000.0
	
	# 第二次计算（应该有缓存优化）
	var second_start = Time.get_ticks_usec()
	for i in range(iterations):
		var total_weight = composite.get_total_weight()
		var normalized_weights = composite.get_normalized_weights()
	var second_end = Time.get_ticks_usec()
	var second_time = (second_end - second_start) / 1000.0
	
	# 测试参数映射缓存
	var mapping = JuicyParameterMapping.new()
	mapping.input_parameter = "test_param"
	mapping.target_item_index = 0
	mapping.target_property = "amplitude"
	
	# 添加曲线以测试曲线缓存
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.5, 0.8))
	curve.add_point(Vector2(1, 1))
	mapping.curve = curve
	
	# 第一次映射计算
	var mapping_first_start = Time.get_ticks_usec()
	for i in range(iterations):
		var mapped_value = mapping.apply_mapping(0.5)
	var mapping_first_end = Time.get_ticks_usec()
	var mapping_first_time = (mapping_first_end - mapping_first_start) / 1000.0
	
	# 第二次映射计算
	var mapping_second_start = Time.get_ticks_usec()
	for i in range(iterations):
		var mapped_value = mapping.apply_mapping(0.5)
	var mapping_second_end = Time.get_ticks_usec()
	var mapping_second_time = (mapping_second_end - mapping_second_start) / 1000.0
	
	print("  缓存机制测试结果:")
	print("  权重计算第一次耗时: " + str(first_time) + "ms")
	print("  权重计算第二次耗时: " + str(second_time) + "ms")
	print("  参数映射第一次耗时: " + str(mapping_first_time) + "ms")
	print("  参数映射第二次耗时: " + str(mapping_second_time) + "ms")
	
	# 缓存效果检查
	var weight_cache_ok = second_time <= first_time * 1.1  # 允许10%的波动
	var mapping_cache_ok = mapping_second_time <= mapping_first_time * 1.1
	
	var cache_ok = weight_cache_ok and mapping_cache_ok
	assert(cache_ok, "缓存机制测试失败")
	
	_record_test_result("缓存机制", cache_ok, "缓存机制测试" + ("通过" if cache_ok else "失败"))

func _test_garbage_collection_impact():
	print("\n🔍 测试垃圾回收影响...")
	_tests_total += 1
	
	# 创建大量临时对象
	var iterations = 100
	var gc_impacts = []
	
	for i in range(iterations):
		# 记录GC前的性能
		var before_gc_start = Time.get_ticks_usec()
		
		# 创建临时对象
		var temp_composites = []
		for j in range(50):
			var composite = JuicyCompositeResource.new()
			var item = JuicyCompositeItem.new()
			var shake_resource = JuicyShakeResource.new()
			var shake_data = ShakeData.new()
			shake_data.property = "position"
			shake_data.amplitude = 10.0
			shake_data.frequency = 5.0
			shake_data.duration = 1.0
			shake_resource.add_shake_data(
				shake_data.property,
				shake_data.amplitude,
				shake_data.frequency,
				shake_data.duration,
				shake_data.falloff,
				shake_data.noise_seed,
				shake_data.octaves,
				shake_data.persistence,
				shake_data.lacunarity
			)
			item.resource = shake_resource
			composite.composite_items = [item]
			temp_composites.append(composite)
		
		var before_gc_end = Time.get_ticks_usec()
		var before_gc_time = (before_gc_end - before_gc_start) / 1000.0
		
		# 释放临时对象
		temp_composites.clear()
		
		# 记录GC后的性能
		var after_gc_start = Time.get_ticks_usec()
		
		# 创建新的对象
		var new_composites = []
		for j in range(50):
			var composite = JuicyCompositeResource.new()
			var item = JuicyCompositeItem.new()
			var shake_resource = JuicyShakeResource.new()
			var shake_data = ShakeData.new()
			shake_data.property = "position"
			shake_data.amplitude = 10.0
			shake_data.frequency = 5.0
			shake_data.duration = 1.0
			shake_resource.add_shake_data(
				shake_data.property,
				shake_data.amplitude,
				shake_data.frequency,
				shake_data.duration,
				shake_data.falloff,
				shake_data.noise_seed,
				shake_data.octaves,
				shake_data.persistence,
				shake_data.lacunarity
			)
			item.resource = shake_resource
			composite.composite_items = [item]
			new_composites.append(composite)
		
		var after_gc_end = Time.get_ticks_usec()
		var after_gc_time = (after_gc_end - after_gc_start) / 1000.0
		
		new_composites.clear()
		
		# 计算GC影响
		var gc_impact = (after_gc_time - before_gc_time) / before_gc_time * 100
		gc_impacts.append(gc_impact)
	
	# 计算平均GC影响
	var total_impact = 0.0
	for impact in gc_impacts:
		total_impact += impact
	var avg_gc_impact = total_impact / gc_impacts.size()
	
	print("  垃圾回收影响测试结果:")
	print("  测试迭代次数: " + str(iterations))
	print("  平均GC性能影响: " + str(avg_gc_impact) + "%")
	
	# GC影响基准检查
	var gc_impact_ok = abs(avg_gc_impact) < 20.0  # GC影响应小于20%
	
	assert(gc_impact_ok, "垃圾回收影响测试失败")
	
	_record_test_result("垃圾回收影响", gc_impact_ok, "垃圾回收影响测试" + ("通过" if gc_impact_ok else "失败"))

func _test_long_running_stability():
	print("\n🔍 测试长时间运行稳定性...")
	_tests_total += 1
	
	# 创建测试资源
	var composite = JuicyCompositeResource.new()
	var items = []
	
	for i in range(10):
		var shake_resource = JuicyShakeResource.new()
		var shake_data = ShakeData.new()
		shake_data.property = "position"
		shake_data.amplitude = 10.0
		shake_data.frequency = 5.0
		shake_data.duration = 1.0
		shake_resource.add_shake_data(
			shake_data.property,
			shake_data.amplitude,
			shake_data.frequency,
			shake_data.duration,
			shake_data.falloff,
			shake_data.noise_seed,
			shake_data.octaves,
			shake_data.persistence,
			shake_data.lacunarity
		)
		
		var item = JuicyCompositeItem.new()
		item.resource = shake_resource
		item.weight = 1.0
		items.append(item)
	
	composite.composite_items = items
	
	# 长时间运行测试
	var test_duration = 5.0  # 5秒
	var start_time = Time.get_ticks_msec() / 1000.0
	var iterations = 0
	var errors = 0
	
	while (Time.get_ticks_msec() / 1000.0 - start_time) < test_duration:
		iterations += 1
		
		# 测试验证
		var validation_result = composite.validate_config()
		if not validation_result.valid:
			errors += 1
		
		# 测试权重计算
		var total_weight = composite.get_total_weight()
		var normalized_weights = composite.get_normalized_weights()
		
		# 测试驱动器创建
		var drivers = composite.create_drivers()
		if drivers.size() != 1:
			errors += 1
		
		# 测试参数映射
		var mapping = JuicyParameterMapping.new()
		mapping.input_parameter = "test_param"
		mapping.target_item_index = 0
		mapping.target_property = "amplitude"
		var mapped_value = mapping.apply_mapping(randf())
		
		# 清理
		mapping.free()
	
	var end_time = Time.get_ticks_msec() / 1000.0
	var total_time = end_time - start_time
	var avg_iteration_time = (total_time * 1000) / iterations
	
	print("  长时间运行稳定性测试结果:")
	print("  测试持续时间: " + str(total_time) + "秒")
	print("  总迭代次数: " + str(iterations))
	print("  错误次数: " + str(errors))
	print("  平均迭代耗时: " + str(avg_iteration_time) + "ms")
	print("  迭代频率: " + str(iterations / total_time) + "次/秒")
	
	# 稳定性基准检查
	var stability_ok = errors == 0
	var performance_ok = avg_iteration_time < 1.0  # 每次迭代应小于1ms
	
	var long_running_ok = stability_ok and performance_ok
	assert(long_running_ok, "长时间运行稳定性测试失败")
	
	_record_test_result("长时间运行稳定性", long_running_ok, "长时间运行稳定性测试" + ("通过" if long_running_ok else "失败"))

func _record_test_result(test_name: String, passed: bool, message: String):
	_test_results.append({
		"name": test_name,
		"passed": passed,
		"message": message,
		"timestamp": Time.get_ticks_msec() / 1000.0
	})
	
	if not passed:
		push_error("测试失败 - " + test_name + ": " + message)

func _generate_test_report():
	var end_time = Time.get_ticks_msec() / 1000.0
	var total_time = end_time - _start_time
	
	var passed_count = 0
	var failed_count = 0
	
	for result in _test_results:
		if result.passed:
			passed_count += 1
		else:
			failed_count += 1
	
	print("\n==================================================")
	print("📊 性能优化测试报告")
	print("==================================================")
	print("总测试数: " + str(_tests_total))
	print("通过测试: " + str(passed_count))
	print("失败测试: " + str(failed_count))
	print("通过率: %.1f%%" % (float(passed_count) / _tests_total * 100))
	print("总耗时: %.3f 秒" % total_time)
	
	print("\n📈 性能基准数据:")
	print("  组合验证基准: " + str(BASELINE_COMPOSITE_VALIDATION_MS) + "ms")
	print("  参数映射基准: " + str(BASELINE_PARAMETER_MAPPING_MS) + "ms")
	print("  变体创建基准: " + str(BASELINE_VARIANT_CREATION_MS) + "ms")
	print("  内存使用基准: " + str(BASELINE_MEMORY_USAGE_MB) + "MB")
	
	if failed_count > 0:
		print("\n❌ 失败的测试:")
		for result in _test_results:
			if not result.passed:
				print("  - " + result.name + ": " + result.message)
	
	print("\n==================================================")
	if failed_count == 0:
		print("🎉 所有性能优化测试通过！")
	else:
		print("⚠️  部分测试失败，请检查上面的详细信息")
	print("==================================================")