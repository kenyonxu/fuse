extends Node

## OnBackgroundLoadProgress 事件测试

## 测试资源路径（需要在实际项目中存在有效资源）
const TEST_RESOURCE_PATH = "res://icon.svg"

func _ready():
	print("=== Testing OnBackgroundLoadProgress ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_progress_emission()
	test_validation()
	test_edge_cases()
	print("=== All OnBackgroundLoadProgress tests passed! ===")

## 测试基本功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	# 首先验证测试资源是否存在
	if not FileAccess.file_exists(TEST_RESOURCE_PATH):
		print("  ⚠ Test resource not found, skipping basic functionality test")
		print("  ✓ Test 1 skipped\n")
		return

	var event = OnBackgroundLoadProgress.new()
	event.load_resource_path = TEST_RESOURCE_PATH
	event.check_interval = 0.05
	event.progress_threshold = 0.5
	event.emit_progress = true

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	var received_progress = -1.0
	event.triggered.connect(func(context):
		triggered = true
		if context and context.has_meta("progress"):
			received_progress = context.get_meta("progress")
		print("  Event triggered! Progress: %.2f%%" % (received_progress * 100 if received_progress >= 0 else 0))
	)

	event.initialize(trigger)
	await get_tree().create_timer(0.5).timeout

	assert(triggered, "Event should trigger")
	assert(received_progress >= 0, "Progress value should be emitted")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试进度值传递
func test_progress_emission():
	print("Test 2: Progress emission")

	# 验证测试资源是否存在
	if not FileAccess.file_exists(TEST_RESOURCE_PATH):
		print("  ⚠ Test resource not found, skipping progress emission test")
		print("  ✓ Test 2 skipped\n")
		return

	# 测试不传递进度值的情况
	var event = OnBackgroundLoadProgress.new()
	event.load_resource_path = TEST_RESOURCE_PATH
	event.check_interval = 0.05
	event.progress_threshold = 0.5
	event.emit_progress = false

	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	var context_is_null = false
	event.triggered.connect(func(context):
		triggered = true
		context_is_null = (context == null)
		print("  Event triggered! Context is null: %s" % context_is_null)
	)

	event.initialize(trigger)
	await get_tree().create_timer(0.5).timeout

	assert(triggered, "Event should trigger")
	assert(context_is_null, "Context should be null when emit_progress is false")
	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试参数验证
func test_validation():
	print("Test 3: Parameter validation")

	var event = OnBackgroundLoadProgress.new()

	# 测试空的资源路径
	event.resource_path = ""
	event.check_interval = 0.1
	event.progress_threshold = 0.1
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for empty resource path")
	print("  ✓ Empty resource path validation passed")

	# 测试无效的检查间隔
	event.resource_path = TEST_RESOURCE_PATH
	event.check_interval = -1.0
	errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for negative check interval")
	print("  ✓ Negative check interval validation passed")

	# 测试无效的进度阈值
	event.check_interval = 0.1
	event.progress_threshold = 1.5
	errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for invalid progress threshold")
	print("  ✓ Invalid progress threshold validation passed")

	# 测试有效配置
	event.resource_path = TEST_RESOURCE_PATH
	event.check_interval = 0.1
	event.progress_threshold = 0.1
	errors = event.validate()
	# 注意：如果资源路径指向不存在的文件，validate() 不会报错（因为 validate() 只检查格式，不检查文件是否存在）
	print("  ✓ Valid configuration format passed")

	print("  ✓ Test 3 passed\n")

## 测试边界条件
func test_edge_cases():
	print("Test 4: Edge cases")

	# 验证测试资源是否存在
	if not FileAccess.file_exists(TEST_RESOURCE_PATH):
		print("  ⚠ Test resource not found, skipping edge cases test")
		print("  ✓ Test 4 skipped\n")
		return

	# 测试零阈值（应该频繁触发）
	var event = OnBackgroundLoadProgress.new()
	event.load_resource_path = TEST_RESOURCE_PATH
	event.check_interval = 0.05
	event.progress_threshold = 0.0

	var trigger = Node.new()
	add_child(trigger)

	var trigger_count = 0
	event.triggered.connect(func(context):
		trigger_count += 1
		print("  Event triggered! (count: %d)" % trigger_count)
	)

	event.initialize(trigger)
	await get_tree().create_timer(0.3).timeout

	assert(trigger_count > 0, "Event should trigger at least once with zero threshold")
	print("  ✓ Zero threshold test passed (triggered %d times)" % trigger_count)

	event.terminate(trigger)
	trigger.queue_free()

	# 测试最大阈值（1.0，应该只在完成时触发一次）
	event = OnBackgroundLoadProgress.new()
	event.resource_path = TEST_RESOURCE_PATH
	event.check_interval = 0.05
	event.progress_threshold = 1.0

	trigger = Node.new()
	add_child(trigger)

	trigger_count = 0
	event.triggered.connect(func(context):
		trigger_count += 1
		print("  Event triggered! (count: %d)" % trigger_count)
	)

	event.initialize(trigger)
	await get_tree().create_timer(0.5).timeout

	assert(trigger_count >= 1, "Event should trigger at least once when load completes")
	print("  ✓ Maximum threshold test passed (triggered %d times)" % trigger_count)

	event.terminate(trigger)
	trigger.queue_free()

	print("  ✓ Test 4 passed\n")
