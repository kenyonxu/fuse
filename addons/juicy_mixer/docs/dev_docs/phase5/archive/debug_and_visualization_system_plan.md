# 调试与可视化系统开发计划

## 概述

本文档详细描述了JuicyMixer V3中调试与可视化系统的开发计划。该系统提供了强大的运行时调试和可视化功能，包括状态监控、性能分析、缓冲区可视化、调试信息导出等，帮助开发者深入了解系统的运行状态和性能表现。

## 系统架构

调试与可视化系统由以下核心组件构成：

- **JuicyDebugger** - 核心调试器
- **JuicyPerformanceMonitor** - 性能监控器
- **JuicyVisualizer** - 可视化渲染器
- **JuicyDebugPanel** - 调试面板UI

## 与现有系统的集成

### 所有系统的深度集成
- 调试系统需要监控所有组件的状态
- 调试信息需要覆盖完整的执行流程
- 调试控制需要能够干预所有系统

### 事件系统协调
- 调试信息需要通过事件系统收集
- 调试控制需要能够触发事件
- 调试状态需要响应事件变化

### 性能监控协同
- 调试系统需要集成性能监控
- 调试信息需要包含性能指标
- 调试控制需要能够优化性能

## 开发时间线

**总体时间**：第15周（与编辑器预览功能并行开发，共1周）

## JuicyDebugger (核心调试器)

**文件路径**：`addons/juicy_mixer/debug/juicy_debugger.gd`

**核心职责**：
- 提供运行时状态可视化
- 显示性能监控信息
- 实现缓冲区状态可视化
- 支持调试信息导出

**详细实现计划**：

