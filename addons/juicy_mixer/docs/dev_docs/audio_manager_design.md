# JuicyMixer 音频管理器技术设计文档

**文档版本**: 1.4
**创建日期**: 2026-01-14
**状态**: 阶段 1 和阶段 2 已完成
**目标阶段**: 阶段 1（核心功能）+ 阶段 2（三层限额架构）
**最后更新**: 2026-01-17

**更新日志**:
- v1.4 (2026-01-17): 添加实际实现总结 - AudioManager 配置中心模式、完整事件流程、ContextType 类型系统
- v1.3 (2026-01-15): 阶段 2 完成 - 三层限额架构完整实现
- v1.2 (2026-01-14): 架构优化 - AudioEventResource 现在继承自 JuicyEventResource
- v1.1 (2026-01-14): 初始版本 - 阶段 1 核心功能设计

> **重要更新**: 播放限额（Voice Management）功能已升级为专业的**多层级架构**。详细设计请参考 [audio_manager_voice_management_enhanced.md](./audio_manager_voice_management_enhanced.md)。
>
> 本文档中标注 `> **重要提示**: ...` 的部分，说明该功能有更详细的增强版本。

---

## 📋 目录

- [1. 概述](#1-概述)
- [2. 设计目标](#2-设计目标)
- [3. 架构设计](#3-架构设计)
- [4. 数据结构定义](#4-数据结构定义)
- [5. 核心类设计](#5-核心类设计)
- [6. 扩展方案](#6-扩展方案)
- [7. 文件结构](#7-文件结构)
- [8. 实现计划](#8-实现计划)
- [9. API 使用示例](#9-api-使用示例)
- [10. 测试计划](#10-测试计划)
- [11. 阶段 2-3 预览](#11-阶段-2-3-预览)
- [12. 附录](#12-附录)

> **提示**: 播放限额功能已升级为多层级架构，详细信息请参考 [audio_manager_voice_management_enhanced.md](./audio_manager_voice_management_enhanced.md)。

---

## 1. 概述

### 1.1 文档目的

本文档详细描述 JuicyMixer 音频管理器的技术设计方案，包括数据结构、核心类、实现计划和 API 设计。该音频管理器基于现有的 `JuicyEvent` 和 `JuicyAudioEventHandler` 架构扩展实现。

### 1.2 设计原则

- **向后兼容**: 保持现有 `JuicyAudioEventHandler` 的所有功能不变
- **渐进增强**: 在现有基础上添加新功能，而非重写
- **模块化**: 核心功能通过独立管理器实现，易于测试和维护
- **扩展性**: 为未来阶段的空间化、RTPC、交互式音乐预留接口

### 1.3 技术栈

- **Godot 4.5**: 游戏引擎版本
- **GDScript**: 主要编程语言
- **Resource 系统**: 配置和序列化
- **RefCounted**: 无状态管理器基类
- **事件系统**: 基于 JuicyEvent 的事件驱动架构

---

## 2. 设计目标

### 2.1 阶段 1：核心音频管理（已完成）

#### 2.1.1 基础播放与变体 (Randomization & Variation)
- ✅ 随机容器 (Random Containers)
  - 从一组音效中随机抽取播放
- ✅ 参数随机化 (Pitch/Volume Randomization)
  - 每次触发时自动随机调整音量和音高
- ✅ 权重控制 (Weighting)
  - 设置不同变体的触发概率
- ✅ 防重复机制 (Shuffle/No-Repeat)
  - 确保同一个声音不会连续播放两次

#### 2.1.2 混音与优先级管理 (Mixing & Priority)
- ✅ 动态鸭霸/避让 (Dynamic Ducking)
  - 当某些声音播放时，自动降低其他类别音量
- ✅ 虚声部 (Virtual Voices)
  - 超出可听范围时停止播放，保留逻辑计时
- ✅ 播放限额 (Instance Limiting) - **已完成三层架构**
  - 限制同一时间内某种音效的最大播放数量
  - **实例级限额**: 7 种策略（FIFO, LIFO, PRIORITY, NEWEST_STEALS_OLDEST, FADE_OUT_OLDEST, FADE_IN_NEWEST, CROSSFADE）
  - **类别级限额**: AudioCategory 支持，智能优先级排序
  - **全局级限额**: GlobalAudioLimitConfig，虚声部系统
  - 详细设计请参考 [audio_manager_voice_management_enhanced.md](./audio_manager_voice_management_enhanced.md)

#### 2.1.3 2D/3D 音频支持
- ✅ 自动检测目标节点类型
- ✅ 同时支持 2D 和 3D 播放器
- ✅ 独立的播放器池管理

### 2.2 阶段 2：三层限额架构（已完成）

**核心功能**：
- ✅ **实例级限额 (Instance-Level)**
  - 7 种限额策略（FIFO, LIFO, PRIORITY, NEWEST_STEALS_OLDEST, FADE_OUT_OLDEST, FADE_IN_NEWEST, CROSSFADE）
  - 相位保护机制（防相位抵消）
  - 实例优先级覆盖

- ✅ **类别级限额 (Category-Level)**
  - AudioCategory 资源类
  - 类别最大实例数限制
  - 智能优先级排序（距离 40% + 重要性 40% + 时间 20%）
  - 类别优先级系统

- ✅ **全局级限额 (Global-Level)**
  - GlobalAudioLimitConfig 资源类
  - 总声部上限配置（移动端/桌面端）
  - 虚声部管理（VirtualVoiceManager）
  - 总线级限制（Master、Music、SFX、Voice）
  - 硬件资源监控框架

详细文档请参考 [AUDIO_MANAGER_PHASE2.md](./AUDIO_MANAGER_PHASE2.md)

### 2.3 阶段 3：空间化与 RTPC（计划中）

- 🟡 衰减曲线 (Attenuation Curves)
- 🟡 3D 空间定位 (3D Positioning)
- 🟡 遮挡与阻碍 (Obstruction & Occlusion)
- 🟡 RTPC 映射
- 🟡 状态切换 (States & Switches)

### 2.4 阶段 4：交互式音乐（计划中）

- 🟢 垂直分层 (Layering/Stems)
- 🟢 水平跳转 (Branching)
- 🟢 节拍回调 (Beat/Bar Callbacks)

---

## 3. 架构设计

### 3.1 整体架构图（已实现）

```
┌─────────────────────────────────────────────────────────────────┐
│                     JuicyAudioPlayer                             │
│                  (信号触发 - 用户层)                               │
├─────────────────────────────────────────────────────────────────┤
│  1. 信号连接 (AudioComponent)                                    │
│     ├─ 自动绑定节点信号                                          │
│     └─ 冷却管理                                                  │
├─────────────────────────────────────────────────────────────────┤
│  2. 事件创建                                                      │
│     ├─ 创建 JuicyEvent (AUDIO_PLAY)                              │
│     ├─ 封装 AudioEventResource                                   │
│     └─ 添加事件数据 (target, position)                           │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                    JuicyMixer                                    │
│              (统一事件入口 - 静态 API)                            │
├─────────────────────────────────────────────────────────────────┤
│  play_event(juicy_event, target, owner)                          │
│     ├─ 创建 JuicyContext.create_for_event()                      │
│     ├─ context_type = ContextType.EVENT                          │
│     └─ 调用 Director.play_event()                                │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                    JuicyDirector                                 │
│                  (调度核心)                                       │
├─────────────────────────────────────────────────────────────────┤
│  play_event(context)                                             │
│     ├─ 从对象池获取 Context                                      │
│     ├─ 设置 context_type = EVENT                                │
│     ├─ 复制事件到 Context                                       │
│     └─ 执行中间件管道                                            │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│              MiddlewarePipeline                                  │
│            (中间件管道 - 完整流程)                                 │
├─────────────────────────────────────────────────────────────────┤
│  1. ValidationMiddleware (类型安全验证)                          │
│     ├─ 检查 context_type == EVENT                               │
│     ├─ 验证事件存在                                              │
│     └─ 验证 target 有效                                          │
├─────────────────────────────────────────────────────────────────┤
│  2. EventHandlingMiddleware (事件调度)                           │
│     ├─ 接收事件 Context                                         │
│     ├─ 添加到 EventBuffer                                        │
│     └─ 调用 EventScheduler                                       │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│              JuicyEventScheduler                                 │
│             (事件调度器)                                          │
├─────────────────────────────────────────────────────────────────┤
│  process_events(event_buffer, delta)                             │
│     ├─ 分批处理事件                                              │
│     ├─ 按优先级排序                                              │
│     └─ 分发到 Handlers                                           │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│          JuicyAudioEventHandler (已注册)                          │
│              (音频事件处理器)                                     │
├─────────────────────────────────────────────────────────────────┤
│  handle_event(event)                                             │
│     ├─ 解析 AudioEventResource                                   │
│     ├─ 三层限额检查                                              │
│     ├─ 变体选择 (AudioVariationManager)                          │
│     ├─ 应用随机化                                                │
│     ├─ 创建播放器 (2D/3D)                                        │
│     └─ 播放音频                                                  │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│              AudioStreamPlayer (2D/3D)                           │
│                      播放音频                                      │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 AudioManager 配置中心模式（新增）

**实际实现架构**：

```
┌─────────────────────────────────────────────────────────────────┐
│                    AudioManager                                 │
│              (场景级配置节点)                                      │
├─────────────────────────────────────────────────────────────────┤
│  静态单例管理                                                      │
│  ├─ get_instance() - 获取单例                                    │
│  ├─ ensure_exists() - 自动创建                                   │
│  └─ has_instance() - 检查存在                                    │
├─────────────────────────────────────────────────────────────────┤
│  场景配置                                                          │
│  ├─ instance_mixing_config - 实例级混音配置                        │
│  ├─ global_limit_config - 全局限额配置                           │
│  └─ enable_debug_view - 调试视图                                  │
├─────────────────────────────────────────────────────────────────┤
│  事件系统集成                                                      │
│  ├─ _register_to_event_middleware() - 自动注册                  │
│  ├─ _audio_handler - AudioEventHandler 实例                      │
│  └─ 优先级 0（配置中心）                                         │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│         EventHandlingMiddleware                                  │
│          (事件处理中间件)                                         │
├─────────────────────────────────────────────────────────────────┤
│  已注册的 Handlers:                                               │
│  ├─ AudioEventHandler (优先级 0 - 来自 AudioManager)            │
│  └─ [未来可添加更多 Handler]                                      │
└─────────────────────────────────────────────────────────────────┘
```

**关键特性**：

1. **自动创建机制**
   - `AudioManager.ensure_exists()` 在运行时自动创建
   - 延迟到场景准备完成后执行
   - 使用 `call_deferred` 避免父节点设置问题

2. **配置中心模式**
   - AudioManager 作为统一的音频配置入口
   - 所有 JuicyAudioPlayer 共享同一个 AudioEventHandler
   - 场景级配置应用到所有音频播放

3. **延迟验证机制**
   - JuicyAudioPlayer 使用 `_verify_with_retry()` 轮询验证
   - 最多等待 10 帧确保 AudioManager 初始化完成
   - 避免场景初始化顺序问题

### 3.3 类型安全的 Context 系统（新增）

**ContextType 枚举**：

```gdscript
# JuicyContext 中的类型定义
enum ContextType {
    FEEDBACK,  # Feedback Resource 的 Context（需要 resource）
    EVENT,    # 事件的 Context（resource 为 null，需要 events）
}
```

**应用场景**：

1. **Context 创建**
   ```gdscript
   # Feedback Context - 需要 Resource
   var feedback_ctx = JuicyContext.create(resource, target)
   feedback_ctx.context_type == ContextType.FEEDBACK  # true

   # Event Context - 不需要 Resource
   var event_ctx = JuicyContext.create_for_event(target)
   event_ctx.context_type == ContextType.EVENT  # true
   ```

2. **ValidationMiddleware 类型验证**
   ```gdscript
   func _validate_basic_requirements(context: JuicyContext) -> bool:
       match context.context_type:
           ContextType.EVENT:
               # 验证事件存在
               return not context.get_events().is_empty()

           ContextType.FEEDBACK:
               # 验证 resource 存在
               return context.resource != null
   ```

3. **Director 类型标记**
   ```gdscript
   # play() - Feedback 类型
   func play(resource, target, owner):
       context.context_type = ContextType.FEEDBACK

   # play_event() - Event 类型
   func play_event(context):
       pooled_context.context_type = ContextType.EVENT
   ```

**架构优势**：
- ✅ **类型安全** - 编译时类型检查
- ✅ **代码清晰** - match 语句比嵌套 if 更易读
- ✅ **性能提升** - 避免重复的 `has_method()` 调用
- ✅ **易于扩展** - 未来可添加 SEQUENCE、TIMELINE 等类型

### 3.4 混合架构模式

根据设计决策，采用**混合方案**：

- **核心层**：增强型事件处理器（扩展 JuicyAudioEventHandler）
  - 变体管理
  - 混音控制

- **中间件层**：高级特性（阶段 2-3）
  - 空间化中间件
  - RTPC 中间件
  - 交互式音乐中间件

**优点**：
- 核心功能紧密集成，性能优异
- 高级特性模块化，灵活扩展
- 符合 JuicyMixer 现有架构风格

### 3.5 类继承关系

音频管理器采用了清晰的继承体系，符合面向对象设计原则：

```
Resource
│
├── JuicyEventResource (通用事件基类)
│   ├── event_type, event_id, event_name
│   ├── priority, delay, target_path
│   ├── event_data (Dictionary)
│   └── create_event() 方法
│
└── 音频管理器资源类
    ├── AudioEventResource (extends JuicyEventResource) ✅
    │   ├── audio_variants, randomization, mixing
    │   ├── player_type, audio_bus
    │   └── create_audio_play_event() 方法
    │
    ├── AudioVariant (extends Resource)
    │   └── 音频变体配置
    │
    ├── AudioRandomizationConfig (extends Resource)
    │   └── 全局随机化配置
    │
    ├── DuckingRule (extends Resource)
    │   └── 鸭霸规则
    │
    └── AudioMixingConfig (extends Resource)
        └── 混音配置
```

**设计原则**：
1. **IS-A 关系**: AudioEventResource **是**一种 JuicyEventResource
2. **代码复用**: 通过继承避免重复定义基础属性
3. **一致性**: 所有事件资源都继承自统一基类
4. **扩展性**: 未来可添加 VideoEventResource、ParticleEventResource 等

---

## 4. 数据结构定义

### 4.1 AudioEventResource（音频事件资源）

**文件**: `addons/juicy_mixer/resources/audio/audio_event_resource.gd`

```gdscript
@tool
class_name AudioEventResource
extends JuicyEventResource

enum AudioPlayerType {
    AUTO_DETECT,    # 自动检测（根据目标节点类型）
    PLAYER_2D,      # 强制使用 2D 播放器
    PLAYER_3D       # 强制使用 3D 播放器
}

# =============================================================================
# 基础配置
# =============================================================================

@export var player_type: AudioPlayerType = AudioPlayerType.AUTO_DETECT
@export var audio_bus: String = "Master"
@export var max_distance: float = 100.0
@export var max_distance_db: float = -80.0

# =============================================================================
# 变体配置
# =============================================================================

@export var audio_variants: Array[AudioVariant] = []
@export var randomization: AudioRandomizationConfig
@export var no_repeat_enabled: bool = true
@export var no_repeat_memory: int = 3

# =============================================================================
# 混音配置
# =============================================================================

@export var mixing: AudioMixingConfig

# =============================================================================
# 高级配置（阶段2-3）
# =============================================================================

@export var virtual_voice_enabled: bool = false
@export var virtual_max_distance: float = 50.0
@export var virtual_max_db: float = -20.0
@export var rtpc_mappings: Array[RTPCMapping] = []
```

**架构说明**:
- **继承关系**: `AudioEventResource` 继承自 `JuicyEventResource`
- **设计理由**:
  - AudioEvent **IS-A** JuicyEvent（音频事件是一种事件类型）
  - 复用父类的基础属性：`event_name`, `event_id`, `priority`, `delay`, `target_path`
  - 与现有事件系统完美集成
  - 符合面向对象设计的 IS-A 原则
- **继承优势**:
  - 无需重复定义 `event_name` 等基础属性
  - 自动获得父类的 `create_event()` 方法支持
  - 可以使用通用的事件处理逻辑
  - 类型系统保证事件类型正确性

**关键方法**:
- `_init()` - 设置 `event_type = AUDIO_PLAY`
- `create_audio_play_event(target: Node) -> JuicyEvent` - 创建音频播放事件
- `create_event(target: Node) -> JuicyEvent` - 重写父类方法，提供便捷接口
- `validate() -> Dictionary` - 验证配置有效性
- `get_total_weight() -> float` - 计算所有变体的总权重

---

### 4.2 AudioVariant（音效变体）

**文件**: `addons/juicy_mixer/resources/audio/audio_variant.gd`

```gdscript
@tool
class_name AudioVariant
extends Resource

# =============================================================================
# 基础属性
# =============================================================================

@export var audio_stream: AudioStream = null
@export var variant_name: String = ""
@export_range(0.1, 10.0, 0.1) var weight: float = 1.0

# =============================================================================
# 音高随机化
# =============================================================================

@export_group("Pitch Randomization", "pitch_")
@export var pitch_enabled: bool = false
@export_range(-12.0, 12.0, 0.1) var pitch_min: float = -0.5
@export_range(-12.0, 12.0, 0.1) var pitch_max: float = 0.5

# =============================================================================
# 音量随机化
# =============================================================================

@export_group("Volume Randomization", "volume_")
@export var volume_enabled: bool = false
@export_range(0.0, 2.0, 0.05) var volume_min: float = 0.9
@export_range(0.0, 2.0, 0.05) var volume_max: float = 1.1

# =============================================================================
# 其他参数
# =============================================================================

@export_group("Other", "other_")
@export_range(0.0, 10.0, 0.1) var start_offset: float = 0.0
@export var loop: bool = false
@export var loop_start: float = 0.0
@export var loop_end: float = 0.0
```

**关键方法**:
- `get_randomized_pitch() -> float`
- `get_randomized_volume() -> float`
- `validate() -> Dictionary`

---

### 4.3 AudioRandomizationConfig（随机化配置）

**文件**: `addons/juicy_mixer/resources/audio/audio_randomization_config.gd`

```gdscript
@tool
class_name AudioRandomizationConfig
extends Resource

# =============================================================================
# 全局随机化设置
# =============================================================================

@export var enabled: bool = true

@export_group("Global Pitch", "global_pitch_")
@export_range(-12.0, 12.0, 0.1) var global_pitch_min: float = -0.2
@export_range(-12.0, 12.0, 0.1) var global_pitch_max: float = 0.2

@export_group("Global Volume", "global_volume_")
@export_range(0.5, 1.5, 0.05) var global_volume_min: float = 0.95
@export_range(0.5, 1.5, 0.05) var global_volume_max: float = 1.05

@export var random_seed: int = 0
@export var use_fixed_seed: bool = false
```

**关键方法**:
- `initialize_random() -> void`
- `get_global_pitch_offset() -> float`
- `get_global_volume_offset() -> float`

---

### 4.4 AudioMixingConfig（混音配置）

**文件**: `addons/juicy_mixer/resources/audio/audio_mixing_config.gd`

> **重要提示**: 本文档中的 `AudioMixingConfig` 提供基础配置接口。播放限额功能已升级为专业的**多层级架构**，包括实例层、类别层和全局层，详细设计请参考 [audio_manager_voice_management_enhanced.md](./audio_manager_voice_management_enhanced.md)。

```gdscript
@tool
class_name AudioMixingConfig
extends Resource

# =============================================================================
# 播放限额配置
# =============================================================================

@export_group("Instance Limiting", "limiting_")
@export var max_instances: int = 5

enum InstanceLimitPolicy {
    STOP_OLDEST,
    STOP_NEWEST,
    STOP_LOWEST_PRIORITY,
    IGNORE_NEW
}
@export var limit_policy: InstanceLimitPolicy = InstanceLimitPolicy.STOP_OLDEST
@export_range(0, 100) var priority: int = 50

# =============================================================================
# 鸭霸配置
# =============================================================================

@export_group("Ducking Rules", "ducking_")
@export var ducking_rules: Array[DuckingRule] = []
@export_range(0.01, 5.0, 0.01) var ducking_fade_in: float = 0.1
@export_range(0.01, 5.0, 0.01) var ducking_fade_out: float = 0.5
@export var ducking_bus: String = "Master"
```

**关键方法**:
- `apply_to_player(player: AudioStreamPlayer, bus: String) -> void`
- `get_ducking_rule_for_event(event_name: String) -> DuckingRule`
- `validate() -> Dictionary`

> **多层级限额扩展**: `AudioMixingConfig` 支持扩展为多层级限额，详见增强文档。

---

### 4.5 DuckingRule（鸭霸规则）

**文件**: `addons/juicy_mixer/resources/audio/ducking_rule.gd`

```gdscript
@tool
class_name DuckingRule
extends Resource

# =============================================================================
# 鸭霸规则定义
# =============================================================================

@export var event_name_pattern: String = "*"
@export var target_bus: String = "Music"
@export_range(0.0, -40.0, 0.1) var duck_amount: float = -10.0
@export_range(0.0, 5.0, 0.1) var recovery_delay: float = 0.5
@export var enabled: bool = true
```

**关键方法**:
- `matches(event_name: String) -> bool`
- `apply_ducking(bus_index: int) -> void`
- `remove_ducking(bus_index: int) -> void`

---

## 5. 核心类设计

### 5.1 AudioVariationManager（变体管理器）

**文件**: `addons/juicy_mixer/core/audio/audio_variation_manager.gd`

**职责**:
- 根据权重选择音频变体
- 应用防重复逻辑
- 应用音高/音量随机化
- 管理播放历史记录

**状态管理**:
```gdscript
var _no_repeat_history: Dictionary = {}  # event_name -> Array[last_played_indices]
var _randomization_config: AudioRandomizationConfig = null
```

**关键接口**:
```gdscript
# 初始化
func _init(randomization_config: AudioRandomizationConfig = null)

# 变体选择
func select_variant(resource: AudioEventResource) -> AudioVariant
func apply_randomization(variant: AudioVariant, base_pitch: float = 1.0,
                         base_volume: float = 1.0) -> Dictionary

# 历史管理
func clear_history(event_name: String) -> void
func clear_all_history() -> void
```

**算法说明**:

1. **权重选择算法**:
   - 计算所有可用变体的总权重
   - 生成 0 到总权重之间的随机数
   - 遍历变体，累计权重，找到第一个超过随机数的变体

2. **防重复算法**:
   - 维护最近播放的 N 个变体索引
   - 选择时排除这些索引
   - 如果所有变体都被排除，回退到第一个变体

---

### 5.2 AudioMixingController（混音控制器）

**文件**: `addons/juicy_mixer/core/audio/audio_mixing_controller.gd`

> **重要提示**: 播放限额功能已升级为专业的**多层级架构**。本节描述基础实现，完整的三层限额架构（实例层、类别层、全局层）请参考 [audio_manager_voice_management_enhanced.md](./audio_manager_voice_management_enhanced.md)。

**职责**:
- 播放实例限额管理（基础版）
- 鸭霸规则应用和恢复
- 虚声部判断
- 实例生命周期管理

**状态管理**:
```gdscript
var _active_instances: Dictionary = {}  # event_name -> Array[player_info]
var _instance_limits: Dictionary = {}   # event_name -> max_instances
var _ducking_state: Dictionary = {}     # target_bus -> ducking_info
```

**关键接口**:
```gdscript
# 播放限额
func can_play(resource: AudioEventResource, event_name: String) -> bool
func record_instance(event_name: String, player: Object, priority: int) -> void
func remove_instance(event_name: String, player: Object) -> void

# 鸭霸管理
func apply_ducking(event_name: String, config: AudioMixingConfig) -> void
func remove_ducking(event_name: String, config: AudioMixingConfig) -> void
func update_ducking(delta: float) -> void

# 虚声部
func should_play_virtual(resource: AudioEventResource, listener: Node3D,
                        source_position: Vector3) -> bool

# 统计
func get_stats() -> Dictionary
```

**算法说明**:

1. **实例限额策略**（基础版）:
   - `STOP_OLDEST`: 停止开始时间最早的实例
   - `STOP_NEWEST`: 不播放新的
   - `STOP_LOWEST_PRIORITY`: 停止优先级最低的
   - `IGNORE_NEW`: 忽略新的播放请求

   > **扩展**: 完整版支持 7 种策略，包括 `NEWEST_STEALS_OLDEST`、`FADE_OUT_OLDEST`、`CROSSFADE` 等，详见增强文档。

2. **鸭霸恢复机制**:
   - 应用鸭霸时记录恢复时间戳
   - 每帧检查是否到达恢复时间
   - 延迟恢复（避免频繁切换）

> **多层级限额**: 增强版支持类别级别和全局级别限额，包括智能排序和虚声部系统。

---

### 5.3 AudioUtils（音频工具类）

**文件**: `addons/juicy_mixer/core/audio/audio_utils.gd`

**职责**:
- 提供静态工具方法
- 音频单位转换
- 播放器创建和配置

**关键接口**:
```gdscript
# 静态工具方法
static func linear_to_db(linear: float) -> float
static func db_to_linear(db: float) -> float
static func get_pitch_scale_from_semitones(semitones: float) -> float

# 播放器类型检测
static func detect_player_type(target: Node) -> AudioEventResource.AudioPlayerType

# 播放器创建
static func create_player_2d() -> AudioStreamPlayer2D
static func create_player_3d() -> AudioStreamPlayer3D

# 播放器配置
static func apply_pitch_and_volume(player: Object, pitch: float, volume: float) -> void
static func set_player_bus(player: Object, bus_name: String) -> void

# 验证
static func validate_audio_stream(stream: AudioStream) -> bool
static func get_audio_duration(stream: AudioStream) -> float
```

---

## 6. 扩展方案

### 6.1 JuicyAudioEventHandler 扩展

**文件**: `addons/juicy_mixer/events/juicy_audio_event_handler.gd`

#### 6.1.1 新增属性

```gdscript
# 核心管理器
var _variation_manager: AudioVariationManager = null
var _mixing_controller: AudioMixingController = null

# 扩展播放器池
var _player_pool_2d: Array[AudioStreamPlayer2D] = []
var _player_pool_3d: Array[AudioStreamPlayer3D] = []
```

#### 6.1.2 扩展方法

```gdscript
# 事件处理扩展
func _handle_audio_play_extended(event: JuicyEvent) -> bool
func _handle_audio_resource_play(resource: AudioEventResource, event: JuicyEvent) -> bool
func _handle_audio_play_legacy(event: JuicyEvent) -> bool

# 播放器管理扩展
func _get_audio_player_for_resource(resource: AudioEventResource)
func _get_audio_player_2d() -> AudioStreamPlayer2D
func _get_audio_player_3d() -> AudioStreamPlayer3D
func _configure_player_for_resource(player: Variant, resource: AudioEventResource,
                                     variant: AudioVariant, randomization: Dictionary,
                                     event: JuicyEvent) -> void

# 播放器返回扩展
func _return_audio_player(player: Variant) -> void

# 每帧更新
func process(delta: float) -> void
```

#### 6.1.3 处理流程

```
1. 接收 AUDIO_PLAY 事件
   │
2. 检查是否为 AudioEventResource
   ├─ 是: _handle_audio_resource_play()
   └─ 否: _handle_audio_play_legacy() (向后兼容)
   │
3. AudioEventResource 处理流程:
   ├─ 3.1 变体选择 (AudioVariationManager)
   ├─ 3.2 应用随机化
   ├─ 3.3 检查播放限额 (AudioMixingController)
   ├─ 3.4 获取播放器 (2D/3D 自动检测)
   ├─ 3.5 配置播放器
   ├─ 3.6 应用鸭霸
   ├─ 3.7 播放音频
   └─ 3.8 记录实例
```

#### 6.1.4 向后兼容

- 保留所有原有方法
- 保留原有播放器池 `_player_pool`（现在指向 2D 池）
- 所有未使用 `AudioEventResource` 的事件走传统处理路径
- 确保现有测试用例继续通过

---

## 7. 文件结构

### 7.1 完整目录树

```
addons/juicy_mixer/
├── resources/audio/                          # 新增：音频资源目录
│   ├── audio_event_resource.gd               # 独立音频事件资源
│   ├── audio_variant.gd                      # 音效变体定义
│   ├── audio_randomization_config.gd         # 随机化配置
│   ├── audio_mixing_config.gd                # 混音配置
│   ├── ducking_rule.gd                       # 鸭霸规则
│   ├── audio_category.gd                     # 类别定义（增强）
│   └── global_audio_limit_config.gd          # 全局限额配置（增强）
│
├── core/audio/                               # 新增：音频核心模块
│   ├── audio_variation_manager.gd            # 变体管理器
│   ├── audio_mixing_controller.gd             # 混音控制器
│   ├── virtual_voice_manager.gd               # 虚声部管理器（增强）
│   └── audio_utils.gd                        # 音频工具类
│
├── middleware/                               # 阶段2-3：中间件
│   ├── audio_spatial_middleware.gd           # 空间化中间件
│   └── audio_rtpc_middleware.gd              # RTPC中间件
│
├── events/
│   └── juicy_audio_event_handler.gd           # 扩展：增强音频处理器
│
├── tests/audio/                               # 新增：音频测试目录
│   ├── test_audio_variations.gd               # 变体测试
│   ├── test_audio_mixing.gd                   # 混音测试
│   ├── test_audio_2d_3d.gd                    # 2D/3D测试
│   ├── test_audio_integration.gd               # 集成测试
│   ├── test_audio_voice_management.gd          # 多层级限额测试（增强）
│   └── audio_demo_scene.tscn                  # 演示场景
│
└── docs/dev_docs/
    ├── audio_manager_design.md                # 本文档
    ├── audio_manager_voice_management_enhanced.md  # 多层级限额增强方案
    └── audio_manager_godot_integration.md      # Godot 原生集成说明
```

> **说明**: 标注 `（增强）` 的文件在 [audio_manager_voice_management_enhanced.md](./audio_manager_voice_management_enhanced.md) 中详细说明。

### 7.2 文件依赖关系

```
AudioEventResource
├── AudioVariant
├── AudioRandomizationConfig
├── AudioMixingConfig
│   └── DuckingRule
├── AudioCategory (增强）
└── RTPCMapping (阶段2)

JuicyAudioEventHandler
├── AudioVariationManager
│   └── AudioRandomizationConfig
├── AudioMixingController
│   └── AudioMixingConfig
└── AudioUtils

AudioMixingController (增强）
├── VirtualVoiceManager (增强）
│   └── GlobalAudioLimitConfig (增强）
└── 类别实例管理 (增强）
```

> **增强版依赖**: 多层级限额系统引入了 `AudioCategory`、`GlobalAudioLimitConfig` 和 `VirtualVoiceManager`，详见 [audio_manager_voice_management_enhanced.md](./audio_manager_voice_management_enhanced.md)。

---

## 8. 实现计划

### 8.1 阶段 1：核心功能（1-2 周）

| 任务编号 | 任务名称 | 优先级 | 预估时间 | 依赖 | 状态 |
|----------|----------|--------|----------|------|------|
| 1.1 | 创建 AudioEventResource | ⭐⭐⭐ | 0.5天 | - | ✅ |
| 1.2 | 创建 AudioVariant | ⭐⭐⭐ | 0.5天 | 1.1 | ✅ |
| 1.3 | 创建 AudioRandomizationConfig | ⭐⭐⭐ | 0.5天 | - | ✅ |
| 1.4 | 创建 AudioMixingConfig | ⭐⭐⭐ | 0.5天 | - | ✅ |
| 1.5 | 创建 DuckingRule | ⭐⭐⭐ | 0.5天 | 1.4 | ✅ |
| 1.6 | 实现 AudioUtils | ⭐⭐⭐ | 0.5天 | - | ✅ |
| 1.7 | 实现 AudioVariationManager | ⭐⭐⭐ | 1.5天 | 1.2, 1.3 | ✅ |
| 1.8 | 实现 AudioMixingController | ⭐⭐⭐ | 1.5天 | 1.4, 1.5 | ✅ |
| 1.9 | 扩展 JuicyAudioEventHandler | ⭐⭐⭐ | 2天 | 1.7, 1.8 | ✅ |
| 1.10 | 2D/3D 播放器支持 | ⭐⭐⭐ | 1天 | 1.9 | ✅ |
| 1.11 | test_audio_variations.gd | ⭐⭐⭐ | 0.5天 | 1.7 | ✅ |
| 1.12 | test_audio_mixing.gd | ⭐⭐⭐ | 0.5天 | 1.8 | ✅ |
| 1.13 | test_audio_2d_3d.gd | ⭐⭐⭐ | 0.5天 | 1.10 | ✅ |
| 1.14 | audio_demo_scene.tscn | ⭐⭐ | 0.5天 | 全部 | ✅ |

**阶段 1 交付物**:
- ✅ 随机容器 + 参数随机化
- ✅ 权重控制 + 防重复
- ✅ 动态鸭霸 + 播放限额
- ✅ 虚声部管理
- ✅ 2D/3D 自动检测
- ✅ 完整单元测试
- ✅ 演示场景

---

### 8.2 阶段 2：空间化与 RTPC（1 周）

| 任务编号 | 任务名称 | 优先级 | 预估时间 | 依赖 | 状态 |
|----------|----------|--------|----------|------|------|
| 2.1 | AudioSpatialMiddleware | ⭐⭐ | 1.5天 | 阶段1 | ⬜ |
| 2.2 | 衰减曲线编辑器 | ⭐⭐ | 1天 | 2.1 | ⬜ |
| 2.3 | 遮挡检测系统 | ⭐ | 1.5天 | 2.1 | ⬜ |
| 2.4 | AudioRTPCMiddleware | ⭐⭐ | 1天 | - | ⬜ |
| 2.5 | RTPC 映射系统 | ⭐⭐ | 1天 | 2.4 | ⬜ |
| 2.6 | 测试与文档 | ⭐⭐ | 1天 | 全部 | ⬜ |

---

### 8.3 阶段 3：交互式音乐（1 周）

| 任务编号 | 任务名称 | 优先级 | 预估时间 | 依赖 | 状态 |
|----------|----------|--------|----------|------|------|
| 3.1 | MusicInteractionMiddleware | ⭐ | 1.5天 | 阶段1 | ⬜ |
| 3.2 | 垂直分层系统 | ⭐ | 1.5天 | 3.1 | ⬜ |
| 3.3 | 水平跳转系统 | ⭐ | 1天 | 3.1 | ⬜ |
| 3.4 | 节拍回调系统 | ⭐ | 1天 | 3.1 | ⬜ |
| 3.5 | 测试与文档 | ⭐ | 1天 | 全部 | ⬜ |

---

## 9. API 使用示例

### 9.1 实际使用流程（已实现）

#### 9.1.1 在场景中设置 AudioManager

```gdscript
# 方法 1: 手动添加（推荐用于编辑器）
# 在场景编辑器中：
# 1. 右键点击场景根节点
# 2. 添加子节点 -> AudioManager
# 3. 在 Inspector 中配置：
#    - instance_mixing_config
#    - global_limit_config
#    - enable_debug_view

# 方法 2: 自动创建（运行时）
# AudioManager 会在首次使用时自动创建
var audio_manager = AudioManager.ensure_exists()
if audio_manager:
    print("AudioManager 已创建")
```

#### 9.1.2 使用 JuicyAudioPlayer 播放音频

```gdscript
# 步骤 1: 创建 JuicyAudioPlayer 节点
var player = JuicyAudioPlayer.new()
player.name = "FootstepAudio"
add_child(player)

# 步骤 2: 配置 AudioComponent
var footstep_event = preload("res://audio_events/footstep.tres")

# 自动设置（推荐）
player.auto_setup = true  # 在 _ready 时自动调用 setup()

# 或手动设置
player.audio_component = AudioComponent.new()
player.add_binding("footstep", footstep_event)

# 步骤 3: 连接节点信号
# 假设父节点是 Player，有 footstep 信号
# AudioComponent 会自动连接
player.setup(player_node, self)

# 步骤 4: 触发信号播放音频
# 当 Player 发出 footstep 信号时：
# player_node.emit_signal("footstep")
#
# 内部流程：
# 1. AudioComponent 接收信号
# 2. JuicyAudioPlayer._on_binding_triggered()
# 3. 创建 JuicyEvent(AUDIO_PLAY)
# 4. 调用 JuicyMixer.play_event(event, target, owner)
# 5. 通过完整中间件流程
# 6. EventHandlingMiddleware 调度
# 7. AudioEventHandler 处理播放
```

#### 9.1.3 完整的事件流程

```gdscript
# 用户代码层
extends Node2D

signal footstep  # 定义信号

@onready var audio_player = $FootstepAudio

func _ready():
    # AudioComponent 自动连接信号
    pass

func _process(_delta):
    if Input.is_action_just_pressed("move"):
        emit_signal("footstep")  # 触发信号

# ==========================================
# 内部自动流程（无需手动编写）
# ==========================================

# 1. AudioComponent 接收信号
func _on_binding_triggered(binding: AudioBinding):
    # 2. 创建 JuicyEvent
    var juicy_event = JuicyEvent.new()
    juicy_event.event_type = JuicyEvent.EventType.AUDIO_PLAY
    juicy_event.event_data = {
        "audio_event_resource": binding.audio_event,
        "target": _parent_node,
        "position": _get_target_position(_parent_node)
    }

    # 3. 通过 JuicyMixer 播放（使用完整中间件流程）
    var context_id = _mixer_instance.play_event(
        juicy_event,
        _parent_node,
        self
    )

    if not context_id.is_empty():
        binding.mark_played()

# ==========================================
# JuicyMixer 内部流程
# ==========================================

# JuicyMixer.play_event(event, target, owner):
static func play_event(event, target, owner):
    # 1. 创建事件 Context
    var context = JuicyContext.create_for_event(target, owner)
    # context.context_type = ContextType.EVENT  # 自动设置

    # 2. 添加事件
    context.add_event(event)

    # 3. 通过 Director 处理
    return instance._director.play_event(context)

# Director.play_event(context):
func play_event(context):
    # 1. 从池中获取 Context
    var pooled_context = _context_pool.get_context()

    # 2. 复制数据
    pooled_context.context_type = ContextType.EVENT
    for event in context.get_events():
        pooled_context.add_event(event)

    # 3. 执行中间件管道
    if _middleware_pipeline_execute(pooled_context):
        _register_context(pooled_context)
        pooled_context.activate()
        return pooled_context.context_id

# MiddlewarePipeline:
# 1. ValidationMiddleware - 验证 context_type
#    match context.context_type:
#        ContextType.EVENT: 检查事件存在
#        ContextType.FEEDBACK: 检查 resource 存在

# 2. EventHandlingMiddleware - 调度事件
#    - 添加到 EventBuffer
#    - 调用 EventScheduler.process_events()

# EventScheduler:
# - 分批处理事件
# - 按优先级排序
# - 分发到注册的 Handlers

# AudioEventHandler:
# - 解析 AudioEventResource
# - 三层限额检查
# - 变体选择
# - 创建播放器
# - 播放音频
```

### 9.2 创建音频事件资源

```gdscript
# 在编辑器中创建 AudioEventResource
var footstep_resource = AudioEventResource.new()

# 配置基础参数
footstep_resource.event_name = "footstep"
footstep_resource.audio_bus = "SFX"
footstep_resource.player_type = AudioEventResource.AudioPlayerType.AUTO_DETECT

# 添加音效变体
var variant1 = AudioVariant.new()
variant1.audio_stream = load("res://sounds/footstep_1.ogg")
variant1.weight = 1.0
variant1.pitch_enabled = true
variant1.pitch_min = -0.2
variant1.pitch_max = 0.2
variant1.volume_enabled = true
variant1.volume_min = 0.9
variant1.volume_max = 1.1
footstep_resource.audio_variants.append(variant1)

var variant2 = AudioVariant.new()
variant2.audio_stream = load("res://sounds/footstep_2.ogg")
variant2.weight = 1.0
variant2.pitch_enabled = true
variant2.pitch_min = -0.2
variant2.pitch_max = 0.2
footstep_resource.audio_variants.append(variant2)

# 配置随机化
footstep_resource.randomization = AudioRandomizationConfig.new()
footstep_resource.randomization.enabled = true

# 配置混音
footstep_resource.mixing = AudioMixingConfig.new()
footstep_resource.mixing.max_instances = 3
footstep_resource.mixing.priority = 50

# 配置防重复
footstep_resource.no_repeat_enabled = true
footstep_resource.no_repeat_memory = 2
```

### 9.3 播放音频事件

**注意**：以下是已废弃的 API，实际使用请参考 9.1 节。

```gdscript
# ❌ 已废弃 - 不要使用
var event = footstep_resource.create_audio_play_event(player_node)
JuicyMixer.add_event(event)

# ✅ 正确用法 - 使用完整事件流程
# 参考第 9.1.2 节
```

### 9.4 配置鸭霸规则

```gdscript
# 创建鸭霸规则
var ducking_rule = DuckingRule.new()
ducking_rule.event_name_pattern = "dialogue_*"  # 匹配所有对话事件
ducking_rule.target_bus = "Music"               # 鸭霸音乐总线
ducking_rule.duck_amount = -10.0                 # 降低 10dB
ducking_rule.recovery_delay = 0.5                # 0.5 秒后恢复
ducking_rule.enabled = true

# 添加到混音配置
var dialogue_resource = AudioEventResource.new()
dialogue_resource.mixing = AudioMixingConfig.new()
dialogue_resource.mixing.ducking_rules.append(ducking_rule)
```

### 9.5 2D/3D 音频示例

```gdscript
# 2D 音频（UI 音效）
var sfx_2d = AudioEventResource.new()
sfx_2d.player_type = AudioEventResource.AudioPlayerType.PLAYER_2D
# ... 配置变体 ...

# 3D 音频（环境音效）
var sfx_3d = AudioEventResource.new()
sfx_3d.player_type = AudioEventResource.AudioPlayerType.PLAYER_3D
sfx_3d.max_distance = 50.0
sfx_3d.max_distance_db = -40.0
# ... 配置变体 ...

# 自动检测（推荐）
var sfx_auto = AudioEventResource.new()
sfx_auto.player_type = AudioEventResource.AudioPlayerType.AUTO_DETECT
# 根据目标节点类型自动选择 2D 或 3D
```

### 9.6 高级：虚声部管理

> **重要提示**: 虚声部管理已升级为专业的**全局层级限额系统**，包括完整的虚声部管理、总线限制和硬件监控。详细实现请参考 [audio_manager_voice_management_enhanced.md](./audio_manager_voice_management_enhanced.md) 第 3.3 节。

```gdscript
# 启用虚声部（基础版）
var explosion = AudioEventResource.new()
explosion.virtual_voice_enabled = true
explosion.virtual_max_distance = 100.0  # 超过 100 米不播放
explosion.virtual_max_db = -20.0       # 超过 -20dB 不播放

# 在混音控制器中检查
if AudioMixingController.should_play_virtual(explosion, listener, position):
    # 实际播放
    pass
else:
    # 只记录逻辑，不实际播放（节省 CPU）
    pass
```

> **增强版功能**:
> - 全局声部上限配置（移动端 32，桌面端 64/128）
> - 虚声部池管理（最大 128-256 个虚声部）
> - 虚声部转换条件（距离、重要性、总声部数）
> - 总线级别限制（Master、Music、SFX、Voice）
> - 硬件资源监控（CPU、内存使用率）

---

## 10. 测试计划

### 10.1 测试文件列表

| 文件名 | 测试内容 | 优先级 |
|--------|----------|--------|
| `test_audio_variations.gd` | 变体系统测试 | ⭐⭐⭐ |
| `test_audio_mixing.gd` | 混音系统测试 | ⭐⭐⭐ |
| `test_audio_2d_3d.gd` | 2D/3D 播放器测试 | ⭐⭐⭐ |
| `test_audio_integration.gd` | 集成测试 | ⭐⭐ |
| `audio_demo_scene.tscn` | 演示场景 | ⭐⭐ |

### 10.2 测试用例设计

#### 10.2.1 变体系统测试

```gdscript
extends Node

func _ready():
    print("=== Audio Variation Tests ===")
    _test_basic_selection()
    _test_weighted_selection()
    _test_no_repeat()
    _test_randomization()
    print("=== Tests Complete ===")

func _test_basic_selection():
    var manager = AudioVariationManager.new()
    var resource = AudioEventResource.new()

    # 添加 3 个变体
    for i in range(3):
        var variant = AudioVariant.new()
        variant.audio_stream = AudioStreamPlayer.new().stream
        resource.audio_variants.append(variant)

    var selected = manager.select_variant(resource)
    assert(selected != null, "Should select a variant")
    print("✓ Basic selection test passed")

func _test_weighted_selection():
    var manager = AudioVariationManager.new()
    var resource = AudioEventResource.new()

    # 添加 3 个变体，权重分别为 1, 2, 3
    var weights = [1.0, 2.0, 3.0]
    for i in range(3):
        var variant = AudioVariant.new()
        variant.audio_stream = AudioStreamPlayer.new().stream
        variant.weight = weights[i]
        resource.audio_variants.append(variant)

    # 测试 100 次选择，验证权重分布
    var counts = [0, 0, 0]
    for i in range(100):
        var selected = manager.select_variant(resource)
        var index = resource.audio_variants.find(selected)
        counts[index] += 1

    # 变体 3 应该被选择最多（权重最大）
    assert(counts[2] > counts[1] and counts[1] > counts[0],
           "Weighted selection should respect weights")
    print("✓ Weighted selection test passed")

func _test_no_repeat():
    var manager = AudioVariationManager.new()
    var resource = AudioEventResource.new()
    resource.no_repeat_enabled = true
    resource.no_repeat_memory = 2

    # 添加 3 个变体
    for i in range(3):
        var variant = AudioVariant.new()
        variant.audio_stream = AudioStreamPlayer.new().stream
        resource.audio_variants.append(variant)

    var last_selected = null
    for i in range(10):
        var selected = manager.select_variant(resource)
        if last_selected != null:
            assert(selected != last_selected, "No repeat should prevent consecutive same variant")
        last_selected = selected

    print("✓ No repeat test passed")

func _test_randomization():
    var manager = AudioVariationManager.new()
    var config = AudioRandomizationConfig.new()
    config.global_pitch_min = -0.5
    config.global_pitch_max = 0.5
    config.global_volume_min = 0.9
    config.global_volume_max = 1.1
    config.enabled = true

    var resource = AudioEventResource.new()
    resource.randomization = config

    var variant = AudioVariant.new()
    variant.pitch_enabled = true
    variant.pitch_min = -0.3
    variant.pitch_max = 0.3
    variant.volume_enabled = true
    variant.volume_min = 0.8
    variant.volume_max = 1.2
    resource.audio_variants.append(variant)

    # 测试 100 次随机化
    var pitch_values = []
    var volume_values = []
    for i in range(100):
        var rand = manager.apply_randomization(variant, 1.0, 1.0)
        pitch_values.append(rand.pitch)
        volume_values.append(rand.volume)

    # 验证范围
    for pitch in pitch_values:
        assert(pitch >= 0.5 and pitch <= 1.5, "Pitch should be within range")

    for volume in volume_values:
        assert(volume >= 0.72 and volume <= 1.32, "Volume should be within range")

    print("✓ Randomization test passed")
```

#### 10.2.2 混音系统测试

> **重要提示**: 本节提供基础测试用例。多层级限额系统的完整测试（包括类别级别、全局级别、虚声部、智能排序）请参考 [audio_manager_voice_management_enhanced.md](./audio_manager_voice_management_enhanced.md) 第 5 节。

```gdscript
extends Node

func _ready():
    print("=== Audio Mixing Tests ===")
    _test_instance_limiting()
    _test_ducking()
    print("=== Tests Complete ===")

func _test_instance_limiting():
    var controller = AudioMixingController.new()
    var resource = AudioEventResource.new()
    resource.mixing = AudioMixingConfig.new()
    resource.mixing.max_instances = 3
    resource.mixing.limit_policy = AudioMixingConfig.InstanceLimitPolicy.STOP_OLDEST

    resource.event_name = "test_sound"

    # 测试限额
    for i in range(5):
        var can_play = controller.can_play(resource, "test_sound")
        if i < 3:
            assert(can_play, "Should be able to play within limit")
        else:
            assert(can_play, "Should stop oldest and allow new")
        controller.record_instance("test_sound", AudioStreamPlayer.new(), 50)

    print("✓ Instance limiting test passed")

func _test_ducking():
    var controller = AudioMixingController.new()
    var resource = AudioEventResource.new()
    resource.mixing = AudioMixingConfig.new()

    var ducking_rule = DuckingRule.new()
    ducking_rule.event_name_pattern = "test_*"
    ducking_rule.target_bus = "Music"
    ducking_rule.duck_amount = -10.0
    ducking_rule.enabled = true

    resource.mixing.ducking_rules.append(ducking_rule)
    resource.event_name = "test_sound"

    # 测试鸭霸
    controller.apply_ducking("test_sound", resource.mixing)
    var stats = controller.get_stats()
    assert(stats.ducking_active == 1, "Ducking should be active")

    # 测试恢复
    controller.remove_ducking("test_sound", resource.mixing)
    for i in range(100):  # 模拟 100 帧
        controller.update_ducking(0.016)
    stats = controller.get_stats()
    assert(stats.ducking_active == 0, "Ducking should be recovered")

    print("✓ Ducking test passed")
```

#### 10.2.3 2D/3D 播放器测试

```gdscript
extends Node

func _ready():
    print("=== Audio 2D/3D Tests ===")
    _test_player_type_detection()
    _test_2d_player_creation()
    _test_3d_player_creation()
    print("=== Tests Complete ===")

func _test_player_type_detection():
    var node_2d = Node2D.new()
    var node_3d = Node3D.new()
    var node_generic = Node.new()

    var type_2d = AudioUtils.detect_player_type(node_2d)
    var type_3d = AudioUtils.detect_player_type(node_3d)
    var type_generic = AudioUtils.detect_player_type(node_generic)

    assert(type_2d == AudioEventResource.AudioPlayerType.PLAYER_2D,
           "Node2D should detect as PLAYER_2D")
    assert(type_3d == AudioEventResource.AudioPlayerType.PLAYER_3D,
           "Node3D should detect as PLAYER_3D")
    assert(type_generic == AudioEventResource.AudioPlayerType.PLAYER_2D,
           "Generic node should default to PLAYER_2D")

    print("✓ Player type detection test passed")

func _test_2d_player_creation():
    var player = AudioUtils.create_player_2d()
    assert(player is AudioStreamPlayer2D, "Should create 2D player")
    player.queue_free()
    print("✓ 2D player creation test passed")

func _test_3d_player_creation():
    var player = AudioUtils.create_player_3d()
    assert(player is AudioStreamPlayer3D, "Should create 3D player")
    player.queue_free()
    print("✓ 3D player creation test passed")
```

---

## 11. 阶段 2-3 预览

### 11.1 阶段 2：空间化与 RTPC

#### 11.1.1 空间化中间件

```gdscript
@tool
class_name AudioSpatialMiddleware
extends JuicyMiddleware

var middleware_name: String = "AudioSpatialMiddleware"
var attenuation_curves: Dictionary = {}  # event_name -> AttenuationCurveResource

func process(context: JuicyContext, event: JuicyEvent) -> bool:
    if event.event_type != JuicyEvent.EventType.AUDIO_PLAY:
        return true

    var resource = event.event_data.get("audio_event_resource")
    if not resource is AudioEventResource:
        return true

    # 应用空间化参数
    if resource.attenuation_curve:
        var curve = resource.attenuation_curve
        # 根据距离应用曲线
        pass

    # 检测遮挡
    var obstruction = _check_obstruction(context.target, event.event_data.get("position"))
    # 应用低通滤波器
    pass

    return true

func _check_obstruction(listener: Node3D, source_position: Vector3) -> float:
    # Raycast 检测遮挡
    var space = listener.get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(
        listener.global_position,
        source_position
    )
    var result = space.intersect_ray(query)
    return 1.0 if result.is_empty() else 0.5
```

#### 11.1.2 RTPC 中间件

```gdscript
@tool
class_name AudioRTPCMiddleware
extends JuicyMiddleware

var middleware_name: String = "AudioRTPCMiddleware"
var rtpc_mappings: Dictionary = {}  # event_name -> Array[RTPCMapping]

func process(context: JuicyContext, event: JuicyEvent) -> bool:
    if event.event_type != JuicyEvent.EventType.AUDIO_PLAY:
        return true

    var resource = event.event_data.get("audio_event_resource")
    if not resource is AudioEventResource:
        return true

    # 应用 RTPC 映射
    for mapping in resource.rtpc_mappings:
        var game_value = _get_game_parameter(mapping.game_parameter)
        var audio_value = mapping.map(game_value)
        _apply_audio_parameter(event, mapping.audio_parameter, audio_value)

    return true

func _get_game_parameter(param_name: String) -> float:
    # 从游戏状态获取参数
    return 0.0

func _apply_audio_parameter(event: JuicyEvent, param_name: String, value: float) -> void:
    # 应用参数到播放器
    pass
```

### 11.2 阶段 3：交互式音乐

```gdscript
@tool
class_name MusicInteractionMiddleware
extends JuicyMiddleware

var middleware_name: String = "MusicInteractionMiddleware"
var layers: Dictionary = {}  # music_name -> Array[layer_config]

func process(context: JuicyContext, event: JuicyEvent) -> bool:
    if event.event_type == JuicyEvent.EventType.AUDIO_PLAY:
        var resource = event.event_data.get("audio_event_resource")
        if resource and resource.event_name.begins_with("music_"):
            _handle_music_play(resource, context)

    elif event.event_type == JuicyEvent.EventType.CUSTOM_EVENT:
        var event_data = event.event_data
        if event_data.get("type") == "music_intensity_change":
            _update_music_layers(event_data.get("intensity"))

    return true

func _handle_music_play(resource: AudioEventResource, context: JuicyContext) -> void:
    # 根据强度播放音乐层
    pass

func _update_music_layers(intensity: float) -> void:
    # 根据强度动态添加/移除层
    pass
```

---

## 12. 附录

### 12.1 术语表

| 术语 | 英文 | 说明 |
|------|------|------|
| 随机容器 | Random Container | 从多个音效中随机选择一个播放 |
| 参数随机化 | Parameter Randomization | 每次播放时随机调整音高/音量 |
| 权重控制 | Weighting | 不同变体有不同的播放概率 |
| 防重复 | No-Repeat | 避免连续播放同一个音效 |
| 鸭霸 | Ducking | 某个声音播放时降低其他声音音量 |
| 虚声部 | Virtual Voice | 超出可听范围时只保留逻辑，不实际播放 |
| 播放限额 | Instance Limiting | 限制同时播放的实例数量 |
| RTPC | Real-Time Parameter Control | 游戏参数到音频参数的实时映射 |
| 衰减曲线 | Attenuation Curve | 音量随距离变化的曲线 |
| 遮挡 | Obstruction | 声音被障碍物部分阻挡 |
| 阻碍 | Occlusion | 声音被完全封闭 |

### 12.2 参考资料

- [Godot Audio Documentation](https://docs.godotengine.org/en/stable/tutorials/audio/audio_buses.html)
- [Wwise Documentation - Randomization](https://www.audiokinetic.com/library/edge/?source=Help&id=randomizer)
- [FMOD Studio - Events](https://www.fmod.com/docs/2.02/studio/content-examples-events.html)

### 12.3 版本历史

| 版本 | 日期 | 变更说明 | 作者 |
|------|------|----------|------|
| 1.1 | 2026-01-14 | 添加多层级播放限额参考标注 | AI |
| 1.0 | 2026-01-14 | 初始设计文档 | AI |

### 12.4 相关文档

- **多层级播放限额增强方案**: [audio_manager_voice_management_enhanced.md](./audio_manager_voice_management_enhanced.md)
  - 三层限额架构（实例、类别、全局）
  - 智能排序系统（距离、重要性、时间）
  - 完整虚声部管理
  - 类别级别管理
  - 总线级别限制
  - 硬件资源监控
- **Godot 原生集成说明**: [audio_manager_godot_integration.md](./audio_manager_godot_integration.md)

---

## 13. 结束语

本文档提供了 JuicyMixer 音频管理器的完整技术设计方案。所有数据结构、核心类、实现计划都已详细定义，可以直接开始实现阶段 1 的核心功能。

如有任何问题或建议，请及时反馈。

---

## 14. 实际实现总结（v1.4 更新）

### 14.1 已实现的架构改进

#### 14.1.1 AudioManager 配置中心模式
**状态**: ✅ 已完成

**实现要点**：
- 静态单例管理（get_instance/ensure_exists/has_instance）
- 自动注册到 EventHandlingMiddleware
- 场景级配置统一管理
- 延迟验证机制避免初始化顺序问题

**相关文件**：
- `addons/juicy_mixer/core/audio_manager.gd`
- `addons/juicy_mixer/core/juicy_audio_player.gd`

#### 14.1.2 完整事件流程集成
**状态**: ✅ 已完成

**实现要点**：
- JuicyMixer.play_event() 使用 Director.play_event()
- EventContext 经过完整中间件管道
- ValidationMiddleware 类型安全验证
- EventHandlingMiddleware 事件调度

**相关文件**：
- `addons/juicy_mixer/core/juicy_mixer.gd`
- `addons/juicy_mixer/core/juicy_director.gd`
- `addons/juicy_mixer/middleware/validation_middleware.gd`
- `addons/juicy_mixer/middleware/event_handling_middleware.gd`

#### 14.1.3 ContextType 类型系统
**状态**: ✅ 已完成

**实现要点**：
- JuicyContext.ContextType 枚举（FEEDBACK/EVENT）
- context_type 字段自动设置
- ValidationMiddleware 使用 match 语句进行类型验证
- 避免运行时 has_method() 调用

**相关文件**：
- `addons/juicy_mixer/core/juicy_context.gd`
- `addons/juicy_mixer/middleware/validation_middleware.gd`

### 14.2 与设计的差异

| 设计特性 | 设计状态 | 实现状态 | 差异说明 |
|----------|----------|----------|----------|
| 直接事件创建 | ❌ 未设计 | ✅ 已废弃 | 改用完整中间件流程 |
| AudioManager 单例 | ❌ 未设计 | ✅ 新增 | 配置中心模式 |
| ContextType 枚举 | ❌ 未设计 | ✅ 新增 | 类型安全验证 |
| 延迟验证机制 | ❌ 未设计 | ✅ 新增 | 避免初始化问题 |

### 14.3 使用建议

#### 14.3.1 推荐用法
```gdscript
# ✅ 推荐：使用 JuicyAudioPlayer
var player = JuicyAudioPlayer.new()
player.auto_setup = true
add_child(player)

# 音频会通过完整事件流程：
# 信号 -> AudioComponent -> JuicyEvent
# -> JuicyMixer.play_event() -> Director -> MiddlewarePipeline
# -> EventHandlingMiddleware -> AudioEventHandler
```

#### 14.3.2 避免的用法
```gdscript
# ❌ 已废弃：直接创建事件
var event = footstep_resource.create_audio_play_event(player)
JuicyMixer.add_event(event)

# ✅ 正确：使用完整流程
# 参考 9.1 节的实际使用示例
```

### 14.4 后续优化方向

1. **性能优化**
   - 事件缓冲区批量处理优化
   - 对象池管理改进
   - 减少重复验证

2. **功能扩展**
   - 更多中间件类型（空间化、RTPC）
   - 事件优先级动态调整
   - 音频流预加载

3. **用户体验**
   - 可视化调试工具
   - 性能监控面板
   - 音频事件预览

### 14.5 相关文档

- **多层级播放限额**: [audio_manager_voice_management_enhanced.md](./audio_manager_voice_management_enhanced.md)
- **事件驱动系统**: [phase4_event_driven_system_detailed_plan.md](./phase4_event_driven_system_detailed_plan.md)

---

**文档版本**: v1.4
**更新日期**: 2026-01-17
**更新内容**: 添加实际实现总结章节
