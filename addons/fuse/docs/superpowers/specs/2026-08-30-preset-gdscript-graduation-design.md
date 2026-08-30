# Preset → GDScript 场景毕业导出器设计（System IR + 混合委托）

**日期：** 2026-08-30
**状态：** 设计已批准（圆桌决策见 §3），待实现
**上下文：** 落实价值评估文档第四轮修订（`2026-08-15-ai-era-value-assessment.md` §5 建议 4、§8）——桥梁定位的出口桥板。前身讨论：2026-08-30 圆桌（切面粒度 / System 工件 / 指令覆盖 / 采用机制均已定）。

---

## 1. 目标与范围

**目标：** 提供"原型 → 工程代码"的晋升路径：从场景拓扑推导出 **System（系统）工件**（新 IR），按 System 生成可读、可验证、与 Fuse 运行时共存的 GDScript。非破坏性：导出器只产新文件，不改场景、不动源 Trigger；回滚 = 手动反向操作。

**MVP 范围（单 Trigger 系统 + 桥接模式）：**

1. System 工件格式 + 从 `build_topology()` 自动推导（单例草稿）
2. System 校验器（工件级规则，复用闭环 finding 体系）
3. 代码生成器：单 Trigger → 单 GDScript；指令混合策略（白名单原生发射 + 其余运行时委托）
4. headless CLI（derive / validate / generate 三命令族，对齐 validate_preset 模式）
5. 就绪报告：覆盖率、警告、采用说明
6. 生成产物的解析级验证（headless 加载脚本零解析错误）

**Non-goals（二期及以后）：**

- 多单元连通分量的**物化模式**（变量物化为脚本成员、事件对直调）——System 格式按多单元设计，实现二期做
- 自动切换/一键回滚（MVP 手动采用：用户自行禁用 Trigger、挂载脚本）
- 拓扑主屏 Tab 的 UI 集成（切面选择、readiness 过滤）——MVP 纯数据源
- 行为等价性评测（生成的代码 vs preset 运行时行为对照）——远期，依赖运行时 harness
- 性能优化宣传（生成代码不承诺快于 Fuse 运行时；卖点是可读、可接管、脱离数据层）

## 2. 现有基础设施（直接依赖，不重建）

| 设施 | 位置 | 用途 |
|------|------|------|
| 拓扑分析 | `editor/analysis/instruction_analyzer.gd` `build_topology()`（:421）| System 推导的输入：triggers / cross_references（signal、variable_write_to_read、variable_write_to_write）/ variable_analysis |
| 单元分析 | 同文件 `analyze_trigger()` | 指令树、三层变量清单、signals、event_bindings、is_nested |
| Preset 序列化 | `core/resources/fuse_preset.gd` + `PresetValueCodec` | 生成脚本内嵌委托指令的重建通道（JSON → BaseInstruction 数组） |
| 闭环体系 | `editor/preset_ai/`（validator/eval/CLI 模式） | 本 spec 复用其 finding code 体系、headless 场景模式、退出码约定 |
| 指令运行时 | `BaseInstruction.execute(ctx)` / `ExecutionContext` / `ActionRunner.ExecutionMode` | 委托执行的执行面 |
| 触发器语义 | `BaseTrigger`：trigger_once / cooldown_mode（NONE/GLOBAL_COOLDOWN/PER_OBJECT_COOLDOWN）/ cooldown_time | 生成代码必须保真的门控语义 |

## 3. 已确认决策（圆桌定案，实现不得偏离）

| # | 决策 | 内容 |
|---|------|------|
| D1 | 两段式架构 | 拓扑 → **System 工件**（人/AI 可审阅编辑）→ 按 System 生成代码；codegen 只消费 System JSON，不直接读场景 |
| D2 | MVP 切面粒度 | System 恒为单 Trigger（桥接模式外联）；**格式从第一天按多单元设计**，二期物化是加法 |
| D3 | 指令覆盖 | **混合运行时委托**：白名单指令生成原生可读代码；其余指令内嵌数据、运行时构造后 `execute(ctx)` 委托——MVP 即覆盖全部指令，毕业是梯度不是门槛 |
| D4 | 采用/回滚 | MVP 手动：导出器产出"脚本 + 就绪报告 + 操作说明"，用户自行禁用原 Trigger、挂载新脚本；回滚反向 |
| D5 | 拓扑面板 | MVP 纯数据源（只读 `build_topology()`），无 UI 改动 |

## 4. System 工件

