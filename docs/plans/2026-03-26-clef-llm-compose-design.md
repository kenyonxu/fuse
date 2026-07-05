# Clef LLM 作曲工作流设计

> 日期：2026-03-26
> 状态：Phase 2 迭代完成
> 阶段：Phase 1 — 知识增强的多步迭代 Skill

## 问题诊断

当前 Clef 的 LLM 集成是纯文档驱动（569 行系统提示词），用户手动复制到网页版 LLM。效果不佳的核心原因：

1. **旋律/和声质量差** — LLM 缺乏深层乐理推理能力
2. **结构/节奏混乱** — 一次性生成无法保证音乐结构的合理性
3. **缺乏表现力** — 力度变化、弯音、CC 事件使用不当或缺失

根本原因：音乐创作需要的知识深度远超一篇提示词能承载的范围，且网页版 LLM 无法迭代改进。

## 解决方案

在 Claude Code 中创建 `clef-compose` Skill，利用其工具调用、文件访问、多轮对话能力，实现：

- **知识增强** — Skill 内嵌结构化乐理知识，用户可按规范扩展
- **多步迭代生成** — 分步构建音乐，每步有明确约束和验证
- **自动验证与自评** — 技术验证 + 音乐质量评分 + 迭代改进
- **高层用户反馈** — 用户用自然语言迭代，不需要音乐专业知识

## 阶段规划

| 阶段 | 内容 | 核心交付物 |
|------|------|-----------|
| **Phase 1** | 知识增强的多步迭代 Skill | `clef-compose` Skill + 乐理知识库 |
| **Phase 2** | 样本分析与参考系统 | MIDI 分析工具 + 风格特征提取 |
| **Phase 3** | 多 Agent 专业流水线 | 和声/旋律/节奏/编排 Agent |
| **Phase 4** | 风格迁移与模板库 | 从 MIDI 提取模式 + 风格模板库 |

本文档详细描述 Phase 1。

## Phase 1 详细设计

### 1. 交互模型

**触发方式：** `/clef-compose <自然语言描述>`

**默认全自动：** 用户只需描述场景/情绪/风格，LLM 自动完成所有步骤。中间步骤对用户透明但不阻塞。

**高层反馈循环：**
```
/clef-compose 为一个像素风RPG游戏创作一段Boss战音乐，大约30秒，风格参考最终幻想

→ LLM 自动完成所有步骤
→ 输出 final.json + 可读的音乐分析报告
→ 用户听效果后给出高层反馈：
  - "节奏感再强一点"
  - "旋律太单调了"
  - "后半段应该更紧张"
  - "低音不够明显"
→ LLM 针对性修改（不从头来）
```

**用户画像：** 独立游戏开发者，有审美但没有音乐专业知识。反馈用自然语言，LLM 负责翻译成具体音乐参数。

### 2. Skill 工作流

#### Step 0: 需求解析

从用户描述中提取结构化参数：
- 场景类型（battle/peaceful/mystery/menu/shop 等）
- 情绪（紧张/欢快/悲伤/史诗/神秘 等）
- 风格参考（游戏名/音乐名/形容词）
- 时长（秒）
- 配器偏好（可选）
- 调性偏好（可选）

#### Step 1: 音乐规划

输出 `plan.json`：
- 调性（主调 + 可能的转调）
- BPM
- 拍号
- 歌曲形式（ABA / ABABC / through-composed 等）
- 段落划分（每段的时长、情绪、力度层次）
- 配器方案（每段使用哪些乐器/GM 音色）
- 音域范围

#### Step 2: 和弦骨架

输出 `chords.json`：
- 每个段落的和弦进行（使用音符号标注）
- 和弦时值
- 和弦转位/声部配置
- 关键张力点

#### Step 3: 旋律生成

输出 `melody.json`：
- 基于和弦骨架的旋律线
- 动机发展（重复、变奏、模进）
- 音域控制在合理范围
- 段落间的对比与发展

#### Step 4: 低音线

输出 `bass.json`：
- 基于和弦的低音进行
- 节奏模式（全音符、四分音符、八分音符 walking bass 等）
- 与旋律的配合

#### Step 5: 鼓组节奏

输出 `drums.json`：
- 基于 BPM 和风格的鼓点模式
- 段落间的节奏变化
- 过渡 fills
- 使用 channel 9 + GM 打击乐映射

#### Step 6: 表现力层

