# Clef-Compose Agent 质量门控与原子化编辑 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 提升 clef-compose 多 Agent 工作流的产出品质，通过 Agent 自验证、原子化编辑、和声评审增强三大 P0 改进。

**Architecture:** 纯 prompt 层面优化 — 修改 5 个 Agent `.md` 文件和 1 个 Skill prompt 文件。不改任何 Python 脚本或 GDScript。每个 Agent 输出后增加内置自检清单；用户反馈处理支持段落+轨道级定向修改；Reviewer 增加和声流畅性评审维度。

**Tech Stack:** Markdown prompt files (`.claude/agents/*.md`, `.claude/skills/clef-compose/SKILL.md`)

**Research basis:** `docs/research/clef-compose-optimization-research.md` — O1/O2/O3 三项 P0 改进

---

## Task 1: Composer Agent 自检清单

**Files:**
- Modify: `.claude/agents/clef-composer.md`

**Why:** Composer 是最核心的创意输出，但目前输出后没有自验证。借鉴 WeaveMuse 的 Agent 自验证机制，在输出前捕获常见问题（大跳未处理、动机不明确、段落过渡跳音区等）。

**Step 1: 在 clef-composer.md 的"约束"章节后添加"自检清单"章节**

在文件末尾（`## 打样模式` 之前）插入：

```markdown
## 自检清单（输出前必须执行）

在保存 melody.jianpu 之前，逐项检查：

1. **动机辨识度** — 第 1-4 小节是否有 2-4 音符的核心动机？动机是否在后续段落中至少出现 1 次（重复/变奏/模进）？
2. **大跳处理** — 扫描所有相邻音符，音程 > 5 半音时是否有经过音？段落开头允许 1 个大跳但必须立即级进收回。
3. **段落过渡** — A→B、B→C 等段落切换处，音区变化是否 ≤ 3 半音？是否通过级进逐步过渡？
4. **乐句衔接** — 是否存在 3 个以上连续乐句都以强拍和弦音终止？如果是，至少将其中 2 个改为弱起或经过音连接。
5. **节奏多样性** — 是否至少使用了 3 种不同的时值？是否不存在连续 4 个小节使用完全相同节奏型的情况？
6. **高潮位置** — 最高音是否出现在 B 段或 C 段？是否配合了力度标记？
7. **简谱格式** — 头部是否包含调号/拍号/BPM？小节线 | 是否正确？附点音符小节拍数是否平衡？

**如果任何检查项不通过，修复后再保存。不要输出自检报告，直接修复。**
```

**Step 2: 验证修改**

打开 `.claude/agents/clef-composer.md`，确认：
- "自检清单"章节出现在"约束"之后、"打样模式"之前
- 7 项检查内容完整

**Step 3: Commit**

```bash
git add .claude/agents/clef-composer.md
git commit -m "feat(clef): add self-check checklist to Composer agent"
```

---

## Task 2: Harmonist Agent 自检清单

**Files:**
- Modify: `.claude/agents/clef-harmonist.md`

**Why:** Harmonist 的和弦输出直接影响旋律质量。自检可捕获声部进行错误、排列法混用、音域越界等问题。

**Step 1: 在 clef-harmonist.md 的"约束"章节后添加"自检清单"章节**

在文件末尾插入：

```markdown
## 自检清单（输出前必须执行）

在保存 chords.json 之前，逐项检查：

1. **声部进行** — 相邻和弦的共同音是否保持不动？非共同音是否级进移动（±1-2 半音）？如果存在跳进 > 3 半音的非共同音，检查是否有音乐上的合理性。
2. **排列法** — 如果同时有 Brass 和 Strings 演奏和弦，Brass 是否使用开放排列（ soprano-alto 间距 > 4 半音），Strings 是否使用密集排列？
3. **音域** — 所有和弦音是否在 C3(48)-B4(71) 范围内？低音区 C2-B2 是否没有密集和弦？
4. **和声节奏** — 是否存在连续每 0.25 拍换和弦的情况？正常应每 1-2 拍换一个和弦。
5. **velocity 范围** — 伴奏层 velocity 是否全部在 60-90 范围内？
6. **notes 非空** — 每个 section 的 notes 数组是否都至少有 1 个音符？
7. **时值网格** — 所有音符的 start 和 duration 是否在 0.25 拍网格上？

**如果任何检查项不通过，修复后再保存。不要输出自检报告，直接修复。**
```

