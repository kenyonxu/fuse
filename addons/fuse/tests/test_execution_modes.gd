extends Node

## ActionRunner 执行模式测试
##
## 测试 ActionRunner 是否正确处理同步和异步指令的混合执行

class SyncInstruction extends BaseInstruction:
	func _setup_metadata():
		metadata.name = "SyncInstruction"
		metadata.description = "同步指令示例"

	func _update_resource_name():
		resource_name = "SyncInstruction"

	func execute(context: ExecutionContext):
		_start_execution(context)
		# 立即完成（同步执行）
		_on_execution_completed()

class AsyncInstruction extends BaseInstruction:
	func _setup_metadata():
		metadata.name = "AsyncInstruction"
		metadata.description = "异步指令示例"

	func _update_resource_name():
		resource_name = "AsyncInstruction"

	var timer: SceneTreeTimer = null

	func execute(context: ExecutionContext):
		_start_execution(context)
		# 使用计时器异步完成
		var scene_tree = Engine.get_main_loop()
		timer = scene_tree.create_timer(0.1)  # 100ms 延迟
		timer.timeout.connect(_on_timer_timeout)

	func _on_timer_timeout():
		if timer:
			timer.queue_free()
			timer = null
		_on_execution_completed()

class ErrorSyncInstruction extends BaseInstruction:
	func _setup_metadata():
		metadata.name = "ErrorSyncInstruction"
		metadata.description = "会抛出错误的同步指令"

	func _update_resource_name():
		resource_name = "ErrorSyncInstruction"

	func execute(context: ExecutionContext):
		_start_execution(context)
		# 抛出错误
		set_error("测试错误")

func test_sync_fallback_to_async():
	print("=== 开始同步降级到异步测试 ===")

	var runner = ActionRunner.new()

	# 创建混合指令序列
	var instructions = []
	instructions.append(SyncInstruction.new())
	instructions.append(AsyncInstruction.new())
	instructions.append(SyncInstruction.new())
	instructions.append(AsyncInstruction.new())
	instructions.append(SyncInstruction.new())

	runner.instructions = instructions
	runner.execution_mode = ActionRunner.ExecutionMode.SEQUENTIAL

	var context = ExecutionContext.new()

	var start_time = Time.get_ticks_msec()

	# 执行并验证：同步和异步指令都应该完成
	await runner.run(context)

	var elapsed = Time.get_ticks_msec() - start_time
	print("执行时间: %d ms" % elapsed)

	# 验证所有指令都完成
	for i in range(instructions.size()):
		var inst = instructions[i]
		if not inst.is_completed():
			push_error("指令 %d (%s) 未完成" % [i, inst.get_name()])
		else:
			print("✓ 指令 %d (%s) 已完成" % [i, inst.get_name()])

		assert(inst.is_completed(), "Instruction %d should be completed" % i)

	# 验证没有错误
	if not runner.has_fuse_error():
		print("✓ 所有指令执行成功，无错误")
	else:
		push_error("✗ 存在执行错误: %s" % runner.get_fuse_error().get_formatted_message())

	assert(not runner.has_fuse_error(), "Should have no execution errors")

	print("=== 同步降级到异步测试完成 ===")

	context.cleanup()
	runner.clear_instructions()

func test_all_sync_instructions():
	print("\n=== 开始全同步指令测试 ===")

	var runner = ActionRunner.new()

	# 创建全同步指令序列
	var instructions = []
	for i in range(5):
		instructions.append(SyncInstruction.new())

	runner.instructions = instructions

	var context = ExecutionContext.new()

	var start_time = Time.get_ticks_msec()

	# 执行
	await runner.run(context)

	var elapsed = Time.get_ticks_msec() - start_time
	print("执行时间: %d ms" % elapsed)
	print("平均每条指令: %.2f ms" % (elapsed / 5.0))

	# 验证所有指令都完成
	for inst in instructions:
		assert(inst.is_completed(), "All sync instructions should be completed")

	print("✓ 全同步指令测试通过")

	context.cleanup()
	runner.clear_instructions()

	print("=== 全同步指令测试完成 ===")

func test_all_async_instructions():
	print("\n=== 开始全异步指令测试 ===")

	var runner = ActionRunner.new()

	# 创建全异步指令序列
	var instructions = []
	for i in range(5):
		instructions.append(AsyncInstruction.new())

	runner.instructions = instructions

	var context = ExecutionContext.new()

	var start_time = Time.get_ticks_msec()

	# 执行
	await runner.run(context)

	var elapsed = Time.get_ticks_msec() - start_time
	print("执行时间: %d ms" % elapsed)
	print("平均每条指令: %.2f ms" % (elapsed / 5.0))

	# 验证所有指令都完成
	for inst in instructions:
		assert(inst.is_completed(), "All async instructions should be completed")

	print("✓ 全异步指令测试通过")

	context.cleanup()
	runner.clear_instructions()

	print("=== 全异步指令测试完成 ===")

func test_error_in_sync_instruction():
	print("\n=== 开始同步指令错误处理测试 ===")

	var runner = ActionRunner.new()
	runner.stop_on_error = true

	var instructions = []
	instructions.append(SyncInstruction.new())
	instructions.append(ErrorSyncInstruction.new())
	instructions.append(SyncInstruction.new())

	runner.instructions = instructions

	var context = ExecutionContext.new()

	# 执行
	await runner.run(context)

	# 验证：第一个指令应该完成，第二个指令应该出错，第三个不应该执行
	assert(instructions[0].is_completed(), "First instruction should complete")
	assert(instructions[1].has_error(), "Second instruction should have error")
	assert(not instructions[2].is_completed(), "Third instruction should not execute")

	print("✓ 同步指令错误处理测试通过")

	context.cleanup()
	runner.clear_instructions()

	print("=== 同步指令错误处理测试完成 ===")

func test_cancel_during_execution():
	print("\n=== 开始执行中取消测试 ===")

	var runner = ActionRunner.new()

	# 创建异步指令
	var instructions = []
	for i in range(10):
		instructions.append(AsyncInstruction.new())

	runner.instructions = instructions

	var context = ExecutionContext.new()

	# 启动执行
	var execution_started = false
	runner.execution_started.connect(func():
		execution_started = true
	)

	# 在短延迟后取消
	var cancel_timer = Engine.get_main_loop().create_timer(0.15)  # 150ms 后取消
	cancel_timer.timeout.connect(func():
		print("取消执行...")
		runner.cancel_execution("测试取消")
	)
	cancel_timer.autostart = true
	get_tree().root.add_child(cancel_timer)

	# 执行
	await runner.run(context)

	# 验证：部分指令可能完成，但应该被正确取消
	print("完成的指令数: %d" % runner.current_instruction_index)
	print("是否取消: %s" % runner.is_canceling)

	assert(execution_started, "Execution should have started")
	assert(runner.is_canceling, "Execution should be cancelled")

	# 清理
	cancel_timer.queue_free()
	context.cleanup()
	runner.clear_instructions()

	print("✓ 执行中取消测试通过")

	print("=== 执行中取消测试完成 ===")
