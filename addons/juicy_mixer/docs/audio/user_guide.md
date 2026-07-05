# JuicyMixer 音乐系统用户指南

## 概述

JuicyMixer 音乐系统提供完整的游戏背景音乐管理功能：

- **MusicManager** - 执行层（Backend）：负责音乐播放、淡入淡出、总线管理
- **MusicPlayer** - 逻辑层（Frontend）：负责状态管理、优先级堆栈、切换逻辑
- **MusicTrackResource** - 资源层：定义音乐轨道配置
- **MusicStateMap** - 映射层：将游戏状态映射到音乐轨道
- **MusicPriorityConfig** - 配置层：可自定义的优先级列表

**架构**：
```
游戏逻辑
   ↓
MusicPlayer (逻辑层)
   - 优先级堆栈管理
   - 决定"播什么"
   ↓
MusicManager (执行层)
   - 淡入淡出
   - Intro-Loop 处理
   - 总线管理
   ↓
AudioStreamPlayer (播放器)
```

---

## 快速开始

### 1. 创建音乐轨道资源

右键 → 创建资源 → MusicTrackResource

**基础字段**：
- `music_type`: 音乐类型（STANDARD 或 INTRO_LOOP）
- `loop_stream`: 循环播放的音频流
- `intro_stream`: Intro 段（仅 INTRO_LOOP 类型）
- `transition_fade_time`: 过渡时间（秒）

**重要**：如果使用 SEAMLESS 循环模式，确保音频文件在导入时勾选 **Loop** 选项。

---

### 循环播放配置 🔄

MusicTrackResource 提供了强大的循环播放系统，支持多种循环模式。

#### 循环模式（Loop Mode）

| 模式 | 说明 | 适用场景 |
|------|------|---------|
| **SEAMLESS** | 无缝循环（使用 AudioStream.loop） | 背景音乐、环境音 |
| **CROSSFADE** | 每次循环时交叉淡入淡出 | 需要平滑过渡的场景 |
| **CROSSFADE_VARIANT** | 交叉淡入淡出到变体 | 避免重复感的长时间播放 |

#### 配置字段

**Loop Configuration** 组：
```gdscript
# 循环模式
loop_mode: LoopMode = LoopMode.SEAMLESS

# Loop 变体模式（仅 CROSSFADE_VARIANT 模式有效）
loop_variant_mode: LoopVariantMode = LoopVariantMode.NONE
# - NONE: 不使用变体
# - RANDOM: 每次循环随机选择变体
# - SEQUENTIAL: 按顺序循环变体

# 循环触发点（0.0-1.0）
loop_trigger_point: float = 0.95  # 在 95% 处触发下一次循环

# 循环交叉淡入淡出时间（秒）
loop_crossfade_time: float = 1.0
```

**Loop 变体**：
```gdscript
# 添加多个 Loop 变体
loop_variants: Array[AudioStream] = [
    preload("res://music/loop_variant_1.ogg"),
    preload("res://music/loop_variant_2.ogg"),
    preload("res://music/loop_variant_3.ogg")
]
```

#### 工作流程

**SEAMLESS 模式**：
```
播放 Loop → 到达结尾 → 自动从头开始（无切换痕迹）
```

**CROSSFADE 模式**：
```
播放 Loop → 95% 处 → 创建新播放器 → Crossfade (1秒) → 旧播放器淡出 → 重复
```

**CROSSFADE_VARIANT 模式**：
```
播放 Loop1 → 95% 处 → 选择 Loop2 → Crossfade → 播放 Loop2 → 95% 处 → 选择 Loop3 → ...
```

#### 使用示例

**示例 1：无缝循环**
```gdscript
# 在 Inspector 中配置
track.loop_mode = MusicTrackResource.LoopMode.SEAMLESS
# 系统会自动设置 AudioStream.loop = true
```

**示例 2：Crossfade 循环**
```gdscript
track.loop_mode = MusicTrackResource.LoopMode.CROSSFADE
track.loop_crossfade_time = 2.0  # 2 秒过渡时间
track.loop_trigger_point = 0.9   # 在 90% 处触发
```

