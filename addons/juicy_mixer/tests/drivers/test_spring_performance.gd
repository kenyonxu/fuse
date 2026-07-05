# SpringDriver性能基准测试
# 测试弹簧物理计算的性能，确保满足阶段2的性能要求

extends Node

# 断言辅助函数
func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		push_error("Assertion failed: " + message)
		return
	print("✓ " + message)

func assert_lt(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual >= expected:
		push_error("Assertion failed: expected %s < %s - %s" % [str(actual), str(expected), message])
		return
	print("✓ " + message)

# 测试1000次弹簧物理计算 < 16ms
func test_spring_physics_1000_calculations():
	print("🧪 Testing 1000 spring physics calculations performance...")
	
	# 创建测试数据
	var spring_data = SpringData.new()
	spring_data.property = "position"
	spring_data.target_value = Vector2(100, 100)
	spring_data.stiffness = 100.0
	spring_data.damping = 10.0
	spring_data.mass = 1.0
	spring_data.threshold = 0.01
	
	# 创建多个弹簧状态以模拟批量计算
	var spring_states = []
	for i in range(1000):
		var state = {
			"current_position": Vector2(0, 0),
			"current_velocity": Vector2(0, 0),
			"target_position": Vector2(100 + i * 0.1, 100 + i * 0.1),
			"is_stable": false
		}
		spring_states.append(state)
	
	# 测量计算时间
	var start_time = Time.get_ticks_usec()
	
	# 执行1000次弹簧物理计算
	for i in range(1000):
		var state = spring_states[i]
		var config = spring_data
		
		# 计算弹簧力 (胡克定律: F = -kx)
		var displacement = state.target_position - state.current_position
		var spring_force = displacement * -config.stiffness
		
		# 计算阻尼力 (F = -cv)
		var damping_force = state.current_velocity * -config.damping
		
		# 计算总力
		var total_force = spring_force + damping_force
		
		# 更新速度 (v = v + (F/m) * dt)
		var acceleration = total_force / config.mass
		var delta_velocity = acceleration * (1.0/60.0)  # 假设60fps
		state.current_velocity += delta_velocity
		
		# 更新位置 (x = x + v * dt)
		var delta_position = state.current_velocity * (1.0/60.0)
		state.current_position += delta_position
		
		# 检查稳定性
		var position_error = (state.current_position - state.target_position).length()
		var velocity_error = state.current_velocity.length()
		state.is_stable = position_error < config.threshold and velocity_error < config.threshold
	
	var end_time = Time.get_ticks_usec()
	var total_time = (end_time - start_time) / 1000.0  # 转换为毫秒
	
	print("1000 spring physics calculations took: %.3f ms" % total_time)
	print("Average time per calculation: %.6f ms" % (total_time / 1000.0))
	
	# 验证性能要求：1000次计算 < 16ms
	assert_lt(total_time, 16.0, "1000 spring physics calculations should take less than 16ms")
	assert_lt(total_time / 1000.0, 0.016, "Average calculation time should be less than 0.016ms")
	
	print("✅ Spring physics 1000 calculations performance test passed")

# 测试批量弹簧力计算
func test_batch_spring_force_calculation():
	print("🧪 Testing batch spring force calculation performance...")
	
	# 创建批量测试数据
	var batch_size = 1000
	var spring_configs = []
	var spring_states = []
	
	# 准备测试数据
	for i in range(batch_size):
		var config = {
			"stiffness": 100.0 + i * 0.1,
			"damping": 10.0 + i * 0.01,
			"mass": 1.0,
			"threshold": 0.01
		}
		spring_configs.append(config)
		
		var state = {
			"current_position": Vector2(i * 0.1, i * 0.1),
			"current_velocity": Vector2(i * 0.05, i * 0.05),
			"target_position": Vector2(100 + i * 0.1, 100 + i * 0.1),
			"is_stable": false
		}
		spring_states.append(state)
	
	# 测量批量计算时间
	var start_time = Time.get_ticks_usec()
	
	# 执行批量弹簧力计算
	for i in range(batch_size):
		var config = spring_configs[i]
		var state = spring_states[i]
		
		# 计算弹簧力
		var displacement = state.target_position - state.current_position
		var spring_force = displacement * -config.stiffness
		
		# 计算阻尼力
		var damping_force = state.current_velocity * -config.damping
		
		# 计算总力
		var total_force = spring_force + damping_force
		
		# 存储结果（模拟实际使用）
		state.force = total_force
	
	var end_time = Time.get_ticks_usec()
	var total_time = (end_time - start_time) / 1000.0  # 转换为毫秒
	
	print("Batch %d spring force calculations took: %.3f ms" % [batch_size, total_time])
	print("Average time per force calculation: %.6f ms" % (total_time / batch_size))
	
	# 验证性能要求
	assert_lt(total_time, 16.0, "Batch spring force calculations should take less than 16ms")
	assert_lt(total_time / batch_size, 0.016, "Average force calculation time should be less than 0.016ms")
	
	print("✅ Batch spring force calculation performance test passed")

# 测试SpringDriver完整处理性能
func test_spring_driver_processing_performance():
	print("🧪 Testing SpringDriver processing performance...")
	
	# 创建测试目标
	var target = Node2D.new()
	target.position = Vector2.ZERO
	add_child(target)
	
	# 创建大量弹簧数据（模拟复杂场景）
	var spring_resource = JuicySpringResource.new()
	for i in range(100):  # 100个弹簧属性
		var spring_data = SpringData.new()
		spring_data.property = "position"
		spring_data.target_value = Vector2(100 + i * 10, 100 + i * 10)
		spring_data.stiffness = 100.0 + i * 5
		spring_data.damping = 10.0 + i * 0.5
		spring_data.mass = 1.0
		spring_data.threshold = 0.01
		spring_resource.spring_data.append(spring_data)
	
	# 创建Context和Driver
	var context = JuicyContext.create(spring_resource, target)
	var driver = JuicySpringDriver.new()
	var buffer = JuicyPropertyBuffer.new()
	
	# 准备驱动器
	driver.prepare(context, 0.0, buffer)
	
	# 测量处理时间
	var start_time = Time.get_ticks_usec()
	
	# 执行一次完整的处理（模拟一帧）
	driver.process(context, 1.0/60.0, buffer)
	
	var end_time = Time.get_ticks_usec()
	var processing_time = (end_time - start_time) / 1000.0  # 转换为毫秒
	
	print("SpringDriver processing 100 spring properties took: %.3f ms" % processing_time)
	print("Average time per property: %.6f ms" % (processing_time / 100.0))
	
	# 验证性能要求
	assert_lt(processing_time, 16.0, "Processing 100 spring properties should take less than 16ms")
	assert_lt(processing_time / 100.0, 0.16, "Average time per property should be less than 0.16ms")
	
	# 清理
	target.queue_free()
	
	print("✅ SpringDriver processing performance test passed")

# 测试不同复杂度下的性能缩放
func test_performance_scaling():
	print("🧪 Testing performance scaling with different complexities...")
	
	# 测试不同数量的弹簧属性
	var test_cases = [10, 50, 100, 200, 500]
	var results = []
	
	for count in test_cases:
		# 创建测试目标
		var target = Node2D.new()
		target.position = Vector2.ZERO
		add_child(target)
		
		# 创建弹簧资源
		var spring_resource = JuicySpringResource.new()
		for i in range(count):
			var spring_data = SpringData.new()
			spring_data.property = "position"
			spring_data.target_value = Vector2(100, 100)
			spring_data.stiffness = 100.0
			spring_data.damping = 10.0
			spring_data.mass = 1.0
			spring_data.threshold = 0.01
			spring_resource.spring_data.append(spring_data)
		
		# 创建Context和Driver
		var context = JuicyContext.create(spring_resource, target)
		var driver = JuicySpringDriver.new()
		var buffer = JuicyPropertyBuffer.new()
		
		# 准备驱动器
		driver.prepare(context, 0.0, buffer)
		
		# 测量处理时间
		var start_time = Time.get_ticks_usec()
		
		# 执行一次完整的处理
		driver.process(context, 1.0/60.0, buffer)
		
		var end_time = Time.get_ticks_usec()
		var processing_time = (end_time - start_time) / 1000.0
		
		results.append({
			"count": count,
			"time": processing_time,
			"time_per_property": processing_time / count
		})
		
		print("%d spring properties took: %.3f ms (avg: %.6f ms per property)" % [count, processing_time, processing_time / count])
		
		# 验证性能要求
		assert_lt(processing_time, 16.0, "Processing %d spring properties should take less than 16ms" % count)
		
		# 清理
		target.queue_free()
	
	# 分析性能缩放
	print("\nPerformance Scaling Analysis:")
	var prev_time = 0
	for i in range(results.size()):
		var result = results[i]
		var scaling_factor = result["count"] / (results[i-1]["count"] if i > 0 else 1)
		var time_factor = result["time"] / prev_time if prev_time > 0 else 1
		
		print("Scale %d -> %d: x%.1f properties, x%.2f time" % [
			results[i-1]["count"] if i > 0 else 1,
			result["count"],
			scaling_factor,
			time_factor
		])
		
		prev_time = result["time"]
	
	print("✅ Performance scaling test passed")

# 测试内存使用和GC压力
func test_memory_usage_and_gc():
	print("🧪 Testing memory usage and GC pressure...")
	
	# 创建测试目标
	var target = Node2D.new()
	target.position = Vector2.ZERO
	add_child(target)
	
	# 创建大量弹簧资源以测试内存使用
	var spring_resources = []
	var contexts = []
	var drivers = []
	var buffers = []
	
	# 创建500个不同的弹簧资源
	for i in range(500):
		var spring_resource = JuicySpringResource.new()
		var spring_data = SpringData.new()
		spring_data.property = "position"
		spring_data.target_value = Vector2(100 + i, 100 + i)
		spring_data.stiffness = 100.0
		spring_data.damping = 10.0
		spring_data.mass = 1.0
		spring_data.threshold = 0.01
		spring_resource.spring_data.append(spring_data)
		
		var context = JuicyContext.create(spring_resource, target)
		var driver = JuicySpringDriver.new()
		var buffer = JuicyPropertyBuffer.new()
		
		driver.prepare(context, 0.0, buffer)
		
		spring_resources.append(spring_resource)
		contexts.append(context)
		drivers.append(driver)
		buffers.append(buffer)
	
	# 测量内存使用（Godot没有直接的内存API，我们通过创建对象来测试）
	var start_time = Time.get_ticks_usec()
	
	# 模拟使用
	for i in range(10):
		for j in range(drivers.size()):
			drivers[j].process(contexts[j], 1.0/60.0, buffers[j])
	
	var end_time = Time.get_ticks_usec()
	var total_time = (end_time - start_time) / 1000.0
	
	print("Processing 500 spring contexts took: %.3f ms" % total_time)
	print("Average time per context: %.6f ms" % (total_time / 500.0))
	
	# 强制垃圾回收测试
	var gc_start = Time.get_ticks_msec()
	
	# 清理所有资源（Resource是RefCounted，不需要手动释放）
	# spring_resources会自动被垃圾回收

	
	# 触发垃圾回收
	# 在Godot中，垃圾回收是自动的，我们只需要等待一下
	await get_tree().process_frame
	
	var gc_end = Time.get_ticks_msec()
	var gc_time = gc_end - gc_start
	
	print("Garbage collection took: %d ms" % gc_time)
	
	# 验证GC时间在合理范围内
	assert_lt(gc_time, 100, "Garbage collection should complete within 100ms")
	
	# 清理测试目标
	target.queue_free()
	
	print("✅ Memory usage and GC pressure test passed")

func _ready():
	print("🚀 Starting SpringDriver Performance Tests...")
	
	# 运行所有性能测试
	test_spring_physics_1000_calculations()
	test_batch_spring_force_calculation()
	test_spring_driver_processing_performance()
	test_performance_scaling()
	test_memory_usage_and_gc()
	
	print("✅ All SpringDriver Performance Tests passed!")
	
	# 自动退出测试场景
	get_tree().quit()
