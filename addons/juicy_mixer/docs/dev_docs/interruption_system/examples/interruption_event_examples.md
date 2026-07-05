# 中断事件处理示例

## 概述

本文档展示了如何处理JuicyMixer中断系统的事件，包括监听中断事件、响应中断状态变化、创建自定义事件处理器等。

## 基础事件监听

### 监听中断事件

```gdscript
class_name InterruptionEventListener
extends Node

var event_history: Array[Dictionary] = []
var max_history_size: int = 100

func _ready():
    _setup_event_listeners()

func _setup_event_listeners():
    # 连接到JuicyMixer的事件系统
    if JuicyMixer.instance:
        # 监听中断发生事件
        if JuicyMixer.instance.has_signal("interruption_occurred"):
            JuicyMixer.instance.interruption_occurred.connect(_on_interruption_occurred)
        
        # 监听中断解决事件
        if JuicyMixer.instance.has_signal("interruption_resolved"):
            JuicyMixer.instance.interruption_resolved.connect(_on_interruption_resolved)
        
        # 监听过渡开始事件
        if JuicyMixer.instance.has_signal("transition_started"):
            JuicyMixer.instance.transition_started.connect(_on_transition_started)
        
        # 监听过渡完成事件
        if JuicyMixer.instance.has_signal("transition_completed"):
            JuicyMixer.instance.transition_completed.connect(_on_transition_completed)
        
        print("中断事件监听器已设置")

func _on_interruption_occurred(event_data: Dictionary):
    """处理中断发生事件"""
    print("=== 中断发生 ===")
    print("时间: ", event_data.get("timestamp", 0))
    print("事件类型: ", event_data.get("type", "unknown"))
    print("新上下文: ", event_data.get("new_context", "unknown"))
    print("现有上下文: ", event_data.get("existing_context", "unknown"))
    print("目标: ", event_data.get("target", null))
    print("策略: ", event_data.get("policy", "unknown"))
    
    # 记录事件历史
    _record_event("interruption_occurred", event_data)

func _on_interruption_resolved(event_data: Dictionary):
    """处理中断解决事件"""
    print("=== 中断解决 ===")
    print("时间: ", event_data.get("timestamp", 0))
    print("上下文: ", event_data.get("context_id", "unknown"))
    print("解决类型: ", event_data.get("resolution_type", "unknown"))
    
    # 记录事件历史
    _record_event("interruption_resolved", event_data)

func _on_transition_started(event_data: Dictionary):
    """处理过渡开始事件"""
    print("=== 过渡开始 ===")
    print("时间: ", event_data.get("timestamp", 0))
    print("过渡类型: ", event_data.get("transition_type", "unknown"))
    print("上下文: ", event_data.get("context_id", "unknown"))
    print("源上下文: ", event_data.get("from_context_id", "none"))
    print("持续时间: ", event_data.get("duration", 0))
    
    # 记录事件历史
    _record_event("transition_started", event_data)

func _on_transition_completed(event_data: Dictionary):
    """处理过渡完成事件"""
    print("=== 过渡完成 ===")
    print("时间: ", event_data.get("timestamp", 0))
    print("上下文: ", event_data.get("context_id", "unknown"))
    print("过渡类型: ", event_data.get("transition_type", "unknown"))
    
    # 记录事件历史
    _record_event("transition_completed", event_data)

func _record_event(event_type: String, event_data: Dictionary):
    """记录事件到历史"""
    var record = {
        "timestamp": Time.get_ticks_msec() / 1000.0,
        "type": event_type,
        "data": event_data
    }
    
    event_history.append(record)
    
    # 限制历史记录大小
    if event_history.size() > max_history_size:
        event_history.pop_front()

func get_event_history() -> Array[Dictionary]:
    """获取事件历史"""
    return event_history.duplicate()

func clear_event_history():
    """清空事件历史"""
    event_history.clear()
    print("事件历史已清空")
```

