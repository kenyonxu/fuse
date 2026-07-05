# Fuse 可视化编程系统 - 文档中心

欢迎来到 Fuse 系统文档中心！Fuse 是一个功能强大的可视化编程系统，让游戏开发变得更简单、更直观。

## 📚 文档分类

### 📖 [用户文档](user_docs/)
面向游戏设计师和开发者，提供使用指南和最佳实践。

**快速开始**：
- [快速开始指南](user_docs/quick_start.md) - 5分钟上手 Fuse 系统

**核心指南**：
- [全局变量管理器 V2](user_docs/guides/global_variable_manager_v2.md) - 全局变量系统使用指南
- [全局变量持久化](user_docs/guides/global-variable-persistence-guide.md) - 存档/读档功能
- [播放 Juicy 效果示例](user_docs/guides/play_juicy_effect_examples.md) - 与 JuicyMixer 集成示例
- [表达式系统指南](user_docs/guides/expression-guide.md) - MathExpression、StringExpression、ExpressionCondition
- [断点指令指南](user_docs/guides/breakpoint-guide.md) - BreakpointInstruction 调试工具
- [场景预加载指南](user_docs/guides/scene-preloading-guide.md) - 异步场景预加载
- [指令生成器](user_docs/guides/instruction-generator-guide.md) - 自动生成节点指令

**操作指南**：
- [Array 操作](user_docs/guides/array-operations-guide.md) - 18 个数组操作指令
- [Dictionary 操作](user_docs/guides/dictionary-operations-guide.md) - 16 个字典操作指令
- [流程控制](user_docs/guides/flow-control-guide.md) - 条件分支、循环、等待、游戏暂停
- [复合条件](user_docs/guides/composite-conditions-guide.md) - AND/OR/NOT 逻辑组合
- [输入事件](user_docs/guides/input-events-guide.md) - 键盘、鼠标、触摸、手柄事件

**系统指南**：
- [物理系统](user_docs/guides/physics-guide.md) - 物理指令与碰撞事件
- [音频系统](user_docs/guides/audio-guide.md) - 音效、音乐与音频事件
- [相机系统](user_docs/guides/camera-guide.md) - 跟随、缩放、震动、限制
- [变换操作](user_docs/guides/transform-guide.md) - 位置、旋转、缩放、朝向
- [UI 操作](user_docs/guides/ui-guide.md) - 文本、纹理、进度条、显示/隐藏
- [动画系统](user_docs/guides/animation-guide.md) - 播放、停止、混合、动画事件
- [调试系统](user_docs/guides/debugging-guide.md) - Print、断点、执行追踪、调试可视化
- [MultiEventTrigger](user_docs/guides/multi-event-trigger-guide.md) - 多事件合并触发器、上下文菜单合并/拆分
- [Runner](user_docs/guides/runner-guide.md) - 信号绑定执行器、awaitable 执行、程序化调用

**最新功能 (Phase 2)**：
- ✅ 14 个新条件（动画、时间、节点、物理、变量）
- ✅ Expression System（表达式系统）

**最佳实践**：
- [创建自定义事件](user_docs/best_practices/custom_event.md) - 扩展事件系统
- [创建自定义指令](user_docs/best_practices/custom_instruction.md) - 创建自定义指令

---

### 🏗️ [系统文档](system_docs/)
面向系统架构师和核心开发者，提供架构设计和分析报告。

**架构设计** (9 篇文档)：
- [可视化编程系统架构](system_docs/architecture/visual_programming_system_architecture.md) - 完整架构设计
- [完整设计总结](system_docs/architecture/visual_programming_complete_design_summary.md) - 系统设计总结
- [数据流与控制流](system_docs/architecture/dataflow_controlflow_design.md) - 执行流程设计
- [变量系统设计](system_docs/architecture/variable_system_design.md) - 变量系统架构
- [指令系统设计](system_docs/architecture/instruction_system_design.md) - 指令执行机制
- [条件系统设计](system_docs/architecture/condition_system_design.md) - 条件判断系统
- [共享变量实现](system_docs/architecture/shared_variable_implementation_design.md) - 变量共享机制
- [Godot 集成设计](system_docs/architecture/godot_integration_design.md) - 与 Godot 深度集成
- [编辑器工具设计](system_docs/architecture/editor_tools_design.md) - 编辑器工具
- [事件：按键输入](system_docs/architecture/event_on_input_key_design.md) - 按键事件设计

