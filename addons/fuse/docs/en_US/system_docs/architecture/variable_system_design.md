> 🌐 [**中文版**](../../../zh_CN/system_docs/architecture/variable_system_design.md) | English

# Fuse Variable System Design Document

## Version Information

- **Current version:** 3.0
- **Last updated:** 2026-02-09
- **Godot version:** 4.6

## Overview

The Fuse variable system adopts a three-layer architecture, providing a flexible variable storage and access mechanism. The system accesses variables at different layers through the unified `VariableOperations` utility class, simplifying instruction development and improving code maintainability.

## Three-Layer Variable Architecture

### 1. LOCAL (Local Variables)

**Storage location:** `ExecutionContext.local_variables`

**Lifecycle:** During a single instruction execution

**Management:** Managed automatically by `ExecutionContext`

**Use cases:**
- Temporary data during instruction execution
- Intermediate computation results
- Single-use data

**Characteristics:**
- ✅ Fastest access speed
- ✅ Automatic garbage collection
- ❌ Cannot be shared across instructions
- ❌ Cannot be persisted

**Example:**
```gdscript
# Using a local variable in an instruction
func execute(context: ExecutionContext):
    # Save the computation result to a local variable
    VariableOperations.set_variable(context, "temp_value", BaseVariable.VariableScope.LOCAL, 42)

    # Read from the local variable
    var value = VariableOperations.get_variable(context, "temp_value", BaseVariable.VariableScope.LOCAL, 0)
```

---

### 2. SCOPE (Scope Variables)

**Storage location:** `ScopeVariableContainer.variables`

**Lifecycle:** Node lifecycle (enters/exits the scene tree with the node)

**Management:**
- Manager: `ScopeVariableManager` (singleton)
- Container: `ScopeVariableContainer` (node component)

**Use cases:**
- Scene-local shared data
- Node group configuration
- UI component state
- Regional game state

**Characteristics:**
- ✅ Supports scope chain inheritance
- ✅ Visual editor support
- ✅ Automatic cleanup when the node is destroyed
- ⚠️ Requires manually adding a `ScopeVariableContainer` node
- ⚠️ Requires a `ScopeVariableManager` instance

**Scope inheritance mode:**

```gdscript
enum InheritanceMode {
    NONE,           # No inheritance from the parent scope
    READ_ONLY,      # Read-only inheritance from the parent scope
    READ_WRITE      # Read-write inheritance from the parent scope
}
```

**Example:**
```gdscript
# Scene tree structure
# Main
#   ├── ScopeContainer (scope_id: "game_ui")
#   │   ├── PlayerHP
#   │   └── ScoreDisplay
#   └── EnemyContainer
#       └── ScopeContainer (scope_id: "enemy_data")

# Using scope variables in an instruction
func execute(context: ExecutionContext):
    # Get the nearest ScopeContainer
    var scope_container = ScopeVariableManager.get_instance().find_nearest_scope(context.target)

    if scope_container:
        # Read the scope variable
        var player_hp = VariableOperations.get_variable(
            context,
            "hp",
            BaseVariable.VariableScope.SCOPE,
            100
        )

        # Write the scope variable
        VariableOperations.set_variable(
            context,
            "hp",
            BaseVariable.VariableScope.SCOPE,
            player_hp - 10
        )
```

---

### 3. GLOBAL (Global Variables)

**Storage location:** `GlobalVariableResource` (Resource file)

**Lifecycle:** The entire game runtime

**Management:**
- Manager: `GlobalVariableManager` (singleton)
- Assistant: `GlobalVariableAssistant` (node component)

**Use cases:**
- Game configuration
- Player data
- Cross-scene shared data
- Game progress

**Characteristics:**
- ✅ Cross-scene access
- ✅ Supports persistence via resource files
- ✅ Visual editor support
- ⚠️ Requires manual memory management
- ⚠️ Overuse leads to code coupling

**Example:**
```gdscript
# Using global variables in an instruction
func execute(context: ExecutionContext):
    # Read the player score
    var score = VariableOperations.get_variable(
        context,
        "player_score",
        BaseVariable.VariableScope.GLOBAL,
        0
    )

    # Update the player score
    VariableOperations.set_variable(
        context,
        "player_score",
        BaseVariable.VariableScope.GLOBAL,
        score + 100
    )
```

---

## VariableScope Enum

```gdscript
# addons/fuse/core/base/base_variable.gd

enum VariableScope {
    LOCAL = 0,      ## Local variable
    SCOPE = 1,      ## Scope variable
    GLOBAL = 2      ## Global variable
}
```

## Core Utility Classes

### VariableOperations (Unified Variable Access Interface)

**File location:** `addons/fuse/core/utils/variable_operations.gd`

**Purpose:** Provides a unified variable access interface that automatically selects the correct storage layer based on the scope

**Main methods:**

#### 1. Get Variable

```gdscript
static func get_variable(
    context: ExecutionContext,
    variable_name: String,
    scope: BaseVariable.VariableScope,
    default_value: Variant = null
) -> Variant:
```

**Parameters:**
- `context`: execution context
- `variable_name`: variable name
- `scope`: variable scope (LOCAL/SCOPE/GLOBAL)
- `default_value`: default value (returned when the variable does not exist)

**Return value:** The variable value, or the default value if the variable does not exist

**Example:**
```gdscript
# Get a local variable (default value 0)
var local_value = VariableOperations.get_variable(
    context,
    "counter",
    BaseVariable.VariableScope.LOCAL,
    0
)

# Get the global player score (default value 0)
var score = VariableOperations.get_variable(
    context,
    "player_score",
    BaseVariable.VariableScope.GLOBAL,
    0
)
```

#### 2. Set Variable

```gdscript
static func set_variable(
    context: ExecutionContext,
    variable_name: String,
    scope: BaseVariable.VariableScope,
    value: Variant
) -> bool
```