### 中间件事件处理

```gdscript
class_name MiddlewareEventHandler
extends RefCounted

var event_handlers: Dictionary = {}
var event_queue: Array[Dictionary] = []
var processing_events: bool = false

func _init():
    _setup_default_handlers()

func _setup_default_handlers():
    """设置默认事件处理器"""
    event_handlers["interruption_occurred"] = _handle_interruption_occurred
    event_handlers["interruption_resolved"] = _handle_interruption_resolved
    event_handlers["transition_started"] = _handle_transition_started
    event_handlers["transition_completed"] = _handle_transition_completed

func register_handler(event_type: String, handler: Callable):
    """注册自定义事件处理器"""
    event_handlers[event_type] = handler
    print("注册事件处理器: ", event_type)

func unregister_handler(event_type: String):
    """注销事件处理器"""
    if event_handlers.has(event_type):
        event_handlers.erase(event_type)
        print("注销事件处理器: ", event_type)

func process_event(event_type: String, event_data: Dictionary):
    """处理事件"""
    var event = {
        "type": event_type,
        "data": event_data,
        "timestamp": Time.get_ticks_msec() / 1000.0
    }
    
    # 添加到队列
    event_queue.append(event)
    
    # 如果没有在处理事件，开始处理
    if not processing_events:
        _process_event_queue()

func _process_event_queue():
    """处理事件队列"""
    processing_events = true
    
    while event_queue.size() > 0:
        var event = event_queue.pop_front()
        var handler = event_handlers.get(event.type)
        
        if handler.is_valid():
            handler.call(event.data)
        
        # 避免阻塞主线程
        await Engine.get_main_loop().process_frame
    
    processing_events = false

# 默认事件处理器
func _handle_interruption_occurred(event_data: Dictionary):
    print("中间件处理中断: ", event_data.get("new_context"), " -> ", event_data.get("existing_context"))

func _handle_interruption_resolved(event_data: Dictionary):
    print("中间件处理中断解决: ", event_data.get("context_id"))

func _handle_transition_started(event_data: Dictionary):
    print("中间件处理过渡开始: ", event_data.get("context_id"))

func _handle_transition_completed(event_data: Dictionary):
    print("中间件处理过渡完成: ", event_data.get("context_id"))
```

## 高级事件处理

### 事件过滤器

```gdscript
class_name InterruptionEventFilter
extends RefCounted

var filter_rules: Array[Dictionary] = []
var filtered_events: Array[Dictionary] = []

func add_filter_rule(rule: Dictionary):
    """添加过滤规则"""
    filter_rules.append(rule)
    print("添加过滤规则: ", rule.get("name", "unnamed"))

func filter_event(event_type: String, event_data: Dictionary) -> bool:
    """过滤事件"""
    for rule in filter_rules:
        if _matches_rule(event_type, event_data, rule):
            if rule.get("action", "allow") == "block":
                _record_filtered_event(event_type, event_data, rule)
                return false
            elif rule.get("action", "allow") == "log":
                _record_filtered_event(event_type, event_data, rule)
    
    return true

func _matches_rule(event_type: String, event_data: Dictionary, rule: Dictionary) -> bool:
    """检查事件是否匹配规则"""
    var rule_type = rule.get("event_type", "")
    if rule_type != "" and rule_type != event_type:
        return false
    
    var conditions = rule.get("conditions", [])
    for condition in conditions:
        if not _matches_condition(event_data, condition):
            return false
    
    return true

func _matches_condition(event_data: Dictionary, condition: Dictionary) -> bool:
    """检查事件数据是否匹配条件"""
    var key = condition.get("key", "")
    var operator = condition.get("operator", "equals")
    var value = condition.get("value", null)
    var event_value = _get_nested_value(event_data, key)
    
    match operator:
        "equals":
            return event_value == value
        "not_equals":
            return event_value != value
        "greater_than":
            return event_value > value
        "less_than":
            return event_value < value
        "contains":
            return str(event_value).contains(str(value))
        "in_list":
            return event_value in value
        _:
            return false

func _get_nested_value(data: Dictionary, key_path: String):
    """获取嵌套值"""
    var keys = key_path.split(".")
    var current = data
    
    for key in keys:
        if current is Dictionary and current.has(key):
            current = current[key]
        else:
            return null
    
    return current

func _record_filtered_event(event_type: String, event_data: Dictionary, rule: Dictionary):
    """记录被过滤的事件"""
    var record = {
        "timestamp": Time.get_ticks_msec() / 1000.0,
        "event_type": event_type,
        "event_data": event_data,
        "rule_name": rule.get("name", "unnamed"),
        "rule_action": rule.get("action", "allow")
    }
    
    filtered_events.append(record)
    print("事件被过滤: ", event_type, " by rule ", rule.get("name", "unnamed"))

func get_filtered_events() -> Array[Dictionary]:
    """获取被过滤的事件"""
    return filtered_events.duplicate()

func clear_filtered_events():
    """清空被过滤的事件"""
    filtered_events.clear()
```

