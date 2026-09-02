> 🌐 [**中文版**](../../../zh_CN/user_docs/best_practices/preset_reuse.md) | English

# Preset Reuse and AI Collaboration Practices

## Overview

Presets are the "building-block" form of Fuse logic: a tuned piece of Trigger logic is exported as JSON and imported into any project for reuse, and AI can generate it directly from the schema. This practices guide answers two questions — **how to write presets that AI generates well and that humans migrate smoothly**, and **how to fit AI into a generate-validate-tune loop**.

For the operational side (which panels to click, the export/import flow), see the [Preset System Guide (Chinese)](../../../zh_CN/user_docs/guides/55-preset-system-guide.md); this article only covers "how to do it well".

## 1. Granularity: One Interaction Unit per Preset

Granularity is the first deciding factor in preset practice, and both extremes carry costs:

- **Too fine** (a single instruction, a single signal binding): reuse value approaches zero; building it directly is easier
- **Too coarse** (a whole level, a whole UI screen): NodePath and variable mapping after import is heavy, and one mismatched part can scrap the entire package

**The recommended granularity is "one independently describable interaction unit"** — a whole piece of logic you can describe in one sentence:

> "hit invincibility frames", "wave spawner", "boss three-phase loop", "pickup floating text"

The deep-test corpus (`demos/fuse/deep_tests/presets/`, 28 domain presets) sits exactly at this granularity: `deep_tween` (a Tween collection), `deep_audio` (audio control), `deep_camera` (camera cinematography) — each is an independently describable, individually importable capability unit.

The corpus also provides a reference for **complexity grading** (L1-L4):

| Level | Shape | Example |
|------|------|------|
| L1 | Single event + simple instruction chain | Print on key press |
| L2 | Timer/interval driven | Breathing light, periodic patrol |
| L3 | Runner unit (code-invoked) | On-hit handler |
| L4 | Multi-event composite (MultiEventTrigger) | Combined attack/defense logic on one object |

L2-L4 is the band with the highest reuse value; L1 is usually faster to build on the spot.

## 2. Metadata: The "Resume" Before Import

The metadata fields at the head of the preset JSON determine its discoverability in the registry and in team collaboration. Before exporting, check that these four items are complete:

```json
{
  "format_version": "...",
  "level": "L4",
  "display_name": "Boss 三阶段循环",
  "category": "boss",
  "description": "血量阈值驱动三阶段行为切换，含受击无敌帧与死亡结算",
  "variables": [ ... ],
  "trigger_config": { ... }
}
```

- **Use a Chinese phrase for `display_name`**, never "logic 1"; in the importer's preset browser list it is the only identifier
- **Name `category` by interaction domain** (combat / ui / camera / boss…), not by project name — cross-project category consistency matters more than the source project
- **State inputs and outputs clearly in `description`**: which variables the preset expects to already exist (what it reads) and what it produces (what it writes) — this is the information importers need most
- **Declare the `variables` array honestly**: the variable dependency check uses it to scan for missing entries; under-reporting means importers only discover problems at runtime

## 3. Minimize Dependencies: Migration Cost = Dependency Count

All friction in cross-project preset migration comes from two kinds of dependencies; prioritize accordingly:

1. **Variable dependencies** (most controllable): use LOCAL variables for intermediate values that only flow inside the preset, so the dependency list shrinks to the real inputs and outputs. A preset with ten GLOBAL dependencies is nearly unreusable; change it to "read 2 globals, write 1 global, everything else LOCAL", and migration becomes a matter of filling in three variable names
2. **NodePath dependencies** (mappable): it does not matter if target nodes live at different paths in the new scene — the [three-level mapping (Chinese)](../../../zh_CN/user_docs/guides/55-preset-system-guide.md) at import time (node name → type → hierarchy approximation) generates suggestions, but **node naming itself must be readable**: `Hurtbox` maps far more reliably than `Area2D7`

Anti-pattern checklist:

- using GLOBAL variables inside a preset to pass intermediate values (switch to LOCAL)
- hard-coding node paths in instruction parameters instead of variable binding (switch to the [variable binding](../guides/07-variable-binding-guide.md) dual track, so migration only changes the variable source)
- one preset depending on another preset's side effects (decouple the coupling and declare variable interfaces separately)

## 4. AI Collaboration: The Generate-Validate-Tune Loop

AI preset generation is not "let the AI write it and use it directly", but a three-step loop:

### Step 1: Feed the Inventory, State the Requirement

Give the AI the three JSON files under `addons/fuse/preset_ai_context/` (components / schemas / enums) — the machine-readable inventory of all components, including the gating relations of condition parameters. State the requirement in the four elements "event → conditions → action sequence → variable interface":

> "Generate a hit-invulnerability preset: event OnDamaged, set invincible to true, then Wait 1.2 seconds and set it back to false; expected input variable invincible (GLOBAL), plus a blinking Tween."

The more complete the four elements, the higher the first-shot hit rate; when component names are uncertain, have the AI search components.json first before writing.

### Step 2: Gate with Offline Validation

```bash
Godot --headless --path . res://addons/fuse/editor/preset_ai/validate_preset.tscn -- <preset.json>
# exit code 0 = no errors; non-zero = go through the findings and fix one by one
```

The validator checks four layers: structure, component references, parameter types, and semantic constraints. **Do not import a preset with errors** — paste the validation findings back to the AI and let it fix itself; usually one round is enough.

### Step 3: Manual Tuning After Import

Validation guarantees "legal", not "fun". Game-feel parameters (durations, easing, strengths) are tuned by dragging sliders in the Inspector — this is exactly why presets are JSON rather than compiled artifacts: **AI provides the structure, humans provide the feel**, each doing what it is best at.

### Iteration Boundaries

- Parameter-level changes: adjust directly in the Inspector after import; do not go back to the AI for regeneration
- Structure-level changes (adding instructions, changing events): revise the requirement description and regenerate; do not hand-edit the instruction tree in the JSON — hand edits easily break schema details (condition gating, variable mode declarations), and the validator will tell you where it broke

## 5. Versioning and Team Collaboration

- preset JSON is plain text, **diffable and reviewable in git** — structural changes (adding/removing instructions) and parameter changes (tuning durations) are obvious in the diff, which the ".tres embedded in scenes" form cannot offer
- The natural team split: designers tune in the Inspector, engineers review JSON diffs, and AI drafts from requirements — all three operate on different layers of the same JSON
- When a preset evolves to v2, **copy to a new file instead of overwriting** (`boss_loop_v2.json`); old scenes referencing the old version are unaffected

## FAQ

### The variable dependency check reports missing variables after import, but the variables exist?

Check the scope: the preset declared GLOBAL, but your project created SCOPE. A scope mismatch is the same as the variable not existing.

### The AI-generated preset passes validation but behaves incorrectly at runtime?

Validation checks legality, not semantics. First open the [variable watcher (Chinese)](../../../zh_CN/user_docs/guides/56-variable-watcher-guide.md) and watch the variable flow; most problems are a wrong variable scope or a misreading of when the event fires — describe the watcher's observations back to the AI and let it locate the issue.

### A preset exported from another project fails all NodePath mappings?

Most likely the original scene's node names are unreadable (`Area2D3` and the like). Rename the target nodes in the new scene to match the preset's semantics and re-import; the mapping suggestions will refresh.

---

**Related docs:**

- [Preset System Guide (Chinese)](../../../zh_CN/user_docs/guides/55-preset-system-guide.md) — the operational side of export/import/mapping
- [Variable Binding Guide](../guides/07-variable-binding-guide.md) — the parameter dual track, the way to reduce path dependencies
- [AI Collaboration and Graduation Handoff (Chinese)](../../../zh_CN/user_docs/Introductions/16-AI协作与毕业交接.md) — where presets sit in the "bridge" big picture
- [Trigger Organization and Race-Condition Avoidance](trigger_organization.md) — organization practices once presets land back in a scene
