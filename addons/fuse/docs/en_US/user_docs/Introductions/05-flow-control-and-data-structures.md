> 🌐 [**中文版**](../../../zh_CN/user_docs/Introductions/05-flow-control-and-data-structures.md) | English

# If, Loops, Arrays, and Dictionaries: Building Complex Logic in a Visual System

By the end of this chapter you will have pushed Fuse from "can compute formulas and play animations" to "can write real program logic". How enemy AI flees when health drops below thirty percent, how a wave system spawns N enemies per wave and waits three seconds before the next, how an inventory stores item counts with a dictionary, how a leaderboard sorts and grabs the top score — logic that conventional wisdom says "requires writing code" can all be assembled in the Inspector with Fuse's 16 flow control instructions plus 18 array operations and 16 dictionary operations. And this chapter will break a common misconception: a visual system does not mean only simple tasks like "press button, play animation" — it can absolutely write complex logic with branches, loops, and data structures.

Carrying over from the previous chapter: expressions let us compute damage, compose text, and make judgments. But judgments without branches and computation without loops leave logic stuck at the "one-shot straight line" stage. To make logic truly run like a program, we need the skeleton of flow control and the collection structures that carry data.

## First, Correcting a Misconception: Visual Does Not Mean Simple

Many people's impression of visual programming stops at "connect-the-dots": press button → play animation, walk into area → trigger dialogue. Such trigger-response logic is indeed easy, but the moment a requirement mentions "iterate all enemies", "loop until health hits zero", or "look up a grade from score in a table", many people's first reaction is "now we need code, right?"

Fuse's flow control instruction group exists precisely to close off that retreat. It turns if/else, for, while, break, continue, function calls, pause/resume — the most fundamental flow primitives of programming languages — all into visual components. Combined with array and dictionary operations, the logic complexity you can build is no different in essence from writing GDScript — the only difference being that you use the Inspector and dropdowns instead of a keyboard.

This is an important positioning signal from Fuse: it is not "a simplified tool for people who can't write code" but "another way of expressing logic", whose expressive power is not discounted by being visual. This point runs through everything below.

## The Full Flow Control Toolkit: 16 Instructions

Fuse's flow control instructions total 16, in six groups. A table first, to build a global impression:

| Group | Instructions | What they do |
|------|------|--------|
| Conditional branches | **IfThen** (if/then), **IfElse** (if/else), **RunConditionCheck** (run condition check) | Execute sub-instructions when true; separate true/false branches; run a condition check first, then decide |
| Loops | **ForLoop**, **ForEach**, **WhileLoop**, **Count** | Counting loops, collection iteration, conditional loops, event-driven accumulators |
| Loop control | **BreakLoop**, **ContinueLoop** | Break out of the current loop; skip to the next iteration |
| Waits | **Wait**, **WaitUntil**, **WaitForEvent**, **WaitForSignal** | Wait seconds; poll until a condition holds; suspend until an Event Bus event / a specified signal arrives |
| Game control | **PauseGame**, **ResumeGame** | Pause the scene tree; resume |
| Advanced calls | **RunRunner** (run runner) | Triggers another ActionRunner — a "function call" |

A few points that differ from coding habits:

The "condition" of `IfThen` and `IfElse` is not an expression text box but a Condition resource — that is, the ExpressionCondition from the previous chapter, or a more complex `CheckAll` / `CheckAny` composite. You can stuff an arbitrary condition tree into an if.

`ForEach` has two array sources: from a variable, or from a node group. That means you can iterate every enemy in the "enemy group" directly, without manually collecting them into an array first; to iterate a node's children, first use instructions like `GetAllChildren` to collect them into an array and pass that in.

`Wait` is an asynchronous instruction — the instructions after it only continue once the wait ends — which is exactly right for pacing like "pause three seconds between waves".

`BreakLoop` / `ContinueLoop` only affect the innermost loop; remember that scope with nested loops.

`RunRunner` is the "function call" of visual logic: factor a piece of shared logic into a standalone Runner resource, specify the Runner node to trigger via the `target_runner` parameter, reuse it in many places, and change it once to change it everywhere.