**Parameters:**
- `context`: execution context
- `variable_name`: variable name
- `scope`: variable scope (LOCAL/SCOPE/GLOBAL)
- `value`: the value to set

**Return value:** Returns `true` on success, `false` on failure

**Example:**
```gdscript
# Set a local variable
VariableOperations.set_variable(
    context,
    "temp_result",
    BaseVariable.VariableScope.LOCAL,
    42
)

# Set a global variable
VariableOperations.set_variable(
    context,
    "player_level",
    BaseVariable.VariableScope.GLOBAL,
    5
)
```

#### 3. Check Variable Existence

```gdscript
static func has_variable(
    context: ExecutionContext,
    variable_name: String,
    scope: BaseVariable.VariableScope
) -> bool
```

**Parameters:**
- `context`: execution context
- `variable_name`: variable name
- `scope`: variable scope (LOCAL/SCOPE/GLOBAL)

**Return value:** Returns `true` if the variable exists, `false` otherwise

**Example:**
```gdscript
# Check whether a global variable exists
if VariableOperations.has_variable(context, "player_data", BaseVariable.VariableScope.GLOBAL):
    # The variable exists; run the logic
    pass
```

---

### VariableScopeUtils (Scope Utility Class)

**File location:** `addons/fuse/core/utils/variable_scope_utils.gd`

**Purpose:** Provides conversion between the scope enum and strings

**Main methods:**

#### 1. Enum to String

```gdscript
static func enum_to_string(scope: BaseVariable.VariableScope) -> String:
    match scope:
        BaseVariable.VariableScope.LOCAL:
            return "local"
        BaseVariable.VariableScope.SCOPE:
            return "scope"
        BaseVariable.VariableScope.GLOBAL:
            return "global"
        _:
            return "local"
```

#### 2. String to Enum

```gdscript
static func string_to_enum(scope_str: String) -> BaseVariable.VariableScope:
    match scope_str.to_lower():
        "local":
            return BaseVariable.VariableScope.LOCAL
        "scope":
            return BaseVariable.VariableScope.SCOPE
        "global":
            return BaseVariable.VariableScope.GLOBAL
        _:
            return BaseVariable.VariableScope.LOCAL
```

#### 3. Get Display Name

```gdscript
static func enum_to_display_name(scope: BaseVariable.VariableScope) -> String:
    match scope:
        BaseVariable.VariableScope.LOCAL:
            return "局部变量"
        BaseVariable.VariableScope.SCOPE:
            return "作用域变量"
        BaseVariable.VariableScope.GLOBAL:
            return "全局变量"
        _:
            return "未知"
```

#### 4. Scope Checks

```gdscript
static func is_local(scope: BaseVariable.VariableScope) -> bool
static func is_scope(scope: BaseVariable.VariableScope) -> bool
static func is_global(scope: BaseVariable.VariableScope) -> bool
```

**Example:**
```gdscript
# Used in an instruction description
func get_description() -> String:
    var scope_str = VariableScopeUtils.enum_to_string(save_to_scope).to_upper()
    return "保存到 %s [%s]" % [variable_name, scope_str]
```

---

## Using the Variable System in Instructions

### Basic Steps

#### 1. Add the Scope Property

```gdscript
# Variable name
var variable_name: String = ""

# Variable scope
@export var variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
    set(value):
        variable_scope = value
        _update_resource_name()
```

#### 2. Access Variables with VariableOperations

```gdscript
func execute(context: ExecutionContext):
    # Get the variable value
    var value = VariableOperations.get_variable(
        context,
        variable_name,
        variable_scope,
        null  # default value
    )

    # Set the variable value
    VariableOperations.set_variable(
        context,
        variable_name,
        variable_scope,
        new_value
    )
```

#### 3. Update the Property List

```gdscript
func _get_property_list()  -> Array[Dictionary]:
    var properties := []

    # ... other properties ...

    properties.append({
        name = "variable_scope",
        type = TYPE_INT,
        hint = PROPERTY_HINT_ENUM,
        hint_string = "Local,Scope,Global",
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    return properties
```

#### 4. Update the Display Methods

```gdscript
func _update_resource_name():
    var scope_str = VariableScopeUtils.enum_to_string(variable_scope).to_upper()
    resource_name = "%s [%s]" % [variable_name, scope_str]

func get_description() -> String:
    var scope_str = VariableScopeUtils.enum_to_string(variable_scope).to_upper()
    return "操作 %s [%s]" % [variable_name, scope_str]
```

#### 5. Validate the SCOPE Scope

```gdscript
func validate() -> Array[String]:
    var errors = super.validate()

    # Validate that the variable name is not empty
    if variable_name.is_empty():
        errors.append("变量名不能为空")

    # The SCOPE scope requires a ScopeVariableManager
    if variable_scope == BaseVariable.VariableScope.SCOPE:
        var manager = ScopeVariableManager.get_instance()
        if manager == null:
            errors.append("未找到 ScopeVariableManager 实例")

    return errors
```

---

## Practical Application Examples

### Example 1: MathOperation (Math Operation Instruction)

**File:** `addons/fuse/instructions/math/math_operation.gd`

**Before refactoring (old API):**
```gdscript
var is_global: bool = false

func execute(context: ExecutionContext):
    # Get the operands
    var operand_a = float(context.get_variable(operand_a_variable, is_global, 0.0))

    # Perform the operation
    var result = operand_a + operand_b

    # Save the result
    context.set_variable(save_to_variable, is_global, result)
```

**After refactoring (new API):**
```gdscript
@export var operand_a_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
@export var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

func execute(context: ExecutionContext):
    # Get the operands
    var operand_a = float(VariableOperations.get_variable(
        context,
        operand_a_variable,
        operand_a_scope,
        0.0
    ))

    # Perform the operation
    var result = operand_a + operand_b

    # Save the result
    VariableOperations.set_variable(
        context,
        save_to_variable,
        save_to_scope,
        result
    )
```

