> 🌐 [**中文版**](../../../zh_CN/dev_docs/guides/57-preset-system-dev-guide.md) | English

# Preset System Developer Guide

> **Goal**: Provide developers with a complete architecture description and extension guide for the Fuse preset system, covering the `FusePreset` resource definition, the serialization/deserialization pipeline, the `PresetRegistry`, NodePath mapping, and the interaction with the global variable system.

**Audience**: Fuse system developers, contributors

**Last updated**: 2026-07-19

**Companion user doc**: [55-preset-system-guide.md](../../user_docs/guides/55-preset-system-guide.md)

---

## 📋 Table of Contents

1. [System Architecture Overview](#system-architecture-overview)
2. [FusePreset Resource Definition](#fusepreset-resource-definition)
3. [Serialization Pipeline (FusePresetSerializer)](#serialization-pipeline-fusepresetserializer)
4. [Deserialization Pipeline (FusePresetDeserializer)](#deserialization-pipeline-fusepresetdeserializer)
5. [PresetRegistry](#presetregistry)
6. [NodePath Resolution (NodePathResolver)](#nodepath-resolution-nodepathresolver)
7. [Preset Creation Workflow](#preset-creation-workflow)
8. [Interaction with the Global Variable System](#interaction-with-the-global-variable-system)
9. [Loading and Saving](#loading-and-saving)
10. [Best Practices](#best-practices)
11. [Common Pitfalls](#common-pitfalls)

---

## System Architecture Overview

The preset system consists of four layers: **data layer (Resource) → serialization layer (Serializer/Deserializer) → registry layer (Registry) → UI layer (Dialog)**:

| Component | Type | Path | Responsibilities |
|------|------|------|------|
| FusePreset | Resource | `core/resources/fuse_preset.gd` | Preset data structure, L1-L4 four-level expression, `to_json()` / `from_json()` |
| FusePresetSerializer | RefCounted utility class | `editor/serialization/fuse_preset_serializer.gd` | Nodes/resources → JSON (all static methods) |
| FusePresetDeserializer | RefCounted utility class | `editor/serialization/fuse_preset_deserializer.gd` | JSON → nodes/resources (all static methods) |
| NodePathResolver | RefCounted utility class | `editor/serialization/nodepath_resolver.gd` | NodePath extraction and three-tier matching |
| PresetRegistry | RefCounted singleton | `editor/preset_registry.gd` | Scans the `presets/` directory, category cache (all static methods) |
| PresetExportDialog | AcceptDialog | `editor/preset_export_dialog.gd` | Export UI, `get_preset()` produces a FusePreset |
| PresetImportDialog | AcceptDialog | `editor/preset_import_dialog.gd` | Import UI, variable dependency display |
| NodePathMappingDialog | AcceptDialog | `editor/serialization/nodepath_mapping_dialog.gd` | Mapping confirmation UI |

**Data flow**:

```
Export: scene nodes → Serializer.serialize() → Dictionary
                                    ↓
                    PresetExportDialog.get_preset() → FusePreset
                                    ↓
              ┌─ ResourceSaver → {name}.tres (Godot resource)
              └─ JSON.stringify → {name}.json (human-readable / version control)
                                    ↓
                    PresetRegistry.scan_presets() (refresh cache)

Import: .tres/.json → FusePreset
                    ↓
      NodePathResolver.extract_nodepaths() → resolve_mapping()
                    ↓
      NodePathMappingDialog (user confirms mapping)
                    ↓
      Deserializer.deserialize(preset, mapping) → scene nodes
```

---

## FusePreset Resource Definition

`FusePreset` is the core data carrier of a preset (`core/resources/fuse_preset.gd`), extending `Resource`.

### Exported Properties

| Property | Type | Default | Description |
|------|------|--------|------|
| `display_name` | String | `""` | Preset display name |
| `category` | String | `""` | Category identifier (usually the folder name) |
| `description` | String | `""` | Description text |
| `icon_name` | String | `""` | FuseIconManager built-in icon name |
| `version` | String | `"1.0"` | Version string |
| `variables` | Dictionary | `{}` | Variable declarations (`local`/`scope`/`global` keys) |
| `level` | String | `"L1"` | Level: L1 ∥ L2 ∥ L3 ∥ L4 |
| `event_json` | Dictionary | `{}` | L2 event serialization data |
| `trigger_config` | Dictionary | `{}` | L2/L4 trigger configuration |
| `signal_binding` | Dictionary | `{}` | L3 signal binding |
| `event_bindings_json` | Array | `[]` | L4 multi-event bindings |
| `instructions` | Array[BaseInstruction] | `[]` | Instruction sequence |

### Levels and Their Serialization Fields

| Level | Corresponding node | Key fields emitted by `to_json()` |
|------|----------|---------------------------|
| **L1** | ActionRunner | `action_runner.instructions` |
| **L2** | Trigger | `action_runner.instructions` + `event` + `trigger_config` |
| **L3** | Runner | `action_runner.instructions` + `signal_binding` |
| **L4** | MultiEventTrigger | `trigger_config` + `event_bindings` |

### Key Methods

```gdscript
## Serialize into a JSON dictionary (branching on level)
func to_json() -> Dictionary

## Build a preset from a JSON dictionary (static factory)
static func from_json(data: Dictionary) -> FusePreset

## Extract all deduplicated NodePaths from the instruction tree
func collect_unique_nodepaths() -> Array[NodePath]

## Apply a NodePath mapping (rewrites paths inside instructions at import time)
func apply_nodepath_mapping(mapping: Dictionary) -> void

## Collect variable declarations → {"local": [...], "scope": [...], "global": [...]}
func collect_variables() -> Dictionary
```

### Property Filtering During Instruction Serialization

When serializing instructions, common base-class properties are skipped to avoid redundancy:

```gdscript
const _BASE_PROPERTIES := ["log_level", "completion_timing", "execution_mode",
    "script", "resource_local_to_scene", "resource_name", "metadata"]
```

> **Note**: Custom properties of new instructions are **automatically** serialized (by reflecting over the property list); no registration in the preset system is required. However, the property must be of a Godot-serializable Variant type.

---

## Serialization Pipeline (FusePresetSerializer)

`FusePresetSerializer` (`editor/serialization/fuse_preset_serializer.gd`) is a purely static utility class responsible for the **node → JSON** direction.

### Core API

| Method | Returns | Description |
|------|------|------|
| `detect_level(node)` | String | Automatically detects the level from the node type (`"L1"`-`"L4"`) |
| `serialize(node)` | Dictionary | Generic entry point; dispatches internally on `detect_level` |
| `serialize_l1(runner)` | Dictionary | Serializes an ActionRunner |
| `serialize_l2(trigger)` | Dictionary | Serializes a Trigger (event + config + instructions) |
| `serialize_l3(runner)` | Dictionary | Serializes a Runner (signal bindings + instructions) |
| `serialize_l4(multi)` | Dictionary | Serializes a MultiEventTrigger (multi-event bindings) |
| `serialize_action_runner(runner)` | Dictionary | Instruction sequence only |
| `serialize_event(event)` | Dictionary | A single event resource → JSON |
| `serialize_condition(cond)` | Dictionary | A single condition resource → JSON |
| `serialize_trigger_config(node)` | Dictionary | Common trigger configuration (trigger_once/cooldown etc.) |
| `serialize_signal_binding(node)` | Dictionary | L3 signal binding configuration |
| `serialize_binding(binding)` | Dictionary | A single EventBinding → JSON |

### Instruction Serialization Details

```gdscript
static func _serialize_instructions(instructions: Array[BaseInstruction]) -> Array:
	# Each instruction is emitted as {"type": <class name>, ...property key-value pairs}
	# Nested instructions (the sub-instruction arrays of if/else/loop) are serialized recursively
```

- Instruction types are recorded in the **`type` field (class name string)**; deserialization reloads the script by class name
- `_serialize_resource_properties(res)` exports Resource properties via reflection, skipping `_BASE_PROPERTIES`

### Variable Collection

`_collect_all_variables(instructions)` scans the instruction sequence and buckets variables by the `variable_scope` integer:

```gdscript
match scope:
	0:  # LOCAL  → result["local"].append(name)
	1:  # SCOPE  → result["scope"].append({"name": name, "container": target_node})
	2:  # GLOBAL → result["global"].append(name)
```

> **Key point**: This scan only recognizes instructions that implement the `variable_name` + `variable_scope` properties. Custom instructions referencing variables should follow the same property naming convention, otherwise the preset's variable dependency declaration will be incomplete.

---

## Deserialization Pipeline (FusePresetDeserializer)

`FusePresetDeserializer` (`editor/serialization/fuse_preset_deserializer.gd`) handles the **JSON → node** direction.

### Core API

| Method | Returns | Description |
|------|------|------|
| `deserialize(preset, mapping)` | Object | Generic entry point; dispatches on `preset.level` and applies the NodePath mapping |
| `validate_imported_node(node, level)` | Array[String] | Post-import validation; returns a list of errors |

Internal dispatch (private static methods):

| Method | Return type | Description |
|------|----------|------|
| `_import_l1(preset, _mapping)` | ActionRunner | Creates ActionRunner + instructions |
| `_import_l2(preset, mapping)` | Trigger | Creates Trigger + event + instructions |
| `_import_l3(preset, mapping)` | Runner | Creates Runner + signal bindings + instructions |
| `_import_l4(preset, mapping)` | MultiEventTrigger | Creates MultiEventTrigger + event bindings |

### Script Caching Mechanism

Deserialization loads the class script matching the `type` field and caches it to avoid repeated IO:

```gdscript
static func _cache_instruction_script(type_name: String) -> GDScript
static func _cache_event_script(type_name: String) -> GDScript
static func _cache_condition_script(type_name: String) -> GDScript
```

### Property Write-Back and Mapping

```gdscript
## Set a property value (handles type conversion)
static func _set_property_value(obj: Object, key: String, val) -> void

## Recursively apply the NodePath mapping to the node and its instructions
static func _apply_nodepath_mapping_node(node: Node, mapping: Dictionary) -> void
static func _apply_mapping_recursive(obj: Object, mapping: Dictionary) -> void
```

**You must call** `validate_imported_node()` after import for integrity checks (e.g. whether L2 has an event, whether L4 has an enabled binding).

---

## PresetRegistry

`PresetRegistry` (`editor/preset_registry.gd`) is the central cache for presets, **entirely static methods**, no instantiation needed.

### API

| Method | Returns | Description |
|------|------|------|
| `scan_presets()` | void | Recursively scans `res://addons/fuse/presets/`, loading all `.tres` files |
| `get_all()` | Array[FusePreset] | All registered presets |
| `get_by_category(category)` | Array[FusePreset] | Filter by category |
| `get_categories()` | Array[String] | All category names |
| `clear()` | void | Clear the cache |

### When to Call

```gdscript
# 1. Scanned automatically at plugin initialization
# 2. Automatically rescanned after each preset export
# 3. After manually adding .tres files you must refresh manually:
PresetRegistry.scan_presets()
```

> **Note**: The registry only scans `.tres` files. `.json` files are for cross-project sharing / version diffing only and do not participate in the registry.

---

## NodePath Resolution (NodePathResolver)

`NodePathResolver` (`editor/serialization/nodepath_resolver.gd`) addresses the central pain point of reusing presets across scenes: **NodePaths from the original scene break in the new scene**.

### Extraction

```gdscript
## Extract all NodePaths from an instruction sequence (deduplicated, recursing into nested instructions and conditions)
static func extract_nodepaths(instructions: Array) -> Array[String]
```

Nested instructions declare their sub-instruction property names via the `_SUB_INSTRUCTIONS` constant:

```gdscript
const _SUB_INSTRUCTIONS := ["instructions", "else_instructions", "loop_instructions"]
```

> **Extension point**: If a new instruction contains a sub-instruction array whose property name is not in the list above, add it to `_SUB_INSTRUCTIONS`; otherwise the NodePaths inside nested instructions will not be extracted or mapped.

### Three-Tier Matching Strategy

```gdscript
## Generate mapping suggestions
## Returns {old_np: {"new": NodePath, "matched": bool, "suggestions": Array[String]}}
static func resolve_mapping(...) -> Dictionary
```

| Priority | Strategy | Implementation |
|--------|------|------|
| 1 | Relative path structure matching | `_match_relative()` — resolves the original path starting from the target node (and its parents) |
| 2 | Global same-name matching | `_find_node_by_name()` — extracts the trailing node name from the path, breadth-first search |
| 3 | Manual selection | `_collect_node_suggestions()` — collects all node paths in the scene for the user to pick from |

An independent resolution entry point is also provided:

```gdscript
## Tries all strategies to resolve a NodePath string; returns null on failure
static func resolve_or_null(np_str: String, scene_root: Node) -> Node
```

---

## Preset Creation Workflow

### Option 1: Creating via Code (Recommended for Tests/Toolchains)

```gdscript
# 1. Build the preset resource
var preset := FusePreset.new()
preset.display_name = "Patrol_Guard"
preset.category = "gameplay"
preset.description = "巡逻守卫行为"
preset.level = "L2"
preset.icon_name = "Bullet"

# 2. Fill in the instructions
var move := TweenMoveTo.new()
move.target_node = NodePath("./Player")
move.duration = 3.0
preset.instructions = [move]

# 3. Fill in the L2 event data (can be produced by FusePresetSerializer.serialize_event)
preset.event_json = {"type": &"OnInterval", "interval_seconds": 2.0, "auto_start": true}
preset.trigger_config = {"trigger_once": false, "cooldown_mode": 0, "cooldown_time": 1.0}

# 4. Collect the variable declarations
preset.variables = preset.collect_variables()

# 5. Save (both formats)
ResourceSaver.save(preset, "res://addons/fuse/presets/gameplay/patrol_guard.tres")
var json_text := JSON.stringify(preset.to_json(), "\t")
var file := FileAccess.open("res://addons/fuse/presets/gameplay/patrol_guard.json", FileAccess.WRITE)
file.store_string(json_text)
file.close()

# 6. Refresh the registry
PresetRegistry.scan_presets()
```

### Option 2: Creating from Scene Nodes (Export Dialog Path)

```
1. Select a Trigger/Runner/MultiEventTrigger in the scene
2. FusePresetSerializer.detect_level(node)   → auto-detect the level
3. FusePresetSerializer.serialize(node)      → Dictionary
4. PresetExportDialog._init(source)          → fill in the UI fields
5. The user confirms name/description/icon/target folder
6. PresetExportDialog.get_preset()           → FusePreset
7. The Inspector plugin saves .tres + .json → PresetRegistry.scan_presets()
```

`get_preset()` is the dialog's outward-facing output API — **the dialog itself never writes to disk**; persistence is done by the caller (`fuse_inspector_plugin.gd`), which keeps it unit-testable.

### Pre-Export Validation

Level checks performed before the export button is shown (the button stays hidden until they pass):

| Level | Check condition |
|------|----------|
| L2 | `event_definition` is configured |
| L3 | `action_runner` is configured |
| L4 | At least one event binding with `enabled = true` |

---

## Interaction with the Global Variable System

The preset system and the global variable system have a **declaration-dependency** relationship, not a storage relationship.

### How Variable Declarations Are Generated

At export time `collect_variables()` scans the instruction sequence and writes the names of variables with `variable_scope == 2` (GLOBAL) into `variables["global"]`:

```json
"variables": {
    "local": ["cooldown", "damage"],
    "scope": [{"name": "hp", "container": "../Player"}],
    "global": ["score", "level"]
}
```

### Handling Rules at Import Time

| Scope | Behavior at import |
|--------|-----------|
| `local` | Nothing to do — created automatically by ExecutionContext at runtime |
| `scope` | Dependency display — the target node needs a ScopeVariableContainer, injected at runtime |
| `global` | Dependency display — **never auto-created**; the project must have registered them through GlobalVariableManager |

**Key design decision**: preset import **does not call** `GlobalVariableManager.add_variable()`. Reasons:

1. Global variables are **project-level state**; a preset only declares "I need these variables to exist"
2. Auto-creation would overwrite the project's existing values of same-named variables
3. The variable's initial value, type, and `persistent` flag should be decided by the project side (usually established with SetVariable in a game-initialization Trigger)

### Integration Advice for Developers

If you need to complete missing global variables for a preset after import, the recommended pattern:

```gdscript
# After the import completes, check for missing global variables and warn/initialize
var gvm := GlobalVariableManager.get_instance()
var deps: Dictionary = preset.collect_variables()
for var_name in deps.get("global", []):
	if not gvm.has_variable(var_name):
		var v := BaseVariable.new()
		v.variable_name = var_name
		v.value = 0           # Project-decided default value
		v.persistent = true
		gvm.add_variable(var_name, v)
		push_warning("预设依赖的全局变量已自动初始化: %s" % var_name)
```

See [59-global-variables-dev-guide.md](59-global-variables-dev-guide.md) for the details of the global variable mechanism.

---

## Loading and Saving

### The .tres Format (Runtime/Editor Loading)

```gdscript
# Load
var preset := load("res://addons/fuse/presets/gameplay/patrol_guard.tres") as FusePreset

# Save
ResourceSaver.save(preset, path)
```

### The .json Format (Cross-Project/Version Control)

```gdscript
# Export JSON
var data: Dictionary = preset.to_json()
var text := JSON.stringify(data, "\t")

# Import JSON
var parsed: Variant = JSON.parse_string(file.get_as_text())
var preset := FusePreset.from_json(parsed)
```

### Deserializing into Scene Nodes

```gdscript
# Full import pipeline
var nodepaths := NodePathResolver.extract_nodepaths(preset.instructions)
var mapping := {}
if not nodepaths.is_empty():
	mapping = NodePathResolver.resolve_mapping(...)   # Three-tier matching
	# → NodePathMappingDialog user confirmation → dialog.get_final_mapping()

var node: Object = FusePresetDeserializer.deserialize(preset, mapping)
var errors := FusePresetDeserializer.validate_imported_node(node, preset.level)
if errors.is_empty():
	target_node.add_child(node)
	node.owner = get_tree().edited_scene_root   # owner must be set in the editor or the node will not be saved
```

> **Editor key point**: nodes created by import must have `owner` set to the scene root, otherwise they will not be saved with the scene.

---

## Best Practices

### 1. Always Generate Both Formats

- `.tres` — for `load()` and PresetRegistry
- `.json` — for version control diffs and cross-project sharing
- Both must have identical content (produced from the same `FusePreset` instance)

### 2. Keep Variable Declarations Up to Date

After modifying `instructions`, call `collect_variables()` again:

```gdscript
preset.instructions = new_instructions
preset.variables = preset.collect_variables()  # Must refresh
```

### 3. Use Relative NodePaths

- ✅ `../Player`, `./HUD/ScoreLabel`
- ❌ `/root/Game/Player` (always breaks across scenes; even three-tier matching cannot recover)

### 4. New Instructions Follow the Variable Property Naming Convention

Custom instructions referencing variables should use the `variable_name` + `variable_scope` property names so the preset system can collect dependencies automatically.

### 5. Semantic Version Field

Increment `version` whenever the preset structure changes (fields added or removed); `from_json()` can branch on the version for compatibility.

---

## Common Pitfalls

### Pitfall 1: Forgetting to Refresh PresetRegistry

**Problem**: the panel does not show a `.tres` file copied manually into `presets/`.

**Solution**: call `PresetRegistry.scan_presets()`.

### Pitfall 2: NodePaths in Nested Instructions Not Mapped

**Problem**: the sub-instruction array property name of a custom instruction is not in `_SUB_INSTRUCTIONS`.

**Solution**: add the property name to the `NodePathResolver._SUB_INSTRUCTIONS` constant.

### Pitfall 3: Imported Node Missing owner

**Problem**: the imported Trigger is visible in the editor but disappears after the scene is saved.

**Solution**: `node.owner = get_tree().edited_scene_root`.

### Pitfall 4: Instruction Properties Using Non-Serializable Types

**Problem**: an instruction property holds a node/object reference; it is lost or errors out after serialization.

**Solution**: store only NodePath/string paths in resources and resolve them at runtime with `context.get_node()` (consistent with the instruction development guidelines).

### Pitfall 5: Expecting Import to Auto-Create Global Variables

**Problem**: after importing a preset, `GetVariable [GLOBAL]` reports that the variable was not found.

**Solution**: global variables are a project-level dependency and must be registered during game initialization; see [Interaction with the Global Variable System](#interaction-with-the-global-variable-system).

### Pitfall 6: Enums Stored as Integers in JSON

**Problem**: when hand-editing the JSON, the enum is written as a string (e.g. `"variable_scope": "GLOBAL"`), causing a type mismatch at deserialization.

**Solution**: enums in JSON are always integers (LOCAL=0, SCOPE=1, GLOBAL=2), matching the match branches of `collect_variables()`.

---

## Summary

Core takeaways for preset system development:

1. ✅ **Four-layer architecture with a clear division of labor** — FusePreset (data) → Serializer/Deserializer (pipeline) → PresetRegistry (cache) → Dialog (UI)
2. ✅ **Fully static serialization** — `FusePresetSerializer` / `FusePresetDeserializer` need no instantiation
3. ✅ **Instruction type is the class name** — the `type` field drives cached script loading; new instructions are supported automatically
4. ✅ **Variables are dependency declarations** — `collect_variables()` produces the local/scope/global three-key declaration; import never auto-creates global variables
5. ✅ **NodePath three-tier matching** — relative structure → same-name search → manual selection; the extension point is `_SUB_INSTRUCTIONS`
6. ✅ **Dual-format persistence** — `.tres` for loading, `.json` for version control

**Reference documents**:
- [Preset System User Guide](../../user_docs/guides/55-preset-system-guide.md)
- [Global Variables Development Guide](59-global-variables-dev-guide.md)
- [Variable Watcher Development Guide](58-variable-watcher-dev-guide.md)
- [Instruction Creation Guide](instruction-creation-guide.md)

---

**Document maintainer**: Fuse development team
**Last updated**: 2026-07-19
