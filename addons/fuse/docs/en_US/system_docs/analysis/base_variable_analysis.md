> 🌐 [**中文版**](../../../zh_CN/system_docs/analysis/base_variable_analysis.md) | English

# BaseVariable Analysis Report


> **Analyzed as of**: 2026-07-07 (each article verified against code during the same-day full documentation audit; implementation evolution after this point defers to the source code; for recently verified mechanical conclusions see the threading / runtime_instance / preset_nested articles)
## Document Overview

This report is a descriptive as-is analysis of the `BaseVariable` core script in the Fuse visual programming system. `BaseVariable` is the base class of the variable system (`class_name BaseVariable extends Resource`); it carries values directly in a native Godot `Variant` and defines three-layer scopes, unified error handling, lifecycle hooks, and a set of static factory methods. It does not itself handle storage/lookup — variables are managed per scope by `VariableContext` (LOCAL), `ScopeVariableContainer` (SCOPE), and the `GlobalVariableManager`/`Assistant`/`Resource`/`Service` quartet (GLOBAL).

**Source file:** [base_variable.gd](../../../../core/base/base_variable.gd)
**Line count:** 1073 lines
**Base class:** Resource (`@tool` + `@icon`)
**Scope enum:** `VariableScope.LOCAL = 0` / `SCOPE = 1` / `GLOBAL = 2`

> Historical note: this article replaces an older draft (its first 6 sections were based on non-existent APIs such as `_validate_value` / `get_modification_history`, and it mistakenly called GlobalVariableManager a "singleton Node"). The old draft is archived at `addons/fuse/docs/archive/analysis/base_variable_analysis.md`.

---

## 1. Class Overview and Responsibilities

`BaseVariable` is a `Resource` subclass; one instance describes "one named variable" — its name, value, scope, persistence preference, and statistics counters. It can be serialized into `.tres`, but holds no node references and is not directly coupled to the scene tree.

### Core responsibilities

1. **Carrying a value**: stores any Godot value directly in a `Variant value` field, with no type constraints and no runtime validation
2. **Scope declaration**: declares which layer the variable belongs to via `scope: int` (a `VariableScope` enum value)
3. **Modification tracking**: maintains counters such as `modification_count`, `last_modified_time`, `access_count`, `creation_time`
4. **Change notification**: broadcasts changes via the three signals `value_changed` / `value_modified` / `variable_reset`
5. **Error carrying**: a built-in `_fuse_error: FuseError` field plus the `_create_fuse_error()` constructor serve as a unified error container
6. **Factory support**: static factories such as `create()` / `create_local()` / `create_global()` / `create_player_health()` / `create_batch()` / `from_config()` / `clone_variable()`
7. **Persistence compatibility**: keeps the legacy ConfigFile persistence methods (`_save_to_storage` / `_load_from_storage` / `_clear_storage`, all `@deprecated`)

### Design traits

- Uses the `@tool` annotation to run in editor mode (`_update_resource_name()` shows the composed resource name in the Inspector)
- Holds no node references, only `RefCounted`/`Resource` companions (e.g. `FuseError`)
- No forced subclassing — in most cases `BaseVariable.new()` directly is enough; no derivation needed
- The type system is left entirely to the Godot Variant: `get_type_name()` / `get_godot_type()` reflect `typeof(value)`; there is no separate type-validation layer

---

## 2. Core Properties

### 2.1 @export properties

| Property | Type | Default | Description |
|------|------|--------|------|
| `variable_name` | String | `""` | Variable name; the setter only logs and does not trigger a resource-name rebuild |
| `value` | Variant | `null` | Variable value; the setter is solely responsible for emitting `value_changed` + `value_modified` and updating counters (see §5) |
| `description` | String | `""` | Human-readable description |
| `log_level` | FuseLogger.LogLevel | `INFO` | Log level |
| `scope` | int | `VariableScope.LOCAL` | Scope; the setter triggers `_update_resource_name()` |
| `persistent` | bool | `false` | Whether it participates in persistence (defaults to true for GLOBAL scope) |
| `auto_create` | bool | `false` | Whether to auto-create when missing (defaults to true for LOCAL/SCOPE) |
| `access_count` | int | `0` | Cumulative read count via `get_value()` (`@export`) |

