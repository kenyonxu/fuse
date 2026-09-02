> 🌐 [**中文版**](../../../zh_CN/system_docs/analysis/base_event_analysis.md) | English

# BaseEvent Analysis Report


> **Analyzed as of**: 2026-07-07 (each article verified against code during the same-day full documentation audit; implementation evolution after this point defers to the source code; for recently verified mechanical conclusions see the threading / runtime_instance / preset_nested articles)
## Document Overview

This report presents a comprehensive analysis of the `BaseEvent` core script in the Fuse visual programming system. `BaseEvent` is the base class of the event system (class_name BaseEvent extends Resource); it defines the lifecycle interface, signal mechanism, runtime state management, and error handling framework shared by all events, providing the foundation for event-driven functionality in the visual programming system.

**Source file:** [base_event.gd](../../../../core/base/base_event.gd)
**Lines:** 534
**Base class:** Resource
**Subclass examples:** OnAnimationStarted, OnAnimationFinished, OnBodyEntered, etc.

---

## 1. Class Overview and Responsibilities

BaseEvent is the abstract base class of all Fuse events. As a Resource subclass it can be serialized into .tres files, held and driven by Trigger nodes.

### Core Responsibilities

1. **Lifecycle management**: defines the initialize / terminate / reset lifecycle methods
2. **Signal triggering**: provides the two core signals triggered and stopped
3. **Runtime state**: provides runtime state storage via RuntimeEventInstance
4. **Error handling**: unified FuseError error management
5. **Resource name management**: supports localized automatic resource_name updates
6. **Metadata interface**: provides event categorization and search info via _get_event_metadata()
7. **Logging**: leveled localized log output
8. **Performance tracing**: built-in performance tracing interface

### Design Characteristics

- Marked as an abstract class with the `@abstract` annotation
- Supports editor-mode running via the `@tool` annotation
- All subclasses must override the `_update_resource_name()` method
- Provides two initialization paths: `initialize()` and `initialize_with_runtime_instance()`

---

## 2. Core Properties

### @export Properties

| Property | Type | Default | Description |
|------|------|--------|------|
| log_level | FuseLogger.LogLevel | INFO | Log output level control |

### Instance Properties

| Property | Type | Description |
|------|------|------|
| _fuse_error | FuseError | Error instance for unified error handling |
| _trigger_ref | Node | Trigger node reference, used to emit stop notifications |
| _runtime_instance_ref | RuntimeEventInstance | Runtime instance reference for accessing runtime state |
| _last_locale | String | Locale code from the last resource_name update |
| icon_name | String | Icon name (recommended) |
| icon | Texture2D | Icon resource (backward compatibility) |

### Static Properties

| Property | Type | Description |
|------|------|------|
| _fuse_localization_class | RefCounted | Cached localization class reference, avoiding repeated load() |

### Constants

| Constant | Value | Description |
|------|----|------|
| FuseLocalization | preload | Localization utility class |
| VariableOperations | preload | Variable operations utility class |
| VariableScopeUtils | preload | Variable scope utility class |
| STOP_REASON_CONDITION_MET | "condition_met" | Stopped because a condition was met |
| STOP_REASON_MAX_REPEATS | "max_repeats" | Reached the maximum repeat count |
| STOP_REASON_MANUAL | "manual" | Stopped manually |
| STOP_REASON_ERROR | "error" | Stopped due to an error |

---

## 3. Key Methods

### 3.1 Lifecycle Methods

#### initialize(owner_node: Node) -- Initializes the event

Called by the Trigger in `_ready()` to connect signals and start listening.

```
Base class default behavior:
  1. Check editor mode → skip
  2. Create error: "BaseEvent.initialize() must be overridden in subclass"
```

Subclasses must override this method to connect concrete Godot signals or set up polling logic.

#### initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -- Runtime-instance initialization

Memory-optimized path; uses RuntimeEventInstance to avoid resource duplication.

```
Execution flow:
  1. Check editor mode → skip
  2. Save the runtime_instance reference into _runtime_instance_ref
  3. Call set_trigger_ref(owner_node) to set the Trigger reference
  4. Call initialize(owner_node) for backward compatibility
  5. Call _initialize_runtime_state(runtime_instance) to initialize runtime state
```

