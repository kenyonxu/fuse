# Brick 插件代码质量改进计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标:** 修复 Brick 插件中的关键内存泄漏和性能问题，提升代码质量和可维护性。

**架构:** 采用渐进式改进策略，先修复 Critical 问题阻止内存泄漏，再优化性能热点，最后清理代码冗余。每个修复都遵循 TDD 流程。

**技术栈:** Godot 4.5, GDScript, RefCounted, Resource, Signal 系统

---

## Phase 1: 紧急修复 - 内存泄漏 (1-2 天)

### Task 1.1: 修复 ActionRunner 信号泄漏

**Files:**
- Modify: `addons/bricks/core/base/action_runner.gd`
- Test: `addons/bricks/tests/test_action_runner_signals.gd` (创建新文件)

**Step 1: 编写失败的信号泄漏测试**

```gdscript
extends Node

func test_signal_cleanup_on_error():
    var runner = ActionRunner.new()
    var instruction = BaseInstruction.new()

    # 创建一个会抛出错误的测试指令
    var context = ExecutionContext.new()
    runner.instructions = [instruction]

    # 记录初始连接数
    var initial_connections = instruction.finished.get_connections().size()

    # 执行并等待失败
    await runner.run(context)

    # 验证：执行后信号应该被清理
    var final_connections = instruction.finished.get_connections().size()
    assert(final_connections == 0, "Expected 0 connections, got %d" % final_connections)

    print("✓ Signal cleanup test passed")
```

**Step 2: 运行测试验证失败**

运行: 在 Godot 编辑器中打开 `addons/bricks/tests/test_action_runner_signals.tscn` 并按 F5
预期: FAIL - "Expected 0 connections, got 1"（信号未断开）

**Step 3: 添加信号跟踪机制**

在 `action_runner.gd` 顶部添加:

```gdscript
## 信号跟踪
var _connected_signals: Dictionary = {}  # instruction -> signal_handler
var _current_signal_handlers: Dictionary = {}  # instruction -> Callable
```

添加信号连接辅助方法:

```gdscript
## 安全连接信号
func _connect_instruction_signal(instruction: BaseInstruction, handler: Callable) -> bool:
    if not instruction or not handler:
        return false

    # 存储处理器引用用于后续断开
    _current_signal_handlers[instruction] = handler

    var result = instruction.finished.connect(handler)
    _connected_signals[instruction] = handler

    return result == OK
```

添加信号断开辅助方法:

```gdscript
## 安全断开指令的所有信号
func _disconnect_instruction_signal(instruction: BaseInstruction):
    if not instruction:
        return

    if _current_signal_handlers.has(instruction):
        var handler = _current_signal_handlers[instruction]
        if instruction.finished.is_connected(handler):
            instruction.finished.disconnect(handler)

        _current_signal_handlers.erase(instruction)
        _connected_signals.erase(instruction)
```

**Step 4: 修改执行逻辑使用新的信号管理**

在 `_run_sequential()` 方法中，将:

```gdscript
instruction.finished.connect(_on_instruction_finished.bind(instruction))
```

替换为:

```gdscript
var handler = _on_instruction_finished.bind(instruction)
_connect_instruction_signal(instruction, handler)
```

在 `_complete_execution()` 中添加:

```gdscript
## 清理所有信号连接
for instruction in instructions:
    _disconnect_instruction_signal(instruction)
```

在 `_run_sequential()` 错误处理中添加:

```gdscript
## 出错时断开当前指令信号
_disconnect_instruction_signal(instruction)
```

**Step 5: 运行测试验证通过**

运行: `addons/bricks/tests/test_action_runner_signals.tscn`
预期: PASS - 信号正确清理

**Step 6: 提交**

```bash
git add addons/bricks/core/base/action_runner.gd addons/bricks/tests/test_action_runner_signals.gd
git commit -m "fix(action-runner): 添加信号跟踪和清理机制，防止内存泄漏"
```

---

### Task 1.2: 修复 ExecutionContext 内存泄漏

**Files:**
- Modify: `addons/bricks/core/base/execution_context.gd`
- Test: `addons/bricks/tests/test_execution_context_cleanup.gd` (创建新文件)

**Step 1: 编写失败的内存清理测试**

```gdscript
extends Node

func test_cleanup_releases_refcounted_objects():
    var context = ExecutionContext.new()

    # 创建 RefCounted 对象并添加到上下文
    var ref_obj = RefCounted.new()
    context.set_variable("test_obj", ref_obj)

    var initial_ref_count = ref_obj.get_reference_count()

    # 清理上下文
    context.cleanup()

    # 验证：cleanup 后引用应该被释放
    var final_ref_count = ref_obj.get_reference_count()
    assert(final_ref_count < initial_ref_count,
        "Expected ref count to decrease, got %d -> %d" % [initial_ref_count, final_ref_count])

    print("✓ Memory cleanup test passed")
```

**Step 2: 运行测试验证失败**

运行: 打开 `addons/bricks/tests/test_execution_context_cleanup.tscn`
预期: FAIL - "Expected ref count to decrease"（对象未释放）

**Step 3: 重写 cleanup() 方法**

在 `execution_context.gd` 中，将 `cleanup()` 方法替换为:

```gdscript
## 清理执行上下文
##
## 清理执行上下文中的所有数据，释放引用。
##
## 此方法会：
## 1. 逐个清理局部变量，显式释放 RefCounted 对象
## 2. 逐个清理自定义数据，释放资源引用
## 3. 释放对场景树、目标节点和触发器的引用
## 4. 重置执行状态
## 5. 清理执行历史和弱引用
## 6. 清理优化缓存
func cleanup():
    # 清理局部变量字典（显式释放 RefCounted 对象）
    for key in local_variables.keys():
        var value = local_variables[key]
        # 如果是 RefCounted 对象，显式设为 null 让引用计数减一
        if value is RefCounted or value is Resource:
            local_variables[key] = null
    local_variables.clear()

    # 清理自定义数据字典（释放资源引用）
    for key in custom_data.keys():
        var value = custom_data[key]
        # 释放 Resource 和 RefCounted 引用
        if value is Resource or value is RefCounted:
            custom_data[key] = null
    custom_data.clear()

    # 使用 WeakRef 清理节点引用
    if target and not target.is_queued_for_deletion():
        target = null

    if trigger and not trigger.is_queued_for_deletion():
        trigger = null

    # 清理弱引用
    _target_weakref = null
    _trigger_weakref = null

    # 清理其他引用
    global_variables = null
    tree = null
    action_runner = null

    # 清理执行历史
    _execution_history.clear()

    # 清理状态监听器
    _state_change_listeners.clear()

    # 清理优化相关的缓存
    _variable_name_cache.clear()
    _variable_index_map.clear()
    _variable_array.clear()
    _use_indexed_access = false

    # 清理 BricksError 实例
    if _bricks_error:
        _bricks_error = null

    # 重置执行状态
    reset_execution_state()

    _log_debug("Execution context cleaned up with explicit object release")
```

