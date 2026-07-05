# Clef Compose 多 Agent 模式改进 — 实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将多 Agent 工作流从"静默生产模式"重构为"交互式打样模式"，引入简谱先于 JSON 的旋律创作流程，添加用户确认点。

**Architecture:** 新增交互式需求收集（MA-Step 0）、两级打样（MA-Step 2a/2b）、简谱审核 Agent、简谱→JSON 确定性转换器。theory.md 扩充 5 个旋律知识章节为 Composer 和审核 Agent 提供理论基础。

**Tech Stack:** Python 3 标准库, argparse, JSON, UTF-8 简谱文本解析

**设计文档:** `docs/plans/2026-03-27-clef-multi-agent-redesign.md`

---

## 文件变更总览

| 文件 | 操作 | Phase |
|------|------|-------|
| `.claude/skills/clef-compose/theory.md` | 扩充 5 个新章节 | 1 |
| `.claude/skills/clef-compose/scripts/jianpu_parser.py` | **新建** 简谱解析器 | 2 |
| `.claude/skills/clef-compose/scripts/jianpu_to_json.py` | **新建** 简谱→JSON 转换器 | 3 |
| `.claude/agents/clef-composer.md` | 修改：输出简谱替代 JSON | 4 |
| `.claude/agents/clef-reviewer.md` | **新建** 简谱审核 Agent | 5 |
| `.claude/skills/clef-compose/SKILL.md` | 重写多 Agent 工作流（MA-Step 0-4） | 6 |
| `.claude/skills/clef-compose/templates/intermediate_schemas.json` | 新增 jianpu schema | 7 |

---

## Phase 1: theory.md 扩充（5 个新章节）

### Task 1.1: 新增「简谱记谱法」章节

**Files:**
- Modify: `.claude/skills/clef-compose/theory.md` (在 `## 音阶定义` 第 21 行之前插入新章节)
- Note: 新章节位于 theory.md 顶部（术语表之后、音阶定义之前），因为简谱是后续旋律知识的基础参考

**Step 1: 编写简谱记谱法章节**

在 theory.md 的 `## 音阶定义`（第 21 行）之前插入新章节。内容参考设计文档"简谱文本格式规范"部分，包含：

```markdown
## 简谱记谱法

### 基本符号

| 元素 | 写法 | 含义 |
|------|------|------|
| 基本音 | `1` `2` `3` `4` `5` `6` `7` | 音阶度数（对应 do re mi fa sol la si） |
| 升号 | `#4` `#5` | 升半音 |
| 降号 | `b3` `b7` | 降半音 |
| 高八度 | `1̇`（上方点，U+0307） | 高一个八度 |
| 低八度 | `1̣`（下方点，U+0323） | 低一个八度 |
| 休止 | `0` | 静默 |

### 时值标记

| 标记 | 写法 | 时值（4/4 拍） |
|------|------|---------------|
| 四分音符 | `1`（无标记） | 1 拍 |
| 八分音符 | `1̲`（下划线，U+0332） | 0.5 拍 |
| 十六分音符 | `1̲̲`（双下划线） | 0.25 拍 |
| 附点 | `1.` | 前值 ×1.5 |
| 延音 | `1 -`（横杠） | 持续到下一拍位 |

### 力度标记

| 标记 | velocity 范围 | 用途 |
|------|-------------|------|
| `(ff)` | 110-120 | 极强 |
| `(f)` | 100-110 | 强 |
| `(mf)` | 85-95 | 中强 |
| `(mp)` | 70-80 | 中弱 |
| `(p)` | 55-65 | 弱 |
| `(pp)` | 40-50 | 极弱 |

力度转换使用线性分配：段内第一个音符取范围下限，最后一个取上限，中间线性插值。

### 结构标记

| 标记 | 写法 | 含义 |
|------|------|------|
| 小节线 | `\|` | 拍号对应的位置 |
| 双小节线 | `\|\|` | 段落边界 |
| 段落标记 | `[A]` `[B]` | 段落 ID |

### 排版规范

1. 头部格式：`1=D  4/4  BPM=140`（调号、拍号、速度各一行）
2. 段落标题单独一行：`[A] 引入`
3. 力度标记单独一行，对齐到变化位置上方
4. 音符按拍位等宽对齐（每拍占固定宽度）
5. 小节线 `\|` 分隔，段落边界用 `\|\|`

### 完整示例

