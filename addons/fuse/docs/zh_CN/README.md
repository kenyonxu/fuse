> 🌐 中文 | [**English**](../en_US/README.md)
# Fuse 可视化编程系统 - 文档中心

Fuse 是一个 Godot 4.7 可视化编程插件：Event / Instruction / Condition 三类砖块在 Inspector 里搭逻辑，AI 可生成 preset，调稳的系统可"毕业"为脱离插件的工程代码——从原型到代码的非破坏性桥梁。

## 📚 文档分类

三个子目录各有自己的 README 作为完整导航，本页只做导览。

### 📖 [用户文档](user_docs/)（[完整索引](user_docs/README.md)）

面向使用者。三条内容线：

- **Introductions 系列**（16 篇）：从总览到 AI 协作与毕业交接的完整教程路径，入口 [01-总览篇](user_docs/Introductions/01-overview.md)
- **使用指南**（40 余篇）：按编号分段覆盖变量、触发器、表达式、各指令域、事件、条件与高级主题，入口 [00-index](user_docs/guides/00-index.md)
- **最佳实践**（5 篇）：自定义组件三部曲（[事件](user_docs/best_practices/custom_event.md) / [指令](user_docs/best_practices/custom_instruction.md) / [条件](user_docs/best_practices/custom_condition.md)）+ 用户实践两篇（[Preset 复用与 AI 协作](user_docs/best_practices/preset_reuse.md) / [触发器组织与竞态规避](user_docs/best_practices/trigger_organization.md)）

首次使用从 [快速开始指南](user_docs/quick_start.md) 进入。

### 🏗️ [系统文档](system_docs/)（[完整索引](system_docs/README.md)）

面向架构师与核心开发者：架构设计（9 篇，如 [可视化编程系统架构](system_docs/architecture/visual_programming_system_architecture.md)、[数据流与控制流](system_docs/architecture/dataflow_controlflow_design.md)）与 20 余篇机制分析报告（2026-07-07 经全量文档审计逐篇核对代码，各篇头部带分析时点注记）。

### 👨‍💻 [开发文档](dev_docs/)（[完整索引](dev_docs/README.md)）

面向贡献者：组件创建指南（[事件](dev_docs/guides/event-creation-guide.md) / [指令](dev_docs/guides/instruction-creation-guide.md) / [条件](dev_docs/guides/condition-creation-guide.md)，配套 agent_skills 生成 skill 为规范权威）、运行时架构（RuntimeInstance、[Event RuntimeInstance 迁移](dev_docs/guides/runtime-instance-migration-guide.md)、多线程）、基础设施（Event Bus、序列化、图标、对象池）。历史归档在本地 `archive/`（不入库）。

---

## 🚀 快速开始

### 5 分钟上手 Fuse

1. **创建触发器节点**：场景中添加 Trigger / MultiEventTrigger / Runner（三者的选型见[触发器选型指南](user_docs/guides/02-trigger-selection-guide.md)）
2. **配置动作序列**：在 Trigger 的 Inspector 中创建 ActionRunner 资源
3. **添加指令**：向 ActionRunner 的 instructions 数组添加指令
4. **测试运行**：运行场景，事件触发即执行

### 基本概念

- **事件 (Event)**：决定逻辑在什么时机触发——按键、碰撞、信号、生命周期
- **指令 (Instruction)**：触发后执行的操作——移动节点、播放音效、流程控制
- **条件 (Condition)**：执行前的判断——变量比较、复合逻辑（AND/OR/NOT）
- **变量 (Variable)**：三层作用域（LOCAL / SCOPE / GLOBAL）存储数据
- **触发器 (Trigger)**：事件入口，管理指令执行与防抖

### 下一步

- [快速开始指南](user_docs/quick_start.md) 详细步骤
- [01-总览篇](user_docs/Introductions/01-overview.md) 系统性入门
- [最佳实践](user_docs/best_practices/) 创建自定义组件

---

## 📊 系统状态

