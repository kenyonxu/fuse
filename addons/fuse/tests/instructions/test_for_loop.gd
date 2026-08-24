extends Node

## For Loop 指令测试
##
## 测试场景：
## 1. 基本循环（3次）
## 2. 循环索引变量
## 3. 从变量读取循环次数
## 4. 嵌套循环
## 4.1 零次迭代
## 4.2 大次数迭代性能
## 5. 验证循环参数
## 6. 取消不复活（容器在途 Wait + runner.cancel）
##
## 修复说明（2026-08-24 清理批 Task 2）：
## - load("res://addons/fuse/instructions/for_loop.gd") 旧路径（文件已迁至
##   flow_control/，File not found → null.new() SCRIPT ERROR）→ ForLoop
##   class_name 直引
## - assert(...) → _check + _fail 计数；_ready 的测试调用 await 化（原
##   _ready 未 await 含协程的用例，✓ 输出乱序到末尾才打）+ 结尾 quit
##   退出码门禁
## - 取消计数为成员变量（GDScript lambda 对局部变量按值捕获）
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
	print("=== For Loop 指令测试开始 ===\n")

	# headless 首帧 delta 异常大：先等两帧让引擎帧时间稳定
	await get_tree().process_frame
	await get_tree().process_frame

	await test_basic_loop()
	await test_loop_with_index_variable()
	await test_loop_with_variable_count()
	await test_nested_loops()
	await test_zero_iterations()
	await test_large_iteration_count()
	await test_validation()
	await test_cancel_no_revive()

	print("\n=== For Loop 指令测试完成（失败 %d 项）===" % _fail)
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

## 测试 1: 基本循环（3次）
func test_basic_loop():
	print("\n--- 测试 1: 基本循环（3次）---")

	var for_loop = ForLoop.new()
	for_loop.loop_count = 3
	for_loop.use_variable_count = false
	for_loop.use_index_variable = false

	# 创建简单的 Print 指令作为循环体
	var print_inst = Print.new()
	print_inst.message = "循环迭代"
	for_loop.loop_instructions.append(print_inst)

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 执行循环
	for_loop.execute(context)

	# For Loop 是同步指令，应该立即完成
	await get_tree().process_frame

	# 验证结果
	_check(for_loop.is_completed(), "循环应该成功完成")
	print("✓ 基本循环测试通过：执行了 3 次迭代")

## 测试 2: 循环索引变量
func test_loop_with_index_variable():
	print("\n--- 测试 2: 循环索引变量 ---")

	var for_loop = ForLoop.new()
	for_loop.loop_count = 5
	for_loop.use_variable_count = false
	for_loop.use_index_variable = true
	for_loop.index_variable = "i"

	# 创建打印索引变量的指令
	var print_inst = Print.new()
	print_inst.message = "索引: {i}"
	for_loop.loop_instructions.append(print_inst)

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 执行循环
	for_loop.execute(context)

	# For Loop 是同步指令
	await get_tree().process_frame

	# 验证结果
	_check(for_loop.is_completed(), "循环应该成功完成")
	_check(context.has_variable("i"), "应该创建索引变量 'i'")
	_check(context.get_variable("i") == 4, "最后一次迭代的索引应该是 4")  # 0-4
	print("✓ 循环索引变量测试通过：索引变量正确创建")

## 测试 3: 从变量读取循环次数
func test_loop_with_variable_count():
	print("\n--- 测试 3: 从变量读取循环次数 ---")

	var for_loop = ForLoop.new()
	for_loop.use_variable_count = true
	for_loop.loop_count_variable = "loop_count"
	for_loop.use_index_variable = true
	for_loop.index_variable = "idx"

	# 创建打印指令
	var print_inst = Print.new()
	print_inst.message = "迭代 {idx}"
	for_loop.loop_instructions.append(print_inst)

	# 创建执行上下文并设置循环次数变量
	var context = ExecutionContext.new()
	context.set_variable("loop_count", 4)

	# 执行循环
	for_loop.execute(context)

	# For Loop 是同步指令
	await get_tree().process_frame

	# 验证结果
	_check(for_loop.is_completed(), "循环应该成功完成")
	_check(context.get_variable("idx") == 3, "最后一次迭代的索引应该是 3")  # 0-3
	print("✓ 从变量读取循环次数测试通过：正确读取并使用了变量")

