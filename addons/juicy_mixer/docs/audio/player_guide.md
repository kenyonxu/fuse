# MusicPlayer 使用指南

## 概述

MusicPlayer 是音乐系统的逻辑层（Frontend），负责管理游戏音乐的状态优先级和切换逻辑。

**架构**：
```
游戏逻辑
   ↓
MusicPlayer (逻辑层)
   - 决定"播什么"
   - 优先级堆栈管理
   ↓
MusicManager (执行层)
   - 处理"怎么播"
   - 淡入淡出、总线管理
```

---

## 核心概念

### 优先级堆栈

MusicPlayer 使用**优先级堆栈**来管理音乐状态：

| 优先级 | 名称 | 用途 |
|-------|------|------|
| 0 | GLOBAL | 全局/默认音乐（菜单、标题） |
| 1 | EXPLORING | 探索音乐 |
| 2 | COMBAT | 战斗音乐 |
| 3 | BOSS | Boss战音乐 |
| 4 | EVENT | 特殊事件/临时音乐 |

**行为规则**：
- 高优先级状态自动覆盖低优先级
- 弹出高优先级后，自动回退到低优先级
- 同优先级可以共存（后进先出）

---

## 快速开始

### 1. 创建状态映射资源

1. 右键 → 创建资源 → MusicStateMap
2. 在 Inspector 中配置：

```gdscript
state_map = {
    &"menu": preload("res://music/menu.tres"),
    &"exploring": preload("res://music/exploring.tres"),
    &"combat": preload("res://music/combat.tres"),
    &"boss": preload("res://music/boss.tres")
}
```

### 2. 场景设置

```
YourScene
├── MusicManager
└── MusicPlayer
    ├── state_map: MusicStateMap 资源
    └── default_fade_time: 2.0
```

### 3. 使用方法调用

```gdscript
# 获取引用
@onready var music_player = $MusicPlayer

# 压入状态
func _on_player_entered_combat():
    music_player.push_state(&"combat", MusicPlayer.Priority.COMBAT)

# 弹出状态
func _on_enemy_defeated():
    music_player.pop_state(&"combat")
```

---

## API 参考

### push_state()

压入一个新的音乐状态到堆栈。

```gdscript
func push_state(state: StringName, priority: int = Priority.EXPLORING, fade_time: float = -1.0) -> bool
```

**参数**：
- `state`: 状态名称（必须在 state_map 中定义）
- `priority`: 优先级（使用 Priority 枚举）
- `fade_time`: 淡入淡出时间（-1 使用默认值）

**返回**：是否成功压入

**示例**：
```gdscript
music_player.push_state(&"exploring", MusicPlayer.Priority.EXPLORING)
music_player.push_state(&"combat", MusicPlayer.Priority.COMBAT, 3.0)
```

---

### pop_state()

从堆栈弹出一个音乐状态。

```gdscript
func pop_state(state: StringName, fade_time: float = -1.0) -> bool
```

**参数**：
- `state`: 要弹出的状态名称
- `fade_time`: 淡出时间

**返回**：是否成功弹出

**示例**：
```gdscript
music_player.pop_state(&"combat")
```

---

### switch_state()

切换到指定状态（清空堆栈并压入新状态）。

```gdscript
func switch_state(state: StringName, priority: int = Priority.EXPLORING, fade_time: float = -1.0) -> bool
```

**示例**：
```gdscript
# 清空所有状态，切换到菜单音乐
music_player.switch_state(&"menu", MusicPlayer.Priority.GLOBAL)
```

---

### stop_all()

停止所有音乐并清空堆栈。

```gdscript
func stop_all(fade_time: float = -1.0) -> void
```

**示例**：
```gdscript
music_player.stop_all()
```

---

## 使用场景

### 场景 1：战斗触发

```gdscript
# 敌人AI脚本
extends Enemy

func _on_agro():
    MusicPlayer.play_state(self, &"combat", MusicPlayer.Priority.COMBAT)

func _on_death():
    MusicPlayer.get_instance(self).pop_state(&"combat")
```

### 场景 2：区域音乐

```gdscript
# 区域触发器脚本
extends Area3D

@export var state_name: StringName = &"exploring"
@export var priority: int = MusicPlayer.Priority.EXPLORING

func _on_body_entered(body):
    if body.is_in_group("player"):
        MusicPlayer.play_state(body, state_name, priority)

func _on_body_exited(body):
    if body.is_in_group("player"):
        MusicPlayer.get_instance(body).pop_state(state_name)
```

### 场景 3：UI 系统

```gdscript
# 菜单脚本
extends Control

func _on_menu_opened():
    MusicPlayer.play_state(self, &"menu", MusicPlayer.Priority.GLOBAL)

func _on_menu_closed():
    MusicPlayer.get_instance(self).pop_state(&"menu")
```

---

## 调试

### 启用调试日志

```gdscript
music_player.enable_debug_logging = true
```

输出示例：
```
[MusicPlayer] 压入状态: combat (优先级 2)
[MusicPlayer] 切换到状态: combat (优先级 2)
[MusicManager] crossfade_to 被调用
```

### 查看堆栈信息

