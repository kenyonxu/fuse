> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/20-node-operations-guide.md) | English

# Node Operations Instructions Guide

## Overview

Node Operations provides **21 instructions** for manipulating the node tree at runtime, covering scene instantiation, node lookup, group operations, lifecycle management, property control, communication, and advanced operations. All instructions live in the `instructions/node_operations/` directory.

| Category | Count | Instruction names |
|------|--------|---------|
| Scene instantiation | 3 | InstantiateScene, RecyclePooledScene, WarmUpPool |
| Node lookup & enumeration | 7 | FindNode, GetAllChildren, GetAllChildrenPosition, GetChildByIndex, GetLastChild, GetRandomChild, GetChildCount |
| Group operations | 2 | GetNodesInGroup, GetGroupCount |
| Node lifecycle | 3 | CloneNode, QueueFreeNode, ReparentNode |
| Node properties | 3 | SetPropertyValue, SetGlobalPosition, SetProcessMode |
| Node control | 2 | EnableDisableNode, EmitSignal |
| Advanced operations | 1 | RunTargetNodeFunction |

---

## Scene Instantiation

### InstantiateScene

**File:** `instructions/node_operations/instantiate_scene.gd`
**class_name:** InstantiateScene

Instantiates a scene dynamically from a scene path. Supports object pooling, position modes, variable references, and more.

| Parameter | Type | Description |
|------|------|------|
| `scene_path` | String | Path of the scene to instantiate (.tscn) |
| `parent_node` | NodePath | Parent of the instantiated node (optional, defaults to the current scene) |
| `position_mode` | PositionMode | Position source: `MANUAL` (specified manually) or `VARIABLE` (read from a variable) |
| `spawn_position` | Vector3 | Manual spawn position (when position_mode=MANUAL) |
| `position_variable` | String | Position variable name (when position_mode=VARIABLE) |
| `position_scope` | VariableScope | Scope of the position variable |
| `spawn_offset` | Vector3 | Spawn position offset |
| `save_instance_id` | bool | Whether to save the instance ID to a variable |
| `target_variable` | String | Target variable name for the instance ID |
| `save_to_scope` | VariableScope | Scope to save the instance ID into |
| `use_object_pool` | bool | Whether to use the object pool |
| `pool_initial_size` | int | Initial pool size (default 20) |
| `pool_max_size` | int | Maximum pool size (default 100) |

**Position configuration:** choose manual coordinates or reading from a variable via `position_mode`, with support for the `spawn_offset` offset.

**Object pool reuse:** with `use_object_pool` enabled, instantiation first tries to take an instance from the object pool.

### RecyclePooledScene

**File:** `instructions/node_operations/recycle_pooled_scene.gd`
**class_name:** RecyclePooledScene

Recycles an instantiated scene back into the object pool instead of deleting it outright. Recycled objects can be reused by `InstantiateScene`.

| Parameter | Type | Description |
|------|------|------|
| `target_node` | NodePath | The node to recycle |

### WarmUpPool

**File:** `instructions/node_operations/warm_up_pool.gd`
**class_name:** WarmUpPool

Pre-creates the given number of scene instances in the object pool to reduce runtime instantiation hitches.

| Parameter | Type | Description |
|------|------|------|
| `scene_path` | String | Scene path |
| `pool_size` | int | Number of instances to pre-create |

---

## Node Lookup & Enumeration

### FindNode

**File:** `instructions/node_operations/find_node.gd`
**class_name:** FindNode

Finds nodes in the scene tree by criteria, with three search dimensions.

| Parameter | Type | Description |
|------|------|------|
| `search_type` | SearchType | `BY_NAME` (by name), `BY_TYPE` (by type), `BY_GROUP` (by group) |
| `search_value` | String | Value to search for (name/type name/group name) |
| `search_scope` | SearchScope | Search scope: `CHILDREN` (child nodes), `SCENE` (current scene), `GLOBAL` (whole scene tree) |
| `recursive` | bool | Whether to search recursively (default true) |
| `first_match_only` | bool | Whether to return only the first match (default true) |
| `result_variable` | String | Variable name that stores the result |
| `result_scope` | VariableScope | Scope of the result variable (Local/Scope/Global) |
| `error_handling` | ErrorHandling | When not found: `STRICT` (log an error) / `SILENT` (silent) / `WARNING` (log a warning) |

### GetAllChildren

**File:** `instructions/node_operations/get_all_children.gd`
**class_name:** GetAllChildren

