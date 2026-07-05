# 联觉序列化与组合系统开发计划

## 概述

本文档详细描述了JuicyMixer V3中联觉序列化与组合系统的开发计划。该系统不仅提供基础的效果序列编排和组合功能，更专注于实现**真正的联觉体验**——多感官的有机融合与动态联动。

系统的核心理念是从"容器"进化为"指挥家"，通过参数映射、事件同步和动态覆盖机制，实现一个输入驱动多个输出的高度融合感官体验。

## 系统架构

联觉序列化与组合系统由以下核心组件构成：

- **JuicySequenceResource** - 序列化资源配置（支持事件驱动）
- **JuicySequenceDriver** - 序列化执行驱动器（支持事件同步）
- **JuicyCompositeResource** - 组合资源配置（支持参数绑定）
- **JuicyCompositeDriver** - 组合效果驱动器（实现混音台功能）
- **JuicyParameterBinding** - 参数映射系统
- **JuicyResourceVariant** - 动态覆盖与继承系统

## 联觉系统的核心概念

### 1. 参数映射 (Parameter Mapping)
联觉的核心在于"通感"——一个参数驱动多个感官。通过参数绑定系统，可以实现：
- **单一输入**：如充能量值 `charge_amount` (0.0 → 1.0)
- **多输出映射**：
  - 视觉：屏幕震动强度 0 → 10
  - 听觉：音效 Pitch 0.8 → 2.0，Volume -10dB → 0dB
  - 触觉：手柄震动频率低频→高频
  - 画面：Shader Glow 强度 0 → 5

### 2. 事件同步 (Event Sync)
超越死板的时间轴，实现感官之间的互相触发：
- **音频驱动**：在音频的重音（Beat）时刻触发屏幕震动
- **事件触发**：等待特定事件信号再执行下一步
- **动态响应**：根据游戏状态实时调整效果时序

### 3. 动态覆盖与继承 (Dynamic Override & Inheritance)
实现效果的变奏和复用：
- **基础模板**：创建标准效果模板（如标准受击反馈）
- **变体覆盖**：基于模板创建变体（如火焰受击）
- **细粒度控制**：精确控制哪些参数被覆盖

## 与现有系统的集成

### Director系统扩展
- 联觉系统需要完全集成到Director的执行流程中
- 参数映射状态需要与Director的生命周期同步
- 事件同步需要通过Director进行协调

### Middleware管道增强
- 联觉Driver需要通过Middleware管道执行
- 参数映射需要支持中间件拦截和修改
- 组合Driver需要支持多种混合模式

### Context系统增强
- 联觉状态需要存储在Context中
- 参数映射的当前值需要实时更新到Context
- 事件同步状态需要与Context同步

### Driver系统协同
- 联觉Driver需要能够管理子Driver的执行
- 参数映射需要跨Driver传递参数值
- 所有Driver需要支持中断和状态还原

### 事件系统协同
- 事件同步需要与事件系统深度集成
- 联觉执行需要生成开始、进度、完成事件
- 参数映射变化需要触发相应的事件通知

## 开发时间线

**总体时间**：第11-14周（共4周）
- 第11-12周：基础序列化与组合系统
- 第13周：参数映射与事件同步系统
- 第14周：动态覆盖与继承系统，集成测试与优化

### 详细时间安排

#### 第11周：基础序列化系统
- **第1天**：JuicySequenceResource基础数据结构定义
- **第2天**：JuicySequenceResource配置参数和验证
- **第3天**：JuicySequenceDriver序列化状态管理
- **第4天**：JuicySequenceDriver顺序序列执行逻辑
- **第5天**：JuicySequenceDriver并行序列执行逻辑

#### 第12周：基础组合系统
- **第1天**：JuicyCompositeResource基础数据结构定义
- **第2天**：JuicyCompositeResource配置参数和验证
- **第3天**：JuicyCompositeDriver基础组合状态管理
- **第4天**：JuicyCompositeDriver混合模式实现
- **第5天**：基础系统单元测试和集成测试

#### 第13周：联觉系统核心功能
- **第1天**：参数绑定系统实现（JuicyCompositeResource）
- **第2天**：事件驱动系统实现（JuicySequenceResource）
- **第3天**：混音台功能实现（JuicyCompositeDriver）
- **第4天**：事件同步系统实现（JuicySequenceDriver）
- **第5天**：参数映射与事件同步集成测试

#### 第14周：动态覆盖与系统优化
- **第1天**：JuicyResourceVariant数据结构定义和覆盖模式实现
- **第2天**：属性路径解析和设置系统
- **第3天**：组合资源特殊处理和继承机制
- **第4天**：系统性能优化和内存管理
- **第5天**：完整系统集成测试和文档完善

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
enum TriggerMode {
    TIME,               # 基于时间延迟
    EVENT               # 等待特定事件
}

