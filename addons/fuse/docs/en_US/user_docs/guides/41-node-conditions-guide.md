> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/41-node-conditions-guide.md) | English

# Node Conditions Guide

## Overview

Node conditions query node state in flow control: existence, enabled/disabled, group membership, property values, relative direction, hierarchy relations, and more. **9 conditions** in total, located in the `conditions/node/` directory.

| Category | Condition | class_name | Function |
|------|------|-----------|------|
| Existence & state | CheckNodeExists | CheckNodeExists | Whether the node exists |
| Existence & state | CheckNodeActive | CheckNodeActive | Whether the node is enabled/disabled |
| Group & property | CheckNodeInGroup | CheckNodeInGroup | Whether the node is in the specified group |
| Group & property | CheckNodeProperty | CheckNodeProperty | Node property value comparison |
| Group & property | CheckGroupCount | CheckGroupCount | Node count in a group comparison |
| Hierarchy | CheckIsChildOf | CheckIsChildOf | Whether the node is a child of the specified node |
| Hierarchy | CheckChildCount | CheckChildCount | Child count comparison |
| Direction | CheckDirection | CheckDirection | The node's direction relative to a target |
| Direction | CheckFacingDirection | CheckFacingDirection | Whether the node faces the target |

---

## Existence and State

### CheckNodeExists

**File:** `conditions/node/check_node_exists.gd`
**class_name:** CheckNodeExists

Checks whether the node exists in the current scene tree.

| Parameter | Type | Description |
|------|------|------|
| `node_path` | NodePath | The node path to check |

**Example:** Attack only if the weapon exists

```
CheckNodeExists → node_path: "Player/Weapon"
├── true → (run the attack logic)
└── false → (unarmed attack or a warning)
```

### CheckNodeActive

**File:** `conditions/node/check_node_active.gd`
**class_name:** CheckNodeActive

Checks whether the node is enabled/active. Determined via `process_mode`.

| Parameter | Type | Description |
|------|------|------|
| `target_node` | NodePath | The target node |
| `expected_active` | bool | The expected active state (true = enabled, false = disabled) |

**Example:** Check whether a trap mechanism is active

```
CheckNodeActive → target_node: "Traps/LaserGate", expected_active: false
├── true → (the gate is closed, safe to pass)
└── false → (the gate is open, danger)
```

---

## Group and Property

### CheckNodeInGroup

**File:** `conditions/node/check_node_in_group.gd`
**class_name:** CheckNodeInGroup

Checks whether the node has been added to the specified group.

| Parameter | Type | Description |
|------|------|------|
| `target_node` | NodePath | The target node |
| `group_name` | String | The group name |

**Example:** Check the enemy type

```
CheckNodeInGroup → target_node: Enemy, group_name: "boss"
├── true → (a Boss-tier enemy, use special handling)
└── false → (a regular minion)
```

### CheckNodeProperty

**File:** `conditions/node/check_node_property.gd`
**class_name:** CheckNodeProperty

Checks whether the node's specified property value satisfies a condition.

| Parameter | Type | Description |
|------|------|------|
| `target_node` | NodePath | The target node |
| `property_name` | String | The property name |
| `operator` | CompareOperator | The comparison operator |
| `value` | Variant | The value to compare against |

**Example:** Boss phase check

```
CheckNodeProperty → target_node: Boss, property_name: "phase", operator: EQUALS, value: 2
├── true → (Boss phase two, switch attack patterns)
└── false → (phase-one attack pattern)
```

### CheckGroupCount

**File:** `conditions/node/check_group_count.gd`
**class_name:** CheckGroupCount

Checks whether the number of nodes in the specified group satisfies a condition.

| Parameter | Type | Description |
|------|------|------|
| `group_name` | String | The group name |
| `operator` | CompareOperator | The comparison operator |
| `value` | int | The count to compare against |

**Example:** Summon reinforcements when the group is understaffed

```
CheckGroupCount → group_name: "enemies", operator: LESS_THAN, value: 3
├── true → (fewer than 3 enemies, summon reinforcements)
└── false → (keep watching)
```

---

## Hierarchy

### CheckIsChildOf

