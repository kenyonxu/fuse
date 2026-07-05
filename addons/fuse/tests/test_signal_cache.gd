extends Node

## SignalManager LRU 缓存测试
##
## 测试 SignalManager 的 LRU 缓存过期机制

func test_signal_cache_with_lru():
	print("=== 开始 LRU 缓存测试 ===")

	var node1 = Node.new()
	node1.name = "Node1"
	var node2 = Node.new()
	node2.name = "Node2"
	var node3 = Node.new()
	node3.name = "Node3"

	# 获取信号（应该被缓存）
	var signals1 = SignalManager.get_node_signals(node1)
	var signals2 = SignalManager.get_node_signals(node2)

	# 获取缓存统计
	var stats = SignalManager.get_cache_stats()
	print("初始缓存统计:")
	print("  缓存节点数: %d" % stats.cached_nodes)
	print("  总信号数: %d" % stats.total_signals)

	# 验证缓存大小
	assert(stats.cached_nodes == 2, "预期 2 个缓存节点，得到 %d" % stats.cached_nodes)

	print("✓ LRU 缓存基础测试通过")

	# 清理特定节点缓存
	SignalManager.clear_cache_for_node(node1)
	stats = SignalManager.get_cache_stats()
	print("\n清理 node1 后:")
	print("  缓存节点数: %d" % stats.cached_nodes)
	assert(stats.cached_nodes == 1, "预期 1 个缓存节点，得到 %d" % stats.cached_nodes)

	print("✓ 单节点清理测试通过")

	# 清理所有缓存
	SignalManager.clear_all_cache()
	stats = SignalManager.get_cache_stats()
	print("\n清理所有缓存后:")
	print("  缓存节点数: %d" % stats.cached_nodes)
	print("  总信号数: %d" % stats.total_signals)
	assert(stats.cached_nodes == 0, "预期 0 个缓存节点，得到 %d" % stats.cached_nodes)
	assert(stats.total_signals == 0, "预期 0 个总信号，得到 %d" % stats.total_signals)

	print("✓ 全部清理测试通过")

	# 测试重复获取不会增加缓存大小
	var signals1_again = SignalManager.get_node_signals(node1)
	var signals2_again = SignalManager.get_node_signals(node2)
	stats = SignalManager.get_cache_stats()
	print("\n重复获取后:")
	print("  缓存节点数: %d" % stats.cached_nodes)
	assert(stats.cached_nodes == 2, "预期 2 个缓存节点（LRU 不重复），得到 %d" % stats.cached_nodes)

	print("✓ 重复获取测试通过")

	# 清理资源
	node1.queue_free()
	node2.queue_free()
	node3.queue_free()

	print("\n=== LRU 缓存测试完成 ===")

func test_cache_eviction():
	print("\n=== 开始缓存驱逐测试 ===")

	var nodes = []
	for i in range(105):  # 超过假设的最大缓存大小 100
		var node = Node.new()
		node.name = "TestNode_%d" % i
		nodes.append(node)

	# 获取 105 个节点的信号（应该触发 LRU 驱逐）
	for node in nodes:
		SignalManager.get_node_signals(node)

	var stats = SignalManager.get_cache_stats()
	print("获取 105 个节点信号后:")
	print("  缓存节点数: %d" % stats.cached_nodes)
	print("  总信号数: %d" % stats.total_signals)

	# 应该只保留最近的 100 个节点（LRU 策略）
	# 注意：这里假设最大缓存大小为 100
	assert(stats.cached_nodes <= 100, "缓存节点数应该不超过最大缓存大小")

	print("✓ 缓存驱逐测试通过")

	# 清理
	SignalManager.clear_all_cache()
	for node in nodes:
		node.queue_free()

	print("\n=== 缓存驱逐测试完成 ===")

func test_cache_performance():
	print("\n=== 开始缓存性能测试 ===")

	var nodes = []
	for i in range(10):
		var node = Node.new()
		node.name = "PerfNode_%d" % i
		nodes.append(node)

	# 预热缓存
	for node in nodes:
		SignalManager.get_node_signals(node)

	# 性能测试：获取信号 10000 次
	var iterations = 10000
	var start_time = Time.get_ticks_msec()

	for i in range(iterations):
		SignalManager.get_node_signals(nodes[i % nodes.size()])

	var elapsed = Time.get_ticks_msec() - start_time
	var ops_per_ms = float(iterations) / float(elapsed)

	print("缓存查询性能: %.2f ops/ms (%.2f ms for %d lookups)" % [ops_per_ms, elapsed, iterations])
	print("  目标: > 500 ops/ms")

	if ops_per_ms > 500:
		print("✓ 性能目标达成")
	else:
		push_warning("⚠ 性能低于目标 %.2f ops/ms < 500" % ops_per_ms)

	# 清理
	SignalManager.clear_all_cache()
	for node in nodes:
		node.queue_free()

	print("\n=== 缓存性能测试完成 ===")
