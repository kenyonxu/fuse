extends Node

## 桥环回测试：同进程 server/client 双桥，覆盖协议 v2 推送与反向 set_var 全链路
## 用独立端口 24599，避开 headless 下 autoload 桥（客户端模式连 24563）的干扰

const BridgeScript = preload("res://addons/fuse/core/fuse_runtime_bridge.gd")
const TEST_PORT := 24599

var _fail_count: int = 0
var _server: Node = null
var _client: Node = null
var _stub_runner: Node = null


func _ready() -> void:
	await get_tree().process_frame  # 等 autoload 完成自身 _ready

	_server = BridgeScript.new()
	_server.start_server(TEST_PORT)
	add_child(_server)

	if not _server.is_server_active():
		# 环境无 TCP（CI 特殊环境）：打印警告后跳过，不算失败（spec §10）
		push_warning("loopback 测试跳过: 127.0.0.1:%d 无法监听" % TEST_PORT)
		get_tree().quit(0)
		return

	_client = BridgeScript.new()
	_client.start_client(TEST_PORT)
	add_child(_client)

	_test_extract_json_lines()
	_test_send_set_var_without_connection()
	_setup_stub_runner()
	_check(await _await_connected(), "client 已连接编辑器（超时 5s）")
	await _test_push_payload_reaches_cache()
	await _test_set_var_global_full_path()  # Task 3 补断言体
	_test_apply_set_var_local_unit()        # Task 3 补断言体
	_test_apply_set_var_non_scalar_guard()  # 回归：非标量槽位守卫
	await _test_push_always_without_runners()  # Task 2 审查携带：无 Runner 仍恒推 global
	_cleanup()

	print("\n=== 结果: %d 处失败 ===" % _fail_count)
	get_tree().quit(1 if _fail_count > 0 else 0)


func _check(condition: bool, msg: String) -> void:
	if condition:
		print("  PASS: ", msg)
	else:
		_fail_count += 1
		push_error("  FAIL: " + msg)


## 粘包/半包：一次到两条 + 半条留缓冲
func _test_extract_json_lines() -> void:
	print("\n--- extract_json_lines 粘包/半包 ---")
	var glue := '{"t":"vars","runners":[]}\n{"t":"set_var","scope":"global","name":"a","value":1}\n'
	var result: Dictionary = BridgeScript.extract_json_lines(glue + '{"t":"vars","run')
	_check(result["lines"].size() == 2, "粘包两行均解析（got %d）" % result["lines"].size())
	_check(result["rest"] == '{"t":"vars","run', "半行留在 rest")
	var result2: Dictionary = BridgeScript.extract_json_lines(result["rest"] + 'ners":[]}\n')
	_check(result2["lines"].size() == 1 and result2["rest"].is_empty(), "续包后补全并清空 rest")


## 无连接时发送返回 false
func _test_send_set_var_without_connection() -> void:
	print("\n--- send_set_var 无连接返回 false ---")
	var orphan := BridgeScript.new()
	_check(orphan.send_set_var("global", 0, "x", 1) == false, "未连接的桥发送返回 false")
	orphan.free()


func _setup_stub_runner() -> void:
	_stub_runner = Runner.new()
	_stub_runner.name = "StubRunner"
	add_child(_stub_runner)
	var ec = ExecutionContext.new()
	var vc = ec.get("_variable_context")  # 与桥同款访问路径
	vc.set_variable("hp", 100, "local")
	_stub_runner.current_execution_context = ec


func _await_connected(timeout_sec: float = 5.0) -> bool:
	var acc := 0.0
	while acc < timeout_sec:
		if _server.is_game_connected():
			return true
		await get_tree().create_timer(0.1).timeout
		acc += 0.1
	return false


## 真实 socket 全链路：stub Runner + 预置 global → 0.5s 节拍推送 → server 缓存断言
func _test_push_payload_reaches_cache() -> void:
	print("\n--- 推送 v2：id + global + 恒推（全链路）---")
	var mgr := GlobalVariableManager.get_instance()
	mgr.add_variable("score", BaseVariable.create("score", 7, BaseVariable.VariableScope.GLOBAL))

	await get_tree().create_timer(1.3).timeout

	var cached: Dictionary = _server.get_cached_vars()
	_check(_server.is_game_connected(), "client 已连接")
	_check(cached.has("StubRunner"), "runner 条目存在（got %s）" % str(cached.keys()))
	if cached.has("StubRunner"):
		var entry: Dictionary = cached["StubRunner"]
		_check(int(entry.get("id", 0)) == _stub_runner.get_instance_id(), "id 为 runner 实例 id")
		_check(entry.get("local", {}).get("hp", null) != null, "local 快照含 hp")
	var cached_global: Dictionary = _server.get_cached_global()
	_check(cached_global.get("score", null) == 7, "global 快照送达（runners 非空场景）")