**示例 3：使用 Loop 变体**
```gdscript
track.loop_mode = MusicTrackResource.LoopMode.CROSSFADE_VARIANT
track.loop_variant_mode = MusicTrackResource.LoopVariantMode.RANDOM
track.loop_variants = [
    preload("res://music/exploring_a.ogg"),
    preload("res://music/exploring_b.ogg"),
    preload("res://music/exploring_c.ogg")
]
```

#### 注意事项

1. **SEAMLESS 模式**：
   - 最简单，性能最好
   - 需要音频文件本身支持无缝循环
   - 在音频导入设置中启用 "Loop"

2. **CROSSFADE 模式**：
   - 会创建额外的 AudioStreamPlayer
   - 过渡时间建议 0.5-2 秒
   - 触发点建议 0.9-0.95（90%-95%）

3. **CROSSFADE_VARIANT 模式**：
   - 适合长时间播放的场景（探索、建造等）
   - RANDOM 模式避免重复感
   - SEQUENTIAL 模式提供可预测的变化

4. **性能考虑**：
   - SEAMLESS 模式：最低开销
   - CROSSFADE 模式：中等开销（每循环 1 次播放器切换）
   - 建议不要同时有太多 CROSSFADE 模式的音乐在播放

---

### 2. 创建状态映射资源

右键 → 创建资源 → MusicStateMap

**配置示例**：
```gdscript
state_map = {
    &"menu": preload("res://music/menu_track.tres"),
    &"exploring": preload("res://music/exploring_track.tres"),
    &"combat": preload("res://music/combat_track.tres"),
    &"boss": preload("res://music/boss_track.tres")
}
```

---

### 3. 场景设置

```
YourScene
├── MusicManager (自动创建或手动添加)
└── MusicPlayer
    ├── state_map: MusicStateMap 资源
    └── priority_config: MusicPriorityConfig 资源 (可选)
```

---

## 使用 MusicManager（执行层）

### 直接播放音乐

```gdscript
@onready var music_manager = $MusicManager

# 播放音乐（带淡入）
music_manager.play_music(track, fade_in_time)

# 停止音乐（带淡出）
music_manager.stop_music(fade_out_time)

# 交叉淡入淡出
music_manager.crossfade_to(new_track, fade_time)
```

### 核心API

**play_music(track, fade_in_time, persistence_key)**
- 播放指定的音乐轨道
- `fade_in_time`: 淡入时间（秒），0 表示立即播放
- 返回：track_id

**stop_music(fade_out_time)**
- 停止当前音乐
- `fade_out_time`: 淡出时间（秒）

**crossfade_to(new_track, fade_time)**
- 淡出当前音乐，淡入新音乐
- `fade_time`: 过渡时间（秒）

---

## 使用 MusicPlayer（逻辑层）✨

### 优先级堆栈系统

MusicPlayer 使用**优先级堆栈**管理音乐状态：

| 优先级名称 | 数值 | 用途 |
|-----------|------|------|
| global | 0 | 全局/默认音乐（菜单、标题） |
| exploring | 1 | 探索音乐 |
| combat | 2 | 战斗音乐 |
| boss | 3 | Boss战音乐 |
| event | 4 | 特殊事件/临时音乐 |

**堆栈行为**：
- 高优先级自动覆盖低优先级
- 弹出高优先级后，自动回退到低优先级
- 支持同优先级多个状态共存

### 方式 1：使用优先级数值

```gdscript
@onready var music_player = $MusicPlayer

# 压入战斗音乐
music_player.push_state(&"combat", MusicPlayer.Priority.COMBAT)

# 弹出战斗音乐
music_player.pop_state(&"combat")
```

### 方式 2：使用优先级名称（推荐）✨

```gdscript
# 配置 MusicPlayer
music_player.priority_config = preload("res://music_priority_config.tres")

# 使用优先级名称
music_player.push_state_by_name(&"combat", &"combat")

# 优势：
# - 可配置的优先级
# - 无需硬编码
# - 易于维护
```

### 核心API

**push_state(state, priority, fade_time)** - 压入状态
```gdscript
music_player.push_state(&"exploring", MusicPlayer.Priority.EXPLORING, 2.0)
```

**push_state_by_name(state, priority_name, fade_time)** - 使用优先级名称
```gdscript
music_player.push_state_by_name(&"combat", &"combat", 2.0)
```

**pop_state(state, fade_time)** - 弹出状态
```gdscript
music_player.pop_state(&"combat")
```

