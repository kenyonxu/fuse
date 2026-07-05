# JuicyMixer 中间件系统集成指南

## 概述

本指南介绍了如何将中间件系统集成到JuicyMixer中，以及如何使用中间件系统来扩展和自定义效果处理流程。

## 系统架构

### 核心组件

1. **JuicyMiddlewarePipeline** - 中间件管道管理系统
   - 管理中间件的注册、排序和执行
   - 提供性能监控和错误处理
   - 支持动态启用/禁用中间件

2. **JuicyMiddleware** - 中间件基类
   - 定义所有中间件的通用接口
   - 提供生命周期管理和性能监控
   - 支持配置验证和错误处理

3. **集成点** - 与JuicyDirector和JuicyMixer的集成
   - 在Context创建时触发中间件钩子
   - 在效果播放前执行中间件管道
   - 在Context生命周期中调用相应钩子

## 快速开始

### 1. 创建自定义中间件

```gdscript
# 自定义中间件示例
class_name MyCustomMiddleware
extends JuicyMiddleware

func _init():
	middleware_name = "MyCustomMiddleware"
	priority = 100  # 优先级，数字越小执行越早
	description = "我的自定义中间件"
	tags = ["validation", "custom"]

func process(context: JuicyContext, next: Callable) -> bool:
	# 在这里实现中间件的核心逻辑
	print("处理Context: ", context.context_id)
	
	# 可以修改context数据
	context.set_user_data("processed", true)
	
	# 继续执行链
	return next.call()

func on_context_created(context: JuicyContext) -> void:
	# Context创建时的处理
	print("Context创建: ", context.context_id)

func on_context_destroyed(context: JuicyContext) -> void:
	# Context销毁时的清理
	print("Context销毁: ", context.context_id)
```

### 2. 注册中间件

```gdscript
# 创建中间件实例
var my_middleware = MyCustomMiddleware.new()

# 添加到JuicyMixer的中间件管道
var success = JuicyMixer.add_middleware(my_middleware)
if success:
	print("中间件添加成功")
else:
	print("中间件添加失败")
```

### 3. 使用效果系统

```gdscript
# 创建资源和目标
var resource = load("res://effects/my_effect.tres")
var target_node = $MyNode

# 播放效果（会自动经过中间件处理）
var context_id = JuicyMixer.play(resource, target_node)

# 管理效果
JuicyMixer.pause(context_id)    # 暂停
JuicyMixer.resume(context_id)   # 恢复
JuicyMixer.stop(context_id)     # 停止
```

## 高级用法

### 动态管理中间件

```gdscript
# 启用/禁用中间件
JuicyMixer.enable_middleware("MyCustomMiddleware")
JuicyMixer.disable_middleware("MyCustomMiddleware")

# 移除中间件
JuicyMixer.remove_middleware("MyCustomMiddleware")

# 获取中间件信息
var middleware = JuicyMixer.get_middleware("MyCustomMiddleware")
if middleware:
	print("中间件状态: ", "激活" if middleware.is_active else "禁用")
```

### 性能监控

```gdscript
# 获取性能统计
var stats = JuicyMixer.get_middleware_performance_stats()

# 管道整体性能
var pipeline_stats = stats.pipeline_stats
print("总执行次数: ", pipeline_stats.execution_count)
print("平均执行时间: ", pipeline_stats.average_execution_time, "ms")

# 单个中间件性能
for middleware_stat in stats.middleware_stats:
	print("中间件: ", middleware_stat.middleware_name)
	print("  执行次数: ", middleware_stat.execution_count)
	print("  平均时间: ", middleware_stat.average_execution_time, "ms")
```

### 配置管理

```gdscript
# 配置中间件管道
var pipeline = JuicyMixer.get_middleware_pipeline()
pipeline.set_configuration({
	"enable_performance_monitoring": true,
	"enable_debug_logging": true,
	"max_retry_attempts": 5,
	"execution_timeout": 2000.0
})

# 配置单个中间件
var middleware = JuicyMixer.get_middleware("MyCustomMiddleware")
middleware.configure({
	"custom_setting": "value",
	"threshold": 0.5
})
```

## 生命周期钩子

中间件系统提供了完整的Context生命周期钩子：

1. **on_context_created** - Context创建时调用
2. **on_context_destroyed** - Context销毁时调用
3. **on_context_paused** - Context暂停时调用
4. **on_context_resumed** - Context恢复时调用

这些钩子允许中间件在适当的时机执行初始化和清理操作。

## 错误处理

中间件系统具有完善的错误处理机制：

```gdscript
func process(context: JuicyContext, next: Callable) -> bool:
	try:
		# 中间件逻辑
		if some_condition:
			return false  # 返回false中断执行链
			
		return next.call()
	except:
		# 错误处理
		return false
```

系统会自动记录错误并重试（如果启用错误恢复）。

## 最佳实践

### 1. 优先级设计
- 验证类中间件：优先级 0-50
- 处理类中间件：优先级 50-100
- 后处理类中间件：优先级 100-200

### 2. 性能考虑
- 避免在中间件中执行耗时操作
- 使用性能监控来识别瓶颈
- 合理设置执行超时时间

### 3. 错误处理
- 始终验证输入数据
- 提供有意义的错误信息
- 考虑使用错误恢复机制

### 4. 资源管理
- 在`on_context_destroyed`中清理资源
- 避免内存泄漏
- 使用适当的日志级别

## 调试和故障排除

### 启用调试日志
```gdscript
var pipeline = JuicyMixer.get_middleware_pipeline()
pipeline.set_configuration({
	"enable_debug_logging": true
})
```

### 查看错误日志
```gdscript
var pipeline = JuicyMixer.get_middleware_pipeline()
var error_log = pipeline.get_error_log()
for error in error_log:
	print("错误: ", error.message)
	print("详情: ", error.details)
```

### 导出日志
```gdscript
var pipeline = JuicyMixer.get_middleware_pipeline()
pipeline.export_logs("user://middleware_log.json")
```

## 示例项目

参考 `addons/juicy_mixer/tests/test_middleware_integration.gd` 获取完整的集成测试示例。

## 总结

JuicyMixer的中间件系统提供了强大而灵活的扩展机制，允许开发者：

1. 自定义效果处理流程
2. 添加验证和预处理逻辑
3. 监控和优化性能
4. 实现复杂的业务逻辑

通过合理使用中间件系统，可以构建出高度可定制和可维护的效果系统。
