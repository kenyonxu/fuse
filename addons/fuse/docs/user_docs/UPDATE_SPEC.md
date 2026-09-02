# user_docs 更新规格说明（UPDATE_SPEC）

> 用途：规范 `addons/fuse/docs/user_docs/` 目录的清理、导航补全与链接修复工作。
> 状态：✅ 已完成（2026-07-07） | 创建日期：2026-07-07 | 维护：Fuse 开发团队

---

## 1. 背景与动机

`user_docs/` 是面向游戏设计师与开发者的使用指南入口。当前 `README.md` 存在三类严重问题：

1. **导航严重缺失**：guides/ 实有 31 篇指南，README 仅列 5 篇，**漏列 26 篇**
2. **统计失真**：称总计 9 篇，实际 36 篇（顶层 3 + guides 31 + best_practices 2）
3. **死链遍布**：README 与 8 个子文档共 20+ 处断裂引用（归档未同步、目录名过期、层级错误）
4. **内容错位**：README 含"开发进度（Phase 0A–2C）"段——属开发状态，非用户文档职责，且其引用的死链已归档

本 spec 定义一次性清理任务，使 `user_docs/` 恢复完整导航、准确统计、零死链。

---

## 2. 现状盘点（As-Is）

### 2.1 实际目录结构（36 个 md，共 ~10554 行）

```
user_docs/
├── README.md                    195 行  导航（严重过时）
├── FEATURES.md                  106 行  功能特性
├── quick_start.md               321 行  快速开始
├── UPDATE_SPEC.md               本文件
├── guides/                      31 篇使用指南
│   ├── 01-variable-system-guide.md            594 行
│   ├── 54-global-variables-guide.md       533 行
│   ├── 18-tween-animation-guide.md            631 行
│   ├── 12-animation-guide.md                  534 行
│   ├── icon_manager_guide.md               492 行
│   ├── object_pool_system_guide.md         411 行
│   ├── 05-expression-guide.md                 407 行
│   ├── math-vector-guide.md                380 行
│   ├── debugging-guide.md                  358 行
│   ├── 17-scene-management-guide.md           298 行
│   ├── coordinate_systems_guide.md         284 行
│   ├── instruction-generator-guide.md      258 行
│   ├── event-bus-guide.md                  238 行
│   ├── 11-movement-system-guide.md            227 行
│   ├── 02-trigger-selection-guide.md          218 行
│   ├── 54-global-variables-guide.md 214 行
│   ├── 50-scene-preloading-guide.md           195 行
│   ├── 26-breakpoint-guide.md                 186 行
│   ├── 04-multi-event-trigger-guide.md        143 行
│   ├── runner-guide.md                     141 行
│   ├── multithreading-optimization.md      133 行
│   ├── 32-input-events-guide.md               128 行
│   ├── 14-physics-guide.md                    112 行
│   ├── composite-conditions-guide.md       102 行
│   ├── 23-flow-control-guide.md                99 行
│   ├── ui-guide.md                          98 行
│   ├── dictionary-operations-guide.md       98 行
│   ├── audio-guide.md                       91 行
│   ├── array-operations-guide.md            91 行
│   ├── 10-transform-guide.md                   64 行
│   └── camera-guide.md                      59 行
└── best_practices/              2 篇
    ├── custom_instruction.md             1250 行
    └── custom_event.md                    865 行
```

### 2.2 README 失真对照

| README 声称 | 实际 |
|------------|------|
| 使用指南 5 篇 | **31 篇**（漏列 26 篇） |
| 总计 9 篇 | **36 篇** |
| 列出 quick_start、global_variable_manager_v2、variable_system_v2_migration、coordinate_systems、event_bus | 其中 variable_system_v2_migration **不存在**，其余 31 篇指南仅 4 篇入导航 |

### 2.3 死链分类（20+ 处，跨 9 个文件）

#### A. README.md（8 处）

