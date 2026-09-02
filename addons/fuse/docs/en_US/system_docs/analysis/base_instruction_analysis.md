> 🌐 [**中文版**](../../../zh_CN/system_docs/analysis/base_instruction_analysis.md) | English

# BaseInstruction Analysis Report


> **Analysis date**: 2026-07-07 (code verified report-by-report during the same-day full documentation audit; for implementation evolution after that date the source code is authoritative — see the threading / runtime_instance / preset_nested and other reports for recently verified mechanism conclusions)
> Reference code: `addons/fuse/core/base/base_instruction.gd` (1294 lines), `addons/fuse/core/runtime_instruction_instance.gd` (548 lines)
> Maintained by: Fuse development team | Status: major 2026-07-07 update (aligned with the v2.0+ architecture)

## Document Overview

This report analyzes the `BaseInstruction` core script in the Fuse visual programming system. `BaseInstruction` is the `@abstract` base class of all instructions (inheriting from `Resource`), providing the instruction system with an execution framework, a state machine, error handling, logging, timeouts, smart sync detection, i18n resource name synchronization, icon management, runtime instance cooperation, and other capabilities.

> **Historical note**: The original first version (v1) of this file described `execute()` as "calling `_on_execution_completed()` by default" and listed timeouts / unified errors / logging / async execution as "improvement suggestions". All of these features have landed in v2.0; the old draft's conclusions rested on wrong premises and have been removed. The current document was rewritten in the as-is description style.

## 1. Class Positioning and Inheritance

```gdscript
@tool
@icon("res://addons/fuse/icons/instruction.svg")
@abstract
class_name BaseInstruction extends Resource
```

- **`@abstract`**: cannot be instantiated directly; must be subclassed.
- **`extends Resource`**: instructions are data resources — configurable in the Inspector, serializable, reusable; the same resource can be shared by multiple `RuntimeInstructionInstance` objects.
- **`@tool`**: enables in-editor preview/validation.

Subclasses must implement the following `@abstract` methods (no default implementation; a missing one is a compile error):

| Method | Location | Purpose |
|------|------|------|
| `execute(context: ExecutionContext)` | base_instruction.gd:379–380 | execution entry point; subclasses implement the instruction logic |
| `_setup_metadata()` | base_instruction.gd:299–300 | sets name/description/category and other metadata |
| `_update_resource_name()` | base_instruction.gd:185–186 | refreshes `resource_name` according to the current state/locale (for Inspector display) |

> **Correction to the old draft**: `execute()` has **no** default implementation — it is declared only as `@abstract func execute(context: ExecutionContext)`; the subclass is responsible for calling `_start_execution(context)` and, on completion, calling `_on_execution_completed()` or `_on_execution_error()`/`set_error()`.

## 2. Core Enums and Fields

### 2.1 The Three Enums (base_instruction.gd:66–94)

| Enum | Values | Purpose |
|------|------|------|
| `ExecutionStatus` | PENDING / RUNNING / COMPLETED / CANCELLED / ERROR | instruction lifecycle state machine |
| `CompletionSignalTiming` | ON_START / ON_FINISH | when the `finished` signal is emitted |
| `ExecutionMode` | AUTO_DETECT / FORCE_ASYNC / FORCE_SYNC | sync/async path selection, used together with `can_execute_sync()` |

### 2.2 Key Fields