### 事件聚合器

```gdscript
class_name InterruptionEventAggregator
extends RefCounted

var aggregation_rules: Array[Dictionary] = []
var aggregated_data: Dictionary = {}
var aggregation_interval: float = 1.0
var timer: Timer

func _init():
    timer = Timer.new()
    timer.wait_time = aggregation_interval
    timer.timeout.connect(_perform_aggregation)
    timer.autostart = true

func add_aggregation_rule(rule: Dictionary):
    """添加聚合规则"""
    aggregation_rules.append(rule)
    print("添加聚合规则: ", rule.get("name", "unnamed"))

func process_event(event_type: String, event_data: Dictionary):
    """处理事件并聚合"""
    for rule in aggregation_rules:
        if _should_aggregate_event(event_type, event_data, rule):
            _aggregate_event(event_type, event_data, rule)

func _should_aggregate_event(event_type: String, event_data: Dictionary, rule: Dictionary) -> bool:
    """检查是否应该聚合事件"""
    var rule_event_types = rule.get("event_types", [])
    if rule_event_types.size() > 0 and not event_type in rule_event_types:
        return false
    
    var conditions = rule.get("conditions", [])
    for condition in conditions:
        if not _matches_condition(event_data, condition):
            return false
    
    return true

func _matches_condition(event_data: Dictionary, condition: Dictionary) -> bool:
    """匹配条件（与EventFilter相同的实现）"""
    var key = condition.get("key", "")
    var operator = condition.get("operator", "equals")
    var value = condition.get("value", null)
    var event_value = _get_nested_value(event_data, key)
    
    match operator:
        "equals":
            return event_value == value
        "greater_than":
            return event_value > value
        "less_than":
            return event_value < value
        _:
            return false

func _get_nested_value(data: Dictionary, key_path: String):
    """获取嵌套值（与EventFilter相同的实现）"""
    var keys = key_path.split(".")
    var current = data
    
    for key in keys:
        if current is Dictionary and current.has(key):
            current = current[key]
        else:
            return null
    
    return current

func _aggregate_event(event_type: String, event_data: Dictionary, rule: Dictionary):
    """聚合事件"""
    var rule_name = rule.get("name", "unnamed")
    var aggregation_type = rule.get("aggregation_type", "count")
    
    if not aggregated_data.has(rule_name):
        aggregated_data[rule_name] = {
            "type": aggregation_type,
            "data": {},
            "last_update": Time.get_ticks_msec() / 1000.0
        }
    
    var agg_data = aggregated_data[rule_name]
    
    match aggregation_type:
        "count":
            var current_count = agg_data.data.get("count", 0)
            agg_data.data.count = current_count + 1
        
        "sum":
            var value_key = rule.get("value_key", "value")
            var event_value = _get_nested_value(event_data, value_key)
            var current_sum = agg_data.data.get("sum", 0)
            agg_data.data.sum = current_sum + event_value
        
        "average":
            var value_key = rule.get("value_key", "value")
            var event_value = _get_nested_value(event_data, value_key)
            var current_sum = agg_data.data.get("sum", 0)
            var current_count = agg_data.data.get("count", 0)
            agg_data.data.sum = current_sum + event_value
            agg_data.data.count = current_count + 1
        
        "latest":
            agg_data.data = event_data.duplicate()

func _perform_aggregation():
    """执行聚合计算"""
    for rule_name in aggregated_data:
        var agg_data = aggregated_data[rule_name]
        var aggregation_type = agg_data.type
        
        match aggregation_type:
            "average":
                var sum = agg_data.data.get("sum", 0)
                var count = agg_data.data.get("count", 0)
                if count > 0:
                    agg_data.data.average = sum / count
        
        agg_data.last_update = Time.get_ticks_msec() / 1000.0

func get_aggregated_data(rule_name: String) -> Dictionary:
    """获取聚合数据"""
    return aggregated_data.get(rule_name, {})

func get_all_aggregated_data() -> Dictionary:
    """获取所有聚合数据"""
    return aggregated_data.duplicate()

func clear_aggregated_data(rule_name: String = ""):
    """清空聚合数据"""
    if rule_name.is_empty():
        aggregated_data.clear()
        print("清空所有聚合数据")
    else:
        aggregated_data.erase(rule_name)
        print("清空聚合数据: ", rule_name)
```

