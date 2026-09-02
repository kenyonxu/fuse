> 🌐 [**中文版**](../../../zh_CN/user_docs/Introductions/03-三层变量系统.md) | English

# Don't Let Global Variables Run Wild: Managing Fuse's LOCAL / SCOPE / GLOBAL Three-Layer Variables

By the end of this chapter you will have a set of judgment criteria: when writing a piece of logic in Fuse, should the data at hand go into LOCAL, SCOPE, or GLOBAL — choose wrong, and at best variables can't be read or everything is lost on scene switch; at worst the save file keeps growing and the game keeps slowing down, with dozens of global variables hanging from start to finish, where touching one moves everything. If you've ever seen one of those projects where "all data gets dumped into global variables", this chapter helps you sidestep that pit at the root.

## First, Decide Where Each Variable Lives

Many newcomers' first instinct with Fuse is to make all data GLOBAL. The instinct is natural — global variables can be read and written anywhere, which sounds like the least effort. But in practice you hit a wall quickly: a temporary distance value computed by a hit animation also goes into global, survives scene switches, gets written into the save on exit, and the save file bloats to several megabytes; worse still are naming conflicts — health is called `hp` and enemy health is also called `hp`, two Triggers each writing their own, values overwriting each other back and forth, and you spend a whole night unable to find out who changed whom.

The root of the problem isn't Fuse — it's picking the wrong "residence". In real life you don't pile everything into the living room: scratch paper is tossed when used up (temporary), the toolbox sits by your workstation for grab-and-go (shared within the workstation), and the household registry is locked in a safe for long-term keeping (global and persistent). Fuse's three-layer variable system is designed along exactly this logic — LOCAL is the scratch paper, SCOPE is the workstation toolbox, GLOBAL is the safe. Nail this mental model down and every usage afterwards follows naturally.

While we're here, let's clear up a common misconception: these three layers are not "tiers of quality" — none is superior to another. The only difference is "how long this piece of data should live, and who should see it". Using GLOBAL for a temporary value is waste; using LOCAL for a player level that must be saved is disaster. The criterion is always the nature of the data itself, never "GLOBAL sounds more powerful".

## Where Each Layer Lives

First, the boundaries in one sentence: LOCAL is confined to a single instruction sequence, SCOPE is confined to the subtree of a container node in the scene tree, and GLOBAL spans the whole game process — lifetime and access cost increase from left to right.

**LOCAL (local).** Lives in the execution context `ExecutionContext`; its lifetime ends together with this instruction sequence — the sequence finishes and the variable is gone. Access is fastest, because it's a direct dictionary lookup. It only serves passing intermediate values inside "the current string of instructions".

**SCOPE (scope).** Lives on a `ScopeVariableContainer` node in the scene tree, covering the subtree that node manages. Multiple Triggers and Runners within the same subtree can share read/write access. When the subtree node is destroyed, the variables are cleaned up automatically and don't leak outside the scene. It's the middle ground between LOCAL and GLOBAL.

**GLOBAL (global).** Lives in `GlobalVariableManager`, a process-level singleton; it stays alive for the entire run of the game and is shared across scenes. Combined with the save system it supports persistence — it's the only layer that can land in a save file.

One sentence to remember the boundaries: **LOCAL is discard-after-use, SCOPE is subtree-shared, GLOBAL is process-resident**. Access speed decreases in the same order — LOCAL is fastest, SCOPE next (it has to look up the container node), GLOBAL slowest (it goes through the singleton manager).

One detail worth knowing in advance: reads and writes on all three layers go through the unified `VariableOperations`, which provides `get_variable`, `set_variable`, and `has_variable`; the first parameter is always the execution context `context`, the second the variable name, and the third specifies the scope. One interface, one way of writing — the only difference is the scope enum value. That means switching scopes between instructions costs you almost nothing; no need to change how you call things.

## LOCAL: Where Temporary Data Belongs

The most common LOCAL misuse is stuffing "intermediate computation results" into GLOBAL too. Computing the distance between two points, accumulating one round of damage, keeping a loop counter — this data is computed, used, and done in the moment; there is no reason whatsoever to let it live until the game ends.

Below is a complete little hit-damage example. When the character is hit, compute the actual damage from attack and defense, store it in LOCAL, and the immediately following instructions read it to deduct HP, show floating text, and add knockback — GLOBAL is never touched:

1. In the Runner's instruction sequence place a **SetVariable** instruction, set `scope` to LOCAL, fill `variable_name` with `temp_damage`, and compute `value` with an expression (attack minus defense; expression syntax is detailed in the next chapter).
2. Follow it with a **MathOperation** instruction that reads LOCAL's `hp` minus `temp_damage`, writing the result back to LOCAL.
3. Then add **SetUIText** to turn `temp_damage` into floating text displayed on screen.
4. When the sequence finishes, `temp_damage` disappears automatically, leaving the save file spotless.

