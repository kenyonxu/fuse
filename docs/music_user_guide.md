# JuicyMixer 音乐系统用户指南

**状态**: 已完成
**作者**: Claude Sonnet 4.5
**日期**: 2026-01-18

---

## 概述

JuicyMixer 的音乐系统是一个功能完整的游戏音乐播放解决方案，支持 Intro-Loop 结构、平滑过渡、低通滤波器快照和场景持久化。本文档将带你了解如何在你的 Godot 项目中使用这些功能。

---

## 快速开始

最简单的使用方式：

```gdscript
# 在场景中创建 MusicManager
var music_manager = MusicManager.new()
add_child(music_manager)

# 创建音乐资源
var track = MusicTrackResource.new()
track.music_type = MusicTrackResource.MusicType.STANDARD
track.loop_stream = preload("res://music/background.ogg")

# 播放音乐
music_manager.play_music(track)
```

就这么简单！你已经可以播放音乐了。

---

## 基础播放

### 播放音乐

最常用的功能就是播放背景音乐。`play_music()` 方法支持淡入效果，让音乐平滑开始。

```gdscript
# 创建 MusicManager
var music_manager = MusicManager.new()
add_child(music_manager)

# 创建音乐资源
var track = MusicTrackResource.new()
track.loop_stream = preload("res://music/background.ogg")
track.transition_fade_time = 2.0  # 2秒淡入

# 播放音乐（带淡入效果）
music_manager.play_music(track, fade_in_time = 2.0)
```

淡入效果会让音乐从静音渐强，避免突然开始。

### 停止音乐

停止音乐时同样支持淡出效果：

```gdscript
# 停止音乐（带2秒淡出）
music_manager.stop_music(fade_out_time = 2.0)
```

### Crossfade 过渡

当你需要从一首音乐平滑切换到另一首音乐时，使用 `crossfade_to()` 方法：

```gdscript
# 切换到战斗音乐
var combat_music = preload("res://music/combat.ogg")
music_manager.crossfade_to(combat_music, fade_time = 3.0)
```

旧音乐会淡出，新音乐同时淡入，创造无缝的听觉体验。

---

## Intro-Loop 结构

很多游戏音乐有 Intro（前奏）和 Loop（循环）部分。JuicyMixer 可以自动处理这种结构。

### 设置 Intro-Loop 资源

```gdscript
var track = MusicTrackResource.new()

# 设置为 Intro-Loop 类型
track.music_type = MusicTrackResource.MusicType.INTRO_LOOP

# 设置 Intro 和 Loop
track.intro_stream = preload("res://music/menu_intro.ogg")
track.loop_stream = preload("res://music/menu_loop.ogg")

# 设置过渡参数
track.intro_fade_out_time = 1.5  # Intro 结束时开始淡出
track.loop_fade_in_time = 1.5   # Loop 开始时开始淡入
```

### 播放 Intro-Loop 音乐

```gdscript
# 自动播放 Intro 然后无缝切换到 Loop
music_manager.play_music(track)

# 系统会：
# 1. 播放 Intro 部分
# 2. 在 Intro 结束前 1.5 秒开始淡出
# 3. 淡出 Intro 的同时，淡入 Loop
# 4. Loop 循环播放
```

你不需要手动处理过渡，系统会自动完成。

---

## 音乐层叠加

当你需要叠加多个音乐层时（例如战斗强度增加时的额外乐器），使用 `add_music_layer()`。

```gdscript
# 主音乐已经在播放
var base_music = preload("res://music/base_combat.ogg")
music_manager.play_music(base_music)

# 添加高强度的打击乐层
var heavy_layer = MusicLayerResource.new()
heavy_layer.layer_stream = preload("res://music/combat_heavy_percussion.ogg")
heavy_layer.layer_bus_index = 0  # 使用 Music_Layer1 总线
heavy_layer.default_volume = -5.0  # -5 dB

# 添加到主音乐上
var layer_id = music_manager.add_music_layer(heavy_layer, fade_in_time = 1.0)
```

### 移除音乐层

```gdscript
# 移除打击乐层
music_manager.remove_music_layer(layer_id, fade_out_time = 1.0)
```

---

## LPF 快照（暂停效果）

当游戏进入暂停菜单时，你希望音乐继续播放但变"闷"，使用 `apply_pause_snapshot()`。