## 实际应用场景

### 调试和监控系统

```gdscript
class_name InterruptionDebugSystem
extends Node

var debug_enabled: bool = false
var event_listener: InterruptionEventListener
var event_filter: InterruptionEventFilter
var event_aggregator: InterruptionEventAggregator

func _ready():
    _setup_debug_system()

func _setup_debug_system():
    """设置调试系统"""
    event_listener = InterruptionEventListener.new()
    event_filter = InterruptionEventFilter.new()
    event_aggregator = InterruptionEventAggregator.new()
    
    # 添加调试过滤规则
    _add_debug_filters()
    
    # 添加聚合规则
    _add_aggregation_rules()
    
    add_child(event_listener)

func _add_debug_filters():
    """添加调试过滤规则"""
    # 过滤掉频繁的过渡事件
    event_filter.add_filter_rule({
        "name": "filter_frequent_transitions",
        "event_type": "transition_started",
        "conditions": [
            {"key": "duration", "operator": "less_than", "value": 0.1}
        ],
        "action": "log"
    })
    
    # 阻止低优先级中断事件的详细日志
    event_filter.add_filter_rule({
        "name": "filter_low_priority_interruptions",
        "event_type": "interruption_occurred",
        "conditions": [
            {"key": "data.policy", "operator": "equals", "value": "stack"}
        ],
        "action": "log"
    })

func _add_aggregation_rules():
    """添加聚合规则"""
    # 聚合中断频率
    event_aggregator.add_aggregation_rule({
        "name": "interruption_frequency",
        "event_types": ["interruption_occurred"],
        "aggregation_type": "count",
        "conditions": []
    })
    
    # 聚合平均中断时间
    event_aggregator.add_aggregation_rule({
        "name": "interruption_duration",
        "event_types": ["interruption_resolved"],
        "aggregation_type": "average",
        "value_key": "data.resolution_time"
    })

func enable_debug():
    """启用调试"""
    debug_enabled = true
    print("中断调试系统已启用")

func disable_debug():
    """禁用调试"""
    debug_enabled = false
    print("中断调试系统已禁用")

func get_debug_report() -> Dictionary:
    """获取调试报告"""
    return {
        "event_history": event_listener.get_event_history(),
        "filtered_events": event_filter.get_filtered_events(),
        "aggregated_data": event_aggregator.get_all_aggregated_data(),
        "debug_enabled": debug_enabled
    }

func print_debug_report():
    """打印调试报告"""
    if not debug_enabled:
        print("调试系统未启用")
        return
    
    var report = get_debug_report()
    
    print("=== 中断调试报告 ===")
    print("调试状态: ", "启用" if debug_enabled else "禁用")
    print("事件历史数量: ", report.event_history.size())
    print("被过滤事件数量: ", report.filtered_events.size())
    
    # 打印聚合数据
    for rule_name in report.aggregated_data:
        var agg_data = report.aggregated_data[rule_name]
        print("聚合数据 [", rule_name, "]: ", agg_data)
```

