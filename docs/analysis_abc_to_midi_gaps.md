# abc_to_midi.py 与 abcmidi 参考实现对比分析

> 对比基准：`third_party_resources/abcmidi/` (genmidi.c 3460行 + parseabc.c 57KB + store.c 163KB)
> 我们的脚本：`.claude/skills/clef-compose/scripts/abc_to_midi.py` (520行)

---

## 一、缺失的核心功能（HIGH）

### 1. Broken Rhythm（`<` `>` 符号）— 完全缺失

**参考实现**：store.c 中 `brokenadjust()` 实现了完整的时值调整：
- `>` — 前音符 ×3/2，后音符 ×1/2（3:1 比例）
- `<` — 前音符 ×1/2，后音符 ×3/2
- `>>` — 7:1 比例，`>>>` — 15:1 比例
- Celtic 模式下可切换为 2:1 比例

**我们的脚本**：`_tokenize_music_line()` 将 `<` 和 `>` 作为普通字符处理，不识别为 broken rhythm 标记，会被忽略或误解析。

**影响**：所有使用 broken rhythm 的 ABC 谱（非常常见的节奏标记）都会产生错误的时值。

### 2. Tuplet/Triplet（连音）— 完全缺失

**参考实现**：`(3` 三连音、`(2` 二连音、`(n:q:r` 完整形式全部支持，时值按比例分配。

**我们的脚本**：`(` 字符被忽略，三连音等连音标记完全不解析。

**影响**：三连音是音乐中最常见的节奏型之一，缺失意味着大量谱子无法正确转换。

### 3. Tie（延音线 `-`）— 完全缺失

**参考实现**：store.c `dotie()` 将两个同音高音符合并为一个长音符，时值累加，支持跨小节 tie。

**我们的脚本**：`-` 字符被忽略，tie 前后的音符被当作独立的两个音符处理。

**影响**：延音线是最基础的乐谱元素，缺失会导致音高重复、时值错误。

### 4. 重复/反复（`|:` `:|` Volta）— 逻辑错误

**参考实现**：完整的状态机 — `save_state()`/`restore_state()` 保存/恢复位置，支持多次反复、volta brackets（`|1` `|2` 1st/2nd ending）。

**我们的脚本**：
- `|:` 和 `:|` 被当作普通小节线处理（只推进到下一个小节边界）
- **没有实际的反复逻辑** — 不回溯播放
- 不支持 volta brackets
- `:|` 的检测逻辑有 bug：通过检查前一个字符 `line[i-1]` 是否为 `:` 来判断，但如果 `:` 前有空格或其他字符则会漏检

**影响**：所有包含反复段落的音乐只播放一遍，且 volta ending 完全不工作。

### 5. Slur/Legato（连奏线 `()`）— 完全缺失

**参考实现**：`SLUR_ON`/`SLUR_OFF` 影响力度模型和 note_off 时间，实现真正的 legato 效果。

**我们的脚本**：`(` 和 `)` 被忽略（`(` 被 tokenize 作为 note 的一部分误解析）。

**影响**：无法表达连奏效果，音乐听起来会很生硬。

---

## 二、解析器缺陷（HIGH）

### 6. 附点音符 — 未处理

**参考实现**：音符后的 `.` 将时值 ×1.5。

**我们的脚本**：`_parse_duration()` 只读取数字后缀，不识别 `.` 附点。例如 `A2.` 应为 3/4 音符，但我们只会解析为 `A` + `2`。

### 7. Key Signature 对音符的实际影响 — 未实现

**参考实现**：K: 字段决定了调号（如 K:D 意味着所有 F# 自动升高），解析器会根据调号为没有临时升降号的音符自动应用升降。

**我们的脚本**：`parse_header()` 读取 K: 但仅存储字符串，`_parse_note_pitch()` 不做任何调号处理。音符的升降号只通过显式的 `^` `_` 前缀处理。

**影响**：除非每个音符都显式标注升降号，否则调号内的音符音高都是错的。

### 8. 音符时值解析不完整 — 缺少分数时值

**参考实现**：支持 `A/2`、`A/4`、`A3/4` 等分数时值写法。

**我们的脚本**：`_parse_duration()` 只读取纯数字后缀（如 `2`、`4`），不支持 `/2`、`/4` 分数形式。

**影响**：使用分数时值写法的音符时值计算错误。

### 9. 八度标记解析不一致

**参考实现**：
- 小写 `a-g` → octave=1（基础八度），`'` 每个+1，`,` 报错但仍-1
- 大写 `A-G` → octave=0（低八度），`,` 每个-1，`'` 报错但仍+1

**我们的脚本**：
- `NOTE_PITCH` 硬编码了大小写的绝对音高
- 同时支持 Unicode combining marks 和标准 `,` `'`
- 但 `_parse_note_pitch()` 先处理了标准 `,` `'`，再又用 `_count_octave_marks()` 处理 Unicode marks — **两套系统重复计算**
- 对大写字母使用 `'` 和小写字母使用 `,` 的情况没有报错处理

### 10. 双升降号（`^^` `__`）— 不支持

**参考实现**：`^^` 双升、`__` 双降，支持微音程。

