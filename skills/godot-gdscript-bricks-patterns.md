---
name: godot-gdscript-bricks-patterns
description: Coding patterns from Project Juicy Godot - Godot 4.6 GDScript Bricks visual programming system
version: 1.0.0
source: local-git-analysis
analyzed_commits: 200
last_updated: 2026-02-05
---

# Project Juicy Godot - GDScript & Bricks Patterns

## Project Overview

This is a **Godot 4.6** project developing two major systems:
- **Bricks** - Visual programming system (similar to Game Creator)
- **JuicyMixer** - Game effect system (shake, spring, tween, timeline)

## Commit Conventions

### Standard Format

This project uses **Conventional Commits** with Chinese descriptions:

```
<type>[: <scope>] <description>

<optional detailed body>
```

**Types:**
- `feat:` - New features
- `fix:` - Bug fixes
- `refactor:` - Code refactoring
- `docs:` - Documentation updates
- `test:` - Testing and test updates
- `debug:` - Debugging sessions

**Scopes (common):**
- `timeline` - JuicyMixer Timeline driver
- `runtime-instance` - Event RuntimeInstance architecture
- `i18n` - Internationalization/localization
- `mouse-enter`, `mouse-exit` - Specific events
- `action_runner` - Bricks ActionRunner system

**Examples:**
```bash
feat: 完成 JuicyTimelineDriver 状态隔离迁移
fix(timeline): pass state parameter to _initialize_track_states
refactor(timeline): complete state migration for public interfaces
docs: 添加 JuicyMixer Driver 状态污染修复完成报告
feat: 修复 JuicyShakeDriver 噪声生成器状态污染问题
```

### Commit Patterns

**Incremental Refactoring Pattern:**
When doing large refactors, break into small, focused commits:
```
refactor(timeline): add TimelineState inner class for state isolation
refactor(timeline): use TimelineState in prepare() method
refactor(timeline): use TimelineState in process() method with temporary bridge
refactor(timeline): complete state migration for track processing methods
refactor(timeline): complete state migration for cleanup methods
refactor(timeline): complete state migration for public interfaces
feat: 完成 JuicyTimelineDriver 状态隔离迁移
```

**Migration Pattern:**
When migrating multiple events/components, commit individually:
```
feat: 迁移 OnTimer 到 RuntimeInstance 架构
feat: 迁移 OnInterval 和 OnInputKey 到 RuntimeInstance 架构
feat: 迁移 OnArea2DEnter 和 OnArea3DEntered 到 RuntimeInstance 架构
feat: 迁移 OnSignalFromGroup 到 RuntimeInstance 架构
feat: 完成 OnMouseButton 和 OnCooldownFinished 的 RuntimeInstance 迁移
```

## Code Architecture

### Bricks Visual Programming System

```
addons/bricks/
├── core/                      # Core system classes
│   ├── base/                  # Base classes
│   │   ├── base_event.gd      # BaseEvent class
│   │   ├── base_instruction.gd # BaseInstruction class
│   │   ├── base_condition.gd  # BaseCondition class
│   │   └── execution_context.gd
│   ├── trigger.gd             # Trigger node
│   ├── runtime_event_instance.gd     # Event runtime state
│   └── runtime_action_runner_instance.gd
│
├── events/                    # Event types
│   ├── animation/             # Animation events
│   ├── audio/                 # Audio events
│   ├── input/                 # Input events
│   ├── lifecycle/             # Lifecycle events (_ready, _process, etc.)
│   ├── node/                  # Node events
│   ├── physics/               # Physics events
│   ├── scene/                 # Scene events
│   ├── timing/                # Timer events
│   ├── tween/                 # Tween events
│   └── ui/                    # UI events
│
├── instructions/              # Instruction types
│   ├── flow_control/          # Loops, conditions
│   ├── node_operations/       # Node operations
│   ├── tween/                 # Tween instructions
│   └── ui/                    # UI instructions
│
├── conditions/                # Condition types
│   ├── animation/
│   ├── composite/
│   ├── distance/
│   ├── input/
│   ├── node/
│   ├── physics/
│   ├── time/
│   └── variable/
│
├── localization/              # i18n
│   └── translations.csv       # All translations
│
├── utils/                     # Utilities
│   ├── bricks_node_utils.gd   # Node path resolution
│   └── signal_manager.gd
│
├── editor/                    # Editor tools
├── tests/                     # Test scenes
└── docs/                      # Documentation
    ├── architecture/          # Architecture docs
    ├── development/           # Development guides
    ├── system/                # System docs
    └── user/                  # User guides
```

