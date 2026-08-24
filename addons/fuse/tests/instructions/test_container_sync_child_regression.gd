# 测试：容器（for_each 运行时模式）同步子指令 + 异步兄弟边界回归
#
# 缺陷机理（终审静态推演）：同步子指令的 finished 在 child_instance.execute_sync()
# 内同步发射——RII 已预先连接 instruction.finished → _on_instruction_finished →
# _complete_execution → 实例 finished → 容器 _on_child_instruction_completed，
# 信号路径已推进过一次；execute_sync 返回 true 后容器的
# `if is_sync: _on_child_instruction_completed(...)` 直调是第二次——
# 会断开在途异步兄弟（Wait）的完成回调并使指令索引双前进，
# 迭代在异步兄弟完成前提前结束。
#
# 用例 A：[SyncFailProbe, Wait(0.1)]——同步失败 + 异步兄弟（3269088 解锁的边界）
# 用例 B：[SyncOkProbe, Wait(0.1)]——同步成功 + 异步兄弟
# 断言：两个子指令都执行、Wait 完成先于容器完成（不提前结束）、迭代正常结束
#
# 搭建方式：既有 for_each 测试（test_for_each.gd）全是遗留 execute 路径，
# 本测试用 RuntimeInstructionInstance 直驱 for_each 指令走
# execute_with_runtime_instance 路径（sequence_mode 默认 ASYNCHRONOUS）。
extends Node

var _fail: int = 0

# 事件序贯记录（成员变量：信号回调经 self 读写，规避 lambda 按值捕获陷阱）
var _events: Array = []
var _loop_done: bool = false

## 同步失败探针：execute 内同步 set_error + finished.emit
## （复制自 test_execute_sync_terminal_detection.gd 最终形态，补 records 记录）
class SyncFailProbe:
	extends BaseInstruction
	var records: Array
	func _init(records: Array = []) -> void:
		self.records = records
	func _setup_metadata() -> void:
		pass
	func _update_resource_name() -> void:
		resource_name = "SyncFailProbe"
	func execute(context: ExecutionContext) -> void:
		_start_execution(context)
		records.append("fail_run")
		set_error("同步失败探针", FuseError.ErrorType.RUNTIME_ERROR)
		finished.emit()
	func get_description() -> String:
		return "同步失败探针"

## 同步成功探针：execute 内 _on_execution_completed 到达 COMPLETED 终态
class SyncOkProbe:
	extends BaseInstruction
	var records: Array
	func _init(records: Array = []) -> void:
		self.records = records
	func _setup_metadata() -> void:
		pass
	func _update_resource_name() -> void:
		resource_name = "SyncOkProbe"
	func execute(context: ExecutionContext) -> void:
		_start_execution(context)
		records.append("ok_run")
		_on_execution_completed()
	func get_description() -> String:
		return "同步成功探针"

## 记录型 Wait：复用真实 Wait 的运行时路径，在计时器超时回调处记录完成时刻
## （运行时模式下 Wait 资源自身的 finished 不发射——完成走
## runtime_instance._complete_execution，故只能在超时回调处记录。
## 记录必须放在 super 之前：健康路径下容器完成（loop_done）正是在
## super 内部的完成链中同步推进的，先记 wait_done 才能区分
## "先等完再结束"与"提前结束"两种时序）
class RecordingWait:
	extends Wait
	var records: Array = []
	func _on_runtime_timer_timeout(runtime_instance: RuntimeInstructionInstance) -> void:
		records.append("wait_done")
		super(runtime_instance)

func _ready() -> void:
	print("=== 容器同步子指令双重调用回归测试开始 ===")
	# headless 首帧 delta 异常大：_ready 同步链上创建的首个 SceneTreeTimer 会被
	# 立即判定超时——先等两帧让引擎帧时间稳定（参照 test_runtime_instruction_instance.gd）
	await get_tree().process_frame
	await get_tree().process_frame
	await _test_case_a_sync_failure_with_async_sibling()
	await _test_case_b_sync_success_with_async_sibling()
	print("=== 容器同步子指令双重调用回归测试完成（失败 %d 项）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("✓ " + message)
	else:
		_fail += 1
		push_error("✗ " + message)

func _on_loop_finished() -> void:
	_events.append("loop_done")
	_loop_done = true

## 构建运行时模式的 for_each（遍历 1 个元素），返回外层 RII
func _build_runtime_for_each(children: Array) -> RuntimeInstructionInstance:
	var for_each := ForEach.new()
	for_each.source_type = ForEach.SourceType.ARRAY
	for_each.array_variable = "src_array"
	for_each.item_variable = "item"
	for_each.index_variable = "index"
	for_each.sequence_mode = ForEach.SequenceMode.ASYNCHRONOUS
	for child in children:
		for_each.loop_instructions.append(child)

	var context := ExecutionContext.new(self, null)
	context.set_variable("src_array", [42])
	return RuntimeInstructionInstance.new(for_each, context, null)

## 等待循环与 Wait 都完成（3 秒兜底超时）
func _await_completion() -> void:
	var deadline := Time.get_ticks_msec() + 3000
	while not (_loop_done and _events.has("wait_done")) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

## 用例 A：同步失败子指令 + 异步兄弟——不跳指令、不提前结束
func _test_case_a_sync_failure_with_async_sibling() -> void:
	print("\n--- 用例 A：同步失败 + 异步兄弟 ---")
	_events = []
	_loop_done = false

	var wait := RecordingWait.new()
	wait.wait_time = 0.1
	wait.records = _events

	var for_each_ri := _build_runtime_for_each([SyncFailProbe.new(_events), wait])
	for_each_ri.finished.connect(_on_loop_finished)

	var sync := for_each_ri.execute_sync()
	_check(sync == false, "for_each 运行时模式整体异步（execute_sync 返回 false）")
	await _await_completion()

	_check(_events.has("fail_run"), "同步失败探针被执行（不跳过首指令）")
	_check(_events.has("wait_done"), "Wait 异步等待正常完成（探针记录）")
	_check(_events.find("wait_done") < _events.find("loop_done"),
		"Wait 完成先于容器完成（不提前结束迭代）")
	_check(_loop_done and for_each_ri.is_completed(), "迭代正常结束（循环最终完成）")
	_check(_events.count("loop_done") == 1, "容器 finished 恰好一次")
	print("  事件序贯: " + str(_events))
	for_each_ri.cleanup()

## 用例 B：同步成功子指令 + 异步兄弟——行为与用例 A 一致
func _test_case_b_sync_success_with_async_sibling() -> void:
	print("\n--- 用例 B：同步成功 + 异步兄弟 ---")
	_events = []
	_loop_done = false

	var wait := RecordingWait.new()
	wait.wait_time = 0.1
	wait.records = _events

	var for_each_ri := _build_runtime_for_each([SyncOkProbe.new(_events), wait])
	for_each_ri.finished.connect(_on_loop_finished)

	var sync := for_each_ri.execute_sync()
	_check(sync == false, "for_each 运行时模式整体异步（execute_sync 返回 false）")
	await _await_completion()

	_check(_events.has("ok_run"), "同步成功探针被执行（不跳过首指令）")
	_check(_events.has("wait_done"), "Wait 异步等待正常完成（探针记录）")
	_check(_events.find("wait_done") < _events.find("loop_done"),
		"Wait 完成先于容器完成（不提前结束迭代）")
	_check(_loop_done and for_each_ri.is_completed(), "迭代正常结束（循环最终完成）")
	_check(_events.count("loop_done") == 1, "容器 finished 恰好一次")
	print("  事件序贯: " + str(_events))
	for_each_ri.cleanup()
