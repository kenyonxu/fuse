# JuicyTweenDriver 测试用例
# 测试补间驱动器的各种功能和边界情况

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
	assert(condition, message)

func assert_false(condition: bool, message: String = "") -> void:
	assert(not condition, message)

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

# 测试目标节点
var target_node: Node2D
var context: JuicyContext
var driver: JuicyTweenDriver
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
	driver = JuicyTweenDriver.new()

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

func test_tween_driver_basic_position():
	"""
	测试基础位置补间功能
	"""
	# 创建补间数据
	var tween_data = [{
		"property": "position",
		"from_value": Vector2.ZERO,
		"to_value": Vector2(100, 100),
		"duration": 1.0,
		"ease_type": Tween.EASE_IN_OUT,
		"trans_type": Tween.TRANS_LINEAR
	}]
	
	# 创建上下文
	var resource = JuicyTweenResource.new()
	context = JuicyContext.create(resource, target_node)
	context.set_driver_data("tween_data", tween_data)
	
	# 准备驱动器
	driver.prepare(context, 0.0, buffer)
	
	# 模拟1秒的补间动画（60帧）
	for i in range(60):
		var delta = 1.0 / 60.0
		context.progress = i / 60.0
		driver.process(context, delta, buffer)
		buffer.flush_all_samples()
	
	# 验证最终位置
	assert_eq(target_node.position, Vector2(100, 100), "Position should reach target value")

func test_tween_driver_relative_values():
	"""
	测试相对值补间功能
	"""
	# 设置初始位置
	target_node.position = Vector2(50, 50)
	
	# 创建相对补间数据
	var tween_data = [{
		"property": "position",
		"from_value": Vector2.ZERO,  # 这个值会被忽略，因为是相对模式
		"to_value": Vector2(30, 20),
		"duration": 1.0,
		"relative": true
	}]
	
	# 创建上下文
	var resource = JuicyTweenResource.new()
	context = JuicyContext.create(resource, target_node)
	context.set_driver_data("tween_data", tween_data)
	
	# 准备驱动器
	driver.prepare(context, 0.0, buffer)
	
	# 模拟补间动画
	for i in range(60):
		var delta = 1.0 / 60.0
		context.progress = i / 60.0
		driver.process(context, delta, buffer)
		buffer.flush_all_samples()
	
	# 验证最终位置（初始值 + 相对值）
	assert_eq(target_node.position, Vector2(80, 70), "Position should be initial + relative value")

func test_tween_driver_delay():
	"""
	测试延迟功能
	"""
	# 创建带延迟的补间数据
	var tween_data = [{
		"property": "position",
		"from_value": Vector2.ZERO,
		"to_value": Vector2(100, 0),
		"duration": 0.5,
		"delay": 0.5  # 0.5秒延迟
	}]
	
	# 创建上下文
	var resource = JuicyTweenResource.new()
	context = JuicyContext.create(resource, target_node)
	context.set_driver_data("tween_data", tween_data)
	
	# 准备驱动器
	driver.prepare(context, 0.0, buffer)
	
	# 前0.5秒应该没有变化（30帧）
	for i in range(30):
		var delta = 1.0 / 60.0
		context.progress = i / 60.0
		driver.process(context, delta, buffer)
		buffer.flush_all_samples()
		assert_eq(target_node.position, Vector2.ZERO, "Position should not change during delay")
	
	# 后0.5秒应该有变化（30帧）
	for i in range(30, 60):
		var delta = 1.0 / 60.0
		context.progress = i / 60.0
		driver.process(context, delta, buffer)
		buffer.flush_all_samples()
	
	# 验证最终位置
	assert_eq(target_node.position, Vector2(100, 0), "Position should reach target after delay")

