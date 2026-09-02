> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/24-math-vector-guide.md) | English

# Math/Vector Instructions Usage Guide

The Fuse math/vector system provides 6 numeric computation instructions, covering basic arithmetic, linear interpolation, range clamping, vector operations, random number generation, and random point generation. For the expression instructions (MathExpression, StringExpression), see the [Expression System Usage Guide](05-expression-guide.md).

## Instruction List

| Name | Description | Key parameters |
|------|----------|----------|
| **MathOperation** | Basic arithmetic | `operation_type` (operation type), `operand_a`/`operand_b` (operands; direct value or variable), `save_to_variable` (result variable) |
| **Lerp** | Linear interpolation | `from`/`to` (interpolation endpoints; direct value or variable), `weight` (interpolation weight 0.0-1.0), `save_to_variable` |
| **ClampValue** | Value range clamping | `value` (input value; direct value or variable), `min_value`/`max_value` (range), `save_to_variable` |
| **VectorOperation** | Vector operations | `operation_type` (operation type), `vector_type` (VECTOR2/VECTOR3), `operand_a`/`operand_b` (operands), `save_to_variable` |
| **RandomNumber** | Generates a random number | `min_value`/`max_value` (range), `is_integer` (whether the result is an integer), `save_to_variable` |
| **GetRandomPointInRange** | Gets a random point within a range | `dimension_mode` (2D/3D), `origin` (origin), `range` (range radius), `plane_3d` (3D plane type), `save_to_variable` |

---

## MathOperation

Performs basic math operations; operands can be read from direct values or variables.

**Category:** Math | **Icon:** Variant

### Operation Types

| Operation | Description | Example |
|------|------|------|
| ADD | Addition | 10 + 5 = 15 |
| SUBTRACT | Subtraction | 10 - 5 = 5 |
| MULTIPLY | Multiplication | 10 * 5 = 50 |
| DIVIDE | Division | 10 / 5 = 2 |
| MODULO | Modulo | 10 % 3 = 1 |

### Operand Sources

Both operands support two source modes:

| Mode | Description |
|------|------|
| VALUE | Enter a number directly |
| VARIABLE | Read from a variable (supports the Local/Scope/Global scopes) |

### Usage Examples

```
# Damage calculation: attack - defense
MathOperation → SUBTRACT
  operand_a: VALUE (20)
  operand_b: VARIABLE (defense, Local)
  save_to: damage (Local)

# Double the experience
MathOperation → MULTIPLY
  operand_a: VARIABLE (exp, Local)
  operand_b: VALUE (2)
  save_to: new_exp (Local)
```

---

## Lerp

Performs linear interpolation between two values.

**Category:** Math | **Icon:** Variant

### Parameters

| Parameter | Description |
|------|------|
| `from` | Start value (supports VALUE or VARIABLE) |
| `to` | Target value (supports VALUE or VARIABLE) |
| `weight` | Interpolation weight (0.0 = start value, 1.0 = target value) |

### Formula

```
result = from + (to - from) * weight
```

### Usage Examples

```
# Smooth health display (transition from the displayed value to the actual value)
Lerp → from: VARIABLE (display_hp), to: VARIABLE (actual_hp), weight: 0.1
  save_to: display_hp (Local)

# Color interpolation
Lerp → from: 0.0, to: 1.0, weight: VARIABLE (progress)
  save_to: alpha (Local)
```

---

## ClampValue

Clamps a value to the specified range.

**Category:** Math | **Icon:** Variant

### Parameters

| Parameter | Description |
|------|------|
| `value` | Input value (supports VALUE or VARIABLE) |
| `min_value` | Minimum value |
| `max_value` | Maximum value |

### Formula

```
result = min(max(value, min_value), max_value)
```

### Usage Examples

```
# Clamp health so it never exceeds the cap
ClampValue → value: VARIABLE (hp), min_value: 0, max_value: 100
  save_to: hp (Local)

# Clamp volume to between 0 and 1
ClampValue → value: VARIABLE (volume_input), min_value: 0.0, max_value: 1.0
  save_to: volume (Local)
```

