# addons/fuse/editor/debugging/variable_watcher.gd
@tool
class_name FuseVariableWatcher
extends Control

## 变量监视器 — Bottom Dock, 0.5s 轮询, 显示 local/scope/global 变量
## Stage 7 升级: (7a)双击编辑 (7b)折线图 (7c)静态声明 (7d)快照补全

const FuseLocalizationClass = preload("res://addons/fuse/localization/fuse_localization.gd")

var _timer: Timer
var _search_input: LineEdit
var _status_label: Label
var _snapshot_btn: Button
var _scroll: ScrollContainer
var _content: VBoxContainer
var _history_graph: Control = null          # 7b: 折线图实例
var _history_graph_container: Control = null # 7b: 折线图容器

const COL_NAME := Color(0.1, 0.15, 0.3)    # 深蓝 — 变量名
const COL_VALUE := Color(0.1, 0.25, 0.15)   # 深绿 — 值
const COL_TYPE := Color(0.15, 0.15, 0.15)   # 浅黑 — 类型
const COL_HEADER := Color(0.2, 0.3, 0.5)    # 分区标题蓝

# 7b: 历史记录常数
const HISTORY_MAX := 120  # 60s / 0.5s

# 7b: 历史记录字典
var _history: Dictionary = {}   # var_key (scope+name) → Array[float]
var _selected_var_key: String = ""
var _editing: bool = false  # 7a: 编辑中标志，_refresh 跳过重建避免销毁 LineEdit

# 7c: 静态声明缓存
var _cached_static_rows: Array[Dictionary] = []
var _last_static_refresh_ms: int = 0
const STATIC_REFRESH_INTERVAL_MS := 5000

# 7e: 运行时编辑可编辑类型（JSON 标量）
const EDITABLE_TYPES := ["int", "float", "bool", "String", "string"]


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(400, 150)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	# 顶栏
	var top := HBoxContainer.new()
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(top)
	_status_label = Label.new()
	_status_label.text = FuseLocalizationClass.translate_format("FUSE_UI_WATCHER_REFRESH_INTERVAL", {"sec": 0.5})
	top.add_child(_status_label)
	top.add_spacer(true)
	_snapshot_btn = Button.new()
	_snapshot_btn.text = "📸" + FuseLocalizationClass.translate("FUSE_UI_WATCHER_SNAPSHOT")
	_snapshot_btn.pressed.connect(_on_snapshot)
	top.add_child(_snapshot_btn)

	# 搜索
	_search_input = LineEdit.new()
	_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_input.placeholder_text = FuseLocalizationClass.translate("FUSE_UI_WATCHER_SEARCH_PLACEHOLDER")
	_search_input.text_changed.connect(_refresh)
	vbox.add_child(_search_input)

	# 列标题
	vbox.add_child(_make_header_row())

	# 滚动内容区
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size.y = 100
	vbox.add_child(_scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)

	# 7b: 折线图容器（底部）
	_history_graph_container = Control.new()
	_history_graph_container.custom_minimum_size.y = 80
	_history_graph_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_graph_container.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(_history_graph_container)

	_history_graph = HistoryGraph.new()
	_history_graph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_history_graph_container.add_child(_history_graph)

	_timer = Timer.new()
	_timer.wait_time = 0.5
	_timer.autostart = true
	_timer.timeout.connect(_on_timer)
	add_child(_timer)


func _enter_tree() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _on_timer() -> void:
	_refresh()


# ============================================================
# 7a: 双击编辑变量值
# ============================================================

## 行是否可编辑：非笔记/静态、JSON 标量类型、scope 可达
## local/scope 需 runner_id 可定位（运行行）；global 恒可（写回路径按数据源分流）
func _is_row_editable(data: Dictionary) -> bool:
	if data.get("is_note", false) or data.get("is_static", false):
		return false
	if not str(data.get("type", "")) in EDITABLE_TYPES:
		return false
	var scope: String = data.get("scope", "")
	if scope in ["local", "scope"]:
		return int(data.get("runner_id", 0)) > 0
	return scope == "global"


## 创建可编辑的值列 PanelContainer
## 默认 Label，双击进入 LineEdit 编辑模式
func _make_value_panel(data: Dictionary) -> PanelContainer:
	var p := _make_label_panel(data.get("value", ""), COL_VALUE, true)
	if not _is_row_editable(data):
		return p
	p.gui_input.connect(func(ev): _on_value_gui_input(ev, p, data))
	return p


