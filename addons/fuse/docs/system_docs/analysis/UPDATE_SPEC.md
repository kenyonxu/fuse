# system_docs/analysis 重写规格说明（UPDATE_SPEC）

> 用途：规范 `addons/fuse/docs/system_docs/analysis/` 12 篇分析文档的重写与更新工作。
> 依据：[AUDIT_REPORT_2026-07-07.md](AUDIT_REPORT_2026-07-07.md)
> 状态：✅ 已完成（2026-07-07，15 篇文档重写/更新 + 3 篇新增专题） | 创建日期：2026-07-07 | 维护：Fuse 开发团队

---

## 1. 背景与动机

2026-07-07 的逐篇审计（见 AUDIT_REPORT）确认：**12 篇分析文档无一可原样保留**，8 篇需大改/重写。文档整体落后代码至少一个大版本。最严重的是 6 大架构演进（Runtime 实例、对象池、线程、变量分化、BaseTrigger 抽象、统一基础设施）几乎全文档未覆盖；部分文档（base_variable、execution_context、base_trigger）主体描述的方法/类**根本不存在**或已迁移。

本 spec 将审计结论转化为逐篇可执行的更新规格，并标注需决策的策略选项。

---

## 2. 现状盘点（摘自审计报告）

### 2.1 评级与处置

| 文档 | 评级 | 处置 |
|------|------|------|
| base_event_analysis | 🟢 | 小更新 |
| fuse_core_analysis_report | 🟢 | 小更新 |
| base_instruction_analysis | 🟡 | 大更新 |
| action_runner_analysis | 🟡 | 大更新 |
| multi_event_trigger_analysis | 🟡 | 小更新 |
| runner_analysis | 🟡 | 小更新 |
| fuse_architecture_analysis | 🟡 | 大更新 |
| fuse_architecture_advantages_analysis | 🟡 | 大更新 |
| base_condition_analysis | 🔴 | 重写 |
| base_trigger_analysis | 🔴 | 重写 |
| base_variable_analysis | 🔴 | 重写 |
| execution_context_analysis | 🔴 | 重写 |

### 2.2 共性缺口（每篇重写时必须回填）

1. Runtime 实例三件套（`RuntimeEvent/Instruction/ActionRunnerInstance`）
2. 对象池 `core/pooling/`（5 类）
3. 线程系统 `core/threading/`（4 类）
4. 变量系统 7 类分化（VariableContainer 已 @deprecated → ScopeVariableContainer + VariableContext + GlobalVariableManager/Assistant/Resource/Service）
5. BaseTrigger 抽象 + 两层继承（Trigger / MultiEventTrigger extends BaseTrigger）
6. FuseLogger / FuseError / 本地化日志统一基础设施

---

## 3. 更新目标

1. **零臆造**：所有描述的方法/字段/类必须在代码中验证存在
2. **架构对齐**：6 大演进体系在相关文档中正确反映
3. **统一体例**：重写文档采用"现状描述"体例（参照 base_event_analysis：核心属性/方法/架构关系/子类模式），删除"批评+改进建议"旧格式
4. **路径准确**：所有代码引用路径与行号以实际代码为准

---

## 4. 详细更新项

### 4.1 P0 — 重写 4 篇（最高优先级）

> 策略选项 A（默认推荐）：旧稿移至 `docs/archive/analysis/` 留存历史，新稿原地重写。  
> 策略选项 B：原地覆盖（不保留旧稿）。

#### 4.1.1 base_condition_analysis.md
- **病灶**：主体是"批评+改进建议"稿，建议项（缓存、依赖图、线程安全、批量操作）**均已实现**却仍列"待改进"
- **硬错误**：称 BaseCondition 有"满足/失败信号"——实际**无 signal**，`on_condition_met/failed` 是普通方法
- **重写要点**：按现状描述缓存系统（enable_cache + 上下文哈希）、依赖图（get_dependency_graph 等）、线程安全（is_thread_safe + ParallelConditionEvaluator）、批量操作族（6 个 *_batch）、序列化/克隆
- **参照代码**：`core/base/base_condition.gd`（942 行）、`core/threading/parallel_condition_evaluator.gd`

