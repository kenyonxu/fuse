# MIDI 播放进度显示 实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 MidiStreamPlayer 添加运行时播放进度 UI 组件（进度条 + 时间标签 + 控制按钮 + seek），并改进编辑器 Inspector 预览。

**Architecture:** 新建可复用的 `MidiPlayerUI` Control 场景，通过 `@export` 绑定 MidiStreamPlayer，由 `progress_updated` 信号驱动 UI 更新。编辑器 Inspector 预览从 ProgressBar 升级为 HSlider + 时间标签 + seek + 暂停按钮，消除私有成员访问。

**Tech Stack:** Godot 4.6 / GDScript 2.0 / Control 节点 / HSlider / EditorInspectorPlugin

---

## Task 1: MidiStreamPlayer 公开 API 补全

**Files:**
- Modify: `addons/clef/player/midi_stream_player.gd:19-20` (新增信号)
- Modify: `addons/clef/player/midi_stream_player.gd:219-222` (公开 get_duration)
- Modify: `addons/clef/player/midi_stream_player.gd:351-382` (_process 中 emit 信号)

**Step 1: 添加 progress_updated 信号**

在 `midi_stream_player.gd` 第 20 行（`signal finished` 之后）添加：

```gdscript
signal progress_updated(position: float, duration: float)
```

**Step 2: 将 _get_duration 改为公开方法**

将第 219 行的 `func _get_duration() -> float:` 改为：

```gdscript
## 获取曲目总时长 (秒)
func get_duration() -> float:
	if midi_resource == null:
		return 0.0
	return midi_resource.get_duration_seconds()
```

注意：`_get_duration()` 未被外部调用（仅内部可能的 `_get_property_list` 不使用它），改为公开无风险。

**Step 3: 添加 is_paused() 公开 getter**

在第 203 行 `func is_playing()` 之后添加：

```gdscript
## 是否暂停中
func is_paused() -> bool:
	return _is_paused
```

**Step 4: 在 _process 中 emit progress_updated**

在 `_process` 方法中（第 358 行 `_current_tick += ...` 之后），添加信号发射逻辑。找到 `_process` 方法中处理事件后的代码块（第 369-381 行 `var all_events_done` 之前），插入：

```gdscript
# 发射进度更新信号
if _duration_ticks > 0:
	var pos: float = _current_tick / _ticks_per_second
	var dur: float = float(_duration_ticks) / _ticks_per_second
	progress_updated.emit(pos, dur)
```

完整的 `_process` 方法修改后如下：

```gdscript
func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not _editor_preview:
		return
	if _is_paused or not _is_playing or midi_resource == null:
		return

	_current_tick += float(delta) * _ticks_per_second
	var current_tick: int = int(_current_tick)

	while _event_index < _sorted_events.size():
		var event: Dictionary = _sorted_events[_event_index]
		if event["time_ticks"] > current_tick:
			break
		_process_event(event)
		_event_index += 1

	# 发射进度更新信号
	if _duration_ticks > 0:
		var pos: float = _current_tick / _ticks_per_second
		var dur: float = float(_duration_ticks) / _ticks_per_second
		progress_updated.emit(pos, dur)

	var all_events_done: bool = _event_index >= _sorted_events.size()
	if all_events_done and current_tick >= _duration_ticks:
		if loop and _duration_ticks > 0:
			_current_tick = 0.0
			_event_index = 0
			_channel_instruments.clear()
			for state in _channel_states:
				state.reset()
		elif _voice_pool.get_active_voices().size() == 0:
			stop()
			finished.emit()
```

**Step 5: 验证 — 启动 Godot 编辑器，确认无脚本错误**

Run: 启动 Godot 编辑器，打开项目，检查输出面板无错误

Expected: 无错误

**Step 6: Commit**

```bash
git add addons/clef/player/midi_stream_player.gd
git commit -m "feat(clef): add progress_updated signal and public get_duration/is_paused API"
```

---

## Task 2: 创建 MidiPlayerUI 控制脚本

**Files:**
- Create: `addons/clef/ui/midi_player_ui.gd`

**Step 1: 创建 `addons/clef/ui/` 目录**

```bash
mkdir -p addons/clef/ui
```

**Step 2: 编写 MidiPlayerUI 脚本**

创建 `addons/clef/ui/midi_player_ui.gd`：

