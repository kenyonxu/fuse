# Instruction RuntimeInstance Migration Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 P0（5个）和 P1(17个)异步指令迁移到 RuntimeInstructionInstance 架构，解决多触发器并发执行状态冲突问题，支持暂停/恢复功能。

**Architecture:**
- 参考 Wait 指令的迁移模式（已完成）
- 使用自声明状态模式：指令通过 `get_default_runtime_state()` 声明运行时状态
- 使用 `runtime_state` 字典存储所有状态，替代实例变量
- 使用回调注册机制避免 bind 泄漏
- 添加暂停/恢复支持（`on_runtime_pause`, `on_runtime_resume`）

- 保留遗留 `execute()` 方法确保向后兼容

**Tech Stack:** GDScript 2.0, Godot 4.6, Bricks Plugin System

**Reference:** [runtime_instruction_instance_migration_guide.md](../addons/bricks/docs/developer/runtime_instruction_instance_migration_guide.md)

**Reference Implementation:** [wait.gd](../addons/bricks/instructions/flow_control/wait.gd)

---

## Phase 1: P0 高优先级指令迁移 (5个指令)

预计工时: 10-15 小时

### Task 1: WaitUntil 指令迁移

**Files:**
- Modify: `addons/bricks/instructions/flow_control/wait_until.gd`

**Step 1: 添加 `get_default_runtime_state()` 方法**

在 `_check_timer` 变量声明后添加:

```gdscript
## ============================================================
## 运行时实例模式支持（RuntimeInstructionInstance 架构）
## ============================================================

## 获取默认运行时状态
##
## 声明 WaitUntil 指令需要的运行时状态。
## 这些状态会在 RuntimeInstructionInstance 初始化时被复制。
func get_default_runtime_state() -> Dictionary:
    var state = super.get_default_runtime_state()
    state["check_timer"] = null  # 轮询计时器
    state["timeout_timer"] = null  # 超时计时器
    state["start_time"] = 0.0  # 开始时间
    state["current_poll_callback"] = null  # 存储回调引用
    state["current_timeout_callback"] = null  # 存储超时回调引用
    return state
```

**Step 2: 添加 `execute_with_runtime_instance()` 方法**

在 `execute()` 方法后添加.

```gdscript
## 使用运行时实例执行（推荐模式）
##
## 这种模式下，所有状态存储在 runtime_instance.runtime_state 中，
## 确保多个执行实例互不干扰。
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
    _start_execution(runtime_instance.execution_context)
    _log_debug_localized("BRICKS_LOG_INSTRUCTION_START", {"instruction": "WaitUntil"})

    var state = runtime_instance.runtime_state
    state["start_time"] = Time.get_ticks_msec() / 1000.0

    # 立即检查一次条件
    if _check_condition_from_state(runtime_instance):
        _log_info_localized("BRICKS_INSTRUCTION_WAIT_UNTIL_CONDITION_MET_IMMEDIATELY", {})
        runtime_instance._complete_execution()
        return true  # 同步完成

    # 开始轮询检查条件
    _log_info_localized("BRICKS_INSTRUCTION_WAIT_UNTIL_START_POLLING", {"interval": "%.2f" % check_interval})
    _start_runtime_polling(runtime_instance)
    return false  # 异步执行
```

**Step 3: 添加轮询方法**

```gdscript
## 开始运行时轮询
func _start_runtime_polling(runtime_instance: RuntimeInstructionInstance) -> void:
    var state = runtime_instance.runtime_state
    var context = runtime_instance.execution_context

    var scene_tree = Engine.get_main_loop()
    if not scene_tree:
        _log_error_localized("BRICKS_ERROR_CANNOT_GET_SCENETREE", {})
        runtime_instance._complete_execution()
        return

    var check_timer = scene_tree.create_timer(check_interval)
    state["check_timer"] = check_timer
    state["is_running"] = true

    var callback = _create_poll_callback(runtime_instance)
    check_timer.timeout.connect(callback)
    runtime_instance.register_timer_callback(callback)
    state["current_poll_callback"] = callback

    # 如果设置了超时，启动超时计时器
    if timeout > 0.0:
        _start_timeout_timer(runtime_instance)
```

