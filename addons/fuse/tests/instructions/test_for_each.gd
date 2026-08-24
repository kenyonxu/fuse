extends Node

## For Each 指令测试
##
## 测试场景：
## 1. 遍历数组
## 2. 遍历节点组
## 3. 跳过空元素
## 4. 嵌套循环
## 5. 验证参数
## 6. 取消不复活（容器在途 Wait + runner.cancel）
## 7. 混合嵌套取消（ForEach > IfElse true 分支 Wait）
##
## 修复说明（2026-08-24 清理批 Task 2）：
## - load("res://addons/fuse/instructions/for_each.gd") 旧路径（文件已迁至
##   flow_control/，File not found → null.new() SCRIPT ERROR）→ ForEach
##   class_name 直引
## - assert(...) → _check + _fail 计数；_ready 的测试调用 await 化 + 结尾
##   quit 退出码门禁
## - 取消用例的遍历来源用 GLOBAL 数组变量（Runner 内建 context 无法预置
##   LOCAL 变量；GLOBAL 存 GlobalVariableAssistant 单例，跨 context 存活）
## - 取消计数为成员变量（GDScript lambda 对局部变量按值捕获）
## - Runner 经 add_child 触发 _ready 完成 RARI 初始化（不手动再调 _ready）

var _fail: int = 0
var _canceled_count: int = 0

## 恒真条件（最简构造：BaseCondition 三个抽象方法的最小实现，参照 test_if_else_cancel_no_revive）
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

func _ready():
	print("=== For Each 指令测试开始 ===\n")

	# 预置取消用例的遍历来源：GLOBAL 数组变量（单元素遍历）
	var setup_ctx := ExecutionContext.new(self, null)
	VariableOperations.set_variable(setup_ctx, "fe_cancel_array", BaseVariable.VariableScope.GLOBAL, [0])
	setup_ctx = null

	# headless 首帧 delta 异常大：先等两帧让引擎帧时间稳定
	await get_tree().process_frame
	await get_tree().process_frame

	await test_for_each_array()
	await test_for_each_node_group()
	await test_for_each_skip_null()
	await test_nested_for_each()
	await test_validation()
	await test_cancel_no_revive()
	await test_nested_if_else_cancel()

	print("\n=== For Each 指令测试完成（失败 %d 项）===" % _fail)
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

## 测试 1: 遍历数组
func test_for_each_array():
	print("\n--- 测试 1: 遍历数组 ---")

	var for_each = ForEach.new()
	for_each.source_type = ForEach.SourceType.ARRAY
	for_each.array_variable = "my_array"
	for_each.item_variable = "item"
	for_each.skip_null_items = false

	# 创建打印指令
	var print_inst = Print.new()
	print_inst.message = "元素: {item}"
	for_each.loop_instructions.append(print_inst)

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 设置数组变量
	var test_array = [1, 2, 3, 4, 5]
	context.set_variable("my_array", test_array)

	# 执行 For Each
	for_each.execute(context)

	# For Each 是同步指令（含同步子指令时无实际 await 点）
	await get_tree().process_frame

	# 验证结果
	_check(for_each.is_completed(), "For Each 应该成功完成")
	print("✓ 遍历数组测试通过")

## 测试 2: 遍历节点组
func test_for_each_node_group():
	print("\n--- 测试 2: 遍历节点组 ---")

	var for_each = ForEach.new()
	for_each.source_type = ForEach.SourceType.NODE_GROUP
	for_each.group_name = "test_group"
	for_each.item_variable = "node"

	# 创建打印指令
	var print_inst = Print.new()
	print_inst.message = "节点: {node}"
	for_each.loop_instructions.append(print_inst)

	# 创建测试节点组
	var node1 = Node2D.new()
	node1.name = "TestNode1"
	var node2 = Node2D.new()
	node2.name = "TestNode2"

	get_tree().current_scene.add_child(node1)
	get_tree().current_scene.add_child(node2)
	node1.add_to_group("test_group")
	node2.add_to_group("test_group")

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 执行 For Each
	for_each.execute(context)

	await get_tree().process_frame

	# 验证结果
	_check(for_each.is_completed(), "For Each 应该成功完成")
	print("✓ 遍历节点组测试通过")

	# 清理
	node1.queue_free()
	node2.queue_free()

## 测试 3: 跳过空元素
func test_for_each_skip_null():
	print("\n--- 测试 3: 跳过空元素 ---")

	var for_each = ForEach.new()
	for_each.source_type = ForEach.SourceType.ARRAY
	for_each.array_variable = "mixed_array"
	for_each.item_variable = "item"
	for_each.skip_null_items = true

	# 创建打印指令
	var print_inst = Print.new()
	print_inst.message = "元素: {item}"
	for_each.loop_instructions.append(print_inst)

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 设置包含空元素的数组
	var test_array = [1, null, 2, null, 3]
	context.set_variable("mixed_array", test_array)

	# 执行 For Each
	for_each.execute(context)

	await get_tree().process_frame

	# 验证结果
	_check(for_each.is_completed(), "For Each 应该成功完成")
	print("✓ 跳过空元素测试通过")

