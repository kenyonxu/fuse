# MIDI Composer v2 设计文档 — MidiResource & Player

## 概述

v2 在现有 JSON → MIDI 转换基础上，新增四大能力：

1. **MidiResource**：自定义 Resource 类型，让 MIDI 数据成为 Godot 一等公民
2. **MIDI 导入**：编辑器中导入 .mid 文件自动转为 MidiResource
3. **MidiStreamPlayer**：继承 AudioStreamPlayer 的 MIDI 播放器节点
4. **编辑器预览**：通过 InspectorPlugin 在编辑器内直接预览播放

**依赖策略：** 零外部依赖。合成器参考 addons/midi/ (arlez80) 的架构，但完全用自有代码实现，保持插件独立可发布。

**向后兼容：** v1 的 JSON → MIDI 工作流完全保留不变，v2 是纯增量扩展。

## 文件结构

```
addons/midi_composer/
├── plugin.cfg                        # 插件配置
├── plugin.gd                         # EditorPlugin（扩展：注册 ImportPlugin + InspectorPlugin）
├── converter.gd                      # JSON → MidiData（v1，不变）
├── midi_writer.gd                    # MidiData → .mid 二进制（v1，不变）
├── midi_reader.gd                    # .mid 二进制 → MidiData（v2 新增）
├── midi_types/
│   ├── midi_data.gd                  # MidiData（v1，不变）
│   ├── track_data.gd                 # TrackData（v1，不变）
│   └── note_data.gd                  # NoteData（v1，不变）
├── midi_resource.gd                  # MidiResource 自定义资源（v2 新增）
├── midi_resources/
│   ├── track_resource.gd             # TrackResource（v2 新增）
│   └── note_resource.gd              # NoteResource（v2 新增）
├── midi_import_plugin.gd             # EditorImportPlugin .mid 导入（v2 新增）
├── midi_inspector_plugin.gd          # EditorInspectorPlugin 预览按钮（v2 新增）
├── player/
│   ├── midi_stream_player.gd         # 播放器节点（v2 新增）
│   ├── voice_manager.gd              # 复音管理器（v2 新增）
│   ├── sf2_reader.gd                 # SF2 文件解析器（v2 新增）
│   ├── sf2_bank.gd                   # SF2 Bank/乐器管理（v2 新增）
│   ├── sf2_data.gd                   # SF2 数据结构定义（v2 新增）
│   └── synth_voice.gd                # 单个合成器发声单元（v2 新增）
├── templates/
│   ├── default.json                  # JSON 模板（v1，不变）
│   └── example_full.json             # 完整示例（v1，不变）
└── tests/
    └── test_midi_composer.gd         # 集成测试（v1，扩展）
```

## 数据流

### v1 数据流（不变）

```
.json → converter.gd → MidiData → midi_writer.gd → .mid
```

### v2 新增数据流

```
.json → converter.gd → MidiData → MidiResource (.tres)    [直接路径，v2 新增]
.mid  → midi_reader.gd → MidiData → MidiResource (.tres)  [导入路径，v2 新增]

MidiResource (.tres) → midi_composer_player.gd → 音频输出
```

### 完整数据流

```
.json ─┬→ converter.gd ─→ MidiData ─→ midi_writer.gd ─→ .mid
       └→ converter.gd ─→ MidiData ─→ MidiResource ─→ Player ─→ 音频

.mid ─→ midi_reader.gd ─→ MidiData ─→ MidiResource ─→ Player ─→ 音频
```

## 模块设计

### 1. MidiResource (midi_resource.gd)

自定义 Resource，包装 MIDI 数据，使其成为 Godot 原生资源类型。

```
class_name MidiResource
extends Resource

@export var tempo: int = 120
@export var timebase: int = 480
@export var tracks: Array[TrackResource] = []

func from_midi_data(data: MidiData) -> void       # 从 MidiData 填充
func get_midi_data() -> MidiData                   # 转为内部 MidiData
func get_duration_seconds() -> float               # 计算总时长
func get_track_count() -> int                      # 轨道数量
func from_json_string(json: String) -> bool        # JSON 直接转为 MidiResource
```

**Inspector 只读摘要：**

