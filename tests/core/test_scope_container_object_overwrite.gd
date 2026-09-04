extends Node

## 回归：ScopeVariableContainer.set_variable 混型（Object↔非 Object）写入不得触发
## "Invalid operands 'Object' and 'String'" 运行时错误
## （2026-09-04 运行时编辑实测崩溃点：scope 槽位持 Object，桥写回 String）

const ContainerScript = preload("res://addons/fuse/core/base/scope_variable_container.gd")

var _fail_count: int = 0


func _ready() -> void:
	_test_object_overwritten_by_string()
	_test_scalar_equal_no_emit()
	print("\n=== 结果: %d 处失败 ===" % _fail_count)
	get_tree().quit(1 if _fail_count > 0 else 0)


func _check(condition: bool, msg: String) -> void:
	if condition:
		print("  PASS: ", msg)
	else:
		_fail_count += 1
		push_error("  FAIL: " + msg)


func _test_object_overwritten_by_string() -> void:
	print("\n--- Object 槽位被 String 覆盖：不崩、发变更信号 ---")
	var c := ContainerScript.new()
	add_child(c)
	var obj := Node.new()
	var emitted: Array = []
	c.scope_variable_changed.connect(func(n, old_v, new_v): emitted.append([n, old_v, new_v]))

	c.set_variable("slot", obj)
	c.set_variable("slot", "text")

	_check(c.get_variable("slot", null) == "text", "值已替换为 String")
	# 两次写入各发一次（首次 null→Object 本就发信号，混型覆盖不得崩溃也不得漏发）
	_check(emitted.size() == 2, "两次写入恰发两次变更信号（got %d）" % emitted.size())
	if emitted.size() >= 2:
		_check(emitted[0][1] == null and emitted[0][2] == obj, "首次信号：null → Object")
		_check(emitted[1][1] == obj and emitted[1][2] == "text", "覆盖信号：旧 Object → 新 String")

	obj.free()
	c.queue_free()


func _test_scalar_equal_no_emit() -> void:
	print("\n--- 同型等值写入：不发信号（既有语义保持） ---")
	var c := ContainerScript.new()
	add_child(c)
	var emitted := 0
	c.scope_variable_changed.connect(func(_n, _o, _v): emitted += 1)

	c.set_variable("hp", 100)
	c.set_variable("hp", 100)

	_check(emitted == 0, "等值重复写入不发信号（got %d）" % emitted)
	c.queue_free()