| Field | Type | Line | Description |
|------|------|------|------|
| `metadata` | `InstructionMetadata` (static) | 101 | populated via `_get_instruction_metadata()` or `_setup_metadata()` |
| `execution_status` | `ExecutionStatus` | 102 | defaults to PENDING |
| `error_message` | `String` | 103 | error description |
| `_fuse_error` | `FuseError` | 105 | unified error object (v2.0+) |
| `log_level` | `FuseLogger.LogLevel` (@export) | 131 | defaults to INFO |
| `completion_timing` | `CompletionSignalTiming` (@export) | 140 | defaults to ON_FINISH |
| `execution_mode` | `ExecutionMode` (@export) | 143 | defaults to AUTO_DETECT |
| `_timeout_timer` / `_timeout_duration` / `_execution_start_time` | `SceneTreeTimer` / `float` / `float` | 146–148 | timeout management |
| `_is_synchronous_hint` / `_sync_capability_cached` / `_sync_capability_detected` / `_sync_hint_manually_set` | `bool` | 134–137 | smart sync detection caches |
| `_last_locale` | `String` | 242 | i18n resource name sync: the locale used the last time resource_name was updated |
| `_is_finished_connected` | `bool` | 104 | prevents duplicate `finished` connections |

### 2.3 Signals

```gdscript
signal finished   # base_instruction.gd:56
```

Emitted when the instruction completes (success / cancellation / error alike). In `ON_START` mode it is emitted immediately inside `_start_execution()`; in `ON_FINISH` mode it is emitted inside `_on_execution_completed()`. `_on_execution_error()` emits it regardless of timing.

## 3. Execution Lifecycle

```
execute(context)            [implemented by subclasses, @abstract]
    └── _start_execution(context)        # :391 set status RUNNING + timestamp + timeout timer
            └── (ON_START mode calls _on_execution_completed immediately)
    └── ... subclass business logic ...
    └── _on_execution_completed()        # :694 set COMPLETED + cleanup + (ON_FINISH) emit finished
    │   or _on_execution_error(...)      # :718 set_error + cleanup + emit finished
    │   or cancel()                      # :466 set CANCELLED + emit finished
    │   or _on_timeout()                 # :953 set_error(TIMEOUT_ERROR) + emit finished
    └── reset()                          # :889 reset to PENDING, clear errors, disconnect signals, clear caches
```

**Status query methods**: `get_execution_status()` / `is_running()` / `is_completed()` / `has_error()` / `get_error_message()` / `get_execution_time()` (valid only while RUNNING).

## 4. i18n Resource Name Synchronization (_set Interception)

`_set(property, value)` intercepts writes to `resource_name` (base_instruction.gd:256–274):

1. Calls `FuseLocalization.init()` to make sure localization is ready.
2. Compares `FuseLocalization.get_locale_code()` with `_last_locale`.
3. On a locale change (or first set) → calls `_update_resource_name()` to regenerate the translated name.
4. Always returns `false`, letting Godot proceed with the default write (which writes the value we just refreshed).

**Trigger scenarios**: after the editor switches locale or a .tres file is deserialized from disk. Together with the `_last_locale` field (:242) this achieves "automatically refreshing the Inspector display when the locale changes".

## 5. Four-Level Icon Fallback (get_icon)

`get_icon() -> Texture2D` (base_instruction.gd:643–666) takes the metadata from the script's static method `_get_instruction_metadata()` and returns by the following priority (consistent with `FuseMetadata.get_icon_texture()`):

| Priority | Field | Source |
|--------|------|------|
| 1 | `builtin_icon` | `FuseIconManager.get_builtin_icon()` — Godot built-in icons |
| 2 | `custom_icon` | `FuseIconManager.get_custom_icon()` — the Fuse custom icon library |
| 3 | `icon_name` | first checks the custom library via `has_custom_icon()` and takes the custom icon on a hit; otherwise takes the built-in via `get_builtin_icon()` (backward compatibility) |
| 4 | `icon` | direct `Texture2D` resource reference |

> Note the second-level "custom first, then builtin" fallback at priority 3 — it exists for compatibility with the legacy `icon_name` field; new code should prefer `builtin_icon`/`custom_icon`.

## 6. Codegen Static Analysis Hooks

Used by `InstructionAnalyzer` (codegen) to statically extract an instruction's variable/node/signal references; default empty implementations are automatically overridden in subclasses by the codegen script (base_instruction.gd:316–344). Components that did not go through codegen are handled by the analyzer's silent degradation.

