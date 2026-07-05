# RuntimeInstructionInstance 迁移指南

## 概述

`RuntimeInstructionInstance` 是指令的运行时实例包装器，提供独立的状态存储和执行隔离。这解决了多个触发器并发执行同一指令资源时的状态冲突问题。

> **参考实现：** [wait.gd](../instructions/flow_control/wait.gd) 是第一个完全迁移到 RuntimeInstance 架构的指令，可作为完整参考。

## 架构对比

### 旧架构（遗留模式）

```
┌─────────────────────────────┐
│     BaseInstruction         │
│  (Resource, 共享引用)        │
│  - execution_status         │  ← 所有触发器共享状态！
│  - _timer                   │
│  - error_message            │
└─────────────────────────────┘
        ↑         ↑
   Trigger A   Trigger B   ← 并发执行会互相干扰
```

### 新架构（RuntimeInstance 模式）

```
BaseInstruction (Resource, 共享)
        │
        ├──────────────────────────────┐
        ▼                              ▼
RuntimeInstructionInstance      RuntimeInstructionInstance
- runtime_state: {}             - runtime_state: {}
- instruction: BaseInstruction  - instruction: BaseInstruction
- execution_context             - execution_context
        │                              │
   Trigger A                      Trigger B   ← 状态完全隔离！
```

## 核心概念

### RuntimeInstructionInstance

每个运行时实例包含：

| 属性 | 说明 |
|------|------|
| `instruction` | 指向共享的指令资源 |
| `runtime_state` | 独立的运行时状态字典 |
| `execution_context` | 执行上下文 |
| `owner_runner` | 拥有此实例的 ActionRunner |

### 状态隔离

所有运行时状态存储在 `runtime_state` 字典中，确保并发执行互不干扰。

## 迁移步骤

### 第一步：声明默认运行时状态

重写 `get_default_runtime_state()` 方法，声明指令需要的运行时状态。

```gdscript
## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
    var state = super.get_default_runtime_state()
    # 添加指令特有的状态
    state["timer"] = null           # 每个 RuntimeInstance 有自己的 timer
    state["my_counter"] = 0
    state["my_flag"] = false
    state["pause_remaining_time"] = 0.0  # 暂停时剩余时间
    return state
```

**Wait 指令实际实现：**

```gdscript
func get_default_runtime_state() -> Dictionary:
    var state = super.get_default_runtime_state()
    state["timer"] = null
    state["wait_time"] = wait_time      # 复制配置值
    state["remaining_time"] = 0.0
    state["pause_remaining_time"] = 0.0
    return state
```

**基类默认状态：**

| 键 | 默认值 | 说明 |
|----|--------|------|
| `initialized` | `true` | 初始化标记 |
| `execution_status` | `PENDING` | 执行状态 |
| `timer` | `null` | 计时器引用 |
| `elapsed_time` | `0.0` | 已用时间 |
| `is_running` | `false` | 运行标记 |

### 第二步：实现运行时实例执行方法

重写 `execute_with_runtime_instance()` 方法，将状态从实例变量迁移到 `runtime_state` 字典。

**迁移前（遗留模式）：**

```gdscript
## 内部计时器（实例变量 - 所有触发器共享！）
var _timer: SceneTreeTimer

func execute(context: ExecutionContext):
    _start_execution(context)

    # 获取等待时间（内联逻辑，可能 60+ 行）
    var actual_wait_time: float = 0.0
    if value_source == ValueSource.DIRECT:
        actual_wait_time = wait_time
    else:
        # 从变量获取...（重复代码）

    # 创建计时器存储到实例变量
    var scene_tree = Engine.get_main_loop()
    if scene_tree:
        _timer = scene_tree.create_timer(actual_wait_time)
        _timer.timeout.connect(_on_timer_timeout)  # 直接连接
        return  # 异步

func _on_timer_timeout():
    _timer = null
    _on_execution_completed()
```

**迁移后（RuntimeInstance 模式）：**

