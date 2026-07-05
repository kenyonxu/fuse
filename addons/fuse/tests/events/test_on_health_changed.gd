extends Node

## OnHealthChanged 事件测试

func _ready():
	print("=== Testing OnHealthChanged ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_threshold_modes()
	test_validation()
	print("=== All OnHealthChanged tests passed! ===")

## 测试基本功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	var event = OnHealthChanged.new()
	var target = Node.new()
	target.name = "TestTarget"
	target.set("health", 100)
	target.set("max_health", 100)
	add_child(target)

	var trigger = Node.new()
	add_child(trigger)

	event.target_node = trigger.get_path_to(target)
	event.health_property = "health"
	event.max_health_property = "max_health"
	event.trigger_mode = OnHealthChanged.TriggerMode.ON_CHANGE
	event.check_interval = 0.05

	var triggered = false
	event.triggered.connect(func(context):
		triggered = true
		print("  Event triggered! Health: %d/%d" % [context.get_meta("health"), context.get_meta("max_health")])
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 改变生命值
	target.set("health", 80)
	await get_tree().create_timer(0.2).timeout

	assert(triggered, "Event should trigger on health change")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	target.queue_free()
	trigger.queue_free()

## 测试阈值模式
func test_threshold_modes():
	print("Test 2: Threshold modes")

	var target = Node.new()
	target.name = "TestTarget"
	target.set("health", 100)
	target.set("max_health", 100)
	add_child(target)

	var trigger = Node.new()
	add_child(trigger)

	# 测试低生命值模式
	var event_low = OnHealthChanged.new()
	event_low.target_node = trigger.get_path_to(target)
	event_low.health_property = "health"
	event_low.max_health_property = "max_health"
	event_low.trigger_mode = OnHealthChanged.TriggerMode.ON_LOW
	event_low.threshold_low = 0.3
	event_low.check_interval = 0.05

	var low_triggered = false
	event_low.triggered.connect(func(context):
		low_triggered = true)

	event_low.initialize(trigger)
	await get_tree().process_frame

	# 降低到低生命值
	target.set("health", 25)
	await get_tree().create_timer(0.2).timeout

	assert(low_triggered, "Event should trigger at low health")
	event_low.terminate(trigger)

	print("  ✓ Test 2 passed\n")

	target.queue_free()
	trigger.queue_free()

## 测试参数验证
func test_validation():
	print("Test 3: Parameter validation")

	var event = OnHealthChanged.new()

	# 测试空目标节点
	event.target_node = NodePath("")
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for empty target")
	print("  ✓ Empty target validation passed")

	# 测试空属性名
	event.target_node = NodePath("TestTarget")
	event.health_property = ""
	errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for empty property name")
	print("  ✓ Empty property name validation passed")

	# 测试无效的检查间隔
	event.health_property = "health"
	event.check_interval = -1.0
	errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for negative interval")
	print("  ✓ Negative interval validation passed")

	# 测试无效的阈值
	event.check_interval = 0.1
	event.threshold_low = -0.5
	errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for invalid threshold")
	print("  ✓ Invalid threshold validation passed")

	# 测试危急阈值大于低阈值
	event.threshold_low = 0.3
	event.threshold_critical = 0.5
	errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors when critical > low")
	print("  ✓ Threshold order validation passed")

	print("  ✓ Test 3 passed\n")