```gdscript
# :329 — variable references read/written by this instruction
static func _get_variable_accesses() -> Array:
    # each item: { "prop": String, "scope_prop": String, "mode": "read"|"write"|"read_write", "condition_prop": String }
    return []

# :335 — scene node property names referenced by this instruction (only supplements non-NodePath-typed ones, e.g. *_node stored as String)
static func _get_nodepath_props() -> Array:
    # Array[String]; NodePath-typed properties are covered automatically by reflection, no declaration needed
    return []

# :343 — custom signal information involved in this instruction
static func _get_signal_info() -> Dictionary:
    # { "declared": Array[String], "emitted": Array[String] }
    return {"declared": [], "emitted": []}
```

**Purpose**: the editor's dependency analysis, variable scope validation, node reference checks, signal wiring hints, etc. — statically inferring an instruction's side effects without running it.

## 7. Cooperation with RuntimeInstructionInstance

To support the "one instruction resource × many runtime instances" model (loops, parallelism, debug breakpoints, etc.), `BaseInstruction` provides four hooks (base_instruction.gd:1236–1294) that decouple runtime state from the Resource into `RuntimeInstructionInstance` (`RefCounted`, runtime_instruction_instance.gd):

| Method | Line | Default behavior |
|------|------|----------|
| `get_default_runtime_state() -> Dictionary` | 1247 | returns `{initialized, execution_status, timer, elapsed_time, is_running}` |
| `execute_with_runtime_instance(ri) -> bool` | 1266 | calls `execute_sync(ri.execution_context)` and syncs `execution_status`/errors back into `ri.runtime_state` |
| `on_runtime_pause(ri) -> void` | 1284 | empty; subclasses may override (e.g. pause a Tween) |
| `on_runtime_resume(ri) -> void` | 1293 | empty |

**Key RuntimeInstructionInstance fields** (runtime_instruction_instance.gd): `runtime_state: Dictionary` (:31), `execution_context: ExecutionContext` (:32), `_has_error: bool` (:43), `_error_message: String` (:44); the constructor `_init(inst, context, runner)` (:55) copies the initial state from the instruction's `get_default_runtime_state()` via `_initialize_runtime_state()` (:72).

**Use cases**: an independent instance per iteration in ForEachInstruction, freeze/resume for debug breakpoints, reusing one instruction resource across contexts.

---

## 8. Implemented Feature Modules (v2.0+)

The following sections describe the v2.0 capabilities module by module: execution mode, completion timing, state machine, runtime instance cooperation, smart sync detection, timeout management, unified error handling, logging, manual sync hint. These features are part of the official API and are no longer improvement suggestions.

### 2.0.1 ExecutionMode Enum

**Description:** Defines an instruction's execution mode for smart execution path optimization. Together with the `can_execute_sync()` method it lets callers such as the ActionRunner pick the optimal execution path (sync/async) based on instruction characteristics, improving overall execution efficiency.

**Enum definition:**

```gdscript
enum ExecutionMode {
    AUTO_DETECT,    ## Auto-detect the execution mode (recommended)
    FORCE_ASYNC,    ## Force asynchronous execution
    FORCE_SYNC      ## Force synchronous execution
}
```

**Related members:**

| Member | Type | Description |
|------|------|------|
| `execution_mode` | `@export var ExecutionMode` | exported property, defaults to `AUTO_DETECT`, configurable in the editor Inspector |
| `can_execute_sync() -> bool` | method | decides sync executability from the current `execution_mode` |

**Use cases:**

- **AUTO_DETECT** (default): the system automatically analyzes traits such as the `await` keyword in the instruction source and `_is_synchronous()` overrides to determine the execution mode. Fits most custom instructions, no manual configuration needed.
- **FORCE_ASYNC**: explicitly requires the async path; fits instructions containing async mechanisms such as Timers, e.g. `WaitInstruction`, `TweenInstruction`.
- **FORCE_SYNC**: forces the synchronous fast path, skipping the await mechanism; fits performance-sensitive pure-computation instructions such as `MathExpression`, `VariableSetInstruction`.