通过 `_get_property_list()` 添加只读计算属性，在 Inspector 顶部显示摘要信息：

```gdscript
func _get_property_list() -> Array[Dictionary]:
    return [
        {
            "name": "_summary",
            "type": TYPE_STRING,
            "usage": PROPERTY_USAGE_NO_EDITOR,
        },
        {
            "name": "track_count",
            "type": TYPE_INT,
            "hint": PROPERTY_HINT_NONE,
            "usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY,
        },
        {
            "name": "duration_seconds",
            "type": TYPE_FLOAT,
            "hint": PROPERTY_HINT_NONE,
            "usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY,
        },
    ]
```

显示内容：BPM、timebase、轨道数量、总时长。每条轨道的名称、通道、乐器、音符数量通过 `TrackResource` 自身的 `@export` 显示。

**保存格式：** `.tres`（Godot 原生 Resource 序列化）

**关键设计决策：** MidiResource 内部持有 TrackResource（Resource 子类），而非 TrackData（RefCounted）。这样 Inspector 可以显示和编辑轨道数据，且 `.tres` 可正确序列化。

### TrackResource (midi_resources/track_resource.gd)

```
class_name TrackResource
extends Resource

@export var name: String = ""
@export var channel: int = 0
@export var instrument: int = 0
@export var notes: Array[NoteResource] = []
```

### NoteResource (midi_resources/note_resource.gd)

```
class_name NoteResource
extends Resource

@export var pitch: int = 60
@export var start_ticks: int = 0
@export var duration_ticks: int = 480
@export var velocity: int = 100
```

**MidiResource ↔ MidiData 转换：**
- `MidiResource.from_midi_data(data: MidiData)` — MidiData → MidiResource
- `MidiResource.get_midi_data() -> MidiData` — MidiResource → MidiData

TrackData/NoteData（v1 RefCounted）与 TrackResource/NoteResource（v2 Resource）之间一一对应转换。

### 2. MIDI Reader (midi_reader.gd)

SMF Type 0/Type 1 文件解析器，将 .mid 二进制数据转为 MidiData。

```
class_name MidiReader
extends RefCounted

static func from_bytes(data: PackedByteArray) -> ReadResult
static func from_file(path: String) -> ReadResult

class ReadResult:
    var ok: bool
    var midi_data: MidiData
    var error_message: String
```

**解析流程：**
1. 读取 MThd header（format、ntracks、timebase）
2. 逐个读取 MTrk chunk
3. 解析每个事件（delta time → 绝对时间，Note On/Off 配对）
4. 提取 Meta 事件（tempo、track name）
5. 合并 Note On/Off 为 NoteData

**支持的事件类型：**
- Note On (0x90)、Note Off (0x80)
- Program Change (0xC0)
- Control Change (0xB0) — 解析但仅用于提取必要信息，不做完整处理
- Meta: Track Name (FF 03)、Set Tempo (FF 51)、End of Track (FF 2F)

**Running Status 处理：**

MIDI 文件中连续同类型事件可省略 status byte。解析器必须维护 `last_status_byte`：

```gdscript
var _running_status: int = -1

# 读取 status byte 时：
if (byte & 0x80) == 0:
    # 无 status byte，使用 running status
    event_status = _running_status
    # byte 本身是第一个数据字节
else:
    event_status = byte
    _running_status = byte  # 更新 running status（Meta 事件除外）
```

**Format 0 处理：**

Format 0 所有数据在单一 track 中，解析后拆分为多个 TrackData（按通道分离）。Tempo track 信息保留在第一个 TrackData 中。

**未知事件跳过：**

对不支持的通道事件（如 SysEx F0/F7、Pitch Bend E0、Aftertouch D0 等）和未知 Meta 事件，读取完整长度后跳过，不报错。

### 3. Import Plugin (midi_import_plugin.gd)

EditorImportPlugin，让 Godot 编辑器识别和导入 .mid 文件。

