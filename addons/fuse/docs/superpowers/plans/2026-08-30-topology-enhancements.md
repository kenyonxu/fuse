# 拓扑增强三件套实施计划（毕业导出器前置）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 场景拓扑三项增强——JSON 导出（毕业导出器的 ground truth）、Runner 单元扫描（扩大拓扑覆盖面）、搜索过滤（日常可用性）。

**Architecture:** 全部改动收敛在 `editor/topology/` 与 `editor/analysis/instruction_analyzer.gd`，不触碰 core 与 preset_ai 闭环。导出走共享序列化函数（CLI 与面板按钮双入口同源）；Runner 扫描给 report 增加 `kind` 判别字段，消费方按 kind 分支；搜索为 report 级匹配函数（static 可测）+ UI 接线。

**Tech Stack:** Godot 4.7 headless GDScript；场景式测试 + 退出码。

**Spec:** `addons/fuse/docs/superpowers/specs/2026-08-30-preset-gdscript-graduation-design.md`（§2 基础设施表——本计划强化其中的拓扑分析器与导出面）

## Global Constraints

- Godot（Git Bash）：`export GODOT="/e/Godot/Godot_v4.7-stable_mono_win64/Godot_v4.7-stable_mono_win64_console.exe"`；`"$GODOT" --headless --path . res://<scene>`；类缓存错先 `--import`。
- 仓库根 `E:\GitHub\fuse`；GDScript：tab 缩进、全类型注解、snake_case、push_error/push_warning。
- 测试场景结尾 `get_tree().quit(1 if _fail > 0 else 0)`；新 .tscn 头省略 uid 属性。
- 本计划**不新增组件**（纯编辑器侧 + 测试），无需重 dump。
- 已核实事实：
  - `build_topology()`（instruction_analyzer.gd:421）只扫 `find_children("*", "Trigger")` + `"MultiEventTrigger"`；report 含 trigger_name/path/type/event/event_bindings/nodes/variables/signals/instructions_flat/instructions_tree/provided_locals。
  - `_get_action_runner()`（:122）会取 Trigger 的 **Runner 子节点**作为动作源——拓扑扫 Runner 时必须去重：跳过已扫描 Trigger/MultiEventTrigger 的直接子 Runner。
  - `_extract_signals()`（:385 区域）已全树扫描 Runner 并收集"target 指向本 Trigger"的信号。
  - `fuse_topology.gd` 的 `refresh()`（:261）经 `EditorInterface.get_edited_scene_root()` 取根 → `build_topology` → 主/嵌套分组 → `_create_trigger_tree_item`；banner 已有问题过滤下拉 + 刷新 + 导出问题报告按钮；防抖 Timer（0.5s）已有。
  - report 的 instructions_flat/tree 为字典结构，但**不保证全 JSON 可序列化**（可能含 NodePath/Object 引用）——导出必须过 sanitizer。
  - 测试目录惯例：`addons/fuse/tests/<子系统>/test_*.tscn`；指令对象可在测试中程序化构造（先例：tests/serialization/test_preset_nested_serde.gd）。

---

### Task 1: 拓扑 JSON 导出（CLI + 面板按钮）

**Files:**
- Create: `addons/fuse/editor/topology/topology_export.gd`
- Create: `addons/fuse/editor/topology/export_topology_cli.gd` + `export_topology.tscn`
- Modify: `addons/fuse/editor/topology/fuse_topology.gd`（banner 增按钮，:67-70 导出问题报告按钮之后）
- Create: `addons/fuse/tests/topology/test_export_topology.gd` + `.tscn`

**Interfaces:**
- Produces（Task 2 复用、毕业 deriver 远期消费）:
  - `TopologyExport.sanitize_for_json(value: Variant) -> Variant`（递归净化：NodePath→str、Object→{"__object__": 类名, "resource_name": ...}、其余原样）
  - `TopologyExport.export_to_json(topology: Dictionary, out_dir: String) -> String`（返回写出路径；失败返回 ""）
  - CLI 契约：`"$GODOT" --headless --path . res://addons/fuse/editor/topology/export_topology.tscn -- --scene res://<scene> [--out res://fuse_reports/topology]`；退出码 0/成功，2/参数或 IO 错

- [ ] **Step 1: 写失败测试**

