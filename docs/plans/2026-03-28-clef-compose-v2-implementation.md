# Clef Compose v2 实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 clef-compose 从"简谱 + Clef JSON"管线迁移到"ABC + music21 + mido"多工具协作架构。

**Architecture:** 7 个 Agent（Composer/Harmonist/Rhythmist/Orchestrator/Reviewer + 新增 Revision/Leader）通过 ABC 格式协作，music21 自动验证，mido 注入表现力，自写 abc_to_midi.py 替代 GPL 的 abc2midi。

**Tech Stack:** Python 3.10+ / music21 (BSD) / mido (MIT) / GDScript (Godot 4.6)

**设计文档:** `docs/plans/2026-03-28-clef-compose-v2-design.md`

---

## Phase 1: 基础设施（工具链验证）

### Task 1: 依赖检查脚本

**Files:**
- Create: `.claude/skills/clef-compose/scripts/check_dependencies.py`

**Step 1: 创建依赖检查脚本**

```python
"""检查 clef-compose v2 所需的 Python 依赖。"""
import importlib
import shutil
import sys


def check():
    issues = []
    for pkg in ['music21', 'mido']:
        try:
            importlib.import_module(pkg)
            print(f"  ✅ {pkg}")
        except ImportError:
            issues.append(pkg)

    if issues:
        print(f"  ❌ 缺失: {', '.join(issues)}")
        print(f"  安装: pip install {' '.join(issues)}")
        return False
    print("所有依赖已就绪。")
    return True


if __name__ == '__main__':
    sys.exit(0 if check() else 1)
```

**Step 2: 运行验证**

Run: `python .claude/skills/clef-compose/scripts/check_dependencies.py`
Expected: 若缺少依赖则提示安装命令

**Step 3: Commit**

```bash
git add .claude/skills/clef-compose/scripts/check_dependencies.py
git commit -m "feat(clef): add dependency check script for v2"
```

---

### Task 2: ABC→MIDI 转换器（替代 abc2midi）

**Files:**
- Create: `.claude/skills/clef-compose/scripts/abc_to_midi.py`
- Create: `.claude/skills/clef-compose/tests/test_abc_to_midi.py`

**Step 1: 写测试 — 头部解析**

```python
# tests/test_abc_to_midi.py
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))
from abc_to_midi import parse_header


def test_parse_header_major():
    abc = "%%abc-version 2.1\nX:1\nM:4/4\nL:1/8\nQ:1/4=120\nK:D\n"
    header = parse_header(abc)
    assert header['time_signature'] == '4/4'
    assert header['unit_length'] == '1/8'
    assert header['bpm'] == 120
    assert header['key'] == 'D'


def test_parse_header_minor():
    abc = "%%abc-version 2.1\nX:1\nM:3/4\nL:1/8\nQ:1/4=90\nK:Am\n"
    header = parse_header(abc)
    assert header['time_signature'] == '3/4'
    assert header['key'] == 'Am'


def test_parse_header_title():
    abc = "%%abc-version 2.1\nX:1\nT:Boss Battle\nM:4/4\nL:1/8\nQ:1/4=140\nK:D\n"
    header = parse_header(abc)
    assert header['title'] == 'Boss Battle'
```

**Step 2: 运行测试验证失败**

Run: `python -m pytest .claude/skills/clef-compose/tests/test_abc_to_midi.py::test_parse_header_major -v`
Expected: FAIL (parse_header not defined)

**Step 3: 实现 parse_header**

在 `abc_to_midi.py` 中实现 `parse_header()`，解析以下字段：
- `%%abc-version` → 记录版本
- `X:` → 参考编号
- `T:` → 标题
- `M:` → 拍号
- `L:` → 单位音符长度
- `Q:` → 速度 (提取 `1/4=N` 中的 N)
- `K:` → 调号

**Step 4: 运行测试验证通过**

Run: `python -m pytest .claude/skills/clef-compose/tests/test_abc_to_midi.py -v`
Expected: 3 passed

**Step 5: Commit**

```bash
git add .claude/skills/clef-compose/scripts/abc_to_midi.py .claude/skills/clef-compose/tests/test_abc_to_midi.py
git commit -m "feat(clef): add ABC header parser (abc_to_midi)"
```

---

### Task 3: ABC→MIDI 转换器 — 声部与音符

**Files:**
- Modify: `.claude/skills/clef-compose/scripts/abc_to_midi.py`
- Modify: `.claude/skills/clef-compose/tests/test_abc_to_midi.py`

**Step 1: 写测试 — 声部声明和音符解析**

