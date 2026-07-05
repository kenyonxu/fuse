# Instruction State Isolation - Plan C: RuntimeInstructionInstance 方案（修订版）

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.
>
> **修订说明:** 本版本修复了原方案的以下问题：
> - 🔴 P0: 信号多次触发保护
> - 🔴 P0: SceneTreeTimer 信号断开
> - 🔴 P0: 异常处理
> - 🔴 P0: 执行超时机制
> - 🟠 P1: 暂停/恢复功能
> - 🟠 P1: 信号连接管理
> - 🟡 P2: 状态同步

**Goal:** 创建 `RuntimeInstructionInstance` 类，为每条指令提供独立的运行时状态容器，实现与 Event/ActionRunner 一致的状态隔离架构。

**Architecture:** 参考 `RuntimeEventInstance` 和 `RuntimeActionRunnerInstance` 的设计模式，创建 `RuntimeInstructionInstance` 类。该类包装指令资源，提供独立的 `runtime_state` 字典存储运行时状态，并通过信号转发机制确保每个执行上下文有独立的回调。

**Tech Stack:** GDScript 2.0, Godot 4.6, Resource-based architecture

---

## 问题背景

### 当前架构不一致

| 层级 | 是否有 RuntimeInstance | 状态隔离 |
|------|----------------------|----------|
| Event | ✅ RuntimeEventInstance | ✅ 有 |
| ActionRunner | ✅ RuntimeActionRunnerInstance | ✅ 有 |
| Instruction | ❌ **没有** | ❌ **无** |

### 期望架构

```
┌──────────────────────────────────────────────────────────────────┐
│                           Trigger                                 │
│  ┌─────────────────────────┐  ┌────────────────────────────────┐ │
│  │ RuntimeEventInstance    │  │ RuntimeActionRunnerInstance    │ │
│  │ - runtime_state: {}     │  │ - runtime_state: {}            │ │
│  │ - event_definition      │  │ - action_runner                │ │
│  └───────────┬─────────────┘  │ - instruction_instances: []    │ │
│              │                 │        ↓                       │ │
│              │                 │  ┌──────────────────────────┐  │ │
│              │                 │  │ RuntimeInstructionInst   │  │ │
│              │                 │  │ - runtime_state: {}      │  │ │
│              │                 │  │ - instruction            │  │ │
│              │                 │  │ - execution_context      │  │ │
│              │                 │  └──────────────────────────┘  │ │
│              │                 └────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

---

## Task 1: 创建 RuntimeInstructionInstance 基类（修订版）

**Files:**
- Create: `addons/bricks/core/runtime_instruction_instance.gd`

**Step 1: 创建类文件**

```gdscript
# addons/bricks/core/runtime_instruction_instance.gd
@tool
class_name RuntimeInstructionInstance extends RefCounted

## 运行时指令实例类
##
## 提供轻量级的运行时指令实例，避免不必要的资源复制。
## 这个类包装了指令定义，并为每个执行提供独立的运行时状态。
##
## 架构设计：
## - 与 RuntimeEventInstance/RuntimeActionRunnerInstance 保持一致
## - 使用 runtime_state 字典存储运行时状态
## - 通过信号转发机制确保独立回调
##
## 修订说明：
## - 添加信号多次触发保护
## - 添加 SceneTreeTimer 信号断开机制
## - 添加异常保护
## - 添加执行超时机制
## - 添加暂停/恢复功能

## 信号
signal finished()                           ## 执行完成信号
signal error_occurred(message: String)      ## 执行出错信号
signal paused()                             ## 暂停信号
signal resumed()                            ## 恢复信号
signal timeout()                            ## 超时信号

## 属性
var instruction: BaseInstruction            ## 指令定义资源
var runtime_state: Dictionary = {}          ## 运行时状态字典
var execution_context: ExecutionContext     ## 执行上下文
var owner_runner: RuntimeActionRunnerInstance  ## 拥有此实例的 ActionRunner
var log_level: BricksLogger.LogLevel = BricksLogger.LogLevel.INFO  ## 日志级别

## 超时配置
var execution_timeout: float = 0.0          ## 执行超时时间（0 表示无超时）

## 内部状态
var _is_executing: bool = false
var _is_completed: bool = false
var _is_paused: bool = false
var _has_error: bool = false
var _error_message: String = ""

## 超时相关
var _timeout_timer: SceneTreeTimer = null
var _paused_time: float = 0.0
var _pause_start_time: float = 0.0

## 信号连接追踪（用于清理）
var _connected_timer_callbacks: Array[Callable] = []

## 构造函数
func _init(inst: BaseInstruction, context: ExecutionContext, runner: RuntimeActionRunnerInstance = null):
    instruction = inst
    execution_context = context
    owner_runner = runner

    # 同步日志级别
    if instruction:
        log_level = instruction.log_level

    # 初始化运行时状态
    _initialize_runtime_state()

    _log_debug("RuntimeInstructionInstance 创建完成: %s" % get_description())

## 初始化运行时状态
##
## 优先使用指令的自声明状态模式，回退到遗留模式
func _initialize_runtime_state():
    if not instruction:
        _log_warning("没有指令定义，无法初始化运行时状态")
        return

    # 新架构：检查指令是否实现了自声明状态模式
    if instruction.has_method("get_default_runtime_state"):
        var declared_state = instruction.get_default_runtime_state()
        runtime_state = declared_state.duplicate(true)
        _log_debug("使用指令自声明状态模式初始化: %s" % instruction.get_name())
    else:
        # 遗留架构：使用默认状态
        runtime_state["timer"] = null
        runtime_state["elapsed_time"] = 0.0
        runtime_state["is_running"] = false

    # 确保基础状态存在
    _ensure_base_states()

## 确保基础状态存在
func _ensure_base_states():
    if not runtime_state.has("initialized"):
        runtime_state["initialized"] = true
    if not runtime_state.has("execution_status"):
        runtime_state["execution_status"] = BaseInstruction.ExecutionStatus.PENDING

