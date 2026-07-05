# abc_to_midi.py 修复实施计划

> 基于 `docs/analysis_abc_to_midi_gaps.md` 分析报告
> 日期: 2026-03-28

## 修复范围

针对 24 个已识别问题，分 6 个阶段渐进修复。每阶段完成后脚本保持可用，所有现有测试持续通过。

---

## Phase 1: 基础修复（快速见效）

**目标**: 修复低工作量但高影响的 bug，为后续阶段打好基础

### 1.1 修复分数时值解析（#8）— `LOW`

**文件**: `abc_to_midi.py` → `_parse_duration()`

**当前问题**: 只支持纯数字后缀 `A2`，不支持 `A/2` `A3/4`

**修复方案**: 重写 `_parse_duration()` 返回 (numerator, denominator) 分数对
```
A     → (1, 1)     # 1 倍 unit_length
A2    → (2, 1)     # 2 倍
A/2   → (1, 2)     # 半个 unit_length
A3/4  → (3, 4)     # 3/4 个 unit_length
A     → (1, 1)     # 默认
```

**同步修改**: `_build_voice_track()` 中所有 `unit_ticks * dur_mult` 改为 `unit_ticks * num / denom`

**测试**: 添加 `test_fractional_duration`

### 1.2 修复附点音符（#6）— `LOW`

**文件**: `abc_to_midi.py` → `_parse_duration()` + `_tokenize_music_line()`

**修复方案**: 在 token 收集阶段识别 `.` 后缀，`_parse_duration()` 返回附加 dot_count

```
A.    → dur=1, dots=1 → 时值 × 1.5
A2.   → dur=2, dots=1 → 时值 × 3
A..   → dur=1, dots=2 → 时值 × 1.75
```

**计算公式**: `duration × (2 - 1/2^dots)` 或等价的 `duration × (2^(dots+1) - 1) / 2^dots`

**测试**: 添加 `test_dotted_notes`

### 1.3 修复和弦 note_on/note_off 顺序（#11）— `LOW`

**文件**: `abc_to_midi.py` → `_build_voice_track()` 和弦处理块

**当前问题**: 逐个发出 on/off 对，导致音符不同时结束
```python
# WRONG
for pitch in note_pitches:
    track.append(note_on(time=0))
    track.append(note_off(time=duration))
```

**修复方案**: 先发所有 note_on，再发所有 note_off
```python
# CORRECT
for pitch in note_pitches:
    track.append(note_on(time=0, ...))
for i, pitch in enumerate(note_pitches):
    delta = duration if i == 0 else 0
    track.append(note_off(time=delta, ...))
```

**测试**: 添加 `test_chord_note_ordering`

### 1.4 修复 `_fix_delta_times()` 无效代码（#21）— `LOW`

**文件**: `abc_to_midi.py` → `_fix_delta_times()`

**当前问题**: 函数什么也没做（`msg.time = msg.time`）

**修复方案**: 在 chord 正确排序后，实际上不再需要这个函数。删除或改为正确的 delta time 重算（按绝对时间排序后重算 delta）。

**决策**: 修复 #11 后评估是否还需要此函数，如果不需要则删除。

### 1.5 支持 `x` 休止符（#23）— `LOW`

**文件**: `abc_to_midi.py` → `_build_voice_track()`

**修复**: `if token.startswith('z')` 改为 `if token[0] in ('z', 'x')`

**测试**: 添加 `test_invisible_rest`

### 1.6 修复 `:` 的小节线检测（#22）— `LOW`

**文件**: `abc_to_midi.py` → `_tokenize_music_line()`

**当前问题**: `:|` 通过 `line[i-1]` 回看检测，不可靠

**修复方案**: 改为前瞻式扫描 — 遇到 `:` 时先看后面是否跟 `|`，或者重新设计小节线解析逻辑为统一的 pattern match

---

## Phase 2: 核心节奏特性

**目标**: 实现 broken rhythm、tuplet、tie — 最常用的三个 ABC 节奏特性

**依赖**: Phase 1 完成（需要分数时值系统）

### 2.1 实现 Broken Rhythm（#1）— `MEDIUM`

**文件**: `abc_to_midi.py` → `_tokenize_music_line()` + 新增 `_apply_broken_rhythm()`

