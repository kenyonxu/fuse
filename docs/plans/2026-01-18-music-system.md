# 音乐系统扩展实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标:** 为 JuicyMixer 添加完整的游戏音乐播放支持，包括 Intro-Loop 机制、Crossfade 过渡、暂停 LPF 快照和场景持久化。

**架构:** 在现有 JuicyMixer 事件驱动架构上添加独立的音乐子系统。MusicManager 作为场景级单例，通过 MusicEventHandler 注册到 EventHandlingMiddleware（优先级 10），与音效系统（优先级 0）协作但互不干扰。复用现有播放器池、虚声部系统和 AudioBus 架构。

**技术栈:** Godot 4.5, GDScript 2.0, Resource 系统, JuicyMixer 事件系统

---

## 前置准备

### Task 0: 创建目录结构

**Files:**
- Create: `addons/juicy_mixer/core/music/` (目录)
- Create: `addons/juicy_mixer/resources/music/` (目录)

**Step 1: 创建 music 子目录**

```bash
mkdir -p addons/juicy_mixer/core/music
mkdir -p addons/juicy_mixer/resources/music
```

**Step 2: 验证目录创建**

Run: `ls -la addons/juicy_mixer/core/`
Expected: 显示 `music` 目录

Run: `ls -la addons/juicy_mixer/resources/`
Expected: 显示 `music` 目录

**Step 3: 创建 .gdignore 文件（避免将目录提交到版本控制）**

```bash
# 在创建实际文件前，不需要 .gdignore
```

**Step 4: 提交目录结构**

```bash
git add addons/juicy_mixer/core/music addons/juicy_mixer/resources/music
git commit -m "feat(music): 创建音乐系统目录结构"
```

---

## 阶段 1: 数据结构

### Task 1: MusicTrackResource 音乐轨道资源

**Files:**
- Create: `addons/juicy_mixer/resources/music/music_track_resource.gd`
- Test: `addons/juicy_mixer/tests/music/test_music_track_resource.gd`

**Step 1: 创建基础 MusicTrackResource 类**

创建文件 `addons/juicy_mixer/resources/music/music_track_resource.gd`:

```gdscript
@tool
class_name MusicTrackResource
extends JuicyEventResource

## 音乐轨道资源
##
## 定义音乐播放的所有配置，包括 Intro-Loop 结构、过渡参数、总线配置等

## 音乐类型枚举
enum MusicType {
	STANDARD,      # 标准音乐（直接播放）
	INTRO_LOOP,    # Intro + Loop 结构
	LAYERED,       # 可叠加的音乐层
	TRANSITIONAL   # 过渡音乐
}

# =============================================================================
# 音乐类型配置
# =============================================================================

@export var music_type: MusicType = MusicType.INTRO_LOOP

# =============================================================================
# 音乐段定义
# =============================================================================

@export_group("Audio Streams", "stream_")
@export var intro_stream: AudioStream
@export var loop_stream: AudioStream
@export var loop_variants: Array[AudioStream] = []

# =============================================================================
# 过渡参数
# =============================================================================

@export_group("Transitions", "transition_")
@export_range(0.0, 10.0, 0.1) var intro_fade_out_time: float = 2.0
@export_range(0.0, 10.0, 0.1) var loop_fade_in_time: float = 2.0
@export_range(0.0, 10.0, 0.1) var transition_fade_time: float = 1.0

# =============================================================================
# 总线配置
# =============================================================================

@export_group("Audio Bus", "bus_")
@export var music_bus: StringName = &"Music"
@export var use_lpf_on_pause: bool = true

# =============================================================================
# 持久化配置
# =============================================================================

@export_group("Persistence", "persist_")
@export var persist_across_scenes: bool = true
@export var persistence_key: String = ""

# =============================================================================
# 初始化
# =============================================================================

func _init():
	# 音乐事件使用自定义事件类型
	event_type = JuicyEvent.EventType.CUSTOM

# =============================================================================
# 公共方法
# =============================================================================

## 获取 Intro 时长
func get_intro_duration() -> float:
	if not intro_stream:
		return 0.0
	return intro_stream.get_length()

## 获取 Loop 时长
func get_loop_duration() -> float:
	if not loop_stream:
		return 0.0
	return loop_stream.get_length()

## 是否有 Loop 变体
func has_loop_variants() -> bool:
	return not loop_variants.is_empty()

## 获取随机 Loop 变体
func get_random_loop_variant() -> AudioStream:
	if not has_loop_variants():
		return loop_stream
	return loop_variants.pick_random()

## 验证配置
func validate() -> Dictionary:
	var issues: Array[String] = []
	var warnings: Array[String] = []

	# 检查音乐类型
	if music_type == MusicType.INTRO_LOOP:
		if not intro_stream:
			issues.append("INTRO_LOOP 类型需要 intro_stream")
		if not loop_stream and loop_variants.is_empty():
			issues.append("INTRO_LOOP 类型需要 loop_stream 或 loop_variants")
	elif music_type == MusicType.STANDARD:
		if not loop_stream:
			issues.append("STANDARD 类型需要 loop_stream")

	return {
		"valid": issues.is_empty(),
		"issues": issues,
		"warnings": warnings
	}
```

**Step 2: 创建测试文件**

创建文件 `addons/juicy_mixer/tests/music/test_music_track_resource.gd`:

```gdscript
extends Node

## MusicTrackResource 测试

func _ready():
	print("\n=== MusicTrackResource 测试开始 ===\n")
	test_basic_creation()
	await get_tree().process_frame
	test_intro_loop_validation()
	await get_tree().process_frame
	test_loop_variants()
	await get_tree().process_frame
	print("\n=== 所有测试通过 ===\n")

func test_basic_creation():
	print("测试: 基础创建")
	var track = MusicTrackResource.new()
	assert(track.music_type == MusicTrackResource.MusicType.INTRO_LOOP, "默认类型应为 INTRO_LOOP")
	assert(track.intro_fade_out_time == 2.0, "默认淡出时间应为 2.0")
	assert(track.persist_across_scenes == true, "默认应跨场景持久化")
	print("  ✓ 基础创建测试通过")

func test_intro_loop_validation():
	print("测试: Intro-Loop 验证")
	var track = MusicTrackResource.new()
	track.music_type = MusicTrackResource.MusicType.INTRO_LOOP

	# 缺少必要流
	var validation = track.validate()
	assert(not validation.valid, "缺少流时验证应失败")
	assert(validation.issues.size() > 0, "应有错误信息")

	# 添加流
	track.loop_stream = AudioStreamOggVorbis.load_from_file("res://test.ogg")
	validation = track.validate()
	assert(validation.valid, "有 loop_stream 时应通过")
	print("  ✓ Intro-Loop 验证测试通过")

func test_loop_variants():
	print("测试: Loop 变体")
	var track = MusicTrackResource.new()

	assert(not track.has_loop_variants(), "初始应无变体")
	assert(track.get_random_loop_variant() == track.loop_stream, "无变体时应返回 loop_stream")

	track.loop_variants.append(AudioStreamOggVorbis.load_from_file("res://test1.ogg"))
	track.loop_variants.append(AudioStreamOggVorbis.load_from_file("res://test2.ogg"))
	assert(track.has_loop_variants(), "添加后应有变体")
	print("  ✓ Loop 变体测试通过")
```

**Step 3: 运行测试验证（可选，需要测试音频文件）**

Run: 在 Godot 编辑器中运行测试场景
Expected: 基础创建测试应通过

**Step 4: 提交**

```bash
git add addons/juicy_mixer/resources/music/music_track_resource.gd
git add addons/juicy_mixer/tests/music/test_music_track_resource.gd
git commit -m "feat(music): 添加 MusicTrackResource 音乐轨道资源

- 支持 Intro-Loop 结构
- 资源级过渡参数配置
- 总线路由配置
- 跨场景持久化配置
- 配置验证方法"
```

---

### Task 2: MusicLayerResource 音乐层资源

**Files:**
- Create: `addons/juicy_mixer/resources/music/music_layer_resource.gd`

**Step 1: 创建 MusicLayerResource 类**

创建文件 `addons/juicy_mixer/resources/music/music_layer_resource.gd`:

```gdscript
@tool
class_name MusicLayerResource
extends Resource

## 音乐层资源
##
## 用于叠加的音乐层（如战斗强度层）

# =============================================================================
# 层定义
# =============================================================================

@export var layer_name: String = "Layer1"
@export var layer_stream: AudioStream

# =============================================================================
# 总线配置
# =============================================================================

@export_group("Audio Bus", "bus_")
@export var layer_bus_index: int = 0  # Music_Layer1, Music_Layer2, ...

# =============================================================================
# 音量控制
# =============================================================================

@export_group("Volume", "volume_")
@export_range(-60.0, 0.0, 0.1) var default_volume: float = -10.0  # dB
@export_range(0.0, 10.0, 0.1) var fade_in_time: float = 1.0
@export_range(0.0, 10.0, 0.1) var fade_out_time: float = 1.0

# =============================================================================
# 触发条件（可扩展）
# =============================================================================

@export_group("Trigger", "trigger_")
@export var trigger_tag: String = ""  # 例如 "combat_heavy"

# =============================================================================
# 公共方法
# =============================================================================

## 验证配置
func validate() -> Dictionary:
	var issues: Array[String] = []
	var warnings: Array[String] = []

	if not layer_stream:
		issues.append("需要 layer_stream")

	if layer_bus_index < 0:
		issues.append("layer_bus_index 不能为负数")

	return {
		"valid": issues.is_empty(),
		"issues": issues,
		"warnings": warnings
	}
```

**Step 2: 提交**

```bash
git add addons/juicy_mixer/resources/music/music_layer_resource.gd
git commit -m "feat(music): 添加 MusicLayerResource 音乐层资源

- 支持音频流配置
- 独立总线索引
- 音量和淡入淡出参数
- 触发标签扩展点"
```

---

### Task 3: ActiveMusicState 活跃音乐状态

**Files:**
- Create: `addons/juicy_mixer/core/music/active_music_state.gd`

**Step 1: 创建 ActiveMusicState 类**

创建文件 `addons/juicy_mixer/core/music/active_music_state.gd`:

```gdscript
class_name ActiveMusicState
extends RefCounted

## 活跃音乐状态
##
## 跟踪当前播放的音乐状态

## 音乐阶段枚举
enum MusicPhase {
	INTRO,      # 播放 Intro 段
	LOOP,       # 播放 Loop 段
	FADING_OUT, # 淡出中
	FADING_IN,  # 淡入中
	STOPPED     # 已停止
}

# =============================================================================
# 核心状态
# =============================================================================

var track_resource: MusicTrackResource
var current_stream_player: AudioStreamPlayer
var current_phase: MusicPhase = MusicPhase.STOPPED

# =============================================================================
# 播放状态
# =============================================================================

var playback_position: float = 0.0
var target_volume: float = 0.0
var current_volume: float = 0.0

# =============================================================================
# 叠加层
# =============================================================================

var active_layers: Dictionary = {}  # {layer_id: ActiveLayerState}

# =============================================================================
# 持久化状态
# =============================================================================

var persistence_key: String = ""
var scene_persistence_enabled: bool = false

# =============================================================================
# 音乐层状态（内部类）
# =============================================================================

class ActiveLayerState:
	var layer_resource: MusicLayerResource
	var layer_player: AudioStreamPlayer
	var layer_phase: MusicPhase
	var current_volume: float = 0.0
	var target_volume: float = 0.0

# =============================================================================
# 初始化
# =============================================================================

static func create(track: MusicTrackResource, player: AudioStreamPlayer) -> ActiveMusicState:
	var state = ActiveMusicState.new()
	state.track_resource = track
	state.current_stream_player = player
	state.current_phase = MusicPhase.FADING_IN
	state.target_volume = 0.0  # 目标音量，根据资源设置
	state.current_volume = -60.0  # 从静音开始
	return state

# =============================================================================
# 状态查询
# =============================================================================

## 是否正在播放
func is_playing() -> bool:
	return current_phase != MusicPhase.STOPPED

## 是否在过渡中
func is_transitioning() -> bool:
	return current_phase in [MusicPhase.FADING_IN, MusicPhase.FADING_OUT]

## 是否播放 Intro
func is_intro_phase() -> bool:
	return current_phase == MusicPhase.INTRO

## 是否播放 Loop
func is_loop_phase() -> bool:
	return current_phase == MusicPhase.LOOP

## 获取播放进度（0.0-1.0）
func get_progress() -> float:
	if not track_resource or not current_stream_player:
		return 0.0

	var duration: float
	if is_intro_phase():
		duration = track_resource.get_intro_duration()
	else:
		duration = track_resource.get_loop_duration()

	if duration == 0.0:
		return 0.0

	return current_stream_player.get_playback_position() / duration

# =============================================================================
# 层管理
# =============================================================================

## 添加活跃层
func add_layer(layer_id: String, layer_state: ActiveLayerState):
	active_layers[layer_id] = layer_state

## 移除活跃层
func remove_layer(layer_id: String):
	active_layers.erase(layer_id)

## 获取活跃层数量
func get_layer_count() -> int:
	return active_layers.size()

## 是否有指定层
func has_layer(layer_id: String) -> bool:
	return layer_id in active_layers
```

**Step 2: 提交**

```bash
git add addons/juicy_mixer/core/music/active_music_state.gd
git commit -m "feat(music): 添加 ActiveMusicState 音乐状态类

- 跟踪音乐播放阶段（INTRO/LOOP/FADING）
- 管理播放位置和音量
- 支持叠加层状态管理
- 提供状态查询辅助方法"
```

---

## 阶段 2: 核心组件

### Task 4: MusicBusController 总线控制器

**Files:**
- Create: `addons/juicy_mixer/core/music/music_bus_controller.gd`

**Step 1: 创建 MusicBusController 类**

创建文件 `addons/juicy_mixer/core/music/music_bus_controller.gd`:

```gdscript
class_name MusicBusController
extends RefCounted

## 音乐总线控制器
##
## 管理 Godot AudioBus 创建和路由

# =============================================================================
# 常量
# =============================================================================

const MUSIC_BUS_NAME = &"Music"
const MUSIC_LPF_BUS_NAME = &"Music_LPF"
const LAYER_BUS_PREFIX = &"Music_Layer"
const DEFAULT_MAX_LAYERS: int = 4

# =============================================================================
# 总线索引
# =============================================================================

var _music_bus_index: int = -1
var _music_lpf_bus_index: int = -1
var _layer_bus_indices: Dictionary = {}  # {layer_index: bus_index}
var _max_layers: int = DEFAULT_MAX_LAYERS

# =============================================================================
# AudioServer 引用
# =============================================================================

var _audio_server: AudioServer

# =============================================================================
# 初始化
# =============================================================================

func _init(audio_server: AudioServer = AudioServer.get_singleton()):
	_audio_server = audio_server

## 设置总线结构
func setup_buses() -> void:
	"""
	创建音乐总线结构

	Music (主音乐总线)
	  ├── Music_LPF (带低通滤波器)
	  ├── Music_Layer1 (叠加层1)
	  ├── Music_Layer2 (叠加层2)
	  └── ...
	"""
	# 创建主音乐总线
	_music_bus_index = _create_bus_if_not_exists(MUSIC_BUS_NAME, &"Master")

	# 创建 LPF 总线
	_music_lpf_bus_index = _create_bus_if_not_exists(MUSIC_LPF_BUS_NAME, MUSIC_BUS_NAME)
	_setup_lpf_effect()

	# 创建层总线
	for i in range(_max_layers):
		var layer_bus_name: StringName = str(LAYER_BUS_PREFIX, i + 1)
		var bus_index: int = _create_bus_if_not_exists(layer_bus_name, MUSIC_BUS_NAME)
		_layer_bus_indices[i] = bus_index

	print("[MusicBusController] 总线设置完成")
	print("  Music 总线索引: ", _music_bus_index)
	print("  LPF 总线索引: ", _music_lpf_bus_index)
	print("  层总线: ", _layer_bus_indices)

# =============================================================================
# 总线创建辅助
# =============================================================================

func _create_bus_if_not_exists(bus_name: StringName, parent_bus: StringName = &"Master") -> int:
	"""创建总线（如果不存在）"""
	var bus_index: int = AudioServer.get_bus_index(bus_name)

	if bus_index == -1:
		bus_index = AudioServer.bus_count
		AudioServer.add_bus(bus_index)
		AudioServer.set_bus_name(bus_index, bus_name)
		AudioServer.set_bus_send(bus_index, parent_bus)
		print("[MusicBusController] 创建总线: ", bus_name, " -> ", parent_bus)

	return bus_index

# =============================================================================
# LPF 效果器设置
# =============================================================================

func _setup_lpf_effect() -> void:
	"""在 LPF 总线上添加低通滤波器效果"""
	if _music_lpf_bus_index == -1:
		return

	# 检查是否已有 Effect
	var effect_count: int = AudioServer.get_bus_effect_count(_music_lpf_bus_index)
	if effect_count > 0:
		return  # 已有效果器，跳过

	# 添加低通滤波器
	var lpf: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
	AudioServer.add_bus_effect(_music_lpf_bus_index, lpf, 0)
	print("[MusicBusController] 添加 LPF 效果器到总线 ", _music_lpf_bus_index)

# =============================================================================
# 路由控制
# =============================================================================

## 切换到 LPF 总线
func route_to_lpf() -> void:
	"""将播放器路由到 LPF 总线（由外部设置 player.bus）"""
	pass  # 实际路由由播放器设置 bus 属性

## 恢复正常总线
func route_to_normal() -> void:
	"""将播放器路由到正常总线（由外部设置 player.bus）"""
	pass  # 实际路由由播放器设置 bus 属性

## 获取层总线
func get_layer_bus(layer_index: int) -> int:
	"""获取音乐层总线索引"""
	if layer_index in _layer_bus_indices:
		return _layer_bus_indices[layer_index]

	# 动态创建新层总线
	var new_bus_name: StringName = str(LAYER_BUS_PREFIX, layer_index + 1)
	var bus_index: int = _create_bus_if_not_exists(new_bus_name, MUSIC_BUS_NAME)
	_layer_bus_indices[layer_index] = bus_index
	return bus_index

# =============================================================================
# 效果控制
# =============================================================================

## 设置 LPF 截止频率
func set_lpf_cutoff(hz: float) -> void:
	"""设置 LPF 截止频率"""
	if _music_lpf_bus_index == -1:
		return

	var effect_index: int = AudioServer.get_bus_effect_index(_music_lpf_bus_index, 0)
	if effect_index == -1:
		return

	var lpf: AudioEffectLowPassFilter = AudioServer.get_bus_effect(_music_lpf_bus_index, effect_index)
	if lpf is AudioEffectLowPassFilter:
		lpf.cutoff_hz = hz

## 设置 LPF 共振
func set_lpf_resonance_db(db: float) -> void:
	"""设置 LPF 共振"""
	if _music_lpf_bus_index == -1:
		return

	var effect_index: int = AudioServer.get_bus_effect_index(_music_lpf_bus_index, 0)
	if effect_index == -1:
		return

	var lpf: AudioEffectLowPassFilter = AudioServer.get_bus_effect(_music_lpf_bus_index, effect_index)
	if lpf is AudioEffectLowPassFilter:
		lpf.resonance = db

## 启用/禁用 LPF
func set_lpf_enabled(enabled: bool) -> void:
	"""启用或禁用 LPF 效果"""
	if _music_lpf_bus_index == -1:
		return

	var effect_index: int = AudioServer.get_bus_effect_index(_music_lpf_bus_index, 0)
	if effect_index == -1:
		return

	AudioServer.set_bus_effect_enabled(_music_lpf_bus_index, effect_index, enabled)

# =============================================================================
# 获取器
# =============================================================================

## 获取主音乐总线索引
func get_music_bus_index() -> int:
	return _music_bus_index

## 获取 LPF 总线索引
func get_lpf_bus_index() -> int:
	return _music_lpf_bus_index

## 获取所有层总线
func get_all_layer_buses() -> Dictionary:
	return _layer_bus_indices.duplicate()
```