**Step 4: 添加回调创建和超时方法**

```gdscript
## 创建轮询回调
func _create_poll_callback(runtime_instance: RuntimeInstructionInstance) -> Callable:
    var callback = func():
        _on_runtime_poll_timeout(runtime_instance)
    return callback

## 轮询超时回调
func _on_runtime_poll_timeout(runtime_instance: RuntimeInstructionInstance) -> void:
    if not runtime_instance or runtime_instance.is_completed():
        return

    var state = runtime_instance.runtime_state
    var context = runtime_instance.execution_context

    # 检查条件是否满足
    if _check_condition_from_state(runtime_instance):
        _log_info_localized("BRICKS_INSTRUCTION_WAIT_UNTIL_CONDITION_MET", {})
        _cleanup_runtime_timers(runtime_instance)
        runtime_instance._complete_execution()
        return

    # 检查是否超时
    if timeout > 0.0:
        var elapsed = (Time.get_ticks_msec() / 1000.0) - state.get("start_time", 0.0)
        if elapsed >= timeout:
            _log_warning_localized("BRICKS_INSTRUCTION_WAIT_UNTIL_TIMEOUT_REACHED", {"timeout": "%.1f" % timeout})
            set_error_localized("BRICKS_INSTRUCTION_WAIT_UNTIL_ERROR_TIMEOUT", BricksError.ErrorType.RUNTIME_ERROR, {})
            _cleanup_runtime_timers(runtime_instance)
            runtime_instance._complete_execution()
            return

    # 继续轮询
    _start_runtime_polling(runtime_instance)

## 启动超时计时器
func _start_timeout_timer(runtime_instance: RuntimeInstructionInstance) -> void:
    var state = runtime_instance.runtime_state
    var scene_tree = Engine.get_main_loop()
    if not scene_tree:
        return

    var timeout_timer = scene_tree.create_timer(timeout)
    state["timeout_timer"] = timeout_timer

    var callback = func():
        if not runtime_instance or runtime_instance.is_completed():
            return
        _on_runtime_timeout_reached(runtime_instance)
    timeout_timer.timeout.connect(callback)
    runtime_instance.register_timer_callback(callback)
    state["current_timeout_callback"] = callback

## 超时回调
func _on_runtime_timeout_reached(runtime_instance: RuntimeInstructionInstance) -> void:
    _log_warning_localized("BRICKS_INSTRUCTION_WAIT_UNTIL_TIMEOUT_REACHED", {"timeout": "%.1f" % timeout})
    set_error_localized("BRICKS_INSTRUCTION_WAIT_UNTIL_ERROR_TIMEOUT", BricksError.ErrorType.RUNTIME_ERROR, {})
    _cleanup_runtime_timers(runtime_instance)
    runtime_instance._complete_execution()

## 清理运行时计时器
func _cleanup_runtime_timers(runtime_instance: RuntimeInstructionInstance) -> void:
    var state = runtime_instance.runtime_state

    if state.has("check_timer") and state["check_timer"]:
        var timer = state["check_timer"]
        var callback = state.get("current_poll_callback")
        if callback and timer.timeout.is_connected(callback):
            timer.timeout.disconnect(callback)
        state["check_timer"] = null
        state["current_poll_callback"] = null

    if state.has("timeout_timer") and state["timeout_timer"]:
        var timer = state["timeout_timer"]
        var callback = state.get("current_timeout_callback")
        if callback and timer.timeout.is_connected(callback):
            timer.timeout.disconnect(callback)
        state["timeout_timer"] = null
        state["current_timeout_callback"] = null
```

**Step 5: 添加条件检查辅助方法**

```gdscript
## 从运行时状态检查条件
func _check_condition_from_state(runtime_instance: RuntimeInstructionInstance) -> bool:
    return _check_condition(runtime_instance.execution_context)
```