### JuicyMixer System

```
addons/juicy_mixer/
├── core/                      # Core classes
├── drivers/                   # Driver implementations
│   ├── juicy_shake_driver.gd
│   ├── juicy_spring_driver.gd
│   ├── juicy_tween_driver.gd
│   └── juicy_timeline_driver.gd
├── resources/                 # Resource definitions
├── middleware/                # Middleware (LOD, TimeScale, Channel)
├── editor/                    # Editor tools
├── tests/                     # Test scenes
└── docs/                      # Documentation
```

## File Naming Conventions

### GDScript Files
- **snake_case**: `bricks_node_utils.gd`, `juicy_timeline_driver.gd`
- **Prefix pattern**:
  - Events: `on_<event_name>.gd` (e.g., `on_mouse_button.gd`)
  - Instructions: `<action>_<target>.gd` (e.g., `tween_property.gd`)
  - Conditions: `check_<condition>.gd` (e.g., `check_is_playing.gd`)

### Class Names
- **PascalCase**: `class_name BricksNodeUtils extends RefCounted`
- **Prefix pattern**:
  - Events: `OnMouseButton`, `OnArea2DEnter`
  - Instructions: `TweenProperty`, `SetPropertyValue`
  - Conditions: `CheckIsPlaying`, `CheckDistance`

### Test Files
- Test scripts: `test_<feature>.gd`
- Test scenes: `test_<feature>.tscn`
- Located in `test_scripts/` or `addons/<system>/tests/`

## GDScript Coding Patterns

### Resource-based Architecture

Bricks uses Godot's **Resource system** extensively:

```gdscript
class_name BaseEvent extends Resource

@export var target_node: NodePath = NodePath("")
@export var property_path: String = ""

## Execute event (must be implemented by subclasses)
func execute(context: ExecutionContext) -> void:
    push_error("Event not implemented")
```

**Key Points:**
- Events, Instructions, Conditions are Resources (not Nodes)
- Stored in Trigger nodes as sub-resources
- Use `@export` for inspector-visible properties
- Implement `get_config_dict()` and `load_from_dict()` for serialization

### RuntimeInstance Pattern

Events use **RuntimeEventInstance** for state management:

```gdscript
class_name RuntimeEventInstance extends RefCounted

## Event must implement this to declare runtime state
static func get_default_runtime_state() -> Dictionary:
    return {
        "previous_state": null,
        "cooldown_remaining": 0.0
    }

## Event then uses the state
func _on_event_fired():
    var state = get_runtime_state()
    state["previous_state"] = current_state
```

**Why:**
- Resources are shared between instances (no instance-specific state)
- RuntimeEventInstance provides isolated state per Trigger
- Events declare their state needs via `get_default_runtime_state()`
- No need to modify core system code

### Editor-safe Node Resolution

Use **BricksNodeUtils** for editor-compatible node path resolution:

```gdscript
## In editor mode (Resource inspector)
func _get_property_list():
    if Engine.is_editor_hint():
        var editor_interface = Engine.get_singleton("EditorInterface")
        var edited_root = editor_interface.get_edited_scene_root()
        _target_node_instance = BricksNodeUtils.find_node_from_resource_context(
            edited_root, self, target_node
        )

## At runtime (during execution)
func execute(context: ExecutionContext):
    var target = context.get_node(target_node)
    # Do something with target
```

**Special Handling for "..":**
When Trigger is stored as child node, relative path `..` means "resource owner node" not "parent node":

