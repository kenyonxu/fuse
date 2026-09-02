> 🌐 [**中文版**](../../../zh_CN/user_docs/Introductions/10-condition-system.md) | English

# Teaching Logic to Think: Fuse's Condition System and AND/OR/NOT Composition

The previous chapter gave the event system a full treatment—events like `OnInterval`, `OnTimer`, `OnReceiveEvent` are pairs of eyes fixed on the game world, always ready for "when to act". But watching "when" alone isn't enough. In real games the same event often needs different reactions in different situations: the player presses the attack key, but the character is stunned and can't strike; an enemy enters view, but doesn't lunge because it isn't within attack range yet. After this chapter you can give your Trigger a thinking "brain"—it no longer merely "executes when it hears an event", but "understands the event, evaluates conditions, then decides whether to act". That is the whole point of Fuse's condition system.

## The Condition System at a Glance: 55 Decision Bricks

Fuse's condition system currently has 55 conditions spread across nearly 20 subcategories: composite logic, variables, distance, navigation, math, strings, arrays, dictionaries, time, physics, nodes, node operations, input, animation, rendering, UI, system, scene, state, and scope. From "is health below 30%" to "has the enemy flanked behind the player", from "is it daytime" to "is the running platform mobile"—they cover nearly every "should we do this" judgment in game logic.

But the count itself isn't the point. The point is that conditions compose. A standalone `CheckDistance` can only answer "are we close", yet what real games want is "close AND has mana AND not on cooldown". What Fuse gives you is not a pile of loose blocks but a composite condition system that nests to arbitrary depth. That is what sets it apart from an "enumerated condition list".

## Four Composite Conditions: AND/OR/NOT, Made Visual

The "logical glue" of the whole condition system is these four composite conditions:

- **CheckAll** (all conditions met): AND logic—true only when every child condition is true.
- **CheckAny** (any condition met): OR logic—true when any child condition is true.
- **CheckNot** (not): NOT logic—inverts the child condition's result.
- **CheckComposite** (composite condition): supports more flexible custom combinations, for building complex condition trees.

The most crucial rule: **a composite condition's children can be any conditions, including another composite condition**. This means you can build a condition tree to any depth, with no layer limit.

Take the most common "can the character attack" check. The player pressed the attack key, but the character must simultaneously satisfy "alive, has mana, skill off cooldown" before truly striking. The build: put a `CheckAll` at the top level with three child conditions hanging under it—`CompareVariable` checks mana, `CheckHealthValue` checks health, `CheckCountdownFinished` checks the cooldown. In the Inspector this is a collapsible tree, more intuitive than writing `if hp > 0 and mp >= 10 and not in_cooldown` in code.

`CheckAny` fits "any one triggers" scenarios. Take a player-death check: three conditions—health less than or equal to 0, fell off screen, timed out—any one true means Game Over. Writing it as a CheckAny instead of three parallel Triggers keeps the logic more cohesive and makes it easy to hook up a single GameOver instruction.

`CheckNot` looks simple but sees heavy use in practice, because it reuses existing conditions to express negated judgments. For "enemy not in view", rather than hunting for a dedicated "distance greater than view range" condition, just wrap a `CheckDistance` in `CheckNot`. One reuse, one less wheel reinvented.

## Nesting: Building Decisions into a Tree

What truly shows the power of composite conditions is nesting. Consider a smart enemy-seeking AI's judgment:

```
CheckAll:                                   # all must pass
  - CheckAny:                               #   enemy state: alive OR revivable
      - CompareHealthThreshold (hp > 0)
      - CheckVariable (revive_state == true)
  - CheckNot:                               #   AND not invincible
      - CheckVariable (invincible_time > 0)
  - CheckAny:                               #   AND distance OR path, either passes
      - CheckDistance (distance < attack range)
      - CheckPathAvailable (path available)
```

Translated into plain language, this condition tree reads: "chase only when the enemy is alive or revivable, AND not invincible, AND either within attack range or with a path it can walk over". The whole judgment is a collapsible tree in the Inspector, where every node can be clicked open to see its parameters. Compared to four levels of nested if-else in code, readability is if anything higher.

Two performance details are worth remembering. `CheckAll` short-circuits and returns immediately on the first false; `CheckAny` also short-circuits immediately on the first true. So putting the "most likely to fail / most likely to succeed" conditions first saves unnecessary checks.

## Comprehensive Conditions: 14 Dedicated Sensors