（包含一个简单旋律示例 + 一个含变音/八度变化的复杂示例）
```
1=D  4/4  BPM=140

[A] 引入
        (mp)
| 2   4   3 -  | 4   3   2 -  |
| 2   4   3   5 | 6   5   3 -  |

[B] 发展
        (f)
|| 5   6   7 -  | 1̇   7   5 -  |
| 5   6   7   1̇ | 2̇   1̇   6 -  |
```
```

**Step 2: 验证 theory.md 格式**

检查新章节的 markdown 格式正确，表格对齐，与现有章节风格一致。

**Step 3: Commit**

```
feat(clef): add jianpu notation reference chapter to theory.md
```

---

### Task 1.2: 新增「旋律写作技法」章节

**Files:**
- Modify: `.claude/skills/clef-compose/theory.md` (在 Task 1.1 章节之后插入)

**Step 1: 编写旋律写作技法章节**

内容参考设计文档"旋律写作技法"部分，包含：

- 动机定义与类型（短动机 2-3 音、长动机 4+ 音、节奏动机、音高动机）
- 动机发展 6 法（重复、变奏、模进、倒影、扩展、截断）
- 变奏技巧细化（装饰音变奏、节奏拉伸/压缩、音区移位、调式交替）
- 乐句构建（长度 2/4/8 小节、前句/后句关系、弱起技巧）
- 旋律建筑（音域布局、高潮位置 60-80% 黄金分割点、段落对比）
- 旋律与和弦配合（强拍和弦音、弱拍和弦外音、经过音/邻音/倚音）

从现有 `clef-composer.md` agent prompt 中提取约束，转化为理论描述（不是规则列表，是知识性描述）。

**Step 2: Commit**

```
feat(clef): add melody composition techniques chapter to theory.md
```

---

### Task 1.3: 新增「旋律音程指南」章节

**Files:**
- Modify: `.claude/skills/clef-compose/theory.md`

**Step 1: 编写旋律音程指南章节**

内容参考设计文档"旋律音程指南"部分，包含：

- 自然音程分类（极常用/常用/需谨慎/需特殊处理 4 级）
- 大跳处理规则（反向级进收回、不超过连续 2 次同向大跳、落在和弦音上）
- 增减音程（增二度回避、增四度解决方式）
- 音域约束（推荐 1.5 八度、高潮段可扩展到 2 八度）
- 度数与半音对应表（方便 Composer 在简谱中判断跳进幅度）

**Step 2: Commit**

```
feat(clef): add melody interval guide chapter to theory.md
```

---

### Task 1.4: 扩展「乐句结构」章节

**Files:**
- Modify: `.claude/skills/clef-compose/theory.md` (扩展现有 `## 歌曲形式参考` 中第 384-385 行的 2 行"乐句长度建议")
- Note: 现有 `### 终止式库`（第 106 行）保持不变，新乐句结构章节通过交叉引用指向它

**Step 1: 扩展乐句结构为完整章节**

将现有的 2 行"乐句长度建议"扩展为完整章节，内容参考设计文档"乐句结构"部分：

- 常见乐句长度（2/4/8 小节）
- 乐句关系类型（平行、对比、问答式）
- 乐句连接技巧（抢先进入、弱起、经过音连接、休止符呼吸）
- 终止式类型（正格、变格、半终止、阻碍终止 — 从现有终止式库迁移并扩展）
- 段落结构（二段式 AB、三段式 ABA、通谱体、回旋曲式）

**注意：** 现有 `### 终止式库`（第 106 行）保留，新章节引用它。

**Step 2: Commit**

```
feat(clef): expand phrase structure section in theory.md
```

---

### Task 1.5: 新增「风格旋律特征」章节

**Files:**
- Modify: `.claude/skills/clef-compose/theory.md` (在 `## 配器方案` 之后插入)

**Step 1: 编写风格旋律特征章节**

内容参考设计文档"风格旋律特征"部分，与现有配器方案表对齐。为 12 种风格各添加：

- 音域范围
- 常用音程
- 节奏特征
- 动机特征
- 代表性旋律模式示例（简谱格式）

涵盖风格：经典 JRPG 战斗、现代 JRPG 战斗、RPG Boss、8-bit/Chiptune、史诗管弦、暗黑/恐怖、悲伤/抒情、村庄/探索、主菜单、激昂/热血、宁静/和平、神秘/悬疑。

**Step 2: Commit**

```
feat(clef): add genre-specific melody characteristics to theory.md
```

---

## Phase 2: 简谱解析器

### Task 2.1: 创建 jianpu_parser.py 脚本

