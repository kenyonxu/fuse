# 开发文档（dev_docs）

面向 Fuse 系统开发者的技术指南：如何创建事件 / 指令 / 条件，如何使用运行时架构、编辑器集成与各类专项工具。

> 用户向使用文档见 [../user_docs/](../user_docs/)；架构与系统级设计见 [../system_docs/](../system_docs/)；历史实现计划与报告见 [../archive/](../archive/)。

---

## 📚 开发指南（按主题）

### 核心组件创建

| 指南 | 说明 |
|------|------|
| [事件创建指南](guides/event_creation_guide.md) | `BaseEvent` 子类化、`RuntimeEventInstance` 状态隔离、信号管理、完整模板与常见陷阱 |
| [指令创建指南](guides/instruction_creation_guide.md) | `BaseInstruction` 子类化、执行方法、参数与本地化 |
| [条件创建指南](guides/condition_creation_guide.md) | `BaseCondition` 子类化、复合条件、验证逻辑 |

### 运行时架构

| 指南 | 说明 |
|------|------|
| [RuntimeInstructionInstance 指南](guides/runtime_instruction_instance_guide.md) | 运行时状态隔离、超时机制、暂停 / 恢复、信号连接管理 |
| [多线程开发指南](guides/multithreading-developer-guide.md) | 多线程执行模型、线程安全约束 |

### 编辑器集成

| 指南 | 说明 |
|------|------|
| [条件属性显示](guides/conditional_property_display.md) | `_validate_property()`、Inspector 属性动态显示与条件判断 |
| [图标系统设计](guides/icon_system.md) | 图标注册、配置方式、内置图标命名参考 |

### 专项开发

| 指南 | 说明 |
|------|------|
| [数组指令开发](guides/array-instructions-development.md) | `element_value` 属性、变量变化通知、翻译键命名、调试日志 |
| [变量操作工具](guides/variable-operations-utility.md) | 变量读写工具 API 与用法 |

---

## 🎯 任务导向入口

### 我想新建一个事件 / 指令 / 条件
→ [事件创建](guides/event_creation_guide.md) · [指令创建](guides/instruction_creation_guide.md) · [条件创建](guides/condition_creation_guide.md)

### 我要让组件支持运行时状态或暂停 / 恢复
→ [RuntimeInstructionInstance 指南](guides/runtime_instruction_instance_guide.md)

### 我要并发执行或关心线程安全
→ [多线程开发指南](guides/multithreading-developer-guide.md)

### 我要让 Inspector 属性随条件动态显示
→ [条件属性显示](guides/conditional_property_display.md)

### 我要为组件配置图标
→ [图标系统设计](guides/icon_system.md)

### 我在开发数组类指令或调试变量变化通知
→ [数组指令开发](guides/array-instructions-development.md) · [变量操作工具](guides/variable-operations-utility.md)

---

## 🔗 跨目录资源

### 架构与系统设计（../system_docs/）
- 架构总览：[visual_programming_system_architecture](../system_docs/architecture/visual_programming_system_architecture.md)、[完整设计摘要](../system_docs/architecture/visual_programming_complete_design_summary.md)
- 分系统设计：[事件](../system_docs/architecture/event_on_input_key_design.md) · [指令](../system_docs/architecture/instruction_system_design.md) · [条件](../system_docs/architecture/condition_system_design.md) · [变量](../system_docs/architecture/variable_system_design.md)
- 编辑器：[编辑器工具设计](../system_docs/architecture/editor_tools_design.md) · [Godot 集成设计](../system_docs/architecture/godot_integration_design.md)
- 数据流 / 控制流：[dataflow_controlflow_design](../system_docs/architecture/dataflow_controlflow_design.md)
- 组件分析：[BaseEvent](../system_docs/analysis/base_event_analysis.md) · [BaseInstruction](../system_docs/analysis/base_instruction_analysis.md) · [BaseCondition](../system_docs/analysis/base_condition_analysis.md) · [BaseVariable](../system_docs/analysis/base_variable_analysis.md) · [ExecutionContext](../system_docs/analysis/execution_context_analysis.md) · [ActionRunner](../system_docs/analysis/action_runner_analysis.md)

### 用户向使用指南（../user_docs/guides/）
- [变量系统指南](../user_docs/guides/variable_system_guide.md) · [全局变量管理器 V2](../user_docs/guides/global_variable_manager_v2.md) · [全局变量持久化](../user_docs/guides/global-variable-persistence-guide.md)
- [指令生成器](../user_docs/guides/instruction-generator-guide.md) · [Runner](../user_docs/guides/runner-guide.md) · [多事件触发器](../user_docs/guides/multi-event-trigger-guide.md) · [事件总线](../user_docs/guides/event_bus_guide.md)
- [多线程优化](../user_docs/guides/multithreading-optimization.md) · [表达式](../user_docs/guides/expression-guide.md) · [调试](../user_docs/guides/debugging-guide.md) · [图标管理器](../user_docs/guides/icon_manager_guide.md)

### 历史归档（../archive/）
历史实现计划、阶段性报告、设计提案与迁移文档。仅供参考，**非当前实现的权威来源**——以本目录指南和 `system_docs/` 为准。

---

## 📊 文档统计

| 类别 | 数量 |
|------|------|
| 开发指南 | 9 篇（`guides/`） |
| 更新规格 | 1 篇（[UPDATE_SPEC.md](UPDATE_SPEC.md)） |

---

## 📝 维护

- **代码规范**：GDScript 2.0、TAB 缩进、类型注解、`##` 文档注释（详见项目根 `CLAUDE.md`）
- **新增指南**：放入 `guides/`，并在本 README 对应主题分组中登记
- **链接健康**：新增 / 修改文档时，确保所有相对链接指向真实存在的文件

---

**最后更新**：2026-07-07
**维护者**：Fuse 开发团队
