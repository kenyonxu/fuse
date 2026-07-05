# 性能优化示例

## 概述

本文档提供了JuicyMixer中断策略系统的性能优化示例，帮助开发者实现高效的中断处理，确保游戏在各种设备上都能流畅运行。

## 基础性能优化

### 对象池优化

```gdscript
class_name InterruptionObjectPool
extends Node

# 对象池配置
var pool_config: Dictionary = {
    "interruption_state": {"size": 50, "growth_factor": 1.5},
    "event_data": {"size": 100, "growth_factor": 2.0},
    "transition_context": {"size": 20, "growth_factor": 1.2}
}

var pools: Dictionary = {}

func _ready():
    _initialize_pools()

func _initialize_pools():
    """初始化对象池"""
    for pool_name in pool_config:
        var config = pool_config[pool_name]
        pools[pool_name] = _create_pool(config.size, config.growth_factor)
        print("初始化对象池: ", pool_name, " 大小: ", config.size)

func _create_pool(initial_size: int, growth_factor: float) -> Array:
    """创建对象池"""
    var pool = []
    for i in range(initial_size):
        pool.append(_create_pooled_object())
    return pool

func _create_pooled_object() -> Object:
    """创建池化对象"""
    # 根据需要创建不同类型的对象
    return RefCounted.new()

func get_pooled_object(pool_name: String) -> Object:
    """从池中获取对象"""
    if not pools.has(pool_name):
        pools[pool_name] = _create_pool(10, 1.5)
    
    var pool = pools[pool_name]
    if pool.size() > 0:
        return pool.pop_back()
    else:
        # 池为空时创建新对象
        print("池为空，创建新对象: ", pool_name)
        return _create_pooled_object()

func return_to_pool(pool_name: String, object: Object):
    """将对象返回到池"""
    if not pools.has(pool_name):
        return
    
    var pool = pools[pool_name]
    var max_size = pool_config[pool_name].size
    var growth_factor = pool_config[pool_name].growth_factor
    
    # 重置对象状态
    if object.has_method("reset"):
        object.reset()
    
    # 检查池大小限制
    if pool.size() < max_size * growth_factor:
        pool.append(object)
    else:
        # 池已满，丢弃对象
        print("池已满，丢弃对象: ", pool_name)

func get_pool_stats() -> Dictionary:
    """获取池统计信息"""
    var stats = {}
    for pool_name in pools:
        stats[pool_name] = {
            "size": pools[pool_name].size(),
            "max_size": pool_config[pool_name].size,
            "growth_factor": pool_config[pool_name].growth_factor
        }
    return stats
```

### 批处理优化

```gdscript
class_name InterruptionBatchProcessor
extends Node

var batch_size: int = 10
var batch_timeout: float = 0.016  # 60fps
var pending_interruptions: Array[Dictionary] = []
var processing_timer: Timer
var batch_processor: Callable

func _ready():
    _setup_batch_processor()

func _setup_batch_processor():
    """设置批处理器"""
    processing_timer = Timer.new()
    processing_timer.wait_time = batch_timeout
    processing_timer.timeout.connect(_process_batch)
    processing_timer.autostart = false
    add_child(processing_timer)

func set_batch_processor(processor: Callable):
    """设置批处理函数"""
    batch_processor = processor

func add_interruption(interruption_data: Dictionary):
    """添加中断到批处理队列"""
    pending_interruptions.append(interruption_data)
    
    # 检查是否需要立即处理
    if pending_interruptions.size() >= batch_size:
        _process_batch()
    elif not processing_timer.time_left > 0:
        processing_timer.start()

func _process_batch():
    """处理批处理"""
    if pending_interruptions.size() == 0:
        return
    
    var batch = pending_interruptions.duplicate()
    pending_interruptions.clear()
    processing_timer.stop()
    
    # 调用批处理函数
    if batch_processor.is_valid():
        batch_processor.call(batch)
    
    print("处理中断批处理，大小: ", batch.size())

func force_process():
    """强制处理所有待处理的中断"""
    if pending_interruptions.size() > 0:
        _process_batch()

func get_pending_count() -> int:
    """获取待处理中断数量"""
    return pending_interruptions.size()

func clear_pending():
    """清空待处理中断"""
    pending_interruptions.clear()
    processing_timer.stop()
```

## 高级性能优化

### 智能缓存系统

