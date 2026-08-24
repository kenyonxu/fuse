extends Node

## While Loop 指令测试
##
## 测试场景：
## 1. While True 循环（简化版，无循环体）
## 2. While False 循环（不执行）
## 3. 最大迭代次数限制
## 4. 验证参数
## 5. 取消钩子直接测试（恒真条件 + 在途 Wait，cancel 触发 on_runtime_cancel）
##
## 修复说明（2026-08-24 清理批 Task 2）：
## - load("res://addons/fuse/instructions/while_loop.gd") 旧路径（文件已迁至
##   flow_control/，File not found → null.new() SCRIPT ERROR）→ WhileLoop
##   class_name 直引
## - ExecutionContext 是 RefCounted：去掉 add_child(context)/queue_free()；
##   `await context.finished`（ExecutionContext 无 finished 信号）→ 轮询
##   while_loop.is_completed() 成员标志帧循环（等待执行结束的等价改造）
## - 测试 1 条件恒真化：counter 初值 0 使 IS_TRUE（bool(0)=false）恒假循环
##   零次，原断言"5 次迭代"不可能成立——初值改 1 实现恒真；原
##   get_current_iteration() 无参调用恒返回 0（状态在 context.custom_data），
##   修正为传 context
## - assert(...) → _check + _fail 计数；_ready 的测试调用 await 化 + 结尾
##   quit 退出码门禁
## - 取消用例的条件变量用 GLOBAL（Runner 内建 context 无法预置 LOCAL 变量）；
##   取消计数为成员变量（GDScript lambda 对局部变量按值捕获）
## - Runner 经 add_child 触发 _ready 完成 RARI 初始化（不手动再调 _ready）

var _fail: int = 0
var _canceled_count: int = 0

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

func _ready():
	print("=== While Loop 指令测试开始 ===\n")

	# 预置取消用例的恒真条件：GLOBAL 变量（跨 context 存活）
	var setup_ctx := ExecutionContext.new(self, null)
	VariableOperations.set_variable(setup_ctx, "wl_cancel_flag", BaseVariable.VariableScope.GLOBAL, true)
	setup_ctx = null

	# headless 首帧 delta 异常大：先等两帧让引擎帧时间稳定
	await get_tree().process_frame
	await get_tree().process_frame

	await test_while_true()
	await test_while_false()
	await test_max_iterations()
	await test_validation()
	await test_cancel_hook()

	print("\n=== While Loop 指令测试完成（失败 %d 项）===" % _fail)
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

## 轮询等待容器进入在途子 Wait（返回是否进入在途）
func _await_child_in_flight(wait_inst: Wait) -> bool:
	for i in range(30):
		await get_tree().process_frame
		if wait_inst.is_running():
			return true
	return false

## 轮询等待指令完成（原 await context.finished 的等价等待）
func _await_instruction_completed(while_loop: WhileLoop) -> bool:
	for i in range(30):
		await get_tree().process_frame
		if while_loop.is_completed():
			return true
	return false

## 测试 1: While True 循环
func test_while_true():
	print("\n--- 测试 1: While True 循环（简化版）---")

	var while_loop = WhileLoop.new()
	var context = ExecutionContext.new()

	# 设置条件变量（初值 1 恒真：初值 0 会使 IS_TRUE 恒假，循环零次）
	context.set_variable("counter", 1)

	# 简化：不添加复杂的循环体指令，只测试循环控制本身
	while_loop.condition_variable = "counter"
	while_loop.condition_check = WhileLoop.ConditionCheck.IS_TRUE
	while_loop.max_iterations = 5  # 限制为5次迭代

	while_loop.execute(context)

	var completed: bool = await _await_instruction_completed(while_loop)

	# 验证循环执行了指定次数
	_check(completed, "While True 循环应该成功完成")
	_check(while_loop.get_current_iteration(context) == 5, "应该执行5次迭代（实际 %d）" % while_loop.get_current_iteration(context))
	print("✓ While True 循环测试通过（执行了 %d 次迭代）" % while_loop.get_current_iteration(context))

## 测试 2: While False 循环
func test_while_false():
	print("\n--- 测试 2: While False 循环（不执行）---")

	var while_loop = WhileLoop.new()
	var context = ExecutionContext.new()

	# 设置条件为 false
	context.set_variable("should_continue", false)

	# 创建打印指令
	var print_inst = Print.new()
	print_inst.message = "这条不应该执行"

	while_loop.condition_variable = "should_continue"
	while_loop.condition_check = WhileLoop.ConditionCheck.IS_TRUE
	while_loop.loop_instructions.append(print_inst)

	while_loop.execute(context)

	var completed: bool = await _await_instruction_completed(while_loop)

	_check(completed, "While False 应该成功完成（不执行循环体）")
	print("✓ While False 循环测试通过（循环体未执行）")