```gdscript
class_name JuicyDebugger
extends RefCounted

# 调试器配置
var debug_enabled: bool = false
var visualization_enabled: bool = true
var performance_overlay: bool = false
var buffer_visualization: bool = false
var context_tracking: bool = true

# 调试数据收集
var _context_snapshots: Dictionary = {}
var _performance_samples: Array[PerformanceSample] = []
var _active_drivers: Dictionary = {}
var _debug_events: Array[Dictionary] = []
var _buffer_states: Dictionary = {}

# 调试配置
var _max_context_snapshots: int = 100
var _max_performance_samples: int = 1000
var _max_debug_events: int = 500
var _update_interval: float = 0.1  # 秒
var _last_update_time: float = 0.0

# 性能采样
class PerformanceSample:
    var timestamp: float
    var frame_time: float
    var active_contexts: int
    var memory_usage: int
    var cpu_usage: float

# 上下文快照
class ContextSnapshot:
    var context_id: String
    var resource_type: String
    var target_path: String
    var current_progress: float
    var time_scale: float
    var state: String
    var properties: Dictionary
    var timestamp: float

# 缓冲区状态
class BufferState:
    var context_id: String
    var buffer_type: String
    var size: int
    var capacity: int
    var utilization: float
    var properties: Dictionary
    var timestamp: float

func enable_debug() -> void:
    debug_enabled = true
    _connect_debug_signals()

func disable_debug() -> void:
    debug_enabled = false
    _disconnect_debug_signals()

func _connect_debug_signals() -> void:
    # 连接系统事件信号
    if JuicyEventBus:
        JuicyEventBus.context_started.connect(_on_context_started)
        JuicyEventBus.context_completed.connect(_on_context_completed)
        JuicyEventBus.context_paused.connect(_on_context_paused)
        JuicyEventBus.context_resumed.connect(_on_context_resumed)
        JuicyEventBus.driver_executed.connect(_on_driver_executed)
        JuicyEventBus.interruption_occurred.connect(_on_interruption_occurred)

func _disconnect_debug_signals() -> void:
    # 断开系统事件信号
    if JuicyEventBus:
        JuicyEventBus.context_started.disconnect(_on_context_started)
        JuicyEventBus.context_completed.disconnect(_on_context_completed)
        JuicyEventBus.context_paused.disconnect(_on_context_paused)
        JuicyEventBus.context_resumed.disconnect(_on_context_resumed)
        JuicyEventBus.driver_executed.disconnect(_on_driver_executed)
        JuicyEventBus.interruption_occurred.disconnect(_on_interruption_occurred)

func capture_context_snapshot(context: JuicyContext) -> void:
    if not context_tracking or not debug_enabled:
        return
    
    var snapshot = ContextSnapshot.new()
    snapshot.context_id = context.context_id
    snapshot.resource_type = context.resource.get_class()
    snapshot.target_path = context.target.get_path()
    snapshot.current_progress = context.progress
    snapshot.time_scale = context.time_scale
    snapshot.state = _get_context_state_string(context)
    snapshot.properties = _extract_context_properties(context)
    snapshot.timestamp = Time.get_ticks_msec() / 1000.0
    
    _context_snapshots[context.context_id] = snapshot
    
    # 限制快照数量
    if _context_snapshots.size() > _max_context_snapshots:
        _remove_oldest_snapshot()

func capture_performance_sample() -> void:
    if not performance_overlay or not debug_enabled:
        return
    
    var sample = PerformanceSample.new()
    sample.timestamp = Time.get_ticks_msec() / 1000.0
    sample.frame_time = Engine.get_frames_drawn() / Engine.get_frames_per_second()
    sample.active_contexts = JuicyMixer.get_active_context_count()
    sample.memory_usage = OS.get_static_memory_usage_by_type()[OS.MEMORY_TYPE_STATIC]
    sample.cpu_usage = OS.get_processor_usage()
    
    _performance_samples.append(sample)
    
    # 限制采样数量
    if _performance_samples.size() > _max_performance_samples:
        _performance_samples.pop_front()

func capture_buffer_state(context: JuicyContext, buffer: JuicyPropertyBuffer) -> void:
    if not buffer_visualization or not debug_enabled:
        return
    
    var buffer_state = BufferState.new()
    buffer_state.context_id = context.context_id
    buffer_state.buffer_type = buffer.get_class()
    buffer_state.size = buffer.get_size()
    buffer_state.capacity = buffer.get_capacity()
    buffer_state.utilization = float(buffer_state.size) / float(buffer_state.capacity)
    buffer_state.properties = _extract_buffer_properties(buffer)
    buffer_state.timestamp = Time.get_ticks_msec() / 1000.0
    
    _buffer_states[context.context_id] = buffer_state

func _get_context_state_string(context: JuicyContext) -> String:
    if context.is_completed:
        return "completed"
    elif context.is_paused:
        return "paused"
    else:
        return "active"

func _extract_context_properties(context: JuicyContext) -> Dictionary:
    var properties = {}
    
    properties["duration"] = context.duration
    properties["loop"] = context.loop
    properties["priority"] = context.priority
    properties["channel"] = context.resource.channel
    
    return properties

func _extract_buffer_properties(buffer: JuicyPropertyBuffer) -> Dictionary:
    var properties = {}
    
    properties["property_count"] = buffer.get_property_count()
    properties["dirty_count"] = buffer.get_dirty_count()
    properties["last_update"] = buffer.get_last_update_time()
    
    return properties

func _remove_oldest_snapshot() -> void:
    var oldest_time = INF
    var oldest_id = ""
    
    for context_id in _context_snapshots:
        var snapshot = _context_snapshots[context_id]
        if snapshot.timestamp < oldest_time:
            oldest_time = snapshot.timestamp
            oldest_id = context_id
    
    if not oldest_id.is_empty():
        _context_snapshots.erase(oldest_id)

func _on_context_started(context: JuicyContext) -> void:
    _record_debug_event("context_started", {
        "context_id": context.context_id,
        "resource_type": context.resource.get_class(),
        "target_path": context.target.get_path()
    })
    
    capture_context_snapshot(context)

func _on_context_completed(context: JuicyContext) -> void:
    _record_debug_event("context_completed", {
        "context_id": context.context_id,
        "duration": context.duration
    })
    
    capture_context_snapshot(context)

func _on_context_paused(context: JuicyContext) -> void:
    _record_debug_event("context_paused", {
        "context_id": context.context_id
    })
    
    capture_context_snapshot(context)

func _on_context_resumed(context: JuicyContext) -> void:
    _record_debug_event("context_resumed", {
        "context_id": context.context_id
    })
    
    capture_context_snapshot(context)

func _on_driver_executed(driver: JuicyDriver, context: JuicyContext) -> void:
    _record_debug_event("driver_executed", {
        "driver_name": driver.driver_name,
        "context_id": context.context_id,
        "execution_time": driver.get_last_execution_time()
    })
    
    _active_drivers[context.context_id] = driver

func _on_interruption_occurred(event_data: Dictionary) -> void:
    _record_debug_event("interruption_occurred", event_data)

func _record_debug_event(event_type: String, data: Dictionary) -> void:
    if not debug_enabled:
        return
    
    var event = {
        "timestamp": Time.get_ticks_msec() / 1000.0,
        "type": event_type,
        "data": data
    }
    
    _debug_events.append(event)
    
    # 限制事件数量
    if _debug_events.size() > _max_debug_events:
        _debug_events.pop_front()

func process_debug(delta: float) -> void:
    if not debug_enabled:
        return
    
    _last_update_time += delta
    
    if _last_update_time >= _update_interval:
        capture_performance_sample()
        _last_update_time = 0.0

func get_context_snapshot(context_id: String) -> ContextSnapshot:
    return _context_snapshots.get(context_id, null)

func get_all_context_snapshots() -> Dictionary:
    return _context_snapshots.duplicate()

func get_performance_samples(count: int = -1) -> Array[PerformanceSample]:
    if count <= 0 or count >= _performance_samples.size():
        return _performance_samples.duplicate()
    
    var start_index = _performance_samples.size() - count
    return _performance_samples.slice(start_index)

func get_debug_events(count: int = -1) -> Array[Dictionary]:
    if count <= 0 or count >= _debug_events.size():
        return _debug_events.duplicate()
    
    var start_index = _debug_events.size() - count
    return _debug_events.slice(start_index)

func get_buffer_state(context_id: String) -> BufferState:
    return _buffer_states.get(context_id, null)

func get_all_buffer_states() -> Dictionary:
    return _buffer_states.duplicate()

func export_debug_data() -> Dictionary:
    return {
        "timestamp": Time.get_ticks_msec() / 1000.0,
        "context_snapshots": _serialize_context_snapshots(),
        "performance_samples": _serialize_performance_samples(),
        "debug_events": _debug_events.duplicate(),
        "buffer_states": _serialize_buffer_states(),
        "statistics": get_statistics()
    }

func _serialize_context_snapshots() -> Array:
    var serialized = []
    
    for snapshot in _context_snapshots.values():
        serialized.append({
            "context_id": snapshot.context_id,
            "resource_type": snapshot.resource_type,
            "target_path": snapshot.target_path,
            "current_progress": snapshot.current_progress,
            "time_scale": snapshot.time_scale,
            "state": snapshot.state,
            "properties": snapshot.properties,
            "timestamp": snapshot.timestamp
        })
    
    return serialized

func _serialize_performance_samples() -> Array:
    var serialized = []
    
    for sample in _performance_samples:
        serialized.append({
            "timestamp": sample.timestamp,
            "frame_time": sample.frame_time,
            "active_contexts": sample.active_contexts,
            "memory_usage": sample.memory_usage,
            "cpu_usage": sample.cpu_usage
        })
    
    return serialized

func _serialize_buffer_states() -> Array:
    var serialized = []
    
    for buffer_state in _buffer_states.values():
        serialized.append({
            "context_id": buffer_state.context_id,
            "buffer_type": buffer_state.buffer_type,
            "size": buffer_state.size,
            "capacity": buffer_state.capacity,
            "utilization": buffer_state.utilization,
            "properties": buffer_state.properties,
            "timestamp": buffer_state.timestamp
        })
    
    return serialized

func get_statistics() -> Dictionary:
    return {
        "total_contexts": _context_snapshots.size(),
        "active_contexts": _get_active_context_count(),
        "total_performance_samples": _performance_samples.size(),
        "total_debug_events": _debug_events.size(),
        "total_buffer_states": _buffer_states.size(),
        "average_frame_time": _calculate_average_frame_time(),
        "memory_usage": _get_current_memory_usage()
    }

func _get_active_context_count() -> int:
    var count = 0
    
    for snapshot in _context_snapshots.values():
        if snapshot.state == "active":
            count += 1
    
    return count

func _calculate_average_frame_time() -> float:
    if _performance_samples.is_empty():
        return 0.0
    
    var total_time = 0.0
    
    for sample in _performance_samples:
        total_time += sample.frame_time
    
    return total_time / _performance_samples.size()

func _get_current_memory_usage() -> int:
    return OS.get_static_memory_usage_by_type()[OS.MEMORY_TYPE_STATIC]

func clear_debug_data() -> void:
    _context_snapshots.clear()
    _performance_samples.clear()
    _debug_events.clear()
    _buffer_states.clear()
    _active_drivers.clear()

func set_update_interval(interval: float) -> void:
    _update_interval = max(interval, 0.01)

func get_update_interval() -> float:
    return _update_interval
```

