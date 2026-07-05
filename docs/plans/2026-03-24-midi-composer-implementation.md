# MIDI Composer 实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 创建一个 Godot 编辑器插件，通过固定格式的 JSON 文件生成标准 MIDI (.mid) 文件。

**Architecture:** 纯 GDScript 实现，不依赖现有 SMF.gd。converter.gd 负责 JSON 解析和校验，midi_writer.gd 独立实现 SMF Type 1 二进制编码，plugin.gd 注册右键菜单。数据通过 midi_types.gd 中的简单类传递。

**Tech Stack:** Godot 4.6 / GDScript 2.0

**设计文档:** `docs/plans/2026-03-24-midi-composer-design.md`

---

### Task 1: 创建插件骨架 + 数据类型

**Files:**
- Create: `addons/midi_composer/plugin.cfg`
- Create: `addons/midi_composer/midi_types.gd`

**Step 1: 创建目录结构**

```bash
mkdir -p addons/midi_composer/templates
```

**Step 2: 创建 plugin.cfg**

```ini
[plugin]
name="MIDI Composer"
description="Convert JSON files to standard MIDI (.mid) files via right-click context menu."
author=""
version="1.0.0"
script="plugin.gd"
```

**Step 3: 创建 midi_types.gd**

```gdscript
## MIDI Composer 内部数据类型
## 独立于 SMF.gd，为后续独立发布做准备。

## 音符数据
class NoteData:
	var pitch: int = 60
	var start_ticks: int = 0
	var duration_ticks: int = 480
	var velocity: int = 100

	func _init(p_pitch: int = 60, p_start_ticks: int = 0, p_duration_ticks: int = 480, p_velocity: int = 100) -> void:
		pitch = p_pitch
		start_ticks = p_start_ticks
		duration_ticks = p_duration_ticks
		velocity = p_velocity

## 音轨数据
class TrackData:
	var name: String = ""
	var channel: int = 0
	var instrument: int = 0
	var notes: Array[NoteData] = []

	func _init(p_name: String = "", p_channel: int = 0, p_instrument: int = 0, p_notes: Array[NoteData] = []) -> void:
		name = p_name
		channel = p_channel
		instrument = p_instrument
		notes = p_notes

## MIDI 文件数据
class MidiData:
	var tempo: int = 120
	var timebase: int = 480
	var tracks: Array[TrackData] = []

	func _init(p_tempo: int = 120, p_tracks: Array[TrackData] = []) -> void:
		tempo = p_tempo
		tracks = p_tracks
```

**Step 4: 创建空 plugin.gd（占位）**

```gdscript
@tool
extends EditorPlugin

func _enter_tree() -> void:
	pass

func _exit_tree() -> void:
	pass
```

**Step 5: 验证插件可被 Godot 识别**

Run: 在 Godot 编辑器中确认 Project > Project Settings > Plugins 列表中出现 "MIDI Composer"

**Step 6: Commit**

```
git add addons/midi_composer/
git commit -m "feat(midi-composer): scaffold plugin with data types"
```

---

### Task 2: 创建 JSON 格式模板

**Files:**
- Create: `addons/midi_composer/templates/default.json`

**Step 1: 创建 default.json**

```json
{
  "format_version": "1.0",
  "tempo": 120,
  "tracks": [
    {
      "name": "Track Name",
      "channel": 0,
      "instrument": 0,
      "notes": [
        {
          "pitch": 60,
          "start": 0.0,
          "duration": 1.0,
          "velocity": 100
        }
      ]
    }
  ]
}
```

**Step 2: Commit**

```
git add addons/midi_composer/templates/default.json
git commit -m "feat(midi-composer): add JSON format template"
```

---

### Task 3: 实现 MIDI 二进制编码器 (midi_writer.gd)

**Files:**
- Create: `addons/midi_composer/midi_writer.gd`

**Step 1: 实现 midi_writer.gd**

