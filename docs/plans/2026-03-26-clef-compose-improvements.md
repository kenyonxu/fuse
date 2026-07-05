# Clef Compose 多 Agent 模式改进计划

> **Status:** SUPERSEDED — 已被 `docs/plans/2026-03-27-clef-multi-agent-redesign.md` 取代。仅 Task 6（CLI 语法修复）纳入新计划。

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 基于首次多 Agent E2E 运行发现的问题，添加旋律分析工具并修复 pipeline 遗留缺陷。

**Architecture:** 新增 Python 分析脚本 `analyze_melody.py`（简谱转换 + 合规检查），修复 SKILL.md 中的 CLI 调用不一致，以及单 Agent 模式旋律约束与多 Agent 模式同步。

**Tech Stack:** Python 标准库, argparse, UTF-8

---

## 问题清单（来自首次 E2E 运行分析）

| # | 问题 | 严重度 | 状态 |
|---|------|--------|------|
| 1 | 缺少旋律分析工具（简谱 + 合规检查） | HIGH | 待实现 |
| 2 | SKILL.md Step 6b 的 generate_expression.py CLI 调用语法错误 | MEDIUM | 待修复 |
| 3 | 单 Agent Step 3 缺少大跳/段落过渡约束（Composer agent 已有，SKILL.md 未同步） | MEDIUM | 待同步 |
| 4 | 顶层元数据缺失（已在上一 session 修复 SKILL.md，但 validate_clef.py 未校验） | LOW | 待验证 |

---

### Task 1: 创建 analyze_melody.py 脚本骨架和 CLI

**Files:**
- Create: `.claude/skills/clef-compose/scripts/analyze_melody.py`
- Reference: `.claude/skills/clef-compose/scripts/generate_expression.py` (CLI 模式、load_json、Windows UTF-8)

**Step 1: 创建脚本骨架**

```python
"""Analyze melody tracks from Clef JSON files.

Outputs:
  - Jianpu (numbered musical notation) for human/LLM review
  - Automated compliance checks against Composer agent constraints
"""
import argparse
import io
import json
import sys
from dataclasses import dataclass, field
from pathlib import Path

# Windows UTF-8 console fix
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")

NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#",", "A", "A#", "B"]
ROOT_PITCHES = {"C": 60, "D": 62, "E": 64, "F": 65, "G": 67, "A": 69, "B": 71}

SCALE_DEFINITIONS = {
    "major": [0, 2, 4, 5, 7, 9, 11],
    "natural_minor": [0, 2, 3, 5, 7, 8, 10],
    "harmonic_minor": [0, 2, 3, 5, 7, 8, 11],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "phrygian": [0, 1, 3, 5, 7, 8, 10],
    "lydian": [0, 2, 4, 6, 7, 9, 11],
    "mixolydian": [0, 2, 4, 5, 7, 9, 10],
    "pentatonic_major": [0, 2, 4, 7, 9],
    "pentatonic_minor": [0, 3, 5, 7, 10],
    "blues": [0, 3, 5, 6, 7, 10],
    "japanese_insen": [0, 1, 5, 7, 8],
    "japanese_yoshi": [0, 1, 5, 7, 10],
}

# ... (main logic will be added in subsequent tasks)


def load_json(path: str) -> dict:
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def load_json_safe(path: str) -> dict | None:
    try:
        return load_json(path)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"Warning: Could not load {path}: {e}", file=sys.stderr)
        return None


def main():
    parser = argparse.ArgumentParser(description="Analyze melody from Clef JSON")
    parser.add_argument("--input", required=True, help="Path to Clef JSON (final or intermediate)")
    parser.add_argument("--planfile", help="Path to plan.json for section/chord info")
    parser.add_argument("--mode", choices=["jianpu", "checks", "all"], default="all")
    parser.add_argument("--track", help="Track name to analyze (default: auto-detect)")
    parser.add_argument("--output", help="Path for text output (default: stdout)")
    parser.add_argument("--ascii", action="store_true", help="ASCII-only output (no Unicode)")
    args = parser.parse_args()
    print("analyze_melody.py loaded successfully")


if __name__ == "__main__":
    main()
```

**Step 2: 运行验证脚本能启动**