`addons/fuse/tests/topology/test_export_topology.gd`：

```gdscript
# addons/fuse/tests/topology/test_export_topology.gd
extends Node

const TopologyExport := preload("res://addons/fuse/editor/topology/topology_export.gd")

var _fail := 0

func _check(cond: bool, msg: String) -> void:
	if cond: print("✓ " + msg)
	else:
		_fail += 1
		push_error("✗ " + msg)

func _ready():
	print("=== test_export_topology ===")
	_test_sanitize()
	_test_export_real_scene()
	print("=== 结果: %d 失败 ===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _test_sanitize() -> void:
	var dirty := {
		"path": NodePath("../Target"),
		"obj": RefCounted.new(),
		"plain": [1, "a", true],
		"nested": {"x": NodePath("A/B")},
	}
	var clean: Variant = TopologyExport.sanitize_for_json(dirty)
	var s := JSON.stringify(clean)
	var parsed: Variant = JSON.parse_string(s)
	_check(parsed is Dictionary, "sanitized 值可 JSON 往返")
	_check(str(clean["path"]) == "../Target", "NodePath 转字符串")
	_check(clean["obj"] is Dictionary and clean["obj"].has("__object__"), "Object 转浅字典")

func _test_export_real_scene() -> void:
	var scene: PackedScene = load("res://demos/fuse/brickian/game_scene.tscn")
	var inst := scene.instantiate()
	add_child(inst)
	var topology: Dictionary = InstructionAnalyzer.build_topology(inst)
	var out_path: String = TopologyExport.export_to_json(topology, "user://topology_test")
	_check(not out_path.is_empty(), "导出成功返回路径")
	if out_path.is_empty():
		return
	var text := FileAccess.get_file_as_string(out_path)
	var parsed: Variant = JSON.parse_string(text)
	_check(parsed is Dictionary, "导出文件是合法 JSON")
	if parsed is Dictionary:
		_check(parsed.has("triggers") and (parsed["triggers"] as Array).size() >= 1,
			"triggers 非空（实际 %d）" % (parsed["triggers"] as Array).size())
		_check(parsed.has("cross_references") and parsed.has("variable_analysis"), "关联与变量分析键在")
	inst.queue_free()
```

`.tscn` 同惯例（头无 uid，root 挂本脚本）。

- [ ] **Step 2: 跑测试确认失败**（topology_export.gd 不存在）

- [ ] **Step 3: 实现共享导出模块**

`addons/fuse/editor/topology/topology_export.gd`：

```gdscript
# addons/fuse/editor/topology/topology_export.gd
@tool
class_name TopologyExport
extends RefCounted

## 拓扑 report 的 JSON 导出（CLI 与拓扑面板共用）
##
## report 字典不保证全 JSON 可序列化（NodePath / Object 引用），
## sanitize 递归净化后再落盘。

## 递归净化：NodePath→str，Object→浅字典，其余原样
static func sanitize_for_json(value: Variant) -> Variant:
	if value is NodePath:
		return str(value)
	if value is Object:
		var entry := {"__object__": value.get_class()}
		var script := value.get_script() as GDScript
		if script != null and not script.get_global_name().is_empty():
			entry["__object__"] = script.get_global_name()
		if "resource_name" in value:
			entry["resource_name"] = value.resource_name
		return entry
	if value is Dictionary:
		var out := {}
		for k in value:
			out[k] = sanitize_for_json(value[k])
		return out
	if value is Array:
		var arr: Array = []
		for item in value:
			arr.append(sanitize_for_json(item))
		return arr
	return value

## 导出 topology 到 <out_dir>/<scene_name>.json，返回路径（失败 ""）
static func export_to_json(topology: Dictionary, out_dir: String) -> String:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var file_name: String = str(topology.get("scene_name", "scene"))
	var path := out_dir.path_join(file_name + ".json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[TopologyExport] 无法写入 %s (err=%d)" % [path, FileAccess.get_open_error()])
		return ""
	f.store_string(JSON.stringify(sanitize_for_json(topology), "\t"))
	f.close()
	return path
```

`addons/fuse/editor/topology/export_topology_cli.gd`：

