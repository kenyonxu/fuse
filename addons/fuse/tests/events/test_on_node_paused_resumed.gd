extends Node

## OnNodePausedResumed 事件测试

func _ready():
	print("=== Testing OnNodePausedResumed ===")

	# 基本功能测试
	await test_basic_functionality()

	# 触发时机测试
	await test_trigger_on_paused()
	await test_trigger_on_resumed()
	await test_trigger_on_both()

	# 边界情况测试
	await test_edge_cases()

	print("=== All OnNodePausedResumed tests passed! ===")

## 基本功能测试
func test_basic_functionality():
	print("\n[Test 1] Basic functionality")

	# 创建事件
	var event_script = load("res://addons/fuse/events/scene/on_node_paused_resumed.gd")
	var event = event_script.new()
	event.target_node = ^"../TargetNode"
	event.trigger_on = event.TriggerOn.Both
	event.check_interval = 0.1

	# 创建 Trigger 节点
	var trigger = Node.new()
	trigger.name = "Trigger"
	add_child(trigger)

	# 创建目标节点
	var target_node = Node.new()
	target_node.name = "TargetNode"
	trigger.add_child(target_node)

	# 连接事件信号
	var triggered_count = 0
	var trigger_contexts = []

	event.triggered.connect(func(context):
		triggered_count += 1
		trigger_contexts.append(context)
		print("  ✓ Event triggered! Count: %d, Type: %s" % [triggered_count, context.get_meta("trigger_type")])
	)

	# 初始化事件
	event.initialize(trigger)
	await get_tree().process_frame

	# 等待一小段时间确保定时器开始工作
	await get_tree().create_timer(0.2).timeout

	# 修改目标节点的 process_mode
	print("  - Changing process_mode to DISABLED...")
	target_node.process_mode = Node.ProcessMode.PROCESS_MODE_DISABLED

	# 等待事件触发
	await get_tree().create_timer(0.3).timeout

	assert(triggered_count > 0, "Event should trigger when process_mode changes")
	assert(trigger_contexts.size() > 0, "Should have trigger context")

	var last_context = trigger_contexts[-1]
	assert(last_context.has_meta("trigger_type"), "Context should have trigger_type")
	assert(last_context.has_meta("old_process_mode"), "Context should have old_process_mode")
	assert(last_context.has_meta("new_process_mode"), "Context should have new_process_mode")

	print("  ✓ Test 1 passed: Event triggered correctly with context")

	# 清理
	event.terminate(trigger)
	trigger.queue_free()
	await get_tree().process_frame

## 测试仅在暂停时触发
func test_trigger_on_paused():
	print("\n[Test 2] Trigger on paused only")

	var event_script = load("res://addons/fuse/events/scene/on_node_paused_resumed.gd")
	var event = event_script.new()
	event.target_node = ^"../TargetNode"
	event.trigger_on = event.TriggerOn.Paused
	event.check_interval = 0.1

	var trigger = Node.new()
	trigger.name = "Trigger2"
	add_child(trigger)

	var target_node = Node.new()
	target_node.name = "TargetNode"
	trigger.add_child(target_node)

	var paused_triggered = false
	var resumed_triggered = false

	event.triggered.connect(func(context):
		var trigger_type = context.get_meta("trigger_type")
		if trigger_type == "paused":
			paused_triggered = true
			print("  ✓ Paused triggered")
		elif trigger_type == "resumed":
			resumed_triggered = true
			print("  ✗ Resumed triggered (should not happen)")

		assert(trigger_type == "paused", "Should only trigger on paused")
	)

	event.initialize(trigger)
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout

	# 暂停节点
	target_node.process_mode = Node.ProcessMode.PROCESS_MODE_DISABLED
	await get_tree().create_timer(0.3).timeout

	assert(paused_triggered, "Should trigger on paused")
	assert(not resumed_triggered, "Should not trigger on resumed")

	print("  ✓ Test 2 passed: Event triggers only on paused")

	# 清理
	event.terminate(trigger)
	trigger.queue_free()
	await get_tree().process_frame