**Step 6: 添加暂停/恢复支持**

```gdscript
## 暂停处理
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
    var state = runtime_instance.runtime_state
    _cleanup_runtime_timers(runtime_instance)
    state["is_running"] = false

## 恢复处理
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
    var state = runtime_instance.runtime_state
    state["is_running"] = true
    # 重新开始轮询
    _start_runtime_polling(runtime_instance)
```

**Step 7: 运行 Godot 验证语法**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --check-only --quit`

Expected: No errors

**Step 8: 提交**

```bash
git add addons/bricks/instructions/flow_control/wait_until.gd
git commit -m "feat(bricks): migrate WaitUntil to RuntimeInstructionInstance architecture"
```

---

### Task 2: LoadSceneBackground 指令迁移

**Files:**
- Modify: `addons/bricks/instructions/scene/load_scene_background.gd`

**Step 1: 添加 `get_default_runtime_state()` 方法**

```gdscript
## ============================================================
## 运行时实例模式支持（RuntimeInstructionInstance 架构）
## ============================================================

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
    var state = super.get_default_runtime_state()
    state["timer"] = null
    state["timer_callback"] = null
    state["is_loading"] = false
    return state
```

**Step 2: 添加 `execute_with_runtime_instance()` 方法**

```gdscript
## 使用运行时实例执行（推荐模式）
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
    _start_execution(runtime_instance.execution_context)
    _log_debug_localized("BRICKS_LOG_INSTRUCTION_START", {"instruction": "LoadSceneBackground"})

    var state = runtime_instance.runtime_state
    var context = runtime_instance.execution_context

    # 验证场景路径
    if scene_path.is_empty():
        _log_error_localized("BRICKS_ERROR_SCENE_PATH_EMPTY", {})
        set_error_localized("BRICKS_ERROR_SCENE_PATH_EMPTY", BricksError.ErrorType.VALIDATION_ERROR, {})
        runtime_instance._complete_execution()
        return true

    # 验证变量名
    if save_to_variable.is_empty():
        _log_error_localized("BRICKS_ERROR_VAR_NAME_EMPTY", {})
        set_error_localized("BRICKS_ERROR_VAR_NAME_EMPTY", BricksError.ErrorType.VALIDATION_ERROR, {})
        runtime_instance._complete_execution()
        return true

    # 开始异步加载
    ResourceLoader.load_threaded_request(scene_path)
    state["is_loading"] = true
    _log_info_localized("BRICKS_INFO_SCENE_LOADING", {})

    # 创建定时器轮询加载状态
    var scene_tree = Engine.get_main_loop()
    if not scene_tree:
        _log_error_localized("BRICKS_ERROR_CANNOT_CREATE_TIMER", {})
        runtime_instance._complete_execution()
        return true

    var timer = scene_tree.create_timer(0.1)
    state["timer"] = timer
    var callback = _create_load_callback(runtime_instance)
    timer.timeout.connect(callback)
    runtime_instance.register_timer_callback(callback)
    state["timer_callback"] = callback

    return false  # 异步执行
```

**Step 3: 添加回调创建和状态检查方法**

```gdscript
## 创建加载回调
func _create_load_callback(runtime_instance: RuntimeInstructionInstance) -> Callable:
    var callback = func():
        _check_load_status(runtime_instance)
    return callback

