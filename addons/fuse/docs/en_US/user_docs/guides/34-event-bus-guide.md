> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/34-event-bus-guide.md) | English

# Event Bus User Guide

The Event Bus is the global event communication mechanism of the Fuse visual programming system, allowing different Triggers to communicate with each other through custom events.

## Quick Start

### Basic Concepts

The Event Bus works like a radio station:

- **Sending events (SendEvent)** - like a station broadcasting a message
- **Receiving events (OnReceiveEvent)** - like a radio receiving a specific channel's broadcast

```
┌─────────────────┐                    ┌─────────────────┐
│    Trigger A    │                    │    Trigger B    │
│                 │                    │                 │
│  SendEvent      │    Event Bus       │  OnReceiveEvent │
│  "player_died"  │ ─────────────────→ │  "player_died"  │
│                 │                    │        ↓        │
└─────────────────┘                    │ execute actions │
                                       └─────────────────┘
```

## Component Reference

### SendEvent Instruction

Sends a custom event to the event bus.

**Properties:**

| Property | Type | Description |
|------|------|------|
| Event Name | String | The event name (required) |
| Event Args | Dictionary | Event arguments (optional) |
| Deferred | Bool | Whether to defer sending until the end of the frame |

**Use cases:**
- Notify other systems of state changes
- Trigger global responses
- Cross-scene communication

### OnReceiveEvent Event

Listens for and responds to custom events.

**Properties:**

| Property | Type | Description |
|------|------|------|
| Event Name | String | The event name to listen for |
| Trigger Once | Bool | Whether to trigger only once |
| Store Args to Local | Bool | Whether to store the arguments as local variables |
| Local Variable Prefix | String | Local variable prefix (default `event_`) |

**Use cases:**
- Respond to global events
- Listen to other Triggers' states
- Achieve loosely coupled communication

## Usage Examples

### Example 1: Player Death Notification

**Step 1: Create the sending Trigger**

1. Create a new Trigger
2. Add the `OnHealthZero` event
3. Add the `SendEvent` instruction
4. Set Event Name to `player_died`
5. Set Event Args to `{ "position": "$player_position" }`

**Step 2: Create the receiving Trigger (Game Over UI)**

1. Create a new Trigger
2. Add the `OnReceiveEvent` event
3. Set Event Name to `player_died`
4. Add instructions that display the Game Over UI

**Step 3: Create the receiving Trigger (enemies stop)**

1. Create a new Trigger
2. Add the `OnReceiveEvent` event
3. Set Event Name to `player_died`
4. Add instructions that stop the enemy AI

### Example 2: Events with Arguments

**Sender:**
```
Event: OnItemCollected
Actions:
  - SendEvent: "item_picked_up"
    Args: {
      "item_id": "$collected_item_id",
      "item_type": "$item_type",
      "count": 1
    }
```

**Receiver:**
```
Event: OnReceiveEvent: "item_picked_up"
  Store Args to Local: true
  Local Variable Prefix: "event_"
Actions:
  - Debug: "收到物品: $event_item_id"
  - UpdateInventory: $event_item_type, $event_count
```

### Example 3: One-shot Event

**Scenario: first-launch tutorial**

```
Event: OnReceiveEvent: "game_started"
  Trigger Once: true
Actions:
  - ShowTutorial: "welcome"
```

## Event Argument Access

When `Store Args to Local` is enabled, event arguments are automatically stored as local variables:

| Original argument | Local variable name |
|----------|------------|
| `{ "health": 100 }` | `$event_health` |
| `{ "player_id": "p1" }` | `$event_player_id` |

These variables can be used in subsequent instructions:

```
- SetHealth: $event_health
- SetPlayer: $event_player_id
```

## Best Practices

### Event Naming Conventions

Use module prefixes to avoid naming conflicts:

```
✅ Good naming:
- player:died
- quest:completed
- ui:refresh
- scene:loaded

❌ Naming to avoid:
- died          (too vague)
- event1        (meaningless)
- playerDied    (inconsistent style)
```

### Argument Design

- Pass only the necessary data
- Use clear, easy-to-understand key names
- Avoid deeply nested structures

```
✅ Good arguments:
{
  "player_id": "p1",
  "position": { "x": 100, "y": 200 }
}

❌ Arguments to avoid:
{
  "data": {
    "info": {
      "player": {
        "id": "p1"
      }
    }
  }
}
```

### Performance Considerations

- Avoid sending events frequently in `_process`
- Use the `Deferred` option to avoid too many events within the same frame
- Use `Trigger Once` to avoid duplicate responses

## Debugging Tips

### Viewing Event History

The Event Bus keeps a history of the most recent 100 events:

1. Find the `FuseEventBus` node in the scene tree
2. Inspect the `event_history` property
3. Check event names, arguments, and timestamps

### Common Issues

**Q: The event is not being received?**

Check:
1. Whether the Event Name matches exactly (case-sensitive)
2. Whether OnReceiveEvent is properly initialized
3. Whether FuseEventBus is loaded correctly

**Q: The argument values are incorrect?**

Check:
1. Whether the variable reference syntax is correct (`$variable_name`)
2. Whether Store Args to Local is enabled
3. Whether the Local Variable Prefix is correct

**Q: The event triggers multiple times?**

Solutions:
1. Enable the Trigger Once option
2. Check whether there are multiple identical Triggers
3. Use condition instructions to control execution

## Comparison with Other Communication Approaches

| Approach | Use case | Complexity |
|------|----------|--------|
| **Event Bus** | Across Triggers, global events | Low |
| OnTargetSignalEmit | Listen to a specific node's signals | Low |
| OnSignalFromGroup | Listen to signals within a group | Medium |
| Global variables + polling | State synchronization | High |

---

**Related docs:**
- [Custom Event Best Practices](../best_practices/custom_event.md)

**Last updated**: 2026-02-27
