extends Node

## ReloadScene 指令测试

func _ready():
	print("=== Testing ReloadScene ===")
	test_basic_functionality()
	test_delayed_reload()
	test_error_handling()
	print("=== All ReloadScene tests passed! ===")
	print("注意: 实际重载场景会销毁测试节点，所以测试只是验证指令逻辑")

## 测试 1: 基础功能 - 立即重载（不实际执行，只验证逻辑）
func test_basic_functionality():
	print("Test 1: Basic functionality - immediate reload")

	var instruction_script = load("res://addons/fuse/instructions/reload_scene.gd")
	var instruction = instruction_script.new()
	instruction.delay = 0.0

	var context = ExecutionContext.new()
	add_child(context)

	# 验证参数设置
	assert(instruction.delay == 0.0, "Delay should be 0.0")
	print("  ✓ Instruction configured correctly")

	# 验证描述信息
	var description = instruction.get_description()
	assert(description.contains("重载当前场景"), "Description should mention reloading")
	print("  ✓ Description: %s" % description)

	# 验证验证方法
	var errors = instruction.validate()
	assert(errors.size() == 0, "Should have no validation errors")
	print("  ✓ Validation passed")

	print("  ✓ Test 1 passed\n")

## 测试 2: 延迟重载（不实际执行，只验证逻辑）
func test_delayed_reload():
	print("Test 2: Delayed reload")

	var instruction_script = load("res://addons/fuse/instructions/reload_scene.gd")
	var instruction = instruction_script.new()
	instruction.delay = 1.5

	var context = ExecutionContext.new()
	add_child(context)

	# 验证参数设置
	assert(instruction.delay == 1.5, "Delay should be 1.5")
	print("  ✓ Instruction configured with delay")

	# 验证描述信息
	var description = instruction.get_description()
	assert(description.contains("延迟"), "Description should mention delay")
	assert(description.contains("1.5"), "Description should show delay value")
	print("  ✓ Description: %s" % description)

	print("  ✓ Test 2 passed\n")

## 测试 3: 错误处理
func test_error_handling():
	print("Test 3: Error handling")

	var instruction_script = load("res://addons/fuse/instructions/reload_scene.gd")
	var context = ExecutionContext.new()
	add_child(context)

	# 测试 3.1: 无效的延迟时间（负数）
	print("  Test 3.1: Invalid delay (negative)")
	var instruction1 = instruction_script.new()
	instruction1.delay = -1.0

	instruction1.execute(context)
	await get_tree().process_frame

	assert(context.had_error(), "Should have error for delay < 0")
	print("    ✓ Correctly rejected delay < 0")

	# 测试 3.2: 验证方法
	print("  Test 3.2: Validation method")
	var instruction2 = instruction_script.new()
	instruction2.delay = -1.0

	var errors = instruction2.validate()
	assert(errors.size() == 1, "Should have 1 validation error")
	assert(errors[0].contains("不能为负数"), "Error message should mention negative value")
	print("    ✓ Validation correctly identified error")

	# 测试 3.3: 有效值（零延迟）
	print("  Test 3.3: Valid value (zero delay)")
	var instruction3 = instruction_script.new()
	instruction3.delay = 0.0

	errors = instruction3.validate()
	assert(errors.size() == 0, "Should have no validation errors for delay = 0")
	print("    ✓ Zero delay is valid")

	print("  ✓ Test 3 passed\n")