## 全链路：server send_set_var → socket → client 收到并应用到本进程单例
func _test_set_var_global_full_path() -> void:
	print("\n--- set_var global 全链路（int 收窄）---")
	var ok: bool = _server.send_set_var("global", 0, "score", 11.0)
	_check(ok, "send_set_var 广播成功返回 true")
	await get_tree().create_timer(1.3).timeout
	var v = GlobalVariableManager.get_instance().get_variable("score")
	_check(v != null and v.value == 11, "global 值已应用为 11（got %s）" % str(v.value if v else null))
	_check(v != null and typeof(v.value) == TYPE_INT, "int 目标收窄为 int（JSON 11.0 不写坏成 float）")


## 单元级：local 分发（真 Runner + 真 ExecutionContext）+ 容错
func _test_apply_set_var_local_unit() -> void:
	print("\n--- _apply_set_var local 单元 + 容错 ---")
	var vc = _stub_runner.current_execution_context.get("_variable_context")
	_client._apply_set_var({
		"t": "set_var", "scope": "local",
		"runner_id": _stub_runner.get_instance_id(),
		"name": "hp", "value": 55.0
	})
	_check(vc.get_variable("hp", null, "local") == 55, "local hp 写入 55")
	_check(typeof(vc.get_variable("hp", null, "local")) == TYPE_INT, "int 目标收窄为 int")

	# 无效 runner_id：静默不崩
	_client._apply_set_var({
		"t": "set_var", "scope": "local", "runner_id": 99999999,
		"name": "hp", "value": 1.0
	})
	_check(vc.get_variable("hp", null, "local") == 55, "无效 runner_id 静默忽略")

	# global 不存在：不创建
	_client._apply_set_var({
		"t": "set_var", "scope": "global", "runner_id": 0,
		"name": "no_such_var", "value": 1.0
	})
	_check(GlobalVariableManager.get_instance().get_variable("no_such_var") == null, "global 目标不存在不创建")


## 回归（2026-09-04 运行时编辑实测崩溃）：推送快照会把 Object 序列化成字符串，
## 编辑器无法分辨真伪标量——非标量槽位的写回必须在游戏侧静默跳过
func _test_apply_set_var_non_scalar_guard() -> void:
	print("\n--- _apply_set_var 非标量槽位守卫 ---")
	var node_val := Node.new()
	var vc = _stub_runner.current_execution_context.get("_variable_context")
	vc.set_variable("target_obj", node_val, "local")
	_client._apply_set_var({
		"t": "set_var", "scope": "local",
		"runner_id": _stub_runner.get_instance_id(),
		"name": "target_obj", "value": "abc"
	})
	_check(vc.get_variable("target_obj", null, "local") == node_val, "local Object 槽位写回被跳过（原对象保留）")
	node_val.free()

	var mgr := GlobalVariableManager.get_instance()
	mgr.add_variable("bridge_vec_test", BaseVariable.create(
		"bridge_vec_test", Vector2(1, 2), BaseVariable.VariableScope.GLOBAL))
	_client._apply_set_var({
		"t": "set_var", "scope": "global", "runner_id": 0,
		"name": "bridge_vec_test", "value": "5"
	})
	var vec_var = mgr.get_variable("bridge_vec_test")
	_check(vec_var != null and vec_var.value == Vector2(1, 2), "global 非标量槽位写回被跳过（Vector2 保留）")
	mgr.remove_variable("bridge_vec_test")


## 恒推：移除 Runner 后仍推送 global（空 runners 快照不断流）
func _test_push_always_without_runners() -> void:
	print("\n--- 恒推空 runners：global 仍送达 ---")
	remove_child(_stub_runner)  # 保留引用，_cleanup 仍可 free
	GlobalVariableManager.get_instance().set_variable_value_thread_safe("score", 33)
	await get_tree().create_timer(1.3).timeout
	_check(_server.get_cached_global().get("score") == 33, "无 Runner 仍恒推 global（score=33）")
	_check(_server.get_cached_vars().is_empty(), "空 runners 快照清空 runner 缓存")


func _cleanup() -> void:
	if _stub_runner:
		_stub_runner.queue_free()
	if _client:
		_client.queue_free()
	if _server:
		_server.queue_free()
