# Fuse 毕业交接 skill（fuse-handoff-packer）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 交付 `addons/fuse/agent_skills/fuse-handoff-packer/`——一个工具中立的交互式 agent skill，在与用户确认后把 System 划分 + 拓扑 + preset + 组件 schema + 语义契约 + 基建模板打包为自包含交接目录（handoff bundle）。

**Architecture:** 零引擎代码——不新增 GDScript 打包器、不加 CLI、不动运行时；skill 本体是 markdown 流程文档 + 静态资产（语义契约 / README 骨架 / 验收指引 / 三个纯 GDScript 基建模板）。skill 运行时消费已存在的原料 CLI（`export_topology` / `derive_systems` / `validate_system`）与 JSON（`preset_ai_context` 三 JSON、用户 preset）。

**Tech Stack:** Godot 4.7 项目内的纯文档资产 + 3 个自包含 GDScript 参考模板（过 gdlint、无 `class_name`、零 `addons/fuse` 依赖）。

**Spec:** `addons/fuse/docs/superpowers/specs/2026-09-01-handoff-bundle-skill-design.md`（本计划从 spec 立论；执行者两份都读）

## Global Constraints

- 全部文档/注释用中文（项目惯例）。
- 三个模板 `.gd` 落在 `addons/fuse/` 下 → **必须过 `gdlint addons/fuse` 零违规**；行长建议 120、硬限 250；**不加 `class_name`**（避免污染全局类名缓存与 ComponentScanner 语境）；**零 `addons/fuse` 依赖**（不 preload/不引用任何 Fuse 类）；自包含单文件。
- GDScript 禁则：`:=` 不能用于 `.findings`/`.map()` 等 Variant 返回链（parse error，用显式 `: 类型`）。
- **Windows Godot 输出管道挂死陷阱**：Godot console exe 的输出接 `| grep` 等管道会挂死——输出一律 `> /tmp/<name>.log 2>&1` 后再 grep 文件。
- Godot 可执行文件：`E:/Godot/Godot_v4.7-stable_mono_win64/Godot_v4.7-stable_mono_win64_console.exe`（下文以 `$GODOT` 指代，bash 中可 `GODOT="E:/Godot/Godot_v4.7-stable_mono_win64/Godot_v4.7-stable_mono_win64_console.exe"`）。
- skill 目录名与 skill 名一致：`fuse-handoff-packer`；资产路径与 spec §3 完全一致（执行者不得改名）。
- **事实表（下节）的 file:line 证据为本计划核实过的事实，成文时不可凭记忆改写**；对证据有疑以源码为准并在任务报告标注。

## 已核实事实表（各任务引用）

| # | 事实 | 证据 |
|---|------|------|
| F1 | 重触发默认 SKIP：执行中再触发忽略 | `core/trigger.gd:170-173`（`_on_event_fired` 中 runner `is_running()` → 跳过） |
| F2 | L4 binding RESTART：取消当前并重启，取消推迟到条件检查通过后 | `core/multi_event_trigger.gd:265-302` |
| F3 | trigger_once：已触发后再触发直接 return | `core/trigger.gd:166-168` |
| F4 | 冷却检查通过**即**计时（条件失败也进冷却）；条件检查在冷却检查之后 | `core/base_trigger.gd:122-154`（GLOBAL 记 `last_trigger_time`、PER_OBJECT 记 `object_cooldowns[object_id]`，检查通过同调用内写入） |
| F5 | 每次触发新建 ExecutionContext，整条指令链共享 | `core/base_trigger.gd:180+` `_create_execution_context` |
| F6 | 事件参数以 `event_<key>` 注入 ctx；`event_source`/`triggered_node` 指向触发源 | `core/trigger.gd:240`、`core/base_trigger.gd:213` |
| F7 | 执行模式 SEQUENTIAL（默认，逐条 await）/ PARALLEL（并行启动等全部结束） | `core/base/action_runner.gd:18,74,134-136` |
| F8 | `stop_on_error` 默认 true：指令失败停止序列剩余指令并发 `execution_failed` 信号 | `core/base/action_runner.gd:23,279-284,318-324` |
| F9 | 三层变量：`set_variable(name, value, scope)` / `get_variable(...)`，scope ∈ "local"（ctx）/ "scope"（节点邻域 ScopeVariableContainer）/ "global"（全局服务，可存档） | `core/base/execution_context.gd:231-239` |
| F10 | FuseEventBus API：`send_event(name, args={})` / `send_event_deferred(name, args={})` / `subscribe(name, cb) -> Subscription` / `unsubscribe(sub)`；信号 `event_sent(name, args)` | `core/fuse_event_bus.gd:14,51,77,91,118` |
| F11 | WarmUpPool 语义：`warm_up_count`（默认 10）、`warm_up_mode`（IMMEDIATE/BATCH）、`batch_size`（5）、`batch_delay`（0.1s）；池参数 `pool_initial_size`/`pool_max_size`/`scene_path` | `instructions/node_operations/warm_up_pool.gd:37-74` + 金样例委托 JSON |
| F12 | preset 导出入口：选中 Trigger/Runner/MultiEventTrigger 节点 → Inspector **📦 导出**按钮 → PresetExportDialog | `docs/user_docs/guides/55-preset-system-guide.md:89-108` |
| F13 | `preset_ai_context` 三 JSON：`fuse_component_schemas.json`（dict 按组件名索引，311 键，参数含 `requires` 门控）/ `fuse_components.json`（list 310 条）/ `fuse_enums.json`（dict 5 枚举） | 目录 `addons/fuse/preset_ai_context/` |
| F14 | 金样例原料现成：`fuse_generated/systems/game_flow.json`（定稿）、`addons/fuse/presets/gameplay/game_flow.json`、`addons/fuse/presets/ui/hint_breath.json`、交叉验证对象 `fuse_generated/scripts/game_flow.gd` | 仓库现状 |
| F15 | SendEvent 的 event_args 值支持 `$var` 引用（发送时从 ctx 解析变量值） | 金样例委托 JSON `"score":"$c_score"` + SendEvent 实现 |