```gdscript
func _on_pause_menu_opened():
	music_manager.apply_pause_snapshot()

func _on_pause_menu_closed():
	music_manager.apply_normal_snapshot()
```

这会将所有音乐路由到带低通滤波器的 Music_LPF 总线，让音乐听起来更沉闷。

---

## 场景持久化

场景持久化功能确保当玩家从地图 A 切换到地图 B 时，如果两张图使用同一首背景音乐，音乐会继续播放，而不会重新开始。

### 手动持久化

```gdscript
# 准备离开当前场景
var state = music_manager.prepare_for_scene_change()

# 在新场景中恢复
music_manager.restore_from_state(state)
```

### 自动持久化

如果音乐资源的 `persist_across_scenes` 为 `true`，系统会自动检测资源是否相同。

```gdscript
var track = MusicTrackResource.new()
track.persist_across_scenes = true
track.persistence_key = "exploration_music"

# 播放音乐
music_manager.play_music(track)

# 切换场景时，音乐将继续播放
get_tree().change_scene_to_file("res://scenes/map_b.tscn")
```

---

## 完整示例

### 示例 1：探索音乐播放

这是一个完整的探索音乐播放示例：

```gdscript
extends Node2D

@export var exploration_music: AudioStream = preload("res://music/exploration.ogg")

func _ready():
	# 创建 MusicManager
	var music_manager = MusicManager.new()
	add_child(music_manager)

	# 创建音乐资源
	var track = MusicTrackResource.new()
	track.music_type = MusicTrackResource.MusicType.STANDARD
	track.loop_stream = exploration_music
	transition_fade_time = 3.0  # 3秒淡入

	# 播放音乐
	music_manager.play_music(track, transition_fade_time)
```

### 示例 2：战斗音乐系统（带层叠加）

```gdscript
extends Node

func _ready():
	var music_manager = MusicManager.new()
	add_child(music_manager)

	# 基础战斗音乐
	var base_track = preload("res://music/combat_base.ogg")
	music_manager.play_music(base_track)

func on_combat_intensity_high():
	# 战斗强度增加，添加打击乐层
	var heavy_layer = preload("res://music/combat_heavy_percussion.ogg")
	var layer = MusicLayerResource.new()
	layer.layer_stream = heavy_layer
	layer.layer_bus_index = 0  # Music_Layer1
	layer.default_volume = -3.0

	music_manager.add_music_layer(layer, fade_in_time = 0.5)

func on_combat_end():
	# 战斗结束，移除打击乐层
	music_manager.remove_music_layer(layer_id, fade_out_time = 1.0)
	music_manager.stop_music(2.0)
```

### 示例 3：暂停菜单 LPF 快照

```gdscript
extends Node

var music_manager: MusicManager

func _ready():
	music_manager = MusicManager = new()
	add_child(music_manager)

	var track = MusicTrackResource.new()
	track.loop_stream = preload("res://music/menu.ogg")
	track.use_lpf_on_pause = true  # 在资源中启用 LPF

	music_manager.play_music(track, 2.0)

func _on_pause():
	music_manager.apply_pause_snapshot()

func _on_resume():
	music_manager.apply_normal_snapshot()
```

### 示例 4：跨场景音乐保持

```gdscript
extends Node2D

# 地图 A
func _ready():
	var music_manager = MusicManager.new()
	add_child(music_manager)

	var track = preload("res://music/exploration.ogg")
	track.persist_across_scenes = true
	track.persistence_key = "exploration_music"  # 唯一标识符

	music_manager.play_music(track)

	# 切换到地图 B
	get_tree().change_scene_to_file("res://scenes/map_b.tscn")

# 地图 B 中有相同的音乐资源
# 音乐会自动继续播放，不会重新开始
```

---

## API 参考

### MusicManager 主要方法