```python
# 追加到 test_abc_to_midi.py
from abc_to_midi import abc_to_midi
import mido


def test_simple_melody():
    abc = """X:1
M:4/4
L:1/8
K:D
%%MIDI channel 1
%%MIDI program 73
V:1 name="Flute" clef=treble
| d2 f2 a2 f2 |
"""
    mid = abc_to_midi(abc)
    assert mid.ticks_per_beat == 480
    assert len(mid.tracks) == 2  # tempo track + melody track
    melody = mid.tracks[1]
    notes = [m for m in melody if m.type == 'note_on']
    assert len(notes) == 4


def test_chord_voices():
    abc = """X:1
M:4/4
L:1/8
K:D
%%MIDI channel 2
%%MIDI program 48
V:2 name="Strings" clef=treble
| [FAc]2 [FAc]2 |
"""
    mid = abc_to_midi(abc)
    melody = mid.tracks[1]
    notes = [m for m in melody if m.type == 'note_on']
    # [FAc] 三和弦: F=65, A=69, C=72 (middle C)
    assert len(notes) == 3
    assert notes[0].note == 65
    assert notes[1].note == 69
    assert notes[2].note == 72


def test_rest_notes():
    abc = """X:1
M:4/4
L:1/8
K:D
%%MIDI channel 1
%%MIDI program 73
V:1 name="Flute"
| d2 z2 a2 f2 |
"""
    mid = abc_to_midi(abc)
    notes_on = [m for m in mid.tracks[1] if m.type == 'note_on']
    assert len(notes_on) == 3  # z 不产生 note_on
```

**Step 2: 运行测试验证失败**

Run: `python -m pytest .claude/skills/clef-compose/tests/test_abc_to_midi.py -v`
Expected: FAIL

**Step 3: 实现 abc_to_midi()**

实现以下解析逻辑：
1. `parse_header()` — 已有
2. 解析 `V:` 声部声明 + `%%MIDI channel/program`
3. 解析音符行：
   - 普通音符: `a`-`g` + 八度标记 `̇`(高)/`̣`(低) + 时值 `2`/`4`/`8`/`16`/空格=8分
   - 和弦: `[FAc]` → 拆分为同时发声的多个 note_on
   - 休止: `z` → 跳过（不产生 MIDI 事件）
   - 小节线 `|` → 时间推进
   - 力度标记 `!f!` → 修改后续音符的 velocity
4. 时间计算：基于 `L:` 单位长度 + `Q:` BPM
5. 输出 `mido.MidiFile`

**Step 4: 运行测试验证通过**

Run: `python -m pytest .claude/skills/clef-compose/tests/test_abc_to_midi.py -v`
Expected: 6 passed

**Step 5: Commit**

```bash
git add .claude/skills/clef-compose/scripts/abc_to_midi.py .claude/skills/clef-compose/tests/test_abc_to_midi.py
git commit -m "feat(clef): add ABC to MIDI converter (voices, notes, rests)"
```

---

### Task 4: ABC→MIDI 转换器 — 鼓声部 + 力度

**Files:**
- Modify: `.claude/skills/clef-compose/scripts/abc_to_midi.py`
- Modify: `.claude/skills/clef-compose/tests/test_abc_to_midi.py`

**Step 1: 写测试 — 鼓声部和力度**

```python
# 追加到 test_abc_to_midi.py

def test_drum_track():
    abc = """X:1
M:4/4
L:1/8
K:D
%%MIDI channel 10
V:4 name="Drums" clef=perc
| B,, z D, z B,, B,, z |
"""
    mid = abc_to_midi(abc)
    drum_track = mid.tracks[1]
    notes = [m for m in drum_track if m.type == 'note_on']
    assert len(notes) == 4
    assert notes[0].note == 36  # B,, = Kick


def test_dynamics():
    abc = """X:1
M:4/4
L:1/8
K:D
%%MIDI channel 1
%%MIDI program 73
V:1 name="Flute"
!pp! | d2 f2 | !f! | a2 f2 |
"""
    mid = abc_to_midi(abc)
    notes = [m for m in mid.tracks[1] if m.type == 'note_on']
    assert notes[0].velocity < notes[2].velocity  # pp < f


def test_full_score():
    abc = """%%abc-version 2.1
X:1
T:Boss Battle
M:4/4
L:1/8
Q:1/4=140
K:D
%%MIDI channel 1
%%MIDI program 73
V:1 name="Flute" clef=treble
|: "D" d2 f2 a2 f2 | "G" g2 b2 d'2 b2 :|
%%MIDI channel 2
%%MIDI program 48
V:2 name="Strings" clef=treble
|: "D"[FAc]2 [FAc]2 | "G"[GBd]2 [GBd]2 :|
%%MIDI channel 3
%%MIDI program 32
V:3 name="Bass" clef=bass
|: "D"D,2 D,2 F,2 D,2 | "G"G,2 G,2 B,2 G,2 :|
%%MIDI channel 10
V:4 name="Drums" clef=perc
|: B,, z D, z | B,, B,, z z :|
"""
    mid = abc_to_midi(abc)
    assert mid.ticks_per_beat == 480
    assert len(mid.tracks) == 5  # tempo + 4 voices
```

