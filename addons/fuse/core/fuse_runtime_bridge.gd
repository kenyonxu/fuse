@tool
extends Node

## 运行时变量 TCP 桥（双模式 Autoload）
##
## 编辑器侧（TCPServer 模式）：
##   listen 127.0.0.1:24563，接受运行游戏推送的变量快照，缓存到 _cached
##
## 运行游戏侧（TCP 客户端模式）：
##   连接 127.0.0.1:24563，每 0.5s 收集当前场景下所有 Runner 的 local/scope
##   变量快照，序列化为 JSON line 推送
##
## 协议：TCP 流 + JSON line（\n 分隔）
##   运行游戏→编辑器: {"t":"vars","runners":[{"name":"Runner1","local":{...},"scope":{...}},...]}

const BRIDGE_PORT := 24563
const PUSH_INTERVAL := 0.5

var _port: int = BRIDGE_PORT  # 测试注入用（生产路径恒为 BRIDGE_PORT）

var _server: TCPServer = null
var _connections: Array[StreamPeerTCP] = []
var _client: StreamPeerTCP = null

## 编辑器侧：运行游戏推送的变量快照缓存
## {runner_name: {"local": {var_name: value, ...}, "scope": {var_name: value, ...}}}
var _cached: Dictionary = {}

var _push_acc: float = 0.0

# TCP 读缓冲（处理粘包/半包），每条连接独立
var _read_buffers: Dictionary = {}  # conn.get_instance_id() → String


# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# 已显式注入模式（测试）则尊重现状，不自动分叉
	if _server != null or _client != null:
		return
	if Engine.is_editor_hint():
		start_server()
	else:
		start_client()


func _exit_tree() -> void:
	_teardown_server()
	for conn in _connections:
		conn.disconnect_from_host()
	_connections.clear()
	_read_buffers.clear()
	_teardown_client()
	_cached.clear()


func _process(delta: float) -> void:
	# 按实际状态分发（而非 is_editor_hint）：允许测试同进程注入双模式
	if _server != null:
		_server_poll()
	elif _client != null:
		_client_poll(delta)


# ============================================================
# 编辑器侧：TCPServer
# ============================================================

## 编辑器侧：启动 TCPServer（测试可注入端口）
func start_server(port: int = BRIDGE_PORT) -> void:
	_teardown_client()
	_port = port
	_server = TCPServer.new()
	var err := _server.listen(_port, "127.0.0.1")
	if err != OK:
		push_warning("FuseRuntimeBridge: 监听 %d 失败(%d)，运行时变量桥不可用" % [_port, err])
		_server = null


func is_server_active() -> bool:
	return _server != null and _server.is_listening()


## 运行游戏侧：连接编辑器（测试可注入端口）
func start_client(port: int = BRIDGE_PORT) -> void:
	_teardown_server()
	_port = port
	_connect_client()


func _teardown_server() -> void:
	if _server:
		_server.stop()
	_server = null


func _teardown_client() -> void:
	if _client:
		var cid := _client.get_instance_id()
		_client.disconnect_from_host()
		_client = null
		_read_buffers.erase(cid)


func _server_poll() -> void:
	# 接受新连接
	while _server and _server.is_connection_available():
		var conn := _server.take_connection()
		_connections.append(conn)

	# 处理现有连接
	var i := 0
	while i < _connections.size():
		var conn: StreamPeerTCP = _connections[i]
		conn.poll()  # 更新状态（关键：poll 后 get_status 准确，断开连接能被清除，避免 !is_open 报错刷屏卡死）
		var st := conn.get_status()
		if st == StreamPeerTCP.STATUS_NONE or st == StreamPeerTCP.STATUS_ERROR:
			var cid := conn.get_instance_id()
			conn.disconnect_from_host()
			_read_buffers.erase(cid)
			_connections.remove_at(i)
			continue
		_read_json_lines(conn)
		i += 1

	# 所有连接断开 → 清缓存（运行游戏已退出）
	if _connections.is_empty() and not _cached.is_empty():
		_cached.clear()


