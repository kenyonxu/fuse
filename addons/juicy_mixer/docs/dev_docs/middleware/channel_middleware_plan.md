# 通道中间件开发计划

## 系统集成与优化要求

### 与Driver系统的协同优化
**Driver执行优化**：
- ChannelMiddleware需要考虑Driver的资源消耗和执行时间
- 在高负载情况下，可能需要限制特定高开销Driver的并发执行

## 核心组件详细设计

### 4. JuicyChannelConfig (通道配置资源)

**文件路径**：`addons/juicy_mixer/resources/juicy_channel_config.gd`

**核心职责**：
- 定义通道的配置参数
- 提供可序列化的配置存储
- 支持编辑器中的可视化配置
- 提供配置验证功能

**详细实现计划**：

```gdscript
@tool
class_name JuicyChannelConfig
extends Resource

# 通道配置属性
@export var channel_name: String = "default"
@export var max_concurrent: int = -1  # -1表示无限制
@export var priority_mode: JuicyMixerEnms.PriorityMode = JuicyMixerEnms.PriorityMode.FIFO
@export var allow_interruption: bool = true
@export var auto_stop_previous: bool = false
@export var description: String = ""

func _init():
    """初始化通道配置"""
    resource_name = "ChannelConfig: " + channel_name

# 验证配置
func validate() -> Dictionary:
    """验证配置的有效性"""
    var result = {
        "valid": true,
        "issues": [],
        "warnings": []
    }
    
    if channel_name.is_empty():
        result.valid = false
        result.issues.append("Channel name cannot be empty")
    
    if max_concurrent < -1:
        result.valid = false
        result.issues.append("Max concurrent must be -1 or greater")
    
    return result

# 获取配置描述
func get_description() -> String:
    """获取配置的友好描述"""
    var priority_names = ["FIFO", "LIFO", "PRIORITY_BASED"]
    var priority_name = priority_names[priority_mode] if priority_mode < priority_names.size() else "UNKNOWN"
    
    return "Channel '%s': max=%s, mode=%s, interrupt=%s" % [
        channel_name,
        "unlimited" if max_concurrent == -1 else str(max_concurrent),
        priority_name,
        allow_interruption
    ]

# 编辑器支持
func _get_property_list() -> Array[Dictionary]:
    """获取属性列表，用于编辑器显示"""
    var properties = []
    
    properties.append({
        "name": "priority_mode",
        "type": TYPE_INT,
        "hint": PROPERTY_HINT_ENUM,
        "hint_string": "FIFO,LIFO,PRIORITY_BASED",
        "usage": PROPERTY_USAGE_DEFAULT
    })
    
    return properties

# 序列化支持
func _to_string() -> String:
    """获取字符串表示"""
    return get_description()
```

**开发任务分解**：
- [ ] 第8周第3天：基础资源类结构
- [ ] 第8周第3天：属性定义和验证
- [ ] 第8周第4天：编辑器支持和序列化
- [ ] 第8周第4天：单元测试

**验收标准**：
- 资源类正确继承Resource
- 属性序列化和反序列化正常
- 编辑器显示友好
- 配置验证功能完整
- 单元测试覆盖率100%

---

### 5. ChannelMiddleware (通道中间件)

**文件路径**：`addons/juicy_mixer/middleware/channel_middleware.gd`

**核心职责**：
- 管理效果通道的调度规则
- 控制同通道效果的并发
- 实现通道优先级和限制
- 提供通道状态监控
- 加载和管理通道配置资源

**详细实现计划**：

