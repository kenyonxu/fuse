> 🌐 [**中文版**](../../../zh_CN/dev_docs/guides/variable-operations-guide.md) | English

# VariableOperations Utility Class Architecture

## Overview

`VariableOperations` is a static utility class of the Fuse system that provides a unified operation interface for the three-layer variable system (LOCAL/SCOPE/GLOBAL). The class consolidates variable operation logic that was previously scattered across multiple instructions and conditions, following the DRY (Don't Repeat Yourself) principle.

### Design Goals

1. **Code reuse** - Eliminates roughly 170 lines of duplicated code
2. **Unified interface** - Provides a consistent variable operation API
3. **Easy maintenance** - Centralizes variable operation logic
4. **Type safety** - Uses enums instead of strings to represent scopes
5. **Performance** - Static methods, no instantiation overhead

### Core Value

| Problem | Solution | Effect |
|------|---------|------|
| Code duplication | Unified utility class | Removes ~170 lines of duplicated code |
| Hard to maintain | Centralized management | Change in one place, takes effect everywhere |
| Complex testing | Independent testing | Higher test coverage |
| Poor extensibility | Standardized API | New components integrate easily |

---

## Three-Layer Variable System

### Architecture Overview

```
┌─────────────────────────────────────────────────┐
│           VariableOperations (Utility Class)     │
│    Unified interface + scope container lookup    │
└─────────────────────────────────────────────────┘
                    │
        ┌───────────┼───────────┐
        │           │           │
        ▼           ▼           ▼
    LOCAL       SCOPE       GLOBAL
   (Local)     (Scope)     (Global)
        │           │           │
        │      ScopeVariable   GlobalVariable
        │      Container       Assistant
        ▼           ▼           ▼
 ExecutionContext  Scene tree  App singleton
```

### Variable Layer Reference

| Scope | Enum Value | Storage Location | Lifecycle | Typical Use |
|-------|--------|---------|---------|---------|
| **LOCAL** | `VariableScope.LOCAL` (0) | `ExecutionContext.local_variables` | Single event execution | Temporary variables, loop counters |
| **SCOPE** | `VariableScope.SCOPE` (1) | `ScopeVariableContainer` | Scene tree scope | Area state, level variables |
| **GLOBAL** | `VariableScope.GLOBAL` (2) | `GlobalVariableAssistant` | Application-wide | Game settings, player data |

---

## Core API

### 1. Reading Variables

```gdscript
static func get_variable(
    context: ExecutionContext,
    variable_name: String,
    scope: BaseVariable.VariableScope,
    default_value: Variant = null
) -> Variant
```

**Purpose:** Get a variable value from the specified scope

**Parameters:**
- `context`: Execution context
- `variable_name`: Variable name
- `scope`: Variable scope (LOCAL/SCOPE/GLOBAL)
- `default_value`: Default value (returned when the variable does not exist)

**Returns:** The variable value, or the default value if not found

**Behavior details:**
- LOCAL: reads from `ExecutionContext.local_variables`
- SCOPE: reads from the nearest `ScopeVariableContainer`
- GLOBAL: reads from `GlobalVariableAssistant`

**Example:**

```gdscript
# Read a local variable
var score = VariableOperations.get_variable(
    context,
    "score",
    BaseVariable.VariableScope.LOCAL,
    0
)

# Read a scope variable (with default value)
var health = VariableOperations.get_variable(
    context,
    "player_health",
    BaseVariable.VariableScope.SCOPE,
    100  # default value
)
```

---

### 2. Setting Variables

```gdscript
static func set_variable(
    context: ExecutionContext,
    variable_name: String,
    scope: BaseVariable.VariableScope,
    value: Variant
) -> bool
```

**Purpose:** Set a variable value in the specified scope

**Parameters:**
- `context`: Execution context
- `variable_name`: Variable name
- `scope`: Variable scope
- `value`: The value to set

**Returns:** `true` on success, `false` on failure

**Behavior details:**
- LOCAL: sets into `ExecutionContext.local_variables`
- SCOPE: sets into the nearest `ScopeVariableContainer`, falls back to LOCAL on failure
- GLOBAL: sets into `GlobalVariableAssistant`, creates the variable if it does not exist

**Error handling:**
- Returns `false` when parameter validation fails
- Logs debug messages to `FuseLogger`

**Example:**

```gdscript
# Set a local variable
var success = VariableOperations.set_variable(
    context,
    "current_level",
    BaseVariable.VariableScope.LOCAL,
    5
)

# Set a scope variable
success = VariableOperations.set_variable(
    context,
    "checkpoint_reached",
    BaseVariable.VariableScope.SCOPE,
    true
)
```

---

### 3. Checking Variables

```gdscript
static func has_variable(
    context: ExecutionContext,
    variable_name: String,
    scope: BaseVariable.VariableScope
) -> bool
```

**Purpose:** Check whether a variable exists

**Parameters:**
- `context`: Execution context
- `variable_name`: Variable name
- `scope`: Variable scope

**Returns:** `true` if the variable exists, `false` otherwise

**Use cases:**
- Validate a variable before evaluating a condition
- Avoid using unreasonable default values
- Make subsequent operations safe

**Example:**

```gdscript
# Check whether a global variable exists
if VariableOperations.has_variable(
    context,
    "game_initialized",
    BaseVariable.VariableScope.GLOBAL
):
    # Run initialization logic
    pass
```

---

### 4. Finding the Scope Container

```gdscript
static func get_scope_container(
    context: ExecutionContext,
    search_node: Node = null
) -> ScopeVariableContainer
```

**Purpose:** Find the nearest `ScopeVariableContainer`

**Parameters:**
- `context`: Execution context
- `search_node`: Node where the search starts (`context.trigger` is used when `null`)

**Returns:** The found container instance, or `null` if not found

**Lookup strategy:**
1. Determine the search start (`search_node` or `context.trigger`)
2. Walk up the scene tree using `ScopeVariableManager.find_nearest_scope()`
3. Return the first `ScopeVariableContainer` found

**Error handling:**
- Returns `null` if `context` is `null`
- Returns `null` if the search node is `null`
- Returns `null` if `ScopeVariableManager` is not initialized

**Example:**

```gdscript
# Use the default search start (context.trigger)
var container = VariableOperations.get_scope_container(context)
if container != null:
    print("Found scope: " + container.scope_id)

# Specify the search node
var target_node = get_node("Level/Checkpoint")
var checkpoint_scope = VariableOperations.get_scope_container(context, target_node)
```

---

## Private Helper Methods

### _get_local_variable()

```gdscript
static func _get_local_variable(
    context: ExecutionContext,
    variable_name: String,
    default_value: Variant
) -> Variant
```

**Responsibility:** Read a local variable from the execution context

**Implementation:** Calls `context.has_variable()` and `context.get_variable()`

---

### _get_scope_variable()

```gdscript
static func _get_scope_variable(
    context: ExecutionContext,
    variable_name: String,
    default_value: Variant
) -> Variant
```

**Responsibility:** Read a variable from the scope container

**Implementation:**
1. Call `get_scope_container()` to find the container
2. Call the container's `has_variable()` and `get_variable()`
3. Log debug details (scope ID, variable name, value)

**Error handling:** Returns the default value when the container is `null`

---

### _get_global_variable()

```gdscript
static func _get_global_variable(
    context: ExecutionContext,
    variable_name: String,
    default_value: Variant
) -> Variant
```

**Responsibility:** Read a variable from the global variable assistant

**Implementation:**
1. Get the `GlobalVariableAssistant` singleton
2. Call `get_global_variable()` to get the variable object
3. Call the variable's `get_value()` method

**Error handling:** Returns the default value when the assistant is `null` or the variable does not exist

---

### _set_local_variable()

```gdscript
static func _set_local_variable(
    context: ExecutionContext,
    variable_name: String,
    value: Variant
) -> bool
```

**Responsibility:** Set a local variable

**Implementation:** Directly calls `context.set_variable(variable_name, value, "local")`

---

### _set_scope_variable()

```gdscript
static func _set_scope_variable(
    context: ExecutionContext,
    variable_name: String,
    value: Variant
) -> bool
```

**Responsibility:** Set a scope variable

**Implementation:**
1. Find the scope container
2. Call the container's `set_variable()` method
3. Fall back to `_set_local_variable()` on failure

**Fallback behavior:** Automatically degrades to LOCAL when the scope container does not exist

---

### _set_global_variable()

```gdscript
static func _set_global_variable(
    context: ExecutionContext,
    variable_name: String,
    value: Variant
) -> bool
```

**Responsibility:** Set a global variable

**Implementation:**
1. Get the `GlobalVariableAssistant` singleton
2. Check whether the variable exists
   - Exists: call the variable's `set_value()` method
   - Does not exist: create a new variable and add it to the assistant

**Automatic creation:** When the variable does not exist, automatically creates it via `BaseVariable.create()`

---

## Logging System

### Logging Methods

```gdscript
static func _log_debug(message: String)
static func _log_info(message: String)
static func _log_warning(message: String)
static func _log_error(message: String)
```

**Implementation:** Calls the corresponding `FuseLogger` methods

**Component identifier:** Uses `"VariableOperations"` as the log component name

**Log levels:**
- `DEBUG`: variable lookups, read details
- `INFO`: successful variable writes
- `WARNING`: non-fatal errors (fallback operations)
- `ERROR`: severe errors (invalid parameters, uninitialized singleton)

---

## Usage Guide

### Basic Usage

#### 1. Reading Variables

```gdscript
# Read a local variable (with default value)
var score = VariableOperations.get_variable(
    context,
    "score",
    BaseVariable.VariableScope.LOCAL,
    0  # default value
)

# Read a scope variable
var health = VariableOperations.get_variable(
    context,
    "player_health",
    BaseVariable.VariableScope.SCOPE,
    100
)

# Read a global variable
var level = VariableOperations.get_variable(
    context,
    "current_level",
    BaseVariable.VariableScope.GLOBAL,
    1
)
```

#### 2. Setting Variables

```gdscript
# Set a local variable
var success = VariableOperations.set_variable(
    context,
    "current_wave",
    BaseVariable.VariableScope.LOCAL,
    5
)

# Set a scope variable (container found automatically)
success = VariableOperations.set_variable(
    context,
    "boss_defeated",
    BaseVariable.VariableScope.SCOPE,
    true
)

# Set a global variable (created if missing)
success = VariableOperations.set_variable(
    context,
    "total_play_time",
    BaseVariable.VariableScope.GLOBAL,
    3600.0
)
```

#### 3. Checking Variable Existence

```gdscript
# Validate before access
if VariableOperations.has_variable(
    context,
    "player_inventory",
    BaseVariable.VariableScope.SCOPE
):
    var inventory = VariableOperations.get_variable(
        context,
        "player_inventory",
        BaseVariable.VariableScope.SCOPE,
        null
    )
    # Process the inventory data
```

#### 4. Finding the Scope Container

```gdscript
# Search from context.trigger by default
var container = VariableOperations.get_scope_container(context)
if container != null:
    print("Scope ID: " + container.scope_id)
    print("Variables: " + str(container.list_variables()))

# Specify the search start
var custom_node = get_node("Level/Room1")
var room_scope = VariableOperations.get_scope_container(context, custom_node)
```

---

### Using in Instructions

#### SetScopeVariable Instruction Example

```gdscript
# Without the utility class (old code)
func execute(context: ExecutionContext):
    var scope_container = _get_scope_container(context)  # duplicated code
    if scope_container == null:
        # Error handling
        return
    scope_container.set_variable(variable_name, new_value)

# With the utility class (new code)
func execute(context: ExecutionContext):
    var scope_container = VariableOperations.get_scope_container(context)
    if scope_container == null:
        # Error handling
        return
    scope_container.set_variable(variable_name, new_value)
```

#### CheckVariable Condition Example

```gdscript
# Without the utility class (old code)
func _get_variable_value(context: ExecutionContext) -> Variant:
    match variable_scope:
        BaseVariable.VariableScope.LOCAL:
            return context.get_variable(variable_name, null)
        BaseVariable.VariableScope.SCOPE:
            var container = _get_scope_container(context)  # duplicated code
            # ... more logic
        BaseVariable.VariableScope.GLOBAL:
            var assistant = GlobalVariableAssistant.get_instance()
            # ... more logic

# With the utility class (new code)
func _get_variable_value(context: ExecutionContext) -> Variant:
    return VariableOperations.get_variable(
        context,
        variable_name,
        variable_scope,
        null
    )
```

---

## Cooperation with Other Utility Classes

### VariableScopeUtils

| Class | Responsibility | Typical Methods |
|---|---|---|
| `VariableScopeUtils` | Enum/string conversion | `enum_to_string()`, `string_to_enum()` |
| `VariableOperations` | Variable operations (read/write/check) | `get_variable()`, `set_variable()` |

**Collaboration example:**

```gdscript
# VariableScopeUtils for data serialization
var scope_str = VariableScopeUtils.enum_to_string(variable_scope)
save_data["scope"] = scope_str

# VariableOperations for runtime operations
var value = VariableOperations.get_variable(
    context,
    var_name,
    variable_scope,
    default_value
)
```

### ScopeVariableManager

```gdscript
# VariableOperations uses ScopeVariableManager internally to find containers
static func get_scope_container(
    context: ExecutionContext,
    search_node: Node = null
) -> ScopeVariableContainer:
    var manager = ScopeVariableManager.get_instance()
    if manager == null:
        return null

    return manager.find_nearest_scope(node)
```

### GlobalVariableAssistant

```gdscript
# VariableOperations uses GlobalVariableAssistant internally to operate on global variables
static func _get_global_variable(...) -> Variant:
    var assistant = GlobalVariableAssistant.get_instance()
    if assistant == null:
        return default_value

    var variable = assistant.get_global_variable(variable_name)
    if variable != null:
        return variable.get_value()

    return default_value
```

---

## Performance Considerations

### Static Method Advantages

- **No instantiation overhead** - All methods are static, no `new` needed
- **Stateless** - Keeps no internal state, thread-safe
- **Compiler friendly** - Static calls are easier to inline and optimize

### Caching Strategy

| Layer | Caching Mechanism | Description |
|------|---------|------|
| LOCAL | ExecutionContext internal cache | Repeated reads have no extra cost |
| SCOPE | ScopeVariableManager container cache | Node tree lookups are cached |
| GLOBAL | GlobalVariableAssistant singleton | The singleton pattern caches naturally |

### Performance Benchmarks

| Operation | Expected Time | Description |
|------|---------|------|
| LOCAL read | ~0.001 ms | Dictionary lookup |
| SCOPE read (cache hit) | ~0.01 ms | Container cache |
| SCOPE read (cache miss) | ~0.5-1 ms | Scene tree traversal |
| GLOBAL read | ~0.01 ms | Singleton dictionary lookup |

**Optimization tips:**
- Prefer LOCAL variables (fastest)
- Avoid reading SCOPE variables in hot loops (unless the cache hits)
- GLOBAL variables suit configuration data, not high-frequency reads/writes

---

## Error Handling

### Parameter Validation

```gdscript
# 1. ExecutionContext validation
if context == null:
    _log_error("ExecutionContext 为空")
    return default_value  # or return false

# 2. Variable name validation
if variable_name.is_empty():
    _log_error("变量名为空")
    return default_value  # or return false

# 3. Scope validation (match default branch)
match scope:
    BaseVariable.VariableScope.LOCAL:
        # ...
    BaseVariable.VariableScope.SCOPE:
        # ...
    BaseVariable.VariableScope.GLOBAL:
        # ...
    _:
        _log_error("未知的作用域类型: %s" % scope)
        return default_value  # or return false
```

### Fallback Mechanisms

| Scenario | Handling Strategy |
|------|---------|
| Scope container not found | Log a warning, return the default value |
| Global variable assistant not initialized | Log an error, return the default value |
| Setting a variable fails | Log an error, return `false` |
| Reading a variable fails | Return the default value |

### Log Levels

```gdscript
# DEBUG: detailed operation information
_log_debug("从作用域 '%s' 获取变量 %s = %s" % [scope_id, var_name, value])

# INFO: important operation succeeded
_log_info("在作用域 '%s' 设置变量 %s = %s" % [scope_id, var_name, value])

# WARNING: recoverable error
_log_warning("未找到作用域容器，回退到局部变量: %s" % var_name)

# ERROR: severe error
_log_error("GlobalVariableAssistant 实例为空")
```

---

## Testing Guide

### Unit Test Structure

Test file: `tests/unit/test_variable_operations.gd`

**Test coverage:**
1. ✅ LOCAL variable reads/writes
2. ✅ SCOPE variable reads/writes
3. ✅ GLOBAL variable reads/writes
4. ✅ Default value handling
5. ✅ Variable existence checks
6. ✅ Empty variable name handling
7. ✅ null context handling
8. ✅ Scope container lookup
9. ✅ Scope container lookup failure

### Test Examples

```gdscript
## Test reading a LOCAL variable
func test_get_local_variable():
    test_context.set_variable("test_var", 42, "local")

    var value = VariableOperations.get_variable(
        test_context,
        "test_var",
        BaseVariable.VariableScope.LOCAL,
        0
    )

    assert_eq(value, 42, "应该读取到局部变量值")

## Test setting a SCOPE variable
func test_set_scope_variable():
    var success = VariableOperations.set_variable(
        test_context,
        "new_scope_var",
        BaseVariable.VariableScope.SCOPE,
        200
    )

    assert_true(success, "设置作用域变量应该成功")
    assert_eq(
        test_scope_container.get_variable("new_scope_var", 0),
        200,
        "值应该正确"
    )

## Test that the default value is returned when the variable does not exist
func test_get_variable_default_value():
    var value = VariableOperations.get_variable(
        test_context,
        "non_existent_var",
        BaseVariable.VariableScope.LOCAL,
        -1
    )

    assert_eq(value, -1, "应该返回默认值")
```

### Running the Tests

```bash
# In the Godot editor
1. Open the test scene: tests/unit/test_variable_operations.tscn
2. Press F5 to run the tests
3. Check the GUT test results panel
```

---

## Extension Guide

### Adding New Methods

If you need to add a new variable operation method:

**Steps:**

1. **Define the method's responsibility**
   - Does it belong in the public API?
   - Will it be used in multiple places?
   - Does it duplicate an existing method?

2. **Design the method signature**
   ```gdscript
   static func new_operation(
       context: ExecutionContext,
       variable_name: String,
       scope: BaseVariable.VariableScope,
       # other parameters
   ) -> Variant:
       pass
   ```

3. **Implement the logic**
   - Parameter validation
   - Scope matching
   - Call the private helper methods
   - Error handling and logging

4. **Write unit tests**
   ```gdscript
   func test_new_operation():
       # Test the normal case
       # Test edge cases
       # Test error cases
   ```

5. **Update the documentation**
   - Add a description of the new method to this document
   - Include parameters, return values, and examples

**Example: adding a variable deletion method**

```gdscript
## Delete a variable
static func delete_variable(
    context: ExecutionContext,
    variable_name: String,
    scope: BaseVariable.VariableScope
) -> bool:
    if context == null or variable_name.is_empty():
        _log_error("无效参数")
        return false

    match scope:
        BaseVariable.VariableScope.LOCAL:
            # Implement deletion logic
            pass
        BaseVariable.VariableScope.SCOPE:
            # Implement deletion logic
            pass
        BaseVariable.VariableScope.GLOBAL:
            # Implement deletion logic
            pass
        _:
            _log_error("未知作用域")
            return false

    return true
```

---

## Frequently Asked Questions (FAQ)

### Q1: Why a static class instead of a singleton?

**A:** A static class fits utility methods better:
- Stateless and thread-safe
- No instantiation overhead
- In Godot, singletons require registration (`register_singleton()`), while static classes can be used directly

### Q2: When should the default value parameter be used?

**A:**
- **Read operations**: always provide a default value (avoids errors caused by `null`)
- **Write operations**: no default value needed (failures return `false`)
- **Check operations**: no default value needed (returns a boolean)

### Q3: Why does a failed SCOPE write fall back to LOCAL?

**A:** The fault-tolerance strategy:
- The scope container may not exist (scene tree structure changes)
- Falling back to LOCAL ensures the variable is still set
- A warning is logged for easier debugging

### Q4: How do I debug variable lookup issues?

**A:** Enable debug logging:
```gdscript
# Enable the DEBUG level in FuseLogger
# Check VariableOperations' log output
# The logs show the lookup path, scope ID, variable values, etc.
```

### Q5: How do I optimize for performance-sensitive scenarios?

**A:**
1. Prefer LOCAL variables
2. Cache the SCOPE container reference (avoid repeated lookups)
3. Reduce variable reads inside hot loops
4. Consider using `@export_storage` to cache variable values

---

## Best Practices

### DO (Recommended)

```gdscript
# ✅ Always provide a default value
var value = VariableOperations.get_variable(
    context,
    "score",
    BaseVariable.VariableScope.LOCAL,
    0  # explicit default value
)

# ✅ Check the return value
var success = VariableOperations.set_variable(...)
if not success:
    _log_error("设置失败")

# ✅ Use enums instead of strings
scope = BaseVariable.VariableScope.SCOPE  # ✅
scope_str = "scope"  # ❌ (unless used for serialization)
```

### DON'T (Not Recommended)

```gdscript
# ❌ No default value provided
var value = VariableOperations.get_variable(
    context,
    "score",
    BaseVariable.VariableScope.LOCAL
    # missing default value, may return null
)

# ❌ Return value not checked
VariableOperations.set_variable(...)  # failures go unnoticed

# ❌ Hard-coded scope values
scope = 1  # magic number, hard to understand
```

---

## Related Documentation

### System Design
- [Variable System Design](../../system_docs/architecture/variable_system_design.md)
- [Execution Context Analysis](../../system_docs/analysis/execution_context_analysis.md)
- [BaseVariable Analysis](../../system_docs/analysis/base_variable_analysis.md)

### Instructions and Conditions
- [SetScopeVariable Instruction](../../../../instructions/variables/set_scope_variable.gd)
- [GetScopeVariable Instruction](../../../../instructions/variables/get_scope_variable.gd)
- [CheckVariable Condition](../../../../conditions/variable/check_variable.gd)

---

## Version History

| Version | Date | Change |
|------|------|------|
| 1.0.0 | 2025-02-09 | Initial version with the complete variable operation API |

---

## Maintainers

- Creator: Claude (AI Assistant)
- Reviewers: Project team
- Last updated: 2025-02-09

---

**Doc status:** ✅ Complete
**Code status:** 🚧 In development (Phase 1 complete; later phases pending)
**Test status:** ⏳ To be written
