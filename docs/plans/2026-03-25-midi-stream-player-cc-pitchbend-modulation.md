# MidiStreamPlayer CC / Pitch Bend / Modulation 功能扩展计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 MidiStreamPlayer 添加 CC 事件（音量/表情/声相）、Pitch Bend（弯音）和 Modulation（颤音）支持，使游戏 BGM 播放具备完整的 MIDI 表现力。

**Architecture:** 分三层改造——数据管线层（MidiReader 解析 CC/Pitch Bend 存入 MidiData）、播放器层（ChannelState 通道状态管理 + _sorted_events 整合）、合成层（SynthVoice per-voice pitch bend / modulation LFO / pan）。现有 MidiWriter 也需扩展以支持编码 CC/Pitch Bend 事件，用于测试 fixture 构建。

**Tech Stack:** GDScript 2.0, Godot 4.6, AudioStreamGenerator

**排除功能（游戏不需要）:** SysEx、实时 MIDI 输入、Drum Assign Groups、RPN/NRPN

**确认已实现:** Velocity Range 过滤（`Sf2Bank.get_sample()` 已正确实现）

---

## 文件修改总览

| 文件 | 任务 | 变更类型 |
|------|------|----------|
| `addons/midi_composer/midi_types/midi_data.gd` | 1 | 修改 |
| `addons/midi_composer/midi_types/track_data.gd` | 1 | 修改 |
| `addons/midi_composer/midi_resource.gd` | 1 | 修改 |
| `addons/midi_composer/midi_reader.gd` | 1 | 修改 |
| `addons/midi_composer/midi_writer.gd` | 1 | 修改 |
| `addons/midi_composer/tests/test_cc_pitchbend_roundtrip.gd` | 2 | **新建** |
| `addons/midi_composer/player/channel_state.gd` | 3 | **新建** |
| `addons/midi_composer/player/synth_voice.gd` | 4, 6 | 修改 |
| `addons/midi_composer/player/midi_stream_player.gd` | 5, 7 | 修改 |

---

## Task 1: 数据管线 — MidiData / TrackData / MidiReader / MidiWriter 扩展

**目标:** MidiData 和 TrackData 能存储 CC/Pitch Bend 事件，MidiReader 不再丢弃这些事件，MidiWriter 能编码它们。

### Step 1: 修改 MidiData 新增 cc_events 和 pitch_bend_events 字段

**Files:**
- Modify: `addons/midi_composer/midi_types/midi_data.gd`

```gdscript
## MIDI 文件数据

class_name MidiData
extends RefCounted

var tempo: int = 120
var timebase: int = 480
var tracks: Array[TrackData] = []
## 速度变化事件: [{time_ticks: int, bpm: int}]
var tempo_events: Array[Dictionary] = []
## CC 变更事件: [{time_ticks: int, channel: int, controller: int, value: int}]
var cc_events: Array[Dictionary] = []
## Pitch Bend 事件: [{time_ticks: int, channel: int, value: int}]
var pitch_bend_events: Array[Dictionary] = []

func _init(p_tempo: int = 120, p_tracks: Array[TrackData] = [],
		p_timebase: int = 480, p_tempo_events: Array[Dictionary] = [],
		p_cc_events: Array[Dictionary] = [],
		p_pitch_bend_events: Array[Dictionary] = []) -> void:
	tempo = p_tempo
	tracks = p_tracks
	timebase = p_timebase
	tempo_events = p_tempo_events
	cc_events = p_cc_events
	pitch_bend_events = p_pitch_bend_events
```

### Step 2: 修改 TrackData 新增 cc_events 和 pitch_bend_events

**Files:**
- Modify: `addons/midi_composer/midi_types/track_data.gd`

在 `notes` 字段后添加：

```gdscript
## CC 变更事件: [{time_ticks: int, controller: int, value: int}]
var cc_events: Array[Dictionary] = []
## Pitch Bend 事件: [{time_ticks: int, value: int}]
var pitch_bend_events: Array[Dictionary] = []
```

更新 `_init()`：

```gdscript
func _init(p_name: String = "", p_channel: int = 0, p_instrument: int = 0,
		p_notes: Array[NoteData] = [],
		p_cc_events: Array[Dictionary] = [],
		p_pitch_bend_events: Array[Dictionary] = []) -> void:
	name = p_name
	channel = p_channel
	instrument = p_instrument
	notes = p_notes
	cc_events = p_cc_events
	pitch_bend_events = p_pitch_bend_events
```