## In Practice: Enemy AI Decisions

Start with the most common piece of logic built from branches — enemy AI. The requirement is simple: check every frame; if close to the player, chase; if health is below thirty percent, flee; otherwise attack.

```
Event: OnProcess (per-frame processing)
Instructions:
  → IfThen(condition: distance to player < 200)
      → chase the player (MoveCharacterBody2DComposite toward the player)
  → IfElse(condition: health <= 30%)
      true branch  → flee (move away from the player)
      false branch → attack (play the attack animation + damage check)
```

Here the first `IfThen`'s condition is `CheckDistance` (object distance), and the second `IfElse`'s condition can use `CompareHealthThreshold` (health below/above) or directly use the previous chapter's `ExpressionCondition` with `{local:hp} / {local:max_hp} <= 0.3`. Both work; the former is a ready-made condition component, the latter more flexible.

Note these two ifs are **side by side**, not nested. Fuse's instruction sequences execute top to bottom by default, with each IfThen judging independently. If you want "first judge distance, then judge health under the premise of being close", drag the second IfElse into the first IfThen's sub-instruction list — sub-instructions nest infinitely; that's how branches combine.

## In Practice: Wave Spawning (Loops + Waits + Arrays)

Combine loops and waits into a wave system. Requirement: after the game starts, 5 waves total; each wave spawns 3 enemies; wait 3 seconds between waves.

```
Game start (OnReady)
  → ForLoop(i, loop_count=5)
      loop body:
        → ForLoop(j, loop_count=3)
            loop body:
              → GetRandomPointInRange (pick a random spot near the spawn point)
              → InstantiateScene (instantiate the enemy scene at that spot)
              → ArrayAdd (add the new enemy to the "alive enemies" array)
        → Wait(3 seconds)
```

This is a double-nested `ForLoop`: the outer loop runs 5 waves, the inner spawns 3 enemies per wave. After the inner loop ends, `Wait` pauses 3 seconds before the next wave. Note that `Wait` sits in the outer loop body, after the inner loop — its position decides it waits "between waves" rather than "between enemies".

`ForLoop`'s core parameter is `loop_count`, with the optional `index_variable` (default `"i"`) to get the current iteration index inside the loop body. It is equivalent to `for i in range(count)` in code and does **not** have separate "start/end/step" parameters.

`ForLoop` and `Count` are easily confused — here's the distinction: `ForLoop` runs the whole loop in one go (say, spawning 5 waves), while `Count` is a simple counter that increments its internal counter by `increment` each time it executes. Use ForLoop for waves; for "unlock an achievement after 10 kills", pair `Count` with a condition component checking its current value.

## In Practice: Pause Menu (Game Control + Branching)

The pause menu is a classic flow-control pairing, using `PauseGame` / `ResumeGame` with `IfThen`:

```
Event: OnInputKey (ESC key)
Instructions:
  → IfThen(condition: game not paused)
      → PauseGame
      → ShowHideUI (show the pause menu panel)
  → IfThen(condition: game already paused)
      → ResumeGame
      → ShowHideUI (hide the pause menu panel)
```

The two `IfThen`s are mutually exclusive, switched by an "is paused" variable (or node active state). `PauseGame` pauses the entire scene tree; `ResumeGame` resumes. A very clean state-switching pattern.

## Arrays: 18 Operations for Collections

Flow control solved "how to walk"; data structures solve "what to carry". Fuse's array operations total 18, covering add/remove/query/update, sorting, statistics, and vector operations.

| Group | Instructions |
|------|------|
| Add/remove/update | **ArrayAdd** (add array element), **ArrayInsert** (insert into array), **ArraySet** (set array element), **ArrayRemove** (remove array element), **ArrayClear** (clear array), **ArrayGet** (get array element) |
| Search | **ArrayFind** (find array element), **ArrayContains** (check array contains), **ArrayRandom** (get random element), **ArraySize** (array size) |
| Reorder | **ArrayReverse** (reverse array), **ArrayShuffle** (shuffle array), **ArrayNumericSort** (numeric sort), **ArrayVectorSort** (vector sort) |
| Statistics | **ArrayNumericGetLargest** (get largest value), **ArrayNumericGetSmallest** (get smallest value) |
| Vectors | **ArrayVectorGetClosest** (get closest vector), **ArrayVectorGetFurthest** (get furthest vector) |

