@tool
extends Node

## 运行时变量 TCP 桥（双模式 Autoload）
##
## 编辑器侧（TCPServer 模式）：
##   listen 127.0.0.1:24563，接受运行游戏推送的变量快照，缓存到 _cached
##
## 运行游戏侧（TCP 客户端模式）：
##   连接 127.0.0.1:24563，每 0.5s 从 root 全树收集 ScopeVariableContainer 容器
##   与 BaseTrigger/Runner 单元（宿主直报最近执行上下文的 local）的变量快照，
##   序列化为 JSON line 推送
##
## 协议：TCP 流 + JSON line（\n 分隔），推送协议版本 proto=3
##   运行游戏→编辑器: {"t":"vars","proto":3,"containers":[{"id":123,"path":"/x","scope_id":"s","vars":{...}},...],"units":[{"id":456,"path":"/x","kind":"trigger|multi|runner","ago_ms":5,"local":{...}},...],"global":{name:value,...}}
##     每 0.5s 恒推（无单元也推 global 与空集，清编辑器缓存）；非标量值编码为
##     {"__complex":"str(v)≤200字符","ty":"Vector2"} 显式只读包装（编辑器据此区分真 String 与复杂值）
##   运行游戏←编辑器: {"t":"set_var","proto":3,"target":"container|unit|global","id":123,"name":"hp","value":1}（反向写回）

const BRIDGE_PORT := 24563
const PUSH_INTERVAL := 0.5

var _port: int = BRIDGE_PORT  # 测试注入用（生产路径恒为 BRIDGE_PORT）

var _server: TCPServer = null
var _connections: Array[StreamPeerTCP] = []
var _client: StreamPeerTCP = null

## 编辑器侧：运行游戏推送的变量快照缓存（v3 双键结构）
## {"containers": [容器条目...], "units": [单元条目...]}
var _cached: Dictionary = {}
var _cached_global: Dictionary = {}  # 游戏侧 global 标量快照

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
	_cached_global.clear()


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
	_teardown_server()
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
	if _connections.is_empty():
		_cached.clear()
		_cached_global.clear()


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


## v3 值编码：标量原样；非标量显式只读包装（编辑器据此区分真 String 与复杂值）
static func _encode_var(v: Variant) -> Variant:
	if typeof(v) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
		return v
	var s := str(v)
	if s.length() > 200:
		s = s.substr(0, 197) + "..."
	return {"__complex": s, "ty": type_string(typeof(v))}


## 显示用路径：current_scene 相对（场景根为 "/"），子树外回退绝对路径；不用于定位
static func _node_path_str(n: Node) -> String:
	var scene: Node = n.get_tree().current_scene
	if scene != null and (n == scene or scene.is_ancestor_of(n)):
		if n == scene:
			return "/"
		return "/" + str(scene.get_path_to(n))
	return str(n.get_path())


func _update_cache(payload: Dictionary) -> void:
	_cached = {
		"containers": payload.get("containers", []),
		"units": payload.get("units", [])
	}
	_cached_global = payload.get("global", {}).duplicate()


## vars 按 t 分发（而非 has 键）：字段缺失的降级消息也要触达 _update_cache 清空缓存（.get 缺省空集）
func _handle_message(msg: Dictionary) -> void:
	if msg.get("t", "") == "vars":
		_update_cache(msg)
	elif msg.get("t", "") == "set_var":
		_apply_set_var(msg)


## 公开 API：获取缓存的运行时变量（编辑器侧）
## v3 结构：{"containers": [容器条目...], "units": [单元条目...]}
func get_cached_vars() -> Dictionary:
	return _cached


## 编辑器侧：游戏侧 global 标量快照
func get_cached_global() -> Dictionary:
	return _cached_global


## 编辑器侧：是否有运行游戏连接
func is_game_connected() -> bool:
	return not _connections.is_empty()


## 编辑器侧：广播写回（fire-and-forget；无连接返回 false）
## 拥塞丢弃由 0.5s 推送回显兜底（spec §3.4）
func send_set_var(target: String, target_id: int, name: String, value: Variant) -> bool:
	if _connections.is_empty():
		return false
	# 只序列化/编码一次，size 取自同一份
	var payload := (JSON.stringify({
		"t": "set_var",
		"proto": 3,
		"target": target,
		"id": target_id,
		"name": name,
		"value": value
	}) + "\n").to_utf8_buffer()
	var any_ok := false
	for conn in _connections:
		var result: Array = conn.put_partial_data(payload)
		# put_partial_data 返回 [Error, 实写字节数]（Godot 4.4+）
		var sent: int = result[1] if result.size() >= 2 else 0
		if result[0] != OK or sent < payload.size():
			push_warning("FuseRuntimeBridge: set_var 短写(%d/%d)，断开该连接等待重连" % [sent, payload.size()])
			conn.disconnect_from_host()
			continue
		any_ok = true
	return any_ok


# ============================================================
# 运行游戏侧：TCP 客户端
# ============================================================

func _connect_client() -> void:
	if _client:
		_client.disconnect_from_host()
		_client = null
	_client = StreamPeerTCP.new()
	_client.connect_to_host("127.0.0.1", _port)


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
	_read_json_lines(_client)  # 反向：接收编辑器 set_var
	_push_snapshot()


func _push_snapshot() -> void:
	var collected := _collect_units_and_containers()
	var msg := JSON.stringify({
		"t": "vars",
		"proto": 3,
		"containers": collected["containers"],
		"units": collected["units"],
		"global": _collect_global_flat()
	}) + "\n"
	# put_partial_data 非阻塞（缓冲满发部分即返回），避免 put_data 阻塞主线程
	# 丢弃未发送部分（下个 snapshot 覆盖，变量快照实时性优先于完整性）
	_client.put_partial_data(msg.to_utf8_buffer())