## 测试仅在恢复时触发
func test_trigger_on_resumed():
	print("\n[Test 3] Trigger on resumed only")

	var event_script = load("res://addons/fuse/events/scene/on_node_paused_resumed.gd")
	var event = event_script.new()
	event.target_node = ^"../TargetNode"
	event.trigger_on = event.TriggerOn.Resumed
	event.check_interval = 0.1

	var trigger = Node.new()
	trigger.name = "Trigger3"
	add_child(trigger)

	var target_node = Node.new()
	target_node.name = "TargetNode"
	trigger.add_child(target_node)

	var paused_triggered = false
	var resumed_triggered = false

	# 先设置为暂停
	target_node.process_mode = Node.ProcessMode.PROCESS_MODE_DISABLED

	event.triggered.connect(func(context):
		var trigger_type = context.get_meta("trigger_type")
		if trigger_type == "paused":
			paused_triggered = true
			print("  ✗ Paused triggered (should not happen)")
		elif trigger_type == "resumed":
			resumed_triggered = true
			print("  ✓ Resumed triggered")

		assert(trigger_type == "resumed", "Should only trigger on resumed")
	)

	event.initialize(trigger)
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout

	# 恢复节点
	target_node.process_mode = Node.ProcessMode.PROCESS_MODE_ALWAYS
	await get_tree().create_timer(0.3).timeout

	assert(resumed_triggered, "Should trigger on resumed")
	assert(not paused_triggered, "Should not trigger on paused")

	print("  ✓ Test 3 passed: Event triggers only on resumed")

	# 清理
	event.terminate(trigger)
	trigger.queue_free()
	await get_tree().process_frame

## 测试在暂停和恢复时都触发
func test_trigger_on_both():
	print("\n[Test 4] Trigger on both paused and resumed")

	var event_script = load("res://addons/fuse/events/scene/on_node_paused_resumed.gd")
	var event = event_script.new()
	event.target_node = ^"../TargetNode"
	event.trigger_on = event.TriggerOn.Both
	event.check_interval = 0.1

	var trigger = Node.new()
	trigger.name = "Trigger4"
	add_child(trigger)

	var target_node = Node.new()
	target_node.name = "TargetNode"
	trigger.add_child(target_node)

	var trigger_types = []

	event.triggered.connect(func(context):
		var trigger_type = context.get_meta("trigger_type")
		trigger_types.append(trigger_type)
		print("  ✓ Triggered: %s" % trigger_type)
	)

	event.initialize(trigger)
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout

	# 暂停节点
	target_node.process_mode = Node.ProcessMode.PROCESS_MODE_DISABLED
	await get_tree().create_timer(0.3).timeout

	# 恢复节点
	target_node.process_mode = Node.ProcessMode.PROCESS_MODE_ALWAYS
	await get_tree().create_timer(0.3).timeout

	assert(trigger_types.size() >= 2, "Should trigger at least twice (paused and resumed)")
	assert("paused" in trigger_types, "Should have paused trigger")
	assert("resumed" in trigger_types, "Should have resumed trigger")

	print("  ✓ Test 4 passed: Event triggers on both paused and resumed")

	# 清理
	event.terminate(trigger)
	trigger.queue_free()
	await get_tree().process_frame

## 边界情况测试
func test_edge_cases():
	print("\n[Test 5] Edge cases")

	# 测试空目标节点
	var event_script = load("res://addons/fuse/events/scene/on_node_paused_resumed.gd")
	var event1 = event_script.new()
	event1.target_node = NodePath("")

	var trigger1 = Node.new()
	add_child(trigger1)

	event1.initialize(trigger1)
	await get_tree().process_frame

	assert(event1.has_fuse_error(), "Should have error for empty target node")
	print("  ✓ Empty target node error detected")

	trigger1.queue_free()

	# 测试无效检查间隔
	var event2 = event_script.new()
	event2.target_node = ^"../TargetNode"
	event2.check_interval = -1.0

	var trigger2 = Node.new()
	add_child(trigger2)
	var target2 = Node.new()
	target2.name = "TargetNode"
	trigger2.add_child(target2)

	event2.initialize(trigger2)
	await get_tree().process_frame

	assert(event2.has_fuse_error(), "Should have error for invalid check interval")
	print("  ✓ Invalid check interval error detected")

	trigger2.queue_free()

	# 测试验证方法
	var event3 = event_script.new()
	var errors = event3.validate()
	assert(errors.size() == 1, "Should have one validation error for empty target")
	print("  ✓ Validation works correctly")

	print("  ✓ Test 5 passed: All edge cases handled")
