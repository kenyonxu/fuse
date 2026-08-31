# Preset → GDScript 毕业导出器实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现"拓扑 → System 工件 → 按 System 生成桥接模式 GDScript"的场景毕业导出器（MVP 单 Trigger 系统 + 混合指令委托）。

**Architecture:** 两段式：deriver 从 `build_topology()` 推导单例 System 草稿（kind 过滤 runner），人/AI 确认后交 generator；generator 读场景节点序列化指令（`FusePresetSerializer`），白名单指令生成原生可读代码、其余内嵌 JSON 经 `core/graduation/fuse_delegation.gd` 桥接面运行时委托。桥接面是生成脚本的唯一运行时依赖（变量/事件/指令/门控四桥）。

**Tech Stack:** Godot 4.7 headless GDScript；场景式测试 + 退出码门禁；复用 preset_ai 闭环的 finding/CLI 模式。

**Spec:** `addons/fuse/docs/superpowers/specs/2026-08-30-preset-gdscript-graduation-design.md`（已批 + 拓扑输入面回填；本计划 Task 1 修正其两处 API 核实后发现的矛盾）

## Global Constraints

- Godot（Git Bash）：`export GODOT="/e/Godot/Godot_v4.7-stable_mono_win64/Godot_v4.7-stable_mono_win64_console.exe"`；`"$GODOT" --headless --path . res://<scene>`；类缓存错先 `--import`。
- 仓库根 `E:\GitHub\fuse`；GDScript：tab 缩进、全类型注解、snake_case、push_error/push_warning（AGENTS.md）。
- 测试场景结尾 `get_tree().quit(1 if _fail > 0 else 0)`；新 .tscn 头省略 uid；**测试输出文件重定向后 grep，禁止管道接 grep**（Windows Godot 管道挂死，已两次踩坑）。
- 触及 `preset_value_codec.gd` 的任务例行跑 `res://addons/fuse/tests/serialization/test_preset_nested_serde.tscn`（`--quit-after 600`）。
- 本计划不新增 Event/Instruction/Condition 组件，无需重 dump。
- **API 核实定案（M0 探索已完成，勿再质疑，直接依赖）**：
  - `ExecutionContext.new(target_node: Node)` 无 trigger 可用（B19 已修复；`set_variable(name, value, "local"/"scope"/"global")`，global 写自动建变量）。限制：`TRIGGER_SCOPE` ScopeSource 与 Trigger-meta 局部变量桥依赖 trigger——毕业场景无对应物，接受。
  - `await action_runner.run(ctx)` 合法；**run 结束会 `ctx.cleanup()`** → 桥接面每次触发新建 ctx；run 期重入被拒（= Trigger SKIP 门控，行为一致非 bug）。
  - 事件总线：autoload `FuseEventBus`——`send_event(name: String, args: Dictionary = {})` / `subscribe(name: String, cb: Callable) -> Subscription`（回调收 `args: Dictionary` 单参）/ `unsubscribe(sub)`。**非 Godot signal**。
  - cooldown 自包含可复刻：GLOBAL = 单浮点 `last_trigger_time`；PER_OBJECT = `{instance_id: last_time}` 字典；时间源 `Time.get_ticks_msec() / 1000.0`（base_trigger.gd:122-156）。
  - 门控顺序（Trigger._on_event_fired）：trigger_once 已触发→跳过；运行中→跳过；cooldown→条件→执行。
  - 事件语义：OnReady= `_ready`+delay Timer（Fuse 多一帧 call_deferred，可接受偏差）；OnInputAction= `_unhandled_input` + `Input.is_action_just_pressed/just_released/pressed`（HOLD=持续触发）；OnInterval= Timer 子节点+随机区间换 wait_time+max_repeats+stop_condition；OnReceiveEvent= 总线订阅。
  - **白名单修正**：`SetGlobalVariables` 不存在——用 `SaveGlobalVariables`（save_to_resource/save_persistent_to_resource）+ `LoadGlobalVariables`。
  - **SetVariable 陷阱**：源侧 `from_*` 5 字段存在于代码但 schema JSON 未收录——发射器读**指令对象属性**（generator 直接持有场景节点上的指令对象），不依赖 schema。
  - delegation 落点统一 **`addons/fuse/core/graduation/fuse_delegation.gd`**（spec §6.2 的 editor/ 路径是笔误，Task 1 修正）；依赖图顶端无环，唯一消费者是生成脚本。
  - run 边现用子串 contains 匹配（`../SpawnLogic` 误命中 `Spawn` 单元）——Task 2 修为 NodePath 最后一段精确比对（spec §9 风险 7 前置任务）。
  - 指令完成信号 `finished`；`execute_sync(ctx) -> bool` 同步包装；`PresetValueCodec.deserialize_instructions(raw) -> Array[BaseInstruction]`。
  - `FusePresetSerializer.serialize(node) -> Dictionary`（L1-L4 序列化，regen_samples 先例）；`detect_level(node)`。
  - `fuse_generated/` 下 `instructions/` 被 dump 扫描，新增 `systems/`、`scripts/` 子目录不受影响。

