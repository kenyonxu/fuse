extends Node

## Break Loop 指令测试

func _ready():
	print("=== Testing Break Loop Instruction ===")

	test_break_from_loop()
	test_break_outside_loop()
	test_break_with_condition()
	test_nested_break()

	print("=== All Break Loop tests passed! ===")

## 测试 1: 在循环中使用 break
func test_break_from_loop():
	print("Test 1: Break from loop")

	# 创建 For Loop 指令
	var for_loop_script = load("res://addons/fuse/instructions/for_loop.gd")
	var for_loop = for_loop_script.new()
	for_loop.loop_count = 10
	for_loop.use_index_variable = false

	# 创建一个 Print 指令
	var print_script = load("res://addons/fuse/instructions/print.gd")
	var print_msg = print_script.new()
	print_msg.message = "Iteration"

	# 创建 Break Loop 指令
	var break_script = load("res://addons/fuse/instructions/break_loop.gd")
	var break_loop = break_script.new()

	# 将指令添加到循环中
	for_loop.loop_instructions = [print_msg, break_loop]

	var context = ExecutionContext.new()
	add_child(context)

	# 执行循环
	for_loop.execute(context)
	await get_tree().process_frame

	print("  Loop executed and break triggered: ✓")
	print("  ✓ Test 1 passed\n")

## 测试 2: 在循环外使用 break（应该报错）
func test_break_outside_loop():
	print("Test 2: Break outside loop (should error)")

	var break_script = load("res://addons/fuse/instructions/break_loop.gd")
	var break_loop = break_script.new()

	var context = ExecutionContext.new()
	add_child(context)

	print("  Executing break outside loop...")
	break_loop.execute(context)
	await get_tree().process_frame

	# 验证应该记录错误
	assert(context.had_error(), "Should have error for break outside loop")
	print("  ✓ Test 2 passed (should log error)\n")

## 测试 3: 带条件的 break
func test_break_with_condition():
	print("Test 3: Break with condition")

	# 创建 For Loop 指令
	var for_loop_script = load("res://addons/fuse/instructions/for_loop.gd")
	var for_loop = for_loop_script.new()
	for_loop.loop_count = 100
	for_loop.index_variable = "i"
	for_loop.use_index_variable = true

	# 创建一个 If/Else 指令来检查条件
	var if_else_script = load("res://addons/fuse/instructions/if_else.gd")
	var if_else = if_else_script.new()
	if_else.condition_type = 2  # VARIABLE_COMPARISON
	if_else.variable_a = "i"
	if_else.comparison_operator = 3  # GREATER_THAN
	if_else.value_b = 5

	# 创建 Break Loop 指令作为 if 的 true 分支
	var break_script = load("res://addons/fuse/instructions/break_loop.gd")
	var break_loop = break_script.new()

	if_else.true_instructions = [break_loop]

	for_loop.loop_instructions = [if_else]

	var context = ExecutionContext.new()
	add_child(context)

	for_loop.execute(context)
	await get_tree().process_frame

	print("  Conditional break executed: ✓")
	print("  ✓ Test 3 passed\n")

## 测试 4: 嵌套循环中的 break
func test_nested_break():
	print("Test 4: Break in nested loops")

	# 创建外层循环
	var outer_loop_script = load("res://addons/fuse/instructions/for_loop.gd")
	var outer_loop = outer_loop_script.new()
	outer_loop.loop_count = 5
	outer_loop.index_variable = "i"
	outer_loop.use_index_variable = true

	# 创建内层循环
	var inner_loop_script = load("res://addons/fuse/instructions/for_loop.gd")
	var inner_loop = inner_loop_script.new()
	inner_loop.loop_count = 10
	inner_loop.index_variable = "j"
	inner_loop.use_index_variable = true

	# 创建一个条件判断，当 j > 3 时 break
	var if_else_script = load("res://addons/fuse/instructions/if_else.gd")
	var if_else = if_else_script.new()
	if_else.condition_type = 2  # VARIABLE_COMPARISON
	if_else.variable_a = "j"
	if_else.comparison_operator = 3  # GREATER_THAN
	if_else.value_b = 3

	var break_script = load("res://addons/fuse/instructions/break_loop.gd")
	var break_loop = break_script.new()

	if_else.true_instructions = [break_loop]

	# 将 if/else 和 break 添加到内层循环
	inner_loop.loop_instructions = [if_else]

	# 将内层循环添加到外层循环
	outer_loop.loop_instructions = [inner_loop]

	var context = ExecutionContext.new()
	add_child(context)

	outer_loop.execute(context)
	await get_tree().process_frame

	print("  Nested break executed: ✓")
	print("  ✓ Test 4 passed\n")
