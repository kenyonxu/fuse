# Clef 立体声采样 + MIDI↔JSON 编辑器工具 实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 Clef MIDI 播放器添加立体声采样支持和 MIDI↔JSON 编辑器工具。

**Architecture:** 立体声采用交错 AudioStreamWAV 方案（L/R PCM 交错为 `stereo=true` 的 AudioStreamWAV），不需要修改 Voice/VoicePool/Bus。JSON 工具在现有 `MidiComposerConverter` + `MidiWriter` 基础上补全 MidiWriter 缺失的事件写入，并在编辑器菜单中暴露导出/导入入口。

**Tech Stack:** Godot 4.6 GDScript, SF2 格式规范, SMF (Standard MIDI File) Format 1

**Skills:** @gdscript-validate

---

## Part A: 立体声采样支持

### Task 1: 扩展 Sf2SampleInfo 添加立体声字段

**Files:**
- Modify: `addons/clef/player/sf2_sample_info.gd`

**Step 1: 添加立体声相关字段**

在 `sf2_sample_info.gd` 末尾（`release` 字段之后）添加：

```gdscript
## 采样类型 (位标志: 1=mono, 2=right, 4=left, 8=linked, 0x8001-0x8008=ROM 变体)
var sample_type: int = 1
## 立体声链接采样索引 (在 Sf2Data.samples 中的索引)
var link_index: int = 0
## 关联声道的 PCM 数据 (16-bit signed, little-endian, 与 sample_data 等长)
var linked_sample_data: PackedByteArray = []
```

**Step 2: 运行 GDScript 验证**

Run: `C:\Users\kenyo\.claude\skills\gdscript-validate\scripts\refresh_godot_lsp.sh`
Expected: 无错误

**Step 3: Commit**

```bash
git add addons/clef/player/sf2_sample_info.gd
git commit -m "refactor(clef): add stereo fields to Sf2SampleInfo"
```

---

### Task 2: Sf2Bank 立体声检测与数据提取

**Files:**
- Modify: `addons/clef/player/sf2_bank.gd`

**Step 1: 添加立体声检测逻辑**

在 `sf2_bank.gd` 的 `get_sample()` 方法中，在 `# 4. 构建 Sf2SampleInfo` 部分（构建 `info` 之后，`return info` 之前），添加立体声检测：

```gdscript
# 5. 立体声检测: 检查 sample_type 是否为 left/right/linked
var st: int = sample_header.sample_type
if st == 2 or st == 4 or st == 8 or st == 0x8002 or st == 0x8004 or st == 0x8008:
	info.sample_type = st
	# 获取链接的采样头
	var linked_idx: int = sample_header.link_index
	if linked_idx >= 0 and linked_idx < _sf2_data.samples.size() and linked_idx != sample_index:
		var linked_header: Sf2Data.Sf2SampleHeader = _sf2_data.samples[linked_idx]
		# 提取链接采样的 PCM 数据 (使用与主采样相同的偏移逻辑)
		var linked_actual_start: int = linked_header.start + total_start_offset
		var linked_actual_end: int = linked_header.end + total_end_offset
		# 链接采样使用自己的偏移，不累加主采样的偏移
		var linked_byte_start: int = linked_actual_start * 2
		var linked_byte_end: int = linked_actual_end * 2 - 1
		if linked_byte_start < 0:
			linked_byte_start = 0
		if linked_byte_end > _sf2_data.sample_data.size():
			linked_byte_end = _sf2_data.sample_data.size()
		if linked_byte_start < linked_byte_end:
			info.linked_sample_data = _sf2_data.sample_data.slice(linked_byte_start, linked_byte_end)
		info.link_index = linked_idx
```

**重要说明：** 链接采样的偏移 (`start_offset`/`end_offset`) 应该使用当前乐器区域的偏移，而不是链接采样的原始偏移。但为了与 MidiPlayer 行为一致（MidiPlayer 使用链接采样的原始 start/end，不加偏移），这里使用 `linked_header.start` 和 `linked_header.end` 不加偏移。如果发现不一致，改为也加偏移。