```gdscript
# addons/fuse/editor/topology/export_topology_cli.gd
extends Node

const TopologyExport := preload("res://addons/fuse/editor/topology/topology_export.gd")

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path := ""
	var out_dir := "res://fuse_reports/topology"
	var i := 0
	while i < args.size():
		match args[i]:
			"--scene":
				i += 1
				if i < args.size(): scene_path = args[i]
			"--out":
				i += 1
				if i < args.size(): out_dir = args[i]
		i += 1
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		printerr("用法: export_topology.tscn -- --scene res://<scene.tscn> [--out <dir>]")
		get_tree().quit(2)
		return
	var scene: PackedScene = load(scene_path)
	if scene == null:
		printerr("场景加载失败: %s" % scene_path)
		get_tree().quit(2)
		return
	var inst := scene.instantiate()
	add_child(inst)
	var topology: Dictionary = InstructionAnalyzer.build_topology(inst)
	var path: String = TopologyExport.export_to_json(topology, out_dir)
	inst.queue_free()
	if path.is_empty():
		get_tree().quit(2)
		return
	print("topology → %s (triggers: %d, cross_refs: %d)" % [path,
		topology.triggers.size(), topology.cross_references.size()])
	get_tree().quit(0)
```

`export_topology.tscn`（头无 uid，root 挂 CLI 脚本）。

- [ ] **Step 4: 面板按钮**

`fuse_topology.gd` 的 banner 区（"导出问题报告"按钮之后）追加：

```gdscript
	var export_json_btn := Button.new()
	export_json_btn.text = "导出 JSON"
	export_json_btn.pressed.connect(_on_export_json)
	banner.add_child(export_json_btn)
```

文件内新增 handler（放在 `_on_export_problems` 附近）：

```gdscript
func _on_export_json() -> void:
	var scene_root: Node = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		_detail.append_text("[color=red](未打开场景，无法导出)[/color]")
		return
	var topology: Dictionary = InstructionAnalyzer.build_topology(scene_root)
	var path: String = TopologyExport.export_to_json(topology, "res://fuse_reports/topology")
	if path.is_empty():
		_detail.append_text("[color=red](导出失败，见输出面板)[/color]")
	else:
		_detail.append_text("[color=gray]拓扑已导出: %s[/color]\n" % path)
```

文件头 preload 区加：`const TopologyExport := preload("res://addons/fuse/editor/topology/topology_export.gd")`。

- [ ] **Step 5: 跑测试 + CLI 冒烟**

```bash
"$GODOT" --headless --path . res://addons/fuse/tests/topology/test_export_topology.tscn ; echo v=$?
"$GODOT" --headless --path . res://addons/fuse/editor/topology/export_topology.tscn -- --scene res://demos/fuse/brickian/game_scene.tscn --out user://topology_smoke ; echo v=$?
```

Expected: 双 0；user://topology_smoke/game_scene.json 可解析。这份产物留作 Task 2 的**变更前基准**（复制到 `/tmp/topo_before.json`）。

- [ ] **Step 6: Commit**

```bash
git add addons/fuse/editor/topology/ addons/fuse/tests/topology/
git commit -m "feat: 场景拓扑 JSON 导出（TopologyExport 共享序列化 + CLI + 面板按钮）"
```

### Task 2: Runner 拓扑扫描

**Files:**
- Modify: `addons/fuse/editor/analysis/instruction_analyzer.gd`
- Modify: `addons/fuse/editor/topology/fuse_topology.gd`（runner 单元显示）
- Create: `addons/fuse/tests/topology/test_runner_topology.gd` + `.tscn`

**Interfaces:**
- Consumes: Task 1 的导出（diff 验收）
- Produces:
  - report 新字段 `kind: "trigger" | "multi" | "runner"`（所有单元必有；`topology.triggers` 键名不改——注释说明其现含 runner，消费方按 kind 判别）
  - runner report 新字段 `signal_binding: {signal_name: String, target_node: String}`
  - `static func analyze_runner(runner: Node) -> Dictionary`
  - cross_references 新类型 `"run"`（RunRunner 指令 → 目标 Runner 单元的调用边）

- [ ] **Step 1: 写失败测试（fixture 场景程序化构造）**

`addons/fuse/tests/topology/test_runner_topology.gd`：

