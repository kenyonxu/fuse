> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/55-preset-system-guide.md) | English

# Preset System User Guide

The Fuse preset system provides an integrated **workflow reuse + cross-project sharing** solution, covering the complete pipeline from editor export to JSON/`.tres` files and back through import. The system consists of the following components:

| Component | Type | Path | Purpose |
|------|------|------|------|
| FusePreset | Resource | `core/resources/fuse_preset.gd` | Preset data structure, four-level (L1-L4) representation |
| PresetRegistry | Singleton (RefCounted) | `editor/preset_registry.gd` | Scans the `presets/` directory with category caching |
| PresetExportDialog | Dialog | `editor/preset_export_dialog.gd` | Export preset UI (choose level/name/folder) |
| PresetImportDialog | Dialog | `editor/preset_import_dialog.gd` | Import preset UI (node creation + mapping confirmation) |
| FusePresetSerializer | Utility class | `editor/serialization/fuse_preset_serializer.gd` | Node/resource → JSON serialization |
| FusePresetDeserializer | Utility class | `editor/serialization/fuse_preset_deserializer.gd` | JSON → node/resource deserialization |
| NodePathResolver | Utility class | `editor/serialization/nodepath_resolver.gd` | NodePath extraction and auto matching |
| NodePathMappingDialog | Dialog | `editor/serialization/nodepath_mapping_dialog.gd` | Mapping confirmation user interface |

---

## Concept Primer: Preset Resource Structure

`FusePreset` is a `Resource` containing common metadata plus data organized by **level**.

### Common Properties

| Property | Type | Default | Description |
|------|------|--------|------|
| `display_name` | String | `""` | Preset name (shown in the panel) |
| `category` | String | `""` | Category identifier |
| `description` | String | `""` | Description text |
| `icon_name` | String | `""` | Icon (FuseIconManager builtin_icon name, e.g. `Bullet`, `Sprite2D`) |
| `version` | String | `"1.0"` | Version number |
| `level` | String | `"L1"` | Preset level: L1 ∥ L2 ∥ L3 ∥ L4 |
| `variables` | Dictionary | `{}` | Variable declarations (see below) |
| `instructions` | Array[BaseInstruction] | `[]` | Instruction sequence |

### The Four-Level Structure

The preset system defines four levels by the node types present in an **LR-BOM** (Logical Run):

| Level | Node | Contents | Serialized data |
|------|----------|----------|-----------|
| **L1** | ActionRunner | Instruction sequence | `action_runner.instructions` |
| **L2** | Trigger | Event + instructions | `event_json` + `trigger_config` + `action_runner.instructions` |
| **L3** | Runner | Signal binding + instructions | `signal_binding` + `action_runner.instructions` |
| **L4** | MultiEventTrigger | Multiple event bindings | `event_bindings_json` + `trigger_config` |

Each level branches in `to_json()` / `from_json()` on the `level` field when serializing:

```gdscript
match level:
    "L1":
        data["action_runner"] = {"instructions": _serialize_instructions()}
    "L2":
        data["action_runner"] = {"instructions": _serialize_instructions()}
        data["event"] = event_json
        data["trigger_config"] = trigger_config
    "L3":
        data["action_runner"] = {"instructions": _serialize_instructions()}
        data["signal_binding"] = signal_binding
    "L4":
        data["trigger_config"] = trigger_config
        data["event_bindings"] = event_bindings_json
```

### Variable Declaration Format

The `variables` dictionary contains three keys describing the variables referenced by the instruction sequence:

```json
{
    "local": ["n1", "temp_value"],
    "scope": [
        {"name": "hp", "container": "../Player"},
        {"name": "mana", "container": ""}
    ],
    "global": ["level", "score"]
}
```

- **`local`** — list of local variable names
- **`scope`** — list of scope variables, each with a `name` and an optional `container` (NodePath)
- **`global`** — list of global variable names

Extracted automatically from the instruction sequence via the `collect_variables()` method.

---

## Preset Panel Operations

