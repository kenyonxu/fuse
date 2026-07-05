extends Node

## Queue Free Node 指令测试

func _ready():
	print("=== Testing Queue Free Node Instruction ===")

	await test_immediate_free()
	await test_delayed_free()
	test_free_nonexistent_node()

	print("=== All Queue Free Node tests passed! ===")

## 测试 1: 立即释放
func test_immediate_free():
	print("Test 1: Immediate queue free")

	var test_node = Node.new()
	test_node.name = "TestNode1"
	add_child(test_node)

	var instruction_script = load("res://addons/fuse/instructions/queue_free_node.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("../TestNode1")
	instruction.delay = 0.0

	var context = ExecutionContext.new()
	add_child(context)

	print("  Node exists before: %s" % is_instance_valid($TestNode1))

	instruction.execute(context)

	# 等待一帧让 queue_free 生效
	await get_tree().process_frame

	print("  Node exists after: %s" % is_instance_valid($TestNode1))
	assert(not is_instance_valid($TestNode1), "Node should be freed")
	print("  ✓ Test 1 passed\n")

## 测试 2: 延迟释放
func test_delayed_free():
	print("Test 2: Delayed queue free")

	var test_node = Node.new()
	test_node.name = "TestNode2"
	add_child(test_node)

	var instruction_script = load("res://addons/fuse/instructions/queue_free_node.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("../TestNode2")
	instruction.delay = 0.5

	var context = ExecutionContext.new()
	add_child(context)

	print("  Node exists before: %s" % is_instance_valid($TestNode2))

	instruction.execute(context)

	await get_tree().create_timer(0.3).timeout
	print("  Node exists at 0.3s: %s" % is_instance_valid($TestNode2))
	assert(is_instance_valid($TestNode2), "Node should still exist")

	await get_tree().create_timer(0.3).timeout
	print("  Node exists at 0.6s: %s" % is_instance_valid($TestNode2))
	assert(not is_instance_valid($TestNode2), "Node should be freed after delay")

	print("  ✓ Test 2 passed\n")

## 测试 3: 释放不存在的节点
func test_free_nonexistent_node():
	print("Test 3: Free nonexistent node")

	var instruction_script = load("res://addons/fuse/instructions/queue_free_node.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("NonexistentNode")
	instruction.delay = 0.0

	var context = ExecutionContext.new()
	add_child(context)

	print("  Executing with nonexistent node...")
	instruction.execute(context)
	await get_tree().process_frame

	print("  ✓ Test 3 passed (should log error)\n")
