# JuicyMixer 音频管理器用户指南

**版本**: 3.1
**最后更新**: 2026-01-15

> **重要说明**: 本文档涵盖两个独立的音频系统：
> 1. **AudioManager 系统**（v3.1+）- 使用 `AudioEventResource` 和 `JuicyAudioEventHandler`，专注于音频播放管理
> 2. **JuicyMixer 通用反馈系统**（v3.0+）- 使用 `JuicyFeedback`，支持特效、动画等多种反馈类型
>
> 本文档重点介绍 AudioManager 系统。如需了解通用反馈系统，请参阅 [JuicyMixer通用反馈](#juicymixer通用反馈系统) 章节。

## 📋 目录

- [快速开始](#快速开始)
- [核心概念](#核心概念)
- [音频管理器系统](#音频管理器系统)
- [JuicyMixer通用反馈系统](#juicymixer通用反馈系统)
- [高级功能](#高级功能)
- [最佳实践](#最佳实践)
- [故障排除](#故障排除)
- [示例场景](#示例场景)

---

## 新功能亮点 ✨

**v3.0 新增专业音频管理器系统**：
- 🎲 随机变体系统（避免重复、权重控制）
- 🎚️ 参数随机化（音高、音量自动调整）
- 🎙️ 动态鸭霸（对白时自动降低音乐音量）
- 📊 播放限额管理（防止音效过载）
- 🎯 2D/3D 自动检测
- 🔄 完整的事件系统集成

---

## 快速开始

### 1. 安装插件

1. 将 `addons/juicy_mixer` 文件夹复制到你的 Godot 项目的 `addons/` 目录
2. 在项目设置中启用插件：
   - 打开 项目 → 项目设置
   - 切换到 插件 标签页
   - 找到 "JuicyMixer V3" 并勾选
   - 重启编辑器

### 2. 第一个音频事件

#### 基本使用步骤：

```gdscript
# 创建音频事件处理器
var _audio_handler: JuicyAudioEventHandler

func _ready():
    # 初始化音频处理器
    _audio_handler = JuicyAudioEventHandler.new()
    add_child(_audio_handler)

    # 预加载并注册音频事件
    var jump_event = preload("res://audio_events/jump.tres")
    _audio_handler.register_audio_event("jump", jump_event)

# 播放音频事件
func play_jump_sound():
    _audio_handler.play_audio_event("jump", self)
```

#### 创建音频事件资源：

1. 在 文件系统 中右键
2. 选择 创建 → Resource
3. 搜索并选择 "AudioEventResource"
4. 命名为 `jump.tres`（保存在 `res://audio_events/` 目录）
5. 在 Inspector 中配置音频参数

### 3. 添加音频文件

1. 将音频文件放入 `res://audio/` 目录
2. 在 AudioEventResource 中配置：
   - **Audio Variants**: 添加音频变体
     - 点击展开数组
     - 添加 AudioVariant
     - 选择 Audio Stream（音频文件）
   - **Audio Bus**: 选择音频总线（如 "SFX"）
   - **Randomization**: 配置音高、音量随机化
   - **Mixing Config**: 配置播放限额和鸭霸规则

---

## 核心概念

### JuicyMixer 架构

JuicyMixer 采用分层架构设计：

```
┌─────────────────────────────────┐
│      JuicyMixer (全局接口)       │
├─────────────────────────────────┤
│     JuicyContext (运行时上下文)   │
├─────────────────────────────────┤
│  JuicyFeedback (反馈资源)        │
├─────────────────────────────────┤
│   JuicyTrack (轨道系统)          │
├─────────────────────────────────┤
│  JuicyDriver (驱动器)           │
├─────────────────────────────────┤
│   Middleware (中间件)           │
└─────────────────────────────────┘
```

### 主要组件

#### JuicyMixer
- 全局单例接口
- 管理所有Context
- 提供便捷的播放方法

#### JuicyContext
- 运行时执行环境
- 管理多个反馈同时播放
- 支持优先级和中断

#### JuicyFeedback
- 音频反馈资源
- 包含轨道和参数
- 支持参数映射

#### JuicyTrack
- 时间线轨道
- 支持多种类型：
  - Property Track（属性变化）
  - Shake Track（震动）
  - Spring Track（弹簧）
  - Tween Track（补间）

---

## 音频管理器系统

v3.0 版本引入了专业级音频管理器系统，提供了完整的音频播放、随机化、混音和事件集成功能。

### 系统架构

```
┌──────────────────────────────────────────┐
│   AudioEventResource (事件资源)          │
│   ├── event_name, priority, delay        │
│   ├── player_type, audio_bus             │
│   ├── audio_variants (变体列表)          │
│   ├── randomization (随机化配置)         │
│   └── mixing_config (混音配置)           │
├──────────────────────────────────────────┤
│   AudioVariant (音频变体)                │
│   ├── audio_stream (音频文件)            │
│   ├── weight (权重)                      │
│   └── volume_db, pitch_scale             │
├──────────────────────────────────────────┤
│   AudioRandomizationConfig (随机化)      │
│   ├── pitch_range, volume_range          │
│   ├── start_position_range              │
│   └── seed (随机种子)                    │
├──────────────────────────────────────────┤
│   DuckingRule (鸭霸规则)                 │
│   ├── target_bus (目标总线)             │
│   ├── volume_db (降低分贝)               │
│   ├── fade_in/out_time                   │
│   └── recovery_delay (恢复延迟)          │
├──────────────────────────────────────────┤
│   AudioMixingConfig (混音配置)           │
│   ├── instance_limit (播放限额)          │
│   ├── limit_policy (限额策略)            │
│   ├── priority (优先级)                  │
│   └── ducking_rules (鸭霸规则列表)       │
├──────────────────────────────────────────┤
│   AudioMixingController (混音控制器)     │
│   └── 管理实例限制、鸭霸、优先级         │
├──────────────────────────────────────────┤
│   AudioVariationManager (变体管理器)     │
│   └── 选择变体、应用随机化               │
└──────────────────────────────────────────┘
```

### 核心功能

#### 1. 音频变体系统 (Audio Variants)

为同一事件提供多个音频变体，避免重复感：

```gdscript
# 创建 AudioEventResource
var footstep_event = AudioEventResource.new()
footstep_event.event_name = "footstep"

# 添加多个变体
var variant1 = AudioVariant.new()
variant1.audio_stream = preload("res://audio/footstep_1.wav")
variant1.weight = 1.0
variant1.volume_db = 0.0
variant1.pitch_scale = 1.0

var variant2 = AudioVariant.new()
variant2.audio_stream = preload("res://audio/footstep_2.wav")
variant2.weight = 1.5  # 更高权重，更频繁
variant2.volume_db = -1.0
variant2.pitch_scale = 1.1

var variant3 = AudioVariant.new()
variant3.audio_stream = preload("res://audio/footstep_3.wav")
variant3.weight = 0.8  # 较低权重，较少出现
variant3.volume_db = -2.0
variant3.pitch_scale = 0.95

footstep_event.audio_variants = [variant1, variant2, variant3]
```

**权重说明**：
- 权重越高，变体被选中的概率越大
- 权重为 0.0 的变体不会被选中
- 相同权重时均匀分布

#### 2. 参数随机化 (Randomization)

自动随机化音高、音量和起始位置，增加自然感：

```gdscript
# 配置随机化
var randomization = AudioRandomizationConfig.new()
randomization.enabled = true

# 音高随机化 ±0.2 (0.8 - 1.2)
randomization.pitch_range = 0.2

# 音量随机化 ±3dB
randomization.volume_range = 3.0

# 起始位置随机化 ±0.5秒
randomization.start_position_range = 0.5

# 固定随机种子（用于可重现的测试）
randomization.fixed_seed = true
randomization.seed = 12345

footstep_event.randomization = randomization
```

**随机化效果**：
- 每次播放时自动应用随机变化
- 避免机械感的重复
- 可选固定种子用于调试

#### 3. 动态鸭霸 (Ducking)

播放时自动降低其他总线的音量：

```gdscript
# 创建混音配置
var mixing_config = AudioMixingConfig.new()

# 配置对白鸭霸：播放时降低音乐音量
var voice_ducking = DuckingRule.new()
voice_ducking.target_bus = "Music"      # 降低音乐总线
voice_ducking.volume_db = -12.0          # 降低 12dB
voice_ducking.fade_in_time = 0.2         # 0.2秒淡入
voice_ducking.fade_out_time = 0.5        # 0.5秒淡出
voice_ducking.recovery_delay = 0.3       # 延迟 0.3秒恢复

# 配置音效限额：最多同时播放 5 个
mixing_config.instance_limit = 5
mixing_config.limit_policy = AudioMixingConfig.LimitPolicy.STOP_NEWEST
mixing_config.priority = 10

mixing_config.ducking_rules = [voice_ducking]

footstep_event.mixing_config = mixing_config
```

**鸭霸场景**：
- 对白播放时降低音乐/音效
- 重要音效播放时降低背景音
- 多个音频事件的优先级管理

**限额策略**：

**实例级限额策略 (Instance Limit Policy)**：
- `FIFO` (First In, First Out)：达到限额时停止最早的实例
- `LIFO` (Last In, First Out)：达到限额时停止最新的实例
- `PRIORITY`：基于优先级决定停止哪个实例
- `NEWEST_STEALS_OLDEST`：新声音会"偷取"最老声音的播放器（淡出老声音，淡入新声音）
- `FADE_OUT_OLDEST`：淡出最老的实例，但不停止
- `FADE_IN_NEWEST`：淡入新实例，可能超额播放
- `CROSSFADE`：新老声音交叉淡入淡出

**类别级限额 (Category-Level)**：
- 通过 AudioCategory 设置类别最大实例数
- 智能优先级排序（距离 + 重要性 + 时间）
- 类别优先级覆盖

**全局级限额 (Global-Level)**：
- GlobalAudioLimitConfig 设置总声部上限
- 虚声部系统（Virtual Voices）
- 总线级限制（Master、Music、SFX、Voice）

#### 4. 2D/3D 自动检测

根据播放位置自动选择 2D 或 3D 音频播放器：

```gdscript
# 在编辑器中设置
footstep_event.player_type = AudioEventResource.AudioPlayerType.AUTO_DETECT

# 系统会自动判断：
# - 有 global_position → 使用 AudioStreamPlayer3D
# - 无 global_position → 使用 AudioStreamPlayer2D
# - 可显式指定 PLAYER_2D 或 PLAYER_3D
```

**3D 音频参数**：
```gdscript
footstep_event.max_distance = 100.0       # 最大距离
footstep_event.max_distance_db = -80.0    # 最大距离处音量
footstep_event.audio_bus = "SFX"          # 音频总线
```

### 与事件系统集成

AudioEventResource 继承自 JuicyEventResource，可以无缝集成到事件系统：

```gdscript
# 方式1：使用 JuicyAudioEventHandler
extends Node

var _audio_handler: JuicyAudioEventHandler

func _ready():
    _audio_handler = JuicyAudioEventHandler.new()
    add_child(_audio_handler)

    # 注册音频事件
    var footstep_event = preload("res://audio_events/footstep.tres")
    _audio_handler.register_audio_event("footstep", footstep_event)

    # 播放音频事件
    _audio_handler.play_audio_event("footstep", self)

# 方式2：使用 AudioEventResource 创建 JuicyEvent
func play_audio_at_position(position: Vector3):
    var event_resource = preload("res://audio_events/explosion.tres")
    var juicy_event = event_resource.create_event(self)

    # 设置位置
    juicy_event.global_position = position

    # 通过 JuicyMixer 播放
    JuicyMixer.get_singleton().play_event(juicy_event)

# 方式3：在 Bricks 系统中使用
# 在 Bricks 事件系统中，可以创建 "播放音频" 指令
# 直接使用 AudioEventResource 作为配置
```

### 创建音频事件资源

#### 在编辑器中创建：

1. **右键点击文件系统面板**
2. **选择 创建 → Resource**
3. **搜索并选择 "AudioEventResource"**
4. **命名并保存**（例如：`res://audio_events/footstep.tres`）

#### 配置音频事件：

在 Inspector 面板中配置：

**基础属性** (继承自 JuicyEventResource)：
- **Event Name**: 事件名称（例如："footstep"）
- **Priority**: 优先级（0-100，数值越高越重要）
- **Delay**: 播放延迟（秒）

**音频属性**：
- **Player Type**: 播放器类型（AUTO_DETECT/PLAYER_2D/PLAYER_3D）
- **Audio Bus**: 音频总线（例如："SFX", "Music", "Master"）
- **Max Distance**: 最大距离（3D音频）
- **Max Distance dB**: 最大距离处的音量衰减

**变体配置**：
- **Audio Variants**: 变体数组
  - 点击展开添加变体
  - 每个变体可设置：
    - Audio Stream: 音频文件
    - Weight: 权重
    - Volume dB: 音量偏移
    - Pitch Scale: 音调缩放

**随机化配置**：
- **Randomization**: AudioRandomizationConfig 资源
  - Enabled: 启用随机化
  - Pitch Range: 音高范围
  - Volume Range: 音量范围
  - Start Position Range: 起始位置范围
  - Fixed Seed: 固定随机种子

**混音配置**：
- **Mixing Config**: AudioMixingConfig 资源
  - Instance Limit: 播放实例限额
  - Limit Policy: 限额策略
  - Priority: 优先级
  - Ducking Rules: 鸭霸规则数组

### 完整使用示例

```gdscript
extends Node

## 角色控制器示例

var _audio_handler: JuicyAudioEventHandler
var _footstep_event: AudioEventResource
var _jump_event: AudioEventResource
var _land_event: AudioEventResource

func _ready():
    # 初始化音频处理器
    _audio_handler = JuicyAudioEventHandler.new()
    add_child(_audio_handler)

    # 预加载音频事件
    _footstep_event = preload("res://audio_events/footstep.tres")
    _jump_event = preload("res://audio_events/jump.tres")
    _land_event = preload("res://audio_events/land.tres")

    # 注册事件
    _audio_handler.register_audio_event("footstep", _footstep_event)
    _audio_handler.register_audio_event("jump", _jump_event)
    _audio_handler.register_audio_event("land", _land_event)

func _on_footstep():
    # 播放脚步声
    # 系统会自动：
    # 1. 从变体中随机选择一个音频
    # 2. 应用随机化（音高、音量、起始位置）
    # 3. 应用鸭霸规则（如果有）
    # 4. 检查播放限额（实例级、类别级、全局级）
    # 5. 根据位置选择 2D/3D 播放器
    _audio_handler.play_audio_event("footstep", self)

func _on_jump():
    _audio_handler.play_audio_event("jump", self)

func _on_land(impact_velocity: float):
    # 可以在运行时调整参数
    var land_event = _land_event.duplicate(true)

    # 根据落地速度调整音量
    if impact_velocity > 20.0:
        land_event.audio_variants[0].volume_db = 6.0  # 更大声
    else:
        land_event.audio_variants[0].volume_db = 0.0

    _audio_handler.play_audio_event_direct(land_event, self)

func _on_dialog_start():
    # 对白开始时，音乐自动降低（通过鸭霸规则）
    var dialog_event = preload("res://audio_events/dialogue.tres")
    _audio_handler.play_audio_event_direct(dialog_event, self)

func _on_dialog_end():
    # 对白结束，音乐自动恢复
    # AudioMixingController 会自动处理恢复延迟
    pass
```

### 类别级配置（Category-Level）

AudioCategory 允许你为某一类音频设置统一的限额规则和优先级。

#### 创建类别配置

```gdscript
# 创建 SFX 类别
var sfx_category = AudioCategory.new()
sfx_category.category_name = "SFX"
sfx_category.max_instances = 10          # 最多同时播放 10 个 SFX
sfx_category.priority = 50               # 默认优先级
sfx_category.importance = 0.7            # 重要性权重（用于智能排序）

# 创建 Music 类别
var music_category = AudioCategory.new()
music_category.category_name = "Music"
music_category.max_instances = 5         # 最多同时播放 5 个音乐
music_category.priority = 80             # 音乐优先级更高
music_category.importance = 0.9          # 高重要性

# 创建 Voice 类别
var voice_category = AudioCategory.new()
voice_category.category_name = "Voice"
voice_category.max_instances = 3         # 最多同时播放 3 个语音
voice_category.priority = 100            # 最高优先级
voice_category.importance = 1.0          # 最高重要性
```

#### 在编辑器中配置类别

1. **创建类别资源**：
   - 右键点击文件系统
   - 创建 → Resource
   - 搜索 "AudioCategory"
   - 命名为 `sfx_category.tres`

2. **配置类别属性**：
   - **Category Name**: 类别名称（如 "SFX", "Music", "Voice"）
   - **Max Instances**: 类别最大实例数
   - **Priority**: 类别默认优先级（0-100）
   - **Importance**: 重要性权重（0.0-1.0）
   - **Enable Priority Override**: 启用优先级覆盖
   - **Override Priority**: 覆盖优先级值

#### 应用类别到音频事件

```gdscript
# 将类别分配给音频事件
footstep_event.category = sfx_category
background_music_event.category = music_category
dialogue_event.category = voice_category
```

#### 智能优先级排序

当类别达到实例上限时，系统会自动根据以下规则排序现有实例：

```
优先级分数 = 距离权重 × (1 - 归一化距离) +
             重要性权重 × 重要性 +
             时间权重 × (1 - 归一化时间)

默认权重：
- 距离权重: 40%
- 重要性权重: 40%
- 时间权重: 20%
```

**排序示例**：
```gdscript
# 场景：同时有 10 个 SFX 在播放，要播放第 11 个

# 系统会评估：
for instance in active_sfx_instances:
    distance_score = 0.4 * (1.0 - instance.distance / max_distance)
    importance_score = 0.4 * instance.importance
    time_score = 0.2 * (1.0 - instance.played_time / max_time)
    total_score = distance_score + importance_score + time_score

# 优先停止分数最低的实例
```

### 全局级配置（Global-Level）

GlobalAudioLimitConfig 提供全局声部管理、虚声部系统和总线级限制。

#### 创建全局配置

```gdscript
# 创建全局配置
var global_config = GlobalAudioLimitConfig.new()

# 移动端配置
global_config.max_real_voices_mobile = 32
global_config.max_virtual_voices_mobile = 128

# 桌面端配置
global_config.max_real_voices_desktop = 64
global_config.max_virtual_voices_desktop = 256

# 启用虚声部
global_config.virtual_voice_enabled = true
global_config.virtual_max_distance = 100.0      # 超过 100 米转为虚声部
global_config.virtual_max_db = -20.0             # 低于 -20dB 转为虚声部

# 总线级限制
global_config.set_bus_limit("Master", 64)       # Master 总线最多 64 个声部
global_config.set_bus_limit("Music", 10)        # Music 总线最多 10 个声部
global_config.set_bus_limit("SFX", 32)          # SFX 总线最多 32 个声部
global_config.set_bus_limit("Voice", 8)         # Voice 总线最多 8 个声部

# 硬件监控（可选）
global_config.hardware_monitoring_enabled = true
global_config.max_cpu_usage = 0.8               # CPU 使用率超过 80% 时限制
global_config.max_memory_usage = 0.7            # 内存使用率超过 70% 时限制
```

#### 在编辑器中配置

1. **创建全局配置资源**：
   - 右键点击文件系统
   - 创建 → Resource
   - 搜索 "GlobalAudioLimitConfig"
   - 命名为 `global_audio_config.tres`

2. **配置属性**：

   **移动端设置**：
   - Max Real Voices (Mobile): 移动端实际声部上限（建议 16-32）
   - Max Virtual Voices (Mobile): 移动端虚声部上限（建议 64-128）

   **桌面端设置**：
   - Max Real Voices (Desktop): 桌面端实际声部上限（建议 48-64）
   - Max Virtual Voices (Desktop): 桌面端虚声部上限（建议 128-256）

   **虚声部设置**：
   - Virtual Voice Enabled: 启用虚声部
   - Virtual Max Distance: 最大距离（米）
   - Virtual Max dB: 最大音量阈值（dB）

   **总线限制**：
   - Bus Limits: 总线限额字典
     - Master: 64
     - Music: 10
     - SFX: 32
     - Voice: 8

   **硬件监控**：
   - Hardware Monitoring Enabled: 启用硬件监控
   - Max CPU Usage: 最大 CPU 使用率（0.0-1.0）
   - Max Memory Usage: 最大内存使用率（0.0-1.0）

#### 应用全局配置

```gdscript
# 在音频处理器中应用
var audio_handler = JuicyAudioEventHandler.new()
audio_handler.set_global_limit_config(global_config)
add_child(audio_handler)
```

#### 虚声部工作原理

虚声部（Virtual Voices）是一种优化技术，用于节省 CPU 和内存：

```gdscript
# 实例 1：距离近，实际播放
if distance < 50.0 and volume_db > -20.0:
    play_real_voice()  # 创建 AudioStreamPlayer，实际播放

# 实例 2：距离远，转为虚声部
elif distance > 100.0 or volume_db < -20.0:
    play_virtual_voice()  # 只记录逻辑，不创建播放器

# 虚声部状态：
# - 保留播放时间（用于恢复）
# - 保留循环信息
# - 不占用实际声部数
# - CPU 开销接近 0
```

**虚声部转换条件**：
1. **距离触发**: 超过 `virtual_max_distance`
2. **音量触发**: 低于 `virtual_max_db`
3. **总数触发**: 实际声部数达到上限

**虚声部恢复**：
```gdscript
# 当虚声部条件不再满足时
if virtual_voice.should_restore():
    # 自动恢复为实际播放
    virtual_voice.restore_to_real()
```

#### 三层架构协同工作

```gdscript
# 播放音频时的完整流程

func play_audio_event(event: AudioEventResource, target: Node):
    # 1. 全局级检查
    if not global_config.can_play_real_voice():
        # 转为虚声部或直接拒绝
        return play_virtual_or_reject(event)

    # 2. 总线级检查
    if not global_config.check_bus_limit(event.audio_bus):
        # 该总线已满
        return handle_bus_limit_exceeded(event)

    # 3. 类别级检查
    if event.category and event.category.is_full():
        # 类别已满，使用智能排序
        var victim = event.category.find_lowest_priority_instance()
        if victim:
            victim.stop()
        else:
            return # 无法腾出空间

    # 4. 实例级检查
    if not event.mixing_config.can_play_instance():
        # 应用实例级限额策略
        apply_instance_limit_policy(event.mixing_config.limit_policy)

    # 5. 所有检查通过，播放音频
    return play_audio_real(event, target)
```

### 相位保护机制

Phase Protection 防止多个相同或相似的音频同时播放导致相位抵消。

```gdscript
# 在 AudioMixingConfig 中配置
mixing_config.anti_phase_cancellation = true
mixing_config.phase_cooldown = 0.5  # 0.5 秒的相位冷却时间

# 系统会自动：
# - 检测相同音频文件的播放
# - 在冷却时间内拒绝新播放
# - 避免相位抵消导致的音量下降
```

**使用场景**：
```gdscript
# 错误示例：多个角色同时踩在金属地板
# 角色 A 播放 footstep_metal.wav
# 角色 B 同时播放 footstep_metal.wav
# 结果：相位抵消，声音听起来很弱

# 正确示例：启用相位保护
footstep_event.mixing.anti_phase_cancellation = true
footstep_event.mixing.phase_cooldown = 0.1
# 角色 A 播放 footstep_metal.wav
# 角色 B 在 0.1 秒内的播放请求被拒绝或延迟
# 结果：清晰的音效，无相位抵消
```

### 高级技巧

#### 1. 运行时修改配置

```gdscript
# 动态调整音效参数
func adjust_footstep_speed(speed: float):
    var event = _audio_handler.get_audio_event("footstep")

    # 根据速度调整音高
    event.randomization.pitch_range = speed * 0.1

    # 根据表面材质选择不同变体
    if current_surface == "metal":
        event.audio_variants[0].volume_db = -3.0
    elif current_surface == "grass":
        event.audio_variants[0].volume_db = 0.0
```

#### 2. 分层音频系统

```gdscript
# 创建分层音频管理
class AudioLayerManager:
    var _music_handler: JuicyAudioEventHandler
    var _sfx_handler: JuicyAudioEventHandler
    var _voice_handler: JuicyAudioEventHandler

    func _init(parent: Node):
        _music_handler = JuicyAudioEventHandler.new()
        _sfx_handler = JuicyAudioEventHandler.new()
        _voice_handler = JuicyAudioEventHandler.new()

        parent.add_child(_music_handler)
        parent.add_child(_sfx_handler)
        parent.add_child(_voice_handler)

    func play_music(event_name: String, target: Node):
        _music_handler.play_audio_event(event_name, target)

    func play_sfx(event_name: String, target: Node):
        _sfx_handler.play_audio_event(event_name, target)

    func play_voice(event_name: String, target: Node):
        # 播放语音时自动降低音乐和音效
        _voice_handler.play_audio_event(event_name, target)
```

#### 3. 音频池管理

```gdscript
# 使用对象池优化性能
var _audio_pool: Array[AudioEventResource] = []

func get_pooled_event(original: AudioEventResource) -> AudioEventResource:
    if _audio_pool.is_empty():
        return original.duplicate(true)

    var pooled = _audio_pool.pop_back()
    pooled.copy_from(original)
    return pooled

func return_event_to_pool(event: AudioEventResource):
    _audio_pool.append(event)
```

---

## JuicyMixer通用反馈系统

> **注意**: 本章节介绍的是 JuicyMixer 的通用反馈系统（使用 `JuicyFeedback`），这与前面介绍的 AudioManager 系统（使用 `AudioEventResource`）是不同的。
>
> - **AudioManager 系统**: 专门用于音频播放管理，支持变体、随机化、三层限额等高级功能
> - **通用反馈系统**: 支持多种反馈类型（震动、弹簧、补间动画等），不仅限于音频
>
> 如果您只需要播放音频，建议使用前面的 AudioManager 系统。

### 创建简单的反馈

1. **基础音频反馈**：
```gdscript
# 创建简单的播放反馈
var feedback = preload("res://audio_feedbacks/jump_feedback.tres")

func _on_player_jumped():
    mixer.play_feedback(feedback)
```

2. **带参数的反馈**：
```gdscript
# 创建带参数的反馈
var feedback = preload("res://audio_feedbacks/impact_feedback.tres")

func _on_impact_hit(intensity: float):
    # 设置强度参数
    var params = {"intensity": intensity}
    mixer.play_feedback(feedback, params)
```

### 使用参数映射

参数映射允许将游戏参数动态映射到音频效果：

```gdscript
# 在音频反馈资源中配置参数映射
# 例如：将角色速度映射到音调
# 参数名: speed
# 目标属性: pitch_scale
# 映射公式: pitch_scale = 1.0 + speed * 0.1

func _on_player_velocity_changed(speed: float):
    var params = {"speed": speed}
    mixer.play_feedback("footstep_feedback", params)
```

### 管理反馈组

```gdscript
# 创建反馈组
var combat_group = mixer.create_context("combat")
var ui_group = mixer.create_context("ui")

# 在特定组中播放
combat_group.play_feedback("sword_hit")
ui_group.play_feedback("button_click")

# 组级别的音量控制
combat_group.set_group_volume(0.8)
```

---

## 高级功能

### 1. 时间线编辑器

JuicyMixer 提供可视化的时间线编辑器：

1. 在 文件系统 中右键选择 创建 → Juicy Timeline Resource
2. 编辑器会自动打开时间线编辑面板
3. 添加不同类型的轨道：
   - 音频轨道
   - 属性变化轨道
   - 事件轨道

#### 时间线操作：

```gdscript
# 创建复杂的时间线反馈
var timeline = preload("res://combat_timeline.tres")

# 播放复杂动画序列
func play_attack_combo():
    mixer.play_timeline(timeline)
```

### 2. 中间件系统

中间件允许自定义音频处理流程：

```gdscript
# 创建自定义中间件
extends JuicyMiddleware

func process_feedback(feedback: JuicyFeedback, params: Dictionary) -> Dictionary:
    # 自定义处理逻辑
    if params.has("damage"):
        # 根据伤害值调整音量
        feedback.volume *= min(2.0, params.damage / 50.0)

    return params
```

### 3. 事件系统

```gdscript
# 注册事件监听
mixer.register_event_listener("player_death", _on_player_death)

# 触发事件
func kill_player():
    mixer.trigger_event("player_death")

# 事件处理
func _on_player_death():
    mixer.play_feedback("death_splash")
```

### 4. 对象池管理

为性能优化，JuicyMixer 使用对象池：

```gdscript
# 获取Context池
var pool = mixer.get_context_pool()

# 使用池化的Context
var context = pool.get_context()
context.play_feedback("explosion")
pool.return_context(context)
```

### 5. 通道管理

```gdscript
# 创建特定通道
var music_channel = mixer.create_channel("music")
var sfx_channel = mixer.create_channel("sfx")

# 通道级别控制
music_channel.set_volume(0.6)
sfx_channel.set_volume(1.0)

# 在通道中播放
music_channel.play_feedback("background_music")
sfx_channel.play_feedback("explosion")
```

---

## 最佳实践

### 1. 文件组织

```
res://
├── audio/
│   ├── music/
│   ├── sfx/
│   └── voices/
├── audio_feedbacks/
│   ├── character/
│   ├── ui/
│   └── environment/
├── timelines/
│   ├── combat/
│   ├── cutscenes/
│   └── ui/
└── audio_configs/
    ├── master_config.tres
    └── channel_configs/
```

### 2. 命名规范

- 音频反馈文件：`[category]_[action]_feedback.tres`
  - 例如：`character_jump_feedback.tres`
  - 例如：`ui_button_click_feedback.tres`
- 时间线文件：`[scene]_[event]_timeline.tres`
  - 例如：`combat_attack_combo_timeline.tres`
- 参数名：使用描述性的名称
  - 例如：`damage`, `intensity`, `speed`, `duration`

### 3. 性能优化

```gdscript
# 1. 预加载音频反馈
var jump_feedback = preload("res://audio_feedbacks/jump_feedback.tres")
var hit_feedback = preload("res://audio_feedbacks/hit_feedback.tres")

# 2. 使用Context池
var context_pool = mixer.get_context_pool()

# 3. 批量操作
func play_impact_effects(position: Vector3, count: int):
    for i in range(count):
        var context = context_pool.get_context()
        context.global_position = position
        context.play_feedback(hit_feedback)
        # 不要立即返回，让池管理器处理
```

### 4. 内存管理

```gdscript
# 场景切换时清理
func _exit_tree():
    # 清理Context
    mixer.cleanup_context(self)

    # 卸载未使用的资源
    ResourceLoader.unload("res://unused_audio.tres")
```

### 5. 参数设计

```gdscript
# 好的参数设计
var impact_params = {
    "intensity": 0.5,      # 0.0 - 1.0
    "surface": "metal",   # 字符串类型
    "distance": 10.0      # 实际距离值
}

# 避免的参数设计
var bad_params = {
    "loud": true,         # 布尔值不够灵活
    "type": 1,            # 魔法数字
    "random": randf()     # 随机性应该在内部处理
}
```

---

## 故障排除

### 常见问题

#### 1. 听不到声音

**可能原因及解决方案：**

- **音频总线配置错误**
  - 检查项目设置中的音频总线
  - 确保音频反馈分配到了正确的总线

- **音量设置过低**
  ```gdscript
  # 检查音量设置
  var feedback = preload("your_feedback.tres")
  print("Volume: ", feedback.volume)  # 应该 > 0
  ```

- **音频文件未加载**
  ```gdscript
  # 检查音频流
  if feedback.audio_stream == null:
      print("Error: Audio stream is null")
  else:
      print("Audio loaded successfully")
  ```

#### 2. 时间线编辑器不工作

**可能原因及解决方案：**

- **插件未正确启用**
  - 确认插件已启用并重启编辑器
  - 检查编辑器底部是否有 "Juicy Timeline" 面板

- **轨道配置错误**
  - 检查轨道类型是否匹配
  - 验证关键帧数据是否正确

#### 3. 参数映射不生效

**调试参数映射：**

```gdscript
# 启用调试日志
mixer.set_debug_enabled(true)

# 检查参数值
var params = {"intensity": 1.0}
mixer.play_feedback(feedback, params)
```

#### 4. 内存泄漏

**检查内存使用：**

```gdscript
# 获取内存统计
var stats = mixer.get_memory_stats()
print("Active contexts: ", stats.active_contexts)
print("Pool size: ", stats.pool_size)
```

#### 5. 性能问题

**性能优化建议：**

- 使用对象池而非频繁创建/销毁Context
- 限制同时播放的反馈数量
- 使用LOD（细节层次）系统根据距离调整质量

### 调试工具

JuicyMixer 提供内置调试工具：

```gdscript
# 启用调试模式
mixer.enable_debug_mode(true)

# 获取调试信息
var debug_info = mixer.get_debug_info()
for context in debug_info.contexts:
    print("Context: ", context.id)
    print("Active feedbacks: ", context.feedback_count)
```

---

## 示例场景

### 1. 角色系统

```gdscript
# 角色管理器
extends Node

var mixer = JuicyMixer.get_singleton()
var character_context: JuicyContext

func _ready():
    # 创建角色专用Context
    character_context = mixer.create_context("character")

    # 连接信号
    $Player.connect("jumped", _on_player_jumped)
    $Player.connect("landed", _on_player_landed)
    $Player.connect("damaged", _on_player_damaged)

func _on_player_jumped(height: float):
    # 根据跳跃高度调整音效
    var params = {"jump_height": height}
    character_context.play_feedback("jump", params)

func _on_player_landed(impact: float):
    var params = {"impact_force": impact}
    character_context.play_feedback("land", params)

func _on_player_damaged(damage: float):
    var params = {
        "damage_amount": damage,
        "health_percentage": $Player.health / $Player.max_health
    }
    character_context.play_feedback("damage", params)
```

### 2. UI系统

```gdscript
# UI音效管理器
extends Node

var mixer = JuicyMixer.get_singleton()
var ui_context: JuicyContext

func _ready():
    ui_context = mixer.create_context("ui")

    # 注册UI按钮
    register_buttons($MainMenu)
    register_buttons($PauseMenu)

func register_buttons(container: Node):
    for button in container.get_children():
        if button is Button:
            button.connect("pressed", _on_button_pressed.bind(button.name))

func _on_button_pressed(button_name: String):
    var feedback_name = "ui_%s_press" % button_name.to_lower()
    ui_context.play_feedback(feedback_name)
```

### 3. 环境音效

```gdscript
# 环境音效管理器
extends Node

var mixer = JuicyMixer.get_singleton()
var env_context: JuicyContext

func _ready():
    env_context = mixer.create_context("environment")
    env_context.global_position = global_position

    # 启动环境音
    play_ambient_sound()

func play_ambient_sound():
    # 播放环境音效循环
    var feedback = preload("res://audio_feedbacks/ambience_forest.tres")
    env_context.play_feedback(feedback)

func on_weather_changed(weather: String):
    # 天气变化音效
    var weather_feedback = "ambience_%s" % weather
    env_context.play_feedback(weather_feedback)
```

### 4. 战斗系统

```gdscript
# 战斗系统
extends Node

var mixer = JuicyMixer.get_singleton()
var combat_context: JuicyContext

func _ready():
    combat_context = mixer.create_context("combat")

    # 创建战斗时间线
    setup_combat_timeline()

func setup_combat_timeline():
    # 使用时间线创建复杂的连击音效
    var combo_timeline = preload("res://timelines/combo_attack_timeline.tres")

    # 连击信号
    $Player.connect("combo_started", _on_combo_started)
    $Player.connect("combo_hit", _on_combo_hit)
    $Player.connect("combo_finished", _on_combo_finished)

func _on_combo_started(combo_level: int):
    var params = {"combo_level": combo_level}
    combat_context.play_timeline("combo_start_timeline", params)

func _on_combo_hit(hit_type: String):
    var feedback = "combat_%s_hit" % hit_type
    combat_context.play_feedback(feedback)

func _on_combo_finished(final_damage: float):
    var params = {"final_damage": final_damage}
    combat_context.play_feedback("combo_finish", params)
```

---

## API 参考

### JuicyMixer API

#### 静态方法

```gdscript
# 获取单例
func get_singleton() -> JuicyMixer

# 创建Context
func create_context(name: String) -> JuicyContext

# 播放反馈
func play_feedback(feedback: JuicyFeedback, params: Dictionary = {})

# 播放时间线
func play_timeline(timeline: JuicyTimelineResource, params: Dictionary = {})
```

### JuicyContext API

```gdscript
# 播放反馈
func play_feedback(feedback: JuicyFeedback, params: Dictionary = {})

# 播放时间线
func play_timeline(timeline: JuicyTimelineResource, params: Dictionary = {})

# 设置组音量
func set_group_volume(volume: float)

# 停止所有反馈
func stop_all_feedbacks()

# 清理Context
func cleanup()
```

---

## 更新日志

### v3.1.0 (2026-01-15)

#### 新增功能
- ✅ 三层限额架构（实例级、类别级、全局级）
- ✅ 7 种实例级限额策略（FIFO, LIFO, PRIORITY, NEWEST_STEALS_OLDEST, FADE_OUT_OLDEST, FADE_IN_NEWEST, CROSSFADE）
- ✅ AudioCategory 类别资源系统
- ✅ 智能优先级排序（距离 + 重要性 + 时间）
- ✅ GlobalAudioLimitConfig 全局配置
- ✅ VirtualVoiceManager 虚声部管理
- ✅ 总线级限额支持（Master、Music、SFX、Voice）
- ✅ 相位保护机制（防相位抵消）
- ✅ 硬件资源监控框架

#### 文档更新
- 📚 完整的类别级配置指南
- 📚 全局级配置指南
- 📚 虚声部系统说明
- 📚 三层架构协同工作流程
- 📚 Phase Protection 使用示例

### v3.0.0 (2026-01-14)

#### 新增功能
- ✅ 完整的音频反馈系统
- ✅ 可视化时间线编辑器
- ✅ 参数映射系统
- ✅ Context管理和对象池
- ✅ 中间件架构
- ✅ 事件系统
- ✅ 通道管理
- ✅ 优先级和中断系统
- ✅ 调试工具

#### 优化改进
- 🚀 性能优化（对象池）
- 🚀 内存管理改进
- 🚅 错误处理增强
- 🚅 编辑器体验优化

---

## 支持

如果遇到问题，请：

1. 查看故障排除章节
2. 启用调试模式查看日志
3. 检查示例场景
4. 参考API文档

更多信息和更新，请访问：
- 项目文档：`docs/` 目录
- 开发文档：`addons/juicy_mixer/docs/dev_docs/`