**Step 2: 验证修改**

打开 `.claude/agents/clef-harmonist.md`，确认 7 项检查内容完整。

**Step 3: Commit**

```bash
git add .claude/agents/clef-harmonist.md
git commit -m "feat(clef): add self-check checklist to Harmonist agent"
```

---

## Task 3: Rhythmist Agent 自检清单

**Files:**
- Modify: `.claude/agents/clef-rhythmist.md`

**Why:** Rhythmist 使用 haiku 模型（最轻量），自检尤为重要，可补偿模型能力差距。

**Step 1: 在 clef-rhythmist.md 的"鼓组约束"章节后添加"自检清单"章节**

在文件末尾插入：

```markdown
## 自检清单（输出前必须执行）

在保存 bass.json 和 drums.json 之前，逐项检查：

### 低音线检查
1. **节奏多样性** — 全曲是否使用了至少 3 种不同的 duration 值？如果所有音符使用同一个 duration，必须修改。
2. **段落变化** — 段落后半段或高潮段落是否切换了节奏型？不能从头到尾同一节奏。
3. **音域** — 所有低音 pitch 是否在 E2(40)-B2(59) 范围内？
4. **velocity** — 所有 velocity 是否 ≤ 100？建议 70-100，段落间是否有变化？
5. **和弦对齐** — 低音 pitch 是否与当前和弦的根音（root_position）或指定音（follow_chord_tone）对齐？

### 鼓组检查
6. **段落变化** — 各段落的鼓点模式是否不同（密度、模式、使用的鼓件）？
7. **过渡 fills** — 段落过渡处（最后 2-4 拍）是否有 fills（军鼓连打 + 底鼓加速）？
8. **力度范围** — 底鼓 100-120、军鼓 90-110、踩镲 70-90 是否遵守？
9. **notes 非空** — 两个文件的 notes 数组是否都至少有 1 个音符？
10. **时值网格** — 所有音符的 start 和 duration 是否在 0.25 拍网格上？

**如果任何检查项不通过，修复后再保存。不要输出自检报告，直接修复。**
```

**Step 2: 验证修改**

打开 `.claude/agents/clef-rhythmist.md`，确认低音线 5 项 + 鼓组 5 项 = 10 项检查内容完整。

**Step 3: Commit**

```bash
git add .claude/agents/clef-rhythmist.md
git commit -m "feat(clef): add self-check checklist to Rhythmist agent"
```

---

## Task 4: Orchestrator Agent 自检清单

**Files:**
- Modify: `.claude/agents/clef-orchestrator.md`

**Why:** Orchestrator 的 CC7 固定值和 velocity 层次是硬性约束，自检可防止最常见的错误。

**Step 1: 在 clef-orchestrator.md 的"力度分层"章节后添加"自检清单"章节**

在文件末尾插入：

```markdown
## 自检清单（输出前必须执行）

在保存 expression_plan.json 之前，逐项检查：

1. **CC7 固定值** — 每轨的 cc7 是否使用了规定的固定值（Melody=100, Brass=95, Drums=100, Bass=85, Strings=75, Choir/Pad=70）？不得自行调整。
2. **CC7 最低值** — 是否所有 cc7 值 ≥ 20？
3. **CC11 范围** — CC11 起始值是否在 60-80 范围？渐强目标 110-127？渐弱目标 50-70？
4. **Pitch Bend 成对** — 每个 pitch_bend 是否都有对应的 return（回中到 8192）？return_at 是否 > beat？
5. **Velocity Offset 层次** — 伴奏层（Strings, Choir）高潮时 offset 后 velocity 是否 ≤ 95？低音（Bass）高潮时是否 ≤ 100？
6. **轨道覆盖** — expression_plan 是否覆盖了所有活跃轨道（plan.json 中有 notes 的轨道）？
7. **Section 引用** — CC11 和 velocity_offset 使用的 section ID 是否与 plan.json 中的 section id 一致？

**如果任何检查项不通过，修复后再保存。不要输出自检报告，直接修复。**
```