# 序列化项数据结构
class JuicySequenceItem:
    @export var resource: JuicyFeedbackResource
    @export var delay: float = 0.0
    @export var duration: float = -1.0  # -1表示使用资源默认持续时间
    @export var condition: String = ""   # 可选的执行条件
    @export var weight: float = 1.0       # 用于随机选择
    @export var enabled: bool = true
    
    # 事件同步系统
    @export var trigger_mode: TriggerMode = TriggerMode.TIME
    @export var trigger_event: String = ""           # 等待的事件名称（如"audio_beat_1", "explosion_peak"等）

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
- [ ] 第13周第1天：事件驱动系统实现
- [ ] 第13周第2天：单元测试和文档

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
    if current_item.trigger_mode == JuicySequenceResource.TriggerMode.TIME:
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
func _check_item_trigger_condition(context: JuicyContext, item: JuicySequenceResource.JuicySequenceItem, state: SequenceState) -> bool:
    match item.trigger_mode:
        JuicySequenceResource.TriggerMode.TIME:
            return true  # 时间触发总是满足条件
        
        JuicySequenceResource.TriggerMode.EVENT:
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

func _execute_sequence_item(context: JuicyContext, item: JuicySequenceResource.JuicySequenceItem, state: SequenceState) -> void:
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

func _create_item_context(parent_context: JuicyContext, item: JuicySequenceResource.JuicySequenceItem) -> JuicyContext:
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
- [ ] 第12周第1天：循环和随机处理
- [ ] 第13周第1天：事件同步系统实现
- [ ] 第13周第2天：事件监听器和超时处理
- [ ] 第13周第3天：单元测试和集成测试

## JuicyCompositeResource (组合资源)

**文件路径**：`addons/juicy_mixer/resources/juicy_composite_resource.gd`

**核心职责**：
- 定义效果组合的配置结构
- 支持多种混合模式
- 提供权重和条件控制
- 实现动态组合调整
- **新增**：支持参数映射系统，实现联觉体验

**详细实现计划**：

```gdscript
@tool
class_name JuicyCompositeResource
extends JuicyFeedbackResource

# 组合混合模式
enum CompositeBlendMode {
    ADDITIVE,           # 叠加
    MULTIPLICATIVE,     # 乘法
    OVERRIDE,          # 覆盖
    WEIGHTED_AVERAGE    # 加权平均
}

# 参数绑定数据结构 - 联觉系统的核心
class JuicyParameterBinding:
    @export var input_parameter: String = "intensity"  # 外部输入的参数名
    @export var target_item_index: int = 0           # 绑定到Composite中的哪个子Resource
    @export var target_property: String = ""          # 绑定到子Resource的哪个属性
    @export var curve: Curve                         # 映射曲线 (例如输入0-1，映射到输出0-100)
    @export var enabled: bool = true

# 组合项数据结构
class JuicyCompositeItem:
    @export var resource: JuicyFeedbackResource
    @export var weight: float = 1.0
    @export var condition: String = ""
    @export var enabled: bool = true
    @export var priority: int = 0

# 组合配置
@export var composite_items: Array[JuicyCompositeItem] = []
@export var blend_mode: CompositeBlendMode = CompositeBlendMode.ADDITIVE
@export var normalize_weights: bool = true
@export var dynamic_weight_adjustment: bool = false

# 联觉系统配置
@export var parameter_bindings: Array[JuicyParameterBinding] = []
@export var enable_parameter_mapping: bool = false
@export var auto_update_parameters: bool = true

func create_drivers() -> Array[JuicyDriver]:
    var driver = JuicyCompositeDriver.new()
    driver.composite_resource = self
    return [driver]

# 联觉系统：设置参数值
func set_parameter(parameter_name: String, value: float) -> void:
    if not enable_parameter_mapping:
        return
    
    # 通过参数绑定更新所有相关子资源的属性
    for binding in parameter_bindings:
        if binding.enabled and binding.input_parameter == parameter_name:
            _apply_parameter_binding(binding, value)

# 联觉系统：应用参数绑定
func _apply_parameter_binding(binding: JuicyParameterBinding, input_value: float) -> void:
    if binding.target_item_index >= composite_items.size():
        return
    
    var item = composite_items[binding.target_item_index]
    if not item.resource or binding.target_property.is_empty():
        return
    
    # 使用曲线映射输入值
    var mapped_value = binding.curve.sample(input_value)
    
    # 动态设置资源属性
    _set_resource_property(item.resource, binding.target_property, mapped_value)

# 联觉系统：动态设置资源属性
func _set_resource_property(resource: JuicyFeedbackResource, property_name: String, value: Variant) -> void:
    # 使用反射设置属性值
    if resource.has_method("set_" + property_name):
        resource.call("set_" + property_name, value)
    elif property_name in resource:
        resource.set(property_name, value)

func validate_config() -> ValidationResult:
    var result = super.validate_config()
    
    if composite_items.is_empty():
        result.valid = false
        result.issues.append("Composite items cannot be empty")
    
    # 验证参数绑定
    if enable_parameter_mapping:
        for i in range(parameter_bindings.size()):
            var binding = parameter_bindings[i]
            if binding.target_item_index >= composite_items.size():
                result.valid = false
                result.issues.append("Parameter binding target_item_index out of range at index " + str(i))
            
            if binding.target_property.is_empty():
                result.valid = false
                result.issues.append("Parameter binding target_property cannot be empty at index " + str(i))
    
    var total_weight = 0.0
    for i in range(composite_items.size()):
        var item = composite_items[i]
        if not item.resource:
            result.valid = false
            result.issues.append("Resource cannot be null at index " + str(i))
        
        if item.weight < 0.0:
            result.valid = false
            result.issues.append("Weight cannot be negative at index " + str(i))
        
        total_weight += item.weight
    
    if normalize_weights and total_weight <= 0.0:
        result.valid = false
        result.issues.append("Total weight must be greater than 0 when normalize_weights is enabled")
    
    return result
```

