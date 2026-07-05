# 池化系统开发计划

## 概述

本文档详细描述了JuicyMixer V3中池化系统的开发计划。该系统提供了高效的对象池化解决方案，包括上下文对象池、通用对象池和内存池管理，确保系统能够高效处理大量并发效果实例而不产生过多的内存分配开销。

## 系统架构

池化系统由以下核心组件构成：

- **JuicyContextPool** - 上下文对象池
- **JuicyObjectPool** - 通用对象池
- **JuicyPoolItem** - 对象池项数据结构

## 与现有系统的集成

### 全局池化
- 所有系统需要支持对象池化
- 所有组件需要考虑内存使用优化
- 池化系统需要与Director的Context管理集成

### Director系统集成
- 池化系统需要与Director的Context管理集成
- Context池需要支持Director的生命周期管理

### Middleware系统集成
- 池化系统需要支持Middleware的动态加载
- 对象池需要支持不同类型的Middleware实例

### 事件系统集成
- 池化系统需要支持事件系统的资源需求
- 事件对象需要通过池化系统管理

## 开发时间线

**总体时间**：第16周前半周（共3天）

## JuicyPoolItem (对象池项)

**文件路径**：`addons/juicy_mixer/core/juicy_pool_item.gd`

**核心职责**：
- 表示对象池中的单个项
- 跟踪对象使用状态
- 提供生命周期管理
- 支持过期检测

**详细实现计划**：

```gdscript
@tool
class_name JuicyPoolItem
extends RefCounted

# 对象池项数据结构
var object: Object
var in_use: bool = false
var last_used: float = 0.0
var creation_time: float = 0.0
var usage_count: int = 0

func _init(obj: Object = null):
	object = obj
	creation_time = Time.get_ticks_msec() / 1000.0

func mark_used() -> void:
	in_use = true
	last_used = Time.get_ticks_msec() / 1000.0
	usage_count += 1

func mark_unused() -> void:
	in_use = false
	last_used = Time.get_ticks_msec() / 1000.0

func reset() -> void:
	in_use = false
	last_used = 0.0
	usage_count = 0

func is_expired(max_idle_time: float = 60.0) -> bool:
	if in_use:
		return false
	var current_time = Time.get_ticks_msec() / 1000.0
	return current_time - last_used > max_idle_time

func get_lifetime() -> float:
	var current_time = Time.get_ticks_msec() / 1000.0
	return current_time - creation_time

func get_idle_time() -> float:
	if in_use:
		return 0.0
	var current_time = Time.get_ticks_msec() / 1000.0
	return current_time - last_used
```

**开发任务分解**：
- [ ] 第16周第1天：对象池项基础实现
- [ ] 第16周第1天：生命周期管理
- [ ] 第16周第1天：过期检测机制

## JuicyContextPool (上下文对象池)

**文件路径**：`addons/juicy_mixer/core/juicy_context_pool.gd`

**核心职责**：
- 管理Context对象池
- 提供高效的Context分配
- 实现内存优化
- 支持池大小动态调整

**详细实现计划**：