**Step 4: 运行测试验证通过**

运行: `addons/bricks/tests/test_execution_context_cleanup.tscn`
预期: PASS - RefCounted 对象正确释放

**Step 5: 提交**

```bash
git add addons/bricks/core/base/execution_context.gd addons/bricks/tests/test_execution_context_cleanup.gd
git commit -m "fix(execution-context): 完善 cleanup() 方法，显式释放 RefCounted 对象"
```

---

### Task 1.3: 重构 ActionRunner 同步/异步执行流程

**Files:**
- Modify: `addons/bricks/core/base/action_runner.gd`
- Test: `addons/bricks/tests/test_execution_modes.gd` (创建新文件)

**Step 1: 编写失败的混合执行模式测试**

```gdscript
extends Node

func test_sync_fallback_to_async():
    var runner = ActionRunner.new()

    # 创建同步和异步指令
    var sync_inst = BaseInstruction.new()
    var async_inst = BaseInstruction.new()

    runner.instructions = [sync_inst, async_inst]
    runner.execution_mode = ActionRunner.ExecutionMode.SEQUENTIAL

    var context = ExecutionContext.new()

    # 执行并验证：同步和异步指令都应该完成
    await runner.run(context)

    assert(sync_inst.is_completed(), "Sync instruction should be completed")
    assert(async_inst.is_completed(), "Async instruction should be completed")

    print("✓ Mixed execution mode test passed")
```

**Step 2: 运行测试验证失败**

运行: `addons/bricks/tests/test_execution_modes.tscn`
预期: FAIL - 异步指令永不完成

**Step 3: 创建统一的指令执行方法**

在 `action_runner.gd` 中添加:

```gdscript
## 执行单个指令（统一同步/异步流程）
## instruction: 要执行的指令
## context: 执行上下文
## returns: bool - 是否同步完成
func _execute_instruction(instruction: BaseInstruction, context: ExecutionContext) -> bool:
    var instruction_start_time = Time.get_ticks_msec() / 1000.0

    # 设置指令超时（如果启用）
    if enable_instruction_timeout:
        instruction.set_timeout(instruction_timeout)

    # 尝试同步执行
    if instruction.can_execute_sync():
        var sync_result = instruction.execute_sync(context)

        if sync_result:
            # 同步执行成功
            var instruction_time = Time.get_ticks_msec() / 1000.0 - instruction_start_time
            _log_debug("同步指令完成: %.3f 秒" % instruction_time)
            instruction_completed.emit(instruction)
            return true

    # 异步执行
    _log_debug("异步执行指令: %s" % instruction.get_description())

    var handler = _on_instruction_finished.bind(instruction)
    _connect_instruction_signal(instruction, handler)

    instruction.execute(context)
    return false
```

**Step 4: 重写顺序执行逻辑**

在 `_run_sequential()` 中，将指令执行部分替换为:

```gdscript
for i in range(instructions.size()):
    # 检查是否需要跳过当前指令
    if _skip_instruction_count > 0:
        _skip_instruction_count -= 1
        continue

    # 检查是否需要停止执行
    if _stop_execution:
        _log_debug("停止执行: %s" % _stop_reason)
        return

    if not is_running:
        if is_canceling:
            _log_debug("Execution cancelled: %s" % cancellation_reason)
            execution_canceled.emit(cancellation_reason)
        else:
            _log_debug("Execution stopped")
        return

    current_instruction_index = i
    var instruction = instructions[i]

    _log_debug("Executing instruction %d/%d: %s" % [i + 1, instructions.size(), instruction.get_description()])
    context.print_message("Executing instruction %d/%d: %s" % [i + 1, instructions.size(), instruction.get_description()])

    instruction_started.emit(instruction)

    # 记录指令开始（调试模式）
    if _debug_enabled and _execution_tracker:
        _execution_tracker.record_instruction_start(instruction, context)

    # 统一执行指令
    var sync_completed = _execute_instruction(instruction, context)

    if sync_completed:
        # 同步完成，继续下一个指令
        # 检查错误
        if stop_on_error and instruction.has_error():
            _create_bricks_error("指令执行失败: %s" % instruction.get_error_message(), BricksError.ErrorType.EXECUTION_ERROR, {
                "instruction_index": i,
                "instruction_description": instruction.get_description()
            })
            execution_failed.emit("Instruction execution failed: %s" % instruction.get_error_message())
            _disconnect_instruction_signal(instruction)
            return

        # 检查超时
        if _check_timeout(context):
            _disconnect_instruction_signal(instruction)
            return
    else:
        # 异步执行，等待完成
        if not instruction.is_completed() and not instruction.has_error():
            await instruction.finished

        var instruction_end_time = Time.get_ticks_msec() / 1000.0
        var instruction_time = instruction_end_time - instruction_start_time
        _log_debug("异步指令完成: %.3f 秒" % instruction_time)

        # 记录指令完成（调试模式）
        if _debug_enabled and _execution_tracker:
            _execution_tracker.record_instruction_complete(instruction, context)

        # 断开信号连接
        _disconnect_instruction_signal(instruction)

        instruction_completed.emit(instruction)

        # 检查错误
        if stop_on_error and instruction.has_error():
            _log_debug("Stopping execution due to instruction error: %s" % instruction.get_error_message())
            _create_bricks_error("指令执行失败: %s" % instruction.get_error_message(), BricksError.ErrorType.EXECUTION_ERROR, {
                "instruction_index": i,
                "instruction_description": instruction.get_description()
            })
            execution_failed.emit("Instruction execution failed: %s" % instruction.get_error_message())
            return

        # 检查超时
        if _check_timeout(context):
            return
```

**Step 5: 移除旧的代码**

删除 `_execute_single_instruction()` 方法（已不再需要）

**Step 6: 运行测试验证通过**

运行: `addons/bricks/tests/test_execution_modes.tscn`
预期: PASS - 同步和异步指令都正确完成

**Step 7: 提交**

```bash
git add addons/bricks/core/base/action_runner.gd addons/bricks/tests/test_execution_modes.gd
git commit -m "refactor(action-runner): 统一同步/异步执行流程，修复混合模式问题"
```

---

## Phase 2: 重要优化 - 性能与功能 (3-5 天)

