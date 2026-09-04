@tool
class_name FuseVariableWatcherTree
extends Tree

## 变量监视器树（场景 → 宿主 → 变量，GLOBAL 平级根）
## 职责：三级增量构建/diff、折叠持久、过滤集重建、选中与双击激活信号
## 数据来源：variable_watcher._rows_from_cached 产物 + 桥缓存 scene 字段

signal variable_selected(row: Dictionary, selected: bool)
signal variable_activated(row: Dictionary)  # 双击编辑请求（仅可编辑行）

const COL_NAME := 0
const COL_VALUE := 1
const COL_TYPE := 2
const STALE_MS := 5000
const KIND_LABEL := {"trigger": "Trigger", "multi": "MultiEvent", "runner": "Runner"}

var _collapsed: Dictionary = {}   # 折叠持久："s:<场景>"/"c<id>"/"u<id>" → bool
var _scene_items: Dictionary = {} # 场景名（含 "__global__"）→ TreeItem
var _host_items: Dictionary = {}  # 宿主 key → TreeItem
var _var_items: Dictionary = {}   # "target:id:name" → TreeItem
var _row_meta: Dictionary = {}    # 同上键 → 行字典
var _selected_key := ""


func _init() -> void:
	columns = 3
	hide_root = true
	select_mode = Tree.SELECT_ROW
	set_column_expand(COL_NAME, true)
	set_column_expand(COL_VALUE, true)
	set_column_custom_minimum_width(COL_VALUE, 120)
	set_column_expand(COL_TYPE, false)
	set_column_custom_minimum_width(COL_TYPE, 86)
	item_selected.connect(_on_item_selected)
	item_activated.connect(_on_item_activated)
	item_collapsed.connect(_on_item_collapsed)


## 场景归组：/root/<名> 前缀 → 附加场景名；否则当前场景名
static func scene_of(path: String, current_scene: String) -> String:
	if path.begins_with("/root/"):
		var rest := path.substr("/root/".length())
		var slash := rest.find("/")
		return rest.substr(0, slash) if slash >= 0 else rest
	return current_scene


## diff 计划：旧键集/新键集 → {add, remove}
static func diff_plan(old_keys: Array, new_keys: Array) -> Dictionary:
	var add: Array = []
	var remove: Array = []
	var old_set := {}
	for k in old_keys:
		old_set[k] = true
	for k in new_keys:
		if not old_set.has(k):
			add.append(k)
	for k in old_keys:
		if not new_keys.has(k):
			remove.append(k)
	return {"add": add, "remove": remove}


## 过滤命中（大小写不敏感包含；空过滤放行）
static func _passes_filter(text: String, filter: String) -> bool:
	if filter.is_empty():
		return true
	return filter.to_lower() in text.to_lower()


func _is_group_collapsed(key: String) -> bool:
	return bool(_collapsed.get(key, false))


func _toggle_group(key: String) -> void:
	_collapsed[key] = not _is_group_collapsed(key)