## 执行指令（同步包装器）
##
## 返回：
## - bool - 是否同步完成（true=同步，false=需要异步等待）
func execute_sync() -> bool:
    if _is_executing:
        _log_warning("指令已在执行中")
        return true

    # 🔧 修复：如果已完成，不允许重新执行
    if _is_completed:
        _log_warning("指令已完成，无法重新执行")
        return true

    _is_executing = true
    _is_completed = false
    _is_paused = false
    _has_error = false
    _error_message = ""
    _paused_time = 0.0
    _pause_start_time = 0.0

    runtime_state["execution_status"] = BaseInstruction.ExecutionStatus.RUNNING

    # 🔧 新增：启动超时计时器
    _start_timeout_timer()

    var result = true

    # 🔧 修复：GDScript 不支持 try-catch，使用条件检查代替
    # 检查指令是否需要运行时实例模式
    if instruction == null:
        _handle_execution_error("指令为空")
        return true

    if not is_instance_valid(instruction):
        _handle_execution_error("指令无效")
        return true

    if instruction.has_method("execute_with_runtime_instance"):
        # 新模式：传递运行时实例给指令
        result = instruction.execute_with_runtime_instance(self)
    else:
        # 兼容模式：直接执行指令，但需要包装回调
        result = _execute_legacy_mode()

    return result

## 遗留模式执行
##
## 为不支持运行时实例的指令提供兼容执行
func _execute_legacy_mode() -> bool:
    if not instruction:
        _handle_execution_error("指令为空")
        return true

    # 连接指令的 finished 信号
    if instruction.finished.is_connected(_on_instruction_finished):
        instruction.finished.disconnect(_on_instruction_finished)
    instruction.finished.connect(_on_instruction_finished)

    # 执行指令
    var sync_completed = instruction.execute_sync(execution_context)

    return sync_completed

## 指令完成回调（遗留模式）
func _on_instruction_finished():
    # 断开信号
    if instruction and instruction.finished.is_connected(_on_instruction_finished):
        instruction.finished.disconnect(_on_instruction_finished)

    _complete_execution()

## 完成执行
func _complete_execution():
    # 🔧 修复：防止多次触发
    if _is_completed:
        _log_warning("指令已完成，忽略重复完成调用")
        return

    # 停止超时计时器
    _stop_timeout_timer()

    _is_executing = false
    _is_completed = true
    _is_paused = false
    runtime_state["execution_status"] = BaseInstruction.ExecutionStatus.COMPLETED

    _log_debug("指令执行完成: %s" % get_description())
    finished.emit()

## 处理执行错误
func _handle_execution_error(message: String):
    _has_error = true
    _error_message = message
    runtime_state["execution_status"] = BaseInstruction.ExecutionStatus.FAILED

    _stop_timeout_timer()
    _is_executing = false
    _is_completed = true

    _log_error(message)
    error_occurred.emit(message)
    finished.emit()

## 🔧 新增：暂停执行
func pause() -> bool:
    if not _is_executing or _is_paused:
        _log_warning("无法暂停：指令未在执行或已暂停")
        return false

    _is_paused = true
    _pause_start_time = Time.get_ticks_msec() / 1000.0
    runtime_state["is_paused"] = true

    # 通知指令暂停（如果支持）
    if instruction and instruction.has_method("on_runtime_pause"):
        instruction.on_runtime_pause(self)

    _log_debug("指令执行已暂停: %s" % get_description())
    paused.emit()
    return true

## 🔧 新增：恢复执行
func resume() -> bool:
    if not _is_paused:
        _log_warning("无法恢复：指令未暂停")
        return false

    # 计算暂停时长
    var pause_duration = Time.get_ticks_msec() / 1000.0 - _pause_start_time
    _paused_time += pause_duration

    _is_paused = false
    runtime_state["is_paused"] = false

    # 通知指令恢复（如果支持）
    if instruction and instruction.has_method("on_runtime_resume"):
        instruction.on_runtime_resume(self)

    _log_debug("指令执行已恢复: %s" % get_description())
    resumed.emit()
    return true

## 取消执行
func cancel():
    if not _is_executing:
        return

    _is_executing = false
    _is_completed = true
    _is_paused = false
    runtime_state["execution_status"] = BaseInstruction.ExecutionStatus.CANCELLED

    # 停止超时计时器
    _stop_timeout_timer()

    # 清理运行时状态中的资源
    _cleanup_runtime_resources()

    _log_debug("指令执行已取消: %s" % get_description())

## 🔧 新增：启动超时计时器
func _start_timeout_timer():
    if execution_timeout <= 0:
        return

    var scene_tree = Engine.get_main_loop()
    if not scene_tree:
        return

    _timeout_timer = scene_tree.create_timer(execution_timeout)
    _timeout_timer.timeout.connect(_on_execution_timeout)

    _log_debug("启动超时计时器: %.2fs" % execution_timeout)

## 🔧 新增：停止超时计时器
func _stop_timeout_timer():
    if _timeout_timer:
        # SceneTreeTimer 无法取消，但可以断开连接
        if _timeout_timer.timeout.is_connected(_on_execution_timeout):
            _timeout_timer.timeout.disconnect(_on_execution_timeout)
        _timeout_timer = null

## 🔧 新增：执行超时回调
func _on_execution_timeout():
    if _is_executing and not _is_completed:
        _log_warning("指令执行超时: %s" % get_description())

        _has_error = true
        _error_message = "Execution timeout (%.2fs)" % execution_timeout
        runtime_state["execution_status"] = BaseInstruction.ExecutionStatus.FAILED

        # 清理资源
        _cleanup_runtime_resources()

        _is_executing = false
        _is_completed = true

        timeout.emit()
        error_occurred.emit(_error_message)
        finished.emit()

## 🔧 修复：清理运行时资源（包含信号断开）
func _cleanup_runtime_resources():
    # 清理计时器
    if runtime_state.has("timer") and runtime_state["timer"]:
        var timer = runtime_state["timer"]
        if timer is SceneTreeTimer:
            # 🔧 修复：断开所有连接的信号
            for callback in _connected_timer_callbacks:
                if timer.timeout.is_connected(callback):
                    timer.timeout.disconnect(callback)
            _connected_timer_callbacks.clear()
        runtime_state["timer"] = null

    # 清理其他资源
    runtime_state["is_running"] = false

## 🔧 新增：注册计时器回调（用于追踪信号连接）
func register_timer_callback(callback: Callable):
    if callback not in _connected_timer_callbacks:
        _connected_timer_callbacks.append(callback)

## 🔧 新增：取消注册计时器回调
func unregister_timer_callback(callback: Callable):
    _connected_timer_callbacks.erase(callback)

## 清理实例
func cleanup():
    _log_debug("开始清理 RuntimeInstructionInstance")

    # 取消正在执行的操作
    if _is_executing:
        cancel()

    # 断开指令的 finished 信号
    if instruction and instruction.finished.is_connected(_on_instruction_finished):
        instruction.finished.disconnect(_on_instruction_finished)

    # 停止超时计时器
    _stop_timeout_timer()

    # 清理运行时状态
    _cleanup_runtime_resources()
    runtime_state.clear()

    # 清除回调追踪
    _connected_timer_callbacks.clear()

    # 清理引用
    instruction = null
    execution_context = null
    owner_runner = null

    _log_debug("RuntimeInstructionInstance 清理完成")

