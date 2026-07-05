extends Node

## ReparentNode 指令测试

func _ready():
	print("=== Testing ReparentNode ===")
	test_basic_functionality()
	test_keep_global_transform()
	test_error_handling()
	print("=== All ReparentNode tests passed! ===")

## 测试 1: 基础功能 - 重父化节点
func test_basic_functionality():
	print("Test 1: Basic functionality - reparent node")

	var instruction_script = load("res://addons/fuse/instructions/reparent_node.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("Parent1/Child1")
	instruction.new_parent = NodePath("Parent2")
	instruction.keep_global_transform = true

	var context = ExecutionContext.new()
	add_child(context)

	# 获取初始父节点
	var child1 = get_node(NodePath("Parent1/Child1"))
	var initial_parent = child1.get_parent()
	assert(initial_parent.name == "Parent1", "Child should start under Parent1")
	print("  ✓ Child initially under Parent1")

	# 执行指令
	instruction.execute(context)
	await get_tree().process_frame

	# 验证重父化成功
	var new_parent = child1.get_parent()
	assert(new_parent.name == "Parent2", "Child should be moved to Parent2")
	print("  ✓ Child moved to Parent2")
	print("  ✓ Test 1 passed\n")

## 测试 2: 保持全局变换
func test_keep_global_transform():
	print("Test 2: Keep global transform")

	var instruction_script = load("res://addons/fuse/instructions/reparent_node.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath("Parent1/Child2")
	instruction.new_parent = NodePath("Parent2")
	instruction.keep_global_transform = true

	var context = ExecutionContext.new()
	add_child(context)

	# 获取节点
	var child2 = get_node(NodePath("Parent1/Child2"))
	var parent1 = get_node(NodePath("Parent1"))
	var parent2 = get_node(NodePath("Parent2"))

	# 设置父节点不同的位置（如果是 2D/3D 节点）
	if child2 is Node2D:
		parent1.position = Vector2(100, 100)
		parent2.position = Vector2(200, 200)
		child2.position = Vector2(50, 50)

		# 记录全局位置
		var initial_global_pos = child2.global_position
		print("  Initial global position: %s" % str(initial_global_pos))

		# 执行重父化
		instruction.execute(context)
		await get_tree().process_frame

		# 验证全局位置保持不变
		var final_global_pos = child2.global_position
		assert(initial_global_pos.is_equal_approx(final_global_pos), "Global position should be preserved")
		print("  ✓ Global position preserved: %s" % str(final_global_pos))
	else:
		# 如果不是 2D 节点，只测试重父化
		instruction.execute(context)
		await get_tree().process_frame
		print("  ✓ Reparent completed (node is not Node2D)")

	print("  ✓ Test 2 passed\n")

## 测试 3: 错误处理
func test_error_handling():
	print("Test 3: Error handling")

	var instruction_script = load("res://addons/fuse/instructions/reparent_node.gd")
	var context = ExecutionContext.new()
	add_child(context)

	# 测试 3.1: 空目标节点路径
	print("  Test 3.1: Empty target node path")
	var instruction1 = instruction_script.new()
	instruction1.target_node = NodePath("")
	instruction1.new_parent = NodePath("Parent2")

	instruction1.execute(context)
	await get_tree().process_frame

	assert(context.had_error(), "Should have error for empty target node")
	print("    ✓ Correctly rejected empty target node")

	# 测试 3.2: 空新父节点路径
	print("  Test 3.2: Empty new parent node path")
	var instruction2 = instruction_script.new()
	instruction2.target_node = NodePath("Parent1/Child1")
	instruction2.new_parent = NodePath("")

	context.clear_errors()

	instruction2.execute(context)
	await get_tree().process_frame

	assert(context.had_error(), "Should have error for empty new parent")
	print("    ✓ Correctly rejected empty new parent")

	# 测试 3.3: 重父化到自身
	print("  Test 3.3: Reparent to self")
	var instruction3 = instruction_script.new()
	instruction3.target_node = NodePath("Parent1")
	instruction3.new_parent = NodePath("Parent1")

	context.clear_errors()

	instruction3.execute(context)
	await get_tree().process_frame

	assert(context.had_error(), "Should have error for reparent to self")
	print("    ✓ Correctly rejected reparent to self")

	# 测试 3.4: 重父化到子孙节点
	print("  Test 3.4: Reparent to descendant")
	var instruction4 = instruction_script.new()
	instruction4.target_node = NodePath("Parent1")
	instruction4.new_parent = NodePath("Parent1/Child1")

	context.clear_errors()

	instruction4.execute(context)
	await get_tree().process_frame

	assert(context.had_error(), "Should have error for reparent to descendant")
	print("    ✓ Correctly rejected reparent to descendant")

	# 测试 3.5: 目标节点不存在
	print("  Test 3.5: Target node not found")
	var instruction5 = instruction_script.new()
	instruction5.target_node = NodePath("NonExistentNode")
	instruction5.new_parent = NodePath("Parent2")

	context.clear_errors()

	instruction5.execute(context)
	await get_tree().process_frame

	assert(context.had_error(), "Should have error for non-existent target")
	print("    ✓ Correctly rejected non-existent target")

	# 测试 3.6: 新父节点不存在
	print("  Test 3.6: New parent node not found")
	var instruction6 = instruction_script.new()
	instruction6.target_node = NodePath("Parent1/Child1")
	instruction6.new_parent = NodePath("NonExistentNode")

	context.clear_errors()

	instruction6.execute(context)
	await get_tree().process_frame

	assert(context.had_error(), "Should have error for non-existent parent")
	print("    ✓ Correctly rejected non-existent parent")

	# 测试 3.7: 验证方法
	print("  Test 3.7: Validation method")
	var instruction7 = instruction_script.new()
	instruction7.target_node = NodePath("")
	instruction7.new_parent = NodePath("")

	var errors = instruction7.validate()
	assert(errors.size() == 2, "Should have 2 validation errors")
	print("    ✓ Validation correctly identified errors")

	print("  ✓ Test 3 passed\n")