Arrays have two sources: from a variable, or from a node group. That means you don't need to manually convert the enemy group into an array first — `ArraySize` can take the member count of the "enemies" group directly. To iterate children, first collect them into an array with instructions like `GetAllChildren`.

A few practical points:

`ArrayGet` / `ArraySet` / `ArrayInsert` / `ArrayRemove` all support **negative indices**; `-1` is the last element. Handy for "grab the array's last enemy" — no need to `ArraySize` then subtract one.

`ArrayNumericSort` and `ArrayVectorSort` sort **in place**, modifying the original array directly. `ArrayShuffle` uses the Fisher-Yates algorithm, so the shuffle is fair.

Sorting plus statistics makes a leaderboard: `ArrayAdd` to add a score → `ArrayNumericSort` descending → `ArrayNumericGetLargest` to grab and display the top score. Three steps, done.

The vector group is a treasure for 2D/3D games. The most common "find nearest enemy": collect all enemy positions into a vector array, compare against the player's position with `ArrayVectorGetClosest`, get the nearest enemy's coordinates back directly, then feed it to `LookAt` — an aiming routine in two or three steps. The reverse, `ArrayVectorGetFurthest`, finds the furthest, suited to "flee from the furthest enemy" AI.

## Dictionaries: 16 Operations for Key-Value Pairs

Dictionaries are the mainstay of RPGs and save systems. Fuse provides 16 dictionary operations in six groups:

| Group | Instructions |
|------|------|
| Basics | **DictSetKeyValue** (set dictionary key-value), **DictGetValue** (get dictionary value), **DictRemoveKey** (remove dictionary key), **DictClear** (clear dictionary), **DictSize** (get dictionary size), **DictDuplicate** (duplicate dictionary) |
| Bulk | **DictGetKeys** (get dictionary key list), **DictGetValues** (get all dictionary values), **DictMerge** (merge dictionaries) |
| Nested paths | **DictGetByPath** (get dictionary path value), **DictSetByPath** (set dictionary path value) |
| Numeric ops | **DictModifyNumber** (modify dictionary number), **DictMathOp** (dictionary math operation), **DictToggleBoolean** (toggle dictionary boolean) |
| JSON | **DictToJson** (dictionary to JSON), **DictFromJson** (JSON to dictionary) |

The dictionary source is a Scope Variable or Global Variable — because dictionaries are usually structured data shared across nodes and scenes; putting them in local variables rarely makes sense.

Most worth emphasizing is **nested path access**. `DictGetByPath` and `DictSetByPath` accept a slash-separated path, like `"player/stats/hp"`, equivalent to `dict["player"]["stats"]["hp"]`. That means you can store an entire nested data tree in one flat dictionary, without layer-by-layer `DictGetValue` extractions. Extremely friendly to saves and config tables:

```
Read difficulty:    DictGetByPath(config dict, "settings/difficulty")
Change a setting:   DictSetByPath(config dict, "settings/difficulty", "hard")
```

`DictModifyNumber` is another high-frequency instruction, dedicated to adding and subtracting numeric keys. With an inventory keyed by item ID storing counts, consuming one is `DictModifyNumber(inventory, item ID, -1)` — three steps ("get value, subtract one, write back") in one. `DictToggleBoolean` is similar — one-click flipping of toggle-style states.

The `DictToJson` / `DictFromJson` pair completes the last mile of saving: serialize the player-data dictionary into a JSON string, store it into the global save slot with `SaveGlobalVariables` from the previous chapter; when loading, reverse it with `LoadGlobalVariables` → `DictFromJson`. A complete player-data management chain:

```
Initialize → DictSetKeyValue(player data, "name", "勇者")
             DictSetKeyValue(player data, "level", 1)
Level up   → DictModifyNumber(player data, "level", +1)
Save       → DictToJson(player data) → SaveGlobalVariables
Load       → LoadGlobalVariables → DictFromJson → DictGetValue
```

A few details: `DictSetKeyValue` automatically creates a new dictionary if one doesn't exist — no need to worry about initialization order; `DictGetValue` supports a default-value parameter, returning the default instead of erroring when the key is missing; `DictMerge` overwrites existing keys by default, changeable to keeping original values via the `overwrite_existing` option.

## Real Logic in a Visual System: Putting the Four Pieces Together

This chapter's title is "building complex logic", so to close, let's assemble flow control, arrays, dictionaries, and the previous chapter's expressions into a fairly complete example — proof of the visual system's expressive power.

Requirement: a loot-drop system. After killing an enemy, look up the loot table (a dictionary) by enemy level, add the loot to the inventory (a dictionary), and if the inventory is full (array length reached) trigger a warning, otherwise play the pickup animation.

```
Event: enemy death (OnHealthChanged → hp <= 0, or a custom signal)
Instructions:
  → DictGetByPath(loot table, "level_" + str({local:enemy_level}) + "/items")
      # fetch the loot list for that level, store it into the drops array
  → ForEach(drops)
      loop body (current element = item ID):
        → ArraySize(inventory array) → store into bag_size
        → IfElse(condition: {local:bag_size} >= {local:max_slots})
            true branch  → SetUIText("背包已满") + TweenShakeAnimation (shake warning)
            false branch → DictModifyNumber(inventory dict, item ID, +1)
                           + TweenPopAnimation (pickup pop animation)
  → ArrayRemove(alive enemies array, current enemy)
  → IfThen(condition: ArraySize(alive enemies array) == 0)
      → trigger the next wave (RunRunner calls the wave-spawning Runner)
```

In this piece of logic you saw: dictionary nested-path lookups, ForEach iterating loot, array size checking a full inventory, IfElse dual branches, dictionary numeric increments tracking the inventory, Tween animations for feedback, RunRunner reusing wave logic, ArrayRemove maintaining the alive list, and IfThen checking for total wipe. This dozen-or-so instruction combination would be thirty to forty lines of GDScript at minimum. In Fuse it's a readable instruction sequence in the Inspector, each entry clickable to inspect parameters and attachable with breakpoints for single-stepping (debugging gets its own chapter later).

That's the proof of "real logic in a visual system". It is not a toy — it's an expressive system that can carry medium-complexity game logic.

## Caveats to Keep in Mind

`WhileLoop` must be guaranteed to eventually turn its condition false, otherwise it's an infinite loop freezing the game. When unsure, prefer `ForLoop` (with a definite end value).

`BreakLoop` / `ContinueLoop` only break the innermost loop. In a double ForLoop, an inner break leaves the outer loop running.

`Wait` is asynchronous — the instructions after it will wait. But note: if the trigger is disabled or the node freed during the wait, the waiting logic may never finish — factor that into long sequences.

If you `ArrayRemove` elements while `ForEach` is iterating, indices get scrambled. The correct approaches: first iterate to collect what to delete, then batch-delete afterwards; or delete in reverse order while iterating.

In-place sorts (`ArrayNumericSort` / `ArrayVectorSort`) modify the original array. If you want to keep the original order, first save a copy of the array into another variable.

## Next Chapter: Bring the Screen to Life

The logic skeleton is built — branches, loops, data structures all in place — but the game is still one that "can compute, can judge, yet cannot move". Enemy attacks have animation playback but no hit shake; UI popups show and hide but have no springy entrance; item pickups have no grow-and-fade feedback.

**In the next chapter, I'll cover Fuse's full animation toolkit: AnimationPlayer's play/stop/blend/speed, how the 6 animation events drive state switching, and how Tween's 13 preset animation and effect instructions polish game feel.** At that point, your visual logic not only runs — it looks and moves good.