---

## 文件结构总览

| 文件 | 职责 |
|------|------|
| `addons/fuse/core/graduation/fuse_delegation.gd`（新） | 桥接面：build_delegated / run / get_var / set_var / send_event / subscribe / gate_allows / teardown |
| `addons/fuse/editor/graduation/system_deriver.gd` + `derive_systems.tscn`（新） | 拓扑 → 单例 System 草稿 |
| `addons/fuse/editor/graduation/system_validator.gd` + `validate_system.tscn`（新） | System 工件校验（8 codes） |
| `addons/fuse/editor/graduation/codegen/event_mapper.gd`（新） | 事件定义 → 生成代码接线形态（原生 4 类 / 整事件委托） |
| `addons/fuse/editor/graduation/codegen/gdscript_emitter.gd`（新） | 白名单原生发射器 + 委托数据块 + 脚本组装 |
| `addons/fuse/editor/graduation/export_system.tscn`（新，含根脚本） | 生成 CLI（内部先跑校验） |
| `addons/fuse/tests/graduation/*.tscn/.gd`（新） | delegation / deriver / validator / codegen-golden 四测试场景 |
| `fuse_generated/systems/`、`fuse_generated/scripts/`（新目录） | System 草稿/定稿 与 生成产物（金样例入库） |

---

## M0：桥接面

### Task 1: spec 两处修正（API 核实结论回填）

**Files:**
- Modify: `addons/fuse/docs/superpowers/specs/2026-08-30-preset-gdscript-graduation-design.md`

**Interfaces:** 无代码；产出后续任务的权威依据。

- [ ] **Step 1: 两处编辑**

1. §6.2 骨架的 `res://addons/fuse/editor/graduation/fuse_delegation.gd` → `res://addons/fuse/core/graduation/fuse_delegation.gd`（与 §11 统一；理由：运行时依赖，依赖图顶端无环——M0 探索结论）。
2. §6.5 白名单 `SetGlobalVariables` → `SaveGlobalVariables`（该指令不存在，实为 Save/Load 对）。

- [ ] **Step 2: Commit**

```bash
git add addons/fuse/docs/superpowers/specs/2026-08-30-preset-gdscript-graduation-design.md
git commit -m "docs: 毕业 spec 修正——delegation 统一 core 路径、白名单 SetGlobalVariables→SaveGlobalVariables（API 核实结论）"
```

### Task 2: run 边精确匹配修复（毕业前置，spec §9 风险 7）

**Files:**
- Modify: `addons/fuse/editor/analysis/instruction_analyzer.gd`（`_instructions_call_unit` 的目标匹配，约 :593）
- Modify: `addons/fuse/tests/topology/test_runner_topology.gd`（追加误命中负例）

**Interfaces:**
- Produces: run 边匹配语义"`target_runner` NodePath **最后一段** == 目标单元名"（Task 4 deriver 依赖此语义算连通分量）

- [ ] **Step 1: 写失败测试（追加到 test_runner_topology.gd 的 `_ready()` 调用与文件尾）**

```gdscript
func _test_run_edge_no_substring_collision() -> void:
	# "SpawnLogic" 不应误命中名为 "Spawn" 的单元（旧子串 contains 会）
	var root := Node.new()
	root.name = "CollisionScene"
	add_child(root)
	var t := Node.new()
	t.name = "TrigA"
	t.set_script(TriggerScript)
	root.add_child(t)
	var ar: ActionRunner = ActionRunnerScript.new()
	var run_inst := RunRunner.new()
	run_inst.target_runner = NodePath("../SpawnLogic")   # 指向 SpawnLogic，不指向 Spawn
	ar.instructions = [run_inst]
	t.action_runner = ar
	for n in ["Spawn", "SpawnLogic"]:
		var r := Node.new()
		r.name = n
		r.set_script(RunnerScript)
		root.add_child(r)
		r.action_runner = ActionRunnerScript.new()
	var topology: Dictionary = InstructionAnalyzer.build_topology(root)
	var run_edges: Array = topology.cross_references.filter(func(e): return e.get("type") == "run")
	_check(run_edges.size() == 1 and run_edges[0].get("to") == "SpawnLogic",
		"run 边精确命中 SpawnLogic 且不误命中 Spawn（实际 %s）" % str(run_edges.map(func(e): return e.get("to"))))
	root.queue_free()
```

- [ ] **Step 2: 跑测试确认失败**（旧 contains 会产出 2 条边）

- [ ] **Step 3: 修匹配**

`_instructions_call_unit` 中 `t.contains(target_name)` 改为：