The preset export and import entry points live in the **Inspector panel** and appear automatically when a `Trigger`, `Runner`, or `MultiEventTrigger` node is selected.

### Exporting a Preset (L2 ∥ L3 ∥ L4)

1. Select the node to export in the scene (`Trigger` / `Runner` / `MultiEventTrigger`)
2. A row of action buttons appears at the bottom of the Inspector:
   - **📦 导出 (Trigger/触发器)** — click to open the export dialog
   - **📥 导入预设** — click to open a file picker
3. The export dialog contains the following fields:

| Field | Description |
|------|------|
| Level | Auto-detected (read-only), e.g. `L2 · Trigger（事件 + 指令）` |
| Name | Preset display name; defaults to the node name |
| Target folder | Save path (e.g. `res://addons/fuse/presets/my_category/`) |
| Description | What the preset is for |
| Icon | FuseIconManager builtin icon name (optional) |
| Info | Auto-detected NodePath count and variable count |

4. Clicking **导出** generates two files at once:
   - `{name}.tres` — Godot resource file (can be `load()`-ed directly)
   - `{name}.json` — human-readable JSON format (ideal for cross-project sharing or version control)

5. After export, `PresetRegistry.scan_presets()` is called automatically to refresh the registry.

**Validation rules**: a pre-check runs before export; if it fails, the export button is not shown:

| Level | Check |
|------|----------|
| L2 | `event_definition` is configured |
| L3 | `action_runner` is configured |
| L4 | At least one enabled (`enabled=true`) event binding |

### Importing a Preset

1. Click the **📥 导入预设** button at the bottom of the Inspector
2. The file picker filters `.tres` and `.json` files, defaulting to `res://addons/fuse/presets/`
3. After choosing a file, **PresetImportDialog** is shown:

```
+------------------------------------------+
| Apply Preset: RedPlanetAttack [L2]       |
|                                          |
| L2 · Trigger (will create a Trigger node) |
|                                          |
| gameplay · RedPlanetAttack               |
| Periodically attacks up at the red planet |
|                                          |
| Variable dependencies:                   |
|   [local] cooldown, damage               |
|   [scope] hp — injected at runtime by instructions |
|   [global] score — exists at project level |
|                                          |
|                [Create Node]              |
+------------------------------------------+
```

4. **NodePath mapping**: if the preset contains NodePath references, **NodePathMappingDialog** pops up:

```
+------------------------------------------+
| NodePath Mapping                         |
|                                          |
| The following paths need mapping to nodes in the current scene: |
|                                          |
| ../Player          → [✓ /root/Player ]  v|
| ../EnemySpawner    → [⚠ Select a node...]  v|
|                                          |
|         [Confirm Import]                  |
+------------------------------------------+
```

5. After confirmation, the corresponding nodes are created and attached to the scene tree (under the selected node, or the scene root)

---

## NodePath Mapping Mechanism

When a preset is imported, NodePaths from the original scene are no longer valid in the new scene and must be mapped. `NodePathResolver` implements a three-tier matching strategy:

### Strategy 1: Relative Path Structure Matching

Try resolving the original path from the **target node** (the node selected as parent):

```gdscript
var found = target_node.get_node_or_null(old_np)  # resolve as-is
```

