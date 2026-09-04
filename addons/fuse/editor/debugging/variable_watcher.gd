# addons/fuse/editor/debugging/variable_watcher.gd
@tool
class_name FuseVariableWatcher
extends Control

## 变量监视器 — Bottom Dock（v3 数据 + Tree 展示层）
## 数据层：桥读取/行生成/编辑分发（纯函数，测试覆盖）
## 展示层：FuseVariableWatcherTree + 选中展开折线图 + 空态

const FuseLocalizationClass = preload("res://addons/fuse/localization/fuse_localization.gd")

# 7b: 历史记录
const HISTORY_MAX := 120  # 60s / 0.5s
var _history: Dictionary = {}   # var_key (scope+name) → Array[float]

# 7e: 运行时编辑可编辑类型（JSON 标量）
const EDITABLE_TYPES := ["int", "float", "bool", "String", "string"]

# —— UI 成员 ——
var _search_input: LineEdit
var _status_label: Label
var _tree: FuseVariableWatcherTree
var _split: VSplitContainer
var _graph_panel: VBoxContainer
var _graph: HistoryGraph
var _graph_title: Label
var _empty_overlay: CenterContainer
var _edit_line: LineEdit = null   # 编辑覆盖层

var _selected_key := ""
var _timer: Timer


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(400, 150)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	# 顶栏：搜索 + 状态摘要（单行）
	var toolbar := HBoxContainer.new()
	vbox.add_child(toolbar)
	_search_input = LineEdit.new()
	_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_input.max_length = 64
	_search_input.placeholder_text = FuseLocalizationClass.translate("FUSE_UI_WATCHER_SEARCH_PLACEHOLDER")
	toolbar.add_child(_search_input)
	_status_label = Label.new()
	toolbar.add_child(_status_label)

	# 中部：Tree（上） + 图区（下，选中展开）
	_split = VSplitContainer.new()
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_split)
	_tree = FuseVariableWatcherTree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.add_child(_tree)
	_graph_panel = VBoxContainer.new()
	_graph_panel.visible = false
	_graph_panel.custom_minimum_size.y = 100
	_split.add_child(_graph_panel)
	var head := HBoxContainer.new()
	_graph_panel.add_child(head)
	_graph_title = Label.new()
	head.add_child(_graph_title)
	var close := Button.new()
	close.flat = true
	close.text = "✕"
	close.pressed.connect(_close_graph)
	head.add_child(close)
	_graph = HistoryGraph.new()
	_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph_panel.add_child(_graph)

	# 空态叠层
	_empty_overlay = CenterContainer.new()
	_empty_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_empty_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var empty_label := Label.new()
	empty_label.text = FuseLocalizationClass.translate("FUSE_UI_WATCHER_WAIT_FOR_GAME")
	empty_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	_empty_overlay.add_child(empty_label)
	add_child(_empty_overlay)

	# 信号接线
	_search_input.text_changed.connect(_on_search_changed)
	_tree.variable_selected.connect(_on_variable_selected)
	_tree.variable_activated.connect(_on_variable_activated)

	_timer = Timer.new()
	_timer.wait_time = 0.5
	_timer.autostart = true
	_timer.timeout.connect(_refresh)
	add_child(_timer)


func _enter_tree() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# ============================================================
# 刷新（主循环）
# ============================================================

