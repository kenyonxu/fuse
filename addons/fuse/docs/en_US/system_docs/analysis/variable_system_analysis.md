> 🌐 [**中文版**](../../../zh_CN/system_docs/analysis/variable_system_analysis.md) | English

# Variable System Analysis Report


> **Analysis date**: 2026-07-07 (code verified report-by-report during the same-day full documentation audit; for implementation evolution after that date the source code is authoritative — see the threading / runtime_instance / preset_nested and other reports for recently verified mechanism conclusions)
## Document Overview

This report gives an overall analysis of the "variable subsystem" of the Fuse visual programming system. The variable system is the data foundation of event-driven / instruction execution: Events, Conditions, and Instructions access variables through a unified read/write interface without caring where they are stored.

After several rounds of divergence and evolution, the variable system now consists of **7 production classes + 2 utility classes + 1 deprecated class**, covering four layers: "value definition / three-layer scope storage / global persistence service / static facade". Earlier documents (base_variable_analysis, fuse_architecture §4) mostly stopped at the old "BaseVariable + singleton Manager" description of 2-3 classes; this report lays out the complete responsibilities and cooperation chains of the 7+ classes from the source code.

**Key source files:**

| File | Lines | Role |
|------|------|------|
| `core/base/base_variable.gd` | 1073 | base class of variable values (Resource) |
| `core/base/variable_context.gd` | 463 | the EC variable subsystem (RefCounted) |
| `core/base/variable_container.gd` | 1188 | **@deprecated 2026-02-08** |
| `core/base/scope_variable_container.gd` | 184 | scope container (Node) |
| `core/scope_variable_manager.gd` | 159 | scope singleton (Node) |
| `core/global_variable_manager.gd` | 438 | global variable service (RefCounted singleton) |
| `core/global_variable_assistant.gd` | 639 | scene proxy (Node) |
| `core/global_variable_resource.gd` | 447 | persistence data carrier (Resource) |
| `core/global_variable_service.gd` | 113 | scene-less service layer (RefCounted) |
| `core/utils/variable_operations.gd` | 338 | static facade utility |
| `core/utils/variable_scope_utils.gd` | 388 | scope conversion utility |

---

## 1. Class Inventory and Responsibility Matrix

| Class | Base class | Singleton | Lines | Responsibility |
|------|------|------|------|------|
| `BaseVariable` | Resource | No | 1073 | single-variable value carrier: value / type / scope / persistence flag / modification count / signals; built-in factories `create / create_local / create_global / from_config / clone_variable` |
| `VariableContext` | RefCounted | No | 463 | the `ExecutionContext` variable subsystem: three-layer scope dispatch, LRU name cache (1000), indexed access, variable snapshots, break/continue loop-control stack |
| `ScopeVariableContainer` | Node | No | 184 | SCOPE variable container attached to a node; maintains the parent/child scope chain; `scope_id` registration |
| `ScopeVariableManager` | Node | Yes | 159 | scope registry + lookup (walks up the parent chain); `find_nearest_scope(node)` |
| `GlobalVariableManager` | RefCounted | Yes | 438 | core global variable service: CRUD + Mutex thread safety + 8 `_thread_safe` APIs + signals; pure logic layer |
| `GlobalVariableAssistant` | Node | Yes | 639 | scene proxy: registers with the Manager, auto load / auto save, Timer-delayed saving, cleanup of non-persistent variables; holds a `GlobalVariableService` fallback |
| `GlobalVariableResource` | Resource | No | 447 | persistence data carrier: `variables: Dictionary`, each value normalized to `{value, scope, persistent, description}`; `validate()` / `cleanup_invalid_variables()` |
| `GlobalVariableService` | RefCounted | No | 113 | thin service layer for scene-less contexts; naming aligned with the Assistant; fully delegates to the Manager |
| `VariableOperations` | RefCounted | No (all static) | 338 | static facade: `get/set/has_variable(context, name, scope, ...)` three-layer dispatch; oriented toward instructions |
| `VariableScopeUtils` | RefCounted | No (all static) | 388 | enum↔string↔display-name conversion; `ScopeSource` enum and Inspector property injection |
| `VariableContainer` ⚠️ | Resource | No | 1188 | **@deprecated 2026-02-08**, superseded by `ExecutionContext.local_variables` + `GlobalVariableAssistant` |