```gdscript
print(music_player.get_stack_info())
```

输出示例：
```
当前堆栈 (2 个状态):
  [2] combat (优先级 2) ← 当前
  [1] exploring (优先级 1)
```

### 监听状态变化

```gdscript
music_player.state_changed.connect(_on_music_state_changed)

func _on_music_state_changed(old_state, new_state, track):
    print("音乐切换: %s → %s" % [old_state, new_state])
```

---

## 堆栈行为示例

### 示例 1：基本堆栈

```
操作序列：
1. push_state(&"exploring", 1)
2. push_state(&"combat", 2)
3. pop_state(&"combat")

结果：
步骤1: 播放 exploring
步骤2: 播放 combat（覆盖 exploring）
步骤3: 回退到 exploring
```

### 示例 2：优先级覆盖

```
操作序列：
1. push_state(&"exploring", 1)
2. push_state(&"combat", 2)
3. push_state(&"boss", 3)
4. pop_state(&"boss")
5. pop_state(&"combat")

结果：
步骤1: 播放 exploring
步骤2: 播放 combat
步骤3: 播放 boss（覆盖 combat）
步骤4: 回退到 combat
步骤5: 回退到 exploring
```

### 示例 3：同优先级切换

```
操作序列：
1. push_state(&"exploring_forest", 1)
2. push_state(&"exploring_cave", 1)

结果：
步骤1: 播放 forest
步骤2: 播放 cave（覆盖 forest，同优先级）
弹出 cave 时：回退到 forest
```

---

## 测试场景

项目包含完整的 UI 测试场景：

**文件**：`addons/juicy_mixer/tests/music/test_music_player_ui.tscn`

**功能**：
- 加载状态映射
- 压入/弹出各个状态
- 实时显示堆栈信息
- 调试日志输出

**运行步骤**：
1. 打开测试场景
2. 准备音乐资源（参考 test_music_state_map.tres 说明）
3. 点击"加载测试状态映射"
4. 使用按钮测试各种操作
5. 观察堆栈信息面板

---

## 全局访问方式

### 方式 1：场景树引用

```gdscript
@onready var music_player = $MusicPlayer
music_player.push_state(&"combat", MusicPlayer.Priority.COMBAT)
```

### 方式 2：静态方法（任意位置调用）

```gdscript
# 使用便捷方法
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

使用 `RunTargetNodeFunction` 指令：

```
指令：压入战斗音乐
节点：MusicPlayer
方法：push_state
参数：
  1. &"combat" (StringName)
  2. 2 (int, Priority.COMBAT)
```

---

## 最佳实践

### ✅ 推荐做法

1. **使用枚举定义优先级**
   ```gdscript
   music_player.push_state(&"combat", MusicPlayer.Priority.COMBAT)
   ```

2. **成对调用 push/pop**
   ```gdscript
   func enter_state():
       music_player.push_state(&"state", priority)

   func exit_state():
       music_player.pop_state(&"state")
   ```

3. **在区域触发器中使用**
   ```gdscript
   func _on_body_entered(body):
       MusicPlayer.play_state(body, state_name, priority)
   ```

### ❌ 避免做法

1. **不要直接调用 MusicManager**
   ```gdscript
   # ❌ 错误：绕过逻辑层
   MusicManager.play_music(track)

   # ✅ 正确：通过 MusicPlayer
   MusicPlayer.play_state(self, &"state", priority)
   ```

2. **不要忘记 pop_state**
   ```gdscript
   # ❌ 错误：只 push 不 pop
   func _on_event():
       music_player.push_state(&"event", priority)
       # 如果忘记 pop，音乐会一直播放
   ```

3. **不要使用硬编码的优先级**
   ```gdscript
   # ❌ 错误
   music_player.push_state(&"combat", 2)

   # ✅ 正确
   music_player.push_state(&"combat", MusicPlayer.Priority.COMBAT)
   ```

---

## 常见问题

### Q: 如何让音乐在不同区域间平滑切换？

A: 使用区域触发器和 MusicPlayer：

```gdscript
extends Area3D

@export var state_name: StringName
@export var priority: int = MusicPlayer.Priority.EXPLORING

func _on_body_entered(body):
    if body.is_in_group("player"):
        MusicPlayer.play_state(body, state_name, priority)
```

### Q: 战斗结束后音乐不会切换回去？

A: 确保调用了 `pop_state()`：

```gdscript
func _on_enemy_death():
    music_player.pop_state(&"combat")
```

### Q: 如何处理多个战斗同时进行？

A: 使用引用计数或检查所有敌人状态：

```gdscript
var combat_count = 0

func _on_enemy_agro():
    combat_count += 1
    if combat_count == 1:
        music_player.push_state(&"combat", MusicPlayer.Priority.COMBAT)

func _on_enemy_death():
    combat_count -= 1
    if combat_count == 0:
        music_player.pop_state(&"combat")
```

---

## 相关文档

- [MusicManager 用户指南](../music_user_guide.md)
- [MusicTrackResource API](../../resources/music/music_track_resource.gd)
- [测试场景](../music/test_music_player_ui.tscn)

---

**最后更新**: 2026-01-20
**Godot 版本**: 4.5