### Step 3: 修改 MidiReader 解析 CC 和 Pitch Bend 事件

**Files:**
- Modify: `addons/midi_composer/midi_reader.gd`

**3a.** 在 `_parse_event()` 中，将 `_STATUS_CONTROL_CHANGE` 分支（约第 254-259 行）从：

```gdscript
		_STATUS_CONTROL_CHANGE:
			# 读取 2 个数据字节并跳过
			if stream.get_available_bytes() >= 2:
				stream.get_u8()  # controller
				stream.get_u8()  # value
			return {}
```

改为：

```gdscript
		_STATUS_CONTROL_CHANGE:
			if stream.get_available_bytes() >= 2:
				var controller: int = stream.get_u8()
				var value: int = stream.get_u8()
				return {
					"type": "control_change",
					"channel": channel,
					"controller": controller,
					"value": value,
				}
			return {}
```

**3b.** 将 `_STATUS_PITCH_BEND` 分支（约第 274-279 行）从：

```gdscript
		_STATUS_PITCH_BEND:
			# 读取 2 个数据字节并跳过
			if stream.get_available_bytes() >= 2:
				stream.get_u8()
				stream.get_u8()
			return {}
```

改为：

```gdscript
		_STATUS_PITCH_BEND:
			if stream.get_available_bytes() >= 2:
				var lsb: int = stream.get_u8()
				var msb: int = stream.get_u8()
				var raw_value: int = (msb << 7) | lsb  # 14-bit: 0-16383
				return {
					"type": "pitch_bend",
					"channel": channel,
					"value": raw_value,
				}
			return {}
```

**3c.** 在 `_build_format_0()` 中（约第 424-439 行），扩展 channel 分组的 match 分支，将 `"control_change"` 和 `"pitch_bend"` 也分发到 `channel_events`：

```gdscript
		"note_on", "note_off", "program_change", "control_change", "pitch_bend":
			var ch: int = event.get("channel", 0)
			if not channel_events.has(ch):
				channel_events[ch] = []
				channel_instruments[ch] = 0
			channel_events[ch].append(event)
			if event_type == "program_change":
				channel_instruments[ch] = event.get("program", 0)
```

**3d.** 在 `_build_format_0()` 末尾构建 tracks 的循环中（约第 448-455 行），从 channel_events 中提取 CC/Pitch Bend 事件并收集到顶级 cc_events/pitch_bend_events 数组：

在 `var tracks: Array[TrackData] = []` 之后添加：

```gdscript
	var cc_events: Array[Dictionary] = []
	var pitch_bend_events: Array[Dictionary] = []
```

在 for ch 循环内，`_pair_notes()` 之后添加：

```gdscript
		# 提取 CC 和 Pitch Bend 事件
		var track_cc: Array[Dictionary] = []
		var track_pb: Array[Dictionary] = []
		for evt in ch_events:
			var evt_type: String = evt.get("type", "")
			if evt_type == "control_change":
				cc_events.append({
					"time_ticks": evt["time_ticks"],
					"channel": ch,
					"controller": evt["controller"],
					"value": evt["value"],
				})
				track_cc.append({"time_ticks": evt["time_ticks"], "controller": evt["controller"], "value": evt["value"]})
			elif evt_type == "pitch_bend":
				pitch_bend_events.append({
					"time_ticks": evt["time_ticks"],
					"channel": ch,
					"value": evt["value"],
				})
				track_pb.append({"time_ticks": evt["time_ticks"], "value": evt["value"]})
```

修改 `TrackData.new()` 调用，传入 track_cc 和 track_pb：

```gdscript
		tracks.append(TrackData.new(ch_name, ch, channel_instruments[ch], notes, track_cc, track_pb))
```

修改最后的 `ReadResult.new()` 调用：

```gdscript
	return ReadResult.new(true, MidiData.new(tempo, tracks, timebase, tempo_events, cc_events, pitch_bend_events))
```

**3e.** 在 `_build_format_1()` 中（约第 485-498 行），同样提取 CC/Pitch Bend 事件。在 `for track_idx` 循环之前添加：

```gdscript
	var cc_events: Array[Dictionary] = []
	var pitch_bend_events: Array[Dictionary] = []
```

在 `_build_track_from_events()` 之后、`if track_idx == 0` 之前，从 raw_events 提取：

