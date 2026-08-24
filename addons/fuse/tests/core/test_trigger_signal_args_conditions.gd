# 测试：Trigger 侧信号参数条件端到端（OnTargetSignalEmit 参数桥接 + Trigger._sync_additional_event_args + conditions）
# 同时回归：无参信号照常触发、last_event_args 为空字典（spec 边界情况 M1 项）
extends Node

var _fail: int = 0

## 信号发射器：custom_signal 带参（value / label 出现在 SignalInfo 元数据中）；ping 无参（回归项）
class SignalEmitter:
	extends Node
	signal custom_signal(value: int, label: String)
	signal ping()

## 记录型测试指令：执行时把 event_* 变量值记录下来
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
		records.append({
			"event_value": context.get_variable("event_value"),
			"event_label": context.get_variable("event_label"),
		})
		_on_execution_completed()

	func get_description() -> String:
		return "记录信号参数的测试指令"

func _ready() -> void:
	print("=== Trigger 信号参数条件测试开始 ===")
	_test_trigger_signal_args_with_conditions()
	_test_no_args_signal_regression()
	print("=== Trigger 信号参数条件测试完成（失败 %d 项）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("✓ " + message)
	else:
		_fail += 1
		push_error("✗ " + message)

## I2：Trigger（非 MultiEventTrigger）宿主下 信号参数 → event_* 局部变量 → 条件 → 指令 端到端
func _test_trigger_signal_args_with_conditions() -> void:
	# 布局：Trigger 子挂 emitter（NodePath("Emitter") 相对 Trigger 可解析）
	var trigger := Trigger.new()
	trigger.name = "TestTrigger"

	var emitter := SignalEmitter.new()
	emitter.name = "Emitter"
	trigger.add_child(emitter)

	var records: Array = []
	var instructions: Array[BaseInstruction] = []
	instructions.append(RecordingInstruction.new(records))
	var ar := ActionRunner.new()
	ar.instructions = instructions

	# 真实条件探针：CompareVariable[event_value EQUAL 42]（scope_source 保持默认 NEAREST——
	# 裸场景无 ScopeVariableContainer，读链回退 local，可读到 event_*）
	var cond := CompareVariable.new()
	cond.variable_name = "event_value"
	cond.comparison_operator = CompareVariable.ComparisonOperator.EQUAL
	cond.compare_value = 42

	var event := OnTargetSignalEmit.new()
	event.target_node = NodePath("Emitter")
	event.target_signal = "custom_signal"

	trigger.event_definition = event
	trigger.action_runner = ar
	trigger.conditions = [cond]

	add_child(trigger)  # 触发 _ready：初始化运行时实例并连接信号

	# 触发 1：参数匹配（value=42）→ 条件通过 → action 执行（Trigger 的 _sync_additional_event_args 链路）
	emitter.emit_signal("custom_signal", 42, "hello")
	_check(records.size() == 1, "Trigger：参数匹配时 action 应执行（event_value 同步为 42）")
	if records.size() >= 1:
		_check(records[0]["event_value"] == 42, "Trigger：指令内 event_value 应为 42")
		_check(records[0]["event_label"] == "hello", "Trigger：指令内 event_label 应为 'hello'")

	# 触发 2：参数不匹配（value=99）→ 条件拦截 → action 不执行
	records.clear()
	emitter.emit_signal("custom_signal", 99, "world")
	_check(records.is_empty(), "Trigger：参数不匹配时 action 应被条件拦截")

	# add_child(trigger) 后 signal_info 应已构建
	var inst := trigger.get_runtime_event_instance_at(0)
	_check(inst != null and inst.runtime_state.get("signal_info", null) != null,
		"Trigger：运行时应构建 signal_info")

## M1：无参信号回归——行为与改动前一致（照常触发、last_event_args 为空字典、无 event_* 变量）
func _test_no_args_signal_regression() -> void:
	var trigger := Trigger.new()
	trigger.name = "TestTriggerNoArgs"

	var emitter := SignalEmitter.new()
	emitter.name = "Emitter2"
	trigger.add_child(emitter)

	var records: Array = []
	var instructions: Array[BaseInstruction] = []
	instructions.append(RecordingInstruction.new(records))
	var ar := ActionRunner.new()
	ar.instructions = instructions

	var event := OnTargetSignalEmit.new()
	event.target_node = NodePath("Emitter2")
	event.target_signal = "ping"

	trigger.event_definition = event
	trigger.action_runner = ar
	# conditions 为空 → 无条件照常执行

	add_child(trigger)

	# 无参信号 → action 照常执行
	emitter.emit_signal("ping")
	_check(records.size() == 1, "无参信号：action 应照常执行（行为与改动前一致）")
	if records.size() >= 1:
		_check(records[0]["event_value"] == null, "无参信号：指令内不应产生 event_value 变量")

	var inst := trigger.get_runtime_event_instance_at(0)
	_check(inst != null and inst.runtime_state.get("last_event_args", {}) == {},
		"无参信号：last_event_args 应为空字典（同步零次、无 event_* 变量产生）")