```
class_name MidiImportPlugin
extends EditorImportPlugin

func _get_importer_name() -> String      # "midi_composer"
func _get_visible_name() -> String       # "MIDI Resource"
func _get_recognized_extensions()        # [".mid"]
func _get_resource_type()                # "MidiResource"
func _get_save_extension()               # "tres"
func _get_preset_count() -> int          # 0
func _get_import_order() -> int          # 0
func _get_priority() -> float            # 1.0
func _get_import_options(...)            # []
func _import(source_file, save_path, ...) -> Error
```

**_import 实现：**
1. 读取 .mid 文件为 PackedByteArray
2. 调用 `MidiReader.from_bytes()` 解析
3. 若解析失败，`push_error()` 并返回 `ERR_PARSE_ERROR`
4. 创建 `MidiResource`，调用 `from_midi_data()`
5. 保存为 .tres，返回 `OK`

**.mid 源文件修改时自动重新导入**（EditorImportPlugin 内置行为）。

### 4. MidiStreamPlayer (player/midi_composer_player.gd)

继承 `AudioStreamPlayer`，体验与标准音频节点一致。

**从 AudioStreamPlayer 继承的能力：**
- `volume_db` — 音量控制
- `bus` — 音频总线路由
- `mix_target` — 混音目标
- 与 Godot 音频系统自然集成（混音、效果链等）

**需要覆盖/重新实现的基类能力：**

| 基类成员 | 处理方式 | 原因 |
|---|---|---|
| `stream` | `_get_property_list()` 过滤隐藏 | 内部使用 AudioStreamGenerator，用户不应操作 |
| `play(from_position)` | 覆盖，初始化播放器并调用 `super.play(0)` | 基类 from_position 对 Generator 无意义 |
| `stop()` | 覆盖，重置序列器 + 调用 `super.stop()` | 需要重置内部状态 |
| `get_playback_position()` | 覆盖，返回 `_song_position` | 基类返回 buffer 位置，非歌曲位置 |
| `finished` 信号 | 手动 emit | AudioStreamGenerator 不会自动结束 |
| `pitch_scale` | 隐藏或映射为播放速度 | 音频 pitch != MIDI 速度 |
| `autoplay` | 保留可用 | 用户可设置自动播放 |
| `pause()` | 新增 | 基类无此方法 |

```
class_name MidiStreamPlayer
extends AudioStreamPlayer

@export var midi_resource: MidiResource : set = set_midi_resource
@export_file("*.sf2") var soundfont: String = "" : set = set_soundfont
@export var loop: bool = false

signal note_triggered(channel: int, pitch: int, velocity: int)

# 内部状态
var _generator: AudioStreamGenerator
var _playback: AudioStreamGeneratorPlayback
var _voice_manager: VoiceManager
var _sf2_bank: Sf2Bank
var _song_position: float = 0.0      # 当前歌曲位置（秒）
var _is_paused: bool = false

# ── 属性管理 ──

func _get_property_list() -> Array[Dictionary]:
    var props: Array[Dictionary] = super._get_property_list()
    # 隐藏基类 stream 属性，防止用户误操作
    props = props.filter(func(p): return p["name"] != "stream")
    return props

func _ready() -> void:
    _generator = AudioStreamGenerator.new()
    _generator.mix_rate = ProjectSettings.get_setting("audio/default_mix_rate")
    stream = _generator

# ── 播放控制 ──

func play(from_position: float = 0.0) -> void:
    if midi_resource == null:
        push_warning("MidiStreamPlayer: midi_resource 为空")
        return
    _playback = get_stream_playback()
    _song_position = from_position
    _is_paused = false
    _start_sequencer()
    super.play(0.0)  # 基类 from_position 对 Generator 无意义，始终传 0

func stop() -> void:
    _stop_all_voices()
    _song_position = 0.0
    _is_paused = false
    super.stop()

func pause() -> void:
    _is_paused = true
    super.stop()  # 暂停基类音频输出（不是真正的 stop）

func resume() -> void:
    if not _is_paused:
        return
    _is_paused = false
    super.play(0.0)

func get_playback_position() -> float:
    return _song_position  # 覆盖基类，返回歌曲位置而非 buffer 位置

func seek(position: float) -> void:
    _song_position = clampf(position, 0.0, _get_duration())
    # kill 当前 voice，重新调度该时间点的事件

# ── 每帧处理 ──

func _process(delta: float) -> void:
    if _is_paused or not playing or _playback == null:
        return
    var prev_position: float = _song_position
    _advance_sequencer(delta)
    _fill_generator_buffer()
    # 检测播放结束
    if _song_position >= _get_duration():
        if loop:
            _song_position = 0.0
            _restart_sequencer()
        else:
            stop()
            finished.emit()

func _fill_generator_buffer() -> void:
    var frames_available: int = _playback.get_frames_available()
    var to_fill: int = mini(frames_available, 4096)
    for i in range(to_fill):
        var frame: Vector2 = Vector2.ZERO
        for voice in _voice_manager.get_active_voices():
            frame += voice.get_next_frame()
        _playback.push_frame(frame)
```