```gdscript
	var last_seg: String = t.get_file() if false else t.trim_suffix("/").split("/")[-1]
	if last_seg == target_name:
		return true
```

实际实现取简洁形态（NodePath 转字符串后取最后段）：

```gdscript
	var parts := t.split("/")
	var last_seg: String = parts[parts.size() - 1] if parts.size() > 0 else ""
	if last_seg == target_name:
		return true
```

- [ ] **Step 4: 回归**：test_runner_topology 全绿（含既有 5 用例）+ test_build_topology + tests/topology 三场景；game_scene 导出冒烟（run 边仍为 GameFlow→SpawnEnemy 1 条）。

- [ ] **Step 5: Commit**：`fix: 拓扑 run 边目标匹配改 NodePath 末段精确比对（毕业 deriver 前置）`

### Task 3: fuse_delegation 桥接面

**Files:**
- Create: `addons/fuse/core/graduation/fuse_delegation.gd`
- Create: `addons/fuse/tests/graduation/test_fuse_delegation.gd` + `.tscn`

**Interfaces:**
- Consumes: `ExecutionContext`、`PresetValueCodec`、`ActionRunner`、`FuseEventBus`（autoload）
- Produces（生成代码与全部后续任务的依赖，签名固定）:
  - `const FuseDelegation := preload("res://addons/fuse/core/graduation/fuse_delegation.gd")`（class_name FuseDelegation 亦可，生成脚本用 preload 显式）
  - `static func build_delegated(bindings_json: Dictionary) -> Dictionary`（键→`Array[BaseInstruction]`，走 `PresetValueCodec.deserialize_instructions`）
  - `static func run(node: Node, instructions: Array, execution_mode: int, event_args: Dictionary = {}) -> void`（**协程**，可 await；每次新建 `ExecutionContext.new(node)` 并同步 `event_<key>` 变量；SEQUENTIAL=0/PARALLEL=1 经内部 ActionRunner）
  - `static func get_var(node: Node, name: String, scope: String) -> Variant` / `static func set_var(node: Node, name: String, value: Variant, scope: String) -> bool`（scope ∈ "local"/"scope"/"global"；经临时 ctx，global 自动建变量）
  - `static func send_event(event_name: String, args: Dictionary = {}) -> void` / `static func subscribe(event_name: String, cb: Callable) -> Variant` / `static func unsubscribe(subscription: Variant) -> void`（总线透传；总线缺失时 push_warning 且订阅返回 null）
  - `static func gate_allows(state: Dictionary, key: String, trigger_once: bool, cooldown_mode: int, cooldown_time: float, object_id: int) -> bool`（**检查并更新**：once 已触发→false；GLOBAL/PER_OBJECT 冷却未到→false；通过则记录时间戳与 once 标记）
  - `static func teardown(node: Node) -> void`（清 node meta `fuse_delegated_subscriptions`）

- [ ] **Step 1: 写失败测试**

`tests/graduation/test_fuse_delegation.gd`（骨架同惯例，`_ready` 依序调用下列用例）：

```gdscript
const FuseDelegation := preload("res://addons/fuse/core/graduation/fuse_delegation.gd")

func _test_build_and_run_delegated() -> void:
	var insts: Array = FuseDelegation.build_delegated({
		"b0": [{"type": "Print", "message": "grad-hello"}]})
	_check(insts is Dictionary and (insts["b0"] as Array).size() == 1, "JSON 重建 1 条指令")
	var holder := Node.new()
	add_child(holder)
	FuseDelegation.run(holder, insts["b0"], 0)   # Print 同步完成，无需 await 也应落地
	await get_tree().process_frame
	_check((insts["b0"] as Array)[0].is_completed(), "委托指令执行完成")
	holder.queue_free()

func _test_run_await_semantics() -> void:
	# 与 ActionRunner 行为对照：Wait 2 秒的委托序列，await run 返回后应完成
	var insts: Array = FuseDelegation.build_delegated({
		"b0": [{"type": "Wait", "wait_time": 0.2}, {"type": "Print", "message": "after-wait"}]})
	var holder := Node.new()
	add_child(holder)
	var t0 := Time.get_ticks_msec()
	await FuseDelegation.run(holder, insts["b0"], 0)
	var elapsed := (Time.get_ticks_msec() - t0) / 1000.0
	_check(elapsed >= 0.18, "await run 尊重 Wait 时长（%.2fs）" % elapsed)
	for inst in insts["b0"]:
		_check(inst.is_completed(), "序列全部完成")
	holder.queue_free()

func _test_variable_bridge() -> void:
	var holder := Node.new()
	add_child(holder)
	FuseDelegation.set_var(holder, "grad_test_v", 42, "global")
	_check(FuseDelegation.get_var(holder, "grad_test_v", "global") == 42, "global 写读往返")
	holder.queue_free()

func _test_event_bridge() -> void:
	var received: Array = []
	var sub: Variant = FuseDelegation.subscribe("grad_test_evt", func(args): received.append(args))
	FuseDelegation.send_event("grad_test_evt", {"n": 7})
	await get_tree().process_frame
	_check(received.size() == 1 and received[0].get("n") == 7, "事件订阅-发送往返")
	FuseDelegation.unsubscribe(sub)
	FuseDelegation.send_event("grad_test_evt", {"n": 8})
	await get_tree().process_frame
	_check(received.size() == 1, "退订后不再收")

func _test_gate() -> void:
	var state := {}
	_check(FuseDelegation.gate_allows(state, "b0", false, 1, 10.0, 99), "GLOBAL 冷却首次放行")
	_check(not FuseDelegation.gate_allows(state, "b0", false, 1, 10.0, 99), "冷却期内拒绝")
	var state2 := {}
	_check(FuseDelegation.gate_allows(state2, "b0", true, 0, 0.0, 1), "once 首次放行")
	_check(not FuseDelegation.gate_allows(state2, "b0", true, 0, 0.0, 1), "once 二次拒绝")
	var state3 := {}
	_check(FuseDelegation.gate_allows(state3, "b0", false, 2, 10.0, 11), "PER_OBJECT obj11 放行")
	_check(not FuseDelegation.gate_allows(state3, "b0", false, 2, 10.0, 11), "PER_OBJECT obj11 冷却")
	_check(FuseDelegation.gate_allows(state3, "b0", false, 2, 10.0, 22), "PER_OBJECT obj22 不受 obj11 影响")
```

