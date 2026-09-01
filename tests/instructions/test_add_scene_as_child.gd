extends Node

## AddSceneAsChild 指令测试

func _ready():
	print("=== Testing AddSceneAsChild ===")
	test_basic_functionality()
	test_with_custom_name()
	test_error_handling()
	print("=== All AddSceneAsChild tests passed! ===")

## 测试 1: 基础功能 - 添加场景到当前场景
func test_basic_functionality():
	print("Test 1: Basic functionality - add to current scene")

	var instruction_script = load("res://addons/fuse/instructions/add_scene_as_child.gd")
	var instruction = instruction_script.new()
	instruction.scene_path = "res://tests/instructions/test_scene_to_instance.tscn"
	instruction.target_parent = NodePath("")  # 空路径 = 当前场景
	instruction.new_node_name = ""  # 使用默认名称

	var context = ExecutionContext.new()
	add_child(context)

	# 执行前检查子节点数量
	var initial_child_count = get_child_count()

	# 执行指令
	instruction.execute(context)
	await get_tree().process_frame

	# 验证场景已添加
	assert(get_child_count() > initial_child_count, "Scene should be instantiated as child")

	# 查找新添加的节点
	var new_node = null
	for child in get_children():
		if child.name.contains("TestInstance"):
			new_node = child
			break

	assert(new_node != null, "Should find the instantiated scene")
	assert(new_node is Node2D, "Instantiated node should be Node2D")
	print("  ✓ Scene instantiated successfully")
	print("  ✓ Node name: %s" % new_node.name)

	# 清理
	new_node.queue_free()
	await get_tree().process_frame

	print("  ✓ Test 1 passed\n")

## 测试 2: 使用自定义名称
func test_with_custom_name():
	print("Test 2: Add scene with custom name")

	var instruction_script = load("res://addons/fuse/instructions/add_scene_as_child.gd")
	var instruction = instruction_script.new()
	instruction.scene_path = "res://tests/instructions/test_scene_to_instance.tscn"
	instruction.target_parent = NodePath("")
	instruction.new_node_name = "MyCustomName"

	var context = ExecutionContext.new()
	add_child(context)

	# 执行指令
	instruction.execute(context)
	await get_tree().process_frame

	# 查找新添加的节点
	var new_node = get_node_or_null("MyCustomName")
	assert(new_node != null, "Should find node with custom name")
	assert(new_node.name == "MyCustomName", "Node should have custom name")
	print("  ✓ Custom name applied: %s" % new_node.name)

	# 清理
	new_node.queue_free()
	await get_tree().process_frame

	print("  ✓ Test 2 passed\n")

## 测试 3: 错误处理
func test_error_handling():
	print("Test 3: Error handling")

	var instruction_script = load("res://addons/fuse/instructions/add_scene_as_child.gd")
	var context = ExecutionContext.new()
	add_child(context)

	# 测试 3.1: 空场景路径
	print("  Test 3.1: Empty scene path")
	var instruction1 = instruction_script.new()
	instruction1.scene_path = ""
	instruction1.target_parent = NodePath("")

	instruction1.execute(context)
	await get_tree().process_frame

	assert(context.had_error(), "Should have error for empty scene path")
	print("    ✓ Correctly rejected empty scene path")

	# 测试 3.2: 不存在的场景
	print("  Test 3.2: Non-existent scene")
	var instruction2 = instruction_script.new()
	instruction2.scene_path = "res://non_existent_scene.tscn"
	instruction2.target_parent = NodePath("")

	context.clear_errors()

	instruction2.execute(context)
	await get_tree().process_frame

	assert(context.had_error(), "Should have error for non-existent scene")
	print("    ✓ Correctly rejected non-existent scene")

	# 测试 3.3: 验证方法
	print("  Test 3.3: Validation method")
	var instruction3 = instruction_script.new()
	instruction3.scene_path = ""

	var errors = instruction3.validate()
	assert(errors.size() == 1, "Should have 1 validation error")
	assert(errors[0].contains("不能为空"), "Error message should mention empty path")
	print("    ✓ Validation correctly identified error")

	# 测试 3.4: 有效配置
	print("  Test 3.4: Valid configuration")
	var instruction4 = instruction_script.new()
	instruction4.scene_path = "res://tests/instructions/test_scene_to_instance.tscn"

	errors = instruction4.validate()
	assert(errors.size() == 0, "Should have no validation errors for valid config")
	print("    ✓ Valid configuration passes validation")

	print("  ✓ Test 3 passed\n")