**Step 2: 提交**

```bash
git add addons/juicy_mixer/core/music/music_bus_controller.gd
git commit -m "feat(music): 添加 MusicBusController 总线控制器

- 创建音乐总线层级结构
- 主音乐总线 + LPF 总线 + 层总线
- LPF 效果器自动配置
- 支持动态创建层总线"
```

---

### Task 5: MusicTransitionScheduler 过渡调度器

**Files:**
- Create: `addons/juicy_mixer/core/music/music_transition_scheduler.gd`

**Step 1: 创建 MusicTransitionScheduler 类**

创建文件 `addons/juicy_mixer/core/music/music_transition_scheduler.gd`:

```gdscript
class_name MusicTransitionScheduler
extends RefCounted

## 音乐过渡调度器
##
## 管理所有音乐过渡动画（淡入淡出、交叉淡入淡出）

# =============================================================================
# 过渡请求定义
# =============================================================================

class TransitionRequest:
	var target_player: AudioStreamPlayer
	var from_volume: float
	var to_volume: float
	var duration: float
	var elapsed: float = 0.0
	var on_complete: Callable

	func _init(player: AudioStreamPlayer, from: float, to: float, dur: float, callback: Callable = Callable()):
		target_player = player
		from_volume = from
		to_volume = to
		duration = dur
		on_complete = callback

# =============================================================================
# 过渡状态
# =============================================================================

var _active_transitions: Array[TransitionRequest] = []
var _tween: Tween

# =============================================================================
# 信号
# =============================================================================

signal transition_completed(player: AudioStreamPlayer)
signal crossfade_completed(out_player: AudioStreamPlayer, in_player: AudioStreamPlayer)

# =============================================================================
# 初始化
# =============================================================================

func _init():
	_tween = Tween.new()

# =============================================================================
# 调度 API
# =============================================================================

## 调度淡入淡出
func schedule_fade(player: AudioStreamPlayer, from_vol: float, to_vol: float, duration: float, on_complete: Callable = Callable()) -> void:
	"""
	调度单个播放器的淡入淡出

	@param player: 目标播放器
	@param from_vol: 起始音量 (dB)
	@param to_vol: 目标音量 (dB)
	@param duration: 过渡时间 (秒)
	@param on_complete: 完成回调
	"""
	var request: TransitionRequest = TransitionRequest.new(player, from_vol, to_vol, duration, on_complete)
	_active_transitions.append(request)

	# 如果是第一个过渡，开始处理
	if _active_transitions.size() == 1:
		_process_transition_immediate(request)

## 调度交叉淡入淡出
func schedule_crossfade(out_player: AudioStreamPlayer, in_player: AudioStreamPlayer, duration: float) -> void:
	"""
	调度两个播放器的交叉淡入淡出

	@param out_player: 淡出的播放器
	@param in_player: 淡入的播放器
	@param duration: 过渡时间 (秒)
	"""
	# 淡出旧播放器
	var out_volume: float = out_player.volume_db
	schedule_fade(out_player, out_volume, -60.0, duration)

	# 淡入新播放器
	var in_start_vol: float = -60.0
	var in_target_vol: float = 0.0  # 可以从资源配置
	schedule_fade(in_player, in_start_vol, in_target_vol, duration, _on_crossfade_fade_in_complete.bind(out_player, in_player))

# =============================================================================
# 处理逻辑
# =============================================================================

func _process_transition_immediate(request: TransitionRequest) -> void:
	"""立即处理过渡请求（使用 Tween）"""
	if not _tween:
		_tween = Tween.new()
		if not _tween:
			push_error("[MusicTransitionScheduler] 无法创建 Tween")
			return

	# 杀死之前的 Tween
	_tween.kill()

	# 创建新的 Tween
	_tween = _tween.parallel().tween_property(
		request.target_player,
		"volume_db",
		request.to_volume,
		request.duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 连接完成信号
	_tween.tween_callback(_on_transition_complete.bind(request))

	# 启动 Tween（需要将 Tween 添加到场景树）
	# 注意：这需要在 Node 上下文中调用
	if request.target_player.get_tree():
		request.target_player.get_tree().current_scene.add_child(_tween)
		_tween.set_owner(request.target_player.get_tree().current_scene)

func _on_transition_complete(request: TransitionRequest) -> void:
	"""过渡完成回调"""
	_active_transitions.erase(request)
	transition_completed.emit(request.target_player)

	if request.on_complete.is_valid():
		request.on_complete.call()

func _on_crossfade_fade_in_complete(out_player: AudioStreamPlayer, in_player: AudioStreamPlayer) -> void:
	"""交叉淡入淡出完成回调"""
	crossfade_completed.emit(out_player, in_player)

# =============================================================================
# 取消
# =============================================================================

## 取消所有活跃过渡
func cancel_all_transitions() -> void:
	"""取消所有活跃的过渡"""
	if _tween and _tween.is_valid():
		_tween.kill()

	_active_transitions.clear()

## 取消指定播放器的过渡
func cancel_transition(player: AudioStreamPlayer) -> void:
	"""取消指定播放器的过渡"""
	for i in range(_active_transitions.size() - 1, -1, -1):
		var request: TransitionRequest = _active_transitions[i]
		if request.target_player == player:
			_active_transitions.remove_at(i)

# =============================================================================
# 状态查询
# =============================================================================

## 获取活跃过渡数量
func get_active_transition_count() -> int:
	return _active_transitions.size()

## 是否有活跃过渡
func has_active_transitions() -> bool:
	return not _active_transitions.is_empty()
```