**Buffer 管理策略：**
- AudioStreamGenerator 默认 buffer 大小根据 `buffer_length` 属性决定
- `_fill_generator_buffer()` 每帧填充 `_playback.get_frames_available()` 中的可用帧数
- 最大单次填充 4096 帧，防止帧时间过长导致卡顿
- 如果 buffer 空间不足 128 帧，提前返回，下一帧继续（避免积压）

### 5. VoiceManager (player/voice_manager.gd)

复音管理器，负责 synth_voice 的分配、回收和混音。

```
class_name VoiceManager
extends RefCounted

const MAX_VOICES: int = 128
const VOICES_PER_CHANNEL: int = 16  # 每通道最大同时发音数

func start_note(channel: int, key: int, velocity: int,
        sample: Sf2SampleInfo, target_rate: int) -> void
func stop_note(channel: int, key: int) -> void
func stop_all() -> void
func get_active_voices() -> Array[SynthVoice]
func get_voice_count() -> int
```

**分配策略：**
1. 查找同 channel + key 已有 voice → 不重复分配（防止重复 Note On）
2. 查找 IDLE voice 分配
3. 若无 IDLE voice，执行 **voice stealing**：终止处于 RELEASE 状态最久的 voice
4. 若仍无可用 voice，终止 RELEASE 状态的 voice 中 sustain 最小的
5. 最后兜底：终止最早的 ATTACK/DECAY/SUSTAIN voice

**通道复音限制：**
- 每通道最大 `VOICES_PER_CHANNEL`（16）个同时发音
- 达到上限时，该通道内 voice stealing 优先

### 6. SF2 Data Structures (player/sf2_data.gd)

SF2 文件解析后的数据结构定义。

```
class_name Sf2Data
extends RefCounted

var version: String = ""                    # SF2 版本（如 "2.04"）
var sound_engine: String = ""               # 目标引擎
var bank_name: String = ""                  # Bank 名称
var sample_rate: int = 44100                # 默认采样率
var sample_data: PackedByteArray = []       # sdta chunk 原始 PCM 数据
var presets: Array[Sf2Preset] = []          # 预设列表
var instruments: Array[Sf2Instrument] = []  # 乐器列表
var samples: Array[Sf2SampleHeader] = []    # 采样头列表

class_name Sf2Preset
extends RefCounted

var name: String = ""
var preset_index: int = 0
var bank: int = 0
var zones: Array[Sf2PresetZone] = []

class_name Sf2PresetZone
extends RefCounted

var key_range: Vector2i = Vector2i(0, 127)      # (low, high)
var vel_range: Vector2i = Vector2i(0, 127)       # (low, high)
var instrument_index: int = -1                    # 链接到 Sf2Instrument
var is_global: bool = false                       # Global Zone 标记

class_name Sf2Instrument
extends RefCounted

var name: String = ""
var zones: Array[Sf2InstrumentZone] = []

class_name Sf2InstrumentZone
extends RefCounted

var key_range: Vector2i = Vector2i(0, 127)
var vel_range: Vector2i = Vector2i(0, 127)
var sample_index: int = -1                       # 链接到 Sf2SampleHeader
var root_key: int = -1                            # 覆盖采样的 root key
var tuning_cents: int = 0                        # 音高微调
var attack: float = -1.0                          # ADSR（-1 表示使用采样默认值）
var decay: float = -1.0
var sustain: float = -1.0                         # 0.0-1.0，实际值为 (1200 - centibel) / 1000
var release: float = -1.0
var is_global: bool = false                       # Global Zone 标记

class_name Sf2SampleHeader
extends RefCounted

var name: String = ""
var start: int = 0                    # sdta 中的起始偏移（word index × 2 = byte offset）
var end: int = 0                      # 结束偏移
var loop_start: int = 0               # 循环起始偏移
var loop_end: int = 0                 # 循环结束偏移
var sample_rate: int = 44100
var original_pitch: int = 60          # 原始音高 MIDI note
var pitch_correction: int = 0         # 音高修正（百分之一半音）
var sample_type: int = 0              # 位掩码：bit0=mono, bit1=right, bit2=left, bit3=linked
var link_index: int = 0               # 立体声链接的另一个采样索引
```