### 2.0.2 CompletionSignalTiming Enum

**Description:** Defines when the instruction completion signal (`finished`) is emitted, covering the case where some instructions must notify the caller as soon as execution starts.

**Enum definition:**

```gdscript
enum CompletionSignalTiming {
    ON_START,   ## Emit the completion signal when execution starts
    ON_FINISH   ## Emit the completion signal when execution finishes (default)
}
```

**Related members:**

| Member | Type | Description |
|------|------|------|
| `completion_timing` | `@export var CompletionSignalTiming` | exported property, defaults to `ON_FINISH` |
| `_start_execution()` | method | in `ON_START` mode calls `_on_execution_completed()` immediately |
| `_on_execution_completed()` | method | emits the signal in `ON_FINISH` mode; skips the duplicate emission in `ON_START` mode |

**Use cases:**

- **ON_FINISH** (default): `finished` is emitted only after the instruction finishes executing. Fits instructions whose results callers must wait for, such as `MoveNodeInstruction`, `PlayAnimationInstruction`.
- **ON_START**: the completion signal is emitted immediately in `_start_execution()`; fits "fire-and-done" instructions. For example `FireEventInstruction`, whose execution logic is mainly notifying other systems and does not need to wait for its own completion.

### 2.0.3 ExecutionStatus Enum

**Description:** Defines the full state machine of an instruction's execution lifecycle, supporting status queries and transition validation.

**Enum definition:**

```gdscript
enum ExecutionStatus {
    PENDING,    ## Waiting to execute
    RUNNING,    ## Currently executing
    COMPLETED,  ## Execution completed
    CANCELLED,  ## Cancelled
    ERROR       ## Execution error
}
```

**Related members:**

| Method signature | Return value | Description |
|----------|--------|------|
| `get_execution_status() -> ExecutionStatus` | the enum value | gets the current status |
| `is_running() -> bool` | `bool` | equivalent to `status == RUNNING` |
| `is_completed() -> bool` | `bool` | equivalent to `status == COMPLETED` |
| `has_error() -> bool` | `bool` | equivalent to `status == ERROR` |
| `reset()` | `void` | resets the status to `PENDING`, also clearing `_fuse_error`, disconnecting signals, cleaning up the timeout timer, and resetting the sync capability cache |

**Status transition flow:**

```
PENDING → RUNNING → COMPLETED
                  → CANCELLED
                  → ERROR
```

**Use cases:**

- The `ActionRunner` checks for the `PENDING` status before dispatching an instruction, preventing double execution.
- The debug panel outputs `ExecutionStatus.keys()[status]` via `get_debug_info()` to show a readable status name.
- The `reset()` method is called when an instruction needs to be reused (e.g. resetting sub-instructions in loop instructions), ensuring a clean initial state.

### 2.0.4 RuntimeInstructionInstance Support

> For the cooperation architecture and method table see §7 of this document; this section adds method signature details.

**Description:** Introduces the runtime instance architecture, decoupling an instruction's runtime state (timer, elapsed time, running flag, etc.) from the instruction resource itself into standalone `RuntimeInstructionInstance` objects. This lets the same instruction resource be shared by multiple runtime instances while each maintains independent execution state.

**Method signatures:**

```gdscript
## Returns the default runtime state dictionary (subclasses may override to declare custom state)
func get_default_runtime_state() -> Dictionary:
    return {
        "initialized": true,
        "execution_status": ExecutionStatus.PENDING,
        "timer": null,
        "elapsed_time": 0.0,
        "is_running": false
    }

## Executes the instruction with a runtime instance (subclasses may override)
## Returns bool indicating whether it completed synchronously
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool

## Pause callback, invoked when the runtime instance is paused
func on_runtime_pause(runtime_instance: RuntimeInstructionInstance) -> void

## Resume callback, invoked when the runtime instance is resumed
func on_runtime_resume(runtime_instance: RuntimeInstructionInstance) -> void
```