**Step 2: 运行测试验证失败**

Run: `python -m pytest .claude/skills/clef-compose/tests/test_abc_to_midi.py -v`
Expected: FAIL

**Step 3: 实现鼓声部解析**

- `V:` 声部中 `clef=perc` → 标记为打击乐通道
- `%%MIDI channel 10` → MIDI channel 10
- 鼓音符直接使用 GM Note 编号（`B,,`=36, `D,`=38 等）

**Step 4: 实现力度标记解析**

- `!pp!` → velocity 48
- `!p!` → velocity 64
- `!mp!` → velocity 80
- `!mf!` → velocity 96
- `!f!` → velocity 112
- `!ff!` → velocity 127

**Step 5: 运行测试验证通过**

Run: `python -m pytest .claude/skills/clef-compose/tests/test_abc_to_midi.py -v`
Expected: 9 passed

**Step 6: Commit**

```bash
git add .claude/skills/clef-compose/scripts/abc_to_midi.py .claude/skills/clef-compose/tests/test_abc_to_midi.py
git commit -m "feat(clef): add drum parsing and dynamics to ABC converter"
```

---

### Task 5: Merger 脚本

**Files:**
- Create: `.claude/skills/clef-compose/scripts/merge_abc.py`
- Create: `.claude/skills/clef-compose/tests/test_merge_abc.py`

**Step 1: 写测试 — 小节计数和合并**

```python
# tests/test_merge_abc.py
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))
from merge_abc import count_measures, pad_with_rests, merge


def test_count_measures():
    content = "| d2 f2 a2 f2 | g2 b2 d'2 b2 |"
    assert count_measures(content) == 3


def test_count_measures_with_repeat():
    content = "|: d2 f2 | g2 b2 :|"
    assert count_measures(content) == 2


def test_pad_with_rests():
    content = "| d2 f2 |"
    result = pad_with_rests(content, target_measures=4)
    assert count_measures(result) == 4


def test_merge_full():
    plan = {"title": "Test", "time_signature": "4/4", "bpm": 120, "key": "D major"}
    fragments = {
        "V:1": '| d2 f2 | g2 b2 |',
        "V:2": '| [FAc]2 [FAc]2 | [GBd]2 [GBd]2 |',
    }
    result = merge(plan, fragments, mode='full')
    assert 'K:D' in result
    assert 'V:1' in result
    assert 'V:2' in result


def test_merge_solo():
    plan = {"title": "Test", "time_signature": "4/4", "bpm": 120, "key": "D major"}
    fragments = {"V:1": '| d2 f2 a2 f2 |'}
    result = merge(plan, fragments, mode='solo')
    assert 'V:1' in result
    assert 'V:2' not in result
```

**Step 2: 运行测试验证失败**

Run: `python -m pytest .claude/skills/clef-compose/tests/test_merge_abc.py -v`
Expected: FAIL

**Step 3: 实现 merge_abc.py**

按照设计文档 Section 9 的伪代码实现，包括：
- `count_measures()` — 统计 `|` 数量（排除 `||`）
- `pad_with_rests()` — 用 `z` 休止符补齐
- `generate_header()` — 从 plan.json 生成 ABC 头部
- `merge()` — 合并声部，支持 `full` 和 `solo` 模式

**Step 4: 运行测试验证通过**

Run: `python -m pytest .claude/skills/clef-compose/tests/test_merge_abc.py -v`
Expected: 5 passed

**Step 5: Commit**

```bash
git add .claude/skills/clef-compose/scripts/merge_abc.py .claude/skills/clef-compose/tests/test_merge_abc.py
git commit -m "feat(clef): add ABC merger script with measure alignment"
```

---

### Task 6: music21 验证脚本

**Files:**
- Create: `.claude/skills/clef-compose/scripts/validate_abc.py`
- Create: `.claude/skills/clef-compose/tests/test_validate_abc.py`

**Step 1: 写测试 — 调性检测和音域检查**

