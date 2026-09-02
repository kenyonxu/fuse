# system_docs/analysis 文档审计报告

> 审计日期：2026-07-07
> 范围：`addons/fuse/docs/system_docs/analysis/` 下全部 12 篇分析文档
> 基准：`addons/fuse/core/` 实际代码实现
> 方法：7 个并行子代理逐篇对比代码 + 人工事实核查

---

## 1. 审计总览

### 1.1 评级分布

| 评级 | 篇数 | 文档 |
|------|------|------|
| 🟢 基本准确 | 2 | base_event_analysis、fuse_core_analysis_report |
| 🟡 部分过时 | 6 | base_instruction_analysis、action_runner_analysis、multi_event_trigger_analysis、runner_analysis、fuse_architecture_analysis、fuse_architecture_advantages_analysis |
| 🔴 严重过时 | 4 | base_condition_analysis、base_trigger_analysis、base_variable_analysis、execution_context_analysis |

### 1.2 处置建议分布

| 处置 | 篇数 | 文档 |
|------|------|------|
| 重写 | 4 | base_condition、base_trigger、base_variable、execution_context |
| 大更新 | 4 | base_instruction、action_runner、fuse_architecture_analysis、fuse_architecture_advantages |
| 小更新 | 4 | base_event、multi_event_trigger、runner、fuse_core_analysis_report |

**结论：12 篇中无一可原样保留，8 篇需大改或重写。** 文档整体落后于代码至少一个大版本（v2.0 runtime 实例 + 对象池 + 线程体系之后）。

---

## 2. 横向发现：未文档化的架构演进

这是最核心的问题——下列 6 大体系在代码中已成熟，但绝大多数分析文档**完全未覆盖**或仅在文末"v2.0 附录"一笔带过而主体未回填：

### 2.1 Runtime 实例三件套（影响最广）
`RuntimeEventInstance` / `RuntimeInstructionInstance` / `RuntimeActionRunnerInstance`（均 RefCounted，位于 `core/` 顶层）实现运行时状态隔离。早期文档普遍描述为「Resource 直接持有状态 / Trigger 直接持有 Event」，实际运行期一切状态走 Runtime 实例。
- 受影响文档：**全部 12 篇**（base_event/multi_event_trigger/fuse_core 较好，其余严重缺失）

### 2.2 对象池 `core/pooling/`（5 个类，全文未覆盖）
`FuseObjectPool` / `FusePoolItem` / `FusePoolManager` / `FuseRecycleTimer` / `InstructionInstancePool`。`InstructionInstancePool` 静态池化 RuntimeInstructionInstance。**无任何分析文档提及。**

### 2.3 线程系统 `core/threading/`（4 个类，仅 fuse_architecture §11.7 覆盖）
`FuseTaskManager` / `ParallelConditionEvaluator` / `FuseThreadSafe` / `FuseThreadingConfig`。BaseCondition 的 `is_thread_safe` / `_compute_thread_safety()` 配套此体系。base_condition_analysis 完全未提线程安全。

### 2.4 变量系统分化（7 个类，文档停留在 2~3 类）
| 文档常见描述 | 实际实现 |
|------------|----------|
| BaseVariable + GlobalVariableManager(单例) + VariableScope(LOCAL/GLOBAL) | BaseVariable + **VariableContainer(@deprecated)** + **ScopeVariableContainer(Node)** + **VariableContext(RefCounted)** + **GlobalVariableManager(RefCounted)** + **GlobalVariableAssistant(Node)** + **GlobalVariableResource** + **GlobalVariableService**；VariableScope = LOCAL/SCOPE/GLOBAL 三值 |

### 2.5 BaseTrigger 抽象 + 两层继承（文档普遍描述为单类）
`BaseTrigger(@abstract, core/base_trigger.gd)` ← `Trigger(core/trigger.gd)` / `MultiEventTrigger(core/multi_event_trigger.gd)`。文档普遍写「Trigger extends Node」或把 BaseTrigger 当具体类描述。**路径错误**也是高发项：多文档写 `core/base/base_trigger.gd`，实际在 `core/base_trigger.gd`。

### 2.6 统一基础设施已就位（文档仍当作"待改进"）
- `FuseLogger`：统一日志，多数 `_log_*` 方法已委托它——base_instruction/action_runner/base_condition 文档仍列"日志格式不统一"为问题
- `FuseError`：错误对象 + 本地化错误键——多文档未提
- `FuseLocalization`：`_log_*_localized` 方法族——文档未提

### 2.7 顶层新增核心类（全文无提及）
`fuse_event_bus.gd`（全局事件总线 Node）、`fuse_runtime_bridge.gd`（运行时桥接 Node）、`ExecutionDiagnostics`、`CompiledInstructionSequence`。