```gdscript
# addons/fuse/tests/topology/test_runner_topology.gd
extends Node

const TriggerScript := preload("res://addons/fuse/core/trigger.gd")
const RunnerScript := preload("res://addons/fuse/core/runner.gd")
const ActionRunnerScript := preload("res://addons/fuse/core/action_runner.gd")
const SetVariable := preload("res://addons/fuse/instructions/variables/set_variable.gd")
const RunRunner := preload("res://addons/fuse/instructions/flow_control/run_runner.gd")

var _fail := 0

func _check(cond: bool, msg: String) -> void:
	if cond: print("✓ " + msg)
	else:
		_fail += 1
		push_error("✗ " + msg)

func _make_set_global(name: String, value: int) -> SetVariable:
	var inst := SetVariable.new()
	inst.target_variable = name
	inst.new_value = value
	return inst

func _ready():
	print("=== test_runner_topology ===")
	# fixture：root + 触发器（写 score + RunRunner 调 runner）+ 独立 runner（也写 score）
	var root := Node.new()
	root.name = "FixtureScene"
	add_child(root)

	var trigger := Node.new()
	trigger.name = "TrigA"
	trigger.set_script(TriggerScript)
	root.add_child(trigger)
	var ar_trig: ActionRunner = ActionRunnerScript.new()
	var run_inst := RunRunner.new()
	run_inst.target_runner = NodePath("../SpawnLogic")
	ar_trig.instructions = [ _make_set_global("score", 1), run_inst ]
	trigger.action_runner = ar_trig

	var runner := Node.new()
	runner.name = "SpawnLogic"
	runner.set_script(RunnerScript)
	root.add_child(runner)
	var ar_run: ActionRunner = ActionRunnerScript.new()
	ar_run.instructions = [ _make_set_global("score", 2) ]
	runner.action_runner = ar_run
	runner.signal_name = "spawn_requested"
	runner.target_node = NodePath("../TrigA")

	var topology: Dictionary = InstructionAnalyzer.build_topology(root)
	var kinds := {}
	var names := {}
	for report in topology.triggers:
		kinds[report.get("kind", "")] = true
		names[report.get("trigger_name", "")] = report
	_check(names.has("TrigA") and names["TrigA"].get("kind") == "trigger", "TrigA 在拓扑且 kind=trigger")
	_check(names.has("SpawnLogic") and names["SpawnLogic"].get("kind") == "runner", "SpawnLogic 在拓扑且 kind=runner")
	var sb: Dictionary = names.get("SpawnLogic", {}).get("signal_binding", {})
	_check(sb.get("signal_name", "") == "spawn_requested", "runner report 带 signal_binding")
	var run_edges: Array = topology.cross_references.filter(func(e): return e.get("type") == "run")
	_check(run_edges.any(func(e): return e.get("from") == "TrigA" and e.get("to") == "SpawnLogic"),
		"RunRunner 调用边 TrigA → SpawnLogic 存在")
	var races: Array = topology.cross_references.filter(func(e): return e.get("type") == "variable_write_to_write")
	_check(races.any(func(e): return str(e.get("detail")) == "score"), "score 双写竞态预警覆盖 runner 单元")
	root.queue_free()
	print("=== 结果: %d 失败 ===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)
```

注：fixture 属性名（`target_variable`/`new_value`/`target_runner`/`signal_name`/`target_node`）实现前先 grep 对应组件源码核实，不符则以真实为准并在报告注明。

- [ ] **Step 2: 跑测试确认失败**（SpawnLogic 不在 triggers、无 run 边）

- [ ] **Step 3: 实现分析器扩展**

`instruction_analyzer.gd`：

1. `analyze_trigger` 的 report 初始化加 `"kind": "trigger"`；MultiEventTrigger 分支（`event_bindings != null`）改 `"kind": "multi"`。
2. 新增（放在 analyze_trigger 之后）：

```gdscript
## 分析 Runner（L3 信号绑定单元）：无 event/cooldown，指令与变量分析与 Trigger 同构
static func analyze_runner(runner: Node) -> Dictionary:
	var report := {
		"trigger_name": runner.name,
		"trigger_path": str(runner.get_path()),
		"trigger_type": "Runner",
		"kind": "runner",
		"event": {},
		"event_bindings": [],
		"nodes": [],
		"variables": {"local": [], "scope": [], "global": []},
		"signals": [],
		"instructions_flat": [],
		"instructions_tree": [],
		"provided_locals": [],
		"signal_binding": {
			"signal_name": str(runner.get("signal_name") if runner.get("signal_name") != null else ""),
			"target_node": str(runner.get("target_node") if runner.get("target_node") != null else ""),
		},
	}
	var action_runner = runner.get("action_runner")
	if action_runner == null:
		return report
	_analyze_instructions(action_runner.instructions, report, "", report["instructions_tree"])
	return report
```