**开发任务分解**：
- [ ] 第15周第1天：调试数据收集
- [ ] 第15周第2天：性能可视化
- [ ] 第15周第3天：缓冲区状态可视化
- [ ] 第15周第4天：调试UI设计
- [ ] 第15周第5天：调试工具集成

## JuicyPerformanceMonitor (性能监控器)

**文件路径**：`addons/juicy_mixer/debug/juicy_performance_monitor.gd`

**核心职责**：
- 监控系统性能指标
- 提供性能分析工具
- 生成性能报告

**详细实现计划**：

```gdscript
class_name JuicyPerformanceMonitor
extends RefCounted

# 性能指标
class PerformanceMetrics:
    var frame_time: float = 0.0
    var fps: float = 0.0
    var draw_calls: int = 0
    var memory_usage: int = 0
    var cpu_usage: float = 0.0
    var active_contexts: int = 0
    var driver_executions: int = 0

# 性能历史
var _performance_history: Array[PerformanceMetrics] = []
var _max_history_size: int = 1000
var _current_metrics: PerformanceMetrics

# 性能阈值
var _performance_thresholds: Dictionary = {
    "frame_time": 16.67,  # 60 FPS
    "fps": 30.0,
    "memory_usage": 512 * 1024 * 1024,  # 512MB
    "cpu_usage": 80.0
}

# 性能警告
var _performance_warnings: Array[Dictionary] = []

func _init():
    _current_metrics = PerformanceMetrics.new()

func update_metrics() -> void:
    _current_metrics.frame_time = Engine.get_frames_drawn() / Engine.get_frames_per_second()
    _current_metrics.fps = Engine.get_frames_per_second()
    _current_metrics.draw_calls = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
    _current_metrics.memory_usage = OS.get_static_memory_usage_by_type()[OS.MEMORY_TYPE_STATIC]
    _current_metrics.cpu_usage = OS.get_processor_usage()
    _current_metrics.active_contexts = JuicyMixer.get_active_context_count()
    
    # 添加到历史记录
    var metrics_copy = PerformanceMetrics.new()
    metrics_copy.frame_time = _current_metrics.frame_time
    metrics_copy.fps = _current_metrics.fps
    metrics_copy.draw_calls = _current_metrics.draw_calls
    metrics_copy.memory_usage = _current_metrics.memory_usage
    metrics_copy.cpu_usage = _current_metrics.cpu_usage
    metrics_copy.active_contexts = _current_metrics.active_contexts
    metrics_copy.driver_executions = _current_metrics.driver_executions
    
    _performance_history.append(metrics_copy)
    
    # 限制历史记录大小
    if _performance_history.size() > _max_history_size:
        _performance_history.pop_front()
    
    # 检查性能警告
    _check_performance_warnings()

func _check_performance_warnings() -> void:
    var current_time = Time.get_ticks_msec() / 1000.0
    
    # 检查帧时间
    if _current_metrics.frame_time > _performance_thresholds.frame_time:
        _add_performance_warning("frame_time", _current_metrics.frame_time, current_time)
    
    # 检查FPS
    if _current_metrics.fps < _performance_thresholds.fps:
        _add_performance_warning("fps", _current_metrics.fps, current_time)
    
    # 检查内存使用
    if _current_metrics.memory_usage > _performance_thresholds.memory_usage:
        _add_performance_warning("memory_usage", _current_metrics.memory_usage, current_time)
    
    # 检查CPU使用率
    if _current_metrics.cpu_usage > _performance_thresholds.cpu_usage:
        _add_performance_warning("cpu_usage", _current_metrics.cpu_usage, current_time)

func _add_performance_warning(metric_type: String, value: float, timestamp: float) -> void:
    var warning = {
        "type": metric_type,
        "value": value,
        "threshold": _performance_thresholds[metric_type],
        "timestamp": timestamp
    }
    
    _performance_warnings.append(warning)
    
    # 限制警告数量
    if _performance_warnings.size() > 100:
        _performance_warnings.pop_front()

func get_current_metrics() -> PerformanceMetrics:
    return _current_metrics

func get_performance_history(count: int = -1) -> Array[PerformanceMetrics]:
    if count <= 0 or count >= _performance_history.size():
        return _performance_history.duplicate()
    
    var start_index = _performance_history.size() - count
    return _performance_history.slice(start_index)

func get_performance_warnings() -> Array[Dictionary]:
    return _performance_warnings.duplicate()

func get_average_metrics(sample_count: int = 100) -> PerformanceMetrics:
    var history = get_performance_history(sample_count)
    
    if history.is_empty():
        return PerformanceMetrics.new()
    
    var average = PerformanceMetrics.new()
    
    for metrics in history:
        average.frame_time += metrics.frame_time
        average.fps += metrics.fps
        average.draw_calls += metrics.draw_calls
        average.memory_usage += metrics.memory_usage
        average.cpu_usage += metrics.cpu_usage
        average.active_contexts += metrics.active_contexts
        average.driver_executions += metrics.driver_executions
    
    var count = history.size()
    average.frame_time /= count
    average.fps /= count
    average.draw_calls /= count
    average.memory_usage /= count
    average.cpu_usage /= count
    average.active_contexts /= count
    average.driver_executions /= count
    
    return average

func set_performance_threshold(metric_type: String, threshold: float) -> void:
    _performance_thresholds[metric_type] = threshold

func get_performance_threshold(metric_type: String) -> float:
    return _performance_thresholds.get(metric_type, 0.0)

func clear_performance_warnings() -> void:
    _performance_warnings.clear()

func clear_performance_history() -> void:
    _performance_history.clear()
```

