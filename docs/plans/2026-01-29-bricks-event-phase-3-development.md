# Bricks Events Phase 3 Development Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 完成高优先级的 Bricks 事件开发，将事件完成度从当前的 45% 提升到 70%+

**Architecture:** 基于 BaseEvent 基类，遵循事件目录分类（animation/audio/gameplay/input/lifecycle/node/physics/scene/timing/ui/variable），每个事件包含：事件类文件、测试脚本、测试场景、本地化翻译

**Tech Stack:** Godot 4.6, GDScript 2.0, BaseEvent 系统，TDD 开发模式

---

## 开发原则

### 核心原则
- **DRY** - 复用现有事件代码模式
- **YAGNI** - 只实现必要功能
- **TDD** - 先写测试，再实现代码
- **频繁提交** - 每个事件完成后立即 commit

### 参考文档
- **开发指南**: `@addons/bricks/docs/development/event_creation_guide.md` - **必须阅读**
- **路线图**: `@addons/bricks/docs/roadmap/2026-01-25-bricks-event-roadmap.md`
- **已完成事件**: 各子目录中的现有事件实现

### 质量标准
- 每个 **@abstract** 方法必须实现
- `initialize()` 中必须连接信号/设置监听
- `terminate()` 中必须断开信号、清理资源（Timer → stop → disconnect → remove_child → queue_free）
- 所有用户可见文本使用 `tr()` 本地化
- 信号连接前检查 `is_connected()`
- 使用 `is_instance_valid()` 检查节点有效性

---

## Phase 3A: 快速完成（高完成度分类）

**目标**: 完成完成度 > 70% 的分类，快速提升总数

### Task 1: On Audio Started（音频开始播放）

**优先级**: 🔴 最高（音频事件只差 2 个即可 100%）

**目录**: `addons/bricks/events/audio/`

**参考**: `on_audio_finished.gd` 的实现模式

**Files:**
- Create: `addons/bricks/events/audio/on_audio_started.gd`
- Create: `addons/bricks/tests/events/test_on_audio_started.gd`
- Create: `addons/bricks/tests/events/test_on_audio_started.tscn`
- Modify: `addons/bricks/localization/translations.csv` (添加翻译键)

**Step 1: 添加本地化翻译**

在 `translations.csv` 的 `# Phase 02 - Audio Events` 部分后添加：

```csv
# Phase 03 - On Audio Started Event
BRICKS_EVENT_ON_AUDIO_STARTED_NAME,音频开始播放,Audio Started
BRICKS_EVENT_ON_AUDIO_STARTED_DESC,当音频开始播放时触发,Triggers when audio starts playing
BRICKS_LOG_EVENT_AUDIO_STARTED,音频开始播放事件触发，播放器：{player},Audio started event triggered, player: {player}
BRICKS_LOG_EVENT_AUDIO_START_CHECK,音频开始检测：playing={playing},was_playing={was_playing},Audio start check: playing={playing}, was_playing={was_playing}
BRICKS_LOG_EVENT_AUDIO_ALREADY_STARTED,音频已经在播放，跳过触发,Audio already playing, skipping trigger
BRICKS_ERROR_AUDIO_PLAYER_NOT_FOUND,未找到音频播放器,Audio player not found
```

**Step 2: 创建事件类**

创建 `on_audio_started.gd`：

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/AudioStreamPlayer.svg")
extends BaseEvent
class_name OnAudioStarted

## 当音频开始播放时触发
##
## 监听 AudioStreamPlayer 的 playing 属性变化
## 检测从 false → true 的状态转换

## 目标音频播放器路径
@export var audio_player_path: NodePath = NodePath(""):
	set(value):
		audio_player_path = value
		_update_resource_name()

## 是否传递音频名称
@export var emit_audio_name: bool = false:
	set(value):
		emit_audio_name = value
		_update_resource_name()

## 循环播放时是否每次触发
@export var trigger_on_loop: bool = true:
	set(value):
		trigger_on_loop = value
		_update_resource_name()

