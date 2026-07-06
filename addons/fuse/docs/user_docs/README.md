# 用户文档

欢迎来到 Fuse 用户文档！这里提供了面向游戏设计师和开发者的使用指南、教程和最佳实践。

## 📚 文档导航

### 🚀 快速开始
- [快速开始指南](quick_start.md) - 5 分钟上手 Fuse 系统

### 📖 使用指南

#### 全局变量系统
- [全局变量管理器 V2](guides/global_variable_manager_v2.md)
  - 单例模式使用
  - 变量管理 API
  - 资源持久化
  - 信号系统
  - 本地化支持
  - 调试技巧
  - 最佳实践
  - 实际应用示例

#### 系统迁移
- [变量系统 V2 迁移指南](guides/variable_system_v2_migration.md)
  - V1 到 V2 的变化
  - 迁移步骤
  - 兼容性说明
  - 常见问题

#### 变换指令
- [坐标系统指南 - Global 与 Local](guides/coordinate_systems_guide.md)
  - Global（全局）坐标系统
  - Local（局部）坐标系统
  - 对比与选择
  - 实际应用案例
  - 最佳实践

#### 事件系统
- [Event Bus 用户指南](guides/event_bus_guide.md) 🌟 **新增**
  - 全局事件通信机制
  - SendEvent 指令使用
  - OnReceiveEvent 事件配置
  - 事件参数传递
  - 跨 Trigger 通信

### 🎯 最佳实践

#### 扩展开发
- [创建自定义事件](best_practices/custom_event.md)
  - 事件基类说明
  - 自定义事件步骤
  - 事件参数配置
  - 测试和调试

- [创建自定义指令](best_practices/custom_instruction.md)
  - 指令基类说明
  - 自定义指令步骤
  - 异步执行处理
  - 错误处理

#### 开发指南（新增）
- [指令创建指南](../development/instruction_creation_guide.md)
  - 命名规范和图标配置
  - Phase 0B 关键技术点总结
  - 完整的指令模板
  - 创建步骤和最佳实践
  - 常见陷阱和解决方案
  - 测试标准和快速参考

## 🎯 按需求查找

### 我想...

#### 学习基础知识
→ 阅读 [快速开始指南](quick_start.md)

#### 管理游戏变量
→ 查看 [全局变量管理器 V2](guides/global_variable_manager_v2.md)

#### 从旧版本迁移
→ 参考 [变量系统 V2 迁移指南](guides/variable_system_v2_migration.md)

#### 添加游戏特效
→ 学习 [Tween 补间动画使用指南](guides/tween-animation-guide.md)

#### 理解坐标系统
→ 阅读 [坐标系统指南](guides/coordinate_systems_guide.md)

#### 创建自定义事件
→ 按照 [创建自定义事件](best_practices/custom_event.md) 操作

#### 创建自定义指令
→ 按照 [创建自定义指令](best_practices/custom_instruction.md) 操作

#### 实现 Trigger 间通信
→ 阅读 [Event Bus 用户指南](guides/event_bus_guide.md)

#### 发送/接收全局事件
→ 查看 [Event Bus 用户指南](guides/event_bus_guide.md)

#### 开发新指令（Phase 2+）
→ 参考 [指令创建指南](../development/instruction_creation_guide.md)

## 📊 开发进度

### 指令开发状态（截至 2026-01-26）