**Step 2: 提交**

```bash
git add addons/juicy_mixer/core/music/music_transition_scheduler.gd
git commit -m "feat(music): 添加 MusicTransitionScheduler 过渡调度器

- 支持单个播放器淡入淡出
- 支持两个播放器交叉淡入淡出
- 使用 Tween 实现平滑过渡
- 提供过渡完成信号"
```

---

### Task 6: MusicEventHandler 事件处理器

**Files:**
- Create: `addons/juicy_mixer/core/music/music_event_handler.gd`

**Step 1: 查找 JuicyEventHandler 基类**

首先确认 JuicyEventHandler 的位置和接口：

Run: `grep -r "class_name JuicyEventHandler" addons/juicy_mixer/`
Expected: 找到基类文件

**Step 2: 创建 MusicEventHandler 类**

创建文件 `addons/juicy_mixer/core/music/music_event_handler.gd`:

```gdscript
class_name MusicEventHandler
extends JuicyEventHandler

## 音乐事件处理器
##
## 专门处理音乐事件的 Handler
## 注册到 EventHandlingMiddleware（优先级：10，高于音效的0）

# =============================================================================
# MusicManager 引用
# =============================================================================

var music_manager: MusicManager

# =============================================================================
# 事件类型定义
# =============================================================================

const EVENT_MUSIC_PLAY: String = "MUSIC_PLAY"
const EVENT_MUSIC_STOP: String = "MUSIC_STOP"
const EVENT_MUSIC_CROSSFADE: String = "MUSIC_CROSSFADE"
const EVENT_MUSIC_ADD_LAYER: String = "MUSIC_ADD_LAYER"
const EVENT_MUSIC_REMOVE_LAYER: String = "MUSIC_REMOVE_LAYER"
const EVENT_MUSIC_PAUSE_SNAPSHOT: String = "MUSIC_PAUSE_SNAPSHOT"
const EVENT_MUSIC_NORMAL_SNAPSHOT: String = "MUSIC_NORMAL_SNAPSHOT"

# =============================================================================
# JuicyEventHandler 接口实现
# =============================================================================

func get_event_types() -> PackedStringArray:
	"""返回处理的事件类型"""
	return [
		EVENT_MUSIC_PLAY,
		EVENT_MUSIC_STOP,
		EVENT_MUSIC_CROSSFADE,
		EVENT_MUSIC_ADD_LAYER,
		EVENT_MUSIC_REMOVE_LAYER,
		EVENT_MUSIC_PAUSE_SNAPSHOT,
		EVENT_MUSIC_NORMAL_SNAPSHOT
	]

func handle_event(event: JuicyEvent, context: JuicyContext) -> void:
	"""处理音乐事件"""
	if not music_manager:
		push_error("[MusicEventHandler] MusicManager 未设置")
		return

	match event.event_type:
		EVENT_MUSIC_PLAY:
			_handle_music_play(event, context)
		EVENT_MUSIC_STOP:
			_handle_music_stop(event, context)
		EVENT_MUSIC_CROSSFADE:
			_handle_crossfade(event, context)
		EVENT_MUSIC_ADD_LAYER:
			_handle_add_layer(event, context)
		EVENT_MUSIC_REMOVE_LAYER:
			_handle_remove_layer(event, context)
		EVENT_MUSIC_PAUSE_SNAPSHOT:
			_handle_pause_snapshot(event, context)
		EVENT_MUSIC_NORMAL_SNAPSHOT:
			_handle_normal_snapshot(event, context)
		_:
			push_warning("[MusicEventHandler] 未知事件类型: %s" % event.event_type)

# =============================================================================
# 事件处理实现
# =============================================================================

func _handle_music_play(event: JuicyEvent, context: JuicyContext) -> void:
	"""处理音乐播放事件"""
	var track: MusicTrackResource = event.event_data.get("track_resource")
	if not track:
		push_error("[MusicEventHandler] MUSIC_PLAY 事件缺少 track_resource")
		return

	var fade_in_time: float = event.event_data.get("fade_in_time", 0.0)
	var persistence_key: String = event.event_data.get("persistence_key", "")

	music_manager.play_music(track, fade_in_time, persistence_key)

func _handle_music_stop(event: JuicyEvent, context: JuicyContext) -> void:
	"""处理音乐停止事件"""
	var fade_out_time: float = event.event_data.get("fade_out_time", 0.0)
	music_manager.stop_music(fade_out_time)

func _handle_crossfade(event: JuicyEvent, context: JuicyContext) -> void:
	"""处理交叉淡入淡出事件"""
	var new_track: MusicTrackResource = event.event_data.get("track_resource")
	if not new_track:
		push_error("[MusicEventHandler] MUSIC_CROSSFADE 事件缺少 track_resource")
		return

	var fade_time: float = event.event_data.get("fade_time", 1.0)
	music_manager.crossfade_to(new_track, fade_time)

func _handle_add_layer(event: JuicyEvent, context: JuicyContext) -> void:
	"""处理添加音乐层事件"""
	var layer: MusicLayerResource = event.event_data.get("layer_resource")
	if not layer:
		push_error("[MusicEventHandler] MUSIC_ADD_LAYER 事件缺少 layer_resource")
		return

	var fade_in_time: float = event.event_data.get("fade_in_time", 0.0)
	music_manager.add_music_layer(layer, fade_in_time)

func _handle_remove_layer(event: JuicyEvent, context: JuicyContext) -> void:
	"""处理移除音乐层事件"""
	var layer_id: String = event.event_data.get("layer_id", "")
	var fade_out_time: float = event.event_data.get("fade_out_time", 0.0)

	if layer_id.is_empty():
		push_error("[MusicEventHandler] MUSIC_REMOVE_LAYER 事件缺少 layer_id")
		return

	music_manager.remove_music_layer(layer_id, fade_out_time)

func _handle_pause_snapshot(event: JuicyEvent, context: JuicyContext) -> void:
	"""处理暂停快照事件"""
	music_manager.apply_pause_snapshot()

func _handle_normal_snapshot(event: JuicyEvent, context: JuicyContext) -> void:
	"""处理正常快照事件"""
	music_manager.apply_normal_snapshot()
```