**开发任务分解**：
- [ ] 第12周第3天：基础组合数据结构定义
- [ ] 第12周第4天：参数绑定系统实现
- [ ] 第13周第1天：混合模式与参数映射集成
- [ ] 第13周第2天：权重和条件处理增强
- [ ] 第13周第3天：单元测试和文档

## JuicyCompositeDriver (组合驱动器)

**文件路径**：`addons/juicy_mixer/drivers/juicy_composite_driver.gd`

**核心职责**：
- 执行效果组合
- 管理混合模式和权重
- 处理动态调整
- 支持条件执行
- **新增**：实现混音台功能，支持参数映射的实时更新

**详细实现计划**：

```gdscript
class_name JuicyCompositeDriver
extends JuicyDriver

# 组合状态
class CompositeState:
    var active_contexts: Array[String] = []
    var item_weights: Dictionary = {}  # context_id -> weight
    var blend_progress: float = 0.0
    var parameter_values: Dictionary = {}  # 联觉系统：存储当前参数值

var composite_resource: JuicyCompositeResource
var _composite_states: Dictionary = {}  # context_id -> CompositeState

func _init():
    driver_name = "JuicyCompositeDriver"
    supported_properties = []  # 组合驱动器通过子Driver处理属性

func prepare(context: JuicyContext) -> void:
    var state = CompositeState.new()
    
    # 计算权重
    var total_weight = 0.0
    for item in composite_resource.composite_items:
        if item.enabled and item.resource:
            total_weight += item.weight
    
    # 创建子上下文
    for item in composite_resource.composite_items:
        if not item.enabled or not item.resource:
            continue
        
        var item_context = _create_item_context(context, item)
        var context_id = JuicyMixer.play(item.resource, context.target)
        state.active_contexts.append(context_id)
        
        # 计算标准化权重
        var normalized_weight = item.weight / total_weight if total_weight > 0 else 0.0
        if composite_resource.normalize_weights:
            state.item_weights[context_id] = normalized_weight
        else:
            state.item_weights[context_id] = item.weight
    
    # 联觉系统：初始化参数值
    if composite_resource.enable_parameter_mapping:
        _initialize_parameter_values(state)
    
    _composite_states[context.context_id] = state

func process(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
    var state = _composite_states.get(context.context_id)
    if not state:
        return
    
    # 更新混合进度
    state.blend_progress = min(state.blend_progress + delta, 1.0)
    
    # 联觉系统：实时更新参数映射
    if composite_resource.enable_parameter_mapping and composite_resource.auto_update_parameters:
        _update_parameter_mappings(context, state, delta)
    
    # 应用混合模式
    _apply_blend_mode(context, state, buffer)

# 联觉系统：设置参数值（混音台核心功能）
func set_parameter(context_id: String, parameter_name: String, value: float) -> void:
    var state = _composite_states.get(context_id)
    if not state or not composite_resource.enable_parameter_mapping:
        return
    
    # 更新参数值
    state.parameter_values[parameter_name] = value
    
    # 立即应用到资源
    composite_resource.set_parameter(parameter_name, value)
    
    # 更新所有相关的子上下文
    _update_child_contexts(state, parameter_name, value)

# 联觉系统：初始化参数值
func _initialize_parameter_values(state: CompositeState) -> void:
    for binding in composite_resource.parameter_bindings:
        if binding.enabled:
            state.parameter_values[binding.input_parameter] = 0.0

# 联觉系统：实时更新参数映射
func _update_parameter_mappings(context: JuicyContext, state: CompositeState, delta: float) -> void:
    # 这里可以根据游戏逻辑动态计算参数值
    # 例如：从游戏状态获取充能量值、伤害值等
    for parameter_name in state.parameter_values:
        var current_value = state.parameter_values[parameter_name]
        # 可以在这里添加自动更新逻辑
        # 例如：current_value = _calculate_parameter_from_game_state(parameter_name, context)
        set_parameter(context.context_id, parameter_name, current_value)

# 联觉系统：更新子上下文
func _update_child_contexts(state: CompositeState, parameter_name: String, value: float) -> void:
    for context_id in state.active_contexts:
        var item_context = JuicyMixer.get_context(context_id)
        if item_context and item_context.property_buffer:
            # 通过中间件系统更新子上下文的属性
            _update_context_parameters(item_context, parameter_name, value)

# 联觉系统：更新上下文参数
func _update_context_parameters(item_context: JuicyContext, parameter_name: String, value: float) -> void:
    # 通过PropertyBuffer更新参数
    if item_context.property_buffer:
        item_context.property_buffer.set_property(parameter_name, value)

func _apply_blend_mode(context: JuicyContext, state: CompositeState, buffer: JuicyPropertyBuffer) -> void:
    match composite_resource.blend_mode:
        JuicyCompositeResource.CompositeBlendMode.ADDITIVE:
            _apply_additive_blend(state, buffer)
        JuicyCompositeResource.CompositeBlendMode.MULTIPLICATIVE:
            _apply_multiplicative_blend(state, buffer)
        JuicyCompositeResource.CompositeBlendMode.OVERRIDE:
            _apply_override_blend(state, buffer)
        JuicyCompositeResource.CompositeBlendMode.WEIGHTED_AVERAGE:
            _apply_weighted_average_blend(state, buffer)

func _apply_additive_blend(state: CompositeState, buffer: JuicyPropertyBuffer) -> void:
    # 叠加混合模式实现
    for context_id in state.active_contexts:
        var weight = state.item_weights.get(context_id, 1.0)
        var item_context = JuicyMixer.get_context(context_id)
        if item_context and item_context.property_buffer:
            buffer.add_buffer(item_context.property_buffer, weight)

func _apply_multiplicative_blend(state: CompositeState, buffer: JuicyPropertyBuffer) -> void:
    # 乘法混合模式实现
    for context_id in state.active_contexts:
        var weight = state.item_weights.get(context_id, 1.0)
        var item_context = JuicyMixer.get_context(context_id)
        if item_context and item_context.property_buffer:
            buffer.multiply_buffer(item_context.property_buffer, weight)

func _apply_override_blend(state: CompositeState, buffer: JuicyPropertyBuffer) -> void:
    # 覆盖混合模式实现
    for context_id in state.active_contexts:
        var item_context = JuicyMixer.get_context(context_id)
        if item_context and item_context.property_buffer:
            buffer.copy_from(item_context.property_buffer)
            break  # 只使用第一个有效项

func _apply_weighted_average_blend(state: CompositeState, buffer: JuicyPropertyBuffer) -> void:
    # 加权平均混合模式实现
    var total_weight = 0.0
    for context_id in state.active_contexts:
        total_weight += state.item_weights.get(context_id, 1.0)
    
    if total_weight <= 0.0:
        return
    
    for context_id in state.active_contexts:
        var weight = state.item_weights.get(context_id, 1.0) / total_weight
        var item_context = JuicyMixer.get_context(context_id)
        if item_context and item_context.property_buffer:
            buffer.add_buffer(item_context.property_buffer, weight)

func _create_item_context(parent_context: JuicyContext, item: JuicyCompositeResource.JuicyCompositeItem) -> JuicyContext:
    var item_context = JuicyContext.create(item.resource, parent_context.target, parent_context.owner)
    item_context.time_scale = parent_context.time_scale
    return item_context

func cleanup(context: JuicyContext) -> void:
    var state = _composite_states.get(context.context_id)
    if state:
        # 停止所有活跃的子上下文
        for context_id in state.active_contexts:
            JuicyMixer.stop(context_id)
        
        _composite_states.erase(context.context_id)
```

