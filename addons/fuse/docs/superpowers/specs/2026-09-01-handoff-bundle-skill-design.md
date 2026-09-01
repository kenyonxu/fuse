# Fuse 毕业交接 skill（fuse-handoff-packer）设计

**日期：** 2026-09-01
**状态：** 设计定稿（待实施）
**上下文：** 2026-09-01 出口方向修订的直接落点（毕业 spec `2026-08-30-preset-gdscript-graduation-design.md` 的"方向修订记录"、价值评估文档 §8.2 第六轮修订记录）——出口主线改为 **AI 交接工件**：拓扑 + System 划分 + preset 供给用户自己的 AI agent 编写脱离 Fuse 的代码。本 spec 定义交接工件的打包机制。

## 1. 目标与范围

**做什么：** 一个随插件分发的交互式 agent skill，在与用户的对话中确认"要毕业哪个系统、需要什么"，把现成原料（System JSON、拓扑 JSON、preset JSON、组件 schema、语义契约、基建模板）打包为自包含的目录包（handoff bundle），交给写代码的 AI agent。

**不做什么（硬边界）：**

- **零引擎代码**：不写 GDScript 打包器、不加 CLI、不动 `addons/fuse` 运行时——打包的交互确认、语义裁剪、模板挑选由 LLM 执行（确定性打包器是用代码模拟 agent 已有的能力，违背方向修订的立论）
- skill **不生成代码**：bundle 只供给上下文，写代码是接包 agent 的事
- 不做编辑器 UI、不做回放测试（验收用静态清单）
- 不迁移 `.claude/skills/` 下现有 6 个开发 skill（后续可选迁移项，另行决定）——**✅ 后续裁决（2026-09-01 收尾后）：6 个开发 skill 已迁入 `addons/fuse/agent_skills/` 统一收纳，`.claude/skills/` 目录移除**

## 2. 定位与原则

与入桥侧对称：入桥 = `agent_skills/fuse-preset-generator`（AI 读 `preset_ai_context` 写 preset 进 Fuse；2026-09-01 自 `.claude/skills/` 迁入）；出桥 = 本 skill（AI 读拓扑/System/preset 打包交接件出 Fuse）。**Fuse 的角色收缩为事实源**：`export_topology` / `derive_systems` / `validate_system` CLI 与 `preset_ai_context` 三 JSON 全部已存在，本 skill 纯消费。

三条设计原则：

1. **工具中立**：SKILL.md 与资产是纯 markdown/GDScript 文本，不依赖任何 agent 工具的专有机制；任何能读文件、跑 Bash、与用户对话的 agent 均可执行
2. **bundle 自包含**：接包 agent 不需要访问 Fuse 仓库或源项目即可理解系统并写代码
3. **非破坏性**：全程只读 Fuse 侧资产、只写 `fuse_generated/handoff/`；源 Trigger 不动，随时可回滚

## 3. skill 目录与分发

```
addons/fuse/agent_skills/fuse-handoff-packer/
├── SKILL.md              # 交互流程 + 打包规范（本 skill 的唯一入口文档）
└── assets/
    ├── semantics.md          # 通用语义契约（静态，随包拷贝）
    ├── README-for-agent.tpl  # bundle 入口骨架
    ├── acceptance-guide.md   # 验收清单提炼指引
    └── templates/            # 基建参考模板（纯 GDScript）
        ├── event_bus.gd
        ├── object_pool.gd
        └── global_state.gd
```

- **放 `addons/fuse/agent_skills/` 而非 `.claude/skills/`**：本 skill 的使用者是用户自己游戏项目里的 agent；用户安装 Fuse = 复制 `addons/fuse/`，skill 随插件到达，且不被 Claude Code 专属目录绑定
- **触发方式**：用户项目根的 AGENTS.md（或任何 agent 指令文件）加一行指路——"要毕业 Fuse 系统时，读 `addons/fuse/agent_skills/fuse-handoff-packer/SKILL.md` 并遵循"；安装文档提供这行文案。与既有 skill 的"Read 该 SKILL.md 并遵循"用法一致

## 4. SKILL.md 交互流程（七步）

每步含：输入、与用户的交互点、产出、失败分支。

