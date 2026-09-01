# 测试：指令错误路径同步 runtime_instance._has_error（stop_on_error 经 RARI 生效）
#
# 验证 execute_with_runtime_instance 的错误终止路径（超时/无效参数等）将
# 指令错误状态同步到 RuntimeInstructionInstance（_has_error/_error_message），
# 使 RARI 层 has_error() 检测成立 → stop_on_error 触发：
# - execution_failed 信号发出
# - 后续指令不再执行
# - is_running 复位
extends Node

var _fail: int = 0

# lambda 经 self 捕获类成员（GDScript lambda 按值捕获局部变量，String 局部量不可用）
var _rari_failed_msg: String = ""

func _ready() -> void:
	print("=== 错误状态同步测试开始 ===")
	# 注意：测试函数含 await（协程），必须 await 逐个执行，
	# 否则 _ready 会立即打印结束并 quit，断言永远不执行
	await _test_wait_until_timeout_stop_on_error()
	await _test_wait_invalid_time_stop_on_error()
	print("=== 错误状态同步测试完成（失败 %d 项）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("✓ " + message)
	else:
		_fail += 1
		push_error("✗ " + message)

## 等待 execution_failed（真实时间兜底，headless 全速帧下固定帧数不可靠）
func _wait_for_failure(timeout_ms: int) -> void:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while _rari_failed_msg.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

## 同步成功探针：若被执行则 records 非空（stop_on_error 失效的证据）
class SyncProbe:
	extends BaseInstruction
	var records: Array
	func _init(records: Array) -> void:
		self.records = records
	func _setup_metadata() -> void:
		pass
	func _update_resource_name() -> void:
		resource_name = "SyncProbe"
	func execute(context: ExecutionContext) -> void:
		_start_execution(context)
		records.append(1)
		_on_execution_completed()
	func get_description() -> String:
		return "同步探针指令"

## wait_until 超时（异步失败路径）：stop_on_error 生效且 execution_failed 发出
func _test_wait_until_timeout_stop_on_error() -> void:
	print("\n--- wait_until 超时 stop_on_error ---")
	_rari_failed_msg = ""
	var trigger := Node.new()
	trigger.name = "WuTrigger"
	add_child(trigger)

	var wu := WaitUntil.new()
	wu.condition_type = WaitUntil.ConditionType.VARIABLE_COMPARISON
	wu.variable_a = "no_such_var_xyz"
	wu.comparison_operator = 0  # 等于
	wu.value_b = 12345
	wu.check_interval = 0.05
	wu.timeout = 0.15

	var records: Array = []
	var instructions: Array[BaseInstruction] = []
	instructions.append(wu)
	instructions.append(SyncProbe.new(records))
	var ar := ActionRunner.new()
	ar.instructions = instructions
	ar.stop_on_error = true

	var rari := RuntimeActionRunnerInstance.new(ar, trigger)
	rari.execution_failed.connect(func(e): _rari_failed_msg = e)

	var context := ExecutionContext.new(trigger, trigger)
	rari.run(context)
	await _wait_for_failure(2000)
	_check(not _rari_failed_msg.is_empty(), "超时经 RARI 发出 execution_failed")
	_check(records.is_empty(), "stop_on_error 生效：后续指令未执行（records=%d）" % records.size())
	_check(not rari.is_running(), "失败后 is_running 复位")
	rari.cleanup()
	trigger.queue_free()

## wait 无效时长（同步失败路径）：同样生效
func _test_wait_invalid_time_stop_on_error() -> void:
	print("\n--- wait 无效时长 stop_on_error ---")
	_rari_failed_msg = ""
	var trigger := Node.new()
	trigger.name = "WTrigger"
	add_child(trigger)

	var w := Wait.new()
	w.wait_time = -1.0

	var records: Array = []
	var instructions: Array[BaseInstruction] = []
	instructions.append(w)
	instructions.append(SyncProbe.new(records))
	var ar := ActionRunner.new()
	ar.instructions = instructions
	ar.stop_on_error = true

	var rari := RuntimeActionRunnerInstance.new(ar, trigger)
	rari.execution_failed.connect(func(e): _rari_failed_msg = e)

	var context := ExecutionContext.new(trigger, trigger)
	rari.run(context)
	await _wait_for_failure(2000)
	_check(not _rari_failed_msg.is_empty(), "无效时长经 RARI 发出 execution_failed")
	_check(records.is_empty(), "stop_on_error 生效：后续指令未执行（records=%d）" % records.size())
	_check(not rari.is_running(), "失败后 is_running 复位")
	rari.cleanup()
	trigger.queue_free()