func _on_value_gui_input(ev: InputEvent, panel: PanelContainer, data: Dictionary) -> void:
	if ev is InputEventMouseButton and ev.double_click:
		_enter_edit_mode(panel, data)


func _enter_edit_mode(panel: PanelContainer, data: Dictionary) -> void:
	var line := LineEdit.new()
	line.text = data.get("value", "")
	line.select_all()

	# 替换 Label 为 LineEdit
	var old_label = panel.get_child(0)
	if old_label is Label:
		panel.remove_child(old_label)
		old_label.queue_free()
	panel.add_child(line)

	# 连接信号（Enter 提交 / 失焦提交）
	line.text_submitted.connect(func(nt): _on_value_submitted(nt, data, panel, line))
	line.focus_exited.connect(func(): _on_focus_exited(data, panel, line))
	_editing = true  # 进入编辑，阻止 _refresh 重建
	line.grab_focus()


## Enter 提交
func _on_value_submitted(new_text: String, data: Dictionary, panel: PanelContainer, line: LineEdit) -> void:
	if not is_instance_valid(line):
		return
	_finish_edit(new_text, data, panel)


## 失焦提交
func _on_focus_exited(data: Dictionary, panel: PanelContainer, line: LineEdit) -> void:
	if not is_instance_valid(line):
		return
	_finish_edit(line.text, data, panel)


## 完成编辑：按数据来源写回 + 恢复 Label
## 类型转换失败（coerced == null）只恢复显示、不警告——那是输入问题不是连接问题
func _finish_edit(text: String, data: Dictionary, panel: PanelContainer) -> void:
	var type_str: String = data.get("type", "")
	var coerced = _coerce_value(text, type_str)
	var scope: String = data.get("scope", "")
	var display := text

	if coerced != null:
		var bridge = _get_bridge()
		var sent := true
		if scope == "global":
			if bridge != null and bridge.has_method("is_game_connected") and bridge.is_game_connected():
				sent = bridge.send_set_var("global", 0, data["name"], coerced)
			else:
				_write_back_global(data["name"], coerced)
		elif scope in ["local", "scope"]:
			if bridge != null and bridge.has_method("send_set_var"):
				sent = bridge.send_set_var(scope, int(data.get("runner_id", 0)), data["name"], coerced)
			else:
				sent = false
		if not sent:
			push_warning(FuseLocalizationClass.translate("FUSE_UI_WATCHER_EDIT_NO_CONNECTION"))
			display = str(data.get("value", ""))  # 写回失败恢复原显示值

	_restore_label(panel, display)
	_editing = false  # 结束编辑，恢复 _refresh 轮询（真实值 ≤1s 内回显校正）


## 恢复 Label 显示
func _restore_label(panel: PanelContainer, display_text: String) -> void:
	# 清理旧子节点（LineEdit）
	for c in panel.get_children():
		panel.remove_child(c)
		c.queue_free()

	var label := Label.new()
	label.text = display_text
	label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	label.add_theme_font_size_override("font_size", 16)
	label.clip_text = true
	panel.add_child(label)


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
# 7b: 历史记录 + 折线图
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


func _update_history_graph() -> void:
	if _history_graph == null or not is_instance_valid(_history_graph):
		return

	if _selected_var_key.is_empty() or not _history.has(_selected_var_key):
		var empty_points: Array[float] = []
		_history_graph.set_points(empty_points)
		return

	var points: Array[float] = _history[_selected_var_key]
	_history_graph.set_points(points)


func _on_row_gui_input(ev: InputEvent, var_key: String) -> void:
	if ev is InputEventMouseButton and ev.pressed \
			and ev.button_index == MOUSE_BUTTON_LEFT \
			and not ev.double_click:
		_selected_var_key = var_key
		_update_history_graph()


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
		var line_color := Color(0.4, 0.8, 1.0)

		for i in points.size():
			var x := w * i / float(points.size() - 1)
			var y: float = h - h * (points[i] - min_v) / range_v
			if i > 0:
				draw_line(prev, Vector2(x, y), line_color, 1.5)
			prev = Vector2(x, y)


# ============================================================
# 7d: 运行时变量收集（_refresh 和 get_snapshot 复用）
# ============================================================

## Autoload 桥安全访问（未注册时返回 null）
func _get_bridge() -> Node:
	return get_tree().root.get_node_or_null("FuseRuntimeBridge")


