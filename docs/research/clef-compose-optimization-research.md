# Clef-Compose 工作流优化研究报告

**研究日期：** 2026-03-27
**分析对象：** 4 篇 AI 音乐创作系统论文 × clef-compose 现有工作流
**目标：** 提取可借鉴的方法论，提出具体优化方向

---

## 一、四篇论文核心方法论摘要

| 系统 | 机构 | 核心创新 | 与 clef-compose 的关联度 |
|------|------|---------|----------------------|
| **Amuse** (CHI 2025 最佳论文) | KAIST/CMU | 多模态（图像/文本/音频）→ 和弦进行的跨模态语义映射 | ⭐⭐⭐ 和弦生成 + 用户意图理解 |
| **CoComposer** (arXiv 2025) | 莱顿大学 | 5 Agent 协作（Leader/Melody/Accompaniment/Revision/Review）+ 迭代优化 | ⭐⭐⭐⭐ Agent 架构 + 迭代机制 |
| **VibeMus** (MMAsia 2025) | 新加坡管理大学 | "氛围中心化" + 主动式双 Agent + 原子化编辑 | ⭐⭐⭐ 用户交互 + 编辑反馈 |
| **WeaveMuse** (LLM4MA 2025) | JKU | 多专家 Agent + 约束模式 + 结构化解码 + 自验证 | ⭐⭐⭐ Agent 自验证 + 约束生成 |

---

## 二、可直接借鉴的改进点

### 2.1 迭代改进机制（来源：CoComposer）— 优先级：高

**现状：** clef-compose 的自评（Step 8）在总分 < 7.5 时最多迭代 3 轮，但迭代是"全量重写"而非"定向修复"。CoComposer 的双阶段流程（初始化 + 迭代）提供了更精细的思路。

**可借鉴：**
- CoComposer 的 **Review Agent 五维评审**（旋律结构、和声、节奏、配器、曲式）与 clef-compose 现有 5 维度自评高度重叠，但 CoComposer 的关键优势是**评审反馈被结构化为可执行的修改指令**
- CoComposer 的 **Revision Agent**（纯技术修订，不改创意）与 **Review Agent**（纯音乐理论评审）职责分离 — clef-compose 目前没有这个分离

**具体改进：**
1. 将 Reviewer Agent 拆分为**音乐评审**（现有）和**技术修订**（新增）两个角色
2. 技术修订 Agent 负责检查：JSON 格式合规、小节拍数平衡、velocity 范围越界、CC 事件冲突等技术性问题
3. 迭代时先执行技术修订（确保格式正确），再执行音乐评审（提升艺术质量）

### 2.2 原子化编辑操作（来源：VibeMus）— 优先级：高

**现状：** 用户反馈（如"再紧张一点"）通过反馈映射表触发**全轨道修改**，粒度较粗。VibeMus 的"原子化编辑"概念可以显著改善这个流程。

**可借鉴：**
- VibeMus 支持用户对生成的歌曲进行**细粒度的局部修改**，如"把副歌部分的节奏加快""将人声音调高半个 key"
- 这种"手术刀式"修改比"全量重写"效率更高，也更符合音乐制作实际

**具体改进：**
1. 扩展用户反馈处理，支持**段落级 + 轨道级**的定向修改：
   - "B 段旋律再紧张一点" → 仅重写 B 段旋律
   - "低音线在 C 段更活跃" → 仅修改 C 段 bass.json
2. 在多 Agent 模式的反馈处理表中，增加原子化编辑的触发规则
3. 实现方法：指定 `section_id` + `track_role` 作为修改范围，其余部分保持不变

### 2.3 Agent 自验证机制（来源：WeaveMuse）— 优先级：中高

**现状：** clef-compose 的验证集中在两个阶段：(1) validate_clef.py 做格式验证，(2) Reviewer 做音乐质量审核。但每个 Agent 自身没有"自验证"步骤。

**可借鉴：**
- WeaveMuse 的每个专家 Agent 具备**自我验证（Self-Validation）**能力 — Agent 输出后自行检查质量
- 这是一种"前置质量门"模式，在输出传递给下游 Agent 之前就捕获问题

**具体改进：**
1. 为每个 Agent 添加**自检清单**（内置在 Agent prompt 中）：
   - Composer：动机是否明确？是否有 ≥2 种发展手法？乐句衔接是否流畅？
   - Harmonist：声部进行是否平滑？和弦排列是否符合 Open/Close 规则？
   - Rhythmist：是否有 ≥3 种 duration？段落间节奏是否有变化？
   - Orchestrator：CC7 是否使用了固定值？velocity 层次是否正确？
2. Agent 输出文件后，在返回前执行自检，发现问题则立即修复

### 2.4 主动式需求引导（来源：VibeMus）— 优先级：中