```gdscript
## MIDI Composer - SMF Type 1 二进制编码器
## 独立实现，不依赖 addons/midi/SMF.gd

class_name MidiWriter

const TICKS_PER_QUARTER: int = 480


static func write(midi_data: MidiData) -> PackedByteArray:
	var stream: StreamPeerBuffer = StreamPeerBuffer.new()
	stream.big_endian = true

	# MThd header: format=1, tracks=N+1 (含 tempo 轨), timebase=480
	stream.put_data("MThd".to_ascii_buffer())
	stream.put_u32(6)
	stream.put_u16(1)  # Format Type 1
	stream.put_u16(midi_data.tracks.size() + 1)
	stream.put_u16(TICKS_PER_QUARTER)

	# Track 0: Tempo meta track
	stream.put_data(_write_tempo_track(midi_data))

	# Track 1..N: Note tracks
	for track in midi_data.tracks:
		stream.put_data(_write_track(track))

	return stream.data_array


static func _write_tempo_track(midi_data: MidiData) -> PackedByteArray:
	var buf: StreamPeerBuffer = StreamPeerBuffer.new()
	buf.big_endian = true

	# Time signature: 4/4, 24 MIDI clocks per metronome tick, 8 notated 32nd notes per quarter
	_write_meta_event(buf, 0, 0xFF, 0x58, PackedByteArray([4, 2, 24, 8]))

	# Tempo: microseconds per quarter note = 60,000,000 / BPM
	var us_per_beat: int = int(60000000.0 / midi_data.tempo)
	var tempo_bytes: PackedByteArray = PackedByteArray([
		(us_per_beat >> 16) & 0xFF,
		(us_per_beat >> 8) & 0xFF,
		us_per_beat & 0xFF,
	])
	_write_meta_event(buf, 0, 0xFF, 0x51, tempo_bytes)

	# End of track
	_write_meta_event(buf, 0, 0xFF, 0x2F, PackedByteArray())

	return _wrap_mtrk(buf)


static func _write_track(track: TrackData) -> PackedByteArray:
	var buf: StreamPeerBuffer = StreamPeerBuffer.new()
	buf.big_endian = true

	# Track name
	if track.name != "":
		_write_meta_event(buf, 0, 0xFF, 0x03, track.name.to_ascii_buffer())

	# Program Change
	buf.put_u8(0x00)  # delta time = 0
	buf.put_u8(0xC0 | (track.channel & 0x0F))
	buf.put_u8(track.instrument & 0x7F)

	# 收集所有事件并按时间排序
	var events: Array[Dictionary] = []
	for note in track.notes:
		events.append({"time": note.start_ticks, "type": "on", "note": note})
		events.append({"time": note.start_ticks + note.duration_ticks, "type": "off", "note": note})

	events.sort_custom(func(a, b): return a["time"] < b["time"])

	var last_time: int = 0
	for event in events:
		var delta: int = event["time"] - last_time
		last_time = event["time"]
		var status_byte: int

		if event["type"] == "on":
			status_byte = 0x90 | (track.channel & 0x0F)
			_write_variable_int(buf, delta)
			buf.put_u8(status_byte)
			buf.put_u8(event["note"].pitch & 0x7F)
			buf.put_u8(event["note"].velocity & 0x7F)
		else:
			status_byte = 0x80 | (track.channel & 0x0F)
			_write_variable_int(buf, delta)
			buf.put_u8(status_byte)
			buf.put_u8(event["note"].pitch & 0x7F)
			buf.put_u8(0)

	# End of track
	var final_delta: int = 0
	if events.size() > 0:
		final_delta = 0
	_write_meta_event(buf, final_delta, 0xFF, 0x2F, PackedByteArray())

	return _wrap_mtrk(buf)


static func _write_meta_event(buf: StreamPeerBuffer, delta_time: int, status: int, meta_type: int, data: PackedByteArray) -> void:
	_write_variable_int(buf, delta_time)
	buf.put_u8(status)
	buf.put_u8(meta_type)
	_write_variable_int(buf, data.size())
	if data.size() > 0:
		buf.put_data(data)


static func _write_variable_int(buf: StreamPeerBuffer, value: int) -> void:
	if value < 0:
		value = 0
	var bytes: Array[int] = []
	bytes.append(value & 0x7F)
	value >>= 7
	while value > 0:
		bytes.append((value & 0x7F) | 0x80)
		value >>= 7
	bytes.reverse()
	for b in bytes:
		buf.put_u8(b)


static func _wrap_mtrk(buf: StreamPeerBuffer) -> PackedByteArray:
	var wrapper: StreamPeerBuffer = StreamPeerBuffer.new()
	wrapper.big_endian = true
	wrapper.put_data("MTrk".to_ascii_buffer())
	wrapper.put_u32(buf.get_size())
	wrapper.put_data(buf.data_array)
	return wrapper.data_array
```