输出 `expression.json`：
- 力度变化曲线（段落渐强渐弱、高潮力度提升）
- 弯音事件（装饰音、滑音、颤音）
- CC 事件（音量变化、延音踏板、颤音轮）
- 表现力与结构的配合

#### Step 7: 整合验证

- 合并所有轨道为完整 Clef JSON
- 运行技术验证规则检查
- 自动修复所有技术问题

#### Step 8: 自评改进

- 使用自评检查清单对音乐质量评分
- 各维度评分（加权总分 < 7.5）时针对性修复
- 最多迭代 3 轮
- 输出最终 `final.json` + 音乐分析报告

### 3. 中间文件结构

工作过程中生成中间文件，用户可查看和干预：

```
.clef-work/
  plan.json        # Step 1: 音乐规划
  chords.json      # Step 2: 和弦骨架
  melody.json      # Step 3: 旋律
  bass.json        # Step 4: 低音线
  drums.json       # Step 5: 鼓组
  expression.json  # Step 6: 表现力层
  final.json       # 最终输出
  report.md        # 音乐分析报告
```

### 4. 乐理知识库（Skill 内嵌）

Skill 文件内嵌以下结构化乐理知识：

#### 4.1 音阶

```
大调:     [0, 2, 4, 5, 7, 9, 11]
自然小调: [0, 2, 3, 5, 7, 8, 10]
和声小调: [0, 2, 3, 5, 7, 8, 11]
旋律小调: [0, 2, 3, 5, 7, 9, 11]
多利亚:   [0, 2, 3, 5, 7, 9, 10]
弗里几亚: [0, 1, 3, 5, 7, 8, 10]
利底亚:   [0, 2, 4, 6, 7, 9, 11]
混合利底亚: [0, 2, 4, 5, 7, 9, 10]
五声大调: [0, 2, 4, 7, 9]
五声小调: [0, 3, 5, 7, 10]
布鲁斯:   [0, 3, 5, 6, 7, 10]
减音阶:   [0, 2, 3, 5, 6, 8, 9, 11]
全音阶:   [0, 2, 4, 6, 8, 10]
日本音阶: [0, 1, 5, 7, 8]
```

#### 4.2 和弦进行（按场景分类）

```json
{
  "通用": {
    "I-V-vi-IV": {"description": "流行万能进行", "mood": ["欢快", "温暖"]},
    "I-IV-V-I": {"description": "经典终止式", "mood": ["坚定", "完整"]},
    "I-vi-IV-V": {"description": "50年代进行", "mood": ["怀旧", "甜蜜"]},
    "ii-V-I": {"description": "爵士基础进行", "mood": ["优雅", "流动"]}
  },
  "battle": {
    "i-VII-VI-VII": {"description": "力量感进行", "mood": ["紧张", "激烈"]},
    "i-III-VII-VI": {"description": "暗黑力量", "mood": ["黑暗", "压迫"]},
    "i-iv-VII-III": {"description": "史诗战斗", "mood": ["史诗", "壮阔"]}
  },
  "peaceful": {
    "I-iii-IV-V": {"description": "宁静田园", "mood": ["平和", "自然"]},
    "I-ii-iii-IV": {"description": "温暖成长", "mood": ["温暖", "希望"]}
  },
  "mystery": {
    "i-iv-ii-V": {"description": "悬疑探索", "mood": ["神秘", "不安"]},
    "i-II-VII-i": {"description": "暗黑悬疑", "mood": ["黑暗", "诡异"]}
  },
  "emotional": {
    "vi-IV-I-V": {"description": "感伤流行", "mood": ["感伤", "思念"]},
    "I-V-vi-iii-IV-I-ii-V": {"description": "卡农进行", "mood": ["优雅", "深情"]}
  }
}
```

#### 4.3 节奏模式

鼓点模式（4/4 拍，以 16 分音符为最小单位）：
- 基础摇滚：Kick on 1,3 / Snare on 2,4 / HiHat on 8th notes
- 军队进行：Kick on 1,3 / Snare on 2,4 / HiHat on quarter notes
- 16拍电子：Kick on 1, 1-and, 3 / Snare on 2, 4 / HiHat on 16th notes
- Bossa Nova：特定的拉丁节奏型
- Waltz 3/4：Kick on 1 / Snare on 3 / HiHat on quarter notes

#### 4.4 配器原则