---

### Task 1: skill 目录骨架 + semantics.md（语义契约）

**Files:**
- Create: `addons/fuse/agent_skills/fuse-handoff-packer/assets/semantics.md`
- Create: `addons/fuse/agent_skills/fuse-handoff-packer/.gitkeep`（占位目录骨架：SKILL.md 与其余资产由后续任务落，先建目录）

**Interfaces:**
- Produces: `assets/semantics.md`——Task 7 打包时整文件拷贝进 bundle；内容必须覆盖事实表 F1-F9

- [ ] **Step 1: 建目录骨架**

```bash
mkdir -p "E:/GitHub/fuse/addons/fuse/agent_skills/fuse-handoff-packer/assets/templates"
touch "E:/GitHub/fuse/addons/fuse/agent_skills/fuse-handoff-packer/assets/.gitkeep"
```

- [ ] **Step 2: 写 semantics.md**（下文全文落盘，证据列来自事实表，不得改写数值）

```markdown
# Fuse 运行时语义契约（v1 · Fuse 4.7 · 2026-09）

> 本文件描述**源 Fuse 运行时**的行为语义。接包 agent 编写替代代码时以本契约为等价性标准；
> 与 bundle 内 preset JSON 原文冲突时，以 preset 原文为准，并在交付说明中显式列出差异假设。

## 1. 触发与重入
- 每个 Trigger / MultiEventTrigger 节点同一时刻只跑一条执行链。
- 执行中再次触发：默认**忽略（SKIP）**。
- L4 MultiEventTrigger 的单个 binding 可配置 RESTART：**取消当前执行并重启**；取消动作推迟到该次触发的条件检查通过之后才发生。
- trigger_once：节点生命周期内只触发一次，已触发后的再触发直接忽略。

## 2. 门控消耗时机（易错点）
- **冷却**（GLOBAL / PER_OBJECT 两档）：冷却检查通过**即开始计时**——即使随后的条件检查失败，冷却也已经进入。效果：条件失败期间的重试受冷却约束。
- **trigger_once**：**条件通过才消耗**——条件失败不消耗一次性机会，后续触发仍可放行。
- 冷却状态存储：GLOBAL 记最近触发时刻；PER_OBJECT 按触发者 object_id 各记各的。

## 3. 单次触发 = 一个执行上下文（LOCAL 连续性）
- 每次触发新建一个执行上下文（ctx），**整条指令链**（含 IfThen/IfElse/Loop 等嵌套内的指令与内嵌条件对象）共享它。
- **local 层变量存于 ctx**：跨指令读写只在这一次执行链内有效，链结束即消失。
- 替代代码必须保证等价的"单次触发链内状态连续性"——不要逐指令重置局部状态；一次触发链内的中间量应存活到链结束。

## 4. 事件参数注入
- 触发事件携带的参数字典以 `event_<key>` 形式写入 ctx，供指令与条件引用
  （例：OnReceiveEvent 收到 `{"score": 10}` → 条件/指令引用 `event_score`）。
- `event_source`、`triggered_node` 指向触发源节点。
- SendEvent 的 event_args 值支持 `$var` 形式引用变量（发送时从 ctx 解析为当前值）。

## 5. 指令序列执行
- **SEQUENTIAL**（默认）：顺序执行，每条指令 await 完成才执行下一条。
- **PARALLEL**：全部指令并行启动，等待全部结束。
- **失败传播**：stop_on_error 默认开启——某指令执行失败即停止序列剩余指令并发出失败信号。
- 嵌套序列（IfThen/IfElse 的分支、Loop 循环体等）递归适用同规则。

## 6. 三层变量
| 层 | 生命周期 | 等价实现建议 |
|----|---------|-------------|
| local | 单次执行链内 | 触发处理函数的局部状态（一次调用的局部变量/字典） |
| scope | 节点邻域共享（沿树向上搜索 ScopeVariableContainer） | 挂在共同祖先节点上的共享组件 |
| global | 全游戏持久，可存档/读档 | autoload 单例（见 templates/global_state.gd） |

## 7. 等价性自检表（写完代码逐条对照）
- [ ] 重触发行为与源一致（默认 SKIP；源配 RESTART 的 binding 是否实现了取消重启）
- [ ] 单次触发链内状态连续（local 语义）
- [ ] 冷却"检查通过即计时"；trigger_once"条件通过才消耗"
- [ ] `event_<key>` 参数名映射正确；`$var` 引用已解析
- [ ] SEQUENTIAL/PARALLEL 与失败停止语义一致
```