**Advantages:**
- ✅ Type safety (enum replaces boolean)
- ✅ Supports the three-layer variable system
- ✅ Unified error handling
- ✅ Clearer code structure

---

### Example 2: GetDeltaTime (Get Delta Time)

**File:** `addons/fuse/instructions/time/get_delta_time.gd`

**Before refactoring:**
```gdscript
var is_global: bool = false

func execute(context: ExecutionContext):
    var delta_time = Time.get_delta_time()

    if is_global:
        var global_vars = context.global_variables
        if global_vars != null:
            var variable = global_vars.get_variable(save_to_variable)
            if variable != null:
                variable.value = delta_time
            else:
                push_error("全局变量 '%s' 不存在" % save_to_variable)
    else:
        context.local_variables[save_to_variable] = delta_time
```

**After refactoring:**
```gdscript
@export var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

func execute(context: ExecutionContext):
    var delta_time = Time.get_delta_time()

    # Everything handled in a single line of code
    VariableOperations.set_variable(
        context,
        save_to_variable,
        save_to_scope,
        delta_time
    )
```

**Improvements:**
- Code reduced from 11 lines to 1 line
- Automatically handles all scopes
- Unified error handling mechanism

---

### Example 3: SetPosition (Set Node Position)

**File:** `addons/fuse/instructions/transform/set_position.gd`

**Scope property definition:**
```gdscript
@export var position_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
```

**Execution logic:**
```gdscript
func execute(context: ExecutionContext):
    # Get the position from a variable
    if use_variable:
        var var_value = VariableOperations.get_variable(
            context,
            position_variable,
            position_scope,
            null
        )

        # Check whether the variable exists
        if var_value == null and not VariableOperations.has_variable(
            context,
            position_variable,
            position_scope
        ):
            _log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": position_variable})
            return

        # Validate the type
        if var_value is Vector2 or var_value is Vector2i or var_value is Vector3 or var_value is Vector3i:
            target_pos = var_value
        else:
            _log_error_localized("FUSE_ERROR_VAR_TYPE_INVALID", {
                "variable": position_variable,
                "actual_type": type_string(typeof(var_value))
            })
            return
    else:
        target_pos = position

    # Apply the position transform
    if node is Node2D:
        node.global_position = Vector2(target_pos.x, target_pos.y)
    elif node is Node3D:
        node.global_position = target_pos
```

---

## Scope Selection Guide

### When to Use LOCAL (Local Variables)

✅ **Suitable use cases:**
- Temporary data for a single instruction execution
- Intermediate computation results
- Loop counters
- Temporary cached data

❌ **Unsuitable use cases:**
- Data that must be shared across instructions
- Data that must be persisted

**Example:**
```gdscript
# Temporary result of computing the distance between two points
var distance = point_a.distance_to(point_b)
VariableOperations.set_variable(context, "temp_distance", BaseVariable.VariableScope.LOCAL, distance)
```

---

### When to Use SCOPE (Scope Variables)

✅ **Suitable use cases:**
- Scene-local shared data
- UI component state
- Regional game state
- Node group configuration

❌ **Unsuitable use cases:**
- Global game configuration
- Temporary single-use data
- Cross-scene shared data

**Prerequisites:**
1. A `ScopeVariableContainer` node must be added to the scene
2. A `ScopeVariableManager` instance must exist

**Example:**
```gdscript
# Scene tree
# Main
#   └── GameUI (ScopeVariableContainer, scope_id: "ui")
#       ├── HPBar
#       └── ScoreDisplay

# Update HP in an HPBar instruction
VariableOperations.set_variable(context, "current_hp", BaseVariable.VariableScope.SCOPE, 80)

# Read HP in a ScoreDisplay instruction
var hp = VariableOperations.get_variable(context, "current_hp", BaseVariable.VariableScope.SCOPE, 100)
```

---

### When to Use GLOBAL (Global Variables)

✅ **Suitable use cases:**
- Game configuration (volume, graphics quality, etc.)
- Player data (level, experience, inventory)
- Game progress (current level, quest status)
- Cross-scene shared data

❌ **Unsuitable use cases:**
- Temporary data
- Data used within a single instruction
- Scene-local data

**Example:**
```gdscript
# Read the player level
var player_level = VariableOperations.get_variable(
    context,
    "player_level",
    BaseVariable.VariableScope.GLOBAL,
    1
)

# Update the player experience
VariableOperations.set_variable(
    context,
    "player_exp",
    BaseVariable.VariableScope.GLOBAL,
    current_exp + 100
)
```

---

## Migration Guide

### Migrating from the Old API to the New API

#### Case 1: Using `is_global: bool`

**Old code:**
```gdscript
var is_global: bool = false

func execute(context: ExecutionContext):
    if is_global:
        var global_vars = context.global_variables
        if global_vars != null:
            var variable = global_vars.get_variable(var_name)
            if variable != null:
                value = variable.value
    else:
        value = context.local_variables.get(var_name, default_value)
```

**New code:**
```gdscript
@export var var_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

func execute(context: ExecutionContext):
    value = VariableOperations.get_variable(context, var_name, var_scope, default_value)
```

#### Case 2: Using `variable_scope: int`

**Old code:**
```gdscript
var variable_scope: int = 0  # 0=LOCAL, 1=GLOBAL

func execute(context: ExecutionContext):
    match variable_scope:
        0:
            value = context.local_variables.get(var_name, default_value)
        1:
            var global_vars = context.global_variables
            if global_vars != null:
                var variable = global_vars.get_variable(var_name)
                if variable != null:
                    value = variable.value
```

**New code:**
```gdscript
@export var var_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

func execute(context: ExecutionContext):
    value = VariableOperations.get_variable(context, var_name, var_scope, default_value)
```

