> 🌐 [**中文版**](../../../zh_CN/system_docs/architecture/instruction_system_design.md) | English

# Instruction System Detailed Design

## Table of Contents
1. [Instruction System Overview](#1-instruction-system-overview)
2. [Core Instruction Types](#2-core-instruction-types)
3. [Instruction Execution Mechanism](#3-instruction-execution-mechanism)
4. [Instruction Extension Framework](#4-instruction-extension-framework)
5. [Built-in Instruction Implementations](#5-built-in-instruction-implementations)
6. [Instruction Debugging and Performance Optimization](#6-instruction-debugging-and-performance-optimization)

---

## 1. Instruction System Overview

### 1.1 Design Principles

The instruction system is the core execution unit of the entire visual programming system and follows these design principles:

- **Atomicity**: each instruction performs a single, well-defined operation
- **Asynchrony**: all instructions execute asynchronously via the Signal mechanism
- **Composability**: complex logic is built by combining simple instructions
- **Type safety**: GDScript's type system ensures safe execution
- **Extensibility**: a simple extension interface supports custom instructions

### 1.2 Instruction Classification System

```mermaid
graph TB
    BaseInstruction[BaseInstruction Base Class]
    
    subgraph "Control Flow Instructions"
        WaitInstruction[Wait Instruction]
        LoopInstruction[Loop Instruction]
        BranchInstruction[Branch Instruction]
        StopInstruction[Stop Instruction]
    end
    
    subgraph "Node Operation Instructions"
        MoveInstruction[Move Instruction]
        RotateInstruction[Rotate Instruction]
        ScaleInstruction[Scale Instruction]
        SetPropertyInstruction[Set Property Instruction]
        CallMethodInstruction[Call Method Instruction]
    end
    
    subgraph "Scene Management Instructions"
        LoadSceneInstruction[Load Scene Instruction]
        UnloadSceneInstruction[Unload Scene Instruction]
        InstantiateInstruction[Instantiate Instruction]
        QueueFreeInstruction[Queue Free Instruction]
    end
    
    subgraph "Audio Instructions"
        PlaySoundInstruction[Play Sound Instruction]
        PlayMusicInstruction[Play Music Instruction]
        StopAudioInstruction[Stop Audio Instruction]
        SetVolumeInstruction[Set Volume Instruction]
    end
    
    subgraph "Animation Instructions"
        PlayAnimationInstruction[Play Animation Instruction]
        StopAnimationInstruction[Stop Animation Instruction]
        SetAnimationSpeedInstruction[Set Animation Speed Instruction]
    end
    
    subgraph "Variable Instructions"
        SetVariableInstruction[Set Variable Instruction]
        GetVariableInstruction[Get Variable Instruction]
        IncrementVariableInstruction[Increment Variable Instruction]
        CompareVariableInstruction[Compare Variable Instruction]
    end
    
    subgraph "UI Instructions"
        ShowUIInstruction[Show UI Instruction]
        HideUIInstruction[Hide UI Instruction]
        UpdateUITextInstruction[Update UI Text Instruction]
        SetUIProgressInstruction[Set UI Progress Instruction]
    end
    
    BaseInstruction --> Control Flow Instructions
    BaseInstruction --> Node Operation Instructions
    BaseInstruction --> Scene Management Instructions
    BaseInstruction --> Audio Instructions
    BaseInstruction --> Animation Instructions
    BaseInstruction --> Variable Instructions
    BaseInstruction --> UI Instructions
```

---

## 2. Core Instruction Types

### 2.1 Control Flow Instructions

#### 2.1.1 Wait Instruction (WaitInstruction)

```gdscript
@tool
class_name WaitInstruction extends BaseInstruction
@icon("res://addons/visual_programming/icons/wait.svg")

@export_group("Wait Settings")
@export var duration: float = 1.0
@export var use_unscaled_time: bool = false

func execute(context: ExecutionContext):
    var timer: SceneTreeTimer
    if use_unscaled_time:
        timer = context.get_tree().create_timer(duration, false, true)
    else:
        timer = context.get_tree().create_timer(duration)
    
    timer.timeout.connect(finished.emit)
    context.print_message("Waiting for %s seconds" % duration)

func get_description() -> String:
    return "Wait %s seconds%s" % [duration, " (unscaled)" if use_unscaled_time else ""]

func validate() -> Array[String]:
    var errors: Array[String] = []
    if duration < 0:
        errors.append("Duration cannot be negative")
    return errors
```

#### 2.1.2 Loop Instruction (LoopInstruction)

```gdscript
@tool
class_name LoopInstruction extends BaseInstruction
@icon("res://addons/visual_programming/icons/loop.svg")

@export_group("Loop Settings")
@export var loop_count: int = 3
@export var loop_instructions: Array[BaseInstruction] = []
@export var break_on_condition: BaseCondition = null

var current_iteration: int = 0
var loop_runner: ActionRunner = null

func execute(context: ExecutionContext):
    if loop_count <= 0:
        finished.emit()
        return
    
    current_iteration = 0
    loop_runner = ActionRunner.new()
    loop_runner.instructions = loop_instructions
    
    _execute_loop_iteration(context)

func _execute_loop_iteration(context: ExecutionContext):
    # Check the loop condition
    if break_on_condition and break_on_condition.check(context):
        context.print_message("Loop break condition met, exiting loop")
        finished.emit()
        return
    
    # Check the iteration count
    if current_iteration >= loop_count:
        context.print_message("Loop completed after %s iterations" % current_iteration)
        finished.emit()
        return
    
    context.print_message("Loop iteration %s/%s" % [current_iteration + 1, loop_count])
    current_iteration += 1
    
    # Execute the loop body
    loop_runner.run(context)
    await loop_runner.action_completed
    
    # Continue with the next iteration
    _execute_loop_iteration(context)

func get_description() -> String:
    return "Loop %s times" % loop_count

func validate() -> Array[String]:
    var errors: Array[String] = []
    if loop_count < 1:
        errors.append("Loop count must be at least 1")
    if loop_instructions.is_empty():
        errors.append("Loop instructions cannot be empty")
    return errors
```

#### 2.1.3 Branch Instruction (BranchInstruction)

```gdscript
@tool
class_name BranchInstruction extends BaseInstruction
@icon("res://addons/visual_programming/icons/branch.svg")

@export_group("Branch Settings")
@export var condition: BaseCondition
@export var true_instructions: Array[BaseInstruction] = []
@export var false_instructions: Array[BaseInstruction] = []

var branch_runner: ActionRunner = null

func execute(context: ExecutionContext):
    var condition_result = false
    
    if condition:
        condition_result = condition.check(context)
        context.print_message("Branch condition result: %s" % condition_result)
    else:
        context.print_warning("Branch instruction has no condition, defaulting to false")
    
    var instructions_to_execute = true_instructions if condition_result else false_instructions
    
    if instructions_to_execute.is_empty():
        context.print_message("Branch has no instructions for %s path" % ("true" if condition_result else "false"))
        finished.emit()
        return
    
    branch_runner = ActionRunner.new()
    branch_runner.instructions = instructions_to_execute
    
    context.print_message("Executing %s branch with %s instructions" % [
        "true" if condition_result else "false",
        instructions_to_execute.size()
    ])
    
    branch_runner.run(context)
    await branch_runner.action_completed
    finished.emit()

func get_description() -> String:
    var true_count = true_instructions.size()
    var false_count = false_instructions.size()
    return "Branch: %s true, %s false" % [true_count, false_count]

func validate() -> Array[String]:
    var errors: Array[String] = []
    if not condition:
        errors.append("Branch instruction requires a condition")
    if true_instructions.is_empty() and false_instructions.is_empty():
        errors.append("Branch instruction must have at least one instruction in either branch")
    return errors
```

### 2.2 Node Operation Instructions

#### 2.2.1 Move Instruction (MoveInstruction)

```gdscript
@tool
class_name MoveInstruction extends BaseInstruction
@icon("res://addons/visual_programming/icons/move.svg")

@export_group("Target Settings")
@export var target_node_path: NodePath
@export_group("Movement Settings")
@export var target_position: Vector3
@export var duration: float = 1.0
@export var relative: bool = false
@export var use_local_coordinates: bool = false
@export_group("Tween Settings")
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT
@export var trans_type: Tween.TransitionType = Tween.TRANS_SINE

var tween: Tween = null

func execute(context: ExecutionContext):
    var target_node = _get_target_node(context)
    if not target_node:
        context.print_error("MoveInstruction: Target node not found at path: %s" % target_node_path)
        finished.emit()
        return
    
    var start_pos = target_node.global_position if not use_local_coordinates else target_node.position
    var end_pos = target_position
    
    if relative:
        end_pos = start_pos + target_position
    
    context.print_message("Moving node from %s to %s over %s seconds" % [start_pos, end_pos, duration])
    
    tween = context.get_tree().create_tween()
    tween.set_ease(ease_type)
    tween.set_trans(trans_type)
    
    var property = "global_position" if not use_local_coordinates else "position"
    tween.tween_property(target_node, property, end_pos, duration)
    tween.finished.connect(finished.emit)

func _get_target_node(context: ExecutionContext) -> Node:
    if target_node_path.is_empty():
        return context.target
    
    return context.get_node(target_node_path)

func get_description() -> String:
    var node_name = "Target" if target_node_path.is_empty() else target_node_path.get_name(0)
    var move_type = "relative" if relative else "absolute"
    var coord_type = "local" if use_local_coordinates else "global"
    return "Move %s %s to %s (%s)" % [node_name, move_type, target_position, coord_type]

func validate() -> Array[String]:
    var errors: Array[String] = []
    if duration < 0:
        errors.append("Duration cannot be negative")
    return errors
```

#### 2.2.2 Set Property Instruction (SetPropertyInstruction)

```gdscript
@tool
class_name SetPropertyInstruction extends BaseInstruction
@icon("res://addons/visual_programming/icons/set_property.svg")

@export_group("Target Settings")
@export var target_node_path: NodePath
@export_group("Property Settings")
@export var property_name: String = ""
@export_enum("bool", "int", "float", "String", "Vector2", "Vector3", "Color") var property_type: int = 0
@export var bool_value: bool = false
@export var int_value: int = 0
@export var float_value: float = 0.0
@export var string_value: String = ""
@export var vector2_value: Vector2 = Vector2.ZERO
@export var vector3_value: Vector3 = Vector3.ZERO
@export var color_value: Color = Color.WHITE
@export var use_variable: bool = false
@export var variable_name: String = ""

func execute(context: ExecutionContext):
    var target_node = _get_target_node(context)
    if not target_node:
        context.print_error("SetPropertyInstruction: Target node not found at path: %s" % target_node_path)
        finished.emit()
        return
    
    if property_name.is_empty():
        context.print_error("SetPropertyInstruction: Property name is empty")
        finished.emit()
        return
    
    var value = _get_property_value(context)
    
    # Use the set call to assign the property, supporting nested properties
    var success = target_node.set(property_name, value)
    
    if success:
        context.print_message("Set property '%s' on node '%s' to: %s" % [
            property_name, target_node.name, value
        ])
    else:
        context.print_error("Failed to set property '%s' on node '%s'" % [property_name, target_node.name])
    
    finished.emit()

func _get_target_node(context: ExecutionContext) -> Node:
    if target_node_path.is_empty():
        return context.target
    
    return context.get_node(target_node_path)

func _get_property_value(context: ExecutionContext) -> Variant:
    if use_variable:
        return context.get_variable(variable_name)
    
    match property_type:
        0: return bool_value
        1: return int_value
        2: return float_value
        3: return string_value
        4: return vector2_value
        5: return vector3_value
        6: return color_value
        _: return null

func get_description() -> String:
    var node_name = "Target" if target_node_path.is_empty() else target_node_path.get_name(0)
    var value_str = "variable: %s" % variable_name if use_variable else str(_get_property_value(null))
    return "Set %s.%s = %s" % [node_name, property_name, value_str]

func validate() -> Array[String]:
    var errors: Array[String] = []
    if property_name.is_empty():
        errors.append("Property name cannot be empty")
    if use_variable and variable_name.is_empty():
        errors.append("Variable name cannot be empty when using variable")
    return errors
```

### 2.3 Variable Instructions

#### 2.3.1 Set Variable Instruction (SetVariableInstruction)

```gdscript
@tool
class_name SetVariableInstruction extends BaseInstruction
@icon("res://addons/visual_programming/icons/set_variable.svg")

@export_group("Variable Settings")
@export var variable_name: String = ""
@export_enum("Local", "Trigger", "Global") var variable_scope: int = 0
@export_group("Value Settings")
@export_enum("Literal", "Variable", "Expression") var value_source: int = 0
@export_enum("bool", "int", "float", "String", "Vector2", "Vector3", "Color") var value_type: int = 0
@export var bool_value: bool = false
@export var int_value: int = 0
@export var float_value: float = 0.0
@export var string_value: String = ""
@export var vector2_value: Vector2 = Vector2.ZERO
@export var vector3_value: Vector3 = Vector3.ZERO
@export var color_value: Color = Color.WHITE
@export var source_variable_name: String = ""
@export var expression: String = ""

func execute(context: ExecutionContext):
    if variable_name.is_empty():
        context.print_error("SetVariableInstruction: Variable name is empty")
        finished.emit()
        return
    
    var value = _get_value(context)
    var scope_name = ["local", "trigger", "global"][variable_scope]
    
    match variable_scope:
        0: # Local
            context.local_variables[variable_name] = value
        1: # Trigger
            if context.trigger and context.trigger.local_variables:
                context.trigger.local_variables.set(variable_name, value)
        2: # Global
            if context.global_variables:
                context.global_variables.set(variable_name, value)
    
    context.print_message("Set %s variable '%s' to: %s" % [scope_name, variable_name, value])
    finished.emit()

func _get_value(context: ExecutionContext) -> Variant:
    match value_source:
        0: # Literal
            match value_type:
                0: return bool_value
                1: return int_value
                2: return float_value
                3: return string_value
                4: return vector2_value
                5: return vector3_value
                6: return color_value
        1: # Variable
            return context.get_variable(source_variable_name)
        2: # Expression
            return _evaluate_expression(context)
    return null

func _evaluate_expression(context: ExecutionContext) -> Variant:
    # Simple expression evaluation implementation
    # In a real project, a more powerful expression parsing library could be used
    var expr = expression
    var variables = context.local_variables.duplicate()
    
    # Replace variable references
    for var_name in variables.keys():
        expr = expr.replace("${%s}" % var_name, str(variables[var_name]))
    
    # Simple math expression evaluation
    var expression_parser = Expression.new()
    var parse_result = expression_parser.parse(expr)
    
    if parse_result != OK:
        context.print_error("Failed to parse expression: %s" % expression)
        return null
    
    var result = expression_parser.execute()
    if result is String:
        context.print_error("Expression execution error: %s" % result)
        return null
    
    return result

func get_description() -> String:
    var scope_name = ["local", "trigger", "global"][variable_scope]
    var value_desc = ""
    
    match value_source:
        0: # Literal
            value_desc = str(_get_value(null))
        1: # Variable
            value_desc = "variable: %s" % source_variable_name
        2: # Expression
            value_desc = "expression: %s" % expression
    
    return "Set %s variable '%s' = %s" % [scope_name, variable_name, value_desc]

func validate() -> Array[String]:
    var errors: Array[String] = []
    if variable_name.is_empty():
        errors.append("Variable name cannot be empty")
    if value_source == 1 and source_variable_name.is_empty():
        errors.append("Source variable name cannot be empty when using variable as value source")
    if value_source == 2 and expression.is_empty():
        errors.append("Expression cannot be empty when using expression as value source")
    return errors
```

---

## 3. Instruction Execution Mechanism

### 3.1 Asynchronous Execution Framework

```gdscript
@tool
class_name InstructionExecutor extends RefCounted

## Instruction execution status
enum ExecutionStatus {
    PENDING,
    RUNNING,
    COMPLETED,
    CANCELLED,
    ERROR
}

## Execution context
class InstructionContext:
    var instruction: BaseInstruction
    var execution_context: ExecutionContext
    var status: ExecutionStatus = ExecutionStatus.PENDING
    var start_time: float = 0
    var end_time: float = 0
    var error_message: String = ""

var active_instructions: Array[InstructionContext] = []
var max_concurrent_instructions: int = 50

## Execute a single instruction
func execute_instruction(instruction: BaseInstruction, context: ExecutionContext) -> String:
    var instruction_id = _generate_instruction_id()
    var instruction_context = InstructionContext.new()
    instruction_context.instruction = instruction
    instruction_context.execution_context = context
    instruction_context.status = ExecutionStatus.PENDING
    
    active_instructions.append(instruction_context)
    
    # Check the concurrency limit
    if _get_running_count() >= max_concurrent_instructions:
        await _wait_for_completion()
    
    _execute_instruction_context(instruction_context)
    return instruction_id

## Execute an instruction context
func _execute_instruction_context(instruction_context: InstructionContext):
    instruction_context.status = ExecutionStatus.RUNNING
    instruction_context.start_time = Time.get_ticks_msec()
    
    # Connect the completion signal
    instruction_context.instruction.finished.connect(
        _on_instruction_completed.bind(instruction_context)
    )
    
    # Execute the instruction
    instruction_context.instruction.execute(instruction_context.execution_context)

## Instruction completion callback
func _on_instruction_completed(instruction_context: InstructionContext):
    instruction_context.status = ExecutionStatus.COMPLETED
    instruction_context.end_time = Time.get_ticks_msec()
    
    var execution_time = instruction_context.end_time - instruction_context.start_time
    instruction_context.execution_context.print_message(
        "Instruction '%s' completed in %s ms" % [
            instruction_context.instruction.get_description(),
            execution_time
        ]
    )
    
    active_instructions.erase(instruction_context)

## Wait for instructions to complete
func _wait_for_completion():
    while _get_running_count() >= max_concurrent_instructions:
        await get_tree().process_frame

## Get the number of running instructions
func _get_running_count() -> int:
    var count = 0
    for context in active_instructions:
        if context.status == ExecutionStatus.RUNNING:
            count += 1
    return count

## Generate an instruction ID
func _generate_instruction_id() -> String:
    return "inst_%d_%d" % [Time.get_ticks_msec(), randi()]
```

### 3.2 Error Handling Mechanism

```gdscript
@tool
class_name InstructionErrorHandler extends RefCounted

## Error types
enum ErrorType {
    VALIDATION_ERROR,
    EXECUTION_ERROR,
    TIMEOUT_ERROR,
    CANCELLATION_ERROR
}

## Error information
class ErrorInfo:
    var error_type: ErrorType
    var instruction: BaseInstruction
    var context: ExecutionContext
    var error_message: String
    var timestamp: float

var error_history: Array[ErrorInfo] = []
var max_error_history: int = 100

## Handle an instruction error
func handle_error(
    error_type: ErrorType,
    instruction: BaseInstruction,
    context: ExecutionContext,
    error_message: String
):
    var error_info = ErrorInfo.new()
    error_info.error_type = error_type
    error_info.instruction = instruction
    error_info.context = context
    error_info.error_message = error_message
    error_info.timestamp = Time.get_ticks_msec()
    
    error_history.append(error_info)
    
    # Cap the error history size
    if error_history.size() > max_error_history:
        error_history.pop_front()
    
    # Log the error
    _log_error(error_info)
    
    # Apply a different handling strategy per error type
    match error_type:
        ErrorType.VALIDATION_ERROR:
            _handle_validation_error(error_info)
        ErrorType.EXECUTION_ERROR:
            _handle_execution_error(error_info)
        ErrorType.TIMEOUT_ERROR:
            _handle_timeout_error(error_info)
        ErrorType.CANCELLATION_ERROR:
            _handle_cancellation_error(error_info)

## Log the error
func _log_error(error_info: ErrorInfo):
    var error_type_name = ErrorType.keys()[error_info.error_type]
    context.print_error(
        "[%s] %s: %s" % [
            error_type_name,
            error_info.instruction.get_description(),
            error_info.error_message
        ]
    )

## Handle validation errors
func _handle_validation_error(error_info: ErrorInfo):
    # Instructions with validation errors should not be executed
    error_info.context.print_warning(
        "Skipping instruction due to validation errors: %s" % error_info.error_message
    )

## Handle execution errors
func _handle_execution_error(error_info: ErrorInfo):
    # Execution errors may require rollback or recovery
    error_info.context.print_error(
        "Instruction execution failed: %s" % error_info.error_message
    )

## Handle timeout errors
func _handle_timeout_error(error_info: ErrorInfo):
    # Timeout errors may require a forced stop
    error_info.context.print_error(
        "Instruction execution timed out: %s" % error_info.error_message
    )

## Handle cancellation errors
func _handle_cancellation_error(error_info: ErrorInfo):
    # Cancellations are normal and need no special handling
    error_info.context.print_message(
        "Instruction was cancelled: %s" % error_info.error_message
    )
```

---

## 4. Instruction Extension Framework

### 4.1 Instruction Registration System

```gdscript
@tool
class_name InstructionRegistry extends RefCounted

static var _registered_instructions: Dictionary = {}
static var _instruction_categories: Dictionary = {}
static var _instruction_metadata: Dictionary = {}

## Instruction metadata
class InstructionMetadata:
    var name: String
    var description: String
    var category: String
    var icon: Texture2D
    var version: String
    var author: String
    var dependencies: Array[String] = []

## Register an instruction type
static func register_instruction(
    instruction_name: String,
    instruction_script: Script,
    metadata: InstructionMetadata
) -> bool:
    if _registered_instructions.has(instruction_name):
        print_warning("Instruction '%s' is already registered" % instruction_name)
        return false
    
    # Validate the instruction script
    if not _validate_instruction_script(instruction_script):
        print_error("Invalid instruction script for '%s'" % instruction_name)
        return false
    
    _registered_instructions[instruction_name] = instruction_script
    _instruction_metadata[instruction_name] = metadata
    
    # Add to the category
    if not _instruction_categories.has(metadata.category):
        _instruction_categories[metadata.category] = []
    _instruction_categories[metadata.category].append(instruction_name)
    
    print("Registered instruction: %s" % instruction_name)
    return true

## Validate an instruction script
static func _validate_instruction_script(instruction_script: Script) -> bool:
    # Check whether the script inherits from BaseInstruction
    var base_class = instruction_script.get_base_script()
    while base_class:
        if base_class.get_global_name() == "BaseInstruction":
            return true
        base_class = base_class.get_base_script()
    return false

## Create an instruction instance
static func create_instruction(instruction_name: String) -> BaseInstruction:
    var instruction_script = _registered_instructions.get(instruction_name)
    if not instruction_script:
        print_error("Instruction '%s' not found" % instruction_name)
        return null
    
    var instruction = instruction_script.new()
    if not instruction is BaseInstruction:
        print_error("Failed to create instruction '%s'" % instruction_name)
        return null
    
    return instruction

## Get all registered instructions
static func get_registered_instructions() -> Dictionary:
    return _registered_instructions.duplicate()

## Get instruction categories
static func get_instruction_categories() -> Dictionary:
    return _instruction_categories.duplicate()

## Get instruction metadata
static func get_instruction_metadata(instruction_name: String) -> InstructionMetadata:
    return _instruction_metadata.get(instruction_name)

## Auto-discover and register instructions
static func auto_register_instructions():
    var instruction_dir = "res://addons/visual_programming/instructions/"
    _scan_directory_for_instructions(instruction_dir)

## Scan a directory for instructions
static func _scan_directory_for_instructions(directory_path: String):
    var dir = DirAccess.open(directory_path)
    if not dir:
        return
    
    dir.list_dir_begin()
    var file_name = dir.get_next()
    
    while file_name != "":
        if file_name.ends_with(".gd"):
            var script_path = directory_path + file_name
            _try_register_instruction_from_file(script_path)
        file_name = dir.get_next()
    
    dir.list_dir_end()

## Try to register an instruction from a file
static func _try_register_instruction_from_file(script_path: String):
    var script = load(script_path)
    if not script or not script is Script:
        return
    
    # Check for a custom registration method
    if script.has_method("auto_register"):
        script.auto_register()
```

### 4.2 Instruction Template System

```gdscript
@tool
class_name InstructionTemplate extends Resource

@export var template_name: String
@export var description: String
@export var category: String
@export var instruction_data: Dictionary = {}
@export var parameters: Array[TemplateParameter] = []

## Template parameter
class TemplateParameter:
    var name: String
    var type: String
    var default_value: Variant
    var description: String
    var required: bool = true

## Create an instruction from the template
func create_instruction(parameters: Dictionary = {}) -> BaseInstruction:
    var instruction_type = instruction_data.get("type")
    if instruction_type.is_empty():
        print_error("Template missing instruction type")
        return null
    
    var instruction = InstructionRegistry.create_instruction(instruction_type)
    if not instruction:
        return null
    
    # Apply template parameters
    _apply_template_parameters(instruction, parameters)
    
    # Apply template data
    _apply_template_data(instruction)
    
    return instruction

## Apply template parameters
func _apply_template_parameters(instruction: BaseInstruction, parameters: Dictionary):
    for param in self.parameters:
        var value = parameters.get(param.name, param.default_value)
        if param.required and value == null:
            print_error("Required parameter '%s' is missing" % param.name)
            continue
        
        # Set the property value via reflection
        if instruction.has_method("set"):
            instruction.set(param.name, value)

## Apply template data
func _apply_template_data(instruction: BaseInstruction):
    for property_name in instruction_data:
        if property_name == "type":
            continue
        
        var value = instruction_data[property_name]
        if instruction.has_method("set"):
            instruction.set(property_name, value)

## Validate template parameters
func validate_parameters(parameters: Dictionary) -> Array[String]:
    var errors: Array[String] = []
    
    for param in self.parameters:
        if param.required and not parameters.has(param.name):
            errors.append("Required parameter '%s' is missing" % param.name)
        
        if parameters.has(param.name):
            var value = parameters[param.name]
            if not _validate_parameter_type(value, param.type):
                errors.append("Parameter '%s' has invalid type" % param.name)
    
    return errors

## Validate a parameter type
func _validate_parameter_type(value: Variant, expected_type: String) -> bool:
    match expected_type:
        "bool":
            return value is bool
        "int":
            return value is int
        "float":
            return value is float
        "String":
            return value is String
        "Vector2":
            return value is Vector2
        "Vector3":
            return value is Vector3
        "Color":
            return value is Color
        "NodePath":
            return value is NodePath
        _:
            return true  # Unknown type, assume valid
```

---

## 5. Built-in Instruction Implementations

### 5.1 Scene Management Instructions

#### 5.1.1 Load Scene Instruction

```gdscript
@tool
class_name LoadSceneInstruction extends BaseInstruction
@icon("res://addons/visual_programming/icons/load_scene.svg")

@export_group("Scene Settings")
@export var scene_path: String = ""
@export var show_progress: bool = false
@export var progress_bar_path: NodePath
@export_group("Loading Options")
@export var use_background_loading: bool = false
@export var replace_current_scene: bool = true
@export var parent_node_path: NodePath

func execute(context: ExecutionContext):
    if scene_path.is_empty():
        context.print_error("LoadSceneInstruction: Scene path is empty")
        finished.emit()
        return
    
    if not ResourceLoader.exists(scene_path):
        context.print_error("LoadSceneInstruction: Scene file not found: %s" % scene_path)
        finished.emit()
        return
    
    context.print_message("Loading scene: %s" % scene_path)
    
    if use_background_loading:
        _load_scene_background(context)
    else:
        _load_scene_sync(context)

func _load_scene_sync(context: ExecutionContext):
    var packed_scene = load(scene_path) as PackedScene
    if not packed_scene:
        context.print_error("Failed to load packed scene: %s" % scene_path)
        finished.emit()
        return
    
    var scene_instance = packed_scene.instantiate()
    if not scene_instance:
        context.print_error("Failed to instantiate scene: %s" % scene_path)
        finished.emit()
        return
    
    if replace_current_scene:
        context.get_tree().change_scene_to_packed(packed_scene)
    else:
        var parent_node = _get_parent_node(context)
        if parent_node:
            parent_node.add_child(scene_instance)
            scene_instance.owner = context.get_tree().current_scene
        else:
            context.print_error("LoadSceneInstruction: No valid parent node found")
    
    context.print_message("Scene loaded successfully: %s" % scene_path)
    finished.emit()

func _load_scene_background(context: ExecutionContext):
    ResourceLoader.load_threaded_request(scene_path)
    _check_loading_progress(context)

func _check_loading_progress(context: ExecutionContext):
    var progress = []
    var status = ResourceLoader.load_threaded_get_status(scene_path, progress)
    
    if show_progress:
        _update_progress_bar(progress[0] if progress.size() > 0 else 0.0)
    
    match status:
        ResourceLoader.THREAD_LOAD_IN_PROGRESS:
            await context.get_tree().process_frame
            _check_loading_progress(context)
        ResourceLoader.THREAD_LOAD_LOADED:
            _on_background_load_completed(context)
        ResourceLoader.THREAD_LOAD_FAILED:
            context.print_error("Background loading failed: %s" % scene_path)
            finished.emit()

func _on_background_load_completed(context: ExecutionContext):
    var packed_scene = ResourceLoader.load_threaded_get(scene_path) as PackedScene
    if packed_scene:
        _load_scene_sync(context)
    else:
        context.print_error("Failed to get loaded scene: %s" % scene_path)
        finished.emit()

func _get_parent_node(context: ExecutionContext) -> Node:
    if parent_node_path.is_empty():
        return context.get_tree().current_scene
    
    return context.get_node(parent_node_path)

func _update_progress_bar(progress: float):
    if not progress_bar_path.is_empty():
        var progress_bar = get_node_or_null(progress_bar_path)
        if progress_bar and progress_bar.has_method("set_value"):
            progress_bar.set_value(progress * 100.0)

func get_description() -> String:
    var mode = "replace" if replace_current_scene else "add"
    return "Load scene '%s' (%s)" % [scene_path, mode]

func validate() -> Array[String]:
    var errors: Array[String] = []
    if scene_path.is_empty():
        errors.append("Scene path cannot be empty")
    elif not ResourceLoader.exists(scene_path):
        errors.append("Scene file not found: %s" % scene_path)
    return errors
```

### 5.2 Audio Instructions

#### 5.2.1 Play Sound Instruction

```gdscript
@tool
class_name PlaySoundInstruction extends BaseInstruction
@icon("res://addons/visual_programming/icons/play_sound.svg")

@export_group("Audio Settings")
@export var sound_resource: AudioStream
@export var audio_player_path: NodePath
@export_group("Playback Settings")
@export var volume_db: float = 0.0
@export var pitch_scale: float = 1.0
@export var bus_name: String = "Master"
@export var autoplay: bool = true
@export var loop: bool = false

var audio_player: AudioStreamPlayer = null

func execute(context: ExecutionContext):
    audio_player = _get_audio_player(context)
    if not audio_player:
        context.print_error("PlaySoundInstruction: No valid audio player found")
        finished.emit()
        return
    
    if not sound_resource:
        context.print_error("PlaySoundInstruction: No sound resource assigned")
        finished.emit()
        return
    
    # Configure the audio player
    audio_player.stream = sound_resource
    audio_player.volume_db = volume_db
    audio_player.pitch_scale = pitch_scale
    audio_player.bus = bus_name
    
    context.print_message("Playing sound: %s" % sound_resource.resource_path if sound_resource else "Unknown")
    
    if autoplay:
        if loop:
            audio_player.play()
            finished.emit()  # Looping playback completes immediately
        else:
            audio_player.play()
            audio_player.finished.connect(finished.emit)
    else:
        finished.emit()

func _get_audio_player(context: ExecutionContext) -> AudioStreamPlayer:
    # If an audio player path is specified, use that player
    if not audio_player_path.is_empty():
        var player = context.get_node(audio_player_path)
        if player is AudioStreamPlayer:
            return player
    
    # Try to find an audio player under the trigger node
    if context.trigger:
        var player = context.trigger.find_child("AudioStreamPlayer", true, false)
        if player is AudioStreamPlayer:
            return player
    
    # Try to find an audio player under the target node
    if context.target:
        var player = context.target.find_child("AudioStreamPlayer", true, false)
        if player is AudioStreamPlayer:
            return player
    
    # Create a temporary audio player
    var temp_player = AudioStreamPlayer.new()
    context.trigger.add_child(temp_player) if context.trigger else context.get_tree().current_scene.add_child(temp_player)
    temp_player.owner = context.get_tree().current_scene
    return temp_player

func get_description() -> String:
    var sound_name = "Unknown"
    if sound_resource:
        sound_name = sound_resource.resource_path.get_file().get_basename()
    
    var mode = "looped" if loop else "once"
    return "Play sound '%s' %s" % [sound_name, mode]

func validate() -> Array[String]:
    var errors: Array[String] = []
    if not sound_resource:
        errors.append("Sound resource is required")
    if pitch_scale <= 0:
        errors.append("Pitch scale must be greater than 0")
    return errors
```

---

## 6. Instruction Debugging and Performance Optimization

### 6.1 Debugging System

```gdscript
@tool
class_name InstructionDebugger extends RefCounted

## Debug information
class DebugInfo:
    var instruction: BaseInstruction
    var context: ExecutionContext
    var start_time: float
    var end_time: float
    var execution_time: float
    var memory_usage: int
    var variables_before: Dictionary
    var variables_after: Dictionary

var debug_history: Array[DebugInfo] = []
var is_debugging: bool = false
var max_debug_history: int = 1000

## Start debugging
func start_debugging():
    is_debugging = true
    debug_history.clear()
    print("Instruction debugging started")

## Stop debugging
func stop_debugging():
    is_debugging = false
    print("Instruction debugging stopped")

## Record an instruction execution
func record_instruction_execution(
    instruction: BaseInstruction,
    context: ExecutionContext,
    start_time: float,
    end_time: float
):
    if not is_debugging:
        return
    
    var debug_info = DebugInfo.new()
    debug_info.instruction = instruction
    debug_info.context = context
    debug_info.start_time = start_time
    debug_info.end_time = end_time
    debug_info.execution_time = end_time - start_time
    debug_info.memory_usage = _get_memory_usage()
    debug_info.variables_before = _get_variables_snapshot(context, "before")
    debug_info.variables_after = _get_variables_snapshot(context, "after")
    
    debug_history.append(debug_info)
    
    # Cap the debug history size
    if debug_history.size() > max_debug_history:
        debug_history.pop_front()
    
    _print_debug_info(debug_info)

## Get memory usage
func _get_memory_usage() -> int:
    return OS.get_static_memory_usage_by_type()[OS.MEMORY_TYPE_STATIC]

## Get a variables snapshot
func _get_variables_snapshot(context: ExecutionContext, phase: String) -> Dictionary:
    var snapshot = {}
    
    # Local variables
    for var_name in context.local_variables.keys():
        snapshot["local_%s_%s" % [var_name, phase]] = context.local_variables[var_name]
    
    # Trigger variables
    if context.trigger and context.trigger.local_variables:
        for var_name in context.trigger.local_variables.get_variable_names():
            snapshot["trigger_%s_%s" % [var_name, phase]] = context.trigger.local_variables.get(var_name)
    
    # Global variables
    if context.global_variables:
        for var_name in context.global_variables.get_variable_names():
            snapshot["global_%s_%s" % [var_name, phase]] = context.global_variables.get(var_name)
    
    return snapshot

## Print debug information
func _print_debug_info(debug_info: DebugInfo):
    print("=== DEBUG INFO ===")
    print("Instruction: %s" % debug_info.instruction.get_description())
    print("Execution Time: %.2f ms" % debug_info.execution_time)
    print("Memory Usage: %d bytes" % debug_info.memory_usage)
    print("Variables Changed: %d" % _count_changed_variables(debug_info))
    print("==================")

## Count changed variables
func _count_changed_variables(debug_info: DebugInfo) -> int:
    var changes = 0
    for key in debug_info.variables_before:
        if debug_info.variables_before.has(key) and debug_info.variables_after.has(key):
            if debug_info.variables_before[key] != debug_info.variables_after[key]:
                changes += 1
    return changes

## Generate a debug report
func generate_debug_report() -> String:
    var report = "INSTRUCTION DEBUG REPORT\n"
    report += "========================\n\n"
    
    var total_time = 0.0
    var total_instructions = debug_history.size()
    
    for debug_info in debug_history:
        total_time += debug_info.execution_time
        report += "Instruction: %s\n" % debug_info.instruction.get_description()
        report += "  Time: %.2f ms\n" % debug_info.execution_time
        report += "  Memory: %d bytes\n" % debug_info.memory_usage
        report += "\n"
    
    report += "SUMMARY:\n"
    report += "Total Instructions: %d\n" % total_instructions
    report += "Total Time: %.2f ms\n" % total_time
    report += "Average Time: %.2f ms\n" % (total_time / total_instructions if total_instructions > 0 else 0)
    
    return report
```

### 6.2 Performance Optimization

```gdscript
@tool
class_name InstructionOptimizer extends RefCounted

## Optimization suggestion
class OptimizationSuggestion:
    var instruction: BaseInstruction
    var suggestion_type: String
    var description: String
    var impact: String  # "low", "medium", "high"

## Analyze instruction performance
func analyze_performance(instructions: Array[BaseInstruction]) -> Array[OptimizationSuggestion]:
    var suggestions: Array[OptimizationSuggestion] = []
    
    for instruction in instructions:
        suggestions.append_array(_analyze_instruction(instruction))
    
    return suggestions

## Analyze a single instruction
func _analyze_instruction(instruction: BaseInstruction) -> Array[OptimizationSuggestion]:
    var suggestions: Array[OptimizationSuggestion] = []
    
    # Check wait instructions
    if instruction is WaitInstruction:
        var wait_instruction = instruction as WaitInstruction
        if wait_instruction.duration > 5.0:
            suggestions.append(_create_suggestion(
                instruction,
                "long_wait",
                "Consider breaking long waits into smaller chunks",
                "medium"
            ))
    
    # Check loop instructions
    elif instruction is LoopInstruction:
        var loop_instruction = instruction as LoopInstruction
        if loop_instruction.loop_count > 100:
            suggestions.append(_create_suggestion(
                instruction,
                "large_loop",
                "Large loops may impact performance",
                "high"
            ))
    
    # Check move instructions
    elif instruction is MoveInstruction:
        var move_instruction = instruction as MoveInstruction
        if move_instruction.duration < 0.1:
            suggestions.append(_create_suggestion(
                instruction,
                "instant_move",
                "Consider using instant position change for very short moves",
                "low"
            ))
    
    return suggestions

## Create an optimization suggestion
func _create_suggestion(
    instruction: BaseInstruction,
    suggestion_type: String,
    description: String,
    impact: String
) -> OptimizationSuggestion:
    var suggestion = OptimizationSuggestion.new()
    suggestion.instruction = instruction
    suggestion.suggestion_type = suggestion_type
    suggestion.description = description
    suggestion.impact = impact
    return suggestion

## Optimize an instruction sequence
func optimize_instructions(instructions: Array[BaseInstruction]) -> Array[BaseInstruction]:
    var optimized = instructions.duplicate()
    
    # Merge consecutive wait instructions
    optimized = _merge_consecutive_waits(optimized)
    
    # Remove empty instructions
    optimized = _remove_empty_instructions(optimized)
    
    # Optimize loop structures
    optimized = _optimize_loops(optimized)
    
    return optimized

## Merge consecutive wait instructions
func _merge_consecutive_waits(instructions: Array[BaseInstruction]) -> Array[BaseInstruction]:
    var optimized: Array[BaseInstruction] = []
    var total_wait_time = 0.0
    var use_unscaled_time = false
    
    for instruction in instructions:
        if instruction is WaitInstruction:
            var wait_instruction = instruction as WaitInstruction
            total_wait_time += wait_instruction.duration
            use_unscaled_time = use_unscaled_time or wait_instruction.use_unscaled_time
        else:
            # If wait time has accumulated, create a merged wait instruction
            if total_wait_time > 0:
                var merged_wait = WaitInstruction.new()
                merged_wait.duration = total_wait_time
                merged_wait.use_unscaled_time = use_unscaled_time
                optimized.append(merged_wait)
                total_wait_time = 0.0
                use_unscaled_time = false
            
            optimized.append(instruction)
    
    # Handle the trailing wait instruction
    if total_wait_time > 0:
        var merged_wait = WaitInstruction.new()
        merged_wait.duration = total_wait_time
        merged_wait.use_unscaled_time = use_unscaled_time
        optimized.append(merged_wait)
    
    return optimized

## Remove empty instructions
func _remove_empty_instructions(instructions: Array[BaseInstruction]) -> Array[BaseInstruction]:
    var optimized: Array[BaseInstruction] = []
    
    for instruction in instructions:
        if instruction:
            optimized.append(instruction)
    
    return optimized

## Optimize loop structures
func _optimize_loops(instructions: Array[BaseInstruction]) -> Array[BaseInstruction]:
    # More complex loop optimization logic could be implemented here
    # e.g. detecting loops that could be parallelized
    return instructions
```

---

## Summary

The instruction system is the core of the entire visual programming system. This design provides:

1. **A complete instruction classification system**: covering control flow, node operations, scene management, audio, animation, variables, UI, and more
2. **A powerful extension framework**: supporting registration, templating, and auto-discovery of custom instructions
3. **A robust execution mechanism**: based on asynchronous execution and thorough error handling
4. **Comprehensive debugging support**: detailed debug information and performance profiling
5. **Intelligent performance optimization**: automatic analysis and optimization of instruction sequences

This instruction system design stays simple and easy to use while providing powerful features and good extensibility, laying a solid foundation for the entire visual programming system.

---

## Architecture Update (2026-03)

### RuntimeInstructionInstance Architecture
- Instructions now support runtime instances, self-declaring their state via get_default_runtime_state()
- Pause/resume mechanism: on_runtime_pause() / on_runtime_resume()
- ExecutionMode enum: AUTO_DETECT / FORCE_ASYNC / FORCE_SYNC
- Smart sync detection: can_execute_sync() automatically determines whether an instruction can execute synchronously

### New Instruction Categories
- Array operations (18 instructions)
- Dictionary operations (16 instructions)
- Expression instructions (MathExpression, StringExpression)
- Breakpoint instruction (BreakpointInstruction)
- Scope variable instructions (GetScopeVariable, SetScopeVariable)

### Unified Infrastructure
- Unified error handling with FuseError
- Unified logging with FuseLogger