## 获取运行时状态
func get_runtime_state(key: String, default = null):
    return runtime_state.get(key, default)

## 设置运行时状态
func set_runtime_state(key: String, value):
    runtime_state[key] = value
    _log_debug("运行时状态已更新: %s = %s" % [key, str(value)])

## 检查是否已完成
func is_completed() -> bool:
    return _is_completed

## 检查是否有错误
func has_error() -> bool:
    return _has_error

## 获取错误消息
func get_error_message() -> String:
    return _error_message

## 检查是否已暂停
func is_paused() -> bool:
    return _is_paused

## 获取总暂停时间
func get_paused_time() -> float:
    return _paused_time

## 获取描述
func get_description() -> String:
    if instruction:
        return "RuntimeInstructionInstance: %s" % instruction.get_description()
    return "RuntimeInstructionInstance (无指令定义)"

## 获取信息
func get_info() -> Dictionary:
    return {
        "instruction_name": instruction.get_name() if instruction else "none",
        "instruction_description": instruction.get_description() if instruction else "无指令定义",
        "is_executing": _is_executing,
        "is_completed": _is_completed,
        "is_paused": _is_paused,
        "has_error": _has_error,
        "error_message": _error_message,
        "paused_time": _paused_time,
        "execution_timeout": execution_timeout,
        "runtime_state_count": runtime_state.size()
    }

## 验证实例
func validate() -> Array[String]:
    var errors: Array[String] = []

    if not instruction:
        errors.append("没有指令定义")

    if not execution_context:
        errors.append("没有执行上下文")

    return errors

## 日志方法
func _log_debug(message: String) -> void:
    BricksLogger.log_debug("RuntimeInstructionInstance", log_level, message)

func _log_info(message: String) -> void:
    BricksLogger.log_info("RuntimeInstructionInstance", log_level, message)

func _log_warning(message: String) -> void:
    BricksLogger.log_warning("RuntimeInstructionInstance", log_level, message)

func _log_error(message: String) -> void:
    BricksLogger.log_error("RuntimeInstructionInstance", log_level, message)
```

**Step 2: 验证文件创建**

确保文件保存在正确路径，无语法错误。

---

## Task 2: 修改 BaseInstruction 支持运行时实例模式（修订版）

**Files:**
- Modify: `addons/bricks/core/base/base_instruction.gd`

**Step 1: 添加运行时实例接口**

在 `BaseInstruction` 类中添加以下方法：

```gdscript
## 获取默认运行时状态（子类可重写）
##
## 子类可以重写此方法声明自己需要的运行时状态。
## 这些状态会在 RuntimeInstructionInstance 初始化时被复制。
##
## 返回：
## - Dictionary - 默认状态字典
func get_default_runtime_state() -> Dictionary:
    return {
        "initialized": true,
        "execution_status": ExecutionStatus.PENDING,
        "timer": null,
        "elapsed_time": 0.0,
        "is_running": false
    }

## 使用运行时实例执行（子类可重写）
##
## 子类可以重写此方法以支持 RuntimeInstructionInstance 模式。
## 在这种模式下，所有状态应该存储在 runtime_instance.runtime_state 中。
##
## 参数：
## - runtime_instance: RuntimeInstructionInstance - 运行时实例
##
## 返回：
## - bool - 是否同步完成
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
    # 🔧 修复：默认实现需要同步状态
    var result = execute_sync(runtime_instance.execution_context)

    # 同步状态到 runtime_instance
    runtime_instance.runtime_state["execution_status"] = execution_status
    if has_error():
        runtime_instance._has_error = true
        runtime_instance._error_message = get_error_message()

    return result

## 🔧 新增：暂停回调（子类可重写）
##
## 当运行时实例被暂停时调用。子类可以重写此方法处理暂停逻辑。
##
## 参数：
## - runtime_instance: RuntimeInstructionInstance - 运行时实例
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
    pass

## 🔧 新增：恢复回调（子类可重写）
##
## 当运行时实例被恢复时调用。子类可以重写此方法处理恢复逻辑。
##
## 参数：
## - runtime_instance: RuntimeInstructionInstance - 运行时实例
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
    pass
```

**Step 2: 添加方法到正确位置**

在 `base_instruction.gd` 文件末尾（`func reset():` 之后）添加这些方法。

---

## Task 3: 迁移 Wait 指令支持运行时实例（修订版）

**Files:**
- Modify: `addons/bricks/instructions/flow_control/wait.gd`

**Step 1: 添加运行时状态声明**

```gdscript
# 在 Wait 类中添加

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
    var state = super.get_default_runtime_state()
    state["timer"] = null  # 每个 RuntimeInstance 有自己的 timer
    state["wait_time"] = wait_time  # 复制配置值
    state["remaining_time"] = 0.0
    state["pause_remaining_time"] = 0.0  # 🔧 新增：暂停时剩余时间
    return state
```

**Step 2: 添加运行时实例执行方法（修订版）**

```gdscript
## 使用运行时实例执行（推荐模式）
##
## 这种模式下，所有状态存储在 runtime_instance.runtime_state 中，
## 确保多个执行实例互不干扰。
##
## 🔧 修订：使用 runtime_instance 管理信号连接，避免 bind 泄漏
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
    _start_execution(runtime_instance.execution_context)

    _log_debug_localized("BRICKS_LOG_INSTRUCTION_START", {"instruction": "Wait"})

    # 获取运行时状态
    var state = runtime_instance.runtime_state

    # 获取等待时间
    var actual_wait_time: float = _get_wait_time(runtime_instance.execution_context)

    if actual_wait_time < 0:
        _log_error_localized("BRICKS_ERROR_INVALID_PARAMETER", {"parameter": "wait_time", "value": str(actual_wait_time)})
        set_error_localized("BRICKS_ERROR_INVALID_PARAMETER", BricksError.ErrorType.VALIDATION_ERROR, {"parameter": "wait_time", "value": str(actual_wait_time)})
        runtime_instance._complete_execution()
        return true

    # 输出等待信息
    if runtime_instance.execution_context:
        var wait_message = BricksLocalization.translate_format("BRICKS_LOG_WAITING_START", {"time": "%.2f" % actual_wait_time})
        runtime_instance.execution_context.print_message(wait_message)

    # 创建计时器并存储到运行时状态
    var scene_tree = Engine.get_main_loop()
    if scene_tree:
        var timer = scene_tree.create_timer(actual_wait_time)
        state["timer"] = timer  # 存储到独立的运行时状态
        state["is_running"] = true
        state["wait_start_time"] = Time.get_ticks_msec() / 1000.0
        state["actual_wait_time"] = actual_wait_time

        # 🔧 修复：使用 Callable 并注册到 runtime_instance
        var callback = _create_timer_callback(runtime_instance)
        timer.timeout.connect(callback)
        runtime_instance.register_timer_callback(callback)

        _log_debug_localized("BRICKS_INSTRUCTION_WAIT_TIMER_STARTED", {})
        return false  # 异步执行
    else:
        _log_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", {"node": "SceneTree"})
        set_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {"node": "SceneTree"})
        runtime_instance._complete_execution()
        return true