#### Case 3: Existing Enum with Manual Logic

**Old code:**
```gdscript
var variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

func _get_variable_value(context: ExecutionContext, name: String) -> Variant:
    match variable_scope:
        BaseVariable.VariableScope.LOCAL:
            return context.local_variables.get(name, null)
        BaseVariable.VariableScope.SCOPE:
            var manager = ScopeVariableManager.get_instance()
            if manager:
                var container = manager.find_nearest_scope(context.target)
                if container:
                    return container.get_variable(name, null)
            return null
        BaseVariable.VariableScope.GLOBAL:
            var manager = GlobalVariableManager.get_instance()
            if manager:
                var variable = manager.get_variable(name)
                if variable:
                    return variable.value
            return null
    return null
```

**New code:**
```gdscript
var variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

func _get_variable_value(context: ExecutionContext, name: String) -> Variant:
    return VariableOperations.get_variable(context, name, variable_scope, null)
```

---

## Best Practices

### 1. Prefer LOCAL Variables

**Rationale:**
- Fastest access speed
- Automatic garbage collection
- Avoids polluting global state

**Example:**
```gdscript
# ✅ Recommended: use a LOCAL variable
var temp_result = calculate_something()
VariableOperations.set_variable(context, "temp", BaseVariable.VariableScope.LOCAL, temp_result)

# ❌ Avoid: unnecessary use of a GLOBAL variable
VariableOperations.set_variable(context, "temp", BaseVariable.VariableScope.GLOBAL, temp_result)
```

---

### 2. Use SCOPE Variables to Replace Some GLOBAL Variables

**Rationale:**
- Better encapsulation
- Automatic cleanup (destroyed with the node)
- Supports scope chain inheritance

**Example:**
```gdscript
# ❌ Not recommended: global variables for UI data
VariableOperations.set_variable(context, "ui_hp", BaseVariable.VariableScope.GLOBAL, 100)

# ✅ Recommended: scope variables for UI data
# Add a ScopeVariableContainer to the UI root node
VariableOperations.set_variable(context, "hp", BaseVariable.VariableScope.SCOPE, 100)
```

---

### 3. Use Clear Prefixes for Variables

**Recommendations:**
- LOCAL variables: the `temp_` prefix
- SCOPE variables: grouped by function (e.g. `ui_`, `player_`, `enemy_`)
- GLOBAL variables: descriptive names (e.g. `player_level`, `game_difficulty`)

**Example:**
```gdscript
# LOCAL variables
"temp_distance"
"temp_index"
"temp_result"

# SCOPE variables
"ui_hp"
"ui_score"
"player_current_state"
"enemy_spawn_count"

# GLOBAL variables
"player_level"
"game_difficulty"
"audio_master_volume"
"current_scene_name"
```

---

### 4. Validate the Prerequisites for the SCOPE Scope

**Code template:**
```gdscript
func validate() -> Array[String]:
    var errors = super.validate()

    # Validate the variable name
    if variable_name.is_empty():
        errors.append("变量名不能为空")

    # The SCOPE scope requires a ScopeVariableManager
    if variable_scope == BaseVariable.VariableScope.SCOPE:
        var manager = ScopeVariableManager.get_instance()
        if manager == null:
            errors.append("未找到 ScopeVariableManager 实例")

    return errors
```

---

### 5. Use has_variable to Check Variable Existence

**Scenario:** Distinguishing "variable does not exist" from "variable value is null"

**Example:**
```gdscript
var value = VariableOperations.get_variable(
    context,
    "my_variable",
    BaseVariable.VariableScope.GLOBAL,
    null
)

# Check whether the variable really exists
if not VariableOperations.has_variable(context, "my_variable", BaseVariable.VariableScope.GLOBAL):
    _log_error("变量 '%s' 不存在" % "my_variable")
    return

# Here a null value is valid (the variable does exist, but its value is null)
```

---

### 6. Use VariableScopeUtils for a Consistent Display Format

**Recommended:**
```gdscript
func _update_resource_name():
    var scope_str = VariableScopeUtils.enum_to_string(save_to_scope).to_upper()
    resource_name = "Set %s → %s [%s]" % [target_property, variable_name, scope_str]

func get_description() -> String:
    var scope_str = VariableScopeUtils.enum_to_string(save_to_scope).to_upper()
    return "设置 %s = %s [%s]" % [target_property, value, scope_str]
```

---

## ScopeSource Architecture Design

### What Is ScopeSource?

**ScopeSource** is a helper enum used, when the SCOPE scope is selected, to **specify which SCOPE container to use**. It is not a replacement for the variable scope, but a supplementary configuration for the SCOPE scope.

**Core principle:**

```
Layer 1: Choose the variable scope (LOCAL/SCOPE/GLOBAL)
    ↓
Layer 2: If SCOPE is chosen, choose which SCOPE container to use (NEAREST/CUSTOM_ID/TRIGGER_SCOPE/TARGET_NODE)
```

### ScopeSource Enum Definition

```gdscript
# Defined as a local enum in every component that needs the SCOPE scope
enum ScopeSource {
    NEAREST,        ## Nearest scope container (default)
    CUSTOM_ID,      ## Specified scope_id
    TRIGGER_SCOPE,  ## Scope on the Trigger node
    TARGET_NODE     ## Scope on the Target node
}
```

### Correct Architecture Patterns

#### Standard Single-Scope Write Pattern