**Files:**
- Create: `.claude/skills/clef-compose/scripts/jianpu_parser.py`
- Reference: `.claude/skills/clef-compose/scripts/generate_expression.py` (CLI 模式、load_json、Windows UTF-8)

**Step 1: 编写脚本骨架和 CLI**

```python
"""Parse jianpu (numbered musical notation) text into structured data.

Usage:
  python jianpu_parser.py melody.jianpu [--output melody_parsed.json]
  python jianpu_parser.py melody.jianpu --validate
"""
import argparse
import io
import json
import sys
from dataclasses import dataclass, field, asdict
from pathlib import Path

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")
```

**Step 2: 定义数据结构**

```python
@dataclass
class JianpuNote:
    degree: int          # 1-7 (0 = rest)
    octave_offset: int   # -1 (low), 0 (middle), +1 (high)
    accidental: str      # "", "#", "b"
    duration: float      # in beats (0.25, 0.5, 1.0, 1.5, 2.0, ...)
    start_beat: float    # absolute position in beats

@dataclass
class JianpuSection:
    id: str              # "A", "B", etc.
    name: str            # "引入", "发展", etc.
    dynamics: str        # "mf", "f", "p", etc. (may be empty)
    start_beat: float
    notes: list[JianpuNote]

@dataclass
class JianpuScore:
    key: str             # "D"
    scale: str           # implied from key
    time_signature: str  # "4/4"
    bpm: int
    sections: list[JianpuSection]
    total_beats: float
```

**Step 3: 实现解析器核心**

解析流程：
1. 解析头部行（`1=D  4/4  BPM=140`）
2. 逐行解析：段落标记行 `[A] 名称`、力度行 `(mf)`、音符行
3. 音符行解析：逐字符识别度数、升降号、八度点、时值下划线、附点、延音线、休止符
4. 拍位计算：从左到右累加时值，小节线重置验证

关键实现细节：
- 八度点使用 Unicode 组合字符：U+0307（上方点，高八度）、U+0323（下方点，低八度）
- 下划线使用 U+0332（组合下划线）
- 延音线 `-` 不产生新音符，延长前一个音符的 duration
- 小节线 `|` 不产生音符，用于验证拍位对齐

**Step 4: 实现验证功能**

`--validate` 模式检查：
- 每小节总拍数 = time_signature 指定的值
- 度数范围 0-7
- 八度标记不超过 ±1
- 力度标记在有效列表中

**Step 5: 手动测试**

准备一个简谱测试文件，运行解析器验证输出。

```bash
python .claude/skills/clef-compose/scripts/jianpu_parser.py test.jianpu
python .claude/skills/clef-compose/scripts/jianpu_parser.py test.jianpu --validate
python .claude/skills/clef-compose/scripts/jianpu_parser.py test.jianpu --output test_parsed.json
```

**Step 6: Commit**

```
feat(clef): add jianpu parser script
```

---

## Phase 3: 简谱→JSON 转换器

### Task 3.1: 创建 jianpu_to_json.py 脚本

**Files:**
- Create: `.claude/skills/clef-compose/scripts/jianpu_to_json.py`
- Reference: `.claude/skills/clef-compose/scripts/jianpu_parser.py` (复用解析器)
- Reference: `.claude/skills/clef-compose/templates/intermediate_schemas.json` (melody schema)

**Step 1: 编写脚本骨架和 CLI**

```python
"""Convert jianpu (numbered musical notation) to Clef melody JSON.

Usage:
  python jianpu_to_json.py melody.jianpu --plan .clef-work/plan.json --output .clef-work/melody.json
  python jianpu_to_json.py melody.jianpu --key D --scale major --root-pitch 62 --output melody.json
"""
import argparse
import io
import json
import sys
from pathlib import Path

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")
```

**Step 2: 实现音高转换**

从 plan.json 读取 `key`、`scale`、`orchestration.melody`，或通过 CLI 参数传入。

