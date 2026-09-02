> 🌐 [**中文版**](../../../zh_CN/system_docs/architecture/editor_tools_design.md) | English

# Fuse Editor Tools Design

## Overview

The Fuse editor tools are a set of editor enhancement systems integrated into the Godot Inspector and the scene tree. They adopt an **Inspector plugin + selector dialogs + context menu** architecture pattern, providing users with component creation, search, debugging, static analysis, code generation, and other capabilities.

Unlike the originally envisioned visual node-graph editor, the current implementation focuses on an **Inspector-driven editing experience**, using Godot's native Inspector panel as the primary interaction entry point and extending editing capabilities through custom buttons and popups. This design avoids the complexity of maintaining a standalone visual editor while taking full advantage of Godot's editor infrastructure.

The editor tooling consists of 8 functional modules:

1. Inspector integration
2. Component registry system
3. Instruction selector
4. Component selector
5. Input key selector
6. Debugging tools
7. Static analysis
8. Instruction generator
9. Context menu tools
10. Metadata system

## Core Architecture

### Inspector Integration

Inspector integration is the core entry point of the Fuse editor tools. It enhances Fuse-related properties through Godot's `EditorInspectorPlugin` mechanism.

#### FuseInspectorPlugin

**File:** `addons/fuse/editor/fuse_inspector_plugin.gd`
**Inherits:** `EditorInspectorPlugin`

The unified Inspector plugin. It handles enhanced editing for three kinds of Fuse property types:

- **`Array[BaseInstruction]`** -- adds a "Click to add instruction" button to instruction array properties, opening the `InstructionSelector` dialog
- **`BaseEvent`** -- adds a "Click to select an event" button to event resource properties, opening the `ComponentSelector` dialog
- **`BaseCondition`** -- adds a "Click to select a condition" button to condition resource properties, opening the `ComponentSelector` dialog

Core design principle: the **decorator pattern**. Enhancement buttons are added via `add_custom_control()` and Godot's native property editors are **not suppressed**, preserving native array and resource editing capabilities.

Property type detection logic:
- Instruction arrays: matched via `TYPE_ARRAY` + the `BaseInstruction` keyword in `hint_string`, or by property name (`instructions`, `*_instructions`)
- Event resources: matched via `TYPE_OBJECT` + `PROPERTY_HINT_RESOURCE_TYPE` + `BaseEvent` in `hint_string`, or by property name (`event`, `*_event`)
- Condition resources: matched via `TYPE_OBJECT` + `PROPERTY_HINT_RESOURCE_TYPE` + `BaseCondition` in `hint_string`, or by property name (`condition`, `*_condition`)

#### ScopeVariableContainerPlugin

**File:** `addons/fuse/editor/scope_variable_container_plugin.gd`
**Inherits:** `EditorInspectorPlugin`

Provides a custom Inspector panel for `ScopeVariableContainer` nodes, allowing scope variables to be viewed and edited in the editor.

**Main features:**
- Displays all variables and values in the current scope using an `ItemList`
- Supports adding, removing, and refreshing variables
- Notifies the editor to update via `notify_property_list_changed()`

### Component Registry System

The component registry system adopts a layered architecture of a **unified registry + type-specific facades**.

#### ComponentRegistry (Unified Registry)

**File:** `addons/fuse/editor/component_registry.gd`
**class_name:** `ComponentRegistry`
**Inherits:** `RefCounted`

The unified registration center for all components (Instruction / Event / Condition), providing registration, query, and search capabilities.

**Core design:**
- Uses `static var` to store data for the three component kinds (`_instructions`, `_events`, `_conditions`)
- Uses `Dictionary` lookup tables to achieve O(1) lookup by name (`_instruction_map`, `_event_map`, `_condition_map`)
- Distinguishes component types via the `ComponentType` enum (`INSTRUCTION`, `EVENT`, `CONDITION`)
- Metadata method name convention: `_get_instruction_metadata`, `_get_event_metadata`, `_get_condition_metadata`

**Registration flow:**
1. Check whether the component class has the specified metadata method
2. Call the metadata method to obtain the metadata object
3. Prefer `name_key` as the identifier, falling back to `name`
4. Store the component info (`{"class": ..., "metadata": ...}`) in the array and the lookup table

**Search mechanism:**
- Supports searching across three dimensions: `name`, `category`, and `keywords`
- Compatible with both the new Resource metadata format (`get_localized_name()`) and the old Dictionary metadata format
- When no search field is specified, all dimensions are searched