```gdscript
## Step 1: Add the VariableScope enum (three-layer variable system)
@export var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
    set(value):
        save_to_scope = value
        _update_resource_name()
        notify_property_list_changed()

## Step 2: Add ScopeSource (only used when save_to_scope == SCOPE)
var scope_source: ScopeSource = ScopeSource.NEAREST:
    set(value):
        scope_source = value
        _update_resource_name()
        notify_property_list_changed()

var custom_scope_id: String = ""
var target_node_path: NodePath = NodePath("")

## Step 3: Property list control (conditional ScopeSource display)
func _get_property_list()  -> Array[Dictionary]:
    var properties := []

    # Always show save_to_scope
    properties.append({
        name = "save_to_scope",
        type = TYPE_INT,
        hint = PROPERTY_HINT_ENUM,
        hint_string = "Local,Scope,Global"
    })

    # Only show ScopeSource when save_to_scope == SCOPE
    if save_to_scope == BaseVariable.VariableScope.SCOPE:
        properties.append({
            name = "scope_source",
            type = TYPE_INT,
            hint = PROPERTY_HINT_ENUM,
            hint_string = "Nearest,Custom ID,Trigger Scope,Target Node"
        })

        # Add extra properties based on scope_source
        if scope_source == ScopeSource.CUSTOM_ID:
            properties.append({ name = "custom_scope_id", ... })
        elif scope_source == ScopeSource.TARGET_NODE:
            properties.append({ name = "target_node_path", ... })

    return properties

## Step 4: Execution logic (branch by scope type)
func execute(context: ExecutionContext):
    var value_to_save = ... # the value to save

    match save_to_scope:
        BaseVariable.VariableScope.LOCAL:
            VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.LOCAL, value_to_save)

        BaseVariable.VariableScope.SCOPE:
            if scope_source == ScopeSource.NEAREST:
                VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.SCOPE, value_to_save)
            else:
                var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
                var scope_container = VariableScopeUtils.get_scope_container_by_source(
                    context, utils_scope_source, custom_scope_id, target_node_path
                )
                scope_container.set_variable(save_to_variable, value_to_save)

        BaseVariable.VariableScope.GLOBAL:
            VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.GLOBAL, value_to_save)

## Step 5: Property validation (conditional ScopeSource property visibility)
func _validate_property(property: Dictionary) -> void:
    if save_to_scope == BaseVariable.VariableScope.SCOPE:
        VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
    else:
        # Hide ScopeSource-related properties for non-SCOPE scopes
        if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
            property.usage = PROPERTY_USAGE_NO_EDITOR

## Step 6: Parameter validation (validate ScopeSource only for SCOPE)
func validate() -> Array[String]:
    var errors = super.validate()

    # Basic validation
    if save_to_variable.is_empty():
        errors.append(...)

    # Validate ScopeSource parameters only for the SCOPE scope
    if save_to_scope == BaseVariable.VariableScope.SCOPE:
        var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
        errors.append_array(VariableScopeUtils.validate_scope_source_params(
            utils_scope_source, custom_scope_id, target_node_path
        ))

    return errors
```

#### Dual-Scope Pattern (SetVariable Example)

```gdscript
# Target variable scope (write)
@export var target_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
var scope_source: ScopeSource = ScopeSource.NEAREST  # only used when target_variable_scope == SCOPE

# Source variable scope (read)
@export var from_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
var from_scope_source: ScopeSource = ScopeSource.NEAREST  # only used when from_variable_scope == SCOPE

# Property list control
func _get_property_list()  -> Array[Dictionary]:
    var properties := []

    # Target scope configuration
    properties.append({ name = "target_variable_scope", ... })
    if target_variable_scope == BaseVariable.VariableScope.SCOPE:
        properties.append({ name = "scope_source", ... })
        # Add extra properties based on scope_source

    # Source scope configuration
    if set_with_another_variable:
        properties.append({ name = "from_variable_scope", ... })
        if from_variable_scope == BaseVariable.VariableScope.SCOPE:
            properties.append({ name = "from_scope_source", ... })
            # Add extra properties based on from_scope_source

    return properties
```

### Common Architecture Mistakes

#### ❌ Mistake 1: Removing VariableScope and Using Only ScopeSource

**Incorrect code:**
```gdscript
# ❌ Wrong: no VariableScope, only ScopeSource
var scope_source: ScopeSource = ScopeSource.NEAREST

func execute(context: ExecutionContext):
    # Cannot choose LOCAL or GLOBAL; only SCOPE is available
    if scope_source == ScopeSource.NEAREST:
        VariableOperations.set_variable(context, var_name, BaseVariable.VariableScope.SCOPE, value)
```

**Problems:**
- Users cannot set LOCAL or GLOBAL variables
- All variables are forced to use the SCOPE scope
- ScopeSource is abused; it should only be shown when the SCOPE scope is selected

**Correct approach:**
```gdscript
# ✅ Correct: keep VariableScope, conditionalize ScopeSource
@export var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
var scope_source: ScopeSource = ScopeSource.NEAREST  # only used when save_to_scope == SCOPE

func execute(context: ExecutionContext):
    match save_to_scope:
        BaseVariable.VariableScope.LOCAL:
            VariableOperations.set_variable(context, var_name, BaseVariable.VariableScope.LOCAL, value)
        BaseVariable.VariableScope.SCOPE:
            if scope_source == ScopeSource.NEAREST:
                VariableOperations.set_variable(context, var_name, BaseVariable.VariableScope.SCOPE, value)
        BaseVariable.VariableScope.GLOBAL:
            VariableOperations.set_variable(context, var_name, BaseVariable.VariableScope.GLOBAL, value)
```

#### ❌ Mistake 2: ScopeSource Properties Always Displayed

**Incorrect code:**
```gdscript
# ❌ Wrong: ScopeSource-related properties always displayed
func _get_property_list()  -> Array[Dictionary]:
    var properties := []

    properties.append({ name = "save_to_scope", ... })
    properties.append({ name = "scope_source", ... })  # always displayed
    properties.append({ name = "custom_scope_id", ... })  # always displayed

    return properties
```

**Problems:**
- When the user selects LOCAL or GLOBAL, the ScopeSource options are meaningless but still shown
- The UI is confusing; users do not know when these options take effect