---

## VectorOperation

Performs vector math operations; supports Vector2 and Vector3.

**Category:** Math | **Icon:** Vector3

### Operation Types

| Operation | Operands | Description | Result type |
|------|--------|------|----------|
| VECTOR_ADD | A + B | Vector addition | Vector |
| VECTOR_SUBTRACT | A - B | Vector subtraction | Vector |
| SCALE | A * scalar | Vector scaling (B is a scalar) | Vector |
| NORMALIZE | normalize(A) | Normalization | Vector |
| LENGTH | length(A) | Vector length | Float |
| DISTANCE | distance(A, B) | Distance between two points | Float |

### Vector Types

| Type | Description | Typical use |
|------|------|----------|
| VECTOR2 | 2D vector (x, y) | 2D games |
| VECTOR3 | 3D vector (x, y, z) | 3D games |

Operands likewise support both the VALUE (direct input) and VARIABLE (read from variable) modes.

### Usage Examples

```
# Compute the direction to the enemy
VectorOperation → VECTOR_SUBTRACT (Vector2)
  operand_a: VARIABLE (enemy_pos)
  operand_b: VARIABLE (player_pos)
  save_to: direction (Local)

# Get the movement direction (normalized)
VectorOperation → NORMALIZE (Vector2)
  operand_a: VARIABLE (move_input)
  save_to: move_dir (Local)

# Compute the distance to the target
VectorOperation → DISTANCE (Vector2)
  operand_a: VARIABLE (player_pos)
  operand_b: VARIABLE (target_pos)
  save_to: distance (Local)

# Scale the movement speed
VectorOperation → SCALE (Vector2)
  operand_a: VARIABLE (direction)
  operand_b: VALUE (5.0)
  save_to: velocity (Local)
```

---

## RandomNumber

Generates a random number within the specified range.

**Category:** Math | **Icon:** Variant

### Parameters

| Parameter | Description |
|------|------|
| `min_value` | Minimum value |
| `max_value` | Maximum value |
| `is_integer` | Whether to return an integer |
| `save_to_variable` | Result variable name |
| `save_to_scope` | Save scope (Local/Scope/Global) |

### Usage Examples

```
# Generate a random integer in 1-6 (dice)
RandomNumber → [1, 6], is_integer: true
  save_to: dice_roll (Local)

# Generate a random float in 0.0-1.0
RandomNumber → [0.0, 1.0], is_integer: false
  save_to: random_factor (Local)

# Random critical damage multiplier
RandomNumber → [1.5, 3.0], is_integer: false
  save_to: crit_multiplier (Local)
```

---

## GetRandomPointInRange

Gets a random position within range of a specified origin; supports 2D and 3D.

**Category:** Math | **Icon:** Vector3i

### Parameters

| Parameter | Description |
|------|------|
| `dimension_mode` | 2D or 3D |
| `plane_3d` | 3D plane type (3D mode only) |
| `origin_mode` | Origin source (Direct / Variable) |
| `origin` | Origin coordinates |
| `range_mode` | Range source (Direct / Variable) |
| `range` | Range per axis (the actual range is -range to +range) |
| `save_to_variable` | Result variable name |

### 3D Plane Types

| Plane | Description | Fixed axis |
|------|------|--------|
| XY | Horizontal plane | Z |
| XZ | Ground | Y |
| YZ | Side plane | X |
| Full 3D | Full 3D space | None |

### Usage Examples

```
# Generate a random position within 200 px of the player (2D)
GetRandomPointInRange → 2D
  origin: Direct (player_position)
  range: Direct (200, 200)
  save_to: spawn_pos (Local)

# Spawn an enemy at a random ground position (3D)
GetRandomPointInRange → 3D [XZ]
  origin: Direct (0, 10, 0)
  range: Direct (500, 0, 500)
  save_to: enemy_spawn_pos (Local)

# Get the random range from variables
GetRandomPointInRange → 2D
  origin: Variable (center_pos, Local)
  range: Variable (spawn_radius, Local)
  save_to: drop_pos (Local)
```