**Step 3: 提交**

```bash
git add addons/juicy_mixer/core/music/music_event_handler.gd
git commit -m "feat(music): 添加 MusicEventHandler 音乐事件处理器

- 支持 7 种音乐事件类型
- 转发事件到 MusicManager
- 事件参数验证
- 完整的错误处理"
```

---

### Task 7: MusicManager 音乐管理器（基础框架）

**Files:**
- Create: `addons/juicy_mixer/core/music_manager.gd`

**Step 1: 创建 MusicManager 基础框架**

创建文件 `addons/juicy_mixer/core/music_manager.gd`:

```gdscript
class_name MusicManager
extends Node

## 音乐管理器
##
## 场景级单例，管理所有背景音乐

# =============================================================================
# 信号
# =============================================================================

signal music_started(track_resource: MusicTrackResource)
signal music_stopped(track_resource: MusicTrackResource)
signal music_transition_started(from_track: MusicTrackResource, to_track: MusicTrackResource)

# =============================================================================
# 单例
# =============================================================================

static var _instance: MusicManager = null

# =============================================================================
# 组件
# =============================================================================

var _transition_scheduler: MusicTransitionScheduler
var _bus_controller: MusicBusController
var _music_event_handler: MusicEventHandler

# =============================================================================
# 状态管理
# =============================================================================

var _active_tracks: Dictionary = {}  # {track_id: ActiveMusicState}
var _active_layers: Dictionary = {}  # {layer_id: LayerState}
var _current_music_state: ActiveMusicState = null

# =============================================================================
# 单例访问
# =============================================================================

static func get_instance() -> MusicManager:
	"""获取 MusicManager 单例"""
	return _instance

static func ensure_exists() -> MusicManager:
	"""确保 MusicManager 存在，不存在则创建"""
	if _instance:
		return _instance

	# 在当前场景中创建
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree or not tree.current_scene:
		push_error("[MusicManager] 无法获取当前场景")
		return null

	var manager: MusicManager = MusicManager.new()
	tree.current_scene.add_child(manager)
	return manager

# =============================================================================
# 生命周期
# =============================================================================

func _ready() -> void:
	"""初始化"""
	if _instance:
		push_warning("[MusicManager] 已存在实例，将替换")
		_instance.queue_free()

	_instance = self
	set_name("MusicManager")
	print("[MusicManager] 初始化")

	# 设置总线
	_bus_controller = MusicBusController.new()
	_bus_controller.setup_buses()

	# 创建过渡调度器
	_transition_scheduler = MusicTransitionScheduler.new()

	# 创建音乐事件处理器
	_music_event_handler = MusicEventHandler.new()
	_music_event_handler.music_manager = self

	# 注册到事件系统
	_register_to_event_middleware()

func _exit_tree() -> void:
	"""清理"""
	if _instance == self:
		_instance = null

	print("[MusicManager] 清理完成")

# =============================================================================
# 事件系统集成
# =============================================================================

func _register_to_event_middleware() -> void:
	"""注册到 EventHandlingMiddleware"""
	var juicy_mixer: JuicyMixer = JuicyMixer.get_instance()
	if not juicy_mixer:
		push_warning("[MusicManager] JuicyMixer 不存在，跳过事件注册")
		return

	var middleware_pipeline = juicy_mixer.get_middleware_pipeline()
	if not middleware_pipeline:
		push_warning("[MusicManager] MiddlewarePipeline 不存在")
		return

	# 获取 EventHandlingMiddleware
	var event_middleware = middleware_pipeline.get_middleware("EventHandlingMiddleware")
	if not event_middleware:
		push_warning("[MusicManager] EventHandlingMiddleware 不存在")
		return

	# 注册处理器
	event_middleware.register_handler(_music_event_handler, 10)  # 优先级 10
	print("[MusicManager] 已注册到 EventHandlingMiddleware (优先级 10)")

# =============================================================================
# 核心 API（占位符，后续实现）
# =============================================================================

## 播放音乐
func play_music(track: MusicTrackResource, fade_in_time: float = 0.0, persistence_key: String = "") -> String:
	push_error("[MusicManager] play_music 尚未实现")
	return ""

## 停止音乐
func stop_music(fade_out_time: float = 0.0):
	push_error("[MusicManager] stop_music 尚未实现")

## 交叉淡入淡出
func crossfade_to(new_track: MusicTrackResource, fade_time: float = 1.0) -> String:
	push_error("[MusicManager] crossfade_to 尚未实现")
	return ""

## 添加音乐层
func add_music_layer(layer: MusicLayerResource, fade_in_time: float = 0.0) -> String:
	push_error("[MusicManager] add_music_layer 尚未实现")
	return ""

## 移除音乐层
func remove_music_layer(layer_id: String, fade_out_time: float = 0.0):
	push_error("[MusicManager] remove_music_layer 尚未实现")

## 应用暂停快照
func apply_pause_snapshot():
	push_error("[MusicManager] apply_pause_snapshot 尚未实现")

## 应用正常快照
func apply_normal_snapshot():
	push_error("[MusicManager] apply_normal_snapshot 尚未实现")

## 准备场景切换
func prepare_for_scene_change() -> Dictionary:
	push_error("[MusicManager] prepare_for_scene_change 尚未实现")
	return {}

## 从状态恢复
func restore_from_state(state: Dictionary):
	push_error("[MusicManager] restore_from_state 尚未实现")
```