| 死链 | 实际去向 |
|------|----------|
| `guides/variable_system_v2_migration.md`（×3） | `docs/archive/archive/variable_system_v2_migration.md` |
| `../development/instruction-creation-guide.md`（×2） | `../dev_docs/guides/instruction-creation-guide.md`（development 目录已重组为 dev_docs） |
| `../../../../docs/plans/2026-01-26-fuse-phase2-instruction-plan.md` | ❌ archive 亦无（删除） |
| `../roadmap/2026-01-25-instruction-evaluation-report-v2.md` | `docs/archive/archive/roadmap/` |
| `../dev_docs/reports/variable_storage_phase1-2_report.md` | ❌ dev_docs 无 reports/（删除） |
| `../dev_docs/reports/localization_coverage_report.md` | ❌ 同上 |

#### B. quick_start.md（1 处）

| 死链 | 修复 |
|------|------|
| `../../../demos/` | 改 `../../../../demos/`（少一级；demos 在项目根） |

#### C. guides/（10 处，跨 7 文件）

| 文档 | 死链 | 处置 |
|------|------|------|
| coordinate_systems_guide.md | `../guides/transform_instructions.md` | ❌ 无（删除引用） |
| coordinate_systems_guide.md | `../guides/3d_game_development.md` | ❌ 无（删除） |
| event-bus-guide.md | `../reference/instructions/send_event.md` | ❌ reference 目录不存在（删除或改指） |
| event-bus-guide.md | `../reference/events/on_receive_event.md` | ❌ 同上 |
| 54-global-variables-guide.md | `variable_system_v2_migration.md` | 改指 `../../archive/archive/variable_system_v2_migration.md` |
| icon_manager_guide.md | `../../development/icon-system-guide.md`（×2） | 改 `../../dev_docs/guides/icon-system-guide.md` |
| multithreading-optimization.md | `../dev/multithreading-developer-guide.md` | 改 `../../dev_docs/guides/multithreading-developer-guide.md` |
| 18-tween-animation-guide.md | `../../../../docs/tween-common-patterns.md` | ❌ 无（删除） |
| 18-tween-animation-guide.md | `../roadmap/...tween-instruction-roadmap.md` | archive 有（名不同：`bricks-tween`），改指或删除 |
| 18-tween-animation-guide.md | `../development/instruction-creation-guide.md` | 改 `../../dev_docs/guides/instruction-creation-guide.md` |
| 01-variable-system-guide.md | `../system_docs/architecture/variable_system_design.md` | 层级少一级，改 `../../system_docs/architecture/variable_system_design.md` |
| 01-variable-system-guide.md | `../system_docs/api/variable_operations.md` | ❌ system_docs 无 api/（删除） |
| 01-variable-system-guide.md | `../system_docs/api/variable_scope_utils.md` | ❌ 同上 |

#### D. best_practices/custom_event.md（1 处）

| 死链 | 修复 |
|------|------|
| `../../architecture/runtime-instance-pattern.md` | 改 `../../archive/architecture/runtime-instance-pattern.md` |

### 2.4 内容错位：README 的"开发进度"段

README 行 104–135 含 Phase 0A–2C 指令开发状态表格（截至 2026-01-26）。问题：
- **职责错位**：开发进度属 `dev_docs/` 或归档内容，不应在面向用户的 user_docs/README
- **数据过时**：2026-01-26，当前 2026-07
- **引用死链**：phase2 plan（archive 无）、evaluation report（已归档）

### 2.5 元信息过时

- 最后更新：`2026-02-27`

---

## 3. 更新目标（To-Be）

1. **导航完整**：31 篇 guides 全部按主题分组入 README 导航
2. **统计准确**：36 篇
3. **零死链**：20+ 处全部修复或删除
4. **职责清晰**：移除"开发进度"段（开发状态归 dev_docs）
5. **元信息更新**：日期 → 2026-07-07

---

## 4. 详细更新项

### 4.1 重写 `README.md`（核心任务）