```gdscript
		for event in raw_events:
			var evt_type: String = event.get("type", "")
			if evt_type == "control_change":
				cc_events.append({
					"time_ticks": event["time_ticks"],
					"channel": event.get("channel", 0),
					"controller": event["controller"],
					"value": event["value"],
				})
			elif evt_type == "pitch_bend":
				pitch_bend_events.append({
					"time_ticks": event["time_ticks"],
					"channel": event.get("channel", 0),
					"value": event["value"],
				})
```

修改 `_build_track_from_events()` 以提取轨道级别的 CC/Pitch Bend（传入 raw_events 并从中提取）：

更新 `_build_track_from_events()` 签名和实现：

```gdscript
static func _build_track_from_events(raw_events: Array, track_idx: int) -> TrackData:
	var track_name: String = "Track %d" % track_idx
	var instrument: int = 0
	var channel: int = 0
	var track_cc: Array[Dictionary] = []
	var track_pb: Array[Dictionary] = []

	# 第一遍：提取轨道名称、乐器、CC 和 Pitch Bend
	for event in raw_events:
		var event_type: String = event.get("type", "")
		if event_type == "meta_track_name":
			track_name = event.get("name", track_name)
		elif event_type == "program_change":
			instrument = event.get("program", 0)
			channel = event.get("channel", 0)
		elif event_type == "control_change":
			track_cc.append({"time_ticks": event["time_ticks"], "controller": event["controller"], "value": event["value"]})
		elif event_type == "pitch_bend":
			track_pb.append({"time_ticks": event["time_ticks"], "value": event["value"]})

	# 第二遍：配对音符
	var notes: Array[NoteData] = _pair_notes(raw_events)

	return TrackData.new(track_name, channel, instrument, notes, track_cc, track_pb)
```

修改 `_build_format_1()` 最后的 `ReadResult.new()`：

```gdscript
	return ReadResult.new(true, MidiData.new(tempo, tracks, timebase, tempo_events, cc_events, pitch_bend_events))
```

### Step 4: 修改 MidiWriter 支持 CC 和 Pitch Bend 编码

**Files:**
- Modify: `addons/midi_composer/midi_writer.gd`

**4a.** 添加常量（在现有常量区域，约第 14 行后）：

```gdscript
const _STATUS_CONTROL_CHANGE: int = 0xB0
const _STATUS_PITCH_BEND: int = 0xE0
```

**4b.** 在 `_write_note_track()` 中（约第 98 行），在收集 note events 之后，也收集 CC 和 Pitch Bend 事件：

在 `var events: Array[Dictionary] = []` 循环之后、排序之前添加：

```gdscript
	# CC 事件
	var _PRIORITY_CC: int = 4
	for cc in track_data.cc_events:
		events.append({
			"time": cc["time_ticks"],
			"type": _PRIORITY_CC,
			"status": _STATUS_CONTROL_CHANGE | (track_data.channel & 0x0F),
			"pitch": cc["controller"],       # 复用 pitch 字段存 controller
			"velocity": cc["value"],          # 复用 velocity 字段存 value
		})

	# Pitch Bend 事件
	var _PRIORITY_PITCH_BEND: int = 5
	for pb in track_data.pitch_bend_events:
		var raw_value: int = pb["value"]
		events.append({
			"time": pb["time_ticks"],
			"type": _PRIORITY_PITCH_BEND,
			"status": _STATUS_PITCH_BEND | (track_data.channel & 0x0F),
			"pitch": raw_value & 0x7F,                # LSB
			"velocity": (raw_value >> 7) & 0x7F,       # MSB
		})
```

### Step 5: 修改 MidiResource 同步新字段

**Files:**
- Modify: `addons/midi_composer/midi_resource.gd`

添加导出字段：

```gdscript
@export var cc_events: Array[Dictionary] = []
@export var pitch_bend_events: Array[Dictionary] = []
```

在 `from_midi_data()` 中（约第 16 行后）添加：

```gdscript
	cc_events = data.cc_events.duplicate(true)
	pitch_bend_events = data.pitch_bend_events.duplicate(true)
```

在 `get_midi_data()` 中更新 `MidiData.new()` 调用：

```gdscript
	return MidiData.new(tempo, track_list, timebase, tempo_events.duplicate(true), cc_events.duplicate(true), pitch_bend_events.duplicate(true))
```