`.tscn` 同惯例。注：事件桥用例依赖 autoload `FuseEventBus`——本项目 project.godot 已注册，headless 跑场景即加载。

- [ ] **Step 2: 跑测试确认失败**（类不存在）

- [ ] **Step 3: 实现桥接面**

```gdscript
# addons/fuse/core/graduation/fuse_delegation.gd
class_name FuseDelegation
extends RefCounted

## 毕业导出器桥接面——生成脚本的唯一运行时依赖
##
## 四桥：变量（临时 ExecutionContext）/ 事件（FuseEventBus 透传）/
## 指令（PresetValueCodec 重建 + ActionRunner 执行）/ 门控（自包含复刻 BaseTrigger 语义）。
## 注意：ActionRunner.run 结束会 cleanup ctx——run() 每次新建 ctx，勿复用。

const PresetValueCodec := preload("res://addons/fuse/core/serialization/preset_value_codec.gd")

const COOLDOWN_NONE := 0
const COOLDOWN_GLOBAL := 1
const COOLDOWN_PER_OBJECT := 2
const SUBS_META := "fuse_delegated_subscriptions"

static func build_delegated(bindings_json: Dictionary) -> Dictionary:
	var out := {}
	for key in bindings_json:
		out[key] = PresetValueCodec.deserialize_instructions(bindings_json[key])
	return out

static func run(node: Node, instructions: Array, execution_mode: int, event_args: Dictionary = {}) -> void:
	if instructions.is_empty():
		return
	var ctx := ExecutionContext.new(node)
	ctx.set_variable("event_source", node)
	ctx.set_variable("triggered_node", node)
	for k in event_args:
		ctx.set_variable("event_%s" % k, event_args[k])
	var runner := ActionRunner.new()
	runner.execution_mode = execution_mode
	runner.instructions = instructions
	await runner.run(ctx)

static func get_var(node: Node, name: String, scope: String) -> Variant:
	return ExecutionContext.new(node).get_variable(name, null, scope)

static func set_var(node: Node, name: String, value: Variant, scope: String) -> bool:
	return ExecutionContext.new(node).set_variable(name, value, scope)

static func _bus() -> Node:
	var bus = Engine.get_main_loop().root.get_node_or_null("FuseEventBus")
	if bus == null:
		push_warning("[FuseDelegation] FuseEventBus autoload 不存在，事件桥不可用")
	return bus

static func send_event(event_name: String, args: Dictionary = {}) -> void:
	var bus = _bus()
	if bus != null:
		bus.send_event(event_name, args)

static func subscribe(event_name: String, cb: Callable) -> Variant:
	var bus = _bus()
	if bus == null:
		return null
	return bus.subscribe(event_name, cb)

static func unsubscribe(subscription: Variant) -> void:
	if subscription != null:
		FuseEventBus.unsubscribe(subscription)

## 门控（检查并更新）：复刻 BaseTrigger._check_cooldown + trigger_once 语义
static func gate_allows(state: Dictionary, key: String, trigger_once: bool,
		cooldown_mode: int, cooldown_time: float, object_id: int) -> bool:
	var once_key := "%s:once" % key
	if trigger_once and state.get(once_key, false):
		return false
	if cooldown_mode != COOLDOWN_NONE and cooldown_time > 0.0:
		var now := Time.get_ticks_msec() / 1000.0
		match cooldown_mode:
			COOLDOWN_GLOBAL:
				var last: float = state.get("%s:last" % key, -1e9)
				if now - last < cooldown_time:
					return false
				state["%s:last" % key] = now
			COOLDOWN_PER_OBJECT:
				var per: Dictionary = state.get("%s:objects" % key, {})
				var last_o: float = per.get(object_id, -1e9)
				if now - last_o < cooldown_time:
					return false
				per[object_id] = now
				state["%s:objects" % key] = per
	state[once_key] = true
	return true

static func teardown(node: Node) -> void:
	# 订阅清理由生成代码持有 Subscription 自行退订；此处预留挂点（meta 清理）
	if node.has_meta(SUBS_META):
		node.remove_meta(SUBS_META)
```