```
主旋律乐器: Piano(0), Violin(40), Flute(73), Lead Synth(80), Oboe(68)
副旋律/和声: Strings(48), Pad Synth(88), Organ(19), Guitar(24)
低音: Acoustic Bass(32), Electric Bass(33), Synth Bass(38), Contrabass(34)
打击乐: Channel 9 (GM Percussion Map)
氛围/Pad: Pad Synth(88), Strings(48), Choir(52), Atmosphere(99)
```

常见游戏音乐配器组合：
```
RPG村庄:   Piano + Strings + Flute + Light Percussion
RPG战斗:   Lead Synth + Distorted Guitar + Power Bass + Heavy Drums
RPG Boss:  Full Orchestra + Choir + Heavy Percussion + Brass
主菜单:    Piano + Strings + Pad + Light Percussion
恐怖场景:  Dark Pad + SFX Percussion + Sparse Melody
```

#### 4.5 表现力规则

力度曲线模式：
- 渐强：velocity 从 60 线性增加到 120
- 渐弱：velocity 从 120 线性减少到 60
- 突强：velocity 瞬间跳升 30+
- 高潮段落：整体 velocity 比普通段落高 20-30

弯音使用规则：
- 装饰音：8192 → 8704 → 8192（+1 半音滑回），时长 0.1-0.2s
- 吉他推弦：8192 → 9344（+2 半音），保持 0.5-1.0s
- 颤音：在目标音高 ±50 范围内振荡，频率 5-8Hz
- 滑音：从起始音高滑到目标音高，时长 0.05-0.3s

CC 事件规则：
- CC7 Volume：段落过渡时淡入淡出，范围 0-127
- CC11 Expression：乐句内的细微变化，范围 80-127
- CC1 Modulation：颤音/震音效果，开启时值 64
- CC64 Sustain：和弦伴奏时开启，旋律线不使用

#### 4.6 歌曲形式

```
简单二元 (A-B):     2 段，对比后返回
三段体 (A-B-A):     3 段，经典对称结构
通谱体:        不重复，持续发展
Rondo (A-B-A-C-A):  主部与插部交替
史诗 (A-B-C-B-D):   多段递进，用于 Boss 战
```

### 5. 用户可扩展知识规范

用户可在 `addons/clef/knowledge/` 目录下添加自定义知识文件，Skill 自动扫描加载。

**文件命名规范：** `<category>_<name>.json`

**支持的知识类别：**

```json
// chord_progressions_custom.json
{
  "custom_category_name": {
    "I-bVII-IV-I": {
      "description": "自定义和弦进行描述",
      "mood": ["情绪标签"],
      "usage_notes": "使用说明"
    }
  }
}
```

```json
// styles_custom.json
{
  "style_name": {
    "scales": ["音阶类型"],
    "chord_progressions": ["常用进行"],
    "rhythm_patterns": ["节奏描述"],
    "instrumentation": ["配器方案"],
    "expression_hints": ["表现力提示"]
  }
}
```

### 6. 技术验证规则

`validation_rules.json` 定义硬规则检查：

```json
{
  "rules": [
    {"id": "duration_positive", "check": "note.duration > 0", "severity": "error"},
    {"id": "pitch_range", "check": "0 <= note.pitch <= 127", "severity": "error"},
    {"id": "velocity_range", "check": "0 <= note.velocity <= 127", "severity": "error"},
    {"id": "drums_channel_9", "check": "percussion track uses channel 9", "severity": "error"},
    {"id": "polyphony_limit", "check": "simultaneous notes <= 32", "severity": "warning"},
    {"id": "notes_sorted", "check": "notes sorted by start time", "severity": "error"},
    {"id": "json_format", "check": "valid Clef JSON v1.1", "severity": "error"},
    {"id": "at_least_one_track", "check": "tracks.length >= 1", "severity": "error"},
    {"id": "track_has_notes", "check": "each track has non-empty notes", "severity": "error"},
    {"id": "tempo_range", "check": "40 <= tempo <= 300", "severity": "warning"}
  ]
}
```

### 7. 自评检查清单

`self_eval_checklist.json` 定义音乐质量评估维度：