### Step 6: Commit

```bash
git add addons/midi_composer/midi_types/midi_data.gd addons/midi_composer/midi_types/track_data.gd addons/midi_composer/midi_reader.gd addons/midi_composer/midi_writer.gd addons/midi_composer/midi_resource.gd
git commit -m "feat(midi): add CC and Pitch Bend support to data pipeline

MidiData/TrackData now store CC and Pitch Bend events.
MidiReader parses control_change and pitch_bend instead of discarding.
MidiWriter encodes CC and Pitch Bend events.
MidiResource syncs new fields.
"
```

---

## Task 2: 回归测试 — CC / Pitch Bend 往返测试

**目标:** 确保数据管线正确性，MidiReader 解析 MidiWriter 编码的 CC/Pitch Bend 后结果一致。

### Step 1: 编写测试脚本

**Files:**
- Create: `addons/midi_composer/tests/test_cc_pitchbend_roundtrip.gd`

```gdscript
extends SceneTree

func _init() -> void:
	print("\n=== CC / Pitch Bend Round-trip Test ===")

	# 构建包含 CC 和 Pitch Bend 的 MidiData
	var midi_data := MidiData.new(120, [
		TrackData.new("Test", 0, 0, [
			NoteData.new(60, 0, 480, 100),
			NoteData.new(64, 480, 480, 80),
		], [
			{"time_ticks": 0, "controller": 7, "value": 80},      # CC7 volume
			{"time_ticks": 0, "controller": 10, "value": 64},     # CC10 pan center
			{"time_ticks": 960, "controller": 11, "value": 100},  # CC11 expression
			{"time_ticks": 960, "controller": 1, "value": 64},    # CC1 modulation
		], [
			{"time_ticks": 0, "value": 8192},    # pitch bend center
			{"time_ticks": 480, "value": 9000},  # pitch bend up
		]),
	])

	# 编码
	var bytes: PackedByteArray = MidiWriter.encode(midi_data)
	print("Encoded %d bytes" % bytes.size())

	# 解码
	var result := MidiReader.from_bytes(bytes)
	if not result.ok:
		print("FAIL: parse error: %s" % result.error_message)
		quit(1)
		return

	# 验证音符
	var notes = result.midi_data.tracks[0].notes
	if notes.size() != 2:
		print("FAIL: expected 2 notes, got %d" % notes.size())
		quit(1)
		return

	if notes[0].pitch != 60 or notes[0].velocity != 100:
		print("FAIL: note 0 mismatch")
		quit(1)
		return

	if notes[1].pitch != 64 or notes[1].velocity != 80:
		print("FAIL: note 1 mismatch")
		quit(1)
		return

	print("PASS: notes round-trip")

	# 验证 CC 事件
	var cc = result.midi_data.cc_events
	if cc.size() != 4:
		print("FAIL: expected 4 CC events, got %d" % cc.size())
		quit(1)
		return

	if cc[0]["controller"] != 7 or cc[0]["value"] != 80:
		print("FAIL: CC7 mismatch")
		quit(1)
		return

	if cc[1]["controller"] != 10 or cc[1]["value"] != 64:
		print("FAIL: CC10 mismatch")
		quit(1)
		return

	if cc[2]["controller"] != 11 or cc[2]["value"] != 100:
		print("FAIL: CC11 mismatch")
		quit(1)
		return

	if cc[3]["controller"] != 1 or cc[3]["value"] != 64:
		print("FAIL: CC1 mismatch")
		quit(1)
		return

	print("PASS: CC events round-trip")

	# 验证 Pitch Bend 事件
	var pb = result.midi_data.pitch_bend_events
	if pb.size() != 2:
		print("FAIL: expected 2 Pitch Bend events, got %d" % pb.size())
		quit(1)
		return

	if pb[0]["value"] != 8192:
		print("FAIL: Pitch Bend center expected 8192, got %d" % pb[0]["value"])
		quit(1)
		return

	if pb[1]["value"] != 9000:
		print("FAIL: Pitch Bend up expected 9000, got %d" % pb[1]["value"])
		quit(1)
		return

	print("PASS: Pitch Bend events round-trip")

	# 验证 TrackData 级别的 CC/Pitch Bend
	var track_cc = result.midi_data.tracks[0].cc_events
	if track_cc.size() != 4:
		print("FAIL: track CC expected 4, got %d" % track_cc.size())
		quit(1)
		return

	print("PASS: track-level CC events")

	var track_pb = result.midi_data.tracks[0].pitch_bend_events
	if track_pb.size() != 2:
		print("FAIL: track Pitch Bend expected 2, got %d" % track_pb.size())
		quit(1)
		return

	print("PASS: track-level Pitch Bend events")

	# 验证无 CC/Pitch Bend 的旧格式向后兼容
	var simple_data := MidiData.new(120, [
		TrackData.new("Simple", 0, 0, [NoteData.new(60, 0, 480, 100)]),
	])
	var simple_bytes: PackedByteArray = MidiWriter.encode(simple_data)
	var simple_result := MidiReader.from_bytes(simple_bytes)
	if not simple_result.ok:
		print("FAIL: simple parse error")
		quit(1)
		return

	if simple_result.midi_data.cc_events.size() != 0 or simple_result.midi_data.pitch_bend_events.size() != 0:
		print("FAIL: simple MIDI should have 0 CC/PB events")
		quit(1)
		return

	if simple_result.midi_data.tracks[0].notes.size() != 1:
		print("FAIL: simple MIDI note mismatch")
		quit(1)
		return

	print("PASS: backward compatibility (no CC/PB)")

	# 验证 MidiResource 往返
	var res := MidiResource.new()
	res.from_midi_data(result.midi_data)
	var restored: MidiData = res.get_midi_data()
	if restored.cc_events.size() != 4:
		print("FAIL: MidiResource CC round-trip")
		quit(1)
		return

	if restored.pitch_bend_events.size() != 2:
		print("FAIL: MidiResource Pitch Bend round-trip")
		quit(1)
		return

	print("PASS: MidiResource round-trip")

	print("\nPASS: All tests")
	quit(0)
```

