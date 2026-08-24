# 测试：filter_signal_args 启用但 signal_info 不可用时应放行（fail-open）
extends Node

var _fail: int = 0
var _triggered_count: int = 0

class SignalEmitter:
	extends Node
	signal custom_signal(value: int)

func _ready() -> void:
	print("=== 参数过滤 fail-open 测试开始 ===")
	_test_failopen()
	print("=== 参数过滤 fail-open 测试完成（失败 %d 项）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("✓ " + message)
	else:
		_fail += 1
		push_error("✗ " + message)

func _test_failopen() -> void:
	var emitter := SignalEmitter.new()
	emitter.name = "Emitter"
	add_child(emitter)

	var event := OnTargetSignalEmit.new()
	event.target_node = NodePath("Emitter")
	event.target_signal = "custom_signal"
	event.filter_signal_args = true
	event.arg_filter_values = [7]
	event.triggered.connect(_on_triggered)

	# 走旧初始化 API（内部自建 RuntimeEventInstance 并 connect）
	event.initialize(self)

	# 人为清空 signal_info，模拟运行时状态异常
	if event._runtime_instance_ref:
		event._runtime_instance_ref.set_runtime_state("signal_info", null)

	# 修复前：signal_info 缺失 → 全部触发被静默丢弃
	emitter.emit_signal("custom_signal", 7)
	_check(_triggered_count == 1, "signal_info 缺失时应放行触发（fail-open）")

	# 正常过滤路径不受影响：signal_info 缺失仍放行后，参数不匹配的场景
	# 由 signal_info 存在时的逐位比较覆盖（Task 1 测试已覆盖 named_args 路径，
	# 这里补一个参数不匹配仍拦截的对照，需要 signal_info）
	if event._runtime_instance_ref:
		var infos = SignalManager.get_node_signals(emitter)
		for info in infos:
			if info.name == "custom_signal":
				event._runtime_instance_ref.set_runtime_state("signal_info", info)
				break
	_triggered_count = 0
	emitter.emit_signal("custom_signal", 99)
	_check(_triggered_count == 0, "signal_info 存在且参数不匹配时应拦截")

	emitter.emit_signal("custom_signal", 7)
	_check(_triggered_count == 1, "signal_info 存在且参数匹配时应触发")

func _on_triggered(_node: Node) -> void:
	_triggered_count += 1