**Step 2: 验证修改**

打开 `.claude/agents/clef-orchestrator.md`，确认 7 项检查内容完整。

**Step 3: Commit**

```bash
git add .claude/agents/clef-orchestrator.md
git commit -m "feat(clef): add self-check checklist to Orchestrator agent"
```

---

## Task 5: Reviewer 增加和声流畅性评审维度

**Files:**
- Modify: `.claude/agents/clef-reviewer.md`

**Why:** 借鉴 Amuse 的和弦流畅性评估模块，在 Reviewer 的 5 维度审核中增加和声流畅性检查。当前 Reviewer 的"维度 5：和声隐含"只检查强拍对齐，缺乏对和弦进行质量的系统性评估。

**Step 1: 扩展 Reviewer 的审核维度**

在 `.claude/agents/clef-reviewer.md` 中，将现有的"维度 5：和声隐含"替换为更完整的和声评审：

找到：
```markdown
### 维度 5：和声隐含（需要 chords.json）

| 检查项 | 检测方式 | 等级 |
|--------|---------|------|
| 强拍和弦对齐 | 每小节第 1 拍的音落在当前和弦构成音上 (WARN) | WARN |
```

替换为：
```markdown
### 维度 5：和声质量（需要 chords.json）

| 检查项 | 检测方式 | 等级 |
|--------|---------|------|
| 强拍和弦对齐 | 每小节第 1 拍的音落在当前和弦构成音上 (WARN) | WARN |
| 根音运动流畅度 | 相邻和弦根音以级进（±2 半音）为主，四五度跳进有功能理由 (WARN) | WARN |
| 和声功能逻辑 | 和弦进行遵循 T→S→D→T 的合理功能走向，不出现无理由的反功能进行 (WARN) | WARN |
| 紧张度解决 | 段落结尾是否有属→主或下属→主的解决感 (INFO) | INFO |
| 声部进行平滑度 | 相邻和弦的共同音保持，非共同音级进 (WARN) | WARN |
```

**Step 2: 验证修改**

打开 `.claude/agents/clef-reviewer.md`，确认：
- 维度 5 标题从"和声隐含"改为"和声质量"
- 5 项检查内容完整（原 1 项 + 新增 4 项）

**Step 3: Commit**

```bash
git add .claude/agents/clef-reviewer.md
git commit -m "feat(clef): enhance Reviewer with harmony fluency evaluation"
```

---

## Task 6: 原子化编辑 — 扩展用户反馈处理

**Files:**
- Modify: `.claude/skills/clef-compose/SKILL.md`

**Why:** 借鉴 VibeMus 的原子化编辑概念，让用户能指定"只改 B 段旋律"而非触发全轨道重写。

**Step 1: 在 SKILL.md 的"用户反馈处理"章节中扩展反馈映射表**

找到现有的反馈映射表（以 `| 用户反馈 | 具体修改策略 |` 开头的表格），在表格**之前**插入原子化编辑的说明段落：

