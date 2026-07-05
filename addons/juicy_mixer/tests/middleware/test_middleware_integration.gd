# 测试中间件系统集成
# 验证中间件管道与JuicyDirector的正确集成

extends Node

# 测试用的中间件
class MyTestMiddleware extends JuicyMiddleware:
	func _init():
		middleware_name = "MyTestMiddleware"
		priority = 10
		description = "测试中间件"
		print("[DEBUG] MyTestMiddleware initialized")
	
	func process(context: JuicyContext, next: Callable) -> bool:
		print("[MyTestMiddleware] 处理Context: ", context.context_id)
		
		# 修改context数据以验证中间件影响
		if not context.has_method("get_middleware_data"):
			print("[DEBUG] Context missing middleware data methods")
			return next.call()
		
		if not context.has_middleware_data("MyTestMiddleware"):
			context.set_middleware_data("MyTestMiddleware", "test_count", 0)
		
		var count = context.get_middleware_data("MyTestMiddleware", "test_count", 0)
		context.set_middleware_data("MyTestMiddleware", "test_count", count + 1)
		
		# 继续执行链
		return next.call()
	
	func on_context_created(context: JuicyContext) -> void:
		print("[MyTestMiddleware] Context创建: ", context.context_id)
	
	func on_context_destroyed(context: JuicyContext) -> void:
		print("[MyTestMiddleware] Context销毁: ", context.context_id)

# 验证中间件
class TestValidationMiddleware extends JuicyMiddleware:
	func _init():
		middleware_name = "TestValidationMiddleware"
		priority = 5  # 更高优先级，先执行
		description = "验证中间件"
		print("[DEBUG] TestValidationMiddleware initialized")
	
	func process(context: JuicyContext, next: Callable) -> bool:
		print("[TestValidationMiddleware] 验证Context: ", context.context_id)
		
		# 简单的验证逻辑
		if not context.resource or not context.target:
			print("[TestValidationMiddleware] 验证失败: 缺少必需数据")
			return false
		
		# 继续执行链
		return next.call()

var test_resource: Resource
var test_target: Node

func _ready():
	print("=== 开始中间件集成测试 ===")
	
	# 创建测试资源 - 使用具体的反馈资源
	test_resource = TestFeedbackResource.new()
	test_resource.resource_type = "test"
	test_resource.duration = 1.0
	
	# 创建测试目标节点
	test_target = Node.new()
	test_target.name = "TestTarget"
	add_child(test_target)
	
	# 运行测试
	test_middleware_pipeline_integration()
	test_context_lifecycle_hooks()
	test_middleware_performance_stats()
	
	print("=== 中间件集成测试完成 ===")

func test_middleware_pipeline_integration():
	print("\n--- 测试中间件管道集成 ---")
	
	# 获取中间件管道
	var pipeline = JuicyMixer.get_middleware_pipeline()
	if not pipeline:
		print("错误: 无法获取中间件管道")
		return
	
	# 创建并添加测试中间件
	var test_middleware = MyTestMiddleware.new()
	var validation_middleware = TestValidationMiddleware.new()
	
	print("[DEBUG] Created test middleware: ", test_middleware.get_class())
	print("[DEBUG] Created validation middleware: ", validation_middleware.get_class())
	
	# 添加中间件到管道
	var add_result1 = JuicyMixer.add_middleware(test_middleware)
	var add_result2 = JuicyMixer.add_middleware(validation_middleware)
	
	print("添加测试中间件: ", "成功" if add_result1 else "失败")
	print("添加验证中间件: ", "成功" if add_result2 else "失败")
	
	# 验证中间件是否存在
	var has_test = pipeline.has_method("has_middleware") and pipeline.has_middleware("MyTestMiddleware")
	var has_validation = pipeline.has_method("has_middleware") and pipeline.has_middleware("TestValidationMiddleware")
	
	print("测试中间件存在: ", "是" if has_test else "否")
	print("验证中间件存在: ", "是" if has_validation else "否")
	
	# 测试播放效果
	print("\n测试播放效果:")
	var context_id = JuicyMixer.play(test_resource, test_target)
	
	if context_id and not context_id.is_empty():
		print("播放成功，Context ID: ", context_id)
		
		# 验证Context数据
		var context = JuicyMixer.get_context(context_id)
		if context and context.has_middleware_data("MyTestMiddleware"):
			var count = context.get_middleware_data("MyTestMiddleware", "test_count", 0)
			print("中间件处理次数: ", count)
		else:
			print("警告: 未找到中间件测试数据")
		
		# 停止效果
		JuicyMixer.stop(context_id)
		print("效果已停止")
	else:
		print("播放失败")

func test_context_lifecycle_hooks():
	print("\n--- 测试Context生命周期钩子 ---")
	
	# 创建新的测试中间件来验证生命周期钩子
	var lifecycle_middleware = MyTestMiddleware.new()
	lifecycle_middleware.middleware_name = "LifecycleTestMiddleware"
	
	# 添加到管道
	JuicyMixer.add_middleware(lifecycle_middleware)
	
	# 创建并播放效果
	var context_id = JuicyMixer.play(test_resource, test_target)
	
	if context_id and not context_id.is_empty():
		# 暂停效果
		print("暂停效果:")
		JuicyMixer.pause(context_id)
		
		# 恢复效果
		print("恢复效果:")
		JuicyMixer.resume(context_id)
		
		# 停止效果（触发销毁钩子）
		print("停止效果:")
		JuicyMixer.stop(context_id)
	
	# 移除测试中间件
	JuicyMixer.remove_middleware("LifecycleTestMiddleware")

func test_middleware_performance_stats():
	print("\n--- 测试中间件性能统计 ---")
	
	# 获取性能统计
	var stats = JuicyMixer.get_middleware_performance_stats()
	
	print("管道性能统计:")
	if stats.has("pipeline_stats"):
		var pipeline_stats = stats.pipeline_stats
		print("  执行次数: ", pipeline_stats.get("execution_count", 0))
		print("  总执行时间: ", pipeline_stats.get("total_execution_time", 0.0), "ms")
		print("  平均执行时间: ", pipeline_stats.get("average_execution_time", 0.0), "ms")
		print("  错误次数: ", pipeline_stats.get("error_count", 0))
	
	print("中间件性能统计:")
	if stats.has("middleware_stats"):
		for middleware_stat in stats.middleware_stats:
			print("  中间件: ", middleware_stat.get("middleware_name", "Unknown"))
			print("    执行次数: ", middleware_stat.get("execution_count", 0))
			print("    平均执行时间: ", middleware_stat.get("average_execution_time", 0.0), "ms")
			print("    错误次数: ", middleware_stat.get("error_count", 0))

func _exit_tree():
	# 清理测试节点
	if test_target and is_instance_valid(test_target):
		test_target.queue_free()
