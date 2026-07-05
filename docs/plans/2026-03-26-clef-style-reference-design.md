# Clef Phase 2: 风格参考系统设计

> 日期：2026-03-26
> 状态：设计完成，待实现
> 前置依赖：Phase 1 + Phase 2 迭代修复已完成

## 目标

用户可以提供一个或多个 Clef JSON 文件作为风格参考，LLM 分析后生成具有相似风格感觉的新曲。

## 用户交互

```
/clef-compose 为一个村庄场景作曲 --ref addons/clef/output/japanese_village.json
/clef-compose Boss战音乐 --ref boss_battle.json epic_orchestra.json
```

`--ref` 参数接受一个或多个 Clef JSON 文件路径。

## 工作流变化

在 Step 0（需求解析）和 Step 1（音乐规划）之间插入 Step R：

```
Step 0: 需求解析
Step R: 风格分析（新增，仅当 --ref 存在时执行）
Step 1: 音乐规划（受 style_profile 约束）
...
```

### Step R 执行流程

1. 读取所有参考 JSON 文件
2. 多文件时检测风格冲突，询问用户以哪个为主参考
3. 分析每个文件，提取风格特征
4. 合并特征，输出 `.clef-work/style_profile.json`

### 冲突检测

| 维度 | 冲突阈值 |
|------|----------|
| 调性 | 不同调性 |
| BPM | 差异 > 30% |
| 配器重叠 | 交集 < 30% |
| 段落数 | 差异 > 1 |

冲突时询问用户选择主参考，主参考权重 0.7，次参考 0.3。

## style_profile.json 结构

```json
{
  "references": ["japanese_village.json"],
  "primary": "japanese_village.json",
  "secondary": [],
  "merge_weights": { "primary": 1.0 },
  "merged_features": {
    "tempo_range": { "min": 76, "max": 76, "suggested": 76 },
    "key": "D pentatonic major",
    "scale_notes": [62, 64, 66, 69, 71],
    "time_signature": "4/4",
    "form": "AB",
    "track_count": 5,
    "tracks": [
      {
        "name": "Flute", "instrument": 73, "channel": 0, "role": "melody",
        "pitch_range": { "min": 62, "max": 76 },
        "velocity_range": { "min": 63, "max": 88 },
        "rhythm_density": "sparse",
        "characteristics": "弱起进入，长音为主，经过音衔接"
      }
    ],
    "chord_progressions": {
      "A": ["D", "E", "A", "D"],
      "B": ["F#m", "B", "A", "D"]
    },
    "dynamics_curve": "渐进式，B段比A段力度高10-15",
    "expression_features": "CC11渐变为主，少量弯音装饰",
    "percussion_style": "极简踩镲点缀，velocity 35-40"
  }
}
```

关键字段说明：
- `role` — LLM 自动判断轨道角色（melody/harmony/bass/pad/percussion）
- `characteristics` — 自然语言风格描述，比纯数值更有指导意义
- `suggested` — 多文件时取平均值 ± 10%，单文件直接用原值

## 多文件合并策略

| 特征 | 单文件 | 多文件 |
|------|--------|--------|
| tempo | 原值 | 平均值 ± 10% 为 suggested |
| key | 原值 | 第一个文件优先（冲突时由用户决定） |
| scale_notes | 原值 | 交集，空则取第一个 |
| form | 原值 | 取最短的 |
| tracks/配器 | 全部保留 | 按角色分组，同角色取范围并集 |
| chord_progressions | 全部保留 | 都作为候选选项 |

**优先级：** 用户明确指定 > 多文件参考合并 > 单文件参考 > Skill 默认值

## 对现有步骤的约束

**Step 1 音乐规划（重约束）：**
- 调性直接使用 style_profile.key
- BPM 使用 suggested，允许 ±10% 浮动
- 形式参考 style_profile.form
- 配器同角色乐器优先选用

**Step 2 和弦骨架（中约束）：**
- chord_progressions 作为候选池，允许借鉴和变化

**Step 3 旋律生成（轻约束）：**
- characteristics 作为风格指导
- pitch_range / rhythm_density 作为参考范围

**Step 4-5 低音/鼓组（轻约束）：**
- 参考 rhythm_density 和 percussion_style

**Step 6 表现力（轻约束）：**
- expression_features 作为参考，不强制复制

核心原则：风格参考是"启发性约束"而非"强制复制"。

## 用户反馈映射新增

```json
{
  "更接近参考": ["收紧调性约束", "配器与参考曲一致", "节奏密度靠拢", "和弦进行更接近"],
  "不要太像参考": ["允许近关系调", "引入新音色", "节奏型做区别", "和弦做更大变化"]
}
```

## 实现范围

| 文件 | 变更 |
|------|------|
| `SKILL.md` | Step 0 增加 --ref 解析；新增 Step R；Step 1-6 增加约束说明；反馈映射新增 2 条 |

只改 SKILL.md 一个文件。LLM 天然擅长分析 JSON 结构，不需要额外的分析脚本。
