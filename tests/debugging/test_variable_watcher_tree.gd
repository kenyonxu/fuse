extends Node

## FuseVariableWatcherTree 单元测试：场景归组/diff 计划/建树/折叠键/过滤/选中元数据

const TreeScript = preload("res://addons/fuse/editor/debugging/variable_watcher_tree.gd")

# FAKE_ROWS 为 var 全大写伪数据（简报裁决：const 容器禁改，测试需改值验增量）
# gdlint: ignore=class-variable-name
var FAKE_ROWS := {
	"container_groups": [
		{"key": "c1", "path": "/", "scope_id": "level"},
		{"key": "c2", "path": "/root/UIOverlay", "scope_id": "ui"}],
	"unit_groups": [
		{"key": "u3", "path": "/Player/OnInput", "kind": "trigger", "ago_ms": 300},
		{"key": "u4", "path": "/root/UIOverlay/OnScore", "kind": "multi", "ago_ms": 800}],
	"local_rows": [
		{"name": "hp", "value": "55", "type": "int", "is_complex": false, "target": "unit",
			"id": 3, "group_key": "u3", "group_path": "/Player/OnInput"}],
	"scope_rows": [
		{"name": "current_level", "value": "1", "type": "int", "is_complex": false, "target": "container",
			"id": 1, "group_key": "c1", "group_path": "/"},
		{"name": "hud_visible", "value": "true", "type": "bool", "is_complex": false, "target": "container",
			"id": 2, "group_key": "c2", "group_path": "/root/UIOverlay"}],
	"unit_count": 2, "container_count": 2
}

var _fail_count: int = 0
var _tree: Tree = null


func _ready() -> void:
	_tree = TreeScript.new()
	add_child(_tree)

	_test_scene_of()
	_test_scene_root_label()
	_test_diff_plan()
	_test_apply_data_structure()
	_test_collapse_and_filter()
	_test_apply_global()
	_test_selection_metadata()

	print("\n=== 结果: %d 处失败 ===" % _fail_count)
	get_tree().quit(1 if _fail_count > 0 else 0)


func _check(condition: bool, msg: String) -> void:
	if condition:
		print("  PASS: ", msg)
	else:
		_fail_count += 1
		push_error("  FAIL: " + msg)


func _test_scene_of() -> void:
	print("\n--- scene_of 归组规则 ---")
	_check(TreeScript.scene_of("/Player/OnInput", "level01") == "level01", "当前场景子树 → 当前场景")
	_check(TreeScript.scene_of("/root/UIOverlay/X", "level01") == "UIOverlay", "/root 前缀 → 附加场景名")
	_check(TreeScript.scene_of("/root/Solo", "level01") == "Solo", "/root 直挂根节点")
	_check(TreeScript.scene_of("/", "level01") == "level01", "场景根本身")


func _test_scene_root_label() -> void:
	print("\n--- 场景根尾注 ---")
	_check(TreeScript._scene_root_label("level01", "level01") == "level01 · 当前", "当前场景尾注")
	_check(TreeScript._scene_root_label("ui_overlay", "level01") == "ui_overlay · 附加", "附加场景尾注")
	_check(TreeScript._scene_root_label("__global__", "level01") == "GLOBAL", "GLOBAL 根无尾注")


func _test_diff_plan() -> void:
	print("\n--- diff 计划 ---")
	var plan: Dictionary = TreeScript.diff_plan(["a", "b", "c"], ["b", "c", "d"])
	_check(plan["add"] == ["d"], "新增 = [d]")
	_check(plan["remove"] == ["a"], "移除 = [a]")


func _test_apply_data_structure() -> void:
	print("\n--- apply_data 三级结构 ---")
	var summary: Dictionary = _tree.apply_data(FAKE_ROWS, "level01", "")
	_check(int(summary.get("scenes", 0)) == 2, "两个场景根（level01 + UIOverlay）（got %d）" % summary.get("scenes", 0))
	_check(int(summary.get("hosts", 0)) == 4, "四个宿主（got %d）" % summary.get("hosts", 0))
	_check(int(summary.get("global", 0)) == 0, "global 计数 0")
	# GLOBAL 根恒存在（变量可后挂）
	var global_root: TreeItem = _find_root_by_text("GLOBAL")
	_check(global_root != null, "GLOBAL 平级根存在")
	# 场景根存在且宿主挂其下
	var lv_root: TreeItem = _find_root_by_text("level01")
	_check(lv_root != null, "level01 场景根存在")
	_check(_child_count(lv_root) == 2, "level01 下 2 宿主（c1 + u3；c2/u4 归 UIOverlay）（got %d）" % _child_count(lv_root))
	var ui_root: TreeItem = _find_root_by_text("UIOverlay")
	_check(ui_root != null and _child_count(ui_root) == 2, "UIOverlay 下 2 宿主")
	# 增量：改一个值再 apply → item 存活且文本更新
	FAKE_ROWS["local_rows"][0]["value"] = "77"
	_tree.apply_data(FAKE_ROWS, "level01", "")
	var hp_item: TreeItem = _find_item_text("hp")
	_check(hp_item != null and hp_item.get_text(1) == "77", "增量更新值列（55→77）")