```python
# 音阶定义（与 theory.md 一致）
SCALE_INTERVALS = {
    "major":            [0, 2, 4, 5, 7, 9, 11],
    "natural_minor":    [0, 2, 3, 5, 7, 8, 10],
    "harmonic_minor":   [0, 2, 3, 5, 7, 8, 11],
    "melodic_minor":    [0, 2, 3, 5, 7, 9, 11],
    "dorian":           [0, 2, 3, 5, 7, 9, 10],
    "phrygian":         [0, 1, 3, 5, 7, 8, 10],
    "lydian":           [0, 2, 4, 6, 7, 9, 11],
    "mixolydian":       [0, 2, 4, 5, 7, 9, 10],
    "pentatonic_major": [0, 2, 4, 7, 9, None, None],
    "pentatonic_minor": [0, 3, 5, 7, 10, None, None],
    "blues":            [0, 3, 5, 6, 7, 10, None],
}

ROOT_PITCHES = {"C": 60, "D": 62, "E": 64, "F": 65, "G": 67, "A": 69, "B": 71}

def degree_to_pitch(degree, accidental, octave_offset, root_pitch, scale_intervals):
    """Convert jianpu degree to MIDI pitch."""
    if degree == 0:  # rest
        return 0
    interval = scale_intervals[degree - 1]
    if interval is None:
        raise ValueError(f"Degree {degree} not available in scale")
    pitch = root_pitch + interval + octave_offset * 12
    if accidental == "#":
        pitch += 1
    elif accidental == "b":
        pitch -= 1
    return pitch
```

**Step 3: 实现 velocity 线性分配**

```python
DYNAMICS_RANGES = {
    "ff": (110, 120),
    "f":  (100, 110),
    "mf": (85, 95),
    "mp": (70, 80),
    "p":  (55, 65),
    "pp": (40, 50),
}

def assign_velocities(notes, dynamics_list):
    """Linear distribution within each dynamics segment."""
    # dynamics_list: [(start_beat, end_beat, dynamics_str), ...]
    # First note gets lower bound, last gets upper bound, linear interpolation
```

**Step 4: 实现完整转换流程**

1. 调用 jianpu_parser 解析简谱文本
2. 从 plan.json 读取 root_pitch、scale、orchestration.melody
3. 遍历每个音符，调用 degree_to_pitch
4. 调用 assign_velocities
5. 按 intermediate_schemas.json 的 melody 格式组装 JSON

输出格式：
```json
{
  "track_name": "Melody",
  "channel": 0,
  "instrument": 60,
  "notes": [
    {"pitch": 74, "start": 0.0, "duration": 1.0, "velocity": 72},
    {"pitch": 77, "start": 1.0, "duration": 0.5, "velocity": 73},
    ...
  ]
}
```

**Step 5: 手动测试**

```bash
python .claude/skills/clef-compose/scripts/jianpu_to_json.py test.jianpu \
  --key D --scale major --root-pitch 62 \
  --channel 0 --instrument 60 \
  --output test_melody.json
```

验证：检查输出 JSON 中 pitch、start、duration、velocity 值的合理性。

**Step 6: Commit**

```
feat(clef): add jianpu to JSON converter script
```

---

## Phase 4: Composer Agent 修改（输出简谱）

### Task 4.1: 修改 clef-composer.md Agent

**Files:**
- Modify: `.claude/agents/clef-composer.md`

**Step 1: 修改 Agent 任务描述**

将任务从"生成 melody.json"改为"生成简谱文本"：

```markdown
## 任务

基于 plan.json 和 chords.json 生成旋律简谱，保存为 `.clef-work/melody.jianpu`。
```

**Step 2: 新增简谱格式引用**

在"必读文件"中新增：
```markdown
- `.claude/skills/clef-compose/theory.md` — 乐理知识（重点关注：简谱记谱法、旋律写作技法、旋律音程指南、风格旋律特征）
```

**Step 3: 修改输出格式**

```markdown
## 输出

将结果保存到 `.clef-work/melody.jianpu`，使用 theory.md 中定义的简谱记谱法格式。
不要生成 JSON 格式的旋律数据。
```

**Step 4: 新增简谱约束**

保留现有旋律约束（大跳处理、段落过渡、音域控制等），新增简谱特定约束：

```markdown
## 简谱格式约束

- 严格遵循 theory.md「简谱记谱法」章节的排版规范
- 头部必须包含调号、拍号、BPM
- 每个段落用 [A] [B] 等标记，附带段落名称
- 力度标记单独一行
- 音符按拍位对齐，使用空格分隔
- 小节线 | 在每小节末尾，段落边界用 ||
- 度数使用 1-7，升降号用 # 和 b 前缀
- 八度标记：高八度用上方点（U+0307），低八度用下方点（U+0323）
- 时值标记：八分音符用下划线（U+0332），十六分音符用双下划线
- 附点用 `.`，延音用 `-`（横杠），休止用 `0`
```

**Step 5: 新增打样模式说明**

新增打样模式的说明（通过 Prompt 指令控制，非 CLI 参数）：