**开发任务分解**：
- [ ] 第12周第3天：基础组合状态管理
- [ ] 第13周第1天：混音台功能实现
- [ ] 第13周第2天：参数映射实时更新系统
- [ ] 第13周第3天：混合模式与参数映射集成
- [ ] 第13周第4天：单元测试和集成测试

## JuicyResourceVariant (动态覆盖与继承系统)

**文件路径**：`addons/juicy_mixer/resources/juicy_resource_variant.gd`

**核心职责**：
- 实现效果的变奏和复用
- 支持基于模板的细粒度覆盖
- 提供类似Prefab Variant的功能
- 实现高效的资源继承机制

**详细实现计划**：

```gdscript
@tool
class_name JuicyResourceVariant
extends JuicyFeedbackResource

# 覆盖模式
enum OverrideMode {
    REPLACE,            # 完全替换
    MODIFY,             # 修改属性
    ADD_TO_COMPOSITE,   # 添加到组合中
    REMOVE_FROM_COMPOSITE # 从组合中移除
}

# 资源覆盖项
class ResourceOverride:
    @export var target_path: String = ""           # 目标资源路径（如"composite_items[0].resource"）
    @export var override_mode: OverrideMode = OverrideMode.REPLACE
    @export var new_resource: JuicyFeedbackResource  # 新资源（用于REPLACE模式）
    @export var property_overrides: Dictionary = {}   # 属性覆盖（用于MODIFY模式）
    @export var enabled: bool = true

# 变体配置
@export var base_resource: JuicyFeedbackResource  # 基础资源模板
@export var resource_overrides: Array[ResourceOverride] = []
@export var inherit_parameters: bool = true      # 是否继承参数绑定
@export var inherit_event_sync: bool = true      # 是否继承事件同步

func create_drivers() -> Array[JuicyDriver]:
    # 创建变体资源
    var variant_resource = _create_variant_resource()
    return variant_resource.create_drivers()

# 联觉系统：创建变体资源
func _create_variant_resource() -> JuicyFeedbackResource:
    if not base_resource:
        push_error("Base resource cannot be null")
        return null
    
    # 深拷贝基础资源
    var variant = base_resource.duplicate(true)
    
    # 应用覆盖
    for override in resource_overrides:
        if not override.enabled:
            continue
        
        _apply_override(variant, override)
    
    return variant

# 联觉系统：应用覆盖
func _apply_override(resource: JuicyFeedbackResource, override: ResourceOverride) -> void:
    match override.override_mode:
        OverrideMode.REPLACE:
            _apply_replace_override(resource, override)
        OverrideMode.MODIFY:
            _apply_modify_override(resource, override)
        OverrideMode.ADD_TO_COMPOSITE:
            _apply_add_to_composite_override(resource, override)
        OverrideMode.REMOVE_FROM_COMPOSITE:
            _apply_remove_from_composite_override(resource, override)

# 联觉系统：应用替换覆盖
func _apply_replace_override(resource: JuicyFeedbackResource, override: ResourceOverride) -> void:
    var target = _get_target_property(resource, override.target_path)
    if target and override.new_resource:
        _set_target_property(resource, override.target_path, override.new_resource)

# 联觉系统：应用修改覆盖
func _apply_modify_override(resource: JuicyFeedbackResource, override: ResourceOverride) -> void:
    var target = _get_target_property(resource, override.target_path)
    if target:
        for property_name in override.property_overrides:
            if property_name in target:
                target.set(property_name, override.property_overrides[property_name])

# 联觉系统：应用添加到组合覆盖
func _apply_add_to_composite_override(resource: JuicyFeedbackResource, override: ResourceOverride) -> void:
    if resource is JuicyCompositeResource and override.new_resource:
        var new_item = JuicyCompositeResource.JuicyCompositeItem.new()
        new_item.resource = override.new_resource
        resource.composite_items.append(new_item)

# 联觉系统：应用从组合移除覆盖
func _apply_remove_from_composite_override(resource: JuicyFeedbackResource, override: ResourceOverride) -> void:
    if resource is JuicyCompositeResource:
        var index = override.target_path.trim_prefix("composite_items[").trim_suffix("]").to_int()
        if index >= 0 and index < resource.composite_items.size():
            resource.composite_items.remove_at(index)

# 联觉系统：获取目标属性
func _get_target_property(resource: JuicyFeedbackResource, path: String) -> Variant:
    var parts = path.split(".")
    var current = resource
    
    for part in parts:
        if part.ends_with("]"):
            # 数组访问
            var array_parts = part.split("[")
            var array_name = array_parts[0]
            var index = array_parts[1].trim_suffix("]").to_int()
            
            if array_name in current and current[array_name] is Array:
                current = current[array_name][index]
            else:
                return null
        else:
            # 属性访问
            if part in current:
                current = current[part]
            else:
                return null
    
    return current

# 联觉系统：设置目标属性
func _set_target_property(resource: JuicyFeedbackResource, path: String, value: Variant) -> void:
    var parts = path.split(".")
    var current = resource
    
    # 导航到父级
    for i in range(parts.size() - 1):
        var part = parts[i]
        if part.ends_with("]"):
            var array_parts = part.split("[")
            var array_name = array_parts[0]
            var index = array_parts[1].trim_suffix("]").to_int()
            
            if array_name in current and current[array_name] is Array:
                current = current[array_name][index]
            else:
                return
        else:
            if part in current:
                current = current[part]
            else:
                return
    
    # 设置最终值
    var final_part = parts[-1]
    if final_part.ends_with("]"):
        var array_parts = final_part.split("[")
        var array_name = array_parts[0]
        var index = array_parts[1].trim_suffix("]").to_int()
        
        if array_name in current and current[array_name] is Array:
            current[array_name][index] = value
    else:
        if final_part in current:
            current[final_part] = value

func validate_config() -> ValidationResult:
    var result = super.validate_config()
    
    if not base_resource:
        result.valid = false
        result.issues.append("Base resource cannot be null")
    
    for i in range(resource_overrides.size()):
        var override = resource_overrides[i]
        if override.target_path.is_empty():
            result.valid = false
            result.issues.append("Override target path cannot be empty at index " + str(i))
        
        if override.override_mode == OverrideMode.REPLACE and not override.new_resource:
            result.valid = false
            result.issues.append("New resource cannot be null when override_mode is REPLACE at index " + str(i))
    
    return result
```

