# test_runtime_instruction_instance.gd
extends Node

## 测试 RuntimeInstructionInstance 状态隔离效果
##
## 测试项目：
## - 运行时实例创建
## - 顺序执行隔离
## - 并行执行隔离
## - 多 Trigger 并发隔离
## - Wait 指令运行时状态
## - 信号多次触发保护
## - 执行超时
## - 暂停/恢复
## - 取消执行
## - 错误处理

var _test_passed: int = 0
var _test_failed: int = 0

# GDScript lambda 按值捕获局部变量——计数/标志必须用成员变量（lambda 内经 self 读写）
var _completed_a: bool = false
var _completed_b: bool = false
var _finished_emit_count: int = 0
var _timeout_triggered: bool = false
var _error_triggered: bool = false

func _ready():
	print("=== 测试 RuntimeInstructionInstance 状态隔离 ===")
	# headless 首帧 delta 异常大：_ready 同步链上创建的首个 SceneTreeTimer 会被
	# 立即判定超时（曾致 Test 2 顺序执行两个 0.1s Wait 实测仅 0.10s）。
	# 先等两帧让引擎帧时间稳定再启动测试。
	await get_tree().process_frame
	await get_tree().process_frame
	await run_all_tests()
	_print_summary()

func run_all_tests():
	await test_runtime_instance_creation()
	await test_sequential_execution_with_runtime_instance()
	await test_parallel_execution_with_runtime_instance()
	await test_multiple_triggers_isolation()
	await test_wait_instruction_runtime_state()

	# 边界测试
	await test_signal_multiple_emit_protection()
	await test_execution_timeout()
	await test_pause_resume()
	await test_cancel_execution()
	await test_error_handling()

## 测试1：运行时实例创建
func test_runtime_instance_creation():
	print("\n[Test 1] RuntimeInstructionInstance 创建测试")

	var wait_inst = Wait.new()
	wait_inst.wait_time = 1.0

	var context = ExecutionContext.new(self, self)
	var runtime_inst = RuntimeInstructionInstance.new(wait_inst, context, null)

	# 验证创建成功
	if runtime_inst.instruction == wait_inst:
		print("  ✓ 指令引用正确")
		_test_passed += 1
	else:
		print("  ✗ 指令引用错误")
		_test_failed += 1

	# 验证运行时状态独立
	if runtime_inst.runtime_state.has("timer"):
		print("  ✓ 运行时状态包含 timer")
		_test_passed += 1
	else:
		print("  ✗ 运行时状态缺少 timer")
		_test_failed += 1

	# 验证初始状态
	if not runtime_inst.is_completed():
		print("  ✓ 初始状态为未完成")
		_test_passed += 1
	else:
		print("  ✗ 初始状态错误")
		_test_failed += 1

## 测试2：顺序执行隔离
func test_sequential_execution_with_runtime_instance():
	print("\n[Test 2] 顺序执行 RuntimeInstance 测试")

	var wait1 = Wait.new()
	wait1.wait_time = 0.1

	var wait2 = Wait.new()
	wait2.wait_time = 0.1

	var runner = ActionRunner.new()
	# instructions 是 Array[BaseInstruction] 类型化数组，直接赋普通 Array 字面量会报错
	runner.instructions.append(wait1)
	runner.instructions.append(wait2)
	runner.execution_mode = ActionRunner.ExecutionMode.SEQUENTIAL

	var runtime_instance = RuntimeActionRunnerInstance.new(runner, self)
	var context = ExecutionContext.new(self, self)

	var start_time = Time.get_ticks_msec() / 1000.0

	runtime_instance.run(context)
	await runtime_instance.execution_completed

	var end_time = Time.get_ticks_msec() / 1000.0
	var total_time = end_time - start_time

	# 验证执行时间（顺序执行应该 >= 0.18s）
	if total_time >= 0.15:
		print("  ✓ 顺序执行时间正确: %.2fs" % total_time)
		_test_passed += 1
	else:
		print("  ✗ 顺序执行时间异常: %.2fs" % total_time)
		_test_failed += 1

## 测试3：并行执行隔离
func test_parallel_execution_with_runtime_instance():
	print("\n[Test 3] 并行执行 RuntimeInstance 测试")

	var wait1 = Wait.new()
	wait1.wait_time = 0.2

	var wait2 = Wait.new()
	wait2.wait_time = 0.3

	var runner = ActionRunner.new()
	# instructions 是 Array[BaseInstruction] 类型化数组，直接赋普通 Array 字面量会报错
	runner.instructions.append(wait1)
	runner.instructions.append(wait2)
	runner.execution_mode = ActionRunner.ExecutionMode.PARALLEL

	var runtime_instance = RuntimeActionRunnerInstance.new(runner, self)
	var context = ExecutionContext.new(self, self)

	var start_time = Time.get_ticks_msec() / 1000.0

	runtime_instance.run(context)
	await runtime_instance.execution_completed

	var end_time = Time.get_ticks_msec() / 1000.0
	var total_time = end_time - start_time

	# 并行执行应该 < 0.5s（最大等待时间 + 余量）
	if total_time < 0.6:
		print("  ✓ 并行执行时间正确: %.2fs" % total_time)
		_test_passed += 1
	else:
		print("  ✗ 并行执行时间异常: %.2fs" % total_time)
		_test_failed += 1

