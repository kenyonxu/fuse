> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/52-multithreading-optimization.md) | English

# Fuse Multithreading Optimization - User Guide

## What Is This?

The Fuse plugin can now run condition checks in parallel. If your trigger has many conditions, your game will run more smoothly.

## How to Enable

Enabled by default. In the MultiEventTrigger Inspector:

```
Use Parallel Condition Evaluation: ✓
```

That's it. The system handles the rest automatically.

## When Is It Useful?

When a trigger has multiple conditions. For example:

```
Trigger "Open Chest"
├── Condition 1: Does the player have the key?
├── Condition 2: Is the chest unlocked?
├── Condition 3: Is the player close enough?
└── Condition 4: Does the game state allow it?
```

Previously these conditions were checked one after another. Now they can be checked simultaneously, which is faster.

## Performance Gains

The more conditions you have, the more obvious the parallel gains — evaluating dozens of conditions in parallel typically reduces judgment time to a fraction of the serial cost, and the gap widens further with hundreds of conditions. With very few conditions the benefit is limited (thread scheduling itself has overhead), but it will not be slower.

## Scene Preloading

### Problem

Stuttering on scene changes? That's Godot loading the scene.

### Solution

Load scenes in the background ahead of time:

1. Add a `Preload Scene` instruction to a trigger
2. Set the scene path to load
3. While the game runs, the scene loads in the background
4. When needed, instantiate it directly with no waiting

### Usage

```
Trigger "Enter Area"
├── Event: Area2D body_entered
├── Instructions:
│   └── Preload Scene
│       └── Scene: res://scenes/boss_fight.tscn
│       └── Mode: Async Later
```

Then check the load status in another trigger:

```
Trigger "Start Boss Fight"
├── Event: Timer timeout
├── Conditions:
│   └── Check Preload Status
│       └── Scene: res://scenes/boss_fight.tscn
│       └── Expected: Loaded
└── Instructions:
    └── Change Scene → boss_fight.tscn
```

The scene switches instantly, with no stuttering.

## Configuration Options

Find `FuseThreadingConfig` in the project settings:

| Option | Default | Description |
|------|--------|------|
| Enable Multithreading | ✓ | Global switch |
| Parallel Condition Evaluation | ✓ | Evaluate conditions in parallel |
| Max Parallel Conditions | 8 (max 16) | Parallelism cap — the maximum number of conditions entering worker threads at once |
| Timeout Per Condition | 0.1s | Timeout for a single condition |
| Enable Resource Preload | ✓ | Enable scene preloading |

## FAQ

### Is the Game Slower?

First confirm it is a condition-evaluation problem (use the Topology panel / the variable watcher to locate hot spots). If so, adjust as needed: lower `Max Parallel Conditions` (excessive parallelism means thread scheduling overhead can eat the gains), or simply turn off the `Parallel Condition Evaluation` switch to fall back to serial evaluation entirely — both switches can be toggled at any time without affecting logical correctness.

### Some Conditions Do Not Execute?

That condition may not be "thread-safe". The system detects this automatically:

- ✅ Thread-safe: checking variable values, math operations
- ❌ Not safe: accessing nodes, getting the parent node

Unsafe conditions run on the main thread; functionality is unaffected.

### Scene Load Timeout?

Increase the preload timeout:

```
Preload Timeout: 30.0  (30 seconds)
```

Large scenes need more time to load.

## Compatibility

- Godot 4.7+
- No impact on existing projects
- Multithreading can be turned off at any time
- All old triggers keep working normally

## Technical Details

Want to know more? See the [developer guide](../../../zh_CN/dev_docs/guides/multithreading-developer-guide.md) (Chinese).