func test_tween_driver_multiple_properties():
	"""
	测试多属性并行补间
	"""
	# 创建多属性补间数据
	var tween_data = [
		{
			"property": "position",
			"from_value": Vector2.ZERO,
			"to_value": Vector2(100, 100),
			"duration": 1.0
		},
		{
			"property": "rotation",
			"from_value": 0.0,
			"to_value": PI,
			"duration": 1.0
		},
		{
			"property": "scale",
			"from_value": Vector2(1, 1),
			"to_value": Vector2(2, 2),
			"duration": 1.0
		}
	]
	
	# 创建上下文
	var resource = JuicyTweenResource.new()
	context = JuicyContext.create(resource, target_node)
	context.set_driver_data("tween_data", tween_data)
	
	# 准备驱动器
	driver.prepare(context, 0.0, buffer)
	
	# 模拟补间动画
	for i in range(60):
		var delta = 1.0 / 60.0
		context.progress = i / 60.0
		driver.process(context, delta, buffer)
		buffer.flush_all_samples()
	
	# 验证所有属性
	assert_eq(target_node.position, Vector2(100, 100), "Position should reach target")
	assert_eq(target_node.rotation, PI, "Rotation should reach target")
	assert_eq(target_node.scale, Vector2(2, 2), "Scale should reach target")

func test_tween_driver_color_interpolation():
	"""
	测试颜色插值
	"""
	# 创建颜色补间数据
	var tween_data = [{
		"property": "modulate",
		"from_value": Color.RED,
		"to_value": Color.BLUE,
		"duration": 1.0
	}]
	
	# 创建上下文
	var resource = JuicyTweenResource.new()
	context = JuicyContext.create(resource, target_node)
	context.set_driver_data("tween_data", tween_data)
	
	# 准备驱动器
	driver.prepare(context, 0.0, buffer)
	
	# 模拟补间动画
	for i in range(60):
		var delta = 1.0 / 60.0
		context.progress = i / 60.0
		driver.process(context, delta, buffer)
		buffer.flush_all_samples()
	
	# 验证最终颜色
	assert_eq(target_node.modulate, Color.BLUE, "Color should reach target value")

func test_tween_driver_easing_functions():
	"""
	测试不同的缓动函数
	"""
	# 测试不同的缓动类型
	var ease_types = [Tween.EASE_IN, Tween.EASE_OUT, Tween.EASE_IN_OUT]
	var trans_types = [Tween.TRANS_LINEAR, Tween.TRANS_SINE, Tween.TRANS_QUAD]
	
	for ease_type in ease_types:
		for trans_type in trans_types:
			# 重置目标
			target_node.position = Vector2.ZERO
			
			# 创建补间数据
			var tween_data = [{
				"property": "position",
				"from_value": Vector2.ZERO,
				"to_value": Vector2(100, 0),
				"duration": 1.0,
				"ease_type": ease_type,
				"trans_type": trans_type
			}]
			
			# 创建上下文
			var resource = JuicyTweenResource.new()
			context = JuicyContext.create(resource, target_node)
			context.set_driver_data("tween_data", tween_data)
			
			# 准备驱动器
			driver.prepare(context, 0.0, buffer)
			
			# 模拟补间动画
			for i in range(60):
				var delta = 1.0 / 60.0
				context.progress = i / 60.0
				driver.process(context, delta, buffer)
				buffer.flush_all_samples()
			
			# 验证最终位置
			assert_eq(target_node.position.x, 100.0, "Position should reach target with easing %s, %s" % [ease_type, trans_type])

func test_tween_driver_time_scale():
	"""
	测试时间缩放功能
	"""
	# 创建补间数据
	var tween_data = [{
		"property": "position",
		"from_value": Vector2.ZERO,
		"to_value": Vector2(100, 0),
		"duration": 1.0
	}]
	
	# 创建上下文
	var resource = JuicyTweenResource.new()
	context = JuicyContext.create(resource, target_node)
	context.set_driver_data("tween_data", tween_data)
	context.time_scale = 0.5  # 时间缩放为0.5
	
	# 准备驱动器
	driver.prepare(context, 0.0, buffer)
	
	# 模拟补间动画（时间缩放，需要2秒）
	for i in range(120):  # 120帧 = 2秒
		var delta = 1.0 / 60.0
		context.progress = i / 120.0
		driver.process(context, delta, buffer)
		buffer.flush_all_samples()
	
	# 验证最终位置
	assert_eq(target_node.position.x, 100.0, "Position should reach target with time scale")

