# BaseInstruction 分析报告

## 文档概述

本报告对 Fuse 可视化编程系统中的 `BaseInstruction` 核心脚本进行了全面分析。`BaseInstruction` 是指令系统的基类，提供了指令执行的基本框架和接口，为可视化编程系统中的指令执行功能提供了基础支持。

## 1. 设计文档符合性分析

### 符合的方面

- **架构设计符合性**：`BaseInstruction` 实现了指令执行的基本架构，提供了完整的指令执行框架。
- **接口设计符合性**：提供了完整的指令执行接口，包括 `execute()`、`validate()`、`cancel()` 等核心方法。
- **状态管理符合性**：实现了指令执行状态跟踪，包括 PENDING、RUNNING、COMPLETED、CANCELLED、ERROR 等状态。
- **信号系统**：提供了指令完成时的信号通知机制，便于外部监听执行状态。
- **元数据管理**：实现了指令元数据管理，包括名称、描述、分类等信息。

### 不符合的方面

- **默认执行逻辑过于简单**：`execute()` 方法的默认实现过于简单，直接调用 `_on_execution_completed()`。
- **错误处理机制不够完善**：错误处理机制相对简单，缺乏详细的错误分类和处理策略。
- **指令依赖管理不足**：缺乏指令之间的依赖关系管理机制。

## 2. 最佳实践符合性分析

### 符合的最佳实践

- **文档注释完善**：提供了详细的文档注释，包括方法用途、参数说明、返回值说明和使用示例。
- **类型安全**：使用了适当的类型注解，提高了代码的类型安全性。
- **资源管理**：实现了指令的复制和清理机制，避免了内存泄漏。
- **配置管理**：通过元数据系统提供了灵活的配置管理。
- **调试支持**：提供了调试信息获取方法，便于问题排查。

### 不符合的最佳实践

- **异步执行支持不足**：缺乏对异步执行的原生支持，需要子类自行实现。
- **性能优化不足**：缺乏指令执行的性能优化机制，如缓存和批处理。
- **测试支持不足**：缺乏内置的测试支持机制，如模拟执行和验证。

## 3. 代码质量评估

### 优点

1. **结构清晰**：代码结构清晰，方法职责明确，易于理解和维护。
2. **文档完善**：提供了详细的文档注释和使用示例，降低了学习成本。
3. **状态管理完整**：实现了完整的执行状态管理，便于跟踪指令执行过程。
4. **信号系统完善**：提供了完整的信号系统，便于外部监听和响应。
5. **元数据管理**：实现了丰富的元数据管理，支持指令的分类和组织。

### 缺点

1. **默认实现过于简单**：`execute()` 方法的默认实现过于简单，缺乏实际功能。
2. **错误处理不够健壮**：错误处理机制相对简单，缺乏详细的错误分类和处理。
3. **异步支持不足**：缺乏对异步执行的原生支持，增加了子类实现的复杂度。
4. **性能优化不足**：缺乏指令执行的性能优化机制。

## 4. 潜在问题识别

### 严重问题

1. **执行状态不一致**：在子类重写 `execute()` 方法时，可能忘记调用 `super.execute()`，导致状态不一致。
   - 位置：`execute()` 方法
   - 影响：可能导致指令状态混乱，影响整个执行流程

2. **内存泄漏风险**：在指令执行过程中，可能存在未清理的资源，导致内存泄漏。
   - 位置：`duplicate()` 方法
   - 影响：可能导致内存占用过高，影响系统性能

### 中等问题

1. **错误处理不够详细**：错误信息不够详细，难以定位问题。
   - 位置：`set_error()` 方法
   - 影响：影响问题排查的效率

2. **缺乏执行超时控制**：没有实现指令执行的超时控制机制。
   - 位置：整个类缺乏超时控制
   - 影响：可能导致指令长时间运行，影响系统性能

### 轻微问题

1. **日志格式不统一**：日志输出的格式在不同方法中不统一。
   - 位置：各种日志输出
   - 影响：影响日志的可读性和一致性

2. **文档注释不完整**：部分方法的文档注释不够详细，缺少使用示例。
   - 位置：部分方法
   - 影响：影响代码的可维护性

## 5. 改进建议

### 高优先级改进