```gdscript
class_name InterruptionCache
extends Node

# 缓存配置
var cache_config: Dictionary = {
    "policy_cache": {"max_size": 100, "ttl": 5.0},
    "state_cache": {"max_size": 50, "ttl": 2.0},
    "priority_cache": {"max_size": 200, "ttl": 1.0}
}

var caches: Dictionary = {}
var cache_stats: Dictionary = {}

func _ready():
    _initialize_caches()

func _initialize_caches():
    """初始化缓存系统"""
    for cache_name in cache_config:
        var config = cache_config[cache_name]
        caches[cache_name] = {
            "data": {},
            "timestamps": {},
            "max_size": config.max_size,
            "ttl": config.ttl
        }
        cache_stats[cache_name] = {
            "hits": 0,
            "misses": 0,
            "evictions": 0
        }

func get_cached_value(cache_name: String, key: String) -> Variant:
    """获取缓存值"""
    if not caches.has(cache_name):
        return null
    
    var cache = caches[cache_name]
    var current_time = Time.get_ticks_msec() / 1000.0
    
    # 检查缓存是否存在
    if not cache.data.has(key):
        cache_stats[cache_name].misses += 1
        return null
    
    # 检查TTL
    var timestamp = cache.timestamps[key]
    if current_time - timestamp > cache.ttl:
        # 缓存过期，移除
        cache.data.erase(key)
        cache.timestamps.erase(key)
        cache_stats[cache_name].misses += 1
        return null
    
    cache_stats[cache_name].hits += 1
    return cache.data[key]

func set_cached_value(cache_name: String, key: String, value: Variant):
    """设置缓存值"""
    if not caches.has(cache_name):
        return
    
    var cache = caches[cache_name]
    var current_time = Time.get_ticks_msec() / 1000.0
    
    # 检查缓存大小
    if cache.data.size() >= cache.max_size:
        _evict_oldest_entry(cache_name)
    
    cache.data[key] = value
    cache.timestamps[key] = current_time

func _evict_oldest_entry(cache_name: String):
    """驱逐最旧的缓存条目"""
    if not caches.has(cache_name):
        return
    
    var cache = caches[cache_name]
    var oldest_key = ""
    var oldest_time = INF
    
    for key in cache.timestamps:
        var timestamp = cache.timestamps[key]
        if timestamp < oldest_time:
            oldest_time = timestamp
            oldest_key = key
    
    if oldest_key != "":
        cache.data.erase(oldest_key)
        cache.timestamps.erase(oldest_key)
        cache_stats[cache_name].evictions += 1

func clear_cache(cache_name: String):
    """清空指定缓存"""
    if caches.has(cache_name):
        caches[cache_name].data.clear()
        caches[cache_name].timestamps.clear()

func get_cache_stats() -> Dictionary:
    """获取缓存统计"""
    var stats = {}
    for cache_name in cache_stats:
        var cache_stat = cache_stats[cache_name]
        var total_requests = cache_stat.hits + cache_stat.misses
        var hit_rate = cache_stat.hits / float(total_requests) if total_requests > 0 else 0.0
        
        stats[cache_name] = {
            "hits": cache_stat.hits,
            "misses": cache_stat.misses,
            "hit_rate": hit_rate,
            "evictions": cache_stat.evictions,
            "size": caches[cache_name].data.size() if caches.has(cache_name) else 0
        }
    
    return stats
```

### 性能监控系统