**switch_state(state, priority, fade_time)** - 切换状态（清空堆栈）
```gdscript
music_player.switch_state(&"menu", MusicPlayer.Priority.GLOBAL)
```

---

## 自定义优先级系统 🎛️

### 创建优先级配置资源

1. 右键 → 创建资源 → MusicPriorityConfig

2. 在 Inspector 中配置优先级列表：

**方式 1：默认配置（简单游戏）**
```
global (0)     → 菜单音乐
exploring (1)  → 探索音乐
combat (2)     → 战斗音乐
boss (3)       → Boss音乐
event (4)      → 特殊事件
```

**方式 2：分层配置（复杂游戏）**
```
ambient (0)     → 环境音（最低）
exploration (10) → 基础探索
secondary (20)   → 次要音乐层
primary (30)     → 主要音乐
focus (40)       → 焦点事件
critical (50)    → 关键事件（最高）
```

### 在代码中使用自定义优先级

```gdscript
# 在 MusicPlayer 中引用配置
@onready var music_player = $MusicPlayer
music_player.priority_config = preload("res://my_priority_config.tres")

# 使用自定义优先级名称
music_player.push_state_by_name(&"primary", &"primary")
music_player.push_state_by_name(&"focus", &"focus")
```

### 运行时动态添加优先级

```gdscript
# 运行时添加新优先级
music_player.priority_config.add_priority(&"special", 5, "特殊事件")

# 更新优先级数值
music_player.priority_config.update_priority_value(&"boss", 10)
```

---

## 使用场景示例

### 场景 1：基本战斗触发

```gdscript
# 敌人AI脚本
extends Enemy

@onready var music_player = MusicPlayer.get_instance(self)

func _on_agro():
    music_player.push_state_by_name(&"combat", &"combat")

func _on_death():
    music_player.pop_state(&"combat")
```

### 场景 2：区域音乐（Area3D）

```gdscript
# 区域触发器脚本
extends Area3D

@export var state_name: StringName = &"exploring"
@export var priority_name: StringName = &"exploring"

func _on_body_entered(body):
    if body.is_in_group("player"):
        MusicPlayer.play_state(body, state_name, 0)

func _on_body_exited(body):
    if body.is_in_group("player"):
        var player = MusicPlayer.get_instance(body)
        player.pop_state(state_name)
```

### 场景 3：UI 菜单

```gdscript
# 菜单脚本
extends Control

func _on_menu_opened():
    MusicPlayer.play_state(self, &"menu", MusicPlayer.Priority.GLOBAL)

func _on_game_start():
    var player = MusicPlayer.get_instance(self)
    player.pop_state(&"menu")
```

### 场景 4：Boss 战

```gdscript
# Boss 触发器
func _on_boss_entered():
    music_player.push_state_by_name(&"boss", &"boss")

func _on_boss_defeated():
    music_player.pop_state(&"boss")
    # 自动回退到 combat 或 exploring
```

---

## 堆栈行为示例

### 示例 1：基本堆栈

```
操作：
1. push_state(&"exploring", 1)
2. push_state(&"combat", 2)
3. pop_state(&"combat")

结果：
步骤1: 播放 exploring
步骤2: 播放 combat（覆盖 exploring）
步骤3: 回退到 exploring ✅
```

### 示例 2：多层堆栈

```
操作：
1. push_state(&"exploring", 1)
2. push_state(&"ambient", 0)
3. push_state(&"combat", 2)

结果：
步骤1: 播放 exploring
步骤2: exploring + ambient 同时播放（低优先级叠加）
步骤3: combat 覆盖所有 ✅
```

### 示例 3：优先级切换

```
当前：exploring (1)

压入：boss (3)
→ 播放 boss（boss > exploring）

弹出：boss
→ 回退到 exploring ✅
```

---

## Intro-Loop 音乐

### 配置 Intro-Loop 结构

1. 创建 MusicTrackResource
2. 设置 `music_type` = `INTRO_LOOP`
3. 配置 `intro_stream` 和 `loop_stream`
4. 调整过渡时间：
   - `intro_fade_out_time`: Intro 淡出时间
   - `loop_fade_in_time`: Loop 淡入时间

**使用**：
```gdscript
var track = preload("res://music/boss_intro_loop.tres")
music_manager.play_music(track)
```

