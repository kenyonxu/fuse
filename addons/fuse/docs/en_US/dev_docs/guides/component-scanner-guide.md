> 🌐 [**中文版**](../../../zh_CN/dev_docs/guides/component-scanner-guide.md) | English

# FuseComponentScanner Component Scanner Development Guide

> **Goal**: Provide developers with a complete development guide to the FuseComponentScanner component scan-and-register mechanism, covering scanning, registration, metadata validation, and unregistration.

**Audience**: Fuse system developers, contributors

**Last updated**: 2026-07-07

---

## 📋 Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Design](#architecture-design)
3. [FuseComponentScanner API](#fusecomponentscanner-api)
4. [ComponentRegistry API](#componentregistry-api)
5. [Dedicated Registry APIs](#dedicated-registry-apis)
6. [Registration Flow in Detail](#registration-flow-in-detail)
7. [Usage Guide](#usage-guide)
8. [Best Practices](#best-practices)
9. [Common Pitfalls](#common-pitfalls)

---

## System Overview

`FuseComponentScanner` is Fuse's **component scan-and-register engine**. It scans the GDScript files under the `instructions/`, `events/`, and `conditions/` directories, validates their metadata, and completes registration through `ComponentRegistry` and its three dedicated registries.

### Core Files

| File | Class | Purpose |
|------|------|------|
| `editor/bootstrap/fuse_component_scanner.gd` | `FuseComponentScanner` | Scan engine (RefCounted) |
| `editor/component_registry.gd` | `ComponentRegistry` | Generic registrar |
| `editor/instruction_selector/instruction_registry.gd` | `InstructionRegistry` | Instruction registrar |
| `editor/event_registry.gd` | `EventRegistry` | Event registrar |
| `editor/condition_registry.gd` | `ConditionRegistry` | Condition registrar |
| `editor/preset_registry.gd` | `PresetRegistry` | Preset registrar |

### Design Goals

- **Automated registration**: directories are scanned automatically at startup, no manual registration per component
- **Generic scanning**: the same scanning logic serves instructions, events, and conditions
- **Metadata validation**: each component is checked at scan time for the required metadata methods
- **Duplicate detection**: duplicate identifiers are detected automatically and updated in place
- **Reversible**: `teardown()` clears all registries when the plugin is deactivated

---

## Architecture Design

```
FuseComponentScanner._init(plugin: EditorPlugin)
        │
        │ setup()
        ▼
├── _register_all_instructions()
│       └── _register_components_from_folders(
│               folders, "_get_instruction_metadata",
│               "InstructionRegistry", ...)
│
├── _register_events()
│       └── _register_components_from_folders(
│               folders, "_get_event_metadata",
│               "EventRegistry", ...)
│
├── _register_conditions()
│       └── _register_components_from_folders(
│               folders, "_get_condition_metadata",
│               "ConditionRegistry", ...)
│
└── PresetRegistry.scan_presets()

        │ Scan results
        ▼
┌──────────────────────────────────────────────────┐
│               ComponentRegistry                   │
│                                                   │
│  _instructions: Array[Dictionary]                 │
│  _instruction_map: Dictionary (name → info)       │
│  _events: Array[Dictionary]                       │
│  _event_map: Dictionary                           │
│  _conditions: Array[Dictionary]                   │
│  _condition_map: Dictionary                       │
│                                                   │
│  _duplicate_counts: Dictionary                    │
│  (ComponentType → int, for scan observability)    │
└──────────────────────────────────────────────────┘
        ↕                      ↕                    ↕
InstructionRegistry      EventRegistry       ConditionRegistry
(dedicated registrar)    (dedicated registrar)  (dedicated registrar)
```

---

## FuseComponentScanner API

**File location**: `addons/fuse/editor/bootstrap/fuse_component_scanner.gd`

**Class definition**:
```gdscript
class_name FuseComponentScanner extends RefCounted
```

### Constructor

```gdscript
func _init(plugin: EditorPlugin) -> void
```

### Core Methods

```gdscript
## Scan and register all instructions/events/conditions/presets
func setup() -> void

## Clear all registries (called when the plugin is deactivated)
func teardown() -> void
```

### Internal Methods

```gdscript
func _register_all_instructions() -> void     # Scan instructions/
func _register_events() -> void               # Scan events/
func _register_conditions() -> void            # Scan conditions/

## Generic component registration method (all three component types share the same logic)
func _register_components_from_folders(
    folders: Array[String],          # List of directories to scan
    metadata_method: String,         # Metadata method name
    registry_name: String,           # Registrar name (string reference)
    register_method: String,         # Registration method name
    skip_prefix: String,             # Skip prefix (e.g. "base_", "instructions_")
    component_label: String          # Component label (used for logging)
) -> void

## Recursively scan a folder for GDScript files
func _scan_scripts_recursive(folder: String, skip_prefix: String = "") -> Array[String]
```

### Scanned Directories

| Component type | Scanned directories |
|---------|---------|
| Instructions | `res://addons/fuse/instructions/`, `res://addons/fuse/integration/`, `res://fuse_generated/instructions/` |
| Events | `res://addons/fuse/events/` |
| Conditions | `res://addons/fuse/conditions/` |

### Skip Rules

- Skip files starting with `"instructions_"` (instruction groups)
- Skip files starting with `"base_"` (base classes of events and conditions)
- Skipped files do not participate in registration (base class files such as `base_event.gd`, `base_condition.gd`)

### Generic Registration Flow

```gdscript
_register_components_from_folders(folders, metadata_method, registry_name, ...):
    1. Walk all directories, collecting .gd files (recursively)
    2. Skip files starting with skip_prefix
    3. Reset the duplicate counter for this component type
    4. For each file:
        a. load(script) → GDScript
        b. Verify script.has_method(metadata_method)
        c. Call script.call(metadata_method) → get the metadata
        d. Verify the metadata has an identifier (name_key / name)
        e. Dispatch to the matching Registry by string
            "InstructionRegistry" → InstructionRegistry.register_instruction(script)
            "EventRegistry"       → EventRegistry.register_event(script)
            "ConditionRegistry"   → ConditionRegistry.register_condition(script)
    5. Print statistics: success count, failed files, duplicate identifier count
```

---

## ComponentRegistry API

**File location**: `addons/fuse/editor/component_registry.gd`

**Class definition**:
```gdscript
class_name ComponentRegistry extends RefCounted
```

### Enum

```gdscript
enum ComponentType {
    INSTRUCTION,
    EVENT,
    CONDITION
}
```

### Static Registration Methods

```gdscript
## Register a component
static func register(component_type: ComponentType, component_class: GDScript, metadata_method: String) -> bool

## Reset the duplicate counter of a component type (call before scanning)
static func reset_duplicate_count(component_type: ComponentType) -> void

## Get the duplicate counter of a component type
static func get_duplicate_count(component_type: ComponentType) -> int
```

### Static Query Methods

```gdscript
## Get all registered components
static func get_all(component_type: ComponentType) -> Array[Dictionary]

## Find a component by name
static func get_by_name(component_type: ComponentType, name: String) -> Dictionary

## Get the registration count
static func get_count(component_type: ComponentType) -> int

## Search components (matching a given field)
## search_by: "name" / "category" / "keywords" / "" (all fields)
static func search(component_type: ComponentType, query: String, search_by: String = "") -> Array[Dictionary]
```

---

## Dedicated Registry APIs

### InstructionRegistry

**File location**: `addons/fuse/editor/instruction_selector/instruction_registry.gd`

```gdscript
static func register_instruction(instruction_class: GDScript) -> void
static func get_all_instructions() -> Array
static func get_instruction_by_name(name: String) -> Dictionary
static func get_instruction_count() -> int
static func search_instructions(query: String, search_by: String = "") -> Array[Dictionary]
static func clear_all() -> void
```

### EventRegistry

**File location**: `addons/fuse/editor/event_registry.gd`

```gdscript
static func register_event(event_class: GDScript) -> bool
static func get_all_events() -> Array
static func get_event_by_name(name: String) -> Dictionary
static func get_event_count() -> int
static func search_events(query: String, search_by: String = "") -> Array[Dictionary]
static func clear_all_events() -> void
```

### ConditionRegistry

**File location**: `addons/fuse/editor/condition_registry.gd`

```gdscript
static func register_condition(condition_class: GDScript) -> bool
static func get_all_conditions() -> Array
static func get_condition_by_name(name: String) -> Dictionary
static func get_condition_count() -> int
static func search_conditions(query: String, search_by: String = "") -> Array[Dictionary]
static func clear_all_conditions() -> void
```

---

## Registration Flow in Detail

### Full Registration Sequence

```
plugin.gd _enter_tree()
    │
    ├── FuseIconManager.init()          # Initialize the icon system
    │
    └── scanner = FuseComponentScanner.new(plugin)
        └── scanner.setup()
            │
            ├── _register_all_instructions()
            │   └── Scan the 3 instruction directories
            │       └── Each .gd file → load → validate metadata → InstructionRegistry
            │
            ├── _register_events()
            │   └── Scan the events/ directory
            │
            ├── _register_conditions()
            │   └── Scan the conditions/ directory
            │
            └── PresetRegistry.scan_presets()  # Stage 2.2
```

### Metadata Validation Rules

```gdscript
# The scanner verifies that each component satisfies the following conditions:
# 1. The script is loadable (load() returns a GDScript)
# 2. The metadata method is implemented (e.g. _get_instruction_metadata)
# 3. The metadata is not empty
# 4. It has an identifier (the name_key or name field is non-empty)
```

### Unregistration Sequence

```
plugin.gd _exit_tree()
    │
    └── scanner.teardown()
        ├── InstructionRegistry.clear_all()
        ├── EventRegistry.clear_all_events()
        ├── ConditionRegistry.clear_all_conditions()
        └── (PresetRegistry is not cleared here)
```

---

## Usage Guide

### Usage in plugin.gd

```gdscript
# Plugin entry point
var _component_scanner: FuseComponentScanner = null

func _enter_tree():
    if Engine.is_editor_hint():
        FuseIconManager.init()
        
        _component_scanner = FuseComponentScanner.new(self)
        _component_scanner.setup()

func _exit_tree():
    if _component_scanner:
        _component_scanner.teardown()
        _component_scanner = null
    
    FuseIconManager.cleanup()
```

### Component Registration Requirements

Every registrable component (instruction/event/condition) must implement the corresponding static metadata method:

```gdscript
# Instructions must implement
static func _get_instruction_metadata() -> InstructionMetadata

# Events must implement
static func _get_event_metadata() -> EventMetadata

# Conditions must implement
static func _get_condition_metadata() -> ConditionMetadata
```

### Skipping Base Class Files

Files starting with `base_` or `instructions_` are not registered. This ensures base class files are not mistakenly registered as usable components.

---

## Best Practices

### 1. Metadata Must Have an Identifier

```gdscript
static func _get_instruction_metadata() -> InstructionMetadata:
    var metadata = InstructionMetadata.new()
    metadata.name_key = "FUSE_INSTRUCTION_MY_NAME"  # Required
    # metadata.name = "Fallback Name"                # Or use the name field
    return metadata
```

### 2. Verify Registration After Adding a New Instruction

```gdscript
# Check in the Godot editor
var instructions = InstructionRegistry.get_all_instructions()
print("已注册指令: %d" % instructions.size())
```

### 3. Watch State on Plugin Reload

```gdscript
# _exit_tree must clean up completely, otherwise the next _enter_tree may register duplicates
# ComponentRegistry's register implementation handles duplicate detection
```

### 4. Organize Instructions into Subdirectories

Instructions can be placed in subdirectories (e.g. `instructions/movement/`); `_scan_scripts_recursive` supports recursive scanning.

---

## Common Pitfalls

### Pitfall 1: Base Class Files Registered by Mistake

**Problem**: Base class files such as `base_instruction.gd` get scanned and registration is attempted, but they lack the metadata method.

**Solution**: The scanner uses the `skip_prefix` parameter to skip files starting with `"instructions_"` and `"base_"`.

### Pitfall 2: Metadata Method Is Not static

**Problem**: `_get_instruction_metadata()` must be `static`. If it is defined as a regular method, `script.call(metadata_method)` errors out.

**Solution**: Always define metadata methods with `static func`.

### Pitfall 3: Incomplete Files Due to int Type Limitations

**Problem**: The ComponentScanner `load()`s each GDScript one by one while scanning; if a script has compile errors, `load()` returns null and the file is skipped.

**Solution**: Check the file for compile errors in the Godot editor.

### Pitfall 4: Registering the Same Component Twice

**Problem**: If `teardown()` is not called properly, components are registered again on the next `setup()`.

**Solution**: When ComponentRegistry's `register` method detects a duplicate identifier it updates instead of appending, recording it in `_duplicate_counts`. No manual deduplication is needed during scans.

### Pitfall 5: Directory Does Not Exist

**Problem**: A scanned directory does not exist (e.g. `res://fuse_generated/instructions/`).

**Solution**: In `_scan_scripts_recursive`, when `DirAccess.open()` fails it returns an empty array without affecting other directories.

---

## Reference Documents

- [Instruction Creation Guide](instruction-creation-guide.md)
- [Event Creation Guide](event-creation-guide.md)
- [Condition Creation Guide](condition-creation-guide.md)
- [Icon System Guide](icon-system-guide.md)
- [FuseEventBus Development Guide](event-bus-guide.md)

---

**Document maintainer**: Fuse development team | **Last updated**: 2026-07-07 | **Godot version**: 4.7