### 7. SF2 Reader (player/sf2_reader.gd)

SoundFont 2 (.sf2) 文件解析器。

```
class_name Sf2Reader
extends RefCounted

static func read_file(path: String) -> Sf2ReadResult

class Sf2ReadResult:
    var ok: bool
    var data: Sf2Data
    var error_message: String
```

**解析范围（最小可用集）：**

| SF2 Section | 解析内容 |
|---|---|
| INFO chunk | 版本、名称、采样率 |
| sdta chunk | 采样数据（raw PCM，signed 16-bit） |
| pdta chunk | 预设 → 乐器 → 采样 映射 |

**最小实现需要的 pdta 子块：**
- `PHDR` (Preset Header)：预设列表
- `PBAG` (Preset Bag)：预设区域索引
- `PMOD` (Preset Mod)：预设调制器（跳过，不解析）
- `PGEN` (Preset Gen)：预设生成参数（key range、vel range、instrument link）
- `INST` (Instrument Header)：乐器列表
- `IBAG` (Instrument Bag)：乐器区域索引
- `IMOD` (Instrument Mod)：乐器调制器（跳过，不解析）
- `IGEN` (Instrument Gen)：乐器生成参数（sample link、root key、tuning、ADSR）
- `SHDR` (Sample Header)：采样信息

**采样数据格式：**
- 16-bit signed PCM，little-endian
- 单声道（立体声通过 sample_type + link_index 关联）
- 采样数据存储在 sdta chunk 中，SHDR 的 start/end 是 word index（× 2 得到 byte offset）

**不需要解析的（后续迭代）：**
- Modulator (PMOD/IMOD)：滤波器、LFO 等调制器
- 3vl / 24-bit 采样（仅支持 16-bit）

### 8. Sf2Bank (player/sf2_bank.gd)

管理已加载的 SF2 数据，提供按 MIDI Program + Key + Velocity 查找采样的接口。

```
class_name Sf2Bank
extends RefCounted

func load_from_data(sf2_data: Sf2Data) -> void
func get_sample(preset_index: int, key: int, velocity: int) -> Sf2SampleInfo
func get_sample_count() -> int

class Sf2SampleInfo:
    var sample_data: PackedByteArray   # PCM 数据（signed 16-bit）
    var sample_rate: int               # 原始采样率
    var root_key: int                  # 原始音高
    var tuning_cents: int              # 音高微调（百分之一半音）
    var loop_start: int                # 循环起始（采样点 index）
    var loop_end: int                  # 循环结束（采样点 index）
    var has_loop: bool                 # 是否有循环
    var attack: float                  # ADSR Attack（秒）
    var hold: float                    # Hold（可选，默认 0）
    var decay: float                   # ADSR Decay（秒）
    var sustain: float                 # ADSR Sustain（0.0-1.0）
    var release: float                 # ADSR Release（秒）
```

**查找逻辑（含 Global Zone）：**

1. 按 `preset_index` 找到 `Sf2Preset`
2. 初始化默认参数（key_range=0-127, vel_range=0-127）
3. 遍历 preset zones：
   - 若 `is_global == true`：合并其生成参数到默认值（local zone 会覆盖）
   - 若 `is_global == false` 且 `key` 和 `velocity` 在范围内：匹配成功
