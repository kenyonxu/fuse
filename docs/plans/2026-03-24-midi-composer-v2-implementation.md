# MIDI Composer v2 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add MidiResource, .mid import, SF2 synthesizer, and MidiStreamPlayer to the MIDI Composer plugin.

**Architecture:** Three layers: data types (Resource + Reader), synthesis engine (SF2 → PCM), and editor integration (ImportPlugin + InspectorPlugin). The player inherits AudioStreamPlayer for native Godot audio integration.

**Tech Stack:** GDScript 2.0, Godot 4.6 EditorPlugin API, AudioStreamGenerator, StreamPeerBuffer

**Design doc:** `docs/plans/2026-03-24-midi-composer-v2-design.md` — full specifications for all modules.

**Godot path:** `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe`

---

### Task 1: NoteResource + TrackResource

**Files:**
- Create: `addons/midi_composer/midi_resources/note_resource.gd`
- Create: `addons/midi_composer/midi_resources/track_resource.gd`

**Step 1: Create NoteResource**

```gdscript
## 音符资源（Inspector 可编辑）

class_name NoteResource
extends Resource

@export var pitch: int = 60
@export var start_ticks: int = 0
@export var duration_ticks: int = 480
@export var velocity: int = 100
```

**Step 2: Create TrackResource**

```gdscript
## 音轨资源（Inspector 可编辑）

class_name TrackResource
extends Resource

@export var name: String = ""
@export var channel: int = 0
@export var instrument: int = 0
@export var notes: Array[NoteResource] = []
```

**Step 3: Validate with gdscript-validate**

Run: `bash ~/.claude/skills/gdscript-validate/scripts/refresh_godot_lsp.sh`

**Step 4: Commit**

```
feat: add NoteResource and TrackResource types
```

---

### Task 2: MidiResource

**Files:**
- Create: `addons/midi_composer/midi_resource.gd`

**Step 1: Create MidiResource with MidiData conversion**

```gdscript
## MIDI 资源类型，Godot 原生 Resource
## 可在 Inspector 中查看/编辑，保存为 .tres

class_name MidiResource
extends Resource

@export var tempo: int = 120
@export var timebase: int = 480
@export var tracks: Array[TrackResource] = []

func from_midi_data(data: MidiData) -> void:
	tempo = data.tempo
	timebase = data.timebase
	tracks.clear()
	for track_data in data.tracks:
		var track_res := TrackResource.new()
		track_res.name = track_data.name
		track_res.channel = track_data.channel
		track_res.instrument = track_data.instrument
		for note_data in track_data.notes:
			var note_res := NoteResource.new()
			note_res.pitch = note_data.pitch
			note_res.start_ticks = note_data.start_ticks
			note_res.duration_ticks = note_data.duration_ticks
			note_res.velocity = note_data.velocity
			track_res.notes.append(note_res)
		tracks.append(track_res)

func get_midi_data() -> MidiData:
	var track_list: Array[TrackData] = []
	for track_res in tracks:
		var note_list: Array[NoteData] = []
		for note_res in track_res.notes:
			note_list.append(NoteData.new(
				note_res.pitch, note_res.start_ticks,
				note_res.duration_ticks, note_res.velocity
			))
		track_list.append(TrackData.new(
			track_res.name, track_res.channel,
			track_res.instrument, note_list
		))
	return MidiData.new(tempo, track_list)

func get_duration_seconds() -> float:
	if tracks.is_empty():
		return 0.0
	var max_end_ticks: int = 0
	var ticks_per_second: float = float(tempo) / 60.0 * float(timebase)
	for track in tracks:
		for note in track.notes:
			var end_ticks: int = note.start_ticks + note.duration_ticks
			if end_ticks > max_end_ticks:
				max_end_ticks = end_ticks
	return float(max_end_ticks) / ticks_per_second

func get_track_count() -> int:
	return tracks.size()

func from_json_string(json: String) -> bool:
	var result := MidiComposerConverter.from_json_string(json)
	if not result.ok:
		return false
	from_midi_data(result.midi_data)
	return true
```