**Correct approach:**
```gdscript
# ✅ Correct: conditional ScopeSource display
func _get_property_list() -> Array[Dictionary]:
    var properties := []

    properties.append({ name = "save_to_scope", ... })

    # Only show when save_to_scope == SCOPE
    if save_to_scope == BaseVariable.VariableScope.SCOPE:
        properties.append({ name = "scope_source", ... })
        if scope_source == ScopeSource.CUSTOM_ID:
            properties.append({ name = "custom_scope_id", ... })

    return properties
```

#### ❌ Mistake 3: Property Validation Not Conditionalized

**Incorrect code:**
```gdscript
# ❌ Wrong: ScopeSource properties always validated
func _validate_property(property: Dictionary) -> void:
    VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
```

**Problems:**
- ScopeSource properties are validated even when LOCAL or GLOBAL is selected
- May produce unnecessary error messages

**Correct approach:**
```gdscript
# ✅ Correct: conditional validation
func _validate_property(property: Dictionary) -> void:
    if save_to_scope == BaseVariable.VariableScope.SCOPE:
        VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
    else:
        # Hide ScopeSource-related properties for non-SCOPE scopes
        if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
            property.usage = PROPERTY_USAGE_NO_EDITOR
```

### Relationship Between ScopeSource and VariableScope

| Concept | VariableScope | ScopeSource |
|------|--------------|-------------|
| **Role** | Selects the variable storage layer | Specifies which SCOPE container to use |
| **Layer** | First-layer choice | Second-layer choice (only when SCOPE) |
| **Required** | Required (all components) | Optional (only needed when SCOPE) |
| **Default** | LOCAL | NEAREST |
| **Display condition** | Always displayed | Only displayed when VariableScope == SCOPE |
| **Enum definition** | BaseVariable.VariableScope | Defined locally in each component |

### Utility Methods

VariableScopeUtils provides ScopeSource-related utility methods:

```gdscript
# Validate ScopeSource property visibility
static func validate_scope_source_property(
    property: Dictionary,
    scope_source: ScopeSource
)

# Validate ScopeSource parameters
static func validate_scope_source_params(
    scope_source: ScopeSource,
    custom_scope_id: String,
    target_node_path: NodePath
) -> Array[String]

# Get the ScopeSource string representation
static func get_scope_source_string(
    scope_source: ScopeSource,
    custom_scope_id: String,
    target_node_path: NodePath
) -> String

# Get the container by ScopeSource
static func get_scope_container_by_source(
    context: ExecutionContext,
    scope_source: ScopeSource,
    custom_scope_id: String,
    target_node_path: NodePath
) -> ScopeVariableContainer
```

### Reference Implementation

**Fully correct implementation:** `addons/fuse/instructions/variables/create_variable.gd`

**Fixed components:**
1. `addons/fuse/instructions/math/random_number.gd`
2. `addons/fuse/instructions/math/clamp_value.gd`
3. `addons/fuse/instructions/math/math_operation.gd`
4. `addons/fuse/instructions/math/lerp.gd`
5. `addons/fuse/instructions/math/vector_operation.gd`
6. `addons/fuse/instructions/variables/set_variable.gd`
7. `addons/fuse/instructions/scene/get_scene_path.gd`

### Fix Documentation

Detailed fix guides and progress reports (historical documents, archived):
- `archive/archive/development/scope_source_fix_progress.md`
- `archive/archive/development/remaining_fixes_guide.md`
- `archive/archive/development/scope_source_todos.md`

---

## FAQ

### Q1: When Should SCOPE Variables Be Used?

**A:** When you need to:
1. Share data within a region of the scene (e.g. a UI container, an enemy spawn area)
2. Bind the data lifecycle to scene nodes
3. Support scope chain inheritance (child scopes can access parent scopes)

**Not for:**
- Global game configuration (use GLOBAL instead)
- Temporary data of a single instruction (use LOCAL instead)

---

### Q2: What to Do When a SCOPE Variable Is null and Causes an Error?

**A:** Check the following:
1. Whether a `ScopeVariableContainer` node has been added to the scene
2. Whether `scope_id` has been set
3. Whether a `ScopeVariableManager` instance exists
4. Whether the node is in the scene tree

**Validation code:**
```gdscript
func validate() -> Array[String]:
    var errors = super.validate()

    if value_scope == BaseVariable.VariableScope.SCOPE:
        var manager = ScopeVariableManager.get_instance()
        if manager == null:
            errors.append("未找到 ScopeVariableManager 实例")

    return errors
```

---

### Q3: How Long Is the Lifecycle of LOCAL Variables?

**A:** LOCAL variables are stored in `ExecutionContext.local_variables` and share the lifecycle of the execution context:
- Created when the event triggers
- Destroyed after the event finishes executing
- Cannot be shared across events

**To share data across instructions, use SCOPE or GLOBAL variables.**

---

### Q4: How to Debug Variable Values in the Editor?

**A:**
1. **LOCAL variables:** Add a `PrintVariableValue` instruction
2. **SCOPE variables:** Select the `ScopeVariableContainer` node and inspect the `variables` dictionary in the Inspector
3. **GLOBAL variables:** Select the `GlobalVariableAssistant` node and check `current_resource`

---

### Q5: Does Variable Scope Affect Performance?

**A:** Performance ranking (fastest to slowest):
1. **LOCAL** - Direct dictionary access, fastest
2. **SCOPE** - Requires looking up the container node, slightly slower
3. **GLOBAL** - Requires access through the manager, relatively slower

**Recommendation:** Prefer LOCAL variables unless you really need to share data.

### Q6: What Is the Difference Between ScopeSource and VariableScope?

**A:** These are two concepts at different layers:

| Layer | Concept | Role | Example |
|------|------|------|------|
| **Layer 1** | VariableScope | Selects the variable storage layer | LOCAL, SCOPE, GLOBAL |
| **Layer 2** | ScopeSource | Specifies which SCOPE container to use | NEAREST, CUSTOM_ID, TRIGGER_SCOPE, TARGET_NODE |

**Analogy:**
- VariableScope is like "choosing a city" (Beijing, Shanghai, Shenzhen)
- ScopeSource is like "choosing a specific district" (only after choosing a city do you choose which district of that city)

**Example:**
```gdscript
# Layer 1: choose the SCOPE scope
@export var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.SCOPE

# Layer 2: if SCOPE is chosen, choose which container to use
var scope_source: ScopeSource = ScopeSource.NEAREST
```

---

### Q7: Why Is ScopeSource Needed? Can't NEAREST Be Used Directly?

**A:** ScopeSource provides flexibility, letting users precisely specify which scope container to use:

**NEAREST (default):** Uses the nearest ScopeVariableContainer
- **Use case:** Most situations
- **Pros:** Simple and convenient
- **Cons:** May not be the expected container

**CUSTOM_ID:** Uses the container with the specified scope_id
- **Use case:** You know exactly which container to use
- **Pros:** Precise control
- **Cons:** Requires manually configuring scope_id

**TRIGGER_SCOPE:** Uses the container on the Trigger node
- **Use case:** Variables related to the event trigger
- **Pros:** Tightly integrated with the event system
- **Cons:** Requires the Trigger node to have a ScopeVariableContainer

**TARGET_NODE:** Uses the container on the target node
- **Use case:** When you need to operate on the target object's variables
- **Pros:** Flexible specification
- **Cons:** Requires manually configuring the node path

**Example scenario:**
```
Scene tree:
├── GameUI (ScopeVariableContainer, scope_id: "ui")
├── Player (ScopeVariableContainer, scope_id: "player")
└── Enemy (ScopeVariableContainer, scope_id: "enemy")
    └── EnemyAI
        └── Trigger (trigger)
            └── Instruction (needs to read player HP)
```

Reading player HP in EnemyAI's instruction:
- **NEAREST:** would read Enemy's scope (wrong)
- **CUSTOM_ID:** specify scope_id="player" (correct)
- **TARGET_NODE:** specify the node path pointing to Player (correct)

---

### Q8: How to Tell Whether a Component Needs ScopeSource?

**A:** ScopeSource only needs to be added when the component needs to support the SCOPE scope.

**Decision process:**

```
1. Does the component need to read/write variables?
   ├─ No → ScopeSource is not needed
   └─ Yes → continue

2. Does the component need to support the SCOPE scope?
   ├─ No → Only LOCAL/GLOBAL is needed; ScopeSource is not needed
   └─ Yes → continue

3. Does the component need to specify which SCOPE container to use?
   ├─ No → Only NEAREST is used; it can be simplified and ScopeSource omitted
   └─ Yes → ScopeSource support must be added
```

**Examples:**

**ScopeSource not needed:**
```gdscript
# Only supports LOCAL and GLOBAL
@export var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
# ScopeSource not needed
```

**ScopeSource needed:**
```gdscript
# Supports all three layers: LOCAL/SCOPE/GLOBAL
@export var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

# A container must be specified when SCOPE
var scope_source: ScopeSource = ScopeSource.NEAREST
var custom_scope_id: String = ""
var target_node_path: NodePath = NodePath("")
```

---

## List of Refactored Instructions

### Math Instructions (5)
- ✅ `MathOperation` - Math operation (save_to_scope added 2026-02-10)
- ✅ `Lerp` - Linear interpolation (save_to_scope added 2026-02-10)
- ✅ `ClampValue` - Value clamping (save_to_scope added 2026-02-10)
- ✅ `RandomNumber` - Random number (save_to_scope added 2026-02-10)
- ✅ `VectorOperation` - Vector operation (save_to_scope added 2026-02-10)

### Transform Instructions (6)
- ✅ `SetPosition` - Set position
- ✅ `SetRotation` - Set rotation
- ✅ `SetScale` - Set scale
- ✅ `RotateBy` - Rotate by offset
- ✅ `MoveBy` - Move by offset
- ✅ `LookAt` - Look at target

### UI Instructions (3)
- ✅ `SetUIText` - Set text
- ✅ `SetUITexture` - Set texture
- ✅ `SetUIProgress` - Set progress bar

### Camera Instructions (1)
- ✅ `SetCameraZoom` - Set camera zoom

### Animation Instructions (1)
- ✅ `BlendAnimation` - Blend animation

### Time Instructions (1)
- ✅ `GetDeltaTime` - Get delta time

### Scene Instructions (2)
- ✅ `GetScenePath` - Get scene path (save_to_scope added 2026-02-10)
- ✅ `LoadSceneBackground` - Load scene in background

### Variables Instructions (2)
- ✅ `SetVariable` - Set variable (dual-scope enum added 2026-02-10)
- ✅ `CreateVariable` - Create variable (reference implementation, fully correct)

### Node Operations Instructions (3)
- ✅ `FindNode` - Find node
- ✅ `InstantiateScene` - Instantiate scene
- ✅ `SetPropertyValue` - Set property value

### Physics Instructions (1)
- ✅ `Raycast` - Raycast detection

### Debug Instructions (1)
- ✅ `PrintVariableValue` - Print variable value (fixed the resource name display bug)

**Total:** 27 instructions refactored ✅

**2026-02-10 update:** 7 components gained full ScopeSource support (conditional display)

---

## Reference Resources