**自动行为**：
1. 播放 Intro 段
2. 在 `intro_duration - intro_fade_out_time` 时开始淡出 Intro
3. 同时淡入 Loop 段
4. 循环播放 Loop

---

## 调试

### 启用调试日志

```gdscript
music_manager.enable_debug_logging = true
music_player.enable_debug_logging = true
```

### 查看堆栈信息

```gdscript
print(music_player.get_stack_info())
```

**输出示例**：
```
当前堆栈 (2 个状态):
  [2] combat (优先级 2) ← 当前
  [1] exploring (优先级 1)
```

### 监听状态变化

```gdscript
music_player.state_changed.connect(_on_music_changed)

func _on_music_changed(old_state, new_state, track):
    print("音乐切换: ", old_state, " → ", new_state)
```

---

## 全局访问方式

### 方式 1：节点引用

```gdscript
@onready var music_player = $MusicPlayer
music_player.push_state(&"combat", MusicPlayer.Priority.COMBAT)
```

### 方式 2：静态便捷方法

```gdscript
# 压入状态
MusicPlayer.play_state(self, &"combat", MusicPlayer.Priority.COMBAT)

# 获取实例
var player = MusicPlayer.get_instance(self)
player.push_state(&"exploring", MusicPlayer.Priority.EXPLORING)
```

### 方式 3：Group 访问

```gdscript
var player = get_tree().get_first_node_in_group("music_player") as MusicPlayer
player.push_state(&"menu", MusicPlayer.Priority.GLOBAL)
```

---

## 与 Bricks 集成

### 使用 RunTargetNodeFunction 指令

**指令**：压入战斗音乐
```
节点：MusicPlayer
方法：push_state 或 push_state_by_name
参数：
  1. &"combat" (StringName, 状态名称)
  2. &"combat" (StringName, 优先级名称，仅 push_state_by_name)
```

---

## 最佳实践

### ✅ 推荐做法

1. **使用优先级名称而不是硬编码数值**
   ```gdscript
   # ✅ 好
   music_player.push_state_by_name(&"combat", &"combat")

   # ❌ 差
   music_player.push_state(&"combat", 2)
   ```

2. **成对调用 push/pop**
   ```gdscript
   func enter_combat():
       music_player.push_state_by_name(&"combat", &"combat")

   func exit_combat():
       music_player.pop_state(&"combat")
   ```

3. **在资源中配置循环**
   ```gdscript
   # 在导入音频时勾选 Loop 选项
   # 或在代码中设置：
   track.loop_stream.loop = true
   ```

### ❌ 避免做法

1. **不要直接调用 MusicManager**（绕过逻辑层）
   ```gdscript
   # ❌ 错误
   MusicManager.play_music(track)

   # ✅ 正确
   MusicPlayer.push_state_by_name(&"state", &"priority")
   ```

2. **不要忘记 pop_state**
   ```gdscript
   # ❌ 错误：只 push 不 pop
   func _on_event():
       music_player.push_state_by_name(&"event", &"event")

   # ✅ 正确：配对使用
   func _on_event_start():
       music_player.push_state_by_name(&"event", &"event")

   func _on_event_end():
       music_player.pop_state(&"event")
   ```

3. **不要使用硬编码的优先级数值**
   ```gdscript
   # ❌ 错误
   music_player.push_state(&"combat", 2)

   # ✅ 正确
   music_player.push_state_by_name(&"combat", &"combat")
   ```

---

## 常见问题

### Q: 如何让音乐在不同区域间平滑切换？

A: 使用区域触发器 + MusicPlayer

```gdscript
extends Area3D

@export var state_name: StringName
@export var priority_name: StringName

func _on_body_entered(body):
    if body.is_in_group("player"):
        MusicPlayer.play_state(body, state_name, 0)
```

### Q: 战斗结束后音乐不会切换回去？

A: 确保调用了 `pop_state()`

```gdscript
var combat_count = 0

func _on_enemy_agro():
    combat_count += 1
    if combat_count == 1:
        music_player.push_state_by_name(&"combat", &"combat")

func _on_enemy_death():
    combat_count -= 1
    if combat_count == 0:
        music_player.pop_state(&"combat")
```

### Q: 如何处理多个战斗同时进行？

A: 使用引用计数或状态管理

