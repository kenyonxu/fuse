extends Node
## 测试 RunConditionCheck 条件检查指令

var action_runner: ActionRunner
var execution_context: ExecutionContext
var check_variable: CheckVariable
var run_condition_check

func _ready():
	print("=== 开始测试 RunConditionCheck 条件检查指令 ===")
	
	# 初始化组件
	_setup_components()
	
	# 运行测试
	call_deferred("_run_tests")

func _setup_components():
	# 创建 ActionRunner
	action_runner = ActionRunner.new()
	
	# 创建执行上下文
	execution_context = ExecutionContext.new()
	
	# 创建 CheckVariable 条件
	check_variable = CheckVariable.new()
	check_variable.variable_name = "test_score"
	check_variable.comparison_operator = CheckVariable.ComparisonOperator.EQUALS
	check_variable.expected_value = 100
	
	# 创建 RunConditionCheck 指令
	run_condition_check = RunConditionCheck.new()
	run_condition_check.condition = check_variable
	run_condition_check.on_condition_true = RunConditionCheck.ConditionBehavior.CONTINUE
	run_condition_check.on_condition_false = RunConditionCheck.ConditionBehavior.SKIP_NEXT
	run_condition_check.skip_count = 2

func _run_tests():
	# 测试 1: 条件为真，继续执行
	_test_condition_true_continue()
	
	# 测试 2: 条件为假，跳过后续指令
	_test_condition_false_skip_next()
	
	# 测试 3: 条件为假，跳过所有剩余指令
	_test_condition_false_skip_remaining()
	
	# 测试 4: 条件为假，停止执行
	_test_condition_false_stop_execution()
	
	# 测试 5: 验证功能
	_test_validation()
	
	print("=== 所有测试完成 ===")

func _test_condition_true_continue():
	print("\n--- 测试 1: 条件为真，继续执行 ---")
	
	# 重置组件
	action_runner.reset()
	execution_context.reset_execution_state()
	execution_context.set_variable("test_score", 100)  # 设置条件为真
	
	# 创建测试指令序列
	var instructions = []
	
	# 指令 1: 条件检查
	var condition_check = RunConditionCheck.new()
	condition_check.condition = check_variable
	condition_check.on_condition_true = RunConditionCheck.ConditionBehavior.CONTINUE
	condition_check.on_condition_false = RunConditionCheck.ConditionBehavior.SKIP_NEXT
	instructions.append(condition_check)
	
	# 指令 2: 应该执行
	var instruction2 = TestInstruction.new("指令2 (应该执行)")
	instructions.append(instruction2)
	
	# 指令 3: 应该执行
	var instruction3 = TestInstruction.new("指令3 (应该执行)")
	instructions.append(instruction3)
	
	# 设置指令到 ActionRunner
	for instruction in instructions:
		action_runner.add_instruction(instruction)
	
	# 运行测试
	var result = await _run_action_runner_test()
	
	print("条件为真测试: %s (期望: 通过)" % ("通过" if result else "失败"))
	assert(result, "条件为真测试失败")

func _test_condition_false_skip_next():
	print("\n--- 测试 2: 条件为假，跳过后续指令 ---")
	
	# 重置组件
	action_runner.reset()
	execution_context.reset_execution_state()
	execution_context.set_variable("test_score", 50)  # 设置条件为假
	
	# 创建测试指令序列
	var instructions = []
	
	# 指令 1: 条件检查
	var condition_check = RunConditionCheck.new()
	condition_check.condition = check_variable
	condition_check.on_condition_true = RunConditionCheck.ConditionBehavior.CONTINUE
	condition_check.on_condition_false = RunConditionCheck.ConditionBehavior.SKIP_NEXT
	condition_check.skip_count = 1
	instructions.append(condition_check)
	
	# 指令 2: 应该被跳过
	var instruction2 = TestInstruction.new("指令2 (应该被跳过)")
	instructions.append(instruction2)
	
	# 指令 3: 应该执行
	var instruction3 = TestInstruction.new("指令3 (应该执行)")
	instructions.append(instruction3)
	
	# 设置指令到 ActionRunner
	for instruction in instructions:
		action_runner.add_instruction(instruction)
	
	# 运行测试
	var result = await _run_action_runner_test()
	
	print("条件为假跳过测试: %s (期望: 通过)" % ("通过" if result else "失败"))
	assert(result, "条件为假跳过测试失败")

