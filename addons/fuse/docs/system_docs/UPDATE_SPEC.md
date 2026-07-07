# system_docs 更新规格说明（UPDATE_SPEC）

> 用途：规范 `addons/fuse/docs/system_docs/` 目录的清理、勘误与链接修复工作。
> 状态：✅ 已完成（2026-07-07，采用方案 B） | 创建日期：2026-07-07 | 维护：Fuse 开发团队

---

## 1. 背景与动机

`system_docs/` 是面向架构师与核心开发者的权威设计 / 分析文档集。2026-07 文档大整理后（commit `bc6a03b`、`fab7708`），大量文档被归档至 `docs/archive/`，但：

- `README.md` 未同步，引用 9 个已归档文件 + 4 个跨目录死链
- 文档篇数统计严重失真（架构声称 15 篇，实际 9 篇）
- 漏列 4 个实际存在的分析文档
- `analysis/` 中存在**系统性链接基准错误**（~50 处源码引用）
- 若干文档引用已归档或已重构的旧路径

本 spec 定义一次性清理任务，使 `system_docs/` 恢复准确、可导航、可点击。

---

## 2. 现状盘点（As-Is）

### 2.1 实际目录结构（21 个 md，共 ~17523 行）

```
system_docs/
├── README.md                                  281 行  导航（过时）
├── UPDATE_SPEC.md                             本文件
├── architecture/                              9 篇
│   ├── condition_system_design.md            1927 行
│   ├── dataflow_controlflow_design.md        1713 行
│   ├── variable_system_design.md             1666 行
│   ├── instruction_system_design.md          1427 行
│   ├── event_on_input_key_design.md          1379 行
│   ├── visual_programming_system_architecture.md 1179 行
│   ├── godot_integration_design.md            972 行
│   ├── editor_tools_design.md                 540 行
│   └── visual_programming_complete_design_summary.md 427 行
└── analysis/                                  12 篇
    ├── fuse_architecture_analysis.md         1317 行
    ├── base_instruction_analysis.md           796 行
    ├── base_variable_analysis.md              586 行
    ├── execution_context_analysis.md          544 行
    ├── fuse_architecture_advantages_analysis.md 532 行
    ├── base_event_analysis.md                 511 行
    ├── base_trigger_analysis.md               487 行
    ├── base_condition_analysis.md             331 行
    ├── action_runner_analysis.md              337 行
    ├── multi_event_trigger_analysis.md        228 行
    ├── fuse_core_analysis_report.md           195 行
    └── runner_analysis.md                     148 行
```

### 2.2 README 失真对照

| README 声称 | 实际 |
|------------|------|
| 架构设计 15 篇 | **9 篇**（README 列了 5 个不存在的） |
| 分析报告 12 篇 | **12 篇文件**，但 README 列的 12 个中 4 个不存在，另有 4 个真实文件未列出 |
| 总计 27 篇 | **21 篇** |

**README 列出但不存在（已归档）的 9 个文件：**

| README 引用 | 实际位置 |
|------------|----------|
| `architecture/trigger_system_design.md` | `docs/archive/archive/trigger_system_design.md` |
| `architecture/trigger_architecture_design.md` | `docs/archive/archive/trigger_architecture_design.md` |
| `architecture/shared_variable_implementation_design.md` | ❌ archive 亦无 |
| `architecture/extensibility_design.md` | `docs/archive/archive/extensibility_design.md` |
| `architecture/event_on_input_key_summary.md` | `docs/archive/archive/event_on_input_key_summary.md` |
| `analysis/fuse_optimization_from_flowkit_analysis.md` | `docs/archive/analysis/` |
| `analysis/fuse_optimization_from_gamecreator_analysis.md` | `docs/archive/analysis/` |
| `analysis/variable_container_analysis.md` | `docs/archive/archive/` |
| `analysis/play_juicy_effect_task_execution_chain_analysis.md` | `docs/archive/analysis/` |

**实际存在但 README 漏列的 4 个分析文档：**
- `analysis/base_event_analysis.md`
- `analysis/fuse_architecture_advantages_analysis.md`
- `analysis/multi_event_trigger_analysis.md`
- `analysis/runner_analysis.md`

**README 跨目录死链：**