**现状：** MA-Step 0 的交互式需求收集是**顺序问答**，用户需要逐项回答。VibeMus 的"主动式智能体"理念可以优化这个过程。

**可借鉴：**
- VibeMus 的界面对话智能体通过**多轮对话**逐步引导用户表达模糊的音乐期望
- 智能体能够**主动探询**（而非被动等待），帮助用户深入挖掘创作意图

**具体改进：**
1. MA-Step 0 从"填表式"改为**对话式**：根据用户的初始描述，智能推断缺失信息，只问真正需要确认的
2. 支持"模糊输入"：用户说"想要一个像最终幻想那种感觉的 Boss 战曲"时，系统自动推断：
   - 风格 → 管弦史诗
   - 情绪 → 激昂/史诗
   - 配器 → Strings + Brass + Choir
   - 仅向用户确认推断结果

### 2.5 和弦流畅性评估模块（来源：Amuse）— 优先级：中

**现状：** Harmonist 的和弦生成依赖 theory.md 中的和弦进行库和声部进行规则，但缺乏一个独立的"流畅性评估"环节。Amuse 的和弦流畅性评估模块提供了参考。

**可借鉴：**
- Amuse 集成了一个**基于音乐理论的和弦流畅性评估模块**，能评估和弦序列的合理性和流畅度
- 评估维度：和弦根音运动（级进 vs 跳进）、和声功能（T/S/D）是否合理、紧张度变化曲线

**具体改进：**
1. 在 Harmonist 输出 chords.json 后，增加一个**和声流畅性评分**步骤（可内嵌在 Reviewer 中）
2. 评分维度：
   - 根音运动流畅度（级进优先）
   - 和声功能逻辑（T→S→D→T 的合理走向）
   - 紧张度曲线（是否在段落结尾有解决感）
3. 评分不达标时，Harmonist 优先调整和弦进行而非直接重写

---

## 三、架构层面优化方向

### 3.1 Agent 数量与分工优化（来源：CoComposer + WeaveMuse）

**现状：** clef-compose 多 Agent 模式使用 4 个 Agent（Composer/Harmonist/Rhythmist/Orchestrator）+ 1 个 Reviewer，共 5 个角色。

**对比分析：**

| 系统 | Agent 数量 | 分工模式 | 优势 |
|------|-----------|---------|------|
| CoComposer | 5 | Leader/Melody/Accompaniment/Revision/Review | 流程清晰，Revision 专注技术 |
| WeaveMuse | 3（1 Manager + N Specialist） | 管理者 + 按需专家 | 灵活，可扩展 |
| clef-compose | 5 | Composer/Harmonist/Rhythmist/Orchestrator/Reviewer | 音乐专业分工 |

**结论：** 当前 5 Agent 的分工是合理的，不需要大幅调整。但可以借鉴 CoComposer 拆分 Revision Agent 的思路。

### 3.2 约束模式（Constraint Schemas）（来源：WeaveMuse）— 优先级：中低

**现状：** clef-compose 通过 Agent prompt 中的"硬性约束"和 validate_clef.py 来控制生成质量。WeaveMuse 的"约束模式"是一种更系统化的方法。

**可借鉴：**
- WeaveMuse 使用 **Constraint Schemas** 定义生成规则和边界条件
- **Structured Decoding** 确保输出符合预定格式
- 这些约束可以**动态组合**，根据不同风格/场景调整

**具体改进（长期）：**
1. 将各 Agent 的约束规则提取为独立的 JSON Schema 文件（类似 validation_rules.json 但面向生成过程）
2. 根据风格/场景动态组合约束集（如"战斗音乐约束集"vs"村庄音乐约束集"）
3. 短期可以先在 theory.md 中按风格分类组织约束

### 3.3 记忆机制（来源：CoComposer）— 优先级：低

**现状：** clef-compose 的 style_profile.json 是单次会话内的风格参考，不跨会话持久化。

**可借鉴：**
- CoComposer 提出**引入记忆机制**，记录用户跨多轮创作的偏好模式
- 如识别用户对弦乐器音色的偏好或紧凑节奏型的偏好

**具体改进（长期）：**
1. 在 `.claude/projects/` 的 memory 系统中记录用户的音乐偏好
2. 下次 `/clef-compose` 时自动读取偏好，减少需求收集步骤

---

## 四、按优先级排序的优化路线图

### P0 — 立即可做（改 prompt 即可）

| 编号 | 改进项 | 来源 | 工作量 | 影响 |
|------|--------|------|--------|------|
| O1 | Agent 自检清单嵌入 prompt | WeaveMuse | 小（改 4 个 Agent .md） | 减少下游错误传递 |
| O2 | 原子化编辑反馈表扩展 | VibeMus | 小（改 Skill prompt） | 提升用户修改体验 |
| O3 | 和声流畅性评审加入 Reviewer | Amuse | 小（改 Reviewer + checklist） | 提升和弦质量 |