**分析报告** (13 篇文档)：
- [Fuse 架构优势分析](system_docs/analysis/fuse_architecture_advantages_analysis.md) - **核心优势与设计权衡**
- [Fuse 架构分析](system_docs/analysis/fuse_architecture_analysis.md) - 系统架构分析
- [核心系统分析](system_docs/analysis/fuse_core_analysis_report.md) - 核心组件分析
- [优化分析：FlowKit](system_docs/analysis/fuse_optimization_from_flowkit_analysis.md) - 从 FlowKit 学习
- [优化分析：GameCreator](system_docs/analysis/fuse_optimization_from_gamecreator_analysis.md) - 从 GameCreator 学习
- [ActionRunner 分析](system_docs/analysis/action_runner_analysis.md) - 动作执行器分析
- [BaseInstruction 分析](system_docs/analysis/base_instruction_analysis.md) - 指令基类分析
- [BaseCondition 分析](system_docs/analysis/base_condition_analysis.md) - 条件基类分析
- [BaseTrigger 分析](system_docs/analysis/base_trigger_analysis.md) - 触发器基类分析
- [BaseVariable 分析](system_docs/analysis/base_variable_analysis.md) - 变量基类分析
- [ExecutionContext 分析](system_docs/analysis/execution_context_analysis.md) - 执行上下文分析
- [BaseEvent 分析](system_docs/analysis/base_event_analysis.md) - 事件基类分析
- [MultiEventTrigger 分析](system_docs/analysis/multi_event_trigger_analysis.md) - 多事件触发器分析
- [Runner 分析](system_docs/analysis/runner_analysis.md) - Runner 节点分析
- [Juicy 效果执行链](system_docs/analysis/play_juicy_effect_task_execution_chain_analysis.md) - 效果执行分析

---

### 👨‍💻 [开发文档](dev_docs/)
面向 Fuse 系统开发者，提供技术设计和实现细节。

**开发指南**：
- [条件属性显示](dev_docs/guides/conditional_property_display.md) - 属性显示控制

**开发报告**：
- [变量存储阶段 1-2](dev_docs/reports/variable_storage_phase1-2_report.md) - 变量存储实现报告
- [变量存储阶段 3-5](dev_docs/reports/variable_storage_phase3-5_report.md) - 变量存储完成报告
- [运行时本地化完成](dev_docs/reports/stage3_runtime_localization_complete.md) - 本地化实现报告
- [本地化覆盖报告](dev_docs/reports/localization_coverage_report.md) - 本地化覆盖分析

**归档文档**：
- 开发历程文档已归档到 [dev_docs/archive/](dev_docs/archive/) 目录

---

### 💡 [设计提案](proposals/)
Fuse 系统的功能设计和改进提案。

**待实现提案** (5 篇)：
- [指令选择器：简单设计](proposals/pending/instruction_selector_simple_design.md) - 指令选择简单方案
- [指令选择器：高级设计](proposals/pending/instruction_selector_advanced_design.md) - 指令选择高级方案
- [内部优化计划](proposals/pending/internal_optimization_plan.md) - 内部优化方案
- [Fuse 优化建议](proposals/pending/fuse_optimization_suggestions.md) - 系统优化建议
- [Fuse 优化实现计划](proposals/pending/fuse_optimization_implementation_plan.md) - 优化实施计划
- [本地化阶段 4 改进](proposals/pending/2026-01-25-localization-stage4-refinement.md) - 本地化改进

**已实现提案** (1 篇)：
- [全局变量助手重构](proposals/implemented/global_variable_assistant_refactor_plan.md) - 全局变量系统重构

---

## 🚀 快速开始

### 5 分钟上手 Fuse

1. **创建触发器节点**
   ```
   在场景中添加 "BaseTrigger" 节点
   ```

2. **配置动作序列**
   ```
   在 Trigger 的 Inspector 中创建 ActionRunner 资源
   ```

3. **添加指令**
   ```
   向 ActionRunner 的 instructions 数组添加指令
   ```

4. **测试运行**
   ```
   运行场景，触发事件执行指令
   ```

### 基本概念

- **事件 (Event)**：触发动作的条件，如按键、碰撞、信号等
- **指令 (Instruction)**：要执行的操作，如移动节点、播放音效等
- **变量 (Variable)**：存储数据，支持全局和局部作用域
- **触发器 (Trigger)**：事件的入口点，管理指令执行

### 下一步

- 阅读 [快速开始指南](user_docs/quick_start.md) 了解详细步骤
- 查看 [全局变量管理器指南](user_docs/guides/global_variable_manager_v2.md) 学习变量管理
- 参考 [最佳实践](user_docs/best_practices/) 创建自定义组件

---

## 📊 系统状态

### 版本信息
- **当前版本**: Fuse 0.6.0
- **Godot 兼容**: 4.6+
- **最后更新**: 2026-03-19
- **文档版本**: 1.3.0