需要一个测试用 ABC 文件和 plan.json。在测试目录创建 fixtures：

```python
# tests/fixtures/sample.abc
%%abc-version 2.1
X:1
T:Test
M:4/4
L:1/8
Q:1/4=120
K:D
%%MIDI channel 1
%%MIDI program 73
V:1 name="Flute" clef=treble
| d2 f2 a2 f2 | g2 b2 d'2 b2 |
```

```json
// tests/fixtures/test_plan.json
{
  "title": "Test", "key": "D major", "bpm": 120,
  "time_signature": "4/4", "orchestration": {
    "melody": {"channel": 0, "instrument": 73, "name": "Flute"}
  }
}
```

```python
# tests/test_validate_abc.py
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))
from validate_abc import validate


def test_validate_clean_abc():
    abc_path = os.path.join(os.path.dirname(__file__), 'fixtures', 'sample.abc')
    plan_path = os.path.join(os.path.dirname(__file__), 'fixtures', 'test_plan.json')
    report = validate(abc_path, plan_path)
    assert report.fails == []


def test_validate_wrong_key():
    # 创建一个 K:G 的 ABC，但 plan.json 说 key 是 D major
    report = validate(...)  # 应产生 key_consistency warn
    assert any(w.category == 'key_consistency' for w in report.warns)
```

**Step 2: 运行测试验证失败**

Run: `python -m pytest .claude/skills/clef-compose/tests/test_validate_abc.py -v`
Expected: FAIL

**Step 3: 实现 validate_abc.py**

按照设计文档 Section 7 实现检查项：
1. 调性一致性 — `music21.converter.parse()` + `analyze('key')`
2. 音域检查 — 遍历每个声部的 pitch，对比 `INSTRUMENT_RANGES`
3. 大跳检测 — 遍历旋律声部的 `melodicIntervals`
4. 小节时值验证 — `duration.quarterLength` vs `timeSignature.beatCount`
5. 声部小节数对齐

输出 `validation_report.json` 格式的结构体。

**Step 4: 运行测试验证通过**

Run: `python -m pytest .claude/skills/clef-compose/tests/test_validate_abc.py -v`
Expected: 2 passed

**Step 5: Commit**

```bash
git add .claude/skills/clef-compose/scripts/validate_abc.py .claude/skills/clef-compose/tests/test_validate_abc.py .claude/skills/clef-compose/tests/fixtures/
git commit -m "feat(clef): add music21 validation script for ABC"
```

---

### Task 7: mido 表现力注入脚本

**Files:**
- Create: `.claude/skills/clef-compose/scripts/inject_expression.py`
- Create: `.claude/skills/clef-compose/tests/test_inject_expression.py`
- Create: `.claude/skills/clef-compose/tests/fixtures/expression_plan.json`

**Step 1: 创建测试 fixture**

```json
{
  "tracks": [
    {
      "channel": 1,
      "events": [
        {"time_beats": 0, "type": "cc", "control": 7, "value": 90},
        {"time_beats": 16, "type": "cc", "control": 7, "value": 70},
        {"time_beats": 15.75, "type": "pitch_bend", "value": 12288},
        {"time_beats": 16.25, "type": "pitch_bend", "value": 8192}
      ]
    }
  ]
}
```

**Step 2: 写测试**

```python
def test_inject_cc():
    # 创建一个基础 MIDI 文件
    base_mid = create_test_midi()  # helper: 1 track, C4 quarter notes
    plan_path = fixtures / 'expression_plan.json'
    output_path = tmp / 'output.mid'
    inject(base_mid, plan_path, output_path)
    result = mido.MidiFile(output_path)
    # 验证 CC7 事件存在
    cc_events = [m for t in result.tracks for m in t if m.type == 'control_change' and m.control == 7]
    assert len(cc_events) == 2


def test_inject_pitch_bend():
    base_mid = create_test_midi()
    plan_path = fixtures / 'expression_plan.json'
    output_path = tmp / 'output.mid'
    inject(base_mid, plan_path, output_path)
    result = mido.MidiFile(output_path)
    pb_events = [m for t in result.tracks for m in t if m.type == 'pitchwheel']
    assert len(pb_events) == 2
    assert pb_events[1].pitch == 8192  # 归零
```

**Step 3: 运行测试验证失败**

Run: `python -m pytest .claude/skills/clef-compose/tests/test_inject_expression.py -v`
Expected: FAIL

**Step 4: 实现 inject_expression.py**

- 读取 base MIDI → 按 channel 匹配轨道
- 将 `time_beats` 转换为 tick（`beat_to_tick`）
- 注入 CC 事件和 pitch bend 事件
- 按时间排序确保事件顺序正确