If that fails, try resolving from the **parent node** (the preset may have been created under the Trigger's parent).

### Strategy 2: Global Same-Name Matching

Extract the **last node name segment** of the original path and search the new scene breadth-first for a node with the same name:

- `../Player/HUD` → search for a node named `HUD`
- `../Enemies/Boss` → search for a node named `Boss`

### Strategy 3: Manual Selection

When none of the strategies above match, NodePathMappingDialog lists **all node paths in the scene** for manual selection.

> **Node filtering**: the mapping panel shows only **scene nodes**; editor-internal nodes (such as `@editor` / `@editor_*` temporary nodes) are filtered out to keep the dropdown manageable. If a target node is missing from the list, check whether it is an editor-internal node or not attached to the scene tree.

### Mapping Processing Flow

The full flow (`fuse_inspector_plugin.gd:_apply_preset_to_node`):

```
1. NodePathResolver.extract_nodepaths()   ← extract all NodePaths from the instruction tree
2. if no NodePath → import directly
3. NodePathResolver.resolve_mapping()     ← three-tier matching produces suggestions
4. NodePathMappingDialog                  ← user confirms / fixes manually
5. dialog.get_final_mapping()             ← take the final mapping after confirmation
6. FusePresetDeserializer.deserialize()   ← apply mapping + deserialize
7. Refresh instruction resource_name (display name after NodePath mapping)
```

---

## Bundled Sample Presets

Fuse ships 4 sample presets under `addons/fuse/presets/`:

### gameplay

| Preset | Level | Description |
|------|------|------|
| `red_planet.tres` | L2 | Every 50 seconds moves the node to `(0, 900)`, simulating the periodic sinking of a "red planet" |
| `spawn_enemy.tres` | L2 | Trigger preset for enemy spawning (with instantiate-subscene + position-set instructions) |
| `game_flow.tres` | L2 | Game flow control preset managing level phase transitions |

### ui

| Preset | Level | Description |
|------|------|------|
| `hint_breath.tres` | L2 | UI breathing effect with a 1.3-second period: fade-in (0.5s) → fade-out (0.5s) loop, suited to blinking hint text |

A complete `.tres` structure example of a sample preset (simplified `hint_breath.tres`):

```gdscript
[resource]
display_name = "HintBreath"
category = "ui"
level = "L2"
event_json = {
    "type": &"OnInterval",
    "interval_seconds": 1.3,
    "auto_start": true,
    "trigger_on_start": false
}
trigger_config = {
    "trigger_once": false,
    "cooldown_mode": 0,
    "cooldown_time": 1.0
}
# Instructions: fade in (0.5s) → fade out (0.5s)
instructions =
    [TweenFadeIn: from_alpha=0.0, to_alpha=1.0, duration=0.5, target=..]
    [TweenFadeOut: duration=0.5, target=..]
```

---

## The PresetRegistry

`PresetRegistry` is the central registry for presets, providing categorized queries:

| Method | Returns | Description |
|------|------|------|
| `scan_presets()` | void | Scans `res://addons/fuse/presets/`, recursively loading all `.tres` files |
| `get_all()` | Array[FusePreset] | Get all registered presets |
| `get_by_category(category)` | Array[FusePreset] | Filter by category |
| `get_categories()` | Array[String] | Get all existing category names |
| `clear()` | void | Clear the cache |

**When it is called:**
- Automatically at plugin initialization
- Automatically re-scanned after each preset export
- Call `scan_presets()` manually after adding `.tres` files to `presets/`

---

## Variable Dependency Check

The import dialog shows the variable dependencies referenced by the preset's instruction sequence (the `collect_variables()` result):

```
Variable dependencies:
  [local] cooldown, damage — created automatically at runtime
  [global] score — exists at project level
```

- **local variables**: created automatically at runtime by the ExecutionContext; no manual declaration needed
- **scope variables**: make sure the target node has a ScopeVariableContainer
- **global variables**: must exist in the project (managed via GlobalVariableManager)

---

## Complete Workflow: From Creation to Reuse

```
# Project A: create and export

1. Configure the Trigger node:
   - Set an OnInterval event with a 2-second interval
   - Add a TweenMoveTo instruction with target path ./Player
   - Add a SetVariable instruction setting scope:score

2. Select the Trigger → click 📦 导出 (Trigger) at the bottom of the Inspector
3. Fill in the name "Patrol_Guard" and description "巡逻守卫行为"
4. Target folder: res://addons/fuse/presets/gameplay/
5. Export → generates Patrol_Guard.tres + Patrol_Guard.json
```

```
# Project B: import and adapt

1. Select an empty node as the attachment point
2. Click 📥 导入预设 at the bottom of the Inspector
3. Choose Patrol_Guard.tres
4. Review the info: L2 Trigger, contains 1 NodePath (./Player)
5. NodePathMappingDialog:
   - ./Player → ✓ /root/Player (auto-matched)
   - Confirm import
6. The Trigger node is created; attach your own Player and it runs
```

---

## File Formats

### .tres Format

Godot's native resource format; `load()` it directly to get a `FusePreset` instance. Contains full type information and sub-resource references.

### .json Format

Cross-platform readable format, suited to hand editing, version diffs, or generation from external tools:

```json
{
    "format_version": "1.0",
    "level": "L2",
    "display_name": "Patrol_Guard",
    "category": "gameplay",
    "description": "巡逻守卫行为",
    "icon_name": "Bullet",
    "variables": {
        "local": ["patrol_index"],
        "scope": [{"name": "alert_level", "container": ""}],
        "global": []
    },
    "event": {
        "type": "OnInterval",
        "interval_seconds": 2.0,
        "auto_start": true
    },
    "trigger_config": {
        "trigger_once": false,
        "cooldown_mode": 0,
        "cooldown_time": 1.0
    },
    "action_runner": {
        "instructions": [
            {"type": "TweenMoveTo", "target_node": "./Player", "duration": 3.0},
            {"type": "SetVariable", "variable_name": "alert_level", "variable_scope": 1, "value": 50}
        ]
    }
}
```

---

## Best Practices

### Naming and Categories
- Use `snake_case` for file names: `patrol_guard.tres`
- Organize directories by game system: `presets/gameplay/`, `presets/ui/`, `presets/audio/`
- `category` is extracted from the folder name automatically

### Export Strategy
- **Export feature snippets as L1**: pure instruction combinations, droppable into any ActionRunner
- **Export complete triggers as L2**: includes event configuration, ready to use on import
- **Export signal adapters as L3**: for bridging custom signals to instructions
- **Export composite triggers as L4**: multiple event bindings + condition combinations

### NodePath Conventions
- Use relative paths (`../Player`, `./HUD/ScoreLabel`)
- Avoid hardcoding absolute paths (`/root/Game/Player`)
- Keep target node names stable in the scene tree

### Version Management
- Put `.json` files under version control (easy to diff)
- `.tres` files can be committed but are hard to diff
- The `version` field is used for forward-compatibility checks

---

## Troubleshooting

| Problem | Cause | Solution |
|------|------|----------|
| Export button not shown | Pre-validation failed | Check the event_definition / action_runner configuration |
| NodePaths lost after import | Mapping not configured correctly | Check every mapping entry in NodePathMappingDialog |
| Instruction type not found | `FusePreset` depends on `InstructionRegistry` | Make sure the Fuse plugin is fully loaded |
| JSON parsing failed | Malformed format or incompatible version | Import via the `.tres` format or fix the JSON by hand |

---

## The Graduation Exit for Presets

Presets now have both an outbound and a return journey: the **outbound** trip is AI generation / manual export → offline validation → import and reuse (the topic of this document); the **return** trip is the AI handoff artifact — Trigger logic stabilized in the scene is derived via topology into System artifacts (system decomposition), which together with presets (behavior specs) are handed to **your own AI agent** to write engineering code free of Fuse, while the source Trigger stays untouched and can be rolled back at any time (see [README](../../../../../../README.md), "从原型到工程代码"). There is also an **experimental** graduation exporter that directly generates GDScript coexisting with the Fuse runtime: [Graduation Exporter User Guide](57-graduation-exporter-guide.md).

---

**Related docs:**
- [Graduation Exporter User Guide (experimental GDScript export)](57-graduation-exporter-guide.md)
- [Variable System Guide](01-variable-system-guide.md)
- [Editor Panels Overview](00-editor-panels-overview.md)
- [Trigger Selection Guide](02-trigger-selection-guide.md)
- [Runner Guide](03-runner-guide.md)
- [Multi-Event Trigger Guide](04-multi-event-trigger-guide.md)