## 🔧 新增：创建计时器回调（避免 bind）
func _create_timer_callback(runtime_instance: RuntimeInstructionInstance) -> Callable:
    # 使用 Callable 和闭包，但存储引用以便清理
    var callback = func():
        _on_runtime_timer_timeout(runtime_instance)
    return callback

## 运行时计时器超时回调
func _on_runtime_timer_timeout(runtime_instance: RuntimeInstructionInstance):
    # 检查实例是否仍然有效
    if not runtime_instance or runtime_instance.is_completed():
        return

    var state = runtime_instance.runtime_state

    _log_debug_localized("BRICKS_LOG_WAITING_COMPLETE", {})

    # 清理运行时状态
    state["timer"] = null
    state["is_running"] = false

    # 标记完成
    runtime_instance._complete_execution()

## 🔧 新增：暂停处理
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
    var state = runtime_instance.runtime_state
    if state.has("timer") and state["timer"]:
        var timer = state["timer"]
        if timer is SceneTreeTimer:
            # SceneTreeTimer 无法暂停，记录剩余时间
            var elapsed = Time.get_ticks_msec() / 1000.0 - state.get("wait_start_time", 0.0)
            var remaining = state.get("actual_wait_time", 0.0) - elapsed
            state["pause_remaining_time"] = max(0.0, remaining)

            # 断开原计时器
            var callback = _create_timer_callback(runtime_instance)
            if timer.timeout.is_connected(callback):
                timer.timeout.disconnect(callback)

            state["timer"] = null

## 🔧 新增：恢复处理
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
    var state = runtime_instance.runtime_state
    var remaining = state.get("pause_remaining_time", 0.0)

    if remaining > 0:
        # 创建新计时器用于剩余时间
        var scene_tree = Engine.get_main_loop()
        if scene_tree:
            var timer = scene_tree.create_timer(remaining)
            state["timer"] = timer
            state["wait_start_time"] = Time.get_ticks_msec() / 1000.0
            state["actual_wait_time"] = remaining

            var callback = _create_timer_callback(runtime_instance)
            timer.timeout.connect(callback)
            runtime_instance.register_timer_callback(callback)

    state["pause_remaining_time"] = 0.0

## 获取等待时间（提取为独立方法）
func _get_wait_time(context: ExecutionContext) -> float:
    if value_source == ValueSource.DIRECT:
        return wait_time
    else:
        # 从变量获取等待时间
        if wait_time_variable.is_empty():
            return -1.0

        var var_value: Variant
        if time_scope == BaseVariable.VariableScope.SCOPE:
            match scope_source:
                ScopeSource.NEAREST:
                    var_value = VariableOperations.get_variable(context, wait_time_variable, BaseVariable.VariableScope.SCOPE, null)
                _:
                    var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
                    var scope_container = VariableScopeUtils.get_scope_container_by_source(
                        context,
                        utils_scope_source,
                        custom_scope_id,
                        target_node_path
                    )

                    if scope_container == null:
                        return -1.0

                    var_value = scope_container.get_variable(wait_time_variable, null)
        else:
            var_value = VariableOperations.get_variable(context, wait_time_variable, time_scope, null)

        if var_value == null:
            return -1.0

        return TypeConverter.safe_convert_to_float(var_value)
```

**Step 3: 保留原有 execute 方法**

原有的 `execute(context)` 方法保持不变，以支持遗留模式。

---

## Task 4: 修改 RuntimeActionRunnerInstance 使用 RuntimeInstructionInstance（修订版）

**Files:**
- Modify: `addons/bricks/core/runtime_action_runner_instance.gd`

**Step 1: 添加指令实例数组**

在类属性中添加：

```gdscript
## 运行时指令实例数组
var _instruction_instances: Array[RuntimeInstructionInstance] = []
```

**Step 2: 修改顺序执行方法（修订版）**

```gdscript
## 顺序执行指令
func _execute_instructions_sequential(context: ExecutionContext, instructions: Array):
    _log_debug_localized("BRICKS_LOG_STARTING_SEQUENTIAL_EXECUTION")

    # 清理之前的指令实例
    _cleanup_instruction_instances()

    for i in range(instructions.size()):
        # 检查是否需要停止执行
        if not runtime_state["is_running"]:
            if runtime_state["is_canceling"]:
                _log_debug_localized("BRICKS_LOG_EXECUTION_CANCELLED", {"reason": runtime_state["cancellation_reason"]})
                execution_canceled.emit(runtime_state["cancellation_reason"])
            else:
                _log_debug_localized("BRICKS_LOG_EXECUTION_STOP")
            return

        runtime_state["current_instruction_index"] = i
        var instruction = instructions[i]

        # 🔧 新增：创建运行时指令实例
        var runtime_instruction = RuntimeInstructionInstance.new(instruction, context, self)
        _instruction_instances.append(runtime_instruction)

        var desc = instruction.get_description()
        _log_debug_localized("BRICKS_LOG_EXECUTING_INSTRUCTION", {"current": str(i + 1), "total": str(instructions.size()), "description": desc})
        context.print_message(BricksLocalization.translate_format("BRICKS_LOG_EXECUTING_INSTRUCTION", {"current": str(i + 1), "total": str(instructions.size()), "description": desc}))

        # 发出信号
        instruction_started.emit(instruction)

        # 记录开始时间
        var instruction_start_time = Time.get_ticks_msec() / 1000.0

        # 使用运行时实例执行
        var sync_completed = runtime_instruction.execute_sync()

        if sync_completed:
            # 同步完成
            if action_runner and action_runner.stop_on_error and runtime_instruction.has_error():
                _create_bricks_error_localized("BRICKS_ERROR_INSTRUCTION_EXECUTION_FAILED", BricksError.ErrorType.EXECUTION_ERROR, {
                    "instruction_index": i,
                    "instruction_description": instruction.get_description()
                }, {"error": runtime_instruction.get_error_message()})
                execution_failed.emit(BricksLocalization.translate_format("BRICKS_ERROR_INSTRUCTION_EXECUTION_FAILED", {"error": runtime_instruction.get_error_message()}))
                return

            instruction_completed.emit(instruction)
            continue
        else:
            # 异步执行，等待完成
            await runtime_instruction.finished

            var instruction_end_time = Time.get_ticks_msec() / 1000.0
            var instruction_time = instruction_end_time - instruction_start_time
            _log_debug_localized("BRICKS_LOG_ASYNC_INSTRUCTION_COMPLETED", {"time": str(instruction_time)})

            instruction_completed.emit(instruction)

            if action_runner and action_runner.stop_on_error and runtime_instruction.has_error():
                _log_debug_localized("BRICKS_LOG_STOPPING_DUE_TO_ERROR", {"error": runtime_instruction.get_error_message()})
                _create_bricks_error_localized("BRICKS_ERROR_INSTRUCTION_EXECUTION_FAILED", BricksError.ErrorType.EXECUTION_ERROR, {
                    "instruction_index": i,
                    "instruction_description": instruction.get_description()
                }, {"error": runtime_instruction.get_error_message()})
                execution_failed.emit(BricksLocalization.translate_format("BRICKS_ERROR_INSTRUCTION_EXECUTION_FAILED", {"error": runtime_instruction.get_error_message()}))
                return

    _complete_execution()

