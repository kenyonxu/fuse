> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/05-expression-guide.md) | English

# Expression System Usage Guide

Fuse provides three expression components built on the Godot `Expression` engine, covering math computation, string handling, and condition evaluation.

## Component Overview

| Component | Type | Purpose | Output |
|------|------|------|------|
| MathExpression | Instruction | Math computation | Float / Int / Vector2 / Vector3 |
| StringExpression | Instruction | String concatenation and formatting | String |
| ExpressionCondition | Condition | Boolean expression evaluation | bool |

## Variable Reference Syntax

The three components share the same variable reference syntax and support three scopes:

```
{local:variable_name}     - local variables (variables on the ExecutionContext)
{scope:variable_name}     - scope variables (variables on the VariableScopeContainer)
{global:variable_name}    - global variables
```

Variable name rules: must start with a letter or underscore, and may only contain letters, digits, and underscores.

> Tip: when a parameter only needs to **reference** a variable without computing anything, you don't need an expression—the dual-track variable binding of instruction parameters is more direct; see the [Variable Binding Usage Guide](07-variable-binding-guide.md).

```
# Valid
{local:hp}  {scope:player_name}  {global:max_count}  {local:_temp}

# Invalid
{local:123}  {scope:player-name}  {global:player name}
```

Variables that cannot be found are replaced with `0` in math contexts; no error is raised.

## Scope Source Configuration

When `{scope:xxx}` is used in an expression, you must specify which scope container the variable is read from. Choose via the `scope_source` property:

| Value | Description |
|----|------|
| Nearest | The nearest scope container (default) |
| Custom ID | A specified scope_id |
| Trigger Scope | The scope on the Trigger node |
| Target Node | The scope on the target node path |

When Custom ID is selected you must fill in `custom_scope_id`; when Target Node is selected you must fill in `target_node_path`.

---

## MathExpression

A math expression instruction that performs math operations and saves the result to a variable.

**File:** [math_expression.gd](../../../../instructions/math/math_expression.gd)
**Category:** Math
**Icon:** Code

### Basic Usage

```
Expression: {local:hp} + {local:heal_amount}
Output type: Float
Save to variable: hp
Save to scope: Local
```

### Output Types

| Type | Description | Example |
|------|------|------|
| Float | Floating point (default) | 3.14 |
| Int | Integer (decimals truncated) | 42 |
| Vector2 | 2D vector | vec2(1, 2) |
| Vector3 | 3D vector | vec3(1, 2, 3) |

Type conversion rules:
- Float → Int: direct truncation (3.9 → 3)
- Vector3 → Vector2: takes the x, y components
- Number → Vector2: converted to (value, 0)
- Number → Vector3: converted to (value, 0, 0)

### Operators

```
# Arithmetic
{local:a} + {local:b}        # add
{local:a} - {local:b}        # subtract
{local:a} * {local:b}        # multiply
{local:a} / {local:b}        # divide
{local:a} % {local:b}        # modulo

# Parenthesis precedence
({local:a} + {local:b}) * {local:c}
```

### Available Functions

**Godot built-ins:**

```
abs(-5)           # absolute value → 5.0
min(3, 7)         # minimum → 3.0
max(3, 7)         # maximum → 7.0
round(3.6)        # round half up → 4.0
floor(3.6)        # round down → 3.0
ceil(3.2)         # round up → 4.0
sqrt(16)          # square root → 4.0
pow(2, 3)         # power → 8.0
clamp(5, 0, 10)   # range clamp → 5.0
sin(0)            # sine (radians)
cos(0)            # cosine
tan(0)            # tangent
```

**Game extension functions:**

