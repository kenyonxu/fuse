extends Node

## ExecutionContext _init / duplicate 修复测试
##
## B19: _init 中 _variable_context 创建误嵌在 if trigger_node: 块下，
##      仅传 target 不传 trigger 时 _variable_context 永远 nil → set_variable/get_variable 报 Nil。
## B11: duplicate() 未复制 _diagnostics，复制后执行历史/状态/统计丢失。

const ExecutionContext = preload("res://addons/fuse/core/base/execution_context.gd")

var _fail_count: int = 0


func _ready() -> void:
	_test_b19_target_only_variable_context_inited()
	_test_b19_target_only_set_get_variable()
	_test_b19_target_only_diagnostics_inited()
	_test_b11_duplicate_copies_diagnostics()
	_test_b11_duplicate_diagnostics_is_deep_copy()
	print("\n=== 结果: %d 处失败 ===" % _fail_count)
	if _fail_count > 0:
		push_error("ExecutionContext _init/duplicate 测试失败: %d 处" % _fail_count)
	get_tree().quit()


func _check(condition: bool, msg: String) -> void:
	if condition:
		print("  PASS: ", msg)
	else:
		_fail_count += 1
		push_error("  FAIL: ", msg)


# ============================================================
# B19：仅传 target 不传 trigger 时 _variable_context / _diagnostics 必须可用
# ============================================================

func _test_b19_target_only_variable_context_inited() -> void:
	print("\n--- B19: EC.new(target, null) 后 _variable_context 非 null ---")
	var target := Node.new()
	var ctx := ExecutionContext.new(target, null)
	_check(ctx._variable_context != null, "_variable_context 已创建（非 null）")
	ctx.cleanup()
	target.free()


func _test_b19_target_only_set_get_variable() -> void:
	print("\n--- B19: EC.new(target, null) 后 set_variable/get_variable 不报 Nil 且语义正确 ---")
	var target := Node.new()
	var ctx := ExecutionContext.new(target, null)
	# 修复前：_variable_context nil → "Nonexistent function 'set_variable' in Nil"
	var ok: bool = ctx.set_variable("score", 42)
	_check(ok, "set_variable('score', 42) 返回 true（实际 %s）" % str(ok))
	var v: Variant = ctx.get_variable("score", null, "local")
	_check(v == 42, "get_variable('score') == 42（实际 %s）" % str(v))
	ctx.cleanup()
	target.free()


func _test_b19_target_only_diagnostics_inited() -> void:
	print("\n--- B19: EC.new(target, null) 后 _diagnostics 非 null，状态查询可用 ---")
	var target := Node.new()
	var ctx := ExecutionContext.new(target, null)
	_check(ctx._diagnostics != null, "_diagnostics 已创建（非 null）")
	# get_execution_state 委托 _diagnostics，nil 会报错
	var state: int = ctx.get_execution_state()
	_check(state == ExecutionContext.ExecutionState.IDLE, "初始状态为 IDLE（实际 %d）" % state)
	ctx.cleanup()
	target.free()


# ============================================================
# B11：duplicate 复制 _diagnostics（深拷贝）
# ============================================================

func _test_b11_duplicate_copies_diagnostics() -> void:
	print("\n--- B11: duplicate() 后新 EC 的 _diagnostics 与原一致（状态/历史） ---")
	var target := Node.new()
	var trigger := Node.new()
	var ctx := ExecutionContext.new(target, trigger)
	# 写入一些执行历史 + 状态变化
	ctx.set_execution_state(ExecutionContext.ExecutionState.RUNNING)
	ctx.set_execution_state(ExecutionContext.ExecutionState.COMPLETED)
	var orig_history_size: int = ctx.get_execution_history().size()
	_check(orig_history_size > 0, "原 EC 有执行历史（size=%d）" % orig_history_size)

	var copy: ExecutionContext = ctx.duplicate()
	_check(copy._diagnostics != null, "duplicate 后 _diagnostics 非 null")
	_check(copy._diagnostics != ctx._diagnostics, "duplicate 后 _diagnostics 是独立实例（深拷贝）")
	var copy_history_size: int = copy.get_execution_history().size()
	_check(copy_history_size == orig_history_size,
		"duplicate 后历史长度一致（原 %d, 副本 %d）" % [orig_history_size, copy_history_size])
	_check(copy.get_execution_state() == ctx.get_execution_state(),
		"duplicate 后执行状态一致（原 %d, 副本 %d）" % [ctx.get_execution_state(), copy.get_execution_state()])
	copy.cleanup()
	ctx.cleanup()
	target.free()
	trigger.free()


func _test_b11_duplicate_diagnostics_is_deep_copy() -> void:
	print("\n--- B11: duplicate 后修改副本 _diagnostics 不影响原 EC（深拷贝独立性） ---")
	var target := Node.new()
	var trigger := Node.new()
	var ctx := ExecutionContext.new(target, trigger)
	ctx.set_execution_state(ExecutionContext.ExecutionState.RUNNING)
	var orig_state: int = ctx.get_execution_state()

	var copy: ExecutionContext = ctx.duplicate()
	copy.set_execution_state(ExecutionContext.ExecutionState.ERROR)
	_check(ctx.get_execution_state() == orig_state,
		"修改副本状态不影响原 EC（原 %d, 副本 %d）" % [ctx.get_execution_state(), copy.get_execution_state()])
	copy.cleanup()
	ctx.cleanup()
	target.free()
	trigger.free()