1. **增强执行状态管理**
   - 在 `execute()` 方法中添加状态检查，确保状态一致性
   - 提供状态转换验证机制，防止非法状态转换
   - 示例改进：
     ```gdscript
     func execute(context: ExecutionContext):
         # 检查当前状态
         if execution_status != ExecutionStatus.PENDING:
             _log_error("Cannot execute instruction in state: %s" % ExecutionStatus.keys()[execution_status])
             return
         
         # 设置执行状态
         execution_status = ExecutionStatus.RUNNING
         
         # 记录执行开始
         if context:
             context.print_message("开始执行指令: %s" % get_description())
         
         # 执行子类逻辑
         _execute_with_error_handling(context)
     
     func _execute_with_error_handling(context: ExecutionContext):
         try:
             _execute_instruction(context)
             _on_execution_completed()
         except Error as e:
             _on_execution_error("执行错误: %s" % str(e))
     ```

2. **实现执行超时控制**
   - 添加执行超时控制机制
   - 支持超时时的优雅处理
   - 示例改进：
     ```gdscript
     var _timeout_timer: Timer = null
     var _timeout_seconds: float = 30.0
     
     func execute(context: ExecutionContext):
         # 设置超时计时器
         _timeout_timer = Timer.new()
         _timeout_timer.wait_time = _timeout_seconds
         _timeout_timer.one_shot = true
         _timeout_timer.timeout.connect(_on_timeout)
         add_child(_timeout_timer)
         _timeout_timer.start()
         
         # 执行指令
         super.execute(context)
     
     func _on_timeout():
         _log_error("指令执行超时")
         set_error("指令执行超时")
         _timeout_timer.queue_free()
         _timeout_timer = null
         finished.emit()
     
     func _on_execution_completed():
         if _timeout_timer:
             _timeout_timer.stop()
             _timeout_timer.queue_free()
             _timeout_timer = null
         super._on_execution_completed()
     ```

3. **增强错误处理机制**
   - 实现更详细的错误分类和处理
   - 提供更具体的错误信息，便于问题排查
   - 示例改进：
     ```gdscript
     enum InstructionErrorType {
         VALIDATION_ERROR,
         EXECUTION_ERROR,
         TIMEOUT_ERROR,
         CANCELLED_ERROR,
         UNKNOWN_ERROR
     }
     
     var error_type: InstructionErrorType = InstructionErrorType.UNKNOWN_ERROR
     var error_stack_trace: String = ""
     
     func set_error(message: String, error_type: InstructionErrorType = InstructionErrorType.UNKNOWN_ERROR):
         execution_status = ExecutionStatus.ERROR
         error_message = message
         self.error_type = error_type
         error_stack_trace = get_stack()
         
         print("[ERROR][BaseInstruction] 指令执行错误: %s - 类型: %s" % [
             message, 
             InstructionErrorType.keys()[error_type]
         ])
     
     func get_error_details() -> Dictionary:
         return {
             "message": error_message,
             "type": InstructionErrorType.keys()[error_type],
             "stack_trace": error_stack_trace,
             "instruction_name": get_name(),
             "instruction_description": get_description()
         }
     ```

### 中优先级改进

1. **添加异步执行支持**
   - 原生支持异步执行
   - 提供异步执行的状态管理
   - 示例改进：
     ```gdscript
     signal execution_progress(progress: float)
     signal execution_step(step_name: String)
     
     func execute_async(context: ExecutionContext) -> Signal:
         # 异步执行指令
         var promise = Promise.new()
         
         # 执行异步逻辑
         _execute_async_with_context(context, promise)
         
         return promise.finished
     
     func _execute_async_with_context(context: ExecutionContext, promise: Promise):
         # 设置执行状态
         execution_status = ExecutionStatus.RUNNING
         execution_progress.emit(0.0)
         
         # 执行异步步骤
         await _execute_async_step1(context)
         execution_step.emit("步骤1完成")
         execution_progress.emit(0.3)
         
         await _execute_async_step2(context)
         execution_step.emit("步骤2完成")
         execution_progress.emit(0.6)
         
         await _execute_async_step3(context)
         execution_step.emit("步骤3完成")
         execution_progress.emit(1.0)
         
         # 完成执行
         _on_execution_completed()
         promise.resolve(get_debug_info())
     ```