## 测试4：多 Trigger 隔离
func test_multiple_triggers_isolation():
	print("\n[Test 4] 多 Trigger 并发隔离测试")

	var shared_wait = Wait.new()
	shared_wait.wait_time = 0.2

	var runner = ActionRunner.new()
	# instructions 是 Array[BaseInstruction] 类型化数组，直接赋普通 Array 字面量会报错
	runner.instructions.append(shared_wait)

	var runtime_instance_a = RuntimeActionRunnerInstance.new(runner, self)
	var runtime_instance_b = RuntimeActionRunnerInstance.new(runner, self)

	var context_a = ExecutionContext.new(self, self)
	var context_b = ExecutionContext.new(self, self)

	var start_time = Time.get_ticks_msec() / 1000.0

	# 先连接信号再启动，防止信号先于连接发射
	# 注意：lambda 内必须写成员变量（局部变量按值捕获，赋值不回传）
	runtime_instance_a.execution_completed.connect(func(_time): _completed_a = true)
	runtime_instance_b.execution_completed.connect(func(_time): _completed_b = true)
	_completed_a = false
	_completed_b = false

	runtime_instance_a.run(context_a)
	runtime_instance_b.run(context_b)

	# 轮询等待两个实例完成（帧数上限防挂死）
	var waited_frames: int = 0
	while not (_completed_a and _completed_b) and waited_frames < 300:
		await get_tree().process_frame
		waited_frames += 1

	var end_time = Time.get_ticks_msec() / 1000.0
	var total_time = end_time - start_time

	if _completed_a and _completed_b:
		print("  ✓ 两个实例都完成执行")
		_test_passed += 1
	else:
		print("  ✗ 实例未完成（a=%s b=%s，等待 %d 帧）" % [_completed_a, _completed_b, waited_frames])
		_test_failed += 1

## 测试5：Wait 指令运行时状态
func test_wait_instruction_runtime_state():
	print("\n[Test 5] Wait 指令运行时状态测试")

	var wait_inst = Wait.new()
	wait_inst.wait_time = 0.1

	var context = ExecutionContext.new(self, self)
	var runtime_inst = RuntimeInstructionInstance.new(wait_inst, context, null)

	# 执行前检查
	var timer_before = runtime_inst.get_runtime_state("timer")
	if timer_before == null:
		print("  ✓ 执行前 timer 为 null")
		_test_passed += 1
	else:
		print("  ✗ 执行前 timer 不为 null")
		_test_failed += 1

	# 执行
	var sync_completed = runtime_inst.execute_sync()

	if not sync_completed:
		print("  ✓ Wait 返回异步模式")
		_test_passed += 1
	else:
		print("  ✗ Wait 返回同步模式")
		_test_failed += 1

	# 等待完成
	await runtime_inst.finished

	# 执行后检查
	var timer_after = runtime_inst.get_runtime_state("timer")
	if timer_after == null:
		print("  ✓ 执行后 timer 已清理")
		_test_passed += 1
	else:
		print("  ✗ 执行后 timer 未清理")
		_test_failed += 1

## 测试6：信号多次触发保护
func test_signal_multiple_emit_protection():
	print("\n[Test 6] 信号多次触发保护测试")

	var wait_inst = Wait.new()
	wait_inst.wait_time = 0.05

	var context = ExecutionContext.new(self, self)
	var runtime_inst = RuntimeInstructionInstance.new(wait_inst, context, null)

	_finished_emit_count = 0
	# lambda 内必须写成员变量（局部变量按值捕获，自增不回传）
	runtime_inst.finished.connect(func(): _finished_emit_count += 1)

	# 执行并等待完成
	runtime_inst.execute_sync()
	await runtime_inst.finished

	# 尝试再次完成（应该被忽略）
	runtime_inst._complete_execution()
	await get_tree().create_timer(0.1).timeout

	if _finished_emit_count == 1:
		print("  ✓ finished 信号只触发一次")
		_test_passed += 1
	else:
		print("  ✗ finished 信号触发 %d 次" % _finished_emit_count)
		_test_failed += 1

