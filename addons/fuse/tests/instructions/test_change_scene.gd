extends Node

## Change Scene 指令测试

# 测试场景路径
const TEST_SCENE_PATH = "res://addons/fuse/tests/test_objects/test_cube.tscn"
const INVALID_SCENE_PATH = "res://nonexistent_scene.tscn"

func _ready():
	print("=== Testing Change Scene Instruction ===")

	test_invalid_scene_path()
	test_scene_path_validation()
	test_delay_validation()
	test_immediate_change()

	print("=== All Change Scene tests passed! ===")

## 测试 1: 无效场景路径
func test_invalid_scene_path():
	print("Test 1: Invalid scene path")

	var instruction_script = load("res://addons/fuse/instructions/change_scene.gd")
	var instruction = instruction_script.new()
	instruction.scene_path = INVALID_SCENE_PATH

	var context = ExecutionContext.new()
	add_child(context)

	print("  Executing with invalid path...")
	instruction.execute(context)
	await get_tree().process_frame

	# 验证应该记录错误
	assert(context.had_error(), "Should have error for invalid scene path")
	print("  ✓ Test 1 passed (should log error)\n")

## 测试 2: 场景路径验证
func test_scene_path_validation():
	print("Test 2: Scene path validation")

	var instruction_script = load("res://addons/fuse/instructions/change_scene.gd")
	var instruction = instruction_script.new()

	# 测试空路径
	instruction.scene_path = ""
	var errors = instruction.validate()
	assert(errors.size() > 0, "Should have errors for empty scene path")
	print("  Empty path validation: ✓")

	# 测试有效路径
	instruction.scene_path = TEST_SCENE_PATH
	errors = instruction.validate()
	assert(errors.size() == 0 or not "场景路径不能为空" in errors, "Should not have empty path error")
	print("  Valid path validation: ✓")
	print("  ✓ Test 2 passed\n")

## 测试 3: 延迟验证
func test_delay_validation():
	print("Test 3: Delay validation")

	var instruction_script = load("res://addons/fuse/instructions/change_scene.gd")
	var instruction = instruction_script.new()
	instruction.scene_path = TEST_SCENE_PATH

	# 测试负延迟
	instruction.delay = -1.0
	var errors = instruction.validate()
	assert(errors.size() > 0, "Should have errors for negative delay")
	print("  Negative delay validation: ✓")

	# 测试有效延迟
	instruction.delay = 1.0
	errors = instruction.validate()
	assert(errors.size() == 0 or not "延迟时间不能为负数" in errors, "Should not have negative delay error")
	print("  Valid delay validation: ✓")
	print("  ✓ Test 3 passed\n")

## 测试 4: 立即切换（不实际执行，只验证结构）
func test_immediate_change():
	print("Test 4: Immediate change structure")

	var instruction_script = load("res://addons/fuse/instructions/change_scene.gd")
	var instruction = instruction_script.new()
	instruction.scene_path = TEST_SCENE_PATH
	instruction.delay = 0.0

	# 验证资源名称更新
	instruction._update_resource_name()
	assert("切换场景" in instruction.resource_name, "Resource name should contain action")
	assert("test_cube.tscn" in instruction.resource_name, "Resource name should contain scene name")
	print("  Resource name: %s" % instruction.resource_name)

	# 验证描述
	var desc = instruction.get_description()
	assert("切换到场景" in desc, "Description should contain action")
	print("  Description: %s" % desc)

	print("  ✓ Test 4 passed\n")