Run: `python .claude/skills/clef-compose/scripts/analyze_melody.py --input addons/clef/output/jrpg_battle_loop.json`
Expected: 输出 "analyze_melody.py loaded successfully"

**Step 3: Commit**

```bash
git add .claude/skills/clef-compose/scripts/analyze_melody.py
git commit -m "feat(clef): add analyze_melody.py script skeleton with CLI"
```

---

### Task 2: 实现 MusicData 加载和调性解析

**Files:**
- Modify: `.claude/skills/clef-compose/scripts/analyze_melody.py`

**Step 1: 实现 MusicData dataclass 和输入加载**

在 Task 1 的骨架中添加：

```python
@dataclass
class MusicData:
    notes: list[dict]
    root_pitch: int
    scale_name: str
    scale_intervals: list[int]
    time_signature: str
    beats_per_measure: float
    sections: list[dict]
    track_name: str


def parse_key(key_str: str) -> tuple[int, str]:
    """Parse key string like 'D minor' -> (62, 'natural_minor')."""
    if not key_str:
        return 60, "major"
    key_str = key_str.strip()
    # Try direct scale_notes array from plan.json (list of ints)
    # Otherwise parse "X scale_name" format
    parts = key_str.lower().split()
    note_part = parts[0]
    scale_part = parts[1] if len(parts) > 1 else "minor"  # default minor

    # Handle accidentals
    root = ROOT_PITCHES.get(note_part[0].upper(), 60)
    if len(note_part) > 1 and note_part[1] == "#":
        root += 1
    elif len(note_part) > 1 and note_part[1] == "b":
        root -= 1

    # Map scale name variants
    scale_map = {
        "major": "major", "ionian": "major",
        "minor": "natural_minor", "natural_minor": "natural_minor", "aeolian": "natural_minor",
        "harmonic": "harmonic_minor", "harmonic_minor": "harmonic_minor",
        "melodic": "melodic_minor", "melodic_minor": "melodic_minor",
        "dorian": "dorian", "phrygian": "phrygian",
        "lydian": "lydian", "mixolydian": "mixolydian",
        "pentatonic": "pentatonic_major", "pentatonic_major": "pentatonic_major",
        "pentatonic_minor": "pentatonic_minor", "penta_minor": "pentatonic_minor",
        "blues": "blues",
    }
    scale_name = scale_map.get(scale_part, "major")
    return root, scale_name


def load_music_data(input_path: str, plan_path: str | None, track_name: str | None) -> MusicData:
    """Load Clef JSON and plan.json into unified MusicData."""
    data = load_json(input_path)

    # Detect format: final Clef JSON vs intermediate melody.json
    if "tracks" in data:
        # Final Clef JSON
        tracks = data["tracks"]
        if track_name:
            track = next((t for t in tracks if t.get("name") == track_name), None)
        else:
            # Auto-detect melody track
            for name in ["Melody", "Lead", "Solo", "Lead Synth"]:
                track = next((t for t in tracks if t.get("name", "").lower() == name.lower()), None)
                if track:
                    break
            if not track:
                track = tracks[0] if tracks else None
        if not track:
            raise ValueError("No melody track found")
        notes = sorted(track.get("notes", []), key=lambda n: n["start"])
        actual_track_name = track.get("name", "Unknown")
    else:
        # Intermediate melody.json
        notes = sorted(data.get("notes", []), key=lambda n: n["start"])
        actual_track_name = data.get("track_name", data.get("name", "Melody"))

    # Load plan.json
    plan = load_json_safe(plan_path) if plan_path else None
    root_pitch = 60
    scale_name = "major"
    time_signature = data.get("time_signature", "4/4")
    sections = []

    if plan:
        root_pitch, scale_name = parse_key(plan.get("key", ""))
        time_signature = plan.get("time_signature", time_signature)
        sections = plan.get("sections", [])
        # If plan has scale_notes directly, use them
        if "scale_notes" in plan and isinstance(plan["scale_notes"], list):
            # Derive intervals from the notes
            root_note = plan["scale_notes"][0]
            scale_name = "custom"
            # (custom scale handling can be added later)

    scale_intervals = SCALE_DEFINITIONS.get(scale_name, [0, 2, 4, 5, 7, 9, 11])
    beats_per_measure = float(time_signature.split("/")[0])

    return MusicData(
        notes=notes,
        root_pitch=root_pitch,
        scale_name=scale_name,
        scale_intervals=scale_intervals,
        time_signature=time_signature,
        beats_per_measure=beats_per_measure,
        sections=sections,
        track_name=actual_track_name,
    )
```