## 🔧 新增：清理指令实例
func _cleanup_instruction_instances():
    for runtime_instruction in _instruction_instances:
        runtime_instruction.cleanup()
    _instruction_instances.clear()
```

**Step 3: 修改并行执行方法（修订版）**

```gdscript
## 并行执行指令
func _execute_instructions_parallel(context: ExecutionContext, instructions: Array):
    _log_debug_localized("BRICKS_LOG_STARTING_PARALLEL_EXECUTION")

    if instructions.size() == 0:
        _complete_execution()
        return

    # 清理之前的指令实例
    _cleanup_instruction_instances()

    var tasks: Array[RuntimeInstructionInstance] = []
    var errors: Array[String] = []

    # 启动所有指令
    for i in range(instructions.size()):
        var instruction = instructions[i]
        if not runtime_state["is_running"]:
            if runtime_state["is_canceling"]:
                _log_debug_localized("BRICKS_LOG_EXECUTION_CANCELLED", {"reason": runtime_state["cancellation_reason"]})
                execution_canceled.emit(runtime_state["cancellation_reason"])
            else:
                _log_debug("并行执行停止")
            return

        _log_debug("并行启动指令 %d/%d: %s" % [i + 1, instructions.size(), instruction.get_description()])

        # 发出信号
        instruction_started.emit(instruction)

        # 🔧 新增：创建运行时指令实例
        var runtime_instruction = RuntimeInstructionInstance.new(instruction, context, self)
        _instruction_instances.append(runtime_instruction)

        # 执行（不等待）
        runtime_instruction.execute_sync()

        tasks.append(runtime_instruction)

    # 等待所有任务完成
    await _wait_for_all_parallel_tasks(tasks)

    # 检查错误
    for i in range(tasks.size()):
        var runtime_instruction = tasks[i]
        if runtime_instruction.has_error():
            errors.append("Instruction %d failed: %s" % [i, runtime_instruction.get_error_message()])

    if not errors.is_empty():
        execution_failed.emit("并行执行失败: " + ", ".join(errors))

    _complete_execution()

## 等待所有并行任务完成
func _wait_for_all_parallel_tasks(tasks: Array[RuntimeInstructionInstance]):
    var pending_tasks: Array[RuntimeInstructionInstance] = []

    for task in tasks:
        if not task.is_completed() and not task.has_error():
            pending_tasks.append(task)

    if pending_tasks.is_empty():
        return

    _log_debug("等待 %d 个异步指令完成" % pending_tasks.size())

    # 使用信号等待
    var completed_count = 0
    var target_count = pending_tasks.size()

    for task in pending_tasks:
        task.finished.connect(func(): completed_count += 1)

    while completed_count < target_count:
        await get_tree().process_frame
        # 检查是否需要取消
        if not runtime_state["is_running"]:
            break
```

**Step 4: 修改 cleanup 方法（修订版）**

```gdscript
## 清理运行时实例（添加到现有 cleanup 方法）
func cleanup():
    _log_debug("开始清理 RuntimeActionRunnerInstance")

    # 取消正在执行的序列
    if runtime_state["is_running"]:
        cancel_execution("清理运行时实例")

    # 🔧 修复：清理所有指令实例
    _cleanup_instruction_instances()

    # 清理运行时状态
    runtime_state.clear()

    # 清理引用
    action_runner = null
    owner_trigger = null

    _log_debug("RuntimeActionRunnerInstance 清理完成")
```

---

## Task 5: 创建测试场景（修订版）

**Files:**
- Create: `addons/bricks/tests/test_runtime_instruction_instance.gd`
- Create: `addons/bricks/tests/test_runtime_instruction_instance.tscn`

**Step 1: 创建测试脚本（包含边界测试）**

```gdscript
# test_runtime_instruction_instance.gd
extends Node

## 测试 RuntimeInstructionInstance 状态隔离效果（修订版）
##
## 🔧 新增测试：
## - 信号多次触发保护测试
## - 执行超时测试
## - 暂停/恢复测试
## - 取消执行测试
## - 异常处理测试

var _test_passed: int = 0
var _test_failed: int = 0

func _ready():
    print("=== 测试 RuntimeInstructionInstance 状态隔离（修订版） ===")
    await run_all_tests()
    _print_summary()

func run_all_tests():
    await test_runtime_instance_creation()
    await test_sequential_execution_with_runtime_instance()
    await test_parallel_execution_with_runtime_instance()
    await test_multiple_triggers_isolation()
    await test_wait_instruction_runtime_state()

    # 🔧 新增：边界测试
    await test_signal_multiple_emit_protection()
    await test_execution_timeout()
    await test_pause_resume()
    await test_cancel_execution()
    await test_error_handling()