3. `build_topology` 在 MultiEventTrigger 收集后追加 Runner 收集与去重：

```gdscript
	# Runner（L3）单元：跳过已扫描 Trigger/MultiEventTrigger 的直接子 Runner
	# （_get_action_runner 会把 Trigger 的 Runner 子节点当动作源——那是宿主的实现细节，非独立单元）
	var scanned := {}
	for trigger in triggers:
		scanned[trigger.get_instance_id()] = true
	for runner in scene_root.find_children("*", "Runner"):
		if not runner is Runner or scanned.has(runner.get_parent().get_instance_id()):
			continue
		var report := analyze_runner(runner)
		var is_nested: bool = runner.owner != null and runner.owner != scene_root
		report["is_nested"] = is_nested
		report["scene_source"] = runner.owner.name if is_nested else "main"
		all_reports[runner.name] = report
		topology.triggers.append(report)
```

4. cross_references 增 `"run"` 边（信号关联循环之后追加）——直接对单元的指令对象做递归扫描，不依赖 report 树形状：

```gdscript
	# RunRunner 调用边：指令 target_runner 指向的 Runner 单元
	for t1_name in all_reports:
		for t2_name in all_reports:
			if t1_name == t2_name:
				continue
			if _unit_calls_unit(all_reports[t1_name], all_reports[t2_name]):
				topology.cross_references.append({
					"from": t1_name, "to": t2_name, "type": "run", "detail": "RunRunner"
				})

## 递归扫描单元指令树中的 RunRunner，target 是否指向目标单元
static func _unit_calls_unit(source: Dictionary, target: Dictionary) -> bool:
	var target_name: String = target.get("trigger_name", "")
	if target_name.is_empty():
		return false
	for arr in _collect_instruction_arrays(source):
		for inst in arr:
			if inst != null and inst.get_script() != null \
					and str(inst.get_script().get_global_name()) == "RunRunner":
				var t: String = str(inst.get("target_runner"))
				if t.contains(target_name):
					return true
	return false

## 从 report 对应的触发单元收集全部指令数组（含嵌套字段与 event_bindings）
static func _collect_instruction_arrays(report: Dictionary) -> Array:
	var arrays: Array = []
	var ar: Variant = report.get("_action_runner", null)
	# report 不携带节点引用——改由调用方传入单元数组；此处遍历 instructions_flat 建索引：
	# （见下方调整）build_topology 直接持有节点，改为对节点收集
	return arrays
```

**实现要点（比上面占位更简单的落地法）**：`_unit_calls_unit` 不从 report 取指令——`build_topology` 手里已有各节点。把 run 边构建改为对 `triggers` 节点数组复用现有的 action_runner 提取（`_get_action_runner`）+ `_NESTED_FIELDS` 递归：

```gdscript
	# RunRunner 调用边（对节点直取指令，避免 report 形状耦合）
	for t1_name in all_reports:
		var r1_node: Node = all_reports[t1_name].get("_node", null)
```

——report 不能持节点引用（JSON 导出刚建立）。**最终落地方案**：在收集阶段维护 `var node_by_name := {}`（t1_name → Node），run 边构建循环里用 `node_by_name[t1_name]` 取节点 → `_get_action_runner(node)` → 递归 `_NESTED_FIELDS` 找 RunRunner → `target_runner` 含 t2_name 即成边。`node_by_name` 是 build_topology 的局部变量，不进 topology 返回值。

- [ ] **Step 4: UI 显示 runner**

`fuse_topology.gd` 的 `_create_trigger_tree_item`（:330）开头改为：

