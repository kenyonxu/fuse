# dev_docs 更新规格说明（UPDATE_SPEC）

> 用途：规范 `addons/fuse/docs/dev_docs/` 目录的清理与重组工作。
> 状态：✅ 已完成（2026-07-07） | 创建日期：2026-07-07 | 维护：Fuse 开发团队

---

## 1. 背景与动机

`dev_docs/` 在 2026-07 的文档大整理后（见 commit `bc6a03b`、`fab7708`），大量历史文档被归档或迁移至 `docs/archive/`。但 `README.md` 未同步更新，导致：

- **导航失效**：README 引用的 `reports/`、`archive/`、专题子目录、`proposals/` 全部不存在
- **统计失真**：文档数量、分类与实际严重不符
- **阶段描述过时**：Phase 1–5 描述与当前实现状态脱节
- **guide 内部死链**：`event_creation_guide.md` 引用已归档的迁移文档

本 spec 定义一次性清理任务，使 `dev_docs/` 恢复准确、可导航、可维护。

---

## 2. 现状盘点（As-Is）

### 2.1 实际目录结构

```
dev_docs/
├── README.md                          # 过时，待重写
├── UPDATE_SPEC.md                     # 本文件
└── guides/                            # 9 篇开发指南（共 ~10643 行）
    ├── event_creation_guide.md            2124 行  事件创建
    ├── instruction_creation_guide.md      2155 行  指令创建
    ├── condition_creation_guide.md        2045 行  条件创建
    ├── icon_system.md                     2061 行  图标系统设计
    ├── variable-operations-utility.md      939 行  变量操作工具
    ├── conditional_property_display.md     581 行  条件属性显示（Inspector）
    ├── multithreading-developer-guide.md   289 行  多线程开发
    ├── runtime_instruction_instance_guide.md 236 行  RuntimeInstructionInstance
    └── array-instructions-development.md   213 行  数组指令开发
```

### 2.2 README 引用的无效路径（死链清单）

| README 引用路径 | 实际状态 |
|----------------|----------|
| `reports/variable_storage_phase1-2_report.md` | ❌ 不存在（已归档至 `docs/archive/reports/`） |
| `reports/variable_storage_phase3-5_report.md` | ❌ 同上 |
| `reports/stage3_runtime_localization_complete.md` | ❌ 同上 |
| `reports/localization_coverage_report.md` | ❌ 同上 |
| `archive/localization_implementation_plan*.md` | ❌ dev_docs 下无 archive/ |
| `archive/CREATE_LOCAL_VARIABLE_INSTRUCTION.md` | ❌ 同上 |
| `archive/quit_instruction_implementation_plan.md` | ❌ 同上 |
| `event_system/` `instruction_system/` `localization/` `variable_system/` | ❌ 4 个专题目录均不存在 |
| `../user_docs/guides/variable_system_v2_migration.md` | ❌ 不存在 |
| `../user_docs/guides/54-global-variables-guide.md` | ✅ 存在 |
| `../system_docs/architecture/variable_system_design.md` | ✅ 存在 |
| `../system_docs/architecture/editor_tools_design.md` | ✅ 存在 |
| `../system_docs/architecture/godot_integration_design.md` | ✅ 存在 |
| `../system_docs/analysis/base_variable_analysis.md` | ✅ 存在 |
| `../proposals/pending/` `../proposals/implemented/` | ❌ proposals 在 `docs/archive/proposals/` |

### 2.3 guide 内部死链

- `guides/event_creation_guide.md:1026` 引用 `addons/fuse/docs/dev_docs/archive/migration-guide-to-runtime-instance.md` → 不存在

### 2.4 README 统计错误

| README 声称 | 实际 |
|------------|------|
| 开发指南 1 篇 | **9 篇** |
| 开发报告 4 篇 | 0 篇（已归档） |
| 归档文档 7 篇 | dev_docs 内 0 篇 |
| 总计 12+ 篇 | **10 篇**（含 README 与本 spec） |

---

## 3. 更新目标（To-Be）

1. **零死链**：所有内部链接指向真实存在的文件
2. **统计准确**：文档数量、分类反映 `guides/` 实际内容
3. **导航清晰**：按主题分组，提供"我想做 X"的任务导向入口
4. **跨目录引用正确**：指向 `system_docs/`、`user_docs/`、`docs/archive/` 的真实文件
5. **阶段描述对齐**：移除或更新与现状不符的 Phase 1–5 表述

---

## 4. 详细更新项

### 4.1 重写 `README.md`（核心任务）

#### 4.1.1 删除章节
- 删除整个"📂 专题目录"段（4 个不存在的目录）
- 删除"📊 开发报告"段及所有 `reports/*.md` 链接
- 删除"📁 归档文档"段中指向 dev_docs/archive/ 的链接
- 删除"📈 开发历程"的 Phase 1–5 段（无法核实，易再过时）
- 删除错误的"📊 文档统计"表

#### 4.1.2 新增/改写章节

**文档导航 — 按主题分组（替代旧分类）：**

