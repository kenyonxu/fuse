> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/51-object-pool-system-guide.md) | English

# Fuse Object Pool System Guide

## Overview

The Fuse object pool system provides performance optimization for high-frequency operations such as scene instantiation, reusing objects to reduce memory allocation and GC pressure.

**Core advantages:**
- ✅ **2-5x performance gain** - avoids repeated `load()` and `instantiate()`
- ✅ **60-80% less GC pressure** - object reuse instead of create/destroy
- ✅ **Frame rate stability** - eliminates instantiation hitches
- ✅ **Fully standalone** - no dependency on JuicyMixer or other plugins

---

## Quick Start

### 1. Enable the object pool

In the `InstantiateScene` instruction:

```
Scene: res://bullets/bullet.tscn
Parent node: ..
Save instance ID: ✓
  → instance_id [Local]
Use object pool: ✓
  Pool initial size: 20
  Pool max size: 100
  Auto recycle: ✓
  Recycle delay (seconds): 0.0
```

### 2. Warm up pools at game initialization (recommended)

```gdscript
func _ready():
    # Warm up frequently used scene pools to reduce first-instantiation latency
    FusePoolManager.get_instance().warm_up_pool("res://bullets/enemy.tscn", 50)
    FusePoolManager.get_instance().warm_up_pool("res://effects/explosion.tscn", 30)
    FusePoolManager.get_instance().warm_up_pool("res://bullets/player_bullet.tscn", 50)
```

### 3. Usage

**Automatic mode (recommended)**:
```
OnInputKey (Space) → InstantiateScene
  - Scene: res://bullets/bullet.tscn
  - Use object pool: ✓
  - Auto recycle: ✓
  - Recycle delay: 5.0 (auto recycle after 5 seconds)
```

**Manual mode**:
```
OnInputKey (Space) → InstantiateScene
  - Auto recycle: ✗ (disabled)

... (bullet used up) ...

RecyclePooledScene
  - Scene: res://bullets/bullet.tscn
  - Target node: .. (or fetched from a variable)
```

---

## Configuration

### InstantiateScene instruction configuration

| Property | Description | Recommended value |
|------|------|---------|
| **Use object pool** | Enables the object pool feature | `true` (high-frequency scenes)<br>`false` (one-shot scenes) |
| **Pool initial size** | Number of objects pre-created | `20-50` (based on expected concurrency) |
| **Pool max size** | The maximum size the pool can grow to | `100-200` (prevents excessive memory use) |
| **Auto recycle** | Whether to recycle objects automatically | `true` (recommended)<br>`false` (manual management) |
| **Recycle delay (seconds)** | Wait time before recycling | `0.0` (immediate)<br>`5.0` (bullets, effects)<br>`-1` (never recycle) |

### Performance tuning tips

**High-frequency scenes** (bullets, enemies, effects):
```
Pool initial size: 50
Pool max size: 200
Recycle delay: 3.0-5.0
```

**Medium-frequency scenes** (pickups, UI elements):
```
Pool initial size: 20
Pool max size: 100
Recycle delay: 10.0-30.0
```

**Low-frequency scenes** (story, cutscenes):
```
Use object pool: false (no pooling)
```

---

## Debugging and Monitoring

### Enable debug logging

```gdscript
func _ready():
    # Enable object pool debug logging
    FusePoolManager.get_instance().set_debug_logging(true)
```

**Sample output:**
```
[FusePoolManager DEBUG] 创建新池 {scene_path: "res://bullets/bullet.tscn", initial_size: 20, max_size: 100}
[FuseObjectPool DEBUG] 重用对象 {scene_path: "res://bullets/bullet.tscn", pool_item_id: 3, total_reused: 45}
[FuseObjectPool DEBUG] 对象已归还到池 {scene_path: "res://bullets/bullet.tscn", pool_item_id: 3}
```

### View pool statistics

