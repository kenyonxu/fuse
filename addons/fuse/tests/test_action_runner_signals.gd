extends Node

## ActionRunner 信号清理测试
##
## 测试 ActionRunner 是否正确清理信号连接，防止内存泄漏

func test_signal_cleanup_on_error():
	print("=== 开始信号清理测试 ===")

	var runner = ActionRunner.new()
	var instruction = SetVariable.new()

	# 创建一个简单的测试指令
	instruction.target_variable = "test_var"
	instruction.new_value = 123
	instruction.completion_timing = BaseInstruction.CompletionSignalTiming.ON_START

	var context = ExecutionContext.new()
	# 在上下文中创建测试变量
	context.set_variable("test_var", 0, "local")
	runner.instructions = [instruction]

	# 记录初始连接数
	var initial_connections = instruction.finished.get_connections().size()
	print("初始信号连接数: %d" % initial_connections)

	# 执行并等待完成
	await runner.run(context)

	# 等待一帧确保清理完成
	await get_tree().process_frame

	# 验证：执行后信号应该被清理
	var final_connections = instruction.finished.get_connections().size()
	print("最终信号连接数: %d" % final_connections)

	if final_connections == 0:
		print("✓ 信号清理测试通过：信号连接已正确清理")
	else:
		push_error("✗ 信号清理测试失败：预期 0 个连接，实际 %d 个连接" % final_connections)

	assert(final_connections == 0, "Expected 0 connections, got %d" % final_connections)

	# 清理
	context.cleanup()
	runner.clear_instructions()

	print("=== 信号清理测试完成 ===")

func test_signal_cleanup_on_cancel():
	print("\n=== 开始取消场景信号清理测试 ===")

	var runner = ActionRunner.new()
	var instructions = []

	# 创建多个异步指令
	for i in range(5):
		var inst = SetVariable.new()
		inst.target_variable = "test_var_%d" % i
		inst.new_value = i
		instructions.append(inst)

	runner.instructions = instructions
	var context = ExecutionContext.new()
	# 在上下文中创建测试变量
	for i in range(5):
		context.set_variable("test_var_%d" % i, 0, "local")

	# 记录初始连接数
	var total_initial_connections = 0
	for inst in instructions:
		total_initial_connections += inst.finished.get_connections().size()
	print("初始总信号连接数: %d" % total_initial_connections)

	# 取消执行
	runner.cancel_execution("测试取消")

	# 等待一帧确保清理完成
	await get_tree().process_frame

	# 验证：取消后所有信号应该被清理
	var total_final_connections = 0
	for inst in instructions:
		total_final_connections += inst.finished.get_connections().size()
	print("最终总信号连接数: %d" % total_final_connections)

	if total_final_connections == 0:
		print("✓ 取消场景信号清理测试通过")
	else:
		push_error("✗ 取消场景信号清理测试失败：预期 0 个连接，实际 %d 个连接" % total_final_connections)

	assert(total_final_connections == 0, "Expected 0 connections after cancel, got %d" % total_final_connections)

	# 清理
	context.cleanup()
	runner.clear_instructions()

	print("=== 取消场景信号清理测试完成 ===")

func test_multiple_executions_no_leak():
	print("\n=== 开始多次执行无泄漏测试 ===")

	var runner = ActionRunner.new()
	var instruction = SetVariable.new()
	instruction.target_variable = "test_var"
	instruction.new_value = 123
	instruction.completion_timing = BaseInstruction.CompletionSignalTiming.ON_START

	runner.instructions = [instruction]

	# 执行多次
	for i in range(10):
		var context = ExecutionContext.new()
		# 在上下文中创建测试变量
		context.set_variable("test_var", 0, "local")

		var connections_before = instruction.finished.get_connections().size()
		await runner.run(context)
		var connections_after = instruction.finished.get_connections().size()

		# 每次执行后，连接数应该归零
		if connections_after != 0:
			push_error("第 %d 次执行后仍有 %d 个信号连接" % [i + 1, connections_after])

		context.cleanup()

	# 最终验证
	var final_connections = instruction.finished.get_connections().size()
	print("10 次执行后最终信号连接数: %d" % final_connections)

	if final_connections == 0:
		print("✓ 多次执行无泄漏测试通过")
	else:
		push_error("✗ 多次执行无泄漏测试失败：存在信号泄漏")

	assert(final_connections == 0, "Expected 0 connections after multiple executions, got %d" % final_connections)

	runner.clear_instructions()

	print("=== 多次执行无泄漏测试完成 ===")
