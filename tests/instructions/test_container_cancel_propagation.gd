# 测试：取消传播穿透容器边界——在途子指令取消清理、嵌套递归、tween 钩子激活
#
# 构造说明（相对 brief 模板的实际修正）：
# - 三容器子指令列表实际属性名为 loop_instructions（非 instructions）
# - ForEach 遍历来源用 GLOBAL 数组变量（LOCAL 变量存 ExecutionContext 自身，
#   Runner 内建 context 无法预置；NODE_GROUP 模式调用的 get_node_tree() 在
#   ExecutionContext 上不存在，运行时必错）——GLOBAL 存 GlobalVariableAssistant
#   单例，跨 context 存活
# - Runner 经 add_child 触发 _ready 完成 RARI 初始化（手动再调 _ready 会
#   二次创建 RuntimeActionRunnerInstance）
# - TweenPulseAnimation 的 loop_count 默认 0 = 无限循环（execute 立即完成
#   不等 tween），异步在途断言需 loop_count >= 1
# - 计数器全部为成员变量（GDScript lambda 对局部变量按值捕获）
extends Node

var _fail: int = 0
var _canceled_count: int = 0
var _completed_count: int = 0
var _tween_finished_count: int = 0

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
	print("=== 容器取消传播测试开始 ===")
	# 预置 ForEach 遍历来源：GLOBAL 数组变量（单元素遍历）
	var setup_ctx := ExecutionContext.new(self, null)
	VariableOperations.set_variable(setup_ctx, "cancel_test_array", BaseVariable.VariableScope.GLOBAL, [0])
	setup_ctx = null
	# headless 首帧 delta 异常大：先等两帧让引擎帧时间稳定
	await get_tree().process_frame
	await get_tree().process_frame
	await _test_foreach_cancel_kills_child()
	await _test_nested_containers_cancel()
	await _test_sync_container_cancel_unchanged()
	await _test_tween_pulse_cancel_activates()
	print("=== 容器取消传播测试完成（失败 %d 项）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("✓ " + message)
	else:
		_fail += 1
		push_error("✗ " + message)

func _reset_counters() -> void:
	_canceled_count = 0
	_completed_count = 0
	_tween_finished_count = 0

## 组装单元素遍历的 ForEach（异步序列模式，走运行时实例路径）
func _build_for_each(children: Array[BaseInstruction]) -> ForEach:
	var fe := ForEach.new()
	fe.source_type = ForEach.SourceType.ARRAY
	fe.array_variable = "cancel_test_array"
	fe.array_scope = BaseVariable.VariableScope.GLOBAL
	fe.item_variable = "item"
	fe.index_variable = "index"
	fe.loop_instructions = children
	return fe

## 组装 Runner + [容器指令]（Runner 走 RARI + RII 路径）
func _build_runner(instructions: Array[BaseInstruction]) -> Runner:
	var runner := Runner.new()
	var ar := ActionRunner.new()
	ar.instructions = instructions
	runner.action_runner = ar
	add_child(runner)  # 触发 _ready：创建 RuntimeActionRunnerInstance 并连接信号
	return runner

## for_each 内嵌 [Wait(30), SideEffect]：取消后子计时器不跑完、副作用不执行
func _test_foreach_cancel_kills_child() -> void:
	print("\n--- for_each 取消清理 ---")
	_reset_counters()
	var wait_inst := Wait.new()
	wait_inst.wait_time = 30.0
	var child_list: Array[BaseInstruction] = []
	child_list.append(wait_inst)
	var records: Array = []
	child_list.append(SideEffectProbe.new(records))
	var fe := _build_for_each(child_list)
	var top: Array[BaseInstruction] = []
	top.append(fe)
	var runner := _build_runner(top)
	runner.execution_canceled.connect(func(_r): _canceled_count += 1)
	runner.execution_completed.connect(func(_t): _completed_count += 1)

	runner.run()
	await get_tree().process_frame  # 进入 for_each → 子 Wait 在途
	_check(runner.is_running(), "容器在途执行中")

	# 取消前抓取容器 RII 与在途子实例引用（取消后引用会被清理）
	var container_ri: RuntimeInstructionInstance = runner._runtime_instance._instruction_instances[0]
	var child_ri = container_ri.runtime_state.get("child_instance")
	_check(child_ri is RuntimeInstructionInstance, "取消前子 Wait 实例在途（前置 sanity）")

	runner.cancel("容器取消测试")
	for i in range(10):
		await get_tree().process_frame
		if _canceled_count > 0:
			break
	_check(_canceled_count == 1, "execution_canceled 恰一次（实际 %d）" % _canceled_count)
	_check(not runner.is_running(), "协程退出")

	# 取消传播核心断言：钩子对在途子实例递归取消并清理引用
	_check(container_ri.runtime_state.get("child_instance") == null, "容器清理在途子实例引用（钩子已执行）")
	if child_ri is RuntimeInstructionInstance:
		_check(child_ri.is_completed(), "在途子实例被递归取消（终态化）")
		_check(child_ri.runtime_state.get("timer") == null, "子 Wait 计时器已清理（回调断开）")

	# 取消后等待窗口：子 Wait 不跑完（计时器回调被断开）、SideEffect 不执行
	await get_tree().create_timer(0.3).timeout
	_check(records.is_empty(), "取消后子序列副作用不执行（不复活）")

	# 取消后可重 run：换成快速序列
	var quick: Array[BaseInstruction] = []
	var quick_records: Array = []
	quick.append(SideEffectProbe.new(quick_records))
	runner.action_runner.instructions = quick
	runner.run()
	await runner.wait_completed()
	await get_tree().process_frame
	_check(quick_records.size() == 1, "取消后可重新 run")
	runner.queue_free()

## 嵌套：for_each > for_loop > Wait(30)，取消逐层传播
func _test_nested_containers_cancel() -> void:
	print("\n--- 嵌套容器递归取消 ---")
	_reset_counters()
	var wait_inst := Wait.new()
	wait_inst.wait_time = 30.0
	var inner_list: Array[BaseInstruction] = []
	inner_list.append(wait_inst)
	var fl := ForLoop.new()
	fl.loop_count = 3
	fl.loop_instructions = inner_list
	var middle_list: Array[BaseInstruction] = []
	middle_list.append(fl)
	var fe := _build_for_each(middle_list)
	var top: Array[BaseInstruction] = []
	top.append(fe)
	var runner := _build_runner(top)
	runner.execution_canceled.connect(func(_r): _canceled_count += 1)

	runner.run()
	await get_tree().process_frame
	await get_tree().process_frame  # 两层容器进入子 Wait

	# 取消前抓取三层引用（外层容器 → 内层容器 → 叶子 Wait）
	var outer_ri: RuntimeInstructionInstance = runner._runtime_instance._instruction_instances[0]
	var inner_ri = outer_ri.runtime_state.get("child_instance")
	var leaf_ri = inner_ri.runtime_state.get("child_instance") if inner_ri is RuntimeInstructionInstance else null
	_check(leaf_ri is RuntimeInstructionInstance, "取消前叶子 Wait 实例在途（前置 sanity）")

	runner.cancel("嵌套取消")
	for i in range(10):
		await get_tree().process_frame
		if _canceled_count > 0:
			break
	_check(_canceled_count == 1, "嵌套取消 canceled 恰一次（实际 %d）" % _canceled_count)
	_check(not runner.is_running(), "嵌套取消协程退出")

	# 递归传播断言：外层 → 内层 → 叶子逐层终态化并清理
	_check(outer_ri.runtime_state.get("child_instance") == null, "外层容器清理内层容器引用")
	if inner_ri is RuntimeInstructionInstance:
		_check(inner_ri.is_completed(), "内层容器被递归取消（终态化）")
		_check(inner_ri.runtime_state.get("child_instance") == null, "内层容器清理叶子子实例引用（递归传播）")
	if leaf_ri is RuntimeInstructionInstance:
		_check(leaf_ri.is_completed(), "叶子 Wait 实例被递归取消（计时器断开）")
	runner.queue_free()

## 全同步容器序列取消：现状行为回归（同步序列间隙取消不受影响）
func _test_sync_container_cancel_unchanged() -> void:
	print("\n--- 全同步容器取消回归 ---")
	_reset_counters()
	var child_list: Array[BaseInstruction] = []
	var records: Array = []
	child_list.append(SideEffectProbe.new(records))
	var fe := _build_for_each(child_list)
	var top: Array[BaseInstruction] = []
	top.append(fe)
	var runner := _build_runner(top)
	runner.execution_canceled.connect(func(_r): _canceled_count += 1)
	runner.execution_completed.connect(func(_t): _completed_count += 1)

	runner.run()
	await runner.wait_completed()
	await get_tree().process_frame
	_check(_completed_count == 1 and records.size() == 1, "全同步容器正常完成不受影响")
	runner.cancel("完成后取消")  # 空转取消无害
	await get_tree().process_frame
	_check(_canceled_count == 0, "完成后取消无副作用")
	runner.queue_free()

## L3 验证：tween_pulse 的孤儿钩子被激活（取消时 kill 而非跑完）
func _test_tween_pulse_cancel_activates() -> void:
	print("\n--- tween_pulse 钩子激活 ---")
	_reset_counters()
	var trigger := Node.new()
	trigger.name = "TweenTrigger"
	add_child(trigger)
	var sprite := Node2D.new()
	sprite.name = "TargetSprite"
	trigger.add_child(sprite)

	var tween_inst := TweenPulseAnimation.new()
	tween_inst.target_node = NodePath("TargetSprite")
	tween_inst.duration = 5.0
	tween_inst.loop_count = 1  # 默认 0 = 无限循环模式（execute 立即完成不等 tween）

	var context := ExecutionContext.new(trigger, trigger)
	var ri := RuntimeInstructionInstance.new(tween_inst, context, null)
	ri.finished.connect(func(): _tween_finished_count += 1)
	var sync := ri.execute_sync()
	_check(sync == false and _tween_finished_count == 0, "tween_pulse 在途（异步）")

	ri.cancel_and_notify()
	await get_tree().process_frame
	_check(_tween_finished_count == 1, "取消后实例完成（钩子 kill tween 并唤醒）")
	_check(ri.runtime_state.get("tween") == null, "运行时 tween 已 kill 并清理（钩子激活）")
	ri.cleanup()
	trigger.queue_free()