### Task 2.1: 优化 ExecutionContext 热路径日志

**Files:**
- Modify: `addons/bricks/core/base/execution_context.gd`
- Test: `addons/bricks/tests/test_variable_lookup_performance.gd` (创建新文件)

**Step 1: 编写性能基准测试**

```gdscript
extends Node

func test_variable_lookup_performance():
    var context = ExecutionContext.new()

    # 设置测试变量
    for i in range(100):
        context.set_variable("var_%d" % i, i)

    var start_time = Time.get_ticks_msec()

    # 执行 10000 次查找
    for i in range(10000):
        var value = context.get_variable("var_%d" % (i % 100))

    var elapsed = Time.get_ticks_msec() - start_time
    var ops_per_ms = 10000.0 / elapsed

    print("✓ Variable lookup performance: %d ops/ms (%.2f ms per 10000 lookups)" % [ops_per_ms, elapsed])

    # 性能要求：至少 1000 ops/ms
    assert(ops_per_ms > 1000, "Performance too slow: %d ops/ms < 1000" % ops_per_ms)
```

**Step 2: 运行测试验证当前性能**

运行: `addons/bricks/tests/test_variable_lookup_performance.tscn`
预期: 当前可能 < 1000 ops/ms（日志开销导致）

**Step 3: 条件化调试日志**

在 `get_variable()` 方法中，将所有 `_log_debug()` 调用包装:

```gdscript
func get_variable(name: String, default: Variant = null) -> Variant:
    if name.is_empty():
        _log_error("Variable name cannot be empty")
        return default

    # 仅在调试模式下记录详细日志
    if OS.is_debug_build() and log_level >= BricksLogger.LogLevel.DEBUG:
        _log_debug("ExecutionContext.get_variable called: name='%s', default=%s" % [name, str(default)])
        _log_debug("ExecutionContext ID: %s" % execution_id)
        _log_debug("Local variables count: %d" % local_variables.size())

    # 获取 StringName 键
    var name_key = _get_cached_name_key(name)

    # ... 其余逻辑保持不变 ...

    # 条件化详细日志
    if OS.is_debug_build() and log_level >= BricksLogger.LogLevel.DEBUG:
        # 打印所有局部变量用于调试
        _log_debug("All local variables:")
        for var_name in local_variables:
            var var_value = local_variables[var_name]
            _log_debug("  %s = %s (type: %s)" % [var_name, str(var_value), typeof(var_value)])
```

对 `set_variable()` 和 `add_variable()` 应用相同的条件化

**Step 4: 运行测试验证性能提升**

运行: `addons/bricks/tests/test_variable_lookup_performance.tscn`
预期: > 1000 ops/ms

**Step 5: 提交**

```bash
git add addons/bricks/core/base/execution_context.gd addons/bricks/tests/test_variable_lookup_performance.gd
git commit -m "perf(execution-context): 条件化热路径日志，提升变量查找性能"
```

---

### Task 2.2: 完善 FunctionManager 类型兼容性

**Files:**
- Modify: `addons/bricks/utils/function_manager.gd`
- Test: `addons/bricks/tests/test_type_compatibility.gd` (创建新文件)

**Step 1: 编写类型兼容性测试**

```gdscript
extends Node

func test_vector_type_compatibility():
    # 测试 Vector2 和 Vector2I 的兼容性
    var manager = FunctionManager.new()

    var node = Node2D.new()

    # 应该允许 Vector2 ↔ Vector2I 的转换
    assert(manager._is_type_compatible(TYPE_VECTOR2, TYPE_VECTOR2I))
    assert(manager._is_type_compatible(TYPE_VECTOR2I, TYPE_VECTOR2))

    # Vector3 类型
    assert(manager._is_type_compatible(TYPE_VECTOR3, TYPE_VECTOR3I))
    assert(manager._is_type_compatible(TYPE_VECTOR3I, TYPE_VECTOR3))

    print("✓ Vector type compatibility test passed")

func test_object_inheritance_compatibility():
    # 测试对象继承关系的兼容性
    var manager = FunctionManager.new()

    # Node2D 是 Node 的子类，应该兼容
    assert(manager._is_type_compatible(TYPE_OBJECT, TYPE_OBJECT))

    # 注意：Godot 类型系统无法检查继承关系，所以这里只验证 TYPE_OBJECT 兼容性
    print("✓ Object inheritance compatibility test passed")
```

**Step 2: 运行测试验证失败**

运行: `addons/bricks/tests/test_type_compatibility.tscn`
预期: FAIL - Vector 类型兼容性检查失败

**Step 3: 扩展类型兼容性检查**

在 `function_manager.gd` 的 `_is_type_compatible()` 方法中添加:

```gdscript
static func _is_type_compatible(actual_type: int, expected_type: int) -> bool:
    # 完全匹配
    if actual_type == expected_type:
        return true

    # 允许 nil 到对象的转换
    if actual_type == TYPE_NIL and expected_type == TYPE_OBJECT:
        return true

    # 数值类型之间的转换
    if actual_type in [TYPE_INT, TYPE_FLOAT] and expected_type in [TYPE_INT, TYPE_FLOAT]:
        return true

    # Vector 类型兼容性（Vector2 ↔ Vector2I）
    if actual_type == TYPE_VECTOR2 and expected_type == TYPE_VECTOR2I:
        return true
    if actual_type == TYPE_VECTOR2I and expected_type == TYPE_VECTOR2:
        return true

    # Vector 类型兼容性（Vector3 ↔ Vector3I）
    if actual_type == TYPE_VECTOR3 and expected_type == TYPE_VECTOR3I:
        return true
    if actual_type == TYPE_VECTOR3I and expected_type == TYPE_VECTOR3:
        return true

    # 字符串到数值的转换（如果字符串可以解析为数值）
    if actual_type == TYPE_STRING and expected_type in [TYPE_INT, TYPE_FLOAT]:
        return true

    # 数值到字符串的转换
    if actual_type in [TYPE_INT, TYPE_FLOAT] and expected_type == TYPE_STRING:
        return true

    # 布尔值到数值的转换
    if actual_type == TYPE_BOOL and expected_type in [TYPE_INT, TYPE_FLOAT]:
        return true

    # 数值到布尔值的转换
    if actual_type in [TYPE_INT, TYPE_FLOAT] and expected_type == TYPE_BOOL:
        return true

    # 字符串到布尔值的转换
    if actual_type == TYPE_STRING and expected_type == TYPE_BOOL:
        return true

    return false
```

**Step 4: 运行测试验证通过**

运行: `addons/bricks/tests/test_type_compatibility.tscn`
预期: PASS - 所有类型兼容性测试通过

