extends Node

## OnPhysicsProcess 事件测试

func _ready():
	print("=== Testing OnPhysicsProcess ===")
	await get_tree().process_frame
	test_physics_frame_triggering()
	await get_tree().process_frame
	test_execution_interval()
	await get_tree().process_frame
	test_reset_functionality()
	await get_tree().process_frame
	test_termination()
	await get_tree().process_frame
	cleanup()
	print("=== All OnPhysicsProcess tests passed! ===")

func test_physics_frame_triggering():
	print("Test 1: Basic physics frame triggering")

	var event_script = load("res://addons/fuse/events/lifecycle/on_physics_process.gd")
	var event = event_script.new()
	event.execution_interval = 0.0  # 每物理帧

	var trigger = Node.new()
	add_child(trigger)

	var trigger_count = 0
	var received_delta = 0.0
	event.triggered.connect(func(context):
		trigger_count += 1
		received_delta = context["delta"]
	)

	event.initialize(trigger)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame  # 增加到 6 个物理帧以确保触发

	assert(trigger_count > 0, "Event should trigger on physics frames")
	assert(received_delta > 0.0, "Should receive delta time")
	print("  ✓ Test 1 passed: Physics frame triggering works\n")

	event.terminate(trigger)
	trigger.queue_free()

func test_execution_interval():
	print("Test 2: Execution interval")

	var event_script = load("res://addons/fuse/events/lifecycle/on_physics_process.gd")
	var event = event_script.new()
	event.execution_interval = 0.1  # 每 0.1 秒

	var trigger = Node.new()
	add_child(trigger)

	var trigger_count = 0
	event.triggered.connect(func(_context):
		trigger_count += 1
	)

	event.initialize(trigger)
	await get_tree().process_frame

	var start_time = Time.get_ticks_msec()
	await get_tree().create_timer(0.25).timeout
	var elapsed = (Time.get_ticks_msec() - start_time) / 1000.0

	# 0.25 秒应该触发约 2-3 次（0.1 间隔）
	assert(trigger_count >= 2 and trigger_count <= 3, "Should trigger 2-3 times in 0.25s, got %d" % trigger_count)
	print("  ✓ Test 2 passed: Execution interval works (triggered %d times in %.2fs)\n" % [trigger_count, elapsed])

	event.terminate(trigger)
	trigger.queue_free()

func test_reset_functionality():
	print("Test 3: Reset functionality")

	var event_script = load("res://addons/fuse/events/lifecycle/on_physics_process.gd")
	var event = event_script.new()
	event.execution_interval = 0.0

	var trigger = Node.new()
	add_child(trigger)

	var trigger_count = 0
	event.triggered.connect(func(_context):
		trigger_count += 1
	)

	event.initialize(trigger)
	await get_tree().process_frame
	await get_tree().physics_frame

	var first_count = trigger_count
	assert(first_count > 0, "Should trigger before reset")

	# 重置事件
	event.reset()

	# 等待几帧
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	var second_count = trigger_count - first_count
	assert(second_count > 0, "Should continue triggering after reset")
	print("  ✓ Test 3 passed: Reset functionality works\n")

	event.terminate(trigger)
	trigger.queue_free()

func test_termination():
	print("Test 4: Termination and cleanup")

	var event_script = load("res://addons/fuse/events/lifecycle/on_physics_process.gd")
	var event = event_script.new()
	event.execution_interval = 0.0

	var trigger = Node.new()
	add_child(trigger)

	event.initialize(trigger)
	await get_tree().process_frame

	# 验证 tree_entered 信号已连接
	assert(trigger.tree_entered.is_connected(event._on_tree_entered), "tree_entered should be connected")
	assert(event._is_physics_processing == true, "Should be physics processing")

	# 终止事件
	event.terminate(trigger)

	# 验证状态已重置
	assert(not trigger.tree_entered.is_connected(event._on_tree_entered), "tree_entered should be disconnected")
	assert(event._owner_node_ref == null, "Owner reference should be cleared")
	assert(event._is_physics_processing == false, "Should not be physics processing")
	assert(event._time_since_last_trigger == 0.0, "Time should be reset")
	print("  ✓ Test 4 passed: Termination works\n")

	trigger.queue_free()

func cleanup():
	# 清理测试资源
	pass