**Note**: this method does not connect the `triggered` signal. Signal connection is done by `RuntimeEventInstance._init()` at construction time — in `_init`, RuntimeEventInstance connects its own `_on_event_triggered` method to `event_definition.triggered`, then forwards to the Trigger via its own `triggered` signal (see [runtime_event_instance.gd:30](../../../../core/runtime_event_instance.gd)). This is the recommended initialization path. Subclasses may override this method to handle specific runtime state initialization.

#### terminate(owner_node: Node) -- Cleans up the event

Called by the Trigger in `_exit_tree()` to disconnect signals and clean up resources.

```
Base class default behavior:
  1. Output a debug log
```

Subclasses should override this method to:
- disconnect connected signals
- clean up RuntimeEventInstance state
- release runtime references

#### reset() -- Resets the event state

Restores the event to its initial state.

```
Base class default behavior:
  1. Clear _fuse_error
  2. Clear _runtime_instance_ref
```

### 3.2 Abstract Methods

#### _update_resource_name() -- Updates the resource name

Marked with `@abstract`; subclasses must implement it. Generates a human-readable resource name from the current property values and locale settings.

```
Implementation requirements:
  - Build a descriptive name from the property values
  - Localize with FuseLocalization.translate_format()
  - Write the result into resource_name
```

### 3.3 Runtime State Methods

#### get_default_runtime_state() -> Dictionary -- Returns the default runtime state

Returns the event's default runtime state declaration.

```gdscript
Default return:
{
    "initialized": true,
    "trigger_count": 0,
    "last_trigger_time": 0.0
}
```

Subclasses should override this method and append custom state:

```gdscript
func get_default_runtime_state() -> Dictionary:
    var base = super.get_default_runtime_state()
    base["my_custom_state"] = false
    return base
```

#### _initialize_runtime_state(runtime_instance: RuntimeEventInstance) -- Initializes the runtime state

Subclasses may override this method to run specific runtime state initialization logic. The default implementation only outputs a debug log.

#### get_runtime_instance() -> RuntimeEventInstance -- Returns the runtime instance

Returns `_runtime_instance_ref`, or null if not set.

#### get_runtime_instance_with_fallback(runtime_instance: RuntimeEventInstance = null) -- Runtime instance retrieval with fallback

When multiple Triggers share the same Event resource, the passed-in runtime_instance argument takes priority, solving the state-overwrite problem with shared resources.

### 3.4 Signal Triggering Methods

#### _emit_triggered(context: Node, owner_node: Node = null) -- Emits the triggered signal

Automatically sets the "trigger" meta on the context, preventing the signal from being broadcast to other RuntimeEventInstances. Suitable for pooled objects and shared Event resources.

```
Execution flow:
  1. Determine trigger_node (owner_node argument first, then _trigger_ref)
  2. If both context and trigger_node are valid, set the "trigger" meta on context
  3. Emit the triggered signal
```

#### notify_stopped(reason: String, context: Dictionary = {}) -- Notifies that the event stopped

Emits the stopped signal and notifies the Trigger to emit the event_stopped signal.

```
Execution flow:
  1. Emit the stopped(reason, context) signal
  2. If _trigger_ref exists:
     a. Duplicate context and add event, event_type, event_description
     b. If the Trigger has the event_stopped signal, emit it
```

### 3.5 Metadata Methods

#### validate() -> Array[String] -- Validates the event configuration

Returns a list of validation errors; an empty array means it passed. The base class returns an empty array by default.

#### get_description() -> String -- Returns the event description

Returns a human-readable event description. The base class returns "Base Event" by default.

#### get_event_type() -> String -- Returns the event type

Returns the event type identifier. The base class returns "base" by default. Examples: "animation_started", "body_entered".

#### get_event_category() -> String -- Returns the event category

Returns the event category. The base class returns "general" by default. Common categories include "signal", "animation", "physics", etc.

#### get_event_icon() -> Texture2D -- Returns the event icon

Returns the event's icon resource. Priority matches `BaseInstruction.get_icon()`:

```
Fallback priority:
  1. metadata.builtin_icon → FuseIconManager.get_builtin_icon()
  2. metadata.custom_icon  → FuseIconManager.get_custom_icon()
  3. metadata.icon_name    → FuseIconManager (has_custom_icon check)
  4. metadata.icon         → return the Texture2D directly
  5. Instance variables icon_name / icon (backward compatibility with old events)
```

#### get_detailed_info() -> Dictionary -- Returns detailed event information

Returns a dictionary containing the event type, description, and category; if `_fuse_error` exists, adds a `fuse_error` key (whose value is the error details returned by `FuseError.get_error_details()`).

#### _get_node_display_name(path: NodePath) -> String -- Human-readable node paths

Converts relative paths (e.g. `..`, `../NodeName`) into human-readable node names, used by `_update_resource_name()` and `get_description()`. Resolution strategy: an explicit node name at the end of the path → extracted directly; pure relative references resolved via `FuseNodeUtils` in editor mode; smart fallback when multiple layers of `..` cannot be resolved (e.g. `../../..` → `[3 levels up]`).

#### _get_event_metadata() -> EventMetadata -- Returns event metadata

Static method implemented by subclasses to provide the metadata used by the instruction picker (name, category, description, keywords, icon).

### 3.6 Error Handling Methods

#### _create_fuse_error(message, error_type, context) -- Creates an error instance

#### _create_fuse_error_localized(message_key, error_type, args, context) -- Creates a localized error

```
Execution flow:
  1. Translate message_key using the cached localization class
  2. If args is non-empty, use translate_format(); otherwise use translate()
  3. If the translation system is unavailable, fall back to manually replacing {key} placeholders
  4. Create a FuseError instance and store it in _fuse_error
  5. Output a localized error log
```

#### get_fuse_error() / has_fuse_error() -- Error queries

### 3.7 Automatic Resource Name Updates

#### _set(property, value) -> bool

Intercepts resource_name property sets to enable automatic updates on locale change.

```
Execution flow:
  1. If the property is not resource_name → return false (default handling)
  2. Initialize FuseLocalization
  3. Check whether the current locale differs from _last_locale
  4. If different → update _last_locale and call _update_resource_name()
  5. Return false so Godot uses the updated value
```

### 3.8 Performance Tracing Methods

#### _start_performance_track(method_name) / _stop_performance_track(method_name)

Uses FusePerformanceTracker to trace event method execution time. The trace name format is "event_type.method_name", e.g. "on_process.on_process".

---

## 4. RuntimeEventInstance Integration

BaseEvent integrates with RuntimeEventInstance through the `_runtime_instance_ref` property to enable runtime state management.

### Integration Architecture

```
BaseEvent (Resource, shareable)
    |
    ├── _runtime_instance_ref ──→ RuntimeEventInstance (unique at runtime)
    |                                    |
    |                                    ├── runtime state dictionary
    |                                    └── event description info
    |
    └── Trigger (Node, holder)
         ├── calls initialize_with_runtime_instance()
         ├── calls terminate()
         └── listens to the triggered signal
```

### State Storage Pattern

BaseEvent uses the "self-declaring state" pattern:

1. Subclasses declare state variables in `get_default_runtime_state()`
2. RuntimeEventInstance calls this method at creation to initialize the state
3. At runtime, state is read/written via `get_runtime_instance().set_runtime_state(key, value)`
4. State is cleaned up in terminate()
5. State is reset in reset()

### Shared Resource Problem

When an Event resource is shared by multiple Triggers, `get_runtime_instance_with_fallback()` ensures each Trigger uses its own RuntimeEventInstance, avoiding state overwrites.

The `_emit_triggered()` method sets the "trigger" meta on the context to identify the trigger source, preventing the signal from being broadcast to unrelated RuntimeEventInstances.

---

## 5. Signal Mechanism

### triggered(context: Node) -- The trigger signal

Emitted when the event's trigger condition is met. The context argument carries the relevant context information (e.g. the body node entering an area).

Triggering approaches:
- Direct call: `triggered.emit(context_node)` -- simple cases
- Safe triggering: `_emit_triggered(context_node, owner_node)` -- recommended; automatically sets the trigger meta