### 2.2 Instance variables (non-@export)

| Variable | Type | Default | Description |
|------|------|--------|------|
| `creation_time` | float | set in `_init()` to `Time.get_ticks_msec()/1000.0` | Creation timestamp |
| `last_modified_time` | float | 0.0 | Most recent modification timestamp (only the value setter updates it) |
| `modification_count` | int | 0 | Modification count (only the value setter increments it) |
| `is_initialized` | bool | `false` | Whether lazy initialization has completed via `get_value()` or a factory |
| `_fuse_error` | FuseError | `null` | Unified error object |

### 2.3 Constants and deprecated constants

| Constant | Value | Description |
|------|----|------|
| `DEFAULT_VALUE` | `null` | Default value placeholder |
| `STORAGE_SECTION` | `"variables"` | @deprecated, legacy ConfigFile section |
| `STORAGE_CONFIG_PATH` | `"user://fuse_variables.cfg"` | @deprecated, legacy ConfigFile path |

### 2.4 Enum

```gdscript
enum VariableScope {
    LOCAL = 0,      ## local variables (ExecutionContext.local_variables)
    SCOPE = 1,      ## scope variables (ScopeVariableContainer)
    GLOBAL = 2      ## global variables (GlobalVariableAssistant/Manager)
}
```

The three values are LOCAL/SCOPE/GLOBAL. Note: the deprecated `VariableContainer` class internally carries a **different** two-value `VariableScope = LOCAL/GLOBAL` enum (see §7.1); do not confuse them.

---

## 3. Key Methods

### 3.1 Value read/write

#### `get_value() -> Variant`
Reads the current value and increments `access_count`; the first access triggers `_initialize_value()` (setting `is_initialized` to true). **No type conversion or validation.**

