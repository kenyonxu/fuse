extends Node

## watcher 编辑链路单元测试：_coerce_value / _is_row_editable / _write_back_global 元数据保留

const WatcherScript = preload("res://addons/fuse/editor/debugging/variable_watcher.gd")

var _fail_count: int = 0
var _watcher: Control = null


func _ready() -> void:
	_watcher = WatcherScript.new()
	add_child(_watcher)

	_test_coerce_value()
	_test_is_row_editable()
	_test_write_back_global_metadata()
	_cleanup_globals()

	print("\n=== 结果: %d 处失败 ===" % _fail_count)
	get_tree().quit(1 if _fail_count > 0 else 0)


func _check(condition: bool, msg: String) -> void:
	if condition:
		print("  PASS: ", msg)
	else:
		_fail_count += 1
		push_error("  FAIL: " + msg)


func _test_coerce_value() -> void:
	print("\n--- _coerce_value ---")
	_check(_watcher._coerce_value("42", "int") == 42, "int 合法文本")
	_check(_watcher._coerce_value("12a", "int") == null, "int 非法文本返回 null")
	_check(_watcher._coerce_value("3.5", "float") == 3.5, "float 合法文本")
	_check(_watcher._coerce_value("true", "bool") == true, "bool true")
	_check(_watcher._coerce_value(" 是 ", "bool") == true, "bool 中文是（strip+lower）")
	_check(_watcher._coerce_value("no", "bool") == false, "bool 其余为 false")
	_check(_watcher._coerce_value("abc", "String") == "abc", "String 原样")
	_check(_watcher._coerce_value("(1, 2)", "Vector2") == "(1, 2)", "未知类型最佳努力原样")


func _test_is_row_editable() -> void:
	print("\n--- _is_row_editable 门控 ---")
	_check(_watcher._is_row_editable({"scope": "global", "type": "int"}) == true, "global 标量行可编辑")
	_check(_watcher._is_row_editable({"scope": "local", "type": "int", "runner_id": 123}) == true, "local 运行行（有 id）可编辑")
	_check(_watcher._is_row_editable({"scope": "local", "type": "int", "runner_id": 0}) == false, "local 无 id 不可编辑")
	_check(_watcher._is_row_editable({"scope": "global", "type": "Vector2"}) == false, "复杂类型不可编辑")
	_check(_watcher._is_row_editable({"scope": "global", "type": "int", "is_note": true}) == false, "笔记行不可编辑")
	_check(_watcher._is_row_editable({"scope": "global", "type": "int", "is_static": true}) == false, "静态行不可编辑")
	_check(_watcher._is_row_editable({"scope": "", "type": "int"}) == false, "未知 scope 不可编辑")


func _test_write_back_global_metadata() -> void:
	print("\n--- _write_back_global 元数据保留 ---")
	var mgr := GlobalVariableManager.get_instance()
	var gold = BaseVariable.create("gold", 1, BaseVariable.VariableScope.GLOBAL)
	gold.description = "金币数量"
	mgr.add_variable("gold", gold)
	_watcher._write_back_global("gold", 5)
	var after = mgr.get_variable("gold")
	_check(after != null and after.value == 5, "既有变量改值为 5")
	_check(after != null and after.description == "金币数量", "description 保留（不再整体替换）")

	_watcher._write_back_global("silver", 2)
	var created = mgr.get_variable("silver")
	_check(created != null and created.value == 2, "不存在的变量创建成功")


func _cleanup_globals() -> void:
	var mgr := GlobalVariableManager.get_instance()
	for vname in ["gold", "silver"]:
		if mgr.has_variable(vname):
			mgr.remove_variable(vname)
	_watcher.queue_free()