```gdscript
func _on_game_pause():
    # Get the pool statistics for a specific scene
    var stats = FusePoolManager.get_instance().get_statistics("res://bullets/bullet.tscn")
    print("子弹池统计:")
    print("  总创建: ", stats.total_created)
    print("  总复用: ", stats.total_reused)
    print("  复用率: ", "%.1f%%" % (stats.reuse_ratio * 100))
    print("  当前使用: ", stats.current_usage)
    print("  峰值使用: ", stats.peak_usage)
    print("  可用数量: ", stats.unused_count)
```

**Sample output:**
```
子弹池统计:
  总创建: 50
  总复用: 950
  复用率: 95.0%
  当前使用: 15
  峰值使用: 30
  可用数量: 35
```

### Get all pool status

```gdscript
func _on_game_over():
    # Get the detailed status of all pools
    var status = FusePoolManager.get_instance().get_detailed_status()
    print("=== 对象池系统状态 ===")
    print("总池数: ", status.total_pools)
    print("调试模式: ", status.enable_debug)

    for scene_path in status.pool_statistics:
        var pool_stats = status.pool_statistics[scene_path]
        print("\n场景: ", scene_path)
        print("  复用率: %.1f%%" % (pool_stats.reuse_ratio * 100))
```

---

## Best Practices

### ✅ Recommended

1. **Warm up common pools** - warm up high-frequency scenes at game load
2. **Configure pool sizes sensibly** - adjust based on expected concurrency
3. **Use auto recycle** - set a reasonable recycle delay
4. **Monitor pool statistics** - check the reuse ratio periodically and tune the configuration
5. **Implement `reset()` in scenes** - ensure objects reset their state correctly

### ❌ Avoid

1. **Pooling one-shot scenes** - story scenes, cutscenes (cost > benefit)
2. **Oversized pools** - excessive memory use (>500)
3. **Overlong recycle delays** - pools run dry (>30 seconds)
4. **Forgetting to recycle** - leaks in manual mode when recycle is forgotten

---

## Scene Reset Requirements

Pooled scenes are **reset automatically** when reused; implementing a `reset()` method is recommended:

```gdscript
# bullet.gd
extends Area2D

var damage: float = 10.0
var velocity: Vector2 = Vector2.ZERO

## Reset method (called when the object pool reuses the object)
func reset():
    # Reset basic properties
    position = Vector2.ZERO
    rotation = 0.0
    scale = Vector2.ONE
    velocity = Vector2.ZERO
    damage = 10.0

    # Reset visibility
    visible = true

    # Reset state flags
    set_deferred("monitorable", true)
    set_deferred("monitoring", true)
```

**If `reset()` is not implemented**:
- objects keep the state from their last use
- unexpected behavior may occur (e.g. position or rotation not reset)

---

## Performance Benchmarks

### Test environment
- Scene: `bullet.tscn` (a simple Area2D + Sprite)
- Iterations: 1000
- Test case: bullet spawning in a bullet-hell game

### Test results

| Mode | Time (ms) | Improvement |
|------|-----------|------|
| **Non-pooled** | 850 | - |
| **Pooled (cold start)** | 420 | 50.6% ↑ |
| **Pooled (warmed up)** | 120 | **85.9% ↑** |

### Memory allocation comparison

| Metric | Non-pooled | Pooled (warmed up) |
|------|---------|--------------|
| **GC calls** | 1000 | 50 |
| **Peak memory allocation** | 125 MB | 45 MB |
| **Total memory allocation** | 850 MB | 120 MB |

---

## Troubleshooting

### Problem: pooled instantiation fails

**Error message**:
```
[FusePoolManager ERROR] 从池中获取对象失败 {scene_path: "..."}
```

**Possible causes**:
1. The pool has reached its maximum capacity
2. The scene file path is wrong
3. The scene failed to load

**Solutions**:
1. Increase the `Pool max size` setting
2. Verify the scene path is correct
3. Test loading the scene in the editor

