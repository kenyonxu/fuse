# 事件处理器

欢迎来到 JuicyMixer 事件处理器文档！事件处理器用于响应游戏中的各种事件。

## 📚 文档目录

1. [快速开始](quick_start.md) - 事件处理器快速入门
2. [使用指南](usage.md) - 事件处理器详细说明

## 🔧 事件处理器类型

### 内置事件处理器
- **JuicyAudioEventHandler** - 处理音频播放和停止事件
- **JuicyParticleEventHandler** - 处理粒子生成和停止事件
- **JuicySequenceEventHandler** - 处理序列触发事件

### 自定义事件处理器
你可以通过继承 `JuicyEventHandler` 基类来创建自定义的事件处理器。

## 🚀 快速开始

```gdscript
# 创建事件处理器资源
var event_handler = EventHandlerEntry.new()
event_handler.handler_class_name = "juicy_audio_event_handler"

# 配置事件处理器
event_handler.config = {
    "audio_stream": preload("res://sounds/hit.wav"),
    "volume": 0.8
}
```

## 📖 相关文档

- [用户文档](../user_docs/) - JuicyMixer 通用文档
- [API 参考](../user_docs/api_reference.md) - 完整 API 参考

---

**返回**: [文档中心](../README.md)
