# 测试：终态信号互斥——canceled/failed/completed 各恰好一次，失败后不发 completed，失败/取消后可重 run
extends Node

var _fail: int = 0
var _completed: int = 0
var _failed: int = 0
var _canceled: int = 0

# RARI 用例计数器（GDScript lambda 按值捕获局部变量，必须用成员变量）
var _rari_failed: int = 0
var _rari_completed: int = 0

class SyncProbe:
	extends BaseInstruction
	var records: Array
	func _init(records: Array) -> void:
		self.records = records
	func _setup_metadata() -> void:
		pass
	func _update_resource_name() -> void:
		resource_name = "SyncProbe"
	func execute(context: ExecutionContext) -> void:
		_start_execution(context)
		records.append(1)
		_on_execution_completed()
	func get_description() -> String:
		return "同步探针指令"

## 失败探针：异步失败（set_error 后不 emit finished）。
## 注：不能做成"同步 emit finished"——BaseInstruction.execute_sync 的同步完成
## 检测 lambda 按值捕获 completed_sync（局部变量），同步失败指令会被判为
## 伪异步且 ERROR 状态被恢复逻辑抹回 PENDING，失败无法传播。改为声明异步
## （内部类 source_code 为空，_is_synchronous 重写检测不到，hint 是唯一可靠
## 通道），set_error 置 ERROR 后靠 has_error 让执行器跳过 await 直入失败分支。
class FailProbe:
	extends BaseInstruction
	func _init() -> void:
		set_synchronous_hint(false)
	func _setup_metadata() -> void:
		pass
	func _update_resource_name() -> void:
		resource_name = "FailProbe"
	func execute(context: ExecutionContext) -> void:
		_start_execution(context)
		set_error("探针失败", FuseError.ErrorType.RUNTIME_ERROR)
	func get_description() -> String:
		return "失败探针指令"

func _ready() -> void:
	print("=== 终态信号互斥测试开始 ===")
	await _test_legacy_multi_instruction_cancel()
	await _test_legacy_failure_no_completed()
	await _test_rari_failure_allows_rerun()
	await _test_rari_parallel_failure_no_completed()
	print("=== 终态信号互斥测试完成（失败 %d 项）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("✓ " + message)
	else:
		_fail += 1
		push_error("✗ " + message)

func _reset_counters() -> void:
	_completed = 0
	_failed = 0
	_canceled = 0
	_rari_failed = 0
	_rari_completed = 0

func _make_ar(mode: int) -> ActionRunner:
	var ar := ActionRunner.new()
	ar.execution_mode = mode
	ar.stop_on_error = true
	return ar

## 遗留路径：多指令执行中取消 → execution_canceled 恰好一次
func _test_legacy_multi_instruction_cancel() -> void:
	print("\n--- 遗留：多指令取消恰一次 ---")
	_reset_counters()
	var ar := _make_ar(ActionRunner.ExecutionMode.SEQUENTIAL)
	var wait_inst := Wait.new()
	wait_inst.wait_time = 30.0
	var instructions: Array[BaseInstruction] = []
	instructions.append(wait_inst)
	instructions.append(SyncProbe.new([]))
	ar.instructions = instructions

	ar.execution_canceled.connect(func(_r): _canceled += 1)
	ar.execution_completed.connect(func(): _completed += 1)
	ar.execution_failed.connect(func(_e): _failed += 1)

	var context := ExecutionContext.new(self, null)
	ar.run(context)
	await get_tree().process_frame
	ar.cancel_execution("多指令取消")
	for i in range(10):
		await get_tree().process_frame
		if _canceled > 0 or _completed > 0 or _failed > 0:
			break
	_check(_canceled == 1, "多指令取消 execution_canceled 恰一次（实际 %d）" % _canceled)
	_check(_completed == 0 and _failed == 0, "取消不发 completed/failed")

## 遗留路径：失败后不发 completed（当前 314→139→517 双发）
func _test_legacy_failure_no_completed() -> void:
	print("\n--- 遗留：失败不发 completed ---")
	_reset_counters()
	var ar := _make_ar(ActionRunner.ExecutionMode.SEQUENTIAL)
	var instructions: Array[BaseInstruction] = []
	instructions.append(FailProbe.new())
	ar.instructions = instructions

	ar.execution_canceled.connect(func(_r): _canceled += 1)
	ar.execution_completed.connect(func(): _completed += 1)
	ar.execution_failed.connect(func(_e): _failed += 1)

	var context := ExecutionContext.new(self, null)
	ar.run(context)
	await get_tree().process_frame
	_check(_failed == 1, "失败 execution_failed 恰一次（实际 %d）" % _failed)
	_check(_completed == 0, "失败后不发 execution_completed（实际 %d）" % _completed)

## RARI：顺序失败后可重新 run（当前 _is_running_cached 残留死锁）
func _test_rari_failure_allows_rerun() -> void:
	print("\n--- RARI：失败后可重 run ---")
	_reset_counters()
	var trigger := Node.new()
	trigger.name = "RariTrigger"
	add_child(trigger)

	var rari := RuntimeActionRunnerInstance.new(_make_ar(ActionRunner.ExecutionMode.SEQUENTIAL), trigger)
	var fail_instructions: Array[BaseInstruction] = []
	fail_instructions.append(FailProbe.new())
	rari.action_runner.instructions = fail_instructions

	rari.execution_failed.connect(func(_e): _rari_failed += 1)

	var context := ExecutionContext.new(trigger, trigger)
	rari.run(context)
	for i in range(10):
		await get_tree().process_frame
		if _rari_failed > 0:
			break
	_check(_rari_failed == 1, "顺序失败 execution_failed 一次（实际 %d）" % _rari_failed)
	_check(not rari.is_running(), "失败后 is_running 复位为 false")

	# 重新 run：换成正常指令应能执行
	var ok_instructions: Array[BaseInstruction] = []
	var records: Array = []
	ok_instructions.append(SyncProbe.new(records))
	rari.action_runner.instructions = ok_instructions
	rari.execution_completed.connect(func(_t): _rari_completed += 1)
	rari.run(context)
	await get_tree().process_frame
	_check(_rari_completed == 1 and records.size() == 1, "失败后可重新 run（completed=%d records=%d）" % [_rari_completed, records.size()])
	rari.cleanup()
	trigger.queue_free()

## RARI：并行失败不发 completed（当前 500→503→632 双发）
func _test_rari_parallel_failure_no_completed() -> void:
	print("\n--- RARI：并行失败不发 completed ---")
	_reset_counters()
	var trigger := Node.new()
	trigger.name = "PTrigger"
	add_child(trigger)

	var rari := RuntimeActionRunnerInstance.new(_make_ar(ActionRunner.ExecutionMode.PARALLEL), trigger)
	var instructions: Array[BaseInstruction] = []
	instructions.append(FailProbe.new())
	rari.action_runner.instructions = instructions

	rari.execution_failed.connect(func(_e): _rari_failed += 1)
	rari.execution_completed.connect(func(_t): _rari_completed += 1)

	var context := ExecutionContext.new(trigger, trigger)
	rari.run(context)
	for i in range(10):
		await get_tree().process_frame
		if _rari_failed > 0:
			break
	_check(_rari_failed == 1, "并行失败 execution_failed 一次（实际 %d）" % _rari_failed)
	_check(_rari_completed == 0, "并行失败后不发 execution_completed（实际 %d）" % _rari_completed)
	_check(not rari.is_running(), "并行失败后 is_running 复位")
	rari.cleanup()
	trigger.queue_free()