### 性能监控系统

```gdscript
class_name InterruptionPerformanceMonitor
extends Node

var performance_data: Dictionary = {}
var monitoring_enabled: bool = false
var report_interval: float = 5.0
var report_timer: Timer

func _ready():
    _setup_performance_monitor()

func _setup_performance_monitor():
    """设置性能监控"""
    report_timer = Timer.new()
    report_timer.wait_time = report_interval
    report_timer.timeout.connect(_generate_performance_report)
    add_child(report_timer)

func start_monitoring():
    """开始监控"""
    monitoring_enabled = true
    report_timer.start()
    print("中断性能监控已启动")

func stop_monitoring():
    """停止监控"""
    monitoring_enabled = false
    report_timer.stop()
    print("中断性能监控已停止")

func record_interruption_performance(interruption_data: Dictionary):
    """记录中断性能数据"""
    if not monitoring_enabled:
        return
    
    var timestamp = Time.get_ticks_msec() / 1000.0
    var strategy = interruption_data.get("strategy", "unknown")
    
    if not performance_data.has(strategy):
        performance_data[strategy] = {
            "count": 0,
            "total_time": 0.0,
            "min_time": INF,
            "max_time": -INF,
            "last_timestamp": 0.0
        }
    
    var data = performance_data[strategy]
    var duration = interruption_data.get("duration", 0.0)
    
    data.count += 1
    data.total_time += duration
    data.min_time = min(data.min_time, duration)
    data.max_time = max(data.max_time, duration)
    data.last_timestamp = timestamp

func _generate_performance_report():
    """生成性能报告"""
    if not monitoring_enabled:
        return
    
    print("=== 中断性能报告 ===")
    print("生成时间: ", Time.get_datetime_string_from_system())
    
    for strategy in performance_data:
        var data = performance_data[strategy]
        var avg_time = data.total_time / data.count if data.count > 0 else 0.0
        
        print("\n策略: ", strategy)
        print("  执行次数: ", data.count)
        print("  总时间: ", "%.3f" % data.total_time, " ms")
        print("  平均时间: ", "%.3f" % avg_time, " ms")
        print("  最小时间: ", "%.3f" % data.min_time, " ms")
        print("  最大时间: ", "%.3f" % data.max_time, " ms")
        print("  最后执行: ", Time.get_datetime_string_from_unix_time(data.last_timestamp))

func get_performance_data() -> Dictionary:
    """获取性能数据"""
    return performance_data.duplicate()

func clear_performance_data():
    """清空性能数据"""
    performance_data.clear()
    print("性能数据已清空")
```

### 自定义事件处理器