- [ ] **Step 3: 逐条核对证据**——打开 F1-F9 引用的源码行核对 semantics.md 每条陈述，发现不符即修文档并在任务报告记录（Ruling 格式：改了什么—为什么—证据行号）

- [ ] **Step 4: Commit**

```bash
git add addons/fuse/agent_skills/
git commit -m "feat(handoff-skill): 目录骨架与语义契约 semantics.md"
```

---

### Task 2: 基建模板 event_bus.gd

**Files:**
- Create: `addons/fuse/agent_skills/fuse-handoff-packer/assets/templates/event_bus.gd`

**Interfaces:**
- Consumes: 事实表 F10（API 对齐目标）
- Produces: `templates/event_bus.gd`——autoload 参考实现；SKILL.md（Task 6）的 SendEvent/OnReceiveEvent → event_bus 映射指向它

- [ ] **Step 1: 写模板**（全文落盘；tab 缩进、无 class_name、过 gdlint）

```gdscript
# 文件：addons/fuse/agent_skills/fuse-handoff-packer/assets/templates/event_bus.gd
## 事件总线——Fuse FuseEventBus 的脱离替代参考实现（推荐 autoload 命名 EventBus）
##
## API 形状与 Fuse FuseEventBus 对齐，preset 中 SendEvent / OnReceiveEvent
## 的用法可直译：
##   FuseDelegation 风格           → 本模板
##   FuseEventBus.send_event(...)   → EventBus.send_event(...)
##   subscribe(name, cb) -> Sub     → subscribe(name, cb) -> Dictionary
##   unsubscribe(sub)               → unsubscribe(sub)
## 订阅回调统一收 args: Dictionary。参考实现：同事件同步分发，无跨线程保证。
extends Node

signal event_sent(event_name: String, args: Dictionary)

# event_name -> Array[Dictionary]（条目形如 {"cb": Callable, "id": int}）
var _subscribers := {}


## 发送总线事件：先广播 event_sent 信号，再同步调用全部订阅者
func send_event(event_name: String, args: Dictionary = {}) -> void:
	event_sent.emit(event_name, args)
	var list: Array = _subscribers.get(event_name, [])
	for entry in list:
		if entry.cb.is_valid():
			entry.cb.call(args)


## 延迟到帧末发送（对齐 FuseEventBus.send_event_deferred）
func send_event_deferred(event_name: String, args: Dictionary = {}) -> void:
	send_event.call_deferred(event_name, args)


## 订阅事件；返回订阅句柄（Dictionary），退订时原样传回 unsubscribe
func subscribe(event_name: String, callback: Callable) -> Dictionary:
	if not _subscribers.has(event_name):
		_subscribers[event_name] = []
	var list: Array = _subscribers[event_name]
	var sub := {"event_name": event_name, "id": list.size()}
	list.append({"cb": callback, "id": sub.id})
	return sub


## 退订（句柄由 subscribe 返回；空句柄安全）
func unsubscribe(subscription: Dictionary) -> void:
	if subscription.is_empty():
		return
	var list: Array = _subscribers.get(subscription.get("event_name", ""), [])
	var target_id: int = subscription.get("id", -1)
	for i in range(list.size()):
		if list[i].id == target_id:
			list.remove_at(i)
			return
```

- [ ] **Step 2: 验证一（lint）**

```bash
cd E:/GitHub/fuse && gdlint addons/fuse/agent_skills/fuse-handoff-packer/assets/templates/event_bus.gd
```
Expected: `Success: no problems found`（退出码 0）

- [ ] **Step 3: 验证二（Godot 解析）**

```bash
GODOT="E:/Godot/Godot_v4.7-stable_mono_win64/Godot_v4.7-stable_mono_win64_console.exe"
"$GODOT" --headless --path E:/GitHub/fuse --check-only --script addons/fuse/agent_skills/fuse-handoff-packer/assets/templates/event_bus.gd > /tmp/hb_eventbus.log 2>&1
grep -i "error\|parse" /tmp/hb_eventbus.log || echo PARSE_OK
```
Expected: `PARSE_OK`（无 SCRIPT ERROR）

- [ ] **Step 4: Commit**

```bash
git add addons/fuse/agent_skills/fuse-handoff-packer/assets/templates/event_bus.gd*
git commit -m "feat(handoff-skill): event_bus 基建模板（对齐 FuseEventBus API）"
```

