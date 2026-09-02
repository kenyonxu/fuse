# 系统文档（system_docs）

面向系统架构师与核心开发者的权威文档：架构设计、数据流 / 控制流、各核心组件的深入分析。

> 开发向指南见 [../dev_docs/](../dev_docs/)；用户向使用文档见 [../user_docs/](../user_docs/)；历史设计 / 分析文档见 `archive/`。

---

## 🏗️ 架构设计文档（9 篇）

### 核心架构
| 文档 | 说明 |
|------|------|
| [可视化编程系统架构](architecture/visual_programming_system_architecture.md) | 系统总体架构、主要组件职责、扩展点、与 Godot 集成方案 |
| [完整设计总结](architecture/visual_programming_complete_design_summary.md) | 系统设计总结、核心特性、技术亮点 |

### 系统设计
| 文档 | 说明 |
|------|------|
| [数据流与控制流设计](architecture/dataflow_controlflow_design.md) | 数据流图、控制流设计、执行流程优化 |
| [变量系统设计](architecture/variable_system_design.md) | 变量容器、管理器、作用域控制、持久化 |
| [指令系统设计](architecture/instruction_system_design.md) | 指令基类、执行模式、错误处理、异步执行 |
| [条件系统设计](architecture/condition_system_design.md) | 条件基类、复合条件、条件评估 |

### 集成与扩展
| 文档 | 说明 |
|------|------|
| [Godot 集成设计](architecture/godot_integration_design.md) | Resource / Signal / NodePath / SceneTree 集成 |
| [编辑器工具设计](architecture/editor_tools_design.md) | 自定义 Inspector、可视化编辑器、节点工具 |

### 事件设计
| 文档 | 说明 |
|------|------|
| [事件：按键输入](architecture/event_on_input_key_design.md) | 按键事件设计、输入映射、事件触发 |

---

## 🔍 分析报告（20 余篇）

### 系统分析
| 文档 | 说明 |
|------|------|
| [Fuse 架构分析](analysis/fuse_architecture_analysis.md) | 整体架构、组件关系、设计模式、运行时实例体系 |
| [Fuse 架构优势分析](analysis/fuse_architecture_advantages_analysis.md) | 架构优势剖析、设计权衡 |
| [核心系统分析](analysis/fuse_core_analysis_report.md) | 核心组件分析、性能评估、优化建议 |

### 组件分析
| 文档 | 说明 |
|------|------|
| [BaseInstruction 分析](analysis/base_instruction_analysis.md) | 指令基类接口设计、扩展机制 |
| [BaseCondition 分析](analysis/base_condition_analysis.md) | 条件基类、条件评估、复合条件 |
| [BaseEvent 分析](analysis/base_event_analysis.md) | 事件基类、事件生命周期 |
| [BaseTrigger 分析](analysis/base_trigger_analysis.md) | 触发器基类、事件处理、生命周期 |
| [BaseVariable 分析](analysis/base_variable_analysis.md) | 变量基类、类型系统、存储机制 |
| [ExecutionContext 分析](analysis/execution_context_analysis.md) | 执行上下文、变量访问、状态管理 |
| [ActionRunner 分析](analysis/action_runner_analysis.md) | 动作执行器、执行流程、性能特征 |
| [MultiEventTrigger 分析](analysis/multi_event_trigger_analysis.md) | 多事件触发器机制 |
| [Runner 分析](analysis/runner_analysis.md) | Runner 执行模型 |

