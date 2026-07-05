# JuicyEventScheduler 实现文档

## 概述

JuicyEventScheduler 是 JuicyMixer V3 事件系统的核心组件，负责协调事件的分发和处理。它实现了完整的事件调度功能，包括事件处理器管理、批处理机制、性能优化和统计监控。

## 核心功能

### 1. 事件处理器管理
- **注册处理器**: `register_handler(handler, priority)` - 注册事件处理器并设置优先级
- **注销处理器**: `unregister_handler(handler_name)` - 移除指定处理器
- **获取处理器**: `get_handler(handler_name)` - 获取特定处理器实例
- **获取事件处理器**: `get_handlers_for_event(event_type)` - 获取处理特定事件类型的所有处理器

### 2. 事件处理逻辑
- **主处理方法**: `process_events(event_buffer, delta)` - 处理事件缓冲区中的事件
- **单事件处理**: `_process_single_event(event)` - 处理单个事件
- **批处理机制**: 支持可配置的批处理大小和最大处理时间
- **优先级排序**: 自动按处理器优先级排序

### 3. 性能优化
- **批处理**: 可配置的批处理大小 (`_batch_size = 50`)
- **时间限制**: 最大处理时间限制 (`_max_processing_time = 16ms`)
- **性能统计**: 详细的处理时间统计和事件计数

### 4. 配置管理
- **设置批处理大小**: `set_batch_size(size)`
- **设置最大处理时间**: `set_max_processing_time(time_ms)`

### 5. 统计和调试
- **获取统计信息**: `get_scheduler_stats()` - 返回详细的性能统计
- **调试打印**: `debug_print_handlers()` - 打印所有注册的处理器信息

## 文件结构

```
addons/juicy_mixer/events/
├── juicy_event_buffer.gd          # 事件缓冲区 (已实现)
├── juicy_event_scheduler.gd       # 事件调度器 (已实现)
├── juicy_event_handler.gd         # 事件处理器基类 (已实现)
├── event_scheduler_test_runner.gd # 测试运行器
├── test_event_scheduler_scene.tscn # 测试场景
├── event_scheduler_example.gd     # 使用示例
└── README.md                      # 本文档
```

## 使用示例

### 基本使用

```gdscript
# 创建事件系统组件
var scheduler = JuicyEventScheduler.new()
var buffer = JuicyEventBuffer.new()

# 创建自定义事件处理器
var handler = MyEventHandler.new()
scheduler.register_handler(handler, 100)

# 创建事件
var event = JuicyEventBuffer.JuicyEvent.new()
event.event_type = JuicyEventBuffer.EventType.AUDIO_PLAY
event.context_id = "gameplay"
event.target = self
event.priority = 50

# 添加事件到缓冲区
buffer.add_event(event)

# 处理事件
var processed = scheduler.process_events(buffer, delta)
```

### 自定义事件处理器

```gdscript
class MyEventHandler:
	extends JuicyEventHandler
	
	func _init():
		handler_name = "MyEventHandler"
		supported_events = [JuicyEventBuffer.EventType.AUDIO_PLAY]
		enabled = true
	
	func handle_event(event) -> bool:
		# 实现具体的事件处理逻辑
		print("Processing audio event")
		return true
```

## 性能特性

### 批处理机制
- 默认批处理大小：50个事件
- 可配置的最大处理时间：16毫秒
- 自动分批处理，避免帧率下降

### 优先级系统
- 支持处理器优先级设置（0-1000）
- 高优先级处理器先执行
- 同一事件类型支持多个处理器

### 性能监控
- 实时统计处理事件数量
- 记录总处理时间
- 计算平均处理时间
- 监控批处理性能

## 错误处理

- **处理器异常**: 单个处理器失败不会影响其他处理器
- **事件验证**: 自动验证事件有效性
- **资源限制**: 处理时间超出限制时自动停止
- **优雅降级**: 错误信息通过Godot的push_error系统输出

## 测试

运行测试：
1. 在Godot中打开测试场景：`test_event_scheduler_scene.tscn`
2. 运行场景查看测试结果
3. 测试包括：基本功能、优先级、批处理、性能测试

## 集成指南

### 与现有系统集成
1. 在插件中注册事件系统组件
2. 创建自定义事件处理器
3. 在游戏循环中调用 `process_events()`
4. 通过事件缓冲区管理事件生命周期

### 向后兼容性
- 事件系统完全可选
- 不启用时不影响现有功能
- 零性能开销设计

## 下一步开发

根据阶段4的详细计划，下一步需要实现：
1. **EventHandlingMiddleware** - 可选的事件处理中间件
2. **具体事件处理器** - 音频、粒子、UI等专用处理器
3. **系统集成** - 与Director、Context、Middleware系统的深度集成

## 注意事项

- 确保在使用前注册所有自定义类型
- 处理器应该实现完整的错误处理
- 注意批处理大小对性能的影响
- 定期检查和清理事件缓冲区

## 相关文档

- [阶段4事件系统核心设计](../docs/phase4_event_system_core_design.md)
- [事件缓冲区文档](juicy_event_buffer.gd)
- [事件处理器基类文档](juicy_event_handler.gd)