#### `set_value(new_value: Variant) -> bool`
**No type validation at all; assigns directly.** Full flow:
1. Save `old_value`
2. `value = new_value` (triggers the value setter, which emits `value_changed` + `value_modified` and updates counters/time — see §5.2)
3. `emit value_modified(new_value)` (duplicating the setter's emit once; kept to stabilize the historical call contract)
4. Returns `true` (no failure path — see §7 known issue 4)

> Design trade-off: all value types pass through the Variant, with no `_validate_value()` / type guards / range checks. Callers that need type constraints (e.g. the instruction layer) should validate externally.
> History: signal double-emission and duplicated counting between the setter/set_value used to exist (CODE_ISSUES B1/B2/B3); emission + counting are now unified in the setter (commit `e3c470d`). set_value still keeps the explicit `value_modified.emit` for compatibility with the historical call contract.

### 3.2 State queries

| Method | Returns | Description |
|------|------|------|
| `has_value()` | bool | `is_initialized and value != null` |
| `is_empty()` | bool | `not has_value()` |
| `get_type_name()` | String | Reflects `typeof(value)` into a string (covers NIL/BOOL/INT/FLOAT/STRING/VECTOR2/VECTOR3/COLOR/ARRAY/DICTIONARY/OBJECT/NODE_PATH and the various PackedArrays; returns `"Unknown"` for uncovered types) |
| `get_godot_type()` | int | Directly returns `typeof(value)` |
| `get_info()` | Dictionary | Aggregates name/type/value/persistent/modification_count/last_modified_time/is_initialized; attaches a `fuse_error` key when `_fuse_error` is non-null |
| `get_debug_info()` | String | Single-line debug string; appends error info when a FuseError is present |
| `get_creation_info()` | Dictionary | name/type/scope (name looked up via `VariableScope.keys()[scope]`)/creation_time/access_count/persistent/auto_create/modification_count/last_modified_time |
| `equals(v)` / `not_equals(v)` / `greater_than(v)` / `less_than(v)` / `greater_equal(v)` / `less_equal(v)` | bool | Value comparisons; the `*_than` family converts via `to_number()` first, logging a warning and returning false when conversion fails |

### 3.3 Type conversion helpers

| Method | Behavior |
|------|------|
| `to_string()` | `str(value)` |
| `to_number()` | int/float returned directly; strings try `float()` (falling back to 0 on NaN); others 0.0 |
| `to_bool()` | bool returned directly; int/float compare non-zero; strings judged non-empty; others false |
| `to_array()` | Returns the Array as-is if it already is one; otherwise wraps into `[value]` |
| `to_dict()` | Returns the Dictionary as-is if it already is one; otherwise `{}` |
| `_convert_to_number(val)` | Static helper, similar to `to_number()` but accepts an external value |

### 3.4 Reset and lifecycle

#### `reset()`
Sets `value` to `null`, zeroes the counters, sets `is_initialized = true` and `_fuse_error = null`, and emits `variable_reset()`. **Note**: reset clears the value outright, which differs from the lazy initialization in `_initialize_value()`.

#### `_init()`
Sets `last_modified_time = 0`, `modification_count = 0`, `is_initialized = false`, `_fuse_error = null`, `creation_time = now`. The comments explicitly say **not** to call `reset()` here (because `value` may not have been set yet).

#### `_notification(what)`
Only handles `NOTIFICATION_PREDELETE`: nulls `_fuse_error` to avoid dangling references. No other cleanup (no nodes, no signals to disconnect — signals are connected by the Manager on `add_variable` and disconnected on `remove_variable`).

### 3.5 FuseError integration

#### `_create_fuse_error(message, error_type = RUNTIME_ERROR, context = {})`
Constructs a FuseError instance and stores it in `_fuse_error`. Automatically injects `variable_name` and `variable_type` (from `get_type_name()`) into `context`. The error source component name is fixed to `"BaseVariable"`.

#### `get_fuse_error() -> FuseError` / `has_fuse_error() -> bool`
Query interface for external consumers (e.g. instructions, events).

> BaseVariable does not create errors on its own — `_fuse_error` is normally written by external code that detects an anomaly, via `_create_fuse_error()`. The error state is cleared on `reset()` and on PREDELETE.

### 3.6 Logging

Four unified logging methods `_log_debug` / `_log_info` / `_log_warning` / `_log_error`, all delegating to `FuseLogger` with the class name `"BaseVariable"`, the `log_level`, the message, and `variable_name` as the context identifier.

### 3.7 Serialization (lightweight)

#### `serialize() -> Dictionary` / `deserialize(data)`
Lightweight dictionary serialization containing only name/value/persistent/modification_count/last_modified_time. `deserialize` also sets `is_initialized` to true. **Note**: this is not the `.tres` persistence path — real resource persistence goes through `GlobalVariableResource` (see §6.4).

#### `clone() -> BaseVariable` (instance method)
Deep-copies all properties into a new `BaseVariable.new()` instance, **including** `scope` / `auto_create` / `creation_time` (consistent with the static `clone_variable()` behavior).

> History: the instance `clone()` used to miss the three fields `scope` / `auto_create` / `creation_time` (CODE_ISSUES B9); fixed (commit `e3c470d`).

### 3.8 Validation

#### `validate_configuration() -> Array[String]`
Returns an array of configuration error strings (**not** FuseError objects, purely localized strings). Current rules:
- `variable_name` empty → append `FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY")`
- `scope == GLOBAL and not persistent` → **no longer treated as an error**; only a `_log_warning` notes that it "will be cleaned up automatically on scene exit" (the mandatory rule described in the old draft — "global variables must enable persistence" — has been relaxed to a suggestion)

An empty array means it passes.

---

## 4. Static Factory Methods

`BaseVariable` provides rich static factories, all located in the "built-in factory pattern" section at the end of the file.

| Method | Purpose | Notes |
|------|------|------|
| `create(name, val, scope = LOCAL)` | Core creation entry | push_error on empty name and returns null; calls `_configure_by_scope` to set default persistent/auto_create; sets `is_initialized = true` |
| `create_local(name, val)` | Convenient LOCAL creation | forwards to `create` |
| `create_global(name, val, persist = true)` | Convenient GLOBAL creation | forwards to `create` then forces `persistent = persist` |
| `create_player_health(health = 100.0)` | Common in games | GLOBAL + persistent, name `"player_health"` |
| `create_player_score(score = 0)` | Common in games | GLOBAL + persistent, name `"player_score"` |
| `create_player_level(level = 1)` | Common in games | GLOBAL + persistent, name `"player_level"` |
| `create_temp_timer(name = "temp_timer", duration = 0.0)` | Temporary timer | LOCAL, non-persistent |
| `create_batch(variables_data: Array)` | Batch creation | elements are `{name, value, scope}` dictionaries; empty names / malformed entries are skipped with push_warning |
| `from_config(config: Dictionary)` | Create from a config dictionary | parses the `scope` string (local/scope/global; `"trigger"` treated as a deprecated alias → LOCAL); additionally supports persistent/auto_create/log_level fields |
| `clone_variable(original, new_name = "")` | Static clone | unlike the instance `clone()` — this version **does** copy scope/auto_create/creation_time |

#### `_configure_by_scope(scope)` private defaults

| Scope | auto_create | persistent |
|--------|-------------|------------|
| LOCAL  | true  | false |
| SCOPE  | true  | false |
| GLOBAL | false | true  |

---

## 5. Signal Mechanism

### 5.1 The three signals

```gdscript
signal value_changed(old_value: Variant, new_value: Variant)
signal value_modified(value: Variant)
signal variable_reset()
```

### 5.2 Emit responsibilities of the value setter vs set_value

The setter of the `value` field is the **sole owner** of signal emission and counter updates:

```gdscript
@export var value: Variant = null:
    set(new_value):
        var old_value = value
        value = new_value
        last_modified_time = Time.get_ticks_msec() / 1000.0
        modification_count += 1
        _log_debug("Variable value changed from %s to %s" % [str(old_value), str(new_value)])
        value_changed.emit(old_value, new_value)
        value_modified.emit(new_value)
```

`set_value()` no longer explicitly emits `value_changed` (avoiding double emission), but still keeps one `value_modified.emit` to stabilize the historical call contract (some listeners rely on the set_value path to trigger explicitly).

> History: three problems used to exist — the setter not emitting `value_modified`, set_value double-emitting `value_changed`, and duplicated counter updates (CODE_ISSUES B1/B2/B3); all were fixed in one pass (commit `e3c470d`, test `test_base_variable_signals.tscn`).

### 5.3 `variable_reset`
Emitted only by `reset()`, with no payload.

---

## 6. Architectural Relationships: BaseVariable and the Variable System's Seven Classes

`BaseVariable` is the variable system's "data record", but it does not itself answer "where does a variable live and how is it found". Those responsibilities are spread across the collaborating classes below. Understanding BaseVariable requires understanding its collaboration diagram.

### 6.1 Collaboration overview

```
                   ┌───────────────────────────────────────┐
                   │ BaseVariable (Resource, data carrier) │
                   │ - value: Variant                      │
                   │ - scope: int (LOCAL/SCOPE/GLOBAL)     │
                   │ - persistent / auto_create / stats    │
                   └───────────────────┬───────────────────┘
                                       │ stored per scope across the three layers below
                       ┌───────────────┼───────────────┐
                       ▼               ▼               ▼
                 [LOCAL]           [SCOPE]          [GLOBAL]
             VariableContext   ScopeVariable-    GlobalVariable-
             (RefCounted,      Container         quartet
              EC subsystem)    (Node)            (see §6.4)
             local_variables   _variables        Manager._variables
               = Variant       = Variant           = BaseVariable
             (bare, not BVs)   (bare, not BVs)   (BV instances)
```

> Key fact: the LOCAL and SCOPE layers store **only bare Variant values** in their containers, not BaseVariable instances; only the GLOBAL layer (`GlobalVariableManager._variables`) uses BaseVariable instances as values. Objects created by BaseVariable factories are mainly used for: GLOBAL registration, serialization/cloning, and UI display.

### 6.2 VariableContext (core of the LOCAL layer)

**Source file:** `addons/fuse/core/base/variable_context.gd` (463 lines, `extends RefCounted`)

The variable subsystem of ExecutionContext, carrying:
- LOCAL variable CRUD (`set_variable` / `get_variable` / `has_variable` / `add_variable`, dispatched by string scope)
- LRU variable-name cache (`_variable_name_cache` + `_cache_access_order`, capped at 1000, evicting 1/5 when exceeded)
- Indexed access optimization (`precompile_variable_access` / `set_variable_by_index` / `get_variable_by_index`)
- Three-layer scope dispatch (`_set_local_variable` / `_set_scope_variable` / `_set_global_variable`)
- Scope container lookup (`_find_scope_container`: trigger → target → owner order, calling `ScopeVariableManager.find_nearest_scope`)
- Variable snapshots (for breakpoint debugging: `get_all_local_variables_snapshot` / `get_all_scope_variables_snapshot` / `get_all_global_variables_snapshot`)
- Loop control flags (`_break_loop_flag` / `_continue_loop_flag` + the nested stack `_loop_flag_stack`)

`add_variable(variable: BaseVariable)` is the direct interface between BaseVariable and VariableContext: it reads `variable.scope` from the BaseVariable; if GLOBAL it forwards to `_set_global_variable`, otherwise it treats it as LOCAL — writing the bare `variable.value` into the `local_variables` dictionary.

> Relationship between EC and VariableContext: EC is the **facade** of VariableContext. `execution_context.gd` holds `_variable_context: VariableContext` and keeps its own `local_variables` as a "compatibility reference" pointing at `_variable_context.local_variables` (the same dictionary object). All variable methods on EC delegate to VariableContext.

### 6.3 ScopeVariableContainer (SCOPE layer)

**Source file:** `addons/fuse/core/base/scope_variable_container.gd` (183 lines, `extends Node`)

A Node component attached to scene nodes, providing scoped storage for that node's subtree:
- `@export var variables: Dictionary[String, Variant]` (**bare Variant values**, not BaseVariable)
- `scope_id: String` identifier; registers to `ScopeVariableManager` via `call_deferred("_register_scope")` in `_enter_tree`
- Three `InheritanceMode`s: NONE / READ_ONLY (default) / READ_WRITE
- `get_scope_chain()` returns the container chain from root to current
- Three signals: `scope_variable_changed(name, old, new)` / `scope_variable_added(name)` / `scope_variable_removed(name)`
- No direct coupling with BaseVariable — it stores bare Variants; scope lookups are triggered by VariableContext/VariableOperations

`ScopeVariableManager` (`addons/fuse/core/scope_variable_manager.gd`, `extends Node`, autoload) provides the bottom-up `find_nearest_scope(node)` lookup.

### 6.4 The GlobalVariable quartet (GLOBAL layer)

The GLOBAL layer is where BaseVariable is truly stored as an "object". Division of labor across the four classes:

| Class | Type | File | Responsibilities |
|----|------|------|------|
| **GlobalVariableManager** | `extends RefCounted` | `core/global_variable_manager.gd` (437 lines) | The source of truth. Static `_instance` singleton + `get_instance()`. Variable CRUD (`add_variable` / `get_variable` / `has_variable` / `remove_variable`) with all operations guarded by a `Mutex`. `_variables: Dictionary` stores BaseVariable instances directly. Provides thread-safe iterators (`get_all_variables_snapshot` / `get_variables_safe` / `get_variables_batch_thread_safe`) and persistence (`save_to_resource` / `save_persistent_to_resource` / `load_from_resource`, all serialized via `GlobalVariableResource`). Three signals: `variable_added` / `variable_removed` / `variable_changed`. |
| **GlobalVariableResource** | `extends Resource` | `core/global_variable_resource.gd` | Serialization data structure. `@export var variables: Dictionary` stores normalized dictionaries `{value, scope, persistent, description}`. `add_variable` / `set_variable` / `get_variable` / `get_variable_names` / `validate` / `cleanup_invalid_variables`. Carries version, author, and tag metadata. |
| **GlobalVariableService** | `extends RefCounted` | `core/global_variable_service.gd` | A pure RefCounted middle layer. `_init` sets `_manager = GlobalVariableManager.get_instance()`; all methods mirror Assistant naming (`add_global_variable` / `get_global_variable` etc.) and forward to the Manager. **Purpose**: serves as the Assistant's `_service` fallback when there is no scene node (e.g. Editor, unit tests, pure-logic environments). |
| **GlobalVariableAssistant** | `extends Node` | `core/global_variable_assistant.gd` | The scene-node layer. A `@tool` Node placed in the scene tree providing Inspector configuration (`resource_path` / `auto_load_on_ready` / `auto_save` / `auto_save_on_change` / `cleanup_on_exit`). Holds a `_service: GlobalVariableService` reference and delegates all CRUD. Owns the lifecycle: `_ready` registers Manager signals + loads the resource; `_exit_tree` / `WM_CLOSE_REQUEST` auto-saves persistent variables + cleans up non-persistent ones. Delayed saving is throttled by a `Timer` node (`auto_save_delay`). `get_instance()` prefers the node present in the scene, otherwise constructs a scene-less Assistant + Service fallback. |

#### Call chain of the quartet

```
Event/Instruction variable operations
        │
        ▼ (@tool Node, scene layer)
GlobalVariableAssistant.add_global_variable(name, variable)
        │  delegates
        ▼ (RefCounted, naming-aligned layer)
GlobalVariableService.add_global_variable(name, variable)
        │  forwards
        ▼ (RefCounted, source of truth + Mutex)
GlobalVariableManager.add_variable(name, variable)
        │  connects variable.value_changed → _on_variable_changed
        ▼
emit variable_added(name, variable)  → Assistant re-emits as variable_added
                                     → persistent variables trigger a delayed save
```

> `GlobalVariableManager` is **not** a Node singleton. It is `RefCounted`, constructed at class-load time via `static var _instance = GlobalVariableManager.new()` and exposed through `get_instance()`. `_notification(PREDELETE)` only clears `_variables`. The old draft's "singleton Node" description was wrong.

### 6.5 VariableOperations (unified access utility)

**Source file:** `addons/fuse/core/utils/variable_operations.gd` (`extends RefCounted`, all static methods)

A stateless utility class providing a unified API dispatched on the `BaseVariable.VariableScope` enum:
- `get_variable(context, name, scope, default)` / `set_variable(context, name, scope, value)` / `has_variable(context, name, scope)`
- `get_scope_container(context, search_node = null)` — the SCOPE lookup entry, via `ScopeVariableManager.find_nearest_scope`

Special behavior: after writing `ExecutionContext.local_variables`, `_set_local_variable` **additionally** writes the value into `context.trigger.set_meta("local_variable_" + name, value)`, so Event subclasses (e.g. OnIntervalWithVariable) can also read LOCAL variables from the Trigger node's meta — a workaround for sharing LOCAL variables between Event and ExecutionContext.

---

## 7. Deprecations and Legacy

### 7.1 VariableContainer (@deprecated)

**Source file:** `addons/fuse/core/base/variable_container.gd` (1188 lines, `extends Resource`)

The file header is explicitly marked `⚠️ 已废弃 - 2026-02-08` ("deprecated - 2026-02-08"), with migration guidance:
- Local variables → `ExecutionContext.local_variables` (i.e. VariableContext)
- Global variables → `GlobalVariableAssistant`

It carries its own **different** `enum VariableScope { LOCAL = 0, GLOBAL = 1 }` (two values, incompatible with BaseVariable's three-value enum) and contains large amounts of duplicated implementation — a `VariableData` inner class, indexed storage, caches, dependency graphs, and more. New code should not use it. This report records its existence only, without elaboration.

### 7.2 ConfigFile persistence inside BaseVariable (@deprecated)

The three methods `_save_to_storage` / `_load_from_storage` / `_clear_storage` and the constants `STORAGE_SECTION` / `STORAGE_CONFIG_PATH` are all marked `@deprecated`, with comments explicitly saying "please use GlobalVariableManager.save_to_resource() for persistence". These methods are kept for backward compatibility and operate on the `user://fuse_variables.cfg` ConfigFile. They pair with helpers such as `_serialize_value` / `_parse_value_from_string` (covering the full format range NIL/BOOL/INT/FLOAT/STRING/VECTOR2/VECTOR3/COLOR/ARRAY/DICT/PackedArray/Base64/NodePath) but should not be used in new projects.

---

## 8. Relationship with BaseEvent

`BaseEvent` (`addons/fuse/core/base/base_event.gd`) preloads `VariableOperations` and `VariableScopeUtils` at the top of the file to read/write variables when events fire. Event subclasses **do not hold** BaseVariable directly; they interact indirectly through ExecutionContext. BaseVariable and BaseEvent have no direct coupling point — their association is entirely mediated by EC/VariableContext/VariableOperations.

---

## 9. Subclassing Pattern

`BaseVariable` is designed to **not require subclassing**. In the vast majority of cases, create instances directly via `BaseVariable.create(...)`. If derivation is needed (e.g. to encapsulate game semantics), the suggested pattern is:

```gdscript
class_name MyGameVariable extends BaseVariable

# Business fields (@export serialized)
@export var business_tag: String = ""

# Override validation (append business rules)
func validate_configuration() -> Array[String]:
    var errors = super.validate_configuration()
    if business_tag.is_empty():
        errors.append("business_tag 不能为空")
    return errors

# Business methods (always go through set_value to fire the full signal chain)
func apply_delta(delta: float) -> void:
    set_value(to_number() + delta)
```

Notes:
- If a subclass overrides `_init`, it must call `super._init()` or set `creation_time` / `last_modified_time` itself
- Always modify values via `set_value()` to fire the full signal chain (`value_changed` + `value_modified`)
- Do not hold Node references in subclasses (BaseVariable is a Resource; node references break serialization)

---

## 10. Overall Assessment

### Pros

1. **Minimalist data model**: a single `value: Variant` field + scope enum + counters covers the vast majority of use cases
2. **Clear responsibilities**: BaseVariable only keeps the "data record"; storage duties are spread across the Context/Container/Manager layers — single responsibility
3. **Unified error container**: `_fuse_error` + `_create_fuse_error` align with Fuse's global error system
4. **Complete factory set**: from the generic `create` to game-specific `create_player_health/score/level`, covering typical scenarios
5. **Clear deprecation paths**: both ConfigFile persistence and VariableContainer carry explicit @deprecated markers and migration guidance
6. **Thread safety pushed down**: BaseVariable itself has no thread semantics; concurrency safety is guarded uniformly by `GlobalVariableManager`'s Mutex

### Known issues

1. **`set_value` always returns true**: the `bool` return type implies possible failure, but there is currently no failure path. **Decision: keep bool to stabilize the API contract** (callers commonly consume it as `if set_value(...)`); a failure path will arise naturally if value validation is introduced later (CODE_ISSUES B5)
2. **VariableContainer still exists**: 1188 lines of deprecated code remain in the repo, adding maintenance burden and confusion risk (its internal two-value VariableScope enum is incompatible with BaseVariable's three-value enum). Its dependency-graph fields were grep-confirmed to have **zero external references** and can be removed along with the deprecated class eventually (CODE_ISSUES B10)

> Historical B1/B2/B3/B9 are fixed (commit `e3c470d`, test `test_base_variable_signals.tscn`) and removed from the known-issues list. See §5.2 / §3.7 for details.

---

**Document maintainer**: Fuse dev team
**Last updated**: 2026-07-07
**Version**: 2.0 (rewrite, replacing the old draft with invented APIs)
**Reference code version**: base_variable.gd @ 1073 lines