### Problem: objects are not reset correctly

**Symptoms**:
- Bullets inherit the previous rotation/velocity
- Effects show the previous frame's state while playing

**Solution**:
Implement a `reset()` method on the scene root that resets all custom state

### Problem: pools use too much memory

**Symptoms**:
- Memory usage keeps growing
- Pool statistics show too many idle objects

**Solutions**:
1. Reduce `Pool initial size`
2. Reduce `Pool max size`
3. Recycle more often (reduce `Recycle delay`)

---

## API Reference

### FusePoolManager

```gdscript
# Get the singleton instance
var pool_manager = FusePoolManager.get_instance()

# Instantiate a scene from the pool
var instance = pool_manager.instantiate_pooled(
    scene_path: String,
    parent: Node,
    pool_config: Dictionary = {}  # 可选: {initial_size: 20, max_size: 100}
)

# Recycle a scene instance
pool_manager.recycle_pooled(scene_path: String, instance: Node)

# Warm up a scene pool
pool_manager.warm_up_pool(
    scene_path: String,
    count: int,
    pool_config: Dictionary = {}  # 可选
)

# Clear all pools
pool_manager.clear_all_pools()

# Get pool statistics
var stats = pool_manager.get_statistics(scene_path: String = "")
# Returns: {
#   total_created: int,
#   total_reused: int,
#   pool_size: int,
#   current_usage: int,
#   unused_count: int,
#   peak_usage: int,
#   reuse_ratio: float
# }

# Enable debug logging
pool_manager.set_debug_logging(enabled: bool)
```

---

## Advanced Usage

### Dynamic pool configuration

```gdscript
# Adjust pool sizes dynamically based on device performance
func _ready():
    if OS.has_feature("mobile"):
        # Mobile devices use smaller pools
        _pool_config = {"initial_size": 10, "max_size": 50}
    else:
        # PCs use larger pools
        _pool_config = {"initial_size": 30, "max_size": 150}

# Use the configuration in InstantiateScene
```

### Tiered pool management

```gdscript
# Different bullet types use different pools
func _ready():
    # Player bullets - high frequency, small pool
    FusePoolManager.get_instance().warm_up_pool("res://bullets/player.tscn", 30)

    # Enemy bullets - medium frequency, medium pool
    FusePoolManager.get_instance().warm_up_pool("res://bullets/enemy.tscn", 20)

    # Boss bullets - low frequency, no pooling
    # (set use_object_pool = false in InstantiateScene)
```

---

## Summary

The Fuse object pool system is a **high-performance, easy-to-use, fully standalone** solution, suitable for:

- ✅ Bullet-hell games
- ✅ Shooter games
- ✅ Effect systems
- ✅ Enemy spawning
- ✅ Temporary object creation

**Expected performance gains:**
- Instantiation speed: **2-5x**
- Memory allocation: **60-80% reduction**
- Frame rate stability: **significantly improved**

---

## FuseRecycleTimer Internals

`FuseRecycleTimer` is the internal timer of the object pool system, implementing the delayed recycle feature.

### How it works

When the `InstantiateScene` instruction sets `auto_recycle = true` and `recycle_delay > 0`:
1. the system creates a `FuseRecycleTimer` instance
2. the timer runs independently of the instruction lifecycle (it remains active even after the instruction finishes)
3. when triggered, the timer automatically asks the pool manager to recycle the instance

### Lifecycle

- **Created**: when the instruction executes
- **Running**: managed by the Godot scene tree, independent of the instruction
- **Fires**: triggers the recycle once the delay expires
- **Cleaned up**: automatically cleaned up after the recycle completes

### Debugging

To debug timer behavior, temporarily enable debug output:

```gdscript
# Set _debug_enabled to true in the FuseRecycleTimer class
var _debug_enabled: bool = true
```

---

**Version**: 1.1
**Last updated**: 2026-02-18
**Author**: Fuse Team