```gdscript
# In BricksNodeUtils.find_node_from_resource_context()
var path_string = str(target_path)
if path_string == "..":
    # Return resource owner node, not parent
    return resource_owner
```

### Thread Safety in Editor Mode

**CRITICAL:** Some methods are not thread-safe in editor:

```gdscript
## ❌ WRONG - Causes thread error in editor
func _get_node_material():
    return _target_node_instance.get_material()  # THREAD ERROR!

## ✅ CORRECT - Use property access only
func _get_node_material():
    var material = _target_node_instance.get("material")
    if material != null and material is Material:
        return material
    return null
```

**Methods to avoid in editor:**
- `get_material()`
- `get_surface_override_material()`
- `get_active_materials()`

**Alternative:** Use `get("property_name")` property access.

### Caching for Performance

Cache expensive property list calculations:

```gdscript
## Cache variables
var _cached_material_properties: Array[PropertyInfo] = []
var _cached_material_node: Node = null

func _get_material_properties() -> Array[PropertyInfo]:
    # Check cache validity
    if _cached_material_node == _target_node_instance and not _cached_material_properties.is_empty():
        return _cached_material_properties

    # Compute properties
    var properties = _compute_material_properties()

    # Update cache
    _cached_material_properties = properties
    _cached_material_node = _target_node_instance
    return properties

## Invalidate cache when needed
var target_node: NodePath = NodePath(""):
    set(value):
        target_node = value
        _cached_material_properties.clear()
        _cached_material_node = null
```

### Property List Dynamic Generation

Use `_get_property_list()` for dynamic inspector properties:

```gdscript
func _get_property_list() -> Array[Dictionary]:
    var properties: Array[Dictionary] = []

    # Add category
    properties.append({
        name = "Tween Property",
        type = TYPE_NIL,
        hint = PROPERTY_HINT_NONE,
        usage = PROPERTY_USAGE_CATEGORY
    })

    # Add dynamic enum
    properties.append({
        name = "property_path",
        type = TYPE_STRING,
        hint = PROPERTY_HINT_ENUM,
        hint_string = _get_property_enum_string(),
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    return properties
```

### Localization Pattern

All user-facing strings use localization system:

```gdscript
## In translations.csv
BRICKS_INSTRUCTION_TWEEN_PROPERTY_NAME,ZH_CN:属性补间,EN:Property Tween

## In code
func _get_instruction_metadata() -> InstructionMetadata:
    metadata.name_key = "BRICKS_INSTRUCTION_TWEEN_PROPERTY_NAME"
    metadata.description_key = "BRICKS_INSTRUCTION_TWEEN_PROPERTY_DESC"

## Use localized logging
func _log_debug(message: String):
    BricksLogger.debug(message, "BRICKS_INSTRUCTION_TWEEN_PROPERTY_NAME")
```

**Localized logging methods:**
- `_log_debug(message)`
- `_log_info(message)`
- `_log_warning(message)`
- `_log_error(message)`

### Signal Connection (Godot 4.x)

Use **Callable** for signal connections:

```gdscript
## ✅ CORRECT - Godot 4.x style
object.signal_name.connect(_on_signal_name)

func _on_signal_name():
    pass

## ❌ WRONG - Old Godot 3.x style
object.connect("signal_name", self, "_on_signal_name")
```

### Type Annotations

Always use explicit type annotations:

```gdscript
## Good
var value: float = 0.0
var items: Array[Resource] = []

## Function return types
func get_value() -> Variant:
    pass

func get_properties() -> Array[PropertyInfo]:
    pass
```

## Workflows

### Creating New Bricks Components

**Use these specialized skills:**
- `/bricks-instruction-generator` - For new instructions
- `/bricks-event-generator` - For new events
- `/bricks-condition-generator` - For new conditions

**Manual steps:**
1. Create file in appropriate category folder
2. Extend base class (`BaseInstruction`, `BaseEvent`, `BaseCondition`)
3. Implement required methods
4. Add metadata with translation keys
5. Add translations to `localization/translations.csv`
6. Create test scene in `tests/` folder