```gdscript
class_name InterruptionPerformanceMonitor
extends Node

# 性能阈值
var performance_thresholds: Dictionary = {
    "max_interruption_time": 5.0,      # 最大中断时间（ms）
    "max_queue_size": 20,               # 最大队列大小
    "max_memory_usage": 100,             # 最大内存使用（MB）
    "min_fps": 30                        # 最小帧率
}

var performance_data: Dictionary = {}
var alert_callbacks: Array[Callable] = []

func _ready():
    _initialize_monitoring()

func _initialize_monitoring():
    """初始化性能监控"""
    performance_data = {
        "interruption_times": [],
        "queue_sizes": [],
        "memory_usage": [],
        "fps_samples": [],
        "last_update": Time.get_ticks_msec() / 1000.0
    }
    
    # 设置定时更新
    var update_timer = Timer.new()
    update_timer.wait_time = 1.0  # 每秒更新
    update_timer.timeout.connect(_update_performance_metrics)
    add_child(update_timer)
    update_timer.start()

func record_interruption_time(time_ms: float):
    """记录中断时间"""
    performance_data.interruption_times.append(time_ms)
    _check_performance_threshold("interruption_time", time_ms)

func record_queue_size(size: int):
    """记录队列大小"""
    performance_data.queue_sizes.append(size)
    _check_performance_threshold("queue_size", size)

func record_memory_usage():
    """记录内存使用"""
    var memory_usage = OS.get_static_memory_usage_by_type()[OS.MEMORY_TYPE_VIDEO] / 1024.0 / 1024.0  # MB
    performance_data.memory_usage.append(memory_usage)
    _check_performance_threshold("memory_usage", memory_usage)

func record_fps():
    """记录帧率"""
    var fps = Engine.get_frames_per_second()
    performance_data.fps_samples.append(fps)
    _check_performance_threshold("fps", fps)

func _check_performance_threshold(metric_type: String, value: float):
    """检查性能阈值"""
    var threshold = performance_thresholds.get(metric_type + "_s", INF)
    
    match metric_type:
        "interruption_time":
            threshold = performance_thresholds.max_interruption_time
            if value > threshold:
                _trigger_alert("interruption_time_exceeded", {
                    "value": value,
                    "threshold": threshold
                })
        
        "queue_size":
            threshold = performance_thresholds.max_queue_size
            if value > threshold:
                _trigger_alert("queue_size_exceeded", {
                    "value": value,
                    "threshold": threshold
                })
        
        "memory_usage":
            threshold = performance_thresholds.max_memory_usage
            if value > threshold:
                _trigger_alert("memory_usage_exceeded", {
                    "value": value,
                    "threshold": threshold
                })
        
        "fps":
            threshold = performance_thresholds.min_fps
            if value < threshold:
                _trigger_alert("fps_below_threshold", {
                    "value": value,
                    "threshold": threshold
                })

func _trigger_alert(alert_type: String, alert_data: Dictionary):
    """触发性能警报"""
    print("性能警报: ", alert_type, " 数据: ", alert_data)
    
    for callback in alert_callbacks:
        callback.call(alert_type, alert_data)

func add_alert_callback(callback: Callable):
    """添加警报回调"""
    alert_callbacks.append(callback)

func _update_performance_metrics():
    """更新性能指标"""
    record_memory_usage()
    record_fps()
    
    # 清理旧数据（保留最近100个样本）
    var max_samples = 100
    
    if performance_data.interruption_times.size() > max_samples:
        performance_data.interruption_times = performance_data.interruption_times.slice(-max_samples)
    
    if performance_data.queue_sizes.size() > max_samples:
        performance_data.queue_sizes = performance_data.queue_sizes.slice(-max_samples)
    
    if performance_data.memory_usage.size() > max_samples:
        performance_data.memory_usage = performance_data.memory_usage.slice(-max_samples)
    
    if performance_data.fps_samples.size() > max_samples:
        performance_data.fps_samples = performance_data.fps_samples.slice(-max_samples)

func get_performance_summary() -> Dictionary:
    """获取性能摘要"""
    var summary = {}
    
    # 计算平均值
    if performance_data.interruption_times.size() > 0:
        var total_time = 0.0
        for time in performance_data.interruption_times:
            total_time += time
        summary.average_interruption_time = total_time / performance_data.interruption_times.size()
    
    if performance_data.queue_sizes.size() > 0:
        var total_size = 0
        for size in performance_data.queue_sizes:
            total_size += size
        summary.average_queue_size = total_size / performance_data.queue_sizes.size()
    
    if performance_data.memory_usage.size() > 0:
        var total_memory = 0.0
        for memory in performance_data.memory_usage:
            total_memory += memory
        summary.average_memory_usage = total_memory / performance_data.memory_usage.size()
    
    if performance_data.fps_samples.size() > 0:
        var total_fps = 0.0
        for fps in performance_data.fps_samples:
            total_fps += fps
        summary.average_fps = total_fps / performance_data.fps_samples.size()
    
    return summary
```

## 自适应性能优化

### 动态质量调整

