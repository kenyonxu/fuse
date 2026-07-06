# Fuse 整改已知问题白名单

日期:2026-06-15
关联:评估报告 §5(8 个架构问题)

## 用途

记录整改前「已知存在、本轮暂不修」的问题。整改过程中若这些问题行为变化,必须记录;
Phase 1 不得让它们恶化,但也不负责修复(留待对应 Phase)。

## 白名单(本轮暂存)

| 评估项 | 问题 | 处理 Phase | 当前表现 |
|--------|------|-----------|----------|
| 5.3 | ComponentRegistry 重复累积 | **Phase 1 修(Task 1.2)** | get_all() 可能重复 |
| 5.5 | Inspector _can_handle 全量介入 | **Phase 1 修(Task 1.3)** | return true |
| 5.2 | 类型注册不一致 | **Phase 1 修(Task 1.1)** | BaseInstruction/BaseCondition |
| 5.1 | plugin.gd 上帝对象(606 行) | Phase 2 | 启动编排耦合 |
| ~~5.4~~ | ~~GlobalVariableAssistant 脱树兜底~~ | **Phase 3 已修复** | ~~new() 后 _ready 不执行~~ → 无场景时返回 Service 实例 |
| 5.6 | ExecutionContext 1623 行 | **Phase 4 已修复** | 拆为 EC(770) + VariableContext(463) + Diagnostics(281) |
| 5.7 | BaseInstruction 静态 metadata 边界 | 暂缓(总计划 §13) | 非 Phase 4 范围 |
| 5.8 | 静态分析文本启发式 | 暂缓(总计划 §14) | 非 AST 语义 |

## 验收对照

**Phase 1 完成日期:** 2026-06-16

| 评估项 | 状态 | 处理结果 |
|--------|:----:|------|
| 5.2 类型注册不一致 | ✅ 已修复 | Task 1.1 — BaseInstruction/BaseCondition 注册基类已修正 |
| 5.3 ComponentRegistry 重复累积 | ✅ 已修复 | Task 1.2 — upsert 去重，去重测试 3/3 通过 |
| 5.5 Inspector _can_handle 全量介入 | ✅ 已修复 | Task 1.3 — 收紧为 Fuse 类型判断 |
| 5.1 plugin.gd 上帝对象 | ⬜ Phase 2 | 未动 |
| 5.4 GlobalVariableAssistant 脱树兜底 | ⬜ Phase 3 | 未动 |
| 5.6 ExecutionContext 1623 行 | ✅ 已修复 | Phase 4 — 拆为 EC(770) + VariableContext(463) + Diagnostics(281) 三层门面 |
| 5.7 BaseInstruction 静态 metadata 边界 | ⬜ 暂缓 | 非 Phase 4 范围 |
| 5.8 静态分析文本启发式 | ⬜ 暂缓 | 未动 |

## Phase 3 完成验收

**Phase 3 完成日期:** 2026-06-16

| 评估项 | 状态 | 处理结果 |
|--------|:----:|------|
| 5.4 GlobalVariableAssistant 脱树兜底 | ✅ 已修复 | Task 3.1-3.2 — 新增 GlobalVariableService (RefCounted)，Assistant 精简为场景包装器，get_instance() 无场景时返回 Service 实例 |

## Phase 4 完成验收

**Phase 4 完成日期:** 2026-06-16

| 评估项 | 状态 | 处理结果 |
|--------|:----:|------|
| 5.6 ExecutionContext 1623 行 | ✅ 已修复 | Task 4.1-4.3 — EC 拆为三层门面: ExecutionContext(770行,核心门面) + VariableContext(463行,变量子系统) + ExecutionDiagnostics(281行,诊断子系统)。外部 API 签名完全不变，100+ 指令引用零改动 |
| 5.7 BaseInstruction 静态 metadata 边界 | ⬜ 暂缓 | 总计划 §13 标注为未覆盖项，Phase 4 不处理 |

### 整改总计划验收总结

| Phase | 评估项 | 状态 |
|-------|--------|:----:|
| Phase 1 | 5.2 类型注册, 5.3 重复累积, 5.5 Inspector | ✅✅✅ |
| Phase 2 | 5.1 plugin.gd 上帝对象 | ✅ |
| Phase 3 | 5.4 GlobalVariableAssistant 脱树兜底 | ✅ |
| Phase 4 | 5.6 ExecutionContext 膨胀 | ✅ |
| 暂缓 | 5.7 metadata, 5.8 静态分析 | ⬜ |

**整改主链闭环。** 8 个评估项中 6 个已修复，2 个暂缓（非关键路径）。