---

## 2. Three-Layer Scope Model

### 2.1 Scope Enum

`BaseVariable.VariableScope` (base_variable.gd:41-45) defines three values:

```gdscript
enum VariableScope {
    LOCAL = 0,   # local variables (ExecutionContext.local_variables)
    SCOPE  = 1,  # scope variables (ScopeVariableContainer)
    GLOBAL = 2   # global variables (GlobalVariableAssistant → Manager)
}
```

> Note: the deprecated `VariableContainer.VariableScope` (variable_container.gd:33-36) has only the two values `LOCAL/GLOBAL` and lags behind the three-layer model.

### 2.2 Storage Location and Lifecycle per Layer

| Layer | Storage location | Lifecycle | Persistent | Created by |
|----|----------|----------|--------|----------|
| **LOCAL** | `VariableContext.local_variables: Dictionary` | a single ExecutionContext | No | created on set at instruction runtime |
| **SCOPE** | `ScopeVariableContainer._variables: Dictionary[String, Variant]` | node entering/leaving the scene tree | No | placing a `ScopeVariableContainer` node in the scene |
| **GLOBAL** | `GlobalVariableManager._variables: Dictionary` (singleton) | the whole application | Yes (`persistent=true`) | added via any Assistant / Service / Manager API |

### 2.3 Scope Lookup Chains (Unified Rules for Reads and Writes)

**LOCAL writes** (`VariableOperations._set_local_variable`, variable_operations.gd:256-271): dual-write strategy
1. `context.set_variable(name, value, "local")` writes into the EC
2. also writes `context.trigger.set_meta("local_variable_<name>", value)` — a workaround so Events (e.g. `OnIntervalWithVariable`) can access LOCAL variables too

**SCOPE lookup** (`VariableContext._find_scope_container`, variable_context.gd:168-181):
- walks up the parent chain via `ScopeVariableManager.get_instance().find_nearest_scope(node)`
- search start priority: `context.trigger` → `context.target` → `context.owner`
- if not found, falls back to LOCAL (`push_error` reports the missing scope container; CODE_ISSUES B7 fixed)

**GLOBAL reads** (`VariableContext.get_variable` local branch, variable_context.gd:97-104):
- on a LOCAL miss, **automatically falls back to checking GLOBAL** (via `_global_variable_assistant.get_global_variable(name)`)
- this is the implicit "if LOCAL misses, look in GLOBAL" chain, different from the SCOPE explicit fallback

### 2.4 ScopeSource Secondary Selection (SCOPE Layer Only)

`VariableScopeUtils.ScopeSource` (variable_scope_utils.gd:160-165) provides 4 container-locating strategies for SCOPE variables:

| Value | Meaning | Implementation |
|----|------|------|
| `NEAREST` | nearest scope container (default) | `VariableOperations.get_scope_container(context)` |
| `CUSTOM_ID` | a specified `scope_id` | `manager.get_scope_by_id(custom_scope_id)` |
| `TRIGGER_SCOPE` | the scope on the Trigger node | `get_scope_container(context, context.trigger)` |
| `TARGET_NODE` | the scope on the Target node | `get_scope_container(context, context.get_node(target_node_path))` |

`validate_scope_source_property` (line 248) controls the dynamic visibility of `custom_scope_id` / `target_node_path` in the Inspector; `append_scope_source_properties` (line 360) injects the dynamic property list.

---

## 3. Core APIs

### 3.1 BaseVariable (Single-Variable API)

```gdscript
# Factories (static)
static func create(name, val, scope = LOCAL) -> BaseVariable
static func create_local(name, val) -> BaseVariable
static func create_global(name, val, persist = true) -> BaseVariable
static func from_config(config: Dictionary) -> BaseVariable
static func clone_variable(original, new_name = "") -> BaseVariable

# Read/write
func get_value() -> Variant       # increments access_count, lazy initialization
func set_value(new_value) -> bool # no type validation, direct assignment
func has_value() / is_empty()

# Type and comparison
func get_type_name() / get_godot_type() / to_number() / to_bool() / to_array()
func equals / not_equals / greater_than / less_than / greater_equal / less_equal

# State
func reset()                       # clears value and error, emits variable_reset
func get_info() -> Dictionary      # debug snapshot
func get_creation_info()           # includes scope / access_count / persistent
func validate_configuration() -> Array[String]

# Serialization
func serialize() / deserialize(data)
func clone() -> BaseVariable
```

