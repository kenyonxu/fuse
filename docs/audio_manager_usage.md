# AudioManager 使用指南

## 概述

AudioManager 是场景级的音频配置节点，提供统一的音频系统配置入口。它在场景中创建并管理 `JuicyAudioEventHandler`，其他音频节点（如 `JuicyAudioPlayer`）会自动查找并使用它。

## 快速开始

### 1. 添加 AudioManager 到场景

在场景树中添加 AudioManager 节点：

```gdscript
# 通过代码添加
var manager = AudioManager.new()
add_child(manager)
```

或在编辑器中：
1. 右键点击场景根节点
2. 选择 "Add Child Node"
3. 搜索并添加 "AudioManager"

### 2. 配置全局限额

在 Inspector 中配置 `Global-Level Limits` 部分：

```
Global-Level Limits
├── global_limit_config: GlobalAudioLimitConfig
    ├── max_total_voices: 64        # 最大真实声部数
    ├── max_virtual_voices: 128     # 最大虚声部数
    ├── virtual_voice_threshold: 0.3  # 虚声部距离阈值
    └── bus_limits: Dictionary       # 各总线限额
```

### 3. 添加音频类别（可选）

在 `Categories` 部分添加音频类别资源：

```
Categories
└── default_categories: Array[AudioCategory] (Size: 0)
    ├── Element 0: AudioCategory
    │   ├── category_name: "Explosions"
    │   ├── max_instances: 5
    │   └── category_priority: HIGH
    └── Element 1: AudioCategory
        ├── category_name: "Footsteps"
        ├── max_instances: 10
        └── category_priority: MEDIUM
```

## 工作原理

### 自动 Handler 创建

当 AudioManager 进入场景树时（`_ready()`）：

1. 创建 `JuicyAudioEventHandler` 实例
2. 将 handler 添加为子节点
3. 应用全局配置和类别配置
4. 将自身添加到 "audio_manager" 组

```gdscript
func _ready() -> void:
    add_to_group("audio_manager")

    _audio_handler = JuicyAudioEventHandler.new()
    _audio_handler.name = "JuicyAudioEventHandler"
    add_child(_audio_handler)

    _apply_scene_config()
```

### JuicyAudioPlayer 集成

JuicyAudioPlayer 自动查找并使用 AudioManager 的 handler：

```gdscript
# JuicyAudioPlayer 中的查找逻辑
func _find_or_create_audio_handler() -> JuicyAudioEventHandler:
    # 1. 查找场景中的 AudioManager
    var audio_manager = get_tree().get_first_node_in_group("audio_manager")
    if audio_manager and audio_manager.has_method("get_audio_handler"):
        return audio_manager.get_audio_handler()

    # 2. 如果找不到，创建临时的
    var handler = JuicyAudioEventHandler.new()
    return handler
```

## API 参考

### 获取音频处理器

```gdscript
var handler = audio_manager.get_audio_handler()
```

### 更新配置

```gdscript
# 更新全局配置
var new_global_config = GlobalAudioLimitConfig.new()
new_global_config.max_total_voices = 128
audio_manager.update_global_config(new_global_config)

# 更新混合配置
var new_mixing_config = AudioMixingConfig.new()
new_mixing_config.max_instances = 20
audio_manager.update_mixing_config(new_mixing_config)
```

### 管理类别

```gdscript
# 添加类别
var category = AudioCategory.new()
category.category_name = "UI_Sounds"
audio_manager.add_default_category(category)

# 移除类别
audio_manager.remove_default_category(category)

# 获取所有类别
var categories = audio_manager.get_default_categories()
```

### 获取调试信息

```gdscript
var debug_info = audio_manager.get_debug_info()
print("Manager: ", debug_info.manager_name)
print("Active players: ", debug_info.audio_stats.active_players)
```

## 配置示例

### 场景 1: 简单 2D 游戏

```
Main (Node)
└── AudioManager
    ├── global_limit_config:
    │   ├── max_total_voices: 32
    │   ├── bus_limits: {"Master": 32, "SFX": 20}
    │   └── virtual_voice_enabled: false
    └── enable_debug_view: true
```