---

## 3. 逐篇详审

### 3.1 base_instruction_analysis.md — 🟡 大更新
- **首版分析（1–394 行）过时**：称 `execute()` 默认实现"过于简单直接调 `_on_execution_completed()`"——**实际 `execute()` 已是 `@abstract`**（base_instruction.gd:379），整个"高优先级改进 1"基于错误前提
- 改进建议项**大多已实现**：超时控制（`set_timeout` 等，906–966 行，用 SceneTreeTimer）、统一错误（`FuseError.ErrorType`）、FuseLogger 日志、ExecutionMode 异步
- **未覆盖**：codegen 静态分析钩子（`_get_variable_accesses` 等）、i18n 资源名同步、图标四级回退

### 3.2 action_runner_analysis.md — 🟡 大更新
- 首版"超时简单/并行竞态/代码重复"问题已被 v2.0 解决（`_SignalAggregator`、`_execute_instruction` 统一）
- 类名差异未区分：action_runner 用 `_SignalAggregator`，runtime_action_runner_instance 用 `_ParallelSignalAggregator`
- **未覆盖**：RuntimeActionRunnerInstance 的状态隔离价值、批量信号模式、状态缓存变量
- ⚠️ **勘误**：子代理曾报"core/execution、core/pooling、core/serialization 目录缺失、幽灵引用、运行时崩溃"——**经直接核查为误判**。三目录及 `CompiledInstructionSequence`/`InstructionInstancePool`/`InstructionSerializer` 类均真实存在且引用有效（`action_runner.gd:9` preload 生效）。`ExecutionTracker` 位于 `editor/debugging/`。

### 3.3 base_event_analysis.md — 🟢 小更新
- 信号流向描述漏 `RuntimeEventInstance` 中转层（triggered 按 trigger meta 过滤转发）
- 行号漂移：源文件 455 → 实际 534
- 补 `get_event_icon` / `get_detailed_info` / `_get_node_display_name` 方法

### 3.4 base_condition_analysis.md — 🔴 重写
- 主体是 2026-03 前的"批评+改进建议"稿，**绝大部分建议已实现**却仍以"待改进问题"形式列出：
  - "缺乏缓存" → 已实现完整缓存（`enable_cache`/`cache_duration`/上下文哈希失效，615–710 行）
  - "get_dependencies 返回空" → 已实现完整依赖图（357–873 行）
  - "缺乏线程安全" → 已实现 `is_thread_safe`/`_compute_thread_safety`
  - "`_evaluate_condition` 无默认实现是缺陷" → 实为 `@abstract` 设计意图
- **错误**：称 BaseCondition 有"条件满足/失败信号"——实际**无任何 signal**，`on_condition_met/failed` 是普通方法

### 3.5 base_trigger_analysis.md — 🔴 重写
- 主体（1–418 行）描述**不存在的旧版单文件 BaseTrigger**（trigger_actions/_check_conditions/is_triggered/cooldown_time/trigger_once 等成员全不存在）
- 实际 `base_trigger.gd` 是纯 `@abstract` 基类，5 个抽象方法；具体逻辑在 `trigger.gd`
- 路径错：写 `core/base/base_trigger.gd`，实际 `core/base_trigger.gd`
- 附录称 BaseEvent 在 `events/base_event.gd`——实际 `core/base/base_event.gd`（`events/` 目录不存在）

### 3.6 multi_event_trigger_analysis.md — 🟡 小更新
- 继承声明含糊：应明确 `MultiEventTrigger extends BaseTrigger`
- 漏 `use_conditions` 字段（控制 `conditions` 动态可见性）
- 漏 `trigger_binding(index, context=null)` 第二参数
- 漏 `_initialize_runtime_instances` 内部先调 `_cleanup_runtime_instances`

### 3.7 base_variable_analysis.md — 🔴 重写
- 前 6 节基于**臆造 API**：`_validate_value()`、`get_modification_history()`、"类型验证不严"等问题——**这些方法/问题均不存在**（`set_value` 直接赋值，无类型校验）
- 称 GlobalVariableManager 是"单例 Node"——实际 `extends RefCounted` 静态 `_instance`
- 漏 `VariableContext`（463 行，变量访问核心）、`GlobalVariableService`、VariableContainer/ScopeVariableContainer 二分
- 仅 v2.0 后记（502–587 行）有保留价值