**Step 2: 测试加载 jrpg_battle_loop.json**

在 main() 中临时调用 `load_music_data` 并打印基本信息，确认能正确解析。

**Step 3: Commit**

```bash
git add .claude/skills/clef-compose/scripts/analyze_melody.py
git commit -m "feat(clef): implement MusicData loading and key parsing"
```

---

### Task 3: 实现简谱转换

**Files:**
- Modify: `.claude/skills/clef-compose/scripts/analyze_melody.py`

**Step 1: 实现 pitch_to_jianpu 和简谱格式化**

```python
def pitch_to_jianpu(pitch: int, root_pitch: int, scale_intervals: list[int]) -> tuple[int, int]:
    """Convert MIDI pitch to (degree_number, octave_offset)."""
    # Find which octave this pitch is in relative to root
    semitones_from_root = (pitch - root_pitch) % 12
    octave_offset = (pitch - root_pitch) // 12

    # Find the closest scale degree
    best_degree = 1
    best_dist = 12
    for i, interval in enumerate(scale_intervals):
        dist = abs(semitones_from_root - interval)
        if dist < best_dist:
            best_dist = dist
            best_degree = i + 1

    # Check for accidentals (non-scale tones)
    is_scale_tone = any(abs(semitones_from_root - iv) == 0 for iv in scale_intervals)
    accidental = ""
    if not is_scale_tone:
        # Determine if sharp or flat
        if semitones_from_root > 0 and semitones_from_root < 6:
            accidental = "#"  # simplified
        else:
            accidental = "b"

    return best_degree, octave_offset


def format_duration(dur: float, ascii_mode: bool) -> str:
    """Format note duration in jianpu notation."""
    if dur >= 3.75:
        return " - - -"
    elif dur >= 1.75:
        dashes = int(dur) - 1
        return " -" * max(dashes, 1)
    elif dur >= 1.25:
        return "."
    elif dur >= 0.75:
        return "." if not ascii_mode else "."
    elif dur >= 0.35:
        return "\u0332" if not ascii_mode else "_"  # eighth note
    else:
        return "\u0308" if not ascii_mode else "__"  # sixteenth


def generate_jianpu(music: MusicData, ascii_mode: bool = False) -> str:
    """Generate jianpu notation string."""
    root_name = NOTE_NAMES[music.root_pitch % 12]
    lines = []
    lines.append(f"1={root_name}  {music.time_signature}")
    lines.append(f"Track: {music.track_name}  |  Notes: {len(music.notes)}")
    lines.append("")

    current_octave = 0
    measure_beats = 0.0

    for section in music.sections:
        sec_id = section.get("id", "?")
        lines.append(f"[{sec_id}]")

    for i, note in enumerate(music.notes):
        degree, octave = pitch_to_jianpu(note["pitch"], music.root_pitch, music.scale_intervals)

        # Octave change marker
        octave_marker = ""
        if octave != current_octave:
            if octave > current_octave:
                octave_marker = "'" * (octave - current_octave) if ascii_mode else "\u0307" * (octave - current_octave)
            else:
                octave_marker = "," * (current_octave - octave) if ascii_mode else "\u0323" * (current_octave - octave)
            current_octave = octave

        # Duration marker
        dur_str = format_duration(note["duration"], ascii_mode)

        # Bar line check
        beat_in_measure = note["start"] % music.beats_per_measure
        bar_line = "| " if beat_in_measure < 0.01 and i > 0 else ""

        lines.append(f"{bar_line}{degree}{octave_marker}{dur_str}")

    return "\n".join(lines)
```

**Step 2: 运行简谱输出**

Run: `python .claude/skills/clef-compose/scripts/analyze_melody.py --input addons/clef/output/jrpg_battle_loop.json --mode jianpu`
Expected: 输出简谱文本，包含小节线、八度标记

**Step 3: Commit**