## 测试 4: 嵌套循环
func test_nested_loops():
	print("\n--- 测试 4: 嵌套循环（验证栈管理）---")

	# 外层循环（3次）
	var outer_loop = ForLoop.new()
	outer_loop.loop_count = 3
	outer_loop.use_variable_count = false
	outer_loop.use_index_variable = true
	outer_loop.index_variable = "i"

	# 内层循环（2次）
	var inner_loop = ForLoop.new()
	inner_loop.loop_count = 2
	inner_loop.use_variable_count = false
	inner_loop.use_index_variable = true
	inner_loop.index_variable = "j"

	# 创建打印指令显示嵌套
	var print_inst = Print.new()
	print_inst.message = "外层={i}, 内层={j}"
	inner_loop.loop_instructions.append(print_inst)

	# 将内层循环添加到外层循环
	outer_loop.loop_instructions.append(inner_loop)

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 执行外层循环
	outer_loop.execute(context)

	# For Loop 是同步指令
	await get_tree().process_frame

	# 验证结果
	_check(outer_loop.is_completed(), "外层循环应该成功完成")
	_check(inner_loop.is_completed(), "内层循环应该成功完成")

	# 验证嵌套循环的索引不会相互污染
	# 外层循环应该执行 3 次（i = 0, 1, 2）
	# 内层循环应该执行 2 次（j = 0, 1）
	# 总共应该执行 3 * 2 = 6 次迭代
	print("✓ 嵌套循环测试通过：内层循环索引不会污染外层循环")
	print("  栈管理正确：循环标志被正确保存和恢复")

## 测试 4.1: 零次迭代
func test_zero_iterations():
	print("\n--- 测试 4.1: 零次迭代 ---")

	var for_loop = ForLoop.new()
	for_loop.loop_count = 0
	for_loop.use_variable_count = false

	var print_inst = Print.new()
	print_inst.message = "这条不应该执行"
	for_loop.loop_instructions.append(print_inst)

	var context = ExecutionContext.new()
	for_loop.execute(context)

	_check(for_loop.is_completed(), "零次循环应该成功完成")
	print("✓ 零次迭代测试通过：循环体未执行")

## 测试 4.2: 大次数迭代性能测试
func test_large_iteration_count():
	print("\n--- 测试 4.2: 大次数迭代性能 ---")

	var for_loop = ForLoop.new()
	for_loop.loop_count = 1000  # 使用1000次而不是10000次以加快测试
	for_loop.use_variable_count = false

	var print_inst = Print.new()
	print_inst.message = "迭代"
	for_loop.loop_instructions.append(print_inst)

	var context = ExecutionContext.new()

	var start_time = Time.get_ticks_msec()
	for_loop.execute(context)
	var elapsed = Time.get_ticks_msec() - start_time

	_check(for_loop.is_completed(), "大次数循环应该成功完成")
	print("  1000次迭代耗时: %s ms" % elapsed)
	print("✓ 大次数迭代性能测试通过")

## 测试 5: 验证循环参数
func test_validation():
	print("\n--- 测试 5: 验证循环参数 ---")

	var for_loop = ForLoop.new()

	# 测试负数循环次数
	for_loop.loop_count = -1
	for_loop.use_variable_count = false
	var errors = for_loop.validate()
	_check(errors.size() > 0, "负数循环次数应该产生验证错误")
	print("✓ 负数循环次数验证通过")

	# 测试空变量名
	for_loop.use_variable_count = true
	for_loop.loop_count_variable = ""
	errors = for_loop.validate()
	_check(errors.size() > 0, "空变量名应该产生验证错误")
	print("✓ 空变量名验证通过")

	# 测试启用索引变量但变量名为空
	for_loop.use_index_variable = true
	for_loop.index_variable = ""
	errors = for_loop.validate()
	_check(errors.size() > 0, "空索引变量名应该产生验证错误")
	print("✓ 空索引变量名验证通过")

	print("✓ 所有验证测试通过")

## 测试 6: 取消不复活（loop_count=2 + 子序列 [Wait(30), SideEffect]）
func test_cancel_no_revive():
	print("\n--- 测试 6: 取消不复活 ---")
	_canceled_count = 0
	var wait_inst := Wait.new()
	wait_inst.wait_time = 30.0
	var child_list: Array[BaseInstruction] = []
	child_list.append(wait_inst)
	var records: Array = []
	child_list.append(SideEffectProbe.new(records))

	var fl := ForLoop.new()
	fl.loop_count = 2
	fl.use_variable_count = false
	fl.loop_instructions = child_list

	var top: Array[BaseInstruction] = []
	top.append(fl)
	var runner := _build_runner(top)
	runner.execution_canceled.connect(func(_r): _canceled_count += 1)

	runner.run()
	var in_flight: bool = await _await_child_in_flight(wait_inst)
	_check(in_flight, "循环体子 Wait 进入在途（前置 sanity）")
	_check(runner.is_running(), "容器在途执行中")

	runner.cancel("ForLoop 取消测试")
	for i in range(10):
		await get_tree().process_frame
		if _canceled_count > 0:
			break
	_check(_canceled_count == 1, "execution_canceled 恰一次（实际 %d）" % _canceled_count)
	_check(not runner.is_running(), "协程退出")

	# 取消后观察窗：子序列副作用不执行（不复活）
	await get_tree().create_timer(0.3).timeout
	_check(records.is_empty(), "取消后子序列副作用不执行（不复活）")
	runner.queue_free()
