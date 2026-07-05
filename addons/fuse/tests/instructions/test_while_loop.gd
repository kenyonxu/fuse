extends Node

## While Loop 指令测试

func _ready():
	print("=== While Loop 指令测试开始 ===\n")

	await test_while_true()
	await test_while_false()
	await test_max_iterations()
	await test_validation()

	print("\n=== While Loop 指令测试完成 ===")

## 测试 1: While True 循环
func test_while_true():
	print("\n--- 测试 1: While True 循环（简化版）---")

	var while_loop_script = load("res://addons/fuse/instructions/while_loop.gd")
	var while_loop = while_loop_script.new()
	var context = ExecutionContext.new()
	add_child(context)

	# 设置条件变量（初始为 true）
	context.set_variable("counter", 0)

	# 简化：不添加复杂的循环体指令，只测试循环控制本身
	while_loop.condition_variable = "counter"
	while_loop.condition_check = 0  # IS_TRUE
	while_loop.max_iterations = 5  # 限制为5次迭代

	while_loop.execute(context)

	await context.finished
	await get_tree().process_frame

	# 验证循环执行了指定次数
	assert(while_loop.get_current_iteration() == 5, "应该执行5次迭代")
	print("✓ While True 循环测试通过（执行了 %d 次迭代）" % while_loop.get_current_iteration())

	context.queue_free()

## 测试 2: While False 循环
func test_while_false():
	print("\n--- 测试 2: While False 循环（不执行）---")

	var while_loop = WhileLoop.new()
	var context = ExecutionContext.new()
	add_child(context)

	# 设置条件为 false
	context.set_variable("should_continue", false)

	# 创建打印指令
	var print_inst = Print.new()
	print_inst.message = "这条不应该执行"

	while_loop.condition_variable = "should_continue"
	while_loop.condition_check = 0  # IS_TRUE
	while_loop.loop_instructions.append(print_inst)

	while_loop.execute(context)

	await context.finished
	await get_tree().process_frame

	assert(while_loop.is_completed(), "While False 应该成功完成（不执行循环体）")
	print("✓ While False 循环测试通过（循环体未执行）")

	context.queue_free()

## 测试 3: 最大迭代次数限制
func test_max_iterations():
	print("\n--- 测试 3: 最大迭代次数限制 ---")

	var while_loop = WhileLoop.new()
	var context = ExecutionContext.new()
	add_child(context)

	# 设置条件变量（永远为真）
	context.set_variable("always_true", true)

	# 创建打印指令
	var print_inst = Print.new()
	print_inst.message = "迭代"

	while_loop.condition_variable = "always_true"
	while_loop.condition_check = 0  # IS_TRUE
	while_loop.max_iterations = 10
	while_loop.loop_instructions.append(print_inst)

	while_loop.execute(context)

	await context.finished
	await get_tree().process_frame

	assert(while_loop.is_completed(), "While Loop 应该成功完成")
	assert(while_loop.get_current_iteration() == 10, "应该执行10次迭代后停止")
	print("✓ 最大迭代次数限制测试通过（执行了 %d 次迭代）" % while_loop.get_current_iteration())

	context.queue_free()

## 测试 4: 验证参数
func test_validation():
	print("\n--- 测试 4: 验证参数 ---")

	var while_loop = WhileLoop.new()

	# 测试空条件变量名
	while_loop.condition_variable = ""
	var errors = while_loop.validate()
	assert(errors.size() > 0, "空条件变量名应该产生验证错误")
	print("✓ 空条件变量名验证通过")

	# 测试无效的最大迭代次数
	while_loop.condition_variable = "test"
	while_loop.max_iterations = 0
	errors = while_loop.validate()
	assert(errors.size() > 0, "最大迭代次数为0应该产生验证错误")
	print("✓ 最大迭代次数验证通过")

	# 测试负数最大迭代次数
	while_loop.max_iterations = -1
	errors = while_loop.validate()
	assert(errors.size() > 0, "负数最大迭代次数应该产生验证错误")
	print("✓ 负数最大迭代次数验证通过")

	print("✓ 所有验证测试通过")
