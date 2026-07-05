# 音乐虚拟化（Music Virtualization）系统设计

**日期**: 2025-01-21
**作者**: Claude AI
**状态**: 设计完成

---

## 1. 系统目标

实现灵活的音乐中断处理机制，支持三种模式：

- **STOP_AND_RESTART** - 彻底停止，回来时重播（适合菜单音乐）
- **PAUSE_AND_RESUME** - 暂停并记录位置，回来继续（适合 RPG 探索音乐）
- **KEEP_PLAYING_SILENTLY** - 继续播放但降低到 ducked_volume_db（适合层叠音乐）

---

## 2. 核心架构

### 2.1 职责分离

- **MusicPlayer** - 管理优先级堆栈和所有音乐状态（包括 ducked/paused 状态）
- **MusicManager** - 负责底层音频播放，提供播放/暂停/恢复/调整音量 API
- **MusicTrackResource** - 定义每个音乐轨道的中断行为和过渡参数

### 2.2 数据流

1. 用户调用 `push_state("Combat", priority)`
2. MusicPlayer 将状态添加到堆栈，检查是否为最高优先级
3. 如果是，调用 MusicManager 播放新音乐
4. 同时，调用 MusicManager 的挂起 API 处理旧音乐（根据 interruption_mode）
5. 当状态被 pop 时，MusicPlayer 调用 MusicManager 的恢复 API

### 2.3 ActiveMusicState 扩展

需要添加字段来支持三种模式：
- `suspension_mode: SuspensionState` - 当前挂起状态
- `saved_playback_position: float` - PAUSE_AND_RESUME 模式保存的位置
- `saved_stream_player: AudioStreamPlayer` - PAUSE_AND_RESUME 模式保留的播放器
- `original_volume_db: float` - KEEP_PLAYING_SILENTLY 模式保存的原始音量

---

## 3. MusicTrackResource 属性

### 3.1 中断模式枚举

```gdscript
enum InterruptionMode {
    STOP_AND_RESTART,      # 彻底停止，回来时重播
    PAUSE_AND_RESUME,      # 暂停并记录位置，回来继续
    KEEP_PLAYING_SILENTLY  # 继续播放但降低音量
}
```

### 3.2 新增导出属性

```gdscript
@export_group("Interruption", "interruption_")
@export var interruption_mode: InterruptionMode = InterruptionMode.STOP_AND_RESTART
@export_range(0.0, 10.0, 0.1) var interruption_fade_out_time: float = 1.0
@export_range(0.0, 10.0, 0.1) var interruption_fade_in_time: float = 1.0
@export_range(-80.0, 0.0, 1.0) var ducked_volume_db: float = -60.0
```

### 3.3 属性说明

- `interruption_mode` - 定义当更高优先级音乐播放时，该音乐应该如何处理
- `interruption_fade_out_time` - 被中断时的淡出时长
- `interruption_fade_in_time` - 恢复播放时的淡入时长
- `ducked_volume_db` - KEEP_PLAYING_SILENTLY 模式下的目标音量（-60dB 基本静音，-20dB 背景可听）

### 3.4 默认值建议

- **菜单音乐**: STOP_AND_RESTART（简单的进入/退出）
- **探索音乐**: PAUSE_AND_RESUME（战斗后继续）
- **战斗音乐**: KEEP_PLAYING_SILENTLY（Boss 战时保留层）

---

## 4. ActiveMusicState 扩展

### 4.1 挂起状态枚举

```gdscript
enum SuspensionState {
    NONE,                   # 正在播放
    STOPPED,                # STOP_AND_RESTART 模式：已停止
    PAUSED,                 # PAUSE_AND_RESUME 模式：已暂停
    DUCKED                  # KEEP_PLAYING_SILENTLY 模式：已降低音量
}
```

### 4.2 新增字段

```gdscript
var suspension_state: SuspensionState = SuspensionState.NONE
var saved_playback_position: float = 0.0
var saved_stream_player: AudioStreamPlayer = null
var original_volume_db: float = 0.0
```