---

### Task 3: 基建模板 object_pool.gd

**Files:**
- Create: `addons/fuse/agent_skills/fuse-handoff-packer/assets/templates/object_pool.gd`

**Interfaces:**
- Consumes: 事实表 F11（WarmUpPool 语义）
- Produces: `templates/object_pool.gd`——SKILL.md 的 WarmUpPool → object_pool 映射指向它

- [ ] **Step 1: 写模板**（全文落盘）

```gdscript
# 文件：addons/fuse/agent_skills/fuse-handoff-packer/assets/templates/object_pool.gd
## 对象池——Fuse WarmUpPool 所依赖池系统的脱离替代参考实现
##
## 对齐 WarmUpPool 的参数语义（preset 中的配置可直译到同名 @export）：
##   warm_up_mode  IMMEDIATE 一次性预热 / BATCH 按 batch_size 分批、批间 batch_delay 秒
##   warm_up_count 预热实例总数；pool_initial_size / pool_max_size 池容量上下限
## 用法：作为节点 add_child 后调用 warm_up()；取用 acquire()，归还 release(node)。
extends Node

enum WarmUpMode { IMMEDIATE, BATCH }

@export var scene_path: String = ""
@export var pool_initial_size: int = 10
@export var pool_max_size: int = 100
@export var warm_up_count: int = 10
@export var warm_up_mode: WarmUpMode = WarmUpMode.IMMEDIATE
@export var batch_size: int = 5
@export var batch_delay: float = 0.1

var _pool: Array[Node] = []
var _created: int = 0


## 预热：IMMEDIATE 一帧内完成；BATCH 分批进行（await，可异步等待）
func warm_up() -> void:
	if scene_path.is_empty():
		push_warning("[object_pool] scene_path 为空，跳过预热")
		return
	var remaining := warm_up_count
	while remaining > 0:
		var n: int = mini(batch_size, remaining) if warm_up_mode == WarmUpMode.BATCH else remaining
		for i in n:
			_spawn_one()
		remaining -= n
		if warm_up_mode == WarmUpMode.BATCH and remaining > 0:
			await get_tree().create_timer(batch_delay).timeout


## 从池中取一个实例（池空且未达上限则新建；达上限返回 null）
func acquire() -> Node:
	if not _pool.is_empty():
		var node := _pool.pop_back()
		if is_instance_valid(node):
			return node
	if _created < pool_max_size:
		return _spawn_one()
	push_warning("[object_pool] 池已达上限 %d，acquire 返回 null" % pool_max_size)
	return null


## 归还实例（隐藏并回池；池满则 queue_free）
func release(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.set_process(false)
	if node is CanvasItem:
		node.hide()
	if _pool.size() < pool_max_size:
		_pool.append(node)
	else:
		node.queue_free()


func _spawn_one() -> Node:
	var scene: PackedScene = load(scene_path)
	if scene == null:
		push_error("[object_pool] 无法加载场景: %s" % scene_path)
		return null
	var node := scene.instantiate()
	_created += 1
	if _pool.size() < pool_max_size:
		_pool.append(node)
		node.set_process(false)
		if node is CanvasItem:
			node.hide()
		return null
	# 池满：直接返回实例交由调用方管理（计入 created）
	return node
```

- [ ] **Step 2: 验证（lint + 解析）**——命令同 Task 2 Step 2/3（文件名换 object_pool.gd，日志 `/tmp/hb_pool.log`）。Expected: lint 零违规 + `PARSE_OK`
- [ ] **Step 3: Commit**

```bash
git add addons/fuse/agent_skills/fuse-handoff-packer/assets/templates/object_pool.gd*
git commit -m "feat(handoff-skill): object_pool 基建模板（对齐 WarmUpPool 语义）"
```

---

### Task 4: 基建模板 global_state.gd

**Files:**
- Create: `addons/fuse/agent_skills/fuse-handoff-packer/assets/templates/global_state.gd`

**Interfaces:**
- Consumes: 事实表 F9（global 层语义）
- Produces: `templates/global_state.gd`——SKILL.md 的 global 变量 → global_state 映射指向它

- [ ] **Step 1: 写模板**（全文落盘）