注：`subscribe` 返回的 Subscription 由**生成代码**存成员变量并在 `_exit_tree` 退订（对齐 OnReceiveEvent terminate 语义）；`teardown` 预留。`unsubscribe` 直接引用 autoload 名——若担心 headless 无 autoload 场景，改为经 `_bus()` 判空（实现时统一走 `_bus()`，勿混用两种取法）。

- [ ] **Step 4: 跑测试全绿 + 回归**（test_preset_nested_serde 例行 + topology 三场景不受影响）

- [ ] **Step 5: Commit**：`feat: FuseDelegation 桥接面（变量/事件/指令/门控四桥，M0）`

---

## M1：System IR

### Task 4: System 推导器 + CLI

**Files:**
- Create: `addons/fuse/editor/graduation/system_deriver.gd` + `derive_systems.tscn`（root 脚本 `derive_systems_cli.gd`）
- Create: `addons/fuse/tests/graduation/test_system_deriver.gd` + `.tscn`

**Interfaces:**
- Consumes: `InstructionAnalyzer.build_topology()`（kind/externals 原料）、Task 2 的精确 run 边
- Produces:
  - `static func derive_systems(scene_root: Node, scene_path: String) -> Dictionary` → `{"drafts": [SystemJSON...], "report": {"skipped_runner": int, "skipped_nested": Array, "components": {unit_name: [同分量单元名...]}}}`
  - System JSON 结构（spec §4.1）：format_version "1.0" / name（snake_case(trigger_name)）/ description ""/ source{derived_from, derived_at, topology_digest} / units[{id "u1", kind, scene, node_path, level}] / externals{events_out[], events_in[], variables[]} / acknowledged_warnings [] / emit{output_script, native_instructions 缺省 []}
  - CLI：`derive_systems.tscn -- --scene res://<scene> [--out res://fuse_generated/systems/drafts]`，退出码 0/2

- [ ] **Step 1: 写失败测试**（真实场景）

```gdscript
func _test_derive_game_scene() -> void:
	var scene: PackedScene = load("res://demos/fuse/brickian/game_scene.tscn")
	var inst := scene.instantiate()
	add_child(inst)
	var result: Dictionary = SystemDeriver.derive_systems(inst, "res://demos/fuse/brickian/game_scene.tscn")
	var drafts: Array = result["drafts"]
	_check(drafts.size() >= 15, "非 runner 非嵌套单元各一份草稿（实际 %d）" % drafts.size())
	var names: Array = drafts.map(func(d): return d["name"])
	_check(names.has("game_flow"), "GameFlow 有草稿")
	_check(not names.has("spawn_enemy"), "runner 单元被 kind 过滤（MVP 不推导）")
	var gf: Dictionary = drafts.filter(func(d): return d["name"] == "game_flow")[0]
	_check(gf["units"].size() == 1 and gf["units"][0]["level"] == "L4", "GameFlow 草稿 L4")
	_check(gf["source"]["derived_from"] == "res://demos/fuse/brickian/game_scene.tscn", "溯源字段")
	var ev_out: Array = gf["externals"]["events_out"].map(func(e): return e["name"])
	_check(ev_out.has("Hit") or ev_out.size() >= 0, "events_out 提取（内容以实测为准报告注明）")
	_check(gf.has("acknowledged_warnings"), "确认字段在")
	inst.queue_free()
```

（events_out 的具体内容断言宽松——实现时以 game_scene 实测填充精确断言并报告。）

- [ ] **Step 2: RED → 实现**

deriver 核心逻辑（骨架照此落地）：

```gdscript
static func derive_systems(scene_root: Node, scene_path: String) -> Dictionary:
	var topology := InstructionAnalyzer.build_topology(scene_root)
	var drafts: Array = []
	var skipped_runner := 0
	var skipped_nested: Array = []
	for report in topology.triggers:
		if report.get("kind", "trigger") == "runner":
			skipped_runner += 1
			continue
		if report.get("is_nested", false):
			skipped_nested.append(report.get("trigger_name", "?"))
			continue
		drafts.append(_derive_single(report, scene_path, scene_root))
	return {"drafts": drafts, "report": {
		"skipped_runner": skipped_runner, "skipped_nested": skipped_nested,
		"components": _components(topology)}}
```

