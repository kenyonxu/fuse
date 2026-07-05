# 联觉序列化系统开发计划

## 概述

本文档详细描述了JuicyMixer V3中联觉序列化系统的开发计划。该系统不仅提供基础的效果序列编排功能，更专注于实现**事件驱动的感官同步**，超越传统的时间轴限制，实现感官之间的互相触发。

系统的核心理念是从"死板的时间轴"进化为"智能的事件响应"，通过事件同步机制，实现基于游戏状态的动态效果触发。

## 系统架构

联觉序列化系统由以下核心组件构成：

- **JuicySequenceResource** - 序列化资源配置（支持事件驱动）
- **JuicySequenceDriver** - 序列化执行驱动器（支持事件同步）

## 联觉系统的核心概念

### 事件同步 (Event Sync)
超越死板的时间轴，实现感官之间的互相触发：
- **音频驱动**：在音频的重音（Beat）时刻触发屏幕震动
- **事件触发**：等待特定事件信号再执行下一步
- **动态响应**：根据游戏状态实时调整效果时序

## 与现有系统的集成

### Director系统扩展
- 序列化系统需要完全集成到Director的执行流程中
- 事件同步需要通过Director进行协调
- 序列化状态需要与Director的生命周期同步

### Middleware管道增强
- 序列化Driver需要通过Middleware管道执行
- 事件同步需要支持中间件拦截和修改

### Context系统增强
- 序列化状态需要存储在Context中
- 事件同步状态需要与Context同步

### Driver系统协同
- 序列化Driver需要能够管理子Driver的执行
- 所有Driver需要支持中断和状态还原

### 事件系统协同
- 事件同步需要与事件系统深度集成
- 序列化执行需要生成开始、进度、完成事件

## 开发时间线

**总体时间**：第11-13周（共3周）
- 第11周：基础序列化系统
- 第12周：事件同步系统
- 第13周：集成测试与优化

### 详细时间安排

#### 第11周：基础序列化系统
- **第1天**：JuicySequenceResource基础数据结构定义
- **第2天**：JuicySequenceResource配置参数和验证
- **第3天**：JuicySequenceDriver序列化状态管理
- **第4天**：JuicySequenceDriver顺序序列执行逻辑
- **第5天**：JuicySequenceDriver并行序列执行逻辑

#### 第12周：事件同步系统
- **第1天**：事件驱动系统实现（JuicySequenceResource）
- **第2天**：事件同步系统实现（JuicySequenceDriver）
- **第3天**：事件监听器和超时处理
- **第4天**：循环和随机处理增强
- **第5天**：单元测试和集成测试

#### 第13周：系统优化与完善
- **第1天**：性能优化和内存管理
- **第2天**：调试工具和状态可视化
- **第3天**：完整系统集成测试
- **第4天**：文档完善和使用示例
- **第5天**：代码审查和最终优化

## JuicySequenceResource (序列化资源)

**文件路径**：`addons/juicy_mixer/resources/juicy_sequence_resource.gd`

**核心职责**：
- 定义效果序列的配置结构
- 支持顺序和并行执行模式
- 提供条件执行和随机选择
- 实现循环和重复机制
- **新增**：支持事件驱动，实现感官之间的互相触发

**详细实现计划**：

```gdscript
@tool
class_name JuicySequenceResource
extends JuicyFeedbackResource

# 事件触发模式 - 联觉系统的核心
# 注意：TriggerMode和JuicySequenceItem已移至独立文件 addons/juicy_mixer/resources/sequence_item.gd

# 序列化配置
@export var sequence_items: Array[JuicySequenceItem] = []
@export var parallel: bool = false
@export var random_order: bool = false
@export var loop_sequence: bool = false
@export var loop_count: int = -1  # -1表示无限循环
@export var shuffle_items: bool = false

# 事件同步配置
@export var enable_event_sync: bool = false
@export var global_event_listeners: Array[String] = []  # 全局事件监听器
@export var event_timeout: float = 10.0  # 事件等待超时时间

func create_drivers() -> Array[JuicyDriver]:
    var driver = JuicySequenceDriver.new()
    driver.sequence_resource = self
    return [driver]

# 联觉系统：检查事件触发条件
func should_trigger_by_event(item: JuicySequenceItem, event_name: String) -> bool:
    if not enable_event_sync or item.trigger_mode != TriggerMode.EVENT:
        return false
    
    return item.trigger_event == event_name

func validate_config() -> ValidationResult:
    var result = super.validate_config()
    
    if sequence_items.is_empty():
        result.valid = false
        result.issues.append("Sequence items cannot be empty")
    
    for i in range(sequence_items.size()):
        var item = sequence_items[i]
        if not item.resource:
            result.valid = false
            result.issues.append("Resource cannot be null at index " + str(i))
        
        if item.duration < -1.0:
            result.valid = false
            result.issues.append("Duration cannot be less than -1 at index " + str(i))
        
        if item.weight < 0.0:
            result.valid = false
            result.issues.append("Weight cannot be negative at index " + str(i))
        
        # 验证事件同步配置
        if enable_event_sync:
            if item.trigger_mode == TriggerMode.EVENT and item.trigger_event.is_empty():
                result.valid = false
                result.issues.append("Trigger event cannot be empty when trigger_mode is EVENT at index " + str(i))
    
    return result
```