| 步骤 | 内容 | 交互点 / 失败分支 |
|------|------|------------------|
| 1 确认目标 | 哪个场景、哪个（些）System、毕业动机 | 动机影响验收重点（性能接管 / 脱离插件 / 交接给程序员），不确定时问 |
| 2 备料 | `fuse_generated/systems/<name>.json` 是否存在 | 无定稿 → 代跑 `derive_systems` CLI，逐单元与用户确认划分 / description / 警告确认（拷入 `acknowledged_warnings`），再跑 `validate_system`；有 error 先解决 |
| 3 行为规格 | 引导用户从编辑器导出相关 Trigger 的 preset JSON（编辑器已有导出功能） | preset 为指令规格主体；`.tscn` 只读节点结构作补充（NodePath 锚点、节点层级）；用户不会导出 → 指引 55 号指南 |
| 4 拓扑快照 | 代跑 `export_topology` CLI，得含 `source_scene` 溯源的拓扑 JSON | CLI 失败（场景路径错等）→ 修正后重跑 |
| 5 模板确认 | 从 preset 的指令类型集推荐基建模板：SendEvent/OnReceiveEvent → event_bus；WarmUpPool → object_pool；global 层变量 → global_state | 推荐清单展示给用户，可增删；无匹配依赖则不带 templates/ |
| 6 打包 | 见 §5 产物清单逐件落盘 | 组件类型在 `preset_ai_context` 无 schema → 照常打包 preset 原文，并在 README-for-agent.md 标注"该组件无 schema，按 JSON 原文理解" |
| 7 交付 | 报告 bundle 路径与内容摘要，提示"交给写代码的 agent，验收对照 acceptance.md" | — |

CLI 调用形态沿用项目惯例（`Godot --headless --path <项目> <tscn> -- <args>`）；skill 在用户项目内执行时以用户项目的 Godot 可执行文件与路径为准，bundle 与 CLI 产物均落在**用户项目**根的对应目录（`fuse_generated/`、`fuse_reports/`）。

## 5. bundle 产物结构

单 System 一包，落 `fuse_generated/handoff/<system_name>/`：

```
├── README-for-agent.md   # agent 入口：系统意图（system.description）、工件导航（各文件
│                         #   是什么怎么读）、模板用法建议、验收要求、约束（勿依赖 addons/fuse、
│                         #   NodePath 以源场景为准、behavior 语义见 semantics.md）
├── system.json           # 系统划分定稿拷贝：units / externals（外联事件/变量）/ acknowledged_warnings
├── topology.json         # 源场景拓扑快照拷贝（全场景跨单元关联——agent 需要知道邻居做接口对接；
│                         #   README 指明本 System 只负责 units 列出的单元）
├── presets/*.json        # 用户导出的 preset JSON（行为规格主体，可多份）
├── semantics.md          # 语义契约（assets 版拷贝，见 §6.1）
├── acceptance.md         # 行为验收清单（按 §6.3 指引从 preset/System 现场提炼）
├── components.json       # 涉及组件的参数 schema：preset JSON 中出现的 type 集合 →
│                         #   从 preset_ai_context 三 JSON（components/schemas/enums）抽对应条目
└── templates/*.gd        # 用户确认后的基建模板拷贝（无匹配则整目录省略）
```

## 6. 资产设计

### 6.1 semantics.md（通用语义契约）

描述**源 Fuse 运行时语义**——接包 agent 按此写出行为等价代码。内容清单（提炼自毕业 spec 执行中修订记录与 trigger/ActionRunner 源码，写作时以源码为准）：

1. **重触发策略**：执行中再次触发默认忽略（SKIP）；RESTART 模式为取消当前并重启
2. **单次触发 = 一个执行上下文**：整条指令链（含嵌套/分支内）共享一个 ctx，LOCAL 变量在其中跨指令读写——agent 代码需保证等价的连续性（毕业导出器终审 C1 的结论反转给 agent：别逐指令丢状态）
3. **门控消耗时机**：trigger_once 在条件通过后才消耗（条件失败不消耗，后续触发仍放行）；冷却自冷却检查通过即开始计时（**条件失败也进冷却**）——注意这与毕业导出器生成代码的简化行为相反，契约必须写源语义（写作时以 trigger.gd 源码为准）
4. **事件参数注入**：触发事件携带的参数以 `event_<key>` 形式可被条件与指令引用；`event_source` / `triggered_node` 指向触发源
5. **执行模式**：指令序列 SEQUENTIAL（默认，顺序 await）与 PARALLEL（并行启动，全部完成才结束）
6. **三层变量语义**：local = 单次触发链内；scope = 节点邻域（ScopeVariableContainer 向上搜索）；global = 全游戏持久（可存档）
7. **指令失败传播**：序列中指令失败时的行为（以 ActionRunner 源码为准，写作时核实补全）