2. **实现指令依赖管理**
   - 添加指令之间的依赖关系管理
   - 支持依赖验证和自动处理
   - 示例改进：
     ```gdscript
     var _dependencies: Array[String] = []
     var _dependents: Array[String] = []
     
     func add_dependency(instruction_name: String):
         if not _dependencies.has(instruction_name):
             _dependencies.append(instruction_name)
     
     func remove_dependency(instruction_name: String):
         _dependencies.erase(instruction_name)
     
     func validate_dependencies(context: ExecutionContext) -> bool:
         for dep_name in _dependencies:
             if not context.has_instruction(dep_name):
                 _log_error("缺少依赖指令: %s" % dep_name)
                 return false
         return true
     
     func get_dependency_chain() -> Array[String]:
         # 返回完整的依赖链
         var chain = []
         for dep_name in _dependencies:
             chain.append(dep_name)
             # 递归获取依赖的依赖
             var dep_instruction = context.get_instruction(dep_name)
             if dep_instruction:
                 chain.append_array(dep_instruction.get_dependency_chain())
         return chain
     ```

3. **增强性能监控**
   - 添加执行性能监控
   - 提供性能统计和分析
   - 示例改进：
     ```gdscript
     var _execution_times: Array[float] = []
     var _memory_usage: Array[int] = []
     
     func execute(context: ExecutionContext):
         var start_time = Time.get_ticks_msec()
         var start_memory = Performance.get_monitor(Performance.MEMORY_STATIC)
         
         super.execute(context)
         
         var end_time = Time.get_ticks_msec()
         var end_memory = Performance.get_monitor(Performance.MEMORY_STATIC)
         
         _execution_times.append(end_time - start_time)
         _memory_usage.append(end_memory - start_memory)
     
     func get_performance_metrics() -> Dictionary:
         return {
             "average_execution_time": _get_average(_execution_times),
             "max_execution_time": _get_max(_execution_times),
             "total_executions": _execution_times.size(),
             "average_memory_usage": _get_average(_memory_usage),
             "max_memory_usage": _get_max(_memory_usage)
         }
     
     func _get_average(values: Array) -> float:
         if values.is_empty():
             return 0.0
         return values.reduce(func(a, b): return a + b) / values.size()
     
     func _get_max(values: Array) -> float:
         if values.is_empty():
             return 0.0
         return values.max()
     ```

### 低优先级改进

1. **统一日志格式**
   - 统一日志输出的格式
   - 使用统一的日志前缀和格式
   - 示例改进：
     ```gdscript
     func _log_debug(message: String):
         if debug_mode:
             var timestamp = Time.get_datetime_string_from_system().replace("T", " ")
             print("[DEBUG][BaseInstruction][%s][%s] %s" % [timestamp, get_name(), message])
     ```

2. **添加执行历史记录**
   - 实现指令执行的历史记录功能
   - 记录每次执行的详细信息，便于后续分析
   - 示例改进：
     ```gdscript
     var _execution_history: Array[Dictionary] = []
     
     func execute(context: ExecutionContext):
         var execution_record = {
             "timestamp": Time.get_ticks_msec() / 1000.0,
             "instruction_name": get_name(),
             "instruction_description": get_description(),
             "context_info": context.get_info()
         }
         
         _execution_history.append(execution_record)
         super.execute(context)
     
     func get_execution_history() -> Array[Dictionary]:
         return _execution_history
     
     func clear_execution_history():
         _execution_history.clear()
     ```

3. **优化内存使用**
   - 优化内存使用，减少不必要的对象创建
   - 使用对象池技术减少内存分配
   - 示例改进：
     ```gdscript
     var _instruction_pool: Array[BaseInstruction] = []
     
     func get_instruction_from_pool() -> BaseInstruction:
         if _instruction_pool.is_empty():
             return BaseInstruction.new()
         else:
             return _instruction_pool.pop_back()
     
     func return_instruction_to_pool(instruction: BaseInstruction):
         _instruction_pool.append(instruction)
     ```

## 6. 总体评估和评分

### 总体评估

`BaseInstruction` 是 Fuse 可视化编程系统中的核心组件，整体设计合理，功能完善。它提供了完整的指令执行框架，具有良好的可扩展性。然而，在默认实现、错误处理和异步支持方面还有改进空间。

### 评分

- **设计符合性**：8/10
  - 优点：架构设计合理，接口设计完整，状态管理完善
  - 缺点：默认执行逻辑过于简单，依赖管理不足

- **最佳实践符合性**：7/10
  - 优点：文档完善，类型安全，资源管理良好
  - 缺点：异步支持不足，性能优化不足，测试支持不足

