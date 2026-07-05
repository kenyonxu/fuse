extends Node

## OnPropertyChanged 事件测试

func _ready():
	print("=== Testing OnPropertyChanged ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_different_properties()
	test_validation()
	print("=== All OnPropertyChanged tests passed! ===")

## 测试基本功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	var trigger = Node.new()
	add_child(trigger)

	# 创建一个测试节点并添加一个可修改的属性
	var test_node = Node2D.new()
	test_node.name = "TestNode"
	test_node.position = Vector2(0, 0)
	trigger.add_child(test_node)

	var event = OnPropertyChanged.new()
	event.target_node = NodePath("TestNode")
	event.property_name = "position"
	event.check_interval = 0.1
	event.emit_old_and_new = true

	var triggered = false
	var old_value = null
	var new_value = null
	event.triggered.connect(func(context):
		triggered = true
		old_value = context.get_meta("old_value")
		new_value = context.get_meta("new_value")
		print("  Property changed event triggered! Old: %s, New: %s" % [old_value, new_value])
	)

	event.initialize(trigger)

	# 修改属性
	await get_tree().create_timer(0.05).timeout
	test_node.position = Vector2(100, 100)

	# 等待事件触发
	await get_tree().create_timer(0.2).timeout

	assert(triggered, "Event should trigger on property change")
	assert(old_value == Vector2(0, 0), "Old value should be (0, 0)")
	assert(new_value == Vector2(100, 100), "New value should be (100, 100)")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	trigger.queue_free()

## 测试不同类型的属性
func test_different_properties():
	print("Test 2: Different property types")

	var trigger = Node.new()
	add_child(trigger)

	# 测试 position 属性
	var node2d = Node2D.new()
	node2d.name = "Node2D"
	node2d.position = Vector2(0, 0)
	trigger.add_child(node2d)

	var event1 = OnPropertyChanged.new()
	event1.target_node = NodePath("Node2D")
	event1.property_name = "position"
	event1.check_interval = 0.1

	var position_triggered = false
	event1.triggered.connect(func(context):
		position_triggered = true
		print("  Position property changed!")
	)

	event1.initialize(trigger)

	await get_tree().process_frame
	node2d.position = Vector2(50, 50)
	await get_tree().create_timer(0.2).timeout

	assert(position_triggered, "Should trigger on position change")
	print("  ✓ Position property passed")

	event1.terminate(trigger)

	# 测试 visible 属性
	var sprite = ColorRect.new()
	sprite.name = "Sprite"
	sprite.visible = true
	trigger.add_child(sprite)

	var event2 = OnPropertyChanged.new()
	event2.target_node = NodePath("Sprite")
	event2.property_name = "visible"
	event2.check_interval = 0.1

	var visible_triggered = false
	event2.triggered.connect(func(context):
		visible_triggered = true
		print("  Visible property changed!")
	)

	event2.initialize(trigger)

	await get_tree().process_frame
	sprite.visible = false
	await get_tree().create_timer(0.2).timeout

	assert(visible_triggered, "Should trigger on visible change")
	print("  ✓ Visible property passed")

	event2.terminate(trigger)
	trigger.queue_free()

	print("  ✓ Test 2 passed\n")

## 测试参数验证
func test_validation():
	print("Test 3: Parameter validation")

	var trigger = Node.new()
	add_child(trigger)

	var event = OnPropertyChanged.new()

	# 测试空的 target_node
	event.target_node = NodePath("")
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for empty target node")
	print("  ✓ Empty target node validation passed")

	# 测试空的 property_name
	event.target_node = NodePath("SomeNode")
	event.property_name = ""
	errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for empty property name")
	print("  ✓ Empty property name validation passed")

	# 测试无效的 check_interval
	event.property_name = "position"
	event.check_interval = -0.01
	errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for negative interval")
	print("  ✓ Negative interval validation passed")

	# 测试有效配置
	event.check_interval = 0.1
	errors = event.validate()
	assert(errors.is_empty(), "Valid configuration should pass validation")
	print("  ✓ Valid configuration passed")

	trigger.queue_free()
	print("  ✓ Test 3 passed\n")
