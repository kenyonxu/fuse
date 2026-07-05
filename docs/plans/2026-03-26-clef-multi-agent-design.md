# Clef Phase 3: 多 Agent 专业流水线设计

> 日期：2026-03-26
> 状态：设计评审 v3（技术调研完成）
> 前置依赖：Phase 1 + Phase 2 迭代 + 风格参考系统已完成

## 目标

将单 Agent 的 `/clef-compose` Skill 升级为多 Agent 协作模式，模拟真实游戏音乐制作工作室的角色分工，提升生成质量、支持局部迭代。

> **诚实声明：** 多 Agent 模式的总 token 消耗可能高于单 Agent（Producer 最终需审查所有产出），核心收益是**专业化分工**和**局部迭代能力**，而非减少上下文。

## 前置验证

### Agent 工具可行性 — 已通过技术调研确认 ✅

> **调研日期：** 2026-03-26
> **调研来源：** Claude Code 官方文档、GitHub Issues、社区实践

**核心结论：** SKILL.md（作为 Producer）可以通过 Agent 工具创建子 Agent。这是已确认可行的方式，`/batch` 和 `/simplify` 等内置 Skill 就是这样工作的。

**已确认的能力：**

| 能力 | 状态 | 说明 |
|------|------|------|
| Skill 中通过 Agent 工具生成子 Agent | ✅ 可行 | SKILL.md 指令可包含 "使用 Agent 工具生成子 Agent"，内置 Skill 已有先例 |
| 子 Agent 读写 `.clef-work/` 文件 | ✅ 可行 | 子 Agent 与父会话共享文件系统，可直接读写同一目录 |
| 并行执行（单条消息同时生成多个 Agent） | ✅ 可行 | 单条消息中同时生成多个 Agent 工具调用即并行执行 |
| Producer 读取子 Agent 产出 | ✅ 可行 | 子 Agent 返回结果给父会话，或通过文件系统间接传递 |

**硬限制（影响设计的关键约束）：**