**我们的脚本**：`_parse_note_pitch()` 只处理单个 `^` 或 `_`。

---

## 三、MIDI 生成缺陷（MEDIUM）

### 11. 和弦音 note_on/note_off 顺序错误

**参考实现**：和弦内所有 note_on 先发出（delta=0），然后所有 note_off 在和弦时长后一起发出。

**我们的脚本**：
```python
for pitch in note_pitches:
    track.append(note_on(time=0))
    track.append(note_off(time=duration))  # ← 每个音符的 note_off 紧跟 note_on
```
这会导致第一个音符先结束，而不是所有音符同时结束。正确做法是先发所有 note_on，再发所有 note_off。

### 12. 力度模型过于简单

**参考实现**：三级力度模型（拍位重音 + 动态标记 + stress 曲线），支持渐强/渐弱。

**我们的脚本**：只有 6 级固定动态标记（pp 到 ff），没有拍位重音、没有渐变。

### 13. 缺少 MIDI 控制事件

**参考实现**：支持 `%%MIDI control` 指令写入 CC 事件，支持 pitch bend、sustain pedal 等。

**我们的脚本**：只有 program_change，没有 CC 事件。

### 14. Tempo Track 缺失 key_signature Meta Event

**参考实现**：写入 key signature meta event。

**我们的脚本**：tempo track 只有 set_tempo 和 time_signature，缺少 key_signature。

---

## 四、ABC 标准支持缺失（MEDIUM）

### 15. 行内字段（Inline Field）— 不支持

**参考实现**：`[K:G]`、`[M:3/4]` 可在音乐行内嵌入，动态改变调号或拍号。

**我们的脚本**：`[` 被统一当作和弦开始处理。

### 16. 装饰音（Grace Notes `{}`）— 不支持

**参考实现**：`{GA}` 花括号内的音符作为装饰音，从主音符"偷取"时间，支持配置偷取比例。

**我们的脚本**：`{` 和 `}` 未在 `_tokenize_music_line()` 中处理。

### 17. 用户宏（U: 字段）— 不支持

**参考实现**：`U: T = !trill!` 定义宏，后续在谱中使用 `T` 展开为 trill。

**我们的脚本**：不解析 U: 字段。

### 18. 段落标记（P: 字段）— 不支持

**参考实现**：P: 字段标记段落，支持按段落选择性播放。

**我们的脚本**：不解析 P: 字段。

### 19. 歌词（w: / W: 字段）— 不支持

**参考实现**：支持歌词同步到音符。

**我们的脚本**：不支持（对我们的 MIDI 转换场景影响较小）。

### 20. 装饰音标记（Ornaments）— 不支持

**参考实现**：`.M L R H ~ T u v` 等装饰符号（staccato、tenuto、fermata、trill、roll 等）。

**我们的脚本**：不处理任何装饰符号。

---

## 五、小问题 / 边界情况（LOW）

### 21. `_fix_delta_times()` 实际无效

```python
def _fix_delta_times(track):
    abs_time = 0
    prev_abs_time = 0
    for msg in track:
        abs_time += msg.time
        msg.time = abs_time - prev_abs_time  # = msg.time，什么也没改
        prev_abs_time = abs_time
```
这个函数的注释说"将 delta times 转为绝对再转回"，但代码实际上什么都没做（`msg.time = msg.time`）。如果意图是处理乱序事件（如和弦的 note_on/note_off 交叉），需要先排序再重算 delta。

### 22. `:` 的处理不完整

`_tokenize_music_line()` 中 `:` 作为 repeat marker 的 `:|` 检测逻辑依赖 `line[i-1]`，如果 `:` 出现在其他上下文中可能被误处理。

### 23. 休止符只有 `z`，缺少 `x`

**参考实现**：`z` = 可见休止符，`x` = 不可见休止符（用于对齐），两者在 MIDI 层效果相同。

**我们的脚本**：只处理 `z` 开头的休止符。

### 24. `%%MIDI` 指令种类不足

**参考实现**：支持 `%%MIDI channel/program/control/tempo/grace/bassprog/bassvol/drum/chordattack/noteon/noteoff` 等大量指令。

**我们的脚本**：只支持 `channel` 和 `program`。

---

## 优先级建议

| 优先级 | 问题 | 工作量估计 |
|--------|------|-----------|
| **P0** | #1 Broken rhythm | 中 |
| **P0** | #2 Tuplet/triplet | 中 |
| **P0** | #3 Tie | 中 |
| **P0** | #7 Key signature 影响 | 高 |
| **P0** | #8 分数时值 | 低 |
| **P1** | #4 反复/volta | 高 |
| **P1** | #5 Slur/legato | 中 |
| **P1** | #6 附点音符 | 低 |
| **P1** | #11 和弦 note 顺序 | 低 |
| **P1** | #15 行内字段 | 中 |
| **P2** | #9 八度重复计算 | 低 |
| **P2** | #16 Grace notes | 中 |
| **P2** | #21 fix_delta_times bug | 低 |
| **P2** | #10 双升降号 | 低 |
| **P3** | #12-14, #17-20, #22-24 | 分散 |