**开发任务分解**：
- [ ] 第15周第2天：性能指标收集
- [ ] 第15周第3天：性能分析工具
- [ ] 第15周第4天：性能报告生成
- [ ] 第15周第5天：单元测试

## JuicyVisualizer (可视化渲染器)

**文件路径**：`addons/juicy_mixer/debug/juicy_visualizer.gd`

**核心职责**：
- 渲染调试可视化
- 提供图表和图形显示
- 支持自定义可视化样式

**详细实现计划**：

```gdscript
class_name JuicyVisualizer
extends RefCounted

# 可视化配置
var _visualization_enabled: bool = false
var _overlay_layer: CanvasLayer
var _performance_overlay: Control
var _context_overlay: Control
var _buffer_overlay: Control

# 图表配置
var _chart_colors: Dictionary = {
    "frame_time": Color.RED,
    "fps": Color.GREEN,
    "memory_usage": Color.BLUE,
    "cpu_usage": Color.YELLOW
}

func enable_visualization() -> void:
    if _visualization_enabled:
        return
    
    _visualization_enabled = true
    _create_overlay_layer()
    _create_performance_overlay()
    _create_context_overlay()
    _create_buffer_overlay()

func disable_visualization() -> void:
    if not _visualization_enabled:
        return
    
    _visualization_enabled = false
    _cleanup_overlay_layer()

func _create_overlay_layer() -> void:
    _overlay_layer = CanvasLayer.new()
    _overlay_layer.layer = 100  # 顶层显示
    Engine.get_main_loop().current_scene.add_child(_overlay_layer)

func _create_performance_overlay() -> void:
    _performance_overlay = Control.new()
    _performance_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _performance_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _overlay_layer.add_child(_performance_overlay)

func _create_context_overlay() -> void:
    _context_overlay = Control.new()
    _context_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _context_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _overlay_layer.add_child(_context_overlay)

func _create_buffer_overlay() -> void:
    _buffer_overlay = Control.new()
    _buffer_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _buffer_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _overlay_layer.add_child(_buffer_overlay)

func render_performance_chart(performance_monitor: JuicyPerformanceMonitor) -> void:
    if not _visualization_enabled or not _performance_overlay:
        return
    
    # 清除之前的绘制
    _clear_overlay(_performance_overlay)
    
    # 获取性能数据
    var metrics = performance_monitor.get_performance_history(100)
    
    if metrics.is_empty():
        return
    
    # 绘制帧时间图表
    _draw_line_chart(_performance_overlay, metrics, "frame_time", Vector2(10, 10), Vector2(200, 100), _chart_colors.frame_time)
    
    # 绘制FPS图表
    _draw_line_chart(_performance_overlay, metrics, "fps", Vector2(10, 120), Vector2(200, 100), _chart_colors.fps)
    
    # 绘制内存使用图表
    _draw_line_chart(_performance_overlay, metrics, "memory_usage", Vector2(10, 230), Vector2(200, 100), _chart_colors.memory_usage)

func render_context_visualization(debugger: JuicyDebugger) -> void:
    if not _visualization_enabled or not _context_overlay:
        return
    
    # 清除之前的绘制
    _clear_overlay(_context_overlay)
    
    # 获取上下文快照
    var snapshots = debugger.get_all_context_snapshots()
    
    for context_id in snapshots:
        var snapshot = snapshots[context_id]
        _render_context_info(snapshot)

func render_buffer_visualization(debugger: JuicyDebugger) -> void:
    if not _visualization_enabled or not _buffer_overlay:
        return
    
    # 清除之前的绘制
    _clear_overlay(_buffer_overlay)
    
    # 获取缓冲区状态
    var buffer_states = debugger.get_all_buffer_states()
    
    for context_id in buffer_states:
        var buffer_state = buffer_states[context_id]
        _render_buffer_info(buffer_state)

func _draw_line_chart(overlay: Control, metrics: Array, property: String, position: Vector2, size: Vector2, color: Color) -> void:
    if metrics.is_empty():
        return
    
    # 创建图表背景
    var chart_bg = ColorRect.new()
    chart_bg.color = Color(0, 0, 0, 0.5)
    chart_bg.position = position
    chart_bg.size = size
    overlay.add_child(chart_bg)
    
    # 计算数据范围
    var min_value = INF
    var max_value = -INF
    
    for metric in metrics:
        var value = metric.get(property)
        min_value = min(min_value, value)
        max_value = max(max_value, value)
    
    if max_value <= min_value:
        return
    
    # 绘制数据线
    var points: Array[Vector2] = []
    
    for i in range(metrics.size()):
        var metric = metrics[i]
        var value = metric.get(property)
        var normalized_value = (value - min_value) / (max_value - min_value)
        var x = position.x + (float(i) / (metrics.size() - 1)) * size.x
        var y = position.y + size.y - (normalized_value * size.y)
        points.append(Vector2(x, y))
    
    # 绘制线条
    for i in range(points.size() - 1):
        overlay.draw_line(points[i], points[i + 1], color, 2.0)

func _render_context_info(snapshot: JuicyDebugger.ContextSnapshot) -> void:
    # 获取目标节点
    var target = Engine.get_main_loop().current_scene.get_node_or_null(snapshot.target_path)
    if not target:
        return
    
    # 获取屏幕位置
    var screen_pos = _get_screen_position(target)
    if screen_pos == Vector2.INF:
        return
    
    # 绘制上下文信息
    var info_text = "%s\n%s\n%.1f%%" % [
        snapshot.resource_type,
        snapshot.state,
        snapshot.current_progress * 100
    ]
    
    _draw_text(_context_overlay, info_text, screen_pos + Vector2(10, 10), Color.WHITE)

func _render_buffer_info(buffer_state: JuicyDebugger.BufferState) -> void:
    # 获取上下文
    var context = JuicyMixer.get_context(buffer_state.context_id)
    if not context:
        return
    
    # 获取目标节点
    var target = context.target
    var screen_pos = _get_screen_position(target)
    if screen_pos == Vector2.INF:
        return
    
    # 绘制缓冲区信息
    var info_text = "Buffer: %s\nSize: %d/%d\n%.1f%%" % [
        buffer_state.buffer_type,
        buffer_state.size,
        buffer_state.capacity,
        buffer_state.utilization * 100
    ]
    
    _draw_text(_buffer_overlay, info_text, screen_pos + Vector2(10, 50), Color.CYAN)

func _get_screen_position(node: Node) -> Vector2:
    if not node or not node is Node2D and not node is Node3D:
        return Vector2.INF
    
    var camera = Engine.get_main_loop().current_scene.get_viewport().get_camera_2d()
    if not camera:
        return Vector2.INF
    
    if node is Node2D:
        return camera.get_screen_center_position()
    elif node is Node3D:
        # 3D节点需要转换为2D屏幕坐标
        var camera_3d = Engine.get_main_loop().current_scene.get_viewport().get_camera_3d()
        if not camera_3d:
            return Vector2.INF
        
        return camera_3d.unproject_position(node.global_position)
    
    return Vector2.INF

func _draw_text(overlay: Control, text: String, position: Vector2, color: Color) -> void:
    var label = Label.new()
    label.text = text
    label.position = position
    label.modulate = color
    label.add_theme_font_size_override("font_size", 12)
    overlay.add_child(label)

func _clear_overlay(overlay: Control) -> void:
    for child in overlay.get_children():
        child.queue_free()

func _cleanup_overlay_layer() -> void:
    if _overlay_layer:
        _overlay_layer.queue_free()
        _overlay_layer = null
```