```gdscript
## MIDI 播放器进度 UI — 进度条 + 时间显示 + 播放/暂停/停止控制
class_name MidiPlayerUI
extends Control

@export var player: MidiStreamPlayer : set = set_player

@onready var _play_button: Button = %PlayButton
@onready var _stop_button: Button = %StopButton
@onready var _slider: HSlider = %ProgressSlider
@onready var _time_label: Label = %TimeLabel

var _is_seeking: bool = false


func _ready() -> void:
	if _play_button:
		_play_button.pressed.connect(_on_play_pressed)
	if _stop_button:
		_stop_button.pressed.connect(_on_stop_pressed)
	if _slider:
		_slider.drag_started.connect(func() -> void: _is_seeking = true)
		_slider.drag_ended.connect(_on_slider_drag_ended)
		_slider.value_changed.connect(_on_slider_value_changed)
	if player:
		_connect_player_signals()
	_update_display(0.0, 0.0)


func set_player(value: MidiStreamPlayer) -> void:
	if player == value:
		return
	if player:
		_disconnect_player_signals()
	player = value
	if player:
		_connect_player_signals()


func _connect_player_signals() -> void:
	if not player or not player.progress_updated.is_connected(_on_progress_updated):
		player.progress_updated.connect(_on_progress_updated)
	if not player or not player.finished.is_connected(_on_player_finished):
		player.finished.connect(_on_player_finished)


func _disconnect_player_signals() -> void:
	if player:
		if player.progress_updated.is_connected(_on_progress_updated):
			player.progress_updated.disconnect(_on_progress_updated)
		if player.finished.is_connected(_on_player_finished):
			player.finished.disconnect(_on_player_finished)


func _on_progress_updated(position: float, duration: float) -> void:
	if _is_seeking:
		return
	_update_display(position, duration)
	if _slider and duration > 0.0:
		_slider.max_value = duration
		_slider.value = position


func _update_display(position: float, duration: float) -> void:
	if _time_label:
		_time_label.text = "%s / %s" % [
			_format_time(position),
			_format_time(duration),
		]


static func _format_time(seconds: float) -> String:
	var mins: int = int(seconds) / 60
	var secs: int = int(seconds) % 60
	return "%d:%02d" % [mins, secs]


func _on_play_pressed() -> void:
	if not player:
		return
	if player.is_playing():
		player.pause()
		if _play_button:
			_play_button.text = "▶"
	else:
		if player.is_paused():
			player.resume()
		else:
			player.start_playback()
		if _play_button:
			_play_button.text = "⏸"


func _on_stop_pressed() -> void:
	if not player:
		return
	player.stop()
	if _play_button:
		_play_button.text = "▶"
	if _slider:
		_slider.value = 0.0
	_update_display(0.0, player.get_duration())


func _on_slider_drag_ended(value: float) -> void:
	_is_seeking = false
	if player:
		player.seek(value)


func _on_slider_value_changed(value: float) -> void:
	# 拖拽中仅更新时间标签，不 seek
	if _is_seeking and _slider:
		_update_display(value, _slider.max_value)


func _on_player_finished() -> void:
	if _play_button:
		_play_button.text = "▶"
	if _slider:
		_slider.value = 0.0
	_update_display(0.0, player.get_duration() if player else 0.0)
```

**Step 3: 验证 — 启动 Godot 编辑器，确认无脚本错误**

Run: 启动 Godot 编辑器，检查输出面板

Expected: 无错误

**Step 4: Commit**

```bash
git add addons/clef/ui/midi_player_ui.gd
git commit -m "feat(clef): add MidiPlayerUI control script for playback progress display"
```

---

## Task 3: 创建 MidiPlayerUI 场景

**Files:**
- Create: `addons/clef/ui/midi_player_ui.tscn`

**Step 1: 创建场景文件**

创建 `addons/clef/ui/midi_player_ui.tscn`：

```
[gd_scene load_steps=2 format=3 uid="uid://<auto-generated>"]

[ext_resource type="Script" path="res://addons/clef/ui/midi_player_ui.gd" id="1_ui"]

[node name="MidiPlayerUI" type="Control"]
layout_mode = 3
anchors_preset = 12
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 0
script = ExtResource("1_ui")

[node name="HBox" type="HBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/separation = 8

[node name="PlayButton" type="Button" parent="HBox"]
layout_mode = 2
custom_minimum_size = Vector2(36, 0)
text = "▶"

[node name="StopButton" type="Button" parent="HBox"]
layout_mode = 2
custom_minimum_size = Vector2(36, 0)
text = "⏹"

[node name="ProgressSlider" type="HSlider" parent="HBox"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
min_value = 0.0
max_value = 1.0
step = 0.01
value = 0.0

[node name="TimeLabel" type="Label" parent="HBox"]
unique_name_in_owner = true
layout_mode = 2
custom_minimum_size = Vector2(80, 0)
text = "0:00 / 0:00"
horizontal_alignment = 2
```