**Default implementation behavior:**

- `get_default_runtime_state()`: returns the default dictionary containing the five fields `initialized`, `execution_status`, `timer`, `elapsed_time`, `is_running`.
- `execute_with_runtime_instance()`: internally calls `execute_sync()` and syncs the execution status and error message back into `runtime_instance.runtime_state`.
- `on_runtime_pause()` / `on_runtime_resume()`: empty; subclasses may override to implement pause/resume logic (e.g. pausing Tween animations).

**Use cases:**

- **Loop instructions (ForEachInstruction)**: each loop iteration creates an independent `RuntimeInstructionInstance`, keeping sub-instruction states from interfering across loop rounds.
- **Debug breakpoint system**: `on_runtime_pause()` freezes the current execution state on pause; `on_runtime_resume()` continues on resume.
- **Instruction reuse**: the same `BaseInstruction` resource can be executed multiple times in different contexts, each execution using its own runtime instance.

### 2.0.5 Smart Execution Mode Detection

**Description:** In `AUTO_DETECT` mode the system applies a multi-level detection strategy to decide whether an instruction is fit for synchronous execution, letting the ActionRunner choose the optimal execution path automatically without developer annotation.

**Detection priority chain:**

```
1. Subclass overrides _is_synchronous() → use its return value
2. Manual set_synchronous_hint() → use the hint value
3. Source analysis via _contains_await_in_code() → detect the await keyword
4. Default to synchronous
```

**Method signatures:**

```gdscript
## Public interface: decides sync executability from execution_mode
func can_execute_sync() -> bool

## Auto-detects sync capability (internal)
func _detect_sync_capability() -> bool

## Checks for async operations (core detection logic, cached)
func _has_async_operations() -> bool

## Source-level detection of the await keyword (comments excluded)
func _contains_await_in_code(source: String) -> bool

## Synchronous execution wrapper; returns bool indicating whether it completed synchronously
func execute_sync(context: ExecutionContext) -> bool
```

**Cache mechanism:**

- `_sync_capability_cached: bool`: the cached detection result.
- `_sync_capability_detected: bool`: marks whether detection has already run, avoiding repeated source analysis.
- The `reset()` method clears the cache, ensuring detection reruns before each execution.

**Use cases:**

- **ActionRunner optimization**: the `execute_sync()` wrapper first calls `can_execute_sync()`; when synchronous execution is possible it returns the result directly, avoiding unnecessary `await` overhead.
- **Validation-time warning**: the `validate_async_in_sync_mode()` static method checks whether a sync-mode instruction contains async sub-instructions and produces a warning message.
- **Custom instructions**: for async instructions using callbacks instead of `await`, developers can call `set_synchronous_hint(false)` to declare the async nature explicitly.

### 2.0.6 Timeout Management System

**Description:** Provides timeout protection for instruction execution, preventing an instruction from blocking indefinitely due to logic errors or unresponsive external dependencies. Implemented with Godot's `SceneTreeTimer`, so no Timer node needs manual management.

**Method signatures:**

```gdscript
## Sets the timeout in seconds; 0 disables the timeout
func set_timeout(timeout_seconds: float)

## Gets the current timeout
func get_timeout() -> float

## Checks whether a timeout is enabled
func has_timeout() -> bool

## Gets the elapsed execution time in seconds; returns a valid value only while RUNNING
func get_execution_time() -> float

## Creates a SceneTreeTimer and connects the timeout callback (internal method)
func _setup_timeout_timer()

## Disconnects and cleans up the timeout timer (internal method)
func _cleanup_timeout_timer()

## Handling logic when the timeout fires (internal method)
func _on_timeout()
```

**Execution flow:**