## 检查加载状态
func _check_load_status(runtime_instance: RuntimeInstructionInstance) -> void:
    if not runtime_instance or runtime_instance.is_completed():
        return

    var state = runtime_instance.runtime_state
    var context = runtime_instance.execution_context

    var status = ResourceLoader.load_threaded_get_status(scene_path)

    if status == ResourceLoader.THREAD_LOAD_LOADED:
        # 加载完成
        var packed_scene = ResourceLoader.load_threaded_get(scene_path)
        if packed_scene is PackedScene:
            _save_scene_to_variable(runtime_instance, packed_scene)
            _log_info_localized("BRICKS_INFO_SCENE_LOADED", {"var": save_to_variable})
        else:
            _log_error_localized("BRICKS_ERROR_CANNOT_LOAD_SCENE", {"scene": scene_path})
            set_error_localized("BRICKS_ERROR_CANNOT_LOAD_SCENE", BricksError.ErrorType.RUNTIME_ERROR, {"scene": scene_path})

        _cleanup_load_timer(runtime_instance)
        runtime_instance._complete_execution()
    elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
        # 继续等待
        var scene_tree = Engine.get_main_loop()
        if scene_tree:
            var timer = scene_tree.create_timer(0.1)
            state["timer"] = timer
            var callback = _create_load_callback(runtime_instance)
            timer.timeout.connect(callback)
            runtime_instance.register_timer_callback(callback)
            state["timer_callback"] = callback
    else:
        _log_error_localized("BRICKS_ERROR_CANNOT_CREATE_TIMER", {})
        _cleanup_load_timer(runtime_instance)
        runtime_instance._complete_execution()
    else:
        # 加载失败
        _log_error_localized("BRICKS_ERROR_CANNOT_LOAD_SCENE", {"scene": scene_path})
        set_error_localized("BRICKS_ERROR_CANNOT_LOAD_SCENE", BricksError.ErrorType.RUNTIME_ERROR, {"scene": scene_path})
        _cleanup_load_timer(runtime_instance)
        runtime_instance._complete_execution()
```

**Step 4: 添加辅助方法**

```gdscript
## 保存场景到变量
func _save_scene_to_variable(runtime_instance: RuntimeInstructionInstance, packed_scene: PackedScene) -> void:
    var context = runtime_instance.execution_context
    match save_to_scope:
        BaseVariable.VariableScope.LOCAL:
            VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.LOCAL, packed_scene)
        BaseVariable.VariableScope.SCOPE:
            if scope_source == ScopeSource.NEAREST:
                VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.SCOPE, packed_scene)
            else:
                var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
                var scope_container = VariableScopeUtils.get_scope_container_by_source(
                    context, utils_scope_source, custom_scope_id, target_node_path
                )
                if scope_container == null:
                    _log_error_localized("BRICKS_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
                    return
                scope_container.set_variable(save_to_variable, packed_scene)
        BaseVariable.VariableScope.GLOBAL:
            VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.GLOBAL, packed_scene)

## 清理加载计时器
func _cleanup_load_timer(runtime_instance: RuntimeInstructionInstance) -> void:
    var state = runtime_instance.runtime_state
    state["is_loading"] = false
    if state.has("timer") and state["timer"]:
        var timer = state["timer"]
        var callback = state.get("timer_callback")
        if callback and timer.timeout.is_connected(callback):
            timer.timeout.disconnect(callback)
        state["timer"] = null
        state["timer_callback"] = null
```

**Step 5: 添加暂停/恢复支持**

```gdscript
## 暂停处理
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
    var state = runtime_instance.runtime_state
    _cleanup_load_timer(runtime_instance)

    state["is_loading"] = false
## 恢复处理
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
    var state = runtime_instance.runtime_state
    if state.get("is_loading", false) == false and not scene_path.is_empty():
        # 重新开始轮询
        var scene_tree = Engine.get_main_loop()
        if scene_tree:
            state["is_loading"] = true
            var timer = scene_tree.create_timer(0.1)
            state["timer"] = timer
            var callback = _create_load_callback(runtime_instance)
            timer.timeout.connect(callback)
            runtime_instance.register_timer_callback(callback)
            state["timer_callback"] = callback
```

**Step 6: 运行 Godot 验证语法**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --check-only --quit`
Expected: No errors

**Step 7: 提交**

```bash
git add addons/bricks/instructions/scene/load_scene_background.gd
git commit -m "feat(bricks): migrate LoadSceneBackground to RuntimeInstructionInstance architecture"
```

