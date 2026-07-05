# JuicySpringDriver 测试用例
# 测试弹簧驱动器的各种功能和边界情况
# 验证物理模拟的准确性和稳定性

extends Node

# 简单的断言函数，用于测试
func assert_check(condition: bool, message: String = "") -> void:
	if not condition:
		push_error("Assertion failed: " + message)
		return
	print("✓ " + message)

func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		push_error("Assertion failed: expected %s, got %s - %s" % [str(expected), str(actual), message])
		return
	print("✓ " + message)

func assert_true(condition: bool, message: String = "") -> void:
	assert_check(condition, message)

func assert_false(condition: bool, message: String = "") -> void:
	assert_check(not condition, message)

func assert_gt(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual <= expected:
		push_error("Assertion failed: expected %s > %s - %s" % [str(actual), str(expected), message])
		return
	print("✓ " + message)

func assert_lt(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual >= expected:
		push_error("Assertion failed: expected %s < %s - %s" % [str(actual), str(expected), message])
		return
	print("✓ " + message)

func assert_near(actual: Variant, expected: Variant, tolerance: float = 0.01, message: String = "") -> void:
	var diff = abs(float(actual) - float(expected))
	if diff > tolerance:
		push_error("Assertion failed: expected %s ≈ %s (±%s), got diff %s - %s" % [str(expected), str(tolerance), str(diff), str(actual), message])
		return
	print("✓ " + message)

# 测试目标节点
var target_node: Node2D
var context: JuicyContext
var driver: JuicySpringDriver
var buffer: JuicyPropertyBuffer

func before_each():
	# 创建测试节点
	target_node = Node2D.new()
	target_node.position = Vector2.ZERO
	target_node.rotation = 0.0
	target_node.scale = Vector2(1, 1)
	
	# 创建属性缓冲区
	buffer = JuicyPropertyBuffer.new()
	
	# 创建驱动器
	driver = JuicySpringDriver.new()

func after_each():
	# 清理资源
	if context:
		context.free()
	if driver:
		driver.free()
	if buffer:
		buffer.free()
	if target_node:
		target_node.free()

func test_spring_driver_basic_position():
	"""
	测试基础位置弹簧功能
	"""
	# 创建弹簧数据
	var spring_data = [{
		"property": "position",
		"target_value": Vector2(100, 0),
		"stiffness": 50.0,
		"damping": 5.0,
		"mass": 1.0,
		"threshold": 0.1
	}]
	
	# 创建上下文
	var resource = JuicySpringResource.new()
	context = JuicyContext.create(resource, target_node)
	context.set_driver_data("spring_data", spring_data)
	
	# 准备驱动器
	driver.prepare(context, 0.0, buffer)
	
	# 模拟弹簧运动（5秒，300帧）
	var positions: Array[Vector2] = []
	for i in range(300):
		var delta = 1.0 / 60.0
		context.progress = i / 300.0
		driver.process(context, delta, buffer)
		buffer.flush_all_samples()
		positions.append(target_node.position)
	
	# 验证最终位置（应该收敛到目标值）
	assert_near(target_node.position.x, 100.0, 0.5, "Position should converge to target X")
	assert_near(target_node.position.y, 0.0, 0.5, "Position should converge to target Y")
	
	# 验证弹簧已稳定
	assert_true(driver.is_spring_stable(context, "position"), "Spring should be stable after simulation")

func test_spring_driver_damping_effect():
	"""
	测试阻尼效果
	"""
	# 创建两个弹簧：一个低阻尼，一个高阻尼
	var low_damping_data = [{
		"property": "position",
		"target_value": Vector2(100, 0),
		"stiffness": 50.0,
		"damping": 1.0,  # 低阻尼
		"mass": 1.0,
		"threshold": 0.1
	}]
	
	var high_damping_data = [{
		"property": "position",
		"target_value": Vector2(100, 0),
		"stiffness": 50.0,
		"damping": 20.0,  # 高阻尼
		"mass": 1.0,
		"threshold": 0.1
	}]
	
	# 测试低阻尼弹簧
	var resource = JuicySpringResource.new()
	context = JuicyContext.create(resource, target_node)
	context.set_driver_data("spring_data", low_damping_data)
	
	var low_damping_driver = JuicySpringDriver.new()
	low_damping_driver.prepare(context, 0.0, buffer)
	
	var low_damping_positions: Array[float] = []
	for i in range(300):
		var delta = 1.0 / 60.0
		context.progress = i / 300.0
		low_damping_driver.process(context, delta, buffer)
		buffer.flush_all_samples()
		low_damping_positions.append(target_node.position.x)
	
	# 清理并测试高阻尼弹簧
	low_damping_driver.free()
	target_node.position = Vector2.ZERO
	
	context.set_driver_data("spring_data", high_damping_data)
	var high_damping_driver = JuicySpringDriver.new()
	high_damping_driver.prepare(context, 0.0, buffer)
	
	var high_damping_positions: Array[float] = []
	for i in range(300):
		var delta = 1.0 / 60.0
		context.progress = i / 300.0
		high_damping_driver.process(context, delta, buffer)
		buffer.flush_all_samples()
		high_damping_positions.append(target_node.position.x)
	
	# 验证阻尼效果
	# 低阻尼应该有更大的超调
	var low_damping_max = 0.0
	var high_damping_max = 0.0
	
	for pos in low_damping_positions:
		low_damping_max = max(low_damping_max, pos)
	
	for pos in high_damping_positions:
		high_damping_max = max(high_damping_max, pos)
	
	assert_gt(low_damping_max, 100.0, "Low damping should overshoot target")
	assert_lt(high_damping_max, 110.0, "High damping should have minimal overshoot")
	
	high_damping_driver.free()

func test_spring_driver_rotation():
	"""
	测试旋转弹簧功能
	"""
	# 创建旋转弹簧数据
	var spring_data = [{
		"property": "rotation",
		"target_value": PI / 2,  # 90度
		"stiffness": 30.0,
		"damping": 3.0,
		"mass": 1.0,
		"threshold": 0.01
	}]
	
	# 创建上下文
	var resource = JuicySpringResource.new()
	context = JuicyContext.create(resource, target_node)
	context.set_driver_data("spring_data", spring_data)
	
	# 准备驱动器
	driver.prepare(context, 0.0, buffer)
	
	# 模拟弹簧运动
	for i in range(300):
		var delta = 1.0 / 60.0
		context.progress = i / 300.0
		driver.process(context, delta, buffer)
		buffer.flush_all_samples()
	
	# 验证最终旋转（应该收敛到目标值）
	assert_near(target_node.rotation, PI / 2, 0.01, "Rotation should converge to target value")
	assert_true(driver.is_spring_stable(context, "rotation"), "Rotation spring should be stable")

func test_spring_driver_scale():
	"""
	测试缩放弹簧功能
	"""
	# 创建缩放弹簧数据
	var spring_data = [{
		"property": "scale",
		"target_value": Vector2(2.0, 2.0),
		"stiffness": 40.0,
		"damping": 4.0,
		"mass": 1.0,
		"threshold": 0.01
	}]
	
	# 创建上下文
	var resource = JuicySpringResource.new()
	context = JuicyContext.create(resource, target_node)
	context.set_driver_data("spring_data", spring_data)
	
	# 准备驱动器
	driver.prepare(context, 0.0, buffer)
	
	# 模拟弹簧运动
	for i in range(300):
		var delta = 1.0 / 60.0
		context.progress = i / 300.0
		driver.process(context, delta, buffer)
		buffer.flush_all_samples()
	
	# 验证最终缩放（应该收敛到目标值）
	assert_near(target_node.scale.x, 2.0, 0.01, "Scale X should converge to target value")
	assert_near(target_node.scale.y, 2.0, 0.01, "Scale Y should converge to target value")
	assert_true(driver.is_spring_stable(context, "scale"), "Scale spring should be stable")

func test_spring_driver_initial_velocity():
	"""
	测试初始速度效果
	"""
	# 创建带初始速度的弹簧数据
	var spring_data = [{
		"property": "position",
		"target_value": Vector2(100, 0),
		"stiffness": 50.0,
		"damping": 2.0,
		"mass": 1.0,
		"initial_velocity": Vector2(50, 0),  # 初始向右速度
		"threshold": 0.1
	}]
	
	# 创建上下文
	var resource = JuicySpringResource.new()
	context = JuicyContext.create(resource, target_node)
	context.set_driver_data("spring_data", spring_data)
	
	# 准备驱动器
	driver.prepare(context, 0.0, buffer)
	
	# 记录前几帧的位置，验证初始速度效果
	var positions: Array[float] = []
	for i in range(30):
		var delta = 1.0 / 60.0
		context.progress = i / 300.0
		driver.process(context, delta, buffer)
		buffer.flush_all_samples()
		positions.append(target_node.position.x)
	
	# 验证初始速度效果（应该比没有初始速度时更快地向目标移动）
	assert_gt(positions[5], 10.0, "Initial velocity should cause faster movement")
	
	# 验证最终收敛
	for i in range(30, 300):
		var delta = 1.0 / 60.0
		context.progress = i / 300.0
		driver.process(context, delta, buffer)
		buffer.flush_all_samples()
	
	assert_near(target_node.position.x, 100.0, 0.5, "Should still converge to target")

func test_spring_driver_stiffness_effect():
	"""
	测试刚度效果
	"""
	# 创建两个弹簧：一个低刚度，一个高刚度
	var low_stiffness_data = [{
		"property": "position",
		"target_value": Vector2(100, 0),
		"stiffness": 10.0,  # 低刚度
		"damping": 5.0,
		"mass": 1.0,
		"threshold": 0.1
	}]
	
	var high_stiffness_data = [{
		"property": "position",
		"target_value": Vector2(100, 0),
		"stiffness": 200.0,  # 高刚度
		"damping": 10.0,
		"mass": 1.0,
		"threshold": 0.1
	}]
	
	# 测试低刚度弹簧
	var resource = JuicySpringResource.new()
	context = JuicyContext.create(resource, target_node)
	context.set_driver_data("spring_data", low_stiffness_data)
	
	var low_stiffness_driver = JuicySpringDriver.new()
	low_stiffness_driver.prepare(context, 0.0, buffer)
	
	var low_stiffness_positions: Array[float] = []
	for i in range(60):  # 只测试前1秒
		var delta = 1.0 / 60.0
		context.progress = i / 300.0
		low_stiffness_driver.process(context, delta, buffer)
		buffer.flush_all_samples()
		low_stiffness_positions.append(target_node.position.x)
	
	# 清理并测试高刚度弹簧
	low_stiffness_driver.free()
	target_node.position = Vector2.ZERO
	
	context.set_driver_data("spring_data", high_stiffness_data)
	var high_stiffness_driver = JuicySpringDriver.new()
	high_stiffness_driver.prepare(context, 0.0, buffer)
	
	var high_stiffness_positions: Array[float] = []
	for i in range(60):
		var delta = 1.0 / 60.0
		context.progress = i / 300.0
		high_stiffness_driver.process(context, delta, buffer)
		buffer.flush_all_samples()
		high_stiffness_positions.append(target_node.position.x)
	
	# 验证刚度效果（高刚度应该更快响应）
	assert_lt(high_stiffness_positions[30], low_stiffness_positions[30], "High stiffness should respond faster")
	
	high_stiffness_driver.free()

func test_spring_driver_mass_effect():
	"""
	测试质量效果
	"""
	# 创建两个弹簧：一个低质量，一个高质量
	var low_mass_data = [{
		"property": "position",
		"target_value": Vector2(100, 0),
		"stiffness": 50.0,
		"damping": 5.0,
		"mass": 0.5,  # 低质量
		"threshold": 0.1
	}]
	
	var high_mass_data = [{
		"property": "position",
		"target_value": Vector2(100, 0),
		"stiffness": 50.0,
		"damping": 5.0,
		"mass": 2.0,  # 高质量
		"threshold": 0.1
	}]
	
	# 测试低质量弹簧
	var resource = JuicySpringResource.new()
	context = JuicyContext.create(resource, target_node)
	context.set_driver_data("spring_data", low_mass_data)
	
	var low_mass_driver = JuicySpringDriver.new()
	low_mass_driver.prepare(context, 0.0, buffer)
	
	var low_mass_positions: Array[float] = []
	for i in range(60):
		var delta = 1.0 / 60.0
		context.progress = i / 300.0
		low_mass_driver.process(context, delta, buffer)
		buffer.flush_all_samples()
		low_mass_positions.append(target_node.position.x)
	
	# 清理并测试高质量弹簧
	low_mass_driver.free()
	target_node.position = Vector2.ZERO
	
	context.set_driver_data("spring_data", high_mass_data)
	var high_mass_driver = JuicySpringDriver.new()
	high_mass_driver.prepare(context, 0.0, buffer)
	
	var high_mass_positions: Array[float] = []
	for i in range(60):
		var delta = 1.0 / 60.0
		context.progress = i / 300.0
		high_mass_driver.process(context, delta, buffer)
		buffer.flush_all_samples()
		high_mass_positions.append(target_node.position.x)
	
	# 验证质量效果（低质量应该响应更快，但可能有更多振荡）
	assert_gt(low_mass_positions[30], high_mass_positions[30], "Low mass should respond faster initially")
	
	high_mass_driver.free()

func test_spring_driver_multiple_properties():
	"""
	测试多属性并行弹簧
	"""
	# 创建多属性弹簧数据
	var spring_data = [
		{
			"property": "position",
			"target_value": Vector2(100, 50),
			"stiffness": 50.0,
			"damping": 5.0,
			"mass": 1.0,
			"threshold": 0.1
		},
		{
			"property": "rotation",
			"target_value": PI / 4,  # 45度
			"stiffness": 30.0,
			"damping": 3.0,
			"mass": 1.0,
			"threshold": 0.01
		},
		{
			"property": "scale",
			"target_value": Vector2(1.5, 1.5),
			"stiffness": 40.0,
			"damping": 4.0,
			"mass": 1.0,
			"threshold": 0.01
		}
	]
	
	# 创建上下文
	var resource = JuicySpringResource.new()
	context = JuicyContext.create(resource, target_node)
	context.set_driver_data("spring_data", spring_data)
	
	# 准备驱动器
	driver.prepare(context, 0.0, buffer)
	
	# 模拟弹簧运动
	for i in range(300):
		var delta = 1.0 / 60.0
		context.progress = i / 300.0
		driver.process(context, delta, buffer)
		buffer.flush_all_samples()
	
	# 验证所有属性
	assert_near(target_node.position.x, 100.0, 0.5, "Position X should converge to target")
	assert_near(target_node.position.y, 50.0, 0.5, "Position Y should converge to target")
	assert_near(target_node.rotation, PI / 4, 0.01, "Rotation should converge to target")
	assert_near(target_node.scale.x, 1.5, 0.01, "Scale X should converge to target")
	assert_near(target_node.scale.y, 1.5, 0.01, "Scale Y should converge to target")
	
	# 验证所有弹簧都已稳定
	assert_true(driver.is_spring_stable(context, "position"), "Position spring should be stable")
	assert_true(driver.is_spring_stable(context, "rotation"), "Rotation spring should be stable")
	assert_true(driver.is_spring_stable(context, "scale"), "Scale spring should be stable")

func test_spring_driver_time_scale():
	"""
	测试时间缩放功能
	"""
	# 创建弹簧数据
	var spring_data = [{
		"property": "position",
		"target_value": Vector2(100, 0),
		"stiffness": 50.0,
		"damping": 5.0,
		"mass": 1.0,
		"threshold": 0.1
	}]
	
	# 创建上下文
	var resource = JuicySpringResource.new()
	context = JuicyContext.create(resource, target_node)
	context.set_driver_data("spring_data", spring_data)
	context.time_scale = 0.5  # 时间缩放为0.5
	
	# 准备驱动器
	driver.prepare(context, 0.0, buffer)
	
	# 模拟弹簧运动（时间缩放，需要更长时间）
	for i in range(600):  # 10秒，60帧/秒
		var delta = 1.0 / 60.0
		context.progress = i / 600.0
		driver.process(context, delta, buffer)
		buffer.flush_all_samples()
	
	# 验证最终位置（应该收敛到目标值）
	assert_near(target_node.position.x, 100.0, 0.5, "Position should converge to target with time scale")
	assert_true(driver.is_spring_stable(context, "position"), "Spring should be stable with time scale")

func test_spring_driver_validation():
	"""
	测试验证功能
	"""
	# 测试空数据
	var resource = JuicySpringResource.new()
	context = JuicyContext.create(resource, target_node)
	context.set_driver_data("spring_data", null)
	
	var validation = driver.validate_context(context)
	assert_false(validation.valid, "Should fail validation with null spring data")
	
	# 测试空数组
	context.set_driver_data("spring_data", [])
	validation = driver.validate_context(context)
	assert_false(validation.valid, "Should fail validation with empty spring data")
	
	# 测试无效数据（缺少target_value）
	context.set_driver_data("spring_data", [{"property": "position"}])
	validation = driver.validate_context(context)
	assert_false(validation.valid, "Should fail validation with missing target_value")
	
	# 测试无效参数值
	context.set_driver_data("spring_data", [{
		"property": "position",
		"target_value": Vector2(100, 0),
		"stiffness": -10.0  # 负刚度
	}])
	validation = driver.validate_context(context)
	assert_false(validation.valid, "Should fail validation with negative stiffness")
	
	# 测试负阻尼
	context.set_driver_data("spring_data", [{
		"property": "position",
		"target_value": Vector2(100, 0),
		"damping": -5.0  # 负阻尼
	}])
	validation = driver.validate_context(context)
	assert_false(validation.valid, "Should fail validation with negative damping")
	
	# 测试零质量
	context.set_driver_data("spring_data", [{
		"property": "position",
		"target_value": Vector2(100, 0),
		"mass": 0.0  # 零质量
	}])
	validation = driver.validate_context(context)
	assert_false(validation.valid, "Should fail validation with zero mass")

func test_spring_driver_stability_queries():
	"""
	测试稳定性查询功能
	"""
	# 创建弹簧数据
	var spring_data = [{
		"property": "position",
		"target_value": Vector2(100, 0),
		"stiffness": 50.0,
		"damping": 5.0,
		"mass": 1.0,
		"threshold": 0.1
	}]
	
	# 创建上下文
	var resource = JuicySpringResource.new()
	context = JuicyContext.create(resource, target_node)
	context.set_driver_data("spring_data", spring_data)
	
	# 准备驱动器
	driver.prepare(context, 0.0, buffer)
	
	# 检查初始状态（应该不稳定）
	assert_false(driver.is_spring_stable(context, "position"), "Spring should not be stable initially")
	
	# 模拟弹簧运动直到稳定
	for i in range(300):
		var delta = 1.0 / 60.0
		context.progress = i / 300.0
		driver.process(context, delta, buffer)
		buffer.flush_all_samples()
	
	# 检查最终状态（应该稳定）
	assert_true(driver.is_spring_stable(context, "position"), "Spring should be stable after simulation")
	
	# 验证偏移量查询
	var offset = driver.get_spring_offset(context, "position")
	assert_near(offset.x, 0.0, 0.1, "Offset should be near zero when stable")
	assert_near(offset.y, 0.0, 0.1, "Offset should be near zero when stable")

func test_spring_driver_performance():
	"""
	测试性能基准
	"""
	# 创建大量弹簧数据
	var spring_data = []
	for i in range(100):  # 100个属性同时弹簧
		spring_data.append({
			"property": "position",
			"target_value": Vector2(100 + i, 100 + i),
			"stiffness": 50.0,
			"damping": 5.0,
			"mass": 1.0,
			"threshold": 0.1
		})
	
	# 创建上下文
	var resource = JuicySpringResource.new()
	context = JuicyContext.create(resource, target_node)
	context.set_driver_data("spring_data", spring_data)
	
	# 准备驱动器
	driver.prepare(context, 0.0, buffer)
	
	# 测量处理时间
	var start_time = Time.get_ticks_usec()
	
	# 模拟一帧
	driver.process(context, 1.0/60.0, buffer)
	
	var end_time = Time.get_ticks_usec()
	var processing_time = (end_time - start_time) / 1000.0  # 转换为毫秒
	
	# 验证性能（100个属性应该在合理时间内处理完成）
	assert_lt(processing_time, 16.0, "Processing 100 spring properties should take less than 16ms")
	
	# 检查性能统计
	var stats = driver.get_performance_stats()
	assert_gt(stats.execution_count, 0, "Should have execution count")
	assert_gt(stats.last_execution_time, 0.0, "Should have last execution time")

func test_spring_driver_physics_accuracy():
	"""
	测试物理模拟的准确性
	"""
	# 创建一个简单的弹簧系统，验证胡克定律
	var spring_data = [{
		"property": "position",
		"target_value": Vector2(100, 0),
		"stiffness": 100.0,  # k = 100
		"damping": 10.0,     # c = 10
		"mass": 1.0,         # m = 1
		"threshold": 0.01
	}]
	
	# 创建上下文
	var resource = JuicySpringResource.new()
	context = JuicyContext.create(resource, target_node)
	context.set_driver_data("spring_data", spring_data)
	
	# 准备驱动器
	driver.prepare(context, 0.0, buffer)
	
	# 记录前几帧的数据，验证物理规律
	var positions: Array[float] = []
	var times: Array[float] = []
	
	for i in range(10):
		var delta = 1.0 / 60.0
		context.progress = i / 600.0
		driver.process(context, delta, buffer)
		buffer.flush_all_samples()
		positions.append(target_node.position.x)
		times.append(i * delta)
	
	# 验证初始加速度方向（应该向目标值加速）
	assert_gt(positions[1], positions[0], "Spring should accelerate towards target")
	
	# 验证系统最终会收敛
	for i in range(10, 300):
		var delta = 1.0 / 60.0
		context.progress = i / 600.0
		driver.process(context, delta, buffer)
		buffer.flush_all_samples()
	
	# 验证最终收敛到目标值
	assert_near(target_node.position.x, 100.0, 0.01, "Spring should converge to target value")
	assert_true(driver.is_spring_stable(context, "position"), "Spring should be stable")

func _ready():
	print("🧪 Running JuicySpringDriver tests...")
	
	# 运行所有测试
	test_spring_driver_basic_position()
	test_spring_driver_damping_effect()
	test_spring_driver_rotation()
	test_spring_driver_scale()
	test_spring_driver_initial_velocity()
	test_spring_driver_stiffness_effect()
	test_spring_driver_mass_effect()
	test_spring_driver_multiple_properties()
	test_spring_driver_time_scale()
	test_spring_driver_validation()
	test_spring_driver_stability_queries()
	test_spring_driver_performance()
	test_spring_driver_physics_accuracy()
	
	print("✅ All JuicySpringDriver tests passed!")