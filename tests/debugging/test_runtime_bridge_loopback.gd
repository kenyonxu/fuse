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
	await _await_connected()
	_test_push_payload_reaches_cache()      # Task 2 补断言体
	await _test_set_var_global_full_path()  # Task 3 补断言体
	_test_apply_set_var_local_unit()        # Task 3 补断言体
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


func _test_push_payload_reaches_cache() -> void:
	pass  # Task 2 填充


func _test_set_var_global_full_path() -> void:
	pass  # Task 3 填充


func _test_apply_set_var_local_unit() -> void:
	pass  # Task 3 填充


func _cleanup() -> void:
	if _stub_runner:
		_stub_runner.queue_free()
	if _client:
		_client.queue_free()
	if _server:
		_server.queue_free()