**开发任务分解**：
- [ ] 第11周第1天：基础序列化数据结构定义
- [ ] 第11周第1天：配置参数和验证
- [ ] 第12周第1天：事件驱动系统实现
- [ ] 第12周第2天：单元测试和文档

## JuicySequenceDriver (序列化驱动器)

**文件路径**：`addons/juicy_mixer/drivers/juicy_sequence_driver.gd`

**核心职责**：
- 执行效果序列
- 管理序列状态和进度
- 处理条件执行和随机选择
- 支持循环和重复机制
- **新增**：实现事件同步，支持感官之间的互相触发

**详细实现计划**：

```gdscript
class_name JuicySequenceDriver
extends JuicyDriver

# 序列化状态
class SequenceState:
    var current_index: int = 0
    var item_start_time: float = 0.0
    var completed_items: Array[int] = []
    var active_contexts: Array[String] = []
    var loop_count: int = 0
    var is_paused: bool = false
    var waiting_events: Dictionary = {}  # 联觉系统：等待的事件 item_index -> event_name
    var event_start_times: Dictionary = {}  # 联觉系统：事件开始时间

var sequence_resource: JuicySequenceResource
var _sequence_states: Dictionary = {}  # context_id -> SequenceState

func _init():
    driver_name = "JuicySequenceDriver"
    supported_properties = []  # 序列化驱动器不直接处理属性

func prepare(context: JuicyContext) -> void:
    var state = SequenceState.new()
    state.current_index = 0
    state.item_start_time = Time.get_ticks_msec() / 1000.0
    
    # 联觉系统：注册全局事件监听器
    if sequence_resource.enable_event_sync:
        _register_event_listeners(context, state)
    
    _sequence_states[context.context_id] = state

func process(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
    var state = _sequence_states.get(context.context_id)
    if not state:
        return
    
    # 联觉系统：检查事件超时
    if sequence_resource.enable_event_sync:
        _check_event_timeouts(state)
    
    if sequence_resource.parallel:
        _process_parallel_sequence(context, state, delta)
    else:
        _process_sequential_sequence(context, state, delta)

func _process_sequential_sequence(context: JuicyContext, state: SequenceState, delta: float) -> void:
    if state.current_index >= sequence_resource.sequence_items.size():
        return
    
    var current_item = sequence_resource.sequence_items[state.current_index]
    
    # 联觉系统：检查事件触发条件
    if sequence_resource.enable_event_sync:
        if not _check_item_trigger_condition(context, current_item, state):
            return
    
    # 检查延迟（仅对时间触发模式有效）
    if current_item.trigger_mode == TriggerMode.TIME:
        if state.item_start_time + current_item.delay > Time.get_ticks_msec() / 1000.0:
            return
    
    # 执行当前项
    if state.active_contexts.is_empty():
        _execute_sequence_item(context, current_item, state)
    
    # 检查当前项是否完成
    var item_completed = _check_item_completed(state.active_contexts)
    if item_completed:
        state.completed_items.append(state.current_index)
        state.current_index += 1
        state.active_contexts.clear()
        state.item_start_time = Time.get_ticks_msec() / 1000.0
        
        # 联觉系统：清除等待的事件
        if sequence_resource.enable_event_sync:
            state.waiting_events.erase(state.current_index - 1)
        
        # 检查序列是否完成
        if state.current_index >= sequence_resource.sequence_items.size():
            if sequence_resource.loop_sequence:
                _handle_sequence_loop(context, state)
            else:
                context.complete()

func _process_parallel_sequence(context: JuicyContext, state: SequenceState, delta: float) -> void:
    # 并行执行所有项
    if state.active_contexts.is_empty():
        for i in range(sequence_resource.sequence_items.size()):
            var item = sequence_resource.sequence_items[i]
            if _should_execute_item(item, context):
                # 联觉系统：检查事件触发条件
                if sequence_resource.enable_event_sync:
                    if not _check_item_trigger_condition(context, item, state):
                        continue
                
                _execute_sequence_item(context, item, state)
    
    # 检查所有项是否完成
    var all_completed = true
    for context_id in state.active_contexts:
        var item_context = JuicyMixer.get_context(context_id)
        if not item_context or not item_context.is_completed:
            all_completed = false
            break
    
    if all_completed:
        if sequence_resource.loop_sequence:
            _handle_sequence_loop(context, state)
        else:
            context.complete()

# 联觉系统：检查项目触发条件
func _check_item_trigger_condition(context: JuicyContext, item: JuicySequenceItem, state: SequenceState) -> bool:
    match item.trigger_mode:
        TriggerMode.TIME:
            return true  # 时间触发总是满足条件
        
        TriggerMode.EVENT:
            # 检查是否已经等待这个事件
            if state.waiting_events.has(state.current_index):
                # 检查事件是否已经触发
                return _has_event_triggered(item.trigger_event, context)
            else:
                # 开始等待事件
                state.waiting_events[state.current_index] = item.trigger_event
                state.event_start_times[state.current_index] = Time.get_ticks_msec() / 1000.0
                return false
    
    return false

# 联觉系统：检查事件是否已触发
func _has_event_triggered(event_name: String, context: JuicyContext) -> bool:
    # 这里需要与事件系统集成
    # 可以通过检查事件缓冲区或事件调度器来判断
    return false  # 临时返回，需要实际实现

# 联觉系统：检查事件超时
func _check_event_timeouts(state: SequenceState) -> void:
    var current_time = Time.get_ticks_msec() / 1000.0
    
    for item_index in state.event_start_times.keys():
        var start_time = state.event_start_times[item_index]
        if current_time - start_time > sequence_resource.event_timeout:
            # 事件超时，跳过该项
            state.waiting_events.erase(item_index)
            state.event_start_times.erase(item_index)
            state.completed_items.append(item_index)

# 联觉系统：注册事件监听器
func _register_event_listeners(context: JuicyContext, state: SequenceState) -> void:
    for event_name in sequence_resource.global_event_listeners:
        # 这里需要与事件系统集成
        # 例如：JuicyMixer.get_event_scheduler().register_listener(event_name, context)
        pass

func _execute_sequence_item(context: JuicyContext, item: JuicySequenceItem, state: SequenceState) -> void:
    if not item.enabled or not item.resource:
        return
    
    # 创建子上下文
    var item_context = _create_item_context(context, item)
    var context_id = JuicyMixer.play(item.resource, context.target)
    state.active_contexts.append(context_id)

func _check_item_completed(context_ids: Array[String]) -> bool:
    for context_id in context_ids:
        var item_context = JuicyMixer.get_context(context_id)
        if not item_context or not item_context.is_completed:
            return false
    return true

func _handle_sequence_loop(context: JuicyContext, state: SequenceState) -> void:
    state.loop_count += 1
    
    if sequence_resource.loop_count > 0 and state.loop_count >= sequence_resource.loop_count:
        context.complete()
    else:
        # 重置序列状态
        state.current_index = 0
        state.completed_items.clear()
        state.active_contexts.clear()
        
        # 联觉系统：清除等待的事件
        if sequence_resource.enable_event_sync:
            state.waiting_events.clear()
            state.event_start_times.clear()
        
        # 如果启用随机顺序，重新排序
        if sequence_resource.random_order:
            _shuffle_sequence_items()

func _create_item_context(parent_context: JuicyContext, item: JuicySequenceItem) -> JuicyContext:
    var item_context = JuicyContext.create(item.resource, parent_context.target, parent_context.owner)
    item_context.time_scale = parent_context.time_scale
    return item_context

func _shuffle_sequence_items() -> void:
    var items = sequence_resource.sequence_items
    for i in range(items.size() - 1, 0, -1):
        var j = randi() % (i + 1)
        items.swap(i, j)

func cleanup(context: JuicyContext) -> void:
    var state = _sequence_states.get(context.context_id)
    if state:
        # 停止所有活跃的子上下文
        for context_id in state.active_contexts:
            JuicyMixer.stop(context_id)
        
        # 联觉系统：注销事件监听器
        if sequence_resource.enable_event_sync:
            _unregister_event_listeners(context)
        
        _sequence_states.erase(context.context_id)

# 联觉系统：注销事件监听器
func _unregister_event_listeners(context: JuicyContext) -> void:
    for event_name in sequence_resource.global_event_listeners:
        # 这里需要与事件系统集成
        # 例如：JuicyMixer.get_event_scheduler().unregister_listener(event_name, context)
        pass
```