func test_tween_driver_validation():
	"""
	测试验证功能
	"""
	# 测试空数据
	var resource = JuicyTweenResource.new()
	context = JuicyContext.create(resource, target_node)
	context.set_driver_data("tween_data", null)
	
	var validation = driver.validate_context(context)
	assert_false(validation.valid, "Should fail validation with null tween data")
	
	# 测试空数组
	context.set_driver_data("tween_data", [])
	validation = driver.validate_context(context)
	assert_false(validation.valid, "Should fail validation with empty tween data")
	
	# 测试无效数据
	context.set_driver_data("tween_data", [{"invalid": "data"}])
	validation = driver.validate_context(context)
	assert_false(validation.valid, "Should fail validation with invalid tween data")

func test_tween_driver_progress_queries():
	"""
	测试进度查询功能
	"""
	# 创建补间数据
	var tween_data = [{
		"property": "position",
		"from_value": Vector2.ZERO,
		"to_value": Vector2(100, 0),
		"duration": 1.0
	}]
	
	# 创建上下文
	var resource = JuicyTweenResource.new()
	context = JuicyContext.create(resource, target_node)
	context.set_driver_data("tween_data", tween_data)
	
	# 准备驱动器
	driver.prepare(context, 0.0, buffer)
	
	# 检查初始进度
	assert_eq(driver.get_tween_progress(context, "position"), 0.0, "Initial progress should be 0")
	assert_false(driver.is_tween_complete(context, "position"), "Tween should not be complete initially")
	
	# 模拟半秒动画
	for i in range(30):
		var delta = 1.0 / 60.0
		context.progress = i / 60.0
		driver.process(context, delta, buffer)
		buffer.flush_all_samples()
	
	# 检查中期进度
	var mid_progress = driver.get_tween_progress(context, "position")
	assert_gt(mid_progress, 0.0, "Mid progress should be greater than 0")
	assert_lt(mid_progress, 1.0, "Mid progress should be less than 1")
	assert_false(driver.is_tween_complete(context, "position"), "Tween should not be complete at mid point")
	
	# 模拟完整动画
	for i in range(30, 60):
		var delta = 1.0 / 60.0
		context.progress = i / 60.0
		driver.process(context, delta, buffer)
		buffer.flush_all_samples()
	
	# 检查最终进度
	assert_eq(driver.get_tween_progress(context, "position"), 1.0, "Final progress should be 1")
	assert_true(driver.is_tween_complete(context, "position"), "Tween should be complete")

func test_tween_driver_performance():
	"""
	测试性能基准
	"""
	# 创建大量补间数据
	var tween_data = []
	for i in range(100):  # 100个属性同时补间
		tween_data.append({
			"property": "position",
			"from_value": Vector2.ZERO,
			"to_value": Vector2(100 + i, 100 + i),
			"duration": 1.0
		})
	
	# 创建上下文
	var resource = JuicyTweenResource.new()
	context = JuicyContext.create(resource, target_node)
	context.set_driver_data("tween_data", tween_data)
	
	# 准备驱动器
	driver.prepare(context, 0.0, buffer)
	
	# 测量处理时间
	var start_time = Time.get_ticks_usec()
	
	# 模拟一帧
	driver.process(context, 1.0/60.0, buffer)
	
	var end_time = Time.get_ticks_usec()
	var processing_time = (end_time - start_time) / 1000.0  # 转换为毫秒
	
	# 验证性能（100个属性应该在合理时间内处理完成）
	assert_lt(processing_time, 16.0, "Processing 100 properties should take less than 16ms")
	
	# 检查性能统计
	var stats = driver.get_performance_stats()
	assert_gt(stats.execution_count, 0, "Should have execution count")
	assert_gt(stats.last_execution_time, 0.0, "Should have last execution time")

func _ready():
	print("🧪 Running JuicyTweenDriver tests...")
	
	# 运行所有测试
	test_tween_driver_basic_position()
	test_tween_driver_relative_values()
	test_tween_driver_delay()
	test_tween_driver_multiple_properties()
	test_tween_driver_color_interpolation()
	test_tween_driver_easing_functions()
	test_tween_driver_time_scale()
	test_tween_driver_validation()
	test_tween_driver_progress_queries()
	test_tween_driver_performance()
	
	print("✅ All JuicyTweenDriver tests passed!")