### 4.1 格式（`fuse_generated/systems/<snake_case_name>.json`）

```json
{
	"format_version": "1.0",
	"name": "player_damage_flow",
	"description": "玩家受击扣血、死亡检查与重生时序",
	"source": {
		"derived_from": "res://demos/fuse/brickian/game_scene.tscn",
		"derived_at": "2026-08-30T12:00:00",
		"topology_digest": "a1b2c3"
	},
	"units": [
		{
			"id": "u1",
			"kind": "trigger",
			"scene": "res://demos/fuse/brickian/game_scene.tscn",
			"node_path": "GameManager/GameFlow",
			"level": "L4"
		}
	],
	"externals": {
		"events_out": [{"name": "Hit", "outside_consumers": true}],
		"events_in": [{"name": "AllEnemyDied", "outside_producers": true}],
		"variables": [
			{"name": "hp", "scope": "scope", "container": "../Target", "shared_outside": false}
		]
	},
	"acknowledged_warnings": [],
	"emit": {
		"output_script": "res://fuse_generated/scripts/player_damage_flow.gd",
		"native_instructions": ["Wait", "SendEvent", "Print"]
	}
}
```

字段规则：

- `name`：snake_case，全局唯一，文件名 = name + `.json`
- `description`：推导时留空，人填或 AI 生成（二期可用 preset AI 管线生成——同款闭环可校验）
- `units[]`：MVP 恒 1 个元素；`id` 稳定（后续物化模式用它做交叉引用）
- `externals`：**边界声明**。MVP 桥接模式下全部外联（见 §6.3）；`shared_outside` 由 cross_references 推导（该变量是否被系统外单元读写）
- `acknowledged_warnings`：竞态等预警的**显式确认**——推导报告里有 warning 而 `acknowledged_warnings` 缺对应条目时校验器拒绝生成（见 §5）
- `emit.native_instructions`：白名单覆盖偏好；缺省用导出器默认白名单

### 4.2 推导算法（derive）

输入：场景根。输出：每个 Trigger/MultiEventTrigger 一份**单例 System 草稿** + 一份推导报告。

```
1. topology = InstructionAnalyzer.build_topology(scene_root)
2. 连通分量计算（用 cross_references 的 signal/variable 边做并查集）——
   MVP 仅用于报告标注（"此单元与 X/Y 同分量，建议二期物化"），草稿仍按单例产出
3. 对每个非嵌套 trigger（is_nested==true 的跳过并在报告中说明：需到子场景内推导）：
   a. units = [该 trigger]
   b. events_out/in：从该单元的 SendEvent 指令与 OnReceiveEvent 事件提取，
      outside_consumers/producers 由分量内是否有对端判定
   c. variables：从 analyze_trigger 的三层变量清单提取，shared_outside 按分量边界判定
   d. warnings：topology.cross_references 中涉及该单元的 warning 条目（竞态）
4. 草稿落盘 fuse_generated/systems/drafts/<trigger_name>.json（drafts 前缀区分草稿与定稿）
```

人（或 AI）从 drafts 中挑选拷贝为正式 System、补 description、确认 warnings——这一步就是"整理出系统（要做什么，包含哪些组件）"。

## 5. System 校验器（`editor/preset_ai/` 同级新模块 `editor/graduation/`）

独立于 preset_validator（工件类型不同），但**复用 finding 体系与 CLI 模式**：

| code | severity | 条件 |
|------|----------|------|
| `E_FORMAT_VERSION` | error | format_version ≠ "1.0" |
| `E_UNIT_NOT_FOUND` | error | units[].scene/node_path 在当前项目中解析不到节点 |
| `E_UNIT_LEVEL_MISMATCH` | error | 声明 level 与节点实际层级不符（复用 `FusePresetSerializer.detect_level`） |
| `E_EXTERNAL_UNRESOLVED` | error | events_in 的生产者/变量容器在拓扑中不存在 |
| `E_WARNING_NOT_ACKNOWLEDGED` | error | 拓扑中该单元存在竞态 warning，acknowledged_warnings 未含对应条目 |
| `E_EMIT_TARGET_CONFLICT` | error | output_script 与既有非本导出器产物冲突（覆盖保护） |
| `W_SINGLETON_IN_COMPONENT` | warning | 该单元属于多单元分量（二期物化候选，当前将全量桥接） |
| `W_NESTED_UNIT` | warning | 单元位于实例化子场景内（生成目标与挂载点需人工确认） |

