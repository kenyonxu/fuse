extends Node

## 桥环回测试：同进程 server/client 双桥，覆盖协议 v3 推送与反向 set_var 全链路
## 用独立端口 24599，避开 headless 下 autoload 桥（客户端模式连 24563）的干扰

const BridgeScript = preload("res://addons/fuse/core/fuse_runtime_bridge.gd")
const TEST_PORT := 24599

var _fail_count: int = 0
var _server: Node = null
var _client: Node = null
var _stub_runner: Node = null
var _container: Node = null
var _trigger: MinimalTrigger = null


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

	_test_last_context_assignment()
	_test_extract_json_lines()
	_test_send_set_var_without_connection()
	_setup_test_tree()
	_check(await _await_connected(), "client 已连接编辑器（超时 5s）")
	await _test_push_payload_reaches_cache()
	await _test_set_var_targets_full_path()
	_test_apply_set_var_guards()
	await _test_push_always_without_units()  # 无单元仍恒推 global
	_cleanup()

	print("\n=== 结果: %d 处失败 ===" % _fail_count)
	get_tree().quit(1 if _fail_count > 0 else 0)


func _check(condition: bool, msg: String) -> void:
	if condition:
		print("  PASS: ", msg)
	else:
		_fail_count += 1
		push_error("  FAIL: " + msg)


## Task 1：BaseTrigger 保留最近执行上下文（v3 local 数据源）
func _test_last_context_assignment() -> void:
	print("\n--- BaseTrigger 最近上下文赋值 ---")
	var mt := MinimalTrigger.new()
	add_child(mt)
	var ec = mt._create_execution_context(mt)
	_check(mt.current_execution_context == ec, "current_execution_context 赋值")
	var now := Time.get_ticks_msec()
	_check(now - mt.current_execution_context_at_ms < 1000, "时间戳为当前时刻")
	mt.queue_free()


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


func _setup_test_tree() -> void:
	# 容器：挂测试场景根，带标量与复杂值
	_container = ScopeVariableContainer.new()
	_container.scope_id = "test_scope"
	_container.name = "TestContainer"
	add_child(_container)
	_container.set_variable("lives", 3)
	_container.set_variable("anchor", Vector2(1, 2))

	# 触发器：建立最近上下文并写 local（标量 + 复杂值）
	_trigger = MinimalTrigger.new()
	_trigger.name = "TestTrigger"
	add_child(_trigger)
	var tec = _trigger._create_execution_context(_trigger)
	var tvc = tec.get("_variable_context")
	tvc.set_variable("hp", 100, "local")
	tvc.set_variable("dir", Vector2(1, 0), "local")

	# Runner：沿用既有 stub 形态
	_stub_runner = Runner.new()
	_stub_runner.name = "StubRunner"
	add_child(_stub_runner)
	var ec = ExecutionContext.new()
	var vc = ec.get("_variable_context")
	vc.set_variable("hp", 100, "local")
	_stub_runner.current_execution_context = ec
	_stub_runner.current_execution_context_at_ms = Time.get_ticks_msec()


func _await_connected(timeout_sec: float = 5.0) -> bool:
	var acc := 0.0
	while acc < timeout_sec:
		if _server.is_game_connected():
			return true
		await get_tree().create_timer(0.1).timeout
		acc += 0.1
	return false


## v3 推送：containers/units/global 三块，经真实 socket
func _test_push_payload_reaches_cache() -> void:
	print("\n--- 推送 v3：containers/units/global（全链路）---")
	var mgr := GlobalVariableManager.get_instance()
	mgr.add_variable("score", BaseVariable.create("score", 7, BaseVariable.VariableScope.GLOBAL))

	await get_tree().create_timer(1.3).timeout

	var cached: Dictionary = _server.get_cached_vars()
	var containers: Array = cached.get("containers", [])
	var units: Array = cached.get("units", [])
	_check(containers.size() == 1, "容器条目恰 1（got %d）" % containers.size())
	if containers.size() == 1:
		var c: Dictionary = containers[0]
		_check(int(c.get("id", 0)) == _container.get_instance_id(), "容器 id 为实例 id")
		_check(c.get("path", "") == "/TestContainer", "容器 path 相对场景根（/TestContainer）")
		_check(c.get("scope_id", "") == "test_scope", "scope_id 送达")
		var cvars: Dictionary = c.get("vars", {})
		_check(cvars.get("lives", null) == 3, "容器标量 lives=3 送达")
		var anchor = cvars.get("anchor", null)
		_check(anchor is Dictionary and anchor.get("ty", "") == "Vector2" \
			and anchor.get("__complex", "") == "(1.0, 2.0)", "容器复杂值 __complex 编码（Godot 4 str(Vector2) 带 .0）")
	_check(units.size() == 2, "units 恰 2（Trigger + Runner，got %d）" % units.size())
	var kinds := {}
	for u in units:
		kinds[u.get("kind", "")] = u
		_check(int(u.get("ago_ms", -1)) >= 0, "ago_ms 非负")
	_check(kinds.has("trigger") and kinds.has("runner"), "units 含 trigger 与 runner 两种 kind")
	if kinds.has("trigger"):
		var tlocal: Dictionary = kinds["trigger"].get("local", {})
		_check(tlocal.get("hp", null) == 100, "trigger local hp=100 送达")
		var dir = tlocal.get("dir", null)
		_check(dir is Dictionary and dir.get("ty", "") == "Vector2", "trigger local 复杂值 __complex 编码")
		_check(kinds["trigger"].get("path", "").ends_with("TestTrigger"), "unit path 含节点名")
	if kinds.has("runner"):
		_check(kinds["runner"].get("local", {}).get("hp", null) == 100, "runner local 送达")
	_check(_server.get_cached_global().get("score", null) == 7, "global 快照送达")
	# 降级：字段缺失安全为空
	_server._handle_message({"t": "vars", "proto": 3})
	_check(_server.get_cached_vars().get("containers", [1]).is_empty(), "缺字段降级为空集")