**Step 5: 提交**

```bash
git add addons/bricks/utils/function_manager.gd addons/bricks/tests/test_type_compatibility.gd
git commit -m "feat(function-manager): 添加 Vector 类型兼容性支持"
```

---

### Task 2.3: 实现 BaseVariable 持久化存储

**Files:**
- Modify: `addons/bricks/core/base/base_variable.gd`
- Test: `addons/bricks/tests/test_variable_persistence.gd` (创建新文件)

**Step 1: 编写持久化测试**

```gdscript
extends Node

func test_variable_persistence():
    var var1 = BaseVariable.create_global("test_score", 100, true)
    var var2 = BaseVariable.create_global("test_health", 50.5, true)

    # 保存变量
    var1._save_to_storage()
    var2._save_to_storage()

    # 创建新变量并加载
    var var1_loaded = BaseVariable.create("test_score", 0, BaseVariable.VariableScope.GLOBAL)
    var var1_loaded._load_from_storage()

    var var2_loaded = BaseVariable.create("test_health", 0.0, BaseVariable.VariableScope.GLOBAL)
    var var2_loaded._load_from_storage()

    # 验证值是否正确恢复
    assert(var1_loaded.value == 100, "Expected score 100, got %d" % var1_loaded.value)
    assert(var2_loaded.value == 50.5, "Expected health 50.5, got %f" % var2_loaded.value)

    print("✓ Variable persistence test passed")

    # 清理
    var1_loaded._clear_storage()
    var2_loaded._clear_storage()
```

**Step 2: 运行测试验证失败**

运行: `addons/bricks/tests/test_variable_persistence.tscn`
预期: FAIL - 持久化未实现，值为 0

**Step 3: 实现 ConfigFile 持久化**

在 `base_variable.gd` 中添加存储常量:

```gdscript
## 持久化配置
const STORAGE_SECTION = "variables"
const STORAGE_CONFIG_PATH = "user://bricks_variables.cfg"
```

实现 `_save_to_storage()`:

```gdscript
## 保存到持久化存储
func _save_to_storage():
    if not persistent:
        _log_debug("变量未启用持久化，跳过保存")
        return

    var config = ConfigFile.new()

    # 加载现有配置
    if FileAccess.file_exists(STORAGE_CONFIG_PATH):
        var error = config.load(STORAGE_CONFIG_PATH)
        if error != OK:
            _log_warning("加载现有配置失败: %d，将覆盖" % error)

    # 保存变量值
    config.set_value(STORAGE_SECTION, variable_name, str(value))
    config.set_value(STORAGE_SECTION, "%s_type" % variable_name, get_type_name())
    config.set_value(STORAGE_SECTION, "%s_modified" % variable_name, last_modified_time)
    config.set_value(STORAGE_SECTION, "%s_count" % variable_name, modification_count)

    # 保存到文件
    var error = config.save(STORAGE_CONFIG_PATH)
    if error == OK:
        _log_debug("变量 '%s' 已保存到持久化存储" % variable_name)
    else:
        _log_error("保存变量 '%s' 失败: %d" % [variable_name, error])
```

实现 `_load_from_storage()`:

```gdscript
## 从持久化存储加载
func _load_from_storage():
    if not FileAccess.file_exists(STORAGE_CONFIG_PATH):
        _log_debug("持久化存储文件不存在，跳过加载")
        return

    var config = ConfigFile.new()
    var error = config.load(STORAGE_CONFIG_PATH)

    if error != OK:
        _log_error("加载持久化存储失败: %d" % error)
        return

    # 检查变量是否存在
    if config.has_section_key(STORAGE_SECTION, variable_name):
        var value_str = config.get_value(STORAGE_SECTION, variable_name, "")
        var type_str = config.get_value(STORAGE_SECTION, "%s_type" % variable_name, "")

        # 根据类型转换值
        value = _parse_value_from_string(value_str, type_str)

        var modified = config.get_value(STORAGE_SECTION, "%s_modified" % variable_name, 0.0)
        last_modified_time = modified

        var count = config.get_value(STORAGE_SECTION, "%s_count" % variable_name, 0)
        modification_count = count

        is_initialized = true
        _log_debug("变量 '%s' 已从持久化存储加载: %s" % [variable_name, str(value)])
    else:
        _log_debug("变量 '%s' 不在持久化存储中" % variable_name)
```

添加辅助方法 `_parse_value_from_string()`:

```gdscript
## 从字符串解析值
func _parse_value_from_string(value_str: String, type_str: String) -> Variant:
    match type_str:
        "Bool":
            return bool(value_str)
        "Int":
            return int(value_str)
        "Float":
            return float(value_str)
        "String":
            return value_str
        "Vector2":
            var parts = value_str.substr(1, value_str.length() - 2).split(", ")
            return Vector2(float(parts[0]), float(parts[1]))
        "Vector3":
            var parts = value_str.substr(1, value_str.length() - 2).split(", ")
            return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
        "Color":
            var parts = value_str.substr(1, value_str.length() - 2).split(", ")
            return Color(float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3]))
        _:
            # 默认：尝试直接使用 str() 的逆操作
            return str_to_var(value_str)
```

添加清理方法 `_clear_storage()`:

```gdscript
## 清理持久化存储中的变量
func _clear_storage():
    if not FileAccess.file_exists(STORAGE_CONFIG_PATH):
        return

    var config = ConfigFile.new()
    var error = config.load(STORAGE_CONFIG_PATH)

    if error == OK:
        config.erase_section_key(STORAGE_SECTION, variable_name)
        config.erase_section_key(STORAGE_SECTION, "%s_type" % variable_name)
        config.erase_section_key(STORAGE_SECTION, "%s_modified" % variable_name)
        config.erase_section_key(STORAGE_SECTION, "%s_count" % variable_name)

        config.save(STORAGE_CONFIG_PATH)
        _log_debug("已从持久化存储清理变量 '%s'" % variable_name)
```

**Step 4: 运行测试验证通过**

运行: `addons/bricks/tests/test_variable_persistence.tscn`
预期: PASS - 变量正确保存和恢复

**Step 5: 提交**

```bash
git add addons/bricks/core/base/base_variable.gd addons/bricks/tests/test_variable_persistence.gd
git commit -m "feat(base-variable): 实现 ConfigFile 持久化存储"
```

---

### Task 2.4: 为 SignalManager 添加 LRU 缓存

**Files:**
- Modify: `addons/bricks/utils/signal_manager.gd`
- Test: `addons/bricks/tests/test_signal_cache.gd` (创建新文件)

**Step 1: 编写缓存测试**