**开发任务分解**：
- [ ] 第14周第1天：资源变体数据结构定义
- [ ] 第14周第1天：覆盖模式实现
- [ ] 第14周第2天：属性路径解析和设置
- [ ] 第14周第3天：组合资源特殊处理
- [ ] 第14周第4天：单元测试和文档

## 性能优化

### 内存管理
- 序列化系统需要使用对象池
- 状态快照需要高效的存储机制
- 资源变体需要智能缓存机制

### 执行效率
- 序列化执行需要支持批处理
- 组合计算需要考虑性能开销
- 参数映射需要优化曲线采样

## 测试计划

### 单元测试
- JuicySequenceResource配置验证测试
- JuicySequenceDriver状态管理测试
- JuicyCompositeResource配置验证测试
- JuicyCompositeDriver混合模式测试
- JuicyResourceVariant覆盖机制测试

### 集成测试
- 序列化与组合系统集成测试
- 参数映射与事件同步集成测试
- 动态覆盖与继承系统测试
- 与Director系统集成测试
- 与Middleware系统集成测试
- 与事件系统集成测试

### 性能测试
- 1000个序列化项处理性能测试
- 1000个组合项混合性能测试
- 参数映射实时更新性能测试
- 资源变体创建和执行性能测试
- 内存使用优化验证

