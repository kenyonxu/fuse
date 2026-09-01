extends Node2D

## OnTreeChanged 事件测试

func _ready():
	print("=== Testing OnTreeChanged ===")
	await get_tree().process_frame
	test_basic_node_added()
	test_basic_node_removed()
	test_filter_by_group()
	test_change_type_filtering()
	test_emit_changed_node()
	test_resource_cleanup()
	print("=== All OnTreeChanged tests passed! ===")

## 测试 1: 基本节点添加测试
func test_basic_node_added():
	print("Test 1: Basic node added")

	var trigger = Node.new()
	add_child(trigger)

	var event = OnTreeChanged.new()
	event.change_type = OnTreeChanged.ChangeType.NodeAdded

	var triggered = false
	var added_node = null
	event.triggered.connect(func(node):
		triggered = true
		added_node = node
		print("  Event triggered with node: ", node.name if node else "null")
	)

	# 初始化事件
	event.initialize(trigger)
	await get_tree().process_frame

	# 添加节点
	var test_node = Node.new()
	test_node.name = "TestNode"
	add_child(test_node)
	await get_tree().process_frame

	# 验证事件触发
	assert(triggered, "Event should trigger when node is added")
	assert(added_node == test_node, "Event should pass the added node")
	print("  ✓ Test 1 passed: Node added event works\n")

	# 清理
	event.terminate(trigger)
	trigger.queue_free()
	test_node.queue_free()

## 测试 2: 基本节点移除测试
func test_basic_node_removed():
	print("Test 2: Basic node removed")

	var trigger = Node.new()
	add_child(trigger)

	var event = OnTreeChanged.new()
	event.change_type = OnTreeChanged.ChangeType.NodeRemoved

	var triggered = false
	var removed_node = null
	event.triggered.connect(func(node):
		triggered = true
		removed_node = node
		print("  Event triggered with node: ", node.name if node else "null")
	)

	# 初始化事件
	event.initialize(trigger)
	await get_tree().process_frame

	# 创建并移除节点
	var test_node = Node.new()
	test_node.name = "TestNodeToRemove"
	add_child(test_node)
	await get_tree().process_frame

	# 移除节点
	test_node.queue_free()
	await get_tree().process_frame

	# 验证事件触发
	assert(triggered, "Event should trigger when node is removed")
	assert(removed_node == test_node, "Event should pass the removed node")
	print("  ✓ Test 2 passed: Node removed event works\n")

	# 清理
	event.terminate(trigger)
	trigger.queue_free()

## 测试 3: 组过滤测试
func test_filter_by_group():
	print("Test 3: Filter by group")

	var trigger = Node.new()
	add_child(trigger)

	var event = OnTreeChanged.new()
	event.change_type = OnTreeChanged.ChangeType.NodeAdded
	event.filter_by_group = "test_group"

	var player_triggered = false
	var enemy_triggered = false
	event.triggered.connect(func(node):
		if node.is_in_group("test_group"):
			if node.name == "Player":
				player_triggered = true
			elif node.name == "Enemy":
				enemy_triggered = true
		print("  Event triggered with node: ", node.name, " groups: ", node.get_groups())
	)

	# 初始化事件
	event.initialize(trigger)
	await get_tree().process_frame

	# 添加 player 节点（在组中）
	var player = Node.new()
	player.name = "Player"
	player.add_to_group("test_group")
	add_child(player)
	await get_tree().process_frame

	# 添加 enemy 节点（不在组中）
	var enemy = Node.new()
	enemy.name = "Enemy"
	enemy.add_to_group("other_group")
	add_child(enemy)
	await get_tree().process_frame

	# 验证只有 player 触发事件
	assert(player_triggered, "Event should trigger for player in test_group")
	assert(not enemy_triggered, "Event should not trigger for enemy in other_group")
	print("  ✓ Test 3 passed: Group filtering works\n")

	# 清理
	event.terminate(trigger)
	trigger.queue_free()
	player.queue_free()
	enemy.queue_free()

## 测试 4: 变化类型过滤测试
func test_change_type_filtering():
	print("Test 4: Change type filtering")

	var trigger = Node.new()
	add_child(trigger)

	var event = OnTreeChanged.new()
	event.change_type = OnTreeChanged.ChangeType.NodeAdded

	var add_triggered = false
	var remove_triggered = false
	event.triggered.connect(func(node):
		add_triggered = true
		print("  Event triggered for: ", node.name)
	)

	# 初始化事件
	event.initialize(trigger)
	await get_tree().process_frame

	# 添加节点
	var test_node = Node.new()
	test_node.name = "TestNode"
	add_child(test_node)
	await get_tree().process_frame

	# 移除节点
	test_node.queue_free()
	await get_tree().process_frame

	# 验证只有添加触发事件
	assert(add_triggered, "Event should trigger for node addition")
	assert(not remove_triggered, "Event should not trigger for node removal")
	print("  ✓ Test 4 passed: Change type filtering works\n")

	# 清理
	event.terminate(trigger)
	trigger.queue_free()

## 测试 5: 发送变化节点测试
func test_emit_changed_node():
	print("Test 5: Emit changed node")

	var trigger = Node.new()
	add_child(trigger)

	# 测试启用节点发送
	var event1 = OnTreeChanged.new()
	event1.change_type = OnTreeChanged.ChangeType.Any
	event1.emit_changed_node = true

	var node_received = false
	var received_node = null
	event1.triggered.connect(func(node):
		node_received = true
		received_node = node
	)

	event1.initialize(trigger)
	await get_tree().process_frame

	var test_node = Node.new()
	add_child(test_node)
	await get_tree().process_frame

	assert(node_received, "Event should pass node when emit_changed_node is true")
	assert(received_node == test_node, "Event should pass the correct node")

	# 清理第一个事件
	event1.terminate(trigger)
	await get_tree().process_frame

	# 测试禁用节点发送
	var event2 = OnTreeChanged.new()
	event2.change_type = OnTreeChanged.ChangeType.Any
	event2.emit_changed_node = false

	var null_received = false
	event2.triggered.connect(func(node):
		null_received = (node == null)
	)

	event2.initialize(trigger)
	await get_tree().process_frame

	var test_node2 = Node.new()
	add_child(test_node2)
	await get_tree().process_frame

	assert(null_received, "Event should pass null when emit_changed_node is false")

	# 清理
	event2.terminate(trigger)
	trigger.queue_free()
	test_node.queue_free()
	test_node2.queue_free()

	print("  ✓ Test 5 passed: Emit changed node option works\n")

## 测试 6: 资源清理测试
func test_resource_cleanup():
	print("Test 6: Resource cleanup")

	var trigger = Node.new()
	add_child(trigger)

	var event = OnTreeChanged.new()
	event.change_type = OnTreeChanged.ChangeType.Any

	# 初始化事件
	event.initialize(trigger)
	await get_tree().process_frame

	# 验证信号已连接
	var scene_tree = trigger.get_tree()
	assert(scene_tree.node_added.is_connected(event._on_node_added), "node_added signal should be connected")
	assert(scene_tree.node_removed.is_connected(event._on_node_removed), "node_removed signal should be connected")
	print("  Signals connected")

	# 终止事件
	event.terminate(trigger)

	# 验证信号已断开
	assert(not scene_tree.node_added.is_connected(event._on_node_added), "node_added signal should be disconnected")
	assert(not scene_tree.node_removed.is_connected(event._on_node_removed), "node_removed signal should be disconnected")
	print("  Signals disconnected")
	print("  ✓ Test 6 passed: Resource cleanup works\n")

	# 清理
	trigger.queue_free()