## 测试 4: 嵌套 For Each
func test_nested_for_each():
	print("\n--- 测试 4: 嵌套 For Each ---")

	# 外层 For Each（遍历行）
	var outer_for_each = ForEach.new()
	outer_for_each.source_type = ForEach.SourceType.ARRAY
	outer_for_each.array_variable = "matrix"
	outer_for_each.item_variable = "row"

	# 内层 For Each（遍历列）
	var inner_for_each = ForEach.new()
	inner_for_each.source_type = ForEach.SourceType.ARRAY
	inner_for_each.array_variable = "row"
	inner_for_each.item_variable = "col"

	# 创建打印指令
	var print_inst = Print.new()
	print_inst.message = "行: {row}, 列: {col}"
	inner_for_each.loop_instructions.append(print_inst)

	# 将内层 For Each 添加到外层
	outer_for_each.loop_instructions.append(inner_for_each)

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 设置二维数组
	var test_matrix = [
		[1, 2, 3],
		[4, 5, 6],
		[7, 8, 9]
	]
	context.set_variable("matrix", test_matrix)

	# 执行外层 For Each
	outer_for_each.execute(context)

	await get_tree().process_frame

	# 验证结果
	_check(outer_for_each.is_completed(), "外层 For Each 应该成功完成")
	_check(inner_for_each.is_completed(), "内层 For Each 应该成功完成")
	print("✓ 嵌套 For Each 测试通过")

## 测试 5: 验证参数
func test_validation():
	print("\n--- 测试 5: 验证参数 ---")

	var for_each = ForEach.new()

	# 测试空元素变量名
	for_each.item_variable = ""
	var errors = for_each.validate()
	_check(errors.size() > 0, "空元素变量名应该产生验证错误")
	print("✓ 空元素变量名验证通过")

	# 测试空数组变量名（当源类型为 ARRAY 时）
	for_each.source_type = ForEach.SourceType.ARRAY
	for_each.array_variable = ""
	errors = for_each.validate()
	_check(errors.size() > 0, "空数组变量名应该产生验证错误")
	print("✓ 空数组变量名验证通过")

	# 测试空组名（当源类型为 NODE_GROUP 时）
	for_each.source_type = ForEach.SourceType.NODE_GROUP
	for_each.group_name = ""
	errors = for_each.validate()
	_check(errors.size() > 0, "空组名应该产生验证错误")
	print("✓ 空组名验证通过")

	print("✓ 所有验证测试通过")

## 测试 6: 取消不复活（单元素遍历 + 子序列 [Wait(30), SideEffect]）
func test_cancel_no_revive():
	print("\n--- 测试 6: 取消不复活 ---")
	_canceled_count = 0
	var wait_inst := Wait.new()
	wait_inst.wait_time = 30.0
	var child_list: Array[BaseInstruction] = []
	child_list.append(wait_inst)
	var records: Array = []
	child_list.append(SideEffectProbe.new(records))

	var fe := ForEach.new()
	fe.source_type = ForEach.SourceType.ARRAY
	fe.array_variable = "fe_cancel_array"
	fe.array_scope = BaseVariable.VariableScope.GLOBAL
	fe.item_variable = "item"
	fe.loop_instructions = child_list

	var top: Array[BaseInstruction] = []
	top.append(fe)
	var runner := _build_runner(top)
	runner.execution_canceled.connect(func(_r): _canceled_count += 1)

	runner.run()
	var in_flight: bool = await _await_child_in_flight(wait_inst)
	_check(in_flight, "容器子 Wait 进入在途（前置 sanity）")
	_check(runner.is_running(), "容器在途执行中")

	runner.cancel("ForEach 取消测试")
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

## 测试 7: 混合嵌套取消（ForEach > IfElse true 分支 [Wait(30), SideEffect]）
func test_nested_if_else_cancel():
	print("\n--- 测试 7: 混合嵌套取消（ForEach > IfElse）---")
	_canceled_count = 0
	var wait_inst := Wait.new()
	wait_inst.wait_time = 30.0
	var true_list: Array[BaseInstruction] = []
	true_list.append(wait_inst)
	var records: Array = []
	true_list.append(SideEffectProbe.new(records))
	var ife := IfElse.new()
	ife.condition = TrueCondition.new()
	ife.true_instructions = true_list

	var fe := ForEach.new()
	fe.source_type = ForEach.SourceType.ARRAY
	fe.array_variable = "fe_cancel_array"
	fe.array_scope = BaseVariable.VariableScope.GLOBAL
	fe.item_variable = "item"
	var loop_list: Array[BaseInstruction] = []
	loop_list.append(ife)
	fe.loop_instructions = loop_list

	var top: Array[BaseInstruction] = []
	top.append(fe)
	var runner := _build_runner(top)
	runner.execution_canceled.connect(func(_r): _canceled_count += 1)

	runner.run()
	var in_flight: bool = await _await_child_in_flight(wait_inst)
	_check(in_flight, "IfElse 分支子 Wait 进入在途（前置 sanity）")
	_check(runner.is_running(), "混合嵌套在途执行中")

	runner.cancel("混合嵌套取消测试")
	for i in range(10):
		await get_tree().process_frame
		if _canceled_count > 0:
			break
	_check(_canceled_count == 1, "混合嵌套 canceled 恰一次（实际 %d）" % _canceled_count)
	_check(not runner.is_running(), "混合嵌套协程退出")

	# 取消后观察窗：IfElse 分支副作用不执行（不复活）
	await get_tree().create_timer(0.3).timeout
	_check(records.is_empty(), "取消后 IfElse 分支副作用不执行（不复活）")
	runner.queue_free()