## 交付检查清单

### 代码交付
- [ ] JuicySequenceResource和JuicySequenceDriver
- [ ] JuicyCompositeResource和JuicyCompositeDriver
- [ ] 单元测试和集成测试
- [ ] 性能基准测试

### 文档交付
- [ ] 序列化系统使用文档
- [ ] 组合系统使用文档
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
1. **序列化复杂性**：复杂的序列化逻辑可能难以调试
   - 缓解措施：提供详细的调试信息和状态可视化

2. **组合计算性能**：复杂的混合模式可能影响性能
   - 缓解措施：实现计算缓存和批处理优化

### 进度风险
1. **混合模式实现**：多种混合模式实现可能比预期复杂
   - 缓解措施：优先实现核心混合模式，后续扩展

## 联觉系统使用示例

### 1. 参数映射示例：大招充能效果

```gdscript
# 创建一个充能效果的组合资源
var charge_composite = JuicyCompositeResource.new()

# 添加视觉效果
var visual_shake = JuicyShakeResource.new()
visual_shake.amplitude = 5.0
var visual_item = JuicyCompositeResource.JuicyCompositeItem.new()
visual_item.resource = visual_shake
visual_item.weight = 1.0

# 添加音效
var audio_effect = JuicyAudioResource.new()
audio_effect.volume_db = -10.0
var audio_item = JuicyCompositeResource.JuicyCompositeItem.new()
audio_item.resource = audio_effect
audio_item.weight = 1.0

# 添加手柄震动
var haptic_effect = JuicyHapticResource.new()
haptic_effect.frequency = 50.0
var haptic_item = JuicyCompositeResource.JuicyCompositeItem.new()
haptic_item.resource = haptic_effect
haptic_item.weight = 1.0

charge_composite.composite_items = [visual_item, audio_item, haptic_item]

# 启用参数映射
charge_composite.enable_parameter_mapping = true

# 创建参数绑定：充能量值 -> 多感官输出
var intensity_to_visual = JuicyCompositeResource.JuicyParameterBinding.new()
intensity_to_visual.input_parameter = "charge_amount"
intensity_to_visual.target_item_index = 0  # 视觉效果
intensity_to_visual.target_property = "amplitude"
intensity_to_visual.curve = preload("res://curves/charge_to_visual.tres")  # 0-1 -> 0-10

var intensity_to_audio = JuicyCompositeResource.JuicyParameterBinding.new()
intensity_to_audio.input_parameter = "charge_amount"
intensity_to_audio.target_item_index = 1  # 音效
intensity_to_audio.target_property = "volume_db"
intensity_to_audio.curve = preload("res://curves/charge_to_audio.tres")  # 0-1 -> -10到0

var intensity_to_haptic = JuicyCompositeResource.JuicyParameterBinding.new()
intensity_to_haptic.input_parameter = "charge_amount"
intensity_to_haptic.target_item_index = 2  # 手柄震动
intensity_to_haptic.target_property = "frequency"
intensity_to_haptic.curve = preload("res://curves/charge_to_haptic.tres")  # 0-1 -> 50-200

charge_composite.parameter_bindings = [intensity_to_visual, intensity_to_audio, intensity_to_haptic]

# 在游戏中使用
var context_id = JuicyMixer.play(charge_composite, player)

# 更新充能量值，所有感官会同步响应
func update_charge(amount: float):
    var driver = JuicyMixer.get_driver(context_id)
    if driver is JuicyCompositeDriver:
        driver.set_parameter(context_id, "charge_amount", amount)
```