**关键实现说明：**
- `write()` 是静态方法入口，无需实例化
- `_write_variable_int()` 实现标准 MIDI 可变长度编码（参考 SMF.gd:671-683 的逻辑，但用自己的实现）
- `_write_track()` 先收集所有 Note On/Off 事件，按时间排序后写入，确保事件顺序正确
- tempo 轨只含时间签名 + 速度标记，不关联任何通道
- `_wrap_mtrk()` 统一处理 "MTrk" + size + data 的封装

**Step 2: 使用 /gdscript-validate 验证语法**

**Step 3: Commit**

```
git add addons/midi_composer/midi_writer.gd
git commit -m "feat(midi-composer): implement SMF Type 1 binary encoder"
```

---

### Task 4: 实现 JSON 转换器 (converter.gd)

**Files:**
- Create: `addons/midi_composer/converter.gd`

**Step 1: 实现 converter.gd**

```gdscript
## MIDI Composer - JSON → MidiData 转换器
## 负责解析 JSON、格式校验、秒→ticks 转换

class_name MidiComposerConverter

const TICKS_PER_QUARTER: int = 480
const SUPPORTED_VERSION: String = "1.0"

## 转换结果
class ConvertResult:
	var ok: bool = false
	var midi_data: MidiData = null
	var error_message: String = ""

	func _init(p_ok: bool = false, p_midi_data: MidiData = null, p_error: String = "") -> void:
		ok = p_ok
		midi_data = p_midi_data
		error_message = p_error


## 从 JSON 字符串转换为 MidiData
static func from_json_string(json_text: String) -> ConvertResult:
	var parse_result: JSONParseResult = JSON.parse_string(json_text)
	if parse_result == null or parse_result.error != OK:
		return ConvertResult.new(false, null, "JSON 解析失败: %s" % json_text)

	var data: Dictionary = parse_result.data if parse_result.data is Dictionary else {}
	return _convert(data)


## 从 Dictionary 转换为 MidiData
static func _convert(data: Dictionary) -> ConvertResult:
	# 校验 format_version（可选，默认 "1.0"）
	var version: String = data.get("format_version", "1.0") as String
	if version != SUPPORTED_VERSION:
		return ConvertResult.new(false, null, "不支持的格式版本: %s（当前支持: %s）" % [version, SUPPORTED_VERSION])

	# 校验 tempo
	if not data.has("tempo"):
		return ConvertResult.new(false, null, "缺少必要字段: tempo")
	var tempo: int = int(data["tempo"])
	if tempo <= 0:
		return ConvertResult.new(false, null, "tempo 必须大于 0，当前值: %d" % tempo)

	# 校验 tracks
	if not data.has("tracks") or not data["tracks"] is Array:
		return ConvertResult.new(false, null, "缺少必要字段: tracks（必须为数组）")
	var tracks_array: Array = data["tracks"]
	if tracks_array.is_empty():
		return ConvertResult.new(false, null, "tracks 不能为空")

	# 转换音轨
	var tracks: Array[TrackData] = []
	for i in tracks_array.size():
		var track_dict: Dictionary = tracks_array[i] if tracks_array[i] is Dictionary else {}
		var result: TrackData = _convert_track(track_dict, i)
		if result == null:
			return ConvertResult.new(false, null, "音轨[%d] 格式错误" % i)
		tracks.append(result)

	var midi_data: MidiData = MidiData.new(tempo, tracks)
	return ConvertResult.new(true, midi_data, "")


## 转换单个音轨
static func _convert_track(track_dict: Dictionary, track_index: int) -> TrackData:
	# 校验必须字段
	for field in ["channel", "instrument", "notes"]:
		if not track_dict.has(field):
			push_error("音轨[%d] 缺少字段: %s" % [track_index, field])
			return null

	var channel: int = int(track_dict["channel"])
	if channel < 0 or channel > 15:
		push_error("音轨[%d] channel 超出范围 (0-15): %d" % [track_index, channel])
		return null

	var instrument: int = int(track_dict["instrument"])
	if instrument < 0 or instrument > 127:
		push_error("音轨[%d] instrument 超出范围 (0-127): %d" % [track_index, instrument])
		return null

	if not track_dict["notes"] is Array:
		push_error("音轨[%d] notes 必须为数组" % track_index)
		return null

	var name: String = track_dict.get("name", "") as String
	var notes: Array[NoteData] = []

	for j in track_dict["notes"].size():
		var note_dict: Dictionary = track_dict["notes"][j] if track_dict["notes"][j] is Dictionary else {}
		var note: NoteData = _convert_note(note_dict, track_index, j)
		if note == null:
			return null
		notes.append(note)

	return TrackData.new(name, channel, instrument, notes)


## 转换单个音符（秒 → ticks）
static func _convert_note(note_dict: Dictionary, track_index: int, note_index: int) -> NoteData:
	for field in ["pitch", "start", "duration", "velocity"]:
		if not note_dict.has(field):
			push_error("音轨[%d] 音符[%d] 缺少字段: %s" % [track_index, note_index, field])
			return null

	var pitch: int = int(note_dict["pitch"])
	if pitch < 0 or pitch > 127:
		push_error("音轨[%d] 音符[%d] pitch 超出范围 (0-127): %d" % [track_index, note_index, pitch])
		return null

	var start_sec: float = float(note_dict["start"])
	var duration_sec: float = float(note_dict["duration"])
	var velocity: int = int(note_dict["velocity"])

	if velocity < 0 or velocity > 127:
		push_error("音轨[%d] 音符[%d] velocity 超出范围 (0-127): %d" % [track_index, note_index, velocity])
		return null

	if duration_sec <= 0:
		push_error("音轨[%d] 音符[%d] duration 必须大于 0" % [track_index, note_index])
		return null

	# 秒 → ticks 转换将在 writer 中完成，这里保留原始秒值
	# 实际上 converter 直接做转换，让 writer 只处理 ticks
	var start_ticks: int = int(start_sec * TICKS_PER_QUARTER * 2)
	var duration_ticks: int = int(duration_sec * TICKS_PER_QUARTER * 2)

	return NoteData.new(pitch, start_ticks, duration_ticks, velocity)
```