**Signals**: `value_changed(old, new)` / `value_modified(value)` / `variable_reset()`

> ⚠️ `set_value` assigns directly with **no type validation whatsoever** (AUDIT_REPORT §3.7 confirmed that `_validate_value()` in the older documents was an invented API).

### 3.2 VariableContext (Three-Layer Dispatch)

```gdscript
func set_variable(name, value, scope = "local") -> bool   # three-layer dispatch
func get_variable(name, default = null, scope = "local") -> Variant
func add_variable(name, variable: BaseVariable) -> bool   # routes by variable.scope
func has_variable(name) -> bool                           # merged check across the three layers
func get_variable_object(name) -> BaseVariable            # advanced API

# Indexed access optimization (precompiled)
func precompile_variable_access(names: Array[String])
func set/get_variable_by_index(index)
func get_variable_index(name) -> int

# Snapshots (breakpoint debugging)
func get_all_local_variables_snapshot() -> Dictionary
func get_all_scope_variables_snapshot() -> Dictionary
func get_all_global_variables_snapshot() -> Dictionary

# Loop control
func set_break_loop() / set_continue_loop()
func should_break_loop() / should_continue_loop()
func clear_loop_flags() / push_loop_flags() / pop_loop_flags()

# Cleanup and duplication
func cleanup()
func duplicate(p_deep = true) -> VariableContext
```

### 3.3 GlobalVariableManager (Global Service Core)

```gdscript
# CRUD
func add_variable(name, variable) -> bool
func get_variable(name) -> BaseVariable
func has_variable(name) -> bool
func remove_variable(name) -> bool
func get_all_variable_names() -> Array[String]
func get_variable_count() -> int
func clear_all_variables()

# Persistence
func save_to_resource(path) -> bool              # everything
func save_persistent_to_resource(path) -> bool   # only persistent=true
func load_from_resource(path) -> bool            # supports both new and legacy formats

# Thread safety (Mutex-protected, 8 APIs)
func get_variable_thread_safe(name)
func has_variable_thread_safe(name)
func set_variable_thread_safe(name, variable)
func set_variable_value_thread_safe(name, value)
func get_variables_batch_thread_safe(names) -> Dictionary
func get_all_variables_snapshot() -> Dictionary   # deep-copied snapshot
func get_variables_safe() -> Dictionary           # safe iterator

# Reference-type notification
func notify_variable_content_changed(name)  # manually triggered when Array/Dictionary content is modified
```

**Signals**: `variable_added(name, variable)` / `variable_removed(name)` / `variable_changed(name, old, new)`

### 3.4 GlobalVariableAssistant (Scene Proxy)

```gdscript
# Singleton
static func get_instance() -> GlobalVariableAssistant  # prefers the scene node; constructs a Service fallback when no scene exists

# Resource management
func load_resource(path) / save_current_resource() / save_persistent_variables()
func set_current_resource(resource) / create_new_resource(path, description)
func register_to_manager() / unregister_from_manager()

# Variable CRUD (all delegated via _service → Manager)
func add_global_variable(name, variable) / remove_global_variable(name)
func get_global_variable(name) / has_global_variable(name)
func get_all_global_variable_names() / get_all_global_variables_info()
```

**Key @exports**: `auto_save` / `auto_load_on_ready` / `cleanup_on_exit` / `auto_save_on_change` (default false) / `auto_save_delay` (default 1.0s)

**Signals**: `resource_changed` / `variable_added` / `variable_removed` / `variable_modified` / `save_completed` / `load_completed`

### 3.5 ScopeVariableContainer + ScopeVariableManager