## 主入口：增量应用行集，返回摘要 {scenes, hosts, global}（过滤前计数）
func apply_data(rows: Dictionary, current_scene: String, filter_text: String) -> Dictionary:
	var summary := {"scenes": 0, "hosts": 0, "global": 0}
	if get_root() == null:
		create_item()
	# 目标结构计算（过滤在此生效——target 集变化即 diff 出增删）
	var targets := _build_targets(rows, current_scene, filter_text)

	# 一级：场景根 + GLOBAL 根
	var scene_keys: Array = targets["scenes"].keys()
	summary["scenes"] = scene_keys.size()
	var splan: Dictionary = diff_plan(_scene_items.keys(), scene_keys)
	for k in splan["remove"]:
		_free_subtree(_scene_items[k])
		_scene_items.erase(k)
	for k in scene_keys:
		if not _scene_items.has(k):
			var it := create_item(get_root())
			var display: String = "GLOBAL" if k == "__global__" else k
			it.set_text(COL_NAME, display)
			var bold: Font = get_theme_font("bold", "EditorFonts")
			if bold != null:
				it.set_custom_font(COL_NAME, bold)
			it.set_metadata(COL_NAME, {"collapse_key": "s:" + k})
			it.collapsed = _is_group_collapsed("s:" + k)
			_scene_items[k] = it
	_ensure_global_root()

	# 二级：宿主（容器在前组件在后 → targets 内已排序）
	var host_keys: Array = targets["hosts"].keys()
	summary["hosts"] = host_keys.size()
	var hplan: Dictionary = diff_plan(_host_items.keys(), host_keys)
	for k in hplan["remove"]:
		# 宿主可能已随场景根子树删除（_free_subtree 内已清键）
		if _host_items.has(k):
			_free_subtree(_host_items[k])
			_host_items.erase(k)
	for k in host_keys:
		var host: Dictionary = targets["hosts"][k]
		if not _host_items.has(k):
			var parent_it: TreeItem = _scene_items[host["scene"]]
			var it := create_item(parent_it)
			it.set_metadata(COL_NAME, {"collapse_key": k})
			_host_items[k] = it
		var hit: TreeItem = _host_items[k]
		hit.set_text(COL_NAME, host["label"])
		hit.collapsed = _is_group_collapsed(k)
		_apply_stale_color(hit, host.get("stale", false))

	# 三级：变量行
	var var_keys: Array = targets["vars"].keys()
	var vplan: Dictionary = diff_plan(_var_items.keys(), var_keys)
	for k in vplan["remove"]:
		# 变量行可能已随宿主子树删除（_free_subtree 内已清键）
		if _var_items.has(k):
			_var_items[k].free()
			_var_items.erase(k)
			_row_meta.erase(k)
	for k in var_keys:
		var row: Dictionary = targets["vars"][k]
		if not _var_items.has(k):
			var it := create_item(_host_items[row["group_key"]])
			it.set_metadata(COL_NAME, row)
			_var_items[k] = it
			_row_meta[k] = row
		var vit: TreeItem = _var_items[k]
		vit.set_text(COL_NAME, row["name"])
		vit.set_text(COL_VALUE, row["value"])
		vit.set_text(COL_TYPE, row["type"])
	_apply_complex_color()
	summary["global"] = int(rows.get("global_count", 0))
	_check_selection_stale()
	return summary


## 组装目标结构：{scenes: {场景名: true}, hosts: {key: {scene,label,stale}},
## vars: {"target:id:name": 行字典}}
func _build_targets(rows: Dictionary, current_scene: String, filter_text: String) -> Dictionary:
	var scenes := {}
	var hosts := {}
	var vars := {}
	var host_order := []  # 保持稳定顺序：容器（原序）→ 组件（原序）
	for g in rows.get("container_groups", []):
		host_order.append(g)
	for g in rows.get("unit_groups", []):
		host_order.append(g)
	var rows_by_group := {}
	for row in rows.get("scope_rows", []):
		_rows_append(rows_by_group, row)
	for row in rows.get("local_rows", []):
		_rows_append(rows_by_group, row)
	for g in host_order:
		var gkey: String = g["key"]
		var gpath: String = g["path"]
		var scene := scene_of(gpath, current_scene)
		# 组命中条件：场景名/组路径命中，或组内任一变量命中
		var group_txt := scene + " " + gpath + " " + str(g.get("scope_id", "")) + " " + str(g.get("kind", ""))
		var group_hit := _passes_filter(group_txt, filter_text)
		var matched_rows: Array = []
		for row in rows_by_group.get(gkey, []):
			if group_hit or _passes_filter(str(row["name"]) + " " + str(row["value"]), filter_text):
				matched_rows.append(row)
		if filter_text != "" and matched_rows.is_empty():
			continue
		scenes[scene] = true
		var stale := int(g.get("ago_ms", 0)) > STALE_MS
		var label: String
		if g.has("kind"):
			label = "%s [%s] · %ss" % [gpath, KIND_LABEL.get(str(g["kind"]), str(g["kind"])),
				("%.1f" % (float(g.get("ago_ms", 0)) / 1000.0))]
		else:
			label = "%s (%s)" % [gpath, g.get("scope_id", "")]
		hosts[gkey] = {"scene": scene, "label": label, "stale": stale}
		for row in matched_rows:
			vars["%s:%d:%s" % [row["target"], row["id"], row["name"]]] = row
	# GLOBAL 根恒在（global 行由主文件直挂——见 _apply_global）
	return {"scenes": scenes, "hosts": hosts, "vars": vars}


static func _rows_append(dict: Dictionary, row: Dictionary) -> void:
	var k: String = row["group_key"]
	if not dict.has(k):
		dict[k] = [] as Array[Dictionary]
	dict[k].append(row)