```gdscript
class_name AdaptiveQualityManager
extends Node

enum QualityLevel {
    LOW,        # 低质量
    MEDIUM,     # 中等质量
    HIGH,       # 高质量
    ULTRA       # 超高质量
}

var current_quality: QualityLevel = QualityLevel.HIGH
var quality_thresholds: Dictionary = {}
var adjustment_callbacks: Array[Callable] = []

func _ready():
    _setup_quality_thresholds()

func _setup_quality_thresholds():
    """设置质量阈值"""
    quality_thresholds = {
        "fps": {
            QualityLevel.ULTRA: {"min": 60, "max": INF},
            QualityLevel.HIGH: {"min": 45, "max": 60},
            QualityLevel.MEDIUM: {"min": 30, "max": 45},
            QualityLevel.LOW: {"min": 0, "max": 30}
        },
        "interruption_time": {
            QualityLevel.ULTRA: {"min": 0, "max": 2.0},
            QualityLevel.HIGH: {"min": 0, "max": 3.0},
            QualityLevel.MEDIUM: {"min": 0, "max": 5.0},
            QualityLevel.LOW: {"min": 0, "max": 10.0}
        },
        "memory_usage": {
            QualityLevel.ULTRA: {"min": 0, "max": 512},
            QualityLevel.HIGH: {"min": 0, "max": 768},
            QualityLevel.MEDIUM: {"min": 0, "max": 1024},
            QualityLevel.LOW: {"min": 0, "max": 1536}
        }
    }

func evaluate_performance(metrics: Dictionary) -> QualityLevel:
    """评估性能并返回推荐质量级别"""
    var fps = metrics.get("fps", 60)
    var interruption_time = metrics.get("interruption_time", 1.0)
    var memory_usage = metrics.get("memory_usage", 500)
    
    var quality_scores = {}
    
    # 计算每个质量级别的得分
    for quality in QualityLevel.values():
        var score = 0
        
        # FPS得分
        var fps_threshold = quality_thresholds.fps[quality]
        if fps >= fps_threshold.min and fps <= fps_threshold.max:
            score += 1
        else:
            var fps_diff = min(abs(fps - fps_threshold.min), abs(fps - fps_threshold.max))
            score -= fps_diff / 10.0
        
        # 中断时间得分
        var time_threshold = quality_thresholds.interruption_time[quality]
        if interruption_time >= time_threshold.min and interruption_time <= time_threshold.max:
            score += 1
        else:
            var time_diff = min(abs(interruption_time - time_threshold.min), abs(interruption_time - time_threshold.max))
            score -= time_diff / 2.0
        
        # 内存使用得分
        var memory_threshold = quality_thresholds.memory_usage[quality]
        if memory_usage >= memory_threshold.min and memory_usage <= memory_threshold.max:
            score += 1
        else:
            var memory_diff = min(abs(memory_usage - memory_threshold.min), abs(memory_usage - memory_threshold.max))
            score -= memory_diff / 100.0
        
        quality_scores[quality] = score
    
    # 找到得分最高的质量级别
    var best_quality = current_quality
    var best_score = quality_scores[current_quality]
    
    for quality in quality_scores:
        if quality_scores[quality] > best_score:
            best_score = quality_scores[quality]
            best_quality = quality
    
    return best_quality

func adjust_quality(new_quality: QualityLevel):
    """调整质量级别"""
    if new_quality == current_quality:
        return
    
    var old_quality = current_quality
    current_quality = new_quality
    
    print("质量级别调整: ", old_quality, " -> ", new_quality)
    
    # 应用质量设置
    _apply_quality_settings(new_quality)
    
    # 通知回调
    for callback in adjustment_callbacks:
        callback.call(old_quality, new_quality)

func _apply_quality_settings(quality: QualityLevel):
    """应用质量设置"""
    match quality:
        QualityLevel.ULTRA:
            _apply_ultra_settings()
        QualityLevel.HIGH:
            _apply_high_settings()
        QualityLevel.MEDIUM:
            _apply_medium_settings()
        QualityLevel.LOW:
            _apply_low_settings()

func _apply_ultra_settings():
    """应用超高质量设置"""
    # 最大队列大小，最短过渡时间
    JuicyMixer.set_global_interruption_policy(JuicyMixerEnms.InterruptionPolicy.SMOOTH_TRANSITION)
    _set_all_channel_max_queue_size(50)
    _set_all_transition_duration(0.1)

func _apply_high_settings():
    """应用高质量设置"""
    JuicyMixer.set_global_interruption_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
    _set_all_channel_max_queue_size(30)
    _set_all_transition_duration(0.2)

func _apply_medium_settings():
    """应用中等质量设置"""
    JuicyMixer.set_global_interruption_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_STACK)
    _set_all_channel_max_queue_size(20)
    _set_all_transition_duration(0.3)

func _apply_low_settings():
    """应用低质量设置"""
    JuicyMixer.set_global_interruption_policy(JuicyMixerEnms.InterruptionPolicy.STACK)
    _set_all_channel_max_queue_size(10)
    _set_all_transition_duration(0.5)

func _set_all_channel_max_queue_size(size: int):
    """设置所有通道的最大队列大小"""
    var channels = ["ui_effects", "combat_effects", "audio_effects", "ambient_effects"]
    for channel in channels:
        var config = JuicyMixer.get_channel_interruption_config(channel)
        if config:
            config.set_max_queue_size(size)
            JuicyMixer.set_channel_interruption_config(channel, config)

func _set_all_transition_duration(duration: float):
    """设置所有通道的过渡时间"""
    var channels = ["ui_effects", "combat_effects", "audio_effects", "ambient_effects"]
    for channel in channels:
        var config = JuicyMixer.get_channel_interruption_config(channel)
        if config:
            config.set_transition_duration(duration)
            JuicyMixer.set_channel_interruption_config(channel, config)

func add_quality_adjustment_callback(callback: Callable):
    """添加质量调整回调"""
    adjustment_callbacks.append(callback)
```

