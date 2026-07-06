# 系统文档

欢迎来到 Fuse 系统文档！这里提供了面向系统架构师和核心开发者的架构设计、分析报告和技术深入。

## 📚 文档导航

### 🏗️ 架构设计文档 (15 篇)

#### 核心架构
- [可视化编程系统架构](architecture/visual_programming_system_architecture.md)
  - 核心架构设计概述
  - 主要组件及其职责
  - 数据流和控制流设计
  - 扩展点设计
  - 与 Godot 特性的集成方案
  - 完整的代码示例和流程图

- [完整设计总结](architecture/visual_programming_complete_design_summary.md)
  - 系统设计总结
  - 核心特性概述
  - 技术亮点

#### 系统设计
- [数据流与控制流设计](architecture/dataflow_controlflow_design.md)
  - 数据流图
  - 控制流设计
  - 执行流程优化

- [变量系统设计](architecture/variable_system_design.md)
  - 变量容器设计
  - 变量管理器
  - 作用域控制
  - 持久化机制

- [指令系统设计](architecture/instruction_system_design.md)
  - 指令基类
  - 执行模式
  - 错误处理
  - 异步执行

- [条件系统设计](architecture/condition_system_design.md)
  - 条件基类
  - 复合条件
  - 条件评估

- [触发器系统设计](architecture/trigger_system_design.md)
  - 触发器基类
  - 事件监听
  - 触发机制

- [触发器架构](architecture/trigger_architecture_design.md)
  - 触发器详细架构
  - 生命周期管理
  - 条件检查流程

- [共享变量实现](architecture/shared_variable_implementation_design.md)
  - 变量共享机制
  - 全局变量访问
  - 线程安全

#### 集成与扩展
- [Godot 集成设计](architecture/godot_integration_design.md)
  - Resource 系统集成
  - Signal 系统集成
  - NodePath 系统集成
  - SceneTree 系统集成

- [可扩展性设计](architecture/extensibility_design.md)
  - 指令系统扩展点
  - 触发器系统扩展点
  - 条件系统扩展点
  - 编辑器扩展点

- [编辑器工具设计](architecture/editor_tools_design.md)
  - 自定义 Inspector 插件
  - 可视化编辑器
  - 节点工具

#### 事件设计
- [事件：按键输入](architecture/event_on_input_key_design.md)
  - 按键事件设计
  - 输入映射
  - 事件触发

- [按键输入总结](architecture/event_on_input_key_summary.md)
  - 按键事件总结
  - 使用示例

### 🔍 分析报告 (12 篇)

#### 系统分析
- [Fuse 架构分析](analysis/fuse_architecture_analysis.md)
  - 整体架构分析
  - 组件关系
  - 设计模式

- [核心系统分析](analysis/fuse_core_analysis_report.md)
  - 核心组件分析
  - 性能评估
  - 优化建议

#### 优化分析
- [优化分析：FlowKit](analysis/fuse_optimization_from_flowkit_analysis.md)
  - 从 FlowKit 学习
  - 优化机会
  - 实施建议

- [优化分析：GameCreator](analysis/fuse_optimization_from_gamecreator_analysis.md)
  - 从 GameCreator 学习
  - 最佳实践
  - 改进方向

#### 组件分析
- [ActionRunner 分析](analysis/action_runner_analysis.md)
  - 动作执行器详细分析
  - 执行流程
  - 性能特征

- [BaseInstruction 分析](analysis/base_instruction_analysis.md)
  - 指令基类分析
  - 接口设计
  - 扩展机制

- [BaseCondition 分析](analysis/base_condition_analysis.md)
  - 条件基类分析
  - 条件评估
  - 复合条件

- [BaseTrigger 分析](analysis/base_trigger_analysis.md)
  - 触发器基类分析
  - 事件处理
  - 生命周期

- [BaseVariable 分析](analysis/base_variable_analysis.md)
  - 变量基类分析
  - 类型系统
  - 存储机制

- [ExecutionContext 分析](analysis/execution_context_analysis.md)
  - 执行上下文分析
  - 变量访问
  - 状态管理

- [VariableContainer 分析](analysis/variable_container_analysis.md)
  - 变量容器分析
  - 存储优化
  - 访问性能

- [Juicy 效果执行链](analysis/play_juicy_effect_task_execution_chain_analysis.md)
  - 效果执行分析
  - 集成流程
  - 性能评估

## 🎯 按主题查找

### 我想了解...

#### 整体架构
→ 阅读 [可视化编程系统架构](architecture/visual_programming_system_architecture.md)

#### 变量系统
→ 查看 [变量系统设计](architecture/variable_system_design.md)
→ 深入 [VariableContainer 分析](analysis/variable_container_analysis.md)