```gdscript
class_name JuicyContextPool
extends RefCounted

# 对象池管理
var _available_contexts: Array[JuicyContext] = []
var _active_contexts: Dictionary = {}
var _pool_size: int = 100
var _max_pool_size: int = 500
var _min_pool_size: int = 10
var _auto_resize: bool = true
var _resize_threshold: float = 0.8

# 统计信息
var _total_allocated: int = 0
var _total_reused: int = 0
var _peak_usage: int = 0
var _resize_count: int = 0

# 池配置
var _warm_up_count: int = 20
var _cleanup_interval: float = 5.0  # 秒
var _last_cleanup_time: float = 0.0
var _prewarmed: bool = false  # 是否已预热

func get_context() -> JuicyContext:
	if _available_contexts.size() > 0:
		var context = _available_contexts.pop_back()
		context.reset()
		_active_contexts[context.get_instance_id()] = context
		_total_reused += 1
		return context
	
	# 池为空，创建新Context
	var context = JuicyContext.new()
	_active_contexts[context.get_instance_id()] = context
	_total_allocated += 1
	
	# 更新峰值使用量
	var current_usage = _active_contexts.size()
	if current_usage > _peak_usage:
		_peak_usage = current_usage
	
	return context

func return_context(context: JuicyContext) -> void:
	if not context:
		return
	
	var context_id = context.get_instance_id()
	if not _active_contexts.has(context_id):
		return
	
	# 从活跃列表移除
	_active_contexts.erase(context_id)
	
	# 重置Context状态
	context.reset()
	
	# 返回池中
	if _available_contexts.size() < _pool_size:
		_available_contexts.append(context)
	else:
		# 池已满，让GC回收
		context = null

func warm_up(count: int) -> void:
	for i in range(count):
		var context = JuicyContext.new()
		_available_contexts.append(context)
		_total_allocated += 1
	_prewarmed = true

# 静态预热方法，用于游戏加载时调用
static func warm_up_system() -> void:
	# 预热ContextPool
	var context_pool = JuicyContextPool.new()
	context_pool.warm_up(50)
	
	# 预热ObjectPool
	var common_types = [JuicyContext, JuicyTweenResource, JuicyShakeResource]
	for type in common_types:
		var object_pool = JuicyObjectPool.new(type, 20)
		object_pool.warm_up(20)
	
	print("JuicyMixer pooling system warmed up successfully")

func set_pool_size(size: int) -> void:
	_pool_size = clamp(size, _min_pool_size, _max_pool_size)
	_adjust_pool_size()

func set_max_pool_size(size: int) -> void:
	_max_pool_size = max(size, _min_pool_size)
	_pool_size = min(_pool_size, _max_pool_size)
	_adjust_pool_size()

func set_min_pool_size(size: int) -> void:
	_min_pool_size = max(size, 1)
	_pool_size = max(_pool_size, _min_pool_size)
	_adjust_pool_size()

func enable_auto_resize(enabled: bool) -> void:
	_auto_resize = enabled

func set_resize_threshold(threshold: float) -> void:
	_resize_threshold = clamp(threshold, 0.1, 1.0)

func _adjust_pool_size() -> void:
	# 调整池大小
	while _available_contexts.size() > _pool_size:
		_available_contexts.pop_back()
	
	while _available_contexts.size() < _pool_size and _total_allocated < _max_pool_size:
		var context = JuicyContext.new()
		_available_contexts.append(context)
		_total_allocated += 1

func process_auto_resize() -> void:
	if not _auto_resize:
		return
	
	var current_usage = _active_contexts.size()
	var total_capacity = _available_contexts.size() + current_usage
	var usage_ratio = float(current_usage) / float(total_capacity)
	
	# 如果使用率超过阈值，增加池大小
	if usage_ratio > _resize_threshold:
		var new_size = min(_pool_size * 2, _max_pool_size)
		if new_size != _pool_size:
			set_pool_size(new_size)
			_resize_count += 1
	# 如果使用率很低，减少池大小
	elif usage_ratio < _resize_threshold * 0.5:
		var new_size = max(_pool_size / 2, _min_pool_size)
		if new_size != _pool_size:
			set_pool_size(new_size)
			_resize_count += 1

func process_cleanup(delta: float) -> void:
	_last_cleanup_time += delta
	
	if _last_cleanup_time >= _cleanup_interval:
		_cleanup_expired_contexts()
		_last_cleanup_time = 0.0

func _cleanup_expired_contexts() -> void:
	# 清理过期的Context
	var current_time = Time.get_ticks_msec() / 1000.0
	var expired_contexts: Array[JuicyContext] = []
	
	for context in _available_contexts:
		if context.is_expired(current_time):
			expired_contexts.append(context)
	
	for context in expired_contexts:
		_available_contexts.erase(context)
		_total_allocated -= 1

func get_statistics() -> Dictionary:
	return {
		"total_allocated": _total_allocated,
		"total_reused": _total_reused,
		"active_contexts": _active_contexts.size(),
		"available_contexts": _available_contexts.size(),
		"pool_size": _pool_size,
		"peak_usage": _peak_usage,
		"resize_count": _resize_count,
		"reuse_ratio": float(_total_reused) / max(_total_allocated, 1)
	}

func clear_pool() -> void:
	_available_contexts.clear()
	_active_contexts.clear()
	_total_allocated = 0
	_total_reused = 0
	_peak_usage = 0
	_resize_count = 0

func get_active_contexts() -> Dictionary:
	return _active_contexts.duplicate()

func get_available_contexts() -> Array[JuicyContext]:
	return _available_contexts.duplicate()
```

**开发任务分解**：
- [ ] 第16周第1天：对象池基础实现（增加预热机制）
- [ ] 第16周第1天：Context分配和回收（增加预热状态管理）
- [ ] 第16周第2天：内存优化和统计（增加自适应分配策略）
- [ ] 第16周第2天：动态池大小调整（增加智能调整算法）
- [ ] 第16周第3天：性能测试和优化（增加预热性能测试）

## JuicyObjectPool (通用对象池)

**文件路径**：`addons/juicy_mixer/core/juicy_object_pool.gd`

**核心职责**：
- 提供通用对象池功能
- 支持多种对象类型
- 实现自动扩容和收缩
- 提供性能统计

**详细实现计划**：