**Step 2: Validate + Commit**

```
feat: add MidiResource with MidiData conversion
```

---

### Task 3: MidiReader (.mid → MidiData)

**Files:**
- Create: `addons/midi_composer/midi_reader.gd`
- Modify: `addons/midi_composer/tests/test_midi_composer.gd` (add reader tests)

**Step 1: Create MidiReader**

This is the most complex P0 file. It must handle:
- MThd/MTrk chunk parsing
- VLQ delta time decoding
- Running Status (consecutive same-type events omit status byte)
- Note On/Off pairing
- Program Change, Control Change (skip), Meta events (tempo, track name, end of track)
- Unknown event skipping
- Format 0 → split by channel into multiple TrackData

Key reference: `addons/midi/SMF.gd` `_read()` method (lines 382-604) for the overall parsing structure and `_read_variable_int()` for VLQ.

The implementation should have these static methods:
- `from_bytes(data: PackedByteArray) -> ReadResult` — parse from byte array
- `from_file(path: String) -> ReadResult` — read file then parse

Inner class `ReadResult` with `ok: bool`, `midi_data: MidiData`, `error_message: String`.

Internal helpers needed:
- `_read_chunk_header(stream)` — read 4-byte ID + 4-byte size
- `_read_variable_length(stream)` — VLQ decode
- `_parse_track_events(stream, track_size_bytes)` — parse events from a track
- `_pair_note_on_off(events)` — convert Note On/Off events into NoteData

**Important:** The `_parse_track_events` should return an array of parsed events (dictionaries with `time_ticks`, `type`, `channel`, `pitch`, `velocity`, `program`, `meta_type`, etc.) and then `_pair_note_on_off` converts them into `NoteData`.

For Note On with velocity 0, treat as Note Off (MIDI standard).

**Step 2: Add round-trip test to test_midi_composer.gd**

Add a test that:
1. Creates MidiData with known notes
2. Encodes to bytes via `MidiWriter.encode()`
3. Parses back via `MidiReader.from_bytes()`
4. Verifies tempo, track count, note data match

**Step 3: Validate + Commit**

```
feat: add MidiReader for .mid file parsing
```

---

### Task 4: MidiImportPlugin

**Files:**
- Create: `addons/midi_composer/midi_import_plugin.gd`
- Modify: `addons/midi_composer/plugin.gd` (register import plugin)

**Step 1: Create ImportPlugin**

```gdscript
@tool
extends EditorImportPlugin

func _get_importer_name() -> String:
	return "midi_composer"

func _get_visible_name() -> String:
	return "MIDI Resource"

func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["mid"])

func _get_resource_type() -> String:
	return "MidiResource"

func _get_save_extension() -> String:
	return "tres"

func _get_preset_count() -> int:
	return 0

func _get_import_order() -> int:
	return 0

func _get_priority() -> float:
	return 1.0

func _get_import_options(_path: String, _preset_index: int) -> Array[Dictionary]:
	return []

func _import(source_file: String, save_path: String, _options: Dictionary, _r_platform_variants: Array, _r_gen_files: Array) -> Error:
	var file := FileAccess.open(source_file, FileAccess.READ)
	if file == null:
		push_error("MidiImportPlugin: 无法读取文件 " + source_file)
		return ERR_CANT_OPEN
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	var result := MidiReader.from_bytes(bytes)
	if not result.ok:
		push_error("MidiImportPlugin: 解析失败 " + source_file + ": " + result.error_message)
		return ERR_PARSE_ERROR
	var resource := MidiResource.new()
	resource.from_midi_data(result.midi_data)
	return ResourceSaver.save(resource, save_path + ".tres")
```

**Step 2: Update plugin.gd to register the import plugin**

