> 🌐 [**中文版**](../../../zh_CN/dev_docs/guides/icon-system-guide.md) | English

# Fuse Icon System Development Guide

> **Goal**: Provide developers with a complete guide to using the Fuse icon system, covering icon registration, configuration, built-in icon references, and custom icon library management.

**Audience**: Fuse system developers, contributors

**Last updated**: 2026-07-07

---

## 📋 Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Design](#architecture-design)
3. [Core Components API](#core-components-api)
4. [Icon Configuration Methods](#icon-configuration-methods)
5. [Built-in Icon Reference](#built-in-icon-reference)
6. [Custom Icon Library](#custom-icon-library)
7. [Managing in the Plugin Lifecycle](#managing-in-the-plugin-lifecycle)
8. [Best Practices](#best-practices)
9. [Common Pitfalls](#common-pitfalls)
10. [Migration Guide](#migration-guide)

---

## System Overview

The Fuse icon management system provides a unified solution for icon retrieval and management, supporting a **four-level fallback** mechanism:

1. Local `builtin/` directory SVG/PNG files (highest priority)
2. `EditorTheme` built-in icons
3. Icons in the custom icon library `Resource`
4. Placeholder icons (auto-generated)

### Core Files

| File | Purpose |
|------|------|
| `addons/fuse/core/utils/fuse_icon_manager.gd` | Icon manager (RefCounted, all-static methods) |
| `addons/fuse/editor/metadata/fuse_metadata.gd` | Icon fields in the FuseMetadata base class (parent of InstructionMetadata) |
| `addons/fuse/core/resources/default_icon_library.tres` | Custom icon library resource file |

---

## Architecture Design

```
Fuse Instructions/Conditions/Events (Instruction/Condition/Event)
        │
        │ get_icon()
        ▼
InstructionMetadata
  ├─ icon_name: String        ← Recommended: Godot built-in icon name
  ├─ icon: Texture2D          ← Backward compatible: direct texture
  ├─ builtin_icon: String     ← Phase 2: validated icon name
  └─ custom_icon: String      ← Phase 2: custom library name
        │
        │ get_icon_texture()
        ▼
FuseIconManager (RefCounted, static methods)
  ├─ get_builtin_icon(name)       → local file > EditorTheme > placeholder icon
  ├─ get_custom_icon(name)        → custom icon library lookup
  ├─ get_icon(spec)               → smart routing (Texture2D / path / name)
  ├─ has_builtin_icon(name)       → check built-in icon existence
  └─ has_custom_icon(name)        → check custom icon existence
        │
        ▼
Load priority:
  1. res://addons/fuse/icons/builtin/<name>.svg/.png
  2. EditorInterface.get_editor_theme().get_icon(name, "EditorIcons")
  3. _custom_icon_library.get("icons")[name]
  4. _create_placeholder_icon(name) — 16×16 gray square + red dot marker
```

---

## Core Components API

### FuseIconManager

**File location**: `addons/fuse/core/utils/fuse_icon_manager.gd`

**Class definition**:
```gdscript
class_name FuseIconManager extends RefCounted
```

All methods are **static methods** and can be called without instantiation.

#### Initialization and Cleanup

```gdscript
## Initialize the icon manager, fetch the editor theme and load the custom icon library
static func init() -> void
```

- Internally uses the `_is_initialized` flag to ensure it initializes only once
- Only fetches `EditorInterface.get_editor_theme()` when `Engine.is_editor_hint()` is true
- Also calls `_load_custom_icon_library()` to load the custom icon library

```gdscript
## Clear the icon cache and the theme reference
static func cleanup() -> void
```

- Clears the `_icon_cache` dictionary
- Nulls out `_editor_theme`
- Resets `_is_initialized = false`

#### Icon Retrieval Methods

```gdscript
## Get a Godot built-in icon (four-level fallback)
static func get_builtin_icon(icon_name: String) -> Texture2D
```

**Fallback order**:
1. Check the `_icon_cache` cache
2. Local `res://addons/fuse/icons/builtin/<name>.svg` (if present)
3. Local `res://addons/fuse/icons/builtin/<name>.png` (if present)
4. `_editor_theme.get_icon(icon_name, "EditorIcons")`
5. `_create_placeholder_icon(icon_name)` — 16×16 gray square with a center red dot

```gdscript
## Get an icon intelligently (supports multiple input types)
static func get_icon(icon_spec: Variant) -> Texture2D
```

**Input type branches**:
- `Texture2D` → return directly (backward compatible)
- `String` starting with `"res://"` → call `_load_custom_icon(icon_spec)` to load the file
- `String` → try in order: `get_builtin_icon()` → `get_custom_icon()` → `_create_placeholder_icon()`
- `null` or empty string → return `null`

```gdscript
## Get an icon from the custom icon library
static func get_custom_icon(icon_name: String) -> Texture2D

## Check whether a built-in icon exists
static func has_builtin_icon(icon_name: String) -> bool

## Check whether a custom icon exists
static func has_custom_icon(icon_name: String) -> bool
```

#### Internal Methods

```gdscript
static func _load_custom_icon_library() -> void
## Load the custom icon library Resource from _custom_icon_library_path
## Default path: "res://addons/fuse/core/resources/default_icon_library.tres"

static func _load_custom_icon(icon_path: String) -> Texture2D
## Load the icon at the given file path (supports res:// paths), cached

static func _create_placeholder_icon(icon_name: String) -> Texture2D
## Generate a 16×16 placeholder icon (semi-transparent gray background + red dot marker)
```

### FuseMetadata (Base Class) Icon Fields

**File location**: `addons/fuse/editor/metadata/fuse_metadata.gd`  
**Note**: InstructionMetadata/EventMetadata/ConditionMetadata all inherit from FuseMetadata; the icon fields are defined in the base class.

```gdscript
## Icon name (prefer Godot built-in icon names)
@export var icon_name: String = ""

## Custom icon name (fetched from the custom icon library)
@export var custom_icon: String = ""

## Backward compatible: specify a Texture2D directly
@export var icon: Texture2D = null

## Get the icon texture
func get_icon_texture() -> Texture2D:
    # Prefer icon_name (the new recommended way)
    if not icon_name.is_empty():
        return FuseIconManager.get_builtin_icon(icon_name)

    # Then use custom_icon
    if not custom_icon.is_empty():
        return FuseIconManager.get_custom_icon(custom_icon)

    # Fall back to the icon field (backward compatible)
    if icon != null:
        return icon

    return null
```

---

## Icon Configuration Methods

### Recommended: Built-in Icon Name

```gdscript
static func _get_instruction_metadata() -> InstructionMetadata:
    var metadata = InstructionMetadata.new()
    metadata.name_key = "FUSE_INSTRUCTION_MY_NAME"
    metadata.category_key = "FUSE_CATEGORY_MY_CATEGORY"
    metadata.description_key = "FUSE_INSTRUCTION_MY_DESC"
    metadata.icon_name = "Script"   # Done in one line
    return metadata
```

### Method 2: Custom Icon Library

```gdscript
static func _get_instruction_metadata() -> InstructionMetadata:
    var metadata = InstructionMetadata.new()
    metadata.custom_icon = "my_special_icon"
    return metadata
```

### Method 3: Direct Texture (Backward Compatible)

```gdscript
static func _get_instruction_metadata() -> InstructionMetadata:
    var metadata = InstructionMetadata.new()
    metadata.icon = preload("res://addons/fuse/icons/instruction.svg")
    return metadata
```

### Method 4: The `@icon` Annotation (Class Level)

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/Script.png")
extends BaseInstruction
class_name MyInstruction
```

**Note**: The `@icon` annotation only affects display in the Godot editor; it is recommended to also set `metadata.icon_name` to ensure correct display within the Fuse system.

---

## Built-in Icon Reference

For the full list (thousands of Godot 4.7 built-in icons), see the original documentation. Common categories:

| Category | Recommended icons | Use cases |
|------|---------|---------|
| Flow control | `Branch`, `Loop`, `Time`, `Clock` | If/Else, For, Wait, Timer |
| Variable operations | `Array`, `New`, `Remove`, `Add`, `View` | Set/Get Variable, Create, Delete |
| Node operations | `Node`, `Node2D`, `Node3D`, `Edit`, `Call`, `Signal` | Find, Set Property, Call Method |
| Debugging | `Debug`, `Print`, `Error`, `Warning`, `Info` | Break, Print, Log |
| Playback | `Play`, `Stop`, `Pause`, `Save`, `Load` | Play Animation, Save Game |
| Input | `Keyboard`, `Mouse`, `Gamepad` | Input Events |
| Math | `Math`, `Vector3`, `Rotate`, `Scale` | Math Operations |
| Physics | `PhysicsBody`, `CollisionShape` | Physics Operations |

---

## Custom Icon Library

FuseIconManager supports loading a custom icon library Resource file that stores Fuse-specific icons.

### Configuration Path

```gdscript
static var _custom_icon_library_path: String = "res://addons/fuse/core/resources/default_icon_library.tres"
```

### Usage

```gdscript
# Specify the custom icon name in the metadata
metadata.custom_icon = "my_icon"

# Fetch it directly in code
var icon = FuseIconManager.get_custom_icon("my_icon")
if icon != null:
    button.icon = icon
```

### Creating a Custom Icon Library

A custom icon library is a Resource containing an `icons: Dictionary` property (`String -> Texture2D`):

```gdscript
# Create the script
extends Resource
class_name FuseIconLibrary

@export var icons: Dictionary = {}
```

Create the `.tres` file in the editor and fill in the icon name to texture mappings.

---

## Managing in the Plugin Lifecycle

### Initialization and Cleanup in plugin.gd

```gdscript
func _enter_tree():
    if Engine.is_editor_hint():
        FuseIconManager.init()

func _exit_tree():
    FuseIconManager.cleanup()
```

### Automatic Cold Start of the Cache

If `get_builtin_icon()` is called without `init()`, the manager automatically calls `init()`:

```gdscript
static func get_builtin_icon(icon_name: String) -> Texture2D:
    # ...
    if not _is_initialized:
        init()  # Auto-initialize
    # ...
```

---

## Best Practices

### 1. Icon Selection Principles

```gdscript
# ✅ Good choices
metadata.icon_name = "Print"      # Print/output instructions
metadata.icon_name = "Debug"      # Debug instructions
metadata.icon_name = "Node"       # Node operations
metadata.icon_name = "Branch"     # Conditional branches

# ❌ Avoid semantic mismatches
metadata.icon_name = "Script"     # For non-script-related instructions
metadata.icon_name = "File"       # For non-file operations
```

### 2. Always Check Icon Existence

```gdscript
var icon_name = "CustomIcon"
if FuseIconManager.has_builtin_icon(icon_name):
    metadata.icon_name = icon_name
else:
    metadata.icon_name = "Script"  # Fallback
```

### 3. Avoid Repeated Lookups in Loops

FuseIconManager already has an internal cache (`_icon_cache: Dictionary`), but avoid calling it every frame during editor drawing:

```gdscript
# ✅ Fetch once and reuse the reference
var cached_icon = FuseIconManager.get_builtin_icon("Play")
for item in items:
    item.set_icon(0, cached_icon)
```

### 4. Icon Names Are Case-Sensitive

Godot built-in icon names are case-sensitive, e.g. `"Script"` ≠ `"script"`. Use `has_builtin_icon()` to verify.

---

## Common Pitfalls

### Pitfall 1: Calling get_builtin_icon at Runtime

**Problem**: outside an editor context, `EditorInterface.get_editor_theme()` returns `null`.

**Solution**: FuseIconManager handles this automatically — `init()` checks `Engine.is_editor_hint()`. But icons only display fully in the editor; at runtime you must make sure icons are provided by other means.

### Pitfall 2: Custom Icon Library File Missing

**Problem**: the default load path `res://addons/fuse/core/resources/default_icon_library.tres` does not exist.

**Symptom**: the console prints `WARNING: 自定义图标库文件不存在: ...` and `get_custom_icon()` returns `null`.

**Solution**: create the resource file, or rely on the smart fallback mechanism of `get_icon()`.

### Pitfall 3: @icon Annotation Conflicts with metadata.icon_name

If both `@icon` and `metadata.icon_name` are set, Fuse internally uses `metadata.get_icon_texture()` to fetch icons (preferring `icon_name`), while the Godot editor uses `@icon`. Keep them consistent.

### Pitfall 4: Misusing the Deprecated icon Field

Older code uses `metadata.icon = preload("...")` to set a texture directly; new code should prefer the `metadata.icon_name` string approach. `metadata.icon` is kept as a fallback but is not recommended.

---

## Migration Guide

### Migrating from the Old System to the New System

**Old way**:
```gdscript
metadata.icon = preload("res://addons/fuse/icons/instruction.svg")
```

**New way**:
```gdscript
metadata.icon_name = "Script"
```

### Batch Migration Helper

You can use an `EditorScript` to batch-scan and replace icon references in instruction files (see the `migrate_icons.gd` template in the original documentation).

### Migration Checklist

- [ ] Call `FuseIconManager.init()` / `cleanup()` in `plugin.gd`
- [ ] Gradually migrate existing instructions to `icon_name`
- [ ] Put the custom icon library `.tres` file in place
- [ ] Test that each instruction icon displays correctly in the editor picker
- [ ] Test backward compatibility (the old `metadata.icon` still works)

---

## Reference Documents

- [Instruction Creation Guide](instruction-creation-guide.md)
- [Event Creation Guide](event-creation-guide.md)
- [Condition Creation Guide](condition-creation-guide.md)
- [Fuse Architecture Overview](../../system_docs/architecture/visual_programming_system_architecture.md)

---

**Document maintainer**: Fuse development team | **Last updated**: 2026-07-07 | **Godot version**: 4.7