func _test_condition_false_skip_remaining():
	print("\n--- 测试 3: 条件为假，跳过所有剩余指令 ---")
	
	# 重置组件
	action_runner.reset()
	execution_context.reset_execution_state()
	execution_context.set_variable("test_score", 50)  # 设置条件为假
	
	# 创建测试指令序列
	var instructions = []
	
	# 指令 1: 条件检查
	var condition_check = RunConditionCheck.new()
	condition_check.condition = check_variable
	condition_check.on_condition_true = RunConditionCheck.ConditionBehavior.CONTINUE
	condition_check.on_condition_false = RunConditionCheck.ConditionBehavior.SKIP_REMAINING
	instructions.append(condition_check)
	
	# 指令 2: 应该被跳过
	var instruction2 = TestInstruction.new("指令2 (应该被跳过)")
	instructions.append(instruction2)
	
	# 指令 3: 应该被跳过
	var instruction3 = TestInstruction.new("指令3 (应该被跳过)")
	instructions.append(instruction3)
	
	# 设置指令到 ActionRunner
	for instruction in instructions:
		action_runner.add_instruction(instruction)
	
	# 运行测试
	var result = await _run_action_runner_test()
	
	print("条件为假跳过剩余测试: %s (期望: 通过)" % ("通过" if result else "失败"))
	assert(result, "条件为假跳过剩余测试失败")

func _test_condition_false_stop_execution():
	print("\n--- 测试 4: 条件为假，停止执行 ---")
	
	# 重置组件
	action_runner.reset()
	execution_context.reset_execution_state()
	execution_context.set_variable("test_score", 50)  # 设置条件为假
	
	# 创建测试指令序列
	var instructions = []
	
	# 指令 1: 条件检查
	var condition_check = RunConditionCheck.new()
	condition_check.condition = check_variable
	condition_check.on_condition_true = RunConditionCheck.ConditionBehavior.CONTINUE
	condition_check.on_condition_false = RunConditionCheck.ConditionBehavior.STOP_EXECUTION
	instructions.append(condition_check)
	
	# 指令 2: 应该被停止
	var instruction2 = TestInstruction.new("指令2 (应该被停止)")
	instructions.append(instruction2)
	
	# 指令 3: 应该被停止
	var instruction3 = TestInstruction.new("指令3 (应该被停止)")
	instructions.append(instruction3)
	
	# 设置指令到 ActionRunner
	for instruction in instructions:
		action_runner.add_instruction(instruction)
	
	# 运行测试
	var result = await _run_action_runner_test()
	
	print("条件为假停止执行测试: %s (期望: 通过)" % ("通过" if result else "失败"))
	assert(result, "条件为假停止执行测试失败")

func _test_validation():
	print("\n--- 测试 5: 验证功能 ---")
	
	# 测试空条件验证
	var condition_check = RunConditionCheck.new()
	var errors = condition_check.validate()
	print("空条件验证: %d 个错误 (期望: >0)" % errors.size())
	assert(errors.size() > 0, "空条件验证失败")
	
	# 测试有效配置
	condition_check.condition = check_variable
	condition_check.on_condition_true = RunConditionCheck.ConditionBehavior.CONTINUE
	condition_check.on_condition_false = RunConditionCheck.ConditionBehavior.SKIP_NEXT
	condition_check.skip_count = 1
	
	errors = condition_check.validate()
	print("有效配置验证: %d 个错误 (期望: 0)" % errors.size())
	assert(errors.size() == 0, "有效配置验证失败")
	
	# 测试无效跳过数量
	condition_check.skip_count = -1
	errors = condition_check.validate()
	print("无效跳过数量验证: %d 个错误 (期望: >0)" % errors.size())
	assert(errors.size() > 0, "无效跳过数量验证失败")

## 运行 ActionRunner 测试
func _run_action_runner_test() -> bool:
	# 重置执行上下文状态
	execution_context.reset_execution_state()
	
	# 运行 ActionRunner
	action_runner.run(execution_context)
	
	# 等待执行完成
	await action_runner.execution_completed
	
	# 检查执行结果
	var success = not action_runner.has_fuse_error()
	
	# 输出执行状态
	var status = action_runner.get_execution_status()
	print("执行状态: %s" % status)
	
	return success

## 测试指令类
class TestInstruction extends BaseInstruction:
	var instruction_name: String
	var executed: bool = false
	
	func _init(name: String):
		instruction_name = name
	
	func _setup_metadata():
		metadata.name = instruction_name
		metadata.category = "测试"
		metadata.description = "测试指令"
	
	func _update_resource_name():
		resource_name = instruction_name
	
	func execute(context: ExecutionContext):
		_start_execution(context)
		executed = true
		context.print_message("执行了: %s" % instruction_name)
		_on_execution_completed()
	
	func get_description() -> String:
		return instruction_name
	
	func reset():
		super.reset()
		executed = false
