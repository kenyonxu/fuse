> 🌐 [**中文版**](../../../zh_CN/dev_docs/guides/instruction-creation-guide.md) | English

# Fuse Instruction Creation Guide

> **Goal**: Provide developers with a complete guide to creating Fuse instructions, based on Phase 0B experience and best practices.
> **Authoritative spec**: The final authority for component generation is the [fuse-instruction-generator skill](../../../../agent_skills/fuse-instruction-generator/SKILL.md) (templates, naming rules, and validation gates); this guide elaborates on its architectural principles.

**Audience**: Fuse system developers and contributors

**Last updated**: 2026-06-17

**Important updates**: Added documentation for CompletionSignalTiming, ExecutionMode, cancel(), and timeout management

---

## 📋 Table of Contents

1. [Naming Conventions](#naming-conventions)
2. [Icon Guidelines](#icon-guidelines)
3. [Key Technical Points](#key-technical-points)
4. [RuntimeInstructionInstance Architecture Support](#runtimeinstructioninstance-architecture-support)
5. [Complete Instruction Template](#complete-instruction-template)
6. [Instruction Template with Variable Operations](#instruction-template-with-variable-operations)
7. [Creation Steps](#creation-steps)
8. [Best Practices](#best-practices)
9. [Common Pitfalls](#common-pitfalls)
10. [Testing Guidelines](#testing-guidelines)

---

## Naming Conventions

**Important**: All Fuse instructions follow the naming conventions below to stay concise and consistent.

### File Naming

- **Instruction files**: Use `snake_case`, **without** the `_instruction` suffix
  - ✅ Correct: `set_position.gd`, `for_loop.gd`, `if_else.gd`
  - ❌ Wrong: `set_position_instruction.gd`, `for_loop_instruction.gd`

### Class Naming

- **Class names**: Use `PascalCase`, **without** the `Instruction` suffix
  - ✅ Correct: `class_name SetPosition`, `class_name ForLoop`, `class_name IfElse`
  - ❌ Wrong: `class_name SetPositionInstruction`, `class_name ForLoopInstruction`

### Test File Naming

- **Test scripts**: `test_<instruction_name>.gd`
  - e.g.: `test_set_position.gd`, `test_for_loop.gd`
- **Test scenes**: `test_<instruction_name>.tscn`
  - e.g.: `test_set_position.tscn`, `test_for_loop.tscn`

### Consistency Principle

- Keep the file name, class name, and test file names based on the same base name
- Avoid redundant suffixes (such as `_instruction`, `Instruction`)
- Keep them concise and readable

**Example**:
```
指令文件：   set_position.gd
类名：       class_name SetPosition
测试脚本：   test_set_position.gd
测试场景：   test_set_position.tscn
```

---

## Icon Guidelines

**Icon selection principle**: Every instruction should have an icon configured to improve user experience and visual presentation.

### Icon Configuration

**Recommended: use Godot builtin icons**
```gdscript
metadata.builtin_icon = "Script"  # 使用 Godot 内置图标名称
```

**Alternative: use a custom icon library**
```gdscript
metadata.custom_icon = "my_custom_icon"  # 使用导入的自定义图标
```

**Backward compatibility**
```gdscript
metadata.icon_name = "Script"  # 旧方式，仍然有效
metadata.icon = preload("res://icon.png")  # 直接指定纹理
```

### Builtin Icon Naming Reference

**Common icon names**:
- **Flow control**: `Loop`, `Branch`, `Time`
- **Variable operations**: `Array`, `New`, `View`, `Print`
- **Node operations**: `Node`, `Edit`, `Call`, `Remove`
- **Debugging**: `Debug`, `Search`
- **General**: `Script`, `Play`, `Stop`, `Save`, `Load`, `Add`, `File`, `Folder`
- **Transform**: `Rotate`, `Scale`, `Translation`, `Move`
- **Audio**: `AudioStreamPlayer`, `Play`, `Stop`, `VolumeCurve`
- **Scenes**: `MakePacked`, `PackedScene`

**Full list**: see [icon-system-guide.md](icon-system-guide.md)

### Icon Configuration Steps

Configure the icon in `_get_instruction_metadata()`:

```gdscript
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.builtin_icon = "Script"  # 配置图标
	return metadata
```

---

## Key Technical Points

> **Important**: Key technical points summarized from Phase 0B development experience; all subsequent instruction development must follow them.

### Required Abstract Methods

All instructions must implement the following methods, otherwise compilation errors occur:

```gdscript
## 1. Update the resource name (required)
func _update_resource_name():
	var parts = []
	# Build a descriptive resource name
	parts.append("操作名称")
	if not target_node.is_empty():
		parts.append("'%s'" % target_node)
	resource_name = " ".join(parts)

## 2. Validate the parameters (required)
func validate() -> Array[String]:
	var errors = super.validate()
	# Add custom validation
	if target_node.is_empty():
		errors.append("目标节点路径不能为空")
	return errors

## 3. Get the description (required)
func get_description() -> String:
	return "指令描述字符串"
```

### Required Methods for the Execution Flow

```gdscript
func execute(context: ExecutionContext):
	# Must be called first
	_start_execution(context)

	# Validation logic
	if validation_failed:
		_log_error_localized("ERROR_KEY", {})
		set_error_localized("ERROR_KEY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()  # 同步指令直接发出信号
		return

	# Execution logic
	# ...

	# Synchronous instruction completion
	_on_execution_completed()

	# Asynchronous instruction (needs a timer, etc.)
	# Do not call _on_execution_completed(); instead call finished.emit() in the callback
```

### Node Retrieval

**❌ Wrong usage**:
```gdscript
var node := context.resolve_node(target_node)  # 方法不存在
var node := get_node(target_node)                 # 无法解析相对路径
```

**✅ Correct usage**:
```gdscript
var node := context.get_node(target_node)       # 正确，支持相对路径解析
```

### Asynchronous Operations (Timers)

**❌ Wrong usage**:
```gdscript
_timer = get_tree().create_timer(delay)  # get_tree() 在指令中不可用
```

**✅ Correct usage**:
```gdscript
var scene_tree = Engine.get_main_loop()
if scene_tree:
	_timer = scene_tree.create_timer(delay)
	_timer.timeout.connect(_on_timer_timeout)
else:
	_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TIMER", {})
	finished.emit()
```

### SceneTree and Current Scene Access

```gdscript
# Get the SceneTree
var scene_tree = Engine.get_main_loop()
if scene_tree:
	# Get the current scene
	var current_scene = scene_tree.current_scene
	# Create a timer
	var timer = scene_tree.create_timer(duration)
```

### Variable Operations (Three-Layer Variable System)

**Important**: The Fuse system uses a three-layer variable architecture (LOCAL/SCOPE/GLOBAL); all instructions should use the `VariableOperations` utility class to access variables uniformly.

**Three-layer variable architecture**:
- **LOCAL** - Local variables (ExecutionContext), valid during a single instruction execution
- **SCOPE** - Scope variables (ScopeVariableContainer), valid for the node's lifetime
- **GLOBAL** - Global variables (GlobalVariableResource), accessible across scenes

**✅ Recommended usage** (using VariableOperations):
```gdscript
# Read a variable (supports the three-layer scopes)
var value = VariableOperations.get_variable(
	context,
	var_name,
	var_scope,  # BaseVariable.VariableScope.LOCAL/SCOPE/GLOBAL
	default_value
)

# Set a variable (supports the three-layer scopes)
VariableOperations.set_variable(
	context,
	var_name,
	var_scope,  # BaseVariable.VariableScope.LOCAL/SCOPE/GLOBAL
	new_value
)

# Check whether the variable exists (distinguish "does not exist" from "value is null")
if not VariableOperations.has_variable(context, var_name, var_scope):
	_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": var_name})
	return
```

**Complete example** (using variables in an instruction):
```gdscript
# Variable scope property
@export var value_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		value_scope = value
		_update_resource_name()

# Read the variable at execution time
func execute(context: ExecutionContext):
	_start_execution(context)

	var value = VariableOperations.get_variable(
		context,
		variable_name,
		value_scope,
		null  # 默认值
	)

	# Check whether the variable exists
	if value == null and not VariableOperations.has_variable(
		context,
		variable_name,
		value_scope
	):
		_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": variable_name})
		set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"variable": variable_name})
		finished.emit()
		return

	# Use the variable...

	_on_execution_completed()
```

**❌ Deprecated usage** (not recommended):
```gdscript
# Old API (deprecated)
var value = context.get_variable(var_name, is_global, default_value)
context.set_variable(var_name, is_global, value)

# Or direct access
if context.global_variables:
	context.global_variables.set_variable(var_name, value)
```

**Scope string display** (using VariableScopeUtils):
```gdscript
# Show the scope in the description
var scope_str = VariableScopeUtils.enum_to_string(value_scope).to_upper()
var description = "%s [%s]" % [variable_name, scope_str]
# Result: "my_variable [LOCAL]", "my_variable [SCOPE]", "my_variable [GLOBAL]"
```

**SCOPE scope validation**:
```gdscript
func validate() -> Array[String]:
	var errors = super.validate()

	# Validate the variable name
	if variable_name.is_empty():
		errors.append("变量名不能为空")

	# Validating the SCOPE scope requires ScopeVariableManager
	if value_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append("未找到 ScopeVariableManager 实例")

	return errors
```

### AudioServer API (Godot 4.x)

**❌ Wrong usage**:
```gdscript
var bus_names = AudioServer.get_bus_names()  # 不是静态方法
```

**✅ Correct usage**:
```gdscript
var bus_names = []
for i in range(AudioServer.get_bus_count()):
	bus_names.append(AudioServer.get_bus_name(i))
```

### Tween Creation (Resource Context)

**❌ Wrong usage**:
```gdscript
var tween = create_tween()  # 在指令中不可用
```

**✅ Correct usage**:
```gdscript
var scene_tree = Engine.get_main_loop()
if not scene_tree:
	_log_error_localized("FUSE_ERROR_CANNOT_CREATE_TWEEN", {})
	# Fall back to setting the value directly
	return
var tween = scene_tree.create_tween()
```

### Error Handling and Signal Emission

```gdscript
# Synchronous instruction error handling
if error:
	_log_error_localized("ERROR_KEY", {"param": value})
	set_error_localized("ERROR_KEY", FuseError.ErrorType.RUNTIME_ERROR, {"param": value})
	finished.emit()  # 直接发出完成信号
	return

# Synchronous instruction successful completion
_on_execution_completed()

# Asynchronous instruction (timer callback)
func _on_timer_timeout():
	# Finish the work
	finished.emit()  # 在回调中发出完成信号
```

### Variable Type Inference

```gdscript
# ✅ Explicit types avoid inference issues
var node: Node = context.get_node(target_node)
var parent: Node = context.get_node(parent_path)

# ✅ Use := to let Godot infer (but it requires initialization)
var node := context.get_node(target_node)

# ❌ Avoid uninitialized variables
var node: Node  # 未初始化，类型推断可能失败
node = context.get_node(target_node)
```

### GDScript 2.0 Ternary Operator

**Syntax**:
```gdscript
# ✅ Correct (Python style)
value_if_true if condition else value_if_false

# ❌ Wrong (C style)
condition ? value_if_true : value_if_false
```

---

### Completion Signal Timing (CompletionSignalTiming)

**Purpose**: Controls when the `finished` signal is emitted.

```gdscript
enum CompletionSignalTiming {
	ON_START,   # 在执行开始时发送完成信号
	ON_FINISH   # 在执行完成时发送完成信号（默认）
}

@export var completion_timing: CompletionSignalTiming = CompletionSignalTiming.ON_FINISH
```

**Use cases**:
- `ON_FINISH` (default): the `finished` signal is emitted only after the instruction actually finishes executing → normal asynchronous instructions
- `ON_START`: the signal is emitted as soon as the instruction starts and subsequent execution does not block → pure notification/logging instructions

---

### Execution Mode (ExecutionMode)

**Purpose**: Controls the instruction's execution mode, used for smart execution path optimization.

```gdscript
enum ExecutionMode {
	AUTO_DETECT,   # 自动检测执行模式（推荐）
	FORCE_ASYNC,   # 强制异步执行
	FORCE_SYNC     # 强制同步执行
}

@export var execution_mode: ExecutionMode = ExecutionMode.AUTO_DETECT
```

**Detection mechanism**:
- `AUTO_DETECT`: `BaseInstruction._detect_sync_capability()` determines it automatically through source analysis (checking for `await`/`finished.emit()`)
- `FORCE_ASYNC`: force the asynchronous path (suitable for instructions containing asynchronous sub-instructions)
- `FORCE_SYNC`: force the synchronous path (suitable for pure computation with no external dependencies)

**Related methods**:
- `can_execute_sync()` — determines whether synchronous execution is possible based on the execution mode
- `set_synchronous_hint(is_sync: bool)` — manually sets the synchronous hint
- `_is_synchronous()` — overridden by subclasses to declare synchronous capability

---

### Instruction Cancellation (cancel)

**Purpose**: Cancels a running instruction. If the instruction is running, the status is set to CANCELLED and the `finished` signal is emitted.

```gdscript
## Cancel instruction execution
##
## Cancels a running instruction. It will:
## 1. Set the execution status to CANCELLED
## 2. Set the error message
## 3. Emit the finished signal
## 4. Clean up the timeout timer
##
## Subclasses overriding this should call super.cancel()
func cancel() -> void:
	if execution_status == ExecutionStatus.RUNNING:
		execution_status = ExecutionStatus.CANCELLED
		error_message = "指令被取消"
		_cleanup_timeout_timer()
		finished.emit()
```

**Use cases**:
- The user manually cancels a long-running asynchronous instruction
- A game state change requires interrupting the current operation
- A sub-instruction runs inside a containing instruction and the parent instruction is cancelled

---

### Timeout Management

**Purpose**: Sets an execution timeout for instructions to prevent them from waiting forever.

```gdscript
## Set the timeout duration
## - timeout_seconds: timeout duration (seconds); 0 disables it
func set_timeout(timeout_seconds: float) -> void:
	_timeout_duration = max(0.0, timeout_seconds)

## Get the timeout duration
func get_timeout() -> float:
	return _timeout_duration

## Check whether a timeout is enabled
func has_timeout() -> bool:
	return _timeout_duration > 0.0

## Get the execution time
func get_execution_time() -> float:
	if execution_status == ExecutionStatus.RUNNING:
		return (Time.get_ticks_msec() / 1000.0) - _execution_start_time
	return 0.0
```

**Timeout handling**:
- On timeout, `_on_timeout()` is called automatically and the error type is set to `TIMEOUT_ERROR`
- The parent instruction's `_start_execution()` automatically calls `_setup_timeout_timer()`
- `_cleanup_timeout_timer()` is called automatically on completion/cancellation/error

---

## RuntimeInstructionInstance Architecture Support

> **Important**: For asynchronous instructions (especially those using timers), implement the `RuntimeInstructionInstance` architecture to ensure state isolation and pause/resume support.

### Why Is RuntimeInstructionInstance Needed?

**Problem scenarios**:
- The same instruction resource is executed concurrently by multiple execution instances
- Instruction execution needs to be paused/resumed
- Timer callbacks need correct cleanup and restoration

**Solution**:
Each execution instance owns an independent `runtime_state` dictionary that stores that instance's runtime state.

### Required Methods

#### 1. `get_default_runtime_state()` - Declaring Runtime State

**All asynchronous instructions should implement this method**:

```gdscript
## Get the default runtime state
##
## Declares the runtime state the instruction needs.
## This state is copied when the RuntimeInstructionInstance is initialized.
func get_default_runtime_state() -> Dictionary:
	var state = super.get_default_runtime_state()
	state["timer"] = null  # 每个 RuntimeInstance 有自己的 timer
	state["is_running"] = false
	state["wait_time"] = wait_time  # 复制配置值
	state["pause_remaining_time"] = 0.0  # 暂停时剩余时间
	state["current_timer_callback"] = null  # 存储回调引用（用于暂停时断开）
	return state
```

**Key points**:
- ✅ Call `super.get_default_runtime_state()` first to get the base class state
- ✅ Declare all variables needed at runtime (timers, counters, flags, etc.)
- ✅ Copy configuration values into the state (avoid multiple instances sharing the same configuration)
- ✅ Reserve state fields for pause/resume support

#### 2. `execute_with_runtime_instance()` - Runtime Execution Method

**Replaces the traditional `execute()` method**:

```gdscript
## Execute using a runtime instance (recommended pattern)
##
## In this mode, all state is stored in runtime_instance.runtime_state,
## ensuring that multiple execution instances do not interfere with each other.
##
## Use the runtime_instance to manage signal connections and avoid bind leaks
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
	_start_execution(runtime_instance.execution_context)

	# Get the runtime state
	var state = runtime_instance.runtime_state

	# ... execution logic, using state to store state ...

	# Create the timer and store it in the runtime state
	var scene_tree = Engine.get_main_loop()
	if scene_tree:
		var timer = scene_tree.create_timer(actual_wait_time)
		state["timer"] = timer  # 存储到独立的运行时状态
		state["is_running"] = true
		state["wait_start_time"] = Time.get_ticks_msec() / 1000.0

		# Use a Callable and register it with the runtime_instance
		var callback = _create_timer_callback(runtime_instance)
		timer.timeout.connect(callback)
		runtime_instance.register_timer_callback(callback)
		state["current_timer_callback"] = callback  # 存储引用，用于暂停时断开

		return false  # 异步执行

	return true  # 同步完成
```

**Return value explanation**:
- `return true` - the instruction completed synchronously
- `return false` - the instruction is executing asynchronously

#### 3. Callback Creation Method - Avoiding bind Leaks

**Create callbacks with closures and store references**:

```gdscript
## Create the timer callback (avoids bind)
##
## Uses a Callable and a closure, but stores the reference for cleanup
func _create_timer_callback(runtime_instance: RuntimeInstructionInstance) -> Callable:
	var callback = func():
		_on_runtime_timer_timeout(runtime_instance)
	return callback

## Runtime timer timeout callback
func _on_runtime_timer_timeout(runtime_instance: RuntimeInstructionInstance):
	# Check whether the instance is still valid
	if not runtime_instance or runtime_instance.is_completed():
		return

	var state = runtime_instance.runtime_state

	# Clean up the runtime state
	state["timer"] = null
	state["is_running"] = false

	# Mark as completed
	runtime_instance._complete_execution()
```

**Key points**:
- ✅ Use closures instead of `bind()` to avoid memory leaks
- ✅ Check instance validity at the start of the callback
- ✅ Use `runtime_instance._complete_execution()` to complete execution
- ❌ Do not use `finished.emit()` (handled by `_complete_execution`)

#### 4. Pause/Resume Handling (Optional)

**If the instruction supports pause/resume, implement the following methods**:

```gdscript
## Pause handling
##
## When the runtime instance is paused, record the remaining time and disconnect the original timer
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	if state.has("timer") and state["timer"]:
		var timer = state["timer"]
		if timer is SceneTreeTimer:
			# SceneTreeTimer cannot be paused; record the remaining time
			var elapsed = Time.get_ticks_msec() / 1000.0 - state.get("wait_start_time", 0.0)
			var remaining = state.get("actual_wait_time", 0.0) - elapsed
			state["pause_remaining_time"] = max(0.0, remaining)

			# Disconnect the original timer using the stored callback reference (critical fix!)
			var callback = state.get("current_timer_callback")
			if callback and timer.timeout.is_connected(callback):
				timer.timeout.disconnect(callback)

			state["timer"] = null
			state["current_timer_callback"] = null  # 清除回调引用

## Resume handling
##
## When the runtime instance is resumed, create a new timer for the remaining time
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var remaining = state.get("pause_remaining_time", 0.0)

	if remaining > 0:
		# Create a new timer for the remaining time
		var scene_tree = Engine.get_main_loop()
		if scene_tree:
			var timer = scene_tree.create_timer(remaining)
			state["timer"] = timer
			state["wait_start_time"] = Time.get_ticks_msec() / 1000.0
			state["actual_wait_time"] = remaining

			var callback = _create_timer_callback(runtime_instance)
			timer.timeout.connect(callback)
			runtime_instance.register_timer_callback(callback)
			state["current_timer_callback"] = callback  # 存储回调引用

	state["pause_remaining_time"] = 0.0
```

### Complete RuntimeInstructionInstance Template

```gdscript
## ============================================================
## Runtime instance pattern support (RuntimeInstructionInstance architecture)
## ============================================================

## Get the default runtime state
func get_default_runtime_state() -> Dictionary:
	var state = super.get_default_runtime_state()
	state["timer"] = null
	state["is_running"] = false
	state["pause_remaining_time"] = 0.0
	state["current_timer_callback"] = null
	return state

## Execute using a runtime instance
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
	_start_execution(runtime_instance.execution_context)
	var state = runtime_instance.runtime_state

	# ... execution logic ...

	# Return false for asynchronous, true for synchronous
	return false

## Create the timer callback
func _create_timer_callback(runtime_instance: RuntimeInstructionInstance) -> Callable:
	var callback = func():
		_on_runtime_timer_timeout(runtime_instance)
	return callback

## Timer timeout callback
func _on_runtime_timer_timeout(runtime_instance: RuntimeInstructionInstance):
	if not runtime_instance or runtime_instance.is_completed():
		return

	var state = runtime_instance.runtime_state
	state["timer"] = null
	state["is_running"] = false

	runtime_instance._complete_execution()

## Pause handling
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	# ... record the remaining time, disconnect the timer ...

## Resume handling
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	# ... recreate the timer ...
```

### RuntimeInstructionInstance Best Practices

#### 1. State Isolation Principle

**❌ Wrong** - using class member variables:
```gdscript
var _timer: SceneTreeTimer  # 多实例共享，会冲突！
var _count: int = 0  # 并发执行时会互相干扰
```

**✅ Correct** - using runtime_state:
```gdscript
func get_default_runtime_state() -> Dictionary:
	var state = super.get_default_runtime_state()
	state["timer"] = null  # 每个实例独立
	state["count"] = 0  # 每个实例独立
	return state

func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
	var state = runtime_instance.runtime_state
	state["timer"] = scene_tree.create_timer(delay)
	state["count"] += 1
```

#### 2. Callback Registration Mechanism

**You must use `register_timer_callback()`**:
```gdscript
var callback = _create_timer_callback(runtime_instance)
timer.timeout.connect(callback)
runtime_instance.register_timer_callback(callback)  # 关键！
state["current_timer_callback"] = callback  # 存储引用
```

**Reasons**:
- Ensures all callbacks are disconnected automatically when the instruction is cancelled
- Avoids memory leaks
- Supports correct disconnection when paused

#### 3. Validity Checks

**Callbacks must check instance validity at the start**:
```gdscript
func _on_runtime_timer_timeout(runtime_instance: RuntimeInstructionInstance):
	# 关键：检查实例是否仍然有效
	if not runtime_instance or runtime_instance.is_completed():
		return

	# Safely run the subsequent logic
```

#### 4. Completing Execution

**Use `_complete_execution()` rather than `finished.emit()`**:
```gdscript
# ✅ Correct
runtime_instance._complete_execution()

# ❌ Wrong (emits the signal twice)
finished.emit()
```

#### 5. Disconnecting When Paused

**Store the callback reference so it can be disconnected**:
```gdscript
# Store on creation
var callback = _create_timer_callback(runtime_instance)
timer.timeout.connect(callback)
state["current_timer_callback"] = callback

# Disconnect on pause
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	var callback = state.get("current_timer_callback")
	if callback and timer.timeout.is_connected(callback):
		timer.timeout.disconnect(callback)
```

### Multiple Timer Management Example

For instructions that need multiple timers (such as WaitUntil's polling timer and its timeout timer):

```gdscript
func get_default_runtime_state() -> Dictionary:
	var state = super.get_default_runtime_state()
	state["check_timer"] = null  # 轮询计时器
	state["timeout_timer"] = null  # 超时计时器
	state["current_poll_callback"] = null
	state["current_timeout_callback"] = null
	state["pause_remaining_timeout"] = 0.0
	return state

## Clean up the runtime timers
func _cleanup_runtime_timers(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state

	# Clean up the polling timer
	if state.has("check_timer") and state["check_timer"]:
		var check_timer = state["check_timer"]
		var poll_callback = state.get("current_poll_callback")
		if poll_callback and check_timer.timeout.is_connected(poll_callback):
			check_timer.timeout.disconnect(poll_callback)
		state["check_timer"] = null
		state["current_poll_callback"] = null

	# Clean up the timeout timer
	if state.has("timeout_timer") and state["timeout_timer"]:
		var timeout_timer = state["timeout_timer"]
		var timeout_callback = state.get("current_timeout_callback")
		if timeout_callback and timeout_timer.timeout.is_connected(timeout_callback):
			timeout_timer.timeout.disconnect(timeout_callback)
		state["timeout_timer"] = null
		state["current_timeout_callback"] = null
```

### When to Use RuntimeInstructionInstance

**Must use**:
- ✅ Asynchronous instructions (using timers, Tween, etc.)
- ✅ Instructions that need pause/resume
- ✅ Instructions that may be executed concurrently multiple times
- ✅ Instructions that need to track execution state

**Optional use**:
- Synchronous instructions (stateless, complete immediately)
- Simple instructions that execute once and do not need pausing

### Common Pitfalls

#### Pitfall 1: Forgetting to Call super.get_default_runtime_state()

**❌ Wrong**:
```gdscript
func get_default_runtime_state() -> Dictionary:
	return {
		"timer": null,
		"count": 0
	}  # 缺少基类状态！
```

**✅ Correct**:
```gdscript
func get_default_runtime_state() -> Dictionary:
	var state = super.get_default_runtime_state()  # 获取基类状态
	state["timer"] = null
	state["count"] = 0
	return state
```

#### Pitfall 2: Creating Callbacks with bind()

**❌ Wrong**:
```gdscript
timer.timeout.connect(_on_timer_timeout.bind(runtime_instance))
# bind() causes memory leaks!
```

**✅ Correct**:
```gdscript
var callback = func():
	_on_runtime_timer_timeout(runtime_instance)
timer.timeout.connect(callback)
runtime_instance.register_timer_callback(callback)
```

#### Pitfall 3: Not Disconnecting the Timer When Paused

**❌ Wrong**:
```gdscript
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
	pass  # 计时器继续运行，恢复时会出问题
```

**✅ Correct**:
```gdscript
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	if state["timer"]:
		var callback = state.get("current_timer_callback")
		if callback and state["timer"].timeout.is_connected(callback):
			state["timer"].timeout.disconnect(callback)
		state["timer"] = null
```

#### Pitfall 4: Forgetting to Register the Callback

**❌ Wrong**:
```gdscript
var callback = func(): _on_timeout(runtime_instance)
timer.timeout.connect(callback)
# Not registered! The connection will not be disconnected on cancellation
```

**✅ Correct**:
```gdscript
var callback = func(): _on_timeout(runtime_instance)
timer.timeout.connect(callback)
runtime_instance.register_timer_callback(callback)  # 必须注册
```

---

## Complete Instruction Template

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/Script.png")
extends BaseInstruction
class_name TemplateInstruction

## Instruction description

# Parameter definitions
var target_node: NodePath = NodePath("")

## Get the instruction metadata
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_XXX_NAME"
	metadata.category_key = "FUSE_CATEGORY_XXX"
	metadata.description_key = "FUSE_INSTRUCTION_XXX_DESC"
	metadata.keywords = ["keyword1", "keyword2"]
	metadata.builtin_icon = "Script"
	return metadata

## Set the instruction metadata
func _setup_metadata():
	pass

## Get the property list
func _get_property_list()  -> Array[Dictionary]:
	var properties := []

	# Category
	properties.append({
		name = "Category",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# Properties
	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## Update the resource name (required)
func _update_resource_name():
	var parts = []
	parts.append("操作名称")
	if not target_node.is_empty():
		parts.append("'%s'" % target_node)
	resource_name = " ".join(parts)

## Execute the instruction
func execute(context: ExecutionContext):
	_start_execution(context)

	# Validation
	if target_node.is_empty():
		_log_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", {})
		set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# Get the node
	var node := context.get_node(target_node)
	if not node:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	# Execution logic
	# ...

	# Synchronous completion
	_on_execution_completed()

## Validate the parameters (required)
func validate() -> Array[String]:
	var errors = super.validate()

	if target_node.is_empty():
		errors.append("目标节点路径不能为空")

	return errors

## Get the description (required)
func get_description() -> String:
	return "操作 %s" % str(target_node)

## Dynamic property setting (optional)
func _set(property: StringName, value: Variant) -> bool:
	if property == "some_property":
		set(property, value)
		notify_property_list_changed()
		_update_resource_name()
		return true
	return false

## Property validation (optional)
func _validate_property(property: Dictionary) -> void:
	if property.name == "some_property" and some_condition:
		property.usage = PROPERTY_USAGE_NO_EDITOR
```

---

## Instruction Template with Variable Operations

> **Important**: When an instruction needs to read or write variables, use the following template to ensure the three-layer variable system is used correctly.

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/Script.png")
extends BaseInstruction
class_name VariableOperationInstruction

## Instruction description

# Input variable name
var input_variable: String = ""

# Input variable scope
@export var input_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		input_scope = value
		_update_resource_name()

# Output variable name
var output_variable: String = "result"

# Output variable scope
@export var output_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		output_scope = value
		_update_resource_name()

## Get the instruction metadata
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_XXX_NAME"
	metadata.category_key = "FUSE_CATEGORY_XXX"
	metadata.description_key = "FUSE_INSTRUCTION_XXX_DESC"
	metadata.keywords = ["keyword1", "keyword2"]
	metadata.builtin_icon = "Script"
	return metadata

## Set the instruction metadata
func _setup_metadata():
	pass

## Get the property list
func _get_property_list()  -> Array[Dictionary]:
	var properties := []

	# Input category
	properties.append({
		name = "Input",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "input_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "input_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Output category
	properties.append({
		name = "Output",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "output_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "output_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## Update the resource name (required)
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_XXX_RESOURCE"))

	# Input variable
	if not input_variable.is_empty():
		var input_scope_str = VariableScopeUtils.enum_to_string(input_scope).to_upper()
		parts.append("← %s [%s]" % [input_variable, input_scope_str])
	else:
		parts.append("← (%s)" % FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY"))

	# Output variable
	if not output_variable.is_empty():
		var output_scope_str = VariableScopeUtils.enum_to_string(output_scope).to_upper()
		parts.append("→ %s [%s]" % [output_variable, output_scope_str])
	else:
		parts.append("→ (%s)" % FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY"))

	resource_name = " ".join(parts)

## Execute the instruction
func execute(context: ExecutionContext):
	_start_execution(context)

	# Validate the input variable name
	if input_variable.is_empty():
		_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# Read the input variable
	var input_value = VariableOperations.get_variable(
		context,
		input_variable,
		input_scope,
		null
	)

	# Check whether the variable exists
	if input_value == null and not VariableOperations.has_variable(
		context,
		input_variable,
		input_scope
	):
		_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": input_variable})
		set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"variable": input_variable})
		finished.emit()
		return

	# Perform the operation
	var result = _process_value(input_value)

	# Save the result to the output variable
	if not output_variable.is_empty():
		VariableOperations.set_variable(
			context,
			output_variable,
			output_scope,
			result
		)

	_on_execution_completed()

## Internal processing method
func _process_value(value: Variant) -> Variant:
	# Implement the concrete processing logic
	return value

## Validate the parameters (required)
func validate() -> Array[String]:
	var errors = super.validate()

	# Validate the input variable name
	if input_variable.is_empty():
		errors.append("输入变量名不能为空")

	# Validate the output variable name
	if output_variable.is_empty():
		errors.append("输出变量名不能为空")

	# Validating the input SCOPE scope requires ScopeVariableManager
	if input_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append("未找到 ScopeVariableManager 实例")

	# Validating the output SCOPE scope requires ScopeVariableManager
	if output_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append("未找到 ScopeVariableManager 实例")

	return errors

## Get the description (required)
func get_description() -> String:
	var input_scope_str = VariableScopeUtils.enum_to_string(input_scope).to_upper()
	var output_scope_str = VariableScopeUtils.enum_to_string(output_scope).to_upper()

	var input_str = input_variable if not input_variable.is_empty() else "(%s)" % FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY")
	var output_str = output_variable if not output_variable.is_empty() else "(%s)" % FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY")

	return FuseLocalization.translate_format("FUSE_INSTRUCTION_XXX_DESC_FORMAT", {
		"input": "%s [%s]" % [input_str, input_scope_str],
		"output": "%s [%s]" % [output_str, output_scope_str]
	})

## Dynamic property setting
func _set(property: StringName, value: Variant) -> bool:
	if property == "input_scope" or property == "output_scope":
		set(property, value)
		notify_property_list_changed()
		_update_resource_name()
		return true
	return false
```

**Key points**:
1. ✅ Use `@export var scope: BaseVariable.VariableScope` to define scope properties
2. ✅ Use `VariableOperations.get_variable()` to read variables
3. ✅ Use `VariableOperations.set_variable()` to write variables
4. ✅ Use `VariableOperations.has_variable()` to check variable existence
5. ✅ Use `VariableScopeUtils.enum_to_string()` to convert to display strings
6. ✅ In `validate()`, validate that the SCOPE scope requires ScopeVariableManager

---

## Creation Steps

### Step 1: Create the Instruction Class Skeleton

Create the instruction file `addons/fuse/instructions/<instruction_name>.gd`:

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/Script.png")
extends BaseInstruction
class_name YourInstruction

## Instruction description

# Parameter definitions
var target_node: NodePath = NodePath("")

## Get the instruction metadata
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_XXX_NAME"
	metadata.category_key = "FUSE_CATEGORY_XXX"
	metadata.description_key = "FUSE_INSTRUCTION_XXX_DESC"
	metadata.keywords = ["keyword1", "keyword2"]
	metadata.builtin_icon = "Script"
	return metadata

## Set the instruction metadata
func _setup_metadata():
	pass

## Get the property list
func _get_property_list()  -> Array[Dictionary]:
	var properties := []
	# ... (refer to the template)
	return properties

## Update the resource name (required)
func _update_resource_name():
	# ...

## Execute the instruction
func execute(context: ExecutionContext):
	# ...

## Validate the parameters (required)
func validate() -> Array[String]:
	# ...

## Get the description (required)
func get_description() -> String:
	# ...
```

### Step 2: Add Localization Translations

Add to `addons/fuse/localization/translations.csv`:

```csv
key,zh_CN,en_US
FUSE_INSTRUCTION_XXX_NAME,指令名称,Instruction Name
FUSE_CATEGORY_XXX,分类名称,Category Name
FUSE_INSTRUCTION_XXX_DESC,指令描述,Instruction description
FUSE_ERROR_XXX_ERROR,错误消息,Error message
```

**Notes**:
- Use the `NAME` suffix for instruction names
- Use the `DESC` suffix for instruction descriptions
- Use `ERROR_XXX_ERROR` for error messages
- All placeholders use the `{variable_name}` format

### Step 3: Create the Test Scene

**Step 3.1: Create the test scene file**

Create `tests/instructions/test_<instruction_name>.tscn`:

```gdscript
[gd_scene load_steps=2 format=3 uid="uid://test_xxx"]

[ext_resource type="Script" path="res://tests/instructions/test_xxx.gd" id="1"]

[node name="TestXxx" type="Node3D"]
script = ExtResource("1")

[node name="TestNode2D" type="Node2D" parent="."]
position = Vector2(100, 100)

[node name="TestNode3D" type="Node3D" parent="."]
position = Vector3(0, 0, 0)
```

**Step 3.2: Create the test script**

Create `tests/instructions/test_<instruction_name>.gd`:

```gdscript
extends Node3D

## YourInstruction instruction test

func _ready():
	print("=== Testing YourInstruction ===")
	test_basic_functionality()
	test_edge_cases()
	print("=== All YourInstruction tests passed! ===")

func test_basic_functionality():
	print("Test 1: Basic functionality")

	var instruction_script = load("res://addons/fuse/instructions/your_instruction.gd")
	var instruction = instruction_script.new()
	instruction.target_node = NodePath(".")
	# Set other parameters...

	var context = ExecutionContext.new()
	add_child(context)

	# Record the state before execution
	var initial_state = ...

	# Execute the instruction
	instruction.execute(context)
	await get_tree().process_frame

	# Verify the result
	assert(condition, "Verification message")
	print("  ✓ Test 1 passed\n")

func test_edge_cases():
	print("Test 2: Edge cases")
	# Test edge cases...
	print("  ✓ Test 2 passed\n")
```


### Step 4: Test and Verify

1. Open the test scene in Godot
2. Run the tests and confirm all test cases pass
3. Check that the Inspector display in the editor is correct
4. Verify that localization takes effect

---

## Best Practices

### 1. Error Handling

**Principle**: All errors should use localized error messages.

```gdscript
# ✅ Good practice
if target_node.is_empty():
	_log_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", {})
	set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
	finished.emit()
	return

# ❌ Avoid hardcoding
if target_node.is_empty():
	_log_error("目标节点不能为空")  # 不推荐
	return
```

### 2. Resource Cleanup

**Principle**: Asynchronous instructions must clean up resources properly (timers, Tweens, etc.).

```gdscript
func _cleanup_resources() -> void:
	if _timer and is_instance_valid(_timer):
		if _timer.timeout.is_connected(_on_timer_timeout):
			_timer.timeout.disconnect(_on_timer_timeout)
		_timer = null
```

### 3. Type Annotations

**Principle**: Use explicit type annotations to avoid type inference issues.

```gdscript
# ✅ Recommended
var node: Node = context.get_node(target_node)

# ✅ Also fine (using :=)
var node := context.get_node(target_node)

# ❌ Avoid
var node: Node  # 未初始化
node = context.get_node(target_node)
```

### 4. Property Validation

**Principle**: Use `_validate_property()` to control property visibility dynamically.

```gdscript
func _validate_property(property: Dictionary) -> void:
	# Conditionally show a property
	if property.name == "optional_param" and not show_optional:
		property.usage = PROPERTY_USAGE_NO_EDITOR
```

### 5. Property Refresh

**Principle**: When modifying a property that affects other properties, call `notify_property_list_changed()`.

```gdscript
func _set(property: StringName, value: Variant) -> bool:
	if property == "use_variable":
		set(property, value)
		notify_property_list_changed()  # 刷新属性列表
		return true
	return false
```

### 6. Code Organization

**Principle**: Organize code by function and add clear comments.

```gdscript
## Validation logic
func _validate_params(context: ExecutionContext) -> bool:
	# ...

## Execute the core logic
func _execute_core(context: ExecutionContext):
	# ...

## Clean up resources
func _cleanup_resources():
	# ...
```

### 7. Variable System Best Practices

**Principle**: Follow consistent patterns and conventions when using the three-layer variable system.

#### 7.1 Prefer VariableOperations

**✅ Recommended**:
```gdscript
# Use VariableOperations uniformly to access variables
var value = VariableOperations.get_variable(context, var_name, var_scope, default_value)
VariableOperations.set_variable(context, var_name, var_scope, new_value)
```

**❌ Avoid direct access**:
```gdscript
# Not recommended: access context or global_variables directly
var value = context.local_variables.get(var_name, default_value)
context.global_variables.set_variable(var_name, value)
```

#### 7.2 Use Type-Safe Enums

**✅ Recommended**:
```gdscript
# Use a type-safe enum
@export var value_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		value_scope = value
		_update_resource_name()
```

**❌ Avoid booleans**:
```gdscript
# Not recommended: use a boolean for the scope
var is_global: bool = false
```

#### 7.3 Validate the SCOPE Scope

**✅ Recommended**:
```gdscript
func validate() -> Array[String]:
	var errors = super.validate()

	# Validate the variable name
	if variable_name.is_empty():
		errors.append("变量名不能为空")

	# Validating the SCOPE scope requires ScopeVariableManager
	if value_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append("未找到 ScopeVariableManager 实例")

	return errors
```

#### 7.4 Distinguish "Variable Does Not Exist" from "Value Is null"

**✅ Recommended**:
```gdscript
# Read the variable
var value = VariableOperations.get_variable(context, var_name, var_scope, null)

# Check whether the variable exists (distinguish "does not exist" from "value is null")
if value == null and not VariableOperations.has_variable(context, var_name, var_scope):
	_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": var_name})
	finished.emit()
	return

# A null value is valid at this point (the variable does exist, but its value is null)
```

#### 7.5 Use VariableScopeUtils for Consistent Display Formatting

**✅ Recommended**:
```gdscript
# Show the scope in the description
var scope_str = VariableScopeUtils.enum_to_string(value_scope).to_upper()
var description = "变量 %s [%s]" % [var_name, scope_str]

# Show it in the resource name
func _update_resource_name():
	var scope_str = VariableScopeUtils.enum_to_string(save_to_scope).to_upper()
	resource_name = "Set %s → %s [%s]" % [property, var_name, scope_str]
```

**❌ Avoid manual conversion**:
```gdscript
# Not recommended: manual match conversion
var scope_str = ""
match value_scope:
	BaseVariable.VariableScope.LOCAL:
		scope_str = "LOCAL"
	BaseVariable.VariableScope.SCOPE:
		scope_str = "SCOPE"
	BaseVariable.VariableScope.GLOBAL:
		scope_str = "GLOBAL"
```

#### 7.6 Variable Scope Selection Guide

**When to use LOCAL**:
- ✅ Temporary data for a single instruction execution
- ✅ Intermediate computation results
- ✅ Loop counters
- ❌ Data that needs to be shared across instructions
- ❌ Data that needs to persist

**When to use SCOPE**:
- ✅ Scene-local shared data
- ✅ UI component state
- ✅ Node group configuration
- ❌ Global game configuration
- ❌ Cross-scene shared data
- ⚠️ Requires adding a ScopeVariableContainer node

**When to use GLOBAL**:
- ✅ Game configuration (volume, graphics quality, etc.)
- ✅ Player data (level, experience, inventory)
- ✅ Game progress (current level, quest state)
- ✅ Cross-scene shared data
- ❌ Temporary data
- ❌ Scene-local data

#### 7.7 Complete Variable Operation Workflow

**Standard pattern**:
```gdscript
# 1. Define the variable scope property
@export var value_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		value_scope = value
		_update_resource_name()

# 2. Add the scope selection to the property list
func _get_property_list()  -> Array[Dictionary]:
	var properties := []
	properties.append({
		name = "value_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	return properties

# 3. Read the variable
func execute(context: ExecutionContext):
	var value = VariableOperations.get_variable(
		context,
		variable_name,
		value_scope,
		null
	)

	# 4. Verify variable existence
	if value == null and not VariableOperations.has_variable(
		context,
		variable_name,
		value_scope
	):
		_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": variable_name})
		set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"variable": variable_name})
		finished.emit()
		return

	# 5. Use the variable...

# 6. Use VariableScopeUtils in display methods
func _update_resource_name():
	var scope_str = VariableScopeUtils.enum_to_string(value_scope).to_upper()
	resource_name = "%s [%s]" % [variable_name, scope_str]

# 7. Check the SCOPE prerequisites in validation
func validate() -> Array[String]:
	var errors = super.validate()
	if value_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append("未找到 ScopeVariableManager 实例")
	return errors
```

---

## Common Pitfalls

### Pitfall 1: Using Node Methods in a Resource

**Problem**:
```gdscript
var tree = get_tree()  # ❌ 在指令中不可用
```

**Solution**:
```gdscript
var scene_tree = Engine.get_main_loop()
if scene_tree:
	# Use scene_tree
```

### Pitfall 2: Forgetting to Call _start_execution()

**Problem**:
```gdscript
func execute(context: ExecutionContext):
	# ❌ Forgot to call _start_execution()
	# Execution logic...
```

**Solution**:
```gdscript
func execute(context: ExecutionContext):
	_start_execution(context)  # ✅ 必须首先调用
	# Execution logic...
```

### Pitfall 3: Confusing Synchronous and Asynchronous

**Problem**:
```gdscript
func execute(context: ExecutionContext):
	# Synchronous completion
	_on_execution_completed()

	# Emits the completion signal again ❌ conflict
	finished.emit()
```

**Solution**:
- Synchronous instructions: only call `_on_execution_completed()`
- Asynchronous instructions: only call `finished.emit()` in the callback

### Pitfall 4: Relative Path Resolution Failure

**Problem**:
```gdscript
var node = get_node(target_node)  # ❌ 无法正确解析相对路径
```

**Solution**:
```gdscript
var node = context.get_node(target_node)  # ✅ 支持相对路径
```

### Pitfall 5: Global Variable Access

**Problem**:
```gdscript
GlobalVariableAssistant.set_variable(name, value)  # ❌ 静态方法不存在
```

**Solution**:
```gdscript
if context.global_variables:
	context.global_variables.set_variable(name, value)  # ✅ 正确
```

### Pitfall 6: Type Inference Failure

**Problem**:
```gdscript
var result: int
# Not initialized; a later assignment may fail type inference
```

**Solution**:
```gdscript
var result: int = 0  # ✅ 初始化
var result := calculate()  # ✅ 使用 :=
```

### Pitfall 7: NaN and Infinity Validation

**Problem**: Missing boundary value validation

**Solution**:
```gdscript
func _is_valid_value(value: Vector3) -> bool:
	return not (is_nan(value.x) or is_inf(value.x) or
				is_nan(value.y) or is_inf(value.y) or
				is_nan(value.z) or is_inf(value.z))
```

### Pitfall 8: Godot 4.x API Changes

**Problem**: Using Godot 3.x APIs

**Solution**:
- AudioServer: use `get_bus_count()` + `get_bus_name(i)`
- Tween: use `scene_tree.create_tween()`
- SceneTree: use `Engine.get_main_loop()`

### Pitfall 9: Using Deprecated Variable Access APIs

**Problem**: Using old variable access methods

**❌ Wrong usage**:
```gdscript
# Old API (deprecated)
var value = context.get_variable(var_name, is_global, default_value)
context.set_variable(var_name, is_global, value)

# Or direct access
if context.global_variables:
	context.global_variables.set_variable(var_name, value)
```

**✅ Correct usage**:
```gdscript
# New API (recommended)
var value = VariableOperations.get_variable(
	context,
	var_name,
	var_scope,  # BaseVariable.VariableScope
	default_value
)

VariableOperations.set_variable(
	context,
	var_name,
	var_scope,  # BaseVariable.VariableScope
	new_value
)
```

### Pitfall 10: Using a Boolean for the Variable Scope

**Problem**: `is_global: bool` cannot support the three-layer variable system

**❌ Wrong usage**:
```gdscript
var is_global: bool = false

func execute(context: ExecutionContext):
	if is_global:
		value = context.global_variables.get_variable(var_name)
	else:
		value = context.local_variables.get(var_name)
```

**✅ Correct usage**:
```gdscript
@export var var_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

func execute(context: ExecutionContext):
	value = VariableOperations.get_variable(context, var_name, var_scope, default_value)
```

### Pitfall 11: Forgetting to Validate SCOPE Prerequisites

**Problem**: The SCOPE scope requires a ScopeVariableManager instance, but it is not validated

**❌ Wrong**:
```gdscript
func validate() -> Array[String]:
	var errors = super.validate()

	if variable_name.is_empty():
		errors.append("变量名不能为空")

	# ❌ Missing SCOPE validation
	return errors
```

**✅ Correct**:
```gdscript
func validate() -> Array[String]:
	var errors = super.validate()

	if variable_name.is_empty():
		errors.append("变量名不能为空")

	# ✅ Validating the SCOPE scope requires ScopeVariableManager
	if var_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append("未找到 ScopeVariableManager 实例")

	return errors
```

### Pitfall 12: Confusing "Variable Does Not Exist" with "Variable Value Is null"

**Problem**: Not using `has_variable()` to check variable existence

**❌ Wrong**:
```gdscript
var value = VariableOperations.get_variable(context, var_name, var_scope, null)

if value == null:
	# ❌ Cannot distinguish "variable does not exist" from "variable value is null"
	_log_error("变量未找到")
	return
```

**✅ Correct**:
```gdscript
var value = VariableOperations.get_variable(context, var_name, var_scope, null)

# ✅ Check whether the variable exists
if value == null and not VariableOperations.has_variable(context, var_name, var_scope):
	_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": var_name})
	return

# A null value is valid at this point (the variable does exist, but its value is null)
```

### Pitfall 13: Manually Converting the Scope Enum to a String

**Problem**: Duplicating the scope conversion logic

**❌ Wrong**:
```gdscript
var scope_str = ""
match value_scope:
	BaseVariable.VariableScope.LOCAL:
		scope_str = "LOCAL"
	BaseVariable.VariableScope.SCOPE:
		scope_str = "SCOPE"
	BaseVariable.VariableScope.GLOBAL:
		scope_str = "GLOBAL"
```

**✅ Correct**:
```gdscript
# Use the VariableScopeUtils utility class
var scope_str = VariableScopeUtils.enum_to_string(value_scope).to_upper()
```

### Pitfalls 14-17: RuntimeInstructionInstance-Related Pitfalls

> **Important**: For asynchronous instructions, the RuntimeInstructionInstance architecture has several critical pitfalls to avoid.
> See [RuntimeInstructionInstance Architecture Support - Common Pitfalls](#common-pitfalls-1) for details.

**Pitfall overview**:
- **Pitfall 14**: Forgetting to call `super.get_default_runtime_state()` - missing base class state
- **Pitfall 15**: Creating callbacks with `bind()` - causes memory leaks
- **Pitfall 16**: Not disconnecting the timer when paused - causes problems on resume
- **Pitfall 17**: Forgetting to register the callback - the connection is not disconnected on cancellation

---

## Testing Guidelines

### Test File Structure

```gdscript
extends Node3D  # 或 Node，根据指令类型选择

## InstructionName instruction test

func _ready():
	print("=== Testing InstructionName ===")
	test_case_1()
	test_case_2()
	test_case_3()
	print("=== All InstructionName tests passed! ===")
```

### Test Case Design

**Required tests**:
1. **Basic functionality test** - verify the instruction works correctly
2. **Boundary value test** - test NaN, Infinity, and large values
3. **Error handling test** - verify error cases are handled correctly
4. **2D/3D compatibility** - if applicable, test both node types
5. **Variable input test** - test reading parameters from variables

**Test example**:
```gdscript
func test_basic_functionality():
	var instruction = InstructionName.new()
	instruction.param = value

	var context = ExecutionContext.new()
	add_child(context)

	instruction.execute(context)
	await get_tree().process_frame

	assert(condition, "Should pass")
```

### Test Assertions

```gdscript
# Verify the results
assert(actual == expected, "Error message")
assert(context.had_error() == should_error, "Should have error")
assert(abs(actual - expected) < 0.01, "Should be approximately equal")
```

---

## Quick Reference

### Common Code Snippets

#### Node Operations
```gdscript
var node := context.get_node(target_node)
if not node:
	_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
	set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
	finished.emit()
	return
```

#### SceneTree Operations
```gdscript
var scene_tree = Engine.get_main_loop()
if not scene_tree:
	_log_error_localized("FUSE_ERROR_CANNOT_GET_SCENETREE", {})
	finished.emit()
	return

var current_scene = scene_tree.current_scene
var timer = scene_tree.create_timer(duration)
```

#### Audio Operations
```gdscript
var bus_names = []
for i in range(AudioServer.get_bus_count()):
	bus_names.append(AudioServer.get_bus_name(i))
```

#### Variable Operations (Using VariableOperations)

**Reading a variable**:
```gdscript
# Read a variable (supports the three-layer scopes)
var value = VariableOperations.get_variable(
	context,
	var_name,
	var_scope,  # BaseVariable.VariableScope
	default_value
)

# Check whether the variable exists (distinguish "does not exist" from "value is null")
if value == null and not VariableOperations.has_variable(context, var_name, var_scope):
	_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": var_name})
	set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"variable": var_name})
	finished.emit()
	return
```

**Setting a variable**:
```gdscript
# Set a variable (supports the three-layer scopes)
VariableOperations.set_variable(
	context,
	var_name,
	var_scope,  # BaseVariable.VariableScope
	new_value
)
```

**Complete example**:
```gdscript
# Instruction property definitions
@export var value_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		value_scope = value
		_update_resource_name()

# Read and use the variable
func execute(context: ExecutionContext):
	var value = VariableOperations.get_variable(context, var_name, value_scope, null)

	if value == null and not VariableOperations.has_variable(context, var_name, value_scope):
		_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": var_name})
		finished.emit()
		return

	# Use value...
```

**Scope string conversion**:
```gdscript
# Enum to string
var scope_str = VariableScopeUtils.enum_to_string(value_scope).to_upper()
# Result: "LOCAL", "SCOPE", or "GLOBAL"

# Use in a description
var description = "变量 %s [%s]" % [var_name, scope_str]
```

### Common Error Keys

Defined localization error keys (see `translations.csv`):
- `FUSE_ERROR_TARGET_NODE_EMPTY` - target node is empty
- `FUSE_ERROR_TARGET_NODE_NOT_FOUND` - target node not found
- `FUSE_ERROR_VAR_NAME_EMPTY` - variable name is empty
- `FUSE_ERROR_VAR_NOT_FOUND` - variable not found
- `FUSE_ERROR_NODE_TYPE_INVALID` - invalid node type
- `FUSE_ERROR_INVALID_POSITION` - invalid position value
- `FUSE_ERROR_INVALID_ROTATION` - invalid rotation value
- `FUSE_ERROR_INVALID_SCALE` - invalid scale value
- `FUSE_ERROR_CANNOT_GET_SCENETREE` - cannot get the SceneTree
- `FUSE_ERROR_CANNOT_GET_CURRENT_SCENE` - cannot get the current scene
- `FUSE_ERROR_CANNOT_CREATE_TIMER` - cannot create a timer
- `FUSE_ERROR_CANNOT_CREATE_TWEEN` - cannot create a Tween

---

## Summary

Key points for creating Fuse instructions:

1. ✅ **Follow the naming conventions** - concise, consistent, no redundancy
2. ✅ **Implement the required methods** - `_update_resource_name()`, `validate()`, `get_description()`
3. ✅ **Use the correct APIs** - `context.get_node()`, `Engine.get_main_loop()`
4. ✅ **Localize error messages** - use `_log_error_localized()`
5. ✅ **Handle synchronous/asynchronous correctly** - synchronous uses `_on_execution_completed()`, asynchronous uses `finished.emit()`
6. ✅ **Add complete tests** - basic functionality + edge cases
7. ✅ **Clean up resources** - asynchronous instructions must clean up timers and Tweens
8. ✅ **Use the three-layer variable system** - access LOCAL/SCOPE/GLOBAL variables uniformly through `VariableOperations`
9. ✅ **Type-safe scopes** - use the `BaseVariable.VariableScope` enum instead of booleans
10. ✅ **Validate SCOPE prerequisites** - check that a `ScopeVariableManager` instance exists
11. ✅ **Implement RuntimeInstructionInstance support** - asynchronous instructions should implement `get_default_runtime_state()` and `execute_with_runtime_instance()`

**Variable system key points**:
- Use `VariableOperations.get_variable/set_variable/has_variable()` to access variables
- Use `VariableScopeUtils.enum_to_string()` to convert to display strings
- Use `@export var scope: BaseVariable.VariableScope` to define scope properties
- In `validate()`, validate that the SCOPE scope requires `ScopeVariableManager`
- Use `has_variable()` to distinguish "variable does not exist" from "variable value is null"

**RuntimeInstructionInstance key points**:
- Asynchronous instructions **must** implement `get_default_runtime_state()` to declare runtime state
- Use the `runtime_state` dictionary to store instance state, **not** class member variables
- Create callbacks with closures and register them by calling `register_timer_callback()`
- Store the callback reference (`current_timer_callback`) so it can be disconnected when paused
- Check `runtime_instance.is_completed()` at the start of callbacks to ensure validity
- Use `runtime_instance._complete_execution()` to complete execution, **not** a manual `finished.emit()`
- Implementing pause/resume requires adding `on_runtime_pause()` and `on_runtime_resume()` methods

**Reference documents**:
- [Complete Instruction Template](#complete-instruction-template)
- [Instruction Template with Variable Operations](#instruction-template-with-variable-operations)
- [RuntimeInstructionInstance Architecture Support](#runtimeinstructioninstance-architecture-support)
- [Variable System Best Practices](#7-variable-system-best-practices)
- [Phase 0B Experience Summary](#key-technical-points)
- [Testing Guidelines](#testing-guidelines)
- [Variable System Design Document](../../system_docs/architecture/variable_system_design.md)

---

**Document maintainer**: Fuse development team
**Last updated**: 2026-06-17
**Important updates**: Added documentation for CompletionSignalTiming, ExecutionMode, cancel(), and timeout management
