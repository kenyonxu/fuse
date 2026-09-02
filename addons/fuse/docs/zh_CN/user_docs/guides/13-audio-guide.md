> 🌐 中文 | [**English**](../../../en_US/user_docs/guides/13-audio-guide.md)

# 音频系统使用指南

Fuse 音频系统提供 6 个音频指令和 4 个音频事件，覆盖音效播放、音乐播放与切换、音量控制、暂停恢复以及音乐节拍检测等完整音频交互链路。

## 指令列表

| 名称 | 功能描述 | 关键参数 |
|------|----------|----------|
| **PlaySound** | 播放音效（一次性播放，播放完自动清理） | `sound_path`（音频文件路径）、`volume`（音量 0.0-1.0）、`pitch_scale`（音调 0.01-4.0）、`bus`（混音器总线） |
| **PlayMusic** | 播放音乐（异步指令，播放完成后才结束） | `music_path`（音乐文件路径）、`volume`（音量 0.0-1.0）、`bus`（混音器总线）、`fade_in`（是否淡入）、`fade_duration`（淡入时间） |
| **CrossfadeToMusic** | 交叉淡入淡出切换音乐（异步指令） | `music_path`（新音乐路径）、`volume`（音量 0.0-1.0）、`bus`（混音器总线）、`crossfade_duration`（淡入淡出时长） |
| **StopAudio** | 停止音频播放 | `stop_mode`（停止模式：All/Bus/Name Pattern）、`bus`（目标总线）、`name_pattern`（名称匹配模式）、`fade_out`（是否淡出）、`fade_duration`（淡出时间） |
| **SetAudioVolume** | 设置音频播放器或总线的音量 | `target_mode`（目标模式：Specific Player/Bus/Name Pattern）、`volume`（音量 0.0-1.0）、`fade`（是否淡入淡出）、`fade_duration`（淡入淡出时间） |
| **PauseResumeAudio** | 暂停或恢复音频播放 | `action_mode`（操作：Pause/Resume）、`target_mode`（目标模式：Specific Player/Bus/Name Pattern/All Playing） |

### 指令使用说明

**PlaySound：**
- 自动创建 `AudioStreamPlayer` 节点，播放完成后自动清理
- 命名格式为 `Fuse_AudioPlayer_<随机数>`，方便 `StopAudio` 和 `SetAudioVolume` 按名称模式定位

**PlayMusic / CrossfadeToMusic：**
- 这两个指令是异步的，会在音乐播放完成后才标记指令结束
- `CrossfadeToMusic` 会自动查找当前正在播放的 `Fuse_MusicPlayer*` 并执行交叉淡入淡出

**目标模式说明：**
- `Specific Player`：指定具体音频播放器节点路径
- `Bus`：按混音器总线名称筛选所有播放器
- `Name Pattern`：按节点名称匹配（支持通配符 `*`）
- `All Playing`（仅暂停/恢复）：所有正在播放的音频

---

## 事件列表

| 名称 | 触发条件 | 输出数据 |
|------|----------|----------|
| **OnAudioStarted** | AudioStreamPlayer 从非播放状态变为播放状态 | `audio_player`（音频播放器节点）、`audio_name`（可选，音频资源名称） |
| **OnAudioFinished** | AudioStreamPlayer 播放完成时触发 | `audio_player`（音频播放器节点）、`audio_name`（可选，音频文件名）、`stream_length`（可选，音频时长） |
| **OnMusicBeat** | 按 BPM 节拍定时触发（适合节奏游戏） | `beat_count`（节拍计数）、`bpm`（BPM 值）、`elapsed_time`（经过时间）、`beat_interval`（节拍间隔） |
| **OnAudioBusVolumeChanged** | 音频总线音量变化时触发 | `bus_name`（总线名称）、`bus_index`（总线索引）、`old_volume_db`（旧音量）、`new_volume_db`（新音量）、`volume_change_db`（变化量） |

### 事件使用说明

**OnAudioStarted：**
- 通过轮询检测 `playing` 属性从 false 到 true 的变化
- `trigger_on_loop`：循环播放时是否每次循环都触发，关闭则每次播放只触发一次

**OnMusicBeat：**
- 使用 `_process` 每帧检测节拍时间，精度取决于帧率
- `beat_interval`：节拍间隔倍数，1 = 每拍，2 = 每两拍，4 = 每小节（4/4 拍）

**OnAudioBusVolumeChanged：**
- 通过轮询检查总线音量变化，默认每 0.1 秒检查一次
- `volume_threshold`：音量变化阈值（dB），低于此值的变化不会触发

---

## 常见用例

### 1. 场景音乐切换

进入新场景时使用 `CrossfadeToMusic` 平滑过渡背景音乐：

```
# 场景加载完成后执行
CrossfadeToMusic → music_path: "res://audio/level2_bgm.ogg", volume: 0.8, crossfade_duration: 3.0
```

### 2. 暂停菜单

打开暂停菜单时暂停所有正在播放的音频，关闭时恢复：

```
# 暂停
PauseResumeAudio → action_mode: Pause, target_mode: All Playing

# 恢复
PauseResumeAudio → action_mode: Resume, target_mode: All Playing
```

### 3. 节奏游戏 - 音乐同步

使用 `OnMusicBeat` 按 BPM 触发视觉或游戏逻辑：

```
# 事件：每拍触发（120 BPM）
OnMusicBeat → bpm: 120, beat_interval: 1, emit_beat_count: true

# 后续指令：根据 beat_count 执行动画、生成音符等
```