**Step 5: 运行测试验证通过**

Run: `python -m pytest .claude/skills/clef-compose/tests/test_inject_expression.py -v`
Expected: 2 passed

**Step 6: Commit**

```bash
git add .claude/skills/clef-compose/scripts/inject_expression.py .claude/skills/clef-compose/tests/test_inject_expression.py .claude/skills/clef-compose/tests/fixtures/expression_plan.json
git commit -m "feat(clef): add mido expression injection script"
```

---

### Task 8: 分轨 Solo 提取脚本

**Files:**
- Create: `.claude/skills/clef-compose/scripts/extract_solo.py`
- Create: `.claude/skills/clef-compose/tests/test_extract_solo.py`

**Step 1: 写测试**

```python
def test_extract_solo_by_track():
    # 创建一个 2 track 的 MIDI (track 0=tempo, track 1=melody, track 2=bass)
    mid = create_test_multi_track_midi()
    mid_path = tmp / 'input.mid'
    mid.save(mid_path)
    output_dir = tmp / 'solo'
    output_dir.mkdir()
    files = extract_solo(str(mid_path), 0.0, 2.0, str(output_dir))
    assert len(files) == 2  # melody + bass
    # 验证每个文件只包含对应轨道的事件
    for f in files:
        solo = mido.MidiFile(f)
        assert len(solo.tracks) == 2  # tempo + one voice
```

**Step 2: 运行测试验证失败**

Run: `python -m pytest .claude/skills/clef-compose/tests/test_extract_solo.py -v`
Expected: FAIL

**Step 3: 实现 extract_solo.py**

- 读取 MIDI，获取 tempo（用于秒→tick 转换）
- 按轨道过滤指定时间范围内的事件
- 每个轨道生成独立的 MIDI 文件（包含 tempo track）
- 文件名包含轨道名称和时间范围

**Step 4: 运行测试验证通过**

Run: `python -m pytest .claude/skills/clef-compose/tests/test_extract_solo.py -v`
Expected: 1 passed

**Step 5: Commit**

```bash
git add .claude/skills/clef-compose/scripts/extract_solo.py .claude/skills/clef-compose/tests/test_extract_solo.py
git commit -m "feat(clef): add solo track extraction script"
```

---

### Task 9: 端到端管线验证

**Files:**
- Create: `.claude/skills/clef-compose/tests/fixtures/e2e_sample.abc`
- Create: `.claude/skills/clef-compose/tests/test_e2e_pipeline.py`

**Step 1: 创建 E2E 测试用 ABC**

创建一个包含 4 个声部、4 小节的完整 ABC 文件（参考设计文档 Section 3.1 的标准格式）。

**Step 2: 写端到端管线测试**

```python
def test_full_pipeline():
    # 1. merge
    plan = {"title": "E2E", "key": "D major", "bpm": 120, "time_signature": "4/4"}
    fragments = {"V:1": "...", "V:2": "...", "V:3": "...", "V:4": "..."}
    score = merge(plan, fragments)

    # 2. validate
    report = validate(score, plan)
    assert report.fails == []

    # 3. abc_to_midi
    base_mid = abc_to_midi(score)

    # 4. inject expression
    inject(base_mid, expression_plan_path, output_path)

    # 5. 验证输出 MIDI 可被 mido 解析
    result = mido.MidiFile(output_path)
    assert result.ticks_per_beat == 480
```

**Step 3: 运行测试**

Run: `python -m pytest .claude/skills/clef-compose/tests/test_e2e_pipeline.py -v`
Expected: 1 passed

**Step 4: Commit**

```bash
git add .claude/skills/clef-compose/tests/fixtures/e2e_sample.abc .claude/skills/clef-compose/tests/test_e2e_pipeline.py
git commit -m "test(clef): add E2E pipeline integration test"
```

---

## Phase 2: Agent 迁移

### Task 10: Revision Agent

**Files:**
- Create: `.claude/agents/clef-revision.md`

**Step 1: 创建 Revision Agent 定义**

按照设计文档 Section 5.6 的 prompt 模板创建 `.claude/agents/clef-revision.md`，包含：
- frontmatter: name, description, model (haiku), tools (Read, Write, Glob)
- 任务说明：只修格式错误，不碰创作内容
- 修正范围和禁止事项
- 输入：score.abc + validation_report.json

**Step 2: 验证 Agent 可被 Claude Code 加载**

确认 `clef-revision` 出现在可用的 subagent_type 列表中。