### Step 2: 运行测试

Run: `godot --headless --script addons/midi_composer/tests/test_cc_pitchbend_roundtrip.gd`
Expected: `PASS: All tests`，exit code 0

### Step 3: 运行现有回归测试

Run: `godot --headless --script addons/midi_composer/tests/test_midi_reader_quick.gd`
Expected: `PASS: All tests`，exit code 0

### Step 4: Commit

```bash
git add addons/midi_composer/tests/test_cc_pitchbend_roundtrip.gd
git commit -m "test(midi): add CC and Pitch Bend round-trip test"
```

---

## Task 3: 通道状态管理 — ChannelState

**目标:** 封装 per-channel 运行时状态（CC 值、Pitch Bend），供 MidiStreamPlayer 使用。

### Step 1: 创建 ChannelState 类

**Files:**
- Create: `addons/midi_composer/player/channel_state.gd`

```gdscript
## MIDI 通道运行时状态
## 跟踪每个通道的 CC 值、Pitch Bend 等调制参数
class_name ChannelState
extends RefCounted

## CC7: 通道音量 (归一化 0.0-1.0, 默认 100/127)
var volume: float = 100.0 / 127.0
## CC11: 表情 (归一化 0.0-1.0, 默认 1.0)
var expression: float = 1.0
## CC10: 声相 (归一化 0.0-1.0, 0=左, 0.5=中, 1=右)
var pan: float = 0.5
## CC1: 调制深度 (归一化 0.0-1.0, 默认 0)
var modulation: float = 0.0
## Pitch Bend 归一化值 (-1.0 ~ +1.0, 0=居中)
var pitch_bend: float = 0.0
## Pitch Bend Sensitivity (半音, 默认 2)
var pitch_bend_sensitivity: float = 2.0


func reset() -> void:
	volume = 100.0 / 127.0
	expression = 1.0
	pan = 0.5
	modulation = 0.0
	pitch_bend = 0.0
	pitch_bend_sensitivity = 2.0


## 设置 Pitch Bend (原始 14-bit 值: 0-16383, 8192=居中)
func set_pitch_bend_raw(raw: int) -> void:
	pitch_bend = float(raw) / 8192.0 - 1.0


## 获取有效音量 (volume * expression)
func get_effective_volume() -> float:
	return volume * expression
```

### Step 2: Commit

```bash
git add addons/midi_composer/player/channel_state.gd
git commit -m "feat(midi): add ChannelState for per-channel runtime state"
```

---

## Task 4: SynthVoice — Pan / Pitch Bend / Modulation LFO

**目标:** SynthVoice 支持 per-voice 的声相定位、实时弯音和调制颤音。

