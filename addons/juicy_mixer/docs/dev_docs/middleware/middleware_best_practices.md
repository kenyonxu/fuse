# JuicyMixer 中间件与Driver协同系统最佳实践指南

本文档旨在指导开发者如何高效利用 JuicyMixer V3 的中间件系统与 Driver 系统的协同能力。文档按照核心组件进行梳理，详细说明每个中间件的最佳实践、初始化策略以及进阶使用场景。

## 1. 系统架构与核心概念

在深入组件之前，理解系统的协同机制至关重要：

- **执行流**：Middleware Pipeline -> Property Buffer -> Driver Execution。中间件作为"拦截器"和"预处理器"，在 Driver 执行具体逻辑之前对 Context 进行修正、过滤或增强。
- **数据隔离**：中间件应通过 `JuicyContext` 的 `middleware_data` 专用区域存储状态，避免污染全局命名空间。
- **属性协调**：中间件通过 `middleware_property_overrides` 影响最终输出，而不是直接修改 Driver 的内部状态，确保了单向数据流的稳定性。

---

## 2. ChannelMiddleware (通道管理)

ChannelMiddleware 是控制并发和优先级的核心组件。

### 2.1 核心职责
- 控制不同效果的并发数量。
- 管理效果的优先级和抢占规则。
- 防止同一类效果刷屏或导致性能问题。

### 2.2 初始化策略
推荐创建一个专用的 Autoload (如 `JuicyConfig.gd`) 来在游戏启动时集中初始化所有通道。

```gdscript
# res://autoloads/JuicyConfig.gd
extends Node

func _ready():
    _setup_channels()

func _setup_channels():
    var mw = JuicyMixer.get_middleware("ChannelMiddleware")
    if not mw: return

    # 1. UI通道：FIFO，防止积压
    mw.set_channel_config("ui", _create_config(3, JuicyChannelConfig.PriorityMode.FIFO))
    
    # 2. 战斗通道：基于优先级，确保暴击等重要反馈播放
    mw.set_channel_config("combat", _create_config(10, JuicyChannelConfig.PriorityMode.PRIORITY_BASED))
    
    # 3. 音效通道：无限制
    mw.set_channel_config("sfx", _create_config(-1)) 

func _create_config(max_concurrent, mode):
    var config = JuicyChannelConfig.new()
    config.max_concurrent = max_concurrent
    config.priority_mode = mode
    return config
```

### 2.3 通道划分最佳实践

| 通道名称 | 典型用途 | 推荐配置 | 理由 |
| :--- | :--- | :--- | :--- |
| `ui_feedback` | 按钮点击、悬停 | `FIFO`, Max=3 | 快速响应，旧效果自然淡出，防止堆叠 |
| `combat_hit` | 受击、暴击 | `PRIORITY_BASED`, Max=5 | 确保高优先级（如暴击）效果挤占低优先级效果 |
| `voice_over` | 角色语音 | `LIFO`, Max=1, AutoStop | 新语音打断旧语音，保持语音清晰 |
| `environment` | 背景音效 | `FIFO`, Max=10 | 允许较多并发，作为背景存在 |
| `cutscene` | 剧情演出 | `PRIORITY`, Max=1, NoInterrupt | 独占式播放，不被普通游戏逻辑打断 |

---

## 3. TimeScaleMiddleware (时间控制)

TimeScaleMiddleware 负责处理全局或局部的时间缩放，实现子弹时间、顿帧等效果。

### 3.1 核心职责
- 管理全局时间缩放。
- 管理基于分组（Time Group）的时间缩放。
- 提供平滑的时间过渡动画。
- 与 Driver 协同，自动应用时间缩放至最终效果。

### 3.2 基础使用：配置时间组
您可以为不同的游戏实体定义不同的时间组，例如让敌人变慢但玩家保持正常速度。

```gdscript
var timescale_mw = JuicyMixer.get_middleware("TimeScaleMiddleware")
var config = JuicyTimeGroupConfig.new()

# 定义分组策略
config.set_time_scale("enemies", 1.0)
config.set_time_scale("player", 1.0)
config.set_time_scale("ui", 1.0) # UI通常不受时间影响

timescale_mw.set_time_group_config(config)
```

### 3.3 进阶使用：运行时动态控制
在游戏过程中，您可以使用两种方式调整时间：

#### A. 直接设置（立即生效）
适用于瞬间的状态切换，如暂停、受击顿帧。
```gdscript
# 立即将敌人组静止
timescale_mw.set_time_group_scale("enemies", 0.0)
```

#### B. 动画过渡（平滑渐变）
适用于进入/退出子弹时间、环境氛围变化。
```gdscript
# 2秒内将全局时间平滑缩放至 0.1 (进入子弹时间)
timescale_mw.animate_time_group_scale("global", 0.1, 2.0, Tween.EASE_OUT)

# 恢复正常速度，带回调
timescale_mw.animate_time_group_scale("global", 1.0, 0.5, Tween.EASE_IN, func():
    print("Bullet time ended")
)
```