The benefits of this style are obvious: temporary values don't pollute the save, don't clash with same-named variables of other Triggers, and access is fastest. Deciding whether a piece of data should use LOCAL is simple — **ask "will it still be needed after the sequence ends?" If not, LOCAL it is**.

One special reminder about loop counters. Fuse's ForLoop instruction produces temporary values every round — the current index, the current element — and these naturally belong in LOCAL. If you catch yourself putting a loop counter into GLOBAL, you can be almost certain it's a selection mistake.

One more easily stepped-on pit: even if a LOCAL variable shares a name with a GLOBAL, they don't interfere — they live in two entirely different dictionaries. But this cuts both ways: if you thought you were writing LOCAL but actually flipped the scope dropdown to GLOBAL, the variable stays around and is globally visible, persisting into the next level. This is the first thing to check when debugging "variable didn't get cleared" bugs.

## SCOPE: In-scene Sharing and the Inheritance Chain

LOCAL only lives within a single instruction sequence, but often you need to share one piece of data "among several nodes in the same scene" — say, the HP bar, scoreboard, and mana bar all need to read the character's current health. At that point LOCAL is too narrow and GLOBAL too wide; SCOPE sits exactly in the middle.

The approach: attach a `ScopeVariableContainer` node to the UI's root node and give it a `scope_id` (say, `ui`). Then HPBar, ScoreDisplay, and ManaBar inside this container's subtree — any instruction reading or writing SCOPE variables — will find the nearest container by default:

```
GameUI (ScopeVariableContainer, scope_id: "ui")
├── HPBar     (instruction: write hp = 100)
├── ScoreDisplay (instruction: read hp to decide low-health warning)
└── ManaBar   (instruction: read hp to sync bar width)
```

When the scene switches away and GameUI is destroyed, this data is cleaned up automatically and won't linger into the next level. That's what makes it smarter than GLOBAL — its lifetime is bound to the scene, clean and crisp.

**Four sources for pinpointing a container.** When multiple containers coexist in the scene tree (say, one for the player panel and one for the enemy panel), instructions need to specify which one to read from. Fuse provides four `scope_source` options: NEAREST takes the nearest container (default), CUSTOM_ID specifies precisely by `scope_id`, TRIGGER_SCOPE takes the container of the trigger node, TARGET_NODE takes the container along the target node's path. Choose CUSTOM_ID and also fill `custom_scope_id`, and you can read and write across subtrees precisely without cross-reading.

**The inheritance chain: child containers read parent container variables.** This is SCOPE's most overlooked yet most useful capability. Containers can configure an inheritance mode: NONE inherits nothing, READ_ONLY read-inherits the parent container, READ_WRITE read-write-inherits the parent container. This lets you build a "global config → per-level override" structure.

See it in a practical game-difficulty example. Put a container `game_settings` on the root node holding difficulty coefficient, max health, and other global settings, with inheritance mode READ_WRITE; then in each level put a child container `level1`, `level2`, with inheritance mode READ_ONLY. When instructions in a level read `difficulty` and it isn't local, the lookup walks up the inheritance chain and gets `game_settings`'s value; if a level wants to temporarily raise difficulty, it directly writes a same-named variable in its own container to override — affecting only that level, without touching the global. This is structured configuration management, far more controllable than stuffing all difficulty parameters into GLOBAL.

One more practical subtlety about the inheritance chain: reads go "nearest upward", but writes depend on the inheritance mode. A READ_ONLY child container can only read from the parent; writing a same-named variable creates a local copy and doesn't touch the parent — that's exactly the precondition that makes "level overrides global" work. READ_WRITE, meanwhile, is write-through: the child container modifies the parent directly, for scenarios where "the child node is meant to change the global setting". Get these two modes right, and your whole configuration has a clean read/write boundary.

## GLOBAL: Cross-scene State and Multiple Save Slots

GLOBAL is the heaviest layer, and the only one that can persist to disk. It handles two jobs: sharing state across scenes, and saving/loading.

Cross-scene sharing is easy to understand. The player's level, experience, and inventory from the village scene must still be there after switching to the battle scene — this data can only live in GLOBAL. Combined with condition instructions like CompareVariable, you can also make cross-scene judgments like "health below 30 triggers a low-health warning".

What truly makes GLOBAL powerful is its companion save system. Fuse provides two instructions — **SaveGlobalVariables** (save) and **LoadGlobalVariables** (load) — which, together with the `GlobalVariableAssistant` node, can build a complete multi-save-slot flow. Here's a complete RPG multi-slot save example:

First, the save write. Place a Trigger bound to the hotkey S:

1. A **SetVariable** instruction with scope GLOBAL, `variable_name` set to `current_save_slot`, `value` written as `user://saves/slot_01.tres` — recording which slot is currently in use.
2. A **SaveGlobalVariables** instruction with `save_target` set to CUSTOM_PATH, `custom_path` filled with `user://saves/slot_01.tres`, and `save_scope` set to PERSISTENT_ONLY.
3. Then a **Print** printing "Saved to save slot 1".