**开发任务分解**：
- [ ] 第15周第3天：可视化基础框架
- [ ] 第15周第4天：图表渲染实现
- [ ] 第15周第4天：上下文可视化
- [ ] 第15周第5天：单元测试

## JuicyDebugPanel (调试面板UI)

**文件路径**：`addons/juicy_mixer/editor/juicy_debug_panel.gd`

**核心职责**：
- 提供调试界面
- 显示调试信息
- 控制调试功能

**详细实现计划**：

```gdscript
@tool
class_name JuicyDebugPanel
extends Control

# 调试组件引用
var _debugger: JuicyDebugger
var _performance_monitor: JuicyPerformanceMonitor
var _visualizer: JuicyVisualizer

# UI组件
var _tab_container: TabContainer
var _context_tab: Control
var _performance_tab: Control
var _buffer_tab: Control
var _events_tab: Control

# 控制按钮
var _enable_debug_button: Button
var _enable_visualization_button: Button
var _export_data_button: Button
var _clear_data_button: Button

func _init(debugger: JuicyDebugger, performance_monitor: JuicyPerformanceMonitor, visualizer: JuicyVisualizer):
    _debugger = debugger
    _performance_monitor = performance_monitor
    _visualizer = visualizer

func _ready():
    _create_ui()
    _connect_signals()

func _create_ui() -> void:
    # 主容器
    var main_container = VBoxContainer.new()
    add_child(main_container)
    
    # 控制栏
    _create_control_bar(main_container)
    
    # 选项卡容器
    _tab_container = TabContainer.new()
    main_container.add_child(_tab_container)
    
    # 创建选项卡
    _create_context_tab()
    _create_performance_tab()
    _create_buffer_tab()
    _create_events_tab()

func _create_control_bar(parent: Control) -> void:
    var control_bar = HBoxContainer.new()
    parent.add_child(control_bar)
    
    # 启用调试按钮
    _enable_debug_button = Button.new()
    _enable_debug_button.text = "启用调试"
    _enable_debug_button.toggled.connect(_on_debug_toggled)
    control_bar.add_child(_enable_debug_button)
    
    # 启用可视化按钮
    _enable_visualization_button = Button.new()
    _enable_visualization_button.text = "启用可视化"
    _enable_visualization_button.toggled.connect(_on_visualization_toggled)
    control_bar.add_child(_enable_visualization_button)
    
    # 导出数据按钮
    _export_data_button = Button.new()
    _export_data_button.text = "导出数据"
    _export_data_button.pressed.connect(_on_export_data_pressed)
    control_bar.add_child(_export_data_button)
    
    # 清除数据按钮
    _clear_data_button = Button.new()
    _clear_data_button.text = "清除数据"
    _clear_data_button.pressed.connect(_on_clear_data_pressed)
    control_bar.add_child(_clear_data_button)

func _create_context_tab() -> void:
    _context_tab = VBoxContainer.new()
    _tab_container.add_child(_context_tab)
    
    # 上下文列表
    var context_list = ItemList.new()
    context_list.name = "ContextList"
    _context_tab.add_child(context_list)

func _create_performance_tab() -> void:
    _performance_tab = VBoxContainer.new()
    _tab_container.add_child(_performance_tab)
    
    # 性能指标显示
    var metrics_label = Label.new()
    metrics_label.name = "MetricsLabel"
    _performance_tab.add_child(metrics_label)
    
    # 性能图表
    var performance_chart = Control.new()
    performance_chart.name = "PerformanceChart"
    performance_tab.add_child(performance_chart)

func _create_buffer_tab() -> void:
    _buffer_tab = VBoxContainer.new()
    _tab_container.add_child(_buffer_tab)
    
    # 缓冲区列表
    var buffer_list = ItemList.new()
    buffer_list.name = "BufferList"
    _buffer_tab.add_child(buffer_list)

func _create_events_tab() -> void:
    _events_tab = VBoxContainer.new()
    _tab_container.add_child(_events_tab)
    
    # 事件列表
    var events_list = ItemList.new()
    events_list.name = "EventsList"
    _events_tab.add_child(events_list)

func _connect_signals() -> void:
    # 连接更新定时器
    var update_timer = Timer.new()
    update_timer.wait_time = 0.1
    update_timer.timeout.connect(_update_ui)
    update_timer.autostart = true
    add_child(update_timer)

func _update_ui() -> void:
    _update_context_tab()
    _update_performance_tab()
    _update_buffer_tab()
    _update_events_tab()

func _update_context_tab() -> void:
    var context_list = _context_tab.get_node("ContextList") as ItemList
    if not context_list:
        return
    
    context_list.clear()
    
    var snapshots = _debugger.get_all_context_snapshots()
    
    for context_id in snapshots:
        var snapshot = snapshots[context_id]
        var text = "%s - %s (%.1f%%)" % [
            snapshot.resource_type,
            snapshot.state,
            snapshot.current_progress * 100
        ]
        
        context_list.add_item(text)

func _update_performance_tab() -> void:
    var metrics_label = _performance_tab.get_node("MetricsLabel") as Label
    if not metrics_label:
        return
    
    var metrics = _performance_monitor.get_current_metrics()
    
    metrics_label.text = "帧时间: %.2fms\nFPS: %.1f\n内存: %dMB\nCPU: %.1f%%" % [
        metrics.frame_time,
        metrics.fps,
        metrics.memory_usage / (1024 * 1024),
        metrics.cpu_usage
    ]

func _update_buffer_tab() -> void:
    var buffer_list = _buffer_tab.get_node("BufferList") as ItemList
    if not buffer_list:
        return
    
    buffer_list.clear()
    
    var buffer_states = _debugger.get_all_buffer_states()
    
    for context_id in buffer_states:
        var buffer_state = buffer_states[context_id]
        var text = "%s - %d/%d (%.1f%%)" % [
            buffer_state.buffer_type,
            buffer_state.size,
            buffer_state.capacity,
            buffer_state.utilization * 100
        ]
        
        buffer_list.add_item(text)

func _update_events_tab() -> void:
    var events_list = _events_tab.get_node("EventsList") as ItemList
    if not events_list:
        return
    
    events_list.clear()
    
    var events = _debugger.get_debug_events(50)
    
    for event in events:
        var text = "%.2f - %s" % [event.timestamp, event.type]
        events_list.add_item(text)

func _on_debug_toggled(pressed: bool) -> void:
    if pressed:
        _debugger.enable_debug()
        _enable_debug_button.text = "禁用调试"
    else:
        _debugger.disable_debug()
        _enable_debug_button.text = "启用调试"

func _on_visualization_toggled(pressed: bool) -> void:
    if pressed:
        _visualizer.enable_visualization()
        _enable_visualization_button.text = "禁用可视化"
    else:
        _visualizer.disable_visualization()
        _enable_visualization_button.text = "启用可视化"

func _on_export_data_pressed() -> void:
    var debug_data = _debugger.export_debug_data()
    
    # 保存到文件
    var file = FileAccess.open("user://juicy_debug_data.json", FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(debug_data))
        file.close()
        
        print("调试数据已导出到: user://juicy_debug_data.json")

func _on_clear_data_pressed() -> void:
    _debugger.clear_debug_data()
    _performance_monitor.clear_performance_warnings()
    _performance_monitor.clear_performance_history()
```