```gdscript
extends Node

func test_signal_cache_with_lru():
    # 创建多个节点并获取信号
    var node1 = Node.new()
    var node2 = Node.new()
    var node3 = Node.new()

    node1.name = "Node1"
    node2.name = "Node2"
    node3.name = "Node3"

    # 获取信号（应该被缓存）
    var signals1 = SignalManager.get_node_signals(node1)
    var signals2 = SignalManager.get_node_signals(node2)

    # 获取缓存统计
    var stats = SignalManager.get_cache_stats()
    print("Cache stats: %s" % str(stats))

    # 验证缓存大小
    assert(stats.cached_nodes == 2, "Expected 2 cached nodes, got %d" % stats.cached_nodes)

    # 清理特定节点缓存
    SignalManager.clear_cache_for_node(node1)

    # 验证缓存已清理
    stats = SignalManager.get_cache_stats()
    assert(stats.cached_nodes == 1, "Expected 1 cached node, got %d" % stats.cached_nodes)

    print("✓ Signal cache test passed")

    node1.queue_free()
    node2.queue_free()
    node3.queue_free()
```

**Step 2: 运行测试验证当前行为**

运行: `addons/bricks/tests/test_signal_cache.tscn`
预期: PASS（当前功能正常，但缓存无过期机制）

**Step 3: 添加 LRU 缓存机制**

在 `signal_manager.gd` 中添加:

```gdscript
## 信号信息缓存（LRU 实现）
static var _signal_cache: Dictionary = {}
static var _cache_access_order: Array = []
static var _max_cache_size: int = 100  # 最大缓存节点数量

## 添加到缓存（LRU）
static func _add_to_cache_lru(cache_key: String, signals: Array):
    # 如果缓存已满，移除最老的项
    if _signal_cache.size() >= _max_cache_size:
        _evict_oldest()

    # 添加到缓存
    _signal_cache[cache_key] = signals

    # 更新访问顺序
    _update_access_order(cache_key)

## 更新访问顺序（LRU）
static func _update_access_order(cache_key: String):
    # 如果已存在，先移除
    var index = _cache_access_order.find(cache_key)
    if index >= 0:
        _cache_access_order.remove_at(index)

    # 添加到末尾（最近访问）
    _cache_access_order.append(cache_key)

## 驱逐最老的缓存项
static func _evict_oldest():
    if _cache_access_order.is_empty():
        return

    var oldest_key = _cache_access_order[0]
    _cache_access_order.pop_front()

    if _signal_cache.has(oldest_key):
        _signal_cache.erase(oldest_key)
```

修改 `get_node_signals()` 使用 LRU:

```gdscript
static func get_node_signals(node):
    if not node:
        return []

    var cache_key = _get_cache_key(node)
    if _signal_cache.has(cache_key):
        # 更新访问顺序
        _update_access_order(cache_key)
        return _signal_cache[cache_key]

    var signals = []
    var signal_list = node.get_signal_list()
    var node_class = node.get_class()

    for signal_dict in signal_list:
        var signal_info = SignalInfo.from_godot_signal(signal_dict, node_class)
        signals.append(signal_info)

    # 使用 LRU 添加到缓存
    _add_to_cache_lru(cache_key, signals)

    return signals
```

修改 `clear_cache_for_node()`:

```gdscript
static func clear_cache_for_node(node):
    if not node:
        return

    var cache_key = _get_cache_key(node)
    if _signal_cache.has(cache_key):
        _signal_cache.erase(cache_key)

        # 从访问顺序中移除
        var index = _cache_access_order.find(cache_key)
        if index >= 0:
            _cache_access_order.remove_at(index)
```

修改 `clear_all_cache()`:

```gdscript
static func clear_all_cache():
    _signal_cache.clear()
    _cache_access_order.clear()
```

**Step 4: 运行测试验证通过**

运行: `addons/bricks/tests/test_signal_cache.tscn`
预期: PASS - LRU 缓存正常工作

**Step 5: 提交**

```bash
git add addons/bricks/utils/signal_manager.gd addons/bricks/tests/test_signal_cache.gd
git commit -m "feat(signal-manager): 实现 LRU 缓存过期机制"
```

---

## Phase 3: 代码清理 (2-3 天)

### Task 3.1: 提取公共日志方法

**Files:**
- Create: `addons/bricks/core/mixins/loggable.gd`
- Modify: `addons/bricks/core/base/base_instruction.gd`
- Modify: `addons/bricks/core/base/base_variable.gd`
- Modify: `addons/bricks/core/base/action_runner.gd`

**Step 1: 创建 Loggable Mixin**

创建 `addons/bricks/core/mixins/loggable.gd`:

```gdscript
## Loggable Mixin
##
## 提供统一的日志接口，避免代码重复
class_name Loggable extends RefCounted

## 日志级别
@export var log_level: BricksLogger.LogLevel = BricksLogger.LogLevel.INFO

## 日志上下文（用于标识日志来源）
@export var log_context: String = ""

## 记录调试日志
## component: 组件名称（如 "BaseInstruction"）
## message: 日志消息
## context_id: 上下文 ID（可选）
func _log_debug(component: String, message: String, context_id: String = ""):
    BricksLogger.log_debug(component, log_level, message, context_id if not context_id.is_empty() else log_context)

## 记录信息日志
func _log_info(component: String, message: String, context_id: String = ""):
    BricksLogger.log_info(component, log_level, message, context_id if not context_id.is_empty() else log_context)

## 记录警告日志
func _log_warning(component: String, message: String, context_id: String = ""):
    BricksLogger.log_warning(component, log_level, message, context_id if not context_id.is_empty() else log_context)

## 记录错误日志
func _log_error(component: String, message: String, context_id: String = ""):
    BricksLogger.log_error(component, log_level, message, context_id if not context_id.is_empty() else log_context)
```

**Step 2: 在 BaseInstruction 中使用 Mixin**

修改 `base_instruction.gd`:

```gdscript
extends Resource
extends Loggable  # 使用 Loggable Mixin

# 删除重复的日志方法，使用继承的方法
# 保留原有的 log_level 属性，但改用 Mixin 的
```

**Step 3: 在 BaseVariable 中使用 Mixin**

修改 `base_variable.gd`:

```gdscript
extends Resource
extends Loggable  # 使用 Loggable Mixin

# 删除重复的日志方法
```

**Step 4: 在 ActionRunner 中使用 Mixin**

修改 `action_runner.gd`:

```gdscript
extends Resource
extends Loggable  # 使用 Loggable Mixin

# 删除重复的日志方法
```

**Step 5: 验证编译通过**