func _collect_runtime_variables() -> Dictionary:
	## 从 FuseRuntimeBridge 读运行游戏推送的变量
	var result := {
		"local_rows": [],
		"scope_rows": [],
		"runners": [],
		"runner_count": 0,
		"active_count": 0
	}

	var bridge = _get_bridge()
	if bridge == null or not bridge.has_method("get_cached_vars"):
		return result

	var cached: Dictionary = bridge.get_cached_vars()
	if cached.is_empty():
		return result

	return _rows_from_cached(cached)


## 由桥缓存生成展示行（与桥访问解耦，便于单元测试）
## scope 变量经共享 ScopeVariableContainer 会被同树下多个 Runner 重复上报
## （同一存储读 N 遍），按"变量名+值"去重；同名不同值（不同容器）各保留一行。
## local 变量为各 Runner 独立存储，不去重。
func _rows_from_cached(cached: Dictionary) -> Dictionary:
	var local_rows: Array[Dictionary] = []
	var scope_rows: Array[Dictionary] = []
	var scope_seen := {}  # "name\x1fvalue" → true
	var result := {
		"local_rows": local_rows,
		"scope_rows": scope_rows,
		"runners": [],
		"runner_count": 0,
		"active_count": 0
	}

	for runner_name in cached:
		result.runner_count += 1
		result.active_count += 1
		var data: Dictionary = cached[runner_name]

		var runner_data := {
			"runner_name": runner_name,
			"local": {},
			"scope": {}
		}

		var locals: Dictionary = data.get("local", {})
		for var_name in locals:
			result.local_rows.append(_make_row_data(var_name, locals[var_name],
				{"scope": "local", "runner": runner_name, "runner_id": int(data.get("id", 0))}))
			runner_data["local"][var_name] = locals[var_name]

		var scopes: Dictionary = data.get("scope", {})
		for var_name in scopes:
			runner_data["scope"][var_name] = scopes[var_name]
			var dedupe_key := "%s\u001f%s" % [var_name, str(scopes[var_name])]
			if scope_seen.has(dedupe_key):
				continue
			scope_seen[dedupe_key] = true
			result.scope_rows.append(_make_row_data(var_name, scopes[var_name],
				{"scope": "scope", "runner": runner_name, "runner_id": int(data.get("id", 0))}))

		result.runners.append(runner_data)

	return result


# ============================================================
# 刷新（主循环）
# ============================================================

func _refresh() -> void:
	# 7a: 编辑中跳过重建，避免销毁正在编辑的 LineEdit
	if _editing:
		return
	# 清空内容区
	for c in _content.get_children():
		c.queue_free()

	var filter := _search_input.text

	# 7d: 收集运行时变量（复用 _collect_runtime_variables）
	var runtime := _collect_runtime_variables()
	var local_rows: Array[Dictionary] = runtime["local_rows"]
	var scope_rows: Array[Dictionary] = runtime["scope_rows"]
	var runner_count: int = runtime["runner_count"]
	var active_count: int = runtime["active_count"]

	if runner_count > 0 and active_count == 0:
		local_rows.append({
			"name": FuseLocalizationClass.translate("FUSE_UI_WATCHER_VISIBLE_AFTER_RUN"),
			"value": "", "type": "",
			"is_note": true, "scope": ""
		})

	# 全局变量：桥活跃 → 游戏侧实时值；否则编辑器侧定义（编辑目标 = 数据来源）
	var bridge = _get_bridge()
	var game_connected: bool = bridge != null \
			and bridge.has_method("is_game_connected") \
			and bridge.is_game_connected()
	var global_rows: Array[Dictionary] = []
	if game_connected:
		var cached_global: Dictionary = bridge.get_cached_global()
		for var_name in cached_global:
			global_rows.append(_make_row_data(var_name, cached_global[var_name],
				{"scope": "global", "runner_id": 0}))
	else:
		var svc := GlobalVariableService.new()
		var globals: Dictionary = svc.get_all_global_variables_info()
		for var_name in globals:
			var info = globals[var_name]
			global_rows.append(_make_row_data(var_name, {
				"value": info.get("value"),
				"type": info.get("type")
			}, {"scope": "global", "runner_id": 0}))

	# 7b: 记录历史
	for row in local_rows + scope_rows + global_rows:
		if row.get("is_note", false) or row.get("is_static", false):
			continue
		var scope_str: String = row.get("scope", "local")
		_record_history("%s/%s" % [scope_str, row["name"]], row["value"], row["type"])

	# 渲染分区
	_render_section(_content, "Local", local_rows, filter, runner_count > 0)
	_render_section(_content, "Scope", scope_rows, filter, false)
	var global_title := "Global"
	if game_connected:
		global_title += FuseLocalizationClass.translate("FUSE_UI_WATCHER_GLOBAL_GAME_SUFFIX")
	_render_section(_content, global_title, global_rows, filter, false)

	# 7c: 静态声明（指令链静态变量声明注入）
	_render_static_declarations(_content, filter)

	# 7b: 更新折线图
	_update_history_graph()

	_status_label.text = "Global:%d  Runner:%d" % [global_rows.size(), runner_count]