**实现策略**:

1. `_tokenize_music_line()` 中识别 `<` `>` `<<` `>>` `<<<` `>>>`，输出为 token（如 `BROKEN_GT_1`、`BROKEN_LT_2`）
2. `_build_voice_track()` 维护 `pending_note` 状态 — 遇到 broken token 时不立即发出前一个音符的 MIDI 事件，而是暂存
3. `_apply_broken_rhythm(prev_note, broken_type, mult, next_note)` 调整时值：
   - `>` (mult=1): prev × 3/2, next × 1/2 (总计不变)
   - `>>` (mult=2): prev × 7/4, next × 1/4
   - `>>>` (mult=3): prev × 15/8, next × 1/8
   - `<`: 交换 prev/next 的乘数

**参考**: store.c `brokenadjust()` — ratio_a=3, ratio_b=1, denom12=(a+b)/2

**测试**: 添加 `test_broken_rhythm_gt`, `test_broken_rhythm_lt`, `test_broken_rhythm_multiple`

### 2.2 实现 Tie（#3）— `MEDIUM`

**文件**: `abc_to_midi.py` → `_tokenize_music_line()` + `_build_voice_track()`

**实现策略**:

1. `_tokenize_music_line()` 中将 `-` 识别为 `TIE` token
2. `_build_voice_track()` 维护 `last_note_info`（pitch, start_tick, duration）
3. 遇到 `TIE` token 且下一个音符 pitch 相同时：将 next_note 的 duration 累加到 last_note，不发出第二个 note_on/note_off
4. 跨小节 tie：tie 不受小节线阻断

**参考**: store.c `dotie()` — `addfract()` 累加 num/denom，被 tie 音符变为 REST

**测试**: 添加 `test_tie_basic`, `test_tie_cross_bar`, `test_tie_chord`

### 2.3 实现 Tuplet/Triplet（#2）— `MEDIUM`

**文件**: `abc_to_midi.py` → `_tokenize_music_line()` + 新增 `_apply_tuplet()`

**实现策略**:

1. `_tokenize_music_line()` 中识别 `(3` `(2` `(n` `(n:q` `(n:q:r`，输出为 `TUPLET_START(n, q, r)` token
2. 跟踪 tuplet 内的音符数量，到达 n 个后结束 tuplet
3. 时值计算：
   - 简单形式 `(3` : 3 个音符占 2 个音符的时间 → 每个 × 2/3
   - `(n:q` : n 个音符占 q 个音符的时间 → 每个 × q/n
   - `(n:q:r` : n 个音符在 r 个 … 时间内（r 通常等于 q）

**参考**: parseabc.c `event_tuple(n, q, r)` + store.c 中 `lenmul` 应用

**测试**: 添加 `test_triplet`, `test_duplet`, `test_tuplet_with_duration`

---

## Phase 3: 调号与音高系统

**目标**: 正确处理调号对音符的影响，修复八度标记问题

**依赖**: 无（可与 Phase 2 并行）

### 3.1 实现 Key Signature 对音符的影响（#7）— `HIGH`

**文件**: `abc_to_midi.py` → 新增 `_parse_key_signature()` + 修改 `_parse_note_pitch()`

**实现策略**:

1. 新增 `_parse_key_signature(key_str)` 解析 K: 字段，返回需要升降的音符集合
   ```
   K:C   → {} (无升降)
   K:D   → {F#: 1, C#: 1}  (2个升号)
   K:G   → {F#: 1}         (1个升号)
   K:F   → {Bb: -1}        (1个降号)
   K:Bb  → {Bb: -1, Eb: -1} (2个降号)
   K:Am  → {} (关系小调，同C)
   ```

2. 使用五度圈映射：
   ```
   SHARPS_ORDER = ['F', 'C', 'G', 'D', 'A', 'E', 'B']
   FLATS_ORDER  = ['B', 'E', 'A', 'D', 'G', 'C', 'F']
   ```

3. 解析 K: 字段的模式识别：
   - 基础调名 + `#`/`b` 后缀（如 `K:F#`）
   - 模式后缀（如 `K:Dm`, `K:C major`）
   - `exp` (显式) 模式 — 不自动应用升降号