**Step 2: 移除调试打印代码**

删除 `sf2_bank.gd` 中的以下内容：
- `_dbg_printed` 变量声明（第 13 行）
- `get_sample()` 中从 `# DEBUG: 首次查询每个 preset 时打印所有 zone` 到 `break` 的整个调试打印块（约第 28-59 行）

**Step 3: 运行 GDScript 验证**

Run: `C:\Users\kenyo\.claude\skills\gdscript-validate\scripts\refresh_godot_lsp.sh`
Expected: 无错误

**Step 4: Commit**

```bash
git add addons/clef/player/sf2_bank.gd
git commit -m "feat(clef): detect stereo samples in Sf2Bank and extract linked channel data"
```

---

### Task 3: ClefBank 生成交错立体声 AudioStreamWAV

**Files:**
- Modify: `addons/clef/player/clef_bank.gd`
- Modify: `addons/clef/player/clef_instrument_info.gd`

**Step 1: 在 ClefInstrumentInfo 添加 is_stereo 字段**

在 `clef_instrument_info.gd` 的 `volume_db` 字段之后添加：

```gdscript
## 是否为立体声采样 (L/R 交错)
var is_stereo: bool = false
```

**Step 2: 修改 ClefBank.load_from_sf2() 添加立体声静音头**

在 `clef_bank.gd` 的 `load_from_sf2()` 中，在 `_head_silent` 初始化之后添加立体声静音头：

```gdscript
## 立体声静音数据 (PackedByteArray, 5512 * 2 * 2 bytes = L0R0L1R1...)
var _head_silent_stereo: PackedByteArray = []
```

在 `load_from_sf2()` 的 `_head_silent` 初始化后添加：

```gdscript
_head_silent_stereo = PackedByteArray()
_head_silent_stereo.resize(HEAD_SILENT_SAMPLES * 4)
_head_silent_stereo.fill(0)
```

**Step 3: 修改 get_instrument() 支持立体声**

在 `clef_bank.gd` 的 `get_instrument()` 中，替换核心的 AudioStreamWAV 生成逻辑：