**Step 3: Commit**

```bash
git add .claude/agents/clef-revision.md
git commit -m "feat(clef): add Revision agent definition"
```

---

### Task 11: Leader Agent

**Files:**
- Create: `.claude/agents/clef-leader.md`

**Step 1: 创建 Leader Agent 定义**

按照设计文档 Section 5.7 + Section 6.5 的 prompt 模板，包含：
- frontmatter: name, description, model (sonnet), tools (Read, Write, Glob)
- 输入：review_report.json, validation_report.json, user_feedback.json
- 决策规则（优先级排序、任务合并、依赖关系、任务上限、终止条件）
- 输出约束（JSON 格式、agent 白名单、scope 格式）
- 迭代终止条件（双重阈值）

**Step 2: 验证**

**Step 3: Commit**

```bash
git add .claude/agents/clef-leader.md
git commit -m "feat(clef): add Leader agent definition"
```

---

### Task 12: Composer Agent 重写

**Files:**
- Modify: `.claude/agents/clef-composer.md`

**Step 1: 重写 Composer prompt**

- 输出格式从 jianpu → ABC V:1 片段
- 约束保留（动机发展、大跳处理、段落过渡等）
- 添加"完整生成"和"定向修改"两种模式
- 首轮 vs 迭代轮的依赖说明
- 移除 jianpu 自检清单（music21 接管技术检查）

**Step 2: Commit**

```bash
git add .claude/agents/clef-composer.md
git commit -m "refactor(clef): rewrite Composer agent for ABC output"
```

---

### Task 13: Harmonist Agent 重写

**Files:**
- Modify: `.claude/agents/clef-harmonist.md`

**Step 1: 重写 Harmonist prompt**

- 输出格式从 chords.json → ABC V:2 片段
- 同时包含和弦标记 `"D"` 和和弦音 `[FAc]`
- 声部进行约束（避免平行五八度）

**Step 2: Commit**

```bash
git add .claude/agents/clef-harmonist.md
git commit -m "refactor(clef): rewrite Harmonist agent for ABC output"
```

---

### Task 14: Rhythmist Agent 重写

**Files:**
- Modify: `.claude/agents/clef-rhythmist.md`

**Step 1: 重写 Rhythmist prompt**

- 输出格式从 bass.json + drums.json → ABC V:3 + V:4 片段
- 包含固定 GM 鼓音高映射表
- 低音约束（和弦根音/五音优先）

**Step 2: Commit**

```bash
git add .claude/agents/clef-rhythmist.md
git commit -m "refactor(clef): rewrite Rhythmist agent for ABC output"
```

---

### Task 15: Reviewer Agent 更新

**Files:**
- Modify: `.claude/agents/clef-reviewer.md`

**Step 1: 更新 Reviewer prompt**

- 输出格式从 review_report.md → review_report.json
- 移除技术检查（music21 自动完成）
- 专注 5 维音乐性评价
- 评审维度从 5维10项 精简为 5 维（合并自动检查项）

**Step 2: Commit**

```bash
git add .claude/agents/clef-reviewer.md
git commit -m "refactor(clef): update Reviewer agent to output JSON"
```

---

### Task 16: Orchestrator Agent 更新

**Files:**
- Modify: `.claude/agents/clef-orchestrator.md`

**Step 1: 更新 Orchestrator prompt**

- 输出改为：在 score.abc 添加力度标记 + 生成 expression_plan.json
- expression_plan.json 结构定义（Section 8.1）
- 力度层级说明（ABC velocity = 基础层，CC11 = 微调层）

**Step 2: Commit**

```bash
git add .claude/agents/clef-orchestrator.md
git commit -m "refactor(clef): update Orchestrator for expression_plan.json"
```

---

## Phase 3: 管线整合

### Task 17: SKILL.md 重写

**Files:**
- Modify: `.claude/skills/clef-compose/SKILL.md`

**Step 1: 重写 SKILL.md 为 4 步新管线**

- 移除所有 jianpu 相关内容
- 移除 validate_clef.py / jianpu_to_json.py / generate_expression.py 引用
- 更新工具链引用（abc_to_midi, validate_abc, inject_expression, merge_abc）
- 更新 Agent 调用方式（subagent_type 名称）
- 更新用户反馈处理（Section 6.8）
- 更新自评流程（Section 7.3 统一评估系统）

**Step 2: Commit**

```bash
git add .claude/skills/clef-compose/SKILL.md
git commit -m "refactor(clef): rewrite SKILL.md for v2 4-step pipeline"
```

---

### Task 18: theory.md 更新

