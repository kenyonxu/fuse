# Fuse — Godot 可视化逻辑插件：从 AI 原型到工程代码的非破坏性桥梁

Fuse 是一个 Godot 4.7 可视化编程 / 事件系统插件。原型侧：Event / Instruction / Condition 三类砖块（Brick）在 Inspector 里搭建与调节游戏逻辑，AI 可直接生成合规的 preset JSON；出口侧：拓扑与 preset 产出结构化交接工件（System 划分 + 行为规格），交给**你自己的 AI agent** 编写脱离 Fuse 的工程代码——不写代码的用户留在 Fuse 运行时继续调参，源 Trigger 始终不动，随时可回滚。

## 为什么是"桥梁"

可视化脚本系统最常被拒绝采用的理由不是表达力，而是"会不会被套牢"。Fuse 的答案是一条双向都安全的桥：

- **原型侧（去程）**：AI 生成 preset JSON（有 schema 约束、可离线校验）→ 导入即用，所有参数在 Inspector 里可长期调节——攻击节奏、UI 呼吸动画这类"调"比"写"多的工作，拖滑块即时生效
- **出口侧（归程）**：场景拓扑推导出 System 工件（可审阅的系统划分 JSON IR）→ 连同 preset（行为规格）交给用户的 AI agent，编写**脱离 Fuse** 的工程代码——Fuse 供给结构化事实，不代写代码；不写代码的用户留在 Fuse 运行时
- **非破坏性**：插件级增量接入（可选 autoload、对现有节点直 apply，不需要重构项目）；代码副本离桥之后，桥还在

## 核心特性

- **事件驱动**：70 种事件（输入、碰撞、动画、信号、生命周期…）
- **指令编排**：182 种指令（变量、流程、动画、物理、UI、导航…）
- **条件分支**：55 种条件，支持复合条件与表达式求值
- **变量系统**：global / local / scope 三层变量，运行时监视与编辑
- **Preset AI 生成闭环**：schema 化组件清单（306 组件 + 条件参数门控）+ 离线校验器（四层规则、退出码门禁）+ eval 回归基线——AI 生成的每一份 preset 都可静态验证
- **场景拓扑面板**：主屏 Tab 可视化全场景 Fuse 单元（Trigger / MultiEventTrigger / Runner）与跨单元关联（事件、RunRunner 调用、变量读写、竞态预警），支持搜索过滤与 JSON 导出
- **AI 交接工件**：拓扑导出 + System 划分（JSON IR），供给用户的 AI agent 编写脱离 Fuse 的代码（详见下节）
- **实验性代码导出器**：拓扑 → System 工件 → GDScript（与 Fuse 运行时共存的混合委托模式）
- **组件自动注册**：在 `instructions/` / `events/` / `conditions/` 放 `.gd` 文件即自动扫描注册
- **本地化**：基于 Godot TranslationDomain，内置 zh_CN / en
- **多线程支持**：ExecutionContext 门面，安全跨线程
- **运行时调试**：变量监视器 V2（历史折线图 + 静态声明分析）+ TCP 变量桥

## 从原型到工程代码（AI 交接）

Fuse 不代写代码——它把"系统做什么、包含哪些组件、行为规格是什么"产出为结构化工件，交给你自己的 AI agent 去写脱离 Fuse 的工程代码：

```bash
# 1. 导出场景拓扑（全量关联 + 源场景溯源）
Godot --headless --path . res://addons/fuse/editor/topology/export_topology.tscn -- --scene res://<你的场景>.tscn

# 2. 推导 System 草稿——每个 Trigger/MultiEventTrigger 单元一份（含外联事件/变量/竞态预警清单）
Godot --headless --path . res://addons/fuse/editor/graduation/derive_systems.tscn -- --scene res://<你的场景>.tscn

# 3. 人工确认草稿（补 description、确认警告），然后校验
Godot --headless --path . res://addons/fuse/editor/graduation/validate_system.tscn -- <system.json>
```

把拓扑 JSON + System JSON + 相关 preset 交给你的 AI agent，即可开始编写脱离 Fuse 的代码；Fuse 侧源 Trigger 保持不动，随时可回滚。一键打包交接工件由随插件分发的 **fuse-handoff-packer skill** 完成（`addons/fuse/agent_skills/fuse-handoff-packer/SKILL.md`，工具中立，任何 AI agent 均可执行）：它与你交互确认系统与模板后产出 `fuse_generated/handoff/<系统名>/` 自包含交接包（系统划分 / 拓扑 / preset / 语义契约 / 验收清单 / 组件 schema / 基建模板）。样例见 `fuse_generated/handoff/game_flow/`。

> **实验性**：毕业导出器（`export_system` CLI）可直接生成与 Fuse 运行时共存的 GDScript——白名单指令原生直译，其余委托执行。它不是推荐出口（生成代码仍依赖 Fuse 运行时），保留作参考实现，详见[毕业导出器指南](addons/fuse/docs/user_docs/guides/57-graduation-exporter-guide.md)。

## 架构

```
Event（何时）──▶ Instruction（做什么）──▶ Condition（是否）
                        │
                        ▼
                ExecutionContext（运行时上下文）
                        │
                        ▼
                  ActionRunner（执行器）

场景拓扑 ──▶ System 工件（JSON IR）──▶ 用户的 AI agent ──▶ 脱离 Fuse 的工程代码
                    └──（实验）──▶ GDScript 生成器 ──▶ 桥接运行时（FuseDelegation）
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
4. （毕业交接）你的 AI agent 需要读 `addons/fuse/agent_skills/fuse-handoff-packer/SKILL.md`——建议在你项目的 AGENTS.md / CLAUDE.md 等指令文件中加一行指路

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
