# 测试：参数过滤统一升级——matches_arg 类型安全 / OnTargetSignalEmit dict 过滤
extends Node

var _fail: int = 0
var _triggered_count: int = 0
# WaitForSignal 完成标志（GDScript lambda 按值捕获局部变量，须用成员变量传递）
var _wfs_finished: bool = false

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
	await _test_otsa_empty_dict_no_match()
	await _test_wait_for_signal_filter()
	_test_arg_filter_subproperty_bridge()
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
	_check(SignalInfo.matches_arg(Vector2(1, 2), Vector2i(1, 2)), "Vector2 期望 vs Vector2i 实际（互转相等）")
	_check(not SignalInfo.matches_arg(Vector2(1, 2), Vector2i(1, 3)), "Vector2 期望 vs Vector2i 实际（互转不等）")
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

## OnTargetSignalEmit：门控开启但空 dict → 明确不匹配（暴露配置缺失而非静默全过）
func _test_otsa_empty_dict_no_match() -> void:
	print("\n--- 空 dict 不匹配 ---")
	_triggered_count = 0
	var emitter := AnimEmitter.new()
	emitter.name = "EmptyDictEmitter"
	add_child(emitter)

	var ev := OnTargetSignalEmit.new()
	ev.target_node = NodePath("../EmptyDictEmitter")
	ev.target_signal = "animation_finished"
	ev.filter_signal_args = true
	ev.arg_filter_values = {}  # 门控开但未配置任何键
	ev.triggered.connect(func(_n): _triggered_count += 1)
	ev.initialize(self)

	emitter.emit_signal("animation_finished", "anything")
	_check(_triggered_count == 0, "空 dict：信号发出但不触发")
	ev.terminate(self)
	emitter.queue_free()

## WaitForSignal：单参动画式过滤（匹配完成/不匹配继续等）+ 4 参部分过滤 + 类型安全
func _test_wait_for_signal_filter() -> void:
	print("\n--- WaitForSignal 过滤 ---")
	var emitter := AnimEmitter.new()
	emitter.name = "WfsEmitter"
	add_child(emitter)

	var wfs := WaitForSignal.new()
	wfs.target_node = NodePath("../WfsEmitter")
	wfs.target_signal = "animation_finished"
	wfs.timeout = 3.0
	wfs.filter_signal_args = true
	wfs.arg_filter_values = {"anim_name": "attack"}

	var context := ExecutionContext.new(emitter, emitter)
	_wfs_finished = false
	wfs.finished.connect(func(): _wfs_finished = true)
	var sync_done: bool = wfs.execute_sync(context)
	_check(sync_done == false, "进入异步等待")

	# 不匹配的动画结束 → 继续等
	emitter.emit_signal("animation_finished", "idle")
	await get_tree().process_frame
	_check(not _wfs_finished, "idle 结束不结束等待（继续等）")

	# 匹配的动画结束 → 完成且捕获 event_*
	emitter.emit_signal("animation_finished", "attack")
	await get_tree().process_frame
	_check(_wfs_finished, "attack 结束完成等待")
	_check(context.get_variable("event_anim_name") == "attack", "event_anim_name 捕获")

	# 4 参部分过滤 + 类型安全（复用 MultiArgEmitter）
	var m := MultiArgEmitter.new()
	m.name = "MultiEmitter"
	add_child(m)
	var wfs2 := WaitForSignal.new()
	wfs2.target_node = NodePath("../MultiEmitter")
	wfs2.target_signal = "shape_entered"
	wfs2.timeout = 3.0
	wfs2.filter_signal_args = true
	wfs2.arg_filter_values = {"body_shape": 2, "body_id": self}  # body_id 期望 Object=self，实际 int → 不匹配
	var ctx2 := ExecutionContext.new(m, m)
	_wfs_finished = false
	wfs2.finished.connect(func(): _wfs_finished = true)
	wfs2.execute_sync(ctx2)
	m.emit_signal("shape_entered", 1, self, 2, 0)  # body_id=1(int) vs 期望 self(Object)
	await get_tree().process_frame
	_check(not _wfs_finished, "Object 期望 vs int 实际 → 不匹配不抛错（继续等）")
	wfs2.arg_filter_values = {"body_shape": 2}
	m.emit_signal("shape_entered", 1, self, 2, 0)
	await get_tree().process_frame
	_check(_wfs_finished, "部分过滤（仅 body_shape）匹配完成")
	emitter.queue_free()
	m.queue_free()

## Inspector 子属性桥接（_set/_get 分发 dict 子路径）+ 子字段去 STORAGE（serialize 无冗余子键）
func _test_arg_filter_subproperty_bridge() -> void:
	print("\n--- per-arg 字段 _set/_get 桥接 ---")
	# WaitForSignal 桥接直测（引擎 Object.set/get 不支持 dict 子路径，靠 _set/_get 桥接）
	var wfs := WaitForSignal.new()
	wfs.set("arg_filter_values/anim_name", "attack")
	_check(wfs.arg_filter_values.get("anim_name") == "attack", "WFS _set 子路径写入 dict")
	_check(wfs.get("arg_filter_values/anim_name") == "attack", "WFS _get 子路径读出 dict")
	wfs.set("arg_filter_values/anim_name", null)
	_check(not wfs.arg_filter_values.has("anim_name"), "WFS _set null 移除键")

	# OnTargetSignalEmit 桥接直测
	var ev := OnTargetSignalEmit.new()
	ev.set("arg_filter_values/anim_name", "idle")
	_check(ev.arg_filter_values.get("anim_name") == "idle", "OTSA _set 子路径写入 dict")
	_check(ev.get("arg_filter_values/anim_name") == "idle", "OTSA _get 子路径读出 dict")
	ev.set("arg_filter_values/anim_name", null)
	_check(not ev.arg_filter_values.has("anim_name"), "OTSA _set null 移除键")

	# WFS serialize 无冗余子键（模拟编辑器信号缓存使 per-arg 字段进属性列表）
	var sig_info := SignalInfo.new()
	sig_info.name = "animation_finished"
	sig_info.args = [{"name": "anim_name", "type": TYPE_STRING}]
	wfs._editor_available_signals = [sig_info]
	wfs.target_signal = "animation_finished"
	wfs.filter_signal_args = true
	wfs.arg_filter_values = {"anim_name": "attack"}
	var data := PresetValueCodec.serialize_instruction(wfs)
	var has_subkey := false
	for k in data.keys():
		if String(k).begins_with("arg_filter_values/"):
			has_subkey = true
	_check(data.has("arg_filter_values") and data["arg_filter_values"].get("anim_name") == "attack",
		"顶层 dict 为唯一数据源（含完整过滤值）")
	_check(not has_subkey, "WFS serialize 不产出 arg_filter_values/ 冗余子键")

	# OTSA serialize 无冗余子键（initialize 解析 runtime signal_info 使子字段进属性列表）
	var emitter := AnimEmitter.new()
	emitter.name = "BridgeEmitter"
	add_child(emitter)
	var ev2 := OnTargetSignalEmit.new()
	ev2.target_node = NodePath("../BridgeEmitter")
	ev2.target_signal = "animation_finished"
	ev2.filter_signal_args = true
	ev2.arg_filter_values = {"anim_name": "attack"}
	ev2.initialize(self)
	var ev_data := PresetValueCodec.serialize_event(ev2)
	var ev_has_sub := false
	for k in ev_data.keys():
		if String(k).begins_with("arg_filter_values/"):
			ev_has_sub = true
	_check(not ev_has_sub, "OTSA serialize 不产出 arg_filter_values/ 冗余子键")
	ev2.terminate(self)
	emitter.queue_free()