Loading is the reverse, with a Trigger bound to the hotkey L:

1. A **LoadGlobalVariables** instruction with `load_source` set to CUSTOM_PATH and `custom_path` filled with the same `user://saves/slot_01.tres`.
2. A **Print** printing "Loaded from save slot 1".

One key detail here: `save_scope` is set to PERSISTENT_ONLY. This means only variables flagged with `persistent = true` at creation time enter the save. Player level, gold, and level progress should be saved; temporary globals like cooldown timers and current animation state won't be written without the persistent flag. This rule lets you precisely control save size and avoid stuffing runtime state that shouldn't hit disk into the file.

Multiple slots just duplicate this structure: slot 2 changes to `slot_02.tres`, slot 3 to `slot_03.tres`; each slot is an independent file that never overwrites another. When loading, build the path from the slot number the player picked.

Here an interjection about "loading wipes": when `LoadGlobalVariables` executes, by default it first clears all global variables in memory, then pours in the file's contents. Loading is destructive — don't casually load mid-game, or progress in memory that hasn't been saved is lost. The correct approach is to make loading happen at safe moments like scene switches or returning to the main menu.

**Auto-save and change notifications.** If you don't want to trigger saves manually, attach a `GlobalVariableAssistant` node in the scene: fill `resource_path` with the save path, turn on `auto_load_on_ready` to auto-load when entering the game, turn on `auto_save` to auto-save on exit, and set `auto_save_delay` to debounce frequent disk writes. Be careful with `auto_save_on_change` — saving to disk on every variable change has a big performance cost under high-frequency changes; it defaults to off, and we recommend keeping it off and instead saving manually via instructions at key moments.

Another commonly used capability is change listening. `GlobalVariableManager` emits a `variable_changed` signal carrying three parameters: `name`, `old_value`, `new_value`. When the player's health changes, flash the screen red; when gold increases, update the scoreboard — just wire the signal to the corresponding feedback logic, no polling needed. The Assistant also provides a `variable_modified` signal, which is more convenient to hook at the scene level.

## Selection Reference Table

Gather the decision criteria for all three layers into one table and just follow it:

| Data characteristic | Which layer | Examples |
|---|---|---|
| Computed and consumed within a sequence, discarded after | LOCAL | Damage intermediates, loop counters, temporary indices |
| Shared by multiple nodes in a scene, cleared on scene exit | SCOPE | UI health, scoreboard, scene-local config |
| Cross-scene sharing, needs disk persistence | GLOBAL | Level, gold, level progress, settings |

Plus one reverse rule: **if a piece of data could work under all three scopes, start from the narrowest, LOCAL**. Upgrade to SCOPE when LOCAL isn't enough; touch GLOBAL only when SCOPE isn't enough either. This principle blocks the source of the vast majority of "global variable bloat".

## Three Engineering Disciplines

First is performance. As noted, access speed goes LOCAL > SCOPE > GLOBAL, so don't repeatedly read GLOBAL inside loops. The wrong way: calling `get_variable` to read a config every loop iteration. The right way: read once into LOCAL outside the loop, and use only the LOCAL copy inside. In loops running hundreds or thousands of iterations, this difference shows up directly in frame rate.

Second is default-value fallbacks. `VariableOperations.get_variable` takes a fourth parameter `default_value`, returned instead of erroring when the variable doesn't exist. Build the habit: every read carries a sensible default — `1` when reading player level, `0` when reading score — so even if a variable hasn't been initialized, the logic safely proceeds and one missing value doesn't interrupt the whole instruction sequence. Only when you strictly need to distinguish "variable doesn't exist" from "variable value is null" should you do an existence check with `has_variable` first. This detail matters especially late in a project as data grows — one read without a default can break an entire logic chain in some corner-case scenario, and you might spend half a day unable to find why.

Third is naming. Disciplined naming dramatically lowers debugging costs: LOCAL uses a `temp_` prefix (`temp_distance`, `temp_index`), SCOPE groups by function (`ui_hp`, `enemy_spawn_count`), GLOBAL uses descriptive names (`player_level`, `game_difficulty`). Later, when you use the variable watcher (detailed in the debugging chapter later in the series) to investigate, you can tell at a glance where a value came from and who owns it.

## Wrap-up

The entire essence of the three-layer variable system boils down to one sentence: **prefer LOCAL, use SCOPE when necessary, use GLOBAL sparingly**. Put data in the right residence, and most data-organization problems get solved at the source — instead of cleaning up later when the save file bloats or names collide.

The series has now covered how data is stored, but stored data also needs to be computed. The next chapter, "Damage Formulas Without Writing a Line of Code: Fuse's Expression System in Practice", walks you through using the unified `{local:hp}`, `{scope:name}`, `{global:max}` syntax to compute damage formulas, normalize health, and compose damage floating text in a visual system — three scopes, one syntax, complex computations without writing a single line of code. If this chapter convinced you of the LOCAL/SCOPE/GLOBAL division of labor, the next one shows you how these variables truly come alive.
