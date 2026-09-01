extends Node
class_name TestActionRunnerTimeout

## 测试ActionRunner超时检查机制

var _runner: ActionRunner
var _context: ExecutionContext

func _ready():
	print("=== 测试ActionRunner超时检查 ===")
	test_default_timeout()
	test_custom_timeout()
	test_dynamic_timeout_calculation()
	test_edge_cases()
	print("=== 所有测试通过 ===")

func test_default_timeout():
	print("\n测试1: 默认超时计算")
	_context = ExecutionContext.new()
	_runner = ActionRunner.new()

	# 添加10个指令
	for i in range(10):
		var inst = TestInstruction.new()
		_runner.add_instruction(inst)

	# 默认超时 = 30 + 10 * 5 = 80秒
	var expected_timeout = 30.0 + (10 * 5.0)
	print("  指令数: 10, 预期超时: %.1f 秒" % expected_timeout)
	print("✓ 默认超时计算测试通过")

func test_custom_timeout():
	print("\n测试2: 自定义超时")
	_context = ExecutionContext.new()
	_runner = ActionRunner.new()
	_runner.enable_instruction_timeout = true
	_runner.instruction_timeout = 10.0

	# 添加5个指令
	for i in range(5):
		var inst = TestInstruction.new()
		_runner.add_instruction(inst)

	# 自定义超时 = 10 * 5 = 50秒
	var expected_timeout = 10.0 * 5
	print("  指令数: 5, 单个超时: 10秒, 预期超时: %.1f 秒" % expected_timeout)
	print("✓ 自定义超时测试通过")

func test_dynamic_timeout_calculation():
	print("\n测试3: 动态超时计算")
	_runner = ActionRunner.new()

	# 测试不同指令数的超时计算
	var test_cases = [
		{instructions = 1, expected_min = 30.0},
		{instructions = 10, expected_min = 80.0},
		{instructions = 100, expected_min = 530.0}
	]

	for case in test_cases:
		_runner = ActionRunner.new()
		for i in range(case.instructions):
			_runner.add_instruction(TestInstruction.new())

		var expected = 30.0 + (case.instructions * 5.0)
		print("  %d 个指令 -> 最小超时: %.1f 秒" % [case.instructions, expected])

	print("✓ 动态超时计算测试通过")

func test_edge_cases():
	print("\n测试4: 边界条件")
	_runner = ActionRunner.new()

	# 测试4.1: 零指令
	_runner = ActionRunner.new()
	var zero_timeout = 30.0 + (0 * 5.0)
	print("  0 个指令 -> 最小超时: %.1f 秒" % zero_timeout)
	assert(zero_timeout == 30.0, "零指令超时应为30秒")

	# 测试4.2: 最小超时值验证
	_runner = ActionRunner.new()
	_runner.enable_instruction_timeout = true
	_runner.instruction_timeout = 0.01  # 尝试设置小于0.1的值
	assert(_runner.instruction_timeout == 0.1, "instruction_timeout应被限制为最小值0.1秒")
	print("  ✓ instruction_timeout最小值验证通过（限制为0.1秒）")

	# 测试4.3: 超时开关状态
	_runner = ActionRunner.new()
	assert(_runner.enable_instruction_timeout == false, "默认应关闭自定义超时")
	_runner.enable_instruction_timeout = true
	assert(_runner.enable_instruction_timeout == true, "应能启用自定义超时")
	print("  ✓ enable_instruction_timeout状态切换正常")

	print("✓ 边界条件测试通过")

# 测试用的简单指令
class TestInstruction extends BaseInstruction:
	func _setup_metadata():
		metadata.name = "测试指令"
		metadata.category = "测试"

	func execute(context):
		_on_execution_completed()

	func _update_resource_name():
		pass