```gdscript
func get_instrument(preset_index: int, key: int, velocity: int, channel: int) -> ClefInstrumentInfo:
	if _sf2_bank == null:
		return null
	var sample: Sf2SampleInfo = _sf2_bank.get_sample(preset_index, key, velocity, channel)
	if sample == null or sample.sample_data.size() == 0:
		return null

	var is_stereo: bool = sample.linked_sample_data.size() > 0

	# 缓存 key: 基于采样数据特征
	var cache_key: String = "%d_%d_%d_%d_%d_%d" % [
		sample.sample_data.size(), sample.root_key,
		sample.sample_rate, sample.tuning_cents,
		1 if sample.has_loop else 0,
		1 if is_stereo else 0,
	]
	if _cache.has(cache_key):
		return _cache[cache_key]

	var info := ClefInstrumentInfo.new()
	info.is_stereo = is_stereo

	# 生成 AudioStreamWAV
	var asw := AudioStreamWAV.new()
	asw.format = AudioStreamWAV.FORMAT_16_BITS
	asw.mix_rate = 44100
	asw.stereo = is_stereo

	var full_data: PackedByteArray

	if is_stereo:
		# 交错 L/R PCM 数据: L0_lo L0_hi R0_lo R0_hi L1_lo L1_hi R1_lo R1_hi ...
		var min_len: int = mini(sample.sample_data.size(), sample.linked_sample_data.size())
		# 取对齐到 2 字节的长度 (每个采样 2 字节)
		min_len -= min_len % 2
		var interleaved := PackedByteArray()
		interleaved.resize(min_len * 2)
		for i in range(0, min_len, 2):
			var frame_offset: int = i * 2  # stereo: 每帧 4 字节
			interleaved[frame_offset] = sample.sample_data[i]
			interleaved[frame_offset + 1] = sample.sample_data[i + 1]
			interleaved[frame_offset + 2] = sample.linked_sample_data[i]
			interleaved[frame_offset + 3] = sample.linked_sample_data[i + 1]
		full_data = _head_silent_stereo + interleaved
	else:
		full_data = _head_silent + sample.sample_data

	asw.data = full_data

	# 循环设置
	if sample.has_loop:
		asw.loop_mode = AudioStreamWAV.LOOP_FORWARD
		if is_stereo:
			# 立体声: 循环点以采样帧为单位 (每帧 4 字节)
			# loop_start/loop_end 原始是字节偏移 (单声道), 需要转采样帧然后乘 4
			var loop_start_frame: int = sample.loop_start / 2
			var loop_end_frame: int = sample.loop_end / 2
			# 取两声道中的较小值
			var linked_loop_start_frame: int = loop_start_frame
			var linked_loop_end_frame: int = loop_end_frame
			# 加上静音头
			asw.loop_begin = mini(loop_start_frame, linked_loop_start_frame) + HEAD_SILENT_SAMPLES
			asw.loop_end = mini(loop_end_frame, linked_loop_end_frame) + HEAD_SILENT_SAMPLES
		else:
			asw.loop_begin = sample.loop_start / 2 + HEAD_SILENT_SAMPLES
			asw.loop_end = sample.loop_end / 2 + HEAD_SILENT_SAMPLES
	else:
		asw.loop_mode = AudioStreamWAV.LOOP_DISABLED

	info.stream = asw
	info.root_key = sample.root_key

	# base_pitch: 采样率补偿 + 音高微调 (不含 key 偏移)
	info.base_pitch = float(sample.tuning_cents) / 1200.0
	if sample.sample_rate != 44100:
		info.base_pitch += log(float(sample.sample_rate) / 44100.0) / log(2.0)

	# ADSR 参数
	info.attack = sample.attack
	info.hold = sample.hold
	info.decay = sample.decay
	info.sustain_db = linear_to_db(sample.sustain)
	info.release = sample.release

	_cache[cache_key] = info
	return info
```

**Step 4: 运行 GDScript 验证**

Run: `C:\Users\kenyo\.claude\skills\gdscript-validate\scripts\refresh_godot_lsp.sh`
Expected: 无错误

**Step 5: Commit**

```bash
git add addons/clef/player/clef_bank.gd addons/clef/player/clef_instrument_info.gd
git commit -m "feat(clef): generate interleaved stereo AudioStreamWAV for stereo SF2 samples"
```

---

### Task 4: 立体声验证与调试

**Files:** 无新文件

**Step 1: 启动 Godot 运行测试**

在 Godot 中加载包含立体声采样的 SF2 文件（如 GeneralUser GS），播放 Reggae Romantic.mid 或 HotelCalifornia.mid，对比 MidiPlayer 的立体声效果。

验证点：
- 立体声乐器有明显的空间深度感（如钢琴、吉他等）
- 单声道乐器播放正常，无变化
- 循环播放的立体声采样无爆音/卡顿
- `get_instrument()` 日志中 `is_stereo=true` 的乐器数量合理

**Step 2: 修复发现的问题**

根据测试结果修复：
- 如果循环点错误导致爆音，检查 loop_begin/loop_end 计算是否正确
- 如果 L/R 颠倒，检查 `sample_type` 的判断逻辑
- 如果某声道缺失，检查 `linked_sample_data` 提取逻辑

**Step 3: Commit (如有修复)**

```bash
git add -u
git commit -m "fix(clef): fix stereo sample playback issues found during testing"
```

---

## Part B: MIDI↔JSON 编辑器工具

### Task 5: 补全 MidiWriter — tempo_events 写入