CLI：`Godot --headless --path . res://addons/fuse/editor/graduation/validate_system.tscn -- <system.json | dir> [--report <out>]`，退出码 0/1/2 对齐既有约定。

## 6. 代码生成器（generate）

### 6.1 输入输出

输入：一份**校验通过**的 System JSON。输出：

- `res://fuse_generated/scripts/<name>.gd`（生成脚本）
- `res://fuse_generated/scripts/<name>.report.md`（就绪报告：原生覆盖率、委托清单、warnings、采用/回滚操作说明）

### 6.2 生成脚本骨架（桥接模式）

```gdscript
# ============================================================
# 由 Fuse 场景毕业导出器生成 — 请勿手工编辑委托数据块
# System: player_damage_flow
# 源单元: GameManager/GameFlow (L4) @ game_scene.tscn
# 原生覆盖率: 6/9 指令 (67%)；委托: [CrossfadeToMusic, InstantiateScene, ...]
# 采用: 禁用源 Trigger 节点 → 本脚本挂到同路径节点 → 运行验证
# 回滚: 恢复源 Trigger → 移除本脚本
# ============================================================
extends Node

const FuseDelegation := preload("res://addons/fuse/editor/graduation/fuse_delegation.gd")

# ---- 委托数据块（PresetValueCodec 在 _ready 重建为 BaseInstruction）----
const _DELEGATED_BINDINGS := {
	"b0": [<内嵌指令 JSON 数组>],
}

var _delegated: Dictionary = {}          # binding_id -> Array[BaseInstruction]
var _ctx: ExecutionContext               # 桥接执行上下文（FuseDelegation 构建）

func _ready() -> void:
	FuseDelegation.setup(self)           # 变量/事件桥接面注册
	_delegated = FuseDelegation.build_delegated(_DELEGATED_BINDINGS)
	# … 事件接线（见 6.4）

func _exit_tree() -> void:
	FuseDelegation.teardown(self)
```

原生指令段直接写等义 GDScript（可读、可改）；委托段调 `FuseDelegation.run(self, _delegated["b0"], _ctx)`。

### 6.3 桥接面（`fuse_delegation.gd`，生成脚本唯一的运行时依赖）

- **变量桥**：读写全部走现有变量服务（global/scope/local 的运行时 API——**实现首任务为 API 核实**，见 §9 风险 1），不在生成代码里物化状态
- **事件桥**：SendEvent → 事件总线发送（对齐现有总线 API）；OnReceiveEvent → 订阅/退订生命周期
- **指令桥**：`build_delegated()`（JSON → 指令对象，走 PresetValueCodec）、`run()`（顺序/并行按源 ActionRunner.execution_mode，await 语义保真）
- **上下文桥**：为委托指令构建 ExecutionContext（目标节点 = 挂载节点，保持相对 NodePath 语义）

### 6.4 事件语义映射（保真要求）

| Fuse 事件 | 生成代码 |
|-----------|----------|
| OnReady | `_ready()` |
| OnInputAction | `_unhandled_input()`（action 名与触发模式保真） |
| OnInterval | `Timer`（interval/随机区间/max_repeats/stop_condition 保真；stop_condition 为条件对象时纳入委托数据） |
| OnReceiveEvent | 总线订阅（`_ready` 订阅 / `_exit_tree` 退订） |
| 其余事件类型 | **整事件委托**：事件对象进委托数据，由桥接面驱动（MVP 不逐个写原生映射） |

门控保真：`trigger_once`（标志位）、`cooldown_mode/cooldown_time`（时间戳检查函数）在生成代码中显式实现，语义对齐 `BaseTrigger`。

### 6.5 原生发射器白名单（初始集，实现期可调）

按"高频 + 直译无歧义"选：`Wait`、`Print`、`SendEvent`（走事件桥）、`SetVariable`/`SetGlobalVariables`/`LoadGlobalVariables`（走变量桥）、`MathOperation`、`ShowHideUI`、`SetUIText`。约 8-10 个起步；其余全部委托。白名单外但结构简单的（IfThen/IfElse/ForEach）**首版不做原生**——控制流的原生直译与委托分支混合的语义边界复杂，留给二期。

## 7. CLI 入口（对齐既有三件套模式）

```bash
# 1. 推导草稿（幂等：重跑覆盖 drafts/）
Godot --headless --path . res://addons/fuse/editor/graduation/derive_systems.tscn -- --scene res://demos/fuse/brickian/game_scene.tscn [--out res://fuse_generated/systems/drafts]

# 2. 校验 System
Godot --headless --path . res://addons/fuse/editor/graduation/validate_system.tscn -- <file-or-dir> [--report <out>]

# 3. 生成（先内部跑校验，不过则拒绝生成）
Godot --headless --path . res://addons/fuse/editor/graduation/export_system.tscn -- <system.json>
```