| Function | Description | Example |
|------|------|------|
| vec2(x, y) | Constructs a 2D vector | `vec2({local:x}, {local:y})` |
| vec3(x, y, z) | Constructs a 3D vector | `vec3(1, 2, 3)` |
| normalize(v) | Normalizes | `normalize({local:vel})` |
| distance(a, b) | Computes distance | `distance(vec2(0,0), {local:pos})` |
| direction(a, b) | Computes direction | `direction(vec2(0,0), {local:target})` |
| angle(a, b) | Computes angle (radians) | `angle(vec2(0,0), {local:pos})` |
| remap(v, a, b, c, d) | Remaps the value range | `remap({local:x}, 0, 100, 0, 1)` |
| inverse_lerp(a, b, v) | Inverse lerp | `inverse_lerp(0, 10, {local:hp})` |
| snap(v, step) | Snaps to a step | `snap({local:x}, 0.5)` |
| move_toward_val(from, to, delta) | Moves toward a target | `move_toward_val({local:val}, 100, 5)` |
| is_zero(v) | Whether close to zero | `is_zero({local:velocity})` |
| format_num(v, d) | Formats a number as a string | `format_num(3.14159, 2)` → "3.14" |
| pad_left(s, len, c) | Left padding | `pad_left("42", 6, "0")` → "000042" |
| pad_right(s, len, c) | Right padding | `pad_right("hi", 5, "!")` → "hi!!!" |

> `move_toward_val` uses the `_val` suffix because Godot Expression has a built-in `move_toward` function. The effect is the same, but it supports automatic type conversion.

### Practical Examples

```
# Damage computation
Expression: ({local:attack} - {local:defense}) * {local:multiplier}
Output type: Float
Save to variable: damage

# Map HP to the 0~1 range
Expression: remap({local:hp}, 0, {local:max_hp}, 0, 1)
Output type: Float
Save to variable: hp_ratio

# Compute the direction vector from the player to a target
Expression: direction(vec2(0, 0), vec2({local:tx}, {local:ty}))
Output type: Vector2
Save to variable: move_dir
```

### How Variable Types Are Handled in Math Contexts

MathExpression processes variable references in numeric mode:
- Numeric variables: used directly (`42` → `42`)
- Vector variables: converted to constructor calls (`Vector2(1,2)` → `vec2(1, 2)`)
- bool variables: converted to floats (`true` → `1`, `false` → `0`)
- String variables: parsed as floats (`"42"` → `42.0`, `"hello"` → `0.0`)

---

## StringExpression

A string expression instruction that concatenates and formats strings with expressions.

**File:** [string_expression.gd](../../../../instructions/math/string_expression.gd)
**Category:** Math
**Icon:** Code

### Basic Usage

```
Expression: "Hello" + " " + "World"
Save to variable: greeting
Save to scope: Local
```

### String Concatenation

```
# Basic concatenation
"Score: " + str({local:score})

# Multi-segment concatenation
"Player " + str({local:id}) + " - HP: " + str({local:hp}) + "/" + str({local:max_hp})
```

### Variable Interpolation

StringExpression processes variable references in string mode:
- String variables: kept as string literals (`"hello"` → `"hello"`)
- Numeric variables: kept in numeric form (`42` → `42`; needs `str()` to convert)
- bool variables: converted to true/false (`true` → `true`)
- Vector variables: converted to constructor calls (`Vector2(1,2)` → `vec2(1, 2)`)

```
# Numeric variables need str() conversion
"HP: " + str({local:hp})

# String variables can be used directly
{local:player_name} + " joined the game"

# bool variables
"is alive: " + str({local:hp} > 0)
```

### Ternary Operations

```
# Conditional text
{local:hp} > 0 ? "Alive" : "Dead"

# Tiered display
{local:score} > 90 ? "S" : ({local:score} > 70 ? "A" : "B")
```

### Formatting Functions

```
# Keep 2 decimal places
format_num({local:hp}, 2)
# hp=3.14159 → "3.14"

# Zero-pad a number
pad_left(str({local:level}), 3, "0")
# level=5 → "005"

# Right-align
pad_right({local:item_name}, 20, ".")
# item_name="剑" → "剑................"
```

### Practical Examples

```
# Build a damage popup
Expression: "-" + str({local:damage}) + " HP"
Save to variable: damage_text

# Build a progress bar
Expression: "[" + pad_left("", {local:percent}, "#") + pad_left("", 100 - {local:percent}, "-") + "] " + str({local:percent}) + "%"
Save to variable: progress_bar

# Build a status line
Expression: {local:name} + " | HP: " + str({local:hp}) + "/" + str({local:max_hp}) + " | " + ({local:alive} ? "ALIVE" : "DEAD")
Save to variable: status_text
```