## 实际应用场景

### 移动设备优化

```gdscript
class_name MobileInterruptionOptimizer
extends Node

var is_mobile: bool = false
var optimization_profile: String = "balanced"  # "performance", "balanced", "quality"

func _ready():
    _detect_platform()
    _apply_mobile_optimizations()

func _detect_platform():
    """检测平台"""
    var os_name = OS.get_name()
    is_mobile = os_name in ["Android", "iOS"]
    print("检测到移动平台: ", is_mobile)

func _apply_mobile_optimizations():
    """应用移动设备优化"""
    if not is_mobile:
        return
    
    match optimization_profile:
        "performance":
            _apply_performance_profile()
        "balanced":
            _apply_balanced_profile()
        "quality":
            _apply_quality_profile()

func _apply_performance_profile():
    """应用性能配置文件"""
    print("应用移动设备性能配置")
    
    # 减少队列大小
    _set_channel_queue_size("ui_effects", 5)
    _set_channel_queue_size("combat_effects", 8)
    _set_channel_queue_size("audio_effects", 3)
    
    # 使用快速中断策略
    JuicyMixer.set_global_interruption_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
    
    # 禁用高级功能
    _disable_advanced_features()

func _apply_balanced_profile():
    """应用平衡配置文件"""
    print("应用移动设备平衡配置")
    
    # 中等队列大小
    _set_channel_queue_size("ui_effects", 8)
    _set_channel_queue_size("combat_effects", 12)
    _set_channel_queue_size("audio_effects", 5)
    
    # 使用平衡的中断策略
    JuicyMixer.set_global_interruption_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_STACK)
    
    # 启用部分高级功能
    _enable_partial_advanced_features()

func _apply_quality_profile():
    """应用质量配置文件"""
    print("应用移动设备质量配置")
    
    # 较大队列大小
    _set_channel_queue_size("ui_effects", 10)
    _set_channel_queue_size("combat_effects", 15)
    _set_channel_queue_size("audio_effects", 8)
    
    # 使用平滑过渡策略
    JuicyMixer.set_global_interruption_policy(JuicyMixerEnms.InterruptionPolicy.SMOOTH_TRANSITION)
    
    # 启用所有高级功能
    _enable_all_advanced_features()

func _set_channel_queue_size(channel: String, size: int):
    """设置通道队列大小"""
    var config = JuicyMixer.get_channel_interruption_config(channel)
    if config:
        config.set_max_queue_size(size)
        JuicyMixer.set_channel_interruption_config(channel, config)

func _disable_advanced_features():
    """禁用高级功能"""
    var channels = ["ui_effects", "combat_effects", "audio_effects"]
    for channel in channels:
        var config = JuicyMixer.get_channel_interruption_config(channel)
        if config:
            config.enable_feature("priority_queue", false)
            config.enable_feature("interruption_history", false)
            config.enable_feature("auto_cleanup", false)
            JuicyMixer.set_channel_interruption_config(channel, config)

func _enable_partial_advanced_features():
    """启用部分高级功能"""
    var channels = ["ui_effects", "combat_effects"]
    for channel in channels:
        var config = JuicyMixer.get_channel_interruption_config(channel)
        if config:
            config.enable_feature("priority_queue", true)
            config.enable_feature("interruption_history", false)
            config.enable_feature("auto_cleanup", true)
            JuicyMixer.set_channel_interruption_config(channel, config)

func _enable_all_advanced_features():
    """启用所有高级功能"""
    var channels = ["ui_effects", "combat_effects", "audio_effects"]
    for channel in channels:
        var config = JuicyMixer.get_channel_interruption_config(channel)
        if config:
            config.enable_feature("priority_queue", true)
            config.enable_feature("interruption_history", true)
            config.enable_feature("auto_cleanup", true)
            JuicyMixer.set_channel_interruption_config(channel, config)
```