```gdscript
	var tname: String = report.get("trigger_name", "?")
	var ttype: String = report.get("trigger_type", "?")
	var event_info: Dictionary = report.get("event", {})
	var kind: String = report.get("kind", "trigger")

	var t_item: TreeItem = _tree.create_item(parent_item)
	t_item.set_text(0, "%s (%s)" % [tname, ttype])
	if kind == "runner":
		var sb: Dictionary = report.get("signal_binding", {})
		t_item.set_text(1, sb.get("signal_name", ""))
		t_item.set_custom_color(0, Color(0.6, 0.9, 0.7))
	else:
		t_item.set_text(1, event_info.get("resource_name", ""))
	t_item.set_metadata(0, {"type": "trigger", "report": report})
```

（runner 无 bindings，走普通指令树分支自然成立。）

- [ ] **Step 5: 跑测试 + 前后 diff 验收**

```bash
"$GODOT" --headless --path . res://addons/fuse/tests/topology/test_runner_topology.tscn ; echo v=$?
"$GODOT" --headless --path . res://addons/fuse/editor/topology/export_topology.tscn -- --scene res://demos/fuse/brickian/game_scene.tscn --out user://topology_after
# 对比 /tmp/topo_before.json 与 user://topology_after/game_scene.json：
# 预期 diff = 新增 SpawnLogic 等 runner 单元（kind=runner）+ 新 run 边 + 变量分析覆盖扩大；既有 trigger 条目内容不变
```

既有单元条目若出现内容变化 → 停下调查（不应有）。

- [ ] **Step 6: 回归 + Commit**

```bash
"$GODOT" --headless --path . res://addons/fuse/tests/topology/test_export_topology.tscn ; echo v=$?
git add addons/fuse/editor/analysis/instruction_analyzer.gd addons/fuse/editor/topology/fuse_topology.gd addons/fuse/tests/topology/
git commit -m "feat: 拓扑扫描覆盖 Runner 单元（kind 判别 + signal_binding + RunRunner 调用边 + 竞态覆盖）"
```

### Task 3: 拓扑搜索过滤

**Files:**
- Modify: `addons/fuse/editor/topology/fuse_topology.gd`
- Create: `addons/fuse/tests/topology/test_topology_filter.gd` + `.tscn`

**Interfaces:**
- Produces: `static func report_matches_filter(report: Dictionary, text: String) -> bool`（static 可测；空 text 恒 true）——匹配面：单元名、三层变量名、binding 变量名、指令类型名（instructions_flat + instructions_tree 递归）、signal_binding.signal_name、signals[].signal

- [ ] **Step 1: 写失败测试**

```gdscript
# addons/fuse/tests/topology/test_topology_filter.gd（骨架同前两个测试，_ready 调两个用例）
func _report_fixture() -> Dictionary:
	return {
		"trigger_name": "TrigA", "kind": "trigger",
		"variables": {"local": [], "scope": [], "global": [{"name": "score", "mode": "write"}]},
		"instructions_flat": [{"name": "RunRunner"}, {"name": "SetVariable"}],
		"instructions_tree": [{"name": "IfThen", "children": {}}],
		"signals": [{"signal": "pressed", "target": "../Btn"}],
		"signal_binding": {"signal_name": "spawn_requested", "target_node": ""},
		"event_bindings": [],
	}

func _test_match() -> void:
	var r := _report_fixture()
	var F := preload("res://addons/fuse/editor/topology/fuse_topology.gd")
	_check(F.report_matches_filter(r, ""), "空文本恒过")
	_check(F.report_matches_filter(r, "triga"), "单元名大小写不敏感")
	_check(F.report_matches_filter(r, "score"), "变量名命中")
	_check(F.report_matches_filter(r, "runrunner"), "flat 指令类型命中")
	_check(F.report_matches_filter(r, "ifthen"), "树指令类型命中")
	_check(F.report_matches_filter(r, "spawn_requested"), "signal_binding 命中")
	_check(F.report_matches_filter(r, "pressed"), "signals 命中")
	_check(not F.report_matches_filter(r, "nosuchthing"), "无命中不过")
```

（注：instructions_flat/tree 条目的类型字段名以 Task 2 实测为准——若为 `"type"` 改用之，报告注明。）

- [ ] **Step 2: 跑测试确认失败**（static 函数不存在）

- [ ] **Step 3: 实现匹配函数 + UI 接线**

`fuse_topology.gd`：

1. banner 问题过滤下拉之后加搜索框：