## 测试1：运行时实例创建
func test_runtime_instance_creation():
    print("\n[Test 1] RuntimeInstructionInstance 创建测试")

    var wait = Wait.new()
    wait.wait_time = 1.0

    var context = ExecutionContext.new(self, self)
    var runtime_inst = RuntimeInstructionInstance.new(wait, context, null)

    # 验证创建成功
    if runtime_inst.instruction == wait:
        print("  ✓ 指令引用正确")
        _test_passed += 1
    else:
        print("  ✗ 指令引用错误")
        _test_failed += 1

    # 验证运行时状态独立
    if runtime_inst.runtime_state.has("timer"):
        print("  ✓ 运行时状态包含 timer")
        _test_passed += 1
    else:
        print("  ✗ 运行时状态缺少 timer")
        _test_failed += 1

    # 验证初始状态
    if not runtime_inst.is_completed():
        print("  ✓ 初始状态为未完成")
        _test_passed += 1
    else:
        print("  ✗ 初始状态错误")
        _test_failed += 1

## 测试2：顺序执行隔离
func test_sequential_execution_with_runtime_instance():
    print("\n[Test 2] 顺序执行 RuntimeInstance 测试")

    var wait1 = Wait.new()
    wait1.wait_time = 0.1

    var wait2 = Wait.new()
    wait2.wait_time = 0.1

    var runner = ActionRunner.new()
    runner.instructions = [wait1, wait2]
    runner.execution_mode = ActionRunner.ExecutionMode.SEQUENTIAL

    var runtime_instance = RuntimeActionRunnerInstance.new(runner, self)
    var context = ExecutionContext.new(self, self)

    var start_time = Time.get_ticks_msec() / 1000.0

    runtime_instance.run(context)
    await runtime_instance.execution_completed

    var end_time = Time.get_ticks_msec() / 1000.0
    var total_time = end_time - start_time

    # 验证执行时间
    if total_time >= 0.18 and total_time < 0.5:
        print("  ✓ 顺序执行时间正确: %.2fs" % total_time)
        _test_passed += 1
    else:
        print("  ✗ 顺序执行时间异常: %.2fs" % total_time)
        _test_failed += 1

    # 验证原指令状态未被修改
    if wait1.execution_status == BaseInstruction.ExecutionStatus.PENDING:
        print("  ✓ 原指令 wait1 状态未被修改")
        _test_passed += 1
    else:
        print("  ✗ 原指令 wait1 状态被修改: %s" % wait1.execution_status)
        _test_failed += 1

## 测试3：并行执行隔离
func test_parallel_execution_with_runtime_instance():
    print("\n[Test 3] 并行执行 RuntimeInstance 测试")

    var wait1 = Wait.new()
    wait1.wait_time = 0.2

    var wait2 = Wait.new()
    wait2.wait_time = 0.3

    var runner = ActionRunner.new()
    runner.instructions = [wait1, wait2]
    runner.execution_mode = ActionRunner.ExecutionMode.PARALLEL

    var runtime_instance = RuntimeActionRunnerInstance.new(runner, self)
    var context = ExecutionContext.new(self, self)

    var start_time = Time.get_ticks_msec() / 1000.0

    runtime_instance.run(context)
    await runtime_instance.execution_completed

    var end_time = Time.get_ticks_msec() / 1000.0
    var total_time = end_time - start_time

    if total_time >= 0.25 and total_time < 0.5:
        print("  ✓ 并行执行时间正确: %.2fs" % total_time)
        _test_passed += 1
    else:
        print("  ✗ 并行执行时间异常: %.2fs" % total_time)
        _test_failed += 1

## 测试4：多 Trigger 隔离
func test_multiple_triggers_isolation():
    print("\n[Test 4] 多 Trigger 并发隔离测试")

    var shared_wait = Wait.new()
    shared_wait.wait_time = 0.2

    var runner = ActionRunner.new()
    runner.instructions = [shared_wait]

    var runtime_instance_a = RuntimeActionRunnerInstance.new(runner, self)
    var runtime_instance_b = RuntimeActionRunnerInstance.new(runner, self)

    var context_a = ExecutionContext.new(self, self)
    var context_b = ExecutionContext.new(self, self)

    var start_time = Time.get_ticks_msec() / 1000.0

    runtime_instance_a.run(context_a)
    runtime_instance_b.run(context_b)

    var completed_a = false
    var completed_b = false

    runtime_instance_a.execution_completed.connect(func(_time): completed_a = true)
    runtime_instance_b.execution_completed.connect(func(_time): completed_b = true)

    while not (completed_a and completed_b):
        await get_tree().process_frame

    var end_time = Time.get_ticks_msec() / 1000.0
    var total_time = end_time - start_time

    if completed_a and completed_b:
        print("  ✓ 两个实例都完成执行")
        _test_passed += 1
    else:
        print("  ✗ 实例未完成")
        _test_failed += 1

    # 验证原指令状态
    if shared_wait.execution_status == BaseInstruction.ExecutionStatus.PENDING:
        print("  ✓ 原指令 shared_wait 状态未被修改")
        _test_passed += 1
    else:
        print("  ✗ 原指令 shared_wait 状态被修改: %s" % shared_wait.execution_status)
        _test_failed += 1

## 测试5：Wait 指令运行时状态
func test_wait_instruction_runtime_state():
    print("\n[Test 5] Wait 指令运行时状态测试")

    var wait = Wait.new()
    wait.wait_time = 0.1

    var context = ExecutionContext.new(self, self)
    var runtime_inst = RuntimeInstructionInstance.new(wait, context, null)

    # 执行前检查
    var timer_before = runtime_inst.get_runtime_state("timer")
    if timer_before == null:
        print("  ✓ 执行前 timer 为 null")
        _test_passed += 1
    else:
        print("  ✗ 执行前 timer 不为 null")
        _test_failed += 1

    # 执行
    var sync_completed = runtime_inst.execute_sync()

    if not sync_completed:
        print("  ✓ Wait 返回异步模式")
        _test_passed += 1
    else:
        print("  ✗ Wait 返回同步模式")
        _test_failed += 1

    # 等待完成
    await runtime_inst.finished

    # 执行后检查
    var timer_after = runtime_inst.get_runtime_state("timer")
    if timer_after == null:
        print("  ✓ 执行后 timer 已清理")
        _test_passed += 1
    else:
        print("  ✗ 执行后 timer 未清理")
        _test_failed += 1

