# JuicyMixer V3 池化系统使用指南

## 概述

JuicyMixer V3 的池化系统提供了高效的对象重用机制，旨在减少内存分配开销和垃圾回收（GC）压力。池化系统包含以下核心组件：

- **JuicyPoolItem** - 对象池项数据结构，跟踪对象使用状态和生命周期
- **JuicyContextPool** - 专门用于管理 JuicyContext 对象的高效池化系统
- **JuicyObjectPool** - 通用对象池，可以管理多种对象类型
- **JuicyPoolManager** - 全局池管理器，统一管理所有对象池

## 快速开始

### 基本使用

池化系统已经完全集成到 JuicyMixer 中，大多数情况下您不需要直接操作池化系统：

```gdscript
# 播放效果（自动使用池化系统）
var context_id = JuicyMixer.play(shake_resource, target_node)

# 停止效果（自动返回到池中）
JuicyMixer.stop(context_id)
```

### 系统预热

在游戏加载时预热池化系统可以显著提高性能：

```gdscript
# 在游戏启动时调用
func _ready():
    # 预热所有池
    JuicyMixer.warm_up_pools()
```

## 高级使用

### 获取池管理器

如果您需要直接访问池化系统：

```gdscript
# 获取池管理器实例
var pool_manager = JuicyMixer.get_pool_manager()

# 获取特定池
var context_pool = pool_manager.get_context_pool()
var event_pool = pool_manager.get_event_pool()
var driver_pool = pool_manager.get_driver_pool(YourDriverScript)
var resource_pool = pool_manager.get_resource_pool(YourResourceScript)
```

### 直接使用对象池

如果您需要直接管理对象池：

```gdscript
# 获取Context池
var context_pool = JuicyMixer.get_pool_manager().get_context_pool()

# 从池中获取Context
var context = context_pool.get_context()

# 使用Context
context.resource = your_resource
context.target = your_target
context.activate()

# 返回Context到池中
context_pool.return_context(context)
```

### 通用对象池使用

```gdscript
# 创建对象池
var object_pool = JuicyObjectPool.new(YourScript, 50)

# 从池中获取对象
var obj = object_pool.get_object()

# 使用对象...

# 返回对象到池中
object_pool.return_object(obj)
```

## 性能监控

### 获取池统计信息

```gdscript
# 获取所有池的统计信息
var pool_stats = JuicyMixer.get_pool_statistics()
print("Context池统计: ", pool_stats.context_pool)
print("事件池统计: ", pool_stats.event_pool)
print("驱动器池统计: ", pool_stats.driver_pools)
print("资源池统计: ", pool_stats.resource_pools)

# 获取全局效率评分
var efficiency = JuicyMixer.get_pool_efficiency_score()
print("池效率评分: ", efficiency)
```

### 性能指标说明

池化系统提供以下性能指标：

- **total_allocated**: 总分配对象数
- **total_reused**: 总重用次数
- **reuse_ratio**: 重用率（目标：>90%）
- **efficiency_score**: 效率评分（0.0-1.0）
- **current_usage**: 当前使用对象数
- **peak_usage**: 峰值使用量

## 配置选项

### 池大小调整

```gdscript
# 获取Context池
var context_pool = JuicyMixer.get_pool_manager().get_context_pool()

# 设置池大小
context_pool.set_pool_size(100)

# 设置最大池大小
context_pool.set_max_pool_size(500)

# 设置最小池大小
context_pool.set_min_pool_size(10)
```

### 自动调整

```gdscript
# 启用/禁用自动调整
context_pool.enable_auto_resize(true)

# 设置调整阈值（使用率超过此值时扩容）
context_pool.set_resize_threshold(0.8)
```

### 清理配置

```gdscript
# 启用智能清理
context_pool.set_smart_cleanup(true)

# 设置最大空闲时间（超过此时间的未使用对象会被清理）
context_pool.set_max_idle_time(60.0)  # 60秒
```

## 最佳实践

### 1. 系统预热

在游戏加载时预热池化系统：

```gdscript
func _ready():
    # 预热池化系统
    JuicyMixer.warm_up_pools()
    
    # 预热特定类型的池
    var pool_manager = JuicyMixer.get_pool_manager()
    var driver_pool = pool_manager.get_driver_pool(YourDriverScript)
    driver_pool.warm_up(50)
```

### 2. 监控性能

定期检查池化系统的性能：