### 场景 2: 大型 3D 游戏

```
Main (Node)
└── AudioManager
    ├── global_limit_config:
    │   ├── max_total_voices: 64
    │   ├── max_virtual_voices: 256
    │   ├── virtual_voice_enabled: true
    │   ├── virtual_max_distance: 100.0
    │   └── bus_limits:
    │       {"Master": 64, "Music": 2, "SFX": 40, "Voice": 8}
    ├── default_categories:
    │   ├── Explosions (max_instances: 3, priority: HIGH)
    │   ├── Footsteps (max_instances: 15, priority: LOW)
    │   └── Gunshots (max_instances: 10, priority: HIGH)
    └── enable_debug_view: false
```

## 高级用法

### 运行时配置更新

```gdscript
# 根据性能动态调整
func _process(delta):
    var fps = Engine.get_frames_per_second()
    if fps < 30:
        var config = audio_manager.get_global_limit_config()
        config.max_total_voices = max(16, config.max_total_voices - 1)
        audio_manager.update_global_config(config)
```

### 多 AudioManager 层级

```gdscript
# 全局 AudioManager
var global_manager = AudioManager.new()
global_manager.name = "GlobalAudioManager"
add_child(global_manager)

# 子场景 AudioManager（继承配置）
var sub_manager = AudioManager.new()
sub_manager.name = "SubAudioManager"
sub_manager.enable_inheritance = true
add_child(sub_manager)
```

## 调试

### 启用调试视图

```gdscript
audio_manager.enable_debug_view = true
audio_manager.debug_update_interval = 0.5  # 每 0.5 秒更新
```

### 查看调试信息

```gdscript
func _process(delta):
    if audio_manager.enable_debug_view:
        var info = audio_manager.get_debug_info()
        print("Active players: ", info.audio_stats.active_players)
        print("Pool size 2D: ", info.audio_stats.pool_size_2d)
```

## 最佳实践

### 1. 每个场景一个 AudioManager
通常在每个主场景（level、menu 等）的根部放置一个 AudioManager。

### 2. 合理配置全局限额
根据目标平台性能调整：
- 移动平台: max_total_voices = 16-32
- 桌面平台: max_total_voices = 64-128
- 虚声部: max_virtual_voices = max_total_voices * 2

### 3. 使用类别管理相似音效
将爆炸、脚步声等相似音效分组管理，避免播放过多样本。

### 4. 在编辑器中配置
使用 Inspector 可视化配置，而非代码硬编码，便于调整。

### 5. 启用调试视图（开发阶段）
在开发时启用 `enable_debug_view`，发布时禁用以提升性能。

## 故障排除

### 问题: JuicyAudioPlayer 找不到 AudioManager

**解决方案:**
- 确保 AudioManager 已添加到场景树
- 确保 AudioManager 已完成 `_ready()`（使用 `await get_tree().process_frame`）
- 检查 AudioManager 是否在 "audio_manager" 组中

### 问题: 配置没有生效

**解决方案:**
- 检查配置资源是否有效（使用 `validate()` 方法）
- 确认配置在 AudioManager 添加到场景树前设置
- 查看控制台是否有错误或警告信息

### 问题: 音频播放过多

**解决方案:**
- 降低 `max_total_voices`
- 启用虚声部系统（`virtual_voice_enabled = true`）
- 使用类别限额（`default_categories`）

## 相关文档

- [AudioEventResource](./audio_event_resource.md) - 音频事件资源
- [AudioComponent](./audio_component.md) - 音频组件
- [JuicyAudioPlayer](./juicy_audio_player.md) - 音频播放器节点
- [AudioMixingConfig](./audio_mixing_config.md) - 混合配置
- [GlobalAudioLimitConfig](./global_audio_limit_config.md) - 全局限额配置

---

**版本**: 1.0
**最后更新**: 2026-01-15
**作者**: Claude (Subagent)