## 🔧 新增测试6：信号多次触发保护
func test_signal_multiple_emit_protection():
    print("\n[Test 6] 信号多次触发保护测试")

    var wait = Wait.new()
    wait.wait_time = 0.05

    var context = ExecutionContext.new(self, self)
    var runtime_inst = RuntimeInstructionInstance.new(wait, context, null)

    var emit_count = 0
    runtime_inst.finished.connect(func(): emit_count += 1)

    # 执行并等待完成
    runtime_inst.execute_sync()
    await runtime_inst.finished

    # 尝试再次完成（应该被忽略）
    runtime_inst._complete_execution()
    await get_tree().create_timer(0.1).timeout

    if emit_count == 1:
        print("  ✓ finished 信号只触发一次")
        _test_passed += 1
    else:
        print("  ✗ finished 信号触发 %d 次" % emit_count)
        _test_failed += 1

## 🔧 新增测试7：执行超时
func test_execution_timeout():
    print("\n[Test 7] 执行超时测试")

    var wait = Wait.new()
    wait.wait_time = 1.0  # 长等待

    var context = ExecutionContext.new(self, self)
    var runtime_inst = RuntimeInstructionInstance.new(wait, context, null)
    runtime_inst.execution_timeout = 0.1  # 短超时

    var timeout_triggered = false
    runtime_inst.timeout.connect(func(): timeout_triggered = true)

    var start_time = Time.get_ticks_msec() / 1000.0
    runtime_inst.execute_sync()
    await runtime_inst.finished
    var end_time = Time.get_ticks_msec() / 1000.0

    if timeout_triggered:
        print("  ✓ 超时信号正确触发")
        _test_passed += 1
    else:
        print("  ✗ 超时信号未触发")
        _test_failed += 1

    if (end_time - start_time) < 0.3:
        print("  ✓ 执行在超时后快速结束")
        _test_passed += 1
    else:
        print("  ✗ 执行时间过长: %.2fs" % (end_time - start_time))
        _test_failed += 1

## 🔧 新增测试8：暂停/恢复
func test_pause_resume():
    print("\n[Test 8] 暂停/恢复测试")

    var wait = Wait.new()
    wait.wait_time = 0.3

    var context = ExecutionContext.new(self, self)
    var runtime_inst = RuntimeInstructionInstance.new(wait, context, null)

    runtime_inst.execute_sync()

    # 等待一小段时间后暂停
    await get_tree().create_timer(0.1).timeout

    if runtime_inst.pause():
        print("  ✓ 暂停成功")
        _test_passed += 1
    else:
        print("  ✗ 暂停失败")
        _test_failed += 1

    if runtime_inst.is_paused():
        print("  ✓ 暂停状态正确")
        _test_passed += 1
    else:
        print("  ✗ 暂停状态不正确")
        _test_failed += 1

    # 等待一段时间后恢复
    await get_tree().create_timer(0.2).timeout

    if runtime_inst.resume():
        print("  ✓ 恢复成功")
        _test_passed += 1
    else:
        print("  ✗ 恢复失败")
        _test_failed += 1

    # 等待完成
    await runtime_inst.finished

    if runtime_inst.is_completed():
        print("  ✓ 暂停恢复后正常完成")
        _test_passed += 1
    else:
        print("  ✗ 暂停恢复后未完成")
        _test_failed += 1

## 🔧 新增测试9：取消执行
func test_cancel_execution():
    print("\n[Test 9] 取消执行测试")

    var wait = Wait.new()
    wait.wait_time = 1.0  # 长等待

    var context = ExecutionContext.new(self, self)
    var runtime_inst = RuntimeInstructionInstance.new(wait, context, null)

    runtime_inst.execute_sync()

    # 等待一小段时间后取消
    await get_tree().create_timer(0.1).timeout

    var start_time = Time.get_ticks_msec() / 1000.0
    runtime_inst.cancel()

    if not runtime_inst._is_executing:
        print("  ✓ 执行状态已停止")
        _test_passed += 1
    else:
        print("  ✗ 执行状态未停止")
        _test_failed += 1

    if runtime_inst.runtime_state["execution_status"] == BaseInstruction.ExecutionStatus.CANCELLED:
        print("  ✓ 取消状态正确")
        _test_passed += 1
    else:
        print("  ✗ 取消状态不正确")
        _test_failed += 1

## 🔧 新增测试10：错误处理
func test_error_handling():
    print("\n[Test 10] 错误处理测试")

    var wait = Wait.new()
    wait.wait_time = -1.0  # 无效值

    var context = ExecutionContext.new(self, self)
    var runtime_inst = RuntimeInstructionInstance.new(wait, context, null)

    var error_triggered = false
    runtime_inst.error_occurred.connect(func(_msg): error_triggered = true)

    runtime_inst.execute_sync()
    await runtime_inst.finished

    if runtime_inst.has_error():
        print("  ✓ 错误被正确检测")
        _test_passed += 1
    else:
        print("  ✗ 错误未被检测")
        _test_failed += 1

    if not runtime_inst.get_error_message().is_empty():
        print("  ✓ 错误消息不为空")
        _test_passed += 1
    else:
        print("  ✗ 错误消息为空")
        _test_failed += 1

func _print_summary():
    print("\n=== 测试总结 ===")
    print("通过: %d" % _test_passed)
    print("失败: %d" % _test_failed)
    if _test_failed == 0:
        print("✓ 所有测试通过!")
    else:
        print("✗ 有测试失败!")
```

**Step 2: 创建测试场景**

在 Godot 编辑器中创建场景并附加脚本。

---

## Task 6: 更新文档

**Files:**
- Create: `addons/bricks/docs/developer/runtime_instruction_instance_guide.md`

**Step 1: 创建开发指南**

```markdown
# RuntimeInstructionInstance 开发指南

## 概述

RuntimeInstructionInstance 是指令的运行时实例包装器，提供独立的状态存储和执行隔离。

## 架构

```
BaseInstruction (Resource, 共享)
        │
        ▼
RuntimeInstructionInstance (RefCounted, 每次执行独立)
    - runtime_state: Dictionary  ← 独立状态存储
    - instruction: BaseInstruction  ← 指向共享资源
```

## 核心功能

### 状态隔离

每个 RuntimeInstructionInstance 都有独立的 `runtime_state` 字典，确保并发执行互不干扰。

### 超时机制

```gdscript
var runtime_inst = RuntimeInstructionInstance.new(instruction, context, null)
runtime_inst.execution_timeout = 5.0  # 5秒超时
runtime_inst.timeout.connect(_on_timeout)
```

### 暂停/恢复

```gdscript
runtime_inst.pause()
# ... 暂停期间
runtime_inst.resume()
```

## 为指令添加运行时实例支持

### 方法1：声明默认状态