## 测试 3: 最大迭代次数限制
func test_max_iterations():
	print("\n--- 测试 3: 最大迭代次数限制 ---")

	var while_loop = WhileLoop.new()
	var context = ExecutionContext.new()

	# 设置条件变量（永远为真）
	context.set_variable("always_true", true)

	# 创建打印指令
	var print_inst = Print.new()
	print_inst.message = "迭代"

	while_loop.condition_variable = "always_true"
	while_loop.condition_check = WhileLoop.ConditionCheck.IS_TRUE
	while_loop.max_iterations = 10
	while_loop.loop_instructions.append(print_inst)

	while_loop.execute(context)

	var completed: bool = await _await_instruction_completed(while_loop)

	_check(completed, "While Loop 应该成功完成")
	_check(while_loop.get_current_iteration(context) == 10, "应该执行10次迭代后停止（实际 %d）" % while_loop.get_current_iteration(context))
	print("✓ 最大迭代次数限制测试通过（执行了 %d 次迭代）" % while_loop.get_current_iteration(context))

## 测试 4: 验证参数
func test_validation():
	print("\n--- 测试 4: 验证参数 ---")

	var while_loop = WhileLoop.new()

	# 测试空条件变量名
	while_loop.condition_variable = ""
	var errors = while_loop.validate()
	_check(errors.size() > 0, "空条件变量名应该产生验证错误")
	print("✓ 空条件变量名验证通过")

	# 测试无效的最大迭代次数
	while_loop.condition_variable = "test"
	while_loop.max_iterations = 0
	errors = while_loop.validate()
	_check(errors.size() > 0, "最大迭代次数为0应该产生验证错误")
	print("✓ 最大迭代次数验证通过")

	# 测试负数最大迭代次数
	while_loop.max_iterations = -1
	errors = while_loop.validate()
	_check(errors.size() > 0, "负数最大迭代次数应该产生验证错误")
	print("✓ 负数最大迭代次数验证通过")

	print("✓ 所有验证测试通过")

## 测试 5: 取消钩子直接测试（恒真条件 + 循环体 [Wait(30), SideEffect]）
##
## runner.cancel → WhileLoop.on_runtime_cancel 钩子对在途子实例递归取消并
## 清理引用（deferred minor "钩子直接测试" 清偿）
func test_cancel_hook():
	print("\n--- 测试 5: 取消钩子直接测试 ---")
	_canceled_count = 0
	var wait_inst := Wait.new()
	wait_inst.wait_time = 30.0
	var child_list: Array[BaseInstruction] = []
	child_list.append(wait_inst)
	var records: Array = []
	child_list.append(SideEffectProbe.new(records))

	var wl := WhileLoop.new()
	wl.condition_variable = "wl_cancel_flag"
	wl.variable_scope = BaseVariable.VariableScope.GLOBAL
	wl.condition_check = WhileLoop.ConditionCheck.IS_TRUE
	wl.max_iterations = 100
	wl.loop_instructions = child_list

	var top: Array[BaseInstruction] = []
	top.append(wl)
	var runner := _build_runner(top)
	runner.execution_canceled.connect(func(_r): _canceled_count += 1)

	runner.run()
	var in_flight: bool = await _await_child_in_flight(wait_inst)
	_check(in_flight, "循环体子 Wait 进入在途（前置 sanity）")
	_check(runner.is_running(), "WhileLoop 在途执行中")

	# 取消前抓取容器 RII 与在途子实例引用（取消后引用会被清理）
	var container_ri: RuntimeInstructionInstance = runner._runtime_instance._instruction_instances[0]
	var child_ri = container_ri.runtime_state.get("child_instance")
	_check(child_ri is RuntimeInstructionInstance, "取消前子 Wait 实例在途（前置 sanity）")

	runner.cancel("WhileLoop 取消测试")
	for i in range(10):
		await get_tree().process_frame
		if _canceled_count > 0:
			break
	_check(_canceled_count == 1, "execution_canceled 恰一次（实际 %d）" % _canceled_count)
	_check(not runner.is_running(), "协程退出")

	# 取消钩子核心断言：on_runtime_cancel 对在途子实例递归取消并清理引用
	_check(container_ri.runtime_state.get("child_instance") == null, "容器清理在途子实例引用（钩子已执行）")
	if child_ri is RuntimeInstructionInstance:
		_check(child_ri.is_completed(), "在途子实例被递归取消（终态化）")
		_check(child_ri.runtime_state.get("timer") == null, "子 Wait 计时器已清理（回调断开）")

	# 取消后观察窗：循环体副作用不执行（不复活）
	await get_tree().create_timer(0.3).timeout
	_check(records.is_empty(), "取消后循环体副作用不执行（不复活）")
	runner.queue_free()
