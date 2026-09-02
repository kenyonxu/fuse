> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/10-transform-guide.md) | English

# Transform System Guide

## Concept Primer: Coordinate Systems

Fuse transform instructions support two coordinate spaces: **Global** and **Local**. Understanding the difference between the two is essential for controlling game objects correctly.

### Global Coordinates

**Global coordinates** are absolute coordinates relative to the **scene root node (world origin)**.

- **Absolute position**: not affected by parent nodes
- **World coordinates**: position directly in world space
- **Independence**: moving the parent node does not change the child's global coordinate values

**Best for:** teleport points, spawn points, world-space navigation, absolute position control

### Local Coordinates

**Local coordinates** are relative coordinates with respect to the **parent node**.

- **Relative position**: affected by the parent node's transform
- **Hierarchy following**: children follow when the parent moves
- **Inheritance**: inherits the parent's rotation and scale

**Best for:** weapon attachment points, UI layout, vehicle seats, relative position adjustments

### Comparison Example

```
World (0, 0, 0)
└─ Parent (10, 0, 0)
   └─ Child (local: 2, 0, 0)
```

| Type | Coordinate value | Description |
|------|------------------|-------------|
| **Local** | (2, 0, 0) | Offset relative to Parent |
| **Global** | (12, 0, 0) | Position relative to World |

**Move by +3 with Local:** Child Local (2→5), Child Global (12→15)
**Move to (20,0,0) with Global:** Child Global (12→20), Child Local (2→10)

### Practical Use Cases

| Use case | Recommended space | Description |
|----------|-------------------|-------------|
| Muzzle following the character | Local | Weapon attachment offset, follows automatically as the character moves |
| Coin flying toward the UI | Global | Move from any position to a fixed UI position |
| Player jump | Global | The physics system computes in world space |
| Vehicle seat | Local | Seat offset relative to the vehicle body, follows when the body moves |

### Common Pitfalls

1. **Coordinate confusion after rotation**: once the parent node rotates, the Local X axis ≠ the Global X axis. Be clear about whether the operation is relative to the object itself or to the world.
2. **Nested parent nodes**: with `Root → A → B → C`, C's Local is relative to B, not to A. Use Global when you need to be relative to a higher level.
3. **Mixing spaces**: mixing the two spaces on the same object may produce results that don't match expectations. Stay consistent.

### Coordinate Space Decision Tree

```
Need to move/rotate an object
├─ Positioning relative to another object? → Global
├─ Needs to follow a parent node? → Local
├─ UI layout? → Local
└─ World-space navigation? → Global
```

> **Rule of thumb**: Global for world positioning, Local for hierarchy following.

---

## Transform Instructions in Detail

The Fuse transform system provides 7 transform instructions covering the complete set of node transform operations — position setting, relative movement, rotation setting, relative rotation, scale setting, look-at targeting, and position retrieval. All components support both 2D and 3D nodes.

### Instruction List

| Name | Description | Key parameters |
|------|-------------|----------------|
| **SetPosition** | Set the node's absolute position | `target_node`, `position` (Vector3), `space` (Global/Local), `use_variable`, `position_variable` / `position_scope` |
| **MoveBy** | Move the node relative to its current position | `target_node`, `offset` (Vector3), `space` (Global/Local), `use_variable`, `offset_variable` / `offset_scope` |
| **SetRotation** | Set the node's absolute rotation | `target_node`, `space` (Global/Local), `rotation_variable`, `rotation_scope` |
| **RotateBy** | Rotate relative to the current rotation | `target_node`, `rotation_offset` (degrees), `space` (Global/Local, default Local), `rotation_variable`, `rotation_scope` |
| **SetScale** | Set the node's scale | `target_node`, `scale` (Vector3), `use_variable`, `scale_variable` / `scale_scope` |
| **LookAt** | Make the node face a target position or node | `target_node`, `target_type` (Position/Node), `look_at_node`, `use_custom_up`, `up_vector` (3D only) |
| **GetPosition** | Get the node's current position and save it to a variable | `target`, `save_to_variable`, `save_to_scope`, `scope_source`, `use_global_position` |

### Instruction Usage Notes

**Coordinate space:**
- `GLOBAL`: operate in the world coordinate system
- `LOCAL`: operate in the node's local coordinate system (relative to the parent's transform)

**Variable read mode:**
- Most transform instructions support `use_variable` mode, reading values from Local/Scope/Global variables
- `ScopeSource` configures the scope source: Nearest / Custom ID / Trigger Scope / Target Node

**Difference between SetRotation and RotateBy:**
- `SetRotation` sets an absolute rotation, directly overwriting the current value
- `RotateBy` adds an offset on top of the current rotation

**LookAt target types:**
- `POSITION`: face the specified coordinate position
- `NODE`: face the position of the specified node

**GetPosition result:**
- 2D nodes return a `Vector2`, 3D nodes return a `Vector3`
- `use_global_position` (default true): true returns the global position (`global_position`), false returns the local position (`position`)
- Configure saving via `save_to_variable` (variable name) and `save_to_scope` (scope)

---

## Common Use Cases

### 1. Teleporting a Character

```
SetPosition → target_node: Player, position: (100, 200, 0), space: Global
```

### 2. Making a Character Face an Enemy

```
LookAt → target_node: Player, target_type: Node, look_at_node: Enemy
```

### 3. Getting an Enemy Position and Computing Distance

```
# Get the enemy position
GetPosition → target: Enemy, save_to_scope: Local, result_variable: enemy_pos

# Compute the distance with MathExpression
MathExpression → expression: distance(vec2(0, 0), vec2({local:player_x}, {local:player_y}))
```

---

**Related docs:**
- [Movement System Guide](11-movement-system-guide.md)
- [Node Operations Instruction Guide](20-node-operations-guide.md)
