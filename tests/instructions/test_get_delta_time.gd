extends Node

## Get Delta Time 指令测试

func _ready():
	print("=== Testing Get Delta Time ===")
	await test_basic_functionality()
	await test_error_handling()
	await test_variable_scopes()
	print("=== All Get Delta Time tests passed! ===")

## 测试 1: 基础功能
func test_basic_functionality():
	print("Test 1: Basic functionality")

	var context = ExecutionContext.new()
	add_child(context)

	# 等待一帧以确保 context.delta_time 已设置
	await get_tree().process_frame

	# 创建指令
	var instruction = load("res://addons/fuse/instructions/get_delta_time.gd").new()
	instruction.save_to_variable = "delta"
	instruction.is_global = false

	# 执行指令
	instruction.execute(context)
	await get_tree().process_frame

	# 验证变量已设置
	var delta = context.get_variable("delta")
	assert(delta != null, "应该设置 delta 变量")
	assert(delta is float, "Delta 应该是浮点数")
	assert(delta >= 0.0, "Delta 应该大于或等于 0")
	print("  ✓ Delta 时间: %.6f 秒" % delta)
	print("  ✓ Test 1 passed\n")

	context.queue_free()

## 测试 2: 错误处理
func test_error_handling():
	print("Test 2: Error handling")

	var context = ExecutionContext.new()
	add_child(context)

	# 测试 2.1: 变量名为空
	print("  Test 2.1: Empty variable name")
	var instruction = load("res://addons/fuse/instructions/get_delta_time.gd").new()
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

	await get_tree().process_frame

	# 测试 3.1: 保存到本地变量
	print("  Test 3.1: Save to local variable")
	var instruction1 = load("res://addons/fuse/instructions/get_delta_time.gd").new()
	instruction1.save_to_variable = "local_delta"
	instruction1.is_global = false
	instruction1.execute(context)
	await get_tree().process_frame

	var local_var = context.get_variable("local_delta")
	assert(local_var != null, "应该找到本地变量")
	assert(local_var is float, "本地变量应该是浮点数")
	print("    ✓ 本地变量设置成功: %.6f 秒" % local_var)

	# 测试 3.2: 保存到全局变量
	print("  Test 3.2: Save to global variable")
	var instruction2 = load("res://addons/fuse/instructions/get_delta_time.gd").new()
	instruction2.save_to_variable = "global_delta"
	instruction2.is_global = true
	instruction2.execute(context)
	await get_tree().process_frame

	if context.global_variables:
		var global_var = context.global_variables.get_variable("global_delta")
		assert(global_var != null, "应该找到全局变量")
		assert(global_var is float, "全局变量应该是浮点数")
		print("    ✓ 全局变量设置成功: %.6f 秒" % global_var)
	else:
		print("    ⚠ 全局变量管理器未初始化")

	context.queue_free()
	if context.global_variables and is_instance_valid(context.global_variables):
		context.global_variables.queue_free()
	print("  ✓ Test 3 passed\n")

## 测试 4: 多帧测试
func test_multiple_frames():
	print("Test 4: Multiple frames")

	var context = ExecutionContext.new()
	add_child(context)

	var deltas = []
	for i in range(5):
		await get_tree().process_frame
		var instruction = load("res://addons/fuse/instructions/get_delta_time.gd").new()
		instruction.save_to_variable = "delta_test"
		instruction.is_global = false
		instruction.execute(context)
		await get_tree().process_frame

		var delta = context.get_variable("delta_test")
		if delta is float:
			deltas.append(delta)
			print("  帧 %d: %.6f 秒" % [i + 1, delta])

	assert(deltas.size() > 0, "应该至少有一个有效的 delta 值")
	print("  ✓ 测试了 %d 帧" % deltas.size())
	print("  ✓ Test 4 passed\n")

	context.queue_free()