```gdscript
# ScopeVariableContainer
func set_variable(name, value) / get_variable(name, default) / has_variable / remove_variable
func get_variable_names() -> PackedStringArray
func clear_variables()
func get_parent_scope() / get_child_scopes() / get_scope_chain()

# ScopeVariableManager (singleton)
static func get_instance() -> ScopeVariableManager
func register_scope(container) / unregister_scope(container)
func get_scope_by_id(scope_id)
func find_nearest_scope(node)                  # MAX_SCOPE_SEARCH_DEPTH=100
func find_scope_by_node_path(node_path, ctx)
func get_scope_node_chain(node) -> Array[ScopeVariableContainer]
```

**InheritanceMode** (scope_variable_container.gd:45-49): `NONE` / `READ_ONLY` (default) / `READ_WRITE`

### 3.6 VariableOperations (Static Facade)

```gdscript
static func get_variable(context, name, scope, default = null) -> Variant
static func set_variable(context, name, scope, value) -> bool
static func has_variable(context, name, scope) -> bool
static func get_scope_container(context, search_node = null) -> ScopeVariableContainer
static func set_log_level(level)
```

---

## 4. Architecture Relationships

### 4.1 Three-Layer Architecture (GLOBAL Layer)

```
┌──────────────────────────────────────────────────────────────┐
│  Instructions / Event / Condition                            │
│     ↓ (static calls)                                         │
│  VariableOperations.set/get_variable(context, name, scope)   │
│     ↓ (GLOBAL branch)                                        │
│  GlobalVariableAssistant (Node, scene proxy)                 │
│     ↓ (_service delegation)                                  │
│  GlobalVariableService (RefCounted, scene-less fallback)     │
│     ↓ (_manager delegation)                                  │
│  GlobalVariableManager (RefCounted singleton, Mutex)         │
│     ↓ (load/save)                                            │
│  GlobalVariableResource (Resource) ← ResourceSaver/Loader    │
└──────────────────────────────────────────────────────────────┘
```

**Motivation for the two-layer delegation design:**
- **The Manager is the de facto service core**: pure RefCounted + Mutex, usable on any thread
- **The Assistant is the scene proxy**: handles node lifecycle hooks such as `_ready` auto-load, `_exit_tree` auto-save and cleanup, Timer-delayed saving
- **The Service is the scene-less fallback**: when `Engine.get_main_loop().current_scene` is empty (editor, unit tests), `get_instance()` constructs an Assistant with `_service = GlobalVariableService.new()`, keeping CRUD available while auto_load/auto_save/cleanup do not apply

### 4.2 SCOPE Layer Architecture

```
ScopeVariableManager (Node singleton, attached under root)
    ↑ register_scope / find_nearest_scope
ScopeVariableContainer (Node, any scene node)
    ↑ _parent_scope / _child_scopes (scope chain)
    └── _variables: Dictionary[String, Variant]
```

### 4.3 LOCAL Layer Architecture

```
ExecutionContext (Node)
    └── VariableContext (RefCounted)
            ├── local_variables: Dictionary
            ├── _variable_name_cache: Dictionary (LRU, 1000)
            ├── _variable_index_map / _variable_array (precompiled indexes)
            ├── _global_variable_assistant: GlobalVariableAssistant (cross-layer reference)
            └── _loop_flag_stack (loop control)
```

### 4.4 VariableContext ↔ GlobalVariableAssistant Cross-Layer Coupling

`VariableContext` holds a `_global_variable_assistant` reference (variable_context.gd:21, 247-256):
- on a LOCAL read miss it queries GLOBAL directly through the assistant (implicit fallback)
- injected at EC initialization by `set_global_variable_assistant(assistant)`

This is the de facto implementation of the LOCAL→GLOBAL fallback chain, bypassing VariableOperations.

---

## 5. Lifecycle and Persistence

### 5.1 LOCAL Variable Lifecycle

```
ExecutionContext created
    └── VariableContext._init(owner) → empty local_variables
set_variable(name, value, "local") at instruction runtime
    ├── _set_local_variable → local_variables[name] = value
    └── VariableOperations._set_local_variable → trigger.set_meta("local_variable_<name>", value)
ExecutionContext.cleanup()
    └── VariableContext.cleanup() → clears local_variables and disconnects the global reference
```

**No persistence**: LOCAL variables are lost as soon as the EC is destroyed.

