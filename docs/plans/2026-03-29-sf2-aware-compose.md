# SF2-Aware Compose 实现方案

> 让 Clef Compose 作曲流水线感知目标 SF2 特性，生成针对特定音色库优化的 MIDI 音乐

## 需求重述

**问题：** Clef Compose 生成的 MIDI 假设标准 GM 音色参数，但不同 SF2 的 key_range、velocity_range、ADSR、采样质量差异很大，导致同一曲子在不同 SF2 下效果差异明显。

**目标：** 在不破坏现有流程的前提下，增加 SF2 感知层：
1. 分析目标 SF2 的乐器特性，生成结构化 profile
2. 作曲 Agent 根据 profile 调整音域、力度、表现力策略
3. 验证器用 SF2 实际范围替代硬编码范围
4. 不指定 SF2 时完全向后兼容

---

## 架构设计

```
                    ┌─────────────────┐
                    │   SF2 文件       │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │ sf2_profiler.py │  ← Phase 1
                    │  (Python 脚本)   │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │ sf2_profile.json│  ← 存入 knowledge/
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
     ┌────────▼────┐ ┌──────▼──────┐ ┌─────▼──────┐
     │ plan.json   │ │ validate_abc│ │ Agent 提示 │  ← Phase 2-4
     │ sf2_profile │ │ 实际 range  │ │ SF2 约束   │
     │ 字段扩展    │ │ 替代硬编码  │ │ 集成       │
     └─────────────┘ └─────────────┘ └───────────┘
```

---

## Phase 1: SF2 Profiler 工具

### 1.1 创建 `sf2_profiler.py`

**位置：** `.claude/skills/clef-compose/scripts/sf2_profiler.py`

**依赖：** 纯 Python，不引入新库。SF2 是 RIFF 二进制格式，可直接用 `struct` 解析（参考已有的 GDScript `sf2_reader.gd`）。

**功能：** 读取 SF2 文件，提取每个 Preset 的关键参数，输出 JSON profile。

**命令行接口：**
```bash
# 完整 profile（所有 preset）
python scripts/sf2_profiler.py <sf2_path> -o <output.json>

# 仅指定 preset（减少输出体积）
python scripts/sf2_profiler.py <sf2_path> -o <output.json> --presets 0,48,73

# 列出所有 preset 名称
python scripts/sf2_profiler.py <sf2_path> --list
```

**输出 JSON 结构（两层设计）：**

```json
{
  "sf2_name": "GeneralUser-GS",
  "version": "2.04",
  "sample_rate": 44100,
  "preset_count": 256,

  "presets": {
    "0": {
      "name": "Acoustic Grand Piano",
      "gm_name": "piano",
      "key_range": [0, 127],
      "vel_range": [1, 127],
      "sweet_spot": [36, 96],
      "vel_layers": 3,
      "avg_attack": 0.005,
      "avg_release": 0.8,
      "quality": "high",
      "characteristics": ["bright", "percussive"]
    },
    "48": {
      "name": "String Ensemble 1",
      "gm_name": "strings",
      "key_range": [0, 127],
      "vel_range": [1, 127],
      "sweet_spot": [36, 84],
      "vel_layers": 2,
      "avg_attack": 0.12,
      "avg_release": 1.5,
      "quality": "medium",
      "characteristics": ["warm", "sustained"]
    }
  }
}
```

**关键字段说明：**

| 字段 | 来源 | 用途 |
|------|------|------|
| `key_range` | Preset zones 聚合 | Agent 不可超出此范围 |
| `vel_range` | Preset zones 聚合 | 力度标记有效范围 |
| `sweet_spot` | 采样密度最高区域（zone 边界内最密集的 2-3 个八度） | Agent 优先在此区间写旋律 |
| `vel_layers` | 不同 vel_range zone 数量 | 单层 SF2 不需要细腻 velocity_offset |
| `avg_attack/release` | Instrument zones ADSR 均值 | 快速琶音 vs 慢板的决定因素 |
| `quality` | 采样数 + vel_layers 启发式评分 | 配器选择参考 |
| `characteristics` | 从 ADSR + 采样类型推导 | 音乐风格匹配 |

**`sweet_spot` 算法：**
```
1. 收集该 preset 所有 instrument zone 的 key_range
2. 统计每个 MIDI key 被多少个 zone 覆盖
3. 找到覆盖密度最高的连续区间（至少 2 个八度）
4. 若无明显密度差异，取 zone 边界的中间 2 个八度
```

**`quality` 启发式评分：**
```
score = zone_count * 2 + vel_layers * 3 + unique_samples * 1
high:   score >= 15
medium: score >= 8
low:    score < 8
```

### 1.2 为 3 个 SF2 生成 profile