```markdown
### 原子化编辑（段落 + 轨道级定向修改）

当用户反馈中同时包含**段落标识**和**轨道/元素类型**时，执行定向修改而非全量重写。

**支持的段落标识：** A段/B段/C段/引入段/发展段/高潮段/收束段（与 plan.json 中的 section id 对应）
**支持的轨道/元素类型：** 旋律/和弦/低音/鼓/表现力/配器

**解析规则：**
1. 从用户反馈中提取 `[段落]` 和 `[元素]` 关键词
2. 如果只提到段落（如"B 段再紧张一点"），默认修改旋律 + 和弦
3. 如果只提到元素（如"低音不够明显"），默认修改所有段落
4. 如果两者都提到（如"B 段旋律太单调"），仅修改指定段落的指定元素
5. 未匹配到段落/元素关键词时，回退到下方的全局反馈映射表

**修改流程（原子化）：**
1. 读取当前 final.json 或对应的中间文件
2. 仅修改目标段落（通过 start_beat/end_beat 范围筛选）的指定轨道
3. 保留其余段落和轨道不变
4. 重新运行 validate_clef.py + 自评（仅评审修改的维度）
5. 输出更新后的文件

**示例：**
- "B 段旋律太单调" → 仅重写 B 段 melody，其余不变
- "低音在 C 段更活跃" → 仅修改 C 段 bass.json，其余不变
- "高潮段表现力不够" → 仅重新生成 C 段 expression，其余不变
```

**Step 2: 在反馈映射表中增加原子化编辑示例行**

在现有反馈映射表的末尾追加以下行：

```markdown
| B段/X段 旋律... | 原子化：仅重写指定段落的旋律简谱，其余不变 |
| B段/X段 和弦... | 原子化：仅修改指定段落的和弦进行，需同步调整该段旋律 |
| B段/X段 低音... | 原子化：仅修改指定段落的 bass.json |
| B段/X段 鼓... | 原子化：仅修改指定段落的 drums.json |
| B段/X段 表现力... | 原子化：仅重新生成指定段落的 expression |
```

**Step 3: 验证修改**

打开 `.claude/skills/clef-compose/SKILL.md`，确认：
- "原子化编辑"说明段落出现在反馈映射表之前
- 反馈映射表末尾有 5 行原子化编辑示例

**Step 4: Commit**

```bash
git add .claude/skills/clef-compose/SKILL.md
git commit -m "feat(clef): add atomic editing support for section+track level feedback"
```

---

## Task 7: 更新多 Agent 反馈处理表

**Files:**
- Modify: `.claude/skills/clef-compose/SKILL.md`

**Why:** Task 6 添加了原子化编辑概念，需要同步更新多 Agent 模式的反馈处理表，让 Agent 调度也支持定向修改。

**Step 1: 在 SKILL.md 的"多 Agent 反馈处理"表格中增加原子化编辑行**

找到"多 Agent 反馈处理"章节中的表格（以 `| 用户反馈 | 唤醒的 Agent |` 开头），在表格末尾追加：

```markdown
| B段/X段旋律... | Composer（仅重写指定段落简谱）→ Reviewer（仅审核该段） |
| B段/X段和弦... | Harmonist（仅修改指定段落和弦）→ Composer（同步调整该段旋律）→ Reviewer |
| B段/X段低音... | Rhythmist（仅修改指定段落 bass.json） |
| B段/X段鼓... | Rhythmist（仅修改指定段落 drums.json） |
| B段/X段表现力... | Orchestrator（仅重新生成指定段落 expression） |
```

**Step 2: 验证修改**

确认多 Agent 反馈处理表末尾有 5 行原子化编辑触发规则。

**Step 3: Commit**

```bash
git add .claude/skills/clef-compose/SKILL.md
git commit -m "feat(clef): update multi-agent feedback table with atomic editing triggers"
```

---

## 完成后验证

所有 7 个 Task 完成后，执行一次端到端验证：

1. 确认 4 个 Agent `.md` 文件都包含"自检清单"章节
2. 确认 Reviewer 的维度 5 已扩展为"和声质量"（5 项检查）
3. 确认 SKILL.md 包含原子化编辑说明 + 反馈映射表扩展 + 多 Agent 反馈表扩展
4. 用 `/clef-compose --multi-agent` 运行一次完整作曲流程，观察：
   - 各 Agent 是否在输出前执行自检
   - 用户反馈是否支持段落级定向修改
   - Reviewer 是否输出和声流畅性评审