**File:** `conditions/node/check_is_child_of.gd`
**class_name:** CheckIsChildOf

Checks whether the node is a (direct or indirect) child of the specified parent node.

| Parameter | Type | Description |
|------|------|------|
| `target_node` | NodePath | The node to check |
| `parent_node` | NodePath | The parent node |

**Example:** Check whether an item is in the inventory

```
CheckIsChildOf → target_node: Potion, parent_node: "Player/Inventory"
├── true → (the potion is in the inventory and can be used)
└── false → (not in the inventory)
```

### CheckChildCount

**File:** `conditions/node/check_child_count.gd`
**class_name:** CheckChildCount

Checks whether the node's direct child count satisfies a condition.

| Parameter | Type | Description |
|------|------|------|
| `target_node` | NodePath | The target node |
| `operator` | CompareOperator | The comparison operator |
| `value` | int | The count to compare against |

**Example:** Stop collecting when the container is full

```
CheckChildCount → target_node: "Player/Backpack", operator: GREATER_EQUALS, value: 20
├── true → (the backpack is full, prompt to clean up)
└── false → (can keep collecting)
```

---

## Direction Detection

### CheckDirection

**File:** `conditions/node/check_direction.gd`
**class_name:** CheckDirection

Checks the node's positional direction relative to the target (left/right/up/down).

| Parameter | Type | Description |
|------|------|------|
| `source_node` | NodePath | The source node |
| `target_node` | NodePath | The target node |
| `direction` | Vector2 | The expected direction vector |

### CheckFacingDirection

**File:** `conditions/node/check_facing_direction.gd`
**class_name:** CheckFacingDirection

Checks whether the node faces another node or position.

| Parameter | Type | Description |
|------|------|------|
| `source_node` | NodePath | The source node |
| `target_node` | NodePath | The target node (optional; mutually exclusive with target_position) |
| `target_position` | Vector3 | The target position (optional) |
| `angle_threshold` | float | The angle tolerance (degrees) |

**Example:** Whether the player faces the treasure chest

```
CheckFacingDirection → source_node: Player, target_node: TreasureChest, angle_threshold: 30.0
├── true → (the player faces the chest, show the open prompt)
└── false → (do not show)
```

---

## Common Use Cases

### Attack Only If the Weapon Exists

```
Trigger: OnInputAction (attack)
├── CheckNodeExists → node_path: "Player/Weapon"
│   ├── true → (attack with the weapon)
│   └── false → CheckNodeProperty → target: Player, property: "has_weapon_equipped", operator: EQUALS, value: true
│       └── true → (equipped but the node is not ready, handle later)
└── (no weapon, play the unarmed attack)
```

### Boss Phase Check via Group Count

```
OnInterval → interval_seconds: 5.0
├── CheckNodeProperty → target: Boss, property_name: "phase", operator: EQUALS, value: 2
│   └── true → CheckGroupCount → group_name: "boss_minions", operator: GREATER_THAN, value: 0
│       └── true → (minions remain, the Boss is invulnerable)
│       └── false → (minions cleared, the Boss enters its attackable phase)
```

### Two-Sided Character Facing Detection

```
CheckFacingDirection → source_node: Enemy, target_node: Player, angle_threshold: 45.0
├── true → (the enemy faces the player, defend against frontal attacks)
└── false → CheckFacingDirection → source_node: Enemy, target_node: Player, angle_threshold: 135.0
    ├── true → (back to the player, trigger the backstab damage bonus)
    └── false → (side)
```

---

## Notes

0. **Node path or variable:** conditions with NodePath parameters (such as CheckNodeExists and CheckNodeActive) support both hard-coded node paths and node references passed dynamically through variables.
1. **Node path validity:** after a scene change, previously cached `NodePath`s may become invalid. Re-acquire node references after scene changes.
2. **Group name casing:** Godot group names are case-sensitive; make sure `CheckNodeInGroup` and `CheckGroupCount` use consistent group names.
3. **CheckDirection vs CheckFacingDirection:** the former checks the positional relation (which side of the target the source node is on); the latter checks facing (whether the source node's facing points at the target).