**Files:**
- Modify: `addons/clef/midi_writer.gd`

**Step 1: 修改 _write_tempo_track() 支持多个 tempo change**

替换 `_write_tempo_track()` 方法，在初始 tempo 之后写入所有 `tempo_events`：

```gdscript
static func _write_tempo_track(stream: StreamPeerBuffer, midi_data: MidiData) -> void:
	var buf: StreamPeerBuffer = StreamPeerBuffer.new()
	buf.big_endian = true

	# 拍号 (delta=0)
	_write_variable_length_quantity(buf, 0)
	_write_meta_time_signature(buf)

	# 初始速度 (delta=0)
	_write_variable_length_quantity(buf, 0)
	_write_meta_tempo(buf, midi_data.tempo)

	# 额外的 tempo changes
	if midi_data.tempo_events.size() > 0:
		var last_tick: int = 0
		for tc in midi_data.tempo_events:
			var tc_tick: int = int(tc.get("time_ticks", 0))
			var tc_bpm: int = int(tc.get("bpm", 0))
			if tc_tick <= 0 or tc_bpm <= 0:
				continue
			var delta: int = tc_tick - last_tick
			last_tick = tc_tick
			_write_variable_length_quantity(buf, maxi(delta, 0))
			_write_meta_tempo(buf, tc_bpm)

	# 轨道结束 (delta=0)
	_write_variable_length_quantity(buf, 0)
	_write_meta_end_of_track(buf)

	_wrap_as_track_chunk(stream, buf)
```

**Step 2: 添加全局 CC/PB/program events 分发到轨道**

修改 `encode()` 方法，在写入轨道之前，将全局事件分发到对应通道的轨道：

```gdscript
static func encode(midi_data: MidiData) -> PackedByteArray:
	var stream: StreamPeerBuffer = StreamPeerBuffer.new()
	stream.big_endian = true

	_write_header(stream, midi_data)
	_write_tempo_track(stream, midi_data)

	# 分发全局事件到对应轨道
	var tracks_copy: Array[TrackData] = []
	for track_data in midi_data.tracks:
		tracks_copy.append(track_data)

	# 分发全局 CC events
	for cc in midi_data.cc_events:
		var ch: int = int(cc.get("channel", 0))
		for track in tracks_copy:
			if track.channel == ch:
				track.cc_events.append(cc)
				break

	# 分发全局 Pitch Bend events
	for pb in midi_data.pitch_bend_events:
		var ch: int = int(pb.get("channel", 0))
		for track in tracks_copy:
			if track.channel == ch:
				track.pitch_bend_events.append(pb)
				break

	# 分发全局 Program Change events
	for pc in midi_data.program_events:
		var ch: int = int(pc.get("channel", 0))
		var preset: int = int(pc.get("preset_index", 0))
		for track in tracks_copy:
			if track.channel == ch:
				track.instrument = preset
				break

	for track_data in tracks_copy:
		_write_note_track(stream, track_data)

	return stream.data_array
```

**注意：** 这里直接修改了 TrackData 的 cc_events/pitch_bend_events 数组（GDScript 中 Array 是引用类型）。为了不污染原始数据，应该深拷贝。但 `TrackData` 没有 `duplicate()` 方法，所以改用在上面的分发逻辑中只在写入时临时合并，不修改原 TrackData。

**修正方案：** 不修改原始 TrackData，改为在 `_write_note_track()` 中接受额外的全局事件参数。这需要更大的改动。更简单的方案：在 `encode()` 中先拷贝事件列表。

实际修改为在 encode 中创建临时 TrackData 副本：

