# JuicyMixer API 快速参考

## 核心API

### JuicyMixer 静态方法

#### 播放控制
```gdscript
# 播放效果
static func play(resource: Object, target: Node, owner: Node = null) -> String

# 停止效果
static func stop(context_id: String) -> bool

# 暂停效果
static func pause(context_id: String) -> bool

# 恢复效果
static func resume(context_id: String) -> bool

# 停止所有效果
static func stop_all() -> void
```

#### 批处理
```gdscript
# 批量播放
static func play_batch(resources: Array, targets: Array) -> Array
```

#### 查询方法
```gdscript
# 获取上下文
static func get_context(context_id: String) -> Object

# 获取调度器
static func get_director() -> JuicyDirector

# 检查上下文是否活跃
static func is_context_active(context_id: String) -> bool

# 获取活跃上下文数量
static func get_active_contexts_count() -> int
```

#### 性能监控
```gdscript
# 获取性能指标
static func get_performance_metrics() -> Dictionary

# 获取缓冲区统计
static func get_buffer_stats() -> Dictionary
```

### 事件系统API

#### 事件操作
```gdscript
# 添加事件
static func add_event(event: Object) -> bool

# 移除事件
static func remove_event(event_id: String) -> bool

# 处理事件
static func process_events(delta: float) -> int

# 获取事件缓冲区统计
static func get_event_buffer_stats() -> Dictionary
```

#### 事件播放
```gdscript
# 播放事件
static func play_event(event: Object, target: Node, owner: Node = null) -> String

# 向上下文添加事件
static func add_event_to_context(context_id: String, event: Object) -> bool
```

### 中间件系统API

#### 中间件管理
```gdscript
# 获取中间件管道
static func get_middleware_pipeline() -> Object

# 添加中间件
static func add_middleware(middleware: Object) -> bool

# 移除中间件
static func remove_middleware(middleware_name: String) -> bool

# 获取中间件
static func get_middleware(middleware_name: String) -> Object

# 获取所有中间件
static func get_all_middleware() -> Array
```

#### 中间件控制
```gdscript
# 启用中间件
static func enable_middleware(middleware_name: String) -> bool

# 禁用中间件
static func disable_middleware(middleware_name: String) -> bool

# 获取中间件性能统计
static func get_middleware_performance_stats() -> Dictionary
```

### 池化系统API

#### 池管理
```gdscript
# 获取池管理器
static func get_pool_manager() -> JuicyPoolManager

# 获取池统计
static func get_pool_statistics() -> Dictionary

# 获取池效率评分
static func get_pool_efficiency_score() -> float

# 预热池
static func warm_up_pools() -> void

# 清空所有池
static func clear_all_pools() -> void
```

### 中断系统API

#### 中断控制
```gdscript
# 获取中断状态
static func get_interruption_state(target: Node) -> Object

# 设置通道中断配置
static func set_channel_interruption_config(channel: String, config: ChannelInterruptionConfig) -> bool

# 获取通道中断配置
static func get_channel_interruption_config(channel: String) -> ChannelInterruptionConfig

# 设置全局中断策略
static func set_global_interruption_policy(policy: JuicyMixerEnums.InterruptionPolicy) -> bool
```

#### 中断历史
```gdscript
# 获取中断历史
static func get_interruption_history(target: Node, max_entries: int = 100) -> Array

# 清除中断历史
static func clear_interruption_history(target: Node) -> bool

# 获取中断统计
static func get_interruption_stats() -> Dictionary

# 设置资源中断优先级
static func set_resource_interruption_priority(resource_type: String, priority: int) -> bool

# 回放中断历史
static func replay_interruption_history(target: Node, from_timestamp: float = 0.0) -> bool
```

## 核心类

### JuicySequenceResource

#### 属性
```gdscript
var sequence_items: Array[JuicySequenceItem] = []
var parallel: bool = false
var random_order: bool = false
var loop_sequence: bool = false
var loop_count: int = -1
var shuffle_items: bool = false

# 事件同步
var enable_event_sync: bool = false
var global_event_listeners: Array[String] = []
var event_timeout: float = 10.0
```

#### 方法
```gdscript
# 创建驱动器
func create_drivers() -> Array

# 获取持续时间
func get_duration() -> float

# 验证配置
func validate_config() -> ValidationResult

# 获取序列类型
func get_sequence_type() -> String

# 获取事件同步状态
func get_event_sync_status() -> String

# 获取配置摘要
func get_summary() -> String
```

### JuicySequenceItem

#### 属性
```gdscript
var resource: JuicyFeedbackResource
var delay: float = 0.0
var duration: float = -1.0
var condition: String = ""
var weight: float = 1.0
var enabled: bool = true

# 触发模式
var trigger_mode: TriggerMode = TriggerMode.TIME
var trigger_event: String = ""
```

