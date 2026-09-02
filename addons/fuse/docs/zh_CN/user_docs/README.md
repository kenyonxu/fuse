# 用户文档（user_docs）

面向游戏设计师与开发者的使用指南、教程与最佳实践。

> 架构与系统设计见 [../system_docs/](../system_docs/)；开发向指南见 [../dev_docs/](../dev_docs/)；历史文档见 [../archive/](../../archive/)。

---

## 🚀 入口

| 文档 | 说明 |
|------|------|
| [快速开始](quick_start.md) | 5 分钟上手 Fuse 系统 |
| [功能特性](FEATURES.md) | Fuse 功能总览 |

---

## 📖 使用指南（39 篇，五层学习路径）

### 🟢 第一层：入门（01-06）

| 编号 | 文档 | 说明 |
|------|------|------|
| 01 | [变量系统指南](guides/01-variable-system-guide.md) | 变量系统整体使用 |
| 02 | [触发器选择](guides/02-trigger-selection-guide.md) | 触发器选型与配置 |
| 03 | [Runner 指南](guides/03-runner-guide.md) | Runner 执行模型 |
| 04 | [多事件触发器](guides/04-multi-event-trigger-guide.md) | MultiEventTrigger 配置 |
| 05 | [表达式指南](guides/05-expression-guide.md) | 表达式求值 |
| 06 | [指令生成器](guides/06-instruction-generator-guide.md) | 自动生成指令 |

### 🔵 第二层：核心系统（10-18）

| 编号 | 文档 | 说明 |
|------|------|------|
| 10 | [变换指南](guides/10-transform-guide.md) | Transform 操作 |
| 11 | [移动系统](guides/11-movement-system-guide.md) | 节点移动 |
| 12 | [动画指南](guides/12-animation-guide.md) | AnimationPlayer 使用 |
| 13 | [音频指南](guides/13-audio-guide.md) | 音频播放 |
| 14 | [物理指南](guides/14-physics-guide.md) | 物理操作 |
| 15 | [UI 指南](guides/15-ui-guide.md) | UI 操作 |
| 16 | [相机指南](guides/16-camera-guide.md) | 相机控制 |
| 17 | [场景管理](guides/17-scene-management-guide.md) | 场景加载/切换 |
| 18 | [Tween 补间动画](guides/18-tween-animation-guide.md) | Tween 震动/补间效果 |

### 🟡 第三层：指令操作（20-26）

| 编号 | 文档 | 说明 |
|------|------|------|
| 20 | [节点操作](guides/20-node-operations-guide.md) | 节点指令操作 |
| 21 | [数组操作](guides/21-array-operations-guide.md) | 数组指令 |
| 22 | [字典操作](guides/22-dictionary-operations-guide.md) | 字典指令 |
| 23 | [流程控制](guides/23-flow-control-guide.md) | 分支、循环、等待 |
| 24 | [数学与向量](guides/24-math-vector-guide.md) | 向量运算 |
| 25 | [调试指南](guides/25-debugging-guide.md) | 调试工具与技巧 |
| 26 | [断点调试](guides/26-breakpoint-guide.md) | 断点使用 |

### 🟠 第四层：事件与条件

#### 事件（30-34）

| 编号 | 文档 | 说明 |
|------|------|------|
| 30 | [生命周期事件](guides/30-lifecycle-events-guide.md) | 节点生命周期事件 |
| 31 | [计时事件](guides/31-timing-events-guide.md) | 计时相关事件 |
| 32 | [输入事件](guides/32-input-events-guide.md) | 输入事件处理 |
| 33 | [节点事件](guides/33-node-events-guide.md) | 节点相关事件 |
| 34 | [Event Bus](guides/34-event-bus-guide.md) | 全局事件通信 |

#### 条件（40-46）

| 编号 | 文档 | 说明 |
|------|------|------|
| 40 | [输入条件](guides/40-input-conditions-guide.md) | 输入检测条件 |
| 41 | [节点条件](guides/41-node-conditions-guide.md) | 节点状态条件 |
| 42 | [物理条件](guides/42-physics-conditions-guide.md) | 物理检测条件 |
| 43 | [动画条件](guides/43-animation-conditions-guide.md) | 动画状态条件 |
| 44 | [时间条件](guides/44-time-conditions-guide.md) | 时间相关条件 |
| 45 | [复合条件](guides/45-composite-conditions-guide.md) | 复合条件配置 |
| 46 | [条件大全](guides/46-comprehensive-conditions-guide.md) | 条件完整参考 |