```markdown
## 打样模式

当 Prompt 中要求"方向小样"时：
- 仅生成 8-16 拍的短旋律（覆盖 1-2 个段落）
- 聚焦动机的辨识度和风格方向
- 简谱头部标注 `(打样)` 标记

当 Prompt 中要求"完整初版"时：
- 生成完整长度旋律
- 复用打样确认的动机方向
- 扩展为完整段落结构
```

**Step 6: Commit**

```
refactor(clef): composer agent outputs jianpu instead of JSON
```

---

## Phase 5: 简谱审核 Agent

### Task 5.1: 创建 clef-reviewer.md Agent

**Files:**
- Create: `.claude/agents/clef-reviewer.md`
- Design note: 此 Agent 定义为实现计划新增的设计决策（设计文档仅描述了审核功能需求，未定义 Agent 规格）

**Step 1: 编写审核 Agent 定义**

```markdown
---
name: clef-reviewer
description: 简谱审核专家，负责旋律质量检查、结构分析、合规性验证
model: sonnet
tools: Read, Write, Glob
---

你是 Reviewer，一位专业的旋律审核专家。你读取简谱文本和 chords.json，输出结构化审核报告。

## 任务

读取 `.clef-work/melody.jianpu`（和可选的 `.clef-work/chords.json`），执行 5 维度 10 项检查，输出审核报告到 `.clef-work/review_report.md`。

## 必读文件

- `.clef-work/melody.jianpu` — 待审核的旋律简谱
- `.clef-work/chords.json` — 和弦骨架（若存在，用于和声隐含检查）
- `.claude/skills/clef-compose/theory.md` — 乐理知识（重点关注：旋律音程指南、乐句结构、和弦外音）
- `.clef-work/plan.json` — 音乐规划（调性、段落结构，用于验证简谱头部信息一致性）

## 审核维度（5 维度 10 项检查）

### 维度 1：音高合理性

| 检查项 | 检测方式 | 等级 |
|--------|---------|------|
| 大跳检测 | 度数跳变 >5 (WARN) / >7 (FAIL) | FAIL/WARN |
| 音域检测 | 高低八度标记跨度 >2 (WARN) | WARN |
| 增减音程 | `#1→b3` 等非常规进行未合理解决 (WARN) | WARN |

### 维度 2：调式内聚性

| 检查项 | 检测方式 | 等级 |
|--------|---------|------|
| 非调内音解决 | 变音后 1 拍内回到调内音 (WARN) | WARN |
| 骨干音频率 | `1` 和 `5` 出现占比 >25% (PASS) / <15% (FAIL) | FAIL/PASS |

### 维度 3：节奏规范性

| 检查项 | 检测方式 | 等级 |
|--------|---------|------|
| 小节时值 | 每小节总拍数正确 (FAIL) | FAIL |
| 节奏多样性 | 至少 3 种不同的节奏型 (WARN) | WARN |

### 维度 4：乐句结构

| 检查项 | 检测方式 | 等级 |
|--------|---------|------|
| 乐句长度 | 2/4/8 小节为正常，异常长度 (WARN) | WARN |
| 动机重复 | 首尾乐句共享动机素材 (INFO) | INFO |
| 高潮位置 | 最高音出现在乐曲 60-80% 位置 (WARN) | WARN |

### 维度 5：和声隐含（需要 chords.json）

| 检查项 | 检测方式 | 等级 |
|--------|---------|------|
| 强拍和弦对齐 | 每小节第 1 拍的音落在当前和弦构成音上 (WARN) | WARN |

## 审核报告格式

报告保存到 `.clef-work/review_report.md`，格式如下：

```
【审核报告】
总体评价：B-（基本规范，但存在3处明显不自然）

[FAIL] 音高合理性
  - 第5小节: 连续减五度跳进 4→b7→3，建议改为纯五度 4→1或分解进行 4→5→7
  - 第13小节: 八度大跳 3→3̇ 未级进收回

[WARN] 节奏规范性
  - 第9-12小节: 节奏型 × 4 重复，建议第11小节加入附点

[INFO] 乐句结构
  - 第17小节: 高潮音 2̇ 仅持续 1 拍，建议延长至 2 拍

[PASS] 调式内聚性 — 骨干音 1(18%) 5(14%) 分布合理
[PASS] 和声隐含 — 强拍音与和弦对齐率 92%
```

## 评级标准

| 等级 | 含义 | 标准 |
|------|------|------|
| A | 优秀 | 0 FAIL, ≤1 WARN |
| B+ | 良好 | 0 FAIL, 2-3 WARN |
| B | 合格 | 0 FAIL, 4-5 WARN |
| B- | 基本合格 | 1-2 FAIL |
| C | 需要修改 | 3+ FAIL |