### P1 — 短期可做（需少量代码/脚本）

| 编号 | 改进项 | 来源 | 工作量 | 影响 |
|------|--------|------|--------|------|
| O4 | 拆分 Revision Agent（技术修订） | CoComposer | 中（新建 Agent + 改流程） | 迭代效率提升 |
| O5 | MA-Step 0 改为推断式需求收集 | VibeMus | 中（改 Skill prompt） | 减少用户输入负担 |
| O6 | 自评迭代改为"定向修复"而非"全量重写" | CoComposer | 中（改 Step 8 逻辑） | 迭代效率提升 |

### P2 — 中期规划（需设计新机制）

| 编号 | 改进项 | 来源 | 工作量 | 影响 |
|------|--------|------|--------|------|
| O7 | 约束模式 JSON Schema 化 | WeaveMuse | 大 | 生成质量系统化提升 |
| O8 | 用户偏好记忆机制 | CoComposer | 大 | 个性化体验 |
| O9 | 跨模态灵感输入（图像→和弦） | Amuse | 很大（需新模型集成） | 创意来源拓展 |

---

## 五、各论文对 clef-compose 各环节的具体影响分析

### 5.1 Step 0 需求解析

| 论文贡献 | 影响 |
|---------|------|
| VibeMus "氛围中心化" — 用户表达模糊意图时，系统主动探询深层期望 | 可优化 MA-Step 0 的交互方式 |
| VibeMus 多轮对话 — 逐步细化模糊需求 | 可支持"先给个大概方向，再逐步调整" |

### 5.2 Step 1 音乐规划

| 论文贡献 | 影响 |
|---------|------|
| CoComposer Leader Agent 的任务分解能力 — 将复杂创作需求分解为可执行子任务 | 可借鉴任务分解思路，让 plan.json 更细粒度 |
| WeaveMuse 约束模式 — 根据场景动态组合生成约束 | 可为不同场景预定义约束集 |

### 5.3 Step 2 和弦骨架

| 论文贡献 | 影响 |
|---------|------|
| Amuse 和弦流畅性评估 — 评估和弦序列的合理性和流畅度 | 可增加和弦质量门控 |
| Amuse 对比学习 — 从高质量和弦库中检索匹配进行 | 可扩展 theory.md 的和弦进行库 |

### 5.4 Step 3 旋律生成

| 论文贡献 | 影响 |
|---------|------|
| CoComposer 旋律 Agent 独立创作 + 迭代优化 | 当前已实现，可优化迭代策略 |
| VibeMus 原子化编辑 — 对旋律局部修改 | 可支持"只改 B 段副歌" |

### 5.5 Step 6 表现力层

| 论文贡献 | 影响 |
|---------|------|
| Amuse 多模态语义映射 — 理解不同灵感形式的情感语义 | 长期可支持"用图像描述想要的力度曲线" |
| WeaveMuse 自验证 — Agent 自检输出质量 | Orchestrator 可增加自检步骤 |

### 5.6 Step 7-8 验证与自评

| 论文贡献 | 影响 |
|---------|------|
| CoComposer Revision Agent — 技术修订与音乐评审分离 | **高价值改进**：拆分技术检查和音乐评审 |
| CoComposer 五维评审与迭代优化 | 当前已有，可优化迭代策略 |
| WeaveMuse 自验证 — 每个输出自带质量检查 | 可在各 Agent 输出后增加前置验证 |

---

## 六、结论

四篇论文中，**CoComposer** 对 clef-compose 的借鉴价值最高（Agent 架构 + 迭代机制高度对齐），**VibeMus** 在用户交互和编辑体验上有重要参考价值，**Amuse** 在和弦质量评估方面有独到之处，**WeaveMuse** 在约束生成和自验证方面提供了系统化思路。

建议优先实施 P0 级别的 3 项改进（Agent 自检、原子化编辑、和声评审），这些改动仅涉及 prompt 调整，风险低、见效快。P1 级别的改进可作为下一阶段的工作重点。

---

## 参考来源

| 编号 | 论文 | 来源 |
|------|------|------|
| [1] | Amuse: Human-AI Collaborative Songwriting with Multimodal Inspirations | CHI 2025 最佳论文, arXiv:2412.18940 |
| [2] | CoComposer: Multi-Agent Collaborative Music Composition with LLMs | arXiv:2509.00132 |
| [3] | VibeMus: Proactive Agentic System for Music Personalization | MMAsia '25, DOI:10.1145/3743093.3771663 |
| [4] | WeaveMuse: An Open Agentic System for Multimodal Music Understanding and Generation | LLM4MA Workshop 2025, arXiv:2509.11183 |
