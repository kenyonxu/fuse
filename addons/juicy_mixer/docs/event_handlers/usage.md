# EventHandlerEntry 使用指南

EventHandlerEntry 是一个资源类，用于在 Godot 编辑器中配置和管理 JuicyEventHandler 子类。它提供了类似于 MiddlewareEntry 的用户体验，让您可以通过下拉菜单选择项目中存在的事件处理器，并动态配置其参数。

## 功能特性

- **下拉选择**：通过枚举下拉菜单选择可用的事件处理器
- **动态配置**：根据选中处理器自动生成配置属性
- **类型安全**：确保只选择有效的 JuicyEventHandler 子类
- **编辑器集成**：资源名称自动更新，支持调试功能
- **配置管理**：支持默认配置和自定义配置覆盖

## 基本使用

### 1. 创建 EventHandlerEntry 资源

在 Godot 编辑器中：
1. 在文件系统面板中右键点击
2. 选择 "新建资源"
3. 搜索并选择 "EventHandlerEntry"
4. 保存资源文件（例如：`audio_handler_entry.tres`）

### 2. 选择事件处理器

在检查器面板中：
1. 找到 "Handler Class Name" 属性
2. 点击下拉箭头
3. 从列表中选择所需的事件处理器（如 `juicy_audio_event_handler`）

### 3. 配置事件处理器

选择处理器后，会自动显示该处理器的配置属性：
- `config_data.max_pool_size`：对象池大小
- `config_data.max_concurrent_sounds`：最大并发声音数
- `config_data.master_volume`：主音量
- `config_data.audio_bus`：音频总线
- `config_data.spatial_audio_enabled`：是否启用空间音频

### 4. 运行时创建处理器实例

```gdscript
# 加载事件处理器条目资源
var handler_entry = load("res://audio_handler_entry.tres")

# 创建配置好的事件处理器实例
var audio_handler = handler_entry.create_handler()

# 使用事件处理器
var event = JuicyEvent.create_audio_play_event(self, audio_stream, position)
if audio_handler.can_handle(event):
    audio_handler.handle_event(event)
```

## 代码示例

### 示例1：音频事件处理器配置

```gdscript
# 创建事件处理器条目
var entry = EventHandlerEntry.new()
entry.handler_class_name = "juicy_audio_event_handler"

# 配置参数
entry.config_data = {
    "max_pool_size": 30,
    "max_concurrent_sounds": 15,
    "master_volume": 0.8,
    "audio_bus": "SFX",
    "spatial_audio_enabled": true
}

# 创建处理器实例
var handler = entry.create_handler()
```

### 示例2：粒子事件处理器配置

```gdscript
# 创建事件处理器条目
var entry = EventHandlerEntry.new()
entry.handler_class_name = "juicy_particle_event_handler"

# 配置参数
entry.config_data = {
    "max_pool_size": 20,
    "max_concurrent_systems": 10,
    "auto_cleanup_time": 5.0
}

# 创建处理器实例
var handler = entry.create_handler()
```

### 示例3：批量管理多个处理器

```gdscript
# 管理多个事件处理器
var handler_entries = []

# 音频处理器
var audio_entry = EventHandlerEntry.new()
audio_entry.handler_class_name = "juicy_audio_event_handler"
audio_entry.enabled = true
handler_entries.append(audio_entry)

# 粒子处理器
var particle_entry = EventHandlerEntry.new()
particle_entry.handler_class_name = "juicy_particle_event_handler"
particle_entry.enabled = true
handler_entries.append(particle_entry)

# 创建所有处理器实例
var handlers = []
for entry in handler_entries:
    if entry.enabled:
        var handler = entry.create_handler()
        if handler:
            handlers.append(handler)

# 使用处理器处理事件
func handle_game_event(event: JuicyEvent):
    for handler in handlers:
        if handler.can_handle(event):
            handler.handle_event(event)
```

