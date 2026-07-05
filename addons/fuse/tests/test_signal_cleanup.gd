extends Node

## 测试 ActionRunner 信号清理功能 - 验证 Callable 缓存修复

func _ready():
	test_signal_cleanup()

func test_signal_cleanup():
	print("=== 测试 ActionRunner 信号清理（Callable 缓存修复） ===")

	# 创建测试用的简单指令
	var instruction = SimpleTestInstruction.new()
	var runner = ActionRunner.new()
	runner.instructions.append(instruction)

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 执行指令
	runner.run(context)
	await runner.execution_completed

	# 验证信号连接已清理
	var connections = instruction.finished.get_connections()
	print("最终信号连接数: %d" % connections.size())

	if connections.size() == 0:
		print("✓ 信号清理测试通过")
	else:
		push_error("✗ 信号清理测试失败：预期 0 个连接，实际 %d 个连接" % connections.size())

	# 清理
	context.cleanup()
	runner.clear_instructions()

	print("=== 测试完成 ===")

## 简单的测试指令
class SimpleTestInstruction extends BaseInstruction:
	func execute(context: ExecutionContext):
		_on_execution_completed()

	func get_description() -> String:
		return "Test Instruction"
	
	func _update_resource_name():
		pass

	func _setup_metadata():
		pass