```gdscript
func _process(delta):
    if Engine.get_frames_drawn() % 600 == 0:  # 每10秒检查一次
        var stats = JuicyMixer.get_pool_statistics()
        var efficiency = JuicyMixer.get_pool_efficiency_score()
        
        if efficiency < 0.8:  # 效率低于80%时警告
            print("警告：池化系统效率较低: ", efficiency)
```

### 3. 内存管理

在场景切换时清理池：

```gdscript
func change_scene():
    # 停止所有效果
    JuicyMixer.stop_all()
    
    # 清理池（可选）
    JuicyMixer.clear_all_pools()
    
    # 切换场景...
```

### 4. 自定义对象池

为自定义类型创建对象池：

```gdscript
# 注册自定义驱动器池
var pool_manager = JuicyMixer.get_pool_manager()
pool_manager.register_driver_class(YourCustomDriver)

# 注册自定义资源池
pool_manager.register_resource_class(YourCustomResource)

# 获取池并使用
var driver_pool = pool_manager.get_driver_pool(YourCustomDriver)
var driver = driver_pool.get_object()

# 使用完毕后返回
driver_pool.return_object(driver)
```

## 故障排除

### 常见问题

1. **重用率低**
   - 检查池大小是否合适
   - 确保对象及时返回到池中
   - 考虑预热池

2. **内存使用过高**
   - 启用智能清理
   - 调整最大池大小
   - 定期清理未使用的池

3. **性能不佳**
   - 检查池效率评分
   - 调整自动调整阈值
   - 考虑使用更大的池大小

### 调试工具

```gdscript
# 启用调试日志
var pool_manager = JuicyMixer.get_pool_manager()
pool_manager.set_debug_logging(true)

# 获取详细状态
var detailed_status = pool_manager.get_detailed_status()
print("详细状态: ", detailed_status)

# 强制回收所有活跃对象
var returned = pool_manager.force_return_all_active()
print("强制回收对象数: ", returned)

# 清理未使用的池
var cleaned = pool_manager.cleanup_unused_pools()
print("清理的池数: ", cleaned)
```

## 性能基准

### 目标指标

- **对象重用率**: >90%
- **内存分配开销减少**: >80%
- **GC压力减少**: >70%
- **支持并发效果实例**: 1000+

### 性能测试

使用提供的性能测试工具：

```gdscript
# 运行完整性能测试
var perf_test = TestPoolingPerformance.new()
var results = perf_test.run_all_performance_tests()

# 运行快速性能测试
var quick_result = perf_test.quick_performance_test()

# 运行内存使用测试
var memory_result = perf_test.test_memory_usage()
```

## API 参考

### JuicyPoolManager

主要方法：
- `get_context_pool() -> JuicyContextPool`
- `get_event_pool() -> JuicyObjectPool`
- `get_driver_pool(script: Script) -> JuicyObjectPool`
- `get_resource_pool(script: Script) -> JuicyObjectPool`
- `get_all_pool_statistics() -> Dictionary`
- `get_global_efficiency_score() -> float`
- `warm_up_system() -> void`
- `clear_all_pools() -> void`

### JuicyContextPool

主要方法：
- `get_context() -> JuicyContext`
- `return_context(context: JuicyContext) -> void`
- `warm_up(count: int) -> void`
- `get_statistics() -> Dictionary`
- `set_pool_size(size: int) -> void`
- `enable_auto_resize(enabled: bool) -> void`

### JuicyObjectPool

主要方法：
- `get_object() -> Object`
- `return_object(obj: Object) -> void`
- `warm_up(count: int) -> void`
- `get_statistics() -> Dictionary`
- `set_pool_size(size: int) -> void`
- `clear_pool() -> void`

### JuicyPoolItem

主要方法：
- `mark_used() -> void`
- `mark_unused() -> void`
- `reset() -> void`
- `is_expired(max_idle_time: float) -> bool`
- `get_efficiency_score() -> float`

## 总结

JuicyMixer V3 的池化系统提供了强大而灵活的对象重用机制，通过合理使用可以显著提高游戏性能。关键要点：

1. **系统预热** - 在游戏加载时预热池
2. **性能监控** - 定期检查池效率
3. **合理配置** - 根据游戏需求调整池大小
4. **及时清理** - 在适当时机清理池

通过遵循这些最佳实践，您可以充分利用池化系统的优势，实现高性能的反馈效果系统。