**开发任务分解**：
- [ ] 第11周第3天：基础序列化状态管理
- [ ] 第11周第4天：顺序序列执行逻辑
- [ ] 第11周第5天：并行序列执行逻辑
- [ ] 第12周第1天：事件同步系统实现
- [ ] 第12周第2天：事件监听器和超时处理
- [ ] 第12周第3天：单元测试和集成测试

## 性能优化

### 内存管理
- 序列化系统需要使用对象池
- 状态快照需要高效的存储机制

### 执行效率
- 序列化执行需要支持批处理
- 事件检查需要优化算法

## 测试计划

### 单元测试
- JuicySequenceResource配置验证测试
- JuicySequenceDriver状态管理测试
- 事件同步机制测试

### 集成测试
- 序列化系统集成测试
- 与Director系统集成测试
- 与Middleware系统集成测试
- 与事件系统集成测试

### 性能测试
- 1000个序列化项处理性能测试
- 事件同步响应时间测试
- 内存使用优化验证

## 交付检查清单

### 代码交付
- [ ] JuicySequenceResource和JuicySequenceDriver
- [ ] 单元测试和集成测试
- [ ] 性能基准测试

### 文档交付
- [ ] 序列化系统使用文档
- [ ] API参考文档
- [ ] 性能优化指南