### 大规模战斗优化

```gdscript
class_name MassCombatInterruptionOptimizer
extends Node

var max_concurrent_effects: int = 50
var effect_groups: Dictionary = {}
var group_priorities: Dictionary = {}

func _ready():
    _setup_combat_optimizations()

func _setup_combat_optimizations():
    """设置大规模战斗优化"""
    # 创建效果组
    effect_groups = {
        "player": {"max_effects": 5, "priority": 100},
        "enemies": {"max_effects": 20, "priority": 50},
        "environment": {"max_effects": 10, "priority": 20},
        "ui": {"max_effects": 8, "priority": 80}
    }
    
    # 设置组优先级
    for group in effect_groups:
        group_priorities[group] = effect_groups[group].priority
    
    print("大规模战斗优化已设置")

func optimize_for_mass_combat():
    """为大规模战斗优化"""
    print("优化大规模战斗中断系统")
    
    # 降低过渡时间
    _set_all_transition_duration(0.1)
    
    # 使用快速中断策略
    JuicyMixer.set_global_interruption_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
    
    # 启用自动清理
    _enable_aggressive_cleanup()

func _set_all_transition_duration(duration: float):
    """设置所有通道的过渡时间"""
    var channels = ["player_effects", "enemy_effects", "environment_effects", "ui_effects"]
    for channel in channels:
        var config = JuicyMixer.get_channel_interruption_config(channel)
        if config:
            config.set_transition_duration(duration)
            JuicyMixer.set_channel_interruption_config(channel, config)

func _enable_aggressive_cleanup():
    """启用激进的清理策略"""
    var channels = ["player_effects", "enemy_effects", "environment_effects", "ui_effects"]
    for channel in channels:
        var config = JuicyMixer.get_channel_interruption_config(channel)
        if config:
            config.enable_feature("auto_cleanup", true)
            config.auto_cleanup_threshold = 5  # 低阈值
            JuicyMixer.set_channel_interruption_config(channel, config)

func check_group_limits(group_name: String) -> bool:
    """检查组限制"""
    if not effect_groups.has(group_name):
        return true
    
    var group = effect_groups[group_name]
    var current_count = _get_group_effect_count(group_name)
    
    return current_count < group.max_effects

func _get_group_effect_count(group_name: String) -> int:
    """获取组效果数量"""
    # 这里应该有实际的计数逻辑
    # 简化实现
    return randi() % 20
```

## 性能测试和基准测试

### 性能基准测试