```json
{
  "dimensions": [
    {
      "name": "旋律质量",
      "weight": 0.25,
      "checks": [
        "是否有明确的动机（2-4 音符的短乐句）？",
        "动机是否有发展（重复、变奏、模进）？",
        "音域是否在乐器合理范围内？",
        "旋律线是否有方向感（上行/下行/波浪）？",
        "是否有明确的高潮点？",
        "段落间旋律是否有足够的对比和联系？"
      ]
    },
    {
      "name": "和声质量",
      "weight": 0.25,
      "checks": [
        "和弦进行是否流畅自然？",
        "是否有合适的张力（属和弦/减和弦）和释放？",
        "和声节奏是否合理（不要每个拍都换和弦）？",
        "旋律音是否在和弦音上或合理的延伸音上？"
      ]
    },
    {
      "name": "节奏质量",
      "weight": 0.2,
      "checks": [
        "节拍感是否清晰稳定？",
        "鼓点模式是否与风格匹配？",
        "段落过渡是否有节奏变化？",
        "各轨道节奏层次是否分明？"
      ]
    },
    {
      "name": "表现力",
      "weight": 0.15,
      "checks": [
        "力度变化范围是否足够（至少 30+ 的跨度）？",
        "是否有段落级别的渐强渐弱？",
        "弯音事件使用是否合理（不过多不过少）？",
        "CC 事件是否增强了音乐表现？"
      ]
    },
    {
      "name": "结构质量",
      "weight": 0.15,
      "checks": [
        "歌曲形式是否清晰可辨？",
        "段落间对比是否明显？",
        "整体是否有起承转合？",
        "时长是否符合用户要求？"
      ]
    }
  ],
  "min_score": 7.5,
  "max_iterations": 3
}
```

### 8. 用户反馈映射

Skill 将用户的高层自然语言反馈映射到具体音乐参数修改：

```json
{
  "更紧张": ["BPM +10-20", "使用小调/和声小调", "增加不协和和弦", "力度范围上移", "节奏密度增加"],
  "更有节奏感": ["强化鼓点模式", "增加切分音", "低音更活跃", "BPM +5-10"],
  "旋律更丰富": ["增加动机变化", "使用模进发展", "扩展音域", "增加经过音"],
  "更史诗": ["增加乐器轨道", "使用全管弦配器", "加入合唱/Pad", "增加力度对比"],
  "更轻柔": ["减少乐器轨道", "降低BPM", "力度范围下移", "使用大调/五声音阶", "减少打击乐"],
  "更暗黑": ["使用小调/减音阶", "低音区为主", "加入不协和音", "使用挂留和弦"],
  "低音不够明显": ["低音力度 +15-20", "低音使用更低的音域", "减少低音区的其他乐器"],
  "太单调": ["增加旋律变化", "添加副旋律", "丰富鼓点", "增加段落对比"]
}
```

## 实现清单

### Phase 1 需要创建的文件

| 文件 | 说明 | 状态 |
|------|------|------|
| `.claude/skills/clef-compose.md` | 主 Skill 定义（工作流逻辑） | 已完成 |
| `addons/clef/knowledge/theory.md` | 核心乐理知识库 | 已完成 |
| `addons/clef/knowledge/README.md` | 用户扩展知识使用说明 | 已完成 |
| `addons/clef/templates/validation_rules.json` | 技术验证规则 | 已完成 |
| `addons/clef/templates/self_eval_checklist.json` | 自评检查清单 | 已完成 |

### Phase 1 需要创建的目录

| 目录 | 说明 | 状态 |
|------|------|------|
| `addons/clef/knowledge/` | 知识库 + 用户扩展目录 | 已完成 |

## Phase 1 执行记录（2026-03-26）

### 实施内容