## 调试功能

### 查看可用处理器

```gdscript
# 打印所有可用的事件处理器
var entry = EventHandlerEntry.new()
entry.debug_print_available_handlers()
```

### 强制重新扫描

```gdscript
# 清除扫描缓存并重新扫描
EventHandlerEntry.clear_scan_cache()

# 或者使用便捷方法
EventHandlerEntry.rescan_handlers()
```

### 获取配置统计

```gdscript
var entry = EventHandlerEntry.new()
entry.handler_class_name = "juicy_audio_event_handler"

var stats = entry.get_config_stats()
print("配置统计: ", stats)
# 输出: {"has_script": true, "enabled": true, "config_keys": [...], "default_keys": [...]}
```

## 事件处理器开发指南

### 创建自定义事件处理器

```gdscript
# my_custom_event_handler.gd
class_name MyCustomEventHandler
extends JuicyEventHandler

func _init():
    handler_name = "MyCustomHandler"
    supported_events = [JuicyEvent.EventType.CUSTOM_EVENT]
    description = "处理自定义事件"

func handle_event(event: JuicyEvent) -> bool:
    # 实现事件处理逻辑
    print("处理自定义事件: ", event.event_data)
    return true

func get_configuration() -> Dictionary:
    return {
        "custom_param1": 100,
        "custom_param2": "default_value",
        "custom_param3": true
    }

func configure(config: Dictionary) -> void:
    # 应用配置
    for key in config.keys():
        if key in self:
            self.set(key, config[key])
```

### 配置模式支持

事件处理器通过 `get_configuration()` 方法提供配置字典，EventHandlerEntry 会自动分析这些配置项的类型并生成对应的编辑器属性。

支持的类型：
- `int`：整数类型
- `float`：浮点数类型
- `bool`：布尔类型
- `String`：字符串类型
- `Array`：数组类型
- `Dictionary`：字典类型
- `Vector2`：2D向量类型
- `Vector3`：3D向量类型
- `Color`：颜色类型

## 最佳实践

### 1. 资源组织
- 将 EventHandlerEntry 资源保存在专门的配置文件夹中
- 使用描述性的文件名（如 `audio_handler_config.tres`）
- 为不同类型的处理器创建不同的资源文件

### 2. 配置管理
- 使用默认配置作为基础
- 只覆盖需要修改的配置项
- 在运行时检查配置的有效性

### 3. 性能优化
- 重用处理器实例而不是频繁创建
- 在不需要时禁用处理器
- 使用对象池管理处理器生命周期

### 4. 调试和测试
- 使用 `debug_print_available_handlers()` 检查可用处理器
- 使用 `get_config_stats()` 验证配置
- 在开发阶段启用详细的日志记录

## 常见问题

### Q: 为什么我的自定义事件处理器没有出现在下拉列表中？
A: 确保：
1. 脚本文件以 `.gd` 结尾
2. 文件名不以 `_` 开头
3. 类继承自 `JuicyEventHandler`
4. 文件位于扫描路径中（`addons/juicy_mixer/events/` 等）

### Q: 配置属性没有正确显示怎么办？
A: 尝试：
1. 强制刷新属性列表：`force_refresh_property_list()`
2. 重新扫描处理器：`rescan_handlers()`
3. 检查处理器的 `get_configuration()` 方法返回值

### Q: 如何处理配置验证错误？
A: EventHandlerEntry 会自动验证配置类型，确保：
1. 配置值类型与处理器期望的类型匹配
2. 配置键名正确无误
3. 在 `configure()` 方法中添加额外的验证逻辑

## 总结

EventHandlerEntry 提供了一个强大而灵活的方式来管理和配置事件处理器，让您可以在 Godot 编辑器中直观地配置事件处理系统，同时保持代码的整洁和可维护性。通过动态属性生成和类型安全的配置管理，它大大简化了事件处理器的使用和维护工作。