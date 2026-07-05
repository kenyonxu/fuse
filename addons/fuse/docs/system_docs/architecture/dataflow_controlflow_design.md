# 数据流和控制流详细设计

## 目录
1. [数据流设计](#1-数据流设计)
2. [控制流设计](#2-控制流设计)
3. [执行引擎](#3-执行引擎)
4. [异步处理机制](#4-异步处理机制)
5. [错误处理和恢复](#5-错误处理和恢复)
6. [性能优化策略](#6-性能优化策略)

---

## 1. 数据流设计

### 1.1 数据流概述

数据流是可视化编程系统中数据在各个组件之间传递的路径和机制。设计原则包括：

- **类型安全**：确保数据传递的类型安全
- **上下文隔离**：不同执行上下文之间的数据隔离
- **高效传递**：最小化数据复制和转换开销
- **可追踪性**：支持数据流的追踪和调试

### 1.2 数据流架构

```mermaid
graph TB
    subgraph "数据源 (Data Sources)"
        TriggerData[触发器数据]
        InputData[输入数据]
        SensorData[传感器数据]
        ExternalData[外部数据]
    end
    
    subgraph "数据处理 (Data Processing)"
        ContextProcessor[上下文处理器]
        DataTransformer[数据转换器]
        DataValidator[数据验证器]
        DataFilter[数据过滤器]
    end
    
    subgraph "数据存储 (Data Storage)"
        LocalVars[局部变量]
        TriggerVars[触发器变量]
        GlobalVars[全局变量]
        TempData[临时数据]
    end
    
    subgraph "数据消费 (Data Consumers)"
        Instructions[指令系统]
        Conditions[条件系统]
        Actions[动作系统]
        UIComponents[UI组件]
    end
    
    TriggerData --> ContextProcessor
    InputData --> ContextProcessor
    SensorData --> ContextProcessor
    ExternalData --> ContextProcessor
    
    ContextProcessor --> DataTransformer
    DataTransformer --> DataValidator
    DataValidator --> DataFilter
    
    DataFilter --> LocalVars
    DataFilter --> TriggerVars
    DataFilter --> GlobalVars
    DataFilter --> TempData
    
    LocalVars --> Instructions
    TriggerVars --> Conditions
    GlobalVars --> Actions
    TempData --> UIComponents
```

### 1.3 执行上下文系统

```gdscript
@tool
class_name ExecutionContext extends RefCounted

## 上下文配置
class ContextConfig:
    var enable_data_tracking: bool = false
    var enable_performance_monitoring: bool = false
    var enable_debug_logging: bool = false
    var max_data_history: int = 100

## 上下文数据
var trigger: BaseTrigger
var target: Node
var local_variables: Dictionary = {}
var global_variables: VariableContainer
var temporary_data: Dictionary = {}
var data_history: Array[Dictionary] = []

## 执行状态
var execution_id: String
var start_time: float
var current_time: float
var is_cancelled: bool = false
var cancellation_reason: String = ""

## 性能监控
var performance_data: Dictionary = {}
var memory_usage: Array[float] = []

## 信号
signal data_changed(key: String, old_value: Variant, new_value: Variant)
signal context_cancelled(reason: String)
signal execution_completed

## 配置
var config: ContextConfig

func _init(trigger_node: BaseTrigger = null, target_node: Node = null, context_config: ContextConfig = null):
    trigger = trigger_node
    target = target_node
    config = context_config if context_config else ContextConfig.new()
    
    execution_id = _generate_execution_id()
    start_time = Time.get_ticks_msec() / 1000.0
    current_time = start_time
    
    # 初始化全局变量容器
    global_variables = VariableManager.get_global_variables()

## 生成执行ID
func _generate_execution_id() -> String:
    return "exec_%d_%d" % [Time.get_ticks_msec(), randi()]

## 获取变量值（支持作用域链）
func get_variable(name: String, default_value = null) -> Variant:
    var value = null
    
    # 1. 检查临时数据
    if temporary_data.has(name):
        value = temporary_data[name]
    
    # 2. 检查局部变量
    elif local_variables.has(name):
        value = local_variables[name]
    
    # 3. 检查触发器变量
    elif trigger and trigger.local_variables and trigger.local_variables.has(name):
        value = trigger.local_variables.get(name)
    
    # 4. 检查全局变量
    elif global_variables and global_variables.has(name):
        value = global_variables.get(name)
    
    # 5. 返回默认值
    else:
        value = default_value
    
    # 记录数据访问
    if config.enable_data_tracking:
        _record_data_access(name, value)
    
    return value

## 设置变量值（智能作用域选择）
func set_variable(name: String, value: Variant, scope: String = "auto") -> bool:
    var old_value = get_variable(name)
    var success = false
    
    match scope:
        "local":
            local_variables[name] = value
            success = true
        "trigger":
            if trigger and trigger.local_variables:
                success = trigger.local_variables.set(name, value)
        "global":
            if global_variables:
                success = global_variables.set(name, value)
        "temporary":
            temporary_data[name] = value
            success = true
        "auto":  # 自动选择最佳作用域
            success = _auto_assign_variable_scope(name, value)
        _:
            push_error("Invalid variable scope: %s" % scope)
            return false
    
    if success:
        # 记录数据变化
        if config.enable_data_tracking:
            _record_data_change(name, old_value, value, scope)
        
        # 发出变化信号
        data_changed.emit(name, old_value, value)
        
        # 性能监控
        if config.enable_performance_monitoring:
            _update_performance_metrics(name, value)
    
    return success

## 自动分配变量作用域
func _auto_assign_variable_scope(name: String, value: Variant) -> bool:
    # 优先级：临时 > 局部 > 触发器 > 全局
    
    # 如果变量名以"temp_"开头，分配到临时作用域
    if name.begins_with("temp_"):
        temporary_data[name] = value
        return true
    
    # 如果变量是基础类型且值较小，分配到局部作用域
    if _is_simple_type(value) and _is_small_value(value):
        local_variables[name] = value
        return true
    
    # 如果变量已存在于某个作用域，更新该作用域
    if local_variables.has(name):
        local_variables[name] = value
        return true
    elif trigger and trigger.local_variables and trigger.local_variables.has(name):
        return trigger.local_variables.set(name, value)
    elif global_variables and global_variables.has(name):
        return global_variables.set(name, value)
    
    # 默认分配到局部作用域
    local_variables[name] = value
    return true

## 检查是否为简单类型
func _is_simple_type(value: Variant) -> bool:
    return value is bool or value is int or value is float or value is String

## 检查是否为小值
func _is_small_value(value: Variant) -> bool:
    if value is String:
        return (value as String).length() < 100
    elif value is Array:
        return (value as Array).size() < 10
    elif value is Dictionary:
        return (value as Dictionary).size() < 10
    return true

## 记录数据访问
func _record_data_access(name: String, value: Variant):
    var access_record = {
        "type": "access",
        "variable_name": name,
        "value": value,
        "timestamp": Time.get_ticks_msec() / 1000.0
    }
    _add_to_data_history(access_record)

## 记录数据变化
func _record_data_change(name: String, old_value: Variant, new_value: Variant, scope: String):
    var change_record = {
        "type": "change",
        "variable_name": name,
        "old_value": old_value,
        "new_value": new_value,
        "scope": scope,
        "timestamp": Time.get_ticks_msec() / 1000.0
    }
    _add_to_data_history(change_record)

## 添加到数据历史
func _add_to_data_history(record: Dictionary):
    data_history.append(record)
    
    # 限制历史记录数量
    if data_history.size() > config.max_data_history:
        data_history.pop_front()

## 更新性能指标
func _update_performance_metrics(name: String, value: Variant):
    current_time = Time.get_ticks_msec() / 1000.0
    
    if not performance_data.has(name):
        performance_data[name] = {
            "access_count": 0,
            "last_access": 0,
            "total_size": 0
        }
    
    var metrics = performance_data[name]
    metrics.access_count += 1
    metrics.last_access = current_time
    metrics.total_size += _estimate_value_size(value)

## 估算值大小
func _estimate_value_size(value: Variant) -> int:
    match typeof(value):
        TYPE_BOOL:
            return 1
        TYPE_INT:
            return 4
        TYPE_FLOAT:
            return 8
        TYPE_STRING:
            return (value as String).length() * 2
        TYPE_ARRAY:
            return (value as Array).size() * 8
        TYPE_DICTIONARY:
            return (value as Dictionary).size() * 16
        _:
            return 32

## 请求取消执行
func request_cancel(reason: String = ""):
    is_cancelled = true
    cancellation_reason = reason
    context_cancelled.emit(reason)

## 检查是否已取消
func is_execution_cancelled() -> bool:
    return is_cancelled

## 获取执行统计
func get_execution_stats() -> Dictionary:
    return {
        "execution_id": execution_id,
        "start_time": start_time,
        "current_time": current_time,
        "duration": current_time - start_time,
        "is_cancelled": is_cancelled,
        "cancellation_reason": cancellation_reason,
        "local_variable_count": local_variables.size(),
        "temporary_data_count": temporary_data.size(),
        "data_history_size": data_history.size(),
        "performance_data": performance_data
    }

## 清理临时数据
func cleanup_temporary_data():
    temporary_data.clear()

## 克隆上下文
func clone() -> ExecutionContext:
    var new_context = ExecutionContext.new(trigger, target, config)
    new_context.local_variables = local_variables.duplicate(true)
    new_context.temporary_data = temporary_data.duplicate(true)
    new_context.execution_id = _generate_execution_id()
    return new_context
```

---

## 2. 控制流设计

### 2.1 控制流概述

控制流定义了可视化编程系统中指令和条件的执行顺序和逻辑。设计特点包括：

- **灵活的流程控制**：支持顺序、分支、循环等多种流程
- **异步执行支持**：原生支持异步操作和等待
- **条件分支**：基于条件的动态流程控制
- **错误恢复**：支持异常处理和流程恢复

### 2.2 控制流类型

```mermaid
graph TB
    subgraph "基本流程 (Basic Flows)"
        SequentialFlow[顺序流程]
        BranchFlow[分支流程]
        LoopFlow[循环流程]
    end
    
    subgraph "高级流程 (Advanced Flows)"
        ParallelFlow[并行流程]
        StateMachineFlow[状态机流程]
        EventDrivenFlow[事件驱动流程]
    end
    
    subgraph "特殊流程 (Special Flows)"
        ConditionalFlow[条件流程]
        ExceptionFlow[异常处理流程]
        CleanupFlow[清理流程]
    end
    
    SequentialFlow --> BranchFlow
    BranchFlow --> LoopFlow
    LoopFlow --> ParallelFlow
    ParallelFlow --> StateMachineFlow
    StateMachineFlow --> EventDrivenFlow
    
    EventDrivenFlow --> ConditionalFlow
    ConditionalFlow --> ExceptionFlow
    ExceptionFlow --> CleanupFlow
```

### 2.3 流程控制器

```gdscript
@tool
class_name FlowController extends RefCounted

## 流程类型
enum FlowType {
    SEQUENTIAL,
    BRANCH,
    LOOP,
    PARALLEL,
    STATE_MACHINE,
    EVENT_DRIVEN
}

## 流程状态
enum FlowState {
    IDLE,
    RUNNING,
    PAUSED,
    COMPLETED,
    ERROR,
    CANCELLED
}

## 流程执行结果
class FlowResult:
    var state: FlowState
    var output_data: Dictionary = {}
    var error_message: String = ""
    var execution_time: float = 0.0

## 流程配置
class FlowConfig:
    var enable_debugging: bool = false
    var enable_profiling: bool = false
    var max_execution_time: float = -1  # -1 = unlimited
    var enable_error_recovery: bool = true
    var retry_count: int = 3

var current_flow: FlowExecutor = null
var flow_stack: Array[FlowExecutor] = []
var global_context: ExecutionContext = null
var config: FlowConfig

func _init(flow_config: FlowConfig = null):
    config = flow_config if flow_config else FlowConfig.new()

## 执行流程
func execute_flow(
    flow_type: FlowType,
    flow_data: Dictionary,
    context: ExecutionContext
) -> FlowResult:
    var flow_executor = _create_flow_executor(flow_type, flow_data)
    if not flow_executor:
        var result = FlowResult.new()
        result.state = FlowState.ERROR
        result.error_message = "Failed to create flow executor"
        return result
    
    flow_executor.context = context
    flow_executor.config = config
    
    # 添加到流程栈
    flow_stack.append(flow_executor)
    current_flow = flow_executor
    
    # 执行流程
    var result = await flow_executor.execute()
    
    # 从流程栈移除
    flow_stack.erase(flow_executor)
    if flow_stack.size() > 0:
        current_flow = flow_stack[-1]
    else:
        current_flow = null
    
    return result

## 创建流程执行器
func _create_flow_executor(flow_type: FlowType, flow_data: Dictionary) -> FlowExecutor:
    match flow_type:
        FlowType.SEQUENTIAL:
            return SequentialFlowExecutor.new(flow_data)
        FlowType.BRANCH:
            return BranchFlowExecutor.new(flow_data)
        FlowType.LOOP:
            return LoopFlowExecutor.new(flow_data)
        FlowType.PARALLEL:
            return ParallelFlowExecutor.new(flow_data)
        FlowType.STATE_MACHINE:
            return StateMachineFlowExecutor.new(flow_data)
        FlowType.EVENT_DRIVEN:
            return EventDrivenFlowExecutor.new(flow_data)
    return null

## 暂停当前流程
func pause_current_flow():
    if current_flow:
        current_flow.pause()

## 恢复当前流程
func resume_current_flow():
    if current_flow:
        current_flow.resume()

## 取消当前流程
func cancel_current_flow(reason: String = ""):
    if current_flow:
        current_flow.cancel(reason)

## 获取流程状态
func get_flow_status() -> Dictionary:
    return {
        "current_flow": current_flow,
        "flow_stack_size": flow_stack.size(),
        "stack_trace": _get_stack_trace()
    }

## 获取堆栈跟踪
func _get_stack_trace() -> Array[Dictionary]:
    var trace = []
    
    for i in range(flow_stack.size()):
        var flow = flow_stack[i]
        trace.append({
            "level": i,
            "flow_type": flow.get_flow_type(),
            "state": flow.get_state(),
            "execution_time": flow.get_execution_time()
        })
    
    return trace
```

### 2.4 流程执行器基类

```gdscript
@tool
class_name FlowExecutor extends RefCounted

## 流程数据
var flow_data: Dictionary = {}
var context: ExecutionContext = null
var config: FlowController.FlowConfig = null

## 执行状态
var state: FlowController.FlowState = FlowController.FlowState.IDLE
var start_time: float = 0.0
var execution_time: float = 0.0
var error_message: String = ""

## 信号
signal flow_started()
signal flow_completed(result: FlowController.FlowResult)
signal flow_paused()
signal flow_resumed()
signal flow_cancelled(reason: String)
signal flow_error(error_message: String)

## 执行流程（子类实现）
func execute() -> FlowController.FlowResult:
    push_error("execute() must be implemented by subclass")
    return null

## 暂停流程
func pause():
    if state == FlowController.FlowState.RUNNING:
        state = FlowController.FlowState.PAUSED
        flow_paused.emit()

## 恢复流程
func resume():
    if state == FlowController.FlowState.PAUSED:
        state = FlowController.FlowState.RUNNING
        flow_resumed.emit()

## 取消流程
func cancel(reason: String = ""):
    state = FlowController.FlowState.CANCELLED
    error_message = reason
    flow_cancelled.emit(reason)

## 获取流程类型
func get_flow_type() -> String:
    return "Base"

## 获取状态
func get_state() -> FlowController.FlowState:
    return state

## 获取执行时间
func get_execution_time() -> float:
    return execution_time

## 创建执行结果
func _create_result(result_state: FlowController.FlowState) -> FlowController.FlowResult:
    var result = FlowController.FlowResult.new()
    result.state = result_state
    result.error_message = error_message
    result.execution_time = execution_time
    return result

## 开始执行
func _start_execution():
    state = FlowController.FlowState.RUNNING
    start_time = Time.get_ticks_msec() / 1000.0
    flow_started.emit()

## 完成执行
func _complete_execution(result_state: FlowController.FlowState) -> FlowController.FlowResult:
    execution_time = Time.get_ticks_msec() / 1000.0 - start_time
    state = result_state
    
    var result = _create_result(result_state)
    flow_completed.emit(result)
    
    return result

## 处理错误
func _handle_error(error: String):
    state = FlowController.FlowState.ERROR
    error_message = error
    flow_error.emit(error)
```

### 2.5 顺序流程执行器

```gdscript
@tool
class_name SequentialFlowExecutor extends FlowExecutor

## 顺序流程数据
class SequentialFlowData:
    var instructions: Array[BaseInstruction] = []
    var stop_on_error: bool = true
    var stop_on_first_false: bool = false

var flow_config: SequentialFlowData

func _init(data: Dictionary):
    flow_data = data
    flow_config = SequentialFlowData.new()
    
    # 解析流程数据
    if data.has("instructions"):
        flow_config.instructions = data["instructions"]
    if data.has("stop_on_error"):
        flow_config.stop_on_error = data["stop_on_error"]
    if data.has("stop_on_first_false"):
        flow_config.stop_on_first_false = data["stop_on_first_false"]

func execute() -> FlowController.FlowResult:
    _start_execution()
    
    var last_result = true
    
    for i in range(flow_config.instructions.size()):
        # 检查是否已取消
        if context.is_execution_cancelled():
            return _complete_execution(FlowController.FlowState.CANCELLED)
        
        var instruction = flow_config.instructions[i]
        if not instruction:
            continue
        
        # 执行指令
        instruction.execute(context)
        await instruction.finished
        
        # 检查指令结果
        var instruction_result = _get_instruction_result(instruction)
        last_result = instruction_result
        
        # 处理停止条件
        if flow_config.stop_on_error and not instruction_result:
            return _complete_execution(FlowController.FlowState.ERROR)
        
        if flow_config.stop_on_first_false and not instruction_result:
            break
    
    return _complete_execution(FlowController.FlowState.COMPLETED)

func get_flow_type() -> String:
    return "Sequential"

## 获取指令执行结果
func _get_instruction_result(instruction: BaseInstruction) -> bool:
    # 这里可以根据指令类型和上下文判断执行结果
    # 简化实现：假设所有指令都成功
    return true
```

### 2.6 分支流程执行器

```gdscript
@tool
class_name BranchFlowExecutor extends FlowExecutor

## 分支流程数据
class BranchFlowData:
    var condition: BaseCondition
    var true_instructions: Array[BaseInstruction] = []
    var false_instructions: Array[BaseInstruction] = []
    var default_branch: String = "true"  # "true", "false", "both"

var flow_config: BranchFlowData

func _init(data: Dictionary):
    flow_data = data
    flow_config = BranchFlowData.new()
    
    # 解析流程数据
    if data.has("condition"):
        flow_config.condition = data["condition"]
    if data.has("true_instructions"):
        flow_config.true_instructions = data["true_instructions"]
    if data.has("false_instructions"):
        flow_config.false_instructions = data["false_instructions"]
    if data.has("default_branch"):
        flow_config.default_branch = data["default_branch"]

func execute() -> FlowController.FlowResult:
    _start_execution()
    
    # 检查是否已取消
    if context.is_execution_cancelled():
        return _complete_execution(FlowController.FlowState.CANCELLED)
    
    # 评估条件
    var condition_result = false
    if flow_config.condition:
        condition_result = flow_config.condition.check(context)
    
    # 选择执行的分支
    var instructions_to_execute: Array[BaseInstruction] = []
    
    match flow_config.default_branch:
        "true":
            instructions_to_execute = flow_config.true_instructions if condition_result else []
        "false":
            instructions_to_execute = flow_config.false_instructions if not condition_result else []
        "both":
            instructions_to_execute = flow_config.true_instructions if condition_result else flow_config.false_instructions
        _:
            instructions_to_execute = flow_config.true_instructions if condition_result else flow_config.false_instructions
    
    # 执行选定的指令
    for instruction in instructions_to_execute:
        # 检查是否已取消
        if context.is_execution_cancelled():
            return _complete_execution(FlowController.FlowState.CANCELLED)
        
        instruction.execute(context)
        await instruction.finished
    
    return _complete_execution(FlowController.FlowState.COMPLETED)

func get_flow_type() -> String:
    return "Branch"
```

---

## 3. 执行引擎

### 3.1 执行引擎概述

执行引擎是可视化编程系统的核心运行时，负责协调指令、条件、变量和触发器的执行。设计特点：

- **统一执行模型**：提供统一的执行接口和模型
- **异步优先**：原生支持异步执行和等待
- **资源管理**：智能管理执行资源和内存
- **性能监控**：内置性能监控和分析功能

### 3.2 执行引擎架构

```gdscript
@tool
class_name ExecutionEngine extends Node

## 执行引擎配置
class EngineConfig:
    var max_concurrent_executions: int = 10
    var enable_profiling: bool = false
    var enable_debug_logging: bool = false
    var execution_timeout: float = 30.0
    var enable_gc_optimization: bool = true

## 执行状态
enum ExecutionState {
    IDLE,
    RUNNING,
    PAUSED,
    STOPPING
}

var config: EngineConfig
var current_state: ExecutionState = ExecutionState.IDLE

## 执行管理
var active_executions: Dictionary = {}  # execution_id -> ExecutionContext
var execution_queue: Array[Dictionary] = []
var execution_history: Array[Dictionary] = []

## 性能监控
var performance_monitor: PerformanceMonitor = null
var resource_monitor: ResourceMonitor = null

## 信号
signal execution_started(execution_id: String)
signal execution_completed(execution_id: String, result: Dictionary)
signal execution_failed(execution_id: String, error: String)
signal engine_state_changed(new_state: ExecutionState)

func _ready():
    config = EngineConfig.new()
    _setup_monitors()

## 设置监控器
func _setup_monitors():
    if config.enable_profiling:
        performance_monitor = PerformanceMonitor.new()
        add_child(performance_monitor)
        
        resource_monitor = ResourceMonitor.new()
        add_child(resource_monitor)

## 执行动作序列
func execute_action_runner(
    action_runner: ActionRunner,
    trigger: BaseTrigger,
    target: Node = null
) -> String:
    var execution_id = _generate_execution_id()
    
    # 创建执行上下文
    var context = ExecutionContext.new(trigger, target)
    
    # 添加到活动执行列表
    active_executions[execution_id] = context
    
    # 发出开始信号
    execution_started.emit(execution_id)
    
    # 执行动作序列
    _execute_action_runner_async(action_runner, context, execution_id)
    
    return execution_id

## 异步执行动作序列
func _execute_action_runner_async(
    action_runner: ActionRunner,
    context: ExecutionContext,
    execution_id: String
):
    # 检查并发限制
    if active_executions.size() >= config.max_concurrent_executions:
        _queue_execution(action_runner, context, execution_id)
        return
    
    # 设置超时
    var timeout_timer = Timer.new()
    timeout_timer.wait_time = config.execution_timeout
    timeout_timer.timeout.connect(_on_execution_timeout.bind(execution_id))
    timeout_timer.autostart = true
    add_child(timeout_timer)
    
    # 开始性能监控
    if performance_monitor:
        performance_monitor.start_monitoring(execution_id)
    
    try:
        # 执行动作序列
        action_runner.run(context)
        await action_runner.action_completed
        
        # 执行成功
        _on_execution_success(execution_id, context)
        
    except:
        # 执行失败
        var error_message = "Execution failed: " + str(get_stack())
        _on_execution_error(execution_id, error_message)
    
    finally:
        # 清理资源
        timeout_timer.queue_free()
        
        if performance_monitor:
            performance_monitor.stop_monitoring(execution_id)
        
        # 处理队列中的下一个执行
        _process_execution_queue()

## 执行成功处理
func _on_execution_success(execution_id: String, context: ExecutionContext):
    var result = {
        "execution_id": execution_id,
        "success": true,
        "context": context,
        "performance_data": performance_monitor.get_data(execution_id) if performance_monitor else {},
        "execution_time": Time.get_ticks_msec() / 1000.0 - context.start_time
    }
    
    # 记录执行历史
    _record_execution(execution_id, result)
    
    # 移除活动执行
    active_executions.erase(execution_id)
    
    # 发出完成信号
    execution_completed.emit(execution_id, result)

## 执行错误处理
func _on_execution_error(execution_id: String, error_message: String):
    # 记录错误
    push_error("Execution error [%s]: %s" % [execution_id, error_message])
    
    # 移除活动执行
    active_executions.erase(execution_id)
    
    # 发出失败信号
    execution_failed.emit(execution_id, error_message)

## 执行超时处理
func _on_execution_timeout(execution_id: String):
    var context = active_executions.get(execution_id)
    if context:
        context.request_cancel("Execution timeout")
    
    _on_execution_error(execution_id, "Execution timeout")

## 队列执行
func _queue_execution(
    action_runner: ActionRunner,
    context: ExecutionContext,
    execution_id: String
):
    execution_queue.append({
        "action_runner": action_runner,
        "context": context,
        "execution_id": execution_id,
        "queue_time": Time.get_ticks_msec() / 1000.0
    })

## 处理执行队列
func _process_execution_queue():
    if execution_queue.is_empty():
        return
    
    if active_executions.size() >= config.max_concurrent_executions:
        return
    
    var queued_execution = execution_queue.pop_front()
    _execute_action_runner_async(
        queued_execution.action_runner,
        queued_execution.context,
        queued_execution.execution_id
    )

## 记录执行
func _record_execution(execution_id: String, result: Dictionary):
    var record = {
        "execution_id": execution_id,
        "timestamp": Time.get_ticks_msec() / 1000.0,
        "result": result
    }
    
    execution_history.append(record)
    
    # 限制历史记录数量
    if execution_history.size() > 1000:
        execution_history.pop_front()

## 生成执行ID
func _generate_execution_id() -> String:
    return "exec_%d_%d" % [Time.get_ticks_msec(), randi()]

## 获取执行统计
func get_execution_statistics() -> Dictionary:
    var stats = {
        "current_state": current_state,
        "active_executions": active_executions.size(),
        "queued_executions": execution_queue.size(),
        "total_executions": execution_history.size(),
        "success_rate": 0.0,
        "average_execution_time": 0.0,
        "performance_summary": {}
    }
    
    # 计算成功率和平均执行时间
    if execution_history.size() > 0:
        var success_count = 0
        var total_time = 0.0
        
        for record in execution_history:
            var result = record.result
            if result.get("success", false):
                success_count += 1
            total_time += result.get("execution_time", 0.0)
        
        stats.success_rate = float(success_count) / execution_history.size() * 100.0
        stats.average_execution_time = total_time / execution_history.size()
    
    # 性能摘要
    if performance_monitor:
        stats.performance_summary = performance_monitor.get_summary()
    
    return stats

## 暂停引擎
func pause_engine():
    current_state = ExecutionState.PAUSED
    engine_state_changed.emit(current_state)

## 恢复引擎
func resume_engine():
    current_state = ExecutionState.RUNNING
    engine_state_changed.emit(current_state)

## 停止引擎
func stop_engine():
    current_state = ExecutionState.STOPPING
    
    # 取消所有活动执行
    for execution_id in active_executions.keys():
        var context = active_executions[execution_id]
        context.request_cancel("Engine stopping")
    
    # 清空队列
    execution_queue.clear()
    
    engine_state_changed.emit(current_state)
```

---

## 4. 异步处理机制

### 4.1 异步处理器

```gdscript
@tool
class_name AsyncProcessor extends RefCounted

## 异步任务状态
enum AsyncTaskStatus {
    PENDING,
    RUNNING,
    COMPLETED,
    FAILED,
    CANCELLED
}

## 异步任务
class AsyncTask:
    var task_id: String
    var callable: Callable
    var args: Array = []
    var status: AsyncTaskStatus = AsyncTaskStatus.PENDING
    var result: Variant = null
    var error_message: String = ""
    var start_time: float = 0.0
    var end_time: float = 0.0
    var timeout: float = -1  # -1 = no timeout

## 处理器配置
class ProcessorConfig:
    var max_concurrent_tasks: int = 50
    var default_timeout: float = 30.0
    var enable_task_priority: bool = true
    var enable_task_cancellation: bool = true

var config: ProcessorConfig
var active_tasks: Dictionary = {}  # task_id -> AsyncTask
var task_queue: Array[AsyncTask] = []
var completed_tasks: Array[AsyncTask] = []

## 信号
signal task_started(task_id: String)
signal task_completed(task_id: String, result: Variant)
signal task_failed(task_id: String, error: String)
signal task_cancelled(task_id: String)

func _init(processor_config: ProcessorConfig = null):
    config = processor_config if processor_config else ProcessorConfig.new()

## 提交异步任务
func submit_task(callable: Callable, args: Array = [], timeout: float = -1) -> String:
    var task = AsyncTask.new()
    task.task_id = _generate_task_id()
    task.callable = callable
    task.args = args
    task.timeout = timeout if timeout > 0 else config.default_timeout
    
    # 添加到队列
    task_queue.append(task)
    
    # 尝试立即执行
    _process_task_queue()
    
    return task.task_id

## 处理任务队列
func _process_task_queue():
    while not task_queue.is_empty() and active_tasks.size() < config.max_concurrent_tasks:
        var task = task_queue.pop_front()
        _execute_task(task)

## 执行任务
func _execute_task(task: AsyncTask):
    active_tasks[task.task_id] = task
    task.status = AsyncTaskStatus.RUNNING
    task.start_time = Time.get_ticks_msec() / 1000.0
    
    task_started.emit(task.task_id)
    
    # 设置超时
    if task.timeout > 0:
        var timeout_timer = get_tree().create_timer(task.timeout)
        timeout_timer.timeout.connect(_on_task_timeout.bind(task.task_id))
    
    # 异步执行任务
    _execute_task_async(task)

## 异步执行任务
func _execute_task_async(task: AsyncTask):
    try:
        # 执行可调用对象
        task.result = await task.callable.callv(task.args)
        task.status = AsyncTaskStatus.COMPLETED
        task.end_time = Time.get_ticks_msec() / 1000.0
        
        task_completed.emit(task.task_id, task.result)
        
    except:
        task.error_message = "Task execution failed: " + str(get_stack())
        task.status = AsyncTaskStatus.FAILED
        task.end_time = Time.get_ticks_msec() / 1000.0
        
        task_failed.emit(task.task_id, task.error_message)
    
    finally:
        # 从活动任务中移除
        active_tasks.erase(task.task_id)
        
        # 添加到完成任务
        completed_tasks.append(task)
        
        # 处理队列中的下一个任务
        _process_task_queue()

## 任务超时处理
func _on_task_timeout(task_id: String):
    var task = active_tasks.get(task_id)
    if task and task.status == AsyncTaskStatus.RUNNING:
        task.status = AsyncTaskStatus.CANCELLED
        task.error_message = "Task timeout"
        task.end_time = Time.get_ticks_msec() / 1000.0
        
        task_cancelled.emit(task_id)
        
        active_tasks.erase(task_id)

## 取消任务
func cancel_task(task_id: String) -> bool:
    var task = active_tasks.get(task_id)
    if task:
        task.status = AsyncTaskStatus.CANCELLED
        task.error_message = "Task cancelled"
        task.end_time = Time.get_ticks_msec() / 1000.0
        
        task_cancelled.emit(task_id)
        active_tasks.erase(task_id)
        return true
    
    # 检查队列中的任务
    for i in range(task_queue.size()):
        if task_queue[i].task_id == task_id:
            task_queue.remove_at(i)
            return true
    
    return false

## 等待任务完成
func wait_for_task(task_id: String) -> Variant:
    var task = active_tasks.get(task_id)
    if not task:
        # 检查已完成的任务
        for completed_task in completed_tasks:
            if completed_task.task_id == task_id:
                if completed_task.status == AsyncTaskStatus.COMPLETED:
                    return completed_task.result
                elif completed_task.status == AsyncTaskStatus.FAILED:
                    push_error(completed_task.error_message)
                    return null
        return null
    
    # 等待任务完成
    while task.status == AsyncTaskStatus.RUNNING or task.status == AsyncTaskStatus.PENDING:
        await get_tree().process_frame
    
    if task.status == AsyncTaskStatus.COMPLETED:
        return task.result
    elif task.status == AsyncTaskStatus.FAILED:
        push_error(task.error_message)
        return null
    
    return null

## 批量等待任务
func wait_for_tasks(task_ids: Array[String]) -> Array[Variant]:
    var results = []
    
    for task_id in task_ids:
        var result = wait_for_task(task_id)
        results.append(result)
    
    return results

## 生成任务ID
func _generate_task_id() -> String:
    return "task_%d_%d" % [Time.get_ticks_msec(), randi()]

## 获取处理器状态
func get_processor_status() -> Dictionary:
    return {
        "active_tasks": active_tasks.size(),
        "queued_tasks": task_queue.size(),
        "completed_tasks": completed_tasks.size(),
        "max_concurrent_tasks": config.max_concurrent_tasks,
        "total_processed": completed_tasks.size()
    }

## 清理已完成的任务
func cleanup_completed_tasks(max_keep: int = 100):
    if completed_tasks.size() > max_keep:
        completed_tasks = completed_tasks.slice(-max_keep)
```

---

## 5. 错误处理和恢复

### 5.1 错误处理系统

```gdscript
@tool
class_name ErrorHandler extends RefCounted

## 错误类型
enum ErrorType {
    VALIDATION_ERROR,
    EXECUTION_ERROR,
    TIMEOUT_ERROR,
    RESOURCE_ERROR,
    LOGIC_ERROR,
    UNKNOWN_ERROR
}

## 错误严重程度
enum ErrorSeverity {
    LOW,
    MEDIUM,
    HIGH,
    CRITICAL
}

## 错误信息
class ErrorInfo:
    var error_type: ErrorType
    var severity: ErrorSeverity
    var message: String
    var context: ExecutionContext
    var stack_trace: Array[Dictionary] = []
    var timestamp: float
    var recovery_suggestions: Array[String] = []

## 错误恢复策略
enum RecoveryStrategy {
    IGNORE,
    RETRY,
    FALLBACK,
    ABORT,
    CUSTOM
}

## 错误处理器配置
class ErrorHandlerConfig:
    var enable_logging: bool = true
    var enable_recovery: bool = true
    var max_retry_count: int = 3
    var retry_delay: float = 1.0
    var enable_error_aggregation: bool = true

var config: ErrorHandlerConfig
var error_history: Array[ErrorInfo] = []
var recovery_strategies: Dictionary = {}

## 信号
signal error_occurred(error_info: ErrorInfo)
signal error_recovered(error_info: ErrorInfo, strategy: RecoveryStrategy)
signal recovery_failed(error_info: ErrorInfo)

func _init(error_handler_config: ErrorHandlerConfig = null):
    config = error_handler_config if error_handler_config else ErrorHandlerConfig.new()
    _setup_default_recovery_strategies()

## 设置默认恢复策略
func _setup_default_recovery_strategies():
    recovery_strategies[ErrorType.VALIDATION_ERROR] = RecoveryStrategy.FALLBACK
    recovery_strategies[ErrorType.EXECUTION_ERROR] = RecoveryStrategy.RETRY
    recovery_strategies[ErrorType.TIMEOUT_ERROR] = RecoveryStrategy.RETRY
    recovery_strategies[ErrorType.RESOURCE_ERROR] = RecoveryStrategy.FALLBACK
    recovery_strategies[ErrorType.LOGIC_ERROR] = RecoveryStrategy.ABORT
    recovery_strategies[ErrorType.UNKNOWN_ERROR] = RecoveryStrategy.IGNORE

## 处理错误
func handle_error(
    error_type: ErrorType,
    severity: ErrorSeverity,
    message: String,
    context: ExecutionContext = null
) -> ErrorInfo:
    var error_info = ErrorInfo.new()
    error_info.error_type = error_type
    error_info.severity = severity
    error_info.message = message
    error_info.context = context
    error_info.stack_trace = get_stack()
    error_info.timestamp = Time.get_ticks_msec() / 1000.0
    
    # 生成恢复建议
    error_info.recovery_suggestions = _generate_recovery_suggestions(error_info)
    
    # 记录错误
    error_history.append(error_info)
    
    # 限制错误历史记录数量
    if error_history.size() > 1000:
        error_history.pop_front()
    
    # 记录日志
    if config.enable_logging:
        _log_error(error_info)
    
    # 发出错误信号
    error_occurred.emit(error_info)
    
    # 尝试恢复
    if config.enable_recovery:
        var recovery_result = await _attempt_recovery(error_info)
        if recovery_result:
            error_recovered.emit(error_info, recovery_result)
        else:
            recovery_failed.emit(error_info)
    
    return error_info

## 生成恢复建议
func _generate_recovery_suggestions(error_info: ErrorInfo) -> Array[String]:
    var suggestions = []
    
    match error_info.error_type:
        ErrorType.VALIDATION_ERROR:
            suggestions.append("Check input parameters")
            suggestions.append("Validate data types")
            suggestions.append("Review configuration")
        
        ErrorType.EXECUTION_ERROR:
            suggestions.append("Check resource availability")
            suggestions.append("Verify permissions")
            suggestions.append("Review execution logic")
        
        ErrorType.TIMEOUT_ERROR:
            suggestions.append("Increase timeout duration")
            suggestions.append("Optimize execution performance")
            suggestions.append("Check network connectivity")
        
        ErrorType.RESOURCE_ERROR:
            suggestions.append("Verify resource paths")
            suggestions.append("Check resource dependencies")
            suggestions.append("Ensure sufficient memory")
        
        ErrorType.LOGIC_ERROR:
            suggestions.append("Review logic flow")
            suggestions.append("Check condition evaluations")
            suggestions.append("Verify variable values")
        
        ErrorType.UNKNOWN_ERROR:
            suggestions.append("Enable debug logging")
            suggestions.append("Check system logs")
            suggestions.append("Report issue to developers")
    
    return suggestions

## 尝试恢复
func _attempt_recovery(error_info: ErrorInfo) -> RecoveryStrategy:
    var strategy = recovery_strategies.get(error_info.error_type, RecoveryStrategy.IGNORE)
    
    match strategy:
        RecoveryStrategy.RETRY:
            return await _retry_recovery(error_info)
        RecoveryStrategy.FALLBACK:
            return await _fallback_recovery(error_info)
        RecoveryStrategy.ABORT:
            return await _abort_recovery(error_info)
        RecoveryStrategy.IGNORE:
            return await _ignore_recovery(error_info)
        RecoveryStrategy.CUSTOM:
            return await _custom_recovery(error_info)
    
    return strategy

## 重试恢复
func _retry_recovery(error_info: ErrorInfo) -> RecoveryStrategy:
    if error_info.context:
        var retry_count = error_info.context.get_variable("_retry_count", 0)
        
        if retry_count < config.max_retry_count:
            error_info.context.set_variable("_retry_count", retry_count + 1)
            
            # 等待重试延迟
            await get_tree().create_timer(config.retry_delay).timeout
            
            # 重新执行
            if error_info.context.trigger and error_info.context.trigger.action_runner:
                error_info.context.trigger.action_runner.run(error_info.context)
                await error_info.context.trigger.action_runner.action_completed
                
                return RecoveryStrategy.RETRY
    
    return RecoveryStrategy.ABORT

## 回退恢复
func _fallback_recovery(error_info: ErrorInfo) -> RecoveryStrategy:
    # 实现回退逻辑
    if error_info.context:
        var fallback_action = error_info.context.get_variable("_fallback_action")
        if fallback_action:
            # 执行回退动作
            print("Executing fallback action: %s" % fallback_action)
            return RecoveryStrategy.FALLBACK
    
    return RecoveryStrategy.IGNORE

## 中止恢复
func _abort_recovery(error_info: ErrorInfo) -> RecoveryStrategy:
    if error_info.context:
        error_info.context.request_cancel("Error recovery: " + error_info.message)
    
    return RecoveryStrategy.ABORT

## 忽略恢复
func _ignore_recovery(error_info: ErrorInfo) -> RecoveryStrategy:
    print("Ignoring error: %s" % error_info.message)
    return RecoveryStrategy.IGNORE

## 自定义恢复
func _custom_recovery(error_info: ErrorInfo) -> RecoveryStrategy:
    # 实现自定义恢复逻辑
    var custom_recovery_func = error_info.context.get_variable("_custom_recovery_func") if error_info.context else null
    
    if custom_recovery_func and custom_recovery_func is Callable:
        var result = await custom_recovery_func.call(error_info)
        return result if result is RecoveryStrategy else RecoveryStrategy.IGNORE
    
    return RecoveryStrategy.IGNORE

## 记录错误日志
func _log_error(error_info: ErrorInfo):
    var severity_str = ErrorSeverity.keys()[error_info.severity]
    var type_str = ErrorType.keys()[error_info.error_type]
    
    var log_message = "[%s][%s] %s" % [severity_str, type_str, error_info.message]
    
    match error_info.severity:
        ErrorSeverity.LOW:
            print(log_message)
        ErrorSeverity.MEDIUM:
            push_warning(log_message)
        ErrorSeverity.HIGH, ErrorSeverity.CRITICAL:
            push_error(log_message)

## 获取错误统计
func get_error_statistics() -> Dictionary:
    var stats = {
        "total_errors": error_history.size(),
        "error_types": {},
        "severity_distribution": {},
        "recent_errors": []
    }
    
    # 统计错误类型
    for error_info in error_history:
        var type_str = ErrorType.keys()[error_info.error_type]
        stats.error_types[type_str] = stats.error_types.get(type_str, 0) + 1
        
        var severity_str = ErrorSeverity.keys()[error_info.severity]
        stats.severity_distribution[severity_str] = stats.severity_distribution.get(severity_str, 0) + 1
    
    # 最近的错误
    var recent_count = min(10, error_history.size())
    for i in range(recent_count):
        var error_info = error_history[error_history.size() - recent_count + i]
        stats.recent_errors.append({
            "message": error_info.message,
            "type": ErrorType.keys()[error_info.error_type],
            "severity": ErrorSeverity.keys()[error_info.severity],
            "timestamp": error_info.timestamp
        })
    
    return stats
```

---

## 6. 性能优化策略

### 6.1 性能监控器

```gdscript
@tool
class_name PerformanceMonitor extends Node

## 性能指标
class PerformanceMetrics:
    var execution_id: String
    var start_time: float
    var end_time: float
    var memory_usage: Array[float] = []
    var cpu_usage: Array[float] = []
    var frame_times: Array[float] = []
    var instruction_count: int = 0
    var variable_access_count: int = 0

var active_monitors: Dictionary = {}  # execution_id -> PerformanceMetrics
var monitoring_enabled: bool = false
var update_interval: float = 0.1  # 监控更新间隔
var monitor_timer: Timer = null

## 信号
signal performance_update(execution_id: String, metrics: PerformanceMetrics)
signal performance_warning(execution_id: String, warning: String)

func _ready():
    _setup_monitor_timer()

## 设置监控定时器
func _setup_monitor_timer():
    monitor_timer = Timer.new()
    monitor_timer.wait_time = update_interval
    monitor_timer.timeout.connect(_update_all_monitors)
    monitor_timer.autostart = false
    add_child(monitor_timer)

## 开始监控
func start_monitoring(execution_id: String):
    var metrics = PerformanceMetrics.new()
    metrics.execution_id = execution_id
    metrics.start_time = Time.get_ticks_msec() / 1000.0
    
    active_monitors[execution_id] = metrics
    
    if not monitoring_enabled:
        monitoring_enabled = true
        monitor_timer.start()

## 停止监控
func stop_monitoring(execution_id: String):
    var metrics = active_monitors.get(execution_id)
    if metrics:
        metrics.end_time = Time.get_ticks_msec() / 1000.0
        performance_update.emit(execution_id, metrics)
    
    active_monitors.erase(execution_id)
    
    if active_monitors.is_empty():
        monitoring_enabled = false
        monitor_timer.stop()

## 更新所有监控器
func _update_all_monitors():
    for execution_id in active_monitors.keys():
        _update_monitor(execution_id)

## 更新单个监控器
func _update_monitor(execution_id: String):
    var metrics = active_monitors.get(execution_id)
    if not metrics:
        return
    
    # 记录内存使用
    var memory_usage = OS.get_static_memory_usage_by_type()[OS.MEMORY_TYPE_STATIC]
    metrics.memory_usage.append(memory_usage)
    
    # 记录帧时间
    var frame_time = get_process_delta_time()
    metrics.frame_times.append(frame_time)
    
    # 检查性能警告
    _check_performance_warnings(execution_id, metrics)

## 检查性能警告
func _check_performance_warnings(execution_id: String, metrics: PerformanceMetrics):
    # 检查内存使用
    if metrics.memory_usage.size() > 0:
        var current_memory = metrics.memory_usage[-1]
        if current_memory > 100 * 1024 * 1024:  # 100MB
            performance_warning.emit(execution_id, "High memory usage: %.1f MB" % (current_memory / (1024 * 1024)))
    
    # 检查帧时间
    if metrics.frame_times.size() > 0:
        var current_frame_time = metrics.frame_times[-1]
        if current_frame_time > 0.1:  # 100ms
            performance_warning.emit(execution_id, "Long frame time: %.1f ms" % (current_frame_time * 1000))

## 获取监控数据
func get_data(execution_id: String) -> Dictionary:
    var metrics = active_monitors.get(execution_id)
    if not metrics:
        return {}
    
    return {
        "execution_id": metrics.execution_id,
        "start_time": metrics.start_time,
        "end_time": metrics.end_time,
        "duration": metrics.end_time - metrics.start_time if metrics.end_time > 0 else 0,
        "memory_usage": metrics.memory_usage,
        "cpu_usage": metrics.cpu_usage,
        "frame_times": metrics.frame_times,
        "instruction_count": metrics.instruction_count,
        "variable_access_count": metrics.variable_access_count,
        "average_memory": _calculate_average(metrics.memory_usage),
        "average_frame_time": _calculate_average(metrics.frame_times),
        "peak_memory": _calculate_peak(metrics.memory_usage),
        "peak_frame_time": _calculate_peak(metrics.frame_times)
    }

## 计算平均值
func _calculate_average(values: Array[float]) -> float:
    if values.is_empty():
        return 0.0
    
    var sum = 0.0
    for value in values:
        sum += value
    
    return sum / values.size()

## 计算峰值
func _calculate_peak(values: Array[float]) -> float:
    if values.is_empty():
        return 0.0
    
    var peak = values[0]
    for value in values:
        if value > peak:
            peak = value
    
    return peak

## 获取性能摘要
func get_summary() -> Dictionary:
    var summary = {
        "active_monitors": active_monitors.size(),
        "total_executions": 0,
        "average_duration": 0.0,
        "average_memory": 0.0,
        "performance_issues": []
    }
    
    var all_durations = []
    var all_memory_peaks = []
    
    for execution_id in active_monitors.keys():
        var data = get_data(execution_id)
        if not data.is_empty():
            summary.total_executions += 1
            all_durations.append(data.duration)
            all_memory_peaks.append(data.peak_memory)
    
    if all_durations.size() > 0:
        summary.average_duration = _calculate_average(all_durations)
        summary.average_memory = _calculate_average(all_memory_peaks)
    
    return summary
```

---

## 总结

数据流和控制流是可视化编程系统的执行核心，本设计提供了：

1. **完整的数据流架构**：支持多层数据处理、类型安全和上下文隔离
2. **灵活的控制流系统**：支持顺序、分支、循环、并行等多种流程控制
3. **强大的执行引擎**：提供统一执行模型、资源管理和性能监控
4. **先进的异步处理**：支持任务队列、并发控制和超时处理
5. **完善的错误处理**：提供错误分类、恢复策略和自动重试
6. **全面的性能优化**：内置性能监控、资源管理和优化建议

这个数据流和控制流设计既保持了高性能，又提供了强大的功能和良好的扩展性，为整个可视化编程系统提供了可靠的执行基础。

---

## 架构更新（2026-03）

### 变量系统重构
- VariableContainer 已标记 @deprecated
- 新工具类：VariableOperations（统一变量访问）、VariableScopeUtils（作用域工具）
- ScopeVariableContainer / ScopeVariableManager（作用域变量系统）
- GlobalVariableAssistant / GlobalVariableManager（全局变量系统）

### 控制流扩展
- WhileLoop、ForEach、Count、WaitUntil 等新循环指令
- IfThen / IfElse 条件分支
- RunRunner 支持指令复用

### 运行时实例集成
- ExecutionContext 现在通过 RuntimeActionRunnerInstance 管理
- 变量快照方法支持断点调试
- 循环标志栈支持嵌套循环控制