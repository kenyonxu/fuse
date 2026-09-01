# 测试：WaitForSignal 指令（信号到达/超时/取消清理/参数捕获/双路径）
extends Node

var _fail: int = 0

# lambda 信号回调载体（GDScript lambda 按值捕获局部变量，须用成员变量传递结果）
var _failed_msg: String = ""
var _completed_flag: bool = false
var _finished_count: int = 0

class SignalEmitter:
	extends Node
	signal custom_signal(value: int, label: String)

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
			"event_value": context.get_variable("event_value"),
			"event_label": context.get_variable("event_label"),
		})
		_on_execution_completed()
	func get_description() -> String:
		return "记录 event_* 变量的测试指令"

func _ready() -> void:
	print("=== WaitForSignal 测试开始 ===")
	await _test_signal_arrives_legacy()
	await _test_timeout_fails()
	await _test_no_timeout_mode()
	await _test_cancel_cleans_connection()
	await _test_missing_signal_fails()
	await _test_runtime_path()
	await _test_runtime_path_cancel()
	await _test_rapid_rerun_no_stale_timeout()
	await _test_pause_freezes_timeout()
	await _test_sibling_path_resolution()
	await _test_serialization_roundtrip()
	print("=== WaitForSignal 测试完成（失败 %d 项）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("✓ " + message)
	else:
		_fail += 1
		push_error("✗ " + message)

## 遗留路径：Runner + [WaitForSignal, Recording] 驱动
func _run_with_runner(emitter: Node, wait_inst: WaitForSignal, records: Array) -> Runner:
	var runner := Runner.new()
	var instructions: Array[BaseInstruction] = []
	instructions.append(wait_inst)
	var rec := RecordingInstruction.new(records)
	instructions.append(rec)
	var ar := ActionRunner.new()
	ar.instructions = instructions
	ar.execution_mode = ActionRunner.ExecutionMode.SEQUENTIAL
	# 注意顺序：add_child 时 action_runner 必须尚未赋值（否则 _ready 创建
	# RARI 并连接信号后，手动 _ready 再建的 RARI 因 _runtime_signals_connected
	# 守卫不会连接，wait_completed 永久挂起）。对齐 test_cancel_propagation.gd 模式。
	add_child(runner)
	runner.action_runner = ar
	# WaitForSignal 的 target_node 相对解析基准：Runner 节点，emitter 挂其下
	if emitter.get_parent() == null:
		runner.add_child(emitter)
	runner._ready()
	return runner

func _test_signal_arrives_legacy() -> void:
	print("\n--- 信号到达（遗留路径）---")
	var emitter := SignalEmitter.new()
	emitter.name = "Emitter"
	var wait_inst := WaitForSignal.new()
	wait_inst.target_node = NodePath("Emitter")
	wait_inst.target_signal = "custom_signal"
	wait_inst.timeout = 5.0
	var records: Array = []
	var runner := _run_with_runner(emitter, wait_inst, records)

	runner.run()
	await get_tree().process_frame  # 让指令进入等待
	emitter.emit_signal("custom_signal", 42, "hello")
	await runner.wait_completed()
	_check(records.size() == 1, "信号到达后继续执行后续指令")
	if records.size() >= 1:
		_check(records[0]["event_value"] == 42, "event_value 捕获为 42")
		_check(records[0]["event_label"] == "hello", "event_label 捕获为 hello")
	runner.queue_free()

func _test_timeout_fails() -> void:
	print("\n--- 超时失败 ---")
	var emitter := SignalEmitter.new()
	emitter.name = "Emitter"
	var wait_inst := WaitForSignal.new()
	wait_inst.target_node = NodePath("Emitter")
	wait_inst.target_signal = "custom_signal"
	wait_inst.timeout = 0.1
	var records: Array = []
	var runner := _run_with_runner(emitter, wait_inst, records)

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
	runner.queue_free()

func _test_no_timeout_mode() -> void:
	print("\n--- timeout=0 无限模式 ---")
	var emitter := SignalEmitter.new()
	emitter.name = "Emitter"
	var wait_inst := WaitForSignal.new()
	wait_inst.target_node = NodePath("Emitter")
	wait_inst.target_signal = "custom_signal"
	wait_inst.timeout = 0.0
	var records: Array = []
	var runner := _run_with_runner(emitter, wait_inst, records)

	runner.run()
	await get_tree().create_timer(0.2).timeout  # 超过任何默认超时
	_check(runner.is_running(), "timeout=0 仍在等待")
	emitter.emit_signal("custom_signal", 7, "x")
	await runner.wait_completed()
	_check(records.size() == 1, "信号到达后完成")
	runner.queue_free()

func _test_cancel_cleans_connection() -> void:
	print("\n--- 取消清理连接 ---")
	var emitter := SignalEmitter.new()
	emitter.name = "Emitter"
	var wait_inst := WaitForSignal.new()
	wait_inst.target_node = NodePath("Emitter")
	wait_inst.target_signal = "custom_signal"
	wait_inst.timeout = 0.0
	var records: Array = []
	var runner := _run_with_runner(emitter, wait_inst, records)

	runner.run()
	await get_tree().process_frame
	runner.cancel("测试取消")
	for i in range(10):
		await get_tree().process_frame
		if not runner.is_running():
			break
	_check(not runner.is_running(), "取消后协程唤醒（Task 1 传播）")

	# 取消后再发信号：完成回调不得触发（连接已断开）
	emitter.emit_signal("custom_signal", 1, "z")
	await get_tree().create_timer(0.2).timeout
	_check(not emitter.is_connected("custom_signal", wait_inst._on_target_signal_emitted),
		"信号连接已断开（is_connected 为 false）")
	_check(records.is_empty(), "取消后的信号不触发后续执行")
	runner.queue_free()

func _test_missing_signal_fails() -> void:
	print("\n--- 信号不存在 ---")
	var emitter := SignalEmitter.new()
	emitter.name = "Emitter"
	var wait_inst := WaitForSignal.new()
	wait_inst.target_node = NodePath("Emitter")
	wait_inst.target_signal = "no_such_signal"
	var records: Array = []
	var runner := _run_with_runner(emitter, wait_inst, records)

	_failed_msg = ""
	runner.execution_failed.connect(func(e): _failed_msg = e)
	runner.run()
	# 同步失败路径在 run() 返回前即发出 execution_failed；帧循环兜底
	for i in range(50):
		await get_tree().process_frame
		if not _failed_msg.is_empty():
			break
	_check(not _failed_msg.is_empty(), "信号不存在以 execution_failed 终止")
	runner.queue_free()

## Runtime 路径：直接驱动 RuntimeInstructionInstance
func _test_runtime_path() -> void:
	print("\n--- Runtime 路径 ---")
	var emitter := SignalEmitter.new()
	emitter.name = "Emitter"
	add_child(emitter)

	var trigger := Node.new()
	trigger.name = "FakeTrigger"
	add_child(trigger)
	emitter.reparent(trigger)

	var wait_inst := WaitForSignal.new()
	wait_inst.target_node = NodePath("Emitter")
	wait_inst.target_signal = "custom_signal"
	wait_inst.timeout = 5.0

	var context := ExecutionContext.new(trigger, trigger)
	var ri := RuntimeInstructionInstance.new(wait_inst, context, null)
	_completed_flag = false
	ri.finished.connect(func(): _completed_flag = true)
	var sync_done := ri.execute_sync()
	_check(sync_done == false, "execute_with_runtime_instance 返回 false（异步）")
	emitter.emit_signal("custom_signal", 9, "rt")
	for i in range(10):
		await get_tree().process_frame
		if _completed_flag:
			break
	_check(_completed_flag, "信号到达后实例完成")
	_check(context.get_variable("event_value") == 9, "Runtime 路径 event_value 捕获")
	ri.cleanup()
	trigger.queue_free()

## Runtime 路径取消：cancel_and_notify 触发指令 disconnect
func _test_runtime_path_cancel() -> void:
	print("\n--- Runtime 路径取消 ---")
	var emitter := SignalEmitter.new()
	emitter.name = "Emitter"
	var trigger := Node.new()
	trigger.name = "FakeTrigger2"
	add_child(trigger)
	trigger.add_child(emitter)

	var wait_inst := WaitForSignal.new()
	wait_inst.target_node = NodePath("Emitter")
	wait_inst.target_signal = "custom_signal"
	wait_inst.timeout = 0.0

	var context := ExecutionContext.new(trigger, trigger)
	var ri := RuntimeInstructionInstance.new(wait_inst, context, null)
	_finished_count = 0
	ri.finished.connect(func(): _finished_count += 1)
	ri.execute_sync()

	ri.cancel_and_notify()
	await get_tree().process_frame
	_check(_finished_count == 1, "cancel_and_notify 后 finished 恰好一次")
	_check(not emitter.is_connected("custom_signal", wait_inst._on_target_signal_emitted),
		"取消后信号连接断开")
	ri.cleanup()
	trigger.queue_free()

## 快速两轮执行无伪超时（容器 IfElse/ForLoop/ForEach 的 reset+execute 复用模式）：
## 第 1 轮正常完成后，其陈旧计时器在第 2 轮等待期内触发不得杀掉第 2 轮
func _test_rapid_rerun_no_stale_timeout() -> void:
	print("\n--- 快速两轮执行无伪超时 ---")
	var emitter := SignalEmitter.new()
	emitter.name = "Emitter"
	add_child(emitter)

	var wait_inst := WaitForSignal.new()
	wait_inst.target_node = NodePath(".")  # 相对 trigger（emitter）解析到自身
	wait_inst.target_signal = "custom_signal"
	wait_inst.timeout = 0.3

	# 第 1 轮：0.05s 时信号到达正常完成（0.3s 计时器未到即完成，成为陈旧计时器）
	var ctx1 := ExecutionContext.new(emitter, emitter)
	wait_inst.execute(ctx1)
	await get_tree().create_timer(0.05).timeout
	emitter.emit_signal("custom_signal", 1, "a")
	await get_tree().process_frame
	_check(wait_inst.execution_status == BaseInstruction.ExecutionStatus.COMPLETED,
		"第 1 轮信号到达正常完成")

	# 立即 reset 后第 2 轮执行（timeout=0：第 2 轮无自身计时器，
	# 0.5s 观察窗内唯一的触发源是第 1 轮的陈旧计时器）
	wait_inst.reset()
	wait_inst.timeout = 0.0
	var ctx2 := ExecutionContext.new(emitter, emitter)
	wait_inst.execute(ctx2)
	await get_tree().create_timer(0.5).timeout  # 跨过第 1 轮计时器 0.3s 触发点
	_check(wait_inst.execution_status == BaseInstruction.ExecutionStatus.RUNNING,
		"第 2 轮未被陈旧计时器伪超时（仍在等待）")
	_check(not wait_inst.has_error(), "第 2 轮无超时错误")

	# 清理第 2 轮
	wait_inst.cancel()
	emitter.queue_free()

## 暂停停表（runtime 路径）：pause 断开超时计时器并记录剩余，resume 按剩余续走
func _test_pause_freezes_timeout() -> void:
	print("\n--- 暂停停表 ---")
	var emitter := SignalEmitter.new()
	emitter.name = "Emitter"
	var trigger := Node.new()
	trigger.name = "FakeTrigger3"
	add_child(trigger)
	trigger.add_child(emitter)

	var wait_inst := WaitForSignal.new()
	wait_inst.target_node = NodePath("Emitter")
	wait_inst.target_signal = "custom_signal"
	wait_inst.timeout = 0.3

	var context := ExecutionContext.new(trigger, trigger)
	var ri := RuntimeInstructionInstance.new(wait_inst, context, null)
	ri.execute_sync()

	ri.pause()  # elapsed≈0，剩余超时≈0.3；计时器回调已断开
	await get_tree().create_timer(0.4).timeout  # 超过原 0.3s 超时
	_check(not ri.is_completed(), "暂停期间超时不触发（停表生效）")

	ri.resume()  # 为剩余时间重建计时器
	for i in range(50):
		await get_tree().process_frame
		if ri.is_completed():
			break
	_check(ri.is_completed(), "恢复后按剩余超时完成")
	_check(wait_inst.has_error(), "恢复后以超时错误完成")
	ri.cleanup()
	trigger.queue_free()

## 解析回归：编辑器资源上下文形态（target_node 相对 Runner 宿主为 "../Emitter"）
## 既有用例的 target_node 均为 Runner 直属子节点（"Emitter"）——未覆盖 "../兄弟"
## 形态；编辑器信号下拉修复（find_node_from_resource_context）与此同源，直接验证
func _test_sibling_path_resolution() -> void:
	print("\n--- 兄弟节点路径解析（../ 形态）---")
	var root := Node.new()
	root.name = "SimSceneRoot"
	add_child(root)
	var runner := Runner.new()
	root.add_child(runner)  # action_runner 未赋值先入树（对齐 _run_with_runner 顺序注释）
	var emitter := SignalEmitter.new()
	emitter.name = "Emitter"
	root.add_child(emitter)

	var wait_inst := WaitForSignal.new()
	wait_inst.target_node = NodePath("../Emitter")
	wait_inst.target_signal = "custom_signal"
	var instructions: Array[BaseInstruction] = []
	instructions.append(wait_inst)
	var ar := ActionRunner.new()
	ar.instructions = instructions
	runner.action_runner = ar

	# 编辑器同款资源上下文解析：资源宿主（Runner）基准的 "../Emitter" → 兄弟节点
	var found = FuseNodeUtils.find_node_from_resource_context(root, wait_inst, wait_inst.target_node)
	_check(found == emitter, "资源上下文解析 ../Emitter 命中 Runner 兄弟节点")

	# 运行时路径：以 trigger（Runner）为基准 _setup_target 成功解析同一形态
	var context := ExecutionContext.new(runner, runner)
	_check(wait_inst._setup_target(context), "_setup_target 以 Runner 为基准解析成功")
	_check(wait_inst._bound_node == emitter, "_bound_node 解析为兄弟 Emitter")
	wait_inst.cancel()
	root.queue_free()

## 序列化 round-trip：PresetValueCodec 保存/还原配置不丢失
func _test_serialization_roundtrip() -> void:
	print("\n--- 序列化 round-trip ---")
	var wait_inst := WaitForSignal.new()
	wait_inst.target_node = NodePath("Emitter")
	wait_inst.target_signal = "custom_signal"
	wait_inst.timeout = 3.5
	wait_inst.filter_signal_args = true
	wait_inst.arg_filter_values = {"value": 42}

	var data := PresetValueCodec.serialize_instruction(wait_inst)
	_check(data.has("target_node") and str(data["target_node"]) == "Emitter",
		"序列化含 target_node 且值正确（实际 %s）" % str(data.get("target_node", "<缺失>")))
	_check(data.has("target_signal") and data["target_signal"] == "custom_signal",
		"序列化含 target_signal 且值正确（实际 %s）" % str(data.get("target_signal", "<缺失>")))
	_check(data.has("timeout") and is_equal_approx(float(data["timeout"]), 3.5),
		"序列化含 timeout 且值正确（实际 %s）" % str(data.get("timeout", "<缺失>")))
	_check(data.has("filter_signal_args") and data["filter_signal_args"] == true,
		"序列化含 filter_signal_args 且值正确（实际 %s）" % str(data.get("filter_signal_args", "<缺失>")))
	_check(data.has("arg_filter_values") and data["arg_filter_values"].get("value") == 42,
		"序列化含 arg_filter_values 且值正确（实际 %s）" % str(data.get("arg_filter_values", "<缺失>")))

	var restored: BaseInstruction = PresetValueCodec.deserialize_instruction(data)
	_check(restored is WaitForSignal, "反序列化还原为 WaitForSignal")
	if restored is WaitForSignal:
		var restored_wait := restored as WaitForSignal
		_check(str(restored_wait.target_node) == "Emitter", "round-trip target_node 一致")
		_check(restored_wait.target_signal == "custom_signal", "round-trip target_signal 一致")
		_check(is_equal_approx(restored_wait.timeout, 3.5), "round-trip timeout 一致")
		_check(restored_wait.filter_signal_args == true, "round-trip filter_signal_args 一致")
		_check(restored_wait.arg_filter_values.get("value") == 42, "round-trip arg_filter_values 一致")
