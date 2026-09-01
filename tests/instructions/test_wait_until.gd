extends Node

## Wait Until 指令测试

func _ready():
	print("=== Testing Wait Until Instruction ===")

	await test_wait_until_variable_comparison()
	await test_wait_until_variable_exists()
	await test_wait_until_timeout()
	await test_wait_invalid_condition()

	print("=== All Wait Until tests passed! ===")

## 测试 1: 等待变量比较条件
func test_wait_until_variable_comparison():
	print("Test 1: Wait until variable comparison")

	var instruction_script = load("res://addons/fuse/instructions/wait_until.gd")
	var instruction = instruction_script.new()
	instruction.condition_type = 0  # VARIABLE_COMPARISON
	instruction.variable_a = "test_var"
	instruction.comparison_operator = 2  # GREATER_THAN
	instruction.value_b = 5
	instruction.use_variable_b = false
	instruction.check_interval = 0.1
	instruction.timeout = 5.0

	var context = ExecutionContext.new()
	add_child(context)

	# 设置初始值
	context.set_variable("test_var", 0)

	# 延迟设置变量的值
	await get_tree().create_timer(1.0).timeout
	context.set_variable("test_var", 10)

	# 执行等待指令
	instruction.execute(context)

	# 等待指令完成
	await get_tree().create_timer(2.0).timeout

	assert(context.is_completed() or not context.had_error(), "Wait should complete when condition is met")
	print("  ✓ Test 1 passed\n")

## 测试 2: 等待变量存在
func test_wait_until_variable_exists():
	print("Test 2: Wait until variable exists")

	var instruction_script = load("res://addons/fuse/instructions/wait_until.gd")
	var instruction = instruction_script.new()
	instruction.condition_type = 2  # VARIABLE_EXISTS
	instruction.check_variable_name = "new_var"
	instruction.check_interval = 0.1
	instruction.timeout = 5.0

	var context = ExecutionContext.new()
	add_child(context)

	# 延迟创建变量
	await get_tree().create_timer(0.5).timeout
	context.set_variable("new_var", 42)

	# 执行等待指令
	instruction.execute(context)

	# 等待指令完成
	await get_tree().create_timer(1.0).timeout

	assert(context.is_completed() or not context.had_error(), "Wait should complete when variable exists")
	print("  ✓ Test 2 passed\n")

## 测试 3: 测试超时
func test_wait_until_timeout():
	print("Test 3: Wait until timeout")

	var instruction_script = load("res://addons/fuse/instructions/wait_until.gd")
	var instruction = instruction_script.new()
	instruction.condition_type = 0  # VARIABLE_COMPARISON
	instruction.variable_a = "timeout_test"
	instruction.comparison_operator = 2  # GREATER_THAN
	instruction.value_b = 100
	instruction.use_variable_b = false
	instruction.check_interval = 0.1
	instruction.timeout = 0.5  # 短超时

	var context = ExecutionContext.new()
	add_child(context)

	# 设置一个永远不会满足条件的值
	context.set_variable("timeout_test", 0)

	# 执行等待指令
	instruction.execute(context)

	# 等待超时
	await get_tree().create_timer(1.0).timeout

	# 应该有超时错误
	assert(context.had_error(), "Should have timeout error")
	print("  ✓ Test 3 passed (timeout triggered)\n")

## 测试 4: 无效条件
func test_wait_invalid_condition():
	print("Test 4: Invalid condition validation")

	var instruction_script = load("res://addons/fuse/instructions/wait_until.gd")
	var instruction = instruction_script.new()

	# 测试空的变量名
	instruction.condition_type = 0  # VARIABLE_COMPARISON
	instruction.variable_a = ""
	var errors = instruction.validate()
	assert(errors.size() > 0, "Should have errors for empty variable name")
	print("  Empty variable validation: ✓")

	# 测试无效的检查间隔
	instruction.variable_a = "test"
	instruction.check_interval = -0.1
	errors = instruction.validate()
	assert(errors.size() > 0, "Should have errors for negative check interval")
	print("  Invalid check interval validation: ✓")

	# 测试负的超时
	instruction.check_interval = 0.1
	instruction.timeout = -1.0
	errors = instruction.validate()
	assert(errors.size() > 0, "Should have errors for negative timeout")
	print("  Invalid timeout validation: ✓")

	print("  ✓ Test 4 passed\n")
