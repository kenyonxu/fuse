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

### 架构对比

| 层级 | 是否有 RuntimeInstance | 状态隔离 |
|------|----------------------|----------|
| Event | ✅ RuntimeEventInstance | ✅ 有 |
| ActionRunner | ✅ RuntimeActionRunnerInstance | ✅ 有 |
| Instruction | ✅ RuntimeInstructionInstance | ✅ 有 |

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

### 信号

| 信号 | 说明 |
|------|------|
| `finished()` | 执行完成信号 |
| `error_occurred(message: String)` | 执行出错信号 |
| `paused()` | 暂停信号 |
| `resumed()` | 恢复信号 |
| `timeout()` | 超时信号 |

## 为指令添加运行时实例支持

### 方法1：声明默认状态

重写 `get_default_runtime_state()` 方法声明自己需要的运行时状态：

```gdscript
class_name MyInstruction extends BaseInstruction

func get_default_runtime_state() -> Dictionary:
    var state = super.get_default_runtime_state()
    state["my_timer"] = null
    state["my_counter"] = 0
    return state
```

### 方法2：实现运行时执行方法

重写 `execute_with_runtime_instance()` 方法：

```gdscript
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
    _start_execution(runtime_instance.execution_context)

    # 使用 runtime_instance.runtime_state 存储状态
    var state = runtime_instance.runtime_state

    # 创建计时器
    var scene_tree = Engine.get_main_loop()
    if scene_tree:
        var timer = scene_tree.create_timer(1.0)
        state["timer"] = timer

        # 使用 Callable 并注册到 runtime_instance
        var callback = _create_timer_callback(runtime_instance)
        timer.timeout.connect(callback)
        runtime_instance.register_timer_callback(callback)

        return false  # 异步执行

    runtime_instance._complete_execution()
    return true  # 同步完成

func _create_timer_callback(runtime_instance: RuntimeInstructionInstance) -> Callable:
    var callback = func():
        _on_timer_done(runtime_instance)
    return callback

func _on_timer_done(runtime_instance: RuntimeInstructionInstance):
    if not runtime_instance or runtime_instance.is_completed():
        return
    runtime_instance._complete_execution()
```

### 方法3：实现暂停/恢复回调

```gdscript
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
    var state = runtime_instance.runtime_state
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

## 迁移现有指令

1. **添加 `get_default_runtime_state()`** - 声明状态
2. **添加 `execute_with_runtime_instance()`** - 实现运行时执行
3. **将实例变量改为使用 `runtime_state`** - 状态存储
4. **实现 `on_runtime_pause()` / `on_runtime_resume()`** - 如果需要
5. **保留原 `execute()` 方法** - 兼容遗留模式

## 示例：Wait 指令迁移

```gdscript
# 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
    var state = super.get_default_runtime_state()
    state["timer"] = null
    state["wait_time"] = wait_time
    state["remaining_time"] = 0.0
    state["pause_remaining_time"] = 0.0
    return state

# 运行时执行方法
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
    _start_execution(runtime_instance.execution_context)

    var state = runtime_instance.runtime_state
    var actual_wait_time = _get_wait_time(runtime_instance.execution_context)

    if actual_wait_time < 0:
        runtime_instance._handle_execution_error("无效的等待时间")
        return true

    var scene_tree = Engine.get_main_loop()
    if scene_tree:
        var timer = scene_tree.create_timer(actual_wait_time)
        state["timer"] = timer
        state["is_running"] = true
        state["actual_wait_time"] = actual_wait_time

        var callback = _create_timer_callback(runtime_instance)
        timer.timeout.connect(callback)
        runtime_instance.register_timer_callback(callback)

        return false  # 异步

    runtime_instance._complete_execution()
    return true

# 暂停处理
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
    var state = runtime_instance.runtime_state
    if state.has("timer") and state["timer"]:
        var elapsed = Time.get_ticks_msec() / 1000.0 - state.get("wait_start_time", 0.0)
        var remaining = state.get("actual_wait_time", 0.0) - elapsed
        state["pause_remaining_time"] = max(0.0, remaining)
        state["timer"] = null

# 恢复处理
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
    var state = runtime_instance.runtime_state
    var remaining = state.get("pause_remaining_time", 0.0)

    if remaining > 0:
        var scene_tree = Engine.get_main_loop()
        if scene_tree:
            var timer = scene_tree.create_timer(remaining)
            state["timer"] = timer

            var callback = _create_timer_callback(runtime_instance)
            timer.timeout.connect(callback)
            runtime_instance.register_timer_callback(callback)

    state["pause_remaining_time"] = 0.0
```

## 注意事项

1. **保留原 `execute()` 方法** - 确保向后兼容
2. **使用条件检查代替 try-catch** - GDScript 不支持异常
3. **注册计时器回调** - 避免使用 `bind()` 导致内存泄漏
4. **状态存储在 `runtime_state`** - 确保并发隔离
5. **检查实例有效性** - 在回调中验证 `is_completed()`