- **当前版本**: Fuse 1.0.0（见 `addons/fuse/plugin.cfg`）
- **Godot 兼容**: 4.7+
- **组件规模**: 310 个即用组件（70 事件 × 185 指令 × 55 条件，以 `addons/fuse/preset_ai_context/fuse_components.json` 为准）
- **文档规模**: 中文全树约 130 篇，另有 en_US 英文镜像 user_docs 全量 69 篇（各子目录明细见其 README）

---

## 🎯 按角色查找文档

### 游戏设计师（不写代码）
[快速开始指南](user_docs/quick_start.md) → [Introductions 系列](user_docs/Introductions/01-overview.md) → [变量系统](user_docs/guides/01-variable-system-guide.md)

### AI 辅助开发者
[Preset 复用与 AI 协作实践](user_docs/best_practices/preset_reuse.md) → [AI 协作与毕业交接](user_docs/Introductions/16-ai-collaboration-and-graduation-handoff.md)

### 游戏开发者（扩展组件）
[创建自定义事件](user_docs/best_practices/custom_event.md) · [指令](user_docs/best_practices/custom_instruction.md) · [条件](user_docs/best_practices/custom_condition.md)

### 系统架构师
[可视化编程系统架构](system_docs/architecture/visual_programming_system_architecture.md) → [数据流与控制流](system_docs/architecture/dataflow_controlflow_design.md) → [Fuse 架构优势分析](system_docs/analysis/fuse_architecture_advantages_analysis.md)

### 核心开发者
[指令系统设计](system_docs/architecture/instruction_system_design.md) → [RuntimeInstructionInstance 指南](dev_docs/guides/runtime-instruction-instance-guide.md) → [多线程开发指南](dev_docs/guides/multithreading-developer-guide.md)

---

## 📖 相关资源

- [Game Creator 文档](https://gamecreator.io/) - 可视化编程参考
- [Godot 官方文档](https://docs.godotengine.org/) - Godot API 参考
- [项目开发规范](../../../../CLAUDE.md) / [AGENTS.md](../../../../AGENTS.md) - 代码规范和开发指南
- [测试场景](../../../../tests/) - 系统测试（仓库根级，不随插件分发）
- [演示场景](../../../../demos/) - 功能演示

---

## 📝 文档更新日志

### v1.5.0 (2026-09-02)
- ✅ 根 README 回归导览本位：明细导航交还各子目录 README（根页罗列明细曾致 27 处断链与三套过期统计）
- ✅ 补 Introductions 系列与最佳实践新篇入口；角色入口增加 AI 辅助开发者线
- ✅ 基本概念补 Condition 与 SCOPE 作用域；快速开始改为三触发器表述
- ✅ 修正 tests 链接（已迁仓库根）；统计改为抗漂移口径（指向权威源）

### v1.4.0 (2026-07-07)
- ✅ 重组文档目录：仅保留 system_docs / dev_docs / user_docs
- ✅ 归档 68 个过时文档到 archive/（Stage specs/plans、proposals、reports、架构整改 plans、ideas、vision 等）
- ✅ archive/ 加入 .gitignore（本地保留，不发布）

### v1.3.0 (2026-03-19)
- ✅ 文档审计与清理：删除 7 个临时文件，归档 19 个过时文档
- ✅ 归档过时的 Trigger 系统设计文档（已迁移到 Event 模式）
- ✅ 新增 12 个用户指南与 BaseEvent / MultiEventTrigger / Runner 技术分析

### v1.2.0 (2026-03-19)
- ✅ 添加断点指令使用指南（BreakpointInstruction）

### v1.1.0 (2026-03-18)
- ✅ 添加 Expression System / 场景预加载 / 全局变量持久化 / 指令生成器指南
- ✅ 归档旧路线图与已完成任务报告

### v1.0.0 (2026-01-25)
- ✅ 创建主文档中心和导航系统

---

## 🤝 贡献指南

欢迎改进文档：
- 使用清晰的中文表达，提供代码示例和使用场景
- 新增文档在所属子目录 README 登记（各目录有自定登记规范）
- 保持文档与代码同步；数字口径以权威源为准（组件数见 `preset_ai_context/fuse_components.json`）

发现问题请在项目 Issue 中注明文档路径与问题描述。

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-09-02
**文档版本**: 1.5.0