# ============================================================
# 7c: 指令链静态变量声明注入
# ============================================================

func _render_static_declarations(parent: VBoxContainer, filter: String) -> void:
	if not Engine.is_editor_hint():
		return

	# 节流：每 STATIC_REFRESH_INTERVAL_MS 重建拓扑（避免 0.5s 高频扫描）
	var now := Time.get_ticks_msec()
	if _last_static_refresh_ms == 0 or now - _last_static_refresh_ms >= STATIC_REFRESH_INTERVAL_MS:
		_last_static_refresh_ms = now
		var editor_interface = Engine.get_singleton("EditorInterface") if ClassDB.class_exists("EditorInterface") else null
		if editor_interface:
			var scene_root = editor_interface.get_edited_scene_root()
			if scene_root:
				var topology := InstructionAnalyzer.build_topology(scene_root)
				_cached_static_rows = _collect_static_var_rows(topology)

	if _cached_static_rows.is_empty():
		return

	# 过滤
	var filtered: Array[Dictionary] = []
	for row in _cached_static_rows:
		if filter.is_empty() or filter in row["name"]:
			filtered.append(row)

	if filtered.is_empty():
		return

	# 分区标题
	var header := _make_section_header(FuseLocalizationClass.translate("FUSE_UI_WATCHER_STATIC_SECTION"))
	parent.add_child(header)

	for row in filtered:
		parent.add_child(_make_data_row(row))


## 汇总所有 Trigger 的 variables 声明 → 去重行
func _collect_static_var_rows(topology: Dictionary) -> Array[Dictionary]:
	var by_name: Dictionary = {}  # name → {scopes: {}, triggers: [], modes: {}}

	for trigger_report in topology.get("triggers", []):
		var tname: String = trigger_report.get("trigger_name", "?")
		for scope in ["local", "scope", "global"]:
			for entry in trigger_report.get("variables", {}).get(scope, []):
				var vname: String = entry.get("name", "")
				if vname.is_empty():
					continue
				if not by_name.has(vname):
					by_name[vname] = {"scopes": {}, "triggers": [], "modes": {}}
				by_name[vname]["scopes"][scope] = true
				if tname not in by_name[vname]["triggers"]:
					by_name[vname]["triggers"].append(tname)
				by_name[vname]["modes"][entry.get("mode", "read_write")] = true

	# 转换行
	var rows: Array[Dictionary] = []
	for vname in by_name:
		var info = by_name[vname]
		var scopes_str := ", ".join(info["scopes"].keys())
		# mode 推断
		var has_write: bool = info["modes"].has("write")
		var has_read: bool = info["modes"].has("read")
		var mode_str := ""
		if has_write and has_read:
			mode_str = FuseLocalizationClass.translate("FUSE_UI_WATCHER_MODE_READ_WRITE")
		elif has_write:
			mode_str = FuseLocalizationClass.translate("FUSE_UI_WATCHER_MODE_WRITE")
		else:
			mode_str = FuseLocalizationClass.translate("FUSE_UI_WATCHER_MODE_READ")
		rows.append({
			"name": vname,
			"value": FuseLocalizationClass.translate("FUSE_UI_WATCHER_STATIC_VALUE"),
			"type": FuseLocalizationClass.translate_format("FUSE_UI_WATCHER_STATIC_TYPE", {
				"scopes": scopes_str, "mode": mode_str, "count": info["triggers"].size()
			}),
			"is_static": true,
			"scope": ""
		})

	return rows


# ============================================================
# 数据行构建
# ============================================================