```bash
python scripts/sf2_profiler.py third_party_resources/GeneralUser-GS/GeneralUser-GS.sf2 \
  -o addons/clef/knowledge/sf2_generaluser_gs.json --presets 0,24,25,32,33,34,40,48,56,73

python scripts/sf2_profiler.py third_party_resources/ColomboGMGS2.sf2 \
  -o addons/clef/knowledge/sf2_colombo.json --presets 0,24,25,32,33,34,40,48,56,73

python scripts/sf2_profiler.py third_party_resources/Jnsgm.sf2 \
  -o addons/clef/knowledge/sf2_jnsgm.json --presets 0,24,25,32,33,34,40,48,56,73
```

**涉及文件：**
- 新建：`.claude/skills/clef-compose/scripts/sf2_profiler.py`
- 新建：`addons/clef/knowledge/sf2_generaluser_gs.json`
- 新建：`addons/clef/knowledge/sf2_colombo.json`
- 新建：`addons/clef/knowledge/sf2_jnsgm.json`

---

## Phase 2: Plan.json 集成

### 2.1 扩展 plan.json 结构

在 `orchestration` 中每个声部增加 `sf2` 子对象：

```json
{
  "orchestration": {
    "melody": {
      "name": "Flute",
      "channel": 0,
      "instrument": 73,
      "range": "C4-C7",
      "register": "C5-C6",
      "sf2": {
        "key_range": [0, 127],
        "sweet_spot": [60, 84],
        "vel_range": [1, 127],
        "vel_layers": 2,
        "avg_attack": 0.08,
        "avg_release": 0.5,
        "quality": "medium",
        "characteristics": ["bright", "breathy"]
      }
    }
  }
}
```

### 2.2 Step 0 需求解析扩展

用户可通过 `--sf2` 参数指定目标 SF2：

```
/clef-compose boss battle, 30s --sf2 GeneralUser-GS
```

SKILL.md 流程调整：
1. Step 0 需求解析时，若 `--sf2` 存在，查找 `addons/clef/knowledge/sf2_<name>.json`
2. 读取 profile，在 plan.json 生成时自动填充每个声部的 `sf2` 字段
3. plan.json 的 `range` 和 `register` 字段根据 `sf2.sweet_spot` 调整（而非通用 GM 范围）
4. **用户确认点 1** 展示时额外显示 SF2 特性摘要

### 2.3 SKILL.md 修改

**位置：** `.claude/skills/clef-compose/SKILL.md`

在 Step 0 需求解析中增加 SF2 选项：
```
- 目标 SF2: 可选（如 "GeneralUser-GS"、"ColomboGMGS2"、"Jnsgm"）
  - 指定后自动加载 addons/clef/knowledge/sf2_<name>.json
  - 不指定时行为与现在完全一致（向后兼容）
```

**涉及文件：**
- 修改：`.claude/skills/clef-compose/SKILL.md`（Step 0 + Step 1a）

---

## Phase 3: 验证器增强

### 3.1 validate_abc.py 增加动态 range 支持

**当前行为：** `check_pitch_range` 使用硬编码的 `INSTRUMENT_RANGES` 字典。

**改为：**
1. 接受 `--sf2-profile` 参数
2. 若提供 profile，从中读取对应 GM# 的 `key_range` 替代硬编码值
3. 额外检查：音符是否在 `sweet_spot` 内（WARN 级别，非 FAIL）
4. 不提供 profile 时 fallback 到现有 `INSTRUMENT_RANGES`

```python
# validate_abc.py 新增参数
parser.add_argument('--sf2-profile', type=str, default=None,
                    help='Path to SF2 profile JSON for dynamic range checking')
```

**新增检查项：**

| 检查项 | 类别 | 严重级 | 说明 |
|--------|------|--------|------|
| `sweet_spot_adherence` | 甜区覆盖 | WARN | 超过 30% 的音符落在 sweet_spot 外 |

### 3.2 INSTRUMENT_RANGES 保留为 fallback

不删除现有字典，仅在 profile 存在时覆盖。

**涉及文件：**
- 修改：`.claude/skills/clef-compose/scripts/validate_abc.py`

---

## Phase 4: Agent 提示词增强

### 4.1 Composer Agent（旋律创作）

**位置：** `.claude/agents/clef-composer.md`

增加 SF2 约束段落（当 plan.json 中存在 `sf2` 字段时生效）：

```markdown
## SF2 音色库约束（当 plan.json 声部包含 sf2 字段时生效）

### 硬约束
- 音符 pitch 不得超出 sf2.key_range
- 旋律主体（>70% 音符）应落在 sf2.sweet_spot 内
- 若 sf2.vel_layers == 1，不使用细腻的力度变化（velocity_offset 限制 ±5）

### 软建议
- sf2.avg_attack > 0.1s 时：避免密集的快速音符（十六分音符串），否则声音会糊
- sf2.avg_release > 1.0s 时：音符间距可适当加大，利用自然延音
- sf2.characteristics 包含 "percussive" 时：适合断奏和节奏动机
- sf2.characteristics 包含 "sustained" 时：适合长音和 legato
```