4. `_parse_note_pitch()` 中加入 `key_accidentals` 参数：
   - 先查 key_accidentals 获取默认升降号
   - 如果音符有显式 `^` `_` `=` 前缀，覆盖调号（`=` 显式还原）
   - 维护小节内的临时升降号状态（bar line 后重置）

**参考**: parseabc.c `parsekey()` → `setmap[]` — 用五度圈偏移计算各调号的升降音集合

**测试**: 添加 `test_key_c_major`, `test_key_g_major`, `test_key_f_major`, `test_key_d_minor`, `test_accidental_override`, `test_barline_resets_accidentals`

### 3.2 修复八度标记解析不一致（#9）— `LOW`

**文件**: `abc_to_midi.py` → `_parse_note_pitch()` + `_count_octave_marks()`

**问题**: Unicode combining marks (U+0307/U+0323) 和标准 `,` `'` 两套系统重复计算

**修复方案**:
1. 统一为一套八度偏移计算：先收集所有 octaves_up 和 octaves_down（无论来源），然后只算一次
2. 删除 `_count_octave_marks()` 的重复调用
3. 在 `_parse_note_pitch()` 中一次性完成所有八度计算

### 3.3 支持双升降号（#10）— `LOW`

**文件**: `abc_to_midi.py` → `_parse_note_pitch()`

**修复**: 扩展 accidental 解析
```python
if base.startswith('^^'):
    accidental = 2
    base = base[2:]
elif base.startswith('__'):
    accidental = -2
    base = base[2:]
elif base.startswith('^'):
    accidental = 1
    base = base[1:]
elif base.startswith('_'):
    accidental = -1
    base = base[1:]
```

### 3.4 添加 key_signature Meta Event（#14）— `LOW`

**文件**: `abc_to_midi.py` → `abc_to_midi()`

**修复**: 在 tempo track 中添加 key signature meta event
```python
from _parse_key_signature 得到 sharps_count, minor_flag
tempo_track.append(mido.MetaMessage(
    'key_signature', key='...' , time=0
))
```

---

## Phase 4: 反复与连奏

**目标**: 实现反复播放、volta ending 和 slur

**依赖**: Phase 1（小节线解析修复）

### 4.1 实现反复/Repeat（#4）— `HIGH`

**文件**: `abc_to_midi.py` → 重新设计 `_tokenize_music_line()` + 新增 repeat 状态机

**实现策略**:

**方案**: 将 token 流转为可回溯的结构

1. **两遍处理架构**:
   - 第一遍：将所有 voice 的 music_lines tokenize 为 token 列表
   - 第二遍：通过 repeat 状态机遍历 token 列表生成 MIDI 事件

2. **Repeat 状态机**:
   ```
   states: NORMAL, IN_REPEAT, IN_ENDING
   |:  → save_position(), pass=1, maxpass=2
   :|  → if pass < maxpass: restore_position(), pass+=1
         else: continue
   |1  或 |[1  → if pass != 1: skip_to_next_ending_or_barline
   |2  或 |[2  → if pass != 2: skip_to_next_ending_or_barline
   ::  → 等价于 |: :| (反复一次)
   ```

3. **Volta brackets**: 识别 `|1` `|2` `[1` `[2` 格式，按 pass 选择播放

4. **小节线解析重写**: 统一处理所有小节线变体
   ```
   |       → BAR_LINE
   ||      → DOUBLE_BAR
   |]      → FINAL_BAR
   |:      → BAR_REP_START
   :|      → BAR_REP_END
   ::      → DOUBLE_REP
   |1 |[1  → BAR + VOLTA(1)
   |2 |[2  → BAR + VOLTA(2)
   ```

**参考**: genmidi.c `save_state()`/`restore_state()` + `PLAY_ON_REP` + `inlist()`

**测试**: `test_repeat_simple`, `test_repeat_with_1st_2nd_ending`, `test_double_repeat`, `test_repeat_nested`

### 4.2 实现 Slur/Legato（#5）— `MEDIUM`

**文件**: `abc_to_midi.py` → `_tokenize_music_line()` + `_build_voice_track()`

**实现策略**:

1. tokenize 阶段：`(` → `SLUR_ON`, `)` → `SLUR_OFF`

