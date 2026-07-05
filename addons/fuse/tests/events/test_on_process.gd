extends Node

## OnProcess 事件测试
## 🔧 简化版：OnProcess 只处理 _process，物理帧处理请使用 OnPhysicsProcess

func _ready():
	print("=== Testing OnProcess (Simplified) ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_execution_interval()
	test_validation()
	print("=== All OnProcess tests passed! ===")

## 测试基本功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	var event = OnProcess.new()
	event.execution_interval = 0.05  # 50ms

	var trigger_node = Node.new()
	trigger_node.name = "TestTrigger"
	add_child(trigger_node)

	var trigger_count = 0
	event.triggered.connect(func(context):
		trigger_count += 1
		print("  Process event triggered! (count: %d)" % trigger_count)
	)

	event.initialize(trigger_node)

	# 模拟 process 调用（通常由 Trigger 完成）
	for i in range(10):
		event.on_process(0.016)  # 60 FPS
		await get_tree().process_frame

	assert(trigger_count > 0, "Event should trigger at least once")
	print("  Event triggered %d times in test period" % trigger_count)
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger_node)
	trigger_node.queue_free()

## 测试执行间隔
func test_execution_interval():
	print("Test 2: Execution interval")

	var event = OnProcess.new()
	event.execution_interval = 0.033  # ~30 FPS

	var trigger_node = Node.new()
	trigger_node.name = "TestTrigger2"
	add_child(trigger_node)

	var trigger_times = []
	event.triggered.connect(func(context):
		trigger_times.append(Time.get_ticks_msec())
	)

	event.initialize(trigger_node)

	# 模拟 process 调用
	var start_time = Time.get_ticks_msec()
	for i in range(20):
		event.on_process(0.016)  # 每帧 16ms
		await get_tree().process_frame

	var total_time = (Time.get_ticks_msec() - start_time) / 1000.0
	var expected_count = int(total_time / event.execution_interval)
	var actual_count = trigger_times.size()

	print("  Total time: %.2fs, Expected triggers: ~%d, Actual: %d" % [total_time, expected_count, actual_count])

	# 验证触发次数在合理范围内
	assert(actual_count >= expected_count - 2 and actual_count <= expected_count + 2,
		"Trigger count should be close to expected (expected: %d, actual: %d)" % [expected_count, actual_count])
	print("  ✓ Test 2 passed\n")

	event.terminate(trigger_node)
	trigger_node.queue_free()

## 测试参数验证
func test_validation():
	print("Test 3: Parameter validation")

	var event = OnProcess.new()

	# 测试无效的 execution_interval
	event.execution_interval = -0.01
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for negative interval")
	print("  ✓ Negative interval validation passed")

	# 测试有效配置
	event.execution_interval = 0.1
	errors = event.validate()
	assert(errors.is_empty(), "Valid configuration should pass validation")
	print("  ✓ Valid configuration passed")

	print("  ✓ Test 3 passed\n")

## 测试禁用后不再触发
func test_terminate_stops_processing():
	print("Test 4: Terminate stops processing")

	var event = OnProcess.new()
	event.execution_interval = 0.01  # 10ms - 很快触发

	var trigger_node = Node.new()
	trigger_node.name = "TestTrigger3"
	add_child(trigger_node)

	var trigger_count = 0
	event.triggered.connect(func(context):
		trigger_count += 1
	)

	event.initialize(trigger_node)

	# 模拟一些 process 调用
	for i in range(5):
		event.on_process(0.016)
		await get_tree().process_frame

	var count_before_terminate = trigger_count
	print("  Triggered %d times before terminate" % count_before_terminate)

	# 终止事件
	event.terminate(trigger_node)

	# 继续模拟 process 调用
	for i in range(5):
		event.on_process(0.016)
		await get_tree().process_frame

	var count_after_terminate = trigger_count
	print("  Triggered %d times after terminate" % (count_after_terminate - count_before_terminate))

	assert(count_after_terminate == count_before_terminate,
		"Should not trigger after terminate (before: %d, after: %d)" % [count_before_terminate, count_after_terminate])
	print("  ✓ Test 4 passed\n")

	trigger_node.queue_free()