| 方法 | 描述 |
|------|------|
| [play_music(track, fade_in_time, persistence_key)](#play_music) | 播放音乐，支持淡入 |
| [stop_music(fade_out_time)](#stop_music) | 停止音乐，支持淡出 |
| [crossfade_to(track, fade_time)](#crossfade_to) | 平滑过渡到新音乐 |
| [add_music_layer(layer, fade_in_time)](#add_music_layer) | 添加音乐层 |
| [remove_music_layer(layer_id, fade_out_time)](#remove_music_layer) | 移除音乐层 |
| [apply_pause_snapshot()](#apply_pause_snapshot) | 应用暂停 LPF 效果 |
| [apply_normal_snapshot()](#apply_normal_snapshot) | 恢复正常播放 |
| [prepare_for_scene_change()](#prepare_for_scene_change) | 准备场景切换 |
| [restore_from_state(state)](#restore_from_state) | 从状态恢复播放 |

### MusicTrackResource 主要属性

| 属性 | 描述 | 默认值 |
|------|------|---------|
| music_type | 音乐类型（STANDARD, INTRO_LOOP, LAYERED, TRANSITIONAL） | INTRO_LOOP |
| intro_stream | Intro 段音频 | null |
| loop_stream | Loop 段音频 | null |
| loop_variants | Loop 变体数组 | [] |
| intro_fade_out_time | Intro 淡出时间（秒） | 2.0 |
| loop_fade_in_time | Loop 淡入时间（秒） | 2.0 |
| transition_fade_time | 默认过渡时间（秒） | 1.0 |
| music_bus | 主音乐总线名称 | "Music" |
| use_lpf_on_pause | 暂停时启用 LPF | true |
| persist_across_scenes | 是否跨场景持久化 | true |
| persistence_key | 唯一标识符 | "" |

### MusicLayerResource 主要属性

| 属性 | 描述 | 默认值 |
|------|------|---------|
| layer_name | 层名称 | "Layer1" |
| layer_stream | 层音频流 | null |
| layer_bus_index | 总线索引（0-MAX_LAYERS） | 0 |
| default_volume | 层音量 | -10.0 dB |
| fade_in_time | 淡入时间 | 1.0 秒 |
| fade_out_time | 暗出时间 | 1.0 秒 |
| trigger_tag | 触发标签 | "" |

---

## 常见使用场景

### 1. 主菜单音乐

```gdscript
func _on_main_menu_opened():
	var menu_music = preload("res://music/menu.ogg")
	music_manager.play_music(menu_music, 3.0)

func _on_game_start():
	var game_music = preload("res://music/game.ogg")
	music_manager.crossfade_to(game_music, 2.0)
```

### 2. 战斗音乐系统

```gdscript
func _on_combat_start():
	var base_music = preload("res://music/combat_base.ogg")
	music_manager.play_music(base_music, 1.0)

func _on_intensity_increase():
	var high_intensity_layer = preload("res://music/combat_high.ogg")
	var layer = MusicLayerResource.new()
	layer.layer_stream = high_intensity_layer
	layer.layer_bus_index = 0

	music_manager.add_music_layer(layer, 0.5)
```

### 3. 场景切换保持

```gdscript
func _on_scene_transition(scene_path: String):
	# 准备离开当前场景
	var state = music_manager.prepare_for_scene_change()
	SceneTransition.set_music_state(state)

# 在新场景的 _ready() 中恢复
func _ready():
	var state = SceneTransition.get_music_state()
	if not state.is_empty():
		music_manager.restore_from_state(state)
```

---

## 进阶技巧

### 动态调整 LPF 参数

```gdscript
# 调整 LPF 截止频率（闷的程度）
var lpf_value = 500.0  # 更闷
_bus_controller.set_lpf_cutoff(lpf_value)

# 调整 LPF 共振
var resonance = 3.0  # 更多共鸣
_bus_controller.set_lpf_resonance_db(resonance)
```

### 检查活跃层

```gdscript
# 获取当前活跃层数量
var layer_count = music_manager._current_music_state.get_layer_count()
print("活跃层数: ", layer_count)
```

---

## 故障排查

### 音乐不播放

1. 检查 MusicManager 是否添加为场景子节点
2. 检查 MusicTrackResource 是否有效
3. 检查音频文件路径是否正确
4. 查看 Godot 输出面板的错误信息

### 过渡不平滑

1. 确保淡入淡出时间设置合理
2. 检查 MusicTransitionScheduler 是否正常工作
3. 验证两个音乐的音量设置

### 场景切换后音乐重新开始

1. 检查 `persist_across_scenes` 是否为 `true`
2. 确保 `persistence_key` 已设置
3. 确认两个场景使用的是同一个资源引用

---

## 相关文档

- [音乐系统设计文档](../docs/music_system_design.md)
- [实现计划文档](../docs/plans/2026-01-18-music-system.md)
- [插件注册指南](#注册音乐系统类)

---

**下一步**: 查看 [设计文档](../docs/music_system_design.md) 了解架构细节。

</content>