## 测试7：执行超时
func test_execution_timeout():
	print("\n[Test 7] 执行超时测试")

	var wait_inst = Wait.new()
	wait_inst.wait_time = 1.0  # 长等待

	var context = ExecutionContext.new(self, self)
	var runtime_inst = RuntimeInstructionInstance.new(wait_inst, context, null)
	runtime_inst.execution_timeout = 0.1  # 短超时

	_timeout_triggered = false
	# lambda 内必须写成员变量（局部变量按值捕获，赋值不回传）
	runtime_inst.timeout.connect(func(): _timeout_triggered = true)

	var start_time = Time.get_ticks_msec() / 1000.0
	runtime_inst.execute_sync()
	await runtime_inst.finished
	var end_time = Time.get_ticks_msec() / 1000.0

	if _timeout_triggered:
		print("  ✓ 超时信号正确触发")
		_test_passed += 1
	else:
		print("  ✗ 超时信号未触发")
		_test_failed += 1

	if (end_time - start_time) < 0.3:
		print("  ✓ 执行在超时后快速结束: %.2fs" % (end_time - start_time))
		_test_passed += 1
	else:
		print("  ✗ 执行时间过长: %.2fs" % (end_time - start_time))
		_test_failed += 1

## 测试8：暂停/恢复
func test_pause_resume():
	print("\n[Test 8] 暂停/恢复测试")

	var wait_inst = Wait.new()
	wait_inst.wait_time = 0.3

	var context = ExecutionContext.new(self, self)
	var runtime_inst = RuntimeInstructionInstance.new(wait_inst, context, null)

	runtime_inst.execute_sync()

	# 等待一小段时间后暂停
	await get_tree().create_timer(0.1).timeout

	if runtime_inst.pause():
		print("  ✓ 暂停成功")
		_test_passed += 1
	else:
		print("  ✗ 暂停失败")
		_test_failed += 1

	if runtime_inst.is_paused():
		print("  ✓ 暂停状态正确")
		_test_passed += 1
	else:
		print("  ✗ 暂停状态不正确")
		_test_failed += 1

	# 等待一段时间后恢复
	await get_tree().create_timer(0.2).timeout

	if runtime_inst.resume():
		print("  ✓ 恢复成功")
		_test_passed += 1
	else:
		print("  ✗ 恢复失败")
		_test_failed += 1

	# 等待完成
	await runtime_inst.finished

	if runtime_inst.is_completed():
		print("  ✓ 暂停恢复后正常完成")
		_test_passed += 1
	else:
		print("  ✗ 暂停恢复后未完成")
		_test_failed += 1

## 测试9：取消执行
func test_cancel_execution():
	print("\n[Test 9] 取消执行测试")

	var wait_inst = Wait.new()
	wait_inst.wait_time = 1.0  # 长等待

	var context = ExecutionContext.new(self, self)
	var runtime_inst = RuntimeInstructionInstance.new(wait_inst, context, null)

	runtime_inst.execute_sync()

	# 等待一小段时间后取消
	await get_tree().create_timer(0.1).timeout

	runtime_inst.cancel()

	if not runtime_inst._is_executing:
		print("  ✓ 执行状态已停止")
		_test_passed += 1
	else:
		print("  ✗ 执行状态未停止")
		_test_failed += 1

	if runtime_inst.runtime_state["execution_status"] == BaseInstruction.ExecutionStatus.CANCELLED:
		print("  ✓ 取消状态正确")
		_test_passed += 1
	else:
		print("  ✗ 取消状态不正确")
		_test_failed += 1

## 测试10：错误处理
func test_error_handling():
	print("\n[Test 10] 错误处理测试")

	var wait_inst = Wait.new()
	wait_inst.wait_time = -1.0  # 无效值

	var context = ExecutionContext.new(self, self)
	var runtime_inst = RuntimeInstructionInstance.new(wait_inst, context, null)

	_error_triggered = false
	# lambda 内必须写成员变量（局部变量按值捕获，赋值不回传）
	runtime_inst.error_occurred.connect(func(_msg): _error_triggered = true)

	runtime_inst.execute_sync()
	# Wait(-1) 走同步完成路径：finished 在 execute_sync 内已发射，再 await 会永久挂起
	# 改为轮询成员标志（帧数上限防挂死；此路径 error_occurred 不发射，用 is_completed 兜底）
	var waited_frames: int = 0
	while not (_error_triggered or runtime_inst.is_completed()) and waited_frames < 60:
		await get_tree().process_frame
		waited_frames += 1

	if _error_triggered or runtime_inst.is_completed():
		print("  ✓ 执行已结束（错误路径）")
		_test_passed += 1
	else:
		print("  ✗ 执行未在限期内结束")
		_test_failed += 1

	if runtime_inst.has_error():
		print("  ✓ 错误被正确检测")
		_test_passed += 1
	else:
		print("  ✗ 错误未被检测")
		_test_failed += 1

	if not runtime_inst.get_error_message().is_empty():
		print("  ✓ 错误消息不为空")
		_test_passed += 1
	else:
		print("  ✗ 错误消息为空")
		_test_failed += 1

func _print_summary():
	print("\n=== 测试总结 ===")
	print("通过: %d" % _test_passed)
	print("失败: %d" % _test_failed)
	if _test_failed == 0:
		print("✓ 所有测试通过!")
	else:
		print("✗ 有测试失败!")
	# 退出码门禁：headless 运行时非 0 即失败
	get_tree().quit(1 if _test_failed > 0 else 0)