## 游戏侧 global 标量快照（{name: value}，复杂类型不入协议）
func _collect_global_flat() -> Dictionary:
	var flat := {}
	var snapshot := GlobalVariableManager.get_instance().get_all_variables_snapshot()
	for vname in snapshot:
		var val = snapshot[vname].get("value")
		if typeof(val) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
			flat[vname] = val
	return flat


## v3 收集：root 全树单次递归，三判归类（BaseTrigger / Runner / ScopeVariableContainer）
## root 扫描覆盖附加场景；游戏进程 autoload 内无 Fuse 组件，等效全量
func _collect_units_and_containers() -> Dictionary:
	var containers: Array = []
	var units: Array = []
	_collect_from_node(get_tree().root, containers, units)
	return {"containers": containers, "units": units}


func _collect_from_node(node: Node, containers: Array, units: Array) -> void:
	for child in node.get_children():
		if child is ScopeVariableContainer:
			containers.append(_encode_container(child))
		if child is BaseTrigger or child is Runner:
			var unit := _encode_unit(child)
			if not unit.is_empty():
				units.append(unit)
		_collect_from_node(child, containers, units)


func _encode_container(c: ScopeVariableContainer) -> Dictionary:
	var vars_enc := {}
	for vname in c.get_variable_names():
		vars_enc[vname] = _encode_var(c.get_variable(vname))
	return {
		"id": c.get_instance_id(),
		"path": _node_path_str(c),
		"scope_id": str(c.scope_id),
		"vars": vars_enc
	}


## 无有效最近上下文的组件返回空 dict（不上报）
func _encode_unit(unit: Node) -> Dictionary:
	var ec = unit.get("current_execution_context")
	if ec == null or not is_instance_valid(ec):
		return {}
	var vc = ec.get("_variable_context")
	if vc == null:
		return {}
	var kind := "runner"
	if unit is MultiEventTrigger:
		kind = "multi"
	elif unit is BaseTrigger:
		kind = "trigger"
	var snap: Dictionary = vc.get_all_local_variables_snapshot()
	var local_enc := {}
	for vname in snap:
		local_enc[vname] = _encode_var(snap[vname])
	return {
		"id": unit.get_instance_id(),
		"path": _node_path_str(unit),
		"kind": kind,
		# Object.get 无第二参（双参缺省是 Dictionary.get 的签名）；Task 1 后两类组件均已有该属性
		"ago_ms": int(Time.get_ticks_msec() - int(unit.get("current_execution_context_at_ms"))),
		"local": local_enc
	}


## 游戏侧：应用编辑器写回（target 失效静默——失败由推送回显兜底）
func _apply_set_var(msg: Dictionary) -> void:
	var target: String = msg.get("target", "")
	var vname: String = msg.get("name", "")
	var value = msg.get("value", null)
	if vname.is_empty() or value == null:
		return
	var rid := int(msg.get("id", 0))
	match target:
		"global":
			var mgr := GlobalVariableManager.get_instance()
			var existing_var = mgr.get_variable(vname)
			if existing_var == null:
				return  # 不存在不创建
			# 非标量槽位不可经桥覆盖：否则标量写入会静默销毁原值
			if not _is_bridge_scalar(existing_var.value):
				return
			mgr.set_variable_value_thread_safe(vname, _narrow_scalar(value, existing_var.value))
		"container":
			if rid == 0:
				return
			var node = _find_node_by_id(rid, "ScopeVariableContainer")
			if node == null:
				return
			var existing = node.get_variable(vname, null)
			if existing != null and not _is_bridge_scalar(existing):
				return
			node.set_variable(vname, _narrow_scalar(value, existing))
		"unit":
			if rid == 0:
				return
			var node = _find_node_by_id(rid, "")
			if node == null:
				return
			var ec = node.get("current_execution_context")
			if ec == null or not is_instance_valid(ec):
				return
			var vc = ec.get("_variable_context")
			if vc == null:
				return
			var existing = vc.get_variable(vname, null, "local")
			# 协议层 __complex 编码已挡住编辑器侧误发，此闸门为手造消息的纵深防御
			if existing != null and not _is_bridge_scalar(existing):
				return
			vc.set_variable(vname, _narrow_scalar(value, existing), "local")


## 桥协议仅承载标量（JSON 可无损表达的类型）
static func _is_bridge_scalar(v: Variant) -> bool:
	return typeof(v) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]


## 按实例 id 场景扫描定位（不用 instance_from_id：无效 id 会刷引擎 ERROR）
## expected: "" = BaseTrigger/Runner 任一；"ScopeVariableContainer" = 容器
func _find_node_by_id(rid: int, expected: String) -> Node:
	var found: Node = _find_node_recursive(get_tree().root, rid)
	if found == null:
		return null
	if expected.is_empty():
		return found if (found is BaseTrigger or found is Runner) else null
	if expected == "ScopeVariableContainer":
		return found if found is ScopeVariableContainer else null
	return null


func _find_node_recursive(node: Node, rid: int) -> Node:
	if node.get_instance_id() == rid:
		return node
	for child in node.get_children():
		var hit: Node = _find_node_recursive(child, rid)
		if hit != null:
			return hit
	return null


## JSON 解析后数字一律为 float：按目标变量现有类型收窄（仅 int 需要处理）
## 目标不存在（auto_create 新建）时原样写入——float 化为已知限制（spec §11）
static func _narrow_scalar(value: Variant, existing: Variant) -> Variant:
	if existing != null and typeof(existing) == TYPE_INT and typeof(value) == TYPE_FLOAT:
		return int(value)
	return value