```gdscript
# 方案 1：引用计数
var active_combats: int = 0

func _start_combat():
    active_combats += 1
    if active_combats == 1:
        music_player.push_state_by_name(&"combat", &"combat")

func _end_combat():
    active_combats -= 1
    if active_combats == 0:
        music_player.pop_state(&"combat")

# 方案 2：直接管理堆栈
func _start_combat():
    music_player.push_state_by_name(&"combat", &"combat")

func _end_combat():
    if _is_last_combat():
        music_player.pop_state(&"combat")
```

### Q: 如何创建分层音乐系统？

A: 使用分层优先级配置

```gdscript
# 创建分层配置
var config = MusicPriorityConfig.create_layered()

# 定义优先级
# ambient (0) → 环境音
# exploration (10) → 基础探索
# secondary (20) → 次要层
# primary (30) → 主要层
# focus (40) → 焦点事件
# critical (50) → 关键事件

# 使用
music_player.push_state_by_name(&"ambient", &"ambient")
music_player.push_state_by_name(&"exploration", &"exploration")
music_player.push_state_by_name(&"primary", &"primary")
```

---

## 故障排除

### 循环播放相关问题

**Q: 音乐播放一次后就停止了，不会循环**

A: 检查以下几点：
1. 确认 `loop_mode` 已正确配置（默认是 SEAMLESS）
2. 如果使用 SEAMLESS 模式，确保音频文件在导入时启用了 "Loop" 选项
3. 检查 `loop_stream` 是否已正确赋值
4. 查看控制台是否有错误信息

**Q: CROSSFADE 模式下，循环时有明显的跳跃**

A: 调整以下参数：
```gdscript
# 延长交叉淡入淡出时间，让过渡更平滑
loop_crossfade_time = 2.0  # 增加到 2 秒

# 提前触发点，给交叉淡入淡出更多时间
loop_trigger_point = 0.85  # 在 85% 处触发
```

**Q: CROSSFADE_VARIANT 模式不工作**

A: 检查：
1. 确认 `loop_variants` 数组不为空
2. 确认 `loop_variant_mode` 设置为 RANDOM 或 SEQUENTIAL
3. 确认所有变体音频文件都存在且可加载

**Q: SEAMLESS 模式下循环有明显的断裂**

A: 这通常是由于音频文件本身不支持无缝循环：
1. 使用音频编辑软件确保音频开头和结尾匹配
2. 或者切换到 CROSSFADE 模式
3. 调整 `loop_offset` 参数（如果 AudioStream 支持）

**Q: 循环播放时 CPU 占用很高**

A: 检查循环模式：
1. SEAMLESS 模式：最低 CPU 占用
2. CROSSFADE 模式：每循环会创建新播放器，确保 `loop_crossfade_time` 不要太短
3. 检查是否同时有太多音乐在循环播放
4. 考虑使用更长的触发点（0.95 或更高）

### 性能优化建议

**1. 选择合适的循环模式**
- 短时间播放：使用 SEAMLESS
- 长时间播放：使用 CROSSFADE_VARIANT
- 需要平滑过渡：使用 CROSSFADE

**2. 调整触发点**
- 触发点越接近 1.0，CPU 占用越低（检查频率降低）
- 建议范围：0.90 - 0.95

**3. 控制同时播放的音乐数量**
- 避免同时有多个 CROSSFADE 模式的音乐
- 使用优先级堆栈确保只有高优先级音乐在播放

**4. 音频文件优化**
- 使用 OGG Vorbis 格式（比 MP3 更适合循环）
- 确保音频采样率一致（推荐 44100Hz 或 48000Hz）
- 避免过大的音频文件

---

## 相关文档

- [MusicPlayer 用户指南](music_player_user_guide.md) - MusicPlayer 详细使用指南
- [MusicTrackResource API](../resources/music/music_track_resource.gd) - 音乐轨道资源
- [MusicStateMap API](../resources/music/music_state_map.gd) - 状态映射
- [MusicPriorityConfig API](../resources/music/music_priority_config.gd) - 优先级配置
- [测试场景](../tests/music/test_music_player_ui.tscn) - UI 测试场景

---

**最后更新**: 2026-01-21
**新增功能**: 循环播放系统（SEAMLESS/CROSSFADE/CROSSFADE_VARIANT）
**Godot 版本**: 4.5