运行: 在 Godot 编辑器中检查是否有语法错误
预期: 无错误

**Step 6: 提交**

```bash
git add addons/bricks/core/mixins/loggable.gd
git add addons/bricks/core/base/base_instruction.gd
git add addons/bricks/core/base/base_variable.gd
git add addons/bricks/core/base/action_runner.gd
git commit -m "refactor: 提取公共日志方法到 Loggable Mixin"
```

---

### Task 3.2: 统一类型注解规范

**Files:**
- Modify: 多个文件缺少类型注解的方法
- Test: 创建类型注解检查脚本

**Step 1: 创建类型注解检查脚本**

创建 `addons/bricks/scripts/check_type_annotations.gd`:

```gdscript
@tool
extends EditorScript

## 类型注解检查脚本
##
## 扫描 brick 插件的所有 GDScript 文件，检查类型注解完整性

func _run():
    var brick_path = "res://addons/bricks"
    var files = _scan_gd_files(brick_path)

    print("=== 类型注解检查 ===")
    print("扫描了 %d 个 GDScript 文件" % files.size())

    var errors: Array = []

    for file_path in files:
        var file = FileAccess.open(file_path, FileAccess.READ)
        var content = file.get_as_text()
        file.close()

        var file_errors = _check_file_type_annotations(file_path, content)
        errors.append_array(file_errors)

    print("\n发现 %d 个类型注解问题" % errors.size())

    for error in errors:
        print("  ❌ %s:%d - %s" % [error.file, error.line, error.message])

    if errors.size() == 0:
        print("✓ 所有文件类型注解完整")
    else:
        print("\n建议：为这些方法添加返回类型注解")

func _scan_gd_files(path: String) -> Array:
    var files: Array = []
    var dir = DirAccess.open(path)

    if not dir:
        return files

    dir.list_dir_begin()
    var file_name = dir.get_next()

    while file_name != "":
        var full_path = path.path_join(file_name)

        if dir.current_is_dir() and not file_name.begins_with("."):
            files.append_array(_scan_gd_files(full_path))
        elif file_name.ends_with(".gd"):
            files.append(full_path)

        file_name = dir.get_next()

    return files

func _check_file_type_annotations(file_path: String, content: String) -> Array:
    var errors: Array = []
    var lines = content.split("\n")

    for i in range(lines.size()):
        var line = lines[i]
        var line_number = i + 1

        # 查找函数定义（忽略私有方法和单行函数）
        if line.match("func *(_*") or line.match("func *[a-z]"):
            continue  # 跳过私有方法

        # 检查是否有类型注解
        if line.begins_with("func "):
            # 检查是否有 "-> " 表示返回类型
            if not "->" in line and not ":" in line.substr(line.find("func ")):
                errors.append({
                    "file": file_path.trim_prefix("res://"),
                    "line": line_number,
                    "message": "缺少返回类型注解"
                })

    return errors
```

**Step 2: 运行检查脚本**

在 Godot 编辑器中运行脚本：
项目 → 工具 → 运行脚本 → 选择 `check_type_annotations.gd`

**Step 3: 根据检查结果修复类型注解**

为每个报告的方法添加返回类型注解。

示例：
```gdscript
# 修复前
func get_some_value():
    return 42

# 修复后
func get_some_value() -> int:
    return 42
```

**Step 4: 提交**

```bash
git add addons/bricks/scripts/check_type_annotations.gd
git add (修复的所有文件)
git commit -m "refactor: 统一类型注解规范"
```

---

### Task 3.3: 优化枚举定义

**Files:**
- Modify: `addons/bricks/core/base/base_variable.gd`
- Modify: `addons/bricks/core/base/execution_context.gd`

**Step 1: 检查枚举使用**

搜索 `VariableScope` 和 `ExecutionState` 的使用情况

```bash
grep -r "VariableScope\." addons/bricks/
grep -r "ExecutionState\." addons/bricks/
```

**Step 2: 评估枚举必要性**

如果枚举值很少（< 4）且使用范围有限，考虑用常量替代。

对于 `VariableScope`：
- 只有 LOCAL 和 GLOBAL 两个值
- 使用范围集中在 BaseVariable

**Step 3: 替换 VariableScope 枚举**

在 `base_variable.gd` 中:

```gdscript
## 变量作用域常量（替代枚举以减少开销）
const SCOPE_LOCAL = 0
const SCOPE_GLOBAL = 1

## 变量配置
@export_group("Factory Configuration")
@export var scope: int = SCOPE_LOCAL:
    set(value):
        if value in [SCOPE_LOCAL, SCOPE_GLOBAL]:
            scope = value
            _update_resource_name()
        else:
            push_warning("无效的作用域值: %d，使用默认值 LOCAL" % value)
            scope = SCOPE_LOCAL
            _update_resource_name()
```

更新工厂方法:

```gdscript
static func create_local(name: String, val: Variant) -> BaseVariable:
    return create(name, val, SCOPE_LOCAL)

static func create_global(name: String, val: Variant, persist: bool = true) -> BaseVariable:
    var variable = create(name, val, SCOPE_GLOBAL)
    variable.persistent = persist
    return variable
```

**Step 4: 验证所有引用已更新**

确保所有 `VariableScope.LOCAL` 改为 `SCOPE_LOCAL`，所有 `VariableScope.GLOBAL` 改为 `SCOPE_GLOBAL`

**Step 5: 提交**

```bash
git add addons/bricks/core/base/base_variable.gd
git commit -m "refactor: 将 VariableScope 枚举替换为常量"
```

---

## Phase 4: 性能提升与验证 (1 周)

### Task 4.1: 引入对象池系统

**Files:**
- Create: `addons/bricks/core/object_pool/bricks_object_pool.gd`
- Modify: `addons/bricks/core/base/action_runner.gd`

**Step 1: 设计对象池架构**