### Core Class Files
- `addons/fuse/core/utils/variable_operations.gd` - Unified variable access interface
- `addons/fuse/core/utils/variable_scope_utils.gd` - Scope utility class
- `addons/fuse/core/base/base_variable.gd` - VariableScope enum definition
- `addons/fuse/core/base/execution_context.gd` - Execution context
- `addons/fuse/core/scope_variable_manager.gd` - Scope variable manager
- `addons/fuse/core/base/scope_variable_container.gd` - Scope variable container
- `addons/fuse/core/global_variable_manager.gd` - Global variable manager
- `addons/fuse/core/global_variable_assistant.gd` - Global variable assistant

### Example Instructions
- `addons/fuse/instructions/math/math_operation.gd`
- `addons/fuse/instructions/math/lerp.gd`
- `addons/fuse/instructions/math/vector_operation.gd`
- `addons/fuse/instructions/transform/set_position.gd`
- `addons/fuse/instructions/time/get_delta_time.gd`

### Documentation
- `addons/fuse/docs/system_docs/execution_system.md` - Execution system documentation
- `addons/fuse/docs/user_docs/instruction_development_guide.md` - Instruction development guide

---

## Version History

### v3.1 (2026-02-10) - ScopeSource Architecture Fixes
- ✅ **Fixed a critical architecture mistake** - ScopeSource cannot replace the three-layer variable system
- ✅ **Clarified the architecture principle** - VariableScope (three layers) + ScopeSource (only shown when SCOPE)
- ✅ **Fixed 7 components** - random_number, set_variable, get_scene_path, clamp_value, math_operation, lerp, vector_operation
- ✅ **Established the standard pattern** - The 6-step fix pattern for conditional ScopeSource display
- ⚠️ **Key lesson** - ScopeSource is only used to specify "which SCOPE container"; it cannot replace the VariableScope enum

**Architecture mistake retrospective:**
- **Wrong approach**: Removing the VariableScope enum and using only ScopeSource
- **Correct approach**: Keeping VariableScope (LOCAL/SCOPE/GLOBAL), with ScopeSource shown only when SCOPE

### v3.0 (2026-02-09)
- ✅ Added the three-layer variable architecture (LOCAL/SCOPE/GLOBAL)
- ✅ Introduced the `VariableOperations` unified access interface
- ✅ Introduced the `VariableScopeUtils` utility class
- ✅ Refactored 25 instructions to use the new API
- ✅ Removed the `is_global: bool` property
- ✅ Adopted the type-safe `VariableScope` enum

### v2.0 (2026-01-25)
- Removed the TRIGGER scope
- Only LOCAL and GLOBAL remained (this version's documentation was inaccurate; SCOPE had in fact been added)

### v1.0 (Initial Version)
- The basic two-layer LOCAL/GLOBAL variable system

---

## Appendix: Complete Instruction Refactoring Template

```gdscript
## Variable system refactor: 2026-02-09 - unified variable access with VariableOperations

@tool
extends BaseInstruction
class_name MyInstruction

## Input variable name
var input_variable: String = ""

## Input variable scope
@export var input_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
    set(value):
        input_scope = value
        _update_resource_name()

## Output variable name
var output_variable: String = "result"

## Output variable scope
@export var output_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
    set(value):
        output_scope = value
        _update_resource_name()

## Execute the instruction
func execute(context: ExecutionContext):
    _start_execution(context)

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

    # Save the result
    VariableOperations.set_variable(
        context,
        output_variable,
        output_scope,
        result
    )

    _on_execution_completed()

## Update the resource name
func _update_resource_name():
    var parts := []

    parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_MY_INSTRUCTION_RESOURCE"))

    if not input_variable.is_empty():
        var input_scope_str = VariableScopeUtils.enum_to_string(input_scope).to_upper()
        parts.append("← %s [%s]" % [input_variable, input_scope_str])
    else:
        parts.append("← (%s)" % FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY"))

    parts.append("→")

    if not output_variable.is_empty():
        var output_scope_str = VariableScopeUtils.enum_to_string(output_scope).to_upper()
        parts.append("%s [%s]" % [output_variable, output_scope_str])
    else:
        parts.append("(%s)" % FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY"))

    resource_name = " ".join(parts)

## Validate instruction parameters
func validate() -> Array[String]:
    var errors = super.validate()

    # Validate the input variable name
    if input_variable.is_empty():
        errors.append(FuseLocalization.translate("FUSE_ERROR_INPUT_VAR_NAME_EMPTY"))

    # Validate the output variable name
    if output_variable.is_empty():
        errors.append(FuseLocalization.translate("FUSE_ERROR_OUTPUT_VAR_NAME_EMPTY"))

    # The SCOPE scope requires a ScopeVariableManager
    if input_scope == BaseVariable.VariableScope.SCOPE:
        var manager = ScopeVariableManager.get_instance()
        if manager == null:
            errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

    if output_scope == BaseVariable.VariableScope.SCOPE:
        var manager = ScopeVariableManager.get_instance()
        if manager == null:
            errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

    return errors

## Get the instruction description
func get_description() -> String:
    var input_scope_str = VariableScopeUtils.enum_to_string(input_scope).to_upper()
    var output_scope_str = VariableScopeUtils.enum_to_string(output_scope).to_upper()

    var input_str = input_variable if not input_variable.is_empty() else "(%s)" % FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY")
    var output_str = output_variable if not output_variable.is_empty() else "(%s)" % FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY")

    return FuseLocalization.translate_format("FUSE_INSTRUCTION_MY_INSTRUCTION_DESC_FORMAT", {
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

## Internal processing method
func _process_value(value: Variant) -> Variant:
    # Implement the concrete processing logic
    return value
```

---

**End of document**

## Architecture Updates (2026-03)

- VariableContainer has been marked @deprecated
- Added the ScopeVariableContainer / ScopeVariableManager scope variable system
- Added the GlobalVariableAssistant / GlobalVariableManager global variable system
- Added the VariableOperations / VariableScopeUtils unified access utility classes
- VariableScope enum extended: LOCAL / GLOBAL / SCOPE
