# 测试Context池修复
# 专门测试Context池的ID管理问题

extends Node

func _ready():
	print("=== 测试Context池修复 ===")
	
	# 初始化JuicyMixer
	var _juicy_mixer = JuicyMixer.instance
	
	# 获取Context池
	var pool_manager = JuicyMixer.get_pool_manager()
	var context_pool = pool_manager.get_context_pool()
	
	# 测试1: 基本的获取和返回
	print("\n--- 测试1: 基本获取和返回 ---")
	var context1 = context_pool.get_context()
	print("获取Context1 ID: ", context1.context_id)
	print("Context1内部ID: ", context_pool.get_internal_id(context1))
	print("活跃Context数: ", context_pool.get_active_contexts().size())
	
	context_pool.return_context(context1)
	print("返回后活跃Context数: ", context_pool.get_active_contexts().size())
	print("可用Context数: ", context_pool.get_available_contexts().size())
	
	# 测试2: 重置后的ID管理
	print("\n--- 测试2: 重置后的ID管理 ---")
	var context2 = context_pool.get_context()
	print("获取Context2 ID: ", context2.context_id)
	print("Context2内部ID: ", context_pool.get_internal_id(context2))
	print("活跃Context数: ", context_pool.get_active_contexts().size())
	
	# 重置Context（模拟长时间使用后的重置）
	var original_id = context2.context_id
	context2.reset()
	print("重置前Context2 ID: ", original_id)
	print("重置后Context2 ID: ", context2.context_id)
	print("重置后内部ID: ", context_pool.get_internal_id(context2))
	
	# 尝试返回重置后的Context
	context_pool.return_context(context2)
	print("返回重置Context后活跃Context数: ", context_pool.get_active_contexts().size())
	
	# 测试3: 重新获取重置的Context
	print("\n--- 测试3: 重新获取重置的Context ---")
	var context3 = context_pool.get_context()
	print("重新获取Context3 ID: ", context3.context_id)
	print("Context3内部ID: ", context_pool.get_internal_id(context3))
	print("活跃Context数: ", context_pool.get_active_contexts().size())
	
	# 测试4: 验证活跃列表管理
	print("\n--- 测试4: 验证活跃列表管理 ---")
	var contexts = []
	var internal_ids = []
	for i in range(3):
		var ctx = context_pool.get_context()
		if ctx:
			contexts.append(ctx)
			internal_ids.append(context_pool.get_internal_id(ctx))
			print("获取Context ", i, " ID: ", ctx.context_id, " 内部ID: ", internal_ids[i])
	
	print("总获取Context数: ", contexts.size())
	print("活跃Context数: ", context_pool.get_active_contexts().size())
	
	# 验证每个Context是否在池中
	for i in range(contexts.size()):
		var is_in_pool = context_pool.has_context(contexts[i])
		print("Context ", i, " 在池中: ", is_in_pool)
	
	# 返回所有Context
	for i in range(contexts.size()):
		context_pool.return_context(contexts[i])
	
	print("返回所有Context后活跃Context数: ", context_pool.get_active_contexts().size())
	print("可用Context数: ", context_pool.get_available_contexts().size())
	
	# 测试5: 统计信息验证
	print("\n--- 测试5: 统计信息验证 ---")
	var stats = context_pool.get_statistics()
	print("最终统计信息: ", stats)
	
	# 测试6: 详细状态信息
	print("\n--- 测试6: 详细状态信息 ---")
	var detailed_status = context_pool.get_detailed_status()
	print("详细状态: ", detailed_status)
	
	print("\n=== 测试完成 ===")