> **注意：** 上面的 `%PlayButton`、`%StopButton`、`%ProgressSlider`、`%TimeLabel` 需要 Unique Name。
> 在 Godot 编辑器中创建场景时，选中每个节点 → 右侧 Inspector → Node → 勾选 "Unique Name In Owner"。
> 或者直接用 Godot 编辑器的场景编辑器创建场景比手写 .tscn 更可靠。
> **推荐方式：** 在 Godot 编辑器中手动创建场景，比手写 .tscn 文件更安全（避免 UID 冲突）。

**推荐创建步骤（Godot 编辑器内）：**

1. 右键 `addons/clef/ui/` → 新建场景 → Control → 保存为 `midi_player_ui.tscn`
2. 根节点重命名 `MidiPlayerUI`，挂载 `midi_player_ui.gd` 脚本
3. 添加 `HBoxContainer` 子节点，锚点设为 Full Rect（preset 15）
4. 在 HBoxContainer 下添加：
   - `Button` → 命名 `PlayButton`，text = "▶"，min_size.x = 36，勾选 Unique Name
   - `Button` → 命名 `StopButton`，text = "⏹"，min_size.x = 36
   - `HSlider` → 命名 `ProgressSlider`，勾选 Unique Name，size_flags_horizontal = Expand Fill，min=0, max=1, step=0.01
   - `Label` → 命名 `TimeLabel`，勾选 Unique Name，min_size.x = 80，text = "0:00 / 0:00"，align = Right
5. 保存场景

**Step 2: 验证 — 在场景树中实例化，确认节点结构正确**

Run: Godot 编辑器中拖入 `midi_player_ui.tscn` 到任意场景

Expected: 看到 HBoxContainer 包含 Play/Stop/Slider/Label，无错误

**Step 3: Commit**

```bash
git add addons/clef/ui/midi_player_ui.tscn addons/clef/ui/midi_player_ui.gd
git commit -m "feat(clef): add MidiPlayerUI scene with slider, time label, and transport controls"
```

---

## Task 4: 编辑器 Inspector 预览增强

**Files:**
- Modify: `addons/clef/midi_inspector_plugin.gd`

**Step 1: 添加新的实例变量**

在第 11 行（`_progress_timer` 之后）添加：

```gdscript
var _pause_button: Button = null
var _time_label: Label = null
```

**Step 2: 替换 ProgressBar 为 HSlider + 时间标签 + 暂停按钮**

将 `_parse_end` 方法中第 50-58 行（`# Progress bar` 到 `container.add_child(_progress_bar)`）替换为：

```gdscript
	# Pause button
	_pause_button = Button.new()
	_pause_button.text = "⏸"
	_pause_button.tooltip_text = "暂停/继续"
	_pause_button.disabled = true
	_pause_button.pressed.connect(_on_pause_pressed)
	container.add_child(_pause_button)

	# Progress slider (替代 ProgressBar，支持 seek)
	_progress_bar = HSlider.new()
	_progress_bar.custom_minimum_size.x = 150
	_progress_bar.max_value = 1.0
	_progress_bar.value = 0.0
	_progress_bar.step = 0.01
	_progress_bar.min_value = 0.0
	_progress_bar.drag_ended.connect(_on_slider_drag_ended)
	container.add_child(_progress_bar)

	# Time label
	_time_label = Label.new()
	_time_label.text = "0:00 / 0:00"
	_time_label.custom_minimum_size.x = 80
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	container.add_child(_time_label)
```

同时将第 9 行 `var _progress_bar: ProgressBar = null` 改为：

```gdscript
var _progress_bar: HSlider = null
```

**Step 3: 添加 _on_pause_pressed 方法**

在 `_on_stop_pressed` 方法（第 109-110 行）之后添加：

```gdscript
func _on_pause_pressed() -> void:
	if _player == null:
		return
	if _player.is_paused():
		_player.resume()
		if _pause_button:
			_pause_button.text = "⏸"
	else:
		_player.pause()
		if _pause_button:
			_pause_button.text = "▶"
```

**Step 4: 添加 _on_slider_drag_ended 方法**

在 `_on_pause_pressed` 之后添加：

```gdscript
func _on_slider_drag_ended(value: float) -> void:
	if _player == null:
		return
	var duration: float = _player.get_duration()
	if duration > 0.0:
		_player.seek(clampf(value * duration, 0.0, duration))
```

**Step 5: 改进 _update_progress 使用公开 API**

将第 135-139 行替换为：

```gdscript
func _update_progress() -> void:
	if _player != null and _progress_bar != null and _player.is_playing():
		var position: float = _player.get_playback_position()
		var duration: float = _player.get_duration()
		if duration > 0.0:
			_progress_bar.value = position / duration
		if _time_label:
			var mins_p: int = int(position) / 60
			var secs_p: int = int(position) % 60
			var mins_d: int = int(duration) / 60
			var secs_d: int = int(duration) % 60
			_time_label.text = "%d:%02d / %d:%02d" % [mins_p, secs_p, mins_d, secs_d]
```