### 验收标准
- [ ] 所有单元测试通过（覆盖率100%）
- [ ] 所有集成测试通过
- [ ] 性能基准测试达标
- [ ] 代码审查通过
- [ ] 文档完整准确



## 事件同步使用示例

### 角色动作状态驱动模拟
在这案例中，我们通过模拟游戏中角色动作触发的事件来驱动序列化系统中的反馈. 

1. 在测试场景中，依次通过juicy_event发出event name为jump_start和jump_end的custom event
2. 分别创建连个sequence item用于监听这两个event
3. 测试对应的sequence item的触发


```

## 总结

联觉序列化系统是JuicyMixer V3的核心创新功能之一，它将传统的基于时间轴的序列系统升级为智能的事件驱动系统。通过事件同步机制，实现了：

**技术突破**：
- 从"死板时间轴"到"智能事件响应"的架构进化
- 基于游戏状态的动态效果触发
- 感官之间的有机联动和同步
- 高效的事件管理和超时处理机制

**开发体验提升**：
- 直观的事件配置界面
- 强大的事件调试和监控工具
- 完善的事件验证和错误提示
- 丰富的事件驱动使用示例

**性能优化**：
- 智能的事件缓存和批处理
- 高效的状态管理和内存使用
- 可配置的事件超时和重试机制
- 针对不同场景的优化策略

联觉序列化系统将为JuicyMixer V3用户提供前所未有的动态效果控制能力，使基于游戏状态的智能效果响应变得简单直观。

## 附录：独立类定义

### JuicySequenceItem 类定义

**文件路径**：`addons/juicy_mixer/resources/sequence_item.gd`

```gdscript
@tool
class_name JuicySequenceItem
extends Resource

# 事件触发模式枚举
enum TriggerMode {
	TIME,    # 基于时间的延迟触发
	EVENT,   # 基于事件的触发
	AUDIO_BEAT  # 基于音频节拍的触发
}

# 序列化项数据结构
@export var resource: JuicyFeedbackResource
@export var delay: float = 0.0
@export var duration: float = -1.0  # -1表示使用资源默认持续时间
@export var condition: String = ""   # 可选的执行条件
@export var weight: float = 1.0       # 用于随机选择
@export var enabled: bool = true

# 事件同步相关
@export var trigger_mode: TriggerMode = TriggerMode.TIME
@export var trigger_event: String = ""  # 等待的事件名称
@export var audio_beat_pattern: String = ""  # 音频节拍模式（如 "1,3" 表示第1和第3拍）

# 验证序列项配置
func validate_item() -> String:
	if not resource:
		return "Resource cannot be null"
	
	if duration < -1.0:
		return "Duration cannot be less than -1"
	
	if weight < 0.0:
		return "Weight cannot be negative"
	
	if trigger_mode == TriggerMode.EVENT and trigger_event.is_empty():
		return "Trigger event cannot be empty when trigger_mode is EVENT"
	
	return ""  # 验证通过

# 获取项的描述信息
func get_description() -> String:
	var desc = resource.resource_path if resource else "None"
	desc += " (delay: %.2fs, duration: %.2fs)" % [delay, duration]
	
	match trigger_mode:
		TriggerMode.TIME:
			desc += " [time trigger]"
		TriggerMode.EVENT:
			desc += " [event: %s]" % trigger_event
		TriggerMode.AUDIO_BEAT:
			desc += " [beat: %s]" % audio_beat_pattern
	
	if not condition.is_empty():
		desc += " [condition: %s]" % condition
	
	return desc

# 检查是否应该执行此项
func should_execute(context: JuicyContext) -> bool:
	if not enabled or not resource:
		return false
	
	if not condition.is_empty():
		# 这里可以添加条件表达式解析逻辑
		# 例如：return context.evaluate_expression(condition)
		pass
	
	return true

# 获取实际持续时间
func get_actual_duration() -> float:
	if duration >= 0.0:
		return duration
	
	# 使用资源的默认持续时间
	if resource and resource.has_method("get_duration"):
		return resource.get_duration()
	
	return 1.0  # 默认持续时间
```