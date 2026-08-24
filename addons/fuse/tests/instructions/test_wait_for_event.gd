# 测试：WaitForEvent 指令（EventBus 事件到达/超时/取消退订/参数捕获/双路径）
extends Node

var _fail: int = 0

# lambda 信号回调载体（GDScript lambda 按值捕获局部变量，须用成员变量传递结果）
var _failed_msg: String = ""
var _completed_flag: bool = false

class RecordingInstruction:
	extends BaseInstruction
	var records: Array
	func _init(records: Array) -> void:
		self.records = records
	func _setup_metadata() -> void:
		pass
	func _update_resource_name() -> void:
		resource_name = "RecordingInstruction"
	func execute(context: ExecutionContext) -> void:
		_start_execution(context)
		records.append({
			"event_score": context.get_variable("event_score"),
			"event_tag": context.get_variable("event_tag"),
		})
		_on_execution_completed()
	func get_description() -> String:
		return "记录 event_* 变量的测试指令"

func _ready() -> void:
	print("=== WaitForEvent 测试开始 ===")
	await _test_event_arrives()
	await _test_timeout_fails()
	await _test_cancel_unsubscribes()
	await _test_runtime_path()
	print("=== WaitForEvent 测试完成（失败 %d 项）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("✓ " + message)
	else:
		_fail += 1
		push_error("✗ " + message)

func _get_bus() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("FuseEventBus")

func _build_runner(wait_inst: WaitForEvent, records: Array) -> Runner:
	var runner := Runner.new()
	var instructions: Array[BaseInstruction] = []
	instructions.append(wait_inst)
	instructions.append(RecordingInstruction.new(records))
	var ar := ActionRunner.new()
	ar.instructions = instructions
	# 注意顺序：add_child 时 action_runner 必须尚未赋值（否则 _ready 创建
	# RARI 并连接信号后，手动 _ready 再建的 RARI 因 _runtime_signals_connected
	# 守卫不会连接，wait_completed 永久挂起）。对齐 test_wait_for_signal.gd 模式。
	add_child(runner)
	runner.action_runner = ar
	runner._ready()
	return runner

func _test_event_arrives() -> void:
	print("\n--- 事件到达 ---")
	var bus = _get_bus()
	bus.clear_history()
	var wait_inst := WaitForEvent.new()
	wait_inst.event_name = "test_wf_scored"
	wait_inst.timeout = 5.0
	var records: Array = []
	var runner := _build_runner(wait_inst, records)

	runner.run()
	await get_tree().process_frame  # 让指令进入等待（订阅生效）
	bus.send_event("test_wf_scored", {"score": 100, "tag": "win"})
	await runner.wait_completed()
	_check(records.size() == 1, "事件到达后继续执行")
	if records.size() >= 1:
		_check(records[0]["event_score"] == 100, "event_score 捕获为 100")
		_check(records[0]["event_tag"] == "win", "event_tag 捕获为 win")
	_check(bus.get_listener_count("test_wf_scored") == 0, "完成后已退订")
	runner.queue_free()

func _test_timeout_fails() -> void:
	print("\n--- 超时失败 ---")
	var wait_inst := WaitForEvent.new()
	wait_inst.event_name = "test_wf_never"
	wait_inst.timeout = 0.1
	var records: Array = []
	var runner := _build_runner(wait_inst, records)

	_failed_msg = ""
	runner.execution_failed.connect(func(e): _failed_msg = e)
	runner.run()
	# stop_on_error 失败分支不发完成通知（RARI 既有行为），轮询等待失败信号
	for i in range(50):
		await get_tree().process_frame
		if not _failed_msg.is_empty():
			break
	_check(not _failed_msg.is_empty(), "超时以 execution_failed 终止")
	_check(records.is_empty(), "超时后不执行后续指令")
	_check(_get_bus().get_listener_count("test_wf_never") == 0, "超时后已退订")
	runner.queue_free()

func _test_cancel_unsubscribes() -> void:
	print("\n--- 取消退订 ---")
	var wait_inst := WaitForEvent.new()
	wait_inst.event_name = "test_wf_cancel"
	wait_inst.timeout = 0.0
	var records: Array = []
	var runner := _build_runner(wait_inst, records)

	runner.run()
	await get_tree().process_frame
	runner.cancel("测试取消")
	for i in range(10):
		await get_tree().process_frame
		if not runner.is_running():
			break
	_check(not runner.is_running(), "取消后协程唤醒")
	_check(_get_bus().get_listener_count("test_wf_cancel") == 0, "取消后已退订（监听器归零）")

	# 取消后事件不再触发完成
	_get_bus().send_event("test_wf_cancel", {"x": 1})
	await get_tree().create_timer(0.1).timeout
	_check(records.is_empty(), "取消后的事件不触发执行")
	runner.queue_free()

func _test_runtime_path() -> void:
	print("\n--- Runtime 路径 ---")
	var trigger := Node.new()
	trigger.name = "FakeTrigger"
	add_child(trigger)
	var wait_inst := WaitForEvent.new()
	wait_inst.event_name = "test_wf_rt"
	wait_inst.timeout = 5.0

	var context := ExecutionContext.new(trigger, trigger)
	var ri := RuntimeInstructionInstance.new(wait_inst, context, null)
	_completed_flag = false
	ri.finished.connect(func(): _completed_flag = true)
	var sync_done := ri.execute_sync()
	_check(sync_done == false, "返回 false（异步）")
	_get_bus().send_event("test_wf_rt", {"score": 5})
	for i in range(10):
		await get_tree().process_frame
		if _completed_flag:
			break
	_check(_completed_flag, "事件到达后实例完成")
	_check(context.get_variable("event_score") == 5, "Runtime 路径参数捕获")
	ri.cleanup()
	trigger.queue_free()