### Automatic Conversion of Non-String Results

If the expression returns a non-string result (such as a number), `str()` is called automatically:

```
Expression: {local:a} + {local:b}
# a=10, b=20 → saved as the string "30"
```

---

## ExpressionCondition

An expression condition that evaluates conditions with a boolean expression.

**File:** [expression_condition.gd](../../../../conditions/math/expression_condition.gd)
**Category:** Math
**Icon:** Code

### Basic Usage

```
Expression: {local:hp} > 0
```

The condition passes when the expression evaluates to `true` and fails on `false`. A non-boolean result (such as a number or string) raises an error and returns false.

### Comparison Operators

```
{local:hp} > 0           # greater than
{local:hp} >= 100        # greater than or equal
{local:hp} < 0           # less than
{local:hp} <= 100        # less than or equal
{local:level} == 10      # equal
{local:state} != "dead"  # not equal
```

### Logical Operators

```
# AND
{local:hp} > 0 and {local:alive}

# OR
{local:has_key} or {local:has_pickaxe}

# NOT
not {local:is_cooling_down}

# Combined
{local:hp} > 0 and {local:mp} > 10 and not {local:stunned}
```

### Ternary Operations

The expression engine supports Godot's ternary syntax `a if b else c`:

```
# Return a boolean
1 if {local:hp} > 0 else 0

# Nested
1 if {local:hp} > 50 else (1 if {local:hp} > 0 else 0)
```

### Helper Functions

```
# Distance check
distance(vec2(0, 0), vec2({local:px}, {local:py})) < {local:range}

# Near-zero check
is_zero({local:velocity})

# Range check
{local:hp} >= {local:min_hp} and {local:hp} <= {local:max_hp}
```

### Practical Examples

```
# Death detection
Expression: {local:hp} <= 0

# Skill cooldown finished
Expression: {local:cooldown_timer} <= 0

# Enemy within attack range
Expression: distance(vec2({local:px}, {local:py}), vec2({local:tx}, {local:ty})) < {local:attack_range}

# Skill can be cast
Expression: {local:mp} >= {local:skill_cost} and not {local:silenced} and {local:cooldown} <= 0

# Inventory is full
Expression: {local:item_count} >= {local:max_slots}
```

### Result Type Requirement

The expression **must** return a boolean (`true` / `false`). The following raises an error:

```
# Wrong: returns a number
{local:hp} + {local:mp}       # returns a float

# Correct: returns a boolean
{local:hp} + {local:mp} > 0   # returns a bool
```

---

## Scope Output Configuration

MathExpression and StringExpression support saving the result to different scopes:

| Save to Scope | Description |
|-------------|------|
| Local | Saves to the ExecutionContext (default) |
| Scope | Saves to the scope container |
| Global | Saves to the global variables |

When Scope is selected, an additional `save_scope_source` option appears, used the same way as the read-side `scope_source`.

---

## FAQ

### Strings in Expressions Need Quotes

```
# In StringExpression
"Hello" + " " + "World"    # correct
Hello + " " + World        # wrong: Hello and World are treated as variable names

# In ExpressionCondition
{local:state} == "idle"    # correct
{local:state} == idle      # wrong: idle is treated as a variable name
```

### move_toward_val vs move_toward

`move_toward_val` is a game extension function that supports automatic type conversion (arguments are coerced to float). `move_toward` is a Godot Expression built-in. Both do the same thing; `move_toward_val` is recommended for better type compatibility.

### Missing Variables Do Not Interrupt Execution

If a referenced variable does not exist, it is replaced with `0` in math contexts and execution continues (with a warning logged). If you want to guarantee the variable exists, initialize it first with a SetVariable or CreateVariable instruction.

### Division by Zero

Division by zero in Godot Expression returns `inf` or `nan` without raising an error. Use `clamp` or a condition check to avoid it:

```
# Safe division
{local:b} != 0 ? {local:a} / {local:b} : 0
```