### 5.2 SCOPE Variable Lifecycle

```
ScopeVariableContainer._enter_tree()
    ├── call_deferred("_register_scope")        → ScopeVariableManager.register_scope(self)
    └── call_deferred("_register_with_parent_scope")  → maintains the parent/child chain
While the node exists: set/get/remove_variable
ScopeVariableContainer._exit_tree()
    ├── _unregister_scope()
    ├── _unregister_from_parent_scope()
    └── _child_scopes.clear()
```

**No automatic persistence**: SCOPE variables are destroyed when the scene exits. To keep them, developers serialize `_variables` themselves.

### 5.3 GLOBAL Variable Persistence Flow

```
1. Application startup
   GlobalVariableAssistant._ready()
     ├── auto_register → register_to_manager() connects the Manager signals
     └── auto_load_on_ready
            ├── resource_path not empty → load_resource(path) → Manager.load_from_resource(path)
            └── current_resource already set → _load_from_current_resource()

2. Runtime modification
   Manager.add_variable / variable.set_value
     └── variable_changed signal → Assistant._on_manager_variable_changed
            └── if persistent and auto_save_on_change → _request_delayed_save()
                   └── Timer(auto_save_delay) timeout → _save_persistent_variables()

3. Application exit
   Assistant._exit_tree() / _notification(WM_CLOSE_REQUEST)
     └── _perform_save_and_cleanup()
            ├── auto_save and resource_path not empty → _save_persistent_variables()
            │     └── Manager.save_persistent_to_resource(path) → ResourceSaver.save()
            ├── cleanup_on_exit → _cleanup_non_persistent_variables()
            │     └── walks the Manager and removes every persistent=false variable
            └── _is_registered → unregister_from_manager() disconnects the signals
```

**Key design choices:**
- **Only persistent variables are saved**: `save_persistent_to_resource` filters out `persistent=false`, keeping runtime temporaries from polluting the save
- **`auto_save_on_change` defaults to false**: explicit manual saving via the `SaveGlobalVariables` instruction is recommended (global_variable_assistant.gd:21)
- **New/legacy format compatibility**: `Manager.load_from_resource` detects the `GlobalVariableResource` type; the legacy meta format is converted automatically (global_variable_manager.gd:166-178)
- **Reference-type modification**: mutating Array/Dictionary content does not fire `value_changed`; call `Manager.notify_variable_content_changed(name)` manually (global_variable_manager.gd:256-272)

### 5.4 Resource Data Format

Each value in `GlobalVariableResource.variables` is normalized to a dictionary:

```gdscript
{
    "value": <Variant>,
    "scope": <int 0/1/2>,
    "persistent": <bool>,
    "description": <String>
}
```

The legacy format (bare values) is wrapped automatically by `_normalize_variable_data` (global_variable_resource.gd:306-331).

`validate()` (line 256) checks: non-empty version, valid timestamp, variable names are legal identifiers, values serializable (recursively checking Array/Dictionary elements).

---

## 6. VariableContainer Deprecation Notes

`VariableContainer` (variable_container.gd:1-13) was **marked @deprecated on 2026-02-08**:

```gdscript
## ⚠️ Deprecated - 2026-02-08
## VariableContainer has been deprecated. Use the following replacements instead:
## - Local variables: use ExecutionContext.local_variables (Dictionary)
## - Global variables: use GlobalVariableAssistant
```

### 6.1 Superseded Responsibility Mapping

| Legacy VariableContainer responsibility | Superseded by |
|--------------------------|--------|
| LOCAL variable storage (`_variables_data`) | `VariableContext.local_variables` |
| GLOBAL variable storage | `GlobalVariableManager._variables` |
| Dependency graph (`_variable_dependencies/_dependents`) | no replacement yet (not migrated) |
| Indexed storage (`_indexed_variables`) | `VariableContext._variable_index_map / _variable_array` |
| Cache (`_unified_cache`) | `VariableContext._variable_name_cache` (LRU) |
| Scope enum (two values LOCAL/GLOBAL) | `BaseVariable.VariableScope` (three layers LOCAL/SCOPE/GLOBAL) |
| Serialization (serialize/deserialize) | `GlobalVariableResource` |