Gets all direct children of a node and stores the result in a variable array.

| Parameter | Type | Description |
|------|------|------|
| `target` | NodePath | Target node |
| `save_to_scope` | String | Variable name that stores the array |
| `scope_source` | ScopeSource | Scope source |

### GetAllChildrenPosition

**File:** `instructions/node_operations/get_all_children_position.gd`
**class_name:** GetAllChildrenPosition

Gets the position information of all direct children, returning an array of Dictionaries containing node names and positions.

| Parameter | Type | Description |
|------|------|------|
| `target` | NodePath | Target node |
| `save_to_scope` | String | Variable name to store into |
| `scope_source` | ScopeSource | Scope source |

### GetChildByIndex

**File:** `instructions/node_operations/get_child_by_index.gd`
**class_name:** GetChildByIndex

Gets a child by index (positive and negative indices supported; negatives count from the end).

| Parameter | Type | Description |
|------|------|------|
| `target` | NodePath | Target node |
| `index` | int | Child index |
| `save_to_scope` | String | Variable name to store into |
| `scope_source` | ScopeSource | Scope source |

### GetLastChild

**File:** `instructions/node_operations/get_last_child.gd`
**class_name:** GetLastChild

Gets the last child node (`get_child(get_child_count() - 1)`).

| Parameter | Type | Description |
|------|------|------|
| `target` | NodePath | Target node |
| `save_to_scope` | String | Variable name to store into |
| `scope_source` | ScopeSource | Scope source |

### GetRandomChild

**File:** `instructions/node_operations/get_random_child.gd`
**class_name:** GetRandomChild

Gets a random child node. Suited to random rewards, random enemy spawning, etc.

| Parameter | Type | Description |
|------|------|------|
| `target` | NodePath | Target node |
| `save_to_scope` | String | Variable name to store into |
| `scope_source` | ScopeSource | Scope source |

### GetChildCount

**File:** `instructions/node_operations/get_child_count.gd`
**class_name:** GetChildCount

Gets the number of direct children and stores the result in a variable.

| Parameter | Type | Description |
|------|------|------|
| `target` | NodePath | Target node |
| `save_to_scope` | String | Variable name to store into |
| `scope_source` | ScopeSource | Scope source |

---

## Group Operations

### GetNodesInGroup

**File:** `instructions/node_operations/get_nodes_in_group.gd`
**class_name:** GetNodesInGroup

Gets all nodes in the specified group and stores the result as a variable array.

| Parameter | Type | Description |
|------|------|------|
| `group_name` | String | Group name |
| `save_to_scope` | String | Variable name to store into |
| `scope_source` | ScopeSource | Scope source |

### GetGroupCount

**File:** `instructions/node_operations/get_group_count.gd`
**class_name:** GetGroupCount

Gets the number of nodes in the specified group.

| Parameter | Type | Description |
|------|------|------|
| `group_name` | String | Group name |
| `save_to_scope` | String | Variable name to store into |
| `scope_source` | ScopeSource | Scope source |

---

## Node Lifecycle

### CloneNode

**File:** `instructions/node_operations/clone_node.gd`
**class_name:** CloneNode

Clones a node and its children (`Node.duplicate()`). Optionally preserves variable references.

| Parameter | Type | Description |
|------|------|------|
| `source_node` | NodePath | Source node |
| `parent_node` | NodePath | Parent of the clone (optional, defaults to the same parent) |
| `preserve_variables` | bool | Whether to preserve variable data |

### QueueFreeNode

**File:** `instructions/node_operations/queue_free_node.gd`
**class_name:** QueueFreeNode

Queues a node for deletion (`queue_free()`); it is safely deleted at the end of the current frame.

| Parameter | Type | Description |
|------|------|------|
| `target_node` | NodePath | The node to delete |

### ReparentNode

**File:** `instructions/node_operations/reparent_node.gd`
**class_name:** ReparentNode

Moves a node from one parent node to another. Supports keeping the global transform.

| Parameter | Type | Description |
|------|------|------|
| `target_node` | NodePath | The node to move |
| `new_parent` | NodePath | New parent node |
| `keep_global_transform` | bool | Whether to keep global position/rotation/scale unchanged |

---

## Node Property Control

### SetPropertyValue

**File:** `instructions/node_operations/set_property_value.gd`
**class_name:** SetPropertyValue

Sets any property value on a node. Supports reading the target value from a variable.