#### 方法
```gdscript
# 验证配置
func validate() -> Array[String]

# 检查是否有效
func is_valid() -> bool

# 获取配置摘要
func get_summary() -> String
```

#### 触发模式枚举
```gdscript
enum TriggerMode {
    TIME,    # 基于时间延迟
    EVENT    # 等待特定事件
}
```

### JuicyEvent

#### 静态工厂方法
```gdscript
# 创建音频播放事件
static func create_audio_play_event(name: String, target: Node, audio_stream: AudioStream, 
                                position: Vector2 = Vector2.ZERO, volume: float = 1.0) -> JuicyEvent

# 创建粒子生成事件
static func create_particle_spawn_event(name: String, target: Node, particle_scene: PackedScene,
                                   amount: int = 10, position: Vector2 = Vector2.ZERO) -> JuicyEvent

# 创建UI更新事件
static func create_ui_update_event(name: String, target: Node, property: String, value: Variant) -> JuicyEvent

# 创建屏幕震动事件
static func create_screen_shake_event(name: String, target: Node, intensity: float = 1.0, 
                                  duration: float = 0.5) -> JuicyEvent

# 创建震动事件
static func create_vibration_event(name: String, target: Node, intensity: float = 1.0, 
                               duration: float = 0.5) -> JuicyEvent

# 创建自定义事件
static func create_custom_event(name: String, target: Node, custom_data: Dictionary) -> JuicyEvent
```

#### 事件类型枚举
```gdscript
enum EventType {
    AUDIO_PLAY,        # 音频播放
    AUDIO_STOP,        # 音频停止
    PARTICLE_SPAWN,    # 粒子生成
    PARTICLE_STOP,      # 粒子停止
    UI_UPDATE,         # UI更新
    SCREEN_SHAKE,      # 屏幕震动
    VIBRATION,         # 手柄震动
    INTERRUPTION_OCCURRED,     # 中断发生
    INTERRUPTION_RESOLVED,     # 中断解决
    TRANSITION_STARTED,        # 过渡开始
    TRANSITION_COMPLETED,      # 过渡完成
    CUSTOM_EVENT       # 自定义事件
}
```

### JuicyContext

#### 属性
```gdscript
var resource: JuicyFeedbackResource
var target: Node
var owner: Node

# 运行时状态
var progress: float = 0.0
var time_scale: float = 1.0
var is_active: bool = false
var is_paused: bool = false
var is_completed: bool = false
var start_time: float = 0.0
var current_time: float = 0.0
var duration: float = 0.0

# 序列化支持
var item_index: int = -1
```

#### 方法
```gdscript
# 静态工厂方法
static func create(resource: JuicyFeedbackResource, target: Node, owner: Node = null) -> JuicyContext

# 驱动器数据访问
func get_driver_data(driver_type: String) -> Variant
func set_driver_data(driver_type: String, data: Variant) -> void

# 属性覆盖
func get_property_override(property: String, default: Variant) -> Variant
func set_property_override(property: String, value: Variant) -> void

# 中间件数据访问
func get_middleware_data(middleware_name: String, key: String, default: Variant = null) -> Variant
func set_middleware_data(middleware_name: String, key: String, value: Variant) -> void

# 事件API
func add_event(event: Variant) -> bool
func get_events() -> Array

# 生命周期
func activate() -> void
func update(delta: float) -> void
func pause() -> void
func resume() -> void
func complete() -> void
func reset() -> void
```

## 常用模式

### 基础序列播放
```gdscript
# 创建序列
var sequence = JuicySequenceResource.new()
var item = JuicySequenceItem.new()
item.resource = preload("res://effects/punch.tres")
item.delay = 0.0
sequence.sequence_items = [item]

# 播放序列
var context_id = JuicyMixer.play(sequence, target_node)

# 停止序列
JuicyMixer.stop(context_id)
```

### 事件驱动序列
```gdscript
# 创建事件驱动序列
var sequence = JuicySequenceResource.new()
sequence.enable_event_sync = true
sequence.global_event_listeners = ["player_jump"]

var item = JuicySequenceItem.new()
item.resource = preload("res://effects/jump.tres")
item.trigger_mode = JuicySequenceItem.TriggerMode.EVENT
item.trigger_event = "player_jump"

sequence.sequence_items = [item]

# 播放序列
JuicyMixer.play(sequence, player_node)

# 发送事件触发序列
var jump_event = JuicyEvent.create_custom_event("player_jump", player_node, {})
JuicyMixer.add_event(jump_event)
```

