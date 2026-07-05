extends Node

## Get Scene Path 指令测试

func _ready():
	print("=== Testing Get Scene Path ===")
	await test_basic_functionality()
	await test_error_handling()
	await test_variable_scopes()
	print("=== All Get Scene Path tests passed! ===")

## 测试 1: 基础功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	var context = ExecutionContext.new()
	add_child(context)

	# 测试 1.1: 获取场景文件路径
	print("  Test 1.1: Get scene file path")
	var instruction1 = load("res://addons/fuse/instructions/get_scene_path.gd").new()
	instruction1.path_mode = 0  # CURRENT_SCENE
	instruction1.save_to_variable = "scene_path"
	instruction1.is_global = false
	instruction1.execute(context)
	await get_tree().process_frame

	var scene_path = context.get_variable("scene_path")
	assert(scene_path != null, "应该设置场景路径变量")
	if scene_path is String:
		print("    ✓ 场景路径类型正确: ", scene_path)
		if scene_path.is_empty():
			print("    ⚠ 场景路径为空（可能是运行时动态场景）")
	else:
		print("    ✗ 场景路径类型错误: ", typeof(scene_path))

	# 测试 1.2: 获取根节点路径
	print("  Test 1.2: Get root node path")
	var instruction2 = load("res://addons/fuse/instructions/get_scene_path.gd").new()
	instruction2.path_mode = 1  # ROOT_NODE
	instruction2.save_to_variable = "root_path"
	instruction2.is_global = false
	instruction2.execute(context)
	await get_tree().process_frame

	var root_path = context.get_variable("root_path")
	assert(root_path != null, "应该设置根节点路径变量")
	assert(root_path is String, "根节点路径应该是字符串")
	print("    ✓ 根节点路径: ", root_path)

	context.queue_free()
	print("  ✓ Test 1 passed\n")

## 测试 2: 错误处理
func test_error_handling():
	print("Test 2: Error handling")

	var context = ExecutionContext.new()
	add_child(context)

	# 测试 2.1: 变量名为空
	print("  Test 2.1: Empty variable name")
	var instruction = load("res://addons/fuse/instructions/get_scene_path.gd").new()
	instruction.path_mode = 0
	instruction.save_to_variable = ""
	instruction.is_global = false
	instruction.execute(context)
	await get_tree().process_frame
	assert(context.had_error(), "应该报告错误：变量名为空")
	print("    ✓ 正确处理空变量名")

	context.queue_free()
	print("  ✓ Test 2 passed\n")

## 测试 3: 变量作用域
func test_variable_scopes():
	print("Test 3: Variable scopes")

	var context = ExecutionContext.new()
	add_child(context)

	# 设置全局变量管理器
	if not context.global_variables:
		context.global_variables = GlobalVariableManager.new()
		add_child(context.global_variables)

	# 测试 3.1: 保存到本地变量
	print("  Test 3.1: Save to local variable")
	var instruction1 = load("res://addons/fuse/instructions/get_scene_path.gd").new()
	instruction1.path_mode = 1
	instruction1.save_to_variable = "local_path"
	instruction1.is_global = false
	instruction1.execute(context)
	await get_tree().process_frame

	var local_var = context.get_variable("local_path")
	assert(local_var != null, "应该找到本地变量")
	print("    ✓ 本地变量设置成功")

	# 测试 3.2: 保存到全局变量
	print("  Test 3.2: Save to global variable")
	var instruction2 = load("res://addons/fuse/instructions/get_scene_path.gd").new()
	instruction2.path_mode = 1
	instruction2.save_to_variable = "global_path"
	instruction2.is_global = true
	instruction2.execute(context)
	await get_tree().process_frame

	if context.global_variables:
		var global_var = context.global_variables.get_variable("global_path")
		assert(global_var != null, "应该找到全局变量")
		print("    ✓ 全局变量设置成功")
	else:
		print("    ⚠ 全局变量管理器未初始化")

	context.queue_free()
	if context.global_variables and is_instance_valid(context.global_variables):
		context.global_variables.queue_free()
	print("  ✓ Test 3 passed\n")
