# 测试：execute_sync 终态判定——同步失败/取消指令返回 true，错误状态不被抹
#
# 缺陷机理：旧 execute_sync 的 lambda 按值捕获 completed_sync（赋值死代码），
# 实际检测只认 COMPLETED——同步失败（set_error + finished.emit）被误判为
# 异步返回 false，且 1174 行把 execution_status 恢复为执行前状态，has_error
# 被抹。修复后终态（COMPLETED/ERROR/CANCELLED）即返回 true，错误传播交给
# 调用方（遗留 action_runner.gd:279-287 / RARI 365-372 区域）既有 has_error 检查。
extends Node

var _fail: int = 0

# lambda 经 self 捕获类成员（GDScript lambda 按值捕获局部变量，局部计数不生效
# ——与被修缺陷同源的捕获语义，参照 test_error_state_sync 的成熟模式）
var _legacy_failed_count: int = 0
var _legacy_completed_count: int = 0
var _rari_failed_msg: String = ""

## 同步失败探针：execute 内同步 set_error + finished.emit（wait-instructions 轮被迫异步化的原始形态回归正身）
class SyncFailProbe:
	extends BaseInstruction
	func _setup_metadata() -> void:
		pass
	func _update_resource_name() -> void:
		resource_name = "SyncFailProbe"
	func execute(context: ExecutionContext) -> void:
		_start_execution(context)
		set_error("同步失败探针", FuseError.ErrorType.RUNTIME_ERROR)
		finished.emit()
	func get_description() -> String:
		return "同步失败探针"

## 同步成功探针：execute 内 _on_execution_completed 到达 COMPLETED 终态
class SyncOkProbe:
	extends BaseInstruction
	var records: Array
	func _init(records: Array = []) -> void:
		self.records = records
	func _setup_metadata() -> void:
		pass
	func _update_resource_name() -> void:
		resource_name = "SyncOkProbe"
	func execute(context: ExecutionContext) -> void:
		_start_execution(context)
		records.append(1)
		_on_execution_completed()
	func get_description() -> String:
		return "同步成功探针"

## 同步自取消探针：execute 内调用自身 cancel()（RUNNING → CANCELLED + finished.emit）
class SyncCancelProbe:
	extends BaseInstruction
	func _setup_metadata() -> void:
		pass
	func _update_resource_name() -> void:
		resource_name = "SyncCancelProbe"
	func execute(context: ExecutionContext) -> void:
		_start_execution(context)
		cancel()
	func get_description() -> String:
		return "同步自取消探针"

func _ready() -> void:
	print("=== execute_sync 终态判定测试开始 ===")
	# 注意：测试函数含 await（协程），必须逐个 await，否则 _ready 立即 quit 断言不执行
	await _test_sync_failure_returns_true()
	await _test_sync_cancel_returns_true()
	await _test_legacy_sync_failure_branch()
	await _test_rari_sync_failure_branch()
	await _test_sync_success_unchanged()
	print("=== execute_sync 终态判定测试完成（失败 %d 项）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("✓ " + message)
	else:
		_fail += 1
		push_error("✗ " + message)

## 直接层：同步失败指令 execute_sync 返回 true 且 has_error 保持
func _test_sync_failure_returns_true() -> void:
	print("\n--- 同步失败返回 true ---")
	var probe := SyncFailProbe.new()
	var context := ExecutionContext.new(self, null)
	var result := probe.execute_sync(context)
	_check(result == true, "同步失败指令 execute_sync 返回 true（被当异步是缺陷）")
	_check(probe.has_error(), "同步失败后 has_error 保持（不被状态恢复抹掉）")

## 直接层：同步自取消指令 execute_sync 返回 true 且状态为 CANCELLED
func _test_sync_cancel_returns_true() -> void:
	print("\n--- 同步自取消返回 true ---")
	var probe := SyncCancelProbe.new()
	var context := ExecutionContext.new(self, null)
	var result := probe.execute_sync(context)
	_check(result == true, "同步自取消指令 execute_sync 返回 true（CANCELLED 终态）")
	_check(probe.execution_status == BaseInstruction.ExecutionStatus.CANCELLED, "取消后状态 CANCELLED")

## 遗留层：同步失败分支（action_runner.gd:279-287）可达且恰一次 execution_failed
func _test_legacy_sync_failure_branch() -> void:
	print("\n--- 遗留同步失败分支 ---")
	_legacy_failed_count = 0
	_legacy_completed_count = 0
	var ar := ActionRunner.new()
	ar.stop_on_error = true
	var instructions: Array[BaseInstruction] = []
	instructions.append(SyncFailProbe.new())
	var records: Array = []
	instructions.append(SyncOkProbe.new(records))
	ar.instructions = instructions

	ar.execution_failed.connect(func(_e): _legacy_failed_count += 1)
	ar.execution_completed.connect(func(): _legacy_completed_count += 1)

	var context := ExecutionContext.new(self, null)
	ar.run(context)
	await get_tree().process_frame
	_check(_legacy_failed_count == 1, "遗留同步失败 execution_failed 恰一次（实际 %d）" % _legacy_failed_count)
	_check(_legacy_completed_count == 0, "失败后不发 completed")
	_check(records.is_empty(), "stop_on_error 拦截后续指令")

## RARI 层：同步失败分支（365/372 区域）可达
func _test_rari_sync_failure_branch() -> void:
	print("\n--- RARI 同步失败分支 ---")
	_rari_failed_msg = ""
	var trigger := Node.new()
	trigger.name = "SyncFailTrigger"
	add_child(trigger)

	var ar := ActionRunner.new()
	ar.stop_on_error = true
	var instructions: Array[BaseInstruction] = []
	instructions.append(SyncFailProbe.new())
	var records: Array = []
	instructions.append(SyncOkProbe.new(records))
	ar.instructions = instructions

	var rari := RuntimeActionRunnerInstance.new(ar, trigger)
	rari.execution_failed.connect(func(e): _rari_failed_msg = e)

	var context := ExecutionContext.new(trigger, trigger)
	rari.run(context)
	await get_tree().process_frame
	_check(not _rari_failed_msg.is_empty(), "RARI 同步失败发出 execution_failed")
	_check(records.is_empty(), "stop_on_error 拦截后续指令")
	_check(not rari.is_running(), "失败后 is_running 复位")
	rari.cleanup()
	trigger.queue_free()

## 回归：同步成功路径行为不变
func _test_sync_success_unchanged() -> void:
	print("\n--- 同步成功回归 ---")
	var probe := SyncOkProbe.new()
	var context := ExecutionContext.new(self, null)
	var result := probe.execute_sync(context)
	_check(result == true, "同步成功指令 execute_sync 返回 true")
	_check(probe.execution_status == BaseInstruction.ExecutionStatus.COMPLETED, "成功后状态 COMPLETED")