## 全链路：container / unit / global 三 target（真实 socket）
func _test_set_var_targets_full_path() -> void:
	print("\n--- set_var 三 target 全链路（int 收窄）---")
	# container
	var ok_c: bool = _server.send_set_var("container", _container.get_instance_id(), "lives", 9.0)
	# unit（trigger 的最近上下文）
	var ok_u: bool = _server.send_set_var("unit", _trigger.get_instance_id(), "hp", 55.0)
	# global
	var ok_g: bool = _server.send_set_var("global", 0, "score", 11.0)
	_check(ok_c and ok_u and ok_g, "三 target 广播均返回 true")

	await get_tree().create_timer(1.3).timeout

	var lives = _container.get_variable("lives", null)
	_check(lives == 9 and typeof(lives) == TYPE_INT, "容器 lives 写入 9 且收窄为 int")
	var tvc = _trigger.current_execution_context.get("_variable_context")
	_check(tvc.get_variable("hp", null, "local") == 55, "unit hp 写入 55")
	_check(typeof(tvc.get_variable("hp", null, "local")) == TYPE_INT, "unit int 收窄")
	var v = GlobalVariableManager.get_instance().get_variable("score")
	_check(v != null and v.value == 11 and typeof(v.value) == TYPE_INT, "global 值 11 且 int")


## 单元级：容错与非标量闸门
func _test_apply_set_var_guards() -> void:
	print("\n--- _apply_set_var 容错与闸门 ---")
	# 无上下文的组件：静默
	var cold := MinimalTrigger.new()
	add_child(cold)
	_client._apply_set_var({"t": "set_var", "target": "unit", "id": cold.get_instance_id(), "name": "hp", "value": 1.0})
	_check(cold.current_execution_context == null, "未触发组件静默忽略")
	cold.queue_free()

	# 伪造 id：静默不崩且无副作用
	_client._apply_set_var({"t": "set_var", "target": "container", "id": 99999999, "name": "x", "value": 1.0})
	_check(_container.get_variable("lives", null) == 9, "伪造 id 后容器未受影响")

	# 非标量槽位闸门：容器 anchor 为 Vector2，写回跳过
	_client._apply_set_var({"t": "set_var", "target": "container", "id": _container.get_instance_id(), "name": "anchor", "value": "5"})
	_check(_container.get_variable("anchor", null) == Vector2(1, 2), "容器非标量槽位写回跳过")

	# unit local 非标量闸门
	_client._apply_set_var({"t": "set_var", "target": "unit", "id": _trigger.get_instance_id(), "name": "dir", "value": "9"})
	_check(_trigger.current_execution_context.get("_variable_context").get_variable("dir", null, "local") == Vector2(1, 0), "unit 非标量槽位写回跳过")

	# global 不存在不创建
	_client._apply_set_var({"t": "set_var", "target": "global", "id": 0, "name": "no_such_var", "value": 1.0})
	_check(GlobalVariableManager.get_instance().get_variable("no_such_var") == null, "global 不存在不创建")


## 恒推：移除单元（Trigger/Runner）后仍推送 global（空 units 快照不断流）
func _test_push_always_without_units() -> void:
	print("\n--- 恒推空 units：global 仍送达 ---")
	remove_child(_stub_runner)  # 保留引用，_cleanup 仍可 free
	remove_child(_trigger)      # 同上（v3：Trigger 也是上报单元）
	GlobalVariableManager.get_instance().set_variable_value_thread_safe("score", 33)
	await get_tree().create_timer(1.3).timeout
	_check(_server.get_cached_global().get("score") == 33, "无活跃单元仍恒推 global（score=33）")
	_check(_server.get_cached_vars().get("units", [1]).is_empty(), "无单元时 units 为空")


func _cleanup() -> void:
	if _stub_runner:
		_stub_runner.queue_free()
	if _trigger:
		_trigger.queue_free()
	if _container:
		_container.queue_free()
	if _client:
		_client.queue_free()
	if _server:
		_server.queue_free()


## 最小 BaseTrigger 测试子类：抽象方法空实现，仅用 _create_execution_context
class MinimalTrigger extends BaseTrigger:
	func get_event_count() -> int:
		return 0

	func get_event_at(_index: int) -> BaseEvent:
		return null

	func get_runtime_event_instance_at(_index: int) -> RuntimeEventInstance:
		return null

	func get_action_runner_instance_at(_index: int) -> RuntimeActionRunnerInstance:
		return null

	func _on_pool_reset() -> void:
		pass