- **代码质量**：8/10
  - 优点：结构清晰，文档完善，状态管理完整，信号系统完善
  - 缺点：默认实现过于简单，错误处理不够健壮

- **潜在问题**：7/10
  - 优点：大部分问题已经识别并可以解决
  - 缺点：存在一些严重的潜在问题需要优先解决

- **改进建议**：8/10
  - 优点：提供了详细的改进建议，覆盖了各个方面
  - 缺点：部分建议需要更多的实现细节

### 综合评分：7.6/10

`BaseInstruction` 是一个功能完善的设计良好的组件，但在默认实现、错误处理和异步支持方面还有改进空间。建议优先解决严重问题，然后逐步实施中优先级和低优先级的改进建议。

---

## v2.0 新增特性（2026-03 更新）

v2.0 版本对 `BaseInstruction` 进行了大幅增强，针对上一版分析中指出的异步支持不足、错误处理不够健壮、缺乏超时控制等问题进行了系统性改进。以下按功能模块逐一分析。

### 2.0.1 ExecutionMode 枚举

**功能说明：** 定义指令的执行模式，用于智能执行路径优化。配合 `can_execute_sync()` 方法，使 ActionRunner 等调用方可以根据指令特征选择最优执行路径（同步/异步），从而提升整体执行效率。

**枚举定义：**

```gdscript
enum ExecutionMode {
    AUTO_DETECT,    ## 自动检测执行模式（推荐）
    FORCE_ASYNC,    ## 强制异步执行
    FORCE_SYNC      ## 强制同步执行
}
```

**相关成员：**

| 成员 | 类型 | 说明 |
|------|------|------|
| `execution_mode` | `@export var ExecutionMode` | 导出属性，默认 `AUTO_DETECT`，可在编辑器检查器中配置 |
| `can_execute_sync() -> bool` | 方法 | 根据当前 `execution_mode` 判断是否可同步执行 |

**使用场景：**

- **AUTO_DETECT**（默认）：由系统自动分析指令源码中的 `await` 关键字、`_is_synchronous()` 重写等特征来判定执行模式。适用于大多数自定义指令，无需手动配置。
- **FORCE_ASYNC**：明确要求通过异步路径执行，适用于包含 Timer 等异步机制的指令。例如 `WaitInstruction`、`TweenInstruction`。
- **FORCE_SYNC**：强制走同步快路径，跳过 await 机制。适用于性能敏感的纯计算指令，如 `MathExpression`、`VariableSetInstruction`。

---

### 2.0.2 CompletionSignalTiming 枚举

**功能说明：** 定义指令完成信号（`finished`）的发送时机，解决某些指令需要在执行开始时即通知调用方的场景需求。

**枚举定义：**

```gdscript
enum CompletionSignalTiming {
    ON_START,   ## 在执行开始时发送完成信号
    ON_FINISH   ## 在执行完成时发送完成信号（默认）
}
```

**相关成员：**

| 成员 | 类型 | 说明 |
|------|------|------|
| `completion_timing` | `@export var CompletionSignalTiming` | 导出属性，默认 `ON_FINISH` |
| `_start_execution()` | 方法 | 在 `ON_START` 模式下立即调用 `_on_execution_completed()` |
| `_on_execution_completed()` | 方法 | 在 `ON_FINISH` 模式下发出信号，在 `ON_START` 模式下跳过重复发送 |

**使用场景：**

- **ON_FINISH**（默认）：指令执行完毕后才发出 `finished` 信号。适用于需要等待执行结果的指令，如 `MoveNodeInstruction`、`PlayAnimationInstruction`。
- **ON_START**：在 `_start_execution()` 中立即发出完成信号，适用于"触发即完成"的指令。例如触发事件的 `FireEventInstruction`，执行逻辑主要是通知其他系统，不需要等待自身完成。

---

### 2.0.3 ExecutionStatus 枚举

**功能说明：** 定义指令在执行生命周期中的完整状态机，支持状态查询和状态转换验证。

**枚举定义：**

```gdscript
enum ExecutionStatus {
    PENDING,    ## 等待执行
    RUNNING,    ## 正在执行
    COMPLETED,  ## 执行完成
    CANCELLED,  ## 已取消
    ERROR       ## 执行出错
}
```

**相关成员：**

