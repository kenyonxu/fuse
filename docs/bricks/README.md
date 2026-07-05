# Bricks 文档已迁移

Bricks 系统文档已迁移至新位置。

**新位置**: `addons/bricks/docs/`

请更新您的书签和链接。

---

## 主要文档映射

### 用户文档
- **快速开始**: `addons/bricks/docs/user_docs/quick_start.md`
- **最佳实践**: `addons/bricks/docs/user_docs/best_practices/`
- **用户指南**: `addons/bricks/docs/user_docs/guides/`
  - 变量迁移指南: `addons/bricks/docs/user_docs/guides/variable_migration.md`
  - PlayJuicyEffect 示例: `addons/bricks/docs/user_docs/guides/play_juicy_effect_task_examples.md`

### 系统文档
- **架构设计**: `addons/bricks/docs/system_docs/architecture/`
  - 条件系统设计: `condition_system_design.md`
  - 数据流和控制流设计: `dataflow_controlflow_design.md`
  - 指令系统设计: `instruction_system_design.md`
  - 变量系统设计: `variable_system_design.md`
  - 可视化编程系统架构: `visual_programming_system_architecture.md`

- **技术分析**: `addons/bricks/docs/system_docs/analysis/`
  - ActionRunner 分析: `action_runner_analysis.md`
  - BaseInstruction 分析: `base_instruction_analysis.md`
  - BaseVariable 分析: `base_variable_analysis.md`
  - ExecutionContext 分析: `execution_context_analysis.md`
  - 核心类分析: `core_classes_analysis.md` (合并文档)

### 开发文档
- **开发指南**: `addons/bricks/docs/dev_docs/guides/`
- **开发报告**: `addons/bricks/docs/dev_docs/reports/`
  - 本地化覆盖率报告: `localization_coverage_report.md`
  - 阶段3运行时本地化完成报告: `stage3_runtime_localization_complete.md`

- **归档文档**: `addons/bricks/docs/dev_docs/archive/`
  - 本地化实施计划: `localization_implementation_plan.md`
  - 优化参考文档: `optimization_references.md`
  - 内部优化计划: `internal_optimization_plan.md`

### 设计提案
- **待实现提案**: `addons/bricks/docs/proposals/pending/`
  - 内部优化计划: `internal_optimization_plan.md`
  - 优化实施计划: `bricks_optimization_implementation_plan.md`
  - 优化建议: `bricks_optimization_suggestions.md`
  - 本地化阶段4改进: `2026-01-25-localization-stage4-refinement.md`

- **已实现提案**: `addons/bricks/docs/proposals/implemented/`
  - GlobalVariableAssistant 重构计划: `global_variable_assistant_refactor_plan.md`

---

## 迁移说明

### 为什么迁移？

1. **模块化组织**: 文档现在按照功能分类（用户文档、系统文档、开发文档）
2. **更好的可发现性**: 清晰的目录结构使文档更容易找到
3. **插件独立性**: Bricks 文档与插件代码放在一起，便于分发
4. **统一管理**: 所有 Bricks 相关文档集中在一个位置

### 如何找到文档？

1. **浏览文档中心**: 查看 `addons/bricks/docs/README.md`
2. **使用搜索**: 在编辑器或文件管理器中搜索关键词
3. **查看文档映射**: 上面列出了主要文档的新位置

### 更新您的引用

如果您有代码或文档引用了旧的 `docs/bricks/` 路径，请更新为新路径：

```markdown
# 旧引用
[文档名称](../../docs/bricks/design/document.md)

# 新引用
[文档名称](../../addons/bricks/docs/system_docs/architecture/document.md)
```

---

**迁移日期**: 2026-01-25

**备份位置**: `backups/docs-reorganization-20260125/`

**文档中心**: [Bricks 文档中心](../../addons/bricks/docs/README.md)

**相关链接**:
- [文档重组完成报告](../../addons/bricks/docs/docs-reorganization-project-complete.md)
- [文档评估报告](../../addons/bricks/docs/document_assessment_report.md)
- [验证清单](../../addons/bricks/docs/verification-checklist.md)