### 文档统计
- **用户文档**: 26 篇（含快速开始、最佳实践、指南）
- **系统文档**: 24 篇（架构 + 分析） 2 个新增：MultiEventTrigger 分析、Runner 分析
- **开发文档**: 11 篇（含归档）
- **设计提案**: 6 篇
- **路线图**: 1 篇（待实现计划）

---

## 🎯 按角色查找文档

### 游戏设计师
从这里开始：
- [快速开始指南](user_docs/quick_start.md)
- [全局变量管理器 V2](user_docs/guides/global_variable_manager_v2.md)
- [播放 Juicy 效果示例](user_docs/guides/play_juicy_effect_examples.md)

### 游戏开发者
推荐阅读：
- [创建自定义事件](user_docs/best_practices/custom_event.md)
- [创建自定义指令](user_docs/best_practices/custom_instruction.md)

### 系统架构师
深入理解：
- [可视化编程系统架构](system_docs/architecture/visual_programming_system_architecture.md)
- [数据流与控制流](system_docs/architecture/dataflow_controlflow_design.md)
- [Fuse 架构分析](system_docs/analysis/fuse_architecture_analysis.md)

### 核心开发者
实现参考：
- [指令系统设计](system_docs/architecture/instruction_system_design.md)
- [指令系统设计](system_docs/architecture/instruction_system_design.md)
- [变量存储实现报告](dev_docs/reports/variable_storage_phase1-2_report.md)

---

## 📖 相关资源

### 项目文档
- [JuicyMixer 文档](../juicy_mixer/docs/README.md) - 特效系统文档
- [项目根文档](../../../docs/) - 项目总体文档
- [Godot 插件本地化最佳实践](../../../docs/godot/plugin_localization_best_practices.md)

### 外部参考
- [Game Creator 文档](https://gamecreator.io/) - 可视化编程参考
- [Godot 官方文档](https://docs.godotengine.org/) - Godot API 参考
- [Feel 插件文档](https://feel-docs.mopipi.com/) - Unity 特效插件参考

### 开发资源
- [项目开发规范](../../../CLAUDE.md) - 代码规范和开发指南
- [测试场景](../../tests/) - 系统测试场景
- [演示场景](../../../demos/) - 功能演示

---

## 📝 文档更新日志

### v1.3.0 (2026-03-19)
- ✅ 文档审计与清理：删除 7 个临时文件，归档 19 个过时文档
- ✅ 归档过时的 Trigger 系统设计文档（已迁移到 Event 模式）
- ✅ 归档未实现的扩展性设计文档
- ✅ 归档已完成的迁移指南和变量容器分析
- ✅ 更新 README 文档索引和统计
- ✅ 新增 12 个用户指南（Array/Dict/Physics/Audio/Camera/Transform/UI/FlowControl/CompositeConditions/InputEvents/Animation/Debugging）
- ✅ 新增 BaseEvent / MultiEventTrigger / Runner 技术分析文档

### v1.2.0 (2026-03-19)
- ✅ 添加断点指令使用指南（BreakpointInstruction）

### v1.1.0 (2026-03-18)
- ✅ 更新版本信息至 Fuse 0.6.0
- ✅ 添加 Expression System 用户指南
- ✅ 添加场景预加载指南（PreloadSceneInstruction + CheckPreloadStatus）
- ✅ 添加全局变量持久化指南（LoadGlobalVariables + SaveGlobalVariables）
- ✅ 添加指令生成器指南
- ✅ 更新 Phase 2 条件实现状态
- ✅ 归档旧路线图文档（2026-01-24 ~ 2026-01-29）
- ✅ 归档已完成的任务报告（Task-6, Task-9, Scope Source）
- ✅ 删除过时的 multithreading.md（已由 dev/multithreading-developer-guide.md 取代）

### v1.0.0 (2026-01-25)
- ✅ 创建主文档中心和导航系统
- ✅ 添加用户文档、系统文档、开发文档分类
- ✅ 创建设计提案目录导航
- ✅ 添加按角色查找文档功能
- ✅ 整合所有现有文档索引
- ✅ 添加快速开始指南
- ✅ 建立相关资源链接

---

## 🤝 贡献指南

### 文档贡献
欢迎改进文档！请参考：
- 使用清晰的中文表达
- 提供代码示例和使用场景
- 包含图表和流程图（如适用）
- 保持文档与代码同步

### 报告问题
如果发现文档错误或需要补充：
- 在项目中创建 Issue
- 说明文档路径和问题描述
- 提供改进建议

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-03-19
**文档版本**: 1.2.0

如有任何问题或建议，请通过项目 Issue 联系我们。