```bash
git add .claude/skills/clef-compose/scripts/analyze_melody.py
git commit -m "feat(clef): implement jianpu conversion with duration and octave markers"
```

---

### Task 4: 实现合规检查框架和 6 项检查

**Files:**
- Modify: `.claude/skills/clef-compose/scripts/analyze_melody.py`

**Step 1: 实现检查框架和 6 项检查**

```python
@dataclass
class CheckResult:
    check_id: str
    status: str  # "PASS" | "WARN" | "FAIL"
    message: str
    details: list[str] = field(default_factory=list)


def check_large_leaps(notes: list[dict]) -> CheckResult:
    """Flag intervals > 5 semitones without passing tone."""
    details = []
    for i in range(len(notes) - 1):
        interval = abs(notes[i + 1]["pitch"] - notes[i]["pitch"])
        if interval > 8:
            details.append(f"  beat {notes[i]['start']:.1f}: {notes[i]['pitch']}->{notes[i+1]['pitch']} ({interval:+d})")
    status = "FAIL" if len(details) > 0 else "PASS"
    return CheckResult("large_leap", status,
        f"{len(details)} large leaps (>8 semitones) found" if details else "No problematic large leaps",
        details)


def check_section_transition(notes: list[dict], sections: list[dict]) -> CheckResult:
    """Flag register shifts > 3 semitones at section boundaries."""
    if not sections:
        return CheckResult("section_transition", "PASS", "No section data")
    details = []
    for sec in sections:
        end_beat = sec["end_beat"]
        # Find last note in section and first note after
        last_in = [n for n in notes if n["start"] < end_beat]
        first_out = [n for n in notes if n["start"] >= end_beat]
        if last_in and first_out:
            shift = abs(first_out[0]["pitch"] - last_in[-1]["pitch"])
            if shift > 3:
                details.append(f"  {sec['id']} boundary (beat {end_beat}): {last_in[-1]['pitch']}->{first_out[0]['pitch']} ({shift:+d})")
    status = "FAIL" if len(details) > 0 else "PASS"
    return CheckResult("section_transition", status,
        f"{len(details)} abrupt register shifts found" if details else "Smooth section transitions",
        details)


def check_melody_range(notes: list[dict]) -> CheckResult:
    """Verify melody stays within 1.5 octaves (18 semitones)."""
    pitches = [n["pitch"] for n in notes]
    range_semitones = max(pitches) - min(pitches)
    status = "PASS" if range_semitones <= 18 else "WARN"
    return CheckResult("melody_range", status,
        f"Range: {min(pitches)}-{max(pitches)} ({range_semitones} semitones, limit 18)")


def check_velocity_variation(notes: list[dict]) -> CheckResult:
    """Verify velocity spread >= 20."""
    vels = [n["velocity"] for n in notes]
    spread = max(vels) - min(vels)
    unique = len(set(vels))
    if spread < 20:
        status = "FAIL"
    elif unique < 3:
        status = "WARN"
    else:
        status = "PASS"
    return CheckResult("velocity_variation", status,
        f"Velocity range: {min(vels)}-{max(vels)} (spread: {spread}, unique values: {unique})")


def check_grid_alignment(notes: list[dict]) -> CheckResult:
    """Verify notes on 0.25 beat grid."""
    off_grid = []
    for n in notes:
        if abs((n["start"] * 4) % 1 - round(n["start"] * 4) % 1) > 0.01:
            off_grid.append(f"  beat {n['start']:.2f}")
    status = "PASS" if not off_grid else "FAIL"
    return CheckResult("grid_alignment", status,
        f"All notes on 0.25 beat grid" if not off_grid else f"{len(off_grid)} notes off grid",
        off_grid)


def check_note_continuity(notes: list[dict]) -> CheckResult:
    """Check for gaps > 1 beat in melody."""
    gaps = []
    for i in range(len(notes) - 1):
        gap = notes[i + 1]["start"] - (notes[i]["start"] + notes[i]["duration"])
        if gap > 1.0:
            gaps.append(f"  beat {notes[i]['start'] + notes[i]['duration']:.1f}-{notes[i+1]['start']:.1f} ({gap:.1f} beats)")
    status = "PASS" if len(gaps) == 0 else "WARN"
    return CheckResult("note_continuity", status,
        f"Melody is continuous" if not gaps else f"{len(gaps)} gaps > 1 beat found",
        gaps)


def run_checks(music: MusicData) -> list[CheckResult]:
    """Run all compliance checks."""
    return [
        check_large_leaps(music.notes),
        check_section_transition(music.notes, music.sections),
        check_melody_range(music.notes),
        check_velocity_variation(music.notes),
        check_grid_alignment(music.notes),
        check_note_continuity(music.notes),
    ]


def format_report(results: list[CheckResult]) -> str:
    """Format check results as human-readable report."""
    lines = []
    pass_count = sum(1 for r in results if r.status == "PASS")
    warn_count = sum(1 for r in results if r.status == "WARN")
    fail_count = sum(1 for r in results if r.status == "FAIL")

    lines.append(f"=== Compliance Report: {pass_count} PASS, {warn_count} WARN, {fail_count} FAIL ===")
    lines.append("")
    for r in results:
        icon = {"PASS": "[PASS]", "WARN": "[WARN]", "FAIL": "[FAIL]"}[r.status]
        lines.append(f"{icon} {r.check_id:20s} - {r.message}")
        for d in r.details:
            lines.append(d)
    lines.append("")
    return "\n".join(lines)
```

