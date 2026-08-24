# 测试：取消执行传播到在途指令（协程唤醒 + 指令侧清理 + 状态一致性）
extends Node

var _fail: int = 0
var _completed_count: int = 0
var _failed_count: int = 0
var _canceled_count: int = 0

func _ready() -> void:
	print("=== 取消传播测试开始 ===")
	await _test_cancel_during_wait()
	await _test_cancel_then_rerun()
	_test_cancel_when_idle()
	await _test_normal_completion_unchanged()
	await _test_legacy_action_runner_cancel()
	print("=== 取消传播测试完成（失败 %d 项）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("✓ " + message)
	else:
		_fail += 1
		push_error("✗ " + message)

## 组装 Runner + ActionRunner(Wait)（tests/runner/test_runner.gd 模式）
func _build_runner(wait_time: float) -> Runner:
	var runner := Runner.new()
	var wait_inst := Wait.new()
	wait_inst.wait_time = wait_time
	var instructions: Array[BaseInstruction] = []
	instructions.append(wait_inst)
	var ar := ActionRunner.new()
	ar.instructions = instructions
	add_child(runner)
	runner.action_runner = ar
	runner.execution_completed.connect(func(_t): _completed_count += 1)
	runner.execution_failed.connect(func(_e): _failed_count += 1)
	runner.execution_canceled.connect(func(_r): _canceled_count += 1)
	runner._ready()  # 手动初始化（同 test_runner.gd:111 模式：add_child 时
	# action_runner 尚未设置，_ready 无操作；此处设置后手动初始化，
	# 保证 _runtime_instance 创建且信号已连接）
	return runner

## 用例 1：取消正在 await 的 Wait（长定时）→ 协程唤醒 + execution_canceled 恰好一次
func _test_cancel_during_wait() -> void:
	print("\n--- 取消 await 中的 Wait ---")
	_reset_counters()
	var runner := _build_runner(30.0)
	runner.run()
	await get_tree().process_frame
	_check(runner.is_running(), "执行中（卡在 await Wait.finished）")

	runner.cancel("测试取消")
	# 修复前：协程卡死，2 秒内不会发 canceled；修复后：同帧/次帧唤醒
	for i in range(10):
		await get_tree().process_frame
		if _canceled_count > 0:
			break
	_check(_canceled_count == 1, "execution_canceled 恰好发出一次（实际 %d）" % _canceled_count)
	_check(not runner.is_running(), "协程退出，runner 不再运行")
	runner.queue_free()

## 用例 2：取消后可重新 run（状态复位）
func _test_cancel_then_rerun() -> void:
	print("\n--- 取消后重新执行 ---")
	_reset_counters()
	var runner := _build_runner(0.05)
	runner.run()
	await get_tree().process_frame
	runner.cancel("第一次取消")
	for i in range(10):
		await get_tree().process_frame
		if _canceled_count > 0:
			break

	runner.run()
	await runner.wait_completed()
	await get_tree().process_frame  # wait_completed 在 _internal_completed.emit 栈内
	# 恢复，此刻 Runner.execution_completed 尚未转发，补一帧再断言
	_check(_completed_count == 1, "第二次执行正常完成（实际 %d）" % _completed_count)
	runner.queue_free()

## 用例 3：空转（未运行）时 cancel 无害
func _test_cancel_when_idle() -> void:
	print("\n--- 空转取消 ---")
	_reset_counters()  # 上一用例的信号可能迟到泄漏，统一从零开始
	var runner := _build_runner(1.0)
	runner.cancel("空转取消")  # 未 run，不应报错/不应发信号
	await get_tree().process_frame
	_check(_canceled_count == 0 and _completed_count == 0 and _failed_count == 0,
		"空转 cancel 无信号副作用")
	runner.queue_free()

## 用例 4：正常完成路径零变化（完成信号恰好一次）
func _test_normal_completion_unchanged() -> void:
	print("\n--- 正常完成回归 ---")
	_reset_counters()
	var runner := _build_runner(0.05)
	runner.run()
	await runner.wait_completed()
	await get_tree().process_frame
	_check(_completed_count == 1 and _canceled_count == 0 and _failed_count == 0,
		"正常完成：completed 恰好一次、无 canceled/failed")
	runner.queue_free()

## 用例 5：遗留 ActionRunner 路径取消（test_action_runner_signals.gd 模式）
func _test_legacy_action_runner_cancel() -> void:
	print("\n--- 遗留 ActionRunner 取消 ---")
	_reset_counters()
	var wait_inst := Wait.new()
	wait_inst.wait_time = 30.0
	var instructions: Array[BaseInstruction] = []
	instructions.append(wait_inst)
	var ar := ActionRunner.new()
	ar.instructions = instructions

	ar.execution_canceled.connect(func(_r): _canceled_count += 1)
	# 注：ActionRunner.run 需显式 context（同 test_action_runner_signals.gd 模式）；
	# 计数用成员变量（GDScript lambda 按值捕获局部变量，局部计数外部不可见）
	var context := ExecutionContext.new()
	ar.run(context)
	await get_tree().process_frame

	ar.cancel_execution("遗留路径取消")
	for i in range(10):
		await get_tree().process_frame
		if _canceled_count > 0:
			break
	_check(_canceled_count == 1, "遗留路径协程唤醒、execution_canceled 一次（实际 %d）" % _canceled_count)

func _reset_counters() -> void:
	_completed_count = 0
	_failed_count = 0
	_canceled_count = 0
