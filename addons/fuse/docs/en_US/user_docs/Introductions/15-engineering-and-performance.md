> 🌐 [**中文版**](../../../zh_CN/user_docs/Introductions/15-engineering-and-performance.md) | English

# Taking Fuse to Production: Preset Reuse, Object Pools, Background Loading, and Multithreaded Conditions

This is chapter 15 of the Introductions series, the close of the engineering arc. The previous 14 chapters took apart every brick, every chain, and every debugging and review tool. But being able to build logic and being able to ship a project are two different things—shipping means reusing one well-tuned Trigger set across ten projects, holding frame rate while bullets fill the screen, eliminating that stutter on scene switches, and still responding in real time with hundreds of conditions stacked up. This chapter tackles these "last mile" problems in one pass: the preset system moves logic across projects like building blocks, object pools stop high-frequency instantiation from eating performance, scene preloading removes switch stutter, multithreaded conditions compress judgment to the millisecond level, and RuntimeInstance lets multiple Triggers run concurrently without interference. After this chapter, Fuse goes from "a pleasant visual tool" to "an engine layer that can take production load".

Picking up from the previous chapter: debugging and review are in place, but shipping takes engineering capability.

## The Preset System: Four Reuse Levels from L1 to L4

The preset system's core is "distilling assembled logic into portable resources", with four levels by node type:

- **L1 (ActionRunner)**: serializes only the instruction sequence, for reusing pure logic fragments
- **L2 (Trigger)**: serializes event config + instructions, the most-used level
- **L3 (Runner)**: serializes signal bindings + instructions
- **L4 (MultiEventTrigger)**: serializes multi-event bindings, for reusing composite triggers

Export generates both `.tres` (Godot-native resource) and `.json` (human-readable / version-controllable) at once. Export is gated by upfront validation—triggers that aren't fully configured don't show the export button. Four sample presets ship built-in and serve as ready-made templates.

## NodePath Mapping: The Key to Cross-Scene Reuse

A three-tier strategy matches automatically: relative path structure match → global same-name node search → manual selection. The mapping panel also shows the preset's variable dependencies, so you know what's still missing before importing.

## Object Pools: High-Frequency Instantiation Stops Eating Frames

The entry point is the `InstantiateScene` instruction, with new pooling properties: initial pool size, max size, auto recycle, recycle delay. Two dedicated companion instructions: `WarmUpPool` (prewarm) and `RecyclePooledScene` (recycle).

Two modes: automatic (set a recycle delay; recycling happens automatically when it expires) and manual (explicitly call `RecyclePooledScene`).

**Performance benchmark (1000 bullet spawns)**:
- No pooling: 850 ms
- Pooled, cold start: 420 ms (50.6% improvement)
- Pooled, prewarmed: 120 ms (85.9% improvement)

Memory: no pooling peaks at 125 MB with 1000 GCs; pooled and prewarmed peaks at 45 MB with 50 GCs.

**The hard requirement for reset methods**: pooled scenes must implement `reset()` to restore position/rotation/scale/velocity/visibility/collision. This is not an optional optimization.

## Scene Preloading: Eliminating Switch Stutter

`PreloadSceneInstruction` calls `ResourceLoader.load_threaded_request()` underneath, with two modes: Async Now (blocking wait) and Async Later (returns immediately without blocking, used for loading ahead of time).

Five statuses: NOT_LOADED / LOADING / LOADED / FAILED / TIMEOUT. Pair with `CheckPreloadStatus` polling, and instantiate only after loading completes—with near-zero latency.

## Multithreaded Conditions: Spreading Hundreds of Checks across Cores (Moat Deepens)

`ParallelConditionEvaluator` moves condition evaluation onto worker threads for parallel execution; the more conditions, the bigger the win—parallel evaluation of double-digit condition counts already cuts judgment time to a fraction of the serial run, and the gap widens further at hundreds of conditions.

Enabled by default, it can be turned off globally in the Threading settings; `max_parallel_conditions` (default 8, cap 16) controls the parallelism. The parallelism runs in safe mode: only conditions marked thread-safe enter the worker threads; unsafe ones automatically stay on the main thread as a serial fallback.

## RuntimeInstance: Concurrency without Interference

Every Trigger execution gets an independent RuntimeInstance, so variables never bleed into each other. Instruction resources are compiled and cached on first execution and reused afterwards, skipping repeated compilation overhead.

## In Practice: The Seven-Step Pre-Launch Checklist

1. **Distill for reuse**: export repeated logic as presets
2. **Pool high-frequency objects**: bullets/enemies/effects all get object pools
3. **Add reset methods**: check every pooled scene root node's reset()
4. **Preload heavy scenes**: load boss fight scenes ahead of time with Async Later
5. **Check condition parallelism**: confirm parallel evaluation is enabled for multi-condition Triggers
6. **Clean out debug leftovers**: remove all Print/BreakpointInstruction before release
7. **Topology final review**: filter Errors only, confirm there are no errors, export the report for the record

## The Penultimate Chapter's Wrap-Up: What Fuse Actually Is

Fifteen chapters in, Fuse's real value is not the counts—185 instructions, 70 events, 55 conditions—but a complete engineering pipeline: variables manage data, expressions manage computation, flow control manages logic, animation and physics manage presentation, events manage communication, conditions manage judgment, the generator manages extension, debugging manages troubleshooting, Topology manages review, and presets, pooling, and multithreading manage production-grade performance.

A visual system's moat was never "you can drag and drop"—it's that "after dragging, you can still debug, review, reuse, survive production load, and **hand off**". The first four were covered before this chapter; the fifth—handing a stabilized system to an AI agent to write Fuse-independent engineering code—is the subject of the next (and final) chapter: the preset AI generation loop, topology export, System artifacts, and one-click handoff packaging.

If you have read all the way here from chapter 1, go back to chapter 1's panoramic frame and re-check it against what you now know—you should be able to understand the real engineering meaning behind every brick.