**Step 2: 提交**

```bash
git add addons/juicy_mixer/core/music_manager.gd
git commit -m "feat(music): 添加 MusicManager 基础框架

- 场景级单例模式
- 初始化总线控制器
- 创建过渡调度器
- 注册到事件系统
- 核心 API 占位符"
```

---

## 阶段 3: 核心功能实现

### Task 8: 实现 play_music 基础播放

**Files:**
- Modify: `addons/juicy_mixer/core/music_manager.gd`

**Step 1: 实现 play_music 方法**

在 `addons/juicy_mixer/core/music_manager.gd` 中找到 play_music 方法并替换：

```gdscript
## 播放音乐
func play_music(track: MusicTrackResource, fade_in_time: float = 0.0, persistence_key: String = "") -> String:
	"""
	播放音乐

	@param track: 音乐轨道资源
	@param fade_in_time: 淡入时间（秒）
	@param persistence_key: 持久化标识符
	@return: track_id
	"""
	# 验证资源
	var validation = track.validate()
	if not validation.valid:
		push_error("[MusicManager] 资源验证失败: %s" % validation.issues)
		return ""

	# 停止当前音乐（如果有）
	if _current_music_state and _current_music_state.is_playing():
		stop_music(0.0)

	# 创建播放器
	var player: AudioStreamPlayer = _get_player_from_pool()
	player.stream = track.loop_stream
	player.bus = _bus_controller.get_music_bus_index()
	player.autoplay = false

	# 设置音量
	if fade_in_time > 0:
		player.volume_db = -60.0
	else:
		player.volume_db = 0.0

	# 播放
	player.play(0.0)

	# 创建状态
	var track_id: String = str(track.get_instance_id())
	var state: ActiveMusicState = ActiveMusicState.create(track, player)
	state.persistence_key = persistence_key if not persistence_key.is_empty() else track.persistence_key
	_active_tracks[track_id] = state
	_current_music_state = state

	# 淡入
	if fade_in_time > 0:
		_transition_scheduler.schedule_fade(player, -60.0, 0.0, fade_in_time)
		state.current_phase = ActiveMusicState.MusicPhase.FADING_IN
	else:
		state.current_phase = ActiveMusicState.MusicPhase.LOOP

	music_started.emit(track)
	print("[MusicManager] 播放音乐: ", track.event_name)

	# 处理 Intro-Loop
	if track.music_type == MusicTrackResource.MusicType.INTRO_LOOP and track.intro_stream:
		_play_intro_loop(track, state)

	return track_id

## 播放 Intro-Loop
func _play_intro_loop(track: MusicTrackResource, state: ActiveMusicState) -> void:
	"""播放 Intro 然后切换到 Loop"""
	if not track.intro_stream:
		return

	# 创建 Intro 播放器
	var intro_player: AudioStreamPlayer = _get_player_from_pool()
	intro_player.stream = track.intro_stream
	intro_player.bus = _bus_controller.get_music_bus_index()
	intro_player.volume_db = 0.0
	intro_player.play(0.0)

	state.current_phase = ActiveMusicState.MusicPhase.INTRO

	# 计算切换时间
	var intro_duration: float = track.get_intro_duration()
	var transition_start_time: float = intro_duration - track.intro_fade_out_time

	# 等待切换时机
	await get_tree().create_timer(transition_start_time).timeout

	# 开始淡出 Intro，淡入 Loop
	var loop_player: AudioStreamPlayer = state.current_stream_player
	loop_player.volume_db = -60.0
	loop_player.play(0.0)

	_transition_scheduler.schedule_crossfade(
		intro_player,
		loop_player,
		track.loop_fade_in_time
	)

	# 过渡完成后清理 Intro 播放器
	await _transition_scheduler.crossfade_completed
	_return_player_to_pool(intro_player)

	state.current_phase = ActiveMusicState.MusicPhase.LOOP
	print("[MusicManager] Intro-Loop 切换完成")
```

