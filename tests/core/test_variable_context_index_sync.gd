extends Node

## VariableContext 数据一致性测试（B6 索引/字典双轨 + B7 SCOPE→LOCAL fallback）

const ExecutionContext = preload("res://addons/fuse/core/base/execution_context.gd")

var _fail_count: int = 0


func _ready() -> void:
	_test_b6_set_variable_then_get_by_index()
	_test_b6_set_by_index_then_get_variable()
	_test_b6_has_variable_after_set_by_index()
	_test_b7_scope_fallback_writes_local()
	print("\n=== 结果: %d 处失败 ===" % _fail_count)
	if _fail_count > 0:
		push_error("VariableContext 一致性测试失败: %d 处" % _fail_count)
	get_tree().quit()


func _check(condition: bool, msg: String) -> void:
	if condition:
		print("  PASS: ", msg)
	else:
		_fail_count += 1
		push_error("  FAIL: ", msg)


# ============================================================
# B6：索引访问与 LOCAL 字典双轨一致性
# ============================================================

# 创建 ExecutionContext，同时传入 dummy target + trigger 以触发 _variable_context 初始化
# （EC._init 的 VariableContext 创建嵌套在 trigger 分支下 —— 见 execution_context.gd:113-128，
# 这是一个独立的预存 bug，不在本任务范围）
func _make_ctx() -> ExecutionContext:
	var target := Node.new()
	var trigger := Node.new()
	return ExecutionContext.new(target, trigger)


func _test_b6_set_variable_then_get_by_index() -> void:
	print("\n--- B6: precompile 后 set_variable(name) → get_variable_by_index(index) ---")
	var ctx := _make_ctx()
	var names: Array[String] = ["x", "y", "z"]
	ctx.precompile_variable_access(names)
	ctx.set_variable("x", 1)
	var idx := ctx.get_variable_index("x")
	_check(idx == 0, "get_variable_index('x') == 0（实际 %d）" % idx)
	var by_index: Variant = ctx.get_variable_by_index(idx)
	_check(by_index == 1, "get_variable_by_index(0) == 1（实际 %s）" % str(by_index))


func _test_b6_set_by_index_then_get_variable() -> void:
	print("\n--- B6: precompile 后 set_variable_by_index(index) → get_variable(name) ---")
	var ctx := _make_ctx()
	var names: Array[String] = ["x", "y", "z"]
	ctx.precompile_variable_access(names)
	var idx := ctx.get_variable_index("y")
	ctx.set_variable_by_index(idx, 2)
	var by_name: Variant = ctx.get_variable("y")
	_check(by_name == 2, "get_variable('y') == 2（实际 %s）" % str(by_name))


func _test_b6_has_variable_after_set_by_index() -> void:
	print("\n--- B6: precompile 后 set_variable_by_index → has_variable(name) ---")
	var ctx := _make_ctx()
	var names: Array[String] = ["a", "b"]
	ctx.precompile_variable_access(names)
	var idx := ctx.get_variable_index("b")
	ctx.set_variable_by_index(idx, "hello")
	_check(ctx.has_variable("b"), "has_variable('b') 在 set_variable_by_index 后为 true")


# ============================================================
# B7：SCOPE→LOCAL 静默 fallback
# ============================================================

func _test_b7_scope_fallback_writes_local() -> void:
	print("\n--- B7: 无 scope 容器时 set_variable(name, value, 'scope') 应触发 error 并 fallback 到 LOCAL ---")
	var ctx := _make_ctx()
	# 注：捕获 push_error 在 Godot headless 中通过退出码/log 体现，
	# 此处重点验证 fallback 行为不破坏 LOCAL 契约；error 日志由人工/CI 检查。
	var ok: bool = ctx.set_variable("fallback_var", 99, "scope")
	_check(ok, "set_variable('scope') fallback 返回 true（实际 %s）" % str(ok))
	var v: Variant = ctx.get_variable("fallback_var", null, "local")
	_check(v == 99, "fallback 后 get_variable('fallback_var', 'local') == 99（实际 %s）" % str(v))