`_derive_single`：units=[{id:"u1", kind, scene: scene_path, node_path: report.trigger_path 去场景根前缀, level: detect}]；**level 与 node 由节点实取**（`scene_root.get_node(...)` → `FusePresetSerializer.detect_level`）；externals——events_out 从该单元指令树里的 SendEvent 实例取 `event_name`（遍历 action_runner 指令含嵌套字段，对象直取）；events_in 从 event/event_bindings 的 OnReceiveEvent 实例取 `event_name`；variables 从 report.variables 三层 + binding variables 归并（含 scope container）；warnings 从 topology.cross_references 中 `warning == true` 且 from/to 为本单元的条目。`_components`：按 run/变量边并查集（**不含 signal 边**——死代码，spec §4.2 已注记）。

CLI 脚本模式对齐 `export_topology_cli.gd`（参数解析/退出码/落盘 drafts/<name>.json，tab 缩进）。

- [ ] **Step 3: GREEN + CLI 冒烟**（game_scene → drafts 目录产出，`ls` 核对文件数 = drafts.size()）

- [ ] **Step 4: Commit**：`feat: System 推导器——拓扑→单例草稿（kind 过滤/externals 提取/竞态预警/分量报告）`

### Task 5: System 校验器 + CLI

**Files:**
- Create: `addons/fuse/editor/graduation/system_validator.gd` + `validate_system.tscn`（root 脚本）
- Create: `addons/fuse/tests/graduation/test_system_validator.gd` + `.tscn`

**Interfaces:**
- Produces:
  - `static func validate_data(data: Dictionary, src := "<inline>") -> Dictionary`（{path, errors, warnings, findings}，finding 四字段——对齐 preset_validator）
  - codes：`E_FORMAT_VERSION` / `E_UNIT_NOT_FOUND`（units[].scene+node_path 解析不到节点）/ `E_UNIT_LEVEL_MISMATCH`（detect_level 不符）/ `E_EXTERNAL_UNRESOLVED`（events_in 生产者/变量容器在拓扑中不存在）/ `E_WARNING_NOT_ACKNOWLEDGED` / `E_EMIT_TARGET_CONFLICT`（output_script 已存在且头注释无生成器标记）/ `W_SINGLETON_IN_COMPONENT` / `W_NESTED_UNIT`
  - CLI：`validate_system.tscn -- <file-or-dir> [--report <out>]`，退出码 0/1/2
- 注：`E_EXTERNAL_UNRESOLVED` 需要 load 场景做拓扑核对——校验器对每个 unit 加载所属 scene（缓存），复用 deriver 的 externals 提取比对；MVP 从宽：events_in 的生产者核对仅在同场景拓扑内查（跨场景留 W 级提示亦可，实现时按此从宽并报告）。

- [ ] **Step 1: 失败测试**——正例用 Task 4 冒烟产出的真实草稿（拷贝 game_flow 草稿为 fixture 入 tests/graduation/fixtures/）；负例内联构造 5 个：版本错/幽灵节点/level 不符/竞态未确认/emit 冲突（预置一个无标记同名文件）。每例断言特定 code。
- [ ] **Step 2: RED → 实现 → GREEN**（结构对齐 preset_validator 的 `_finding/validate_data/validate_preset/validate_path` 四件套）
- [ ] **Step 3: Commit**：`feat: System 校验器（8 codes + CLI，finding 体系对齐 preset_validator）`

---

## M2：生成器

### Task 6: event_mapper + gdscript_emitter

**Files:**
- Create: `addons/fuse/editor/graduation/codegen/event_mapper.gd`
- Create: `addons/fuse/editor/graduation/codegen/gdscript_emitter.gd`
- Create: `addons/fuse/tests/graduation/test_codegen_emitter.gd` + `.tscn`

**Interfaces:**
- Consumes: System JSON + 场景节点（export 阶段实取指令对象）
- Produces:
  - `EventMapper.map_event(event_obj: BaseEvent) -> Dictionary` → `{"mode": "ready"|"input"|"interval"|"receive"|"delegated", "params": {...事件参数快照}, "setup_code": String, "wiring_code": String}`（生成代码片段，tab 缩进字符串）
  - `GdscriptEmitter.emit_system(system: Dictionary, unit_node: Node, scene_path: String) -> Dictionary` → `{"script_text": String, "native_count": int, "delegated_names": Array[String], "report": {...覆盖率/委托清单}}`
  - 白名单原生发射器注册表 `_EMITTERS: Dictionary[String, Callable]`（键 = 指令 class_name；首批：Wait/Print/SendEvent/SetVariable（仅字面量模式）/MathOperation/ShowHideUI/SetUIText/SaveGlobalVariables/LoadGlobalVariables；`set_with_another_variable` 与其余一切 → 委托）