#### InstructionRegistry / EventRegistry / ConditionRegistry (Type-Specific Facades)

**Files:**
- `addons/fuse/editor/instruction_selector/instruction_registry.gd`
- `addons/fuse/editor/event_registry.gd`
- `addons/fuse/editor/condition_registry.gd`

Three type-specific facade classes providing type-safe convenience APIs; internally they all delegate to `ComponentRegistry`.

| Method | InstructionRegistry | EventRegistry | ConditionRegistry |
|------|---------------------|---------------|-------------------|
| Register | `register_instruction()` | `register_event()` | `register_condition()` |
| Get all | `get_all_instructions()` | `get_all_events()` | `get_all_conditions()` |
| Find by name | `get_instruction_by_name()` | `get_event_by_name()` | `get_condition_by_name()` |
| Search | `search_instructions()` | `search_events()` | `search_conditions()` |
| Clear | `clear_all()` | `clear_all_events()` | `clear_all_conditions()` |

## Editor Tool Modules

### 1. Instruction Selector

**Directory:** `addons/fuse/editor/instruction_selector/`

The instruction selector selects from registered instructions and adds them to the target object's instruction array.

#### InstructionSelector

**File:** `instructions_selector.gd`
**class_name:** `InstructionSelector`
**Inherits:** `AcceptDialog`

The UI dialog of the instruction selector, laid out as a **search box + category tree**.

**Core behavior:**
- **Multi-select add mode**: each instruction row has its own plus button on the right; clicking it adds the instruction to the instruction array
- **Category tree structure**: instructions are grouped by the metadata `category` field
- **Search filtering**: the search box filters in real time, delegating to `InstructionSearch`
- **Deferred updates**: the Tree control is updated via `call_deferred()` to avoid operating on a blocked control during signal handling

**Add-instruction flow:**
1. The user clicks the plus button to the right of an instruction row
2. The instruction class is instantiated: `instruction_class.new()`
3. It is appended to the target object's instruction array
4. After waiting one frame, the write is validated
5. The editor is notified to refresh (`notify_property_list_changed()`, `emit_changed()`)

**Localization support:**
- Automatically detects the editor language when opened (the `editor_language` setting)
- Force-refreshes the localization cache of all instruction metadata
- All UI text is translated through `FuseLocalization`

#### InstructionSearch

**File:** `instructions_search.gd`
**class_name:** `InstructionSearch`
**Inherits:** `RefCounted`

The core search algorithm for instructions, using a three-tier weighted matching mechanism:

| Match tier | Search field | Weight |
|----------|----------|------|
| Tier 1 | Name | 100 |
| Tier 2 | Category | 50 |
| Tier 3 | Keywords | 30 |

Search results are sorted by weight in descending order. When the query is empty, all instructions are returned (with weight 0).

### 2. Component Selector

**File:** `addons/fuse/editor/component_selector/component_selector.gd`
**class_name:** `ComponentSelector`
**Inherits:** `AcceptDialog`

The unified component selector, supporting selection of both Event and Condition component types.

**Core behavior:**
- **Single-select replace mode**: double-clicking or pressing Enter selects the component, replaces the target property, and closes the dialog
- After selection, the component is instantiated directly and assigned to the target property
- Search filtering is performed through `ComponentRegistry.search()`
- Empty results show localized hint text

**Differences from InstructionSelector:**

| Feature | InstructionSelector | ComponentSelector |
|------|---------------------|-------------------|
| Selection mode | Multi-select (append to array) | Single-select (replace property) |
| Add method | Plus button on the right | Double-click / Enter |
| Applicable types | Instruction | Event / Condition |
| Tree column count | 2 (name + button) | 1 (name) |

### 3. Input Key Selector

**Directory:** `addons/fuse/editor/input_key_selector/`

Provides key-capture editing for input-related instructions.

#### InputKeySelector

**File:** `input_key_selector.gd`
**class_name:** `InputKeySelector`
**Inherits:** `EditorProperty`

An Inspector property editor that renders key-code properties as a button control.

**Workflow:**
1. Displays the current key name (e.g. "Key: W")
2. Clicking the button opens the `InputKeyDialog` dialog
3. After the dialog captures a key, it updates the property value via `emit_changed()`

#### InputKeyDialog

**File:** `input_key_dialog.gd`
**class_name:** `InputKeyDialog`
**Inherits:** `AcceptDialog`

The key-capture dialog. It captures key events using the Window's `window_input` signal.