| README 引用 | 状态 |
|------------|------|
| `../user_docs/guides/global_variable_manager_v2.md` | ✅ |
| `../user_docs/best_practices/custom_event.md` | ✅ |
| `../dev_docs/reports/variable_storage_phase1-2_report.md` | ❌ dev_docs 无 reports/ |
| `../dev_docs/reports/localization_coverage_report.md` | ❌ 同上 |
| `../proposals/pending/internal_optimization_plan.md` | ❌ proposals 在 archive |
| `../proposals/pending/instruction_selector_simple_design.md` | ❌ 同上 |

### 2.3 analysis/ 系统性链接基准错误（重点）

`analysis/*.md`（尤其 `fuse_architecture_analysis.md`）大量以 `[文字](addons/fuse/core/base/xxx.gd:行号)` 形式引用源码。问题双重：

1. **基准错误**：markdown 链接按文档目录（`system_docs/analysis/`）解析，而路径 `addons/fuse/...` 是项目根相对。从 analysis/ 出发应为 `../../../../../addons/fuse/...`（上升 5 级）。当前写法 100% 解析失败。
2. **行号格式**：`:行号` 非 markdown 标准锚点（应为 `#L行号`）。

**核查结果**：50 个唯一 .gd 引用中，**46 个文件实际存在**（仅链接写法错），3 个路径已过期（`core/base/base_trigger.gd`、`events/base_event.gd`、`events/on_input_key.gd`——类已迁移，需重定位），1 个为脚本误抓的行内代码。

### 2.4 真·死链（目标已归档或重构）

| 文档 | 死链 | 实际去向 |
|------|------|----------|
| `fuse_architecture_advantages_analysis.md` | `../architecture/trigger_system_design.md` | archive |
| `fuse_architecture_analysis.md` | `docs/architecture/runtime-instance-pattern.md` | `docs/archive/architecture/` |
| `fuse_architecture_analysis.md` | `addons/fuse/docs/multithreading.md` | 拆分为 `dev_docs/guides/multithreading-developer-guide.md` + `user_docs/guides/multithreading-optimization.md` |
| `variable_system_design.md` | `../../development/scope_source_fix_progress.md` | `docs/archive/archive/development/` |
| `variable_system_design.md` | `../../development/remaining_fixes_guide.md` | 同上 |
| `variable_system_design.md` | `../../development/scope_source_todos.md` | 同上 |
| `visual_programming_system_architecture.md` | `../../architecture/runtime-instance-pattern.md` | `docs/archive/architecture/` |

### 2.5 元信息过时

- 最后更新：`2026-01-25`

---

## 3. 更新目标（To-Be）

1. **README 零死链、统计准确**：篇数与实际一致，9 个归档文件移除或改为 archive 指向，4 个漏列文档补入
2. **真死链全部处置**：归档文件改指 `../archive/`，重构文件改指新位置
3. **.gd 引用可解析**：系统性修复基准错误（推荐改为行内代码格式，见 4.2）
4. **元信息更新**：日期 → 2026-07-07

---

## 4. 详细更新项

### 4.1 重写 `README.md`（核心任务）

**删除：**
- 9 个已归档 / 不存在文件的条目（trigger_system_design、trigger_architecture_design、shared_variable_implementation_design、extensibility_design、event_on_input_key_summary、fuse_optimization_from_flowkit/gamecreator_analysis、variable_container_analysis、play_juicy_effect_task_execution_chain_analysis）
- 段落"相关资源"中 4 个跨目录死链（dev_docs/reports×2、proposals/pending×2）
- 失真的统计表（15/12/27）

**新增 / 修正：**
- 补入 4 个漏列分析文档：base_event_analysis、fuse_architecture_advantages_analysis、multi_event_trigger_analysis、runner_analysis
- 统计表改为：架构 9 篇、分析 12 篇、共 21 篇
- "相关资源"段：dev_docs 链接改为有效目标（如 `../dev_docs/`、`../dev_docs/guides/`），proposals 段删除或指向 `../archive/proposals/`
- 末尾"最后更新" → 2026-07-07

**保留（已核实有效）：**
- 全部 9 篇 architecture 与 8 篇已列 analysis 的链接
- `../user_docs/guides/global_variable_manager_v2.md`、`../user_docs/best_practices/custom_event.md`

### 4.2 修复 analysis/ 系统性 .gd 引用（重点，~50 处）

**推荐方案 B —— 改为行内代码格式：**

将 `[文字](addons/fuse/core/base/base_event.gd:169)` 改为 `` `addons/fuse/core/base/base_event.gd:169` ``。