```gdscript
## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
    var state = super.get_default_runtime_state()
    state["timer"] = null
    state["wait_time"] = wait_time
    state["remaining_time"] = 0.0
    state["pause_remaining_time"] = 0.0
    return state

## 使用运行时实例执行
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
    _start_execution(runtime_instance.execution_context)

    var state = runtime_instance.runtime_state

    # 获取等待时间（提取为独立方法）
    var actual_wait_time = _get_wait_time(runtime_instance.execution_context)

    # 验证
    if actual_wait_time < 0:
        set_error_localized("FUSE_ERROR_INVALID_PARAMETER",
            FuseError.ErrorType.VALIDATION_ERROR,
            {"parameter": "wait_time", "value": str(actual_wait_time)})
        runtime_instance._complete_execution()
        return true  # 同步完成（错误）

    # 输出等待信息
    if runtime_instance.execution_context:
        var msg = FuseLocalization.translate_format(
            "FUSE_LOG_WAITING_START", {"time": "%.2f" % actual_wait_time})
        runtime_instance.execution_context.print_message(msg)

    # 创建计时器并存储到运行时状态
    var scene_tree = Engine.get_main_loop()
    if scene_tree:
        var timer = scene_tree.create_timer(actual_wait_time)
        state["timer"] = timer  # 存储到独立状态
        state["is_running"] = true
        state["wait_start_time"] = Time.get_ticks_msec() / 1000.0
        state["actual_wait_time"] = actual_wait_time

        # 使用回调注册机制（重要！）
        var callback = _create_timer_callback(runtime_instance)
        timer.timeout.connect(callback)
        runtime_instance.register_timer_callback(callback)

        return false  # 异步执行
    else:
        set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND",
            FuseError.ErrorType.RUNTIME_ERROR,
            {"node": "SceneTree"})
        runtime_instance._complete_execution()
        return true

## 创建计时器回调（避免 bind 泄漏）
func _create_timer_callback(runtime_instance: RuntimeInstructionInstance) -> Callable:
    var callback = func():
        _on_runtime_timer_timeout(runtime_instance)
    return callback

## 运行时计时器超时回调
func _on_runtime_timer_timeout(runtime_instance: RuntimeInstructionInstance):
    # 检查实例是否仍然有效
    if not runtime_instance or runtime_instance.is_completed():
        return

    var state = runtime_instance.runtime_state
    state["timer"] = null
    state["is_running"] = false

    runtime_instance._complete_execution()
```

**关键差异总结：**

| 方面 | 遗留模式 | RuntimeInstance 模式 |
|------|----------|---------------------|
| 状态存储 | 实例变量 `_timer` | `runtime_state["timer"]` |
| 状态隔离 | 所有触发器共享 | 每个实例独立 |
| 信号连接 | 直接连接方法 | 通过回调注册机制 |
| 完成调用 | `_on_execution_completed()` | `runtime_instance._complete_execution()` |

### 第三步：实现暂停/恢复回调（可选）

如果指令支持暂停/恢复，实现以下方法：

```gdscript
## 暂停处理
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
    var state = runtime_instance.runtime_state
    if state.has("timer") and state["timer"]:
        var timer = state["timer"]
        if timer is SceneTreeTimer:
            # SceneTreeTimer 无法暂停，记录剩余时间
            var elapsed = Time.get_ticks_msec() / 1000.0 - state.get("start_time", 0.0)
            var remaining = state.get("duration", 0.0) - elapsed
            state["pause_remaining_time"] = max(0.0, remaining)

            # 断开原计时器
            var callback = _create_timer_callback(runtime_instance)
            if timer.timeout.is_connected(callback):
                timer.timeout.disconnect(callback)

            state["timer"] = null

## 恢复处理
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
    var state = runtime_instance.runtime_state
    var remaining = state.get("pause_remaining_time", 0.0)

    if remaining > 0:
        var scene_tree = Engine.get_main_loop()
        if scene_tree:
            var timer = scene_tree.create_timer(remaining)
            state["timer"] = timer
            state["start_time"] = Time.get_ticks_msec() / 1000.0
            state["duration"] = remaining

            var callback = _create_timer_callback(runtime_instance)
            timer.timeout.connect(callback)
            runtime_instance.register_timer_callback(callback)

    state["pause_remaining_time"] = 0.0
```