#### 指令执行
→ 参考 [指令系统设计](architecture/instruction_system_design.md)
→ 学习 [ActionRunner 分析](analysis/action_runner_analysis.md)

#### 触发机制
→ 阅读 [触发器系统设计](architecture/trigger_system_design.md)
→ 深入 [BaseTrigger 分析](analysis/base_trigger_analysis.md)

#### 条件判断
→ 查看 [条件系统设计](architecture/condition_system_design.md)
→ 学习 [BaseCondition 分析](analysis/base_condition_analysis.md)

#### Godot 集成
→ 参考 [Godot 集成设计](architecture/godot_integration_design.md)

#### 扩展开发
→ 阅读 [可扩展性设计](architecture/extensibility_design.md)

#### 性能优化
→ 查看 [优化分析：FlowKit](analysis/fuse_optimization_from_flowkit_analysis.md)
→ 学习 [优化分析：GameCreator](analysis/fuse_optimization_from_gamecreator_analysis.md)

## 📊 文档统计

| 类别 | 文档数量 |
|------|----------|
| 架构设计 | 15 篇 |
| 分析报告 | 12 篇 |
| **总计** | **27 篇** |

### 架构设计分类

| 分类 | 数量 | 关键文档 |
|------|------|----------|
| 核心架构 | 2 | 系统架构、设计总结 |
| 系统设计 | 7 | 数据流、变量、指令、条件、触发器等 |
| 集成扩展 | 3 | Godot 集成、扩展性、编辑器 |
| 事件设计 | 3 | 按键输入、动画事件 |

### 分析报告分类

| 分类 | 数量 | 关键文档 |
|------|------|----------|
| 系统分析 | 2 | 架构分析、核心系统分析 |
| 优化分析 | 2 | FlowKit、GameCreator |
| 组件分析 | 8 | 各核心组件详细分析 |

## 🔗 相关资源

### 用户文档
- [全局变量管理器 V2](../user_docs/guides/global_variable_manager_v2.md) - 用户使用指南
- [创建自定义事件](../user_docs/best_practices/custom_event.md) - 扩展开发实践

### 开发文档
- [变量存储实现](../dev_docs/reports/variable_storage_phase1-2_report.md) - 实现细节
- [本地化覆盖报告](../dev_docs/reports/localization_coverage_report.md) - 本地化实现

### 设计提案
- [内部优化计划](../proposals/pending/internal_optimization_plan.md) - 优化提案
- [指令选择器设计](../proposals/pending/instruction_selector_simple_design.md) - 新功能设计

## 💡 阅读建议

### 系统架构师
推荐阅读顺序：
1. [可视化编程系统架构](architecture/visual_programming_system_architecture.md)
2. [数据流与控制流设计](architecture/dataflow_controlflow_design.md)
3. [Fuse 架构分析](analysis/fuse_architecture_analysis.md)
4. [核心系统分析](analysis/fuse_core_analysis_report.md)

### 核心开发者
推荐阅读顺序：
1. [指令系统设计](architecture/instruction_system_design.md)
2. [ActionRunner 分析](analysis/action_runner_analysis.md)
3. [触发器系统设计](architecture/trigger_system_design.md)
4. [BaseTrigger 分析](analysis/base_trigger_analysis.md)

### 性能优化人员
推荐阅读顺序：
1. [优化分析：FlowKit](analysis/fuse_optimization_from_flowkit_analysis.md)
2. [优化分析：GameCreator](analysis/fuse_optimization_from_gamecreator_analysis.md)
3. [核心系统分析](analysis/fuse_core_analysis_report.md)
4. [VariableContainer 分析](analysis/variable_container_analysis.md)

### 集成开发者
推荐阅读顺序：
1. [Godot 集成设计](architecture/godot_integration_design.md)
2. [可扩展性设计](architecture/extensibility_design.md)
3. [编辑器工具设计](architecture/editor_tools_design.md)

## 📈 技术深度

### 入门级
- [完整设计总结](architecture/visual_programming_complete_design_summary.md)
- [按键输入总结](architecture/event_on_input_key_summary.md)

### 中级
- [变量系统设计](architecture/variable_system_design.md)
- [指令系统设计](architecture/instruction_system_design.md)
- [条件系统设计](architecture/condition_system_design.md)
- [触发器系统设计](architecture/trigger_system_design.md)

### 高级
- [可视化编程系统架构](architecture/visual_programming_system_architecture.md)
- [数据流与控制流设计](architecture/dataflow_controlflow_design.md)
- [Godot 集成设计](architecture/godot_integration_design.md)
- [可扩展性设计](architecture/extensibility_design.md)

### 专家级
- 所有分析报告（12 篇）
- [优化分析：FlowKit](analysis/fuse_optimization_from_flowkit_analysis.md)
- [优化分析：GameCreator](analysis/fuse_optimization_from_gamecreator_analysis.md)

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-01-25
