# Fuse 用户指南索引

> **目标**: 全部用户指南的导航入口，按使用场景分组，帮助快速定位所需文档。

**适用对象**: Fuse 插件使用者

**最后更新**: 2026-07-19

---

## 📖 使用说明

- 指南按 **编号分段** 组织：`00-0x` 入门 ∥ `1x-2x` 核心系统 ∥ `25-26` 调试 ∥ `3x` 事件 ∥ `4x` 条件 ∥ `5x` 高级主题
- 推荐阅读路径见文末 [推荐学习路径](#推荐学习路径)
- 开发者文档（组件创建、架构原理）在 [dev_docs/](../../dev_docs/) 目录

---

## 🚀 入门基础（00-06）

首次接触 Fuse 从这里开始：认识面板、变量、触发器三件套。

| 编号 | 指南 | 内容简介 |
|------|------|----------|
| 00 | [编辑器面板总览](00-editor-panels-overview.md) | Fuse 各编辑器面板/Inspector 入口一览 |
| 01 | [Fuse 变量使用指南](01-variable_system_guide.md) | LOCAL/SCOPE/GLOBAL 三层变量系统 |
| 02 | [触发器选型指南](02-trigger-selection-guide.md) | Runner、Trigger 与 MultiEventTrigger 如何选择 |
| 03 | [Runner 使用指南](03-runner-guide.md) | 信号绑定式触发器 |
| 04 | [MultiEventTrigger 使用指南](04-multi-event-trigger-guide.md) | 多事件组合触发器 |
| 05 | [表达式系统使用指南](05-expression-guide.md) | 在指令参数中书写动态表达式 |
| 06 | [指令生成器使用指南](06-instruction-generator-guide.md) | 用生成器快速脚手架自定义指令 |

---

## 🧩 核心系统（10-24）

各类指令分类详解：变换、移动、动画、音频、物理、UI、数据操作与流程控制。

| 编号 | 指南 | 内容简介 |
|------|------|----------|
| 10 | [变换系统使用指南](10-transform-guide.md) | 位置/旋转/缩放指令 |
| 11 | [Fuse 移动系统用户指南](11-movement-system-guide.md) | 角色移动与寻路 |
| 12 | [动画系统用户指南](12-animation-guide.md) | AnimationPlayer 控制 |
| 13 | [音频系统使用指南](13-audio-guide.md) | 音效/音乐播放与总线 |
| 14 | [物理系统使用指南](14-physics-guide.md) | 刚体/碰撞/射线检测 |
| 15 | [UI 系统使用指南](15-ui-guide.md) | 控件操作与界面逻辑 |
| 16 | [相机系统使用指南](16-camera-guide.md) | 相机切换与跟随 |
| 17 | [场景管理指令使用指南](17-scene-management-guide.md) | 场景切换/加载/卸载 |
| 18 | [Tween 补间动画使用指南](18-tween-animation-guide.md) | 程序化补间动画 |
| 20 | [Node Operations 指令指南](20-node-operations-guide.md) | 节点增删/属性/调用 |
| 21 | [Array 操作指南](21-array-operations-guide.md) | 数组读写与遍历 |
| 22 | [Dictionary 操作指南](22-dictionary-operations-guide.md) | 字典读写与合并 |
| 23 | [流程控制指南](23-flow-control-guide.md) | If/Else、循环、等待 |
| 24 | [数学/向量指令使用指南](24-math-vector-guide.md) | 数学运算与向量计算 |

---

## 🔍 调试（25-26）

| 编号 | 指南 | 内容简介 |
|------|------|----------|
| 25 | [调试系统用户指南](25-debugging-guide.md) | 日志、执行追踪与诊断 |
| 26 | [断点指令使用指南](26-breakpoint-guide.md) | 在指令链中设置断点 |

> 实时变量监控见高级主题中的 [变量监视器使用指南](56-variable-watcher-guide.md)。

---

## ⚡ 事件（30-34）

事件是 Trigger 的触发源，决定"什么时候执行"。

| 编号 | 指南 | 内容简介 |
|------|------|----------|
| 30 | [Lifecycle 事件指南](30-lifecycle-events-guide.md) | 就绪/进入树/退出等生命周期事件 |
| 31 | [Timing 事件指南](31-timing-events-guide.md) | 间隔/延时/定时触发 |
| 32 | [输入事件指南](32-input-events-guide.md) | 键鼠/手柄输入触发 |
| 33 | [Node 事件指南](33-node-events-guide.md) | 节点信号类事件 |
| 34 | [Event Bus 用户指南](34-event_bus_guide.md) | 全局事件总线解耦通信 |

---

## ✅ 条件（40-46）

条件决定"是否执行"，可组合为复合条件。

| 编号 | 指南 | 内容简介 |
|------|------|----------|
| 40 | [Input 条件指南](40-input-conditions-guide.md) | 输入状态判断 |
| 41 | [Node 条件指南](41-node-conditions-guide.md) | 节点状态/属性判断 |
| 42 | [Physics 条件指南](42-physics-conditions-guide.md) | 碰撞/区域检测判断 |
| 43 | [Animation 条件指南](43-animation-conditions-guide.md) | 动画播放状态判断 |
| 44 | [Time 条件指南](44-time-conditions-guide.md) | 时间/冷却判断 |
| 45 | [复合条件指南](45-composite-conditions-guide.md) | AND/OR/NOT 组合条件 |
| 46 | [综合条件合集](46-comprehensive-conditions-guide.md) | 条件系统综合参考 |

---

## 🏗️ 高级主题（50-56）

性能优化、资产复用与深度定制。

| 编号 | 指南 | 内容简介 |
|------|------|----------|
| 50 | [场景预加载系统](50-scene-preloading-guide.md) | 后台预加载场景资源 |
| 51 | [Fuse 对象池系统使用指南](51-object_pool_system_guide.md) | 高频实例化的性能优化 |
| 52 | [Fuse 多线程优化 - 用户指南](52-multithreading-optimization.md) | 多线程执行配置 |
| 53 | [Fuse 图标管理器使用指南](53-icon_manager_guide.md) | 内置/自定义图标体系 |
| 54 | [全局变量管理指南](54-global-variables-guide.md) | 全局变量持久化与存档 |
| 55 | [预设系统使用指南](55-preset-system-guide.md) | 工作流导出/导入/复用 |
| 56 | [变量监视器使用指南](56-variable-watcher-guide.md) | 实时变量监控/编辑/折线图 |

---

## 🎯 推荐学习路径

### 新手路径（第 1 天）

```
00 面板总览 → 01 变量系统 → 02 触发器选型 → 03 Runner → 23 流程控制
```

### 功能开发路径

```
10 变换 → 11 移动 → 12 动画 → 13 音频 → 15 UI → 17 场景管理
                                    ↘ 30-34 事件 ↗
                                    ↘ 40-46 条件 ↗
```

### 进阶路径

```
05 表达式 → 45 复合条件 → 34 Event Bus → 54 全局变量 → 55 预设系统
```

### 调试排障路径

```
25 调试系统 → 26 断点 → 56 变量监视器
```

---

## 📚 开发者文档入口

需要**扩展 Fuse 本身**（创建自定义指令/事件/条件、理解架构）请阅读开发文档：

| 主题 | 路径 |
|------|------|
| 指令创建 | [dev_docs/guides/instruction_creation_guide.md](../../dev_docs/guides/instruction_creation_guide.md) |
| 事件创建 | [dev_docs/guides/event_creation_guide.md](../../dev_docs/guides/event_creation_guide.md) |
| 条件创建 | [dev_docs/guides/condition_creation_guide.md](../../dev_docs/guides/condition_creation_guide.md) |
| 预设系统开发 | [dev_docs/guides/57-preset-system-dev-guide.md](../../dev_docs/guides/57-preset-system-dev-guide.md) |
| 变量监视器开发 | [dev_docs/guides/58-variable-watcher-dev-guide.md](../../dev_docs/guides/58-variable-watcher-dev-guide.md) |
| 全局变量开发 | [dev_docs/guides/59-global-variables-dev-guide.md](../../dev_docs/guides/59-global-variables-dev-guide.md) |
| 多线程 | [multithreading.md](../../multithreading.md) |

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-07-19