### 2. 事件同步示例：音乐节拍驱动效果

```gdscript
# 创建一个与音乐同步的序列
var music_sync_sequence = JuicySequenceResource.new()

# 启用事件同步
music_sync_sequence.enable_event_sync = true

# 创建节拍同步的视觉效果
var beat_visual = JuicyFlashResource.new()
var beat_item = JuicySequenceResource.JuicySequenceItem.new()
beat_item.resource = beat_visual
beat_item.trigger_mode = JuicySequenceResource.TriggerMode.EVENT
beat_item.trigger_event = "music_beat_1"  # 在第一拍触发

# 创建重音同步的屏幕震动
var downbeat_shake = JuicyShakeResource.new()
var downbeat_item = JuicySequenceResource.JuicySequenceItem.new()
downbeat_item.resource = downbeat_shake
downbeat_item.trigger_mode = JuicySequenceResource.TriggerMode.EVENT
downbeat_item.trigger_event = "music_downbeat"  # 在重音触发

music_sync_sequence.sequence_items = [beat_item, downbeat_item]

# 在音频系统中触发事件
func on_music_beat(beat_type: String):
    JuicyMixer.trigger_global_event(beat_type)
```

### 3. 动态覆盖示例：火焰受击变体

```gdscript
# 创建基础受击效果
var base_hit_effect = JuicyCompositeResource.new()
# ... 配置基础受击效果（声音A + 震动A）

# 创建火焰受击变体
var fire_hit_variant = JuicyResourceVariant.new()
fire_hit_variant.base_resource = base_hit_effect

# 覆盖声音为火焰声
var fire_audio = JuicyAudioResource.new()
fire_audio.stream = preload("res://sounds/fire_hit.wav")
var sound_override = JuicyResourceVariant.ResourceOverride.new()
sound_override.target_path = "composite_items[0].resource"  # 替换第一个项（声音）
sound_override.override_mode = JuicyResourceVariant.OverrideMode.REPLACE
sound_override.new_resource = fire_audio

# 增强震动强度
var shake_override = JuicyResourceVariant.ResourceOverride.new()
shake_override.target_path = "composite_items[1].resource.amplitude"  # 修改震动幅度
shake_override.override_mode = JuicyResourceVariant.OverrideMode.MODIFY
shake_override.property_overrides = {"amplitude": 8.0}  # 增加20%震动

fire_hit_variant.resource_overrides = [sound_override, shake_override]

# 使用变体效果
var context_id = JuicyMixer.play(fire_hit_variant, enemy)
```

### 4. 复杂联觉组合示例