### 3.8 execution_context_analysis.md — 🔴 重写
- 主体描述的方法/字段**多数不存在**或已迁移：`_execution_state`/`_execution_history`/`_break_loop_flag` 等已迁至 `ExecutionDiagnostics` 和 `VariableContext`，EC 现为门面
- 把已实现的 fallback（`get_tree()` 从主场景取）当作"待改进建议"
- 漏整个委托架构（VariableContext + ExecutionDiagnostics 拆分）

### 3.9 runner_analysis.md — 🟡 小更新
- 信号发现用 `get_signal_list()` → 实际 `SignalManager.has_signal_named/get_node_signals`
- 漏编辑器集成（`@tool` + 动态 signal_name 下拉）、`current_execution_context` 字段、`@export_storage` 语义
- 行号 318→430；图标 Play.svg→ViewportSpeed.png

### 3.10 fuse_architecture_analysis.md（1317 行） — 🟡 大更新
- §1–10 主体描述早期单层架构，§11 演进章节质量较好但与主体**割裂**
- §2.4 Trigger 单类 → 实际 BaseTrigger/Trigger/MultiEventTrigger/Runner 四兄弟 + Runtime 双实例
- §4 变量系统仅 BaseVariable + 单例 Manager → 实际 7 类
- §1.1 分层图缺 pooling/threading 层
- §11.x 子文档链接（如 `../../archive/architecture/runtime-instance-pattern.md`）指向 archive，需核实

### 3.11 fuse_architecture_advantages_analysis.md — 🟡 大更新
- LimboAI/状态机集成示例用错 API：`context.set_agent/set_scene_root/get_agent` **均不存在**——实际字段 `target`/`trigger`/`owner_node`
- Trigger `extends Node` → 实际 `extends BaseTrigger`
- 漏 Runtime 三件套、对象池、线程、变量四件套、MultiEventTrigger
- 核心理念（Resource-based、可组合 ActionRunner）仍成立，可保留

### 3.12 fuse_core_analysis_report.md — 🟢 小更新
- 主体章节（指令/执行/流程/变量/事件）与代码吻合
- **硬错误 2 处**：Trigger 继承链（应 BaseTrigger）；GlobalVariableManager 非单例（RefCounted）
- 漏 BaseEvent 的 `initialize_with_runtime_instance` 接口、变量三层作用域
- v2.0 附录较准，补 pooling/threading/ScopeVariableManager 条目即可

---

## 4. 共性出入模式（按频次）

| 模式 | 出现篇数 | 说明 |
|------|----------|------|
| Runtime 实例体系未覆盖 | 12 | 最普遍缺口 |
| 把已实现特性列为"待改进" | 6 | base_condition/variable/execution_context/instruction/action_runner 首版 |
| 路径/类名过时 | 7 | base_trigger 位置、events/ 目录、VariableScope 值 |
| 行号引用漂移 | 几乎全部 | 低优先级，重写时自然解决 |
| 臆造 API | 3 | base_variable（_validate_value 等）、execution_context（多处方法）、advantages（set_agent） |

---

## 5. 处置优先级建议

### P0 — 重写（4 篇，与实现脱节最严重，可能误导）
`base_condition`、`base_trigger`、`base_variable`、`execution_context`
> 这 4 篇主体描述的方法/类不存在或已迁移，继续留作"分析"会误导读者。建议重写为现状描述体例（参照 base_event_analysis），旧稿归档。

### P1 — 大更新（4 篇，v2.0 章节可保留，主体需重写）
`base_instruction`、`action_runner`、`fuse_architecture_analysis`、`fuse_architecture_advantages`
> 删除已实现的"改进建议"，主体回填 Runtime 实例 / pooling / threading / 变量分化。

### P2 — 小更新（4 篇，基本准确，修硬错误 + 补新架构）
`base_event`、`multi_event_trigger`、`runner`、`fuse_core_analysis_report`
> 修路径/类名/行号，补 1–2 节新架构说明。

### 建议新增（缺失专题）
当前 analysis/ 无对象池、线程系统、变量系统（VariableContext/Scope 三层）的专题分析——重写 P0 时可拆出独立文档。

---

## 6. 方法与可信度说明

- 审计由 7 个并行子代理按代码域分组完成，每代理 Read 文档 + Grep/Read 代码逐项验证
- 子代理输出经**人工事实核查**：agent 曾误报 action_runner「幽灵引用 / 运行时崩溃」（探查偏差），经 `ls core/execution core/pooling core/serialization` + `grep class_name` 直接核查为误判，已从本报告剔除
- 行号引用的精确性未逐条复核（量大且低价值），重写时以实际代码为准

---

**报告维护**：Fuse 开发团队 | **下一步**：建议从 P0 的 4 篇重写开始，可逐篇做或派并行子代理按本报告的"实际实现"事实重写。