#### 4.1.2 base_trigger_analysis.md
- **病灶**：主体描述**不存在的旧版 BaseTrigger**（trigger_actions/_check_conditions/is_triggered/cooldown_time 等成员全无）；路径错（写 core/base/ 实际 core/）
- **重写要点**：BaseTrigger 是 `@abstract` 基类（5 抽象方法）+ 两层继承（Trigger / MultiEventTrigger）+ CooldownMode 三档 + 与 Runtime 实例协作
- **参照代码**：`core/base_trigger.gd`（354 行，**注意位置**）、`core/trigger.gd`、`core/multi_event_trigger.gd`

#### 4.1.3 base_variable_analysis.md
- **病灶**：前 6 节基于**臆造 API**（`_validate_value`、`get_modification_history`、"类型验证不严"等方法/问题均不存在）；称 Manager 是"单例 Node"实际 RefCounted
- **保留**：仅 v2.0 后记（502–587 行）
- **重写要点**：BaseVariable 真实 API（set_value 无类型校验、value 字段、access_count/creation_time、工厂方法）、与 VariableContext/Container/Scope 三层的关系、FuseError 集成
- **参照代码**：`core/base/base_variable.gd`（1073 行）、`core/base/variable_context.gd`、`core/base/variable_container.gd`（已 @deprecated）、`core/base/scope_variable_container.gd`

#### 4.1.4 execution_context_analysis.md
- **病灶**：主体描述的方法/字段已迁移至 ExecutionDiagnostics 与 VariableContext，EC 现为门面；把已实现 fallback 当"待改进"
- **重写要点**：委托架构（EC 门面 + VariableContext 变量/循环/索引/快照 + ExecutionDiagnostics 状态/历史/依赖）、FuseError、duplicate、create_with_params
- **参照代码**：`core/base/execution_context.gd`（773 行）、`core/base/execution_diagnostics.gd`、`core/base/variable_context.gd`

### 4.2 P1 — 大更新 4 篇

#### 4.2.1 base_instruction_analysis.md
- **删**：首版分析（1–394 行）+ 已实现的"改进建议"（超时/错误/日志/异步）
- **改**：`execute()` 描述（现为 @abstract，无默认实现）
- **补**：codegen 静态分析钩子、i18n 资源名同步、图标四级回退、RuntimeInstructionInstance 协作

#### 4.2.2 action_runner_analysis.md
- **删**：首版"超时简单/竞态/代码重复"问题（已解决）+ 已实现建议
- **改**：区分 `_SignalAggregator`（action_runner）vs `_ParallelSignalAggregator`（runtime_action_runner_instance）
- **补**：RuntimeActionRunnerInstance 状态隔离、批量信号模式、状态缓存变量、编译缓存（CompiledInstructionSequence）
- **勘误注记**：保留"代码引用完整"的事实结论（审计已纠正幽灵引用误判）

#### 4.2.3 fuse_architecture_analysis.md（1317 行，最大）
- **保留**：§11 演进章节（质量较好）
- **重写 §1–10**：§1.1 分层图补 pooling/threading 层；§2.3 ActionRunner / §2.4 Trigger 改为"资源 + Runtime 实例"双层叙述并补 BaseTrigger/Trigger/MultiEventTrigger/Runner；§4 变量系统按 7 类重构
- **新增章节**：对象池、fuse_event_bus/fuse_runtime_bridge、ExecutionDiagnostics/CompiledInstructionSequence
- **核实**：§11.x 的 archive 子链接是否有效

#### 4.2.4 fuse_architecture_advantages_analysis.md
- **保留**：核心理念（Resource-based、可组合 ActionRunner）+ 对比章节
- **改写所有代码示例**：`set_agent/set_scene_root` → `target/trigger/owner_node`；Trigger extends BaseTrigger
- **补**：Runtime 三件套、pooling、threading、变量四件套、MultiEventTrigger；更新"劣势"章节（ParallelConditionEvaluator/loop flags 已部分缓解）