### 6.2 Migration Status

The source file comment (variable_container.gd:9-11) states:
- the `OnVariableChanged` event has been refactored to use `GlobalVariableAssistant`
- all variable operation instructions use `ExecutionContext` and `GlobalVariableAssistant`
- new code should no longer depend on this class

**Reason kept**: backward compatibility with the deserialization path of old `.tres` resources.

---

## 7. Thread Safety and Concurrency

`GlobalVariableManager` is the only explicitly thread-safe class in the variable system (global_variable_manager.gd:21, 47-72):

- **A Mutex guards all `_variables` access**: lock before writing, unlock before emitting (avoids callbacks under the lock)
- **Signal connections happen outside the lock**: `add_variable` only calls `connect(value_changed)` after `_mutex.unlock()`, preventing callback reentrancy
- **8 `_thread_safe` APIs**: used by `FuseTaskManager` / `ParallelConditionEvaluator` for parallel condition checking
- **`get_all_variables_snapshot` / `get_variables_safe`**: return deep copies, immune to concurrent modification during iteration

The other classes (VariableContext / ScopeVariableContainer / GlobalVariableAssistant) are **not thread safe** and must be used on the main thread.

See [multithreading-developer-guide.md](../../dev_docs/guides/multithreading-developer-guide.md) for details.

---

## 8. Overall Assessment

### Strengths

1. **Clear division of responsibilities**: value definition (BaseVariable) / three-layer storage (VC/SVC/Manager) / persistence (Resource) / scene proxy (Assistant) / static facade (Operations) each do their own job
2. **Well-defined three-layer scope semantics**: LOCAL/SCOPE/GLOBAL map to "a single execution / a node subtree / the whole application"; together with the `ScopeSource` secondary selection they cover the typical use cases
3. **Thread-safe GLOBAL layer**: Mutex + deep-copied snapshots support parallel condition evaluation
4. **Scene decoupling**: the Manager is pure RefCounted, the Assistant handles node lifecycle hooks, the Service provides the scene-less fallback; the combination works uniformly in the editor, unit tests, and at runtime
5. **Robust persistence format**: automatic new/legacy format conversion, persistent-only filtering, reference-type modification notification, Timer-delayed saving
6. **Unified facade**: `VariableOperations` frees instructions from knowing the three-layer differences, and `VariableScopeUtils` provides Inspector integration

### Weaknesses

1. **Implicit coupling between VariableContext and GLOBAL**: a LOCAL read miss automatically falls back to GLOBAL (variable_context.gd:97-104), which contradicts the "strict LOCAL/SCOPE/GLOBAL layering" intuition and makes variable provenance easy to confuse when debugging
2. **Fragility of the LOCAL dual-write strategy**: `VariableOperations._set_local_variable` writes both the EC and the Trigger meta (line 256-271) — a workaround for sharing LOCAL variables between Events and the EC, with no unified abstraction at the EC layer
3. **VariableContainer dependency graph not migrated**: the deprecated class's `_variable_dependencies/_dependents` (variable_container.gd:947-1028) has no replacement. A grep confirmed the dependency-graph fields have **zero external references** in the repository, the deprecated class is unused, and there is no migration need (CODE_ISSUES B10, classified as design intent)
4. **GlobalVariableManager singleton timing (a misjudgment)**: `static var _instance = GlobalVariableManager.new()` (global_variable_manager.gd:14) is statically initialized. It was once logged as a concern that script load order might precede FuseLogger (CODE_ISSUES B8); verification showed FuseLogger is purely static with no instance dependencies, so **this misjudgment was removed**

> Historical B6 (VariableContext index dual-track desync) and B7 (silent SCOPE fallback) were fixed (commit `4adf15b`, test `test_variable_context_index_sync.tscn`): the write path now syncs the index array, and the SCOPE fallback uses `push_error`. Removed from the weakness list.

---

**Maintained by**: Fuse development team
**Last updated**: 2026-07-07
**Version**: 1.0.0
**Audit basis**: [AUDIT_REPORT_2026-07-07.md (Chinese)](../../../zh_CN/system_docs/analysis/AUDIT_REPORT_2026-07-07.md) §2.4 / §3.7
