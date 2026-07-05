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
	if Engine.is_editor_hint():
		_start_server()
	else:
		_connect_client()


func _exit_tree() -> void:
	if _server:
		_server.stop()
		_server = null
	for conn in _connections:
		conn.disconnect_from_host()
	_connections.clear()
	_read_buffers.clear()
	if _client:
		_client.disconnect_from_host()
		_client = null
	_cached.clear()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if _server:
			_server_poll()
	else:
		if _client:
			_client_poll(delta)


# ============================================================
# 编辑器侧：TCPServer
# ============================================================

func _start_server() -> void:
	_server = TCPServer.new()
	var err := _server.listen(BRIDGE_PORT, "127.0.0.1")
	if err != OK:
		push_warning("FuseRuntimeBridge: 监听 %d 失败(%d)，运行时变量桥不可用" % [BRIDGE_PORT, err])


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
	_read_buffers[cid] += data
	# 逐行提取（处理粘包/半包）
	var idx: int = _read_buffers[cid].find("\n")
	while idx >= 0:
		var line: String = _read_buffers[cid].left(idx)
		_read_buffers[cid] = _read_buffers[cid].substr(idx + 1)
		line = line.strip_edges()
		if not line.is_empty():
			var parsed = JSON.parse_string(line)
			if parsed is Dictionary and parsed.has("runners"):
				_update_cache(parsed["runners"])
		idx = _read_buffers[cid].find("\n")


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


# ============================================================
# 运行游戏侧：TCP 客户端
# ============================================================

func _connect_client() -> void:
	if _client:
		_client.disconnect_from_host()
		_client = null
	_client = StreamPeerTCP.new()
	_client.connect_to_host("127.0.0.1", BRIDGE_PORT)


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