## GLOBAL 平级根恒在（apply_data/apply_global 共用；global 行由主文件经 apply_global 直挂）
func _ensure_global_root() -> void:
	var gk := "__global__"
	if _scene_items.has(gk):
		return
	var it := create_item(get_root())
	it.set_text(COL_NAME, "GLOBAL")
	var bold: Font = get_theme_font("bold", "EditorFonts")
	if bold != null:
		it.set_custom_font(COL_NAME, bold)
	it.set_metadata(COL_NAME, {"collapse_key": "s:" + gk})
	it.collapsed = _is_group_collapsed("s:" + gk)
	_scene_items[gk] = it


## GLOBAL 平铺行（主文件每轮调用；同样走增量）
func apply_global(global_rows: Array, filter_text: String) -> void:
	if get_root() == null:
		create_item()
	_ensure_global_root()
	var git: TreeItem = _scene_items["__global__"]
	# 全删全建（global 行少且无稳定 id）
	var c := git.get_first_child()
	while c:
		var n := c.get_next()
		c.free()
		c = n
	var seen := {}  # 本轮 global 行键集（清理 _row_meta 中已消失的旧 global 键）
	for row in global_rows:
		if not _passes_filter(str(row["name"]) + " " + str(row["value"]) + " global", filter_text):
			continue
		var it := create_item(git)
		it.set_text(COL_NAME, row["name"])
		it.set_text(COL_VALUE, row["value"])
		it.set_text(COL_TYPE, row["type"])
		it.set_metadata(COL_NAME, row)
		var k := "%s:%d:%s" % [row["target"], row["id"], row["name"]]
		_row_meta[k] = row
		seen[k] = true
	for k in _row_meta.keys():
		if k.begins_with("global:") and not seen.has(k):
			_row_meta.erase(k)
	_check_selection_stale()


func selected_row() -> Dictionary:
	if _selected_key.is_empty() or not _row_meta.has(_selected_key):
		return {}
	return _row_meta[_selected_key]


## 选中行值列屏幕矩形（LineEdit 编辑定位用）
func value_cell_screen_rect() -> Rect2:
	var it := get_selected()
	if it == null:
		return Rect2()
	var rect := get_item_area_rect(it, COL_VALUE)
	return Rect2(get_global_rect().position + rect.position, rect.size)


func _free_subtree(item: TreeItem) -> void:
	# 递归前先清索引（TreeItem 存活时比较；free 后再取会命中已释放实例）
	for k in _var_items.keys():
		if _var_items[k].get_parent() == item:
			_var_items.erase(k)
			_row_meta.erase(k)
	for k in _host_items.keys():
		if _host_items[k] == item:
			_host_items.erase(k)
	var c := item.get_first_child()
	while c:
		var n := c.get_next()
		_free_subtree(c)
		c = n
	item.free()


func _apply_stale_color(item: TreeItem, stale: bool) -> void:
	if stale:
		item.set_custom_color(COL_NAME, get_theme_color("font_disabled_color", "Tree"))
	else:
		item.clear_custom_color(COL_NAME)


func _apply_complex_color() -> void:
	for k in _var_items:
		var row: Dictionary = _row_meta[k]
		if bool(row.get("is_complex", false)):
			_var_items[k].set_custom_color(COL_VALUE, get_theme_color("font_disabled_color", "Tree"))
		else:
			_var_items[k].clear_custom_color(COL_VALUE)


func _on_item_selected() -> void:
	var it := get_selected()
	if it == null:
		return
	var meta = it.get_metadata(COL_NAME)
	if meta is Dictionary and meta.has("target"):
		_selected_key = "%s:%d:%s" % [meta["target"], meta["id"], meta["name"]]
		variable_selected.emit(meta, true)


## 选中失效检测（Tree 无 item_deselected 信号——选中行被 diff 移除时补发失选事件）
func _check_selection_stale() -> void:
	if not _selected_key.is_empty() and not _row_meta.has(_selected_key):
		_selected_key = ""
		variable_selected.emit({}, false)


func _on_item_activated() -> void:
	var it := get_selected()
	if it == null:
		return
	var meta = it.get_metadata(COL_NAME)
	if meta is Dictionary and meta.has("target"):
		variable_activated.emit(meta)


func _on_item_collapsed(item: TreeItem) -> void:
	var meta = item.get_metadata(COL_NAME)
	if meta is Dictionary and meta.has("collapse_key"):
		_collapsed[meta["collapse_key"]] = item.collapsed
