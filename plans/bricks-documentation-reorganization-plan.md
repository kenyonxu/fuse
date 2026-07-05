# Bricks 系统文档整理实施计划

**创建日期**: 2026-01-25
**目标**: 对 `docs/bricks/` 和 `addons/bricks/docs/` 目录下的文档进行系统性整理
**参考标准**: `addons/juicy_mixer/docs/` 目录结构规则

---

## 📋 目录

1. [项目概述](#1-项目概述)
2. [当前文档状态分析](#2-当前文档状态分析)
3. [目标目录结构](#3-目标目录结构)
4. [文档相关性评估标准](#4-文档相关性评估标准)
5. [实施步骤](#5-实施步骤)
6. [文档迁移清单](#6-文档迁移清单)
7. [文档更新计划](#7-文档更新计划)
8. [验证和测试](#8-验证和测试)
9. [风险和注意事项](#9-风险和注意事项)

---

## 1. 项目概述

### 1.1 整理目标

1. **结构标准化**: 按照 JuicyMixer 文档结构规则建立 Bricks 文档目录结构
2. **内容清理**: 识别过期文档并归档或删除
3. **内容更新**: 根据最新实现更新相关文档
4. **统一管理**: 将分散的文档集中到 `addons/bricks/docs/` 目录

### 1.2 整理范围

**涉及目录**:
- `addons/bricks/docs/` (20 个文件)
- `docs/bricks/` (20 个文件)
- `docs/event_on_target_signal_emit_design.md` (顶层相关文档)

### 1.3 参考标准

**JuicyMixer 文档结构** (`addons/juicy_mixer/docs/`):
```
docs/
├── user_docs/          # 用户文档（使用指南、API参考、示例）
├── system_docs/        # 系统文档（架构分析、验证报告）
├── dev_docs/           # 开发文档（技术设计、实现计划）
│   ├── archive/        # 过期开发文档
│   └── [feature]/      # 按功能分类
├── proposals/          # 设计提案
├── audio/              # 特定功能文档
├── event_handlers/     # 特定功能文档
└── timeline/           # 特定功能文档
```

---

## 2. 当前文档状态分析

### 2.1 现有文档清单

#### addons/bricks/docs/ (20 个文件)

| 文件名 | 类型 | 最后修改 | 初步评估 |
|--------|------|----------|----------|
| `CONDITIONAL_PROPERTY_DISPLAY_GUIDE.md` | 技术指南 | 较旧 | 相关 - 开发文档 |
| `CREATE_VARIABLE_INSTRUCTION_OPTIMIZATION_PLAN.md` | 优化方案 | 11月23日 | 相关 - 已完成，归档 |
| `CUSTOM_EVENT_BEST_PRACTICES.md` | 最佳实践 | 11月16日 | **高度相关** - 用户文档 |
| `CUSTOM_INSTRUCTION_BEST_PRACTICES.md` | 最佳实践 | 11月23日 | **高度相关** - 用户文档 |
| `global_variable_manager_v2_guide.md` | 使用指南 | 11月23日 | **高度相关** - 用户文档 |
| `instruction_selector_advanced_design.md` | 设计文档 | 较旧 | 部分相关 - 已采用简化方案 |
| `instruction_selector_simple_design.md` | 设计文档 | 较旧 | 部分相关 - 已实现 |
| `localization_coverage_report.md` | 覆盖率报告 | 1月24日 | **高度相关** - 系统文档 |
| `localization_implementation_plan.md` | 实施计划 | 11月16日 | 相关 - 已完成，归档 |
| `localization_implementation_plan_v2.md` | 实施计划v2 | 1月25日 | 相关 - 进行中 |
| `localization_progress_report.md` | 进度报告 | 1月24日 | **高度相关** - 系统文档 |
| `localization_task1_fix_report.md` | 修复报告 | 1月25日 | **高度相关** - 系统文档 |
| `play_juicy_effect_task_execution_chain_analysis.md` | 分析文档 | 11月15日 | 相关 - 技术分析 |
| `stage3_runtime_localization_complete.md` | 完成报告 | 1月25日 | **高度相关** - 系统文档 |
| `variable_storage_phase1-2_report.md` | 阶段报告 | 1月23日 | **高度相关** - 系统文档 |
| `variable_storage_phase3-5_report.md` | 阶段报告 | 1月23日 | **高度相关** - 系统文档 |
| `plans/2026-01-25-localization-stage4-refinement.md` | 计划文档 | 1月25日 | 相关 - 计划 |
| `temp_design/CREATE_LOCAL_VARIABLE_INSTRUCTION.md` | 临时设计 | 较旧 | **过期** - 功能已变更 |
| `temp_design/quit_instruction_implementation_plan.md` | 实施计划 | 较旧 | **过期** - 已实现 |

#### docs/bricks/ (20 个文件)

| 文件名 | 类型 | 最后修改 | 初步评估 |
|--------|------|----------|----------|
| `analysis/action_runner_analysis.md` | 分析报告 | 11月3日 | **高度相关** - 系统文档 |
| `analysis/base_condition_analysis.md` | 分析报告 | 11月3日 | **高度相关** - 系统文档 |
| `analysis/base_instruction_analysis.md` | 分析报告 | 11月3日 | **高度相关** - 系统文档 |
| `analysis/base_trigger_analysis.md` | 分析报告 | 11月3日 | **高度相关** - 系统文档 |
| `analysis/base_variable_analysis.md` | 分析报告 | 11月3日 | **高度相关** - 系统文档 |
| `analysis/execution_context_analysis.md` | 分析报告 | 11月3日 | **高度相关** - 系统文档 |
| `analysis/variable_container_analysis.md` | 分析报告 | 11月3日 | **高度相关** - 系统文档 |
| `architecture/global_variable_assistant_refactor_plan.md` | 重构计划 | 11月9日 | 相关 - 已实现，归档 |
| `bricks_architecture_analysis.md` | 架构分析 | 较旧 | **高度相关** - 系统文档 |
| `bricks_core_analysis_report.md` | 核心分析 | 较旧 | **高度相关** - 系统文档 |
| `bricks_optimization_from_flowkit_analysis.md` | 优化分析 | 较旧 | 相关 - 参考 |
| `bricks_optimization_from_gamecreator_analysis.md` | 优化分析 | 较旧 | 相关 - 参考 |
| `bricks_optimization_implementation_plan.md` | 实施计划 | 较旧 | 相关 - 归档 |
| `bricks_optimization_suggestions.md` | 优化建议 | 较旧 | 相关 - 参考 |
| `design/condition_system_design.md` | 设计文档 | 较旧 | 相关 - 已实现 |
| `design/dataflow_controlflow_design.md` | 设计文档 | 较旧 | 相关 - 系统设计 |
| `design/editor_tools_design.md` | 设计文档 | 较旧 | 相关 - 系统设计 |
| `design/event_on_input_key_design.md` | 设计文档 | 11月12日 | 相关 - 已实现 |
| `design/event_on_input_key_summary.md` | 设计摘要 | 11月12日 | 相关 - 已实现 |
| `design/shared_variable_implementation_design.md` | 设计文档 | 11月12日 | 相关 - 系统设计 |
| `design/trigger_architecture_design.md` | 设计文档 | 11月5日 | 相关 - 系统设计 |
| `design/visual_programming_complete_design_summary.md` | 设计总结 | 11月3日 | 相关 - 系统设计 |
| `migration/variable_system_v2.md` | 迁移指南 | 1月23日 | **高度相关** - 用户文档 |
| `optimization/internal_optimization_plan.md` | 优化计划 | 11月7日 | 相关 - 参考 |

#### docs/ 顶层相关文档

| 文件名 | 类型 | 最后修改 | 初步评估 |
|--------|------|----------|----------|
| `event_on_target_signal_emit_design.md` | 设计文档 | 12月2日 | 相关 - 已实现 |
| `event_on_target_signal_emit_implementation_plan.md` | 实施计划 | 12月2日 | 相关 - 已实现 |
| `run_target_node_function_design.md` | 设计文档 | 12月2日 | 相关 - 已实现 |
| `run_target_node_function_implementation_plan.md` | 实施计划 | 12月2日 | 相关 - 已实现 |
| `run_target_node_function_performance_optimization.md` | 优化文档 | 12月3日 | 相关 - 技术文档 |
| `set_property_value_instruction_design.md` | 设计文档 | 12月1日 | 相关 - 已实现 |

### 2.2 当前实现状态

**核心系统已实现**:
- ✅ BaseEvent (包括 RuntimeEventInstance 优化)
- ✅ BaseInstruction (包括 ExecutionStatus、Metadata 系统)
- ✅ BaseCondition
- ✅ BaseVariable
- ✅ ExecutionContext
- ✅ VariableContainer
- ✅ ActionRunner
- ✅ GlobalVariableManager v2
- ✅ Trigger 系统

**已实现的 Event**:
- EventOnReady
- EventOnInputKey
- EventOnInputAction
- EventOnArea2DEnter
- EventOnTargetSignalEmit

**已实现的 Instruction**:
- CreateVariable
- SetVariable (SetIntVariable)
- Print
- PrintVariableValue
- Wait
- Count
- Quit
- RunConditionCheck
- SetPropertyValue
- RunTargetNodeFunction

**已完成的系统**:
- ✅ 本地化系统 (阶段 4 完成)
- ✅ 指令选择器 (简化版已实现)
- ✅ 变量存储系统
- ✅ 调试可视化工具

---

## 3. 目标目录结构

### 3.1 新的 Bricks 文档结构

```
addons/bricks/docs/
├── README.md                           # 文档中心入口
├── user_docs/                          # 用户文档
│   ├── README.md
│   ├── quick_start.md                  # 快速开始指南
│   ├── user_guide.md                   # 用户使用指南
│   ├── api_reference.md                # API 参考手册
│   ├── best_practices/
│   │   ├── custom_event.md             # 自定义事件最佳实践
│   │   ├── custom_instruction.md       # 自定义指令最佳实践
│   │   └── conditional_property.md     # 条件化属性显示
│   └── guides/
│       ├── global_variable_manager_v2.md
│       └── variable_migration.md
│
├── system_docs/                        # 系统文档
│   ├── README.md
│   ├── architecture/
│   │   ├── core_architecture.md        # 核心架构分析
│   │   ├── trigger_architecture.md     # 触发器架构
│   │   ├── variable_system.md          # 变量系统架构
│   │   └── dataflow_controlflow.md     # 数据流和控制流
│   ├── analysis/
│   │   ├── core_classes_analysis.md    # 核心类分析
│   │   └── execution_chain_analysis.md # 执行链分析
│   └── reports/
│       ├── localization_coverage.md    # 本地化覆盖率报告
│       ├── localization_progress.md    # 本地化进度报告
│       └── variable_storage_reports.md # 变量存储报告
│
├── dev_docs/                           # 开发文档
│   ├── README.md
│   ├── archive/                        # 过期文档
│   │   ├── old_optimization_plans.md
│   │   ├── old_instruction_selector_designs.md
│   │   └── implementation_plans/
│   ├── event_system/                   # 事件系统
│   │   ├── event_on_input_key.md
│   │   ├── event_on_input_action.md
│   │   ├── event_on_area_2d_enter.md
│   │   └── event_on_target_signal_emit.md
│   ├── instruction_system/             # 指令系统
│   │   ├── create_variable.md
│   │   ├── set_variable.md
│   │   ├── run_target_node_function.md
│   │   └── set_property_value.md
│   ├── localization/                   # 本地化系统
│   │   ├── implementation_plan.md
│   │   ├── stage_reports.md
│   │   └── task_fixes.md
│   └── variable_system/                # 变量系统
│       ├── v2_migration.md
│       └── storage_phases.md
│
└── proposals/                          # 设计提案
    ├── README.md
    ├── implemented/                    # 已实现的提案
    │   └── instruction_selector_simple.md
    └── pending/                        # 待讨论的提案
```

---

## 4. 文档相关性评估标准

### 4.1 评估维度

| 维度 | 权重 | 评估标准 |
|------|------|----------|
| **实现匹配度** | 40% | 文档描述的功能与当前实现的一致性 |
| **时效性** | 25% | 文档最后修改时间与当前实现的差距 |
| **完整性** | 20% | 文档内容的完整程度 |
| **实用性** | 15% | 文档对用户的实际参考价值 |

### 4.2 相关性等级

- **🟢 高度相关** (80-100%): 与当前实现高度一致，需要保留并更新
- **🟡 部分相关** (50-79%): 部分内容仍有效，需要整理或归档
- **🔴 过期/不相关** (0-49%): 内容已过期或不再适用，归档或删除

### 4.3 具体评估规则

**高度相关标准**:
- 描述的是已实现且仍在使用的功能
- API/架构文档与代码一致
- 最佳实践指南仍然适用
- 最近修改（1个月内）且内容准确

**部分相关标准**:
- 描述的是已实现但发生重大变更的功能
- 设计/实施计划（功能已实现）
- 优化建议（可能仍有参考价值）
- 较旧但内容基本准确的文档

**过期标准**:
- 描述的功能已被移除或完全重写
- 临时的设计笔记（功能已定型）
- 被新文档替代的旧版本
- 纯粹的临时性讨论记录

---

## 5. 实施步骤

### 阶段 1: 准备和备份 (预计 30 分钟)

**任务 1.1**: 创建备份
```bash
# 创建备份目录
mkdir -p backups/docs-reorganization-$(date +%Y%m%d)

# 备份现有文档
cp -r addons/bricks/docs backups/docs-reorganization-$(date +%Y%m%d)/bricks-docs-backup
cp -r docs/bricks backups/docs-reorganization-$(date +%Y%m%d)/bricks-docs-project-backup
```

**任务 1.2**: 创建新目录结构
```bash
# 在 addons/bricks/docs/ 下创建新结构
cd addons/bricks/docs
mkdir -p user_docs/best_practices
mkdir -p user_docs/guides
mkdir -p system_docs/architecture
mkdir -p system_docs/analysis
mkdir -p system_docs/reports
mkdir -p dev_docs/archive/implementation_plans
mkdir -p dev_docs/event_system
mkdir -p dev_docs/instruction_system
mkdir -p dev_docs/localization
mkdir -p dev_docs/variable_system
mkdir -p proposals/implemented
mkdir -p proposals/pending
```

**任务 1.3**: 创建 README 模板
- 创建各子目录的 README.md 文件
- 参考 JuicyMixer 的 README 格式

---

### 阶段 2: 文档评估和分类 (预计 2-3 小时)

**任务 2.1**: 创建评估工作表

创建一个电子表格或 markdown 表格，记录每个文档的评估结果：

| 原路径 | 文档名 | 相关性 | 目标位置 | 需要更新 |
|--------|--------|--------|----------|----------|
| ... | ... | ... | ... | ... |

**任务 2.2**: 逐个评估文档

对于每个文档：
1. 阅读文档内容
2. 对照当前实现代码
3. 确定相关性等级
4. 确定目标位置
5. 标记需要更新的内容

**任务 2.3**: 生成文档迁移清单

基于评估结果生成详细的迁移清单（见第 6 节）

---

### 阶段 3: 文档迁移 (预计 2-3 小时)

**任务 3.1**: 迁移高度相关文档

优先迁移高度相关的文档：
- 保持文件名清晰
- 更新内部链接
- 更新文档元数据

**任务 3.2**: 迁移部分相关文档

- 整理和合并相似内容
- 添加过期说明（如适用）
- 归档到合适位置

**任务 3.3**: 处理过期文档

- 移动到 `dev_docs/archive/`
- 或删除（如无价值）

**任务 3.4**: 迁移 docs/bricks/ 文档

- 将所有相关文档迁移到 `addons/bricks/docs/`
- 保持项目顶层 docs/ 目录整洁

---

### 阶段 4: 文档更新 (预计 4-6 小时)

**任务 4.1**: 更新用户文档

**优先级 1 - 必须更新**:
- `CUSTOM_EVENT_BEST_PRACTICES.md`
  - 检查与 BaseEvent 实现的一致性
  - 添加 RuntimeEventInstance 相关内容
  - 更新代码示例

- `CUSTOM_INSTRUCTION_BEST_PRACTICES.md`
  - 检查与 BaseInstruction 实现的一致性
  - 更新 ExecutionStatus 相关内容
  - 更新代码示例

- `global_variable_manager_v2_guide.md`
  - 验证 v2 功能描述
  - 更新 API 使用示例
  - 添加新功能说明

**优先级 2 - 建议更新**:
- `migration/variable_system_v2.md`
  - 添加迁移注意事项
  - 更新迁移步骤

**任务 4.2**: 更新系统文档

- `system_docs/architecture/` 下的所有文档
  - 验证架构描述与实际代码一致
  - 更新类图和流程图
  - 补充新功能架构

- `system_docs/reports/` 下的报告
  - 验证报告数据准确性
  - 更新统计信息

**任务 4.3**: 更新开发文档

- `dev_docs/event_system/`
  - 标记已实现的事件
  - 添加实现总结

- `dev_docs/instruction_system/`
  - 标记已实现的指令
  - 添加实现总结

- `dev_docs/localization/`
  - 整理本地化阶段报告
  - 更新进度信息

**任务 4.4**: 创建新文档

需要创建的新文档：
- `user_docs/quick_start.md` - 快速开始指南
- `user_docs/api_reference.md` - API 参考手册
- `user_docs/user_guide.md` - 完整用户指南

---

### 阶段 5: 创建文档中心 (预计 1-2 小时)

**任务 5.1**: 创建主 README

创建 `addons/bricks/docs/README.md`：
```markdown
# Bricks 可视化编程系统 - 文档中心

欢迎来到 Bricks 系统文档！

## 📚 文档分类

### 用户文档
面向游戏设计师和开发者，提供使用指南和最佳实践

### 系统文档
面向系统架构师和核心开发者，提供架构设计和分析报告

### 开发文档
面向 Bricks 系统开发者，提供技术设计和实现细节

### 设计提案
Bricks 系统的功能设计和改进提案

---

## 🎯 快速导航

- [快速开始](user_docs/quick_start.md) - 5分钟上手 Bricks
- [用户指南](user_docs/user_guide.md) - 完整使用指南
- [API 参考](user_docs/api_reference.md) - API 查询
- [最佳实践](user_docs/best_practices/) - 创建自定义组件

---

## 📖 相关资源

- [JuicyMixer 文档](../juicy_mixer/docs/) - 特效系统文档
- [项目文档](../../../docs/) - 项目总体文档
```

**任务 5.2**: 创建子目录 README

为每个主要子目录创建 README.md：
- `user_docs/README.md`
- `system_docs/README.md`
- `dev_docs/README.md`
- `proposals/README.md`

---

### 阶段 6: 清理和验证 (预计 1-2 小时)

**任务 6.1**: 清理空目录和重复文件

```bash
# 删除空目录
find addons/bricks/docs -type d -empty -delete

# 检查重复文件（手动处理）
# 使用工具如 fdupes 或手动比对
```

**任务 6.2**: 验证文档完整性

检查清单：
- [ ] 所有文档都正确迁移
- [ ] 没有损坏的链接
- [ ] 所有 README 都已创建
- [ ] 文档命名一致
- [ ] 目录结构清晰

**任务 6.3**: 验证文档可访问性

- 从主 README 开始，检查所有链接是否可访问
- 确认文档可以通过导航清晰找到

**任务 6.4**: 清理原始目录

完成验证后：
- 删除 `docs/bricks/` 目录（内容已迁移）
- 删除 `addons/bricks/docs/` 下的旧文件
- 保留 `docs/` 下的其他非 Bricks 文档

---

### 阶段 7: 更新项目引用 (预计 1 小时)

**任务 7.1**: 更新项目文档

更新 `docs/` 目录下的相关引用：
- 更新 `CLAUDE.md` 中的文档路径
- 更新其他文档中的 Bricks 文档链接

**任务 7.2**: 更新代码注释

检查代码中是否有文档路径的注释需要更新

**任务 7.3**: 创建迁移说明

在原 `docs/bricks/` 位置创建重定向说明：
```markdown
# Bricks 文档已迁移

Bricks 系统文档已迁移至新位置：

**新位置**: `addons/bricks/docs/`

请更新您的书签和链接。

---

主要文档映射：
- 原分析文档 → `addons/bricks/docs/system_docs/analysis/`
- 原设计文档 → `addons/bricks/docs/dev_docs/` 或 `proposals/`
- 原架构文档 → `addons/bricks/docs/system_docs/architecture/`
```

---

## 6. 文档迁移清单

### 6.1 高度相关文档迁移 (🟢)

| 源路径 | 目标路径 | 更新需求 |
|--------|----------|----------|
| `addons/bricks/docs/CUSTOM_EVENT_BEST_PRACTICES.md` | `user_docs/best_practices/custom_event.md` | 需要更新 |
| `addons/bricks/docs/CUSTOM_INSTRUCTION_BEST_PRACTICES.md` | `user_docs/best_practices/custom_instruction.md` | 需要更新 |
| `addons/bricks/docs/global_variable_manager_v2_guide.md` | `user_docs/guides/global_variable_manager_v2.md` | 需要验证 |
| `addons/bricks/docs/CONDITIONAL_PROPERTY_DISPLAY_GUIDE.md` | `user_docs/best_practices/conditional_property.md` | 需要验证 |
| `addons/bricks/docs/localization_coverage_report.md` | `system_docs/reports/localization_coverage.md` | 保持最新 |
| `addons/bricks/docs/localization_progress_report.md` | `system_docs/reports/localization_progress.md` | 保持最新 |
| `addons/bricks/docs/localization_task1_fix_report.md` | `dev_docs/localization/task1_fix_report.md` | 保持最新 |
| `addons/bricks/docs/stage3_runtime_localization_complete.md` | `dev_docs/localization/stage3_completion.md` | 保持最新 |
| `addons/bricks/docs/variable_storage_phase1-2_report.md` | `dev_docs/variable_system/storage_phase1-2.md` | 保持最新 |
| `addons/bricks/docs/variable_storage_phase3-5_report.md` | `dev_docs/variable_system/storage_phase3-5.md` | 保持最新 |
| `docs/bricks/migration/variable_system_v2.md` | `user_docs/guides/variable_migration.md` | 需要更新 |
| `docs/bricks/analysis/*.md` (7个文件) | `system_docs/analysis/core_classes_analysis.md` (合并) | 需要合并更新 |
| `docs/bricks/bricks_architecture_analysis.md` | `system_docs/architecture/core_architecture.md` | 需要更新 |
| `docs/bricks/bricks_core_analysis_report.md` | `system_docs/architecture/core_system_analysis.md` | 需要更新 |

### 6.2 部分相关文档迁移 (🟡)

| 源路径 | 目标路径 | 处理方式 |
|--------|----------|----------|
| `addons/bricks/docs/instruction_selector_simple_design.md` | `proposals/implemented/instruction_selector_simple.md` | 添加实现总结 |
| `addons/bricks/docs/instruction_selector_advanced_design.md` | `dev_docs/archive/old_instruction_selector_designs.md` | 归档 |
| `addons/bricks/docs/localization_implementation_plan.md` | `dev_docs/localization/old_implementation_plan.md` | 归档 |
| `addons/bricks/docs/localization_implementation_plan_v2.md` | `dev_docs/localization/implementation_plan_v2.md` | 保留 |
| `addons/bricks/docs/CREATE_VARIABLE_INSTRUCTION_OPTIMIZATION_PLAN.md` | `dev_docs/archive/variable_optimization_plan.md` | 归档 |
| `addons/bricks/docs/play_juicy_effect_task_execution_chain_analysis.md` | `dev_docs/archive/juicy_effect_analysis.md` | 归档 |
| `docs/bricks/architecture/global_variable_assistant_refactor_plan.md` | `dev_docs/archive/global_variable_assistant_refactor.md` | 归档 |
| `docs/bricks/bricks_optimization_*.md` (4个文件) | `dev_docs/archive/optimization_references.md` (合并) | 合并归档 |
| `docs/bricks/design/*.md` (10个文件) | `dev_docs/` 各功能目录 | 分类归档 |
| `docs/bricks/optimization/internal_optimization_plan.md` | `dev_docs/archive/internal_optimization_plan.md` | 归档 |
| `docs/event_on_target_signal_emit_*.md` | `dev_docs/event_system/event_on_target_signal_emit.md` (合并) | 合并 |
| `docs/run_target_node_function_*.md` | `dev_docs/instruction_system/run_target_node_function.md` (合并) | 合并 |
| `docs/set_property_value_instruction_design.md` | `dev_docs/instruction_system/set_property_value.md` | 归档 |

### 6.3 过期文档处理 (🔴)

| 源路径 | 处理方式 |
|--------|----------|
| `addons/bricks/docs/temp_design/` | **删除** - 临时设计已过时 |
| `addons/bricks/docs/plans/2026-01-25-localization-stage4-refinement.md` | **归档到** `dev_docs/localization/` |

---

## 7. 文档更新计划

### 7.1 用户文档更新

#### CUSTOM_EVENT_BEST_PRACTICES.md

**需要更新的内容**:
1. **BaseEvent API 变更**
   - ✅ 已添加 `initialize_with_runtime_instance()` 方法
   - ✅ 已添加 `RuntimeEventInstance` 支持
   - ✅ 需要更新相关示例代码

2. **新增方法**
   - `_initialize_runtime_state()` 方法说明
   - `validate()` 方法说明

3. **性能优化**
   - 添加 `_bricks_localization_class` 缓存说明

4. **示例代码更新**
   - 更新 `initialize()` 示例
   - 添加 `initialize_with_runtime_instance()` 示例

#### CUSTOM_INSTRUCTION_BEST_PRACTICES.md

**需要更新的内容**:
1. **BaseInstruction API 变更**
   - ✅ `ExecutionStatus` 枚举
   - ✅ `CompletionSignalTiming` 枚举
   - ✅ `ExecutionMode` 枚举

2. **Metadata 系统**
   - `InstructionMetadata` 类说明
   - `_setup_metadata()` 方法说明

3. **错误处理**
   - `BricksError` 集成
   - 错误状态处理

4. **示例代码更新**
   - 更新指令创建示例
   - 添加异步执行示例

#### global_variable_manager_v2_guide.md

**需要验证的内容**:
1. v2 功能完整性
2. API 使用示例准确性
3. 新功能文档完整性

### 7.2 系统文档更新

#### 核心架构分析文档

**需要更新的内容**:
1. 新增组件：
   - `RuntimeEventInstance`
   - `InstructionMetadata`
   - `BricksError`
   - `BricksLocalization`

2. 性能优化：
   - 本地化类缓存
   - 内存优化

3. 本地化系统：
   - 完整的本地化支持
   - 运行时本地化

### 7.3 开发文档更新

#### 事件系统文档

**需要添加的内容**:
1. 已实现事件清单
2. 每个事件的实现总结
3. 使用示例

#### 指令系统文档

**需要添加的内容**:
1. 已实现指令清单
2. 每个指令的实现总结
3. 使用示例

### 7.4 需要创建的新文档

#### user_docs/quick_start.md

**内容大纲**:
```markdown
# Bricks 快速开始指南

## 5分钟上手

### 1. 创建第一个事件
### 2. 添加指令
### 3. 测试运行

## 基本概念

### 事件 (Event)
### 指令 (Instruction)
### 变量 (Variable)
### 触发器 (Trigger)

## 下一步
```

#### user_docs/api_reference.md

**内容大纲**:
```markdown
# Bricks API 参考手册

## 核心类

### BaseEvent
### BaseInstruction
### BaseCondition
### BaseVariable
### ExecutionContext
### VariableContainer
### ActionRunner
### Trigger

## 管理器类

### GlobalVariableManager
### GlobalVariableAssistant

## 工具类

### BricksLogger
### BricksError
### BricksLocalization
```

#### user_docs/user_guide.md

**内容大纲**:
```markdown
# Bricks 用户指南

## 系统概述

## 核心概念详解

## 编辑器使用

## 常见工作流

## 高级功能

## 故障排除

## 最佳实践
```

---

## 8. 验证和测试

### 8.1 验证检查清单

**结构验证**:
- [ ] 所有目录都已创建
- [ ] 所有文档都已迁移
- [ ] 没有孤立的文档
- [ ] 目录结构符合 JuicyMixer 规则

**内容验证**:
- [ ] 高度相关文档内容准确
- [ ] 代码示例可运行
- [ ] API 参考与实际一致
- [ ] 链接没有断链

**可读性验证**:
- [ ] 从主 README 可以导航到所有文档
- [ ] 文档标题清晰
- [ ] 文档有适当的目录
- [ ] 代码块语法高亮正确

**实用性验证**:
- [ ] 用户可以找到需要的信息
- [ ] 开发者可以理解架构
- [ ] 新手可以快速上手

### 8.2 测试计划

**测试 1: 新用户导航测试**

模拟一个新用户：
1. 从主 README 开始
2. 尝试找到"如何创建自定义事件"
3. 尝试找到"如何使用全局变量"
4. 尝试找到"API 参考"

**测试 2: 开发者导航测试**

模拟一个开发者：
1. 尝试找到架构文档
2. 尝试找到实现细节
3. 尝试找到分析报告

**测试 3: 链接完整性测试**

使用工具检查所有 markdown 链接：
```bash
# 使用 markdown-link-check 或类似工具
npm install -g markdown-link-check
markdown-link-check addons/bricks/docs/**/*.md
```

**测试 4: 代码示例测试**

提取所有代码示例并验证：
- 语法正确性
- API 调用准确性
- 可运行性

---

## 9. 风险和注意事项

### 9.1 风险识别

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|----------|
| 误删重要文档 | 高 | 低 | 做好备份，分步验证 |
| 破坏现有链接 | 中 | 中 | 创建重定向，保留映射 |
| 文档更新不完整 | 中 | 高 | 按优先级分批更新 |
| 估计时间不足 | 低 | 中 | 灵活调整，分阶段进行 |

### 9.2 注意事项

**1. 备份重要性**
- 在开始前必须创建完整备份
- 保留备份至少 1 个月

**2. 迁移顺序**
- 先迁移后删除
- 验证后再清理源文件

**3. 文档更新优先级**
- 优先更新高度相关的用户文档
- 系统文档可以逐步完善
- 归档文档可以简单标记

**4. 链接处理**
- 内部链接需要同步更新
- 外部引用需要创建重定向
- 在原位置保留迁移说明

**5. 协作考虑**
- 如果有其他协作者，提前沟通
- 在重大变更前征求意见
- 提供过渡期

**6. 版本控制**
- 每个阶段完成后提交一次
- 使用清晰的提交信息
- 保留迁移历史

### 9.3 回滚计划

如果出现问题，回滚步骤：

1. **停止迁移**
   - 停止所有正在进行的移动操作

2. **评估影响**
   - 确定问题范围
   - 评估恢复的难易程度

3. **执行回滚**
   ```bash
   # 从备份恢复
   rm -rf addons/bricks/docs
   cp -r backups/docs-reorganization-YYYYMMDD/bricks-docs-backup addons/bricks/docs

   rm -rf docs/bricks
   cp -r backups/docs-reorganization-YYYYMMDD/bricks-docs-project-backup docs/bricks
   ```

4. **分析和修复**
   - 分析问题原因
   - 修改计划
   - 重新执行

---

## 10. 附录

### 10.1 时间估算汇总

| 阶段 | 预计时间 | 备注 |
|------|----------|------|
| 阶段 1: 准备和备份 | 30 分钟 | |
| 阶段 2: 文档评估和分类 | 2-3 小时 | 最耗时的部分 |
| 阶段 3: 文档迁移 | 2-3 小时 | |
| 阶段 4: 文档更新 | 4-6 小时 | 可分批进行 |
| 阶段 5: 创建文档中心 | 1-2 小时 | |
| 阶段 6: 清理和验证 | 1-2 小时 | |
| 阶段 7: 更新项目引用 | 1 小时 | |
| **总计** | **11.5-17.5 小时** | 建议 2-3 个工作日 |

### 10.2 命令参考

**创建目录结构**:
```bash
cd addons/bricks/docs

# 创建所有必需的目录
mkdir -p user_docs/best_practices
mkdir -p user_docs/guides
mkdir -p system_docs/architecture
mkdir -p system_docs/analysis
mkdir -p system_docs/reports
mkdir -p dev_docs/archive/implementation_plans
mkdir -p dev_docs/event_system
mkdir -p dev_docs/instruction_system
mkdir -p dev_docs/localization
mkdir -p dev_docs/variable_system
mkdir -p proposals/implemented
mkdir -p proposals/pending
```

**批量移动文件** (示例):
```bash
# 移动最佳实践文档
mv CUSTOM_EVENT_BEST_PRACTICES.md user_docs/best_practices/custom_event.md
mv CUSTOM_INSTRUCTION_BEST_PRACTICES.md user_docs/best_practices/custom_instruction.md

# 移动系统分析文档
mv docs/bricks/analysis/*.md system_docs/analysis/
```

**查找和更新链接**:
```bash
# 在所有 markdown 文件中查找旧路径
grep -r "docs/bricks" addons/bricks/docs/**/*.md

# 使用 sed 批量替换（谨慎使用）
sed -i 's|old/path|new/path|g' addons/bricks/docs/**/*.md
```

### 10.3 参考资源

**JuicyMixer 文档示例**:
- `addons/juicy_mixer/docs/README.md`
- `addons/juicy_mixer/docs/user_docs/README.md`
- `addons/juicy_mixer/docs/system_docs/README.md`
- `addons/juicy_mixer/docs/dev_docs/README.md`

**相关工具**:
- `markdown-link-check` - 链接检查工具
- `fdupes` - 重复文件查找工具
- `tree` - 目录结构查看工具

---

## 11. 后续维护建议

### 11.1 文档维护规范

1. **新文档创建**
   - 按照新结构创建在合适位置
   - 遵循命名规范
   - 包含适当的 README

2. **文档更新**
   - 功能变更时同步更新文档
   - 定期审查文档时效性
   - 标注文档最后更新日期

3. **过期文档处理**
   - 及时归档过期文档
   - 在原位置保留指向新文档的链接
   - 定期清理归档

### 11.2 文档质量标准

1. **完整性**
   - 包含必要的示例代码
   - 有清晰的目录结构
   - 提供足够的上下文

2. **准确性**
   - 代码示例可运行
   - API 描述准确
   - 与实现一致

3. **可读性**
   - 使用清晰的语言
   - 适当的格式和排版
   - 合理的信息密度

4. **可维护性**
   - 模块化组织
   - 避免重复内容
   - 易于更新和扩展

---

**计划创建者**: Claude (AI Assistant)
**创建日期**: 2026-01-25
**预计完成日期**: 根据实际执行进度确定
**版本**: 1.0

---

## 变更历史

| 版本 | 日期 | 变更说明 |
|------|------|----------|
| 1.0 | 2026-01-25 | 初始版本创建 |
