> 🌐 [**中文版**](../../../zh_CN/user_docs/best_practices/custom_instruction.md) | English

# Custom Instruction Creation Best Practices Guide

## Overview

This guide is based on the Instruction architecture of the Fuse Visual Programming system and provides complete best practices for creating custom Instruction classes. By following these practices, you can create efficient, reliable, and easy-to-maintain custom instructions.

## Table of Contents

1. [Instruction Architecture Basics](#instruction-architecture-basics)
2. [Core Method Implementation](#core-method-implementation)
3. [Lifecycle Management](#lifecycle-management)
4. [Error Handling and Logging](#error-handling-and-logging)
5. [Performance Optimization](#performance-optimization)
6. [Common Implementation Patterns](#common-implementation-patterns)
7. [Complete Example](#complete-example)
8. [Testing and Validation](#testing-and-validation)

---

## Instruction Architecture Basics

### BaseInstruction Core Responsibilities

`BaseInstruction` is the base class of all instruction classes and provides the following core capabilities:

- **Execution framework**: a unified instruction execution flow and state management
- **Signal system**: the `finished` signal is used to notify execution completion
- **Lifecycle management**: the `execute()` and `_cleanup_resources()` methods manage the instruction lifecycle
- **Error handling**: the unified `FuseError` error handling mechanism (including localized errors)
- **Metadata**: instruction name, category, and description information (via the InstructionMetadata class)
- **Timeout management**: built-in timeout detection and handling
- **Execution state management**: complete execution state tracking (the ExecutionStatus enum)
- **Completion timing control**: two completion signal timings are supported (CompletionSignalTiming)
- **Execution mode optimization**: smart execution mode detection (ExecutionMode)
- **Performance optimization**: the localization class cache improves performance by about 70%

### Instruction Lifecycle

```
创建 → _init() → _setup_metadata() → execute() → [执行逻辑] → finished.emit() → _cleanup_resources()
```

1. **Creation phase**: the Instruction resource is instantiated
2. **Initialization phase**: `_init()` and `_setup_metadata()` are called to set up the instruction information
3. **Execution phase**: `execute()` is called to run the concrete logic
4. **Completion phase**: the `finished` signal is emitted and resources are cleaned up

### Execution State Management (ExecutionStatus Enum)

An instruction goes through the following states during execution:

- **PENDING**: waiting to execute (initial state)
- **RUNNING**: currently executing
- **COMPLETED**: execution completed
- **CANCELLED**: cancelled
- **ERROR**: an error occurred during execution

**State transition rules:**
```
PENDING → RUNNING → COMPLETED
                ↘ ERROR
                ↘ CANCELLED
```

### Completion Signal Timing (CompletionSignalTiming Enum)

Two completion signal timings are supported:

- **ON_START**: the completion signal is sent when execution starts (for instructions that complete immediately)
- **ON_FINISH**: the completion signal is sent when execution finishes (default, for most instructions)

### Execution Mode (ExecutionMode Enum)

Smart execution mode optimization:

- **AUTO_DETECT**: auto-detect the execution mode (recommended, default)
- **FORCE_ASYNC**: force asynchronous execution
- **FORCE_SYNC**: force synchronous execution

---

## Core Method Implementation

### 1. Required Abstract Methods

#### _get_instruction_metadata() - Static Method

Sets up the instruction's basic information and metadata, using the static method pattern:

```gdscript
static func _get_instruction_metadata() -> InstructionMetadata:
	metadata = InstructionMetadata.new()
	metadata.name = "我的指令"
	metadata.description = "这是一个自定义指令"
	metadata.category = "自定义"
	metadata.version = "1.0"
	metadata.author = "开发者"
	metadata.keywords = ["关键词1", "关键词2"]
	return metadata
```

**InstructionMetadata class properties:**
- `name`: the instruction's display name (required)
- `description`: a detailed description of the instruction (required)
- `category`: the instruction's category, used for organization in the editor (required)
- `version`: instruction version (optional)
- `author`: author information (optional)
- `keywords`: a keyword list used for search (optional)
- `icon`: instruction icon (optional)

**Important notes:**
- This static method must be implemented; it is used by the instruction picker and the registration system
- `name`, `description`, and `category` must be set
- The metadata object must be returned
- The metadata is cached to avoid repeated creation

#### _setup_metadata()

Sets up the instruction's instance metadata (optional):

```gdscript
func _setup_metadata():
	# Usually left empty because the metadata is already set in the static method
	pass
```

**Notes:**
- This method still needs to be implemented (it is an abstract method), but it usually just stays empty
- The actual metadata setup is done in the static method `_get_instruction_metadata()`

#### execute(context: ExecutionContext)

Implements the instruction's core logic:

```gdscript
func execute(context: ExecutionContext):
	# Mandatory: this method must be called to initialize the execution state
	_start_execution(context)
	
	# Validate parameters
	if not _validate_parameters():
		set_error("参数验证失败", FuseError.ErrorType.VALIDATION_ERROR)
		finished.emit()
		return
	
	# Run the instruction logic
	_execute_instruction_logic(context)
	
	# Mark completion
	_on_execution_completed()
```

**Important notes:**
- The `_start_execution(context)` call is mandatory and must be the first operation in the `execute()` method
- This method sets the execution state to RUNNING, records the start time, and starts the timeout timer
- Omitting this call breaks the instruction's state management

#### _update_resource_name()

Updates the name displayed for the instruction in the editor list, so users can see at a glance what the instruction does and which parameters it uses:

```gdscript
func _update_resource_name():
	resource_name = "指令类型: 参数值"
```

**Important notes:**
- This is an abstract method and must be implemented in subclasses
- Call this method only in property setters so the name is updated in sync whenever a parameter changes
- There is no need to call it in `_init()` or `_setup_metadata()`, because this method only affects editor display
- The name should be concise and contain the most important parameter information
- Avoid including too much detail in the name; keep it readable

**Implementation example:**

```gdscript
# Called in property setters
@export var message: String = "Hello":
	set(value):
		message = value
		_update_resource_name()

@export var wait_time: float = 1.0:
	set(value):
		wait_time = value
		_update_resource_name()

# Implements the update method
func _update_resource_name():
	if wait_time > 0:
		resource_name = "等待 %.1f 秒: %s" % [wait_time, message]
	else:
		resource_name = "立即: %s" % message
```

### 2. Recommended Overrides

#### get_description() -> String

Provides the instruction description:

```gdscript
func get_description() -> String:
	return "执行 %s 操作，参数: %s" % [metadata.name, parameter]
```

#### validate() -> Array[String]

Validates the instruction configuration:

```gdscript
func validate() -> Array[String]:
	var errors: Array[String] = []
	
	# Call the base class validation
	errors.append_array(super.validate())
	
	# Add custom validation
	if required_parameter <= 0:
		errors.append("参数值必须大于0")
	
	return errors
```

#### _cleanup_resources()

Releases resources used during instruction execution:

```gdscript
func _cleanup_resources():
	super._cleanup_resources()
	
	# Clean up the timer
	if _timer:
		if _timer.timeout.is_connected(_on_timer_timeout):
			_timer.timeout.disconnect(_on_timer_timeout)
		_timer = null
	
	# Clean up other resources
	_custom_resources.clear()
```

#### cancel()

Handles instruction cancellation:

```gdscript
func cancel():
	# Stop in-progress operations
	if _timer:
		_timer.timeout.disconnect(_on_timer_timeout)
		_timer = null
	
	# Call the base class cancel method
	super.cancel()
```

---

## Lifecycle Management

### Resource Management Best Practices

#### 1. Execution State Management

```gdscript
func execute(context: ExecutionContext):
	_start_execution(context)
	
	# Check the execution state
	if execution_status != ExecutionStatus.RUNNING:
		_log_warning("指令不在运行状态，跳过执行")
		return
	
	# Run the logic
	_perform_instruction_logic()
```

#### 2. Async Operation Management

```gdscript
var _timer: SceneTreeTimer = null
var _async_operation: AsyncOperation = null

func execute(context: ExecutionContext):
	_start_execution(context)
	
	# Create the async operation
	_timer = Engine.get_main_loop().create_timer(wait_time)
	_timer.timeout.connect(_on_operation_completed)

func _cleanup_resources():
	super._cleanup_resources()
	
	# Clean up the async operation
	if _timer:
		if _timer.timeout.is_connected(_on_operation_completed):
			_timer.timeout.disconnect(_on_operation_completed)
		_timer = null
	
	if _async_operation:
		_async_operation.cancel()
		_async_operation = null
```

#### 3. Timeout Management

```gdscript
func execute(context: ExecutionContext):
	# Set the timeout
	set_timeout(30.0)  # 30秒超时
	
	_start_execution(context)
	# Execution logic...

func _on_timeout():
	_log_error("指令执行超时")
	set_error("指令执行超时", FuseError.ErrorType.TIMEOUT_ERROR)
	finished.emit()
```

---

## Error Handling and Logging

### 1. Unified Error Handling

```gdscript
func execute(context: ExecutionContext):
	_start_execution(context)
	
	# Parameter validation
	if not _validate_parameters():
		set_error("参数验证失败", FuseError.ErrorType.VALIDATION_ERROR, {
			"parameter_name": parameter_name,
			"parameter_value": parameter_value
		})
		finished.emit()
		return
	
	# Run the logic
	var result = _perform_operation()
	if result.is_error():
		set_error("操作失败: %s" % result.get_error_message(), FuseError.ErrorType.EXECUTION_ERROR)
		finished.emit()
		return
	
	_on_execution_completed()
```

**Error handling best practices:**
- Use the `set_error()` method directly; there is no need to pre-create a FuseError object
- Provide meaningful error messages that contain enough context
- Use the appropriate error type
- Provide error context information to ease debugging
- Emit the `finished` signal and return immediately after setting the error

### 2. Localized Error Handling

Localized error messages are supported to enable multi-language support:

```gdscript
func execute(context: ExecutionContext):
	_start_execution(context)

	# Parameter validation - use a localized error
	if not _validate_parameters():
		set_error_localized(
			"FUSE_ERROR_PARAMETER_VALIDATION_FAILED",
			FuseError.ErrorType.VALIDATION_ERROR,
			{"param_name": parameter_name}  # 翻译参数
		)
		finished.emit()
		return

	# Execution logic...
```

**Error types (FuseError.ErrorType):**

- **VALIDATION_ERROR**: parameter validation error
- **CONFIGURATION_ERROR**: configuration error
- **EXECUTION_ERROR**: execution error (default)
- **RUNTIME_ERROR**: runtime error
- **TIMEOUT_ERROR**: timeout error
- **NOT_FOUND_ERROR**: resource or node not found
- **PERMISSION_ERROR**: permission error
- **NETWORK_ERROR**: network error

**Advantages of localized errors:**
- Supports multi-language UIs
- Centralizes error message management
- Easier to translate and maintain
- Better user experience

### 3. Leveled Logging

```gdscript
func execute(context: ExecutionContext):
	_log_debug("开始执行指令: %s" % metadata.name)
	
	# Execution logic
	_log_info("正在执行操作...")
	
	if condition_met:
		_log_debug("条件满足，继续执行")
	else:
		_log_warning("条件不满足，跳过操作")
		return
	
	_log_info("指令执行完成")
```

### 3. Context Information Logging

```gdscript
func set_error(message: String, error_type: FuseError.ErrorType = FuseError.ErrorType.EXECUTION_ERROR, context: Dictionary = {}):
	var error_context = context.duplicate()
	error_context["instruction_name"] = metadata.name
	error_context["instruction_category"] = metadata.category
	error_context["execution_time"] = get_execution_time()
	
	super.set_error(message, error_type, error_context)
```

---

## Advanced Features

### 1. Timeout Management

BaseInstruction provides complete timeout management that prevents instructions from executing indefinitely:

#### Basic Timeout Setup

```gdscript
func execute(context: ExecutionContext):
	# Set the timeout (seconds)
	set_timeout(30.0)  # 30秒超时
	
	_start_execution(context)
	
	# Perform operations that may take a while...
```

#### Timeout Query Methods

```gdscript
# Check whether a timeout is enabled
func has_timeout() -> bool:
	return _timeout_duration > 0.0

# Get the current timeout setting
func get_timeout() -> float:
	return _timeout_duration

# Get the elapsed execution time
func get_execution_time() -> float:
	if execution_status == ExecutionStatus.RUNNING:
		return (Time.get_ticks_msec() / 1000.0) - _execution_start_time
	return 0.0
```

#### Custom Timeout Handling

```gdscript
# Override the timeout handling method (optional)
func _on_timeout():
	var elapsed_time = get_execution_time()
	var error_msg = "指令执行超时 (%.2f 秒 > %.2f 秒)" % [elapsed_time, _timeout_duration]
	
	# Provide a detailed timeout context
	var timeout_context = {
		"elapsed_time": elapsed_time,
		"timeout_duration": _timeout_duration,
		"instruction_type": get_class()
	}
	
	set_error(error_msg, FuseError.ErrorType.TIMEOUT_ERROR, timeout_context)
	finished.emit()
```

**Timeout management best practices:**
- Set a reasonable timeout for instructions that may run for a long time
- Document the expected execution time in the instruction description
- Use longer timeouts for network operations or file I/O
- For compute-intensive operations, set the timeout according to complexity

### 2. Completion Signal Timing

BaseInstruction supports two completion signal timings, controlled by the `CompletionSignalTiming` enum:

#### ON_FINISH Mode (Default)

```gdscript
# The signal is sent when the instruction finishes executing (default behavior)
func _init():
	completion_timing = CompletionSignalTiming.ON_FINISH

func execute(context: ExecutionContext):
	_start_execution(context)
	
	# Instruction logic...
	
	# Calling _on_execution_completed() here emits the finished signal
	_on_execution_completed()
```

#### ON_START Mode

```gdscript
# The signal is sent immediately when the instruction starts executing
func _init():
	completion_timing = CompletionSignalTiming.ON_START

func execute(context: ExecutionContext):
	# _start_execution() auto-detects this and emits the finished signal
	_start_execution(context)
	
	# Instruction logic...
	
	# No need to call _on_execution_completed() here because the signal was already sent
```

#### Use cases

**The ON_FINISH mode suits:**
- Instructions that need to wait for execution to complete
- Instructions with asynchronous operations
- Most standard instructions

**The ON_START mode suits:**
- Instructions that complete immediately
- Trigger-style instructions
- Operations that only need to start, without waiting for completion

#### Dynamically Setting the Completion Timing

```gdscript
@export var immediate_completion: bool = false:
	set(value):
		immediate_completion = value
		completion_timing = CompletionSignalTiming.ON_FINISH if not immediate_completion else CompletionSignalTiming.ON_START

func execute(context: ExecutionContext):
	_start_execution(context)
	
	if immediate_completion:
		# ON_START mode: the signal was already sent in _start_execution()
		_log_info("指令已触发，无需等待完成")
	else:
		# ON_FINISH mode: wait for execution to complete
		_perform_full_execution()
		_on_execution_completed()
```

### 3. Variable Binding Declaration (get_variable_modes)

Built-in instructions generally support the "direct value / variable" dual-track parameter mode (for user-side usage see the [Variable Binding Usage Guide](../guides/07-variable-binding-guide.md)). Custom instructions join the same system by declaring a `use_variable_for_xxx` boolean switch plus `get_variable_modes()`:

```gdscript
@export var use_variable_for_damage: bool = false:
    set(value):
        use_variable_for_damage = value
        notify_property_list_changed()

@export var damage_variable: String = ""      # 勾选后的变量来源
@export var damage_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

func get_variable_modes() -> Array[Dictionary]:
    var modes: Array[Dictionary] = []
    if use_variable_for_damage:
        modes.append({"name": "damage_variable", "mode": "read"})
    return modes
```

Pair this with dynamically switching the property shape in `_get_property_list()` based on the toggle (unchecked shows a direct-value input box; checked shows a variable name + scope dropdown), matching the built-in instruction behavior. Instructions that declare variable modes are collected into the preset AI context schema, so AI-generated presets can use the dual-track parameters correctly.

---

## Performance Optimization

### 1. Condition Check Optimization

```gdscript
# Use short-circuit logic to optimize condition checks
func _should_execute(context: ExecutionContext) -> bool:
	# Check lightweight conditions first
	if not context or not _enabled:
		return false
	
	# Then check heavyweight conditions
	if not _check_expensive_condition(context):
		return false
	
	return true
```

### 2. Resource Reuse

```gdscript
# Cache frequently used resources
var _cached_texture: Texture2D = null
var _cached_node: Node = null

func _get_resource():
	if not _cached_texture:
		_cached_texture = load("res://textures/icon.png")
	return _cached_texture
```

### 3. Batch Operations

```gdscript
# Process multiple objects in batches
func _process_multiple_objects(objects: Array[Node]) -> void:
	var valid_objects: Array[Node] = []
	
	# Filter first, then process
	for obj in objects:
		if _is_valid_object(obj):
			valid_objects.append(obj)
	
	# Perform the operation in batches
	for obj in valid_objects:
		_process_object(obj)
```

---

## Common Implementation Patterns

### 1. Synchronous Execution Pattern

Implementation pattern based on `PrintInstruction`:

```gdscript
@export var message: String = "":
	set(value):
		message = value
		_update_resource_name()

func execute(context: ExecutionContext):
	_start_execution(context)
	
	# Validate parameters
	if message.is_empty():
		set_error("消息不能为空", FuseError.ErrorType.VALIDATION_ERROR)
		finished.emit()
		return
	
	# Perform the synchronous operation
	print(message)
	if context:
		context.print_message(message)
	
	_on_execution_completed()

func _update_resource_name():
	resource_name = "Print: %s" % message
```

### 2. Asynchronous Execution Pattern

Implementation pattern based on `WaitInstruction`:

```gdscript
@export var wait_time: float = 1.0:
	set(value):
		wait_time = value
		_update_resource_name()

var _timer: SceneTreeTimer = null

func execute(context: ExecutionContext):
	_start_execution(context)
	
	# Validate parameters
	if wait_time <= 0:
		set_error("等待时间必须大于0", FuseError.ErrorType.VALIDATION_ERROR)
		finished.emit()
		return
	
	# Create the async operation
	var scene_tree = Engine.get_main_loop()
	if scene_tree:
		_timer = scene_tree.create_timer(wait_time)
		_timer.timeout.connect(_on_timer_timeout)
	else:
		set_error("无法获取场景树", FuseError.ErrorType.RUNTIME_ERROR)
		finished.emit()

func _on_timer_timeout():
	_timer = null
	_on_execution_completed()

func _cleanup_resources():
	super._cleanup_resources()
	if _timer:
		if _timer.timeout.is_connected(_on_timer_timeout):
			_timer.timeout.disconnect(_on_timer_timeout)
		_timer = null

func _update_resource_name():
	resource_name = "Wait: %.1f secs" % wait_time
```

### 3. State Maintenance Pattern

Implementation pattern based on `CountInstruction`:

```gdscript
@export var initial_count: int = 0:
	set(value):
		initial_count = value
		current_count = value
		_update_resource_name()

@export var increment: int = 1:
	set(value):
		increment = value
		_update_resource_name()

var current_count: int = 0

func execute(context: ExecutionContext):
	_start_execution(context)
	
	# Update the state
	current_count += increment
	
	# Output the result
	var message = "计数: %d" % current_count
	print(message)
	if context:
		context.print_message(message)
	
	_on_execution_completed()

func reset():
	super.reset()
	current_count = initial_count

func _update_resource_name():
	resource_name = "Count: %d→%d (+%d)" % [initial_count, current_count, increment]
```

### 4. Dynamic Resource Name Update Pattern

Implementation pattern based on `_update_resource_name()`, providing an intuitive editor experience:

```gdscript
# Resource name updates for multi-parameter instructions
@export var target_node: NodePath = "":
	set(value):
		target_node = value
		_update_resource_name()

@export var operation_type: String = "move":
	set(value):
		operation_type = value
		_update_resource_name()

@export var duration: float = 1.0:
	set(value):
		duration = value
		_update_resource_name()

func _update_resource_name():
	var parts = []
	
	# Base operation type
	match operation_type:
		"move":
			parts.append("移动")
		"rotate":
			parts.append("旋转")
		"scale":
			parts.append("缩放")
		_:
			parts.append("操作")
	
	# Target node information
	if not target_node.is_empty():
		parts.append(target_node.get_name(0))
	
	# Duration information
	if duration > 0:
		parts.append("(%.1fs)" % duration)
	
	# Combine the final name
	resource_name = " ".join(parts)

# Conditional resource name updates
@export var condition_type: String = "always":
	set(value):
		condition_type = value
		_update_resource_name()

@export var threshold: float = 0.0:
	set(value):
		threshold = value
		_update_resource_name()

func _update_resource_name():
	var base_name = "条件检查"
	
	match condition_type:
		"always":
			resource_name = base_name + ": 始终"
		"threshold":
			if threshold > 0:
				resource_name = "%s: 阈值%.1f" % [base_name, threshold]
			else:
				resource_name = base_name + ": 阈值未设置"
		"custom":
			resource_name = base_name + ": 自定义条件"
		_:
			resource_name = base_name + ": 未知条件"
```

### 5. Conditional Property Display Pattern

Implementation pattern based on `_validate_property()`, providing a dynamic editor UI:

```gdscript
# Base properties (always shown)
@export var target_variable: String = ""
@export var scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

# Control property (has a setter that triggers property updates)
@export var set_with_another_variable: bool = false:
	set(value):
		if set_with_another_variable != value:
			set_with_another_variable = value
			_update_resource_name()
			notify_property_list_changed()  # 触发属性验证

# Conditional properties (always exported but disabled based on conditions)
@export var from_variable: String = ""
@export var from_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
@export var new_value: int = 0

# Use _validate_property() for conditional display
func _validate_property(property: Dictionary) -> void:
	# When set_with_another_variable = false, disable the source variable properties
	if not set_with_another_variable:
		if property.name == "from_variable":
			property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
		elif property.name == "from_variable_scope":
			property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
	
	# When set_with_another_variable = true, disable the new value property
	if set_with_another_variable:
		if property.name == "new_value":
			property.usage = property.usage | PROPERTY_USAGE_READ_ONLY

# Update the resource name to reflect the current configuration
func _update_resource_name():
	if target_variable.is_empty():
		resource_name = "设置变量: 未指定"
		return
	
	var operation_desc = ""
	if set_with_another_variable:
		if from_variable.is_empty():
			operation_desc = "从[未指定]复制"
		else:
			operation_desc = "从[%s]复制" % from_variable
	else:
		operation_desc = "设置为%d" % new_value
	
	resource_name = "设置 %s.%s %s" % [scope, target_variable, operation_desc]
```

#### Advantages of Conditional Display

1. **Better user experience**: properties are greyed out instead of disappearing, so users can see all available options
2. **Better performance**: there is no need to rebuild the whole property list; only the properties that need validation are validated
3. **Clearer logic**: the condition checks for each property are independent, making debugging and maintenance easier
4. **Standard practice**: uses Godot's recommended property validation approach

#### Implementation Notes

1. **Export all properties with @export**: make sure the editor recognizes every property
2. **Add setters to key properties**: call `notify_property_list_changed()` inside the setter to trigger updates
3. **Implement _validate_property()**: dynamically set the property's `PROPERTY_USAGE_READ_ONLY` flag based on conditions
4. **Update the resource name**: update `resource_name` when properties change to reflect the current configuration

#### Commonly Used Property Usage Flags

```gdscript
# Disable a property (greyed out)
property.usage = property.usage | PROPERTY_USAGE_READ_ONLY

# Hide a property (completely invisible)
property.usage = property.usage | PROPERTY_USAGE_NO_EDITOR

# Show only in the editor
property.usage = property.usage | PROPERTY_USAGE_EDITOR

# Mark as a script variable
property.usage = property.usage | PROPERTY_USAGE_SCRIPT_VARIABLE
```

#### Complex Condition Example

```gdscript
func _validate_property(property: Dictionary) -> void:
	# Multi-condition checks
	var should_disable_advanced = not advanced_mode_enabled
	var should_hide_deprecated = not show_deprecated_features
	
	# Control properties based on multiple conditions
	match property.name:
		"advanced_property":
			if should_disable_advanced:
				property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
		"deprecated_property":
			if should_hide_deprecated:
				property.usage = property.usage | PROPERTY_USAGE_NO_EDITOR
		"conditional_property":
			if not condition_a or not condition_b:
				property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
```

---

## Complete Example

### Custom Instruction Example: MoveNodeInstruction

```gdscript
@tool
extends BaseInstruction
class_name MoveNodeInstruction

## Target node path
@export var target_node_path: NodePath:
	set(value):
		target_node_path = value
		_update_resource_name()

## Target position
@export var target_position: Vector2 = Vector2.ZERO:
	set(value):
		target_position = value
		_update_resource_name()

## Move duration (seconds)
@export var move_duration: float = 1.0:
	set(value):
		move_duration = value
		_update_resource_name()

## Whether to use relative movement
@export var relative_movement: bool = false:
	set(value):
		relative_movement = value
		_update_resource_name()

## Easing type
@export_enum("Linear", "EaseIn", "EaseOut", "EaseInOut") var ease_type: int = 0:
	set(value):
		ease_type = value
		_update_resource_name()

# Internal state
var _target_node: Node = null
var _tween: Tween = null
var _initial_position: Vector2

# Update the resource name
func _update_resource_name():
	var node_name = "未指定节点"
	if not target_node_path.is_empty():
		node_name = target_node_path.get_name(0)
	
	var move_type = relative_movement ? "相对移动" : "绝对移动"
	var ease_name = ["Linear", "EaseIn", "EaseOut", "EaseInOut"][ease_type]
	
	resource_name = "移动 %s %s (%.1fs, %s)" % [
		node_name,
		move_type,
		move_duration,
		ease_name
	]

# Set up instruction metadata (static method)
static func _get_instruction_metadata() -> InstructionMetadata:
	metadata = InstructionMetadata.new()
	metadata.name = "移动节点"
	metadata.description = "将节点移动到指定位置"
	metadata.category = "节点操作"
	metadata.version = "1.0"
	metadata.author = "Fuse System"
	metadata.keywords = ["移动", "节点", "动画", "位置"]
	return metadata

# Set up instruction metadata (instance method, usually empty)
func _setup_metadata():
	pass

# Execute the instruction
func execute(context: ExecutionContext):
	# Mandatory: this method must be called first
	_start_execution(context)
	
	# Set the timeout (animation operations may take a while)
	set_timeout(move_duration + 5.0)  # 动画时间 + 5秒缓冲
	
	# Validate parameters
	var errors = validate()
	if not errors.is_empty():
		set_error("参数验证失败: " + ", ".join(errors), FuseError.ErrorType.VALIDATION_ERROR)
		finished.emit()
		return
	
	# Get the target node
	_target_node = context.get_node(target_node_path) if context else null
	if not _target_node:
		set_error("无法找到目标节点: %s" % target_node_path, FuseError.ErrorType.RUNTIME_ERROR)
		finished.emit()
		return
	
	# Validate the node type
	if not _target_node is Node2D and not _target_node is Control:
		set_error("目标节点必须是 Node2D 或 Control 类型", FuseError.ErrorType.VALIDATION_ERROR)
		finished.emit()
		return
	
	# Record the initial position
	_initial_position = _target_node.position
	
	# Compute the target position
	var final_position = target_position
	if relative_movement:
		final_position = _initial_position + target_position
	
	# Log execution information
	var move_message = "开始移动 %s 从 %s 到 %s" % [_target_node.name, _initial_position, final_position]
	_log_info(move_message)
	if context:
		context.print_message(move_message)
	
	# Create the tween animation
	_create_move_tween(final_position)

# Create the move tween
func _create_move_tween(target_pos: Vector2):
	var scene_tree = Engine.get_main_loop()
	if not scene_tree:
		set_error("无法获取场景树", FuseError.ErrorType.RUNTIME_ERROR)
		finished.emit()
		return
	
	_tween = scene_tree.create_tween()
	_tween.set_parallel(false)
	
	# Set the easing type
	match ease_type:
		0: _tween.set_ease(Tween.EASE_IN_OUT)
		1: _tween.set_ease(Tween.EASE_IN)
		2: _tween.set_ease(Tween.EASE_OUT)
		3: _tween.set_ease(Tween.EASE_IN_OUT)
	
	# Set the transition type
	_tween.set_trans(Tween.TRANS_SINE)
	
	# Run the move animation
	_tween.tween_property(_target_node, "position", target_pos, move_duration)
	_tween.tween_callback(_on_move_completed)

# Move completion callback
func _on_move_completed():
	_log_info("节点移动完成: %s" % _target_node.name)
	_tween = null
	_on_execution_completed()

# Get the instruction description
func get_description() -> String:
	var move_type = relative_movement ? "相对移动" : "绝对移动"
	var node_name = target_node_path.get_name(0) if not target_node_path.is_empty() else "未指定节点"
	
	return "%s %s 到 %s，持续时间 %.1f 秒" % [
		move_type,
		node_name,
		str(target_position),
		move_duration
	]

# Validate instruction parameters
func validate() -> Array[String]:
	var errors = super.validate()
	
	if target_node_path.is_empty():
		errors.append("必须指定目标节点路径")
	
	if move_duration <= 0:
		errors.append("移动持续时间必须大于0")
	
	return errors

# Cancel instruction execution
func cancel():
	if _tween:
		_tween.kill()
		_tween = null
		_log_debug("移动动画已取消")
	
	super.cancel()

# Resource cleanup
func _cleanup_resources():
	super._cleanup_resources()
	
	if _tween:
		_tween.kill()
		_tween = null
	
	_target_node = null
	_log_debug("MoveNodeInstruction 资源清理完成")

# Reset the instruction state
func reset():
	super.reset()
	_target_node = null
	_tween = null
	_log_debug("MoveNodeInstruction 状态已重置")

# Unified logging methods
func _log_debug(message: String):
	FuseLogger.log_debug("MoveNodeInstruction", log_level, message)

func _log_info(message: String):
	FuseLogger.log_info("MoveNodeInstruction", log_level, message)

func _log_warning(message: String):
	FuseLogger.log_warning("MoveNodeInstruction", log_level, message)

func _log_error(message: String):
	FuseLogger.log_error("MoveNodeInstruction", log_level, message)
```

---

## Testing and Validation

### 1. Unit Test Pattern

```gdscript
# Test instruction initialization
func test_instruction_initialization():
	var instruction = MoveNodeInstruction.new()
	var context = ExecutionContext.new()
	
	# Test metadata setup
	assert(instruction.metadata.name == "移动节点")
	assert(instruction.metadata.category == "节点操作")
	
	# Test parameter settings
	instruction.target_node_path = "^/TestNode"
	instruction.target_position = Vector2(100, 100)
	instruction.move_duration = 2.0
	
	# Verify the resource name update
	assert("TestNode" in instruction.resource_name)
	assert("100.0" in instruction.resource_name)

# Test instruction execution
func test_instruction_execution():
	var instruction = MoveNodeInstruction.new()
	var context = create_test_context()
	
	# Set test parameters
	instruction.target_node_path = "^/TestNode"
	instruction.target_position = Vector2(50, 50)
	
	# Connect the finished signal
	var completed = false
	instruction.finished.connect(func(): completed = true)
	
	# Execute the instruction
	instruction.execute(context)
	
	# Verify the execution state
	assert(instruction.is_running())
	
	# Wait for completion (a proper waiting mechanism is needed in real tests)
	# await instruction.finished
	
	# Verify the completion state
	assert(completed)
	assert(instruction.is_completed())
```

### 2. Integration Test Pattern

```gdscript
# Test the instruction in a real scene
func test_instruction_in_scene():
	# Create a test scene
	var scene = PackedScene.new()
	var test_node = Node2D.new()
	test_node.name = "TestNode"
	
	# Create the execution context
	var context = ExecutionContext.new()
	context.add_node(test_node)
	
	# Create and execute the instruction
	var instruction = MoveNodeInstruction.new()
	instruction.target_node_path = "^/TestNode"
	instruction.target_position = Vector2(200, 200)
	
	# Execute and verify the result
	instruction.execute(context)
	
	# Verify the node position change
	assert(test_node.position.x == 200)
	assert(test_node.position.y == 200)
```

### 3. Performance Test

```gdscript
func test_instruction_performance():
	var instruction = MoveNodeInstruction.new()
	var context = create_test_context()
	var start_time = Time.get_ticks_msec()
	
	# Perform a large number of instruction operations
	for i in range(1000):
		instruction.target_position = Vector2(i, i)
		instruction._update_resource_name()
	
	var end_time = Time.get_ticks_msec()
	print("指令资源名称更新时间: %d ms" % (end_time - start_time))
```

---

## Summary

When creating custom Instructions, follow these key principles:

1. **Complete lifecycle management**: implement the `execute()` and `_cleanup_resources()` methods correctly
2. **Metadata management**: use the `_get_instruction_metadata()` static method to set up instruction information
3. **Execution state management**: understand and correctly use the ExecutionStatus enum
4. **Completion timing control**: choose the right CompletionSignalTiming for the instruction type
5. **Execution mode optimization**: use ExecutionMode.AUTO_DETECT to auto-detect the best execution mode
6. **Robust error handling**: use the unified error handling mechanism (including localized errors)
7. **Clear logging**: provide appropriate debug information (including localized logs)
8. **Performance optimization**: leverage the built-in localization class cache (about 70% faster)
9. **Timeout management**: set reasonable timeouts to prevent instructions from executing indefinitely
10. **State consistency**: keep the instruction state consistent across the lifecycle
11. **Resource cleanup**: release unneeded resources in a timely manner
12. **Parameter validation**: validate configuration parameters in `validate()`
13. **Intuitive resource names**: implement `_update_resource_name()` so the instruction shows clear information in the editor
14. **Async operation handling**: handle asynchronous operations and resource cleanup correctly
15. **Mandatory initialization call**: call `_start_execution(context)` first in `execute()`

By following these best practices, you can create high-quality, high-performance custom Instruction classes that give the Fuse Visual Programming system powerful and reliable instruction execution.

---
## Update Notes (2026-03)

- BaseInstruction now supports the `ExecutionMode` enum (AUTO_DETECT / FORCE_ASYNC / FORCE_SYNC)
- Added the `get_default_runtime_state()` method for the RuntimeInstance mode
- Added `set_error()` / `set_error_localized()` for unified error handling
- Added `set_timeout()` timeout management
- Metadata is defined through the `InstructionMetadata` class and the `_get_instruction_metadata()` static method

---

**Related docs:**

- [Custom Condition Creation Best Practices](custom_condition.md)
- [Instruction generation skill](../../../../agent_skills/fuse-instruction-generator/SKILL.md) — the final authority on instruction component specs (templates, naming rules, and validation gates); this guide details the architectural principles behind it
- [Variable Binding Usage Guide](../guides/07-variable-binding-guide.md) — user-side usage of the dual-track parameters