## 8. 验证闭环

1. **解析级**（MVP 硬门禁）：生成脚本 headless `load()` 零解析错误（test 场景驱动，退出码门禁）
2. **结构级**：就绪报告断言——覆盖率数字与委托清单和 System 的 units 内容一致；委托数据块重建后指令数与源 preset 一致（防静默丢失，对齐闭环 E_ROUNDTRIP_LOSS 思想）
3. **金样例**：挑 2 个真实场景单元生成并入库产物，测试断言其解析通过 + 报告内容稳定（回归基线）——建议 game_scene 的 `GameManager/GameFlow`（L4 MultiEventTrigger）与 title_scene 的 `Control/TitleHint/HintBreath`（L2 Trigger）。注意拓扑只扫 Trigger/MultiEventTrigger，L1/L3 单元（ActionRunner/Runner，如 SpawnEnemy）**不在 MVP 推导范围**，报告中如实标注
4. System 校验器自身：正例/负例 fixture（缺确认的竞态、幽灵节点、版本错）断言 error code

## 9. 风险与开放问题

1. **运行时 API 核实（实现首任务）**：变量服务/事件总线的对外调用面（方法名、订阅接口、scope 容器解析）、ExecutionContext 能否在 Trigger 之外安全构建——本 spec 的桥接面签名按假设写，实现前必须以源码为准核实并回填。若 ExecutionContext 不能脱离 Trigger 构建，委托桥需要一个薄适配层。
2. **await 语义保真**：Wait/Tween 等异步指令的完成等待、并行模式的汇合点，委托桥必须对齐 ActionRunner 现行为——以 `test` 场景实测对照，不凭文档。
3. **事件时序差异**：生成的 `_unhandled_input` vs Fuse 事件的输入处理阶段可能不同（处理顺序/焦点），就绪报告中显式标注此风险。
4. **cooldown 的 PER_OBJECT 语义**：依赖 Fuse 内部按对象状态，桥接实现需核实其存储位置；若过于内部，MVP 该模式降级为 GLOBAL 并在报告中标注语义偏差。
5. **委托数据内嵌 NodePath**：委托指令的相对路径以挂载节点为锚——采用说明必须要求挂载到源 Trigger 同路径，报告强调。
6. **二期依赖**：物化模式（多单元）不做，但 System 格式/校验器不得写死"恒 1 单元"的假设（数组遍历而非下标访问）。

## 10. 里程碑

| 里程碑 | 内容 | 验收 |
|--------|------|------|
| M0 | API 核实 + 桥接面骨架（fuse_delegation.gd：变量/事件/指令/上下文四桥，含 await 语义实测） | 桥接面单测通过；与 ActionRunner 行为对照记录 |
| M1 | System 格式 + 推导器 + 校验器 + CLI | 真实场景推导出草稿；正/负例校验断言全绿 |
| M2 | 生成器（事件映射 + 门控保真 + 白名单发射器 + 委托数据块）+ 就绪报告 | 金样例 2 份生成、解析零错、覆盖率与委托清单一致 |
| M3 | 验证闭环 + 文档（cheatsheet 增"毕业导出"节、AGENTS.md 工具链小节）| 全量回归（既有 8 项 + 新增）全绿 |

## 11. 文件清单（新增）

- `addons/fuse/editor/graduation/system_schema.gd`（格式常量与字段校验）
- `addons/fuse/editor/graduation/system_deriver.gd` + `derive_systems.tscn`
- `addons/fuse/editor/graduation/system_validator.gd` + `validate_system.tscn`
- `addons/fuse/editor/graduation/codegen/gdscript_emitter.gd`（白名单发射器）
- `addons/fuse/editor/graduation/codegen/event_mapper.gd`
- `addons/fuse/editor/graduation/export_system.tscn`
- `addons/fuse/core/graduation/fuse_delegation.gd`（桥接面——运行时依赖，故放 core）
- `addons/fuse/tests/graduation/test_system_deriver.tscn` / `test_system_validator.tscn` / `test_codegen_golden.tscn` / `test_fuse_delegation.tscn`
- 产物目录：`fuse_generated/systems/`（草稿 + 定稿）、`fuse_generated/scripts/`