func _refresh() -> void:
	var filter_text := _search_input.text
	var bridge = _get_bridge()
	var connected: bool = bridge != null \
			and bridge.has_method("is_game_connected") and bridge.is_game_connected()

	var cached: Dictionary = bridge.get_cached_vars() if bridge != null \
			and bridge.has_method("get_cached_vars") else {}
	var rows: Dictionary = _rows_from_cached(cached)
	var scene_name := str(cached.get("scene", ""))

	# global 行：桥活跃 → 游戏侧；否则编辑器侧定义（v3 语义照抄现文件）
	var global_rows: Array[Dictionary] = []
	if connected:
		var cg: Dictionary = bridge.get_cached_global()
		for vname in cg:
			global_rows.append(_make_var_row(vname, cg[vname],
				{"target": "global", "id": 0, "group_key": "", "group_path": ""}))
	else:
		var svc := GlobalVariableService.new()
		var globals: Dictionary = svc.get_all_global_variables_info()
		for vname in globals:
			var info = globals[vname]
			global_rows.append(_make_var_row(vname, info.get("value"),
				{"target": "global", "id": 0, "group_key": "", "group_path": ""}))

	# 历史记录（键方案不变；编辑覆盖层独立于树行，刷新不干扰输入——此处仍记录真实值）
	for row in rows["local_rows"] + rows["scope_rows"]:
		if bool(row.get("is_complex", false)):
			continue
		_record_history(_history_key(row), row["value"], row["type"])
	for row in global_rows:
		if not bool(row.get("is_complex", false)):
			_record_history(_history_key(row), row["value"], row["type"])

	rows["global_count"] = global_rows.size()
	var summary: Dictionary = _tree.apply_data(rows, scene_name, filter_text)
	# apply_data 之后必须每轮紧跟 apply_global（Tree 的 GLOBAL 根依赖此契约，勿调序）
	_tree.apply_global(global_rows, filter_text)

	# 摘要 scenes/hosts 为过滤后计数（过滤激活时状态栏数字随之收缩——接受的行为）
	_status_label.text = "场景:%d · 宿主:%d · Global:%d" % [
		summary.get("scenes", 0), summary.get("hosts", 0), global_rows.size()]
	_empty_overlay.visible = not connected \
			and rows["local_rows"].is_empty() and rows["scope_rows"].is_empty() and global_rows.is_empty()


# ============================================================
# 选中 / 编辑 / 图区回调
# ============================================================

func _on_search_changed(_t: String) -> void:
	_refresh()  # 过滤集变化走同一条增量 diff 路径


func _on_variable_selected(row: Dictionary, selected: bool) -> void:
	if not selected or row.is_empty():
		_close_graph()
		return
	_selected_key = _history_key(row)  # 与 _record_history 同键方案，折线图直接取数
	var path_txt := str(row.get("group_path", ""))
	_graph_title.text = (path_txt + "/" if path_txt != "" else "") + str(row["name"])
	_graph_panel.visible = true
	_update_graph()


func _on_variable_activated(row: Dictionary) -> void:
	if not _is_row_editable(row):
		return
	if _edit_line != null:
		return
	_edit_line = LineEdit.new()
	add_child(_edit_line)
	var rect := _tree.value_cell_screen_rect()
	_edit_line.position = rect.position
	_edit_line.size = rect.size
	_edit_line.text = row.get("value", "")
	_edit_line.select_all()
	_edit_line.text_submitted.connect(func(t): _finish_edit(t, row))
	_edit_line.focus_exited.connect(func():
		if is_instance_valid(_edit_line):
			_finish_edit(_edit_line.text, row))
	_edit_line.grab_focus()


## 完成编辑：按数据来源写回 + 清理编辑覆盖层
## 类型转换失败（coerced == null）不写回也不警告——那是输入问题不是连接问题
## 分发逻辑与旧版逐字一致（coerce → container/unit/global 三路 → 失败恢复警告）；
## 差异仅两处：1) 参数 panel 换 row；2) 末尾删除 _restore_label(panel, display)——
## 编辑覆盖层独立于树行，无需冻结刷新，提交后下方 _refresh 即回显真实值
func _finish_edit(text: String, row: Dictionary) -> void:
	var type_str: String = row.get("type", "")
	var coerced = _coerce_value(text, type_str)

	if coerced != null:
		var bridge = _get_bridge()
		var sent := true
		var target: String = row.get("target", "")
		if target == "global":
			if bridge != null and bridge.has_method("is_game_connected") and bridge.is_game_connected():
				sent = bridge.send_set_var("global", 0, row["name"], coerced)
			else:
				_write_back_global(row["name"], coerced)
		elif target in ["container", "unit"]:
			if bridge != null and bridge.has_method("send_set_var"):
				sent = bridge.send_set_var(target, int(row.get("id", 0)), row["name"], coerced)
			else:
				sent = false
		if not sent:
			push_warning(FuseLocalizationClass.translate("FUSE_UI_WATCHER_EDIT_NO_CONNECTION"))

	if _edit_line != null and is_instance_valid(_edit_line):
		_edit_line.queue_free()
		_edit_line = null
	_refresh()