## 检测间隔（秒）
@export_range(0.01, 1.0, 0.01) var check_interval: float = 0.1:
	set(value):
		check_interval = value
		_update_resource_name()

var _audio_player: AudioStreamPlayer = null
var _check_timer: Timer = null
var _was_playing: bool = false
var _owner_node_ref: Node = null

## 更新资源名称（必需）
func _update_resource_name():
	var loop_text = trigger_on_loop ? "" : "（循环不触发）"
	resource_name = "On Audio Started: %s%s" % [audio_player_path, loop_text]

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	_log_debug_localized("BRICKS_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

	if not owner_node:
		_create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NULL", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_owner_node_ref = owner_node

	# 获取音频播放器
	_audio_player = owner_node.get_node_or_null(audio_player_path)
	if not _audio_player:
		_create_bricks_error_localized("BRICKS_ERROR_AUDIO_PLAYER_NOT_FOUND", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	if not _audio_player is AudioStreamPlayer:
		_create_bricks_error_localized("BRICKS_ERROR_INVALID_TARGET", BricksError.ErrorType.CONFIGURATION_ERROR, {
			"node_path": str(audio_player_path),
			"expected_types": "AudioStreamPlayer"
		})
		return

	# 初始化状态
	_was_playing = _audio_player.playing

	# 创建检测定时器
	_check_timer = Timer.new()
	_check_timer.wait_time = check_interval
	_check_timer.timeout.connect(_on_check_timeout)
	_check_timer.autostart = false
	owner_node.add_child(_check_timer)
	_check_timer.start()

	_log_debug_localized("BRICKS_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 停止并清理定时器
	if _check_timer:
		_check_timer.stop()
		if _check_timer.timeout.is_connected(_on_check_timeout):
			_check_timer.timeout.disconnect(_on_check_timeout)
		if owner_node and is_instance_valid(owner_node):
			owner_node.remove_child(_check_timer)
		_check_timer.queue_free()
		_check_timer = null

	# 重置状态
	_was_playing = false
	_audio_player = null
	_owner_node_ref = null

	_log_debug_localized("BRICKS_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 定时检查
func _on_check_timeout():
	if not _audio_player or not is_instance_valid(_audio_player):
		return

	var is_playing = _audio_player.playing

	# 检测从 false → true 的变化
	if is_playing and not _was_playing:
		_log_debug_localized("BRICKS_LOG_EVENT_AUDIO_START_CHECK", {
			"playing": is_playing,
			"was_playing": _was_playing
		})
		_trigger_event()

	_was_playing = is_playing

## 触发事件
func _trigger_event():
	# 检查是否需要触发
	if not trigger_on_loop and _was_playing:
		_log_debug_localized("BRICKS_LOG_EVENT_AUDIO_ALREADY_STARTED", {})
		return

	_log_debug_localized("BRICKS_LOG_EVENT_AUDIO_STARTED", {"player": _audio_player.name})

	var context = _audio_player
	triggered.emit(context)

## 获取事件描述
func get_description() -> String:
	var interval_text = "%.2fs" % check_interval
	var loop_text = trigger_on_loop ? "" : "（首次播放时触发）"
	return "监听音频开始播放，检测间隔：%s%s" % [interval_text, loop_text]

## 获取事件类型
func get_event_type() -> String:
	return "audio_started"

## 获取事件分类
func get_event_category() -> String:
	return "audio"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if audio_player_path.is_empty():
		errors.append(tr("BRICKS_ERROR_AUDIO_PLAYER_NOT_FOUND"))

	if check_interval <= 0:
		errors.append("检测间隔必须大于 0")

	if check_interval > 1.0:
		errors.append("检测间隔建议不超过 1.0 秒")

	return errors

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "BRICKS_EVENT_ON_AUDIO_STARTED_NAME"
	metadata.category_key = "BRICKS_EVENT_CATEGORY_AUDIO"
	metadata.description_key = "BRICKS_EVENT_ON_AUDIO_STARTED_DESC"
	metadata.keywords = ["audio", "音频", "start", "开始", "play", "播放", "playing", "播放中", "monitor", "监听"]
	metadata.builtin_icon = "AudioStreamPlayer"
	return metadata
```

**Step 3: 创建测试场景**

创建 `test_on_audio_started.tscn`：

```gdscript
[gd_scene load_steps=2 format=3 uid="uid://test_on_audio_started"]

[ext_resource type="Script" path="res://addons/bricks/tests/events/test_on_audio_started.gd" id="1"]

[node name="TestOnAudioStarted" type="Node"]
script = ExtResource("1")

[node name="AudioPlayer" type="AudioStreamPlayer" parent="."]
```

**Step 4: 创建测试脚本**

创建 `test_on_audio_started.gd`：

```gdscript
extends Node

## OnAudioStarted 事件测试

func _ready():
	print("=== Testing OnAudioStarted ===")
	test_audio_start_detection()
	test_loop_triggering()
	test_not_triggered_when_already_playing()
	cleanup()
	print("=== All OnAudioStarted tests passed! ===")

func test_audio_start_detection():
	print("Test 1: Audio start detection")

	var event_script = load("res://addons/bricks/events/audio/on_audio_started.gd")
	var event = event_script.new()
	event.audio_player_path = NodePath("AudioPlayer")
	event.check_interval = 0.05

	var audio_player = $AudioPlayer
	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	var received_context = null
	event.triggered.connect(func(context):
		triggered = true
		received_context = context
	)

	# 初始化事件
	event.initialize(trigger)
	await get_tree().process_frame
	await get_tree().process_frame  # 等待定时器第一次检查

	# 启动音频播放
	audio_player.stream = load("res://addons/bricks/tests/test_audio.ogg")  # 需要测试音频
	audio_player.play()

	# 等待事件触发
	await get_tree().create_timer(0.2).timeout
	assert(triggered, "Event should trigger when audio starts")
	assert(received_context == audio_player, "Context should be the audio player")
	print("  ✓ Test 1 passed: Audio start detected\n")

	# 清理
	event.terminate(trigger)
	trigger.queue_free()

func test_loop_triggering():
	print("Test 2: Loop triggering control")

	var event_script = load("res://addons/bricks/events/audio/on_audio_started.gd")
	var event = event_script.new()
	event.audio_player_path = NodePath("AudioPlayer")
	event.trigger_on_loop = false  # 循环时不触发
	event.check_interval = 0.05

	var audio_player = $AudioPlayer
	var trigger = Node.new()
	add_child(trigger)

	var trigger_count = 0
	event.triggered.connect(func(_context):
		trigger_count += 1
	)

	event.initialize(trigger)
	await get_tree().process_frame

	# 模拟音频播放状态变化
	audio_player.play()
	await get_tree().create_timer(0.2).timeout
	assert(trigger_count == 1, "Should trigger once on start")

	# 模拟循环（状态保持 playing）
	audio_player.play(0.5)  # 从中间位置继续播放
	await get_tree().create_timer(0.2).timeout
	assert(trigger_count == 1, "Should not trigger again on loop")

	print("  ✓ Test 2 passed: Loop control works\n")

	event.terminate(trigger)
	trigger.queue_free()

func test_not_triggered_when_already_playing():
	print("Test 3: Not triggered when already playing")

	var event_script = load("res://addons/bricks/events/audio/on_audio_started.gd")
	var event = event_script.new()
	event.audio_player_path = NodePath("AudioPlayer")
	event.check_interval = 0.05

	var audio_player = $AudioPlayer
	var trigger = Node.new()
	add_child(trigger)

	var triggered = false
	event.triggered.connect(func(_context):
		triggered = true
	)

	# 先播放音频
	audio_player.stream = load("res://addons/bricks/tests/test_audio.ogg")
	audio_player.play()
	await get_tree().process_frame

	# 再初始化事件
	event.initialize(trigger)
	await get_tree().create_timer(0.2).timeout

	# 应该不触发（因为已经播放中）
	assert(not triggered, "Should not trigger when audio is already playing")

	print("  ✓ Test 3 passed: No false trigger on already playing audio\n")

	event.terminate(trigger)
	trigger.queue_free()

func cleanup():
	# 清理测试资源
	if $AudioPlayer:
		$AudioPlayer.stop()
```

**Step 5: 验证实现**

运行: 在 Godot 中打开 `test_on_audio_started.tscn` 并按 F5 运行

Expected:
- 所有测试通过
- 控制台输出 "All OnAudioStarted tests passed!"

**Step 6: Commit**

```bash
git add addons/bricks/events/audio/on_audio_started.gd
git add addons/bricks/tests/events/test_on_audio_started.*
git add addons/bricks/localization/translations.csv
git commit -m "feat(audio): add OnAudioStarted event

- 监听 AudioStreamPlayer.playing 属性变化
- 支持循环播放控制 (trigger_on_loop)
- 可配置检测间隔 (check_interval)
- 完整的测试覆盖和本地化支持

Phase 3A: Audio Events - Task 1"
```

---

### Task 2: On Realtime（实时时间）

**优先级**: 🔴 高（时间事件完成度 75%，只差 1 个）

**目录**: `addons/bricks/events/timing/`

**参考**: `on_timer.gd` 的实现模式

**Files:**
- Create: `addons/bricks/events/timing/on_realtime.gd`
- Create: `addons/bricks/tests/events/test_on_realtime.gd`
- Create: `addons/bricks/tests/events/test_on_realtime.tscn`
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 添加本地化翻译**

```csv
# Phase 03 - On Realtime Event
BRICKS_EVENT_ON_REALTIME_NAME,实时时间,Realtime
BRICKS_EVENT_ON_REALTIME_DESC,按实际时间触发（不受 time_scale 影响）,Triggers based on real time (unaffected by time_scale)
BRICKS_LOG_EVENT_REALTIME_TRIGGERED,实时时间事件触发（{timestamp}）,Realtime event triggered (timestamp: {timestamp})
BRICKS_ERROR_REALTIME_INTERVAL_INVALID,间隔必须大于 0（当前值：{interval}）,Interval must be greater than 0 (current: {interval})
```

**Step 2: 创建事件类**

创建 `on_realtime.gd`：

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/Time.svg")
extends BaseEvent
class_name OnRealtime

## 按实际时间触发事件（不受 Engine.time_scale 影响）
##
## 与 OnTimer 不同，此事件使用 OS.get_time() 而非 delta time
## 即使游戏暂停或 time_scale = 0，此事件仍会触发

## 触发间隔（秒）
@export_range(0.1, 3600.0, 0.1) var interval_seconds: float = 1.0:
	set(value):
		interval_seconds = value
		_update_resource_name()

## 最大触发次数（0 = 无限）
@export var max_triggers: int = 0:
	set(value):
		max_triggers = value
		_update_resource_name()

## 是否传递当前时间戳
@export var emit_timestamp: bool = false:
	set(value):
		emit_timestamp = value
		_update_resource_name()

var _timer: Timer = null
var _trigger_count: int = 0
var _owner_node_ref: Node = null

## 更新资源名称（必需）
func _update_resource_name():
	var max_text = max_triggers > 0 ? " (最多 %d 次)" % max_triggers : " (无限)"
	resource_name = "On Realtime: %.1fs%s" % [interval_seconds, max_text]

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	_log_debug_localized("BRICKS_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

	if not owner_node:
		_create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NULL", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_owner_node_ref = owner_node

	# 创建定时器（使用 Timer 的 time_left 不受 time_scale 影响）
	_timer = Timer.new()
	_timer.wait_time = interval_seconds
	_timer.autostart = false
	_timer.timeout.connect(_on_timer_timeout)
	owner_node.add_child(_timer)
	_timer.start()

	_log_debug_localized("BRICKS_LOG_EVENT_TIMER_STARTED", {
		"wait_time": interval_seconds,
		"repeat_count": max_triggers
	})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	if _timer:
		_timer.stop()
		if _timer.timeout.is_connected(_on_timer_timeout):
			_timer.timeout.disconnect(_on_timer_timeout)
		if owner_node and is_instance_valid(owner_node):
			owner_node.remove_child(_timer)
		_timer.queue_free()
		_timer = null

	_trigger_count = 0
	_owner_node_ref = null

	_log_debug_localized("BRICKS_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 定时器超时
func _on_timer_timeout():
	# 检查触发次数限制
	if max_triggers > 0 and _trigger_count >= max_triggers:
		_log_debug_localized("BRICKS_LOG_EVENT_TIMER_REPEAT_LIMIT_REACHED", {"repeat_count": max_triggers})
		_timer.stop()
		return

	_trigger_count += 1

	var timestamp = Time.get_datetime_dict_from_system()
	_log_debug_localized("BRICKS_LOG_EVENT_REALTIME_TRIGGERED", {"timestamp": timestamp})

	var context = _owner_node_ref
	if emit_timestamp:
		context = {"timestamp": timestamp, "node": _owner_node_ref}

	triggered.emit(context)

## 获取事件描述
func get_description() -> String:
	var max_text = max_triggers > 0 ? "，最多 %d 次" % max_triggers : "，无限次"
	return "每 %.1f 秒（实际时间）触发一次%s" % [interval_seconds, max_text]

## 获取事件类型
func get_event_type() -> String:
	return "realtime"

## 获取事件分类
func get_event_category() -> String:
	return "timing"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if interval_seconds <= 0:
		errors.append(tr("BRICKS_ERROR_REALTIME_INTERVAL_INVALID"))

	if max_triggers < 0:
		errors.append("最大触发次数不能为负数")

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	_trigger_count = 0
	if _timer:
		_timer.stop()
		if _owner_node_ref and is_instance_valid(_owner_node_ref):
			_timer.start()
	_log_debug_localized("BRICKS_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "BRICKS_EVENT_ON_REALTIME_NAME"
	metadata.category_key = "BRICKS_EVENT_CATEGORY_TIMER"
	metadata.description_key = "BRICKS_EVENT_ON_REALTIME_DESC"
	metadata.keywords = ["time", "时间", "realtime", "实时", "clock", "时钟", "unscaled", "不受缩放"]
	metadata.builtin_icon = "Time"
	return metadata
```

**Step 3: 创建测试场景和脚本**

创建 `test_on_realtime.tscn` 和 `test_on_realtime.gd`（参考其他测试文件结构）

**Step 4: Commit**

```bash
git add addons/bricks/events/timing/on_realtime.gd
git add addons/bricks/tests/events/test_on_realtime.*
git add addons/bricks/localization/translations.csv
git commit -m "feat(timing): add OnRealtime event

- 基于实际时间触发（不受 time_scale 影响）
- 支持最大触发次数限制
- 可选传递时间戳信息
- 适用于计时器、倒计时等不受游戏暂停影响的功能

Phase 3A: Timing Events - Task 2"
```

---

### Task 3: On Gamepad Axis（游戏手柄轴）

**优先级**: 🔴 高（输入事件完成度 87.5%，只差 4 个）

**目录**: `addons/bricks/events/input/`

**参考**: `on_gamepad_button.gd` 的实现模式

**Files:**
- Create: `addons/bricks/events/input/on_gamepad_axis.gd`
- Create: `addons/bricks/tests/events/test_on_gamepad_axis.gd`
- Create: `addons/bricks/tests/events/test_on_gamepad_axis.tscn`
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 添加本地化翻译**

```csv
# Phase 03 - On Gamepad Axis Event
BRICKS_EVENT_ON_GAMEPAD_AXIS_NAME,游戏手柄轴,Gamepad Axis
BRICKS_EVENT_ON_GAMEPAD_AXIS_DESC,监听游戏手柄轴输入变化,Monitors gamepad axis input changes
BRICKS_LOG_EVENT_GAMEPAD_AXIS_TRIGGERED,手柄轴事件触发：轴 {axis}，值 {value}，{device},Gamepad axis event triggered: axis {axis}, value {value}, {device}
BRICKS_ERROR_AXIS_INDEX_INVALID,轴索引无效（范围：0-5）,Invalid axis index (range: 0-5)
BRICKS_ERROR_AXIS_DEADZONE_INVALID,死区值必须在 0.0 到 1.0 之间,Deadzone value must be between 0.0 and 1.0
```

**Step 2: 创建事件类**

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/JoyAxis.svg")
extends BaseEvent
class_name OnGamepadAxis

## 监听游戏手柄轴输入变化

## 手柄设备索引（-1 = 所有设备）
@export_range(-1, 7) var device_index: int = -1:
	set(value):
		device_index = value
		_update_resource_name()

## 轴索引（0-5）
## 0: 左摇杆 X, 1: 左摇杆 Y, 2: 右摇杆 X, 3: 右摇杆 Y, 4-5: 扳机
@export_range(0, 5) var axis_index: int = 0:
	set(value):
		axis_index = value
		_update_resource_name()

## 触发模式
enum TriggerMode {
	ON_ANY_CHANGE,      ## 任何变化
	ON_THRESHOLD,       ## 超过阈值
	ON_CROSS_ZERO,      ## 穿过零点
}

@export var trigger_mode: TriggerMode = TriggerMode.ON_ANY_CHANGE:
	set(value):
		trigger_mode = value
		_update_resource_name()

## 阈值（用于 ON_THRESHOLD 模式）
@export_range(0.0, 1.0, 0.01) var threshold: float = 0.5:
	set(value):
		threshold = value
		_update_resource_name()

## 死区（0.0-1.0）
@export_range(0.0, 1.0, 0.01) var deadzone: float = 0.1:
	set(value):
		deadzone = value
		_update_resource_name()

var _last_value: float = 0.0
var _owner_node_ref: Node = null

## 更新资源名称（必需）
func _update_resource_name():
	var mode_text = ""
	match trigger_mode:
		TriggerMode.ON_ANY_CHANGE: mode_text = "任何变化"
		TriggerMode.ON_THRESHOLD: mode_text = "阈值 %.2f" % threshold
		TriggerMode.ON_CROSS_ZERO: mode_text = "过零"

	var device_text = device_index >= 0 ? "设备 %d" % device_index : "所有设备"
	resource_name = "手柄轴 %d: %s (%s)" % [axis_index, mode_text, device_text]

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	_log_debug_localized("BRICKS_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

	if not owner_node:
		_create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NULL", BricksError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_owner_node_ref = owner_node

	# 设置输入处理
	_setup_input_processing()

	if not owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.connect(_on_tree_entered)

	_log_debug_localized("BRICKS_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 设置输入处理
func _setup_input_processing():
	if not _owner_node_ref:
		return
	# 注意：Godot 4.x 不需要显式调用 set_process_input

## 当节点进入场景树
func _on_tree_entered():
	_setup_input_processing()

## 输入处理（Godot 4.x 虚拟函数）
func _input(event: InputEvent):
	if not _is_monitoring:
		return

	if not event is InputEventJoypadMotion:
		return

	var axis_event = event as InputEventJoypadMotion

	# 检查设备索引
	if device_index >= 0 and axis_event.device != device_index:
		return

	# 检查轴索引
	if axis_event.axis != axis_index:
		return

	var axis_value = axis_event.axis_value

	# 应用死区
	if abs(axis_value) < deadzone:
		axis_value = 0.0

	# 检查是否应该触发
	if _should_trigger(axis_value):
		_trigger_event(axis_value)

	_last_value = axis_value

## 判断是否应该触发
func _should_trigger(current_value: float) -> bool:
	match trigger_mode:
		TriggerMode.ON_ANY_CHANGE:
			return current_value != _last_value

		TriggerMode.ON_THRESHOLD:
			# 超过阈值时触发
			return abs(current_value) >= threshold and abs(_last_value) < threshold

		TriggerMode.ON_CROSS_ZERO:
			# 穿过零点（正负切换）
			return (current_value >= 0 and _last_value < 0) or (current_value <= 0 and _last_value > 0)

	return false

## 触发事件
func _trigger_event(axis_value: float):
	var device_text = "设备 %d" % device_index if device_index >= 0 else "所有设备"
	_log_debug_localized("BRICKS_LOG_EVENT_GAMEPAD_AXIS_TRIGGERED", {
		"axis": axis_index,
		"value": axis_value,
		"device": device_text
	})

	var context = {
		"axis": axis_index,
		"axis_value": axis_value,
		"device": device_index
	}
	triggered.emit(context)

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	if owner_node and owner_node.tree_entered.is_connected(_on_tree_entered):
		owner_node.tree_entered.disconnect(_on_tree_entered)

	_last_value = 0.0
	_owner_node_ref = null

	_log_debug_localized("BRICKS_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 获取事件描述
func get_description() -> String:
	var mode_text = ""
	match trigger_mode:
		TriggerMode.ON_ANY_CHANGE: mode_text = "任何轴值变化"
		TriggerMode.ON_THRESHOLD: mode_text = "轴值超过 %.2f" % threshold
		TriggerMode.ON_CROSS_ZERO: mode_text = "轴值穿过零点"

	var deadzone_text = deadzone > 0 ? "，死区 %.2f" % deadzone : ""
	return "监听手柄轴 %d 输入：%s%s" % [axis_index, mode_text, deadzone_text]

## 获取事件类型
func get_event_type() -> String:
	return "gamepad_axis"

## 获取事件分类
func get_event_category() -> String:
	return "input"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if axis_index < 0 or axis_index > 5:
		errors.append(tr("BRICKS_ERROR_AXIS_INDEX_INVALID"))

	if deadzone < 0.0 or deadzone > 1.0:
		errors.append(tr("BRICKS_ERROR_AXIS_DEADZONE_INVALID"))

	return errors

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "BRICKS_EVENT_ON_GAMEPAD_AXIS_NAME"
	metadata.category_key = "BRICKS_EVENT_CATEGORY_INPUT"
	metadata.description_key = "BRICKS_EVENT_ON_GAMEPAD_AXIS_DESC"
	metadata.keywords = ["gamepad", "手柄", "joystick", "摇杆", "axis", "轴", "stick", "模拟", "analog"]
	metadata.builtin_icon = "JoyAxis"
	return metadata
```

**Step 3: 创建测试和提交**

（同之前的模式，创建测试文件并 commit）

---

## Phase 3B: 中等难度事件

**目标**: 完成需要更多实现但价值较高的事件

### Task 4: On Touch（触摸事件）

**优先级**: 🟡 中高（移动平台支持）

**目录**: `addons/bricks/events/input/`

**参考**: `on_mouse_button.gd` 的实现模式

**Files:**
- Create: `addons/bricks/events/input/on_touch.gd`
- Create: `addons/bricks/tests/events/test_on_touch.gd`
- Create: `addons/bricks/tests/events/test_on_touch.tscn`
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 添加本地化翻译**

```csv
# Phase 03 - On Touch Event
BRICKS_EVENT_ON_TOUCH_NAME,触摸,Touch
BRICKS_EVENT_ON_TOUCH_DESC,监听触摸屏输入事件,Monitors touchscreen input events
BRICKS_LOG_EVENT_TOUCH_TRIGGERED,触摸事件触发：位置 {position}，索引 {index},Touch event triggered: position {position}, index {index}
BRICKS_ERROR_TOUCH_INDEX_INVALID,触摸索引必须在 0-9 之间,Touch index must be between 0 and 9
```

**Step 2: 实现逻辑**

- 监听 `InputEventScreenTouch` 事件
- 支持多点触控（通过 index 参数）
- 区分按下/释放
- 返回触摸位置和索引

---

### Task 5: On Physics Process（物理帧处理）

**优先级**: 🟡 中（生命周期事件补充）

**目录**: `addons/bricks/events/lifecycle/`

**参考**: `on_process.gd` 的实现模式

**Files:**
- Create: `addons/bricks/events/lifecycle/on_physics_process.gd`
- Create: `addons/bricks/tests/events/test_on_physics_process.gd`
- Create: `addons/bricks/tests/events/test_on_physics_process.tscn`
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 添加本地化翻译**

```csv
# Phase 03 - On Physics Process Event
BRICKS_EVENT_ON_PHYSICS_PROCESS_NAME,物理帧处理,Physics Process
BRICKS_EVENT_ON_PHYSICS_PROCESS_DESC,每物理帧触发（⚠️ 性能影响极大）,Triggers every physics frame (⚠️ extremely high performance impact)
BRICKS_LOG_EVENT_PHYSICS_PROCESS_TRIGGERED,物理帧事件触发（delta: {delta}，间隔: {interval}s）,Physics frame event triggered (delta: {delta}, interval: {interval}s)
BRICKS_ERROR_PHYSICS_PROCESS_INTERVAL_INVALID,执行间隔必须大于 0（当前值：{interval}）,Execution interval must be greater than 0 (current: {interval})
```

**Step 2: 实现逻辑**

- 实现类似 `on_process.gd` 的逻辑
- 但使用 `physics_delta` 而非 `delta`
- 添加性能警告（物理帧更频繁）
- 支持 `execution_interval` 参数

---

## Phase 3C: UI 事件扩展

**目标**: 提升 UI 事件完成度从 50% 到 75%

### Task 6: On Focus Entered/Exited（焦点进入/离开）

**优先级**: 🟡 中（UI 交互完整性）

**目录**: `addons/bricks/events/ui/`

**参考**: `on_mouse_enter.gd` 的实现模式

**Files:**
- Create: `addons/bricks/events/ui/on_focus.gd`（同时支持进入和离开）
- Create: `addons/bricks/tests/events/test_on_focus.gd`
- Create: `addons/bricks/tests/events/test_on_focus.tscn`
- Modify: `addons/bricks/localization/translations.csv`

---

## 开发检查清单

每个事件完成前必须验证：

### 代码质量
- [ ] 所有 `@abstract` 方法已实现
- [ ] `initialize()` 中验证了 `owner_node`
- [ ] `terminate()` 中断开了所有信号
- [ ] `terminate()` 中清理了所有 Timer（stop → disconnect → remove_child → queue_free）
- [ ] 使用 `is_instance_valid()` 检查节点有效性
- [ ] 使用 `is_connected()` 检查信号连接

### 本地化
- [ ] 所有用户可见文本使用 `tr()`
- [ ] 翻译键已添加到 `translations.csv`
- [ ] 日志使用 `_log_*_localized()` 方法
- [ ] 错误使用 `_create_bricks_error_localized()` 方法

### 测试
- [ ] 测试脚本已创建
- [ ] 测试场景已创建
- [ ] 测试覆盖：初始化、触发、清理、边界情况
- [ ] 测试在 Godot 中运行通过

### 文档
- [ ] 事件元数据 `_get_event_metadata()` 已实现
- [ ] `name_key`, `category_key`, `description_key`, `keywords`, `builtin_icon` 全部配置
- [ ] `get_description()` 方法返回有意义的描述
- [ ] `get_event_type()` 返回唯一的类型标识
- [ ] `get_event_category()` 返回正确的分类

### Git
- [ ] 每个事件独立 commit
- [ ] Commit message 遵循约定格式：
  ```
  feat(category): add EventName event

  - 简短描述
  - 关键特性列表

  Phase X: Category - Task N
  ```

---

## 进度跟踪

### Phase 3A: 快速完成（3个事件）
- [ ] Task 1: On Audio Started
- [ ] Task 2: On Realtime
- [ ] Task 3: On Gamepad Axis

### Phase 3B: 中等难度（2个事件）
- [ ] Task 4: On Touch
- [ ] Task 5: On Physics Process

### Phase 3C: UI 事件扩展（1个事件）
- [ ] Task 6: On Focus Entered/Exited

**总计**: 6 个事件

**预期完成度提升**: 45% → ~55%

---

## 下一步

完成此计划后，考虑：
1. 添加动画事件（On Animation Frame Reached, On Animation Blend）
2. 添加场景管理事件（On Scene About To Change）
3. 添加碰撞检测事件（On Raycast Hit）

---

**文档维护**: Bricks 开发团队
**创建日期**: 2026-01-29
**最后更新**: 2026-01-29
**参考**: `@addons/bricks/docs/development/event_creation_guide.md`