### 并行序列
```gdscript
# 创建并行序列
var sequence = JuicySequenceResource.new()
sequence.parallel = true

# 添加多个同时执行的效果
var shake_item = JuicySequenceItem.new()
shake_item.resource = preload("res://effects/screen_shake.tres")

var sound_item = JuicySequenceItem.new()
sound_item.resource = preload("res://effects/explosion_sound.tres")

var particle_item = JuicySequenceItem.new()
particle_item.resource = preload("res://effects/explosion_particles.tres")

sequence.sequence_items = [shake_item, sound_item, particle_item]

# 播放序列
JuicyMixer.play(sequence, target_node)
```

### 循环序列
```gdscript
# 创建循环序列
var sequence = JuicySequenceResource.new()
sequence.loop_sequence = true
sequence.loop_count = 3  # 循环3次

var item = JuicySequenceItem.new()
item.resource = preload("res://effects/pulse.tres")
item.duration = 1.0

sequence.sequence_items = [item]

# 播放序列
JuicyMixer.play(sequence, target_node)
```

### 性能监控
```gdscript
# 获取性能指标
var metrics = JuicyMixer.get_performance_metrics()
print("活跃上下文: ", JuicyMixer.get_active_contexts_count())

# 获取池统计
var pool_stats = JuicyMixer.get_pool_statistics()
print("池效率: ", JuicyMixer.get_pool_efficiency_score())

# 获取中间件性能
var middleware_stats = JuicyMixer.get_middleware_performance_stats()
print("中间件统计: ", middleware_stats)
```

### 错误处理
```gdscript
# 安全播放函数
func safe_play_sequence(sequence: JuicySequenceResource, target: Node) -> String:
    # 验证序列
    if not sequence:
        push_error("序列资源为空")
        return ""
    
    var validation = sequence.validate_config()
    if not validation.valid:
        push_error("序列验证失败: " + str(validation.issues))
        return ""
    
    # 验证目标
    if not target or not is_instance_valid(target):
        push_error("目标节点无效")
        return ""
    
    # 播放序列
    var context_id = JuicyMixer.play(sequence, target)
    if context_id.is_empty():
        push_error("序列播放失败")
        return ""
    
    return context_id
```

## 调试技巧

### 监控序列状态
```gdscript
func monitor_sequence(context_id: String):
    var context = JuicyMixer.get_context(context_id)
    if context:
        print("进度: ", context.progress * 100, "%")
        print("活跃: ", context.is_active)
        print("完成: ", context.is_completed)
```

### 调试事件系统
```gdscript
func debug_events():
    var event_stats = JuicyMixer.get_event_buffer_stats()
    print("事件统计: ", event_stats)
    
    # 手动处理事件
    var processed_count = JuicyMixer.process_events(get_process_delta_time())
    print("处理的事件数: ", processed_count)
```

### 性能分析
```gdscript
func analyze_performance():
    var metrics = JuicyMixer.get_performance_metrics()
    var pool_stats = JuicyMixer.get_pool_statistics()
    var middleware_stats = JuicyMixer.get_middleware_performance_stats()
    
    print("=== 性能分析 ===")
    print("活跃上下文: ", metrics.get("active_contexts", 0))
    print("池效率: ", JuicyMixer.get_pool_efficiency_score())
    print("中间件性能: ", middleware_stats)
```

## 最佳实践

### 资源管理
```gdscript
# 预加载常用序列
class SequenceLibrary:
    static var attack_sequences: Dictionary = {}
    static var ui_sequences: Dictionary = {}
    
    static func _init():
        attack_sequences["light"] = preload("res://sequences/light_attack.tres")
        attack_sequences["heavy"] = preload("res://sequences/heavy_attack.tres")
        ui_sequences["button_click"] = preload("res://sequences/button_click.tres")
```

### 生命周期管理
```gdscript
# 自动清理序列
class SequenceManager extends Node:
    var active_sequences: Array[String] = []
    
    func play_sequence(sequence: JuicySequenceResource, target: Node) -> String:
        var context_id = JuicyMixer.play(sequence, target)
        if not context_id.is_empty():
            active_sequences.append(context_id)
        return context_id
    
    func _exit_tree():
        for context_id in active_sequences:
            JuicyMixer.stop(context_id)
        active_sequences.clear()
```

### 错误处理
```gdscript
# 带错误检查的播放
func safe_play(resource: JuicyFeedbackResource, target: Node) -> String:
    if not resource:
        push_error("资源为空")
        return ""
    
    if not target or not is_instance_valid(target):
        push_error("目标无效")
        return ""
    
    var context_id = JuicyMixer.play(resource, target)
    if context_id.is_empty():
        push_error("播放失败")
    
    return context_id
```

这个快速参考指南提供了JuicyMixer序列系统的核心API和常用模式，帮助开发者快速查找和使用系统功能。