### 3.4 Driver 协同机制
TimeScaleMiddleware 会自动计算最终的 `time_scale` 并注入 Context。所有标准 Driver (如 `TweenDriver`, `AnimationDriver`) 无需任何修改，只需读取 `context.time_scale` 即可自动适配变速效果。

---

## 4. LODMiddleware (性能细节分级)

LODMiddleware 负责根据摄像机距离动态调整效果强度，以平衡画面表现与性能开销。

### 4.1 核心职责
- **距离衰减**：随着距离增加，降低效果强度（如减少粒子数量、减弱震动幅度）。
- **视锥剔除**：自动停止播放屏幕外不可见的效果。
- **距离剔除**：超过最大可视距离直接停止效果。

### 4.2 配置指南
LOD 策略通过 `JuicyLODConfig` 资源进行配置。建议为不同类型的特效创建不同的配置模板。

```gdscript
var lod_mw = JuicyMixer.get_middleware("LODMiddleware")
var config = JuicyLODConfig.new()

# 1. 定义距离阈值与强度倍数
config.max_distance = 1000.0
# 距离 < 100: 100% 强度
# 100 < 距离 < 300: 70% 强度
# 300 < 距离 < 600: 30% 强度
# 距离 > 600: 0% 强度 (不播放)
config.distance_thresholds = [100.0, 300.0, 600.0]
config.intensity_multipliers = [1.0, 0.7, 0.3, 0.0]

# 2. 启用剔除优化
config.enable_frustum_culling = true # 屏幕外不播
config.enable_distance_culling = true # 太远不播

lod_mw.set_lod_config(config)
```

### 4.3 摄像机集成
LODMiddleware 默认会自动获取主视口的 2D 摄像机。如果您的游戏使用自定义摄像机逻辑（如多视口或非主摄像机），需要手动注入：

```gdscript
func _ready():
    var camera = %PlayerCamera
    var lod_mw = JuicyMixer.get_middleware("LODMiddleware")
    lod_mw.set_camera(camera)
```

### 4.4 最佳实践建议
- **高频特效**：务必开启 `enable_frustum_culling`，避免在屏幕外消耗大量计算资源。
- **关键反馈**：对于极其重要（如玩家死亡）的效果，可以使用一个 `max_distance` 极大的配置，或临时禁用 LOD，确保玩家无论在哪都能感知到。
---

## 5. 自定义中间件开发规范

如果您需要开发新的中间件（如 `AudioFilterMiddleware`），请遵循以下规范：

### 4.1 单一职责原则
每个中间件只专注于一个领域。
- **错误示范**: `GameLogicMiddleware` (同时处理时间、声音和特效)。
- **正确示范**: `LODMiddleware` (仅处理性能分级), `AudioMiddleware` (仅处理音频参数)。

### 4.2 数据安全访问
严禁直接修改 Context 中属于 Driver 的私有变量。始终使用提供的 API：

```gdscript
# ✅ 正确：使用专用存储区
context.set_middleware_data("lod_level", 1)

# ✅ 正确：使用属性覆盖机制
context.set_middleware_property_override("volume_db", -10.0)

# ❌ 错误：直接修改 Driver 内部属性
context.resource.internal_volume = -10.0 
```

### 4.3 性能守则
中间件会在每一帧或每个效果触发时运行，必须保持极其轻量。
- **避免**: 复杂的数学运算、文件 I/O、大量对象创建。
- **推荐**: 缓存计算结果、使用简单的条件判断快速返回。

---

## 6. 调试与监控

当效果未按预期播放时，请按以下步骤排查：

1. **检查 ValidationMiddleware**: 
   - 查看 Output 面板是否有警告。
   - 启用 `enable_debug_logging` 查看具体的拦截原因（如目标节点无效、资源缺失）。
2. **检查 Channel 状态**:
   - 调用 `JuicyMixer.get_middleware("ChannelMiddleware").debug_print_channels()`。
   - 确认 `active_contexts` 是否达到上限，或被高优先级效果阻塞。
3. **检查 TimeScale 状态**:
   - 调用 `JuicyMixer.get_middleware("TimeScaleMiddleware").debug_print_time_scales()`。
   - 确认当前的时间缩放值是否符合预期（例如是否误设为 0 导致效果静止）。
4. **检查 LOD 状态**:
   - 调用 `JuicyMixer.get_middleware("LODMiddleware").debug_print_lod_info()`。
   - 确认摄像机是否正确获取。
   - 确认距离计算和剔除逻辑是否符合预期（例如是否因距离过远被剔除）。

---

**总结**

JuicyMixer V3 的强大之处在于"各司其职"。Middleware 负责"策略"（能不能播、怎么播、何时播），Driver 负责"执行"（具体怎么动）。保持这种边界清晰，您的反馈系统将坚不可摧。