### Step 1: 添加 Pan 支持

**Files:**
- Modify: `addons/midi_composer/player/synth_voice.gd`

在 `var _mix_rate: int = 44100` 之后（约第 24 行）添加：

```gdscript
## 声相 (0.0=全左, 0.5=居中, 1.0=全右)
var pan: float = 0.5
```

修改 `get_next_frame()` 的返回语句（约第 120 行）：

从：
```gdscript
	return Vector2.ONE * sample_value * env * _velocity_factor
```

改为：
```gdscript
	var level: float = sample_value * env * _velocity_factor
	return Vector2(level * sqrt(1.0 - pan), level * sqrt(pan))
```

### Step 2: 添加 Pitch Bend 支持

**Files:**
- Modify: `addons/midi_composer/player/synth_voice.gd`

在 `pan` 之后添加：

```gdscript
## Pitch Bend 归一化值 (-1.0 ~ +1.0)
var pitch_bend: float = 0.0
## Pitch Bend Sensitivity (半音)
var pitch_bend_sensitivity: float = 2.0
## 调制深度 (归一化 0.0-1.0)
var modulation: float = 0.0
## 调制灵敏度 (半音, 默认 0.5)
var modulation_sensitivity: float = 0.5
## 调制 LFO 相位
var _mod_lfo_phase: float = 0.0
## 调制 LFO 频率 (Hz, 默认 5.0)
var _mod_lfo_freq: float = 5.0
## 标记: pitch bend 或 modulation 是否有非零值
var _pitch_dirty: bool = false
```

添加方法（在 `force_stop()` 之后）：

```gdscript
## 设置 Pitch Bend 并标记 dirty
func set_pitch_bend(bend: float, sensitivity: float) -> void:
	pitch_bend = bend
	pitch_bend_sensitivity = sensitivity
	_pitch_dirty = true


## 设置 Modulation 深度并标记 dirty
func set_modulation(value: float) -> void:
	modulation = value
	_pitch_dirty = true
```

提取步长计算为独立方法：

```gdscript
## 计算当前有效的播放步长 (包含 pitch bend 和 modulation)
func _compute_current_step() -> float:
	if not _pitch_dirty:
		return _playback_step
	var semitones: float = float(key - _root_key) + float(_tuning_cents) / 100.0
	semitones += pitch_bend * pitch_bend_sensitivity
	# 调制 LFO
	var mod_amount: float = sin(_mod_lfo_phase) * modulation * modulation_sensitivity
	semitones += mod_amount
	return float(_mix_rate) * pow(2.0, semitones / 12.0) / float(_sample_rate)
```

### Step 3: 修改 get_next_frame() 使用动态步长

**Files:**
- Modify: `addons/midi_composer/player/synth_voice.gd`

在 `get_next_frame()` 中，将 `_sample_position += _playback_step`（约第 106 行）改为：

```gdscript
	# 更新调制 LFO 相位
	if _pitch_dirty and modulation > 0.0:
		var delta: float = 1.0 / float(_mix_rate)
		_mod_lfo_phase += _mod_lfo_freq * delta * TAU
		if _mod_lfo_phase > TAU:
			_mod_lfo_phase -= TAU

	_sample_position += _compute_current_step()
```

在 `start()` 方法末尾（约第 72 行之后），添加重置：

```gdscript
	pitch_bend = 0.0
	pitch_bend_sensitivity = 2.0
	modulation = 0.0
	_mod_lfo_phase = 0.0
	_pitch_dirty = false
```

### Step 4: Commit

```bash
git add addons/midi_composer/player/synth_voice.gd
git commit -m "feat(midi): add pan, pitch bend and modulation to SynthVoice

- Pan: sqrt constant-power panning on stereo output
- Pitch Bend: real-time playback step modification
- Modulation: 5Hz sine LFO with configurable depth
- Performance: cached step when pitch_dirty is false
"
```

---

## Task 5: MidiStreamPlayer 集成 — ChannelState + CC/Pitch Bend 处理

**目标:** MidiStreamPlayer 初始化通道状态，在 `_build_sorted_events()` 中整合 CC/Pitch Bend，在 `_process_event()` 中处理新事件类型。

### Step 1: 添加 ChannelState 初始化

**Files:**
- Modify: `addons/midi_composer/player/midi_stream_player.gd`

