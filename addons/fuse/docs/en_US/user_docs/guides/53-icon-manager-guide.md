> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/53-icon-manager-guide.md) | English

# Fuse Icon Manager User Guide

Want your instructions to show the correct icons in the editor? FuseIconManager makes it easy. We provide two icon systems: **builtin icons** (shipped with Godot) and the **custom icon library** (your own icons).

## Quick Start

### Option 1: Use a Builtin Icon (Recommended)

```gdscript
@tool
extends BaseInstruction
class_name MyInstruction

static func _get_instruction_metadata() -> InstructionMetadata:
    metadata = InstructionMetadata.new()
    metadata.name_key = "FUSE_INSTRUCTION_MY_NAME"
    metadata.category_key = "FUSE_CATEGORY_CUSTOM"
    metadata.builtin_icon = "Play"  # Use a Godot builtin icon
    return metadata
```

### Option 2: Use the Custom Icon Library

```gdscript
@tool
extends BaseInstruction
class_name MyInstruction

static func _get_instruction_metadata() -> InstructionMetadata:
    metadata = InstructionMetadata.new()
    metadata.name_key = "FUSE_INSTRUCTION_MY_NAME"
    metadata.category_key = "FUSE_CATEGORY_CUSTOM"
    metadata.custom_icon = "my_custom_icon"  # Use your custom icon
    return metadata
```

### Option 3: Backward Compatibility (Legacy Code)

```gdscript
metadata.icon_name = "Play"  # Still works, but builtin_icon is recommended
```

## Common Builtin Icon Names

These icons can be used directly in the `builtin_icon` field:

**Flow control**
- `Loop` - loops
- `Branch` - branching / if-else
- `Time` - time / waiting

**Variable operations**
- `Array` - arrays
- `New` - new / create
- `View` - view / print

**Node operations**
- `Node` - nodes
- `Edit` - edit / modify
- `Call` - call a method

**Debugging**
- `Debug` - debugging
- `Print` - print

**General icons**
- `Script`, `Play`, `Stop`, `Pause`
- `Add`, `Remove`, `Save`, `Load`
- `File`, `Folder`, `Search`, `Tools`, `Settings`

The full list has 1,011 icons; see [icon-system-guide.md](../../../zh_CN/dev_docs/guides/icon-system-guide.md) (Chinese).

## Custom Icon Library

### What Is an Icon Library?

FuseIconLibrary is a resource file that manages all custom icons centrally, providing:
- **Unified storage**: all custom icons in a single `.tres` file
- **Visual management**: edit the Dictionary directly in the Inspector
- **Version controllable**: `.tres` files can be committed to Git
- **Name indexing**: access icons by string name

### Three Ways to Use Custom Icons

#### Option A: Batch Import via a Tool Script (Recommended)

```bash
# 1. Run the import tool
Project → Tools → Execute Script → import_custom_icons.gd

# 2. Select the directory containing the icon files
# Supports: .svg, .png, .jpg, .webp, etc.

# 3. Icons are imported into default_icon_library.tres automatically
```

**Example**:
```
Icon file: icons/custom/count.svg
Name after import: count

Usage: metadata.custom_icon = "count"
```

#### Option B: Add Manually in the Inspector

1. Open `addons/fuse/core/resources/default_icon_library.tres` in the editor
2. Add an entry to the `icons` dictionary:
   - **Key**: `my_custom_icon`
   - **Value**: drag in the icon file (Texture2D)

#### Option C: Add Dynamically in Code

```gdscript
var library = load("res://addons/fuse/core/resources/default_icon_library.tres")
if library and library.has_method("add_icon"):
    library.add_icon("my_icon", preload("res://icons/my_icon.svg"))
```

## Where Icons Are Displayed (Two Places)

### 1. Instruction Selector

The instruction selector uses your icon configuration automatically, with no extra steps:

**Using a builtin icon:**
```gdscript
metadata.builtin_icon = "Print"
```

**Using the custom icon library:**
```gdscript
metadata.custom_icon = "my_custom_icon"
```

The instruction selector will show the corresponding icon.

### 2. Inspector Panel (Array[BaseInstruction])

The Inspector displays icons via the `@icon` decorator. You need to run a tool to sync:

```bash
# Step 1: Extract Godot builtin icons (one-time; needed when using builtin icons)
Project → Tools → Execute Script → generate_builtin_icons.gd

# Step 2: Update @icon in instruction files (after each icon configuration change)
Project → Tools → Execute Script → update_instruction_icon_decorators.gd

# Step 3: Restart the editor
```

The tool automatically adds the following at the top of your instruction file:

```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/Print.png")  # Added automatically (builtin icon)
# or
@icon("res://addons/fuse/icons/custom/my_icon.svg")  # Added automatically (custom icon)
extends BaseInstruction
class_name MyInstruction
```

Now the Inspector shows the correct icon too.

**Note**: for custom_icon, the icon file must already exist in the `addons/fuse/icons/custom/` directory.

## Using the Tool Scripts

### Extracting Builtin Icons

