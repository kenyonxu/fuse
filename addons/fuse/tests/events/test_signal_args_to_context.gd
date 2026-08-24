# 测试：OnTargetSignalEmit 信号参数桥接到 ExecutionContext
# 验证链路：信号 args → last_event_args → event_<参数名> 局部变量 → CompareVariable 条件可验证
extends Node

var _fail: int = 0

## 带参信号发射器（参数名 value / label 会在 SignalInfo 元数据中出现）
class SignalEmitter:
	extends Node
	signal custom_signal(value: int, label: String)

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
	print("=== 信号参数桥接测试开始 ===")
	_test_args_bridge()
	print("=== 信号参数桥接测试完成（失败 %d 项）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("✓ " + message)
	else:
		_fail += 1
		push_error("✗ " + message)

func _test_args_bridge() -> void:
	# 布局：MultiEventTrigger 子挂 emitter（NodePath("Emitter") 相对 Trigger 必然可解析）
	var multi := MultiEventTrigger.new()
	multi.name = "TestMulti"

	var emitter := SignalEmitter.new()
	emitter.name = "Emitter"
	multi.add_child(emitter)

	var records: Array = []
	var instructions: Array[BaseInstruction] = []
	instructions.append(RecordingInstruction.new(records))
	var ar := ActionRunner.new()
	ar.instructions = instructions

	# 条件探针：参数正确同步为 event_* 时条件才通过，action 才执行
	var cond := CompareVariable.new()
	cond.variable_name = "event_value"
	cond.comparison_operator = CompareVariable.ComparisonOperator.EQUAL
	cond.compare_value = 42

	var event := OnTargetSignalEmit.new()
	event.target_node = NodePath("Emitter")
	event.target_signal = "custom_signal"

	var binding := EventBinding.new()
	binding.event = event
	binding.action_runner = ar
	binding.conditions = [cond]

	multi.event_bindings = [binding]
	add_child(multi)  # 触发 _ready：初始化运行时实例并连接信号

	# 触发 1：参数匹配（value=42）→ 条件通过 → action 执行
	emitter.emit_signal("custom_signal", 42, "hello")
	_check(records.size() == 1, "参数匹配时 action 应执行（event_value 同步为 42）")
	if records.size() >= 1:
		_check(records[0]["event_value"] == 42, "指令内 event_value 应为 42")
		_check(records[0]["event_label"] == "hello", "指令内 event_label 应为 'hello'")

	# 触发 2：参数不匹配（value=99）→ 条件拦截 → action 不执行
	records.clear()
	emitter.emit_signal("custom_signal", 99, "world")
	_check(records.is_empty(), "参数不匹配时 action 应被条件拦截")

	# 直接断言 runtime_state：signal_info 已构建、last_event_args 已写入最近一次参数
	var inst := multi.get_runtime_event_instance_at(0)
	_check(inst != null and inst.runtime_state.get("signal_info", null) != null,
		"运行时应构建 signal_info")
	if inst:
		_check(inst.runtime_state.get("last_event_args", {}) == {"value": 99, "label": "world"},
			"last_event_args 应为最近一次信号参数字典")