### Adding New Features to JuicyMixer

1. Create new Track/Driver in `drivers/` or `resources/`
2. Inherit from base class
3. Implement required methods
4. Register in DriverRegistry
5. Add tests in `tests/`

### Localization Workflow

1. Add translation keys to `addons/bricks/localization/translations.csv`
2. Format: `KEY,ZH_CN:中文,EN:English`
3. Use in code via `BricksLocalization.tr("KEY")`
4. Verify with check script: `test_scripts/check_translations.gd`

### Testing Pattern

Test files follow naming convention:
- Test script: `test_<feature>.gd`
- Test scene: `test_<feature>.tscn`
- Location: `test_scripts/` or `addons/<system>/tests/`

```gdscript
## Test template
extends Node

func _ready():
    test_feature()

func test_feature():
    assert(true, "Test description")
    print("Test passed!")
```

### Documentation Pattern

Documentation is organized by type:
- `docs/plans/` - Implementation plans and completion reports
- `docs/analysis/` - Analysis and audit documents
- `addons/bricks/docs/architecture/` - Architecture documentation
- `addons/bricks/docs/development/` - Development guides
- `addons/bricks/docs/system/` - System documentation
- `addons/bricks/docs/user/` - User guides

## Important Constraints

### Godot Version
- **Target:** Godot 4.6
- **Language:** GDScript 2.0
- **Always use:** Godot 4.x syntax

### Editor Safety
- Check `Engine.is_editor_hint()` before node operations
- Avoid method calls that trigger thread checks in editor
- Use property access instead of method calls where possible

### File Organization
- **Many small files > few large files**
- High cohesion, low coupling
- 200-400 lines typical, 800 max
- Extract utilities from large components

### No .gdignore Files
**CRITICAL:** Never create `.gdignore` files while working. They cause Godot to ignore entire folders, making resources unavailable in the editor.

### Abstract Methods (Godot 4.5+)
Use `@abstract` annotation for abstract methods:

```gdscript
@abstract
func execute(context: ExecutionContext) -> void:
    pass
```

### Tab Indentation
**Always use TAB** for indentation (Godot standard).

## Common Patterns

### Error Handling
```gdscript
func execute(context: ExecutionContext) -> void:
    var target = context.get_node(target_node)
    if not target:
        _log_error("Target node not found: " + str(target_node))
        return
    # Continue...
```

### Node Path Handling
```gdscript
@export var target_node: NodePath = NodePath("")

func _ready():
    if not target_node.is_empty():
        var node = get_node_or_null(target_node)
        if node:
            # Use node
            pass
```

### Resource Validation
```gdscript
func validate() -> String:
    if target_node.is_empty():
        return "Target node is required"
    if property_path.is_empty():
        return "Property path is required"
    return ""  # Empty string = valid
```

### Dynamic Property Enumeration
```gdscript
func _get_available_properties() -> Array[PropertyInfo]:
    var properties: Array[PropertyInfo] = []

    if property_source == PropertySource.NODE_PROPERTY:
        var prop_list = _target_node_instance.get_property_list()
        for prop_dict in prop_list:
            var prop_info = PropertyInfo.create(prop_dict)
            properties.append(prop_info)

    return properties
```

## Resource Management

### Serialization Support
```gdscript
func get_config_dict() -> Dictionary:
    return {
        "target_node": str(target_node),
        "property_path": property_path,
        "to_value": to_value
    }

func load_from_dict(config_dict: Dictionary) -> bool:
    target_node = NodePath(config_dict.get("target_node", ""))
    property_path = config_dict.get("property_path", "")
    to_value = config_dict.get("to_value", 0.0)
    return true
```

### Cloning Support
```gdscript
func clone() -> Resource:
    return duplicate(true)
```

---

**Last Updated:** 2026-02-05
**Godot Version:** 4.6-stable
**Branch:** Develop_brick