**关于秒→ticks 转换的说明：**
- 这里使用 `seconds × TICKS_PER_QUARTER × 2` 作为近似转换
- 精确转换需要 tempo，但 converter 不知道 tempo（tempo 在 writer 层）
- 解决方案：converter 输出 MidiData 时，converter 已经有 tempo，所以应该传入
- 修正：在 `_convert()` 中创建 `MidiData` 之前，对每个 track 的 notes 做秒→ticks 转换，使用 `seconds × (tempo / 60.0) × TICKS_PER_QUARTER`

**实际实现中需要修正 `_convert_note` 的签名，增加 tempo 参数：**
```gdscript
static func _convert_note(note_dict: Dictionary, track_index: int, note_index: int, tempo: int) -> NoteData:
    # ...
    var ticks_per_second: float = tempo / 60.0 * TICKS_PER_QUARTER
    var start_ticks: int = int(start_sec * ticks_per_second)
    var duration_ticks: int = int(duration_sec * ticks_per_second)
```

并在 `_convert_track` 中传递 tempo。

**Step 2: 使用 /gdscript-validate 验证语法**

**Step 3: Commit**

```
git add addons/midi_composer/converter.gd
git commit -m "feat(midi-composer): implement JSON to MidiData converter with validation"
```

---

### Task 5: 实现编辑器插件 (plugin.gd)

**Files:**
- Modify: `addons/midi_composer/plugin.gd`

**Step 1: 实现 plugin.gd**