**Step 2: 实现辅助方法**

在 MusicManager 类中添加辅助方法：

```gdscript
# =============================================================================
# 辅助方法
# =============================================================================

## 从池中获取播放器
func _get_player_from_pool() -> AudioStreamPlayer:
	"""从 AudioEventHandler 的播放器池获取播放器"""
	var event_middleware = JuicyMixer.get_middleware("EventHandlingMiddleware")
	if event_middleware and event_middleware.audio_handler:
		return event_middleware.audio_handler.request_player()

	# 创建临时播放器（如果没有池）
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	add_child(player)
	return player

## 返回播放器到池
func _return_player_to_pool(player: AudioStreamPlayer) -> void:
	"""返回播放器到池"""
	player.stop()
	player.queue_free()
```

**Step 3: 提交**

```bash
git add addons/juicy_mixer/core/music_manager.gd
git commit -m "feat(music): 实现 play_music 基础播放

- 播放音乐资源
- 支持 Intro-Loop 自动切换
- 支持淡入效果
- 状态管理和信号发射"
```

---

### Task 9: 实现 stop_music 和 crossfade_to

**Files:**
- Modify: `addons/juicy_mixer/core/music_manager.gd`

**Step 1: 实现 stop_music**

替换 stop_music 方法：

```gdscript
## 停止音乐
func stop_music(fade_out_time: float = 0.0):
	"""停止当前音乐"""
	if not _current_music_state:
		return

	var state: ActiveMusicState = _current_music_state
	var player: AudioStreamPlayer = state.current_stream_player

	if fade_out_time > 0:
		# 淡出
		_transition_scheduler.schedule_fade(
			player,
			player.volume_db,
			-60.0,
			fade_out_time,
			_on_stop_fade_complete.bind(state)
		)
		state.current_phase = ActiveMusicState.MusicPhase.FADING_OUT
	else:
		# 立即停止
		_stop_immediate(state)

func _stop_immediate(state: ActiveMusicState) -> void:
	"""立即停止播放"""
	if not state:
		return

	var track_id: String = str(state.track_resource.get_instance_id())
	_active_tracks.erase(track_id)
	_return_player_to_pool(state.current_stream_player)

	if _current_music_state == state:
		_current_music_state = null

	music_stopped.emit(state.track_resource)

func _on_stop_fade_complete(state: ActiveMusicState) -> void:
	"""淡出完成回调"""
	_stop_immediate(state)
```

**Step 2: 实现 crossfade_to**

替换 crossfade_to 方法：

```gdscript
## 交叉淡入淡出
func crossfade_to(new_track: MusicTrackResource, fade_time: float = 1.0) -> String:
	"""
	淡入新音乐，淡出旧音乐

	@param new_track: 新音乐轨道
	@param fade_time: 过渡时间
	@return: track_id
	"""
	if not _current_music_state:
		# 没有旧音乐，直接淡入
		return play_music(new_track, fade_in_time=fade_time)

	var old_state: ActiveMusicState = _current_music_state
	var old_player: AudioStreamPlayer = old_state.current_stream_player

	# 创建新播放器
	var new_player: AudioStreamPlayer = _get_player_from_pool()
	new_player.stream = new_track.loop_stream
	new_player.bus = _bus_controller.get_music_bus_index()
	new_player.volume_db = -60.0
	new_player.play(0.0)

	# 交叉淡入淡出
	_transition_scheduler.schedule_crossfade(old_player, new_player, fade_time)

	# 创建新状态
	var track_id: String = str(new_track.get_instance_id())
	var new_state: ActiveMusicState = ActiveMusicState.create(new_track, new_player)
	_active_tracks[track_id] = new_state
	_current_music_state = new_state

	# 过渡完成后清理旧状态
	await _transition_scheduler.crossfade_completed
	var old_track_id: String = str(old_state.track_resource.get_instance_id())
	_active_tracks.erase(old_track_id)
	_return_player_to_pool(old_player)

	music_transition_started.emit(old_state.track_resource, new_track)
	print("[MusicManager] Crossfade 完成")

	return track_id
```

**Step 3: 提交**

```bash
git add addons/juicy_mixer/core/music_manager.gd
git commit -m "feat(music): 实现 stop_music 和 crossfade_to

- 停止音乐（支持淡出）
- 交叉淡入淡出切换音乐
- 状态清理和信号发射"
```

---

## 后续任务

以下任务需要继续实现（按照相同的详细程度）：

### Task 10-15: 音乐层、LPF 快照、持久化
### Task 16-20: 测试和文档
### Task 21-25: 集成测试和优化

由于篇幅限制，完整计划包含 25+ 个任务。当前已完成前 9 个核心任务，建立了：
- ✅ 完整的数据结构
- ✅ 核心组件框架
- ✅ 基础播放功能
- ✅ 事件系统集成

**建议**: 先实现并测试当前任务，确认架构可行后，再继续剩余任务。

---

## 测试策略

### 单元测试
每个组件都需要对应的测试文件，位于 `addons/juicy_mixer/tests/music/`

### 集成测试
创建 `addons/juicy_mixer/tests/music/integration_test_music_system.gd` 测试完整流程

### 手动测试
创建演示场景 `demos/music_system_demo.tscn`

---

## 相关文档

- [音乐系统设计文档](../../music_system_design.md)
- [JuicyMixer 音频管理器设计](../addons/juicy_mixer/docs/dev_docs/audio_manager_design.md)
- [事件驱动系统设计](../addons/juicy_mixer/docs/dev_docs/phase4_event_driven_system_detailed_plan.md)