**Files:**
- Modify: `.claude/skills/clef-compose/theory.md`

**Step 1: 更新 theory.md**

- 添加 ABC 格式规范（Section 3 设计文档内容）
- 添加 GM 鼓音高映射表
- 保留现有乐理知识（音阶、和弦进行、配器方案等）
- 移除简谱记谱法章节（或标记为 deprecated）

**Step 2: Commit**

```bash
git add .claude/skills/clef-compose/theory.md
git commit -m "docs(clef): update theory.md with ABC format spec"
```

---

### Task 19: 清理旧文件

**Files:**
- Delete: `.claude/skills/clef-compose/scripts/jianpu_to_json.py`
- Delete: `.claude/skills/clef-compose/scripts/validate_clef.py`
- Delete: `.claude/skills/clef-compose/scripts/generate_expression.py`
- Delete: `.claude/skills/clef-compose/scripts/jianpu_parser.py`

**Step 1: 确认旧脚本不再被引用**

```bash
grep -r "jianpu_to_json\|validate_clef\|generate_expression\|jianpu_parser" .claude/ --include="*.md" -l
```

**Step 2: 删除旧文件**

```bash
git rm .claude/skills/clef-compose/scripts/jianpu_to_json.py
git rm .claude/skills/clef-compose/scripts/validate_clef.py
git rm .claude/skills/clef-compose/scripts/generate_expression.py
git rm .claude/skills/clef-compose/scripts/jianpu_parser.py
```

**Step 3: Commit**

```bash
git commit -m "chore(clef): remove deprecated jianpu scripts (replaced by ABC toolchain)"
```

---

### Task 20: Portable Python 环境打包

**目标：** 将所有 Python 脚本 + 依赖（music21, mido）打包为独立可执行文件，用户无需安装 Python。

**Files:**
- Create: `.claude/skills/clef-compose/scripts/build_portable.py`
- Create: `.claude/skills/clef-compose/scripts/clef_tools.py`（统一入口）
- Create: `.claude/skills/clef-compose/scripts/clef_tools.spec`（PyInstaller spec）
- Create: `.claude/skills/clef-compose/tests/test_portable.py`

**Step 1: 创建统一入口 clef_tools.py**

将所有脚本整合为一个 CLI 入口，Godot 通过 `clef_tools <command>` 调用：

```python
"""Clef Compose v2 工具链统一入口。"""
import argparse
import sys


def main():
    parser = argparse.ArgumentParser(prog='clef_tools')
    sub = parser.add_subparsers(dest='command')

    # check-deps
    sub.add_parser('check-deps', help='检查依赖')

    # abc-to-midi <input.abc> <output.mid>
    p = sub.add_parser('abc-to-midi', help='ABC 转 MIDI')
    p.add_argument('input', help='输入 ABC 文件路径')
    p.add_argument('output', help='输出 MIDI 文件路径')

    # validate <input.abc> <plan.json> [--output report.json]
    p = sub.add_parser('validate', help='music21 验证 ABC')
    p.add_argument('abc', help='ABC 文件路径')
    p.add_argument('plan', help='plan.json 路径')
    p.add_argument('--output', '-o', default=None, help='输出报告路径')

    # merge <plan.json> <fragments_dir> [--mode full|solo] [--output score.abc]
    p = sub.add_parser('merge', help='合并声部 ABC 片段')
    p.add_argument('plan', help='plan.json 路径')
    p.add_argument('fragments_dir', help='片段目录路径')
    p.add_argument('--mode', choices=['full', 'solo'], default='full')
    p.add_argument('--output', '-o', default=None)

    # inject <input.mid> <expression_plan.json> <output.mid>
    p = sub.add_parser('inject', help='注入表现力 CC/弯音')
    p.add_argument('input', help='基础 MIDI 文件路径')
    p.add_argument('plan', help='expression_plan.json 路径')
    p.add_argument('output', help='输出 MIDI 文件路径')

    # extract-solo <input.mid> <start_sec> <end_sec> <output_dir>
    p = sub.add_parser('extract-solo', help='分轨 Solo 提取')
    p.add_argument('input', help='MIDI 文件路径')
    p.add_argument('start', type=float, help='起始时间（秒）')
    p.add_argument('end', type=float, help='结束时间（秒）')
    p.add_argument('output_dir', help='输出目录')

    args = parser.parse_args()
    # dispatch to respective modules...
```

**Step 2: 创建 PyInstaller build 脚本 build_portable.py**