### 4.3 P2 — 小更新 4 篇

| 文档 | 修正项 |
|------|--------|
| base_event_analysis | 信号流向补 RuntimeEventInstance 中转；行号 455→534；补 get_event_icon/get_detailed_info/_get_node_display_name |
| multi_event_trigger_analysis | 明确 extends BaseTrigger；补 use_conditions 字段、trigger_binding 第二参数、_cleanup_runtime_instances 调用、双信号发射 |
| runner_analysis | get_signal_list→SignalManager.has_signal_named/get_node_signals；补编辑器集成节、current_execution_context 字段、@export_storage；行号 318→430；图标 Play.svg→ViewportSpeed.png |
| fuse_core_analysis_report | 修 2 硬错误（Trigger 继承链→BaseTrigger；GlobalVariableManager 非单例）；补 initialize_with_runtime_instance、变量三层作用域、pooling/threading 条目 |

### 4.4 新增专题文档（决策项）

> 选项 A（默认推荐）：新建 3 篇专题，填补 analysis/ 在 pooling/threading/variable 系统的空白。  
> 选项 B：不新建，将相关内容并入重写后的现有文档。

- `pooling_analysis.md`（对象池体系：FuseObjectPool/FusePoolManager/InstructionInstancePool/FuseRecycleTimer）
- `threading_analysis.md`（线程系统：FuseTaskManager/ParallelConditionEvaluator/FuseThreadSafe/FuseThreadingConfig）
- `variable_system_analysis.md`（变量 7 类：BaseVariable/VariableContext/Container/ScopeContainer/GlobalVariable* 全链）

---

## 5. 不做的事（Out of Scope）

- ❌ 不改 `architecture/` 下文档（本次仅 analysis/）
- ❌ 不改代码（本任务是文档对齐代码，非代码改文档）
- ❌ 不臆造未核实的实现细节——拿不准的查代码或留 TODO

---

## 6. 验收标准

- [ ] P0 4 篇重写完成，采用现状描述体例，无臆造 API
- [ ] P1 4 篇大更新完成，已实现特性不再列为"待改进"
- [ ] P2 4 篇小更新完成，硬错误修正
- [ ] 每篇覆盖相关 Runtime 实例 / pooling / threading / 变量分化事实
- [ ] 所有代码引用路径与类名经核查无误（含 base_trigger 位置）
- [ ] 决策项（4.1 策略、4.4 新增专题）已执行或明确跳过
- [ ] 如选项 A：旧 P0 稿已移至 `docs/archive/analysis/`

---

## 7. 执行顺序

1. **决策**（见 §8）：定 4.1 重写策略、4.4 是否新增专题、执行方式（逐篇/并行）
2. P0 4 篇重写（建议并行子代理，每篇 1 个，给本 spec 的"参照代码"+ AUDIT_REPORT 作输入）
3. P1 4 篇大更新
4. P2 4 篇小更新
5.（可选）4.4 新增专题
6. 全文交叉校验（路径/类名/行号抽查）+ 更新 README

---

## 8. 需决策的事项

| # | 决策 | 选项 | 推荐 |
|---|------|------|------|
| 1 | P0 重写策略 | A 旧稿归档+新稿 / B 原地覆盖 | A（保留历史） |
| 2 | 新增专题文档 | A 新建 3 篇 / B 并入现有 | A（独立清晰） |
| 3 | 执行方式 | A 逐篇顺序 / B 并行子代理 | B（P0 并行） |
| 4 | 范围 | 全 12 篇 / 仅 P0+P1 / 仅 P0 | 全 12 篇 |

---

**附**：审计事实依据见 [AUDIT_REPORT_2026-07-07.md](AUDIT_REPORT_2026-07-07.md)；架构演进清单见审计报告 §2。