```
_start_execution()
    ├── record _execution_start_time
    ├── _setup_timeout_timer()
    │     ├── check has_timeout()
    │     ├── _cleanup_timeout_timer() (clean up the old timer)
    │     └── scene_tree.create_timer(_timeout_duration)
    │           └── timeout.connect(_on_timeout)
    └── run the instruction logic

_on_timeout()
    ├── check execution_status == RUNNING
    ├── compute the elapsed time
    ├── set_error(..., TIMEOUT_ERROR, context)
    ├── _cleanup_timeout_timer()
    └── finished.emit()

_on_execution_completed() / _on_execution_error() / cancel()
    └── _cleanup_timeout_timer()
```

**Related fields:**

| Field | Type | Description |
|------|------|------|
| `_timeout_timer` | `SceneTreeTimer` | reference to the Godot scene tree timer |
| `_timeout_duration` | `float` | timeout in seconds; 0 means no timeout |
| `_execution_start_time` | `float` | execution start timestamp (seconds) |

**Use cases:**

- **Network request instructions**: a sensible timeout prevents network stalls.
- **Player interaction waits**: after the timeout the waiting state is skipped automatically.
- **Debugging**: temporarily set a short timeout on a suspicious instruction to locate infinite loops quickly.

### 2.0.7 Unified Error Handling

**Description:** Structured error handling via the `_fuse_error` field and the `FuseError` class, replacing plain string error messages; supports error type classification, context information collection, and logging system integration.

**Method signatures:**

```gdscript
## Sets an error (supports automatic translation of translation keys)
func set_error(
    message: String,
    error_type: FuseError.ErrorType = FuseError.ErrorType.EXECUTION_ERROR,
    context: Dictionary = {}
)

## Creates a localized error (translation key + args)
func set_error_localized(
    message_key: String,
    error_type: FuseError.ErrorType = FuseError.ErrorType.EXECUTION_ERROR,
    args: Dictionary = {},
    context: Dictionary = {}
)

## Internal error handling method (sets the error + emits the finished signal)
func _on_execution_error(
    error: String,
    error_type: FuseError.ErrorType = FuseError.ErrorType.EXECUTION_ERROR,
    context: Dictionary = {}
)
```

**FuseError.ErrorType enum values:**

| Value | Description |
|------|------|
| `VALIDATION_ERROR` | validation error |
| `EXECUTION_ERROR` | execution error (default) |
| `CONFIGURATION_ERROR` | configuration error |
| `RUNTIME_ERROR` | runtime error |
| `TIMEOUT_ERROR` | timeout error |

**`_fuse_error` field behavior:**

- Typed `FuseError`, created via the `FuseError.create_with_context()` factory method.
- Automatically attaches `instruction_name` and `instruction_description` to the error context.
- The `get_debug_info()` method appends detailed `fuse_error` information when `_fuse_error` is present.
- The `reset()` method sets `_fuse_error` back to `null`.

**Difference between `set_error()` and `set_error_localized()`:**

- `set_error(message)`: uses the given message string directly. If `message` starts with `FUSE_ERROR_`, the translation system is invoked automatically to localize it.
- `set_error_localized(message_key, args)`: always localizes through a translation key + args dictionary; fits scenarios that need parameterized error messages.

**Use cases:**

- `set_error("找不到目标节点: %s" % target_path)`: a simple formatted error message.
- `set_error_localized("FUSE_ERROR_NODE_NOT_FOUND", {"node": target_path})`: a parameterized error that supports multiple languages.
- `_on_execution_error(error_msg, FuseError.ErrorType.TIMEOUT_ERROR, {"timeout": 5.0})`: used in the timeout callback to mark the error type explicitly.

### 2.0.8 Logging System

**Description:** Integrates the unified `FuseLogger` logging system with leveled log output (DEBUG/INFO/WARNING/ERROR/NONE); every logging method carries the source tag (`"BaseInstruction"`) and the instruction name as context.