```gdscript
class_name JuicyChannelMiddleware
extends JuicyMiddleware

# 通道管理
var _channel_configs: Dictionary = {}  # channel_name -> JuicyChannelConfig
var _channel_states: Dictionary = {}   # channel_name -> ChannelState
var _context_channels: Dictionary = {} # context_id -> channel_name

# 通道状态
class ChannelState:
    var active_contexts: Array[String] = []
    var queued_contexts: Array[String] = []
    var total_executed: int = 0

func _init():
    middleware_name = "ChannelMiddleware"
    priority = 900  # 高优先级，在验证后执行
    description = "Manages effect channel scheduling and concurrency"

func process(context: JuicyContext, next: Callable) -> bool:
    """处理通道调度"""
    var start_time = _start_execution_timer()
    
    var channel_name = context.resource.channel
    if channel_name.is_empty():
        channel_name = "default"
    
    # 获取或创建通道配置
    var channel_config = _get_channel_config(channel_name)
    
    # 获取或创建通道状态
    var channel_state = _get_channel_state(channel_name)
    
    # 检查是否可以调度
    if not _can_schedule(channel_config, channel_state, context):
        _end_execution_timer(start_time)
        return false
    
    # 执行调度
    if not _schedule_context(channel_config, channel_state, context):
        _end_execution_timer(start_time)
        return false
    
    # 记录通道关联
    _context_channels[context.context_id] = channel_name
    
    _end_execution_timer(start_time)
    return next.call(context)

func cleanup(context: JuicyContext) -> void:
    """清理通道状态"""
    var channel_name = _context_channels.get(context.context_id)
    if channel_name:
        var channel_state = _channel_states.get(channel_name)
        if channel_state:
            channel_state.active_contexts.erase(context.context_id)
        
        _context_channels.erase(context.context_id)
        
        # 处理队列中的下一个Context
        _process_queue(channel_name)

# 内部实现
func _get_channel_config(channel_name: String) -> JuicyChannelConfig:
    """获取通道配置"""
    if not _channel_configs.has(channel_name):
        _channel_configs[channel_name] = _create_default_channel_config(channel_name)
    return _channel_configs[channel_name]

func _create_default_channel_config(channel_name: String) -> JuicyChannelConfig:
    """创建默认通道配置"""
    var config = JuicyChannelConfig.new()
    config.channel_name = channel_name
    return config

func _get_channel_state(channel_name: String) -> ChannelState:
    """获取通道状态"""
    if not _channel_states.has(channel_name):
        _channel_states[channel_name] = ChannelState.new()
    return _channel_states[channel_name]

func _can_schedule(config: JuicyChannelConfig, state: ChannelState, context: JuicyContext) -> bool:
    """检查是否可以调度"""
    # 检查并发限制
    if config.max_concurrent > 0 and state.active_contexts.size() >= config.max_concurrent:
        return false
    
    # 检查是否允许中断
    if not config.allow_interruption and not state.active_contexts.is_empty():
        return false
    
    return true

func _schedule_context(config: JuicyChannelConfig, state: ChannelState, context: JuicyContext) -> bool:
    """调度Context"""
    # 如果需要自动停止前一个Context
    if config.auto_stop_previous and not state.active_contexts.is_empty():
        var previous_context_id = state.active_contexts[-1]
        JuicyMixer.stop(previous_context_id)
    
    # 添加到活跃列表
    state.active_contexts.append(context.context_id)
    state.total_executed += 1
    
    return true

func _process_queue(channel_name: String) -> void:
    """处理队列中的Context"""
    var config = _get_channel_config(channel_name)
    var state = _get_channel_state(channel_name)
    
    while not state.queued_contexts.is_empty() and _can_schedule(config, state, null):
        var context_id = _dequeue_context(config, state)
        if context_id.is_empty():
            break
        
        # 重新调度队列中的Context
        var context = JuicyMixer.get_context(context_id)
        if context:
            _schedule_context(config, state, context)

func _dequeue_context(config: JuicyChannelConfig, state: ChannelState) -> String:
    """从队列中取出Context"""
    if state.queued_contexts.is_empty():
        return ""
    
    match config.priority_mode:
        JuicyMixerEnms.PriorityMode.FIFO:
            return state.queued_contexts.pop_front()
        JuicyMixerEnms.PriorityMode.LIFO:
            return state.queued_contexts.pop_back()
        JuicyMixerEnms.PriorityMode.PRIORITY_BASED:
            # 按优先级排序后取出
            state.queued_contexts.sort_custom(func(a, b):
                var context_a = JuicyMixer.get_context(a)
                var context_b = JuicyMixer.get_context(b)
                if not context_a or not context_b:
                    return false
                return context_a.resource.priority > context_b.resource.priority
            )
            return state.queued_contexts.pop_front()
        _:
            return state.queued_contexts.pop_front()

# 通道配置管理
func set_channel_config(channel_name: String, config: JuicyChannelConfig) -> void:
    """设置通道配置"""
    _channel_configs[channel_name] = config

func get_channel_config(channel_name: String) -> JuicyChannelConfig:
    """获取通道配置"""
    return _get_channel_config(channel_name)

func load_channel_config(resource_path: String) -> JuicyChannelConfig:
    """从文件加载通道配置"""
    if ResourceLoader.exists(resource_path):
        return load(resource_path) as JuicyChannelConfig
    return null

func save_channel_config(config: JuicyChannelConfig, resource_path: String) -> bool:
    """保存通道配置到文件"""
    return ResourceSaver.save(config, resource_path) == OK

func get_channel_state(channel_name: String) -> ChannelState:
    """获取通道状态"""
    return _get_channel_state(channel_name)

# 统计和调试
func get_channel_stats() -> Dictionary:
    """获取通道统计信息"""
    var stats = {}
    
    for channel_name in _channel_states.keys():
        var state = _channel_states[channel_name]
        var config = _channel_configs[channel_name]
        
        stats[channel_name] = {
            "active_contexts": state.active_contexts.size(),
            "queued_contexts": state.queued_contexts.size(),
            "max_concurrent": config.max_concurrent,
            "priority_mode": config.priority_mode,
            "total_executed": state.total_executed
        }
    
    return stats

func debug_print_channels() -> void:
    """打印通道信息"""
    print("=== JuicyMixer Channel States ===")
    var stats = get_channel_stats()
    
    for channel_name in stats.keys():
        var stat = stats[channel_name]
        print("Channel: ", channel_name)
        print("  Active: ", stat.active_contexts, "/", stat.max_concurrent)
        print("  Queued: ", stat.queued_contexts)
        print("  Priority Mode: ", stat.priority_mode)
        print("  Total Executed: ", stat.total_executed)
```

