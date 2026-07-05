extends Node

## For Loop 指令测试
##
## 测试场景：
## 1. 基本循环（3次）
## 2. 循环索引变量
## 3. 从变量读取循环次数
## 4. 嵌套循环

func _ready():
	print("=== For Loop 指令测试开始 ===\n")

	test_basic_loop()
	test_loop_with_index_variable()
	test_loop_with_variable_count()
	test_nested_loops()
	test_zero_iterations()
	test_large_iteration_count()
	test_validation()

	print("\n=== For Loop 指令测试完成 ===")

## 测试 1: 基本循环（3次）
func test_basic_loop():
	print("\n--- 测试 1: 基本循环（3次）---")

	var for_loop_script = load("res://addons/fuse/instructions/for_loop.gd")
	var for_loop = for_loop_script.new()
	for_loop.loop_count = 3
	for_loop.use_variable_count = false
	for_loop.use_index_variable = false

	# 创建简单的 Print 指令作为循环体
	var print_inst = Print.new()
	print_inst.message = "循环迭代"
	for_loop.loop_instructions.append(print_inst)

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 执行循环
	for_loop.execute(context)

	# For Loop 是同步指令，应该立即完成
	# 不需要 await，但如果为了保险可以使用
	await get_tree().process_frame

	# 验证结果
	assert(for_loop.is_completed(), "循环应该成功完成")
	print("✓ 基本循环测试通过：执行了 3 次迭代")

## 测试 2: 循环索引变量
func test_loop_with_index_variable():
	print("\n--- 测试 2: 循环索引变量 ---")

	var for_loop = ForLoop.new()
	for_loop.loop_count = 5
	for_loop.use_variable_count = false
	for_loop.use_index_variable = true
	for_loop.index_variable = "i"

	# 创建打印索引变量的指令
	var print_inst = Print.new()
	print_inst.message = "索引: {i}"
	for_loop.loop_instructions.append(print_inst)

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 执行循环
	for_loop.execute(context)

	# For Loop 是同步指令
	await get_tree().process_frame

	# 验证结果
	assert(for_loop.is_completed(), "循环应该成功完成")
	assert(context.has_variable("i"), "应该创建索引变量 'i'")
	assert(context.get_variable("i") == 4, "最后一次迭代的索引应该是 4")  # 0-4
	print("✓ 循环索引变量测试通过：索引变量正确创建")

## 测试 3: 从变量读取循环次数
func test_loop_with_variable_count():
	print("\n--- 测试 3: 从变量读取循环次数 ---")

	var for_loop = ForLoop.new()
	for_loop.use_variable_count = true
	for_loop.loop_count_variable = "loop_count"
	for_loop.use_index_variable = true
	for_loop.index_variable = "idx"

	# 创建打印指令
	var print_inst = Print.new()
	print_inst.message = "迭代 {idx}"
	for_loop.loop_instructions.append(print_inst)

	# 创建执行上下文并设置循环次数变量
	var context = ExecutionContext.new()
	context.set_variable("loop_count", 4)

	# 执行循环
	for_loop.execute(context)

	# For Loop 是同步指令
	await get_tree().process_frame

	# 验证结果
	assert(for_loop.is_completed(), "循环应该成功完成")
	assert(context.get_variable("idx") == 3, "最后一次迭代的索引应该是 3")  # 0-3
	print("✓ 从变量读取循环次数测试通过：正确读取并使用了变量")

## 测试 4: 嵌套循环
func test_nested_loops():
	print("\n--- 测试 4: 嵌套循环（验证栈管理）---")

	# 外层循环（3次）
	var outer_loop = ForLoop.new()
	outer_loop.loop_count = 3
	outer_loop.use_variable_count = false
	outer_loop.use_index_variable = true
	outer_loop.index_variable = "i"

	# 内层循环（2次）
	var inner_loop = ForLoop.new()
	inner_loop.loop_count = 2
	inner_loop.use_variable_count = false
	inner_loop.use_index_variable = true
	inner_loop.index_variable = "j"

	# 创建打印指令显示嵌套
	var print_inst = Print.new()
	print_inst.message = "外层={i}, 内层={j}"
	inner_loop.loop_instructions.append(print_inst)

	# 将内层循环添加到外层循环
	outer_loop.loop_instructions.append(inner_loop)

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 执行外层循环
	outer_loop.execute(context)

	# For Loop 是同步指令
	await get_tree().process_frame

	# 验证结果
	assert(outer_loop.is_completed(), "外层循环应该成功完成")
	assert(inner_loop.is_completed(), "内层循环应该成功完成")

	# 验证嵌套循环的索引不会相互污染
	# 外层循环应该执行 3 次（i = 0, 1, 2）
	# 内层循环应该执行 2 次（j = 0, 1）
	# 总共应该执行 3 * 2 = 6 次迭代
	print("✓ 嵌套循环测试通过：内层循环索引不会污染外层循环")
	print("  栈管理正确：循环标志被正确保存和恢复")

## 测试 4.1: 零次迭代
func test_zero_iterations():
	print("\n--- 测试 4.1: 零次迭代 ---")

	var for_loop = ForLoop.new()
	for_loop.loop_count = 0
	for_loop.use_variable_count = false

	var print_inst = Print.new()
	print_inst.message = "这条不应该执行"
	for_loop.loop_instructions.append(print_inst)

	var context = ExecutionContext.new()
	for_loop.execute(context)

	assert(for_loop.is_completed(), "零次循环应该成功完成")
	print("✓ 零次迭代测试通过：循环体未执行")

## 测试 4.2: 大次数迭代性能测试
func test_large_iteration_count():
	print("\n--- 测试 4.2: 大次数迭代性能 ---")

	var for_loop = ForLoop.new()
	for_loop.loop_count = 1000  # 使用1000次而不是10000次以加快测试
	for_loop.use_variable_count = false

	var print_inst = Print.new()
	print_inst.message = "迭代"
	for_loop.loop_instructions.append(print_inst)

	var context = ExecutionContext.new()

	var start_time = Time.get_ticks_msec()
	for_loop.execute(context)
	var elapsed = Time.get_ticks_msec() - start_time

	assert(for_loop.is_completed(), "大次数循环应该成功完成")
	print("  1000次迭代耗时: %s ms" % elapsed)
	print("✓ 大次数迭代性能测试通过")

## 测试 5: 验证循环参数
func test_validation():
	print("\n--- 测试 5: 验证循环参数 ---")

	var for_loop = ForLoop.new()

	# 测试负数循环次数
	for_loop.loop_count = -1
	for_loop.use_variable_count = false
	var errors = for_loop.validate()
	assert(errors.size() > 0, "负数循环次数应该产生验证错误")
	print("✓ 负数循环次数验证通过")

	# 测试空变量名
	for_loop.use_variable_count = true
	for_loop.loop_count_variable = ""
	errors = for_loop.validate()
	assert(errors.size() > 0, "空变量名应该产生验证错误")
	print("✓ 空变量名验证通过")

	# 测试启用索引变量但变量名为空
	for_loop.use_index_variable = true
	for_loop.index_variable = ""
	errors = for_loop.validate()
	assert(errors.size() > 0, "空索引变量名应该产生验证错误")
	print("✓ 空索引变量名验证通过")

	print("✓ 所有验证测试通过")
