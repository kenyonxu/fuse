# abc_to_midi.py 代码审查报告 (Phase 2)

> 对照 `plans/fix_abc_to_midi.md` 6 阶段计划
> 日期: 2026-03-28
> 67/67 测试通过

## 计划完成度

| Phase | 计划内容 | 状态 | 备注 |
|-------|---------|------|------|
| 1.1 | 分数时值 (#8) | ✅ 完成 | `_parse_dur_str` 支持 `/2`, `3/4` |
| 1.2 | 附点音符 (#6) | ✅ 完成 | `_calc_ticks` 支持 dots |
| 1.3 | 和弦 note 顺序 (#11) | ✅ 完成 | abs_time + sort 方案更优 |
| 1.4 | `_fix_delta_times` 删除 (#21) | ✅ 完成 | 已被 abs_time 排序替代 |
| 1.5 | `x` 休止符 (#23) | ✅ 完成 | L941 处理 `z`/`x` |
| 1.6 | `:` 小节线 (#22) | ✅ 完成 | 前瞻式解析 |
| 2.1 | Broken Rhythm (#1) | ✅ 完成 | tokenize + _handle_broken_rhythm |
| 2.2 | Tie (#3) | ✅ 完成 | pending note + duration 累加 |
| 2.3 | Tuplet (#2) | ✅ 完成 | TUPLET_n_q_r token |
| 3.1 | Key Signature (#7) | ✅ 完成 | 五度圈查表 + bar accidentals |
| 3.2 | 八度标记 (#9) | ⚠️ 部分 | 见 BUG-1 |
| 3.3 | 双升降号 (#10) | ✅ 完成 | `^^`/`__` 支持 |
| 3.4 | Key Meta Event (#14) | ✅ 完成 | tempo track 中已添加 |
| 4.1 | 反复/Volta (#4) | ⚠️ 部分 | 见 BUG-3, BUG-4 |
| 4.2 | Slur (#5) | ✅ 完成 | SLUR_ON/OFF + legato |
| 5.1 | Inline Field (#15) | ✅ 完成 | `[K:G]`, `[M:3/4]` |
| 5.2 | Grace Notes (#16) | ✅ 完成 | 时间偷取 1/2 |
| 5.3 | 力度增强 (#12) | ✅ 完成 | crescendo + beat stress |
| 6.1 | %%MIDI 扩展 (#24) | ✅ 完成 | tempo/control/transpose |
| 6.2 | 装饰符号 (#20) | ⚠️ 部分 | STACCATO/FERMATA/TRILL ok, TENUTO 缺失实现 |
| 6.3 | U:/P: 宏 (#17/#18) | ❌ 未实现 | 游戏音乐场景低频 |

---

## BUG 清单

### BUG-1: `'`（八度升标记）未在 tokenizer 中收集 — HIGH

**位置**: `_tokenize_music_line()` L467-491

**问题**: tokenizer 收集 combining marks (U+0307) 和 `,`（八度降），但**不收集 `'`（标准 ABC 八度升标记）**。标准 ABC 记谱法中 `c'` 表示高八度 C，但当前 tokenizer 会将 `c'` 拆为 `c` 和 `'` 两个 token，后者无法识别。

**影响**: 使用标准 ABC `'` 标记的乐谱八度完全错误。clef-compose 内部使用 Unicode combining marks 因此不受影响，但与外部 ABC 文件的兼容性被破坏。

**修复**: 在 L476（收集 commas 的循环）之后，添加收集 `'` 的循环：
```python
# Collect primes (octave up)
while i < length and line[i] == "'":
    token += line[i]
    i += 1
```

**同步**: `_parse_note_pitch` L243-245 已正确计数 primes，无需额外修改。

---

### BUG-2: `_handle_barline` 小节溢出时间丢失 — MEDIUM

**位置**: `_VoiceTrackBuilder._handle_barline()` L918-919

**问题**: 当音符时值溢出一个小节时（如 4/4 拍但写了 5 拍的音符），`_close_pending()` 将 `abs_time` 推进到溢出位置，但随后 L919 直接赋值 `self.abs_time = self.bar_start_tick + self.bar_ticks`，**回退到小节边界**，导致溢出部分的 note_off 与下小节音符重叠。

```python
# 当前代码 (L918-919)
if not self.tie_active:
    self._close_pending()  # 可能将 abs_time 推到 bar 边界之后
self.abs_time = self.bar_start_tick + self.bar_ticks  # 强制回退!
```

**修复**:
```python
self.abs_time = max(self.abs_time, self.bar_start_tick + self.bar_ticks)
```

---

### BUG-3: `_expand_one_repeat` depth 变量遮蔽参数 — MEDIUM

**位置**: `_expand_one_repeat()` L531 vs L539

**问题**: L531 声明参数 `depth: int = 0`，L539 用同名局部变量 `depth = 0` 覆盖。局部变量用于跟踪 `|:/:|` 配对计数（循环后归零），然后 L586 传递 `depth + 1` 给 `_expand_repeats` — 但此时 `depth` 永远是 0。

**影响**: 嵌套反复的深度安全检查 (`_depth >= 8`) 失效，深层嵌套可能导致无限递归。

**修复**: 重命名局部变量为 `nest_level`，在递归调用中使用原始 `depth` 参数：
```python
def _expand_one_repeat(tokens, start, result, depth=0):
    i = start + 1
    n = len(tokens)
    nest_level = 0  # 改名

    for j in range(i, n):
        if tokens[j] == '|:':
            nest_level += 1
        elif tokens[j] == ':|':
            if nest_level == 0:
                end = j
                break
            nest_level -= 1

    # 递归时正确传递深度
    body = _expand_repeats(body, _depth=depth + 1)
```

---

### BUG-4: `::` 双反复标记当作普通小节线处理 — LOW

**位置**: `_expand_repeats()` L517-519

**问题**: `::` 在 ABC 标准中等价于 `|: :|`（反复一次），但当前代码只输出 `|`（普通小节线），完全忽略反复。

```python
elif t == '::':
    result.append('|')  # 应该展开为反复
    i += 1
```

**影响**: 使用 `::` 的乐谱不会反复播放。

---

### BUG-5: `_handle_chord` 不消费 decoration — LOW

**位置**: `_VoiceTrackBuilder._handle_chord()` L947-978

**问题**: `_handle_note` 处理 STACCATO/FERMATA/TRILL，但 `_handle_chord` 完全忽略 `self.pending_decor`。如果 decoration token 出现在和弦前（如 `.[CEG]`），装饰被设置但从不被消费或清除。

**影响**: 装饰 + 和弦组合时，装饰会"泄漏"到下一个非和弦音符上。

---

## 优化建议

### OPT-1: 预编译正则表达式

**位置**: `_parse_duration()` L171, `_parse_note_pitch()` L238, `_parse_voice_section()` L633+

**当前**: 每次调用都重新编译正则。
**建议**: 在模块级预编译：
```python
_RE_DURATION_SUFFIX = re.compile(r'[\d/\.]+$')
_RE_STRIP_DURATION = re.compile(r'[\d/\.]+$')
_RE_BPM = re.compile(r'(\d+)/\d+=(\d+)')
_RE_MIDI_CHANNEL = re.compile(r'channel\s+(\d+)')
```

### OPT-2: `_parse_note_pitch` 避免重复处理 Unicode marks

**位置**: L240 + L273

**当前**: L240 先 strip Unicode marks，L273 又从原始 token 重新计数。
**建议**: 在 strip 之前计数，然后复用：
```python
octaves_up, octaves_down = _count_octave_marks(base)
base = base.replace('\u0307', '').replace('\u0323', '')
# ... 后续直接用 octaves_up, octaves_down，不再调用 _count_octave_marks
```

### OPT-3: `_parse_bar_duration` 未使用 `unit_ticks` 参数

**位置**: L715-727

`unit_ticks` 参数声明但从未使用。计算始终用 `beats_per_bar * TICKS_PER_BEAT`，对于标准拍号（4/4, 3/4 等）正确，但对于非标准单位长度（如 L:1/16 配合某些拍号）可能不准确。要么移除参数，要么正确使用它。

### OPT-4: `_tokenize_music_line` 中 L468 注释误导

**位置**: L468 `# Collect commas for drum notation (e.g. 'B,,')`

注释说"为鼓谱收集逗号"，但逗号是标准 ABC 八度降标记，适用于所有音符（如 `C,` = C3）。建议改为 `# Collect octave-down marks (commas)`。

### OPT-5: Tenuto decoration 已 tokenize 但未实现效果

**位置**: `_handle_note()` L988-1009

STACCATO 缩短 50%，FERMATA 延长 100%，TRILL 展开交替音。TENUTO 被 tokenize 为 `DECOR_TENUTO` 但 `_handle_note` 中无对应处理分支。应添加：
```python
elif decor == 'TENUTO':
    duration = int(duration * 1.1)  # 略微延长
```

### OPT-6: `_expand_repeats` 列表拼接效率

**位置**: `_expand_one_repeat()` L590-606

每次反复都创建新的 list slice + extend。对于大型乐谱（多段反复），可改为 index-based 方案避免频繁内存分配。

---

## 代码质量评估

| 维度 | 评分 | 说明 |
|------|------|------|
| 功能完整性 | 8/10 | 6 阶段计划完成 ~85%，5 个 bug 待修 |
| 测试覆盖 | 9/10 | 67 个测试覆盖所有已实现功能 |
| 代码结构 | 8/10 | `_VoiceTrackBuilder` 封装良好，abs_time 方案优雅 |
| 可读性 | 7/10 | 部分注释误导，depth 变量遮蔽降低可维护性 |
| 性能 | 7/10 | 正则未预编译，大乐谱场景可能有瓶颈 |

## 建议优先级

1. **BUG-1** (`'` 未收集) — 影响 ABC 标准兼容性，修复简单
2. **BUG-2** (bar 溢出) — 可能导致 MIDI 时间轴错误
3. **BUG-3** (depth 遮蔽) — 嵌套反复安全性
4. **BUG-5** (chord decoration) — 修复 1 行
5. **BUG-4** (`::` 双反复) — 低频使用场景
6. **OPT-5** (Tenuto) — 补齐缺失实现
7. **OPT-1~3** — 性能/代码质量优化