| 阶段 | 状态 | 指令数量 | 完成度 |
|------|------|---------|--------|
| **Phase 0A** - 核心基础 | ✅ 已完成 | 4 | 100% |
| **Phase 0B** - 节点管理 | ✅ 已完成 | 4 | 100% |
| **Phase 1A** - 场景和变换 | ✅ 已完成 | 4 | 100% |
| **Phase 1B** - 音频系统 | ✅ 已完成 | 5 | 100% |
| **Phase 1C** - 流程控制完善 | ✅ 已完成 | 3 | 100% |
| **Phase 1D** - 变换增强 | ✅ 已完成 | 2 | 100% |
| **Phase 2A** - 场景管理增强 | 📝 计划中 | 4 | 0% |
| **Phase 2B** - 时间控制系统 | 📝 计划中 | 2 | 0% |
| **Phase 2C** - 动画和节点 | 📝 计划中 | 2 | 0% |
| **Phase 0-1 总计** | ✅ 已完成 | **22** | **100%** |
| **Phase 2 总计** | 📝 计划中 | **8** | **0%** |
| **所有阶段总计** | 🚧 进行中 | **30** | **73%** |

**代码质量：**
- ✅ Phase 1A-1D 代码审查完成（22 个指令）
- ✅ 22 项代码质量改进（本地化、测试、语法修复）
- ✅ 创建指令开发指南

**下一步：**
- 📋 Phase 2 开发计划已创建（8 个指令）
- 🎯 目标：1-1.5 周完成 8 个指令
- ✅ Wait 指令已在之前阶段完成，已从 Phase 2 移除

详见：
- [Phase 2 开发计划](../../../../docs/plans/2026-01-26-fuse-phase2-instruction-plan.md)
- [指令评估报告](../roadmap/2026-01-25-instruction-evaluation-report-v2.md)

---

## 📊 文档统计

| 类别 | 文档数量 |
|------|----------|
| 快速开始 | 1 篇 |
| 使用指南 | 5 篇 |
| 最佳实践 | 2 篇 |
| 开发指南 | 1 篇 |
| **总计** | **9 篇** |

## 🔗 相关资源

### 系统文档
- [系统架构](../system_docs/architecture/visual_programming_system_architecture.md) - 深入了解系统设计
- [变量系统设计](../system_docs/architecture/variable_system_design.md) - 变量系统架构

### 开发文档
- [变量存储实现](../dev_docs/reports/variable_storage_phase1-2_report.md) - 实现细节
- [本地化覆盖报告](../dev_docs/reports/localization_coverage_report.md) - 本地化支持

### 外部参考
- [Godot 官方文档](https://docs.godotengine.org/) - Godot API 参考
- [Game Creator 文档](https://gamecreator.io/) - 可视化编程参考

## 💡 使用提示

### 文档阅读顺序建议

**初学者**：
1. [快速开始指南](quick_start.md)
2. [全局变量管理器 V2](guides/global_variable_manager_v2.md)
3. [Tween 补间动画使用指南](guides/tween-animation-guide.md)

**进阶用户**：
1. [变量系统 V2 迁移指南](guides/variable_system_v2_migration.md)
2. [创建自定义事件](best_practices/custom_event.md)
3. [创建自定义指令](best_practices/custom_instruction.md)

### 常见任务速查

| 任务 | 文档 |
|------|------|
| 初始化全局变量 | [全局变量管理器 V2](guides/global_variable_manager_v2.md#快速开始) |
| 监听变量变化 | [全局变量管理器 V2](guides/global_variable_manager_v2.md#监听变量变化) |
| 保存/加载变量 | [全局变量管理器 V2](guides/global_variable_manager_v2.md#资源持久化) |
| 播放震动效果 | [Tween 补间动画使用指南](guides/tween-animation-guide.md) |
| 理解 Global/Local 坐标 | [坐标系统指南](guides/coordinate_systems_guide.md) |
| 创建自定义事件 | [创建自定义事件](best_practices/custom_event.md#自定义事件步骤) |
| 创建自定义指令 | [创建自定义指令](best_practices/custom_instruction.md#自定义指令步骤) |
| 发送全局事件 | [Event Bus 用户指南](guides/event_bus_guide.md#sendevent-指令) |
| 接收全局事件 | [Event Bus 用户指南](guides/event_bus_guide.md#onreceiveevent-事件) |
| Trigger 间通信 | [Event Bus 用户指南](guides/event_bus_guide.md) |

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-02-27