---

### Task 3: ForLoop 指令迁移

**Files:**
- Modify: `addons/bricks/instructions/flow_control/for_loop.gd`

**Step 1: 添加 `get_default_runtime_state()` 方法**

```gdscript
## ============================================================
## 运行时实例模式支持（RuntimeInstructionInstance 架构）
## ============================================================
## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
    var state = super.get_default_runtime_state()
    state["current_index"] = 0
    state["loop_count"] = 0
    state["is_running"] = false
    state["current_instruction_index"] = 0
    state["is_executing_instruction"] = false
    return state
```

**Step 2: 添加 `execute_with_runtime_instance()` 方法**

```gdscript
## 使用运行时实例执行（推荐模式）
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
    _start_execution(runtime_instance.execution_context)
    _log_debug_localized("BRICKS_LOG_INSTRUCTION_START", {"instruction": "ForLoop"})

    var state = runtime_instance.runtime_state
    var context = runtime_instance.execution_context
    # 获取循环次数
    var actual_loop_count = _get_loop_count(context)
    if actual_loop_count <= 0:
        _log_info_localized("BRICKS_LOG_FOR_LOOP_ZERO_ITERATIONS", {})
        runtime_instance._complete_execution()
        return true
    state["loop_count"] = actual_loop_count
    state["current_index"] = 0
    state["is_running"] = true
    # 开始执行第一条指令
    _execute_next_instruction(runtime_instance)
    return false  # 异步执行
```

**Step 3: 添加循环执行方法**

```gdscript
## 执行下一条指令
func _execute_next_instruction(runtime_instance: RuntimeInstructionInstance) -> void:
    var state = runtime_instance.runtime_state
    var context = runtime_instance.execution_context
    if state["current_index"] >= state["loop_count"]:
        # 循环完成
        _log_info_localized("BRICKS_LOG_FOR_LOOP_COMPLETE", {"count": str(state["loop_count"])})
        state["is_running"] = false
        runtime_instance._complete_execution()
        return
    # 更新索引变量
    if use_index_variable:
        _set_index_variable(context, state["current_index"])
    # 执行指令序列
    _execute_instruction_sequence(runtime_instance)
## 执行指令序列
func _execute_instruction_sequence(runtime_instance: RuntimeInstructionInstance) -> void:
    var state = runtime_instance.runtime_state
    state["is_executing_instruction"] = true
    # 根据 sequence_mode 执行指令
    match sequence_mode:
        SequenceMode.SYNCHRONOUS:
            _execute_sequence_sync(runtime_instance)
        SequenceMode.ASYNCHRONOUS:
            _execute_sequence_async(runtime_instance)
## 执行序列（同步模式）
func _execute_sequence_sync(runtime_instance: RuntimeInstructionInstance) -> void:
    var state = runtime_instance.runtime_state
    var context = runtime_instance.execution_context
    for instruction in loop_instructions:
        if instruction:
            instruction.execute(context)
    # 同步模式完成， _on_sequence_completed(runtime_instance)
## 执行序列（异步模式）
func _execute_sequence_async(runtime_instance: RuntimeInstructionInstance) -> void:
    var state = runtime_instance.runtime_state
    # 执行当前索引的指令序列（异步等待）
    _execute_and_wait_for_sequence(runtime_instance)
```

**Step 4: 添加序列完成回调**

```gdscript
## 序列执行完成回调
func _on_sequence_completed(runtime_instance: RuntimeInstructionInstance) -> void:
    var state = runtime_instance.runtime_state
    if not state["is_running"]:
        return
    state["is_executing_instruction"] = false
    state["current_index"] = state["current_index"] + 1
    # 继续下一条
    _execute_next_instruction(runtime_instance)
```

**Step 5: 添加暂停/恢复支持**

