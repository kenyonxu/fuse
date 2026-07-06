# Fuse — Godot 可视化编程系统

一个用于 Godot 4.7 的可视化编程 / 事件系统插件，灵感来源于 Game Creator 的无代码脚本系统。通过 Event / Instruction / Condition 三类砖块（Brick）组合，无需编写代码即可搭建游戏逻辑。

## 核心特性

- **事件驱动**：65+ 种事件（输入、碰撞、动画、信号、生命周期…）
- **指令编排**：130+ 种指令（变量、流程、动画、物理、UI、导航…）
- **条件分支**：43+ 种条件，支持复合条件与表达式求值
- **变量系统**：global / local / scope 三层变量，运行时监视与编辑
- **组件自动注册**：在 `instructions/` / `events/` / `conditions/` 放 `.gd` 文件即自动扫描注册
- **本地化**：基于 Godot TranslationDomain，内置 zh_CN / en
- **多线程支持**：ExecutionContext 门面，安全跨线程
- **运行时调试**：变量监视器 V2（历史折线图 + 静态声明分析）+ TCP 变量桥

## 架构

```
Event（何时）──▶ Instruction（做什么）──▶ Condition（是否）
                        │
                        ▼
                ExecutionContext（运行时上下文）
                        │
                        ▼
                  ActionRunner（执行器）
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
