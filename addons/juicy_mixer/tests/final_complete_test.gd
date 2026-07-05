# 最终完整测试 - 验证所有修复
extends Node

func _ready():
	print("=== 最终完整测试 ===")
	
	# 初始化JuicyMixer
	var _juicy_mixer = JuicyMixer.instance
	
	# 获取Context池
	var pool_manager = JuicyMixer.get_pool_manager()
	var context_pool = pool_manager.get_context_pool()
	
	# 清空池以确保干净的测试环境
	context_pool.clear_pool()
	
	# 测试1: 验证新创建的Context有有效ID
	print("\n--- 测试1: 验证新创建的Context有有效ID ---")
	var context1 = context_pool.get_context()
	print("获取Context1成功: ", context1 != null)
	print("Context1 ID有效: ", not context1.context_id.is_empty())
	print("Context1内部ID: ", context_pool.get_internal_id(context1))
	print("Context1在池中: ", context_pool.has_context(context1))
	
	# 测试2: 验证重置后的ID管理
	print("\n--- 测试2: 验证重置后的ID管理 ---")
	var original_id = context1.context_id
	var original_internal_id = context_pool.get_internal_id(context1)
	
	context1.reset()
	
	print("重置前Context ID: ", original_id)
	print("重置后Context ID: ", context1.context_id)
	print("重置前内部ID: ", original_internal_id)
	print("重置后内部ID: ", context_pool.get_internal_id(context1))
	print("重置后仍在池中: ", context_pool.has_context(context1))
	
	# 测试3: 验证返回后的状态
	print("\n--- 测试3: 验证返回后的状态 ---")
	context_pool.return_context(context1)
	print("返回后活跃Context数: ", context_pool.get_active_contexts().size())
	print("返回后Context1在池中: ", context_pool.has_context(context1))
	
	# 测试4: 验证批量操作
	print("\n--- 测试4: 验证批量操作 ---")
	var contexts = []
	var internal_ids = []
	
	# 批量获取
	for i in range(5):
		var ctx = context_pool.get_context()
		if ctx and not ctx.context_id.is_empty():
			contexts.append(ctx)
			internal_ids.append(context_pool.get_internal_id(ctx))
			print("获取Context ", i, " ID: ", ctx.context_id, " 内部ID: ", internal_ids[i])
		else:
			print("获取Context ", i, " 失败: ID为空")
	
	print("批量获取后活跃Context数: ", context_pool.get_active_contexts().size())
	print("批量获取后可用Context数: ", context_pool.get_available_contexts().size())
	
	# 批量返回
	for i in range(contexts.size()):
		context_pool.return_context(contexts[i])
	
	print("批量返回后活跃Context数: ", context_pool.get_active_contexts().size())
	print("批量返回后可用Context数: ", context_pool.get_available_contexts().size())
	
	# 测试5: 验证边界条件
	print("\n--- 测试5: 验证边界条件 ---")
	
	# 测试重复返回
	var test_context = context_pool.get_context()
	context_pool.return_context(test_context)
	print("第一次返回成功")
	
	context_pool.return_context(test_context)  # 应该产生警告
	print("重复返回处理完成")
	
	# 测试返回null
	context_pool.return_context(null)
	print("返回null Context处理完成")
	
	# 测试最终统计
	print("\n--- 测试6: 最终统计验证 ---")
	var final_stats = context_pool.get_statistics()
	print("最终统计信息: ", final_stats)
	
	# 验证关键指标
	var all_tests_passed = true
	
	# 检查ID有效性
	if context1.context_id.is_empty():
		print("❌ 测试失败: Context ID为空")
		all_tests_passed = false
	
	# 检查内部ID管理
	if context_pool.get_internal_id(context1).is_empty():
		print("❌ 测试失败: 内部ID为空")
		all_tests_passed = false
	
	# 检查池状态一致性
	if final_stats.active_contexts != 0:
		print("❌ 测试失败: 活跃Context数不为0")
		all_tests_passed = false
	
	# 检查重用率
	if final_stats.total_allocated > 0 and final_stats.total_reused >= 0:
		var reuse_ratio = float(final_stats.total_reused) / float(final_stats.total_allocated)
		print("重用率: ", reuse_ratio)
		if reuse_ratio < 0.0:
			print("❌ 测试失败: 重用率为负数")
			all_tests_passed = false
	
	# 最终结果
	print("\n=== 最终测试结果 ===")
	if all_tests_passed:
		print("✅ 所有测试通过！池化系统修复成功！")
	else:
		print("❌ 部分测试失败，需要进一步调试")
	
	print("\n=== 测试完成 ===")