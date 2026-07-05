# 文件：addons/fuse/tests/runner/test_runner.gd
extends Node

## Runner 测试用例
##
## 测试 Runner 节点的核心功能：
## - 创建和初始化
## - 执行 ActionRunner
## - 取消执行
## - 重置状态
## - 信号绑定

var _runner: Runner = null
var _action_runner: ActionRunner = null
var _execution_completed_count: int = 0
var _execution_failed_count: int = 0
var _execution_canceled_count: int = 0
var _last_completed_time: float = 0.0

func _ready() -> void:
	print("=== Runner 测试开始 ===")
	_run_all_tests()
	print("=== Runner 测试完成 ===")

func _run_all_tests() -> void:
	test_runner_creation()
	await get_tree().process_frame

	test_runner_run_without_action_runner()
	await get_tree().process_frame

	await test_runner_run_with_action_runner()
	await get_tree().process_frame

	await test_runner_cancel()
	await get_tree().process_frame

	test_runner_reset()
	await get_tree().process_frame

	await test_runner_signal_binding()
	await get_tree().process_frame

	test_runner_is_running()
	await get_tree().process_frame

func _setup() -> void:
	_execution_completed_count = 0
	_execution_failed_count = 0
	_execution_canceled_count = 0
	_last_completed_time = 0.0

	# 创建 Runner
	_runner = Runner.new()
	_runner.name = "TestRunner"
	_runner.log_level = FuseLogger.LogLevel.DEBUG
	add_child(_runner)

	# 连接信号
	_runner.execution_completed.connect(_on_execution_completed)
	_runner.execution_failed.connect(_on_execution_failed)
	_runner.execution_canceled.connect(_on_execution_canceled)

func _teardown() -> void:
	if _runner:
		_runner.queue_free()
		_runner = null
	if _action_runner:
		_action_runner = null

func _on_execution_completed(total_time: float) -> void:
	_execution_completed_count += 1
	_last_completed_time = total_time
	print("  [信号] execution_completed: %.3fs" % total_time)

func _on_execution_failed(error_message: String) -> void:
	_execution_failed_count += 1
	print("  [信号] execution_failed: %s" % error_message)

func _on_execution_canceled(reason: String) -> void:
	_execution_canceled_count += 1
	print("  [信号] execution_canceled: %s" % reason)

## ============================================
## 测试用例
## ============================================

func test_runner_creation() -> void:
	print("\n[测试] Runner 创建...")
	_setup()

	assert(_runner != null, "Runner 应该被创建")
	assert(_runner.is_running() == false, "Runner 初始状态应该不在运行")

	_teardown()
	print("  ✓ 通过")

func test_runner_run_without_action_runner() -> void:
	print("\n[测试] Runner 无 ActionRunner 时运行...")
	_setup()

	_runner.run()
	await get_tree().process_frame

	# 应该不会有执行完成信号
	assert(_execution_completed_count == 0, "无 ActionRunner 时不应该有完成信号")

	_teardown()
	print("  ✓ 通过")

func test_runner_run_with_action_runner() -> void:
	print("\n[测试] Runner 带 ActionRunner 运行...")
	_setup()

	# 创建 ActionRunner
	_action_runner = ActionRunner.new()
	var instruction = _create_mock_instruction("测试指令")
	_action_runner.instructions.append(instruction)

	_runner.action_runner = _action_runner

	# 手动触发 _ready 以初始化运行时实例
	_runner._ready()

	_runner.run()

	# 等待执行完成
	await _runner.wait_completed()

	assert(_execution_completed_count == 1, "应该有执行完成信号")
	assert(_runner.is_running() == false, "执行完成后不应该在运行")

	_teardown()
	print("  ✓ 通过")

func test_runner_cancel() -> void:
	print("\n[测试] Runner 取消...")
	_setup()

	# 创建 ActionRunner 并执行
	_action_runner = ActionRunner.new()
	var wait_instruction = Wait.new()
	wait_instruction.wait_time = 5.0
	_action_runner.instructions.append(wait_instruction)

	_runner.action_runner = _action_runner

	# 手动触发 _ready 以初始化运行时实例
	_runner._ready()

	_runner.run()

	await get_tree().process_frame
	assert(_runner.is_running() == true, "Runner 应该在运行")

	_runner.cancel("测试取消")

	await get_tree().process_frame
	assert(_execution_canceled_count == 1, "应该有取消信号")

	_teardown()
	print("  ✓ 通过")

func test_runner_reset() -> void:
	print("\n[测试] Runner 重置...")
	_setup()

	_action_runner = ActionRunner.new()
	_action_runner.instructions.append(_create_mock_instruction("重置测试"))
	_runner.action_runner = _action_runner

	# 手动触发 _ready 以初始化运行时实例
	_runner._ready()

	_runner.run()
	await get_tree().process_frame

	_runner.reset()

	assert(_runner.is_running() == false, "重置后不应该在运行")

	_teardown()
	print("  ✓ 通过")

func test_runner_signal_binding() -> void:
	print("\n[测试] Runner 信号绑定...")
	_setup()

	# 创建一个按钮节点
	var button = Button.new()
	button.name = "TestButton"
	add_child(button)

	# 创建 ActionRunner
	_action_runner = ActionRunner.new()
	_action_runner.instructions.append(_create_mock_instruction("按钮触发"))
	_runner.action_runner = _action_runner

	# 设置信号绑定
	_runner.target_node = button.get_path()
	_runner.signal_name = "pressed"

	# 手动触发 _ready 以初始化运行时实例和信号绑定
	_runner._ready()

	# 模拟按钮按下
	button.emit_signal("pressed")

	await get_tree().process_frame
	await get_tree().process_frame

	assert(_execution_completed_count == 1, "信号绑定应该触发执行")

	button.queue_free()
	_teardown()
	print("  ✓ 通过")

func test_runner_is_running() -> void:
	print("\n[测试] Runner is_running 状态...")
	_setup()

	assert(_runner.is_running() == false, "初始状态不在运行")

	_action_runner = ActionRunner.new()
	var wait_instruction = Wait.new()
	wait_instruction.wait_time = 0.1
	_action_runner.instructions.append(wait_instruction)
	_runner.action_runner = _action_runner

	# 手动触发 _ready 以初始化运行时实例
	_runner._ready()

	_runner.run()
	assert(_runner.is_running() == true, "执行中应该在运行")

	await _runner.wait_completed()
	assert(_runner.is_running() == false, "完成后不在运行")

	_teardown()
	print("  ✓ 通过")

## ============================================
## 辅助方法
## ============================================

func _create_mock_instruction(desc: String) -> BaseInstruction:
	# 由于 BaseInstruction 是抽象的，我们使用 Wait 作为替代
	var mock = Wait.new()
	mock.wait_time = 0.01
	return mock
