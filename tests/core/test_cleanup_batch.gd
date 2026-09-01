# 测试：收尾清理批——NODE_GROUP 运行 / 循环顶取消 flush / 取消指令不发 completed
#
# 构造说明（相对 brief 模板的实际修正）：
# - Runner 经 add_child 触发 _ready 完成 RARI 初始化（手动再调 _ready 会
#   二次创建 RuntimeActionRunnerInstance，参照 test_container_cancel_propagation.gd）
# - 计数器全部为成员变量（GDScript lambda 对局部变量按值捕获）
extends Node

var _fail: int = 0
var _started_count: int = 0
var _completed_count: int = 0

class SyncProbe:
	extends BaseInstruction
	var records: Array
	func _init(records: Array = []) -> void:
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

func _ready() -> void:
	print("=== 清理批测试开始 ===")
	await get_tree().process_frame
	await _test_node_group_runs()
	await _test_loop_top_cancel_flush()
	await _test_cancelled_instruction_no_completed()
	print("=== 清理批测试完成（失败 %d 项）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("✓ " + message)
	else:
		_fail += 1
		push_error("✗ " + message)

## 立项 9：NODE_GROUP 遍历真实执行（现状 get_node_tree() 必报错）
func _test_node_group_runs() -> void:
	print("\n--- NODE_GROUP 遍历 ---")
	var trigger := Node.new()
	trigger.name = "NgTrigger"
	add_child(trigger)
	var member := Node.new()
	member.name = "GroupMember"
	member.add_to_group("cleanup_test_group")
	trigger.add_child(member)

	var child_list: Array[BaseInstruction] = []
	var records: Array = []
	child_list.append(SyncProbe.new(records))
	var fe := ForEach.new()
	fe.source_type = ForEach.SourceType.NODE_GROUP
	fe.group_name = "cleanup_test_group"
	fe.loop_instructions = child_list

	var top: Array[BaseInstruction] = []
	top.append(fe)
	var runner := Runner.new()
	var ar := ActionRunner.new()
	ar.instructions = top
	runner.action_runner = ar
	add_child(runner)  # 触发 _ready：创建 RuntimeActionRunnerInstance 并连接信号

	runner.run()
	await runner.wait_completed()
	await get_tree().process_frame
	_check(records.size() >= 1, "NODE_GROUP 遍历执行子指令（实际 %d）" % records.size())
	runner.queue_free()

## 立项 7：[Sync, Wait(30), Sync] 卡在 Wait 取消（仍有后续指令）——pending 清空 + 无跨 run 重放
func _test_loop_top_cancel_flush() -> void:
	print("\n--- 循环顶取消 flush ---")
	_started_count = 0
	_completed_count = 0
	var trigger := Node.new()
	trigger.name = "LoopTopTrigger"
	add_child(trigger)

	var instructions: Array[BaseInstruction] = []
	instructions.append(SyncProbe.new([]))
	var wait_inst := Wait.new()
	wait_inst.wait_time = 30.0
	instructions.append(wait_inst)
	instructions.append(SyncProbe.new([]))  # 后续指令（循环顶 return 场景的构成条件）
	var ar := ActionRunner.new()
	ar.instructions = instructions
	ar.stop_on_error = true

	var rari := RuntimeActionRunnerInstance.new(ar, trigger)
	rari.set_batch_signal_mode(true)
	rari.instruction_started.connect(func(_i): _started_count += 1)
	rari.instruction_completed.connect(func(_i): _completed_count += 1)

	var context := ExecutionContext.new(trigger, trigger)
	rari.run(context)
	await get_tree().process_frame  # Sync 完成（入 pending），卡在 Wait
	rari.cancel_execution("循环顶取消")
	for i in range(10):
		await get_tree().process_frame
		if not rari.is_running():
			break
	_check(not rari.is_running(), "取消后协程退出")
	_check(rari._pending_started_instructions.is_empty() and rari._pending_completed_instructions.is_empty(),
		"循环顶取消路径 pending 已清空")

	# 第二次 run 单探针：只重放自己的
	var second: Array[BaseInstruction] = []
	second.append(SyncProbe.new([]))
	rari.action_runner.instructions = second
	_started_count = 0
	_completed_count = 0
	rari.run(context)
	for i in range(10):
		await get_tree().process_frame
		if not rari.is_running():
			break
	_check(_started_count == 1 and _completed_count == 1,
		"第二次 run 只重放自己的指令信号（started=%d completed=%d）" % [_started_count, _completed_count])
	rari.cleanup()
	trigger.queue_free()

## 立项 6：被取消唤醒的 Wait 不发 instruction_completed（[Sync, Wait(30)] 取消）
func _test_cancelled_instruction_no_completed() -> void:
	print("\n--- 取消指令不发 completed ---")
	_started_count = 0
	_completed_count = 0
	var trigger := Node.new()
	trigger.name = "GateTrigger"
	add_child(trigger)

	var instructions: Array[BaseInstruction] = []
	instructions.append(SyncProbe.new([]))
	var wait_inst := Wait.new()
	wait_inst.wait_time = 30.0
	instructions.append(wait_inst)
	var ar := ActionRunner.new()
	ar.instructions = instructions

	var rari := RuntimeActionRunnerInstance.new(ar, trigger)
	rari.set_batch_signal_mode(false)  # 直发模式便于即时计数
	rari.instruction_started.connect(func(_i): _started_count += 1)
	rari.instruction_completed.connect(func(_i): _completed_count += 1)

	var context := ExecutionContext.new(trigger, trigger)
	rari.run(context)
	await get_tree().process_frame
	rari.cancel_execution("门控测试")
	for i in range(10):
		await get_tree().process_frame
		if not rari.is_running():
			break
	_check(_completed_count == 1, "只有 Sync 发 completed，被取消的 Wait 不发（实际 %d）" % _completed_count)
	rari.cleanup()
	trigger.queue_free()