| 方法签名 | 返回值 | 说明 |
|----------|--------|------|
| `get_execution_status() -> ExecutionStatus` | 枚举值 | 获取当前状态 |
| `is_running() -> bool` | `bool` | 等价于 `status == RUNNING` |
| `is_completed() -> bool` | `bool` | 等价于 `status == COMPLETED` |
| `has_error() -> bool` | `bool` | 等价于 `status == ERROR` |
| `reset()` | `void` | 重置状态为 `PENDING`，同时清除 `_fuse_error`、断开信号、清理超时计时器、重置同步能力缓存 |

**状态转换流程：**

```
PENDING → RUNNING → COMPLETED
                  → CANCELLED
                  → ERROR
```

**使用场景：**

- `ActionRunner` 在调度指令前检查 `PENDING` 状态，防止重复执行。
- 调试面板通过 `get_debug_info()` 输出 `ExecutionStatus.keys()[status]` 来显示可读的状态名称。
- `reset()` 方法在指令需要被复用时调用（如循环指令中的子指令重置），确保干净的初始状态。

---

### 2.0.4 RuntimeInstructionInstance 支持

**功能说明：** 引入运行时实例架构，将指令的运行时状态（如计时器、已用时间、是否正在运行等）从指令资源本身解耦到独立的 `RuntimeInstructionInstance` 对象中。这使得同一个指令资源可以被多个运行时实例共享，同时各自维护独立的执行状态。

**方法签名：**

```gdscript
## 获取默认运行时状态字典（子类可重写以声明自定义状态）
func get_default_runtime_state() -> Dictionary:
    return {
        "initialized": true,
        "execution_status": ExecutionStatus.PENDING,
        "timer": null,
        "elapsed_time": 0.0,
        "is_running": false
    }

## 使用运行时实例执行指令（子类可重写）
## 返回 bool 表示是否同步完成
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool

## 暂停回调，运行时实例被暂停时调用
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void

## 恢复回调，运行时实例被恢复时调用
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void
```

**默认实现行为：**

- `get_default_runtime_state()`：返回包含 `initialized`、`execution_status`、`timer`、`elapsed_time`、`is_running` 五个字段的默认字典。
- `execute_with_runtime_instance()`：内部调用 `execute_sync()`，并将执行状态和错误信息同步回 `runtime_instance.runtime_state`。
- `on_runtime_pause()` / `on_runtime_resume()`：空实现，子类可重写以实现暂停/恢复逻辑（如暂停 Tween 动画）。

**使用场景：**

- **循环指令（ForEachInstruction）**：每次循环迭代创建独立的 `RuntimeInstructionInstance`，确保子指令在多轮循环中状态互不干扰。
- **调试断点系统**：暂停时通过 `on_runtime_pause()` 冻结当前执行状态，恢复时通过 `on_runtime_resume()` 继续执行。
- **指令复用**：同一个 `BaseInstruction` 资源可以在不同上下文中被多次执行，每次执行使用独立的运行时实例。

---

### 2.0.5 智能执行模式检测

**功能说明：** 在 `AUTO_DETECT` 模式下，系统通过多层次检测策略判断指令是否适合同步执行，从而让 ActionRunner 自动选择最优执行路径，无需开发者手动标注。

**检测优先级链：**

```
1. 子类重写 _is_synchronous() → 使用其返回值
2. 手动设置 set_synchronous_hint() → 使用 hint 值
3. 源码分析 _contains_await_in_code() → 检测 await 关键字
4. 默认假设为同步
```

**方法签名：**

```gdscript
## 公开接口：根据 execution_mode 判断是否可同步执行
func can_execute_sync() -> bool

## 自动检测同步能力（内部使用）
func _detect_sync_capability() -> bool

## 检查是否包含异步操作（核心检测逻辑，带缓存）
func _has_async_operations() -> bool

## 源码级别检测 await 关键字（排除注释）
func _contains_await_in_code(source: String) -> bool

## 同步执行包装器，返回 bool 表示是否同步完成
func execute_sync(context: ExecutionContext) -> bool
```

**缓存机制：**

- `_sync_capability_cached: bool`：缓存的检测结果。
- `_sync_capability_detected: bool`：标记是否已完成检测，避免重复分析源码。
- `reset()` 方法会清除缓存，确保每次执行前重新检测。

**使用场景：**

- **ActionRunner 优化**：`execute_sync()` 包装器先调用 `can_execute_sync()`，如果可以同步执行则直接返回结果，避免不必要的 `await` 开销。
- **验证阶段警告**：`validate_async_in_sync_mode()` 静态方法用于验证同步模式下是否包含异步子指令，生成警告信息。
- **自定义指令**：对于使用回调而非 `await` 的异步指令，开发者可调用 `set_synchronous_hint(false)` 明确声明异步特性。