**Step 2: 运行合规检查**

Run: `python .claude/skills/clef-compose/scripts/analyze_melody.py --input addons/clef/output/jrpg_battle_loop.json --mode checks`
Expected: 输出合规报告，large_leap 和 section_transition 应有 WARN/FAIL

**Step 3: Commit**

```bash
git add .claude/skills/clef-compose/scripts/analyze_melody.py
git commit -m "feat(clef): implement 6 compliance checks for melody analysis"
```

---

### Task 5: 组装 main() 并集成 --mode all

**Files:**
- Modify: `.claude/skills/clef-compose/scripts/analyze_melody.py`

**Step 1: 更新 main() 使用 load_music_data + generate_jianpu + run_checks**

替换 main() 中的临时代码为完整流程：

```python
def main():
    parser = argparse.ArgumentParser(description="Analyze melody from Clef JSON")
    parser.add_argument("--input", required=True, help="Path to Clef JSON")
    parser.add_argument("--planfile", help="Path to plan.json")
    parser.add_argument("--mode", choices=["jianpu", "checks", "all"], default="all")
    parser.add_argument("--track", help="Track name to analyze")
    parser.add_argument("--output", help="Output file path (default: stdout)")
    parser.add_argument("--ascii", action="store_true", help="ASCII-only output")
    args = parser.parse_args()

    music = load_music_data(args.input, args.planfile, args.track)

    output_parts = []

    if args.mode in ("jianpu", "all"):
        output_parts.append(generate_jianpu(music, ascii_mode=args.ascii))
        output_parts.append("")

    if args.mode in ("checks", "all"):
        results = run_checks(music)
        output_parts.append(format_report(results))

    output = "\n".join(output_parts)

    if args.output:
        Path(args.output).write_text(output, encoding="utf-8")
        print(f"Wrote analysis to {args.output}")
    else:
        print(output)

    # Exit code
    has_fail = any(r.status == "FAIL" for r in results) if args.mode in ("checks", "all") else False
    sys.exit(1 if has_fail else 0)
```

**Step 2: 运行完整分析**

Run: `python .claude/skills/clef-compose/scripts/analyze_melody.py --input addons/clef/output/jrpg_battle_loop.json`
Expected: 简谱 + 合规报告完整输出

**Step 3: Commit**

```bash
git add .claude/skills/clef-compose/scripts/analyze_melody.py
git commit -m "feat(clef): assemble analyze_melody.py with full --mode all support"
```

---

### Task 6: 修复 SKILL.md Step 6b CLI 调用语法

**Files:**
- Modify: `.claude/skills/clef-compose/SKILL.md` (Step 6b 脚本调用行)

**Step 1: 查找并修复 generate_expression.py 的调用语法**

SKILL.md Step 6b 当前写的是：
```
python .claude/skills/clef-compose/scripts/generate_expression.py .clef-work/expression_plan.json --workdir .clef-work --output .clef-work/expression.json
```

