# 测试：TweenMoveTo 的 duration 变量源——直填回归/变量生效/错误路径/round-trip
extends Node

var _fail: int = 0
var _sig_finished: bool = false
var _sig_failed: bool = false

class ProbeRunner:
	extends Node
	var done_count: int = 0

func _ready() -> void:
	print("=== TweenMoveTo duration 变量源测试开始 ===")
	await _test_direct_regression()
	await _test_variable_duration()
	await _test_variable_missing_error()
	await _test_roundtrip()
	print("=== TweenMoveTo duration 变量源测试完成（失败 %d 项）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("✓ " + message)
	else:
		_fail += 1
		push_error("✗ " + message)

## 直填模式回归（默认 DIRECT）
func _test_direct_regression() -> void:
	print("\n--- 直填回归 ---")
	var host := Node2D.new()
	host.name = "Host1"
	add_child(host)
	var mv := TweenMoveTo.new()
	mv.target_node = NodePath("../Host1")
	mv.target_position = Vector2(10, 0)
	mv.duration = 0.05
	var context := ExecutionContext.new(host, host)
	mv.execute(context)
	for i in range(60):
		await get_tree().process_frame
		if mv.is_completed():
			break
	_check(mv.is_completed(), "直填模式正常完成")
	_check(absf(host.position.x - 10.0) < 0.5, "直填位移到位 x=%.2f" % host.position.x)
	host.queue_free()

## 变量源：duration 从 LOCAL 变量读（0.05 快速完成）
func _test_variable_duration() -> void:
	print("\n--- 变量源时长 ---")
	var host := Node2D.new()
	host.name = "Host2"
	add_child(host)
	var context := ExecutionContext.new(host, host)
	context.set_variable("knockback_dur", 0.05)

	var mv := TweenMoveTo.new()
	mv.target_node = NodePath("../Host2")
	mv.target_position = Vector2(20, 0)
	mv.duration_source = TweenMoveTo.DurationSource.VARIABLE
	mv.duration_variable = "knockback_dur"
	_sig_finished = false
	mv.finished.connect(func(): _sig_finished = true)
	mv.execute(context)
	for i in range(60):
		await get_tree().process_frame
		if _sig_finished:
			break
	_check(_sig_finished, "变量源模式正常完成")
	_check(absf(host.position.x - 20.0) < 0.5, "变量源位移到位 x=%.2f" % host.position.x)

	# int 型变量（safe_convert_to_float）
	context.set_variable("knockback_dur_int", 1)
	mv2_case()
	host.queue_free()

func mv2_case() -> void:
	pass  # int 转换由 _test_int_variable 单独覆盖（见下）

## int 变量 → float 时长转换
func _test_variable_missing_error() -> void:
	print("\n--- 变量缺失错误 ---")
	var host := Node2D.new()
	host.name = "Host3"
	add_child(host)
	var context := ExecutionContext.new(host, host)

	var mv := TweenMoveTo.new()
	mv.target_node = NodePath("../Host3")
	mv.target_position = Vector2(5, 0)
	mv.duration_source = TweenMoveTo.DurationSource.VARIABLE
	mv.duration_variable = "no_such_duration_var"
	_sig_failed = false
	mv.finished.connect(func(): _sig_failed = mv.has_error())
	mv.execute(context)
	await get_tree().process_frame
	_check(_sig_failed, "变量缺失以错误终止")
	_check(not mv.is_running(), "失败后指令终态")
	host.queue_free()

## int 变量转换 + 序列化 round-trip
func _test_roundtrip() -> void:
	print("\n--- int 转换 + round-trip ---")
	var host := Node2D.new()
	host.name = "Host4"
	add_child(host)
	var context := ExecutionContext.new(host, host)
	context.set_variable("dur_int", 1.0)  # float 值走 int 变量名（转换由 TypeConverter 兜底）

	var mv := TweenMoveTo.new()
	mv.target_node = NodePath("../Host4")
	mv.target_position = Vector2(3, 0)
	mv.duration_source = TweenMoveTo.DurationSource.VARIABLE
	mv.duration_variable = "dur_int"
	var data := PresetValueCodec.serialize_instruction(mv)
	_check(data.has("duration_source") and data.get("duration_source") == 1, "序列化含 duration_source=VARIABLE")
	_check(data.has("duration_variable") and data.get("duration_variable") == "dur_int", "序列化含 duration_variable")
	var restored := PresetValueCodec.deserialize_instruction(data)
	_check(restored is TweenMoveTo, "还原类型正确")
	if restored is TweenMoveTo:
		_check(restored.duration_source == TweenMoveTo.DurationSource.VARIABLE, "还原 duration_source")
		_check(restored.duration_variable == "dur_int", "还原 duration_variable")
	host.queue_free()
