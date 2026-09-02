> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/33-node-events-guide.md) | English

# Node Events Guide

## Overview

Node events respond to node state changes or specific signal firings, covering property change monitoring, signal forwarding, instantiation detection, and more. **4 events** in total, located in the `events/node/` directory.

| Event | class_name | Trigger condition | Trigger mode |
|------|-----------|----------|----------|
| OnPropertyChanged | OnPropertyChanged | The value of a specified property on the target node changes | Polling |
| OnSignalFromGroup | OnSignalFromGroup | Any node in the group emits the specified signal | Signal binding |
| OnTargetSignalEmit | OnTargetSignalEmit | The target node emits the specified signal | Signal binding |
| OnNodeInstance | OnNodeInstance | The specified scene is instantiated | Signal binding |

---

## OnPropertyChanged (Property Changed)

**File:** `events/node/on_property_changed.gd`
**class_name:** OnPropertyChanged

Fires when the value of the specified property on the target node changes.

> **⚠️ Note:** this event uses **polling mode** (periodic checks at `check_interval`), not signal binding. It does not automatically react to property changes; detection is delayed.

| Parameter | Type | Default | Description |
|------|------|--------|------|
| `target_node` | NodePath | — | The node to watch |
| `property_name` | String | "" | The property name to watch (e.g. `"health"`, `"position"`) |
| `check_interval` | float | 0.1 | Polling interval (seconds) |
| `emit_old_and_new` | bool | true | Whether to pass the old and new values on trigger |

**Effect of `emit_old_and_new`:**
- `false`: only the property name is passed on trigger
- `true`: `property_name`, `old_value`, and `new_value` are passed to the subsequent instruction chain on trigger

**Example:** Watch health changes to trigger a UI update

```
OnPropertyChanged → target_node: Player, property_name: "health", check_interval: 0.05, emit_old_and_new: true
├── (fires when health changes)
└── SetVariable → variable_name: "hud_health", value: {scope:new_value}
```

---

## OnSignalFromGroup (Group Signal)

**File:** `events/node/on_signal_from_group.gd`
**class_name:** OnSignalFromGroup

Fires when **any node in the group** emits the specified signal. Useful for watching a shared behavior across all objects in a group (e.g. any enemy in the enemies group dying).

| Parameter | Type | Default | Description |
|------|------|--------|------|
| `signal_name` | String | "" | The signal name to listen for |
| `group_name` | String | "" | The target group name |
| `emit_node` | bool | false | Whether to pass the signal-emitting node into the instruction chain |
| `emit_signal_name` | bool | false | Whether to pass the signal name into the instruction chain |

**Example:** Any enemy in the group dies

```
OnSignalFromGroup → signal_name: "died", group_name: "enemies"
├── (fires when an enemy dies)
├── AddScore → points: 100
└── LogInstruction → message: "敌人被击败"
```

---

## OnTargetSignalEmit (Target Signal)

**File:** `events/node/on_target_signal_emit.gd`
**class_name:** OnTargetSignalEmit

Fires when the target node emits the specified signal. Integrates with the automatic refresh of the signal cache in the Editor.

| Parameter | Type | Default | Description |
|------|------|--------|------|
| `target_node` | NodePath | — | Target node path |
| `target_signal` | String | "" | The signal name to listen for |
| `trigger_once` | bool | false | Whether to fire only once |
| `filter_signal_args` | bool | false | Whether to enable signal argument filtering |
| `arg_filter_values` | Array | [] | Argument filter values (effective when filter_signal_args=true) |

**Editor support:** after selecting the target node, the signal name dropdown automatically caches the node's available signals for quick selection.

**Example:** Button click event

```
OnTargetSignalEmit → target_node: "UI/StartButton", target_signal: "pressed"
├── HideUI
├── InstantiateScene → scene_path: "res://levels/level_01.tscn"
└── LogInstruction → message: "游戏开始"
```

---

## OnNodeInstance (Node Instance)

**File:** `events/node/on_node_instance.gd`
**class_name:** OnNodeInstance

Fires when the specified scene is instantiated. Useful for running initialization logic after scene preloading completes.

| Parameter | Type | Default | Description |
|------|------|--------|------|
| `scene_path` | String | "" | The scene path to watch |
| `parent_node` | NodePath | — | The parent node of the instantiation (used for matching) |
| `emit_instance` | bool | false | Whether to pass the instantiation result into the instruction chain |

**Example:** Trigger after scene preloading completes

```
OnNodeInstance → scene_path: "res://levels/boss_room.tscn"
├── (the Boss scene has been instantiated)
├── SetVariable → name: "boss_health", value: 1000, scope: GLOBAL
└── LogInstruction → message: "Boss 房间已加载"
```

---

## Common Use Cases

### Watch Health Changes to Trigger UI

```
OnPropertyChanged → target_node: Player, property_name: "health", check_interval: 0.05
├── SetVariable → scope: GLOBAL, name: "player_health", value: {scope:new_value}
└── PlayAnimation → target: HealthBar, animation: "update"
```

### Group Event Broadcast

```
# Listens when any enemy is hit
OnSignalFromGroup → signal_name: "hit", group_name: "enemies", emit_node: true
├── (get a reference to the hit enemy)
└── (trigger the hit-reaction logic)
```

### Start the Game on Button Click

```
OnTargetSignalEmit → target_node: "CanvasLayer/MainMenu/PlayButton", target_signal: "pressed"
├── ChangeScene → scene_path: "res://levels/intro.tscn"
└── (play the transition animation)
```

---

## Notes

1. **OnPropertyChanged polling mode:** this event is not true signal binding; it polls the property value at `check_interval`. Responses are delayed (by up to the check interval). For high-frequency properties, use an interval below 0.05s.
2. **OnTargetSignalEmit signal availability:** the target node must actually have the specified signal. If nodes change at runtime, refresh the signal cache list in the editor.
3. **OnSignalFromGroup group names:** group names are case-sensitive; make sure the target nodes have been added to the specified group.
4. **OnNodeInstance matching:** the scene path must exactly match the path used in the `InstantiateScene` instruction (including the .tscn resource suffix).