```gdscript
## 暂停处理
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
    var state = runtime_instance.runtime_state
    state["is_running"] = false
    # 循环指令的暂停由各自的 RuntimeInstance 处理
## 恢复处理
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
    var state = runtime_instance.runtime_state
    state["is_running"] = true
    # 继续执行
    if state["is_executing_instruction"]:
        # 当前指令会自行恢复
        pass
    else:
        _execute_next_instruction(runtime_instance)
```

**Step 6: 运行 Godot 验证语法**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --check-only --quit`
Expected: No errors
**Step 7: 提交**

```bash
git add addons/bricks/instructions/flow_control/for_loop.gd
git commit -m "feat(bricks): migrate ForLoop to RuntimeInstructionInstance architecture"
```
---

### Task 4: ForEach 指令迁移

**Files:**
- Modify: `addons/bricks/instructions/flow_control/for_each.gd`

**Step 1-7: 与 ForLoop 相同的模式**
- 添加 `get_default_runtime_state()`
- 添加 `execute_with_runtime_instance()`
- 添加遍历执行方法
- 添加暂停/恢复支持
- 验证语法
- 提交

*(详细代码略，参考 ForLoop 模式)*

---

### Task 5: WhileLoop 指令迁移

**Files:**
- Modify: `addons/bricks/instructions/flow_control/while_loop.gd`

**Step 1-7: 与 ForLoop 相同的模式**
- 添加 `get_default_runtime_state()`
- 添加 `execute_with_runtime_instance()`
- 添加循环条件检查方法
- 添加暂停/恢复支持
- 验证语法
- 提交
*(详细代码略，参考 ForLoop 模式)*
---

## Phase 2: P1 中优先级指令迁移（部分核心指令）

预计工时: 17-34 小时

### Task 6: CameraShake 指令迁移

**Files:**
- Modify: `addons/bricks/instructions/camera/camera_shake.gd`

**Step 1: 添加 `get_default_runtime_state()` 方法**

```gdscript
## ============================================================
## 运行时实例模式支持（RuntimeInstructionInstance 架构）
## ============================================================
## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
    var state = super.get_default_runtime_state()
    state["tween"] = null
    state["original_offset"] = Vector2.ZERO
    state["is_running"] = false
    state["tween_callback"] = null
    return state
```

**Step 2: 添加 `execute_with_runtime_instance()` 方法**

```gdscript
## 使用运行时实例执行（推荐模式）
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
    _start_execution(runtime_instance.execution_context)
    _log_debug_localized("BRICKS_LOG_INSTRUCTION_START", {"instruction": "CameraShake"})

    var state = runtime_instance.runtime_state
    var context = runtime_instance.execution_context
    # 获取目标相机
    var camera := context.get_node(target_node)
    if not camera:
        _log_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
        set_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
        runtime_instance._complete_execution()
        return true
    if not camera is Camera2D:
        _log_error_localized("BRICKS_ERROR_CAMERA_NOT_CAMERA2D", {})
        set_error_localized("BRICKS_ERROR_CAMERA_NOT_CAMERA2D", BricksError.ErrorType.RUNTIME_ERROR, {})
        runtime_instance._complete_execution()
        return true
    var camera_2d := camera as Camera2D
    if duration <= 0.0:
        _log_error_localized("BRICKS_ERROR_SHAKE_DURATION_INVALID", {})
        set_error_localized("BRICKS_ERROR_SHAKE_DURATION_INVALID", BricksError.ErrorType.VALIDATION_ERROR, {})
        runtime_instance._complete_execution()
        return true
    # 执行抖动
    _execute_shake_runtime(runtime_instance, camera_2d)
    return false  # 异步执行