关键改动：移除 `_player._duration_ticks / _player._ticks_per_second` 私有访问，改用 `_player.get_duration()`。

**Step 6: 更新 _stop_playback 启用/禁用暂停按钮**

在 `_stop_playback` 方法中（第 113-128 行），找到 `_stop_button.disabled = true` 之后，添加：

```gdscript
		if _pause_button:
			_pause_button.disabled = true
			_pause_button.text = "⏸"
		if _time_label:
			_time_label.text = "0:00 / 0:00"
```

**Step 7: 更新 _on_play_pressed 启用暂停按钮**

在 `_on_play_pressed` 方法中，找到 `_stop_button.disabled = false` 之后，添加：

```gdscript
		if _pause_button:
			_pause_button.disabled = false
```

**Step 8: 验证 — 在 Godot 编辑器中选中 MidiResource，测试 Inspector 预览**

Run: Godot 编辑器 → 选中任意 MidiResource → Inspector 底部出现 Play/Pause/Stop + Slider + 时间标签

Expected:
- 点击 Play 按钮开始播放，进度条和时间实时更新
- 点击 Pause 暂停/继续，按钮文字切换 ⏸/▶
- 拖拽 Slider 释放后跳转到对应位置
- 点击 Stop 停止，进度条归零

**Step 9: Commit**

```bash
git add addons/clef/midi_inspector_plugin.gd
git commit -m "feat(clef): upgrade inspector preview with HSlider seek, time label, and pause button"
```

---

## Task 5: 更新 Demo 场景

**Files:**
- Modify: `addons/clef/demo/midi_stream_player.tscn`

**Step 1: 在 Godot 编辑器中打开 demo 场景**

Run: Godot 编辑器 → 打开 `addons/clef/demo/midi_stream_player.tscn`

**Step 2: 添加 MidiPlayerUI 实例**

1. 在场景树中右键根节点 → 添加子节点 → 实例化场景 → 选择 `addons/clef/ui/midi_player_ui.tscn`
2. 在 MidiPlayerUI 的 Inspector 中，将 `player` 属性拖拽绑定到 `MidiStreamPlayer` 节点
3. 选中 MidiPlayerUI 节点，设置锚点为 Bottom Wide（preset 12）：
   - anchor_top = 1.0, anchor_bottom = 1.0, anchor_right = 1.0
4. 调整 offset_top = -40 使 UI 不遮挡场景内容
5. 保存场景

**Step 3: 验证 — 运行 demo 场景**

Run: Godot 编辑器 → F5 运行 `midi_stream_player.tscn`

Expected:
- 底部出现播放进度 UI（Play/Stop + Slider + 时间标签）
- 自动播放 MIDI，进度条和时间实时更新
- 点击 Play/Pause 切换播放/暂停
- 拖拽 Slider 可 seek
- 循环播放时进度条正确重置

**Step 4: Commit**

```bash
git add addons/clef/demo/midi_stream_player.tscn
git commit -m "feat(clef): add MidiPlayerUI to demo scene for playback progress display"
```

---

## 风险与缓解

| 风险 | 缓解措施 |
|------|----------|
| HSlider 拖拽频繁触发 seek 导致卡顿 | 仅 `drag_ended` 时 seek，拖拽中仅更新时间标签 |
| player 先于 UI 被释放 | `set_player` setter 中 `is_instance_valid()` 检查，信号连接前判空 |
| Inspector seek 后重建事件索引卡顿 | `_preprocess_events_up_to()` 是 O(n)，短曲目无感知 |
| .tscn 文件 UID 冲突 | 推荐在 Godot 编辑器中创建场景而非手写 |

## 文件清单

| 操作 | 文件路径 |
|------|----------|
| 修改 | `addons/clef/player/midi_stream_player.gd` |
| 新建 | `addons/clef/ui/midi_player_ui.gd` |
| 新建 | `addons/clef/ui/midi_player_ui.tscn` |
| 修改 | `addons/clef/midi_inspector_plugin.gd` |
| 修改 | `addons/clef/demo/midi_stream_player.tscn` |

## 成功标准

- [ ] `MidiPlayerUI` 场景可添加到任意场景，绑定 `MidiStreamPlayer` 后自动显示进度
- [ ] HSlider 可拖拽 seek，时间标签 `MM:SS / MM:SS` 实时更新
- [ ] Play/Pause/Stop 按钮正常工作
- [ ] Inspector 预览使用公开 API（`get_duration()`），无私有成员访问
- [ ] 循环播放时进度条正确重置
- [ ] Demo 场景展示完整功能
