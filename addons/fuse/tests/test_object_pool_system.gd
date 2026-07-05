extends Node

## Fuse 对象池系统测试场景
##
## 测试对象池的创建、实例化、回收和统计功能

func _ready():
	print("\n=== Fuse 对象池系统测试 ===\n")
	_run_all_tests()

func _run_all_tests():
	# 测试 1: 基础池管理器测试
	test_pool_manager_singleton()

	# 测试 2: 对象池创建和预热
	test_pool_creation_and_warmup()

	# 测试 3: 对象获取和回收
	test_object_get_and_return()

	# 测试 4: 池统计
	test_pool_statistics()

	# 测试 5: 非池化实例化对比
	test_non_pooled_instantiation()

	print("\n=== 所有测试完成 ===")

## 测试 1: 基础池管理器测试
func test_pool_manager_singleton():
	print("\n--- 测试 1: 池管理器单例 ---")

	var pool_manager = FusePoolManager.get_instance()
	if pool_manager:
		print("✅ 池管理器单例获取成功")
	else:
		print("❌ 池管理器单例获取失败")

## 测试 2: 对象池创建和预热
func test_pool_creation_and_warmup():
	print("\n--- 测试 2: 池创建和预热 ---")

	var test_scene_path = "res://test_objects/bullet.tscn"
	var pool_manager = FusePoolManager.get_instance()

	# 预热池（假设场景路径）
	print("预热池: ", test_scene_path)
	pool_manager.warm_up_pool(test_scene_path, 5)

	print("✅ 池预热完成")

## 测试 3: 对象获取和回收
func test_object_get_and_return():
	print("\n--- 测试 3: 对象获取和回收 ---")

	var test_scene_path = "res://test_objects/bullet.tscn"
	var pool_manager = FusePoolManager.get_instance()

	# 创建一个测试父节点
	var test_parent = Node2D.new()
	test_parent.name = "TestParent"
	add_child(test_parent)

	# 获取对象（假设场景存在）
	print("从池中获取对象...")
	var instance = pool_manager.instantiate_pooled(test_scene_path, test_parent)

	if instance:
		print("✅ 对象获取成功: ", instance.name)
		print("对象类型: ", instance.get_class())
	else:
		print("❌ 对象获取失败（可能场景路径不存在）")

	# 等待几帧然后回收
	if instance:
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame

		print("回收对象到池...")
		pool_manager.recycle_pooled(test_scene_path, instance)
		print("✅ 对象已回收")

	# 清理
	test_parent.queue_free()

## 测试 4: 池统计
func test_pool_statistics():
	print("\n--- 测试 4: 池统计 ---")

	var pool_manager = FusePoolManager.get_instance()
	var all_stats = pool_manager.get_statistics()

	print("所有池的统计信息:")
	for scene_path in all_stats:
		var stats = all_stats[scene_path]
		if stats is Dictionary:
			print("\n场景: ", scene_path)
			print("  总创建: ", stats.total_created)
			print("  总复用: ", stats.total_reused)
			print("  池大小: ", stats.pool_size)
			print("  当前使用: ", stats.current_usage)
			print("  峰值使用: ", stats.peak_usage)
			if stats.has("reuse_ratio"):
				print("  复用率: ", "%.1f%%" % (stats.reuse_ratio * 100))

## 测试 5: 非池化实例化对比
func test_non_pooled_instantiation():
	print("\n--- 测试 5: 非池化实例化对比 ---")

	var test_scene_path = "res://test_objects/bullet.tscn"
	var iterations = 10

	# 创建测试父节点
	var test_parent = Node2D.new()
	test_parent.name = "TestParent"
	add_child(test_parent)

	# 测试非池化实例化
	var start_time = Time.get_ticks_msec()
	for i in range(iterations):
		var packed = load(test_scene_path)
		if packed and packed is PackedScene:
			var instance = packed.instantiate()
			if instance:
				test_parent.add_child(instance)
				instance.queue_free()

		await get_tree().process_frame

	var non_pooled_time = Time.get_ticks_msec() - start_time
	print("非池化 %d 次实例化用时: %d ms" % [iterations, non_pooled_time])

	# 清理
	for child in test_parent.get_children():
		child.queue_free()

	test_parent.queue_free()
	await get_tree().process_frame

	# 启用池化测试
	print("\n启用池化模式测试...")
	var pool_manager = FusePoolManager.get_instance()
	pool_manager.warm_up_pool(test_scene_path, 10)

	await get_tree().process_frame

	start_time = Time.get_ticks_msec()
	for i in range(iterations):
		var instance = pool_manager.instantiate_pooled(test_scene_path, test_parent)
		if instance:
			pool_manager.recycle_pooled(test_scene_path, instance)

		await get_tree().process_frame

	var pooled_time = Time.get_ticks_msec() - start_time
	print("池化 %d 次实例化用时: %d ms" % [iterations, pooled_time])

	# 计算性能提升
	if pooled_time > 0:
		var improvement = float(non_pooled_time - pooled_time) / non_pooled_time * 100
		print("\n✅ 性能提升: %.1f%%" % improvement)
	else:
		print("\n⚠️  池化测试无效（场景可能不存在）")

	# 清理
	for child in test_parent.get_children():
		child.queue_free()

	test_parent.queue_free()

## 测试完成
func _on_tests_completed():
	print("\n=== 所有测试完成 ===")

	# 输出最终状态
	var pool_manager = FusePoolManager.get_instance()
	var status = pool_manager.get_detailed_status()
	print("\n最终池状态:")
	print("  总池数: ", status.total_pools)
	print("  场景路径: ", status.scene_paths)