```

**Step 3: 添加抖动执行方法**

```gdscript
## 执行相机抖动（运行时版本）
func _execute_shake_runtime(runtime_instance: RuntimeInstructionInstance, camera: Camera2D) -> void:
    var state = runtime_instance.runtime_state
    state["original_offset"] = camera.offset
    var scene_tree := Engine.get_main_loop()
    if not scene_tree:
        _log_error_localized("BRICKS_ERROR_CANNOT_CREATE_TWEEN", {})
        runtime_instance._complete_execution()
        return
    var tween = scene_tree.create_tween()
    state["tween"] = tween
    state["is_running"] = true
    # 创建抖动动画
    var shake_count := int(duration * SHAKE_FPS)
    for i in shake_count:
        var random_offset := Vector2(
            randf_range(-intensity * 20, intensity * 20),
            randf_range(-intensity * 20, intensity * 20)
        )
        var frame_time := 1.0 / SHAKE_FPS
        tween.tween_property(camera, "offset", random_offset, frame_time)
        tween.tween_property(camera, "offset", state["original_offset"], frame_time)
    # 连接完成回调
    var callback = func():
        _on_shake_completed(runtime_instance, camera)
    tween.finished.connect(callback)
    runtime_instance.register_timer_callback(callback)
    state["tween_callback"] = callback
    _log_info("相机抖动开始 (强度: %.1f, 时间: %.1f秒)" % [intensity, duration])
## 抖动完成回调
func _on_shake_completed(runtime_instance: RuntimeInstructionInstance, camera: Camera2D) -> void:
    if not runtime_instance or runtime_instance.is_completed():
        return
    var state = runtime_instance.runtime_state
    if not is_instance_valid(camera):
        _log_warning("相机对象已在抖动过程中被销毁")
        runtime_instance._complete_execution()
        return
    if not camera.is_inside_tree():
        _log_warning("相机已从场景树中移除")
        runtime_instance._complete_execution()
        return
    camera.offset = state["original_offset"]
    state["tween"] = null
    state["is_running"] = false
    _log_info("相机抖动完成")
    runtime_instance._complete_execution()
```

**Step 4: 添加暂停/恢复和取消支持**

```gdscript
## 暂停处理
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
    var state = runtime_instance.runtime_state
    if state.has("tween") and state["tween"]:
        var tween = state["tween"]
        tween.pause()
    state["is_running"] = false
## 恢复处理
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
    var state = runtime_instance.runtime_state
    state["is_running"] = true
    if state.has("tween") and state["tween"]:
        var tween = state["tween"]
        tween.play()
## 取消指令执行
func cancel():
    if is_running():
        var tween = _get_current_tween()
        if tween and is_instance_valid(tween):
            tween.kill()
        super.cancel()
```

**Step 5: 运行 Godot 验证语法**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --check-only --quit`
Expected: No errors
**Step 6: 提交**

```bash
git add addons/bricks/instructions/camera/camera_shake.gd
git commit -m "feat(bricks): migrate CameraShake to RuntimeInstructionInstance architecture"
```
---

### Task 7-11: Tween 动画系列迁移

**Files:**
- `addons/bricks/instructions/tween/tween_fade_in.gd`
- `addons/bricks/instructions/tween/tween_fade_out.gd`
- `addons/bricks/instructions/tween/tween_move_to.gd`
- `addons/bricks/instructions/tween/tween_scale_to.gd`
- `addons/bricks/instructions/tween/tween_rotate_to.gd`

**通用模式（继承 BaseTweenInstruction）:**
1. 在 `BaseTweenInstruction` 中添加默认运行时状态
2. 各动画指令继承基类实现

3. 添加暂停/恢复支持

4. 验证并提交
*(详细代码略，参考 CameraShake 模式)*
---

### Task 12-14: 音频指令迁移

**Files:**
- `addons/bricks/instructions/audio/crossfade_to_music.gd`
- `addons/bricks/instructions/audio/play_music.gd`

**模式:**
1. 添加 `get_default_runtime_state()` - 存储 Tween、AudioStreamPlayer 引用
2. 添加 `execute_with_runtime_instance()`
3. 添加暂停/恢复支持
4. 验证并提交
*(详细代码略)*
---
### Task 15: ChangeScene 迁移
**Files:**
- `addons/bricks/instructions/scene_management/change_scene.gd`