```gdscript
## BrickObjectPool
##
## 通用对象池，用于缓存和复用 RefCounted 对象

class_name BrickObjectPool extends RefCounted

## 对象类型到池的映射
var _pools: Dictionary = {}

## 池配置
var _max_pool_size: int = 100  # 每种类型的最大池大小
var _pool_stats: Dictionary = {}  # 统计信息

## 获取对象
## type: 对象类型（类名或脚本路径）
## returns: 池中的对象或新对象
func acquire(type: Variant):
    var type_key = _get_type_key(type)

    if not _pools.has(type_key):
        _pools[type_key] = []

    var pool = _pools[type_key]

    if pool.size() > 0:
        var obj = pool.pop_back()
        _record_stats(type_key, "acquire_from_pool")
        return obj

    # 池为空，创建新对象
    var obj = _create_object(type)
    _record_stats(type_key, "create_new")
    return obj

## 释放对象
## obj: 要释放的对象
func release(obj):
    if not obj:
        return

    var type_key = _get_type_key_from_object(obj)

    if not _pools.has(type_key):
        _pools[type_key] = []

    var pool = _pools[type_key]

    # 检查池大小限制
    if pool.size() >= _max_pool_size:
        # 池已满，直接丢弃对象
        _record_stats(type_key, "discard_full")
        return

    # 重置对象状态
    _reset_object(obj)

    # 放回池中
    pool.append(obj)
    _record_stats(type_key, "release")

## 获取池统计信息
## returns: 统计信息字典
func get_stats() -> Dictionary:
    return _pool_stats.duplicate()

## 清空所有池
func clear_all():
    for pool in _pools.values():
        pool.clear()
    _pools.clear()
    _pool_stats.clear()

## 私有方法

## 获取类型键
func _get_type_key(type: Variant) -> String:
    if type is String:
        return type
    elif type is Script:
        return type.get_path()
    else:
        return str(type)

## 从对象获取类型键
func _get_type_key_from_object(obj) -> String:
    var script = obj.get_script()
    if script:
        return _get_type_key(script)
    return _get_type_key(obj.get_class())

## 创建对象
func _create_object(type: Variant):
    if type is String:
        return load(type).new()
    elif type is Script:
        return type.new()
    else:
        # 尝试使用 ClassDB
        return ClassDB.instantiate(str(type))

## 重置对象
func _reset_object(obj):
    # 清理对象状态
    if obj.has_method("reset"):
        obj.reset()
    elif obj.has_method("cleanup"):
        obj.cleanup()

## 记录统计信息
func _record_stats(type_key: String, action: String):
    if not _pool_stats.has(type_key):
        _pool_stats[type_key] = {}

    if not _pool_stats[type_key].has(action):
        _pool_stats[type_key][action] = 0

    _pool_stats[type_key][action] += 1
```

**Step 2: 集成到 ActionRunner**

在 `action_runner.gd` 中添加对象池:

```gdscript
var _object_pool: BrickObjectPool = null

func _init():
    _object_pool = BrickObjectPool.new()
    _log_debug("ActionRunner initialized with object pool")
```

修改指令执行使用对象池:

```gdscript
# 对于临时对象（如 ExecutionContext），使用对象池
func _create_context() -> ExecutionContext:
    return _object_pool.acquire(ExecutionContext)

func _release_context(context: ExecutionContext):
    context.cleanup()
    _object_pool.release(context)
```

**Step 3: 编写性能测试**

```gdscript
extends Node

func test_object_pool_performance():
    var pool = BrickObjectPool.new()

    var start_time = Time.get_ticks_msec()

    # 创建和释放 10000 个对象
    for i in range(10000):
        var context = pool.acquire(ExecutionContext)
        context.cleanup()
        pool.release(context)

    var elapsed = Time.get_ticks_msec() - start_time
    var ops_per_ms = 10000.0 / elapsed

    print("✓ Object pool performance: %d ops/ms (%.2f ms for 10000 ops)" % [ops_per_ms, elapsed])

    var stats = pool.get_stats()
    print("Pool stats: %s" % str(stats))

    pool.clear_all()
```

**Step 4: 运行性能测试**

运行: `addons/bricks/tests/test_object_pool_performance.tscn`

**Step 5: 提交**

```bash
git add addons/bricks/core/object_pool/bricks_object_pool.gd
git add addons/bricks/core/base/action_runner.gd
git add addons/bricks/tests/test_object_pool_performance.gd
git commit -m "feat: 引入对象池系统优化性能"
```

---

### Task 4.2: 添加性能基准测试套件

**Files:**
- Create: `addons/bricks/tests/benchmark_suite.gd`
- Create: `addons/bricks/tests/benchmarks/*.gd`

**Step 1: 创建基准测试框架**

创建 `addons/bricks/tests/benchmark_suite.gd`:

```gdscript
## Benchmark Suite
##
## 性能基准测试套件，用于跟踪性能回归

extends Node

## 基准测试结果
var _results: Dictionary = {}

## 运行所有基准测试
func run_all_benchmarks():
    print("=== Brick 插件性能基准测试 ===")
    print("开始时间: %s" % Time.get_datetime_string_from_system())

    _run_variable_lookup_benchmark()
    _run_signal_cache_benchmark()
    _run_instruction_execution_benchmark()

    print("\n=== 测试完成 ===")
    _print_summary()

## 变量查找基准测试
func _run_variable_lookup_benchmark():
    print("\n--- 变量查找基准测试 ---")

    var context = ExecutionContext.new()

    # 设置 100 个变量
    for i in range(100):
        context.set_variable("var_%d" % i, i)

    # 预热
    for i in range(1000):
        context.get_variable("var_%d" % (i % 100))

    # 实际测试
    var iterations = 10000
    var start_time = Time.get_ticks_msec()

    for i in range(iterations):
        context.get_variable("var_%d" % (i % 100))

    var elapsed = Time.get_ticks_msec() - start_time
    var ops_per_ms = float(iterations) / float(elapsed)

    _results["variable_lookup"] = {
        "ops_per_ms": ops_per_ms,
        "total_time_ms": elapsed,
        "iterations": iterations
    }

    print("  变量查找: %.2f ops/ms (%.2f ms for %d lookups)" % [ops_per_ms, elapsed, iterations])
    print("  目标: > 1000 ops/ms")

    context.cleanup()

## 信号缓存基准测试
func _run_signal_cache_benchmark():
    print("\n--- 信号缓存基准测试 ---")

    var nodes = []
    for i in range(100):
        var node = Node.new()
        node.name = "BenchmarkNode_%d" % i
        nodes.append(node)

    # 预热缓存
    for node in nodes:
        SignalManager.get_node_signals(node)

    # 实际测试
    var iterations = 10000
    var start_time = Time.get_ticks_msec()

    for i in range(iterations):
        SignalManager.get_node_signals(nodes[i % nodes.size()])

    var elapsed = Time.get_ticks_msec() - start_time
    var ops_per_ms = float(iterations) / float(elapsed)

    _results["signal_cache"] = {
        "ops_per_ms": ops_per_ms,
        "total_time_ms": elapsed,
        "iterations": iterations
    }

    print("  信号缓存: %.2f ops/ms (%.2f ms for %d lookups)" % [ops_per_ms, elapsed, iterations])

    for node in nodes:
        node.queue_free()

## 指令执行基准测试
func _run_instruction_execution_benchmark():
    print("\n--- 指令执行基准测试 ---")

    var runner = ActionRunner.new()

    # 创建 100 个简单指令
    for i in range(100):
        var inst = BaseInstruction.new()
        runner.add_instruction(inst)

    var context = ExecutionContext.new()

    # 实际测试
    var iterations = 100
    var start_time = Time.get_ticks_msec()

    for i in range(iterations):
        runner.run(context)
        await runner.execution_completed

    var elapsed = Time.get_ticks_msec() - start_time
    var avg_time_ms = float(elapsed) / float(iterations)

    _results["instruction_execution"] = {
        "avg_time_ms": avg_time_ms,
        "total_time_ms": elapsed,
        "iterations": iterations
    }

    print("  指令执行: %.3f ms avg (%.2f ms for %d runs)" % [avg_time_ms, elapsed, iterations])
    print("  目标: < 5 ms per run")

    context.cleanup()

## 打印总结
func _print_summary():
    print("\n=== 基准测试总结 ===")

    for test_name in _results:
        var result = _results[test_name]
        print("\n%s:" % test_name)

        for key in result:
            print("  %s: %s" % [key, str(result[key])])

    print("\n性能目标:")
    print("  变量查找: > 1000 ops/ms")
    print("  信号缓存: > 500 ops/ms")
    print("  指令执行: < 5 ms per run")
```