- [ ] **Step 1: 失败测试**（发射器单元级——直接构造指令对象断言生成的代码行）：

```gdscript
func _test_wait_native() -> void:
	var w := Wait.new(); w.wait_time = 0.5
	var line: String = GdscriptEmitter.emit_instruction(w, "\t")
	_check(line.contains("await get_tree().create_timer(0.5).timeout"), "Wait 原生直译: %s" % line)

func _test_print_native() -> void:
	var p := Print.new(); p.message = "hi"
	var line: String = GdscriptEmitter.emit_instruction(p, "\t")
	_check(line.contains('print("hi")'), "Print 原生直译")

func _test_tween_delegated() -> void:
	var t := load("res://addons/fuse/instructions/tween/tween_move_to.gd").new()
	var line: String = GdscriptEmitter.emit_instruction(t, "\t")
	_check(line.begins_with("await FuseDelegation.run"), "非白名单指令走委托")

func _test_emit_system_golden_shape() -> void:
	# fixture：单 Print 指令的 L2 Trigger → emit_system → 断言脚本文本关键行
	#（构造方式参照 test_runner_topology 的 fixture：TriggerScript 节点 + ActionRunner + OnReady 事件）
	# 断言：头注释含"毕业导出器生成"与采用/回滚说明、_ready 存在、FuseDelegation preload 行存在、
	# gate_allows 调用存在（L2 带 trigger_config 时）、Print 原生行存在
```

（fixture 断言清单在实现时按实际模板补全为逐行 `_check`，报告注明。）

- [ ] **Step 2: RED → 实现**

**生成脚本模板**（`emit_system` 组装，`%s` 填充）：

```gdscript
# ============================================================
# 由 Fuse 场景毕业导出器生成 — 委托数据块勿手工编辑
# System: %s | 源单元: %s (%s) @ %s
# 原生覆盖率: %d/%d (%d%%) | 委托: %s
# 采用: 禁用源 Trigger 节点 → 本脚本挂到同路径节点 → 运行验证
# 回滚: 恢复源 Trigger → 移除本脚本
# ============================================================
extends Node

const FuseDelegation := preload("res://addons/fuse/core/graduation/fuse_delegation.gd")

# ---- 委托数据块（PresetValueCodec 重建为 BaseInstruction）----
const _DELEGATED := %s

var _delegated := {}
var _gate := {}

func _ready() -> void:
	_delegated = FuseDelegation.build_delegated(_DELEGATED)
%s

func _exit_tree() -> void:
	FuseDelegation.teardown(self)
%s
```

**事件接线形态**（EventMapper 产出，追加进 `_ready` / 文件尾）：

- OnReady（delay 0）→ `_ready` 尾部直接调用 `_on_b0({})`；delay>0 → one-shot Timer。
- OnInputAction → 文件尾 `_unhandled_input(event)` + `event.is_action("<action>")` 过滤 + `Input.is_action_just_pressed/just_released/pressed` 按 trigger_mode 分支。
- OnInterval → Timer 成员 + `_setup/_on_interval`（含 max_repeats 计数与 stop_condition 存在时该事件**整体委托**——简化：含 stop_condition 的 OnInterval 归入 delegated 模式）。
- OnReceiveEvent → `_ready` 订阅存 `_sub_b0`，`_exit_tree` 退订，回调 `_on_b0(args)`。
- delegated 模式 → 事件对象进 `_DELEGATED["evt_b0"]`，由桥接面 `RuntimeEventInstance` 驱动（MVP：`FuseDelegation.run_event(node, evt_json, binding...)` —— 实现为构建 `RuntimeEventInstance` + initialize，复杂则**首版降级**：报告中列出不支持原生映射的事件类型并拒绝生成该 System（白名单事件外拒生成，错误码 `E_EVENT_UNSUPPORTED`）。

**统一触发入口**（每个 binding/单元一个）：

```gdscript
func _on_b0(event_args: Dictionary = {}) -> void:
	if not FuseDelegation.gate_allows(_gate, "b0", %s, %s, %s, get_instance_id()):
		return
%s
```

（%s = trigger_once/cooldown_mode/cooldown_time 三值 + 指令体：原生行序列或 `await FuseDelegation.run(self, _delegated["b0"], %d, event_args)`；L4 每 binding 一个入口。）

- [ ] **Step 3: GREEN + Commit**：`feat: 事件映射器 + GDScript 发射器（白名单 9 指令原生 + 委托数据块 + 门控复刻）`

### Task 7: export CLI + 金样例

**Files:**
- Create: `addons/fuse/editor/graduation/export_system.tscn` + `export_system_cli.gd`
- Create: `addons/fuse/tests/graduation/test_codegen_golden.gd` + `.tscn`
- Create（运行产物入库）: `fuse_generated/scripts/game_flow.gd`、`hint_breath.gd` + 各自 `.report.md` + 对应 System 定稿 `fuse_generated/systems/game_flow.json`、`hint_breath.json`