## 约束

- 报告必须具体到小节号和音符位置
- 每条 FAIL/WARN 必须附带修改建议
- 不要修改简谱文件本身，只输出报告
- 评级必须客观，不因"看起来还行"而提高评级
```

**Step 2: Commit**

```
feat(clef): add jianpu review agent
```

---

## Phase 6: SKILL.md 重写（核心）

### Task 6.1: 重写 MA-Step 0 — 交互式需求收集

**Files:**
- Modify: `.claude/skills/clef-compose/SKILL.md` (替换 `## 多 Agent 工作流（--multi-agent）` 整个章节，约第 531-620 行)

**Step 1: 重写多 Agent 工作流头部**

替换从 `## 多 Agent 工作流（--multi-agent）` 到 `---` 之前的所有内容。新工作流为 MA-Step 0-4。

**Step 2: 编写 MA-Step 0 交互式需求收集**

参考设计文档"MA-Step 0: 交互式需求收集"部分。关键内容：

```markdown
### MA-Step 0: 交互式需求收集

根据用户描述，逐步询问缺失的关键信息。每步选项依赖前序回答。

**必要信息（按顺序收集）：**

| 顺序 | 信息 | 选项来源 | 说明 |
|------|------|---------|------|
| 1 | 游戏类型/场景 | 根据用户描述动态生成 | 如 JRPG → 战斗/Boss/村庄/主菜单/过场 |
| 2 | 音乐风格 | 根据场景给出合理选项 | 如 JRPG 战斗 → 经典管弦/现代电子/8-bit |
| 3 | 情绪/氛围 | 固定选项 | 激昂/紧张/悲伤/宁静/史诗/暗黑 |
| 4 | 时长 | 固定选项 | 30 秒/1 分钟/2 分钟/自定义 |
| 5 | 乐器组合 | 根据上面所有回答，给出 3-4 个备选方案 | 从 theory.md 配器方案中选择 |
| 6 | 主打乐器 | 根据选定的乐器组合，给出 3-4 个备选 | 从组合中提取旋律乐器选项 |

**可选信息（用户没说就不问）：** 参考曲（--ref 已有）、调性偏好、BPM 范围、是否循环

**输出：** 结构化需求参数 → 进入 MA-Step 1
```

**Step 3: 编写 MA-Step 1 — Producer 规划（微调）**

保留现有 MA-Step 1 逻辑，新增：
- 需求参数从 MA-Step 0 传入
- plan.json 生成后展示给用户确认（调性、BPM、段落结构、配器方案）

**Step 4: Commit MA-Step 0 + 1**

```
refactor(clef): add interactive requirement collection (MA-Step 0) and update planning step
```

---

### Task 6.2: 编写 MA-Step 2 — 两级打样

**Files:**
- Modify: `.claude/skills/clef-compose/SKILL.md` (接续 Task 6.1)

**Step 1: 编写 MA-Step 2a — 方向小样**

```markdown
### MA-Step 2a: 方向小样

- **时长：** 8-16 拍（约 5-10 秒），只覆盖 1-2 个段落
- **流程：**
  1. 使用 Agent 工具生成 Harmonist（subagent_type: "clef-harmonist"），Prompt: "根据 .clef-work/plan.json，生成简化版和弦进行（仅覆盖前 1-2 个段落），保存到 .clef-work/chords_sample.json。"
  2. 使用 Agent 工具生成 Composer（subagent_type: "clef-composer"），Prompt: "根据 plan.json 和 chords_sample.json，生成 8-16 拍的方向小样简谱，保存到 .clef-work/melody_sample.jianpu。这是方向小样，聚焦动机辨识度和风格方向。"
  3. 使用 Agent 工具生成 Reviewer（subagent_type: "clef-reviewer"），Prompt: "审核 melody_sample.jianpu，使用 chords_sample.json 进行和声隐含检查。"
- **简谱审核：** Reviewer 输出审核报告
  - 如果评级 C：Composer 重写简谱（最多 2 次）
  - 如果评级 B-/B：向用户展示报告，让用户决定是否继续
  - 如果评级 B+/A：自动通过
- **简谱转试听：** 运行 `jianpu_to_json.py` 转换为 melody_sample.json，合并 chords_sample.json 生成试听片段
- **用户决策：** 旋律走向、风格感觉、情绪对不对
- **不满意：** Composer 重写简谱 / 回到 MA-Step 1 调 plan
```