```gdscript
class_name MyInstruction extends BaseInstruction

func get_default_runtime_state() -> Dictionary:
    var state = super.get_default_runtime_state()
    state["my_timer"] = null
    state["my_counter"] = 0
    return state
```

### 方法2：实现运行时执行方法

```gdscript
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
    # 使用 runtime_instance.runtime_state 存储状态
    runtime_instance.set_runtime_state("my_timer", create_timer())

    # 返回 false 表示异步
    return false
```

### 方法3：实现暂停/恢复回调

```gdscript
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
    # 保存暂停时状态
    runtime_instance.set_runtime_state("paused_at", Time.get_ticks_msec())

func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
    # 恢复执行
    pass
```

## 信号连接管理

**重要：** 不要使用 `bind()` 连接 SceneTreeTimer 信号，而是使用注册机制：

```gdscript
# ✅ 正确：注册回调
var callback = func(): _on_timer_done(runtime_instance)
timer.timeout.connect(callback)
runtime_instance.register_timer_callback(callback)

# ❌ 错误：使用 bind 可能导致内存泄漏
timer.timeout.connect(_on_timer_done.bind(runtime_instance))
```

## 迁移现有指令

1. 添加 `get_default_runtime_state()` 声明状态
2. 添加 `execute_with_runtime_instance()` 方法
3. 将实例变量改为使用 `runtime_state` 字典
4. 实现暂停/恢复回调（如果需要）
5. 保留原 `execute()` 方法以兼容遗留模式

## 错误处理

使用条件检查和 `_handle_execution_error()` 处理错误（GDScript 不支持 try-catch）：

```gdscript
# GDScript 使用条件检查代替 try-catch
if risky_operation() != OK:
    runtime_instance._handle_execution_error("操作失败")
    return true

# 或使用返回值检查
var result = risky_operation()
if result == null or result.has_error():
    runtime_instance._handle_execution_error("操作失败: %s" % str(result.get_error()))
    return true
```

---

## Task 7: Commit 变更

**Step 1: 检查修改**

```bash
git status
```

**Step 2: 添加文件**

```bash
git add addons/bricks/core/runtime_instruction_instance.gd
git add addons/bricks/core/base/base_instruction.gd
git add addons/bricks/instructions/flow_control/wait.gd
git add addons/bricks/core/runtime_action_runner_instance.gd
git add addons/bricks/tests/test_runtime_instruction_instance.gd
git add addons/bricks/tests/test_runtime_instruction_instance.tscn
git add addons/bricks/docs/developer/runtime_instruction_instance_guide.md
```

**Step 3: 提交**

```bash
git commit -m "feat(bricks): implement RuntimeInstructionInstance architecture (revised)

- Create RuntimeInstructionInstance class for state isolation
- Add signal multiple emit protection
- Add SceneTreeTimer signal disconnect mechanism
- Add error handling with null/validity checks (GDScript safe pattern)
- Add execution timeout mechanism
- Add pause/resume functionality
- Add timer callback registration to avoid bind() leaks
- Add get_default_runtime_state() interface to BaseInstruction
- Migrate Wait instruction to use runtime instance pattern
- Update RuntimeActionRunnerInstance to use instruction instances
- Add comprehensive tests including boundary tests
- Add developer documentation for migration guide

This establishes consistent architecture across Event/ActionRunner/Instruction layers.

Fixes: #issue-number"
```

---

## 修订说明

### P0 修复（已完成）

| 问题 | 修复方案 |
|------|----------|
| 信号多次触发 | `_complete_execution()` 添加 `_is_completed` 检查 |
| SceneTreeTimer 泄漏 | `register_timer_callback()` 追踪并断开信号 |
| 错误未处理 | `execute_sync()` 使用 null/validity 检查 |
| 无超时机制 | 添加 `execution_timeout` 和 `_on_execution_timeout()` |

### P1 修复（已完成）

| 问题 | 修复方案 |
|------|----------|
| 无暂停/恢复 | 添加 `pause()`、`resume()` 和相关信号 |
| bind 导致泄漏 | 使用 Callable + 注册机制替代 bind |
| 状态不同步 | `execute_with_runtime_instance()` 默认实现同步状态 |

### P2 改进（已完成）

| 问题 | 修复方案 |
|------|----------|
| 测试覆盖不足 | 添加 5 个边界测试用例 |
| 文档不完整 | 添加超时、暂停、信号管理等章节 |

---

## 方案优缺点总结（修订版）

### 优点

| 项目 | 说明 |
|------|------|
| ✅ 架构一致 | 与 Event/ActionRunner 模式完全一致 |
| ✅ 完全隔离 | 每次执行有独立的运行时状态 |
| ✅ 类型安全 | 使用类包装，而非泛型字典 |
| ✅ 可扩展 | 子类可声明自己的状态需求 |
| ✅ 兼容性 | 保留遗留模式，渐进迁移 |
| ✅ **信号安全** | 防止多次触发，正确断开连接 |
| ✅ **错误处理安全** | null/validity 检查保护，状态一致性 |
| ✅ **功能完整** | 超时、暂停/恢复支持 |

### 缺点

| 项目 | 说明 |
|------|------|
| ⚠️ 工作量大 | 需要迁移所有异步指令 |
| ⚠️ 复杂度增加 | 新增一层抽象 |
| ⚠️ 学习成本 | 开发者需要理解新架构 |

### 与方案 B 对比（修订版）

| 对比项 | 方案 B (duplicate) | 方案 C 修订版 |
|--------|-------------------|-------------------------|
| 状态隔离 | ✅ 有 | ✅ 有 |
| 架构一致性 | ❌ 不一致 | ✅ 一致 |
| 实现复杂度 | ⭐⭐ 简单 | ⭐⭐⭐⭐ 复杂 |
| 性能开销 | duplicate() 开销 | 实例创建开销 |
| 迁移成本 | 无需迁移 | 需要迁移指令 |
| 可维护性 | 一般 | **更好** |
| **信号安全** | ⚠️ 依赖 GC | ✅ **主动管理** |
| **错误处理** | ❌ 无 | ✅ **有** |
| **超时机制** | ❌ 无 | ✅ **有** |
| **暂停/恢复** | ❌ 无 | ✅ **有** |

### 推荐

- **短期/快速修复**: 使用方案 B
- **长期/架构优化**: 使用方案 C 修订版

可以先用方案 B 解决紧急问题，后续渐进迁移到方案 C 修订版。

---

## 执行选项

Plan complete and saved to `docs/plans/2026-03-10-instruction-state-isolation-plan-c-runtime-instance.md`. Two execution options:

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach?**
