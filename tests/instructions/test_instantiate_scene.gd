extends Node3D

## Instantiate Scene 指令测试

func _ready():
	print("=== Testing Instantiate Scene Instruction ===")

	await test_instantiate_to_scene()
	await test_instantiate_to_parent()
	await test_save_instance_id()
	test_invalid_scene_path()

	print("=== All Instantiate Scene tests passed! ===")

## 测试 1: 实例化到当前场景
func test_instantiate_to_scene():
	print("Test 1: Instantiate to current scene")

	var instruction_script = load("res://addons/fuse/instructions/instantiate_scene.gd")
	var instruction = instruction_script.new()
	instruction.scene_path = "res://tests/test_objects/test_cube.tscn"
	instruction.parent_node = NodePath("")
	instruction.save_instance_id = false

	var context = ExecutionContext.new()
	add_child(context)

	var child_count_before = get_children().size()
	print("  Children before: %d" % child_count_before)

	instruction.execute(context)
	await get_tree().process_frame

	var child_count_after = get_children().size()
	print("  Children after: %d" % child_count_after)

	assert(child_count_after > child_count_before, "Should add new child")
	print("  ✓ Test 1 passed\n")

## 测试 2: 实例化到指定父节点
func test_instantiate_to_parent():
	print("Test 2: Instantiate to specific parent")

	# 创建父节点
	var container = Node.new()
	container.name = "Container"
	add_child(container)

	var instruction_script = load("res://addons/fuse/instructions/instantiate_scene.gd")
	var instruction = instruction_script.new()
	instruction.scene_path = "res://tests/test_objects/test_cube.tscn"
	instruction.parent_node = NodePath("../Container")
	instruction.save_instance_id = false

	var context = ExecutionContext.new()
	add_child(context)

	var child_count_before = container.get_children().size()
	print("  Container children before: %d" % child_count_before)

	instruction.execute(context)
	await get_tree().process_frame

	var child_count_after = container.get_children().size()
	print("  Container children after: %d" % child_count_after)

	assert(child_count_after > child_count_before, "Should add to container")
	print("  ✓ Test 2 passed\n")

## 测试 3: 保存实例 ID
func test_save_instance_id():
	print("Test 3: Save instance ID")

	var instruction_script = load("res://addons/fuse/instructions/instantiate_scene.gd")
	var instruction = instruction_script.new()
	instruction.scene_path = "res://tests/test_objects/test_cube.tscn"
	instruction.save_instance_id = true
	instruction.target_variable = "cube_instance"
	instruction.variable_scope = 0  # Local

	var context = ExecutionContext.new()
	add_child(context)

	instruction.execute(context)
	await get_tree().process_frame

	var instance_id = context.get_variable("cube_instance")
	assert(instance_id != null, "Should save instance ID")
	print("  Instance ID: %s" % instance_id)

	var instance = instance_from_id(instance_id)
	assert(is_instance_valid(instance), "Instance ID should be valid")
	print("  Instance valid: %s" % is_instance_valid(instance))
	print("  ✓ Test 3 passed\n")

## 测试 4: 无效场景路径
func test_invalid_scene_path():
	print("Test 4: Invalid scene path")

	var instruction_script = load("res://addons/fuse/instructions/instantiate_scene.gd")
	var instruction = instruction_script.new()
	instruction.scene_path = "res://nonexistent_scene.tscn"

	var context = ExecutionContext.new()
	add_child(context)

	print("  Executing with invalid path...")
	instruction.execute(context)
	await get_tree().process_frame

	print("  ✓ Test 4 passed (should log error)\n")