func _read_json_lines(conn: StreamPeerTCP) -> void:
	conn.poll()
	var avail := conn.get_available_bytes()
	if avail <= 0:
		return
	var data := conn.get_utf8_string(avail)
	var cid := conn.get_instance_id()
	if not _read_buffers.has(cid):
		_read_buffers[cid] = ""
	var result: Dictionary = extract_json_lines(_read_buffers[cid] + data)
	_read_buffers[cid] = result["rest"]
	for msg in result["lines"]:
		_handle_message(msg)


## 纯函数：从缓冲提取完整 JSON 行（粘包/半包）；返回 {lines: Array[Dictionary], rest: String}
static func extract_json_lines(buffer: String) -> Dictionary:
	var lines: Array[Dictionary] = []
	var rest := buffer
	var idx: int = rest.find("\n")
	while idx >= 0:
		var line := rest.left(idx).strip_edges()
		rest = rest.substr(idx + 1)
		if not line.is_empty():
			var parsed = JSON.parse_string(line)
			if parsed is Dictionary:
				lines.append(parsed)
		idx = rest.find("\n")
	return {"lines": lines, "rest": rest}


## 消息分发（Task 2/3 扩展：vars / set_var）
func _handle_message(msg: Dictionary) -> void:
	if msg.has("runners"):
		_update_cache(msg["runners"])


func _update_cache(runners: Array) -> void:
	_cached.clear()
	for r in runners:
		if not r is Dictionary:
			continue
		var rname: String = r.get("name", "?")
		var local_data: Dictionary = r.get("local", {})
		var scope_data: Dictionary = r.get("scope", {})
		_cached[rname] = {"local": local_data.duplicate(), "scope": scope_data.duplicate()}


## 公开 API：获取缓存的运行时变量（编辑器侧）
func get_cached_vars() -> Dictionary:
	return _cached


## 编辑器侧：是否有运行游戏连接
func is_game_connected() -> bool:
	return not _connections.is_empty()


# ============================================================
# 运行游戏侧：TCP 客户端
# ============================================================

func _connect_client() -> void:
	if _client:
		_client.disconnect_from_host()
		_client = null
	_client = StreamPeerTCP.new()
	_client.connect_to_host("127.0.0.1", _port)


## 运行游戏侧：向编辑器发送反向 set_var 请求（Task 3 全链路验证）
## 返回 false 表示当前无已连接的通道（未连接/连接未就绪）
func send_set_var(scope: String, runner_index: int, var_name: String, value: Variant) -> bool:
	if _client == null or _client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return false
	var msg := JSON.stringify({"t": "set_var", "scope": scope, "runner": runner_index, "name": var_name, "value": value}) + "\n"
	_client.put_partial_data(msg.to_utf8_buffer())
	return true


func _client_poll(delta: float) -> void:
	# 节流：poll + push 都按 PUSH_INTERVAL（不每帧 poll，避免阻塞主线程）
	_push_acc += delta
	if _push_acc < PUSH_INTERVAL:
		return
	_push_acc = 0.0
	_client.poll()  # 推进 socket（节流，0.5s 一次，避免每帧阻塞主线程）
	var st := _client.get_status()
	if st == StreamPeerTCP.STATUS_NONE or st == StreamPeerTCP.STATUS_ERROR:
		_connect_client()  # 重连
		return
	if st != StreamPeerTCP.STATUS_CONNECTED:
		return
	_push_snapshot()


func _push_snapshot() -> void:
	var runners := _collect_runners()
	if runners.is_empty():
		return
	var msg := JSON.stringify({"t": "vars", "runners": runners}) + "\n"
	# put_partial_data 非阻塞（缓冲满发部分即返回），避免 put_data 阻塞主线程
	# 丢弃未发送部分（下个 snapshot 覆盖，变量快照实时性优先于完整性）
	_client.put_partial_data(msg.to_utf8_buffer())


func _collect_runners() -> Array:
	var result: Array = []
	var scene = get_tree().current_scene
	if scene == null:
		return result

	for runner in scene.find_children("*", "Runner", true, false):
		var ec = runner.get("current_execution_context")
		if ec == null or not is_instance_valid(ec):
			continue
		var vc = ec.get("_variable_context")
		if vc == null:
			continue
		result.append({
			"name": runner.name,
			"local": vc.get_all_local_variables_snapshot(),
			"scope": vc.get_all_scope_variables_snapshot()
		})
	return result
