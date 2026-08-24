# 测试：取消路径的批量信号冲刷——取消 run 不残留 pending、不跨 run 串扰
extends Node

var _fail: int = 0
var _started_count: int = 0

class SyncProbe:
	extends BaseInstruction
	func _setup_metadata() -> void:
		pass
	func _update_resource_name() -> void:
		resource_name = "SyncProbe"
	func execute(context: ExecutionContext) -> void:
		_start_execution(context)
		_on_execution_completed()
	func get_description() -> String:
		return "同步探针指令"

func _ready() -> void:
	print("=== 取消冲刷测试开始 ===")
	await _test_cancel_flushes_pending()
	await _test_no_cross_run_replay()
	print("=== 取消冲刷测试完成（失败 %d 项）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("✓ " + message)
	else:
		_fail += 1
		push_error("✗ " + message)

## 取消 run：pending 清空
func _test_cancel_flushes_pending() -> void:
	print("\n--- 取消清空 pending ---")
	var trigger := Node.new()
	trigger.name = "FlushTrigger"
	add_child(trigger)

	# 序列：[同步探针, Wait(30)]——同步探针完成后进 pending，卡在 Wait 时取消
	var ar := ActionRunner.new()
	ar.stop_on_error = true
	var instructions: Array[BaseInstruction] = []
	instructions.append(SyncProbe.new())
	var wait_inst := Wait.new()
	wait_inst.wait_time = 30.0
	instructions.append(wait_inst)
	ar.instructions = instructions

	var rari := RuntimeActionRunnerInstance.new(ar, trigger)
	rari.set_batch_signal_mode(true)

	var context := ExecutionContext.new(trigger, trigger)
	rari.run(context)
	await get_tree().process_frame  # 同步探针完成入 pending，卡在 Wait
	rari.cancel_execution("冲刷测试")
	for i in range(10):
		await get_tree().process_frame
		if not rari.is_running():
			break

	_check(not rari.is_running(), "取消后协程退出")
	_check(rari._pending_started_instructions.is_empty() and rari._pending_completed_instructions.is_empty(),
		"取消后 pending 数组已清空（跨 run 串扰源）")
	rari.cleanup()
	trigger.queue_free()

## 跨 run 串扰：取消 run 后再成功 run，instruction_started 只含新 run 的
func _test_no_cross_run_replay() -> void:
	print("\n--- 无跨 run 重放 ---")
	_started_count = 0
	var trigger := Node.new()
	trigger.name = "ReplayTrigger"
	add_child(trigger)

	var ar := ActionRunner.new()
	var instructions: Array[BaseInstruction] = []
	instructions.append(SyncProbe.new())
	var wait_inst := Wait.new()
	wait_inst.wait_time = 30.0
	instructions.append(wait_inst)
	ar.instructions = instructions

	var rari := RuntimeActionRunnerInstance.new(ar, trigger)
	rari.set_batch_signal_mode(true)
	rari.instruction_started.connect(func(_i): _started_count += 1)

	var context := ExecutionContext.new(trigger, trigger)
	# 第一次 run：同步探针入 pending 后取消
	rari.run(context)
	await get_tree().process_frame
	rari.cancel_execution("第一次")
	for i in range(10):
		await get_tree().process_frame
		if not rari.is_running():
			break

	# 第二次 run：单同步探针，正常完成 flush——只应发 1 次 started
	var second: Array[BaseInstruction] = []
	second.append(SyncProbe.new())
	rari.action_runner.instructions = second
	_started_count = 0
	rari.run(context)
	for i in range(10):
		await get_tree().process_frame
		if not rari.is_running():
			break
	_check(_started_count == 1, "第二次 run 只重放自己的 instruction_started（实际 %d，>1 即跨 run 串扰）" % _started_count)
	rari.cleanup()
	trigger.queue_free()