1. **`.claude/skills/clef-compose/SKILL.md`** — 主 Skill（350 行）
   - 9 步工作流：需求解析→音乐规划→和弦→旋律→低音→鼓组→表现力→整合验证→自评改进→输出
   - 用户反馈映射表：12 种自然语言反馈→具体音乐参数修改
   - 通过 `## 必读文件` 段落引用 Skill 本地知识文件（theory.md、templates/*.json、knowledge/*.json）
   - Clef JSON 格式参考摘要（完整规则以 llm_compose_guide.json 为准）

2. **`.claude/skills/clef-compose/theory.md`** — 核心乐理知识库（208 行）
   - 14 种音阶（大调/小调/教会调式/五声/布鲁斯/减音阶/全音阶/日本音阶）
   - 30+ 和弦进行（按通用/战斗/和平/恐怖/情感 5 类分组）
   - 11 种和弦构建（Major/Minor/Dom7/Maj7/Dim/Aug/sus 等）
   - GM 乐器参考：旋律乐器(15种)、和声/Pad(10种)、低音(7种)、打击乐(10种)
   - 配器方案：11 种游戏场景推荐配器
   - 声部进行规则 + 6 种歌曲形式

3. **`addons/clef/knowledge/README.md`** — 用户扩展知识说明（58 行）
   - 支持三种扩展文件格式：chord_progressions_*.json、styles_*.json、rhythm_*.json
   - 文件命名规范和格式示例

4. **`addons/clef/templates/validation_rules.json`** — 技术验证规则
   - 9 类规则：format/track/note/percussion/polyphony/conflict/expression/tempo_change/music_quality
   - 3 级严重度：error / warning / info

5. **`addons/clef/templates/self_eval_checklist.json`** — 自评检查清单
   - 5 维度 25 项检查：旋律(0.25)、和声(0.25)、节奏(0.20)、表现力(0.15)、结构(0.15)
   - 显式评分公式 + 每维度修复策略
   - 加权总分 < 7.5 时迭代改进，最多 3 轮

### 知识库拆分重构（2026-03-26）

**原因：** Skill 文件原 610 行（接近 800 行限制），乐理知识占 200+ 行，不利于后续扩展。

**变更：**
- Skill 从 610 行缩减到 **348 行**（-43%），只保留工作流逻辑
- 乐理知识提取到 `addons/clef/knowledge/theory.md`（208 行）
- 用户扩展规范提取到 `addons/clef/knowledge/README.md`（58 行）
- Skill 通过 `## 必读文件` 段落声明依赖，执行时读取外部文件

**效果：**
- 知识库可独立维护和扩展，不影响 Skill 工作流
- 后续 Phase 2-4 添加新知识只需修改 theory.md 或添加新文件
- LOW 级别问题"Skill 文件接近 800 行限制"已解决

### 代码审查修复

审查发现 3 CRITICAL + 5 HIGH + 8 MEDIUM + 5 LOW 问题，已全部修复 CRITICAL 和 HIGH：

| 修复项 | 文件 | 内容 |
|--------|------|------|
| CRITICAL-1 | `llm_compose_guide.json` | 69=D4 → 69=A4（事实错误） |
| CRITICAL-2 | `llm_compose_guide.json` | velocity 范围 0-127 → 1-127 |
| CRITICAL-3 | `clef-compose.md` | 添加对 `llm_compose_guide.json` 的交叉引用 |
| HIGH-1 | `validation_rules.json` | format_version 验证从 error 降为 warning |
| HIGH-2 | 设计文档 | 评分标准从"各维度<7.5"改为"加权总分<7.5" |
| HIGH-3 | `validation_rules.json` | 新增 tempo_change_rules（3 条规则） |
| HIGH-4 | `self_eval_checklist.json` | 添加显式评分公式字段 |
| HIGH-5 | `clef-compose.md` | knowledge/ 目录不存在时跳过 |
| MEDIUM | `clef-compose.md` | Boss战 bVI → i-VII-VI-VII，史诗形式对齐，velocity 描述，-2半音弯音值，output/ 目录创建 |

### Skill 目录重组（2026-03-26）

**原因：** Skill 文件应遵循 Claude Code 目录式 Skill 规范，且模板文件应随 Skill 一起独立发布。

**变更：**
- Skill 文件从 `.claude/skills/clef-compose.md`（单文件）重组为 `.claude/skills/clef-compose/SKILL.md`（目录式）
- 乐理知识从 `addons/clef/knowledge/theory.md` 移至 `.claude/skills/clef-compose/theory.md`（Skill 自带核心知识）
- 三个模板文件复制到 `.claude/skills/clef-compose/templates/`：
  - `llm_compose_guide.json` — Clef JSON 格式规范
  - `validation_rules.json` — 技术验证规则
  - `self_eval_checklist.json` — 音乐质量自评清单
- `addons/clef/knowledge/README.md` 中的核心知识引用路径更新
- SKILL.md 中所有文件引用路径更新为 Skill 本地路径

**最终目录结构：**
```
.claude/skills/clef-compose/
├── SKILL.md                          # 主定义文件（350 行）
├── theory.md                         # 核心乐理知识（208 行）
└── templates/
    ├── llm_compose_guide.json        # Clef JSON 格式规范
    ├── validation_rules.json         # 技术验证规则
    └── self_eval_checklist.json      # 音乐质量自评清单
```

**效果：**
- Skill 完全自包含，可独立发布和分发
- 不再依赖 `addons/clef/templates/` 中的模板文件
- 原始模板文件保留在 `addons/clef/templates/` 供插件运行时使用
- 用户扩展知识仍通过 `addons/clef/knowledge/` 扫描加载

### 遗留 LOW 级别问题（不阻塞使用）

- 弯音评分对无弯音风格（如 chiptune、钢琴）不公平
- 验证规则为伪代码，LLM 解释执行（Phase 1 可接受）
- ~~Skill 文件约 610 行，接近 800 行限制~~ → 已通过知识库拆分解决（348 行）
- ~~模板文件引用 addons/ 路径~~ → 已通过目录重组解决（全部移入 Skill 目录）

### Phase 2 迭代 — 专家评审反馈修复（2026-03-26）

专家深度审视后发现 3 个架构级问题，全部修复完成：

1. **Clef JSON v2.0 — 时间单位从秒改为拍** — 解决 LLM 浮点运算导致的节拍漂移。更新了 spec、converter、SKILL.md、模板文件、示例文件（共 10 个文件）。
2. **Python 验证脚本** — 新建 `validate_clef.py`，替代 LLM 自我验证的幻觉问题。SKILL.md Step 7 集成代码验证步骤。
3. **Pitch Bend 值修正** — 从错误的 ±16 半音（512 单位/半音）修正为 GM 标准 ±2 半音（4096 单位/半音）。
4. **旋律"终端"问题修复** — 解决 LLM 在每个乐句结尾都使用终止式导致旋律碎片化的问题。更新 SKILL.md、theory.md、self_eval_checklist.json。
5. **v2.0 格式兼容** — 修复右键菜单不识别 v2.0 JSON 的问题。

**最终目录结构：**
```
.claude/skills/clef-compose/
├── SKILL.md                          # 主定义文件
├── theory.md                         # 核心乐理知识
├── scripts/
│   └── validate_clef.py              # Python 验证脚本（新增）
└── templates/
    ├── llm_compose_guide.json        # Clef JSON v2.0 格式规范
    ├── validation_rules.json         # 技术验证规则
    └── self_eval_checklist.json      # 音乐质量自评清单
```

## 后续阶段概要

### Phase 2: 样本分析与参考系统 ✅ 已完成
- ~~读取现有 `.mid`/`.json` 文件~~ → 通过 `--ref` 参数提供 Clef JSON 文件
- ~~提取风格特征（和弦进行、节奏型、配器方案、音域使用）~~ → Step R 自动分析，输出 style_profile.json
- ~~用户可以指定 "参考 BossBattle.mid 的风格"~~ → 支持单文件和多文件参考
- ~~自动匹配知识库中最接近的风格模板~~ → style_profile 作为约束注入 Step 1-6

**实现：** 仅修改 SKILL.md 一个文件（新增 Step R + Step 0/1-6 约束说明 + 反馈映射 2 条）。
**设计文档：** [2026-03-26-clef-style-reference-design.md](2026-03-26-clef-style-reference-design.md)

### 乐理知识库增强（2026-03-26）

基于用户反馈文档 `clef_feedback.md` 的评估，补充了 4 项内容到 theory.md：

1. **和弦外音** — 5 种类型（经过音、邻音、延留音、先现音、倚音）及使用原则
2. **低音线节奏模式** — 新增切分低音、琶音低音（原有 3 种扩充至 5 种）
3. **段落过渡技巧** — 5 种过渡方式（渐弱、填充、悬留、静默、交叉渐变）
4. **频率范围与复音限制** — 按频段的建议同时声部数

### 导出功能修复（2026-03-26）

- `midi_inspector_plugin.gd` tooltip 从 "v1.1" 更新为 "v2.0"

### Phase 3: 多 Agent 专业流水线
- 和声 Agent：专注和弦进行和声部配置
- 旋律 Agent：专注旋律线和动机发展
- 节奏 Agent：专注鼓组和节奏编排
- 编排 Agent：负责整体结构和配器平衡
- 验证 Agent：专注格式验证和质量评估
- 各 Agent 可并行生成，由主 Agent 协调

### Phase 4: 风格迁移与模板库
- 从用户提供的 MIDI 文件自动提取音乐模式
- 构建风格模板库（用户可贡献）
- 支持风格混合："80% 最终幻想 + 20% 塞尔达"
- 基于模板的快速生成（跳过规划步骤）