4. 匹配到的 zone 提供 `instrument_index`
5. 按 `instrument_index` 找到 `Sf2Instrument`
6. 同理遍历 instrument zones（Global Zone + local zone），最终得到 `sample_index`
7. 从 SHDR 提取采样信息，组装 `Sf2SampleInfo`

**Global Zone 合并规则：**
- Global Zone 提供默认值（key range、vel range、ADSR 等）
- Local Zone 的参数覆盖 Global Zone 的同名参数
- 若多个 Local Zone 匹配，选择 key range 最精确的

**Velocity 层处理：**
- 同一个 key 可能匹配多个 velocity range 不同的 zone
- 选择 velocity 落入范围且 vel range 最窄的 zone（最精确匹配）

### 9. SynthVoice (player/synth_voice.gd)

单个合成器发声单元，管理一个音符的生命周期。

```
class_name SynthVoice
extends RefCounted

enum State { IDLE, ATTACK, HOLD, DECAY, SUSTAIN, RELEASE, FINISHED }

var state: State = State.IDLE
var channel: int = 0
var key: int = 0

func start(sample: Sf2SampleInfo, p_channel: int, p_key: int,
        velocity: float, target_rate: int) -> void
func stop() -> void                     # 进入 Release 阶段
func get_next_frame() -> Vector2        # 生成下一个立体声采样帧
func is_finished() -> bool
func is_releasing() -> bool
```

**ADSR 包络：**

```
Amplitude
    │    /\
    │   /  \    ──── Hold (可选)
    │  /    \___________
    │ /                 \
    │/                   \
    └─────────────────────→ Time
      A  H  D  Sustain   R
```

**采样循环处理：**

SF2 中的采样分为循环采样和一次性采样：

- **Attack 阶段：** 从采样起始位置播放，到达 loop_end 后跳回 loop_start 循环
- **Sustain 阶段：** 继续在 loop_start ↔ loop_end 之间循环
- **Note Off（Release 阶段）：** 退出循环，从当前位置继续播放到采样末尾，同时包络衰减
- **无循环的采样：** 从头播到尾，无循环行为（percussion 类乐器常见）

```gdscript
var _sample_position: float = 0.0  # 浮点采样位置，支持非整数 playback_rate

func get_next_frame() -> Vector2:
    if state == State.FINISHED:
        return Vector2.ZERO

    var pos: int = int(_sample_position)
    # 读取 16-bit signed PCM
    var sample_value: float = _read_sample(pos)
    # 线性插值（消除非整数 playback_rate 的噪声）
    var frac: float = _sample_position - pos
    var next_pos: int = mini(pos + 1, _sample_data_end)
    var next_value: float = _read_sample(next_pos)
    sample_value = lerpf(sample_value, next_value, frac)

    # 推进采样位置
    _sample_position += _playback_step

    # 循环处理：仅在非 RELEASE 状态下循环
    if _has_loop and state != State.RELEASE:
        if _sample_position >= float(_loop_end):
            _sample_position -= float(_loop_end - _loop_start)
    elif _sample_position >= float(_sample_data_end):
        state = State.FINISHED
        return Vector2.ZERO

    # 应用 ADSR 包络
    var envelope: float = _update_envelope()
    return Vector2.ONE * sample_value * envelope * _velocity_factor
```

**音高变换：**
```
_semitones = (key - root_key + tuning_cents / 100.0)
_playback_step = target_sample_rate × 2^(_semitones / 12.0) / original_sample_rate
```

`_playback_step` 是每次调用 `get_next_frame()` 时采样位置前进的浮点步长。

### 10. InspectorPlugin (midi_inspector_plugin.gd)

在 MidiResource 的 Inspector 底部添加预览播放按钮。

```
class_name MidiInspectorPlugin
extends EditorInspectorPlugin

func _can_handle(object: Object) -> bool    # return object is MidiResource
func _parse_end(object: Object) -> void      # 在属性末尾添加预览 UI
```

**预览 UI：**
- ▶ Play / ⏹ Stop 按钮
- 当前播放位置进度条
- 使用临时 MidiStreamPlayer 播放，Inspector 关闭或切换对象时自动停止

**Soundfont 来源：**