```gdscript
static func encode(midi_data: MidiData) -> PackedByteArray:
	var stream: StreamPeerBuffer = StreamPeerBuffer.new()
	stream.big_endian = true

	_write_header(stream, midi_data)
	_write_tempo_track(stream, midi_data)

	for track_data in midi_data.tracks:
		# 创建临时轨道副本，合并全局事件
		var temp_track := TrackData.new(
			track_data.name, track_data.channel, track_data.instrument,
			track_data.notes.duplicate(),
			track_data.cc_events.duplicate(),
			track_data.pitch_bend_events.duplicate()
		)

		# 合并同通道的全局 CC events
		for cc in midi_data.cc_events:
			if int(cc.get("channel", 0)) == track_data.channel:
				temp_track.cc_events.append(cc)

		# 合并同通道的全局 Pitch Bend events
		for pb in midi_data.pitch_bend_events:
			if int(pb.get("channel", 0)) == track_data.channel:
				temp_track.pitch_bend_events.append(pb)

		_write_note_track(stream, temp_track)

	return stream.data_array
```

**Step 3: 运行 GDScript 验证**

Run: `C:\Users\kenyo\.claude\skills\gdscript-validate\scripts\refresh_godot_lsp.sh`
Expected: 无错误

**Step 4: Commit**

```bash
git add addons/clef/midi_writer.gd
git commit -m "feat(clef): MidiWriter support tempo_events and global CC/PB/program events"
```

---

### Task 6: 编辑器菜单 — Export MIDI to JSON

**Files:**
- Modify: `addons/clef/plugin.gd`

**Step 1: 在 plugin.gd 添加两个新菜单项**

修改 `_enter_tree()` 和 `_exit_tree()`，添加 "Export MIDI/JSON..." 和 "Import JSON/MIDI..." 菜单项：

```gdscript
var _export_menu_name: String = "Export MIDI/JSON..."
var _import_menu_name: String = "Import JSON/MIDI..."

func _enter_tree() -> void:
	add_tool_menu_item(_tool_menu_name, _on_tool_menu_pressed)
	add_tool_menu_item(_export_menu_name, _on_export_menu_pressed)
	add_tool_menu_item(_import_menu_name, _on_import_menu_pressed)
	_import_plugin = MidiImportPlugin.new()
	add_import_plugin(_import_plugin)
	_inspector_plugin = MidiInspectorPlugin.new()
	add_inspector_plugin(_inspector_plugin)
	_register_project_settings()

func _exit_tree() -> void:
	if _inspector_plugin != null:
		remove_inspector_plugin(_inspector_plugin)
		_inspector_plugin = null
	if _import_plugin != null:
		remove_import_plugin(_import_plugin)
		_import_plugin = null
	remove_tool_menu_item(_tool_menu_name)
	remove_tool_menu_item(_export_menu_name)
	remove_tool_menu_item(_import_menu_name)
```

**Step 2: 实现 _on_export_menu_pressed()**

```gdscript
func _on_export_menu_pressed() -> void:
	var paths: PackedStringArray = EditorInterface.get_selected_paths()
	if paths.is_empty():
		_show_error("请先在文件系统面板中选择 .mid 或 .tres 文件")
		return

	var input_path: String = paths[0]
	if not (input_path.ends_with(".mid") or input_path.ends_with(".tres")):
		_show_error("不支持的文件格式，请选择 .mid 或 .tres 文件")
		return

	if not FileAccess.file_exists(input_path):
		_show_error("文件不存在：" + input_path)
		return

	# 读取 MidiData
	var midi_data: MidiData = null
	if input_path.ends_with(".tres"):
		var res = load(input_path)
		if res == null or not res is MidiResource:
			_show_error("无法加载 MidiResource：" + input_path)
			return
		midi_data = res.get_midi_data()
	else:
		var file := FileAccess.open(input_path, FileAccess.READ)
		if file == null:
			_show_error("无法读取文件：" + input_path)
			return
		var bytes := file.get_buffer(file.get_length())
		var result := MidiReader.from_bytes(bytes)
		if not result.ok:
			_show_error("MIDI 解析失败：" + result.error_message)
			return
		midi_data = result.midi_data

	if midi_data == null:
		_show_error("无法获取 MIDI 数据")
		return

	# 转换为 JSON
	var json_text: String = MidiComposerConverter.to_json_string(midi_data)

	# 弹出保存对话框
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.title = "导出 JSON"
	dialog.filters = PackedStringArray(["*.json ; JSON 文件"])
	dialog.current_file = input_path.get_basename() + ".json"
	dialog.file_selected.connect(func(path: String) -> void:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			_show_error("无法写入文件：" + path)
			return
		file.store_string(json_text)
		file.close()
		EditorInterface.get_resource_filesystem().scan()
		EditorInterface.get_base_control().remove_child(dialog)
		dialog.queue_free()
	)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(600, 400))
```