### stopped(reason: String, context: Dictionary) -- The stop signal

Emitted when the event stops. reason uses the STOP_REASON_* constants to identify the stop cause.

Stop reasons:

| Constant | Value | Scenario |
|------|----|------|
| STOP_REASON_CONDITION_MET | "condition_met" | Condition events stop after their condition is met |
| STOP_REASON_MAX_REPEATS | "max_repeats" | Maximum repeat count reached |
| STOP_REASON_MANUAL | "manual" | Stop invoked manually |
| STOP_REASON_ERROR | "error" | Stopped due to an error |

### Signal Flow

Event signals are not broadcast directly from BaseEvent to the Trigger; they are relayed and filtered through RuntimeEventInstance:

```
BaseEvent.triggered(context)
    └──→ RuntimeEventInstance._on_event_triggered(context)
          │   Filtered by the context's "trigger" meta:
          │   forwarded only when meta == owner_trigger, otherwise ignored
          └──→ RuntimeEventInstance.triggered.emit(context)
                └──→ Trigger._on_event_triggered()
                      └──→ ActionRunner.execute_instructions()

BaseEvent.stopped
    └──→ Trigger.event_stopped (if present, notified back via _trigger_ref)
```

The value of the relay layer: when the same Event resource is shared by multiple Triggers, each Trigger holds its own RuntimeEventInstance; `_emit_triggered()` writes the "trigger" meta onto the context, and RuntimeEventInstance filters on it, ensuring the signal only reaches its owning Trigger and avoiding mutual interference.

---

## 6. Relationship with BaseTrigger

BaseEvent and BaseTrigger cooperate:

1. **Ownership**: the Trigger holds one or more Event resources
2. **Lifecycle management**: the Trigger calls Event.initialize() in _ready() and Event.terminate() in _exit_tree()
3. **Signal listening**: the Trigger connects the Event.triggered signal to trigger instruction execution
4. **Stop notification**: the Event notifies the Trigger back via _trigger_ref to emit the event_stopped signal
5. **Execution context**: the Trigger provides the runtime context (owner_node) for the Event

### Initialization Flow

```
Trigger._ready()
    ├── for each Event:
    │   ├── create RuntimeEventInstance(event, self)  // in _init:
    │   │   ├── _initialize_runtime_state()         // initialize the state dictionary
    │   │   └── event.triggered.connect(_on_event_triggered)  // signal relay
    │   └── runtime_instance.start_listening()
    │       └── Event.initialize_with_runtime_instance(owner_node, runtime_instance)
    │           ├── Event.set_trigger_ref(owner_node)
    │           ├── Event.initialize(owner_node)  // implemented by subclass
    │           └── Event._initialize_runtime_state(runtime_instance)
    └── RuntimeEventInstance.triggered.connect(_on_event_triggered)  // Trigger listens to the REI
```

### Cleanup Flow

```
Trigger._exit_tree()
    ├── for each Event:
    │   ├── Event.triggered.disconnect(_on_event_triggered)
    │   └── Event.terminate(owner_node)  // implemented by subclass
```

---

## 7. Performance Considerations

### Localization Cache

The `_fuse_localization_class` static variable caches the FuseLocalization class reference, avoiding repeated `load()` calls. Per the comment, this improves performance by about 70%.

### Editor Mode Check

`initialize()` and `initialize_with_runtime_instance()` return immediately in editor mode, avoiding unnecessary initialization overhead.

### Performance Tracing

Provides `_start_performance_track()` and `_stop_performance_track()` methods, using FusePerformanceTracker to trace event method execution time. The trace name format is `{event_type}.{method_name}`, easing performance analysis.

### Resource Name Update Optimization

The `_set()` method intercepts resource_name sets so translations are only regenerated on locale change, avoiding a translation-system call on every property set.

### RuntimeEventInstance State Separation

Storing runtime state in RuntimeEventInstance rather than in the Event resource itself achieves:
- Resource sharing (multiple Triggers can share the same Event resource)
- Memory optimization (avoids resource duplication)
- Object-pool friendliness (pooling only needs to swap the RuntimeEventInstance)

### Potential Performance Issues

