# 测试：参数过滤统一升级——matches_arg 类型安全 / OnTargetSignalEmit dict 过滤
extends Node

var _fail: int = 0
var _triggered_count: int = 0

## 4 参异构模拟信号（body_shape_entered 同构）
class MultiArgEmitter:
	extends Node
	signal shape_entered(body_id: int, body: Node, body_shape: int, local_shape: int)

## 带参动画式信号
class AnimEmitter:
	extends Node
	signal animation_finished(anim_name: String)

func _ready() -> void:
	print("=== 参数过滤升级测试开始 ===")
	_test_matches_arg_unit()
	await _test_otsa_dict_partial_filter()
	await _test_otsa_gate_off_regression()
	await _test_wait_for_signal_filter()
	print("=== 参数过滤升级测试完成（失败 %d 项）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("✓ " + message)
	else:
		_fail += 1
		push_error("✗ " + message)

## matches_arg 单元：类型安全各分支
func _test_matches_arg_unit() -> void:
	print("\n--- matches_arg 单元 ---")
	_check(SignalInfo.matches_arg("attack", "attack"), "同型相等")
	_check(not SignalInfo.matches_arg("attack", "idle"), "同型不等")
	_check(SignalInfo.matches_arg(1, 1.0), "数值互转（int/float）")
	_check(SignalInfo.matches_arg("x", StringName("x")), "String/StringName 兼容")
	_check(not SignalInfo.matches_arg(self, 1), "Object vs 非 Object → false 不抛错")
	var n := Node.new()
	_check(SignalInfo.matches_arg(n, n), "同 Object 引用相等")
	_check(not SignalInfo.matches_arg(n, self), "不同 Object 引用不等")
	_check(not SignalInfo.matches_arg("1", 1), "跨类型族 → false")
	_check(SignalInfo.matches_arg(null, null), "null == null")
	_check(not SignalInfo.matches_arg(null, 1), "null vs 非 null → false")
	n.queue_free()

## OnTargetSignalEmit：4 参信号 dict 只过滤 1 键（按名部分过滤）
func _test_otsa_dict_partial_filter() -> void:
	print("\n--- OnTargetSignalEmit dict 部分过滤 ---")
	_triggered_count = 0
	var emitter := MultiArgEmitter.new()
	emitter.name = "Emitter"
	add_child(emitter)

	var ev := OnTargetSignalEmit.new()
	ev.target_node = NodePath("../Emitter")  # 事件在测试根下解析（资源上下文/相对由实现裁决）
	ev.target_signal = "shape_entered"
	ev.filter_signal_args = true
	ev.arg_filter_values = {"body_shape": 3}  # 只过滤 body_shape，其余 3 参忽略
	ev.triggered.connect(func(_n): _triggered_count += 1)
	ev.initialize(self)

	# body_shape=5 → 不匹配丢弃
	emitter.emit_signal("shape_entered", 1, self, 5, 0)
	_check(_triggered_count == 0, "body_shape=5 被过滤")
	# body_shape=3 → 匹配触发
	emitter.emit_signal("shape_entered", 9, self, 3, 7)
	_check(_triggered_count == 1, "body_shape=3 匹配触发（其余参数忽略）")
	# dict 键名不存在于信号参数 → 不匹配
	ev.arg_filter_values = {"no_such_param": 1}
	emitter.emit_signal("shape_entered", 1, self, 3, 0)
	_check(_triggered_count == 1, "未知参数名不匹配")
	ev.terminate(self)

## OnTargetSignalEmit：门控关闭行为回归（存量形态）
func _test_otsa_gate_off_regression() -> void:
	print("\n--- 门控关闭回归 ---")
	_triggered_count = 0
	var emitter := AnimEmitter.new()
	emitter.name = "AnimEmitter"
	add_child(emitter)

	var ev := OnTargetSignalEmit.new()
	ev.target_node = NodePath("../AnimEmitter")
	ev.target_signal = "animation_finished"
	ev.filter_signal_args = false  # 存量场景形态：不启用过滤
	ev.triggered.connect(func(_n): _triggered_count += 1)
	ev.initialize(self)

	emitter.emit_signal("animation_finished", "whatever")
	_check(_triggered_count == 1, "门控关闭：任意参数触发（存量行为）")
	ev.terminate(self)

## WaitForSignal 过滤（Task 2 填充；占位不算断言）
func _test_wait_for_signal_filter() -> void:
	print("\n--- WaitForSignal 过滤（Task 2 填充）---")
	print("（占位：Task 2 实现后替换）")