func _test_collapse_and_filter() -> void:
	print("\n--- 折叠与过滤（迁移自 watcher 测试） ---")
	_check(_tree._is_group_collapsed("s:level01") == false, "默认展开")
	_tree._toggle_group("s:level01")
	_check(_tree._is_group_collapsed("s:level01") == true, "折叠置位")
	_tree._toggle_group("s:level01")
	_check(_tree._is_group_collapsed("s:level01") == false, "二次 toggle 恢复展开")
	_check(_tree._passes_filter("HP", "") == true, "空过滤放行")
	_check(_tree._passes_filter("OnInput", "oninput") == true, "大小写不敏感命中")
	_check(_tree._passes_filter("hp", "camera") == false, "不命中")
	# 过滤重建：无匹配 → 场景根与行均不在树中
	_tree.apply_data(FAKE_ROWS, "level01", "camera")
	_check(_find_root_by_text("level01") == null, "全组不命中时场景根不建")
	_check(_find_item_text("hp") == null, "不匹配行按过滤集重建后不在树中")


func _test_apply_global() -> void:
	print("\n--- apply_global 路径 ---")
	var grows: Array = [
		{"name": "score", "value": "2100", "type": "int", "is_complex": false,
			"target": "global", "id": 0, "group_key": "", "group_path": ""},
		{"name": "god", "value": "true", "type": "bool", "is_complex": false,
			"target": "global", "id": 0, "group_key": "", "group_path": ""}]
	_tree.apply_global(grows, "")
	var groot := _find_root_by_text("GLOBAL")
	_check(groot != null and _child_count(groot) == 2,
		"GLOBAL 根挂 2 行（got %d）" % (_child_count(groot) if groot != null else -1))
	_tree.apply_global(grows, "god")
	_check(_child_count(_find_root_by_text("GLOBAL")) == 1, "过滤后仅 god 命中")
	_tree.apply_global([], "")
	_check(_child_count(_find_root_by_text("GLOBAL")) == 0, "global 清空")
	# 失选补发：选中键失效时 variable_selected({}, false)
	var fired := {"deselect": 0}
	_tree.variable_selected.connect(func(_r: Dictionary, sel: bool) -> void:
		if not sel:
			fired["deselect"] += 1)
	_tree._selected_key = "global:0:gone"
	_tree.apply_global(grows, "")
	_check(fired["deselect"] >= 1, "选中键失效补发失选事件")


func _test_selection_metadata() -> void:
	print("\n--- 选中与元数据 ---")
	_tree.apply_data(FAKE_ROWS, "level01", "")
	var hp_item: TreeItem = _find_item_text("hp")
	_check(hp_item != null, "hp 行存在")
	if hp_item:
		var meta: Dictionary = hp_item.get_metadata(0)
		_check(meta.get("target", "") == "unit" and int(meta.get("id", 0)) == 3, "行元数据携带 target/id")
		_check(_tree.selected_row().is_empty(), "未选中时 selected_row 为空")
	_tree.queue_free()


func _find_root_by_text(txt: String) -> TreeItem:
	# 前缀匹配：场景根文本带尾注（"level01 · 当前"/"ui_overlay · 附加"），GLOBAL 精确无尾注
	var root := _tree.get_root()
	if root == null:
		return null
	var c := root.get_first_child()
	while c:
		if c.get_text(0).begins_with(txt):
			return c
		c = c.get_next()
	return null


func _child_count(item: TreeItem) -> int:
	var n := 0
	var c := item.get_first_child()
	while c:
		n += 1
		c = c.get_next()
	return n


func _find_item_text(txt: String) -> TreeItem:
	var root := _tree.get_root()
	if root == null:
		return null
	var stack: Array[TreeItem] = [root]
	while stack.size() > 0:
		var it: TreeItem = stack.pop_back()
		if it != root and it.get_text(0) == txt:
			return it
		var c := it.get_first_child()
		while c:
			stack.append(c)
			c = c.get_next()
	return null