### 第四步：保留遗留模式（兼容性）

保留原有的 `execute()` 方法以支持遗留模式：

```gdscript
## 执行指令（遗留模式）
func execute(context: ExecutionContext):
    _start_execution(context)
    # ... 原有实现保持不变
```

## 信号连接管理

**重要：** 不要使用 `bind()` 连接 SceneTreeTimer 信号，这可能导致内存泄漏。

```gdscript
# ❌ 错误：使用 bind 可能导致内存泄漏
timer.timeout.connect(_on_timer_done.bind(runtime_instance))

# ✅ 正确：使用注册机制
var callback = func(): _on_timer_done(runtime_instance)
timer.timeout.connect(callback)
runtime_instance.register_timer_callback(callback)
```

## 迁移检查清单

迁移一个指令需要检查以下内容：

- [ ] 添加 `get_default_runtime_state()` 方法声明状态
- [ ] 添加 `execute_with_runtime_instance()` 方法
- [ ] 将实例变量改为使用 `runtime_state` 字典
- [ ] 使用回调注册机制而非 `bind()`
- [ ] 实现暂停/恢复回调（如需要）
- [ ] 保留原有 `execute()` 方法（兼容性）
- [ ] 测试并发执行隔离

## 完整示例：Wait 指令

Wait 指令是第一个完全迁移到 RuntimeInstance 架构的指令，可作为参考：

```gdscript
## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
    var state = super.get_default_runtime_state()
    state["timer"] = null
    state["wait_time"] = wait_time
    state["remaining_time"] = 0.0
    state["pause_remaining_time"] = 0.0
    return state

## 使用运行时实例执行
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
    _start_execution(runtime_instance.execution_context)

    var state = runtime_instance.runtime_state
    var actual_wait_time = _get_wait_time(runtime_instance.execution_context)

    if actual_wait_time < 0:
        set_error_localized("FUSE_ERROR_INVALID_PARAMETER", ...)
        runtime_instance._complete_execution()
        return true

    var scene_tree = Engine.get_main_loop()
    if scene_tree:
        var timer = scene_tree.create_timer(actual_wait_time)
        state["timer"] = timer
        state["is_running"] = true
        state["wait_start_time"] = Time.get_ticks_msec() / 1000.0
        state["actual_wait_time"] = actual_wait_time

        var callback = _create_timer_callback(runtime_instance)
        timer.timeout.connect(callback)
        runtime_instance.register_timer_callback(callback)

        return false  # 异步
    else:
        set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", ...)
        runtime_instance._complete_execution()
        return true
```

## RuntimeInstructionInstance API 参考

### 信号

| 信号 | 说明 |
|------|------|
| `finished()` | 执行完成 |
| `error_occurred(message: String)` | 执行出错 |
| `paused()` | 暂停 |
| `resumed()` | 恢复 |
| `timeout()` | 超时 |

### 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `instruction` | `BaseInstruction` | 指令资源 |
| `runtime_state` | `Dictionary` | 运行时状态 |
| `execution_context` | `ExecutionContext` | 执行上下文 |
| `execution_timeout` | `float` | 超时时间（0=无超时）|

### 方法

| 方法 | 返回值 | 说明 |
|------|--------|------|
| `execute_sync()` | `bool` | 执行指令，返回是否同步完成 |
| `pause()` | `bool` | 暂停执行 |
| `resume()` | `bool` | 恢复执行 |
| `cancel()` | `void` | 取消执行 |
| `is_completed()` | `bool` | 是否已完成 |
| `is_paused()` | `bool` | 是否已暂停 |
| `has_error()` | `bool` | 是否有错误 |
| `get_runtime_state(key, default)` | `Variant` | 获取运行时状态 |
| `set_runtime_state(key, value)` | `void` | 设置运行时状态 |
| `register_timer_callback(callback)` | `void` | 注册计时器回调 |
| `cleanup()` | `void` | 清理实例 |