```gdscript
class_name JuicyObjectPool
extends RefCounted

# 池管理
var _pool_items: Array[JuicyPoolItem] = []
var _object_script: Script
var _pool_size: int = 50
var _max_pool_size: int = 200
var _auto_resize: bool = true
var _resize_threshold: float = 0.8

# 统计信息
var _total_created: int = 0
var _total_reused: int = 0
var _peak_usage: int = 0

func _init(script: Script, initial_size: int = 50):
	_object_script = script
	_pool_size = initial_size
	_warm_up(initial_size)

func get_object() -> Object:
	# 查找可用的对象
	for item in _pool_items:
		if not item.in_use:
			item.in_use = true
			item.last_used = Time.get_ticks_msec() / 1000.0
			_total_reused += 1
			
			# 更新峰值使用量
			var current_usage = _get_current_usage()
			if current_usage > _peak_usage:
				_peak_usage = current_usage
			
			return item.object
	
	# 没有可用对象，创建新对象
	if _pool_items.size() < _max_pool_size:
		var object = _object_script.new()
		var item = JuicyPoolItem.new(object)
		item.mark_used()
		
		_pool_items.append(item)
		_total_created += 1
		
		return object
	
	return null

func return_object(obj: Object) -> void:
	if not obj:
		return
	
	# 查找对应的池项
	for item in _pool_items:
		if item.object == obj:
			item.mark_unused()
			break

func _warm_up(count: int) -> void:
	for i in range(count):
		var object = _object_script.new()
		var item = JuicyPoolItem.new(object)
		item.mark_unused()
		
		_pool_items.append(item)
		_total_created += 1

func _get_current_usage() -> int:
	var count = 0
	for item in _pool_items:
		if item.in_use:
			count += 1
	return count

func get_statistics() -> Dictionary:
	return {
		"total_created": _total_created,
		"total_reused": _total_reused,
		"pool_size": _pool_items.size(),
		"current_usage": _get_current_usage(),
		"peak_usage": _peak_usage,
		"reuse_ratio": float(_total_reused) / max(_total_created, 1)
	}

func clear_pool() -> void:
	_pool_items.clear()
	_total_created = 0
	_total_reused = 0
	_peak_usage = 0
```

**开发任务分解**：
- [ ] 第16周第1天：通用对象池基础实现
- [ ] 第16周第2天：对象分配和回收
- [ ] 第16周第2天：自动扩容和收缩
- [ ] 第16周第3天：单元测试

## 池化系统优化目标

### 优化目标
- 支持1000+并发效果实例
- 对象重用率达到90%以上
- 内存分配开销降低80%
- GC压力降低70%

### 优化策略
- [ ] 第16周第1天：智能预热机制
- [ ] 第16周第2天：自适应池大小调整
- [ ] 第16周第3天：过期对象清理
- [ ] 第16周第3天：性能基准测试

## 测试计划

### 单元测试
- JuicyPoolItem生命周期测试
- JuicyContextPool对象池测试
- JuicyObjectPool通用对象池测试

### 集成测试
- 与Director系统集成测试
- 与Middleware系统集成测试
- 与事件系统集成测试

### 性能测试
- 1000+并发效果实例池化性能测试
- 对象重用率验证
- 内存分配开销降低验证
- GC压力降低验证

## 交付检查清单

### 代码交付
- [ ] JuicyPoolItem对象池项
- [ ] JuicyContextPool上下文对象池
- [ ] JuicyObjectPool通用对象池
- [ ] 单元测试和集成测试
- [ ] 性能基准测试

### 文档交付
- [ ] 池化系统使用文档
- [ ] API参考文档
- [ ] 池化优化指南

### 验收标准
- [ ] 所有单元测试通过（覆盖率100%）
- [ ] 所有集成测试通过
- [ ] 性能基准测试达标
- [ ] 代码审查通过
- [ ] 文档完整准确

## 风险管控

### 技术风险
1. **池化复杂性**：复杂的池化逻辑可能导致内存泄漏
   - 缓解措施：实现全面的池监控和泄漏检测

2. **性能平衡**：池大小调整可能影响性能
   - 缓解措施：实现自适应调整算法和性能监控

### 进度风险
1. **优化工作量**：池化优化可能比预期耗时
   - 缓解措施：优先实现核心池化功能，后续迭代改进

## 总结

池化系统是JuicyMixer V3的关键基础设施，它提供了高效的对象池化解决方案。通过上下文对象池、通用对象池和智能池管理，系统能够高效处理大量并发效果实例而不产生过多的内存分配开销。

**关键成就**：
- 实现了高效的对象池化系统
- 提供了智能的池大小调整
- 确保了低内存分配开销
- 提供了详细的池化统计

池化系统将为JuicyMixer V3用户提供卓越的性能表现，使系统能够处理大规模的效果实例而不影响整体性能。