**开发任务分解**：
- [ ] 第15周第4天：调试面板UI设计
- [ ] 第15周第4天：调试信息显示
- [ ] 第15周第5天：调试控制功能
- [ ] 第15周第5天：单元测试

## 性能优化

### 执行效率
- 调试系统需要最小化性能影响
- 可视化渲染需要优化绘制开销

### 内存管理
- 调试数据需要限制内存使用
- 历史记录需要自动清理

## 测试计划

### 单元测试
- JuicyDebugger调试器测试
- JuicyPerformanceMonitor性能监控测试
- JuicyVisualizer可视化测试
- JuicyDebugPanel调试面板测试

### 集成测试
- 与所有系统组件集成测试
- 编辑器集成测试

### 性能测试
- 调试系统性能影响测试
- 可视化渲染性能测试

## 交付检查清单

### 代码交付
- [ ] JuicyDebugger调试系统
- [ ] JuicyPerformanceMonitor性能监控器
- [ ] JuicyVisualizer可视化渲染器
- [ ] JuicyDebugPanel调试面板
- [ ] 单元测试和集成测试
- [ ] 性能基准测试

### 文档交付
- [ ] 调试和可视化系统使用文档
- [ ] API参考文档
- [ ] 性能优化指南

### 验收标准
- [ ] 所有单元测试通过（覆盖率100%）
- [ ] 所有集成测试通过
- [ ] 性能基准测试达标
- [ ] 代码审查通过
- [ ] 文档完整准确

## 风险管控

### 技术风险
1. **性能影响**：调试系统可能影响整体性能
   - 缓解措施：实现条件编译和性能优化

2. **可视化复杂性**：复杂的可视化可能难以实现
   - 缓解措施：分阶段实现，先提供基础功能

### 进度风险
1. **UI开发复杂性**：调试面板UI开发可能比预期耗时
   - 缓解措施：使用现有UI组件，简化设计

## 总结

调试与可视化系统是JuicyMixer V3的重要特性之一，它提供了强大的运行时调试和可视化功能。通过状态监控、性能分析和可视化渲染，开发者可以深入了解系统的运行状态和性能表现。

**关键成就**：
- 实现了全面的调试数据收集
- 提供了强大的性能监控功能
- 确保了高效的可视化渲染
- 提供了直观的调试界面

调试与可视化系统将为JuicyMixer V3用户提供优秀的调试体验，使系统的开发和维护变得更加便捷。