### 4.2 Harmonist Agent（和声编配）

**位置：** `.claude/agents/clef-harmonist.md`

```markdown
## SF2 约束（同 Composer，但关注和声层）
- 和弦音域优先使用 sf2.sweet_spot（重叠度 >60%）
- sf2.quality == "low" 的乐器：简化织体，不要写密集和弦
```

### 4.3 Rhythmist Agent（低音+鼓）

**位置：** `.claude/agents/clef-rhythmist.md`

```markdown
## SF2 约束
- 低音线音域不超过 sf2.sweet_spot 下限（避免沉闷）
- sf2.avg_attack > 0.05s 的贝斯：避免极快的十六分低音线
```

### 4.4 Orchestrator Agent（表现力）

**位置：** `.claude/agents/clef-orchestrator.md`

```markdown
## SF2 感知表现力策略
- sf2.vel_layers == 1：cc11 曲线幅度限制在 ±15（单层采样无力度响应差异）
- sf2.avg_attack > 0.1s：cc11 起始值不低于 70（太弱时 attack 阶段不明显）
- sf2.quality == "high"：可使用更细腻的 velocity_offset（±15）
- sf2.quality == "low"：velocity_offset 限制在 ±5，依赖 CC7 做层次
```

### 4.5 Reviewer Agent（审核）

**位置：** `.claude/agents/clef-reviewer.md`

```markdown
## SF2 感知审核（当 profile 存在时）
- 检查各声部音符是否超出 sf2.key_range
- 检查 sweet_spot 覆盖率（WARN < 60%）
- 检查快速乐段是否与 sf2.avg_attack 冲突
```

**涉及文件：**
- 修改：`.claude/agents/clef-composer.md`
- 修改：`.claude/agents/clef-harmonist.md`
- 修改：`.claude/agents/clef-rhythmist.md`
- 修改：`.claude/agents/clef-orchestrator.md`
- 修改：`.claude/agents/clef-reviewer.md`

---

## 实施顺序与依赖

```
Phase 1 (sf2_profiler.py)
    │
    ├── 1a: 实现 SF2 二进制解析
    ├── 1b: 实现 profile 生成逻辑
    └── 1c: 为 3 个 SF2 生成 profile
    │
Phase 2 (plan.json 集成)  ← 依赖 Phase 1
    │
    ├── 2a: plan.json 结构扩展
    └── 2b: SKILL.md Step 0 流程调整
    │
Phase 3 (validate_abc 增强)  ← 依赖 Phase 1
    │
    └── 3a: 动态 range + sweet_spot 检查
    │
Phase 4 (Agent 提示词)  ← 依赖 Phase 2
    │
    ├── 4a: Composer/Harmonist/Rhythmist 约束
    └── 4b: Orchestrator/Reviewer 增强
```

---

## 风险评估

| 风险 | 严重级 | 概率 | 缓解措施 |
|------|--------|------|----------|
| 纯 Python SF2 解析性能差（大文件 >100MB） | MEDIUM | 低 | Colombo 约 200MB，可用 `--presets` 只解析需要的 preset；或只读 pdta 块跳过 sdta |
| Profile 与实际听感不一致（SF2 内部 modulator 影响响应） | MEDIUM | 中 | profile 提供的是"安全区间"，不是精确建模；Agent 将其作为参考而非绝对约束 |
| Agent 忽略 SF2 约束信息 | HIGH | 中 | 在 Agent 提示词中标记为"硬约束"，validate_abc 做兜底检查 |
| 新增 Python 依赖 | LOW | 极低 | 使用纯 Python struct 解析，不引入新库 |

---

## 复杂度估算

| Phase | 内容 | 复杂度 |
|-------|------|--------|
| Phase 1 | SF2 Profiler 脚本 | MEDIUM（SF2 二进制解析，约 300-400 行 Python） |
| Phase 2 | plan.json + SKILL.md 集成 | LOW（结构扩展 + 流程文字调整） |
| Phase 3 | validate_abc 增强 | LOW（约 30 行改动） |
| Phase 4 | 5 个 Agent 提示词 | LOW（各增加 10-15 行约束说明） |
| **总计** | | **MEDIUM** |

---

## 待确认问题

1. **SF2 文件大小**：ColomboGMGS2.sf2 约 200MB，是否接受纯 Python 解析的耗时？还是需要预生成 profile 后只存 JSON？
2. **Profile 覆盖范围**：是否需要覆盖全部 128+ GM 乐器，还是只覆盖 plan.json 中实际使用的？
3. **sweet_spot 算法**：基于 zone 密度的启发式是否可接受，还是需要更精确的采样质量评估？
