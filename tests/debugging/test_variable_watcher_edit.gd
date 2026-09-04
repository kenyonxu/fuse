extends Node

## watcher 编辑链路单元测试：_coerce_value / _write_back_global 元数据保留 / v3 分组行

const WatcherScript = preload("res://addons/fuse/editor/debugging/variable_watcher.gd")

var _fail_count: int = 0
var _watcher: Control = null

const FAKE_V3 := {
	"containers": [{
		"id": 481, "path": "/Player", "scope_id": "player",
		"vars": {"invincible": false, "anchor": {"__complex": "(1, 2)", "ty": "Vector2"}}
	}],
	"units": [{
		"id": 922, "path": "/Player/OnInput", "kind": "trigger", "ago_ms": 300,
		"local": {"hp": 55, "dir": {"__complex": "(1, 0)", "ty": "Vector2"}}
	}]
}


func _ready() -> void:
	_watcher = WatcherScript.new()
	add_child(_watcher)

	_test_coerce_value()
	_test_write_back_global_metadata()
	_test_collect_runtime_early_return_typed()
	_test_rows_v3_groups()
	_test_editable_v3()
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


## 回归（2026-09-04 编辑器实测刷屏）：早退路径（桥缺失/缓存空——编辑器静止常态）
## 必须返回类型化 Array[Dictionary]，否则 _refresh 的类型化接收每 0.5s 刷类型错误
func _test_collect_runtime_early_return_typed() -> void:
	print("\n--- _collect_runtime_variables 早退路径类型化 ---")
	# 本测试进程无运行游戏连接：autoload 桥为客户端模式且缓存为空 → 恰走早退分支
	var runtime: Dictionary = _watcher._collect_runtime_variables()
	_check(runtime["local_rows"].get_typed_builtin() == TYPE_DICTIONARY,
		"早退 local_rows 为 Array[Dictionary]")
	_check(runtime["unit_groups"] is Array and runtime["container_groups"] is Array, "早退含分组键")
	var rows: Array[Dictionary] = runtime["scope_rows"]
	_check(rows.is_empty(), "早退结果为空")


func _test_rows_v3_groups() -> void:
	print("\n--- _rows_from_cached v3 分组 ---")
	var rows: Dictionary = _watcher._rows_from_cached(FAKE_V3)
	var cgroups: Array = rows["container_groups"]
	var ugroups: Array = rows["unit_groups"]
	_check(cgroups.size() == 1 and cgroups[0]["key"] == "c481", "容器组 key=c481")
	_check(cgroups[0]["scope_id"] == "player", "容器组 scope_id")
	var scope_rows: Array = rows["scope_rows"]
	_check(scope_rows.size() == 2, "容器 2 变量 → 2 行")
	var by_name := {}
	for row in scope_rows:
		by_name[row["name"]] = row
	_check(by_name["invincible"]["target"] == "container" and by_name["invincible"]["id"] == 481, "行携带 target/id")
	_check(by_name["anchor"]["is_complex"] == true and by_name["anchor"]["type"] == "Vector2", "__complex 行只读标注")
	_check(ugroups.size() == 1 and ugroups[0]["kind"] == "trigger" and ugroups[0]["ago_ms"] == 300, "unit 组 kind/ago")
	_check(rows["local_rows"].size() == 2, "unit 2 变量 → 2 行")
	_check(int(rows["unit_count"]) == 1 and int(rows["container_count"]) == 1, "计数正确")


func _test_editable_v3() -> void:
	print("\n--- v3 行可编辑门控 ---")
	_check(_watcher._is_row_editable({"target": "container", "type": "int", "is_complex": false}) == true, "容器标量行可编辑")
	_check(_watcher._is_row_editable({"target": "unit", "type": "int", "is_complex": false}) == true, "unit 标量行可编辑")
	_check(_watcher._is_row_editable({"target": "container", "type": "Vector2", "is_complex": true}) == false, "__complex 行不可编辑")
	_check(_watcher._is_row_editable({"target": "global", "type": "int", "is_complex": false}) == true, "global 行可编辑")
	_check(_watcher._is_row_editable({"target": "", "type": "int", "is_complex": false}) == false, "无 target 不可编辑")
	_check(_watcher._is_row_editable({"target": "global", "type": "int", "is_complex": false, "is_note": true}) == false, "笔记行不可编辑")
	_check(_watcher._is_row_editable({"target": "global", "type": "int", "is_complex": false, "is_static": true}) == false, "静态行不可编辑")


func _cleanup_globals() -> void:
	var mgr := GlobalVariableManager.get_instance()
	for vname in ["gold", "silver"]:
		if mgr.has_variable(vname):
			mgr.remove_variable(vname)
	_watcher.queue_free()
