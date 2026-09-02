> 🌐 [**中文版**](../../../zh_CN/dev_docs/guides/condition-creation-guide.md) | English

# Fuse Condition Creation Guide

> **Goal**: Provide developers with a complete guide to creating Fuse conditions, based on existing condition implementation experience and best practices.
> **Authoritative spec**: The final authority for component generation is the [fuse-condition-generator skill](../../../../agent_skills/fuse-condition-generator/SKILL.md) (templates, naming rules, and validation gates); this guide details its architectural principles.

**Audience**: Fuse system developers and contributors

**Last updated**: 2026-06-17

---

## 📋 Table of Contents

1. [Conditions vs Events vs Instructions](#conditions-vs-events-vs-instructions)
2. [Naming Conventions](#naming-conventions)
3. [Icon Conventions](#icon-conventions)
4. [Required Methods](#required-methods)
5. [Optional Methods](#optional-methods)
6. [Condition Features](#condition-features)
7. [Variable Operations (Three-Layer Variable System)](#variable-operations-three-layer-variable-system)
8. [Complete Condition Templates](#complete-condition-templates)
9. [Creation Steps](#creation-steps)
10. [Best Practices](#best-practices)
11. [Common Pitfalls](#common-pitfalls)
12. [Testing Standards](#testing-standards)

---

## Conditions vs Events vs Instructions

Understanding the differences between Conditions, Events, and Instructions is the first step in creating a condition.

| Feature | Condition | Event | Instruction |
|------|-----------------|-------------|-------------------|
| **Purpose** | Judge whether a condition is met | Listen for conditions, trigger responses | Execute concrete actions |
| **Core method** | `_evaluate_condition()` | `initialize()`/`terminate()` | `execute()` |
| **Return value** | `bool` | None (emits signals) | None (emits signals) |
| **Invocation** | Called passively (checked by the system) | Triggered passively | Executed actively |
| **Lifecycle** | Stateless (or cacheable) | initialize → terminate | execute → finished/cancelled/error |
| **Features** | Negation, caching, dependency tracking | Signal management | Execution state management |
| **Typical uses** | Variable comparison, node checks, state checks | Input, collision, signals | Movement, playback, variable setting |

**Core differences**:
- **Condition** is the "evaluator" - checks whether some condition is met and returns a boolean value
- **Event** is the "listener" - waits for something to happen, then emits the `triggered` signal
- **Instruction** is the "executor" - performs an action, then emits the `finished` signal

---

## Naming Conventions

**Important**: All Fuse conditions follow the naming conventions below, using different prefixes based on function type.

### Function-Based Naming Rules

Conditions use different prefixes based on function type, making names more precise and semantic.

#### Check-Type Conditions (Check)

Used to check whether a state/condition holds.

```
文件名：   check_<描述>.gd
类名：     Check<描述>
条件类型： <描述>
```

**Example**:
```
文件名：   check_node_exists.gd
类名：     CheckNodeExists
条件类型： "node_exists"
```

**More examples**:
- `check_node_exists.gd` → `CheckNodeExists` - checks whether a node exists
- `check_node_property.gd` → `CheckNodeProperty` - checks a node property
- `check_variable_exists.gd` → `CheckVariableExists` - checks whether a variable exists
- `check_is_in_group.gd` → `CheckIsInGroup` - checks membership in a group
- `check_is_visible.gd` → `CheckIsVisible` - checks visibility

#### Compare-Type Conditions (Compare)

Used to compare two values or their relationship.

```
文件名：   compare_<描述>.gd
类名：     Compare<描述>
条件类型： <描述>
```

**Example**:
```
文件名：   compare_variable.gd
类名：     CompareVariable
条件类型： "variable_comparison"
```

**More examples**:
- `compare_variable.gd` → `CompareVariable` - compares variable values
- `compare_health.gd` → `CompareHealth` - compares health
- `compare_score.gd` → `CompareScore` - compares score
- `compare_distance.gd` → `CompareDistance` - compares distance
- `compare_node_property.gd` → `CompareNodeProperty` - compares a node property

### Naming Convention Summary

| Type | Prefix | File name format | Class name format | Purpose |
|------|------|-----------|---------|------|
| **Check-type** | `check_` | `check_<描述>.gd` | `Check<描述>` | Check states/conditions |
| **Compare-type** | `compare_` | `compare_<描述>.gd` | `Compare<描述>` | Compare value relationships |

**Naming rules**:
- File names must use the function prefix (`check_` or `compare_`)
- File names use `snake_case`
- Class names use `PascalCase`, matching the prefix (`Check` or `Compare`)
- Condition type strings use `snake_case`, without the prefix

### Test File Naming

- **Test script**: `test_<文件名>.gd`
  - Examples: `test_check_node_exists.gd`, `test_compare_variable.gd`
- **Test scene**: `test_<文件名>.tscn`
  - Examples: `test_check_node_exists.tscn`, `test_compare_variable.tscn`

### Consistency Principles

- File name, class name, and test file name share the same base name
- Must use the function prefix (`check_` or `compare_`)
- The class name prefix (`Check` or `Compare`) matches the file name prefix
- Keep names concise and readable

**Complete example**:
```
检查类条件：
  文件名：     check_node_exists.gd
  类名：       CheckNodeExists
  条件类型：   "node_exists"
  测试脚本：   test_check_node_exists.gd
  测试场景：   test_check_node_exists.tscn

对比类条件：
  文件名：     compare_variable.gd
  类名：       CompareVariable
  条件类型：   "variable_comparison"
  测试脚本：   test_compare_variable.gd
  测试场景：   test_compare_variable.tscn
```

---

## Icon Conventions

**Icon selection principle**: Every condition should have an icon configured, to improve user experience and visualization.

### Icon Configuration Methods

**Recommended: use Godot builtin icons**
```gdscript
metadata.builtin_icon = "KeyCurve"  # 使用 Godot 内置图标名称
```

**Alternative: use a custom icon library**
```gdscript
metadata.custom_icon = "my_custom_icon"  # 使用导入的自定义图标
```

**Backward compatibility**
```gdscript
metadata.icon_name = "KeyCurve"  # 旧方式，仍然有效
metadata.icon = preload("res://icon.png")  # 直接指定纹理
```

### Builtin Icon Name Reference

**Common icon names**:
- **Variable conditions**: `KeyCurve`, `Hash`, `Array`, `Dictionary`
- **Node conditions**: `Node`, `NodePath`, `HostNode`, `Circle`
- **Physics conditions**: `CollisionShape2D`, `CollisionShape3D`, `PhysicsBody2D`
- **State conditions**: `CheckBox`, `Toggle`, `Check`, `Switch`
- **Math conditions**: `Math`, `Graph`, `Curve`, `CurveXY`
- **General**: `Script`, `File`, `Folder`, `Search`

**Full list**: See [icon-system-guide.md](icon-system-guide.md)

### Icon Configuration Steps

Configure the icon in `_get_condition_metadata()`:

```gdscript
static func _get_condition_metadata() -> ConditionMetadata:
    var metadata = ConditionMetadata.new()
    metadata.builtin_icon = "KeyCurve"  # 配置图标
    return metadata
```

---

## Required Methods

All conditions **must** implement the following methods, otherwise compilation errors will occur.

### 1. `_update_resource_name()` - Update Resource Name

**Marker**: `@abstract` - **must implement**

```gdscript
## Update the resource name (required)
##
## Updates resource_name from condition properties, for display in the editor Inspector
func _update_resource_name():
    var parts = []
    parts.append("条件类型名称")
    if not some_property.is_empty():
        parts.append("'%s'" % some_property)
    resource_name = " ".join(parts)
```

**Purpose**:
- Displays a meaningful condition name in the editor
- Makes it easy for users to identify and distinguish different condition configurations

**Example**:
```gdscript
# Simple condition
func _update_resource_name():
    resource_name = "变量比较: %s" % variable_name

# Complex condition
func _update_resource_name():
    var op_symbol = _get_operator_symbol()
    resource_name = "%s %s %s" % [variable_name, op_symbol, str(threshold)]
```

---

### 2. `_evaluate_condition()` - Evaluate the Condition

**Marker**: `@abstract` - **must implement**

```gdscript
## Evaluate the condition (required)
##
## The core method that evaluates whether the condition is met
##
## Parameters:
## - context: ExecutionContext - execution context
##
## Returns:
## - bool - condition evaluation result (true = met, false = not met)
func _evaluate_condition(context: ExecutionContext) -> bool:
    # Validate parameters
    if some_parameter.is_empty():
        _log_error_localized("FUSE_ERROR_CONDITION_PARAM_EMPTY", {"param": "some_parameter"})
        _create_fuse_error_localized("FUSE_ERROR_CONDITION_PARAM_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {"param": "some_parameter"})
        return false

    # Perform the condition check logic
    var result = perform_check(context)

    _log_debug("条件评估: %s => %s" % [get_description(), result])

    return result
```

**Purpose**:
- The core condition judgment logic
- Returns `true` when the condition is met, `false` when not
- The system automatically applies the `negate_result` negation setting
- The system automatically handles caching (if enabled)

**Important**:
- Must return a boolean value
- Validate parameter validity
- Log messages
- Do not handle negation here (the system handles it automatically)

**Example**:
```gdscript
# Simple condition
func _evaluate_condition(context: ExecutionContext) -> bool:
    if variable_name.is_empty():
        return false

    var value = VariableOperations.get_variable(context, variable_name, variable_scope, null)
    return value == expected_value

# Complex condition
func _evaluate_condition(context: ExecutionContext) -> bool:
    var node = context.get_node(target_path)
    if not node:
        return false

    if not node has_method("get_health"):
        return false

    var health = node.get_health()
    return health > threshold
```

---

### 3. `_compute_dependencies()` - Compute Dependencies

**Marker**: `@abstract` - **must implement**

```gdscript
## Compute dependencies (required)
##
## Returns the list of variable names this condition depends on
## Used for cache invalidation and dependency tracking
##
## Returns:
## - Array[String] - list of dependent variable names
func _compute_dependencies() -> Array[String]:
    var deps: Array[String] = []

    # Add the dependent variables
    if not variable_name.is_empty():
        deps.append(variable_name)

    if not another_variable_name.is_empty():
        deps.append(another_variable_name)

    return deps
```

**Purpose**:
- Declares the variables the condition depends on
- Used for smart cache invalidation
- Used for dependency tracking and optimization

**Important**:
- If the condition depends on no variables, return an empty array `[]`
- Return only dependent **variable names**, not variable values
- Used for cache invalidation detection

**Example**:
```gdscript
# Depends on a single variable
func _compute_dependencies() -> Array[String]:
    if not variable_name.is_empty():
        return [variable_name]
    return []

# Depends on multiple variables
func _compute_dependencies() -> Array[String]:
    return [var1, var2, var3]

# No variable dependencies
func _compute_dependencies() -> Array[String]:
    return []  # 例如：节点检查、时间检查等
```

---

## Optional Methods

These methods are not mandatory, but implementing them is strongly recommended to provide full functionality.

### 0. `_compute_thread_safety()` - Compute Thread Safety (Recommended)

```gdscript
## Compute thread safety (recommended)
##
## Determines whether the condition can be evaluated in parallel on worker threads.
## Only conditions meeting specific criteria may be marked as thread-safe.
##
## Returns:
## - bool - true means thread-safe and eligible for parallel evaluation
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	var is_safe := true

	# Check whether node access is needed
	if uses_target_node:
		is_safe = false

	# Check whether ExecutionContext (SCOPE scope) is accessed
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		is_safe = false

	_thread_safety_cached = is_safe
	_thread_safety_computed = true
	return _thread_safety_cached
```

**Thread safety conditions**:
- ❌ **No node access** - does not call `get_node()`, `get_parent()`, `get_tree()`
- ❌ **No access to the ExecutionContext trigger/target** - uses only variable snapshots
- ✅ **Reads only LOCAL/GLOBAL scope variables** - does not depend on the SCOPE scope
- ✅ **Calls only thread-safe APIs** - such as `Input.is_action_*()`

**Thread safety detection patterns**:

| Pattern | Example | Thread-safe |
|------|------|---------|
| **Always safe** | Input checks, preloaded state checks | ✅ |
| **Variable-scope dependent** | LOCAL/GLOBAL safe, SCOPE unsafe | Partial |
| **Node access** | Accessing node properties, child nodes | ❌ |
| **Composite conditions** | Depends on all sub-conditions | Recursive detection |

**Example - Input condition (always safe)**:
```gdscript
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	_thread_safety_cached = true  # Input API 线程安全
	_thread_safety_computed = true
	return _thread_safety_cached
```

**Example - Variable condition (scope-dependent)**:
```gdscript
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	var is_safe := true

	# The SCOPE scope requires ExecutionContext — not thread-safe
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		is_safe = false

	# If comparing against another variable, check its scope too
	if is_safe and check_with_another_variable:
		if compare_variable_scope == BaseVariable.VariableScope.SCOPE:
			is_safe = false

	_thread_safety_cached = is_safe
	_thread_safety_computed = true
	return _thread_safety_cached
```

**Example - Composite condition (recursive detection)**:
```gdscript
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	var is_safe := true
	for condition in conditions:
		if condition != null and not condition.is_thread_safe:
			is_safe = false
			break

	_thread_safety_cached = is_safe
	_thread_safety_computed = true
	return _thread_safety_cached
```

**Important notes**:
- `_thread_safety_cached` and `_thread_safety_computed` are provided by `BaseCondition`
- You must use the caching mechanism to avoid recomputation
- When in doubt, return `false` (conservative strategy)
- See [Multithreading Developer Guide](multithreading-developer-guide.md) for details

---

### 1. `get_description()` - Get Condition Description

```gdscript
## Get the condition description (recommended)
##
## Returns the condition's description, shown in logs and debugging
##
## Returns:
## - String - the condition description
func get_description() -> String:
    if variable_name.is_empty():
        return "变量比较 (未设置变量)"

    return "%s %s %s" % [variable_name, operator, str(compare_value)]
```

**Example**:
```gdscript
func get_description() -> String:
    match comparison_operator:
        EQUAL: return "%s == %s" % [variable_name, compare_value]
        GREATER_THAN: return "%s > %s" % [variable_name, compare_value]
        LESS_THAN: return "%s < %s" % [variable_name, compare_value]
        _: return "未知比较"
```

---

### 2. `get_condition_type()` - Get Condition Type

```gdscript
## Get the condition type (recommended)
##
## Returns the condition's unique type identifier
##
## Returns:
## - String - the condition type name
func get_condition_type() -> String:
    return "your_condition_type"
```

**Naming suggestions**:
- Use `snake_case`
- Concise and descriptive
- Examples: `"variable_comparison"`, `"node_exists"`, `"property_check"`

---

### 3. `get_condition_category()` - Get Condition Category

```gdscript
## Get the condition category (recommended)
##
## Returns the condition's category, used to organize conditions in the editor
##
## Returns:
## - String - the condition category name
func get_condition_category() -> String:
    return "your_category"
```

**Common categories**:
- `"variable"` - Variable-related conditions
- `"node"` - Node-related conditions
- `"property"` - Property-related conditions
- `"math"` - Math-related conditions
- `"state"` - State-related conditions

---

### 4. `validate()` - Validate Condition Configuration

```gdscript
## Validate the condition configuration (recommended)
##
## Validates the validity of the condition parameters
##
## Returns:
## - Array[String] - array of error messages; empty means validation passed
func validate() -> Array[String]:
    var errors = super.validate()

    # Add custom validation
    if variable_name.is_empty():
        errors.append("变量名不能为空")

    if compare_value == null:
        errors.append("比较值不能为空")

    return errors
```

---

### 5. `get_parameters()` / `set_parameters()` - Parameter Serialization

```gdscript
## Get the parameters (optional)
##
## Returns the condition's parameter dictionary
func get_parameters() -> Dictionary:
    return {
        "variable_name": variable_name,
        "comparison_operator": comparison_operator,
        "compare_value": compare_value
    }

## Set the parameters (optional)
##
## Sets the condition parameters from a dictionary
func set_parameters(parameters: Dictionary):
    if parameters.has("variable_name"):
        variable_name = parameters["variable_name"]
    if parameters.has("comparison_operator"):
        comparison_operator = parameters["comparison_operator"]
    if parameters.has("compare_value"):
        compare_value = parameters["compare_value"]

    clear_dependencies_cache()  # 清除依赖缓存
```

---

### 6. `_get_condition_metadata()` - Get Condition Metadata

```gdscript
## Get the condition metadata (recommended)
##
## Static method, returns the condition's metadata
## Used by the condition selector and editor display
##
## Returns:
## - ConditionMetadata - the condition metadata object
static func _get_condition_metadata() -> ConditionMetadata:
    var metadata = ConditionMetadata.new()
    metadata.name_key = "FUSE_CONDITION_XXX_NAME"
    metadata.category_key = "FUSE_CATEGORY_XXX"
    metadata.description_key = "FUSE_CONDITION_XXX_DESC"
    metadata.keywords = ["keyword1", "keyword2"]
    metadata.builtin_icon = "Script"
    return metadata
```

---

## Condition Features

BaseCondition provides powerful built-in features that subclasses can use without additional implementation.

### 1. Result Negation

```gdscript
@export var negate_result: bool = false
```

**Purpose**: Automatically negates the condition result; no manual handling in code needed.

**Example**:
```gdscript
# Condition: check whether a node exists
# If negate_result = false: returns true when the node exists
# If negate_result = true: returns true when the node does not exist

func _evaluate_condition(context: ExecutionContext) -> bool:
    var node = context.get_node(node_path)
    return node != null  # 系统会自动应用取反
```

### 2. Result Caching

```gdscript
@export var enable_cache: bool = false
@export var cache_duration: float = 1.0
@export var cache_context_changes: bool = true
```

**Purpose**: Caches condition evaluation results to improve performance.

**Use cases**:
- The condition check is expensive (e.g., traversing many nodes)
- The condition does not change over short periods
- The same condition needs to be checked frequently

**Automatic invalidation**:
- Expires after `cache_duration` elapses
- Invalidated when a dependent variable changes (if `cache_context_changes = true`)

### 3. Dependency Tracking

```gdscript
func get_dependencies() -> Array[String]:
    # Cached automatically to avoid recomputation
    if _cached_dependencies.is_empty():
        _cached_dependencies = _compute_dependencies()
    return _cached_dependencies
```

**Purpose**: Automatically tracks the variables the condition depends on, for cache invalidation and optimization.

### 4. Enable/Disable

```gdscript
@export var enabled: bool = true
```

**Purpose**: When disabled, the `check()` method always returns `false`.

### 5. Performance Metrics

```gdscript
var check_count: int = 0        # 检查次数
var last_check_time: float = 0.0 # 最后检查时间
var last_result: bool = false    # 最后检查结果
```

**Purpose**: Automatically records performance metrics for condition checks.

---

## Variable Operations (Three-Layer Variable System)

The Fuse system uses a **three-layer variable architecture**, and conditions need to read these variables during evaluation. Understanding how to access variables correctly is key to writing conditions.

### Three-Layer Variable Architecture

| Scope | Enum value | Storage location | Lifecycle | Purpose |
|--------|--------|----------|----------|------|
| **LOCAL** | `VariableScope.LOCAL` (0) | ExecutionContext | Single condition evaluation | Temporary data, intermediate values |
| **SCOPE** | `VariableScope.SCOPE` (1) | ScopeVariableContainer | Node lifetime | Scene-local variables |
| **GLOBAL** | `VariableScope.GLOBAL` (2) | GlobalVariableResource | Game runtime | Global game state |

### The VariableOperations Utility Class

Use the `VariableOperations` utility class for all variable access; **do not use** `context.get_variable()` or `context.set_variable()` directly.

#### Reading Variables

```gdscript
## Read a variable from the specified scope
##
## Parameters:
## - context: ExecutionContext - execution context
## - variable_name: String - variable name
## - scope: VariableScope - variable scope
## - default_value: Variant = null - default value (returned when the variable does not exist)
##
## Returns:
## - Variant - the variable value, or default_value if it does not exist
var value = VariableOperations.get_variable(context, "my_var", VariableScope.LOCAL)

## Read with a default value
var health = VariableOperations.get_variable(context, "player_health", VariableScope.GLOBAL, 100)
```

#### Checking Variable Existence

```gdscript
## Check whether a variable exists
##
## Parameters:
## - context: ExecutionContext - execution context
## - variable_name: String - variable name
## - scope: VariableScope - variable scope
##
## Returns:
## - bool - whether the variable exists
if VariableOperations.has_variable(context, "player_health", VariableScope.GLOBAL):
    var health = VariableOperations.get_variable(context, "player_health", VariableScope.GLOBAL)
```

### Variable Access Patterns in Conditions

#### 1. Conditions with a Fixed Scope

```gdscript
@export var variable_name: String = "":
    set(value):
        variable_name = value
        clear_dependencies_cache()

@export var scope: BaseVariable.VariableScope = BaseVariable.VariableScope.GLOBAL

@export var threshold: float = 0.0

func _evaluate_condition(context: ExecutionContext) -> bool:
    if variable_name.is_empty():
        _create_fuse_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
        return false

    # Read the variable with VariableOperations
    var value = VariableOperations.get_variable(context, variable_name, scope)
    if value == null:
        _create_fuse_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"variable": variable_name})
        return false

    # Perform the comparison
    return float(value) > threshold

func _compute_dependencies() -> Array[String]:
    if not variable_name.is_empty():
        return [variable_name]
    return []
```

#### 2. Multi-Scope Conditions (with Scope Selectors)

```gdscript
@export var variable_name: String = "":
    set(value):
        variable_name = value
        clear_dependencies_cache()

@export_group("Variable Scope")
@export var use_local: bool = false
@export var use_scope: bool = false
@export var scope_id: String = ""
@export var use_global: bool = true

func _get_effective_scope() -> BaseVariable.VariableScope:
    ## Determine the effective scope from the configuration
    if use_local:
        return BaseVariable.VariableScope.LOCAL
    elif use_scope:
        return BaseVariable.VariableScope.SCOPE
    else:
        return BaseVariable.VariableScope.GLOBAL

func _evaluate_condition(context: ExecutionContext) -> bool:
    if variable_name.is_empty():
        return false

    var scope = _get_effective_scope()
    var value = VariableOperations.get_variable(context, variable_name, scope, 0)
    return value > threshold
```

### The VariableScopeUtils Utility Class

Used to convert between the scope enum and strings:

```gdscript
## Convert the scope enum to a lowercase string
##
## GLOBAL -> "global"
## SCOPE -> "scope"
## LOCAL -> "local"
var scope_str = VariableScopeUtils.enum_to_string(BaseVariable.VariableScope.GLOBAL)

## Get the localized display name of a scope
##
## Used to show a friendly scope name in the Inspector
var display_name = VariableScopeUtils.enum_to_display_name(BaseVariable.VariableScope.SCOPE)
```

### Variable Best Practices in Conditions

#### ✅ Good Practices

```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    # 1. Validate parameters
    if variable_name.is_empty():
        _create_fuse_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
        return false

    # 2. Read the variable with VariableOperations
    var value = VariableOperations.get_variable(context, variable_name, scope)
    if value == null:
        _create_fuse_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"variable": variable_name})
        return false

    # 3. Type check
    if not (value is int or value is float):
        _log_warning("变量类型不支持数值比较: %s" % type_string(typeof(value)))
        return false

    # 4. Perform the comparison
    return float(value) > threshold
```

#### ❌ Bad Practices

```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    # ❌ Directly using context.get_variable() — not recommended
    var value = context.get_variable(variable_name)

    # ❌ No existence validation
    # ❌ No type check
    return value > threshold
```

### Declaring Variable Dependencies in Conditions

When a condition depends on variables, you must declare them in `_compute_dependencies()`:

```gdscript
func _compute_dependencies() -> Array[String]:
    # Return the list of dependent variable names (without scope prefixes)
    if not variable_name.is_empty():
        return [variable_name]
    return []
```

**Important**:
- Dependencies use only the **variable name**, without any scope
- The system automatically tracks changes to that variable across all scopes
- When the variable changes, cached evaluation results are invalidated automatically

### Variable Operations in Tests

In condition tests, use VariableOperations to set test variables:

```gdscript
func test_evaluation():
    var condition = MyCondition.new()
    condition.variable_name = "test_var"
    condition.scope = BaseVariable.VariableScope.LOCAL

    var context = ExecutionContext.new()
    add_child(context)

    # Set the test variable with VariableOperations
    VariableOperations.set_variable(context, "test_var", 100, BaseVariable.VariableScope.LOCAL)

    # Check the condition
    var result = condition.check(context)
    assert(result == true, "Condition should be true")

    context.queue_free()
```

---

## Complete Condition Templates

### Check-Type Condition Template

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/Script.png")
extends BaseCondition
class_name CheckSimpleValue

## Simple check condition template

# Parameter definitions
@export_group("Simple Condition")
@export var target_value: int = 0:
    set(value):
        target_value = value
        clear_dependencies_cache()

## Update the resource name (required)
func _update_resource_name():
    resource_name = "变量值等于 %d" % target_value

## Evaluate the condition (required)
func _evaluate_condition(context: ExecutionContext) -> bool:
    # Validate parameters
    if not context:
        _log_error_localized("FUSE_ERROR_CONTEXT_NULL_EVALUATE", {})
        _create_fuse_error_localized("FUSE_ERROR_CONTEXT_NULL_EVALUATE", FuseError.ErrorType.VALIDATION_ERROR)
        return false

    # Get the variable value (using VariableOperations)
    var var_name = "my_variable"
    var current_value = VariableOperations.get_variable(context, var_name, BaseVariable.VariableScope.LOCAL)

    if current_value == null:
        _log_warning("变量不存在: %s" % var_name)
        return false

    # Perform the comparison
    var result = current_value == target_value

    _log_debug("条件评估: %s (%d) == %d => %s" % [
        var_name, current_value, target_value, result
    ])

    return result

## Compute dependencies (required)
func _compute_dependencies() -> Array[String]:
    return ["my_variable"]

## Compute thread safety (recommended)
##
## The LOCAL scope is thread-safe; the SCOPE scope is not (requires ExecutionContext)
func _compute_thread_safety() -> bool:
    if _thread_safety_computed:
        return _thread_safety_cached

    # LOCAL and GLOBAL scopes can be evaluated in parallel
    _thread_safety_cached = true
    _thread_safety_computed = true
    return _thread_safety_cached

## Get the condition description (recommended)
func get_description() -> String:
    return "变量值等于 %d" % target_value

## Get the condition type (recommended)
func get_condition_type() -> String:
    return "simple_template"

## Get the condition category (recommended)
func get_condition_category() -> String:
    return "template"

## Validate the condition configuration (recommended)
func validate() -> Array[String]:
    var errors = super.validate()

    # Additional validation logic can be added here

    return errors

## Get the condition metadata (recommended)
static func _get_condition_metadata() -> ConditionMetadata:
    var metadata = ConditionMetadata.new()
    metadata.name_key = "FUSE_CONDITION_SIMPLE_TEMPLATE_NAME"
    metadata.category_key = "FUSE_CATEGORY_TEMPLATE"
    metadata.description_key = "FUSE_CONDITION_SIMPLE_TEMPLATE_DESC"
    metadata.keywords = ["template", "模板", "simple", "简单", "check", "检查"]
    metadata.builtin_icon = "Script"
    return metadata
```

---

### Compare-Type Condition Template

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/Hash.png")
extends BaseCondition
class_name CompareVariableThreshold

## Variable threshold comparison condition template (multiple parameters, multiple dependencies)

# Parameter definitions
@export_group("Complex Condition")
@export var variable_name: String = "":
    set(value):
        variable_name = value
        clear_dependencies_cache()

@export_enum("等于:0", "大于:1", "小于:2", "大于等于:3", "小于等于:4") var comparison_operator: int = 0

@export var threshold: float = 0.0:
    set(value):
        threshold = value
        clear_dependencies_cache()

@export var check_node_path: NodePath = NodePath("")

## Update the resource name (required)
func _update_resource_name():
    if variable_name.is_empty():
        resource_name = "复杂条件 (未设置变量)"
        return

    var op_symbol = _get_operator_symbol()
    resource_name = "%s %s %.2f" % [variable_name, op_symbol, threshold]

## Evaluate the condition (required)
func _evaluate_condition(context: ExecutionContext) -> bool:
    # 1. Validate parameters
    if variable_name.is_empty():
        _log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
        _create_fuse_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
        return false

    # 2. Get the variable value (using VariableOperations)
    var var_value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.GLOBAL)
    if var_value == null:
        _log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": variable_name})
        _create_fuse_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"variable": variable_name})
        return false

    # 3. Check the node (optional)
    if not check_node_path.is_empty():
        var node = context.get_node(check_node_path)
        if not node:
            _log_warning("节点不存在: %s" % check_node_path)
            return false

    # 4. Perform the comparison
    var result := false

    # Convert the values to float for comparison
    var var_float = float(var_value)
    var threshold_float = float(threshold)

    match comparison_operator:
        0:  # 等于
            result = is_equal_approx(var_float, threshold_float)
        1:  # 大于
            result = var_float > threshold_float
        2:  # 小于
            result = var_float < threshold_float
        3:  # 大于等于
            result = var_float >= threshold_float
        4:  # 小于等于
            result = var_float <= threshold_float
        _:
            _log_error_localized("FUSE_ERROR_UNKNOWN_COMPARISON_OPERATOR", {"operator": comparison_operator})
            return false

    _log_debug("条件评估: %s (%.2f) %s %.2f => %s" % [
        variable_name,
        var_float,
        _get_operator_symbol(),
        threshold_float,
        result
    ])

    return result

## Compute dependencies (required)
func _compute_dependencies() -> Array[String]:
    if not variable_name.is_empty():
        return [variable_name]
    return []

## Get the operator symbol
func _get_operator_symbol() -> String:
    match comparison_operator:
        0: return "=="
        1: return ">"
        2: return "<"
        3: return ">="
        4: return "<="
        _: return "?"

## Get the condition description (recommended)
func get_description() -> String:
    if variable_name.is_empty():
        return "复杂条件 (未设置变量)"

    var op_symbol = _get_operator_symbol()
    var desc = "%s %s %.2f" % [variable_name, op_symbol, threshold]

    # Limit the description length
    if desc.length() > 50:
        desc = desc.substr(0, 47) + "..."

    return desc

## Get the condition type (recommended)
func get_condition_type() -> String:
    return "complex_template"

## Get the condition category (recommended)
func get_condition_category() -> String:
    return "template"

## Validate the condition configuration (recommended)
func validate() -> Array[String]:
    var errors = super.validate()

    if variable_name.is_empty():
        errors.append("变量名不能为空")

    if comparison_operator < 0 or comparison_operator > 4:
        errors.append("无效的比较运算符")

    return errors

## Get the parameters (optional)
func get_parameters() -> Dictionary:
    return {
        "variable_name": variable_name,
        "comparison_operator": comparison_operator,
        "threshold": threshold,
        "check_node_path": check_node_path
    }

## Set the parameters (optional)
func set_parameters(parameters: Dictionary):
    if parameters.has("variable_name"):
        variable_name = parameters["variable_name"]
    if parameters.has("comparison_operator"):
        comparison_operator = parameters["comparison_operator"]
    if parameters.has("threshold"):
        threshold = parameters["threshold"]
    if parameters.has("check_node_path"):
        check_node_path = parameters["check_node_path"]

    clear_dependencies_cache()

## Get the condition metadata (recommended)
static func _get_condition_metadata() -> ConditionMetadata:
    var metadata = ConditionMetadata.new()
    metadata.name_key = "FUSE_CONDITION_COMPLEX_TEMPLATE_NAME"
    metadata.category_key = "FUSE_CATEGORY_TEMPLATE"
    metadata.description_key = "FUSE_CONDITION_COMPLEX_TEMPLATE_DESC"
    metadata.keywords = ["template", "模板", "complex", "复杂", "comparison", "比较", "threshold", "阈值"]
    metadata.builtin_icon = "Hash"
    return metadata
```

---

## Creation Steps

### Step 1: Create the Condition Class Skeleton

Create the condition file `addons/fuse/conditions/<your_condition_name>_condition.gd`:

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/Script.png")
extends BaseCondition
class_name YourConditionName

## Condition description

# Parameter definitions
@export_group("Your Condition")
@export var your_property: String = ""

## Update the resource name (required)
func _update_resource_name():
    resource_name = "你的条件: %s" % your_property

## Evaluate the condition (required)
func _evaluate_condition(context: ExecutionContext) -> bool:
    # TODO: Implement the condition evaluation logic
    return false

## Compute dependencies (required)
func _compute_dependencies() -> Array[String]:
    return []
```

### Step 2: Implement the Core Methods

**2.1 Implement `_evaluate_condition()`**:
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    # 1. Validate parameters
    if your_property.is_empty():
        _log_error_localized("FUSE_ERROR_CONDITION_PROPERTY_EMPTY", {"property": "your_property"})
        _create_fuse_error_localized("FUSE_ERROR_CONDITION_PROPERTY_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {"property": "your_property"})
        return false

    # 2. Perform the condition check logic
    var result = perform_your_check(context, your_property)

    # 3. Log
    _log_debug("条件评估: %s => %s" % [your_property, result])

    return result
```

**2.2 Implement `_compute_dependencies()`**:
```gdscript
func _compute_dependencies() -> Array[String]:
    # Return the list of dependent variable names
    if not your_property.is_empty():
        return [your_property]
    return []
```

### Step 3: Add Localization Translations

Add to `addons/fuse/localization/translations.csv`:

```csv
key,zh_CN,en_US
FUSE_CONDITION_YOUR_CONDITION_NAME,你的条件名称,Your Condition Name
FUSE_CATEGORY_YOUR_CATEGORY,你的分类,Your Category
FUSE_CONDITION_YOUR_CONDITION_DESC,条件描述,Condition description
FUSE_ERROR_YOUR_CONDITION_ERROR,错误消息,Error message
```

**Notes**:
- Use the `NAME` suffix for condition names
- Use the `DESC` suffix for condition descriptions
- Use the `ERROR_` suffix for error messages
- All placeholders use the `{variable_name}` format

### Step 4: Create the Test Scene

**Step 4.1: Create the test scene file**

Create `tests/conditions/test_<condition_name>.tscn`:

```gdscript
[gd_scene load_steps=2 format=3 uid="uid://test_xxx"]

[ext_resource type="Script" path="res://tests/conditions/test_xxx.gd" id="1"]

[node name="TestXxx" type="Node"]
script = ExtResource("1")
```

**Step 4.2: Create the test script**

Create `tests/conditions/test_<condition_name>.gd`:

```gdscript
extends Node

## Tests for the YourConditionName condition

func _ready():
    print("=== Testing YourConditionName ===")
    test_basic_functionality()
    test_edge_cases()
    print("=== All YourConditionName tests passed! ===")

func test_basic_functionality():
    print("Test 1: Basic functionality")

    var condition_script = load("res://addons/fuse/conditions/your_condition_name.gd")
    var condition = condition_script.new()
    condition.your_property = "test_value"

    var context = ExecutionContext.new()
    add_child(context)

    # Set the variable (using VariableOperations)
    VariableOperations.set_variable(context, "test_var", 100, BaseVariable.VariableScope.LOCAL)

    # Check the condition
    var result = condition.check(context)

    # Verify the result
    assert(result == expected, "Condition should return expected value")
    print("  ✓ Test 1 passed\n")

    # Clean up
    context.queue_free()

func test_edge_cases():
    print("Test 2: Edge cases")
    # Test edge cases...
    print("  ✓ Test 2 passed\n")
```

### Step 5: Test and Verify

1. Open the test scene in Godot
2. Run the tests and confirm all test cases pass
3. Check that the Inspector display in the editor is correct
4. Verify that localization takes effect
5. Verify that caching works correctly
6. Verify that negation works correctly

---

## Best Practices

### 1. Parameter Validation

**Principle**: Validate all parameters at the start of `_evaluate_condition()`.

```gdscript
# ✅ Good practice
func _evaluate_condition(context: ExecutionContext) -> bool:
    # Validate the context
    if not context:
        _create_fuse_error_localized("FUSE_ERROR_CONTEXT_NULL", FuseError.ErrorType.VALIDATION_ERROR, {})
        return false

    # Validate parameters
    if variable_name.is_empty():
        _create_fuse_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
        return false

    # Perform the check logic
    ...
```

```gdscript
# ❌ Parameters not validated
func _evaluate_condition(context: ExecutionContext) -> bool:
    # Using parameters directly may cause errors
    var value = context.get_variable(variable_name)  # variable_name 可能为空
    ...
```

---

### 2. Dependency Declaration

**Principle**: Declare all dependent variables correctly.

```gdscript
# ✅ Good practice
func _compute_dependencies() -> Array[String]:
    var deps: Array[String] = []

    # Add all dependent variables
    if not var1.is_empty():
        deps.append(var1)
    if not var2.is_empty():
        deps.append(var2)

    return deps
```

```gdscript
# ❌ Forgetting to declare dependencies
func _compute_dependencies() -> Array[String]:
    return []  # 实际上使用了变量，但未声明
```

---

### 3. Localized Errors

**Principle**: Use localized error messages.

```gdscript
# ✅ Good practice
if variable_name.is_empty():
    _create_fuse_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
    return false
```

```gdscript
# ❌ Hardcoded error message
if variable_name.is_empty():
    _create_fuse_error("变量名不能为空", FuseError.ErrorType.VALIDATION_ERROR)
    return false
```

---

### 4. Logging

**Principle**: Use appropriate log levels and localized logs.

```gdscript
# ✅ Good practice
func _evaluate_condition(context: ExecutionContext) -> bool:
    _log_debug("开始评估条件: %s" % get_description())

    var result = perform_check()

    _log_debug("条件评估结果: %s => %s" % [get_description(), result])
    return result
```

---

### 5. Type Safety

**Principle**: Use type annotations and type checks.

```gdscript
# ✅ Good practice
func _evaluate_condition(context: ExecutionContext) -> bool:
    var value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.GLOBAL)

    # Type check
    if not typeof(value) in [TYPE_INT, TYPE_FLOAT]:
        _log_warning("变量类型不支持比较: %s" % type_string(typeof(value)))
        return false

    return value > threshold
```

---

### 6. Use the Negation Feature

**Principle**: Do not implement negation manually in code; use the built-in `negate_result`.

```gdscript
# ✅ Good practice
func _evaluate_condition(context: ExecutionContext) -> bool:
    # Return only the positive condition
    return node != null

# Users can set negate_result = true in the Inspector to invert the result
```

```gdscript
# ❌ Manually implementing negation
func _evaluate_condition(context: ExecutionContext) -> bool:
    # Don't do this; use negate_result instead
    return not (node != null)
```

---

### 7. Cache Optimization

**Principle**: For expensive condition checks, enable caching.

```gdscript
# Set in the Inspector:
# enable_cache = true
# cache_duration = 1.0  # Cache for 1 second
```

**Applicable scenarios**:
- Traversing large numbers of nodes
- Complex math computations
- Accessing remote resources

---

### 8. Description Length Limits

**Principle**: Limit description length to avoid UI display issues.

```gdscript
# ✅ Good practice
func get_description() -> String:
	var desc = "很长的描述字符串..."

	# Limit the description length
	if desc.length() > 50:
		desc = desc.substr(0, 47) + "..."

	return desc
```

---

### 9. Thread Safety Implementation

**Principle**: Implement `_compute_thread_safety()` correctly to support parallel evaluation.

```gdscript
# ✅ Good practice - uses the caching mechanism
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	var is_safe := true

	# Check for unsafe factors
	if needs_node_access or uses_scope_variables:
		is_safe = false

	_thread_safety_cached = is_safe
	_thread_safety_computed = true
	return _thread_safety_cached
```

```gdscript
# ❌ Wrong - no caching
func _compute_thread_safety() -> bool:
	return not needs_node_access  # 每次都重新计算
```

```gdscript
# ❌ Wrong - conservative estimate but actually unsafe
func _compute_thread_safety() -> bool:
	return true  # 但实际上访问了节点！
```

**Thread safety checklist**:
- [ ] Does not call `get_node()`, `get_parent()`, `get_tree()`
- [ ] Does not access `context.trigger` or `context.target`
- [ ] Uses only LOCAL/GLOBAL scope variables
- [ ] Does not modify any global state
- [ ] Uses the caching mechanism to avoid recomputation

**Principle**: Limit description length to avoid UI display issues.

```gdscript
# ✅ Good practice
func get_description() -> String:
    var desc = "很长的描述字符串..."

    # Limit the description length
    if desc.length() > 50:
        desc = desc.substr(0, 47) + "..."

    return desc
```

---

## Common Pitfalls

### Pitfall 1: Forgetting to Implement Required Methods

**Problem**:
```gdscript
@tool
extends BaseCondition
class_name MyCondition

# ❌ Forgot to implement _update_resource_name()
# ❌ Forgot to implement _evaluate_condition()
# ❌ Forgot to implement _compute_dependencies()
```

**Consequence**:
- Compilation errors (all three methods are `@abstract`)

**Solution**:
```gdscript
@tool
extends BaseCondition
class_name MyCondition

# ✅ Implement all required methods
func _update_resource_name():
    resource_name = "My Condition"

func _evaluate_condition(context: ExecutionContext) -> bool:
    return true

func _compute_dependencies() -> Array[String]:
    return []
```

---

### Pitfall 2: Handling Negation in _evaluate_condition

**Problem**:
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    var result = check_condition()

    # ❌ Manually handling negation
    if negate_result:
        result = not result

    return result
```

**Consequence**: Negation is applied twice (once in your code, once in the base class).

**Solution**:
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    # ✅ Return only the positive result; the base class applies negation automatically
    return check_condition()
```

---

### Pitfall 3: Not Declaring Dependent Variables

**Problem**:
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    # Uses the variables var1 and var2
    var val1 = VariableOperations.get_variable(context, "var1", BaseVariable.VariableScope.LOCAL)
    var val2 = VariableOperations.get_variable(context, "var2", BaseVariable.VariableScope.LOCAL)
    return val1 > val2

# ❌ Forgot to declare in _compute_dependencies
func _compute_dependencies() -> Array[String]:
    return []
```

**Consequence**: The cache may not invalidate correctly.

**Solution**:
```gdscript
# ✅ Dependencies declared correctly
func _compute_dependencies() -> Array[String]:
    return ["var1", "var2"]
```

---

### Pitfall 4: Returning a Non-Boolean Value

**Problem**:
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    var value = VariableOperations.get_variable(context, "my_var", BaseVariable.VariableScope.LOCAL)
    return value  # ❌ 可能不是布尔值
```

**Consequence**: Type mismatch errors.

**Solution**:
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    var value = VariableOperations.get_variable(context, "my_var", BaseVariable.VariableScope.LOCAL)

    # ✅ Explicitly convert to a boolean
    if value is bool:
        return value
    elif value is int or value is float:
        return value != 0
    elif value is String:
        return not value.is_empty()
    else:
        return value != null
```

---

### Pitfall 5: Not Validating Parameters

**Problem**:
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    # ❌ Using parameters directly without validation
    var value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.GLOBAL)
    return value > threshold
```

**Consequence**: Runtime errors when parameters are empty.

**Solution**:
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    # ✅ Validate parameters
    if variable_name.is_empty():
        _create_fuse_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
        return false

    var value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.GLOBAL)
    if value == null:
        _create_fuse_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"variable": variable_name})
        return false

    return value > threshold
```

---

### Pitfall 6: Dependency Cache Not Cleared After Setting Parameters

**Problem**:
```gdscript
@export var variable_name: String = "":
    set(value):
        variable_name = value
        # ❌ Forgot to clear the dependency cache

@export var variable_name: String = ""
```

**Consequence**: The dependency list will not update and cache invalidation will be incorrect.

**Solution**:
```gdscript
@export var variable_name: String = "":
    set(value):
        variable_name = value
        clear_dependencies_cache()  # ✅ 清除依赖缓存
```

---

### Pitfall 7: Overly Long Descriptions Causing UI Issues

**Problem**:
```gdscript
func get_description() -> String:
    # ❌ The description can be very long
    return "这是一个非常非常非常非常非常非常非常非常非常非常长的描述..."
```

**Consequence**: UI display issues; text is truncated or overlaps.

**Solution**:
```gdscript
func get_description() -> String:
    var desc = "这是一个非常非常非常非常非常非常非常非常非常非常长的描述..."

    # ✅ Limit the description length
    if desc.length() > 50:
        desc = desc.substr(0, 47) + "..."

    return desc
```

---

### Pitfall 8: Not Handling Type Mismatches

**Problem**:
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    var value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.GLOBAL)
    # ❌ Direct comparison may have a type mismatch
    return value > threshold
```

**Consequence**: Type mismatch errors or unexpected comparison results.

**Solution**:
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    var value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.GLOBAL)

    # ✅ Type check and conversion
    if not (value is int or value is float):
        _log_warning("变量类型不支持数值比较: %s" % type_string(typeof(value)))
        return false

    return float(value) > float(threshold)
```

---

## Testing Standards

### Test File Structure

```gdscript
extends Node

## Tests for the ConditionName condition

func _ready():
    print("=== Testing ConditionName ===")
    test_evaluation()
    test_negation()
    test_caching()
    test_dependencies()
    test_edge_cases()
    print("=== All ConditionName tests passed! ===")
```

### Test Case Design

**Required tests**:
1. **Basic evaluation test** - verifies the condition evaluates correctly
2. **Negation test** - verifies the `negate_result` feature
3. **Caching test** - verifies caching works correctly
4. **Dependency test** - verifies dependencies are declared correctly
5. **Boundary value test** - tests extreme parameter values
6. **Error handling test** - verifies error cases are handled correctly

**Test example**:
```gdscript
func test_evaluation():
    print("Test 1: Basic evaluation")

    var condition = MyCondition.new()
    condition.variable_name = "test_var"
    condition.threshold = 100

    var context = ExecutionContext.new()
    add_child(context)

    # Test the condition being met (using VariableOperations)
    VariableOperations.set_variable(context, "test_var", 150, BaseVariable.VariableScope.LOCAL)
    assert(condition.check(context) == true, "Should be true when value > threshold")

    # Test the condition not being met
    VariableOperations.set_variable(context, "test_var", 50, BaseVariable.VariableScope.LOCAL)
    assert(condition.check(context) == false, "Should be false when value < threshold")

    print("  ✓ Test 1 passed\n")

    context.queue_free()

func test_negation():
    print("Test 2: Negation")

    var condition = MyCondition.new()
    condition.variable_name = "test_var"
    condition.threshold = 100
    condition.negate_result = true  # 启用取反

    var context = ExecutionContext.new()
    add_child(context)

    VariableOperations.set_variable(context, "test_var", 150, BaseVariable.VariableScope.LOCAL)
    # Due to negation, what originally returned true now returns false
    assert(condition.check(context) == false, "Should be false with negation")

    print("  ✓ Test 2 passed\n")

    context.queue_free()

func test_caching():
    print("Test 3: Caching")

    var condition = MyCondition.new()
    condition.variable_name = "test_var"
    condition.enable_cache = true
    condition.cache_duration = 1.0

    var context = ExecutionContext.new()
    add_child(context)

    VariableOperations.set_variable(context, "test_var", 100, BaseVariable.VariableScope.LOCAL)

    # First check
    var result1 = condition.check(context)
    assert(condition.check_count == 1, "Should increment check count")

    # Second check (should hit the cache)
    var result2 = condition.check(context)
    assert(condition.check_count == 1, "Should use cache, not increment count")

    print("  ✓ Test 3 passed\n")

    context.queue_free()

func test_dependencies():
    print("Test 4: Dependencies")

    var condition = MyCondition.new()
    condition.variable_name = "test_var"

    var deps = condition.get_dependencies()
    assert(deps.size() == 1, "Should have one dependency")
    assert(deps[0] == "test_var", "Dependency should be 'test_var'")

    print("  ✓ Test 4 passed\n")

func test_edge_cases():
    print("Test 5: Edge cases")

    var condition = MyCondition.new()
    # No variable name set
    condition.variable_name = ""

    var context = ExecutionContext.new()
    add_child(context)

    # Should return false (invalid parameters)
    assert(condition.check(context) == false, "Should return false with invalid parameters")

    print("  ✓ Test 5 passed\n")

    context.queue_free()
```

### Test Assertions

```gdscript
# Verify the condition result
assert(condition.check(context) == expected, "Condition should return expected value")

# Verify negation
assert(condition.check(context) == not expected, "Condition should be negated")

# Verify caching
assert(condition.check_count == expected_count, "Check count should match")

# Verify dependencies
assert(condition.get_dependencies().size() == expected_size, "Dependency count should match")
```

---

## Quick Reference

### Common Code Snippets

#### Variable Check
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    if variable_name.is_empty():
        _create_fuse_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
        return false

    var value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.GLOBAL)
    if value == null:
        _create_fuse_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"variable": variable_name})
        return false

    return value == expected_value
```

#### Node Check
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    if node_path.is_empty():
        _create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
        return false

    var node = context.get_node(node_path)
    if not node:
        return false

    # Check the node type
    if not node is NodeType:
        _log_warning("节点类型不匹配: %s" % node.get_class())
        return false

    return true
```

#### Numeric Comparison
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    var value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.GLOBAL)

    # Type check
    if not (value is int or value is float):
        _log_warning("变量类型不支持数值比较: %s" % type_string(typeof(value)))
        return false

    # Convert to float
    var value_float = float(value)
    var threshold_float = float(threshold)

    # Compare
    match comparison_operator:
        0: return is_equal_approx(value_float, threshold_float)
        1: return value_float > threshold_float
        2: return value_float < threshold_float
        3: return value_float >= threshold_float
        4: return value_float <= threshold_float
        _: return false
```

#### Property Check
```gdscript
func _evaluate_condition(context: ExecutionContext) -> bool:
    var node = context.get_node(node_path)
    if not node:
        return false

    # Check whether the property exists
    if not "property_name" in node:
        _log_warning("节点缺少属性: property_name")
        return false

    var value = node.get("property_name")

    # Compare the property values
    return value == expected_value
```

### Common Error Keys

Predefined localization error keys (see `translations.csv`):
- `FUSE_ERROR_CONTEXT_NULL` - Execution context is null
- `FUSE_ERROR_VAR_NAME_EMPTY` - Variable name is empty
- `FUSE_ERROR_VAR_NOT_FOUND` - Variable not found
- `FUSE_ERROR_TARGET_NODE_EMPTY` - Target node path is empty
- `FUSE_ERROR_TARGET_NODE_NOT_FOUND` - Target node not found
- `FUSE_ERROR_INVALID_TARGET` - Invalid target
- `FUSE_ERROR_MISSING_PARAMETER` - Missing required parameter

### Common Log Keys

- `FUSE_LOG_CONDITION_CHECK` - Condition check
- `FUSE_LOG_CONDITION_RESULT` - Condition result
- `FUSE_LOG_CONDITION_CACHE_HIT` - Cache hit
- `FUSE_LOG_CONDITION_CACHE_MISS` - Cache miss

---

## Summary

Key takeaways for creating Fuse conditions:

1. ✅ **Follow the naming conventions** - `_condition` suffix; class names naturally end with "Condition"
2. ✅ **Implement the required methods** - `_update_resource_name()`, `_evaluate_condition()`, `_compute_dependencies()`
3. ✅ **Declare dependencies correctly** - return all dependent variables in `_compute_dependencies()`
4. ✅ **Validate parameter validity** - validate at the start of `_evaluate_condition()`
5. ✅ **Use localized messages** - use `_create_fuse_error_localized()`
6. ✅ **Do not negate manually** - use the built-in `negate_result` property
7. ✅ **Add complete tests** - evaluation, negation, caching, dependencies, edge cases
8. ✅ **Limit description length** - avoid exceeding 50 characters
9. ✅ **Provide metadata** - implement the `_get_condition_metadata()` static method
10. ✅ **Use VariableOperations** - use VariableOperations consistently to access the three-layer variable system
11. ✅ **Implement thread safety detection** - override `_compute_thread_safety()` to support parallel evaluation

**Core principles**:
- **_update_resource_name()** updates the resource display name
- **_evaluate_condition()** returns a boolean value
- **_compute_dependencies()** declares the dependent variables
- **_compute_thread_safety()** determines whether parallel evaluation is possible (caching mechanism)
- **VariableOperations** is the unified variable access interface (LOCAL/SCOPE/GLOBAL)
- The system handles negation and caching automatically

**Reference documents**:
- [BaseCondition API](../../../../core/base/base_condition.gd)
- [Variable Operations (Three-Layer Variable System)](#variable-operations-three-layer-variable-system)
- [Complete Condition Templates](#complete-condition-templates)
- [Testing Standards](#testing-standards)

---

**Maintained by**: Fuse development team
**Last updated**: 2026-06-17