**模式:**
1. 添加 `get_default_runtime_state()`
2. 添加 `execute_with_runtime_instance()`
3. 验证并提交
*(详细代码略)*
---

## Phase 3: 测试验证

### Task 16: 创建并发执行测试

**Files:**
- Create: `addons/bricks/tests/test_instruction_concurrent_execution.gd`
- Create: `addons/bricks/tests/test_instruction_concurrent_execution.tscn`

**Step 1: 编写测试脚本**

```gdscript
extends Node
class_name TestInstructionConcurrentExecution
## 测试指令并发执行
##
## 验证多个触发器同时执行同一指令资源时状态隔离

# 测试场景
var _test_scene: Node
# Wait 指令资源
var _wait_instruction: BaseInstruction
# 测试结果
var _results: Array[Dictionary] = []

func _ready():
    # 创建测试场景
    _test_scene = Node.new()
    _test_scene.name = "TestScene"
    add_child(_test_scene)

    # 加载 Wait 指令
    var wait_script = load("res://addons/bricks/instructions/flow_control/wait.gd")
    if wait_script:
        _wait_instruction = wait_script.new()
        _wait_instruction.wait_time = 0.5

func _test_concurrent_wait():
    _results.clear()
    # 创建三个并发的执行上下文
    var contexts: Array[ExecutionContext] = []
    for i in range(3):
        var context = ExecutionContext.new()
        context.trigger_node = _test_scene
        contexts.append(context)
    # 同时执行 Wait 指令
    var start_time = Time.get_ticks_msec()
    var instances: Array[RuntimeInstructionInstance] = []
    for context in contexts:
        var instance = RuntimeInstructionInstance.new(_wait_instruction, context)
        instances.append(instance)
        instance.finished.connect(_on_instance_finished.bind(instance))
        instance.execute_sync()
    # 等待所有实例完成
    await get_tree().create_timer(2.0).timeout
    # 验证结果
    var all_completed = instances.all(func(i): return i.is_completed())
    assert(all_completed, "所有实例应该完成")
    # 验证时间（应该接近并行，约 0.5 秒）
    var elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
    assert(elapsed < 1.0, "并发执行应该在 1 秒内完成，实际: %.2f" % elapsed)
    print("并发执行测试通过！")

func _on_instance_finished(instance: RuntimeInstructionInstance):
    var result = {
        "completed": instance.is_completed(),
        "has_error": instance.has_error(),
        "error": instance.get_error_message() if instance.has_error() else ""
    }
    _results.append(result)
```

**Step 2: 创建测试场景**

```gdscript
# test_instruction_concurrent_execution.tscn
[gd_scene load_steps=2 format=3 uid="uid://test_concurrent_execution"]

[ext_resource type="Script" path="res://addons/bricks/tests/test_instruction_concurrent_execution.gd" id="1_xxxxx"]
[node name="TestScene" type="Node" parent="."]

[node name="Timer" type="Timer" parent="TestScene"]
[connection signal="timeout" from="Timer" to="Script" method="_test_concurrent_wait"]
```

**Step 3: 运行测试**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --run-scene addons/bricks/tests/test_instruction_concurrent_execution.tscn --quit`
Expected: 输出 "并发执行测试通过!"

**Step 4: 提交**

```bash
git add addons/bricks/tests/test_instruction_concurrent_execution.gd
git add addons/bricks/tests/test_instruction_concurrent_execution.tscn
git commit -m "test(bricks): add concurrent execution test for RuntimeInstance"
```
---

## 迁移检查清单

迁移一个指令需要检查以下内容：
- [ ] 添加 `get_default_runtime_state()` 方法声明状态
- [ ] 添加 `execute_with_runtime_instance()` 方法
- [ ] 将实例变量改为使用 `runtime_state` 字典
- [ ] 使用回调注册机制而非 `bind()`
- [ ] 实现暂停/恢复回调（如需要）
- [ ] 保留原有 `execute()` 方法（兼容性）
- [ ] 测试并发执行隔离

- [ ] 更新迁移指南文档