**Step 2: 编写 MA-Step 2b — 完整初版**

```markdown
### MA-Step 2b: 完整初版

- **时长：** 完整长度（如 72 拍 / 30 秒）
- **复用：** 2a 确定的旋律方向和和弦风格
- **流程：**
  1. 使用 Agent 工具生成 Harmonist，生成完整版 chords.json（参考 chords_sample.json 的风格方向）
  2. 使用 Agent 工具生成 Composer，生成完整版 melody.jianpu（复用 2a 确认的动机和风格方向，Prompt 中注明"完整初版，复用打样确认的动机方向"）
  3. 使用 Agent 工具生成 Reviewer，审核完整版简谱
- **简谱转试听：** 运行 `jianpu_to_json.py` 转换为 melody.json，生成完整 MIDI 试听
- **用户决策：** 段落过渡、高潮位置、循环衔接
- **不满意：** 局部修改（指定小节范围让 Composer 重写）/ 回到 2a
```

**Step 3: Commit MA-Step 2**

```
feat(clef): add two-level sampling workflow (MA-Step 2a/2b)
```

---

### Task 6.3: 编写 MA-Step 3-4 + 反馈处理

**Files:**
- Modify: `.claude/skills/clef-compose/SKILL.md` (接续 Task 6.2)

**Step 1: 编写 MA-Step 3 — 完整生产**

```markdown
### MA-Step 3: 完整生产

并行生成基础轨道 + 表现力：
1. 使用 Agent 工具同时生成 Rhythmist（bass.json + drums.json）
   - 注意：chords.json 已在 MA-Step 2b 生成，不需要重新生成
2. 等待 Rhythmist 完成后，使用 Agent 工具生成 Orchestrator（expression_plan.json → expression.json）
3. 整合所有轨道 + validate_clef.py + 输出
```

**Step 2: 编写 MA-Step 4 — 输出**

保留现有 MA-Step 8 的逻辑。

**Step 3: 重写反馈处理表**

更新反馈映射表，反映新的 Agent 职责：

| 用户反馈 | 唤醒的 Agent |
|---------|-------------|
| 旋律方向不对 | Composer（重写简谱）→ Reviewer（重新审核） |
| 和弦不够紧张 | Harmonist → Composer（和弦变了旋律需调整） |
| 节奏感再强一点 | Rhythmist |
| 低音不够明显 | Rhythmist |
| 表现力不够丰富 | Orchestrator |
| 配器太满/太吵 | 回到 MA-Step 0 重新选配器 |
| 整体风格不对 | 回到 MA-Step 0 重新选择 |
| 局部小节需要修改 | Composer（指定小节范围重写简谱） |

**Step 4: 更新降级策略**

如果多 Agent 模式因任何原因无法完成，自动降级为单 Agent 模式重新生成。

**Step 5: Commit MA-Step 3-4 + 反馈处理**

```
feat(clef): add production and output steps (MA-Step 3-4) with updated feedback handling
```

---

### Task 6.4: 更新模式选择逻辑

**Files:**
- Modify: `.claude/skills/clef-compose/SKILL.md` (第 157-163 行，模式选择章节)

**Step 1: 更新模式选择描述**

```markdown
### 模式选择

解析用户输入中的参数：
- 如果包含 `--multi-agent`：进入**多 Agent 交互模式**（MA-Step 0-4，带用户确认点）
- 否则：继续使用**单 Agent 模式**（现有的 Step 1-9 流程，零影响）

注意：Step 0（需求解析）和 Step R（风格分析）在两种模式下共享。
多 Agent 模式在 Step 0 之后额外执行 MA-Step 0（交互式需求收集）。
```

**Step 2: Commit**

```
docs(clef): update mode selection description for new multi-agent workflow
```

---

## Phase 7: Schema 更新

### Task 7.1: 在 intermediate_schemas.json 新增 jianpu schema

**Files:**
- Modify: `.claude/skills/clef-compose/templates/intermediate_schemas.json`

**Step 1: 新增 jianpu 格式规范**

在文件末尾（expression_plan 之后）添加 jianpu 的格式规范：