| 限制 | 影响 | 应对 |
|------|------|------|
| **子 Agent 不能再生成子 Agent** | Producer 不能是子 Agent，必须在主会话执行 | Producer = Skill 自身（主会话），已与设计一致 |
| `context: fork` + `agent:` 有已知 Bug [#17283](https://github.com/anthropics/claude-code/issues/17283) | 不能依赖 Skill 自动在隔离上下文中以指定 Agent 运行 | 不使用 `context: fork`，Skill 在主会话中通过 Agent 工具手动生成子 Agent |
| 自定义 Agent 定义需放在 `.claude/agents/` | Skill 目录内的 `agents/` 不能被 Agent 工具自动识别 | Agent 定义放 `.claude/agents/clef-*.md`，或 SKILL.md 中内联 prompt |

**技术选择决策：**

**Agent 定义方式** — 采用 `.claude/agents/` 目录定义（方案 A）：

| 方案 | 描述 | 优点 | 缺点 |
|------|------|------|------|
| A. `.claude/agents/` 定义 | 4 个 Agent 各一个 `.md` 文件 | 可被 Agent 工具直接识别；支持 `model`、`tools` 等字段；其他 Skill 可复用 | 与 Skill 分离，发布时需复制两处 |
| B. SKILL.md 内联 prompt | 在生成 Agent 时直接传 prompt 字符串 | 全部在一个文件中，简单 | prompt 过长导致 SKILL.md 臃肿；无法利用 Agent 定义的 `model`/`tools` 字段 |

选择方案 A，理由：
1. 每个 Agent 可独立配置模型（Composer → Opus, Rhythmist → Haiku）
2. 每个 Agent 可配置 `tools` 白名单，限制只读写必要文件
3. Agent 定义可被 Agent 工具的 `subagent_type` 直接引用
4. 虽然与 Skill 目录分离，但 `.claude/agents/` 已被 git 追踪，发布不是问题

**不需要 Agent Teams：** Agent Teams 是实验性功能，不支持会话恢复，对当前场景过于复杂。Subagent 模式（Agent 工具）已足够满足需求。

**前置验证简化：** 原计划写最小原型验证，现改为直接实现。如实现中发现问题再调整。

### 理论知识注入方式

Agent 定义支持 `skills` 字段，可预加载 Skill 内容到子 Agent 上下文。但 theory.md 内容较长（~3000 字），且每个 Agent 只需要其中部分章节，因此采用以下策略：

- **不使用 `skills` 字段预加载 theory.md**（全量注入浪费上下文）
- **在 Agent prompt 的"必读文件"中指定 theory.md 及重点关注章节**
- 子 Agent 启动后自行读取 theory.md（已确认子 Agent 可使用 Read 工具）

## 触发方式

```
/clef-compose Boss战音乐                    → 单 Agent 模式（现有流程，零影响）
/clef-compose Boss战音乐 --multi-agent      → 多 Agent 模式（新流程）
```

默认单 Agent，用户显式选择多 Agent。

## 角色映射

参考真实游戏音乐制作团队（如 Final Fantasy 的植松伸夫团队）：

| Agent 角色 | 工作室对应 | 职责 | 建议模型 |
|-----------|-----------|------|---------|
| **Producer** | 音乐制作人 | 需求解析、整体规划、任务分配、质量把控、最终输出 | Sonnet |
| **Harmonist** | 和声/编曲 | 和弦进行、声部排列、和弦外音、段落和声设计 | Sonnet |
| **Composer** | 作曲家 | 旋律线、动机发展、乐句衔接（最核心的创意输出） | Opus |
| **Rhythmist** | 节奏/打击乐 | 鼓组编排、低音线设计、节奏模式、段落节奏变化 | Haiku |
| **Orchestrator** | 管弦乐编配 | 表现力层（CC/弯音/力度曲线）、频率平衡、音色搭配、混音分层 | Sonnet |

## 执行流程

```
Producer（串行）
  ↓ 解析需求 + --ref 风格分析
  ↓ 生成 plan.json + style_profile.json
  ↓
  ├──→ Harmonist（并行 A）──→ chords.json
  ├──→ Rhythmist（并行 B）──→ bass.json + drums.json
  ↓
  Producer 审查（chords + bass + drums + melody 预检）
  ↓ [有问题则打回对应 Agent 修复，最多 2 次重试]
  ↓
  Composer（串行，依赖 Harmonist）
  ↓ melody.json
  ↓
  Producer 审查（melody vs chords 对齐 + 动机/衔接检查）
  ↓ [有问题则打回 Composer 修复，最多 2 次重试]
  ↓
  Orchestrator（串行，依赖全部）
  ↓ expression_plan.json → generate_expression.py → expression.json
  ↓
  Producer 最终审查（全部轨道整合 + validate_clef.py）
  ↓ 合并为 final.json + 自评 + 输出
```

### 交接点审查

| 审查点 | 检查内容 | 打回条件 | 最多重试 |
|--------|---------|---------|---------|
| #1 基础审查 | 声部进行合理性、低音与根音一致性、节奏密度符合风格、旋律与和弦音基本对齐 | 和弦排列有平行五八度、低音偏离 bass_rule | 2 次 |
| #2 最终审查 | 频率平衡、力度分层、整体连贯性、validate_clef.py 0 errors | 伴奏层 velocity 超限、验证脚本报错 | 2 次 |

**合并说明：** 审查 #1 和原设计的 #2 合并为一次，减少 Producer 审查次数（从 3 次降为 2 次）。基础审查合并了和弦+节奏+旋律的对齐检查，避免过度的串行等待。理由：单独审查旋律时，如果 chords 有问题需要先修复，合并后可以一次性指出所有基础问题。

### 依赖关系

1. Harmonist 和 Rhythmist **可以并行** — Rhythmist 基于 plan.json 中的和弦进行，不依赖 Harmonist 的具体音符
2. Composer **必须等 Harmonist** — 旋律需要基于具体的和弦音符（不只是和弦名）
3. Orchestrator **必须等全部** — 表现力层需要配合所有轨道
4. Producer 前后各出现一次 — 开头规划，结尾整合

## Agent 通信

### 文件系统通信

所有 Agent 通过 `.clef-work/` 目录中的文件通信，不依赖对话。

**共享上下文（所有 Agent 读取）：**
- `plan.json` — 整体规划（Producer 写入）
- `style_profile.json` — 风格参考特征（Producer 写入，如有 --ref）
- `theory.md` — 乐理知识（预置）

**专业产出（Agent 间传递）：**
- `chords.json` — Harmonist 写入，Composer + Orchestrator 读取
- `bass.json` — Rhythmist 写入，Orchestrator 读取
- `drums.json` — Rhythmist 写入，Orchestrator 读取
- `melody.json` — Composer 写入，Orchestrator 读取
- `expression_plan.json` — Orchestrator 写入（参数化表现力描述）
- `expression.json` — 脚本生成（Orchestrator 产出经脚本插值后的完整数据），Producer 读取

### 中间产物 JSON Schema

所有中间产物必须遵循 `templates/intermediate_schemas.json` 中定义的 Schema。该文件包含每个中间文件的：
- 必填字段及类型
- 值域约束（如 pitch 0-127, velocity 1-127）
- track/channel 分配规则（从 plan.json.orchestration 继承）
- 示例结构

**目的：** 确保 Agent 间文件格式一致，合并时不会因格式理解差异出错。

### Agent Prompt 模板

每个 Agent 定义在 `.claude/agents/clef-{role}.md`，格式为 YAML frontmatter + Markdown prompt。prompt 内容包含：
```
你是 {角色名}，一位专业的游戏音乐{职责描述}。

## 任务
{具体任务描述}

## 必读文件
- .clef-work/plan.json — 整体规划
- .claude/skills/clef-compose/theory.md — 乐理知识（重点关注：{相关章节}）
- .claude/skills/clef-compose/templates/intermediate_schemas.json — 中间文件格式规范
- {依赖文件} — 前置 Agent 的产出

## 输出
将结果保存到 .clef-work/{output_file}.json，严格遵循 intermediate_schemas.json 中的格式。

## 约束
- 严格遵循 plan.json 中的参数（调性、BPM、段落、力度范围）
- channel 和 instrument 必须从 plan.json.orchestration 中读取，不得自行指定
- 如有 style_profile.json，遵循风格约束
```

**各 Agent 的 `tools` 配置：**

| Agent | tools | 理由 |
|-------|-------|------|
| Harmonist | `Read, Write, Glob` | 只需读取 plan.json/theory.md，写入 chords.json |
| Composer | `Read, Write, Glob` | 需读取 chords.json（依赖），写入 melody.json |
| Rhythmist | `Read, Write, Glob` | 需读取 plan.json，写入 bass.json + drums.json |
| Orchestrator | `Read, Write, Glob, Bash` | 需运行 generate_expression.py 脚本 |

### 合并策略

Producer 最终合并时按以下规则组装 `final.json`：

1. **读取所有中间文件** — chords.json, bass.json, drums.json, melody.json, expression.json
2. **按 plan.json.orchestration 创建 tracks[]** — 每个轨道从 orchestration 获取 name/channel/instrument
3. **分配音符** — melody.json → melody track, bass.json → bass track, 依此类推
4. **分配 CC 事件** — expression.json 中的 CC/pb 事件按 track name 关联到对应轨道
5. **合并 velocity** — expression.json 中的 velocity_offset 应用到对应音符的 velocity 上
6. **写入 final.json** — 组装为完整 Clef JSON v2.0 格式

### style_profile.json 传递

| Agent | 是否读取 style_profile.json | 关注内容 |
|-------|--------------------------|---------|
| Harmonist | 是 | 调性、和弦进行、声部排列风格 |
| Composer | 是 | 旋律特征（characteristics, rhythm_density） |
| Rhythmist | 是 | 打击乐风格（percussion_style）、节奏密度 |
| Orchestrator | 是 | 表现力特征（expression_features）、dynamics_curve |

## 反馈迭代与局部修复

用户反馈后，Producer 判断需要唤醒哪些 Agent，只重新派发任务给相关 Agent，未涉及的 Agent 产出保持不变。

### 单 Agent 反馈 → 多 Agent 反馈映射

| 用户反馈 | 单 Agent 修改 | 多 Agent 唤醒 |
|---------|-------------|-------------|
| 旋律太单调了 | Step 3 修改 | Composer |
| 和弦不够紧张 | Step 2 修改 | Harmonist → Composer（和弦变了旋律需调整） |
| 节奏感再强一点 | Step 5 修改 | Rhythmist |
| 低音不够明显 | Step 4 修改 | Rhythmist |
| 表现力不够丰富 | Step 6 修改 | Orchestrator |
| 配器太满/太吵 | Step 6 修改 | Orchestrator |
| 更史诗/壮阔 | 多步骤修改 | Harmonist + Orchestrator（增加乐器+改配器+改力度） |
| 更接近参考曲 | 重新规划 | Producer → 重新跑全部 |

**跨 Agent 反馈协调：** 当反馈需要唤醒多个 Agent 时，Producer 按依赖顺序派发（先 Harmonist，等完成后再派发 Orchestrator），避免并行修改产生冲突。

## 并行协调规则

### 低音与和弦的根音一致性

Harmonist 和 Rhythmist 并行执行时，低音可能和弦声部的根音不一致（如 Harmonist 用第一转位 Dm/F，但 Rhythmist 低音选了 D）。

**解决方案：** Producer 在 plan.json 中明确低音规则，两边同时遵守：

```json
{
  "bass_rule": "root_position"
}
```

| bass_rule | 含义 | Harmonist 约束 | Rhythmist 约束 |
|-----------|------|---------------|---------------|
| `root_position`（默认） | 低音始终走根音 | 在根音之上构建声部，不使用需要非根音低音的转位 | 每个和弦低音取根音 pitch |
| `follow_chord_tone` | 低音跟随指定和弦音 | 按标注的转位构建声部 | 按和弦标注取低音（如 Dm/F → F） |

当 `follow_chord_tone` 时，Producer 在 `chord_progression` 中标注转位：`["Dm", "C", "Bb/F", "A"]`。

## 表现力层：参数化生成方案

### 统一方案（单 Agent + 多 Agent 共用）

参数化生成方案同时应用于单 Agent 模式和多 Agent 模式，避免两套并行的表现力逻辑：
- **单 Agent 模式：** Step 6 改为输出 expression_plan.json → 运行 generate_expression.py → 得到 expression.json
- **多 Agent 模式：** Orchestrator 输出 expression_plan.json → 运行 generate_expression.py → 得到 expression.json

**Orchestrator 输出示例（expression_plan.json）：**

```json
{
  "expression_plan": [
    {
      "track": "Melody",
      "cc7": 100,
      "cc11": [
        {"section": "A", "start_val": 60, "end_val": 80, "curve": "linear"},
        {"section": "B", "start_val": 80, "end_val": 120, "curve": "ease_in_out"}
      ],
      "pitch_bend": [
        {"beat": 7.75, "target": 12288, "return_at": 8.25, "description": "上行装饰滑音"}
      ],
      "velocity_offset": [
        {"section": "A", "offset": 0},
        {"section": "B", "offset": 15}
      ]
    }
  ]
}
```

**Python 脚本（`scripts/generate_expression.py`）处理：**

```
输入：
  - expression_plan.json（参数化描述）
  - plan.json（段落 beat 范围，用于解析 section 字段）
  - melody.json / bass.json / drums.json / chords.json（按 track name 读取音符数据）

处理：
  → 解析 section → beat 范围（从 plan.json 获取）
  → 按 curve 类型插值生成 CC11 事件（每 0.5 拍一个采样点）
  → 按 pitch_bend 描述生成成对的弯音事件（弯上去 → 回中 8192）
  → 按 velocity_offset 修改各轨道音符的 velocity
  → 按 track name 将 CC/pb 事件关联到对应轨道

输出：
  - expression.json — 按 track 分组的完整 CC/pb/velocity 数据
```

**支持四种曲线类型：**

| curve | 公式 | 效果 | 适用场景 |
|-------|------|------|----------|
| `linear` | 匀速插值 | 平滑直线变化 | 一般渐强渐弱 |
| `ease_in` | 二次缓入 | 慢起快收 | 渐强（accelerando） |
| `ease_out` | 二次缓出 | 快起慢收 | 渐弱（ritardando） |
| `ease_in_out` | 三次缓入缓出 | S 形曲线 | 段落高潮过渡 |

**脚本依赖：** Python 标准库（json, math），无第三方依赖。Windows/macOS/Linux 兼容。

## 错误处理与失败恢复

### Agent 产出无效 JSON

- Producer 在读取子 Agent 产出后，用 Python 快速验证 JSON 格式（`json.loads()`）
- 如果格式无效，Producer 将错误信息反馈给对应 Agent，要求重新生成（最多 2 次）
- 连续 2 次格式无效时，Producer 终止该 Agent 并使用默认占位产出（空轨道），继续后续流程

### Agent 产出违反 plan.json 约束

- Producer 审查时检测：pitch 超出范围、velocity 超限、使用了 plan 中未指定的乐器等
- 打回对应 Agent 修复（最多 2 次）
- 连续 2 次仍违规时，Producer 降级处理（如 clamp 到允许范围）

### Python 脚本执行失败

- `generate_expression.py` 异常时，Producer 捕获错误并尝试修复常见问题（如缺少 section 定义）
- 无法自动修复时，Orchestrator 被要求重新生成 expression_plan.json
- 最终降级：跳过参数化生成，Orchestrator 直接生成简化的 expression.json（仅 CC7 + 少量 CC11）

### 打回次数上限

- 每个 Agent 最多被同一审查点打回 **2 次**
- 超过上限后 Producer 使用当前产出继续（降级策略）
- 总审查重试次数超过 **4 次**时，Producer 停止并报告用户

### 降级策略

如果多 Agent 模式因任何原因无法完成，Producer 自动降级为单 Agent 模式，重新生成。

## 文件状态管理

### 中间文件版本控制

- Agent 产出直接覆盖对应文件（不创建 v2 版本），简化流程
- Producer 在每次审查前保存当前状态的快照（可选，用于调试）

### `.clef-work/` 清理

- 每次 `--multi-agent` 执行开始时，Producer 清空 `.clef-work/` 目录下的旧中间文件
- 最终输出（final.json）和中间文件都保留供用户查阅

## 实现方式

### 文件结构

```
.claude/
├── agents/
│   ├── clef-harmonist.md             # Harmonist Agent 定义（model: sonnet）
│   ├── clef-composer.md              # Composer Agent 定义（model: opus）
│   ├── clef-rhythmist.md             # Rhythmist Agent 定义（model: haiku）
│   └── clef-orchestrator.md          # Orchestrator Agent 定义（model: sonnet）
└── skills/clef-compose/
    ├── SKILL.md                      # 主 Skill（含 Producer 逻辑 + 单/多模式分支）
    ├── theory.md                     # 乐理知识（不变）
    ├── scripts/
    │   ├── validate_clef.py          # 现有验证脚本
    │   └── generate_expression.py    # 新建 — 参数化表现力数据生成
    └── templates/
        ├── intermediate_schemas.json # 新建 — 中间产物 JSON Schema
        └── ...
```

**Agent 定义位置变更说明（v3）：** Agent 定义从 Skill 目录内的 `agents/` 移到 `.claude/agents/`。原因：Agent 工具通过 `subagent_type` 字段识别自定义 Agent，仅搜索 `.claude/agents/` 和 `~/.claude/agents/` 目录，不搜索 Skill 目录内的子目录。使用 `clef-` 前缀避免与其他 Agent 命名冲突。

### Agent 定义格式

每个 Agent 使用 YAML frontmatter + Markdown prompt：

```yaml
---
name: clef-harmonist
description: 游戏音乐和声编曲专家，负责和弦进行、声部排列、和弦外音设计
model: sonnet
tools: Read, Write, Glob
---

你是 Harmonist，一位专业的游戏音乐和声/编曲专家。

## 任务
根据 plan.json 生成和弦进行（chords.json）。

## 必读文件
- .clef-work/plan.json — 整体规划
- .claude/skills/clef-compose/theory.md — 乐理知识（重点关注：和弦进行、声部排列、和弦外音）
- .claude/skills/clef-compose/templates/intermediate_schemas.json — 中间文件格式规范

## 输出
将结果保存到 .clef-work/chords.json，严格遵循 intermediate_schemas.json 中的格式。

## 约束
- channel 和 instrument 必须从 plan.json.orchestration 中读取
- 如有 .clef-work/style_profile.json，遵循风格约束
- bass_rule 从 plan.json 读取，确保声部排列与低音一致
```

**SKILL.md 中调用方式：**

```
使用 Agent 工具生成 Harmonist（subagent_type: "clef-harmonist"），
要求其读取 .clef-work/plan.json 并生成 chords.json。
```

### 需要修改/新建的文件

| 文件 | 位置 | 变更类型 |
|------|------|---------|
| `SKILL.md` | `.claude/skills/clef-compose/` | 修改 — 新增 `--multi-agent` 模式工作流分支 |
| `clef-harmonist.md` | `.claude/agents/` | 新建 |
| `clef-composer.md` | `.claude/agents/` | 新建 |
| `clef-rhythmist.md` | `.claude/agents/` | 新建 |
| `clef-orchestrator.md` | `.claude/agents/` | 新建 |
| `intermediate_schemas.json` | `.claude/skills/clef-compose/templates/` | 新建 — 中间产物 JSON Schema |
| `generate_expression.py` | `.claude/skills/clef-compose/scripts/` | 新建 — 参数化表现力数据生成脚本 |
| `theory.md` | `.claude/skills/clef-compose/` | 不变 |

## 不在范围内

- Agent 之间直接对话（通过文件通信已足够）
- 动态调整 Agent 数量（5 个角色固定）
- Agent 自主决定重新生成（由 Producer 统一控制）
- Phase 4（风格迁移/模板库）
- 自定义 Agent 角色

## 技术约束

| 约束 | 应对 |
|------|------|
| 子 Agent 不能再生成子 Agent | Producer 必须是主会话（Skill 自身），不能委托给子 Agent |
| 子 Agent 共享同一 working directory | 通过 `.clef-work/` 文件通信，天然支持 |
| 子 Agent 上下文窗口独立 | 每个 Agent 只读必要文件，不需要完整 Skill 上下文 |
| 并行 Agent 数量限制 | Harmonist + Rhythmist 仅 2 个并行，其余串行 |
| theory.md 多次读取开销 | 每个 Agent prompt 中指明重点章节，子 Agent 自行 Read |
| `context: fork` 不可靠 | 不使用，Skill 在主会话中通过 Agent 工具手动生成子 Agent |
| Agent 定义位置 | 放在 `.claude/agents/` 目录，使用 `clef-` 前缀 |
| Python 脚本运行环境 | 仅使用标准库，无第三方依赖；Windows/macOS/Linux 兼容 |

## 验证方案

### Phase A：前置验证 — 已通过技术调研 ✅

原计划写最小原型验证 Agent 工具可行性，现通过官方文档和社区实践确认：
1. Skill 中通过 Agent 工具生成子 Agent — ✅ 可行（`/batch`、`/simplify` 先例）
2. 子 Agent 读写 `.clef-work/` 文件 — ✅ 可行（共享文件系统）
3. 并行执行 — ✅ 可行（单条消息多个 Agent 调用）
4. 自定义 Agent 定义 — ✅ 可行（`.claude/agents/*.md` + `subagent_type` 引用）

跳过原型验证，直接进入实现。

### Phase B：集成验证（实现后）
1. 对比测试：同一需求分别用单 Agent 和多 Agent 生成，比较质量
2. 局部修复测试：反馈"旋律太单调"，确认只唤醒 Composer
3. 并行效率测试：对比总执行时间
4. 回归测试：不加 `--multi-agent` 时，确认现有流程零影响
5. 降级测试：人为模拟 Agent 失败，确认能降级到单 Agent 模式
6. Schema 验证：各 Agent 产出格式符合 intermediate_schemas.json

---

## 附录：技术调研记录（2026-03-26）

### 调研范围

Claude Code 的 Agent 工具、自定义 Agent 定义、Agent Teams、Skill 集成、并行执行等功能的官方文档和社区实践。

### 关键发现

**1. Agent 工具（Subagent 模式）**

- 子 Agent 在独立上下文窗口中运行，与父会话共享文件系统
- 支持前台（阻塞等待结果）和后台（并发执行）两种模式
- 单条消息中同时生成多个 Agent 工具调用 = 并行执行
- 子 Agent 不能再生成子 Agent（硬限制，防止无限递归）
- 子 Agent 返回结果给父会话，或通过文件系统间接传递

**2. 自定义 Agent 定义**

- 位置：`.claude/agents/*.md`（项目级）或 `~/.claude/agents/*.md`（用户级）
- 格式：YAML frontmatter + Markdown prompt
- 关键字段：`name`, `description`, `model`（sonnet/opus/haiku）, `tools`, `skills`
- 通过 Agent 工具的 `subagent_type` 字段引用
- `tools` 白名单可限制 Agent 只能使用特定工具

**3. Skill 集成**

- Skill（SKILL.md）运行在主会话中，可在指令中包含 "使用 Agent 工具生成子 Agent"
- 已有先例：`/batch`（并行 worktree agent）、`/simplify`（并行 review agent）
- `context: fork` + `agent:` frontmatter 有已知 Bug [#17283](https://github.com/anthropics/claude-code/issues/17283)，不可靠
- Agent 定义的 `skills` 字段可预加载 Skill 内容到子 Agent 上下文（全量注入）

**4. Agent Teams（不采用）**

- 实验性功能（需 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`）
- 每个 teammate 是独立 Claude Code 实例，有独立上下文窗口
- 支持队友间直接消息（SendMessage）和共享任务列表
- 不支持会话恢复、不支持嵌套团队
- 对当前场景过于复杂，Subagent 模式更简单可控

### 参考来源

- [Claude Code 官方文档 - Subagents](https://code.claude.com/docs/en/sub-agents)
- [Claude Code 官方文档 - Skills](https://code.claude.com/docs/en/skills)
- [Claude Code 官方文档 - Agent Teams](https://code.claude.com/docs/en/agent-teams)
- [GitHub Issue #17283 - context: fork not honored](https://github.com/anthropics/claude-code/issues/17283)
- [Claude Agent SDK - Subagents](https://platform.claude.com/docs/en/agent-sdk/subagents)
- [Claude Code Customization Guide - alexop.dev](https://alexop.dev/posts/claude-code-customization-guide-claudemd-skills-subagents/)