`generate_builtin_icons.gd` extracts icons from the Godot editor theme and saves them as PNG files.

**Smart scanning features:**
- Automatically scans the `events/` and `instructions/` directories
- Collects every `builtin_icon` value actually in use
- Extracts only the icons that are needed, saving space
- Deduplicates and sorts automatically

**When to use it:**
- The first time you use the icon system
- After adding a new `builtin_icon` configuration
- Whenever the icon library needs updating

**Result:**
- Icons are saved to `addons/fuse/icons/builtin/`
- They are also imported into `default_icon_library.tres` (if IMPORT_TO_LIBRARY is enabled)
- Only icons actually in use are extracted

**Run:**
```
Project → Tools → Execute Script
Select generate_builtin_icons.gd → click Run
```

**Sample output:**
```
============================================================
Extract Godot builtin icons (auto scan)
============================================================

Step 1: Scanning the events and instructions directories...
  Found 8 icons in use

  Icons in use:
    - Branch
    - Debug
    - Loop
    - Node
    - Print
    - Script
    - ZoomReset
    - ...

Step 2: Extracting icons...
✓ Saved: Branch → res://addons/fuse/icons/builtin/Branch.png
✓ Saved: Debug → res://addons/fuse/icons/builtin/Debug.png
...

============================================================
Done! Success: 8, Failed: 0
Icons saved to: res://addons/fuse/icons/builtin/
Imported into icon library: 8
============================================================
```

### Importing Custom Icons

`import_custom_icons.gd` batch-imports icon files into FuseIconLibrary.

**When to use it:**
- You need to use custom icons
- You have a batch of icon files to import

**Result:**
- Icons are imported into `default_icon_library.tres` automatically
- File names are converted to icon names automatically (extension stripped)
- Recursive scanning of subdirectories is supported

**Run:**
```
Project → Tools → Execute Script
Select import_custom_icons.gd → click Run
Select the directory containing the icon files
```

**Supported formats:** .png, .svg, .jpg, .jpeg, .webp, .tga, .bmp

**Example:**
```
Icon file: icons/custom/my_icon.svg
Name after import: my_icon
Usage: metadata.custom_icon = "my_icon"
```

### Updating @icon Decorators

`update_instruction_icon_decorators.gd` scans all instruction files and updates `@icon` according to the icon configuration.

**When to use it:**
- You changed an instruction's `builtin_icon`, `custom_icon`, or `icon_name`
- You added a new instruction with an icon configuration

**Result:**
- Updates the `@icon` decorator in all instruction files automatically
- Looks up the icon configuration by priority: builtin_icon > custom_icon > icon_name
- Skips instructions without any icon configuration
- Preserves existing custom `@icon` entries (if already present with a correct path)

**Run:**
```
Project → Tools → Execute Script
Select update_instruction_icon_decorators.gd → click Run
```

**Sample output:**
```
✓ Updated: print.gd → builtin_icon = Print
✓ Updated: custom_instruction.gd → custom_icon = my_icon (custom)
✓ Updated: old_instruction.gd → icon_name = Debug (legacy)
✓ Skipped: no_icon_instruction.gd (no icon configuration)
```

**Priority order:**
The tool looks up the icon configuration in the following order:
1. `builtin_icon` - Godot builtin icons
2. `custom_icon` - custom icon library
3. `icon_name` - backward-compatible field

## Complete Workflow

Creating a new instruction with an icon:

### Using a Builtin Icon

```gdscript
# 1. Create the instruction file
@tool
extends BaseInstruction
class_name DebugPrint

static func _get_instruction_metadata() -> InstructionMetadata:
    metadata = InstructionMetadata.new()
    metadata.name_key = "FUSE_INSTRUCTION_DEBUG_PRINT_NAME"
    metadata.category_key = "FUSE_CATEGORY_DEBUG"
    metadata.builtin_icon = "Debug"  # Use a Godot builtin icon
    return metadata

func execute(context: ExecutionContext):
    print("Debug output!")
    finished.emit()
```

```bash
# 2. Run the tool to update @icon (if it should show in the Inspector)
Project → Tools → Execute Script → update_instruction_icon_decorators.gd

# 3. Restart the editor
```

### Using the Custom Icon Library

```gdscript
# 1. Import custom icons (if not yet imported)
Project → Tools → Execute Script → import_custom_icons.gd
# Select the directory containing the icons

# 2. Create the instruction file
@tool
extends BaseInstruction
class_name MyCustomInstruction

static func _get_instruction_metadata() -> InstructionMetadata:
    metadata = InstructionMetadata.new()
    metadata.name_key = "FUSE_INSTRUCTION_MY_NAME"
    metadata.category_key = "FUSE_CATEGORY_CUSTOM"
    metadata.custom_icon = "my_custom_icon"  # Use the custom icon library
    return metadata

func execute(context: ExecutionContext):
    print("Custom instruction!")
    finished.emit()
```

```bash
# 3. Run the tool to update @icon (if it should show in the Inspector)
Project → Tools → Execute Script → update_instruction_icon_decorators.gd

# 4. Restart the editor
```