应改为（与 Orchestrator agent 和实际 argparse 一致）：
```
python .claude/skills/clef-compose/scripts/generate_expression.py --plan .clef-work/expression_plan.json --workdir .clef-work --output .clef-work/expression.json
```

**Step 2: 验证 generate_expression.py 的 argparse 定义**

Run: `python .claude/skills/clef-compose/scripts/generate_expression.py --help`
Expected: 确认 `--plan` 是 required positional-style named argument

**Step 3: Commit**

```bash
git add .claude/skills/clef-compose/SKILL.md
git commit -m "fix(clef): correct generate_expression.py CLI syntax in SKILL.md Step 6b"
```

---

### Task 7: 同步单 Agent Step 3 旋律约束

**Files:**
- Modify: `.claude/skills/clef-compose/SKILL.md` (Step 3 旋律生成约束)

**Step 1: 在 Step 3 的旋律约束中添加大跳和段落过渡规则**

在 SKILL.md Step 3 的"乐句衔接技巧"部分后添加（与 clef-composer.md 保持一致）：

```markdown
**大跳处理：** 相邻音符音程 > 5 半音时，必须插入经过音（跳进 → 经过音 → 目标音）。例外：段落开头可有一个大跳作为起句，但必须立即反向级进收回。

**段落过渡：** 段落切换时旋律音区变化不得超过 3 半音，需在段落末尾 2-4 拍内通过级进逐步过渡。
```

**Step 2: 确认与 clef-composer.md 措辞一致**

对比两个文件中的约束描述，确保无矛盾。

**Step 3: Commit**

```bash
git add .claude/skills/clef-compose/SKILL.md
git commit -m "fix(clef): sync melody large-leap and section-transition constraints to Step 3"
```

---

### Task 8: 将 analyze_melody.py 集成到 SKILL.md Step 8

**Files:**
- Modify: `.claude/skills/clef-compose/SKILL.md` (Step 8 自评部分)

**Step 1: 在 Step 8a 自评前添加可选的旋律分析调用**

在 Step 8 的 `8a. 音乐质量评分` 之前添加：

```markdown
**8a-pre. 旋律分析（可选，推荐多 Agent 模式使用）**

运行旋律分析工具获取结构化数据：
```bash
python .claude/skills/clef-compose/scripts/analyze_melody.py --input .clef-work/final.json --planfile .clef-work/plan.json
```

- 简谱输出：目视检查旋律轮廓、段落过渡、音区变化
- 合规报告：如有 FAIL 项，必须在评分前修复
```

同时将原 8a/8b 重新编号为 8b/8c。

**Step 2: 验证 SKILL.md 整体结构连贯**

确认 Step 编号连续，MA-Step 8 引用正确。

**Step 3: Commit**

```bash
git add .claude/skills/clef-compose/SKILL.md
git commit -m "feat(clef): integrate analyze_melody.py into Step 8 self-evaluation"
```

---

### Task 9: 用 jrpg_battle_loop.json 验证完整流程

**Step 1: 运行简谱模式**

Run: `python .claude/skills/clef-compose/scripts/analyze_melody.py --input addons/clef/output/jrpg_battle_loop.json --mode jianpu`
Expected: 可读的简谱输出，包含小节线和音符时值

**Step 2: 运行合规检查模式**

Run: `python .claude/skills/clef-compose/scripts/analyze_melody.py --input addons/clef/output/jrpg_battle_loop.json --mode checks`
Expected: 至少 large_leap 和 section_transition 报告 FAIL/WARN（因为这是已知有问题的输出）

**Step 3: 运行 ASCII 模式**

Run: `python .claude/skills/clef-compose/scripts/analyze_melody.py --input addons/clef/output/jrpg_battle_loop.json --ascii`
Expected: 纯 ASCII 输出，无 Unicode 字符

**Step 4: 确认退出码**

Run 以上命令后检查 `$?`，有 FAIL 时应为 1，全 PASS 时应为 0。

**Step 5: 最终 Commit（如有修复）**

```bash
git add .claude/skills/clef-compose/scripts/analyze_melody.py
git commit -m "fix(clef): harden analyze_melody.py based on E2E validation"
```