在 `var _channel_instruments: Dictionary = {}`（约第 27 行）之后添加：

```gdscript
var _channel_states: Array[ChannelState] = []
```

在 `_ready()` 中（约第 40 行 `_voice_manager = VoiceManager.new()` 之后）添加：

```gdscript
	for i in range(16):
		_channel_states.append(ChannelState.new())
```

### Step 2: 修改 _build_sorted_events() 整合 CC/Pitch Bend

**Files:**
- Modify: `addons/midi_composer/player/midi_stream_player.gd`

在 `_build_sorted_events()` 中，在 `# Note 事件` 循环之后、排序之前（约第 238 行后），添加：

```gdscript
	# CC 事件
	for cc_event in data.cc_events:
		_sorted_events.append({
			"time_ticks": cc_event["time_ticks"],
			"type": "control_change",
			"channel": cc_event["channel"],
			"controller": cc_event["controller"],
			"value": cc_event["value"],
		})

	# Pitch Bend 事件
	for pb_event in data.pitch_bend_events:
		_sorted_events.append({
			"time_ticks": pb_event["time_ticks"],
			"type": "pitch_bend",
			"channel": pb_event["channel"],
			"value": pb_event["value"],
		})
```

更新 `_event_order()`（约第 179 行），添加新类型：

```gdscript
func _event_order(type: String) -> int:
	match type:
		"tempo_change": return 0
		"program_change": return 1
		"control_change": return 1
		"pitch_bend": return 1
		"note_off": return 2
		"note_on": return 3
		_: return 4
```

### Step 3: 修改 _process_event() 处理 CC 和 Pitch Bend

**Files:**
- Modify: `addons/midi_composer/player/midi_stream_player.gd`

在 `_process_event()` 的 match 块中（约第 291 行），在 `"tempo_change"` 之后添加：

```gdscript
		"control_change":
			_process_cc(event)
		"pitch_bend":
			_process_pitch_bend(event)
```

在 `_process_event()` 方法之后添加两个新方法：

```gdscript
## 处理 CC 事件
func _process_cc(event: Dictionary) -> void:
	var ch: int = event["channel"]
	var controller: int = event["controller"]
	var value: int = event["value"]
	var state: ChannelState = _channel_states[ch]

	match controller:
		7:   # Volume
			state.volume = float(value) / 127.0
		11:  # Expression
			state.expression = float(value) / 127.0
		10:  # Pan
			state.pan = float(value) / 127.0
		1:   # Modulation
			state.modulation = float(value) / 127.0
			for voice in _voice_manager.get_active_voices():
				if voice.channel == ch:
					voice.set_modulation(state.modulation)
		120: # All Sound Off
			_voice_manager.stop_all()
		123: # All Notes Off
			_voice_manager.stop_all()


## 处理 Pitch Bend 事件
func _process_pitch_bend(event: Dictionary) -> void:
	var ch: int = event["channel"]
	var state: ChannelState = _channel_states[ch]
	state.set_pitch_bend_raw(event["value"])
	for voice in _voice_manager.get_active_voices():
		if voice.channel == ch:
			voice.set_pitch_bend(state.pitch_bend, state.pitch_bend_sensitivity)
```

### Step 4: 修改 note_on 处理 — 传递通道状态到新语音

**Files:**
- Modify: `addons/midi_composer/player/midi_stream_player.gd`

在 `_process_event()` 的 `"note_on"` 分支中，`note_triggered.emit()` 之前添加：

```gdscript
			# 将当前通道状态应用到新语音
			var ch_state: ChannelState = _channel_states[channel]
			var voices := _voice_manager.get_active_voices()
			for v in voices:
				if v.channel == channel and v.key == key and v.state == SynthVoice.State.ATTACK:
					v.set_pitch_bend(ch_state.pitch_bend, ch_state.pitch_bend_sensitivity)
					v.set_modulation(ch_state.modulation)
					v.pan = ch_state.pan
					break
```

### Step 5: 修改 stop() 和 seek() 重置通道状态

**Files:**
- Modify: `addons/midi_composer/player/midi_stream_player.gd`

在 `stop()` 中（约第 104 行），`_event_index = 0` 之后添加：

```gdscript
	for state in _channel_states:
		state.reset()
```

### Step 6: 修改 _preprocess_events_up_to() 处理 CC/Pitch Bend

**Files:**
- Modify: `addons/midi_composer/player/midi_stream_player.gd`