```gdscript
# 文件：addons/fuse/agent_skills/fuse-handoff-packer/assets/templates/global_state.gd
## 全局状态——Fuse global 层变量的脱离替代参考实现（推荐 autoload 命名 GlobalState）
##
## 对齐 Fuse global 层语义：全游戏持久、按名读写、不存在时自动创建（写路径）、
## 支持存档/读档（对应 LoadGlobalVariables / SaveGlobalVariables 的持久化用途）。
## 注意：Fuse 的 global 层读不存在的变量返回 null（不报错），本模板同行为。
extends Node

const SAVE_PATH := "user://global_state.cfg"

var _values: Dictionary = {}


func set_value(name: String, value: Variant) -> void:
	_values[name] = value


func get_value(name: String, default: Variant = null) -> Variant:
	return _values.get(name, default)


func has_value(name: String) -> bool:
	return _values.has(name)


func erase_value(name: String) -> void:
	_values.erase(name)


## 存档（对应 SaveGlobalVariables：全部 global 变量写盘）
func save_state() -> bool:
	var cfg := ConfigFile.new()
	for key in _values:
		cfg.set_value("state", key, _values[key])
	return cfg.save(SAVE_PATH) == OK


## 读档（对应 LoadGlobalVariables：从盘恢复，已有键会被盘上值覆盖）
func load_state() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	for key in cfg.get_section_keys("state"):
		_values[key] = cfg.get_value("state", key)
	return true
```

- [ ] **Step 2: 验证（lint + 解析）**——命令同 Task 2 Step 2/3（文件名换 global_state.gd，日志 `/tmp/hb_gstate.log`）。Expected: lint 零违规 + `PARSE_OK`
- [ ] **Step 3: Commit**

```bash
git add addons/fuse/agent_skills/fuse-handoff-packer/assets/templates/global_state.gd*
git commit -m "feat(handoff-skill): global_state 基建模板（对齐 global 层变量语义）"
```

---

### Task 5: README-for-agent.tpl + acceptance-guide.md

**Files:**
- Create: `addons/fuse/agent_skills/fuse-handoff-packer/assets/README-for-agent.tpl`
- Create: `addons/fuse/agent_skills/fuse-handoff-packer/assets/acceptance-guide.md`

**Interfaces:**
- Consumes: spec §6.3/§6.4；事实表 F15（`$var` 解析）
- Produces: 两份资产——Task 6 SKILL.md 步骤 6 引用；Task 7 走查按模板实例化

- [ ] **Step 1: 写 README-for-agent.tpl**（全文落盘；`{{占位符}}` 由打包时的 agent 填充）