```gdscript
# 创建一个复杂的联觉效果序列
var complex_sequence = JuicySequenceResource.new()
complex_sequence.enable_event_sync = true

# 第一阶段：充能（参数映射驱动）
var charge_phase = JuicyCompositeResource.new()
# ... 配置充能组合效果
var charge_item = JuicySequenceResource.JuicySequenceItem.new()
charge_item.resource = charge_phase
charge_item.trigger_mode = JuicySequenceResource.TriggerMode.TIME
charge_item.delay = 0.0

# 第二阶段：爆炸（事件触发）
var explosion_phase = JuicyCompositeResource.new()
# ... 配置爆炸组合效果
var explosion_item = JuicySequenceResource.JuicySequenceItem.new()
explosion_item.resource = explosion_phase
explosion_item.trigger_mode = JuicySequenceResource.TriggerMode.EVENT
explosion_item.trigger_event = "charge_complete"

complex_sequence.sequence_items = [charge_item, explosion_item]

# 在游戏中使用
var context_id = JuicyMixer.play(complex_sequence, player)

# 充能过程中更新参数
func process_charge(delta: float):
    charge_amount = min(charge_amount + delta, 1.0)
    
    # 获取充能阶段的驱动器并更新参数
    var charge_driver = JuicyMixer.get_driver(context_id)
    if charge_driver:
        charge_driver.set_parameter(context_id, "charge_amount", charge_amount)
    
    # 充能完成时触发事件
    if charge_amount >= 1.0:
        JuicyMixer.trigger_global_event("charge_complete")
```

## 文档完善

### API参考文档

#### JuicyCompositeResource
- `set_parameter(parameter_name: String, value: float)` - 设置参数值，触发联觉映射
- `enable_parameter_mapping: bool` - 启用/禁用参数映射系统
- `parameter_bindings: Array[JuicyParameterBinding]` - 参数绑定配置数组

#### JuicySequenceResource
- `should_trigger_by_event(item: JuicySequenceItem, event_name: String) -> bool` - 检查事件触发条件
- `enable_event_sync: bool` - 启用/禁用事件同步系统
- `global_event_listeners: Array[String]` - 全局事件监听器数组

#### JuicyResourceVariant
- `_create_variant_resource() -> JuicyFeedbackResource` - 创建变体资源
- `_apply_override(resource: JuicyFeedbackResource, override: ResourceOverride)` - 应用覆盖
- `base_resource: JuicyFeedbackResource` - 基础资源模板

### 最佳实践指南

#### 参数映射最佳实践
1. **合理设计参数范围**：确保输入参数范围（通常是0-1）与输出需求匹配
2. **使用曲线映射**：利用Curve资源实现非线性映射，增强表现力
3. **避免循环依赖**：确保参数绑定不会形成循环引用
4. **性能考虑**：避免在高频更新的参数上使用复杂的曲线计算

#### 事件同步最佳实践
1. **合理设置超时**：为事件等待设置合适的超时时间，避免无限等待
2. **事件命名规范**：使用清晰、一致的事件命名约定
3. **错误处理**：为事件监听器添加适当的错误处理机制
4. **测试覆盖**：确保所有事件路径都有相应的测试覆盖

#### 动态覆盖最佳实践
1. **保持模板简洁**：基础资源应该保持简洁，只包含核心功能
2. **细粒度覆盖**：使用精确的属性路径进行覆盖，避免意外影响
3. **版本管理**：为基础资源建立版本管理机制
4. **文档记录**：详细记录每个变体的覆盖目的和效果

## 总结

联觉序列化与组合系统是JuicyMixer V3的核心创新功能，它将传统的效果编排系统进化为真正的"指挥家"系统。通过参数映射、事件同步和动态覆盖三大核心机制，实现了：

**技术突破**：
- 从"容器"到"指挥家"的架构进化
- 多感官有机融合的联觉体验
- 高度可复用的资源变体系统
- 实时参数映射和事件同步机制

**开发体验提升**：
- 直观的视觉化配置界面
- 强大的调试和状态监控工具
- 完善的验证和错误提示机制
- 丰富的使用示例和最佳实践指南

**性能优化**：
- 智能缓存和批处理机制
- 高效的状态管理和内存使用
- 可配置的性能参数和监控
- 针对不同场景的优化策略

**关键成就**：
- 实现了真正的联觉体验设计
- 提供了灵活的效果变奏机制
- 确保了高性能的实时执行
- 建立了完善的开发者工具链

联觉序列化与组合系统将为JuicyMixer V3用户提供前所未有的感官体验控制能力，使复杂的多感官效果创建变得简单直观，真正实现"牵一发而动全身"的联觉设计理念。