```
### 核心组件创建
- 事件创建指南          guides/event_creation_guide.md
- 指令创建指南          guides/instruction_creation_guide.md
- 条件创建指南          guides/condition_creation_guide.md

### 运行时架构
- RuntimeInstructionInstance 指南   guides/runtime_instruction_instance_guide.md
- 多线程开发指南                     guides/multithreading-developer-guide.md

### 编辑器集成
- 条件属性显示（Inspector）  guides/conditional_property_display.md
- 图标系统设计              guides/icon_system.md

### 专项开发
- 数组指令开发              guides/array-instructions-development.md
- 变量操作工具              guides/variable-operations-utility.md
```

**跨目录资源（仅保留经核实的有效链接）：**
- system_docs/architecture/：variable_system_design、instruction_system_design、condition_system_design、event 相关、editor_tools_design、godot_integration_design
- system_docs/analysis/：base_event_analysis、base_instruction_analysis、base_condition_analysis、base_variable_analysis、execution_context_analysis、action_runner_analysis
- user_docs/guides/：variable_system_guide、global_variable_manager_v2、instruction-generator-guide 等

**历史归档指引：** 统一指向 `../archive/`（docs 顶层），说明"历史实现计划/报告/提案均在此，仅供参考，非当前实现权威"。

#### 4.1.3 更新元信息
- 最后更新：2026-07-07
- 文档统计表改为：开发指南 9 篇

#### 4.1.4 阅读建议改写
- "新组件开发者入门"：event/instruction/condition 三篇创建指南
- "运行时与性能"：runtime_instruction_instance + multithreading
- "编辑器扩展"：conditional_property_display + icon_system
- 移除所有指向已删 reports 的顺序建议

### 4.2 修复 `guides/event_creation_guide.md`

- 行 1026：将 `addons/fuse/docs/dev_docs/archive/migration-guide-to-runtime-instance.md` 改为指向 `docs/archive/` 下实际位置，或删除该"相关文档"行（若 archive 中也无此文件——已确认不存在，建议直接删除该注释行）

### 4.3 其余 guides 检查（已执行）

执行全量死链扫描后，**实际发现 20 处既存跨 guide 死链**（超出原识别范围），全部处置完毕：

**机械修复（11 处，目标存在、路径层级 / 目录名 / 扩展名写错）：**
- `array-instructions-development.md`：`array_add.gd` 路径少一级
- `condition_creation_guide.md`：`icon_system.md`、`multithreading-developer-guide.md` 改同级；`base_condition.gd` 路径修正
- `event_creation_guide.md`：`icon_system.md` 改同级；`base_event.gd` 路径修正
- `instruction_creation_guide.md`：`icon_system.md` 改同级；`variable_system_design.md` 路径少一级
- `variable-operations-utility.md`：`set/get_scope_variable`、`check_variable` 由 `.md` 改 `.gd` 并修正路径

**删除 / 改写（9 处，目标全项目不存在）：**
- `icon_system.md`：「C. 相关文档」3 个旧链接（`index.md`、`instruction_development.md`、`editor_extensions.md`）改写为真实同目录 guide 与架构文档
- `variable-operations-utility.md`：「相关文档」6 个 `./` 架构文档引用改写为真实的 `system_docs/` 设计 / 分析文档

---

## 5. 不做的事（Out of Scope）

- ❌ 不重新撰写或合并 9 篇 guide 的内容（它们各自完整）
- ❌ 不从 `docs/archive/` 恢复任何历史报告到 dev_docs
- ❌ 不改动 `system_docs/`、`user_docs/` 的内容
- ❌ 不新建专题子目录（event_system/ 等）——保持 guides/ 扁平结构

---

## 6. 验收标准（全部通过 ✅）

- [x] `README.md` 内所有 `guides/*.md` 链接可点击到达
- [x] `README.md` 内所有 `../system_docs/**`、`../user_docs/**` 链接经核实存在
- [x] 无任何指向 `reports/`、`proposals/`、dev_docs 内 `archive/`、4 个专题目录的链接
- [x] 文档统计数字与 `guides/` 实际文件数一致（9 篇）
- [x] `event_creation_guide.md` 的 migration 死链已处理（5 处）
- [x] 全量扫描 9 篇 guide + README，**零断裂引用**（含额外修复的 20 处既存死链）
- [x] 最后更新日期改为 2026-07-07

---

## 7. 执行顺序

1. 修复 `event_creation_guide.md:1026`（小改动，先清死链）
2. 全量扫描其余 8 篇 guide 的跨文件引用，记录问题
3. 重写 `README.md`（按 4.1 章节）
4. 按验收标准逐项核对
5. 提交：`docs: rewrite dev_docs README, fix broken links`

---

## 8. 附：guide 主题速查

| Guide | 主题 | 适用场景 |
|-------|------|----------|
| event_creation_guide | BaseEvent 子类化、RuntimeInstance、信号管理 | 新建事件 |
| instruction_creation_guide | BaseInstruction 子类化、执行方法 | 新建指令 |
| condition_creation_guide | BaseCondition 子类化、复合条件 | 新建条件 |
| runtime_instruction_instance_guide | 运行时状态隔离、超时、暂停/恢复 | 状态化指令 |
| multithreading-developer-guide | 多线程执行、线程安全 | 并发场景 |
| conditional_property_display | `_validate_property`、Inspector 动态显示 | 编辑器属性 |
| icon_system | 图标注册、配置、内置图标引用 | 组件图标 |
| array-instructions-development | element_value、变量变化通知、翻译键 | 数组类指令 |
| variable-operations-utility | 变量读写工具 API | 变量交互 |