```gdscript
	_search_input = LineEdit.new()
	_search_input.placeholder_text = "搜索：单元 / 指令 / 变量"
	_search_input.custom_minimum_size = Vector2(180, 0)
	_search_input.text_changed.connect(_on_search_changed)
	banner.add_child(_search_input)
```

（成员变量区加 `var _search_input: LineEdit`、`var _filter_text := ""`。）

```gdscript
func _on_search_changed(text: String) -> void:
	_filter_text = text
	_refresh_timer.start()  # 复用既有防抖
```

2. static 匹配函数（可测、无 UI 依赖）：

```gdscript
## 搜索过滤：单元名 / 变量名 / 指令类型 / 信号名（大小写不敏感；空文本恒过）
static func report_matches_filter(report: Dictionary, text: String) -> bool:
	if text.is_empty():
		return true
	var needle := text.to_lower()
	if str(report.get("trigger_name", "")).to_lower().contains(needle):
		return true
	var sb: Dictionary = report.get("signal_binding", {})
	if str(sb.get("signal_name", "")).to_lower().contains(needle):
		return true
	for sig in report.get("signals", []):
		if str(sig.get("signal", "")).to_lower().contains(needle):
			return true
	for scope in ["local", "scope", "global"]:
		for v in report.get("variables", {}).get(scope, []):
			var vn: Variant = v.get("name", v) if v is Dictionary else v
			if str(vn).to_lower().contains(needle):
				return true
	for binding in report.get("event_bindings", []):
		for scope in ["local", "scope", "global"]:
			for v in binding.get("variables", {}).get(scope, []):
				var bvn: Variant = v.get("name", v) if v is Dictionary else v
				if str(bvn).to_lower().contains(needle):
					return true
	if _tree_has(report.get("instructions_flat", []), needle):
		return true
	return _tree_has(report.get("instructions_tree", []), needle)

static func _tree_has(entries: Array, needle: String) -> bool:
	for entry in entries:
		if entry is Dictionary:
			var n := str(entry.get("name", entry.get("type", "")))
			if n.to_lower().contains(needle):
				return true
			for child_list in entry.get("children", {}).values():
				if child_list is Array and _tree_has(child_list, needle):
					return true
	return false
```

3. `refresh()` 的主/嵌套分组填充处应用过滤（main_reports 收集与 nested_groups 填充时）：

```gdscript
	# 在「填充 Trigger 列表」循环处对每个 report 先判：
	if not report_matches_filter(report, _filter_text):
		continue
```

（嵌套分组在过滤后为空时跳过该组：`if nested_groups[source].is_empty(): continue`——分组循环填充前再过滤一次或收集时统一过滤。空结果时树显示 "(无匹配)" 提示项。）

- [ ] **Step 4: 跑测试 + 解析冒烟 + Commit**

```bash
"$GODOT" --headless --path . res://addons/fuse/tests/topology/test_topology_filter.tscn ; echo v=$?
git add addons/fuse/editor/topology/fuse_topology.gd addons/fuse/tests/topology/
git commit -m "feat: 拓扑面板搜索过滤（单元/指令/变量/信号，static 匹配函数可测）"
```

（UI 接线无法 headless 测——以测试覆盖匹配逻辑 + 脚本解析零错为准，编辑器内人工验证留给采用时。）

### 收尾：全量回归

```bash
# 既有 8 项闭环门禁不回归（本计划不触碰 preset_ai/core，应全绿）
# + 三个新测试场景全绿
```

---

## Self-Review 记录

- **覆盖核查**：#3→Task 1、#2→Task 2、#1→Task 3；导出双入口（CLI+按钮）与共享序列化在 Task 1；runner 去重、kind、run 边、竞态覆盖在 Task 2；搜索匹配面（六类目标）在 Task 3。无缺口。
- **占位符扫描**：Task 2 Step 3 的 `_unit_calls_unit` 初稿有意识地演示了错误方向并立即给出最终落地法（node_by_name 局部映射 + `_get_action_runner` + `_NESTED_FIELDS` 递归）——实现者按"最终落地方案"段执行。fixture 属性名标注"以 grep 实测为准"。
- **类型一致性**：`kind` 三值在 Task 2 定义、Task 3 消费（signal_binding 分支）；`TopologyExport.sanitize_for_json/export_to_json` 签名 Task 1 定、Task 2 复用（diff 验收）；`report_matches_filter(report, text)` static 无 UI 依赖。