## 常见问题

### Q: 为什么要迁移到 RuntimeInstance 架构？

A: 解决以下问题：
1. 多触发器并发执行同一指令时的状态冲突
2. 信号多次触发保护
3. SceneTreeTimer 信号断开机制
4. 执行超时机制
5. 暂停/恢复功能

### Q: 是否所有指令都需要迁移？

A: 不是。同步指令（不使用计时器、不等待异步操作）可以暂时保持遗留模式。但建议异步指令都迁移到新架构。

### Q: 迁移后是否兼容旧代码？

A: 是的。保留 `execute()` 方法可确保向后兼容。`RuntimeActionRunnerInstance` 会自动检测并使用正确的执行模式。

### Q: 如何测试迁移是否成功？

A: 创建多个触发器同时触发同一指令，验证：
1. 所有触发器都能正常完成
2. 执行时间符合预期（并行执行应该重叠）
3. 原指令资源状态未被修改

---

## Wait 指令迁移前后对比

### 状态存储对比

| 对比项 | 遗留模式 | RuntimeInstance 模式 |
|--------|----------|---------------------|
| 状态存储 | 实例变量 `_timer` | `runtime_state["timer"]` |
| 并发安全 | ❌ 共享状态冲突 | ✅ 完全隔离 |
| 信号连接 | 直接 `connect()` | 回调注册机制 |
| 暂停/恢复 | ❌ 无 | ✅ 支持（可选实现） |
| bind 泄漏风险 | ⚠️ 可能泄漏 | ✅ 注册机制可追踪清理 |
| 代码复杂度 | 较简单 | 添加独立方法 |

### 关键方法对比

| 方法 | 遗留模式 | RuntimeInstance 模式 |
|------|----------|------------------------|
| 状态声明 | `var _timer` | `get_default_runtime_state()` |
| 执行入口 | `execute(context)` | `execute_with_runtime_instance(runtime_instance)` |
| 完成回调 | `_on_timer_timeout()` | `_on_runtime_timer_timeout(runtime_instance)` |
| 获取等待时间 | 内联逻辑（重复代码） | 提取为 `_get_wait_time(context)` |

### 暂停/恢复实现注意事项

> ✅ **已修复 (2026-03-10)：** Wait.gd 中的暂停/恢复回调匹配问题已修复。

**原问题：** 在 `on_runtime_pause` 中调用 `_create_timer_callback()` 会创建新回调，但新回调与正在运行的回调是不同对象，导致 `is_connected()` 检查失败。

**解决方案：** 存储原始回调引用

```gdscript
## 在 get_default_runtime_state() 中添加
state["current_timer_callback"] = null

## 在 execute_with_runtime_instance() 中存储
var callback = _create_timer_callback(runtime_instance)
timer.timeout.connect(callback)
runtime_instance.register_timer_callback(callback)
state["current_timer_callback"] = callback  # 存储引用

## 在 on_runtime_pause() 中使用存储的回调
var callback = state.get("current_timer_callback")
if callback and timer.timeout.is_connected(callback):
    timer.timeout.disconnect(callback)
state["current_timer_callback"] = null  # 清除引用

## 在 on_runtime_resume() 中也要存储新回调
var callback = _create_timer_callback(runtime_instance)
timer.timeout.connect(callback)
runtime_instance.register_timer_callback(callback)
state["current_timer_callback"] = callback  # 存储新回调引用
```

---

**最后更新:** 2026-03-10
**相关文件:**
- [runtime_instruction_instance.gd](../core/runtime_instruction_instance.gd)
- [base_instruction.gd](../core/base/base_instruction.gd)
- [wait.gd](../instructions/flow_control/wait.gd)
