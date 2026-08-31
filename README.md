# Fuse — Godot 可视化逻辑插件：从 AI 原型到工程代码的非破坏性桥梁

Fuse 是一个 Godot 4.7 可视化编程 / 事件系统插件。原型侧：Event / Instruction / Condition 三类砖块（Brick）在 Inspector 里搭建与调节游戏逻辑，AI 可直接生成合规的 preset JSON；出口侧：毕业导出器把稳定的逻辑晋升为可接管的 GDScript——源 Trigger 保持不动，随时可回滚。

## 为什么是"桥梁"

可视化脚本系统最常被拒绝采用的理由不是表达力，而是"会不会被套牢"。Fuse 的答案是一条双向都安全的桥：

- **原型侧（去程）**：AI 生成 preset JSON（有 schema 约束、可离线校验）→ 导入即用，所有参数在 Inspector 里可长期调节——攻击节奏、UI 呼吸动画这类"调"比"写"多的工作，拖滑块即时生效
- **出口侧（归程）**：场景拓扑推导出 System 工件（可审阅的 JSON IR）→ 生成 GDScript（常用指令原生直译，其余委托 Fuse 运行时执行）→ 禁用原 Trigger、挂上新脚本即完成晋升；恢复 Trigger 即回滚
- **非破坏性**：插件级增量接入（可选 autoload、对现有节点直 apply，不需要重构项目）；代码副本离桥之后，桥还在

## 核心特性

- **事件驱动**：70 种事件（输入、碰撞、动画、信号、生命周期…）
- **指令编排**：182 种指令（变量、流程、动画、物理、UI、导航…）
- **条件分支**：55 种条件，支持复合条件与表达式求值
- **变量系统**：global / local / scope 三层变量，运行时监视与编辑
- **Preset AI 生成闭环**：schema 化组件清单（306 组件 + 条件参数门控）+ 离线校验器（四层规则、退出码门禁）+ eval 回归基线——AI 生成的每一份 preset 都可静态验证
- **场景拓扑面板**：主屏 Tab 可视化全场景 Fuse 单元（Trigger / MultiEventTrigger / Runner）与跨单元关联（事件、RunRunner 调用、变量读写、竞态预警），支持搜索过滤与 JSON 导出
- **毕业导出器**：拓扑 → System 工件 → GDScript（详见下节）
- **组件自动注册**：在 `instructions/` / `events/` / `conditions/` 放 `.gd` 文件即自动扫描注册
- **本地化**：基于 Godot TranslationDomain，内置 zh_CN / en
- **多线程支持**：ExecutionContext 门面，安全跨线程
- **运行时调试**：变量监视器 V2（历史折线图 + 静态声明分析）+ TCP 变量桥

## 从原型到代码（毕业导出器）

```bash
# 1. 推导 System 草稿（每个 Trigger/MultiEventTrigger 单元一份，含外联事件/变量/竞态预警清单）
Godot --headless --path . res://addons/fuse/editor/graduation/derive_systems.tscn -- --scene res://<你的场景>.tscn

# 2. 人工确认草稿（补 description、确认警告），然后校验
Godot --headless --path . res://addons/fuse/editor/graduation/validate_system.tscn -- <system.json>

# 3. 生成 GDScript + 就绪报告（覆盖率、委托清单、采用/回滚说明）
Godot --headless --path . res://addons/fuse/editor/graduation/export_system.tscn -- <system.json>
```

生成物落在 `fuse_generated/scripts/`：白名单指令（Wait/Print/SendEvent/变量读写/MathOperation/UI…）原生直译为可读代码，其余指令内嵌为数据、运行时委托 Fuse 执行——毕业是梯度不是门槛。金样例见 `fuse_generated/scripts/game_flow.gd` 与 `hint_breath.gd`。使用指南：[毕业导出器指南](addons/fuse/docs/user_docs/guides/57-graduation-exporter-guide.md)。

## 架构

```
Event（何时）──▶ Instruction（做什么）──▶ Condition（是否）
                        │
                        ▼
                ExecutionContext（运行时上下文）
                        │
                        ▼
                  ActionRunner（执行器）

场景拓扑 ──▶ System 工件（JSON IR）──▶ GDScript 生成器 ──▶ 桥接运行时（FuseDelegation）
```

**关键基类：**
- `BaseEvent` — 事件基类
- `BaseInstruction` — 指令基类
- `BaseCondition` — 条件基类
- `ExecutionContext` — 执行上下文（三层门面）
- `ActionRunner` — 动作运行器

详见 [addons/fuse/docs/](addons/fuse/docs/)。

## 安装

1. 将 `addons/fuse/` 复制到你的 Godot 4.7 项目的 `addons/` 目录
2. 项目设置 → 插件 → 启用 "Fuse Visual Programming"
3. （可选）启用 autoload：`FuseEventBus`、`FuseRuntimeBridge`

## 系统要求

- Godot 4.7+
- 兼容 2D / 3D 项目

## 文档

- [系统文档](addons/fuse/docs/system_docs/)
- [用户文档](addons/fuse/docs/user_docs/)
- [开发者文档](addons/fuse/docs/dev_docs/)
- [多线程指南](addons/fuse/docs/dev_docs/multithreading-developer-guide.md)

## 许可证

MIT License — 详见 [LICENSE](LICENSE)

## 相关链接

- GitHub 仓库：https://github.com/kenyonxu/fuse
- 问题反馈：https://github.com/kenyonxu/fuse/issues