在 `_preprocess_events_up_to()` 中，将现有的 else 分支改为显式处理 CC 和 Pitch Bend：

```gdscript
func _preprocess_events_up_to(target_tick: int) -> void:
	_event_index = 0
	while _event_index < _sorted_events.size():
		var event: Dictionary = _sorted_events[_event_index]
		if event["time_ticks"] >= target_tick:
			break
		var event_type: String = event.get("type", "")
		if event_type == "tempo_change":
			_ticks_per_second = event["bpm"] / 60.0 * float(_timebase)
		elif event_type == "program_change":
			_channel_instruments[event["channel"]] = event["preset_index"]
		elif event_type == "control_change":
			_process_cc(event)
		elif event_type == "pitch_bend":
			_process_pitch_bend(event)
		_event_index += 1
```

### Step 7: 修改 _fill_generator_buffer() 使用 per-voice 增益

**Files:**
- Modify: `addons/midi_composer/player/midi_stream_player.gd`

修改 `_fill_generator_buffer()`（约第 347-360 行）：

```gdscript
func _fill_generator_buffer() -> void:
	var available: int = _playback.get_frames_available()
	var to_fill: int = mini(available, 8192)
	var active_voices: Array[SynthVoice] = _voice_manager.get_active_voices()
	var voice_count: int = active_voices.size()
	if voice_count == 0:
		return

	# 多语音时降低增益防止削波
	var poly_gain: float = 1.0 / sqrt(float(voice_count))

	for i in range(to_fill):
		var frame: Vector2 = Vector2.ZERO
		for voice in active_voices:
			var ch_vol: float = 1.0
			if voice.channel >= 0 and voice.channel < _channel_states.size():
				ch_vol = _channel_states[voice.channel].get_effective_volume()
			frame += voice.get_next_frame() * ch_vol
		_playback.push_frame(frame * poly_gain)
```

同步修改 `_prefill_buffer()` 中的增益计算逻辑（约第 327-343 行），同样使用 per-voice `ch_vol`。

### Step 8: Commit

```bash
git add addons/midi_composer/player/midi_stream_player.gd
git commit -m "feat(midi): integrate ChannelState, CC and Pitch Bend into player

- Init 16 ChannelState instances in _ready()
- Build sorted events include CC and Pitch Bend
- Process CC events (volume, expression, pan, modulation)
- Process Pitch Bend events with per-voice update
- Pass channel state to new voices on note_on
- Per-voice volume gain based on channel CC7*CC11
- Reset channel state on stop/seek
"
```

---

## Task 6: 端到端验证

**目标:** 在 Godot 编辑器中播放包含 CC/Pitch Bend 的 MIDI 文件，听音验证。

### Step 1: 重新导入测试 MIDI 文件

Run: 在 Godot 编辑器中右键 `.mid` 文件 → Reimport

### Step 2: 回归测试 — 纯音符 MIDI

Run: 在 Godot 编辑器中运行 `midi_stream_player.tscn` 场景
Expected: 播放正常，无回归

### Step 3: 功能测试 — CC 渐强/声相

使用包含 CC7 渐强和 CC10 声相扫描的 MIDI 文件测试
Expected: 能听到音量变化和声相移动

### Step 4: 功能测试 — Pitch Bend

使用包含 Pitch Bend 的 MIDI 文件测试
Expected: 能听到音高平滑偏移

### Step 5: 功能测试 — Modulation (CC1)

使用包含 CC1 颤音的 MIDI 文件测试
Expected: 能听到颤音效果

### Step 6: 回归测试 — 循环播放

Run: 开启 loop 播放，观察循环重启时是否正常
Expected: 通道状态正确重置，无残留声音

---

## 风险与缓解

| 风险 | 严重性 | 缓解措施 |
|------|--------|----------|
| `pow(2.0, x/12.0)` 每帧性能 | 中 | `_pitch_dirty=false` 时使用缓存 `_playback_step` |
| Pitch Bend click/pop | 低 | 游戏场景可接受 |
| .tres 向后兼容 | 中 | 新字段默认空数组，旧文件无缝加载 |
| CC 事件密集时遍历 voice 开销 | 低 | CC 事件通常稀疏（游戏 BGM 典型几十个/分钟） |
| Modulation LFO 固定 5Hz | 低 | 游戏场景足够，后续可从 SF2 GEN 读取 |
