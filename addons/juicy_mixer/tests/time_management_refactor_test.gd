# 时间管理重构测试脚本
# 用于验证重构后的驱动器功能是否正常

extends Node

func _ready():
	print("=== 时间管理重构测试开始 ===")
	_run_tests()

func _run_tests():
	# 测试 TweenDriver
	_test_tween_driver()
	
	# 测试 ShakeDriver
	_test_shake_driver()
	
	# 测试 SpringDriver
	_test_spring_driver()
	
	print("=== 时间管理重构测试完成 ===")

func _test_tween_driver():
	print("\n--- 测试 TweenDriver ---")
	
	# 创建补间资源
	var tween_resource = JuicyTweenResource.new()
	var tween_data = tween_resource.add_tween_data("position", Vector2.ZERO, Vector2(100, 100), 1.0)
	
	# 创建测试节点
	var test_node = Node2D.new()
	add_child(test_node)
	
	# 创建上下文
	var context = JuicyContext.create(tween_resource, test_node)
	
	# 设置驱动器数据
	context.set_driver_data("tween_data", tween_resource.tween_data)
	
	# 创建驱动器
	var driver = JuicyTweenDriver.new()
	
	# 测试验证
	var validation = driver.validate_context(context)
	print("TweenDriver 验证结果: ", validation.valid)
	if not validation.valid:
		print("验证问题: ", validation.issues)
		return
	
	# 创建缓冲区
	var buffer = JuicyPropertyBuffer.new()
	
	# 准备阶段
	driver.prepare(context, 0.016, buffer)
	print("TweenDriver 准备完成")
	
	# 模拟几帧处理
	for i in range(5):
		driver.process(context, 0.016, buffer)
		var progress = driver.get_tween_progress(context, "position")
		print("帧 ", i + 1, " 进度: ", progress)
		
		if driver.is_tween_complete(context, "position"):
			print("TweenDriver 在帧 ", i + 1, " 完成")
			break
	
	# 清理
	driver.cleanup(context)
	print("TweenDriver 清理完成")

func _test_shake_driver():
	print("\n--- 测试 ShakeDriver ---")
	
	# 创建震动资源
	var shake_resource = JuicyShakeResource.new()
	var shake_data = shake_resource.add_shake_data("position", 10.0, 10.0, 1.0)
	
	# 创建测试节点
	var test_node = Node2D.new()
	add_child(test_node)
	
	# 创建上下文
	var context = JuicyContext.create(shake_resource, test_node)
	
	# 设置驱动器数据
	context.set_driver_data("shake_data", shake_resource.shake_data)
	
	# 创建驱动器
	var driver = JuicyShakeDriver.new()
	
	# 测试验证
	var validation = driver.validate_context(context)
	print("ShakeDriver 验证结果: ", validation.valid)
	if not validation.valid:
		print("验证问题: ", validation.issues)
		return
	
	# 创建缓冲区
	var buffer = JuicyPropertyBuffer.new()
	
	# 准备阶段
	driver.prepare(context, 0.016, buffer)
	print("ShakeDriver 准备完成")
	
	# 模拟几帧处理
	for i in range(5):
		driver.process(context, 0.016, buffer)
		var progress = driver.get_shake_progress(context, "position")
		print("帧 ", i + 1, " 进度: ", progress)
		
		if driver.is_shake_complete(context, "position"):
			print("ShakeDriver 在帧 ", i + 1, " 完成")
			break
	
	# 清理
	driver.cleanup(context)
	print("ShakeDriver 清理完成")

func _test_spring_driver():
	print("\n--- 测试 SpringDriver ---")
	
	# 创建弹簧资源
	var spring_resource = JuicySpringResource.new()
	var spring_data = spring_resource.add_spring_data("position", Vector2(50, 50), 100.0, 10.0, 1.0)
	
	# 创建测试节点
	var test_node = Node2D.new()
	add_child(test_node)
	
	# 创建上下文
	var context = JuicyContext.create(spring_resource, test_node)
	
	# 设置驱动器数据
	context.set_driver_data("spring_data", spring_resource.spring_data)
	
	# 创建驱动器
	var driver = JuicySpringDriver.new()
	
	# 测试验证
	var validation = driver.validate_context(context)
	print("SpringDriver 验证结果: ", validation.valid)
	if not validation.valid:
		print("验证问题: ", validation.issues)
		return
	
	# 创建缓冲区
	var buffer = JuicyPropertyBuffer.new()
	
	# 准备阶段
	driver.prepare(context, 0.016, buffer)
	print("SpringDriver 准备完成")
	
	# 模拟几帧处理
	for i in range(20):  # 弹簧需要更多帧来稳定
		driver.process(context, 0.016, buffer)
		var offset = driver.get_spring_offset(context, "position")
		print("帧 ", i + 1, " 偏移: ", offset)
		
		if driver.is_spring_stable(context, "position"):
			print("SpringDriver 在帧 ", i + 1, " 稳定")
			break
	
	# 清理
	driver.cleanup(context)
	print("SpringDriver 清理完成")