### 4.3 关键方法

```gdscript
func is_suspended() -> bool:
    return suspension_state != SuspensionState.NONE

func suspend(mode: MusicTrackResource.InterruptionMode, player: AudioStreamPlayer) -> void:
    match mode:
        MusicTrackResource.InterruptionMode.STOP_AND_RESTART:
            suspension_state = SuspensionState.STOPPED
        MusicTrackResource.InterruptionMode.PAUSE_AND_RESUME:
            suspension_state = SuspensionState.PAUSED
            saved_playback_position = player.get_playback_position()
            saved_stream_player = player
        MusicTrackResource.InterruptionMode.KEEP_PLAYING_SILENTLY:
            suspension_state = SuspensionState.DUCKED
            original_volume_db = player.volume_db

func resume() -> MusicTrackResource.InterruptionMode:
    var mode := get_interruption_mode()
    suspension_state = SuspensionState.NONE
    return mode
```

---

## 5. MusicPlayer 状态管理

### 5.1 活跃状态字典

```gdscript
var _active_states: Dictionary = {}  # {StringName: ActiveMusicState}
```

### 5.2 核心流程

**Push 新状态时**：
1. 调用 `_suspend_state()` 处理旧状态
2. 调用 `_activate_state()` 激活新状态
3. 更新 `_current_state` 和 `_current_priority`

**Pop 状态时**：
1. 从堆栈移除状态
2. 调用 `_update_top_priority()` 恢复下一个最高优先级

### 5.3 关键方法

```gdscript
func _update_top_priority(fade_time: float) -> void:
    # 找到最高优先级
    var top_item := _get_top_priority_item()

    if top_item.state_name != _current_state:
        # 挂起旧状态
        if _current_state != &"" and _current_state in _active_states:
            _suspend_state(_current_state, fade_time)

        # 激活新状态
        _activate_state(top_item, fade_time)

func _activate_state(item: MusicStackItem, fade_time: float) -> void:
    if item.state_name in _active_states:
        # 恢复挂起的状态
        _resume_state(_active_states[item.state_name], fade_time)
    else:
        # 创建新状态并播放
        var state := _music_manager.play_music(item.track, fade_time)
        _active_states[item.state_name] = state

func _suspend_state(state_name: StringName, fade_time: float) -> void:
    var state := _active_states[state_name]
    var mode := state.track_resource.interruption_mode

    match mode:
        MusicTrackResource.InterruptionMode.STOP_AND_RESTART:
            _music_manager.stop_music(state, fade_time)
        MusicTrackResource.InterruptionMode.PAUSE_AND_RESUME:
            _music_manager.pause_music(state, fade_time)
        MusicTrackResource.InterruptionMode.KEEP_PLAYING_SILENTLY:
            _music_manager.duck_music(state, state.track_resource.ducked_volume_db, fade_time)

    state.suspend(mode, state.current_stream_player)
```

---

## 6. MusicManager API 扩展

### 6.1 暂停音乐（PAUSE_AND_RESUME）

```gdscript
func pause_music(state: ActiveMusicState, fade_time: float) -> void:
    var player := state.current_stream_player

    # 淡出到静音
    if fade_time > 0:
        _transition_scheduler.schedule_fade(
            player, player.volume_db, -60.0, fade_time,
            _on_pause_fade_complete.bind(state)
        )
    else:
        _on_pause_fade_complete(state)

func _on_pause_fade_complete(state: ActiveMusicState) -> void:
    if state.current_stream_player:
        state.current_stream_player.stream_paused = true
```

### 6.2 恢复音乐（PAUSE_AND_RESUME）

```gdscript
func resume_music(state: ActiveMusicState, fade_time: float) -> void:
    var track := state.track_resource
    var player := create_player()

    player.stream = track.loop_stream
    player.bus = AudioServer.get_bus_name(_bus_controller.get_music_bus_index())
    player.volume_db = -60.0
    player.play(state.saved_playback_position)

    state.current_stream_player = player

    # 淡入到正常音量
    if fade_time > 0:
        _transition_scheduler.schedule_fade(player, -60.0, 0.0, fade_time)
    else:
        player.volume_db = 0.0
```

