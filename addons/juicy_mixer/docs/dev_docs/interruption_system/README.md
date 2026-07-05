# JuicyMixer 中断策略系统文档

## 概述

JuicyMixer中断策略系统是一个强大的效果管理框架，提供了多种中断策略来处理效果之间的交互和过渡。该系统允许开发者精确控制效果如何响应新的效果请求，确保游戏中的反馈效果能够流畅、自然地呈现。

## 文档结构

### API文档
- [InterruptionState API文档](api/InterruptionState.md) - 中断状态数据结构
- [ChannelInterruptionConfig API文档](api/ChannelInterruptionConfig.md) - 通道中断配置
- [JuicyInterruptionManager API文档](api/JuicyInterruptionManager.md) - 中断管理器
- [InterruptionMiddleware API文档](api/InterruptionMiddleware.md) - 中断中间件
- [JuicyMixerEnums中断策略枚举API文档](api/JuicyMixerEnums.md) - 中断策略枚举
- [JuicyFeedbackResource中断相关API文档](api/JuicyFeedbackResource.md) - 反馈资源中断接口

### 使用示例
- [基础中断策略使用示例](examples/basic_interruption_examples.md)
- [高级中断配置示例](examples/advanced_interruption_examples.md)
- [自定义中断策略示例](examples/custom_interruption_examples.md)
- [中断事件处理示例](examples/interruption_event_examples.md)
- [性能优化示例](examples/performance_optimization_examples.md)

### 集成指南
- [中断系统集成步骤](guides/integration_guide.md)
- [配置最佳实践](guides/configuration_best_practices.md)
- [性能调优建议](guides/performance_tuning.md)
- [故障排除指南](guides/troubleshooting.md)
- [开发者扩展指南](guides/developer_extension_guide.md)

### 完成总结
- [中断策略系统开发完成总结](completion_summary.md)
- [系统概述和特性](system_overview.md)
- [架构设计说明](architecture_design.md)
- [开发过程回顾](development_process.md)
- [测试结果总结](test_results.md)
- [性能指标报告](performance_metrics.md)
- [后续改进建议](future_improvements.md)

## 快速开始

### 基本使用

```gdscript
# 设置中断策略
var feedback_resource = JuicyFeedbackResource.new()
feedback_resource.interruption_policy = JuicyMixerEnms.InterruptionPolicy.STACK

# 播放效果
JuicyMixer.play(feedback_resource, target_node)

# 设置通道级配置
var channel_config = ChannelInterruptionConfig.new()
channel_config.default_policy = JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE
JuicyMixer.set_channel_interruption_config("ui_effects", channel_config)
```

### 中断策略类型

1. **STACK (堆叠)**: 新效果加入队列，当前效果继续执行
2. **RESTART (重启)**: 立即停止当前效果，开始新效果
3. **IGNORE (忽略)**: 忽略新效果，保持当前效果
4. **SMOOTH_TRANSITION (平滑过渡)**: 平滑地从当前效果过渡到新效果
5. **PRIORITY_OVERRIDE (优先级覆盖)**: 高优先级效果覆盖低优先级效果
6. **FADE_OUT_FADE_IN (淡出淡入)**: 当前效果淡出，新效果淡入
7. **PRIORITY_STACK (优先级堆叠)**: 按优先级插入队列

## 系统特性

- 🎯 **多种中断策略**: 提供7种不同的中断处理策略
- 🔧 **灵活配置**: 支持全局、通道和资源级别的配置
- 📊 **性能监控**: 内置性能统计和监控功能
- 🔄 **平滑过渡**: 支持效果间的平滑过渡动画
- 📝 **历史记录**: 完整的中断历史记录和回放功能
- 🎮 **事件驱动**: 基于事件的系统设计，易于扩展
- 🚀 **高性能**: 优化的中断处理和状态管理

## 版本信息

- **当前版本**: 1.0.0
- **兼容性**: Godot 4.0+
- **最后更新**: 2024年

## 贡献

欢迎提交问题报告和功能请求到项目的GitHub仓库。

## 许可证

本项目采用MIT许可证。