编辑器预览需要一个 soundfont 才能发声。来源优先级：
1. MidiResource 上的可选属性 `@export_file("*.sf2") var preview_soundfont: String = ""`
2. 若为空，回退到项目设置 `ProjectSettings.get_setting("midi_composer/default_soundfont", "")`
3. 若仍为空，Play 按钮灰显并提示 "请先在项目设置中配置默认 Soundfont"

**实现要点：**
- 创建临时 MidiStreamPlayer 节点（`@tool` 模式下运行）
- 添加到 EditorInterface 的 base_control 作为临时子节点
- `_parse_end` 每次调用时检查是否需要重建 UI（对象切换时）

**项目设置注册：**

plugin.gd 的 `_enter_tree()` 中注册项目设置：

```gdscript
if not ProjectSettings.has_setting("midi_composer/default_soundfont"):
    ProjectSettings.set_setting("midi_composer/default_soundfont", "")
ProjectSettings.set_initial_value("midi_composer/default_soundfont", "")
ProjectSettings.add_property_info({
    "name": "midi_composer/default_soundfont",
    "type": TYPE_STRING,
    "hint": PROPERTY_HINT_GLOBAL_FILE,
    "hint_string": "*.sf2",
})
```

## plugin.gd 变更

```
@tool
extends EditorPlugin

var _import_plugin: MidiImportPlugin
var _inspector_plugin: MidiInspectorPlugin

func _enter_tree():
    # v1: Tools 菜单
    add_tool_menu_item("Compose MIDI from JSON...", _on_tool_menu_pressed)
    # v2: 导入插件 + Inspector 插件
    _import_plugin = MidiImportPlugin.new()
    add_import_plugin(_import_plugin)
    _inspector_plugin = MidiInspectorPlugin.new()
    add_inspector_plugin(_inspector_plugin)
    # v2: 注册项目设置（默认 soundfont 路径）
    _register_project_settings()

func _exit_tree():
    remove_tool_menu_item("Compose MIDI from JSON...")
    remove_import_plugin(_import_plugin)
    remove_inspector_plugin(_inspector_plugin)
    _import_plugin = null
    _inspector_plugin = null

func _register_project_settings() -> void:
    if not ProjectSettings.has_setting("midi_composer/default_soundfont"):
        ProjectSettings.set_setting("midi_composer/default_soundfont", "")
    ProjectSettings.set_initial_value("midi_composer/default_soundfont", "")
    ProjectSettings.add_property_info({
        "name": "midi_composer/default_soundfont",
        "type": TYPE_STRING,
        "hint": PROPERTY_HINT_GLOBAL_FILE,
        "hint_string": "*.sf2",
    })
```

## 实现优先级

| 阶段 | 内容 | 依赖 |
|------|------|------|
| P0 | sf2_data.gd（SF2 数据结构定义） | 无 |
| P0 | midi_reader.gd（.mid → MidiData，含 Running Status） | 无 |
| P0 | MidiResource + TrackResource + NoteResource | 无 |
| P1 | midi_import_plugin.gd（编辑器导入） | midi_reader, MidiResource |
| P1 | sf2_reader.gd（SF2 文件解析） | sf2_data |
| P1 | sf2_bank.gd（乐器管理，含 Global Zone） | sf2_reader, sf2_data |
| P2 | synth_voice.gd（合成器发声，含循环处理） | sf2_data |
| P2 | voice_manager.gd（复音管理，含 voice stealing） | synth_voice |
| P2 | midi_composer_player.gd（播放器节点） | voice_manager, sf2_bank, MidiResource |
| P3 | midi_inspector_plugin.gd（编辑器预览） | midi_composer_player |

## 参考资料

- `addons/midi/SMF.gd` — MIDI 读取参考（arlez80），解析逻辑参考但不直接依赖
- `addons/midi/SoundFont.gd` — SF2 读取参考，数据结构参考但不直接依赖
- `addons/midi/MidiPlayer.gd` — 播放器架构参考，合成器流程参考但不直接依赖
- SoundFont 2.04 技术规范：https://www.fluidsynth.org/resources/soundfont/SoundFont%20Technical%20Specification%202.04.pdf

---

**创建日期:** 2026-03-24
**状态:** 设计完成，待实现
