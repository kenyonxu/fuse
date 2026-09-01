extends Node

## OnMouseEnter 事件测试

func _ready():
	print("=== Testing OnMouseEnter ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_trigger_once()
	test_validation()
	print("=== All OnMouseEnter tests passed! ===")

## 测试基本功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	var event = OnMouseEnter.new()
	event.trigger_once_per_enter = true

	var trigger = Node.new()
	add_child(trigger)

	# 创建一个 Control 节点
	var control = Control.new()
	control.custom_minimum_size = Vector2(100, 100)
	control.position = Vector2(50, 50)
	control.name = "TestControl"
	trigger.add_child(control)

	event.target_node_path = control.get_path()

	var triggered = false
	var context_node = null
	event.triggered.connect(func(node):
		triggered = true
		context_node = node
		print("  Event triggered!")
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 手动触发 mouse_entered 信号
	control.mouse_entered.emit()
	await get_tree().process_frame

	assert(triggered, "Event should trigger on mouse enter")
	assert(context_node != null, "Context node should be provided")
	assert(context_node.has_meta("target_node"), "Context should have target_node")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	control.queue_free()
	trigger.queue_free()

## 测试触发一次模式
func test_trigger_once():
	print("Test 2: Trigger once per enter")

	var trigger = Node.new()
	add_child(trigger)

	var control = Control.new()
	control.custom_minimum_size = Vector2(100, 100)
	control.name = "TestControl2"
	trigger.add_child(control)

	# 测试仅触发一次
	var event_once = OnMouseEnter.new()
	event_once.target_node_path = control.get_path()
	event_once.trigger_once_per_enter = true

	var trigger_count = 0
	event_once.triggered.connect(func(node):
		trigger_count += 1
	)

	event_once.initialize(trigger)
	await get_tree().process_frame

	# 第一次进入
	control.mouse_entered.emit()
	await get_tree().process_frame
	var first_count = trigger_count

	# 第二次进入（应该不触发）
	control.mouse_entered.emit()
	await get_tree().process_frame
	var second_count = trigger_count

	assert(first_count == 1, "Event should trigger once")
	assert(second_count == 1, "Event should not trigger again on same enter")
	event_once.terminate(trigger)

	# 测试可重复触发
	var event_repeat = OnMouseEnter.new()
	event_repeat.target_node_path = control.get_path()
	event_repeat.trigger_once_per_enter = false

	var repeat_count = 0
	event_repeat.triggered.connect(func(node):
		repeat_count += 1
	)

	event_repeat.initialize(trigger)
	await get_tree().process_frame

	# 多次进入
	control.mouse_entered.emit()
	await get_tree().process_frame
	control.mouse_entered.emit()
	await get_tree().process_frame

	assert(repeat_count == 2, "Event should trigger multiple times")
	event_repeat.terminate(trigger)

	print("  ✓ Test 2 passed\n")
	control.queue_free()
	trigger.queue_free()

## 测试参数验证
func test_validation():
	print("Test 3: Parameter validation")

	var event = OnMouseEnter.new()

	# 测试空目标路径
	event.target_node_path = NodePath("")
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for empty target path")
	print("  ✓ Empty target path validation passed")

	# 测试有效路径
	event.target_node_path = NodePath("./SomeNode")
	errors = event.validate()
	# 路径不为空，但可能找不到节点，这里只验证路径本身
	assert(errors.is_empty() or "目标节点路径不能为空" not in errors, "Should not have empty path error")
	print("  ✓ Valid target path validation passed")

	print("  ✓ Test 3 passed\n")