1. **Per-frame polling events**: some subclasses (e.g. OnAnimationLoop, OnAnimationMarker) detect via on_process() polling, which can incur overhead when many events exist
2. **RuntimeEventInstance state reads/writes**: frequent set_runtime_state / get_runtime_state calls involve Dictionary operations, which may become a bottleneck in high-frequency events
3. **Context node creation**: every triggered signal creates a temporary Node to carry meta information, involving node allocation and freeing

---

## 8. Subclass Implementation Pattern Summary

Based on analysis of existing subclasses (OnAnimationStarted, OnAnimationFinished, etc.), subclasses usually follow this pattern:

### Required Methods

| Method | Description |
|------|------|
| _update_resource_name() | Generates the localized resource name |
| _get_event_metadata() (static) | Provides the event metadata |
| initialize() | Connects signals or sets up polling |
| terminate() | Disconnects signals, cleans up references |

### Optional Methods

| Method | Description |
|------|------|
| get_default_runtime_state() | Declares runtime state variables |
| initialize_with_runtime_instance() | Runtime-instance initialization (advanced) |
| on_process(delta) | Per-frame polling logic |
| validate() | Parameter validation |
| get_description() | Event description text |
| get_event_type() | Event type identifier |
| get_event_category() | Event category |
| reset() | Resets runtime state |

### Typical Subclass Structure

```gdscript
class_name OnMyEvent extends BaseEvent

# @export properties (serialized into .tres)
@export var target_node: NodePath = NodePath("")

# Runtime references (not serialized)
var _target_ref: Node = null

# Declare runtime state
func get_default_runtime_state() -> Dictionary:
    var base = super.get_default_runtime_state()
    base["my_state"] = false
    return base

# Update the resource name
func _update_resource_name():
    resource_name = "OnMyEvent: " + str(target_node)

# Initialize (connect signals)
func initialize(owner_node: Node):
    _target_ref = owner_node.get_node_or_null(target_node)
    if _target_ref and _target_ref.some_signal.is_connected(_on_callback):
        _target_ref.some_signal.connect(_on_callback)

# Cleanup (disconnect signals)
func terminate(owner_node: Node):
    if _target_ref and is_instance_valid(_target_ref):
        if _target_ref.some_signal.is_connected(_on_callback):
            _target_ref.some_signal.disconnect(_on_callback)
    _target_ref = null

# Validation
func validate() -> Array[String]:
    var errors: Array[String] = []
    if target_node.is_empty():
        errors.append("目标节点不能为空")
    return errors

# Event metadata
static func _get_event_metadata() -> EventMetadata:
    var metadata = EventMetadata.new()
    metadata.name_key = "MY_EVENT_NAME"
    metadata.category_key = "MY_EVENT_CATEGORY"
    metadata.description_key = "MY_EVENT_DESC"
    metadata.keywords = ["关键词1", "关键词2"]
    metadata.builtin_icon = "MyIcon"
    return metadata
```

---

## 9. Overall Assessment

### Strengths

1. **Well-designed interface**: lifecycle methods (initialize/terminate/reset) are clear with a well-marked division of responsibilities
2. **Flexible state management**: RuntimeEventInstance integration supports resource sharing and object pooling
3. **Unified error handling**: FuseError provides consistent error management and query interfaces
4. **Localization support**: comprehensive localized logging and resource name support
5. **Safe signal mechanism**: _emit_triggered() resolves the signal broadcast problem for shared resources via meta identification
6. **Backward compatible**: initialize_with_runtime_instance() calls initialize() internally, preserving compatibility
7. **Performance considerations**: localization cache, editor-mode skip, performance tracing interface

### Weaknesses

1. **No unified framework for the on_process() pattern**: some subclasses poll via on_process(), but there is no unified timer management
2. **Context passing relies on a temporary Node**: every trigger creates a Node to carry meta information, incurring allocation overhead
3. **Missing event lifecycle hooks**: no optional hooks such as on_enable / on_disable are provided
4. **Unclear validation timing**: when validate() is called is decided by subclasses and external code; the base class enforces no validation flow

---

**Maintained by**: Fuse development team
**Last updated**: 2026-07-07
**Version**: 1.1.0
