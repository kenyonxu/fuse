# 音乐系统扩展设计文档

**文档版本**: 1.0
**创建日期**: 2026-01-18
**状态**: 设计阶段
**目标**: 为 JuicyMixer 添加游戏音乐播放支持

---

## 📋 目录

- [1. 概述](#1-概述)
- [2. 设计目标](#2-设计目标)
- [3. 架构设计](#3-架构设计)
- [4. 数据结构](#4-数据结构)
- [5. 核心类设计](#5-核心类设计)
- [6. 实现细节](#6-实现细节)
- [7. 与现有系统集成](#7-与现有系统集成)
- [8. API 使用示例](#8-api-使用示例)
- [9. 实现计划](#9-实现计划)
- [10. 测试策略](#10-测试策略)

---

## 1. 概述

### 1.1 设计目的

在现有 JuicyMixer 音频管理体系基础上，添加专门的游戏音乐播放功能，支持：
- Intro-Loop 音乐结构
- 跨音轨平滑过渡（Crossfade）
- 环境快照（暂停 LPF 效果）
- 音乐持久化与同步（场景切换保持播放）

### 1.2 设计原则

- **渐进扩展**: 在现有架构上添加音乐系统，不破坏现有音效系统
- **事件驱动**: 通过 JuicyMixer 的统一事件系统处理音乐事件
- **资源驱动**: 使用 Resource 配置音乐参数，支持 Inspector 可视化编辑
- **性能优化**: 复用现有播放器池、虚声部系统、AudioBus 架构

### 1.3 技术栈

- **Godot 4.5**: 游戏引擎版本
- **GDScript**: 主要编程语言
- **Resource 系统**: 配置和序列化
- **JuicyMixer 事件系统**: 统一的事件驱动架构

---

## 2. 设计目标

### 2.1 核心功能需求

#### 2.1.1 Intro-Loop 机制
- ✅ 播放 Intro 部分，结束后自动切换到 Loop
- ✅ 支持 Intro 淡出、Loop 淡入的平滑过渡
- ✅ 支持多个 Loop 变体（随机选择）
- ✅ 过渡参数在资源级配置

#### 2.1.2 Crossfade 调度器
- ✅ 替换式过渡：旧音乐淡出，新音乐淡入
- ✅ 叠加式过渡：基础音乐保持，添加新音乐层
- ✅ 支持场景切换、游戏状态切换、时间点触发
- ✅ 可配置的过渡时间和曲线

#### 2.1.3 环境快照（LPF）
- ✅ 暂停时应用低通滤波器，音乐变"闷"
- ✅ 通过 AudioBus 路由切换实现
- ✅ 恢复时移除效果

#### 2.1.4 音乐持久化
- ✅ 跨场景识别相同音乐资源
- ✅ 保持播放位置、音量等状态
- ✅ 支持播放器跨场景移动

---

## 3. 架构设计

### 3.1 整体架构

```
游戏代码
   ↓
MusicManager (高层 API)
   ↓ 创建 JuicyEvent
JuicyMixer.play_event()
   ↓
Director.play_event()
   ↓
MiddlewarePipeline
   ├─ ValidationMiddleware (验证 ContextType.EVENT)
   ├─ EventHandlingMiddleware (分发事件)
   │   ├─ AudioEventHandler (优先级 0) → 音效播放
   │   └─ MusicEventHandler (优先级 10) → MusicManager
   └─ [其他中间件...]

MusicManager
   ├─ MusicTransitionScheduler (过渡调度)
   ├─ MusicBusController (总线控制)
   └─ ActiveMusicState (状态管理)
```

### 3.2 设计理念

**分离与协作**
- 音效使用 AudioEventHandler（优先级 0）
- 音乐使用 MusicEventHandler（优先级 10）
- 两者共享 AudioManager 的配置和资源

**事件驱动**
- 所有音乐操作都通过 JuicyMixer.play_event()
- 保持架构一致性，支持完整的中间件流程

**资源驱动**
- MusicTrackResource 配置音乐参数
- 支持 Inspector 可视化编辑

---

## 4. 数据结构

### 4.1 MusicTrackResource（音乐轨道资源）

```gdscript
class_name MusicTrackResource
extends JuicyEventResource

## 音乐类型枚举
enum MusicType {
    STANDARD,      # 标准音乐（直接播放）
    INTRO_LOOP,    # Intro + Loop 结构
    LAYERED,       # 可叠加的音乐层
    TRANSITIONAL   # 过渡音乐
}

## 音乐段定义
@export var music_type: MusicType = MusicType.INTRO_LOOP
@export var intro_stream: AudioStream      # Intro 段音频
@export var loop_stream: AudioStream       # Loop 段音频
@export var loop_variants: Array[AudioStream] = []  # Loop 变体

## 过渡参数
@export var intro_fade_out_time: float = 2.0   # Intro 结束淡出时间
@export var loop_fade_in_time: float = 2.0     # Loop 开始淡入时间
@export var transition_fade_time: float = 1.0  # 默认过渡时间

## 总线配置
@export var music_bus: StringName = &"Music"   # 主音乐总线
@export var use_lpf_on_pause: bool = true      # 暂停时使用 LPF

## 持久化配置
@export var persist_across_scenes: bool = true  # 跨场景保持播放
@export var persistence_key: String = ""        # 唯一标识符
```

### 4.2 MusicLayerResource（音乐层资源）

```gdscript
class_name MusicLayerResource
extends Resource

## 用于叠加的音乐层（如战斗强度层）
@export var layer_name: String = "Layer1"
@export var layer_stream: AudioStream
@export var layer_bus_index: int = 0  # Music_Layer1, Music_Layer2, ...

## 音量控制
@export var default_volume: float = -10.0  # dB
@export var fade_in_time: float = 1.0
@export var fade_out_time: float = 1.0

## 触发条件（可扩展）
@export var trigger_tag: String = ""  # 例如 "combat_heavy"
```

### 4.3 ActiveMusicState（活跃音乐状态）

```gdscript
class_name ActiveMusicState
extends RefCounted

## 当前播放的音乐状态
var track_resource: MusicTrackResource
var current_stream_player: AudioStreamPlayer
var current_phase: MusicPhase

var playback_position: float = 0.0
var target_volume: float = 0.0
var current_volume: float = 0.0

## 叠加层
var active_layers: Dictionary = {}  # {layer_id: ActiveLayerState}

## 持久化状态
var persistence_key: String = ""
var scene_persistence_enabled: bool = false

enum MusicPhase {
    INTRO,
    LOOP,
    FADING_OUT,
    FADING_IN,
    STOPPED
}
```

---

## 5. 核心类设计

### 5.1 MusicManager（音乐管理器）

```gdscript
class_name MusicManager
extends Node

## 场景级单例，管理所有背景音乐

signal music_started(track_resource: MusicTrackResource)
signal music_stopped(track_resource: MusicTrackResource)
signal music_transition_started(from_track: MusicTrackResource, to_track: MusicTrackResource)

## 单例访问
static func get_instance() -> MusicManager:
    ## 返回场景中的 MusicManager 单例

static func ensure_exists() -> MusicManager:
    ## 确保 MusicManager 存在，不存在则创建

## 核心播放 API
func play_music(track: MusicTrackResource,
                fade_in_time: float = 0.0,
                persistence_key: String = "") -> String:
    """
    播放音乐，支持淡入

    @param track: 音乐轨道资源
    @param fade_in_time: 淡入时间（秒）
    @param persistence_key: 持久化标识符
    @return: context_id
    """

func stop_music(fade_out_time: float = 0.0):
    """停止当前音乐，支持淡出"""

func crossfade_to(new_track: MusicTrackResource,
                  fade_time: float = 1.0) -> String:
    """
    淡入新音乐，淡出旧音乐

    @param new_track: 新音乐轨道
    @param fade_time: 过渡时间
    @return: context_id
    """

## 音乐层 API
func add_music_layer(layer: MusicLayerResource,
                     fade_in_time: float = 0.0) -> String:
    """
    添加叠加音乐层

    @param layer: 音乐层资源
    @param fade_in_time: 淡入时间
    @return: layer_id
    """

func remove_music_layer(layer_id: String,
                        fade_out_time: float = 0.0):
    """移除音乐层"""

## 总线控制
func apply_pause_snapshot():
    """应用暂停快照（LPF）"""

func apply_normal_snapshot():
    """恢复正常播放"""

## 持久化
func prepare_for_scene_change() -> Dictionary:
    """准备场景切换，返回持久化状态"""

func restore_from_state(state: Dictionary):
    """从状态恢复音乐播放"""

## 内部管理
var _transition_scheduler: MusicTransitionScheduler
var _bus_controller: MusicBusController
var _music_event_handler: MusicEventHandler
var _active_tracks: Dictionary = {}  # {track_id: ActiveMusicState}
var _active_layers: Dictionary = {}  # {layer_id: LayerState}
```

### 5.2 MusicEventHandler（音乐事件处理器）

```gdscript
class_name MusicEventHandler
extends JuicyEventHandler

## 专门处理音乐事件的 Handler
## 注册到 EventHandlingMiddleware（优先级：10，高于音效的0）

func get_event_types() -> PackedStringArray:
    """返回处理的事件类型"""
    return ["MUSIC_PLAY", "MUSIC_STOP", "MUSIC_CROSSFADE",
            "MUSIC_ADD_LAYER", "MUSIC_REMOVE_LAYER",
            "MUSIC_PAUSE_SNAPSHOT", "MUSIC_NORMAL_SNAPSHOT"]

func handle_event(event: JuicyEvent, context: JuicyContext) -> void:
    """处理音乐事件"""
    match event.event_type:
        "MUSIC_PLAY":
            _handle_music_play(event, context)
        "MUSIC_STOP":
            _handle_music_stop(event, context)
        "MUSIC_CROSSFADE":
            _handle_crossfade(event, context)
        "MUSIC_ADD_LAYER":
            _handle_add_layer(event, context)
        "MUSIC_REMOVE_LAYER":
            _handle_remove_layer(event, context)
        "MUSIC_PAUSE_SNAPSHOT":
            _handle_pause_snapshot(event, context)
        "MUSIC_NORMAL_SNAPSHOT":
            _handle_normal_snapshot(event, context)

func _handle_music_play(event: JuicyEvent, context: JuicyContext):
    """处理音乐播放事件"""
    var track = event.event_data["track_resource"]
    var fade_in = event.event_data.get("fade_in_time", 0.0)
    var persistence_key = event.event_data.get("persistence_key", "")

    # 调用 MusicManager 实际播放
    var manager = MusicManager.get_instance()
    if manager:
        manager.play_music(track, fade_in, persistence_key)
```

### 5.3 MusicTransitionScheduler（音乐过渡调度器）

```gdscript
class_name MusicTransitionScheduler
extends RefCounted

## 管理所有音乐过渡动画

## 过渡请求定义
class TransitionRequest:
    var target_player: AudioStreamPlayer
    var from_volume: float
    var to_volume: float
    var duration: float
    var fade_curve: Tween.EaseType
    var on_complete: Callable

var _active_transitions: Array[TransitionRequest] = []
var _tween: Tween

## 调度 API
func schedule_fade(player: AudioStreamPlayer,
                   from_volume: float,
                   to_volume: float,
                   duration: float,
                   on_complete: Callable = Callable()):
    """调度淡入淡出"""

func schedule_crossfade(out_player: AudioStreamPlayer,
                        in_player: AudioStreamPlayer,
                        duration: float):
    """调度交叉淡入淡出"""

func process_transitions(delta: float):
    """每帧更新过渡状态（如果使用自定义插值）"""

func cancel_all_transitions():
    """取消所有活跃过渡"""

## 信号
signal transition_completed(player: AudioStreamPlayer)
signal crossfade_completed(out_player: AudioStreamPlayer, in_player: AudioStreamPlayer)
```

### 5.4 MusicBusController（音乐总线控制器）

```gdscript
class_name MusicBusController
extends RefCounted

## 管理 Godot AudioBus 创建和路由

const MUSIC_BUS_NAME = &"Music"
const MUSIC_LPF_BUS_NAME = &"Music_LPF"
const LAYER_BUS_PREFIX = &"Music_Layer"

## 总线索引
var _music_bus_index: int = -1
var _music_lpf_bus_index: int = -1
var _layer_bus_indices: Dictionary = {}  # {layer_index: bus_index}

## 初始化
func setup_buses():
    """
    创建音乐总线结构

    Music (主音乐总线)
      ├── Music_LPF (带低通滤波器)
      ├── Music_Layer1 (叠加层1)
      ├── Music_Layer2 (叠加层2)
      └── ...
    """

## 路由控制
func route_to_lpf(enable: bool):
    """切换到/恢复 LPF 总线"""

func route_to_normal():
    """恢复到正常总线"""

func get_layer_bus(layer_index: int) -> int:
    """获取音乐层总线索引"""

## 效果控制
func set_lpf_cutoff(hz: float):
    """设置 LPF 截止频率"""

func set_lpf resonance_db: float):
    """设置 LPF 共振"""
```

---

## 6. 实现细节

### 6.1 Intro-Loop 播放流程

```gdscript
func _play_intro_loop_track(track: MusicTrackResource):
    # 步骤 1: 创建播放器
    var player = _get_player_from_pool()
    player.stream = track.intro_stream
    player.bus = _bus_controller._music_bus_index

    # 步骤 2: 播放 Intro
    player.play(0.0)

    # 步骤 3: 计算何时切换到 Loop
    var intro_duration = track.intro_stream.get_length()
    var transition_start_time = intro_duration - track.intro_fade_out_time

    # 步骤 4: 等待过渡时机
    await get_tree().create_timer(transition_start_time).timeout

    # 步骤 5: 开始淡出 Intro，淡入 Loop
    var loop_player = _get_player_from_pool()
    loop_player.stream = _select_loop_variant(track)
    loop_player.autoplay = false

    # 步骤 6: 交叉淡入淡出
    _transition_scheduler.schedule_crossfade(
        player,      # 淡出
        loop_player, # 淡入
        track.loop_fade_in_time
    )

    # 步骤 7: Loop 播放器设置为循环
    loop_player.finished.connect(_on_loop_finished, CONNECT_ONE_SHOT)

func _select_loop_variant(track: MusicTrackResource) -> AudioStream:
    """选择 Loop 变体（如果有）"""
    if track.loop_variants.is_empty():
        return track.loop_stream

    # 使用现有的防重复机制
    var index = _get_non_repeating_index(track.loop_variants.size())
    return track.loop_variants[index]
```

### 6.2 Crossfade 跨资源过渡

```gdscript
func crossfade_to(new_track: MusicTrackResource, fade_time: float):
    var old_state = _current_music_state

    if old_state == null:
        # 没有旧音乐，直接淡入新音乐
        play_music(new_track, fade_in_time=fade_time)
        return

    # 创建新的播放器
    var new_player = _get_player_from_pool()
    new_player.stream = new_track.loop_stream
    new_player.volume_db = -60.0  # 从静音开始
    new_player.play()

    # 调度交叉淡入淡出
    _transition_scheduler.schedule_crossfade(
        old_state.current_stream_player,  # 淡出
        new_player,                        # 淡入
        fade_time
    )

    # 过渡完成后清理旧播放器
    await _transition_scheduler.crossfade_completed
    _return_player_to_pool(old_state.current_stream_player)
```

### 6.3 音乐层叠加

```gdscript
func add_music_layer(layer: MusicLayerResource, fade_in_time: float) -> String:
    # 创建独立的播放器
    var layer_player = _get_player_from_pool()
    layer_player.stream = layer.layer_stream
    layer_player.bus = _bus_controller.get_layer_bus(layer.layer_bus_index)
    layer_player.volume_db = -60.0
    layer_player.play()

    # 淡入
    _transition_scheduler.schedule_fade(
        layer_player,
        -60.0,
        layer.default_volume,
        fade_in_time
    )

    # 记录活跃层
    var layer_id = str(layer.get_instance_id())
    _active_layers[layer_id] = {
        "resource": layer,
        "player": layer_player,
        "state": ActiveLayerState.FADING_IN
    }

    return layer_id
```

### 6.4 暂停 LPF 快照

```gdscript
func apply_pause_snapshot():
    """应用暂停快照（LPF）"""
    # 将所有活跃音乐播放器路由到 LPF 总线
    for track_id in _active_tracks:
        var state = _active_tracks[track_id]
        state.current_stream_player.bus = \
            _bus_controller._music_lpf_bus_index

    # 设置 LPF 参数（例如：1000Hz 截止频率）
    _bus_controller.set_lpf_cutoff(1000.0)

func apply_normal_snapshot():
    """恢复正常播放"""
    # 恢复正常总线
    for track_id in _active_tracks:
        var state = _active_tracks[track_id]
        state.current_stream_player.bus = \
            _bus_controller._music_bus_index
```

### 6.5 场景持久化

```gdscript
func prepare_for_scene_change() -> Dictionary:
    """准备场景切换，返回持久化状态"""
    if not _current_music_state:
        return {}

    var state = _current_music_state
    return {
        "track_resource": state.track_resource,
        "playback_position": state.current_stream_player.get_playback_position(),
        "volume": state.current_stream_player.volume_db,
        "persistence_key": state.persistence_key,
        "active_layers": _serialize_layers()
    }

func restore_from_state(saved_state: Dictionary):
    """从状态恢复音乐播放"""
    if saved_state.is_empty():
        return

    var track: MusicTrackResource = saved_state["track_resource"]

    # 检查是否需要保持（资源相同且标记为持久化）
    if track.persist_across_scenes:
        # 恢复播放位置和音量
        var player = _get_player_from_pool()
        player.stream = track.loop_stream
        player.play(saved_state["playback_position"])
        player.volume_db = saved_state["volume"]

        # 恢复活跃层
        _restore_layers(saved_state["active_layers"])

func _serialize_layers() -> Dictionary:
    """序列化活跃层状态"""
    var serialized = {}
    for layer_id in _active_layers:
        var layer_state = _active_layers[layer_id]
        serialized[layer_id] = {
            "resource": layer_state.resource,
            "volume": layer_state.player.volume_db,
            "playback_position": layer_state.player.get_playback_position()
        }
    return serialized

func _restore_layers(serialized: Dictionary):
    """恢复活跃层"""
    for layer_id in serialized:
        var layer_data = serialized[layer_id]
        add_music_layer(layer_data.resource, 0.0)
        # 恢复状态...
```

---

## 7. 与现有系统集成

### 7.1 注册 Handler

```gdscript
# MusicManager 在 _ready 时注册 Handler
func _ready():
    # 设置总线
    _bus_controller = MusicBusController.new()
    _bus_controller.setup_buses()

    # 创建过渡调度器
    _transition_scheduler = MusicTransitionScheduler.new()

    # 创建音乐事件处理器
    _music_event_handler = MusicEventHandler.new()
    _music_event_handler.music_manager = self

    # 注册到 EventHandlingMiddleware
    var event_middleware = JuicyMixer.get_middleware("EventHandlingMiddleware")
    if event_middleware:
        event_middleware.register_handler(_music_event_handler, priority=10)
```

### 7.2 复用播放器池

```gdscript
# 复用 AudioEventHandler 的播放器池
func _get_player_from_pool() -> AudioStreamPlayer:
    var event_middleware = JuicyMixer.get_middleware("EventHandlingMiddleware")
    if event_middleware and event_middleware.audio_handler:
        return event_middleware.audio_handler.request_player()

    # 或者创建独立的音乐播放器池
    return _music_player_pool.request()
```

### 7.3 共享配置

```gdscript
# MusicManager 复用现有的配置
func _ready():
    var audio_manager = AudioManager.get_instance()
    if audio_manager:
        # 共享全局限额配置
        _global_limit_config = audio_manager.global_limit_config

        # 共享虚声部管理
        _virtual_voice_manager = audio_manager.virtual_voice_manager
```

---

## 8. API 使用示例

### 8.1 基础播放

```gdscript
# 在场景中创建 MusicManager
var music_manager = MusicManager.new()
add_child(music_manager)

# 加载音乐资源
var exploration_music = preload("res://music/exploration.tres")

# 播放音乐（带淡入）
music_manager.play_music(exploration_music, fade_in_time=2.0)

# 停止音乐（带淡出）
music_manager.stop_music(fade_out_time=3.0)
```

### 8.2 Intro-Loop 音乐

```gdscript
# 创建 Intro-Loop 资源
var track = MusicTrackResource.new()
track.music_type = MusicTrackResource.MusicType.INTRO_LOOP
track.intro_stream = preload("res://music/battle_intro.ogg")
track.loop_stream = preload("res://music/battle_loop.ogg")
track.intro_fade_out_time = 1.5
track.loop_fade_in_time = 1.5

# 播放
music_manager.play_music(track)
```

### 8.3 Crossfade 过渡

```gdscript
# 切换到战斗音乐
var combat_music = preload("res://music/combat.tres")
music_manager.crossfade_to(combat_music, fade_time=3.0)
```

### 8.4 音乐层叠加

```gdscript
# 基础战斗音乐
music_manager.play_music(combat_music)

# 添加高强度层
var heavy_layer = MusicLayerResource.new()
heavy_layer.layer_stream = preload("res://music/combat_heavy.ogg")
heavy_layer.default_volume = -5.0

var layer_id = music_manager.add_music_layer(heavy_layer, fade_in_time=1.5)

# 移除高强度层
music_manager.remove_music_layer(layer_id, fade_out_time=2.0)
```

### 8.5 暂停快照

```gdscript
func _on_pause_menu_opened():
    MusicManager.get_instance().apply_pause_snapshot()

func _on_pause_menu_closed():
    MusicManager.get_instance().apply_normal_snapshot()
```

### 8.6 场景持久化

```gdscript
# Scene A 准备切换
func _on_exit_to_scene_b():
    var state = MusicManager.get_instance().prepare_for_scene_change()
    SceneTransition.set_music_state(state)  # 传递给下一场景

# Scene B 恢复
func _ready():
    var saved_state = SceneTransition.get_music_state()
    if not saved_state.is_empty():
        MusicManager.get_instance().restore_from_state(saved_state)
```

### 8.7 通过事件系统播放

```gdscript
# 通过 JuicyMixer 事件系统播放音乐
var music_event = JuicyEvent.new()
music_event.event_type = "MUSIC_PLAY"
music_event.event_data = {
    "track_resource": exploration_music,
    "fade_in_time": 2.0,
    "persistence_key": "exploration_theme"
}

JuicyMixer.play_event(music_event, get_tree().current_scene, self)
```

---

## 9. 实现计划

### 9.1 阶段划分

#### 阶段 1：核心基础设施（1-2天）
- ✅ MusicTrackResource 和 MusicLayerResource 数据结构
- ✅ MusicManager 基础框架
- ✅ MusicEventHandler 注册到事件系统
- ✅ MusicBusController 总线创建

#### 阶段 2：Intro-Loop 机制（1天）
- ✅ Intro-Loop 时序控制
- ✅ 淡入淡出过渡
- ✅ Loop 变体选择

#### 阶段 3：过渡系统（1天）
- ✅ MusicTransitionScheduler 实现
- ✅ Crossfade 跨资源过渡
- ✅ 音乐层叠加

#### 阶段 4：总线与快照（1天）
- ✅ LPF 效果器配置
- ✅ 暂停快照应用/恢复
- ✅ 总线路由切换

#### 阶段 5：持久化（1天）
- ✅ 场景切换检测
- ✅ 状态保存/恢复
- ✅ 播放器跨场景移动

#### 阶段 6：测试与优化（1-2天）
- ✅ 单元测试
- ✅ 集成测试
- ✅ 性能优化
- ✅ 文档完善

### 9.2 文件结构

```
addons/juicy_mixer/
├── core/
│   ├── music_manager.gd              # 音乐管理器
│   └── music/
│       ├── music_event_handler.gd    # 音乐事件处理器
│       ├── music_transition_scheduler.gd  # 过渡调度器
│       └── music_bus_controller.gd   # 总线控制器
├── resources/
│   └── music/
│       ├── music_track_resource.gd   # 音乐轨道资源
│       └── music_layer_resource.gd   # 音乐层资源
└── docs/
    └── music_system_design.md        # 本文档
```

---

## 10. 测试策略

### 10.1 单元测试

**Intro-Loop 时序测试**
```gdscript
func test_intro_loop_timing():
    var track = MusicTrackResource.new()
    track.intro_stream = _create_test_stream(5.0)  # 5秒 Intro
    track.loop_stream = _create_test_stream(10.0)  # 10秒 Loop
    track.intro_fade_out_time = 1.0
    track.loop_fade_in_time = 1.0

    music_manager.play_music(track)

    # 验证 Intro 在 4秒时开始淡出
    await get_tree().create_timer(4.0).timeout
    assert(music_state.current_phase == ActiveMusicState.FADING_OUT)

    # 验证 Loop 在 5秒时开始播放
    await get_tree().create_timer(1.0).timeout
    assert(music_state.current_phase == ActiveMusicState.LOOP)
```

**Crossfade 音量曲线测试**
```gdscript
func test_crossfade_volume_curve():
    var old_player = _create_test_player()
    var new_player = _create_test_player()

    scheduler.schedule_crossfade(old_player, new_player, 2.0)

    # 中间点检查：两个播放器音量应该相等
    await get_tree().create_timer(1.0).timeout
    assert(abs(old_player.volume_db - new_player.volume_db) < 0.1)
```

**状态序列化测试**
```gdscript
func test_state_serialization():
    var state = music_manager.prepare_for_scene_change()

    # 验证必要字段存在
    assert(state.has("track_resource"))
    assert(state.has("playback_position"))
    assert(state.has("volume"))
    assert(state.has("persistence_key"))
```

### 10.2 集成测试

**场景切换音乐保持**
```gdscript
func test_scene_persistence():
    # Scene A 播放音乐
    music_manager.play_music(track_a)
    var saved_state = music_manager.prepare_for_scene_change()

    # 模拟场景切换
    music_manager.queue_free()
    music_manager = MusicManager.new()
    add_child(music_manager)

    # Scene B 恢复
    music_manager.restore_from_state(saved_state)

    # 验证音乐继续播放
    assert(music_manager.is_playing())
    assert(music_manager.get_current_track() == track_a)
```

**暂停 LPF 效果**
```gdscript
func test_pause_lpf():
    music_manager.play_music(track)
    await get_tree().process_frame

    # 应用暂停快照
    music_manager.apply_pause_snapshot()

    # 验证总线路由
    assert(music_manager._current_player.bus == bus_controller._music_lpf_bus_index)
```

**多层叠加混音**
```gdscript
func test_music_layers():
    music_manager.play_music(base_track)

    var layer1_id = music_manager.add_music_layer(layer1)
    var layer2_id = music_manager.add_music_layer(layer2)

    # 验证两层都在播放
    assert(music_manager.get_active_layer_count() == 2)

    # 验证不同总线
    assert(layer1_player.bus != layer2_player.bus)
```

### 10.3 性能测试

**大量过渡调度**
```gdscript
func test_many_transitions():
    for i in range(100):
        music_manager.crossfade_to(tracks[i % tracks.size()], 0.5)
        await get_tree().create_timer(0.1).timeout

    # 验证无内存泄漏
    assert(performance.get_monitor(Performance.MEMORY_STATIC) < threshold)
```

**长时间播放稳定性**
```gdscript
func test_long_playback_stability():
    music_manager.play_music(loop_track)

    # 播放 10 分钟
    await get_tree().create_timer(600.0).timeout

    # 验证仍在正常播放
    assert(music_manager.is_playing())
```

---

## 11. 未来扩展

### 11.1 高级特性

**动态音乐层触发**
- 基于游戏参数（血量、距离）自动添加/移除层
- 支持参数曲线控制

**交互式音乐**
- 支持跳转标记（Jump Marker）
- 垂直混音（Horizontal Remix）
- 段落重排序（Segment Reordering）

**音乐主题切换**
- 平滑过渡到变奏主题
- 支持主题链（Theme Chaining）

### 11.2 性能优化

**流式加载**
- 大型音乐文件流式播放
- 预加载相邻场景音乐

**音频压缩**
- 自适应压缩率
- 运行时转码

---

## 12. 附录

### 12.1 参考文档

- [JuicyMixer 音频管理器设计](../addons/juicy_mixer/docs/dev_docs/audio_manager_design.md)
- [事件驱动系统详细设计](../addons/juicy_mixer/docs/dev_docs/phase4_event_driven_system_detailed_plan.md)
- [Godot AudioStream 文档](https://docs.godotengine.org/en/stable/classes/class_audiostream.html)

### 12.2 术语表

| 术语 | 说明 |
|------|------|
| Intro-Loop | 介绍段 + 循环段的音乐结构 |
| Crossfade | 交叉淡入淡出，同时淡出旧音频、淡入新音频 |
| LPF | Low Pass Filter，低通滤波器 |
| Persistence | 持久化，保持状态跨场景 |
| Layer | 音乐层，可叠加的音频轨道 |

---

**文档结束**

**下一步**: 开始实现阶段 1（核心基础设施）
