# 用户文档（user_docs）

面向游戏设计师与开发者的使用指南、教程与最佳实践。

> 架构与系统设计见 [../system_docs/](../system_docs/)；开发向指南见 [../dev_docs/](../dev_docs/)；历史文档见 [../archive/](../archive/)。

---

## 🚀 入口

| 文档 | 说明 |
|------|------|
| [快速开始](quick_start.md) | 5 分钟上手 Fuse 系统 |
| [功能特性](FEATURES.md) | Fuse 功能总览 |

---

## 📖 使用指南（31 篇）

### 变量系统
| 文档 | 说明 |
|------|------|
| [变量系统指南](guides/variable_system_guide.md) | 变量系统整体使用 |
| [全局变量管理器 V2](guides/global_variable_manager_v2.md) | 单例管理、API、持久化、信号、调试 |
| [全局变量持久化](guides/global-variable-persistence-guide.md) | 变量保存 / 加载机制 |

### 事件与触发
| 文档 | 说明 |
|------|------|
| [Event Bus 用户指南](guides/event_bus_guide.md) | 全局事件通信、SendEvent / OnReceiveEvent、跨 Trigger 通信 |
| [多事件触发器](guides/multi-event-trigger-guide.md) | MultiEventTrigger 配置 |
| [触发器选择](guides/trigger-selection-guide.md) | 触发器选型与配置 |
| [输入事件](guides/input-events-guide.md) | 输入事件处理 |

### 指令与执行
| 文档 | 说明 |
|------|------|
| [指令生成器](guides/instruction-generator-guide.md) | 自动生成指令 |
| [Runner 指南](guides/runner-guide.md) | Runner 执行模型 |
| [流程控制](guides/flow-control-guide.md) | 分支、循环、等待 |
| [断点调试](guides/breakpoint-guide.md) | 断点使用 |
| [调试指南](guides/debugging-guide.md) | 调试工具与技巧 |

### 场景与节点
| 文档 | 说明 |
|------|------|
| [场景管理](guides/scene-management-guide.md) | 场景加载 / 切换 |
| [场景预加载](guides/scene-preloading-guide.md) | 预加载优化 |
| [移动系统](guides/movement-system-guide.md) | 节点移动 |
| [对象池系统](guides/object_pool_system_guide.md) | 对象池使用 |

### 变换与坐标
| 文档 | 说明 |
|------|------|
| [坐标系统指南](guides/coordinate_systems_guide.md) | Global / Local 坐标 |
| [变换指南](guides/transform-guide.md) | Transform 操作 |
| [数学与向量](guides/math-vector-guide.md) | 向量运算 |

### 动画 / 音频 / UI
| 文档 | 说明 |
|------|------|
| [动画指南](guides/animation-guide.md) | AnimationPlayer 使用 |
| [Tween 补间动画](guides/tween-animation-guide.md) | Tween 震动 / 补间效果 |
| [音频指南](guides/audio-guide.md) | 音频播放 |
| [UI 指南](guides/ui-guide.md) | UI 操作 |

### 物理 / 相机
| 文档 | 说明 |
|------|------|
| [物理指南](guides/physics-guide.md) | 物理操作 |
| [相机指南](guides/camera-guide.md) | 相机控制 |

### 表达式与数据
| 文档 | 说明 |
|------|------|
| [表达式指南](guides/expression-guide.md) | 表达式求值 |
| [复合条件](guides/composite-conditions-guide.md) | 复合条件配置 |
| [数组操作](guides/array-operations-guide.md) | 数组指令 |
| [字典操作](guides/dictionary-operations-guide.md) | 字典指令 |

### 性能与工具
| 文档 | 说明 |
|------|------|
| [多线程优化](guides/multithreading-optimization.md) | 多线程执行 |
| [图标管理器](guides/icon_manager_guide.md) | 图标配置与管理 |

---

## 🎯 最佳实践（2 篇）

| 文档 | 说明 |
|------|------|
| [创建自定义事件](best_practices/custom_event.md) | 事件基类、自定义步骤、参数、测试 |
| [创建自定义指令](best_practices/custom_instruction.md) | 指令基类、自定义步骤、异步、错误处理 |

---

## 🎯 任务导向入口

### 我想…
- **上手 Fuse** → [快速开始](quick_start.md)
- **管理变量** → [全局变量管理器 V2](guides/global_variable_manager_v2.md) · [持久化](guides/global-variable-persistence-guide.md)
- **做动画 / 特效** → [Tween 补间动画](guides/tween-animation-guide.md) · [动画指南](guides/animation-guide.md)
- **理解坐标** → [坐标系统指南](guides/coordinate_systems_guide.md)
- **Trigger 间通信** → [Event Bus](guides/event_bus_guide.md)
- **创建自定义组件** → [自定义事件](best_practices/custom_event.md) · [自定义指令](best_practices/custom_instruction.md)
- **调试** → [调试指南](guides/debugging-guide.md) · [断点](guides/breakpoint-guide.md)

> 开发者创建组件的完整流程另见 [../dev_docs/guides/](../dev_docs/guides/)（事件 / 指令 / 条件创建指南）。

---

## 🔗 跨目录资源

### 系统文档（../system_docs/）
- [可视化编程系统架构](../system_docs/architecture/visual_programming_system_architecture.md) · [变量系统设计](../system_docs/architecture/variable_system_design.md)
- [组件分析](../system_docs/analysis/)（BaseEvent / BaseInstruction / BaseCondition / BaseVariable 等）

### 开发文档（../dev_docs/）
- [开发指南目录](../dev_docs/guides/)（事件 / 指令 / 条件 / 多线程 / 图标系统等创建指南）

### 历史归档（../archive/）
早期使用指南（如变量系统 V2 迁移）、路线图、阶段计划均已归档。仅供参考，**以本目录指南为准**。

---

## 📊 文档统计

| 类别 | 数量 |
|------|------|
| 入口文档 | 2 篇（quick_start、FEATURES） |
| 使用指南 | 31 篇（`guides/`） |
| 最佳实践 | 2 篇（`best_practices/`） |
| 更新规格 | 1 篇（[UPDATE_SPEC.md](UPDATE_SPEC.md)） |
| **合计** | **35 篇** + spec |

---

## 📝 维护

- **新增指南**：使用指南入 `guides/`，最佳实践入 `best_practices/`，并在本 README 对应分组登记
- **链接健康**：新增 / 修改文档时，确保所有相对链接指向真实存在的文件
- **职责边界**：用户使用问题归本目录；开发实现细节归 `dev_docs/`；架构设计归 `system_docs/`

---

**最后更新**：2026-07-07
**维护者**：Fuse 开发团队