```gdscript
class_name InterruptionBenchmark
extends Node

var benchmark_results: Dictionary = {}
var test_scenarios: Array[Dictionary] = []

func _ready():
    _setup_benchmark_scenarios()

func _setup_benchmark_scenarios():
    """设置基准测试场景"""
    test_scenarios = [
        {
            "name": "low_frequency_interruptions",
            "description": "低频中断测试",
            "interruption_rate": 1,  # 每秒1次
            "duration": 10.0
        },
        {
            "name": "medium_frequency_interruptions",
            "description": "中频中断测试",
            "interruption_rate": 5,  # 每秒5次
            "duration": 10.0
        },
        {
            "name": "high_frequency_interruptions",
            "description": "高频中断测试",
            "interruption_rate": 20, # 每秒20次
            "duration": 10.0
        },
        {
            "name": "burst_interruptions",
            "description": "突发中断测试",
            "interruption_rate": 50, # 突发50次
            "duration": 1.0
        }
    ]

func run_benchmark(scenario_name: String) -> Dictionary:
    """运行基准测试"""
    var scenario = null
    for s in test_scenarios:
        if s.name == scenario_name:
            scenario = s
            break
    
    if not scenario:
        print("未找到测试场景: ", scenario_name)
        return {}
    
    print("开始基准测试: ", scenario.description)
    
    var start_time = Time.get_ticks_msec()
    var start_fps = Engine.get_frames_per_second()
    var start_memory = OS.get_static_memory_usage_by_type()[OS.MEMORY_TYPE_VIDEO]
    
    # 执行测试场景
    _execute_scenario(scenario)
    
    var end_time = Time.get_ticks_msec()
    var end_fps = Engine.get_frames_per_second()
    var end_memory = OS.get_static_memory_usage_by_type()[OS.MEMORY_TYPE_VIDEO]
    
    var results = {
        "scenario": scenario_name,
        "duration_ms": end_time - start_time,
        "fps_drop": start_fps - end_fps,
        "memory_increase": end_memory - start_memory,
        "interruption_count": scenario.interruption_rate * scenario.duration,
        "performance_score": _calculate_performance_score(start_fps, end_fps, start_memory, end_memory)
    }
    
    benchmark_results[scenario_name] = results
    print("基准测试完成: ", scenario_name, " 性能得分: ", results.performance_score)
    
    return results

func _execute_scenario(scenario: Dictionary):
    """执行测试场景"""
    var interruption_count = 0
    var target_rate = scenario.interruption_rate
    var duration = scenario.duration
    
    # 创建测试效果
    var test_effect = JuicyFeedbackResource.new()
    test_effect.duration = 0.1
    test_effect.channel = "benchmark_effects"
    
    var start_time = Time.get_ticks_msec() / 1000.0
    
    while Time.get_ticks_msec() / 1000.0 - start_time < duration:
        var target_time = interruption_count / target_rate
        
        if Time.get_ticks_msec() / 1000.0 - start_time >= target_time:
            # 执行中断
            JuicyMixer.play(test_effect, get_tree().current_scene)
            interruption_count += 1
        
        await Engine.get_main_loop().process_frame

func _calculate_performance_score(start_fps: float, end_fps: float, start_memory: int, end_memory: int) -> float:
    """计算性能得分"""
    var fps_score = max(0, 100 - (start_fps - end_fps))
    var memory_score = max(0, 100 - (end_memory - start_memory) / 1024.0 / 1024.0)  # MB
    
    return (fps_score + memory_score) / 2.0

func get_benchmark_summary() -> Dictionary:
    """获取基准测试摘要"""
    var summary = {
        "total_scenarios": test_scenarios.size(),
        "completed_scenarios": benchmark_results.size(),
        "average_performance_score": 0.0,
        "best_scenario": "",
        "worst_scenario": ""
    }
    
    if benchmark_results.size() > 0:
        var total_score = 0.0
        var best_score = -INF
        var worst_score = INF
        
        for scenario_name in benchmark_results:
            var results = benchmark_results[scenario_name]
            total_score += results.performance_score
            
            if results.performance_score > best_score:
                best_score = results.performance_score
                summary.best_scenario = scenario_name
            
            if results.performance_score < worst_score:
                worst_score = results.performance_score
                summary.worst_scenario = scenario_name
        
        summary.average_performance_score = total_score / benchmark_results.size()
    
    return summary
```

## 最佳实践

1. **对象池化**: 对频繁创建和销毁的对象使用对象池
2. **批处理**: 将多个操作合并为批处理减少开销
3. **智能缓存**: 缓存频繁访问的数据，设置合理的TTL
4. **性能监控**: 实时监控系统性能，及时发现问题
5. **自适应调整**: 根据设备性能动态调整质量设置

## 常见问题

### Q: 如何减少中断处理的CPU开销？
A: 使用批处理、对象池化和智能缓存。

### Q: 如何优化内存使用？
A: 限制队列大小、启用自动清理、使用对象池。

### Q: 如何在不同设备上保持一致的性能？
A: 实现自适应质量管理和性能监控。

### Q: 如何测试中断系统性能？
A: 使用基准测试工具和性能监控系统。

## 相关文档

- [基础中断策略使用示例](basic_interruption_examples.md)
- [高级中断配置示例](advanced_interruption_examples.md)
- [自定义中断策略示例](custom_interruption_examples.md)
- [中断事件处理示例](interruption_event_examples.md)
- [API文档](../api/)