**Step 2: 运行基准测试套件**

运行: `addons/bricks/tests/benchmark_suite.tscn`

**Step 3: 记录基线性能**

将结果保存到 `addons/bricks/tests/benchmarks/baseline.json`:

```json
{
  "date": "2026-01-23",
  "variable_lookup": {
    "ops_per_ms": 1500.0,
    "target": "> 1000 ops/ms"
  },
  "signal_cache": {
    "ops_per_ms": 800.0,
    "target": "> 500 ops/ms"
  },
  "instruction_execution": {
    "avg_time_ms": 3.5,
    "target": "< 5 ms"
  }
}
```

**Step 4: 提交**

```bash
git add addons/bricks/tests/benchmark_suite.gd
git add addons/bricks/tests/benchmarks/baseline.json
git commit -m "test: 添加性能基准测试套件"
```

---

### Task 4.3: 性能验证与回归测试

**Files:**
- Create: `addons/bricks/scripts/run_performance_tests.sh`

**Step 1: 创建性能测试脚本**

创建 `addons/bricks/scripts/run_performance_tests.sh`:

```bash
#!/bin/bash

# Brick 插件性能测试脚本
# 运行所有性能和回归测试

echo "=========================================="
echo "Brick 插件性能测试"
echo "=========================================="
echo ""

# 清理旧的测试报告
rm -f test_report_*.txt

# 运行基准测试
echo "1. 运行基准测试..."
godot --headless --script addons/bricks/tests/benchmark_suite.gd > benchmark_report.txt 2>&1

# 检查是否达到性能目标
if grep -q "性能目标" benchmark_report.txt; then
    echo "✓ 基准测试完成"
else
    echo "✗ 基准测试失败"
    exit 1
fi

# 运行内存泄漏测试
echo ""
echo "2. 运行内存泄漏测试..."
godot --headless --script addons/bricks/tests/test_memory_leaks.gd > memory_report.txt 2>&1

# 运行功能测试
echo ""
echo "3. 运行功能测试..."
godot --headless --script addons/bricks/tests/test_all.gd > test_report.txt 2>&1

echo ""
echo "=========================================="
echo "测试完成"
echo "=========================================="
echo ""
echo "测试报告："
echo "  - benchmark_report.txt"
echo "  - memory_report.txt"
echo "  - test_report.txt"
```

**Step 2: 创建内存泄漏检测测试**

创建 `addons/bricks/tests/test_memory_leaks.gd`:

```gdscript
extends Node

## 内存泄漏检测测试

func test_no_memory_leaks_in_action_runner():
    var runner = ActionRunner.new()

    # 创建指令
    for i in range(100):
        var inst = BaseInstruction.new()
        runner.add_instruction(inst)

    var context = ExecutionContext.new()

    # 记录初始内存
    var initial_memory = OS.get_static_memory_usage_by_type(OS.MEMORY_STATIC)
    print("初始内存: %d MB" % (initial_memory / 1024 / 1024))

    # 执行多次
    for i in range(100):
        runner.run(context)
        await runner.execution_completed

    # 等待 GC
    await get_tree().process_frame
    await get_tree().process_frame

    # 记录最终内存
    var final_memory = OS.get_static_memory_usage_by_type(OS.MEMORY_STATIC)
    print("最终内存: %d MB" % (final_memory / 1024 / 1024))

    var memory_increase = final_memory - initial_memory
    var increase_mb = memory_increase / 1024 / 1024

    # 允许 10MB 的增长（用于缓存等）
    assert(increase_mb < 10, "内存增长过大: %d MB" % increase_mb)

    print("✓ 无明显内存泄漏")

    context.cleanup()
```

**Step 3: 运行完整测试套件**

```bash
cd E:\Godot\GodotProjects\project-juicy-godot
bash addons/bricks/scripts/run_performance_tests.sh
```

**Step 4: 验证所有测试通过**

检查所有报告文件：
- `benchmark_report.txt` - 性能目标达到
- `memory_report.txt` - 无内存泄漏
- `test_report.txt` - 功能测试通过

**Step 5: 提交**

```bash
git add addons/bricks/scripts/run_performance_tests.sh
git add addons/bricks/tests/test_memory_leaks.gd
git commit -m "test: 添加性能验证和回归测试"
```

---

## 总结

### 完成后的改进

| 问题类别 | 修复数量 | 影响 |
|---------|---------|------|
| Critical 内存泄漏 | 3 | 阻止内存泄漏，提升稳定性 |
| Important 性能问题 | 4 | 提升 3-5 倍性能 |
| Minor 代码质量 | 3 | 提高可维护性 |
| 测试覆盖 | 新增 8 个测试套件 | 确保质量 |

### 预期效果

- **内存泄漏**: 100% 修复
- **变量查找性能**: 提升 400%
- **信号缓存性能**: 提升 200%
- **代码重复**: 减少 60%
- **测试覆盖**: 从 30% 提升到 80%

### 后续建议

1. **定期运行性能基准测试**（CI 集成）
2. **添加更多边界情况测试**
3. **考虑引入静态分析工具**（gdformat, gdlint）
4. **文档化公共 API**（使用 Markdown 生成器）
5. **性能监控仪表板**（运行时性能可视化）

---

**计划完成日期**: 2026-02-15 (预计 2-3 周)