Add to `_enter_tree()`:
```gdscript
_import_plugin = MidiImportPlugin.new()
add_import_plugin(_import_plugin)
```

Add to `_exit_tree()`:
```gdscript
remove_import_plugin(_import_plugin)
_import_plugin = null
```

Add `var _import_plugin: MidiImportPlugin` as class member.

**Step 3: Manual test** — place a `.mid` file in the project, verify it imports as `MidiResource` in the FileSystem dock.

**Step 4: Validate + Commit**

```
feat: add .mid file import via EditorImportPlugin
```

---

### Task 5: SF2 Data Structures

**Files:**
- Create: `addons/midi_composer/player/sf2_data.gd`

**Step 1: Create all SF2 data types**

Create the file with these inner classes (each `class_name` in a separate section, one file):
- `Sf2Data` — top-level container
- `Sf2Preset` — preset with zones
- `Sf2PresetZone` — key/vel range + instrument link
- `Sf2Instrument` — instrument with zones
- `Sf2InstrumentZone` — key/vel range + sample link + ADSR
- `Sf2SampleHeader` — sample metadata

Since Godot allows one `class_name` per file, put all inner classes WITHOUT `class_name` and only give `class_name Sf2Data` to the file's main class. The other types are used only internally by the SF2 module.

**Step 2: Validate + Commit**

```
feat: add SF2 data structure definitions
```

---

### Task 6: Sf2Reader

**Files:**
- Create: `addons/midi_composer/player/sf2_reader.gd`

**Step 1: Create SF2 parser**

This parser reads a `.sf2` file's binary structure. Key reference: `addons/midi/SoundFont.gd` for the overall parsing approach.

Structure of an SF2 file:
```
RIFF....sfbk
  INFO....          (chunk: version, name, etc.)
  sdta....          (chunk: raw PCM sample data)
    smpl....        (sub-chunk: 16-bit signed PCM)
  pdta....          (chunk: preset/instrument/sample headers)
    PHDR....        (preset headers)
    PBAG....        (preset bags)
    PMOD....        (preset modulators — skip)
    PGEN....        (preset generators)
    INST....        (instrument headers)
    IBAG....        (instrument bags)
    IMOD....        (instrument modulators — skip)
    IGEN....        (instrument generators)
    SHDR....        (sample headers)
```

Parsing steps:
1. Verify RIFF/sfbk header
2. Find and parse INFO chunk (version, name)
3. Find sdta/smpl chunk, store raw PCM bytes
4. Find pdta chunk, parse each sub-chunk
5. For each sub-chunk: read records of known size (PHDR=38, PBAG=4, PGEN=4, INST=22, IBAG=4, IGEN=4, SHDR=46)

Generator (GEN) record format: `generator_type (2 bytes) + value (2 bytes)`
Key generator types:
- `0x00` = Start Address (sample link via index)
- `0x01` = End Address
- `0x02` = Start Loop Address
- `0x03` = End Loop Address
- `0x05` = Sample Rate
- `0x08` = Original Pitch (root key)
- `0x09` = Pitch Correction (tuning cents)
- `0x0A` = Sample Link (stereo)
- `0x0C` = Sample Type
- `0x15` = Key Range (low:15-8, high:7-0)
- `0x16` = Vel Range
- `0x2A` = Attack (timecent, convert to seconds)
- `0x2B` = Hold
- `0x2C` = Decay
- `0x2E` = Sustain (centibel, convert: sustain = (1200 - value) / 1000.0)
- `0x2F` = Release
- `0x43` = Instrument (link to instrument index)

Timecent to seconds: `time = 2^(timecent / 1200.0)` (but 0x7FFF = -1 means "take no action", and -1200 = 0 seconds)

**Step 2: Validate + Commit**

```
feat: add Sf2Reader for SoundFont file parsing
```

---

### Task 7: Sf2Bank

**Files:**
- Create: `addons/midi_composer/player/sf2_bank.gd`