func _make_row_data(var_name: String, data, extra: Dictionary = {}) -> Dictionary:
	var val = data.get("value", data) if data is Dictionary else data
	var type_str := ""
	if data is Dictionary and data.has("type"):
		type_str = data["type"]
	else:
		type_str = type_string(typeof(val))
	return {
		"name": var_name,
		"value": str(val),
		"type": type_str,
		"scope": extra.get("scope", ""),
		"runner": extra.get("runner", ""),
		"runner_id": int(extra.get("runner_id", 0))
	}


func _render_section(parent: VBoxContainer, title: String, rows: Array[Dictionary], filter: String, _has_runners: bool) -> void:
	# 过滤
	var filtered: Array[Dictionary] = []
	for row in rows:
		if filter.is_empty() or filter in row["name"]:
			filtered.append(row)

	if not _has_runners or not rows.is_empty():
		var header := _make_section_header(title)
		parent.add_child(header)

	if filtered.is_empty():
		return

	for row in filtered:
		parent.add_child(_make_data_row(row))


# --- UI 工厂方法 ---

func _make_header_row() -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)

	var name := _make_label_panel(FuseLocalizationClass.translate("FUSE_UI_LABEL_VARIABLES"), COL_NAME)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.size_flags_stretch_ratio = 1.0
	hbox.add_child(name)

	var val := _make_label_panel(FuseLocalizationClass.translate("FUSE_UI_LABEL_VALUE"), COL_VALUE)
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.size_flags_stretch_ratio = 1.0
	hbox.add_child(val)

	var typ := _make_label_panel(FuseLocalizationClass.translate("FUSE_UI_LABEL_TYPE"), COL_TYPE)
	typ.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	typ.size_flags_stretch_ratio = 1.0
	hbox.add_child(typ)

	return hbox


func _make_section_header(title: String) -> PanelContainer:
	return _make_label_panel(title, COL_HEADER)


func _make_data_row(data: Dictionary) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)

	var is_interactive: bool = not data.get("is_note", false) and not data.get("is_static", false)
	var var_key := "%s/%s" % [data.get("scope", "?"), data["name"]]

	# 7b: 行选中（仅交互行）
	if is_interactive:
		hbox.gui_input.connect(func(ev): _on_row_gui_input(ev, var_key))

	# 交互行各列 pass mouse 让 HBox 接收点击选中
	var pass_mouse := is_interactive

	# 变量名列
	var name_panel := _make_label_panel(data["name"], COL_NAME, pass_mouse)
	name_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_panel.size_flags_stretch_ratio = 1.0
	hbox.add_child(name_panel)

	# 值列（7a: 交互行可编辑，非交互行只读 label）
	if is_interactive:
		var val := _make_value_panel(data)
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val.size_flags_stretch_ratio = 1.0
		hbox.add_child(val)
	else:
		var val := _make_label_panel(data.get("value", ""), COL_VALUE)
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val.size_flags_stretch_ratio = 1.0
		hbox.add_child(val)

	# 类型列
	var typ := _make_label_panel(data["type"], COL_TYPE, pass_mouse)
	typ.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	typ.size_flags_stretch_ratio = 1.0
	hbox.add_child(typ)

	return hbox


func _make_label_panel(text_str: String, color: Color, pass_mouse: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_content_margin_all(3)
	p.add_theme_stylebox_override("panel", s)
	if pass_mouse:
		p.mouse_filter = Control.MOUSE_FILTER_PASS
	var l := Label.new()
	l.text = text_str
	l.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	l.add_theme_font_size_override("font_size", 16)
	l.clip_text = true
	p.add_child(l)
	return p


func _add_var_row(_parent, name: String, data) -> void:
	pass  # 保留兼容，不再使用 Tree


# --- 快照 ---

func get_snapshot() -> Dictionary:
	var result := {
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"runners": [],
		"global": {}
	}

	# 全局变量
	var svc := GlobalVariableService.new()
	result["global"] = svc.get_all_global_variables_info()

	# 7d: runners + local/scope（复用 _collect_runtime_variables）
	var runtime = _collect_runtime_variables()
	result["runners"] = runtime["runners"]

	return result


func _on_snapshot() -> void:
	var snap := get_snapshot()
	var path := "user://fuse_watcher_snapshot_%d.json" % Time.get_ticks_msec()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(snap, "\t"))
		file.close()
		print(FuseLocalizationClass.translate_format("FUSE_UI_WATCHER_SNAPSHOT_SAVED", {"path": path}))
