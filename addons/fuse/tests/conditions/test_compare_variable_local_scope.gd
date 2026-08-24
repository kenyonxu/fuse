# 测试：CompareVariable LOCAL 作用域 + 跨类型比较安全性
# 1. LOCAL 直接读执行上下文局部变量（event_* 参数验证的推荐作用域）
# 2. 容器存在时 NEAREST 读不到局部变量（spec 已知局限），LOCAL 可读
# 3. Object 与非 Object 混合比较不再抛运行时错误
extends Node

var _fail: int = 0

func _ready() -> void:
	print("=== CompareVariable LOCAL/类型安全 测试开始 ===")
	await _test_local_read_bare_scene()
	await _test_local_read_with_container()
	_test_object_comparison_safety()
	_test_cross_type_compatibility()
	print("=== CompareVariable LOCAL/类型安全 测试完成（失败 %d 项）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("✓ " + message)
	else:
		_fail += 1
		push_error("✗ " + message)

## 构造 CompareVariable 并走完整 check() 链路
func _make_cond(source: int, var_name: String, op: int, value: Variant) -> CompareVariable:
	var cond := CompareVariable.new()
	cond.variable_name = var_name
	cond.scope_source = source
	cond.comparison_operator = op
	cond.compare_value = value
	return cond

## 裸场景（无 ScopeVariableContainer）：LOCAL 与 NEAREST 均可读局部变量
func _test_local_read_bare_scene() -> void:
	print("\n--- 裸场景 LOCAL 读取 ---")
	var trigger := Node.new()
	trigger.name = "BareTrigger"
	add_child(trigger)
	var context := ExecutionContext.new(trigger, trigger)
	context.set_variable("event_value", 42)

	var local_cond := _make_cond(CompareVariable.ScopeSource.LOCAL, "event_value",
		CompareVariable.ComparisonOperator.EQUAL, 42)
	_check(local_cond.check(context) == true, "LOCAL 读取局部变量：EQUAL 42 应通过")

	var local_ne := _make_cond(CompareVariable.ScopeSource.LOCAL, "event_value",
		CompareVariable.ComparisonOperator.NOT_EQUAL, 42)
	_check(local_ne.check(context) == false, "LOCAL 读取：NOT_EQUAL 42 应不通过")

	# 裸场景下 NEAREST 靠无容器回退（variable_operations 修复）也能读到
	var nearest_cond := _make_cond(CompareVariable.ScopeSource.NEAREST, "event_value",
		CompareVariable.ComparisonOperator.EQUAL, 42)
	_check(nearest_cond.check(context) == true, "裸场景 NEAREST 回退也能读到局部变量")

## 容器存在场景（spec 已知局限）：NEAREST 读不到局部变量，LOCAL 可读
func _test_local_read_with_container() -> void:
	print("\n--- 容器场景 LOCAL 读取 ---")
	var container := ScopeVariableContainer.new()
	container.scope_id = "test_scope_container"
	container.name = "TestContainer"
	add_child(container)

	var trigger := Node.new()
	trigger.name = "ScopedTrigger"
	container.add_child(trigger)

	# 容器注册是 call_deferred，等一帧确保 ScopeVariableManager 生效
	await get_tree().process_frame

	var context := ExecutionContext.new(trigger, trigger)
	context.set_variable("event_value", 42)

	# 已知局限钉死：容器存在但变量不在容器中 → NEAREST 读到 null
	var nearest_cond := _make_cond(CompareVariable.ScopeSource.NEAREST, "event_value",
		CompareVariable.ComparisonOperator.EQUAL, 42)
	_check(nearest_cond.check(context) == false, "容器场景 NEAREST 读不到局部变量（已知局限）")
	var nearest_ne := _make_cond(CompareVariable.ScopeSource.NEAREST, "event_value",
		CompareVariable.ComparisonOperator.NOT_EQUAL, 42)
	_check(nearest_ne.check(context) == true, "容器场景 NEAREST NOT_EQUAL 恒真（误导方向，已知局限）")

	# LOCAL 是解法：不经容器直接读局部变量
	var local_cond := _make_cond(CompareVariable.ScopeSource.LOCAL, "event_value",
		CompareVariable.ComparisonOperator.EQUAL, 42)
	_check(local_cond.check(context) == true, "容器场景 LOCAL 仍能读到局部变量（解法验证）")

## Object 与非 Object 混合比较不抛运行时错误
func _test_object_comparison_safety() -> void:
	print("\n--- Object 比较安全性 ---")
	var trigger := Node.new()
	trigger.name = "ObjTrigger"
	add_child(trigger)
	var context := ExecutionContext.new(trigger, trigger)
	context.set_variable("body_ref", trigger)  # Object 局部变量（如 event_body）

	var eq := _make_cond(CompareVariable.ScopeSource.LOCAL, "body_ref",
		CompareVariable.ComparisonOperator.EQUAL, 1)
	_check(eq.check(context) == false, "Object EQUAL int 应返回 false 而非抛错")

	var ne := _make_cond(CompareVariable.ScopeSource.LOCAL, "body_ref",
		CompareVariable.ComparisonOperator.NOT_EQUAL, 1)
	_check(ne.check(context) == true, "Object NOT_EQUAL int 应返回 true 而非抛错")

	var gt := _make_cond(CompareVariable.ScopeSource.LOCAL, "body_ref",
		CompareVariable.ComparisonOperator.GREATER_THAN, 1)
	_check(gt.check(context) == false, "Object GREATER int 应返回 false 而非抛错")

	var same_obj := _make_cond(CompareVariable.ScopeSource.LOCAL, "body_ref",
		CompareVariable.ComparisonOperator.EQUAL, trigger)
	_check(same_obj.check(context) == true, "Object EQUAL 同一 Object 引用应通过")

## 既有跨类型兼容行为回归
func _test_cross_type_compatibility() -> void:
	print("\n--- 跨类型兼容回归 ---")
	var trigger := Node.new()
	trigger.name = "CompatTrigger"
	add_child(trigger)
	var context := ExecutionContext.new(trigger, trigger)

	context.set_variable("s_var", "5")
	var str_num := _make_cond(CompareVariable.ScopeSource.LOCAL, "s_var",
		CompareVariable.ComparisonOperator.EQUAL, 5)
	_check(str_num.check(context) == true, "字符串 '5' EQUAL 数值 5 既有语义保持")

	context.set_variable("i_var", 7)
	var gt_str := _make_cond(CompareVariable.ScopeSource.LOCAL, "i_var",
		CompareVariable.ComparisonOperator.GREATER_THAN, "abc")
	_check(gt_str.check(context) == false, "数值 GREATER 非数值字符串应返回 false 而非抛错")

	var null_var := _make_cond(CompareVariable.ScopeSource.LOCAL, "not_exist_var",
		CompareVariable.ComparisonOperator.EQUAL, null)
	_check(null_var.check(context) == true, "不存在的变量 EQUAL null 应通过（default null）")