---

### 2.0.6 超时管理系统

**功能说明：** 为指令执行提供超时保护机制，防止指令因逻辑错误或外部依赖无响应而无限期阻塞。使用 Godot 的 `SceneTreeTimer` 实现，无需手动管理 Timer 节点。

**方法签名：**

```gdscript
## 设置超时时间（秒），0 表示禁用超时
func set_timeout(timeout_seconds: float)

## 获取当前超时时间
func get_timeout() -> float

## 检查是否启用了超时
func has_timeout() -> bool

## 获取当前执行已耗时（秒），仅在 RUNNING 状态下返回有效值
func get_execution_time() -> float

## 创建 SceneTreeTimer 并连接超时回调（内部方法）
func _setup_timeout_timer()

## 断开并清理超时计时器（内部方法）
func _cleanup_timeout_timer()

## 超时触发时的处理逻辑（内部方法）
func _on_timeout()
```

**执行流程：**

```
_start_execution()
    ├── 记录 _execution_start_time
    ├── _setup_timeout_timer()
    │     ├── 检查 has_timeout()
    │     ├── _cleanup_timeout_timer()（清理旧计时器）
    │     └── scene_tree.create_timer(_timeout_duration)
    │           └── timeout.connect(_on_timeout)
    └── 执行指令逻辑

_on_timeout()
    ├── 检查 execution_status == RUNNING
    ├── 计算已用时间 elapsed_time
    ├── set_error(..., TIMEOUT_ERROR, context)
    ├── _cleanup_timeout_timer()
    └── finished.emit()

_on_execution_completed() / _on_execution_error() / cancel()
    └── _cleanup_timeout_timer()
```

**相关字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `_timeout_timer` | `SceneTreeTimer` | Godot 场景树计时器引用 |
| `_timeout_duration` | `float` | 超时时间（秒），0 表示无超时 |
| `_execution_start_time` | `float` | 执行开始时间戳（秒） |

**使用场景：**

- **网络请求指令**：设置合理超时防止网络阻塞。
- **玩家交互等待**：设置超时后自动跳过等待状态。
- **调试模式**：为可疑指令临时设置较短超时，快速定位无限循环问题。

---

### 2.0.7 统一错误处理

**功能说明：** 通过 `_fuse_error` 字段和 `FuseError` 类实现结构化错误处理，替代简单的字符串错误消息，支持错误类型分类、上下文信息收集和日志系统集成。

**方法签名：**

```gdscript
## 设置错误（支持翻译键自动翻译）
func set_error(
    message: String,
    error_type: FuseError.ErrorType = FuseError.ErrorType.EXECUTION_ERROR,
    context: Dictionary = {}
)

## 创建本地化错误（通过翻译键+参数）
func set_error_localized(
    message_key: String,
    error_type: FuseError.ErrorType = FuseError.ErrorType.EXECUTION_ERROR,
    args: Dictionary = {},
    context: Dictionary = {}
)

## 内部错误处理方法（设置错误 + 发出 finished 信号）
func _on_execution_error(
    error: String,
    error_type: FuseError.ErrorType = FuseError.ErrorType.EXECUTION_ERROR,
    context: Dictionary = {}
)
```

**FuseError.ErrorType 枚举值：**

| 值 | 说明 |
|------|------|
| `VALIDATION_ERROR` | 验证错误 |
| `EXECUTION_ERROR` | 执行错误（默认） |
| `CONFIGURATION_ERROR` | 配置错误 |
| `RUNTIME_ERROR` | 运行时错误 |
| `TIMEOUT_ERROR` | 超时错误 |

**`_fuse_error` 字段行为：**

- 类型为 `FuseError`，通过 `FuseError.create_with_context()` 工厂方法创建。
- 自动附加 `instruction_name` 和 `instruction_description` 到错误上下文。
- `get_debug_info()` 方法在有 `_fuse_error` 时会附加 `fuse_error` 详细信息。
- `reset()` 方法会将 `_fuse_error` 置为 `null`。

**`set_error()` 与 `set_error_localized()` 的区别：**