---

## Scope Notes

Result saving in all math instructions supports three scopes:

| Scope | Description |
|--------|------|
| **Local** | Local variables on the ExecutionContext; valid within the current instruction chain |
| **Scope** | Scope variables on the VariableScopeContainer; shared across nodes |
| **Global** | Global variables; valid for the entire game runtime |

When Scope is selected, `scope_source` must also be configured to specify which scope container to read from and write to:

| ScopeSource | Description |
|-------------|------|
| Nearest | The nearest scope container (default) |
| Custom ID | A specified scope_id |
| Trigger Scope | The scope on the Trigger node |
| Target Node | The scope on the target node path |

---

## Common Use Cases

### 1. Damage Calculation

```
# Final damage = (attack - defense) * crit multiplier
MathOperation → SUBTRACT
  operand_a: VALUE (attack), operand_b: VARIABLE (defense)
  save_to: base_damage

# Random crit roll
RandomNumber → [0.0, 1.0], is_integer: false
  save_to: crit_roll

# Crit multiplier selection (using MathExpression)
MathExpression → {local:crit_roll} < {local:crit_chance} ? 2.0 : 1.0
  save_to: multiplier

# Final damage
MathOperation → MULTIPLY
  operand_a: VARIABLE (base_damage), operand_b: VARIABLE (multiplier)
  save_to: final_damage

# Clamp minimum damage to 1
ClampValue → value: VARIABLE (final_damage), min: 1, max: 9999
  save_to: final_damage
```

### 2. Random Drop Position

```
# Drop an item at a random position near the kill location
GetRandomPointInRange → 2D
  origin_mode: Variable
  origin: kill_position (Local)
  range_mode: Direct
  range: (30, 30)
  save_to: drop_position (Local)

# Instantiate the drop at the random position
AddSceneAsChild → scene: "res://scenes/item_drop.tscn"
  parent: ItemContainer
```

### 3. Smooth Camera Follow

```
# Interpolate the camera position toward the target each frame
Lerp → from: VARIABLE (camera_pos), to: VARIABLE (target_pos), weight: 0.1
  save_to: camera_pos

SetPosition → target: Camera, position: VARIABLE (camera_pos)
```

### 4. Compute the Enemy-Player Distance

```
# Get the enemy position
GetPosition → target: Enemy
  save_to: enemy_pos (Local)

# Get the player position
GetPosition → target: Player
  save_to: player_pos (Local)

# Compute the distance
VectorOperation → DISTANCE (Vector2)
  operand_a: VARIABLE (enemy_pos)
  operand_b: VARIABLE (player_pos)
  save_to: distance (Local)

# Check whether the target is within attack range
ClampValue → value: VARIABLE (distance), min: 0, max: 100
  # If distance > 100 it is clamped to 100; Clamp can be used to check the range
```

---

## Notes

- **Division by zero**: MathOperation's DIVIDE raises an error when the divisor is 0; it is recommended to use ClampValue to ensure the divisor is not 0, or to use MathExpression's ternary `{local:b} != 0 ? {local:a} / {local:b} : 0`
- **Type matching**: VectorOperation's two operands must have the same type (both Vector2 or both Vector3), and the vector type parameter must match the actual data
- **Variable existence**: when reading operands from variables, make sure the variables are initialized; a missing variable causes a runtime error
- **Random seed**: RandomNumber and GetRandomPointInRange use Godot's global random number generator, which is automatically randomized at game startup
- **Expression alternative**: for complex computation (nested formulas, multiple variables), prefer MathExpression over chaining multiple MathOperation instructions

---

**Related docs:**
- [Expression System Usage Guide](05-expression-guide.md) - MathExpression, StringExpression, ExpressionCondition
- [Transform System Usage Guide](10-transform-guide.md) - SetPosition, MoveBy, LookAt and other node transform instructions
