# 简单的弹簧驱动器测试
# 验证基本功能是否正常工作

extends Node

func _ready():
	print("🧪 开始测试 JuicySpringDriver...")
	
	# 创建测试节点
	var target_node = Node2D.new()
	target_node.position = Vector2.ZERO
	
	# 创建缓冲区
	var buffer = JuicyPropertyBuffer.new()
	
	# 创建驱动器
	var driver = JuicySpringDriver.new()
	
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
	var context = JuicyContext.create(resource, target_node)
	context.set_driver_data("spring_data", spring_data)
	
	# 验证驱动器创建
	check_assert(driver != null, "驱动器创建成功")
	check_assert(driver.driver_name == "JuicySpringDriver", "驱动器名称正确")
	
	# 验证上下文验证
	var validation = driver.validate_context(context)
	print("验证结果: ", validation)
	check_assert(validation.valid, "上下文验证通过")
	
	# 准备驱动器
	driver.prepare(context, 0.0, buffer)
	print("✓ 驱动器准备完成")
	
	# 测试几帧弹簧效果
	var start_pos = target_node.position
	print("初始位置: ", start_pos)
	
	# 模拟5帧
	for i in range(5):
		var delta = 1.0 / 60.0
		context.progress = i * delta
		driver.process(context, delta, buffer)
		buffer.flush_all_samples()
		print("第", i+1, "帧位置: ", target_node.position)
	
	# 验证位置有变化（弹簧开始运动）
	var end_pos = target_node.position
	check_assert(end_pos != start_pos, "位置发生了变化")
	check_assert(end_pos.x > start_pos.x, "向目标位置移动")
	
	# 测试稳定性查询
	var is_stable = driver.is_spring_stable(context, "position")
	print("弹簧稳定状态: ", is_stable)
	
	# 清理
	driver.cleanup(context)
	
	# 释放资源
	context.free()
	driver.free()
	buffer.free()
	target_node.free()
	
	print("✅ JuicySpringDriver 基本测试通过!")

# 简单的断言函数
func check_assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("测试失败: " + message)
	else:
		print("✓ " + message)