```gdscript
@tool
extends EditorPlugin

const MidiComposerConverter = preload("converter.gd")
const MidiWriter = preload("midi_writer.gd")

## 右键菜单弹出项
var _popup: PopupMenu = null


func _enter_tree() -> void:
	_popup = PopupMenu.new()
	_popup.name = "MidiComposerPopup"
	_popup.id_pressed.connect(_on_popup_id_pressed)
	add_child(_popup)

	# 注册文件系统右键菜单
	add_tool_menu_item("Compose MIDI from JSON...", _on_tool_menu)


func _exit_tree() -> void:
	remove_tool_menu_item("Compose MIDI from JSON...")
	if is_instance_valid(_popup):
		_popup.queue_free()


func _on_tool_menu() -> void:
	# 获取当前选中的文件
	var selected := get_selected_paths()
	if selected.size() != 1:
		_show_error("请选择一个 .json 文件")
		return

	var path: String = selected[0]
	if not path.to_lower().ends_with(".json"):
		_show_error("请选择 .json 文件\n当前选择: %s" % path.get_file())
		return

	_convert_file(path)


func _convert_file(json_path: String) -> void:
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		_show_error("无法读取文件: %s\n错误: %d" % [json_path, FileAccess.get_open_error()])
		return

	var json_text: String = file.get_as_text()
	file.close()

	var result: MidiComposerConverter.ConvertResult = MidiComposerConverter.from_json_string(json_text)
	if not result.ok:
		_show_error("转换失败:\n%s" % result.error_message)
		return

	var midi_bytes: PackedByteArray = MidiWriter.write(result.midi_data)
	if midi_bytes.is_empty():
		_show_error("MIDI 编码失败")
		return

	var mid_path: String = json_path.get_basename() + ".mid"
	var out := FileAccess.open(mid_path, FileAccess.WRITE)
	if out == null:
		_show_error("无法写入文件: %s" % mid_path)
		return

	out.store_buffer(midi_bytes)
	out.close()

	# 通知文件系统刷新
	EditorInterface.get_resource_filesystem().scan()

	_show_success("已生成: %s" % mid_path.get_file())


func _show_error(message: String) -> void:
	# 弹窗提示
	var dialog := AcceptDialog.new()
	dialog.dialog_text = message
	dialog.title = "MIDI Composer 错误"
	dialog.transient = true
	dialog.exclusive = true

	# 添加到编辑器树并显示
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(400, 150))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)


func _show_success(message: String) -> void:
	EditorInterface.get_base_control().call_deferred("_print_message", "[MIDI Composer] " + message)
```

**Step 2: 使用 /gdscript-validate 验证语法**

**Step 3: Commit**

```
git add addons/midi_composer/plugin.gd
git commit -m "feat(midi-composer): implement editor plugin with tool menu"
```

---

### Task 6: 集成测试 — 用模板 JSON 生成 MIDI 并验证

**Files:**
- 使用: `addons/midi_composer/templates/default.json`

**Step 1: 在 Godot 编辑器中启用插件**

Project > Project Settings > Plugins > MIDI Composer > Enable

**Step 2: 用示例 JSON 测试**

使用之前用户提供的完整示例 JSON（含 4 个音轨），保存为测试文件，通过 Tools > Compose MIDI from JSON 转换。

**Step 3: 验证生成的 .mid 文件**

- 用现有 MIDI Player 插件 (`addons/midi/`) 加载生成的 .mid 文件，确认可以正常播放
- 或用外部 MIDI 验证工具（如 [Violet](https://www.piano-midi.de/violet)）检查文件结构

**Step 4: 验证要点**

- [ ] .mid 文件大小合理（非 0 字节）
- [ ] MIDI Player 可正常加载并播放
- [ ] 4 个音轨全部存在
- [ ] 速度正确（140 BPM）
- [ ] 鼓组轨道（channel 9）正常
- [ ] 各轨道乐器正确

**Step 5: Commit**

```
git add addons/midi_composer/
git commit -m "feat(midi-composer): complete plugin with editor integration"
```

---

### Task 7: 创建测试用完整 JSON 示例

**Files:**
- Create: `addons/midi_composer/templates/example_full.json`

**Step 1: 创建完整示例文件**

使用用户之前提供的 4 轨道示例（Melody、Bass、Pad、Drums），作为模板目录下的完整示例。

**Step 2: Commit**

```
git add addons/midi_composer/templates/example_full.json
git commit -m "feat(midi-composer): add full 4-track example JSON"
```

---

## 实现顺序总结

| Task | 内容 | 依赖 |
|------|------|------|
| 1 | 插件骨架 + midi_types.gd | 无 |
| 2 | JSON 格式模板 | 无 |
| 3 | MIDI 二进制编码器 | Task 1 (midi_types) |
| 4 | JSON 转换器 | Task 1 (midi_types) |
| 5 | 编辑器插件 | Task 3, Task 4 |
| 6 | 集成测试 | Task 5 |
| 7 | 完整示例 | Task 6 |

Task 2 和 Task 3/4 可以并行，Task 3 和 Task 4 也可以并行（它们只依赖 Task 1）。
