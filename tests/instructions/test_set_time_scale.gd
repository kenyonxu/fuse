extends Node

## SetTimeScale 指令测试

func _ready():
	print("=== Testing SetTimeScale ===")
	test_basic_functionality()
	test_temporary_time_scale()
	test_error_handling()
	print("=== All SetTimeScale tests passed! ===")

## 测试 1: 基础功能 - 永久设置时间缩放
func test_basic_functionality():
	print("Test 1: Basic functionality - permanent time scale")

	var instruction_script = load("res://addons/fuse/instructions/set_time_scale.gd")
	var instruction = instruction_script.new()
	instruction.time_scale = 0.5
	instruction.duration = 0.0  # 永久

	var context = ExecutionContext.new()
	add_child(context)

	# 保存原始时间缩放
	var original_scale = Engine.time_scale

	# 执行指令
	instruction.execute(context)
	await get_tree().process_frame

	# 验证时间缩放已设置
	assert(Engine.time_scale == 0.5, "Time scale should be 0.5")
	print("  ✓ Time scale set to 0.5")

	# 恢复原始时间缩放
	Engine.time_scale = original_scale
	print("  ✓ Test 1 passed\n")

## 测试 2: 临时时间缩放（自动恢复）
func test_temporary_time_scale():
	print("Test 2: Temporary time scale (auto restore)")

	var instruction_script = load("res://addons/fuse/instructions/set_time_scale.gd")
	var instruction = instruction_script.new()
	instruction.time_scale = 2.0
	instruction.duration = 0.5  # 0.5秒后恢复

	var context = ExecutionContext.new()
	add_child(context)

	# 保存原始时间缩放
	var original_scale = Engine.time_scale

	# 执行指令
	instruction.execute(context)
	await get_tree().process_frame

	# 验证时间缩放已设置
	assert(Engine.time_scale == 2.0, "Time scale should be 2.0")
	print("  ✓ Time scale set to 2.0")

	# 等待恢复
	await get_tree().create_timer(0.6).timeout
	await get_tree().process_frame

	# 验证时间缩放已恢复
	assert(Engine.time_scale == original_scale, "Time scale should be restored")
	print("  ✓ Time scale restored to original value")
	print("  ✓ Test 2 passed\n")

## 测试 3: 错误处理
func test_error_handling():
	print("Test 3: Error handling")

	var instruction_script = load("res://addons/fuse/instructions/set_time_scale.gd")
	var context = ExecutionContext.new()
	add_child(context)

	# 测试 3.1: 无效的时间缩放值（0）
	print("  Test 3.1: Invalid time scale (0)")
	var instruction1 = instruction_script.new()
	instruction1.time_scale = 0.0
	instruction1.duration = 0.0

	instruction1.execute(context)
	await get_tree().process_frame

	assert(context.had_error(), "Should have error for time_scale = 0")
	print("    ✓ Correctly rejected time_scale = 0")

	# 测试 3.2: 无效的时间缩放值（负数）
	print("  Test 3.2: Invalid time scale (negative)")
	var instruction2 = instruction_script.new()
	instruction2.time_scale = -1.0
	instruction2.duration = 0.0

	# 重置错误状态
	context.clear_errors()

	instruction2.execute(context)
	await get_tree().process_frame

	assert(context.had_error(), "Should have error for time_scale < 0")
	print("    ✓ Correctly rejected time_scale < 0")

	# 测试 3.3: 无效的持续时间（负数）
	print("  Test 3.3: Invalid duration (negative)")
	var instruction3 = instruction_script.new()
	instruction3.time_scale = 1.0
	instruction3.duration = -1.0

	context.clear_errors()

	instruction3.execute(context)
	await get_tree().process_frame

	assert(context.had_error(), "Should have error for duration < 0")
	print("    ✓ Correctly rejected duration < 0")

	# 测试 3.4: 验证方法
	print("  Test 3.4: Validation method")
	var instruction4 = instruction_script.new()
	instruction4.time_scale = 0.0
	instruction4.duration = -1.0

	var errors = instruction4.validate()
	assert(errors.size() == 2, "Should have 2 validation errors")
	print("    ✓ Validation correctly identified errors")

	print("  ✓ Test 3 passed\n")