**Step 1: Create Sf2Bank with Global Zone and velocity layer support**

`load_from_data(sf2_data)` — stores the parsed data.

`get_sample(preset_index, key, velocity) -> Sf2SampleInfo` — lookup logic:
1. Find preset by index
2. Extract global zone defaults + find matching local zone (key/vel range)
3. Follow instrument link
4. Extract global zone defaults + find matching local zone
5. Follow sample link → get SHDR
6. Combine ADSR (instrument overrides preset, use defaults for -1)
7. Build Sf2SampleInfo with PCM slice from sdta data

Inner class `Sf2SampleInfo` with: sample_data, sample_rate, root_key, tuning_cents, loop_start, loop_end, has_loop, attack, hold, decay, sustain, release.

**Step 2: Validate + Commit**

```
feat: add Sf2Bank for instrument sample lookup
```

---

### Task 8: SynthVoice

**Files:**
- Create: `addons/midi_composer/player/synth_voice.gd`

**Step 1: Create SynthVoice with ADSR and sample looping**

Core state machine: IDLE → ATTACK → (HOLD) → DECAY → SUSTAIN → RELEASE → FINISHED

`start(sample, channel, key, velocity, target_rate)` — initialize voice:
- Compute `_playback_step = target_rate * pow(2.0, semitones / 12.0) / sample_rate`
- `_velocity_factor = velocity / 127.0`
- `_sample_position = 0.0`

`get_next_frame() -> Vector2`:
1. If FINISHED, return `Vector2.ZERO`
2. Read 16-bit signed PCM at `_sample_position` with linear interpolation
3. Advance `_sample_position += _playback_step`
4. Handle loop: if in ATTACK/HOLD/DECAY/SUSTAIN and position >= loop_end, wrap to loop_start
5. Handle end: if in RELEASE and position >= sample end, state = FINISHED
6. If no loop and position >= sample end, state = FINISHED
7. Update ADSR envelope
8. Return `Vector2.ONE * sample_value * envelope * velocity_factor`

`stop()` — transition to RELEASE state (note off)

**Step 2: Validate + Commit**

```
feat: add SynthVoice with ADSR and sample looping
```

---

### Task 9: VoiceManager

**Files:**
- Create: `addons/midi_composer/player/voice_manager.gd`

**Step 1: Create VoiceManager with voice stealing**

Pre-allocate 128 SynthVoice instances.

`start_note(channel, key, velocity, sample, target_rate)`:
1. Check if voice already exists for channel+key → stop it first
2. Count active voices for this channel → if >= VOICES_PER_CHANNEL, steal oldest releasing voice on this channel
3. Find IDLE voice → if none, steal oldest releasing voice globally
4. If still none, steal oldest active voice globally
5. Start the found voice with the sample

`stop_note(channel, key)` — find voice by channel+key, call `stop()`

`stop_all()` — call `stop()` on all non-IDLE voices

`get_active_voices() -> Array[SynthVoice]` — return all voices not in IDLE/FINISHED state

**Step 2: Validate + Commit**

```
feat: add VoiceManager with polyphony and voice stealing
```

---

### Task 10: MidiStreamPlayer

**Files:**
- Create: `addons/midi_composer/player/midi_stream_player.gd`

**Step 1: Create MidiStreamPlayer extending AudioStreamPlayer**

Key implementation points:
- `_get_property_list()` — filter out `stream` and `pitch_scale` from base class
- `_ready()` — create AudioStreamGenerator, assign to internal `stream`
- `set_soundfont(path)` — load SF2 via Sf2Reader → Sf2Bank
- `play(from_position)` — override, init sequencer, call `super.play(0)`
- `stop()` — override, reset sequencer + voices, call `super.stop()`
- `pause()` / `resume()` — custom pause state (base class has no pause)
- `get_playback_position()` — override, return internal `_song_position`
- `_process(delta)` — advance sequencer, trigger Note On/Off, fill audio buffer, check for end/loop