理由：
- 分析文档引用源码行，行内代码比超长相对链接（`../../../../../addons/fuse/...`）更整洁可读
- `.gd:行号` 本就不是 markdown 标准链接，IDE / grep 可直接定位
- 一次性批量替换，无歧义

**备选方案 A —— 改正确相对路径：**
改为 `../../../../../addons/fuse/core/base/base_event.gd`（去掉 `:行号` 或改 `#L169`）。链接可点击，但路径冗长。

**3 个真过期路径单独处理**（无论选 A/B 都需重定位）：
- `core/base/base_trigger.gd` → 实际位置待查（可能在 `core/trigger.gd` 或别处）
- `events/base_event.gd` → 实际为 `core/base/base_event.gd`
- `events/on_input_key.gd` → 实际位置待查

### 4.3 修复真死链（7 处）

| 文档 | 旧链接 | 改为 |
|------|--------|------|
| fuse_architecture_advantages_analysis.md | `../architecture/trigger_system_design.md` | 删除引用，或改 `../../archive/archive/trigger_system_design.md` |
| fuse_architecture_analysis.md | `docs/architecture/runtime-instance-pattern.md` | `../../archive/architecture/runtime-instance-pattern.md`（并修基准） |
| fuse_architecture_analysis.md | `addons/fuse/docs/multithreading.md` | 改指 `../dev_docs/guides/multithreading-developer-guide.md` 或删除 |
| variable_system_design.md | `../../development/scope_source_fix_progress.md` | `../../archive/archive/development/scope_source_fix_progress.md` |
| variable_system_design.md | `../../development/remaining_fixes_guide.md` | `../../archive/archive/development/remaining_fixes_guide.md` |
| variable_system_design.md | `../../development/scope_source_todos.md` | `../../archive/archive/development/scope_source_todos.md` |
| visual_programming_system_architecture.md | `../../architecture/runtime-instance-pattern.md` | `../../archive/architecture/runtime-instance-pattern.md` |

> 注：`fuse_architecture_analysis.md` 的链接基准也是错的（写在 analysis/ 却用 `docs/architecture/...`），修复时一并校正为从 analysis/ 出发的正确相对路径。

### 4.4 其余文档扫描（验证项）

重写后对所有 21 个 md 跑一次基于各文件目录的全量死链扫描，确认无新增断裂。

---

## 5. 不做的事（Out of Scope）

- ❌ 不从 `docs/archive/` 恢复任何归档文档到 system_docs
- ❌ 不改动 `analysis/` 与 `architecture/` 的文档正文内容（仅修链接与 README）
- ❌ 不重新组织目录结构（保持 architecture/ + analysis/ 二分）
- ❌ 不改动 `dev_docs/`、`user_docs/` 内容

---

## 6. 验收标准（全部通过 ✅）

- [x] README 内 architecture/ 与 analysis/ 链接全部指向真实存在文件
- [x] 无指向 `reports/`、`proposals/pending/`、9 个已归档文件的链接
- [x] README 统计 = 架构 9 / 分析 12 / 共 21
- [x] 4 个漏列分析文档已补入 README（base_event、fuse_architecture_advantages、multi_event_trigger、runner）
- [x] analysis 的 .gd 引用采用方案 B：64 处 `[`X`](...gd:行号)` → `` `X` ``（7 文件）
- [x] 7 处真死链全部修复（改指 `../archive/` 或新位置）
- [x] 3 个过期 .gd 路径随方案 B 自动消解（路径被丢弃，仅保留代码名）
- [x] 全量扫描 21 个 md + README，**零断裂引用**
- [x] 最后更新日期 → 2026-07-07

---

## 7. 执行顺序

1. **决定 .gd 引用方案**（A 改相对路径 / B 改行内代码）—— 建议先定，影响 4.2 工作量
2. 重写 `README.md`（4.1）
3. 批量修复 analysis 的 .gd 引用（4.2，按选定方案）
4. 修复 7 处真死链（4.3）
5. 全量扫描验证（4.4）
6. 提交：`docs: rewrite system_docs README, fix broken source refs and archived links`

---

## 8. 附：与 dev_docs 的差异提示

- system_docs 的链接问题**比 dev_docs 更深**：除 README 死链外，还有 analysis 的系统性基准错误（dev_docs 无此问题）
- 建议本次 spec 执行时，.gd 引用方案需用户拍板（A vs B），其余项可自主推进
- system_docs 内部文档体积大（多个 1000+ 行），编辑时注意用 offset/limit 精读目标区域，勿全量读入
