# 测试：IfElse/IfThen 遗留协程取消后不复活——重写 cancel 对在途子指令传播唤醒协程，
# 异步循环补 CANCELLED 检查退出。
#
# 构造说明（相对 brief 模板的实际修正）：
# - 恒真条件：条件组件库无现成 AlwaysTrue，测试内联 TrueCondition（BaseCondition
#   三个抽象方法的最小实现），零环境依赖（CompareVariable 需预置变量、
#   CheckNodeExists 依赖 context.target 解析，均不如内联恒真简明）
# - Wait 时长用 0.15s（brief 模板 30s）：现状缺陷形态为"悬置泄漏 + 迟到复活"——
#   Wait 不被取消、timer 不清理，30s 后才自然完成复活；观察窗 0.3s 内测不到。
#   缩短至 0.15s 后 RED 可见（timer 跑完 → 协程复活执行探针）
# - canceled 计数为成员变量（GDScript lambda 对局部变量按值捕获，brief 模板的
#   局部计数永不生效）
# - _build_runner 不手动调 runner._ready()：add_child 已触发 _ready，手动再调
#   会二次创建 RuntimeActionRunnerInstance（Task 1 实证）
# - 取消传播补强断言：在途子 Wait 被取消终态化（is_running → false）、
#   观察窗内不自然跑完（is_completed 保持 false）
extends Node

var _fail: int = 0
var _canceled_count: int = 0

## 恒真条件（最简构造：三个抽象方法的最小实现）
class TrueCondition:
	extends BaseCondition
	func _evaluate_condition(context: ExecutionContext) -> bool:
		return true
	func _compute_dependencies() -> Array[String]:
		return []
	func _update_resource_name() -> void:
		resource_name = "TrueCondition（恒真）"

## 副作用探针：Wait 之后才执行的指令（若取消后仍执行即为复活证据）
class SideEffectProbe:
	extends BaseInstruction
	var records: Array
	func _init(records: Array = []) -> void:
		self.records = records
	func _setup_metadata() -> void:
		pass
	func _update_resource_name() -> void:
		resource_name = "SideEffectProbe"
	func execute(context: ExecutionContext) -> void:
		_start_execution(context)
		records.append(1)
		_on_execution_completed()
	func get_description() -> String:
		return "副作用探针指令"

func _ready() -> void:
	print("=== IfElse/IfThen 取消不复活测试开始 ===")
	# headless 首帧 delta 异常大：先等两帧让引擎帧时间稳定（Task 1 先例）
	await get_tree().process_frame
	await get_tree().process_frame
	await _test_if_else_cancel()
	await _test_if_then_cancel()
	print("=== IfElse/IfThen 取消不复活测试完成（失败 %d 项）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("✓ " + message)
	else:
		_fail += 1
		push_error("✗ " + message)

## 组装 Runner + [容器指令]（Runner 走 RARI + RII 路径）
func _build_runner(top: Array[BaseInstruction]) -> Runner:
	var runner := Runner.new()
	var ar := ActionRunner.new()
	ar.instructions = top
	runner.action_runner = ar
	add_child(runner)  # 触发 _ready：创建 RuntimeActionRunnerInstance 并连接信号
	return runner

## 通用取消不复活流程：容器分支内 [Wait(0.15), SideEffect]，取消后探针不执行
func _run_cancel_no_revive(label: String, container: BaseInstruction, wait_inst: Wait, records: Array) -> void:
	print("\n--- %s 取消不复活 ---" % label)
	_canceled_count = 0
	var top: Array[BaseInstruction] = []
	top.append(container)
	var runner := _build_runner(top)
	runner.execution_canceled.connect(func(_r): _canceled_count += 1)

	runner.run()
	await get_tree().process_frame  # 进入分支 → 子 Wait 在途
	_check(runner.is_running(), "%s 在途执行中（前置 sanity）" % label)
	_check(wait_inst.is_running(), "%s 子 Wait 在途（前置 sanity）" % label)

	runner.cancel("%s 取消" % label)
	for i in range(10):
		await get_tree().process_frame
		if _canceled_count > 0:
			break
	_check(_canceled_count == 1, "%s canceled 恰一次（实际 %d）" % [label, _canceled_count])
	_check(not runner.is_running(), "%s 协程退出" % label)
	# 取消传播核心断言：在途子 Wait 被取消终态化（计时器清理）
	_check(not wait_inst.is_running(), "%s 在途子 Wait 已取消（取消传播）" % label)

	# 取消后观察窗（0.3s > Wait 0.15s）：不复活——子 Wait 不自然跑完、后续指令不执行
	await get_tree().create_timer(0.3).timeout
	_check(not wait_inst.is_completed(), "%s 子 Wait 取消后不自然跑完" % label)
	_check(records.is_empty(), "%s 取消后分支后续指令不执行（不复活）" % label)
	runner.queue_free()

## IfElse true 分支 [Wait(0.15), SideEffect]：条件恒真，取消后 SideEffect 不执行
func _test_if_else_cancel() -> void:
	var records: Array = []
	var wait_inst := Wait.new()
	wait_inst.wait_time = 0.15
	var true_list: Array[BaseInstruction] = []
	true_list.append(wait_inst)
	true_list.append(SideEffectProbe.new(records))
	var ife := IfElse.new()
	ife.condition = TrueCondition.new()
	ife.true_instructions = true_list
	await _run_cancel_no_revive("IfElse", ife, wait_inst, records)

## IfThen 同构：instructions 分支 [Wait(0.15), SideEffect]
func _test_if_then_cancel() -> void:
	var records: Array = []
	var wait_inst := Wait.new()
	wait_inst.wait_time = 0.15
	var then_list: Array[BaseInstruction] = []
	then_list.append(wait_inst)
	then_list.append(SideEffectProbe.new(records))
	var ift := IfThen.new()
	ift.condition = TrueCondition.new()
	ift.instructions = then_list
	await _run_cancel_no_revive("IfThen", ift, wait_inst, records)
