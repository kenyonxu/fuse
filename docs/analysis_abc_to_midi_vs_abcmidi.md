# abc_to_midi.py vs abcmidi 功能对比分析

> 日期: 2026-03-29
> 目的: 评估自研 abc_to_midi.py 与 abcmidi 参考实现的差距，指导后续改进方向

## 1. 概述

| 维度 | abcmidi | abc_to_midi.py |
|------|---------|----------------|
| 版本 | abc2midi 3.88 (2015-02-08) | 持续迭代 |
| 语言 | C (~6000 行) | Python (~1210 行) |
| 作者 | James Allwright / Seymour Shlien | 项目自研 |
| 定位 | 通用 ABC→MIDI 转换器 | clef-compose 游戏音乐工具链 |
| 集成方式 | 需编译 C 可执行文件 | Python 直接调用，GDScript 友好 |
| ABC 标准覆盖 | ~95% | ~70% |
| 游戏音乐核心需求 | ✅ | ✅ |

---

## 2. 解析层对比

### 2.1 基础元素

| 功能 | abcmidi | abc_to_midi.py | 差距 |
|------|:-------:|:--------------:|:----:|
| Header 字段 (X,T,M,L,Q,K) | ✅ | ✅ | — |
| Voice 声部 V: (数字/字符串 ID) | ✅ | ✅ 数字 ID + name/clef | 🟡 |
| Note 音符 (a-g, A-G) | ✅ | ✅ | — |
| Octave 八度 (', ,,) | ✅ | ✅ 标准 + Unicode combining (U+0307/U+0323) | — |
| Accidental 升降号 (^, _, =, ^^, __) | ✅ 含 quartertone | ✅ 含 double sharp/flat | 🟡 |
| Duration 时值 (A2, A/2, A3/4) | ✅ | ✅ | — |
| Dotted 附点 (A., A..) | ✅ | ✅ | — |
| Rest 休止符 (z, x) | ✅ | ✅ | — |
| Multi-bar rest (Z2, Z4) | ✅ | ❌ | 🟡 |
| Chord 和弦 [CEG] + duration | ✅ | ✅ | — |

### 2.2 节奏与结构

| 功能 | abcmidi | abc_to_midi.py | 差距 |
|------|:-------:|:--------------:|:----:|
| Bar lines 小节线 (\|, \|\|, \|:, :\|, ::) | ✅ | ✅ | — |
| Volta ending (\|1, \|[1, [1, [2) | ✅ | ✅ | — |
| Repeat 反复 (嵌套) | ✅ | ✅ (最多 8 层安全限制) | — |
| Broken rhythm (<, >, <<, >>) | ✅ 可配 ratio (2:1/3:1) | ✅ 固定 3:1 ratio | 🟡 |
| Tie 延音线 (-) | ✅ 含跨小节/跨声部 | ✅ 含跨小节 | 🟡 |
| Tuplet 连音 ((3, (2, (n:q:r)) | ✅ 含 special tuple | ✅ (n:q:r) | 🟡 |
| Slur 连奏线 (, ) | ✅ 影响力度 + legato | ✅ 影响 note_off 时间 | 🟡 |

### 2.3 表现力

| 功能 | abcmidi | abc_to_midi.py | 差距 |
|------|:-------:|:--------------:|:----:|
| Grace notes 装饰音 ({}) | ✅ 两种模式, 可配偷取比例 | ✅ 固定 1/2 偷取 | 🟡 |
| Dynamics 力度 (!pp!-!ff!) | ✅ | ✅ | — |
| Crescendo/Decrescendo | ✅ 渐强 + 渐弱 | ✅ 仅渐强 | 🟡 |
| Slur 对力度的影响 | ✅ articulated_stress_factors 完整模型 | ⚠️ 仅 legato (note_off 时间) | 🟡 |
| Beat stress 拍位重音 | ✅ 可配 pattern 文件 | ✅ 简单首拍 +1.15 / 弱拍 +1.05 | 🟡 |

### 2.4 装饰符号

| 符号 | ABC 语法 | abcmidi | abc_to_midi.py |
|------|----------|:-------:|:--------------:|
| Staccato | `.` | ✅ | ✅ |
| Tenuto | `M` | ✅ | ✅ |
| Trill | `T` | ✅ | ✅ |
| Fermata | `H` | ✅ | ✅ |
| Loud/Accent | `!>!` | ✅ | ❌ |
| Roll | `!roll!` | ✅ | ❌ |
| Bow up | `!upbow!` | ✅ | ❌ |
| Bow down | `!downbow!` | ✅ | ❌ |
| Breath | `!breath!` | ✅ | ❌ |
| Ornament | `!ornament!` | ✅ | ❌ |
| Arpeggio | `!arpeggio!` | ✅ | ❌ |

### 2.5 调号与音高

| 功能 | abcmidi | abc_to_midi.py | 差距 |
|------|:-------:|:--------------:|:----:|
| Key signature 调号 | ✅ 15 调 + mode (mix/dor/phr/lyd) | ✅ 15 调 (major/minor) | 🟡 |
| Bar accidentals 小节升降号 | ✅ 含 cautionary accidental | ✅ 小节内持久 + 小节线重置 | 🟡 |
| Inline key change 行内调号变更 | ✅ | ✅ | — |
| Microtone/quarter tone | ✅ 半升降号, pitch bend | ❌ | 🔴 |

---

## 3. %%MIDI 指令对比

| 指令 | abcmidi | abc_to_midi.py | 游戏音乐需求 |
|------|:-------:|:--------------:|:-----------:|
| `%%MIDI channel N` | ✅ | ✅ | 高 |
| `%%MIDI program N` | ✅ | ✅ | 高 |
| `%%MIDI transpose N` | ✅ global + per voice | ✅ per voice | 高 |
| `%%MIDI tempo N` | ✅ | ✅ | 高 |
| `%%MIDI control N V` | ✅ | ✅ | 中 |
| `%%MIDI drummap` | ✅ 自定义鼓映射 | ❌ | 中 |
| `%%MIDI pitchbend` | ✅ | ❌ | 低 |
| `%%MIDI portamento` | ✅ | ❌ | 低 |
| `%%MIDI ratio` (broken rhythm) | ✅ | ❌ | 中 |
| `%%MIDI grace a/b` (偷取比例) | ✅ | ❌ | 低 |
| `%%MIDI chordprog` | ✅ 吉他和弦伴奏 | ❌ | 低 |
| `%%MIDI bassprog` | ✅ 低音伴奏 | ❌ | 低 |
| `%%MIDI gchord` | ✅ 吉他节奏型 | ❌ | 低 |
| `%%MIDI drum` | ✅ 鼓轨开关 | ❌ | 中 |
| `%%MIDI nocom` | ✅ 禁止注释 | ❌ | 低 |
| `%%MIDI beat` | ✅ 拍位力度配置 | ❌ | 低 |
| `%%MIDI stress` | ✅ 自定义 stress pattern | ❌ | 低 |

---

## 4. MIDI 生成层对比

| 功能 | abcmidi | abc_to_midi.py |
|------|:-------:|:--------------:|
| Ticks per beat | 可配 (默认 480) | 固定 480 |
| Key signature meta event | ✅ | ✅ |
| Time signature meta event | ✅ | ✅ |
| Set tempo meta event | ✅ | ✅ |
| Program change | ✅ per voice | ✅ per voice |
| Pitch bend | ✅ microtone 支持 | ❌ |
| Control change | ✅ | ✅ |
| Chord note ordering | ✅ 所有 note_on 先发 | ✅ 绝对时间排序保证 |
| Beat stress 拍位重音 | ✅ 可配 pattern 文件 | ✅ 简单首拍/弱拍加成 |
| Arpeggio 琶音 | ✅ !arpeggio! | ❌ |
| Lyrics 歌词 | ✅ W: 字段 → lyric meta event | ❌ |
| Multi-tune 多曲 | ✅ 单文件多曲 | ❌ 单曲 |
| SMF format | ✅ Format 0/1 可选 | ✅ Format 1 |

---

## 5. 我们独有功能

| 功能 | 说明 |
|------|------|
| Unicode combining octave marks | U+0307 (高八度) / U+0323 (低八度)，兼容简谱输入系统 |
| Embedded MIDI directives | `__MIDI_CTRL:n:v__` / `__MIDI_TEMPO:bpm__` 行内嵌入 MIDI 事件 |
| 绝对时间 + 排序架构 | 事件以绝对时间存储，最后排序转 delta time，避免累积误差 |
| 简洁的 Python 架构 | `_VoiceTrackBuilder` 类封装，1200 行完成核心功能 |

---

## 6. abcmidi 独有（我们完全缺失）

| 功能 | 说明 | 游戏音乐需求 |
|------|------|:-----------:|
| Microtone/quarter tone | 半升降号, pitch bend 实现 | 🟡 低 |
| Voice overlay (`</`) | overlay 声部覆盖 | 🟡 低 |
| Voice split/merge | 声部拆分与合并 | 🟡 低 |
| Part marking (P:A, P:B) | 段落标记与反复 | 🟡 低 |
| Tempo name (Allegro, etc.) | 文字速度名映射 | 🟡 低 |
| Clef change 行内谱号变更 | 中段换谱号 | 🟡 低 |
| Stress pattern 文件 | 自定义力度模式 (reel/hornpipe/jig 等) | 🟡 低 |
| Guitar chord auto-accompaniment | %%MIDI chordprog/bassprog/gchord 自动伴奏 | 🟠 中 |
| Drum track 自动生成 | %%MIDI drum + %%MIDI drummap | 🟠 中 |
| Retuning / custom temperament | 非 12-TET 音律支持 | 🟡 低 |

---

## 7. 差距优先级评估

### P0 — 不影响游戏音乐（无需补齐）

| 功能 | 原因 |
|------|------|
| Multi-bar rest (Z) | 游戏音乐用 z 足够 |
| Microtone | 西方调式游戏音乐不需要 |
| Lyrics | 游戏音乐无歌词需求 |
| Voice overlay/split/merge | 单声部旋律场景不需要 |
| Custom temperament | 12-TET 够用 |
| Stress pattern 文件 | 简单 beat stress 已满足 |

### P1 — 可选增强（视场景需要）

| 功能 | 价值 | 工作量 |
|------|------|--------|
| `%%MIDI drummap` 自定义鼓映射 | 扩展打击乐支持 | LOW |
| `%%MIDI ratio` broken rhythm 比例配置 | 支持 Celtic 2:1 风格 | LOW |
| `%%MIDI grace a/b` 装饰音偷取比例配置 | 更精细的装饰音控制 | LOW |
| Decrescendo 渐弱 | 完善力度表现 | MEDIUM |
| Remaining decorations (!>, !roll!, !breath! 等) | 更丰富的表情符号 | LOW |
| Part marking (P:A/B) | 段落结构支持 | LOW |

### P2 — 较高价值但工作量大

| 功能 | 价值 | 工作量 |
|------|------|--------|
| Key mode (mixolydian, dorian 等) | 民族音乐支持 | MEDIUM |
| Guitar chord auto-accompaniment | 自动伴奏生成 | HIGH |
| Drum track auto-generation | 自动鼓轨 | MEDIUM |
| Cross-voice tie | 多声部延音 | MEDIUM |

---

## 8. 总结

abc_to_midi.py 在 **~1210 行 Python 代码**中实现了 abcmidi **~6000 行 C 代码**约 **70%** 的核心功能，覆盖了游戏音乐场景的所有关键需求（音符/时值/和弦/反复/连音/调号/力度/装饰音/装饰符号/行内字段/声部分离）。

主要差距集中在：
1. **%%MIDI 指令丰富度**（缺 drummap/ratio/grace 配置等 ~10 种指令）
2. **装饰符号种类**（缺 LOUD/ROLL/BOWUP/BOWDOWN/BREATH 5 种）
3. **高阶音乐表现**（缺渐弱、microtone、stress pattern 文件等）

这些差距对游戏音乐影响较小，优先级均为 P1-P2。如需补齐，建议从 `%%MIDI drummap` 和 `Decrescendo` 开始。

---

*文档生成日期: 2026-03-29*
