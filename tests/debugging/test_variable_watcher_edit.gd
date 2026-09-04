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
	_test_rows_from_cached_scope_dedupe()
	_test_collect_runtime_early_return_typed()
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


## 回归（2026-09-04 level01 实测）：共享 ScopeVariableContainer 的同一变量
## 被多个 Runner 重复上报，watcher 按"名+值"去重；local 为独立存储不去重
func _test_rows_from_cached_scope_dedupe() -> void:
	print("\n--- _rows_from_cached scope 去重 ---")
	var rows: Dictionary = _watcher._rows_from_cached({
		"RunnerA": {"id": 11, "local": {"hp": 10}, "scope": {"player": "P1", "camera": "Cam"}},
		"RunnerB": {"id": 22, "local": {"hp": 20}, "scope": {"player": "P1", "camera": "Cam"}},
		"RunnerC": {"id": 33, "local": {}, "scope": {"player": "P2"}},
	})
	var scope_rows: Array = rows["scope_rows"]
	_check(scope_rows.size() == 3, "同名同值去重（4 条上报 → 3 行，got %d）" % scope_rows.size())
	var by_name := {}
	for row in scope_rows:
		by_name[row["name"] + "=" + row["value"]] = true
	_check(by_name.has("player=P1") and by_name.has("player=P2") and by_name.has("camera=Cam"),
		"同名不同值（P1/P2）各保留一行")
	var local_rows: Array = rows["local_rows"]
	_check(local_rows.size() == 2, "local 为独立存储不去重（got %d）" % local_rows.size())
	var runner_count: int = rows["runner_count"]
	_check(runner_count == 3, "Runner 计数不受去重影响")
	var runners: Array = rows["runners"]
	_check(runners.size() == 3 and runners[1]["scope"].size() == 2,
		"快照 API（get_snapshot）保留每 Runner 全量数据")


## 回归（2026-09-04 编辑器实测刷屏）：早退路径（桥缺失/缓存空——编辑器静止常态）
## 必须返回类型化 Array[Dictionary]，否则 _refresh 的类型化接收每 0.5s 刷类型错误
func _test_collect_runtime_early_return_typed() -> void:
	print("\n--- _collect_runtime_variables 早退路径类型化 ---")
	# 本测试进程无运行游戏连接：autoload 桥为客户端模式且缓存为空 → 恰走早退分支
	var runtime: Dictionary = _watcher._collect_runtime_variables()
	_check(runtime["local_rows"].get_typed_builtin() == TYPE_DICTIONARY,
		"早退 local_rows 为 Array[Dictionary]")
	_check(runtime["scope_rows"].get_typed_builtin() == TYPE_DICTIONARY,
		"早退 scope_rows 为 Array[Dictionary]")
	var rows: Array[Dictionary] = runtime["scope_rows"]  # 与 _refresh 同款接收，不应报错
	_check(rows.is_empty(), "早退结果为空")


func _cleanup_globals() -> void:
	var mgr := GlobalVariableManager.get_instance()
	for vname in ["gold", "silver"]:
		if mgr.has_variable(vname):
			mgr.remove_variable(vname)
	_watcher.queue_free()