- `set_error(message)`：直接使用传入的消息字符串。如果 `message` 以 `FUSE_ERROR_` 开头，会自动调用翻译系统进行本地化。
- `set_error_localized(message_key, args)`：强制通过翻译键 + 参数字典进行本地化，适用于需要参数化错误消息的场景。

**使用场景：**

- `set_error("找不到目标节点: %s" % target_path)`：简单的格式化错误消息。
- `set_error_localized("FUSE_ERROR_NODE_NOT_FOUND", {"node": target_path})`：支持多语言的参数化错误。
- `_on_execution_error(error_msg, FuseError.ErrorType.TIMEOUT_ERROR, {"timeout": 5.0})`：在超时回调中使用，明确标记错误类型。

---

### 2.0.8 日志系统

**功能说明：** 集成 `FuseLogger` 统一日志系统，支持分级日志输出（DEBUG/INFO/WARNING/ERROR/NONE），所有日志方法均带有源标识（`"BaseInstruction"`）和指令名称上下文。

**导出属性：**

```gdscript
@export var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.INFO
```

**FuseLogger.LogLevel 枚举值：**

| 值 | 级别 | 说明 |
|------|------|------|
| `NONE` | -- | 不输出任何日志 |
| `INFO` | 常规 | 只输出 info 级别（默认） |
| `WARNING` | 警告 | 输出 info + warning |
| `ERROR` | 错误 | 输出 info + warning + error |
| `DEBUG` | 调试 | 输出所有级别（debug + info + warning + error） |

**日志方法（共 8 个）：**

| 方法 | 说明 |
|------|------|
| `_log_debug(message)` | 调试级别日志 |
| `_log_info(message)` | 信息级别日志 |
| `_log_warning(message)` | 警告级别日志 |
| `_log_error(message)` | 错误级别日志 |
| `_log_debug_localized(message_key, args)` | 本地化调试日志 |
| `_log_info_localized(message_key, args)` | 本地化信息日志 |
| `_log_warning_localized(message_key, args)` | 本地化警告日志 |
| `_log_error_localized(message_key, args)` | 本地化错误日志 |

所有日志方法统一调用 `FuseLogger` 对应方法，传入三个固定参数：`source = "BaseInstruction"`、`level = self.log_level`、`context = get_name()`。

**使用场景：**

- 在编辑器检查器中通过 `log_level` 属性为特定指令调整日志级别，如调试时将某个指令设为 `DEBUG`。
- 本地化日志方法（`_log_*_localized`）用于输出可翻译的日志消息，确保多语言环境下日志信息的一致性。
- `FuseLogger` 内部根据 `log_level` 过滤输出，避免在生产环境中产生过多调试日志。

---

### 2.0.9 手动同步提示

**功能说明：** 提供编程接口让子类或工厂方法在运行时明确声明指令的同步/异步特性，作为智能检测的补充手段。主要适用于使用回调机制而非 `await` 关键字的异步指令，这类指令无法通过源码分析检测到异步特征。

**字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `_is_synchronous_hint` | `bool` | 同步能力提示值，默认 `false` |
| `_sync_hint_manually_set` | `bool` | 标记 hint 是否被 `set_synchronous_hint()` 手动设置 |

**方法签名：**

```gdscript
## 设置同步提示（供子类或工厂使用）
func set_synchronous_hint(is_sync: bool)
```

**方法行为：**

1. 设置 `_is_synchronous_hint` 为传入的 `is_sync` 值。
2. 标记 `_sync_hint_manually_set = true`，表示此值是手动设置的。
3. 重置 `_sync_capability_detected = false`，清除缓存使下次 `_has_async_operations()` 调用时重新检测。

**与 `_is_synchronous()` 的关系：**

```gdscript
func _is_synchronous() -> bool:
    return _is_synchronous_hint
```

`_is_synchronous()` 的默认实现直接返回 `_is_synchronous_hint`。子类可以重写此方法提供自定义的同步判断逻辑，此时 `set_synchronous_hint()` 的值将不再生效。

**使用场景：**

- **回调型异步指令**：指令在 `execute()` 中启动一个异步操作并通过回调完成（不使用 `await`），此时 `_contains_await_in_code()` 无法检测到异步特征。开发者应调用 `set_synchronous_hint(false)` 来声明。
- **指令工厂**：在动态创建指令实例时，工厂方法可以根据配置参数设置同步提示，而无需修改指令源码。
- **动态配置**：在运行时根据条件改变指令的同步特性（如切换在线/离线模式时改变网络请求指令的执行模式）。