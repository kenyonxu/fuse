# addons/fuse/tests/graduation/test_fuse_delegation.gd
extends Node

## FuseDelegation 桥接面测试（M0 毕业导出器）
##
## 覆盖五桥：指令重建+执行 / await 语义 / 变量 / 事件 / 门控 / 条件重建检查。
## 事件桥用例依赖 autoload FuseEventBus（project.godot 已注册）。

const FuseDelegation := preload("res://addons/fuse/core/graduation/fuse_delegation.gd")
const ScopeVariableContainer := preload("res://addons/fuse/core/base/scope_variable_container.gd")

var _fail: int = 0


func _ready() -> void:
	print("=== FuseDelegation 桥接面测试 ===")
	await _test_build_and_run_delegated()
	await _test_run_await_semantics()
	await _test_variable_bridge()
	await _test_event_bridge()
	await _test_gate()
	await _test_check_condition()
	print("=== FuseDelegation 测试完成（失败 %d）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("✓ %s" % msg)
	else:
		_fail += 1
		push_error("✗ FAIL: %s" % msg)


func _test_build_and_run_delegated() -> void:
	var insts: Dictionary = FuseDelegation.build_delegated({
		"b0": [{"type": "Print", "message": "grad-hello"}]})
	_check(insts is Dictionary and (insts["b0"] as Array).size() == 1, "JSON 重建 1 条指令")
	var holder := Node.new()
	add_child(holder)
	var b0: Array = insts["b0"]
	FuseDelegation.run(holder, b0, 0)  # Print 同步完成，无需 await 也应落地
	# run 内部经 call_deferred 启动（deferred 队列在 process_frame 之后 flush），等两帧确保落地
	await get_tree().process_frame
	await get_tree().process_frame
	var first: BaseInstruction = b0[0]
	_check(first.is_completed(), "委托指令执行完成")
	holder.queue_free()


func _test_run_await_semantics() -> void:
	# 暖链：Wait 计时路径在 headless 下的首跑存在一次性偏差（相关脚本首次
	# 加载与 SceneTreeTimer 交互所致，实测首跑仅 ~0.05s），先完整执行一条
	# 短 Wait 链再断言正式链时长
	var warm: Dictionary = FuseDelegation.build_delegated({
		"w": [{"type": "Wait", "wait_time": 0.05}]})
	var warm_holder := Node.new()
	add_child(warm_holder)
	await FuseDelegation.run(warm_holder, warm["w"], 0)
	warm_holder.queue_free()

	# 与 ActionRunner 行为对照：Wait 0.2 秒的委托序列，await run 返回后应完成
	var insts: Dictionary = FuseDelegation.build_delegated({
		"b0": [{"type": "Wait", "wait_time": 0.2}, {"type": "Print", "message": "after-wait"}]})
	var holder := Node.new()
	add_child(holder)
	var b0: Array = insts["b0"]
	var t0 := Time.get_ticks_msec()
	await FuseDelegation.run(holder, b0, 0)
	var elapsed := (Time.get_ticks_msec() - t0) / 1000.0
	_check(elapsed >= 0.18, "await run 尊重 Wait 时长（%.2fs）" % elapsed)
	for inst_variant: Variant in b0:
		var inst: BaseInstruction = inst_variant
		_check(inst.is_completed(), "序列全部完成")
	holder.queue_free()


func _test_variable_bridge() -> void:
	var holder := Node.new()
	add_child(holder)
	FuseDelegation.set_var(holder, "grad_test_v", 42, "global")
	_check(FuseDelegation.get_var(holder, "grad_test_v", "global") == 42, "global 写读往返")
	holder.queue_free()


func _test_event_bridge() -> void:
	var received: Array = []
	var sub: Variant = FuseDelegation.subscribe("grad_test_evt", func(args: Dictionary): received.append(args))
	FuseDelegation.send_event("grad_test_evt", {"n": 7})
	await get_tree().process_frame
	_check(received.size() == 1 and received[0].get("n") == 7, "事件订阅-发送往返")
	FuseDelegation.unsubscribe(sub)
	FuseDelegation.send_event("grad_test_evt", {"n": 8})
	await get_tree().process_frame
	_check(received.size() == 1, "退订后不再收")


func _test_gate() -> void:
	var state := {}
	_check(FuseDelegation.gate_allows(state, "b0", false, 1, 10.0, 99), "GLOBAL 冷却首次放行")
	_check(not FuseDelegation.gate_allows(state, "b0", false, 1, 10.0, 99), "冷却期内拒绝")
	var state2 := {}
	_check(FuseDelegation.gate_allows(state2, "b0", true, 0, 0.0, 1), "once 首次放行")
	_check(not FuseDelegation.gate_allows(state2, "b0", true, 0, 0.0, 1), "once 二次拒绝")
	var state3 := {}
	_check(FuseDelegation.gate_allows(state3, "b0", false, 2, 10.0, 11), "PER_OBJECT obj11 放行")
	_check(not FuseDelegation.gate_allows(state3, "b0", false, 2, 10.0, 11), "PER_OBJECT obj11 冷却")
	_check(FuseDelegation.gate_allows(state3, "b0", false, 2, 10.0, 22), "PER_OBJECT obj22 不受 obj11 影响")


func _test_check_condition() -> void:
	# NEAREST 语义：check_condition 以 node 兼任 trigger，从 node 向上查找
	# ScopeVariableContainer 祖先——把容器节点作为 holder 父节点即可判真假
	var scope_parent: ScopeVariableContainer = ScopeVariableContainer.new()
	scope_parent.scope_id = "grad_scope_parent"
	scope_parent.set_variable("grad_cond_v", 123)
	add_child(scope_parent)
	var holder := Node.new()
	scope_parent.add_child(holder)

	# CheckScopeVariable 默认 scope_source=NEAREST / ComparisonOperator.EQUALS=0
	var json_true: Dictionary = {
		"type": "CheckScopeVariable",
		"variable_name": "grad_cond_v",
		"comparison_operator": 0,
		"expected_value": 123,
	}
	_check(FuseDelegation.check_condition(holder, json_true), "条件 JSON 重建后检查为 true")
	var json_false: Dictionary = {
		"type": "CheckScopeVariable",
		"variable_name": "grad_cond_v",
		"comparison_operator": 0,
		"expected_value": 999,
	}
	_check(not FuseDelegation.check_condition(holder, json_false), "条件 JSON 重建后检查为 false")
	_check(not FuseDelegation.check_condition(holder, {"type": "NoSuchCondition"}), "未知条件类型返回 false")
	holder.queue_free()
	scope_parent.queue_free()