**Key-capture flow:**
1. The user clicks the "Start capturing a key" button
2. The `window_input` signal is connected (fallback: connecting the SceneTree's `input` signal)
3. `InputEventKey` events are filtered: only `pressed` and non-`is_echo` events are handled
4. The `key_selected` signal is emitted and the dialog closes
5. Signal connections are cleaned up in `_notification(NOTIFICATION_VISIBILITY_CHANGED)` and `_exit_tree()`

### 4. Debugging Tools

**Directory:** `addons/fuse/editor/debugging/`

#### ExecutionTracker

**File:** `execution_tracker.gd`
**class_name:** `ExecutionTracker`
**Inherits:** `RefCounted`

The execution tracker provides runtime execution tracing. It records detailed histories of instruction execution for debugging and performance analysis.

**Tracked data structure:**
```
execution_history: Array[Dictionary]
  └── current_execution: Dictionary
        ├── start_time / end_time / total_time
        ├── context_id
        ├── steps: Array[Dictionary]
        │     ├── instruction_start: instruction started
        │     ├── instruction_complete: instruction completed (with execution time, success status, error message)
        │     ├── error: error event
        │     ├── performance_bottleneck: performance bottleneck
        │     └── custom_event: custom event
        ├── performance_metrics: {initial, final}
        ├── memory_snapshots: Array[{phase, timestamp, static_memory}]
        └── stats: {instruction_count, total_execution_time, average_execution_time, error_count, performance_issues, success_rate}
```

**Configurable tracking dimensions:**
- `track_performance_metrics` -- performance metrics
- `track_memory_usage` -- memory usage
- `track_variable_changes` -- variable changes
- `max_history_size` -- maximum number of history records (default 100)

**API:**
- `start_tracking(context)` / `stop_tracking()` -- session control
- `record_instruction_start()` / `record_instruction_complete()` -- instruction-level tracking
- `record_custom_event()` / `record_error()` / `record_performance_bottleneck()` -- event recording
- `get_execution_history()` / `get_recent_executions()` / `get_execution_stats()` -- queries
- `export_execution_history(file_path)` -- export to JSON

#### DebugVisualizer

**File:** `debug_visualizer.gd`
**class_name:** `DebugVisualizer`
**Inherits:** `Control`

The debug visualization panel, providing a graphical interface that displays execution history.

**UI layout:** an `HSplitContainer` split into left and right columns:
- **Left panel**: control buttons (refresh, clear, export, auto-refresh) + execution tree (`Tree`)
- **Right panel**: execution details (`RichTextLabel`) + performance chart placeholder (`Control`)

**Execution tree color scheme:**
- Green: completed successfully
- Red: has errors
- Yellow: has performance issues
- Light blue: instruction started
- Gray: custom event

**Auto refresh:** periodic refreshing via a `Timer` (default interval 1 second).

### 5. Static Analysis (Merged)

The static analysis logic has been moved from the standalone `InstructionValidator` / `StaticAnalysisPanel` into `InstructionAnalyzer.analyze_problems`, with results annotated on the FuseTopology main screen (entry code `topology/fuse_topology.gd`). The former `editor/static_analysis/` directory has been removed.

### 6. Instruction Generator

**Directory:** `addons/fuse/editor/instruction_generator/`

Generates Fuse instruction files automatically from a node class's methods and property information.

#### InstructionGenerator

**File:** `instruction_generator.gd`
**class_name:** `InstructionGenerator`
**Inherits:** `RefCounted`

The method instruction generator. It generates corresponding Fuse call instructions from Godot method signatures.

**Generated instruction structure:**
- `target_node: NodePath` -- target node path
- Each parameter is mapped to a corresponding `@export` property according to its type
- Optional return-value storage (`result_variable` + `result_variable_scope`)
- Supports the variable-binding variant (`use_variables`): each parameter can read from either a direct value or a variable

**Special handling for the variable-binding variant:**
- Generates `_source` (direct value/variable), `_value` (direct value), `_variable` (variable name), and `_scope` (scope) properties for each parameter
- Controls property visibility dynamically via `_get_property_list()`
- Sets `PROPERTY_USAGE_NO_EDITOR` dynamically according to options via `_validate_property()`

**Code generation utilities:**
- `TypeMapper` -- maps Godot types to GDScript types
- `ConflictHandler` -- handles file name conflicts

**Output location:** `res://fuse_generated/instructions/<ClassName>/`

#### PropertyInstructionGenerator

**File:** `property_instruction_generator.gd`
**class_name:** `PropertyInstructionGenerator`
**Inherits:** `RefCounted`

The property instruction generator, producing GET/SET property instructions.

**SET instructions:**
- Set the specified property value on the target node
- Support both the plain variant and the variable-binding variant
- Include target node validation and type checking

**GET instructions:**
- Read the specified property value from the target node
- Support saving to variables (Local / Scope / Global)
- The Scope scope supports multiple sources (nearest / custom ID / Trigger Scope / target node)

### 7. Context Menu

**Directory:** `addons/fuse/editor/context_menu/`

Extends the scene tree context menu through Godot 4's `EditorContextMenuPlugin`.

#### FuseContextMenuPlugin

**File:** `fuse_context_menu_plugin.gd`
**class_name:** `FuseContextMenuPlugin`
**Inherits:** `EditorContextMenuPlugin`

The entry class of the Fuse context menu system.

**Menu items provided (shown conditionally):**

| Menu item | Condition | Behavior |
|--------|------|------|
| Merge into Multi-Event Trigger | 2+ Trigger nodes selected and siblings | Merge into a MultiEventTrigger |
| Split into independent triggers | 1 MultiEventTrigger with 2+ bindings selected | Split into independent Trigger nodes |
| Generate instruction... | 1 node of any type selected | Open the method/property selection dialog |

**Instruction generation flow:**
1. The context menu triggers `_on_generate_instruction()`
2. A `MethodSelectorDialog` dialog is created
3. After the user picks a method or property, the corresponding Generator is invoked
4. The generated file is automatically registered with `InstructionRegistry`
5. A filesystem scan is triggered

#### TriggerMerger

**File:** `trigger_merger.gd`
**class_name:** `TriggerMerger`
**Inherits:** `RefCounted`

Merges multiple Trigger nodes into a single MultiEventTrigger node.

**Merge preconditions:**
- At least 2 nodes
- All nodes are Trigger nodes
- All nodes share the same parent

**Merge operations:**
1. Sort by scene tree index
2. Create an EventBinding for each Trigger (deep-copying `event_definition` and `action_runner`)
3. Validate binding data integrity
4. Create the MultiEventTrigger and set `event_bindings`
5. Full UndoRedo support (`create_action` + `add_do_method` + `add_undo_method`)

#### TriggerSplitter

**File:** `trigger_splitter.gd`
**class_name:** `TriggerSplitter`
**Inherits:** `RefCounted`

Splits a MultiEventTrigger node into multiple independent Trigger nodes (the inverse of merging).

**Split preconditions:**
- The node type is MultiEventTrigger
- It contains at least 2 EventBindings

**Naming strategy:** the event class name is used as the Trigger name (e.g. `InputEvent`); numeric suffixes are appended on name conflicts.

### 8. Metadata System

**File:** `addons/fuse/editor/metadata/fuse_metadata.gd`
**class_name:** `FuseMetadata`
**Inherits:** `Resource`

The unified metadata Resource base class, providing a consistent metadata interface for all Fuse components.

**Field design:**

| Field | Type | Description |
|------|------|------|
| `name_key` | String | Name translation key (preferred) |
| `category_key` | String | Category translation key (preferred) |
| `description_key` | String | Description translation key (preferred) |
| `name` | String | Direct name text (backward compatible, deprecated) |
| `category` | String | Direct category text (backward compatible, deprecated) |
| `description` | String | Direct description text (backward compatible, deprecated) |
| `keywords` | Array | Search keywords |
| `builtin_icon` | String | Godot built-in icon name |
| `custom_icon` | String | Fuse custom icon library name |
| `icon_name` | String | Icon name (backward compatible) |
| `icon` | Texture2D | Icon texture (backward compatible) |

**Localization cache mechanism:**
- Lazy caching via `_cache_valid` / `_cache_locale` / `_cached_instance_id`
- Automatically invalidated on language switch or after `duplicate()`
- `get_localized_name()` / `get_localized_category()` / `get_localized_description()` refresh the cache automatically

**Icon resolution priority:**
1. `builtin_icon` -- Godot built-in icon (via `FuseIconManager.get_builtin_icon()`)
2. `custom_icon` -- Fuse custom icon library (via `FuseIconManager.get_custom_icon()`)
3. `icon_name` -- backward compatible (checks the custom library first, then built-in icons)
4. `icon` -- a direct Texture2D resource

## Design Decisions

### 1. Inspector-driven instead of a standalone editor

The Inspector plugin pattern was chosen over a standalone visual node-graph editor for the following reasons:
- **Lower complexity**: avoids maintaining a standalone visual editor by leveraging Godot's existing Inspector infrastructure
- **Consistency**: the user's editing experience stays consistent with Godot's native workflow
- **Extensibility**: `_parse_property()` precisely controls which properties get enhanced

### 2. The decorator pattern preserves the native editor

All Inspector enhancements use `add_custom_control()` to add extra UI and **do not suppress** Godot's native property editors (`_parse_property()` returns `false`). Users can use native editing and Fuse enhancements side by side.

### 3. Unified registry + type-specific facades

`ComponentRegistry` is the single registration and query implementation; `InstructionRegistry` / `EventRegistry` / `ConditionRegistry` only provide type-safe convenience APIs. This eliminates code duplication across the three registries while keeping each type's API semantically clear.

### 4. Service classes built on static methods

Utility classes such as registries, searchers, and validators mostly use `static func`, avoiding instantiation overhead. This is because in most scenarios the editor tools only need a single global state.

### 5. Incremental localization strategy

All editor tools use `FuseLocalization` for localization uniformly, following this pattern:
- Prefer translation keys (`translate("KEY")`)
- Fall back to hardcoded Chinese text
- Automatically detect the editor language setting when opening a dialog

### 6. Deferred updates avoid blocking the Tree control

Operating on a Tree control inside signal callbacks can trigger a blocked state, so all Tree updates are deferred via `call_deferred()`, combined with an `_updating_ui` flag to prevent re-entrancy.

### 7. UndoRedo integration

TriggerMerger and TriggerSplitter fully integrate Godot's UndoRedo system using the `create_action()` + `add_do_method()` + `add_undo_method()` + `commit_action()` pattern, ensuring users can undo merge/split operations.

### 8. Automatic code generation and instant registration

`.gd` files generated by the instruction generator are immediately registered with the system via `InstructionRegistry.register_instruction()`, and a filesystem scan is triggered through `EditorInterface.get_resource_filesystem().scan()`, ensuring generated instructions are instantly available.

## File Index

| File path | class_name | Inherits | Responsibility |
|----------|------------|------|------|
| `editor/fuse_inspector_plugin.gd` | -- | EditorInspectorPlugin | Unified Inspector enhancement |
| `editor/scope_variable_container_plugin.gd` | -- | EditorInspectorPlugin | Scope variable editing |
| `editor/component_registry.gd` | ComponentRegistry | RefCounted | Unified component registry |
| `editor/condition_registry.gd` | ConditionRegistry | RefCounted | Condition registration facade |
| `editor/event_registry.gd` | EventRegistry | RefCounted | Event registration facade |
| `editor/instruction_selector/instruction_registry.gd` | InstructionRegistry | RefCounted | Instruction registration facade |
| `editor/instruction_selector/instructions_selector.gd` | InstructionSelector | AcceptDialog | Instruction selector dialog |
| `editor/instruction_selector/instructions_search.gd` | InstructionSearch | RefCounted | Instruction search algorithm |
| `editor/component_selector/component_selector.gd` | ComponentSelector | AcceptDialog | Component selector dialog |
| `editor/input_key_selector/input_key_selector.gd` | InputKeySelector | EditorProperty | Key property editor |
| `editor/input_key_selector/input_key_dialog.gd` | InputKeyDialog | AcceptDialog | Key capture dialog |
| `editor/debugging/debug_visualizer.gd` | DebugVisualizer | Control | Debug visualization panel |
| `editor/debugging/execution_tracker.gd` | ExecutionTracker | RefCounted | Execution tracker |
| `editor/instruction_generator/instruction_generator.gd` | InstructionGenerator | RefCounted | Method instruction generator |
| `editor/instruction_generator/property_instruction_generator.gd` | PropertyInstructionGenerator | RefCounted | Property instruction generator |
| `editor/context_menu/fuse_context_menu_plugin.gd` | FuseContextMenuPlugin | EditorContextMenuPlugin | Context menu entry |
| `editor/context_menu/trigger_merger.gd` | TriggerMerger | RefCounted | Trigger merge tool |
| `editor/context_menu/trigger_splitter.gd` | TriggerSplitter | RefCounted | Trigger split tool |
| `editor/metadata/fuse_metadata.gd` | FuseMetadata | Resource | Metadata Resource base class |
