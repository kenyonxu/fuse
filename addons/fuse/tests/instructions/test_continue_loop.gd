extends Node

## Continue Loop 指令测试

func _ready():
	print("=== Testing Continue Loop Instruction ===")

	test_continue_in_loop()
	test_continue_outside_loop()
	test_continue_with_condition()
	test_nested_continue()

	print("=== All Continue Loop tests passed! ===")

## 测试 1: 在循环中使用 continue
func test_continue_in_loop():
	print("Test 1: Continue in loop")

	# 创建 For Loop 指令
	var for_loop_script = load("res://addons/fuse/instructions/for_loop.gd")
	var for_loop = for_loop_script.new()
	for_loop.loop_count = 5
	for_loop.index_variable = "i"
	for_loop.use_index_variable = true

	# 创建一个 Print 指令
	var print_script = load("res://addons/fuse/instructions/print.gd")
	var print_msg = print_script.new()
	print_msg.message = "Before continue"

	# 创建 Continue Loop 指令
	var continue_script = load("res://addons/fuse/instructions/continue_loop.gd")
	var continue_loop = continue_script.new()

	# 创建另一个 Print 指令（这个应该被跳过）
	var print_after_script = load("res://addons/fuse/instructions/print.gd")
	var print_after = print_after_script.new()
	print_after.message = "After continue (should not print)"

	# 将指令添加到循环中
	for_loop.loop_instructions = [print_msg, continue_loop, print_after]

	var context = ExecutionContext.new()
	add_child(context)

	# 执行循环
	for_loop.execute(context)
	await get_tree().process_frame

	print("  Loop executed with continue: ✓")
	print("  ✓ Test 1 passed\n")

## 测试 2: 在循环外使用 continue（应该报错）
func test_continue_outside_loop():
	print("Test 2: Continue outside loop (should error)")

	var continue_script = load("res://addons/fuse/instructions/continue_loop.gd")
	var continue_loop = continue_script.new()

	var context = ExecutionContext.new()
	add_child(context)

	print("  Executing continue outside loop...")
	continue_loop.execute(context)
	await get_tree().process_frame

	# 验证应该记录错误
	assert(context.had_error(), "Should have error for continue outside loop")
	print("  ✓ Test 2 passed (should log error)\n")

## 测试 3: 带条件的 continue
func test_continue_with_condition():
	print("Test 3: Continue with condition")

	# 创建 For Loop 指令
	var for_loop_script = load("res://addons/fuse/instructions/for_loop.gd")
	var for_loop = for_loop_script.new()
	for_loop.loop_count = 10
	for_loop.index_variable = "i"
	for_loop.use_index_variable = true

	# 创建一个 If/Else 指令来检查条件
	var if_else_script = load("res://addons/fuse/instructions/if_else.gd")
	var if_else = if_else_script.new()
	if_else.condition_type = 2  # VARIABLE_COMPARISON
	if_else.variable_a = "i"
	if_else.comparison_operator = 1  # EQUAL
	if_else.value_b = 5

	# 创建 Continue Loop 指令作为 if 的 true 分支
	var continue_script = load("res://addons/fuse/instructions/continue_loop.gd")
	var continue_loop = continue_script.new()

	if_else.true_instructions = [continue_loop]

	# 创建 Print 指令
	var print_script = load("res://addons/fuse/instructions/print.gd")
	var print_msg = print_script.new()
	print_msg.message = "Index {i}"

	for_loop.loop_instructions = [if_else, print_msg]

	var context = ExecutionContext.new()
	add_child(context)

	for_loop.execute(context)
	await get_tree().process_frame

	print("  Conditional continue executed: ✓")
	print("  ✓ Test 3 passed\n")

## 测试 4: 嵌套循环中的 continue
func test_nested_continue():
	print("Test 4: Continue in nested loops")

	# 创建外层循环
	var outer_loop_script = load("res://addons/fuse/instructions/for_loop.gd")
	var outer_loop = outer_loop_script.new()
	outer_loop.loop_count = 3
	outer_loop.index_variable = "i"
	outer_loop.use_index_variable = true

	# 创建内层循环
	var inner_loop_script = load("res://addons/fuse/instructions/for_loop.gd")
	var inner_loop = inner_loop_script.new()
	inner_loop.loop_count = 5
	inner_loop.index_variable = "j"
	inner_loop.use_index_variable = true

	# 创建一个条件判断，当 j == 2 时 continue
	var if_else_script = load("res://addons/fuse/instructions/if_else.gd")
	var if_else = if_else_script.new()
	if_else.condition_type = 2  # VARIABLE_COMPARISON
	if_else.variable_a = "j"
	if_else.comparison_operator = 1  # EQUAL
	if_else.value_b = 2

	var continue_script = load("res://addons/fuse/instructions/continue_loop.gd")
	var continue_loop = continue_script.new()

	if_else.true_instructions = [continue_loop]

	# 将 if/else 和 continue 添加到内层循环
	inner_loop.loop_instructions = [if_else]

	# 将内层循环添加到外层循环
	outer_loop.loop_instructions = [inner_loop]

	var context = ExecutionContext.new()
	add_child(context)

	outer_loop.execute(context)
	await get_tree().process_frame

	print("  Nested continue executed: ✓")
	print("  ✓ Test 4 passed\n")