### 6.2 基建模板（首版三个）

自包含纯 GDScript、零 `addons/fuse` 依赖、带文档注释；**API 形状对齐 Fuse 对应概念**，使 preset 里的用法能直译：

- `event_bus.gd` — 对齐 FuseEventBus：`send_event(name, args)` / `subscribe(name, cb) -> Subscription` / `unsubscribe(sub)`（autoload 用法说明附注释）
- `object_pool.gd` — 对齐 WarmUpPool：预热批量（batch_size/batch_delay）、`acquire`/`release`、上限与增长策略
- `global_state.gd` — 对齐 global 层变量：单例存储、get/set/存在性、可选持久化（对应 LoadGlobalVariables/SaveGlobalVariables 语义）

模板是**推荐参考实现**：README-for-agent.md 声明 agent 可采用、改写或替换。

### 6.3 acceptance-guide.md（验收清单提炼指引）

指导打包时的 agent 从 preset/System 提炼静态可对照断言，类型清单：

- **事件序列**：SendEvent 的 event_name 与顺序、参数值（含 `$var` 引用的解析来源）
- **变量终值**：SetVariable / MathOperation 的写入目标与期望值（含分支条件）
- **触发-效果对**：每个 binding 的事件 → 指令链摘要（OnReceiveEvent X → 扣命 → 若命=0 → GameEnd）
- **时序约束**：Wait 链、间隔触发周期、冷却时长
- **边界条件**：重触发行为（SKIP/RESTART）、trigger_once、条件失败重试

清单格式：每条断言一行、可勾选（`- [ ]`），并注明来源（preset 文件名 + 路径）。

### 6.4 README-for-agent.tpl

骨架段落：系统意图 → 工件导航表 → 本系统范围（units/externals 摘要）→ 语义契约要点（指向 semantics.md）→ 模板使用建议 → 验收要求（指向 acceptance.md，要求逐条核对后在代码注释/交付说明中回标）→ 约束（勿依赖 addons/fuse；节点路径以 topology.json 为准；语义歧义时以 semantics.md 与 preset JSON 原文为准并显式列出假设）。

## 7. Fuse 侧改动（仅文档）

| 文档 | 改动 |
|------|------|
| README.md | "从原型到工程代码"节：交接流程补 skill 打包步骤（替换"规划中"占位） |
| 57 号指南 | "后续方向"节替换为 skill 的实际用法入口 |
| AGENTS.md | 配套 skill 表格加一行：毕业交接 → `addons/fuse/agent_skills/fuse-handoff-packer/SKILL.md` |
| 安装/用户文档 | `agent_skills/` 目录说明 + AGENTS.md 指路文案（供用户复制进自己项目） |

## 8. 验证（验收场景）

用金样例 brickian 的 `game_flow` 系统人工走一遍 skill 全流程：

1. 七步交互可走通，产物齐全且落盘结构符合 §5
2. **自包含性检查**：把 bundle 拷到独立目录，仅凭包内文件能回答"这个系统做什么、包含哪些单元、行为规格在哪、怎么验收"——不依赖 Fuse 仓库
3. **语义契约正确性**：semantics.md 各条与 trigger.gd / ActionRunner / ExecutionContext 源码逐条核对
4. **交叉验证**：bundle 内行为规格与实验性毕业导出器的金样例 `game_flow.gd`（同一数据源）对照——两者对同一 binding 的指令序列应一致
5. 模板三个可独立解析（`Godot --headless --check-only` 或 load 零错）

## 9. 实施范围

单里程碑交付（工程主体是 skill 文档与资产的编写，无代码风险面）：

1. skill 目录 + SKILL.md（七步流程 + 打包规范）
2. assets 四件：semantics.md（核实源码后成文）、三个模板、README-for-agent.tpl、acceptance-guide.md
3. 金样例走查（§8）产出首个真实 bundle 作为样例入库
4. §7 文档同步