func _close_graph() -> void:
	_graph_panel.visible = false
	_selected_key = ""


func _update_graph() -> void:
	if _selected_key.is_empty() or not _history.has(_selected_key):
		_graph.set_points([] as Array[float])
		return
	_graph.set_points(_history[_selected_key])


# ============================================================
# 7a: 双击编辑变量值（数据层：门控 / 写回 / 类型转换）
# ============================================================

## v3 可编辑：非 __complex、JSON 标量类型、target 有效（container/unit/global）
func _is_row_editable(data: Dictionary) -> bool:
	if data.get("is_note", false) or data.get("is_static", false):
		return false
	if data.get("is_complex", false):
		return false
	if not str(data.get("type", "")) in EDITABLE_TYPES:
		return false
	return str(data.get("target", "")) in ["container", "unit", "global"]


## 全局变量写回（编辑器侧定义）：改值优先保留元数据，不存在才新建
func _write_back_global(name: String, value: Variant) -> void:
	var mgr := GlobalVariableManager.get_instance()
	if mgr.set_variable_value_thread_safe(name, value):
		return
	var var_obj = BaseVariable.create(name, value, BaseVariable.VariableScope.GLOBAL)
	if var_obj == null:
		push_warning(FuseLocalizationClass.translate_format(
			"FUSE_UI_WATCHER_GLOBAL_CREATE_FAILED", {"name": name}))
		return
	mgr.add_variable(name, var_obj)


## 类型转换：String → 目标类型
## 返回 null 表示转换失败（调用方应中止写回）
func _coerce_value(text: String, type_str: String):
	match type_str:
		"int":
			if not text.is_valid_int():
				return null
			return text.to_int()
		"float":
			if not text.is_valid_float():
				return null
			return text.to_float()
		"bool":
			return text.strip_edges().to_lower() in ["true", "1", "是", "yes"]
		"String", "string":
			return text
		_:
			# 未知类型，原样返回（最佳努力）
			return text


# ============================================================
# 7b: 历史记录
# ============================================================

func _record_history(var_key: String, value, type_str: String) -> void:
	if not type_str in ["int", "float"]:
		return
	if not _history.has(var_key):
		var arr: Array[float] = []
		_history[var_key] = arr
	_history[var_key].append(float(value))
	if _history[var_key].size() > HISTORY_MAX:
		_history[var_key].pop_front()


## 历史记录键 / 行选中 var_key 共用 scheme：
## local:<unit_path>/<名>、scope:<container_path>/<名>、global/<名>
## 两端（_record_history 与 _make_data_row 选中）必须同键，否则折线图静默失效
func _history_key(row: Dictionary) -> String:
	var target: String = row.get("target", "")
	if target == "global":
		return "global/%s" % row["name"]
	var prefix := "local" if target == "unit" else "scope"
	return "%s:%s/%s" % [prefix, row.get("group_path", ""), row["name"]]


# ============================================================
# 7d: 运行时变量收集（_refresh 复用）
# ============================================================

## Autoload 桥安全访问（未注册时返回 null）
func _get_bridge() -> Node:
	return get_tree().root.get_node_or_null("FuseRuntimeBridge")


func _collect_runtime_variables() -> Dictionary:
	## 从 FuseRuntimeBridge 读运行游戏推送的变量
	## 注意：早退路径也必须返回类型化 Array[Dictionary]——_refresh 以类型化变量接收，
	## 无类型数组会在每次轮询刷 "Trying to assign an array of type Array" 错误
	var result := {
		"local_rows": [] as Array[Dictionary],
		"scope_rows": [] as Array[Dictionary],
		"unit_groups": [] as Array[Dictionary],
		"container_groups": [] as Array[Dictionary],
		"unit_count": 0,
		"container_count": 0
	}

	var bridge = _get_bridge()
	if bridge == null or not bridge.has_method("get_cached_vars"):
		return result

	var cached: Dictionary = bridge.get_cached_vars()
	if cached.is_empty():
		return result

	return _rows_from_cached(cached)


