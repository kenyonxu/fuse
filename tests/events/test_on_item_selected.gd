extends Node

## OnItemSelected 事件测试

func _ready():
	print("=== Testing OnItemSelected ===")
	await get_tree().process_frame
	test_basic_functionality()
	test_multi_select_mode()
	test_deselect_all()
	test_validation()
	print("=== All OnItemSelected tests passed! ===")

## 测试基本功能（单选模式）
func test_basic_functionality():
	print("Test 1: Basic functionality (single select)")

	var event = OnItemSelected.new()
	var itemlist = ItemList.new()
	itemlist.name = "TestItemList"
	itemlist.add_item("Item 1")
	itemlist.add_item("Item 2")
	itemlist.add_item("Item 3")
	add_child(itemlist)

	var trigger = Node.new()
	add_child(trigger)

	event.target_node_path = trigger.get_path_to(itemlist)
	event.multi_select_mode = false

	var triggered = false
	var selected_indices = []
	var selected_count = -1

	event.triggered.connect(func(context):
		triggered = true
		if context:
			selected_indices = context.get_meta("selected_indices", [])
			selected_count = context.get_meta("selected_count", -1)
		print("  Event triggered! Selected indices: ", selected_indices)
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 模拟选中第一项
	itemlist.select(0)
	itemlist.emit_signal("item_selected", 0)
	await get_tree().process_frame

	assert(triggered, "Event should trigger when item is selected")
	assert(selected_indices.size() == 1, "Should have 1 selected index")
	assert(selected_indices[0] == 0, "Selected index should be 0")
	assert(selected_count == 1, "Selected count should be 1")
	print("  ✓ Test 1 passed\n")

	event.terminate(trigger)
	itemlist.queue_free()
	trigger.queue_free()

## 测试多选模式
func test_multi_select_mode():
	print("Test 2: Multi-select mode")

	var event = OnItemSelected.new()
	var itemlist = ItemList.new()
	itemlist.name = "MultiSelectItemList"
	itemlist.add_item("Item A")
	itemlist.add_item("Item B")
	itemlist.add_item("Item C")
	add_child(itemlist)

	var trigger = Node.new()
	add_child(trigger)

	event.target_node_path = trigger.get_path_to(itemlist)
	event.multi_select_mode = true

	var trigger_count = 0
	var selected_indices_history = []

	event.triggered.connect(func(context):
		trigger_count += 1
		if context:
			var indices = context.get_meta("selected_indices", [])
			selected_indices_history.append(indices.duplicate())
		print("  Trigger #%d: Selected indices: " % trigger_count, selected_indices_history[-1])
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 选中第一项
	itemlist.select(0)
	itemlist.emit_signal("multi_selected", 0, true)
	await get_tree().process_frame

	# 选中第二项
	itemlist.select(1)
	itemlist.emit_signal("multi_selected", 1, true)
	await get_tree().process_frame

	# 取消选中第一项
	itemlist.deselect(0)
	itemlist.emit_signal("multi_selected", 0, false)
	await get_tree().process_frame

	assert(trigger_count >= 2, "Event should trigger multiple times in multi-select mode")
	print("  ✓ Test 2 passed\n")

	event.terminate(trigger)
	itemlist.queue_free()
	trigger.queue_free()

## 测试取消所有选中
func test_deselect_all():
	print("Test 3: Deselect all")

	var event = OnItemSelected.new()
	var itemlist = ItemList.new()
	itemlist.name = "DeselectItemList"
	itemlist.add_item("Item X")
	itemlist.add_item("Item Y")
	add_child(itemlist)

	var trigger = Node.new()
	add_child(trigger)

	event.target_node_path = trigger.get_path_to(itemlist)
	event.multi_select_mode = true

	var triggered = false
	var selected_count = -1

	event.triggered.connect(func(context):
		triggered = true
		if context:
			selected_count = context.get_meta("selected_count", -1)
		print("  Event triggered! Selected count: ", selected_count)
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 先选中一项
	itemlist.select(0)
	itemlist.emit_signal("multi_selected", 0, true)
	await get_tree().process_frame

	# 取消所有选中
	itemlist.deselect_all()
	itemlist.emit_signal("nothing_selected")
	await get_tree().process_frame

	assert(triggered, "Event should trigger when nothing is selected")
	assert(selected_count == 0, "Selected count should be 0")
	print("  ✓ Test 3 passed\n")

	event.terminate(trigger)
	itemlist.queue_free()
	trigger.queue_free()

## 测试参数验证
func test_validation():
	print("Test 4: Parameter validation")

	var event = OnItemSelected.new()

	# 测试空目标节点
	event.target_node_path = NodePath("")
	var errors = event.validate()
	assert(not errors.is_empty(), "Should have validation errors for empty target")
	print("  ✓ Empty target validation passed")

	print("  ✓ Test 4 passed\n")