**Step 3: 实现 _on_import_menu_pressed()**

```gdscript
func _on_import_menu_pressed() -> void:
	var paths: PackedStringArray = EditorInterface.get_selected_paths()
	if paths.is_empty():
		_show_error("请先在文件系统面板中选择 .json 文件")
		return

	var json_path: String = paths[0]
	if not json_path.ends_with(".json"):
		_show_error("请选择 .json 文件")
		return

	if not FileAccess.file_exists(json_path):
		_show_error("文件不存在：" + json_path)
		return

	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		_show_error("无法读取文件：" + json_path)
		return

	var json_text: String = file.get_as_text()
	var result := MidiComposerConverter.from_json_string(json_text)
	if not result.ok:
		_show_error("JSON 转换失败：" + result.error_message)
		return

	var midi_bytes: PackedByteArray = MidiWriter.encode(result.midi_data)

	# 弹出保存对话框
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.title = "导入为 MIDI"
	dialog.filters = PackedStringArray(["*.mid ; MIDI 文件"])
	dialog.current_file = json_path.get_basename() + ".mid"
	dialog.file_selected.connect(func(path: String) -> void:
		var out_file := FileAccess.open(path, FileAccess.WRITE)
		if out_file == null:
			_show_error("无法写入 MIDI 文件：" + path)
			return
		out_file.store_buffer(midi_bytes)
		out_file.close()
		EditorInterface.get_resource_filesystem().scan()
		EditorInterface.get_base_control().remove_child(dialog)
		dialog.queue_free()
	)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(600, 400))
```

**Step 4: 运行 GDScript 验证**

Run: `C:\Users\kenyo\.claude\skills\gdscript-validate\scripts\refresh_godot_lsp.sh`
Expected: 无错误

**Step 5: Commit**

```bash
git add addons/clef/plugin.gd
git commit -m "feat(clef): add Export MIDI/JSON and Import JSON/MIDI editor menu items"
```

---

### Task 7: 整体验证

**Files:** 无新文件

**Step 1: 验证 JSON 导出**

1. 在 Godot 编辑器的 FileSystem 中选择一个 `.tres` (MidiResource)
2. Project → Tools → "Export MIDI/JSON..."
3. 选择保存位置，生成 `.json`
4. 打开 `.json` 确认结构正确（format_version=1.1, tracks, tempo_changes）

**Step 2: 验证 JSON→MIDI 往返**

1. 选择刚生成的 `.json`
2. Project → Tools → "Import JSON/MIDI..."
3. 生成 `.mid`
4. 将 `.mid` 导入为 `.tres`，播放对比原始文件

**Step 3: 验证 InspectorPlugin 中的 Export JSON 按钮**

1. 在 Inspector 中选择一个 `MidiResource`
2. 点击 "Export JSON" 按钮
3. 确认文件对话框弹出，保存成功

**Step 4: 验证立体声播放**

1. 使用包含立体声采样的 SF2 文件
2. 播放包含立体声乐器的 MIDI 文件
3. 对比 MidiPlayer，确认空间感一致

**Step 5: 最终 Commit（如有修复）**

```bash
git add -u
git commit -m "fix(clef): fix issues found during integration testing"
```
