# EventHandlerEntry 快速开始指南

## 什么是 EventHandlerEntry？

EventHandlerEntry 是一个 Godot 资源类，让您可以在编辑器中通过下拉菜单选择和配置 JuicyEventHandler 子类，类似于 MiddlewareEntry 的功能。

## 核心功能

✅ **下拉选择**：从可用的事件处理器列表中选择  
✅ **动态配置**：自动生成配置属性界面  
✅ **类型安全**：确保选择有效的事件处理器  
✅ **编辑器集成**：资源名称自动更新  
✅ **配置管理**：支持默认配置和自定义配置  

## 快速开始

### 步骤1：创建资源
1. 在文件系统中右键点击 → 新建资源
2. 搜索 "EventHandlerEntry"
3. 保存为 `.tres` 文件

### 步骤2：选择处理器
1. 在检查器中找到 "Handler Class Name"
2. 点击下拉箭头选择处理器（如 `juicy_audio_event_handler`）

### 步骤3：配置参数
选择处理器后，会自动显示配置属性：
- `config_data.max_pool_size`
- `config_data.max_concurrent_sounds`
- `config_data.master_volume`
- 等等...

### 步骤4：代码中使用
```gdscript
# 加载资源
var handler_entry = load("res://my_audio_handler.tres")

# 创建处理器实例
var handler = handler_entry.create_handler()

# 使用处理器
var event = JuicyEvent.create_audio_play_event(self, audio_stream)
if handler.can_handle(event):
    handler.handle_event(event)
```

## 可用的事件处理器

| 处理器类名 | 功能 | 主要配置 |
|------------|------|----------|
| `juicy_audio_event_handler` | 音频播放控制 | 音量、并发数、对象池 |
| `juicy_particle_event_handler` | 粒子效果管理 | 粒子数量、清理时间 |
| 自定义处理器 | 您自己的处理器 | 根据实现而定 |

## 代码示例

### 基本使用
```gdscript
var entry = EventHandlerEntry.new()
entry.handler_class_name = "juicy_audio_event_handler"
entry.config_data = {"master_volume": 0.8}

var handler = entry.create_handler()
```

### 批量管理
```gdscript
var handlers = []
for entry in handler_entries:
    if entry.enabled:
        handlers.append(entry.create_handler())
```

## 调试功能

```gdscript
# 查看可用处理器
entry.debug_print_available_handlers()

# 重新扫描处理器
EventHandlerEntry.rescan_handlers()

# 获取配置统计
var stats = entry.get_config_stats()
```

## 注意事项

1. **文件位置**：自定义处理器需放在扫描路径中（`addons/juicy_mixer/events/` 等）
2. **继承要求**：处理器必须继承自 `JuicyEventHandler`
3. **配置类型**：确保配置值类型与处理器期望的类型匹配
4. **资源清理**：使用完毕后调用 `handler.cleanup()` 清理资源

## 故障排除

### 处理器不显示在下拉列表中
- 检查文件是否以 `.gd` 结尾
- 确保文件名不以 `_` 开头
- 验证类是否正确继承 `JuicyEventHandler`
- 确认文件在扫描路径中

### 配置属性不显示
- 尝试 `entry.force_refresh_property_list()`
- 检查处理器的 `get_configuration()` 方法返回值
- 确保处理器脚本没有错误

### 处理器创建失败
- 检查脚本路径是否正确
- 验证处理器类名是否准确
- 查看控制台错误信息

## 下一步

- 查看 [完整使用指南](event_handler_entry_usage.md)
- 运行 [示例场景](../examples/EventHandlerEntryExampleScene.tscn)
- 阅读 [API 文档](#)

EventHandlerEntry 让事件处理器的配置变得简单直观，大大提升了开发效率！