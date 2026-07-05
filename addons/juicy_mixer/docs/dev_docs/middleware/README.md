# JuicyMiddleware 使用指南

## 概述

JuicyMiddleware 是一个强大的中间件系统基类，为JuicyMixer V3提供了可扩展的管道式处理能力。通过继承JuicyMiddleware，开发者可以创建自定义的中间件来扩展系统的功能。

## 核心特性

### 1. 生命周期管理
- **Context生命周期钩子**: `on_context_created()`, `on_context_destroyed()`, `on_context_paused()`, `on_context_resumed()`
- **完整的生命周期跟踪**: 自动跟踪Context的创建、销毁、暂停和恢复
- **状态管理**: 提供内部状态管理和上下文引用

### 2. 性能监控
- **执行统计**: 自动记录执行次数、执行时间、错误计数
- **性能指标**: 提供平均执行时间、总执行时间等关键指标
- **可配置监控**: 支持启用/禁用性能监控

### 3. 配置管理
- **灵活配置**: 支持运行时配置和默认配置
- **配置验证**: 自动验证配置值的类型和有效性
- **配置模式**: 支持配置模式定义和验证

### 4. 错误处理
- **错误隔离**: 单个中间件的错误不会影响整个系统
- **详细日志**: 提供错误日志、警告日志和调试日志
- **错误恢复**: 支持错误状态恢复和降级处理

### 5. 优先级控制
- **执行顺序**: 通过优先级控制中间件的执行顺序
- **动态调整**: 支持运行时调整中间件的优先级
- **链式执行**: 实现洋葱模型的链式处理

## 基本使用

### 1. 创建自定义中间件

```gdscript
# 创建自定义中间件
class_name CustomMiddleware
extends JuicyMiddleware

func _init():
	# 设置中间件基本信息
	middleware_name = "CustomMiddleware"
	middleware_version = "1.0.0"
	priority = 100
	description = "自定义中间件示例"
	author = "Your Name"

# 实现核心处理逻辑
func process(context: JuicyContext, next: Callable) -> bool:
	# 在处理前执行逻辑
	_pre_process(context)
	
	# 调用下一个中间件
	var result = next.call()
	
	# 在处理后执行逻辑
	if result:
		_post_process(context)
	
	return result

# 实现清理逻辑
func cleanup(context: JuicyContext) -> void:
	# 清理资源
	pass

# 实现生命周期钩子
func on_context_created(context: JuicyContext) -> void:
	# Context创建时的初始化逻辑
	pass

func on_context_destroyed(context: JuicyContext) -> void:
	# Context销毁时的清理逻辑
	pass

func on_context_paused(context: JuicyContext) -> void:
	# Context暂停时的逻辑
	pass

func on_context_resumed(context: JuicyContext) -> void:
	# Context恢复时的逻辑
	pass
```

### 2. 初始化和配置中间件

```gdscript
# 创建中间件实例
var middleware = CustomMiddleware.new()

# 初始化中间件
var config = {
	"enable_performance_monitoring": true,
	"enable_debug_logging": true,
	"priority": 100,
	"custom_parameter": "value"
}

if middleware.initialize(config):
	print("中间件初始化成功")
else:
	print("中间件初始化失败")
```

### 3. 执行中间件

```gdscript
# 创建Context
var context = JuicyContext.create(resource, target_node)

# 处理Context生命周期事件
middleware.handle_context_event(context, "created")

# 执行中间件处理
var next_callback = func():
	# 这里是下一个中间件的调用
	return true

var result = middleware.execute(context, next_callback)

if result:
	print("中间件执行成功")
else:
	print("中间件执行失败")
```

### 4. 性能监控和调试

```gdscript
# 获取性能统计
var stats = middleware.get_performance_stats()
print("执行次数:", stats.execution_count)
print("平均执行时间:", stats.average_execution_time, "ms")

# 获取错误日志
var error_log = middleware.get_error_log()
for error in error_log:
	print("错误:", error.message)

# 启用调试日志
middleware.set_debug_logging(true)

# 重置性能统计
middleware.reset_performance_stats()
```

## 高级特性

### 1. 配置验证

```gdscript
# 设置配置模式
middleware.set_configuration_schema({
	"enable_monitoring": {"type": "bool"},
	"timeout": {"type": "float"},
	"max_retries": {"type": "int"}
})

# 配置中间件
var config = {
	"enable_monitoring": true,
	"timeout": 5.0,
	"max_retries": 3
}

middleware.configure(config)
```

### 2. Context数据验证

```gdscript
# 重写验证方法
func _validate_required_context_data(context: JuicyContext) -> bool:
	# 检查必需的数据
	if not context.resource:
		return false
	
	if not context.target:
		return false
	
	# 检查特定的数据
	if not context.get_driver_data("required_data"):
		return false
	
	return true

func _validate_target_node(context: JuicyContext) -> bool:
	# 检查目标节点是否支持特定属性
	if not "position" in context.target:
		return false
	
	return true
```

### 3. 动态控制

```gdscript
# 启用/禁用中间件
middleware.set_active(true)

# 获取当前状态
if middleware.is_ready():
	print("中间件已准备好执行")

# 获取当前上下文
var current_context = middleware.get_current_context()
```

## 最佳实践

### 1. 性能优化
- **合理使用性能监控**: 在开发阶段启用性能监控，在生产阶段可以禁用
- **避免阻塞操作**: 在`process()`方法中避免耗时操作
- **使用缓存**: 对于重复计算的结果，考虑使用缓存机制

### 2. 错误处理
- **详细的错误信息**: 在错误日志中提供足够的上下文信息
- **优雅降级**: 当出现错误时，提供降级处理方案
- **错误恢复**: 实现适当的错误恢复机制

### 3. 配置管理
- **合理的默认值**: 提供合理的默认配置值
- **配置验证**: 实现严格的配置验证机制
- **配置文档**: 为配置参数提供清晰的文档说明

### 4. 生命周期管理
- **及时清理**: 在`cleanup()`方法中及时释放资源
- **状态一致性**: 保持中间件状态的一致性
- **异常处理**: 处理生命周期中的异常情况

## 示例中间件

参考 `example_middleware.gd` 文件，它展示了一个完整的中间件实现，包括：
- 基本的元信息设置
- 核心处理逻辑实现
- 生命周期钩子实现
- 配置管理
- 验证逻辑
- 性能监控

## 常见问题

### Q: 如何调试中间件？
A: 启用调试日志和性能监控，使用`get_error_log()`和`get_debug_log()`方法查看详细的执行信息。

### Q: 如何处理中间件间的数据共享？
A: 使用Context的`set_middleware_data()`和`get_middleware_data()`方法来在中间件间共享数据。

### Q: 如何优化中间件性能？
A: 避免在`process()`方法中进行耗时操作，合理使用缓存，启用性能监控来识别性能瓶颈。

### Q: 如何处理中间件执行失败？
A: 在`process()`方法中检查返回值，实现适当的错误处理和恢复机制。

## API 参考

详细的API参考请查看 `juicy_middleware.gd` 文件中的方法注释。

## 总结

JuicyMiddleware 提供了一个强大而灵活的中间件系统，支持：
- 完整的生命周期管理
- 性能监控和调试
- 灵活的配置管理
- 强大的错误处理
- 优先级控制
- 链式执行

通过合理使用这些特性，开发者可以创建高效、可靠、可扩展的中间件来增强JuicyMixer系统的功能。