```markdown
# {{系统名}} — 交接工件包（Handoff Bundle）

> 你（AI agent）的任务：为该系统编写**脱离 Fuse 插件**的等价 GDScript 实现。
> 约束：不得依赖 `addons/fuse/`（不 preload、不引用类名、不假设 autoload 存在）。

## 系统意图
{{system.description，一两句；必要时打包 agent 补充与用户确认的动机}}

## 工件导航
| 文件 | 是什么 | 怎么用 |
|------|--------|--------|
| `system.json` | 系统划分定稿：单元清单 / 外联事件与变量（externals）/ 已确认警告 | 先读 units 与 externals——这是系统的边界 |
| `topology.json` | 源场景全量拓扑（含 source_scene 溯源） | 查节点层级与邻居单元；本系统只负责 units 列出的单元 |
| `presets/*.json` | 行为规格主体：指令序列（含参数与嵌套） | 逐 binding 阅读并翻译为代码 |
| `components.json` | 涉及组件的参数 schema（含 requires 门控） | 理解 preset 中各组件的参数含义与枚举值 |
| `semantics.md` | Fuse 运行时语义契约 | **翻译 preset 前必读**；等价性标准 |
| `acceptance.md` | 行为验收清单 | 交付前逐条核对并回标 |
| `templates/*.gd` | 基建参考实现（event_bus / object_pool / global_state） | 可采用 / 改写 / 替换；API 与 Fuse 概念对齐 |

## 本系统范围
- 单元：{{units 摘要（node_path / kind / level）}}
- 消费的外部事件：{{externals.events_in 名称}}
- 产出的外部事件：{{externals.events_out 名称}}
- 读写的外部变量：{{externals.variables 名称与 scope}}

## 语义要点（详见 semantics.md）
- 执行中重触发默认忽略（SKIP）{{若源配 RESTART 则注明}}
- 一次触发 = 一个上下文：local 变量跨指令连续
- 冷却"检查通过即计时"；trigger_once"条件通过才消耗"
- 事件参数以 `event_<key>` 引用；`$var` 为变量引用

## 验收要求
交付前逐条核对 `acceptance.md`，在交付说明中对每条断言标注"已实现 / 不适用（附原因）"。

## 有歧义时
以 `semantics.md` 与 `presets/*.json` 原文为准；仍无法判定时，**显式列出你的假设**并标注影响面，不要静默猜测。
```

- [ ] **Step 2: 写 acceptance-guide.md**（全文落盘）

```markdown
# 验收清单提炼指引（打包 agent 用）

从 bundle 的 preset / system 数据提炼**静态可对照**的行为断言，产出 `acceptance.md`。
每条断言一行、可勾选（`- [ ]`），**注明来源**（preset 文件名 + 定位信息）。

## 必须覆盖的五类断言

1. **事件序列**：每个 SendEvent 的 event_name、顺序、参数值；`$var` 引用需注明
   解析来源变量（例：`args.score = $c_score ← local 变量 c_score 当前值`）。
2. **变量终值**：SetVariable / MathOperation 的写入目标、期望值、所在分支条件。
3. **触发-效果对**：每个 binding 一行摘要——「OnReceiveEvent X → 扣命 → 若命=0 → GameEnd("loss")」。
4. **时序约束**：Wait 链与时长、OnInterval 周期、冷却时长、跨指令延迟。
5. **边界条件**：重触发行为（SKIP / RESTART）、trigger_once、条件失败后的重试约束。

## 格式模板

```markdown
# 验收清单 — {{系统名}}

## 事件序列
- [ ] EnemyDie 触发 → 依次发出 ScoreUpdate(score=当前分) 与（敌数=0 时）AllEnemyDied
      （来源：game_flow.json binding b2）

## 变量终值
- [ ] PlayerDie 后 player_life 减 1；=0 走死亡分支，>0 走重生分支
      （来源：game_flow.json binding b3 的 IfElse 条件）

## 触发-效果对
- [ ] ...

## 时序约束
- [ ] ...

## 边界条件
- [ ] ...
```

## 度量
- 每个顶层 binding 至少产出 1 条触发-效果对断言
- 每个 SendEvent 至少出现在 1 条事件序列断言中
- 清单条数 = max(10, 指令数 / 3) 左右为宜——过少覆盖不足，过多稀释重点
```

- [ ] **Step 3: Commit**

```bash
git add addons/fuse/agent_skills/fuse-handoff-packer/assets/
git commit -m "feat(handoff-skill): README-for-agent 骨架与验收清单提炼指引"
```

---

### Task 6: SKILL.md（七步交互流程）

**Files:**
- Create: `addons/fuse/agent_skills/fuse-handoff-packer/SKILL.md`

**Interfaces:**
- Consumes: Task 1-5 全部资产（路径引用必须逐字一致）；spec §4 七步表
- Produces: skill 入口文档——Task 7 走查按它执行；Task 8 文档指路指向它

- [ ] **Step 1: 写 SKILL.md**（全文落盘）

````markdown
# fuse-handoff-packer：Fuse 系统毕业交接打包

把 Fuse 场景中调稳的系统打包为**自包含交接工件包**（handoff bundle），交给 AI agent
编写脱离 Fuse 的工程代码。本 skill 是交互式的：每一步与用户确认后再前进。

**不可破坏的约束**：只读 Fuse 侧资产、只写 `fuse_generated/handoff/<系统名>/`；
不生成游戏代码（那是接包 agent 的事）；不修改源场景与 Trigger。

## 触发词
"毕业这个系统" / "打包 handoff" / "交接 X 系统"

## 前置原料（缺什么补什么，见步骤）
- System 划分定稿：`fuse_generated/systems/<name>.json`（derive_systems CLI 产出）
- 源场景拓扑：`export_topology` CLI 产出
- 行为规格：用户从编辑器导出的 preset JSON（Inspector 选中节点 → 📦 导出）
- 组件 schema：`addons/fuse/preset_ai_context/fuse_component_schemas.json` 等三 JSON
- 本 skill 资产：`assets/`（semantics / README 模板 / 验收指引 / 基建模板）

## 七步流程

### 1 确认目标
问用户三件事：哪个场景、哪个（些）系统、毕业动机（性能接管 / 脱离插件 / 交接给
程序员——动机影响验收重点与模板取舍）。系统名与 `fuse_generated/systems/` 下的
文件名对应。

### 2 备料：System 划分
检查 `fuse_generated/systems/<name>.json` 是否存在且过校验：
- 不存在 → 代跑推导 CLI（输出重定向到文件再查看，Godot console exe 输出接管道会挂死）：
  ```
  <Godot> --headless --path <项目> res://addons/fuse/editor/graduation/derive_systems.tscn \
    -- --scene res://<场景>.tscn > /tmp/derive.log 2>&1
  ```
  然后与用户逐单元确认：划分是否合理、补 description、`_derive_report.json` 的
  warnings_by_unit 是否拷入 acknowledged_warnings（不确认的警告要向用户解释后果）
- 存在 → 代跑校验：
  ```
  <Godot> --headless --path <项目> res://addons/fuse/editor/graduation/validate_system.tscn \
    -- <system.json> > /tmp/validate.log 2>&1
  ```
  有 error（退出码 1）先与用户解决；topology_digest 漂移说明场景改过，需重新 derive。

### 3 行为规格：preset
引导用户提供系统涉及单元的 preset JSON：
- 已导出 → 直接用（通常在用户项目的 preset 目录）
- 未导出 → 指引用户在编辑器中选中对应 Trigger / Runner / MultiEventTrigger 节点，
  点 Inspector 的 **📦 导出** 按钮（详细步骤见 Fuse 的 55 号预设指南）
- 补充路径：需要节点层级 / NodePath 锚点时直接读源 `.tscn` 文本核对
  （preset 是行为规格主体，.tscn 只用于结构核对）

### 4 拓扑快照
代跑（产物名 = 场景文件茎，含 source_scene 溯源）：
```
<Godot> --headless --path <项目> res://addons/fuse/editor/topology/export_topology.tscn \
  -- --scene res://<场景>.tscn > /tmp/topo.log 2>&1
```

### 5 模板确认
扫描 preset JSON 中出现的指令 `type` 集合，按下表推荐基建模板，展示给用户确认增删：
| preset 中出现 | 推荐模板 | 对齐的 Fuse 概念 |
|---------------|----------|------------------|
| SendEvent / OnReceiveEvent | `templates/event_bus.gd` | FuseEventBus 总线 |
| WarmUpPool | `templates/object_pool.gd` | 对象池系统 |
| global 层变量（读写 scope="global"） | `templates/global_state.gd` | global 变量层 / 存读档 |
无匹配依赖则不带 templates/ 目录（向用户说明）。

### 6 打包
逐件落盘到 `fuse_generated/handoff/<系统名>/`：
| 产物 | 来源与做法 |
|------|-----------|
| `system.json` | 拷贝定稿 |
| `topology.json` | 拷贝步骤 4 产物 |
| `presets/*.json` | 拷贝步骤 3 的 preset（多份全拷） |
| `semantics.md` | 拷贝 `assets/semantics.md` |
| `README-for-agent.md` | 按 `assets/README-for-agent.tpl` 填充 `{{占位符}}`（意图/范围/事件变量摘要从 system.json 提取） |
| `acceptance.md` | 按 `assets/acceptance-guide.md` 指引从 preset 现场提炼 |
| `components.json` | 收集 preset 中出现的全部 `type` → 从 `fuse_component_schemas.json` 抽对应条目为 `{组件名: 参数表}`；再从 `fuse_components.json`（list）按 name 过滤出条目数组的说明信息（category / description 键名）；枚举值从 `fuse_enums.json` 抽涉及的枚举。**preset 中出现但 schema 缺失的组件**：照常打包 preset 原文，并在 README-for-agent.md 标注"该组件无 schema，按 JSON 原文理解" |
| `templates/*.gd` | 拷贝用户确认后的模板 |

### 7 交付
向用户报告：bundle 路径、内容摘要（单元/事件/变量/断言数）、下一句提示——
"把该目录交给你的 AI agent；要求它交付前逐条核对 acceptance.md 并回标"。

## 失败分支速查
- derive 校验 error → 与用户解决后重跑（步骤 2）
- 用户不会导出 preset → 指 55 号指南的导出小节
- Godot CLI 无输出/挂起 → 检查是否忘了输出重定向到文件
````

- [ ] **Step 2: 一致性核对**——SKILL.md 引用的资产路径（`assets/semantics.md` 等 6 处）与 Task 1-5 实际落盘路径逐字比对；CLI tscn 路径与 AGENTS.md「构建/测试命令」节逐字比对
- [ ] **Step 3: Commit**

```bash
git add addons/fuse/agent_skills/fuse-handoff-packer/SKILL.md
git commit -m "feat(handoff-skill): SKILL.md 七步交互流程"
```

---

### Task 7: 金样例走查（game_flow）+ 首个 bundle 入库

**Files:**
- Create: `fuse_generated/handoff/game_flow/`（8 件产物，见步骤）
- Test: 本任务四步验收即测试（自包含性 / 语义核对 / 交叉验证 / 模板解析）

**Interfaces:**
- Consumes: Task 1-6 全部产物；事实表 F14（金样例原料路径）
- Produces: 首个真实 bundle（样例入库，供后续使用者参考）

- [ ] **Step 1: 按 SKILL.md 执行打包**（以 skill 使用者身份走完七步；步骤 1/2/3/5 的"用户确认"以既定事实替代：系统=game_flow、动机=脱离插件、preset=`addons/fuse/presets/gameplay/game_flow.json`、模板按依赖推荐全带——SendEvent/WarmUpPool/global 变量均出现）。跑 CLI 前先初始化：

```bash
cd E:/GitHub/fuse
GODOT="E:/Godot/Godot_v4.7-stable_mono_win64/Godot_v4.7-stable_mono_win64_console.exe"
# 拓扑快照（System 定稿已存在，跳过 derive；仍跑 validate 复验）
"$GODOT" --headless --path . res://addons/fuse/editor/graduation/validate_system.tscn \
  -- fuse_generated/systems/game_flow.json > /tmp/hb_validate.log 2>&1
echo "validate exit=$?"
"$GODOT" --headless --path . res://addons/fuse/editor/topology/export_topology.tscn \
  -- --scene res://demos/fuse/brickian/game_scene.tscn > /tmp/hb_topo.log 2>&1
echo "topo exit=$?"
```
Expected: 两个 exit=0；拓扑产物在 `fuse_reports/topology/game_scene.json`

- [ ] **Step 2: 生成 bundle 八件**（拷贝 + 填充 + 提炼，产物落 `fuse_generated/handoff/game_flow/`）：system.json / topology.json（拷贝步骤 1 产物）/ presets/game_flow.json / semantics.md / README-for-agent.md（按模板填充，占位符全消）/ acceptance.md（按指引从 preset 提炼，覆盖五类断言）/ components.json（从三 JSON 抽 preset 涉及的 type 集合）/ templates/（三个模板全拷）

- [ ] **Step 3: 四步验收**
1. **自包含性**：把 bundle 视为唯一信息源，逐项能回答——系统做什么 / 包含哪些单元 / 行为规格在哪 / 怎么验收；不引用 Fuse 仓库其他文件
2. **语义核对**：bundle 内 semantics.md 与源码五处抽查（F1/F4/F6/F7/F8 的证据行）一致
3. **交叉验证**：`fuse_generated/scripts/game_flow.gd` 头注释的委托清单（27 个指令）与 bundle 的 `presets/game_flow.json` 指令集对照——同源数据应一致（数量与类型分布）
4. **模板解析**：bundle 内三个模板再跑一次 Task 2 Step 3 的解析命令（路径换成 bundle 内），全部 PARSE_OK

- [ ] **Step 4: Commit**

```bash
git add fuse_generated/handoff/
git commit -m "feat(handoff-skill): 金样例 game_flow 首个交接 bundle（走查样例入库）"
```

---

### Task 8: 文档同步（README / 57 / AGENTS / 面板指南）

**Files:**
- Modify: `README.md`（"从原型到工程代码"节）
- Modify: `addons/fuse/docs/user_docs/guides/57-graduation-exporter-guide.md`（"后续方向"节）
- Modify: `AGENTS.md`（配套 skill 表格）
- Modify: `addons/fuse/docs/user_docs/guides/00-editor-panels-overview.md`（拓扑 JSON 导出节末尾）

**Interfaces:**
- Consumes: Task 6 的 SKILL.md 路径、Task 7 的 bundle 样例路径
- Produces: 全部指路文案与新口径一致

- [ ] **Step 1: README.md**——"从原型到工程代码（AI 交接）"节：把「一键打包交接工件（handoff bundle…）规划中。」一句替换为：

```markdown
一键打包交接工件由随插件分发的 **fuse-handoff-packer skill** 完成（`addons/fuse/agent_skills/fuse-handoff-packer/SKILL.md`，工具中立，任何 AI agent 均可执行）：它与你交互确认系统与模板后产出 `fuse_generated/handoff/<系统名>/` 自包含交接包（系统划分 / 拓扑 / preset / 语义契约 / 验收清单 / 组件 schema / 基建模板）。样例见 `fuse_generated/handoff/game_flow/`。
```

- [ ] **Step 2: 57 号指南**——"后续方向"节末尾追加一段：

```markdown
**出口主线已落地**：`addons/fuse/agent_skills/fuse-handoff-packer/`——交互式交接打包 skill，产出脱离 Fuse 编码所需的自包含 bundle（样例 `fuse_generated/handoff/game_flow/`）。本导出器（实验性 GDScript 生成）的语义结论已沉淀进 bundle 的语义契约。
```

- [ ] **Step 3: AGENTS.md**——「配套生成 skill」表格追加一行，并在表格后备注段追加一句：

表格行：
```markdown
| 毕业交接打包（handoff bundle） | `addons/fuse/agent_skills/fuse-handoff-packer/SKILL.md` |
```
备注句：
```markdown
`addons/fuse/agent_skills/` 下的 skill 面向插件使用者（随 `addons/fuse/` 分发、工具中立），与上表面向本仓库开发的 `.claude/skills/` 不同；用户项目通过其 AGENTS.md 指路使用。
```

- [ ] **Step 4: 00-editor-panels-overview.md**——"拓扑 JSON 导出"节末尾追加：

```markdown
该 JSON 也是 handoff bundle 交接包的拓扑快照来源（由 `fuse-handoff-packer` skill 消费）。
```

- [ ] **Step 5: README.md 安装节**——第 3 步（可选 autoload）之后追加一条：

```markdown
4. （毕业交接）你的 AI agent 需要读 `addons/fuse/agent_skills/fuse-handoff-packer/SKILL.md`——建议在你项目的 AGENTS.md / CLAUDE.md 等指令文件中加一行指路
```

- [ ] **Step 6: 交叉检查 + Commit**——grep 五个文件确认指路路径均含 `agent_skills/fuse-handoff-packer`；README 无残留"规划中"占位

```bash
grep -rn "fuse-handoff-packer" README.md AGENTS.md addons/fuse/docs/user_docs/guides/57-graduation-exporter-guide.md addons/fuse/docs/user_docs/guides/00-editor-panels-overview.md
grep -n "规划中" README.md || echo NO_PLACEHOLDER
git add README.md AGENTS.md addons/fuse/docs/user_docs/guides/
git commit -m "docs(handoff-skill): 文档同步——skill 用法与 agent_skills 目录说明"
```
Expected: grep 命中 4 文件（安装节与出口节都在 README.md 内）；`NO_PLACEHOLDER`