**开发任务分解**：
- [ ] 第8周第4天：通道配置资源集成
- [ ] 第8周第4天：调度逻辑和队列处理
- [ ] 第8周第5天：优先级模式实现
- [ ] 第8周第5天：统计和调试功能
- [ ] 第8周第5天：单元测试和集成测试

**验收标准**：
- 通道调度规则正确执行
- 并发控制有效
- 优先级处理准确
- 单元测试覆盖率100%
---

## 测试计划

### 测试场景3：通道中间件并发控制测试
```gdscript
func test_channel_middleware_concurrency():
    var middleware = JuicyChannelMiddleware.new()
    
    # 设置通道配置（最大并发数为2）
    var config = JuicyChannelConfig.new()
    config.channel_name = "test"
    config.max_concurrent = 2
    middleware.set_channel_config("test", config)
    
    var contexts = []
    for i in range(3):
        var context = _create_test_context()
        context.resource.channel = "test"
        contexts.append(context)
    
    # 前两个应该成功
    assert_true(middleware.process(contexts[0], func(ctx): return true))
    assert_true(middleware.process(contexts[1], func(ctx): return true))
    
    # 第三个应该失败（超过并发限制）
    assert_false(middleware.process(contexts[2], func(ctx): return true))
```

### 测试场景4：通道配置资源序列化测试
```gdscript
func test_channel_config_serialization():
    var config = JuicyChannelConfig.new()
    config.channel_name = "test_channel"
    config.max_concurrent = 3
    config.priority_mode = JuicyMixerEnms.PriorityMode.LIFO
    config.allow_interruption = false
    config.auto_stop_previous = true
    config.description = "Test channel configuration"
    
    # 保存配置
    var temp_path = "user://temp_channel_config.tres"
    assert_true(ResourceSaver.save(config, temp_path) == OK)
    
    # 加载配置
    var loaded_config = load(temp_path) as JuicyChannelConfig
    assert_not_null(loaded_config)
    assert_eq(loaded_config.channel_name, "test_channel")
    assert_eq(loaded_config.max_concurrent, 3)
    assert_eq(loaded_config.priority_mode, JuicyMixerEnms.PriorityMode.LIFO)
    assert_eq(loaded_config.allow_interruption, false)
    assert_eq(loaded_config.auto_stop_previous, true)
    assert_eq(loaded_config.description, "Test channel configuration")
    
    # 清理
    DirAccess.remove_absolute(temp_path)
```