extends Node

## NODE_GROUP 数据源 get_node_tree 扫尾抽查测试（2026-08-25）
##
## 抽查 arrays/conditions 两族的 NODE_GROUP 真实运行路径：
## 1. 指令侧：ArrayAdd NODE_GROUP——Runner 全链路执行，后续指令照常跑
## 2. 条件侧：CheckArraySize NODE_GROUP——组大小比较真实求值
##
## 修复前（get_node_tree）：ExecutionContext 无此方法，运行时
## SCRIPT ERROR（Invalid call）中断执行链，两断言必失败。
## 修复后（context.get_tree()）：tree 属性访问器 + current_scene 回退。
##
## 参数说明（对 brief 模板的实测修正）：
## - SourceType.NODE_GROUP = 2（VARIABLE=0, NODE_CHILDREN=1, NODE_GROUP=2）
## - CheckArraySize.Comparison.EQUALS（非 EQUAL）；比较值成员为 compare_value
## - ArrayAdd NODE_GROUP 模式的目标数组即 get_nodes_in_group 返回的数组
##   副本（不写任何变量），故无需预置全局变量（简于 brief 预案）

var _fail: int = 0

## 副作用探针：验证 ArrayAdd 之后的后续指令照常执行
class RecordingInstruction:
	extends BaseInstruction
	var records: Array
	func _init(records: Array = []) -> void:
		self.records = records
	func _setup_metadata() -> void:
		pass
	func _update_resource_name() -> void:
		resource_name = "RecordingInstruction"
	func execute(context: ExecutionContext) -> void:
		_start_execution(context)
		records.append(1)
		_on_execution_completed()
	func get_description() -> String:
		return "记录探针指令"

func _ready() -> void:
	print("=== NODE_GROUP 扫尾抽查测试开始 ===\n")

	# headless 首帧 delta 异常大：先等两帧让引擎帧时间稳定（参照 test_for_each）
	await get_tree().process_frame
	await get_tree().process_frame

	await _test_array_add_node_group()
	_test_check_array_size_node_group()

	print("\n=== NODE_GROUP 扫尾抽查测试完成（失败 %d 项）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("✓ " + message)
	else:
		_fail += 1
		push_error("✗ " + message)

## 指令侧：ArrayAdd 以 NODE_GROUP 为数据源（修复前 get_node_tree 必报错）
func _test_array_add_node_group() -> void:
	print("\n--- ArrayAdd NODE_GROUP ---")
	var trigger := Node.new()
	trigger.name = "SweepTrigger"
	add_child(trigger)
	var member := Node.new()
	member.name = "SweepMember"
	member.add_to_group("sweep_group")
	trigger.add_child(member)

	var add_inst := ArrayAdd.new()
	add_inst.source_type = ArrayAdd.SourceType.NODE_GROUP
	add_inst.group_name = "sweep_group"
	add_inst.element_value = "sweep_element"

	var top: Array[BaseInstruction] = []
	top.append(add_inst)
	var records: Array = []
	top.append(RecordingInstruction.new(records))
	var runner := Runner.new()
	var ar := ActionRunner.new()
	ar.instructions = top
	runner.action_runner = ar
	add_child(runner)  # 触发 _ready：完成 RARI 初始化（参照 test_for_each）

	runner.run()
	# 有限观察窗轮询（不用 wait_completed：修复前 SCRIPT ERROR 会中断 RARI
	# 协程，runner 永不 completed，wait_completed 将永久挂起导致测试卡死）
	var completed_in_window: bool = false
	for i in range(300):
		await get_tree().process_frame
		if not runner.is_running():
			completed_in_window = true
			break
	# 断言：Runner 全链路完成（修复前协程被 get_node_tree 错误中断、
	# 恒 running）、ArrayAdd 真实完成、后续指令照常执行
	_check(completed_in_window, "Runner 在观察窗内完成（未被 SCRIPT ERROR 中断）")
	_check(add_inst.is_completed(), "ArrayAdd NODE_GROUP 真实执行完成（无 SCRIPT ERROR）")
	_check(records.size() == 1, "ArrayAdd 之后的后续指令照常执行")
	runner.queue_free()
	trigger.queue_free()

## 条件侧：CheckArraySize 以 NODE_GROUP 为数据源（组内 1 节点 == 1）
func _test_check_array_size_node_group() -> void:
	print("\n--- CheckArraySize NODE_GROUP ---")
	var trigger := Node.new()
	trigger.name = "CasTrigger"
	add_child(trigger)
	var member := Node.new()
	member.name = "CasMember"
	member.add_to_group("sweep_group_2")
	trigger.add_child(member)

	var cond := CheckArraySize.new()
	cond.source_type = CheckArraySize.SourceType.NODE_GROUP
	cond.group_name = "sweep_group_2"
	cond.comparison = CheckArraySize.Comparison.EQUALS
	cond.compare_value = 1

	var context := ExecutionContext.new(trigger, trigger)
	_check(cond.check(context) == true, "CheckArraySize NODE_GROUP 真实求值（组 1 节点 == 1）")
	# 反向 sanity：比较值不匹配时应为 false（证明是真实求值而非恒真）
	cond.compare_value = 2
	_check(cond.check(context) == false, "CheckArraySize NODE_GROUP 反向求值（组 1 节点 != 2）")
	trigger.queue_free()