```python
"""打包 clef_tools 为单文件可执行程序。"""
import subprocess
import sys
import os

def build():
    scripts_dir = os.path.dirname(__file__)
    entry = os.path.join(scripts_dir, 'clef_tools.py')

    # 收集 music21 的数据文件（corpus 等）
    cmd = [
        sys.executable, '-m', 'PyInstaller',
        '--onefile',
        '--name', 'clef_tools',
        '--distpath', os.path.join(scripts_dir, '..', 'dist'),
        '--workpath', os.path.join(scripts_dir, '..', 'build', 'pyinstaller'),
        '--specpath', scripts_dir,
        entry
    ]
    subprocess.run(cmd, check=True)
    print("打包完成: dist/clef_tools.exe")

if __name__ == '__main__':
    build()
```

**Step 3: 创建 PyInstaller spec 文件 clef_tools.spec**

确保 music21 的 corpus 数据和 mido 都正确打包：

```python
# clef_tools.spec — PyInstaller 打包配置
a = Analysis(
    ['clef_tools.py'],
    pathex=[],
    binaries=[],
    datas=[
        # music21 需要 corpus 数据
        # 通过 hiddenimports 确保所有模块被打包
    ],
    hiddenimports=[
        'music21', 'music21.converter', 'music21.key',
        'music21.pitch', 'music21.meter', 'music21.note',
        'music21.stream', 'music21.interval', 'music21.voiceLeading',
        'mido', 'mido.backends',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=['tkinter', 'matplotlib', 'numpy'],  # music21 可选依赖，减小体积
)
```

**Step 4: 写测试 — 验证 CLI 入口**

```python
# tests/test_portable.py
import subprocess
import sys

def test_cli_help():
    result = subprocess.run(
        [sys.executable, 'clef_tools.py', '--help'],
        capture_output=True, text=True,
        cwd=SCRIPTS_DIR
    )
    assert result.returncode == 0
    assert 'abc-to-midi' in result.stdout
    assert 'validate' in result.stdout
```

**Step 5: 运行测试**

Run: `python -m pytest .claude/skills/clef-compose/tests/test_portable.py -v`
Expected: 1 passed

**Step 6: 执行打包并验证**

Run: `python .claude/skills/clef-compose/scripts/build_portable.py`
Expected: `dist/clef_tools.exe` 生成

验证:
```bash
./dist/clef_tools.exe check-deps
./dist/clef_tools.exe abc-to-midi test.abc test.mid
```

**Step 7: 验证许可证合规**

确认打包组件许可证：
| 组件 | 许可证 | 合规 |
|------|--------|------|
| music21 | BSD-3-Clause | 可随分发 |
| mido | MIT | 可随分发 |
| PyInstaller | GPL-2.0（或 AGPL-3.0 for newer） | 仅作构建工具，不打包进产物 |
| abc_to_midi.py | 自写 | 项目自有 |
| merge_abc.py | 自写 | 项目自有 |
| validate_abc.py | 自写 | 项目自有 |
| inject_expression.py | 自写 | 项目自有 |
| extract_solo.py | 自写 | 项目自有 |

注意：PyInstaller 仅作为构建工具使用，不打包进最终产物。最终产物 `clef_tools.exe` 中只包含 music21、mido 和自写脚本，均为 MIT/BSD 兼容许可。

**Step 8: Commit**

```bash
git add .claude/skills/clef-compose/scripts/clef_tools.py
git add .claude/skills/clef-compose/scripts/build_portable.py
git add .claude/skills/clef-compose/scripts/clef_tools.spec
git add .claude/skills/clef-compose/tests/test_portable.py
git commit -m "feat(clef): add portable Python build (PyInstaller + unified CLI)"
```

---

### Task 21: 端到端验收

**Step 1: 使用 clef-compose skill 生成一首简单曲子**

通过 Godot 运行 `/clef-compose 8-bit chiptune 风格，30秒`，验证：
- Step 0: 需求收集正常
- Step 1: 方向小样生成 + abc_to_midi 转换 + Godot 试听
- Step 2: 完整创作 + Leader 迭代（至少 1 轮自动迭代）
- Step 3: 表现力注入 + mido 注入
- Step 4: 自评报告生成

**Step 2: 验证所有中间文件正确生成**

- `.clef-work/plan.json` 存在且格式正确
- `.clef-work/score.abc` 包含 4 个声部
- `.clef-work/review_report.json` 格式正确
- `.clef-work/validation_report.json` 格式正确
- `.clef-work/expression_plan.json` 格式正确
- `addons/clef/output/` 下有最终 .mid 文件

**Step 3: Commit**

```bash
git add -A
git commit -m "chore(clef): v2 migration complete"
```