**删除：**
- 整个"📊 开发进度"段（Phase 0A–2C 表格、代码质量、下一步、phase2 plan / evaluation report 链接）
- 8 处死链对应的条目
- 失真的统计表（9 篇）

**补全 guides 导航（31 篇，按主题分组，建议）：**

| 分组 | 指南 |
|------|------|
| 变量系统 | variable_system_guide、global_variable_manager_v2、global-variable-persistence-guide |
| 事件与触发 | event_bus_guide、multi-event-trigger-guide、trigger-selection-guide、input-events-guide |
| 指令与执行 | instruction-generator-guide、runner-guide、flow-control-guide、breakpoint-guide、debugging-guide |
| 场景与节点 | scene-management-guide、scene-preloading-guide、movement-system-guide、object_pool_system_guide |
| 变换与坐标 | coordinate_systems_guide、transform-guide、math-vector-guide |
| 动画 / 音频 / UI | animation-guide、tween-animation-guide、audio-guide、ui-guide |
| 物理 / 相机 | physics-guide、camera-guide |
| 表达式与数据 | expression-guide、composite-conditions-guide、array-operations-guide、dictionary-operations-guide |
| 性能与工具 | multithreading-optimization、icon_manager_guide |

**修正：**
- 统计表：快速开始 1 / 使用指南 31 / 最佳实践 2 / 顶层 2（FEATURES）= 36
- "相关资源"段：dev_docs/reports 死链删除；system_docs 链接保留（有效）
- 末尾"最后更新" → 2026-07-07

### 4.2 修复 quick_start.md（1 处）

- `../../../demos/` → `../../../../demos/`

### 4.3 修复 guides/ 死链（10 处，7 文件）

按 2.3-C 表处置：
- **改指有效目标**（5 处）：global-variable-persistence、icon_manager ×2、multithreading-optimization、variable_system_guide（层级）、tween-animation（development→dev_docs）
- **删除引用**（5 处）：transform_instructions、3d_game_development、reference/instructions·events、tween-common-patterns、system_docs/api ×2

### 4.4 修复 best_practices/custom_event.md（1 处）

- runtime-instance-pattern → `../../archive/architecture/runtime-instance-pattern.md`

### 4.5 全量验证

重写后对所有 36 个 md 跑基于各文件目录的全量死链扫描。

---

## 5. 不做的事（Out of Scope）

- ❌ 不改动各 guide 正文内容（仅修链接与 README）
- ❌ 不从 archive 恢复 variable_system_v2_migration 等到 user_docs（用户向迁移指南已过时，归档即可）
- ❌ 不新建 reference/、api/ 等目录
- ❌ 不改动 `dev_docs/`、`system_docs/` 内容

---

## 6. 验收标准（全部通过 ✅）

- [x] README 导航覆盖全部 31 篇 guides（按 9 个主题分组）
- [x] 统计修正（入口 2 / 指南 31 / 最佳实践 2，合计 35 篇 + spec）
- [x] "开发进度"段已移除
- [x] README 8 处死链全部处置
- [x] quick_start、7 篇 guides、custom_event 共 12 处死链全部处置（改指 / 删除）
- [x] 全量扫描 36 个 md，**零断裂引用**
- [x] 最后更新 → 2026-07-07

---

## 7. 执行顺序

1. 重写 `README.md`（4.1，含 31 篇 guides 分组导航）
2. 修复 quick_start（4.2）
3. 修复 7 篇 guides 死链（4.3）
4. 修复 custom_event（4.4）
5. 全量扫描验证（4.5）
6. 提交：`docs: rewrite user_docs README (cover all 31 guides), fix broken links`

---

## 8. 附：与前两次清理的差异

- **user_docs 的核心问题是"导航缺失"**（漏列 26 篇），而非仅死链——README 重写工作量最大
- 死链分散在 9 个文件（dev_docs 主要 1 文件、system_docs 主要 analysis 批量），需逐文件处理
- 存在"内容错位"（开发进度段）需结构性删除，前两次无此问题