```gdscript
class_name CustomInterruptionEventHandler
extends Node

var custom_handlers: Dictionary = {}
var event_dispatcher: Node

func _ready():
    _setup_event_dispatcher()

func _setup_event_dispatcher():
    """设置事件分发器"""
    event_dispatcher = Node.new()
    event_dispatcher.name = "InterruptionEventDispatcher"
    add_child(event_dispatcher)
    
    # 添加自定义信号
    event_dispatcher.add_user_signal("custom_interruption_event")
    event_dispatcher.add_user_signal("interruption_threshold_reached")
    event_dispatcher.add_user_signal("interruption_pattern_detected")

func register_custom_handler(event_name: String, handler: Callable):
    """注册自定义事件处理器"""
    custom_handlers[event_name] = handler
    print("注册自定义事件处理器: ", event_name)

func handle_interruption_event(event_data: Dictionary):
    """处理中断事件并分发到自定义处理器"""
    # 检查阈值事件
    _check_interruption_thresholds(event_data)
    
    # 检查模式事件
    _check_interruption_patterns(event_data)
    
    # 分发自定义事件
    event_dispatcher.emit_signal("custom_interruption_event", event_data)

func _check_interruption_thresholds(event_data: Dictionary):
    """检查中断阈值"""
    var handler = custom_handlers.get("threshold_check")
    if handler.is_valid():
        handler.call(event_data)

func _check_interruption_patterns(event_data: Dictionary):
    """检查中断模式"""
    var handler = custom_handlers.get("pattern_check")
    if handler.is_valid():
        var pattern = handler.call(event_data)
        if pattern:
            event_dispatcher.emit_signal("interruption_pattern_detected", pattern)

# 示例自定义处理器
func create_threshold_handler():
    """创建阈值检查处理器"""
    return func(event_data: Dictionary):
        var threshold = 10  # 每分钟最多10次中断
        var current_time = Time.get_ticks_msec() / 1000.0
        
        # 这里应该有更复杂的逻辑来计算频率
        # 简化示例
        if randf() < 0.1:  # 模拟10%的概率超过阈值
            event_dispatcher.emit_signal("interruption_threshold_reached", {
                "threshold": threshold,
                "current_value": 12,
                "timestamp": current_time
            })

func create_pattern_handler():
    """创建模式检查处理器"""
    return func(event_data: Dictionary):
        # 检查是否有连续的中断模式
        var strategy = event_data.get("policy", "")
        
        # 简化的模式检测
        if strategy == "priority_override":
            return {
                "pattern": "frequent_priority_overrides",
                "severity": "medium"
            }
        
        return null

func connect_to_custom_events():
    """连接到自定义事件"""
    event_dispatcher.custom_interruption_event.connect(_on_custom_interruption_event)
    event_dispatcher.interruption_threshold_reached.connect(_on_threshold_reached)
    event_dispatcher.interruption_pattern_detected.connect(_on_pattern_detected)

func _on_custom_interruption_event(event_data: Dictionary):
    """处理自定义中断事件"""
    print("自定义中断事件: ", event_data)

func _on_threshold_reached(threshold_data: Dictionary):
    """处理阈值达到事件"""
    print("中断阈值达到: ", threshold_data)
    # 可以在这里采取行动，如降低中断频率

func _on_pattern_detected(pattern_data: Dictionary):
    """处理模式检测事件"""
    print("检测到中断模式: ", pattern_data)
    # 可以在这里调整中断策略
```

## 最佳实践

1. **事件过滤**: 使用过滤器减少不必要的事件处理
2. **事件聚合**: 聚合频繁事件以提高性能
3. **性能监控**: 监控事件处理性能，避免影响游戏性能
4. **调试支持**: 提供详细的调试信息和事件历史
5. **错误处理**: 妥善处理事件处理中的错误

## 常见问题

### Q: 如何避免事件处理影响游戏性能？
A: 使用事件过滤、聚合和异步处理机制。

### Q: 如何记录复杂的事件数据？
A: 使用嵌套的数据结构和序列化机制。

### Q: 如何创建自定义事件类型？
A: 扩展事件系统并添加自定义信号和处理器。

### Q: 如何调试事件处理问题？
A: 启用详细日志、事件历史记录和性能监控。

## 相关文档

- [基础中断策略使用示例](basic_interruption_examples.md)
- [高级中断配置示例](advanced_interruption_examples.md)
- [自定义中断策略示例](custom_interruption_examples.md)
- [性能优化示例](performance_optimization_examples.md)
- [API文档](../api/)