### 6.3 降低音量（KEEP_PLAYING_SILENTLY）

```gdscript
func duck_music(state: ActiveMusicState, target_volume_db: float, fade_time: float) -> void:
    var player := state.current_stream_player

    if fade_time > 0:
        _transition_scheduler.schedule_fade(
            player, player.volume_db, target_volume_db, fade_time
        )
    else:
        player.volume_db = target_volume_db

func unduck_music(state: ActiveMusicState, target_volume_db: float, fade_time: float) -> void:
    var player := state.current_stream_player

    if fade_time > 0:
        _transition_scheduler.schedule_fade(
            player, player.volume_db, target_volume_db, fade_time
        )
    else:
        player.volume_db = target_volume_db
```

---

## 7. 完整流程示例

### 场景：Push Combat（Exploring 使用 PAUSE_AND_RESUME）

**步骤**：
1. 用户调用 `push_state("Combat", 1)`
2. 当前播放 "Exploring"(优先级0)
3. MusicPlayer 检测到优先级变化
4. 调用 `_suspend_state("Exploring", 2.0)`
   - → `pause_music()` → Exploring 淡出到 -60dB
   - → `stream_paused = true` → 暂停解码
5. 调用 `_activate_state("Combat", 2.0)`
   - → `play_music()` → Combat 淡入并播放
6. Exploring 状态保存在 `_active_states` 中

**Pop Combat 时**：
1. 用户调用 `pop_state("Combat")`
2. MusicPlayer 从堆栈移除 "Combat"
3. 调用 `_update_top_priority()`
4. 找到下一个最高优先级："Exploring"
5. 调用 `_resume_state("Exploring", 2.0)`
   - → `resume_music()` → 从保存位置创建新播放器
   - → 淡入到正常音量
6. Exploring 继续播放

---

## 8. 实现顺序

1. **MusicTrackResource** - 添加 InterruptionMode 枚举和属性
2. **ActiveMusicState** - 添加挂起状态字段和方法
3. **MusicManager** - 实现 pause/resume/duck/unduck API
4. **MusicPlayer** - 修改 _update_top_priority() 支持多状态管理
5. **测试** - 测试三种中断模式

---

## 9. 测试计划

### 9.1 STOP_AND_RESTART 测试
- 配置 Menu 音乐使用 STOP_AND_RESTART
- Push Exploring → Menu 应该停止
- Pop Exploring → Menu 应该从头开始播放

### 9.2 PAUSE_AND_RESUME 测试
- 配置 Exploring 音乐使用 PAUSE_AND_RESUME
- Push Combat → Exploring 应该暂停
- Pop Combat → Exploring 应该从暂停位置继续

### 9.3 KEEP_PLAYING_SILENTLY 测试
- 配置 Combat 音乐使用 KEEP_PLAYING_SILENTLY
- Push Boss → Combat 应该降低到 -60dB
- Pop Boss → Combat 应该恢复到 0dB

### 9.4 混合模式测试
- Menu (STOP_AND_RESTART, 优先级0)
- Exploring (PAUSE_AND_RESUME, 优先级1)
- Combat (KEEP_PLAYING_SILENTLY, 优先级2)
- Boss (STOP_AND_RESTART, 优先级3)
- 测试各种 Push/Pop 组合

---

## 10. 注意事项

1. **AudioStreamPlayer 生命周期**：PAUSE_AND_RESUME 模式需要创建新播放器，旧播放器需要正确清理
2. **淡入淡出同步**：确保淡出完成后才开始淡入新音乐
3. **循环控制**：挂起/恢复时需要暂停/恢复循环控制器
4. **资源管理**：确保不再使用的 AudioStreamPlayer 被正确返回到池中

---

**设计完成** ✅