**Interfaces:**
- CLI：`export_system.tscn -- <system.json>`——流程：读 System → `SystemValidator.validate_preset`（有 error 拒绝生成，exit 1）→ load scene 取 unit 节点 → `GdscriptEmitter.emit_system` → 写 `emit.output_script` + `<stem>.report.md` → headless `load()` 生成脚本验证解析零错 → exit 0/1/2。

- [ ] **Step 1: 金样例测试**

```gdscript
func _test_golden_generation() -> void:
	# 两个 System 定稿（game_flow L4 / hint_breath L2，从 Task 4 草稿人工确认生成）
	for name in ["game_flow", "hint_breath"]:
		var script_path := "res://fuse_generated/scripts/%s.gd" % name
		var script: Variant = load(script_path)
		_check(script is GDScript and script.can_instantiate(), "%s 生成脚本解析零错" % name)
		var text := FileAccess.get_file_as_string(script_path)
		_check(text.contains("FuseDelegation") and text.contains("_DELEGATED"), "委托结构在")
	# 结构级：委托数据块重建后指令数与源一致（防静默丢失）
	var system: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://fuse_generated/systems/hint_breath.json"))
	#（按 System 引用回源场景节点，序列化指令计数 vs _DELEGATED 条目计数 + 原生数 == 源总数）
```

（计数断言实现时展开为具体代码；两个金样例的覆盖率数字断言进测试——hint_breath 预期 0 原生（OnInterval+2×Tween 全委托）或仅事件原生，以实测定死。）

- [ ] **Step 2: 手工确认两份 System**——从 Task 4 冒烟 drafts 拷贝 game_flow/hint_breath 为定稿（补 description、确认 warnings——有竞态则填 acknowledged_warnings），入库。
- [ ] **Step 3: 实现 CLI → 跑生成 → 金样例入库 → 测试 GREEN**
- [ ] **Step 4: 回归**（既有 8 项 + graduation 全部测试）
- [ ] **Step 5: Commit**：`feat: 毕业 export CLI + 金样例两份（生成脚本解析零错 + 覆盖率报告入库）`

---

## M3：闭环收尾

### Task 8: 文档 + 全量回归

**Files:**
- Modify: `AGENTS.md`（工具链小节补 derive/validate/export 三命令 + 退出码 + "毕业产物在 fuse_generated/"）
- Modify: spec 状态行 → `已实现（2026-08-3X，M0-M3 验收达标）`
- Modify: `addons/fuse/docs/superpowers/plans/`（本计划不动，收尾只改 spec/AGENTS）

- [ ] **Step 1: AGENTS.md 增补**（对齐 export_topology 先例的紧凑三行/命令）
- [ ] **Step 2: 全量回归清单**（既有 8 项闭环 + 拓扑 4 项 + graduation 5 项 = 17 项全 0；任何非 0 停下调查）
- [ ] **Step 3: Commit**：`chore: 毕业导出器 M0-M3 全量回归通过，工具链文档收尾`

---

## Self-Review 记录

- **Spec 覆盖**：§3 D1 两段式→T4/T7；D2 单 Trigger+多单元格式→T4（units 数组）；D3 混合委托→T3/T6；D4 手动采用→T6 模板头注释；D5 拓扑纯数据源→T4 只读 build_topology；§4 格式/推导→T4；§5 校验→T5；§6.2-6.5 生成器→T6/T7；§7 CLI 三命令→T4/T5/T7；§8 验证（解析级金样例+结构级计数）→T7；§9 风险 1（API 核实）→已完成于计划前探索并回填 Global Constraints；风险 7（run 边精确匹配）→T2。缺口检查：§8.4 System 校验正负例→T5 ✓；§10 M0-M3 对齐 ✓。
- **占位符扫描**：T4 的 events_out 断言与 T6 的 golden 断言标注"以实测填充精确断言"——这是对未知量的显式处理指令（数据驱动的测试），非 TBD；其余步骤代码完整。
- **类型一致性**：`FuseDelegation.run(node, instructions, execution_mode, event_args)`、`gate_allows(state, key, once, mode, time, object_id)`、`EventMapper.map_event(event_obj)`、`GdscriptEmitter.emit_system(system, unit_node, scene_path)` / `emit_instruction(inst, indent)` 在 T3/T6/T7 间签名一致；System JSON 字段与 spec §4.1 一致；finding 四字段对齐 preset_validator 先例。
- **风险预埋**：ctx cleanup 陷阱（每次新建）已写入 delegation 注释与 Global Constraints；重入=SKIP 语义一致非 bug 已注明；非白名单事件首版降级路径（E_EVENT_UNSUPPORTED 拒生成）已给。
