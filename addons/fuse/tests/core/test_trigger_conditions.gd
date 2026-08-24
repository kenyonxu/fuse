# 测试：Trigger 条件支持（use_conditions 门控、条件拦截/放行、trigger_once 消耗时机）
extends Node

var _fail: int = 0

class RecordingInstruction:
	extends BaseInstruction

	var records: Array

	func _init(records: Array) -> void:
		self.records = records

	func _setup_metadata() -> void:
		pass

	func _update_resource_name() -> void:
		resource_name = "RecordingInstruction"

	func execute(context: ExecutionContext) -> void:
		_start_execution(context)
		records.append(1)
		_on_execution_completed()

	func get_description() -> String:
		return "记录执行次数的测试指令"

func _ready() -> void:
	print("=== Trigger 条件测试开始 ===")
	_test_conditions_empty()
	_test_condition_block_and_pass()
	_test_condition_failure_keeps_trigger_once()
	_test_disabled_condition_skipped()
	print("=== Trigger 条件测试完成（失败 %d 项）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("✓ " + message)
	else:
		_fail += 1
		push_error("✗ " + message)

## 组装一个可手动触发的 Trigger（事件仅占位，不真正监听）
func _build_trigger(records: Array) -> Trigger:
	var trigger := Trigger.new()

	var instructions: Array[BaseInstruction] = []
	instructions.append(RecordingInstruction.new(records))
	var ar := ActionRunner.new()
	ar.instructions = instructions
	trigger.action_runner = ar

	# 事件占位：满足 _on_trigger_ready 对 event_definition 的要求
	# （偏离 brief：target_signal 用 "renamed" 而非 "ready"——后者在 add_child 时会真实
	#  触发一次，违背"事件仅占位，不真正监听"的意图；renamed 仅在 rename() 时发射）
	var event := OnTargetSignalEmit.new()
	event.target_node = NodePath(".")
	event.target_signal = "renamed"
	trigger.event_definition = event

	return trigger

## 固定返回的探针条件
## （偏离 brief：CompareVariable 对 Object 与 int 直接 == 比较会抛 GDScript 运行时错误
##  "Invalid operands 'Object' and 'int'"，event_source 探针不可用，改用自定义条件）
class ProbeCondition:
	extends BaseCondition

	var passes: bool

	func _init(passes: bool) -> void:
		self.passes = passes

	func _update_resource_name() -> void:
		resource_name = "ProbeCondition"

	func _evaluate_condition(context: ExecutionContext) -> bool:
		return passes

	func _compute_dependencies() -> Array[String]:
		return []

func _make_cond(passes: bool) -> BaseCondition:
	return ProbeCondition.new(passes)

func _test_conditions_empty() -> void:
	var records: Array = []
	var trigger := _build_trigger(records)
	add_child(trigger)
	trigger.trigger_manually(self)
	_check(records.size() == 1, "conditions 为空时应无条件执行")
	trigger.queue_free()

func _test_condition_block_and_pass() -> void:
	var records: Array = []
	var trigger := _build_trigger(records)
	trigger.conditions = [_make_cond(false)]
	add_child(trigger)
	trigger.trigger_manually(self)
	_check(records.is_empty(), "条件失败时应拦截执行")

	trigger.conditions = [_make_cond(true)]
	trigger.trigger_manually(self)
	_check(records.size() == 1, "条件通过时应执行")
	trigger.queue_free()

func _test_condition_failure_keeps_trigger_once() -> void:
	var records: Array = []
	var trigger := _build_trigger(records)
	trigger.trigger_once = true
	trigger.conditions = [_make_cond(false)]
	add_child(trigger)
	trigger.trigger_manually(self)
	_check(records.is_empty(), "trigger_once + 条件失败：不执行")

	# 关键语义：条件失败不应消耗唯一一次触发机会
	trigger.conditions = [_make_cond(true)]
	trigger.trigger_manually(self)
	_check(records.size() == 1, "trigger_once 未被条件失败消耗，条件通过后仍可执行")

	# 消耗之后再次触发应被 trigger_once 拦截
	trigger.trigger_manually(self)
	_check(records.size() == 1, "成功执行后 trigger_once 应拦截后续触发")
	trigger.queue_free()

func _test_disabled_condition_skipped() -> void:
	var records: Array = []
	var trigger := _build_trigger(records)
	var cond := _make_cond(false)
	cond.enabled = false
	trigger.conditions = [cond]
	add_child(trigger)
	trigger.trigger_manually(self)
	_check(records.size() == 1, "enabled=false 的条件应被跳过（视为通过）")
	trigger.queue_free()
