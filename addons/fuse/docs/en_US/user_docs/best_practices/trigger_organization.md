> 🌐 [**中文版**](../../../zh_CN/user_docs/best_practices/trigger_organization.md) | English

# Trigger Organization and Race-Condition Avoidance

## Overview

When the Fuse units in a scene (Trigger / MultiEventTrigger / Runner) grow from a dozen to over a hundred, the question shifts from "how to build" to "how to manage": who shares data with whom, which concurrent triggers fire first, and how to locate problems. This practices guide covers two things — **understanding the real boundary of race conditions**, and **organizing triggers once the scene grows**.

## 1. What Actually Counts as a Race: Write-Write Only

Topology static analysis classifies cross-unit variable relations into three types, and this classification is the authoritative definition of the race boundary:

| Relation type | Meaning | Topology panel mark |
|--------|------|--------------|
| Write → read | One unit writes the variable, another reads it | 📝 Normal data flow |
| Signal | One unit emits a signal, another receives it | 🔗 Normal communication |
| **Write → write** | **Two units both write the same variable** | 🔥 **Race warning** |

**Write-read is not a race, it is a dependency** — a producer-consumer relation like "health updated → health bar refreshes" is exactly what the event system is designed for. The real race is **two Triggers writing the same variable**: the firing order of the two is undefined, the later write overwrites the earlier one, and nothing reports an error — the symptom is "the value is occasionally wrong", one of the hardest kinds of bug to track down.

### Why Write-Write Is Dangerous

When two Triggers fire in the same or adjacent frames (on-hit damage × pickup healing), the execution order depends on event arrival order, parallel evaluation scheduling, even scene tree position. The result is that the variable value depends on "who happened to run last" — correct today, wrong tomorrow, correct again on another machine.

### Investigation Tools

The race warnings (yellow 🔥) on the Topology main screen list every write-write conflict pair and the shared variable names. The [Topology guide (Chinese)](../../../zh_CN/user_docs/Introductions/14-Topology拓扑主屏.md) details the panel operations — this article is about what to do after you see the 🔥.

## 2. Five Ways to Avoid Races

In priority order from high to low, consider these in sequence when you hit a 🔥 warning:

### 1. The Single-Writer Principle (Preferred)

**Allow only one Trigger to write a variable; everything else stays read-only.** This is the most thorough fix:

> On-hit damage and pickup healing both write `hp` → converge "health change" into a single `ApplyHpDelta` Runner, which the on-hit and pickup sides both call with a positive or negative delta.

Invoke it with the `RunRunner` instruction (the "function call" of the visual system). Once the writer is converged to one place, ordering problems disappear and the health logic has a single point of change.

### 2. Scope Isolation

When a write-write conflict happens in a shared scope, consider demoting the variable's scope:

- Two enemy Triggers writing "the same" health → they should really each write their own: demote health from GLOBAL to **SCOPE** (one container per enemy subtree), and the conflict disappears naturally
- Rule of thumb: **when the writers belong to different object instances, the variable should follow the instance** — the SCOPE container hangs off the instance subtree root

For the complete rules of scope selection, see the [Variable System Guide](../guides/01-variable-system-guide.md).

### 3. Trigger Control: cooldown and trigger_once

When the conflict comes from high-frequency repeated firing, throttle the writer:

- `cooldown`: continuous touches inside the area settle only the first one — solves "standing in a trap losing health every frame"
- `trigger_once`: cutscene/initialization-style logic naturally needs to run only once
- The MultiEventTrigger's trigger controls are **configured per binding**; set them one by one when multiple events share a node

The options are in the Trigger's Inspector trigger-control group (`cooldown_mode: GLOBAL_COOLDOWN`, etc.). Note this is **mitigation**, not a cure — two low-frequency writers can still collide; the single-writer principle takes priority.

### 4. Event Semantics Instead of State Polling

Write-write conflicts often come from "poll-style design": several Triggers read state on `OnInterval` and then write flags. Switch to event semantics — the side whose state changes **emits an event** (Event Bus / custom signal), and consumers act when `OnReceiveEvent` fires:

> Three Triggers poll `game_state` and each write their own `state_dirty` flag → the state-machine Trigger emits `SendEvent("state_changed")` when it switches, and the three consumers switch to reacting to the event, each doing only its own thing.

The writers go from three to one (the state machine), and all consumers are read-only.

### 5. Merge into MultiEventTrigger

If several Triggers on the same node responding to multiple events are writing the same set of variables, they most likely should be one piece of logic: after merging into a MultiEventTrigger, the multiple events execute **in order** inside one unit, and write-write becomes in-unit sequential semantics (mutually exclusive branches or first-come-first-served), eliminating the race. Right-click the scene tree node to merge.

## 3. Organization Practices

### The Selection Ladder Still Applies

Once units multiply, the progressive principle of [trigger selection](../guides/02-trigger-selection-guide.md) still holds: simple signals use a Runner, cases needing event filtering/trigger control use a Trigger, and multiple events on the same node use a MultiEventTrigger. One organization-level addition:

- **Group by "object", not by "function"** — player-related units hang off the player subtree, enemy logic travels with the enemy prefab. SCOPE isolation, topology readability, and scene splitting all come in one move
- Cross-object communication goes through the Event Bus, not "shared GLOBAL variable polling" (see method 4 above)

### Naming

Give Trigger node names an "object + semantics" shape: `Player_OnDamaged`, `Boss_Phase2_Entry`. This is the name shown in the topology panel, race warnings, and export reports — `Area2D7 (Trigger)` in a race list says nothing.

### Final Review Workflow

Run this once before a release or milestone (together with the debugging workflow from the [Debugging Guide](../guides/25-debugging-guide.md)):

1. Topology main screen → filter to "errors only" and drive errors to zero
2. Go through the race warning area (🔥), handling each with the five methods or confirming it is harmless
3. Export the problem report for the record (`user://fuse_problems_report_*.txt`) and archive it with the milestone — next time you compare the delta

### Cases Where a Race Is "Confirmed Harmless"

Warnings are static analysis, and legitimate write-write scenarios exist: writing the same variable inside mutually exclusive branches (the two arms of an IfElse each write once), or an initialization Trigger and a reset Trigger living in different lifecycle phases. These can be let go once the topology clearly shows the execution paths are mutually exclusive — but **treat every warning as a real problem by default**; the burden of confirming mutual exclusion is on you.

## FAQ

### There are many race warnings — where to start?

Start with GLOBAL variable write-writes (the largest shared surface) and look at SCOPE ones last. Record a stretch of actual gameplay with the variable watcher and observe the real write sequence of the warned variables; that quickly separates true conflicts from false positives.

### Does parallel condition evaluation create more races?

No. What runs in parallel is **condition evaluation** (read-only judgment); the paths of instruction execution and variable writes are unchanged — which is exactly why the condition "read-only contract" (see [Custom Condition Creation Best Practices](custom_condition.md)) exists.

### Can a Runner's manual `run()` call collide with event triggering?

A manual call makes the code side a "code-side writer" that participates in races. Code invocation follows the single-writer principle too: make the code-invoked Runner the only writer of that variable, with every other unit read-only.

---

**Related docs:**

- [Topology Main Screen (Chinese)](../../../zh_CN/user_docs/Introductions/14-Topology拓扑主屏.md) — panel operations for race warnings
- [Variable System Guide](../guides/01-variable-system-guide.md) — the complete rules of scope isolation
- [Trigger Selection Guide](../guides/02-trigger-selection-guide.md) — choosing among the three trigger types
- [Preset Reuse and AI Collaboration Practices](preset_reuse.md) — building-block reuse of unit logic and cross-project migration