### 🔴 第五层：高级（50-54）

| 编号 | 文档 | 说明 |
|------|------|------|
| 50 | [场景预加载](guides/50-scene-preloading-guide.md) | 预加载优化 |
| 51 | [对象池系统](guides/51-object-pool-system-guide.md) | 对象池使用 |
| 52 | [多线程优化](guides/52-multithreading-optimization.md) | 多线程执行 |
| 53 | [图标管理器](guides/53-icon-manager-guide.md) | 图标配置与管理 |
| 54 | [全局变量指南](guides/54-global-variables-guide.md) | 全局变量使用 |

---

## 🎯 最佳实践（5 篇）

| 文档 | 说明 |
|------|------|
| [创建自定义事件](best_practices/custom_event.md) | 事件基类、自定义步骤、参数、测试 |
| [创建自定义指令](best_practices/custom_instruction.md) | 指令基类、自定义步骤、异步、错误处理 |
| [创建自定义条件](best_practices/custom_condition.md) | 条件基类、模板方法、线程安全、缓存 |
| [Preset 复用与 AI 协作](best_practices/preset_reuse.md) | 粒度、依赖最小化、AI 生成-校验-调参循环 |
| [触发器组织与竞态规避](best_practices/trigger_organization.md) | 写写竞态定义、规避五法、大场景组织 |

---

## 🎯 任务导向入口

### 我想…
- **上手 Fuse** → [快速开始](quick_start.md)
- **做动画/特效** → [Tween 补间动画](guides/18-tween-animation-guide.md) · [动画指南](guides/12-animation-guide.md)
- **Trigger 间通信** → [Event Bus](guides/34-event-bus-guide.md)
- **创建自定义组件** → [自定义事件](best_practices/custom_event.md) · [自定义指令](best_practices/custom_instruction.md) · [自定义条件](best_practices/custom_condition.md)
- **复用逻辑 / 让 AI 生成 preset** → [Preset 复用与 AI 协作](best_practices/preset_reuse.md)
- **场景变大想理清触发器** → [触发器组织与竞态规避](best_practices/trigger_organization.md)
- **调试** → [调试指南](guides/25-debugging-guide.md) · [断点](guides/26-breakpoint-guide.md)

> 开发者创建组件的完整流程另见 [../dev_docs/guides/](../dev_docs/guides/)（事件/指令/条件创建指南）。

---

## 🔗 跨目录资源

### 系统文档（../system_docs/）
- [可视化编程系统架构](../system_docs/architecture/visual_programming_system_architecture.md) · [变量系统设计](../system_docs/architecture/variable_system_design.md)
- [组件分析](../system_docs/analysis/)（BaseEvent / BaseInstruction / BaseCondition / BaseVariable 等）

### 开发文档（../dev_docs/）
- [开发指南目录](../dev_docs/guides/)（事件/指令/条件/多线程/图标系统等创建指南）

### 历史归档（../archive/）
早期使用指南（如变量系统 V2 迁移）、路线图、阶段计划均已归档。仅供参考，**以本目录指南为准**。

---

## 📊 文档统计

| 类别 | 数量 |
|------|------|
| 入口文档 | 2 篇（quick_start、FEATURES） |
| 使用指南 | 39 篇（`guides/`） |
| 最佳实践 | 2 篇（`best_practices/`） |
| 更新规格 | 1 篇（[UPDATE_SPEC.md](UPDATE_SPEC.md)） |
| **合计** | **43 篇** + spec |

---

## 📝 维护

- **新增指南**：使用指南入 `guides/`，最佳实践入 `best_practices/`，并在本 README 对应分组登记
- **链接健康**：新增/修改文档时，确保所有相对链接指向真实存在的文件
- **职责边界**：用户使用问题归本目录；开发实现细节归 `dev_docs/`；架构设计归 `system_docs/`

---

**最后更新**：2026-07-07
**维护者**：Fuse 开发团队