**Exported property:**

```gdscript
@export var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.INFO
```

**FuseLogger.LogLevel enum values:**

| Value | Level | Description |
|------|------|------|
| `NONE` | -- | no log output at all |
| `INFO` | normal | outputs info-level only (default) |
| `WARNING` | warning | outputs info + warning |
| `ERROR` | error | outputs info + warning + error |
| `DEBUG` | debug | outputs all levels (debug + info + warning + error) |

**Logging methods (8 in total):**

| Method | Description |
|------|------|
| `_log_debug(message)` | debug-level log |
| `_log_info(message)` | info-level log |
| `_log_warning(message)` | warning-level log |
| `_log_error(message)` | error-level log |
| `_log_debug_localized(message_key, args)` | localized debug log |
| `_log_info_localized(message_key, args)` | localized info log |
| `_log_warning_localized(message_key, args)` | localized warning log |
| `_log_error_localized(message_key, args)` | localized error log |

All logging methods delegate to the matching `FuseLogger` method with three fixed arguments: `source = "BaseInstruction"`, `level = self.log_level`, `context = get_name()`.

**Use cases:**

- Adjust the log level of a specific instruction via the `log_level` property in the editor Inspector, e.g. setting one instruction to `DEBUG` while debugging.
- The localized logging methods (`_log_*_localized`) emit translatable log messages, keeping log information consistent across locales.
- `FuseLogger` filters output by `log_level` internally, avoiding excessive debug logs in production.

### 2.0.9 Manual Sync Hint

**Description:** Provides a programmatic interface for subclasses or factory methods to explicitly declare an instruction's sync/async nature at runtime, complementing smart detection. Mainly for async instructions that use callbacks instead of the `await` keyword — their async traits cannot be detected by source analysis.

**Fields:**

| Field | Type | Description |
|------|------|------|
| `_is_synchronous_hint` | `bool` | sync capability hint value, defaults to `false` |
| `_sync_hint_manually_set` | `bool` | marks whether the hint was set manually via `set_synchronous_hint()` |

**Method signature:**

```gdscript
## Sets the sync hint (for subclasses or factories)
func set_synchronous_hint(is_sync: bool)
```

**Method behavior:**

1. Sets `_is_synchronous_hint` to the given `is_sync` value.
2. Marks `_sync_hint_manually_set = true`, recording that the value was set manually.
3. Resets `_sync_capability_detected = false`, clearing the cache so the next `_has_async_operations()` call re-detects.

**Relationship with `_is_synchronous()`:**

```gdscript
func _is_synchronous() -> bool:
    return _is_synchronous_hint
```

The default `_is_synchronous()` implementation returns `_is_synchronous_hint` directly. Subclasses may override this method to provide custom sync logic, in which case the `set_synchronous_hint()` value no longer takes effect.

**Use cases:**

- **Callback-based async instructions**: the instruction starts an async operation in `execute()` and completes via a callback (no `await`), so `_contains_await_in_code()` cannot detect the async trait. Developers should call `set_synchronous_hint(false)` to declare it.
- **Instruction factories**: when creating instruction instances dynamically, a factory method can set the sync hint from configuration parameters without touching the instruction source.
- **Dynamic configuration**: change an instruction's sync behavior at runtime based on conditions (e.g. switching a network request instruction's execution mode when toggling online/offline mode).
---

## 9. Related Documents

- [action_runner_analysis.md](action_runner_analysis.md) — how the ActionRunner dispatches BaseInstruction (including the `execute_sync()` / `execute_with_runtime_instance()` call paths)
- [execution_context_analysis.md](execution_context_analysis.md) — the `ExecutionContext` facade + `VariableContext` + `ExecutionDiagnostics`
- `addons/fuse/core/runtime_instruction_instance.gd` — RuntimeInstructionInstance implementation
- `addons/fuse/core/base/base_instruction.gd` — source of this class