## v3 行生成：local 按 unit 分组、scope 按 container 分组、global 由 _refresh 单独处理
func _rows_from_cached(cached: Dictionary) -> Dictionary:
	var local_rows: Array[Dictionary] = []
	var scope_rows: Array[Dictionary] = []
	var unit_groups: Array[Dictionary] = []
	var container_groups: Array[Dictionary] = []
	var result := {
		"local_rows": local_rows,
		"scope_rows": scope_rows,
		"unit_groups": unit_groups,
		"container_groups": container_groups,
		"unit_count": 0,
		"container_count": 0
	}

	for c in cached.get("containers", []):
		var cid := int(c.get("id", 0))
		var path := str(c.get("path", "?"))
		container_groups.append({
			"key": "c%d" % cid, "path": path, "scope_id": str(c.get("scope_id", ""))
		})
		result["container_count"] = int(result["container_count"]) + 1
		var vars_enc: Dictionary = c.get("vars", {})
		for vname in vars_enc:
			scope_rows.append(_make_var_row(vname, vars_enc[vname],
				{"target": "container", "id": cid, "group_key": "c%d" % cid, "group_path": path}))

	for u in cached.get("units", []):
		var uid := int(u.get("id", 0))
		var path := str(u.get("path", "?"))
		unit_groups.append({
			"key": "u%d" % uid, "path": path,
			"kind": str(u.get("kind", "?")), "ago_ms": int(u.get("ago_ms", 0))
		})
		result["unit_count"] = int(result["unit_count"]) + 1
		var local_enc: Dictionary = u.get("local", {})
		for vname in local_enc:
			local_rows.append(_make_var_row(vname, local_enc[vname],
				{"target": "unit", "id": uid, "group_key": "u%d" % uid, "group_path": path}))

	return result


## v3 行构造：__complex 编码行只读标注；类型列复杂值显示 ty
func _make_var_row(vname: String, encoded: Variant, extra: Dictionary) -> Dictionary:
	var is_complex: bool = encoded is Dictionary and encoded.has("__complex")
	var type_str := ""
	var display := ""
	if is_complex:
		type_str = str(encoded.get("ty", "?"))
		display = str(encoded.get("__complex", ""))
	else:
		display = str(encoded)
		type_str = type_string(typeof(encoded))
	return {
		"name": vname,
		"value": display,
		"type": type_str,
		"is_complex": is_complex,
		"target": extra.get("target", ""),
		"id": int(extra.get("id", 0)),
		"group_key": extra.get("group_key", ""),
		"group_path": extra.get("group_path", "")
	}


# ============================================================
# 7b: HistoryGraph 折线图组件（嵌套类）
# ============================================================

class HistoryGraph extends Control:
	var points: Array[float] = []
	var _empty_label: Label = null

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_PASS
		_empty_label = Label.new()
		_empty_label.text = FuseLocalizationClass.translate("FUSE_UI_WATCHER_NO_HISTORY")
		_empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_empty_label.add_theme_font_size_override("font_size", 14)
		_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(_empty_label)

	func set_points(new_points: Array[float]) -> void:
		points = new_points
		_empty_label.visible = points.size() < 2
		queue_redraw()

	func _draw() -> void:
		if points.size() < 2:
			return
		var max_v := points.max()
		var min_v := points.min()
		var range_v := max(0.001, max_v - min_v)
		var w := size.x
		var h := size.y
		var prev := Vector2.ZERO
		var line_color: Color = get_theme_color("accent_color", "Editor")
		if line_color == Color():
			line_color = Color(0.4, 0.8, 1.0)  # 主题取色失败的兜底

		for i in points.size():
			var x := w * i / float(points.size() - 1)
			var y: float = h - h * (points[i] - min_v) / range_v
			if i > 0:
				draw_line(prev, Vector2(x, y), line_color, 1.5)
			prev = Vector2(x, y)