2. MIDI 生成：
   - slur 状态下，note_off 的 time 延迟到下一个 note_on 之前（即缩短 gap）
   - 简化实现：slur 内的音符 note_off time = 0（或极小值如 1 tick），下一个 note_on time 包含完整时值
   - 力度方面：slur 内的音符 velocity 适当降低（可选）

**参考**: genmidi.c `SLUR_ON`/`SLUR_OFF` — 主要影响 `articulated_stress_factors()` 力度计算

**测试**: `test_slur_basic`, `test_slur_with_tie`

---

## Phase 5: 高级特性

**目标**: 支持 inline field、grace notes、力度增强

**依赖**: Phase 2+3 完成

### 5.1 行内字段 Inline Field（#15）— `MEDIUM`

**文件**: `abc_to_midi.py` → `_tokenize_music_line()`

**修复**: 在遇到 `[` 时，检查是否匹配 `[X:...]` 格式（字母+冒号），若是则解析为行内字段而非和弦

```
[CEG]    → 和弦
[K:G]    → 行内调号变更
[M:3/4]  → 行内拍号变更
```

### 5.2 Grace Notes（#16）— `MEDIUM`

**文件**: `abc_to_midi.py` → `_tokenize_music_line()` + `_build_voice_track()`

**实现**:
1. tokenize 阶段：`{...}` 内容解析为 grace note 列表
2. MIDI 生成：从主音符"偷取"时间分配给 grace notes
3. 默认偷取比例 1/2（可通过 `%%MIDI grace a/b` 配置）

**参考**: store.c `applygrace_orig()` — `gfact_num/gfact_denom` 控制比例

### 5.3 力度增强（#12）— `MEDIUM`

**文件**: `abc_to_midi.py` → `_build_voice_track()`

**增强**:
1. 拍位重音：小节首音 louder，弱拍 softer
2. 渐强/渐弱：`!crescendo(!` `!crescendo)!` 或 `!<(!` `!<)!` — 在范围内逐步调整 velocity
3. Stress 映射：简单的 beat position → velocity 乘数表

---

## Phase 6: 扩展与完善

**目标**: 补齐剩余小问题和扩展 MIDI 指令支持

### 6.1 扩展 %%MIDI 指令（#24）— `LOW`

新增支持：
- `%%MIDI tempo N` — 临时速度变更
- `%%MIDI control N V` — CC 事件
- `%%MIDI transpose N` — 移调
- `%%MIDI drummap` — 自定义鼓映射

### 6.2 装饰符号（#20）— `LOW`

基础支持：
- `.` staccato — 缩短 note_off 时间
- `M` tenuto — 延长 note_off 时间
- `T` trill — 展开为交替音符序列（简单实现）
- `H` fermata — 延长时值

### 6.3 U: 宏（#17）和 P: 段落（#18）— `LOW`

按需实现，游戏音乐场景中使用频率低。

---

## 风险评估

| 风险 | 等级 | 缓解措施 |
|------|------|---------|
| Phase 2 broken rhythm 状态机复杂度 | MEDIUM | 参考 store.c 成熟算法，添加详尽测试 |
| Phase 3 key signature 五度圈计算 | MEDIUM | 使用查表法而非算法计算，覆盖 15 个常用调 |
| Phase 4 repeat 状态机 | HIGH | 两遍处理架构降低复杂度，限制嵌套反复层数 |
| 重构可能破坏现有功能 | MEDIUM | 每阶段先跑现有 17 个测试确保不回归 |
| 分数时值系统重构影响面广 | LOW | Phase 1 先改接口，后续阶段渐进适配 |

## 测试策略

每个 Phase 完成后：
1. 运行现有 17 个测试确保无回归
2. 运行新增测试覆盖新功能
3. 手动用 abc 文件生成 MIDI 并用 MIDI 播放器验证听觉效果
4. 对比 abcmidi 工具生成的参考 MIDI 文件

## 实施顺序建议

```
Phase 1 (1-2小时) → Phase 2 (2-3小时) → Phase 3 (2-3小时)
                                              ↕ 可并行
                                         Phase 4 (3-4小时)
                                         Phase 5 (2-3小时)
                                         Phase 6 (按需)
```

**总计 P0+P1 修复预计**: 8-12 小时
**全部修复预计**: 15-20 小时
