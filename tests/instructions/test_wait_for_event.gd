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
	await _test_rapid_rerun_no_stale_timeout()
	await _test_pause_freezes_timeout()
	await _test_serialization_roundtrip()
	print("=== WaitForEvent 测试完成（失败 %d 项）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("✓ " + message)
	else:
		_fail += 1
		push_error("✗ " + message)

func _get_bus() -> Node:
	# 注：bus 缺失（FUSE_ERROR_EVENT_BUS_NOT_FOUND）分支不测——FuseEventBus 为
	# autoload（project.godot），headless 测试下始终存在，该分支不可构造，
	# spec §4 允许跳过并注明
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

## 快速两轮执行无伪超时（容器 IfElse/ForLoop/ForEach 的 reset+execute 复用模式）：
## 第 1 轮正常完成后，其陈旧计时器在第 2 轮等待期内触发不得杀掉第 2 轮
func _test_rapid_rerun_no_stale_timeout() -> void:
	print("\n--- 快速两轮执行无伪超时 ---")
	var wait_inst := WaitForEvent.new()
	wait_inst.event_name = "test_wf_rapid"
	wait_inst.timeout = 0.3

	# 第 1 轮：0.05s 时事件到达正常完成（0.3s 计时器未到即完成，成为陈旧计时器）
	var ctx1 := ExecutionContext.new(self, self)
	wait_inst.execute(ctx1)
	await get_tree().create_timer(0.05).timeout
	_get_bus().send_event("test_wf_rapid", {"x": 1})
	await get_tree().process_frame
	_check(wait_inst.execution_status == BaseInstruction.ExecutionStatus.COMPLETED,
		"第 1 轮事件到达正常完成")

	# 立即 reset 后第 2 轮执行（timeout=0：第 2 轮无自身计时器，
	# 0.5s 观察窗内唯一的触发源是第 1 轮的陈旧计时器）
	wait_inst.reset()
	wait_inst.timeout = 0.0
	var ctx2 := ExecutionContext.new(self, self)
	wait_inst.execute(ctx2)
	await get_tree().create_timer(0.5).timeout  # 跨过第 1 轮计时器 0.3s 触发点
	_check(wait_inst.execution_status == BaseInstruction.ExecutionStatus.RUNNING,
		"第 2 轮未被陈旧计时器伪超时（仍在等待）")
	_check(not wait_inst.has_error(), "第 2 轮无超时错误")

	# 清理第 2 轮
	wait_inst.cancel()
	_check(_get_bus().get_listener_count("test_wf_rapid") == 0, "清理后退订")

## 暂停停表（runtime 路径）：pause 断开超时计时器并记录剩余，resume 按剩余续走
func _test_pause_freezes_timeout() -> void:
	print("\n--- 暂停停表 ---")
	var trigger := Node.new()
	trigger.name = "FakeTrigger4"
	add_child(trigger)
	var wait_inst := WaitForEvent.new()
	wait_inst.event_name = "test_wf_pause"
	wait_inst.timeout = 0.3

	var context := ExecutionContext.new(trigger, trigger)
	var ri := RuntimeInstructionInstance.new(wait_inst, context, null)
	ri.execute_sync()

	ri.pause()  # elapsed≈0，剩余超时≈0.3；计时器回调已断开
	await get_tree().create_timer(0.4).timeout  # 超过原 0.3s 超时
	_check(not ri.is_completed(), "暂停期间超时不触发（停表生效）")
	_check(_get_bus().get_listener_count("test_wf_pause") == 1, "暂停期间订阅保持")

	ri.resume()  # 为剩余时间重建计时器
	for i in range(50):
		await get_tree().process_frame
		if ri.is_completed():
			break
	_check(ri.is_completed(), "恢复后按剩余超时完成")
	_check(wait_inst.has_error(), "恢复后以超时错误完成")
	_check(_get_bus().get_listener_count("test_wf_pause") == 0, "超时后退订")
	ri.cleanup()
	trigger.queue_free()

## 序列化 round-trip：PresetValueCodec 保存/还原配置不丢失
func _test_serialization_roundtrip() -> void:
	print("\n--- 序列化 round-trip ---")
	var wait_inst := WaitForEvent.new()
	wait_inst.event_name = "test_wf_ser"
	wait_inst.timeout = 3.5

	var data := PresetValueCodec.serialize_instruction(wait_inst)
	_check(data.has("event_name") and data["event_name"] == "test_wf_ser",
		"序列化含 event_name 且值正确（实际 %s）" % str(data.get("event_name", "<缺失>")))
	_check(data.has("timeout") and is_equal_approx(float(data["timeout"]), 3.5),
		"序列化含 timeout 且值正确（实际 %s）" % str(data.get("timeout", "<缺失>")))

	var restored: BaseInstruction = PresetValueCodec.deserialize_instruction(data)
	_check(restored is WaitForEvent, "反序列化还原为 WaitForEvent")
	if restored is WaitForEvent:
		var restored_wait := restored as WaitForEvent
		_check(restored_wait.event_name == "test_wf_ser", "round-trip event_name 一致")
		_check(is_equal_approx(restored_wait.timeout, 3.5), "round-trip timeout 一致")