```json
"jianpu": {
  "_description": "简谱文本格式 — Composer Agent 输出，Reviewer Agent 审核，jianpu_to_json.py 转换",
  "_file": "melody.jianpu",
  "_producer": "Composer Agent (MA-Step 2a/2b)",
  "_consumer": "Reviewer Agent → jianpu_to_json.py → melody.json",

  "header_format": "1={调号}  {拍号}  BPM={速度}",
  "section_format": "[{段落ID}] {段落名称}",
  "dynamics_format": "({力度标记})",

  "note_elements": {
    "degree": {"valid": ["0","1","2","3","4","5","6","7"], "description": "音阶度数，0=休止"},
    "accidental": {"valid": ["","#","b"], "prefix": true, "description": "升降号前缀"},
    "octave_high": {"char": "̇", "unicode": "U+0307", "description": "高八度"},
    "octave_low": {"char": "̣", "unicode": "U+0323", "description": "低八度"},
    "duration_8th": {"char": "̲", "unicode": "U+0332", "value": 0.5, "description": "八分音符"},
    "duration_16th": {"char": "̲̲", "value": 0.25, "description": "十六分音符（双下划线）"},
    "dot": {"char": ".", "multiplier": 1.5, "description": "附点"},
    "tie": {"char": "-", "description": "延音线"},
    "barline": {"char": "|", "description": "小节线"},
    "double_barline": {"char": "||", "description": "段落边界"}
  },

  "constraints": [
    "头部必须包含调号、拍号、BPM",
    "每个段落用 [A] [B] 标记",
    "力度标记单独一行",
    "音符按拍位对齐",
    "小节线 | 在每小节末尾",
    "度数 1-7，升降号 # 和 b 前缀",
    "八度标记使用 U+0307（高）/ U+0323（低）",
    "时值下划线使用 U+0332"
  ]
}
```

**Step 2: Commit**

```
docs(clef): add jianpu format schema to intermediate_schemas.json
```

---

## Phase 8: 集成验证

### Task 8.1: 端到端验证

**Step 1: 验证 theory.md 扩充**

- 检查 5 个新章节的格式和内容完整性
- 确认与现有章节无重复/冲突
- 确认简谱示例在 theory.md 和设计文档中一致

**Step 2: 验证 jianpu_parser.py**

准备测试简谱文件（包含所有元素：升降号、八度点、附点、延音线、力度、段落标记），运行：
```bash
python .claude/skills/clef-compose/scripts/jianpu_parser.py test.jianpu --validate
python .claude/skills/clef-compose/scripts/jianpu_parser.py test.jianpu --output test_parsed.json
```

**Step 3: 验证 jianpu_to_json.py**

使用测试简谱文件运行转换：
```bash
python .claude/skills/clef-compose/scripts/jianpu_to_json.py test.jianpu \
  --key D --scale major --root-pitch 62 \
  --channel 0 --instrument 60 \
  --output test_melody.json
```

验证：
- pitch 值在合理范围内（如 C4=60 附近）
- start 值从 0.0 开始递增
- duration 值 > 0
- velocity 值在力度标记对应的范围内

**Step 4: 验证 Agent 定义**

检查所有 5 个 Agent 的 frontmatter 格式正确：
```bash
head -6 .claude/agents/clef-*.md
```

**Step 5: 验证 SKILL.md 新工作流**

通读 SKILL.md 多 Agent 部分，确认：
- MA-Step 0-4 流程完整
- 4 个用户确认点都已标注
- Agent 调用的 subagent_type 和 prompt 正确
- 脚本调用路径和参数正确

---

## 执行顺序

1. **Phase 1** (Task 1.1-1.5) — theory.md 扩充（5 个章节，可并行但建议顺序执行以保持一致性）
2. **Phase 2** (Task 2.1) — jianpu_parser.py（依赖 Phase 1 的简谱格式定义）
3. **Phase 3** (Task 3.1) — jianpu_to_json.py（依赖 Phase 2 的解析器）
4. **Phase 4** (Task 4.1) — Composer Agent 修改（依赖 Phase 1 的旋律知识）
5. **Phase 5** (Task 5.1) — Reviewer Agent 创建（依赖 Phase 1 的审核规则）
6. **Phase 6** (Task 6.1-6.4) — SKILL.md 重写（依赖 Phase 2-5 的所有产出）
7. **Phase 7** (Task 7.1) — Schema 更新（可与 Phase 6 并行）
8. **Phase 8** (Task 8.1) — 集成验证

---

## 不在本次范围内

- 单 Agent 模式（Step 1-9）不做任何改动
- converter.gd 不需要修改（它消费 JSON，不涉及简谱）
- validate_clef.py 不需要修改（它验证 JSON，不涉及简谱）
- MidiReader/MidiWriter 不受影响
- midi_stream_player.gd 不受影响
- `addons/clef/output/` 下的旧输出文件不修改
