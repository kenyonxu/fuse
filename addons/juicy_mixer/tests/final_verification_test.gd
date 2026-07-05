# 最终验证测试 - 验证池化系统修复效果
extends Node

func _ready():
	print("=== 最终验证测试 ===")
	
	# 初始化JuicyMixer
	var _juicy_mixer = JuicyMixer.instance
	
	# 获取Context池
	var pool_manager = JuicyMixer.get_pool_manager()
	var context_pool = pool_manager.get_context_pool()
	
	# 清空池以确保干净的测试环境
	context_pool.clear_pool()
	
	# 测试1: 基本功能验证
	print("\n--- 测试1: 基本功能验证 ---")
	test_basic_functionality(context_pool)
	
	# 测试2: ID管理验证
	print("\n--- 测试2: ID管理验证 ---")
	test_id_management(context_pool)
	
	# 测试3: 高频操作验证
	print("\n--- 测试3: 高频操作验证 ---")
	test_high_frequency_operations(context_pool)
	
	# 测试4: 边界条件验证
	print("\n--- 测试4: 边界条件验证 ---")
	test_edge_cases(context_pool)
	
	# 最终统计
	print("\n--- 最终统计 ---")
	var final_stats = context_pool.get_statistics()
	print("最终统计信息: ", final_stats)
	
	print("\n=== 验证测试完成 ===")

func test_basic_functionality(context_pool: JuicyContextPool) -> void:
	# 获取Context
	var context1 = context_pool.get_context()
	print("获取Context1成功: ", context1 != null)
	print("Context1 ID有效: ", not context1.context_id.is_empty())
	print("活跃Context数: ", context_pool.get_active_contexts().size())
	print("Context1在池中: ", context_pool.has_context(context1))
	
	# 返回Context
	context_pool.return_context(context1)
	print("返回后活跃Context数: ", context_pool.get_active_contexts().size())
	print("Context1在池中: ", context_pool.has_context(context1))

func test_id_management(context_pool: JuicyContextPool) -> void:
	var context = context_pool.get_context()
	var original_id = context.context_id
	var internal_id = context_pool.get_internal_id(context)
	
	print("原始Context ID: ", original_id)
	print("内部ID: ", internal_id)
	
	# 重置Context
	context.reset()
	print("重置后Context ID: ", context.context_id)
	print("重置后内部ID: ", context_pool.get_internal_id(context))
	print("重置后仍在池中: ", context_pool.has_context(context))
	
	# 返回重置后的Context
	context_pool.return_context(context)
	print("返回后活跃Context数: ", context_pool.get_active_contexts().size())

func test_high_frequency_operations(context_pool: JuicyContextPool) -> void:
	var contexts = []
	var operation_count = 10
	
	print("执行 ", operation_count, " 次获取/返回操作")
	
	# 批量获取
	for i in range(operation_count):
		var ctx = context_pool.get_context()
		contexts.append(ctx)
	
	print("获取 ", operation_count, " 个Context后活跃数: ", context_pool.get_active_contexts().size())
	
	# 批量返回
	for i in range(operation_count):
		context_pool.return_context(contexts[i])
	
	print("返回 ", operation_count, " 个Context后活跃数: ", context_pool.get_active_contexts().size())
	
	# 验证所有Context都不在活跃列表
	var all_returned = true
	for i in range(operation_count):
		if context_pool.has_context(contexts[i]):
			all_returned = false
			break
	
	print("所有Context已正确返回: ", all_returned)

func test_edge_cases(context_pool: JuicyContextPool) -> void:
	# 测试重复返回同一个Context
	var context = context_pool.get_context()
	context_pool.return_context(context)
	
	print("第一次返回成功")
	
	# 尝试再次返回（应该产生警告但不崩溃）
	context_pool.return_context(context)
	print("重复返回处理完成")
	
	# 测试返回null Context
	context_pool.return_context(null)
	print("返回null Context处理完成")
	
	# 测试获取大量Context
	var many_contexts = []
	for i in range(20):
		var ctx = context_pool.get_context()
		if ctx:
			many_contexts.append(ctx)
	
	print("获取20个Context成功: ", many_contexts.size() == 20)
	print("活跃Context数: ", context_pool.get_active_contexts().size())
	
	# 清理
	for ctx in many_contexts:
		context_pool.return_context(ctx)
	
	print("清理后活跃Context数: ", context_pool.get_active_contexts().size())