Composite conditions handle "how to combine"; comprehensive conditions handle "what to check". This group has 14 conditions scattered across several subcategories, each a dedicated sensor for one specific kind of judgment.

`CheckDistance` is probably the daily workhorse. It directly compares the distance between two nodes (or a node and a position), switching 2D/3D computation via `use_3d`. Paired with `OnInterval` for "check for nearby enemies every second", it feels effortless.

`CheckPathAvailable` is built for NavigationAgent—it checks whether the agent has a valid path to the target position. Nearly mandatory in tower defense and RTS games that need to judge "can we get there".

`ExpressionCondition` is moat-grade (the expression system was covered in depth in chapter 4). It takes a GDScript boolean expression directly, then maps variable references in through variable binding. One expression condition is worth several basic comparison conditions.

For rendering and UI there are `CheckIsOnScreen` and `CheckUIVisible`. The former checks whether a node is inside the current viewport, commonly used for "recycle bullets once they fly off screen"; the latter checks a UI element's visible property, commonly used for "block game input while the pause menu is open".

Two are health-related: `CheckHealthValue` judges "is health equal to the target value", while `CompareHealthThreshold` judges "health against a threshold" with comparison operators. For boss phase switches and low-health warnings, the latter fits better.

Two are string conditions: `CheckStringContains` checks substring containment, `CheckStringLength` checks length. At the system level there are `CheckFrameRate` and `CheckPlatform`.

Finally there is `CheckPreloadStatus`, a key link in the scene preloading pipeline—it can check whether preloading is in LOADING, LOADED, or FAILED state, and is the judgment basis for "switch scenes only after loading completes".

## Time Conditions: Making Logic Timing-Aware

There are 4 time conditions, dedicated to "when" judgments:

- **CheckTimeReached** (time reached): has the current time reached the specified point.
- **CheckTimeRange** (within time range): is the current time within the specified range, with cross-midnight wrap support.
- **CheckCountdownFinished** (countdown finished): has the countdown completed.
- **CheckGameTime** (game time): compares against the game's total run time.

`CheckTimeRange`'s most classic use is the day/night cycle. For example `start_time: 06:00`, `end_time: 18:00` (seconds or time format), and with `wrap_around` enabled it also handles "night crossing midnight".

`CheckCountdownFinished` is the standard companion for skill cooldowns and works independently without being bound to a specific event—write the current time into a variable when the skill fires, then use the condition to check "has start time plus duration passed".

`CheckGameTime` serves timed modes like "declare victory after 5 minutes of game time".

## In Practice: An Enemy AI That Judges

Here is a small working case: a smart enemy-seeker. Requirements: check every 0.5 seconds; if the player is within 15 meters, a reachable path exists, and the skill cooldown has finished—chase the player; otherwise hold position.

Build steps: attach a Runner to the enemy node, pick `OnInterval` as the Trigger, set `interval_seconds` to 0.5. In the Runner's condition slot put a `CheckAll` with three children: `CheckDistance` (distance < 15), `CheckPathAvailable` (reachable path), `CheckCountdownFinished` (cooldown finished). When the conditions pass, run `NavigateToPosition` to move the enemy. Add another Runner wrapping the above conditions in `CheckNot` to stop the chase when they fail.

Once running, the enemy starts chasing the moment the player comes close with a viable path, and stops automatically when the player runs far away or reaches unreachable terrain.

## Conditions, Events, Instructions: A Three-Part Thinking Loop

Looking back: conditions themselves do nothing—they only "judge". Instructions actually complete the action, and events trigger the judging. The three form a complete "think-act" loop:

- Events answer "when to check"
- Conditions answer "whether to do it"
- Instructions answer "what to do"

Almost all game logic fits this triple. When you find a Trigger's logic getting messier and messier, don't rush to add conditions—ask yourself three questions: is the event the right one, are the conditions cleanly split, is the instruction chain too long.

## Summary

Fuse's condition system is not just "55 enumerated items". Its real value lies in the arbitrary-depth nesting held up by the four composite conditions, plus the judgment coverage of the comprehensive and time conditions. Combined with the event-condition-instruction triple model, you can build almost any "thinking" logic in a visual interface.

After judging usually comes acting on the game world—switching scenes, spawning enemies, changing node properties. The next chapter steps into Fuse's "hands and feet": scene switching, background loading, and node add/remove/modify, showing how to manage the whole game world.