Sequencer logic:
- Maintain `_song_position` (seconds)
- Convert to ticks: `tick = song_position * ticks_per_second`
- On each frame: find all events between current tick and next tick
- Trigger Note On → `voice_manager.start_note(sf2_bank.get_sample(...))`
- Trigger Note Off → `voice_manager.stop_note(channel, key)`
- Track per-channel current instrument (Program Change events)

Buffer fill:
- `get_frames_available()` frames to fill
- Cap at 4096 per frame
- For each frame: sum all active voices' `get_next_frame()`
- Push via `_playback.push_frame(frame)`

**Step 2: Validate + Commit**

```
feat: add MidiStreamPlayer extending AudioStreamPlayer
```

---

### Task 11: Plugin.gd Updates

**Files:**
- Modify: `addons/midi_composer/plugin.gd`

**Step 1: Add project settings registration**

Register `midi_composer/default_soundfont` as a global file path setting in `_enter_tree()`.

**Step 2: Validate + Commit**

```
feat: register default soundfont project setting
```

---

### Task 12: MidiInspectorPlugin

**Files:**
- Create: `addons/midi_composer/midi_inspector_plugin.gd`
- Modify: `addons/midi_composer/plugin.gd` (register inspector plugin)

**Step 1: Create InspectorPlugin**

`_can_handle(object)` — return `object is MidiResource`

`_parse_end(object)`:
1. Create HBoxContainer with Play/Stop buttons
2. Soundfont source: check `ProjectSettings.get_setting("midi_composer/default_soundfont", "")`
3. If no soundfont configured, disable Play button, show warning label
4. On Play: create temporary MidiStreamPlayer, attach to base_control, call play()
5. On Stop: stop and free the temporary player
6. Track current object — if `_parse_end` called with different object, stop previous playback

**Step 2: Update plugin.gd**

Register/remove inspector plugin in `_enter_tree()` / `_exit_tree()`.

**Step 3: Manual test** — select a MidiResource in Inspector, verify preview buttons appear and can play.

**Step 4: Validate + Commit**

```
feat: add editor preview for MidiResource via InspectorPlugin
```

---

## Commit Plan Summary

| Commit | Content |
|--------|---------|
| 1 | NoteResource + TrackResource |
| 2 | MidiResource |
| 3 | MidiReader |
| 4 | MidiImportPlugin + plugin.gd import registration |
| 5 | Sf2Data structures |
| 6 | Sf2Reader |
| 7 | Sf2Bank |
| 8 | SynthVoice |
| 9 | VoiceManager |
| 10 | MidiStreamPlayer |
| 11 | plugin.gd project settings |
| 12 | MidiInspectorPlugin |

## Testing Strategy

- **Tasks 1-2 (Resources):** Validate via gdscript-validate, manual Inspector test
- **Task 3 (MidiReader):** Round-trip test (encode → parse → verify), parse known .mid file
- **Task 4 (Import):** Manual — place .mid in project, verify import
- **Tasks 5-7 (SF2):** Validate via gdscript-validate, manual — parse real .sf2 file
- **Task 8 (SynthVoice):** Unit test — verify ADSR envelope, pitch calculation
- **Tasks 9-10 (Player):** Manual — scene with MidiStreamPlayer, verify audio output
- **Tasks 11-12 (Editor):** Manual — Inspector preview, project settings

## Key Reference Files

| File | Purpose |
|------|---------|
| `addons/midi/SMF.gd` | MIDI parsing reference (VLQ, chunk reading, event types) |
| `addons/midi/SoundFont.gd` | SF2 parsing reference (chunk structure, GEN types) |
| `addons/midi/MidiPlayer.gd` | Player architecture reference (sequencer, voice management) |
| `addons/midi_composer/midi_writer.gd` | Existing encoder (mirror structure for reader) |
| `addons/midi_composer/midi_types/*.gd` | Existing data types (MidiData, TrackData, NoteData) |
