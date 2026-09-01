extends Node

## Enable/Disable Node 指令测试

func _ready():
	print("=== Testing Enable/Disable Node Instruction ===")

	test_enable_processing()
	test_disable_processing()
	test_show_visible()
	test_hide_visible()

	print("=== All Enable/Disable Node tests passed! ===")

## 测试 1: 启用处理模式
func test_enable_processing():
	print("Test 1: Enable processing")

	var instruction_script = load("res://addons/fuse/instructions/enable_disable_node.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("../TestNode2D")
	instruction.enable = true
	instruction.mode = 0  # PROCESSING

	var context = ExecutionContext.new()
	add_child(context)

	var test_node = get_node("../TestNode2D")
	test_node.process_mode = Node.PROCESS_MODE_DISABLED
	print("  Before: process_mode = %s" % test_node.process_mode)

	instruction.execute(context)
	await get_tree().process_frame

	assert(test_node.process_mode == Node.PROCESS_MODE_INHERIT, "Should enable processing")
	print("  After: process_mode = %s" % test_node.process_mode)
	print("  ✓ Test 1 passed\n")

## 测试 2: 禁用处理模式
func test_disable_processing():
	print("Test 2: Disable processing")

	var instruction_script = load("res://addons/fuse/instructions/enable_disable_node.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("../TestNode2D")
	instruction.enable = false
	instruction.mode = 0  # PROCESSING

	var context = ExecutionContext.new()
	add_child(context)

	var test_node = get_node("../TestNode2D")
	test_node.process_mode = Node.PROCESS_MODE_INHERIT
	print("  Before: process_mode = %s" % test_node.process_mode)

	instruction.execute(context)
	await get_tree().process_frame

	assert(test_node.process_mode == Node.PROCESS_MODE_DISABLED, "Should disable processing")
	print("  After: process_mode = %s" % test_node.process_mode)
	print("  ✓ Test 2 passed\n")

## 测试 3: 显示节点
func test_show_visible():
	print("Test 3: Show visible")

	var instruction_script = load("res://addons/fuse/instructions/enable_disable_node.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("../TestNode2D")
	instruction.enable = true
	instruction.mode = 1  # VISIBLE

	var context = ExecutionContext.new()
	add_child(context)

	var test_node = get_node("../TestNode2D")
	test_node.visible = false
	print("  Before: visible = %s" % test_node.visible)

	instruction.execute(context)
	await get_tree().process_frame

	assert(test_node.visible == true, "Should show node")
	print("  After: visible = %s" % test_node.visible)
	print("  ✓ Test 3 passed\n")

## 测试 4: 隐藏节点
func test_hide_visible():
	print("Test 4: Hide visible")

	var instruction_script = load("res://addons/fuse/instructions/enable_disable_node.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("../TestNode2D")
	instruction.enable = false
	instruction.mode = 1  # VISIBLE

	var context = ExecutionContext.new()
	add_child(context)

	var test_node = get_node("../TestNode2D")
	test_node.visible = true
	print("  Before: visible = %s" % test_node.visible)

	instruction.execute(context)
	await get_tree().process_frame

	assert(test_node.visible == false, "Should hide node")
	print("  After: visible = %s" % test_node.visible)
	print("  ✓ Test 4 passed\n")