Done! Your instruction now shows the correct icon in both the instruction selector and the Inspector.

## Backward Compatibility

The old icon configuration methods still work, so existing code continues to run unchanged.

### Supported Legacy Fields

**1. icon_name field (backward compatible)**
```gdscript
metadata.icon_name = "Debug"  # Still works
```
- The custom icon library is checked first
- If not found there, it is looked up as a builtin icon

**2. icon field (Texture2D resource)**
```gdscript
metadata.icon = preload("res://custom_icon.svg")  # Still works
```
- Uses the texture resource directly
- Compatible with the old direct-assignment approach

**3. @icon decorator (file level)**
```gdscript
@icon("res://path/to/icon.svg")
@tool
extends BaseInstruction
```
- Used by the Inspector panel
- Can coexist with the metadata configuration

### New Priority Rules

The system looks up icons in the following priority order:

1. **builtin_icon** - Godot builtin icons (recommended for standard icons)
2. **custom_icon** - custom icon library (recommended for project-specific icons)
3. **icon_name** - backward-compatible field (type detected automatically)
4. **icon** - Texture2D resource (legacy)
5. **@icon decorator** - used by the Inspector (file-level decorator)

If all of the fields above are empty or invalid, the instruction uses Godot's default script icon.

## Checking Whether an Icon Exists

Not sure whether an icon name is correct? Use these methods to check:

### Checking Builtin Icons

```gdscript
if FuseIconManager.has_builtin_icon("MyIcon"):
    metadata.builtin_icon = "MyIcon"
else:
    print("内置图标不存在，使用默认图标")
    metadata.builtin_icon = "Script"
```

### Checking Custom Icons

```gdscript
if FuseIconManager.has_custom_icon("my_custom_icon"):
    metadata.custom_icon = "my_custom_icon"
else:
    print("自定义图标不存在，使用内置图标")
    metadata.builtin_icon = "Script"
```

### Choosing an Icon Dynamically

```gdscript
# Try the custom icon first; fall back to a builtin icon if missing
if FuseIconManager.has_custom_icon("my_icon"):
    metadata.custom_icon = "my_icon"
elif FuseIconManager.has_builtin_icon("MyIcon"):
    metadata.builtin_icon = "MyIcon"
else:
    metadata.builtin_icon = "Script"  # Default icon
```

## FAQ

### Q: The instruction selector shows the correct icon, but the Inspector shows an old one?

A: The Inspector uses the `@icon` decorator; run `update_instruction_icon_decorators.gd` to sync, then restart the editor.

### Q: What happens if an icon name is misspelled?

A: The system shows a placeholder icon (a gray square with a red dot). Check the icon name spelling, or verify it with `has_builtin_icon()` / `has_custom_icon()`.

### Q: Should I choose builtin_icon or custom_icon?

A:
- **builtin_icon** - for standard Godot editor icons (Script, Node, Play, Debug, etc.)
- **custom_icon** - for project-specific custom icons (branding, special feature icons, etc.)

### Q: How do I add custom icons to the icon library?

A: Three ways:
1. **Recommended**: run the `import_custom_icons.gd` tool to batch import
2. Open `default_icon_library.tres` in the Inspector and add entries manually
3. Call `FuseIconLibrary.add_icon()` in code to add them dynamically

### Q: Where should custom icon files go?

A:
- If you use `import_custom_icons.gd`, icons can live in any directory
- If you add them manually to `default_icon_library.tres`, `addons/fuse/icons/custom/` is recommended
- If you use `metadata.icon`, icons can be anywhere in the project

### Q: Can I use my own custom icon files?

A: Yes, in several ways:
- Via the icon library (recommended): `metadata.custom_icon = "my_icon"`
- Direct texture assignment (legacy): `metadata.icon = preload("res://path/to/icon.svg")`
- Via the @icon decorator: `@icon("res://path/to/icon.svg")`

### Q: The tool script cannot be found?

A: Make sure the files are in the `tools/` directory:
- `tools/generate_builtin_icons.gd`
- `tools/import_custom_icons.gd`
- `tools/update_instruction_icon_decorators.gd`

### Q: The update tool reports "custom_icon file not found"?

A: This means `update_instruction_icon_decorators.gd` cannot find the corresponding icon file. Fixes:
1. Make sure you ran `import_custom_icons.gd` to import the icons
2. Or manually place the icon file in the `addons/fuse/icons/custom/` directory
3. Check that the icon name is correct (no extension)

### Q: Can the icon library be shared with other projects?

A: Yes! `default_icon_library.tres` is a standard Godot Resource file:
- It can be copied directly to other projects
- It can be committed to Git for version control
- It can be edited visually in the Inspector

## Next Steps

- [icon-system-guide.md](../../../zh_CN/dev_docs/guides/icon-system-guide.md) (Chinese) - full technical documentation and API reference
- [custom_instruction.md](../best_practices/custom_instruction.md) - creating custom instructions
- [custom_event.md](../best_practices/custom_event.md) - creating custom events