### 专题分析
| 文档 | 说明 |
|------|------|
| [对象池分析](analysis/pooling_analysis.md) | `core/pooling/` 5 类：FuseObjectPool / PoolManager / InstructionInstancePool 等 |
| [线程系统分析](analysis/threading_analysis.md) | `core/threading/` 4 类：FuseTaskManager / ParallelConditionEvaluator 等 |
| [变量系统分析](analysis/variable_system_analysis.md) | 变量 7 类全链：BaseVariable / VariableContext / 三层作用域 / GlobalVariable* |
| [Runtime 实例分析](analysis/runtime_instance_analysis.md) | 三件套：RuntimeEvent/Instruction/ActionRunnerInstance，状态隔离 + 池化集成 |
| [全局基础设施分析](analysis/global_infrastructure_analysis.md) | FuseEventBus（事件总线）+ FuseRuntimeBridge（变量监视 TCP 桥） |
| [序列化分析](analysis/serialization_analysis.md) | InstructionSerializer（反射式序列化）+ CompiledInstructionSequence（编译缓存） |

---

## 🎯 任务导向入口

### 我想理解整体架构
→ [可视化编程系统架构](architecture/visual_programming_system_architecture.md) · [Fuse 架构分析](analysis/fuse_architecture_analysis.md) · [完整设计总结](architecture/visual_programming_complete_design_summary.md)

### 我想深入某个子系统
→ 变量：[设计](architecture/variable_system_design.md) · [BaseVariable 分析](analysis/base_variable_analysis.md)
→ 指令：[设计](architecture/instruction_system_design.md) · [BaseInstruction 分析](analysis/base_instruction_analysis.md) · [ActionRunner 分析](analysis/action_runner_analysis.md)
→ 条件：[设计](architecture/condition_system_design.md) · [BaseCondition 分析](analysis/base_condition_analysis.md)
→ 事件 / 触发：[按键事件设计](architecture/event_on_input_key_design.md) · [BaseEvent 分析](analysis/base_event_analysis.md) · [BaseTrigger 分析](analysis/base_trigger_analysis.md) · [MultiEventTrigger](analysis/multi_event_trigger_analysis.md)

### 我想理解执行流与上下文
→ [数据流与控制流](architecture/dataflow_controlflow_design.md) · [ExecutionContext 分析](analysis/execution_context_analysis.md) · [Runner 分析](analysis/runner_analysis.md)

### 我想做 Godot 集成或编辑器扩展
→ [Godot 集成设计](architecture/godot_integration_design.md) · [编辑器工具设计](architecture/editor_tools_design.md)

---

## 🔗 跨目录资源

### 开发文档（../dev_docs/）
- [开发文档总览](../dev_docs/README.md) · [开发指南目录](../dev_docs/guides/)
- [多线程开发指南](../dev_docs/guides/multithreading-developer-guide.md) · [变量操作工具](../dev_docs/guides/variable-operations-guide.md)

### 用户文档（../user_docs/）
- [全局变量管理器 V2](../user_docs/guides/54-global-variables-guide.md) · [变量系统指南](../user_docs/guides/01-variable-system-guide.md)
- [创建自定义事件](../user_docs/best_practices/custom_event.md)（扩展实践）

### 历史归档（../archive/）
早期设计文档（如 `trigger_system_design`、`extensibility_design`、`runtime-instance-pattern`）与优化分析（FlowKit / GameCreator）均已归档。仅供参考，**非当前实现的权威来源**——以本目录架构文档为准。

---

## 📊 文档统计

| 类别 | 数量 |
|------|------|
| 架构设计 | 9 篇（`architecture/`） |
| 分析报告 | 18 篇（`analysis/`） |
| 更新规格 | 1 篇（[UPDATE_SPEC.md](UPDATE_SPEC.md)） |
| **合计** | **27 篇** + spec |

---

## 📝 维护

- **新增文档**：架构设计入 `architecture/`，分析报告入 `analysis/`，并在本 README 对应分组登记
- **代码引用**：分析文档引用源码时使用行内代码（如 `` `addons/fuse/core/base/base_event.gd` ``），避免相对链接基准错误
- **链接健康**：新增 / 修改文档时，确保所有相对链接指向真实存在的文件

---

**最后更新**：2026-09-02
**维护者**：Fuse 开发团队
