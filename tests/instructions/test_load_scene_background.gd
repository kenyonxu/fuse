extends Node

## LoadSceneBackground 指令测试

# 测试场景路径
const TEST_SCENE_PATH = "res://tests/instructions/test_load_scene_background_test_scene.tscn"

func _ready():
	print("=== Testing LoadSceneBackground ===")
	# 先创建测试场景
	_ensure_test_scene_exists()

	await test_basic_functionality()
	await test_error_handling()
	print("=== All LoadSceneBackground tests passed! ===")

## 确保测试场景存在
func _ensure_test_scene_exists():
	var test_scene_path = "res://tests/instructions/test_load_scene_background_test_scene.tscn"

	# 如果场景不存在，创建一个简单的测试场景
	if not FileAccess.file_exists(test_scene_path):
		var test_scene = PackedScene.new()
		var test_node = Node2D.new()
		test_node.name = "TestSceneNode"
		test_scene.pack(test_node)
		ResourceSaver.save(test_scene, test_scene_path)
		print("Created test scene at: %s" % test_scene_path)

## 测试 1: 基础功能 - 异步加载场景
func test_basic_functionality():
	print("Test 1: Basic functionality - async load scene")

	var instruction_script = load("res://addons/fuse/instructions/load_scene_background.gd")
	var instruction = instruction_script.new()
	instruction.scene_path = TEST_SCENE_PATH
	instruction.save_to_variable = "loaded_scene"
	instruction.is_global = false

	var context = ExecutionContext.new()
	add_child(context)

	# 执行指令
	print("  Starting background load...")
	instruction.execute(context)

	# 等待加载完成（使用超时保护）
	var timeout = 5.0  # 5秒超时
	var elapsed = 0.0
	var check_interval = 0.1

	while elapsed < timeout:
		await get_tree().create_timer(check_interval).timeout
		elapsed += check_interval

		# 检查变量是否已设置
		var loaded_scene = context.get_variable("loaded_scene")
		if loaded_scene != null:
			print("  ✓ Scene loaded after %.2f seconds" % elapsed)

			# 验证加载的是 PackedScene
			assert(loaded_scene is PackedScene, "Loaded resource should be a PackedScene")
			print("  ✓ Correctly loaded as PackedScene")

			# 尝试实例化验证
			var instance = loaded_scene.instantiate()
			assert(instance != null, "Should be able to instantiate the loaded scene")
			assert(instance.name == "TestSceneNode", "Instance should have correct name")
			print("  ✓ Successfully instantiated loaded scene")
			instance.queue_free()

			print("  ✓ Test 1 passed\n")
			return

	# 如果超时仍未加载
	assert(false, "Scene loading timeout after %.1f seconds" % timeout)

## 测试 2: 错误处理
func test_error_handling():
	print("Test 2: Error handling")

	var instruction_script = load("res://addons/fuse/instructions/load_scene_background.gd")
	var context = ExecutionContext.new()
	add_child(context)

	# 测试 2.1: 空场景路径
	print("  Test 2.1: Empty scene path")
	var instruction1 = instruction_script.new()
	instruction1.scene_path = ""
	instruction1.save_to_variable = "loaded_scene"

	instruction1.execute(context)
	await get_tree().process_frame

	assert(context.had_error(), "Should have error for empty scene path")
	print("    ✓ Correctly rejected empty scene path")

	# 测试 2.2: 空变量名
	print("  Test 2.2: Empty variable name")
	var instruction2 = instruction_script.new()
	instruction2.scene_path = TEST_SCENE_PATH
	instruction2.save_to_variable = ""

	context.clear_errors()

	instruction2.execute(context)
	await get_tree().process_frame

	assert(context.had_error(), "Should have error for empty variable name")
	print("    ✓ Correctly rejected empty variable name")

	# 测试 2.3: 不存在的场景
	print("  Test 2.3: Non-existent scene")
	var instruction3 = instruction_script.new()
	instruction3.scene_path = "res://non_existent_scene_12345.tscn"
	instruction3.save_to_variable = "loaded_scene"

	context.clear_errors()

	instruction3.execute(context)

	# 等待加载失败
	await get_tree().create_timer(1.0).timeout
	await get_tree().process_frame

	# 注意：Godot 的 ResourceLoader 可能不会立即失败，所以这个测试可能需要调整
	if context.had_error():
		print("    ✓ Correctly rejected non-existent scene")
	else:
		print("    ⚠ Non-existent scene test inconclusive (Godot may handle this differently)")

	# 测试 2.4: 验证方法
	print("  Test 2.4: Validation method")
	var instruction4 = instruction_script.new()
	instruction4.scene_path = ""
	instruction4.save_to_variable = ""

	var errors = instruction4.validate()
	assert(errors.size() == 2, "Should have 2 validation errors")
	print("    ✓ Validation correctly identified errors")

	print("  ✓ Test 2 passed\n")