| Parameter | Type | Description |
|------|------|------|
| `target_node` | NodePath | Target node |
| `target_property` | String | Property name |
| `new_value` | Variant | Property value (direct value mode) |
| `set_with_variable` | bool | Whether to read the value from a variable |
| `variable_name` | String | Value variable name (variable mode) |
| `variable_scope` | VariableScope | Variable scope (Local/Scope/Global) |

### SetGlobalPosition

**File:** `instructions/node_operations/set_global_position.gd`
**class_name:** SetGlobalPosition

Sets the node's global position (`global_position`) directly, ignoring parent transforms.

| Parameter | Type | Description |
|------|------|------|
| `target_node` | NodePath | Target node |
| `position` | Vector2/Vector3 | Target global position |
| `use_variable` | bool | Whether to read the position from a variable |
| `position_variable` | String | Position variable name |
| `position_scope` | ScopeSource | Variable scope |

### SetProcessMode

**File:** `instructions/node_operations/set_process_mode.gd`
**class_name:** SetProcessMode

Sets the node's process mode (`process_mode`), controlling whether the node receives `_process` / `_physics_process` callbacks.

| Parameter | Type | Description |
|------|------|------|
| `target_node` | NodePath | Target node |
| `process_mode` | ProcessMode | Godot ProcessMode enum value |

### EnableDisableNode

**File:** `instructions/node_operations/enable_disable_node.gd`
**class_name:** EnableDisableNode

Enables or disables a node (combined `process_mode` + `visible` control).

| Parameter | Type | Description |
|------|------|------|
| `target_node` | NodePath | Target node |
| `enabled` | bool | Enable/disable |

---

## Node Communication

### EmitSignal

**File:** `instructions/node_operations/emit_signal.gd`
**class_name:** EmitSignal

Emits a signal on the specified node. Useful for custom message passing between nodes.

| Parameter | Type | Description |
|------|------|------|
| `target_node` | NodePath | Node that emits the signal |
| `signal_name` | String | Signal name |
| `argument_count` | int | Number of signal arguments (0-5) |
| `arg0` ~ `arg4` | Variant | Signal argument values |
| `use_variables` | bool | Whether to read the arguments from variables |

---

## Advanced Operations

### RunTargetNodeFunction

**File:** `instructions/node_operations/run_target_node_function.gd`
**class_name:** RunTargetNodeFunction

Dynamically calls a specified method on the target node. Supports argument passing and return value capture. Arguments use a dynamic binding system that adapts automatically to the actual method signature.

| Parameter | Type | Description |
|------|------|------|
| `target_node` | NodePath | Target node |
| `target_function` | String | Method name |
| `store_result` | bool | Whether to capture the return value |
| `result_variable_name` | String | Variable name that stores the return value |
| `result_variable_scope` | VariableScope | Scope of the return value variable (Local/Scope/Global) |
| `param_0` ~ `param_N` | Variant | Dynamic arguments (generated automatically from the selected method's signature) |

---

## Common Use Cases

### Dynamically Spawning Enemies at Runtime

```
Trigger: OnInterval (every 3 seconds)
├── InstantiateScene
│   scene_path: "res://enemies/goblin.tscn"
│   parent_node: "/root/Game/EnemyContainer"
│   use_variable: false
└── SetPosition
    target_node: (result of the previous line)
    position: (random position)
    space: Global
```

### Moving Nodes Across Scene Switches

```
Trigger: OnSignalFromGroup (scene_manager, "switching_scene")
├── FindNode
│   search_type: BY_NAME
│   search_value: "PlayerHUD"
│   scope: SCENE_TREE
├── ReparentNode
│   target_node: (the found HUD)
│   new_parent: "/root/NewScene/UI"
│   keep_global_transform: true
└── LogInstruction
    message: "HUD 已转移到新场景"
```

### Finding Child Nodes in Bulk

```
Trigger: OnReady
├── GetAllChildren
│   target: "/root/Game/ItemContainer"
│   save_to_scope: "items"
├── ForEach
│   array: {scope:items}
│   └── RunTargetNodeFunction
│       target_node: (current element)
│       function_name: "collect"
```

---

## Notes

- **Node paths vs variable references**: most instructions accept both a NodePath and a node reference stored in a variable. Paths are more robust; references perform better.
- **Post-instantiation references**: the node returned by `InstantiateScene` is usable within the current instruction sequence — no need to wait for a frame.
- **Group name casing**: Godot group names are case-sensitive; stay consistent.
- **QueueFreeNode does not delete immediately**: the node is freed at the end of the current frame; referencing it afterwards causes errors.
